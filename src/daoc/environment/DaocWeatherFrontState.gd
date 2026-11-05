extends RefCounted
class_name DaocWeatherFrontState

## Lossless representation of the five raw DOL SendWeather parameters.
## The precipitation hint is deliberately separate: no temperature threshold
## is invented while the original client handler remains unconfirmed.

enum PrecipitationHint {
	UNKNOWN,
	RAIN,
	SNOW,
}

var x: float = 0.0
var width: float = 0.0
var speed: float = 0.0
var fog_diffusion: float = 0.0
var intensity: float = 0.0
var precipitation_hint: int = PrecipitationHint.UNKNOWN


func configure(raw: Dictionary, hint: int = PrecipitationHint.UNKNOWN) -> RefCounted:
	x = float(raw.get("x", 0.0))
	width = maxf(0.0, float(raw.get("width", 0.0)))
	speed = float(raw.get("speed", 0.0))
	fog_diffusion = float(raw.get("fogdiffusion", raw.get("fog_diffusion", 0.0)))
	intensity = float(raw.get("intensity", 0.0))
	precipitation_hint = hint
	return self


func advance_offline(delta: float) -> void:
	x += speed * delta


func normalized_intensity() -> float:
	# DOL captures commonly expose integer-like intensities. Values already in
	# [0,1] remain normalized; larger raw values are treated as percentages only
	# for the modern renderer, while the exact raw value remains available.
	return clampf(intensity if intensity <= 1.0 else intensity / 100.0, 0.0, 1.0)


func normalized_fog_diffusion() -> float:
	return clampf(fog_diffusion if fog_diffusion <= 1.0 else fog_diffusion / 255.0, 0.0, 1.0)


func local_influence(world_x: float) -> float:
	if width <= 0.0 or intensity <= 0.0:
		return 0.0
	# Modern visual interpretation: x is the front centre, width its complete
	# span, with a soft 15% edge. This preserves spatial progression without
	# claiming the precise proprietary client falloff has been recovered.
	var half_width := width * 0.5
	var distance := absf(world_x - x)
	if distance >= half_width:
		return 0.0
	var edge := maxf(width * 0.15, 1.0)
	var spatial := 1.0 - smoothstep(maxf(0.0, half_width - edge), half_width, distance)
	return spatial * normalized_intensity()


func precipitation_name() -> String:
	match precipitation_hint:
		PrecipitationHint.RAIN:
			return "RAIN"
		PrecipitationHint.SNOW:
			return "SNOW"
	return "UNKNOWN"


func to_dict() -> Dictionary:
	return {
		"x": x,
		"width": width,
		"speed": speed,
		"fog_diffusion": fog_diffusion,
		"intensity": intensity,
		"normalized_intensity": normalized_intensity(),
		"precipitation_hint": precipitation_name(),
	}
