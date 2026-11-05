extends RefCounted
class_name DaocCharacterCreationRules

## 2026-09-30 — ce que la fenêtre de création simplifiée a le droit de proposer,
## et le paquet 0xFF qui en sort. Rien n'est écrit de mémoire :
## - races par royaume et modèles : DOL `GlobalConstants.eLivingModel`
##   (GlobalConstants.cs:1043-1085) — BritonFemale = 35, AvalonianFemale = 65…
##   Les Minotaures n'existent qu'en mâle (1395 / 1407 / 1419) ;
## - classes permises par race : `eligible_races` de la table P1-23
##   (`CharacterClassDB.cs`), d'où les noms Korazh / Deifrang / Graoch ;
## - statistiques de départ : `DaocDolFormulas.RACE_STARTING_STATS`
##   (`STARTING_STATS_DICT`) ;
## - coût des points et octet race/sexe : `DaocOpenDaocCharacterCreateCodec`,
##   prouvé en live par P1-20 (bit 7 = femme, race sur les 5 bits bas).
## L'apparence (visage, cheveux…) reste neutre : CustomMode 0, ignorée par DOL.

const ClassTableScript = preload("res://src/daoc/gameplay/items/DaocDolClassTable.gd")
const FormulasScript = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")
const CreateCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterCreateCodec.gd")

const STATS := ["STR", "CON", "DEX", "QUI", "INT", "PIE", "EMP", "CHR"]
const STAT_FIELDS := {"STR": "strength", "CON": "constitution", "DEX": "dexterity", "QUI": "quickness",
	"INT": "intelligence", "PIE": "piety", "EMP": "empathy", "CHR": "charisma"}
const STAT_LABELS := {"STR": "Force", "CON": "Constitution", "DEX": "Dextérité", "QUI": "Vivacité",
	"INT": "Intelligence", "PIE": "Piété", "EMP": "Empathie", "CHR": "Charisme"}
const MAX_POINTS := 30

## Clé = nom de race de la table des classes. `stats` = nom dans STARTING_STATS_DICT.
const RACES := {
	1: [
		{"key": "Briton", "label": "Briton", "id": 1, "stats": "Briton", "male": 32, "female": 35},
		{"key": "Avalonian", "label": "Avalonian", "id": 2, "stats": "Avalonian", "male": 61, "female": 65},
		{"key": "Highlander", "label": "Highlander", "id": 3, "stats": "Highlander", "male": 39, "female": 43},
		{"key": "Saracen", "label": "Saracen", "id": 4, "stats": "Saracen", "male": 48, "female": 52},
		{"key": "Inconnu", "label": "Inconnu", "id": 13, "stats": "Inconnu", "male": 716, "female": 724},
		{"key": "HalfOgre", "label": "Half Ogre", "id": 16, "stats": "HalfOgre", "male": 1008, "female": 1020},
		{"key": "Korazh", "label": "Korazh (Minotaure)", "id": 19, "stats": "AlbionMinotaur", "male": 1395, "female": 0},
	],
	2: [
		{"key": "Norseman", "label": "Norseman", "id": 5, "stats": "Norseman", "male": 503, "female": 507},
		{"key": "Troll", "label": "Troll", "id": 6, "stats": "Troll", "male": 137, "female": 145},
		{"key": "Dwarf", "label": "Dwarf", "id": 7, "stats": "Dwarf", "male": 185, "female": 193},
		{"key": "Kobold", "label": "Kobold", "id": 8, "stats": "Kobold", "male": 169, "female": 177},
		{"key": "Valkyn", "label": "Valkyn", "id": 14, "stats": "Valkyn", "male": 773, "female": 781},
		{"key": "Frostalf", "label": "Frostalf", "id": 17, "stats": "Frostalf", "male": 1051, "female": 1063},
		{"key": "Deifrang", "label": "Deifrang (Minotaure)", "id": 20, "stats": "MidgardMinotaur", "male": 1407, "female": 0},
	],
	3: [
		{"key": "Celt", "label": "Celt", "id": 9, "stats": "Celt", "male": 302, "female": 310},
		{"key": "Firbolg", "label": "Firbolg", "id": 10, "stats": "Firbolg", "male": 286, "female": 294},
		{"key": "Elf", "label": "Elf", "id": 11, "stats": "Elf", "male": 334, "female": 342},
		{"key": "Lurikeen", "label": "Lurikeen", "id": 12, "stats": "Lurikeen", "male": 318, "female": 326},
		{"key": "Sylvan", "label": "Sylvan", "id": 15, "stats": "Sylvan", "male": 700, "female": 708},
		{"key": "Shar", "label": "Shar", "id": 18, "stats": "Shar", "male": 1075, "female": 1087},
		{"key": "Graoch", "label": "Graoch (Minotaure)", "id": 21, "stats": "HiberniaMinotaur", "male": 1419, "female": 0},
	],
}

var _classes: Array = []


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ClassTableScript.INDEX_PATH))
	if parsed is Dictionary:
		_classes = (parsed as Dictionary).get("classes", []) as Array


func races_for_realm(realm_id: int) -> Array:
	return (RACES.get(realm_id, []) as Array).duplicate(true)


func race(realm_id: int, race_key: String) -> Dictionary:
	for entry in RACES.get(realm_id, []) as Array:
		if str((entry as Dictionary).get("key")) == race_key:
			return (entry as Dictionary).duplicate()
	return {}


## Classes finales jouables par cette race (celles qu'aucune race n'a le droit
## de prendre, les classes de base, disparaissent d'elles-mêmes).
func classes_for_race(race_key: String) -> Array:
	var out: Array = []
	for value in _classes:
		var entry := value as Dictionary
		if race_key in (entry.get("eligible_races", []) as Array):
			out.append({"id": int(entry.get("id", 0)), "name": str(entry.get("display_name", entry.get("name", "")))})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name) < str(b.name))
	return out


func base_stats(realm_id: int, race_key: String) -> Dictionary:
	var entry := race(realm_id, race_key)
	return FormulasScript.race_starting_stats(str(entry.get("stats", "")))


## Coût d'un stat monté de `above` points : 1 par point jusqu'à 10, 2 de 11 à 15,
## 3 au-delà — la règle du codec, prouvée par la création live de P1-20.
static func cost_for(above: int) -> int:
	if above <= 0:
		return 0
	return above + maxi(0, above - 10) + maxi(0, above - 15)


func points_used(added: Dictionary) -> int:
	var total := 0
	for stat in STATS:
		total += cost_for(int(added.get(stat, 0)))
	return total


## Le dictionnaire attendu par `build_character_create_payload_1125`.
func build_create_data(realm_id: int, slot_index: int, name: String, race_key: String,
		female: bool, class_id: int, added: Dictionary) -> Dictionary:
	var entry := race(realm_id, race_key)
	var base := base_stats(realm_id, race_key)
	var data := {
		"slot_index": slot_index, "name": name, "realm_id": realm_id,
		"race_id": int(entry.get("id", 0)), "class_id": class_id,
		"gender": "female" if female else "male",
		"race_gender_byte": (int(entry.get("id", 0)) & 0x1f) | (0x80 if female else 0),
		"creation_model": int(entry.get("female" if female else "male", 0)),
		"region_id": 0, "operation": 1, "customize_type": 0, "custom_mode": 0,
		"eye_size": 0, "lip_size": 0, "eye_color": 0, "hair_color": 0,
		"face_type": 0, "hair_style": 0, "mood_type": 0, "level": 1,
	}
	for stat in STATS:
		data[STAT_FIELDS[stat]] = int(base.get(stat, 0)) + int(added.get(stat, 0))
	data["new_constitution"] = data["constitution"]
	return data


## Vérifie ce que le serveur refuserait, avant d'envoyer.
func validate(data: Dictionary, added: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var name := str(data.get("name", ""))
	var regex := RegEx.create_from_string("^[A-Z][a-zA-Z]{2,19}$")
	if regex.search(name) == null:
		errors.append("Nom : 3 à 20 lettres sans accent, majuscule initiale.")
	var entry := race(int(data.get("realm_id", 0)), _race_key_for_id(int(data.get("realm_id", 0)), int(data.get("race_id", 0))))
	if entry.is_empty():
		errors.append("Race inconnue pour ce royaume.")
	if int(data.get("creation_model", 0)) <= 0:
		errors.append("Cette race n'existe pas dans ce sexe.")
	var allowed := false
	for value in classes_for_race(str(entry.get("key", ""))):
		if int((value as Dictionary).get("id", -1)) == int(data.get("class_id", -2)):
			allowed = true
	if not allowed:
		errors.append("Classe interdite à cette race.")
	if points_used(added) != MAX_POINTS:
		errors.append("Il faut répartir exactement %d points (%d utilisés)." % [MAX_POINTS, points_used(added)])
	var slot := int(data.get("slot_index", -1))
	if slot < 0 or slot > 9:
		errors.append("Emplacement invalide.")
	var payload := (CreateCodecScript.new() as RefCounted).call("build_character_create_payload_1125", data) as PackedByteArray
	if payload.size() != CreateCodecScript.payload_size_for_name_1125(name):
		errors.append("Paquet de création mal formé.")
	return errors


func _race_key_for_id(realm_id: int, race_id: int) -> String:
	for entry in RACES.get(realm_id, []) as Array:
		if int((entry as Dictionary).get("id", 0)) == race_id:
			return str((entry as Dictionary).get("key"))
	return ""
