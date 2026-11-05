extends Node
class_name DaocSky3DAdapter

## Replaceable rendering backend for the DAoC controller. Sky3D never receives
## network packets, zone rules, or authority decisions directly.

const Sky3DScript = preload("res://addons/sky_3d/src/Sky3D.gd")

const CLOUD_PROFILE: String = "DAOC_REALM_LEGACY_4_LAYER"
const CELESTIAL_PROFILE: String = "DAOC_LEGACY_SPRITE_SUN_MOON"
## Fallbacks used only when a key is missing from the zone's sky_*.dat. They are
## the values Mythic shipped in sky_albion.dat, not invented numbers.
const CELESTIAL_FALLBACK: Dictionary = {
	"sun_distance": 1000.0, "sun_scale": 15.0,
	"sunflare_scale": 150.0, "sunglow_scale": 150.0,
	"moon_distance": 1000.0, "moon_scale": 15.0,
}
const MAX_VOLUMETRIC_FOG_DENSITY: float = 0.00016
const MAX_SUN_RAYS_ENERGY: float = 2.0

## Graphics quality options, each one switchable on its own so the client can stay
## light on a modest configuration. These describe HOW the state is rendered; the
## DAoC state itself (time, zone, weather) still arrives through
## `apply_environment_state` and is never decided here.
##
## The defaults ARE the shipped preset, so a caller that never configures anything
## gets the same picture as the F5 scene. Two effects default to OFF on purpose:
## `ambient_from_sky` changes the P1-20K lighting contract, and `volumetric_fog`
## carries the Sky3D/Godot 4.6 regression plus by far the highest cost.
const QUALITY_DEFAULTS: Dictionary = {
	"glow_enabled": true,
	"glow_intensity": 0.55,
	"glow_hdr_threshold": 1.0,
	"ambient_from_sky_enabled": false,
	"ambient_sky_contribution": 0.85,
	"ambient_energy_scale": 1.0,
	"realtime_radiance_enabled": true,
	"aerial_perspective_enabled": true,
	"aerial_perspective_amount": 0.35,
	"volumetric_fog_enabled": false,
	"volumetric_fog_density": 0.00012,
	"volumetric_fog_length": 6000.0,
	"sun_rays_energy": 1.5,
	"ssao_enabled": true,
	"ssao_radius": 1.6,
	"ssao_intensity": 2.0,
	"ssao_power": 1.35,
	# LA LUNE DE SKY3D NE SE LEVE PAS FORCEMENT LA NUIT. Son mode par defaut,
	# REALISTIC, calcule une vraie orbite lunaire a partir de la date : avec la
	# date livree elle est proche du soleil, donc levee EN PLEIN JOUR et absente
	# de toutes les nuits. Mesure pendant P1-32 : sur les 96 quarts d'heure d'une
	# journee, AUCUN ne leve la lune pendant que le soleil est couche.
	# DAoC n'a pas d'orbite lunaire : son `sky_*.dat` ne porte qu'une distance et
	# une echelle, et sa lune est simplement a l'oppose du soleil - ce que fait
	# le mode SIMPLE de Sky3D. Decocher rend l'orbite astronomique de Sky3D.
	"opposite_moon_enabled": true,
	# OMBRES. En mode SIMPLE l'arc solaire passe PAR LE ZENITH a midi : les
	# ombres tombent a la verticale et toute facade lit plat. Le DAT porte
	# `ecliptic_angle` (15 degres pour Albion), applique ici pour la premiere
	# fois ; ce supplement l'incline davantage pour que le soleil culmine vers
	# 55 degres au lieu de 90. 0 rend l'inclinaison du seul DAT.
	"sun_arc_extra_tilt_degrees": 20.0,
	# Taille angulaire du soleil pour Godot : > 0 arme les ombres douces PCSS.
	# ZERO PAR DEFAUT, ET CE N'EST PAS UN CHOIX ESTHETIQUE : mesure le 2026-09-18,
	# a 0,5 degre les ombres directionnelles DISPARAISSENT ENTIEREMENT des que la
	# scene est a plus de ~10 000 unites de l'origine (bisection : a 5 000 elles
	# tiennent, a 20 000 plus rien ; une lumiere identique a 0 degre les rend).
	# Or la zone 51 vit vers (33 000, 3 000, 53 000). Une lumiere sans PCSS
	# n'est pas concernee. Ne remonter cette valeur que si la scene est
	# recentree pres de l'origine.
	"shadow_softness_degrees": 0.0,
	# Portee des ombres du soleil, en unites monde. Godot livre 100 : dans un
	# monde a l'echelle DAoC brute (un personnage fait ~80 unites) les ombres
	# s'arretaient a un pas de la camera. 5000 couvre la place d'un village.
	# CE N'ETAIT PAS la cause du « monde plat » : elle etait dans le SENS DES
	# FACES du terrain et des decors (DaocTerrainBuilder._visual_winding,
	# DaocMeshWindingFix), qui les eclairait par en dessous.
	"shadow_max_distance": 5000.0,
	# Multiplie le soleil (1,15 x meteo) sans toucher l'ambiance. 1,0 = livre :
	# depuis que le sol recoit vraiment le soleil, aucun renfort n'est necessaire.
	"sun_energy_scale": 1.0,
	# Palette purement visuelle du soleil. Elle teinte la lumiere directe selon
	# l'heure, sans changer l'horloge, la meteo ni aucune autorite DAoC.
	"sun_warm_palette_enabled": false,
	"sun_day_color": Color(1.0, 0.965, 0.90),
	"sun_low_color": Color(1.0, 0.68, 0.42),
	"sun_warmth_strength": 0.65,
	# COULEURS. Sky3D pose ACES avec un blanc a 6 : il aplatit et grise les
	# teintes moyennes. AgX (Godot 4.3+) garde la saturation des couleurs
	# vives sans les faire virer ; les deux reglages suivants passent par
	# `Environment.adjustment_*`, coupes si saturation = contraste = 1.
	"tonemap_agx_enabled": true,
	"tonemap_exposure": 1.0,
	"color_saturation": 1.18,
	"color_contrast": 1.06,
	# NUAGES. Ombrage 2D des bords et des bases, et lumiere qui filtre au
	# travers des bords fins face au soleil. 0 rend le voile plat d'avant.
	"cloud_shading": 0.7,
	"cloud_silver_lining": 0.6,
	# Derive lente des formes (hauteur et compacite des couches, direction du
	# vent) pour que le ciel ne soit jamais deux fois le meme. Sans effet sur
	# les regles DAoC : c'est la meme couverture, vue vivre.
	"cloud_drift_enabled": true,
}
## Formes de nuages, par couche (top, bottom, top2, bottom2) : hauteur du
## plafond (1 haut, 0 bas) et compacite (0 compacte, 1 diffuse). Les deux jeux
## sont melanges par l'influence meteo, puis derivent lentement autour.
const CLOUD_SHAPE_CLEAR: Dictionary = {
	"altitude": Vector4(0.85, 0.35, 0.65, 0.20),
	"softness": Vector4(0.50, 0.25, 0.75, 0.35),
}
const CLOUD_SHAPE_STORM: Dictionary = {
	"altitude": Vector4(0.40, 0.10, 0.25, 0.05),
	"softness": Vector4(0.85, 0.60, 0.95, 0.70),
}
## Valeur de `TimeOfDay.CelestialMode.SIMPLE`, recopiee plutot que reference :
## l'enum vit dans un script du greffon que cet adapter ne precharge pas.
const CELESTIAL_MODE_SIMPLE: int = 0
const CELESTIAL_MODE_REALISTIC: int = 1

var sky3d: WorldEnvironment = null
var _quality: Dictionary = QUALITY_DEFAULTS.duplicate(true)
var _last_state: Dictionary = {}
var _screen_space_fog_disabled_for_godot_46: bool = true
var _active_cloud_realm_id: int = 1
var _active_cloud_realm_name: String = "Albion"
var _active_cloud_layers: Array[String] = []
var _active_cloud_tiles := Vector4.ZERO
var _active_cloud_speeds := Vector4.ZERO
var _active_cloud_source_root: String = ""
var _active_cloud_recipe_path: String = ""
var _active_cloud_recipe_source: String = "FALLBACK"
var _active_clouds_loaded: bool = false
var _missing_cloud_paths: Array[String] = []
var _external_texture_cache: Dictionary = {}
var _realm_recipe_cache: Dictionary = {}
var _cloud_motion_seconds: float = 0.0
var _cloud_motion_direction := Vector2(1.0, 0.35).normalized()
## Deplacement UV accumule : la direction du vent tourne lentement, donc le
## produit direction x secondes ferait sauter toute la nappe a chaque virage.
var _cloud_motion_offset := Vector2.ZERO
var _cloud_shape: Dictionary = {}
var _active_ecliptic_degrees: float = 0.0
var _horizon_fog_density_addition: float = 0.0
var _brightness_boost: float = 0.0
var _celestial_texture_cache: Dictionary = {}
var _active_celestial: Dictionary = {}
var _celestial_loaded: bool = false
var _missing_celestial_paths: Array[String] = []


func setup() -> Dictionary:
	if sky3d != null and is_instance_valid(sky3d):
		return debug_snapshot()
	sky3d = Sky3DScript.new() as WorldEnvironment
	sky3d.name = "Sky3D"
	add_child(sky3d)
	# The DAoC controller owns time. Sky3D only renders the supplied value.
	sky3d.set("game_time_enabled", false)
	sky3d.set("editor_time_enabled", false)
	sky3d.set("update_interval", 0.10)
	# Godot 4.6 regression: Sky3D screen-space fog + volumetric fog can split
	# the frame. Use Godot's native exponential fog, driven below, instead.
	# The screen-space backend stays off in every quality preset; only Godot's
	# own volumetric fog can be re-armed, and only by explicit opt-in.
	sky3d.set("fog_enabled", false)
	_apply_quality_options(true)
	return debug_snapshot()


## Rendering-side options only. Never call this to express a DAoC rule: the zone,
## the hour and the weather front arrive through `apply_environment_state`.
func set_quality_options(options: Dictionary) -> void:
	for key in options.keys():
		if _quality.has(key):
			_quality[key] = options[key]
	if _last_state.is_empty():
		_apply_quality_options(true)
	else:
		apply_environment_state(_last_state)


func quality_options() -> Dictionary:
	return _quality.duplicate(true)


## Applies the switchable effects to the live Environment. `outside` follows the
## zone's sky mode: a NO_SKY dungeon keeps the screen-space glow but gets neither
## aerial perspective nor sun shafts, since it has no sky and no zone fog to read.
func _apply_quality_options(outside: bool) -> void:
	if sky3d == null:
		return
	var environment := sky3d.environment
	if environment == null:
		return

	# Glow. Sky3D renders its sun disk at sun_disk_intensity = 30.0, well into
	# HDR, but Godot leaves glow off by default: ACES tonemapping flattened that
	# value into a plain white disc. SCREEN blending keeps the halo from blowing
	# out a bright overcast the way ADDITIVE does.
	environment.glow_enabled = bool(_quality["glow_enabled"])
	if environment.glow_enabled:
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		environment.glow_intensity = float(_quality["glow_intensity"])
		environment.glow_strength = 1.0
		environment.glow_bloom = 0.0
		environment.glow_hdr_threshold = float(_quality["glow_hdr_threshold"])
		# A wide, soft solar halo rather than a tight fringe: the low levels stay
		# dark so ordinary lit surfaces do not smear.
		environment.set("glow_levels/1", 0.0)
		environment.set("glow_levels/2", 0.0)
		environment.set("glow_levels/3", 0.6)
		environment.set("glow_levels/4", 1.0)
		environment.set("glow_levels/5", 0.7)
		environment.set("glow_levels/6", 0.3)
		environment.set("glow_levels/7", 0.0)

	# Sky radiance. Ambient (when taken from the sky) and reflections both read a
	# baked radiance map; left stale, the world keeps a noon sky at dusk. REALTIME
	# is capped at 256 px by Godot, so the size is pinned here rather than left to
	# a silent fallback.
	if environment.sky != null:
		if bool(_quality["realtime_radiance_enabled"]):
			environment.sky.radiance_size = Sky.RADIANCE_SIZE_256
			environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		else:
			# Not a frozen sky: INCREMENTAL keeps the day/night cycle correct but
			# spreads one radiance bake over several frames instead of paying it
			# whole, every frame.
			environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	# Aerial perspective rides on the native zone fog, so it is meaningless where
	# that fog is off. Unrelated to the volumetric backend below.
	if outside and bool(_quality["aerial_perspective_enabled"]):
		environment.fog_aerial_perspective = float(_quality["aerial_perspective_amount"])
	else:
		environment.fog_aerial_perspective = 0.0

	# Volumetric fog: the only source of real sun shafts, and the most expensive
	# thing in this file. Off by default.
	var volumetric := outside and bool(_quality["volumetric_fog_enabled"])
	environment.volumetric_fog_enabled = volumetric
	if volumetric:
		# Les anciens presets pouvaient monter a 0,05 et 8,0 : dans l'echelle
		# brute DAoC cela lave toute l'image. Borner aussi ici protege les scenes
		# et fichiers de configuration deja sauvegardes, pas seulement l'inspecteur.
		environment.volumetric_fog_density = clampf(
			float(_quality["volumetric_fog_density"]), 0.0, MAX_VOLUMETRIC_FOG_DENSITY)
		environment.volumetric_fog_length = maxf(1.0, float(_quality["volumetric_fog_length"]))
		# Forward scattering is what turns a grey haze into visible shafts.
		environment.volumetric_fog_anisotropy = 0.4
		environment.volumetric_fog_sky_affect = 0.0

	# Occlusion de contact : elle rattache les pieds, les herbes, les troncs et
	# les fondations au terrain sans ajouter une fausse ombre sous le joueur.
	environment.ssao_enabled = bool(_quality["ssao_enabled"])
	if environment.ssao_enabled:
		environment.ssao_radius = maxf(0.01, float(_quality["ssao_radius"]))
		environment.ssao_intensity = maxf(0.0, float(_quality["ssao_intensity"]))
		environment.ssao_power = maxf(0.01, float(_quality["ssao_power"]))

	# Couleurs. Sky3D pose ACES / blanc 6 dans son _ready ; AgX est rearme ici a
	# chaque passage puisque l'option peut changer en cours de partie.
	if bool(_quality["tonemap_agx_enabled"]):
		environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	else:
		environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		environment.tonemap_white = 6.0
	environment.tonemap_exposure = clampf(float(_quality["tonemap_exposure"]), 0.1, 4.0)
	var saturation := clampf(float(_quality["color_saturation"]), 0.0, 3.0)
	var contrast := clampf(float(_quality["color_contrast"]), 0.1, 3.0)
	environment.adjustment_saturation = saturation
	environment.adjustment_contrast = contrast
	_apply_brightness_boost(environment, saturation, contrast)

	# Ombres du soleil. Quatre tranches fondues pour que la limite de nettete
	# ne se lise pas comme une ligne au sol, et un diametre angulaire non nul
	# pour des penombres qui s'elargissent avec la distance a l'objet.
	var sun := sun_light()
	if sun != null:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_max_distance = maxf(10.0, float(_quality["shadow_max_distance"]))
		# Tranches serrees pres de la camera : c'est la que les pieds, les
		# poteaux et les murs se lisent ; le fond se contente d'une ombre large.
		sun.directional_shadow_split_1 = 0.06
		sun.directional_shadow_split_2 = 0.18
		sun.directional_shadow_split_3 = 0.45
		sun.directional_shadow_fade_start = 0.85
		sun.light_angular_distance = clampf(float(_quality["shadow_softness_degrees"]), 0.0, 5.0)
		sun.shadow_opacity = 1.0
		_apply_sun_palette(sun)

	# Orbite lunaire. DAoC place sa lune a l'oppose du soleil ; Sky3D calcule par
	# defaut une vraie orbite qui, a la date livree, la garde du cote du soleil.
	var tod: Object = sky3d.get("tod") as Object
	if tod != null:
		tod.set("celestials_calculations",
			CELESTIAL_MODE_SIMPLE if bool(_quality["opposite_moon_enabled"]) else CELESTIAL_MODE_REALISTIC)
		# Inclinaison de l'arc : l'`ecliptic_angle` du DAT de la zone, plus le
		# supplement de rendu. Ne concerne que le mode SIMPLE (voir TimeOfDay).
		var tilt := _active_ecliptic_degrees + clampf(float(_quality["sun_arc_extra_tilt_degrees"]), -60.0, 60.0)
		tod.set("simple_arc_tilt", deg_to_rad(clampf(tilt, -80.0, 80.0)))

	# Nuages : les deux reglages de rendu qui ne dependent pas de l'etat DAoC.
	var dome: Object = sky3d.get("sky") as Object
	var material := dome.get("sky_material") as ShaderMaterial if dome != null else null
	if material != null:
		material.set_shader_parameter("daoc_cloud_shading", clampf(float(_quality["cloud_shading"]), 0.0, 1.0))
		material.set_shader_parameter("daoc_cloud_silver_lining", clampf(float(_quality["cloud_silver_lining"]), 0.0, 2.0))

	# The shafts themselves are the sun's contribution to that medium. Zeroed when
	# there is no medium, so the value never lingers on a disabled preset.
	if sun != null:
		sun.light_volumetric_fog_energy = clampf(
			float(_quality["sun_rays_energy"]), 0.0, MAX_SUN_RAYS_ENERGY) if volumetric else 0.0


func _apply_sun_palette(sun: DirectionalLight3D) -> void:
	if not bool(_quality["sun_warm_palette_enabled"]):
		sun.light_color = Color.WHITE
		return
	var hour := fposmod(float(_last_state.get("time_hours", 12.0)), 24.0)
	# 0 au lever/coucher, 1 vers midi. La palette reste stable et ne prend
	# aucune decision de gameplay : elle ne fait que teinter le photon rendu.
	var daylight_arc := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var day_color: Color = _quality["sun_day_color"] as Color
	var low_color: Color = _quality["sun_low_color"] as Color
	var palette := low_color.lerp(day_color, pow(daylight_arc, 0.55))
	var strength := clampf(float(_quality["sun_warmth_strength"]), 0.0, 1.0)
	sun.light_color = Color.WHITE.lerp(palette, strength)


func _process(delta: float) -> void:
	if not _active_clouds_loaded or sky3d == null:
		return
	var step := maxf(delta, 0.0)
	_cloud_motion_seconds = fmod(_cloud_motion_seconds + step, 100000.0)
	var drift := bool(_quality["cloud_drift_enabled"])
	if drift:
		# Le vent tourne de +-14 degres sur une periode de ~9 minutes : assez
		# lent pour ne jamais se voir, assez pour que la nappe ne file pas en
		# ligne droite pendant une heure.
		var turn := sin(_cloud_motion_seconds * TAU / 540.0) * deg_to_rad(14.0)
		_cloud_motion_direction = Vector2(1.0, 0.35).normalized().rotated(turn)
	# DAT speeds are already UV rates after their documented x0.001 factor.
	# Advance them once with real elapsed seconds; do not attenuate them again
	# through Sky3D's slower cirrus movement.
	_cloud_motion_offset += _cloud_motion_direction * step
	var dome: Object = sky3d.get("sky") as Object
	var material := dome.get("sky_material") as ShaderMaterial if dome != null else null
	if material != null:
		material.set_shader_parameter("daoc_cloud_motion", _cloud_motion_offset)
		_apply_cloud_shape(material, clampf(float(_last_state.get("weather_influence", 0.0)), 0.0, 1.0))


## Hauteur et compacite des quatre couches : le jeu « clair » vers le jeu
## « orage » selon l'influence meteo, puis une derive lente et deterministe
## (trois sinus incommensurables) pour qu'un ciel clair passe d'un plafond
## haut et compact a un voile plus bas et plus diffus au fil des minutes.
func _apply_cloud_shape(material: ShaderMaterial, weather_influence: float) -> void:
	var altitude: Vector4 = (CLOUD_SHAPE_CLEAR["altitude"] as Vector4).lerp(
		CLOUD_SHAPE_STORM["altitude"] as Vector4, weather_influence)
	var softness: Vector4 = (CLOUD_SHAPE_CLEAR["softness"] as Vector4).lerp(
		CLOUD_SHAPE_STORM["softness"] as Vector4, weather_influence)
	var coverage := float(_last_state.get("cloud_coverage", 0.28))
	if bool(_quality["cloud_drift_enabled"]):
		var t := _cloud_motion_seconds
		var wave_a := sin(t * TAU / 251.0)
		var wave_b := sin(t * TAU / 173.0 + 1.3)
		var wave_c := sin(t * TAU / 397.0 + 2.9)
		# L'amplitude est plus grande par temps clair : un front d'orage a une
		# forme imposee, un ciel de beau temps a le droit de respirer.
		var room := lerpf(1.0, 0.35, weather_influence)
		altitude += Vector4(wave_a, wave_b, wave_c, wave_a * wave_b) * 0.12 * room
		softness += Vector4(wave_b, wave_c, wave_a, wave_c * wave_a) * 0.15 * room
		coverage += wave_c * 0.05 * room
	altitude = altitude.clamp(Vector4.ZERO, Vector4.ONE)
	softness = softness.clamp(Vector4.ZERO, Vector4.ONE)
	coverage = clampf(coverage, 0.0, 1.0)
	material.set_shader_parameter("daoc_cloud_altitude", altitude)
	material.set_shader_parameter("daoc_cloud_softness", softness)
	material.set_shader_parameter("daoc_cloud_coverage", coverage)
	_cloud_shape = {"altitude": altitude, "softness": softness, "coverage": coverage}


func set_horizon_fog_density_addition(value: float) -> void:
	_horizon_fog_density_addition = clampf(value, 0.0, 0.00001)
	if not _last_state.is_empty():
		apply_environment_state(_last_state)


func apply_environment_state(state: Dictionary) -> void:
	if sky3d == null:
		setup()
	_last_state = state.duplicate(true)
	var mode := str(state.get("sky_mode", "OUTDOOR_DYNAMIC"))
	var outside := mode != "NO_SKY"
	sky3d.set("sky3d_enabled", true)
	sky3d.set("sky_enabled", outside)
	sky3d.set("lights_enabled", outside)
	sky3d.set("clouds_enabled", outside)
	# Always keep the fragile screen-space fog backend disabled on Godot 4.6.
	sky3d.set("fog_enabled", false)
	sky3d.set("current_time", float(state.get("time_hours", 12.0)))
	sky3d.set("sun_energy", 1.15 * clampf(float(_quality["sun_energy_scale"]), 0.0, 3.0) * float(state.get("sun_multiplier", 1.0)))
	sky3d.set("moon_energy", 0.22 * float(state.get("ambient_multiplier", 1.0)))
	sky3d.set("ambient_energy", 0.60 * float(state.get("ambient_multiplier", 1.0)))
	var weather_influence := clampf(float(state.get("weather_influence", 0.0)), 0.0, 1.0)

	var dome: Object = sky3d.get("sky") as Object
	if dome != null:
		var zone_profile := state.get("zone_profile", {}) as Dictionary
		_active_cloud_source_root = str(zone_profile.get("sky_asset_root", "")).strip_edges().replace("\\", "/").trim_suffix("/")
		var realm_profile := _realm_cloud_profile(int(zone_profile.get("realm_id", 1)), _active_cloud_source_root)
		_active_cloud_realm_id = int(realm_profile["realm_id"])
		_active_cloud_realm_name = str(realm_profile["realm_name"])
		_active_cloud_layers.assign(realm_profile["layer_names"] as Array)
		_active_cloud_tiles = realm_profile["tiles"] as Vector4
		_active_cloud_speeds = realm_profile["speeds"] as Vector4
		_active_cloud_recipe_path = str(realm_profile.get("recipe_path", ""))
		_active_cloud_recipe_source = str(realm_profile.get("recipe_source", "FALLBACK"))
		_missing_cloud_paths.clear()
		var cloud_textures: Array[Texture2D] = []
		for layer_name in _active_cloud_layers:
			var texture := _load_external_png(_active_cloud_source_root, layer_name)
			if texture == null:
				_missing_cloud_paths.append(_active_cloud_source_root.path_join(layer_name))
			else:
				cloud_textures.append(texture)
		_active_clouds_loaded = cloud_textures.size() == 4
		# Each realm's four PNG layers are read directly from the configured DAoC
		# client. Nothing is copied into res:// and no DDS conversion occurs.
		dome.set("wind_speed", 1.0)
		var material := dome.get("sky_material") as ShaderMaterial
		if material != null:
			material.set_shader_parameter("daoc_legacy_clouds_enabled", outside and _active_clouds_loaded)
			if _active_clouds_loaded:
				material.set_shader_parameter("daoc_cloud_top_texture", cloud_textures[0])
				material.set_shader_parameter("daoc_cloud_bottom_texture", cloud_textures[1])
				material.set_shader_parameter("daoc_cloud_top_texture2", cloud_textures[2])
				material.set_shader_parameter("daoc_cloud_bottom_texture2", cloud_textures[3])
			material.set_shader_parameter("daoc_cloud_tiles", _active_cloud_tiles)
			material.set_shader_parameter("daoc_cloud_speeds", _active_cloud_speeds)
			material.set_shader_parameter("daoc_cloud_motion", _cloud_motion_offset)
			material.set_shader_parameter("daoc_cloud_storminess", weather_influence)
			material.set_shader_parameter("daoc_cloud_intensity", lerpf(1.02, 0.70, weather_influence))
			_apply_cloud_shape(material, weather_influence)
			_apply_celestial_bodies(material, outside, weather_influence)
		# `ecliptic_angle` du DAT : l'inclinaison de l'arc solaire de la zone,
		# notee « non appliquee » par P1-32 et consommee par les ombres depuis.
		_active_ecliptic_degrees = _recipe_float(_read_main_recipe(_active_cloud_recipe_path), "ecliptic_angle", 0.0)
		dome.set("fog_visible", false)

	var environment := sky3d.environment
	if environment == null:
		return
	if outside:
		environment.background_mode = Environment.BG_SKY
		var profile := state.get("zone_profile", {}) as Dictionary
		var zone_sky_colour := Color.from_string(str(profile.get("sky_color", "80d7ff")), Color8(128, 215, 255))
		environment.ambient_light_color = zone_sky_colour.lerp(Color.WHITE, 0.34)
		var hour := fposmod(float(state.get("time_hours", 12.0)), 24.0)
		# Broad 05:00-19:00 daylight curve: twilight stays readable, noon gets
		# the full value, and midnight is not mistaken for a cloudy afternoon.
		var daylight := clampf(sin((hour - 5.0) / 14.0 * PI), 0.0, 1.0)
		var time_ambient := lerpf(0.20, 0.72, pow(daylight, 0.65)) * clampf(float(_quality["ambient_energy_scale"]), 0.0, 2.0)
		var ambient_multiplier := float(state.get("ambient_multiplier", 1.0))
		if bool(_quality["ambient_from_sky_enabled"]):
			# Opt-in: the ground is lit by the sky that is actually on screen, so
			# dusk tints the whole world instead of only the dome.
			#
			# The double-darkening that forced AMBIENT_SOURCE_COLOR in P1-20K is
			# settled here rather than avoided: the rendered panorama ALREADY
			# carries the weather, so the explicit multiplier is applied only to
			# the fraction still coming from the zone colour. At contribution 1.0
			# the cloud cover is billed exactly once; at 0.0 the result is
			# identical to the branch below.
			var contribution := clampf(float(_quality["ambient_sky_contribution"]), 0.0, 1.0)
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			# Routed through Sky3D's own property, not the Environment field: its
			# night_ambient_boost tween owns ambient_light_sky_contribution and
			# would otherwise overwrite whatever is written here.
			sky3d.set("sky_contribution", contribution)
			environment.ambient_light_energy = time_ambient * lerpf(ambient_multiplier, 1.0, contribution)
		else:
			# The original cloud PNGs are deliberately dense. Sampling the rendered
			# sky as ground irradiance made those pixels darken every surface twice:
			# once through the sun/weather multiplier and again through the cloudy
			# panorama. Keep reflections on the real sky, but drive ground ambience
			# from the DAoC zone colour and the explicit weather multiplier.
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_energy = time_ambient * ambient_multiplier
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.fog_enabled = true
		var source_amount := int(profile.get("fog_amount", -1))
		var base_density := 0.0000008
		var weather_fog := clampf(float(state.get("weather_fog_factor", 0.0)), 0.0, 1.0)
		if source_amount >= 0:
			base_density = lerpf(0.00000035, 0.0000080, clampf(float(source_amount) / 255.0, 0.0, 1.0))
		environment.fog_density = base_density + _horizon_fog_density_addition + 0.0000100 * weather_fog
		environment.fog_light_color = Color.from_string(str(profile.get("fog_color", "b8c7d9")), Color(0.72, 0.78, 0.85))
		# Native fog sees the sky at infinite distance. Its default sky influence
		# (1.0) therefore hides the whole Sky3D shader even at tiny DAoC density.
		# Preserve the zone fog on distant terrain while letting clear weather
		# reveal the celestial cycle; an actual weather front closes it again.
		environment.fog_sky_affect = lerpf(0.08, 0.62, weather_fog)
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.015, 0.018, 0.025)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.08, 0.09, 0.12)
		environment.ambient_light_energy = 0.18
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		environment.fog_enabled = false
	_apply_quality_options(outside)


## Sun and moon as the original client draws them: five sprites from
## `zones/sky`, sized and tinted by the zone's own `sky_*.dat`. Nothing is
## copied into res:// and no DAT value is reinterpreted here beyond the
## documented distance/scale ratio.
func _apply_celestial_bodies(material: ShaderMaterial, outside: bool, weather_influence: float) -> void:
	var recipe := _read_main_recipe(_active_cloud_recipe_path)
	var sprites := {
		"daoc_sun_disk_texture": str(recipe.get("sun_texture", "sundisk.bmp")),
		"daoc_sun_flare_texture": str(recipe.get("sunflare_texture", "sunflare.bmp")),
		"daoc_sun_glow_texture": str(recipe.get("sunglow_texture", "sunglow.bmp")),
		"daoc_moon_disk_texture": str(recipe.get("moon_texture", "moon.tga")),
		"daoc_moon_back_texture": str(recipe.get("moonback_texture", "moonback.tga")),
	}
	_missing_celestial_paths.clear()
	var loaded := {}
	for uniform_name in sprites.keys():
		var file_name := str(sprites[uniform_name]).strip_edges()
		var texture := _load_celestial_texture(_active_cloud_source_root, file_name)
		if texture == null:
			_missing_celestial_paths.append(_active_cloud_source_root.path_join(file_name))
		else:
			loaded[uniform_name] = texture
	_celestial_loaded = loaded.size() == sprites.size()
	var enabled := outside and _celestial_loaded
	material.set_shader_parameter("daoc_celestial_enabled", enabled)
	if not enabled:
		_active_celestial = {"enabled": false, "sprites": sprites}
		return
	for uniform_name in loaded.keys():
		material.set_shader_parameter(uniform_name, loaded[uniform_name])

	# A sprite of `scale` units placed at `distance` units covers scale/distance
	# radians of half-angle. That ratio is the only geometric conversion here.
	var sun_distance := _recipe_float(recipe, "sun_distance", CELESTIAL_FALLBACK["sun_distance"])
	var moon_distance := _recipe_float(recipe, "moon_distance", CELESTIAL_FALLBACK["moon_distance"])
	var sun_radii := Vector3(
		_angular_radius(_recipe_float(recipe, "sun_scale", CELESTIAL_FALLBACK["sun_scale"]), sun_distance),
		_angular_radius(_recipe_float(recipe, "sunflare_scale", CELESTIAL_FALLBACK["sunflare_scale"]), sun_distance),
		_angular_radius(_recipe_float(recipe, "sunglow_scale", CELESTIAL_FALLBACK["sunglow_scale"]), sun_distance))
	var moon_radius := _angular_radius(
		_recipe_float(recipe, "moon_scale", CELESTIAL_FALLBACK["moon_scale"]), moon_distance)
	material.set_shader_parameter("daoc_sun_radii", sun_radii)
	material.set_shader_parameter("daoc_moon_radius", moon_radius)

	# The DAT carries four colours per sun layer: horizon and noon, clear and
	# stormy. Sky3D already knows where the sun is, so the noon blend is read
	# from the live sun direction rather than recomputed from the hour.
	var sun := sun_light()
	var noon_mix := clampf(sun.transform.origin.y * 2.0, 0.0, 1.0) if sun != null else 0.0
	var storm := clampf(weather_influence, 0.0, 1.0)
	var disk_tint := _celestial_tint(recipe, "sundisk", Color8(255, 255, 255, 255), noon_mix, storm)
	var flare_tint := _celestial_tint(recipe, "sunflare", Color8(255, 160, 30, 128), noon_mix, storm)
	var glow_tint := _celestial_tint(recipe, "sunglow", Color8(255, 160, 30, 255), noon_mix, storm)
	# The moon has a single colour in every DAT: no noon variant, no storm
	# variant. It is NOT blended here, because the source does not blend it.
	var moon_tint := _parse_dat_color(str(recipe.get("moon_color", "")), Color8(255, 245, 217, 255))
	var moon_back_tint := _parse_dat_color(str(recipe.get("moonback_color", "")), Color8(16, 51, 89, 255))
	material.set_shader_parameter("daoc_sun_disk_tint", disk_tint)
	material.set_shader_parameter("daoc_sun_flare_tint", flare_tint)
	material.set_shader_parameter("daoc_sun_glow_tint", glow_tint)
	material.set_shader_parameter("daoc_moon_tint", moon_tint)
	material.set_shader_parameter("daoc_moon_back_tint", moon_back_tint)
	material.set_shader_parameter("daoc_sun_sprites_visible", true)
	material.set_shader_parameter("daoc_moon_sprites_visible", true)

	_active_celestial = {
		"enabled": true,
		"sprites": sprites,
		"sun_distance": sun_distance,
		"moon_distance": moon_distance,
		"sun_radii": sun_radii,
		"moon_radius": moon_radius,
		"noon_mix": noon_mix,
		"storm_mix": storm,
		"sun_disk_tint": disk_tint,
		"sun_flare_tint": flare_tint,
		"sun_glow_tint": glow_tint,
		"moon_tint": moon_tint,
		"moon_back_tint": moon_back_tint,
	}


func _angular_radius(scale: float, distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	return clampf(scale / distance, 0.0, 1.0)


func _recipe_float(recipe: Dictionary, key: String, fallback: float) -> float:
	if not recipe.has(key):
		return fallback
	var raw := str(recipe[key]).strip_edges()
	return float(raw) if raw.is_valid_float() else fallback


## Picks one sun layer's colour out of its four DAT variants. Missing variants
## fall back to the plain one rather than to an invented value.
func _celestial_tint(recipe: Dictionary, prefix: String, fallback: Color, noon_mix: float, storm: float) -> Color:
	var horizon_clear := _parse_dat_color(str(recipe.get("%s_color" % prefix, "")), fallback)
	var horizon_storm := _parse_dat_color(str(recipe.get("%s_color_storm" % prefix, "")), horizon_clear)
	var noon_clear := _parse_dat_color(str(recipe.get("%s_color_noon" % prefix, "")), horizon_clear)
	var noon_storm := _parse_dat_color(str(recipe.get("%s_color_noon_storm" % prefix, "")), noon_clear)
	return horizon_clear.lerp(horizon_storm, storm).lerp(noon_clear.lerp(noon_storm, storm), noon_mix)


## `r,g,b,a` in the 0-255 range, the only colour notation used by sky_*.dat.
func _parse_dat_color(raw: String, fallback: Color) -> Color:
	var parts := raw.strip_edges().split(",", false)
	if parts.size() < 3:
		return fallback
	var channels: Array[int] = []
	for index in range(4):
		if index >= parts.size():
			channels.append(255)
			continue
		var value := str(parts[index]).strip_edges()
		if not value.is_valid_int():
			return fallback
		channels.append(clampi(int(value), 0, 255))
	return Color8(channels[0], channels[1], channels[2], channels[3])


## The sun sprites are BMP and the moon sprites TGA in the shipped client; both
## decode natively in Godot 4.6, so nothing is converted or copied here. The
## `.png` sibling is accepted as well because the remaster pipeline writes one.
func _load_celestial_texture(sky_root: String, file_name: String) -> Texture2D:
	if sky_root.is_empty() or file_name.is_empty():
		return null
	var candidates: Array[String] = [file_name]
	for extension in [".png", ".tga", ".bmp", ".dds"]:
		var sibling: String = file_name.get_basename() + str(extension)
		if not candidates.has(sibling):
			candidates.append(sibling)
	for candidate in candidates:
		var path := sky_root.path_join(candidate)
		var cache_key := path.to_lower()
		if _celestial_texture_cache.has(cache_key):
			return _celestial_texture_cache[cache_key] as Texture2D
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			continue
		var texture := ImageTexture.create_from_image(image)
		_celestial_texture_cache[cache_key] = texture
		return texture
	return null


func sun_light() -> DirectionalLight3D:
	return sky3d.get("sun") as DirectionalLight3D if sky3d != null else null


func environment_resource() -> Environment:
	return sky3d.environment if sky3d != null else null


## Eclaircissement temporaire du monde (torche du joueur, P1-111) : +10 % =
## adjustment_brightness 1.10. Il survit a chaque passe de qualite, qui le
## reposait a 1.0, et l ajustement n est arme que s il change quelque chose.
func set_brightness_boost(value: float) -> void:
	_brightness_boost = clampf(value, 0.0, 1.0)
	var environment := environment_resource()
	if environment == null:
		return
	_apply_brightness_boost(environment,
		clampf(float(_quality["color_saturation"]), 0.0, 3.0),
		clampf(float(_quality["color_contrast"]), 0.1, 3.0))


func brightness_boost() -> float:
	return _brightness_boost


func _apply_brightness_boost(environment: Environment, saturation: float, contrast: float) -> void:
	var brightness := 1.0 + _brightness_boost
	environment.adjustment_brightness = brightness
	environment.adjustment_enabled = not (is_equal_approx(saturation, 1.0)
		and is_equal_approx(contrast, 1.0) and is_equal_approx(brightness, 1.0))


func debug_snapshot() -> Dictionary:
	return {
		"backend": "Sky3D",
		"backend_version": str(sky3d.get("version")) if sky3d != null else "2.1",
		"present": sky3d != null,
		"screen_space_fog_enabled": bool(sky3d.get("fog_enabled")) if sky3d != null else false,
		"volumetric_fog_enabled": bool(sky3d.environment.volumetric_fog_enabled) if sky3d != null and sky3d.environment != null else false,
		"godot_46_fog_mitigation": _screen_space_fog_disabled_for_godot_46,
		"quality": _quality.duplicate(true),
		"glow_enabled": bool(sky3d.environment.glow_enabled) if sky3d != null and sky3d.environment != null else false,
		"aerial_perspective": float(sky3d.environment.fog_aerial_perspective) if sky3d != null and sky3d.environment != null else 0.0,
		"ambient_light_source": int(sky3d.environment.ambient_light_source) if sky3d != null and sky3d.environment != null else -1,
		"sun_rays_energy_applied": float(sun_light().light_volumetric_fog_energy) if sun_light() != null else 0.0,
		"cloud_profile": CLOUD_PROFILE,
		"cloud_texture_resolution": 512,
		"cloud_realm_id": _active_cloud_realm_id,
		"cloud_realm_name": _active_cloud_realm_name,
		"cloud_layers": _active_cloud_layers.duplicate(),
		"cloud_tiles": _active_cloud_tiles,
		"cloud_speeds": _active_cloud_speeds,
		"cloud_source": "EXTERNAL_DAOC_CLIENT_PNG" if _active_clouds_loaded else "SKY3D_FALLBACK",
		"cloud_source_root": _active_cloud_source_root,
		"cloud_recipe_path": _active_cloud_recipe_path,
		"cloud_recipe_source": _active_cloud_recipe_source,
		"clouds_loaded": _active_clouds_loaded,
		"missing_cloud_paths": _missing_cloud_paths.duplicate(),
		"external_texture_cache_size": _external_texture_cache.size(),
		"cloud_motion_seconds": _cloud_motion_seconds,
		"cloud_motion_direction": _cloud_motion_direction,
		"cloud_motion_offset": _cloud_motion_offset,
		"cloud_shape": _cloud_shape.duplicate(true),
		"ecliptic_angle_degrees": _active_ecliptic_degrees,
		"sun_arc_tilt_degrees_applied": rad_to_deg(float(sky3d.get("tod").get("simple_arc_tilt"))) if sky3d != null and sky3d.get("tod") != null else 0.0,
		"horizon_fog_density_addition": _horizon_fog_density_addition,
		"celestial_profile": CELESTIAL_PROFILE,
		"celestial_mode": int(sky3d.get("tod").get("celestials_calculations")) if sky3d != null and sky3d.get("tod") != null else -1,
		"opposite_moon_enabled": bool(_quality["opposite_moon_enabled"]),
		"celestial_source": "EXTERNAL_DAOC_CLIENT_SPRITE" if _celestial_loaded else "SKY3D_FALLBACK",
		"celestial_loaded": _celestial_loaded,
		"celestial": _active_celestial.duplicate(true),
		"celestial_texture_cache_size": _celestial_texture_cache.size(),
		"missing_celestial_paths": _missing_celestial_paths.duplicate(),
		# NO PHASE CYCLE. `moon.tga` already carries ONE baked phase - its lit
		# area is off-centre, measured bbox x 18..61 against moonback's 2..61 -
		# and `phases.tga` (24 cells) is in the client but is NOT read. The moon
		# therefore keeps that single phase forever. Not "always full".
		"moon_phases_implemented": false,
		"moon_phase_source": "BAKED_IN_MOON_TGA",
		"last_state": _last_state.duplicate(true),
	}


func _realm_cloud_profile(realm_id: int, sky_root: String) -> Dictionary:
	var fallback: Dictionary
	match realm_id:
		2:
			fallback = {
				"realm_id": 2, "realm_name": "Midgard",
				"recipe_file": "sky_midgard.dat",
				"layer_names": ["cloudsA.png", "cloudsD.png", "cloudsE.png", "cloudsF.png"],
				"tiles": Vector4(4.0, 3.0, 5.0, 4.0),
				"speeds": Vector4(6.0, 12.0, 6.0, 12.0) * 0.001,
			}
		3:
			fallback = {
				"realm_id": 3, "realm_name": "Hibernia",
				"recipe_file": "sky_hibernia.dat",
				"layer_names": ["cloudsB.png", "cloudsC.png", "cloudsF.png", "cloudsG.png"],
				"tiles": Vector4(4.0, 5.0, 4.0, 3.0),
				"speeds": Vector4(4.0, 6.0, 5.0, 9.0) * 0.001,
			}
		_:
			fallback = {
				"realm_id": 1, "realm_name": "Albion",
				"recipe_file": "sky_albion.dat",
				"layer_names": ["cloudsB.png", "cloudsE.png", "cloudsF.png", "cloudsG.png"],
				"tiles": Vector4(5.0, 4.0, 4.0, 3.0),
				"speeds": Vector4(3.0, 5.0, 5.0, 9.0) * 0.001,
			}
	var recipe_path := sky_root.path_join("sky").path_join(str(fallback["recipe_file"]))
	fallback["recipe_path"] = recipe_path
	fallback["recipe_source"] = "BUILTIN_FAILSAFE"
	var source_values := _read_main_recipe(recipe_path)
	if source_values.is_empty():
		return fallback
	var texture_keys := ["cloud_top_texture", "cloud_bot_texture", "cloud_top_texture2", "cloud_bot_texture2"]
	var tile_keys := ["cloud_top_tile", "cloud_bot_tile", "cloud_top_tile2", "cloud_bot_tile2"]
	var speed_keys := ["cloud_top_speed", "cloud_bot_speed", "cloud_top_speed2", "cloud_bot_speed2"]
	var layer_names: Array[String] = []
	var tiles := Vector4.ZERO
	var speeds := Vector4.ZERO
	for index in range(4):
		if not source_values.has(texture_keys[index]) or not source_values.has(tile_keys[index]) or not source_values.has(speed_keys[index]):
			return fallback
		var source_texture := str(source_values[texture_keys[index]]).strip_edges()
		layer_names.append(source_texture.get_basename().get_file() + ".png")
		tiles[index] = float(source_values[tile_keys[index]])
		speeds[index] = float(source_values[speed_keys[index]]) * 0.001
	fallback["layer_names"] = layer_names
	fallback["tiles"] = tiles
	fallback["speeds"] = speeds
	fallback["recipe_source"] = "EXTERNAL_DAOC_SKY_DAT"
	return fallback


func _read_main_recipe(path: String) -> Dictionary:
	var cache_key := path.to_lower()
	if _realm_recipe_cache.has(cache_key):
		return (_realm_recipe_cache[cache_key] as Dictionary).duplicate()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var values := {}
	var in_main := false
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := str(raw_line).strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.contains("]"):
			if in_main:
				break
			in_main = line.substr(1, line.find("]") - 1).strip_edges().to_lower() == "main"
			continue
		if not in_main or not line.contains("="):
			continue
		var separator := line.find("=")
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		var comment := value.find(";")
		if comment >= 0:
			value = value.substr(0, comment).strip_edges()
		values[key] = value
	_realm_recipe_cache[cache_key] = values.duplicate()
	return values


func _load_external_png(sky_root: String, file_name: String) -> Texture2D:
	if sky_root.is_empty() or file_name.is_empty():
		return null
	var path := sky_root.path_join(file_name)
	var cache_key := path.to_lower()
	if _external_texture_cache.has(cache_key):
		return _external_texture_cache[cache_key] as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_external_texture_cache[cache_key] = texture
	return texture
