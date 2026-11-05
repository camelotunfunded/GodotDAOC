extends RefCounted
class_name DaocModelIdAssetOfflineReport

const Resolver = preload("res://src/daoc/assets/DaocModelIdAssetResolver.gd")
const REPORT_DIR := "res://reports/p1_20f_model_asset_resolver"
const CATALOG_PATH := "res://reports/p1_20e_nearby_world_offline/p1_20e_model_catalog.csv"

var resolver := Resolver.new()


func build(report_dir: String = REPORT_DIR, write_files: bool = true, root: String = "") -> Dictionary:
	var configured := resolver.configure(root)
	if not bool(configured.get("ok", false)):
		return {"ok": false, "error": configured.get("error", "resolver_configuration_failed")}
	var catalog := _load_catalog(CATALOG_PATH)
	var resolution := resolver.resolve_catalog(catalog)
	var models: Array = resolution.models
	var exact := models.filter(func(row): return str(row.status) == "RESOLVED_EXACT")
	var unresolved := models.filter(func(row): return str(row.status) == "UNRESOLVED")
	var candidate := models.filter(func(row): return str(row.status) == "CANDIDATE")
	var priority := _priority_models(models)
	var npc_count := models.filter(func(row): return str(row.asset_kind) == "npc").size()
	var object_count := models.filter(func(row): return str(row.asset_kind) == "object").size()
	var unique_nifs := {}
	for row in exact: unique_nifs[str(row.nif_path).to_lower()] = true
	var eden_audit := _read_json(report_dir.path_join("p1_20f_eden_dll_static_audit.json"))
	var test_result := _read_json(report_dir.path_join("p1_20f_test_result.json"))
	var passed := catalog.size() == 119 and exact.size() == 119 and unresolved.is_empty() and candidate.is_empty()
	var report := {
		"checkpoint": "P1-20F_MODEL_ID_TO_DAOC_ASSET_RESOLVER",
		"verdict": "PASS_MODEL_ID_TO_DAOC_ASSET_RESOLVER" if passed else "PARTIAL_MODEL_ID_TO_DAOC_ASSET_RESOLVER",
		"offline_only": true, "catalog_source": CATALOG_PATH, "observed_model_id_count": catalog.size(),
		"resolved_exact_count": exact.size(), "candidate_count": candidate.size(), "unresolved_count": unresolved.size(),
		"npc_or_player_model_count": npc_count, "object_model_count": object_count, "unique_nif_file_count": unique_nifs.size(),
		"priority_model_count": priority.size(), "all_observed_models_resolved": unresolved.is_empty(),
		"canonical_chains": {
			"npc_or_player": "model_id -> monsters.csv[NIF] -> monnifs.csv[Name] -> figures/<Name>.nif",
			"object": "model_id -> objects.csv[NIF] -> items.csv[Name] -> items/<Name>.nif",
		},
		"source_table_inventory": resolution.source_inventory,
		"client_asset_inventory": resolver.client_asset_inventory(),
		"eden_dll_static_audit_verdict": str(eden_audit.get("verdict", "AUDIT_NOT_AVAILABLE")),
		"eden_runtime_lookup_status": str(eden_audit.get("runtime_lookup_function", {}).get("status", "UNKNOWN")),
		"test_summary": {
			"passed": bool(test_result.get("passed", false)),
			"check_count": int(test_result.get("check_count", 0)),
			"failed_count": int(test_result.get("failed_count", 0)),
		},
		"network_access_performed": false, "gameplay_connection_performed": false, "udp_enabled": false,
		"nif_conversion_performed": false, "godot_scene_created": false, "world_placement_performed": false,
		"p1_20g_started": false,
	}
	if write_files:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
		_write_json(report_dir.path_join("p1_20f_offline_report.json"), report)
		_write_text(report_dir.path_join("p1_20f_offline_report.txt"), _summary(report, priority))
		_write_text(report_dir.path_join("p1_20f_summary.txt"), _summary(report, priority))
		_write_json(report_dir.path_join("p1_20f_model_asset_registry.json"), {"models": models})
		_write_text(report_dir.path_join("p1_20f_model_asset_registry.csv"), _models_csv(models))
		_write_text(report_dir.path_join("p1_20f_priority_models.csv"), _models_csv(priority))
		_write_text(report_dir.path_join("p1_20f_unresolved.csv"), _models_csv(unresolved))
		_write_text(report_dir.path_join("p1_20f_texture_sets.csv"), _textures_csv(models))
		_write_json(report_dir.path_join("p1_20f_source_tables.json"), resolution.source_inventory)
		_write_json(report_dir.path_join("p1_20f_client_asset_inventory.json"), resolver.client_asset_inventory())
	return {"ok": passed, "report": report, "models": models, "priority_models": priority,
		"unresolved": unresolved, "catalog": catalog}


func _load_catalog(path: String) -> Array:
	if not FileAccess.file_exists(path): return []
	var file := FileAccess.open(path, FileAccess.READ)
	var headers := file.get_csv_line(",")
	if not headers.is_empty(): headers[0] = str(headers[0]).trim_prefix("\ufeff")
	var out: Array = []
	while not file.eof_reached():
		var cells := file.get_csv_line(",")
		if cells.is_empty() or str(cells[0]).strip_edges().is_empty(): continue
		var row := {}
		for i in range(mini(headers.size(), cells.size())): row[str(headers[i])] = str(cells[i])
		row.model_id = int(row.get("model_id", 0)); row.entity_count = int(row.get("entity_count", 0))
		row.names = _split_pipe(str(row.get("names", ""))); row.example_object_ids = _split_pipe_int(str(row.get("example_object_ids", "")))
		row.equipment_model_ids = _split_pipe_int(str(row.get("equipment_model_ids", "")))
		row.minimum_distance = null if str(row.get("minimum_distance", "")).is_empty() else float(row.minimum_distance)
		row.maximum_distance = null if str(row.get("maximum_distance", "")).is_empty() else float(row.maximum_distance)
		out.append(row)
	file.close()
	return out


func _priority_models(models: Array) -> Array:
	var selected := {}
	var frequent := models.duplicate(); frequent.sort_custom(func(a, b): return int(a.entity_count) > int(b.entity_count))
	for row in frequent.slice(0, mini(25, frequent.size())): selected[int(row.model_id)] = row
	var nearest := models.filter(func(row): return row.minimum_distance != null)
	nearest.sort_custom(func(a, b): return float(a.minimum_distance) < float(b.minimum_distance))
	for row in nearest.slice(0, mini(25, nearest.size())): selected[int(row.model_id)] = row
	var out: Array = selected.values()
	out.sort_custom(func(a, b):
		var ad := INF if a.minimum_distance == null else float(a.minimum_distance)
		var bd := INF if b.minimum_distance == null else float(b.minimum_distance)
		return int(a.entity_count) > int(b.entity_count) if is_equal_approx(ad, bd) else ad < bd)
	return out


func _models_csv(models: Array) -> String:
	var lines := ["model_id,entity_type,entity_count,names,minimum_distance,resource_name,nif_path,texture_set,skeleton_path,skeleton_or_animation_set,resolution_source,source_entries,status,confidence,nif_sha256"]
	for row in models:
		var animation := "animation_set_id=%d;animation_set_name=%s;combat_animation_set_name=%s;skeleton_kind=%s" % [int(row.animation_set_id), str(row.animation_set_name), str(row.combat_animation_set_name), str(row.skeleton_kind)]
		var sources: Array[String] = []
		for source in row.source_chain: sources.append("%s:%d[id=%d]" % [source.file, int(source.line), int(source.id)])
		lines.append(",".join([str(row.model_id), _q(row.entity_type), str(row.get("entity_count", 0)), _q("|".join(row.get("names", []))),
			_float_or_blank(row.get("minimum_distance")), _q(row.resource_name), _q(row.nif_path), _q("|".join(row.texture_set)),
			_q(row.skeleton_path), _q(animation), _q(row.resolution_source), _q("|".join(sources)), row.status, _q(row.confidence), row.nif_sha256]))
	return "\ufeff" + "\n".join(lines) + "\n"


func _textures_csv(models: Array) -> String:
	var lines := ["model_id,resource_name,nif_path,texture,texture_sources"]
	for row in models:
		if row.texture_set.is_empty(): lines.append(",".join([str(row.model_id), _q(row.resource_name), _q(row.nif_path), "", _q("|".join(row.texture_sources))]))
		for texture in row.texture_set: lines.append(",".join([str(row.model_id), _q(row.resource_name), _q(row.nif_path), _q(texture), _q("|".join(row.texture_sources))]))
	return "\ufeff" + "\n".join(lines) + "\n"


func _summary(report: Dictionary, priority: Array) -> String:
	var sample: Array[String] = []
	for row in priority.slice(0, mini(12, priority.size())):
		sample.append("model_id=%d type=%s count=%d distance=%s resource=%s nif=%s status=%s" % [int(row.model_id), str(row.entity_type), int(row.entity_count), _float_or_blank(row.minimum_distance), str(row.resource_name), str(row.nif_path), str(row.status)])
	return "\n".join(["P1-20F model_id to DAoC asset resolver", "verdict=%s" % report.verdict,
		"observed=%d exact=%d candidates=%d unresolved=%d unique_nifs=%d" % [report.observed_model_id_count, report.resolved_exact_count, report.candidate_count, report.unresolved_count, report.unique_nif_file_count],
		"npc_or_player_models=%d object_models=%d" % [report.npc_or_player_model_count, report.object_model_count],
		"eden_dll=%s runtime_lookup=%s" % [report.eden_dll_static_audit_verdict, report.eden_runtime_lookup_status],
		"offline_tests_passed=%s checks=%d failures=%d" % [str(report.test_summary.passed).to_lower(), report.test_summary.check_count, report.test_summary.failed_count],
		"offline_only=true network_access_performed=false nif_conversion_performed=false p1_20g_started=false", "", "Priority models:"] + sample + [""])


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)); return parsed if parsed is Dictionary else {}

func _write_json(path: String, value: Variant) -> void: _write_text(path, JSON.stringify(value, "\t"))
func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(value)
		file.close()
func _q(value: Variant) -> String: return '"%s"' % str(value).replace('"', '""')
func _float_or_blank(value: Variant) -> String: return "" if value == null else "%.3f" % float(value)
func _split_pipe(value: String) -> Array:
	var out: Array = []
	for part in value.split("|", false):
		out.append(str(part))
	return out
func _split_pipe_int(value: String) -> Array:
	var out: Array = []
	for part in value.split("|", false):
		if str(part).is_valid_int(): out.append(int(part))
	return out
