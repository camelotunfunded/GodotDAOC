extends RefCounted
class_name DaocFactionIndex

## P1-34 — l'index des factions, côté JEU.
##
## Même discipline que `DaocMobDbIndex` : ce fichier ne lit JAMAIS un `.sql`. Il
## ouvre l'index pré-cuit par `tools/p1_34_build_faction_index.gd` — 278
## factions et 313 liens ami/ennemi — et rend ce que la base sait d'une faction.
##
## CE QU'IL APPORTE, ET CE QU'IL N'APPORTE PAS :
##
##   | valeur                          | avant P1-34   | avec l'index         |
##   | ------------------------------- | ------------- | -------------------- |
##   | hostilité d'une faction         | inexistante   | **`BaseAggroLevel`** |
##   | factions ennemies / amies       | inexistantes  | **313 liens**        |
##   | réputation d'un PERSONNAGE      | inexistante   | **toujours absente** |
##
## LA DERNIÈRE LIGNE EST LE CONSTAT DU JALON. `factionaggrolevel` porte la
## réputation personnelle d'un personnage, sa clé est `CharacterID`, et le dump
## en contient **zéro ligne** — un dump sans personnages n'en a aucune. Le
## projet annonçait pourtant depuis P1-22D que c'était CE fichier qui manquait
## pour qu'un PNJ ait une cible. C'était faux deux fois : il est vide, et ce
## n'est de toute façon pas lui qui relie deux factions — c'est `linkedfaction`.
##
## L'aggro d'une faction envers un joueur inconnu est donc entièrement
## disponible ; l'historique personnel, lui, n'existera que le jour où une vraie
## partie en produira un.

const DEFAULT_INDEX_PATH := "res://data/gameplay/dol/p1_34_faction_index.json"

const BASIS_DUMP_FACTION := "DUMP_FACTION"

var loaded: bool = false
var error: String = ""
var index_path: String = ""

var _factions: Dictionary = {}
var _link_counts: Dictionary = {}
var _source: Dictionary = {}
var _reputation_rows: int = 0
var _reputation_state: String = "UNKNOWN"


func load_index(path: String = DEFAULT_INDEX_PATH) -> bool:
	loaded = false
	error = ""
	index_path = path
	_factions.clear()
	if not FileAccess.file_exists(path):
		error = "index absent : %s" % path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "index illisible : %s" % path
		return false
	var payload := parsed as Dictionary
	if str(payload.get("checkpoint", "")) != "P1_34_FACTION_INDEX":
		error = "ce fichier n'est pas l'index des factions"
		return false
	_factions = payload.get("factions", {}) as Dictionary
	_link_counts = payload.get("link_counts", {}) as Dictionary
	_source = payload.get("source", {}) as Dictionary
	_reputation_rows = int(payload.get("character_reputation_rows", 0))
	_reputation_state = str(payload.get("character_reputation_state", "UNKNOWN"))
	loaded = not _factions.is_empty()
	if not loaded:
		error = "index vide"
	return loaded


func known(faction_id: int) -> bool:
	return _factions.has(str(faction_id))


## Le profil d'une faction. Un identifiant ZÉRO est une ABSENCE de faction, pas
## la faction numéro zéro : il rend VIDE, exactement comme `resists_for_id(0)` en
## P1-26. Lui donner « les valeurs de la faction 0 » serait une invention
## silencieuse, et 0 est la valeur par défaut de la colonne `mob.FactionID`.
func profile(faction_id: int) -> Dictionary:
	if faction_id <= 0 or not known(faction_id):
		return {}
	return (_factions[str(faction_id)] as Dictionary).duplicate(true)


func base_aggro_level(faction_id: int) -> int:
	var entry := profile(faction_id)
	return int(entry.get("base_aggro_level", 0)) if not entry.is_empty() else 0


func enemies_of(faction_id: int) -> Array:
	var entry := profile(faction_id)
	return (entry.get("enemies", []) as Array) if not entry.is_empty() else []


func friends_of(faction_id: int) -> Array:
	var entry := profile(faction_id)
	return (entry.get("friends", []) as Array) if not entry.is_empty() else []


func name_of(faction_id: int) -> String:
	var entry := profile(faction_id)
	return str(entry.get("name", "")) if not entry.is_empty() else ""


## Deux factions sont-elles déclarées ennemies ?
##
## LE LIEN N'EST PAS SYMÉTRIQUE, ni dans le dump ni dans DOL : `AddEnemyFaction`
## n'est appelée que dans un sens. La question porte donc sur un SENS — « A
## considère-t-elle B comme ennemie » — et la réciproque peut être fausse. La
## symétriser ici inventerait 242 relations que la base ne déclare pas.
func considers_enemy(faction_id: int, other_faction_id: int) -> bool:
	return other_faction_id > 0 and enemies_of(faction_id).has(other_faction_id)


func considers_friend(faction_id: int, other_faction_id: int) -> bool:
	return other_faction_id > 0 and friends_of(faction_id).has(other_faction_id)


func describe() -> Dictionary:
	return {
		"ok": loaded,
		"error": error,
		"index_path": index_path,
		"basis": BASIS_DUMP_FACTION,
		"factions": _factions.size(),
		"link_counts": _link_counts.duplicate(true),
		"source": _source.duplicate(true),
		# Répété ici pour qu'un rapport de session porte le constat sans qu'on
		# ait à rouvrir le dump.
		"character_reputation_rows": _reputation_rows,
		"character_reputation_state": _reputation_state,
	}
