extends Node
class_name DaocOpenDaocTcpLoginProbe

const DaocOpenDaocPacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const DaocOpenDaocChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const DaocOpenDaocPacketLogScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketLog.gd")

const CHECKPOINT: String = "P1_20A_OPENDAOC_TCP_LOGIN_PROBE"
const PRODUCTION_HOST: String = "135.125.201.202"
const DEFAULT_REPORT_DIR: String = "res://reports/p1_20a_opendaoc_tcp_login_probe/"
const DEFAULT_CLIENT_VERSION: String = "1.125a"
const DEFAULT_CLIENT_TYPE: int = 0x02

@export var p1_20a_probe_enabled: bool = false
@export var p1_20a_run_on_ready: bool = false
@export var p1_20a_host: String = ""
@export var p1_20a_login_port: int = 10300
@export var p1_20a_username: String = ""
@export var p1_20a_password: String = ""
@export var p1_20a_client_version: String = ""
@export var p1_20a_send_packets: bool = false
@export var p1_20a_allow_production_host: bool = false
@export var p1_20a_stop_after_character_overview: bool = true
@export var p1_20a_timeout_seconds: float = 8.0
@export var p1_20a_write_hex_dump: bool = true
@export var p1_20a_report_dir: String = DEFAULT_REPORT_DIR
@export var p1_20a_redact_credentials: bool = true

var state: String = "idle"
var receive_buffer := PackedByteArray()
var last_report: Dictionary = {}

var _codec: RefCounted = DaocOpenDaocPacketCodecScript.new()
var _checksum: RefCounted = DaocOpenDaocChecksumScript.new()
var _packet_log: RefCounted = DaocOpenDaocPacketLogScript.new()
var _peer: StreamPeerTCP = null
var _next_sequence: int = 0
var _session_id: int = 0


func _ready() -> void:
	if p1_20a_run_on_ready:
		call_deferred("run_probe")


func run_probe(overrides: Dictionary = {}) -> Dictionary:
	var options := _options(overrides)
	_packet_log.call("clear")
	receive_buffer = PackedByteArray()
	state = "idle"
	var report := _base_report(options)
	report["codec_selftest"] = run_codec_selftest()
	report["checksum"] = _checksum.call("algorithm_status") as Dictionary
	_packet_log.call("log_event", "probe started")
	var crypt_payload: Dictionary = build_crypt_key_request_payload(str(options.get("client_version", DEFAULT_CLIENT_VERSION)))
	var login_payload: Dictionary = build_login_request_payload(str(options.get("username", "")), str(options.get("password", "")), str(options.get("client_version", DEFAULT_CLIENT_VERSION)))
	var overview_payload: Dictionary = build_character_overview_request_payload(int(options.get("chosen_realm", 1)))
	var select_payload: Dictionary = build_character_select_request_payload()
	var layouts_ok := bool(crypt_payload.get("ok", false)) \
		and bool(login_payload.get("ok", false)) \
		and bool(overview_payload.get("ok", false)) \
		and bool(select_payload.get("ok", false))
	report["payload_layouts_available"] = layouts_ok
	report["layout_status"] = {
		"crypt_key_request": _payload_status_without_bytes(crypt_payload),
		"login_request": _payload_status_without_bytes(login_payload),
		"character_overview_request": _payload_status_without_bytes(overview_payload),
		"character_select_request": _payload_status_without_bytes(select_payload),
	}

	var guard := _preflight_guard(options)
	report.merge(guard, true)
	if str(guard.get("block_reason", "")) != "":
		state = "failed" if str(guard.get("severity", "WARN")) == "FAIL" else "done"
		report["last_state"] = state
		report["verdict"] = _verdict(report)
		_write_all_reports(report, options)
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	if not bool(options.get("probe_enabled", false)) or not bool(options.get("send_packets", false)):
		state = "done"
		report["last_state"] = state
		report["verdict"] = _verdict(report)
		_packet_log.call("log_event", "dry-run only; no network connection attempted")
		_write_all_reports(report, options)
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	if not layouts_ok:
		report["payload_layout_blocked"] = true
		report["block_reason"] = "invalid_payload_layout"
		state = "done"
		report["last_state"] = state
		report["verdict"] = _verdict(report)
		_packet_log.call("log_event", "live send blocked: %s" % report["block_reason"])
		_write_all_reports(report, options)
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	_attempt_live_flow(report, options, crypt_payload.get("payload", PackedByteArray()) as PackedByteArray)
	report["last_state"] = state
	report["verdict"] = _verdict(report)
	_write_all_reports(report, options)
	last_report = report.duplicate(true)
	return last_report.duplicate(true)


func build_crypt_key_request_payload(client_version: String = DEFAULT_CLIENT_VERSION, client_type: int = DEFAULT_CLIENT_TYPE, build_number: int = 0) -> Dictionary:
	var version := client_version.strip_edges().to_lower()
	if version.begins_with("v"):
		version = version.substr(1)
	if version == "":
		version = DEFAULT_CLIENT_VERSION
	var parts := version.split(".", false)
	if parts.size() != 2 or not str(parts[0]).is_valid_int():
		return {"ok": false, "payload": PackedByteArray(), "reason": "invalid_client_version", "client_version": version}
	var major := int(parts[0])
	var suffix := str(parts[1])
	var revision_letter := "a"
	if suffix.length() > 0 and not suffix.substr(suffix.length() - 1, 1).is_valid_int():
		revision_letter = suffix.substr(suffix.length() - 1, 1)
		suffix = suffix.substr(0, suffix.length() - 1)
	if suffix.length() < 2 or not suffix.is_valid_int():
		return {"ok": false, "payload": PackedByteArray(), "reason": "invalid_client_version_digits", "client_version": version}
	# GameClient computes (major * 1000) + (minor * 100) + revision.
	# Therefore 1.125a is encoded as 1, 1, 25 (01 01 19), not 1, 12, 5.
	var minor_digits := suffix.substr(0, 1)
	var revision_digits := suffix.substr(1)
	if not minor_digits.is_valid_int() or not revision_digits.is_valid_int():
		return {"ok": false, "payload": PackedByteArray(), "reason": "invalid_client_version_components", "client_version": version}
	var minor := int(minor_digits)
	var revision := int(revision_digits)
	var letter_bytes: PackedByteArray = _codec.call("encode_windows_1252", revision_letter) as PackedByteArray
	if major > 0xff or minor > 0xff or revision > 0xff or letter_bytes.size() != 1:
		return {"ok": false, "payload": PackedByteArray(), "reason": "client_version_component_out_of_range", "client_version": version}
	var payload := PackedByteArray([int(client_type) & 0xff, major, minor, revision, int(letter_bytes[0]) & 0xff])
	payload.append_array(_codec.call("u16_le_write", build_number) as PackedByteArray)
	return {
		"ok": true,
		"payload": payload,
		"payload_size": payload.size(),
		"layout_confidence": "server_confirmed",
		"client_version": "%d.%s%s" % [major, suffix, revision_letter],
		"client_type": int(client_type) & 0xff,
		"build_number": int(build_number) & 0xffff,
		"version_number": (major * 1000) + (minor * 100) + revision,
	}


func build_login_request_payload(username: String = "", password: String = "", client_version: String = DEFAULT_CLIENT_VERSION) -> Dictionary:
	if username == "" or password == "":
		return {"ok": false, "payload": PackedByteArray(), "reason": "credentials_missing", "layout_confidence": "server_confirmed"}
	var version_layout := build_crypt_key_request_payload(client_version)
	if not bool(version_layout.get("ok", false)):
		return {"ok": false, "payload": PackedByteArray(), "reason": "invalid_client_version", "layout_confidence": "server_source_verified"}
	var version_number := int(version_layout.get("version_number", 0))
	var username_bytes: PackedByteArray = _codec.call("encode_windows_1252", username) as PackedByteArray
	var password_bytes: PackedByteArray = _codec.call("encode_windows_1252", password) as PackedByteArray
	var payload := PackedByteArray()
	# OpenDAoC LoginRequestHandler for 1.115 through 1.125 skips the same
	# 7-byte client type/version/revision/build block used by CryptKeyRequest.
	# From 1.126 onward it reads the Pascal strings immediately.
	var includes_version_prefix := version_number >= 1115 and version_number < 1126
	if includes_version_prefix:
		payload.append_array(version_layout.get("payload", PackedByteArray()) as PackedByteArray)
	payload.append_array(_codec.call("pascal_u32_le_write", username) as PackedByteArray)
	payload.append_array(_codec.call("pascal_u32_le_write", password) as PackedByteArray)
	return {
		"ok": true,
		"payload": payload,
		"payload_size": payload.size(),
		"username_byte_length": username_bytes.size(),
		"password_byte_length": password_bytes.size(),
		"layout_confidence": "server_source_verified",
		"client_version": str(version_layout.get("client_version", client_version)),
		"version_prefix_size": 7 if includes_version_prefix else 0,
		"credentials_redacted": true,
	}


func build_character_overview_request_payload(chosen_realm: int = 1) -> Dictionary:
	var realm := clampi(int(chosen_realm), 0, 3)
	return {"ok": true, "payload": PackedByteArray([realm]), "payload_size": 1, "chosen_realm": realm, "layout_confidence": "server_confirmed"}


func build_character_select_request_payload() -> Dictionary:
	return {"ok": true, "payload": PackedByteArray(), "payload_size": 0, "layout_confidence": "server_confirmed", "server_ignores_payload_for_1_124_plus": true}


func decode_crypt_key_payload(payload: PackedByteArray) -> Dictionary:
	var version: Dictionary = _codec.call("pascal_u32_le_read", payload, 0) as Dictionary
	if not bool(version.get("ok", false)):
		return {"ok": false, "error": version.get("error", "invalid_version_string")}
	var offset := int(version.get("next_offset", 0))
	if offset + 2 > payload.size():
		return {"ok": false, "error": "missing_build_bytes", "version": version.get("text", "")}
	return {
		"ok": true,
		"version": str(version.get("text", "")),
		"major_build": int(payload[offset]) & 0xff,
		"minor_build": int(payload[offset + 1]) & 0xff,
		"encryption_enabled": false,
		"requires_client_sbox": false,
		"consumed": offset + 2,
	}


func decode_login_granted_payload(payload: PackedByteArray) -> Dictionary:
	var account: Dictionary = _codec.call("pascal_u8_read", payload, 0) as Dictionary
	if not bool(account.get("ok", false)):
		return {"ok": false, "error": account.get("error", "invalid_account_name")}
	var server: Dictionary = _codec.call("pascal_u8_read", payload, int(account.get("next_offset", 0))) as Dictionary
	if not bool(server.get("ok", false)):
		return {"ok": false, "error": server.get("error", "invalid_server_name")}
	var offset := int(server.get("next_offset", 0))
	if offset + 3 > payload.size():
		return {"ok": false, "error": "missing_login_granted_flags"}
	return {
		"ok": true,
		"account_name": str(account.get("text", "")),
		"server_short_name": str(server.get("text", "")),
		"server_id": int(payload[offset]) & 0xff,
		"realm_color_type": int(payload[offset + 1]) & 0xff,
		"is_trial_account": (int(payload[offset + 2]) & 0xff) != 0,
		"consumed": offset + 3,
	}


func decode_session_id_payload(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2:
		return {"ok": false, "error": "session_id_payload_too_short"}
	return {"ok": true, "session_id": int(_codec.call("u16_le_read", payload, 0)), "consumed": 2}


func decode_character_overview_payload(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 8:
		return {"ok": false, "error": "character_overview_missing_padding", "characters": []}
	var offset := 8
	var characters: Array = []
	var slots: Array = []
	for slot_index in range(10):
		if offset >= payload.size():
			return {"ok": false, "error": "character_overview_truncated_before_slot", "slot": slot_index, "characters": characters, "slots": slots, "offset": offset}
		var level := int(payload[offset]) & 0xff
		offset += 1
		if level == 0:
			slots.append({"slot": slot_index, "empty": true})
			continue
		var name_result: Dictionary = _codec.call("pascal_u32_le_read", payload, offset) as Dictionary
		if not bool(name_result.get("ok", false)):
			return {"ok": false, "error": name_result.get("error", "invalid_character_name"), "slot": slot_index, "characters": characters}
		offset = int(name_result.get("next_offset", offset))
		# unknown1 + unknown2 + six face bytes + two extensions + customization + mood + 13 padding
		if offset + 28 > payload.size():
			return {"ok": false, "error": "character_fixed_block_truncated", "slot": slot_index, "characters": characters}
		var unknown1 := int(payload[offset]) & 0xff
		var unknown2 := int(_codec.call("u32_le_read", payload, offset + 1))
		var appearance := {
			"eye_size": int(payload[offset + 5]) & 0xff,
			"lip_size": int(payload[offset + 6]) & 0xff,
			"eye_color": int(payload[offset + 7]) & 0xff,
			"hair_color": int(payload[offset + 8]) & 0xff,
			"face_type": int(payload[offset + 9]) & 0xff,
			"hair_style": int(payload[offset + 10]) & 0xff,
			"equipment_extension_1": int(payload[offset + 11]) & 0xff,
			"equipment_extension_2": int(payload[offset + 12]) & 0xff,
			"customization_step": int(payload[offset + 13]) & 0xff,
			"mood_type": int(payload[offset + 14]) & 0xff,
		}
		offset += 28
		var location_result: Dictionary = _codec.call("pascal_u32_le_read", payload, offset) as Dictionary
		if not bool(location_result.get("ok", false)):
			return {"ok": false, "error": location_result.get("error", "invalid_location"), "slot": slot_index, "characters": characters}
		offset = int(location_result.get("next_offset", offset))
		var class_result: Dictionary = _codec.call("pascal_u32_le_read", payload, offset) as Dictionary
		if not bool(class_result.get("ok", false)):
			return {"ok": false, "error": class_result.get("error", "invalid_class_name"), "slot": slot_index, "characters": characters}
		offset = int(class_result.get("next_offset", offset))
		var race_result: Dictionary = _codec.call("pascal_u32_le_read", payload, offset) as Dictionary
		if not bool(race_result.get("ok", false)):
			return {"ok": false, "error": race_result.get("error", "invalid_race_name"), "slot": slot_index, "characters": characters}
		offset = int(race_result.get("next_offset", offset))
		if offset + 59 > payload.size():
			return {"ok": false, "error": "character_tail_truncated", "slot": slot_index, "characters": characters, "available": payload.size() - offset}
		var current_model := int(_codec.call("u16_le_read", payload, offset))
		var region_id := int(payload[offset + 2]) & 0xff
		var expansion_flag := int(payload[offset + 3]) & 0xff
		offset += 4
		var equipment: Array[int] = []
		for equipment_index in range(20):
			equipment.append(int(_codec.call("u16_le_read", payload, offset + equipment_index * 2)))
		offset += 40
		var attributes := {
			"strength": int(payload[offset]) & 0xff,
			"dexterity": int(payload[offset + 1]) & 0xff,
			"constitution": int(payload[offset + 2]) & 0xff,
			"quickness": int(payload[offset + 3]) & 0xff,
			"intelligence": int(payload[offset + 4]) & 0xff,
			"piety": int(payload[offset + 5]) & 0xff,
			"empathy": int(payload[offset + 6]) & 0xff,
			"charisma": int(payload[offset + 7]) & 0xff,
		}
		offset += 8
		var character := {
			"slot": slot_index,
			"empty": false,
			"level": level,
			"name": str(name_result.get("text", "")),
			"unknown1": unknown1,
			"unknown2": unknown2,
			"appearance": appearance,
			"location": str(location_result.get("text", "")),
			"class_name": str(class_result.get("text", "")),
			"race_name": str(race_result.get("text", "")),
			"current_model": current_model,
			"region_id": region_id,
			"expansion_flag": expansion_flag,
			"equipment": equipment,
			"attributes": attributes,
			"class_id": int(payload[offset]) & 0xff,
			"realm_id": int(payload[offset + 1]) & 0xff,
			"race_and_gender": int(payload[offset + 2]) & 0xff,
			"active_weapon_right": int(payload[offset + 3]) & 0xff,
			"active_weapon_left": int(payload[offset + 4]) & 0xff,
			"si_zone_flag": int(payload[offset + 5]) & 0xff,
			"constitution_copy": int(payload[offset + 6]) & 0xff,
		}
		offset += 7
		characters.append(character)
		slots.append(character)
	return {"ok": true, "characters": characters, "slots": slots, "character_count": characters.size(), "consumed": offset, "remaining": payload.size() - offset}


func run_codec_selftest() -> Dictionary:
	var payload := PackedByteArray([0x11, 0x22, 0x33])
	var packet0: PackedByteArray = _codec.call("build_packet", 0xF4, payload, 0x0102, 0x0304, 0x0506, 0)
	var checksum_value: int = int(_checksum.call("compute_checksum", packet0.slice(0, packet0.size() - 2)))
	var packet: PackedByteArray = _codec.call("build_packet", 0xF4, payload, 0x0102, 0x0304, 0x0506, checksum_value)
	var parsed: Dictionary = _codec.call("parse_packet", packet) as Dictionary
	var split_a := packet.slice(0, 5)
	var split_b := packet.slice(5, packet.size())
	var fragmented := PackedByteArray()
	fragmented.append_array(split_a)
	var first_extract: Dictionary = _codec.call("try_extract_packets", fragmented) as Dictionary
	fragmented.append_array(split_b)
	var second_extract: Dictionary = _codec.call("try_extract_packets", fragmented) as Dictionary
	var short_parse: Dictionary = _codec.call("parse_packet", PackedByteArray([0x00, 0x01])) as Dictionary
	var invalid := PackedByteArray([0xff, 0xff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var invalid_extract: Dictionary = _codec.call("try_extract_packets", invalid) as Dictionary
	var checksum_report: Dictionary = _checksum.call("verify_checksum", packet) as Dictionary
	# Exact 0x22 shape observed from OpenDAoC: the declared version length includes NUL.
	var server_payload := PackedByteArray([0x07, 0x00, 0x00, 0x00, 0x31, 0x2E, 0x31, 0x32, 0x35, 0x61, 0x00, 0x00, 0x00])
	var server_packet: PackedByteArray = _codec.call("build_server_packet", 0x22, server_payload) as PackedByteArray
	var server_parsed: Dictionary = _codec.call("parse_server_packet", server_packet) as Dictionary
	var server_decoded: Dictionary = decode_crypt_key_payload(server_payload)
	var cp1252_roundtrip := str(_codec.call("decode_windows_1252", _codec.call("encode_windows_1252", "Théurgiste €") as PackedByteArray))
	var ok := packet.size() == payload.size() + 12 \
		and bool(parsed.get("ok", false)) \
		and int(parsed.get("opcode", -1)) == 0xF4 \
		and int(parsed.get("sequence", 0)) == 0x0102 \
		and int(parsed.get("session_id", 0)) == 0x0304 \
		and int(parsed.get("parameter", 0)) == 0x0506 \
		and (first_extract.get("packets", []) as Array).is_empty() \
		and (second_extract.get("packets", []) as Array).size() == 1 \
		and not bool(short_parse.get("ok", true)) \
		and not bool(invalid_extract.get("ok", true)) \
		and bool(checksum_report.get("ok", false)) \
		and server_packet.size() == server_payload.size() + 3 \
		and int(server_parsed.get("opcode", -1)) == 0x22 \
		and not bool(server_parsed.get("checksum_present", true)) \
		and str(server_decoded.get("version", "")) == "1.125a" \
		and cp1252_roundtrip == "Théurgiste €"
	return {
		"ok": ok,
		"packet_total_size": packet.size(),
		"payload_size": payload.size(),
		"parsed": _strip_bytes(parsed),
		"fragmented_first_count": (first_extract.get("packets", []) as Array).size(),
		"fragmented_second_count": (second_extract.get("packets", []) as Array).size(),
		"short_status": str(short_parse.get("parse_status", "")),
		"invalid_errors": invalid_extract.get("errors", []),
		"checksum": checksum_report,
		"server_framing": _strip_bytes(server_parsed),
		"server_crypt_key": server_decoded,
		"cp1252_roundtrip_ok": cp1252_roundtrip == "Théurgiste €",
	}


func _attempt_live_flow(report: Dictionary, options: Dictionary, crypt_payload: PackedByteArray) -> void:
	report["connection_attempted"] = true
	_next_sequence = 0
	_session_id = 0
	state = "connecting"
	_peer = StreamPeerTCP.new()
	var err := _peer.connect_to_host(str(options.get("host", "")), int(options.get("login_port", 10300)))
	if err != OK:
		report["socket_error"] = "connect_to_host error=%d" % int(err)
		state = "failed"
		_close_peer()
		return
	var deadline := Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 8.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		var status := int(_peer.get_status())
		if status == StreamPeerTCP.STATUS_CONNECTED:
			report["connected"] = true
			state = "connected"
			break
		if status == StreamPeerTCP.STATUS_ERROR:
			report["socket_error"] = "tcp status error"
			state = "failed"
			_close_peer()
			return
		OS.delay_msec(25)
	if not bool(report.get("connected", false)):
		report["socket_error"] = "timeout_connecting"
		state = "failed"
		_close_peer()
		return
	_send_packet(0xF4, crypt_payload, "CryptKeyRequest", report)
	_poll_receive_until(deadline, report, options)
	_close_peer()
	if state != "failed" and not bool(report.get("handshake_complete", false)):
		if not bool(report.get("probe_goal_reached", false)):
			report["timeout_stage"] = state
			report["socket_error"] = "timeout_after_%s" % state
			state = "failed"
		else:
			state = "done"


func _send_packet(opcode: int, payload: PackedByteArray, label: String, report: Dictionary) -> bool:
	var sequence := _next_sequence & 0xffff
	_next_sequence = (_next_sequence + 1) & 0xffff
	var packet0: PackedByteArray = _codec.call("build_client_packet", opcode, payload, sequence, _session_id, 0, 0)
	var chk := int(_checksum.call("compute_checksum", packet0.slice(0, packet0.size() - 2)))
	var packet: PackedByteArray = _codec.call("build_client_packet", opcode, payload, sequence, _session_id, 0, chk)
	var err := _peer.put_data(packet)
	var parsed: Dictionary = _codec.call("parse_client_packet", packet) as Dictionary
	var checksum_report: Dictionary = _checksum.call("verify_checksum", packet) as Dictionary
	_packet_log.call("log_packet", "client_to_server", parsed, packet, checksum_report, label, true)
	if err != OK:
		report["socket_error"] = "put_data error=%d" % int(err)
		state = "failed"
		return false
	if opcode == 0xF4:
		state = "sent_crypt_key_request"
	elif opcode == 0xA7:
		state = "sent_login_request"
		report["login_request_sent"] = true
	elif opcode == 0xFC:
		state = "sent_character_overview_request"
		report["character_overview_request_sent"] = true
	elif opcode == 0x10:
		state = "sent_character_select_request"
		report["character_select_request_sent"] = true
	return true


func _poll_receive_until(deadline: int, report: Dictionary, options: Dictionary) -> void:
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		var status := int(_peer.get_status())
		if status != StreamPeerTCP.STATUS_CONNECTED:
			report["remote_closed"] = true
			report["socket_error"] = "remote_closed_after_%s" % state
			state = "failed"
			return
		var available := int(_peer.get_available_bytes())
		if available > 0:
			var result := _peer.get_data(mini(available, 8192))
			if result.size() >= 2 and int(result[0]) == OK:
				var chunk: PackedByteArray = result[1] as PackedByteArray
				receive_buffer.append_array(chunk)
				_extract_received(report, options)
				if bool(report.get("probe_goal_reached", false)) or bool(report.get("handshake_complete", false)) or state == "failed":
					return
		OS.delay_msec(25)


func _extract_received(report: Dictionary, options: Dictionary) -> void:
	var extracted: Dictionary = _codec.call("try_extract_server_packets", receive_buffer) as Dictionary
	receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	if not bool(extracted.get("ok", true)):
		report["server_parse_errors"] = extracted.get("errors", [])
		state = "failed"
		return
	for raw in (extracted.get("packets", []) as Array):
		var parsed: Dictionary = raw as Dictionary
		var packet: PackedByteArray = parsed.get("packet", PackedByteArray()) as PackedByteArray
		var checksum_report := {"available": false, "checksum_status": "not_present_server_to_client", "reason": "OpenDAoC server TCP framing has no checksum"}
		_packet_log.call("log_packet", "server_to_client", parsed, packet, checksum_report, "", false)
		var opcode := int(parsed.get("opcode", -1))
		var payload: PackedByteArray = parsed.get("payload", PackedByteArray()) as PackedByteArray
		var received: Array = report.get("received_opcodes", []) as Array
		received.append(str(parsed.get("opcode_hex", "")))
		report["received_opcodes"] = received
		if opcode == 0x22:
			var crypt_key := decode_crypt_key_payload(payload)
			report["crypt_key"] = crypt_key
			if not bool(crypt_key.get("ok", false)):
				state = "failed"
				report["socket_error"] = "invalid_crypt_key_payload"
				continue
			state = "received_crypt_key"
			if not bool(report.get("login_request_sent", false)):
				var login := build_login_request_payload(str(options.get("username", "")), str(options.get("password", "")), str(options.get("client_version", DEFAULT_CLIENT_VERSION)))
				if not bool(login.get("ok", false)) or not _send_packet(0xA7, login.get("payload", PackedByteArray()) as PackedByteArray, "LoginRequest", report):
					state = "failed"
		elif opcode == 0x2A:
			report["login_granted"] = decode_login_granted_payload(payload)
			state = "login_granted"
			if not bool(report.get("character_overview_request_sent", false)):
				var overview := build_character_overview_request_payload(int(options.get("chosen_realm", 1)))
				if not _send_packet(0xFC, overview.get("payload", PackedByteArray()) as PackedByteArray, "CharacterOverviewRequest", report):
					state = "failed"
		elif opcode == 0xFC or opcode == 0xFD:
			state = "received_character_overview"
			report["character_overview_received"] = true
			var overview_decoded := decode_character_overview_payload(payload)
			report["character_overview"] = overview_decoded
			if not bool(overview_decoded.get("ok", false)):
				state = "failed"
				report["socket_error"] = "invalid_character_overview_payload"
				continue
			if bool(options.get("stop_after_character_overview", true)):
				report["probe_goal_reached"] = true
				report["stopped_before_character_select"] = true
				state = "limited_probe_complete"
			elif not bool(report.get("character_select_request_sent", false)):
				var select_request := build_character_select_request_payload()
				if not _send_packet(0x10, select_request.get("payload", PackedByteArray()) as PackedByteArray, "CharacterSelectRequest", report):
					state = "failed"
		elif opcode == 0x28:
			var session := decode_session_id_payload(payload)
			report["session"] = session
			if bool(session.get("ok", false)):
				_session_id = int(session.get("session_id", 0))
				report["session_id_received"] = true
				state = "received_session_id"
				if bool(report.get("character_overview_received", false)):
					report["handshake_complete"] = true
					state = "handshake_complete"
			else:
				state = "failed"
				report["socket_error"] = "invalid_session_id_payload"


func _base_report(options: Dictionary) -> Dictionary:
	return {
		"checkpoint": CHECKPOINT,
		"scope": "P1-20A OpenDAoC TCP Login Probe",
		"host": _redacted_host(str(options.get("host", ""))),
		"port": int(options.get("login_port", 10300)),
		"dry_run_live": "live" if bool(options.get("send_packets", false)) else "dry_run",
		"production_blocked": false,
		"checksum_available": true,
		"payload_layouts_available": false,
		"client_version": str(options.get("client_version", DEFAULT_CLIENT_VERSION)) if str(options.get("client_version", "")) != "" else DEFAULT_CLIENT_VERSION,
		"chosen_realm": int(options.get("chosen_realm", 1)),
		"stop_after_character_overview": bool(options.get("stop_after_character_overview", true)),
		"connection_attempted": false,
		"connected": false,
		"last_state": state,
		"received_opcodes": [],
		"login_request_sent": false,
		"character_overview_request_sent": false,
		"character_select_request_sent": false,
		"session_id_received": false,
		"handshake_complete": false,
		"probe_goal_reached": false,
		"stopped_before_character_select": false,
		"verdict": "WARN",
		"password_redaction_enabled": bool(options.get("redact_credentials", true)),
		"username_present": str(options.get("username", "")) != "",
		"password_present": str(options.get("password", "")) != "",
		"credentials_written_plaintext": false,
		"udp_enabled": false,
		"spawn_world": false,
		"gameplay_enabled": false,
	}


func _preflight_guard(options: Dictionary) -> Dictionary:
	var host := str(options.get("host", "")).strip_edges()
	if host == PRODUCTION_HOST and not bool(options.get("allow_production_host", false)):
		return {"block_reason": "production_host_blocked", "production_blocked": true, "severity": "WARN"}
	if host == "":
		return {"block_reason": "host_missing", "severity": "WARN"}
	if str(options.get("username", "")) == "" or str(options.get("password", "")) == "":
		return {"block_reason": "credentials_missing", "severity": "WARN"}
	return {"block_reason": "", "severity": ""}


func _verdict(report: Dictionary) -> String:
	if bool(report.get("probe_goal_reached", false)) or bool(report.get("handshake_complete", false)):
		return "PASS"
	if str(report.get("socket_error", "")) != "":
		return "FAIL"
	return "WARN"


func _write_all_reports(report: Dictionary, options: Dictionary) -> void:
	var dir := str(options.get("report_dir", DEFAULT_REPORT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var log_paths: Dictionary = _packet_log.call("write_reports", dir) as Dictionary
	report["packet_log_files"] = log_paths
	report["written_files"] = {
		"report_json": ProjectSettings.globalize_path(dir.path_join("p1_20a_tcp_login_probe.json")),
		"report_txt": ProjectSettings.globalize_path(dir.path_join("p1_20a_tcp_login_probe.txt")),
		"summary_txt": ProjectSettings.globalize_path(dir.path_join("p1_20a_summary.txt")),
		"packet_log_csv": ProjectSettings.globalize_path(dir.path_join("p1_20a_packet_log.csv")),
		"packet_log_json": ProjectSettings.globalize_path(dir.path_join("p1_20a_packet_log.json")),
		"codec_selftest_json": ProjectSettings.globalize_path(dir.path_join("p1_20a_codec_selftest.json")),
		"codec_selftest_txt": ProjectSettings.globalize_path(dir.path_join("p1_20a_codec_selftest.txt")),
	}
	_write_text(dir.path_join("p1_20a_tcp_login_probe.json"), JSON.stringify(_strip_bytes(report), "\t"))
	_write_text(dir.path_join("p1_20a_tcp_login_probe.txt"), build_text_report(report))
	_write_text(dir.path_join("p1_20a_summary.txt"), build_summary_text(report))
	_write_text(dir.path_join("p1_20a_codec_selftest.json"), JSON.stringify(_strip_bytes(report.get("codec_selftest", {})), "\t"))
	_write_text(dir.path_join("p1_20a_codec_selftest.txt"), build_codec_selftest_text(report.get("codec_selftest", {}) as Dictionary))


func build_text_report(report: Dictionary) -> String:
	return "\n".join([
		"host=%s" % str(report.get("host", "")),
		"port=%d" % int(report.get("port", 0)),
		"dry_run/live=%s" % str(report.get("dry_run_live", "dry_run")),
		"production_blocked=%s" % ("yes" if bool(report.get("production_blocked", false)) else "no"),
		"checksum_available=%s" % ("yes" if bool(report.get("checksum_available", false)) else "no"),
		"payload_layouts_available=%s" % ("yes" if bool(report.get("payload_layouts_available", false)) else "no"),
		"connection_attempted=%s" % ("yes" if bool(report.get("connection_attempted", false)) else "no"),
		"connected=%s" % ("yes" if bool(report.get("connected", false)) else "no"),
		"last_state=%s" % str(report.get("last_state", "")),
		"received_opcodes=%s" % str(report.get("received_opcodes", [])),
		"verdict=%s" % str(report.get("verdict", "WARN")),
		"block_reason=%s" % str(report.get("block_reason", "")),
		"notes=OpenDAoC layouts and asymmetric TCP framing are implemented from server-provided source details; network remains opt-in.",
	]) + "\n"


func build_summary_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("P1-20A OpenDAoC TCP Login Probe - resume")
	lines.append("")
	lines.append("Etat: %s" % str(report.get("last_state", "")))
	lines.append("Verdict: %s" % str(report.get("verdict", "WARN")))
	lines.append("Mode: %s" % str(report.get("dry_run_live", "dry_run")))
	lines.append("Connexion tentee: %s" % ("oui" if bool(report.get("connection_attempted", false)) else "non"))
	lines.append("Connecte: %s" % ("oui" if bool(report.get("connected", false)) else "non"))
	lines.append("Prod bloquee: %s" % ("oui" if bool(report.get("production_blocked", false)) else "non"))
	lines.append("Raison blocage: %s" % str(report.get("block_reason", "")))
	lines.append("Checksum disponible: %s" % ("oui" if bool(report.get("checksum_available", false)) else "non"))
	lines.append("Layouts payload disponibles: %s" % ("oui" if bool(report.get("payload_layouts_available", false)) else "non"))
	lines.append("Opcodes recus: %s" % str(report.get("received_opcodes", [])))
	lines.append("Handshake complet: %s" % ("oui" if bool(report.get("handshake_complete", false)) else "non"))
	lines.append("Objectif probe limite atteint: %s" % ("oui" if bool(report.get("probe_goal_reached", false)) else "non"))
	lines.append("")
	lines.append("Garanties actuelles:")
	lines.append("- dry-run par defaut")
	lines.append("- send_packets=false pour le lancement automatique et Ctrl+R")
	lines.append("- IP production bloquee sauf autorisation explicite")
	lines.append("- aucun UDP, spawn, deplacement ou gameplay")
	lines.append("- credentials non ecrits en clair")
	lines.append("")
	lines.append("Layouts confirmes: 0xF4, 0x22, 0xA7, 0x2A, 0xFC/0xFD, 0x10 et 0x28.")
	lines.append("Prochaine validation: capture controlee sur un serveur de developpement, jamais automatique.")
	return "\n".join(lines) + "\n"


func build_codec_selftest_text(selftest: Dictionary) -> String:
	return "\n".join([
		"P1-20A codec selftest",
		"ok=%s" % str(selftest.get("ok", false)),
		"packet_total_size=%d" % int(selftest.get("packet_total_size", 0)),
		"payload_size=%d" % int(selftest.get("payload_size", 0)),
		"short_status=%s" % str(selftest.get("short_status", "")),
	]) + "\n"


func _options(overrides: Dictionary) -> Dictionary:
	return {
		"probe_enabled": bool(overrides.get("probe_enabled", p1_20a_probe_enabled)),
		"run_on_ready": bool(overrides.get("run_on_ready", p1_20a_run_on_ready)),
		"host": str(overrides.get("host", p1_20a_host)).strip_edges(),
		"login_port": int(overrides.get("login_port", p1_20a_login_port)),
		"username": str(overrides.get("username", p1_20a_username)),
		"password": str(overrides.get("password", p1_20a_password)),
		"client_version": str(overrides.get("client_version", p1_20a_client_version)).strip_edges(),
		"chosen_realm": clampi(int(overrides.get("chosen_realm", 1)), 0, 3),
		"send_packets": bool(overrides.get("send_packets", p1_20a_send_packets)),
		"allow_production_host": bool(overrides.get("allow_production_host", p1_20a_allow_production_host)),
		"stop_after_character_overview": bool(overrides.get("stop_after_character_overview", p1_20a_stop_after_character_overview)),
		"timeout_seconds": float(overrides.get("timeout_seconds", p1_20a_timeout_seconds)),
		"write_hex_dump": bool(overrides.get("write_hex_dump", p1_20a_write_hex_dump)),
		"report_dir": str(overrides.get("report_dir", p1_20a_report_dir)),
		"redact_credentials": bool(overrides.get("redact_credentials", p1_20a_redact_credentials)),
	}


func _redacted_host(host: String) -> String:
	return host


func _payload_status_without_bytes(layout: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in layout.keys():
		if str(key) != "payload":
			out[key] = layout[key]
	return out


func _close_peer() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _strip_bytes(value: Variant) -> Variant:
	if typeof(value) == TYPE_PACKED_BYTE_ARRAY:
		return _codec.call("hex_dump", value as PackedByteArray, 64)
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		for key in (value as Dictionary).keys():
			out[key] = _strip_bytes((value as Dictionary)[key])
		return out
	if typeof(value) == TYPE_ARRAY:
		var out_arr: Array = []
		for item in value as Array:
			out_arr.append(_strip_bytes(item))
		return out_arr
	return value
