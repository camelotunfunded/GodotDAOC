extends RefCounted
class_name DaocServerCoordinateFrameProbe

const DaocServerClientZoneMapScript = preload("res://src/daoc/world/DaocServerClientZoneMap.gd")

## P1-17E2F — probe abstrait de frame coordonnées serveur -> scène client.
## Ne confirme rien et n'applique aucun spawn. Il transforme seulement les
## destinations serveur candidates en tâches de validation manuelle.

const SCOPE: String = "P1-17E2F server coordinate frame probe"
const CHECKPOINT: String = "P1_17E2F_SERVER_COORDINATE_FRAME_PROBE"
const DEFAULT_PROBE_JSON_PATH: String = "res://reports/daoc_server_coordinate_frame_probe_p1_17e2f.json"
const DEFAULT_PROBE_TEXT_PATH: String = "res://reports/daoc_server_coordinate_frame_probe_p1_17e2f.txt"


const REGION_LABELS: Dictionary = {
	20: "Stonehenge Barrows",
	21: "Tomb of Mithra",
}

const DAOC_COORD_MIN: float = 0.0
const DAOC_COORD_MAX: float = 65535.0
const HEADING_RAW_MIN: int = 0
const HEADING_RAW_MAX: int = 4096

var last_probe: Dictionary = {}


func build_probe_report(sql_report: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var candidates: Array = _collect_destination_candidates(sql_report)
	var probes: Array = []
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		probes.append(probe_destination(candidate_value as Dictionary, options))
	var tasks: Array = build_manual_validation_tasks(probes)
	var report: Dictionary = {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"source_status": str(sql_report.get("status", "manual_or_fixture")),
		"candidate_count": candidates.size(),
		"probe_count": probes.size(),
		"manual_validation_task_count": tasks.size(),
		"probes": probes,
		"manual_validation_tasks": tasks,
		"decision": "do_not_apply_runtime_spawn_until_official_client_or_server_log_confirms_coordinate_frame",
		"required_external_evidence": [
			"client_official_loc_before_after_transition",
			"server_MoveTo_or_ZonePoint_log_for_same_transition",
			"visual_confirmation_in_generated_dungeon_scene",
		],
	}
	last_probe = report.duplicate(true)
	return report


func probe_destination(destination: Dictionary, options: Dictionary = {}) -> Dictionary:
	var region_id: int = int(destination.get("target_region_id", destination.get("region_id", 0)))
	var mapping: Dictionary = DaocServerClientZoneMapScript.new().call("resolve_region", region_id, {"allow_visible_zone_candidate_mapping": false}) as Dictionary
	var zone_id_client: int = int(mapping.get("client_zone_id", int(destination.get("target_zone_id", -1))))
	var x: float = float(destination.get("x", 0.0))
	var y: float = float(destination.get("y", 0.0))
	var z: float = float(destination.get("z", 0.0))
	var heading_raw: int = int(destination.get("heading_raw", destination.get("heading", 0)))
	var xy_in_daoc_range: bool = _in_range(x, DAOC_COORD_MIN, DAOC_COORD_MAX) and _in_range(y, DAOC_COORD_MIN, DAOC_COORD_MAX)
	var z_plausible: bool = _in_range(z, -4096.0, 32768.0)
	var heading_plausible: bool = heading_raw >= HEADING_RAW_MIN and heading_raw <= HEADING_RAW_MAX
	var has_known_region_mapping: bool = bool(mapping.get("ok", false))
	var has_xyz: bool = not (is_zero_approx(x) and is_zero_approx(y) and is_zero_approx(z))
	var status: String = "unmapped_region"
	if has_known_region_mapping and xy_in_daoc_range and z_plausible and heading_plausible and has_xyz:
		status = "plausible_server_destination_needs_frame_validation"
	elif has_known_region_mapping:
		status = "known_region_but_values_need_review"
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"status": status,
		"target_region_id": region_id,
		"target_region_label": str(REGION_LABELS.get(region_id, "unknown")),
		"expected_client_zone_id": zone_id_client,
		"expected_client_zone_name": "zone%03d" % zone_id_client if zone_id_client >= 0 else "unknown",
		"x": x,
		"y": y,
		"z": z,
		"heading_raw": heading_raw,
		"heading_deg_estimate": _heading_raw_to_deg(heading_raw),
		"xy_in_daoc_0_65535_range": xy_in_daoc_range,
		"z_plausible_server_range": z_plausible,
		"heading_plausible_0_4096": heading_plausible,
		"has_known_region_mapping": has_known_region_mapping,
		"has_nonzero_xyz": has_xyz,
		"source_table_id": str(destination.get("table_id", "")),
		"source_record_id": str(destination.get("record_id", "")),
		"authenticity": str(destination.get("authenticity", "server_db_imported_unconfirmed_frame")),
		"next_action": "compare_against_official_client_loc_and_generated_scene_marker",
	}


func build_manual_validation_tasks(probes: Array = []) -> Array:
	var tasks: Array = []
	for probe_value in probes:
		if typeof(probe_value) != TYPE_DICTIONARY:
			continue
		var probe: Dictionary = probe_value as Dictionary
		if not bool(probe.get("has_known_region_mapping", false)):
			continue
		var region_id: int = int(probe.get("target_region_id", 0))
		tasks.append({
			"scope": SCOPE,
			"checkpoint": CHECKPOINT,
			"abstract_only": true,
			"runtime_enabled": false,
			"coordinate_frame_confirmed": false,
			"target_region_id": region_id,
			"target_region_label": probe.get("target_region_label", ""),
			"expected_client_zone_id": probe.get("expected_client_zone_id", -1),
			"expected_client_zone_name": probe.get("expected_client_zone_name", ""),
			"server_xyz_heading": {
				"x": probe.get("x", 0.0),
				"y": probe.get("y", 0.0),
				"z": probe.get("z", 0.0),
				"heading_raw": probe.get("heading_raw", 0),
			},
			"manual_steps": [
				"ouvrir le client officiel sur le serveur de référence",
				"entrer/sortir du donjon correspondant",
				"noter /loc avant et après transition",
				"capturer le log serveur MoveTo/ZonePoint de la même transition",
				"poser un marker debug dans la scène Godot sans déplacer le joueur",
				"comparer orientation/entrée/sortie avant toute confirmation",
			],
		})
	return tasks


func export_last_probe_json(path: String = DEFAULT_PROBE_JSON_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_PROBE_JSON_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "error": "cannot open probe json for write"}
	file.store_string(JSON.stringify(last_probe, "  "))
	file.close()
	return {"ok": true, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func export_last_probe_text(path: String = DEFAULT_PROBE_TEXT_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_PROBE_TEXT_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "error": "cannot open probe text for write"}
	file.store_string(_probe_as_text(last_probe))
	file.close()
	return {"ok": true, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"last_probe": last_probe.duplicate(true),
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
	}


func _collect_destination_candidates(sql_report: Dictionary) -> Array:
	var out: Array = []
	var summary: Dictionary = sql_report.get("barrows_mithra_summary", {}) as Dictionary
	for key in ["barrows", "mithra"]:
		var part: Dictionary = summary.get(key, {}) as Dictionary
		var samples: Array = part.get("normalized_destination_samples", []) as Array
		for sample_value in samples:
			if typeof(sample_value) == TYPE_DICTIONARY:
				out.append((sample_value as Dictionary).duplicate(true))
	if out.is_empty():
		var tables: Array = sql_report.get("tables", []) as Array
		for table_value in tables:
			if typeof(table_value) != TYPE_DICTIONARY:
				continue
			var table: Dictionary = table_value as Dictionary
			var rows: Array = table.get("rows_sample", []) as Array
			for row_value in rows:
				if typeof(row_value) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_value as Dictionary
				var region_id: int = _row_first_int(row, ["TargetRegion", "RegionID", "Region", "region"])
				var row_mapping: Dictionary = DaocServerClientZoneMapScript.new().call("resolve_region", region_id, {"allow_visible_zone_candidate_mapping": false}) as Dictionary
				if bool(row_mapping.get("ok", false)):
					out.append({
						"backend": "opendaoc",
						"source": "opendaoc_sql_import_row_fallback",
						"authenticity": "server_db_imported_unconfirmed_frame",
						"coordinate_frame_confirmed": false,
						"runtime_enabled": false,
						"table_id": table.get("table_id", ""),
						"target_region_id": region_id,
						"x": _row_first_float(row, ["TargetX", "X", "XPos", "x"]),
						"y": _row_first_float(row, ["TargetY", "Y", "YPos", "y"]),
						"z": _row_first_float(row, ["TargetZ", "Z", "ZPos", "z"]),
						"heading_raw": _row_first_int(row, ["TargetHeading", "Heading", "heading"]),
					})
	return out


func _row_first_int(row: Dictionary, keys: Array) -> int:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0
	return int(value)


func _row_first_float(row: Dictionary, keys: Array) -> float:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0.0
	return float(value)


func _row_first_any(row: Dictionary, keys: Array):
	for key_value in keys:
		var key: String = str(key_value)
		if row.has(key):
			return row[key]
	return null


func _heading_raw_to_deg(raw: int) -> float:
	return fposmod(float(raw), 4096.0) * 360.0 / 4096.0


func _in_range(value: float, min_value: float, max_value: float) -> bool:
	return value >= min_value and value <= max_value


func _probe_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s" % str(report.get("scope", SCOPE)))
	lines.append("checkpoint=%s" % str(report.get("checkpoint", CHECKPOINT)))
	lines.append("candidate_count=%d probe_count=%d manual_validation_task_count=%d" % [int(report.get("candidate_count", 0)), int(report.get("probe_count", 0)), int(report.get("manual_validation_task_count", 0))])
	lines.append("runtime_enabled=%s coordinate_frame_confirmed=%s" % [str(report.get("runtime_enabled", false)), str(report.get("coordinate_frame_confirmed", false))])
	for probe_value in (report.get("probes", []) as Array):
		if typeof(probe_value) != TYPE_DICTIONARY:
			continue
		var probe: Dictionary = probe_value as Dictionary
		lines.append("region=%d zone=%s status=%s xyz=(%.1f, %.1f, %.1f) heading=%d" % [int(probe.get("target_region_id", 0)), str(probe.get("expected_client_zone_name", "")), str(probe.get("status", "")), float(probe.get("x", 0.0)), float(probe.get("y", 0.0)), float(probe.get("z", 0.0)), int(probe.get("heading_raw", 0))])
	lines.append("decision=%s" % str(report.get("decision", "")))
	return "\n".join(lines)
