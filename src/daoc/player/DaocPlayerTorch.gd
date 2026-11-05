extends Node3D
class_name DaocPlayerTorch

## Torche/lanterne moderne attachee au joueur. T la bascule, comme le client
## d'origine. Deux sources donnent a la fois une lumiere locale douce et un
## faisceau utile pour lire le chemin sans eclairer toute la zone.

var toggle_key: Key = KEY_T
var enabled_on_start: bool = false
var warm_color := Color(1.0, 0.63, 0.31)
var energy: float = 12.0
var range_raw: float = 2100.0
var shadows: bool = true
## Direction artistique des ombres de flamme (P1-91) : bords larges et fondus,
## jamais tout a fait noires - la nuit garde son ambiance autour du porteur.
var shadow_blur: float = 2.4
var shadow_opacity: float = 0.85
var flicker_amount: float = 0.08
## Orientation du faisceau dans le repere du joueur. L AVANT DU JOUEUR EST SON
## +X LOCAL (DaocPlayerMotor : cap 0 = DAoC +X, rotation.y = -cap) alors qu un
## SpotLight3D vise son -Z : sans lacet, le faisceau eclairait la GAUCHE du
## porteur (constat du 2026-09-22). -90 degres ramenent le -Z du spot sur +X.
var beam_yaw_deg: float = -90.0
var beam_pitch_deg: float = -9.0
## Eclaircissement du monde torche allumee (0.10 = +10 %). La torche ne touche
## pas l Environment elle-meme : DaocGameWorld ecoute torch_toggled.
var world_brightness_boost: float = 0.10

signal torch_toggled(enabled: bool, world_brightness_boost: float)

var _omni: OmniLight3D = null
var _spot: SpotLight3D = null
var _glow: MeshInstance3D = null
var _enabled := false
var _clock := 0.0


func setup(options: Dictionary = {}) -> Dictionary:
	toggle_key = int(options.get("toggle_key", toggle_key))
	enabled_on_start = bool(options.get("enabled_on_start", enabled_on_start))
	warm_color = options.get("color", warm_color) as Color
	energy = float(options.get("energy", energy))
	range_raw = float(options.get("range_raw", range_raw))
	shadows = bool(options.get("shadows", shadows))
	shadow_blur = maxf(0.0, float(options.get("shadow_blur", shadow_blur)))
	shadow_opacity = clampf(float(options.get("shadow_opacity", shadow_opacity)), 0.0, 1.0)
	flicker_amount = clampf(float(options.get("flicker_amount", flicker_amount)), 0.0, 0.35)
	beam_yaw_deg = float(options.get("beam_yaw_deg", beam_yaw_deg))
	beam_pitch_deg = float(options.get("beam_pitch_deg", beam_pitch_deg))
	world_brightness_boost = clampf(float(options.get("world_brightness_boost", world_brightness_boost)), 0.0, 1.0)
	_build()
	_apply_beam_orientation()
	set_torch_enabled(enabled_on_start)
	return debug_snapshot()


func _ready() -> void:
	if _omni == null:
		_build()
	set_process_input(true)
	set_process(true)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	if key_event.keycode != toggle_key and key_event.physical_keycode != toggle_key:
		return
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus is LineEdit or focus is TextEdit:
		return
	set_torch_enabled(not _enabled)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _enabled or _omni == null or _spot == null:
		return
	_clock += maxf(delta, 0.0)
	var wave := sin(_clock * 8.7) * 0.55 + sin(_clock * 17.3 + 1.2) * 0.30 \
		+ sin(_clock * 31.1 + 0.4) * 0.15
	var multiplier := 1.0 + wave * flicker_amount
	_omni.light_energy = energy * 0.5 * multiplier
	_spot.light_energy = energy * multiplier


func set_torch_enabled(value: bool) -> void:
	_enabled = value
	if _omni != null:
		_omni.visible = value
	if _spot != null:
		_spot.visible = value
	if _glow != null:
		_glow.visible = value
	torch_toggled.emit(value, world_brightness_boost if value else 0.0)


func set_beam_orientation(yaw_deg: float, pitch_deg: float) -> void:
	beam_yaw_deg = yaw_deg
	beam_pitch_deg = pitch_deg
	_apply_beam_orientation()


func set_world_brightness_boost(value: float) -> void:
	world_brightness_boost = clampf(value, 0.0, 1.0)
	if _enabled:
		torch_toggled.emit(true, world_brightness_boost)


func _apply_beam_orientation() -> void:
	if _spot == null:
		return
	# Ordre d Euler YXZ de Godot : le lacet oriente le faisceau vers l avant du
	# joueur, puis le tangage l incline vers le sol dans SON axe, pas dans
	# celui du porteur.
	_spot.rotation_degrees = Vector3(beam_pitch_deg, beam_yaw_deg, 0.0)


func _build() -> void:
	if _omni != null:
		return
	position = Vector3(28.0, 105.0, -8.0)
	_omni = OmniLight3D.new()
	_omni.name = "WarmFill"
	_omni.light_color = warm_color
	_omni.light_energy = energy * 0.5
	# LE REMPLISSAGE TUAIT LES OMBRES DU FAISCEAU. Mesure le 2026-09-18 : a la
	# meme portee et la meme energie que le faisceau, cet omni SANS ombre
	# reeclairait tout ce que le faisceau ombrageait - l ombre d un PNJ devenait
	# un demi-ton invisible. Il ne fait plus que la lueur autour du porteur.
	_omni.omni_range = range_raw * 0.30
	_omni.omni_attenuation = 0.9
	_omni.shadow_enabled = false
	add_child(_omni)

	_spot = SpotLight3D.new()
	_spot.name = "PathBeam"
	_spot.light_color = warm_color.lerp(Color(1.0, 0.82, 0.58), 0.32)
	_spot.light_energy = energy
	_spot.spot_range = range_raw
	_spot.spot_angle = 51.0
	_spot.spot_attenuation = 0.55
	_spot.spot_angle_attenuation = 0.72
	_spot.shadow_enabled = shadows
	_spot.shadow_blur = shadow_blur
	_spot.shadow_opacity = shadow_opacity
	add_child(_spot)
	_apply_beam_orientation()

	_glow = MeshInstance3D.new()
	_glow.name = "EmberGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 4.2
	sphere.height = 8.4
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(warm_color.r, warm_color.g, warm_color.b, 0.82)
	material.emission_enabled = true
	material.emission = warm_color
	material.emission_energy_multiplier = 3.0
	sphere.material = material
	_glow.mesh = sphere
	add_child(_glow)


func debug_snapshot() -> Dictionary:
	return {
		"enabled": _enabled,
		"key": int(toggle_key),
		"energy": energy,
		"range_raw": range_raw,
		"shadows": shadows,
		"shadow_blur": shadow_blur,
		"shadow_opacity": shadow_opacity,
		"beam_yaw_deg": beam_yaw_deg,
		"beam_pitch_deg": beam_pitch_deg,
		"beam_forward_local": (_spot.transform.basis * Vector3.FORWARD) if _spot != null else Vector3.ZERO,
		"world_brightness_boost": world_brightness_boost,
		"omni": _omni != null,
		"spot": _spot != null,
	}
