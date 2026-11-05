extends RefCounted
class_name DaocHairMotionProfile

## Classe une coiffure une fois, hors de la boucle de jeu, a partir de sa
## geometrie et de la boite de la tete. Le profil obtenu peut etre ecrit dans
## un manifeste puis consomme par un shader sans refaire l'analyse au runtime.

const PROFILE_SHORT := "short"
const PROFILE_MEDIUM := "medium"
const PROFILE_LONG := "long"


static func analyze_mesh(hair_mesh: Mesh, head_mesh: Mesh) -> Dictionary:
	if hair_mesh == null or head_mesh == null:
		return {"ok": false, "reason": "mesh_absent"}
	var vertices := PackedVector3Array()
	for surface_index in range(hair_mesh.get_surface_count()):
		var arrays := hair_mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		vertices.append_array(surface_vertices)
	return analyze_vertices(vertices, head_mesh.get_aabb())


static func analyze_vertices(hair_vertices: PackedVector3Array, head_aabb: AABB) -> Dictionary:
	if hair_vertices.is_empty() or head_aabb.size.y <= 0.0001:
		return {"ok": false, "reason": "geometrie_insuffisante"}

	var lowest_y := INF
	var below_lower_head := 0
	# Les sommets sous le bas de la boite de tete representent les longueurs. Ce
	# second indicateur evite que la seule boite globale confonde une pointe
	# isolee avec une masse de cheveux reellement longue.
	var lower_head_y := head_aabb.position.y
	for vertex in hair_vertices:
		lowest_y = minf(lowest_y, vertex.y)
		if vertex.y < lower_head_y:
			below_lower_head += 1

	var extension_ratio := maxf(0.0, head_aabb.position.y - lowest_y) / head_aabb.size.y
	var trailing_vertex_ratio := float(below_lower_head) / float(hair_vertices.size())
	var profile := PROFILE_SHORT
	if extension_ratio > 0.65 or (extension_ratio > 0.45 and trailing_vertex_ratio > 0.28):
		profile = PROFILE_LONG
	elif extension_ratio > 0.25 or trailing_vertex_ratio > 0.16:
		profile = PROFILE_MEDIUM

	return {
		"ok": true,
		"profile": profile,
		"extension_ratio": extension_ratio,
		"trailing_vertex_ratio": trailing_vertex_ratio,
		"vertex_count": hair_vertices.size(),
		"motion": motion_settings(profile),
	}


static func motion_settings(profile: String) -> Dictionary:
	match profile:
		PROFILE_LONG:
			return {"amplitude": 1.0, "tip_start": 0.30, "medium_lod_scale": 0.45}
		PROFILE_MEDIUM:
			return {"amplitude": 0.55, "tip_start": 0.48, "medium_lod_scale": 0.35}
		_:
			return {"amplitude": 0.18, "tip_start": 0.72, "medium_lod_scale": 0.20}
