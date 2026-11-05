extends RefCounted
class_name DaocPlayerChampionLevelState

## Progression Champion moderne (1.116+) : CL0-15, un point d'embarquement,
## puis un point par CL. Chaque colonne coute 1, 2, 3, 4 puis 5 points.

const MAX_CHAMPION_LEVEL := 15
const MAX_LINE_RANK := 5
const BASIS := "DAOC_1_116_AND_DOL_CHAMPION_SPECIALTY_POINTS"

const REALM_PROFESSIONS := {
	"Albion": ["Acolyte", "Disciple", "Elementalist", "Fighter", "Mage", "Rogue"],
	"Midgard": ["Mystic", "Rogue", "Seer", "Viking"],
	"Hibernia": ["Forester", "Guardian", "Magician", "Naturalist", "Stalker"],
}
const BASE_PROFESSION_BY_CLASS_ID := {
	1:"Fighter",2:"Fighter",3:"Rogue",4:"Rogue",5:"Elementalist",6:"Acolyte",7:"Elementalist",8:"Mage",9:"Rogue",10:"Acolyte",11:"Fighter",12:"Disciple",13:"Mage",19:"Fighter",33:"Acolyte",60:"Fighter",
	21:"Viking",22:"Viking",23:"Rogue",24:"Viking",25:"Rogue",26:"Seer",27:"Mystic",28:"Seer",29:"Mystic",30:"Mystic",31:"Viking",32:"Viking",34:"Viking",59:"Mystic",61:"Viking",
	39:"Magician",40:"Magician",41:"Magician",42:"Magician",43:"Guardian",44:"Guardian",45:"Guardian",46:"Naturalist",47:"Naturalist",48:"Naturalist",49:"Stalker",50:"Stalker",55:"Forester",56:"Forester",58:"Stalker",62:"Guardian",
}
const REALM_BY_CLASS_ID := {
	1:"Albion",2:"Albion",3:"Albion",4:"Albion",5:"Albion",6:"Albion",7:"Albion",8:"Albion",9:"Albion",10:"Albion",11:"Albion",12:"Albion",13:"Albion",19:"Albion",33:"Albion",60:"Albion",
	21:"Midgard",22:"Midgard",23:"Midgard",24:"Midgard",25:"Midgard",26:"Midgard",27:"Midgard",28:"Midgard",29:"Midgard",30:"Midgard",31:"Midgard",32:"Midgard",34:"Midgard",59:"Midgard",61:"Midgard",
	39:"Hibernia",40:"Hibernia",41:"Hibernia",42:"Hibernia",43:"Hibernia",44:"Hibernia",45:"Hibernia",46:"Hibernia",47:"Hibernia",48:"Hibernia",49:"Hibernia",50:"Hibernia",55:"Hibernia",56:"Hibernia",58:"Hibernia",62:"Hibernia",
}

var character_key := "default"
var class_id := 0
var character_level := 1
var champion_enabled := false
var champion_level := 0
var trained_lines: Dictionary = {}


func setup(p_character_key: String, p_class_id: int, p_character_level: int) -> DaocPlayerChampionLevelState:
	character_key = p_character_key.strip_edges() if p_character_key.strip_edges() != "" else "default"
	class_id = p_class_id
	character_level = maxi(1, p_character_level)
	return self


func embark() -> Dictionary:
	if character_level < 50:
		return {"ok": false, "reason": "niveau 50 requis"}
	champion_enabled = true
	return {"ok": true, "available_points": available_points()}


func set_champion_level(value: int) -> Dictionary:
	if not champion_enabled:
		return {"ok": false, "reason": "progression Champion non commencee"}
	var previous_level := champion_level
	champion_level = clampi(value, 0, MAX_CHAMPION_LEVEL)
	if spent_points() > total_points():
		champion_level = previous_level
		return {"ok": false, "reason": "choix incompatibles avec ce Champion Level"}
	return {"ok": true, "champion_level": champion_level, "available_points": available_points()}


func allowed_professions() -> Array:
	var realm := str(REALM_BY_CLASS_ID.get(class_id, ""))
	var own := str(BASE_PROFESSION_BY_CLASS_ID.get(class_id, ""))
	var out := (REALM_PROFESSIONS.get(realm, []) as Array).duplicate()
	out.erase(own)
	return out


func train_line(profession: String, line_key: String, desired_rank: int,
		catalogue_lines: Dictionary) -> Dictionary:
	if not champion_enabled:
		return {"ok": false, "reason": "progression Champion non commencee"}
	if not allowed_professions().has(profession):
		return {"ok": false, "reason": "profession de sous-classe interdite"}
	if not catalogue_lines.has(line_key) or str((catalogue_lines[line_key] as Dictionary).get("profession", "")) != profession:
		return {"ok": false, "reason": "ligne Champion inconnue"}
	var old_rank := int(trained_lines.get(line_key, 0))
	if desired_rank != old_rank + 1 or desired_rank > MAX_LINE_RANK:
		return {"ok": false, "reason": "rang precedent requis"}
	if available_points() < desired_rank:
		return {"ok": false, "reason": "points Champion insuffisants"}
	trained_lines[line_key] = desired_rank
	return {"ok": true, "line": line_key, "rank": desired_rank, "cost": desired_rank,
		"available_points": available_points()}


func total_points() -> int:
	return 0 if not champion_enabled else champion_level + 1


func spent_points() -> int:
	var total := 0
	for value in trained_lines.values():
		var rank := int(value)
		total += int(rank * (rank + 1) / 2.0)
	return total


func available_points() -> int:
	return maxi(0, total_points() - spent_points())


func unlocked_abilities(catalogue_lines: Dictionary) -> Array:
	var out: Array = []
	for line_key_value in trained_lines:
		var line_key := str(line_key_value)
		if not catalogue_lines.has(line_key):
			continue
		var definition := catalogue_lines[line_key] as Dictionary
		var abilities := definition.get("abilities", []) as Array
		for index in mini(int(trained_lines[line_key]), abilities.size()):
			var entry := (abilities[index] as Dictionary).duplicate(true)
			entry["kind"] = str(entry.get("kind", "champion_ability"))
			entry["ability_id"] = str(entry.get("ability_id", "cl:%s:%d" % [line_key, index + 1]))
			entry["line"] = line_key
			entry["profession"] = str(definition.get("profession", ""))
			entry["required_level"] = index + 1
			out.append(entry)
	return out


func save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "sauvegarde inaccessible"}
	file.store_string(JSON.stringify({"version":1,"basis":BASIS,"character":character_key,
		"class_id":class_id,"champion_enabled":champion_enabled,"champion_level":champion_level,
		"trained_lines":trained_lines}, "\t"))
	file.close()
	return {"ok": true}


func load(path: String, catalogue_lines: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "new_file": true}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "sauvegarde illisible"}
	var payload := parsed as Dictionary
	if str(payload.get("character", "")) != character_key or int(payload.get("class_id", -1)) != class_id:
		return {"ok": false, "reason": "sauvegarde d'un autre personnage ou metier"}
	champion_enabled = bool(payload.get("champion_enabled", false))
	champion_level = clampi(int(payload.get("champion_level", 0)), 0, MAX_CHAMPION_LEVEL)
	trained_lines = (payload.get("trained_lines", {}) as Dictionary).duplicate(true)
	for line_key in trained_lines:
		var profession := str((catalogue_lines.get(line_key, {}) as Dictionary).get("profession", ""))
		if not catalogue_lines.has(line_key) or not allowed_professions().has(profession) \
				or int(trained_lines[line_key]) < 1 or int(trained_lines[line_key]) > MAX_LINE_RANK:
			trained_lines.clear()
			return {"ok": false, "reason": "ligne Champion sauvegardee invalide"}
	if spent_points() > total_points():
		trained_lines.clear()
		return {"ok": false, "reason": "depense Champion invalide"}
	return {"ok": true, "available_points": available_points()}
