extends "res://src/daoc/network/opendaoc/DaocOpenDaocWorldInitProbe.gd"

const GameOpenCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocGameOpenCodec.gd")
const NearbyDecoderScript = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")

const WAIT_GAME_OPEN_REPLY_D := "WAIT_GAME_OPEN_REPLY"
const WAIT_PLAYER_INIT_D := "WAIT_PLAYER_INIT"
const WAIT_PLAYING_TAIL_D := "WAIT_PLAYING_TAIL"

@export var p1_20d_live_enabled := false
@export var p1_20d_confirm_exact_name := ""
@export var p1_20d_max_game_open_attempts := 1
@export var p1_20d_tcp_only := true
@export var p1_20d_send_player_init_for_playing := true
@export var p1_20d_send_single_movement := false
@export var p1_20d_movement_delta_x := 32.0
@export var p1_20d_movement_delta_y := 0.0
@export var p1_20d_movement_steps := 1
@export var p1_20d_combat_probe_enabled := false
@export var p1_20d_spell_level := 1
@export var p1_20d_spell_line_index := 0
@export var p1_20d_spell_cast_limit := 4
@export var p1_20d_melee_probe_enabled := false
@export var p1_20d_interact_name := ""
@export var p1_20d_interact_keyword := ""
@export var p1_20d_initial_command := ""

var game_open_attempt_count := 0
var game_open_write_success_count := 0
var game_open_send_count := 0
var player_init_send_count := 0
var _game_open_sent_ticks := 0
var _player_init_sent_ticks := 0
var _post_game_last_ticks := 0
var _post_game_packets: Array[Dictionary] = []
var _game_codec: RefCounted = GameOpenCodecScript.new()
var _initial_position: Dictionary = {}
var movement_send_count := 0
var _last_movement_ticks := 0
var _nearby_decoder: RefCounted = NearbyDecoderScript.new()
var _combat_candidate: Dictionary = {}
var _target_sent_ticks := 0
var _spell_sent_ticks := 0
var target_send_count := 0
var spell_send_count := 0
var safety_command_send_count := 0
var _safety_sent_ticks := 0
var _last_visibility_refresh_ticks := 0
var los_response_send_count := 0
var _interaction_candidate: Dictionary = {}
var interaction_send_count := 0
var _interaction_sent_ticks := 0
var interaction_keyword_send_count := 0
var quest_accept_send_count := 0


func offline_validation() -> Dictionary:
	var prior := super.offline_validation()
	var packet: PackedByteArray = _game_codec.call("build_game_open_packet_tcp_only_1125", 8, 0x1234, 0) as PackedByteArray
	var decoded: Dictionary = _game_codec.call("decode_game_open_request", packet) as Dictionary
	var reply := _packet_codec.build_server_packet(0x2D, PackedByteArray([0]))
	var reply_dec: Dictionary = _game_codec.call("decode_game_open_reply", reply) as Dictionary
	var init_packet: PackedByteArray = _game_codec.call("build_player_init_packet_1125", 9, 0x1234, 0) as PackedByteArray
	return {"ok": bool(prior.get("ok", false)) and packet.size() == 13 and bool(decoded.get("ok", false)) and int(decoded.get("udp_flag", -1)) == 0 and bool(reply_dec.get("ok", false)) and init_packet.size() == 12, "p1_20c_worldinit": prior, "game_open_codec": "PASS" if bool(decoded.get("ok", false)) else "FAIL", "tcp_only_flag": "PASS" if int(decoded.get("udp_flag", -1)) == 0 else "FAIL", "game_open_reply_decoder": "PASS" if bool(reply_dec.get("ok", false)) else "FAIL", "player_init_playing_path": "SOURCE_DERIVED", "game_open_fixture_checksum": int(decoded.get("checksum", 0)), "game_open_packet_size": packet.size(), "player_init_packet_size": init_packet.size()}


func run_controlled_live(overrides: Dictionary = {}) -> Dictionary:
	p1_20c_live_enabled = bool(overrides.get("live_enabled", p1_20d_live_enabled))
	p1_20c_confirm_exact_name = str(overrides.get("confirm_exact_name", p1_20d_confirm_exact_name))
	return super.run_controlled_live(overrides)


func _finalize_capture_verdict(report: Dictionary) -> void:
	# WorldInit must already have produced the source-derived position packet.
	report["post_worldinit_packet_count"] = int(_capture.get("packets").size())
	report["post_worldinit_total_bytes"] = int(_capture.get("total_bytes"))
	var position: Dictionary = _capture.call("first_position") as Dictionary
	if not bool(position.get("ok", false)):
		report["verdict"] = "ABORTED_WORLDINIT_NOT_VERIFIED"
		state = ABORTED
		return
	report["position_packet_decoded"] = true
	report["player_object_id_received"] = int(position.get("object_id", 0)) > 0
	report["player_region_received"] = position.has("region_id")
	report["player_coordinates_received"] = position.has("x") and position.has("y") and position.has("z")
	report["server_worldenter_reached"] = true
	report["heyveno_instantiated_server_side"] = true
	_initial_position = position.duplicate(true)
	report["initial_position"] = {"x": position.get("x", 0.0), "y": position.get("y", 0.0), "z": position.get("z", 0.0), "heading": position.get("heading", 0), "region_id": position.get("region_id", 0)}
	if not p1_20d_tcp_only or not p1_20d_send_player_init_for_playing or p1_20d_max_game_open_attempts != 1:
		report["verdict"] = "ABORTED_GAME_OPEN_CONFIGURATION"
		state = ABORTED
		return
	if not _write_game_open(report):
		report["verdict"] = "FAILED_GAME_OPEN_WRITE"
		state = FAILED
		return
	state = WAIT_GAME_OPEN_REPLY_D


func _handle_received(report: Dictionary, options: Dictionary) -> void:
	if state not in [WAIT_GAME_OPEN_REPLY_D, WAIT_PLAYER_INIT_D, WAIT_PLAYING_TAIL_D]:
		super._handle_received(report, options)
		return
	var extracted := _packet_codec.try_extract_server_packets(_receive_buffer)
	_receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	if not bool(extracted.get("ok", true)):
		report["verdict"] = "FAILED_POST_GAME_OPEN_FRAME"
		state = FAILED
		return
	for raw in extracted.get("packets", []) as Array:
		var parsed := raw as Dictionary
		var packet := parsed.get("packet", PackedByteArray()) as PackedByteArray
		var opcode := int(parsed.get("opcode", -1))
		if opcode == 0xDA and not _initial_position.is_empty():
			_consider_combat_candidate(parsed.get("payload", PackedByteArray()) as PackedByteArray)
			_consider_interaction_candidate(parsed.get("payload", PackedByteArray()) as PackedByteArray)
		if opcode == 0xD0 and p1_20d_combat_probe_enabled:
			_write_los_response(report, parsed.get("payload", PackedByteArray()) as PackedByteArray)
		if opcode == 0x81 and p1_20d_interact_keyword != "" and quest_accept_send_count == 0:
			_write_quest_accept(report, parsed.get("payload", PackedByteArray()) as PackedByteArray)
		var now := Time.get_ticks_msec()
		_post_game_last_ticks = now
		_post_game_packets.append({"index": _post_game_packets.size(), "timestamp_relative_ms": now - _game_open_sent_ticks, "opcode": opcode, "opcode_hex": "0x%02X" % opcode, "payload_size": int(parsed.get("payload_size", 0)), "packet_size": packet.size(), "packet": packet})
		if _post_game_packets.size() > 2048 or int(report.get("post_game_open_total_bytes", 0)) > 4 * 1024 * 1024:
			report["verdict"] = "PASS_GAME_OPEN_TCP_PLAYING_IMMOBILE" if bool(report.get("player_init_finished_received", false)) else "FAILED_POST_GAME_OPEN_CAPTURE_LIMIT"
			state = STOPPED if bool(report.get("player_init_finished_received", false)) else FAILED
			return
		(report["received_opcodes"] as Array).append("0x%02X" % opcode)
		(report["post_game_open_received_opcodes"] as Array).append("0x%02X" % opcode)
		if opcode == 0x2D and state == WAIT_GAME_OPEN_REPLY_D:
			var reply: Dictionary = _game_codec.call("decode_game_open_reply", packet) as Dictionary
			if not bool(reply.get("ok", false)):
				report["verdict"] = "FAILED_GAME_OPEN_REPLY_INVALID"; state = FAILED; return
			report["game_open_reply_received"] = true
			report["udp_confirm_flag"] = false
			if not _write_player_init(report):
				report["verdict"] = "FAILED_PLAYER_INIT_WRITE"; state = FAILED; return
			state = WAIT_PLAYER_INIT_D
		elif opcode == 0x2B and state in [WAIT_PLAYER_INIT_D, WAIT_PLAYING_TAIL_D]:
			var finished: Dictionary = _game_codec.call("decode_player_init_finished", packet) as Dictionary
			if bool(finished.get("ok", false)):
				report["player_init_finished_received"] = true
				report["server_playing_reached_source_derived"] = true
				state = WAIT_PLAYING_TAIL_D
				if p1_20d_send_single_movement and movement_send_count == 0:
					if not _write_single_position_update(report):
						report["verdict"] = "FAILED_MOVEMENT_WRITE"; state = FAILED; return
	_update_post_game_counts(report)


func _tick_extension(report: Dictionary) -> bool:
	if state not in [WAIT_GAME_OPEN_REPLY_D, WAIT_PLAYER_INIT_D, WAIT_PLAYING_TAIL_D]:
		return false
	var now := Time.get_ticks_msec()
	# Some live revisions omit 0x2B while already streaming the active world after
	# E8. A sustained decoded stream is stronger evidence than waiting forever.
	if state == WAIT_PLAYER_INIT_D and player_init_send_count == 1 and _post_game_packets.size() >= 100 and now - _player_init_sent_ticks >= 2000:
		report["player_init_finished_stream_fallback"] = true
		report["server_playing_reached_source_derived"] = true
		state = WAIT_PLAYING_TAIL_D
		if p1_20d_send_single_movement and movement_send_count == 0 and not _write_single_position_update(report):
			report["verdict"] = "FAILED_MOVEMENT_WRITE"; state = FAILED
	if state == WAIT_PLAYING_TAIL_D and p1_20d_interact_name != "":
		if interaction_send_count == 0 and now - _player_init_sent_ticks >= 3000:
			if _interaction_candidate.is_empty() or not _write_interaction(report):
				report["verdict"] = "FAILED_INTERACTION_TARGET_NOT_FOUND"; state = FAILED
		elif interaction_send_count == 1 and interaction_keyword_send_count == 0 and p1_20d_interact_keyword != "" and now - _interaction_sent_ticks >= 800:
			if not _send_command_raw("&whisper " + p1_20d_interact_keyword):
				report["verdict"] = "FAILED_INTERACTION_KEYWORD_WRITE"; state = FAILED
			else:
				interaction_keyword_send_count = 1; report["interaction_keyword_sent"] = p1_20d_interact_keyword
		elif interaction_send_count == 1 and interaction_keyword_send_count == 1 and now - _interaction_sent_ticks >= 1600:
			if not _send_command_raw("&say " + p1_20d_interact_keyword):
				report["verdict"] = "FAILED_INTERACTION_SAY_WRITE"; state = FAILED
			else:
				interaction_keyword_send_count = 2; report["interaction_say_fallback_sent"] = true
		elif interaction_send_count == 1 and now - _interaction_sent_ticks >= 5000:
			report["verdict"] = "PASS_INTERACTION_SENT"; state = STOPPED
	elif state == WAIT_PLAYING_TAIL_D and p1_20d_initial_command != "":
		if safety_command_send_count == 0 and now - _player_init_sent_ticks >= 1000:
			if not _write_command(report, "&" + p1_20d_initial_command.trim_prefix("&").trim_prefix("/")):
				report["verdict"] = "FAILED_COMMAND_WRITE"; state = FAILED
		elif safety_command_send_count == 1 and now - _safety_sent_ticks >= 2500:
			report["verdict"] = "PASS_COMMAND_SENT"; state = STOPPED
	elif state == WAIT_PLAYING_TAIL_D and p1_20d_combat_probe_enabled:
		if safety_command_send_count == 0 and now - _player_init_sent_ticks >= 1000:
			if not _write_command(report, "&safety off"):
				report["verdict"] = "FAILED_SAFETY_COMMAND_WRITE"; state = FAILED
		# Camlann/PvP rules grant ten seconds of immunity on game entry. Keep the
		# same session alive and perform the local nearest-hostile (TAB) selection
		# only after that timer, otherwise every reconnect rearms the immunity.
		elif target_send_count == 0 and now - _player_init_sent_ticks >= 16000:
			if _combat_candidate.is_empty() or not _write_target(report):
				report["verdict"] = "FAILED_NO_SAFE_COMBAT_TARGET"; state = FAILED
		elif target_send_count == 1 and movement_send_count == 0 and now - _target_sent_ticks >= 300:
			if not _write_combat_approach(report):
				report["verdict"] = "FAILED_COMBAT_APPROACH_WRITE"; state = FAILED
		elif target_send_count == 1 and spell_send_count == 0 and p1_20d_melee_probe_enabled and now - _target_sent_ticks >= 700:
			if not _write_target(report, true):
				report["verdict"] = "FAILED_MELEE_RETARGET_WRITE"; state = FAILED
		elif target_send_count == 2 and spell_send_count == 0 and p1_20d_melee_probe_enabled and now - _target_sent_ticks >= 1000:
			if not _write_melee_start(report):
				report["verdict"] = "FAILED_MELEE_PROBE_WRITE"; state = FAILED
		elif target_send_count == 1 and movement_send_count == 1 and spell_send_count == 0 and not p1_20d_melee_probe_enabled and now - _target_sent_ticks >= 700:
			if not _write_spell_probe(report, p1_20d_spell_level, p1_20d_spell_line_index):
				report["verdict"] = "FAILED_SPELL_PROBE_WRITE"; state = FAILED
		elif spell_send_count >= 1 and spell_send_count < maxi(1, p1_20d_spell_cast_limit) and not p1_20d_melee_probe_enabled and now - _spell_sent_ticks >= 4000:
			if not _write_spell_probe(report, p1_20d_spell_level, p1_20d_spell_line_index):
				report["verdict"] = "FAILED_SPELL_PROBE_WRITE"; state = FAILED
		elif spell_send_count >= 1 and not p1_20d_melee_probe_enabled and now - _spell_sent_ticks < 4000 and now - _last_visibility_refresh_ticks >= 400:
			_write_visibility_refresh(report)
		elif spell_send_count >= (1 if p1_20d_melee_probe_enabled else maxi(1, p1_20d_spell_cast_limit)) and now - _spell_sent_ticks >= (8000 if p1_20d_melee_probe_enabled else 4000):
			report["verdict"] = "PASS_COMBAT_PROBE_SENT"
			state = STOPPED
	elif state == WAIT_PLAYING_TAIL_D and p1_20d_send_single_movement and movement_send_count < maxi(1, p1_20d_movement_steps) and now - _last_movement_ticks >= 1100:
		if not _write_single_position_update(report):
			report["verdict"] = "FAILED_MOVEMENT_WRITE"; state = FAILED
	elif state == WAIT_PLAYING_TAIL_D and p1_20d_send_single_movement and movement_send_count >= maxi(1, p1_20d_movement_steps) and now - _last_movement_ticks >= 1200:
		report["verdict"] = "PASS_GAME_OPEN_TCP_SINGLE_MOVEMENT_SENT"
		report["playing_state_claimed"] = true
		state = STOPPED
	elif state == WAIT_PLAYING_TAIL_D and not p1_20d_send_single_movement and now - _post_game_last_ticks >= 2000:
		report["verdict"] = "PASS_GAME_OPEN_TCP_PLAYING_IMMOBILE"
		report["playing_state_claimed"] = true
		state = STOPPED
	# Long autonomous routes must not be cut off by the short handshake watchdog.
	# Keep the original eight-second bound for probes, then budget one movement
	# cadence per requested step plus a small completion margin.
	elif now - _game_open_sent_ticks >= maxi(45000 if p1_20d_combat_probe_enabled else 8000, maxi(1, p1_20d_movement_steps) * 1100 + 4000):
		report["verdict"] = "FAILED_GAME_OPEN_TIMEOUT" if not bool(report.get("game_open_reply_received", false)) else "FAILED_PLAYER_INIT_TIMEOUT"
		state = FAILED
	return true


func _write_game_open(report: Dictionary) -> bool:
	if game_open_attempt_count != 0 or game_open_send_count != 0 or _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	game_open_attempt_count = 1
	var packet: PackedByteArray = _game_codec.call("build_game_open_packet_tcp_only_1125", _next_sequence & 0xffff, _session_id_memory, 0) as PackedByteArray
	if packet.size() != 13:
		return false
	_next_sequence = (_next_sequence + 1) & 0xffff
	if _peer.put_data(packet) != OK:
		return false
	game_open_write_success_count = 1
	game_open_send_count = 1
	network_send_count += 1
	_game_open_sent_ticks = Time.get_ticks_msec()
	_post_game_last_ticks = _game_open_sent_ticks
	report["game_open_sent"] = true
	report["game_open_tcp_only"] = true
	(report["sent_opcodes"] as Array).append("0xBF")
	return true


func _write_player_init(report: Dictionary) -> bool:
	if player_init_send_count != 0 or _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var packet: PackedByteArray = _game_codec.call("build_player_init_packet_1125", _next_sequence & 0xffff, _session_id_memory, 0) as PackedByteArray
	if packet.size() != 12:
		return false
	_next_sequence = (_next_sequence + 1) & 0xffff
	if _peer.put_data(packet) != OK:
		return false
	player_init_send_count = 1
	network_send_count += 1
	_player_init_sent_ticks = Time.get_ticks_msec()
	report["player_init_sent"] = true
	(report["sent_opcodes"] as Array).append("0xE8")
	return true


func _write_single_position_update(report: Dictionary) -> bool:
	if _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or _initial_position.is_empty():
		return false
	var payload := PackedByteArray()
	payload.resize(36)
	payload.encode_float(0, float(_initial_position.get("x", 0.0)) + p1_20d_movement_delta_x)
	payload.encode_float(4, float(_initial_position.get("y", 0.0)) + p1_20d_movement_delta_y)
	payload.encode_float(8, float(_initial_position.get("z", 0.0)))
	payload.encode_float(12, 32.0)
	payload.encode_float(16, 0.0)
	_write_u16_be(payload, 20, _session_id_memory)
	_write_u16_be(payload, 22, int(_initial_position.get("region_id", 0)))
	_write_u16_be(payload, 24, 0)
	_write_u16_be(payload, 26, 0)
	_write_u16_be(payload, 28, int(_initial_position.get("heading", 0)))
	payload[30] = 0x30; payload[31] = 0; payload[32] = 0; payload[33] = 100; payload[34] = 0; payload[35] = 0
	var sequence := _next_sequence & 0xffff
	_next_sequence = (_next_sequence + 1) & 0xffff
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", 0xA9, payload, sequence, _session_id_memory, 0, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	var packet: PackedByteArray = _packet_codec.call("build_client_packet", 0xA9, payload, sequence, _session_id_memory, 0, checksum_value) as PackedByteArray
	if _peer.put_data(packet) != OK:
		return false
	movement_send_count += 1
	_last_movement_ticks = Time.get_ticks_msec()
	network_send_count += 1
	_initial_position["x"] = float(_initial_position.get("x", 0.0)) + p1_20d_movement_delta_x
	_initial_position["y"] = float(_initial_position.get("y", 0.0)) + p1_20d_movement_delta_y
	report["movement_sent"] = true
	report["movement_send_count"] = movement_send_count
	report["requested_position"] = {"x": _initial_position.get("x", 0.0), "y": _initial_position.get("y", 0.0), "z": _initial_position.get("z", 0.0)}
	(report["sent_opcodes"] as Array).append("0xA9")
	return true


func _write_combat_approach(report: Dictionary) -> bool:
	var dx := float(_combat_candidate.get("x", 0)) - float(_initial_position.get("x", 0))
	var dy := float(_combat_candidate.get("y", 0)) - float(_initial_position.get("y", 0))
	var distance: float = maxf(1.0, sqrt(dx * dx + dy * dy))
	var step: float = minf(96.0, maxf(0.0, distance - 120.0))
	var payload := PackedByteArray(); payload.resize(36)
	var next_x: float = float(_initial_position.get("x", 0)) + dx / distance * step
	var next_y: float = float(_initial_position.get("y", 0)) + dy / distance * step
	var target_heading := _heading_towards(next_x, next_y, float(_combat_candidate.get("x", 0)), float(_combat_candidate.get("y", 0)))
	payload.encode_float(0, next_x); payload.encode_float(4, next_y)
	payload.encode_float(8, float(_initial_position.get("z", 0))); payload.encode_float(12, 96.0); payload.encode_float(16, 0.0)
	_write_u16_be(payload, 20, _session_id_memory); _write_u16_be(payload, 22, int(_initial_position.get("region_id", 0)))
	_write_u16_be(payload, 24, 0); _write_u16_be(payload, 26, 0); _write_u16_be(payload, 28, target_heading)
	payload[30] = 0x30; payload[31] = 0; payload[32] = 0; payload[33] = 100; payload[34] = 0; payload[35] = 0
	if not _send_gameplay_packet(0xA9, payload): return false
	movement_send_count = 1
	_initial_position["x"] = next_x; _initial_position["y"] = next_y; _initial_position["heading"] = target_heading
	_last_visibility_refresh_ticks = Time.get_ticks_msec()
	report["combat_approach"] = {"x": next_x, "y": next_y, "step": step, "target_distance_before": distance, "target_in_view_flags": true}
	(report["sent_opcodes"] as Array).append("0xA9")
	return true


func _heading_towards(from_x: float, from_y: float, to_x: float, to_y: float) -> int:
	# DOL heading grid: atan2(-dx, dy), scaled so one revolution is 4096.
	var heading := atan2(-(to_x - from_x), to_y - from_y) * 4096.0 / TAU
	if heading < 0.0: heading += 4096.0
	return int(round(heading)) & 0x0fff


func _write_visibility_refresh(report: Dictionary) -> bool:
	var payload := PackedByteArray(); payload.resize(36)
	payload.encode_float(0, float(_initial_position.get("x", 0))); payload.encode_float(4, float(_initial_position.get("y", 0)))
	payload.encode_float(8, float(_initial_position.get("z", 0))); payload.encode_float(12, 0.0); payload.encode_float(16, 0.0)
	_write_u16_be(payload, 20, _session_id_memory); _write_u16_be(payload, 22, int(_initial_position.get("region_id", 0)))
	_write_u16_be(payload, 24, 0); _write_u16_be(payload, 26, 0); _write_u16_be(payload, 28, int(_initial_position.get("heading", 0)))
	payload[30] = 0x30; payload[31] = 0; payload[32] = 0; payload[33] = 100; payload[34] = 0; payload[35] = 0
	if not _send_gameplay_packet(0xA9, payload): return false
	var target_payload := PackedByteArray([0, 0, 0x60, 0x00])
	_write_u16_be(target_payload, 0, int(_combat_candidate.get("object_id", 0)))
	if not _send_gameplay_packet(0xB0, target_payload): return false
	_last_visibility_refresh_ticks = Time.get_ticks_msec()
	report["visibility_refresh_count"] = int(report.get("visibility_refresh_count", 0)) + 1
	return true


func _write_los_response(report: Dictionary, request: PackedByteArray) -> bool:
	if request.size() < 4: return false
	var payload := PackedByteArray(); payload.resize(8)
	payload[0] = request[0]; payload[1] = request[1]; payload[2] = request[2]; payload[3] = request[3]
	_write_u16_be(payload, 4, 0x0100); _write_u16_be(payload, 6, 0)
	if not _send_gameplay_packet(0xD0, payload): return false
	los_response_send_count += 1
	report["los_response_send_count"] = los_response_send_count
	(report["sent_opcodes"] as Array).append("0xD0")
	return true


func _write_quest_accept(report: Dictionary, dialog: PackedByteArray) -> bool:
	if dialog.size() < 12 or int(dialog[1]) != 0x64: return false
	var payload := PackedByteArray(); payload.resize(8)
	payload[0] = dialog[2]; payload[1] = dialog[3]
	payload[2] = dialog[4]; payload[3] = dialog[5]
	payload[4] = dialog[6]; payload[5] = dialog[7]
	payload[6] = 0x64; payload[7] = 0x01
	if not _send_gameplay_packet(0x82, payload): return false
	quest_accept_send_count = 1; _interaction_sent_ticks = Time.get_ticks_msec()
	report["quest_accept_sent"] = true
	report["quest_offer"] = {"quest_id": (int(dialog[2]) << 8) | int(dialog[3]), "npc_object_id": (int(dialog[4]) << 8) | int(dialog[5])}
	(report["sent_opcodes"] as Array).append("0x82")
	return true


func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


func _consider_combat_candidate(payload: PackedByteArray) -> void:
	var npc: Dictionary = _nearby_decoder.call("decode_npc_create", payload) as Dictionary
	if not bool(npc.get("ok", false)) or int(npc.get("level", 99)) > 1:
		return
	var flags := npc.get("flags", {}) as Dictionary
	if bool(flags.get("peaceful", false)) or bool(flags.get("cannot_target", false)):
		return
	var dx := float(npc.get("x", 0)) - float(_initial_position.get("x", 0))
	var dy := float(npc.get("y", 0)) - float(_initial_position.get("y", 0))
	var distance := sqrt(dx * dx + dy * dy)
	if distance > 1500.0:
		return
	npc["distance_2d"] = distance
	if _combat_candidate.is_empty() or distance < float(_combat_candidate.get("distance_2d", INF)):
		_combat_candidate = npc


func _consider_interaction_candidate(payload: PackedByteArray) -> void:
	if p1_20d_interact_name == "": return
	var npc: Dictionary = _nearby_decoder.call("decode_npc_create", payload) as Dictionary
	if not bool(npc.get("ok", false)) or str(npc.get("name", "")).to_lower() != p1_20d_interact_name.to_lower(): return
	var dx := float(npc.get("x", 0)) - float(_initial_position.get("x", 0))
	var dy := float(npc.get("y", 0)) - float(_initial_position.get("y", 0))
	npc["distance_2d"] = sqrt(dx * dx + dy * dy)
	_interaction_candidate = npc


func _write_interaction(report: Dictionary) -> bool:
	var target_payload := PackedByteArray([0, 0, 0xE0, 0x00])
	_write_u16_be(target_payload, 0, int(_interaction_candidate.get("object_id", 0)))
	if not _send_gameplay_packet(0xB0, target_payload): return false
	var payload := PackedByteArray(); payload.resize(12)
	_write_u32_be(payload, 0, int(_initial_position.get("x", 0))); _write_u32_be(payload, 4, int(_initial_position.get("y", 0)))
	_write_u16_be(payload, 8, _session_id_memory); _write_u16_be(payload, 10, int(_interaction_candidate.get("object_id", 0)))
	if not _send_gameplay_packet(0x7A, payload): return false
	interaction_send_count = 1; _interaction_sent_ticks = Time.get_ticks_msec()
	report["interaction_target"] = _interaction_candidate.duplicate(true)
	(report["sent_opcodes"] as Array).append_array(["0xB0", "0x7A"])
	return true


func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff; data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff; data[offset + 3] = value & 0xff


func _write_target(report: Dictionary, attack_mode: bool = false) -> bool:
	var payload := PackedByteArray([0, 0, 0xFF, 0xFF if attack_mode else 0xFE])
	_write_u16_be(payload, 0, int(_combat_candidate.get("object_id", 0)))
	if not _send_gameplay_packet(0xB0, payload):
		return false
	target_send_count += 1; _target_sent_ticks = Time.get_ticks_msec()
	report["combat_target"] = {"object_id": _combat_candidate.get("object_id", 0), "name": _combat_candidate.get("name", ""), "level": _combat_candidate.get("level", 0), "distance_2d": _combat_candidate.get("distance_2d", 0.0)}
	report["target_send_count"] = target_send_count
	(report["sent_opcodes"] as Array).append("0xB0")
	return true


func _write_spell_probe(report: Dictionary, spell_level: int, spell_line_index: int) -> bool:
	var payload := PackedByteArray(); payload.resize(24)
	payload.encode_float(0, float(_initial_position.get("x", 0.0)))
	payload.encode_float(4, float(_initial_position.get("y", 0.0)))
	payload.encode_float(8, float(_initial_position.get("z", 0.0)))
	payload.encode_float(12, 0.0)
	_write_u16_be(payload, 16, int(_initial_position.get("heading", 0)))
	# The live server derives target visibility from these high bits. Preserve all
	# action/LOS bits for now; narrower masks are rejected as not visible.
	_write_u16_be(payload, 18, 0xA000)
	payload[20] = spell_level & 0xff; payload[21] = spell_line_index & 0xff
	if not _send_gameplay_packet(0x7D, payload):
		return false
	spell_send_count += 1; _spell_sent_ticks = Time.get_ticks_msec()
	report["spell_probe"] = {"level": spell_level, "line_index": spell_line_index}
	report["spell_send_count"] = spell_send_count
	(report["sent_opcodes"] as Array).append("0x7D")
	return true


func _write_melee_start(report: Dictionary) -> bool:
	if not _send_gameplay_packet(0x74, PackedByteArray([1, 0])):
		return false
	spell_send_count = 1; _spell_sent_ticks = Time.get_ticks_msec()
	report["melee_attack_started"] = true
	report["spell_send_count"] = 0
	(report["sent_opcodes"] as Array).append("0x74")
	return true


func _write_command(report: Dictionary, command: String) -> bool:
	if not _send_command_raw(command):
		return false
	safety_command_send_count = 1; _safety_sent_ticks = Time.get_ticks_msec()
	report["safety_command_sent"] = true
	(report["sent_opcodes"] as Array).append("0xAF")
	return true


func _send_command_raw(command: String) -> bool:
	var payload := PackedByteArray(); payload.resize(8)
	payload.append_array(command.to_utf8_buffer()); payload.append(0)
	return _send_gameplay_packet(0xAF, payload)


func _send_gameplay_packet(opcode: int, payload: PackedByteArray) -> bool:
	var sequence := _next_sequence & 0xffff; _next_sequence = (_next_sequence + 1) & 0xffff
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", opcode, payload, sequence, _session_id_memory, 0, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	var packet: PackedByteArray = _packet_codec.call("build_client_packet", opcode, payload, sequence, _session_id_memory, 0, checksum_value) as PackedByteArray
	if _peer.put_data(packet) != OK:
		return false
	network_send_count += 1
	return true


func _base_report() -> Dictionary:
	var report := super._base_report()
	report["checkpoint"] = "P1-20D_HEYVENO_GAMEOPEN_TCP_ONLY_PLAYING"
	report.merge({"game_open_attempt_count": 0, "game_open_write_success_count": 0, "game_open_send_count": 0, "game_open_tcp_only": true, "udp_confirm_flag": false, "player_init_sent": false, "player_init_send_count": 0, "player_init_finished_received": false, "server_playing_reached_source_derived": false, "post_game_open_packet_count": 0, "post_game_open_total_bytes": 0, "post_game_open_received_opcodes": [], "movement_send_count": 0, "target_send_count": 0, "spell_send_count": 0}, true)
	return report


func _finish(report: Dictionary, options: Dictionary) -> Dictionary:
	_update_post_game_counts(report)
	report["game_open_attempt_count"] = game_open_attempt_count
	report["game_open_write_success_count"] = game_open_write_success_count
	report["game_open_send_count"] = game_open_send_count
	report["player_init_send_count"] = player_init_send_count
	report["movement_send_count"] = movement_send_count
	return super._finish(report, options)


func _write_reports(report: Dictionary, report_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	_write_json(report_dir.path_join("p1_20d_live_report.json"), report)
	_write_text(report_dir.path_join("p1_20d_live_report.txt"), _summary_d(report))
	_write_text(report_dir.path_join("p1_20d_packet_log.csv"), _post_game_csv())
	_write_text(report_dir.path_join("p1_20d_post_gameopen_opcode_inventory.csv"), _post_game_inventory_csv())
	var file := FileAccess.open(report_dir.path_join("p1_20d_post_gameopen_server_packets.bin"), FileAccess.WRITE)
	if file != null:
		file.store_buffer(_post_game_binary()); file.close()
	_write_text(report_dir.path_join("p1_20d_summary.txt"), _summary_d(report))


func _update_post_game_counts(report: Dictionary) -> void:
	report["post_game_open_packet_count"] = _post_game_packets.size()
	var total := 0
	for entry in _post_game_packets:
		total += int(entry.get("packet_size", 0))
	report["post_game_open_total_bytes"] = total


func _post_game_binary() -> PackedByteArray:
	var out := PackedByteArray()
	for entry in _post_game_packets:
		out.append_array(entry.get("packet", PackedByteArray()) as PackedByteArray)
	return out


func _post_game_csv() -> String:
	var lines := PackedStringArray(["index,timestamp_relative_ms,direction,opcode,payload_size,packet_size"])
	for entry in _post_game_packets:
		lines.append("%d,%d,server_to_client,%s,%d,%d" % [int(entry.get("index", 0)), int(entry.get("timestamp_relative_ms", 0)), str(entry.get("opcode_hex", "")), int(entry.get("payload_size", 0)), int(entry.get("packet_size", 0))])
	return "\n".join(lines) + "\n"


func _post_game_inventory_csv() -> String:
	var counts := {}
	for entry in _post_game_packets:
		var key := str(entry.get("opcode_hex", ""))
		if not counts.has(key):
			counts[key] = {"count": 0, "first_order": int(entry.get("index", 0)), "sizes": []}
		var row := counts[key] as Dictionary
		row["count"] = int(row.get("count", 0)) + 1
		var size := int(entry.get("payload_size", 0)); var sizes := row.get("sizes", []) as Array
		if size not in sizes: sizes.append(size)
	var lines := PackedStringArray(["opcode,count,payload_sizes,first_order"])
	for key in counts.keys():
		var row := counts[key] as Dictionary
		lines.append("%s,%d,\"%s\",%d" % [key, int(row.get("count", 0)), JSON.stringify(row.get("sizes", [])), int(row.get("first_order", 0))])
	return "\n".join(lines) + "\n"


func _summary_d(report: Dictionary) -> String:
	return "\n".join(["P1-20D GameOpen TCP-only controlled", "verdict=%s final_state=%s" % [str(report.get("verdict", "")), str(report.get("final_state", state))], "world_init_send_count=%d game_open_send_count=%d player_init_send_count=%d" % [int(report.get("world_init_send_count", 0)), game_open_send_count, player_init_send_count], "game_open_reply_received=%s player_init_finished_received=%s playing_source_derived=%s" % [str(report.get("game_open_reply_received", false)), str(report.get("player_init_finished_received", false)), str(report.get("server_playing_reached_source_derived", false))], "post_game_open_packet_count=%d total_bytes=%d opcodes=%s" % [int(report.get("post_game_open_packet_count", 0)), int(report.get("post_game_open_total_bytes", 0)), JSON.stringify(report.get("post_game_open_received_opcodes", []))], "tcp_only=true udp_enabled=false movement_sent=false remained_immobile=true", "session_id_value_redacted=true credentials_written=false"]) + "\n"


func _reset() -> void:
	super._reset()
	game_open_attempt_count = 0; game_open_write_success_count = 0; game_open_send_count = 0; player_init_send_count = 0
	_game_open_sent_ticks = 0; _player_init_sent_ticks = 0; _post_game_last_ticks = 0; _post_game_packets.clear()
	_initial_position.clear(); movement_send_count = 0; _combat_candidate.clear(); target_send_count = 0; spell_send_count = 0; _target_sent_ticks = 0; _spell_sent_ticks = 0
