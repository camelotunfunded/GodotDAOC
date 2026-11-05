extends RefCounted
class_name DaocRaceIndex

## P1-26 — les résistances raciales, lues dans l'index pré-cuit.
##
## `resists` était marqué `PLACEHOLDER` depuis P1-21A, et ce n'était pas anodin :
## la chaîne de dégâts de P1-23B les APPLIQUE — `melee_damage` retire
## `dégâts * résistance * 0,01`. Une résistance nulle partout est un chiffre qui
## agit, pas une absence.
##
## CE QUE L'INDEX PORTE : les 41 races de `race.sql`, avec leurs dix résistances.
## Les 22 premières sont jouables ; les autres — `Animal`, `Humanoid`, `Undead`,
## `Demon`, `Dragons`, `Giant` — sont des **familles de monstres**, et `mob.sql`
## y renvoie par sa colonne `Race`.
##
## LES DEUX CÔTÉS EN ONT DONC, et le premier jet de ce jalon disait le contraire.
## Sur les 188 PNJ de la capture, **88 déclarent une race** : 25 `Animal`,
## 51 `Humanoid`, 12 `Undead`.
##
## `ResistCalculator.HardCap` vaut 70 — le seul plafond, et il n'est jamais
## atteint sans objets ni buffs.

const INDEX_PATH := "res://data/gameplay/dol/p1_26_race_index.json"

const BASIS_DUMP_RACE := "DUMP_RACE"

## `ResistCalculator.HardCap` — propertycalc/ResistCalculator.cs:197.
const RESIST_HARD_CAP := 70

var loaded: bool = false
var error: String = ""

var _by_name: Dictionary = {}
var _by_id: Dictionary = {}
var _source: Dictionary = {}


func load_index(path: String = INDEX_PATH) -> bool:
	loaded = false
	error = ""
	if not FileAccess.file_exists(path):
		error = "index absent : %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "index illisible : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "index mal formé"
		return false
	var payload: Dictionary = parsed as Dictionary
	_source = payload.get("source", {}) as Dictionary
	_by_name = payload.get("races", {}) as Dictionary
	_by_id = {}
	for name in _by_name:
		var entry: Dictionary = _by_name[name] as Dictionary
		_by_id[int(entry.get("id", 0))] = entry
	loaded = not _by_name.is_empty()
	if not loaded:
		error = "index vide"
	return loaded


func source_fingerprint() -> Dictionary:
	return _source.duplicate(true)


func race_count() -> int:
	return _by_name.size()


## Les résistances d'une race, par NOM. Rend un dictionnaire VIDE pour une race
## inconnue — jamais des zéros, qui se confondraient avec « aucune résistance ».
func resists_for_name(race_name: String) -> Dictionary:
	var entry: Variant = _by_name.get(race_name, null)
	if entry == null:
		return {}
	return ((entry as Dictionary).get("resists", {}) as Dictionary).duplicate()


## Les résistances d'une race, par IDENTIFIANT — celui que porte `mob.sql`.
##
## L'IDENTIFIANT ZÉRO EST L'ABSENCE, pas une race : 85 des 188 PNJ de la capture
## n'en déclarent aucune, et leur rendre les résistances de la race 0 serait une
## invention. On rend vide, et l'appelant garde ses zéros déclarés.
func resists_for_id(race_id: int) -> Dictionary:
	if race_id <= 0:
		return {}
	var entry: Variant = _by_id.get(race_id, null)
	if entry == null:
		return {}
	return ((entry as Dictionary).get("resists", {}) as Dictionary).duplicate()


func name_for_id(race_id: int) -> String:
	var entry: Variant = _by_id.get(race_id, null)
	if entry == null:
		return ""
	return str((entry as Dictionary).get("name", ""))


## Même contrat qu'à P1-24 : un index périmé ne dit pas son nom tout seul.
func matches_sources(source_root_resolver: Callable) -> bool:
	for table in _source.keys():
		var recorded: Dictionary = _source[table] as Dictionary
		var path: String = str(source_root_resolver.call(str(table)))
		if path == "" or not FileAccess.file_exists(path):
			continue
		if int(FileAccess.get_modified_time(path)) != int(recorded.get("modified", -1)):
			return false
	return true
