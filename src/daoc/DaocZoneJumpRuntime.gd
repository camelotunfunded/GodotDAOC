extends RefCounted
class_name DaocZoneJumpRuntime

## P1-14A: runtime vivant du domaine zonejump.
## Il consomme l'index brut produit par le builder, câble les signaux après parentage,
## et expose les requêtes en coordonnées DAoC natives.

signal zonejump_body_entered(body: Node, data: Dictionary)
signal zonejump_body_exited(body: Node, data: Dictionary)

var _static_index: Array = []
var _by_zone: Dictionary = {}
var _by_area_id: Dictionary = {}
var _areas: Array[Area3D] = []
var _last_triggered: Dictionary = {}
var _wire_count: int = 0


func bind(static_index: Array) -> void:
	_static_index = static_index.duplicate(true)
	_rebuild_maps()


func wire(areas: Array) -> void:
	for area in areas:
		if area == null:
			continue
		_areas.append(area)
		if bool(area.get_meta("daoc_zonejump_wired_14a", false)):
			continue
		area.set_meta("daoc_zonejump_wired_14a", true)
		area.body_entered.connect(_on_area_body_entered.bind(area))
		area.body_exited.connect(_on_area_body_exited.bind(area))
		_wire_count += 1


func nearest_daoc(zone_num: int, xy: Vector2) -> Dictionary:
	var entries: Array = _by_zone.get(zone_num, []) as Array
	var best: Dictionary = {}
	var best_dist: float = INF
	for item in entries:
		var d: Dictionary = item as Dictionary
		var a: Vector2 = d.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = d.get("b", Vector2.ZERO) as Vector2
		var dist := _distance_to_segment_2d(xy, a, b)
		if dist < best_dist:
			best_dist = dist
			best = d
	if best.is_empty():
		return {"ok": false, "reason": "no zonejump entries", "zone": zone_num, "entry_count": entries.size()}
	var out := best.duplicate(true)
	out["ok"] = true
	out["distance_raw"] = best_dist
	out["entry_count"] = entries.size()
	return out


func volumes_at_daoc(zone_num: int, xy: Vector2) -> Array:
	var out: Array = []
	var entries: Array = _by_zone.get(zone_num, []) as Array
	for item in entries:
		var d: Dictionary = item as Dictionary
		var a: Vector2 = d.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = d.get("b", Vector2.ZERO) as Vector2
		var radius := float(d.get("radius", 0.0))
		if _distance_to_segment_2d(xy, a, b) <= radius:
			out.append(d.duplicate(true))
	return out


func note_triggered(area_id: StringName) -> void:
	var key := str(area_id)
	var data: Dictionary = _by_area_id.get(key, {}) as Dictionary
	if data.is_empty():
		_last_triggered = {"ok": false, "area_id": key, "reason": "area id missing"}
		return
	_last_triggered = data.duplicate(true)
	_last_triggered["ok"] = true
	_last_triggered["event"] = "triggered"
	_last_triggered["msec"] = Time.get_ticks_msec()


func get_last_triggered() -> Dictionary:
	return _last_triggered.duplicate(true)


func status() -> Dictionary:
	var targets := 0
	for item in _static_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("target_zone", -1)) >= 0:
			targets += 1
	return {
		"scope": "P1-14A ZoneJumpRuntime",
		"entries": _static_index.size(),
		"targets": targets,
		"zones": _by_zone.keys(),
		"areas_known": _areas.size(),
		"areas_wired": _wire_count,
		"last_triggered": get_last_triggered(),
	}


func entries_for_zone(zone_num: int) -> Array:
	return (_by_zone.get(zone_num, []) as Array).duplicate(true)


func _rebuild_maps() -> void:
	_by_zone.clear()
	_by_area_id.clear()
	for item in _static_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		var zone_entries: Array = _by_zone.get(z, []) as Array
		zone_entries.append(d)
		_by_zone[z] = zone_entries
		var area_id := str(d.get("area_id", ""))
		if area_id != "":
			_by_area_id[area_id] = d


func _on_area_body_entered(body: Node, area: Area3D) -> void:
	var data := _event_from_area("entered", area, Time.get_ticks_msec())
	note_triggered(StringName(str(data.get("area_id", ""))))
	emit_signal("zonejump_body_entered", body, data)


func _on_area_body_exited(body: Node, area: Area3D) -> void:
	var data := _event_from_area("exited", area, Time.get_ticks_msec())
	emit_signal("zonejump_body_exited", body, data)


func _event_from_area(event_name: String, area: Area3D, msec: int) -> Dictionary:
	var area_id := str(area.get_meta("daoc_zonejump_area_id", ""))
	var index_data: Dictionary = _by_area_id.get(area_id, {}) as Dictionary
	var out := index_data.duplicate(true)
	out["scope"] = "P1-14A ZoneJumpRuntime signal event"
	out["event"] = event_name
	out["msec"] = msec
	out["area_id"] = area_id
	out["zone"] = int(area.get_meta("zone", int(out.get("source_zone", -1))))
	out["id"] = int(area.get_meta("id", int(out.get("id", -1))))
	out["name"] = str(area.get_meta("name", str(out.get("name", ""))))
	out["target"] = int(area.get_meta("target", int(out.get("target_zone", -1))))
	out["extra1"] = str(area.get_meta("extra1", str(out.get("extra1", ""))))
	out["extra2"] = str(area.get_meta("extra2", str(out.get("extra2", ""))))
	out["source"] = str(area.get_meta("source", str(out.get("source", ""))))
	out["raw_a"] = area.get_meta("raw_a", out.get("a", Vector2.ZERO))
	out["raw_b"] = area.get_meta("raw_b", out.get("b", Vector2.ZERO))
	return out


func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)
