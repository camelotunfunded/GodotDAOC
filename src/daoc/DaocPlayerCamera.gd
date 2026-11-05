extends Node3D
class_name DaocPlayerCamera

## Caméra joueur DAoC séparée du moteur de déplacement.
## Objectif : reproduire les valeurs client plutôt qu'une caméra Godot bricolée.
##
## Valeurs brutes DAoC :
## - distance_raw : unités DAoC, molette par pas de 25, clamp live1420 normal 25..700.
## - height_raw   : offset hauteur, clamp live1420 -50..25.
## - angle_raw    : orbite horizontale 0..4095, 4096 = 360°.
## - tilt_raw     : dixièmes de degré pratiques pour le prototype ; les INI client stockent tilt entier.
##
## La caméra est volontairement un sibling du joueur, pas un enfant du motor : elle calcule sa position
## globale depuis la position/heading du player, comme le client original après accumulation input.

const DAOC_STAND_OFFSET := 68.0
const DAOC_CAMERA_DISTANCE_DEFAULT := 240.0
const DAOC_CAMERA_HEIGHT_DEFAULT := 10.0
const DAOC_CAMERA_DISTANCE_MIN := 25.0
const DAOC_CAMERA_DISTANCE_MAX := 700.0
const DAOC_CAMERA_DISTANCE_MAX_SPECIAL := 1500.0
const DAOC_CAMERA_ZOOM_STEP := 25.0
const DAOC_CAMERA_HEIGHT_MIN := -50.0
const DAOC_CAMERA_HEIGHT_MAX := 25.0
const DAOC_CAMERA_TILT_DEFAULT := 174.0
const DAOC_CAMERA_TILT_MIN_LIVE1420 := 100.0
const DAOC_CAMERA_TILT_CENTER_LIVE1420 := 900.0
const DAOC_CAMERA_TILT_MAX_LIVE1420 := 1700.0
const DAOC_HEADING_UNITS := 4096.0
const DAOC_HALF_TURN_UNITS := 2048.0

@export var distance_raw: float = DAOC_CAMERA_DISTANCE_DEFAULT
@export var height_raw: float = DAOC_CAMERA_HEIGHT_DEFAULT
@export var tilt_raw: float = DAOC_CAMERA_TILT_DEFAULT
@export var angle_raw: float = 0.0
@export var allow_boat_zoom_max: bool = false

@export var tilt_min_raw: float = DAOC_CAMERA_TILT_MIN_LIVE1420
@export var tilt_max_raw: float = DAOC_CAMERA_TILT_MAX_LIVE1420
@export var mouse_angle_units_per_pixel: float = 1.35
@export var mouse_tilt_units_per_pixel: float = 1.20

@export var use_client_camera_ini: bool = false
@export var camera_ini_path: String = "res://data/default.ini"
@export var debug_camera: bool = false
@export var snapback_enabled: bool = true
@export var snapback_speed_units_per_sec: float = 2048.0
@export var snapback_min_angle_units: float = 2.0
@export var camera_collision_enabled: bool = true
@export var camera_collision_mask: int = 5
@export var camera_collision_margin_raw: float = 28.0
@export var first_person_distance_raw: float = 25.0
@export_range(35.0, 100.0, 1.0) var camera_fov_degrees: float = 75.0

var zone_viewer: Node = null
var player: Node3D = null
var _world_scale: float = 1.0
var _height_exaggeration: float = 1.0
var _camera: Camera3D = null
var _loaded_ini_once: bool = false
var input_state: DaocInputState = null
var third_person_distance_raw: float = DAOC_CAMERA_DISTANCE_DEFAULT
var camera_mode: String = "third_person"
var last_collision_hit: bool = false
var last_collision_distance_raw: float = -1.0
var last_look_at_guard_applied: bool = false
var last_camera_distance_to_pivot_raw: float = -1.0
var last_camera_action_debug: String = ""
var last_orbit_delta_units: float = 0.0
var last_tilt_delta_units: float = 0.0
var last_wheel_notches: float = 0.0
var snapback_last_step_units: float = 0.0


func setup(p_zone_viewer: Node, p_player: Node3D, make_current: bool = true) -> void:
	zone_viewer = p_zone_viewer
	player = p_player
	if zone_viewer != null:
		_world_scale = float(zone_viewer.get("world_scale"))
		_height_exaggeration = float(zone_viewer.get("height_exaggeration"))
	_make_camera_node(make_current)
	if use_client_camera_ini and not _loaded_ini_once:
		_load_camera_from_ini(camera_ini_path)
		_loaded_ini_once = true
	_update_camera()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if player != null:
		_update_snapback(delta)
		_update_camera()


func _make_camera_node(make_current: bool) -> void:
	if get_node_or_null("PlayerCamera3D") == null:
		_camera = Camera3D.new()
		_camera.name = "PlayerCamera3D"
		_camera.near = 1.0
		_camera.far = 600000.0
		add_child(_camera)
	else:
		_camera = get_node("PlayerCamera3D") as Camera3D
	_camera.current = make_current
	_camera.fov = camera_fov_degrees


func set_current(v: bool) -> void:
	if _camera != null:
		_camera.current = v


func set_input_state(state: DaocInputState) -> void:
	input_state = state


func orbit_mouse_dx(dx: float) -> void:
	# Souris droite gauche/droite : angle orbital autour du perso.
	# Signe choisi pour un comportement naturel dans Godot ; inverser ici si besoin.
	last_orbit_delta_units = -dx * mouse_angle_units_per_pixel
	angle_raw = _wrap_heading_units(angle_raw + last_orbit_delta_units)
	last_camera_action_debug = "orbit dx=%.2f units=%.2f" % [dx, last_orbit_delta_units]
	_update_camera()
	if debug_camera:
		_print_state("orbit")


func tilt_mouse_dy(dy: float) -> void:
	# Souris droite haut/bas : tilt vertical, pas un yaw. C'est ce qui manquait dans la V1.
	last_tilt_delta_units = -dy * mouse_tilt_units_per_pixel
	tilt_raw = clampf(tilt_raw + last_tilt_delta_units, tilt_min_raw, tilt_max_raw)
	last_camera_action_debug = "tilt dy=%.2f units=%.2f" % [dy, last_tilt_delta_units]
	_update_camera()
	if debug_camera:
		_print_state("tilt")


func zoom_wheel_notches(notches: float) -> void:
	# Eden live1420 : distance = distance - wheel_delta * 25.0 ; un cran Windows = 120.
	# Ici : notches +1 = molette haut = zoom avant.
	last_wheel_notches = notches
	distance_raw = _clamp_camera_distance(distance_raw - notches * DAOC_CAMERA_ZOOM_STEP)
	last_camera_action_debug = "wheel notches=%.2f distance=%.1f" % [notches, distance_raw]
	_update_camera()
	if debug_camera:
		_print_state("zoom")


func reset_camera() -> void:
	# Équivalent prototype de /resetcamera. Garde un pitch DAoC valide, pas 0 hors bornes live1420.
	camera_mode = "third_person"
	distance_raw = DAOC_CAMERA_DISTANCE_DEFAULT
	height_raw = DAOC_CAMERA_HEIGHT_DEFAULT
	tilt_raw = DAOC_CAMERA_TILT_DEFAULT
	angle_raw = 0.0
	last_camera_action_debug = "reset"
	_update_camera()


func set_camera_as_reset_from_current() -> void:
	# Placeholder pour /setcamera. Pour l'instant les valeurs courantes sont déjà les valeurs stockées.
	last_camera_action_debug = "setcamera current"
	_update_camera()


func set_angle_raw(v: float) -> void:
	angle_raw = _wrap_heading_units(v)
	last_camera_action_debug = "set_angle %.1f" % angle_raw
	_update_camera()


func normalize_camera_values() -> void:
	distance_raw = _clamp_camera_distance(distance_raw)
	height_raw = clampf(height_raw, DAOC_CAMERA_HEIGHT_MIN, DAOC_CAMERA_HEIGHT_MAX)
	angle_raw = _wrap_heading_units(angle_raw)
	tilt_raw = clampf(tilt_raw, tilt_min_raw, tilt_max_raw)


func get_camera_constants_snapshot() -> Dictionary:
	return {
		"distance_min": DAOC_CAMERA_DISTANCE_MIN,
		"distance_max": DAOC_CAMERA_DISTANCE_MAX,
		"distance_max_special": DAOC_CAMERA_DISTANCE_MAX_SPECIAL,
		"zoom_step": DAOC_CAMERA_ZOOM_STEP,
		"height_min": DAOC_CAMERA_HEIGHT_MIN,
		"height_max": DAOC_CAMERA_HEIGHT_MAX,
		"tilt_default": DAOC_CAMERA_TILT_DEFAULT,
		"tilt_min_live1420": DAOC_CAMERA_TILT_MIN_LIVE1420,
		"tilt_center_live1420": DAOC_CAMERA_TILT_CENTER_LIVE1420,
		"tilt_max_live1420": DAOC_CAMERA_TILT_MAX_LIVE1420,
		"heading_units": DAOC_HEADING_UNITS,
	}


func get_camera_state_for_restore() -> Dictionary:
	return {
		"distance_raw": distance_raw,
		"height_raw": height_raw,
		"tilt_raw": tilt_raw,
		"angle_raw": angle_raw,
		"allow_boat_zoom_max": allow_boat_zoom_max,
		"camera_mode": camera_mode,
		"third_person_distance_raw": third_person_distance_raw,
		"snapback_enabled": snapback_enabled,
		"camera_collision_enabled": camera_collision_enabled,
		"last_camera_action_debug": last_camera_action_debug,
	}


func restore_camera_state(state: Dictionary) -> void:
	distance_raw = float(state.get("distance_raw", distance_raw))
	height_raw = float(state.get("height_raw", height_raw))
	tilt_raw = float(state.get("tilt_raw", tilt_raw))
	angle_raw = float(state.get("angle_raw", angle_raw))
	allow_boat_zoom_max = bool(state.get("allow_boat_zoom_max", allow_boat_zoom_max))
	camera_mode = str(state.get("camera_mode", camera_mode))
	third_person_distance_raw = float(state.get("third_person_distance_raw", third_person_distance_raw))
	snapback_enabled = bool(state.get("snapback_enabled", snapback_enabled))
	camera_collision_enabled = bool(state.get("camera_collision_enabled", camera_collision_enabled))
	last_camera_action_debug = str(state.get("last_camera_action_debug", last_camera_action_debug))
	_update_camera()


func set_snapback_enabled(v: bool) -> void:
	snapback_enabled = v


func _update_snapback(delta: float) -> void:
	snapback_last_step_units = 0.0
	if not snapback_enabled:
		return
	if input_state == null:
		return
	if input_state.mouse_look_held or input_state.mouse_pan_held:
		return
	if not input_state.has_translation_movement():
		return
	if absf(_heading_delta_units(angle_raw, 0.0)) <= snapback_min_angle_units:
		snapback_last_step_units = absf(_heading_delta_units(angle_raw, 0.0))
		angle_raw = 0.0
		last_camera_action_debug = "snapback complete"
		return
	var before := angle_raw
	angle_raw = _move_toward_heading_units(angle_raw, 0.0, snapback_speed_units_per_sec * delta)
	snapback_last_step_units = absf(_heading_delta_units(before, angle_raw))
	last_camera_action_debug = "snapback step=%.2f angle=%.2f" % [snapback_last_step_units, angle_raw]


func get_camera3d() -> Camera3D:
	return _camera


func get_pivot_global_position() -> Vector3:
	if player == null:
		return global_position
	# 2026-09-27 : position INTERPOLÉE du joueur (il avance au pas physique,
	# 60 Hz) ; sans elle la caméra sautait d un pas à chaque tick.
	var origin := player.global_position
	if player.is_physics_interpolated_and_enabled():
		origin = player.get_global_transform_interpolated().origin
	return origin + Vector3(0.0, (DAOC_STAND_OFFSET + height_raw) * _world_scale * _height_exaggeration, 0.0)


func toggle_camera_mode() -> void:
	if camera_mode == "first_person":
		camera_mode = "third_person"
		distance_raw = third_person_distance_raw
	else:
		camera_mode = "first_person"
		third_person_distance_raw = maxf(distance_raw, DAOC_CAMERA_DISTANCE_MIN)
		distance_raw = first_person_distance_raw
	last_camera_action_debug = "toggle mode=%s" % camera_mode
	_update_camera()


func get_camera_debug_snapshot() -> Dictionary:
	return {
		"distance_raw": distance_raw,
		"height_raw": height_raw,
		"tilt_raw": tilt_raw,
		"tilt_degrees": tilt_raw / 10.0,
		"tilt_min_raw": tilt_min_raw,
		"tilt_max_raw": tilt_max_raw,
		"angle_raw": angle_raw,
		"mode": camera_mode,
		"snapback_enabled": snapback_enabled,
		"snapback_last_step_units": snapback_last_step_units,
		"camera_collision_enabled": camera_collision_enabled,
		"last_collision_hit": last_collision_hit,
		"last_collision_distance_raw": last_collision_distance_raw,
		"last_look_at_guard_applied": last_look_at_guard_applied,
		"last_camera_distance_to_pivot_raw": last_camera_distance_to_pivot_raw,
		"last_camera_action_debug": last_camera_action_debug,
		"last_orbit_delta_units": last_orbit_delta_units,
		"last_tilt_delta_units": last_tilt_delta_units,
		"last_wheel_notches": last_wheel_notches,
		"has_camera3d": _camera != null,
		"camera_is_inside_tree": _camera != null and _camera.is_inside_tree(),
	}


func _update_camera() -> void:
	if player == null or _camera == null:
		return
	normalize_camera_values()

	var pivot := get_pivot_global_position()
	global_position = pivot

	var player_heading_deg := _get_player_heading_deg()
	var orbit_deg := angle_raw * 360.0 / DAOC_HEADING_UNITS
	# DAoC ajoute conceptuellement un demi-tour pour placer la caméra derrière le joueur.
	var yaw := deg_to_rad(player_heading_deg + orbit_deg + 180.0)
	var pitch := deg_to_rad(tilt_raw / 10.0)
	var d := distance_raw * _world_scale
	var horizontal := cos(pitch) * d
	var vertical := sin(pitch) * d * _height_exaggeration

	var offset := Vector3(cos(yaw) * horizontal, vertical, sin(yaw) * horizontal)
	var desired_position := pivot + offset
	var camera_position := _resolve_camera_collision(pivot, desired_position)
	camera_position = _clamp_above_ground(camera_position, pivot)
	last_look_at_guard_applied = false
	var look_dir := pivot - camera_position
	if look_dir.length_squared() <= 0.000001:
		var fallback_dir := desired_position - pivot
		if fallback_dir.length_squared() <= 0.000001:
			fallback_dir = Vector3.BACK
		camera_position = pivot + fallback_dir.normalized() * maxf(1.0, _world_scale)
		look_dir = pivot - camera_position
		last_look_at_guard_applied = true
	last_camera_distance_to_pivot_raw = camera_position.distance_to(pivot) / maxf(_world_scale, 0.00001)
	_camera.global_position = camera_position
	if _camera.is_inside_tree() and look_dir.length_squared() > 0.000001:
		_camera.look_at(pivot, Vector3.UP)


func _resolve_camera_collision(pivot: Vector3, desired: Vector3) -> Vector3:
	last_collision_hit = false
	last_collision_distance_raw = -1.0
	if not camera_collision_enabled:
		return desired
	var world := get_world_3d()
	if world == null:
		return desired
	var query := PhysicsRayQueryParameters3D.create(pivot, desired, camera_collision_mask)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_pos: Vector3 = hit.get("position", desired) as Vector3
	var dir := desired - pivot
	var length := dir.length()
	if length <= 0.001:
		return desired
	var margin := camera_collision_margin_raw * _world_scale
	var safe_dist := maxf(0.0, pivot.distance_to(hit_pos) - margin)
	last_collision_hit = true
	last_collision_distance_raw = safe_dist / maxf(_world_scale, 0.00001)
	return pivot + dir.normalized() * safe_dist


## P1-133 — le rayon pivot -> caméra frôle le relief quand on regarde d'en bas :
## la caméra se posait alors SOUS le terrain (envers du décor visible). Un rayon
## vertical, parti bien au-dessus d'elle, trouve le dessus du SOL (masque terrain)
## et la remonte à `camera_ground_clearance_raw` au-dessus.
@export var camera_ground_clamp_enabled: bool = true
@export var camera_ground_clearance_raw: float = 24.0
@export var camera_ground_mask: int = 1

func _clamp_above_ground(position: Vector3, pivot: Vector3) -> Vector3:
	if not camera_ground_clamp_enabled or not is_inside_tree():
		return position
	var world := get_world_3d()
	if world == null:
		return position
	var up := maxf(pivot.y, position.y) + 4000.0 * _world_scale
	var query := PhysicsRayQueryParameters3D.create(Vector3(position.x, up, position.z),
		Vector3(position.x, position.y - 2000.0 * _world_scale, position.z), camera_ground_mask)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	query.hit_back_faces = true
	var hit := world.direct_space_state.intersect_ray(query)
	var ground_y := NAN
	if not hit.is_empty():
		ground_y = (hit.get("position", position) as Vector3).y
	elif zone_viewer != null and zone_viewer.has_method("godot_to_daoc") and zone_viewer.has_method("sample_daoc_floor_z") and zone_viewer.has_method("daoc_to_godot") and player != null and "daoc_zone" in player:
		# Terrain sans corps physique (P1-74) : la carte de hauteurs fait foi.
		var zone := int(player.get("daoc_zone"))
		var local: Vector3 = zone_viewer.call("godot_to_daoc", zone, position) as Vector3
		var raw_floor := float(zone_viewer.call("sample_daoc_floor_z", zone, local.x, local.y, local.z))
		ground_y = (zone_viewer.call("daoc_to_godot", zone, local.x, local.y, raw_floor) as Vector3).y
	if is_nan(ground_y):
		return position
	var floor_y := ground_y + camera_ground_clearance_raw * _world_scale * _height_exaggeration
	if position.y < floor_y:
		position.y = floor_y
		last_collision_hit = true
	return position


func _get_player_heading_deg() -> float:
	if player != null:
		var v: Variant = player.get("heading_deg")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return float(v)
	return 0.0


func _clamp_camera_distance(v: float) -> float:
	var max_distance := DAOC_CAMERA_DISTANCE_MAX_SPECIAL if allow_boat_zoom_max else DAOC_CAMERA_DISTANCE_MAX
	return clampf(v, DAOC_CAMERA_DISTANCE_MIN, max_distance)


func _wrap_heading_units(v: float) -> float:
	return fposmod(v, DAOC_HEADING_UNITS)


func _heading_delta_units(from_units: float, to_units: float) -> float:
	return fposmod(to_units - from_units + DAOC_HEADING_UNITS * 0.5, DAOC_HEADING_UNITS) - DAOC_HEADING_UNITS * 0.5


func _move_toward_heading_units(from_units: float, to_units: float, max_delta: float) -> float:
	var delta := _heading_delta_units(from_units, to_units)
	if absf(delta) <= max_delta:
		return _wrap_heading_units(to_units)
	var step := max_delta if delta > 0.0 else -max_delta
	return _wrap_heading_units(from_units + step)


func _load_camera_from_ini(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	if not FileAccess.file_exists(path):
		if debug_camera:
			print("daoc camera ini not found: ", path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var in_camera := false
	var found := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			in_camera = line.to_lower() == "[camera]"
			continue
		if not in_camera or not line.contains("="):
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges().to_lower()
		var val := line.substr(eq + 1).strip_edges()
		match key:
			"distance":
				distance_raw = float(val)
				found = true
			"height":
				height_raw = float(val)
				found = true
			"tilt":
				tilt_raw = float(val)
				found = true
			"angle":
				angle_raw = float(val)
				found = true
	if found:
		distance_raw = _clamp_camera_distance(distance_raw)
		height_raw = clampf(height_raw, DAOC_CAMERA_HEIGHT_MIN, DAOC_CAMERA_HEIGHT_MAX)
		angle_raw = _wrap_heading_units(angle_raw)
		tilt_raw = clampf(tilt_raw, tilt_min_raw, tilt_max_raw)
		if debug_camera:
			_print_state("ini")
	return found


func _print_state(prefix: String) -> void:
	print("daoc camera ", prefix, " dist=", distance_raw, " height=", height_raw, " tilt=", tilt_raw, " angle=", angle_raw)
