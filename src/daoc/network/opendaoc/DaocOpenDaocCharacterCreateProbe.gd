extends Node
class_name DaocOpenDaocCharacterCreateProbe

const CharacterCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterCreateCodec.gd")
const DataAdapterScript = preload("res://src/daoc/ui/pregame/DaocPregameDataAdapter.gd")
const LoginProbeScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const PacketLogScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketLog.gd")

const CHECKPOINT := "P1-20CREATE-A_B_HEYVENO_CONTROLLED_LIVE_CREATE"
const TARGET_NAME := "Heyvena"

const IDLE := "IDLE"
const CONNECTING := "CONNECTING"
const WAIT_CRYPT_KEY := "WAIT_CRYPT_KEY"
const WAIT_LOGIN_GRANTED := "WAIT_LOGIN_GRANTED"
const WAIT_INITIAL_OVERVIEW := "WAIT_INITIAL_OVERVIEW"
const READY_TO_CREATE := "READY_TO_CREATE"
const WAIT_CREATE_RESPONSE := "WAIT_CREATE_RESPONSE"
const WAIT_REFRESHED_OVERVIEW := "WAIT_REFRESHED_OVERVIEW"
const CREATED_AND_VERIFIED := "CREATED_AND_VERIFIED"
const ABORTED := "ABORTED"
const FAILED := "FAILED"

@export var p1_20create_live_enabled: bool = false
@export var p1_20create_confirm_exact_name: String = ""
@export var p1_20create_max_attempts: int = 1
@export var p1_20create_stop_after_refreshed_overview: bool = true
@export var p1_20create_host: String = ""
@export var p1_20create_port: int = 10300
@export var p1_20create_username: String = ""
@export var p1_20create_password: String = ""
@export var p1_20create_allow_production_host: bool = false
@export var p1_20create_timeout_seconds: float = 15.0

var state := IDLE
var attempt_live_count := 0
var character_create_send_count := 0
var network_send_count := 0
var udp_enabled := false
var character_select_sent := false
var session_id_received := false
var world_entry_sent := false

var _character_codec: DaocOpenDaocCharacterCreateCodec = CharacterCodecScript.new()
var _adapter: DaocPregameDataAdapter = DataAdapterScript.new()
var _login_probe: DaocOpenDaocTcpLoginProbe = LoginProbeScript.new()
var _packet_codec: DaocOpenDaocPacketCodec = PacketCodecScript.new()
var _checksum: DaocOpenDaocChecksum = ChecksumScript.new()
var _packet_log: DaocOpenDaocPacketLog = PacketLogScript.new()
var _peer: StreamPeerTCP = null
var _receive_buffer := PackedByteArray()
var _next_sequence := 0


func _exit_tree() -> void:
	if _login_probe != null and is_instance_valid(_login_probe) and not _login_probe.is_inside_tree():
		_login_probe.free()


func analyze_initial_overview(raw_overview: Dictionary) -> Dictionary:
	var normalized := _adapter.normalize_character_overview(raw_overview)
	var existing_slot := -1
	var first_empty_slot := -1
	for raw in normalized.get("slots", []) as Array:
		var slot := raw as Dictionary
		var index := int(slot.get("slot_index", -1))
		if bool(slot.get("valid", false)) and str(slot.get("name", "")).to_lower() == TARGET_NAME.to_lower():
			existing_slot = index
		if first_empty_slot < 0 and not bool(slot.get("valid", false)):
			first_empty_slot = index
	return {
		"normalized": normalized,
		"overview_received": true,
		"character_count": int(normalized.get("character_count", 0)),
		"heyveno_preexisting": existing_slot >= 0,
		"heyveno_existing_slot": existing_slot,
		"first_empty_slot": first_empty_slot,
		"has_empty_slot": first_empty_slot >= 0,
	}


func offline_validation(slot_index: int = 0) -> Dictionary:
	var data := _character_codec.heyveno_fixture(slot_index)
	var validation := _character_codec.validate_character_create_data_1125(data)
	var payload := _character_codec.build_character_create_payload_1125(data)
	var decoded := _character_codec.decode_character_create_payload_for_test_1125(payload)
	var round_trip_ok := bool(decoded.get("ok", false)) \
		and str(decoded.get("name", "")) == TARGET_NAME \
		and int(decoded.get("slot_index", -1)) == slot_index \
		and int(decoded.get("realm_id", 0)) == 1 \
		and int(decoded.get("race_id", 0)) == 2 \
		and int(decoded.get("class_id", 0)) == 7 \
		and int(decoded.get("female_bit", 0)) == 1 \
		and int(decoded.get("creation_model", 0)) == 65
	return {
		"ok": bool(validation.get("ok", false)) and round_trip_ok,
		"validation": validation,
		"round_trip_ok": round_trip_ok,
		"decoded": decoded,
		"payload_size": payload.size(),
		"offset_map": _character_codec.describe_payload_offsets_1125(payload),
		"offline_codec_verdict": "PASS" if bool(validation.get("ok", false)) and round_trip_ok else "FAIL",
		"live_send_performed": false,
	}


func preflight_guard(raw_overview: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var live_enabled := bool(overrides.get("live_enabled", p1_20create_live_enabled))
	var confirmation := str(overrides.get("confirm_exact_name", p1_20create_confirm_exact_name))
	var login_granted := bool(overrides.get("login_granted", false))
	var overview_received := bool(overrides.get("overview_received", false))
	var max_attempts := int(overrides.get("max_attempts", p1_20create_max_attempts))
	var overview := analyze_initial_overview(raw_overview)
	var empty_slot := int(overview.get("first_empty_slot", -1))
	var offline := offline_validation(maxi(empty_slot, 0))
	var reason := ""
	var verdict := "ABORTED_CONFIRMATION_MISSING"
	if not bool(offline.get("ok", false)):
		reason = "offline_validation_failed"
		verdict = "ABORTED_OFFLINE_VALIDATION_FAILED"
	elif not live_enabled or confirmation != TARGET_NAME:
		reason = "exact_confirmation_missing"
		verdict = "ABORTED_CONFIRMATION_MISSING"
	elif not login_granted:
		reason = "login_not_granted"
		verdict = "ABORTED_CONFIRMATION_MISSING"
	elif not overview_received:
		reason = "initial_overview_not_received"
		verdict = "ABORTED_CONFIRMATION_MISSING"
	elif bool(overview.get("heyveno_preexisting", false)):
		reason = "heyveno_already_exists"
		verdict = "PASS_ALREADY_EXISTS"
	elif not bool(overview.get("has_empty_slot", false)):
		reason = "no_empty_slot"
		verdict = "ABORTED_NO_EMPTY_SLOT"
	elif max_attempts != 1 or attempt_live_count != 0 or character_create_send_count != 0:
		reason = "attempt_limit_reached"
		verdict = "ABORTED_CONFIRMATION_MISSING"
	var ready := reason == ""
	state = READY_TO_CREATE if ready else ABORTED
	return {
		"ok": ready,
		"state": state,
		"block_reason": reason,
		"verdict": "READY_TO_CREATE" if ready else verdict,
		"selected_empty_slot": empty_slot,
		"create_confirmation_valid": live_enabled and confirmation == TARGET_NAME,
		"login_granted": login_granted,
		"initial_overview_received": overview_received,
		"heyveno_preexisting": bool(overview.get("heyveno_preexisting", false)),
		"offline_codec_validated": bool(offline.get("ok", false)),
		"points_used": int(((offline.get("validation", {}) as Dictionary).get("points_used", -1))),
		"attempt_live_count": attempt_live_count,
		"character_create_send_count": character_create_send_count,
		"network_send_count": network_send_count,
		"udp_enabled": udp_enabled,
		"character_select_sent": character_select_sent,
		"session_id_received": session_id_received,
		"world_entry_sent": world_entry_sent,
	}


func claim_single_create_attempt(guard: Dictionary) -> bool:
	if not bool(guard.get("ok", false)) or state != READY_TO_CREATE:
		return false
	if attempt_live_count != 0 or character_create_send_count != 0 or p1_20create_max_attempts != 1:
		state = ABORTED
		return false
	attempt_live_count = 1
	character_create_send_count = 1
	state = WAIT_CREATE_RESPONSE
	return true


func confirmation_summary(slot_index: int) -> String:
	return "\n".join([
		"Créer le personnage réel suivant sur le serveur ?",
		"",
		"Nom : Heyvena",
		"Royaume : Albion",
		"Race : Avalonian",
		"Classe : Wizard",
		"Sexe : Féminin",
		"Slot : %d" % slot_index,
		"",
		"Cette opération créera réellement le personnage.",
	])


func safety_snapshot() -> Dictionary:
	return {
		"live_enabled": p1_20create_live_enabled,
		"attempt_live_count": attempt_live_count,
		"character_create_send_count": character_create_send_count,
		"network_send_count": network_send_count,
		"udp_enabled": udp_enabled,
		"character_select_sent": character_select_sent,
		"session_id_received": session_id_received,
		"world_entry_sent": world_entry_sent,
		"automatic_reconnect": false,
		"automatic_retry": false,
	}


func run_controlled_live(overrides: Dictionary = {}) -> Dictionary:
	_reset_live_state()
	var options := _live_options(overrides)
	var report := _base_live_report()
	var offline := offline_validation(0)
	report["offline_validation"] = offline
	if not bool(offline.get("ok", false)):
		report["verdict"] = "ABORTED_OFFLINE_VALIDATION_FAILED"
		report["block_reason"] = "offline_validation_failed"
		state = ABORTED
		return _finish_live_report(report, options)
	if not bool(options.get("live_enabled", false)) or str(options.get("confirm_exact_name", "")) != TARGET_NAME:
		report["verdict"] = "ABORTED_CONFIRMATION_MISSING"
		report["block_reason"] = "exact_confirmation_missing"
		state = ABORTED
		return _finish_live_report(report, options)
	if str(options.get("host", "")) == "" or str(options.get("username", "")) == "" or str(options.get("password", "")) == "":
		report["verdict"] = "ABORTED_CONFIRMATION_MISSING"
		report["block_reason"] = "connection_configuration_missing"
		state = ABORTED
		return _finish_live_report(report, options)
	if str(options.get("host", "")) == "135.125.201.202" and not bool(options.get("allow_production_host", false)):
		report["verdict"] = "ABORTED_CONFIRMATION_MISSING"
		report["block_reason"] = "production_host_not_explicitly_allowed"
		state = ABORTED
		return _finish_live_report(report, options)

	state = CONNECTING
	report["connection_attempted"] = true
	_peer = StreamPeerTCP.new()
	var connect_error := _peer.connect_to_host(str(options.get("host", "")), int(options.get("port", 10300)))
	if connect_error != OK:
		report["verdict"] = "FAILED_DISCONNECTED"
		report["socket_error"] = "connect_to_host error=%d" % connect_error
		state = FAILED
		return _finish_live_report(report, options)
	var deadline := Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_peer.poll()
		var status := _peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			report["connected"] = true
			break
		if status == StreamPeerTCP.STATUS_ERROR:
			report["verdict"] = "FAILED_DISCONNECTED"
			report["socket_error"] = "tcp_status_error_connecting"
			state = FAILED
			return _finish_live_report(report, options)
		OS.delay_msec(20)
	if not bool(report.get("connected", false)):
		report["verdict"] = "FAILED_TIMEOUT"
		report["timeout_stage"] = CONNECTING
		state = FAILED
		return _finish_live_report(report, options)

	var crypt := _login_probe.build_crypt_key_request_payload("1.125a")
	if not _send_live_packet(0xF4, crypt.get("payload", PackedByteArray()) as PackedByteArray, "CryptKeyRequest", report):
		report["verdict"] = "FAILED_DISCONNECTED"
		return _finish_live_report(report, options)
	state = WAIT_CRYPT_KEY
	deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
	while Time.get_ticks_msec() < deadline and state not in [CREATED_AND_VERIFIED, ABORTED, FAILED]:
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			report["verdict"] = "FAILED_DISCONNECTED"
			report["socket_error"] = "remote_closed_after_%s" % state
			state = FAILED
			break
		var available := _peer.get_available_bytes()
		if available > 0:
			var read_result := _peer.get_data(mini(available, 8192))
			if read_result.size() >= 2 and int(read_result[0]) == OK:
				_receive_buffer.append_array(read_result[1] as PackedByteArray)
				_handle_received_packets(report, options)
				deadline = Time.get_ticks_msec() + int(float(options.get("timeout_seconds", 15.0)) * 1000.0)
		OS.delay_msec(20)
	if state not in [CREATED_AND_VERIFIED, ABORTED, FAILED]:
		report["verdict"] = "FAILED_TIMEOUT"
		report["timeout_stage"] = state
		state = FAILED
	return _finish_live_report(report, options)


func _handle_received_packets(report: Dictionary, options: Dictionary) -> void:
	var extracted := _packet_codec.try_extract_server_packets(_receive_buffer)
	_receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	if not bool(extracted.get("ok", true)):
		report["verdict"] = "FAILED_SERVER_REJECTED"
		report["parse_errors"] = extracted.get("errors", [])
		state = FAILED
		return
	for raw in extracted.get("packets", []) as Array:
		var parsed := raw as Dictionary
		var packet := parsed.get("packet", PackedByteArray()) as PackedByteArray
		_packet_log.log_packet("server_to_client", parsed, packet, {"checksum_status": "not_present_server_to_client"}, "", true)
		var opcode := int(parsed.get("opcode", -1))
		var received := report.get("received_opcodes", []) as Array
		received.append("0x%02X" % opcode)
		report["received_opcodes"] = received
		var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
		if opcode == 0x22 and state == WAIT_CRYPT_KEY:
			var crypt := _login_probe.decode_crypt_key_payload(payload)
			if not bool(crypt.get("ok", false)):
				report["verdict"] = "FAILED_SERVER_REJECTED"
				state = FAILED
				return
			var login := _login_probe.build_login_request_payload(str(options.get("username", "")), str(options.get("password", "")), "1.125a")
			if not bool(login.get("ok", false)) or not _send_live_packet(0xA7, login.get("payload", PackedByteArray()) as PackedByteArray, "LoginRequest", report):
				report["verdict"] = "FAILED_DISCONNECTED"
				state = FAILED
				return
			state = WAIT_LOGIN_GRANTED
		elif opcode == 0x2A:
			var granted := _login_probe.decode_login_granted_payload(payload)
			if not bool(granted.get("ok", false)):
				report["verdict"] = "FAILED_SERVER_REJECTED"
				state = FAILED
				return
			if state == WAIT_LOGIN_GRANTED:
				report["login_granted"] = true
				if not _send_live_packet(0xFC, PackedByteArray([1]), "CharacterOverviewRequest Albion", report):
					report["verdict"] = "FAILED_DISCONNECTED"
					state = FAILED
					return
				state = WAIT_INITIAL_OVERVIEW
			elif state == WAIT_CREATE_RESPONSE:
				report["create_response_received"] = true
				if not bool(report.get("refresh_overview_requested", false)):
					if not _send_live_packet(0xFC, PackedByteArray([1]), "Refreshed CharacterOverviewRequest Albion", report):
						report["verdict"] = "FAILED_DISCONNECTED"
						state = FAILED
						return
					report["refresh_overview_requested"] = true
					state = WAIT_REFRESHED_OVERVIEW
		elif (opcode == 0xFC or opcode == 0xFD) and state == WAIT_INITIAL_OVERVIEW:
			var overview_before := _login_probe.decode_character_overview_payload(payload)
			if not bool(overview_before.get("ok", false)):
				report["verdict"] = "FAILED_SERVER_REJECTED"
				state = FAILED
				return
			report["initial_overview_received"] = true
			report["initial_character_count"] = int(overview_before.get("character_count", 0))
			report["overview_before"] = overview_before
			var guard := preflight_guard(overview_before, {
				"live_enabled": bool(options.get("live_enabled", false)),
				"confirm_exact_name": str(options.get("confirm_exact_name", "")),
				"login_granted": true,
				"overview_received": true,
				"max_attempts": 1,
			})
			report.merge(guard, true)
			if not bool(guard.get("ok", false)):
				report["verdict"] = str(guard.get("verdict", "ABORTED_CONFIRMATION_MISSING"))
				state = ABORTED
				return
			var selected_slot := int(guard.get("selected_empty_slot", -1))
			var create_data := _character_codec.heyveno_fixture(selected_slot)
			var validation := _character_codec.validate_character_create_data_1125(create_data)
			if not bool(validation.get("ok", false)):
				report["verdict"] = "ABORTED_OFFLINE_VALIDATION_FAILED"
				state = ABORTED
				return
			if not claim_single_create_attempt(guard):
				report["verdict"] = "ABORTED_CONFIRMATION_MISSING"
				state = ABORTED
				return
			var create_payload := _character_codec.build_character_create_payload_1125(create_data)
			if not _send_live_packet(0xFF, create_payload, "CharacterCreateRequest Heyvena", report):
				report["verdict"] = "FAILED_DISCONNECTED"
				state = FAILED
				return
			report["character_create_sent"] = true
			report["selected_empty_slot"] = selected_slot
			state = WAIT_CREATE_RESPONSE
		elif (opcode == 0xFC or opcode == 0xFD) and state == WAIT_REFRESHED_OVERVIEW:
			var overview_after := _login_probe.decode_character_overview_payload(payload)
			report["refreshed_overview_received"] = bool(overview_after.get("ok", false))
			report["overview_after"] = overview_after
			if not bool(overview_after.get("ok", false)):
				report["verdict"] = "FAILED_SERVER_REJECTED"
				state = FAILED
				return
			_verify_final_overview(overview_after, report)
		elif (opcode == 0xFC or opcode == 0xFD) and state == WAIT_CREATE_RESPONSE:
			# Some server variants answer creation with an overview instead of 0x2A.
			# Still request one explicit refreshed Albion overview, exactly once.
			report["create_response_received"] = true
			if not bool(report.get("refresh_overview_requested", false)):
				if not _send_live_packet(0xFC, PackedByteArray([1]), "Refreshed CharacterOverviewRequest Albion", report):
					report["verdict"] = "FAILED_DISCONNECTED"
					state = FAILED
					return
				report["refresh_overview_requested"] = true
				state = WAIT_REFRESHED_OVERVIEW
		elif opcode == 0x28:
			report["session_id_received"] = true
			report["verdict"] = "FAILED_SERVER_REJECTED"
			state = FAILED
			return


func _verify_final_overview(overview: Dictionary, report: Dictionary) -> void:
	var found: Dictionary = {}
	for raw in overview.get("characters", []) as Array:
		var character := raw as Dictionary
		if str(character.get("name", "")).to_lower() == TARGET_NAME.to_lower():
			found = character
			break
	if found.is_empty():
		report["heyveno_found"] = false
		report["verdict"] = "FAILED_SERVER_REJECTED"
		state = FAILED
		return
	report["heyveno_found"] = true
	report["heyveno_slot"] = int(found.get("slot", -1))
	report["heyveno_realm"] = int(found.get("realm_id", 0))
	report["heyveno_race"] = str(found.get("race_name", ""))
	report["heyveno_class"] = str(found.get("class_name", ""))
	var packed := int(found.get("race_and_gender", 0))
	var overview_race := (packed & 0x0f) + ((packed & 0x40) >> 2)
	var overview_female := ((packed >> 4) & 1) == 1
	report["heyveno_gender"] = "female" if overview_female else "male"
	var requested_slot := int(report.get("selected_empty_slot", -1))
	if int(found.get("slot", -1)) != requested_slot:
		report["verdict"] = "CREATED_WITH_SLOT_MISMATCH"
		state = FAILED
		return
	var name_ok := str(found.get("name", "")) == TARGET_NAME
	var realm_ok := int(found.get("realm_id", 0)) == 1
	var race_ok := overview_race == 2 or str(found.get("race_name", "")).to_lower() == "avalonian"
	var class_ok := int(found.get("class_id", 0)) == 7 or str(found.get("class_name", "")).to_lower() == "wizard"
	var model := int(found.get("current_model", 0))
	var model_ok := model == 0 or model == 65 or model == 64 or model == 42
	if not name_ok or not realm_ok or not race_ok or not class_ok or not overview_female or not model_ok:
		report["verdict"] = "CREATED_WITH_DATA_MISMATCH"
		state = FAILED
		return
	report["verdict"] = "PASS_CREATED_AND_VERIFIED"
	state = CREATED_AND_VERIFIED


func _send_live_packet(opcode: int, payload: PackedByteArray, note: String, report: Dictionary) -> bool:
	if _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var sequence := _next_sequence & 0xffff
	_next_sequence = (_next_sequence + 1) & 0xffff
	var packet_without_checksum := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, 0)
	var checksum_value := _checksum.compute_checksum(packet_without_checksum.slice(0, packet_without_checksum.size() - 2))
	var packet := _packet_codec.build_client_packet(opcode, payload, sequence, 0, 0, checksum_value)
	var error := _peer.put_data(packet)
	var parsed := _packet_codec.parse_client_packet(packet)
	_packet_log.log_packet("client_to_server", parsed, packet, _checksum.verify_checksum(packet), note, true)
	if error != OK:
		return false
	network_send_count += 1
	if opcode == 0x10:
		character_select_sent = true
	if opcode == 0x28:
		session_id_received = true
	report["network_send_count"] = network_send_count
	return true


func _live_options(overrides: Dictionary) -> Dictionary:
	return {
		"live_enabled": bool(overrides.get("live_enabled", p1_20create_live_enabled)),
		"confirm_exact_name": str(overrides.get("confirm_exact_name", p1_20create_confirm_exact_name)),
		"host": str(overrides.get("host", p1_20create_host)),
		"port": int(overrides.get("port", p1_20create_port)),
		"username": str(overrides.get("username", p1_20create_username)),
		"password": str(overrides.get("password", p1_20create_password)),
		"allow_production_host": bool(overrides.get("allow_production_host", p1_20create_allow_production_host)),
		"timeout_seconds": float(overrides.get("timeout_seconds", p1_20create_timeout_seconds)),
		"report_dir": str(overrides.get("report_dir", "res://reports/p1_20create_b_live_heyveno")),
	}


func _base_live_report() -> Dictionary:
	return {
		"checkpoint": CHECKPOINT,
		"connected": false,
		"login_granted": false,
		"initial_overview_received": false,
		"initial_character_count": 0,
		"heyveno_preexisting": false,
		"selected_empty_slot": -1,
		"create_confirmation_valid": false,
		"character_create_sent": false,
		"character_create_send_count": 0,
		"create_response_received": false,
		"refresh_overview_requested": false,
		"refreshed_overview_received": false,
		"heyveno_found": false,
		"heyveno_slot": -1,
		"heyveno_realm": 0,
		"heyveno_race": "",
		"heyveno_class": "",
		"heyveno_gender": "",
		"received_opcodes": [],
		"udp_enabled": false,
		"character_select_sent": false,
		"session_id_received": false,
		"world_entry_sent": false,
		"verdict": "ABORTED_CONFIRMATION_MISSING",
		"connection_attempted": false,
	}


func _finish_live_report(report: Dictionary, options: Dictionary) -> Dictionary:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	report["final_state"] = state
	report["character_create_send_count"] = character_create_send_count
	report["udp_enabled"] = udp_enabled
	report["character_select_sent"] = character_select_sent
	report["session_id_received"] = session_id_received
	report["world_entry_sent"] = world_entry_sent
	report["network_send_count"] = network_send_count
	report["credentials_written"] = false
	report["account_name_written"] = false
	_write_live_reports(report, str(options.get("report_dir", "res://reports/p1_20create_b_live_heyveno")))
	return report.duplicate(true)


func _write_live_reports(report: Dictionary, report_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	_write_json(report_dir.path_join("p1_20create_b_live_report.json"), _without_overviews(report))
	_write_text(report_dir.path_join("p1_20create_b_live_report.txt"), _live_summary(report))
	_write_text(report_dir.path_join("p1_20create_b_packet_log.csv"), _packet_log.build_csv())
	_write_json(report_dir.path_join("p1_20create_b_overview_before.json"), report.get("overview_before", {}) as Dictionary)
	_write_json(report_dir.path_join("p1_20create_b_overview_after.json"), report.get("overview_after", {}) as Dictionary)
	_write_text(report_dir.path_join("p1_20create_b_summary.txt"), _live_summary(report))


func _without_overviews(report: Dictionary) -> Dictionary:
	var copy := report.duplicate(true)
	copy.erase("overview_before")
	copy.erase("overview_after")
	return copy


func _live_summary(report: Dictionary) -> String:
	return "\n".join([
		"P1-20CREATE-B controlled live Heyveno",
		"verdict=%s" % str(report.get("verdict", "")),
		"connected=%s login_granted=%s" % [str(report.get("connected", false)), str(report.get("login_granted", false))],
		"initial_overview_received=%s initial_character_count=%d" % [str(report.get("initial_overview_received", false)), int(report.get("initial_character_count", 0))],
		"heyveno_preexisting=%s selected_empty_slot=%d" % [str(report.get("heyveno_preexisting", false)), int(report.get("selected_empty_slot", -1))],
		"character_create_sent=%s character_create_send_count=%d" % [str(report.get("character_create_sent", false)), int(report.get("character_create_send_count", 0))],
		"refreshed_overview_received=%s heyveno_found=%s heyveno_slot=%d" % [str(report.get("refreshed_overview_received", false)), str(report.get("heyveno_found", false)), int(report.get("heyveno_slot", -1))],
		"received_opcodes=%s" % JSON.stringify(report.get("received_opcodes", [])),
		"udp_enabled=false character_select_sent=false session_id_received=%s world_entry_sent=false" % str(report.get("session_id_received", false)),
		"No account name, username, password or raw 0xA7 payload is written.",
	]) + "\n"


func _reset_live_state() -> void:
	state = IDLE
	attempt_live_count = 0
	character_create_send_count = 0
	network_send_count = 0
	udp_enabled = false
	character_select_sent = false
	session_id_received = false
	world_entry_sent = false
	_receive_buffer = PackedByteArray()
	_next_sequence = 0
	_packet_log.clear()


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
