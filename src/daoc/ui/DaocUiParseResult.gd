extends RefCounted
class_name DaocUiParseResult

## P1-21C - resultat de lecture d'UN fichier XML d'interface DAoC.
##
## Ne juge rien et ne construit aucun noeud : porte l'arbre lu tel quel plus
## les index utiles. Meme role que `DaocTerrainBuildResult` pour le terrain.

## Chemin absolu du fichier lu, hors du depot.
var source_path: String = ""

## Fenetres declarees dans ce fichier : chaque entree est un `WindowTemplate`.
var windows: Array[Dictionary] = []

## Gabarits d'apparence, par type puis par nom : templates["ButtonTemplate"]["window_close"].
var templates: Dictionary = {}

## Noms de canaux de donnees rencontres, valeur = nombre d'occurrences.
var adapters: Dictionary = {}

## Noms de commandes rencontrees, valeur = nombre d'occurrences.
var events: Dictionary = {}

## Types de controles instancies, par balise `*Def`.
var control_counts: Dictionary = {}

## Valeurs de `WindowId` rencontrees.
var window_ids: PackedStringArray = PackedStringArray()

## Lecture impossible ou XML invalide. Vide = succes.
var errors: Array[String] = []


func is_ok() -> bool:
	return errors.is_empty()


func control_total() -> int:
	var total: int = 0
	for key: String in control_counts:
		total += int(control_counts[key])
	return total


func template_total() -> int:
	var total: int = 0
	for type_name: String in templates:
		total += (templates[type_name] as Dictionary).size()
	return total


func get_debug_snapshot() -> Dictionary:
	return {
		"source": source_path.get_file(),
		"windows": windows.size(),
		"window_ids": window_ids.size(),
		"templates": template_total(),
		"controls": control_total(),
		"adapters": adapters.size(),
		"events": events.size(),
		"errors": errors.size(),
	}
