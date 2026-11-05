extends RefCounted
class_name DaocCollisionBuilder

const DaocCollisionBuildResultScript = preload("res://src/daoc/DaocCollisionBuildResult.gd")
const NifCollisionMeshScript = preload("res://src/daoc/DaocNifCollisionMesh.gd")
const MISSING_INT: int = -2147483648

## P1-14C: builder statique du domaine collisions locales.
## Il reçoit les données déjà disponibles, ne lit pas ZoneViewer, ne parente rien,
## et retourne des nodes packables + index DAoC bruts.

static func build_boundary(zone_num: int, segments: Array, origin3: Vector3, settings: Dictionary) -> DaocCollisionBuildResult:
	var result: DaocCollisionBuildResult = DaocCollisionBuildResultScript.new()
	result.source_path = str(settings.get("source_path", ""))
	var root := Node3D.new()
	root.name = "Zone%03d_BoundCollision" % zone_num
	result.root = root
	result.boundary_root = root
	var static_index: Array = []
	var bodies: Array[StaticBody3D] = []
	for i in segments.size():
		var seg: Dictionary = segments[i] as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		var idx := _boundary_index_row(zone_num, i, a, b, result.source_path)
		static_index.append(idx)
		if bool(settings.get("build_bound_collision", true)):
			var body := _make_bound_segment_collision(zone_num, idx, origin3, settings)
			if body != null:
				root.add_child(body)
				bodies.append(body)
	var pack_probe := PackedScene.new()
	var packable_ok := pack_probe.pack(root) == OK
	result.boundary_segments = static_index
	result.boundary_bodies = bodies
	result.metrics = {
		"zone": zone_num,
		"boundary_segments": static_index.size(),
		"boundary_bodies": bodies.size(),
		"prop_bodies": 0,
		"packable_ok": packable_ok,
	}
	result.boundary_index_signature = compute_boundary_signature(static_index)
	return result


static func build_prop_aabb(zone_num: int, fx: Dictionary, filename: String, template_root: Node, pos: Vector3, yaw_rad: float, placed_scale: float, origin3: Vector3, settings: Dictionary) -> Dictionary:
	var aabb := template_local_aabb(template_root)
	if aabb.size.x <= 0.001 or aabb.size.y <= 0.001 or aabb.size.z <= 0.001:
		return {"ok": false, "reason": "empty_aabb"}
	var body := StaticBody3D.new()
	body.name = "prop_%d_%s" % [int(fx.get("id", 0)), filename.get_basename()]
	body.collision_layer = int(settings.get("prop_collision_layer", 4))
	body.collision_mask = int(settings.get("prop_collision_mask", 0))
	body.transform = Transform3D(Basis(Vector3.UP, yaw_rad), pos)
	body.set_meta("daoc_zone", zone_num)
	body.set_meta("daoc_fixture_id", int(fx.get("id", 0)))
	body.set_meta("daoc_nif_id", int(fx.get("nif", -1)))
	body.set_meta("daoc_file", filename)
	body.set_meta("daoc_collision_source", "fixture_collide_aabb_p1_14c")
	body.add_to_group("daoc_prop_collision")
	var collision_size := Vector3(
		aabb.size.x * placed_scale * float(settings.get("prop_collision_size_scale_xz", 0.72)),
		aabb.size.y * placed_scale * float(settings.get("prop_collision_size_scale_y", 0.90)),
		aabb.size.z * placed_scale * float(settings.get("prop_collision_size_scale_xz", 0.72))
	)
	var collision_center := aabb.get_center() * placed_scale
	var low_name := filename.get_basename().to_lower()
	# P1-133 — d'abord la collision que le NIF déclare (branche collidee) : murs
	# avec leur porte, planchers, marches, tablier de pont. Les boîtes ci-dessous
	# ne restent qu'en repli pour un NIF sans branche de collision.
	var nif_faces := PackedVector3Array()
	if bool(settings.get("prop_collision_use_nif_mesh", true)) and template_root != null:
		nif_faces = NifCollisionMeshScript.faces_for_nif(str(template_root.get_meta("daoc_nif_abs_path", "")))
	if nif_faces.size() >= 3:
		var scaled := PackedVector3Array()
		scaled.resize(nif_faces.size())
		for i in nif_faces.size():
			scaled[i] = nif_faces[i] * placed_scale
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(scaled)
		var cs_mesh := CollisionShape3D.new()
		cs_mesh.name = "NifCollidee"
		cs_mesh.shape = concave
		body.add_child(cs_mesh)
		body.set_meta("daoc_collision_source", "nif_collidee_p1_133")
		body.set_meta("daoc_collision_trimesh", true)
		var runtime_mesh_item := _prop_runtime_item(zone_num, fx, filename, body, origin3, settings)
		return {"ok": true, "body": body, "runtime_item": runtime_mesh_item, "trimesh": true, "faces": scaled.size() / 3}
	if _is_bridge_name(low_name):
		_build_bridge_collision(body, collision_center, collision_size)
	elif _is_hollow_architecture_name(low_name):
		_build_hollow_architecture_collision(body, collision_center, collision_size)
	else:
		_add_box_shape(body, "CollisionShape3D", collision_center, collision_size)
	if bool(settings.get("prop_collision_debug_visible", false)):
		var mi := MeshInstance3D.new()
		mi.name = "DebugAABB"
		var bm := BoxMesh.new()
		bm.size = collision_size
		mi.mesh = bm
		mi.position = collision_center
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.85, 1.0, 0.22)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		body.add_child(mi)
	var runtime_item := _prop_runtime_item(zone_num, fx, filename, body, origin3, settings)
	return {"ok": true, "body": body, "runtime_item": runtime_item}


static func _is_bridge_name(low_name: String) -> bool:
	return low_name.contains("bridge") or low_name.contains("pont")


static func _is_hollow_architecture_name(low_name: String) -> bool:
	for token in ["house", "keep", "tavern", "inn", "hut", "gate", "arch"]:
		if low_name.contains(token):
			return true
	return false


static func _add_box_shape(body: StaticBody3D, shape_name: String, center: Vector3, size: Vector3) -> void:
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = shape_name
	cs.shape = shape
	cs.position = center
	body.add_child(cs)


## Une maison n'est pas une boîte pleine : quatre murs minces, avec une vraie
## ouverture centrale sur la façade. La porte animée reste une fixture séparée
## et décide elle-même si cette ouverture est fermée ou praticable.
static func _build_hollow_architecture_collision(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var thickness := maxf(12.0, minf(minf(size.x, size.z) * 0.10, 90.0))
	var door_width := clampf(size.x * 0.24, 70.0, size.x * 0.46)
	var side_width := maxf((size.x - door_width) * 0.5, thickness)
	var front_z := center.z - size.z * 0.5 + thickness * 0.5
	var back_z := center.z + size.z * 0.5 - thickness * 0.5
	var left_x := center.x - size.x * 0.5 + thickness * 0.5
	var right_x := center.x + size.x * 0.5 - thickness * 0.5
	_add_box_shape(body, "WallBack", Vector3(center.x, center.y, back_z), Vector3(size.x, size.y, thickness))
	_add_box_shape(body, "WallLeft", Vector3(left_x, center.y, center.z), Vector3(thickness, size.y, size.z))
	_add_box_shape(body, "WallRight", Vector3(right_x, center.y, center.z), Vector3(thickness, size.y, size.z))
	_add_box_shape(body, "WallFrontLeft", Vector3(center.x - door_width * 0.5 - side_width * 0.5, center.y, front_z), Vector3(side_width, size.y, thickness))
	_add_box_shape(body, "WallFrontRight", Vector3(center.x + door_width * 0.5 + side_width * 0.5, center.y, front_z), Vector3(side_width, size.y, thickness))


## Un pont porte le joueur sur son tablier au lieu de dresser un volume plein.
static func _build_bridge_collision(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var deck_height := clampf(size.y * 0.10, 10.0, 45.0)
	var deck_y := center.y - size.y * 0.5 + deck_height * 0.5
	_add_box_shape(body, "BridgeDeck", Vector3(center.x, deck_y, center.z), Vector3(size.x, deck_height, size.z))
	var rail_width := maxf(8.0, minf(size.x, size.z) * 0.035)
	var rail_height := clampf(size.y * 0.30, 35.0, 120.0)
	_add_box_shape(body, "BridgeRailLeft", Vector3(center.x - size.x * 0.5 + rail_width * 0.5, deck_y + rail_height * 0.5, center.z), Vector3(rail_width, rail_height, size.z))
	_add_box_shape(body, "BridgeRailRight", Vector3(center.x + size.x * 0.5 - rail_width * 0.5, deck_y + rail_height * 0.5, center.z), Vector3(rail_width, rail_height, size.z))


static func parse_bound_csv(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cols := line.split(",", false)
		if cols.size() < 4:
			continue
		var closed := int(float(cols[0].strip_edges())) != 0
		var point_count := int(float(cols[1].strip_edges()))
		if point_count < 1 or point_count > 98:
			continue
		if cols.size() < 2 + point_count * 2:
			continue
		var points: Array[Vector2] = []
		for i in point_count:
			var x := float(cols[2 + i * 2].strip_edges())
			var y := float(cols[3 + i * 2].strip_edges())
			points.append(Vector2(x, y))
		if closed and points.size() > 1:
			points.append(points[0])
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			if a.distance_squared_to(b) > 1.0:
				out.append({"a": a, "b": b})
	f.close()
	return out


static func parse_fixture_collide_table(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header: PackedStringArray = PackedStringArray()
	var id_idx := -1
	var collide_idx := -1
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cols := line.split(",", true)
		if header.is_empty():
			var has_text := false
			for c in cols:
				var ct := str(c).strip_edges()
				if ct != "" and not ct.is_valid_float():
					has_text = true
					break
			if has_text:
				header = cols
				for i in header.size():
					var name := str(header[i]).strip_edges().to_lower()
					if id_idx < 0 and (name == "id" or name == "fixture" or name == "fixture_id" or name == "fixtureid"):
						id_idx = i
					if collide_idx < 0 and (name == "collide" or name == "collision" or name == "collides"):
						collide_idx = i
				continue
			break
		if id_idx < 0 or collide_idx < 0 or cols.size() <= max(id_idx, collide_idx):
			continue
		var id_text := str(cols[id_idx]).strip_edges()
		if not id_text.is_valid_float():
			continue
		var fid := int(float(id_text))
		out[fid] = variant_to_int_flag(cols[collide_idx])
	f.close()
	return out


static func prop_collision_decision(fx: Dictionary, filename: String, fixture_table: Dictionary, settings: Dictionary) -> Dictionary:
	if filename == "":
		return {"wants": false, "reason": "missing_filename"}
	if is_prop_collision_excluded_by_name(filename, settings):
		return {"wants": false, "reason": "excluded_by_name"}
	var direct_flag := fixture_collide_flag(fx)
	if direct_flag != MISSING_INT:
		return {"wants": direct_flag != 0, "reason": "flag_direct" if direct_flag != 0 else "flag_zero"}
	var fixture_id: int = int(fx.get("id", fx.get("ID", -1)))
	if fixture_id >= 0 and fixture_table.has(fixture_id):
		var csv_flag := int(fixture_table[fixture_id])
		return {"wants": csv_flag != 0, "reason": "flag_csv" if csv_flag != 0 else "flag_zero"}
	if bool(settings.get("prop_collision_fallback_when_flag_missing", true)):
		return {"wants": true, "reason": "missing_flag_fallback"}
	return {"wants": false, "reason": "missing_flag_no_fallback"}


static func fixture_collide_flag(fx: Dictionary) -> int:
	var keys: Array[String] = ["collide", "Collide", "COLLIDE", "collision", "Collision", "COLLISION", "collides", "Collides"]
	for key in keys:
		if fx.has(key):
			return variant_to_int_flag(fx.get(key, 0))
	return MISSING_INT


static func variant_to_int_flag(v: Variant) -> int:
	if typeof(v) == TYPE_BOOL:
		return 1 if bool(v) else 0
	var text := str(v).strip_edges()
	if text.is_valid_float():
		return int(float(text))
	return 0


static func is_prop_collision_excluded_by_name(filename: String, settings: Dictionary) -> bool:
	var low := filename.get_basename().to_lower()
	var exacts: PackedStringArray = settings.get("prop_collision_excluded_exact_names", PackedStringArray()) as PackedStringArray
	for exact_name in exacts:
		var exact := str(exact_name).strip_edges().to_lower()
		if exact != "" and low == exact:
			return true
	var tokens: PackedStringArray = settings.get("prop_collision_excluded_name_tokens", PackedStringArray()) as PackedStringArray
	for token in tokens:
		var t := str(token).strip_edges().to_lower()
		if t != "" and low.find(t) != -1:
			return true
	return false


static func compute_boundary_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append("%03d:%04d:%.2f:%.2f:%.2f:%.2f" % [int(d.get("zone", -1)), int(d.get("index", -1)), float(d.get("ax", 0.0)), float(d.get("ay", 0.0)), float(d.get("bx", 0.0)), float(d.get("by", 0.0))])
	rows.sort()
	return "\n".join(rows).md5_text()


static func compute_prop_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append("%03d:%d:%d:%s:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f" % [int(d.get("zone", -1)), int(d.get("fixture_id", -1)), int(d.get("nif_id", -1)), str(d.get("file", "")), float((d.get("daoc_min", Vector3.ZERO) as Vector3).x), float((d.get("daoc_min", Vector3.ZERO) as Vector3).y), float((d.get("daoc_min", Vector3.ZERO) as Vector3).z), float((d.get("daoc_max", Vector3.ZERO) as Vector3).x), float((d.get("daoc_max", Vector3.ZERO) as Vector3).y), float((d.get("daoc_max", Vector3.ZERO) as Vector3).z)])
	rows.sort()
	return "\n".join(rows).md5_text()


static func template_local_aabb(root: Node) -> AABB:
	var has_aabb := false
	var out := AABB()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := transformed_aabb(mi.mesh.get_aabb(), mi.transform)
		if not has_aabb:
			out = local
			has_aabb = true
		else:
			out = out.merge(local)
	return out if has_aabb else AABB()


static func transformed_aabb(aabb: AABB, xf: Transform3D) -> AABB:
	var has_point := false
	var out := AABB()
	var p := aabb.position
	var s := aabb.size
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var corner := p + Vector3(s.x * x, s.y * y, s.z * z)
				var tp := xf * corner
				if not has_point:
					out = AABB(tp, Vector3.ZERO)
					has_point = true
				else:
					out = out.expand(tp)
	return out


static func _make_bound_segment_collision(zone_num: int, idx: Dictionary, origin3: Vector3, settings: Dictionary) -> StaticBody3D:
	var a := Vector2(float(idx.get("ax", 0.0)), float(idx.get("ay", 0.0)))
	var b := Vector2(float(idx.get("bx", 0.0)), float(idx.get("by", 0.0)))
	var d := b - a
	var length := d.length()
	if length <= 1.0:
		return null
	var mid := (a + b) * 0.5
	var floor_a := _sample_height_from_settings(settings, a.x, a.y)
	var floor_b := _sample_height_from_settings(settings, b.x, b.y)
	var floor_mid := _sample_height_from_settings(settings, mid.x, mid.y)
	var bottom := minf(minf(floor_a, floor_b), floor_mid) + float(settings.get("bound_collision_bottom_offset_raw", -1000.0))
	var top := maxf(maxf(floor_a, floor_b), floor_mid) + float(settings.get("bound_collision_top_offset_raw", 3000.0))
	if top <= bottom + 1.0:
		top = bottom + 100.0
	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	var body := StaticBody3D.new()
	body.name = "bound_segment_%03d" % int(idx.get("index", 0))
	body.collision_layer = int(settings.get("bound_collision_layer", 1))
	body.collision_mask = int(settings.get("bound_collision_mask", 0))
	body.position = origin3 + Vector3(mid.x * world_scale, (bottom + (top - bottom) * 0.5) * world_scale * height_exaggeration, mid.y * world_scale)
	body.rotation.y = atan2(d.y, d.x)
	body.set_meta("daoc_zone", zone_num)
	body.set_meta("daoc_collision_source", "bound_csv_p1_14c")
	body.set_meta("daoc_bound_index", int(idx.get("index", 0)))
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		length * world_scale,
		(top - bottom) * world_scale * height_exaggeration,
		float(settings.get("bound_collision_thickness_raw", 90.0)) * world_scale
	)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	body.add_child(cs)
	if bool(settings.get("bound_collision_debug_visible", false)):
		var mi := MeshInstance3D.new()
		mi.name = "DebugBox"
		var bm := BoxMesh.new()
		bm.size = shape.size
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.25, 0.05, 0.28)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		body.add_child(mi)
	return body


static func _boundary_index_row(zone_num: int, idx: int, a: Vector2, b: Vector2, source_path: String) -> Dictionary:
	return {
		"source_zone": zone_num,
		"zone": zone_num,
		"index": idx,
		"a": a,
		"b": b,
		"ax": a.x,
		"ay": a.y,
		"bx": b.x,
		"by": b.y,
		"source": source_path,
	}


static func _prop_runtime_item(zone_num: int, fx: Dictionary, filename: String, body: StaticBody3D, origin3: Vector3, settings: Dictionary) -> Dictionary:
	var daoc_min := Vector3.ZERO
	var daoc_max := Vector3.ZERO
	var has_daoc_aabb := false
	var combined_local := AABB()
	var first_shape := true
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		var local_box := AABB()
		if cs.shape is BoxShape3D:
			var box := cs.shape as BoxShape3D
			local_box = AABB(cs.position - box.size * 0.5, box.size)
		elif cs.shape is ConcavePolygonShape3D:
			var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
			if faces.is_empty():
				continue
			local_box = AABB(faces[0], Vector3.ZERO)
			for v in faces:
				local_box = local_box.expand(v)
			local_box.position += cs.position
		else:
			continue
		combined_local = local_box if first_shape else combined_local.merge(local_box)
		first_shape = false
	if not first_shape:
		var world_box := transformed_aabb(combined_local, body.transform)
		var sx := maxf(float(settings.get("world_scale", 1.0)), 0.00001)
		var sy := maxf(float(settings.get("world_scale", 1.0)) * float(settings.get("height_exaggeration", 1.0)), 0.00001)
		daoc_min = Vector3(
			(world_box.position.x - origin3.x) / sx,
			(world_box.position.z - origin3.z) / sx,
			(world_box.position.y - origin3.y) / sy
		)
		daoc_max = Vector3(
			(world_box.end.x - origin3.x) / sx,
			(world_box.end.z - origin3.z) / sx,
			(world_box.end.y - origin3.y) / sy
		)
		has_daoc_aabb = true
	return {
		"source_zone": zone_num,
		"zone": zone_num,
		"fixture_id": int(fx.get("id", 0)),
		"nif_id": int(fx.get("nif", -1)),
		"file": filename,
		"body": body,
		"has_daoc_aabb": has_daoc_aabb,
		"daoc_min": daoc_min,
		"daoc_max": daoc_max,
		"sample_x": (daoc_min.x + daoc_max.x) * 0.5,
		"sample_y": (daoc_min.y + daoc_max.y) * 0.5,
		"sample_z": daoc_min.z,
		"sample_height": maxf(1.0, daoc_max.z - daoc_min.z),
		# P1-133 : maillage NIF -> le solveur tire des rayons contre le corps au
		# lieu de refuser toute l'AABB (qui fermait portes et ponts).
		"trimesh": bool(body.get_meta("daoc_collision_trimesh", false)),
		"origin3": origin3,
		"sx": maxf(float(settings.get("world_scale", 1.0)), 0.00001),
		"sy": maxf(float(settings.get("world_scale", 1.0)) * float(settings.get("height_exaggeration", 1.0)), 0.00001),
	}


static func _sample_height_from_settings(settings: Dictionary, wx: float, wy: float) -> float:
	var hb: PackedByteArray = settings.get("hb", PackedByteArray()) as PackedByteArray
	var res := int(settings.get("res", 0))
	if hb.is_empty() or res <= 0:
		return 0.0
	var fx: float = clampf(wx / 65536.0 * res - 0.5, 0.0, res - 1.0)
	var fy: float = clampf(wy / 65536.0 * res - 0.5, 0.0, res - 1.0)
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var x1: int = min(x0 + 1, res - 1)
	var y1: int = min(y0 + 1, res - 1)
	var dx: float = fx - x0
	var dy: float = fy - y0
	var i00: int = (y0 * res + x0) * 2
	var i10: int = (y0 * res + x1) * 2
	var i01: int = (y1 * res + x0) * 2
	var i11: int = (y1 * res + x1) * 2
	var h00: float = float(hb[i00] | (hb[i00 + 1] << 8))
	var h10: float = float(hb[i10] | (hb[i10 + 1] << 8))
	var h01: float = float(hb[i01] | (hb[i01 + 1] << 8))
	var h11: float = float(hb[i11] | (hb[i11 + 1] << 8))
	return (h00 * (1 - dx) * (1 - dy) + h10 * dx * (1 - dy)
		+ h01 * (1 - dx) * dy + h11 * dx * dy)
