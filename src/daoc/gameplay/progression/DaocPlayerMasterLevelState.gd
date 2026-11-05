extends RefCounted
class_name DaocPlayerMasterLevelState

## Progression ToA distincte des specialisations de classe. Une seule voie est
## active et son niveau ne peut jamais depasser ML10.

const MAX_MASTER_LEVEL := 10
const BASIS := "DAOC_OFFICIAL_CLASS_OPTIONS_AND_DOL_MLLEVEL"

const PATHS_BY_CLASS_ID := {
	1: ["Warlord", "Battlemaster"],
	2: ["Warlord", "Battlemaster"],
	3: ["Battlemaster", "Sojourner"],
	4: ["Warlord", "Sojourner"],
	5: ["Convoker", "Stormlord"],
	6: ["Warlord", "Perfecter"],
	7: ["Convoker", "Stormlord"],
	8: ["Convoker", "Stormlord"],
	9: ["Spymaster", "Battlemaster"],
	10: ["Battlemaster", "Perfecter"],
	11: ["Battlemaster", "Banelord"],
	12: ["Convoker", "Warlord"],
	13: ["Convoker", "Stormlord"],
	19: ["Battlemaster", "Banelord"],
	21: ["Battlemaster", "Stormlord"],
	22: ["Warlord", "Battlemaster"],
	23: ["Spymaster", "Battlemaster"],
	24: ["Warlord", "Sojourner"],
	25: ["Sojourner", "Battlemaster"],
	26: ["Sojourner", "Perfecter"],
	27: ["Convoker", "Stormlord"],
	28: ["Convoker", "Perfecter"],
	29: ["Convoker", "Stormlord"],
	30: ["Convoker", "Banelord"],
	31: ["Battlemaster", "Banelord"],
	32: ["Warlord", "Battlemaster"],
	33: ["Banelord", "Perfecter"],
	34: ["Stormlord", "Warlord"],
	39: ["Convoker", "Stormlord"],
	40: ["Convoker", "Stormlord"],
	41: ["Convoker", "Stormlord"],
	42: ["Stormlord", "Warlord"],
	43: ["Battlemaster", "Banelord"],
	44: ["Battlemaster", "Warlord"],
	45: ["Battlemaster", "Banelord"],
	46: ["Battlemaster", "Perfecter"],
	47: ["Convoker", "Perfecter"],
	48: ["Sojourner", "Perfecter"],
	49: ["Spymaster", "Stormlord"],
	50: ["Battlemaster", "Sojourner"],
	55: ["Convoker", "Stormlord"],
	56: ["Battlemaster", "Stormlord"],
	58: ["Banelord", "Warlord"],
	59: ["Banelord", "Convoker"],
	60: ["Battlemaster", "Warlord"],
	61: ["Battlemaster", "Warlord"],
	62: ["Battlemaster", "Warlord"],
}

# Ordre ML1 -> ML10 de la table officielle. `kind` distingue les styles des
# capacités actives/passives : ils suivront des arbitres différents.
const ABILITIES_BY_PATH := {
	"Banelord": [
		{"ability_id": "ml:banelord:1", "name": "Zone of Unmana", "kind": "ability"},
		{"ability_id": "ml:banelord:2", "name": "Primal Agony", "kind": "ability"},
		{"ability_id": "ml:banelord:3", "name": "Oppression", "kind": "ability"},
		{"ability_id": "ml:banelord:4", "name": "Inexorable Defeat", "kind": "ability"},
		{"ability_id": "ml:banelord:5", "name": "Tactical Insight", "kind": "ability"},
		{"ability_id": "ml:banelord:6", "name": "Snaring Tendrils of Power", "kind": "ability"},
		{"ability_id": "ml:banelord:7", "name": "Chaotic Power", "kind": "ability"},
		{"ability_id": "ml:banelord:8", "name": "Agony Transmission", "kind": "ability"},
		{"ability_id": "ml:banelord:9", "name": "Demoralization", "kind": "ability"},
		{"ability_id": "ml:banelord:10", "name": "Banespike", "kind": "ability"},
	],
	"Warlord": [
		{"ability_id": "ml:warlord:1", "name": "Siege Master", "kind": "passive"},
		{"ability_id": "ml:warlord:2", "name": "Bolstering Battlecry", "kind": "ability"},
		{"ability_id": "ml:warlord:3", "name": "Cowering Bellow", "kind": "ability"},
		{"ability_id": "ml:warlord:4", "name": "Resillient Will", "kind": "ability"},
		{"ability_id": "ml:warlord:5", "name": "Guided Strike", "kind": "ability"},
		{"ability_id": "ml:warlord:6", "name": "Energizing Aura", "kind": "ability"},
		{"ability_id": "ml:warlord:7", "name": "Cleansing Aura", "kind": "ability"},
		{"ability_id": "ml:warlord:8", "name": "Defending Martyr", "kind": "ability"},
		{"ability_id": "ml:warlord:9", "name": "Leadership", "kind": "ability"},
		{"ability_id": "ml:warlord:10", "name": "Warguard", "kind": "ability"},
	],
	"Battlemaster": [
		{"ability_id": "ml:battlemaster:1", "name": "Sapping Strike", "kind": "style"},
		{"ability_id": "ml:battlemaster:2", "name": "Faultfinder", "kind": "style"},
		{"ability_id": "ml:battlemaster:3", "name": "Power Leak", "kind": "style"},
		{"ability_id": "ml:battlemaster:4", "name": "Grapple", "kind": "ability"},
		{"ability_id": "ml:battlemaster:5", "name": "Essence Flames", "kind": "style"},
		{"ability_id": "ml:battlemaster:6", "name": "Throw Weapon", "kind": "ability"},
		{"ability_id": "ml:battlemaster:7", "name": "Essence Sear", "kind": "style"},
		{"ability_id": "ml:battlemaster:8", "name": "Bodyguard", "kind": "ability"},
		{"ability_id": "ml:battlemaster:9", "name": "Essence Dampen", "kind": "style"},
		{"ability_id": "ml:battlemaster:10", "name": "Essence Shatter", "kind": "style"},
	],
	"Convoker": [
		{"ability_id": "ml:convoker:1", "name": "Summon Wood", "kind": "ability"},
		{"ability_id": "ml:convoker:2", "name": "Prescience Node", "kind": "ability"},
		{"ability_id": "ml:convoker:3", "name": "Power Trap", "kind": "ability"},
		{"ability_id": "ml:convoker:4", "name": "Speedwarp", "kind": "ability"},
		{"ability_id": "ml:convoker:5", "name": "Summon Warcrystal", "kind": "ability"},
		{"ability_id": "ml:convoker:6", "name": "Battlewarder", "kind": "ability"},
		{"ability_id": "ml:convoker:7", "name": "Dissonance Trap", "kind": "ability"},
		{"ability_id": "ml:convoker:8", "name": "Brittle Guard", "kind": "ability"},
		{"ability_id": "ml:convoker:9", "name": "Summoning Mastery", "kind": "ability"},
		{"ability_id": "ml:convoker:10", "name": "Crystal Titan", "kind": "ability"},
	],
	"Perfecter": [
		{"ability_id": "ml:perfecter:1", "name": "Purging Wave", "kind": "ability"},
		{"ability_id": "ml:perfecter:2", "name": "Purify Vision", "kind": "ability"},
		{"ability_id": "ml:perfecter:3", "name": "Sphere of Rejuvenation", "kind": "ability"},
		{"ability_id": "ml:perfecter:4", "name": "Greatness", "kind": "passive"},
		{"ability_id": "ml:perfecter:5", "name": "Font of Power", "kind": "ability"},
		{"ability_id": "ml:perfecter:6", "name": "Determination Field", "kind": "ability"},
		{"ability_id": "ml:perfecter:7", "name": "Leaping Health", "kind": "ability"},
		{"ability_id": "ml:perfecter:8", "name": "Restore the Soul", "kind": "ability"},
		{"ability_id": "ml:perfecter:9", "name": "Dissonating Ward", "kind": "ability"},
		{"ability_id": "ml:perfecter:10", "name": "Rampant Healing", "kind": "ability"},
	],
	"Sojourner": [
		{"ability_id": "ml:sojourner:1", "name": "Unburdened Warrior", "kind": "passive"},
		{"ability_id": "ml:sojourner:2", "name": "Unending Breath", "kind": "ability"},
		{"ability_id": "ml:sojourner:3", "name": "Reveal Crystalseed", "kind": "ability"},
		{"ability_id": "ml:sojourner:4", "name": "Unmake Crystalseed", "kind": "ability"},
		{"ability_id": "ml:sojourner:5", "name": "Ancient Transmuter", "kind": "ability"},
		{"ability_id": "ml:sojourner:6", "name": "Gateway", "kind": "ability"},
		{"ability_id": "ml:sojourner:7", "name": "Resistance of the Ancients", "kind": "ability"},
		{"ability_id": "ml:sojourner:8", "name": "Forceful Zephyr", "kind": "ability"},
		{"ability_id": "ml:sojourner:9", "name": "Phase Shift", "kind": "ability"},
		{"ability_id": "ml:sojourner:10", "name": "Mass Gateway", "kind": "ability"},
	],
	"Spymaster": [
		{"ability_id": "ml:spymaster:1", "name": "Pickpocket", "kind": "passive"},
		{"ability_id": "ml:spymaster:2", "name": "Decoy", "kind": "ability"},
		{"ability_id": "ml:spymaster:3", "name": "Enduring Poison", "kind": "passive"},
		{"ability_id": "ml:spymaster:4", "name": "Sabotage", "kind": "ability"},
		{"ability_id": "ml:spymaster:5", "name": "Tanglesnare", "kind": "ability"},
		{"ability_id": "ml:spymaster:6", "name": "Poisonspike", "kind": "ability"},
		{"ability_id": "ml:spymaster:7", "name": "Lookout", "kind": "ability"},
		{"ability_id": "ml:spymaster:8", "name": "Siege Wrecker", "kind": "ability"},
		{"ability_id": "ml:spymaster:9", "name": "Essence Flare", "kind": "ability"},
		{"ability_id": "ml:spymaster:10", "name": "Blanket of Camouflage", "kind": "ability"},
	],
	"Stormlord": [
		{"ability_id": "ml:stormlord:1", "name": "Dazzling Array", "kind": "ability"},
		{"ability_id": "ml:stormlord:2", "name": "Vacuum Vortex", "kind": "ability"},
		{"ability_id": "ml:stormlord:3", "name": "Enervating Gas", "kind": "ability"},
		{"ability_id": "ml:stormlord:4", "name": "Inebriating Fumes", "kind": "ability"},
		{"ability_id": "ml:stormlord:5", "name": "Mental Siphon", "kind": "ability"},
		{"ability_id": "ml:stormlord:6", "name": "Focusing Winds", "kind": "ability"},
		{"ability_id": "ml:stormlord:7", "name": "Fearsome Surge", "kind": "ability"},
		{"ability_id": "ml:stormlord:8", "name": "Blinding Cloud", "kind": "ability"},
		{"ability_id": "ml:stormlord:9", "name": "Energy Tempest", "kind": "ability"},
		{"ability_id": "ml:stormlord:10", "name": "Arcing Power", "kind": "ability"},
	],
}

var character_key: String = "default"
var class_id: int = 0
var path_name: String = ""
var master_level: int = 0


func setup(p_character_key: String, p_class_id: int) -> DaocPlayerMasterLevelState:
	character_key = p_character_key.strip_edges() if p_character_key.strip_edges() != "" else "default"
	class_id = p_class_id
	return self


func available_paths() -> Array:
	return (PATHS_BY_CLASS_ID.get(class_id, []) as Array).duplicate()


func choose_path(requested_path: String) -> Dictionary:
	if not available_paths().has(requested_path):
		return {"ok": false, "reason": "voie ML indisponible pour ce metier"}
	path_name = requested_path
	return {"ok": true, "path": path_name}


func set_master_level(value: int) -> Dictionary:
	if path_name == "" and value > 0:
		return {"ok": false, "reason": "aucune voie ML choisie"}
	master_level = clampi(value, 0, MAX_MASTER_LEVEL)
	return {"ok": true, "path": path_name, "master_level": master_level}


func unlocked_line_levels() -> Dictionary:
	if path_name == "" or master_level <= 0:
		return {}
	return {path_name: master_level}


func unlocked_abilities() -> Array:
	var out: Array = []
	var entries := ABILITIES_BY_PATH.get(path_name, []) as Array
	for index in mini(master_level, entries.size()):
		var entry := (entries[index] as Dictionary).duplicate(true)
		entry["path"] = path_name
		entry["required_level"] = index + 1
		out.append(entry)
	return out


func unlocked_catalogue_entries(catalogue: DaocSpellCatalogue) -> Dictionary:
	if catalogue == null or not catalogue.loaded:
		return {"ok": false, "reason": "catalogue indisponible", "entries": []}
	var dump_entries: Array = catalogue.spells_up_to_level(path_name, master_level) if path_name != "" else []
	var entries := unlocked_abilities()
	return {
		"ok": true,
		"path": path_name,
		"master_level": master_level,
		"entries": entries,
		"dump_entries": dump_entries,
		"data_complete": entries.size() == master_level,
		"basis": BASIS,
	}


func save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "sauvegarde inaccessible"}
	file.store_string(JSON.stringify({
		"version": 1, "basis": BASIS, "character": character_key,
		"class_id": class_id, "path": path_name, "master_level": master_level,
	}, "\t"))
	file.close()
	return {"ok": true}


func load(path: String) -> Dictionary:
	path_name = ""
	master_level = 0
	if not FileAccess.file_exists(path):
		return {"ok": true, "new_file": true}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "sauvegarde illisible"}
	var payload := parsed as Dictionary
	if str(payload.get("character", "")) != character_key or int(payload.get("class_id", -1)) != class_id:
		return {"ok": false, "reason": "sauvegarde d'un autre personnage ou metier"}
	var selected := str(payload.get("path", ""))
	if selected != "" and not bool(choose_path(selected).get("ok", false)):
		return {"ok": false, "reason": "voie ML sauvegardee invalide"}
	return set_master_level(int(payload.get("master_level", 0)))
