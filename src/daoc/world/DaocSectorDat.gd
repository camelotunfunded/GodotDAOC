extends RefCounted
class_name DaocSectorDat

## R6 — la lecture du `SECTOR.DAT`, sortie du ZoneViewer pour que deux hôtes
## puissent la partager.
##
## Six appelants lisent ce fichier dans le projet — eau, ciel, mer de région,
## herbes, horizon, frontières maritimes. `DaocZoneBuildServices` en faisait déjà
## un service dès R4, mais l'implémentation vivait encore dans le banc. La scène
## de jeu R6 en a besoin aussi, et la recopier aurait créé deux vérités sur
## l'endroit où le client range ses secteurs.
##
## Aucun octet n'est lu différemment : le corps de ces deux fonctions est celui
## du ZoneViewer, déplacé et non réécrit. Le banc les appelle désormais ici.

## Trouve le `SECTOR.DAT` d'une zone.
##
## L'ordre des candidats est significatif : les noms « amis du cache » d'abord,
## pour qu'un futur générateur de cache n'ait qu'à y copier le fichier ; les
## arbres du client décompressé ensuite. La recherche reste CIBLÉE — on ne
## parcourt jamais le client entier au runtime.
static func find_path(data_dir: String, client_root: String, znum: int) -> String:
	var zone_dir := "zone%03d" % znum
	var dat_dir := "dat%03d" % znum
	var csv_dir := "csv%03d" % znum
	var candidates: Array[String] = []

	candidates.append(data_dir.path_join("zone%03d_sector.dat" % znum))
	candidates.append(data_dir.path_join("zone%03d_SECTOR.DAT" % znum))
	candidates.append(data_dir.path_join(zone_dir).path_join("SECTOR.DAT"))
	candidates.append(data_dir.path_join(zone_dir).path_join(dat_dir).path_join("SECTOR.DAT"))
	candidates.append(data_dir.path_join(zone_dir).path_join(csv_dir).path_join("SECTOR.DAT"))
	candidates.append(data_dir.path_join(dat_dir).path_join("SECTOR.DAT"))
	candidates.append(data_dir.path_join(csv_dir).path_join("SECTOR.DAT"))

	if client_root != "":
		var zone_roots: Array[String] = [
			client_root.path_join("zones").path_join(zone_dir),
			client_root.path_join("frontiers/zones").path_join(zone_dir),
			client_root.path_join("phousing/zones").path_join(zone_dir),
			client_root.path_join("tutorial/zones").path_join(zone_dir),
			client_root.path_join("zones"),
			client_root.path_join("frontiers/zones"),
			client_root.path_join("phousing/zones"),
			client_root.path_join("tutorial/zones"),
		]
		for zone_root in zone_roots:
			candidates.append(zone_root.path_join(dat_dir).path_join("SECTOR.DAT"))
			candidates.append(zone_root.path_join(csv_dir).path_join("SECTOR.DAT"))
			candidates.append(zone_root.path_join("dat").path_join("SECTOR.DAT"))
			candidates.append(zone_root.path_join("csv").path_join("SECTOR.DAT"))
			candidates.append(zone_root.path_join("SECTOR.DAT"))

	for candidate in candidates:
		if candidate != "" and FileAccess.file_exists(candidate):
			return candidate
	return ""


## Lit un `SECTOR.DAT` en sections `[nom]` de paires `cle=valeur`.
##
## Les clés et les noms de section sont ramenés en MINUSCULES, les valeurs
## conservées telles quelles : le client écrit indifféremment `Tesselation` et
## `tesselation`, et la casse d'une valeur peut être un nom de fichier.
static func parse(path: String) -> Dictionary:
	var out: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var section := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			if not out.has(section):
				out[section] = {}
			continue
		var separator := line.find("=")
		if separator < 0 or section == "":
			continue
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		var entries: Dictionary = out[section]
		entries[key] = value
	file.close()
	return out
