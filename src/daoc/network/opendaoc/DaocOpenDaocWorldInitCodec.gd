extends RefCounted

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const WORLD_INIT_OPCODE := 0xD4
const CLIENT_HEADER_SIZE := 10
const CHECKSUM_SIZE := 2

var last_error := ""
var _packet_codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func char_index_for(realm_id: int, local_slot: int) -> int:
	if realm_id < 1 or realm_id > 3:
		return -1
	if local_slot < 0 or local_slot > 9:
		return -1
	return realm_id * 10 - 10 + local_slot


func build_world_init_payload_1125(character: Dictionary) -> PackedByteArray:
	last_error = ""
	var realm_id := int(character.get("realm_id", 0))
	var local_slot := int(character.get("slot", character.get("slot_index", -1)))
	var char_index := char_index_for(realm_id, local_slot)
	if char_index < 0:
		last_error = "invalid_realm_or_slot"
		return PackedByteArray()
	return PackedByteArray([char_index])


func build_world_init_packet_1125(character: Dictionary, sequence: int, session_id: int, parameter: int) -> PackedByteArray:
	last_error = ""
	if session_id <= 0 or session_id > 0xffff:
		last_error = "session_id_must_be_nonzero_u16"
		return PackedByteArray()
	var payload := build_world_init_payload_1125(character)
	if payload.size() != 1:
		return PackedByteArray()
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", WORLD_INIT_OPCODE, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - CHECKSUM_SIZE)))
	return _packet_codec.call("build_client_packet", WORLD_INIT_OPCODE, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray


func decode_world_init_packet_1125(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_client_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return parsed
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	var checksum_report: Dictionary = _checksum.call("verify_checksum", packet) as Dictionary
	var ok := int(parsed.get("opcode", -1)) == WORLD_INIT_OPCODE and payload.size() == 1 and int(parsed.get("session_id", 0)) != 0 and bool(checksum_report.get("ok", false))
	return {
		"ok": ok, "opcode": int(parsed.get("opcode", -1)), "payload_size": payload.size(),
		"char_index": int(payload[0]) if payload.size() == 1 else -1,
		"sequence": int(parsed.get("sequence", 0)), "session_id": int(parsed.get("session_id", 0)),
		"session_id_present": int(parsed.get("session_id", 0)) != 0,
		"parameter": int(parsed.get("parameter", 0)), "checksum": int(parsed.get("checksum", 0)),
		"checksum_valid": bool(checksum_report.get("ok", false)), "packet_size": packet.size(),
	}


func describe_offsets_1125(character: Dictionary, sequence: int = 7, session_id: int = 0x1234, parameter: int = 0) -> Array[Dictionary]:
	var payload := build_world_init_payload_1125(character)
	return [
		{"offset": 0, "size": 2, "field": "payload_size", "value": payload.size(), "endianness": "big"},
		{"offset": 2, "size": 2, "field": "sequence", "value": sequence & 0xffff, "endianness": "big"},
		{"offset": 4, "size": 2, "field": "session_id", "value": "REDACTED", "endianness": "big"},
		{"offset": 6, "size": 2, "field": "parameter", "value": parameter & 0xffff, "endianness": "big"},
		{"offset": 8, "size": 1, "field": "reserved", "value": 0, "endianness": "n/a"},
		{"offset": 9, "size": 1, "field": "opcode", "value": "0xD4", "endianness": "n/a"},
		{"offset": 10, "size": 1, "field": "charIndex", "value": int(payload[0]) if payload.size() == 1 else "invalid", "endianness": "n/a"},
		{"offset": 11, "size": 2, "field": "checksum", "value": "fixture-derived", "endianness": "big"},
	]
