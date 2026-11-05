extends RefCounted
class_name DaocGeneratedZoneRuntimeBridge

## P1-16A9 — pont runtime contrôlé vers les scènes générées.
## Attache/détache les GeneratedZone_XXX.tscn sous un root dédié sans supprimer
## le build live ZoneViewer existant. La bascule devient testable, mais reste opt-in.
## Depuis P1-16A10A, attachall ignore les familles non supportées du manifest.

const DaocGeneratedZoneSceneLoaderScript = preload("res://src/daoc/DaocGeneratedZoneSceneLoader.gd")

const SCOPE: String = "P1-16A9 generated-scene runtime bridge"
const CHECKPOINT: String = "P1_16A9_GENERATED_SCENE_RUNTIME_BRIDGE"
const DEFAULT_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"
const BRIDGE_ROOT_NAME: String = "GeneratedZonesRuntimeRoot_A9"
const ATTACHED_ZONE_PREFIX: String = "RuntimeGeneratedZone_"
const REQUIRED_BRANCHES: Array = [
	"TerrainRoot",
	"StaticPropsRoot",
	"CollisionRoot",
	"WaterRoot",
	"ZoneJumpRoot",
]

var manifest_path: String = DEFAULT_MANIFEST_PATH
var host_node: Node = null
var bridge_root: Node3D = null
var loader: RefCounted = null
var attached_zones: Dictionary = {}
var last_error: String = ""
var last_operation: String = ""
var last_zone_id: int = -1
var last_result: Dictionary = {}
var event_log: Array = []


func configure(host: Node, path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	manifest_path = path
	host_node = host
	last_operation = "configure"
	last_zone_id = -1
	if host_node == null:
		last_error = "host node missing"
		last_result = _result(false, {"error": last_error, "manifest_path": manifest_path})
		_log(last_result)
		return last_result
	var root: Node3D = _ensure_bridge_root(host_node)
	var ok: bool = root != null
	last_error = "" if ok else "bridge root unavailable"
	last_result = _result(ok, {
		"manifest_path": manifest_path,
		"host_path": str(host_node.get_path()) if host_node.is_inside_tree() else str(host_node.name),
		"bridge_root": BRIDGE_ROOT_NAME,
		"bridge_root_present": ok,
		"attached_zones": attached_zone_ids(),
	})
	_log(last_result)
	return last_result


func attach_zone_scene(host: Node, znum: int, path: String = DEFAULT_MANIFEST_PATH, replace_existing: bool = true) -> Dictionary:
	last_operation = "attach_zone_scene"
	last_zone_id = znum
	manifest_path = path
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
	if has_attached_zone(znum):
		if not replace_existing:
			var existing: Node = attached_zones[znum] as Node
			last_error = ""
			last_result = _result(true, {
				"zone_id": znum,
				"already_attached": true,
				"node_name": str(existing.name),
				"attached_zones": attached_zone_ids(),
			})
			_log(last_result)
			return last_result
		detach_zone_scene(znum)
	var scene_loader: RefCounted = _ensure_loader()
	var node: Node = scene_loader.call("create_generated_zone_node", znum, path) as Node
	if node == null:
		last_error = str(scene_loader.get("last_error"))
		last_result = _result(false, {
			"zone_id": znum,
			"scene_path": str(scene_loader.get("last_scene_path")),
			"error": last_error,
		})
		_log(last_result)
		return last_result
	node.name = "%s%03d" % [ATTACHED_ZONE_PREFIX, znum]
	node.set_meta("p1_16a9_runtime_attached", true)
	node.set_meta("zone_id", znum)
	node.set_meta("scene_path", str(scene_loader.get("last_scene_path")))
	root.add_child(node)
	attached_zones[znum] = node
	var branches: Dictionary = _branch_report(node)
	last_error = ""
	var missing_branches: Array = branches.get("missing_branches", []) as Array
	last_result = _result(missing_branches.is_empty(), {
		"zone_id": znum,
		"scene_path": str(scene_loader.get("last_scene_path")),
		"node_name": str(node.name),
		"node_path": str(node.get_path()) if node.is_inside_tree() else str(node.name),
		"attached": true,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"present_branches": branches.get("present_branches", []),
		"missing_branches": branches.get("missing_branches", []),
		"branch_count": int(branches.get("branch_count", 0)),
	})
	_log(last_result)
	return last_result


func attach_manifest_zones(host: Node, path: String = DEFAULT_MANIFEST_PATH, max_zones: int = 0) -> Dictionary:
	last_operation = "attach_manifest_zones"
	manifest_path = path
	if host != null:
		host_node = host
	var scene_loader: RefCounted = _ensure_loader()
	var manifest_result: Dictionary = scene_loader.call("load_manifest", path) as Dictionary
	if not bool(manifest_result.get("ok", false)):
		last_error = str(manifest_result.get("error", "manifest load failed"))
		last_result = _result(false, {"error": last_error, "manifest_path": path, "manifest_result": manifest_result})
		_log(last_result)
		return last_result
	var zone_ids: Array = []
	if scene_loader.has_method("manifest_exportable_zone_ids"):
		zone_ids = scene_loader.call("manifest_exportable_zone_ids") as Array
	else:
		zone_ids = scene_loader.call("manifest_zone_ids") as Array
	var attached: Array = []
	var failed: Array = []
	var results: Array = []
	var limit: int = max_zones
	for zone_value in zone_ids:
		if limit > 0 and attached.size() >= limit:
			break
		var znum: int = int(zone_value)
		var result: Dictionary = attach_zone_scene(host_node, znum, path, true)
		results.append(_strip_runtime_objects(result))
		if bool(result.get("ok", false)):
			attached.append(znum)
		else:
			failed.append(znum)
	last_error = "" if failed.is_empty() else "one or more generated zones failed to attach"
	var all_manifest_zones: Array = zone_ids
	if scene_loader.has_method("manifest_zone_ids"):
		all_manifest_zones = scene_loader.call("manifest_zone_ids") as Array
	last_result = _result(failed.is_empty(), {
		"manifest_path": path,
		"requested_zones": zone_ids,
		"attached_zones_this_call": attached,
		"failed_zones": failed,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"manifest_all_zones": all_manifest_zones,
		"manifest_exportable_zones": zone_ids,
		"results": results,
		"error": last_error,
	})
	_log(last_result)
	return last_result


func detach_zone_scene(znum: int) -> Dictionary:
	last_operation = "detach_zone_scene"
	last_zone_id = znum
	var existed: bool = has_attached_zone(znum)
	if existed:
		var node: Node = attached_zones[znum] as Node
		attached_zones.erase(znum)
		if node != null and is_instance_valid(node):
			node.free()
	last_error = ""
	last_result = _result(true, {
		"zone_id": znum,
		"detached": existed,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
	})
	_log(last_result)
	return last_result


func detach_all_generated_zones() -> Dictionary:
	last_operation = "detach_all_generated_zones"
	var before: Array = attached_zone_ids()
	for zone_value in before:
		detach_zone_scene(int(zone_value))
	last_operation = "detach_all_generated_zones"
	last_zone_id = -1
	last_error = ""
	last_result = _result(true, {
		"detached_zones": before,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
	})
	_log(last_result)
	return last_result


func has_attached_zone(znum: int) -> bool:
	if not attached_zones.has(znum):
		return false
	var node: Node = attached_zones[znum] as Node
	if node == null or not is_instance_valid(node):
		attached_zones.erase(znum)
		return false
	return true


func attached_zone_ids() -> Array:
	var out: Array = []
	var keys: Array = attached_zones.keys()
	for key in keys:
		var znum: int = int(key)
		if has_attached_zone(znum):
			out.append(znum)
	out.sort()
	return out


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"manifest_path": manifest_path,
		"host_valid": host_node != null and is_instance_valid(host_node),
		"bridge_root_present": bridge_root != null and is_instance_valid(bridge_root),
		"bridge_root_name": BRIDGE_ROOT_NAME,
		"attached_zones": attached_zone_ids(),
		"attached_zone_count": attached_zone_ids().size(),
		"last_operation": last_operation,
		"last_zone_id": last_zone_id,
		"last_error": last_error,
		"last_result": _strip_runtime_objects(last_result),
		"event_log_size": event_log.size(),
	}


func _ensure_loader() -> RefCounted:
	if loader == null:
		loader = DaocGeneratedZoneSceneLoaderScript.new()
	return loader


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
	root.set_meta("p1_16a9_runtime_bridge_root", true)
	host.add_child(root)
	bridge_root = root
	return bridge_root


func _branch_report(root: Node) -> Dictionary:
	var present: Array = []
	var missing: Array = []
	if root == null:
		return {"present_branches": present, "missing_branches": REQUIRED_BRANCHES.duplicate(), "branch_count": 0}
	for branch_value in REQUIRED_BRANCHES:
		var branch_name: String = str(branch_value)
		if root.get_node_or_null(NodePath(branch_name)) != null:
			present.append(branch_name)
		else:
			missing.append(branch_name)
	return {"present_branches": present, "missing_branches": missing, "branch_count": present.size()}


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
