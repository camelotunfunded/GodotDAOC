extends RefCounted
class_name DaocUiSkinContract

## P1-21C - contrat d'interface releve sur UN skin du client d'origine.
##
## Agrege les 67 fichiers de `ui/isles/` et repond a la seule question qui
## engage le portage : quels NOMS le moteur doit-il reconnaitre ?
##
## Trois registres sont figes cote moteur et doivent etre reimplementes tels
## quels : `WindowId`, les adaptateurs et les commandes. Les respecter rend
## lisibles les skins DAoC existants sans les retoucher.
##
## PROVENANCE, au sens de `DaocLocalServerVitals` :
##   CAPTURE     tout ce que porte ce contrat - lu dans les fichiers du client
##   PLACEHOLDER aucun. Rien n'est complete ni suppose.
##
## Ce qu'un fichier XML ne dit PAS, et qui n'est donc pas ici : le sens de
## poussee des valeurs, et l'unite de chaque adaptateur. Les jauges recoivent
## un pourcentage - aucune balise `Max`, `Range` ou `Total` n'existe dans le
## format, donc une barre ne peut pas connaitre son maximum.

const PROVENANCE: String = "CAPTURE"

## Racine `ui/` du client, hors depot.
var ui_root: String = ""

## Nom du skin lu, par exemple `isles`.
var skin: String = ""

## Un resultat par fichier, dans l'ordre alphabetique.
var files: Array[DaocUiParseResult] = []

## Nom de canal -> nombre d'occurrences, tous fichiers confondus.
var adapters: Dictionary = {}

## Nom de commande -> nombre d'occurrences. La casse d'origine est conservee.
var events: Dictionary = {}

## Identifiants de fenetre declares par le skin.
var window_ids: PackedStringArray = PackedStringArray()

## Balise `*Def` -> nombre d'instances.
var control_counts: Dictionary = {}

## Balise `*Template` -> nombre de gabarits.
var template_counts: Dictionary = {}

## Fichiers listes par `uimain.xml` et absents du disque.
var missing_includes: PackedStringArray = PackedStringArray()

## Fichiers illisibles ou XML invalide.
var errors: Array[String] = []


## Lit un skin entier. `ui_root_path` pointe le dossier `ui/` du client.
static func read(ui_root_path: String, skin_name: String) -> DaocUiSkinContract:
	var contract: DaocUiSkinContract = DaocUiSkinContract.new()
	contract.ui_root = ui_root_path
	contract.skin = skin_name

	var skin_dir: String = ui_root_path.path_join(skin_name)
	if not DirAccess.dir_exists_absolute(skin_dir):
		contract.errors.append("skin introuvable : %s" % skin_dir)
		return contract

	contract.files = DaocUiXmlParser.parse_directory(skin_dir)
	for result: DaocUiParseResult in contract.files:
		contract._absorb(result)
	contract._check_includes(skin_dir)
	return contract


## Les commandes sont dispatchees SANS tenir compte de la casse : `ShowWarMap`
## et `ShowWarmap` coexistent dans des skins qui fonctionnent. Cette vue replie
## donc les variantes sur une seule entree.
func events_case_folded() -> Dictionary:
	var folded: Dictionary = {}
	for name: String in events:
		var key: String = name.to_lower()
		folded[key] = int(folded.get(key, 0)) + int(events[name])
	return folded


## Familles d'adaptateurs : les suites indexees comme `group_health0..7` sont
## repliees sur `group_health#`, ce qui donne le modele de donnees reel.
func adapter_families() -> Dictionary:
	var families: Dictionary = {}
	var digits: RegEx = RegEx.new()
	digits.compile("[0-9]+")
	for name: String in adapters:
		var family: String = digits.sub(name, "#", true)
		families[family] = int(families.get(family, 0)) + int(adapters[name])
	return families


## Tous les gabarits du skin, type -> nom -> gabarit. Ils sont declares dans
## `styles.xml` mais cites depuis n'importe quelle fenetre : la table doit donc
## etre fusionnee avant toute construction.
func merged_templates() -> Dictionary:
	var merged: Dictionary = {}
	for result: DaocUiParseResult in files:
		for type_name: String in result.templates:
			if not merged.has(type_name):
				merged[type_name] = {}
			var target: Dictionary = merged[type_name]
			var source: Dictionary = result.templates[type_name]
			for name: String in source:
				target[name] = source[name]
	return merged


## Retrouve une fenetre par son `Name` ou par son `WindowId`, sans distinction
## de casse. Renvoie un Dictionary vide si elle n'existe pas.
func find_window(name_or_id: String) -> Dictionary:
	var wanted: String = name_or_id.strip_edges().to_lower()
	if wanted == "":
		return {}
	for result: DaocUiParseResult in files:
		for window: Dictionary in result.windows:
			if str(window.get("Name", "")).strip_edges().to_lower() == wanted:
				return window
			if str(window.get("WindowId", "")).strip_edges().to_lower() == wanted:
				return window
	return {}


func is_ok() -> bool:
	return errors.is_empty() and missing_includes.is_empty()


func window_total() -> int:
	var total: int = 0
	for result: DaocUiParseResult in files:
		total += result.windows.size()
	return total


func get_debug_snapshot() -> Dictionary:
	return {
		"provenance": PROVENANCE,
		"skin": skin,
		"files": files.size(),
		"windows": window_total(),
		"window_ids": window_ids.size(),
		"adapters": adapters.size(),
		"adapter_families": adapter_families().size(),
		"events": events.size(),
		"events_folded": events_case_folded().size(),
		"controls": _sum(control_counts),
		"templates": _sum(template_counts),
		"missing_includes": missing_includes.size(),
		"errors": errors.size(),
	}


# ---------------------------------------------------------------------------

func _absorb(result: DaocUiParseResult) -> void:
	for message: String in result.errors:
		errors.append(message)
	for name: String in result.adapters:
		adapters[name] = int(adapters.get(name, 0)) + int(result.adapters[name])
	for name: String in result.events:
		events[name] = int(events.get(name, 0)) + int(result.events[name])
	for tag: String in result.control_counts:
		control_counts[tag] = int(control_counts.get(tag, 0)) + int(result.control_counts[tag])
	for type_name: String in result.templates:
		var count: int = (result.templates[type_name] as Dictionary).size()
		template_counts[type_name] = int(template_counts.get(type_name, 0)) + count
	for window_id: String in result.window_ids:
		if not window_ids.has(window_id):
			window_ids.append(window_id)


## `uimain.xml` liste les fenetres que le skin charge reellement. Un fichier
## annonce mais absent est un trou : il doit se voir, pas se deviner au runtime.
func _check_includes(skin_dir: String) -> void:
	var main_path: String = skin_dir.path_join("uimain.xml")
	if not FileAccess.file_exists(main_path):
		return
	var parsed: DaocUiParseResult = DaocUiXmlParser.parse_file(main_path)
	if not parsed.is_ok():
		return
	var listed: PackedStringArray = _includes_of(main_path)
	for name: String in listed:
		if not FileAccess.file_exists(skin_dir.path_join(name)):
			missing_includes.append(name)


## `<Include>` n'apparait pas dans l'arbre indexe : il est relu ici a plat.
func _includes_of(main_path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(main_path, FileAccess.READ)
	if file == null:
		return names
	var text: String = file.get_as_text()
	file.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("<Include>([^<]+)</Include>")
	for found: RegExMatch in pattern.search_all(text):
		var name: String = found.get_string(1).strip_edges()
		if name != "":
			names.append(name)
	return names


func _sum(bag: Dictionary) -> int:
	var total: int = 0
	for key: String in bag:
		total += int(bag[key])
	return total


## P1-134 — par `Name` SEULEMENT. `find_window("merchant")` rendait la fenetre
## de hookpoint_merchant_window.xml, dont le WindowId est aussi « Merchant » et
## qui est lue avant merchant_window.xml.
func find_window_named(name: String) -> Dictionary:
	var wanted: String = name.strip_edges().to_lower()
	for result: DaocUiParseResult in files:
		for window: Dictionary in result.windows:
			if str(window.get("Name", "")).strip_edges().to_lower() == wanted:
				return window
	return {}
