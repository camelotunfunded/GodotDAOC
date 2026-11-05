extends RefCounted
class_name DaocGroundingService

const DaocVisualFeetResolverScript = preload("res://src/daoc/player/DaocVisualFeetResolver.gd")

const CHECKPOINT: String = "P1_18P_ACTOR_GROUNDING_VISUAL_FEET_ALIGNMENT"
const DEFAULT_REPORT_DIR: String = "res://reports/p1_18p_actor_grounding"


func probe_ground(player: Node3D, zone_viewer: Node, options: Dictionary = {}) -> Dictionary:
	var out := {
		"checkpoint": CHECKPOINT,
		"ok": false,
		"ground_y": 0.0,
		"terrain_y": null,
		"collision_y": null,
		"ground_source": "none",
		"slope_normal": Vector3.UP,
		"distance_to_ground": 0.0,
		"was_snapped": false,
		"reason": "",
		"player_position_before": Vector3.ZERO,
	}
	if player == null:
		out["reason"] = "missing_player"
		return out
	out["player_position_before"] = player.global_position
	var use_terrain := bool(options.get("grounding_use_terrain", true))
	var use_collision := bool(options.get("grounding_use_collision", true))
	var terrain := _probe_terrain(player, zone_viewer, options) if use_terrain else {"ok": false}
	var collision := _probe_collision(player, options) if use_collision else {"ok": false}
	if bool(terrain.get("ok", false)):
		out["terrain_y"] = float(terrain.get("ground_y", 0.0))
		out["terrain_raw_z"] = float(terrain.get("terrain_raw_z", 0.0))
		out["terrain_center_raw_z"] = float(terrain.get("heightmap_raw_z", 0.0))
		out["terrain_footprint"] = terrain.get("footprint", {})
	if bool(collision.get("ok", false)):
		out["collision_y"] = float(collision.get("ground_y", 0.0))
		out["slope_normal"] = collision.get("normal", Vector3.UP)
	var max_slope := deg_to_rad(float(options.get("grounding_max_walkable_slope_degrees", 50.0)))
	var collision_walkable := bool(collision.get("ok", false)) and _normal_slope_angle(collision.get("normal", Vector3.UP) as Vector3) <= max_slope
	if collision_walkable:
		out["ok"] = true
		out["ground_y"] = float(collision.get("ground_y", 0.0))
		out["ground_source"] = "collision"
	elif bool(terrain.get("ok", false)):
		out["ok"] = true
		out["ground_y"] = float(terrain.get("ground_y", 0.0))
		out["ground_source"] = "terrain"
	else:
		out["reason"] = "no_ground_probe_available"
		return out
	out["distance_to_ground"] = player.global_position.y - float(out["ground_y"])
	return out


func apply_grounding(player: CharacterBody3D, zone_viewer: Node, options: Dictionary = {}) -> Dictionary:
	var report := probe_ground(player, zone_viewer, options)
	if not bool(report.get("ok", false)):
		_write_report(report, options)
		return report
	if bool(options.get("grounding_respect_vertical_velocity", true)) and _read_float_property(player, "vertical_velocity_raw", 0.0) > 0.0:
		report["reason"] = "vertical_velocity_positive_no_snap"
		_write_report(report, options)
		return report
	if not bool(options.get("grounding_snap_enabled", true)):
		report["reason"] = "snap_disabled"
		_write_report(report, options)
		return report
	var actor_offset := float(options.get("grounding_actor_ground_offset", 0.0))
	var target_y := float(report.get("ground_y", player.global_position.y)) + actor_offset
	var delta := target_y - player.global_position.y
	var max_delta := maxf(0.0, float(options.get("grounding_max_snap_delta", 512.0)))
	if absf(delta) > max_delta:
		report["reason"] = "snap_delta_exceeds_limit"
		report["snap_delta"] = delta
		_write_report(report, options)
		return report
	var strength := clampf(float(options.get("grounding_snap_strength", 1.0)), 0.0, 1.0)
	var pos := player.global_position
	pos.y += delta * strength
	player.global_position = pos
	if str(report.get("ground_source", "")) == "terrain" and _has_property(player, "daoc_z"):
		player.set("daoc_z", float(report.get("terrain_raw_z", player.get("daoc_z"))) + actor_offset)
		if player.has_method("_apply_daoc_transform"):
			player.call("_apply_daoc_transform")
	report["was_snapped"] = absf(delta) > 0.001
	report["snap_delta"] = delta
	report["actor_ground_offset"] = actor_offset
	_write_report(report, options)
	return report


func compute_visual_feet_offset(visual_root: Node3D, options: Dictionary = {}) -> Dictionary:
	var mode := str(options.get("feet_alignment_mode", "auto"))
	var out := DaocVisualFeetResolverScript.resolve(visual_root, mode) as Dictionary
	out["checkpoint"] = CHECKPOINT
	return out


func apply_visual_feet_alignment(visual_root: Node3D, options: Dictionary = {}) -> Dictionary:
	var before := compute_visual_feet_offset(visual_root, options)
	var report := before.duplicate(true)
	report["visual_aabb_before"] = {
		"position": before.get("visual_aabb_global_position", Vector3.ZERO),
		"size": before.get("visual_aabb_global_size", Vector3.ZERO),
	}
	report["visual_feet_offset"] = float(options.get("player_visual_feet_offset", 0.0))
	if not bool(before.get("ok", false)):
		# Even when the visual model has no usable AABB yet, keep the report schema
		# complete so F12/CTRL+R can distinguish “alignment unavailable” from
		# “report not produced”.  P1-18P remains non-final and is intentionally
		# diagnostic only until the generated-scene path is the runtime base.
		report["visual_aabb_after"] = {
			"position": before.get("visual_aabb_global_position", Vector3.ZERO),
			"size": before.get("visual_aabb_global_size", Vector3.ZERO),
		}
		report["feet_align_delta"] = 0.0
		_write_report(report, options)
		return report
	var parent := visual_root.get_parent() as Node3D
	var target_y := (parent.global_position.y if parent != null else visual_root.global_position.y) + float(options.get("player_visual_feet_offset", 0.0))
	var delta := target_y - float(before.get("lowest_y", target_y))
	visual_root.position.y += delta
	report["ok"] = true
	report["feet_align_delta"] = delta
	var after := compute_visual_feet_offset(visual_root, options)
	report["visual_aabb_after"] = {
		"position": after.get("visual_aabb_global_position", Vector3.ZERO),
		"size": after.get("visual_aabb_global_size", Vector3.ZERO),
	}
	_write_report(report, options)
	return report


func _probe_terrain(player: Node3D, zone_viewer: Node, options: Dictionary = {}) -> Dictionary:
	if zone_viewer == null or not zone_viewer.has_method("sample_daoc_floor_z"):
		return {"ok": false, "reason": "zone_viewer_missing_sample_daoc_floor_z"}
	var zone := int(_read_float_property(player, "daoc_zone", 0.0))
	var x := _read_float_property(player, "daoc_x", player.global_position.x)
	var y := _read_float_property(player, "daoc_y", player.global_position.z)
	var z := _read_float_property(player, "daoc_z", player.global_position.y)
	var floor_z := float(zone_viewer.call("sample_daoc_floor_z", zone, x, y, z))
	var footprint := _sample_terrain_footprint(zone_viewer, zone, x, y, z, options)
	var actor_floor_z := floor_z
	if player.has_method("_query_floor_z"):
		actor_floor_z = float(player.call("_query_floor_z"))
	var ground_y := floor_z
	if zone_viewer.has_method("daoc_to_godot"):
		var gp: Vector3 = zone_viewer.call("daoc_to_godot", zone, x, y, actor_floor_z) as Vector3
		ground_y = gp.y
	return {
		"ok": true,
		"ground_y": ground_y,
		"terrain_raw_z": actor_floor_z,
		"heightmap_raw_z": floor_z,
		"footprint": footprint,
	}


func _sample_terrain_footprint(zone_viewer: Node, zone: int, x: float, y: float, z: float, options: Dictionary) -> Dictionary:
	if zone_viewer == null or not zone_viewer.has_method("sample_daoc_floor_z"):
		return {}
	var radius := float(options.get("grounding_footprint_radius_raw", 40.0)) * float(options.get("grounding_footprint_radius_factor", 0.85))
	var diag := radius * 0.70710678
	var offsets := [
		Vector2.ZERO,
		Vector2(radius, 0.0),
		Vector2(-radius, 0.0),
		Vector2(0.0, radius),
		Vector2(0.0, -radius),
		Vector2(diag, diag),
		Vector2(-diag, diag),
		Vector2(diag, -diag),
		Vector2(-diag, -diag),
	]
	var samples: Array = []
	var min_z := INF
	var max_z := -INF
	var max_offset := Vector2.ZERO
	for offset in offsets:
		var o := offset as Vector2
		var raw_z := float(zone_viewer.call("sample_daoc_floor_z", zone, x + o.x, y + o.y, z))
		min_z = minf(min_z, raw_z)
		if raw_z > max_z:
			max_z = raw_z
			max_offset = o
		samples.append({
			"dx": o.x,
			"dy": o.y,
			"raw_z": raw_z,
		})
	return {
		"radius_raw": radius,
		"center_raw_z": float(samples[0].get("raw_z", z)) if samples.size() > 0 else z,
		"min_raw_z": min_z,
		"max_raw_z": max_z,
		"delta_raw_z": max_z - min_z,
		"max_offset": max_offset,
		"samples": samples,
	}


func _probe_collision(player: Node3D, options: Dictionary) -> Dictionary:
	var world := player.get_world_3d()
	if world == null:
		return {"ok": false, "reason": "missing_world"}
	var height := float(options.get("grounding_probe_height", 2048.0))
	var depth := float(options.get("grounding_probe_depth", 4096.0))
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0.0, height, 0.0),
		player.global_position - Vector3(0.0, depth, 0.0)
	)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	if options.has("grounding_collision_mask"):
		query.collision_mask = int(options.get("grounding_collision_mask", 0xFFFFFFFF))
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false, "reason": "no_collision_hit"}
	var pos: Vector3 = hit.get("position", player.global_position) as Vector3
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	return {"ok": true, "ground_y": pos.y, "normal": normal, "collider": str(hit.get("collider", ""))}
func _normal_slope_angle(normal: Vector3) -> float:
	if normal.length() <= 0.0001:
		return INF
	return acos(clampf(normal.normalized().dot(Vector3.UP), -1.0, 1.0))


func _read_float_property(obj: Object, property_name: String, fallback: float) -> float:
	if obj == null:
		return fallback
	for info in obj.get_property_list():
		if typeof(info) == TYPE_DICTIONARY and str(info.get("name", "")) == property_name:
			return float(obj.get(property_name))
	return fallback


func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for info in obj.get_property_list():
		if typeof(info) == TYPE_DICTIONARY and str(info.get("name", "")) == property_name:
			return true
	return false


func _write_report(report: Dictionary, options: Dictionary) -> void:
	if not bool(options.get("write_report", true)):
		return
	var dir := str(options.get("report_dir", DEFAULT_REPORT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var json_path := dir.path_join("p1_18p_grounding_report.json")
	var txt_path := dir.path_join("p1_18p_grounding_report.txt")
	var json := FileAccess.open(json_path, FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify(report, "\t"))
		json.close()
	var txt := FileAccess.open(txt_path, FileAccess.WRITE)
	if txt != null:
		txt.store_string(_format_text_report(report))
		txt.close()


func _format_text_report(report: Dictionary) -> String:
	return "\n".join([
		"# P1-18P Actor Grounding & Visual Feet Alignment",
		"ok=%s source=%s reason=%s" % [str(report.get("ok", false)), str(report.get("ground_source", "")), str(report.get("reason", ""))],
		"ground_y=%s terrain_y=%s collision_y=%s distance=%s" % [str(report.get("ground_y", "")), str(report.get("terrain_y", "")), str(report.get("collision_y", "")), str(report.get("distance_to_ground", ""))],
		"snap_delta=%s actor_ground_offset=%s visual_feet_offset=%s" % [str(report.get("snap_delta", "")), str(report.get("actor_ground_offset", "")), str(report.get("visual_feet_offset", ""))],
	]) + "\n"
