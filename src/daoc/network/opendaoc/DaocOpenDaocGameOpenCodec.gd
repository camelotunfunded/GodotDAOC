extends RefCounted

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const GAME_OPEN_OPCODE := 0xBF
const GAME_OPEN_REPLY_OPCODE := 0x2D
const PLAYER_INIT_OPCODE := 0xE8
const PLAYER_INIT_FINISHED_OPCODE := 0x2B

var last_error := ""
var _packet_codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func build_game_open_payload_tcp_only_1125() -> PackedByteArray:
	# GameOpenRequestHandler: flag == 1 enables UDP. Zero is strictly TCP-only.
	return PackedByteArray([0])


func build_game_open_packet_tcp_only_1125(sequence: int, session_id: int, parameter: int = 0) -> PackedByteArray:
	return _build_checked(GAME_OPEN_OPCODE, build_game_open_payload_tcp_only_1125(), sequence, session_id, parameter)


func build_player_init_packet_1125(sequence: int, session_id: int, parameter: int = 0) -> PackedByteArray:
	return _build_checked(PLAYER_INIT_OPCODE, PackedByteArray(), sequence, session_id, parameter)


func decode_game_open_request(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_client_packet", packet) as Dictionary
	var check: Dictionary = _checksum.call("verify_checksum", packet) as Dictionary
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	var ok := bool(parsed.get("ok", false)) and int(parsed.get("opcode", -1)) == GAME_OPEN_OPCODE and payload == PackedByteArray([0]) and int(parsed.get("session_id", 0)) != 0 and bool(check.get("ok", false))
	return {"ok": ok, "opcode": int(parsed.get("opcode", -1)), "payload_size": payload.size(), "udp_flag": int(payload[0]) if payload.size() == 1 else -1, "tcp_only": payload == PackedByteArray([0]), "sequence": int(parsed.get("sequence", 0)), "session_id": int(parsed.get("session_id", 0)), "session_id_present": int(parsed.get("session_id", 0)) != 0, "checksum": int(parsed.get("checksum", 0)), "checksum_valid": bool(check.get("ok", false)), "packet_size": packet.size()}


func decode_game_open_reply(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_server_packet", packet) as Dictionary
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	var ok := bool(parsed.get("ok", false)) and int(parsed.get("opcode", -1)) == GAME_OPEN_REPLY_OPCODE and payload == PackedByteArray([0]) and packet.size() == 4
	return {"ok": ok, "opcode": int(parsed.get("opcode", -1)), "payload_size": payload.size(), "reply_flag": int(payload[0]) if payload.size() == 1 else -1, "packet_size": packet.size(), "checksum_status": "not_present_server_to_client"}


func decode_player_init_finished(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_server_packet", packet) as Dictionary
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	return {"ok": bool(parsed.get("ok", false)) and int(parsed.get("opcode", -1)) == PLAYER_INIT_FINISHED_OPCODE and payload.size() == 1, "opcode": int(parsed.get("opcode", -1)), "mobs_flag": int(payload[0]) if payload.size() == 1 else -1}


func describe_game_open_offsets(sequence: int = 8, session_id: int = 0x1234) -> Array[Dictionary]:
	return [
		{"offset": 0, "size": 2, "field": "payload_size", "value": 1, "endianness": "big"},
		{"offset": 2, "size": 2, "field": "sequence", "value": sequence, "endianness": "big"},
		{"offset": 4, "size": 2, "field": "session_id", "value": "REDACTED", "endianness": "big"},
		{"offset": 6, "size": 2, "field": "parameter", "value": 0, "endianness": "big"},
		{"offset": 8, "size": 1, "field": "reserved", "value": 0, "endianness": "n/a"},
		{"offset": 9, "size": 1, "field": "opcode", "value": "0xBF", "endianness": "n/a"},
		{"offset": 10, "size": 1, "field": "udp_flag", "value": 0, "endianness": "n/a"},
		{"offset": 11, "size": 2, "field": "checksum", "value": "fixture-derived", "endianness": "big"},
	]


func _build_checked(opcode: int, payload: PackedByteArray, sequence: int, session_id: int, parameter: int) -> PackedByteArray:
	last_error = ""
	if session_id <= 0 or session_id > 0xffff:
		last_error = "session_id_must_be_nonzero_u16"
		return PackedByteArray()
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", opcode, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	return _packet_codec.call("build_client_packet", opcode, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray
