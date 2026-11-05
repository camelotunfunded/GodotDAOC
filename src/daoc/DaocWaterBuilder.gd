extends RefCounted
class_name DaocWaterBuilder

const DaocWaterBuildResultScript = preload("res://src/daoc/DaocWaterBuildResult.gd")
const DaocWaterMaterialFactoryScript = preload("res://src/daoc/water/DaocWaterMaterialFactory.gd")
const DaocWaterTextureBinderScript = preload("res://src/daoc/water/DaocWaterTextureBinder.gd")

## P1-14B: builder statique du domaine eau.
## Il reçoit SECTOR.DAT déjà parsé, ne lit pas ZoneViewer, ne parente rien,
## ne connecte aucun signal et produit nodes packables + index DAoC brut.

static func build(zone_num: int, sector: Dictionary, origin3: Vector3, settings: Dictionary) -> DaocWaterBuildResult:
	var result: DaocWaterBuildResult = DaocWaterBuildResultScript.new()
	result.sector_path = str(settings.get("sector_path", ""))
	var root := Node3D.new()
	root.name = "Zone%03d_Water" % zone_num
	result.root = root

	if sector.is_empty() or not sector.has("waterdefs"):
		result.metrics = _make_metrics(zone_num, 0, 0, 0, true)
		result.index_signature = compute_index_signature([])
		return result

	var waterdefs: Dictionary = sector.get("waterdefs", {}) as Dictionary
	var body_count := int(str(waterdefs.get("num", "0")))
	if body_count <= 0:
		result.metrics = _make_metrics(zone_num, 0, 0, 0, true)
		result.index_signature = compute_index_signature([])
		return result

	var built := 0
	var static_index: Array = []
	var meshes: Array[MeshInstance3D] = []
	for i in range(body_count):
		var section_name := "river%02d" % i
		if not sector.has(section_name):
			continue
		var body: Dictionary = sector[section_name] as Dictionary
		var mesh: ArrayMesh = _make_water_body_mesh(body, settings)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		var water_name := str(body.get("name", section_name)).strip_edges()
		if water_name == "":
			water_name = section_name
		mi.name = "%s_%s" % [section_name, _safe_node_label(water_name)]
		mi.mesh = mesh
		var material_settings := settings.duplicate(true)
		material_settings["bind_external_texture_immediately"] = false
		mi.material_override = DaocWaterMaterialFactoryScript.make_material(body, material_settings)
		# Visibilite strictement graphique : le maillage et surtout l'index brut
		# continuent d'etre construits pour DaocWaterRuntime quand la surface est cachee.
		mi.visible = bool(settings.get("water_surface_visible", true))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = origin3
		mi.set_meta("daoc_water_14b", true)
		mi.set_meta("daoc_zone", zone_num)
		mi.set_meta("daoc_water_section", section_name)
		mi.set_meta("daoc_water_type", str(body.get("type", "")))
		mi.set_meta("daoc_water_height", int(str(body.get("height", "0"))))
		mi.set_meta("daoc_water_flow", float(str(body.get("flow", "0"))))
		mi.set_meta("daoc_water_tessellation_source", int(str(body.get("tesselation", "1"))))
		mi.set_meta("daoc_water_texture_recipe", str(body.get("texture", "")))
		mi.set_meta("daoc_water_multitexture_recipe", str(body.get("multitexture", "")))
		mi.set_meta("daoc_water_source", result.sector_path)
		root.add_child(mi)
		meshes.append(mi)
		var idx := _index_from_body(zone_num, section_name, water_name, body, result.sector_path)
		static_index.append(idx)
		built += 1

	# Bind client PNGs only after the branch enters a live tree. A later
	# PackedScene export therefore stores paths/recipes, never copied pixels.
	var texture_binder := DaocWaterTextureBinderScript.new()
	texture_binder.name = "DaocWaterTextureBinder"
	texture_binder.configure(str(settings.get("client_root", "")))
	root.add_child(texture_binder)

	var pack_probe := PackedScene.new()
	var packable_ok := pack_probe.pack(root) == OK
	result.meshes = meshes
	result.static_index = static_index
	result.metrics = _make_metrics(zone_num, body_count, built, meshes.size(), packable_ok)
	result.metrics["modern_shader_meshes"] = meshes.filter(func(item: MeshInstance3D) -> bool:
		return item.material_override is ShaderMaterial
	).size()
	result.metrics["external_texture_binding"] = "DEFERRED_RUNTIME_PNG"
	result.index_signature = compute_index_signature(static_index)
	return result


static func compute_index_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append(_canonical_row(d))
	rows.sort()
	return "\n".join(rows).md5_text()


static func _make_metrics(zone_num: int, waterdefs: int, bodies: int, meshes: int, packable_ok: bool) -> Dictionary:
	return {
		"zone": zone_num,
		"waterdefs": waterdefs,
		"bodies": bodies,
		"meshes": meshes,
		"packable_ok": packable_ok,
	}


static func _make_water_body_mesh(body: Dictionary, settings: Dictionary) -> ArrayMesh:
	var bankpoints := int(str(body.get("bankpoints", "0")))
	if bankpoints < 2:
		return null
	for i in range(bankpoints):
		if not body.has("left%02d" % i) or not body.has("right%02d" % i):
			return null

	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	var water_vertical_offset := float(settings.get("water_vertical_offset", 0.0))
	var h := (float(str(body.get("height", "0"))) + water_vertical_offset) * world_scale * height_exaggeration
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# UV2 = position dans la BANDE : x de la rive gauche (0) a la rive droite (1),
	# y du premier point de berge (0) au dernier (1). Le shader s'en sert pour
	# fondre les bords ouverts du polygone au lieu de les couper net.
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	# DAoC stores an explicit Tesselation field per surface. Honour it for the
	# active 6/9/12 recipes and cap exceptional 64/100 recipes so a legacy zone
	# cannot create millions of vertices in one frame.
	var source_tessellation := maxi(1, int(str(body.get("tesselation", "1"))))
	var tessellation_cap := maxi(1, int(settings.get("water_tessellation_cap", 12)))
	var subdivisions := mini(source_tessellation, tessellation_cap)
	for segment in range(bankpoints - 1):
		var left0 := _sector_dat_point(str(body.get("left%02d" % segment, "0,0,0")), h, world_scale)
		var right0 := _sector_dat_point(str(body.get("right%02d" % segment, "0,0,0")), h, world_scale)
		var left1 := _sector_dat_point(str(body.get("left%02d" % (segment + 1), "0,0,0")), h, world_scale)
		var right1 := _sector_dat_point(str(body.get("right%02d" % (segment + 1), "0,0,0")), h, world_scale)
		var base_vertex := verts.size()
		for along in range(subdivisions + 1):
			var along_t := float(along) / float(subdivisions)
			var left := left0.lerp(left1, along_t)
			var right := right0.lerp(right1, along_t)
			for across in range(subdivisions + 1):
				var across_t := float(across) / float(subdivisions)
				var point := left.lerp(right, across_t)
				verts.append(point)
				normals.append(Vector3.UP)
				uvs.append(Vector2(point.x, point.z) * 0.00055)
				uv2s.append(Vector2(across_t, (float(segment) + along_t) / float(bankpoints - 1)))
		for along in range(subdivisions):
			for across in range(subdivisions):
				var row := subdivisions + 1
				var a := base_vertex + along * row + across
				var b := a + row
				var c := a + 1
				var d := b + 1
				indices.append_array([a, b, c, c, b, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


static func _index_from_body(zone_num: int, section_name: String, water_name: String, body: Dictionary, sector_path: String) -> Dictionary:
	var bankpoints := int(str(body.get("bankpoints", "0")))
	var lefts: Array[Vector2] = []
	var rights: Array[Vector2] = []
	for i in range(bankpoints):
		lefts.append(_sector_dat_point_daoc2(str(body.get("left%02d" % i, "0,0,0"))))
		rights.append(_sector_dat_point_daoc2(str(body.get("right%02d" % i, "0,0,0"))))
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var sx := 0.0
	var sy := 0.0
	var count := 0
	for p in lefts + rights:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		sx += p.x
		sy += p.y
		count += 1
	# P1-14B hotfix: the F12 containment oracle must use a point inside a
	# water strip, not on the first cross-bank edge.  The old midpoint
	# (left0/right0) could sit exactly on an open polygon edge and fail the
	# runtime point-in-water test while the built mesh/index were valid.
	var sample_x := 0.0
	var sample_y := 0.0
	if lefts.size() >= 2 and rights.size() >= 2:
		var sample: Vector2 = (lefts[0] + rights[0] + lefts[1] + rights[1]) * 0.25
		sample_x = sample.x
		sample_y = sample.y
	elif lefts.size() > 0 and rights.size() > 0:
		sample_x = (lefts[0].x + rights[0].x) * 0.5
		sample_y = (lefts[0].y + rights[0].y) * 0.5
	elif count > 0:
		sample_x = sx / float(count)
		sample_y = sy / float(count)
	return {
		"section": section_name,
		"name": water_name,
		"source_zone": zone_num,
		"zone": zone_num,
		"type": str(body.get("type", "")),
		"height": float(str(body.get("height", "0"))),
		"bankpoints": bankpoints,
		"lefts": lefts,
		"rights": rights,
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"sample_x": sample_x,
		"sample_y": sample_y,
		"source": sector_path,
	}


static func _sector_dat_point(value: String, water_y: float, world_scale: float) -> Vector3:
	var parts := value.split(",", false)
	var x := 0.0
	var z := 0.0
	if parts.size() >= 2:
		x = float(parts[0].strip_edges()) * 256.0 * world_scale
		z = float(parts[1].strip_edges()) * 256.0 * world_scale
	return Vector3(x, water_y, z)


static func _sector_dat_point_daoc2(value: String) -> Vector2:
	var parts := value.split(",", false)
	var x := 0.0
	var y := 0.0
	if parts.size() >= 2:
		x = float(parts[0].strip_edges()) * 256.0
		y = float(parts[1].strip_edges()) * 256.0
	return Vector2(x, y)


static func _safe_node_label(s: String) -> String:
	return s.replace(" ", "_").replace("/", "_").replace("\\", "_")


static func _canonical_row(d: Dictionary) -> String:
	var lefts: Array = d.get("lefts", []) as Array
	var rights: Array = d.get("rights", []) as Array
	var pts: Array[String] = []
	for i in range(lefts.size()):
		var p: Vector2 = lefts[i] as Vector2
		pts.append("L%s,%s" % [_fmt_float(p.x), _fmt_float(p.y)])
	for i in range(rights.size()):
		var p: Vector2 = rights[i] as Vector2
		pts.append("R%s,%s" % [_fmt_float(p.x), _fmt_float(p.y)])
	return "%03d|%s|%s|%s|%s|%s|%s|%s" % [
		int(d.get("source_zone", -1)),
		str(d.get("section", "")),
		str(d.get("type", "")),
		_fmt_float(float(d.get("height", 0.0))),
		str(int(d.get("bankpoints", 0))),
		_fmt_float(float(d.get("min_x", 0.0))),
		_fmt_float(float(d.get("max_x", 0.0))),
		";".join(pts),
	]


static func _fmt_float(v: float) -> String:
	return "%.3f" % v
