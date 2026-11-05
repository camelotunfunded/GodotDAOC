extends RefCounted
class_name DaocServerCoordinateMarkerPlan

const DaocServerClientZoneMapScript = preload("res://src/daoc/world/DaocServerClientZoneMap.gd")

## P1-17E2J — marker-only des coordonnées serveur candidates.
## Cette couche transforme les probes E2F en marqueurs debug visuels pour les
## scènes donjon. Elle ne confirme pas la frame de coordonnées et ne déplace
## jamais le joueur.

const SCOPE: String = "P1-17E2J server coordinate marker-only plan"
const CHECKPOINT: String = "P1_17E2J_SERVER_COORDINATE_MARKER_ONLY"
const DEFAULT_MARKER_JSON_PATH: String = "res://reports/daoc_server_coordinate_markers_p1_17e2j.json"
const DEFAULT_MARKER_TEXT_PATH: String = "res://reports/daoc_server_coordinate_markers_p1_17e2j.txt"
const MARKER_ROOT_NAME: String = "ServerCoordinateMarkers_E2J"

const DEFAULT_DUNGEON_WORLD_SCALE: float = 0.10
const DEFAULT_RUNTIME_SCALE_COMPENSATION: float = 10.0
const DEFAULT_MARKER_LIFT_RAW: float = 160.0
const DEFAULT_MARKER_RADIUS_RAW: float = 180.0


const REGION_LABELS: Dictionary = {
	20: "Stonehenge Barrows",
	21: "Tomb of Mithra",
}

var last_plan: Dictionary = {}
var last_apply_result: Dictionary = {}


func build_marker_plan(probe_report: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var world_scale: float = float(options.get("dungeon_world_scale", DEFAULT_DUNGEON_WORLD_SCALE))
	var runtime_scale_compensation: float = float(options.get("runtime_scale_compensation", DEFAULT_RUNTIME_SCALE_COMPENSATION))
	var marker_lift_raw: float = float(options.get("marker_lift_raw", DEFAULT_MARKER_LIFT_RAW))
	var marker_radius_raw: float = float(options.get("marker_radius_raw", DEFAULT_MARKER_RADIUS_RAW))
	var probes: Array = _collect_probes(probe_report)
	var markers: Array = []
	for probe_value in probes:
		if typeof(probe_value) != TYPE_DICTIONARY:
			continue
		var probe: Dictionary = probe_value as Dictionary
		var marker: Dictionary = _marker_from_probe(probe, world_scale, runtime_scale_compensation, marker_lift_raw, marker_radius_raw)
		if not marker.is_empty():
			markers.append(marker)
	var plan: Dictionary = {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"marker_only": true,
		"gameplay_runtime_enabled": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"source_checkpoint": str(probe_report.get("checkpoint", "")),
		"source_status": str(probe_report.get("source_status", probe_report.get("status", ""))),
		"probe_count": probes.size(),
		"marker_count": markers.size(),
		"markers": markers,
		"dungeon_world_scale": world_scale,
		"runtime_scale_compensation": runtime_scale_compensation,
		"marker_lift_raw": marker_lift_raw,
		"marker_radius_raw": marker_radius_raw,
		"placement_assumption": "dungeon_scene_local_daoc_xyz_to_godot_x_z_minus_y",
		"scene_node_path_hint": MARKER_ROOT_NAME,
		"decision": "debug_markers_only_do_not_spawn_until_coordinate_frame_confirmed",
	}
	last_plan = plan.duplicate(true)
	return plan


func daoc_xyz_to_godot_scene_local(daoc_x: float, daoc_y: float, daoc_z: float, world_scale: float = DEFAULT_DUNGEON_WORLD_SCALE) -> Vector3:
	# Même convention que DaocDungeonSceneBuilder : Godot = (x, z, -y) * scale.
	return Vector3(daoc_x * world_scale, daoc_z * world_scale, -daoc_y * world_scale)


func create_marker_nodes(parent: Node, plan: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	if parent == null or not (parent is Node3D):
		last_apply_result = _apply_result(false, {"error": "parent Node3D missing"})
		return last_apply_result
	var source_plan: Dictionary = plan
	if source_plan.is_empty():
		source_plan = last_plan
	var markers: Array = source_plan.get("markers", []) as Array
	var zone_filter: int = int(options.get("client_zone_id", -1))
	var coordinate_space: String = str(options.get("coordinate_space", "scene_local"))
	var clear_existing: bool = bool(options.get("clear_existing", true))
	var root: Node3D = _ensure_marker_root(parent as Node3D, clear_existing)
	var created: int = 0
	var attached_ids: Array = []
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value as Dictionary
		if zone_filter >= 0 and int(marker.get("client_zone_id", -1)) != zone_filter:
			continue
		var node: Node3D = _make_marker_node(marker, coordinate_space)
		if node == null:
			continue
		root.add_child(node)
		created += 1
		attached_ids.append(str(marker.get("id", "")))
	last_apply_result = _apply_result(true, {
		"parent_name": str(parent.name),
		"marker_root_name": MARKER_ROOT_NAME,
		"coordinate_space": coordinate_space,
		"zone_filter": zone_filter,
		"markers_available": markers.size(),
		"markers_created": created,
		"attached_marker_ids": attached_ids,
	})
	return last_apply_result


func apply_markers_to_generated_dungeon_scene(scene_path: String, plan: Dictionary = {}, client_zone_id: int = -1, options: Dictionary = {}) -> Dictionary:
	var target_path: String = scene_path.strip_edges()
	if target_path == "":
		last_apply_result = _apply_result(false, {"scene_path": target_path, "error": "empty scene path"})
		return last_apply_result
	if not FileAccess.file_exists(target_path):
		last_apply_result = _apply_result(false, {"scene_path": target_path, "error": "generated dungeon scene missing"})
		return last_apply_result
	var resource: Resource = ResourceLoader.load(target_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = resource as PackedScene
	if packed == null:
		last_apply_result = _apply_result(false, {"scene_path": target_path, "error": "resource is not PackedScene"})
		return last_apply_result
	var root_node: Node = packed.instantiate()
	if root_node == null or not (root_node is Node3D):
		if root_node != null:
			root_node.free()
		last_apply_result = _apply_result(false, {"scene_path": target_path, "error": "PackedScene root is not Node3D"})
		return last_apply_result
	var apply_options: Dictionary = options.duplicate(true)
	apply_options["client_zone_id"] = client_zone_id
	apply_options["coordinate_space"] = str(options.get("coordinate_space", "scene_local"))
	var apply_result: Dictionary = create_marker_nodes(root_node, plan, apply_options)
	if not bool(apply_result.get("ok", false)):
		root_node.free()
		last_apply_result = apply_result
		return last_apply_result
	_set_scene_owner_recursive(root_node, root_node)
	var new_packed := PackedScene.new()
	var pack_err: int = int(new_packed.pack(root_node))
	if pack_err != OK:
		root_node.free()
		last_apply_result = _apply_result(false, {"scene_path": target_path, "pack_error_code": pack_err, "error": "PackedScene.pack failed"})
		return last_apply_result
	var save_err: int = int(ResourceSaver.save(new_packed, target_path))
	root_node.free()
	last_apply_result = _apply_result(save_err == OK, {
		"scene_path": target_path,
		"client_zone_id": client_zone_id,
		"markers_created": int(apply_result.get("markers_created", 0)),
		"pack_error_code": pack_err,
		"save_error_code": save_err,
		"error": "" if save_err == OK else "ResourceSaver.save failed",
	})
	return last_apply_result


func export_last_plan_json(path: String = DEFAULT_MARKER_JSON_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_MARKER_JSON_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "error": "cannot open marker json for write"}
	file.store_string(JSON.stringify(last_plan, "  "))
	file.close()
	return {"ok": true, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "marker_only": true, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func export_last_plan_text(path: String = DEFAULT_MARKER_TEXT_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_MARKER_TEXT_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "error": "cannot open marker text for write"}
	file.store_string(_plan_as_text(last_plan))
	file.close()
	return {"ok": true, "scope": SCOPE, "checkpoint": CHECKPOINT, "path": target_path, "marker_only": true, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func build_compact_report(plan: Dictionary = {}) -> Dictionary:
	var source_plan: Dictionary = plan
	if source_plan.is_empty():
		source_plan = last_plan
	var markers: Array = source_plan.get("markers", []) as Array
	var compact_markers: Array = []
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value as Dictionary
		compact_markers.append({
			"id": str(marker.get("id", "")),
			"label": str(marker.get("label", "")),
			"target_region_id": int(marker.get("target_region_id", 0)),
			"client_zone_id": int(marker.get("client_zone_id", -1)),
			"source_record_id": str(marker.get("source_record_id", "")),
			"source_table_id": str(marker.get("source_table_id", "")),
			"daoc_position_raw": marker.get("daoc_position_raw", {}),
			"scene_local_marker_position": marker.get("scene_local_marker_position", {}),
			"runtime_child_local_marker_position": marker.get("runtime_child_local_marker_position", {}),
			"heading_raw": int(marker.get("heading_raw", 0)),
			"status": str(marker.get("status", "")),
			"recommended_scene_path": str(marker.get("recommended_scene_path", "")),
			"coordinate_frame_confirmed": false,
			"player_spawn_applied": false,
		})
	return {
		"ok": bool(source_plan.get("ok", false)),
		"scope": SCOPE,
		"checkpoint": "P1_17E2K_SERVER_MARKERS_COMPACT_REPORT",
		"source_checkpoint": str(source_plan.get("checkpoint", CHECKPOINT)),
		"marker_count": compact_markers.size(),
		"marker_only": true,
		"runtime_enabled": false,
		"gameplay_runtime_enabled": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"source_status": str(source_plan.get("source_status", "")),
		"dungeon_world_scale": float(source_plan.get("dungeon_world_scale", DEFAULT_DUNGEON_WORLD_SCALE)),
		"runtime_scale_compensation": float(source_plan.get("runtime_scale_compensation", DEFAULT_RUNTIME_SCALE_COMPENSATION)),
		"placement_assumption": "Godot=(DAoC.x, DAoC.z, -DAoC.y)*dungeon_world_scale",
		"confirmed": [
			"OpenDAoC candidate coordinates were parsed into the marker plan",
			"Markers are report-only/debug-only",
			"No player spawn is applied",
		],
		"not_confirmed": [
			"Server coordinate frame against Godot scene",
			"Official client /loc equivalence",
			"Server MoveTo/log equivalence",
		],
		"markers": compact_markers,
	}


func build_validation_evidence_template(plan: Dictionary = {}) -> Dictionary:
	var source_plan: Dictionary = plan
	if source_plan.is_empty():
		source_plan = last_plan
	var markers: Array = source_plan.get("markers", []) as Array
	var tasks: Array = []
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value as Dictionary
		tasks.append({
			"marker_id": str(marker.get("id", "")),
			"target_region_id": int(marker.get("target_region_id", 0)),
			"client_zone_id": int(marker.get("client_zone_id", -1)),
			"source_record_id": str(marker.get("source_record_id", "")),
			"raw_daoc_xyz": marker.get("daoc_position_raw", {}),
			"heading_raw": int(marker.get("heading_raw", 0)),
			"official_client_loc_before": null,
			"official_client_loc_after": null,
			"server_log_MoveTo": null,
			"server_log_ZonePoint": null,
			"visual_marker_check": {
				"screenshot_path": "",
				"marker_visible": null,
				"matches_expected_entrance": null,
				"notes": "",
			},
			"human_verdict": "unconfirmed",
		})
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": "P1_17E2K_VALIDATION_EVIDENCE_TEMPLATE",
		"source_checkpoint": str(source_plan.get("checkpoint", CHECKPOINT)),
		"marker_only": true,
		"runtime_enabled": false,
		"gameplay_runtime_enabled": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"auto_confirm_allowed": false,
		"evidence_required": [
			"official_client_loc_before",
			"official_client_loc_after",
			"server_log_MoveTo or server_log_ZonePoint",
			"visual_marker_check",
		],
		"do_not_conclude": [
			"Visible marker alone confirms the coordinate frame",
			"RegionID always equals client zone folder",
			"Marker candidate can be used as player spawn",
		],
		"tasks": tasks,
	}


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"last_plan": last_plan.duplicate(true),
		"last_apply_result": last_apply_result.duplicate(true),
		"marker_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
	}


func _marker_from_probe(probe: Dictionary, world_scale: float, runtime_scale_compensation: float, marker_lift_raw: float, marker_radius_raw: float) -> Dictionary:
	var region_id: int = int(probe.get("target_region_id", 0))
	var mapping: Dictionary = DaocServerClientZoneMapScript.new().call("resolve_region", region_id, {"allow_visible_zone_candidate_mapping": false}) as Dictionary
	if not bool(mapping.get("ok", false)):
		return {}
	var client_zone_id: int = int(mapping.get("client_zone_id", -1))
	var x: float = float(probe.get("x", 0.0))
	var y: float = float(probe.get("y", 0.0))
	var z: float = float(probe.get("z", 0.0))
	var heading_raw: int = int(probe.get("heading_raw", 0))
	var scene_position: Vector3 = daoc_xyz_to_godot_scene_local(x, y, z, world_scale)
	var scene_marker_position: Vector3 = daoc_xyz_to_godot_scene_local(x, y, z + marker_lift_raw, world_scale)
	var safe_runtime_scale: float = maxf(runtime_scale_compensation, 0.0001)
	var runtime_child_position: Vector3 = scene_marker_position / safe_runtime_scale
	var label: String = str(mapping.get("region_name", REGION_LABELS.get(region_id, "Region%03d" % region_id)))
	return {
		"id": "server_marker_region%03d_zone%03d" % [region_id, client_zone_id],
		"label": "%s server ZonePoint candidate" % label,
		"marker_only": true,
		"abstract_only": true,
		"runtime_enabled": false,
		"gameplay_runtime_enabled": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"status": "marker_candidate_unconfirmed_frame",
		"target_region_id": region_id,
		"target_region_label": label,
		"client_zone_id": client_zone_id,
		"client_zone_name": "zone%03d" % client_zone_id,
		"recommended_scene_path": _default_dungeon_scene_path(client_zone_id),
		"source_record_id": str(probe.get("source_record_id", "")),
		"source_table_id": str(probe.get("source_table_id", "")),
		"authenticity": str(probe.get("authenticity", "server_db_imported_unconfirmed_frame")),
		"daoc_position_raw": {"x": x, "y": y, "z": z},
		"daoc_marker_position_raw": {"x": x, "y": y, "z": z + marker_lift_raw},
		"scene_local_position": _vector3_to_dict(scene_position),
		"scene_local_marker_position": _vector3_to_dict(scene_marker_position),
		"runtime_child_local_marker_position": _vector3_to_dict(runtime_child_position),
		"heading_raw": heading_raw,
		"heading_deg_estimate": float(probe.get("heading_deg_estimate", _heading_raw_to_deg(heading_raw))),
		"dungeon_world_scale": world_scale,
		"runtime_scale_compensation": runtime_scale_compensation,
		"marker_radius_raw": marker_radius_raw,
		"marker_radius_scene": marker_radius_raw * world_scale,
		"placement_assumption": "Godot=(DAoC.x, DAoC.z, -DAoC.y)*dungeon_world_scale",
		"next_action": "visually_compare_marker_against_generated_dungeon_and_official_client_loc_before_spawn",
	}


func _collect_probes(probe_report: Dictionary) -> Array:
	var probes: Array = probe_report.get("probes", []) as Array
	if not probes.is_empty():
		return probes
	var tasks: Array = probe_report.get("manual_validation_tasks", []) as Array
	var out: Array = []
	for task_value in tasks:
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = task_value as Dictionary
		var xyz: Dictionary = task.get("server_xyz_heading", {}) as Dictionary
		out.append({
			"target_region_id": int(task.get("target_region_id", 0)),
			"x": float(xyz.get("x", 0.0)),
			"y": float(xyz.get("y", 0.0)),
			"z": float(xyz.get("z", 0.0)),
			"heading_raw": int(xyz.get("heading_raw", 0)),
			"authenticity": "server_db_imported_unconfirmed_frame",
		})
	return out


func _ensure_marker_root(parent: Node3D, clear_existing: bool) -> Node3D:
	var existing: Node = parent.get_node_or_null(NodePath(MARKER_ROOT_NAME))
	var root: Node3D = null
	if existing != null and existing is Node3D:
		root = existing as Node3D
	else:
		root = Node3D.new()
		root.name = MARKER_ROOT_NAME
		parent.add_child(root)
	root.set_meta("scope", SCOPE)
	root.set_meta("checkpoint", CHECKPOINT)
	root.set_meta("marker_only", true)
	root.set_meta("coordinate_frame_confirmed", false)
	root.set_meta("player_spawn_applied", false)
	if clear_existing:
		for child_value in root.get_children():
			var child: Node = child_value as Node
			if child != null:
				child.queue_free()
	return root


func _make_marker_node(marker: Dictionary, coordinate_space: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = str(marker.get("id", "ServerCoordinateMarker"))
	root.set_meta("scope", SCOPE)
	root.set_meta("checkpoint", CHECKPOINT)
	root.set_meta("marker", marker.duplicate(true))
	root.set_meta("marker_only", true)
	root.set_meta("coordinate_frame_confirmed", false)
	root.set_meta("player_spawn_applied", false)
	var pos_dict: Dictionary = marker.get("scene_local_marker_position", {}) as Dictionary
	if coordinate_space == "runtime_child_local":
		pos_dict = marker.get("runtime_child_local_marker_position", {}) as Dictionary
	root.position = _dict_to_vector3(pos_dict)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Sphere"
	var sphere: SphereMesh = SphereMesh.new()
	var radius: float = maxf(float(marker.get("marker_radius_scene", 8.0)), 4.0)
	if coordinate_space == "runtime_child_local":
		radius = radius / maxf(float(marker.get("runtime_scale_compensation", DEFAULT_RUNTIME_SCALE_COMPENSATION)), 0.0001)
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_node.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(0.2, 1.0, 0.95, 0.9) if int(marker.get("target_region_id", 0)) == 20 else Color(1.0, 0.55, 0.2, 0.9)
	mesh_node.material_override = mat
	root.add_child(mesh_node)
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = "%s\nR%d %s\nframe unconfirmed" % [str(marker.get("label", "Server marker")), int(marker.get("target_region_id", 0)), str(marker.get("client_zone_name", ""))]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, radius * 1.6, 0.0)
	root.add_child(label)
	return root


func _set_scene_owner_recursive(node: Node, owner: Node) -> void:
	if node == null or owner == null:
		return
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null:
			continue
		child.owner = owner
		_set_scene_owner_recursive(child, owner)


func _default_dungeon_scene_path(znum: int) -> String:
	return "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn" % [znum, znum]


func _apply_result(ok: bool, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"marker_only": true,
		"gameplay_runtime_enabled": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func _dict_to_vector3(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))


func _heading_raw_to_deg(raw: int) -> float:
	return fposmod(float(raw), 4096.0) * 360.0 / 4096.0


func _plan_as_text(plan: Dictionary) -> String:
	var lines: Array = []
	lines.append(str(plan.get("scope", SCOPE)))
	lines.append("checkpoint=%s" % str(plan.get("checkpoint", CHECKPOINT)))
	lines.append("marker_count=%d probe_count=%d" % [int(plan.get("marker_count", 0)), int(plan.get("probe_count", 0))])
	lines.append("marker_only=%s runtime_enabled=%s coordinate_frame_confirmed=%s player_spawn_applied=%s" % [str(plan.get("marker_only", true)), str(plan.get("runtime_enabled", false)), str(plan.get("coordinate_frame_confirmed", false)), str(plan.get("player_spawn_applied", false))])
	lines.append("placement_assumption=%s" % str(plan.get("placement_assumption", "")))
	for marker_value in (plan.get("markers", []) as Array):
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value as Dictionary
		var p: Dictionary = marker.get("scene_local_marker_position", {}) as Dictionary
		lines.append("region=%d zone=%s id=%s raw=(%.1f, %.1f, %.1f) marker_scene=(%.2f, %.2f, %.2f) heading=%d status=%s" % [
			int(marker.get("target_region_id", 0)),
			str(marker.get("client_zone_name", "")),
			str(marker.get("source_record_id", "")),
			float((marker.get("daoc_position_raw", {}) as Dictionary).get("x", 0.0)),
			float((marker.get("daoc_position_raw", {}) as Dictionary).get("y", 0.0)),
			float((marker.get("daoc_position_raw", {}) as Dictionary).get("z", 0.0)),
			float(p.get("x", 0.0)),
			float(p.get("y", 0.0)),
			float(p.get("z", 0.0)),
			int(marker.get("heading_raw", 0)),
			str(marker.get("status", "")),
		])
	lines.append("decision=%s" % str(plan.get("decision", "")))
	return "\n".join(lines)
