extends RefCounted
class_name DaocWaterRuntime

## P1-14B: runtime vivant du domaine eau.
## Il consomme l'index DAoC brut produit par le builder. Les requêtes restent en
## coordonnées DAoC natives ; le floor_z est calculé par l'appelant.

var _static_index: Array = []
var _by_zone: Dictionary = {}


func bind(static_index: Array) -> void:
	_static_index = static_index.duplicate(true)
	_rebuild_maps()


func status() -> Dictionary:
	return {
		"scope": "P1-14B WaterRuntime",
		"bodies": _static_index.size(),
		"zones": _by_zone.keys(),
	}


func bodies_for_zone(zone_num: int) -> Array:
	return (_by_zone.get(zone_num, []) as Array).duplicate(true)


func bodies_at_daoc(zone_num: int, xy: Vector2) -> Array:
	var out: Array = []
	var bodies: Array = _by_zone.get(zone_num, []) as Array
	for item in bodies:
		var body: Dictionary = item as Dictionary
		if _point_in_water_body_2d(xy.x, xy.y, body):
			out.append(body.duplicate(true))
	return out


func sample_daoc(zone_num: int, daoc_x: float, daoc_y: float, daoc_z: float, floor_z: float) -> Dictionary:
	var bodies: Array = _by_zone.get(zone_num, []) as Array
	for item in bodies:
		var body: Dictionary = item as Dictionary
		var height := float(body.get("height", 0.0))
		if daoc_z > height + 120.0:
			continue
		if not _point_in_water_body_2d(daoc_x, daoc_y, body):
			continue
		var depth := height - floor_z
		return {
			"in_water": daoc_z <= height,
			"wading": daoc_z <= height and depth < 180.0,
			"height": height,
			"floor_z": floor_z,
			"depth": depth,
			"section": str(body.get("section", "")),
			"type": str(body.get("type", "")),
		}
	return {}


func _rebuild_maps() -> void:
	_by_zone.clear()
	for item in _static_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		var arr: Array = _by_zone.get(z, []) as Array
		arr.append(d)
		_by_zone[z] = arr


func _point_in_water_body_2d(x: float, y: float, body: Dictionary) -> bool:
	var margin := 128.0
	if x < float(body.get("min_x", 0.0)) - margin or x > float(body.get("max_x", 0.0)) + margin:
		return false
	if y < float(body.get("min_y", 0.0)) - margin or y > float(body.get("max_y", 0.0)) + margin:
		return false
	var lefts: Array = body.get("lefts", []) as Array
	var rights: Array = body.get("rights", []) as Array
	if lefts.size() < 2 or rights.size() != lefts.size():
		return false
	var p := Vector2(x, y)
	for i in range(lefts.size() - 1):
		var quad: Array = [lefts[i], lefts[i + 1], rights[i + 1], rights[i]]
		if _point_in_poly_2d(p, quad):
			return true
		# P1-14B hotfix: edge-tolerant containment.  The builder/test may sample
		# exactly on a water-strip edge, and bank/cross-bank edges are still part
		# of the water body for runtime queries.
		if _distance_to_segment_2d(p, lefts[i], lefts[i + 1]) <= margin:
			return true
		if _distance_to_segment_2d(p, rights[i], rights[i + 1]) <= margin:
			return true
		if _distance_to_segment_2d(p, lefts[i], rights[i]) <= margin:
			return true
		if _distance_to_segment_2d(p, lefts[i + 1], rights[i + 1]) <= margin:
			return true
	return false


func _point_in_poly_2d(p: Vector2, poly: Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var pi: Vector2 = poly[i] as Vector2
		var pj: Vector2 = poly[j] as Vector2
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)
