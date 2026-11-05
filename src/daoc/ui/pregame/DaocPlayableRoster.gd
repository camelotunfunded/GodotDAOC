extends RefCounted
class_name DaocPlayableRoster

## Le roster des personnages REELLEMENT jouables, et la scene 3D qui les montre.
##
## Jusqu'au 2026-09-15 l'ecran de selection hors ligne affichait six personnages
## de fixture (Aelynn, Gareth, Sigrun...) qu'aucune scene ne savait incarner : le
## jeu montait toujours `player_appearance_choice` de l'inspecteur, quel que
## soit le nom clique. Et l'apercu 3D montrait un GLB Meshy generique.
##
## Desormais :
## - hors ligne, trois personnages, un par apparence exportee du Lab :
##   Riri (Avalonienne, plate simple 04), Fifi (Troll, mailles), Loulou
##   (Lurikeen, cuir). Ce sont les trois scenes de `PLAYER_APPEARANCE_SCENES`
##   de DaocGameWorld, rien d'autre — un personnage sans scene n'est pas jouable ;
## - en ligne, les personnages du CharacterOverview serveur, montres avec la
##   scene la plus proche de leur race et de leur sexe (l'equipement serveur
##   n'est pas encore rendu : on choisit une tenue de depart plausible).
##
## Les deux chemins passent par `preview_scene_for` et `appearance_choice_for`,
## pour que l'apercu de l'ecran de selection et le personnage monte dans le
## monde soient LE MEME modele.

const APPEARANCE_AVALONIENNE := 0
const APPEARANCE_TROLL := 1
const APPEARANCE_LURIKEEN := 2

const APPEARANCE_SCENES := {
	APPEARANCE_AVALONIENNE: "res://assets/daoc/player/briton_female_modern/briton_female_simple_plate_04.tscn",
	APPEARANCE_TROLL: "res://assets/daoc/player/troll_male_modern/troll_male_chain.tscn",
	APPEARANCE_LURIKEEN: "res://assets/daoc/player/lurikeen_male_modern/lurikeen_male_leather.tscn",
}

## Scenes de depart pour un personnage SERVEUR dont on ne connait que la race et
## le sexe. Femme -> tenue de depart de Heyveno ; troll -> troll de depart ;
## lurikeen -> cuir ; tout le reste -> plate simple 04.
const ONLINE_SCENE_FEMALE := "res://assets/daoc/player/briton_female_modern/briton_female_heyveno_starter.tscn"
const ONLINE_SCENE_TROLL := "res://assets/daoc/player/troll_male_modern/troll_male_starter.tscn"
const ONLINE_SCENE_LURIKEEN := "res://assets/daoc/player/lurikeen_male_modern/lurikeen_male_leather.tscn"
const ONLINE_SCENE_DEFAULT := "res://assets/daoc/player/briton_female_modern/briton_female_simple_plate_04.tscn"

## Gothwaite, zone 51 : la seule zone dont le peuplement hors ligne est valide.
const OFFLINE_REGION_ID := 51
const OFFLINE_LOCATION := "Gothwaite"
## Identifiants DOL des metiers du roster (p1_23_dol_class_table.json).
const OFFLINE_CLASS_IDS := {"Maître d'armes": 2, "Guerrier": 22, "Enchanteur": 41}


## Le metier DOL d'un personnage : overview serveur (class_id) ou roster.
static func class_id_for(character: Dictionary) -> int:
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	return int(character.get("class_id", raw.get("class_id", 0)))


static func offline_characters() -> Array[Dictionary]:
	return [
		_offline(0, "Riri", "Avalonienne", "Maître d'armes", APPEARANCE_AVALONIENNE),
		_offline(1, "Fifi", "Troll", "Guerrier", APPEARANCE_TROLL),
		_offline(2, "Loulou", "Lurikeen", "Enchanteur", APPEARANCE_LURIKEEN),
	]


## Modele d'ecran de selection hors ligne. Le royaume choisi ne filtre PAS : les
## trois personnages ont une scene, ils sont jouables quel que soit le blason
## clique, et cacher un Troll parce qu'on a clique Albion cacherait un tiers de
## ce qui marche.
static func offline_overview(realm_id: int) -> Dictionary:
	var characters: Array[Dictionary] = []
	for character in offline_characters():
		var copy := character.duplicate(true)
		copy["realm_id"] = clampi(realm_id, 1, 3)
		characters.append(copy)
	return {
		"ui_phase": "CHARACTER_SELECT",
		"selected_realm": {"id": clampi(realm_id, 1, 3)},
		"characters": characters,
		"character_count": characters.size(),
		"selected": {},
		"source": "offline_roster",
	}


## La scene a instancier pour montrer ce personnage, ou "" s'il n'en a aucune.
static func preview_scene_for(character: Dictionary) -> String:
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	var explicit := str(character.get("preview_scene", raw.get("preview_scene", "")))
	if explicit != "":
		return explicit
	if character.has("appearance_choice") or raw.has("appearance_choice"):
		var choice := int(character.get("appearance_choice", raw.get("appearance_choice", -1)))
		if APPEARANCE_SCENES.has(choice):
			return str(APPEARANCE_SCENES[choice])
	if str(character.get("name", "")) == "":
		return ""
	# P1-130 : la base du CATALOGUE passe en premier. Elle porte les animations
	# completes (Lab P1-130 : 244 clips par race) et s habille piece par piece
	# (tenue nue de la race, armure, armes actives). Les scenes pre-cuites
	# `online_<nom>.tscn` (P1-73, 43 clips, tout l equipement cuit) ne servent
	# plus que de repli : Vcx gardait ainsi ses vieux clips (retour du 29/09).
	var catalog_base := DaocPlayerCatalogAppearance.base_scene_for(
		DaocPlayerCatalogAppearance.appearance_for_character(character))
	if catalog_base != "":
		return catalog_base
	var exported := exported_online_scene_for(str(character.get("name", "")))
	if exported != "":
		return exported
	return _online_scene_for(character, raw)


static func exported_online_scene_for(name: String) -> String:
	if name.strip_edges() == "":
		return ""
	var path := "res://assets/daoc/player/online/online_%s.tscn" % name.to_lower().validate_filename()
	return path if ResourceLoader.exists(path) else ""


## Le choix d'apparence de DaocGameWorld pour ce personnage.
static func appearance_choice_for(character: Dictionary) -> int:
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	if character.has("appearance_choice") or raw.has("appearance_choice"):
		return clampi(int(character.get("appearance_choice", raw.get("appearance_choice", 0))), 0, 2)
	var race := _race_of(character, raw)
	if race.contains("troll"):
		return APPEARANCE_TROLL
	if race.contains("lurikeen"):
		return APPEARANCE_LURIKEEN
	return APPEARANCE_AVALONIENNE


static func _online_scene_for(character: Dictionary, raw: Dictionary) -> String:
	var race := _race_of(character, raw)
	if race.contains("troll"):
		return ONLINE_SCENE_TROLL
	if race.contains("lurikeen"):
		return ONLINE_SCENE_LURIKEEN
	var gender := str(character.get("gender", raw.get("gender", raw.get("gender_name", "")))).to_lower()
	# CharacterOverview 1.125 : `race_and_gender` porte la race dans le quartet bas
	# et le sexe dans le bit 0x10 (Heyveno Bretonne = 17 = 0x11, Briton 1 + femme).
	var race_and_gender := int(character.get("race_and_gender", raw.get("race_and_gender", -1)))
	var female_bit := race_and_gender >= 0 and (race_and_gender & 0x10) != 0
	if female_bit or gender.begins_with("f") or gender == "1" or race.ends_with("ienne") or race.ends_with("onne"):
		return ONLINE_SCENE_FEMALE
	return ONLINE_SCENE_DEFAULT


static func _race_of(character: Dictionary, raw: Dictionary) -> String:
	return str(character.get("race_name", character.get("race", raw.get("race_name", raw.get("race", ""))))).to_lower()


static func _offline(slot: int, name: String, race: String, profession: String, appearance: int) -> Dictionary:
	return {
		"class_id": OFFLINE_CLASS_IDS.get(profession, 0),
		"slot_index": slot,
		"realm_id": 1,
		"name": name,
		"level": 1,
		"class_name": profession,
		"class": profession,
		"race_name": race,
		"race": race,
		"location": OFFLINE_LOCATION,
		"region_id": OFFLINE_REGION_ID,
		"appearance_choice": appearance,
		"preview_scene": str(APPEARANCE_SCENES[appearance]),
		"valid": true,
		"empty": false,
	}
