extends RefCounted

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const INVENTORY_UPDATE_OPCODE := 0x02
const PLAYER_MOVE_ITEM_OPCODE := 0xDD
const GIVE_SLOT_BASE := 1000

const SLOT_RIGHT_HAND := 10
const SLOT_TWO_HAND := 12
const SLOT_FIRST_BACKPACK := 40
const SLOT_LAST_BACKPACK := 79
const OBJECT_TYPE_STAFF := 8

var _packet_codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func build_move_item_payload(item_id: int, to_slot: int, from_slot: int, item_count: int = 1) -> PackedByteArray:
	if item_id < 0 or item_id > 0xffff:
		return PackedByteArray()
	# P1-121 : une destination au-dela de 1000 est un OBJET du monde (1000 + son
	# ObjectID) - OpenDAoC PlayerMoveItemRequestHandler.MoveItemToTargetObject :
	# donner a un PNJ (forgeron, quete), ouvrir un echange avec un joueur.
	var to_world_object := to_slot > GIVE_SLOT_BASE and to_slot <= 0xffff
	# P1-122 : une SOURCE a partir de 1000 est une ligne du marche (OpenDAoC
	# MarketExplorer.FirstClientSlot = 1000) : l acheter, c est la deplacer au sac.
	var from_market := from_slot >= GIVE_SLOT_BASE and from_slot <= 0xffff
	if not (to_world_object or _is_valid_inventory_slot(to_slot)) or not (from_market or _is_valid_inventory_slot(from_slot)):
		return PackedByteArray()
	if to_slot == from_slot or item_count < 1 or item_count > 0xffff:
		return PackedByteArray()
	var payload := PackedByteArray()
	payload.append_array(_packet_codec.call("u16_be_write", item_id) as PackedByteArray)
	payload.append_array(_packet_codec.call("u16_be_write", to_slot) as PackedByteArray)
	payload.append_array(_packet_codec.call("u16_be_write", from_slot) as PackedByteArray)
	payload.append_array(_packet_codec.call("u16_be_write", item_count) as PackedByteArray)
	return payload


func build_move_item_packet(item_id: int, to_slot: int, from_slot: int, item_count: int, sequence: int, session_id: int, parameter: int = 0) -> PackedByteArray:
	var payload := build_move_item_payload(item_id, to_slot, from_slot, item_count)
	if payload.size() != 8:
		return PackedByteArray()
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", PLAYER_MOVE_ITEM_OPCODE, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	return _packet_codec.call("build_client_packet", PLAYER_MOVE_ITEM_OPCODE, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray


func decode_inventory_update_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error": parsed.get("parse_status", "invalid_server_packet")}
	if int(parsed.get("opcode", -1)) != INVENTORY_UPDATE_OPCODE:
		return {"ok": false, "error": "unexpected_opcode", "opcode": int(parsed.get("opcode", -1))}
	return decode_inventory_update_payload(parsed.get("payload", PackedByteArray()) as PackedByteArray)


## P1-95 — la disposition 1.124+ MESUREE sur les 0x02 de la capture P1-20C
## (juillet, Heyveno, 8 pieces de depart + pierre de rappel), relus octet par
## octet dans reports/p1_95_inventory/p1_20c_inventory_packets.txt. L'ancienne
## disposition 1.68 (en-tete 4, objet 19) rendait `inventory_item_name_truncated`
## sur chaque 0x02 d'Eden : l'inventaire Online restait VIDE.
##
##   en-tete, 6 octets : u8 nombre, u8 0, u8 0, u8 0,
##     u8 VisibleActiveWeaponSlots (quartet bas = main droite, haut = gauche,
##     0x10 = epee 10 + bouclier 11, 0xFF = aucune), u8 type de fenetre
##     (1 = equipement, 2 = inventaire) ;
##   objet, u8 logement + 24 octets fixes + nom : u16 0 (inconnu 1.124),
##     u8 niveau, u8 valeur1 (DPS / AF), u8 valeur2 (SPD / ABS), u8 main << 6,
##     u8 type de degats << 6 | type d objet, u8 0, u16 poids, u8 condition,
##     u8 durabilite, u8 qualite, u8 bonus, u8 niveau de bonus, u16 modele,
##     u8 extension, u16 couleur ou embleme, u8 drapeaux (0x02 = recyclable,
##     toujours pose par DOL), u16 effet, u8 longueur du nom, nom (1252).
##   Preuves : epee d entrainement 0c 19 83 = DPS 12, SPD 25, tranchant, type 3 ;
##   bouclier 80 6a = main gauche, taille 1, type 42 ; casque 04 13 22 = AF 4,
##   ABS 19, type 34 (P1-24 dit exactement ces chiffres).
const HEADER_SIZE_1124 := 6
const ITEM_FIXED_SIZE_1124 := 24


func decode_inventory_update_payload(payload: PackedByteArray) -> Dictionary:
	var modern := decode_inventory_update_payload_1124(payload)
	if bool(modern.get("ok", false)):
		return modern
	var legacy := decode_inventory_update_payload_168(payload)
	if bool(legacy.get("ok", false)):
		legacy["layout"] = "1.68"
		return legacy
	return modern


func decode_inventory_update_payload_1124(payload: PackedByteArray) -> Dictionary:
	if payload.size() < HEADER_SIZE_1124:
		return {"ok": false, "error": "inventory_header_truncated", "layout": "1.124"}
	var count := int(payload[0])
	var offset := HEADER_SIZE_1124
	var items: Array[Dictionary] = []
	for index in range(count):
		if offset >= payload.size():
			return {"ok": false, "error": "inventory_slot_missing", "item_index": index, "layout": "1.124"}
		var slot := int(payload[offset])
		offset += 1
		if offset + ITEM_FIXED_SIZE_1124 > payload.size():
			return {"ok": false, "error": "inventory_item_truncated", "slot": slot, "layout": "1.124"}
		if _all_zero(payload, offset, ITEM_FIXED_SIZE_1124):
			items.append({"slot": slot, "empty": true})
			offset += ITEM_FIXED_SIZE_1124
			continue
		var name_size := int(payload[offset + 23])
		var next_offset := offset + ITEM_FIXED_SIZE_1124 + name_size
		if next_offset > payload.size():
			return {"ok": false, "error": "inventory_item_name_truncated", "slot": slot, "layout": "1.124"}
		var hand_byte := int(payload[offset + 5])
		var type_byte := int(payload[offset + 6])
		items.append({
			"slot": slot,
			"empty": false,
			"unknown_u16": int(_packet_codec.call("u16_be_read", payload, offset)),
			"level": int(payload[offset + 2]),
			"value1": int(payload[offset + 3]),
			"value2": int(payload[offset + 4]),
			"hand": (hand_byte >> 6) & 0x03,
			"object_type": type_byte & 0x3f,
			"damage_type": (type_byte >> 6) & 0x03,
			"weight": int(_packet_codec.call("u16_be_read", payload, offset + 8)),
			"condition": int(payload[offset + 10]),
			"durability": int(payload[offset + 11]),
			"quality": int(payload[offset + 12]),
			"bonus": int(payload[offset + 13]),
			"bonus_level": int(payload[offset + 14]),
			"model": int(_packet_codec.call("u16_be_read", payload, offset + 15)),
			"extension": int(payload[offset + 17]),
			"color_or_emblem": int(_packet_codec.call("u16_be_read", payload, offset + 18)),
			"flags": int(payload[offset + 20]),
			"effect": int(_packet_codec.call("u16_be_read", payload, offset + 21)),
			"name": str(_packet_codec.call("decode_windows_1252", payload.slice(offset + ITEM_FIXED_SIZE_1124, next_offset))),
		})
		offset = next_offset
	if offset != payload.size():
		return {"ok": false, "error": "inventory_trailing_bytes", "trailing_size": payload.size() - offset, "layout": "1.124"}
	var active := int(payload[4])
	return {
		"ok": true,
		"layout": "1.124",
		"count": count,
		"active_weapon_slots": active,
		"active_right_hand": active & 0x0f,
		"active_left_hand": (active >> 4) & 0x0f,
		"window_type": int(payload[5]),
		"items": items,
	}


## Disposition 1.68 (PacketLib168), conservee pour les captures anciennes et
## les suites P1-56 ; elle n est plus celle d Eden.
func decode_inventory_update_payload_168(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "inventory_header_truncated"}
	var count := int(payload[0])
	var offset := 4
	var items: Array[Dictionary] = []
	for index in range(count):
		if offset >= payload.size():
			return {"ok": false, "error": "inventory_slot_missing", "item_index": index}
		var slot := int(payload[offset])
		offset += 1
		if offset + 19 > payload.size():
			return {"ok": false, "error": "inventory_item_truncated", "slot": slot}
		var level := int(payload[offset])
		if level == 0 and _all_zero(payload, offset, 19):
			items.append({"slot": slot, "empty": true})
			offset += 19
			continue
		var hand_and_flags := int(payload[offset + 3])
		var type_and_damage := int(payload[offset + 4])
		var name_size := int(payload[offset + 18])
		var next_offset := offset + 19 + name_size
		if next_offset > payload.size():
			return {"ok": false, "error": "inventory_item_name_truncated", "slot": slot}
		var name_bytes := payload.slice(offset + 19, next_offset)
		items.append({
			"slot": slot,
			"empty": false,
			"level": level,
			"value1": int(payload[offset + 1]),
			"value2": int(payload[offset + 2]),
			"hand": (hand_and_flags >> 6) & 0x03,
			"object_type": type_and_damage & 0x3f,
			"damage_type": (type_and_damage >> 6) & 0x03,
			"weight": int(_packet_codec.call("u16_be_read", payload, offset + 5)),
			"condition": int(payload[offset + 7]),
			"durability": int(payload[offset + 8]),
			"quality": int(payload[offset + 9]),
			"bonus": int(payload[offset + 10]),
			"model": int(_packet_codec.call("u16_be_read", payload, offset + 11)),
			"extension": int(payload[offset + 13]),
			"color_or_emblem": int(_packet_codec.call("u16_be_read", payload, offset + 14)),
			"effect": int(_packet_codec.call("u16_be_read", payload, offset + 16)),
			"name": str(_packet_codec.call("decode_windows_1252", name_bytes)),
		})
		offset = next_offset
	if offset != payload.size():
		return {"ok": false, "error": "inventory_trailing_bytes", "trailing_size": payload.size() - offset}
	return {
		"ok": true,
		"count": count,
		"hood_and_quiver": int(payload[1]),
		"active_weapon_slots": int(payload[2]),
		"window_type": int(payload[3]),
		"items": items,
	}


func find_staff_to_equip(inventory: Dictionary) -> Dictionary:
	if not bool(inventory.get("ok", false)):
		return {"ok": false, "error": "inventory_not_decoded"}
	for raw in inventory.get("items", []):
		var item := raw as Dictionary
		var slot := int(item.get("slot", -1))
		if not bool(item.get("empty", true)) and slot >= SLOT_FIRST_BACKPACK and slot <= SLOT_LAST_BACKPACK and int(item.get("object_type", -1)) == OBJECT_TYPE_STAFF:
			return {
				"ok": true,
				"item": item.duplicate(true),
				"from_slot": slot,
				"to_slot": SLOT_TWO_HAND,
				"item_count": 1,
			}
	return {"ok": false, "error": "no_staff_in_backpack"}


func _is_valid_inventory_slot(slot: int) -> bool:
	return slot == 1 or (slot >= 7 and slot <= 249)


func _all_zero(data: PackedByteArray, offset: int, size: int) -> bool:
	for index in range(offset, offset + size):
		if int(data[index]) != 0:
			return false
	return true
