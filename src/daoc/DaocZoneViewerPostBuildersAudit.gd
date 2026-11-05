extends RefCounted
class_name DaocZoneViewerPostBuildersAudit


## P1-15A — Audit statique léger de ZoneViewer après extraction 14A→14E.
## Ne modifie rien en scène. Sert uniquement aux notes/F12 pour décider le prochain refactor.

static func build_snapshot(zone_viewer: Node) -> Dictionary:
	var source := _read_text("res://ZoneViewer.gd")
	var functions := _function_names(source)
	var domains := _domain_counts(functions)
	var old_present := _present_old_extracted_methods(functions)
	var builder_status := _builder_runtime_status(zone_viewer)
	return {
		"scope": "P1-15A ZoneViewer post-builders audit",
		"source_path": "res://ZoneViewer.gd",
		"source_readable": source != "",
		"line_count": _line_count(source),
		"function_count": functions.size(),
		"export_count": _count_trimmed_prefix(source, "@export"),
		"var_count": _count_trimmed_prefix(source, "var "),
		"preload_count": _count_contains(source, "preload(\"res://"),
		"domains": domains,
		"old_extracted_methods_present": old_present,
		"extracted_builder_methods_absent": old_present.is_empty(),
		"builder_runtime_status": builder_status,
		"zoneviewer_role_now": "consumer/orchestrator/debug_shell_still_heavy",
		"recommended_next_step": "P1-15B ZoneSceneAssembler foundation",
		"recommended_next_scope": "extract zone construction orchestration/root parenting out of ZoneViewer; no terrain/eau/props/collision logic changes",
		"keep_in_zoneviewer": ["F12 entry point", "temporary debug commands", "public compatibility wrappers", "local test scene ownership"],
		"move_next": ["zone root construction", "builder call order", "builder result parentage", "runtime registry wiring", "zone-level debug snapshot aggregation"],
		"defer": ["DOL live", "new terrain shader", "multi-zone streaming", "vegetation rewrite", "real pregame UI"],
	}


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func _line_count(source: String) -> int:
	if source == "":
		return 0
	return source.split("\n", true).size()


static func _function_names(source: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw_line in source.split("\n", true):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("func "):
			continue
		var rest := line.substr(5)
		var paren := rest.find("(")
		if paren <= 0:
			continue
		out.append(rest.substr(0, paren))
	return out


static func _count_trimmed_prefix(source: String, prefix: String) -> int:
	var count := 0
	for raw_line in source.split("\n", true):
		if str(raw_line).strip_edges().begins_with(prefix):
			count += 1
	return count


static func _count_contains(source: String, needle: String) -> int:
	var count := 0
	for raw_line in source.split("\n", true):
		if str(raw_line).find(needle) >= 0:
			count += 1
	return count


static func _domain_counts(functions: PackedStringArray) -> Dictionary:
	var domains := {
		"orchestration_bootstrap": 0,
		"asset_model_texture_index": 0,
		"terrain_14e_wrappers": 0,
		"prop_14d_wrappers": 0,
		"collision_14c_wrappers": 0,
		"zonejump_runtime_debug": 0,
		"water_14b_wrappers": 0,
		"vegetation_legacy": 0,
		"legacy_lights": 0,
		"player_camera_hud": 0,
		"dol_offline_debug": 0,
		"misc_shared_helpers": 0,
	}
	for fn in functions:
		var name := str(fn)
		var domain := _domain_for_function(name)
		domains[domain] = int(domains.get(domain, 0)) + 1
	return domains


static func _domain_for_function(name: String) -> String:
	if name.find("opendaoc_db") >= 0:
		return "misc_shared_helpers"
	# Shared zone/dat lookup is still used by collision/zonejump/fixtures.
	# It is not vegetation implementation residue.
	if name == "_find_zone_dat_asset":
		return "asset_model_texture_index"
	if name.find("zonejump") >= 0:
		return "zonejump_runtime_debug"
	if _contains_any(name, ["grass", "vegetation", "pcx", "zone_dat", "stable_rand"]):
		return "vegetation_legacy"
	if name.find("light") >= 0:
		return "legacy_lights"
	if _contains_any(name, ["water", "sector_dat"]):
		return "water_14b_wrappers"
	if _contains_any(name, ["terrain", "splat", "sample_daoc_floor_z", "daoc_to_godot"]):
		return "terrain_14e_wrappers"
	if _contains_any(name, ["collision", "bound", "solve_daoc", "point_near_boundary"]):
		return "collision_14c_wrappers"
	if _contains_any(name, ["prop", "fixture", "template", "missing_marker"]):
		return "prop_14d_wrappers"
	if _contains_any(name, ["dol", "pregame"]):
		return "dol_offline_debug"
	if _contains_any(name, ["player", "camera", "hud", "targeting"]):
		return "player_camera_hud"
	if _contains_any(name, ["model", "texture", "path", "dir", "json", "csv", "dds", "image", "nif"]):
		return "asset_model_texture_index"
	if _contains_any(name, ["_ready", "_input", "_process", "_run_f12", "_build_zone", "_compute_base", "_load_placement", "_get_zone_root", "_zone_branch", "_origin"]):
		return "orchestration_bootstrap"
	return "misc_shared_helpers"


static func _contains_any(text: String, needles: Array) -> bool:
	for n in needles:
		if text.find(str(n)) >= 0:
			return true
	return false


static func _present_old_extracted_methods(functions: PackedStringArray) -> PackedStringArray:
	var old := PackedStringArray([
		"_build_zone_zonejumps",
		"_add_zonejump_area",
		"_build_zone_water",
		"_make_water_body_mesh",
		"_build_zone_bound_collision",
		"_add_bound_segment_collision",
		"_place_fixtures",
		"_place_fixture_boxes",
		"_build_zone_splat",
		"_build_sector_mesh",
		"_build_terrain_collision_from_indexed_mesh",
		"_sample_height",
		"_raw_at",
	])
	var present := PackedStringArray()
	for symbol in old:
		if functions.has(symbol):
			present.append(symbol)
	return present


static func _builder_runtime_status(zone_viewer: Node) -> Dictionary:
	return {
		"zonejump_build_results": _dict_size(zone_viewer, "_zonejump_build_results"),
		"water_build_results": _dict_size(zone_viewer, "_water_build_results"),
		"collision_build_results": _dict_size(zone_viewer, "_boundary_build_results"),
		"prop_build_results": _dict_size(zone_viewer, "_prop_build_results"),
		"terrain_build_results": _dict_size(zone_viewer, "_terrain_build_results"),
		"terrain_runtime_present": zone_viewer != null and zone_viewer.get("_terrain_runtime_obj") != null,
		"water_runtime_present": zone_viewer != null and zone_viewer.get("_water_runtime_obj") != null,
		"collision_runtime_present": zone_viewer != null and zone_viewer.get("_collision_runtime_obj") != null,
		"prop_runtime_present": zone_viewer != null and zone_viewer.get("_prop_runtime_obj") != null,
		"zonejump_runtime_present": zone_viewer != null and zone_viewer.get("_zonejump_runtime") != null,
	}


static func _dict_size(node: Node, property_name: String) -> int:
	if node == null:
		return -1
	var value: Variant = node.get(property_name)
	if typeof(value) != TYPE_DICTIONARY:
		return -1
	var dict := value as Dictionary
	return dict.size()
