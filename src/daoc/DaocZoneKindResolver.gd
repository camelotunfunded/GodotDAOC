extends RefCounted
class_name DaocZoneKindResolver

## P1-16A10A — classification explicite des familles de zones DAoC.
##
## Objectif : ne pas laisser le pipeline GeneratedZone prétendre couvrir les
## donjons, tileworld/villes ou formats inconnus. Les scènes générées restent
## supportées pour les zones extérieures heightmap ; les autres familles sont
## classées, loguées et refusées proprement jusqu'à builder dédié.

const SCOPE: String = "P1-16A10A zone kind classification manifest"
const CHECKPOINT: String = "P1_16A10A_ZONE_KIND_CLASSIFICATION_MANIFEST"

const KIND_TERRAIN_HEIGHTMAP: String = "terrain_heightmap"
const KIND_DUNGEON_CHUNK: String = "dungeon_chunk"
const KIND_TILEWORLD_CITY: String = "tileworld_city"
const KIND_TILEWORLD_FOOTPRINT: String = "tileworld_footprint"
const KIND_UNKNOWN: String = "unknown"

const STATUS_SUPPORTED: String = "supported_generated_scene"
const STATUS_UNSUPPORTED: String = "unsupported_yet"
const STATUS_SUPPORTED_DUNGEON: String = "supported_generated_dungeon_scene"
const STATUS_UNKNOWN: String = "unknown_unclassified"

const TERRAIN_MARKERS: Array = [
	"terrain.pcx",
	"offset.pcx",
	"fixtures.csv",
	"bound.csv",
	"zonejump.csv",
]
const DUNGEON_MARKERS: Array = [
	"dungeon.chunk",
	"dungeon.place",
	"dungeon.prop",
	"portals.csv",
]
const CITY_MARKERS: Array = [
	"CITY.CSV",
	"city.csv",
	"adjacency.csv",
]
const FOOTPRINT_MARKERS: Array = [
	"footprint.csv",
	"FOOTPRINT.CSV",
	"tile.csv",
	"TILE.CSV",
]


func classify_zone(host: Node, znum: int) -> Dictionary:
	var evidence: Dictionary = _collect_evidence(host, znum)
	var terrain_evidence: Array = _present_marker_names(evidence, TERRAIN_MARKERS)
	var dungeon_evidence: Array = _present_marker_names(evidence, DUNGEON_MARKERS)
	var city_evidence: Array = _present_marker_names(evidence, CITY_MARKERS)
	var footprint_evidence: Array = _present_marker_names(evidence, FOOTPRINT_MARKERS)
	var runtime: Dictionary = evidence.get("runtime", {}) as Dictionary

	var has_runtime_terrain: bool = int(runtime.get("terrain_meshes", 0)) > 0
	var has_runtime_props: bool = int(runtime.get("prop_nodes", 0)) > 0
	var has_runtime_boundary: bool = int(runtime.get("boundary_segments", 0)) > 0
	var has_terrain_files: bool = terrain_evidence.has("terrain.pcx") or terrain_evidence.has("offset.pcx")

	var zone_kind: String = KIND_UNKNOWN
	var status: String = STATUS_UNKNOWN
	var supported: bool = false
	var reason: String = "no known DAoC zone file family detected"
	var priority: int = 99

	if has_runtime_terrain or has_terrain_files:
		zone_kind = KIND_TERRAIN_HEIGHTMAP
		status = STATUS_SUPPORTED
		supported = true
		reason = "terrain/heightmap zone; covered by current Terrain/Water/Prop/Collision/ZoneJump builders"
		priority = 10
	elif not dungeon_evidence.is_empty():
		zone_kind = KIND_DUNGEON_CHUNK
		status = STATUS_UNSUPPORTED
		supported = false
		reason = "dungeon.chunk/place/prop family detected; DungeonChunkBuilder not implemented yet"
		priority = 20
	elif not city_evidence.is_empty():
		zone_kind = KIND_TILEWORLD_CITY
		status = STATUS_UNSUPPORTED
		supported = false
		reason = "CITY.CSV/adjacency tileworld family detected; TileWorld/CityBuilder not implemented yet"
		priority = 30
	elif not footprint_evidence.is_empty():
		zone_kind = KIND_TILEWORLD_FOOTPRINT
		status = STATUS_UNSUPPORTED
		supported = false
		reason = "tile/footprint family detected; footprint builder not implemented yet"
		priority = 40

	var ready_full_export: bool = supported and has_runtime_terrain and has_runtime_props and has_runtime_boundary
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"zone_id": znum,
		"zone_name": "zone%03d" % znum,
		"zone_kind": zone_kind,
		"generated_scene_status": status,
		"supported_for_generated_scene": supported,
		"ready_full_export": ready_full_export,
		"reason": reason,
		"priority": priority,
		"terrain_markers_present": terrain_evidence,
		"dungeon_markers_present": dungeon_evidence,
		"city_markers_present": city_evidence,
		"footprint_markers_present": footprint_evidence,
		"evidence": evidence,
	}


func classify_zones(host: Node, zone_ids: Array) -> Dictionary:
	var normalized: Array = []
	for raw_zone in zone_ids:
		var znum: int = int(raw_zone)
		if znum < 0 or normalized.has(znum):
			continue
		normalized.append(znum)
	normalized.sort()

	var entries: Array = []
	var supported: Array = []
	var unsupported: Array = []
	var unknown: Array = []
	var kind_counts: Dictionary = {}
	for zone_value in normalized:
		var entry: Dictionary = classify_zone(host, int(zone_value))
		entries.append(entry)
		var kind: String = str(entry.get("zone_kind", KIND_UNKNOWN))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		if bool(entry.get("supported_for_generated_scene", false)):
			supported.append(int(zone_value))
		elif kind == KIND_UNKNOWN:
			unknown.append(int(zone_value))
		else:
			unsupported.append(int(zone_value))
	return {
		"schema": "daoc.zone_kind_manifest.v1",
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"ok": true,
		"zone_count": normalized.size(),
		"zones": entries,
		"zone_ids": normalized,
		"supported_zones": supported,
		"unsupported_zones": unsupported,
		"unknown_zones": unknown,
		"supported_count": supported.size(),
		"unsupported_count": unsupported.size(),
		"unknown_count": unknown.size(),
		"kind_counts": kind_counts,
		"generated_scene_primary_allowed_only_for": [KIND_TERRAIN_HEIGHTMAP],
		"recommended_next_step": "P1-16A10B generated primary only for terrain_heightmap; dungeon/tileworld stay fallback until builders exist",
	}


func is_generated_scene_supported(host: Node, znum: int) -> bool:
	return bool(classify_zone(host, znum).get("supported_for_generated_scene", false))


func unsupported_reason(host: Node, znum: int) -> String:
	return str(classify_zone(host, znum).get("reason", ""))


func _collect_evidence(host: Node, znum: int) -> Dictionary:
	var files: Dictionary = {}
	var all_markers: Array = []
	for marker in TERRAIN_MARKERS:
		all_markers.append(str(marker))
	for marker in DUNGEON_MARKERS:
		all_markers.append(str(marker))
	for marker in CITY_MARKERS:
		all_markers.append(str(marker))
	for marker in FOOTPRINT_MARKERS:
		all_markers.append(str(marker))
	for marker_value in all_markers:
		var marker_name: String = str(marker_value)
		files[marker_name] = _find_zone_file(host, znum, marker_name)
	return {
		"files": files,
		"runtime": _runtime_evidence(host, znum),
		"data_dir": _effective_data_dir_from_host(host),
		"daoc_root": _effective_daoc_root_from_host(host),
	}


func _present_marker_names(evidence: Dictionary, markers: Array) -> Array:
	var files: Dictionary = evidence.get("files", {}) as Dictionary
	var out: Array = []
	for marker_value in markers:
		var marker_name: String = str(marker_value)
		if str(files.get(marker_name, "")) != "":
			out.append(marker_name)
	return out


func _runtime_evidence(host: Node, znum: int) -> Dictionary:
	return {
		"terrain_meshes": _zone_result_array_size(host, "_terrain_build_results", znum, "terrain_meshes"),
		"terrain_collision_bodies": _zone_result_array_size(host, "_terrain_build_results", znum, "collision_bodies"),
		"water_meshes": _zone_result_array_size(host, "_water_build_results", znum, "meshes"),
		"prop_nodes": _zone_result_array_size(host, "_prop_build_results", znum, "prop_nodes"),
		"boundary_segments": _zone_result_array_size(host, "_boundary_build_results", znum, "boundary_segments"),
		"zonejump_entries": _zone_result_array_size(host, "_zonejump_build_results", znum, "static_index"),
	}


func _zone_result_array_size(host: Node, property_name: String, znum: int, array_name: String) -> int:
	if host == null:
		return 0
	var value: Variant = host.get(property_name)
	if typeof(value) != TYPE_DICTIONARY:
		return 0
	var dict: Dictionary = value as Dictionary
	var item: Variant = null
	if dict.has(znum):
		item = dict.get(znum)
	elif dict.has(str(znum)):
		item = dict.get(str(znum))
	if typeof(item) != TYPE_OBJECT:
		return 0
	var obj: Object = item as Object
	var arr_value: Variant = obj.get(array_name)
	if typeof(arr_value) == TYPE_ARRAY:
		return (arr_value as Array).size()
	return 0


func _find_zone_file(host: Node, znum: int, file_name: String) -> String:
	if host != null and host.has_method("_asset_zone_file_15d"):
		var from_host: String = str(host.call("_asset_zone_file_15d", znum, file_name))
		if from_host != "":
			return from_host
	if host != null and host.has_method("_find_zone_dat_asset"):
		var legacy: String = str(host.call("_find_zone_dat_asset", znum, file_name))
		if legacy != "":
			return legacy
	var candidates: Array = _candidate_paths(host, znum, file_name)
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		if candidate != "" and FileAccess.file_exists(candidate):
			return candidate
	return ""


func _candidate_paths(host: Node, znum: int, file_name: String) -> Array:
	var out: Array = []
	var data_dir: String = _effective_data_dir_from_host(host)
	var root: String = _effective_daoc_root_from_host(host)
	var zp: String = "zone%03d" % znum
	var dp: String = "dat%03d" % znum
	var cp: String = "csv%03d" % znum
	var variants: Array = _file_name_variants(file_name)
	for variant_value in variants:
		var variant: String = str(variant_value)
		if data_dir != "":
			out.append(data_dir.path_join("zone%03d_%s" % [znum, variant]))
			out.append(data_dir.path_join(zp).path_join(variant))
			out.append(data_dir.path_join(zp).path_join(dp).path_join(variant))
			out.append(data_dir.path_join(zp).path_join(cp).path_join(variant))
			out.append(data_dir.path_join(dp).path_join(variant))
			out.append(data_dir.path_join(cp).path_join(variant))
			out.append(data_dir.path_join(variant))
		if root != "":
			for zone_root in [
				root.path_join("zones").path_join(zp),
				root.path_join("frontiers/zones").path_join(zp),
				root.path_join("phousing/zones").path_join(zp),
				root.path_join("tutorial/zones").path_join(zp),
				root.path_join("zones"),
				root.path_join("frontiers/zones"),
				root.path_join("phousing/zones"),
				root.path_join("tutorial/zones"),
			]:
				out.append(zone_root.path_join(dp).path_join(variant))
				out.append(zone_root.path_join(cp).path_join(variant))
				out.append(zone_root.path_join("dat").path_join(variant))
				out.append(zone_root.path_join("csv").path_join(variant))
				out.append(zone_root.path_join("terrain").path_join(variant))
				out.append(zone_root.path_join(variant))
	return out


func _file_name_variants(file_name: String) -> Array:
	var out: Array = []
	var lower: String = file_name.to_lower()
	var upper: String = file_name.to_upper()
	for value in [file_name, lower, upper]:
		if not out.has(str(value)):
			out.append(str(value))
	return out


func _effective_data_dir_from_host(host: Node) -> String:
	var direct: String = _host_string(host, "external_data_dir")
	if direct != "":
		return _norm_path(direct)
	var root: String = _effective_daoc_root_from_host(host)
	if root != "":
		return root.path_join("_godot_daoc_cache").path_join("data")
	return "res://data"


func _effective_daoc_root_from_host(host: Node) -> String:
	var root: String = _norm_path(_host_string(host, "daoc_client_root"))
	if root != "":
		return root
	var d: String = _norm_path(_host_string(host, "external_data_dir"))
	var marker: String = "/_godot_daoc_cache/data"
	if d.to_lower().ends_with(marker):
		return d.substr(0, d.length() - marker.length())
	return ""


func _host_string(host: Node, property_name: String) -> String:
	if host == null:
		return ""
	var value: Variant = host.get(property_name)
	if value == null:
		return ""
	return str(value).strip_edges().replace("\\", "/")


func _norm_path(path: String) -> String:
	var p: String = path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p
