extends Node

const WorldCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocWorldInitCodec.gd")
const CaptureScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocWorldBootstrapCapture.gd")
const SelectCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterSelectCodec.gd")
const LoginProbeScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const CHECKPOINT := "P1-20C_HEYVENO_WORLDINIT_TCP_BOOTSTRAP_CAPTURE"
const TARGET_NAME := "Heyvena"
const IDLE := "IDLE"
const CONNECTING := "CONNECTING"
const WAIT_CRYPT_KEY := "WAIT_CRYPT_KEY"
const WAIT_LOGIN_GRANTED := "WAIT_LOGIN_GRANTED"
const WAIT_OVERVIEW := "WAIT_OVERVIEW"
const READY_TO_SELECT := "READY_TO_SELECT"
const WAIT_SESSION_ID := "WAIT_SESSION_ID"
const READY_TO_WORLD_INIT := "READY_TO_WORLD_INIT"
const WAIT_WORLD_BOOTSTRAP := "WAIT_WORLD_BOOTSTRAP"
const POSITION_AND_OBJECT_ID_RECEIVED := "POSITION_AND_OBJECT_ID_RECEIVED"
const BOOTSTRAP_CAPTURED := "BOOTSTRAP_CAPTURED"
const DISCONNECTING := "DISCONNECTING"
const STOPPED := "STOPPED"
const ABORTED := "ABORTED"
const FAILED := "FAILED"

@export var p1_20c_live_enabled: bool = false
@export var p1_20c_confirm_exact_name: String = ""
@export var p1_20c_max_worldinit_attempts: int = 1
@export var p1_20c_stop_before_game_open: bool = true
@export var p1_20c_host := ""
@export var p1_20c_port := 10300
@export var p1_20c_username := ""
@export var p1_20c_password := ""
@export var p1_20c_allow_production_host := false
@export var p1_20c_timeout_seconds := 15.0

var state := IDLE
var world_init_attempt_count := 0
var world_init_write_success_count := 0
var world_init_send_count := 0
var character_select_send_count := 0
var network_send_count := 0
var _next_sequence := 0
var _receive_buffer := PackedByteArray()
var _session_id_memory := 0
var _peer: StreamPeerTCP
var _world_sent_ticks := 0
var _world_packet_redacted := {}
var _world_codec: RefCounted = WorldCodecScript.new()
var _capture: RefCounted = CaptureScript.new()
var _select_codec: RefCounted = SelectCodecScript.new()
var _login_probe: DaocOpenDaocTcpLoginProbe
var _packet_codec: DaocOpenDaocPacketCodec = PacketCodecScript.new()
var _checksum: DaocOpenDaocChecksum = ChecksumScript.new()


func _ready() -> void:
	_ensure_login_probe()


func offline_validation() -> Dictionary:
	var character: Dictionary = _select_codec.call("fixture_heyveno") as Dictionary
	var payload: PackedByteArray = _world_codec.call("build_world_init_payload_1125", character) as PackedByteArray
	var packet: PackedByteArray = _world_codec.call("build_world_init_packet_1125", character, 7, 0x1234, 0) as PackedByteArray
	var decoded: Dictionary = _world_codec.call("decode_world_init_packet_1125", packet) as Dictionary
	var named_select: PackedByteArray = _select_codec.call("build_character_select_payload_named_1125", character) as PackedByteArray
	var fixture := _build_fixture_burst()
	var replay: Dictionary = fixture.get("replay", {}) as Dictionary
	return {
		"ok": payload == PackedByteArray([0]) and packet.size() == 13 and bool(decoded.get("ok", false)) and int(decoded.get("session_id", 0)) == 0x1234 and named_select.size() == 26 and bool(replay.get("ok", false)) and int(replay.get("packet_count", 0)) == 5,
		"worldinit_codec": "PASS" if payload == PackedByteArray([0]) and packet.size() == 13 and bool(decoded.get("ok", false)) else "FAIL",
		"session_id_header_injection": "PASS" if int(decoded.get("session_id", 0)) == 0x1234 else "FAIL",
		"bootstrap_capture_replay": "PASS" if bool(replay.get("ok", false)) else "FAIL",
		"fixture_checksum": int(decoded.get("checksum", 0)), "packet_size": packet.size(),
		"named_character_select_1125_source_branch": named_select.size() == 26,
	}


func preflight_guard(overview: Dictionary, options: Dictionary) -> Dictionary:
	if not bool(options.get("live_enabled", p1_20c_live_enabled)) or str(options.get("confirm_exact_name", p1_20c_confirm_exact_name)) != TARGET_NAME:
		return {"ok": false, "verdict": "ABORTED_CONFIRMATION_MISSING"}
	if not p1_20c_stop_before_game_open or p1_20c_max_worldinit_attempts != 1:
		return {"ok": false, "verdict": "ABORTED_CONFIGURATION_MISSING"}
	if not bool(options.get("login_granted", false)) or not bool(options.get("overview_received", false)):
		return {"ok": false, "verdict": "ABORTED_CONFIGURATION_MISSING"}
	if world_init_attempt_count != 0 or world_init_send_count != 0:
		return {"ok": false, "verdict": "ABORTED_CONFIGURATION_MISSING"}
	var selected: Dictionary = _select_codec.call("select_heyveno_from_overview", overview) as Dictionary
	if not bool(selected.get("ok", false)):
		var verdict := str(selected.get("verdict", "ABORTED_CHARACTER_DATA_MISMATCH"))
		if verdict in ["ABORTED_DUPLICATE_HEYVENO", "ABORTED_SLOT_MISMATCH"]:
			verdict = "ABORTED_CHARACTER_DATA_MISMATCH"
		selected["verdict"] = verdict
		return selected
	return selected


func claim_single_world_init_attempt(guard_ok: bool) -> bool:
	if not guard_ok or world_init_attempt_count != 0 or world_init_send_count != 0 or p1_20c_max_worldinit_attempts != 1:
		return false
	world_init_attempt_count = 1
	return true


func record_world_init_write(error: int) -> bool:
	if world_init_attempt_count != 1 or world_init_write_success_count != 0 or world_init_send_count != 0:
		return false
	if error != OK:
		return false
	world_init_write_success_count = 1
	world_init_send_count = 1
	return true


func safety_snapshot() -> Dictionary:
	return {"world_init_attempt_count": world_init_attempt_count, "world_init_write_success_count": world_init_write_success_count, "world_init_send_count": world_init_send_count, "game_open_sent": false, "character_create_send_count": 0, "udp_enabled": false, "movement_sent": false, "automatic_retry": false}


func run_controlled_live(overrides: Dictionary = {}) -> Dictionary:
	_reset()
	_ensure_login_probe()
	var options := _options(overrides)
	var report := _base_report()
	var offline := offline_validation()
	report["offline_validation"] = offline
	if not bool(offline.get("ok", false)):
		return _abort_finish(report, options, "ABORTED_OFFLINE_VALIDATION_FAILED")
	if not bool(options.get("live_enabled", false)) or str(options.get("confirm_exact_name", "")) != TARGET_NAME:
		return _abort_finish(report, options, "ABORTED_CONFIRMATION_MISSING")
	if str(options.get("host", "")) == "" or str(options.get("username", "")) == "" or str(options.get("password", "")) == "":
		return _abort_finish(report, options, "ABORTED_CONFIGURATION_MISSING")
	if str(options.get("host", "")) == "135.125.201.202" and not bool(options.get("allow_production_host", false)):
		return _abort_finish(report, options, "ABORTED_CONFIGURATION_MISSING")
	state = CONNECTING
	_peer = StreamPeerTCP.new()
	if _peer.connect_to_host(str(options.get("host", "")), int(options.get("port", 10300))) != OK:
		return _fail_finish(report, options, "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP")
	var deadline := Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			report["connected"] = true
			break
		if _peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			return _fail_finish(report, options, "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP")
		OS.delay_msec(20)
	if not bool(report.get("connected", false)):
		return _fail_finish(report, options, "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP")
	var crypt := _login_probe.build_crypt_key_request_payload("1.125a")
	if not _send_protocol_packet(0xF4, crypt.get("payload", PackedByteArray()) as PackedByteArray, report):
		return _fail_finish(report, options, "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP")
	state = WAIT_CRYPT_KEY
	deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while state not in [STOPPED, ABORTED, FAILED]:
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			if state in [WAIT_WORLD_BOOTSTRAP, POSITION_AND_OBJECT_ID_RECEIVED] and int(report.get("post_worldinit_packet_count", 0)) > 0:
				_finalize_capture_verdict(report)
			else:
				report["verdict"] = "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"
				state = FAILED
			break
		var available := _peer.get_available_bytes()
		if available > 0:
			var read_result := _peer.get_data(mini(available, 65536))
			if read_result.size() >= 2 and int(read_result[0]) == OK:
				_receive_buffer.append_array(read_result[1] as PackedByteArray)
				_handle_received(report, options)
				if state not in [WAIT_WORLD_BOOTSTRAP, POSITION_AND_OBJECT_ID_RECEIVED]:
					deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
		if state in [WAIT_WORLD_BOOTSTRAP, POSITION_AND_OBJECT_ID_RECEIVED]:
			var now := Time.get_ticks_msec()
			if bool(_capture.call("has_position_alias")) and now - int(_capture.get("last_packet_ticks")) >= 2000:
				_finalize_capture_verdict(report)
			elif now - _world_sent_ticks >= 8000:
				_finalize_capture_verdict(report)
			elif str(_capture.get("limit_reason")) != "":
				_finalize_capture_verdict(report)
		elif _tick_extension(report):
			pass
		elif Time.get_ticks_msec() >= deadline:
			report["verdict"] = "FAILED_TIMEOUT_NO_BOOTSTRAP" if world_init_send_count == 1 else "ABORTED_SESSION_ID_MISSING"
			state = FAILED
		OS.delay_msec(20)
	return _finish(report, options)


## Extension hook used by the next protocol checkpoint without changing the
## validated P1-20C behaviour.
func _tick_extension(_report: Dictionary) -> bool:
	return false


func _handle_received(report: Dictionary, options: Dictionary) -> void:
	var extracted := _packet_codec.try_extract_server_packets(_receive_buffer)
	_receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	if not bool(extracted.get("ok", true)):
		report["verdict"] = "FAILED_POSITION_PACKET_INVALID" if world_init_send_count == 1 else "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"
		state = FAILED
		return
	for raw in extracted.get("packets", []) as Array:
		var parsed := raw as Dictionary
		var packet := parsed.get("packet", PackedByteArray()) as PackedByteArray
		var opcode := int(parsed.get("opcode", -1))
		(report["received_opcodes"] as Array).append("0x%02X" % opcode)
		if state in [WAIT_WORLD_BOOTSTRAP, POSITION_AND_OBJECT_ID_RECEIVED]:
			var relative := Time.get_ticks_msec() - _world_sent_ticks
			var added: Dictionary = _capture.call("add_server_packet", packet, relative) as Dictionary
			if bool(added.get("ok", false)):
				report["post_worldinit_packet_count"] = int(_capture.get("packets").size())
				report["post_worldinit_total_bytes"] = int(_capture.get("total_bytes"))
				(report["post_worldinit_received_opcodes"] as Array).append("0x%02X" % opcode)
				if opcode in [0x88, 0x20]:
					state = POSITION_AND_OBJECT_ID_RECEIVED
					report["position_packet_0x88_received"] = bool(_capture.call("has_primary_position"))
					report["position_packet_alias_received"] = true
			continue
		var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
		if opcode == 0x22 and state == WAIT_CRYPT_KEY:
			if not bool(_login_probe.decode_crypt_key_payload(payload).get("ok", false)):
				report["verdict"] = "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"; state = FAILED; return
			var login := _login_probe.build_login_request_payload(str(options.get("username", "")), str(options.get("password", "")), "1.125a")
			if not _send_protocol_packet(0xA7, login.get("payload", PackedByteArray()) as PackedByteArray, report):
				report["verdict"] = "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"; state = FAILED; return
			state = WAIT_LOGIN_GRANTED
		elif opcode == 0x2A and state == WAIT_LOGIN_GRANTED:
			report["login_granted"] = true
			if not _send_protocol_packet(0xFC, PackedByteArray([1]), report):
				report["verdict"] = "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"; state = FAILED; return
			state = WAIT_OVERVIEW
		elif opcode in [0xFC, 0xFD] and state == WAIT_OVERVIEW:
			var overview := _login_probe.decode_character_overview_payload(payload)
			if not bool(overview.get("ok", false)):
				report["verdict"] = "ABORTED_HEYVENO_NOT_FOUND"; state = ABORTED; return
			report["overview_received"] = true
			var guard := preflight_guard(overview, {"live_enabled": true, "confirm_exact_name": str(options.get("confirm_exact_name", "")), "login_granted": true, "overview_received": true})
			if not bool(guard.get("ok", false)):
				report["verdict"] = str(guard.get("verdict", "ABORTED_CHARACTER_DATA_MISMATCH")); state = ABORTED; return
			var character := guard.get("character", {}) as Dictionary
			_copy_character_fields(report, character)
			state = READY_TO_SELECT
			if not _write_character_select(character, report):
				report["verdict"] = "FAILED_DISCONNECTED_BEFORE_BOOTSTRAP"; state = FAILED; return
			state = WAIT_SESSION_ID
		elif opcode == 0x2A and state == WAIT_SESSION_ID:
			report["post_select_login_granted_received"] = true
		elif opcode == 0x28 and state == WAIT_SESSION_ID:
			var decoded: Dictionary = _select_codec.call("decode_session_id_packet", packet) as Dictionary
			if not bool(decoded.get("ok", false)) or not bool(decoded.get("session_id_nonzero", false)):
				report["verdict"] = "ABORTED_SESSION_ID_MISSING"; state = ABORTED; return
			_session_id_memory = int(decoded.get("session_id", 0))
			report["session_id_received"] = true
			report["session_id_nonzero"] = true
			state = READY_TO_WORLD_INIT
			if not claim_single_world_init_attempt(true):
				report["verdict"] = "ABORTED_CONFIGURATION_MISSING"; state = ABORTED; return
			if not _write_world_init(report):
				report["verdict"] = "FAILED_WORLDINIT_WRITE"; state = FAILED; return
			state = WAIT_WORLD_BOOTSTRAP


func _send_protocol_packet(opcode: int, payload: PackedByteArray, report: Dictionary) -> bool:
	if opcode not in [0xF4, 0xA7, 0xFC] or _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var sequence := _next_sequence & 0xffff
	_next_sequence = (_next_sequence + 1) & 0xffff
	var unsigned := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, 0)
	var checksum_value := _checksum.compute_checksum(unsigned.slice(0, unsigned.size() - 2))
	var packet := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, checksum_value)
	if _peer.put_data(packet) != OK:
		return false
	network_send_count += 1
	(report["sent_opcodes"] as Array).append("0x%02X" % opcode)
	return true


func _write_character_select(character: Dictionary, report: Dictionary) -> bool:
	if character_select_send_count != 0 or _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var packet: PackedByteArray = _select_codec.call("build_character_select_packet_named_1125", character, _next_sequence & 0xffff, 0, 0) as PackedByteArray
	if packet.is_empty():
		return false
	_next_sequence = (_next_sequence + 1) & 0xffff
	if _peer.put_data(packet) != OK:
		return false
	character_select_send_count = 1
	network_send_count += 1
	report["character_select_sent"] = true
	(report["sent_opcodes"] as Array).append("0x10")
	return true


func _write_world_init(report: Dictionary) -> bool:
	if _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or world_init_attempt_count != 1:
		return false
	var character := {"name": TARGET_NAME, "realm_id": 1, "slot": 5}
	var packet: PackedByteArray = _world_codec.call("build_world_init_packet_1125", character, _next_sequence & 0xffff, _session_id_memory, 0) as PackedByteArray
	if packet.size() != 13:
		return false
	var decoded: Dictionary = _world_codec.call("decode_world_init_packet_1125", packet) as Dictionary
	if not bool(decoded.get("ok", false)) or int(decoded.get("session_id", 0)) != _session_id_memory:
		return false
	_next_sequence = (_next_sequence + 1) & 0xffff
	var error := _peer.put_data(packet)
	if not record_world_init_write(error):
		return false
	network_send_count += 1
	report["world_init_sent"] = true
	report["session_id_injected_in_worldinit_header"] = true
	(report["sent_opcodes"] as Array).append("0xD4")
	_world_packet_redacted = {"opcode": "0xD4", "packet_size": packet.size(), "payload_size": 1, "sequence": int(decoded.get("sequence", 0)), "session_id_present": true, "session_id_value": "REDACTED", "checksum": "0x%04X" % int(decoded.get("checksum", 0)), "checksum_valid": true, "packet_sha256": _sha256_hex(packet)}
	_world_sent_ticks = Time.get_ticks_msec()
	_capture.call("reset", _world_sent_ticks)
	return true


func _finalize_capture_verdict(report: Dictionary) -> void:
	report["post_worldinit_packet_count"] = int(_capture.get("packets").size())
	report["post_worldinit_total_bytes"] = int(_capture.get("total_bytes"))
	report["position_packet_0x88_received"] = bool(_capture.call("has_primary_position"))
	report["position_packet_alias_received"] = bool(_capture.call("has_position_alias"))
	var position: Dictionary = _capture.call("first_position") as Dictionary
	report["position_packet_decoded"] = bool(position.get("ok", false))
	report["player_object_id_received"] = int(position.get("object_id", 0)) > 0
	report["player_region_received"] = position.has("region_id")
	report["player_coordinates_received"] = position.has("x") and position.has("y") and position.has("z")
	report["server_worldenter_reached"] = bool(_capture.call("has_position_alias"))
	report["heyveno_instantiated_server_side"] = bool(_capture.call("has_position_alias")) and int(position.get("object_id", 0)) > 0
	if bool(position.get("ok", false)):
		report["verdict"] = "PASS_WORLDINIT_POSITION_DECODED"
		state = BOOTSTRAP_CAPTURED
	elif int(report.get("post_worldinit_packet_count", 0)) > 0:
		report["verdict"] = "PASS_WORLDINIT_BOOTSTRAP_CAPTURED" if bool(_capture.call("has_position_alias")) else "PARTIAL_WORLDINIT_BURST_WITHOUT_POSITION"
		state = BOOTSTRAP_CAPTURED
	else:
		report["verdict"] = "FAILED_TIMEOUT_NO_BOOTSTRAP"
		state = FAILED
	if state == BOOTSTRAP_CAPTURED:
		state = DISCONNECTING
		state = STOPPED


func _copy_character_fields(report: Dictionary, character: Dictionary) -> void:
	report["heyveno_found"] = true
	report["heyveno_slot"] = int(character.get("slot", -1))
	report["heyveno_realm"] = int(character.get("realm_id", 0))
	report["heyveno_race"] = str(character.get("race_name", ""))
	report["heyveno_class"] = str(character.get("class_name", ""))
	report["heyveno_model"] = int(character.get("current_model", 0))
	report["heyveno_gender"] = "female" if ((int(character.get("race_and_gender", 0)) >> 4) & 1) == 1 else "unknown"


func _build_fixture_burst() -> Dictionary:
	var capture: RefCounted = CaptureScript.new()
	capture.call("reset", 1000)
	var position_payload := PackedByteArray()
	position_payload.resize(28)
	position_payload.encode_float(0, 561443.0)
	position_payload.encode_float(4, 511128.0)
	position_payload.encode_float(8, 2280.0)
	_write_u16_be(position_payload, 12, 0x1234)
	_write_u16_be(position_payload, 14, 2048)
	_write_u16_be(position_payload, 20, 51)
	var fixtures := [
		_packet_codec.build_server_packet(0x88, position_payload),
		_packet_codec.build_server_packet(0x1E, PackedByteArray([0, 1])),
		_packet_codec.build_server_packet(0xAA, PackedByteArray([1, 2, 3])),
		_packet_codec.build_server_packet(0x53, PackedByteArray([4, 5])),
		_packet_codec.build_server_packet(0xEF, PackedByteArray([9])),
	]
	for i in range(fixtures.size()):
		capture.call("add_server_packet", fixtures[i] as PackedByteArray, i * 10)
	var binary: PackedByteArray = capture.call("binary_capture") as PackedByteArray
	return {"capture": capture, "binary": binary, "replay": capture.call("replay", binary)}


func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


func _sha256_hex(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _base_report() -> Dictionary:
	return {"checkpoint": CHECKPOINT, "connected": false, "login_granted": false, "overview_received": false, "heyveno_found": false, "heyveno_slot": -1, "character_select_sent": false, "session_id_received": false, "session_id_nonzero": false, "session_id_injected_in_worldinit_header": false, "session_id_value_redacted": true, "world_init_attempt_count": 0, "world_init_write_success_count": 0, "world_init_send_count": 0, "world_init_sent": false, "post_worldinit_packet_count": 0, "post_worldinit_total_bytes": 0, "received_opcodes": [], "post_worldinit_received_opcodes": [], "sent_opcodes": [], "position_packet_0x88_received": false, "position_packet_alias_received": false, "position_packet_decoded": false, "player_object_id_received": false, "player_region_received": false, "player_coordinates_received": false, "server_worldenter_reached": false, "heyveno_instantiated_server_side": false, "game_open_sent": false, "game_open_reply_received": false, "udp_enabled": false, "movement_sent": false, "world_entry_visualized": false, "playing_state_claimed": false, "character_create_send_count": 0, "credentials_written": false, "verdict": "ABORTED_CONFIGURATION_MISSING"}


func _options(overrides: Dictionary) -> Dictionary:
	return {"live_enabled": bool(overrides.get("live_enabled", p1_20c_live_enabled)), "confirm_exact_name": str(overrides.get("confirm_exact_name", p1_20c_confirm_exact_name)), "host": str(overrides.get("host", p1_20c_host)), "port": int(overrides.get("port", p1_20c_port)), "username": str(overrides.get("username", p1_20c_username)), "password": str(overrides.get("password", p1_20c_password)), "allow_production_host": bool(overrides.get("allow_production_host", p1_20c_allow_production_host)), "timeout_seconds": float(overrides.get("timeout_seconds", p1_20c_timeout_seconds)), "report_dir": str(overrides.get("report_dir", "res://reports/p1_20c_live_heyveno_worldinit"))}


func _abort_finish(report: Dictionary, options: Dictionary, verdict: String) -> Dictionary:
	report["verdict"] = verdict; state = ABORTED; return _finish(report, options)


func _fail_finish(report: Dictionary, options: Dictionary, verdict: String) -> Dictionary:
	report["verdict"] = verdict; state = FAILED; return _finish(report, options)


func _finish(report: Dictionary, options: Dictionary) -> Dictionary:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	_session_id_memory = 0
	report["final_state"] = state
	report["world_init_attempt_count"] = world_init_attempt_count
	report["world_init_write_success_count"] = world_init_write_success_count
	report["world_init_send_count"] = world_init_send_count
	report["character_select_send_count"] = character_select_send_count
	report["network_send_count"] = network_send_count
	report["capture_burst_duration_ms"] = maxi(0, int(_capture.get("last_packet_ticks")) - _world_sent_ticks) if world_init_send_count == 1 else 0
	report["capture_window_elapsed_ms"] = maxi(0, Time.get_ticks_msec() - _world_sent_ticks) if world_init_send_count == 1 else 0
	_write_reports(report, str(options.get("report_dir", "res://reports/p1_20c_live_heyveno_worldinit")))
	return report.duplicate(true)


func _write_reports(report: Dictionary, report_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	_write_json(report_dir.path_join("p1_20c_live_report.json"), report)
	_write_text(report_dir.path_join("p1_20c_live_report.txt"), _summary(report))
	_write_text(report_dir.path_join("p1_20c_packet_log.csv"), _packet_log_csv())
	_write_text(report_dir.path_join("p1_20c_post_worldinit_opcode_inventory.csv"), _inventory_csv())
	var bin_file := FileAccess.open(report_dir.path_join("p1_20c_world_bootstrap_server_packets.bin"), FileAccess.WRITE)
	if bin_file != null:
		bin_file.store_buffer(_capture.call("binary_capture") as PackedByteArray); bin_file.close()
	_write_json(report_dir.path_join("p1_20c_world_bootstrap_replay_manifest.json"), _capture.call("manifest_redacted") as Dictionary)
	_write_json(report_dir.path_join("p1_20c_position_packet.json"), _capture.call("first_position") as Dictionary)
	_write_text(report_dir.path_join("p1_20c_summary.txt"), _summary(report))


func _packet_log_csv() -> String:
	var lines := PackedStringArray(["index,timestamp_relative_ms,direction,opcode,payload_size,packet_size,checksum_valid,classification,parser_status,packet_sha256,session_id_present,session_id_value"])
	if not _world_packet_redacted.is_empty():
		lines.append("-1,0,client_to_server,0xD4,1,%d,true,WORLD_INIT,redacted,%s,true,REDACTED" % [int(_world_packet_redacted.get("packet_size", 0)), str(_world_packet_redacted.get("packet_sha256", ""))])
	for raw in _capture.get("packets") as Array:
		var e := raw as Dictionary
		lines.append("%d,%d,server_to_client,%s,%d,%d,not_present,%s,%s,,," % [int(e.get("index", 0)), int(e.get("timestamp_relative_ms", 0)), str(e.get("opcode_hex", "")), int(e.get("payload_size", 0)), int(e.get("packet_size", 0)), str(e.get("classification", "")), str(e.get("parser_status", ""))])
	return "\n".join(lines) + "\n"


func _inventory_csv() -> String:
	var lines := PackedStringArray(["opcode,count,sizes_observed,first_order,classification,parser_existing,source_server,future_priority"])
	for raw in _capture.call("opcode_inventory") as Array:
		var r := raw as Dictionary
		lines.append("%s,%d,\"%s\",%d,%s,%s,\"%s\",%s" % [str(r.get("opcode_hex", "")), int(r.get("count", 0)), JSON.stringify(r.get("sizes", [])), int(r.get("first_order", 0)), str(r.get("classification", "")), str(r.get("parser_existing", false)), str(r.get("source", "")).replace("\"", "\"\""), str(r.get("future_priority", ""))])
	return "\n".join(lines) + "\n"


func _summary(report: Dictionary) -> String:
	return "\n".join(["P1-20C controlled WorldInit TCP bootstrap capture", "verdict=%s final_state=%s" % [str(report.get("verdict", "")), str(report.get("final_state", state))], "connected=%s login_granted=%s overview_received=%s heyveno_found=%s slot=%d" % [str(report.get("connected", false)), str(report.get("login_granted", false)), str(report.get("overview_received", false)), str(report.get("heyveno_found", false)), int(report.get("heyveno_slot", -1))], "session_id_received=%s injected=true value_redacted=true" % str(report.get("session_id_received", false)), "world_init_attempt_count=%d write_success_count=%d send_count=%d" % [world_init_attempt_count, world_init_write_success_count, world_init_send_count], "post_worldinit_packet_count=%d total_bytes=%d opcodes=%s" % [int(report.get("post_worldinit_packet_count", 0)), int(report.get("post_worldinit_total_bytes", 0)), JSON.stringify(report.get("post_worldinit_received_opcodes", []))], "position_packet_0x88_received=%s position_alias_received=%s decoded=%s object_id=%s region=%s coordinates=%s" % [str(report.get("position_packet_0x88_received", false)), str(report.get("position_packet_alias_received", false)), str(report.get("position_packet_decoded", false)), str(report.get("player_object_id_received", false)), str(report.get("player_region_received", false)), str(report.get("player_coordinates_received", false))], "game_open_sent=false udp_enabled=false movement_sent=false world_entry_visualized=false", "credentials_written=false session_id_value_redacted=true"]) + "\n"


func _reset() -> void:
	state = IDLE; world_init_attempt_count = 0; world_init_write_success_count = 0; world_init_send_count = 0; character_select_send_count = 0; network_send_count = 0; _next_sequence = 0; _receive_buffer = PackedByteArray(); _session_id_memory = 0; _world_sent_ticks = 0; _world_packet_redacted = {}; _capture.call("reset", 0)


func _ensure_login_probe() -> void:
	if _login_probe == null:
		_login_probe = LoginProbeScript.new() as DaocOpenDaocTcpLoginProbe
		add_child(_login_probe)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t")); file.close()


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value); file.close()
