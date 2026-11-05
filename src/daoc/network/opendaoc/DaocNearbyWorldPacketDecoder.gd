extends RefCounted
class_name DaocNearbyWorldPacketDecoder

## Strict, source-derived decoders for the OpenDAoC 1.125a nearby-world stream.
## PacketLib1125 inherits these writers without overriding them:
##   DA: PacketLib1124.SendNPCCreate
##   D9: PacketLib176.SendObjectCreate
##   15: PacketLib1124.SendLivingEquipmentUpdate
##   A1: PacketLib168.SendObjectUpdate
##   DE: PacketLib168.SendObjectGuildID

const Codec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
## P1-94 : 0x4B PlayerCreate172 rejoint le flux. Les AUTRES JOUEURS n'etaient
## instancies nulle part : on pouvait parler et grouper avec le GM sans le voir.
const SUPPORTED := [0xDA, 0xD9, 0x15, 0xA1, 0xDE, 0x4B]

var _codec := Codec.new()


func decode_nearby_world_packet(opcode: int, payload: PackedByteArray) -> Dictionary:
	match opcode & 0xff:
		0xDA: return decode_npc_create(payload)
		0xD9: return decode_object_create(payload)
		0x15: return decode_equipment_update(payload)
		0xA1: return decode_object_update(payload)
		0xDE: return decode_object_guild_id(payload)
		0x4B: return decode_player_create(payload)
	return _unknown(opcode, payload)


## 0x4B PlayerCreate172 — disposition 1.124+ (PacketLib1124.SendPlayerCreate,
## heritee jusqu a 1.127), MESUREE le 2026-09-22 sur le paquet reel du GM
## (52 octets, reports/online/last_parity_packets.json). LA DISPOSITION 172
## (u16 partout, coordonnees locales a la zone) ETAIT FAUSSE pour Eden : elle
## rendait un dictionnaire vide et le GM restait invisible.
##
##   f32 LE x, f32 LE y, f32 LE z (coordonnees REGION, comme le 0xDA),
##   u16 session id, u16 object id, u16 cap, u16 modele, u8 niveau affiche,
##   u8 drapeaux (bits 2-3 royaume, 0x01 mort, 0x02 nage, 0x10 furtif,
##   0x20 wireframe, 0x40 vampiir), 7 × u8 visage (yeux/nez, levres/oreilles,
##   humeur, couleur des yeux/peau, couleur de cheveux, type de visage,
##   coiffure), 3 × u8 zero, puis nom, guilde, nom de famille, prefixe (RR),
##   titre (Pascal u8), u8 monture (0 = aucune ; sinon u8 barde, u16 couleur
##   ou embleme, u8 selle, u8 couleur de selle).
##
## Paquet temoin : « Elfe », prefixe « Ard Tiarna », cap 0x2ae, u16 0xf152 a la
## place du modele (a comprendre), niveau 1, royaume 1 dans le drapeau.
const PLAYER_CREATE_1124_FIXED := 32

func decode_player_create(p: PackedByteArray) -> Dictionary:
	if p.size() < PLAYER_CREATE_1124_FIXED:
		return _truncated(0x4B, p, PLAYER_CREATE_1124_FIXED, "fixed_fields")
	var r := _base(0x4B, p)
	var flags := int(p[21])
	r.merge({
		"entity_type": "player",
		"x": int(round(_f32_le(p, 0))), "y": int(round(_f32_le(p, 4))), "z": int(round(_f32_le(p, 8))),
		"x_float": _f32_le(p, 0), "y_float": _f32_le(p, 4), "z_float": _f32_le(p, 8),
		"session_id": _u16(p, 12), "object_id": _u16(p, 14),
		"heading": _u16(p, 16) & 0x0fff, "model_id": _u16(p, 18),
		"level": int(p[20]), "realm": (flags >> 2) & 3, "flags_raw": flags, "size": 50,
		"face_eye_nose": int(p[22]), "face_lip_ear": int(p[23]), "face_mood": int(p[24]),
		"face_skin_eye": int(p[25]), "face_hair_color": int(p[26]), "face_type": int(p[27]),
		"face_hair_style": int(p[28]),
		"flags": {
			"dead": (flags & 0x01) != 0, "swimming": (flags & 0x02) != 0,
			"stealthed": (flags & 0x10) != 0, "wireframe": (flags & 0x20) != 0,
			"vampiir": (flags & 0x40) != 0, "peaceful": true,
		},
		"layout_confidence": "MEASURED_LIVE_PACKETLIB1124_2026_09_22",
		"position_source": "0x4B_region_float",
	}, true)
	var cursor := PLAYER_CREATE_1124_FIXED
	var texts := ["name", "guild_name", "last_name", "prefix_name", "title"]
	for field in texts:
		var s := _codec.pascal_u8_read(p, cursor)
		if not bool(s.get("ok")): return _string_error(r, s, field)
		r[field] = str(s.text)
		cursor = int(s.next_offset)
	if cursor < p.size():
		r.horse_id = int(p[cursor]); cursor += 1
		if int(r.horse_id) != 0 and cursor + 5 <= p.size():
			r.horse = {"barding": int(p[cursor]), "barding_color_or_emblem": _u16(p, cursor + 1),
				"saddle": int(p[cursor + 3]), "saddle_color": int(p[cursor + 4])}
			cursor += 5
	return _finish(r, cursor)


func _f32_le(p: PackedByteArray, o: int) -> float:
	return p.decode_float(o)


func decode_npc_create(p: PackedByteArray) -> Dictionary:
	# Fixed part through the 1.71+ flags/unknown field is 30 bytes.
	if p.size() < 30:
		return _truncated(0xDA, p, 30, "fixed_fields")
	var r := _base(0xDA, p)
	r.merge({
		"entity_type": "npc", "object_id": _u16(p, 0), "speed": _u16(p, 2),
		"heading": _u16(p, 4), "z": _u16(p, 6), "x": _u32(p, 8), "y": _u32(p, 12),
		"z_speed_factor": _u16(p, 16), "model_id": _u16(p, 18), "size": int(p[20]),
		"level": int(p[21]) & 0x7f, "is_statue": (int(p[21]) & 0x80) != 0,
		"realm": (int(p[22]) >> 6) & 3, "flags_raw": int(p[22]), "max_stick_distance": int(p[23]),
		"flags2_raw": int(p[24]), "flags3_raw": int(p[25]), "unknown_26_u16": _u16(p, 26),
		"flags": {
			"ghost": (int(p[22]) & 0x01) != 0, "has_equipment_template": (int(p[22]) & 0x02) != 0,
			"torch_lit": (int(p[22]) & 0x04) != 0, "peaceful": (int(p[22]) & 0x10) != 0,
			"flying": (int(p[22]) & 0x20) != 0, "cannot_target": (int(p[24]) & 0x01) != 0,
			"hide_name": (int(p[24]) & 0x02) != 0, "stealthed": (int(p[24]) & 0x04) != 0,
			"quest_available": (int(p[24]) & 0x08) != 0, "quest_finish": (int(p[24]) & 0x10) != 0,
			"has_owner": (int(p[24]) & 0x80) != 0, "quest_lesson": (int(p[25]) & 0x01) != 0,
			"quest_lore": (int(p[25]) & 0x02) != 0, "quest_pending": (int(p[25]) & 0x20) != 0,
		}
	}, true)
	var name := _codec.pascal_u8_read(p, 28)
	if not bool(name.get("ok")): return _string_error(r, name, "name")
	r.name = str(name.text)
	var guild := _codec.pascal_u8_read(p, int(name.next_offset))
	if not bool(guild.get("ok")): return _string_error(r, guild, "guild_name")
	r.guild_name = str(guild.text)
	var cursor := int(guild.next_offset)
	if cursor >= p.size(): return _truncated_from(r, cursor + 1, "trailing_byte")
	r.trailing_byte = int(p[cursor]); cursor += 1
	return _finish(r, cursor)


func decode_object_create(p: PackedByteArray) -> Dictionary:
	# PacketLib176 adds a four-byte high-emblem mask before the Pascal name.
	if p.size() < 25:
		return _truncated(0xD9, p, 25, "fixed_fields")
	var r := _base(0xD9, p)
	r.merge({
		"entity_type": "object", "object_id": _u16(p, 0), "emblem_low": _u16(p, 2),
		"heading": _u16(p, 4), "z": _u16(p, 6), "x": _u32(p, 8), "y": _u32(p, 12),
		"model_id": _u16(p, 16) & 0x7fff, "model_raw": _u16(p, 16), "flags_raw": _u16(p, 18),
		"realm": (_u16(p, 18) >> 4) & 3, "underwater": (_u16(p, 18) & 0x01) != 0,
		"keep_banner": (_u16(p, 18) & 0x08) != 0, "owner_only_timed": (_u16(p, 18) & 0x04) != 0,
		"emblem_high_mask": _u32(p, 20),
	}, true)
	var name := _codec.pascal_u8_read(p, 24)
	if not bool(name.get("ok")): return _string_error(r, name, "name")
	r.name = str(name.text)
	var cursor := int(name.next_offset)
	if cursor >= p.size(): return _truncated_from(r, cursor + 1, "object_kind")
	r.object_kind = int(p[cursor]); cursor += 1
	if int(r.object_kind) == 4:
		if cursor + 4 > p.size(): return _truncated_from(r, cursor + 4, "door_id")
		r.door_id = _u32(p, cursor); cursor += 4
	r.type_classification = "door_confirmed" if int(r.object_kind) == 4 else _object_name_heuristic(str(r.name))
	r.type_classification_source = "wire_object_kind" if int(r.object_kind) == 4 else "name_heuristic_only"
	return _finish(r, cursor)


func decode_equipment_update(p: PackedByteArray) -> Dictionary:
	if p.size() < 7:
		return _truncated(0x15, p, 7, "equipment_header")
	var r := _base(0x15, p)
	r.merge({
		"object_id": _u16(p, 0), "active_weapon_slots": int(p[2]), "current_speed": int(p[3]),
		"visibility_flags": int(p[4]), "cloak_invisible": (int(p[4]) & 1) != 0,
		"helm_invisible": (int(p[4]) & 2) != 0, "hood_quiver_flags": int(p[5]),
		"hood_up": (int(p[5]) & 1) != 0, "active_quiver_slot": int(p[5]) & 0xf0,
		"declared_item_count": int(p[6]), "items": [],
	}, true)
	var cursor := 7
	for item_index in range(int(r.declared_item_count)):
		if cursor + 3 > p.size(): return _truncated_from(r, cursor + 3, "equipment_item_%d_base" % item_index)
		var slot_wire := int(p[cursor]); cursor += 1
		var slot := slot_wire & 0x7f
		var model_wire := _u16(p, cursor); cursor += 2
		var item := {
			"item_index": item_index, "slot": slot, "slot_wire": slot_wire,
			"model_id": model_wire & 0x1fff, "model_wire": model_wire,
			"extension": 0, "texture": 0, "color": 0, "emblem": 0, "effect": 0,
			"new_emblem_bit": (slot_wire & 0x80) != 0,
		}
		# Slot.RIGHTHAND=10 through Slot.RANGED=13 omit extension; all others include it.
		if slot > 13 or slot < 10:
			if cursor >= p.size(): return _truncated_from(r, cursor + 1, "equipment_item_%d_extension" % item_index)
			item.extension = int(p[cursor]); cursor += 1
		if (model_wire & 0x8000) != 0:
			if cursor + 2 > p.size(): return _truncated_from(r, cursor + 2, "equipment_item_%d_texture_u16" % item_index)
			item.texture = _u16(p, cursor); cursor += 2
			if bool(item.new_emblem_bit): item.texture = int(item.texture) | 0x10000
			item.emblem = int(item.texture) # source chose Emblem when non-zero; exact for new-emblem bit.
		elif (model_wire & 0x4000) != 0:
			if cursor >= p.size(): return _truncated_from(r, cursor + 1, "equipment_item_%d_color" % item_index)
			item.texture = int(p[cursor]); item.color = int(p[cursor]); cursor += 1
		if (model_wire & 0x2000) != 0:
			if cursor + 2 > p.size(): return _truncated_from(r, cursor + 2, "equipment_item_%d_effect" % item_index)
			item.effect = _u16(p, cursor); cursor += 2
		r.items.append(item)
	return _finish(r, cursor)


func decode_object_update(p: PackedByteArray) -> Dictionary:
	# PacketLib168 writes a fixed GSUDP payload. OpenDAoC routes it over TCP when UDP is absent.
	if p.size() < 24:
		return _truncated(0xA1, p, 24, "fixed_object_update")
	var r := _base(0xA1, p)
	# SendObjectUpdate range la vitesse verticale dans les bits hauts : speed
	# = h_speed | (zSpeed & 0x70) << 8 | signe 0x8000 ; heading = (zSpeed & 0xF)
	# << 12 | heading. Sans masque, un PNJ qui monte une pente recevait une
	# vitesse de 28 000 unites/s et un cap hors de [0, 4096[ : teleportation.
	var speed_raw := _u16(p, 0)
	var heading_raw := _u16(p, 2)
	var z_speed := (((speed_raw >> 8) & 0x70) | ((heading_raw >> 12) & 0x0F)) * 4
	if (speed_raw & 0x8000) != 0:
		z_speed = -z_speed
	r.merge({
		"speed": speed_raw & 0x0FFF, "heading": heading_raw & 0x0FFF,
		"speed_raw": speed_raw, "heading_raw": heading_raw, "z_speed": z_speed,
		"zone_x": _u16(p, 4), "target_zone_x": _u16(p, 6),
		"zone_y": _u16(p, 8), "target_zone_y": _u16(p, 10),
		"zone_z": _u16(p, 12), "target_zone_z": _u16(p, 14),
		"object_id": _u16(p, 16), "target_object_id": _u16(p, 18),
		"health_percent": int(p[20]), "flags_raw": int(p[21]),
		"zone_skin_id": int(p[22]) | ((int(p[21]) & 0x04) << 6),
		"target_zone_skin_id": int(p[23]) | ((int(p[21]) & 0x08) << 5),
		"cannot_target_or_statue": (int(p[21]) & 0x01) != 0, "hide_name": (int(p[21]) & 0x02) != 0,
		"underwater": (int(p[21]) & 0x10) != 0, "flying": (int(p[21]) & 0x20) != 0,
		"realm": (int(p[21]) >> 6) & 3,
	}, true)
	return _finish(r, 24)


func decode_object_guild_id(p: PackedByteArray) -> Dictionary:
	if p.size() < 8:
		return _truncated(0xDE, p, 8, "fixed_object_guild")
	var first := _u16(p, 2)
	var second := _u16(p, 4)
	var r := _base(0xDE, p)
	r.merge({"object_id": _u16(p, 0), "guild_id": first, "guild_id_repeat": second,
		"guild_id_repeat_matches": first == second, "unknown_6_u16": _u16(p, 6)}, true)
	return _finish(r, 8)


func opcode_layouts() -> Dictionary:
	return {
		"profile": {"announced": "1.125a", "enum": 1125, "packet_lib": "PacketLib1125", "inheritance": "PacketLib1125 -> PacketLib1124 -> ..."},
		"0xDA": _layout("NPCCreate", "PacketLib1124.SendNPCCreate", [
			_f(0,2,"object_id","BE","WriteShort","high"), _f(2,2,"speed","BE","WriteShort","high"), _f(4,2,"heading","BE","WriteShort","high"), _f(6,2,"z","BE","WriteShort","high"),
			_f(8,4,"x","BE","WriteInt","high"), _f(12,4,"y","BE","WriteInt","high"), _f(16,2,"z_speed_factor","BE","WriteShort","high"), _f(18,2,"model_id","BE","WriteShort","high"),
			_f(20,1,"size","N/A","WriteByte","high"), _f(21,1,"level_statue","N/A","WriteByte","high"), _f(22,1,"flags_realm","N/A","WriteByte","high"), _f(23,1,"max_stick","N/A","WriteByte","high"),
			_f(24,1,"flags2","N/A","WriteByte","high"), _f(25,1,"flags3","N/A","WriteByte","high"), _f(26,2,"unknown","BE","WriteShort","high"),
			_f(28,-1,"name","u8 length + CP1252","WritePascalString","high"), _f(-1,-1,"guild_name","u8 length + CP1252","WritePascalString","high"), _f(-1,1,"trailing","N/A","WriteByte","high")]),
		"0xD9": _layout("ObjectCreate", "PacketLib176.SendObjectCreate", [
			_f(0,2,"object_id","BE","WriteShort","high"), _f(2,2,"emblem_low","BE","WriteShort","high"), _f(4,2,"heading","BE","WriteShort","high"), _f(6,2,"z","BE","WriteShort","high"),
			_f(8,4,"x","BE","WriteInt","high"), _f(12,4,"y","BE","WriteInt","high"), _f(16,2,"model_flags","BE","WriteShort","high"), _f(18,2,"flags","BE","WriteShort","high"),
			_f(20,4,"emblem_high_mask","BE","WriteInt","high"), _f(24,-1,"name","u8 length + CP1252","WritePascalString","high"), _f(-1,1,"object_kind","N/A","WriteByte","high"), _f(-1,4,"door_id_if_kind_4","BE","WriteInt","high")]),
		"0x15": _layout("EquipmentUpdate", "PacketLib1124.SendLivingEquipmentUpdate", [
			_f(0,2,"object_id","BE","WriteShort","high"), _f(2,1,"active_weapon_slots","N/A","WriteByte","high"), _f(3,1,"current_speed","N/A","WriteByte","high"),
			_f(4,1,"visibility_flags","N/A","WriteByte","high"), _f(5,1,"hood_quiver_flags","N/A","WriteByte","high"), _f(6,1,"item_count","N/A","WriteByte","high"),
			_f(7,-1,"items","dynamic flags","WriteByte/WriteShort","high")]),
		"0xA1": _layout("ObjectUpdate", "PacketLib168.SendObjectUpdate", [
			_f(0,2,"speed","BE","WriteShort","high"), _f(2,2,"heading","BE","WriteShort","high"), _f(4,2,"zone_x","BE","WriteShort","high"), _f(6,2,"target_zone_x","BE","WriteShort","high"),
			_f(8,2,"zone_y","BE","WriteShort","high"), _f(10,2,"target_zone_y","BE","WriteShort","high"), _f(12,2,"zone_z","BE","WriteShort","high"), _f(14,2,"target_zone_z","BE","WriteShort","high"),
			_f(16,2,"object_id","BE","WriteShort","high"), _f(18,2,"target_object_id","BE","WriteShort","high"), _f(20,1,"health_percent","N/A","WriteByte","high"),
			_f(21,1,"flags_zone_high_bits","N/A","WriteByte","high"), _f(22,1,"zone_skin_low","N/A","WriteByte","high"), _f(23,1,"target_zone_skin_low","N/A","WriteByte","high")]),
		"0xDE": _layout("ObjectGuildID", "PacketLib168.SendObjectGuildID", [
			_f(0,2,"object_id","BE","WriteShort","high"), _f(2,2,"guild_id","BE","WriteShort","high"), _f(4,2,"guild_id_repeat","BE","WriteShort","high"), _f(6,2,"unknown","BE","WriteShort","high")]),
	}


func _base(opcode: int, p: PackedByteArray) -> Dictionary:
	return {"ok": true, "parse_status": "ok", "opcode": opcode, "opcode_hex": "0x%02X" % opcode,
		"payload_size": p.size(), "bytes_consumed": 0, "remaining_bytes": p.size(), "partially_decoded": false}

func _finish(r: Dictionary, cursor: int) -> Dictionary:
	r.bytes_consumed = cursor; r.remaining_bytes = int(r.payload_size) - cursor
	if int(r.remaining_bytes) != 0:
		r.partially_decoded = true; r.parse_status = "known_fields_with_trailing_bytes"
	return r

func _truncated(opcode: int, p: PackedByteArray, needed: int, at: String) -> Dictionary:
	return {"ok": false, "parse_status": "truncated", "opcode": opcode, "opcode_hex": "0x%02X" % opcode,
		"payload_size": p.size(), "needed_bytes": needed, "truncated_at": at, "bytes_consumed": 0,
		"remaining_bytes": p.size(), "partially_decoded": false}

func _truncated_from(r: Dictionary, needed: int, at: String) -> Dictionary:
	r.ok = false; r.parse_status = "truncated"; r.needed_bytes = needed; r.truncated_at = at
	return r

func _string_error(r: Dictionary, error: Dictionary, field: String) -> Dictionary:
	r.ok = false; r.parse_status = "truncated_pascal_string"; r.truncated_at = field; r.string_error = error
	return r

func _unknown(opcode: int, p: PackedByteArray) -> Dictionary:
	return {"ok": true, "supported": false, "parse_status": "unknown_opcode_preserved", "opcode": opcode & 0xff,
		"opcode_hex": "0x%02X" % (opcode & 0xff), "payload_size": p.size(), "payload": p,
		"bytes_consumed": 0, "remaining_bytes": p.size(), "partially_decoded": false}

func _u16(p: PackedByteArray, o: int) -> int:
	return ((int(p[o]) & 0xff) << 8) | (int(p[o + 1]) & 0xff)

func _u32(p: PackedByteArray, o: int) -> int:
	return (_u16(p, o) << 16) | _u16(p, o + 2)

func _object_name_heuristic(name: String) -> String:
	var n := name.to_lower()
	if "bind" in n or "liaison" in n: return "bind_like_heuristic"
	if "coffre" in n or "caisse" in n: return "container_like_heuristic"
	if "quête" in n or "quest" in n: return "quest_like_heuristic"
	return "unknown_object"

func _layout(name: String, source: String, fields: Array) -> Dictionary:
	return {"name": name, "source": source, "source_file": "GameServer/packets/Server/%s.cs" % source.get_slice(".", 0),
		"client_profile": "1.125a", "fields": fields}

func _f(offset: int, size: int, field: String, endian: String, method: String, confidence: String) -> Dictionary:
	return {"offset": offset, "size": size, "field": field, "endianness": endian,
		"server_method": method, "confidence": confidence, "fixture_value": null}
