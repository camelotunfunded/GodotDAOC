@tool
## prebake_nif.gd — OPTIONNEL. Conversion par lot .nif -> scenes Godot (.tscn),
## a executer dans l'editeur : ouvrir ce fichier, Fichier > Executer (Ctrl+Maj+X).
##
## Chemin "production" du pivot (NOTE_TERRAIN §11) : on convertit tout le catalogue
## UNE fois et on met en cache ; le jeu n'a plus qu'a charger du Godot natif.
## Le viewer (ZoneViewer.gd) fait deja la conversion a chaud pour tester ; ce
## prebake sert quand on voudra figer le lot. Reutilise NifConverter.build_template.
extends EditorScript

## Dossier source des .nif (recursif). Chemin ABSOLU.
const SRC_DIR := "C:/CHANGE_ME/zones/nifs"
## Dossier de sortie (cree au besoin).
const OUT_DIR := "res://cache_nif"
const REPORT := "res://reports/prebake_nif/conversion_report.csv"


func _run() -> void:
	if SRC_DIR.begins_with("C:/CHANGE_ME"):
		push_error("prebake: edite SRC_DIR (et OUT_DIR) en haut du fichier avant de lancer.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var files: Array[String] = []
	_scan(SRC_DIR, files)
	print("prebake: %d fichiers .nif trouves." % files.size())

	var report := FileAccess.open(REPORT, FileAccess.WRITE)
	report.store_line("fichier,statut,version,signature,blocs,maillages,raison")
	var ok_count := 0
	for src in files:
		var reader := NifReader.new()
		var rel := src.get_file().get_basename()
		if not reader.read(src) or reader.failed:
			report.store_line("%s,ECHEC,%s,%s,%d,0,%s" % [
				src.get_file(), reader.version_str, reader.signature,
				reader.blocks.size(), reader.fail_reason.replace(",", ";")])
			continue
		var node := NifConverter.build_template(reader, rel)
		var meshes := _count_meshes(node)
		var packed := PackedScene.new()
		packed.pack(node)
		var out_path := "%s/%s.tscn" % [OUT_DIR, rel]
		var err := ResourceSaver.save(packed, out_path)
		node.queue_free()
		if err == OK:
			ok_count += 1
		report.store_line("%s,%s,%s,%s,%d,%d," % [
			src.get_file(), ("OK" if err == OK else "SAVE_ERR"),
			reader.version_str, reader.signature, reader.blocks.size(), meshes])
	report.close()
	print("prebake termine : %d / %d OK. Rapport: %s" % [ok_count, files.size(), REPORT])


func _scan(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		push_error("prebake: dossier introuvable: %s" % dir)
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


func _count_meshes(node: Node) -> int:
	var n := 1 if node.is_class("MeshInstance3D") else 0
	for c in node.get_children():
		n += _count_meshes(c)
	return n
