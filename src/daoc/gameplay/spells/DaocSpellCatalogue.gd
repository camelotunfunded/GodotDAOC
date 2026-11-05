extends RefCounted
class_name DaocSpellCatalogue

## P1-35 — le catalogue de sorts, côté JEU.
##
## Même discipline que `DaocMobDbIndex` et `DaocFactionIndex` : ce fichier ne lit
## JAMAIS un `.sql`. Il ouvre l'index pré-cuit par
## `tools/p1_35_build_spell_index.gd` et remplit le `DaocSpellBook` qui existe
## depuis P1-18B.
##
## POURQUOI CE FICHIER EXISTE PLUTÔT QU'UNE MÉTHODE DE PLUS SUR LE LIVRE. Le
## livre sait déjà charger un TABLEAU de sorts ; l'index, lui, porte en plus les
## lignes de sorts, les empreintes de ses sources et le comptage de couverture.
## Mélanger les deux ferait du livre le propriétaire d'un format de fichier,
## alors qu'il n'est qu'un conteneur.
##
## CE QU'IL FAUT SAVOIR AVANT DE S'EN SERVIR :
##
##   **UN SORT CATALOGUÉ N'EST PAS UN SORT EXÉCUTABLE.** Le dump porte 4151
##   sorts répartis sur 140 `Type` ; le registre P1-18B à P1-18J en couvre 104.
##   **502 sorts, sur 36 types, n'ont aucun gestionnaire** — `PetSpell` (161),
##   `Archery` (92), `DefensiveProc` (41), `Confusion` (36) en tête. Les compter
##   est le contraire d'un aveu : c'est ce qui empêche d'annoncer « les sorts
##   marchent ».
##
##   **LE NIVEAU D'UN SORT N'EST PAS DANS `spell.sql`.** Il vit dans
##   `linexspell`, qui affecte un sort à une LIGNE et à un niveau. Un même sort
##   peut donc appartenir à plusieurs lignes à des niveaux différents, et
##   demander « le niveau du sort 1234 » est une question mal posée.

const DEFAULT_INDEX_PATH := "res://data/gameplay/dol/p1_35_spell_index.json"

const BASIS_DUMP_SPELL := "DUMP_SPELL"

var loaded: bool = false
var error: String = ""
var index_path: String = ""

var _spells: Array = []
var _by_id: Dictionary = {}
var _lines: Dictionary = {}
var _line_defs: Dictionary = {}
var _counts: Dictionary = {}
var _coverage: Dictionary = {}
var _type_counts: Dictionary = {}
var _source: Dictionary = {}
var _load_milliseconds: float = 0.0


func load_index(path: String = DEFAULT_INDEX_PATH) -> bool:
	loaded = false
	error = ""
	index_path = path
	_spells.clear()
	_by_id.clear()
	_lines.clear()
	_line_defs.clear()
	var started := Time.get_ticks_usec()
	if not FileAccess.file_exists(path):
		error = "index absent : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "index illisible : %s" % path
		return false
	var payload := parsed as Dictionary
	if str(payload.get("checkpoint", "")) != "P1_35_SPELL_INDEX":
		error = "ce fichier n'est pas le catalogue de sorts"
		return false
	_spells = payload.get("spells", []) as Array
	_lines = payload.get("lines", {}) as Dictionary
	_line_defs = payload.get("line_defs", {}) as Dictionary
	_counts = payload.get("counts", {}) as Dictionary
	_coverage = payload.get("coverage", {}) as Dictionary
	_type_counts = payload.get("type_counts", {}) as Dictionary
	_source = payload.get("source", {}) as Dictionary
	for index in range(_spells.size()):
		var entry := _spells[index] as Dictionary
		_by_id[int(entry.get("SpellID", 0))] = index
	_load_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
	loaded = not _spells.is_empty()
	if not loaded:
		error = "catalogue vide"
	return loaded


func spell_count() -> int:
	return _spells.size()


func has_spell(spell_id: int) -> bool:
	return _by_id.has(spell_id)


## La ligne brute d'un sort, telle qu'elle sort du dump. Vide si inconnu : aucun
## sort n'est fabriqué pour combler un trou.
func raw_spell(spell_id: int) -> Dictionary:
	if not _by_id.has(spell_id):
		return {}
	return (_spells[int(_by_id[spell_id])] as Dictionary).duplicate(true)


## Les affectations d'une ligne de sorts, triées par niveau croissant.
func line(line_name: String) -> Array:
	return (_lines.get(line_name, []) as Array).duplicate(true)


func line_names() -> Array:
	var names: Array = _lines.keys()
	names.sort()
	return names


func line_definition(line_name: String) -> Dictionary:
	return (_line_defs.get(line_name, {}) as Dictionary).duplicate(true)


## Les sorts d'une ligne utilisables à ce niveau, du plus haut niveau au plus
## bas — l'ordre dans lequel on cherche « le meilleur que je sache lancer ».
##
## LE NIVEAU DEMANDÉ EST CELUI DE LA SPÉCIALISATION, pas celui du personnage :
## c'est `linexspell.Level` qui est comparé, et il décrit à quel niveau de ligne
## le sort s'ouvre.
func spells_up_to_level(line_name: String, level: int) -> Array:
	var out: Array = []
	for value in line(line_name):
		var entry := value as Dictionary
		if int(entry.get("level", 0)) <= level:
			out.append(entry)
	out.reverse()
	return out


## Remplit un `DaocSpellBook` avec tout le catalogue.
##
## Le livre accepte déjà les noms de colonnes du dump — `SpellID`, `Type`,
## `Damage` — donc rien n'est traduit en route. Un traducteur intermédiaire
## serait un endroit de plus où une valeur peut se perdre sans bruit.
func fill_spell_book(book: DaocSpellBook) -> Dictionary:
	if book == null:
		return {"ok": false, "error": "aucun livre de sorts"}
	if not loaded:
		return {"ok": false, "error": error if error != "" else "catalogue non charge"}
	book.load_from_array(_spells)
	return {
		"ok": true,
		"loaded": book.spells_by_id.size(),
		"types": book.spells_by_type.size(),
		"basis": BASIS_DUMP_SPELL,
	}


func describe() -> Dictionary:
	return {
		"ok": loaded,
		"error": error,
		"index_path": index_path,
		"basis": BASIS_DUMP_SPELL,
		"counts": _counts.duplicate(true),
		"coverage": _coverage.duplicate(true),
		"source": _source.duplicate(true),
		"load_milliseconds": _load_milliseconds,
	}


## Les types que le dump déclare et que le registre ne couvre pas, du plus
## peuplé au moins peuplé. Répété ici pour qu'un rapport de session porte le
## reste-à-faire sans rouvrir l'index.
func unsupported_backlog() -> Array:
	return (_coverage.get("backlog", []) as Array).duplicate(true)


func type_count(spell_type: String) -> int:
	return int(_type_counts.get(spell_type, 0))
