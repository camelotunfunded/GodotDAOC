extends RefCounted

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")

const POSITION_PRIMARY := 0x88
const POSITION_SOURCE_ENUM_ALIAS := 0x20
const MAX_PACKETS := 512
const MAX_BYTES := 4 * 1024 * 1024

const CLASSIFICATIONS := {
	0x88: ["POSITION_SELF", "WorldInitRequestHandler comment: 0x88 Position; SendPlayerPositionAndObjectID", "P0"],
	0x20: ["POSITION_SELF", "eServerPackets.PositionAndObjectID in inspected DOLSharp tree", "P0"],
	0xB6: ["SPEED", "eServerPackets.MaxSpeed / SendUpdateMaxSpeed", "P1"],
	0xAD: ["HEALTH", "eServerPackets.CharacterStatusUpdate / SendStatusUpdate", "P1"],
	0x02: ["INVENTORY", "eServerPackets.InventoryUpdate / SendInventoryItemsUpdate", "P1"],
	0x16: ["SKILLS_SPELLS", "eServerPackets.VariousUpdate / skill and craft bootstrap", "P1"],
	0xD8: ["SKILLS_SPELLS", "eServerPackets.DelveInfo / skill detail bootstrap", "P2"],
	0xFA: ["MONEY", "eServerPackets.MoneyUpdate / SendUpdateMoney", "P2"],
	0xFB: ["STATS", "eServerPackets.StatsUpdate / stats and resist bootstrap", "P1"],
	0x83: ["QUESTS", "eServerPackets.QuestEntry / SendQuestListUpdate", "P2"],
	0x91: ["POINTS", "eServerPackets.CharacterPointsUpdate / SendUpdatePoints", "P2"],
	0x75: ["EFFECTS", "eServerPackets.ConcentrationList / SendConcentrationList", "P2"],
	0xDE: ["GUILD", "eServerPackets.ObjectGuildID / SendObjectGuildID", "P2"],
	0x21: ["DEBUG", "eServerPackets.DebugMode / SendDebugMode", "P3"],
	0x4E: ["HORSE", "eServerPackets.ControlledHorse / SendSetControlledHorse", "P3"],
	0xBD: ["STATS", "eServerPackets.Encumberance / SendEncumberance", "P2"],
	0xC5: ["UNKNOWN", "eServerPackets.AddFriend; outside requested taxonomy", "P3"],
	# Legacy labels retained only for offline fixtures/protocol comparisons.
	0x1E: ["SPEED", "legacy handler comment", "P3"],
	0x05: ["HEALTH", "legacy handler comment", "P3"],
	0xAA: ["INVENTORY", "legacy handler comment", "P3"],
	0xBE: ["SKILLS_SPELLS", "legacy handler comment", "P3"],
}

var packets: Array[Dictionary] = []
var total_bytes := 0
var limit_reason := ""
var started_ticks := 0
var last_packet_ticks := 0
var _codec: RefCounted = PacketCodecScript.new()


func reset(start_ticks: int = 0) -> void:
	packets.clear()
	total_bytes = 0
	limit_reason = ""
	started_ticks = start_ticks
	last_packet_ticks = start_ticks


func can_accept(packet_size: int) -> bool:
	if packets.size() >= MAX_PACKETS:
		limit_reason = "max_packets"
		return false
	if total_bytes + packet_size > MAX_BYTES:
		limit_reason = "max_bytes"
		return false
	return true


func add_server_packet(packet: PackedByteArray, relative_ms: int) -> Dictionary:
	if not can_accept(packet.size()):
		return {"ok": false, "limit_reason": limit_reason}
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error": parsed.get("parse_status", "invalid")}
	var opcode := int(parsed.get("opcode", -1))
	var meta := classification_for(opcode)
	var position := decode_position_packet(packet) if opcode in [POSITION_PRIMARY, POSITION_SOURCE_ENUM_ALIAS] else {}
	var entry := {
		"index": packets.size(), "timestamp_relative_ms": relative_ms,
		"direction": "server_to_client", "opcode": opcode, "opcode_hex": "0x%02X" % opcode,
		"payload_size": int(parsed.get("payload_size", 0)), "packet_size": packet.size(),
		"checksum_valid": "not_present_server_to_client", "classification": meta[0],
		"parser_status": str(position.get("parser_status", "not_implemented")), "packet": packet,
		"position": position,
	}
	packets.append(entry)
	total_bytes += packet.size()
	last_packet_ticks = started_ticks + relative_ms
	return {"ok": true, "entry": entry}


func classification_for(opcode: int) -> Array:
	return CLASSIFICATIONS.get(opcode, ["UNKNOWN", "unclassified", "P3"]) as Array


func has_primary_position() -> bool:
	for entry in packets:
		if int(entry.get("opcode", -1)) == POSITION_PRIMARY:
			return true
	return false


func has_position_alias() -> bool:
	for entry in packets:
		if int(entry.get("opcode", -1)) in [POSITION_PRIMARY, POSITION_SOURCE_ENUM_ALIAS]:
			return true
	return false


func first_position() -> Dictionary:
	for entry in packets:
		if int(entry.get("opcode", -1)) in [POSITION_PRIMARY, POSITION_SOURCE_ENUM_ALIAS]:
			return (entry.get("position", {}) as Dictionary).duplicate(true)
	return {"ok": false, "parser_status": "not_received"}


## PacketLib1124.SendPlayerPositionAndObjectID, inherited by PacketLib1125:
## float32 LE X/Y/Z, u16 BE ObjectID, heading, zone offsets X/Y,
## CurrentRegion.Skin, flags, Pascal server-name, four reserved bytes.
func decode_position_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "parser_status": "invalid_frame"}
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	if payload.size() < 28:
		return {"ok": false, "parser_status": "payload_too_short", "payload_size": payload.size()}
	var name_len := int(payload[23]) & 0xff
	var expected_min := 24 + name_len + 4
	if payload.size() < expected_min:
		return {"ok": false, "parser_status": "truncated_pascal_server_name", "payload_size": payload.size()}
	return {
		"ok": true, "parser_status": "decoded_source_derived_packetlib1124_inherited_by_1125",
		"wire_opcode": int(parsed.get("opcode", -1)),
		"x": payload.decode_float(0), "y": payload.decode_float(4), "z": payload.decode_float(8),
		"object_id": _u16_be(payload, 12), "heading": _u16_be(payload, 14),
		"zone_offset_x_units": _u16_be(payload, 16), "zone_offset_y_units": _u16_be(payload, 18),
		"region_skin": _u16_be(payload, 20), "region_id": _u16_be(payload, 20),
		"flags": int(payload[22]) & 0xff, "zone_id": null,
		"session_identifier_present": false,
	}


func binary_capture() -> PackedByteArray:
	var out := PackedByteArray()
	for entry in packets:
		out.append_array(entry.get("packet", PackedByteArray()) as PackedByteArray)
	return out


func replay(binary: PackedByteArray) -> Dictionary:
	var extracted: Dictionary = _codec.call("try_extract_server_packets", binary) as Dictionary
	var decoded := extracted.get("packets", []) as Array
	var order: Array[String] = []
	for parsed in decoded:
		order.append("0x%02X" % int((parsed as Dictionary).get("opcode", -1)))
	return {"ok": bool(extracted.get("ok", false)) and (extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray).is_empty(), "packet_count": decoded.size(), "order": order}


func opcode_inventory() -> Array[Dictionary]:
	var by_opcode := {}
	for entry in packets:
		var opcode := int(entry.get("opcode", -1))
		if not by_opcode.has(opcode):
			var meta := classification_for(opcode)
			by_opcode[opcode] = {"opcode": opcode, "opcode_hex": "0x%02X" % opcode, "count": 0, "sizes": [], "first_order": int(entry.get("index", 0)), "classification": meta[0], "parser_existing": opcode in [POSITION_PRIMARY, POSITION_SOURCE_ENUM_ALIAS], "source": meta[1], "future_priority": meta[2]}
		var row := by_opcode[opcode] as Dictionary
		row["count"] = int(row.get("count", 0)) + 1
		var sizes := row.get("sizes", []) as Array
		var size := int(entry.get("payload_size", 0))
		if size not in sizes:
			sizes.append(size)
	var rows: Array[Dictionary] = []
	for row in by_opcode.values():
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("first_order", 0)) < int(b.get("first_order", 0)))
	return rows


func manifest_redacted() -> Dictionary:
	var entries: Array[Dictionary] = []
	for raw in packets:
		var entry := raw.duplicate(true) as Dictionary
		entry.erase("packet")
		entries.append(entry)
	return {"format": "concatenated OpenDAoC server TCP frames", "login_traffic_included": false, "packet_count": packets.size(), "total_bytes": total_bytes, "entries": entries}


func _u16_be(data: PackedByteArray, offset: int) -> int:
	return ((int(data[offset]) & 0xff) << 8) | (int(data[offset + 1]) & 0xff)
