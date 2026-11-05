extends RefCounted
class_name DaocTerrainBuilder

const DaocTerrainBuildResultScript = preload("res://src/daoc/DaocTerrainBuildResult.gd")
const DaocTerrainRuntimeScript = preload("res://src/daoc/DaocTerrainRuntime.gd")

## P1-14E: builder statique du terrain.
## Il reçoit meta + heightmap + ressources de splatting déjà chargées, ne lit pas ZoneViewer,
## ne parente rien dans la scène live et produit root packable + collision terrain + index stable.

static func build(zone_num: int, meta: Dictionary, hb: PackedByteArray, origin3: Vector3, settings: Dictionary = {}) -> DaocTerrainBuildResult:
	var result: DaocTerrainBuildResult = DaocTerrainBuildResultScript.new()
	result.source_path = str(settings.get("source_path", ""))
	var root := Node3D.new()
	root.name = "Zone%03d_Terrain" % zone_num
	var collision_root := Node3D.new()
	collision_root.name = "Zone%03d_TerrainCollisionRoot" % zone_num
	result.root = root
	result.collision_root = collision_root

	var res := int(meta.get("resolution", 256))
	if res <= 0 or hb.is_empty():
		result.metrics = _make_metrics(zone_num, res, 0, 0, 0, 0, true, true)
		result.index_signature = compute_index_signature([])
		return result

	var units_per_cell := float(meta.get("units_per_cell", 256))
	var world_scale := float(settings.get("world_scale", 1.0))
	var cell := units_per_cell * world_scale
	var splat_manifest: Dictionary = settings.get("splat_manifest", {}) as Dictionary
	if not splat_manifest.is_empty() and splat_manifest.has("patches"):
		_build_splat_terrain(zone_num, hb, res, cell, origin3, settings, result)
	else:
		_build_single_terrain(zone_num, hb, res, cell, origin3, settings, result)

	var pack_probe := PackedScene.new()
	var packable_ok := pack_probe.pack(root) == OK
	var collision_pack_probe := PackedScene.new()
	var collision_packable_ok := collision_pack_probe.pack(collision_root) == OK
	var triangles := 0
	var vertices := 0
	for item in result.static_index:
		var d: Dictionary = item as Dictionary
		triangles += int(d.get("triangles", 0))
		vertices += int(d.get("vertices", 0))
	result.metrics = _make_metrics(zone_num, res, result.terrain_meshes.size(), result.static_index.size(), result.collision_bodies.size(), vertices, packable_ok, collision_packable_ok)
	result.metrics["triangles"] = triangles
	result.index_signature = compute_index_signature(result.static_index)
	return result


static func compute_index_signature(static_index: Array) -> String:
	var rows: Array[String] = []
	for item in static_index:
		var d: Dictionary = item as Dictionary
		rows.append(_canonical_row(d))
	rows.sort()
	return "\n".join(rows).md5_text()


static func _build_splat_terrain(zone_num: int, hb: PackedByteArray, res: int, cell: float, origin3: Vector3, settings: Dictionary, result: DaocTerrainBuildResult) -> void:
	var manifest: Dictionary = settings.get("splat_manifest", {}) as Dictionary
	var patches: Dictionary = manifest.get("patches", {}) as Dictionary
	var seg: int = res / 8
	var side: int = seg + 1
	for sy in 8:
		for sx in 8:
			var key := "%d,%d" % [sx, sy]
			if not patches.has(key):
				continue
			var layers: Array = patches[key]
			_build_sector_mesh(zone_num, sx, sy, seg, side, res, cell, hb, origin3, layers, settings, result)


static func _build_single_terrain(zone_num: int, hb: PackedByteArray, res: int, cell: float, origin3: Vector3, settings: Dictionary, result: DaocTerrainBuildResult) -> void:
	var side := res + 1
	var n := side * side
	var verts := PackedVector3Array(); verts.resize(n)
	var uvs := PackedVector2Array(); uvs.resize(n)
	var hs := PackedFloat32Array(); hs.resize(n)
	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	for row in side:
		var rr: int = min(row, res - 1)
		for col in side:
			var cc: int = min(col, res - 1)
			var bi: int = (rr * res + cc) * 2
			var raw: int = hb[bi] | (hb[bi + 1] << 8)
			var idx := row * side + col
			var y := float(raw) * world_scale * height_exaggeration
			hs[idx] = y
			verts[idx] = Vector3(col * cell, y, row * cell)
			uvs[idx] = Vector2(float(col) / res, float(row) / res)

	var normals := PackedVector3Array(); normals.resize(n)
	for row in side:
		for col in side:
			var hl := hs[row * side + max(col - 1, 0)]
			var hr := hs[row * side + min(col + 1, side - 1)]
			var hd := hs[max(row - 1, 0) * side + col]
			var hu := hs[min(row + 1, side - 1) * side + col]
			normals[row * side + col] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()

	var indices := _grid_indices(side)
	var mesh := _mesh_from_arrays(verts, normals, uvs, indices)
	var mi := MeshInstance3D.new()
	mi.name = "Zone%03d" % zone_num
	mi.mesh = mesh
	mi.material_override = _make_fallback_material(settings)
	mi.position = origin3
	mi.set_meta("daoc_terrain_14e", true)
	mi.set_meta("daoc_zone", zone_num)
	mi.set_meta("sector_x", -1)
	mi.set_meta("sector_y", -1)
	result.root.add_child(mi)
	result.terrain_meshes.append(mi)
	_maybe_add_collision_body(zone_num, "Zone%03d_TerrainCollision" % zone_num, verts, indices, origin3, settings, result)
	result.static_index.append(_index_row(zone_num, -1, -1, "single", verts.size(), int(indices.size() / 3), 0, 0, res - 1, res - 1))


static func _build_sector_mesh(zone_num: int, sx: int, sy: int, seg: int, side: int, res: int, cell: float, hb: PackedByteArray, origin3: Vector3, layers: Array, settings: Dictionary, result: DaocTerrainBuildResult) -> void:
	var visual_factor := clampi(int(settings.get("terrain_visual_bilinear_subdivision", 1)), 1, 8)
	var visual_seg := seg * visual_factor
	var visual_side := visual_seg + 1
	var n := visual_side * visual_side
	var verts := PackedVector3Array(); verts.resize(n)
	var uvs := PackedVector2Array(); uvs.resize(n)
	var normals := PackedVector3Array(); normals.resize(n)
	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	var raw_cell := cell / maxf(world_scale, 0.000001)

	for row in visual_side:
		for col in visual_side:
			var gcol := float(sx * seg) + float(col) / visual_factor
			var grow := float(sy * seg) + float(row) / visual_factor
			var raw_x := gcol * raw_cell
			var raw_y := grow * raw_cell
			var raw_height := float(_raw_at(hb, res, roundi(gcol), roundi(grow))) if visual_factor == 1 else DaocTerrainRuntimeScript._sample_height(hb, res, raw_x, raw_y)
			var idx := row * visual_side + col
			verts[idx] = Vector3(raw_x * world_scale, raw_height * world_scale * height_exaggeration, raw_y * world_scale)
			uvs[idx] = Vector2(float(col) / visual_seg, float(row) / visual_seg)

	for row in visual_side:
		for col in visual_side:
			var gcol := float(sx * seg) + float(col) / visual_factor
			var grow := float(sy * seg) + float(row) / visual_factor
			var probe_raw := raw_cell / visual_factor
			var wx := gcol * raw_cell
			var wy := grow * raw_cell
			var hl := DaocTerrainRuntimeScript._sample_height(hb, res, wx - probe_raw, wy) * world_scale * height_exaggeration
			var hr := DaocTerrainRuntimeScript._sample_height(hb, res, wx + probe_raw, wy) * world_scale * height_exaggeration
			var hd := DaocTerrainRuntimeScript._sample_height(hb, res, wx, wy - probe_raw) * world_scale * height_exaggeration
			var hu := DaocTerrainRuntimeScript._sample_height(hb, res, wx, wy + probe_raw) * world_scale * height_exaggeration
			normals[row * visual_side + col] = Vector3(hl - hr, 2.0 * probe_raw * world_scale, hd - hu).normalized()

	var indices := _grid_indices(visual_side)
	var mesh := _mesh_from_arrays(verts, normals, uvs, indices)
	var mi := MeshInstance3D.new()
	mi.name = "Zone%03d_S%d%d" % [zone_num, sx, sy]
	mi.mesh = mesh
	mi.material_override = _make_splat_material(sx, sy, layers, settings)
	mi.position = origin3
	mi.set_meta("daoc_terrain_14e", true)
	mi.set_meta("daoc_zone", zone_num)
	mi.set_meta("sector_x", sx)
	mi.set_meta("sector_y", sy)
	result.root.add_child(mi)
	result.terrain_meshes.append(mi)
	# Contrat de sécurité : même avec un rendu ×2/×4/×8, la collision est rebâtie
	# séparément avec les sommets historiques. Elle ne suit jamais le test visuel.
	var collision_geometry := _historical_sector_geometry(sx, sy, seg, side, res, cell, hb, world_scale, height_exaggeration)
	_maybe_add_collision_body(zone_num, "Zone%03d_S%d%d_Collision" % [zone_num, sx, sy],
		collision_geometry["vertices"] as PackedVector3Array,
		collision_geometry["indices"] as PackedInt32Array, origin3, settings, result)
	result.static_index.append(_index_row(zone_num, sx, sy, "splat", verts.size(), int(indices.size() / 3), sx * seg, sy * seg, sx * seg + seg, sy * seg + seg))


static func _historical_sector_geometry(sx: int, sy: int, seg: int, side: int, res: int,
		cell: float, hb: PackedByteArray, world_scale: float, height_exaggeration: float) -> Dictionary:
	var vertices := PackedVector3Array(); vertices.resize(side * side)
	for row in side:
		for col in side:
			var gcol := sx * seg + col
			var grow := sy * seg + row
			vertices[row * side + col] = Vector3(gcol * cell,
				float(_raw_at(hb, res, gcol, grow)) * world_scale * height_exaggeration,
				grow * cell)
	return {"vertices": vertices, "indices": _grid_indices(side)}


static func _grid_indices(side: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for row in side - 1:
		for col in side - 1:
			var tl := row * side + col
			var tr := tl + 1
			var bl := (row + 1) * side + col
			var br := bl + 1
			indices.append_array([tl, bl, tr, tr, bl, br])
	return indices


## LE SOL ETAIT ECLAIRE PAR EN DESSOUS. `_grid_indices` enroule ses triangles
## (tl, bl, tr) : vu du ciel c'est le sens TRIGONOMETRIQUE, qui est la face
## AVANT pour la physique Godot (`ConcavePolygonShape3D` calcule sa normale par
## produit vectoriel) mais la face ARRIERE pour le rendu — Godot dessine ses
## faces avant dans le sens HORAIRE. Le sol ne s'affichait que grace a
## `cull_disabled`, et sur une face arriere Godot RETOURNE la normale : le
## terrain etait eclaire comme s'il regardait le sous-sol. Consequence mesuree
## le 2026-09-18 (P1-90) : AUCUNE lumiere directe du soleil au sol, donc aucune
## ombre portee visible, uniquement l'ambiance — d'ou le « monde plat ».
## Seul le maillage VISUEL est retourne ; la collision garde l'ordre d'origine,
## puisque son sens a lui est correct et que les joueurs marchent dessus.
static func _visual_winding(indices: PackedInt32Array) -> PackedInt32Array:
	var flipped := PackedInt32Array()
	flipped.resize(indices.size())
	for i in range(0, indices.size() - 2, 3):
		flipped[i] = indices[i]
		flipped[i + 1] = indices[i + 2]
		flipped[i + 2] = indices[i + 1]
	return flipped


static func _mesh_from_arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	# Tangentes : sans elles, `NORMAL_MAP` est inerte — le sol PBR resterait
	# plat quelle que soit la carte. La grille a `u` le long de +X et `v` le
	# long de +Z ; la tangente est +X couchée sur le plan de la normale, et le
	# signe -1 dit à Godot que la bitangente (cross(N, T) * w) doit pointer +Z.
	arrays[Mesh.ARRAY_TANGENT] = _grid_tangents(normals)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _visual_winding(indices)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


static func _grid_tangents(normals: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(normals.size() * 4)
	for i in normals.size():
		var n: Vector3 = normals[i]
		var t: Vector3 = (Vector3.RIGHT - n * n.x).normalized()
		if not t.is_finite() or t.length_squared() < 0.5:
			t = Vector3.RIGHT
		out[i * 4] = t.x
		out[i * 4 + 1] = t.y
		out[i * 4 + 2] = t.z
		out[i * 4 + 3] = -1.0
	return out


static func _make_splat_material(sx: int, sy: int, layers: Array, settings: Dictionary) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = settings.get("splat_shader", null) as Shader
	mat.set_shader_parameter("details", settings.get("splat_details", null))
	mat.set_shader_parameter("masks", settings.get("splat_masks", null))
	var lc: int = min(layers.size(), 12)
	var tex_slice := PackedInt32Array(); tex_slice.resize(12)
	var tiles := PackedFloat32Array(); tiles.resize(12)
	var mask_slice := PackedFloat32Array(); mask_slice.resize(12)
	var chan := PackedVector4Array(); chan.resize(12)
	for k in 12:
		if k < lc:
			var layer: Dictionary = layers[k] as Dictionary
			tex_slice[k] = int(layer.get("tex", 0))
			tiles[k] = float(layer.get("tiles", 1.0))
			mask_slice[k] = float(max(int(layer.get("mask", 0)), 0))
			chan[k] = _chan_vec(int(layer.get("sub", 0)))
		else:
			tex_slice[k] = 0
			tiles[k] = 1.0
			mask_slice[k] = 0.0
			chan[k] = Vector4.ZERO
	mat.set_shader_parameter("layer_count", lc)
	mat.set_shader_parameter("patch_x", sx)
	mat.set_shader_parameter("patch_y", sy)
	mat.set_shader_parameter("tex_slice", tex_slice)
	mat.set_shader_parameter("tiles", tiles)
	mat.set_shader_parameter("mask_slice", mask_slice)
	mat.set_shader_parameter("chan_sel", chan)
	mat.set_shader_parameter("tile_scale", float(settings.get("tile_scale", 1.0)))
	# Sol PBR : posé à la naissance du matériau quand l'option est déjà cochée ;
	# sinon `DaocTerrainPbrUpgrade.apply` le rejoue plus tard, sans reconstruire.
	var pbr: Dictionary = settings.get("splat_pbr", {}) as Dictionary
	if not pbr.is_empty():
		DaocTerrainPbrUpgrade.apply_to_material(mat, pbr)
	return mat


static func _make_fallback_material(settings: Dictionary) -> Material:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex: Texture2D = settings.get("ground_texture", null) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color(0.52, 0.56, 0.48)
	return mat


static func _maybe_add_collision_body(zone_num: int, body_name: String, verts: PackedVector3Array, indices: PackedInt32Array, origin3: Vector3, settings: Dictionary, result: DaocTerrainBuildResult) -> void:
	if not bool(settings.get("build_terrain_collision", true)):
		return
	if verts.size() == 0 or indices.size() < 3:
		return
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for i in indices.size():
		faces[i] = verts[indices[i]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = int(settings.get("terrain_collision_layer", 1))
	body.collision_mask = int(settings.get("terrain_collision_mask", 0))
	body.position = origin3
	body.set_meta("daoc_terrain_collision_14e", true)
	body.set_meta("daoc_zone", zone_num)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	body.add_child(cs)
	result.collision_root.add_child(body)
	result.collision_bodies.append(body)


static func _index_row(zone_num: int, sx: int, sy: int, mode: String, vertices: int, triangles: int, min_col: int, min_row: int, max_col: int, max_row: int) -> Dictionary:
	return {
		"source_zone": zone_num,
		"zone": zone_num,
		"sector_x": sx,
		"sector_y": sy,
		"mode": mode,
		"vertices": vertices,
		"triangles": triangles,
		"min_col": min_col,
		"min_row": min_row,
		"max_col": max_col,
		"max_row": max_row,
	}


static func _make_metrics(zone_num: int, res: int, terrain_meshes: int, sectors: int, collision_bodies: int, vertices: int, packable_ok: bool, collision_packable_ok: bool) -> Dictionary:
	return {
		"zone": zone_num,
		"res": res,
		"sectors": sectors,
		"terrain_meshes": terrain_meshes,
		"collision_bodies": collision_bodies,
		"vertices": vertices,
		"packable_ok": packable_ok,
		"collision_packable_ok": collision_packable_ok,
	}


static func _raw_at(hb: PackedByteArray, res: int, gcol: int, grow: int) -> int:
	var c: int = clampi(gcol, 0, res - 1)
	var r: int = clampi(grow, 0, res - 1)
	var bi: int = (r * res + c) * 2
	return hb[bi] | (hb[bi + 1] << 8)


static func _chan_vec(sub: int) -> Vector4:
	if sub == 0:
		return Vector4(1, 0, 0, 0)
	if sub == 1:
		return Vector4(0, 1, 0, 0)
	return Vector4(0, 0, 1, 0)


static func _canonical_row(d: Dictionary) -> String:
	return "%03d|%02d|%02d|%s|%d|%d|%d|%d|%d|%d" % [
		int(d.get("source_zone", -1)),
		int(d.get("sector_x", -1)),
		int(d.get("sector_y", -1)),
		str(d.get("mode", "")),
		int(d.get("vertices", 0)),
		int(d.get("triangles", 0)),
		int(d.get("min_col", 0)),
		int(d.get("min_row", 0)),
		int(d.get("max_col", 0)),
		int(d.get("max_row", 0)),
	]
