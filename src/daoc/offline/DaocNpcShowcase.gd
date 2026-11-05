extends RefCounted
class_name DaocNpcShowcase

const ROOT_NAME := "NpcShowcaseRoot"

var root: Node3D
var last_report: Dictionary = {}


func build(host: Node3D, manifest_path: String, overrides: Dictionary = {}) -> Dictionary:
	clear(host)
	var manifest := _read_json(manifest_path)
	if manifest.is_empty():
		last_report = {"ok": false, "error": "manifest_unreadable", "manifest_path": manifest_path}
		return last_report
	var zone_data := manifest.get("zone", {}) as Dictionary
	var placement := manifest.get("placement", {}) as Dictionary
	var zone_id := int(overrides.get("zone", zone_data.get("id", 0)))
	var origin := Vector2(
		float(overrides.get("origin_x", (placement.get("origin_daoc_xy", [0.0, 0.0]) as Array)[0])),
		float(overrides.get("origin_y", (placement.get("origin_daoc_xy", [0.0, 0.0]) as Array)[1]))
	)
	var spacing_raw := float(overrides.get("spacing_raw", placement.get("spacing_raw", 200.0)))
	var source_units_per_meter := float(overrides.get("source_units_per_meter", placement.get("source_units_per_meter", 100.0)))
	var columns := maxi(1, int(overrides.get("columns", placement.get("columns", 3))))
	var labels_visible := bool(overrides.get("labels_visible", true))
	var fallback_floor_z := float(overrides.get("fallback_floor_z", zone_data.get("center_height_raw", 0.0)))
	var face_yaw := float(overrides.get("face_yaw_degrees", placement.get("face_yaw_degrees", 180.0)))

	root = Node3D.new()
	root.name = ROOT_NAME
	host.add_child(root)
	root.set_meta("offline_only", true)
	root.set_meta("manifest_path", manifest_path)
	root.set_meta("zone_id", zone_id)
	root.set_meta("spacing_raw", spacing_raw)

	var entries := manifest.get("entries", []) as Array
	var instanced_ids: Array[int] = []
	var missing_ids: Array[int] = []
	var positions: Array[Dictionary] = []
	var stripped_helpers := 0
	var animations_started := 0
	for index in entries.size():
		var entry := entries[index] as Dictionary
		var model_id := int(entry.get("model_id", -1))
		var scene_path := str(entry.get("scene", ""))
		var row := index / columns
		var column := index % columns
		var daoc_x := origin.x + float(row) * spacing_raw
		var daoc_y := origin.y + (float(column) - float(columns - 1) * 0.5) * spacing_raw
		var floor_z := _sample_floor(host, zone_id, daoc_x, daoc_y, fallback_floor_z)
		var wrapper := Node3D.new()
		wrapper.name = "NPC_%04d_%s" % [model_id, _safe_name(str(entry.get("label", "model")))]
		wrapper.position = _to_godot(host, zone_id, daoc_x, daoc_y, floor_z)
		wrapper.rotation_degrees.y = face_yaw
		wrapper.set_meta("daoc_model_id", model_id)
		wrapper.set_meta("daoc_status", str(entry.get("status", "UNKNOWN")))
		wrapper.set_meta("daoc_scene", scene_path)
		wrapper.set_meta("daoc_grid_row", row)
		wrapper.set_meta("daoc_grid_column", column)
		wrapper.set_meta("daoc_position", Vector3(daoc_x, daoc_y, floor_z))
		root.add_child(wrapper)
		positions.append({"model_id": model_id, "row": row, "column": column, "daoc_x": daoc_x, "daoc_y": daoc_y, "floor_z": floor_z})

		var packed := load(scene_path) as PackedScene
		if packed == null:
			missing_ids.append(model_id)
			_add_missing_marker(wrapper, model_id, labels_visible)
			continue
		var visual := packed.instantiate() as Node3D
		if visual == null:
			missing_ids.append(model_id)
			_add_missing_marker(wrapper, model_id, labels_visible)
			continue
		wrapper.add_child(visual)
		stripped_helpers += _strip_studio_helpers(visual)
		var runtime_scale := float(entry.get("display_scale", 0.02)) * source_units_per_meter
		visual.scale = Vector3.ONE * runtime_scale
		_align_visual_base(visual, wrapper, entry)
		if _play_animation(visual, str(entry.get("default_animation", ""))):
			animations_started += 1
		if labels_visible:
			_add_label(wrapper, visual, "ID %d - %s" % [model_id, str(entry.get("label", "Model"))])
		instanced_ids.append(model_id)

	last_report = {
		"ok": missing_ids.is_empty() and instanced_ids.size() == entries.size(),
		"offline_only": true,
		"zone_id": zone_id,
		"manifest_path": manifest_path,
		"requested": entries.size(),
		"instanced": instanced_ids.size(),
		"instanced_model_ids": instanced_ids,
		"missing_model_ids": missing_ids,
		"spacing_raw": spacing_raw,
		"spacing_meters": spacing_raw / source_units_per_meter,
		"columns": columns,
		"origin_daoc_xy": [origin.x, origin.y],
		"positions": positions,
		"stripped_studio_helpers": stripped_helpers,
		"animations_started": animations_started,
	}
	print("NPC_SHOWCASE=%s" % JSON.stringify(last_report))
	return last_report


func clear(host: Node3D) -> void:
	var previous := host.get_node_or_null(ROOT_NAME)
	if previous != null:
		host.remove_child(previous)
		previous.free()
	root = null
	last_report = {}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _sample_floor(host: Node3D, zone_id: int, daoc_x: float, daoc_y: float, fallback: float) -> float:
	if host.has_method("sample_daoc_floor_z"):
		return float(host.call("sample_daoc_floor_z", zone_id, daoc_x, daoc_y, fallback))
	return fallback


func _to_godot(host: Node3D, zone_id: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	if host.has_method("daoc_to_godot"):
		return host.call("daoc_to_godot", zone_id, daoc_x, daoc_y, daoc_z) as Vector3
	return Vector3(daoc_x, daoc_z, daoc_y)


func _strip_studio_helpers(node: Node) -> int:
	var removed := 0
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is WorldEnvironment or str(child.name) == "ReferenceGround":
			node.remove_child(child)
			child.free()
			removed += 1
		else:
			removed += _strip_studio_helpers(child)
	return removed


## Pose la base du modele sur le sol de son conteneur.
##
## ATTENTION : la boite d'un mesh SKINNE est calculee par Godot en pose de repos
## et surestime largement le personnage. Alignee dessus, une scene skinnee
## s'enfonce ou flotte — le rat y paraissait quatre metres de haut au lieu d'un,
## et le Jinni levitait au-dessus de la parade.
##
## Trois sources, dans cet ordre :
##   1. `base_offset_native` du manifeste — mesure faite par le Character Lab,
##      qui sait skinner ; c'est le seul canal disponible pour les scenes
##      creature, que le client ne recopie pas ;
##   2. la metadonnee `daoc_skinned_aabb_position` des scenes modernes ;
##   3. la boite de mesh, exacte pour les scenes RIGIDES uniquement.
func _align_visual_base(visual: Node3D, wrapper: Node3D, entry: Dictionary = {}) -> void:
	if entry.has("base_offset_native"):
		visual.position.y -= float(entry["base_offset_native"]) * visual.scale.y
		return
	if visual.has_meta("daoc_skinned_aabb_position"):
		var base := (visual.get_meta("daoc_skinned_aabb_position") as Vector3).y
		visual.position.y -= base * visual.scale.y
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	if meshes.is_empty():
		return
	var min_y := INF
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		var to_wrapper := _transform_to_ancestor(mesh_instance, wrapper)
		for corner_index in 8:
			var corner := Vector3(
				aabb.position.x + (aabb.size.x if (corner_index & 1) != 0 else 0.0),
				aabb.position.y + (aabb.size.y if (corner_index & 2) != 0 else 0.0),
				aabb.position.z + (aabb.size.z if (corner_index & 4) != 0 else 0.0)
			)
			min_y = minf(min_y, (to_wrapper * corner).y)
	if is_finite(min_y):
		visual.position.y -= min_y


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _play_animation(node: Node, animation_name: String) -> bool:
	if animation_name.is_empty():
		return false
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		if player.has_animation(animation_name):
			player.play(animation_name)
			return true
	for child in node.get_children():
		if _play_animation(child, animation_name):
			return true
	return false


func _add_label(wrapper: Node3D, visual: Node3D, caption: String) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	var max_y := 160.0
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		var to_wrapper := _transform_to_ancestor(mesh_instance, wrapper)
		for corner_index in 8:
			var corner := Vector3(
				aabb.position.x + (aabb.size.x if (corner_index & 1) != 0 else 0.0),
				aabb.position.y + (aabb.size.y if (corner_index & 2) != 0 else 0.0),
				aabb.position.z + (aabb.size.z if (corner_index & 4) != 0 else 0.0)
			)
			max_y = maxf(max_y, (to_wrapper * corner).y)
	var label := Label3D.new()
	label.name = "ModelLabel"
	label.text = caption
	label.position = Vector3(0.0, max_y + 35.0, 0.0)
	label.font_size = 32
	label.outline_size = 8
	label.pixel_size = 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	wrapper.add_child(label)


func _transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var current := node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _add_missing_marker(wrapper: Node3D, model_id: int, labels_visible: bool) -> void:
	if not labels_visible:
		return
	var label := Label3D.new()
	label.name = "MissingModelLabel"
	label.text = "ID %d - SCENE ABSENTE" % model_id
	label.position.y = 100.0
	label.font_size = 32
	label.outline_size = 8
	label.pixel_size = 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.2, 0.2)
	wrapper.add_child(label)


func _safe_name(value: String) -> String:
	var safe := value.strip_edges().replace(" ", "_").replace("(", "").replace(")", "").replace("-", "_")
	return safe if not safe.is_empty() else "Model"
