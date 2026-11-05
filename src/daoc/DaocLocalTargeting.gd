extends Node
class_name DaocLocalTargeting

## Targeting local client-only.
## Objectif : préparer nearest object / clear target / debug ray sans logique serveur.

@export var nearest_radius_raw: float = 2400.0
@export var debug_targeting: bool = false

var zone_viewer: Node = null
var player: Node = null
var player_camera: Node = null
var current_target: Object = null
var current_target_info: Dictionary = {}
var last_scan_count: int = 0
var last_scan_distance_raw: float = -1.0


func setup(p_zone_viewer: Node, p_player: Node, p_camera: Node) -> void:
	zone_viewer = p_zone_viewer
	player = p_player
	player_camera = p_camera


func clear_target() -> void:
	current_target = null
	current_target_info = {}
	last_scan_distance_raw = -1.0
	if debug_targeting:
		print("daoc target cleared")


func target_nearest_object(radius_raw: float = -1.0, print_log: bool = true) -> bool:
	var r := nearest_radius_raw if radius_raw <= 0.0 else radius_raw
	last_scan_count = 0
	last_scan_distance_raw = -1.0
	current_target = null
	current_target_info = {}
	if zone_viewer == null or player == null:
		return false

	var pzone := int(player.get("daoc_zone"))
	var px := float(player.get("daoc_x"))
	var py := float(player.get("daoc_y"))
	var props: Dictionary = zone_viewer.get("_prop_collision_runtime") as Dictionary
	var arr: Array = props.get(pzone, []) as Array
	var best: Dictionary = {}
	var best_dist := INF
	for item in arr:
		var d: Dictionary = item as Dictionary
		if not bool(d.get("has_daoc_aabb", false)):
			continue
		last_scan_count += 1
		var mn: Vector3 = d.get("daoc_min", Vector3.ZERO) as Vector3
		var mx: Vector3 = d.get("daoc_max", Vector3.ZERO) as Vector3
		var cx := (mn.x + mx.x) * 0.5
		var cy := (mn.y + mx.y) * 0.5
		var dist := Vector2(px, py).distance_to(Vector2(cx, cy))
		if dist < best_dist and dist <= r:
			best_dist = dist
			best = d
	if best.is_empty():
		if print_log:
			print("target nearest: none within %.1f raw units, scanned=%d" % [r, last_scan_count])
		return false

	current_target = best.get("body", null) as Object
	last_scan_distance_raw = best_dist
	current_target_info = {
		"kind": "prop_collision",
		"zone": pzone,
		"fixture_id": int(best.get("fixture_id", 0)),
		"nif_id": int(best.get("nif_id", -1)),
		"file": str(best.get("file", "")),
		"distance_raw": best_dist,
	}
	if print_log:
		print("target nearest: fixture=%s file=%s dist=%.1f" % [str(current_target_info.get("fixture_id", "?")), str(current_target_info.get("file", "")), best_dist])
	return true


func target_zonejump_nearest(radius_raw: float = 1600.0, print_log: bool = true) -> bool:
	current_target = null
	current_target_info = {}
	last_scan_distance_raw = -1.0
	if zone_viewer == null or player == null:
		return false
	var pzone := int(player.get("daoc_zone"))
	var pp := Vector2(float(player.get("daoc_x")), float(player.get("daoc_y")))

	# P1-14A hotfix: _zonejump_runtime is now DaocZoneJumpRuntime, not the old
	# Dictionary keyed by zone. Prefer the ZoneViewer facade so targeting does not
	# depend on the concrete runtime layout. Keep a legacy fallback for old zips.
	var nearest: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"):
		nearest = zone_viewer.call("get_zonejump_nearest_debug_snapshot", radius_raw) as Dictionary
	else:
		nearest = _legacy_zonejump_nearest(pzone, pp, radius_raw)

	if not bool(nearest.get("ok", false)):
		if print_log:
			print("target nearest zonejump: none within %.1f raw units reason=%s" % [radius_raw, str(nearest.get("reason", "none"))])
		return false

	last_scan_distance_raw = float(nearest.get("distance_raw", -1.0))
	current_target_info = {
		"kind": "zonejump",
		"zone": pzone,
		"id": int(nearest.get("id", -1)),
		"name": str(nearest.get("name", "")),
		"target": int(nearest.get("target", nearest.get("target_zone", -1))),
		"distance_raw": last_scan_distance_raw,
		"radius_raw": float(nearest.get("radius_raw", radius_raw)),
		"transition_deferred": bool(nearest.get("transition_deferred", true)),
		"transition_allowed": bool(nearest.get("transition_allowed", false)),
	}
	if print_log:
		print("target nearest zonejump: id=%s name=%s target=%s dist=%.1f" % [str(current_target_info.get("id", "?")), str(current_target_info.get("name", "")), str(current_target_info.get("target", "")), last_scan_distance_raw])
	return true


func _legacy_zonejump_nearest(pzone: int, pp: Vector2, radius_raw: float) -> Dictionary:
	var raw: Variant = zone_viewer.get("_zonejump_runtime")
	if raw is Dictionary:
		var zjs: Dictionary = raw as Dictionary
		var entries: Array = zjs.get(pzone, []) as Array
		var best: Dictionary = {}
		var best_dist := INF
		for e in entries:
			var d: Dictionary = e as Dictionary
			var a: Vector2 = d.get("a", Vector2.ZERO) as Vector2
			var b: Vector2 = d.get("b", Vector2.ZERO) as Vector2
			var dist := _distance_to_segment(pp, a, b)
			if dist < best_dist and dist <= radius_raw:
				best_dist = dist
				best = d
		if best.is_empty():
			return {"ok": false, "reason": "none within radius", "zone": pzone, "radius_raw": radius_raw}
		var out := best.duplicate(true)
		out["ok"] = true
		out["distance_raw"] = best_dist
		out["radius_raw"] = radius_raw
		return out
	if raw is Object:
		var runtime: Object = raw as Object
		if not runtime.has_method("nearest_daoc"):
			return {"ok": false, "reason": "zonejump runtime missing nearest_daoc", "zone": pzone, "radius_raw": radius_raw}
		var near: Dictionary = runtime.call("nearest_daoc", pzone, pp) as Dictionary
		if not bool(near.get("ok", false)):
			near["radius_raw"] = radius_raw
			return near
		var dist2 := float(near.get("distance_raw", INF))
		if dist2 > radius_raw:
			return {"ok": false, "reason": "none within radius", "zone": pzone, "radius_raw": radius_raw, "entry_count": int(near.get("entry_count", 0))}
		near["radius_raw"] = radius_raw
		return near
	return {"ok": false, "reason": "zonejump runtime missing", "zone": pzone, "radius_raw": radius_raw}


func get_target_debug_string() -> String:
	if current_target_info.is_empty():
		return "target=none scan=%d" % last_scan_count
	return "target=%s dist=%.1f data=%s" % [str(current_target_info.get("kind", "?")), float(current_target_info.get("distance_raw", -1.0)), str(current_target_info)]


func get_debug_snapshot() -> Dictionary:
	return {
		"has_zone_viewer": zone_viewer != null,
		"has_player": player != null,
		"nearest_radius_raw": nearest_radius_raw,
		"last_scan_count": last_scan_count,
		"last_scan_distance_raw": last_scan_distance_raw,
		"has_target": not current_target_info.is_empty(),
		"target": current_target_info,
	}


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)
