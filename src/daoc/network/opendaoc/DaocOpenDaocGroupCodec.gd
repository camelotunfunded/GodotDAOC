extends RefCounted
class_name DaocOpenDaocGroupCodec

## P1-105 — le groupe et le social, tels que DOL les ecrit (PacketLib1125,
## sources remises sur le disque le 2026-09-21 : `DOLSharp-master`).
##
##   0x16 sous-code 0x06 — SendGroupWindowUpdate (PacketLib1125.cs:410) :
##     u8 0x06, u8 nombre (0 = pas de groupe, envoye a l entree monde),
##     par membre : nom Pascal, classe Pascal (« NPC » pour un pet),
##     u16 object id, u8 niveau. L ordre est l index de groupe (0..7).
##
##   0x70 GroupMemberUpdate (PacketLib1125.cs:440, WriteGroupMemberUpdate) :
##     une suite de blocs, terminee par 0x00. Chaque bloc commence par un octet
##     dont les 3 bits hauts disent le genre et les 5 bits bas l index :
##       0x20 | idx : vie %, mana %, endurance %, statut (0x01 mort, 0x02 mez,
##                    0x04 malade, 0x08 empoisonne, 0x10 linkdead, 0x20 autre
##                    region, 0x40 portee reduite) ;
##       0x40 | idx : u16 zone skin, u16 x, u16 y (le membre bouge) ;
##       0x80 | idx : u8 nombre d effets, par effet u8 0, u16 icone.
##     Un membre dans une autre region : vie/mana/endu a 0 et statut 0x20.
##
##   0xC5 AddFriend / 0xC6 RemoveFriend : noms Pascal, puis 0x00.
##   0xF9 EmoteAnimation : u16 object id, u8 emote (eEmote), u8 0.
##   0x81 Dialog code 0x05 = invitation de groupe (data1 = session id de
##     l inviteur), 0x03 = guilde, 0x08 = quitter la guilde (eDialogCode).
##   Client : InviteToGroup 0x87 (sur la cible), DisbandFromGroup 0x9F ; mais
##   /invite, /disband, /makeleader, /autosplit, /friend, /who, /afk, /anon,
##   /send passent tous par 0xAF, ce que le client sait deja faire.

const OPCODE_GROUP_MEMBER_UPDATE := 0x70
const OPCODE_ADD_FRIEND := 0xC5
const OPCODE_REMOVE_FRIEND := 0xC6
const OPCODE_EMOTE_ANIMATION := 0xF9
const SUBCODE_GROUP_WINDOW := 0x06

const STATUS_FLAGS := {0x01: "dead", 0x02: "mezzed", 0x04: "diseased", 0x08: "poisoned",
	0x10: "linkdead", 0x20: "other_region", 0x40: "range_reduced"}

const EMOTES := {
	0x1: "beckon", 0x2: "blush", 0x3: "bow", 0x4: "cheer", 0x5: "clap", 0x6: "cry", 0x7: "curtsey",
	0x8: "flex", 0x9: "blowkiss", 0xa: "dance", 0xb: "laugh", 0xc: "point", 0xd: "salute",
	0xe: "bangonshield", 0xf: "victory", 0x10: "wave", 0x11: "distract", 0x12: "midgardfrenzy",
	0x13: "throwdirt", 0x14: "stagfrenzy", 0x15: "roar", 0x16: "drink", 0x17: "ponder", 0x18: "military",
	0x19: "present", 0x1b: "rude", 0x1c: "taunt", 0x1d: "hug", 0x1e: "letsgo", 0x1f: "meditate",
	0x20: "no", 0x21: "raise", 0x22: "shrug", 0x23: "slap", 0x24: "slit", 0x25: "surrender", 0x26: "yes",
	0x27: "beg", 0x28: "induct", 0x29: "dismiss", 0x2a: "lvlup", 0x2b: "pray", 0x2c: "bind",
	0x2d: "spellgoboom", 0x2e: "knock", 0x2f: "smile", 0x30: "angry",
}


static func decode_group_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2 or int(payload[0]) != SUBCODE_GROUP_WINDOW:
		return {"ok": false, "error": "not_a_group_window"}
	var count := int(payload[1])
	var members: Array = []
	var offset := 2
	for index in range(count):
		var name := _pascal(payload, offset)
		if not bool(name.get("ok", false)):
			return {"ok": false, "error": "group_member_name_truncated", "index": index}
		offset = int(name["next"])
		var salutation := _pascal(payload, offset)
		if not bool(salutation.get("ok", false)):
			return {"ok": false, "error": "group_member_class_truncated", "index": index}
		offset = int(salutation["next"])
		if offset + 3 > payload.size():
			return {"ok": false, "error": "group_member_tail_truncated", "index": index}
		members.append({"index": index, "name": str(name["text"]), "class_name": str(salutation["text"]),
			"object_id": _u16(payload, offset), "level": int(payload[offset + 2]),
			"is_pet": str(salutation["text"]) == "NPC"})
		offset += 3
	return {"ok": true, "count": count, "members": members, "in_group": count > 0, "trailing_bytes": payload.size() - offset}


static func decode_member_update(payload: PackedByteArray) -> Dictionary:
	var updates: Array = []
	var offset := 0
	while offset < payload.size():
		var head := int(payload[offset])
		if head == 0:
			offset += 1
			break
		var kind := head & 0xE0
		var index := head & 0x1F
		offset += 1
		if kind == 0x20:
			if offset + 4 > payload.size():
				return {"ok": false, "error": "member_status_truncated", "index": index}
			var status := int(payload[offset + 3])
			var flags: Array = []
			for bit in STATUS_FLAGS:
				if (status & int(bit)) != 0:
					flags.append(STATUS_FLAGS[bit])
			updates.append({"kind": "status", "index": index, "health_percent": int(payload[offset]),
				"mana_percent": int(payload[offset + 1]), "endurance_percent": int(payload[offset + 2]),
				"status": status, "flags": flags, "other_region": (status & 0x20) != 0, "dead": (status & 0x01) != 0})
			offset += 4
		elif kind == 0x40:
			if offset + 6 > payload.size():
				return {"ok": false, "error": "member_map_truncated", "index": index}
			updates.append({"kind": "map", "index": index, "zone_skin_id": _u16(payload, offset),
				"zone_x": _u16(payload, offset + 2), "zone_y": _u16(payload, offset + 4)})
			offset += 6
		elif kind == 0x80:
			if offset >= payload.size():
				return {"ok": false, "error": "member_icons_truncated", "index": index}
			var count := int(payload[offset])
			offset += 1
			var icons: Array = []
			for i in range(count):
				if offset + 3 > payload.size():
					return {"ok": false, "error": "member_icon_truncated", "index": index}
				icons.append(_u16(payload, offset + 1))
				offset += 3
			updates.append({"kind": "icons", "index": index, "icons": icons})
		else:
			return {"ok": false, "error": "member_block_unknown", "head": head, "offset": offset - 1}
	return {"ok": true, "updates": updates, "trailing_bytes": payload.size() - offset}


static func decode_friends(payload: PackedByteArray) -> Dictionary:
	var names: Array = []
	var offset := 0
	while offset < payload.size():
		var size := int(payload[offset])
		if size == 0:
			offset += 1
			break
		if offset + 1 + size > payload.size():
			return {"ok": false, "error": "friend_name_truncated"}
		names.append(payload.slice(offset + 1, offset + 1 + size).get_string_from_ascii())
		offset += 1 + size
	return {"ok": true, "names": names}


static func decode_emote(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 3:
		return {"ok": false, "error": "emote_too_short"}
	var emote := int(payload[2])
	return {"ok": true, "object_id": _u16(payload, 0), "emote": emote, "name": str(EMOTES.get(emote, "emote_%d" % emote))}


## Encodeurs pour les suites a faux pair.
static func encode_group_window(members: Array) -> PackedByteArray:
	var out := PackedByteArray([SUBCODE_GROUP_WINDOW, members.size()])
	for value in members:
		var m := value as Dictionary
		_write_pascal(out, str(m.get("name", "")))
		_write_pascal(out, str(m.get("class_name", "NPC")))
		var oid := int(m.get("object_id", 0))
		out.append((oid >> 8) & 0xff)
		out.append(oid & 0xff)
		out.append(int(m.get("level", 1)) & 0xff)
	return out


static func encode_member_status(index: int, health: int, mana: int, endurance: int, status: int) -> PackedByteArray:
	return PackedByteArray([0x20 | (index & 0x1F), health & 0xff, mana & 0xff, endurance & 0xff, status & 0xff])


static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": payload.slice(offset + 1, offset + 1 + size).get_string_from_ascii(), "next": offset + 1 + size}


static func _write_pascal(out: PackedByteArray, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	out.append(bytes.size() & 0xff)
	out.append_array(bytes)


static func _u16(p: PackedByteArray, o: int) -> int:
	return ((int(p[o]) & 0xff) << 8) | (int(p[o + 1]) & 0xff)
