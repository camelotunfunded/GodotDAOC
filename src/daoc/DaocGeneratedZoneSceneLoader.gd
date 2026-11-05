extends RefCounted
class_name DaocGeneratedZoneSceneLoader

## P1-16A8 — loader runtime des scènes générées par ZoneCreator.
## Lit generated/zones/manifest.json, résout les .tscn par zone, charge et instancie
## les PackedScene sans repasser par la reconstruction runtime lourde de ZoneViewer.
## Depuis P1-16A10A, ignore/refuse explicitement les familles non supportées.

const SCOPE: String = "P1-16A8 runtime load generated scenes"
const CHECKPOINT: String = "P1_16A8_RUNTIME_LOAD_GENERATED_SCENES"
const DEFAULT_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"
const EXPECTED_A7_CHECKPOINT: String = "P1_16A7_CONTROLLED_MULTI_ZONE_BATCH_MANIFEST"
const EXPECTED_SCHEMA: String = "daoc.generated_zones_manifest.v1"
const REQUIRED_BRANCHES: Array = [
	"TerrainRoot",
	"StaticPropsRoot",
	"CollisionRoot",
	"WaterRoot",
	"ZoneJumpRoot",
]

var manifest_path: String = DEFAULT_MANIFEST_PATH
var manifest: Dictionary = {}
var manifest_loaded: bool = false
var last_error: String = ""
var last_zone_id: int = -1
var last_scene_path: String = ""
var last_operation: String = ""
var last_result: Dictionary = {}
var load_log: Array = []


func load_manifest(path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	manifest_path = path
	manifest = {}
	manifest_loaded = false
	last_error = ""
	last_operation = "load_manifest"
	if not FileAccess.file_exists(path):
		last_error = "manifest missing"
		last_result = _result(false, {"path": path, "missing": true, "error": last_error})
		_log(last_result)
		return last_result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "manifest open failed: %s" % str(FileAccess.get_open_error())
		last_result = _result(false, {"path": path, "missing": false, "error": last_error})
		_log(last_result)
		return last_result
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "manifest json is not a dictionary"
		last_result = _result(false, {"path": path, "missing": false, "error": last_error, "length": text.length()})
		_log(last_result)
		return last_result
	manifest = parsed as Dictionary
	manifest_loaded = true
	last_result = _result(true, {
		"path": path,
		"missing": false,
		"schema": str(manifest.get("schema", "")),
		"checkpoint": str(manifest.get("checkpoint", "")),
		"zone_count": int(manifest.get("zone_count", 0)),
		"ok_count": int(manifest.get("ok_count", 0)),
		"fail_count": int(manifest.get("fail_count", 0)),
		"supported_count": int(manifest.get("supported_count", 0)),
		"unsupported_count": int(manifest.get("unsupported_count", 0)),
		"zones": manifest_zone_ids(),
		"exportable_zones": manifest_exportable_zone_ids(),
	})
	_log(last_result)
	return last_result


func validate_manifest(path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	var loaded: Dictionary = load_manifest(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var errors: Array = []
	var schema_value: String = str(manifest.get("schema", ""))
	var checkpoint_value: String = str(manifest.get("checkpoint", ""))
	if schema_value != EXPECTED_SCHEMA:
		errors.append("unexpected schema=%s" % schema_value)
	if checkpoint_value != EXPECTED_A7_CHECKPOINT:
		errors.append("unexpected checkpoint=%s" % checkpoint_value)
	if not bool(manifest.get("ok", false)):
		errors.append("manifest ok=false")
	if int(manifest.get("fail_count", 0)) != 0:
		errors.append("manifest fail_count=%d" % int(manifest.get("fail_count", 0)))
	var out: Dictionary = _result(errors.is_empty(), {
		"path": path,
		"schema": schema_value,
		"checkpoint": checkpoint_value,
		"manifest_ok": bool(manifest.get("ok", false)),
		"ok_count": int(manifest.get("ok_count", 0)),
		"fail_count": int(manifest.get("fail_count", 0)),
		"supported_count": int(manifest.get("supported_count", 0)),
		"unsupported_count": int(manifest.get("unsupported_count", 0)),
		"zones": manifest_zone_ids(),
		"exportable_zones": manifest_exportable_zone_ids(),
		"errors": errors,
	})
	last_operation = "validate_manifest"
	last_result = out
	_log(out)
	return out


func manifest_zone_ids() -> Array:
	var out: Array = []
	if not manifest_loaded:
		return out
	var entries_value: Variant = manifest.get("zones", [])
	if typeof(entries_value) == TYPE_ARRAY:
		var entries: Array = entries_value as Array
		for entry_value in entries:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var zone_id: int = int(entry.get("zone_id", -1))
			if zone_id >= 0 and not out.has(zone_id):
				out.append(zone_id)
	if out.is_empty():
		var exported_value: Variant = manifest.get("exported_zones", [])
		if typeof(exported_value) == TYPE_ARRAY:
			var exported: Array = exported_value as Array
			for zone_value in exported:
				var exported_zone: int = int(zone_value)
				if exported_zone >= 0 and not out.has(exported_zone):
					out.append(exported_zone)
	out.sort()
	return out


func manifest_exportable_zone_ids() -> Array:
	var out: Array = []
	if not manifest_loaded:
		return out
	var entries_value: Variant = manifest.get("zones", [])
	if typeof(entries_value) == TYPE_ARRAY:
		var entries: Array = entries_value as Array
		for entry_value in entries:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var zone_id: int = int(entry.get("zone_id", -1))
			if zone_id < 0:
				continue
			if _entry_is_generated_scene_exportable(entry) and not out.has(zone_id):
				out.append(zone_id)
	if out.is_empty():
		var exported_value: Variant = manifest.get("exported_zones", [])
		if typeof(exported_value) == TYPE_ARRAY:
			var exported: Array = exported_value as Array
			for zone_value in exported:
				var exported_zone: int = int(zone_value)
				if exported_zone >= 0 and not out.has(exported_zone):
					out.append(exported_zone)
	out.sort()
	return out


func manifest_entry_for_zone(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	if not manifest_loaded or manifest_path != path:
		load_manifest(path)
	if not manifest_loaded:
		return {}
	var entries_value: Variant = manifest.get("zones", [])
	if typeof(entries_value) != TYPE_ARRAY:
		return {}
	var entries: Array = entries_value as Array
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		if int(entry.get("zone_id", -1)) == znum:
			return entry
	return {}


func is_zone_exportable(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> bool:
	var entry: Dictionary = manifest_entry_for_zone(znum, path)
	if entry.is_empty():
		return false
	return _entry_is_generated_scene_exportable(entry)


func zone_kind_for_zone(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> String:
	var entry: Dictionary = manifest_entry_for_zone(znum, path)
	return str(entry.get("zone_kind", "unknown"))


func scene_path_for_zone(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> String:
	if not manifest_loaded or manifest_path != path:
		load_manifest(path)
	if not manifest_loaded:
		return ""
	var entries_value: Variant = manifest.get("zones", [])
	if typeof(entries_value) == TYPE_ARRAY:
		var entries: Array = entries_value as Array
		for entry_value in entries:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_value as Dictionary
			if int(entry.get("zone_id", -1)) == znum:
				return str(entry.get("scene_path", ""))
	var expected: String = "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [znum, znum]
	var paths_value: Variant = manifest.get("exported_paths", [])
	if typeof(paths_value) == TYPE_ARRAY:
		var paths: Array = paths_value as Array
		for path_value in paths:
			var candidate: String = str(path_value)
			if candidate == expected:
				return candidate
	return ""


func load_generated_zone_scene(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	last_operation = "load_generated_zone_scene"
	last_zone_id = znum
	last_scene_path = scene_path_for_zone(znum, path)
	var entry: Dictionary = manifest_entry_for_zone(znum, path)
	if not entry.is_empty() and not _entry_is_generated_scene_exportable(entry):
		last_error = "unsupported generated zone kind=%s status=%s" % [str(entry.get("zone_kind", "unknown")), str(entry.get("generated_scene_status", "unsupported_yet"))]
		last_result = _result(false, {"zone_id": znum, "scene_path": str(entry.get("scene_path", "")), "zone_kind": str(entry.get("zone_kind", "unknown")), "unsupported": true, "error": last_error})
		_log(last_result)
		return last_result
	if last_scene_path == "":
		last_error = "scene path missing for zone%03d" % znum
		last_result = _result(false, {"zone_id": znum, "scene_path": "", "error": last_error})
		_log(last_result)
		return last_result
	if not ResourceLoader.exists(last_scene_path):
		last_error = "scene file missing"
		last_result = _result(false, {"zone_id": znum, "scene_path": last_scene_path, "missing": true, "error": last_error})
		_log(last_result)
		return last_result
	var resource: Resource = ResourceLoader.load(last_scene_path)
	if resource == null or not (resource is PackedScene):
		last_error = "resource is not PackedScene"
		last_result = _result(false, {"zone_id": znum, "scene_path": last_scene_path, "missing": false, "error": last_error})
		_log(last_result)
		return last_result
	last_error = ""
	last_result = _result(true, {"zone_id": znum, "scene_path": last_scene_path, "missing": false, "packed_scene": resource})
	_log(_strip_runtime_objects(last_result))
	return last_result


func create_generated_zone_node(znum: int, path: String = DEFAULT_MANIFEST_PATH) -> Node:
	var loaded: Dictionary = load_generated_zone_scene(znum, path)
	if not bool(loaded.get("ok", false)):
		return null
	var packed: PackedScene = loaded.get("packed_scene") as PackedScene
	if packed == null:
		last_error = "PackedScene missing after load"
		return null
	var node: Node = packed.instantiate() as Node
	if node == null:
		last_error = "PackedScene instantiate returned null"
		return null
	last_operation = "create_generated_zone_node"
	last_zone_id = znum
	last_scene_path = str(loaded.get("scene_path", ""))
	last_error = ""
	return node


func instantiate_generated_zone_scene(znum: int, keep_node: bool = false, path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	last_operation = "instantiate_generated_zone_scene"
	var node: Node = create_generated_zone_node(znum, path)
	if node == null:
		last_result = _result(false, {"zone_id": znum, "scene_path": last_scene_path, "error": last_error, "instantiated": false})
		_log(last_result)
		return last_result
	var branch_report: Dictionary = _branch_report(node)
	var missing: Array = branch_report.get("missing_branches", []) as Array
	var out: Dictionary = _result(missing.is_empty(), {
		"zone_id": znum,
		"scene_path": last_scene_path,
		"root_name": node.name,
		"instantiated": true,
		"branch_count": int(branch_report.get("branch_count", 0)),
		"present_branches": branch_report.get("present_branches", []),
		"missing_branches": missing,
	})
	if keep_node:
		out["node"] = node
	else:
		node.free()
	last_result = _strip_runtime_objects(out) as Dictionary
	_log(last_result)
	return out


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"manifest_path": manifest_path,
		"manifest_loaded": manifest_loaded,
		"manifest_schema": str(manifest.get("schema", "")) if manifest_loaded else "",
		"manifest_checkpoint": str(manifest.get("checkpoint", "")) if manifest_loaded else "",
		"manifest_ok": bool(manifest.get("ok", false)) if manifest_loaded else false,
		"zones": manifest_zone_ids(),
		"exportable_zones": manifest_exportable_zone_ids(),
		"supported_count": int(manifest.get("supported_count", 0)) if manifest_loaded else 0,
		"unsupported_count": int(manifest.get("unsupported_count", 0)) if manifest_loaded else 0,
		"last_operation": last_operation,
		"last_zone_id": last_zone_id,
		"last_scene_path": last_scene_path,
		"last_error": last_error,
		"last_result": _strip_runtime_objects(last_result),
		"log_size": load_log.size(),
	}


func _branch_report(root: Node) -> Dictionary:
	var present: Array = []
	var missing: Array = []
	for branch_value in REQUIRED_BRANCHES:
		var branch_name: String = str(branch_value)
		if root.get_node_or_null(NodePath(branch_name)) != null:
			present.append(branch_name)
		else:
			missing.append(branch_name)
	return {"present_branches": present, "missing_branches": missing, "branch_count": present.size()}


func _entry_is_generated_scene_exportable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if entry.has("supported_for_generated_scene") and not bool(entry.get("supported_for_generated_scene", false)):
		return false
	if str(entry.get("generated_scene_status", "supported_generated_scene")) == "unsupported_yet":
		return false
	if str(entry.get("zone_kind", "terrain_heightmap")) != "terrain_heightmap":
		return false
	if entry.has("ok") and not bool(entry.get("ok", false)):
		return false
	return true


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
	load_log.append(_strip_runtime_objects(entry))
	if load_log.size() > 16:
		load_log.pop_front()


func _strip_runtime_objects(value: Variant) -> Variant:
	var t: int = typeof(value)
	if t == TYPE_DICTIONARY:
		var out: Dictionary = {}
		var dict: Dictionary = value as Dictionary
		for key in dict.keys():
			var item: Variant = dict[key]
			if typeof(item) == TYPE_OBJECT:
				continue
			out[key] = _strip_runtime_objects(item)
		return out
	if t == TYPE_ARRAY:
		var out_arr: Array = []
		var arr: Array = value as Array
		for item in arr:
			if typeof(item) == TYPE_OBJECT:
				continue
			out_arr.append(_strip_runtime_objects(item))
		return out_arr
	return value
