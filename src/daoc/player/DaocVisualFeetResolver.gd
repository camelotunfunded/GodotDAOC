extends RefCounted


static func resolve(visual_root: Node3D, mode: String = "auto") -> Dictionary:
	var out := {
		"ok": false,
		"source": "none",
		"lowest_y": 0.0,
		"anchors": [],
		"visual_aabb_global_position": Vector3.ZERO,
		"visual_aabb_global_size": Vector3.ZERO,
		"reason": "",
	}
	if visual_root == null:
		out["reason"] = "missing_visual_root"
		return out
	var normalized_mode := mode.strip_edges().to_lower()
	if normalized_mode != "aabb" and normalized_mode != "skeleton":
		normalized_mode = "auto"
	var aabb_report := _global_visual_aabb(visual_root)
	if bool(aabb_report.get("ok", false)):
		var aabb := aabb_report.get("aabb", AABB()) as AABB
		out["visual_aabb_global_position"] = aabb.position
		out["visual_aabb_global_size"] = aabb.size
	if normalized_mode != "aabb":
		var skeleton_report := _skeleton_feet(visual_root)
		if bool(skeleton_report.get("ok", false)):
			for key in skeleton_report.keys():
				out[key] = skeleton_report[key]
			return out
		if normalized_mode == "skeleton":
			out["reason"] = str(skeleton_report.get("reason", "skeleton_feet_unavailable"))
			return out
	if bool(aabb_report.get("ok", false)):
		var fallback_aabb := aabb_report.get("aabb", AABB()) as AABB
		out["ok"] = true
		out["source"] = "mesh_aabb"
		out["lowest_y"] = fallback_aabb.position.y
		out["reason"] = ""
		return out
	if str(out.get("reason", "")) == "":
		out["reason"] = "empty_visual_aabb"
	return out


static func _skeleton_feet(root: Node3D) -> Dictionary:
	var toe_anchors: Array[Dictionary] = []
	var foot_anchors: Array[Dictionary] = []
	for child in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := child as Skeleton3D
		if skeleton == null or not _is_visible_through_parents(skeleton, root):
			continue
		for bone_idx in range(skeleton.get_bone_count()):
			var bone_name := skeleton.get_bone_name(bone_idx)
			var lower_name := bone_name.to_lower()
			if "footsteps" in lower_name:
				continue
			var point := (skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)).origin
			var anchor := {"bone": bone_name, "bone_index": bone_idx, "position": point}
			if "toe" in lower_name:
				toe_anchors.append(anchor)
			elif "foot" in lower_name:
				foot_anchors.append(anchor)
	var anchors := toe_anchors if not toe_anchors.is_empty() else foot_anchors
	if anchors.is_empty():
		return {"ok": false, "reason": "no_visible_foot_bones"}
	var lowest_y := INF
	for anchor in anchors:
		lowest_y = minf(lowest_y, float((anchor.get("position", Vector3.ZERO) as Vector3).y))
	return {
		"ok": true,
		"source": "skeleton_toes" if not toe_anchors.is_empty() else "skeleton_feet",
		"lowest_y": lowest_y,
		"anchors": anchors,
		"reason": "",
	}


static func _global_visual_aabb(root: Node3D) -> Dictionary:
	var out := AABB()
	var has := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or not _is_visible_through_parents(mi, root):
			continue
		var local := mi.mesh.get_aabb()
		for corner in _corners(local):
			var point := AABB(mi.global_transform * corner, Vector3.ZERO)
			out = out.merge(point) if has else point
			has = true
	return {"ok": has, "aabb": out}


static func _corners(aabb: AABB) -> Array[Vector3]:
	return [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]


static func _is_visible_through_parents(node: Node, stop_at: Node) -> bool:
	var current := node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		if current == stop_at:
			return true
		current = current.get_parent()
	return false
