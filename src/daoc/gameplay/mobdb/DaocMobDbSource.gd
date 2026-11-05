extends RefCounted
class_name DaocMobDbSource

## P1-22A — la lecture des dumps `.sql` d'OpenDAoC, ligne par ligne.
##
## POURQUOI CE FICHIER EXISTE. `DaocLocalServerVitals` porte depuis P1-21A trois
## TODO qui disent la même chose : « remplacer par la vraie règle OpenDAoC dès
## que les sources sont sur le disque ». Elles y sont — 70 Mio de dumps sous
## `tools-mini projets/server_dumps/opendaoc/opendaoc-db-core` — mais
## `mob.sql` pèse 29 Mio et personne ne charge 29 Mio au démarrage d'une partie.
##
## Ce fichier est donc la moitié HORS LIGNE du travail : il sait lire les dumps,
## il ne les lit qu'en outil, et ce qui entre dans le jeu est le petit index
## pré-cuit qu'il produit. C'est exactement le motif du cache de splat du
## terrain, et il porte le même piège : **un index périmé ne dit pas son nom.**
## D'où l'empreinte du fichier source inscrite dans l'index, et vérifiée.
##
## LA LETTRE DE LECTEUR. Le dossier des dumps vit à côté du projet, pas dedans.
## La règle est celle de `DaocClientRoot`, et pour la même raison : le disque
## s'appelle `D:` sur une machine et `E:` sur l'autre. Voir §3.1 du relais.
##
## CE QU'IL NE FAIT PAS. Il ne comprend pas le SQL. Il reconnaît la forme exacte
## que `mysqldump` écrit — un `REPLACE INTO` puis une ligne par n-uplet — et
## rien d'autre. Une autre forme de dump rendrait zéro ligne, ce qui est un
## échec bruyant côté outil et jamais côté jeu.

const ClientRootScript = preload("res://src/daoc/DaocClientRoot.gd")

## Le nom du dossier des dumps dans l'arborescence du projet.
const DUMP_FOLDER := "tools-mini projets/server_dumps/opendaoc/opendaoc-db-core"

## La variable d'environnement qui gagne sur le voisinage, pour un dump rangé
## ailleurs. Même rôle que `DAOC_CLIENT_ROOT` pour le client.
const DUMP_ENV_VAR := "OPENDAOC_DB_ROOT"


## Le dossier des dumps, ou une chaîne vide s'il est introuvable.
##
## Ordre, calqué sur `DaocClientRoot` : le chemin configuré s'il existe, le même
## relettré, la variable d'environnement telle quelle, la variable relettrée,
## puis le voisinage de `res://`. **On ne « corrige » jamais un chemin qui
## marche.**
static func dump_root(configured: String = "") -> String:
	for candidate in _dump_root_candidates(configured):
		if candidate != "" and DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""


static func _dump_root_candidates(configured: String) -> Array:
	var out: Array = []
	var configured_clean := configured.replace("\\", "/").strip_edges().trim_suffix("/")
	if configured_clean != "":
		out.append(configured_clean)
		out.append(ClientRootScript.with_project_drive(configured_clean))
	var from_env := OS.get_environment(DUMP_ENV_VAR).replace("\\", "/").strip_edges().trim_suffix("/")
	if from_env != "":
		out.append(from_env)
		out.append(ClientRootScript.with_project_drive(from_env))
	var neighbourhood: String = ClientRootScript.project_neighbourhood()
	if neighbourhood != "":
		out.append(neighbourhood.path_join(DUMP_FOLDER))
	return out


## Le chemin d'une table, ou une chaîne vide. `table` est le nom du fichier sans
## extension : `mob`, `loottemplate`, `itemtemplate`.
static func table_path(table: String, configured_root: String = "") -> String:
	var root := dump_root(configured_root)
	if root == "":
		return ""
	var path := root.path_join("%s.sql" % table)
	return path if FileAccess.file_exists(path) else ""


# --------------------------------------------------------------------------
# Lecture
# --------------------------------------------------------------------------

## Les colonnes déclarées par le premier `REPLACE INTO` du fichier.
##
## On ne les écrit PAS en dur : un dump plus récent qui ajoute une colonne
## décalerait silencieusement toutes les suivantes, et un index faux ne lève
## aucune erreur — il rend des niveaux et des dégâts plausibles. Les noms sont
## donc lus dans le fichier, et les champs demandés sont retrouvés par NOM.
static func read_columns(path: String) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var columns := PackedStringArray()
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("REPLACE INTO "):
			continue
		var open_paren := line.find("(")
		var close_paren := line.find(")", open_paren)
		if open_paren < 0 or close_paren < 0:
			continue
		for raw in line.substr(open_paren + 1, close_paren - open_paren - 1).split(","):
			columns.append(raw.strip_edges().trim_prefix("`").trim_suffix("`"))
		break
	file.close()
	return columns


## Parcourt les n-uplets d'une table et appelle `row_callback` pour chacun.
##
## Le rappel reçoit un `Dictionary` limité à `wanted_columns` — jamais la ligne
## entière. C'est ce qui rend `mob.sql` lisible sans le tenir en mémoire : à
## aucun moment plus d'une ligne de texte n'existe.
##
## Le rappel rend `true` pour continuer, `false` pour arrêter la lecture.
##
## Rend un rapport : lignes vues, lignes retenues, colonnes manquantes.
static func stream_rows(path: String, wanted_columns: Array, row_callback: Callable,
		options: Dictionary = {}) -> Dictionary:
	var report := {
		"ok": false, "path": path, "rows_seen": 0, "rows_kept": 0,
		"rows_malformed": 0,
		"columns": PackedStringArray(), "missing_columns": PackedStringArray(),
		"error": "",
	}
	if path == "" or not FileAccess.file_exists(path):
		report["error"] = "dump introuvable"
		return report

	var columns := read_columns(path)
	report["columns"] = columns
	if columns.is_empty():
		report["error"] = "aucun REPLACE INTO — forme de dump inattendue"
		return report

	var indices: Dictionary = {}
	var missing := PackedStringArray()
	for wanted in wanted_columns:
		var name := str(wanted)
		var index := -1
		for i in columns.size():
			if columns[i].to_lower() == name.to_lower():
				index = i
				break
		if index < 0:
			missing.append(name)
		else:
			indices[name] = index
	report["missing_columns"] = missing
	if not missing.is_empty():
		report["error"] = "colonnes absentes du dump : %s" % ", ".join(missing)
		return report

	var max_rows: int = int(options.get("max_rows", 0))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		report["error"] = "lecture impossible"
		return report

	var rows_seen := 0
	var rows_malformed := 0
	var rows_kept := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.begins_with("("):
			continue
		var values := split_values(line)
		if values.size() != columns.size():
			# Un n-uplet dont le compte ne tombe pas juste est ecarte plutot que
			# devine : une valeur decalee produirait un mob credible et faux.
			# Il est COMPTE : un rejet muet ferait passer un dump mal lu pour un
			# dump pauvre.
			rows_malformed += 1
			continue
		rows_seen += 1
		var row: Dictionary = {}
		for name in indices:
			row[name] = values[int(indices[name])]
		if row_callback.call(row):
			rows_kept += 1
		if max_rows > 0 and rows_seen >= max_rows:
			break
	file.close()

	report["ok"] = true
	report["rows_seen"] = rows_seen
	report["rows_kept"] = rows_kept
	report["rows_malformed"] = rows_malformed
	return report


## Découpe un n-uplet `('a', 1, NULL),` en valeurs brutes.
##
## Les apostrophes sont respectées : `'Ylaine\'s guard'` reste une valeur, et
## une virgule dans un nom ne coupe rien. `NULL` devient une chaîne vide — le
## dump n'en distingue pas l'absence de la vacuité pour ce qui nous intéresse.
static func split_values(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var text := line.strip_edges()
	var start := text.find("(")
	if start < 0:
		return out
	var i := start + 1
	var current := ""
	var in_quotes := false
	var was_quoted := false
	var depth := 1
	while i < text.length():
		var c := text[i]
		if in_quotes:
			if c == "\\" and i + 1 < text.length():
				var next := text[i + 1]
				# `\'` et `\\` sont les seules echappes que mysqldump ecrit ici ;
				# `\n` et consorts sont conserves tels quels, on ne les affiche
				# jamais.
				current += next
				i += 2
				continue
			if c == "'":
				in_quotes = false
				i += 1
				continue
			current += c
			i += 1
			continue
		match c:
			"'":
				in_quotes = true
				was_quoted = true
			"(":
				depth += 1
				current += c
			")":
				depth -= 1
				if depth == 0:
					out.append(_finish_value(current, was_quoted))
					return out
				current += c
			",":
				out.append(_finish_value(current, was_quoted))
				current = ""
				was_quoted = false
			_:
				current += c
		i += 1
	return out


## Un `NULL` NON ENTRE APOSTROPHES est l'absence de valeur ; `'NULL'` entre
## apostrophes est la chaine de quatre lettres, et `mob.sql` en porte
## reellement. Confondre les deux ferait apparaitre le mot NULL comme nom de
## cervelle ou d'equipement — ce qu'on a vu au premier jet.
static func _finish_value(raw: String, was_quoted: bool) -> String:
	var value := raw.strip_edges()
	if not was_quoted and value.to_upper() == "NULL":
		return ""
	return value


## L'empreinte d'un dump, pour qu'un index sache s'il est périmé.
##
## Taille et date de modification, pas un hachage : hacher 29 Mio à chaque
## contrôle coûterait plus que ce que l'index fait gagner, et ces deux valeurs
## suffisent à attraper le seul cas qui nous menace — un dump remplacé.
static func fingerprint(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "size": 0, "modified": 0}
	return {
		"ok": true,
		"path": path.get_file(),
		"size": _file_size(path),
		"modified": FileAccess.get_modified_time(path),
	}


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := int(file.get_length())
	file.close()
	return size
