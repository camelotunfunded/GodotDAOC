extends RefCounted
class_name DaocPlayerTextureApplicator

const CHECKPOINT := "PLAYER_TEXTURES_H61"


static func apply(root: Node, surface_textures: Dictionary) -> Dictionary:
	var report := {
		"checkpoint": CHECKPOINT,
		"ok": true,
		"requested_surfaces": surface_textures.size(),
		"applied_surfaces": 0,
		"material_applications": 0,
		"missing_surfaces": [],
		"missing_textures": [],
		"resolved_paths": [],
	}
	if root == null:
		report["ok"] = false
		(report["missing_surfaces"] as Array).append("<visual_root>")
		return report
	for surface_value in surface_textures.keys():
		var surface_name := str(surface_value)
		var texture_path := str(surface_textures[surface_value])
		var mesh_instance := root.find_child(surface_name, true, false) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			(report["missing_surfaces"] as Array).append(surface_name)
			continue
		if not FileAccess.file_exists(texture_path):
			(report["missing_textures"] as Array).append(texture_path)
			continue
		var texture := load(texture_path) as Texture2D
		if texture == null:
			(report["missing_textures"] as Array).append(texture_path)
			continue
		var mesh := mesh_instance.mesh.duplicate(true) as Mesh
		if mesh == null:
			(report["missing_surfaces"] as Array).append(surface_name)
			continue
		mesh_instance.mesh = mesh
		var applied_to_surface := false
		for surface_index in range(mesh.get_surface_count()):
			var original := mesh.surface_get_material(surface_index) as StandardMaterial3D
			var material := original.duplicate(true) as StandardMaterial3D if original != null else StandardMaterial3D.new()
			material.resource_name = "%s_h61_material" % surface_name
			material.albedo_color = Color.WHITE
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.set_meta("daoc_texture_path", texture_path)
			mesh.surface_set_material(surface_index, material)
			report["material_applications"] = int(report["material_applications"]) + 1
			applied_to_surface = true
		if applied_to_surface:
			mesh_instance.set_meta("daoc_texture_path", texture_path)
			report["applied_surfaces"] = int(report["applied_surfaces"]) + 1
			(report["resolved_paths"] as Array).append(texture_path)
	report["ok"] = (
		int(report["applied_surfaces"]) == int(report["requested_surfaces"])
		and (report["missing_surfaces"] as Array).is_empty()
		and (report["missing_textures"] as Array).is_empty()
	)
	return report
