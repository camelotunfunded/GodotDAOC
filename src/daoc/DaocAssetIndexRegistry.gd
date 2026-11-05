extends RefCounted
class_name DaocAssetIndexRegistry

const DaocClientRootScript = preload("res://src/daoc/DaocClientRoot.gd")
const DaocFoliageWindScript = preload("res://src/daoc/vegetation/DaocFoliageWind.gd")
const DaocWorldPbrUpgradeScript = preload("res://src/daoc/world/DaocWorldPbrUpgrade.gd")
const DaocThatchMaterialScript = preload("res://src/daoc/world/DaocThatchMaterial.gd")


## P1-15D — registre assets/index extrait de ZoneViewer.
## Il possède les chemins DAoC, l'index modèles, l'index textures, les caches runtime,
## les helpers CSV/image/DDS et les diagnostics missing models.

var daoc_client_root: String = ""
var external_data_dir: String = ""
var models_dir: String = ""
var extra_models_dirs: PackedStringArray = PackedStringArray()
var use_nif_reader: bool = true
## P1-21U : selection experimentale du LOD le plus dense. OFF = premier enfant.
var prop_dense_lod_enabled: bool = false
var texture_dirs: PackedStringArray = PackedStringArray()
var extra_texture_dirs: PackedStringArray = PackedStringArray()
## The complete client contains more than 100k image files. Scanning its root is
## useful for exhaustive audits, but is far too expensive for the viewer startup.
var scan_full_texture_client_root: bool = false
var link_textures: bool = true
var foliage_alpha_scissor: float = 0.5
## Couche detail des NIF multitexture (slot 2 de NiTexturingProperty). ON restitue
## le grain d.origine des troncs et des rochers ; OFF rend exactement comme avant.
var prop_detail_layer_enabled: bool = true
## Compense le "modulate 2x" du client d.origine, que Godot ne reproduit pas tel
## quel : il ne sait faire que base * detail. 1.0 = aucune compensation, les
## surfaces a couche detail ressortent alors nettement plus sombres qu.en 2001.
var prop_detail_gain: float = 2.0
## Signale une seule fois chaque texture detail absente du client decompresse.
var log_missing_detail_textures: bool = true
## R10-HF2 — le vent dans les feuilles. Les surfaces a canal alpha SANS couche
## detail, c.est-a-dire les cartes de feuillage, recoivent un materiau anime au
## lieu d.un StandardMaterial3D fige. DECOCHE rend exactement comme avant : le
## module n.est alors jamais appele.
var foliage_wind_enabled: bool = true
var foliage_wind_settings: Dictionary = {}
var _foliage_wind_converted: int = 0
## PBR des textures 3D du monde. Les cartes sont reduites pour ne pas transformer
## les centaines de props residents en plusieurs gigaoctets de VRAM.
var world_pbr_enabled: bool = true
var world_pbr_map_size: int = 256
var world_pbr_normal_strength: float = 1.0
var world_pbr_roughness_amount: float = 0.85
var world_pbr_ao_amount: float = 0.45
## P1-118 — materiau de chaume (relief + detail photo). Decoche : comportement d.avant.
var thatch_material_enabled: bool = true
var _thatch_detail: Array = []
var _thatch_surfaces: int = 0
var _world_pbr: RefCounted = null
var _world_pbr_surfaces: int = 0

var log_missing_models: bool = true
var export_missing_models_csv: bool = true
var missing_models_csv_path: String = "res://reports/missing_models_last.csv"

var _model_index: Dictionary = {}
var _model_cache: Dictionary = {}
var _model_min_y: Dictionary = {}
var _model_fail_reason: Dictionary = {}
var _model_fail_header: Dictionary = {}
var _model_index_built: bool = false
var _missing_model_logged: Dictionary = {}
var _missing_model_rows: Array = []
var _texture_index: Dictionary = {}
var _texture_alpha: Dictionary = {}
var _texture_cache: Dictionary = {}
var _texture_index_built: bool = false
var _missing_detail_logged: Dictionary = {}
var _config_signature: String = ""
var _cooked_tree_paths: Dictionary = {}
var _cooked_tree_paths_loaded := false
const TEXTURE_INDEX_CACHE_PATH := "user://daoc_texture_index_cache.json"


func configure(settings: Dictionary) -> void:
	var old_sig := _config_signature
	daoc_client_root = _norm_path(str(settings.get("daoc_client_root", daoc_client_root)))
	external_data_dir = _norm_path(str(settings.get("external_data_dir", external_data_dir)))
	models_dir = _norm_path(str(settings.get("models_dir", models_dir)))
	extra_models_dirs = PackedStringArray(settings.get("extra_models_dirs", extra_models_dirs))
	use_nif_reader = bool(settings.get("use_nif_reader", use_nif_reader))
	prop_dense_lod_enabled = bool(settings.get("prop_dense_lod_enabled", prop_dense_lod_enabled))
	texture_dirs = PackedStringArray(settings.get("texture_dirs", texture_dirs))
	extra_texture_dirs = PackedStringArray(settings.get("extra_texture_dirs", extra_texture_dirs))
	scan_full_texture_client_root = bool(settings.get("scan_full_texture_client_root", scan_full_texture_client_root))
	link_textures = bool(settings.get("link_textures", link_textures))
	foliage_alpha_scissor = float(settings.get("foliage_alpha_scissor", foliage_alpha_scissor))
	prop_detail_layer_enabled = bool(settings.get("prop_detail_layer_enabled", prop_detail_layer_enabled))
	prop_detail_gain = float(settings.get("prop_detail_gain", prop_detail_gain))
	log_missing_detail_textures = bool(settings.get("log_missing_detail_textures", log_missing_detail_textures))
	log_missing_models = bool(settings.get("log_missing_models", log_missing_models))
	export_missing_models_csv = bool(settings.get("export_missing_models_csv", export_missing_models_csv))
	missing_models_csv_path = str(settings.get("missing_models_csv_path", missing_models_csv_path))
	# R10-HF2 — le vent dans les feuilles. Les cles de reglage voyagent en bloc
	# vers DaocFoliageWind : ce module porte ses propres defauts, donc une cle
	# absente laisse sa valeur au lieu d.imposer un zero.
	foliage_wind_enabled = bool(settings.get("foliage_wind_enabled", foliage_wind_enabled))
	world_pbr_enabled = bool(settings.get("world_pbr_enabled", world_pbr_enabled))
	world_pbr_map_size = int(settings.get("world_pbr_map_size", world_pbr_map_size))
	world_pbr_normal_strength = float(settings.get("world_pbr_normal_strength", world_pbr_normal_strength))
	world_pbr_roughness_amount = float(settings.get("world_pbr_roughness_amount", world_pbr_roughness_amount))
	world_pbr_ao_amount = float(settings.get("world_pbr_ao_amount", world_pbr_ao_amount))
	thatch_material_enabled = bool(settings.get("thatch_material_enabled", thatch_material_enabled))
	for key: String in DaocFoliageWindScript.default_settings().keys():
		if settings.has(key):
			foliage_wind_settings[key] = settings[key]
	if settings.has("world_scale"):
		foliage_wind_settings["world_scale"] = settings["world_scale"]
	_config_signature = _make_config_signature()
	if old_sig != "" and old_sig != _config_signature:
		clear_runtime_caches()


## Combien de surfaces de feuillage ont recu le materiau anime depuis le
## demarrage. Un COMPTE et non un booleen : « le vent est active » et « quatre-
## vingts surfaces bougent » ne disent pas la meme chose, et c.est la seconde qui
## se verifie.
func foliage_wind_converted_surfaces() -> int:
	return _foliage_wind_converted


func _make_config_signature() -> String:
	return JSON.stringify({
		"root": daoc_client_root,
		"data": external_data_dir,
		"models": models_dir,
		"extra_models": Array(extra_models_dirs),
		"use_nif": use_nif_reader,
		"prop_dense_lod_enabled": prop_dense_lod_enabled,
		"textures": Array(texture_dirs),
		"extra_textures": Array(extra_texture_dirs),
		"scan_full_texture_client_root": scan_full_texture_client_root,
		"link_textures": link_textures,
		"prop_detail_layer_enabled": prop_detail_layer_enabled,
		"prop_detail_gain": prop_detail_gain,
		"world_pbr_enabled": world_pbr_enabled,
		"world_pbr_map_size": world_pbr_map_size,
	})


func clear_runtime_caches() -> void:
	_cooked_tree_paths.clear()
	_cooked_tree_paths_loaded = false
	_world_pbr = null
	_world_pbr_surfaces = 0
	_free_cached_model_nodes()
	_missing_detail_logged.clear()
	_model_index.clear()
	_model_cache.clear()
	_model_min_y.clear()
	_model_fail_reason.clear()
	_model_fail_header.clear()
	_model_index_built = false
	_texture_index.clear()
	_texture_alpha.clear()
	_texture_cache.clear()
	_texture_index_built = false
	_missing_model_logged.clear()
	_missing_model_rows.clear()


func _free_cached_model_nodes() -> void:
	for cached_value in _model_cache.values():
		if cached_value is Node:
			var node: Node = cached_value as Node
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()


func _norm_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p


func effective_data_dir() -> String:
	var d := _norm_path(external_data_dir)
	if d != "":
		return d
	var root := effective_daoc_root()
	if root != "":
		return root.path_join("_godot_daoc_cache").path_join("data")
	return "res://data"


## R10-HF1 — la resolution est mise en cache par chemin CONFIGURE.
##
## `effective_daoc_root` est appelee a chaque recherche d'asset : interroger le
## disque a chaque fois pour verifier une lettre de lecteur couterait bien plus
## cher que le probleme qu'on repare.
var _root_resolution_cache: Dictionary = {}


## La racine du client, avec la LETTRE DE LECTEUR reparee au besoin.
##
## Le projet est ouvert depuis plusieurs machines et le disque n'y porte pas la
## meme lettre. Un chemin configure qui EXISTE est toujours rendu tel quel - la
## correction a la main gagne - mais un chemin qui ne repond pas est reessaye
## avec la lettre du lecteur ou vit `res://` avant d'etre abandonne.
##
## Voir `DaocClientRoot` pour l'ordre complet des cinq candidats.
func effective_daoc_root() -> String:
	var root := _norm_path(daoc_client_root)
	if root == "":
		var d := _norm_path(external_data_dir)
		var marker := "/_godot_daoc_cache/data"
		if d.to_lower().ends_with(marker):
			root = d.substr(0, d.length() - marker.length())
	if root == "":
		return ""
	if _root_resolution_cache.has(root):
		return str(_root_resolution_cache[root])
	var resolution: Dictionary = DaocClientRootScript.resolve(root)
	# Une racine introuvable est rendue TELLE QUELLE et non videe : le message
	# d'erreur en aval doit nommer le chemin que l'utilisateur a demande, pas une
	# chaine vide qui ne dit rien.
	var resolved: String = str(resolution.get("root", "")) if bool(resolution.get("ok", false)) else root
	if bool(resolution.get("healed", false)):
		print("DAOC_CLIENT_ROOT repare : %s -> %s (source=%s)" % [
			root, resolved, str(resolution.get("source", "?"))])
	_root_resolution_cache[root] = resolved
	return resolved


func find_zone_dat_asset(znum: int, file_name: String) -> String:
	var zp := "zone%03d" % znum
	var dp := "dat%03d" % znum
	var cp := "csv%03d" % znum
	var data_dir := effective_data_dir()
	var root := effective_daoc_root()
	var candidates: Array[String] = []
	var upper_name: String = file_name.to_upper()
	candidates.append(data_dir.path_join("zone%03d_%s" % [znum, file_name]))
	candidates.append(data_dir.path_join("zone%03d_%s" % [znum, upper_name]))
	candidates.append(data_dir.path_join(zp).path_join(file_name))
	candidates.append(data_dir.path_join(zp).path_join(dp).path_join(file_name))
	candidates.append(data_dir.path_join(zp).path_join(cp).path_join(file_name))
	candidates.append(data_dir.path_join(dp).path_join(file_name))
	candidates.append(data_dir.path_join(cp).path_join(file_name))
	candidates.append(data_dir.path_join(file_name))
	if root != "":
		for zr in [
			root.path_join("zones").path_join(zp),
			root.path_join("frontiers/zones").path_join(zp),
			root.path_join("phousing/zones").path_join(zp),
			root.path_join("tutorial/zones").path_join(zp),
			root.path_join("zones"),
			root.path_join("frontiers/zones"),
			root.path_join("phousing/zones"),
			root.path_join("tutorial/zones"),
		]:
			candidates.append(zr.path_join(dp).path_join(file_name))
			candidates.append(zr.path_join(cp).path_join(file_name))
			candidates.append(zr.path_join("dat").path_join(file_name))
			candidates.append(zr.path_join("csv").path_join(file_name))
			candidates.append(zr.path_join(file_name))
			candidates.append(zr.path_join("terrain").path_join(file_name))
	for candidate_path in candidates:
		if candidate_path != "" and FileAccess.file_exists(candidate_path):
			return candidate_path
	return ""


func data_path(file_name: String) -> String:
	return effective_data_dir().path_join(file_name)


func fs_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func load_json_file(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed


func load_texture_file(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path)
	var im := Image.load_from_file(fs_path(path))
	if im == null:
		return null
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


func _dir_exists(path: String) -> bool:
	return _norm_path(path) != "" and DirAccess.open(_norm_path(path)) != null


func _append_unique_dir(out: Array, path: String, require_exists: bool = true) -> void:
	var p := _norm_path(path)
	if p == "" or out.has(p):
		return
	if require_exists and not _dir_exists(p):
		return
	out.append(p)


func model_search_dirs() -> Array:
	var out: Array = []
	_append_unique_dir(out, models_dir)
	var root := effective_daoc_root()
	if root != "":
		_append_unique_dir(out, root.path_join("zones/nifs"))
		_append_unique_dir(out, root.path_join("frontiers/nifs"))
		_append_unique_dir(out, root.path_join("phousing/nifs"))
		_append_unique_dir(out, root.path_join("tutorial/zones/nifs"))
		# Conversion/cache Godot convention seen in older benches.
		_append_unique_dir(out, root.path_join("_godot_daoc_cache/models"), false)
	for d in extra_models_dirs:
		_append_unique_dir(out, d)
	return out


func texture_search_dirs() -> Array:
	var out: Array = []
	for d in texture_dirs:
		_append_unique_dir(out, d)
	var root := effective_daoc_root()
	if root != "":
		_append_unique_dir(out, root.path_join("zones/nifs"))
		_append_unique_dir(out, root.path_join("zones/TerrainTex"))
		_append_unique_dir(out, root.path_join("frontiers/nifs"))
		_append_unique_dir(out, root.path_join("frontiers/zones/TerrainTex"))
		_append_unique_dir(out, root.path_join("phousing/nifs"))
		_append_unique_dir(out, root.path_join("tutorial/zones/nifs"))
		_append_unique_dir(out, root.path_join("tutorial/zones/TerrainTex"))
		# Exhaustive audit fallback. Never enable this implicitly: a normal client
		# can contain more than 100k images and used to freeze startup for minutes.
		if scan_full_texture_client_root:
			_append_unique_dir(out, root)
	for d in extra_texture_dirs:
		_append_unique_dir(out, d)
	return out


func ensure_model_index() -> void:
	if _model_index_built:
		return
	_model_index_built = true
	var dirs := model_search_dirs()
	if dirs.is_empty():
		push_warning("no model search directory. Set daoc_client_root or models_dir.")
		return
	for d in dirs:
		_scan_dir_for_models(d)
	print("model index: %d %s files across %d dir(s)" % [_model_index.size(), (".nif" if use_nif_reader else ".glb"), dirs.size()])


func _scan_dir_for_models(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	var want := ".nif" if use_nif_reader else ".glb"
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if da.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir_for_models(path.path_join(fname))
		elif fname.to_lower().ends_with(want):
			var stem := fname.get_basename().to_lower()
			if not _model_index.has(stem):
				_model_index[stem] = path.path_join(fname)
		fname = da.get_next()
	da.list_dir_end()


func get_model(filename: String) -> Node3D:
	if filename == "":
		return null
	ensure_model_index()
	var stem := filename.get_basename().to_lower()
	var abs_path: String = _model_index.get(stem, "")
	if abs_path == "":
		_model_fail_reason[stem] = "file not found in model index"
		return null
	if _model_cache.has(abs_path):
		return _model_cache[abs_path] as Node3D
	if abs_path.to_lower().ends_with(".nif"):
		# P1-133 : la collision relit le NIF (branche collidee) ; le gabarit garde son chemin.
		var nif_node := _get_model_nif(abs_path, stem)
		if nif_node != null:
			nif_node.set_meta("daoc_nif_abs_path", abs_path)
		return nif_node
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(abs_path, state)
	if err != OK:
		_model_fail_reason[stem] = "glTF load failed (%d)" % err
		push_warning("glTF load failed (%d): %s" % [err, abs_path])
		_model_cache[abs_path] = null
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		_model_fail_reason[stem] = "glTF generated null scene"
		_model_cache[abs_path] = null
		return null
	if link_textures:
		apply_textures(scene)
	_model_min_y[stem] = _template_min_y(scene)
	_model_cache[abs_path] = scene
	return scene


func _get_model_nif(abs_path: String, stem: String) -> Node3D:
	if prop_dense_lod_enabled:
		var cooked := _get_cooked_tree(abs_path)
		if cooked != null:
			if link_textures:
				apply_textures(cooked)
			_model_min_y[stem] = _template_min_y(cooked)
			_model_cache[abs_path] = cooked
			return cooked
	var reader := NifReader.new()
	var header := peek_file_header_line(abs_path)
	_model_fail_header[stem] = header
	var read_ok := reader.read(abs_path)
	if not read_ok or reader.failed:
		_model_fail_reason[stem] = str(reader.fail_reason)
		if header.find("Gamebryo File Format, Version 10.") != -1:
			_model_fail_reason[stem] += " / GAMEBRYO_10x"
			# Les fichiers 10.1 n'ont aucune table de tailles de blocs. Si une
			# variante vendeur apparaît après des géométries déjà décodées, le
			# lecteur signale justement la désynchronisation ; ne jetons pas pour
			# autant les surfaces statiques valides déjà acquises.
			# Une récupération partielle ne parcourt jamais toutes les variantes LOD :
			# les références situées après la désynchronisation ne sont plus fiables.
			var partial := NifConverter.build_template(reader, stem, false)
			if partial != null and partial.get_child_count() > 0:
				# DR_Alb_tavern place son corps de bâtiment après un long cluster
				# particules vendeur. Tant que ce layout 10.1 n'est pas entièrement
				# décodé, le fragment récupéré ne contient que les portes. Afficher la
				# taverne Albion complète classique est plus fidèle que deux portes
				# flottantes, tout en conservant la collision serveur inchangée.
				if stem == "dr_alb_tavern" and _surface_count(partial) < 20:
					var fallback_source := get_model("Btavern")
					var fallback := fallback_source.duplicate() as Node3D if fallback_source != null else null
					if fallback != null:
						fallback.set_meta("daoc_gamebryo10_visual_fallback", "Btavern")
						fallback.set_meta("daoc_partial_reason", reader.fail_reason)
						_model_min_y[stem] = _template_min_y(fallback)
						_model_cache[abs_path] = fallback
						return fallback
				partial.set_meta("daoc_partial_gamebryo10", true)
				partial.set_meta("daoc_partial_reason", reader.fail_reason)
				if link_textures:
					apply_textures(partial)
				_model_min_y[stem] = _template_min_y(partial)
				_model_cache[abs_path] = partial
				return partial
		push_warning("NIF load failed: %s — %s" % [abs_path, reader.fail_reason])
		_model_cache[abs_path] = null
		return null
	var scene := NifConverter.build_template(reader, stem, prop_dense_lod_enabled)
	if scene == null or scene.get_child_count() == 0:
		_model_fail_reason[stem] = "NIF parsed but converter produced empty scene"
		_model_cache[abs_path] = null
		return null
	if link_textures:
		apply_textures(scene)
	_model_min_y[stem] = _template_min_y(scene)
	_model_cache[abs_path] = scene
	return scene


func _surface_count(root: Node) -> int:
	var total := 0
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null:
			total += mesh_instance.mesh.get_surface_count()
	return total


func _get_cooked_tree(abs_path: String) -> Node3D:
	if not _cooked_tree_paths_loaded:
		_cooked_tree_paths_loaded = true
		var manifest_path := "res://generated/trees/nif/manifest.json"
		if FileAccess.file_exists(manifest_path):
			var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if manifest is Dictionary:
				for row in manifest.get("rows", []):
					if row.get("geometry_checked", false) and row.get("status") == "READY_FOR_VISUAL_REVIEW" and int(row.get("surfaces", 0)) > 0 and row.get("missing_textures", []).is_empty() and row.get("save_error", 1) == OK:
						_cooked_tree_paths[str(row.path).to_lower()] = str(row.scene)
	var relative := _norm_path(abs_path).trim_prefix(effective_daoc_root().rstrip("/") + "/").to_lower()
	var path := str(_cooked_tree_paths.get(relative, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed = load(path)
	return packed.instantiate() as Node3D if packed is PackedScene else null


func model_min_y(filename: String) -> float:
	return float(_model_min_y.get(filename.get_basename().to_lower(), 0.0))


func _template_min_y(root: Node) -> float:
	if root.has_meta("daoc_anchor_min_y"):
		return float(root.get_meta("daoc_anchor_min_y"))
	var miny := INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.mesh.get_aabb()
		var y := ab.position.y + mi.position.y
		if y < miny:
			miny = y
	return 0.0 if miny == INF else miny


func ensure_texture_index() -> void:
	if _texture_index_built:
		return
	_texture_index_built = true
	var t0 := Time.get_ticks_msec()
	var dirs := texture_search_dirs()
	if _restore_texture_index_cache(dirs):
		print("texture index: %d images restored from cache (%d ms)" % [_texture_index.size(), Time.get_ticks_msec() - t0])
		return
	var scanned := 0
	for d in dirs:
		_scan_dir_for_textures(d)
		scanned += 1
	_store_texture_index_cache(dirs)
	print("texture index: %d images across %d dir(s) (%d ms)" % [_texture_index.size(), scanned, Time.get_ticks_msec() - t0])


func _texture_index_cache_signature(dirs: Array) -> String:
	return JSON.stringify({
		"version": 1,
		"config": _config_signature,
		"dirs": dirs,
	})


func _restore_texture_index_cache(dirs: Array) -> bool:
	if not FileAccess.file_exists(TEXTURE_INDEX_CACHE_PATH):
		return false
	var cache_text := FileAccess.get_file_as_string(TEXTURE_INDEX_CACHE_PATH)
	if cache_text.is_empty():
		return false
	var parser := JSON.new()
	if parser.parse(cache_text) != OK:
		return false
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return false
	var cached := parsed as Dictionary
	if str(cached.get("signature", "")) != _texture_index_cache_signature(dirs):
		return false
	var index = cached.get("index", {})
	if not index is Dictionary or (index as Dictionary).is_empty():
		return false
	_texture_index = (index as Dictionary).duplicate()
	return true


func _store_texture_index_cache(dirs: Array) -> void:
	if _texture_index.is_empty():
		return
	var file := FileAccess.open(TEXTURE_INDEX_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"signature": _texture_index_cache_signature(dirs),
		"index": _texture_index,
	}))
	file.flush()
	file.close()


func _scan_dir_for_textures(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if da.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir_for_textures(path.path_join(fname))
		else:
			var low := fname.to_lower()
			var rank := _img_rank(low)
			if rank >= 0:
				var stem := fname.get_basename().to_lower()
				var cur: String = _texture_index.get(stem, "")
				if cur == "" or rank > _img_rank(cur.get_file().to_lower()):
					_texture_index[stem] = path.path_join(fname)
		fname = da.get_next()
	da.list_dir_end()


func _img_rank(low: String) -> int:
	if low.ends_with(".png"):
		return 3
	if low.ends_with(".tga"):
		return 2
	if low.ends_with(".bmp"):
		return 1
	if low.ends_with(".dds"):
		return 0
	return -1


func get_texture(matname: String) -> Texture2D:
	if matname == "" or matname == "mat":
		return null
	ensure_texture_index()
	var stem := matname.get_basename().to_lower()
	if _texture_cache.has(stem):
		return _texture_cache[stem] as Texture2D
	var p: String = _texture_index.get(stem, "")
	if p == "":
		_texture_cache[stem] = null
		return null
	var im: Image
	if p.to_lower().ends_with(".dds"):
		im = dds_to_image(p)
	else:
		im = Image.load_from_file(fs_path(p))
	if im == null:
		push_warning("texture load failed: %s" % p)
		_texture_cache[stem] = null
		return null
	_texture_alpha[stem] = im.detect_alpha() != Image.ALPHA_NONE
	im.generate_mipmaps()
	var tex := ImageTexture.create_from_image(im)
	_texture_cache[stem] = tex
	return tex


func apply_textures(root: Node) -> void:
	ensure_texture_index()
	var pbr := _ensure_world_pbr()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var m: Mesh = mi.mesh
		if m == null:
			continue
		for si in m.get_surface_count():
			var src := m.surface_get_material(si)
			# Les volumes de service NIF restent dans le maillage pour conserver
			# l'ancrage original, mais leur materiau invisible ne doit jamais etre
			# remplace par une texture opaque lors du chainage des textures.
			var nm := ""
			if src != null:
				nm = src.resource_name
			if src != null and src.has_meta("daoc_hidden_collision_surface"):
				var hidden := StandardMaterial3D.new()
				hidden.resource_name = nm
				hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				hidden.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
				hidden.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				hidden.set_meta("daoc_hidden_collision_surface", true)
				mi.set_surface_override_material(si, hidden)
				continue
			var tex := get_texture(nm)
			if tex == null:
				continue
			var sm := StandardMaterial3D.new()
			sm.resource_name = nm
			sm.albedo_texture = tex
			sm.roughness = 1.0
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			if _texture_alpha.get(nm.get_basename().to_lower(), false):
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				sm.alpha_scissor_threshold = foliage_alpha_scissor
			# Les vieux NiParticles doivent garder leur fusion alpha et leur rendu
			# non eclaire. Le convertisseur pose ces metadonnees sur le fallback.
			if src != null and src.has_meta("daoc_particle_surface"):
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				sm.vertex_color_use_as_albedo = true
			_apply_detail_layer(sm, src)
			var texture_path := str(_texture_index.get(nm.get_basename().to_lower(), ""))
			sm.set_meta("daoc_pbr_source", texture_path)
			if pbr != null and pbr.call("upgrade_material_from_base", sm, texture_path):
				_world_pbr_surfaces += 1
			if thatch_material_enabled and DaocThatchMaterialScript.is_thatch_texture(nm.get_basename()):
				var detail := _thatch_detail_textures()
				var thatch_settings: Dictionary = foliage_wind_settings.duplicate(true)
				thatch_settings["foliage_wind_enabled"] = foliage_wind_enabled
				var thatch: ShaderMaterial = DaocThatchMaterialScript.build(sm, detail[0], detail[1], thatch_settings)
				if thatch != null:
					_thatch_surfaces += 1
					mi.set_surface_override_material(si, thatch)
					continue
			# R10-HF2 — le feuillage bouge, le tronc non. La couche detail vient
			# d.etre posee, et elle EXCLUT la surface du vent : P1-21T a mesure
			# qu.elle porte le grain d.ecorce et de pierre, jamais des feuilles.
			var animated: ShaderMaterial = null
			if foliage_wind_enabled:
				var wind_settings: Dictionary = foliage_wind_settings.duplicate(true)
				wind_settings["foliage_wind_enabled"] = true
				wind_settings["asset_name"] = root.name
				animated = DaocFoliageWindScript.build_material(sm, wind_settings)
			if animated != null:
				_foliage_wind_converted += 1
				mi.set_surface_override_material(si, animated)
			else:
				mi.set_surface_override_material(si, sm)


## Couleur et normale du chaume photo, chargées une fois (normale en pleine
## résolution : c'est elle qui porte les brins, la réduire à 256 les effacerait).
func _thatch_detail_textures() -> Array:
	if not _thatch_detail.is_empty():
		return _thatch_detail
	var stem := DaocThatchMaterialScript.DETAIL_STEM
	var albedo := get_texture(stem)
	var normal: Texture2D = null
	var path := str(_texture_index.get(stem, ""))
	if path != "":
		var image := Image.load_from_file(fs_path(path.get_basename() + "_normal.png"))
		if image != null:
			image.generate_mipmaps()
			normal = ImageTexture.create_from_image(image)
	_thatch_detail = [albedo, normal]
	return _thatch_detail


func thatch_surfaces() -> int:
	return _thatch_surfaces


func _ensure_world_pbr() -> RefCounted:
	if not world_pbr_enabled:
		return null
	if _world_pbr == null:
		_world_pbr = DaocWorldPbrUpgradeScript.new()
		_world_pbr.call("configure", effective_daoc_root(), {
			"enabled": world_pbr_enabled,
			"map_size": world_pbr_map_size,
			"normal_strength": world_pbr_normal_strength,
			"roughness_amount": world_pbr_roughness_amount,
			"ao_amount": world_pbr_ao_amount,
		})
	return _world_pbr


func configure_world_pbr_runtime(options: Dictionary) -> void:
	world_pbr_enabled = bool(options.get("enabled", world_pbr_enabled))
	world_pbr_map_size = int(options.get("map_size", world_pbr_map_size))
	world_pbr_normal_strength = float(options.get("normal_strength", world_pbr_normal_strength))
	world_pbr_roughness_amount = float(options.get("roughness_amount", world_pbr_roughness_amount))
	world_pbr_ao_amount = float(options.get("ao_amount", world_pbr_ao_amount))
	if _world_pbr == null:
		_world_pbr = DaocWorldPbrUpgradeScript.new()
	_world_pbr.call("configure", effective_daoc_root(), {
		"enabled": world_pbr_enabled,
		"map_size": world_pbr_map_size,
		"normal_strength": world_pbr_normal_strength,
		"roughness_amount": world_pbr_roughness_amount,
		"ao_amount": world_pbr_ao_amount,
	})
	# Un prochain configure() ne doit pas prendre cette bascule a chaud pour un
	# changement de projet et vider tous les modeles residents.
	_config_signature = _make_config_signature()


func apply_world_pbr_runtime(root: Node) -> Dictionary:
	if _world_pbr == null:
		configure_world_pbr_runtime({"enabled": world_pbr_enabled})
	return _world_pbr.call("apply_to_subtree", root) as Dictionary


func world_pbr_upgraded_surfaces() -> int:
	return _world_pbr_surfaces


## Couche detail (slot 2 de NiTexturingProperty), posee par NifConverter en
## metadonnee sur le materiau du maillage. Elle porte le grain que la texture de
## base n'a pas : ecorce des troncs multitexture, pierre des rochers. Sans elle,
## le tronc ne montre que la zone basse resolution de la texture de base.
##
## Le client d'origine module en "2x" : le resultat vaut base * detail * 2, ce
## qui garde la luminosite moyenne. Godot n'offre que base * detail, d'ou le gain
## rendu par `prop_detail_gain` sur les seules surfaces qui portent une couche
## detail. Toute la fonction est court-circuitee par `prop_detail_layer_enabled`.
func _apply_detail_layer(sm: StandardMaterial3D, source_material: Material) -> void:
	if not prop_detail_layer_enabled:
		return
	if source_material == null or not source_material.has_meta("daoc_detail_texture"):
		return
	var detail_name := str(source_material.get_meta("daoc_detail_texture"))
	if detail_name == "":
		return
	var detail_tex := get_texture(detail_name)
	if detail_tex == null:
		# Certaines textures detail ne sont pas livrees avec le client decompresse
		# (oakdetail.tga, elmdetail.tga). On rend alors la surface comme avant.
		if log_missing_detail_textures and not _missing_detail_logged.has(detail_name):
			_missing_detail_logged[detail_name] = true
			print("DETAIL TEXTURE ABSENTE '%s' — surface rendue sans couche detail" % detail_name)
		return
	sm.detail_enabled = true
	sm.detail_albedo = detail_tex
	sm.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	# Le jeu d'UV 1 porte le tuilage de la couche ; sans lui elle se plaquerait 1:1.
	var uv_set := int(source_material.get_meta("daoc_detail_uv_set", 0))
	sm.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2 if uv_set >= 1 else BaseMaterial3D.DETAIL_UV_1
	if prop_detail_gain != 1.0:
		sm.albedo_color = Color(prop_detail_gain, prop_detail_gain, prop_detail_gain, sm.albedo_color.a)


func record_missing_model(znum: int, fx: Dictionary, filename: String) -> void:
	var nif_id := int(fx.get("nif", -1))
	var fixture_id := int(fx.get("id", 0))
	var stem := filename.get_basename().to_lower()
	var abs_path := ""
	if stem != "":
		abs_path = str(_model_index.get(stem, ""))
	var reason := ""
	var header := ""
	if filename == "":
		reason = "missing entry in placement models table"
	elif abs_path == "":
		reason = "file not found in model index"
	else:
		reason = str(_model_fail_reason.get(stem, "load/parse/convert failed"))
		header = str(_model_fail_header.get(stem, ""))
		if header == "":
			header = peek_file_header_line(abs_path)
	var row := {
		"zone": znum,
		"fixture_id": fixture_id,
		"nif_id": nif_id,
		"file": filename,
		"reason": reason,
		"path": abs_path,
		"header": header,
	}
	_missing_model_rows.append(row)
	if log_missing_models:
		var key := "%03d|%d|%s" % [znum, nif_id, stem]
		if not _missing_model_logged.has(key):
			_missing_model_logged[key] = true
			print("MISSING MODEL zone%03d fixture_id=%d nif_id=%d file='%s' reason='%s' path='%s' header='%s'" % [znum, fixture_id, nif_id, filename, reason, abs_path, header])


func write_missing_models_csv() -> void:
	if _missing_model_rows.is_empty():
		return
	var f := FileAccess.open(missing_models_csv_path, FileAccess.WRITE)
	if f == null:
		push_warning("cannot write missing models CSV: %s" % missing_models_csv_path)
		return
	f.store_line("zone;fixture_id;nif_id;file;reason;path;header")
	for row in _missing_model_rows:
		f.store_line(";".join([
			_csv_cell(row.get("zone", "")),
			_csv_cell(row.get("fixture_id", "")),
			_csv_cell(row.get("nif_id", "")),
			_csv_cell(row.get("file", "")),
			_csv_cell(row.get("reason", "")),
			_csv_cell(row.get("path", "")),
			_csv_cell(row.get("header", "")),
		]))
	f.close()
	print("missing models CSV written: %s (%d rows)" % [ProjectSettings.globalize_path(missing_models_csv_path), _missing_model_rows.size()])


func _csv_cell(v: Variant) -> String:
	var s := str(v).replace("\"", "'").replace("\n", " ").replace("\r", " ")
	return "\"%s\"" % s if s.find(";") >= 0 else s


func peek_file_header_line(abs_path: String) -> String:
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return ""
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return ""
	var line := f.get_line().strip_edges()
	f.close()
	return line


func csv_col(cols: PackedStringArray, idx: int) -> String:
	if idx < 0 or idx >= cols.size():
		return ""
	return cols[idx].strip_edges()


func csv_int(cols: PackedStringArray, idx: int, default_value: int = 0) -> int:
	var s: String = csv_col(cols, idx)
	if s == "":
		return default_value
	return int(s)


func csv_float(cols: PackedStringArray, idx: int, default_value: float = 0.0) -> float:
	var s: String = csv_col(cols, idx)
	if s == "":
		return default_value
	return float(s)


func parse_zonejump_csv(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cols := line.split(",", false)
		if cols.size() < 8:
			continue
		var entry := {
			"id": csv_int(cols, 0, out.size() + 1),
			"name": csv_col(cols, 1),
			"a": Vector2(csv_float(cols, 2), csv_float(cols, 3)),
			"b": Vector2(csv_float(cols, 4), csv_float(cols, 5)),
			"z_min": csv_float(cols, 6),
			"z_max": csv_float(cols, 7),
			"target": csv_int(cols, 8, -1) if cols.size() > 8 else -1,
			"extra1": csv_col(cols, 9) if cols.size() > 9 else "",
			"extra2": csv_col(cols, 10) if cols.size() > 10 else "",
			"source_path": path,
		}
		out.append(entry)
	f.close()
	return out


func load_image_array(dir_path: String, count: int, pad: int, size: int, mips: bool) -> Texture2DArray:
	var imgs: Array[Image] = []
	for i in count:
		var p := "%s/%s.png" % [dir_path, str(i).pad_zeros(pad)]
		var im := Image.load_from_file(fs_path(p))
		if im == null:
			push_warning("splat: missing %s" % p)
			continue
		im.convert(Image.FORMAT_RGBA8)
		if im.get_width() != size or im.get_height() != size:
			im.resize(size, size, Image.INTERPOLATE_LANCZOS)
		if mips:
			im.generate_mipmaps()
		imgs.append(im)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	return arr


func _dds_colors(c0: int, c1: int, fourcc: String) -> PackedInt32Array:
	var r0 := (c0 >> 11) & 0x1f
	var g0 := (c0 >> 5) & 0x3f
	var b0 := c0 & 0x1f
	var r1 := (c1 >> 11) & 0x1f
	var g1 := (c1 >> 5) & 0x3f
	var b1 := c1 & 0x1f
	r0 = (r0 << 3) | (r0 >> 2)
	g0 = (g0 << 2) | (g0 >> 4)
	b0 = (b0 << 3) | (b0 >> 2)
	r1 = (r1 << 3) | (r1 >> 2)
	g1 = (g1 << 2) | (g1 >> 4)
	b1 = (b1 << 3) | (b1 >> 2)
	var c := PackedInt32Array()
	c.append(r0); c.append(g0); c.append(b0)
	c.append(r1); c.append(g1); c.append(b1)
	if fourcc == "DXT1" and c0 <= c1:
		c.append((r0 + r1) / 2); c.append((g0 + g1) / 2); c.append((b0 + b1) / 2)
		c.append(0); c.append(0); c.append(0)
	else:
		c.append((2 * r0 + r1) / 3); c.append((2 * g0 + g1) / 3); c.append((2 * b0 + b1) / 3)
		c.append((r0 + 2 * r1) / 3); c.append((g0 + 2 * g1) / 3); c.append((b0 + 2 * b1) / 3)
	return c


func dds_to_image(path: String) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 128 or data.decode_u32(0) != 0x20534444:
		return null
	var h := int(data.decode_u32(12))
	var w := int(data.decode_u32(16))
	var pf_flags := int(data.decode_u32(80))
	var fourcc := data.slice(84, 88).get_string_from_ascii()
	var off := 128
	var out := PackedByteArray()
	out.resize(w * h * 4)

	if fourcc != "DXT1" and fourcc != "DXT3" and fourcc != "DXT5":
		var bitcount := int(data.decode_u32(88))
		if (pf_flags & 0x40) != 0 and bitcount == 32:
			for i in w * h:
				out[i * 4 + 0] = data[off + i * 4 + 2]
				out[i * 4 + 1] = data[off + i * 4 + 1]
				out[i * 4 + 2] = data[off + i * 4 + 0]
				out[i * 4 + 3] = data[off + i * 4 + 3]
			return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
		push_warning("unsupported DDS fourcc '%s': %s" % [fourcc, path])
		return null

	var bw := (w + 3) / 4
	var bh := (h + 3) / 4
	var alpha := PackedInt32Array()
	alpha.resize(16)
	for by in bh:
		for bx in bw:
			for i in 16:
				alpha[i] = 255
			if fourcc == "DXT3":
				for i in 16:
					var nib := (data[off + i / 2] >> (4 * (i % 2))) & 0xf
					alpha[i] = nib * 17
				off += 8
			elif fourcc == "DXT5":
				var a0 := data[off]
				var a1 := data[off + 1]
				var bits := 0
				for k in 6:
					bits |= int(data[off + 2 + k]) << (8 * k)
				var at := PackedInt32Array()
				at.append(a0); at.append(a1)
				if a0 > a1:
					for k in range(1, 7):
						at.append(((7 - k) * a0 + k * a1) / 7)
				else:
					for k in range(1, 5):
						at.append(((5 - k) * a0 + k * a1) / 5)
					at.append(0); at.append(255)
				for i in 16:
					alpha[i] = at[(bits >> (3 * i)) & 0x7]
				off += 8
			var c0 := int(data.decode_u16(off))
			var c1 := int(data.decode_u16(off + 2))
			var idx := int(data.decode_u32(off + 4))
			off += 8
			var col := _dds_colors(c0, c1, fourcc)
			for i in 16:
				var px := bx * 4 + (i % 4)
				var py := by * 4 + (i / 4)
				if px < w and py < h:
					var ci := (idx >> (2 * i)) & 0x3
					var o := (py * w + px) * 4
					out[o + 0] = col[ci * 3 + 0]
					out[o + 1] = col[ci * 3 + 1]
					out[o + 2] = col[ci * 3 + 2]
					var a := alpha[i]
					if fourcc == "DXT1" and c0 <= c1 and ci == 3:
						a = 0
					out[o + 3] = a
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


func status_snapshot() -> Dictionary:
	return {
		"scope": "P1-15D AssetIndexRegistry foundation",
		"configured": _config_signature != "",
		"data_dir": effective_data_dir(),
		"daoc_root": effective_daoc_root(),
		"model_index_built": _model_index_built,
		"model_index_size": _model_index.size(),
		"model_cache_size": _model_cache.size(),
		"model_min_y_size": _model_min_y.size(),
		"model_fail_reason_size": _model_fail_reason.size(),
		"texture_index_built": _texture_index_built,
		"texture_index_size": _texture_index.size(),
		"texture_cache_size": _texture_cache.size(),
		"texture_alpha_size": _texture_alpha.size(),
		"missing_model_rows": _missing_model_rows.size(),
		"missing_model_logged": _missing_model_logged.size(),
		"model_search_dirs": model_search_dirs(),
		"texture_search_dirs": texture_search_dirs(),
		"scan_full_texture_client_root": scan_full_texture_client_root,
		"use_nif_reader": use_nif_reader,
		"link_textures": link_textures,
	}
