extends RefCounted
class_name DaocThatchMaterial

## P1-118 — le chaume des toits reçoit son propre matériau.
##
## Le compte rendu du 2026-09-23 : « toits de chaume : shader absent ou
## imperceptible ». Mesuré : le seul « shader de toit » était la respiration au
## vent de DaocVegetatedRoofWind, posée sur les franges alpha, qui PERDAIT la
## normale et l'AO du PBR ; les pans opaques (THATCH1 128 px, A_thatchroof)
## restaient un aplat. `DaocThatch.gdshader` leur donne un relief tiré de la
## couleur d'origine et une couche de détail — la normale et le grain de
## `a_thatch_dark` (Poly Haven thatch_roof_angled, CC0, déjà sur le disque).
##
## Uniquement visuel : aucune collision, aucune donnée de zone, rien du serveur.

const ThatchShader = preload("res://src/daoc/world/DaocThatch.gdshader")

## Radicaux de texture reconnus comme chaume. `hay` couvre avhay01/02 (Avalon).
const TOKENS := ["thatch", "hay"]
## La source de détail : couleur et normale photo déjà convertie par le remaster.
const DETAIL_STEM := "a_thatch_dark"


static func is_thatch_texture(stem: String) -> bool:
	var low := stem.to_lower()
	if low == DETAIL_STEM:
		return true
	for token in TOKENS:
		if low.contains(token):
			return true
	return false


## `detail_albedo` / `detail_normal` peuvent être nuls : le relief de la
## couleur d'origine reste alors seul.
static func build(source: BaseMaterial3D, detail_albedo: Texture2D, detail_normal: Texture2D,
		settings: Dictionary = {}) -> ShaderMaterial:
	if source == null or source.albedo_texture == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = ThatchShader
	material.resource_name = source.resource_name
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	var use_alpha := source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	material.set_shader_parameter("use_alpha", use_alpha)
	material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold)
	var has_detail := detail_albedo != null and detail_normal != null
	material.set_shader_parameter("has_detail", has_detail)
	if has_detail:
		material.set_shader_parameter("detail_albedo", detail_albedo)
		material.set_shader_parameter("detail_normal", detail_normal)
	material.set_shader_parameter("detail_scale", float(settings.get("thatch_detail_scale", 3.0)))
	material.set_shader_parameter("detail_normal_strength", float(settings.get("thatch_normal_strength", 1.1)))
	material.set_shader_parameter("sheen_strength", float(settings.get("thatch_sheen_strength", 0.35)))
	# Les franges (alpha) respirent au vent comme avant ; les pans restent fixes.
	if use_alpha and bool(settings.get("foliage_wind_enabled", true)):
		material.set_shader_parameter("roof_strength", 2.0 * float(settings.get("world_scale", 1.0)))
	material.set_meta("daoc_thatch", true)
	material.set_meta("daoc_pbr_source", source.get_meta("daoc_pbr_source", ""))
	return material
