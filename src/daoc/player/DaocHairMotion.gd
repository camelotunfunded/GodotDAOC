extends RefCounted
class_name DaocHairMotion

const HairProfile = preload("res://src/daoc/player/DaocHairMotionProfile.gd")
const HAIR_SHADER = preload("res://src/daoc/player/daoc_hair_motion.gdshader")
const META_PBR_ORIGINAL := "daoc_pbr_material_vanilla"


static func apply(visual_root: Node) -> Dictionary:
	var report := {"ok": false, "profile": "", "surfaces": 0, "reason": ""}
	if visual_root == null:
		report.reason = "visual_root_absent"
		return report
	var hair := visual_root.find_child("Hair", true, false) as MeshInstance3D
	var head := visual_root.find_child("Head", true, false) as MeshInstance3D
	if hair == null or head == null or hair.mesh == null or head.mesh == null:
		report.reason = "hair_or_head_absent"
		return report
	var analysis: Dictionary = HairProfile.analyze_mesh(hair.mesh, head.mesh)
	if not bool(analysis.get("ok", false)):
		return analysis
	var settings := analysis.get("motion", {}) as Dictionary
	var aabb := hair.mesh.get_aabb()
	var originals: Array = hair.get_meta(META_PBR_ORIGINAL, []) as Array
	for surface_index in range(hair.mesh.get_surface_count()):
		var source := hair.mesh.surface_get_material(surface_index) as StandardMaterial3D
		if source == null and surface_index < originals.size():
			source = originals[surface_index] as StandardMaterial3D
		if source == null or source.albedo_texture == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = HAIR_SHADER
		material.resource_name = "%s_hair_motion" % source.resource_name
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		material.set_shader_parameter("normal_texture", source.normal_texture)
		material.set_shader_parameter("roughness_texture", source.roughness_texture)
		material.set_shader_parameter("metallic_texture", source.metallic_texture)
		material.set_shader_parameter("ao_texture", source.ao_texture)
		material.set_shader_parameter("roughness_amount", maxf(source.roughness, 0.72))
		material.set_shader_parameter("normal_strength", source.normal_scale)
		material.set_shader_parameter("dielectric_specular", source.metallic_specular)
		material.set_shader_parameter("hair_top_y", aabb.end.y)
		material.set_shader_parameter("hair_bottom_y", aabb.position.y)
		material.set_shader_parameter("tip_start", float(settings.get("tip_start", 0.72)))
		material.set_shader_parameter("motion_amplitude", aabb.size.y * 0.055 * float(settings.get("amplitude", 0.18)))
		material.set_shader_parameter("medium_lod_scale", float(settings.get("medium_lod_scale", 0.2)))
		hair.mesh.surface_set_material(surface_index, material)
		report.surfaces = int(report.surfaces) + 1
	report.ok = int(report.surfaces) > 0
	report.profile = str(analysis.get("profile", ""))
	report["analysis"] = analysis
	return report
