extends RefCounted
class_name DaocDungeonTextureResolver

## P1-17A3 — resolveur leger de textures pour DungeonLab.
##
## Objectif volontairement etroit : materialiser les textures referencees par
## les NIF de donjon sans declencher le gros index global du ZoneViewer.
## La recherche privilegie le dossier du NIF puis les racines donjon DAoC
## connues (`zones/Dnifs`), avec fallback controle sur quelques dossiers usuels.

const AssetIndexRegistryScript: Script = preload("res://src/daoc/DaocAssetIndexRegistry.gd")

var image_exts: PackedStringArray = PackedStringArray([".png", ".tga", ".bmp", ".dds"])
# Godot 4.6 refuse les appels constructeur dans une expression const.
# Garder cette liste en var instance evite le parse error sans changer le comportement.
const MAX_SCAN_FILES_PER_ROOT: int = 5000
const MAX_SCAN_DEPTH: int = 4

var client_root: String = ""
var alpha_scissor_threshold: float = 0.5

var _path_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _alpha_cache: Dictionary = {}
var _dds_helper: Object = null


func configure(root_path: String, alpha_scissor: float = 0.5) -> void:
	client_root = _norm_path(root_path)
	alpha_scissor_threshold = clampf(alpha_scissor, 0.0, 1.0)
	_path_cache.clear()
	_texture_cache.clear()
	_alpha_cache.clear()
	_dds_helper = AssetIndexRegistryScript.new()


func apply_textures(root: Node, nif_path: String) -> Dictionary:
	var status: Dictionary = {
		"surface_count": 0,
		"texture_requests": 0,
		"textures_resolved": 0,
		"textures_missing": 0,
		"material_names": [],
		"missing_names": [],
		"resolved_paths": [],
		"surfaces": [],
	}
	if root == null:
		return status
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh: Mesh = mi.mesh
		for si in range(mesh.get_surface_count()):
			status["surface_count"] = int(status.get("surface_count", 0)) + 1
			var src: Material = mesh.surface_get_material(si)
			var material_name := ""
			if src != null:
				material_name = src.resource_name.strip_edges()
			if material_name == "":
				_continue_surface(status, mi.name, si, material_name, "", false, "empty material resource_name")
				continue
			status["texture_requests"] = int(status.get("texture_requests", 0)) + 1
			_append_unique(status["material_names"] as Array, material_name)
			var texture_path: String = resolve_texture_path(material_name, nif_path)
			if texture_path == "":
				status["textures_missing"] = int(status.get("textures_missing", 0)) + 1
				_append_unique(status["missing_names"] as Array, material_name)
				_continue_surface(status, mi.name, si, material_name, "", false, "not found")
				continue
			var texture: Texture2D = load_texture(texture_path)
			if texture == null:
				status["textures_missing"] = int(status.get("textures_missing", 0)) + 1
				_append_unique(status["missing_names"] as Array, material_name)
				_continue_surface(status, mi.name, si, material_name, texture_path, false, "load failed")
				continue
			var mat := StandardMaterial3D.new()
			mat.resource_name = material_name
			mat.albedo_texture = texture
			mat.roughness = 1.0
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if bool(_alpha_cache.get(texture_path, false)):
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = alpha_scissor_threshold
			mi.set_surface_override_material(si, mat)
			status["textures_resolved"] = int(status.get("textures_resolved", 0)) + 1
			_append_unique(status["resolved_paths"] as Array, texture_path)
			_continue_surface(status, mi.name, si, material_name, texture_path, true, "")
	return status


func resolve_texture_path(texture_name: String, nif_path: String = "") -> String:
	var key := "%s|%s" % [_norm_path(nif_path).to_lower(), texture_name.strip_edges().to_lower()]
	if _path_cache.has(key):
		return str(_path_cache[key])
	var found := _resolve_texture_path_uncached(texture_name, nif_path)
	_path_cache[key] = found
	return found


func load_texture(path: String) -> Texture2D:
	var p := _norm_path(path)
	if p == "":
		return null
	if _texture_cache.has(p):
		return _texture_cache[p] as Texture2D
	var image: Image = null
	if p.to_lower().ends_with(".dds"):
		if _dds_helper == null:
			_dds_helper = AssetIndexRegistryScript.new()
		image = _dds_helper.call("dds_to_image", p) as Image
	else:
		image = Image.load_from_file(_fs_path(p))
	if image == null:
		_texture_cache[p] = null
		_alpha_cache[p] = false
		return null
	_alpha_cache[p] = image.detect_alpha() != Image.ALPHA_NONE
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[p] = texture
	return texture


func debug_snapshot() -> Dictionary:
	return {
		"scope": "P1-17A3 DungeonLab texture/material resolver",
		"client_root": client_root,
		"path_cache_size": _path_cache.size(),
		"texture_cache_size": _texture_cache.size(),
		"search_roots": _candidate_roots(""),
	}


func _resolve_texture_path_uncached(texture_name: String, nif_path: String) -> String:
	var tex := texture_name.strip_edges().replace("\\", "/")
	if tex == "":
		return ""
	var basename := tex.get_file()
	var explicit_ext := basename.get_extension() != ""
	var stems: Array = []
	_append_unique(stems, basename.get_basename().to_lower())
	_append_unique(stems, tex.get_basename().to_lower())
	var file_variants: Array = []
	if explicit_ext:
		_append_unique(file_variants, basename)
		_append_unique(file_variants, basename.to_lower())
		_append_unique(file_variants, basename.to_upper())
	else:
		for ext_value in image_exts:
			var ext: String = str(ext_value)
			_append_unique(file_variants, basename + ext)
			_append_unique(file_variants, basename.to_lower() + ext)
			_append_unique(file_variants, basename.to_upper() + ext.to_upper())
	for root in _candidate_roots(nif_path):
		for fv in file_variants:
			var direct: String = str(root).path_join(str(fv))
			if FileAccess.file_exists(direct):
				return direct
		for stem in stems:
			var scanned := _scan_for_texture_by_stem(str(root), str(stem), 0, {"files": 0})
			if scanned != "":
				return scanned
	return ""


func _candidate_roots(nif_path: String) -> Array:
	var roots: Array = []
	var np := _norm_path(nif_path)
	if np != "":
		var nif_dir := np.get_base_dir()
		_append_dir_unique(roots, nif_dir)
		_append_dir_unique(roots, nif_dir.get_base_dir())
	var root := _norm_path(client_root)
	if root != "":
		_append_dir_unique(roots, root.path_join("zones/Dnifs"))
		_append_dir_unique(roots, root.path_join("zones/dnifs"))
		_append_dir_unique(roots, root.path_join("zones/DNIFS"))
		_append_dir_unique(roots, root.path_join("zones/nifs"))
		_append_dir_unique(roots, root.path_join("zones/Nifs"))
		_append_dir_unique(roots, root.path_join("zones/NIFS"))
		_append_dir_unique(roots, root.path_join("zones/textures"))
		_append_dir_unique(roots, root.path_join("zones/Textures"))
		_append_dir_unique(roots, root.path_join("zones/TerrainTex"))
		_append_dir_unique(roots, root.path_join("frontiers/nifs"))
		_append_dir_unique(roots, root.path_join("frontiers/zones/TerrainTex"))
		_append_dir_unique(roots, root.path_join("phousing/nifs"))
		_append_dir_unique(roots, root.path_join("tutorial/zones/nifs"))
	return roots


func _scan_for_texture_by_stem(root: String, stem: String, depth: int, budget: Dictionary) -> String:
	if depth > MAX_SCAN_DEPTH:
		return ""
	if int(budget.get("files", 0)) > MAX_SCAN_FILES_PER_ROOT:
		return ""
	var da := DirAccess.open(root)
	if da == null:
		return ""
	var best_path := ""
	var best_rank := -1
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if da.current_is_dir():
			if name != "." and name != "..":
				var found := _scan_for_texture_by_stem(root.path_join(name), stem, depth + 1, budget)
				if found != "" and _image_rank(found) > best_rank:
					best_path = found
					best_rank = _image_rank(found)
		else:
			budget["files"] = int(budget.get("files", 0)) + 1
			var low := name.to_lower()
			var rank := _image_rank(low)
			if rank >= 0 and name.get_basename().to_lower() == stem and rank > best_rank:
				best_path = root.path_join(name)
		name = da.get_next()
	da.list_dir_end()
	return best_path


func _image_rank(path_or_name: String) -> int:
	var low := path_or_name.to_lower()
	if low.ends_with(".png"):
		return 4
	if low.ends_with(".tga"):
		return 3
	if low.ends_with(".bmp"):
		return 2
	if low.ends_with(".dds"):
		return 1
	return -1


func _continue_surface(status: Dictionary, node_name: String, surface: int, material_name: String, path: String, resolved: bool, error: String) -> void:
	var surfaces: Array = status.get("surfaces", []) as Array
	surfaces.append({
		"node": node_name,
		"surface": surface,
		"material_name": material_name,
		"texture_path": path,
		"resolved": resolved,
		"error": error,
	})
	status["surfaces"] = surfaces


func _append_dir_unique(out: Array, path: String) -> void:
	var p := _norm_path(path)
	if p == "" or out.has(p):
		return
	if DirAccess.open(p) == null:
		return
	out.append(p)


func _append_unique(out: Array, value: Variant) -> void:
	if not out.has(value):
		out.append(value)


func _norm_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p


func _fs_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
