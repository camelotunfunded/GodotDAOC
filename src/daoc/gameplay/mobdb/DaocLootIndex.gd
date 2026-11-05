extends RefCounted
class_name DaocLootIndex

## P1-22C — l'index de butin, côté JEU.
##
## Même partage qu'à P1-22A : l'outil lit les 14 Mio d'`itemtemplate.sql`, le jeu
## ouvre les 6 Kio qu'il en reste. Ne retenir que les objets réellement
## atteignables depuis un PNJ de la capture est ce qui rend l'écart possible.
##
## Un index absent n'est PAS une panne : les cadavres n'auront alors que leur
## argent, et le rapport le dira.

const DEFAULT_INDEX_PATH := "res://data/gameplay/mobdb/p1_22c_loot_index.json"

var loaded: bool = false
var path: String = ""
var error: String = ""

var _templates: Dictionary = {}
var _items: Dictionary = {}
var _header: Dictionary = {}


func load_index(index_path: String = DEFAULT_INDEX_PATH) -> bool:
	loaded = false
	error = ""
	path = index_path
	_templates.clear()
	_items.clear()
	_header.clear()

	if not FileAccess.file_exists(index_path):
		error = "index absent — lancer tools/p1_22c_build_loot_index.gd"
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		error = "index illisible"
		return false
	var data: Dictionary = parsed as Dictionary
	if str(data.get("checkpoint", "")) != "P1_22C_LOOT_INDEX":
		error = "ce fichier n'est pas un index P1-22C"
		return false
	_templates = data.get("templates", {}) as Dictionary
	_items = data.get("items", {}) as Dictionary
	_header = {
		"generated_utc": str(data.get("generated_utc", "")),
		"source": data.get("source", {}),
		"missing_item_templates": data.get("missing_item_templates", []),
	}
	loaded = true
	return true


func header() -> Dictionary:
	return _header.duplicate(true)


func templates() -> Dictionary:
	return _templates


func items() -> Dictionary:
	return _items


func template_count() -> int:
	return _templates.size()


func item_count() -> int:
	return _items.size()


## Vrai si au moins une des tables citées existe réellement dans l'index.
##
## C'est la question utile pour un cadavre : « ce mob a-t-il une table, ou
## seulement un nom de table ? » — et sur les 28 noms cités par la capture,
## quatre seulement sont des tables.
func has_any_table(names: Array) -> bool:
	for value in names:
		var name: String = str((value as Dictionary).get("template", value))
		if _templates.has(name):
			return true
	return false
