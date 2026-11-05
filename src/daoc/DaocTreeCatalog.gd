extends RefCounted
## Tables natives uniquement. Aucun remplacement ni conversion au chargement.
## Une substitution vide (mightyoak, BigHibTree...) conserve le modele NIF.

static func key(filename: String) -> String:
	return filename.replace("\\", "/").get_file().get_basename().to_lower()

static func load_client(client: String) -> Dictionary:
	var result := {"trees": {}, "clusters": {}, "errors": []}
	var trees := FileAccess.open(client.path_join("zones/trees/treemap/Treemap.csv"), FileAccess.READ)
	if trees == null:
		result.errors.append("Treemap.csv introuvable")
		return result
	trees.get_csv_line()
	while not trees.eof_reached():
		var row := trees.get_csv_line()
		if row.is_empty() or row[0].strip_edges() == "":
			continue
		if row.size() < 17:
			result.errors.append("Treemap ligne incomplete: " + row[0])
			continue
		var id := key(row[0])
		if result.trees.has(id):
			result.errors.append("Treemap doublon: " + id)
			continue
		var active := row[1].strip_edges() != ""
		var numeric_ok := true
		if active:
			for i in range(4, 17):
				if not row[i].is_valid_float():
					numeric_ok = false
		if not numeric_ok:
			result.errors.append("Treemap parametre non numerique: " + id)
			continue
		result.trees[id] = {"nif": row[0], "replacement": row[1], "has_replacement": active,
			"bark_texture": row[2], "leaf_texture": row[3],
			"zoffset_raw": float(row[4]) if active else null,
			"scale_raw": float(row[5]) if active else null,
			"scale_factor": float(row[5]) / 1000.0 if active else null,
			"seeds": [int(row[6]), int(row[7]), int(row[8]), int(row[9])] if active else [],
			"bark_dif_amb_emi": [float(row[10]), float(row[11]), float(row[12])] if active else [],
			"leaf_dif_amb_emi": [float(row[13]), float(row[14]), float(row[15])] if active else [],
			"expansion": int(row[16]) if active else null, "raw": Array(row)}
	var groups := FileAccess.open(client.path_join("zones/trees/tree_clusters/tree_clusters.csv"), FileAccess.READ)
	if groups == null:
		result.errors.append("tree_clusters.csv introuvable")
		return result
	groups.get_csv_line()
	var pattern := RegEx.new()
	pattern.compile("(?i)CL([0-9]+)")
	while not groups.eof_reached():
		var row := groups.get_csv_line()
		if row.is_empty() or row[0].strip_edges() == "":
			continue
		var match_count := pattern.search(row[0])
		if match_count == null or row.size() < 2:
			result.errors.append("Bosquet sans compteur CL: " + row[0])
			continue
		var count := int(match_count.get_string(1))
		var id := key(row[0])
		if count <= 0 or row.size() < 2 + 3 * count or result.clusters.has(id) or not result.trees.has(key(row[1])):
			result.errors.append("Bosquet invalide: " + row[0])
			continue
		var positions: Array = []
		for i in count:
			var off := 2 + i * 3
			if not row[off].is_valid_float() or not row[off+1].is_valid_float() or not row[off+2].is_valid_float():
				break
			positions.append(Vector3(float(row[off]), float(row[off+1]), float(row[off+2])))
		if positions.size() != count:
			result.errors.append("Bosquet coordonnees invalides: " + row[0])
			continue
		# Le compteur CL conserve une eventuelle position (0,0,0), sans le padding.
		result.clusters[id] = {"nif": row[0], "tree_key": key(row[1]), "count": count, "offsets_raw": positions}
	return result
