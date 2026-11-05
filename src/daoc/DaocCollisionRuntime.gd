extends RefCounted
class_name DaocCollisionRuntime

## P1-14C: runtime vivant du domaine collisions locales.
## Il consomme les index DAoC bruts produits par CollisionBuilder. Les requêtes
## restent en coordonnées DAoC natives ; ZoneViewer garde seulement les wrappers.

var _boundary_index: Array = []
var _prop_index: Array = []
var _bound_by_zone: Dictionary = {}
var _prop_by_zone: Dictionary = {}


func bind_boundary(static_index: Array) -> void:
	_boundary_index = static_index.duplicate(true)
	_rebuild_boundary_maps()


func bind_props(static_index: Array) -> void:
	_prop_index = static_index.duplicate(true)
	_rebuild_prop_maps()


func status() -> Dictionary:
	return {
		"scope": "P1-14C CollisionRuntime",
		"boundary_segments": _boundary_index.size(),
		"prop_bodies": _prop_index.size(),
		"boundary_zones": _bound_by_zone.keys(),
		"prop_zones": _prop_by_zone.keys(),
	}


func boundaries_for_zone(zone_num: int) -> Array:
	return (_bound_by_zone.get(zone_num, []) as Array).duplicate(true)


func props_for_zone(zone_num: int) -> Array:
	return (_prop_by_zone.get(zone_num, []) as Array).duplicate(true)


func point_near_boundary_2d(zone_num: int, p: Vector2, clearance_raw: float) -> bool:
	var segments: Array = _bound_by_zone.get(zone_num, []) as Array
	for seg_var in segments:
		var seg: Dictionary = seg_var as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		if _distance_to_segment_2d(p, a, b) < clearance_raw:
			return true
	return false


func solve_boundary_collision(zone_num: int, old_x: float, old_y: float, new_x: float, new_y: float, radius_raw: float = 40.0) -> Vector2:
	var newp := Vector2(new_x, new_y)
	var segments: Array = _bound_by_zone.get(zone_num, []) as Array
	if segments.is_empty():
		return newp
	var oldp := Vector2(old_x, old_y)
	if oldp.distance_squared_to(newp) <= 0.0001:
		return newp
	for seg_var in segments:
		var seg: Dictionary = seg_var as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		var closest_old := _closest_point_on_segment_2d(oldp, a, b)
		var old_dist := oldp.distance_to(closest_old)
		var closest := _closest_point_on_segment_2d(newp, a, b)
		var dist := newp.distance_to(closest)
		# Même règle que le monolithe : ne pas emprisonner un joueur déjà né près du bound.
		if old_dist < radius_raw and dist >= old_dist:
			continue
		if old_dist >= radius_raw and _segments_intersect_2d(oldp, newp, a, b):
			return oldp
		if dist < radius_raw and dist > 0.001:
			newp = closest + (newp - closest).normalized() * radius_raw
	return newp


## P1-133 — hauteur sous laquelle un obstacle NIF est une MARCHE (escalier,
## seuil, rampe de pont) et non un mur ; au-dessus, les rayons de murs.
var nif_step_height_raw: float = 52.0


func solve_prop_collision(zone_num: int, old_x: float, old_y: float, new_x: float, new_y: float, daoc_z: float, radius_raw: float = 40.0, height_raw: float = 136.0) -> Vector2:
	var oldp := Vector2(old_x, old_y)
	var newp := Vector2(new_x, new_y)
	var registered: Array = _prop_by_zone.get(zone_num, []) as Array
	if registered.is_empty():
		return newp
	if oldp.distance_squared_to(newp) <= 0.0001:
		return newp
	if not _move_blocked(zone_num, oldp, newp, daoc_z, radius_raw, height_raw):
		return newp
	# Ne pas bloquer un joueur déjà né dans une collision AABB.
	if is_prop_position_blocked(zone_num, oldp, daoc_z, radius_raw, height_raw):
		return newp
	var candidates: Array[Vector2] = []
	var move := newp - oldp
	if absf(move.x) >= absf(move.y):
		candidates.append(Vector2(newp.x, oldp.y))
		candidates.append(Vector2(oldp.x, newp.y))
	else:
		candidates.append(Vector2(oldp.x, newp.y))
		candidates.append(Vector2(newp.x, oldp.y))
	for c in candidates:
		if c.distance_squared_to(oldp) <= 0.0001:
			continue
		if not _move_blocked(zone_num, oldp, c, daoc_z, radius_raw, height_raw):
			return c
	return oldp


func _move_blocked(zone_num: int, oldp: Vector2, newp: Vector2, daoc_z: float, radius_raw: float, height_raw: float) -> bool:
	return is_prop_position_blocked(zone_num, newp, daoc_z, radius_raw, height_raw) \
		or trimesh_motion_blocked(zone_num, oldp, newp, daoc_z, radius_raw, height_raw)


## Les props à boîte gardent la règle AABB de P1-14C ; ceux qui portent le
## maillage NIF (trimesh) sont jugés par `trimesh_motion_blocked`.
func is_prop_position_blocked(zone_num: int, p: Vector2, daoc_z: float, radius_raw: float = 40.0, height_raw: float = 136.0) -> bool:
	var registered: Array = _prop_by_zone.get(zone_num, []) as Array
	for item_var in registered:
		var item := item_var as Dictionary
		if not bool(item.get("has_daoc_aabb", false)) or bool(item.get("trimesh", false)):
			continue
		if _daoc_prop_aabb_blocks_position(item, p, daoc_z, radius_raw, height_raw):
			return true
	return false


## P1-133 — deux rayons horizontaux (au-dessus d'une marche, et à hauteur de
## poitrine) de l'ancienne position vers la nouvelle, prolongés du rayon de la
## capsule, contre les SEULS corps trimesh proches. Un plancher ou une rampe
## (normale proche de la verticale) ne bloque jamais : c'est un sol.
func trimesh_motion_blocked(zone_num: int, oldp: Vector2, newp: Vector2, daoc_z: float, radius_raw: float = 40.0, height_raw: float = 136.0) -> bool:
	var registered: Array = _prop_by_zone.get(zone_num, []) as Array
	var near: Array = []
	for item_var in registered:
		var item := item_var as Dictionary
		if not bool(item.get("trimesh", false)) or not bool(item.get("has_daoc_aabb", false)):
			continue
		var mn: Vector3 = item.get("daoc_min", Vector3.ZERO) as Vector3
		var mx: Vector3 = item.get("daoc_max", Vector3.ZERO) as Vector3
		if daoc_z + height_raw < mn.z or daoc_z > mx.z:
			continue
		var r := radius_raw * 2.0
		if maxf(oldp.x, newp.x) < mn.x - r or minf(oldp.x, newp.x) > mx.x + r \
				or maxf(oldp.y, newp.y) < mn.y - r or minf(oldp.y, newp.y) > mx.y + r:
			continue
		var body := item.get("body") as Node3D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			continue
		near.append(item)
	if near.is_empty():
		return false
	var first := near[0] as Dictionary
	var body0 := first.get("body") as Node3D
	var space := body0.get_world_3d().direct_space_state if body0.get_world_3d() != null else null
	if space == null:
		return false
	var move := newp - oldp
	var dir := move.normalized()
	var reach := newp + dir * radius_raw
	var mask := 0
	var rids: Array = []
	for item_var in near:
		var body := (item_var as Dictionary).get("body") as CollisionObject3D
		if body != null:
			mask |= body.collision_layer
			rids.append(body.get_rid())
	for h in [nif_step_height_raw, maxf(nif_step_height_raw + 1.0, height_raw * 0.75)]:
		var from := _daoc_to_world(first, oldp, daoc_z + h)
		var to := _daoc_to_world(first, reach, daoc_z + h)
		var query := PhysicsRayQueryParameters3D.create(from, to, mask if mask != 0 else 0xFFFFFFFF)
		query.hit_back_faces = true
		query.hit_from_inside = false
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Object = hit.get("collider") as Object
		if collider == null or not rids.has((collider as CollisionObject3D).get_rid() if collider is CollisionObject3D else RID()):
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
		if absf(normal.y) < 0.7:
			return true
	return false


func _daoc_to_world(item: Dictionary, p: Vector2, z: float) -> Vector3:
	var o: Vector3 = item.get("origin3", Vector3.ZERO) as Vector3
	var sx := float(item.get("sx", 1.0))
	var sy := float(item.get("sy", 1.0))
	return Vector3(o.x + p.x * sx, o.y + z * sy, o.z + p.y * sx)


func _rebuild_boundary_maps() -> void:
	_bound_by_zone.clear()
	for item in _boundary_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		var arr: Array = _bound_by_zone.get(z, []) as Array
		arr.append(d)
		_bound_by_zone[z] = arr


func _rebuild_prop_maps() -> void:
	_prop_by_zone.clear()
	for item in _prop_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		var arr: Array = _prop_by_zone.get(z, []) as Array
		arr.append(d)
		_prop_by_zone[z] = arr


func _daoc_prop_aabb_blocks_position(item: Dictionary, p: Vector2, daoc_z: float, radius_raw: float, height_raw: float) -> bool:
	var mn: Vector3 = item.get("daoc_min", Vector3.ZERO) as Vector3
	var mx: Vector3 = item.get("daoc_max", Vector3.ZERO) as Vector3
	var player_min_z := daoc_z
	var player_max_z := daoc_z + height_raw
	if player_max_z < mn.z or player_min_z > mx.z:
		return false
	return (p.x >= mn.x - radius_raw and p.x <= mx.x + radius_raw
		and p.y >= mn.y - radius_raw and p.y <= mx.y + radius_raw)


func _closest_point_on_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return a
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return a + ab * t


func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(_closest_point_on_segment_2d(p, a, b))


func _segments_intersect_2d(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _ccw(a, c, d) != _ccw(b, c, d) and _ccw(a, b, c) != _ccw(a, b, d)


func _ccw(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
