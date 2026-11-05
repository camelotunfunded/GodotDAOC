extends Node
class_name DaocWaterFx

const UNDERWATER_SHADER = preload("res://src/daoc/water/DaocUnderwaterOverlay.gdshader")

## Runtime-only water feedback. It consumes the existing DaocWaterRuntime
## oracle through ZoneViewer and never changes movement/gameplay authority.

var enabled: bool = true
var underwater_enabled: bool = true
var wake_enabled: bool = true
var caustic_fps: float = 12.0
var caustic_frame_count: int = 64
var water_vertical_offset_raw: float = 8.0
var wake_size_raw: float = 230.0
var wake_speed_threshold_raw: float = 30.0

var host: Node = null
var player: Node3D = null
var camera: Camera3D = null
var client_root: String = ""

var overlay_layer: CanvasLayer = null
var overlay_rect: ColorRect = null
var overlay_material: ShaderMaterial = null
var wake_particles: GPUParticles3D = null
var wake_material: StandardMaterial3D = null

var _texture_cache: Dictionary = {}
var _caustic_clock: float = 0.0
var _caustic_frame: int = -1
var _underwater: bool = false
var _last_camera_water_info: Dictionary = {}
var _last_wake_position := Vector3.ZERO
var _wake_texture_path: String = ""
var _caustic_texture_path: String = ""
var _world_scale: float = 1.0
var _height_exaggeration: float = 1.0


func setup(p_host: Node, p_player: Node3D, p_camera: Camera3D, p_client_root: String, options: Dictionary = {}) -> Dictionary:
	host = p_host
	player = p_player
	camera = p_camera
	client_root = p_client_root.strip_edges().replace("\\", "/").trim_suffix("/")
	enabled = bool(options.get("enabled", enabled))
	underwater_enabled = bool(options.get("underwater_enabled", underwater_enabled))
	wake_enabled = bool(options.get("wake_enabled", wake_enabled))
	caustic_fps = maxf(1.0, float(options.get("caustic_fps", caustic_fps)))
	water_vertical_offset_raw = float(options.get("water_vertical_offset_raw", water_vertical_offset_raw))
	wake_size_raw = maxf(16.0, float(options.get("wake_size_raw", wake_size_raw)))
	wake_speed_threshold_raw = maxf(0.0, float(options.get("wake_speed_threshold_raw", wake_speed_threshold_raw)))
	if host != null:
		_world_scale = float(host.get("world_scale"))
		_height_exaggeration = float(host.get("height_exaggeration"))
	_build_overlay()
	_build_wake()
	set_process(enabled)
	return debug_snapshot()


func _process(delta: float) -> void:
	if not enabled:
		_set_underwater(false)
		_set_wake_emitting(false)
		return
	_update_underwater(maxf(delta, 0.0))
	_update_wake()


func debug_snapshot() -> Dictionary:
	return {
		"scope": "P1-20L2 Water immersion/caustics/wake",
		"enabled": enabled,
		"underwater_enabled": underwater_enabled,
		"underwater": _underwater,
		"camera_water_info": _last_camera_water_info.duplicate(true),
		"overlay_present": overlay_rect != null,
		"overlay_visible": overlay_rect.visible if overlay_rect != null else false,
		"caustic_frame": _caustic_frame,
		"caustic_fps": caustic_fps,
		"caustic_texture_path": _caustic_texture_path,
		"wake_enabled": wake_enabled,
		"wake_present": wake_particles != null,
		"wake_emitting": wake_particles.emitting if wake_particles != null else false,
		"wake_position": _last_wake_position,
		"wake_texture_path": _wake_texture_path,
		"external_texture_cache_size": _texture_cache.size(),
		"png_only": true,
		"gameplay_authority_changed": false,
	}


func clear_runtime_cache() -> void:
	_texture_cache.clear()


func _build_overlay() -> void:
	if overlay_layer != null:
		return
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "DaocUnderwaterLayer"
	overlay_layer.layer = 90
	add_child(overlay_layer)
	overlay_rect = ColorRect.new()
	overlay_rect.name = "DaocUnderwaterOverlay"
	overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_rect.visible = false
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = UNDERWATER_SHADER
	overlay_material.set_shader_parameter("effect_strength", 0.0)
	overlay_rect.material = overlay_material
	overlay_layer.add_child(overlay_rect)
	_set_caustic_frame(0)


func _build_wake() -> void:
	if wake_particles != null:
		return
	wake_particles = GPUParticles3D.new()
	wake_particles.name = "DaocPlayerWake"
	wake_particles.amount = 30
	wake_particles.lifetime = 2.2
	wake_particles.randomness = 0.18
	wake_particles.local_coords = false
	wake_particles.emitting = false
	wake_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wake_particles.visibility_aabb = AABB(
		Vector3(-1200, -80, -1200) * _world_scale,
		Vector3(2400, 160, 2400) * _world_scale
	)
	wake_particles.rotation_degrees.x = -90.0

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_material.direction = Vector3.ZERO
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.0
	process_material.initial_velocity_max = 0.0
	process_material.scale_min = 0.26
	process_material.scale_max = 0.42
	var scale_curve := Curve.new()
	scale_curve.min_value = 0.0
	scale_curve.max_value = 2.6
	scale_curve.add_point(Vector2(0.0, 0.18))
	scale_curve.add_point(Vector2(0.20, 1.0))
	scale_curve.add_point(Vector2(1.0, 2.35))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process_material.scale_curve = scale_texture
	var colour_gradient := Gradient.new()
	colour_gradient.set_color(0, Color(0.78, 0.92, 0.96, 0.0))
	colour_gradient.set_color(1, Color(0.58, 0.78, 0.86, 0.0))
	colour_gradient.add_point(0.10, Color(0.78, 0.92, 0.96, 0.62))
	colour_gradient.add_point(0.68, Color(0.62, 0.82, 0.89, 0.24))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = colour_gradient
	process_material.color_ramp = gradient_texture
	wake_particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * wake_size_raw * _world_scale
	wake_material = StandardMaterial3D.new()
	wake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wake_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wake_material.vertex_color_use_as_albedo = true
	_wake_texture_path = client_root.path_join("water/water_wake.png")
	var wake_texture := _load_external_png(_wake_texture_path, true)
	if wake_texture != null:
		wake_material.albedo_texture = wake_texture
	quad.material = wake_material
	wake_particles.draw_pass_1 = quad
	add_child(wake_particles)


func _update_underwater(delta: float) -> void:
	if not underwater_enabled or camera == null or host == null or player == null:
		_set_underwater(false)
		return
	var zone := int(player.get("daoc_zone"))
	var origin: Vector3 = host.call("daoc_to_godot", zone, 0.0, 0.0, 0.0) as Vector3
	var camera_daoc_x := (camera.global_position.x - origin.x) / maxf(_world_scale, 0.00001)
	var camera_daoc_y := (camera.global_position.z - origin.z) / maxf(_world_scale, 0.00001)
	var camera_daoc_z := (camera.global_position.y - origin.y) / maxf(_world_scale * _height_exaggeration, 0.00001)
	_last_camera_water_info = host.call("sample_daoc_water_info", zone, camera_daoc_x, camera_daoc_y, camera_daoc_z) as Dictionary
	var submerged := bool(_last_camera_water_info.get("in_water", false))
	_set_underwater(submerged)
	if submerged:
		_caustic_clock = fmod(_caustic_clock + delta, 100000.0)
		var next_frame := int(floor(_caustic_clock * caustic_fps)) % caustic_frame_count
		if next_frame != _caustic_frame:
			_set_caustic_frame(next_frame)


func _set_underwater(value: bool) -> void:
	_underwater = value
	if overlay_rect != null:
		overlay_rect.visible = value
	if overlay_material != null:
		overlay_material.set_shader_parameter("effect_strength", 1.0 if value else 0.0)


func _set_caustic_frame(frame: int) -> void:
	_caustic_frame = posmod(frame, caustic_frame_count)
	_caustic_texture_path = client_root.path_join("effects/caustic/caust_%03d.png" % (_caustic_frame + 1))
	var texture := _load_external_png(_caustic_texture_path, false)
	if texture != null and overlay_material != null:
		overlay_material.set_shader_parameter("caustic_texture", texture)


func _update_wake() -> void:
	if not wake_enabled or wake_particles == null or player == null or host == null:
		_set_wake_emitting(false)
		return
	var water_info: Dictionary = player.get("last_water_info") as Dictionary
	var in_water := bool(player.get("is_in_water")) and not water_info.is_empty()
	var move_vector: Vector2 = player.get("last_move_vector") as Vector2
	var speed := float(player.get("last_speed_raw")) * move_vector.length()
	var emitting := in_water and speed >= wake_speed_threshold_raw
	if in_water:
		var zone := int(player.get("daoc_zone"))
		var surface_height := float(water_info.get("height", player.get("daoc_z"))) + water_vertical_offset_raw + 2.0
		_last_wake_position = host.call("daoc_to_godot", zone, float(player.get("daoc_x")), float(player.get("daoc_y")), surface_height) as Vector3
		wake_particles.global_position = _last_wake_position
		wake_particles.amount_ratio = clampf(speed / maxf(float(player.get("local_run_speed_raw")), 1.0), 0.18, 1.0) if emitting else 0.0
	_set_wake_emitting(emitting)


func _set_wake_emitting(value: bool) -> void:
	if wake_particles != null:
		wake_particles.emitting = value
		if not value:
			wake_particles.amount_ratio = 0.0


func _load_external_png(path: String, mipmaps: bool) -> Texture2D:
	if path.is_empty() or not path.to_lower().ends_with(".png"):
		return null
	var key := path.to_lower()
	if _texture_cache.has(key):
		return _texture_cache[key] as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	if mipmaps and not image.has_mipmaps():
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture
