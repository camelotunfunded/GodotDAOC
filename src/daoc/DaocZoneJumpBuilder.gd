extends RefCounted
class_name DaocZoneJumpBuilder

const DaocZoneJumpBuildResultScript = preload("res://src/daoc/DaocZoneJumpBuildResult.gd")

## P1-14A: builder statique du domaine zonejump.
## Il ne lit pas ZoneViewer, ne parente rien dans la scène active et ne connecte aucun signal.

static func build(zone_num: int, jump_entries: Array, xform: Object) -> DaocZoneJumpBuildResult:
	var result: DaocZoneJumpBuildResult = DaocZoneJumpBuildResultScript.new()
	var root := Node3D.new()
	root.name = "Zone%03d_ZoneJumps" % zone_num
	var areas: Array[Area3D] = []
	var index: Array = []
	var targets := 0
	var world_scale := _xform_float(xform, "world_scale", 1.0)
	var height_exaggeration := _xform_float(xform, "height_exaggeration", 1.0)
	var thickness_raw := _xform_float(xform, "zonejump_thickness_raw", 60.0)
	var debug_visible := _xform_bool(xform, "zonejump_debug_visible", false)
	var area_enabled := _xform_bool(xform, "zonejump_area_enabled", true)

	for i in range(jump_entries.size()):
		var entry: Dictionary = jump_entries[i] as Dictionary
		var built: Dictionary = _build_area(zone_num, entry, i, xform, world_scale, height_exaggeration, thickness_raw, debug_visible, area_enabled)
		var area: Area3D = built.get("area", null) as Area3D
		var idx: Dictionary = built.get("index", {}) as Dictionary
		if area == null or idx.is_empty():
			continue
		root.add_child(area)
		areas.append(area)
		index.append(idx)
		if int(idx.get("target_zone", -1)) >= 0:
			targets += 1

	var pack_probe := PackedScene.new()
	var packable_ok := pack_probe.pack(root) == OK
	result.root = root
	result.areas = areas
	result.static_index = index
	result.metrics = {
		"zone": zone_num,
		"entries": jump_entries.size(),
		"targets": targets,
		"areas": areas.size(),
		"packable_ok": packable_ok,
	}
	result.index_signature = compute_index_signature(index)
	return result


static func dedupe_reverse_pairs(entries: Array) -> Array:
	var out: Array = []
	var seen := {}
	for item in entries:
		var e: Dictionary = item as Dictionary
		var a: Vector2 = e.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = e.get("b", Vector2.ZERO) as Vector2
		var key_a := "%d,%d" % [int(round(a.x)), int(round(a.y))]
		var key_b := "%d,%d" % [int(round(b.x)), int(round(b.y))]
		var ordered := key_a.naturalnocasecmp_to(key_b) <= 0
		var first_key := key_a if ordered else key_b
		var second_key := key_b if ordered else key_a
		var key := "%s|%s|%s|%s" % [str(e.get("name", "")), str(e.get("target", "")), first_key, second_key]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(e)
	return out


static func compute_index_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append(_canonical_row(d))
	rows.sort()
	var canonical := "\n".join(rows)
	return canonical.md5_text()


static func _build_area(zone_num: int, entry: Dictionary, idx: int, xform: Object, world_scale: float, height_exaggeration: float, thickness_raw: float, debug_visible: bool, area_enabled: bool) -> Dictionary:
	var a: Vector2 = entry.get("a", Vector2.ZERO) as Vector2
	var b: Vector2 = entry.get("b", Vector2.ZERO) as Vector2
	var d := b - a
	var length := d.length()
	if length <= 1.0:
		return {}
	var z0 := float(entry.get("z_min", 0.0))
	var z1 := float(entry.get("z_max", z0 + 100.0))
	if z1 < z0:
		var t := z0
		z0 = z1
		z1 = t
	if z1 <= z0 + 1.0:
		z1 = z0 + 100.0
	var mid := (a + b) * 0.5
	var area_id := "%03d:%04d:%03d" % [zone_num, int(entry.get("id", idx + 1)), idx]
	var target := int(entry.get("target", -1))
	var area := Area3D.new()
	area.name = _node_name(entry, idx)
	area.monitoring = area_enabled
	area.monitorable = false
	area.position = _xform_daoc_to_godot(xform, zone_num, mid.x, mid.y, z0 + (z1 - z0) * 0.5)
	area.rotation.y = atan2(d.y, d.x)
	area.set_meta("daoc_zonejump", true)
	area.set_meta("daoc_zonejump_area_id", area_id)
	area.set_meta("zone", zone_num)
	area.set_meta("id", int(entry.get("id", idx + 1)))
	area.set_meta("name", str(entry.get("name", "")))
	area.set_meta("target", target)
	area.set_meta("extra1", str(entry.get("extra1", "")))
	area.set_meta("extra2", str(entry.get("extra2", "")))
	area.set_meta("source", str(entry.get("source", "")))
	area.set_meta("raw_a", a)
	area.set_meta("raw_b", b)
	area.set_meta("center", mid)
	area.set_meta("radius", thickness_raw * 0.5)
	area.set_meta("z_min", z0)
	area.set_meta("z_max", z1)

	var shape := BoxShape3D.new()
	shape.size = Vector3(
		length * world_scale,
		(z1 - z0) * world_scale * height_exaggeration,
		thickness_raw * world_scale
	)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	area.add_child(cs)

	if debug_visible:
		var mi := MeshInstance3D.new()
		mi.name = "DebugZoneJump"
		var bm := BoxMesh.new()
		bm.size = shape.size
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.7, 1.0, 0.22)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		area.add_child(mi)

	var index_entry := {
		"area_id": area_id,
		"index": idx,
		"id": int(entry.get("id", idx + 1)),
		"source_zone": zone_num,
		"zone": zone_num,
		"target_zone": target,
		"target": target,
		"name": str(entry.get("name", "")),
		"center_x": mid.x,
		"center_y": mid.y,
		"center": mid,
		"radius": thickness_raw * 0.5,
		"z_min": z0,
		"z_max": z1,
		"a": a,
		"b": b,
		"length": length,
		"extra1": str(entry.get("extra1", "")),
		"extra2": str(entry.get("extra2", "")),
		"source": str(entry.get("source", "")),
	}
	return {"area": area, "index": index_entry}


static func _node_name(entry: Dictionary, idx: int) -> String:
	var id := int(entry.get("id", idx + 1))
	var label := str(entry.get("name", "jump")).strip_edges()
	if label == "":
		label = "jump"
	label = label.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var target := int(entry.get("target", -1))
	if target >= 0:
		return "jump_%03d_%s_to_%03d" % [id, label, target]
	return "jump_%03d_%s_no_target" % [id, label]


static func _canonical_row(d: Dictionary) -> String:
	return "%06d|%03d|%03d|%s|%s|%s|%s|%s" % [
		int(d.get("id", -1)),
		int(d.get("source_zone", -1)),
		int(d.get("target_zone", -1)),
		_fmt_float(float(d.get("center_x", 0.0))),
		_fmt_float(float(d.get("center_y", 0.0))),
		_fmt_float(float(d.get("radius", 0.0))),
		_fmt_float(float(d.get("z_min", 0.0))),
		_fmt_float(float(d.get("z_max", 0.0))),
	]


static func _fmt_float(v: float) -> String:
	return "%.3f" % v


static func _xform_float(xform: Object, property_name: String, default_value: float) -> float:
	if xform == null:
		return default_value
	var v: Variant = xform.get(property_name)
	if v == null:
		return default_value
	return float(v)


static func _xform_bool(xform: Object, property_name: String, default_value: bool) -> bool:
	if xform == null:
		return default_value
	var v: Variant = xform.get(property_name)
	if v == null:
		return default_value
	return bool(v)


static func _xform_daoc_to_godot(xform: Object, zone_num: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	if xform != null and xform.has_method("daoc_to_godot"):
		var value: Variant = xform.call("daoc_to_godot", zone_num, daoc_x, daoc_y, daoc_z)
		if value is Vector3:
			return value as Vector3
	return Vector3(daoc_x, daoc_z, daoc_y)
