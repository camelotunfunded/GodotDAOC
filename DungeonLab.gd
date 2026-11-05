extends Node3D

## P1-17C1 — DungeonLab cible configurable.
##
## Mithra zone021 reste la cible de contrôle par défaut, mais le build donjon
## n'est plus codé pour Mithra uniquement. Le même builder sert à ZoneCreator.

const SCOPE: String = "P1-17C1 DungeonLab configurable dungeon target"
const CHECKPOINT: String = "P1_17C1_DUNGEONLAB_CONFIGURABLE_TARGET"

const DungeonSceneBuilderScript: Script = preload("res://src/daoc/dungeon/DaocDungeonSceneBuilder.gd")
const FileResolverScript: Script = preload("res://src/daoc/dungeon/DaocDungeonFileResolver.gd")

@export var daoc_client_root: String = ""
@export var default_test_zone_id: int = 21
@export var default_test_zone_name: String = "Tomb of Mithra"
@export var source_region_hint: String = "DungeonLab configurable default: Tomb of Mithra / Tombe de Mithra (zone021)"
@export var previous_wrong_target_note: String = "P1-17C1 keeps Mithra as clean regression target while removing hardcoded builder assumptions"
@export var world_scale: float = 0.10
@export var placeholder_extent: float = 90.0
@export var try_runtime_nif_preview: bool = true
@export var nif_preview_scale: float = 0.10
@export var link_runtime_textures: bool = true
@export var texture_alpha_scissor: float = 0.5
@export var build_runtime_collisions: bool = true
@export var collision_shape_mode: String = "trimesh"
@export var show_debug_footprints: bool = false
@export var show_debug_axes: bool = false
@export var show_debug_labels: bool = false
@export var show_portal_debug: bool = true
@export var show_light_debug: bool = false
@export var enable_player_collision_test: bool = true
@export var auto_player_spawn_from_dungeon: bool = true
@export var player_spawn_instance_index: int = 0
@export var player_spawn_position: Vector3 = Vector3(0.0, 8.0, 0.0)
@export var player_spawn_height_offset: float = 18.0
@export var player_floor_snap_height: float = 220.0
@export var player_floor_snap_depth: float = 620.0
@export var player_reset_if_below_y: float = -80.0
@export var player_freeze_until_floor_found: bool = true
@export var player_input_layout: String = "azerty"
@export var player_allow_arrow_keys: bool = true
@export var player_allow_qwerty_fallback: bool = false
@export var player_start_in_ghost_mode: bool = true
@export var player_ghost_move_speed: float = 36.0
@export var player_ghost_vertical_speed: float = 30.0
@export var player_hide_capsule_in_ghost: bool = true
@export var player_camera_ghost_eye_height: float = 1.35
@export var player_camera_ghost_pitch_deg: float = 0.0
@export var player_camera_collision_back: float = 6.0
@export var player_camera_collision_height: float = 3.2
@export var player_capsule_radius: float = 1.25
@export var player_capsule_height: float = 4.25
@export var player_move_speed: float = 18.0
@export var player_run_multiplier: float = 1.8
@export var player_turn_speed_deg: float = 120.0
@export var player_jump_speed: float = 13.0
@export var player_gravity: float = 42.0
@export var player_probe_length: float = 18.0
@export var auto_write_player_report_interval: float = 1.0
@export var auto_build_on_ready: bool = true
@export var print_report_on_ready: bool = true
@export var auto_write_report_on_build: bool = true

const REPORT_PATH: String = "user://daoc_dungeon_lab_report.txt"
const JSON_REPORT_PATH: String = "user://daoc_dungeon_lab_report.json"
const INVALID_PLAYER_SPAWN: Vector3 = Vector3(1.0e30, 1.0e30, 1.0e30)

var _dungeon_root: Node3D = null
var _player_body: CharacterBody3D = null
var _player_yaw: float = 0.0
var _player_report_timer: float = 0.0
var _player_spawn_resolved: Vector3 = Vector3.ZERO
var _player_ghost_mode: bool = false
var _player_floor_snapped: bool = false
var _player_snap_attempts: int = 0
var _player_last_snap_reason: String = ""
var _last_status: Dictionary = {}


func _ready() -> void:
	if daoc_client_root.strip_edges() == "":
		daoc_client_root = FileResolverScript.default_client_root()
	_ensure_camera_and_light()
	if auto_build_on_ready:
		build_default_dungeon()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			build_default_dungeon()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F10:
			_update_player_status()
			write_report()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			_toggle_player_ghost_mode()
			_update_player_status()
			write_report()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			show_portal_debug = not show_portal_debug
			build_default_dungeon()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_player_collision_test(delta)


func build_default_dungeon() -> Dictionary:
	return build_dungeon(default_test_zone_id, default_test_zone_name)


func build_dungeon(zone_id: int, zone_name: String) -> Dictionary:
	_clear_existing_dungeon()
	var builder: Object = DungeonSceneBuilderScript.new()
	var metadata: Dictionary = {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"generated_scene_type": "DungeonLabRuntime",
		"source_region_hint": source_region_hint,
		"previous_wrong_target_note": previous_wrong_target_note,
	}
	var result: Dictionary = builder.call("build", daoc_client_root, zone_id, zone_name, world_scale, placeholder_extent, try_runtime_nif_preview, nif_preview_scale, link_runtime_textures, texture_alpha_scissor, build_runtime_collisions, collision_shape_mode, show_debug_footprints, show_debug_axes, show_debug_labels, show_portal_debug, show_light_debug, metadata) as Dictionary
	_dungeon_root = result.get("root", null) as Node3D
	if _dungeon_root != null:
		add_child(_dungeon_root)
	_last_status = result.get("status", {}) as Dictionary
	_last_status["source_region_hint"] = source_region_hint
	_last_status["previous_wrong_target_note"] = previous_wrong_target_note
	_setup_player_collision_test()
	_update_player_status()
	if print_report_on_ready:
		print(_summary_line(_last_status))
	if auto_write_report_on_build:
		write_report()
	else:
		print("DungeonLab report: %s" % report_path())
	return _last_status


func get_status_snapshot() -> Dictionary:
	return _last_status.duplicate(true)


func report_path() -> String:
	return REPORT_PATH


func json_report_path() -> String:
	return JSON_REPORT_PATH


func report_directory() -> String:
	return ProjectSettings.globalize_path("user://")


func write_report() -> String:
	_update_player_status()
	_write_report_files(true)
	return report_path()


func _write_json_report() -> void:
	var path: String = json_report_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("DungeonLab: cannot write json report %s" % path)
		return
	f.store_string(JSON.stringify(_last_status, "  "))
	f.close()


func _clear_existing_dungeon() -> void:
	if _player_body != null and is_instance_valid(_player_body):
		_player_body.queue_free()
		_player_body = null
	if _dungeon_root != null and is_instance_valid(_dungeon_root):
		_dungeon_root.queue_free()
		_dungeon_root = null


func _setup_player_collision_test() -> void:
	_player_report_timer = 0.0
	if not enable_player_collision_test:
		_last_status["player_collision_test"] = {
			"enabled": false,
			"spawned": false,
			"reason": "disabled",
		}
		return
	_player_yaw = 0.0
	_player_ghost_mode = player_start_in_ghost_mode
	_player_floor_snapped = false
	_player_snap_attempts = 0
	_player_last_snap_reason = "pending"
	_player_spawn_resolved = _resolve_player_spawn_position()
	_player_body = CharacterBody3D.new()
	_player_body.name = "DungeonLabPlayerCapsule"
	_player_body.position = _player_spawn_resolved
	_player_body.safe_margin = 0.02
	_player_body.collision_layer = 1
	_player_body.collision_mask = 0 if _player_ghost_mode else 1
	_player_body.add_to_group("daoc_dungeon_player")
	_player_body.add_to_group("daoc_dungeon_collision_test")

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "PlayerCollisionCapsule"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = maxf(player_capsule_radius, 0.1)
	capsule.height = maxf(player_capsule_height, player_capsule_radius * 2.1)
	shape_node.shape = capsule
	_player_body.add_child(shape_node)

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "PlayerDebugCapsule"
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = capsule.radius
	mesh.height = capsule.height
	visual.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.75, 1.0, 0.70)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = mat
	_player_body.add_child(visual)

	var probe: RayCast3D = RayCast3D.new()
	probe.name = "FloorProbe"
	probe.enabled = true
	probe.target_position = Vector3.DOWN * maxf(player_probe_length, 1.0)
	probe.collision_mask = 1
	_player_body.add_child(probe)

	var pivot: Node3D = Node3D.new()
	pivot.name = "PlayerCameraPivot"
	pivot.position = Vector3.ZERO
	_player_body.add_child(pivot)
	var camera: Camera3D = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	pivot.add_child(camera)

	add_child(_player_body)
	_apply_player_observer_mode()
	call_deferred("_snap_player_to_available_floor")
	_update_player_status()


func _resolve_player_spawn_position() -> Vector3:
	if not auto_player_spawn_from_dungeon:
		return player_spawn_position
	var p: Vector3 = _placement_position_for_instance(player_spawn_instance_index)
	if p == INVALID_PLAYER_SPAWN:
		return player_spawn_position
	return p + Vector3.UP * maxf(player_spawn_height_offset, 0.0)


func _placement_position_for_instance(instance_index: int) -> Vector3:
	var places: Dictionary = _last_status.get("place_result", {}) as Dictionary
	var placements: Array = places.get("placements", []) as Array
	for value in placements:
		var p: Dictionary = value as Dictionary
		if int(p.get("instance_index", -1)) == instance_index:
			# Meme transformation que DaocDungeonSceneBuilder HF3 :
			# Godot.x = DAoC.x ; Godot.y = DAoC.z ; Godot.z = -DAoC.y.
			return Vector3(
				float(p.get("x", 0.0)) * world_scale,
				float(p.get("z", 0.0)) * world_scale,
				-float(p.get("y", 0.0)) * world_scale
			)
	return INVALID_PLAYER_SPAWN


func _snap_player_to_available_floor() -> bool:
	if _player_body == null or not is_instance_valid(_player_body):
		return false
	if _player_floor_snapped:
		return true
	_player_snap_attempts += 1
	var candidates: Array = _player_floor_snap_candidates()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for base_value in candidates:
		var base: Vector3 = base_value as Vector3
		var offsets: Array = [
			Vector3.ZERO,
			Vector3(4.0, 0.0, 0.0),
			Vector3(-4.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 4.0),
			Vector3(0.0, 0.0, -4.0),
			Vector3(8.0, 0.0, 0.0),
			Vector3(-8.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 8.0),
			Vector3(0.0, 0.0, -8.0),
		]
		for offset_value in offsets:
			var offset: Vector3 = offset_value as Vector3
			var from: Vector3 = base + offset + Vector3.UP * maxf(player_floor_snap_height, 1.0)
			var to: Vector3 = base + offset - Vector3.UP * maxf(player_floor_snap_depth, 1.0)
			var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
			params.collision_mask = 1
			params.exclude = [_player_body.get_rid()]
			var hit: Dictionary = space.intersect_ray(params)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit.get("position", base) as Vector3
				_player_body.global_position = hit_pos + Vector3.UP * (maxf(player_capsule_height, player_capsule_radius * 2.1) * 0.5 + 0.08)
				_player_body.velocity = Vector3.ZERO
				_player_floor_snapped = true
				_player_last_snap_reason = "ray_hit"
				return true
	_player_last_snap_reason = "no_floor_hit"
	return false


func _player_floor_snap_candidates() -> Array:
	var out: Array = []
	if _player_spawn_resolved != Vector3.ZERO:
		out.append(_player_spawn_resolved)
	var preferred: Vector3 = _placement_position_for_instance(player_spawn_instance_index)
	if preferred != INVALID_PLAYER_SPAWN:
		out.append(preferred + Vector3.UP * maxf(player_spawn_height_offset, 0.0))
	for idx in [1, 3, 0, 2, 4, 5]:
		var p: Vector3 = _placement_position_for_instance(int(idx))
		if p != INVALID_PLAYER_SPAWN:
			out.append(p + Vector3.UP * maxf(player_spawn_height_offset, 0.0))
	return out


func _toggle_player_ghost_mode() -> void:
	_player_ghost_mode = not _player_ghost_mode
	if _player_body != null and is_instance_valid(_player_body):
		_player_body.collision_mask = 0 if _player_ghost_mode else 1
		_player_body.velocity = Vector3.ZERO
		_apply_player_observer_mode()
	_player_last_snap_reason = "ghost_on" if _player_ghost_mode else "ghost_off"


func _apply_player_observer_mode() -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
	var visual: MeshInstance3D = _player_body.get_node_or_null("PlayerDebugCapsule") as MeshInstance3D
	if visual != null:
		visual.visible = not (_player_ghost_mode and player_hide_capsule_in_ghost)
	var pivot: Node3D = _player_body.get_node_or_null("PlayerCameraPivot") as Node3D
	if pivot == null:
		return
	var camera: Camera3D = pivot.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		return
	if _player_ghost_mode:
		pivot.position = Vector3(0.0, maxf(player_camera_ghost_eye_height, 0.1), 0.0)
		camera.position = Vector3.ZERO
		camera.rotation_degrees = Vector3(player_camera_ghost_pitch_deg, 0.0, 0.0)
	else:
		pivot.position = Vector3(0.0, maxf(player_camera_collision_height, 0.1), 0.0)
		camera.position = Vector3(0.0, 0.0, maxf(player_camera_collision_back, 0.1))
		camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	camera.current = true


func _key_ghost_down_pressed() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)

func _key_forward_pressed() -> bool:
	if player_input_layout.strip_edges().to_lower() == "qwerty":
		return Input.is_key_pressed(KEY_W) or (player_allow_arrow_keys and Input.is_key_pressed(KEY_UP))
	return Input.is_key_pressed(KEY_Z) or (player_allow_arrow_keys and Input.is_key_pressed(KEY_UP)) or (player_allow_qwerty_fallback and Input.is_key_pressed(KEY_W))


func _key_backward_pressed() -> bool:
	return Input.is_key_pressed(KEY_S) or (player_allow_arrow_keys and Input.is_key_pressed(KEY_DOWN))


func _key_turn_left_pressed() -> bool:
	if player_input_layout.strip_edges().to_lower() == "qwerty":
		return Input.is_key_pressed(KEY_A)
	return Input.is_key_pressed(KEY_Q)


func _key_turn_right_pressed() -> bool:
	return Input.is_key_pressed(KEY_D)


func _key_strafe_left_pressed() -> bool:
	if player_input_layout.strip_edges().to_lower() == "qwerty":
		return Input.is_key_pressed(KEY_Q)
	return Input.is_key_pressed(KEY_A)


func _key_strafe_right_pressed() -> bool:
	return Input.is_key_pressed(KEY_E)


func _update_player_ghost_movement(delta: float) -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
	var turn_axis: float = 0.0
	if _key_turn_left_pressed():
		turn_axis += 1.0
	if _key_turn_right_pressed():
		turn_axis -= 1.0
	_player_yaw += deg_to_rad(player_turn_speed_deg) * turn_axis * delta
	_player_body.rotation.y = _player_yaw

	var move_axis: float = 0.0
	if _key_forward_pressed():
		move_axis += 1.0
	if _key_backward_pressed():
		move_axis -= 1.0
	var strafe_axis: float = 0.0
	if _key_strafe_left_pressed():
		strafe_axis -= 1.0
	if _key_strafe_right_pressed():
		strafe_axis += 1.0
	var vertical_axis: float = 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vertical_axis += 1.0
	if _key_ghost_down_pressed():
		vertical_axis -= 1.0
	var local_move: Vector3 = Vector3(strafe_axis, 0.0, -move_axis)
	if local_move.length() > 1.0:
		local_move = local_move.normalized()
	var basis: Basis = _player_body.global_transform.basis
	var world_move: Vector3 = (basis.x * local_move.x) + (basis.z * local_move.z)
	world_move.y = vertical_axis
	if world_move.length() > 1.0:
		world_move = world_move.normalized()
	var speed: float = player_ghost_move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= player_run_multiplier
	_player_body.velocity = world_move * speed
	_player_body.velocity.y = vertical_axis * maxf(player_ghost_vertical_speed, 0.1)
	_player_body.global_position += _player_body.velocity * delta


func _update_player_collision_test(delta: float) -> void:
	if _player_body == null or not is_instance_valid(_player_body):
		return
	if _player_body.global_position.y < player_reset_if_below_y:
		_player_body.global_position = _player_spawn_resolved
		_player_body.velocity = Vector3.ZERO
		_player_floor_snapped = false
		_player_last_snap_reason = "reset_below_y"
		_snap_player_to_available_floor()
	if player_freeze_until_floor_found and not _player_floor_snapped:
		_snap_player_to_available_floor()
		if not _player_floor_snapped:
			_player_body.velocity = Vector3.ZERO
			_update_player_status()
			return
	if _player_ghost_mode:
		_update_player_ghost_movement(delta)
		_player_report_timer += delta
		if auto_write_player_report_interval > 0.0 and _player_report_timer >= auto_write_player_report_interval:
			_player_report_timer = 0.0
			_update_player_status()
			_write_report_files(false)
		return

	var turn_axis: float = 0.0
	if _key_turn_left_pressed():
		turn_axis += 1.0
	if _key_turn_right_pressed():
		turn_axis -= 1.0
	_player_yaw += deg_to_rad(player_turn_speed_deg) * turn_axis * delta
	_player_body.rotation.y = _player_yaw

	var move_axis: float = 0.0
	if _key_forward_pressed():
		move_axis += 1.0
	if _key_backward_pressed():
		move_axis -= 1.0
	var strafe_axis: float = 0.0
	if _key_strafe_left_pressed():
		strafe_axis -= 1.0
	if _key_strafe_right_pressed():
		strafe_axis += 1.0

	var local_move: Vector3 = Vector3(strafe_axis, 0.0, -move_axis)
	if local_move.length() > 1.0:
		local_move = local_move.normalized()
	var basis: Basis = _player_body.global_transform.basis
	var world_move: Vector3 = (basis.x * local_move.x) + (basis.z * local_move.z)
	world_move.y = 0.0
	if world_move.length() > 1.0:
		world_move = world_move.normalized()
	var speed: float = player_move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= player_run_multiplier

	var velocity: Vector3 = _player_body.velocity
	velocity.x = world_move.x * speed
	velocity.z = world_move.z * speed
	if _player_body.is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = player_jump_speed
		else:
			velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= player_gravity * delta
	_player_body.velocity = velocity
	_player_body.move_and_slide()

	_player_report_timer += delta
	if auto_write_player_report_interval > 0.0 and _player_report_timer >= auto_write_player_report_interval:
		_player_report_timer = 0.0
		_update_player_status()
		_write_report_files(false)


func _update_player_status() -> void:
	var report: Dictionary = {
		"enabled": enable_player_collision_test,
		"spawned": false,
		"controls": "AZERTY: Z/S move, Q/D turn, A/E strafe, Shift run, Space up in ghost/jump in collision, Left Ctrl or C down in ghost, F8 toggle portal debug/rebuild, F9 ghost toggle, F10 write report, F12 rebuild",
		"configured_spawn_position": str(player_spawn_position),
		"resolved_spawn_position": str(_player_spawn_resolved),
		"auto_spawn_from_dungeon": auto_player_spawn_from_dungeon,
		"spawn_instance_index": player_spawn_instance_index,
		"floor_snapped": _player_floor_snapped,
		"snap_attempts": _player_snap_attempts,
		"last_snap_reason": _player_last_snap_reason,
		"hotfix_note": "B1/HF5: HF3 transform kept; portal debug forced visible; thick suspicious edge markers enabled",
		"capsule_radius": player_capsule_radius,
		"capsule_height": player_capsule_height,
		"ghost_vertical_speed": player_ghost_vertical_speed,
		"hide_capsule_in_ghost": player_hide_capsule_in_ghost,
		"camera_ghost_eye_height": player_camera_ghost_eye_height,
		"camera_collision_back": player_camera_collision_back,
		"camera_collision_height": player_camera_collision_height,
	}
	if _player_body == null or not is_instance_valid(_player_body):
		report["reason"] = "player body missing"
		_last_status["player_collision_test"] = report
		return
	var probe: RayCast3D = _player_body.get_node_or_null("FloorProbe") as RayCast3D
	var probe_hit: bool = false
	var probe_collider: String = ""
	var probe_point: String = ""
	var probe_distance: float = -1.0
	if probe != null:
		probe.force_raycast_update()
		probe_hit = probe.is_colliding()
		if probe_hit:
			var collider: Object = probe.get_collider()
			if collider != null:
				probe_collider = str(collider)
			var point: Vector3 = probe.get_collision_point()
			probe_point = str(point)
			probe_distance = _player_body.global_position.distance_to(point)
	report["spawned"] = true
	report["position"] = str(_player_body.global_position)
	report["velocity"] = str(_player_body.velocity)
	report["yaw_deg"] = rad_to_deg(_player_yaw)
	report["on_floor"] = _player_body.is_on_floor()
	report["slide_collision_count"] = _player_body.get_slide_collision_count()
	report["floor_probe_hit"] = probe_hit
	report["floor_probe_collider"] = probe_collider
	report["floor_probe_point"] = probe_point
	report["floor_probe_distance"] = probe_distance
	report["collision_layer"] = _player_body.collision_layer
	report["collision_mask"] = _player_body.collision_mask
	report["reset_if_below_y"] = player_reset_if_below_y
	report["freeze_until_floor_found"] = player_freeze_until_floor_found
	report["input_layout"] = player_input_layout
	report["allow_qwerty_fallback"] = player_allow_qwerty_fallback
	report["ghost_mode"] = _player_ghost_mode
	report["ghost_controls"] = "F8 portal debug rebuild; F9 ghost toggle; Z/S/A/E/Q/D; Space up; Left Ctrl or C down"
	_last_status["player_collision_test"] = report


func _write_report_files(verbose: bool) -> void:
	var text_path: String = report_path()
	var f: FileAccess = FileAccess.open(text_path, FileAccess.WRITE)
	if f == null:
		if verbose:
			push_warning("DungeonLab: cannot write report %s" % text_path)
		return
	f.store_string(_format_report(_last_status))
	f.close()
	_write_json_report()
	if verbose:
		print("DungeonLab report dir: %s" % report_directory())
		print("DungeonLab report: %s" % ProjectSettings.globalize_path(text_path))
		print("DungeonLab json report: %s" % ProjectSettings.globalize_path(json_report_path()))


func _ensure_camera_and_light() -> void:
	if get_node_or_null("DungeonLabCamera") == null:
		var camera: Camera3D = Camera3D.new()
		camera.name = "DungeonLabCamera"
		camera.position = Vector3(0.0, 420.0, 520.0)
		camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
		camera.current = true
		add_child(camera)
	if get_node_or_null("DungeonLabSun") == null:
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.name = "DungeonLabSun"
		light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
		light.light_energy = 1.4
		add_child(light)


func _summary_line(status: Dictionary) -> String:
	var chunks: Dictionary = status.get("chunk_result", {}) as Dictionary
	var places: Dictionary = status.get("place_result", {}) as Dictionary
	var portals: Dictionary = status.get("portal_result", {}) as Dictionary
	var lights: Dictionary = status.get("lights_result", {}) as Dictionary
	var player: Dictionary = status.get("player_collision_test", {}) as Dictionary
	return "DungeonLab %s zone=%s %s hint=%s chunks=%d instances=%d portals=%d lights=%d nif_preview=%d fallback=%d nif_fail=%d logical=%d proxy_edges=%d tex=%d/%d miss=%d coll=%d fail=%d player=%s floor=%s probe=%s ok=%s" % [
		CHECKPOINT,
		str(status.get("zone_id", "?")),
		str(status.get("zone_name", "")),
		str(status.get("source_region_hint", "")),
		int(chunks.get("chunk_count", 0)),
		int(places.get("placement_count", 0)),
		int(portals.get("link_count", 0)),
		int(lights.get("light_count", 0)),
		int(status.get("nif_preview_nodes", 0)),
		int(status.get("placeholder_nodes", 0)),
		int(status.get("nif_preview_failures", 0)),
		int(status.get("logical_connector_nodes", 0)),
		int(status.get("connector_proxy_edges", 0)),
		int(status.get("material_textures_resolved", 0)),
		int(status.get("material_texture_requests", 0)),
		int(status.get("material_textures_missing", 0)),
		int(status.get("collision_bodies", 0)),
		int(status.get("collision_failures", 0)),
		str(player.get("spawned", false)),
		str(player.get("on_floor", false)),
		str(player.get("floor_probe_hit", false)),
		str(status.get("ok", false)),
	]


func _join_variant_array(value: Variant) -> String:
	if value is Array:
		var arr: Array = value as Array
		var parts: PackedStringArray = PackedStringArray()
		for item in arr:
			parts.append(str(item))
		return ", ".join(parts)
	return str(value)


func _format_report(status: Dictionary) -> String:
	var lines: Array = []
	var chunks: Dictionary = status.get("chunk_result", {}) as Dictionary
	var places: Dictionary = status.get("place_result", {}) as Dictionary
	var portals: Dictionary = status.get("portal_result", {}) as Dictionary
	var lights: Dictionary = status.get("lights_result", {}) as Dictionary
	lines.append("DAoC DungeonLab local report")
	lines.append("scope=%s" % SCOPE)
	lines.append("checkpoint=%s" % CHECKPOINT)
	lines.append("zone=%s" % str(status.get("zone_id", "?")))
	lines.append("zone_name=%s" % str(status.get("zone_name", "")))
	lines.append("source_region_hint=%s" % str(status.get("source_region_hint", "")))
	lines.append("previous_wrong_target_note=%s" % str(status.get("previous_wrong_target_note", "")))
	lines.append("client_root=%s" % str(status.get("client_root", "")))
	lines.append("dat_folder=%s" % str(status.get("dat_folder", "")))
	lines.append("ok=%s error=%s" % [str(status.get("ok", false)), str(status.get("error", ""))])
	lines.append("")
	lines.append("[counts]")
	lines.append("chunks=%d" % int(chunks.get("chunk_count", 0)))
	lines.append("instances=%d" % int(places.get("placement_count", 0)))
	lines.append("portal_declared=%d" % int(portals.get("declared_count", 0)))
	lines.append("portal_links=%d" % int(portals.get("link_count", 0)))
	lines.append("lights=%d" % int(lights.get("light_count", 0)))
	lines.append("placeholder_nodes=%d" % int(status.get("placeholder_nodes", 0)))
	lines.append("nif_preview_nodes=%d" % int(status.get("nif_preview_nodes", 0)))
	lines.append("nif_preview_failures=%d" % int(status.get("nif_preview_failures", 0)))
	lines.append("logical_connector_nodes=%d" % int(status.get("logical_connector_nodes", 0)))
	lines.append("logical_empty_nif_nodes=%d" % int(status.get("logical_empty_nif_nodes", 0)))
	lines.append("logical_no_mesh_nif_nodes=%d" % int(status.get("logical_no_mesh_nif_nodes", 0)))
	lines.append("connector_proxy_nodes=%d" % int(status.get("connector_proxy_nodes", 0)))
	lines.append("connector_proxy_edges=%d" % int(status.get("connector_proxy_edges", 0)))
	lines.append("try_runtime_nif_preview=%s" % str(status.get("try_runtime_nif_preview", false)))
	lines.append("nif_preview_scale=%.4f" % float(status.get("nif_preview_scale", 0.0)))
	lines.append("nif_converter_mode=%s" % str(status.get("nif_converter_mode", "")))
	lines.append("link_runtime_textures=%s" % str(status.get("link_runtime_textures", false)))
	lines.append("build_runtime_collisions=%s" % str(status.get("build_runtime_collisions", false)))
	lines.append("collision_shape_mode=%s" % str(status.get("collision_shape_mode", "")))
	lines.append("show_debug_footprints=%s" % str(status.get("show_debug_footprints", false)))
	lines.append("show_debug_axes=%s" % str(status.get("show_debug_axes", false)))
	lines.append("show_debug_labels=%s" % str(status.get("show_debug_labels", false)))
	lines.append("show_portal_debug=%s" % str(status.get("show_portal_debug", false)))
	lines.append("show_light_debug=%s" % str(status.get("show_light_debug", false)))
	lines.append("material_surfaces=%d" % int(status.get("material_surface_count", 0)))
	lines.append("material_texture_requests=%d" % int(status.get("material_texture_requests", 0)))
	lines.append("material_textures_resolved=%d" % int(status.get("material_textures_resolved", 0)))
	lines.append("material_textures_missing=%d" % int(status.get("material_textures_missing", 0)))
	lines.append("material_unique_names=%s" % _join_variant_array(status.get("material_unique_names", [])))
	lines.append("material_missing_names=%s" % _join_variant_array(status.get("material_missing_names", [])))
	lines.append("collision_bodies=%d" % int(status.get("collision_bodies", 0)))
	lines.append("collision_shapes=%d" % int(status.get("collision_shapes", 0)))
	lines.append("collision_mesh_instances=%d" % int(status.get("collision_mesh_instances", 0)))
	lines.append("collision_surfaces=%d" % int(status.get("collision_surfaces", 0)))
	lines.append("collision_trimesh_shapes=%d" % int(status.get("collision_trimesh_shapes", 0)))
	lines.append("collision_aabb_fallbacks=%d" % int(status.get("collision_aabb_fallbacks", 0)))
	lines.append("collision_failures=%d" % int(status.get("collision_failures", 0)))
	var player_status: Dictionary = status.get("player_collision_test", {}) as Dictionary
	lines.append("player_test_enabled=%s" % str(player_status.get("enabled", false)))
	lines.append("player_spawned=%s" % str(player_status.get("spawned", false)))
	lines.append("player_on_floor=%s" % str(player_status.get("on_floor", false)))
	lines.append("player_floor_probe_hit=%s" % str(player_status.get("floor_probe_hit", false)))
	lines.append("player_input_layout=%s" % str(player_status.get("input_layout", "")))
	lines.append("player_ghost_mode=%s" % str(player_status.get("ghost_mode", false)))
	lines.append("portal_debug_lines=%d" % int(status.get("portal_debug_lines", 0)))
	lines.append("portal_debug_thick_edges=%d" % int(status.get("portal_debug_thick_edges", 0)))
	lines.append("portal_debug_endpoint_markers=%d" % int(status.get("portal_debug_endpoint_markers", 0)))
	var graph: Dictionary = status.get("portal_graph", {}) as Dictionary
	var failed_connector_values: Array = graph.get("failed_connector_instances", []) as Array
	var logical_connector_values: Array = graph.get("logical_connector_instances", []) as Array
	lines.append("portal_graph_components=%d" % int(graph.get("component_count", 0)))
	lines.append("portal_graph_connected_all=%s" % str(graph.get("connected_all_instances", false)))
	lines.append("portal_long_edge_count=%d" % int(graph.get("long_edge_count", 0)))
	lines.append("portal_missing_preview_edge_count=%d" % int(graph.get("missing_preview_edge_count", 0)))
	lines.append("portal_failed_connector_count=%d" % failed_connector_values.size())
	lines.append("portal_logical_connector_count=%d" % logical_connector_values.size())
	lines.append("light_debug_nodes=%d" % int(status.get("light_debug_nodes", 0)))
	lines.append("")
	lines.append("[files]")
	var files: Dictionary = status.get("files", {}) as Dictionary
	for key in files.keys():
		lines.append("%s=%s" % [str(key), str(files.get(key, ""))])
	lines.append("")
	lines.append("[chunks]")
	for chunk_value in chunks.get("chunks", []):
		var chunk: Dictionary = chunk_value as Dictionary
		lines.append("%02d %s" % [int(chunk.get("chunk_index", -1)), str(chunk.get("nif_name", ""))])
	lines.append("")
	lines.append("[placements]")
	for place_value in places.get("placements", []):
		var p: Dictionary = place_value as Dictionary
		lines.append("inst=%02d chunk=%d pos=(%.3f, %.3f, %.3f) angle=%.6f axis=(%.3f, %.3f, %.3f)" % [
			int(p.get("instance_index", -1)),
			int(p.get("chunk_index", -1)),
			float(p.get("x", 0.0)),
			float(p.get("y", 0.0)),
			float(p.get("z", 0.0)),
			float(p.get("angle", 0.0)),
			float(p.get("axis_x", 0.0)),
			float(p.get("axis_y", 0.0)),
			float(p.get("axis_z", 0.0)),
		])
	lines.append("")
	lines.append("[portals]")
	for link_value in portals.get("links", []):
		var link: Dictionary = link_value as Dictionary
		lines.append("%02d: %d:%d -> %d:%d" % [
			int(link.get("link_index", -1)),
			int(link.get("from_instance", -1)),
			int(link.get("from_portal", -1)),
			int(link.get("to_instance", -1)),
			int(link.get("to_portal", -1)),
		])
	lines.append("")
	lines.append("[portal_graph]")
	var graph_section: Dictionary = status.get("portal_graph", {}) as Dictionary
	lines.append("component_count=%d" % int(graph_section.get("component_count", 0)))
	lines.append("component_sizes=%s" % _join_variant_array(graph_section.get("component_sizes", [])))
	lines.append("connected_all_instances=%s" % str(graph_section.get("connected_all_instances", false)))
	lines.append("unique_edge_count=%d" % int(graph_section.get("unique_edge_count", 0)))
	lines.append("long_edge_threshold=%.3f" % float(graph_section.get("long_edge_threshold", 0.0)))
	lines.append("long_edge_count=%d" % int(graph_section.get("long_edge_count", 0)))
	lines.append("missing_preview_edge_count=%d" % int(graph_section.get("missing_preview_edge_count", 0)))
	lines.append("failed_connector_instances=%s" % _join_variant_array(graph_section.get("failed_connector_instances", [])))
	lines.append("logical_connector_instances=%s" % _join_variant_array(graph_section.get("logical_connector_instances", [])))
	lines.append("long_edges_top:")
	for edge_value in graph_section.get("long_edges_top", []):
		var edge: Dictionary = edge_value as Dictionary
		lines.append("  %02d -> %02d dist=%.3f chunks=%d/%d names=%s/%s ok=%s/%s" % [
			int(edge.get("from", -1)),
			int(edge.get("to", -1)),
			float(edge.get("distance", 0.0)),
			int(edge.get("from_chunk", -1)),
			int(edge.get("to_chunk", -1)),
			str(edge.get("from_name", "")),
			str(edge.get("to_name", "")),
			str(edge.get("from_preview_ok", false)),
			str(edge.get("to_preview_ok", false)),
		])
	lines.append("missing_preview_edges_top:")
	for edge_value in graph_section.get("missing_preview_edges_top", []):
		var edge: Dictionary = edge_value as Dictionary
		lines.append("  %02d -> %02d dist=%.3f chunks=%d/%d names=%s/%s ok=%s/%s" % [
			int(edge.get("from", -1)),
			int(edge.get("to", -1)),
			float(edge.get("distance", 0.0)),
			int(edge.get("from_chunk", -1)),
			int(edge.get("to_chunk", -1)),
			str(edge.get("from_name", "")),
			str(edge.get("to_name", "")),
			str(edge.get("from_preview_ok", false)),
			str(edge.get("to_preview_ok", false)),
		])
	lines.append("")
	lines.append("[nif_resolution]")
	for nif_value in status.get("nif_resolution", []):
		var nif: Dictionary = nif_value as Dictionary
		lines.append("inst=%02d chunk=%d found=%s preview=%s logical=%s reason=%s meshes=%d blocks=%d mat=%d tex=%d/%d miss=%d coll=%d cfails=%d method=%s candidates=%d name=%s path=%s error=%s" % [
			int(nif.get("instance_index", -1)),
			int(nif.get("chunk_index", -1)),
			str(nif.get("nif_found", false)),
			str(nif.get("preview_ok", false)),
			str(nif.get("logical_connector", false)),
			str(nif.get("logical_connector_reason", "")),
			int(nif.get("preview_meshes", 0)),
			int(nif.get("preview_blocks", 0)),
			int(nif.get("material_surface_count", 0)),
			int(nif.get("material_textures_resolved", 0)),
			int(nif.get("material_texture_requests", 0)),
			int(nif.get("material_textures_missing", 0)),
			int(nif.get("collision_bodies", 0)),
			int(nif.get("collision_failures", 0)),
			str(nif.get("nif_resolve_method", "")),
			int(nif.get("nif_candidate_count", 0)),
			str(nif.get("nif_name", "")),
			str(nif.get("nif_path", "")),
			str(nif.get("preview_error", "")),
		])
	lines.append("")
	lines.append("[texture_resolution]")
	for nif_value in status.get("nif_resolution", []):
		var nif: Dictionary = nif_value as Dictionary
		lines.append("inst=%02d name=%s materials=%s missing=%s paths=%s" % [
			int(nif.get("instance_index", -1)),
			str(nif.get("nif_name", "")),
			_join_variant_array(nif.get("material_names", [])),
			_join_variant_array(nif.get("material_missing_names", [])),
			_join_variant_array(nif.get("material_resolved_paths", [])),
		])
	lines.append("")
	lines.append("[collision_runtime]")
	for nif_value in status.get("nif_resolution", []):
		var nif: Dictionary = nif_value as Dictionary
		lines.append("inst=%02d name=%s bodies=%d shapes=%d meshes=%d surfaces=%d trimesh=%d aabb=%d failures=%d errors=%s" % [
			int(nif.get("instance_index", -1)),
			str(nif.get("nif_name", "")),
			int(nif.get("collision_bodies", 0)),
			int(nif.get("collision_shapes", 0)),
			int(nif.get("collision_mesh_instances", 0)),
			int(nif.get("collision_surfaces", 0)),
			int(nif.get("collision_trimesh_shapes", 0)),
			int(nif.get("collision_aabb_fallbacks", 0)),
			int(nif.get("collision_failures", 0)),
			_join_variant_array(nif.get("collision_errors", [])),
		])
	lines.append("")
	lines.append("[player_collision_test]")
	var player_report: Dictionary = status.get("player_collision_test", {}) as Dictionary
	for key in player_report.keys():
		lines.append("%s=%s" % [str(key), str(player_report.get(key, ""))])
	var packed_lines: PackedStringArray = PackedStringArray()
	for line in lines:
		packed_lines.append(str(line))
	return "\n".join(packed_lines) + "\n"
