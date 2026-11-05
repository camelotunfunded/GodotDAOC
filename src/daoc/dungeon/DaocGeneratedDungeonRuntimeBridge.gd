extends RefCounted
class_name DaocGeneratedDungeonRuntimeBridge

## P1-17D — pont runtime opt-in pour GeneratedDungeon_XXX.tscn.
## Charge/attache une scène donjon déjà générée, ou la régénère si absente,
## puis place la capsule joueur sur un spawn local stable.
## HF3 corrige deux faux raccourcis de HF2 :
## - le spawn n'est plus le premier chunk visible, mais l'instance d'entrée fixe
##   connue/par zone, ou l'instance marquee transition si la scène a été régénérée ;
## - l'état extérieur du joueur est mémorisé puis restauré à la sortie donjon.
## P1-17E1 ajoute une couche WorldDestination neutre DOL/OpenDAoC : le fallback
## géométrique reste jouable, mais il est maintenant explicitement marqué comme
## local_geometry_fallback et non comme vérité serveur.

const DaocZoneCreatorScript = preload("res://src/daoc/DaocZoneCreator.gd")
const DaocWorldDestinationResolverScript = preload("res://src/daoc/world/DaocWorldDestinationResolver.gd")

const SCOPE: String = "P1-17E1 GeneratedDungeon runtime via neutral WorldDestination"
const CHECKPOINT: String = "P1_17E1_WORLD_DESTINATION_RUNTIME_BRIDGE"
const LEGACY_CHECKPOINT_P1_17D: String = "P1_17D_GENERATED_DUNGEON_RUNTIME_ATTACH_SPAWN"
const BRIDGE_ROOT_NAME: String = "GeneratedDungeonsRuntimeRoot_17D"
const ATTACHED_DUNGEON_PREFIX: String = "RuntimeGeneratedDungeon_"
const DEFAULT_REPORT_JSON_PATH: String = "res://reports/daoc_generated_dungeon_runtime_report.json"
const DEFAULT_REPORT_TXT_PATH: String = "res://reports/daoc_generated_dungeon_runtime_report.txt"
const DEFAULT_RUNTIME_SCALE_COMPENSATION: float = 10.0
const DEFAULT_ISOLATE_EXTERIOR: bool = true
const DEFAULT_REMEMBER_EXTERIOR_PLAYER_STATE: bool = true

## Repères provisoires mais déterministes : dans les deux donjons validés,
## l'instance flags[2] == -1 correspond au connecteur d'entrée/transition.
## Les scènes déjà générées avant HF3 n'ont pas encore le meta daoc_flags ; on garde
## donc aussi l'index d'instance comme fallback stable.
const DEFAULT_ENTRY_INSTANCE_BY_ZONE: Dictionary = {
	19: 1,
	21: 0,
}

const DEFAULT_ENTRY_HEADING_BY_ZONE: Dictionary = {
	19: 180.0,
	21: 180.0,
}

const EXTERIOR_HIDE_PREFIXES: Array[String] = [
	"Zone",
	"GeneratedZonesRuntimeRoot",
]

const REQUIRED_BRANCHES: Array = [
	"DungeonChunkInstances",
	"DungeonPortalDebug",
	"DungeonLightDebug",
	"DungeonLogicalConnectorProxies",
]

var host_node: Node = null
var bridge_root: Node3D = null
var attached_dungeons: Dictionary = {}
var scene_paths_by_zone: Dictionary = {}
var spawn_points_by_zone: Dictionary = {}
var last_error: String = ""
var last_operation: String = ""
var last_zone_id: int = -1
var last_result: Dictionary = {}
var event_log: Array = []
var isolated_exterior_nodes: Dictionary = {}
var isolation_active: bool = false
var active_runtime_scale_compensation: float = DEFAULT_RUNTIME_SCALE_COMPENSATION
var saved_exterior_player_state: Dictionary = {}
var destination_resolver_17e: RefCounted = null
var destination_results_by_zone: Dictionary = {}


func configure(host: Node) -> Dictionary:
	host_node = host
	last_operation = "configure"
	last_zone_id = -1
	if host_node == null:
		last_error = "host node missing"
		last_result = _result(false, {"error": last_error})
		_log(last_result)
		return last_result
	var root: Node3D = _ensure_bridge_root(host_node)
	var ok: bool = root != null
	last_error = "" if ok else "bridge root unavailable"
	last_result = _result(ok, {
		"host_path": str(host_node.get_path()) if host_node.is_inside_tree() else str(host_node.name),
		"bridge_root": BRIDGE_ROOT_NAME,
		"bridge_root_present": ok,
		"attached_zones": attached_zone_ids(),
		"destination_resolver_present": _ensure_destination_resolver_17e() != null,
	})
	_log(last_result)
	return last_result


func attach_dungeon_scene(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	last_operation = "attach_dungeon_scene"
	last_zone_id = znum
	if host != null:
		host_node = host
	if host_node == null:
		last_error = "host node missing"
		last_result = _result(false, {"zone_id": znum, "error": last_error})
		_log(last_result)
		return last_result
	var root: Node3D = _ensure_bridge_root(host_node)
	if root == null:
		last_error = "bridge root unavailable"
		last_result = _result(false, {"zone_id": znum, "error": last_error})
		_log(last_result)
		return last_result

	var isolate_exterior: bool = bool(options.get("isolate_exterior", DEFAULT_ISOLATE_EXTERIOR))
	active_runtime_scale_compensation = float(options.get("runtime_scale_compensation", DEFAULT_RUNTIME_SCALE_COMPENSATION))
	if isolate_exterior:
		_apply_exterior_isolation(true)
	var scene_path: String = str(options.get("scene_path", _default_dungeon_scene_path(znum)))
	var auto_export_missing: bool = bool(options.get("auto_export_missing", false))
	var auto_export_result: Dictionary = {}
	if not FileAccess.file_exists(scene_path) and auto_export_missing:
		auto_export_result = _auto_export_dungeon_scene(host_node, znum, scene_path, options)
	if not FileAccess.file_exists(scene_path):
		last_error = "generated dungeon scene missing"
		last_result = _result(false, {"zone_id": znum, "scene_path": scene_path, "missing": true, "auto_export": auto_export_result, "error": last_error})
		_log(last_result)
		return last_result

	var resource: Resource = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = resource as PackedScene
	if packed == null:
		last_error = "resource is not PackedScene"
		last_result = _result(false, {"zone_id": znum, "scene_path": scene_path, "missing": false, "auto_export": auto_export_result, "error": last_error})
		_log(last_result)
		return last_result
	var node: Node = packed.instantiate() as Node
	if node == null:
		last_error = "PackedScene instantiate returned null"
		last_result = _result(false, {"zone_id": znum, "scene_path": scene_path, "auto_export": auto_export_result, "error": last_error})
		_log(last_result)
		return last_result
	if has_attached_zone(znum):
		detach_dungeon_scene(znum)
	node.name = "%s%03d" % [ATTACHED_DUNGEON_PREFIX, znum]
	node.set_meta("p1_17d_runtime_attached", true)
	node.set_meta("zone_id", znum)
	node.set_meta("scene_path", scene_path)
	node.set_meta("runtime_scale_compensation", active_runtime_scale_compensation)
	if node is Node3D:
		var node3d: Node3D = node as Node3D
		node3d.scale = Vector3.ONE * active_runtime_scale_compensation
	root.add_child(node)
	attached_dungeons[znum] = node
	scene_paths_by_zone[znum] = scene_path
	var branches: Dictionary = _branch_report(node)
	var spawn: Dictionary = _resolve_spawn_point(node, znum, options)
	spawn_points_by_zone[znum] = spawn
	last_error = "" if bool(spawn.get("ok", false)) else str(spawn.get("error", "spawn resolution failed"))
	last_result = _result(bool(spawn.get("ok", false)), {
		"zone_id": znum,
		"scene_path": scene_path,
		"node_name": str(node.name),
		"node_path": str(node.get_path()) if node.is_inside_tree() else str(node.name),
		"attached": true,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"present_branches": branches.get("present_branches", []),
		"missing_branches": branches.get("missing_branches", []),
		"branch_count": int(branches.get("branch_count", 0)),
		"isolation_active": isolation_active,
		"runtime_scale_compensation": active_runtime_scale_compensation,
		"spawn": spawn,
		"auto_export": auto_export_result,
		"error": last_error,
	})
	_log(last_result)
	return last_result


func attach_and_spawn_player(host: Node, player: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	last_operation = "attach_and_spawn_player"
	if player != null and bool(options.get("remember_exterior_player_state", DEFAULT_REMEMBER_EXTERIOR_PLAYER_STATE)):
		_remember_exterior_player_state(player, options)
	var attach_result: Dictionary = attach_dungeon_scene(host, znum, options)
	if not bool(attach_result.get("ok", false)):
		last_result = _result(false, {"zone_id": znum, "attach": attach_result, "spawned": false, "error": str(attach_result.get("error", "attach failed"))})
		_log(last_result)
		return last_result
	var spawn_result: Dictionary = spawn_player_on_dungeon(player, znum, options)
	last_result = _result(bool(spawn_result.get("ok", false)), {
		"zone_id": znum,
		"attach": attach_result,
		"spawn": spawn_result,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"error": str(spawn_result.get("error", "")),
	})
	last_error = str(last_result.get("error", ""))
	_log(last_result)
	return last_result


func spawn_player_on_dungeon(player: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	last_operation = "spawn_player_on_dungeon"
	last_zone_id = znum
	if player == null:
		last_error = "player missing"
		last_result = _result(false, {"zone_id": znum, "spawned": false, "error": last_error})
		_log(last_result)
		return last_result
	if not has_attached_zone(znum):
		last_error = "dungeon scene not attached"
		last_result = _result(false, {"zone_id": znum, "spawned": false, "error": last_error})
		_log(last_result)
		return last_result
	var spawn: Dictionary = spawn_points_by_zone.get(znum, {}) as Dictionary
	if spawn.is_empty() or not bool(spawn.get("ok", false)):
		var node: Node = attached_dungeons.get(znum, null) as Node
		spawn = _resolve_spawn_point(node, znum, options)
		spawn_points_by_zone[znum] = spawn
	if not bool(spawn.get("ok", false)):
		last_error = str(spawn.get("error", "spawn point invalid"))
		last_result = _result(false, {"zone_id": znum, "spawned": false, "spawn": spawn, "error": last_error})
		_log(last_result)
		return last_result
	var px: float = float(spawn.get("daoc_x", 0.0))
	var py: float = float(spawn.get("daoc_y", 0.0))
	var pz: float = float(spawn.get("daoc_z", 0.0))
	var heading: float = float(spawn.get("heading_deg", options.get("heading_deg", DEFAULT_ENTRY_HEADING_BY_ZONE.get(znum, 0.0))))
	_apply_player_daoc_state(player, znum, px, py, pz, heading)
	last_error = ""
	last_result = _result(true, {
		"zone_id": znum,
		"spawned": true,
		"player_zone": znum,
		"daoc_x": px,
		"daoc_y": py,
		"daoc_z": pz,
		"heading_deg": heading,
		"godot_position": str(daoc_to_godot(znum, px, py, pz)),
		"spawn": spawn,
		"attached_zones": attached_zone_ids(),
	})
	_log(last_result)
	return last_result


func detach_dungeon_scene(znum: int, player: Node = null) -> Dictionary:
	last_operation = "detach_dungeon_scene"
	last_zone_id = znum
	var existed: bool = has_attached_zone(znum)
	if existed:
		var node: Node = attached_dungeons[znum] as Node
		attached_dungeons.erase(znum)
		if node != null and is_instance_valid(node):
			node.free()
	spawn_points_by_zone.erase(znum)
	destination_results_by_zone.erase(znum)
	var restore_result: Dictionary = {}
	if attached_zone_ids().is_empty():
		_apply_exterior_isolation(false)
		if player != null:
			restore_result = restore_player_after_dungeon(player)
	last_error = ""
	last_result = _result(true, {"zone_id": znum, "detached": existed, "attached_zones": attached_zone_ids(), "attached_zone_count": attached_zone_ids().size(), "isolation_active": isolation_active, "restore": restore_result})
	_log(last_result)
	return last_result


func detach_all_dungeon_scenes(player: Node = null) -> Dictionary:
	last_operation = "detach_all_dungeon_scenes"
	var before: Array = attached_zone_ids()
	for zone_value in before:
		detach_dungeon_scene(int(zone_value))
	if before.is_empty():
		_apply_exterior_isolation(false)
	var restore_result: Dictionary = {}
	if player != null:
		restore_result = restore_player_after_dungeon(player)
	last_operation = "detach_all_dungeon_scenes"
	last_zone_id = -1
	last_error = ""
	last_result = _result(true, {"detached_zones": before, "attached_zones": attached_zone_ids(), "attached_zone_count": attached_zone_ids().size(), "restored_player": bool(restore_result.get("ok", false)), "restore": restore_result, "isolation_active": isolation_active})
	_log(last_result)
	return last_result


func restore_player_after_dungeon(player: Node) -> Dictionary:
	last_operation = "restore_player_after_dungeon"
	if player == null:
		return {"ok": false, "error": "player missing"}
	if saved_exterior_player_state.is_empty():
		return {"ok": false, "error": "no saved exterior player state"}
	var zone_id: int = int(saved_exterior_player_state.get("zone", 0))
	var px: float = float(saved_exterior_player_state.get("x", 32768.0))
	var py: float = float(saved_exterior_player_state.get("y", 32768.0))
	var pz: float = float(saved_exterior_player_state.get("z", 0.0))
	var heading: float = float(saved_exterior_player_state.get("heading_deg", 0.0))
	var floor_z: float = pz
	if host_node != null and host_node.has_method("sample_daoc_floor_z"):
		floor_z = float(host_node.call("sample_daoc_floor_z", zone_id, px, py, pz))
		if pz < floor_z + 3.0:
			pz = floor_z + 3.0
	_apply_player_daoc_state(player, zone_id, px, py, pz, heading)
	var restored: Dictionary = {
		"ok": true,
		"zone": zone_id,
		"daoc_x": px,
		"daoc_y": py,
		"daoc_z": pz,
		"heading_deg": heading,
		"floor_daoc_z": floor_z,
		"source": "saved exterior player state before generated dungeon attachspawn",
	}
	saved_exterior_player_state.clear()
	return restored


func has_attached_zone(znum: int) -> bool:
	if not attached_dungeons.has(znum):
		return false
	var node: Node = attached_dungeons[znum] as Node
	if node == null or not is_instance_valid(node):
		attached_dungeons.erase(znum)
		spawn_points_by_zone.erase(znum)
		return false
	return true


func attached_zone_ids() -> Array:
	var out: Array = []
	for key in attached_dungeons.keys():
		var znum: int = int(key)
		if has_attached_zone(znum):
			out.append(znum)
	out.sort()
	return out


func daoc_to_godot(znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	var local_scale: float = _world_scale()
	if active_runtime_scale_compensation > 0.0001:
		local_scale = local_scale / active_runtime_scale_compensation
	var local_pos: Vector3 = Vector3(daoc_x * local_scale, daoc_z * local_scale, -daoc_y * local_scale)
	if has_attached_zone(znum):
		var dungeon_node: Node = attached_dungeons.get(znum, null) as Node
		if dungeon_node != null and dungeon_node is Node3D:
			var dungeon_3d: Node3D = dungeon_node as Node3D
			return dungeon_3d.global_transform * local_pos
	return local_pos


func sample_floor_daoc(znum: int, _daoc_x: float, _daoc_y: float, fallback_z: float = 0.0) -> float:
	var spawn: Dictionary = spawn_points_by_zone.get(znum, {}) as Dictionary
	if not spawn.is_empty() and bool(spawn.get("ok", false)):
		return float(spawn.get("floor_daoc_z", spawn.get("daoc_z", fallback_z)))
	return fallback_z


func write_runtime_report(zone_ids: Array = [], options: Dictionary = {}) -> Dictionary:
	var zones: Array = zone_ids.duplicate()
	if zones.is_empty():
		zones = attached_zone_ids()
	var results: Array = []
	var ok_count: int = 0
	var fail_count: int = 0
	for zone_value in zones:
		var znum: int = int(zone_value)
		var item: Dictionary = {
			"zone": znum,
			"attached": has_attached_zone(znum),
			"scene_path": str(scene_paths_by_zone.get(znum, _default_dungeon_scene_path(znum))),
			"spawn": spawn_points_by_zone.get(znum, {}),
		}
		item["ok"] = bool(item.get("attached", false)) and bool((item.get("spawn", {}) as Dictionary).get("ok", false))
		if bool(item.get("ok", false)):
			ok_count += 1
		else:
			fail_count += 1
		results.append(item)
	var report: Dictionary = _result(fail_count == 0 and zones.size() > 0, {
		"schema": "daoc.generated_dungeon_runtime_report.v2",
		"zones": zones,
		"zone_count": zones.size(),
		"ok_count": ok_count,
		"fail_count": fail_count,
		"attached_zones": attached_zone_ids(),
		"results": results,
		"destination_results_by_zone": destination_results_by_zone.duplicate(true),
		"report_json_path": str(options.get("report_json_path", DEFAULT_REPORT_JSON_PATH)),
		"report_txt_path": str(options.get("report_txt_path", DEFAULT_REPORT_TXT_PATH)),
		"reports_written": false,
	})
	if bool(options.get("write_reports", true)):
		var json_ok: bool = _write_json(str(report.get("report_json_path", DEFAULT_REPORT_JSON_PATH)), report)
		var txt_ok: bool = _write_text(str(report.get("report_txt_path", DEFAULT_REPORT_TXT_PATH)), _format_report_txt(report))
		report["reports_written"] = json_ok and txt_ok
		if bool(report.get("reports_written", false)):
			_write_json(str(report.get("report_json_path", DEFAULT_REPORT_JSON_PATH)), report)
			_write_text(str(report.get("report_txt_path", DEFAULT_REPORT_TXT_PATH)), _format_report_txt(report))
	last_result = report
	_log(report)
	return report


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"legacy_checkpoint_p1_17d": LEGACY_CHECKPOINT_P1_17D,
		"host_valid": host_node != null and is_instance_valid(host_node),
		"bridge_root_present": bridge_root != null and is_instance_valid(bridge_root),
		"bridge_root_name": BRIDGE_ROOT_NAME,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"isolation_active": isolation_active,
		"isolated_exterior_node_count": isolated_exterior_nodes.size(),
		"runtime_scale_compensation": active_runtime_scale_compensation,
		"saved_exterior_player_state_present": not saved_exterior_player_state.is_empty(),
		"saved_exterior_player_state": saved_exterior_player_state.duplicate(true),
		"scene_paths_by_zone": scene_paths_by_zone.duplicate(true),
		"spawn_points_by_zone": spawn_points_by_zone.duplicate(true),
		"destination_results_by_zone": destination_results_by_zone.duplicate(true),
		"destination_resolver": _destination_resolver_snapshot_17e(),
		"last_operation": last_operation,
		"last_zone_id": last_zone_id,
		"last_error": last_error,
		"last_result": _strip_runtime_objects(last_result),
		"event_log_size": event_log.size(),
	}



func _apply_exterior_isolation(enable: bool) -> void:
	if host_node == null:
		return
	if enable:
		if isolation_active:
			return
		isolated_exterior_nodes.clear()
		for child_value in host_node.get_children():
			var child: Node = child_value as Node
			if child == null:
				continue
			if child == bridge_root:
				continue
			if child.name == StringName(BRIDGE_ROOT_NAME):
				continue
			if not (child is Node3D):
				continue
			if _should_hide_for_dungeon_isolation(child):
				var child3d: Node3D = child as Node3D
				isolated_exterior_nodes[str(child3d.get_path())] = child3d.visible
				child3d.visible = false
		isolation_active = true
		return
	if not isolation_active:
		return
	for path_value in isolated_exterior_nodes.keys():
		var path_text: String = str(path_value)
		var node: Node = host_node.get_node_or_null(NodePath(path_text))
		if node != null and node is Node3D:
			var node3d: Node3D = node as Node3D
			node3d.visible = bool(isolated_exterior_nodes[path_value])
	isolated_exterior_nodes.clear()
	isolation_active = false


func _should_hide_for_dungeon_isolation(node: Node) -> bool:
	var node_name: String = str(node.name)
	for prefix_value in EXTERIOR_HIDE_PREFIXES:
		var prefix: String = str(prefix_value)
		if node_name.begins_with(prefix) and node_name != BRIDGE_ROOT_NAME:
			return true
	return false


func _ensure_bridge_root(host: Node) -> Node3D:
	if bridge_root != null and is_instance_valid(bridge_root):
		return bridge_root
	if host == null:
		return null
	var existing: Node = host.get_node_or_null(NodePath(BRIDGE_ROOT_NAME))
	if existing != null and existing is Node3D:
		bridge_root = existing as Node3D
		return bridge_root
	var root: Node3D = Node3D.new()
	root.name = BRIDGE_ROOT_NAME
	root.set_meta("p1_17d_generated_dungeon_runtime_bridge_root", true)
	root.set_meta("p1_17e1_world_destination_runtime_bridge_root", true)
	host.add_child(root)
	bridge_root = root
	return bridge_root


func _auto_export_dungeon_scene(host: Node, znum: int, scene_path: String, options: Dictionary) -> Dictionary:
	var creator: RefCounted = DaocZoneCreatorScript.new()
	if creator == null or not creator.has_method("export_dungeon_scene_c2"):
		return {"ok": false, "error": "DaocZoneCreator.export_dungeon_scene_c2 missing", "scene_path": scene_path}
	var export_options: Dictionary = options.duplicate(true)
	export_options["scene_path"] = scene_path
	export_options["dry_run"] = false
	var result: Variant = creator.call("export_dungeon_scene_c2", host, znum, export_options)
	if result != null and result.has_method("to_debug_dict"):
		var debug: Dictionary = result.call("to_debug_dict", false) as Dictionary
		debug["scene_path"] = scene_path
		debug["file_exists_after_export"] = FileAccess.file_exists(scene_path)
		var detached_root: Node = result.get("root") as Node
		if detached_root != null and not detached_root.is_inside_tree():
			detached_root.free()
		return debug
	return {"ok": false, "error": "export result missing", "scene_path": scene_path, "file_exists_after_export": FileAccess.file_exists(scene_path)}



func _ensure_destination_resolver_17e() -> RefCounted:
	if destination_resolver_17e == null:
		destination_resolver_17e = DaocWorldDestinationResolverScript.new()
	return destination_resolver_17e


func _destination_resolver_snapshot_17e() -> Dictionary:
	var resolver: RefCounted = _ensure_destination_resolver_17e()
	if resolver != null and resolver.has_method("debug_snapshot"):
		return resolver.call("debug_snapshot") as Dictionary
	return {"ok": false, "error": "destination resolver missing"}


func _resolve_world_destination_17e(znum: int, options: Dictionary) -> Dictionary:
	var resolver: RefCounted = _ensure_destination_resolver_17e()
	if resolver == null or not resolver.has_method("resolve_destination_for_zone"):
		return {
			"ok": false,
			"backend": "none",
			"source": "resolver_missing",
			"authenticity": "fallback",
			"target_zone_id": znum,
			"error": "WorldDestination resolver missing",
		}
	var context: Dictionary = options.duplicate(true)
	context["target_zone_id"] = znum
	if not context.has("destination_backend_preference"):
		context["destination_backend_preference"] = "auto"
	var result: Dictionary = resolver.call("resolve_destination_for_zone", znum, context) as Dictionary
	return result


func _spawn_from_world_destination_17e(znum: int, destination_result: Dictionary) -> Dictionary:
	if not bool(destination_result.get("ok", false)):
		return {"ok": false, "zone": znum, "source": "world_destination_unavailable"}
	var destination: Dictionary = destination_result.get("destination", {}) as Dictionary
	if destination.is_empty() or not bool(destination.get("ok", false)):
		return {"ok": false, "zone": znum, "source": "world_destination_invalid", "destination_resolution": destination_result.duplicate(true)}
	var px: float = float(destination.get("x", 0.0))
	var py: float = float(destination.get("y", 0.0))
	var pz: float = float(destination.get("z", 0.0))
	var heading: float = float(destination.get("heading_deg", 0.0))
	var backend: String = str(destination.get("backend", destination_result.get("backend", "unknown")))
	var source: String = str(destination.get("source", destination_result.get("source", "world_destination")))
	var authenticity: String = str(destination.get("authenticity", destination_result.get("authenticity", "server_imported")))
	return {
		"ok": true,
		"zone": znum,
		"source": source,
		"backend": backend,
		"authenticity": authenticity,
		"destination_resolution_ok": true,
		"destination_resolution": destination_result.duplicate(true),
		"world_destination": destination.duplicate(true),
		"node_name": "",
		"instance_index": -1,
		"chunk_index": -1,
		"nif_name": "",
		"daoc_x": px,
		"daoc_y": py,
		"daoc_z": pz,
		"floor_daoc_z": pz,
		"spawn_z_offset_raw": 0.0,
		"heading_deg": heading,
		"godot_position": str(daoc_to_godot(znum, px, py, pz)),
	}


func _resolve_spawn_point(root: Node, znum: int, options: Dictionary) -> Dictionary:
	if root == null:
		return {"ok": false, "zone": znum, "error": "root missing"}
	var destination_result: Dictionary = _resolve_world_destination_17e(znum, options)
	destination_results_by_zone[znum] = destination_result
	var destination_spawn: Dictionary = _spawn_from_world_destination_17e(znum, destination_result)
	if bool(destination_spawn.get("ok", false)):
		return destination_spawn
	var explicit_spawn: Dictionary = _explicit_spawn_from_options(znum, options)
	if bool(explicit_spawn.get("ok", false)):
		return explicit_spawn
	var instances_root: Node = root.get_node_or_null(NodePath("DungeonChunkInstances"))
	if instances_root == null:
		return {"ok": false, "zone": znum, "error": "DungeonChunkInstances missing"}
	var preferred_index: int = int(options.get("spawn_instance_index", -1))
	var chosen: Node = null
	var source: String = ""
	if preferred_index >= 0:
		chosen = _find_instance_by_index(instances_root, preferred_index)
		source = "explicit spawn_instance_index"
	if chosen == null:
		chosen = _find_entry_marker_instance(instances_root)
		if chosen != null:
			source = "dungeon.place transition marker flags[2] == -1"
	if chosen == null and DEFAULT_ENTRY_INSTANCE_BY_ZONE.has(znum):
		var default_index: int = int(DEFAULT_ENTRY_INSTANCE_BY_ZONE[znum])
		chosen = _find_instance_by_index(instances_root, default_index)
		if chosen != null:
			source = "fixed zone entry instance fallback"
	if chosen == null:
		chosen = _first_spawnable_instance(instances_root)
		if chosen != null:
			source = "first spawnable dungeon instance fallback"
	if chosen == null:
		return {"ok": false, "zone": znum, "error": "no spawnable dungeon instance"}
	var raw_x: float = float(chosen.get_meta("daoc_x", 0.0))
	var raw_y: float = float(chosen.get_meta("daoc_y", 0.0))
	var raw_z: float = float(chosen.get_meta("daoc_z", 0.0))
	var z_offset: float = float(options.get("spawn_z_offset_raw", 8.0))
	var floor_z: float = raw_z
	var spawn_z: float = raw_z + z_offset
	return {
		"ok": true,
		"zone": znum,
		"source": source,
		"backend": "fallback",
		"authenticity": "local_geometry_fallback",
		"destination_resolution_ok": false,
		"destination_resolution": destination_result.duplicate(true),
		"node_name": str(chosen.name),
		"instance_index": int(chosen.get_meta("instance_index", -1)),
		"chunk_index": int(chosen.get_meta("chunk_index", -1)),
		"nif_name": str(chosen.get_meta("nif_name", "")),
		"daoc_x": raw_x,
		"daoc_y": raw_y,
		"daoc_z": spawn_z,
		"floor_daoc_z": floor_z,
		"spawn_z_offset_raw": z_offset,
		"godot_position": str(daoc_to_godot(znum, raw_x, raw_y, spawn_z)),
	}


func _explicit_spawn_from_options(znum: int, options: Dictionary) -> Dictionary:
	if not options.has("spawn_daoc_x") or not options.has("spawn_daoc_y"):
		return {"ok": false}
	var px: float = float(options.get("spawn_daoc_x", 0.0))
	var py: float = float(options.get("spawn_daoc_y", 0.0))
	var pz: float = float(options.get("spawn_daoc_z", options.get("spawn_z", 0.0)))
	var floor_z: float = float(options.get("spawn_floor_daoc_z", pz))
	return {
		"ok": true,
		"zone": znum,
		"source": "explicit spawn_daoc_x/y/z options",
		"backend": "manual_options",
		"authenticity": "manual",
		"destination_resolution_ok": true,
		"node_name": "",
		"instance_index": -1,
		"chunk_index": -1,
		"nif_name": "",
		"daoc_x": px,
		"daoc_y": py,
		"daoc_z": pz,
		"floor_daoc_z": floor_z,
		"spawn_z_offset_raw": 0.0,
		"godot_position": str(daoc_to_godot(znum, px, py, pz)),
	}


func _find_entry_marker_instance(root: Node) -> Node:
	for child_value in root.get_children():
		var child: Node = child_value as Node
		if child == null:
			continue
		if _node_has_entry_marker_flags(child):
			return child
	return null


func _node_has_entry_marker_flags(node: Node) -> bool:
	if node == null or not node.has_meta("daoc_flags"):
		return false
	var flags_value: Variant = node.get_meta("daoc_flags")
	var flags: Array = []
	if typeof(flags_value) == TYPE_ARRAY:
		flags = flags_value as Array
	elif typeof(flags_value) == TYPE_PACKED_INT32_ARRAY:
		var packed: PackedInt32Array = flags_value as PackedInt32Array
		for value in packed:
			flags.append(int(value))
	if flags.size() < 3:
		return false
	return int(flags[2]) == -1


func _find_instance_by_index(root: Node, instance_index: int) -> Node:
	for child_value in root.get_children():
		var child: Node = child_value as Node
		if child != null and int(child.get_meta("instance_index", -999999)) == instance_index:
			return child
	return null


func _first_spawnable_instance(root: Node) -> Node:
	for child_value in root.get_children():
		var child: Node = child_value as Node
		if child == null:
			continue
		if not child.has_meta("daoc_x") or not child.has_meta("daoc_y") or not child.has_meta("daoc_z"):
			continue
		if _count_mesh_instances(child) <= 0:
			continue
		return child
	for child_value in root.get_children():
		var child: Node = child_value as Node
		if child != null and child.has_meta("daoc_x") and child.has_meta("daoc_y") and child.has_meta("daoc_z"):
			return child
	return null


func _count_mesh_instances(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1 if node is MeshInstance3D else 0
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child != null:
			count += _count_mesh_instances(child)
	return count


func _branch_report(root: Node) -> Dictionary:
	var present: Array = []
	var missing: Array = []
	for branch_value in REQUIRED_BRANCHES:
		var branch_name: String = str(branch_value)
		if root != null and root.get_node_or_null(NodePath(branch_name)) != null:
			present.append(branch_name)
		else:
			missing.append(branch_name)
	return {"present_branches": present, "missing_branches": missing, "branch_count": present.size()}


func _world_scale() -> float:
	if host_node != null:
		return float(host_node.get("world_scale"))
	return 1.0


func _remember_exterior_player_state(player: Node, options: Dictionary = {}) -> void:
	if player == null:
		return
	if not bool(options.get("force_remember_exterior_player_state", false)) and not saved_exterior_player_state.is_empty():
		return
	var current_zone: int = int(player.get("daoc_zone"))
	if has_attached_zone(current_zone):
		return
	saved_exterior_player_state = {
		"zone": current_zone,
		"x": float(player.get("daoc_x")),
		"y": float(player.get("daoc_y")),
		"z": float(player.get("daoc_z")),
		"heading_deg": float(player.get("heading_deg")),
		"source": "pre-generated-dungeon attachspawn snapshot",
	}


func _apply_player_daoc_state(player: Node, zone_id: int, px: float, py: float, pz: float, heading: float) -> void:
	player.set("daoc_zone", zone_id)
	player.set("daoc_x", px)
	player.set("daoc_y", py)
	player.set("daoc_z", pz)
	player.set("heading_deg", heading)
	player.set("vertical_velocity_raw", 0.0)
	player.set("on_ground", true)
	player.set("climb_flag_local_placeholder", false)
	player.set("movement_state", 0)
	if player.has_method("_apply_daoc_transform"):
		player.call("_apply_daoc_transform")
	else:
		player.set("global_position", daoc_to_godot(zone_id, px, py, pz))


func _default_dungeon_scene_path(znum: int) -> String:
	return "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn" % [znum, znum]


func _result(ok: bool, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
	}
	for key in extra.keys():
		out[key] = extra[key]
	return out


func _log(entry: Dictionary) -> void:
	event_log.append(_strip_runtime_objects(entry))
	if event_log.size() > 24:
		event_log.pop_front()


func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return FileAccess.file_exists(path)


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return FileAccess.file_exists(path)


func _format_report_txt(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("DAoC GeneratedDungeon runtime attach/spawn report")
	lines.append("scope=%s" % str(report.get("scope", "")))
	lines.append("checkpoint=%s" % str(report.get("checkpoint", "")))
	lines.append("ok=%s ok_count=%d fail_count=%d attached=%s" % [str(report.get("ok", false)), int(report.get("ok_count", 0)), int(report.get("fail_count", 0)), str(report.get("attached_zones", []))])
	lines.append("")
	for item_value in (report.get("results", []) as Array):
		var item: Dictionary = item_value as Dictionary
		var spawn: Dictionary = item.get("spawn", {}) as Dictionary
		lines.append("[zone%03d] %s scene=%s" % [int(item.get("zone", -1)), "OK" if bool(item.get("ok", false)) else "FAIL", str(item.get("scene_path", ""))])
		lines.append("spawn ok=%s x=%.1f y=%.1f z=%.1f backend=%s authenticity=%s source=%s node=%s" % [str(spawn.get("ok", false)), float(spawn.get("daoc_x", 0.0)), float(spawn.get("daoc_y", 0.0)), float(spawn.get("daoc_z", 0.0)), str(spawn.get("backend", "")), str(spawn.get("authenticity", "")), str(spawn.get("source", "")), str(spawn.get("node_name", ""))])
		lines.append("")
	return "\n".join(lines)


func _strip_runtime_objects(value: Variant) -> Variant:
	var value_type: int = typeof(value)
	if value_type == TYPE_DICTIONARY:
		var out: Dictionary = {}
		var dict: Dictionary = value as Dictionary
		for key in dict.keys():
			var item: Variant = dict[key]
			if typeof(item) == TYPE_OBJECT:
				continue
			out[key] = _strip_runtime_objects(item)
		return out
	if value_type == TYPE_ARRAY:
		var out_arr: Array = []
		var arr: Array = value as Array
		for item in arr:
			if typeof(item) == TYPE_OBJECT:
				continue
			out_arr.append(_strip_runtime_objects(item))
		return out_arr
	return value
