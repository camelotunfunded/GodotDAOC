extends RefCounted
class_name DaocOpenDaocMerchantCodec

## P1-114 — marchand, argent, encombrement, échange. Lu dans DOL
## (`DOLSharp-master`) pour ce que le serveur ENVOIE et dans game.dll
## (`eden.dll.c`) pour ce que le client ENVOIE. Rien de mémoire.
##
##   0x17 MerchantWindow (PacketLib168.SendMerchantWindow — **la disposition
##   1.68 reste celle d Eden** : le premier PacketLib à la réécrire en
##   petit-boutiste est le 1125, `PacketLib1125.SendMerchantWindow`, et Eden
##   parle 1.124). En-tête 4 octets : u8 nombre d objets de la page, u8 type
##   de fenêtre (eMerchantWindowType : 0 normal, 1 points de prime, 2 troc,
##   0x0E mithril, 3..0x0D logement), u8 numéro de page, u8 inutilisé. Puis
##   par objet : u8 index DANS LA PAGE, u8 niveau, u8 valeur1 (DPS / AF, ou
##   la taille de pile pour flèches / carreaux / poisons / objets
##   génériques), u8 SPD / ABS, u8 main << 6 (DPS pour un objet de jardin),
##   u8 type de dégâts << 6 | type d objet, **u8 1 = inutilisable par ta
##   classe (grisé)**, u16 valeur2 (poids, ou pile × poids), u32 PRIX dans la
##   monnaie de la page, u16 modèle, nom Pascal.
##   Une page = un paquet ; DOL en envoie un par page du catalogue.
##
##   0xFA MoneyUpdate (PacketLib168.SendUpdateMoney) : u8 cuivre, u8 argent,
##   u16 or, u16 mithril, u16 platine. Le total se recompose par
##   `Money.GetMoney` : ((((mithril × 1000 + platine) × 1000 + or) × 100 +
##   argent) × 100 + cuivre).
##
##   0xBD Encumberance (PacketLib168.SendEncumberance) : u16 maximum, u16
##   porté. Le maximum est la FORCE modifiée du joueur (GamePlayer
##   .MaxEncumberance) ; au-dessus, DOL renvoie un 0xB6 MaxSpeed ralenti et le
##   message « You are encumbered… » (P1-82 décode déjà le 0xB6).
##
##   0xEA TradeWindow (PacketLib1109.SendTradeWindow, celui d Eden : la 1.68
##   écrivait l objet à plat, la 1.109 délègue à `WriteItemData`, donc au
##   **même bloc de 24 octets + nom que l inventaire 0x02** de P1-95) :
##   10 u8 logements offerts par MOI, u16 0, 5 u16 mon argent (mithril,
##   platine, or, argent, cuivre), u16 0, 5 u16 l argent du PARTENAIRE, u16 0,
##   u8 nombre d objets du partenaire, u8 1, u8 réparation, u8 combinaison,
##   puis par objet du partenaire u8 logement + bloc d objet, enfin le titre
##   Pascal (« Trading with <nom> » / « Selfcrafting »). **Fermer la fenêtre =
##   40 octets nuls** (SendCloseTradeWindow), ce qui est exactement l en-tête
##   vide : un 0xEA tout à zéro FERME.
##
##   Ce que le client envoie (game.dll, aucune supposition) :
##   - 0x78 BuyRequest, **16 octets** (FUN_0042aff8) : u32 x, u32 y, u16
##     session, u16 index de l objet dans la page, u8 nombre, u8 type de
##     fenêtre (celui du 0x17 en cours) — DOL lit x, y, id dans le vide et
##     prend la CIBLE du joueur (PlayerBuyRequestHandler) ;
##   - 0x79 SellRequest, **12 octets** (FUN_0042b31d) : u32 x, u32 y, u16
##     session, u16 logement d inventaire ;
##   - 0xE0 PlayerAppraiseItemRequest, **12 octets** (FUN_0042b378) : même
##     forme que la vente — le marchand répond par un message de chat
##     (« <nom> offers you … »), pas par un paquet dédié ;
##   - 0xEB ModifyTrade, **28 octets** (FUN_0042a8be pour la mise à jour,
##     FUN_0042a935 pour l acceptation) : u8 réponse (**0 = fermer, 1 =
##     mettre à jour, 2 = accepter**), u8 réparation, u8 combinaison, u8 0,
##     10 u8 logements offerts, u16 0, 5 u16 argent offert (mithril, platine,
##     or, argent, cuivre), u16 0 de bourrage.
##
##   `/sell`, `/repair`, `/salvage`, `/discard` sont des commandes DOL
##   (GameServer/commands/playercommands) : elles partent telles quelles en
##   0xAF, comme P1-110 le fait pour `/quest`.

const OPCODE_MERCHANT_WINDOW := 0x17
const OPCODE_MONEY_UPDATE := 0xFA
const OPCODE_ENCUMBERANCE := 0xBD
const OPCODE_TRADE_WINDOW := 0xEA
const OPCODE_BUY := 0x78
const OPCODE_SELL := 0x79
const OPCODE_APPRAISE := 0xE0
const OPCODE_MODIFY_TRADE := 0xEB

const BUY_PAYLOAD_SIZE := 16
const SELL_PAYLOAD_SIZE := 12
const MODIFY_TRADE_PAYLOAD_SIZE := 28
const TRADE_HEADER_SIZE := 40
const TRADE_SLOT_COUNT := 10
const ITEM_FIXED_SIZE := 24

## eMerchantWindowType (DOL IPacketLib.cs) — seuls 0, 1, 2 et 0x0E concernent
## un marchand de rue ; 3..0x0D sont les menus de logement.
const WINDOW_TYPES := {
	0x00: "copper", 0x01: "bounty_points", 0x02: "barter", 0x0E: "mithril",
	0x03: "housing_deed", 0x04: "housing_outside_menu", 0x05: "housing_npc_hookpoint",
	0x06: "housing_inside_shop", 0x07: "housing_outside_shop", 0x08: "housing_vault_hookpoint",
	0x09: "housing_crafting_hookpoint", 0x0A: "housing_bindstone_hookpoint",
	0x0B: "housing_inside_menu", 0x0C: "housing_ticket", 0x0D: "housing_guild_ticket",
}

## DOL ServerProperties « item_sell_ratio », 50 par défaut : un marchand
## rachète à la moitié du prix (GameMerchant.OnPlayerAppraise).
const ITEM_SELL_RATIO := 50

## Les types d objets dont la valeur1 du 0x17 est une taille de pile et non un
## DPS (PacketLib168.SendMerchantWindow ; eObjectType de DOL).
const OBJECT_TYPE_GENERIC := 0
const OBJECT_TYPE_ARROW := 18
const OBJECT_TYPE_BOLT := 19
const OBJECT_TYPE_THROWN := 21
const OBJECT_TYPE_POISON := 46
const OBJECT_TYPE_GARDEN := 47
const OBJECT_TYPE_SHIELD := 42
const STACKED_OBJECT_TYPES := [OBJECT_TYPE_GENERIC, OBJECT_TYPE_ARROW, OBJECT_TYPE_BOLT, OBJECT_TYPE_POISON]


## ── argent ───────────────────────────────────────────────────────────────
## DOL Money.cs : 100 cuivres = 1 argent, 100 argent = 1 or, 1000 or = 1
## platine, 1000 platine = 1 mithril.
static func split_money(copper: int) -> Dictionary:
	var total := maxi(0, copper)
	return {
		"copper": total % 100,
		"silver": int(total / 100) % 100,
		"gold": int(total / 10000) % 1000,
		"platinum": int(total / 10000000) % 1000,
		"mithril": int(total / 10000000000) % 1000,
		"total_copper": total,
	}


static func compose_money(mithril: int, platinum: int, gold: int, silver: int, copper: int) -> int:
	return ((((mithril * 1000 + platinum) * 1000 + gold) * 100 + silver) * 100) + copper


static func money_text(copper: int) -> String:
	var split := split_money(copper)
	var parts: Array[String] = []
	for pair in [["mithril", "mithril"], ["platinum", "platine"], ["gold", "or"], ["silver", "argent"]]:
		var count := int(split[str(pair[0])])
		if count > 0:
			parts.append("%d %s" % [count, str(pair[1])])
	var tail := int(split["copper"])
	if tail > 0 or parts.is_empty():
		parts.append("%d cuivre" % tail)
	return " ".join(parts)


## ── 0x17 MerchantWindow ──────────────────────────────────────────────────
## 2026-09-29 : deux dispositions coexistent. OpenDAoC (1.124) ecrit la 1.68 ;
## le serveur DOL local ecrit la 1.125 (PacketLib1125.SendMerchantWindow),
## mesuree sur le marchand de test :
##   04 00 00 | 00 0f 1e 22 00 24 01 2800 64000000 4000 11000000 "alloy plate helm" 00
## en-tete de TROIS octets, u16/u32 petit-boutistes, nom PascalStringIntLE
## (u32 LE longueur, zero final compris) et octet 1 = UTILISABLE (inverse de
## la 1.68). La 1.68 est essayee d abord ; la 1.125 prend le relais quand la
## premiere lecture echoue ou laisse des octets.
static func decode_merchant_window(payload: PackedByteArray) -> Dictionary:
	var legacy := _decode_merchant_window_168(payload)
	if bool(legacy.get("ok", false)) and int(legacy.get("trailing_bytes", -1)) == 0:
		return legacy
	var modern := _decode_merchant_window_1125(payload)
	if bool(modern.get("ok", false)) and int(modern.get("trailing_bytes", -1)) == 0:
		return modern
	return legacy


static func _decode_merchant_window_1125(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 3:
		return {"ok": false, "error": "merchant_header_truncated", "size": payload.size()}
	var count := int(payload[0])
	var window_type := int(payload[1])
	var out := {
		"ok": true, "count": count, "window_type": window_type, "layout": "1.125",
		"currency": str(WINDOW_TYPES.get(window_type, "unknown")),
		"page": int(payload[2]), "items": [],
	}
	var offset := 3
	var items: Array = []
	for index in range(count):
		if offset + 21 > payload.size():
			return {"ok": false, "error": "merchant_item_truncated", "item_index": index, "layout": "1.125"}
		var object_type := int(payload[offset + 5]) & 0x3f
		var value1 := int(payload[offset + 2])
		var value2 := int(payload[offset + 7]) | (int(payload[offset + 8]) << 8)
		var name_size := int(payload[offset + 15]) | (int(payload[offset + 16]) << 8) | (int(payload[offset + 17]) << 16) | (int(payload[offset + 18]) << 24)
		if name_size < 0 or offset + 19 + name_size > payload.size():
			return {"ok": false, "error": "merchant_item_name_truncated", "item_index": index, "layout": "1.125"}
		items.append({
			"page_slot": int(payload[offset]),
			"level": int(payload[offset + 1]),
			"value1": value1,
			"value2": value2,
			"pack_size": value1 if object_type in STACKED_OBJECT_TYPES else 1,
			"weight": value2,
			"speed_or_absorb": int(payload[offset + 3]),
			"hand": (int(payload[offset + 4]) >> 6) & 0x03,
			"object_type": object_type,
			"damage_type": (int(payload[offset + 5]) >> 6) & 0x03,
			"unusable": int(payload[offset + 6]) == 0,
			"price": int(payload[offset + 9]) | (int(payload[offset + 10]) << 8) | (int(payload[offset + 11]) << 16) | (int(payload[offset + 12]) << 24),
			"model": int(payload[offset + 13]) | (int(payload[offset + 14]) << 8),
			"name": _text(payload, offset + 19, name_size),
		})
		offset += 19 + name_size
	out["items"] = items
	out["trailing_bytes"] = payload.size() - offset
	return out


static func _decode_merchant_window_168(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "merchant_header_truncated", "size": payload.size()}
	var count := int(payload[0])
	var window_type := int(payload[1])
	var out := {
		"ok": true, "count": count, "window_type": window_type,
		"currency": str(WINDOW_TYPES.get(window_type, "unknown")),
		"page": int(payload[2]), "items": [],
	}
	var offset := 4
	var items: Array = []
	for index in range(count):
		if offset + 16 > payload.size():
			return {"ok": false, "error": "merchant_item_truncated", "item_index": index}
		var object_type := int(payload[offset + 5]) & 0x3f
		var value1 := int(payload[offset + 2])
		var value2 := _u16(payload, offset + 7)
		var name_size := int(payload[offset + 15])
		if offset + 16 + name_size > payload.size():
			return {"ok": false, "error": "merchant_item_name_truncated", "item_index": index}
		items.append({
			"page_slot": int(payload[offset]),
			"level": int(payload[offset + 1]),
			"value1": value1,
			"value2": value2,
			"pack_size": value1 if object_type in STACKED_OBJECT_TYPES else 1,
			"weight": value2,
			"speed_or_absorb": int(payload[offset + 3]),
			"hand": (int(payload[offset + 4]) >> 6) & 0x03,
			"object_type": object_type,
			"damage_type": (int(payload[offset + 5]) >> 6) & 0x03,
			"unusable": int(payload[offset + 6]) != 0,
			"price": (int(payload[offset + 9]) << 24) | (int(payload[offset + 10]) << 16) | (int(payload[offset + 11]) << 8) | int(payload[offset + 12]),
			"model": (int(payload[offset + 13]) << 8) | int(payload[offset + 14]),
			"name": _text(payload, offset + 16, name_size),
		})
		offset += 16 + name_size
	out["items"] = items
	out["trailing_bytes"] = payload.size() - offset
	return out


## ── 0xFA MoneyUpdate ─────────────────────────────────────────────────────
static func decode_money(payload: PackedByteArray) -> Dictionary:
	# 1 + 1 + 2 + 2 + 2 = HUIT octets, pas dix.
	if payload.size() < 8:
		return {"ok": false, "error": "money_truncated", "size": payload.size()}
	var copper := int(payload[0])
	var silver := int(payload[1])
	var gold := _u16(payload, 2)
	var mithril := _u16(payload, 4)
	var platinum := _u16(payload, 6)
	var total := compose_money(mithril, platinum, gold, silver, copper)
	return {"ok": true, "copper": copper, "silver": silver, "gold": gold, "mithril": mithril,
		"platinum": platinum, "total_copper": total, "text": money_text(total)}


## ── 0xBD Encumberance ────────────────────────────────────────────────────
static func decode_encumberance(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "encumberance_truncated", "size": payload.size()}
	var maximum := _u16(payload, 0)
	var current := _u16(payload, 2)
	return {"ok": true, "maximum": maximum, "current": current, "overencumbered": current > maximum,
		"percent": int(round(float(current) * 100.0 / float(maxi(1, maximum))))}


## ── 0xEA TradeWindow ─────────────────────────────────────────────────────
static func decode_trade_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < TRADE_HEADER_SIZE:
		return {"ok": false, "error": "trade_header_truncated", "size": payload.size()}
	if _all_zero(payload, 0, payload.size()):
		# SendCloseTradeWindow : 40 octets nuls et rien d autre.
		return {"ok": true, "closed": true, "my_slots": [], "partner_items": [], "caption": "",
			"my_money": 0, "partner_money": 0, "repairing": false, "combine": false, "partner_item_count": 0}
	var my_slots: Array = []
	for i in range(TRADE_SLOT_COUNT):
		var slot := int(payload[i])
		if slot > 0:
			my_slots.append(slot)
	var my_money := compose_money(_u16(payload, 12), _u16(payload, 14), _u16(payload, 16), _u16(payload, 18), _u16(payload, 20))
	var partner_money := compose_money(_u16(payload, 24), _u16(payload, 26), _u16(payload, 28), _u16(payload, 30), _u16(payload, 32))
	var partner_count := int(payload[36])
	var out := {
		"ok": true, "closed": false, "my_slots": my_slots, "my_money": my_money, "my_money_text": money_text(my_money),
		"partner_money": partner_money, "partner_money_text": money_text(partner_money),
		"partner_item_count": partner_count, "repairing": int(payload[38]) != 0, "combine": int(payload[39]) != 0,
		"partner_items": [], "caption": "", "partner_name": "",
	}
	var offset := TRADE_HEADER_SIZE
	var items: Array = []
	for index in range(partner_count):
		if offset >= payload.size():
			return {"ok": false, "error": "trade_item_slot_missing", "item_index": index}
		var slot := int(payload[offset])
		offset += 1
		var item := decode_item_block(payload, offset)
		if not bool(item.get("ok", false)):
			return {"ok": false, "error": "trade_item_truncated", "item_index": index}
		var entry: Dictionary = item["item"]
		entry["slot"] = slot
		items.append(entry)
		offset = int(item["next"])
	out["partner_items"] = items
	var caption := _pascal(payload, offset)
	if bool(caption.get("ok", false)):
		out["caption"] = str(caption["text"])
		var text := str(caption["text"])
		if text.begins_with("Trading with "):
			out["partner_name"] = text.substr(13)
		out["trailing_bytes"] = payload.size() - int(caption["next"])
	return out


## Le bloc d objet de 24 octets + nom, identique à celui de l inventaire 0x02
## en 1.124 (P1-95, `DaocOpenDaocInventoryCodec`) : la 1.109 a fait passer la
## fenêtre d échange par le même `WriteItemData`.
static func decode_item_block(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset + ITEM_FIXED_SIZE > payload.size():
		return {"ok": false}
	if _all_zero(payload, offset, ITEM_FIXED_SIZE):
		return {"ok": true, "item": {"empty": true}, "next": offset + ITEM_FIXED_SIZE}
	var name_size := int(payload[offset + 23])
	var next_offset := offset + ITEM_FIXED_SIZE + name_size
	if next_offset > payload.size():
		return {"ok": false}
	var type_byte := int(payload[offset + 6])
	return {"ok": true, "next": next_offset, "item": {
		"empty": false,
		"level": int(payload[offset + 2]),
		"value1": int(payload[offset + 3]),
		"value2": int(payload[offset + 4]),
		"hand": (int(payload[offset + 5]) >> 6) & 0x03,
		"object_type": type_byte & 0x3f,
		"damage_type": (type_byte >> 6) & 0x03,
		"weight": _u16(payload, offset + 8),
		"condition": int(payload[offset + 10]),
		"durability": int(payload[offset + 11]),
		"quality": int(payload[offset + 12]),
		"bonus": int(payload[offset + 13]),
		"model": _u16(payload, offset + 15),
		"color_or_emblem": _u16(payload, offset + 18),
		"effect": _u16(payload, offset + 21),
		"name": _text(payload, offset + ITEM_FIXED_SIZE, name_size),
	}}


## ── ce que le client envoie ──────────────────────────────────────────────
## 0x78 : `page_slot` est l index DANS LA PAGE reçue, `window_type` celui du
## 0x17 en cours (game.dll relit DAT_009ab4e0, le type de la fenêtre ouverte).
static func build_buy_payload(x: int, y: int, session_id: int, page_slot: int, count: int, window_type: int) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(BUY_PAYLOAD_SIZE)
	_w32(payload, 0, x)
	_w32(payload, 4, y)
	_w16(payload, 8, session_id)
	_w16(payload, 10, page_slot)
	payload[12] = maxi(1, count) & 0xff
	payload[13] = window_type & 0xff
	return payload


static func build_sell_payload(x: int, y: int, session_id: int, inventory_slot: int) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(SELL_PAYLOAD_SIZE)
	_w32(payload, 0, x)
	_w32(payload, 4, y)
	_w16(payload, 8, session_id)
	_w16(payload, 10, inventory_slot)
	return payload


## Même forme que la vente : DOL les lit avec le même code.
static func build_appraise_payload(x: int, y: int, session_id: int, inventory_slot: int) -> PackedByteArray:
	return build_sell_payload(x, y, session_id, inventory_slot)


## `response` : 0 fermer, 1 mettre à jour, 2 accepter (DOL
## PlayerModifyTradeHandler). `slots` : jusqu à dix logements d inventaire.
static func build_modify_trade_payload(response: int, slots: Array = [], copper: int = 0, repairing: bool = false, combine: bool = false) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(MODIFY_TRADE_PAYLOAD_SIZE)
	payload[0] = response & 0xff
	payload[1] = 1 if repairing else 0
	payload[2] = 1 if combine else 0
	for i in range(mini(TRADE_SLOT_COUNT, slots.size())):
		payload[4 + i] = int(slots[i]) & 0xff
	var money := split_money(copper)
	_w16(payload, 16, int(money["mithril"]))
	_w16(payload, 18, int(money["platinum"]))
	_w16(payload, 20, int(money["gold"]))
	_w16(payload, 22, int(money["silver"]))
	_w16(payload, 24, int(money["copper"]))
	return payload


## ── ce qu un marchand donnerait hors ligne ───────────────────────────────
## GameMerchant.OnPlayerAppraise : prix × nombre / taille de pile × ratio /
## 100, et zéro pour un objet qui ne se jette pas.
static func sell_value(price: int, count: int = 1, pack_size: int = 1, dropable: bool = true) -> int:
	if not dropable:
		return 0
	return int(int(price * maxi(1, count) / maxi(1, pack_size)) * ITEM_SELL_RATIO / 100)


## DOL GameLivingInventory.InventoryWeight / GamePlayerInventory : le poids des
## objets est en DIXIÈMES de livre, et l équipement et le sac sont divisés
## SÉPARÉMENT (deux divisions entières, pas une somme divisée une fois).
## L argent ne pèse rien dans cette version.
static func inventory_weight(equipped_weights: Array, backpack_weights: Array) -> int:
	var equipped := 0
	for value in equipped_weights:
		equipped += int(value)
	var backpack := 0
	for value in backpack_weights:
		backpack += int(value)
	return int(backpack / 10) + int(equipped / 10)


## DOL GamePlayer.MaxEncumberance : la FORCE modifiée (les capacités Lifter,
## Sojourner, Oppression et le bonus mythique la modulent ; hors ligne le
## client n en a aucune).
static func max_encumberance(strength: int) -> int:
	return maxi(0, strength)


## ── encodeurs pour les suites à faux pair ────────────────────────────────
static func encode_merchant_window(window_type: int, page: int, items: Array) -> PackedByteArray:
	var out := PackedByteArray([items.size() & 0xff, window_type & 0xff, page & 0xff, 0])
	for value in items:
		var item := value as Dictionary
		var price := int(item.get("price", 0))
		var model := int(item.get("model", 0))
		var value2 := int(item.get("value2", item.get("weight", 0)))
		out.append_array(PackedByteArray([
			int(item.get("page_slot", 0)) & 0xff, int(item.get("level", 1)) & 0xff, int(item.get("value1", 0)) & 0xff,
			int(item.get("speed_or_absorb", 0)) & 0xff, (int(item.get("hand", 0)) << 6) & 0xff,
			((int(item.get("damage_type", 0)) & 3) << 6) | (int(item.get("object_type", 0)) & 0x3f),
			1 if bool(item.get("unusable", false)) else 0,
			(value2 >> 8) & 0xff, value2 & 0xff,
			(price >> 24) & 0xff, (price >> 16) & 0xff, (price >> 8) & 0xff, price & 0xff,
			(model >> 8) & 0xff, model & 0xff,
		]))
		_write_pascal(out, str(item.get("name", "")))
	return out


static func encode_money(copper: int) -> PackedByteArray:
	var money := split_money(copper)
	var out := PackedByteArray([int(money["copper"]) & 0xff, int(money["silver"]) & 0xff])
	for key in ["gold", "mithril", "platinum"]:
		out.append((int(money[key]) >> 8) & 0xff)
		out.append(int(money[key]) & 0xff)
	return out


static func encode_encumberance(maximum: int, current: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	_w16(out, 0, maximum)
	_w16(out, 2, current)
	return out


static func encode_item_block(item: Dictionary) -> PackedByteArray:
	if item.is_empty() or bool(item.get("empty", false)):
		var zeros := PackedByteArray()
		zeros.resize(ITEM_FIXED_SIZE)
		return zeros
	var name := str(item.get("name", "")).to_ascii_buffer()
	var model := int(item.get("model", 0))
	var out := PackedByteArray([0, 0, int(item.get("level", 1)), int(item.get("value1", 0)), int(item.get("value2", 0)),
		(int(item.get("hand", 0)) << 6) & 0xff,
		(int(item.get("object_type", 0)) & 0x3f) | ((int(item.get("damage_type", 0)) & 3) << 6), 0,
		(int(item.get("weight", 0)) >> 8) & 0xff, int(item.get("weight", 0)) & 0xff,
		int(item.get("condition", 100)), int(item.get("durability", 100)), int(item.get("quality", 100)), int(item.get("bonus", 0)), 0,
		(model >> 8) & 0xff, model & 0xff, 0, 0, 0, 0, 0, 0, name.size() & 0xff])
	out.append_array(name)
	return out


static func encode_trade_window(my_slots: Array, my_copper: int, partner_copper: int, partner_items: Array, caption: String, repairing: bool = false, combine: bool = false) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TRADE_HEADER_SIZE)
	for i in range(mini(TRADE_SLOT_COUNT, my_slots.size())):
		out[i] = int(my_slots[i]) & 0xff
	var mine := split_money(my_copper)
	var theirs := split_money(partner_copper)
	var keys := ["mithril", "platinum", "gold", "silver", "copper"]
	for i in keys.size():
		_w16(out, 12 + i * 2, int(mine[keys[i]]))
		_w16(out, 24 + i * 2, int(theirs[keys[i]]))
	out[36] = partner_items.size() & 0xff
	out[37] = 1
	out[38] = 1 if repairing else 0
	out[39] = 1 if combine else 0
	for value in partner_items:
		var item := value as Dictionary
		out.append(int(item.get("slot", 0)) & 0xff)
		out.append_array(encode_item_block(item))
	_write_pascal(out, caption)
	return out


static func encode_close_trade_window() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TRADE_HEADER_SIZE)
	return out


## ── petits outils ────────────────────────────────────────────────────────
static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": _text(payload, offset + 1, size), "next": offset + 1 + size}


static func _text(payload: PackedByteArray, start: int, length: int) -> String:
	var bytes := payload.slice(start, start + length)
	var text := bytes.get_string_from_utf8()
	if text == "" and length > 0:
		text = bytes.get_string_from_ascii()
	return text


static func _write_pascal(out: PackedByteArray, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	out.append(bytes.size() & 0xff)
	out.append_array(bytes)


static func _all_zero(payload: PackedByteArray, start: int, length: int) -> bool:
	for i in range(start, mini(start + length, payload.size())):
		if int(payload[i]) != 0:
			return false
	return true


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func _w16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


static func _w32(data: PackedByteArray, offset: int, value: int) -> void:
	for i in range(4):
		data[offset + i] = (value >> (8 * (3 - i))) & 0xff
