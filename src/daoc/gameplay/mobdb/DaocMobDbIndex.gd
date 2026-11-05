extends RefCounted
class_name DaocMobDbIndex

## P1-22A — l'index des PNJ, côté JEU.
##
## La moitié en ligne du travail commencé par `DaocMobDbSource` : elle ne lit
## JAMAIS un `.sql`. Elle ouvre le petit index pré-cuit par
## `tools/p1_22a_build_mob_index.gd` — 206 Kio contre 29 Mio — et rend, pour une
## entité de la capture, ce que la base OpenDAoC sait de son homologue.
##
## CE QUE CET INDEX AMÉLIORE VRAIMENT, et rien de plus :
##
##   | valeur                       | avant P1-22A        | avec l'index        |
##   | ---------------------------- | ------------------- | ------------------- |
##   | force, constitution, dext.   | PLACEHOLDER calculé | **valeur de la base** |
##   | portée et niveau d'aggro     | inexistants         | **valeur de la base** |
##   | délai de réapparition        | inexistant          | **valeur de la base** |
##   | rayon d'errance, vitesse     | inexistants         | **valeur de la base** |
##   | type de dégâts au corps      | PLACEHOLDER         | **valeur de la base** |
##   | table de butin               | inexistante         | **nom de la base**  |
##   | **vie maximale**             | PLACEHOLDER         | **PLACEHOLDER**     |
##
## LA VIE MAXIMALE RESTE INVENTÉE, et c'est le point à ne pas laisser filer. La
## règle qui la calcule vit dans le CODE d'OpenDAoC (`GameNPC.MaxHealth`), pas
## dans ses tables ; le dump ne la contient pas. Avoir la vraie constitution ne
## donne pas la vraie formule. `DaocLocalServerVitals.placeholder_max_health`
## garde donc la main, et le dire ici évite qu'un jour on promeuve la valeur
## parce que « maintenant on lit la base ».
##
## LA PROVENANCE VOYAGE AVEC LA VALEUR. Chaque profil rendu porte son `basis` —
## `SPAWN_MATCH`, `MODEL_LEVEL_MATCH`, `MODEL_MATCH` ou `PLACEHOLDER`. Sur les
## 188 PNJ de la capture, DEUX seulement sont un vrai `SPAWN_MATCH` : la capture
## vient d'un serveur français, la base est en anglais, et les deux peuplements
## ne coïncident pas. Un PNJ `MODEL_LEVEL_MATCH` emprunte les chiffres d'un
## autre mob de même apparence et de même niveau. **Ce ne sont pas SES valeurs
## serveur.**

const DEFAULT_INDEX_PATH := "res://data/gameplay/mobdb/p1_22a_mob_index.json"

const BASIS_SPAWN := "SPAWN_MATCH"
const BASIS_MODEL_LEVEL := "MODEL_LEVEL_MATCH"
const BASIS_MODEL := "MODEL_MATCH"
const BASIS_PLACEHOLDER := "PLACEHOLDER"

var loaded: bool = false
var path: String = ""
var error: String = ""

var _by_object_id: Dictionary = {}
var _by_model_level: Dictionary = {}
var _by_model: Dictionary = {}
var _header: Dictionary = {}


## Charge l'index. Un index absent n'est PAS une erreur de jeu : l'arbitre
## retombe alors sur les PLACEHOLDER de P1-21A, exactement comme avant. Le
## drapeau `loaded` dit lequel des deux mondes on habite.
func load_index(index_path: String = DEFAULT_INDEX_PATH) -> bool:
	loaded = false
	error = ""
	path = index_path
	_by_object_id.clear()
	_by_model_level.clear()
	_by_model.clear()
	_header.clear()

	if not FileAccess.file_exists(index_path):
		error = "index absent — lancer tools/p1_22a_build_mob_index.gd"
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		error = "index illisible"
		return false
	var data: Dictionary = parsed as Dictionary
	if str(data.get("checkpoint", "")) != "P1_22A_MOB_DB_INDEX":
		error = "ce fichier n'est pas un index P1-22A"
		return false

	_by_object_id = data.get("by_object_id", {}) as Dictionary
	_by_model_level = data.get("by_model_level", {}) as Dictionary
	for key in _by_model_level:
		var parts := str(key).split(":")
		if parts.size() != 2:
			continue
		var model := int(parts[0])
		var levels: Dictionary = _by_model.get(model, {}) as Dictionary
		levels[int(parts[1])] = str(key)
		_by_model[model] = levels
	_header = {
		"generated_utc": str(data.get("generated_utc", "")),
		"source": data.get("source", {}),
		"capture": data.get("capture", {}),
		"basis_counts": data.get("basis_counts", {}),
		"spawn_match_radius_raw": float(data.get("spawn_match_radius_raw", 0.0)),
	}
	loaded = true
	return true


func header() -> Dictionary:
	return _header.duplicate(true)


func entry_count() -> int:
	return _by_object_id.size()


## Le profil d'une entité de la capture.
##
## Ordre de recherche : l'`object_id` de la capture, puis le couple
## modèle/niveau, puis le modèle seul. Le premier barreau ne vaut que pour la
## capture P1-20E ; les deux suivants existent pour qu'une entité venue d'un
## VRAI serveur, dont l'`object_id` sera autre, se résolve quand même.
##
## Rend toujours un dictionnaire. `basis` vaut `PLACEHOLDER` quand rien n'a été
## trouvé, et `db` est alors vide — c'est le cas des quinze PNJ à modèle moderne
## que la base OpenDAoC ne connaît pas.
func profile_for(entity: Dictionary) -> Dictionary:
	var object_id := int(entity.get("object_id", -1))
	var model := int(entity.get("model_id", -1))
	var level := int(entity.get("level", 0))

	var found: Dictionary = {}
	if _by_object_id.has(str(object_id)):
		found = _by_object_id[str(object_id)] as Dictionary
	else:
		var key := "%d:%d" % [model, level]
		if _by_model_level.has(key):
			found = {"basis": BASIS_MODEL_LEVEL, "db": _by_model_level[key], "model_level_key": key}
		else:
			var levels: Dictionary = _by_model.get(model, {}) as Dictionary
			var best_key := ""
			var best_gap := 1 << 30
			for candidate in levels:
				var gap := absi(int(candidate) - level)
				if gap < best_gap:
					best_gap = gap
					best_key = str(levels[candidate])
			if best_key != "":
				found = {"basis": BASIS_MODEL, "db": _by_model_level[best_key], "model_level_key": best_key}

	return _shape(found, entity)


## Met le profil dans la forme que consomme l'arbitre, sans jamais fabriquer une
## valeur absente : un champ que la base ne donne pas n'apparaît PAS.
func _shape(found: Dictionary, entity: Dictionary) -> Dictionary:
	var out := {
		"basis": BASIS_PLACEHOLDER,
		"resolved": false,
		"db_name": "",
		"stats": {},
		"loot_templates": [],
	}
	if found.is_empty():
		return out
	var db: Dictionary = found.get("db", {}) as Dictionary
	if db.is_empty():
		return out

	# P1-26 — la RACE du spawn, qui porte ses resistances. Zero = aucune.
	out["race"] = int((found.get("db", {}) as Dictionary).get("race", 0))
	out["basis"] = str(found.get("basis", BASIS_PLACEHOLDER))
	out["resolved"] = out["basis"] != BASIS_PLACEHOLDER
	out["db_name"] = str(db.get("db_name", ""))
	out["db_level"] = int(db.get("level", 0))
	out["stats"] = {
		"Strength": float(db.get("strength", 0)),
		"Constitution": float(db.get("constitution", 0)),
		"Dexterity": float(db.get("dexterity", 0)),
		"Quickness": float(db.get("quickness", 0)),
	}
	out["aggro_level"] = int(db.get("aggro_level", 0))
	out["aggro_range_raw"] = int(db.get("aggro_range", 0))
	out["respawn_interval_sec"] = int(db.get("respawn_interval", 0))
	out["roaming_range_raw"] = int(db.get("roaming_range", 0))
	out["speed_raw"] = int(db.get("speed", 0))
	out["melee_damage_type"] = int(db.get("melee_damage_type", 0))
	out["body_type"] = int(db.get("body_type", 0))
	out["faction_id"] = int(db.get("faction_id", 0))
	out["brain"] = str(db.get("brain", ""))
	out["loot_templates"] = found.get("loot_templates", [])
	if found.has("spawn_distance_raw"):
		out["spawn_distance_raw"] = float(found["spawn_distance_raw"])
	if found.has("model_level_key"):
		out["model_level_key"] = str(found["model_level_key"])

	# Une statistique a zero dans la base signifie « non renseignee », pas « nulle ».
	# Un mob a force 0 frapperait comme un decor : on rend la main au PLACEHOLDER
	# plutot que d'imposer un zero qui a l'air d'une donnee serveur.
	var stats: Dictionary = out["stats"] as Dictionary
	var all_zero := true
	for key in stats:
		if float(stats[key]) > 0.0:
			all_zero = false
			break
	if all_zero:
		out["stats"] = {}
		out["stats_unavailable"] = true
	return out
