class_name DaocPlayerCatalogAppearance
extends RefCounted

## Relie un personnage jouable (CharacterOverview, ou modele 0x4B d'un autre
## joueur) a sa base nue du catalogue assemblable (`base_aNN`, exportee par le
## Lab pour les 36 apparences fig3). L'equipement est ensuite pose piece par
## piece par DaocPlayerEquipmentVisuals, comme pour Heyveno et Heyvena.

const CATALOG_ROOT := "res://generated/client_catalog"
const MANIFEST_PATH := CATALOG_ROOT + "/catalog.manifest.draft.json"

## Nom de race du CharacterOverview -> [apparence homme, apparence femme]
## (fig3map ; meme table que tools/p1_73_export_online_characters.gd).
const APPEARANCE_BY_RACE := {
	"briton": [1, 2], "saracen": [3, 4], "frostalf": [5, 6], "shar": [7, 8],
	"avalonian": [9, 10], "elf": [11, 12], "highlander": [13, 14], "norse": [15, 16],
	"norseman": [15, 16], "lurikeen": [17, 18], "kobold": [19, 20], "dwarf": [21, 22],
	"inconnu": [23, 24], "half ogre": [25, 26], "halfogre": [25, 26], "valkyn": [27, 28],
	"firbolg": [29, 30], "troll": [31, 32], "celt": [33, 34], "sylvan": [35, 36],
}

## Premier modele de chaque race/sexe jouable, `eLivingModel` de DOL
## (GlobalConstants.cs). Les variantes de visage suivent le modele de base :
## monsters.csv 61-64 = Avalonian Male, 65-68 = Avalonian Female.
const APPEARANCE_BY_BASE_MODEL := {
	32: 1, 35: 2, 39: 13, 43: 14, 48: 3, 52: 4, 61: 9, 65: 10,
	716: 23, 724: 24, 1008: 25, 1020: 26,
	137: 31, 145: 32, 503: 15, 507: 16, 169: 19, 177: 20, 185: 21, 193: 22,
	773: 27, 781: 28, 1051: 5, 1063: 6,
	286: 29, 294: 30, 302: 33, 310: 34, 318: 17, 326: 18, 334: 11, 342: 12,
	1075: 7, 1087: 8, 700: 35, 708: 36,
}
## Un visage ne s'eloigne jamais de plus de 7 modeles de sa base (Troll 137..144).
const MAX_FACE_OFFSET := 7


static func appearance_for_character(character: Dictionary) -> int:
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	var race := str(character.get("race_name", character.get("race",
		raw.get("race_name", raw.get("race", ""))))).to_lower().strip_edges()
	var pair: Array = APPEARANCE_BY_RACE.get(race, []) as Array
	if pair.is_empty():
		var model := int(character.get("current_model", raw.get("current_model", -1)))
		return appearance_for_model(model)
	# CharacterOverview : le sexe est le bit 0x10 de `race_and_gender`.
	var race_and_gender := int(character.get("race_and_gender", raw.get("race_and_gender", 0)))
	return int(pair[1] if (race_and_gender & 0x10) != 0 else pair[0])


static func appearance_for_model(model_id: int) -> int:
	var best_base := -1
	for base_value in APPEARANCE_BY_BASE_MODEL.keys():
		var base := int(base_value)
		if base <= model_id and model_id - base <= MAX_FACE_OFFSET and base > best_base:
			best_base = base
	return int(APPEARANCE_BY_BASE_MODEL[best_base]) if best_base >= 0 else -1


static func base_scene_for(appearance_id: int) -> String:
	if appearance_id <= 0:
		return ""
	var path := CATALOG_ROOT + "/characters/base_a%02d.tscn" % appearance_id
	return path if ResourceLoader.exists(path) else ""


## Echelle raciale de la recette (`scale_contract.visual_scale_for_target`),
## portee aussi par la meta `daoc_visual_scale` de la scene.
static func visual_scale_for_scene(scene_path: String) -> float:
	if not scene_path.begins_with(CATALOG_ROOT) or not FileAccess.file_exists(MANIFEST_PATH):
		return 0.0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		return 0.0
	var characters: Dictionary = (parsed as Dictionary).get("characters", {}) as Dictionary
	var entry: Dictionary = characters.get(scene_path.get_file().get_basename(), {}) as Dictionary
	var contract: Dictionary = entry.get("scale_contract", {}) as Dictionary
	return float(contract.get("visual_scale_for_target", 0.0))
