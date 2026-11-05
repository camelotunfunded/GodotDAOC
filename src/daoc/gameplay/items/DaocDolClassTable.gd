extends RefCounted
class_name DaocDolClassTable

## P1-27 — la table des métiers, lue dans l'index extrait par P1-23.
##
## L'index existait depuis P1-23 mais personne ne le LISAIT au runtime : ses deux
## valeurs utiles, `BaseHP` et `BaseWeaponSkill`, étaient recopiées en constantes
## dans `DaocLocalServerVitals` pour la seule fixture canonique. P1-27 ajoute une
## troisième valeur qui ne peut PAS être recopiée à la main sans mentir —
## `auto_train_skills` — et ce lecteur avec elle.
##
## CE QUE L'AUTO-ENTRAÎNEMENT APPORTE, et pourquoi c'est le seul morceau de
## progression de personnage qui soit DÉRIVABLE : `GetAutoTrainPoints`
## (GamePlayer.cs:5272) fait monter certaines spécialisations **toutes seules**
## jusqu'à `niveau / 4`, sans que le joueur dépense quoi que ce soit. Ce n'est
## donc pas un choix de build — c'est une règle, et elle s'applique à tout
## personnage du métier.
##
## TOUT LE RESTE DE LA PROGRESSION RESTE INCONNU. Ce qu'un personnage a APPRIS
## par ses points de spécialisation n'est nulle part sur ce disque.

const INDEX_PATH := "res://data/gameplay/dol/p1_23_dol_class_table.json"
const PLAYER_RULES_PATH := "res://data/player/opendaoc_player_rules.json"

const BASIS_DOL_CODE := "DOL_CODE"

var loaded: bool = false
var error: String = ""

var _by_id: Dictionary = {}
var _by_name: Dictionary = {}
var _source: Dictionary = {}
var _career_specs_by_id: Dictionary = {}


func load_index(path: String = INDEX_PATH) -> bool:
	loaded = false
	error = ""
	if not FileAccess.file_exists(path):
		error = "table des métiers absente : %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "table des métiers illisible : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "table mal formée"
		return false
	var payload: Dictionary = parsed as Dictionary
	_source = payload.get("source", {}) as Dictionary
	_by_id = {}
	_by_name = {}
	_career_specs_by_id = {}
	for value in (payload.get("classes", []) as Array):
		var entry: Dictionary = value as Dictionary
		_by_id[int(entry.get("id", -1))] = entry
		_by_name[str(entry.get("name", ""))] = entry
	_load_career_specs()
	loaded = not _by_id.is_empty()
	if not loaded:
		error = "table vide"
	return loaded


func class_count() -> int:
	return _by_id.size()


func entry_for_id(class_id: int) -> Dictionary:
	var entry: Variant = _by_id.get(class_id, null)
	return (entry as Dictionary).duplicate(true) if entry != null else {}


func base_hp(class_id: int) -> int:
	return int(entry_for_id(class_id).get("base_hp", 0))


func base_weapon_skill(class_id: int) -> int:
	return int(entry_for_id(class_id).get("base_weapon_skill", 0))


## Les spécialisations que ce métier monte TOUT SEUL.
##
## Un métier peut n'en avoir aucune — le Wizard, par exemple — et rendre un
## tableau vide est alors la bonne réponse, pas un défaut.
func auto_train_skills(class_id: int) -> Array:
	return (entry_for_id(class_id).get("auto_train_skills", []) as Array).duplicate()


func career_specs(class_id: int) -> Array:
	return (_career_specs_by_id.get(class_id, []) as Array).duplicate()


func _load_career_specs() -> void:
	if not FileAccess.file_exists(PLAYER_RULES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYER_RULES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for value in ((parsed as Dictionary).get("classes", []) as Array):
		var entry := value as Dictionary
		_career_specs_by_id[int(entry.get("id", -1))] = (entry.get("career_specs", []) as Array).duplicate()


## `GamePlayer.GetAutoTrainPoints` — GamePlayer.cs:5274 : `Level / 4`, jamais
## moins de 1. Le niveau d'une spécialisation NON auto-entraînée reste 1 : c'est
## le plancher de DOL pour une spécialisation connue mais non montée.
##
## Rend un dictionnaire `spécialisation -> niveau`, prêt pour
## `DaocCombatEntityState.spec_levels`.
func auto_trained_spec_levels(class_id: int, character_level: int) -> Dictionary:
	var out: Dictionary = {}
	var level: int = maxi(1, int(character_level / 4.0))
	for skill in auto_train_skills(class_id):
		out[str(skill)] = level
	return out


func matches_sources(source_root_resolver: Callable) -> bool:
	for relative in _source.keys():
		var recorded: Dictionary = _source[relative] as Dictionary
		var path: String = str(source_root_resolver.call(str(relative)))
		if path == "" or not FileAccess.file_exists(path):
			continue
		if int(FileAccess.get_modified_time(path)) != int(recorded.get("modified", -1)):
			return false
	return true
