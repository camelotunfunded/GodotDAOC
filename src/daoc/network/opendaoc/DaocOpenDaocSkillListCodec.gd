extends RefCounted
class_name DaocOpenDaocSkillListCodec

## Le LIVRE DE SORTS que le serveur envoie, et les intentions de combat.
##
## 0x16 VariousUpdate, sous-code 0x02 / sous-type 0x02 (PacketLib1112.cs:213
## SendNonHybridSpellLines) : une LIGNE par paquet —
##   u8 0x02, u8 nombre d'entrees (+1), u8 0x02, u8 index de ligne,
##   u16 LE 0, u16 BE InternalID de la ligne, u16 BE 0, pascal nom de ligne,
##   puis par sort : u16 LE niveau (+256 capacite, +512 style), u16 BE InternalID,
##   u16 BE icone, pascal nom.
## Sous-type 99 = fin de liste. C'est CETTE liste que UseSpell (0x7D) adresse
## par (niveau, index de ligne) — UseSpellHandler.cs:150 — et c'est elle qui
## porte l'identifiant d'icone reel du serveur (Eden).
##
## 0x7D UseSpell 1.124+ (sonde P1-20D, live) : 3 floats LE position, float
## vitesse, u16 cap, u16 drapeaux (0xA000 = cible visible), u8 niveau, u8 ligne.
## 0x74 AttackMode : u8 1/0. 0xB0 PlayerTarget : u16 id, u16 0xFFFE (0xFFFF en
## mode attaque).

const OPCODE_VARIOUS_UPDATE := 0x16
const SUBCODE_SPELL_LINES := 0x02
const SUBTYPE_LINE := 0x02
const SUBTYPE_END := 99
## P1-79 — sous-code 0x01 : la LISTE DES COMPETENCES (PacketLib1112
## SendUpdatePlayerSkills) : specialisations, capacites, styles, sorts hybrides.
## u8 0x01, u8 nombre d'entrees, u8 sous-type (0x03 = derniere page, 99 = une
## page SUIT), u8 index de la premiere entree ; par entree : u8 niveau, u16 BE
## InternalID, u8 type (eSkillPage : 0 spe, 1 capacite, 2 style, 3 sort, 4
## chant, 5 capacite-sort, 6 capacite de royaume), u16 BE ouverture / index de
## ligne, u8 bonus / index de spe, u16 BE icone, pascal nom. UseSkill (0xBB)
## adresse cette liste : type > 0 -> index compte a partir de la premiere entree
## qui n'est PAS une specialisation (UseSkillHandler.cs).
const SUBCODE_SKILLS := 0x01
const SKILL_PAGE_LAST := 0x03
const SKILL_PAGE_MORE := 99
const SKILL_TYPES := {0: "specialization", 1: "ability", 2: "style", 3: "spell", 4: "song", 5: "ability_spell", 6: "realm_ability"}
## P1-83 — sous-code 0x08 : les METIERS (PacketLib168 SendUpdateCraftingSkills) :
## u8 0x08, u8 nombre, u8 0x03, u8 0 ; par metier : u16 BE points, u8 icone,
## u32 1, pascal nom. La capture locale du 02/09 n'en montre que l'en-tete vide
## (`08 00 03 00`) : la queue par entree vient du code source, pas d'une capture.
const SUBCODE_CRAFTING := 0x08

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")


static func decode_various_update(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "various_update_too_short"}
	var subcode := int(payload[0])
	var count := int(payload[1])
	var subtype := int(payload[2])
	var index := int(payload[3])
	if subcode == SUBCODE_SKILLS:
		return decode_skills_page(payload)
	if subcode == SUBCODE_CRAFTING:
		return decode_crafting_skills(payload)
	if subcode != SUBCODE_SPELL_LINES:
		return {"ok": true, "subcode": subcode, "kind": "other"}
	if subtype == SUBTYPE_END:
		return {"ok": true, "subcode": subcode, "kind": "spell_lines_end"}
	if subtype != SUBTYPE_LINE:
		return {"ok": true, "subcode": subcode, "kind": "other", "subtype": subtype}
	var offset := 4
	if payload.size() < offset + 6:
		return {"ok": false, "error": "spell_line_header_too_short"}
	offset += 2  # niveau, inutilise pour une ligne
	var line_internal_id := _u16(payload, offset); offset += 2
	offset += 2  # icone, inutilisee pour une ligne
	var line_name := _pascal(payload, offset)
	offset += 1 + line_name.length()
	var entries: Array = []
	while offset + 6 < payload.size() and entries.size() < count:
		var raw_level := int(payload[offset]) | (int(payload[offset + 1]) << 8)
		var internal_id := _u16(payload, offset + 2)
		var icon := _u16(payload, offset + 4)
		var name := _pascal(payload, offset + 6)
		offset += 7 + name.length()
		var kind := "spell"
		var level := raw_level
		if raw_level >= 512:
			kind = "style"; level = raw_level - 512
		elif raw_level >= 256:
			kind = "ability"; level = raw_level - 256
		entries.append({"kind": kind, "level": level, "internal_id": internal_id, "icon": icon, "name": name})
	return {"ok": true, "subcode": subcode, "kind": "spell_line", "line_index": index,
		"line_name": line_name, "line_internal_id": line_internal_id, "entries": entries}


static func build_use_spell_payload(position: Dictionary, level: int, line_index: int, target_visible: bool = true) -> PackedByteArray:
	var payload := PackedByteArray(); payload.resize(24)
	payload.encode_float(0, float(position.get("x", 0.0)))
	payload.encode_float(4, float(position.get("y", 0.0)))
	payload.encode_float(8, float(position.get("z", 0.0)))
	payload.encode_float(12, float(position.get("speed", 0.0)))
	_w16(payload, 16, int(position.get("heading", 0)) & 0x0fff)
	_w16(payload, 18, 0xA000 if target_visible else 0x0000)
	payload[20] = level & 0xff
	payload[21] = line_index & 0xff
	return payload


static func build_target_payload(object_id: int, attack_mode: bool = false) -> PackedByteArray:
	var payload := PackedByteArray([0, 0, 0xFF, 0xFF if attack_mode else 0xFE])
	_w16(payload, 0, object_id)
	return payload


static func build_attack_mode_payload(on: bool) -> PackedByteArray:
	return PackedByteArray([1 if on else 0, 0])


static func _pascal(data: PackedByteArray, offset: int) -> String:
	if offset >= data.size():
		return ""
	var length := int(data[offset])
	if offset + 1 + length > data.size():
		length = data.size() - offset - 1
	var bytes := data.slice(offset + 1, offset + 1 + length)
	var text := bytes.get_string_from_utf8()
	return text if text != "" else bytes.get_string_from_ascii()


static func _u16(data: PackedByteArray, offset: int) -> int:
	return ((int(data[offset]) & 0xff) << 8) | (int(data[offset + 1]) & 0xff)


static func _w16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


static func decode_skills_page(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "skills_page_too_short"}
	var count := int(payload[1])
	var subtype := int(payload[2])
	var first_index := int(payload[3])
	var entries: Array = []
	var offset := 4
	while offset + 9 <= payload.size() and entries.size() < count:
		var name := _pascal(payload, offset + 9)
		entries.append({
			"index": first_index + entries.size(),
			"level": int(payload[offset]),
			"internal_id": _u16(payload, offset + 1),
			"skill_type": int(payload[offset + 3]),
			"kind": str(SKILL_TYPES.get(int(payload[offset + 3]), "type_%d" % int(payload[offset + 3]))),
			"opening": _u16(payload, offset + 4),
			"bonus": int(payload[offset + 6]),
			"icon": _u16(payload, offset + 7),
			"name": name,
		})
		offset += 10 + name.length()
	return {"ok": true, "subcode": SUBCODE_SKILLS, "kind": "skills_page", "first_index": first_index,
		"more": subtype == SKILL_PAGE_MORE, "entries": entries}


## 0xBB UseSkill 1.124+ : meme prefixe de position que UseSpell, puis u16
## drapeaux (0xA000 cible visible), u8 index, u8 type.
static func build_use_skill_payload(position: Dictionary, index: int, type: int, target_visible: bool = true) -> PackedByteArray:
	var payload := build_use_spell_payload(position, 0, 0, target_visible)
	payload[20] = index & 0xff
	payload[21] = type & 0xff
	return payload


static func decode_crafting_skills(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "crafting_too_short"}
	var count := int(payload[1])
	var entries: Array = []
	var offset := 4
	while offset + 8 <= payload.size() and entries.size() < count:
		var name := _pascal(payload, offset + 7)
		entries.append({"points": _u16(payload, offset), "icon": int(payload[offset + 2]), "name": name})
		offset += 8 + name.length()
	return {"ok": true, "subcode": SUBCODE_CRAFTING, "kind": "crafting_skills", "entries": entries}


## Affichage uniquement : les index reseau et la cle de quickbar restent intacts.
## PacketLib1112.SendUpdatePlayerSkills : sorts -> opening = index de spe ;
## styles -> bonus = GetSpecToInternalIndex, PAS l'InternalID de la spe.
const STYLE_SPECIALIZATIONS := {
	0x01: "Slash",
	0x02: "Thrust",
	0x08: "Parry",
	0x0E: "Sword",
	0x10: "Hammer",
	0x11: "Axe",
	0x12: "Left Axe",
	0x13: "Stealth",
	0x1A: "Spear",
	0x1D: "Mending",
	0x1E: "Augmentation",
	0x21: "Crush",
	0x22: "Pacification",
	0x26: "Darkness",
	0x27: "Suppression",
	0x2A: "Runecarving",
	0x2B: "Shields",
	0x2E: "Flexible",
	0x2F: "Staff",
	0x30: "Summoning",
	0x32: "Stormcalling",
	0x3E: "Beastcraft",
	0x40: "Polearms",
	0x41: "Two Handed",
	0x42: "Fire Magic",
	0x43: "Wind Magic",
	0x44: "Cold Magic",
	0x45: "Earth Magic",
	0x46: "Light",
	0x47: "Matter Magic",
	0x48: "Body Magic",
	0x49: "Spirit Magic",
	0x4A: "Mind Magic",
	0x4B: "Void",
	0x4C: "Mana",
	0x4D: "Dual Wield",
	0x4E: "CompositeBow",
	0x52: "Battlesongs",
	0x53: "Enhancement",
	0x54: "Enchantments",
	0x58: "Rejuvenation",
	0x59: "Smite",
	0x5A: "Longbow",
	0x5B: "Crossbow",
	0x61: "Chants",
	0x62: "Instruments",
	0x65: "Blades",
	0x66: "Blunt",
	0x67: "Piercing",
	0x68: "Large Weapons",
	0x69: "Mentalism",
	0x6A: "Regrowth",
	0x6B: "Nurture",
	0x6C: "Nature",
	0x6D: "Music",
	0x6E: "Celtic Dual",
	0x70: "Celtic Spear",
	0x71: "RecurveBow",
	0x72: "Valor",
	0x74: "Pathfinding",
	0x75: "Envenom",
	0x76: "Critical Strike",
	0x78: "Deathsight",
	0x79: "Painworking",
	0x7A: "Death Servant",
	0x7B: "Soulrending",
	0x7C: "HandToHand",
	0x7D: "Scythe",
	0x7F: "Arboreal Path",
	0x81: "Creeping Path",
	0x82: "Verdant Path",
	0x85: "OdinsWill",
	0x86: "SpectralForce",
	0x87: "PhantasmalWail",
	0x88: "EtherealShriek",
	0x89: "ShadowMastery",
	0x8A: "VampiiricEmbrace",
	0x8B: "Dementia",
	0x8C: "Witchcraft",
	0x8D: "Cursing",
	0x8E: "Hexing",
	0x93: "Fist Wraps",
	0x94: "Mauler Staff",
	0x95: "SpectralGuard",
}
const CATEGORY_LABELS := {
	"ability": "Capacites", "realm_ability": "Capacites de royaume",
	"ability_spell": "Capacites magiques", "song": "Chants",
	"spell": "Sorts", "style": "Styles de combat",
}

static func display_group(skill: Dictionary, skills: Array) -> String:
	var kind := str(skill.get("kind", ""))
	if kind == "spell" or kind == "song":
		var index := int(skill.get("opening", 0xFE))
		if index < 0xFE:
			for value in skills:
				var spec := value as Dictionary
				if str(spec.get("kind", "")) == "specialization" and int(spec.get("index", -1)) == index:
					return str(spec.get("name", CATEGORY_LABELS.get(kind, "Sorts")))
		return "Chants" if index == 0xFF or kind == "song" else "Sorts sans specialisation"
	if kind == "style":
		return str(STYLE_SPECIALIZATIONS.get(int(skill.get("bonus", -1)), "Styles de combat"))
	return str(CATEGORY_LABELS.get(kind, "Capacites"))
