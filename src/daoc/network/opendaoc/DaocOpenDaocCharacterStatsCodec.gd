extends RefCounted
class_name DaocOpenDaocCharacterStatsCodec

## P1-106 — les caracteristiques du personnage telles que DOL les envoie
## (PacketLib175.SendCharStatsUpdate / SendCharResistsUpdate, heritees par
## 1.125 ; PacketLib168.SendUpdateWeaponAndArmorStats).
##
##   0xFB StatsUpdate, 78 octets, DEUX variantes que l octet 72 distingue :
##     caracteristiques (octet 72 = 0x00) : 8 x u16 base (FOR DEX CON VIV INT
##     PIE EMP CHA), u16 0, 8 x u16 buffs (signe : sorts et debuffs SEULS, base
##     et objets retires), u16 0, 8 x u16 bonus d objets, u16 0, 8 x u8 plafond
##     d objets (niveau x 1,5 + bonus de plafond, borne a niveau x 1,5 + niveau/2
##     + 1), u8 0, 8 x u8 bonus de capacites de royaume, u8 0, u8 0x00,
##     u8 constitution perdue a la mort, u16 vie maximale, u16 0 ;
##     resistances (octet 72 = 0xFF) : 9 x u16 raciales (CONT TRANCH PERF CHAL
##     FROID MAT CORPS ESPRIT ENERG), 9 x u16 buffs, 9 x u16 objets, 9 x u8
##     plafond, 9 x u8 capacites, 0xFF, 0, u16 0, u16 0.
##   VALEUR AFFICHEE = base + buffs + min(objets, plafond) + capacites (+ bonus
##   de classe x3 FOR/DEX/CON, x2 VIV si l octet 72 n est ni 0 ni 0xFF).
##   COULEUR, lue dans game.dll (FUN_0041a60e) : ROUGE si les BUFFS sont
##   negatifs ou, pour la constitution, si de la con a ete perdue a la mort ;
##   VERT si les buffs sont positifs ; BLANC sinon. Les objets et les capacites
##   de royaume ne colorent PAS - seuls les sorts le font.
##
##   0x16 sous-code 0x05 (SendUpdateWeaponAndArmorStats) : u8 5, u8 6, u8 0,
##     u8 0, puis six paires (u8 valeur, chaine Pascal « ») : degats d arme
##     entier et centiemes, competence d arme octet haut et bas, facteur
##     d armure effectif octet haut et bas.

const OPCODE_STATS_UPDATE := 0xFB
const SUBCODE_WEAPON_ARMOR := 0x05
const STAT_NAMES := ["strength", "dexterity", "constitution", "quickness", "intelligence", "piety", "empathy", "charisma"]
const RESIST_NAMES := ["crush", "slash", "thrust", "heat", "cold", "matter", "body", "spirit", "energy"]
const PACKET_SIZE := 78
const VARIANT_OFFSET := 72


static func decode_stats_update(payload: PackedByteArray) -> Dictionary:
	if payload.size() < PACKET_SIZE:
		return {"ok": false, "error": "stats_update_too_short", "size": payload.size()}
	var variant := int(payload[VARIANT_OFFSET])
	if variant == 0xFF:
		return _decode_table(payload, RESIST_NAMES, "resists", 9)
	if variant == 0x00:
		var out := _decode_table(payload, STAT_NAMES, "stats", 8)
		out["constitution_lost_at_death"] = int(payload[73])
		out["max_health"] = _u16(payload, 74)
		return out
	return {"ok": false, "error": "stats_update_unknown_variant", "variant": variant}


static func _colour_for(buff: int, con_penalty: bool) -> String:
	if buff < 0 or con_penalty:
		return "red"
	return "green" if buff > 0 else "white"


static func _decode_table(payload: PackedByteArray, names: Array, kind: String, count: int) -> Dictionary:
	var con_lost := int(payload[73]) if kind == "stats" else 0
	# Les caracteristiques ont un u16/u8 de bourrage apres chaque table, les
	# resistances non : 8 x 2 + 2 = 18 = 9 x 2, 8 + 1 = 9. Les tables tombent
	# donc aux memes offsets dans les deux variantes.
	var entries: Dictionary = {}
	for i in range(count):
		var base := _s16(payload, i * 2)
		var buff := _s16(payload, 18 + i * 2)
		var item := _s16(payload, 36 + i * 2)
		var cap := int(payload[54 + i])
		var ability := int(payload[63 + i])
		var item_effective := mini(item, cap) if item > 0 else item
		var bonus := buff + item_effective + ability
		entries[str(names[i])] = {"base": base, "buff": buff, "item": item, "item_cap": cap, "ability": ability,
			"item_effective": item_effective, "bonus": bonus, "total": base + bonus,
			"colour": _colour_for(buff, str(names[i]) == "constitution" and con_lost > 0)}
	return {"ok": true, "kind": kind, "entries": entries}


static func decode_weapon_armor(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4 or int(payload[0]) != SUBCODE_WEAPON_ARMOR:
		return {"ok": false, "error": "not_weapon_armor"}
	var values: Array = []
	var offset := 4
	while values.size() < 6 and offset < payload.size():
		values.append(int(payload[offset]))
		offset += 1
		if offset >= payload.size():
			break
		offset += 1 + int(payload[offset])
	if values.size() < 6:
		return {"ok": false, "error": "weapon_armor_truncated", "values": values}
	return {"ok": true, "weapon_damage": float(values[0]) + float(values[1]) / 100.0,
		"weapon_skill": (int(values[2]) << 8) | int(values[3]), "armor_factor": (int(values[4]) << 8) | int(values[5])}


## Encodeurs pour les suites a faux pair : `entries` = nom -> {base, buff, item, cap, ability}.
static func encode_stats(entries: Dictionary, max_health: int, con_lost: int = 0) -> PackedByteArray:
	return _encode_table(entries, STAT_NAMES, 0x00, max_health, con_lost)


static func encode_resists(entries: Dictionary) -> PackedByteArray:
	return _encode_table(entries, RESIST_NAMES, 0xFF, 0, 0)


static func _encode_table(entries: Dictionary, names: Array, variant: int, max_health: int, con_lost: int) -> PackedByteArray:
	var out := PackedByteArray()
	var pad16 := names.size() == 8
	for field in ["base", "buff", "item"]:
		for name in names:
			_w16(out, int((entries.get(name, {}) as Dictionary).get(field, 0)))
		if pad16:
			_w16(out, 0)
	for field in ["cap", "ability"]:
		for name in names:
			out.append(int((entries.get(name, {}) as Dictionary).get(field, 0)) & 0xff)
		if pad16:
			out.append(0)
	out.append(variant)
	out.append(con_lost & 0xff)
	_w16(out, max_health)
	_w16(out, 0)
	return out


static func encode_weapon_armor(weapon_damage: float, weapon_skill: int, armor_factor: int) -> PackedByteArray:
	var wd := int(round(weapon_damage * 100.0))
	var out := PackedByteArray([SUBCODE_WEAPON_ARMOR, 6, 0, 0])
	for v in [wd / 100, wd % 100, (weapon_skill >> 8) & 0xff, weapon_skill & 0xff, (armor_factor >> 8) & 0xff, armor_factor & 0xff]:
		out.append(int(v) & 0xff)
		out.append(1)
		out.append(0x20)
	return out


static func _u16(p: PackedByteArray, o: int) -> int:
	return ((int(p[o]) & 0xff) << 8) | (int(p[o + 1]) & 0xff)


static func _s16(p: PackedByteArray, o: int) -> int:
	var v := _u16(p, o)
	return v - 0x10000 if v >= 0x8000 else v


static func _w16(out: PackedByteArray, v: int) -> void:
	out.append((v >> 8) & 0xff)
	out.append(v & 0xff)
