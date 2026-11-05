extends Node3D
class_name DaocWeatherFx

signal ground_wetness_changed(amount: float)

const RAIN_TEXTURE := preload("res://assets/placeholders/rain_streak.svg")
const SNOW_TEXTURE := preload("res://assets/placeholders/snow_flake.svg")

## Camera-centred native Godot precipitation. One rain emitter and one snow
## emitter replace any attempt to cover a complete DAoC region with particles.

var rain_particles: GPUParticles3D = null
var snow_particles: GPUParticles3D = null
var follow_camera: bool = true
var follow_height_raw: float = 1800.0
var _manual_anchor: Node3D = null
var _last_state: Dictionary = {}
var wetness: float = 0.0
var wet_soak_seconds: float = 14.0
var wet_dry_seconds: float = 90.0
var _rain_target: float = 0.0


func _ready() -> void:
	if rain_particles == null:
		_build_emitters()
	set_process(true)


func setup(anchor: Node3D = null) -> Dictionary:
	_manual_anchor = anchor
	if rain_particles == null:
		_build_emitters()
	return debug_snapshot()


func apply_environment_state(state: Dictionary) -> void:
	if rain_particles == null:
		_build_emitters()
	_last_state = state.duplicate(true)
	var rain := clampf(float(state.get("rain_intensity", 0.0)), 0.0, 1.0)
	var snow := clampf(float(state.get("snow_intensity", 0.0)), 0.0, 1.0)
	rain_particles.amount_ratio = rain
	snow_particles.amount_ratio = snow
	rain_particles.emitting = rain > 0.005
	snow_particles.emitting = snow > 0.005
	_rain_target = rain


func _process(delta: float) -> void:
	var anchor := _manual_anchor
	if anchor == null and follow_camera and get_viewport() != null:
		anchor = get_viewport().get_camera_3d()
	if anchor != null:
		global_position = anchor.global_position + Vector3.UP * follow_height_raw
	var old_wetness := wetness
	var duration := wet_soak_seconds if _rain_target > wetness else wet_dry_seconds
	wetness = move_toward(wetness, _rain_target, maxf(delta, 0.0) / maxf(0.1, duration))
	if absf(wetness - old_wetness) >= 0.0001:
		ground_wetness_changed.emit(wetness)


func _build_emitters() -> void:
	rain_particles = _make_rain()
	rain_particles.name = "RainParticles"
	add_child(rain_particles)
	snow_particles = _make_snow()
	snow_particles.name = "SnowParticles"
	add_child(snow_particles)


func _make_rain() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 1400
	particles.lifetime = 1.45
	particles.preprocess = 1.45
	particles.visibility_aabb = AABB(Vector3(-3600, -3800, -3600), Vector3(7200, 7600, 7200))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3200.0, 1600.0, 3200.0)
	process.direction = Vector3.DOWN
	process.spread = 4.0
	process.initial_velocity_min = 3600.0
	process.initial_velocity_max = 5200.0
	process.gravity = Vector3(220.0, -1100.0, 80.0)
	particles.process_material = process
	particles.draw_pass_1 = _particle_quad(Vector2(7.0, 108.0), Color(0.72, 0.83, 1.0, 0.62), RAIN_TEXTURE)
	return particles


func _make_snow() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 800
	particles.lifetime = 5.5
	particles.preprocess = 5.5
	particles.visibility_aabb = AABB(Vector3(-3600, -3800, -3600), Vector3(7200, 7600, 7200))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3000.0, 1400.0, 3000.0)
	process.direction = Vector3.DOWN
	process.spread = 28.0
	process.initial_velocity_min = 180.0
	process.initial_velocity_max = 420.0
	process.gravity = Vector3(35.0, -45.0, 20.0)
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -55.0
	process.angular_velocity_max = 55.0
	process.scale_min = 0.55
	process.scale_max = 1.35
	particles.process_material = process
	particles.draw_pass_1 = _particle_quad(Vector2(13.0, 13.0), Color(0.94, 0.97, 1.0, 0.88), SNOW_TEXTURE)
	return particles


func _particle_quad(size: Vector2, color: Color, texture: Texture2D) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


func debug_snapshot() -> Dictionary:
	return {
		"camera_centred": follow_camera,
		"rain_present": rain_particles != null,
		"snow_present": snow_particles != null,
		"rain_emitting": rain_particles.emitting if rain_particles != null else false,
		"snow_emitting": snow_particles.emitting if snow_particles != null else false,
		"rain_amount": rain_particles.amount if rain_particles != null else 0,
		"snow_amount": snow_particles.amount if snow_particles != null else 0,
		"wetness": wetness,
		"rain_texture": RAIN_TEXTURE != null,
		"snow_texture": SNOW_TEXTURE != null,
		"last_state": _last_state.duplicate(true),
	}
