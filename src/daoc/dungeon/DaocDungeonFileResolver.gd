extends RefCounted
class_name DaocDungeonFileResolver

## P1-17A1 — résolution locale des fichiers donjon DAoC.
##
## Le DungeonLab reste volontairement séparé du ZoneViewer. Ce resolver cherche
## d'abord dans le client DAoC local, puis dans le cache Godot si disponible.

const SCOPE: String = "P1-17C1 configurable dungeon file resolver"
const CHECKPOINT: String = "P1_17C1_CONFIGURABLE_DUNGEON_FILE_RESOLVER"

const DEFAULT_ZONE_ID: int = 21
const DEFAULT_ZONE_NAME: String = "Tomb of Mithra"


static func normalize_path(path: String) -> String:
	var p: String = path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p


static func default_client_root() -> String:
	var value: Variant = ProjectSettings.get_setting("daoc/client_root", "")
	return normalize_path(str(value))


static func zone_folder_name(zone_id: int) -> String:
	return "zone%03d" % zone_id


static func dat_folder_name(zone_id: int) -> String:
	return "dat%03d" % zone_id


static func default_zone_name(zone_id: int) -> String:
	match zone_id:
		19:
			return "Stonehenge Barrows Dungeon"
		21:
			return "Tomb of Mithra"
		499:
			return "Dungeon smoke-test zone499"
		_:
			return zone_folder_name(zone_id)


static func resolve_dat_folder(client_root: String, zone_id: int) -> String:
	var root: String = normalize_path(client_root)
	var zp: String = zone_folder_name(zone_id)
	var dp: String = dat_folder_name(zone_id)
	var candidates: Array = []
	if root != "":
		candidates.append(root.path_join("zones").path_join(zp).path_join(dp))
		candidates.append(root.path_join("frontiers/zones").path_join(zp).path_join(dp))
		candidates.append(root.path_join("phousing/zones").path_join(zp).path_join(dp))
		candidates.append(root.path_join("tutorial/zones").path_join(zp).path_join(dp))
		candidates.append(root.path_join("zones").path_join(zp).path_join("dat"))
		candidates.append(root.path_join("zones").path_join(dp))
		candidates.append(root.path_join("_godot_daoc_cache").path_join("data").path_join(zp).path_join(dp))
		candidates.append(root.path_join("_godot_daoc_cache").path_join("data").path_join(dp))
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		if candidate != "" and DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""


static func resolve_zone_file(client_root: String, zone_id: int, file_name: String) -> String:
	var dat_folder: String = resolve_dat_folder(client_root, zone_id)
	var variants: Array = _file_name_variants(file_name)
	if dat_folder != "":
		for variant_value in variants:
			var candidate: String = dat_folder.path_join(str(variant_value))
			if FileAccess.file_exists(candidate):
				return candidate
	var root: String = normalize_path(client_root)
	var zp: String = zone_folder_name(zone_id)
	var dp: String = dat_folder_name(zone_id)
	var candidates: Array = []
	if root != "":
		for variant_value in variants:
			var variant: String = str(variant_value)
			for zone_root in [
				root.path_join("zones").path_join(zp),
				root.path_join("frontiers/zones").path_join(zp),
				root.path_join("phousing/zones").path_join(zp),
				root.path_join("tutorial/zones").path_join(zp),
				root.path_join("_godot_daoc_cache").path_join("data").path_join(zp),
			]:
				candidates.append(zone_root.path_join(dp).path_join(variant))
				candidates.append(zone_root.path_join("dat").path_join(variant))
				candidates.append(zone_root.path_join(variant))
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		if candidate != "" and FileAccess.file_exists(candidate):
			return candidate
	return ""


static func resolve_dungeon_files(client_root: String, zone_id: int, zone_name: String = "") -> Dictionary:
	var display_name: String = zone_name.strip_edges()
	if display_name == "":
		display_name = default_zone_name(zone_id)
	var files: Dictionary = {}
	for file_name in [
		"dungeon.chunk",
		"dungeon.place",
		"dungeon.prop",
		"portals.csv",
		"lights.csv",
		"dungeon.water",
		"dungeon.water.csv",
		"SECTOR.DAT",
	]:
		files[file_name] = resolve_zone_file(client_root, zone_id, file_name)
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"zone_id": zone_id,
		"zone_name": display_name,
		"client_root": normalize_path(client_root),
		"dat_folder": resolve_dat_folder(client_root, zone_id),
		"files": files,
	}


static func resolve_nif_path(client_root: String, nif_name: String) -> String:
	var info: Dictionary = resolve_nif_path_info(client_root, nif_name)
	return str(info.get("path", ""))


static func resolve_nif_path_info(client_root: String, nif_name: String) -> Dictionary:
	var root: String = normalize_path(client_root)
	var n: String = nif_name.strip_edges().replace("\\", "/")
	var result: Dictionary = {
		"name": nif_name,
		"path": "",
		"found": false,
		"method": "",
		"candidate_roots": [],
		"candidate_count": 0,
	}
	if n == "":
		result["method"] = "empty_name"
		return result
	if FileAccess.file_exists(n):
		result["path"] = n
		result["found"] = true
		result["method"] = "absolute_or_relative_direct"
		result["candidate_count"] = 1
		return result
	var base: String = n.get_file()
	var stem: String = base.get_basename()
	var variants: Array = _file_name_variants(base)
	var folder_variants: Array = _folder_name_variants(stem)
	var roots: Array = _nif_search_roots(root)
	result["candidate_roots"] = roots.duplicate()
	var candidate_count: int = 0
	var first_empty_candidate: String = ""
	var first_empty_method: String = ""
	for rv in roots:
		var r: String = str(rv)
		if r == "":
			continue
		for variant_value in variants:
			var variant: String = str(variant_value)
			var direct: String = r.path_join(variant)
			candidate_count += 1
			if FileAccess.file_exists(direct):
				if _nif_file_usable(direct):
					result["path"] = direct
					result["found"] = true
					result["method"] = "direct_variant"
					result["candidate_count"] = candidate_count
					return result
				if first_empty_candidate == "":
					first_empty_candidate = direct
					first_empty_method = "direct_variant_empty"
			for folder_value in folder_variants:
				var nested: String = r.path_join(str(folder_value)).path_join(variant)
				candidate_count += 1
				if FileAccess.file_exists(nested):
					if _nif_file_usable(nested):
						result["path"] = nested
						result["found"] = true
						result["method"] = "nested_variant"
						result["candidate_count"] = candidate_count
						return result
					if first_empty_candidate == "":
						first_empty_candidate = nested
						first_empty_method = "nested_variant_empty"
	# Godot/FileAccess can be picky about exact case on some mounted or extracted
	# trees. Final fallback: shallow case-insensitive traversal under known NIF roots.
	for rv in roots:
		var scanned: Dictionary = _find_file_case_insensitive_shallow(str(rv), variants, folder_variants, 3)
		candidate_count += int(scanned.get("visited", 0))
		if str(scanned.get("path", "")) != "":
			var scanned_path: String = str(scanned.get("path", ""))
			if _nif_file_usable(scanned_path):
				result["path"] = scanned_path
				result["found"] = true
				result["method"] = str(scanned.get("method", "case_insensitive_scan"))
				result["candidate_count"] = candidate_count
				return result
			if first_empty_candidate == "":
				first_empty_candidate = scanned_path
				first_empty_method = str(scanned.get("method", "case_insensitive_scan")) + "_empty"
	if first_empty_candidate != "":
		result["path"] = first_empty_candidate
		result["found"] = true
		result["method"] = first_empty_method
		result["candidate_count"] = candidate_count
		result["empty_file_candidate"] = true
		return result
	result["method"] = "not_found"
	result["candidate_count"] = candidate_count
	return result


static func _nif_file_usable(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var length: int = f.get_length()
	f.close()
	return length >= 16


static func _nif_search_roots(root: String) -> Array:
	var roots: Array = []
	if root == "":
		return roots
	# DAoC separates some dungeon NIFs in Dnifs (observed for Stonehenge
	# Barrows: ALTSTONEHall10/11/22 under zones/Dnifs/<stem>/<file>). Keep
	# regular nifs roots first for compatibility with exterior/static props, then
	# add dungeon-specific Dnifs variants.
	for value in [
		root.path_join("zones").path_join("nifs"),
		root.path_join("zones").path_join("Nifs"),
		root.path_join("zones").path_join("NIFS"),
		root.path_join("zones").path_join("nif"),
		root.path_join("zones").path_join("Dnifs"),
		root.path_join("zones").path_join("dnifs"),
		root.path_join("zones").path_join("DNIFS"),
		root.path_join("zones").path_join("DNifs"),
		root.path_join("Nifs"),
		root.path_join("nifs"),
		root.path_join("NIFS"),
		root.path_join("Dnifs"),
		root.path_join("dnifs"),
		root.path_join("DNIFS"),
		root.path_join("_godot_daoc_cache").path_join("nifs"),
		root.path_join("_godot_daoc_cache").path_join("dnifs"),
		root.path_join("_godot_daoc_cache").path_join("Dnifs"),
		root.path_join("_godot_daoc_cache").path_join("data").path_join("nifs"),
		root.path_join("_godot_daoc_cache").path_join("data").path_join("dnifs"),
		root.path_join("_godot_daoc_cache").path_join("data").path_join("Dnifs"),
	]:
		_append_unique(roots, normalize_path(str(value)))
	return roots


static func _find_file_case_insensitive_shallow(root: String, variants: Array, folder_variants: Array, max_depth: int) -> Dictionary:
	var result: Dictionary = {"path": "", "visited": 0, "method": ""}
	var wanted_files: Dictionary = {}
	for value in variants:
		wanted_files[str(value).to_lower()] = true
	var wanted_folders: Dictionary = {}
	for value in folder_variants:
		wanted_folders[str(value).to_lower()] = true
	var queue: Array = [{"path": normalize_path(root), "depth": 0}]
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front() as Dictionary
		var dir_path: String = str(current.get("path", ""))
		var depth: int = int(current.get("depth", 0))
		if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
			continue
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var entry: String = dir.get_next()
			if entry == "":
				break
			if entry == "." or entry == "..":
				continue
			var full: String = dir_path.path_join(entry)
			result["visited"] = int(result.get("visited", 0)) + 1
			if dir.current_is_dir():
				if depth < max_depth:
					var entry_l: String = entry.to_lower()
					# Prefer the matching NIF folder, but keep shallow traversal as a safety net.
					if wanted_folders.has(entry_l) or depth < 1:
						queue.append({"path": full, "depth": depth + 1})
			else:
				if wanted_files.has(entry.to_lower()):
					dir.list_dir_end()
					result["path"] = full
					result["method"] = "case_insensitive_scan"
					return result
		dir.list_dir_end()
	return result


static func _append_unique(out: Array, value: String) -> void:
	if value != "" and not out.has(value):
		out.append(value)


static func _file_name_variants(file_name: String) -> Array:
	var out: Array = []
	var clean: String = file_name.get_file()
	var stem: String = clean.get_basename()
	var ext: String = clean.get_extension()
	var ext_values: Array = []
	if ext != "":
		ext_values = [ext, ext.to_lower(), ext.to_upper()]
	else:
		ext_values = ["nif", "NIF"]
	var stems: Array = [stem, stem.to_lower(), stem.to_upper()]
	for value in [clean, clean.to_lower(), clean.to_upper()]:
		_append_unique(out, str(value))
	for stem_value in stems:
		for ext_value in ext_values:
			_append_unique(out, "%s.%s" % [str(stem_value), str(ext_value)])
	return out


static func _folder_name_variants(stem: String) -> Array:
	var out: Array = []
	for value in [stem, stem.to_lower(), stem.to_upper()]:
		var s: String = str(value)
		if not out.has(s):
			out.append(s)
	return out
