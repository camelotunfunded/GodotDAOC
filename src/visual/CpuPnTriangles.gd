class_name CpuPnTriangles
extends RefCounted

## CPU implementation of Vlachos et al. curved point-normal triangles.
## The source Mesh and the NIF stay untouched: a derived ArrayMesh is returned.

static func build(source: Mesh, subdivisions: int = 3, curvature: float = 0.65) -> ArrayMesh:
	var output := ArrayMesh.new()
	var steps := clampi(subdivisions, 1, 8)
	for surface_index in source.get_surface_count():
		var source_arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL] if source_arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV] if source_arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX] if source_arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var triangle_indices := indices
		if triangle_indices.is_empty():
			triangle_indices.resize(vertices.size())
			for i in vertices.size():
				triangle_indices[i] = i
		var out_vertices := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_uvs := PackedVector2Array()
		for triangle_start in range(0, triangle_indices.size() - 2, 3):
			var ids := [triangle_indices[triangle_start], triangle_indices[triangle_start + 1], triangle_indices[triangle_start + 2]]
			if ids[0] < 0 or ids[1] < 0 or ids[2] < 0 or ids[0] >= vertices.size() or ids[1] >= vertices.size() or ids[2] >= vertices.size():
				continue
			var p := [vertices[ids[0]], vertices[ids[1]], vertices[ids[2]]]
			var face_normal: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
			var n := [face_normal, face_normal, face_normal]
			if normals.size() == vertices.size():
				n = [normals[ids[0]].normalized(), normals[ids[1]].normalized(), normals[ids[2]].normalized()]
			var tex := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			if uvs.size() == vertices.size():
				tex = [uvs[ids[0]], uvs[ids[1]], uvs[ids[2]]]
			var control := _position_control_points(p, n, curvature)
			for row in steps:
				for column in range(steps - row):
					var a := Vector3(float(steps - row - column), float(column), float(row)) / float(steps)
					var b := Vector3(float(steps - row - column - 1), float(column + 1), float(row)) / float(steps)
					var c := Vector3(float(steps - row - column - 1), float(column), float(row + 1)) / float(steps)
					_emit_triangle(a, b, c, p, n, tex, control, out_vertices, out_normals, out_uvs)
					if column < steps - row - 1:
						var d := Vector3(float(steps - row - column - 2), float(column + 1), float(row + 1)) / float(steps)
						_emit_triangle(b, d, c, p, n, tex, control, out_vertices, out_normals, out_uvs)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_vertices
		arrays[Mesh.ARRAY_NORMAL] = out_normals
		if not out_uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = out_uvs
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		output.surface_set_material(output.get_surface_count() - 1, source.surface_get_material(surface_index))
	return output


static func apply_to_tree(root: Node, subdivisions: int = 3, curvature: float = 0.65) -> Dictionary:
	var before := 0
	var after := 0
	var surfaces := 0
	for value in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := value as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var original := mesh_instance.mesh
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			before += (ids.size() if not ids.is_empty() else verts.size()) / 3
			surfaces += 1
		var derived := build(original, subdivisions, curvature)
		for surface in derived.get_surface_count():
			var arrays := derived.surface_get_arrays(surface)
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			after += (ids.size() if not ids.is_empty() else verts.size()) / 3
		mesh_instance.mesh = derived
	return {"triangles_before": before, "triangles_after": after, "surfaces": surfaces}


static func _position_control_points(p: Array, n: Array, curvature: float) -> Dictionary:
	var result := {"300": p[0], "030": p[1], "003": p[2]}
	result["210"] = _edge_control(p[0], p[1], n[0], curvature)
	result["120"] = _edge_control(p[1], p[0], n[1], curvature)
	result["021"] = _edge_control(p[1], p[2], n[1], curvature)
	result["012"] = _edge_control(p[2], p[1], n[2], curvature)
	result["102"] = _edge_control(p[2], p[0], n[2], curvature)
	result["201"] = _edge_control(p[0], p[2], n[0], curvature)
	var edge_average: Vector3 = (result["210"] + result["120"] + result["021"] + result["012"] + result["102"] + result["201"]) / 6.0
	var vertex_average: Vector3 = (p[0] + p[1] + p[2]) / 3.0
	result["111"] = edge_average + (edge_average - vertex_average) * 0.5
	return result


static func _edge_control(origin: Vector3, other: Vector3, normal: Vector3, curvature: float) -> Vector3:
	var straight := (2.0 * origin + other) / 3.0
	var curved := (2.0 * origin + other - normal * (other - origin).dot(normal)) / 3.0
	return straight.lerp(curved, curvature)


static func _emit_triangle(a: Vector3, b: Vector3, c: Vector3, p: Array, n: Array, tex: Array, control: Dictionary, out_vertices: PackedVector3Array, out_normals: PackedVector3Array, out_uvs: PackedVector2Array) -> void:
	for barycentric in [a, b, c]:
		out_vertices.append(_evaluate_patch(barycentric, control))
		out_normals.append(_evaluate_normal(barycentric, p, n))
		out_uvs.append(tex[0] * barycentric.x + tex[1] * barycentric.y + tex[2] * barycentric.z)


static func _evaluate_patch(b: Vector3, c: Dictionary) -> Vector3:
	var u := b.x
	var v := b.y
	var w := b.z
	return c["300"] * u*u*u + c["030"] * v*v*v + c["003"] * w*w*w \
		+ c["210"] * 3.0*u*u*v + c["201"] * 3.0*u*u*w \
		+ c["120"] * 3.0*u*v*v + c["021"] * 3.0*v*v*w \
		+ c["102"] * 3.0*u*w*w + c["012"] * 3.0*v*w*w \
		+ c["111"] * 6.0*u*v*w


static func _evaluate_normal(b: Vector3, p: Array, n: Array) -> Vector3:
	# Quadratic PN normal patch. Edge controls keep interpolation tangent to edges.
	var h110: Vector3 = (n[0] + n[1]).normalized()
	var h011: Vector3 = (n[1] + n[2]).normalized()
	var h101: Vector3 = (n[2] + n[0]).normalized()
	var value: Vector3 = n[0] * b.x*b.x + n[1] * b.y*b.y + n[2] * b.z*b.z \
		+ h110 * 2.0*b.x*b.y + h011 * 2.0*b.y*b.z + h101 * 2.0*b.z*b.x
	return value.normalized()
