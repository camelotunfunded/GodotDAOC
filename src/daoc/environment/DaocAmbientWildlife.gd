extends Node3D
class_name DaocAmbientWildlife

## Faune d'ambiance locale et purement visuelle.
## Quatre MultiMesh suffisent pour les oiseaux, papillons, insectes et, depuis
## le 2026-09-19, les feuilles qui tombent (losanges low poly aux couleurs
## d'automne, chute en spirale, vent et remontee en boucle) :
## aucune collision, aucune IA et aucune synchronisation réseau.

const UPDATE_STEP := 0.08

var _player: Node3D
var _elapsed := 0.0
var _update_accumulator := 0.0
var _birds: MultiMeshInstance3D
var _butterflies: MultiMeshInstance3D
var _insects: MultiMeshInstance3D
var _leaves: MultiMeshInstance3D
var _bird_data: Array[Dictionary] = []
var _butterfly_data: Array[Dictionary] = []
var _insect_data: Array[Dictionary] = []
var _leaf_data: Array[Dictionary] = []
var _tree_anchors: Array[Vector3] = []


func setup(player: Node3D, options: Dictionary = {}) -> Dictionary:
	_player = player
	if _player == null or not is_instance_valid(_player):
		return {"ok": false, "reason": "joueur absent"}

	var economical_mode := bool(options.get("economical_mode", false))
	var bird_count := maxi(0, int(options.get("bird_count", 12 if economical_mode else 24)))
	var butterfly_count := maxi(0, int(options.get("butterfly_count", 8 if economical_mode else 16)))
	var insect_count := maxi(0, int(options.get("insect_count", 36 if economical_mode else 72)))
	var leaf_count := maxi(0, int(options.get("leaf_count", 8 if economical_mode else 18)))
	for value in (options.get("tree_anchors", []) as Array):
		if value is Vector3:
			_tree_anchors.append(value as Vector3)
	if _tree_anchors.is_empty():
		leaf_count = 0
	_birds = _make_group("Oiseaux", _bird_mesh(), bird_count, 6500.0)
	_butterflies = _make_group("Papillons", _butterfly_mesh(), butterfly_count, 1800.0)
	_insects = _make_group("Insectes", _insect_mesh(), insect_count, 1000.0)
	_leaves = _make_group("Feuilles", _leaf_mesh(), leaf_count, 2600.0)
	_seed_motion_data(bird_count, butterfly_count, insect_count, leaf_count)
	global_position = _player.global_position
	_update_instances()
	set_process(true)
	return debug_snapshot()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		set_process(false)
		return
	_elapsed += delta
	_update_accumulator += delta
	# Le lot appartient au décor. Il reste ancré là où il a été créé : le joueur
	# le traverse puis l'abandonne derrière lui.
	if _update_accumulator < UPDATE_STEP:
		return
	_update_accumulator = fmod(_update_accumulator, UPDATE_STEP)
	_update_instances()


func _make_group(group_name: String, mesh: ArrayMesh, count: int, range_end: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = group_name
	instance.multimesh = multimesh
	instance.visibility_range_end = range_end
	add_child(instance)
	return instance


func _seed_motion_data(bird_count: int, butterfly_count: int, insect_count: int, leaf_count: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDA0C51
	for index in bird_count:
		_bird_data.append({
			"phase": rng.randf_range(0.0, TAU),
			"radius": rng.randf_range(1200.0, 3200.0),
			"height": rng.randf_range(650.0, 1450.0),
			"speed": rng.randf_range(0.10, 0.22),
			"scale": rng.randf_range(13.0, 24.0),
		})
	for index in butterfly_count:
		# Quatre petits essaims localises au-dessus de plaques d'herbe, au lieu
		# d'un anneau uniforme qui suit le joueur.
		var patch_angle := float(index % 4) * TAU / 4.0 + rng.randf_range(-0.22, 0.22)
		var patch_distance := rng.randf_range(260.0, 680.0)
		_butterfly_data.append({
			"phase": rng.randf_range(0.0, TAU),
			"patch": Vector2(cos(patch_angle), sin(patch_angle)) * patch_distance,
			"radius": rng.randf_range(24.0, 105.0),
			"height": rng.randf_range(25.0, 95.0),
			"speed": rng.randf_range(0.28, 0.65),
			"scale": rng.randf_range(12.0, 24.0),
		})
	for index in insect_count:
		_insect_data.append({
			"phase": rng.randf_range(0.0, TAU),
			"radius": rng.randf_range(80.0, 420.0),
			"height": rng.randf_range(20.0, 105.0),
			"speed": rng.randf_range(0.55, 1.4),
			"scale": rng.randf_range(18.0, 38.0),
		})
	var leaf_palette := [
		Color(0.80, 0.36, 0.10), Color(0.86, 0.60, 0.14), Color(0.62, 0.22, 0.08),
		Color(0.72, 0.66, 0.18), Color(0.44, 0.52, 0.16),
	]
	for index in leaf_count:
		# Les feuilles sont regroupees en trois bosquets et bien moins nombreuses.
		var tree := _tree_anchors[index % _tree_anchors.size()]
		var grove := Vector2(tree.x, tree.z)
		_leaf_data.append({
			"phase": rng.randf_range(0.0, TAU),
			# Point de depart autour du joueur ; la feuille retombe toujours au
			# meme endroit relatif, donc l'ensemble accompagne la marche sans
			# creation ni destruction.
			"offset": grove + Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0)),
			"height": rng.randf_range(420.0, 1100.0),
			# Vitesse de chute en unites DAoC par seconde : lente, feuille morte.
			"fall": rng.randf_range(55.0, 110.0),
			"sway": rng.randf_range(40.0, 120.0),
			"spin": rng.randf_range(1.2, 3.4),
			"scale": rng.randf_range(9.0, 17.0),
			"colour": leaf_palette[index % leaf_palette.size()],
		})


func _update_instances() -> void:
	_update_birds()
	_update_butterflies()
	_update_insects()
	_update_leaves()


func _update_birds() -> void:
	for index in _bird_data.size():
		var data := _bird_data[index]
		var angle := float(data.phase) + _elapsed * float(data.speed)
		var position := sample_bird_position(index, _elapsed)
		var tangent := Vector3(-sin(angle), 0.04 * cos(angle * 2.1), cos(angle)).normalized()
		var basis := Basis.looking_at(tangent, Vector3.UP).scaled(Vector3.ONE * float(data.scale))
		_birds.multimesh.set_instance_transform(index, Transform3D(basis, position))
		_birds.multimesh.set_instance_color(index, Color(0.16, 0.18, 0.20).lerp(Color(0.34, 0.30, 0.24), float(index % 4) / 3.0))


func sample_bird_position(index: int, time_seconds: float) -> Vector3:
	if index < 0 or index >= _bird_data.size():
		return Vector3.ZERO
	var data := _bird_data[index]
	var angle := float(data.phase) + time_seconds * float(data.speed)
	var radius := float(data.radius)
	return Vector3(cos(angle) * radius, float(data.height) + sin(angle * 2.1) * 90.0, sin(angle) * radius)


func _update_butterflies() -> void:
	for index in _butterfly_data.size():
		var data := _butterfly_data[index]
		var angle := float(data.phase) + _elapsed * float(data.speed)
		var radius := float(data.radius)
		var bob := sin(_elapsed * 4.5 + float(data.phase)) * 14.0
		var patch := data.patch as Vector2
		var position := Vector3(patch.x + cos(angle) * radius, float(data.height) + bob, patch.y + sin(angle * 1.17) * radius)
		var direction := Vector3(-sin(angle), 0.08 * cos(_elapsed * 4.5 + float(data.phase)), cos(angle * 1.17)).normalized()
		var flap := 0.72 + absf(sin(_elapsed * 10.0 + float(data.phase))) * 0.5
		var basis := Basis.looking_at(direction, Vector3.UP).scaled(Vector3.ONE * float(data.scale) * Vector3(flap, 1.0, 1.0))
		_butterflies.multimesh.set_instance_transform(index, Transform3D(basis, position))
		var colors := [Color(0.95, 0.56, 0.12), Color(0.96, 0.86, 0.22), Color(0.36, 0.62, 0.92), Color(0.92, 0.48, 0.68)]
		_butterflies.multimesh.set_instance_color(index, colors[index % colors.size()])


func _update_insects() -> void:
	for index in _insect_data.size():
		var data := _insect_data[index]
		var angle := float(data.phase) + _elapsed * float(data.speed)
		var radius := float(data.radius) * (0.75 + sin(_elapsed * 0.7 + float(data.phase)) * 0.25)
		var position := Vector3(cos(angle) * radius, float(data.height) + sin(_elapsed * 3.2 + float(data.phase)) * 18.0, sin(angle * 1.31) * radius)
		var scale := float(data.scale)
		_insects.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), position))
		_insects.multimesh.set_instance_color(index, Color(0.72, 0.69, 0.38, 0.72))


## Feuilles mortes : chute lente en spirale (balancement + derive du vent),
## rotation sur elles-memes, puis remontee au point de depart. La feuille
## s'efface juste avant le sol pour qu'aucune ne s'arrete en l'air.
func _update_leaves() -> void:
	for index in _leaf_data.size():
		var data := _leaf_data[index]
		var height := float(data.height)
		var phase := float(data.phase)
		var cycle := (height + 40.0) / float(data.fall)
		var t := fmod(_elapsed + phase * cycle / TAU, cycle)
		var y := height - t * float(data.fall)
		var offset := data.offset as Vector2
		var sway := float(data.sway)
		var wind_drift := t * 18.0
		var position := Vector3(
			offset.x + sin(_elapsed * 0.9 + phase) * sway + wind_drift,
			y,
			offset.y + cos(_elapsed * 0.7 + phase * 1.3) * sway * 0.7 + wind_drift * 0.4)
		var spin := float(data.spin)
		var basis := Basis.from_euler(Vector3(
			sin(_elapsed * spin + phase) * 0.9,
			_elapsed * spin * 0.6 + phase,
			cos(_elapsed * spin * 0.8 + phase) * 0.7))
		var fade := clampf(y / 60.0, 0.0, 1.0)
		basis = basis.scaled(Vector3.ONE * float(data.scale) * fade)
		_leaves.multimesh.set_instance_transform(index, Transform3D(basis, position))
		var colour := data.colour as Color
		_leaves.multimesh.set_instance_color(index, colour)


func sample_leaf_height(index: int, time_seconds: float) -> float:
	if index < 0 or index >= _leaf_data.size():
		return 0.0
	var data := _leaf_data[index]
	var cycle := (float(data.height) + 40.0) / float(data.fall)
	var t := fmod(time_seconds + float(data.phase) * cycle / TAU, cycle)
	return float(data.height) - t * float(data.fall)


## Losange a deux faces, nervure marquee par un pli : lisible de loin comme
## une feuille, quatre triangles.
func _leaf_mesh() -> ArrayMesh:
	return _mesh_from_triangles(PackedVector3Array([
		Vector3(0.0, 0.0, -0.55), Vector3(-0.34, -0.06, -0.05), Vector3(0.0, 0.03, 0.0),
		Vector3(0.0, 0.0, -0.55), Vector3(0.0, 0.03, 0.0), Vector3(0.34, -0.06, -0.05),
		Vector3(0.0, 0.03, 0.0), Vector3(-0.34, -0.06, -0.05), Vector3(0.0, 0.0, 0.62),
		Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.0, 0.62), Vector3(0.34, -0.06, -0.05),
	]), Color.WHITE)


func _bird_mesh() -> ArrayMesh:
	return _mesh_from_triangles(PackedVector3Array([
		Vector3(0.0, 0.05, -0.55), Vector3(-0.85, 0.0, 0.18), Vector3(0.0, 0.0, 0.08),
		Vector3(0.0, 0.05, -0.55), Vector3(0.0, 0.0, 0.08), Vector3(0.85, 0.0, 0.18),
		Vector3(0.0, 0.0, 0.08), Vector3(-0.26, 0.0, 0.55), Vector3(0.26, 0.0, 0.55),
	]), Color(0.22, 0.23, 0.24))


func _butterfly_mesh() -> ArrayMesh:
	return _mesh_from_triangles(PackedVector3Array([
		Vector3(0.0, 0.02, -0.16), Vector3(-0.32, 0.0, -0.08), Vector3(-0.08, 0.0, 0.19),
		Vector3(0.0, 0.02, -0.16), Vector3(0.08, 0.0, 0.19), Vector3(0.32, 0.0, -0.08),
		Vector3(-0.025, 0.04, -0.18), Vector3(0.025, 0.04, -0.18), Vector3(0.0, 0.04, 0.22),
	]), Color.WHITE)


func _insect_mesh() -> ArrayMesh:
	return _mesh_from_triangles(PackedVector3Array([
		Vector3(-0.025, 0.0, 0.0), Vector3(0.025, 0.0, 0.0), Vector3(0.0, 0.085, 0.0),
	]), Color.WHITE, true)


func _mesh_from_triangles(vertices: PackedVector3Array, color: Color, transparent := false) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	return mesh


func debug_snapshot() -> Dictionary:
	return {
		"ok": _player != null and is_instance_valid(_player),
		"draw_groups": 4,
		"birds": _bird_data.size(),
		"butterflies": _butterfly_data.size(),
		"insects": _insect_data.size(),
		"leaves": _leaf_data.size(),
		"network_entities": 0,
		"collisions": 0,
		"update_hz": 1.0 / UPDATE_STEP,
		"world_anchored": true,
		"tree_anchors": _tree_anchors.size(),
	}
