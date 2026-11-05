extends RefCounted
class_name DaocPropBuilder

const DaocPropBuildResultScript = preload("res://src/daoc/DaocPropBuildResult.gd")
const SpeedTreeBatches = preload("res://src/daoc/vegetation/DaocSpeedTreeBatches.gd")
const MeshWindingFix = preload("res://src/daoc/assets/DaocMeshWindingFix.gd")

## P1-14D: builder statique des props visibles.
## Il reçoit des entrées déjà préparées par ZoneViewer (résolution modèle/NIF + hauteur).
## Il ne lit pas le viewer, ne connecte aucun signal, ne produit pas les collisions props
## et ne stocke aucun callable dans l'index.

static func build(zone_num: int, prepared_entries: Array, settings: Dictionary = {}) -> DaocPropBuildResult:
	var result: DaocPropBuildResult = DaocPropBuildResultScript.new()
	result.placement_path = str(settings.get("placement_path", ""))
	var root := Node3D.new()
	root.name = "Zone%03d_Fixtures" % zone_num
	result.root = root

	var mark_missing := bool(settings.get("mark_missing", true))
	var missing_box := _missing_marker_mesh(float(settings.get("world_scale", 1.0)))
	var mm_missing: MultiMesh = null
	if mark_missing:
		mm_missing = MultiMesh.new()
		mm_missing.transform_format = MultiMesh.TRANSFORM_3D
		mm_missing.mesh = missing_box
		mm_missing.instance_count = prepared_entries.size()
	var miss_i := 0
	var placed := 0
	var missing := 0
	var nodes: Array[Node3D] = []
	var static_index: Array = []
	var trees: RefCounted = null
	if bool(settings.get("speedtree_enabled", false)):
		trees = SpeedTreeBatches.new()
		trees.configure(str(settings.get("daoc_client_root", "")), settings)

	for raw_entry in prepared_entries:
		var entry: Dictionary = raw_entry as Dictionary
		if trees != null and trees.try_add(entry):
			placed += 1
			static_index.append(_index_from_entry(zone_num, entry, true, false))
			continue
		var template: Variant = entry.get("template", null)
		var is_missing := bool(entry.get("missing", false)) or template == null or not (template is Node)
		if is_missing:
			missing += 1
			if mm_missing != null:
				var marker_xform: Transform3D = entry.get("marker_transform", Transform3D()) as Transform3D
				mm_missing.set_instance_transform(miss_i, marker_xform)
				miss_i += 1
			static_index.append(_index_from_entry(zone_num, entry, false, true))
			continue

		var source_node: Node = template as Node
		# Corrige le gabarit AVANT de le dupliquer : les duplicata partagent ses
		# maillages, donc chaque modele est retourne une fois pour toute la zone.
		MeshWindingFix.apply(source_node)
		var inst_node: Node = source_node.duplicate()
		var inst: Node3D = inst_node as Node3D
		if inst == null:
			missing += 1
			static_index.append(_index_from_entry(zone_num, entry, false, true))
			continue
		inst.transform = entry.get("transform", Transform3D()) as Transform3D
		inst.name = str(entry.get("node_name", "f%d_%s" % [int(entry.get("fixture_id", 0)), str(entry.get("file", "prop")).get_basename()]))
		inst.set_meta("daoc_prop_14d", true)
		inst.set_meta("daoc_zone", zone_num)
		inst.set_meta("fixture_id", int(entry.get("fixture_id", 0)))
		inst.set_meta("nif_id", int(entry.get("nif_id", -1)))
		inst.set_meta("source_file", str(entry.get("file", "")))
		# P1-115 : chaque porte du modele recoit son identifiant serveur,
		# zone x 1 000 000 + fixture x 100 + piece (DoorRequestHandler).
		for door in inst.find_children("door_*", "MeshInstance3D", true, false):
			var door_id := int(door.get_meta("daoc_door_absolute_id", 0))
			if door_id <= 0 and door.has_meta("daoc_door_piece"):
				door_id = zone_num * 1000000 + int(entry.get("fixture_id", 0)) * 100 + int(door.get_meta("daoc_door_piece"))
			if door_id > 0:
				door.set_meta("daoc_door_id", door_id)
		root.add_child(inst)
		nodes.append(inst)
		placed += 1
		static_index.append(_index_from_entry(zone_num, entry, true, false))

	if mm_missing != null and miss_i > 0:
		mm_missing.instance_count = miss_i
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MissingModelMarkers"
		mmi.multimesh = mm_missing
		var fmm := StandardMaterial3D.new()
		fmm.albedo_color = Color(0.9, 0.15, 0.15)
		mmi.material_override = fmm
		root.add_child(mmi)
	elif mm_missing != null:
		mm_missing.instance_count = 0

	var pack_probe := PackedScene.new()
	var tree_batches: int = trees.finish(root) if trees != null else 0
	var packable_ok := pack_probe.pack(root) == OK
	result.prop_nodes = nodes
	result.static_index = static_index
	result.metrics = {
		"zone": zone_num,
		"fixtures": prepared_entries.size(),
		"placed": placed,
		"missing": missing,
		"nodes": nodes.size(),
		"missing_markers": miss_i,
		"packable_ok": packable_ok,
		"speedtree_instances": trees.count if trees != null else 0,
		"speedtree_batches": tree_batches,
		"speedtree_fallbacks": trees.fallback_count if trees != null else 0,
	}
	result.index_signature = compute_index_signature(static_index)
	return result


static func compute_index_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append(_canonical_row(d))
	rows.sort()
	return "\n".join(rows).md5_text()


static func _index_from_entry(zone_num: int, entry: Dictionary, placed: bool, missing: bool) -> Dictionary:
	var p: Vector3 = entry.get("position", Vector3.ZERO) as Vector3
	return {
		"fixture_id": int(entry.get("fixture_id", 0)),
		"id": int(entry.get("fixture_id", 0)),
		"source_zone": zone_num,
		"zone": zone_num,
		"nif_id": int(entry.get("nif_id", -1)),
		"file": str(entry.get("file", "")),
		"x": float(entry.get("x", 0.0)),
		"y": float(entry.get("y", 0.0)),
		"z": float(entry.get("z", 0.0)),
		"a": float(entry.get("a", 0.0)),
		"scale": float(entry.get("scale", 1.0)),
		"ground": int(entry.get("ground", 0)),
		"placed": placed,
		"missing": missing,
		"node_name": str(entry.get("node_name", "")),
		"position_x": p.x,
		"position_y": p.y,
		"position_z": p.z,
		"source": str(entry.get("source", "")),
	}


static func _missing_marker_mesh(world_scale: float) -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 200.0 * world_scale
	return box


static func _canonical_row(d: Dictionary) -> String:
	return "%03d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		int(d.get("source_zone", -1)),
		int(d.get("fixture_id", 0)),
		int(d.get("nif_id", -1)),
		str(d.get("file", "")),
		_fmt_float(float(d.get("x", 0.0))),
		_fmt_float(float(d.get("y", 0.0))),
		_fmt_float(float(d.get("z", 0.0))),
		_fmt_float(float(d.get("a", 0.0))),
		_fmt_float(float(d.get("scale", 1.0))),
		str(int(d.get("ground", 0))),
		"1" if bool(d.get("placed", false)) else "0",
		"1" if bool(d.get("missing", false)) else "0",
	]


static func _fmt_float(v: float) -> String:
	return "%.3f" % v
