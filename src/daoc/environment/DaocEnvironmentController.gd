extends Node
class_name DaocEnvironmentController

const ZoneProfileScript = preload("res://src/daoc/environment/DaocZoneEnvironmentProfile.gd")
const WeatherFrontScript = preload("res://src/daoc/environment/DaocWeatherFrontState.gd")

## DAoC authority layer. It owns server time, exact zone fields, and the raw
## weather front. Rendering backends only consume the calculated visual state.

signal environment_state_changed(state: Dictionary)
signal zone_profile_changed(profile)
signal weather_front_changed(front)

var server_time_seconds: int = 12 * 60 * 60
var offline_test_mode: bool = true
var offline_cycle_enabled: bool = false
var offline_minutes_per_day: float = 12.0
var offline_advance_weather_front: bool = false
var transition_seconds: float = 8.0
## P1-94 : en autorite SERVEUR, combien de ms de jeu passent par ms reelle
## (0x7E Time, 24 par defaut dans DOL). 0 = horloge figee entre deux 0x7E.
var server_day_increment: int = 0
var _server_time_fraction: float = 0.0

var zone_profile = ZoneProfileScript.new()
var weather_front = WeatherFrontScript.new()
var local_weather_x: float = 0.0

var _smoothed_influence: float = 0.0
var _last_emitted_state: Dictionary = {}


func _ready() -> void:
	set_process(true)
	emit_current_state(true)


func configure(profile: RefCounted, options: Dictionary = {}) -> void:
	zone_profile = profile if profile != null else ZoneProfileScript.new()
	server_time_seconds = posmod(int(options.get("server_time_seconds", server_time_seconds)), 86400)
	offline_test_mode = bool(options.get("offline_test_mode", offline_test_mode))
	offline_cycle_enabled = bool(options.get("offline_cycle_enabled", offline_cycle_enabled))
	offline_minutes_per_day = maxf(0.0, float(options.get("offline_minutes_per_day", offline_minutes_per_day)))
	offline_advance_weather_front = bool(options.get("offline_advance_weather_front", offline_advance_weather_front))
	transition_seconds = maxf(0.0, float(options.get("transition_seconds", transition_seconds)))
	zone_profile_changed.emit(zone_profile)
	emit_current_state(true)


func set_server_time_seconds(value: int) -> void:
	server_time_seconds = posmod(value, 86400)
	emit_current_state(true)


func set_server_time_hours(value: float) -> void:
	set_server_time_seconds(roundi(fposmod(value, 24.0) * 3600.0))


## P1-94 : le SERVEUR prend l autorite sur l heure. Coupe le cycle hors ligne
## et fait tourner l horloge a l increment du 0x7E entre deux paquets.
func set_server_time_authority(seconds: int, day_increment: int) -> void:
	offline_test_mode = false
	offline_cycle_enabled = false
	server_day_increment = maxi(0, day_increment)
	_server_time_fraction = 0.0
	set_server_time_seconds(seconds)


func set_zone_profile(profile: RefCounted) -> void:
	zone_profile = profile if profile != null else ZoneProfileScript.new()
	zone_profile_changed.emit(zone_profile)
	emit_current_state(true)


func set_weather_front_raw(raw: Dictionary, hint: int = WeatherFrontScript.PrecipitationHint.UNKNOWN) -> void:
	weather_front = WeatherFrontScript.new().configure(raw, hint)
	weather_front_changed.emit(weather_front)
	emit_current_state(true)


func set_offline_weather(hint: int, normalized_intensity: float, fog_diffusion: float = 0.0) -> void:
	set_weather_front_raw({
		"x": local_weather_x,
		"width": 1000000000.0,
		"speed": 0.0,
		"fogdiffusion": fog_diffusion,
		"intensity": clampf(normalized_intensity, 0.0, 1.0),
	}, hint)


func set_local_weather_sample_x(value: float) -> void:
	local_weather_x = value


func effective_time_seconds() -> int:
	return zone_profile.effective_time_seconds(server_time_seconds)


func current_state() -> Dictionary:
	var effective_seconds := effective_time_seconds()
	var precipitation: String = weather_front.precipitation_name()
	var influence := _smoothed_influence
	var zone: Dictionary = zone_profile.to_dict()
	return {
		"authority": "OFFLINE_TEST" if offline_test_mode else "SERVER",
		"server_time_seconds": server_time_seconds,
		"server_day_increment": server_day_increment,
		"effective_time_seconds": effective_seconds,
		"time_hours": float(effective_seconds) / 3600.0,
		"time_overridden_by_zone": zone_profile.has_override_time,
		"sky_mode": zone_profile.sky_mode_name(),
		"sky_override_pending": zone_profile.sky_mode() == ZoneProfileScript.SkyMode.SKY_OVERRIDE,
		"zone_profile": zone,
		"weather_front": weather_front.to_dict(),
		"weather_influence": influence,
		"precipitation": precipitation,
		"rain_intensity": influence if precipitation == "RAIN" else 0.0,
		"snow_intensity": influence if precipitation == "SNOW" else 0.0,
		"cloud_coverage": lerpf(0.28, 0.94, influence),
		"sun_multiplier": lerpf(1.0, 0.30, influence),
		"ambient_multiplier": lerpf(1.0, 0.66, influence),
		"weather_fog_factor": influence * weather_front.normalized_fog_diffusion(),
		# The source temperature is preserved above but intentionally does not
		# classify rain versus snow until the client handler is confirmed.
		"temperature_classification_used": false,
	}


func emit_current_state(force: bool = false) -> Dictionary:
	var state := current_state()
	if force or state != _last_emitted_state:
		_last_emitted_state = state.duplicate(true)
		environment_state_changed.emit(state)
	return state


func _process(delta: float) -> void:
	if not offline_test_mode and server_day_increment > 0:
		_server_time_fraction += delta * float(server_day_increment)
		var whole := int(_server_time_fraction)
		if whole > 0:
			_server_time_fraction -= float(whole)
			server_time_seconds = posmod(server_time_seconds + whole, 86400)
			emit_current_state()
	if offline_test_mode and offline_cycle_enabled and offline_minutes_per_day > 0.0:
		var seconds_per_real_second := 86400.0 / (offline_minutes_per_day * 60.0)
		server_time_seconds = posmod(server_time_seconds + roundi(delta * seconds_per_real_second), 86400)
	if offline_test_mode and offline_advance_weather_front:
		weather_front.advance_offline(delta)
	var target: float = weather_front.local_influence(local_weather_x)
	var previous := _smoothed_influence
	if transition_seconds <= 0.0:
		_smoothed_influence = target
	else:
		_smoothed_influence = lerpf(_smoothed_influence, target, 1.0 - exp(-delta / transition_seconds))
	if offline_cycle_enabled or absf(previous - _smoothed_influence) > 0.0005:
		emit_current_state()
