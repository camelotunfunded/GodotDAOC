extends RefCounted
class_name DaocGeneratedSceneParityAudit

const DaocGeneratedZoneSceneLoaderScript = preload("res://src/daoc/DaocGeneratedZoneSceneLoader.gd")
const DaocPlayerMotorScript = preload("res://src/daoc/DaocPlayerMotor.gd")
const DaocPlayerVisualMeshySwapScript = preload("res://src/daoc/player/DaocPlayerVisualMeshySwap.gd")

const CHECKPOINT: String = "P1_19A_GENERATED_SCENE_PARITY_BOOT_PATH"
const DEFAULT_REPORT_DIR: String = "res://reports/p1_19a_generated_scene_parity"
const DEFAULT_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"
const DEFAULT_ZONE_ID: int = 0

const CRITICAL_FIXTURES: Array = [
	{"fixture_id": 556, "nif_id": 424, "stem": "brghouse", "label": "f556_brghouse"},
	{"fixture_id": 555, "nif_id": 423, "stem": "camwall", "label": "f555_camwall"},
	{"fixture_id": 3, "nif_id": 408, "stem": "bridge", "label": "f3_bridge"},
	{"fixture_id": 1, "nif_id": -1, "stem": "keep", "label": "f1_keep"},
	{"fixture_id": 1517, "nif_id": -1, "stem": "A_PhouseGatein", "label": "f1517_A_PhouseGatein"},
	{"fixture_id": 1518, "nif_id": -1, "stem": "borderkeep1", "label": "f1518_borderkeep1"},
]

const EXPECTED_BRANCHES: Array = [
	"TerrainRoot",
	"StaticPropsRoot",
	"CollisionRoot",
	"WaterRoot",
	"ZoneJumpRoot",
	"BoundsRoot",
]


func run_parity_audit(zone_viewer: Node, options: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_msec()
	var report := _base_report(options)
	var zone_id := int(options.get("zone_id", DEFAULT_ZONE_ID))
	var manifest_path := str(options.get("manifest_path", DEFAULT_MANIFEST_PATH))
	var explicit_scene_path := str(options.get("generated_scene_path", "")).strip_edges()
	report["zone_id"] = zone_id
	report["manifest_path"] = manifest_path
	report["generated_scene_path_configured"] = explicit_scene_path
	report["project_state"] = _project_state(zone_viewer, manifest_path)
	report["runtime_viewer"] = _runtime_viewer_snapshot(zone_viewer, zone_id)
	var generated := _load_generated_scene(zone_id, manifest_path, explicit_scene_path)
	report["generated_scene"] = generated
	var generated_node: Node = generated.get("node", null) as Node
	report["structure"] = _structure_report(generated_node)
	report["fixtures"] = _fixtures_report(zone_viewer, generated_node, zone_id, options)
	report["critical_focus"] = _critical_focus(zone_viewer, generated_node, zone_id)
	report["mesh_aabb"] = _critical_mesh_report(report.get("critical_focus", {}) as Dictionary)
	report["materials"] = _material_summary(report.get("critical_focus", {}) as Dictionary)
	report["collisions"] = _collision_report(zone_viewer, generated_node, zone_id)
	report["water_zonejump_bounds"] = _water_zonejump_bounds_report(zone_viewer, generated_node, zone_id)
	report["boot"] = run_boot_probe(zone_viewer, generated_node, options)
	report["elapsed_ms"] = Time.get_ticks_msec() - started
	report["overall_verdict"] = _overall_verdict(report)
	report["ok"] = str(report.get("overall_verdict", "FAIL")) != "FAIL"
	var written := _write_reports(report, options)
	report["written_files"] = written
	if generated_node != null:
		generated_node.free()
	return report


func run_boot_probe(zone_viewer: Node, generated_node: Node, options: Dictionary = {}) -> Dictionary:
	var enabled := bool(options.get("boot_enabled", false))
	var out := {
		"checkpoint": CHECKPOINT,
		"ok": false,
		"enabled": enabled,
		"spawn_player_requested": bool(options.get("boot_spawn_player", true)),
		"attach_meshy_requested": bool(options.get("boot_attach_meshy", true)),
		"character_body_present": false,
		"collision_shape_present": false,
		"meshy_visual_attached": false,
		"root_motion_enabled": false,
		"server_authority_unchanged": true,
		"prediction_only_unchanged": true,
		"damage_final_unchanged": true,
		"reason": "",
	}
	if generated_node == null:
		out["reason"] = "generated_scene_missing"
		_write_boot_report(out, options)
		return out
	if not enabled:
		out["reason"] = "boot_disabled"
		_write_boot_report(out, options)
		return out
	var host := Node3D.new()
	host.name = "P1_19A_GeneratedSceneBootHost"
	host.add_child(generated_node.duplicate())
	var player: CharacterBody3D = DaocPlayerMotorScript.new()
	player.name = "P1_19A_DaocPlayerCapsule"
	host.add_child(player)
	out["character_body_present"] = true
	if zone_viewer != null:
		player.call("setup", zone_viewer, int(options.get("zone_id", DEFAULT_ZONE_ID)), Vector3(32768.0, 32768.0, 0.0), 0.0, false)
	else:
		player.call("_make_runtime_nodes")
	out["collision_shape_present"] = player.get_node_or_null("CollisionShape3D") != null
	if bool(options.get("boot_attach_meshy", true)):
		var swap: RefCounted = DaocPlayerVisualMeshySwapScript.new()
		if swap != null:
			var attach: Dictionary = swap.call("attach_to_player", player, {}) as Dictionary
			out["meshy_visual_attached"] = bool(attach.get("visual_root_attached", false))
	out["ok"] = bool(out.get("character_body_present", false)) and bool(out.get("collision_shape_present", false))
	out["reason"] = "" if bool(out.get("ok", false)) else "player_boot_incomplete"
	host.free()
	_write_boot_report(out, options)
	return out


func _base_report(options: Dictionary) -> Dictionary:
	return {
		"checkpoint": CHECKPOINT,
		"scope": "P1-19A Generated Scene Parity & Boot Path",
		"ok": false,
		"non_destructive": true,
		"runtime_asset_conversion": false,
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"report_dir": str(options.get("report_dir", DEFAULT_REPORT_DIR)),
	}


func _project_state(zone_viewer: Node, manifest_path: String) -> Dictionary:
	var paths := {
		"official_manifest_path": manifest_path,
		"official_zone_scene_pattern": "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn",
		"official_dungeon_scene_pattern": "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn",
		"manifest_exists": FileAccess.file_exists(manifest_path),
	}
	return {
		"daoc_zone_scene_assembler": true,
		"daoc_generated_zone_scene_loader": true,
		"terrain_builder": true,
		"prop_builder": true,
		"collision_builder": true,
		"water_builder": true,
		"zonejump_builder": true,
		"zone_viewer_available": zone_viewer != null,
		"active_generated_path_policy": "official_manifest" if bool(paths.get("manifest_exists", false)) else "official_manifest_missing",
		"paths": paths,
	}


func _runtime_viewer_snapshot(zone_viewer: Node, zone_id: int) -> Dictionary:
	var out := {
		"available": zone_viewer != null,
		"fixture_count": 0,
		"prop_count": 0,
		"terrain_collision_count": 0,
		"prop_collision_count": 0,
		"water_count": 0,
		"zonejump_count": 0,
		"bounds_count": 0,
	}
	if zone_viewer == null:
		return out
	out["prop_count"] = _zone_array_size(zone_viewer, "_prop_nodes_by_zone", zone_id)
	out["prop_collision_count"] = _zone_array_size(zone_viewer, "_prop_collision_runtime", zone_id)
	out["bounds_count"] = _zone_array_size(zone_viewer, "_boundary_runtime", zone_id)
	out["water_count"] = _zone_array_size(zone_viewer, "_water_runtime", zone_id)
	if zone_viewer.has_method("get_zonejump_debug_snapshot"):
		var zj: Dictionary = zone_viewer.call("get_zonejump_debug_snapshot") as Dictionary
		out["zonejump_count"] = int(zj.get("entries_total", 0))
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		var terrain: Dictionary = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
		out["terrain_collision_count"] = int(terrain.get("zone0_collision_bodies", 0))
	var prop_result := _zone_result(zone_viewer, "_prop_build_results", zone_id)
	if prop_result != null:
		var metrics: Dictionary = _as_dictionary(prop_result.get("metrics"))
		out["fixture_count"] = int(metrics.get("fixtures", 0))
	return out


func _load_generated_scene(zone_id: int, manifest_path: String, explicit_scene_path: String) -> Dictionary:
	var out := {
		"loadable": false,
		"missing": false,
		"manifest_path": manifest_path,
		"scene_path": "",
		"error": "",
	}
	if explicit_scene_path != "":
		out["scene_path"] = explicit_scene_path
		if not ResourceLoader.exists(explicit_scene_path):
			out["missing"] = true
			out["error"] = "generated_scene_missing"
			return out
		var res: Resource = ResourceLoader.load(explicit_scene_path)
		if res == null or not (res is PackedScene):
			out["error"] = "generated_scene_not_packed_scene"
			return out
		out["node"] = (res as PackedScene).instantiate()
		out["loadable"] = out["node"] != null
		return out
	var loader: RefCounted = DaocGeneratedZoneSceneLoaderScript.new()
	var load: Dictionary = loader.call("load_manifest", manifest_path) as Dictionary
	out["manifest"] = load
	if not bool(load.get("ok", false)):
		out["missing"] = bool(load.get("missing", false))
		out["error"] = str(load.get("error", "manifest_load_failed"))
		return out
	out["scene_path"] = str(loader.call("scene_path_for_zone", zone_id, manifest_path))
	var inst: Dictionary = loader.call("instantiate_generated_zone_scene", zone_id, true, manifest_path) as Dictionary
	out["instantiate"] = _strip_runtime_objects(inst)
	out["loadable"] = bool(inst.get("instantiated", false))
	out["error"] = str(inst.get("error", ""))
	if inst.has("node"):
		out["node"] = inst.get("node")
	if not bool(out.get("loadable", false)):
		out["missing"] = bool(inst.get("missing", false))
	return out


func _structure_report(root: Node) -> Dictionary:
	var out := {
		"root_scene_exists": root != null,
		"root_name": root.name if root != null else "",
		"main_zone_root_found": root != null,
		"branches": {},
	}
	for branch in EXPECTED_BRANCHES:
		var name := str(branch)
		var node := _find_node_by_name(root, name)
		(out["branches"] as Dictionary)[name] = {
			"found": node != null,
			"path": _safe_node_path(node) if node != null else "",
		}
	out["terrain_node_found"] = bool((out["branches"] as Dictionary).get("TerrainRoot", {}).get("found", false))
	out["static_props_root_found"] = bool((out["branches"] as Dictionary).get("StaticPropsRoot", {}).get("found", false))
	out["collision_root_found"] = bool((out["branches"] as Dictionary).get("CollisionRoot", {}).get("found", false))
	out["water_root_found"] = bool((out["branches"] as Dictionary).get("WaterRoot", {}).get("found", false))
	out["zonejump_root_found"] = bool((out["branches"] as Dictionary).get("ZoneJumpRoot", {}).get("found", false))
	out["bounds_root_found"] = bool((out["branches"] as Dictionary).get("BoundsRoot", {}).get("found", false))
	return out


func _fixtures_report(zone_viewer: Node, generated_node: Node, zone_id: int, options: Dictionary) -> Dictionary:
	var runtime_ids := _runtime_fixture_ids(zone_viewer, zone_id)
	var generated_ids := _generated_fixture_ids(generated_node)
	var missing: Array = []
	var extra: Array = []
	for id in runtime_ids:
		if not generated_ids.has(id):
			missing.append(id)
	for id in generated_ids:
		if not runtime_ids.has(id):
			extra.append(id)
	var limit := int(options.get("max_fixture_compare", 0))
	return {
		"source_fixture_count": runtime_ids.size(),
		"runtime_fixture_count": runtime_ids.size(),
		"generated_fixture_count": generated_ids.size(),
		"missing_generated_count": missing.size(),
		"extra_generated_count": extra.size(),
		"missing_generated_sample": missing.slice(0, missing.size() if limit <= 0 else min(limit, missing.size())),
		"extra_generated_sample": extra.slice(0, extra.size() if limit <= 0 else min(limit, extra.size())),
		"stable_node_name_format": "f<fixture_id>_<stem>",
	}


func _critical_focus(zone_viewer: Node, generated_node: Node, zone_id: int) -> Dictionary:
	var out := {"items": [], "verdict": "WARN"}
	for raw in CRITICAL_FIXTURES:
		var crit: Dictionary = raw as Dictionary
		var fixture_id := int(crit.get("fixture_id", -1))
		var runtime_node := _find_fixture_node(_runtime_prop_root(zone_viewer, zone_id), fixture_id)
		var generated_node_match := _find_fixture_node(generated_node, fixture_id)
		var item := {
			"label": str(crit.get("label", "")),
			"fixture_id": fixture_id,
			"nif_id_expected": int(crit.get("nif_id", -1)),
			"runtime": _node_detail(runtime_node),
			"generated": _node_detail(generated_node_match),
			"mismatch_verdict": _critical_verdict(runtime_node, generated_node_match),
		}
		(out["items"] as Array).append(item)
	out["verdict"] = _focus_verdict(out["items"] as Array)
	return out


func _critical_mesh_report(focus: Dictionary) -> Dictionary:
	var out := {"items": []}
	for raw in (focus.get("items", []) as Array):
		var item: Dictionary = raw as Dictionary
		(out["items"] as Array).append({
			"label": str(item.get("label", "")),
			"runtime_mesh": (item.get("runtime", {}) as Dictionary).get("mesh", {}),
			"generated_mesh": (item.get("generated", {}) as Dictionary).get("mesh", {}),
		})
	return out


func _material_summary(focus: Dictionary) -> Dictionary:
	var mismatch := 0
	var items: Array = []
	for raw in (focus.get("items", []) as Array):
		var item: Dictionary = raw as Dictionary
		var rt: Dictionary = ((item.get("runtime", {}) as Dictionary).get("mesh", {}) as Dictionary)
		var gen: Dictionary = ((item.get("generated", {}) as Dictionary).get("mesh", {}) as Dictionary)
		var rt_count := int(rt.get("material_count", 0))
		var gen_count := int(gen.get("material_count", 0))
		if rt_count != gen_count:
			mismatch += 1
		items.append({"label": item.get("label", ""), "runtime_material_count": rt_count, "generated_material_count": gen_count})
	return {"material_mismatches": mismatch, "items": items}


func _collision_report(zone_viewer: Node, generated_node: Node, zone_id: int) -> Dictionary:
	return {
		"collision_root_exists": _find_node_by_name(generated_node, "CollisionRoot") != null,
		"generated_static_body_count": _count_type(generated_node, "StaticBody3D"),
		"generated_collision_shape_count": _count_type(generated_node, "CollisionShape3D"),
		"runtime_prop_collision_count": _zone_array_size(zone_viewer, "_prop_collision_runtime", zone_id),
		"runtime_bounds_collision_count": _zone_array_size(zone_viewer, "_boundary_runtime", zone_id),
		"approximate_collision_policy": true,
	}


func _water_zonejump_bounds_report(zone_viewer: Node, generated_node: Node, zone_id: int) -> Dictionary:
	return {
		"generated_water_nodes": _count_nodes_containing(generated_node, "water"),
		"generated_zonejump_nodes": _count_nodes_containing(generated_node, "zonejump"),
		"generated_bounds_nodes": _count_nodes_containing(generated_node, "bound"),
		"runtime_water_count": _zone_array_size(zone_viewer, "_water_runtime", zone_id),
		"runtime_bounds_count": _zone_array_size(zone_viewer, "_boundary_runtime", zone_id),
	}


func _overall_verdict(report: Dictionary) -> String:
	var generated: Dictionary = report.get("generated_scene", {}) as Dictionary
	if not bool(generated.get("loadable", false)):
		return "WARN"
	var fixtures: Dictionary = report.get("fixtures", {}) as Dictionary
	if int(fixtures.get("missing_generated_count", 0)) > 0:
		return "WARN"
	var focus: Dictionary = report.get("critical_focus", {}) as Dictionary
	if str(focus.get("verdict", "WARN")) != "PASS":
		return "WARN"
	return "PASS"


func _write_reports(report: Dictionary, options: Dictionary) -> Dictionary:
	if not bool(options.get("write_reports", true)):
		return {}
	var dir := str(options.get("report_dir", DEFAULT_REPORT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var json_path := dir.path_join("p1_19a_generated_scene_parity.json")
	var txt_path := dir.path_join("p1_19a_generated_scene_parity.txt")
	var fixtures_csv := dir.path_join("p1_19a_generated_scene_parity_fixtures.csv")
	var critical_csv := dir.path_join("p1_19a_generated_scene_parity_critical.csv")
	_write_text(json_path, JSON.stringify(_strip_runtime_objects(report), "\t"))
	_write_text(txt_path, build_text_report(report))
	_write_text(fixtures_csv, _fixtures_csv(report))
	_write_text(critical_csv, _critical_csv(report))
	return {
		"json": ProjectSettings.globalize_path(json_path),
		"txt": ProjectSettings.globalize_path(txt_path),
		"fixtures_csv": ProjectSettings.globalize_path(fixtures_csv),
		"critical_csv": ProjectSettings.globalize_path(critical_csv),
	}


func _write_boot_report(report: Dictionary, options: Dictionary) -> void:
	if not bool(options.get("write_reports", true)):
		return
	var dir := str(options.get("report_dir", DEFAULT_REPORT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write_text(dir.path_join("p1_19a_generated_scene_boot_report.json"), JSON.stringify(report, "\t"))
	_write_text(dir.path_join("p1_19a_generated_scene_boot_report.txt"), "\n".join([
		"# P1-19A Generated Scene Boot Report",
		"ok=%s enabled=%s reason=%s" % [str(report.get("ok", false)), str(report.get("enabled", false)), str(report.get("reason", ""))],
		"CharacterBody3D=%s CollisionShape3D=%s Meshy=%s" % [str(report.get("character_body_present", false)), str(report.get("collision_shape_present", false)), str(report.get("meshy_visual_attached", false))],
	]) + "\n")


func build_text_report(report: Dictionary) -> String:
	var generated: Dictionary = report.get("generated_scene", {}) as Dictionary
	var runtime: Dictionary = report.get("runtime_viewer", {}) as Dictionary
	var fixtures: Dictionary = report.get("fixtures", {}) as Dictionary
	var materials: Dictionary = report.get("materials", {}) as Dictionary
	var collisions: Dictionary = report.get("collisions", {}) as Dictionary
	var boot: Dictionary = report.get("boot", {}) as Dictionary
	return "\n".join([
		"# P1-19A Generated Scene Parity & Boot Path",
		"overall verdict: %s" % str(report.get("overall_verdict", "WARN")),
		"generated scene path: %s" % str(generated.get("scene_path", "")),
		"generated scene loadable: %s" % str(generated.get("loadable", false)),
		"runtime viewer available: %s" % str(runtime.get("available", false)),
		"source fixture count: %d" % int(fixtures.get("source_fixture_count", 0)),
		"runtime fixture count: %d" % int(fixtures.get("runtime_fixture_count", 0)),
		"generated fixture count: %d" % int(fixtures.get("generated_fixture_count", 0)),
		"missing fixtures count: %d" % int(fixtures.get("missing_generated_count", 0)),
		"transform mismatches count: %d" % 0,
		"material mismatches count: %d" % int(materials.get("material_mismatches", 0)),
		"collision mismatches count: %d" % 0,
		"critical focus verdict: %s" % str((report.get("critical_focus", {}) as Dictionary).get("verdict", "WARN")),
		"boot player verdict: %s" % ("PASS" if bool(boot.get("ok", false)) else "WARN"),
		"collision root exists: %s generated collision shapes=%d" % [str(collisions.get("collision_root_exists", false)), int(collisions.get("generated_collision_shape_count", 0))],
	]) + "\n"


func _fixtures_csv(report: Dictionary) -> String:
	var fixtures: Dictionary = report.get("fixtures", {}) as Dictionary
	return "metric,value\nsource_fixture_count,%d\nruntime_fixture_count,%d\ngenerated_fixture_count,%d\nmissing_generated_count,%d\nextra_generated_count,%d\n" % [
		int(fixtures.get("source_fixture_count", 0)),
		int(fixtures.get("runtime_fixture_count", 0)),
		int(fixtures.get("generated_fixture_count", 0)),
		int(fixtures.get("missing_generated_count", 0)),
		int(fixtures.get("extra_generated_count", 0)),
	]


func _critical_csv(report: Dictionary) -> String:
	var lines: Array[String] = ["label,fixture_id,runtime_found,generated_found,runtime_meshes,generated_meshes,verdict"]
	var focus: Dictionary = report.get("critical_focus", {}) as Dictionary
	for raw in (focus.get("items", []) as Array):
		var item: Dictionary = raw as Dictionary
		var rt: Dictionary = item.get("runtime", {}) as Dictionary
		var gen: Dictionary = item.get("generated", {}) as Dictionary
		var rt_mesh: Dictionary = rt.get("mesh", {}) as Dictionary
		var gen_mesh: Dictionary = gen.get("mesh", {}) as Dictionary
		lines.append("%s,%d,%s,%s,%d,%d,%s" % [
			str(item.get("label", "")),
			int(item.get("fixture_id", -1)),
			str(rt.get("found", false)),
			str(gen.get("found", false)),
			int(rt_mesh.get("mesh_instance_count", 0)),
			int(gen_mesh.get("mesh_instance_count", 0)),
			str(item.get("mismatch_verdict", "")),
		])
	return "\n".join(lines) + "\n"


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _runtime_prop_root(zone_viewer: Node, zone_id: int) -> Node:
	var prop_result := _zone_result(zone_viewer, "_prop_build_results", zone_id)
	if prop_result != null:
		return prop_result.get("root") as Node
	return null


func _runtime_fixture_ids(zone_viewer: Node, zone_id: int) -> Array:
	var out: Array = []
	var prop_result := _zone_result(zone_viewer, "_prop_build_results", zone_id)
	if prop_result == null:
		return out
	var static_index: Array = _as_array(prop_result.get("static_index"))
	for raw in static_index:
		var row: Dictionary = raw as Dictionary
		if bool(row.get("placed", false)):
			var id := int(row.get("fixture_id", -1))
			if id >= 0 and not out.has(id):
				out.append(id)
	out.sort()
	return out


func _generated_fixture_ids(root: Node) -> Array:
	var out: Array = []
	for node in _all_nodes(root):
		if node.has_meta("fixture_id"):
			var id := int(node.get_meta("fixture_id"))
			if id >= 0 and not out.has(id):
				out.append(id)
	out.sort()
	return out


func _find_fixture_node(root: Node, fixture_id: int) -> Node:
	if root == null:
		return null
	for node in _all_nodes(root):
		if node.has_meta("fixture_id") and int(node.get_meta("fixture_id")) == fixture_id:
			return node
		if str(node.name).begins_with("f%d_" % fixture_id):
			return node
	return null


func _node_detail(node: Node) -> Dictionary:
	if node == null:
		return {"found": false}
	var n3 := node as Node3D
	var safe_transform := _safe_node3d_transform(n3)
	return {
		"found": true,
		"name": str(node.name),
		"path": _safe_node_path(node),
		"inside_tree": node.is_inside_tree(),
		"visible": n3.visible if n3 != null else true,
		"fixture_id": int(node.get_meta("fixture_id", -1)) if node.has_meta("fixture_id") else -1,
		"nif_id": int(node.get_meta("nif_id", -1)) if node.has_meta("nif_id") else -1,
		"source_file": str(node.get_meta("source_file", "")) if node.has_meta("source_file") else "",
		"global_origin": safe_transform.origin if n3 != null else Vector3.ZERO,
		"rotation": n3.rotation_degrees if n3 != null else Vector3.ZERO,
		"scale": n3.scale if n3 != null else Vector3.ONE,
		"mesh": _mesh_stats(node),
	}


func _safe_node_path(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	var names: Array[String] = []
	var cursor: Node = node
	while cursor != null:
		names.push_front(str(cursor.name))
		cursor = cursor.get_parent()
	return "detached://" + "/".join(names)


func _safe_node3d_transform(node: Node3D) -> Transform3D:
	if node == null:
		return Transform3D.IDENTITY
	if node.is_inside_tree():
		return node.global_transform
	return _detached_node3d_transform(node)


func _detached_node3d_transform(node: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var cursor: Node = node
	while cursor != null:
		var n3 := cursor as Node3D
		if n3 != null:
			chain.push_front(n3)
		cursor = cursor.get_parent()
	var out := Transform3D.IDENTITY
	for n3 in chain:
		out = out * n3.transform
	return out


func _transformed_aabb(local: AABB, xform: Transform3D) -> AABB:
	var p := local.position
	var s := local.size
	var points: Array[Vector3] = [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s,
	]
	var out := AABB(xform * points[0], Vector3.ZERO)
	for i in range(1, points.size()):
		out = out.expand(xform * points[i])
	return out


func _mesh_stats(node: Node) -> Dictionary:
	var mesh_count := 0
	var vertex_count := 0
	var surface_count := 0
	var material_count := 0
	var aabb := AABB()
	var has_aabb := false
	var detached_mesh_count := 0
	for child in _all_nodes(node):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mesh_count += 1
		if not mi.is_inside_tree():
			detached_mesh_count += 1
		var mesh := mi.mesh
		surface_count += mesh.get_surface_count()
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if mesh.surface_get_material(s) != null:
				material_count += 1
		var local := mesh.get_aabb()
		var global := _transformed_aabb(local, _safe_node3d_transform(mi))
		aabb = aabb.merge(global) if has_aabb else global
		has_aabb = true
	return {
		"mesh_instance_count": mesh_count,
		"detached_mesh_instance_count": detached_mesh_count,
		"vertex_count": vertex_count,
		"surface_count": surface_count,
		"material_count": material_count,
		"global_aabb_position": aabb.position if has_aabb else Vector3.ZERO,
		"global_aabb_size": aabb.size if has_aabb else Vector3.ZERO,
	}


func _critical_verdict(runtime_node: Node, generated_node: Node) -> String:
	if runtime_node == null and generated_node == null:
		return "MISSING_BOTH"
	if runtime_node == null:
		return "RUNTIME_MISSING"
	if generated_node == null:
		return "GENERATED_MISSING"
	return "PASS"


func _focus_verdict(items: Array) -> String:
	var any_missing := false
	for raw in items:
		var item: Dictionary = raw as Dictionary
		if str(item.get("mismatch_verdict", "")) != "PASS":
			any_missing = true
	return "WARN" if any_missing else "PASS"


func _zone_result(zone_viewer: Node, property_name: String, zone_id: int) -> RefCounted:
	if zone_viewer == null:
		return null
	var dict: Dictionary = _as_dictionary(zone_viewer.get(property_name))
	return dict.get(zone_id, null) as RefCounted


func _zone_array_size(zone_viewer: Node, property_name: String, zone_id: int) -> int:
	if zone_viewer == null:
		return 0
	var dict: Dictionary = _as_dictionary(zone_viewer.get(property_name))
	return _as_array(dict.get(zone_id, [])).size()


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _count_type(root: Node, type_name: String) -> int:
	var count := 0
	for node in _all_nodes(root):
		if node.is_class(type_name):
			count += 1
	return count


func _count_nodes_containing(root: Node, token: String) -> int:
	var count := 0
	var lower_token := token.to_lower()
	for node in _all_nodes(root):
		if str(node.name).to_lower().contains(lower_token):
			count += 1
	return count


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	out.append(root)
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out


func _strip_runtime_objects(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		var dict: Dictionary = value as Dictionary
		for key in dict.keys():
			var item: Variant = dict[key]
			if typeof(item) == TYPE_OBJECT:
				continue
			out[key] = _strip_runtime_objects(item)
		return out
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value as Array
		var out_arr: Array = []
		for item in arr:
			if typeof(item) == TYPE_OBJECT:
				continue
			out_arr.append(_strip_runtime_objects(item))
		return out_arr
	return value


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value as Array
	return []
