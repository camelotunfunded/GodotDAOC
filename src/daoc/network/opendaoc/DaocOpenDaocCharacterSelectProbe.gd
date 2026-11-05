extends Node

const SelectCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterSelectCodec.gd")
const LoginProbeScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const PacketLogScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketLog.gd")

const CHECKPOINT := "P1-20B_HEYVENO_CHARACTER_SELECT_SESSION_ID_PASS"
const TARGET_NAME := "Heyvena"
const IDLE := "IDLE"
const CONNECTING := "CONNECTING"
const WAIT_CRYPT_KEY := "WAIT_CRYPT_KEY"
const WAIT_LOGIN_GRANTED := "WAIT_LOGIN_GRANTED"
const WAIT_CHARACTER_OVERVIEW := "WAIT_CHARACTER_OVERVIEW"
const READY_TO_SELECT := "READY_TO_SELECT"
const WAIT_CHARACTER_SELECT_RESPONSE := "WAIT_CHARACTER_SELECT_RESPONSE"
const WAIT_SESSION_ID := "WAIT_SESSION_ID"
const SESSION_ID_VERIFIED := "SESSION_ID_VERIFIED"
const STOPPED := "STOPPED"
const ABORTED := "ABORTED"
const FAILED := "FAILED"

@export var p1_20b_live_enabled := false
@export var p1_20b_confirm_exact_name := ""
@export var p1_20b_max_attempts := 1
@export var p1_20b_stop_after_session_id := true
@export var p1_20b_host := ""
@export var p1_20b_port := 10300
@export var p1_20b_username := ""
@export var p1_20b_password := ""
@export var p1_20b_allow_production_host := false
@export var p1_20b_timeout_seconds := 15.0

var state := IDLE
var character_select_attempt_count := 0
var character_select_write_success_count := 0
var character_select_send_count := 0
var network_send_count := 0
var _next_sequence := 0
var _receive_buffer := PackedByteArray()
var _session_id_memory := 0
var _peer: StreamPeerTCP
var _select_codec: RefCounted = SelectCodecScript.new()
var _login_probe: DaocOpenDaocTcpLoginProbe
var _packet_codec: DaocOpenDaocPacketCodec = PacketCodecScript.new()
var _checksum: DaocOpenDaocChecksum = ChecksumScript.new()
var _packet_log: DaocOpenDaocPacketLog = PacketLogScript.new()


func _ready() -> void:
	_ensure_login_probe()


func offline_validation() -> Dictionary:
	var character: Dictionary = _select_codec.fixture_heyveno()
	var validation: Dictionary = _select_codec.validate_character_select_data(character)
	var payload: PackedByteArray = _select_codec.build_character_select_payload_1125(character)
	var packet: PackedByteArray = _select_codec.build_character_select_packet_1125(character, 3, 0, 0)
	var parsed := _packet_codec.parse_client_packet(packet)
	var checksum_report := _checksum.verify_checksum(packet)
	var session_packet := _packet_codec.build_server_packet(0x28, PackedByteArray([0x34, 0x12]))
	var session: Dictionary = _select_codec.decode_session_id_packet(session_packet)
	return {
		"ok": bool(validation.get("ok", false)) and payload.is_empty() and bool(parsed.get("ok", false)) and int(parsed.get("opcode", -1)) == 0x10 and bool(checksum_report.get("ok", false)) and bool(session.get("ok", false)) and int(session.get("session_id", 0)) == 0x1234,
		"character_validation": validation,
		"payload_size": payload.size(), "packet_size": packet.size(),
		"checksum": checksum_report, "session_decoder": _redact_session(session),
	}


func preflight_guard(overview: Dictionary, options: Dictionary) -> Dictionary:
	if not bool(options.get("live_enabled", p1_20b_live_enabled)):
		return {"ok": false, "verdict": "ABORTED_CONFIRMATION_MISSING", "reason": "live_flag_false"}
	if str(options.get("confirm_exact_name", p1_20b_confirm_exact_name)) != TARGET_NAME:
		return {"ok": false, "verdict": "ABORTED_CONFIRMATION_MISSING", "reason": "exact_confirmation_missing"}
	if not bool(options.get("login_granted", false)) or not bool(options.get("overview_received", false)):
		return {"ok": false, "verdict": "ABORTED_CONFIGURATION_MISSING", "reason": "login_or_overview_missing"}
	if character_select_attempt_count != 0 or character_select_send_count != 0:
		return {"ok": false, "verdict": "ABORTED_CONFIGURATION_MISSING", "reason": "attempt_already_claimed"}
	var selected: Dictionary = _select_codec.select_heyveno_from_overview(overview)
	if not bool(selected.get("ok", false)):
		return selected
	selected["confirmation_valid"] = true
	selected["heyveno_selected_locally"] = true
	return selected


func claim_single_character_select_attempt(guard: Dictionary) -> bool:
	if not bool(guard.get("ok", false)) or character_select_attempt_count != 0 or character_select_send_count != 0:
		return false
	if p1_20b_max_attempts != 1:
		return false
	character_select_attempt_count = 1
	return true


func record_character_select_write(error: int) -> bool:
	if character_select_attempt_count != 1 or character_select_write_success_count != 0 or character_select_send_count != 0:
		return false
	if error != OK:
		return false
	character_select_write_success_count = 1
	character_select_send_count = 1
	return true


func emulate_server_handler(allow_direct_session: bool = true, include_login_granted: bool = true) -> Dictionary:
	var simulated_state := WAIT_CHARACTER_SELECT_RESPONSE
	var received: Array[String] = []
	if include_login_granted:
		received.append("0x2A")
		simulated_state = WAIT_SESSION_ID
	elif not allow_direct_session:
		return {"ok": false, "state": simulated_state, "received_opcodes": received}
	var packet := _packet_codec.build_server_packet(0x28, PackedByteArray([0x34, 0x12]))
	var decoded: Dictionary = _select_codec.decode_session_id_packet(packet)
	received.append("0x28")
	if bool(decoded.get("ok", false)):
		simulated_state = SESSION_ID_VERIFIED
	return {"ok": bool(decoded.get("ok", false)), "state": simulated_state, "received_opcodes": received, "session": _redact_session(decoded)}


func safety_snapshot() -> Dictionary:
	return {
		"live_enabled": p1_20b_live_enabled,
		"character_select_attempt_count": character_select_attempt_count,
		"character_select_write_success_count": character_select_write_success_count,
		"character_select_send_count": character_select_send_count,
		"character_create_send_count": 0,
		"world_init_sent": false,
		"udp_enabled": false,
		"world_entry_sent": false,
		"automatic_retry": false,
	}


func run_controlled_live(overrides: Dictionary = {}) -> Dictionary:
	_reset()
	_ensure_login_probe()
	var options := _options(overrides)
	var report := _base_report()
	var offline := offline_validation()
	report["offline_validation"] = offline
	if not bool(offline.get("ok", false)):
		report["verdict"] = "ABORTED_OFFLINE_VALIDATION_FAILED"
		state = ABORTED
		return _finish(report, options)
	if not bool(options.get("live_enabled", false)) or str(options.get("confirm_exact_name", "")) != TARGET_NAME:
		report["verdict"] = "ABORTED_CONFIRMATION_MISSING"
		state = ABORTED
		return _finish(report, options)
	if str(options.get("host", "")) == "" or str(options.get("username", "")) == "" or str(options.get("password", "")) == "":
		report["verdict"] = "ABORTED_CONFIGURATION_MISSING"
		state = ABORTED
		return _finish(report, options)
	if str(options.get("host", "")) == "135.125.201.202" and not bool(options.get("allow_production_host", false)):
		report["verdict"] = "ABORTED_CONFIGURATION_MISSING"
		state = ABORTED
		return _finish(report, options)
	state = CONNECTING
	report["connection_attempted"] = true
	_peer = StreamPeerTCP.new()
	var connect_error := _peer.connect_to_host(str(options.get("host", "")), int(options.get("port", 10300)))
	if connect_error != OK:
		report["verdict"] = "FAILED_DISCONNECTED"
		state = FAILED
		return _finish(report, options)
	var deadline := Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			report["connected"] = true
			break
		if _peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			report["verdict"] = "FAILED_DISCONNECTED"
			state = FAILED
			return _finish(report, options)
		OS.delay_msec(20)
	if not bool(report.get("connected", false)):
		report["verdict"] = "FAILED_DISCONNECTED"
		state = FAILED
		return _finish(report, options)
	var crypt := _login_probe.build_crypt_key_request_payload("1.125a")
	if not _send_protocol_packet(0xF4, crypt.get("payload", PackedByteArray()) as PackedByteArray, "CryptKeyRequest", report):
		report["verdict"] = "FAILED_DISCONNECTED"
		state = FAILED
		return _finish(report, options)
	state = WAIT_CRYPT_KEY
	deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline and state not in [STOPPED, ABORTED, FAILED]:
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			report["verdict"] = "FAILED_DISCONNECTED"
			state = FAILED
			break
		var available := _peer.get_available_bytes()
		if available > 0:
			var read_result := _peer.get_data(mini(available, 8192))
			if read_result.size() >= 2 and int(read_result[0]) == OK:
				_receive_buffer.append_array(read_result[1] as PackedByteArray)
				_handle_received(report, options)
				deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
		OS.delay_msec(20)
	if state not in [STOPPED, ABORTED, FAILED]:
		report["verdict"] = "FAILED_TIMEOUT_WAITING_LOGIN_GRANTED" if state in [WAIT_CRYPT_KEY, WAIT_LOGIN_GRANTED] else "FAILED_TIMEOUT_WAITING_SESSION_ID"
		state = FAILED
	return _finish(report, options)


func _handle_received(report: Dictionary, options: Dictionary) -> void:
	var extracted := _packet_codec.try_extract_server_packets(_receive_buffer)
	_receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	if not bool(extracted.get("ok", true)):
		report["verdict"] = "FAILED_SESSION_ID_PACKET_INVALID"
		state = FAILED
		return
	for raw in extracted.get("packets", []) as Array:
		var parsed := raw as Dictionary
		var packet := parsed.get("packet", PackedByteArray()) as PackedByteArray
		var opcode := int(parsed.get("opcode", -1))
		_packet_log.log_packet("server_to_client", parsed, packet, {"checksum_status": "not_present_server_to_client"}, "", true)
		(report["received_opcodes"] as Array).append("0x%02X" % opcode)
		var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
		if opcode == 0x22 and state == WAIT_CRYPT_KEY:
			if not bool(_login_probe.decode_crypt_key_payload(payload).get("ok", false)):
				report["verdict"] = "FAILED_DISCONNECTED"
				state = FAILED
				return
			var login := _login_probe.build_login_request_payload(str(options.get("username", "")), str(options.get("password", "")), "1.125a")
			if not _send_protocol_packet(0xA7, login.get("payload", PackedByteArray()) as PackedByteArray, "LoginRequest", report):
				report["verdict"] = "FAILED_DISCONNECTED"
				state = FAILED
				return
			state = WAIT_LOGIN_GRANTED
		elif opcode == 0x2A and state == WAIT_LOGIN_GRANTED:
			if not bool(_login_probe.decode_login_granted_payload(payload).get("ok", false)):
				report["verdict"] = "FAILED_TIMEOUT_WAITING_LOGIN_GRANTED"
				state = FAILED
				return
			report["login_granted"] = true
			if not _send_protocol_packet(0xFC, PackedByteArray([1]), "CharacterOverviewRequest Albion", report):
				report["verdict"] = "FAILED_DISCONNECTED"
				state = FAILED
				return
			state = WAIT_CHARACTER_OVERVIEW
		elif (opcode == 0xFC or opcode == 0xFD) and state == WAIT_CHARACTER_OVERVIEW:
			var overview := _login_probe.decode_character_overview_payload(payload)
			if not bool(overview.get("ok", false)):
				report["verdict"] = "ABORTED_HEYVENO_NOT_FOUND"
				state = ABORTED
				return
			report["overview_received"] = true
			report["overview"] = overview
			var guard := preflight_guard(overview, {"live_enabled": true, "confirm_exact_name": str(options.get("confirm_exact_name", "")), "login_granted": true, "overview_received": true})
			report["heyveno_match_count"] = int(guard.get("heyveno_match_count", 0))
			if not bool(guard.get("ok", false)):
				report["verdict"] = str(guard.get("verdict", "ABORTED_CHARACTER_DATA_MISMATCH"))
				state = ABORTED
				return
			var selected := guard.get("character", {}) as Dictionary
			_copy_character_fields(report, selected)
			report["heyveno_selected_locally"] = true
			report["confirmation_valid"] = true
			state = READY_TO_SELECT
			if not claim_single_character_select_attempt(guard):
				report["verdict"] = "ABORTED_CONFIGURATION_MISSING"
				state = ABORTED
				return
			if not _write_character_select(selected, report):
				report["verdict"] = "FAILED_CHARACTER_SELECT_WRITE"
				state = FAILED
				return
			state = WAIT_CHARACTER_SELECT_RESPONSE
		elif opcode == 0x2A and state == WAIT_CHARACTER_SELECT_RESPONSE:
			report["post_select_login_granted_received"] = true
			state = WAIT_SESSION_ID
		elif opcode == 0x28 and state in [WAIT_CHARACTER_SELECT_RESPONSE, WAIT_SESSION_ID]:
			var decoded: Dictionary = _select_codec.decode_session_id_packet(packet)
			if not bool(decoded.get("ok", false)):
				report["verdict"] = "FAILED_SESSION_ID_PACKET_INVALID"
				state = FAILED
				return
			_session_id_memory = int(decoded.get("session_id", 0))
			report.merge(_redact_session(decoded), true)
			report["server_session_granted"] = true
			report["verdict"] = "PASS_SESSION_ID_RECEIVED"
			state = SESSION_ID_VERIFIED
			report["session_id_verified_state_reached"] = true
			state = STOPPED
			return


func _send_protocol_packet(opcode: int, payload: PackedByteArray, note: String, report: Dictionary) -> bool:
	if opcode not in [0xF4, 0xA7, 0xFC] or _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var sequence := _next_sequence & 0xffff
	_next_sequence = (_next_sequence + 1) & 0xffff
	var unsigned := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, 0)
	var checksum_value := _checksum.compute_checksum(unsigned.slice(0, unsigned.size() - 2))
	var packet := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, checksum_value)
	var error := _peer.put_data(packet)
	_packet_log.log_packet("client_to_server", _packet_codec.parse_client_packet(packet), packet, _checksum.verify_checksum(packet), note, true)
	if error != OK:
		return false
	network_send_count += 1
	(report["sent_opcodes"] as Array).append("0x%02X" % opcode)
	return true


func _write_character_select(character: Dictionary, report: Dictionary) -> bool:
	if _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or character_select_attempt_count != 1:
		return false
	var packet: PackedByteArray = _select_codec.build_character_select_packet_1125(character, _next_sequence & 0xffff, 0, 0)
	_next_sequence = (_next_sequence + 1) & 0xffff
	var error := _peer.put_data(packet)
	_packet_log.log_packet("client_to_server", _packet_codec.parse_client_packet(packet), packet, _checksum.verify_checksum(packet), "CharacterSelectRequest", true)
	if not record_character_select_write(error):
		return false
	network_send_count += 1
	(report["sent_opcodes"] as Array).append("0x10")
	report["character_select_sent"] = true
	return true


func _copy_character_fields(report: Dictionary, character: Dictionary) -> void:
	report["heyveno_found"] = true
	report["heyveno_slot"] = int(character.get("slot", -1))
	report["heyveno_realm"] = int(character.get("realm_id", 0))
	report["heyveno_race"] = str(character.get("race_name", ""))
	report["heyveno_class"] = str(character.get("class_name", ""))
	report["heyveno_gender"] = "female" if ((int(character.get("race_and_gender", 0)) >> 4) & 1) == 1 else "unknown"


func _redact_session(decoded: Dictionary) -> Dictionary:
	return {
		"session_id_received": bool(decoded.get("ok", false)),
		"session_id_payload_size": int(decoded.get("session_id_payload_size", 0)),
		"session_id_nonzero": bool(decoded.get("session_id_nonzero", false)),
		"session_id_value_redacted": true,
		"session_id_checksum_status": str(decoded.get("checksum_status", "not_present_server_to_client")),
	}


func _base_report() -> Dictionary:
	return {
		"checkpoint": CHECKPOINT, "connected": false, "login_granted": false,
		"overview_received": false, "heyveno_found": false, "heyveno_match_count": 0,
		"heyveno_slot": -1, "heyveno_realm": 0, "heyveno_race": "", "heyveno_class": "", "heyveno_gender": "",
		"heyveno_selected_locally": false, "confirmation_valid": false,
		"character_select_attempt_count": 0, "character_select_write_success_count": 0,
		"character_select_send_count": 0, "character_select_sent": false,
		"received_opcodes": [], "sent_opcodes": [], "post_select_login_granted_received": false,
		"session_id_received": false, "session_id_payload_size": 0, "session_id_nonzero": false,
		"session_id_value_redacted": true, "server_session_granted": false,
		"heyveno_instantiated_server_side": false, "heyveno_world_entry_verified": false,
		"character_create_sent": false, "character_create_send_count": 0,
		"world_init_sent": false, "udp_enabled": false, "world_entry_sent": false,
		"connection_attempted": false, "verdict": "ABORTED_CONFIGURATION_MISSING",
	}


func _options(overrides: Dictionary) -> Dictionary:
	return {
		"live_enabled": bool(overrides.get("live_enabled", p1_20b_live_enabled)),
		"confirm_exact_name": str(overrides.get("confirm_exact_name", p1_20b_confirm_exact_name)),
		"host": str(overrides.get("host", p1_20b_host)), "port": int(overrides.get("port", p1_20b_port)),
		"username": str(overrides.get("username", p1_20b_username)), "password": str(overrides.get("password", p1_20b_password)),
		"allow_production_host": bool(overrides.get("allow_production_host", p1_20b_allow_production_host)),
		"timeout_seconds": float(overrides.get("timeout_seconds", p1_20b_timeout_seconds)),
		"report_dir": str(overrides.get("report_dir", "res://reports/p1_20b_live_heyveno_session_id")),
	}


func _finish(report: Dictionary, options: Dictionary) -> Dictionary:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	report["final_state"] = state
	report["character_select_attempt_count"] = character_select_attempt_count
	report["character_select_write_success_count"] = character_select_write_success_count
	report["character_select_send_count"] = character_select_send_count
	report["network_send_count"] = network_send_count
	report["credentials_written"] = false
	report["session_id_value_redacted"] = true
	_write_reports(report, str(options.get("report_dir", "res://reports/p1_20b_live_heyveno_session_id")))
	return report.duplicate(true)


func _write_reports(report: Dictionary, report_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var persisted := report.duplicate(true)
	var overview := persisted.get("overview", {}) as Dictionary
	persisted.erase("overview")
	_write_json(report_dir.path_join("p1_20b_live_report.json"), persisted)
	_write_text(report_dir.path_join("p1_20b_live_report.txt"), _summary(report))
	_write_text(report_dir.path_join("p1_20b_packet_log.csv"), _packet_log.build_csv())
	_write_json(report_dir.path_join("p1_20b_overview_received.json"), overview)
	_write_text(report_dir.path_join("p1_20b_summary.txt"), _summary(report))


func _summary(report: Dictionary) -> String:
	return "\n".join([
		"P1-20B controlled CharacterSelect / SessionID",
		"verdict=%s final_state=%s" % [str(report.get("verdict", "")), str(report.get("final_state", state))],
		"connected=%s login_granted=%s overview_received=%s" % [str(report.get("connected", false)), str(report.get("login_granted", false)), str(report.get("overview_received", false))],
		"heyveno_found=%s slot=%d selected_locally=%s" % [str(report.get("heyveno_found", false)), int(report.get("heyveno_slot", -1)), str(report.get("heyveno_selected_locally", false))],
		"character_select_attempt_count=%d write_success_count=%d send_count=%d" % [character_select_attempt_count, character_select_write_success_count, character_select_send_count],
		"received_opcodes=%s" % JSON.stringify(report.get("received_opcodes", [])),
		"session_id_received=%s payload_size=%d nonzero=%s value_redacted=true" % [str(report.get("session_id_received", false)), int(report.get("session_id_payload_size", 0)), str(report.get("session_id_nonzero", false))],
		"character_create_send_count=0 world_init_sent=false udp_enabled=false world_entry_sent=false",
		"heyveno_instantiated_server_side=false heyveno_world_entry_verified=false",
	]) + "\n"


func _reset() -> void:
	state = IDLE
	character_select_attempt_count = 0
	character_select_write_success_count = 0
	character_select_send_count = 0
	network_send_count = 0
	_next_sequence = 0
	_receive_buffer = PackedByteArray()
	_session_id_memory = 0
	_packet_log.clear()


func _ensure_login_probe() -> void:
	if _login_probe == null:
		_login_probe = LoginProbeScript.new() as DaocOpenDaocTcpLoginProbe
		add_child(_login_probe)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
