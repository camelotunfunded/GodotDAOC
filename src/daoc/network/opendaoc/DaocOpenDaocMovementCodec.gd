extends RefCounted
class_name DaocOpenDaocMovementCodec

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const OPCODE := 0xA9
const PAYLOAD_SIZE := 36

var _codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func build_packet(position: Dictionary, sequence: int, session_id: int) -> PackedByteArray:
	if session_id <= 0 or session_id > 0xffff or not _valid_position(position):
		return PackedByteArray()
	var payload := PackedByteArray(); payload.resize(PAYLOAD_SIZE)
	payload.encode_float(0, float(position.get("x", 0.0)))
	payload.encode_float(4, float(position.get("y", 0.0)))
	payload.encode_float(8, float(position.get("z", 0.0)))
	payload.encode_float(12, float(position.get("speed", 0.0)))
	payload.encode_float(16, float(position.get("z_speed", 0.0)))
	_write_u16(payload, 20, session_id)
	_write_u16(payload, 22, int(position.get("region_id", 0)))
	_write_u16(payload, 24, int(position.get("player_state", 0)))
	_write_u16(payload, 26, int(position.get("falling_damage", 0)))
	_write_u16(payload, 28, int(position.get("heading", 0)) & 0x0fff)
	payload[30] = int(position.get("action_flags", 0x30)) & 0xff
	payload[31] = int(position.get("roleplay", 0)) & 0xff
	payload[32] = 0
	payload[33] = clampi(int(position.get("health", 100)), 0, 100)
	payload[34] = clampi(int(position.get("mana", 0)), 0, 100)
	payload[35] = clampi(int(position.get("endurance", 0)), 0, 100)
	var unsigned: PackedByteArray = _codec.call("build_client_packet", OPCODE, payload, sequence, session_id, 0, 0) as PackedByteArray
	var sum := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	return _codec.call("build_client_packet", OPCODE, payload, sequence, session_id, 0, sum) as PackedByteArray


func decode_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_client_packet", packet) as Dictionary
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	if not bool(parsed.get("ok", false)) or int(parsed.get("opcode", -1)) != OPCODE or payload.size() != PAYLOAD_SIZE:
		return {"ok": false, "error": "invalid_movement_packet"}
	return {"ok": bool((_checksum.call("verify_checksum", packet) as Dictionary).get("ok", false)),
		"x": payload.decode_float(0), "y": payload.decode_float(4), "z": payload.decode_float(8),
		"speed": payload.decode_float(12), "z_speed": payload.decode_float(16),
		"embedded_session_id": int(_codec.call("u16_be_read", payload, 20)), "region_id": int(_codec.call("u16_be_read", payload, 22)),
		"heading": int(_codec.call("u16_be_read", payload, 28)), "sequence": int(parsed.get("sequence", 0)),
		"health": int(payload[33]), "mana": int(payload[34]), "endurance": int(payload[35])}


func _valid_position(value: Dictionary) -> bool:
	for key in ["x", "y", "z"]:
		if not value.has(key) or not is_finite(float(value[key])): return false
	return int(value.get("region_id", 0)) > 0


func _write_u16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
