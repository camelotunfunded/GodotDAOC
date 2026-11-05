extends CharacterBody3D
class_name DaocPlayerMotor

## Prototype de déplacement local DAoC.
## Ce script ne gère plus la souris ni la caméra : voir DaocInputRouter.gd et DaocPlayerCamera.gd.
## Il consomme un DaocInputState rempli par le routeur global.
## Repère interne DAoC: X/Y = plan horizontal, Z = hauteur.
## Repère Godot du viewer: X DAoC -> X Godot, Y DAoC -> Z Godot, Z DAoC -> Y Godot.

const DAOC_CAPSULE_RADIUS := 40.0
const DAOC_STAND_OFFSET := 68.0
const DAOC_LOW_OFFSET := 40.0
const DAOC_CAPSULE_HEIGHT_APPROX := 136.0
const DAOC_GROUND_COLLISION_OFFSET := 40.0

const DAOC_GRAVITY := 1000.0
const DAOC_TERMINAL_FALL_SPEED := -4000.0
const DAOC_JUMP_VELOCITY := 275.0

const DAOC_SWIM_SURFACE_OFFSET := 80.0
const DAOC_SWIM_VERTICAL_SPEED := 85.0
const DAOC_SWIM_VERTICAL_ACCEL := 166.0
const DAOC_WADING_SPEED_FACTOR := 0.5

const DAOC_SLOPE_NORMAL_Z_CANDIDATE := 0.7
const DAOC_STEP_HEIGHT_PLACEHOLDER := 40.0

enum MovementState {
	NORMAL,
	SWIMMING,
	FALLING,
	CLIMBING,
}

@export var local_run_speed_raw: float = 1500.0
@export var local_back_speed_factor: float = 0.55
@export var local_strafe_speed_factor: float = 0.70
@export var walk_speed_factor: float = 0.45
@export var sprint_speed_factor: float = 1.18
## P1-82 — en ligne, le serveur dit la vitesse (0xB6, en pourcent de
## PLAYER_BASE_SPEED). `local_run_speed_raw` est calibre sur l'allure hors combat
## (125 %) : le facteur applique est `percent / 125`. Sous 0, on reste local et
## le sprint est celui de la touche (place-holder hors ligne).
@export var server_speed_percent: float = -1.0
@export var server_speed_reference_percent: float = 125.0
@export var turn_rate_deg_per_sec: float = 180.0
@export var show_debug_mesh: bool = true

## Probe sol multi-points sous l'empreinte de la capsule.
## Corrige le cas où le centre touche le sol mais un bord de la capsule entre dans une pente.
@export var ground_probe_use_capsule_footprint: bool = true
@export var ground_probe_clearance_raw: float = 3.0
@export var ground_probe_radius_factor: float = 0.85
@export var ground_probe_use_runtime_collision: bool = true
@export var ground_probe_collision_terrain_only: bool = true
@export var ground_probe_collision_mask: int = 1
@export var ground_probe_collision_height_raw: float = 512.0
@export var ground_probe_collision_depth_raw: float = 2048.0
@export var ground_probe_collision_max_slope_degrees: float = 60.0
## P1-133 : un plancher de prop (maillage collidee) n est accepte que sous
## pieds + cette marche : on ne remonte jamais sur un toit ou un tablier au-dessus.
@export var ground_probe_prop_floor_enabled: bool = true
@export var ground_probe_prop_step_up_raw: float = 52.0
@export var ground_probe_prop_collision_mask: int = 4

var zone_viewer: Node = null
var player_camera: Node = null
var input_state: DaocInputState = null

var daoc_zone: int = 0
var daoc_x: float = 0.0
var daoc_y: float = 0.0
var daoc_z: float = 0.0
var heading_deg: float = 0.0
var vertical_velocity_raw: float = 0.0
var on_ground: bool = false
var is_in_water: bool = false
var is_wading: bool = false
var climb_flag_local_placeholder: bool = false
var movement_state: int = MovementState.NORMAL
## P1-97 : verrou de mouvement (mort). Le sol, l eau et la gravite continuent.
var movement_locked: bool = false

var _world_scale: float = 1.0
var _height_exaggeration: float = 1.0
var _debug_label: Label = null
var last_speed_raw: float = 0.0
var last_floor_z: float = 0.0
var last_water_info: Dictionary = {}
var last_move_vector: Vector2 = Vector2.ZERO
var last_boundary_solved: bool = false
var last_prop_solved: bool = false
var last_heightmap_floor_z: float = 0.0
var last_collision_floor_z: float = 0.0
var last_floor_source: String = "heightmap"


func setup(p_zone_viewer: Node, p_zone: int, p_daoc_pos: Vector3, p_heading_deg: float = 0.0, _make_camera_current: bool = true) -> void:
	zone_viewer = p_zone_viewer
	daoc_zone = p_zone
	daoc_x = p_daoc_pos.x
	daoc_y = p_daoc_pos.y
	daoc_z = p_daoc_pos.z
	heading_deg = p_heading_deg
	if zone_viewer != null:
		_world_scale = float(zone_viewer.get("world_scale"))
		_height_exaggeration = float(zone_viewer.get("height_exaggeration"))
	_make_runtime_nodes()
	_snap_to_floor(true)
	_apply_daoc_transform()


func set_input_state(state: DaocInputState) -> void:
	input_state = state


func _ready() -> void:
	# Runtime nodes are created by setup(), after ZoneViewer gives us scale and start position.
	# 2026-09-27 (retour : « la course est saccadée ») : le joueur avance dans
	# `_physics_process`, 60 fois par seconde ; sur un écran plus rapide, le
	# personnage et la caméra avançaient par à-coups. L interpolation physique
	# (project.godot) est coupée à la racine pour tout ce qui bouge dans
	# `_process` (PNJ, herbe, UI 3D) et rallumée pour le seul joueur ; la caméra
	# lit sa position interpolée (DaocPlayerCamera.get_pivot_global_position).
	if is_inside_tree() and ProjectSettings.get_setting("physics/common/physics_interpolation", false):
		get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func _make_runtime_nodes() -> void:
	# Collision capsule volontairement simple : les collisions monde exactes viendront plus tard.
	if get_node_or_null("CollisionShape3D") == null:
		var shape := CapsuleShape3D.new()
		shape.radius = DAOC_CAPSULE_RADIUS * _world_scale
		shape.height = DAOC_CAPSULE_HEIGHT_APPROX * _world_scale * _height_exaggeration
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = shape
		cs.position.y = (DAOC_CAPSULE_HEIGHT_APPROX * 0.5) * _world_scale * _height_exaggeration
		add_child(cs)

	if show_debug_mesh and get_node_or_null("DaocCapsuleDebug") == null:
		var mesh := CapsuleMesh.new()
		mesh.radius = DAOC_CAPSULE_RADIUS * _world_scale
		mesh.height = DAOC_CAPSULE_HEIGHT_APPROX * _world_scale * _height_exaggeration
		mesh.radial_segments = 16
		mesh.rings = 8
		var mi := MeshInstance3D.new()
		mi.name = "DaocCapsuleDebug"
		mi.mesh = mesh
		mi.position.y = (DAOC_CAPSULE_HEIGHT_APPROX * 0.5) * _world_scale * _height_exaggeration
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.75, 1.0, 0.32)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		add_child(mi)

	if _debug_label == null:
		var layer := CanvasLayer.new()
		layer.name = "PlayerDebugLayer"
		_debug_label = Label.new()
		_debug_label.position = Vector2(12, 68)
		_debug_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
		_debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_debug_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_debug_label)
		add_child(layer)


func _physics_process(delta: float) -> void:
	if zone_viewer == null:
		return
	_update_movement(delta)
	_apply_daoc_transform()
	_update_debug_label()


func turn_by_degrees(delta_deg: float) -> void:
	heading_deg = _wrap_degrees(heading_deg + delta_deg)


func motor_compute_forward_vector() -> Vector2:
	var heading_rad := deg_to_rad(heading_deg)
	return Vector2(cos(heading_rad), sin(heading_rad))


func motor_compute_right_vector() -> Vector2:
	var f := motor_compute_forward_vector()
	return Vector2(-f.y, f.x)


func _motor_compute_move_vector(forward_axis: float, strafe_axis: float) -> Vector2:
	var forward := motor_compute_forward_vector()
	var right := motor_compute_right_vector()
	var move := Vector2.ZERO
	if forward_axis > 0.0:
		move += forward * forward_axis
	elif forward_axis < 0.0:
		move += forward * forward_axis * local_back_speed_factor
	move += right * strafe_axis * local_strafe_speed_factor
	if move.length() > 1.0:
		move = move.normalized()
	return move


func motor_apply_heading_turn(turn_axis: float, delta: float) -> void:
	heading_deg = _wrap_degrees(heading_deg + turn_axis * turn_rate_deg_per_sec * delta)


func motor_clamp_zone_xy() -> void:
	if _is_generated_dungeon_runtime_zone():
		return
	if daoc_x >= 0.0 and daoc_x <= 65536.0 and daoc_y >= 0.0 and daoc_y <= 65536.0:
		return
	# R5 — avant de raboter, demander s'il existe une voisine sous ce point.
	#
	# Le rabotage reste la bonne réponse au bord de l'archipel : la région 51 est
	# un escalier, la plupart des frontières ne donnent sur rien. L'hôte répond
	# donc `ok=false` bien plus souvent qu'il ne fait passer.
	#
	# Le passage ne déplace PAS le joueur : les coordonnées changent de repère,
	# le point monde reste le même. C'est pour cela qu'on écrase les trois
	# champs ensemble, jamais la zone seule.
	if zone_viewer != null and zone_viewer.has_method("cross_zone_border_r5"):
		var crossing: Dictionary = zone_viewer.call("cross_zone_border_r5",
			daoc_zone, daoc_x, daoc_y) as Dictionary
		if bool(crossing.get("ok", false)):
			daoc_zone = int(crossing.get("zone", daoc_zone))
			daoc_x = float(crossing.get("x", daoc_x))
			daoc_y = float(crossing.get("y", daoc_y))
			return
	daoc_x = clampf(daoc_x, 0.0, 65536.0)
	daoc_y = clampf(daoc_y, 0.0, 65536.0)


func _is_generated_dungeon_runtime_zone() -> bool:
	if zone_viewer != null and zone_viewer.has_method("has_generated_dungeon_runtime_zone_17d"):
		return bool(zone_viewer.call("has_generated_dungeon_runtime_zone_17d", daoc_zone))
	return false


func _update_movement(delta: float) -> void:
	var forward_axis := 0.0
	var strafe_axis := 0.0
	var turn_axis := 0.0
	var walk_held := false
	var jump_held := false
	var down_held := false
	var sprint_held := false

	if input_state != null:
		forward_axis = input_state.forward_axis
		strafe_axis = input_state.strafe_axis
		turn_axis = input_state.turn_axis
		walk_held = input_state.walk_held
		jump_held = input_state.jump_held
		down_held = input_state.down_held
		sprint_held = input_state.sprint_held
	# P1-97 : mort, le personnage ne bouge plus (client d origine : drapeau
	# player+0x60 pose par 0xAE, leve par 0x89 ; toute entree est ignoree).
	if movement_locked:
		forward_axis = 0.0; strafe_axis = 0.0; turn_axis = 0.0
		jump_held = false; down_held = false; sprint_held = false

	motor_apply_heading_turn(turn_axis, delta)

	var water_info := _query_water_info()
	is_in_water = bool(water_info.get("in_water", false))
	is_wading = bool(water_info.get("wading", false))

	var speed := motor_compute_effective_speed_raw(walk_held, sprint_held, is_wading)
	last_speed_raw = speed
	last_water_info = water_info.duplicate(true)
	last_boundary_solved = false
	last_prop_solved = false

	var old_x := daoc_x
	var old_y := daoc_y

	var move := _motor_compute_move_vector(forward_axis, strafe_axis)
	last_move_vector = move

	daoc_x += move.x * speed * delta
	daoc_y += move.y * speed * delta

	if zone_viewer != null and zone_viewer.has_method("solve_daoc_boundary_collision"):
		var solved: Vector2 = zone_viewer.call("solve_daoc_boundary_collision", daoc_zone, old_x, old_y, daoc_x, daoc_y, DAOC_CAPSULE_RADIUS) as Vector2
		last_boundary_solved = solved.distance_to(Vector2(daoc_x, daoc_y)) > 0.001
		daoc_x = solved.x
		daoc_y = solved.y

	if zone_viewer != null and zone_viewer.has_method("solve_daoc_prop_collision"):
		var prop_solved: Vector2 = zone_viewer.call("solve_daoc_prop_collision", daoc_zone, old_x, old_y, daoc_x, daoc_y, daoc_z, DAOC_CAPSULE_RADIUS, DAOC_CAPSULE_HEIGHT_APPROX) as Vector2
		last_prop_solved = prop_solved.distance_to(Vector2(daoc_x, daoc_y)) > 0.001
		daoc_x = prop_solved.x
		daoc_y = prop_solved.y

	var floor_z := _query_floor_z()
	last_floor_z = floor_z
	on_ground = daoc_z <= floor_z + 0.5 and vertical_velocity_raw <= 0.0
	movement_state = _resolve_movement_state(floor_z)
	match movement_state:
		MovementState.SWIMMING:
			_update_water_vertical(delta, water_info, floor_z, jump_held, down_held)
		MovementState.CLIMBING:
			# Placeholder volontaire : l'état existe pour isoler la future logique,
			# mais aucun déclencheur climbing n'est encore câblé dans cette passe.
			vertical_velocity_raw = 0.0
		_:
			_update_ground_or_fall_vertical(delta, floor_z, jump_held)

	# Garde-fou local : le serveur corrigera plus tard, mais le viewer ne doit pas sortir de la zone.
	motor_clamp_zone_xy()


func _resolve_movement_state(floor_z: float) -> int:
	if climb_flag_local_placeholder:
		return MovementState.CLIMBING
	if is_in_water:
		return MovementState.SWIMMING
	if not on_ground and daoc_z > floor_z + 0.5:
		return MovementState.FALLING
	return MovementState.NORMAL


func motor_compute_effective_speed_raw(walk_held: bool, sprint_held: bool, wading: bool) -> float:
	var speed := local_run_speed_raw
	if server_speed_percent >= 0.0 and server_speed_reference_percent > 0.0:
		speed *= server_speed_percent / server_speed_reference_percent
		if walk_held:
			speed *= walk_speed_factor
	elif walk_held:
		speed *= walk_speed_factor
	elif sprint_held:
		speed *= sprint_speed_factor
	if wading:
		speed *= DAOC_WADING_SPEED_FACTOR
	return speed


func set_climb_flag_local_placeholder(enabled: bool) -> void:
	climb_flag_local_placeholder = enabled
	if enabled:
		movement_state = MovementState.CLIMBING
	elif movement_state == MovementState.CLIMBING:
		movement_state = MovementState.NORMAL


func get_motor_constants_snapshot() -> Dictionary:
	return {
		"run_speed_raw": local_run_speed_raw,
		"back_speed_factor": local_back_speed_factor,
		"strafe_speed_factor": local_strafe_speed_factor,
		"walk_speed_factor": walk_speed_factor,
		"sprint_speed_factor": sprint_speed_factor,
		"wading_speed_factor": DAOC_WADING_SPEED_FACTOR,
		"jump_velocity": DAOC_JUMP_VELOCITY,
		"gravity": DAOC_GRAVITY,
		"terminal_fall_speed": DAOC_TERMINAL_FALL_SPEED,
		"swim_surface_offset": DAOC_SWIM_SURFACE_OFFSET,
		"swim_vertical_speed": DAOC_SWIM_VERTICAL_SPEED,
		"states": ["NORMAL", "SWIMMING", "FALLING", "CLIMBING"],
	}


func get_motor_local_flags_snapshot() -> Dictionary:
	var walk := false
	var sprint := false
	var runlock := false
	var jump := false
	var down := false
	var forward := 0.0
	var strafe := 0.0
	var turn := 0.0
	if input_state != null:
		walk = input_state.walk_held
		sprint = input_state.sprint_held
		runlock = input_state.run_lock_enabled
		jump = input_state.jump_held
		down = input_state.down_held
		forward = input_state.forward_axis
		strafe = input_state.strafe_axis
		turn = input_state.turn_axis
	return {
		"movement_state": _movement_state_name(),
		"walk_held": walk,
		"sprint_held": sprint,
		"run_lock_enabled": runlock,
		"jump_held": jump,
		"down_held": down,
		"forward_axis": forward,
		"strafe_axis": strafe,
		"turn_axis": turn,
		"is_in_water": is_in_water,
		"is_wading": is_wading,
		"is_swimming": movement_state == MovementState.SWIMMING,
		"is_falling": movement_state == MovementState.FALLING,
		"is_climbing": movement_state == MovementState.CLIMBING,
		"climb_flag_local_placeholder": climb_flag_local_placeholder,
		"effective_speed_raw": motor_compute_effective_speed_raw(walk, sprint, is_wading),
	}


func _update_ground_or_fall_vertical(delta: float, floor_z: float, jump_held: bool) -> void:
	if on_ground:
		daoc_z = floor_z
		vertical_velocity_raw = 0.0
		if jump_held:
			vertical_velocity_raw = DAOC_JUMP_VELOCITY
			on_ground = false
			movement_state = MovementState.FALLING
	else:
		vertical_velocity_raw = maxf(vertical_velocity_raw - DAOC_GRAVITY * delta, DAOC_TERMINAL_FALL_SPEED)
		daoc_z += vertical_velocity_raw * delta
		if daoc_z <= floor_z:
			daoc_z = floor_z
			vertical_velocity_raw = 0.0
			on_ground = true
			movement_state = MovementState.NORMAL


func _movement_state_name() -> String:
	return motor_movement_state_name_for_value(movement_state)


func motor_movement_state_name_for_value(state_value: int) -> String:
	match state_value:
		MovementState.NORMAL:
			return "NORMAL"
		MovementState.SWIMMING:
			return "SWIMMING"
		MovementState.FALLING:
			return "FALLING"
		MovementState.CLIMBING:
			return "CLIMBING"
		_:
			return "UNKNOWN"


func _update_water_vertical(delta: float, water_info: Dictionary, floor_z: float, jump_held: bool, down_held: bool) -> void:
	var water_height := float(water_info.get("height", daoc_z))
	var swim_ceiling := water_height - DAOC_SWIM_SURFACE_OFFSET
	if jump_held:
		vertical_velocity_raw = minf(vertical_velocity_raw + DAOC_SWIM_VERTICAL_ACCEL * delta, DAOC_SWIM_VERTICAL_SPEED)
	elif down_held:
		vertical_velocity_raw = maxf(vertical_velocity_raw - DAOC_SWIM_VERTICAL_ACCEL * delta, -DAOC_SWIM_VERTICAL_SPEED)
	else:
		vertical_velocity_raw = move_toward(vertical_velocity_raw, 0.0, DAOC_SWIM_VERTICAL_ACCEL * delta)
	daoc_z += vertical_velocity_raw * delta
	if daoc_z > swim_ceiling:
		daoc_z = swim_ceiling
		vertical_velocity_raw = minf(vertical_velocity_raw, 0.0)
	if daoc_z < floor_z:
		daoc_z = floor_z
		vertical_velocity_raw = 0.0


func _query_floor_z() -> float:
	var best_z := _query_floor_z_at(daoc_x, daoc_y, daoc_z)
	if not ground_probe_use_capsule_footprint:
		return best_z + ground_probe_clearance_raw

	var r := DAOC_CAPSULE_RADIUS * ground_probe_radius_factor
	var diag := r * 0.70710678
	var samples := [
		Vector2(r, 0.0),
		Vector2(-r, 0.0),
		Vector2(0.0, r),
		Vector2(0.0, -r),
		Vector2(diag, diag),
		Vector2(-diag, diag),
		Vector2(diag, -diag),
		Vector2(-diag, -diag),
	]

	for s in samples:
		best_z = maxf(best_z, _query_floor_z_at(daoc_x + s.x, daoc_y + s.y, daoc_z))
	return best_z + ground_probe_clearance_raw


func _query_floor_z_at(px: float, py: float, pz: float) -> float:
	var ground := _query_terrain_floor_z_at(px, py, pz)
	# P1-133 : plancher, marche ou tablier de pont (maillage collidee du NIF).
	var prop := _query_prop_floor_z_at(px, py, pz)
	if bool(prop.get("ok", false)) and float(prop.get("floor_z", ground)) > ground:
		last_floor_source = "prop_nif"
		return float(prop["floor_z"])
	return ground


func _query_terrain_floor_z_at(px: float, py: float, pz: float) -> float:
	var heightmap_z := pz
	if zone_viewer != null and zone_viewer.has_method("sample_daoc_floor_z"):
		heightmap_z = float(zone_viewer.call("sample_daoc_floor_z", daoc_zone, px, py, pz))
	var collision_probe := _query_runtime_collision_floor_z_at(px, py, pz)
	if bool(collision_probe.get("ok", false)):
		last_heightmap_floor_z = heightmap_z
		last_collision_floor_z = float(collision_probe.get("floor_z", heightmap_z))
		last_floor_source = "collision"
		return last_collision_floor_z
	last_heightmap_floor_z = heightmap_z
	last_collision_floor_z = 0.0
	last_floor_source = "heightmap"
	return heightmap_z


func _query_runtime_collision_floor_z_at(px: float, py: float, pz: float) -> Dictionary:
	if not ground_probe_use_runtime_collision:
		return {"ok": false, "reason": "disabled"}
	# R7 - hors de l'arbre, `get_world_3d` n'est pas seulement vide : il journalise
	# une erreur moteur a chaque appel, et le sondage tire neuf rayons par image.
	# Une suite headless qui monte le joueur avant la premiere trame en produisait
	# des centaines de lignes, ou une vraie erreur se serait perdue.
	if not is_inside_tree():
		return {"ok": false, "reason": "hors_de_l_arbre"}
	var world := get_world_3d()
	if world == null:
		return {"ok": false, "reason": "missing_world"}
	var base := _daoc_point_to_global(px, py, pz)
	var scale_y := maxf(0.0001, _world_scale * _height_exaggeration)
	var from := base + Vector3(0.0, ground_probe_collision_height_raw * scale_y, 0.0)
	var to := base - Vector3(0.0, ground_probe_collision_depth_raw * scale_y, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = ground_probe_collision_mask
	query.hit_from_inside = false
	query.hit_back_faces = true
	query.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false, "reason": "no_hit"}
	var collider: Variant = hit.get("collider", null)
	if ground_probe_collision_terrain_only and not _is_terrain_floor_collider(collider):
		return {"ok": false, "reason": "non_terrain_collider", "collider": str(collider)}
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	if _normal_slope_degrees(normal) > ground_probe_collision_max_slope_degrees:
		return {"ok": false, "reason": "slope_too_steep", "normal": normal}
	var pos: Vector3 = hit.get("position", base) as Vector3
	var origin_zero := _daoc_point_to_global(0.0, 0.0, 0.0)
	var raw_z := (pos.y - origin_zero.y) / scale_y
	return {
		"ok": true,
		"floor_z": raw_z,
		"hit_position": pos,
		"normal": normal,
		"collider": str(collider),
	}


func _daoc_point_to_global(px: float, py: float, pz: float) -> Vector3:
	if zone_viewer != null and zone_viewer.has_method("daoc_to_godot"):
		return zone_viewer.call("daoc_to_godot", daoc_zone, px, py, pz) as Vector3
	return Vector3(px * _world_scale, pz * _world_scale * _height_exaggeration, py * _world_scale)


func _is_terrain_floor_collider(collider: Variant) -> bool:
	if collider == null or not (collider is Object):
		return false
	var obj := collider as Object
	if obj.has_meta("daoc_terrain_collision_14e"):
		return true
	var label := str(obj).to_lower()
	if obj is Node:
		label = str((obj as Node).name).to_lower()
	if obj.has_meta("daoc_zone") and label.contains("terrain"):
		return true
	return label.contains("terraincollision")


func _normal_slope_degrees(normal: Vector3) -> float:
	if normal.length() <= 0.0001:
		return 180.0
	return rad_to_deg(acos(clampf(normal.normalized().dot(Vector3.UP), -1.0, 1.0)))


func _query_water_info() -> Dictionary:
	if zone_viewer != null and zone_viewer.has_method("sample_daoc_water_info"):
		var v: Variant = zone_viewer.call("sample_daoc_water_info", daoc_zone, daoc_x, daoc_y, daoc_z)
		if typeof(v) == TYPE_DICTIONARY:
			return v
	return {}


func _snap_to_floor(force: bool = false) -> void:
	var floor_z := _query_floor_z()
	if force or daoc_z < floor_z:
		daoc_z = floor_z
		vertical_velocity_raw = 0.0
		on_ground = true


func _apply_daoc_transform() -> void:
	var before := global_position
	if zone_viewer != null and zone_viewer.has_method("daoc_to_godot"):
		var gp: Vector3 = zone_viewer.call("daoc_to_godot", daoc_zone, daoc_x, daoc_y, daoc_z) as Vector3
		global_position = gp
	else:
		global_position = Vector3(daoc_x * _world_scale, daoc_z * _world_scale * _height_exaggeration, daoc_y * _world_scale)
	# Téléportation (/stuck, pierre de liaison, changement de région) : pas de
	# glissement interpolé entre l ancien et le nouveau point.
	if is_inside_tree() and before.distance_to(global_position) > 600.0 * _world_scale:
		reset_physics_interpolation()
	# Cette rotation sert surtout aux futurs meshes/personnages. La capsule debug est symétrique.
	rotation_degrees.y = -heading_deg


func _wrap_degrees(v: float) -> float:
	return fposmod(v + 180.0, 360.0) - 180.0


func get_movement_state_name() -> String:
	return _movement_state_name()


func get_movement_debug_snapshot() -> Dictionary:
	return {
		"zone": daoc_zone,
		"x": daoc_x,
		"y": daoc_y,
		"z": daoc_z,
		"heading_deg": heading_deg,
		"floor_z": last_floor_z if last_floor_z != 0.0 else _query_floor_z(),
		"floor_source": last_floor_source,
		"heightmap_floor_z": last_heightmap_floor_z,
		"collision_floor_z": last_collision_floor_z,
		"vertical_velocity_raw": vertical_velocity_raw,
		"on_ground": on_ground,
		"movement_state": _movement_state_name(),
		"is_in_water": is_in_water,
		"is_wading": is_wading,
		"climb_flag_local_placeholder": climb_flag_local_placeholder,
		"last_speed_raw": last_speed_raw,
		"last_move_vector": last_move_vector,
		"last_boundary_solved": last_boundary_solved,
		"last_prop_solved": last_prop_solved,
		"water_info": last_water_info,
		"capsule_radius": DAOC_CAPSULE_RADIUS,
		"capsule_height": DAOC_CAPSULE_HEIGHT_APPROX,
		"ground_probe_use_capsule_footprint": ground_probe_use_capsule_footprint,
		"ground_probe_use_runtime_collision": ground_probe_use_runtime_collision,
		"ground_probe_collision_terrain_only": ground_probe_collision_terrain_only,
		"motor_flags": get_motor_local_flags_snapshot(),
	}


func unstuck_to_safe_local_position() -> void:
	# Local-only recovery. Le serveur fera autorité plus tard ; ici on garantit juste un viewer récupérable.
	daoc_x = 32768.0
	daoc_y = 32768.0
	daoc_z = _query_floor_z()
	vertical_velocity_raw = 0.0
	on_ground = true
	climb_flag_local_placeholder = false
	movement_state = MovementState.NORMAL
	_apply_daoc_transform()


func _update_debug_label() -> void:
	if _debug_label == null:
		return
	var cam_line := ""
	if player_camera != null:
		cam_line = "\ncam dist=%.1f height=%.1f tilt=%.1f angle=%.1f" % [
			float(player_camera.get("distance_raw")),
			float(player_camera.get("height_raw")),
			float(player_camera.get("tilt_raw")),
			float(player_camera.get("angle_raw"))
		]
	var input_line := ""
	if input_state != null:
		input_line = "\ninput " + input_state.debug_string() + "\n" + input_state.last_action_debug
	_debug_label.text = "DAoC player zone%03d  x=%.1f y=%.1f z=%.1f  floor=%.1f src=%s hm=%.1f col=%.1f  vv=%.1f  state=%s  water=%s wading=%s climb=%s speed=%.1f\nheading=%.1f%s%s\nkeyboard.dat physique: avancer/reculer/strafe/tourner · clic droit caméra/mouselook · molette zoom" % [
		daoc_zone,
		daoc_x,
		daoc_y,
		daoc_z,
		last_floor_z if last_floor_z != 0.0 else _query_floor_z(),
		last_floor_source,
		last_heightmap_floor_z,
		last_collision_floor_z,
		vertical_velocity_raw,
		_movement_state_name(),
		str(is_in_water),
		str(is_wading),
		str(climb_flag_local_placeholder),
		last_speed_raw,
		heading_deg,
		cam_line,
		input_line
	]


## P1-133 — le sol d'un prop : rayon vertical parti de pieds + une marche, contre
## les seuls corps qui portent le maillage NIF (`daoc_collision_trimesh`). Parti
## de si bas, il ne voit jamais le toit d'une maison ni le tablier d'un pont
## sous lequel on passe ; il voit le plancher, la marche suivante, la rampe.
func _query_prop_floor_z_at(px: float, py: float, pz: float) -> Dictionary:
	if not ground_probe_prop_floor_enabled or not is_inside_tree():
		return {"ok": false}
	var world := get_world_3d()
	if world == null:
		return {"ok": false}
	var base := _daoc_point_to_global(px, py, pz)
	var scale_y := maxf(0.0001, _world_scale * _height_exaggeration)
	var from := base + Vector3(0.0, ground_probe_prop_step_up_raw * scale_y, 0.0)
	var to := base - Vector3(0.0, ground_probe_collision_depth_raw * scale_y, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, ground_probe_prop_collision_mask)
	query.hit_back_faces = true
	query.hit_from_inside = false
	query.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false}
	var collider: Object = hit.get("collider") as Object
	if collider == null or not collider.has_meta("daoc_collision_trimesh"):
		return {"ok": false}
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	if _normal_slope_degrees(normal) > ground_probe_collision_max_slope_degrees:
		return {"ok": false}
	var pos: Vector3 = hit.get("position", base) as Vector3
	var origin_zero := _daoc_point_to_global(0.0, 0.0, 0.0)
	return {"ok": true, "floor_z": (pos.y - origin_zero.y) / scale_y}
