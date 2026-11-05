extends Node
class_name DaocCommandRouter

const DaocDebugOutputLimiterScript = preload("res://src/daoc/DaocDebugOutputLimiter.gd")
const DaocZoneCreatorScript = preload("res://src/daoc/DaocZoneCreator.gd")
const DaocGeneratedZoneSceneLoaderScript = preload("res://src/daoc/DaocGeneratedZoneSceneLoader.gd")
const DaocGeneratedZoneRuntimeBridgeScript = preload("res://src/daoc/DaocGeneratedZoneRuntimeBridge.gd")
const DaocGeneratedDungeonRuntimeBridgeScript = preload("res://src/daoc/dungeon/DaocGeneratedDungeonRuntimeBridge.gd")
const DaocZoneKindResolverScript = preload("res://src/daoc/DaocZoneKindResolver.gd")
const DaocOpenDaocSqlImportScript = preload("res://src/daoc/serverdb/DaocOpenDaocSqlImport.gd")
const DaocServerCoordinateFrameProbeScript = preload("res://src/daoc/serverdb/DaocServerCoordinateFrameProbe.gd")
const DaocServerCoordinateMarkerPlanScript = preload("res://src/daoc/serverdb/DaocServerCoordinateMarkerPlan.gd")
const DaocServerLiveCaptureProbeScript = preload("res://src/daoc/serverdb/DaocServerLiveCaptureProbe.gd")
const DaocOfflineCombatLabScript = preload("res://src/daoc/gameplay/lab/DaocOfflineCombatLab.gd")
const DaocOpenDaocLiveComparisonHarnessScript = preload("res://src/daoc/gameplay/live/DaocOpenDaocLiveComparisonHarness.gd")
const DaocPlayerVisualMeshySwapScript = preload("res://src/daoc/player/DaocPlayerVisualMeshySwap.gd")
const DaocGroundingServiceScript = preload("res://src/daoc/player/DaocGroundingService.gd")
const DaocAssetMaterialFidelityAuditScript = preload("res://src/daoc/audit/DaocAssetMaterialFidelityAudit.gd")
const DaocNifImportConversionProbeScript = preload("res://src/daoc/audit/DaocNifImportConversionProbe.gd")
const DaocGeneratedSceneParityAuditScript = preload("res://src/daoc/audit/DaocGeneratedSceneParityAudit.gd")
const DaocOfflineWorldPreviewScript = preload("res://src/daoc/offline/DaocOfflineWorldPreview.gd")
const DaocServerClientZoneMapScript = preload("res://src/daoc/world/DaocServerClientZoneMap.gd")
const A7_ZONECREATOR_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"


## Slash commands locales non destructives.
## Les commandes réseau/serveur restent des stubs.

var player_camera: Node = null
var player: Node = null
var zone_viewer: Node = null
var targeting: Node = null
var dol_client: Node = null
var _debug_output_limiter: RefCounted = null
var _generated_zone_runtime_bridge_a9: RefCounted = null
var _generated_dungeon_runtime_bridge_17d: RefCounted = null
var _opendaoc_sql_importer_e2e: RefCounted = null
var _server_coordinate_probe_e2f: RefCounted = null
var _server_marker_plan_e2j: RefCounted = null
var _offline_world_preview_e2p: RefCounted = null
var _server_client_zone_map_f1: RefCounted = null
var _server_live_capture_f6: RefCounted = null
var _offline_combat_lab_p1_18b: RefCounted = null
var _opendaoc_live_comparison_p1_18l: RefCounted = null
var _player_visual_meshy_p1_18m: RefCounted = null
var _player_visual_meshy_config_p1_18m: Dictionary = {}
var _asset_material_audit_p1_18n_obj: RefCounted = null
var _nif_import_probe_p1_18n_hf6_obj: RefCounted = null


func setup(p_camera: Node, p_player: Node = null, p_zone_viewer: Node = null, p_targeting: Node = null, p_dol_client: Node = null) -> void:
	player_camera = p_camera
	player = p_player
	zone_viewer = p_zone_viewer
	targeting = p_targeting
	dol_client = p_dol_client


func set_dol_client(p_dol_client: Node) -> void:
	dol_client = p_dol_client


func _limiter() -> RefCounted:
	if _debug_output_limiter == null:
		_debug_output_limiter = DaocDebugOutputLimiterScript.new()
	return _debug_output_limiter


func _print_safe(value: Variant, max_chars: int = 900) -> void:
	var text := str(_limiter().call("compact_text", str(value), max_chars, 24))
	print(text)


func _compact_value(value: Variant, max_chars: int = 900) -> String:
	return str(_limiter().call("compact_value", value, max_chars, 2))


func has_debug_output_governor() -> bool:
	return _limiter() != null


func execute_command(text: String) -> bool:
	var raw := text.strip_edges()
	var cmd := raw.to_lower()
	if cmd.begins_with("/zonecreator") or cmd.begins_with("/zc"):
		return _cmd_zonecreator(raw)
	if cmd.begins_with("/generateddungeon") or cmd.begins_with("/gdungeon"):
		return _cmd_generated_dungeon_17d(raw)
	if cmd.begins_with("/opendaocdb") or cmd.begins_with("/odb"):
		return _cmd_opendaocdb_e2e(raw)
	if cmd.begins_with("/offlinepreview") or cmd.begins_with("/opreview"):
		return _cmd_offline_preview_e2p(raw)
	if cmd.begins_with("/servercapture") or cmd.begins_with("/scapture"):
		return _cmd_server_capture_f6(raw)
	if cmd.begins_with("/playervisual") or cmd.begins_with("/pvisual") or cmd.begins_with("/meshy"):
		return _cmd_player_visual_meshy_p1_18m(raw)
	if cmd.begins_with("/grounding"):
		return _cmd_grounding_p1_18p(raw)
	if cmd.begins_with("/feetalign"):
		return _cmd_feet_align_p1_18p(raw)
	if cmd.begins_with("/assetaudit") or cmd.begins_with("/aaudit"):
		return _cmd_asset_material_audit_p1_18n(raw)
	if cmd.begins_with("/nifprobe"):
		return _cmd_nif_import_probe_p1_18n_hf6(raw)
	if cmd.begins_with("/combatlab") or cmd.begins_with("/clab"):
		return _cmd_combat_lab_p1_18b(raw)
	if cmd.begins_with("/servermarkers") or cmd.begins_with("/smarkers"):
		return _cmd_server_markers_e2j(raw)
	if cmd.begins_with("/generated") or cmd.begins_with("/gzone"):
		return _cmd_generated_zone(raw)
	if cmd.begins_with("/zonejump") or cmd.begins_with("/zj"):
		return _cmd_zonejump_debug(raw)
	if cmd.begins_with("/dol loginpacket"):
		return _cmd_dol_loginpacket(raw)
	if cmd.begins_with("/dol login") or cmd.begins_with("/login"):
		return _cmd_dol_login(_third_token_or_default(raw, "debug"))
	if cmd.begins_with("/dol charlist") or cmd == "/charlist":
		return _cmd_dol_charlist()
	if cmd.begins_with("/dol enter") or cmd == "/enterworld":
		return _cmd_dol_enter_world(_third_token_int_or_default(raw, 0))
	if cmd.begins_with("/dol pos") or cmd == "/net pos" or cmd == "/sendpos":
		return _cmd_dol_position()
	if cmd.begins_with("/dol heading") or cmd == "/net heading":
		return _cmd_dol_heading()
	if cmd.begins_with("/dol realm"):
		return _cmd_dol_realm(raw)
	if cmd.begins_with("/dol worldloading") or cmd.begins_with("/dol enterloading"):
		return _cmd_dol_worldloading(raw)
	if cmd.begins_with("/dol loading"):
		return _cmd_dol_loading(raw)
	if cmd.begins_with("/dol uiflow") or cmd.begins_with("/dol ui"):
		return _cmd_dol_uiflow(raw)
	if cmd.begins_with("/dol region") or cmd.begins_with("/net region"):
		return _cmd_dol_region(_third_token_int_or_default(raw, -1), _fourth_token_int_or_default(raw, -1))
	if cmd.begins_with("/dol tcp") or cmd.begins_with("/net tcp"):
		return _cmd_dol_tcp_status()
	if cmd.begins_with("/dol packet") or cmd.begins_with("/net packet"):
		return _cmd_dol_packet_status()
	if cmd.begins_with("/dol wire") or cmd.begins_with("/net wire"):
		return _cmd_dol_wire_status()
	if cmd.begins_with("/dol charpacket"):
		return _cmd_dol_charpacket(raw)
	if cmd.begins_with("/dol selectpacket"):
		return _cmd_dol_selectpacket(raw)
	if cmd.begins_with("/dol worldpacket"):
		return _cmd_dol_worldpacket()
	if cmd.begins_with("/dol flow"):
		return _cmd_dol_flow(raw)
	if cmd.begins_with("/dol rx") or cmd.begins_with("/dol serverpacket"):
		return _cmd_dol_server_fixtures(raw)
	if cmd.begins_with("/dol assets") or cmd.begins_with("/dol asset"):
		return _cmd_dol_assets(raw)
	if cmd.begins_with("/dol charhud"):
		return _cmd_dol_charhud(raw)
	if cmd.begins_with("/dol selected"):
		return _cmd_dol_selected(raw)
	if cmd.begins_with("/dol unchoose"):
		return _cmd_dol_unchoose(raw)
	if cmd.begins_with("/dol rollbackbootstrap") or cmd.begins_with("/dol rollback"):
		return _cmd_dol_rollbackbootstrap(raw)
	if cmd.begins_with("/dol applybootstrap"):
		return _cmd_dol_applybootstrap(raw)
	if cmd.begins_with("/dol charview"):
		return _cmd_dol_charview(raw)
	if cmd.begins_with("/dol choose"):
		return _cmd_dol_choose(raw)
	if cmd.begins_with("/dol bootstrap"):
		return _cmd_dol_bootstrap(raw)
	match cmd:
		"/resetcamera":
			return _cmd_resetcamera()
		"/setcamera":
			return _cmd_setcamera()
		"/snapback on":
			return _cmd_snapback(true)
		"/snapback off":
			return _cmd_snapback(false)
		"/loc", "/where":
			return _cmd_loc()
		"/stuck":
			return _cmd_stuck_local()
		"/targetnearest", "/nearestobject":
			return _cmd_target_nearest()
		"/targetjump", "/nearestjump":
			return _cmd_target_nearest_zonejump()
		"/zonejump", "/zonejump status", "/zj", "/zj status":
			return _cmd_zonejump_debug(raw)
		"/zonejump last", "/zj last":
			return _cmd_zonejump_debug(raw)
		"/cleartarget":
			return _cmd_clear_target()
		"/target":
			return _cmd_target_status()
		"/targetnpc", "/targetliving":
			return _cmd_target_nearest_living_p1_21a()
		"/attack":
			return _cmd_toggle_attack_p1_21a()
		"/stat", "/combat":
			return _cmd_combat_status_p1_21a()
		"/dol", "/dol status", "/net", "/net status":
			return _cmd_dol_status()
		"/dol connect":
			return _cmd_dol_login("debug")
		"/dol disconnect", "/logout":
			return _cmd_dol_disconnect()
		"/hud on":
			return _set_node_bool("DaocDevHud", "visible", true)
		"/hud off":
			return _set_node_bool("DaocDevHud", "visible", false)
		"/debuginput on":
			return _set_node_bool("DaocInputRouter", "debug_input", true)
		"/debuginput off":
			return _set_node_bool("DaocInputRouter", "debug_input", false)
		"/debugcollision on":
			return _set_zone_viewer_bool("log_collision", true)
		"/debugcollision off":
			return _set_zone_viewer_bool("log_collision", false)
		"/debugwater on":
			return _set_zone_viewer_bool("log_water", true)
		"/debugwater off":
			return _set_zone_viewer_bool("log_water", false)
	return false



func _opendaoc_sql_importer() -> RefCounted:
	if _opendaoc_sql_importer_e2e == null:
		_opendaoc_sql_importer_e2e = DaocOpenDaocSqlImportScript.new()
		if _opendaoc_sql_importer_e2e != null and _opendaoc_sql_importer_e2e.has_method("load_slot_db"):
			_opendaoc_sql_importer_e2e.call("load_slot_db")
	return _opendaoc_sql_importer_e2e


func _server_coordinate_probe() -> RefCounted:
	if _server_coordinate_probe_e2f == null:
		_server_coordinate_probe_e2f = DaocServerCoordinateFrameProbeScript.new()
	return _server_coordinate_probe_e2f


func _server_marker_plan() -> RefCounted:
	if _server_marker_plan_e2j == null:
		_server_marker_plan_e2j = DaocServerCoordinateMarkerPlanScript.new()
	return _server_marker_plan_e2j


func _offline_world_preview() -> RefCounted:
	if _offline_world_preview_e2p == null:
		_offline_world_preview_e2p = DaocOfflineWorldPreviewScript.new()
	return _offline_world_preview_e2p


func _server_client_zone_map() -> RefCounted:
	if _server_client_zone_map_f1 == null:
		_server_client_zone_map_f1 = DaocServerClientZoneMapScript.new()
	return _server_client_zone_map_f1


func _server_live_capture() -> RefCounted:
	if _server_live_capture_f6 == null:
		_server_live_capture_f6 = DaocServerLiveCaptureProbeScript.new()
	return _server_live_capture_f6

func _opendaoc_live_comparison() -> RefCounted:
	if _opendaoc_live_comparison_p1_18l == null:
		_opendaoc_live_comparison_p1_18l = DaocOpenDaocLiveComparisonHarnessScript.new()
	return _opendaoc_live_comparison_p1_18l


func _cmd_server_capture_f6(raw: String) -> bool:
	var lower = raw.to_lower()
	var capture := _server_live_capture()
	if capture == null:
		_print_safe("/servercapture missing")
		return false
	if lower == "/servercapture" or lower == "/scapture" or lower.contains("help"):
		_print_safe("/servercapture status | report | probe [host] [port] -- version-probe only, no login, no player spawn, coordinate_frame_confirmed=false")
		return true
	var options := _server_capture_options_f6(raw)
	var transport := _get_dol_transport_1127()
	var wire := _get_dol_wire_1127()
	var report: Dictionary
	if lower.contains("probe"):
		options["allow_network_probe"] = true
		report = capture.call("attempt_local_probe", dol_client, transport, wire, options) as Dictionary
	else:
		report = capture.call("build_readiness_report", dol_client, transport, wire, options) as Dictionary
	var json_export: Dictionary = capture.call("export_last_report_json") as Dictionary
	var txt_export: Dictionary = capture.call("export_last_report_text") as Dictionary
	var guard: Dictionary = report.get("guardrails", {}) as Dictionary
	_print_safe("/servercapture ok=%s ready=%s attempted=%s connected=%s sent_probe=%s rx_bytes=%d rx_packets=%d host=%s port=%d json=%s txt=%s frame=%s runtime=%s spawn=%s" % [
		str(report.get("ok", false)),
		str(report.get("capture_ready", false)),
		str(report.get("live_probe_attempted", false)),
		str(report.get("connected", false)),
		str(report.get("sent_version_probe", false)),
		int(report.get("received_bytes", 0)),
		int(report.get("received_packet_count", 0)),
		str(report.get("host", "")),
		int(report.get("port", 0)),
		str(json_export.get("path", "")),
		str(txt_export.get("path", "")),
		str(guard.get("coordinate_frame_confirmed", true)),
		str(guard.get("runtime_enabled", true)),
		str(guard.get("player_spawn_applied", true)),
	], 2400)
	return true


func _server_capture_options_f6(raw: String) -> Dictionary:
	var parts: PackedStringArray = raw.split(" ", false)
	var options := {}
	for i in range(1, parts.size()):
		var token := str(parts[i]).strip_edges()
		if token == "" or token.to_lower() == "status" or token.to_lower() == "report" or token.to_lower() == "probe":
			continue
		if token.is_valid_int():
			options["port"] = int(token)
		elif token.contains("="):
			var pair := token.split("=", false, 1)
			if pair.size() == 2:
				var key := str(pair[0]).strip_edges().to_lower()
				var value := str(pair[1]).strip_edges()
				if key == "host":
					options["host"] = value
				elif key == "port" and value.is_valid_int():
					options["port"] = int(value)
				elif key == "timeout" and value.is_valid_int():
					options["timeout_msec"] = int(value)
		else:
			options["host"] = token
	return options


func _get_dol_transport_1127() -> Node:
	if dol_client != null:
		var transport = dol_client.get("transport")
		if transport != null:
			return transport as Node
	if zone_viewer != null:
		var viewer_transport = zone_viewer.get("_dol_transport")
		if viewer_transport != null:
			return viewer_transport as Node
	return null


func _get_dol_wire_1127() -> Node:
	if dol_client != null:
		var wire = dol_client.get("wire_1127")
		if wire != null:
			return wire as Node
	if zone_viewer != null:
		var viewer_wire = zone_viewer.get("_dol_wire_1127")
		if viewer_wire != null:
			return viewer_wire as Node
	return null


func _build_server_marker_plan_from_db_e2j() -> Dictionary:
	var importer := _opendaoc_sql_importer()
	var probe := _server_coordinate_probe()
	var planner := _server_marker_plan()
	if importer == null or probe == null or planner == null:
		return {"ok": false, "error": "missing importer/probe/planner", "runtime_enabled": false, "coordinate_frame_confirmed": false, "player_spawn_applied": false}
	var report: Dictionary = importer.call("parse_configured_directory", "", _opendaocdb_candidate_paths_from_viewer()) as Dictionary
	if str(report.get("status", "")) == "waiting_for_local_sql_directory":
		return {"ok": false, "error": "waiting_for_local_sql_directory", "report": report, "runtime_enabled": false, "coordinate_frame_confirmed": false, "player_spawn_applied": false}
	var probe_report: Dictionary = probe.call("build_probe_report", report) as Dictionary
	var plan: Dictionary = planner.call("build_marker_plan", probe_report, {"dungeon_world_scale": 0.10, "runtime_scale_compensation": 10.0, "marker_lift_raw": 160.0}) as Dictionary
	planner.call("export_last_plan_json")
	planner.call("export_last_plan_text")
	return plan


func _cmd_server_markers_e2j(raw: String) -> bool:
	var lower = raw.to_lower()
	if lower == "/servermarkers" or lower == "/smarkers" or lower.contains("help"):
		_print_safe("/servermarkers report | bake <zone> [optional_scene_path] — marker-only, uses OpenDAoC DB candidates, no player spawn, coordinate_frame_confirmed=false")
		return true
	var planner := _server_marker_plan()
	if planner == null:
		_print_safe("/servermarkers missing marker planner")
		return false
	var plan: Dictionary = _build_server_marker_plan_from_db_e2j()
	if not bool(plan.get("ok", false)):
		_print_safe("/servermarkers plan failed: %s" % str(plan.get("error", "unknown")), 1800)
		return true
	if lower.contains("status"):
		var compact_status: Dictionary = planner.call("build_compact_report", plan) as Dictionary
		_print_safe("/servermarkers status source=%s markers=%d marker_only=%s runtime=%s frame=%s spawn=%s evidence_required=%s" % [
			str(compact_status.get("source_status", "")),
			int(compact_status.get("marker_count", 0)),
			str(compact_status.get("marker_only", true)),
			str(compact_status.get("runtime_enabled", false)),
			str(compact_status.get("coordinate_frame_confirmed", false)),
			str(compact_status.get("player_spawn_applied", false)),
			str(compact_status.get("requires_coordinate_frame_validation", true)),
		], 2200)
		return true
	if lower.contains("list"):
		var compact_list: Dictionary = planner.call("build_compact_report", plan) as Dictionary
		var lines: Array = ["/servermarkers list marker_count=%d frame=false spawn=false" % int(compact_list.get("marker_count", 0))]
		for marker_value in (compact_list.get("markers", []) as Array):
			if typeof(marker_value) != TYPE_DICTIONARY:
				continue
			var marker: Dictionary = marker_value as Dictionary
			var p: Dictionary = marker.get("scene_local_marker_position", {}) as Dictionary
			lines.append("region=%d zone%03d record=%s scene_marker=(%.2f, %.2f, %.2f) heading=%d status=%s" % [
				int(marker.get("target_region_id", 0)),
				int(marker.get("client_zone_id", -1)),
				str(marker.get("source_record_id", "")),
				float(p.get("x", 0.0)),
				float(p.get("y", 0.0)),
				float(p.get("z", 0.0)),
				int(marker.get("heading_raw", 0)),
				str(marker.get("status", "")),
			])
		_print_safe("\n".join(lines), 2600)
		return true
	if lower.contains("explain"):
		var compact_explain: Dictionary = planner.call("build_compact_report", plan) as Dictionary
		_print_safe("/servermarkers explain confirmed=%s not_confirmed=%s placement=%s decision=debug markers only; do not spawn until external evidence confirms the coordinate frame" % [
			_compact_value(compact_explain.get("confirmed", []), 700),
			_compact_value(compact_explain.get("not_confirmed", []), 700),
			str(compact_explain.get("placement_assumption", "")),
		], 2400)
		return true
	if lower.contains("evidence"):
		var evidence: Dictionary = planner.call("build_validation_evidence_template", plan) as Dictionary
		_print_safe("/servermarkers evidence-template tasks=%d auto_confirm_allowed=%s required=%s frame=%s spawn=%s" % [
			(evidence.get("tasks", []) as Array).size(),
			str(evidence.get("auto_confirm_allowed", false)),
			_compact_value(evidence.get("evidence_required", []), 900),
			str(evidence.get("coordinate_frame_confirmed", false)),
			str(evidence.get("player_spawn_applied", false)),
		], 2400)
		return true
	if lower.contains("bake") or lower.contains("apply"):
		var zone_id: int = _generated_zone_id_from_command(raw)
		if zone_id < 0:
			zone_id = 19
		var scene_path: String = _server_marker_scene_path_from_command(raw, zone_id)
		var result: Dictionary = planner.call("apply_markers_to_generated_dungeon_scene", scene_path, plan, zone_id, {}) as Dictionary
		_print_safe("/servermarkers bake zone%03d ok=%s markers=%d path=%s error=%s no_spawn=%s frame=%s" % [zone_id, str(result.get("ok", false)), int(result.get("markers_created", 0)), scene_path, str(result.get("error", "")), str(not bool(result.get("player_spawn_applied", true))), str(result.get("coordinate_frame_confirmed", false))], 2400)
		return true
		_print_safe("/servermarkers report ok=%s markers=%d json=res://reports/daoc_server_coordinate_markers_p1_17e2j.json txt=res://reports/daoc_server_coordinate_markers_p1_17e2j.txt no_spawn=%s frame=%s" % [str(plan.get("ok", false)), int(plan.get("marker_count", 0)), str(not bool(plan.get("player_spawn_applied", true))), str(plan.get("coordinate_frame_confirmed", false))], 2200)
	return true


func _server_marker_scene_path_from_command(raw: String, zone_id: int) -> String:
	var parts: PackedStringArray = raw.split(" ", false)
	for i in range(1, parts.size()):
		var token: String = str(parts[i]).strip_edges()
		if token.ends_with(".tscn") or token.begins_with("res://") or token.begins_with("user://"):
			return token
	return "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn" % [zone_id, zone_id]


func _cmd_offline_preview_e2p(raw: String) -> bool:
	var lower = raw.to_lower()
	var preview := _offline_world_preview()
	var action: String = _offline_preview_action_e2u(raw)
	if preview == null:
		_print_safe("/offlinepreview missing preview service")
		return false
	if lower == "/offlinepreview" or lower == "/opreview" or action == "help":
		_print_safe("/offlinepreview status | report [sql_dir] | show [sql_dir] [limit=N] [rows=N|all] | hide — DB placeholders filtered through runtime RegionID->client zone adapter; no scene bake, no player spawn")
		return true
	if action == "hide" or action == "off" or action == "detach":
		var detach_report: Dictionary = preview.call("detach_placeholders", zone_viewer) as Dictionary
		_print_safe("/offlinepreview hide ok=%s detached=%s frame=%s spawn=%s" % [
			str(detach_report.get("ok", false)),
			str(detach_report.get("detached", false)),
			str(detach_report.get("coordinate_frame_confirmed", false)),
			str(detach_report.get("player_spawn_applied", false)),
		])
		return bool(detach_report.get("ok", false))
	var sql_report: Dictionary = _build_offline_preview_sql_report_e2p(raw)
	if str(sql_report.get("status", "")) == "waiting_for_local_sql_directory":
		_print_safe("/offlinepreview waiting: no local opendaoc-db-core SQL folder configured; placeholders not attached")
		return true
	var report_options: Dictionary = _offline_preview_report_options_e2s(raw)
	var report: Dictionary = preview.call("build_preview_report", sql_report, report_options) as Dictionary
	if action == "show" or action == "on" or action == "attach":
		var attach_report: Dictionary = preview.call("attach_placeholders", zone_viewer, report, _offline_preview_attach_options_e2q()) as Dictionary
		var json_export: Dictionary = preview.call("export_last_report_json") as Dictionary
		var txt_export: Dictionary = preview.call("export_last_report_text") as Dictionary
		var quality_report: Dictionary = attach_report.get("quality_report", {}) as Dictionary
		var quality_json_export: Dictionary = preview.call("export_last_quality_report_json") as Dictionary
		var quality_txt_export: Dictionary = preview.call("export_last_quality_report_text") as Dictionary
		var zone_filter: Dictionary = report.get("visible_client_zone_filter", {}) as Dictionary
		var coord_filter: Dictionary = report.get("coordinate_range_filter", {}) as Dictionary
		_print_safe("/offlinepreview show ok=%s placeholders=%d diagnostics_beacon=%s diagnostics_samples=%d folded=%d floor_snapped=%d entities=%d counts=%s vertical=%s loc_filtered=%d region_global=%d visible_zones=%s zone_filtered=%d skipped_regions=%s mapping=%s placement=%s json=%s txt=%s quality_json=%s quality_txt=%s authority=%s fake=%s frame=%s" % [
			str(attach_report.get("ok", false)),
			int(attach_report.get("attached_placeholder_count", 0)),
			str(attach_report.get("debug_beacon_added", false)),
			int(attach_report.get("near_player_sample_count", 0)),
			int(attach_report.get("folded_coordinate_count", 0)),
			int(attach_report.get("floor_snapped_count", 0)),
			int(report.get("entity_count", 0)),
			str(report.get("entity_counts", {})),
			str(quality_report.get("vertical_classification", {})),
			int(coord_filter.get("filtered_out", 0)),
			int(coord_filter.get("global_coordinate_count", 0)),
			str(zone_filter.get("visible_client_zone_ids", [])),
			int(zone_filter.get("filtered_out", 0)),
			str(zone_filter.get("skipped_by_region", {})),
			str(zone_filter.get("kept_by_mapping_basis", {})),
			str(attach_report.get("placement_mode", "")),
			str(json_export.get("path", "")),
			str(txt_export.get("path", "")),
			str(quality_json_export.get("path", "")),
			str(quality_txt_export.get("path", "")),
			str(report.get("server_authority", false)),
			str(report.get("gameplay_fake", false)),
			str(report.get("coordinate_frame_confirmed", false)),
		], 2400)
		return bool(attach_report.get("ok", false))
	var json_export: Dictionary = preview.call("export_last_report_json") as Dictionary
	var txt_export: Dictionary = preview.call("export_last_report_text") as Dictionary
	_print_safe("/offlinepreview report ok=%s entities=%d counts=%s regions=%s json=%s txt=%s authority=%s fake=%s frame=%s" % [
		str(report.get("ok", false)),
		int(report.get("entity_count", 0)),
		str(report.get("entity_counts", {})),
		str(report.get("region_counts", {})),
		str(json_export.get("path", "")),
		str(txt_export.get("path", "")),
		str(report.get("server_authority", false)),
		str(report.get("gameplay_fake", false)),
		str(report.get("coordinate_frame_confirmed", false)),
	], 2400)
	return bool(report.get("ok", false))


func _offline_preview_action_e2u(raw: String) -> String:
	var parts: PackedStringArray = raw.strip_edges().split(" ", false)
	for i in range(1, parts.size()):
		var token: String = str(parts[i]).strip_edges().to_lower()
		if token == "":
			continue
		if token.contains("=") or token.ends_with(".sql") or token.contains(":/") or token.contains(":\\"):
			continue
		if token in ["show", "on", "attach", "hide", "off", "detach", "report", "status", "help"]:
			return token
	return "report"


func _offline_preview_report_options_e2s(raw: String) -> Dictionary:
	return {
		"max_entities": _offline_preview_limit_from_command(raw),
		"validate_client_loc_xy_range": true,
		"allow_out_of_range_client_loc_preview": false,
		"allow_region_global_coordinate_preview": true,
		"filter_to_visible_client_zones": true,
		"visible_client_zone_ids": _offline_preview_visible_client_zones_e2s(),
		"default_client_zone_id": -1,
		"server_client_zone_map": _server_client_zone_map(),
		"region_to_client_zone": _offline_preview_region_to_client_zone_e2s(),
		"allow_visible_zone_candidate_mapping": true,
		"allow_explicit_region_visible_zone_projection": true,
		"allow_default_zone_fallback": false,
		"mapping_policy": "runtime_adapter_visible_zone_candidate",
	}


func _offline_preview_attach_options_e2q() -> Dictionary:
	return {
		"clear_existing": true,
		"world_scale": 0.10,
		"host": zone_viewer,
		"player": player,
		"default_client_zone_id": _offline_preview_default_client_zone_e2q(),
		"visible_client_zone_ids": _offline_preview_visible_client_zones_e2s(),
		"server_client_zone_map": _server_client_zone_map(),
		"region_to_client_zone": _offline_preview_region_to_client_zone_e2s(),
		"allow_visible_zone_candidate_mapping": true,
		"allow_explicit_region_visible_zone_projection": true,
		"allow_default_zone_fallback": false,
		"placement_mode": "host_daoc_to_godot_if_available",
		"snap_mobs_to_floor": true,
		"snap_all_placeholders_to_floor": true,
		"force_floor_height_for_preview": true,
		"floor_snap_epsilon_raw": 1.0,
		"add_debug_beacon": false,
		"add_near_player_samples": false,
		"fold_region_coordinates_to_zone": true,
	}


func _offline_preview_default_client_zone_e2q() -> int:
	if zone_viewer == null:
		return 0
	var loaded_zones: PackedInt32Array = zone_viewer.get("zones") as PackedInt32Array
	if loaded_zones.size() > 0:
		return int(loaded_zones[0])
	return 0


func _offline_preview_visible_client_zones_e2s() -> Array:
	var out: Array = []
	if zone_viewer == null:
		return [0]
	var loaded_zones: PackedInt32Array = zone_viewer.get("zones") as PackedInt32Array
	for zone_id in loaded_zones:
		out.append(int(zone_id))
	if out.is_empty():
		out.append(0)
	return out


func _offline_preview_region_to_client_zone_e2s() -> Dictionary:
	var mapper := _server_client_zone_map()
	if mapper != null and mapper.has_method("region_to_client_zone_dictionary"):
		return mapper.call("region_to_client_zone_dictionary", true) as Dictionary
	return {}


func _build_offline_preview_sql_report_e2p(raw: String) -> Dictionary:
	var importer := _opendaoc_sql_importer()
	if importer == null:
		return {"ok": false, "status": "missing_importer", "tables": []}
	var path: String = _offline_preview_path_from_command(raw)
	var parse_options: Dictionary = _offline_preview_sql_parse_options_e2t(raw)
	if path != "":
		return importer.call("parse_configured_directory", path, [], parse_options) as Dictionary
	return importer.call("parse_configured_directory", "", _opendaocdb_candidate_paths_from_viewer(), parse_options) as Dictionary


func _offline_preview_path_from_command(raw: String) -> String:
	var parts := raw.split(" ", false)
	var out: String = ""
	for i in range(1, parts.size()):
		var token: String = str(parts[i]).strip_edges()
		var lower_token: String = token.to_lower()
		if lower_token in ["status", "report", "show", "on", "attach", "hide", "off", "detach", "help"]:
			continue
		if lower_token.begins_with("limit=") or lower_token.begins_with("rows="):
			continue
		if out != "":
			out += " "
		out += token
	out = out.strip_edges()
	if out.begins_with("\"") and out.ends_with("\"") and out.length() >= 2:
		out = out.substr(1, out.length() - 2)
	return out


func _offline_preview_limit_from_command(raw: String) -> int:
	for token_value in raw.split(" ", false):
		var token: String = str(token_value).strip_edges().to_lower()
		if token.begins_with("limit="):
			var value: String = token.substr("limit=".length())
			if value.is_valid_int():
				return int(value)
	return 0


func _offline_preview_sql_parse_options_e2t(raw: String) -> Dictionary:
	var max_rows: int = _offline_preview_rows_limit_from_command_e2t(raw)
	return {
		"max_rows_by_table": {
			"opendaoc_mob": max_rows,
			"opendaoc_door": max_rows,
			"opendaoc_bindpoint": max_rows,
			"opendaoc_startuplocation": max_rows,
			"opendaoc_zonepoint": max_rows,
			"opendaoc_jumppoint": max_rows,
		}
	}


func _offline_preview_rows_limit_from_command_e2t(raw: String) -> int:
	for token_value in raw.split(" ", false):
		var token: String = str(token_value).strip_edges().to_lower()
		if token.begins_with("rows="):
			var value: String = token.substr("rows=".length())
			if value == "all" or value == "none" or value == "unlimited":
				return -1
			if value.is_valid_int():
				return int(value)
	return -1


func _cmd_opendaocdb_e2e(raw: String) -> bool:
	var lower = raw.to_lower()
	if lower == "/opendaocdb" or lower == "/odb" or lower.contains("help"):
		_print_safe("/opendaocdb report [path_to_opendaoc-db-core] | status — if no path is given, uses ZoneViewer.opendaoc_db_core_dir then server_dumps fallback; parse only, no runtime spawn, exports res://reports/daoc_opendaoc_sql_realdb_report.*")
		return true
	var importer := _opendaoc_sql_importer()
	if importer == null:
		_print_safe("/opendaocdb missing importer")
		return false
	if lower.contains("status"):
		var found: Dictionary = importer.call("find_local_sql_directory", _opendaocdb_candidate_paths_from_viewer()) as Dictionary
		_print_safe("/opendaocdb status=%s sql_files=%d path=%s configured=%s" % [str(found.get("status", "")), int(found.get("sql_file_count", 0)), str(found.get("source_path", "")), _compact_value(_opendaocdb_candidate_paths_from_viewer(), 700)], 1800)
		return true
	var path: String = _opendaocdb_path_from_command(raw)
	var report: Dictionary = {}
	if path != "":
		report = importer.call("parse_configured_directory", path) as Dictionary
	else:
		report = importer.call("parse_configured_directory", "", _opendaocdb_candidate_paths_from_viewer()) as Dictionary
	if report.get("status", "") == "waiting_for_local_sql_directory":
		_print_safe("/opendaocdb waiting: fill ZoneViewer.opendaoc_db_core_dir, copy opendaoc-db-core to res://data/server_dumps/opendaoc/opendaoc-db-core, or pass a path", 2000)
		return true
	var json_export: Dictionary = importer.call("export_last_report_json") as Dictionary
	var txt_export: Dictionary = importer.call("export_last_report_text") as Dictionary
	var summary: Dictionary = report.get("barrows_mithra_summary", {}) as Dictionary
	var barrows: Dictionary = summary.get("barrows", {}) as Dictionary
	var mithra: Dictionary = summary.get("mithra", {}) as Dictionary
	_print_safe("/opendaocdb report ok=%s tables=%d world=%d barrows=%s mithra=%s json=%s txt=%s" % [str(report.get("ok", false)), int(report.get("present_table_count", 0)), int(report.get("world_destination_table_count", 0)), str(barrows.get("status", "")), str(mithra.get("status", "")), str(json_export.get("path", "")), str(txt_export.get("path", ""))], 2200)
	return true



func _opendaocdb_candidate_paths_from_viewer() -> Array:
	var out: Array = []
	if zone_viewer != null and zone_viewer.has_method("get_opendaoc_db_core_candidate_paths"):
		out = zone_viewer.call("get_opendaoc_db_core_candidate_paths") as Array
	if out.is_empty():
		out.append("res://data/server_dumps/opendaoc/opendaoc-db-core")
		out.append("res://data/server_instruction_db/opendaoc-db-core")
		out.append("res://opendaoc-db-core")
	return out

func _opendaocdb_path_from_command(raw: String) -> String:
	var parts := raw.split(" ", false)
	if parts.size() <= 2:
		return ""
	if str(parts[1]).to_lower() != "report":
		return ""
	var text: String = ""
	for i in range(2, parts.size()):
		if text != "":
			text += " "
		text += str(parts[i])
	text = text.strip_edges()
	if text.begins_with("\"") and text.ends_with("\"") and text.length() >= 2:
		text = text.substr(1, text.length() - 2)
	return text


func _cmd_resetcamera() -> bool:
	if player_camera != null and player_camera.has_method("reset_camera"):
		player_camera.call("reset_camera")
		_print_safe("/resetcamera")
		return true
	return false


func _cmd_setcamera() -> bool:
	if player_camera != null and player_camera.has_method("set_camera_as_reset_from_current"):
		player_camera.call("set_camera_as_reset_from_current")
		_print_safe("/setcamera")
		return true
	return false


func _cmd_snapback(enabled: bool) -> bool:
	if player_camera != null and player_camera.has_method("set_snapback_enabled"):
		player_camera.call("set_snapback_enabled", enabled)
		_print_safe("/snapback %s" % ("on" if enabled else "off"))
		return true
	return false


func _cmd_loc() -> bool:
	if player == null:
		return false
	var zone := int(player.get("daoc_zone"))
	var x := float(player.get("daoc_x"))
	var y := float(player.get("daoc_y"))
	var z := float(player.get("daoc_z"))
	var h := float(player.get("heading_deg"))
	_print_safe("/loc zone%03d x=%.1f y=%.1f z=%.1f heading=%.1f" % [zone, x, y, z, h])
	return true


func _cmd_stuck_local() -> bool:
	if player != null and player.has_method("unstuck_to_safe_local_position"):
		player.call("unstuck_to_safe_local_position")
		_print_safe("/stuck local: moved to safe fallback")
		return true
	_print_safe("/stuck stub: no local recovery available")
	return true




func _asset_material_audit_p1_18n() -> RefCounted:
	if _asset_material_audit_p1_18n_obj == null:
		_asset_material_audit_p1_18n_obj = DaocAssetMaterialFidelityAuditScript.new()
	return _asset_material_audit_p1_18n_obj


func _nif_import_probe_p1_18n_hf6() -> RefCounted:
	if _nif_import_probe_p1_18n_hf6_obj == null:
		_nif_import_probe_p1_18n_hf6_obj = DaocNifImportConversionProbeScript.new()
	return _nif_import_probe_p1_18n_hf6_obj


func _cmd_nif_import_probe_p1_18n_hf6(raw: String) -> bool:
	var lower := raw.to_lower().strip_edges()
	var probe: RefCounted = _nif_import_probe_p1_18n_hf6()
	if probe == null:
		_print_safe("/nifprobe missing P1-18N-HF6 service")
		return false
	if lower == "/nifprobe" or lower.contains("help"):
		_print_safe("/nifprobe zone000 | focus brghouse | visual brghouse | report — writes res://reports/p1_18n_nif_import_probe/*; audit only, no asset edits", 1400)
		return true
	if lower.contains("visual"):
		var visual: Dictionary = probe.call("apply_visual_debug", zone_viewer, _asset_audit_zone_from_command(raw, 0), 556, true, true, true) as Dictionary
		_print_safe(visual, 1400)
		return bool(visual.get("ok", false))
	var znum := _asset_audit_zone_from_command(raw, 0)
	var max_fixtures := 0
	if lower.contains("focus") or lower.contains("smoke"):
		max_fixtures = 0
	var report: Dictionary = probe.call("run_zone_probe", zone_viewer, znum, {
		"write_csv": true,
		"write_json": true,
		"write_txt": true,
		"max_fixtures": max_fixtures,
	}) as Dictionary
	_print_safe(probe.call("summarize_for_console", report), 2200)
	return bool(report.get("ok", false))


func _cmd_asset_material_audit_p1_18n(raw: String) -> bool:
	var lower := raw.to_lower().strip_edges()
	var audit: RefCounted = _asset_material_audit_p1_18n()
	if audit == null:
		_print_safe("/assetaudit missing P1-18N audit service")
		return false
	if lower == "/assetaudit" or lower == "/aaudit" or lower.contains("help"):
		_print_safe("/assetaudit zone000 | zone <id> | textures off | materials off — writes res://reports/p1_18n_asset_material_audit/*.json/txt/csv; audit only, no render changes", 1400)
		return true
	var znum := _asset_audit_zone_from_command(raw, 0)
	var options := {
		"write_reports": true,
		"scan_model_index": true,
		"scan_texture_index": not lower.contains("textures off"),
		"inspect_runtime_materials": not lower.contains("materials off"),
	}
	var report: Dictionary = audit.call("run_zone_audit", zone_viewer, znum, options) as Dictionary
	_print_safe(audit.call("summarize_for_console", report), 2200)
	return bool(report.get("ok", false))


func _asset_audit_zone_from_command(raw: String, fallback: int) -> int:
	var parts := raw.split(" ", false)
	for token_value in parts:
		var token := str(token_value).strip_edges().to_lower()
		if token.begins_with("zone"):
			var suffix := token.substr(4)
			if suffix.is_valid_int():
				return int(suffix)
		if token.is_valid_int():
			return int(token)
	return fallback


func _player_visual_meshy() -> RefCounted:
	if _player_visual_meshy_p1_18m == null:
		_player_visual_meshy_p1_18m = DaocPlayerVisualMeshySwapScript.new()
	return _player_visual_meshy_p1_18m


func _grounding_service_p1_18p() -> RefCounted:
	return DaocGroundingServiceScript.new()


func _grounding_options_p1_18p() -> Dictionary:
	if zone_viewer != null and zone_viewer.has_method("build_player_grounding_options_p1_18p"):
		return zone_viewer.call("build_player_grounding_options_p1_18p") as Dictionary
	return {}


func _cmd_grounding_p1_18p(raw: String) -> bool:
	var service := _grounding_service_p1_18p()
	var options := _grounding_options_p1_18p()
	if raw.to_lower().contains("snap"):
		var body := player as CharacterBody3D
		var snap_report := {"ok": false, "reason": "player_not_characterbody"}
		if body != null:
			snap_report = service.call("apply_grounding", body, zone_viewer, options) as Dictionary
		_print_safe("/grounding snap %s" % _compact_value(snap_report, 1200), 1300)
		return true
	var probe_report := {"ok": false, "reason": "player_not_node3d"}
	if player is Node3D:
		probe_report = service.call("probe_ground", player as Node3D, zone_viewer, options) as Dictionary
	_print_safe("/grounding %s %s" % ["status" if raw.to_lower().contains("status") else "probe", _compact_value(probe_report, 1200)], 1300)
	return true


func _cmd_feet_align_p1_18p(raw: String) -> bool:
	var service := _grounding_service_p1_18p()
	var visual_root: Node3D = null
	if player != null:
		visual_root = player.get_node_or_null("DaocPlayerVisualRoot") as Node3D
	var options := _grounding_options_p1_18p()
	if raw.to_lower().contains("apply"):
		var apply_report: Dictionary = service.call("apply_visual_feet_alignment", visual_root, options) as Dictionary
		_print_safe("/feetalign apply %s" % _compact_value(apply_report, 1200), 1300)
		return true
	var status_report: Dictionary = service.call("compute_visual_feet_offset", visual_root) as Dictionary
	_print_safe("/feetalign status %s" % _compact_value(status_report, 1200), 1300)
	return true


func _cmd_player_visual_meshy_p1_18m(raw: String) -> bool:
	var lower := raw.to_lower().strip_edges()
	var swap: RefCounted = _player_visual_meshy()
	if swap == null:
		_print_safe("/playervisual missing P1-18M Meshy swap service")
		return false
	if lower == "/playervisual" or lower == "/pvisual" or lower == "/meshy" or lower.contains("help"):
		_print_safe("/playervisual status | meshy/on | off | scale <float> | yoffset <float> | yaw <degrees> | idle | walk | run | auto | idlemode freeze|walk_loop — keeps CharacterBody3D + CollisionShape3D")
		return true
	if lower.contains("scale"):
		_player_visual_meshy_config_p1_18m["visual_scale"] = _player_visual_parse_last_float(raw, float(_player_visual_meshy_config_p1_18m.get("visual_scale", 60.0)))
		_print_safe("/playervisual scale=%s; run /playervisual meshy to reattach" % str(_player_visual_meshy_config_p1_18m.get("visual_scale", 60.0)))
		return true
	if lower.contains("yoffset") or lower.contains("offset"):
		_player_visual_meshy_config_p1_18m["ground_offset"] = _player_visual_parse_last_float(raw, float(_player_visual_meshy_config_p1_18m.get("ground_offset", 0.0)))
		_print_safe("/playervisual yoffset=%s; run /playervisual meshy to reattach" % str(_player_visual_meshy_config_p1_18m.get("ground_offset", 0.0)))
		return true
	if lower.contains("yaw") or lower.contains("rotate"):
		_player_visual_meshy_config_p1_18m["yaw_degrees"] = _player_visual_parse_last_float(raw, float(_player_visual_meshy_config_p1_18m.get("yaw_degrees", 90.0)))
		_print_safe("/playervisual yaw=%s; run /playervisual meshy to reattach" % str(_player_visual_meshy_config_p1_18m.get("yaw_degrees", 90.0)))
		return true
	if lower.contains("idlemode") or lower.contains("idle_mode"):
		var idle_mode := "walk_loop" if (lower.contains("walk") or lower.contains("loop")) else "freeze"
		_player_visual_meshy_config_p1_18m["idle_mode"] = idle_mode
		var idle_report: Dictionary = swap.call("configure_runtime", player, {"idle_mode": idle_mode}) as Dictionary
		_print_safe("/playervisual idle_mode=%s ok=%s" % [idle_mode, str(idle_report.get("ok", true))], 1200)
		return true
	if lower == "/playervisual auto" or lower == "/pvisual auto" or lower == "/meshy auto" or lower.ends_with(" auto"):
		_player_visual_meshy_config_p1_18m["force_state"] = "auto"
		var auto_report: Dictionary = swap.call("force_state", player, "auto") as Dictionary
		_print_safe("/playervisual force_state=auto ok=%s" % str(auto_report.get("ok", false)), 1200)
		return bool(auto_report.get("ok", false))
	if lower.contains("idle") or lower.contains("walk") or lower.contains("run"):
		var state := "idle"
		if lower.contains("run"):
			state = "run"
		elif lower.contains("walk"):
			state = "walk"
		_player_visual_meshy_config_p1_18m["force_state"] = state
		var state_report: Dictionary = swap.call("force_state", player, state) as Dictionary
		_print_safe("/playervisual force_state=%s ok=%s" % [state, str(state_report.get("ok", false))], 1200)
		return bool(state_report.get("ok", false))
	if lower.contains("off") or lower.contains("detach") or lower.contains("hide"):
		var detach_report: Dictionary = swap.call("detach_from_player", player, false) as Dictionary
		_print_safe("/playervisual off ok=%s status=%s collision_replaced=false" % [str(detach_report.get("ok", false)), str(detach_report.get("status", ""))], 1200)
		return bool(detach_report.get("ok", false))
	if lower.contains("mesh") or lower.contains("on") or lower.contains("attach"):
		_merge_zone_viewer_feet_alignment_config_p1_18p()
		var attach_report: Dictionary = swap.call("attach_to_player", player, _player_visual_meshy_config_p1_18m) as Dictionary
		var runtime_status: Dictionary = attach_report.get("runtime_status", {}) as Dictionary
		var texture_status: Dictionary = runtime_status.get("texture_status", {}) as Dictionary
		_print_safe("/playervisual meshy ok=%s walk=%s run=%s collision_shapes=%d collision_replaced=%s scale=%s yaw=%s anim=%s idle_mode=%s textures=%d/%d" % [
			str(attach_report.get("ok", false)),
			str(attach_report.get("walk_glb_exists", false)),
			str(attach_report.get("run_glb_exists", false)),
			int(attach_report.get("collision_shape_count", 0)),
			str(attach_report.get("collision_replaced", true)),
			str(runtime_status.get("visual_scale", attach_report.get("visual_scale", 60.0))),
			str(runtime_status.get("yaw_degrees", attach_report.get("yaw_degrees", 90.0))),
			str(runtime_status.get("force_state", attach_report.get("force_state", "auto"))),
			str(runtime_status.get("idle_mode", attach_report.get("idle_mode", "walk_loop"))),
			int(texture_status.get("unique_surfaces", 0)),
			int(texture_status.get("material_applications", 0)),
		], 1800)
		return bool(attach_report.get("ok", false))
	var status: Dictionary = swap.call("build_status_report", player, _player_visual_meshy_config_p1_18m) as Dictionary
	_print_safe("/playervisual status ok=%s player=%s attached=%s walk=%s run=%s collision_shapes=%d capsule_collision_preserved=%s" % [
		str(status.get("ok", false)),
		str(status.get("player_valid", false)),
		str(status.get("visual_root_attached", false)),
		str(status.get("walk_glb_exists", false)),
		str(status.get("run_glb_exists", false)),
		int(status.get("collision_shape_count", 0)),
		str(status.get("capsule_collision_preserved", false)),
	], 1800)
	return true


func _merge_zone_viewer_feet_alignment_config_p1_18p() -> void:
	if zone_viewer == null:
		return
	_player_visual_meshy_config_p1_18m["feet_alignment_enabled"] = bool(zone_viewer.get("player_visual_auto_feet_align")) and bool(zone_viewer.get("player_visual_feet_align_runtime"))
	_player_visual_meshy_config_p1_18m["feet_alignment_offset"] = float(zone_viewer.get("player_visual_feet_offset"))
	_player_visual_meshy_config_p1_18m["feet_alignment_max_step"] = float(zone_viewer.get("player_visual_feet_align_max_step"))


func _player_visual_parse_last_float(raw: String, fallback: float) -> float:
	var parts: PackedStringArray = raw.split(" ", false)
	for index in range(parts.size() - 1, -1, -1):
		var token := str(parts[index]).strip_edges()
		if token.is_valid_float():
			return float(token)
	return fallback


func _ensure_combat_lab_p1_18b() -> RefCounted:
	if _offline_combat_lab_p1_18b == null:
		_offline_combat_lab_p1_18b = DaocOfflineCombatLabScript.new()
		if _offline_combat_lab_p1_18b != null and _offline_combat_lab_p1_18b.has_method("load_default_fixtures"):
			_offline_combat_lab_p1_18b.call("load_default_fixtures")
	return _offline_combat_lab_p1_18b



func _combat_lab_opendaoc_candidate_paths() -> Array:
	var out: Array = []
	if zone_viewer != null and zone_viewer.has_method("get_opendaoc_db_core_candidate_paths"):
		out = zone_viewer.call("get_opendaoc_db_core_candidate_paths") as Array
	if out.is_empty():
		out = ["res://data/server_dumps/opendaoc/opendaoc-db-core", "res://data/server_instruction_db/opendaoc-db-core", "res://opendaoc-db-core"]
	return out

func _combat_lab_parse_last_int(raw: String, default_id: int = 0) -> int:
	var parts: PackedStringArray = raw.split(" ", false)
	for index in range(parts.size() - 1, -1, -1):
		var token: String = str(parts[index]).strip_edges()
		if token.is_valid_int():
			return int(token)
	return default_id

func _cmd_combat_lab_p1_18b(raw: String) -> bool:
	var lower: String = raw.to_lower()
	if lower == "/combatlab" or lower == "/clab" or lower.contains("help"):
		_print_safe("/combatlab status | run | report | suite verbose | dummy | cast <spell_id> | opendaoc status | opendaoc report | opendaoc coverage | opendaoc p0 | opendaoc cast <spell_id> — prediction-only combat lab; server remains authoritative")
		return true
	var lab: RefCounted = _ensure_combat_lab_p1_18b()
	if lab == null:
		_print_safe("/combatlab missing P1-18B/P1-18C lab")
		return false
	if lower.contains("live"):
		var harness: RefCounted = _opendaoc_live_comparison()
		if harness == null:
			_print_safe("/combatlab live missing P1-18L harness")
			return false
		if lower.contains("report"):
			var live_json: Dictionary = harness.call("export_last_report_json") as Dictionary
			var live_txt: Dictionary = harness.call("export_last_report_text") as Dictionary
			_print_safe("/combatlab live report json=%s txt=%s prediction_only=true server_authority=true" % [str(live_json.get("path", "")), str(live_txt.get("path", ""))], 1800)
			return true
		if lower.contains("dd"):
			var live_spell_id: int = _combat_lab_parse_last_int(raw, 101)
			var live_candidates: Array = _combat_lab_opendaoc_candidate_paths()
			if live_spell_id == 101:
				live_candidates = []
			var live_report: Dictionary = harness.call("run_direct_damage_comparison", lab, live_spell_id, live_candidates, {"seed": 42, "verbose": true}) as Dictionary
			var live_json_dd: Dictionary = harness.call("export_last_report_json") as Dictionary
			var live_txt_dd: Dictionary = harness.call("export_last_report_text") as Dictionary
			var live_prediction: Dictionary = live_report.get("prediction_summary", {}) as Dictionary
			_print_safe("/combatlab live dd spell_id=%d status=%s prediction_total=%d server_reachable=%s json=%s txt=%s authoritative=false" % [
				live_spell_id,
				str(live_report.get("comparison_status", "")),
				int(live_prediction.get("total_damage", 0)),
				str(live_report.get("server_reachable", false)),
				str(live_json_dd.get("path", "")),
				str(live_txt_dd.get("path", "")),
			], 2200)
			return true
		var live_status: Dictionary = harness.call("build_status_report") as Dictionary
		var live_json_status: Dictionary = harness.call("export_last_report_json") as Dictionary
		var live_txt_status: Dictionary = harness.call("export_last_report_text") as Dictionary
		var live_config: Dictionary = live_status.get("config", {}) as Dictionary
		_print_safe("/combatlab live status configured=%s reachable=%s status=%s host=%s port=%d json=%s txt=%s" % [
			str(live_status.get("server_configured", false)),
			str(live_status.get("server_reachable", false)),
			str(live_status.get("comparison_status", "")),
			str(live_config.get("host", "")),
			int(live_config.get("port", 0)),
			str(live_json_status.get("path", "")),
			str(live_txt_status.get("path", "")),
		], 2200)
		return true
	if lower.contains("opendaoc") or lower.contains("real"):
		var candidates: Array = _combat_lab_opendaoc_candidate_paths()
		var opendaoc_spell_report: Dictionary = lab.call("run_opendaoc_spellbook_detailed_suite", candidates, {"seed": 42, "verbose": false, "max_rows": 8192}) as Dictionary
		if lower.contains("coverage") or lower.contains("unsupported"):
			var coverage_report: Dictionary = lab.call("run_opendaoc_spell_coverage_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4}) as Dictionary
			var coverage_json: Dictionary = lab.call("export_opendaoc_spell_coverage_report_json", "res://reports/p1_18e_opendaoc_spell_coverage.json") as Dictionary
			var coverage_txt: Dictionary = lab.call("export_opendaoc_spell_coverage_report_text", "res://reports/p1_18e_opendaoc_spell_coverage.txt") as Dictionary
			_print_safe("/combatlab opendaoc coverage ok=%s total=%d supported=%d unsupported=%d unsupported_types=%d json=%s txt=%s" % [str(coverage_report.get("ok", false)), int(coverage_report.get("total_spell_count", 0)), int(coverage_report.get("supported_spell_count", 0)), int(coverage_report.get("unsupported_spell_count", 0)), int(coverage_report.get("unsupported_type_count", 0)), str(coverage_json.get("path", "")), str(coverage_txt.get("path", ""))], 2400)
			return bool(coverage_report.get("ok", false)) or str(coverage_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("p0") or lower.contains("p1-18f") or lower.contains("18f"):
			var p0_report: Dictionary = lab.call("run_opendaoc_p0_handler_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var p0_json: Dictionary = lab.call("export_opendaoc_p0_handler_report_json", "res://reports/p1_18f_opendaoc_p0_handlers.json") as Dictionary
			var p0_txt: Dictionary = lab.call("export_opendaoc_p0_handler_report_text", "res://reports/p1_18f_opendaoc_p0_handlers.txt") as Dictionary
			_print_safe("/combatlab opendaoc p0 ok=%s supported=%d unsupported=%d casts=%d/%d json=%s txt=%s" % [str(p0_report.get("ok", false)), int(p0_report.get("supported_spell_count", 0)), int(p0_report.get("unsupported_spell_count", 0)), int(p0_report.get("ok_cast_probe_count", 0)), int(p0_report.get("cast_probe_count", 0)), str(p0_json.get("path", "")), str(p0_txt.get("path", ""))], 2400)
			return bool(p0_report.get("ok", false)) or str(p0_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("buff") or lower.contains("debuff") or lower.contains("p1-18g") or lower.contains("18g"):
			var buff_report: Dictionary = lab.call("run_opendaoc_buff_debuff_state_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var buff_json: Dictionary = lab.call("export_buff_debuff_state_report_json", "res://reports/p1_18g_buff_debuff_state.json") as Dictionary
			var buff_txt: Dictionary = lab.call("export_buff_debuff_state_report_text", "res://reports/p1_18g_buff_debuff_state.txt") as Dictionary
			var buff_summary: Dictionary = buff_report.get("active_effect_summary", {}) as Dictionary
			_print_safe("/combatlab opendaoc buffs ok=%s supported=%d unsupported=%d active_effects=%d casts=%d/%d json=%s txt=%s" % [str(buff_report.get("ok", false)), int(buff_report.get("supported_spell_count", 0)), int(buff_report.get("unsupported_spell_count", 0)), int(buff_summary.get("active_effect_count", 0)), int(buff_report.get("ok_sample_cast_count", 0)), int(buff_report.get("sample_cast_count", 0)), str(buff_json.get("path", "")), str(buff_txt.get("path", ""))], 2400)
			return bool(buff_report.get("ok", false)) or str(buff_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("k25") or lower.contains("p1-18k") or lower.contains("18k") or lower.contains("heal simple") or lower.contains("runtime"):
			var k25_report: Dictionary = lab.call("run_opendaoc_k25_lab_runtime_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var k25_json: Dictionary = lab.call("export_k25_lab_runtime_report_json", "res://reports/p1_18k_2_5_lab_runtime.json") as Dictionary
			var k25_txt: Dictionary = lab.call("export_k25_lab_runtime_report_text", "res://reports/p1_18k_2_5_lab_runtime.txt") as Dictionary
			var k2: Dictionary = k25_report.get("k2_heal_simple", {}) as Dictionary
			var k4: Dictionary = k25_report.get("k4_dot_tick_minimal", {}) as Dictionary
			var k5: Dictionary = k25_report.get("k5_pet_summon_observation", {}) as Dictionary
			_print_safe("/combatlab opendaoc k25 ok=%s heal=%d dot_tick=%d pet_obs=%d json=%s txt=%s prediction_only=true spawn=false" % [str(k25_report.get("ok", false)), int(k2.get("effective_amount", 0)), int(k4.get("tick_damage", 0)), int(k5.get("observed_intent_count", 0)), str(k25_json.get("path", "")), str(k25_txt.get("path", ""))], 2400)
			return bool(k25_report.get("ok", false)) or str(k25_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("hij") or lower.contains("p1-18h") or lower.contains("18h") or lower.contains("dot") or lower.contains("disease") or lower.contains("proc"):
			var dot_report: Dictionary = lab.call("run_opendaoc_dot_disease_proc_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var dot_json: Dictionary = lab.call("export_dot_disease_proc_report_json", "res://reports/p1_18h_dot_disease_proc_state.json") as Dictionary
			var dot_txt: Dictionary = lab.call("export_dot_disease_proc_report_text", "res://reports/p1_18h_dot_disease_proc_state.txt") as Dictionary
			if not lower.contains("hij"):
				_print_safe("/combatlab opendaoc dots ok=%s supported=%d unsupported=%d casts=%d/%d json=%s txt=%s" % [str(dot_report.get("ok", false)), int(dot_report.get("supported_spell_count", 0)), int(dot_report.get("unsupported_spell_count", 0)), int(dot_report.get("ok_sample_cast_count", 0)), int(dot_report.get("sample_cast_count", 0)), str(dot_json.get("path", "")), str(dot_txt.get("path", ""))], 2400)
				return bool(dot_report.get("ok", false)) or str(dot_report.get("status", "")) == "waiting_for_local_sql_directory"
			var dmg_report_hij: Dictionary = lab.call("run_opendaoc_generic_damage_effect_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var pet_report_hij: Dictionary = lab.call("run_opendaoc_pet_summon_intent_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			lab.call("export_generic_damage_effect_report_json", "res://reports/p1_18i_generic_damage_effects.json")
			lab.call("export_generic_damage_effect_report_text", "res://reports/p1_18i_generic_damage_effects.txt")
			lab.call("export_pet_summon_intent_report_json", "res://reports/p1_18j_pet_summon_intent.json")
			lab.call("export_pet_summon_intent_report_text", "res://reports/p1_18j_pet_summon_intent.txt")
			_print_safe("/combatlab opendaoc hij H=%s I=%s J=%s supported=%d unsupported=%d prediction_only=true" % [str(dot_report.get("ok", false)), str(dmg_report_hij.get("ok", false)), str(pet_report_hij.get("ok", false)), int(pet_report_hij.get("supported_spell_count", 0)), int(pet_report_hij.get("unsupported_spell_count", 0))], 2400)
			return bool(dot_report.get("ok", false)) and bool(dmg_report_hij.get("ok", false)) and bool(pet_report_hij.get("ok", false))
		if lower.contains("damagefx") or lower.contains("p1-18i") or lower.contains("18i") or lower.contains("bomber") or lower.contains("turret"):
			var dmg_report: Dictionary = lab.call("run_opendaoc_generic_damage_effect_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var dmg_json: Dictionary = lab.call("export_generic_damage_effect_report_json", "res://reports/p1_18i_generic_damage_effects.json") as Dictionary
			var dmg_txt: Dictionary = lab.call("export_generic_damage_effect_report_text", "res://reports/p1_18i_generic_damage_effects.txt") as Dictionary
			_print_safe("/combatlab opendaoc damagefx ok=%s supported=%d unsupported=%d casts=%d/%d json=%s txt=%s" % [str(dmg_report.get("ok", false)), int(dmg_report.get("supported_spell_count", 0)), int(dmg_report.get("unsupported_spell_count", 0)), int(dmg_report.get("ok_sample_cast_count", 0)), int(dmg_report.get("sample_cast_count", 0)), str(dmg_json.get("path", "")), str(dmg_txt.get("path", ""))], 2400)
			return bool(dmg_report.get("ok", false)) or str(dmg_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("pet") or lower.contains("summon") or lower.contains("charm") or lower.contains("p1-18j") or lower.contains("18j"):
			var pet_report: Dictionary = lab.call("run_opendaoc_pet_summon_intent_report", candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
			var pet_json: Dictionary = lab.call("export_pet_summon_intent_report_json", "res://reports/p1_18j_pet_summon_intent.json") as Dictionary
			var pet_txt: Dictionary = lab.call("export_pet_summon_intent_report_text", "res://reports/p1_18j_pet_summon_intent.txt") as Dictionary
			_print_safe("/combatlab opendaoc pets ok=%s supported=%d unsupported=%d casts=%d/%d json=%s txt=%s spawn=false" % [str(pet_report.get("ok", false)), int(pet_report.get("supported_spell_count", 0)), int(pet_report.get("unsupported_spell_count", 0)), int(pet_report.get("ok_sample_cast_count", 0)), int(pet_report.get("sample_cast_count", 0)), str(pet_json.get("path", "")), str(pet_txt.get("path", ""))], 2400)
			return bool(pet_report.get("ok", false)) or str(pet_report.get("status", "")) == "waiting_for_local_sql_directory"
		if lower.contains("cast"):
			var real_spell_id: int = _combat_lab_parse_last_int(raw, int(opendaoc_spell_report.get("first_supported_spell_id", 0)))
			var real_cast: Dictionary = lab.call("cast_opendaoc_spell_by_id", real_spell_id, candidates, {"seed": 42, "verbose": true, "max_rows": 8192}) as Dictionary
			var real_detail: Dictionary = real_cast.get("detail", {}) as Dictionary
			var real_dmg: Dictionary = real_detail.get("damage_summary", {}) as Dictionary
			_print_safe("/combatlab opendaoc cast spell_id=%d ok=%s mech=%s hp %d -> %d delta=%+d final=%d prediction_only=true" % [real_spell_id, str(real_cast.get("ok", false)), str(real_detail.get("mechanism", "")), int(real_detail.get("target_hp_before", 0)), int(real_detail.get("target_hp_after_predicted", 0)), int(real_detail.get("hp_delta_predicted", 0)), int(real_dmg.get("damage", 0))], 2200)
			return bool(real_cast.get("ok", false))
		if lower.contains("report"):
			var real_json: Dictionary = lab.call("export_opendaoc_spellbook_report_json", "res://reports/p1_18d_opendaoc_spellbook.json") as Dictionary
			var real_txt: Dictionary = lab.call("export_opendaoc_spellbook_report_text", "res://reports/p1_18d_opendaoc_spellbook.txt") as Dictionary
			_print_safe("/combatlab opendaoc report ok=%s spells=%d supported=%d json=%s txt=%s" % [str(opendaoc_spell_report.get("ok", false)), int((opendaoc_spell_report.get("spellbook", {}) as Dictionary).get("spell_count", 0)), int(opendaoc_spell_report.get("supported_spell_count", 0)), str(real_json.get("path", "")), str(real_txt.get("path", ""))], 2200)
			return bool(opendaoc_spell_report.get("ok", false)) or str(opendaoc_spell_report.get("status", "")) == "waiting_for_local_sql_directory"
		_print_safe("/combatlab opendaoc status ok=%s status=%s spells=%d supported=%d first_supported=%d prediction_only=true" % [str(opendaoc_spell_report.get("ok", false)), str(opendaoc_spell_report.get("status", "")), int((opendaoc_spell_report.get("spellbook", {}) as Dictionary).get("spell_count", 0)), int(opendaoc_spell_report.get("supported_spell_count", 0)), int(opendaoc_spell_report.get("first_supported_spell_id", 0))], 2200)
		return bool(opendaoc_spell_report.get("ok", false)) or str(opendaoc_spell_report.get("status", "")) == "waiting_for_local_sql_directory"
	if lower.contains("effects"):
		var effects_snapshot: Dictionary = lab.call("effects_state_snapshot") as Dictionary
		var effects_summary: Dictionary = effects_snapshot.get("active_effect_summary", {}) as Dictionary
		_print_safe("/combatlab effects ok=%s active=%d categories=%s stats=%s resists=%s speed=%d armor=%d regen=%d prediction_only=true server_authority=true" % [
			str(effects_snapshot.get("ok", false)),
			int(effects_summary.get("active_effect_count", 0)),
			str(effects_summary.get("effects_by_category", {})),
			str(effects_summary.get("modifiers_by_stat", {})),
			str(effects_summary.get("modifiers_by_resist", {})),
			(effects_summary.get("speed_modifiers", []) as Array).size(),
			(effects_summary.get("armor_modifiers", []) as Array).size(),
			(effects_summary.get("regen_modifiers", []) as Array).size(),
		], 2400)
		return true
	if lower.contains("dummy"):
		var dummy: Dictionary = lab.call("dummy_snapshot") as Dictionary
		var target: Dictionary = dummy.get("target", {}) as Dictionary
		_print_safe("/combatlab dummy ok=%s target=%s hp=%d/%d prediction_only=true" % [str(dummy.get("ok", false)), str(target.get("name", "")), int(target.get("health", 0)), int(target.get("max_health", 0))], 1800)
		return bool(dummy.get("ok", false))
	if lower.contains("cast"):
		var spell_id: int = _combat_lab_parse_spell_id(raw, 101)
		var cast_report: Dictionary = lab.call("cast_spell_by_id", spell_id, {"seed": 42, "verbose": true}) as Dictionary
		var detail: Dictionary = cast_report.get("detail", {}) as Dictionary
		var dmg: Dictionary = detail.get("damage_summary", {}) as Dictionary
		_print_safe("/combatlab cast spell_id=%d ok=%s mech=%s hp %d -> %d delta=%+d base=%.1f final=%d crit=%d resist_mod=%d" % [spell_id, str(cast_report.get("ok", false)), str(detail.get("mechanism", "")), int(detail.get("target_hp_before", 0)), int(detail.get("target_hp_after_predicted", 0)), int(detail.get("hp_delta_predicted", 0)), float(dmg.get("base_damage", 0.0)), int(dmg.get("damage", 0)), int(dmg.get("critical_damage", 0)), int(dmg.get("resist_modifier", 0))], 2200)
		return bool(cast_report.get("ok", false))
	if lower.contains("suite") or lower.contains("verbose"):
		var detailed: Dictionary = lab.call("run_detailed_suite", {"seed": 42, "verbose": lower.contains("verbose")}) as Dictionary
		var detailed_text: String = str(lab.call("build_detailed_text_report", detailed))
		_print_safe(detailed_text, 2600)
		return bool(detailed.get("ok", false))
	if lower.contains("status"):
		var load: Dictionary = lab.call("load_default_fixtures") as Dictionary
		var report: Dictionary = lab.call("run_detailed_suite", {"seed": 42, "verbose": false}) as Dictionary
		var book: Dictionary = report.get("spellbook", {}) as Dictionary
		var summary: Dictionary = report.get("summary", {}) as Dictionary
		_print_safe("/combatlab status ok=%s spells=%d entries=%d total_damage=%d total_heal=%d prediction_only=true server_authority=true" % [str(report.get("ok", false)), int(book.get("spell_count", 0)), int(summary.get("entry_count", 0)), int(summary.get("total_predicted_damage", 0)), int(summary.get("total_predicted_heal", 0))], 1800)
		return bool(report.get("ok", false)) or bool(load.get("ok", false))
	if lower.contains("report"):
		var report2: Dictionary = lab.call("run_detailed_suite", {"seed": 42, "verbose": true}) as Dictionary
		var json_export: Dictionary = lab.call("export_detailed_report_json", "res://reports/p1_18c_combat_lab.json") as Dictionary
		var txt_export: Dictionary = lab.call("export_detailed_report_text", "res://reports/p1_18c_combat_lab.txt") as Dictionary
		_print_safe("/combatlab report ok=%s json=%s txt=%s" % [str(report2.get("ok", false)), str(json_export.get("path", "")), str(txt_export.get("path", ""))])
		return bool(report2.get("ok", false)) and bool(json_export.get("ok", false)) and bool(txt_export.get("ok", false))
	if lower.contains("run"):
		var report3: Dictionary = lab.call("run_spell_suite", {"seed": 42}) as Dictionary
		var text: String = str(lab.call("build_text_report", report3))
		_print_safe(text, 2200)
		return bool(report3.get("ok", false))
	_print_safe("/combatlab unknown; use /combatlab help")
	return true


func _combat_lab_parse_spell_id(raw: String, default_id: int = 101) -> int:
	var parts: PackedStringArray = raw.split(" ", false)
	for index in range(parts.size()):
		if parts[index].to_lower() == "cast" and index + 1 < parts.size():
			return int(parts[index + 1])
	return default_id


func _cmd_zonecreator(raw: String) -> bool:
	if zone_viewer == null:
		_print_safe("/zonecreator missing zone_viewer")
		return false
	var lower = raw.to_lower()
	if lower == "/zonecreator" or lower == "/zc" or lower.contains("help"):
		_print_safe("/zonecreator classify <zone...> | export <zone...> | dryrun <zone...> | dungeon <zone...> | dungeondryrun <zone...> | dungeonreport <zone...> | manifest")
		return true
	if lower.contains("manifest"):
		return _cmd_zonecreator_manifest()
	if lower.contains("classify") or lower.contains("coverage"):
		return _cmd_zonecreator_classify(raw)
	if lower.contains("dungeonreport") or lower.contains("dungeonvalidate"):
		return _cmd_zonecreator_dungeon_report_c3(raw)
	if lower.contains("dungeon"):
		return _cmd_zonecreator_dungeon(raw, lower.contains("dryrun"))
	if lower.contains("dryrun"):
		return _cmd_zonecreator_export(raw, true)
	if lower.contains("export"):
		return _cmd_zonecreator_export(raw, false)
	_print_safe("/zonecreator unknown; use: /zonecreator export 0 1")
	return true


func _cmd_zonecreator_classify(raw: String) -> bool:
	if zone_viewer == null:
		_print_safe("/zonecreator classify missing zone_viewer")
		return false
	var zones := _zonecreator_zone_ids_from_command(raw)
	if zones.is_empty():
		if zone_viewer != null:
			var runtime_zones: Variant = zone_viewer.get("zones")
			if typeof(runtime_zones) == TYPE_ARRAY:
				zones = runtime_zones as Array
	if zones.is_empty():
		_print_safe("usage: /zonecreator classify 0 1")
		return true
	var resolver: RefCounted = DaocZoneKindResolverScript.new()
	if resolver == null or not resolver.has_method("classify_zones"):
		_print_safe("/zonecreator classify missing DaocZoneKindResolver")
		return false
	var manifest: Dictionary = resolver.call("classify_zones", zone_viewer, zones) as Dictionary
	_print_safe("/zonecreator classify zones=%s supported=%s unsupported=%s unknown=%s kinds=%s next=%s" % [
		str(manifest.get("zone_ids", zones)),
		str(manifest.get("supported_zones", [])),
		str(manifest.get("unsupported_zones", [])),
		str(manifest.get("unknown_zones", [])),
		str(manifest.get("kind_counts", {})),
		str(manifest.get("recommended_next_step", "")),
	], 2200)
	return bool(manifest.get("ok", false))


func _cmd_zonecreator_export(raw: String, dry_run: bool) -> bool:
	var zones := _zonecreator_zone_ids_from_command(raw)
	if zones.is_empty():
		_print_safe("usage: /zonecreator export 0 1 or /zonecreator dryrun 0 1")
		return true
	var creator: RefCounted = DaocZoneCreatorScript.new()
	if creator == null or not creator.has_method("export_zones_batch_a7"):
		_print_safe("/zonecreator missing DaocZoneCreator.export_zones_batch_a7")
		return false
	var options := {
		"dry_run": dry_run,
		"write_manifest": not dry_run,
		"require_manifest_write": not dry_run,
	}
	var manifest: Dictionary = creator.call("export_zones_batch_a7", zone_viewer, zones, options) as Dictionary
	_print_safe("/zonecreator %s zones=%s ok=%s ok_count=%d fail_count=%d supported=%s unsupported=%s manifest_written=%s path=%s" % [
		"dryrun" if dry_run else "export",
		str(manifest.get("zones_to_export", zones)),
		str(manifest.get("ok", false)),
		int(manifest.get("ok_count", 0)),
		int(manifest.get("fail_count", 0)),
		str(manifest.get("supported_zones", [])),
		str(manifest.get("unsupported_zones", [])),
		str(manifest.get("manifest_written", false)),
		str(manifest.get("manifest_path", A7_ZONECREATOR_MANIFEST_PATH)),
	], 2200)
	return bool(manifest.get("ok", false))



func _cmd_zonecreator_dungeon(raw: String, dry_run: bool) -> bool:
	var zones := _zonecreator_zone_ids_from_command(raw)
	if zones.is_empty():
		_print_safe("usage: /zonecreator dungeon 19 21 or /zonecreator dungeondryrun 19 21")
		return true
	var creator: RefCounted = DaocZoneCreatorScript.new()
	if creator == null or not creator.has_method("export_dungeon_scenes_batch_c2"):
		_print_safe("/zonecreator missing DaocZoneCreator.export_dungeon_scenes_batch_c2")
		return false
	var options := {
		"dry_run": dry_run,
		"write_manifest": not dry_run,
	}
	var manifest: Dictionary = creator.call("export_dungeon_scenes_batch_c2", zone_viewer, zones, options) as Dictionary
	_print_safe("/zonecreator %s zones=%s ok=%s ok_count=%d fail_count=%d exported=%s failed=%s manifest_written=%s path=%s next=%s" % [
		"dungeondryrun" if dry_run else "dungeon",
		str(manifest.get("zones_to_export", zones)),
		str(manifest.get("ok", false)),
		int(manifest.get("ok_count", 0)),
		int(manifest.get("fail_count", 0)),
		str(manifest.get("exported_zones", [])),
		str(manifest.get("failed_zones", [])),
		str(manifest.get("manifest_written", false)),
		str(manifest.get("manifest_path", "res://reports/generated/zones/dungeon_manifest.json")),
		str(manifest.get("recommended_next_step", "")),
	], 2200)
	return bool(manifest.get("ok", false))


func _cmd_zonecreator_dungeon_report_c3(raw: String) -> bool:
	var zones := _zonecreator_zone_ids_from_command(raw)
	if zones.is_empty():
		zones = [19, 21]
	var creator: RefCounted = DaocZoneCreatorScript.new()
	if creator == null or not creator.has_method("validate_generated_dungeon_scenes_c3"):
		_print_safe("/zonecreator missing DaocZoneCreator.validate_generated_dungeon_scenes_c3")
		return false
	var report: Dictionary = creator.call("validate_generated_dungeon_scenes_c3", zone_viewer, zones, {"write_reports": true}) as Dictionary
	_print_safe("/zonecreator dungeonreport zones=%s ok=%s ok_count=%d fail_count=%d json=%s txt=%s next=%s" % [
		str(report.get("zones", zones)),
		str(report.get("ok", false)),
		int(report.get("ok_count", 0)),
		int(report.get("fail_count", 0)),
		str(report.get("report_json_path", "res://reports/daoc_generated_dungeon_report.json")),
		str(report.get("report_txt_path", "res://reports/daoc_generated_dungeon_report.txt")),
		str(report.get("recommended_next_step", "")),
	], 2200)
	return bool(report.get("ok", false))


func _cmd_zonecreator_manifest() -> bool:
	if not FileAccess.file_exists(A7_ZONECREATOR_MANIFEST_PATH):
		_print_safe("/zonecreator manifest missing path=%s" % A7_ZONECREATOR_MANIFEST_PATH)
		return true
	var file := FileAccess.open(A7_ZONECREATOR_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_print_safe("/zonecreator manifest read failed error=%s" % str(FileAccess.get_open_error()))
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_print_safe("/zonecreator manifest invalid json len=%d" % text.length())
		return false
	var manifest: Dictionary = parsed as Dictionary
	_print_safe("/zonecreator manifest ok=%s zones=%s ok_count=%d fail_count=%d supported=%s unsupported=%s elapsed_ms=%d" % [
		str(manifest.get("ok", false)),
		str(manifest.get("zones_to_export", [])),
		int(manifest.get("ok_count", 0)),
		int(manifest.get("fail_count", 0)),
		str(manifest.get("supported_zones", [])),
		str(manifest.get("unsupported_zones", [])),
		int(manifest.get("elapsed_ms", 0)),
	], 2200)
	return true


func _zonecreator_zone_ids_from_command(raw: String) -> Array:
	var zones: Array = []
	var parts := raw.split(" ", false)
	for i in range(1, parts.size()):
		var token := str(parts[i]).strip_edges()
		if not token.is_valid_int():
			continue
		var znum := int(token)
		if znum < 0:
			continue
		if zones.has(znum):
			continue
		zones.append(znum)
	return zones


func _ensure_generated_dungeon_runtime_bridge_17d() -> RefCounted:
	if _generated_dungeon_runtime_bridge_17d == null:
		if zone_viewer != null and zone_viewer.has_method("ensure_generated_dungeon_runtime_bridge_17d"):
			_generated_dungeon_runtime_bridge_17d = zone_viewer.call("ensure_generated_dungeon_runtime_bridge_17d") as RefCounted
		else:
			_generated_dungeon_runtime_bridge_17d = DaocGeneratedDungeonRuntimeBridgeScript.new()
			if _generated_dungeon_runtime_bridge_17d != null and _generated_dungeon_runtime_bridge_17d.has_method("configure"):
				_generated_dungeon_runtime_bridge_17d.call("configure", zone_viewer)
	return _generated_dungeon_runtime_bridge_17d


func _cmd_generated_dungeon_17d(raw: String) -> bool:
	var lower: String = raw.to_lower()
	if lower == "/generateddungeon" or lower == "/gdungeon" or lower.contains("help"):
		_print_safe("/generateddungeon attach <zone> | attachspawn <zone> | spawn <zone> | detach <zone> | detachall | status | report (P1-17E1 WorldDestination; Ctrl+F4 enter, Ctrl+F3 exit/restore)")
		return true
	var bridge: RefCounted = _ensure_generated_dungeon_runtime_bridge_17d()
	if bridge == null:
		_print_safe("/generateddungeon missing P1-17D bridge")
		return false
	if lower.contains("status"):
		var snap: Dictionary = bridge.call("debug_snapshot") as Dictionary
		var resolver_snap: Dictionary = snap.get("destination_resolver", {}) as Dictionary
		_print_safe("/generateddungeon status bridge=%s attached=%s count=%d destination=%s adapters=%d last=%s error=%s" % [
			str(snap.get("bridge_root_present", false)),
			str(snap.get("attached_zones", [])),
			int(snap.get("attached_zone_count", 0)),
			str(resolver_snap.get("checkpoint", "missing")),
			int(resolver_snap.get("adapter_count", 0)),
			str(snap.get("last_operation", "")),
			str(snap.get("last_error", "")),
		], 2200)
		return true
	if lower.contains("detachall") or lower.contains("detach all"):
		var detach_all: Dictionary = bridge.call("detach_all_dungeon_scenes", player) as Dictionary
		_print_safe("/generateddungeon detachall ok=%s detached=%s attached=%s" % [str(detach_all.get("ok", false)), str(detach_all.get("detached_zones", [])), str(detach_all.get("attached_zones", []))], 1600)
		return bool(detach_all.get("ok", false))
	if lower.contains("report"):
		var report: Dictionary = bridge.call("write_runtime_report", [], {"write_reports": true}) as Dictionary
		_print_safe("/generateddungeon report ok=%s ok_count=%d fail_count=%d attached=%s json=%s txt=%s" % [str(report.get("ok", false)), int(report.get("ok_count", 0)), int(report.get("fail_count", 0)), str(report.get("attached_zones", [])), str(report.get("report_json_path", "")), str(report.get("report_txt_path", ""))], 1800)
		return bool(report.get("ok", false))
	var zone_id: int = _generated_zone_id_from_command(raw)
	if zone_id < 0:
		zone_id = 19
	var options: Dictionary = {
		"auto_export_missing": false,
		"isolate_exterior": true,
		"runtime_scale_compensation": 10.0,
		"remember_exterior_player_state": true,
		"destination_backend_preference": "auto",
	}
	if zone_viewer != null:
		options["spawn_z_offset_raw"] = float(zone_viewer.get("generated_dungeon_runtime_spawn_z_offset_raw"))
		options["auto_export_missing"] = bool(zone_viewer.get("generated_dungeon_runtime_auto_export_missing"))
		options["isolate_exterior"] = bool(zone_viewer.get("generated_dungeon_runtime_isolate_exterior"))
		options["runtime_scale_compensation"] = float(zone_viewer.get("generated_dungeon_runtime_scale_compensation"))
		options["remember_exterior_player_state"] = bool(zone_viewer.get("generated_dungeon_runtime_remember_exterior_player_state"))
		options["destination_backend_preference"] = str(zone_viewer.get("generated_dungeon_runtime_destination_backend_preference"))
	if lower.contains("detach"):
		var detach_result: Dictionary = bridge.call("detach_dungeon_scene", zone_id, player) as Dictionary
		_print_safe("/generateddungeon detach zone%03d ok=%s detached=%s attached=%s" % [zone_id, str(detach_result.get("ok", false)), str(detach_result.get("detached", false)), str(detach_result.get("attached_zones", []))], 1600)
		return bool(detach_result.get("ok", false))
	if lower.contains("spawn") and not lower.contains("attach"):
		var spawn_only: Dictionary = bridge.call("spawn_player_on_dungeon", player, zone_id, options) as Dictionary
		var spawn_only_dict: Dictionary = spawn_only.get("spawn", {}) as Dictionary
		_print_safe("/generateddungeon spawn zone%03d ok=%s backend=%s auth=%s player=(%.1f,%.1f,%.1f) error=%s" % [zone_id, str(spawn_only.get("ok", false)), str(spawn_only_dict.get("backend", spawn_only.get("backend", ""))), str(spawn_only_dict.get("authenticity", spawn_only.get("authenticity", ""))), float(spawn_only.get("daoc_x", 0.0)), float(spawn_only.get("daoc_y", 0.0)), float(spawn_only.get("daoc_z", 0.0)), str(spawn_only.get("error", ""))], 2200)
		return bool(spawn_only.get("ok", false))
	if lower.contains("attachspawn") or lower.contains("attach spawn"):
		var attach_spawn: Dictionary = bridge.call("attach_and_spawn_player", zone_viewer, player, zone_id, options) as Dictionary
		var spawn: Dictionary = attach_spawn.get("spawn", {}) as Dictionary
		_print_safe("/generateddungeon attachspawn zone%03d ok=%s backend=%s auth=%s attached=%s player=(%.1f,%.1f,%.1f) json=%s txt=%s error=%s" % [
			zone_id,
			str(attach_spawn.get("ok", false)),
			str(spawn.get("backend", "")),
			str(spawn.get("authenticity", "")),
			str(attach_spawn.get("attached_zones", [])),
			float(spawn.get("daoc_x", 0.0)),
			float(spawn.get("daoc_y", 0.0)),
			float(spawn.get("daoc_z", 0.0)),
			"res://reports/daoc_generated_dungeon_runtime_report.json",
			"res://reports/daoc_generated_dungeon_runtime_report.txt",
			str(attach_spawn.get("error", "")),
		], 2600)
		bridge.call("write_runtime_report", [zone_id], {"write_reports": true})
		return bool(attach_spawn.get("ok", false))
	if lower.contains("attach"):
		var attach_result: Dictionary = bridge.call("attach_dungeon_scene", zone_viewer, zone_id, options) as Dictionary
		_print_safe("/generateddungeon attach zone%03d ok=%s attached=%s path=%s error=%s" % [zone_id, str(attach_result.get("ok", false)), str(attach_result.get("attached_zones", [])), str(attach_result.get("scene_path", "")), str(attach_result.get("error", ""))], 1800)
		return bool(attach_result.get("ok", false))
	_print_safe("/generateddungeon unknown; use /generateddungeon help")
	return true


func _cmd_generated_zone(raw: String) -> bool:
	var lower: String = raw.to_lower()
	if lower == "/generated" or lower == "/gzone" or lower.contains("help"):
		_print_safe("/generated manifest | load <zone> | inst <zone> | attach <zone> | attachall | detach <zone> | detachall | status | parity | focus brghouse | boot | report ; attachall ignores unsupported zone kinds")
		return true
	var loader: RefCounted = DaocGeneratedZoneSceneLoaderScript.new()
	if loader == null:
		_print_safe("/generated missing DaocGeneratedZoneSceneLoader")
		return false

	if lower.contains("parity") or lower.contains("report") or lower.contains("focus") or lower.contains("boot"):
		return _cmd_generated_parity_p1_19a(raw)
	if lower.contains("status"):
		return _cmd_generated_runtime_status_a9()
	if lower.contains("detachall") or lower.contains("detach all"):
		return _cmd_generated_runtime_detach_all_a9()
	if lower.contains("attachall") or lower.contains("attach all"):
		return _cmd_generated_runtime_attach_all_a9()
	if lower.contains("detach"):
		var detach_zone_id: int = _generated_zone_id_from_command(raw)
		if detach_zone_id < 0:
			_print_safe("usage: /generated detach 0 or /generated detachall")
			return true
		return _cmd_generated_runtime_detach_a9(detach_zone_id)
	if lower.contains("attach"):
		var attach_zone_id: int = _generated_zone_id_from_command(raw)
		if attach_zone_id < 0:
			_print_safe("usage: /generated attach 0 or /generated attachall")
			return true
		return _cmd_generated_runtime_attach_a9(attach_zone_id)
	if lower.contains("manifest"):
		var manifest_result: Dictionary = loader.call("load_manifest", A7_ZONECREATOR_MANIFEST_PATH) as Dictionary
		if not bool(manifest_result.get("ok", false)):
			_print_safe("/generated manifest ok=false path=%s error=%s" % [A7_ZONECREATOR_MANIFEST_PATH, str(manifest_result.get("error", ""))])
			return true
		_print_safe("/generated manifest ok=true zones=%s exportable=%s ok_count=%d fail_count=%d unsupported=%d" % [
			str(manifest_result.get("zones", [])),
			str(manifest_result.get("exportable_zones", [])),
			int(manifest_result.get("ok_count", 0)),
			int(manifest_result.get("fail_count", 0)),
			int(manifest_result.get("unsupported_count", 0)),
		], 1800)
		return true
	var zone_id: int = _generated_zone_id_from_command(raw)
	if zone_id < 0:
		_print_safe("usage: /generated load 0 or /generated inst 0")
		return true
	if lower.contains("inst"):
		var inst_result: Dictionary = loader.call("instantiate_generated_zone_scene", zone_id, false, A7_ZONECREATOR_MANIFEST_PATH) as Dictionary
		_print_safe("/generated inst zone%03d ok=%s path=%s branches=%s missing=%s" % [
			zone_id,
			str(inst_result.get("ok", false)),
			str(inst_result.get("scene_path", "")),
			str(inst_result.get("present_branches", [])),
			str(inst_result.get("missing_branches", [])),
		], 1800)
		return bool(inst_result.get("ok", false))
	if lower.contains("load"):
		var load_result: Dictionary = loader.call("load_generated_zone_scene", zone_id, A7_ZONECREATOR_MANIFEST_PATH) as Dictionary
		_print_safe("/generated load zone%03d ok=%s path=%s error=%s" % [
			zone_id,
			str(load_result.get("ok", false)),
			str(load_result.get("scene_path", "")),
			str(load_result.get("error", "")),
		], 1600)
		return bool(load_result.get("ok", false))
	_print_safe("/generated unknown; use /generated help")
	return true



func _ensure_generated_zone_runtime_bridge_a9() -> RefCounted:
	if _generated_zone_runtime_bridge_a9 == null:
		_generated_zone_runtime_bridge_a9 = DaocGeneratedZoneRuntimeBridgeScript.new()
		if _generated_zone_runtime_bridge_a9 != null and _generated_zone_runtime_bridge_a9.has_method("configure"):
			_generated_zone_runtime_bridge_a9.call("configure", zone_viewer, A7_ZONECREATOR_MANIFEST_PATH)
	return _generated_zone_runtime_bridge_a9


func _cmd_generated_runtime_status_a9() -> bool:
	var bridge: RefCounted = _ensure_generated_zone_runtime_bridge_a9()
	if bridge == null or not bridge.has_method("debug_snapshot"):
		_print_safe("/generated status missing P1-16A9 bridge")
		return false
	var snap: Dictionary = bridge.call("debug_snapshot") as Dictionary
	_print_safe("/generated status bridge=%s attached=%s count=%d last=%s error=%s" % [
		str(snap.get("bridge_root_present", false)),
		str(snap.get("attached_zones", [])),
		int(snap.get("attached_zone_count", 0)),
		str(snap.get("last_operation", "")),
		str(snap.get("last_error", "")),
	], 1600)
	return true


func _cmd_generated_runtime_attach_a9(zone_id: int) -> bool:
	if zone_viewer == null:
		_print_safe("/generated attach missing zone_viewer")
		return false
	var bridge: RefCounted = _ensure_generated_zone_runtime_bridge_a9()
	if bridge == null or not bridge.has_method("attach_zone_scene"):
		_print_safe("/generated attach missing P1-16A9 bridge")
		return false
	var result: Dictionary = bridge.call("attach_zone_scene", zone_viewer, zone_id, A7_ZONECREATOR_MANIFEST_PATH, true) as Dictionary
	_print_safe("/generated attach zone%03d ok=%s attached=%s count=%d path=%s error=%s" % [
		zone_id,
		str(result.get("ok", false)),
		str(result.get("attached_zones", [])),
		int(result.get("attached_zone_count", 0)),
		str(result.get("scene_path", "")),
		str(result.get("error", "")),
	], 1800)
	return bool(result.get("ok", false))


func _cmd_generated_runtime_attach_all_a9() -> bool:
	if zone_viewer == null:
		_print_safe("/generated attachall missing zone_viewer")
		return false
	var bridge: RefCounted = _ensure_generated_zone_runtime_bridge_a9()
	if bridge == null or not bridge.has_method("attach_manifest_zones"):
		_print_safe("/generated attachall missing P1-16A9 bridge")
		return false
	var result: Dictionary = bridge.call("attach_manifest_zones", zone_viewer, A7_ZONECREATOR_MANIFEST_PATH, 0) as Dictionary
	_print_safe("/generated attachall ok=%s attached=%s failed=%s count=%d error=%s" % [
		str(result.get("ok", false)),
		str(result.get("attached_zones", [])),
		str(result.get("failed_zones", [])),
		int(result.get("attached_zone_count", 0)),
		str(result.get("error", "")),
	], 1800)
	return bool(result.get("ok", false))


func _cmd_generated_runtime_detach_a9(zone_id: int) -> bool:
	var bridge: RefCounted = _ensure_generated_zone_runtime_bridge_a9()
	if bridge == null or not bridge.has_method("detach_zone_scene"):
		_print_safe("/generated detach missing P1-16A9 bridge")
		return false
	var result: Dictionary = bridge.call("detach_zone_scene", zone_id) as Dictionary
	_print_safe("/generated detach zone%03d ok=%s detached=%s attached=%s count=%d" % [
		zone_id,
		str(result.get("ok", false)),
		str(result.get("detached", false)),
		str(result.get("attached_zones", [])),
		int(result.get("attached_zone_count", 0)),
	], 1600)
	return bool(result.get("ok", false))


func _cmd_generated_runtime_detach_all_a9() -> bool:
	var bridge: RefCounted = _ensure_generated_zone_runtime_bridge_a9()
	if bridge == null or not bridge.has_method("detach_all_generated_zones"):
		_print_safe("/generated detachall missing P1-16A9 bridge")
		return false
	var result: Dictionary = bridge.call("detach_all_generated_zones") as Dictionary
	_print_safe("/generated detachall ok=%s detached=%s attached=%s count=%d" % [
		str(result.get("ok", false)),
		str(result.get("detached_zones", [])),
		str(result.get("attached_zones", [])),
		int(result.get("attached_zone_count", 0)),
	], 1600)
	return bool(result.get("ok", false))


func _cmd_generated_parity_p1_19a(raw: String) -> bool:
	var audit: RefCounted = DaocGeneratedSceneParityAuditScript.new()
	if audit == null or not audit.has_method("run_parity_audit"):
		_print_safe("/generated parity missing P1-19A audit")
		return false
	var options: Dictionary = _generated_parity_options_p1_19a(raw)
	var report: Dictionary = audit.call("run_parity_audit", zone_viewer, options) as Dictionary
	var generated: Dictionary = report.get("generated_scene", {}) as Dictionary
	var runtime: Dictionary = report.get("runtime_viewer", {}) as Dictionary
	var fixtures: Dictionary = report.get("fixtures", {}) as Dictionary
	var focus: Dictionary = report.get("critical_focus", {}) as Dictionary
	var written: Dictionary = report.get("written_files", {}) as Dictionary
	_print_safe("/generated parity verdict=%s loadable=%s scene=%s runtime=%s fixtures runtime=%d generated=%d missing=%d focus=%s json=%s txt=%s" % [
		str(report.get("overall_verdict", "")),
		str(generated.get("loadable", false)),
		str(generated.get("scene_path", "")),
		str(runtime.get("available", false)),
		int(fixtures.get("runtime_fixture_count", 0)),
		int(fixtures.get("generated_fixture_count", 0)),
		int(fixtures.get("missing_generated_count", 0)),
		str(focus.get("verdict", "")),
		str(written.get("json", "")),
		str(written.get("txt", "")),
	], 2200)
	return true


func _generated_parity_options_p1_19a(raw: String) -> Dictionary:
	var options: Dictionary = {}
	if zone_viewer != null and zone_viewer.has_method("build_generated_scene_parity_options_p1_19a"):
		options = zone_viewer.call("build_generated_scene_parity_options_p1_19a") as Dictionary
	else:
		options = {
			"zone_id": 0,
			"manifest_path": A7_ZONECREATOR_MANIFEST_PATH,
			"report_dir": "res://reports/p1_19a_generated_scene_parity",
			"write_reports": true,
		}
	var zone_id: int = _generated_zone_id_from_command(raw)
	if zone_id >= 0:
		options["zone_id"] = zone_id
	var lower: String = raw.to_lower()
	if lower.contains("boot"):
		options["boot_enabled"] = true
	if lower.contains("focus"):
		options["focus_critical_fixtures"] = true
	if lower.contains("report") or lower.contains("parity") or lower.contains("boot"):
		options["write_reports"] = true
	return options


func _generated_zone_id_from_command(raw: String) -> int:
	var parts: PackedStringArray = raw.split(" ", false)
	for i in range(1, parts.size()):
		var token: String = str(parts[i]).strip_edges()
		if token.is_valid_int():
			return int(token)
	return -1


func _cmd_zonejump_debug(raw: String) -> bool:
	if zone_viewer == null:
		_print_safe("/zonejump missing zone_viewer")
		return false
	var lower = raw.to_lower()
	if lower.contains("help"):
		_print_safe("/zonejump status | last | log | nearest | go nearest | go <id> | auto on|off|status")
		return true
	if lower.contains("auto on"):
		return _cmd_zonejump_auto(true)
	if lower.contains("auto off"):
		return _cmd_zonejump_auto(false)
	if lower.contains("auto"):
		return _cmd_zonejump_auto_status()
	if lower.contains("go nearest"):
		return _cmd_zonejump_go_nearest()
	if lower.begins_with("/zonejump go") or lower.begins_with("/zj go"):
		return _cmd_zonejump_go_id(raw)
	if lower.contains("transition"):
		if zone_viewer.has_method("get_zonejump_transition_lines"):
			var transition_lines: PackedStringArray = zone_viewer.call("get_zonejump_transition_lines", 8) as PackedStringArray
			_print_safe("\n".join(transition_lines), 1800)
			return true
		_print_safe("/zonejump transition missing")
		return false
	if lower.contains("nearest"):
		return _cmd_zonejump_nearest()
	if lower.contains("last"):
		if zone_viewer.has_method("get_zonejump_last_event_lines"):
			var last_lines: PackedStringArray = zone_viewer.call("get_zonejump_last_event_lines") as PackedStringArray
			_print_safe("\n".join(last_lines), 1600)
			return true
		_print_safe("/zonejump last missing")
		return false
	if lower.contains("log"):
		if zone_viewer.has_method("get_zonejump_status_lines"):
			var log_lines: PackedStringArray = zone_viewer.call("get_zonejump_status_lines", 8) as PackedStringArray
			_print_safe("\n".join(log_lines), 2600)
			return true
		_print_safe("/zonejump log missing")
		return false
	if zone_viewer.has_method("get_zonejump_status_lines"):
		var lines: PackedStringArray = zone_viewer.call("get_zonejump_status_lines", 4) as PackedStringArray
		_print_safe("\n".join(lines), 2200)
		return true
	if zone_viewer.has_method("get_zonejump_debug_snapshot"):
		_print_safe("/zonejump status -> %s" % _compact_value(zone_viewer.call("get_zonejump_debug_snapshot"), 1200), 1400)
		return true
	_print_safe("/zonejump missing")
	return false


func _cmd_zonejump_auto(enabled: bool) -> bool:
	if zone_viewer != null and zone_viewer.has_method("set_zonejump_auto_transition_enabled"):
		var snap: Dictionary = zone_viewer.call("set_zonejump_auto_transition_enabled", enabled) as Dictionary
		_print_safe("/zonejump auto %s -> direct=%s auto=%s" % ["on" if enabled else "off", str(snap.get("direct_transition_enabled", false)), str(snap.get("auto_transition_enabled", false))])
		return true
	_print_safe("/zonejump auto missing")
	return false


func _cmd_zonejump_auto_status() -> bool:
	if zone_viewer != null and zone_viewer.has_method("get_zonejump_transition_debug_snapshot"):
		var snap: Dictionary = zone_viewer.call("get_zonejump_transition_debug_snapshot") as Dictionary
		_print_safe("/zonejump auto status direct=%s auto=%s load_missing=%s" % [str(snap.get("direct_transition_enabled", false)), str(snap.get("auto_transition_enabled", false)), str(snap.get("load_missing_target_zone", false))])
		return true
	_print_safe("/zonejump auto status missing")
	return false


func _cmd_zonejump_go_nearest() -> bool:
	if zone_viewer != null and zone_viewer.has_method("execute_zonejump_nearest_transition"):
		var result: Dictionary = zone_viewer.call("execute_zonejump_nearest_transition", -1.0, "command_go_nearest") as Dictionary
		_print_safe("/zonejump go nearest ok=%s target=%s reason=%s" % [str(result.get("ok", false)), str(result.get("target", "")), str(result.get("reason", ""))], 1600)
		return true
	_print_safe("/zonejump go nearest missing")
	return false


func _cmd_zonejump_go_id(raw: String) -> bool:
	if zone_viewer == null or not zone_viewer.has_method("execute_zonejump_transition_by_id"):
		_print_safe("/zonejump go <id> missing")
		return false
	var parts := raw.split(" ", false)
	if parts.size() < 3:
		_print_safe("usage: /zonejump go <id> or /zonejump go nearest")
		return true
	var token := str(parts[2]).strip_edges()
	if not token.is_valid_int():
		_print_safe("/zonejump go invalid id=%s" % token)
		return true
	var result: Dictionary = zone_viewer.call("execute_zonejump_transition_by_id", int(token), -1, "command_go_id") as Dictionary
	_print_safe("/zonejump go %s ok=%s target=%s reason=%s" % [token, str(result.get("ok", false)), str(result.get("target", "")), str(result.get("reason", ""))], 1600)
	return true


func _cmd_zonejump_nearest() -> bool:
	if zone_viewer != null and zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"):
		var snap: Dictionary = zone_viewer.call("get_zonejump_nearest_debug_snapshot", 2400.0) as Dictionary
		if bool(snap.get("ok", false)):
			_print_safe("/zonejump nearest id=%s name=%s target=%s dist=%.1f deferred=%s" % [
				str(snap.get("id", "?")),
				str(snap.get("name", "")),
				str(snap.get("target", "")),
				float(snap.get("distance_raw", -1.0)),
				str(snap.get("transition_deferred", true)),
			])
		else:
			_print_safe("/zonejump nearest none radius=%.1f entries=%d" % [float(snap.get("radius_raw", 0.0)), int(snap.get("entry_count", 0))])
		return true
	if targeting != null and targeting.has_method("target_zonejump_nearest"):
		var ok := bool(targeting.call("target_zonejump_nearest", 2400.0, false))
		if targeting.has_method("get_target_debug_string"):
			_print_safe(str(targeting.call("get_target_debug_string")))
		else:
			_print_safe("/zonejump nearest -> %s" % str(ok))
		return true
	_print_safe("/zonejump nearest missing")
	return false


func _cmd_target_nearest() -> bool:
	if targeting != null and targeting.has_method("target_nearest_object"):
		return bool(targeting.call("target_nearest_object"))
	return false


func _cmd_target_nearest_zonejump() -> bool:
	if targeting != null and targeting.has_method("target_zonejump_nearest"):
		return bool(targeting.call("target_zonejump_nearest"))
	return false


func _cmd_clear_target() -> bool:
	if targeting != null and targeting.has_method("clear_target"):
		targeting.call("clear_target")
		_print_safe("/cleartarget")
		return true
	return false


func _cmd_target_status() -> bool:
	if targeting != null and targeting.has_method("get_target_debug_string"):
		_print_safe(str(targeting.call("get_target_debug_string")))
		return true
	return false


## P1-21A — memes intentions que les touches, mais par commande. Utile en
## headless et pour verifier l'etat sans deplacer le joueur.
func _combat_client_p1_21a() -> Node:
	if zone_viewer == null:
		return null
	return zone_viewer.get("_combat_client") as Node


func _cmd_target_nearest_living_p1_21a() -> bool:
	var client: Node = _combat_client_p1_21a()
	if client == null or not client.has_method("target_nearest"):
		_print_safe("serveur local absent")
		return false
	var found: Dictionary = client.call("target_nearest") as Dictionary
	if not bool(found.get("ok", false)):
		_print_safe("aucune cible vivante : %s" % str(found.get("reason", "?")))
		return false
	_print_safe("cible : %s niv %d, %d/%d PV, %.0f unites" % [
		str(found.get("name", "?")), int(found.get("level", 0)),
		int(found.get("health", 0)), int(found.get("max_health", 0)),
		float(found.get("distance_raw", -1.0)),
	])
	return true


func _cmd_toggle_attack_p1_21a() -> bool:
	var client: Node = _combat_client_p1_21a()
	if client == null or not client.has_method("toggle_attack"):
		_print_safe("serveur local absent")
		return false
	var result: Dictionary = client.call("toggle_attack") as Dictionary
	if not bool(result.get("ok", false)):
		_print_safe("attaque refusee : %s" % str(result.get("reason", "?")))
		return false
	_print_safe("attaque : %s" % str(result.get("target", "cessee")))
	return true


func _cmd_combat_status_p1_21a() -> bool:
	if zone_viewer == null or not zone_viewer.has_method("get_local_server_debug_snapshot"):
		_print_safe("serveur local absent")
		return false
	_print_safe(JSON.stringify(zone_viewer.call("get_local_server_debug_snapshot")))
	return true


func _cmd_dol_status() -> bool:
	if dol_client != null and dol_client.has_method("debug_compact_string"):
		_print_safe(str(dol_client.call("debug_compact_string")))
		return true
	_print_safe("dol=missing")
	return false


func _cmd_dol_login(account: String = "debug") -> bool:
	if dol_client != null and dol_client.has_method("start_login"):
		var ok := bool(dol_client.call("start_login", account, "", true))
		_print_safe("/dol login %s -> %s" % [account, str(ok)])
		return ok
	return false


func _cmd_dol_charlist() -> bool:
	if dol_client != null and dol_client.has_method("request_charlist"):
		var ok := bool(dol_client.call("request_charlist"))
		_print_safe("/dol charlist -> %s" % str(ok))
		return ok
	return false


func _cmd_dol_enter_world(index: int = 0) -> bool:
	if dol_client != null and dol_client.has_method("enter_world"):
		var ok := bool(dol_client.call("enter_world", index))
		_print_safe("/dol enter %d -> %s" % [index, str(ok)])
		return ok
	return false


func _cmd_dol_disconnect() -> bool:
	if dol_client != null and dol_client.has_method("disconnect_from_server"):
		var ok := bool(dol_client.call("disconnect_from_server", "command"))
		_print_safe("/dol disconnect -> %s" % str(ok))
		return ok
	return false


func _cmd_dol_position() -> bool:
	if dol_client != null and dol_client.has_method("send_position_update_stub"):
		var ok := bool(dol_client.call("send_position_update_stub", "command"))
		if dol_client.has_method("get_position_sync_debug_snapshot"):
			var snap: Dictionary = dol_client.call("get_position_sync_debug_snapshot") as Dictionary
			_print_safe("/dol pos -> %s seq=%d" % [str(ok), int(snap.get("position_sequence", 0))])
		else:
			_print_safe("/dol pos -> %s" % str(ok))
		return ok
	return false


func _cmd_dol_heading() -> bool:
	if dol_client != null and dol_client.has_method("send_heading_update_stub"):
		var ok := bool(dol_client.call("send_heading_update_stub", "command"))
		_print_safe("/dol heading -> %s" % str(ok))
		return ok
	return false


func _cmd_dol_region(zone_id: int = -1, region_id: int = -1) -> bool:
	if dol_client != null and dol_client.has_method("simulate_regionchange_stub"):
		var ok := bool(dol_client.call("simulate_regionchange_stub", zone_id, region_id, "command"))
		_print_safe("/dol region zone=%d region=%d -> %s" % [zone_id, region_id, str(ok)])
		return ok
	return false


func _cmd_dol_tcp_status() -> bool:
	if dol_client != null and dol_client.has_method("get_p1_n3_debug_snapshot"):
		var snap: Dictionary = dol_client.call("get_p1_n3_debug_snapshot") as Dictionary
		var transport: Dictionary = snap.get("transport", {}) as Dictionary
		_print_safe("/dol tcp attached=%s enabled=%s status=%s host=%s port=%d" % [
			str(snap.get("attached", false)),
			str(transport.get("enabled", false)),
			str(transport.get("status_name", "?")),
			str(transport.get("host", "")),
			int(transport.get("port", 0)),
		])
		return true
	_print_safe("/dol tcp missing")
	return false


func _cmd_dol_packet_status() -> bool:
	if dol_client != null and dol_client.has_method("get_p1_n4_debug_snapshot"):
		var snap: Dictionary = dol_client.call("get_p1_n4_debug_snapshot") as Dictionary
		var layer: Dictionary = snap.get("packet_layer", {}) as Dictionary
		_print_safe("/dol packet attached=%s registry=%d buffer=%d real_protocol=%s" % [
			str(snap.get("attached", false)),
			int(layer.get("registry_size", 0)),
			int(layer.get("receive_buffer_size", 0)),
			str(snap.get("real_protocol_implemented", false)),
		])
		return true
	_print_safe("/dol packet missing")
	return false




func _cmd_dol_wire_status() -> bool:
	if dol_client != null and dol_client.has_method("get_p1_n5a_debug_snapshot"):
		var snap: Dictionary = dol_client.call("get_p1_n5a_debug_snapshot") as Dictionary
		var wire: Dictionary = snap.get("wire", {}) as Dictionary
		var profile: Dictionary = wire.get("profile", {}) as Dictionary
		_print_safe("/dol wire attached=%s client=%d lib=%s host=%s port=%d checksum=%s" % [
			str(snap.get("attached", false)),
			int(profile.get("client_version", 0)),
			str(profile.get("packet_lib", "?")),
			str(profile.get("host", "")),
			int(profile.get("port", 0)),
			str(wire.get("probe_checksum_ok", false)),
		])
		return true
	_print_safe("/dol wire missing")
	return false



func _get_login_flow_1127() -> Node:
	if dol_client != null:
		var flow = dol_client.get("login_flow_1127")
		if flow != null:
			return flow as Node
	return null


func _cmd_dol_loginpacket(raw: String) -> bool:
	var flow := _get_login_flow_1127()
	if flow == null or not flow.has_method("build_login_packet_1127"):
		_print_safe("/dol loginpacket missing")
		return false
	var parts := raw.split(" ", false)
	var account := str(parts[2]) if parts.size() >= 3 else "testgodot"
	var password := str(parts[3]) if parts.size() >= 4 else "testgodot"
	var packet: PackedByteArray = flow.call("build_login_packet_1127", account, password, 1, 0) as PackedByteArray
	_print_safe("/dol loginpacket %s -> %s" % [account, str(flow.call("packet_summary", packet))])
	return packet.size() > 0


func _cmd_dol_charpacket(raw: String) -> bool:
	var flow := _get_login_flow_1127()
	if flow == null or not flow.has_method("build_character_overview_packet_1127"):
		_print_safe("/dol charpacket missing")
		return false
	var realm := _third_token_int_or_default(raw, 1)
	var packet: PackedByteArray = flow.call("build_character_overview_packet_1127", realm, 2, 0) as PackedByteArray
	_print_safe("/dol charpacket realm=%d -> %s" % [realm, str(flow.call("packet_summary", packet))])
	return packet.size() > 0


func _cmd_dol_selectpacket(raw: String) -> bool:
	var flow := _get_login_flow_1127()
	if flow == null or not flow.has_method("build_character_select_packet_1127"):
		_print_safe("/dol selectpacket missing")
		return false
	var idx := _third_token_int_or_default(raw, 0)
	var packet: PackedByteArray = flow.call("build_character_select_packet_1127", idx, 3, 0) as PackedByteArray
	_print_safe("/dol selectpacket idx=%d -> %s" % [idx, str(flow.call("packet_summary", packet))])
	return packet.size() > 0


func _cmd_dol_worldpacket() -> bool:
	var flow := _get_login_flow_1127()
	if flow == null or not flow.has_method("build_world_init_packet_1127"):
		_print_safe("/dol worldpacket missing")
		return false
	var packet: PackedByteArray = flow.call("build_world_init_packet_1127", 4, 0) as PackedByteArray
	_print_safe("/dol worldpacket -> %s" % str(flow.call("packet_summary", packet)))
	return packet.size() > 0


func _cmd_dol_flow(raw: String) -> bool:
	var flow := _get_login_flow_1127()
	if flow == null or not flow.has_method("build_full_offline_flow_packets"):
		_print_safe("/dol flow missing")
		return false
	var parts := raw.split(" ", false)
	var account := str(parts[2]) if parts.size() >= 3 else "testgodot"
	var password := str(parts[3]) if parts.size() >= 4 else "testgodot"
	var packets: Array = flow.call("build_full_offline_flow_packets", account, password, 1, 0) as Array
	_print_safe(str(flow.call("flow_summary", packets)))
	return packets.size() >= 5


func _get_server_fixtures_1127() -> Node:
	if dol_client != null:
		var fixtures = dol_client.get("server_fixtures_1127")
		if fixtures != null:
			return fixtures as Node
	return null


func _cmd_dol_server_fixtures(raw: String) -> bool:
	var fixtures := _get_server_fixtures_1127()
	if fixtures == null or not fixtures.has_method("build_server_fixture_flow"):
		_print_safe("/dol rx missing")
		return false
	var packets: Array = fixtures.call("build_server_fixture_flow") as Array
	_print_safe(str(fixtures.call("fixture_flow_summary", packets)))
	return packets.size() >= 5


func _get_character_bootstrap_1127() -> Node:
	if dol_client != null:
		var bootstrap = dol_client.get("character_bootstrap_1127")
		if bootstrap != null:
			return bootstrap as Node
	return null



func _get_character_select_hud_1127() -> Node:
	if dol_client != null:
		var hud = dol_client.get("character_select_hud_1127")
		if hud != null:
			return hud as Node
	var root := get_tree().current_scene
	if root != null:
		var found := root.find_child("DaocDolCharacterSelectHud1127", true, false)
		if found != null:
			return found
	return null



func _get_pregame_loading_asset_resolver() -> RefCounted:
	if dol_client != null:
		var client_resolver = dol_client.get("pregame_loading_asset_resolver")
		if client_resolver != null:
			return client_resolver as RefCounted
	var hud := _get_character_select_hud_1127()
	if hud != null:
		var hud_resolver = hud.get("asset_resolver")
		if hud_resolver != null:
			return hud_resolver as RefCounted
	return null


func _cmd_dol_assets(raw: String) -> bool:
	var resolver := _get_pregame_loading_asset_resolver()
	if resolver == null:
		_print_safe("/dol assets missing")
		return false
	var lower = raw.to_lower()
	var realm := _realm_from_command_text(lower)
	var section := "summary"
	if lower.contains("help"):
		section = "help"
	elif lower.contains("roots") or lower.contains("root"):
		section = "roots"
	elif lower.contains("pregame"):
		section = "pregame"
	elif lower.contains("loading"):
		section = "loading"
	elif lower.contains("realm") or lower.contains("alb") or lower.contains("mid") or lower.contains("hib"):
		section = "realm"
	elif lower.contains("audit"):
		section = "audit"
	if lower.contains("json") or lower.contains("full"):
		_print_safe("/dol assets: sortie JSON complète désactivée pour éviter output overflow; utilise /dol assets audit|roots|pregame|loading|realm")
		return true
	if resolver.has_method("build_audit_report_lines"):
		var lines: PackedStringArray = resolver.call("build_audit_report_lines", section, realm, -1, -1, "command", 80) as PackedStringArray
		_print_safe("\n".join(lines), 2400)
		return true
	if resolver.has_method("build_asset_source_panel_lines"):
		var panel_lines: PackedStringArray = resolver.call("build_asset_source_panel_lines", realm, -1, -1, "command") as PackedStringArray
		_print_safe("\n".join(panel_lines), 1600)
		return true
	if resolver.has_method("status_snapshot"):
		_print_safe("/dol assets -> %s" % str(resolver.call("status_snapshot")))
		return true
	_print_safe("/dol assets resolver attached, no report method")
	return true


func _realm_from_command_text(lower: String) -> int:
	if lower.contains("mid") or lower.contains("midgard"):
		return 2
	if lower.contains("hib") or lower.contains("hibernia"):
		return 3
	return 1


func _cmd_dol_charhud(raw: String) -> bool:
	var hud := _get_character_select_hud_1127()
	if hud == null or not hud.has_method("build_panel_text"):
		_print_safe("/dol charhud missing")
		return false
	var lower = raw.to_lower()
	if lower.ends_with(" off") and hud.has_method("hide_panel"):
		hud.call("hide_panel")
	elif lower.ends_with(" on") and hud.has_method("show_panel"):
		hud.call("show_panel")
	elif hud.has_method("toggle_panel"):
		hud.call("toggle_panel")
	var text := str(hud.call("force_refresh")) if hud.has_method("force_refresh") else str(hud.call("build_panel_text"))
	_print_safe(text, 1600)
	return true


func _cmd_dol_uiflow(raw: String) -> bool:
	var hud := _get_character_select_hud_1127()
	if hud == null or not hud.has_method("build_login_selection_flow_model"):
		_print_safe("/dol uiflow missing")
		return false
	if hud.has_method("show_panel"):
		hud.call("show_panel")
	var model: Dictionary = hud.call("build_login_selection_flow_model") as Dictionary
	var text := str(hud.call("force_refresh")) if hud.has_method("force_refresh") else str(hud.call("build_panel_text"))
	var selected: Dictionary = model.get("selected", {}) as Dictionary
	var realm: Dictionary = model.get("selected_realm", {}) as Dictionary
	_print_safe("/dol uiflow phase=%s realm=%s chars=%d selected=%s assets=compact(use /dol assets audit)" % [
		str(model.get("ui_phase", "?")),
		str(realm.get("name", "?")),
		int(model.get("character_count", 0)),
		str(selected.get("name", "none")),
	])
	_print_safe(text, 1600)
	return true


func _cmd_dol_loading(raw: String) -> bool:
	var hud := _get_character_select_hud_1127()
	if hud == null or not hud.has_method("start_loading_screen"):
		_print_safe("/dol loading missing")
		return false
	var lower = raw.to_lower()
	if lower.contains("world") or lower.contains("enter"):
		return _cmd_dol_worldloading(raw)
	var snap := {}
	if lower.contains("done") or lower.contains("ok") or lower.contains("complete"):
		snap = hud.call("complete_loading_to_realm_select", "command_done") as Dictionary
	else:
		snap = hud.call("start_loading_screen", "command") as Dictionary
	if hud.has_method("show_panel"):
		hud.call("show_panel")
	_print_safe("/dol loading -> %s" % str(snap))
	return true


func _cmd_dol_worldloading(raw: String) -> bool:
	var hud := _get_character_select_hud_1127()
	if hud == null or not hud.has_method("start_world_loading_screen"):
		_print_safe("/dol worldloading missing")
		return false
	var lower = raw.to_lower()
	var snap := {}
	if lower.contains("done") or lower.contains("ok") or lower.contains("complete"):
		snap = hud.call("complete_world_loading_to_ready", "command_done") as Dictionary
	else:
		snap = hud.call("start_world_loading_screen", "command") as Dictionary
	if hud.has_method("show_panel"):
		hud.call("show_panel")
	_print_safe("/dol worldloading -> %s" % str(snap))
	return true


func _cmd_dol_realm(raw: String) -> bool:
	var hud := _get_character_select_hud_1127()
	if hud == null or not hud.has_method("available_realms"):
		_print_safe("/dol realm missing")
		return false
	var parts := raw.split(" ", false)
	if parts.size() < 3:
		if hud.has_method("complete_loading_to_realm_select"):
			hud.call("complete_loading_to_realm_select", "command_list")
		_print_safe("/dol realm -> %s" % str(hud.call("available_realms")))
		return true
	var realm_token := str(parts[2]).strip_edges()
	var snap := {}
	if dol_client != null and dol_client.has_method("select_login_realm_offline"):
		snap = dol_client.call("select_login_realm_offline", realm_token) as Dictionary
	elif hud.has_method("select_realm"):
		snap = hud.call("select_realm", realm_token) as Dictionary
	if hud.has_method("show_panel"):
		hud.call("show_panel")
	_print_safe("/dol realm %s -> %s" % [realm_token, str(snap)])
	return bool(snap.get("ok", false))


func _cmd_dol_selected(raw: String) -> bool:
	var bootstrap := _get_character_bootstrap_1127()
	if bootstrap == null or not bootstrap.has_method("selected_character_full_snapshot"):
		_print_safe("/dol selected missing")
		return false
	_print_safe("/dol selected -> %s" % str(bootstrap.call("selected_character_full_snapshot")))
	return true


func _cmd_dol_unchoose(raw: String) -> bool:
	var ok := false
	if dol_client != null and dol_client.has_method("unchoose_bootstrap_character"):
		ok = bool(dol_client.call("unchoose_bootstrap_character"))
	else:
		var bootstrap := _get_character_bootstrap_1127()
		if bootstrap == null or not bootstrap.has_method("unselect_character"):
			_print_safe("/dol unchoose missing")
			return false
		ok = bool(bootstrap.call("unselect_character"))
	var hud := _get_character_select_hud_1127()
	if hud != null and hud.has_method("force_refresh"):
		hud.call("force_refresh")
	_print_safe("/dol unchoose -> %s" % str(ok))
	return ok


func _cmd_dol_applybootstrap(raw: String) -> bool:
	var lower = raw.to_lower()
	var wants_real := lower.contains(" real")
	var confirmed := lower.contains(" confirm") or lower.contains(" confirmed")
	if wants_real and dol_client != null and dol_client.has_method("apply_bootstrap_to_player_safe_real"):
		var guarded: Dictionary = dol_client.call("apply_bootstrap_to_player_safe_real", confirmed, "command") as Dictionary
		_print_safe("/dol applybootstrap real%s -> %s" % [" confirm" if confirmed else "", str(guarded)])
		return bool(guarded.get("handled", guarded.get("ok", false)))
	var apply_real := false
	if dol_client != null and dol_client.has_method("apply_bootstrap_to_player_offline"):
		var snap: Dictionary = dol_client.call("apply_bootstrap_to_player_offline", apply_real) as Dictionary
		_print_safe("/dol applybootstrap dry -> %s" % str(snap))
		return bool(snap.get("ok", false))
	var bootstrap := _get_character_bootstrap_1127()
	if bootstrap == null or not bootstrap.has_method("apply_bootstrap_to_player"):
		_print_safe("/dol applybootstrap missing")
		return false
	var snap2: Dictionary = bootstrap.call("apply_bootstrap_to_player", player, false, "command") as Dictionary
	_print_safe("/dol applybootstrap dry -> %s" % str(snap2))
	return bool(snap2.get("ok", false))


func _cmd_dol_rollbackbootstrap(raw: String) -> bool:
	if dol_client != null and dol_client.has_method("rollback_last_bootstrap_apply"):
		var snap: Dictionary = dol_client.call("rollback_last_bootstrap_apply", "command") as Dictionary
		_print_safe("/dol rollbackbootstrap -> %s" % str(snap))
		return bool(snap.get("handled", snap.get("ok", false)))
	var bootstrap := _get_character_bootstrap_1127()
	if bootstrap == null or not bootstrap.has_method("rollback_last_player_apply"):
		_print_safe("/dol rollbackbootstrap missing")
		return false
	var snap2: Dictionary = bootstrap.call("rollback_last_player_apply", player, "command") as Dictionary
	_print_safe("/dol rollbackbootstrap -> %s" % str(snap2))
	return bool(snap2.get("handled", snap2.get("ok", false)))


func _cmd_dol_charview(raw: String) -> bool:
	var bootstrap := _get_character_bootstrap_1127()
	if bootstrap == null or not bootstrap.has_method("build_character_overview_enriched_packet_1127"):
		_print_safe("/dol charview missing")
		return false
	var packet: PackedByteArray = bootstrap.call("build_character_overview_enriched_packet_1127", {}, 1) as PackedByteArray
	var chars: Array = bootstrap.call("character_list_from_overview_packet", packet, 1) as Array
	_print_safe("/dol charview chars=%d %s" % [chars.size(), str(bootstrap.call("build_local_ui_model_snapshot", chars))])
	return chars.size() > 0


func _cmd_dol_choose(raw: String) -> bool:
	var idx := _third_token_int_or_default(raw, 0)
	var selected := {}
	if dol_client != null and dol_client.has_method("choose_bootstrap_character"):
		selected = dol_client.call("choose_bootstrap_character", idx) as Dictionary
	else:
		var bootstrap := _get_character_bootstrap_1127()
		if bootstrap == null or not bootstrap.has_method("select_character_by_index"):
			_print_safe("/dol choose missing")
			return false
		var packet: PackedByteArray = bootstrap.call("build_character_overview_enriched_packet_1127", {}, 1) as PackedByteArray
		var chars: Array = bootstrap.call("character_list_from_overview_packet", packet, 1) as Array
		selected = bootstrap.call("select_character_by_index", chars, idx) as Dictionary
	var hud := _get_character_select_hud_1127()
	if hud != null and hud.has_method("set_selected_index"):
		hud.call("set_selected_index", idx)
	_print_safe("/dol choose %d -> %s" % [idx, str(selected)])
	return not selected.is_empty()


func _cmd_dol_bootstrap(raw: String) -> bool:
	var bootstrap := _get_character_bootstrap_1127()
	if bootstrap == null or not bootstrap.has_method("build_offline_bootstrap_flow"):
		_print_safe("/dol bootstrap missing")
		return false
	if dol_client != null and dol_client.has_method("mark_bootstrap_ready_from_selected"):
		dol_client.call("mark_bootstrap_ready_from_selected")
	var flow: Array = bootstrap.call("build_offline_bootstrap_flow") as Array
	_print_safe(str(bootstrap.call("bootstrap_flow_summary", flow)))
	return flow.size() >= 5


func _third_token_or_default(raw: String, fallback: String) -> String:
	var parts := raw.split(" ", false)
	if parts.size() >= 3:
		return str(parts[2]).strip_edges()
	if parts.size() >= 2 and str(parts[0]).to_lower() == "/login":
		return str(parts[1]).strip_edges()
	return fallback


func _third_token_int_or_default(raw: String, fallback: int) -> int:
	var token := _third_token_or_default(raw, str(fallback))
	if token.is_valid_int():
		return int(token)
	return fallback


func _fourth_token_int_or_default(raw: String, fallback: int) -> int:
	var parts := raw.split(" ", false)
	if parts.size() >= 4:
		var token := str(parts[3]).strip_edges()
		if token.is_valid_int():
			return int(token)
	return fallback


func _set_node_bool(node_name: String, property_name: String, value: bool) -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false
	var found := root.find_child(node_name, true, false)
	if found == null:
		return false
	found.set(property_name, value)
	_print_safe("%s.%s=%s" % [node_name, property_name, str(value)])
	return true


func _set_zone_viewer_bool(property_name: String, value: bool) -> bool:
	if zone_viewer == null:
		return false
	zone_viewer.set(property_name, value)
	_print_safe("ZoneViewer.%s=%s" % [property_name, str(value)])
	return true
