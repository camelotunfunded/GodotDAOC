extends RefCounted
class_name DaocModelIdAssetResolver

## P1-20F — entirely offline, source-derived model_id resolver.
## Canonical client chains:
## NPC/player: model_id -> monsters.csv[NIF] -> monnifs.csv[Name] -> figures/<Name>.nif
## Object:     model_id -> objects.csv[NIF]  -> items.csv[Name]   -> items/<Name>.nif

const TABLE_SPECS := {
	"monsters": {"file": "monsters.csv", "skip": 2},
	"monnifs": {"file": "monnifs.csv", "skip": 2},
	"objects": {"file": "objects.csv", "skip": 2},
	"items": {"file": "items.csv", "skip": 2},
	"skins": {"file": "skins.csv", "skip": 2},
	"anims": {"file": "anims.csv", "skip": 2},
	"canims": {"file": "canims.csv", "skip": 2},
}

const MONSTER_SKIN_PARTS := ["body", "head", "arms", "gloves", "lower_body", "legs", "boots", "cloak", "helm"]
const ITEM_ANIMATION_FIELDS := ["idle", "combat_idle", "attack_high", "attack_mid", "combat_style_01", "combat_style_03", "combat_style_04", "combat_style_06", "combat_style_07", "parry"]
const CP1252_DECODE := {
	0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
	0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6,
	0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
	0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
	0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
	0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
	0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
}

var daoc_root := ""
var tables: Dictionary = {}
var source_inventory: Dictionary = {}
var _dir_indexes: Dictionary = {}
var _nif_metadata_cache: Dictionary = {}


func configure(root: String = "") -> Dictionary:
	daoc_root = _normalize(root)
	if daoc_root.is_empty(): daoc_root = discover_daoc_root()
	tables.clear(); source_inventory.clear(); _dir_indexes.clear(); _nif_metadata_cache.clear()
	if daoc_root.is_empty() or not DirAccess.dir_exists_absolute(daoc_root):
		return {"ok": false, "error": "daoc_root_not_found", "daoc_root": daoc_root}
	for table_name in TABLE_SPECS:
		var spec: Dictionary = TABLE_SPECS[table_name]
		var relative := "gamedata/%s" % str(spec.file)
		var loaded := _load_id_csv(daoc_root.path_join(relative), int(spec.skip))
		tables[table_name] = loaded.get("rows", {})
		source_inventory[table_name] = {
			"relative_path": relative, "exists": bool(loaded.get("ok", false)),
			"row_count": int(loaded.get("row_count", 0)), "sha256": str(loaded.get("sha256", "")),
		}
	return {"ok": source_inventory.values().all(func(v): return bool(v.exists)),
		"daoc_root": daoc_root, "source_inventory": source_inventory.duplicate(true)}


func discover_daoc_root() -> String:
	var candidates: Array[String] = []
	var env := OS.get_environment("DAOC_CLIENT_ROOT").strip_edges()
	if not env.is_empty(): candidates.append(env)
	if ProjectSettings.has_setting("daoc/client_root"):
		candidates.append(str(ProjectSettings.get_setting("daoc/client_root")))
	candidates.append(ProjectSettings.globalize_path("res://../../Dark Age of Camelot"))
	for candidate in candidates:
		var normalized := _normalize(candidate)
		if DirAccess.dir_exists_absolute(normalized) and FileAccess.file_exists(normalized.path_join("gamedata/monsters.csv")):
			return normalized
	return ""


func resolve_catalog(catalog: Array) -> Dictionary:
	if tables.is_empty():
		var configured := configure(daoc_root)
		if not bool(configured.get("ok", false)): return {"ok": false, "error": configured.get("error", "configure_failed"), "models": []}
	var models: Array = []
	var status_counts := {"RESOLVED_EXACT": 0, "CANDIDATE": 0, "UNRESOLVED": 0}
	for input in catalog:
		var row: Dictionary = input
		var resolved := resolve_model(int(row.get("model_id", 0)), str(row.get("entity_type", "")))
		for key in ["entity_count", "names", "example_object_ids", "minimum_distance", "maximum_distance", "equipment_model_ids"]:
			if row.has(key): resolved[key] = row[key]
		models.append(resolved)
		status_counts[str(resolved.status)] = int(status_counts.get(str(resolved.status), 0)) + 1
	models.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.model_id) < int(b.model_id))
	return {"ok": int(status_counts.UNRESOLVED) == 0, "models": models, "status_counts": status_counts,
		"model_count": models.size(), "source_inventory": source_inventory.duplicate(true)}


func client_asset_inventory() -> Dictionary:
	var archive := daoc_root.path_join("gamedata.mpk")
	return {
		"gamedata_archive": {
			"relative_path": "gamedata.mpk",
			"exists": FileAccess.file_exists(archive),
			"size": FileAccess.get_file_as_bytes(archive).size() if FileAccess.file_exists(archive) else 0,
			"sha256": _sha256_file(archive) if FileAccess.file_exists(archive) else "",
		},
		"figures_manifest": {
			"relative_path": "figures",
			"nif_file_count": _count_files_with_extension("figures", ".nif"),
			"role": "NPC/player figure resources named by monnifs.csv",
		},
		"items_manifest": {
			"relative_path": "items",
			"nif_file_count": _count_files_with_extension("items", ".nif"),
			"role": "static/object resources named by items.csv",
		},
	}


func resolve_model(model_id: int, entity_type: String) -> Dictionary:
	var kind := "object" if entity_type == "object" else "npc"
	var base := {
		"model_id": model_id, "entity_type": entity_type, "asset_kind": kind,
		"resource_name": "", "nif_path": "", "texture_set": [], "texture_sources": [],
		"skeleton_path": "", "skeleton_kind": "none", "animation_set_id": 0,
		"animation_set_name": "", "combat_animation_set_name": "", "item_animations": {},
		"resolution_source": "", "source_chain": [], "confidence": "none", "status": "UNRESOLVED",
		"nif_exists": false, "nif_sha256": "", "nif_size": 0, "nif_family": "unknown",
		"geometry_kind": "static" if kind == "object" else "skinned_or_articulated",
	}
	return _resolve_object(model_id, base) if kind == "object" else _resolve_npc(model_id, base)


func _resolve_npc(model_id: int, out: Dictionary) -> Dictionary:
	var monster: Dictionary = tables.get("monsters", {}).get(model_id, {})
	if monster.is_empty(): return _fail(out, "model_id absent from monsters.csv")
	var mc: PackedStringArray = monster.cells
	if mc.size() < 3 or not mc[2].is_valid_int(): return _fail(out, "monsters.csv NIF reference absent")
	var nif_id := int(mc[2])
	var monnif: Dictionary = tables.get("monnifs", {}).get(nif_id, {})
	if monnif.is_empty(): return _fail(out, "NIF ID absent from monnifs.csv")
	var nc: PackedStringArray = monnif.cells
	if nc.size() < 4 or nc[2].strip_edges().is_empty(): return _fail(out, "monnifs.csv resource name absent")
	var resource := nc[2].strip_edges()
	var nif_relative := _find_relative_file("figures", resource + ".nif")
	out.resource_name = resource; out.nif_path = nif_relative; out.nif_exists = not nif_relative.is_empty()
	out.animation_set_id = int(nc[3]) if nc[3].is_valid_int() else 0
	var anim: Dictionary = tables.get("anims", {}).get(int(out.animation_set_id), {})
	var canim: Dictionary = tables.get("canims", {}).get(int(out.animation_set_id), {})
	out.animation_set_name = _cell(anim, 1)
	out.combat_animation_set_name = _cell(canim, 1)
	out.skeleton_kind = "embedded_in_figure_nif"
	var separate_skeleton := _find_relative_file("figures/fig3", resource + "_skeleton.nif")
	if not separate_skeleton.is_empty():
		out.skeleton_path = separate_skeleton; out.skeleton_kind = "separate_fig3_skeleton"
	var texture_set: Array = []
	for i in range(MONSTER_SKIN_PARTS.size()):
		var cell_index := 3 + i
		if cell_index >= mc.size() or not mc[cell_index].is_valid_int(): continue
		var skin_id := int(mc[cell_index])
		if skin_id <= 0: continue
		var skin: Dictionary = tables.get("skins", {}).get(skin_id, {})
		var texture := _cell(skin, 2)
		if not texture.is_empty(): _append_unique(texture_set, texture)
	if not texture_set.is_empty(): out.texture_sources.append("monsters.csv skin IDs -> skins.csv")
	out.source_chain = [
		_source("gamedata/monsters.csv", int(monster.line), model_id, "column 2 NIF=%d" % nif_id),
		_source("gamedata/monnifs.csv", int(monnif.line), nif_id, "column 2 Name=%s; column 3 animation set=%d" % [resource, int(out.animation_set_id)]),
	]
	out.resolution_source = "monsters.csv -> monnifs.csv -> figures/<Name>.nif"
	return _finalize_exact(out, texture_set)


func _resolve_object(model_id: int, out: Dictionary) -> Dictionary:
	var object_row: Dictionary = tables.get("objects", {}).get(model_id, {})
	if object_row.is_empty(): return _fail(out, "model_id absent from objects.csv")
	var oc: PackedStringArray = object_row.cells
	if oc.size() < 3 or not oc[2].is_valid_int(): return _fail(out, "objects.csv NIF reference absent")
	var item_id := int(oc[2])
	var item: Dictionary = tables.get("items", {}).get(item_id, {})
	if item.is_empty(): return _fail(out, "NIF ID absent from items.csv")
	var ic: PackedStringArray = item.cells
	if ic.size() < 3 or ic[2].strip_edges().is_empty(): return _fail(out, "items.csv resource name absent")
	var resource := ic[2].strip_edges()
	var nif_relative := _find_relative_file("items", resource + ".nif")
	out.resource_name = resource; out.nif_path = nif_relative; out.nif_exists = not nif_relative.is_empty()
	for i in range(ITEM_ANIMATION_FIELDS.size()):
		var cell_index := 5 + i
		if cell_index < ic.size() and ic[cell_index].is_valid_int() and int(ic[cell_index]) > 0:
			out.item_animations[ITEM_ANIMATION_FIELDS[i]] = int(ic[cell_index])
	out.source_chain = [
		_source("gamedata/objects.csv", int(object_row.line), model_id, "column 2 NIF=%d" % item_id),
		_source("gamedata/items.csv", int(item.line), item_id, "column 2 Name=%s" % resource),
	]
	out.resolution_source = "objects.csv -> items.csv -> items/<Name>.nif"
	return _finalize_exact(out, [])


func _finalize_exact(out: Dictionary, table_textures: Array) -> Dictionary:
	if not bool(out.nif_exists): return _fail(out, "table chain complete but NIF file absent")
	var metadata := _nif_metadata(str(out.nif_path))
	out.nif_sha256 = str(metadata.sha256); out.nif_size = int(metadata.size); out.nif_family = str(metadata.family)
	var textures: Array = table_textures.duplicate()
	for texture in metadata.textures: _append_unique(textures, str(texture))
	if not metadata.textures.is_empty(): out.texture_sources.append("embedded NIF texture strings")
	out.texture_set = textures
	out.status = "RESOLVED_EXACT"; out.confidence = "high_source_derived_and_file_verified"
	return out


func _fail(out: Dictionary, reason: String) -> Dictionary:
	out.status = "UNRESOLVED"; out.confidence = "none"; out.failure_reason = reason
	return out


func _load_id_csv(path: String, skip_lines: int) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "rows": {}, "row_count": 0, "sha256": ""}
	var rows := {}; var line_number := 0
	var raw_bytes := FileAccess.get_file_as_bytes(path)
	var line_bytes := PackedByteArray()
	for raw in raw_bytes:
		if int(raw) != 10:
			if int(raw) != 13:
				line_bytes.append(int(raw))
			continue
		line_number += 1
		var cells := _parse_csv_line(_decode_windows_1252(line_bytes))
		line_bytes = PackedByteArray()
		if line_number <= skip_lines or cells.is_empty(): continue
		var id_text := str(cells[0]).strip_edges()
		if id_text.is_valid_int(): rows[int(id_text)] = {"cells": cells, "line": line_number}
	if not line_bytes.is_empty():
		line_number += 1
		var cells := _parse_csv_line(_decode_windows_1252(line_bytes))
		if line_number > skip_lines and not cells.is_empty():
			var id_text := str(cells[0]).strip_edges()
			if id_text.is_valid_int(): rows[int(id_text)] = {"cells": cells, "line": line_number}
	return {"ok": true, "rows": rows, "row_count": rows.size(), "sha256": _sha256_file(path)}


func _parse_csv_line(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	var cell := ""
	var quoted := false
	var index := 0
	while index < line.length():
		var character := line[index]
		if character == '"':
			if quoted and index + 1 < line.length() and line[index + 1] == '"':
				cell += '"'
				index += 2
				continue
			quoted = not quoted
		elif character == "," and not quoted:
			cells.append(cell)
			cell = ""
		else:
			cell += character
		index += 1
	if not line.is_empty() or not cell.is_empty():
		cells.append(cell)
	return cells


func _decode_windows_1252(bytes: PackedByteArray) -> String:
	var out := ""
	for raw in bytes:
		var value := int(raw) & 0xff
		out += String.chr(int(CP1252_DECODE.get(value, value)))
	return out


func _find_relative_file(relative_dir: String, wanted_name: String) -> String:
	var key := relative_dir.to_lower()
	if not _dir_indexes.has(key):
		var index := {}; var absolute_dir := daoc_root.path_join(relative_dir)
		if DirAccess.dir_exists_absolute(absolute_dir):
			for file_name in DirAccess.get_files_at(absolute_dir): index[str(file_name).to_lower()] = str(file_name)
		_dir_indexes[key] = index
	var actual := str(_dir_indexes[key].get(wanted_name.to_lower(), ""))
	return relative_dir.path_join(actual).replace("\\", "/") if not actual.is_empty() else ""


func _count_files_with_extension(relative_dir: String, extension: String) -> int:
	var absolute_dir := daoc_root.path_join(relative_dir)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		return 0
	var count := 0
	for file_name in DirAccess.get_files_at(absolute_dir):
		if str(file_name).to_lower().ends_with(extension.to_lower()):
			count += 1
	return count


func _nif_metadata(relative_path: String) -> Dictionary:
	if _nif_metadata_cache.has(relative_path): return _nif_metadata_cache[relative_path]
	var absolute := daoc_root.path_join(relative_path)
	var bytes := FileAccess.get_file_as_bytes(absolute)
	var runs := _ascii_runs(bytes)
	var textures: Array = []
	for run in runs:
		var low := str(run).to_lower()
		if low.ends_with(".dds") or low.ends_with(".tga") or low.ends_with(".bmp") or low.ends_with(".png"):
			_append_unique(textures, str(run).replace("\\", "/"))
	var family := "unknown"
	for run in runs.slice(0, mini(12, runs.size())):
		if str(run).begins_with("Gamebryo File Format") or str(run).begins_with("NetImmerse File Format"):
			family = str(run); break
	var result := {"size": bytes.size(), "sha256": _sha256(bytes), "family": family, "textures": textures}
	_nif_metadata_cache[relative_path] = result
	return result


func _ascii_runs(bytes: PackedByteArray) -> Array:
	var out: Array = []; var current := PackedByteArray()
	for raw in bytes:
		var value := int(raw)
		if value >= 32 and value <= 126:
			current.append(value)
		else:
			if current.size() >= 4: out.append(current.get_string_from_ascii())
			current = PackedByteArray()
	if current.size() >= 4: out.append(current.get_string_from_ascii())
	return out


func _source(file: String, line: int, id: int, evidence: String) -> Dictionary:
	return {"file": file, "line": line, "id": id, "evidence": evidence}


func _cell(row: Dictionary, index: int) -> String:
	if row.is_empty(): return ""
	var cells: PackedStringArray = row.cells
	return cells[index].strip_edges() if index >= 0 and index < cells.size() else ""


func _append_unique(values: Array, value: String) -> void:
	if not value.is_empty() and not values.has(value): values.append(value)


func _sha256_file(path: String) -> String:
	return _sha256(FileAccess.get_file_as_bytes(path))


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()


func _normalize(path: String) -> String:
	var result := path.strip_edges().replace("\\", "/")
	while result.ends_with("/"):
		result = result.substr(0, result.length() - 1)
	return result
