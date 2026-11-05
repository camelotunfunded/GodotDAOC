extends RefCounted
class_name DaocOpenDaocEconomyCodec

## P1-122 — l'economie hors marchand : artisanat, coffre, consignation, marche.
##
## CE QUE LE CLIENT ENVOIE (eden.dll.c, rien de memoire) :
##   0xED CraftRequest, 4 octets (FUN_0042b84c + htons) : u16 CraftedItemID,
##        u16 poubelle. OpenDAoC MakeProductHandler -> Recipe.FindBy(id).
##   0x1A SetMarketPrice, 8 octets (FUN_0042b088 + htonl) : u8 logement
##        RELATIF a la consignation (0..99), 3 poubelle, u32 prix en cuivre.
##   0x1C WithDrawMerchantMoney, 4 octets de poubelle (FUN_0042b0bb).
##   0x11 MarketSearchRequest, taille variable (FUN_0042b0f9) : chaine = u32
##        PETIT-boutiste de longueur (NUL compris) puis les octets ; u8
##        emplacement ; trois bonus (u8 type, u8, u8 valeur, u8) ; u8 proc,
##        u8 ; u8 armure, u8 degats, u8 niveau min, u8 max, u8 qualite min ;
##        u32 LE prix min, u32 LE prix max ; u8 artisan, u8 visuel, u8 page.
##        OpenDAoC PlayerMarketSearchRequestHandler lit exactement cela.
##
## CE QUE LE SERVEUR ENVOIE (PacketLib168, herite jusqu'en 1.124) :
##   0x1E ConsignmentMerchantMoney : la meme bourse de huit octets que 0xFA.
##   0x1F MarketExplorerWindow : 255 + trois 0 = fenetre vide a ouvrir ; sinon
##        u8 nombre, u8 page, u8 pages, u8 0 puis par objet u8 index, u8 niveau,
##        u8 valeur1, u8 valeur2, u8 main << 6, u8 degats << 6 | type,
##        u8 1 = inutilisable, u16 poids, u8 condition %, u8 durabilite %,
##        u8 qualite, u8 bonus, u16 modele, u16 couleur, u16 effet, u16 lot
##        (numero de maison), u32 prix, nom Pascal.
##   0x02 avec le type de fenetre 3 (coffre), 4 (coffre de maison),
##        5 (consignation proprietaire), 6 (consignation visiteur) : le contenu,
##        aux logements CLIENT 110..149 (coffre) ou 150..249 (maison,
##        consignation) — OpenDAoC eInventorySlot / GameInventoryObject.
##   Acheter au marche = 0xDD depuis 1000 + index vers le sac (MarketExplorer).

const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")

const OPCODE_CRAFT_REQUEST := 0xED
const OPCODE_SET_MARKET_PRICE := 0x1A
const OPCODE_WITHDRAW_MERCHANT_MONEY := 0x1C
const OPCODE_MARKET_SEARCH := 0x11
const OPCODE_CONSIGNMENT_MONEY := 0x1E
const OPCODE_MARKET_EXPLORER := 0x1F

const WINDOW_PLAYER_VAULT := 3
const WINDOW_HOUSE_VAULT := 4
const WINDOW_CONSIGNMENT_OWNER := 5
const WINDOW_CONSIGNMENT_VIEWER := 6
const WINDOW_NAMES := {3: "Coffre", 4: "Coffre de la maison", 5: "Votre marchand", 6: "Marchand de consignation"}
const FIRST_VAULT := 110
const LAST_VAULT := 149
const FIRST_HOUSING := 150
const LAST_HOUSING := 249
const MARKET_EXPLORER_FIRST := 1000


static func is_external_slot(slot: int) -> bool:
	return slot >= FIRST_VAULT and slot <= LAST_HOUSING


static func is_external_window(window_type: int) -> bool:
	return window_type >= WINDOW_PLAYER_VAULT and window_type <= WINDOW_CONSIGNMENT_VIEWER


## Premier logement client de la fenetre (coffre 110, maison/consignation 150).
static func first_slot_of(window_type: int) -> int:
	return FIRST_VAULT if window_type == WINDOW_PLAYER_VAULT else FIRST_HOUSING


static func last_slot_of(window_type: int) -> int:
	return LAST_VAULT if window_type == WINDOW_PLAYER_VAULT else LAST_HOUSING


static func build_craft_payload(recipe_id: int) -> PackedByteArray:
	if recipe_id <= 0 or recipe_id > 0xffff:
		return PackedByteArray()
	return PackedByteArray([(recipe_id >> 8) & 0xff, recipe_id & 0xff, 0, 0])


static func build_set_price_payload(relative_slot: int, price: int) -> PackedByteArray:
	if relative_slot < 0 or relative_slot > 0xff or price < 0 or price > 0xffffffff:
		return PackedByteArray()
	return PackedByteArray([relative_slot, 0, 0, 0,
		(price >> 24) & 0xff, (price >> 16) & 0xff, (price >> 8) & 0xff, price & 0xff])


static func build_withdraw_payload() -> PackedByteArray:
	return PackedByteArray([0, 0, 0, 0])


static func build_market_search_payload(search: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var name := str(search.get("name", "")).to_ascii_buffer()
	_u32_le(out, name.size() + 1)
	out.append_array(name)
	out.append(0)
	out.append(int(search.get("slot", 0)) & 0xff)
	var bonuses: Array = search.get("bonuses", []) as Array
	for index in range(3):
		var bonus: Array = bonuses[index] as Array if index < bonuses.size() else [0, 0]
		out.append_array(PackedByteArray([int(bonus[0]) & 0xff, 0, int(bonus[1]) & 0xff, 0]))
	out.append(int(search.get("proc", 0)) & 0xff)
	out.append(0)
	for key in ["armor_type", "damage_type", "level_min", "level_max", "quality_min"]:
		out.append(int(search.get(key, 0 if key != "level_max" else 51)) & 0xff)
	_u32_le(out, int(search.get("price_min", 0)))
	_u32_le(out, int(search.get("price_max", 0)))
	out.append(1 if bool(search.get("player_crafted", false)) else 0)
	out.append(int(search.get("visual", 0)) & 0xff)
	out.append(int(search.get("page", 0)) & 0xff)
	return out


static func decode_consignment_money(payload: PackedByteArray) -> Dictionary:
	return MerchantCodec.decode_money(payload)


static func decode_market_explorer(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "market_truncated"}
	if int(payload[0]) == 255:
		return {"ok": true, "open_empty": true, "items": [], "page": 0, "max_page": 0}
	var count := int(payload[0])
	var at := 4
	var items: Array = []
	for index in range(count):
		if at + 26 > payload.size():
			return {"ok": false, "error": "market_item_truncated", "index": index}
		var name_size := int(payload[at + 25])
		if at + 26 + name_size > payload.size():
			return {"ok": false, "error": "market_name_truncated", "index": index}
		var type_byte := int(payload[at + 5])
		items.append({
			"index": int(payload[at]), "level": int(payload[at + 1]),
			"value1": int(payload[at + 2]), "value2": int(payload[at + 3]),
			"hand": (int(payload[at + 4]) >> 6) & 3, "object_type": type_byte & 0x3f,
			"damage_type": (type_byte >> 6) & 3, "unusable": int(payload[at + 6]) == 1,
			"weight": _u16(payload, at + 7), "condition": int(payload[at + 9]),
			"durability": int(payload[at + 10]), "quality": int(payload[at + 11]),
			"bonus": int(payload[at + 12]), "model": _u16(payload, at + 13),
			"color": _u16(payload, at + 15), "effect": _u16(payload, at + 17),
			"lot": _u16(payload, at + 19), "price": _u32(payload, at + 21),
			"name": payload.slice(at + 26, at + 26 + name_size).get_string_from_ascii(),
		})
		at += 26 + name_size
	return {"ok": true, "open_empty": false, "items": items, "page": int(payload[1]), "max_page": int(payload[2])}


static func encode_market_explorer(items: Array, page: int = 0, max_page: int = 0) -> PackedByteArray:
	var out := PackedByteArray([items.size(), page, max_page, 0])
	for value in items:
		var item := value as Dictionary
		out.append_array(PackedByteArray([int(item.get("index", 0)), int(item.get("level", 1)),
			int(item.get("value1", 0)), int(item.get("value2", 0)), int(item.get("hand", 0)) << 6,
			(int(item.get("damage_type", 0)) << 6) | int(item.get("object_type", 0)),
			1 if bool(item.get("unusable", false)) else 0]))
		_u16_be(out, int(item.get("weight", 0)))
		out.append_array(PackedByteArray([int(item.get("condition", 100)), int(item.get("durability", 100)),
			int(item.get("quality", 100)), int(item.get("bonus", 0))]))
		for key in ["model", "color", "effect", "lot"]:
			_u16_be(out, int(item.get(key, 0)))
		var price := int(item.get("price", 0))
		out.append_array(PackedByteArray([(price >> 24) & 0xff, (price >> 16) & 0xff, (price >> 8) & 0xff, price & 0xff]))
		var name := str(item.get("name", "")).to_ascii_buffer()
		out.append(name.size())
		out.append_array(name)
	return out


static func _u16(data: PackedByteArray, at: int) -> int:
	return (int(data[at]) << 8) | int(data[at + 1])


static func _u32(data: PackedByteArray, at: int) -> int:
	return (int(data[at]) << 24) | (int(data[at + 1]) << 16) | (int(data[at + 2]) << 8) | int(data[at + 3])


static func _u16_be(out: PackedByteArray, value: int) -> void:
	out.append((value >> 8) & 0xff)
	out.append(value & 0xff)


static func _u32_le(out: PackedByteArray, value: int) -> void:
	out.append(value & 0xff)
	out.append((value >> 8) & 0xff)
	out.append((value >> 16) & 0xff)
	out.append((value >> 24) & 0xff)
