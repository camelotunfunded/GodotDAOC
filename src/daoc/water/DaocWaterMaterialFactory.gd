extends RefCounted
class_name DaocWaterMaterialFactory

const WATER_SHADER = preload("res://src/daoc/water/DaocWaterSurface.gdshader")
const MODERN_WATER_TEXTURE = preload("res://assets/placeholders/water_ripples.svg")
const DEFAULT_TEXTURE_NAME := "watery.png"

static var _external_png_cache: Dictionary = {}


static func make_material(body: Dictionary, settings: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var water_type := str(body.get("type", "OCEAN")).to_upper()
	var colours := _colours_for_type(water_type)
	material.set_shader_parameter("shallow_colour", colours[0])
	material.set_shader_parameter("deep_colour", colours[1])
	material.set_shader_parameter("foam_colour", colours[2])
	material.set_shader_parameter("water_opacity", clampf(float(settings.get("water_alpha", 0.62)), 0.05, 1.0))
	material.set_shader_parameter("world_uv_scale", float(settings.get("water_uv_world_scale", 0.00055)))
	material.set_shader_parameter("wave_strength", _wave_strength_for_type(water_type)
		* clampf(float(settings.get("water_wave_strength_scale", 1.0)), 0.0, 4.0))
	material.set_shader_parameter("refraction_strength", (0.007 if water_type == "SWAMP" else 0.012)
		* clampf(float(settings.get("water_refraction_scale", 1.0)), 0.0, 3.0))
	material.set_shader_parameter("depth_distance", (520.0 if water_type == "SWAMP" else 900.0)
		* clampf(float(settings.get("water_depth_colour_scale", 1.0)), 0.05, 2.0))
	material.set_shader_parameter("shore_distance", 75.0 if water_type == "RIVER" else 105.0)
	material.set_shader_parameter("flow_direction", _flow_direction(body))
	material.set_shader_parameter("flow_speed", clampf(float(str(body.get("flow", "0"))) * 0.00045, -0.20, 0.20))
	material.set_shader_parameter("ambient_drift", 0.006 if water_type == "SWAMP" else 0.012)
	_apply_shore_parameters(material, water_type, body, settings)

	var texture_info := resolve_texture(body, settings)
	material.set_meta("daoc_water_shader", true)
	material.set_meta("daoc_water_texture_source", str(texture_info.get("path", "")))
	material.set_meta("daoc_water_texture_loaded", false)
	material.set_meta("daoc_water_texture_recipe", str(texture_info.get("recipe", "")))
	material.set_meta("daoc_water_multitexture_recipe", str(body.get("multitexture", "")))
	material.set_meta("daoc_water_png_only", true)
	# Repli API historique : un appelant qui ne connait pas encore l'option lit
	# toujours watery.png. Les scenes modernes la passent explicitement a true.
	var use_modern_texture := bool(settings.get("water_modern_texture_enabled", false))
	material.set_meta("daoc_water_use_project_texture", use_modern_texture)
	if use_modern_texture:
		material.set_shader_parameter("daoc_water_texture", MODERN_WATER_TEXTURE)
		material.set_meta("daoc_water_texture_source", "res://assets/daoc/water/water_ripples_tile.png")
		material.set_meta("daoc_water_texture_loaded", true)
	if bool(settings.get("bind_external_texture_immediately", true)):
		bind_external_texture(material, str(settings.get("client_root", "")))
	return material


static func resolve_texture(body: Dictionary, settings: Dictionary) -> Dictionary:
	var client_root := str(settings.get("client_root", "")).strip_edges().replace("\\", "/").trim_suffix("/")
	var recipe := str(body.get("texture", "")).strip_edges()
	var file_name := _png_name(recipe)
	if file_name.is_empty():
		file_name = DEFAULT_TEXTURE_NAME
	if client_root.is_empty():
		return {"path": "", "recipe": recipe, "fallback": recipe.is_empty()}

	# These are existing client folders only. DDS/TGA files are never opened and
	# the resolved PNG remains outside res://.
	var candidates: Array[String] = [
		client_root.path_join("zones/textures").path_join(file_name),
		client_root.path_join("zones/Nifs").path_join(file_name),
		client_root.path_join("zones/Dnifs").path_join(file_name),
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			return {"path": path, "recipe": recipe, "fallback": recipe.is_empty()}
	return {"path": candidates[0], "recipe": recipe, "fallback": recipe.is_empty()}


static func bind_external_texture(material: ShaderMaterial, client_root: String = "") -> bool:
	if material == null:
		return false
	if bool(material.get_meta("daoc_water_use_project_texture", false)):
		return true
	var path := str(material.get_meta("daoc_water_texture_source", ""))
	if path.is_empty() and not client_root.is_empty():
		path = client_root.replace("\\", "/").trim_suffix("/").path_join("zones/textures").path_join(DEFAULT_TEXTURE_NAME)
	var texture := _load_external_png(path)
	if texture == null:
		material.set_meta("daoc_water_texture_loaded", false)
		return false
	material.set_shader_parameter("daoc_water_texture", texture)
	material.set_meta("daoc_water_texture_source", path)
	material.set_meta("daoc_water_texture_loaded", true)
	return true


static func cache_size() -> int:
	return _external_png_cache.size()


static func clear_runtime_cache() -> void:
	_external_png_cache.clear()


static func _load_external_png(path: String) -> Texture2D:
	if not path.to_lower().ends_with(".png"):
		return null
	var key := path.to_lower()
	if _external_png_cache.has(key):
		return _external_png_cache[key] as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_external_png_cache[key] = texture
	return texture


static func _png_name(recipe: String) -> String:
	if recipe.is_empty():
		return ""
	return recipe.get_file().get_basename() + ".png"


static func _flow_direction(body: Dictionary) -> Vector2:
	var bankpoints := int(str(body.get("bankpoints", "0")))
	if bankpoints < 2:
		return Vector2.RIGHT
	var start := (_sector_point(body, "left00") + _sector_point(body, "right00")) * 0.5
	var end_index := bankpoints - 1
	var finish := (_sector_point(body, "left%02d" % end_index) + _sector_point(body, "right%02d" % end_index)) * 0.5
	var direction := finish - start
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT


static func _sector_point(body: Dictionary, key: String) -> Vector2:
	var parts := str(body.get(key, "0,0,0")).split(",", false)
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))


## 2026-09-19 — Berges. L'ocean recoit l'ECUME de plage ; lac, riviere et
## marais recoivent la MOUSSE, la surface se fondant dans le sol des bas-fonds.
## Les bandes de SECTOR.DAT (bankpoints >= 2) fondent aussi leurs bords ouverts
## par UV2 ; la mer lointaine n'a pas d'UV2 et garde un bord net (edge_fade 0).
## `water_shore_enabled = false` dans les reglages rend la surface d'avant.
static func _apply_shore_parameters(material: ShaderMaterial, water_type: String,
		body: Dictionary, settings: Dictionary) -> void:
	var enabled := bool(settings.get("water_shore_enabled", true))
	var strength := clampf(float(settings.get("water_shore_strength", 0.85)), 0.0, 1.0) if enabled else 0.0
	var is_ocean := water_type != "SWAMP" and water_type != "RIVER" and water_type != "LAKE"
	material.set_shader_parameter("shore_mode", 0 if is_ocean else 1)
	material.set_shader_parameter("shore_strength", strength)
	match water_type:
		"SWAMP":
			material.set_shader_parameter("shore_band_distance", 420.0)
			material.set_shader_parameter("shore_wave_speed", 0.35)
			material.set_shader_parameter("moss_colour", Color(0.24, 0.36, 0.14))
		"RIVER":
			material.set_shader_parameter("shore_band_distance", 220.0)
			material.set_shader_parameter("shore_wave_speed", 0.8)
			material.set_shader_parameter("moss_colour", Color(0.27, 0.42, 0.20))
		"LAKE":
			material.set_shader_parameter("shore_band_distance", 300.0)
			material.set_shader_parameter("shore_wave_speed", 0.5)
			material.set_shader_parameter("moss_colour", Color(0.26, 0.40, 0.18))
		_:
			material.set_shader_parameter("shore_band_distance", float(settings.get("water_beach_foam_distance", 140.0)))
			material.set_shader_parameter("shore_wave_speed", 0.9)
	var has_band_uv2 := int(str(body.get("bankpoints", "0"))) >= 2
	# Ocean : fondu court, les bandes voisines se recouvrent sur la mer lointaine.
	material.set_shader_parameter("edge_fade", (0.05 if is_ocean else 0.08) if (enabled and has_band_uv2) else 0.0)
	material.set_meta("daoc_water_shore_mode", "foam" if is_ocean else "moss")


static func _colours_for_type(water_type: String) -> Array[Color]:
	match water_type:
		"SWAMP":
			return [Color(0.20, 0.31, 0.20), Color(0.055, 0.12, 0.075), Color(0.60, 0.68, 0.49)]
		"RIVER":
			return [Color(0.14, 0.39, 0.43), Color(0.025, 0.12, 0.17), Color(0.74, 0.86, 0.82)]
		"LAKE":
			return [Color(0.14, 0.36, 0.40), Color(0.025, 0.105, 0.16), Color(0.70, 0.82, 0.78)]
		_:
			return [Color(0.13, 0.36, 0.43), Color(0.018, 0.075, 0.15), Color(0.72, 0.84, 0.82)]


static func _wave_strength_for_type(water_type: String) -> float:
	match water_type:
		"SWAMP": return 0.42
		"RIVER": return 0.92
		"LAKE": return 0.68
		_: return 1.22
