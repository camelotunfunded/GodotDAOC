extends RefCounted
class_name DaocClientZoneInventory

const DaocServerClientZoneMapScript = preload("res://src/daoc/world/DaocServerClientZoneMap.gd")

const SCOPE: String = "P1-17E2N client zone inventory and region mapping"
const CHECKPOINT: String = "P1_17E2N_CLIENT_ZONE_INVENTORY_REGION_MAPPING"

const DEFAULT_JSON_PATH: String = "res://reports/p1_17e2n_client_zone_inventory.json"
const DEFAULT_TEXT_PATH: String = "res://reports/p1_17e2n_client_zone_inventory.txt"

const TERRAIN_MARKERS: Array = ["terrain.pcx", "offset.pcx", "fixtures.csv", "bound.csv", "zonejump.csv"]
const TERRAIN_CORE_MARKERS: Array = ["terrain.pcx", "offset.pcx"]
const DUNGEON_MARKERS: Array = ["dungeon.chunk", "dungeon.place", "dungeon.prop", "dungeon.water", "portals.csv", "lights.csv"]
const DUNGEON_CORE_MARKERS: Array = ["dungeon.chunk", "dungeon.place", "dungeon.prop", "portals.csv"]
const CITY_MARKERS: Array = ["city.csv", "adjacency.csv"]
const FOOTPRINT_MARKERS: Array = ["footprint.csv", "tile.csv"]

var last_inventory: Dictionary = {}


func build_inventory(zones_root: String, options: Dictionary = {}) -> Dictionary:
	var root: String = _normalize_os_path(zones_root)
	var entries: Array = []
	var errors: Array = []
	if root == "" or not DirAccess.dir_exists_absolute(root):
		errors.append("zones root missing: %s" % root)
		last_inventory = _inventory_result(root, entries, errors, {})
		return last_inventory
	var zone_dirs: Array = _discover_zone_dirs(root)
	var limit: int = int(options.get("limit", 0))
	if limit > 0 and zone_dirs.size() > limit:
		zone_dirs = zone_dirs.slice(0, limit)
	for zone_info_value in zone_dirs:
		if typeof(zone_info_value) != TYPE_DICTIONARY:
			continue
		entries.append(_inspect_zone(root, zone_info_value as Dictionary))
	var mapping: Array = build_region_zone_mapping(entries)
	last_inventory = _inventory_result(root, entries, errors, {
		"region_zone_mapping": mapping,
		"region_zone_mapping_count": mapping.size(),
	})
	return last_inventory


func build_region_zone_mapping(zone_entries: Array = []) -> Array:
	var zone_by_id: Dictionary = {}
	for entry_value in zone_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		zone_by_id[int(entry.get("zone_id", -1))] = entry
	var out: Array = []
	var known_mappings: Array = DaocServerClientZoneMapScript.new().call("known_mappings") as Array
	for mapping_value in known_mappings:
		var mapping: Dictionary = (mapping_value as Dictionary).duplicate(true)
		var zone_id: int = int(mapping.get("client_zone_id", -1))
		var zone_entry: Dictionary = zone_by_id.get(zone_id, {}) as Dictionary
		mapping["client_zone_present"] = not zone_entry.is_empty()
		mapping["scene_godot_path"] = _generated_scene_path(zone_id, str(mapping.get("zone_kind", "")))
		mapping["scene_godot_exists"] = FileAccess.file_exists(str(mapping.get("scene_godot_path", "")))
		mapping["zone_markers_present"] = zone_entry.get("markers_present", [])
		mapping["mapping_status"] = "client_zone_present_frame_unconfirmed" if bool(mapping.get("client_zone_present", false)) else "client_zone_missing"
		out.append(mapping)
	return out


func export_last_inventory_json(path: String = DEFAULT_JSON_PATH) -> Dictionary:
	return _write_text(path, JSON.stringify(last_inventory, "  "), "json")


func export_last_inventory_text(path: String = DEFAULT_TEXT_PATH) -> Dictionary:
	return _write_text(path, _inventory_as_text(last_inventory), "text")


func _inventory_result(root: String, entries: Array, errors: Array, extra: Dictionary) -> Dictionary:
	var kind_counts: Dictionary = {}
	var present_scene_count: int = 0
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var kind: String = str(entry.get("zone_kind", "unknown"))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		if bool(entry.get("generated_scene_exists", false)) or bool(entry.get("generated_dungeon_scene_exists", false)):
			present_scene_count += 1
	var result: Dictionary = {
		"ok": errors.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"report_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"zones_root": root,
		"zone_count": entries.size(),
		"kind_counts": kind_counts,
		"generated_scene_present_count": present_scene_count,
		"zones": entries,
		"errors": errors,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _discover_zone_dirs(root: String) -> Array:
	var out: Array = []
	for dir_name in DirAccess.get_directories_at(root):
		var normalized: String = str(dir_name).to_lower()
		if not normalized.begins_with("zone"):
			continue
		var suffix: String = normalized.substr(4)
		if not suffix.is_valid_int():
			continue
		out.append({
			"zone_id": int(suffix),
			"dir_name": str(dir_name),
			"path": root.path_join(str(dir_name)),
		})
	out.sort_custom(func(a, b): return int((a as Dictionary).get("zone_id", 0)) < int((b as Dictionary).get("zone_id", 0)))
	return out


func _inspect_zone(root: String, zone_info: Dictionary) -> Dictionary:
	var zone_id: int = int(zone_info.get("zone_id", -1))
	var zone_path: String = str(zone_info.get("path", ""))
	var marker_hits: Dictionary = {}
	var markers_present: Array = []
	for marker in _all_markers():
		var hit: String = _find_marker(zone_id, zone_path, str(marker))
		marker_hits[str(marker)] = hit
		if hit != "":
			markers_present.append(str(marker))
	var zone_kind: String = _classify_markers(markers_present)
	return {
		"zone_id": zone_id,
		"zone_name": "zone%03d" % zone_id,
		"source_dir_name": str(zone_info.get("dir_name", "")),
		"source_path": zone_path,
		"zone_kind": zone_kind,
		"markers_present": markers_present,
		"marker_paths": marker_hits,
		"generated_scene_path": _generated_scene_path(zone_id, "terrain_heightmap"),
		"generated_scene_exists": FileAccess.file_exists(_generated_scene_path(zone_id, "terrain_heightmap")),
		"generated_dungeon_scene_path": _generated_scene_path(zone_id, "dungeon_chunk"),
		"generated_dungeon_scene_exists": FileAccess.file_exists(_generated_scene_path(zone_id, "dungeon_chunk")),
		"runtime_enabled": false,
		"report_only": true,
	}


func _find_marker(zone_id: int, zone_path: String, marker: String) -> String:
	var zdat: String = "dat%03d" % zone_id
	var zcsv: String = "csv%03d" % zone_id
	var candidates: Array = [
		zone_path.path_join(marker),
		zone_path.path_join(zdat).path_join(marker),
		zone_path.path_join(zcsv).path_join(marker),
		zone_path.path_join("dat").path_join(marker),
		zone_path.path_join("csv").path_join(marker),
	]
	var variants: Array = _case_variants(marker)
	for base_value in candidates:
		var base: String = str(base_value)
		var dir: String = base.get_base_dir()
		for variant_value in variants:
			var candidate: String = dir.path_join(str(variant_value))
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


func _classify_markers(markers_present: Array) -> String:
	if _has_any(markers_present, TERRAIN_CORE_MARKERS):
		return "terrain_heightmap"
	if _has_any(markers_present, DUNGEON_CORE_MARKERS):
		return "dungeon_chunk"
	if _has_any(markers_present, CITY_MARKERS):
		return "tileworld_city"
	if _has_any(markers_present, FOOTPRINT_MARKERS):
		return "tileworld_footprint"
	return "unknown"


func _all_markers() -> Array:
	var out: Array = []
	for group in [TERRAIN_MARKERS, DUNGEON_MARKERS, CITY_MARKERS, FOOTPRINT_MARKERS]:
		for marker in (group as Array):
			if not out.has(str(marker)):
				out.append(str(marker))
	return out


func _has_any(values: Array, candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(str(candidate)):
			return true
	return false


func _case_variants(value: String) -> Array:
	var out: Array = []
	for item in [value, value.to_lower(), value.to_upper()]:
		if not out.has(str(item)):
			out.append(str(item))
	return out


func _generated_scene_path(zone_id: int, zone_kind: String) -> String:
	if zone_kind == "dungeon_chunk":
		return "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn" % [zone_id, zone_id]
	return "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [zone_id, zone_id]


func _write_text(path: String, text: String, kind: String) -> Dictionary:
	var target: String = path.strip_edges()
	if target == "":
		return {"ok": false, "kind": kind, "path": target, "error": "empty path"}
	var global_path: String = ProjectSettings.globalize_path(target)
	var parent: String = global_path.get_base_dir()
	var dir_error: int = DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return {"ok": false, "kind": kind, "path": target, "error": "cannot create parent dir: %d" % dir_error}
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "kind": kind, "path": target, "error": "cannot open for write"}
	file.store_string(text)
	file.close()
	return {"ok": true, "kind": kind, "path": target, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func _inventory_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-17E2N client zone inventory")
	lines.append("ok=%s zones=%d scenes_present=%d" % [str(report.get("ok", false)), int(report.get("zone_count", 0)), int(report.get("generated_scene_present_count", 0))])
	lines.append("kind_counts=%s" % str(report.get("kind_counts", {})))
	lines.append("region_zone_mapping_count=%d" % int(report.get("region_zone_mapping_count", 0)))
	for mapping_value in (report.get("region_zone_mapping", []) as Array):
		if typeof(mapping_value) != TYPE_DICTIONARY:
			continue
		var mapping: Dictionary = mapping_value as Dictionary
		lines.append("region=%d name=%s -> zone%03d present=%s scene_exists=%s confidence=%s frame=false" % [
			int(mapping.get("region_id", -1)),
			str(mapping.get("region_name", "")),
			int(mapping.get("client_zone_id", -1)),
			str(mapping.get("client_zone_present", false)),
			str(mapping.get("scene_godot_exists", false)),
			str(mapping.get("confidence", "")),
		])
	return "\n".join(lines)


func _normalize_os_path(path: String) -> String:
	var p: String = path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p
