@tool
## scan_nifs.gd — diagnostic global multi-dossiers.
## Ouvrir ce fichier dans l'éditeur, puis Fichier > Exécuter (Ctrl+Maj+X).
##
## Lit daoc_client_root depuis les ProjectSettings (même clé que ZoneViewer).
## Si la clé n'est pas définie, affiche une erreur claire.
##
## Parcourt tous les .nif des dossiers nifs/ du client (récursif),
## tente de les lire avec NifReader, et produit :
##   1) un CSV (un .nif par ligne) : statut, version, bloc suspect, offset
##   2) un résumé agrégé en console
##   3) un dump hexa du premier exemple de chaque bloc suspect
##   4) un log texte des échecs uniquement
extends EditorScript

## Clé ProjectSettings où ZoneViewer stocke le chemin racine DAoC.
## Si tu utilises un nom différent dans ton projet, modifie cette constante.
const SETTINGS_KEY := "daoc/client_root"

## Sous-dossiers nifs/ à scanner sous la racine client.
const NIF_SUBDIRS: Array[String] = [
	"zones/nifs",
	"frontiers/nifs",
	"phousing/nifs",
	"tutorial/zones/nifs",
]

const OUT_CSV  := "res://reports/prebake_nif/scan_nifs_report.csv"
const HEX_DUMP := "res://reports/prebake_nif/scan_nifs_hexdump.txt"
const OUT_LOG  := "res://reports/prebake_nif/scan_nifs_log.txt"

## 0 = tous les fichiers. Ex. 200 pour un test rapide.
const LIMIT := 0


func _get_daoc_root() -> String:
	# Priorité 1 : ProjectSettings (clé sauvegardée)
	if ProjectSettings.has_setting(SETTINGS_KEY):
		var v := str(ProjectSettings.get_setting(SETTINGS_KEY)).strip_edges().replace("\\", "/")
		while v.ends_with("/"):
			v = v.substr(0, v.length() - 1)
		if v != "" and DirAccess.open(v) != null:
			return v

	# Priorité 2 : chercher un nœud ZoneViewer dans la scène éditée
	# et lire sa propriété daoc_client_root
	var edited := EditorInterface.get_edited_scene_root()
	if edited != null:
		for node in _find_zone_viewers(edited):
			var prop: Variant = node.get("daoc_client_root")
			if prop != null:
				var v := str(prop).strip_edges().replace("\\", "/")
				while v.ends_with("/"):
					v = v.substr(0, v.length() - 1)
				if v != "" and DirAccess.open(v) != null:
					print("daoc_client_root lu depuis le nœud ZoneViewer : %s" % v)
					# Sauvegarder pour les prochains runs
					ProjectSettings.set_setting(SETTINGS_KEY, v)
					ProjectSettings.save()
					return v

	return ""


func _find_zone_viewers(node: Node) -> Array:
	var result := []
	if node.get_script() != null:
		var path: String = node.get_script().resource_path
		if path.get_file().to_lower().contains("zoneviewer"):
			result.append(node)
	for child in node.get_children():
		result.append_array(_find_zone_viewers(child))
	return result


func _run() -> void:
	var t_start := Time.get_ticks_msec()

	# ── Résolution du chemin racine ─────────────────────────────────────────
	var daoc_root := _get_daoc_root()

	if daoc_root == "":
		push_error(
			"scan_nifs: daoc_client_root introuvable.\n" +
			"Solution A (recommandée) : ouvrir la scène contenant ZoneViewer,\n" +
			"  s'assurer que daoc_client_root est renseigné dans l'Inspector,\n" +
			"  puis relancer ce script.\n" +
			"Solution B : ajouter manuellement dans Project > Project Settings :\n" +
			"  Clé   : %s\n" % SETTINGS_KEY +
			"  Valeur: C:/chemin/vers/Dark Age of Camelot"
		)
		return

	print("Racine DAoC : %s" % daoc_root)

	# ── Collecte des fichiers .nif ──────────────────────────────────────────
	var files: Array[String] = []
	var dirs_found:   Array[String] = []
	var dirs_missing: Array[String] = []

	for sub in NIF_SUBDIRS:
		var full_dir := daoc_root + "/" + sub
		if DirAccess.open(full_dir) != null:
			var before := files.size()
			_scan(full_dir, files)
			dirs_found.append("%s  (%d nifs)" % [full_dir, files.size() - before])
		else:
			dirs_missing.append(full_dir)

	if dirs_missing.size() > 0:
		print("⚠ Dossiers absents (normaux si non extraits) :")
		for d in dirs_missing:
			print("    " + d)

	if files.is_empty():
		push_error("scan: aucun .nif trouvé dans les sous-dossiers de : %s" % daoc_root)
		return

	# Dédoublonnage par nom de fichier (premier dossier gagne)
	var seen: Dictionary = {}
	var deduped: Array[String] = []
	for p in files:
		var key := p.get_file().to_lower()
		if not seen.has(key):
			seen[key] = true
			deduped.append(p)
	var dupes := files.size() - deduped.size()
	files = deduped

	if LIMIT > 0 and files.size() > LIMIT:
		files = files.slice(0, LIMIT)
		print("⚠ LIMIT=%d appliqué — scan partiel." % LIMIT)

	print("\n── Dossiers scannés ──")
	for d in dirs_found:
		print("  " + d)
	if dupes > 0:
		print("  (%d doublons supprimés)" % dupes)
	print("── Total : %d fichiers .nif ──\n" % files.size())

	# ── Scan ────────────────────────────────────────────────────────────────
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_CSV.get_base_dir()))
	var csv := FileAccess.open(OUT_CSV, FileAccess.WRITE)
	csv.store_line("fichier;version;statut;bloc_suspect;offset_hex;blocs_lus;dossier")

	var log := FileAccess.open(OUT_LOG, FileAccess.WRITE)
	log.store_line("scan_nifs — %s" % Time.get_datetime_string_from_system())
	log.store_line("Racine : %s" % daoc_root)
	log.store_line("Fichiers : %d\n" % files.size())

	var by_suspect: Dictionary = {}
	var by_status:  Dictionary = {}
	var hex_example: Dictionary = {}
	var ok := 0
	var i  := 0

	for path in files:
		i += 1
		if i % 100 == 0:
			print("  … %d / %d" % [i, files.size()])

		var reader := NifReader.new()
		reader.read(path)
		var fname   := path.get_file()
		var dossier := path.get_base_dir().get_file()

		var status  := ""
		var suspect := reader.suspect

		if not reader.failed:
			status = "OK"
			ok += 1
		elif reader.fail_reason.find("Gamebryo") >= 0:
			status  = "GAMEBRYO_10x"
			suspect = "(Gamebryo 10.x)"
		elif reader.fail_reason.find("bloc non gere") >= 0:
			status = "BLOC_NON_GERE"
		elif reader.fail_reason.find("invalide") >= 0 or reader.fail_reason.find("aberrant") >= 0:
			status = "DESYNC"
		else:
			status = "AUTRE"

		by_status[status] = by_status.get(status, 0) + 1
		if status != "OK":
			by_suspect[suspect] = by_suspect.get(suspect, 0) + 1
			if not hex_example.has(suspect):
				hex_example[suspect] = [path, reader.fail_offset, reader.fail_block_start]
			log.store_line("FAIL  %-20s  %-14s  %-30s  %s" % [
				status, suspect, fname, reader.fail_reason])

		csv.store_line("%s;%s;%s;%s;0x%X;%d;%s" % [
			fname,
			reader.version_str.replace(";", " "),
			status,
			suspect,
			reader.fail_offset,
			reader.blocks.size(),
			dossier,
		])

	csv.close()
	log.close()

	var elapsed := (Time.get_ticks_msec() - t_start) / 1000.0

	# ── Résumé console ──────────────────────────────────────────────────────
	print("\n═══════ STATUTS ═══════")
	for k in by_status:
		print("  %-16s %d" % [k, by_status[k]])
	print("  OK = %d / %d  (%.1f%%)" % [ok, files.size(), 100.0 * ok / files.size()])
	print("  Durée : %.1f s" % elapsed)

	print("\n═══════ BLOCS SUSPECTS (par nb de fichiers bloqués) ═══════")
	var pairs: Array = []
	for k in by_suspect:
		pairs.append([k, by_suspect[k]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	for p in pairs:
		print("  %5d  %s" % [p[1], p[0]])

	_write_hex_dumps(hex_example)

	print("\nCSV    : %s" % ProjectSettings.globalize_path(OUT_CSV))
	print("Hexdump: %s" % ProjectSettings.globalize_path(HEX_DUMP))
	print("Log    : %s" % ProjectSettings.globalize_path(OUT_LOG))


func _write_hex_dumps(examples: Dictionary) -> void:
	var out := FileAccess.open(HEX_DUMP, FileAccess.WRITE)
	for suspect in examples:
		var path:   String = examples[suspect][0]
		var off:    int    = examples[suspect][1]
		var bstart: int    = examples[suspect][2]
		out.store_line("═════ %s   (fichier: %s,  bloc=0x%X,  échec=0x%X) ═════" % [
			suspect, path.get_file(), bstart, off])
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			out.store_line("  (lecture impossible)\n")
			continue
		var start := maxi(0, bstart - 16)
		var endp  := off + 48
		f.seek(start)
		var buf := f.get_buffer(endp - start)
		f.close()
		var hex := ""
		var asc := ""
		for j in range(buf.size()):
			hex += "%02X " % buf[j]
			var c := buf[j]
			asc += String.chr(c) if (c >= 32 and c < 127) else "."
			if (j + 1) % 16 == 0:
				out.store_line("  0x%06X  %-48s %s" % [start + j - 15, hex, asc])
				hex = ""
				asc = ""
		if hex != "":
			out.store_line("           %-48s %s" % [hex, asc])
		out.store_line("  (bloc=0x%X  échec=0x%X)\n" % [bstart, off])
	out.close()


func _scan(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir.path_join(name)
		if d.current_is_dir():
			if name != "." and name != "..":
				_scan(full, out)
		elif name.to_lower().ends_with(".nif"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
