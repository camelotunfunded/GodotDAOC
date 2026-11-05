extends RefCounted
class_name DaocWorldCoverageReport

const SCOPE: String = "P1-17E2O offline world coverage report"
const CHECKPOINT: String = "P1_17E2O_WORLD_COVERAGE_REPORT"

const DEFAULT_JSON_PATH: String = "res://reports/p1_17e2o_world_coverage.json"
const DEFAULT_TEXT_PATH: String = "res://reports/p1_17e2o_world_coverage.txt"
const DEFAULT_RECOMMENDATION_LIMIT: int = 12

var last_report: Dictionary = {}


func build_report(inventory: Dictionary, options: Dictionary = {}) -> Dictionary:
	var zones: Array = inventory.get("zones", []) as Array
	var recommendation_limit: int = int(options.get("recommendation_limit", DEFAULT_RECOMMENDATION_LIMIT))
	if recommendation_limit <= 0:
		recommendation_limit = DEFAULT_RECOMMENDATION_LIMIT
	var generated_by_kind: Dictionary = {}
	var missing_by_kind: Dictionary = {}
	var generated_zones: Array = []
	var missing_zones: Array = []
	for entry_value in zones:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var zone_id: int = int(entry.get("zone_id", -1))
		var zone_kind: String = str(entry.get("zone_kind", "unknown"))
		var generated_path: String = _expected_scene_path(zone_id, zone_kind)
		var generated_exists: bool = FileAccess.file_exists(generated_path)
		var row: Dictionary = {
			"zone_id": zone_id,
			"zone_name": str(entry.get("zone_name", "zone%03d" % zone_id)),
			"zone_kind": zone_kind,
			"generated_scene_path": generated_path,
			"generated_scene_exists": generated_exists,
			"runtime_enabled": false,
			"report_only": true,
		}
		if generated_exists:
			generated_by_kind[zone_kind] = int(generated_by_kind.get(zone_kind, 0)) + 1
			generated_zones.append(row)
		else:
			missing_by_kind[zone_kind] = int(missing_by_kind.get(zone_kind, 0)) + 1
			missing_zones.append(row)
	var mapping_coverage: Array = _build_mapping_coverage(inventory.get("region_zone_mapping", []) as Array)
	var recommended_batches: Dictionary = _build_recommendations(missing_zones, mapping_coverage, recommendation_limit)
	last_report = {
		"ok": bool(inventory.get("ok", false)),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_checkpoint": str(inventory.get("checkpoint", "")),
		"report_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"zone_count": int(inventory.get("zone_count", zones.size())),
		"kind_counts": inventory.get("kind_counts", {}),
		"generated_scene_present_count": generated_zones.size(),
		"missing_scene_count": missing_zones.size(),
		"generated_by_kind": generated_by_kind,
		"missing_by_kind": missing_by_kind,
		"generated_zones": generated_zones,
		"missing_zones": missing_zones,
		"region_mapping_coverage": mapping_coverage,
		"recommended_batches": recommended_batches,
		"notes": [
			"coverage report only; no zone generation performed",
			"server coordinates are not used as player spawns",
			"coordinate frame remains unconfirmed",
		],
	}
	return last_report


func export_last_report_json(path: String = DEFAULT_JSON_PATH) -> Dictionary:
	return _write_text(path, JSON.stringify(last_report, "  "), "json")


func export_last_report_text(path: String = DEFAULT_TEXT_PATH) -> Dictionary:
	return _write_text(path, _report_as_text(last_report), "text")


func _build_mapping_coverage(region_mapping: Array) -> Array:
	var out: Array = []
	for mapping_value in region_mapping:
		if typeof(mapping_value) != TYPE_DICTIONARY:
			continue
		var mapping: Dictionary = (mapping_value as Dictionary).duplicate(true)
		var zone_id: int = int(mapping.get("client_zone_id", -1))
		var zone_kind: String = str(mapping.get("zone_kind", "unknown"))
		var scene_path: String = _expected_scene_path(zone_id, zone_kind)
		mapping["expected_scene_path"] = scene_path
		mapping["scene_godot_path"] = scene_path
		mapping["scene_godot_exists"] = FileAccess.file_exists(scene_path)
		mapping["coverage_status"] = "scene_present_frame_unconfirmed" if bool(mapping.get("scene_godot_exists", false)) else "scene_missing_frame_unconfirmed"
		mapping["runtime_enabled"] = false
		mapping["coordinate_frame_confirmed"] = false
		mapping["player_spawn_applied"] = false
		out.append(mapping)
	return out


func _build_recommendations(missing_zones: Array, mapping_coverage: Array, limit: int) -> Dictionary:
	var terrain: Array = []
	var dungeons: Array = []
	var mapped_priority: Array = []
	for mapping_value in mapping_coverage:
		if typeof(mapping_value) != TYPE_DICTIONARY:
			continue
		var mapping: Dictionary = mapping_value as Dictionary
		if not bool(mapping.get("scene_godot_exists", false)):
			mapped_priority.append({
				"region_id": int(mapping.get("region_id", -1)),
				"region_name": str(mapping.get("region_name", "")),
				"zone_id": int(mapping.get("client_zone_id", -1)),
				"zone_name": str(mapping.get("client_zone_name", "")),
				"zone_kind": str(mapping.get("zone_kind", "")),
				"reason": "known RegionID mapping exists but generated scene is missing",
			})
	for zone_value in missing_zones:
		if typeof(zone_value) != TYPE_DICTIONARY:
			continue
		var zone: Dictionary = zone_value as Dictionary
		var kind: String = str(zone.get("zone_kind", "unknown"))
		if kind == "terrain_heightmap" and terrain.size() < limit:
			terrain.append(_zone_recommendation(zone, "terrain scene missing"))
		elif kind == "dungeon_chunk" and dungeons.size() < limit:
			dungeons.append(_zone_recommendation(zone, "dungeon scene missing"))
	return {
		"mapped_region_priority": mapped_priority,
		"next_terrain_zones": terrain,
		"next_dungeon_zones": dungeons,
		"limit": limit,
	}


func _zone_recommendation(zone: Dictionary, reason: String) -> Dictionary:
	return {
		"zone_id": int(zone.get("zone_id", -1)),
		"zone_name": str(zone.get("zone_name", "")),
		"zone_kind": str(zone.get("zone_kind", "")),
		"expected_scene_path": str(zone.get("generated_scene_path", "")),
		"reason": reason,
	}


func _expected_scene_path(zone_id: int, zone_kind: String) -> String:
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


func _report_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-17E2O offline world coverage report")
	lines.append("ok=%s zones=%d scenes_present=%d scenes_missing=%d" % [
		str(report.get("ok", false)),
		int(report.get("zone_count", 0)),
		int(report.get("generated_scene_present_count", 0)),
		int(report.get("missing_scene_count", 0)),
	])
	lines.append("kind_counts=%s" % str(report.get("kind_counts", {})))
	lines.append("generated_by_kind=%s" % str(report.get("generated_by_kind", {})))
	lines.append("missing_by_kind=%s" % str(report.get("missing_by_kind", {})))
	lines.append("region_mapping_coverage:")
	for mapping_value in (report.get("region_mapping_coverage", []) as Array):
		if typeof(mapping_value) != TYPE_DICTIONARY:
			continue
		var mapping: Dictionary = mapping_value as Dictionary
		lines.append("region=%d name=%s -> zone%03d scene_exists=%s status=%s frame=false" % [
			int(mapping.get("region_id", -1)),
			str(mapping.get("region_name", "")),
			int(mapping.get("client_zone_id", -1)),
			str(mapping.get("scene_godot_exists", false)),
			str(mapping.get("coverage_status", "")),
		])
	var recommendations: Dictionary = report.get("recommended_batches", {}) as Dictionary
	lines.append("mapped_region_priority=%d next_terrain=%d next_dungeon=%d" % [
		(recommendations.get("mapped_region_priority", []) as Array).size(),
		(recommendations.get("next_terrain_zones", []) as Array).size(),
		(recommendations.get("next_dungeon_zones", []) as Array).size(),
	])
	return "\n".join(lines)
