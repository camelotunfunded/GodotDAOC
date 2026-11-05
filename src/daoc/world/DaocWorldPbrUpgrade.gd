extends RefCounted
class_name DaocWorldPbrUpgrade

## PBR generique pour les materiaux 3D du monde (props NIF, batiments et PNJ).
## Les interfaces et les shaders specialises sont volontairement ignores.

const STATE_FILE := "_pbr_state.json"

var enabled: bool = true
var map_size: int = 256
var normal_strength: float = 1.0
var roughness_amount: float = 0.85
var ao_amount: float = 0.45
var client_root: String = ""

var _sources_by_stem: Dictionary = {}
var _texture_cache: Dictionary = {}
var _source_index_ready := false


func configure(root_path: String, options: Dictionary = {}) -> void:
	var normalized_root := root_path.replace("\\", "/").trim_suffix("/")
	var old_map_size := map_size
	var root_changed := normalized_root != client_root
	client_root = normalized_root
	enabled = bool(options.get("enabled", enabled))
	map_size = clampi(int(options.get("map_size", map_size)), 64, 1024)
	normal_strength = clampf(float(options.get("normal_strength", normal_strength)), 0.0, 4.0)
	roughness_amount = clampf(float(options.get("roughness_amount", roughness_amount)), 0.0, 1.0)
	ao_amount = clampf(float(options.get("ao_amount", ao_amount)), 0.0, 1.0)
	if root_changed:
		_sources_by_stem.clear()
		_source_index_ready = false
	if root_changed or old_map_size != map_size:
		_texture_cache.clear()


func apply_to_subtree(root: Node) -> Dictionary:
	var report := {"enabled": enabled, "surfaces": 0, "upgraded": 0, "missing": 0, "skipped": 0}
	if root == null:
		return report
	if enabled and not _ensure_source_index():
		return report
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var replacements: Dictionary = {}
	if root is MeshInstance3D:
		meshes.append(root)
	for value in meshes:
		var mi := value as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			report["surfaces"] = int(report["surfaces"]) + 1
			var current: Material = mi.get_surface_override_material(surface)
			if current == null:
				current = mi.mesh.surface_get_material(surface)
			var material := current as StandardMaterial3D
			if material == null or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				report["skipped"] = int(report["skipped"]) + 1
				continue
			var material_id := material.get_instance_id()
			if replacements.has(material_id):
				mi.set_surface_override_material(surface, replacements[material_id] as Material)
				report["upgraded"] = int(report["upgraded"]) + 1
				continue
			if not enabled:
				var vanilla := material.duplicate() as StandardMaterial3D
				if _restore_material(vanilla):
					mi.set_surface_override_material(surface, vanilla)
					replacements[material_id] = vanilla
					report["upgraded"] = int(report["upgraded"]) + 1
				else:
					report["skipped"] = int(report["skipped"]) + 1
				continue
			var stem := mi.mesh.resource_name.get_basename().to_lower()
			var base_path := str(material.get_meta("daoc_pbr_source", ""))
			if base_path == "" and (stem == "" or not _sources_by_stem.has(stem)):
				stem = material.resource_name.get_basename().to_lower()
			if base_path == "":
				base_path = _best_source(stem)
			if base_path == "":
				report["missing"] = int(report["missing"]) + 1
				continue
			var upgraded := material.duplicate() as StandardMaterial3D
			if upgrade_material_from_base(upgraded, base_path):
				mi.set_surface_override_material(surface, upgraded)
				replacements[material_id] = upgraded
				report["upgraded"] = int(report["upgraded"]) + 1
			else:
				report["missing"] = int(report["missing"]) + 1
	return report


func upgrade_material_from_base(material: StandardMaterial3D, source_path: String) -> bool:
	if not enabled or material == null:
		return false
	var base := source_path.get_basename()
	var normal := _load_map(base + "_normal.png")
	var roughness := _load_map(base + "_roughness.png")
	var metallic := _load_map(base + "_metallic.png")
	var ao := _load_map(base + "_ao.png")
	if normal == null and roughness == null and metallic == null and ao == null:
		return false
	if not material.has_meta("daoc_world_pbr_original"):
		material.set_meta("daoc_world_pbr_original", {
			"normal_enabled": material.normal_enabled,
			"normal_texture": material.normal_texture,
			"normal_scale": material.normal_scale,
			"roughness_texture": material.roughness_texture,
			"roughness": material.roughness,
			"metallic_texture": material.metallic_texture,
			"metallic": material.metallic,
			"ao_enabled": material.ao_enabled,
			"ao_texture": material.ao_texture,
			"ao_light_affect": material.ao_light_affect,
		})
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = normal_strength
	if roughness != null:
		material.roughness_texture = roughness
		material.roughness = roughness_amount
	if metallic != null:
		material.metallic_texture = metallic
		material.metallic = 1.0
	if ao != null:
		material.ao_enabled = true
		material.ao_texture = ao
		material.ao_light_affect = ao_amount
	material.set_meta("daoc_world_pbr", true)
	material.set_meta("daoc_pbr_source", source_path)
	return true


func _restore_material(material: StandardMaterial3D) -> bool:
	if material == null or not material.has_meta("daoc_world_pbr_original"):
		return false
	var original: Dictionary = material.get_meta("daoc_world_pbr_original") as Dictionary
	material.normal_enabled = bool(original.get("normal_enabled", false))
	material.normal_texture = original.get("normal_texture", null) as Texture2D
	material.normal_scale = float(original.get("normal_scale", 1.0))
	material.roughness_texture = original.get("roughness_texture", null) as Texture2D
	material.roughness = float(original.get("roughness", 1.0))
	material.metallic_texture = original.get("metallic_texture", null) as Texture2D
	material.metallic = float(original.get("metallic", 0.0))
	material.ao_enabled = bool(original.get("ao_enabled", false))
	material.ao_texture = original.get("ao_texture", null) as Texture2D
	material.ao_light_affect = float(original.get("ao_light_affect", 0.0))
	material.remove_meta("daoc_world_pbr")
	return true


func _ensure_source_index() -> bool:
	if _source_index_ready:
		return not _sources_by_stem.is_empty()
	_source_index_ready = true
	var state_path := client_root.path_join(STATE_FILE)
	if not FileAccess.file_exists(state_path):
		return false
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var sources: Dictionary = (parsed as Dictionary).get("sources", {}) as Dictionary
	for relative_value in sources.keys():
		var relative := str(relative_value).replace("\\", "/")
		var stem := relative.get_file().get_basename().to_lower()
		if stem.ends_with("_normal") or stem.ends_with("_roughness") \
				or stem.ends_with("_metallic") or stem.ends_with("_ao"):
			continue
		if not _sources_by_stem.has(stem):
			_sources_by_stem[stem] = []
		(_sources_by_stem[stem] as Array).append(client_root.path_join(relative))
	return not _sources_by_stem.is_empty()


func _best_source(stem: String) -> String:
	if stem == "" or not _sources_by_stem.has(stem):
		return ""
	var candidates: Array = _sources_by_stem[stem] as Array
	# Les variantes d'un meme morceau partagent relief et classe de matiere.
	# Prendre le premier chemin evite de decoder des milliers d'albedos au boot.
	return str(candidates[0]) if not candidates.is_empty() else ""


func _load_map(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not FileAccess.file_exists(path):
		_texture_cache[path] = null
		return null
	var image := Image.load_from_file(path)
	if image == null:
		_texture_cache[path] = null
		return null
	# P1-118 — plafonner le PLUS GRAND côté en gardant les proportions. Avant, toute
	# carte devenait un carré map_size : une écorce 256×1024 était écrasée et une
	# normale photo 2048 px tombait à 256, relief effacé (« PBR plat »).
	var longest := maxi(image.get_width(), image.get_height())
	if longest > map_size:
		var ratio := float(map_size) / float(longest)
		image.resize(maxi(4, int(image.get_width() * ratio)), maxi(4, int(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	# Compression GPU : une normale 1024 px passe de ~5 Mio à ~1,4 Mio (BC5/BC1).
	if image.get_width() % 4 == 0 and image.get_height() % 4 == 0:
		var is_normal := path.ends_with("_normal.png")
		image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL if is_normal else Image.COMPRESS_SOURCE_GENERIC)
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture
