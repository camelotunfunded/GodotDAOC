extends RefCounted
class_name DaocOpenDaocCombatControlCodec

## P1-109 — la cible au sol, les armes de siege, la fenetre de compte a
## rebours. Lu dans DOL (`DOLSharp-master`) et game.dll (`eden.dll.c`).
##
##   Cible au sol, client 0xEC PlayerGroundTarget, 16 octets (game.dll
##   FUN_0042950c puis FUN_0042876a = htonl) : u32 x, u32 y, u32 z, u8
##   visible (1 si la cible est en vue), 3 x 0. DOL lit x, y, z puis un u16
##   dont le bit 0x100 est « visible » — le u8 a l octet 12 EST l octet haut
##   de ce u16. Serveur 0xEC ChangeGroundTarget (PacketLib168) : u32 x, u32
##   y, u32 z — la position que le serveur impose (Nowhere -> 0, 0, 0).
##
##   Siege, client 0xF5 SiegeCommandRequest, 16 octets (FUN_0042ade8) : u16
##   0, u8 action, u8 munition, 12 x 0 ; le client refuse d en envoyer deux
##   en moins d une seconde (DAT_00d904a8 = 1000). Actions (DOL
##   SiegeWeaponActionHandler) : 1 charger, 2 armer, 3 viser, 4 tirer, 5
##   deplacer, 6 reparer, 7 recycler, 8 relacher, 9 arreter, 10 balancer.
##   Serveur 0xF5 SiegeWeaponInterface (PacketLib1124) : u16 drapeau (bit 0
##   = peut bouger, octet haut = type de munition), u8 0, u8 fermer (1 =
##   fermer), u8 temps x 100 ms, u8 munitions externes, u8 action en cours,
##   u8 logement de munition, u16 effet, u16 0, u16 0, u16 oid, puis par
##   munition 24 octets (ou 24 zeros) : u8 index, u16 0, u8 niveau, 4 x u8,
##   u8 1, u8 0, u8 nombre, u8 etat %, u8 durabilite %, u8 qualite %, u8
##   bonus, u8 niveau de bonus, u16 modele, u8 extension, u16 0, u8 4, u16
##   0, nom Pascal ; enfin le nom de l arme « nom (etat) » Pascal. La
##   fermeture (SendSiegeWeaponCloseInterface) : u16 0, u16 1, 13 x 0.
##   Serveur 0xE3 SiegeWeaponAnimation (PacketLib1124 / 1110 pour le tir) :
##   u32 oid, u32 x, u32 y, u32 z de visee, u32 oid cible, u16 effet, u16
##   temps restant, u8 action (1 viser, 2 armer, 3 charger, 4 tirer), puis
##   3 octets qui dependent de l action.
##
##   Compte a rebours, serveur 0xF3 TimerWindow (PacketLib168) : u16
##   secondes, u8 longueur du titre, u8 1, titre (SANS prefixe Pascal — la
##   longueur est l octet 2). La fermeture : u16 0, u8 0, u8 0. DOL s en
##   sert pour le /release (« Release Timer »), les sieges et les quetes.

const OPCODE_GROUND_TARGET := 0xEC
const OPCODE_SIEGE := 0xF5
const OPCODE_SIEGE_ANIMATION := 0xE3
const OPCODE_TIMER_WINDOW := 0xF3
## 0xF6 ChangeTarget (PacketLib168) : u16 oid (0 = plus de cible), u16 0. DOL
## l envoie pour /assist (YouAssist) et quand une cible disparait.
const OPCODE_CHANGE_TARGET := 0xF6


static func decode_change_target(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2:
		return {"ok": false, "error": "change_target_too_short", "size": payload.size()}
	var object_id := _u16(payload, 0)
	return {"ok": true, "object_id": object_id, "cleared": object_id == 0}


static func encode_change_target(object_id: int) -> PackedByteArray:
	return PackedByteArray([(object_id >> 8) & 0xff, object_id & 0xff, 0, 0])
const GROUND_TARGET_VISIBLE_FLAG := 0x100
const SIEGE_CLIENT_COOLDOWN_MSEC := 1000

const SIEGE_ACTIONS := {1: "load", 2: "arm", 3: "aim", 4: "fire", 5: "move", 6: "repair", 7: "salvage", 8: "release", 9: "stop", 10: "swing"}
const SIEGE_ACTION_CODES := {"load": 1, "arm": 2, "aim": 3, "fire": 4, "move": 5, "repair": 6, "salvage": 7, "release": 8, "stop": 9, "swing": 10}
const SIEGE_TIMER_ACTIONS := {0: "none", 1: "aiming", 2: "arming", 3: "loading", 4: "fire"}


static func build_ground_target_payload(x: int, y: int, z: int, visible: bool = true) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(16)
	_w32(out, 0, x)
	_w32(out, 4, y)
	_w32(out, 8, z)
	out[12] = 1 if visible else 0
	return out


static func decode_ground_target_request(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 14:
		return {"ok": false, "error": "ground_target_request_too_short", "size": payload.size()}
	var flag := _u16(payload, 12)
	return {"ok": true, "x": _u32(payload, 0), "y": _u32(payload, 4), "z": _u32(payload, 8), "flag": flag, "visible": (flag & GROUND_TARGET_VISIBLE_FLAG) != 0}


static func decode_change_ground_target(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 12:
		return {"ok": false, "error": "change_ground_target_too_short", "size": payload.size()}
	var x := _u32(payload, 0)
	var y := _u32(payload, 4)
	var z := _u32(payload, 8)
	return {"ok": true, "x": x, "y": y, "z": z, "cleared": x == 0 and y == 0 and z == 0}


static func build_siege_command_payload(action: int, ammo: int = 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(16)
	out[2] = action & 0xff
	out[3] = ammo & 0xff
	return out


static func siege_action_code(name: String) -> int:
	return int(SIEGE_ACTION_CODES.get(name.to_lower(), 0))


static func decode_siege_interface(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 17:
		return {"ok": false, "error": "siege_interface_too_short", "size": payload.size()}
	var flag := _u16(payload, 0)
	var out := {
		"ok": true,
		"can_move": (flag & 1) != 0,
		"ammo_type": (flag >> 8) & 0xff,
		"close": int(payload[3]) != 0,
		"time_msec": int(payload[4]) * 100,
		"external_ammo_count": int(payload[5]),
		"action_code": int(payload[6]),
		"action": str(SIEGE_TIMER_ACTIONS.get(int(payload[6]), "action_%d" % int(payload[6]))),
		"ammo_slot": int(payload[7]),
		"effect": _u16(payload, 8),
		"object_id": _u16(payload, 14),
		"ammo": [],
		"name": "",
	}
	if bool(out["close"]):
		out["trailing_bytes"] = payload.size() - 17
		return out
	var offset := 16
	var ammo: Array = []
	# Chaque munition (l octet 5 en donne le nombre) : 24 octets fixes puis un
	# nom Pascal ; un logement vide est 24 zeros sans nom. Le dernier Pascal du
	# paquet est le nom de l arme.
	for i in range(int(out["external_ammo_count"])):
		if offset + 24 > payload.size():
			return {"ok": false, "error": "siege_ammo_truncated", "index": i}
		var chunk := payload.slice(offset, offset + 24)
		var empty := true
		for b in chunk:
			if int(b) != 0:
				empty = false
				break
		if empty:
			ammo.append({})
			offset += 24
			continue
		var entry := {
			"index": int(payload[offset]), "level": int(payload[offset + 3]), "object_type": int(payload[offset + 7]),
			"count": int(payload[offset + 10]), "condition_percent": int(payload[offset + 11]), "durability_percent": int(payload[offset + 12]),
			"quality_percent": int(payload[offset + 13]), "bonus": int(payload[offset + 14]), "model": _u16(payload, offset + 16),
		}
		var name := _pascal(payload, offset + 24)
		if not bool(name.get("ok", false)):
			return {"ok": false, "error": "siege_ammo_name_truncated", "index": ammo.size()}
		entry["name"] = str(name["text"])
		ammo.append(entry)
		offset = int(name["next"])
	out["ammo"] = ammo
	var weapon_name := _pascal(payload, offset)
	if bool(weapon_name.get("ok", false)):
		out["name"] = str(weapon_name["text"])
		offset = int(weapon_name["next"])
	out["trailing_bytes"] = payload.size() - offset
	return out


static func decode_siege_animation(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 25:
		return {"ok": false, "error": "siege_animation_too_short", "size": payload.size()}
	var action := int(payload[24])
	var out := {
		"ok": true, "object_id": _u32(payload, 0), "x": _u32(payload, 4), "y": _u32(payload, 8), "z": _u32(payload, 12),
		"target_id": _u32(payload, 16), "effect": _u16(payload, 20), "time_msec": _u16(payload, 22),
		"action_code": action, "action": str(SIEGE_TIMER_ACTIONS.get(action, "action_%d" % action)),
	}
	if action == 1 and payload.size() >= 28:
		out["target_short_id"] = _u16(payload, 26)
	out["trailing_bytes"] = maxi(0, payload.size() - 25)
	return out


static func decode_timer_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "timer_window_too_short", "size": payload.size()}
	var seconds := _u16(payload, 0)
	var length := int(payload[2])
	if seconds == 0 and length == 0:
		return {"ok": true, "close": true, "seconds": 0, "title": ""}
	if 4 + length > payload.size():
		return {"ok": false, "error": "timer_window_title_truncated", "length": length}
	return {"ok": true, "close": false, "seconds": seconds, "title": payload.slice(4, 4 + length).get_string_from_ascii(), "flag": int(payload[3])}


## Encodeurs pour les suites a faux pair.
static func encode_change_ground_target(x: int, y: int, z: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(12)
	_w32(out, 0, x); _w32(out, 4, y); _w32(out, 8, z)
	return out


static func encode_timer_window(title: String, seconds: int) -> PackedByteArray:
	var out := PackedByteArray([(seconds >> 8) & 0xff, seconds & 0xff, title.length() & 0xff, 1])
	out.append_array(title.to_ascii_buffer())
	return out


static func encode_timer_close() -> PackedByteArray:
	return PackedByteArray([0, 0, 0, 0])


static func encode_siege_close() -> PackedByteArray:
	var out := PackedByteArray([0, 0, 0, 1])
	out.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
	return out


## `ammo` : [{name, count, level, model, condition_percent, durability_percent, quality_percent}] ou {} pour un logement vide.
static func encode_siege_interface(object_id: int, name: String, action_code: int, time_msec: int, can_move: bool, ammo: Array, ammo_type: int = 0, effect: int = 0) -> PackedByteArray:
	var flag := (1 if can_move else 0) | ((ammo_type & 0xff) << 8)
	var out := PackedByteArray([(flag >> 8) & 0xff, flag & 0xff, 0, 0, (time_msec / 100) & 0xff, ammo.size() & 0xff, action_code & 0xff, 0,
		(effect >> 8) & 0xff, effect & 0xff, 0, 0, 0, 0, (object_id >> 8) & 0xff, object_id & 0xff])
	for i in ammo.size():
		var item := ammo[i] as Dictionary
		if item.is_empty():
			var zeros := PackedByteArray()
			zeros.resize(24)
			out.append_array(zeros)
			continue
		var model := int(item.get("model", 0))
		out.append_array(PackedByteArray([i, 0, 0, int(item.get("level", 0)), 0, 0, 0, int(item.get("object_type", 0)), 1, 0, int(item.get("count", 1)),
			int(item.get("condition_percent", 100)), int(item.get("durability_percent", 100)), int(item.get("quality_percent", 100)), int(item.get("bonus", 0)), 0,
			(model >> 8) & 0xff, model & 0xff, 0, 0, 0, 4, 0, 0]))
		var text := str(item.get("name", ""))
		if int(item.get("count", 1)) > 1:
			text = "%d %s" % [int(item.get("count", 1)), text]
		_write_pascal(out, text)
	_write_pascal(out, name)
	return out


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


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func _u32(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


static func _w32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
