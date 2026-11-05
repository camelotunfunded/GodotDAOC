extends RefCounted
class_name DaocStyleIndex

## P1-29 — le catalogue des styles de mêlée, lu dans l'index pré-cuit.
##
## `DaocStyleProcessor` existe depuis P1-18B et n'a **jamais eu un seul style à
## exécuter** : aucun catalogue n'était chargé. Le voici — 1199 styles, 23
## spécialisations, la table entière parce qu'elle ne pèse que 152 Kio.
##
## CE QU'UN PERSONNAGE PEUT RÉELLEMENT EXÉCUTER dépend de son niveau de
## spécialisation, et c'est P1-27 qui l'a rendu connaissable pour les
## spécialisations auto-entraînées. Pour toutes les autres, le niveau vaut 1 et
## `styles_for_spec` ne rend donc que les styles de niveau 1 — ce qui est exact,
## pas une restriction inventée.

const INDEX_PATH := "res://data/gameplay/dol/p1_29_style_index.json"

const BASIS_DUMP_STYLE := "DUMP_STYLE"

## `Style.eOpening` — les trois familles d'enchaînement.
const OPENING_OFFENSIVE := 0
const OPENING_DEFENSIVE := 1
const OPENING_POSITIONAL := 2

## `Style.eOpeningPosition` — Style.cs:56-70. BACK VAUT ZERO, ce qui compte :
## une valeur non renseignee et « dans le dos » sont le meme entier.
const POSITION_BACK := 0
const POSITION_SIDE := 1
const POSITION_FRONT := 2

## P1-31 — `Style.eAttackResultRequirement`, Style.cs:75-100. L'index garde ces
## champs en ENTIERS, comme P1-29 l'a decide ; il faut donc les traduire au
## moment de construire un `DaocStyleDef`, dont les champs sont des CHAINES.
##
## SANS CETTE TRADUCTION, AUCUN STYLE N'EST JAMAIS EXECUTABLE, et le defaut est
## silencieux : `str(0)` vaut « 0 », qui n'est pas « Any », donc `can_use_style`
## exige que le coup precedent ait rendu un resultat nomme « 0 » — ce qui
## n'arrive jamais. Tous les styles auraient ete refuses, avec un motif exact et
## trompeur : « attack result requirement not met ».
const ATTACK_RESULT_BY_ID := {
	0: DaocCombatEnums.RESULT_ANY,
	1: DaocCombatEnums.RESULT_MISSED,
	2: DaocCombatEnums.RESULT_HIT_UNSTYLED,
	3: DaocCombatEnums.RESULT_PARRIED,
	4: DaocCombatEnums.RESULT_BLOCKED,
	5: DaocCombatEnums.RESULT_EVADED,
	6: DaocCombatEnums.RESULT_FUMBLED,
	7: DaocCombatEnums.RESULT_HIT_STYLE,
}

const OPENING_NAME_BY_ID := {
	OPENING_OFFENSIVE: "offensive",
	OPENING_DEFENSIVE: "defensive",
	OPENING_POSITIONAL: "positional",
}

const POSITION_NAME_BY_ID := {
	POSITION_BACK: "back",
	POSITION_SIDE: "side",
	POSITION_FRONT: "front",
}


## Traduit une entree d'index en `DaocStyleDef` executable.
##
## `DaocStyleDef.from_dict` seul ne suffit PAS : il recopie les entiers tels
## quels dans des champs qui attendent des chaines. Ce traducteur est le seul
## endroit qui connaisse les enums de `Style.cs`, et il y a une raison de le
## garder ici plutot que dans `from_dict` : l'index est la seule source qui
## produise ces entiers.
static func style_def_from_entry(entry: Dictionary) -> DaocStyleDef:
	var translated: Dictionary = entry.duplicate(true)
	var result_id: int = int(entry.get("attack_result_requirement", 0))
	translated["attack_result_requirement"] = str(
		ATTACK_RESULT_BY_ID.get(result_id, DaocCombatEnums.RESULT_ANY))
	var opening_id: int = int(entry.get("opening_requirement_type", OPENING_OFFENSIVE))
	translated["opening_requirement_type"] = str(
		OPENING_NAME_BY_ID.get(opening_id, "offensive"))
	return DaocStyleDef.from_dict(translated)


## Le nom de la position exigee par un style POSITIONNEL, vide sinon.
##
## `DaocStyleProcessor.can_use_style` compare `opening_requirement_value` a « 1 »
## pour le dos et « 2 » pour le flanc. C'EST DECALE D'UN CRAN : la source dit
## Back = 0, Side = 1, Front = 2 (Style.cs:56-70). Un style « dans le dos » etait
## donc exigible de face, et un style de flanc jamais executable. Le processeur
## lit desormais ce nom au lieu de comparer des chiffres.
static func required_position(entry: Dictionary) -> String:
	if int(entry.get("opening_requirement_type", OPENING_OFFENSIVE)) != OPENING_POSITIONAL:
		return ""
	return str(POSITION_NAME_BY_ID.get(int(entry.get("opening_requirement_value", POSITION_BACK)), ""))

var loaded: bool = false
var error: String = ""

var _by_spec: Dictionary = {}
var _source: Dictionary = {}
var _count: int = 0


func load_index(path: String = INDEX_PATH) -> bool:
	loaded = false
	error = ""
	if not FileAccess.file_exists(path):
		error = "catalogue absent : %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "catalogue illisible : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "catalogue mal formé"
		return false
	var payload: Dictionary = parsed as Dictionary
	_source = payload.get("source", {}) as Dictionary
	_by_spec = payload.get("by_spec", {}) as Dictionary
	_count = 0
	for spec in _by_spec:
		_count += (_by_spec[spec] as Array).size()
	loaded = _count > 0
	if not loaded:
		error = "catalogue vide"
	return loaded


func style_count() -> int:
	return _count


func spec_count() -> int:
	return _by_spec.size()


func spec_names() -> Array:
	var out: Array = _by_spec.keys()
	out.sort()
	return out


## Tous les styles d'une spécialisation, quel que soit le niveau requis.
func all_styles_for_spec(spec_name: String) -> Array:
	var out: Array = []
	for value in (_by_spec.get(spec_name, []) as Array):
		out.append((value as Dictionary).duplicate())
	return out


## Les styles qu'un personnage de ce niveau de spécialisation peut EXÉCUTER.
##
## UN NIVEAU DE SPÉ DE 1 NE DONNE QUE LES STYLES DE NIVEAU 1, et c'est exact :
## le reste s'achète avec des points de spécialisation, et ce qu'un personnage a
## dépensé n'est nulle part sur ce disque.
func styles_for_spec(spec_name: String, spec_level: int) -> Array:
	var out: Array = []
	for value in (_by_spec.get(spec_name, []) as Array):
		var entry: Dictionary = value as Dictionary
		if int(entry.get("spec_level_requirement", 0)) <= spec_level:
			out.append(entry.duplicate())
	return out


## Un style par son nom, dans une spécialisation. Rend VIDE s'il n'existe pas —
## jamais un style par défaut, qui serait une invention.
func style_by_name(spec_name: String, style_name: String) -> Dictionary:
	for value in (_by_spec.get(spec_name, []) as Array):
		var entry: Dictionary = value as Dictionary
		if str(entry.get("name", "")) == style_name:
			return entry.duplicate()
	return {}


func matches_sources(source_root_resolver: Callable) -> bool:
	for table in _source.keys():
		var recorded: Dictionary = _source[table] as Dictionary
		var path: String = str(source_root_resolver.call(str(table)))
		if path == "" or not FileAccess.file_exists(path):
			continue
		if int(FileAccess.get_modified_time(path)) != int(recorded.get("modified", -1)):
			return false
	return true
