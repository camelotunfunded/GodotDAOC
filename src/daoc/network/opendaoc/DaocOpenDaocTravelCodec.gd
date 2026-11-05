extends RefCounted
class_name DaocOpenDaocTravelCodec

## P1-115 — se déplacer autrement qu'en marchant : téléportation, portes,
## montures, changement de région.
##
## Rien de mémoire. Chaque disposition est lue dans OpenDAoC-Core master
## (`sources tierces daoc/opendaoc_core_master_2026-09-21/` et son sous-dossier
## `p1_115/`) ET dans le client d'origine décompilé (`eden.dll.c`) :
##
## SERVEUR → CLIENT
## - **0x04 CharacterJump** (`PacketLib168.SendPlayerJump`, jamais surchargé
##   jusqu'en 1.129) : u32 X monde, u32 Y monde, u16 oid, u16 Z, u16 cap, u16
##   maison. Tout gros-boutiste — `FUN_00428a41` fait deux `ntohl` et quatre
##   `ntohs`. X = Y = Z = 0 signifie « cap seulement » (`FUN_004129ab` teste
##   exactement ces trois champs). C'est ce que DOL envoie pour tout
##   `MoveTo` DANS la même région : `/stuck`, retour à la pierre de liaison,
##   téléporteurs, `/release` vers une tombe de la région.
## - **0x99 DoorState** (`PacketLib168.SendDoorState`) : u32 identifiant de
##   porte, u8 1 ouverte / 0 fermée, u8 drapeau (son), u8 vitesse (0xFF =
##   aucune, sinon pourcentage — `FUN_00418359`), u8 0.
## - **0x4E ControlledHorse** (`PacketLib180`) : u16 oid. **Oid 0 = MON
##   cheval** (`SendSetControlledHorse`) : u8 id, u8 caparaçon, u16 couleur du
##   caparaçon, u8 selle, u8 couleur de selle, u8 sacoches, u8 armure, nom
##   Pascal ; ou huit zéros = pas de cheval. **Oid ≠ 0 = le cheval d'un
##   joueur visible** (`SendControlledHorse`) : u8 id, u8 caparaçon, u16
##   couleur, u8 selle, u8 couleur de selle ; six zéros = il n'en a pas.
## - **0xC8 Riding** (`PacketLib168.SendRiding`) : u16 cavalier, u16 monture,
##   u8 1 monter / 0 descendre, u8 place (`RiderSlot`), u16 0.
## - **0xB7 RegionChanged** (`PacketLib174`) : u16 région (skin), u16 zone
##   (skin). Précédé d'un `SendRegions` (0xB1) que le client ne lit pas ici.
##   Côté client d'origine, `case 0xb7` range la région dans `DAT_00d913c0` ;
##   la boucle principale DÉTRUIT alors le monde (« NDLDestroyWorld »), charge
##   la nouvelle région et renvoie un **0xD4 WorldInit** (`FUN_0042a87b`).
##
## CLIENT → SERVEUR (`eden.dll.c`)
## - **0x99 DoorRequest**, 8 octets (`FUN_0042bd35`) : u32 identifiant
##   (`htonl`), u8 état voulu (1 ouvrir, 0 fermer), trois octets inutilisés.
##   DOL (`DoorRequestHandler`) lit `ReadInt` + `ReadByte`.
## - **0xC8 PlayerDismountRequest**, 8 octets (`FUN_0042b8ee`) : deux u32 ;
##   le second vaut 0x10000 si son drapeau est posé. DOL ne lit RIEN
##   (`PlayerDismountRequestHandler` descend le joueur de sa monture).
## - **0x90 PlayerRegionChangeRequest**, 4 octets (`FUN_0042a6cf` →
##   `FUN_0042c0fc`) : l'identifiant du point de saut, recopié TEL QUEL en
##   mémoire (u32 petit-boutiste, sans `htonl`). Il vient du nom du nœud
##   « jumpNNN » du décor (`FUN_004648ae`, `_atol`), envoyé au plus une fois
##   par dix secondes (`DAT_00d90498 + 10000`). DOL lit un u16 petit-boutiste
##   en 1.126+, gros-boutiste avant : **à confirmer en live** sur ce serveur.
##
## L'IDENTIFIANT D'UNE PORTE (`DoorRequestHandler`, et `FUN_00463f6d` du
## client qui l'écrit « door%03d%04d%02d ») : zone × 1 000 000 + fixture ×
## 100 + pièce. Le client d'origine lit la pièce dans le NOM du nœud du NIF :
## un nœud « door… » de sept caractères au moins, la pièce = `atol` de ce qui
## suit « door » ; un nom de treize caractères porte l'identifiant complet ;
## un huitième caractère « s » fait une porte COULISSANTE (type 3), sinon elle
## PIVOTE (type 1).

const OPCODE_CHARACTER_JUMP := 0x04
const OPCODE_DOOR := 0x99
const OPCODE_CONTROLLED_HORSE := 0x4E
const OPCODE_RIDING := 0xC8
const OPCODE_REGION_CHANGED := 0xB7
const OPCODE_REGION_CHANGE_REQUEST := 0x90
const OPCODE_DISMOUNT_REQUEST := 0xC8

const CHARACTER_JUMP_SIZE := 16
const DOOR_STATE_SIZE := 8
const DOOR_REQUEST_SIZE := 8
const DISMOUNT_REQUEST_SIZE := 8
const REGION_CHANGE_REQUEST_SIZE := 4
## Le client d'origine n'envoie pas deux 0x90 en moins de dix secondes.
const REGION_CHANGE_REQUEST_COOLDOWN_MSEC := 10000

const DOOR_KIND_ROTATING := 1
const DOOR_KIND_SLIDING := 3


## ── 0x04 CharacterJump ──────────────────────────────────────────────────
static func decode_character_jump(payload: PackedByteArray) -> Dictionary:
	if payload.size() < CHARACTER_JUMP_SIZE:
		return {"ok": false, "error": "character_jump_truncated", "size": payload.size()}
	var x := _u32(payload, 0)
	var y := _u32(payload, 4)
	var z := _u16(payload, 10)
	return {
		"ok": true,
		"x": x, "y": y, "z": z,
		"object_id": _u16(payload, 8),
		"heading": _u16(payload, 12),
		"house": _u16(payload, 14),
		# FUN_004129ab : les trois coordonnées nulles = on ne tourne que le cap.
		"heading_only": x == 0 and y == 0 and z == 0,
	}


## ── 0x99 DoorState / DoorRequest ────────────────────────────────────────
static func decode_door_state(payload: PackedByteArray) -> Dictionary:
	if payload.size() < DOOR_STATE_SIZE:
		return {"ok": false, "error": "door_state_truncated", "size": payload.size()}
	var door_id := _u32(payload, 0)
	var speed_byte := int(payload[6])
	var result := {
		"ok": true,
		"door_id": door_id,
		"open": int(payload[4]) == 1,
		"state": int(payload[4]),
		"sound_flag": int(payload[5]),
		# FUN_00418359 : 0xFF = pas de vitesse imposée, 0 = 0,01, sinon n / 100.
		"speed": 0.0 if speed_byte == 0xFF else (0.01 if speed_byte == 0 else float(speed_byte) * 0.01),
	}
	result.merge(split_door_id(door_id))
	return result


static func build_door_request_payload(door_id: int, open: bool) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(DOOR_REQUEST_SIZE)
	_w32(payload, 0, door_id)
	payload[4] = 1 if open else 0
	return payload


## zone × 1 000 000 + fixture × 100 + pièce (DoorRequestHandler).
static func door_id_for(zone: int, fixture_id: int, piece: int) -> int:
	return zone * 1000000 + fixture_id * 100 + piece


static func split_door_id(door_id: int) -> Dictionary:
	var zone := door_id / 1000000
	var fixture_part := door_id - zone * 1000000
	return {"door_zone": zone, "door_fixture": fixture_part / 100, "door_piece": fixture_part % 100,
		"door_type": door_id / 100000000}


## La règle de nommage du client d'origine (`FUN_00463f6d`) pour un nœud NIF.
## Rend `{}` quand le nœud n'est pas une porte.
static func door_node_info(node_name: String) -> Dictionary:
	if node_name.length() < 7 or not node_name.substr(0, 4).to_lower() == "door":
		return {}
	var digits := node_name.substr(4)
	var kind := DOOR_KIND_SLIDING if node_name.length() >= 8 and node_name[7].to_lower() == "s" else DOOR_KIND_ROTATING
	if node_name.length() == 13:
		var absolute := int(digits.to_int())
		if absolute != 0:
			return {"absolute_id": absolute, "kind": kind}
	var piece := int(_leading_int(digits))
	if piece == 0:
		return {}
	return {"piece": piece, "kind": kind}


## ── 0x4E ControlledHorse ────────────────────────────────────────────────
static func decode_controlled_horse(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 8:
		return {"ok": false, "error": "controlled_horse_truncated", "size": payload.size()}
	var object_id := _u16(payload, 0)
	var own := object_id == 0
	var has_horse := false
	for i in range(2, 8):
		if int(payload[i]) != 0:
			has_horse = true
	var result := {
		"ok": true, "object_id": object_id, "own": own, "has_horse": has_horse,
		"horse_id": int(payload[2]), "barding": int(payload[3]) & 0x7F,
		"barding_guild_emblem": (int(payload[3]) & 0x80) != 0,
		"barding_color": _u16(payload, 4), "saddle": int(payload[6]), "saddle_color": int(payload[7]),
	}
	if own and has_horse and payload.size() >= 10:
		result["saddlebag_slots"] = int(payload[8])
		result["armor"] = int(payload[9])
		var name := _pascal(payload, 10)
		result["name"] = str(name.get("text", "")) if bool(name.get("ok", false)) else ""
	return result


## ── 0xC8 Riding (serveur) / PlayerDismountRequest (client) ──────────────
static func decode_riding(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 6:
		return {"ok": false, "error": "riding_truncated", "size": payload.size()}
	return {"ok": true, "rider_id": _u16(payload, 0), "steed_id": _u16(payload, 2),
		"mounted": int(payload[4]) != 0, "slot": int(payload[5])}


static func build_dismount_payload(flag: bool = false) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(DISMOUNT_REQUEST_SIZE)
	# FUN_0042b8ee : uStack_8 = 0x10000, rangé petit-boutiste → octet 6.
	if flag:
		payload[6] = 1
	return payload


## ── 0xB7 RegionChanged / 0x90 PlayerRegionChangeRequest ─────────────────
static func decode_region_changed(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2:
		return {"ok": false, "error": "region_changed_truncated", "size": payload.size()}
	return {"ok": true, "region_id": _u16(payload, 0),
		"zone_skin_id": _u16(payload, 2) if payload.size() >= 4 else 0}


static func build_region_change_request_payload(jump_point_id: int) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(REGION_CHANGE_REQUEST_SIZE)
	# Recopié tel quel par FUN_0042c0fc : PETIT-boutiste, contrairement au reste.
	payload[0] = jump_point_id & 0xff
	payload[1] = (jump_point_id >> 8) & 0xff
	payload[2] = (jump_point_id >> 16) & 0xff
	payload[3] = (jump_point_id >> 24) & 0xff
	return payload


## ── utilitaires ─────────────────────────────────────────────────────────
static func _leading_int(text: String) -> int:
	var digits := ""
	for c in text:
		if c < "0" or c > "9":
			break
		digits += c
	return digits.to_int() if not digits.is_empty() else 0


static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": payload.slice(offset + 1, offset + 1 + size).get_string_from_ascii(), "next": offset + 1 + size}


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func _u32(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


static func _w32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
