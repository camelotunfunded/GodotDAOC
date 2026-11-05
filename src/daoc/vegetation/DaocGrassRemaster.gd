extends Node3D
class_name DaocGrassRemaster

const TerrainGrassClassifier = preload("res://src/daoc/vegetation/DaocTerrainGrassClassifier.gd")
const GrassShader = preload("res://src/daoc/vegetation/DaocGrassRemaster.gdshader")
const LawnShader = preload("res://src/daoc/vegetation/DaocLawnShell.gdshader")
## LES DEUX TABLEAUX SONT ALIGNES PAR INDICE : `GRASS_NORMAL_PATHS[i]` est la
## normale de `GRASS_TEXTURE_PATHS[i]`, et une chaine vide veut dire « ce sprite
## n'en a pas ». Retirer une silhouette impose donc de retirer sa ligne DANS LES
## DEUX, sans quoi toutes les normales suivantes glissent d'un cran — un defaut
## qui ne leve aucune erreur et se lit comme un eclairage bizarre.
##
## RECALE LE 2026-09-09 : `verdant_swordfern` retire. L'utilisateur avait supprime
## le PNG du disque, le jugeant inapproprie ; la liste continuait de le declarer,
## d'ou `texture_resource_exists` faux et la suite a 22/25. Le jeu conserve fait
## foi — ce n'etait pas une panne d'import, c'etait un choix.
const GRASS_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/grass/remaster/verdant_egrass01.png",
	"res://assets/grass/remaster/verdant_egrass02short.png",
	"res://assets/grass/remaster/verdant_fieldgrassobj02.png",
	"res://assets/grass/remaster/verdant_egrass03.png",
	"res://assets/grass/remaster/verdant_forestgrass01.png",
	"res://assets/grass/remaster/verdant_weedygroundcover.png",
	"res://assets/grass/remaster/verdant_helegrass01fa.png",
	"res://assets/grass/remaster/verdant_mixgrass02.png",
	"res://assets/grass/remaster/verdant_vurt_brownplants.png",
	"res://assets/grass/remaster/verdant_margagrass01fo.png",
	"res://assets/grass/remaster/verdant_vurt_bengrass.png",
	"res://assets/outward/foliage_grass_01_billboard_c.png",
	"res://assets/outward/foliage_grass_02_billboard_c.png",
	"res://assets/outward/foliage_grass_03_billboard_c.png",
	"res://assets/outward/foliage_grass_04_billboard_c.png",
	"res://assets/outward/foliage_grass_05_billboard_c.png",
	"res://assets/outward/foliage_grass_05a_billboard_c.png",
	"res://assets/outward/foliage_grass_06_billboard_c.png",
	"res://assets/outward/foliage_grass_07_billboard_c.png",
	"res://assets/outward/foliage_grass_07a_billboard_c.png",
	"res://assets/outward/foliage_grass_02a_billboard_c.png",
]
const GRASS_NORMAL_PATHS: PackedStringArray = [
	"", "", "", "",
	"res://assets/grass/remaster/verdant_forestgrass01_n.png",
	"res://assets/grass/remaster/verdant_weedygroundcover_n.png",
	"res://assets/grass/remaster/verdant_helegrass01fa_n.png",
	"res://assets/grass/remaster/verdant_mixgrass02_n.png",
	"",
	"res://assets/grass/remaster/verdant_margagrass01fo_n.png",
	"",
	"", "", "", "", "", "", "", "", "", "",
]

var _outward_rocks_enabled := false
var _outward_flowers_enabled := false
var _outward_rock_meshes: Array[Mesh] = []
var _outward_rock_material: Material
var _outward_flower_mesh: Mesh
var _outward_flower_material: StandardMaterial3D

const GRASS_ATLAS_CELL_SIZE := 512
## P1-133 : duree du fondu d apparition d un bloc d herbe ou de pelouse.
const CHUNK_APPEAR_SEC := 0.9
const ECOLOGY_CATALOG_PATH := "res://assets/grass/remaster/zone_ecology_catalog.json"
const LEGACY_MAX_HEIGHT_SCALE := 1.34
const MAX_HEIGHT_SCALE := LEGACY_MAX_HEIGHT_SCALE * 0.70
const NATIVE_SEED_GRID_RAW := 2048.0
## 2026-09-27 : eclaircissement des chunks lointains, adouci (1,35 / 2,0
## laissaient voir le sol pale entre les touffes a mi-distance).
## Niveaux de l option « Densite de l herbe » : rayon du tapis, espacement des
## chunks moyens et lointains. 0 = Bas (reglage d avant), 1 = Moyen, 2 = Eleve.
const DETAIL_LEVELS := [
	{"lawn_radius_raw": 3400.0, "lod2_spacing": 1.35, "lod1_spacing": 2.0},
	{"lawn_radius_raw": 5000.0, "lod2_spacing": 1.25, "lod1_spacing": 1.75},
	{"lawn_radius_raw": 6500.0, "lod2_spacing": 1.15, "lod1_spacing": 1.5},
]
var _lod2_spacing := 1.15
var _lod1_spacing := 1.5
var _detail_level := 2
const NATIVE_TREE_RADIUS_RAW := 1450.0
const NATIVE_PLANT_RADIUS_RAW := 900.0
const ZONE_SIZE_RAW := 65536.0
## Empreinte minimale (petit cote, unites DAoC) pour qu'un corps de collision de
## prop soit traite comme un BATIMENT qui interdit l'herbe. 1 m = 100 unites :
## une maison fait plusieurs metres, un poteau ou une barriere non.
const BUILDING_MIN_EXTENT_RAW := 150.0
## Marge rentree dans l'AABB : l'emprise d'une maison tournee de 45 degres est
## plus large que ses murs, on retire un peu pour ne pas raser le pied des murs
## voisins ; et l'herbe s'arrete NATURELLEMENT contre un mur.
const BUILDING_INSET_RAW := 12.0
## Un batiment dont le plancher est a plus de cette hauteur au-dessus du sol
## (pont, passerelle) ne cache pas l'herbe dessous.
const BUILDING_FLOOR_TOLERANCE_RAW := 200.0
## Delai de stabilite du compte de props avant de rebatir les chunks.
const BUILDING_REFRESH_SETTLE_MSEC := 1500

var _host: Node3D
## Empreintes de batiments retenues pour la zone, lues sur l'hote
## (`_prop_collision_runtime`, AABB DAoC des props a collision). Vide tant que
## les props ne sont pas batis : le compte est relu a chaque rafraichissement
## et les chunks sont rebatis quand il change.
var _building_footprints: Array[Dictionary] = []
var _building_footprint_source_count := -1
var _pending_footprint_count := -1
var _pending_footprint_since_msec := 0
var _zone_id := -1
var _origin := Vector3.ZERO
var _world_scale := 0.01
var _height_exaggeration := 1.0
var _height_bytes := PackedByteArray()
var _height_resolution := 256
var _grass_pixels := PackedByteArray()
var _grass_width := 0
var _grass_height := 0
var _original_grass_pixels := PackedByteArray()
var _original_grass_width := 0
var _original_grass_height := 0
var _dense_pixels := PackedByteArray()
var _dense_width := 0
var _dense_height := 0
var _client_root := ""
var _data_dir := ""
var _manifest: Dictionary = {}
var _mask_images: Dictionary = {}
var _detail_images: Dictionary = {}
var _detail_color_cache: Dictionary = {}
var _water_bands: Array[Dictionary] = []
var _water_margin_raw := 96.0
## Part des brins conservee sous l'eau : 0,1 = divise par dix.
var _underwater_keep_ratio := 0.1
## Largeur (unites DAoC, depuis la rive) de l'ourlet de joncs des lacs, rivieres
## et marais ; 0 le coupe. Il commence derriere `_water_margin_raw`.
var _shore_ring_raw := 340.0
var _shore_band_bounds_cache: Dictionary = {}
var _chunks: Dictionary = {}
## 2026-09-29 — RESERVE des blocs quittes. Retour utilisateur : « en partant de
## Ludlow je perds vite la vegetation ». Un bloc sorti de l anneau etait DETRUIT,
## et le retour (ou un aller-retour de zone) le recalculait (~0,5 s de calcul par
## bloc, etale a 16 ms par image : des dizaines de secondes de sol nu). Il est
## desormais masque et garde, puis reaffiche tel quel ; la reserve est bornee
## (les plus anciens sont liberes) et videe quand les emprises de batiments ou la
## densite changent, seuls cas ou un bloc garde serait faux.
const CHUNK_RESERVE_MAX := 96
var _chunk_reserve: Dictionary = {}
var _chunk_reserve_order: Array = []
var _lawn_reserve: Dictionary = {}
var _lawn_reserve_order: Array = []
## P1-119 — pelouse rase en couches, autour du joueur seulement.
var _lawn_enabled := true
var _lawn_radius_raw := 6500.0
var _lawn_grid_raw := 64.0
var _lawn_shells := 16
var _lawn_snow := false
var _lawn_chunks: Dictionary = {}
var _lawn_material: ShaderMaterial
var _last_player_chunk := Vector2i(-99999, -99999)
var _chunk_size_raw := 4096.0
var _spacing_raw := 60.0
var _fade_start_raw := 8500.0
var _fade_end_raw := 12000.0
var _density := 1.40
var _coverage_threshold := 0.10
var _max_instances_per_chunk := 5000
var _vertical_offset_raw := 3.0
var _card_width_raw := 64.0
var _card_height_raw := 70.0
var _wind_strength_raw := 30.0
var _wind_strength := 30.0
var _wind_speed := 1.35
var _wind_gust_strength := 0.72
var _grass_map_path := ""
var _strict_grassmap_authority := false
var _use_densemap := false
var _native_seed_enabled := true
var _autumn_groundcover_enabled := true
var _native_tree_radius_raw := NATIVE_TREE_RADIUS_RAW
var _native_plant_radius_raw := NATIVE_PLANT_RADIUS_RAW
var _meshes: Array[ArrayMesh] = []
var _material: ShaderMaterial
var _zone_ecology: Dictionary = {}
var _native_seed_grid: Dictionary = {}
var _native_seed_count := 0
var _report := {
	"mode": "Grass Remaster", "chunks": 0, "instances": 0,
	"vegetal_samples": 0, "rejected_non_vegetal": 0, "rejected_water": 0,
	"semantic_samples": 0, "native_fallback_samples": 0,
	"explicit_alt_override_samples": 0,
	"source": "explicit grassmap + TerrainTex layer weights",
}


func configure(host: Node3D, zone_id: int, origin: Vector3,
		height_bytes: PackedByteArray, height_resolution: int,
		grass_data: Dictionary, dense_data: Dictionary,
		water_bands: Array[Dictionary], settings: Dictionary) -> void:
	_outward_rocks_enabled = bool(settings.get("outward_rocks_enabled", false))
	_outward_flowers_enabled = bool(settings.get("outward_flowers_enabled", false))
	add_to_group("daoc_grass_runtime")
	_host = host
	_zone_id = zone_id
	_origin = origin
	_height_bytes = height_bytes
	_height_resolution = height_resolution
	_world_scale = float(settings.get("world_scale", 0.01))
	_height_exaggeration = float(settings.get("height_exaggeration", 1.0))
	_client_root = str(settings.get("client_root", "")).replace("\\", "/").trim_suffix("/")
	_data_dir = str(settings.get("data_dir", "")).replace("\\", "/").trim_suffix("/")
	_water_bands = water_bands
	_water_margin_raw = maxf(0.0, float(settings.get("water_margin_raw", 96.0)))
	_underwater_keep_ratio = clampf(float(settings.get("underwater_keep_ratio", 0.1)), 0.0, 1.0)
	_shore_ring_raw = maxf(0.0, float(settings.get("shore_ring_raw", 340.0)))
	_shore_band_bounds_cache.clear()
	_water_bounds_cache.clear()
	_chunk_size_raw = maxf(1024.0, float(settings.get("chunk_size_raw", 4096.0)))
	_spacing_raw = maxf(45.0, float(settings.get("spacing_raw", 60.0)))
	_fade_start_raw = maxf(1000.0, float(settings.get("fade_start_raw", 8500.0)))
	_fade_end_raw = maxf(_fade_start_raw + 500.0, float(settings.get("fade_end_raw", 12000.0)))
	_density = maxf(0.0, float(settings.get("density", 1.40)))
	_coverage_threshold = clampf(float(settings.get("coverage_threshold", 0.10)), 0.0, 1.0)
	_max_instances_per_chunk = maxi(64, int(settings.get("max_instances_per_chunk", 5000)))
	_vertical_offset_raw = float(settings.get("vertical_offset_raw", 3.0))
	_card_width_raw = maxf(8.0, float(settings.get("card_width_raw", 64.0)))
	_card_height_raw = maxf(8.0, float(settings.get("card_height_raw", 70.0)))
	_wind_strength_raw = maxf(0.0, float(settings.get("wind_strength", 30.0)))
	# Le shader travaille en unites Godot, tandis que l'inspecteur et les cartes
	# DAoC utilisent les unites brutes. Sans cette conversion, un brin haut de 60
	# ne bougeait que de 0,58 et paraissait statique dans ZoneViewer.
	_wind_strength = _wind_strength_raw * _world_scale
	_wind_speed = maxf(0.0, float(settings.get("wind_speed", 1.35)))
	_wind_gust_strength = clampf(float(settings.get("wind_gust_strength", 0.72)), 0.0, 1.0)
	_grass_map_path = str(settings.get("grass_map_path", ""))
	_strict_grassmap_authority = bool(settings.get("strict_grassmap_authority", false))
	_use_densemap = bool(settings.get("use_densemap", false))
	_native_seed_enabled = bool(settings.get("native_seed_enabled", true))
	_autumn_groundcover_enabled = bool(settings.get("autumn_groundcover_enabled", true))
	_native_tree_radius_raw = maxf(0.0, float(settings.get("native_tree_radius_raw", NATIVE_TREE_RADIUS_RAW)))
	_native_plant_radius_raw = maxf(0.0, float(settings.get("native_plant_radius_raw", NATIVE_PLANT_RADIUS_RAW)))
	_lawn_enabled = bool(settings.get("lawn_enabled", true))
	_lawn_radius_raw = maxf(500.0, float(settings.get("lawn_radius_raw", 6500.0)))
	_lawn_shells = clampi(int(settings.get("lawn_shells", 16)), 2, 32)
	_lawn_snow = bool(settings.get("lawn_snow_midgard", true)) and DaocZoneEnvironmentProfile.realm_id_for_zone(zone_id) == 2
	_apply_detail_level(int(settings.get("grass_detail_level", 2)), false)
	_report["original_densemap_diagnostic"] = settings.get("original_densemap_diagnostic", {})
	_report["alternative_difference"] = settings.get("alternative_difference", {})
	_grass_pixels = grass_data.get("luminance_pixels",
		grass_data.get("pixels", PackedByteArray())) as PackedByteArray
	_grass_width = int(grass_data.get("width", 0))
	_grass_height = int(grass_data.get("height", 0))
	var original_grass_data := settings.get("original_grass_data", {}) as Dictionary
	_original_grass_pixels = original_grass_data.get("luminance_pixels",
		original_grass_data.get("pixels", PackedByteArray())) as PackedByteArray
	_original_grass_width = int(original_grass_data.get("width", 0))
	_original_grass_height = int(original_grass_data.get("height", 0))
	_dense_pixels = dense_data.get("luminance_pixels",
		dense_data.get("pixels", PackedByteArray())) as PackedByteArray
	_dense_width = int(dense_data.get("width", 0))
	_dense_height = int(dense_data.get("height", 0))
	# 2026-09-27 : une grassmap DAoC n utilise pas toute l echelle (zone 0 : 0..100).
	# Divisee par 255, une valeur 10 ou 20 (« un peu d herbe ») passait sous le
	# seuil de 10 % et laissait la terre tachetee de touffes isolees. On la ramene
	# a son propre maximum, comme le chemin Vanilla le faisait deja (grass_max).
	if bool(settings.get("normalize_grassmap", true)):
		var grass_max := maxi(int(grass_data.get("max_luminance", 255)), int(original_grass_data.get("max_luminance", 0)))
		_grass_pixels = _normalized(_grass_pixels, grass_max)
		_original_grass_pixels = _normalized(_original_grass_pixels, grass_max)
		_report["grassmap_normalized_from"] = grass_max
	if bool(settings.get("grass_fill_enabled", true)):
		_load_fill_map()
	_load_manifest()
	_load_zone_ecology()
	_load_native_vegetation_seeds()
	_meshes = [_make_grass_mesh(1), _make_grass_mesh(2), _make_grass_mesh(3)]
	_material = _make_grass_material()
	add_to_group("daoc_vegetation")
	add_to_group("daoc_grass_remaster")
	set_process(true)
	call_deferred("_initial_refresh")


## Zone du joueur : pose complète tout de suite (chargement). Zone voisine
## préchargée : en file, pour ne pas figer le joueur qui marche encore.
## 2026-09-30 — au chargement, seuls les chunks PROCHES (~3x3) sont batis dans
## la meme image ; le reste de l anneau part dans la file budgetee. Mesure DOL
## local zone 8 : l anneau complet coutait 22,7 s de premiere image.
## Les outils et suites qui appellent `_refresh_chunks(true)` gardent tout.
var _force_sync_radius_raw := INF


func _initial_refresh() -> void:
	var focus := _player_local_raw()
	var inside := focus.x >= 0.0 and focus.y >= 0.0 and focus.x < ZONE_SIZE_RAW and focus.y < ZONE_SIZE_RAW
	_force_sync_radius_raw = _chunk_size_raw * 1.5
	_refresh_chunks(inside)
	_force_sync_radius_raw = INF


func _process(_delta: float) -> void:
	_refresh_chunks(false)
	_pump_build_queue()


## ═══════════════════════════════════════════════════════════════════════════
## 2026-09-27 — OPTIMISATION. Le franchissement d un chunk rebâtissait tout
## l anneau manquant dans la même image : 3 à 6 s de gel à chaque pas (log du
## 27/09, zone 1, jusqu à 120 000 brins). Hors reconstruction forcée
## (chargement, outils, suites), les chunks entrent dans une FILE, du plus
## proche au plus lointain, bâtis par tranches de `_build_budget_usec` par
## image. Un chunk à densifier garde l ancien jusqu à ce que le neuf soit prêt.
## ═══════════════════════════════════════════════════════════════════════════
var _build_budget_usec := 6000
var _build_budget_urgent_usec := 16000
var _build_queue: Array = []
var _active_job: Dictionary = {}
var _wanted_grass: Dictionary = {}
var _wanted_lawn: Dictionary = {}


func _enqueue_build(kind: String, cx: int, cy: int, lod: int, distance: float) -> void:
	var key := "%s:%d,%d" % [kind, cx, cy]
	if not _worker_job.is_empty() and str(_worker_job.get("qkey", "")) == key \
			and int(_worker_job.get("lod", 0)) >= lod:
		return
	if not _active_job.is_empty() and str(_active_job.get("qkey", "")) == key \
			and int(_active_job.get("lod", 0)) >= lod:
		return
	for entry in _build_queue:
		if str(entry["qkey"]) == key:
			entry["lod"] = maxi(int(entry["lod"]), lod)
			entry["distance"] = distance
			return
	_build_queue.append({"qkey": key, "kind": kind, "cx": cx, "cy": cy, "lod": lod, "distance": distance})


func _pump_build_queue() -> void:
	if threaded_build:
		_pump_threaded()
		return
	if _build_queue.is_empty() and _active_job.is_empty():
		return
	# P1-134 : un bloc que le joueur a deja quitte n est plus construit jusqu au
	# bout pour etre jete ; et tant qu un bloc PROCHE manque (le joueur court
	# plus vite que la file), le budget passe de 6 a 16 ms par image — sinon
	# l anneau se vidait en foret dense et ne se remplissait jamais.
	if not _active_job.is_empty():
		var active_key := "%d,%d" % [int(_active_job["cx"]), int(_active_job["cy"])]
		if not (_wanted_lawn if str(_active_job["kind"]) == "lawn" else _wanted_grass).has(active_key):
			_active_job = {}
	var budget := _build_budget_usec
	if _near_chunk_missing():
		budget = maxi(budget, _build_budget_urgent_usec)
	var deadline := Time.get_ticks_usec() + budget
	var finished_any := false
	while Time.get_ticks_usec() < deadline:
		if _active_job.is_empty():
			if _build_queue.is_empty():
				break
			var entry: Dictionary = _build_queue.pop_front()
			var key := "%d,%d" % [int(entry["cx"]), int(entry["cy"])]
			var wanted := _wanted_lawn if str(entry["kind"]) == "lawn" else _wanted_grass
			if not wanted.has(key):
				continue
			if str(entry["kind"]) == "lawn":
				_active_job = _lawn_job_begin(int(entry["cx"]), int(entry["cy"]))
			else:
				_active_job = _chunk_job_begin(int(entry["cx"]), int(entry["cy"]), int(entry["lod"]))
			_active_job["qkey"] = entry["qkey"]
			_active_job["distance"] = entry["distance"]
		var done := _lawn_job_step(_active_job, deadline) if str(_active_job["kind"]) == "lawn" \
			else _chunk_job_step(_active_job, deadline)
		if not done:
			break
		_install_job(_active_job)
		_active_job = {}
		finished_any = true
	if finished_any:
		_recount_report()


func _install_job(job: Dictionary) -> void:
	var key := "%d,%d" % [int(job["cx"]), int(job["cy"])]
	var is_lawn := str(job["kind"]) == "lawn"
	var wanted := _wanted_lawn if is_lawn else _wanted_grass
	if not wanted.has(key):
		return
	var store := _lawn_chunks if is_lawn else _chunks
	var node: MultiMeshInstance3D = _lawn_job_finish(job) if is_lawn else _chunk_job_finish(job)
	var old := store.get(key, null) as Node
	store.erase(key)
	if is_lawn:
		_lawn_chunks[key] = node
	elif node != null:
		_chunks[key] = node
	if node != null:
		add_child(node)
	# P1-133 — plus de pop : le bloc neuf apparait en fondu trame, et celui qu'il
	# remplace (changement de LOD) reste affiche le temps du fondu.
	var fade_sec := CHUNK_APPEAR_SEC if is_inside_tree() else 0.0
	if node != null and fade_sec > 0.0:
		node.set_instance_shader_parameter("appear", 0.0)
		var tween := node.create_tween()
		tween.tween_method(func(v: float):
			if is_instance_valid(node):
				node.set_instance_shader_parameter("appear", v), 0.0, 1.0, fade_sec)
	if old != null and is_instance_valid(old):
		if fade_sec > 0.0 and node != null:
			get_tree().create_timer(fade_sec).timeout.connect(func():
				if is_instance_valid(old):
					old.queue_free())
		else:
			old.queue_free()


func debug_snapshot() -> Dictionary:
	var out := _report.duplicate(true)
	out["active_chunk_keys"] = _chunks.keys()
	out["mask_images_cached"] = _mask_images.size()
	out["detail_images_cached"] = _detail_images.size()
	out["detail_colors_cached"] = _detail_color_cache.size()
	out["texture_paths"] = Array(GRASS_TEXTURE_PATHS)
	out["outward_rocks_enabled"] = _outward_rocks_enabled
	out["outward_rock_count"] = find_children("OutwardRock*", "MeshInstance3D", true, false).size()
	out["outward_flowers_enabled"] = _outward_flowers_enabled
	out["outward_flower_count"] = find_children("OutwardFlowers*", "MultiMeshInstance3D", true, false).reduce(
		func(total: int, flower_node: Node) -> int:
			var mm_node := flower_node as MultiMeshInstance3D
			return total + (mm_node.multimesh.instance_count if mm_node != null and mm_node.multimesh != null else 0), 0)
	out["texture_variants"] = GRASS_TEXTURE_PATHS.size()
	out["texture_resource_exists"] = _all_grass_textures_exist()
	out["texture_cutouts_valid"] = _all_grass_textures_have_cutout()
	out["zone_ecology"] = _zone_ecology.duplicate(true)
	out["fade_start_raw"] = _fade_start_raw
	out["fade_end_raw"] = _fade_end_raw
	out["chunk_size_raw"] = _chunk_size_raw
	out["spacing_raw"] = _spacing_raw
	out["wind_strength"] = _wind_strength
	out["wind_strength_raw"] = _wind_strength_raw
	out["wind_speed"] = _wind_speed
	out["wind_gust_strength"] = _wind_gust_strength
	out["wind_model"] = "vertex_tip_sway_two_frequencies_with_gusts"
	out["grass_map_path"] = _grass_map_path
	out["strict_grassmap_authority"] = _strict_grassmap_authority
	out["min_height_scale"] = 0.72
	out["max_height_scale"] = MAX_HEIGHT_SCALE
	out["native_seed_count"] = _native_seed_count
	out["native_seed_enabled"] = _native_seed_enabled and not _strict_grassmap_authority and _native_seed_count > 0
	out["native_tree_radius_raw"] = _native_tree_radius_raw
	out["native_plant_radius_raw"] = _native_plant_radius_raw
	out["native_seed_model"] = "deterministic_fixture_radius+terrain_guard+water_guard"
	out["densemap_used"] = _use_densemap
	out["water_filter"] = "exact_DAoC_quads"
	out["water_margin_raw"] = _water_margin_raw
	out["underwater_keep_ratio"] = _underwater_keep_ratio
	out["shore_ring_raw"] = _shore_ring_raw
	out["shore_samples"] = int(_report.get("shore_samples", 0))
	out["underwater_samples"] = int(_report.get("underwater_samples", 0))
	out["rejected_underwater"] = int(_report.get("rejected_underwater", 0))
	out["geometry_lod"] = "chunk_3_2_1"
	out["building_filter"] = "prop_collision_aabb_min_extent_%d" % int(BUILDING_MIN_EXTENT_RAW)
	out["building_footprints"] = _building_footprints.size()
	out["rejected_building"] = int(_report.get("rejected_building", 0))
	return out


func debug_first_explicit_alt_position() -> Vector3:
	for node_value in _chunks.values():
		var node := node_value as MultiMeshInstance3D
		if node != null and int(node.get_meta("explicit_alt_override_instances", 0)) > 0:
			return node.get_meta("first_explicit_alt_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _refresh_chunks(force: bool) -> void:
	if _host == null or _meshes.is_empty() or _material == null:
		return
	_drain_worker()
	var focus := _player_local_raw()
	var player_chunk := Vector2i(floori(focus.x / _chunk_size_raw), floori(focus.y / _chunk_size_raw))
	# Les props (donc les batiments) peuvent etre batis APRES la vegetation ou
	# rebatis par un rechargement de zone : quand leur compte change, les chunks
	# deja poses portent de l'herbe sous des maisons et sont rebatis.
	if _refresh_building_footprints():
		_clear_reserves()
		if _chunks.is_empty() or force:
			for old_value in _chunks.values():
				var old_chunk := old_value as Node
				if old_chunk != null:
					old_chunk.queue_free()
			_chunks.clear()
			force = true
		else:
			# Rebâtis en file : l ancien reste affiché jusqu au remplacement.
			for key_value in _chunks.keys():
				var parts := str(key_value).split(",")
				var node := _chunks[key_value] as Node
				var lod := int(node.get_meta("spacing_lod", 1)) if node != null else 1
				_enqueue_build("grass", int(parts[0]), int(parts[1]), lod, 0.0)
			_last_player_chunk = Vector2i(-99999, -99999)
	if not force and player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk
	if force:
		_build_queue.clear()
		_active_job = {}
	var refresh_started := Time.get_ticks_msec()
	print("GRASS_REMASTER_BUILD_BEGIN zone=%d focus=%s" % [_zone_id, str(focus)])
	var ring := ceili(_fade_end_raw / _chunk_size_raw) + 1
	var wanted: Dictionary = {}
	for cy in range(player_chunk.y - ring, player_chunk.y + ring + 1):
		for cx in range(player_chunk.x - ring, player_chunk.x + ring + 1):
			if cx < 0 or cy < 0 or float(cx) * _chunk_size_raw >= ZONE_SIZE_RAW or float(cy) * _chunk_size_raw >= ZONE_SIZE_RAW:
				continue
			var center := Vector2((float(cx) + 0.5) * _chunk_size_raw, (float(cy) + 0.5) * _chunk_size_raw)
			var distance := center.distance_to(focus)
			if distance > _fade_end_raw + _chunk_size_raw * 0.72:
				continue
			var key := "%d,%d" % [cx, cy]
			wanted[key] = true
			var lod_clusters := _clusters_for_distance(distance)
			if not _chunks.has(key) and not force:
				var kept := _reserve_take(_chunk_reserve, _chunk_reserve_order, key)
				if kept != null:
					_chunks[key] = kept
			if not _chunks.has(key):
				if force and distance <= _force_sync_radius_raw:
					var chunk := _build_chunk(cx, cy, lod_clusters)
					if chunk != null:
						_chunks[key] = chunk
						add_child(chunk)
				else:
					_enqueue_build("grass", cx, cy, lod_clusters, distance)
			else:
				var existing := _chunks[key] as MultiMeshInstance3D
				if existing != null and existing.multimesh != null:
					var built_lod := int(existing.get_meta("spacing_lod", existing.get_meta("lod_clusters", 0)))
					if lod_clusters > built_lod:
						# 2026-09-27 : un chunk bati DE LOIN garde l espacement lache de
						# son LOD (x1,35 ou x2) ; changer seulement le maillage laissait
						# des trous a l approche. Il est rebati a la densite du plus proche
						# (en file : l ancien reste affiché en attendant).
						_enqueue_build("grass", cx, cy, lod_clusters, distance)
						_report["chunks_densified"] = int(_report.get("chunks_densified", 0)) + 1
					if lod_clusters != int(existing.get_meta("lod_clusters", 0)):
						existing.multimesh.mesh = _meshes[lod_clusters - 1]
						existing.set_meta("lod_clusters", lod_clusters)
	_wanted_grass = wanted
	_refresh_lawn(focus, force)
	_build_queue = _build_queue.filter(func(entry: Dictionary) -> bool:
		var k := "%d,%d" % [int(entry["cx"]), int(entry["cy"])]
		return (_wanted_lawn if str(entry["kind"]) == "lawn" else _wanted_grass).has(k))
	_build_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"]))
	for key_value in _chunks.keys():
		var key := str(key_value)
		if wanted.has(key):
			continue
		var old := _chunks[key] as Node
		_chunks.erase(key)
		if old != null:
			_reserve_put(_chunk_reserve, _chunk_reserve_order, key, old)
	_recount_report()
	print("GRASS_REMASTER_BUILD_END zone=%d chunks=%d instances=%d ms=%d" % [
		_zone_id, int(_report.get("chunks", 0)), int(_report.get("instances", 0)),
		Time.get_ticks_msec() - refresh_started,
	])
	if int(_report.get("chunks", 0)) == 0:
		print("GRASS_REMASTER_EMPTY=%s" % JSON.stringify({
			"zone": _zone_id,
			"focus": focus,
			"strict_alt": _strict_grassmap_authority,
			"manifest": str(_report.get("manifest_path", "")),
			"terrain_details": _report.get("terrain_details", []),
			"vegetal_samples": int(_report.get("vegetal_samples", 0)),
			"rejected_non_vegetal": int(_report.get("rejected_non_vegetal", 0)),
			"rejected_water": int(_report.get("rejected_water", 0)),
			"rejected_underwater": int(_report.get("rejected_underwater", 0)),
			"rejected_building": int(_report.get("rejected_building", 0)),
		}))


## Outils de releve : un point de vue force (coordonnees de zone), INF = le joueur.
var _player_override := Vector2.INF


func _player_local_raw() -> Vector2:
	if _player_override != Vector2.INF:
		return _player_override
	# R10 — un hôte absent rend le centre de zone, comme un joueur absent. Le
	# Remaster est bâti par un module qui peut être configuré par DONNÉES, sans
	# hôte : sans cette garde, l'appel plantait au lieu de dégrader.
	if _host == null:
		return Vector2(ZONE_SIZE_RAW * 0.5, ZONE_SIZE_RAW * 0.5)
	var player: Node3D = _host.get("_player") as Node3D
	if player == null:
		return Vector2(ZONE_SIZE_RAW * 0.5, ZONE_SIZE_RAW * 0.5)
	return Vector2(
		(player.global_position.x - _origin.x) / _world_scale,
		(player.global_position.z - _origin.z) / _world_scale
	)


func _clusters_for_distance(distance_raw: float) -> int:
	# LOD geometrique par chunk, selon une recette courante des mondes ouverts :
	# silhouette riche pres du joueur, puis reduction du nombre de cartes avant
	# le fondu trame. Le MultiMesh et son animation au vent restent identiques.
	var near_end := maxf(3000.0, _fade_start_raw * 0.40)
	var medium_end := maxf(6000.0, _fade_start_raw * 0.75)
	if distance_raw <= near_end:
		return 3
	if distance_raw <= medium_end:
		return 2
	return 1


func _build_chunk(chunk_x: int, chunk_y: int, lod_clusters: int) -> MultiMeshInstance3D:
	var job := _chunk_job_begin(chunk_x, chunk_y, lod_clusters)
	_chunk_job_step(job, -1)
	return _chunk_job_finish(job)


## 2026-09-27 (optimisation) : un chunk se bâtit par TRANCHES. Bâtir un anneau
## d un coup figeait le jeu 3 à 6 s à chaque chunk franchi (log du 27/09).
## `_chunk_job_step` avance jusqu à l échéance (µs, -1 = jusqu au bout) ; le
## résultat est le même, tirage pour tirage, qu en une fois.
func _chunk_job_begin(chunk_x: int, chunk_y: int, lod_clusters: int) -> Dictionary:
	# Densite concentree la ou elle compte visuellement. Les chunks lointains
	# echantillonnent moins de cellules au lieu de payer le meme tapis que le
	# premier plan, recette classique des terrains modernes instancies.
	var lod_spacing_multiplier := 1.0
	if lod_clusters == 2:
		lod_spacing_multiplier = _lod2_spacing
	elif lod_clusters == 1:
		lod_spacing_multiplier = _lod1_spacing
	var local_spacing := _spacing_raw * lod_spacing_multiplier
	var cells := maxi(1, ceili(_chunk_size_raw / local_spacing))
	return {
		"kind": "grass", "cx": chunk_x, "cy": chunk_y, "lod": lod_clusters,
		"cells": cells, "cell_size": _chunk_size_raw / float(cells),
		"start_x": float(chunk_x) * _chunk_size_raw, "start_y": float(chunk_y) * _chunk_size_raw,
		"gx": 0, "gy": 0, "count": 0, "buffer": PackedFloat32Array(),
		"alt": 0, "alt_pos": Vector3.ZERO,
	}


func _chunk_job_step(job: Dictionary, deadline_usec: int) -> bool:
	var cells := int(job["cells"])
	var gx := int(job["gx"])
	var gy := int(job["gy"])
	var tick := 0
	while gy < cells:
		# 2026-09-27 : le plafond arrete AUSSI la boucle des rangees.
		if int(job["count"]) >= _max_instances_per_chunk:
			gy = cells
			break
		_sample_grass_cell(job, gx, gy)
		gx += 1
		if gx >= cells:
			gx = 0
			gy += 1
		tick += 1
		if deadline_usec >= 0 and (tick & 7) == 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	job["gx"] = gx
	job["gy"] = gy
	return gy >= cells


func _chunk_job_finish(job: Dictionary) -> MultiMeshInstance3D:
	var count := int(job["count"])
	if count <= 0:
		return null
	var chunk_x := int(job["cx"])
	var chunk_y := int(job["cy"])
	var lod_clusters := int(job["lod"])
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _meshes[clampi(lod_clusters, 1, 3) - 1]
	multimesh.instance_count = count
	multimesh.buffer = job["buffer"] as PackedFloat32Array
	var instance := MultiMeshInstance3D.new()
	instance.name = "GrassRemaster_%02d_%02d" % [chunk_x, chunk_y]
	instance.multimesh = multimesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = maxf(2.0, _wind_strength * 1.6)
	instance.visibility_range_end = (_fade_end_raw + _chunk_size_raw) * _world_scale
	instance.set_meta("daoc_grass_remaster", true)
	instance.add_to_group("daoc_grass_remaster_chunk")
	instance.set_meta("chunk", Vector2i(chunk_x, chunk_y))
	instance.set_meta("instances", count)
	instance.set_meta("lod_clusters", lod_clusters)
	instance.set_meta("spacing_lod", lod_clusters)
	instance.set_meta("explicit_alt_override_instances", int(job["alt"]))
	instance.set_meta("first_explicit_alt_position", job["alt_pos"])
	_populate_outward_rocks(instance)
	_populate_outward_flowers(instance)
	return instance


func _sample_grass_cell(job: Dictionary, gx: int, gy: int) -> void:
			# Tache de fond : compteurs PROPRES a la tache, fusionnes a l installation.
			var rep: Dictionary = job.get("report", _report) as Dictionary
			var chunk_x: int = job["cx"]
			var chunk_y: int = job["cy"]
			var cell_size: float = job["cell_size"]
			var start_x: float = job["start_x"]
			var start_y: float = job["start_y"]
			var seed_x := chunk_x * 1009 + gx
			var seed_y := chunk_y * 1013 + gy
			var wx := start_x + (float(gx) + lerpf(0.12, 0.88, _stable_rand01(_zone_id + 11, seed_x, seed_y))) * cell_size
			var wy := start_y + (float(gy) + lerpf(0.12, 0.88, _stable_rand01(_zone_id + 19, seed_y, seed_x))) * cell_size
			var ground := _sample_ground_material(wx, wy)
			var native_map_weight := _sample_byte_map(_grass_pixels, _grass_width, _grass_height, wx, wy)
			var original_map_weight := _sample_byte_map(_original_grass_pixels,
				_original_grass_width, _original_grass_height, wx, wy)
			var native_dense := _sample_byte_map(_dense_pixels, _dense_width, _dense_height, wx, wy)
			var semantic_coverage := float(ground.get("semantic_vegetal", 0.0))
			var native_seed := _native_seed_influence(wx, wy) \
				if _native_seed_enabled and not _strict_grassmap_authority else {}
			if not native_seed.is_empty():
				ground["native_seed_habitat"] = str(native_seed.get("habitat", ""))
			# Comme Unity Detail Layers / Unreal Landscape Grass, une carte explicite
			# est l'autorite. La couleur du terrain n'intervient jamais dans le
			# placement. Sans ALT, les poids de couches vegetales completent l'original.
			var coverage := native_map_weight if _strict_grassmap_authority \
				else maxf(native_map_weight, semantic_coverage)
			# Les fixtures vegetales du client servent de graines, surtout lorsqu'une
			# vieille grassmap est parcimonieuse. Leur influence ne passe cependant
			# que sur un sol compatible ; routes, pierre, boue, eau et carte ALT stricte
			# restent pleinement autoritaires.
			var native_seed_coverage := 0.0
			if not native_seed.is_empty():
				native_seed_coverage = float(native_seed.get("strength", 0.0)) \
					* _native_seed_ground_compatibility(ground)
				coverage = maxf(coverage, native_seed_coverage)
			# Une grassmapALT est une retouche volontaire de l'auteur, pas une simple
			# texture de densite. Tout pixel eclairci par rapport a la grassmap native
			# demande donc un tapis plein. Cela conserve les bords doux du pinceau sans
			# laisser les tons intermediaires presque vides.
			var explicit_alt_override := _strict_grassmap_authority \
				and not _original_grass_pixels.is_empty() \
				and native_map_weight > original_map_weight + (0.5 / 255.0)
			if explicit_alt_override:
				coverage = 1.0
			# 2026-09-27 : la carte de remplissage du projet (data/gameplay/grass_fill)
			# comble les sols verts que ni la grassmap ni le classement des textures
			# ne couvrent ; elle vaut autorite, comme une retouche ALT.
			var fill := _sample_byte_map(_fill_pixels, _fill_resolution, _fill_resolution, wx, wy)
			if fill > coverage:
				coverage = fill
				rep["fill_samples"] = int(rep.get("fill_samples", 0)) + 1
			if coverage < _coverage_threshold:
				rep["rejected_non_vegetal"] = int(rep["rejected_non_vegetal"]) + 1
				return
			var dense_boost := lerpf(0.55, 1.0, native_dense) if _use_densemap else 1.0
			# Une fois la matiere jugee vegetale, on vise un tapis moderne et non des
			# ilots clairsemes. Coverage module encore la densite, mais ne la remet
			# plus presque a zero sur les zones de transition entre deux splats.
			var density_scale := _density / 1.40
			var chance := clampf(lerpf(0.82, 1.0, coverage) * density_scale
				* dense_boost, 0.0, 1.0)
			# 2026-09-19 : ourlet d'herbes de berge autour des lacs, rivieres et
			# marais. La surface d'eau s'arrete sur une ligne brisee ; un rideau
			# de joncs et d'herbes hautes serres contre la rive la cache. L'ocean
			# n'en recoit pas : sa plage porte l'ecume. La proximite n'est
			# calculee que si le tirage ordinaire a echoue (elle parcourt les
			# bandes d'eau) ou pour grandir les brins retenus pres de la rive.
			var roll := _stable_rand01(_zone_id + 29, seed_x, seed_y)
			var shore := 0.0
			if roll > chance:
				shore = _shore_proximity(wx, wy)
				if shore <= 0.0 or roll > lerpf(0.55, 1.0, shore) * density_scale:
					return
			if _inside_water(wx, wy):
				rep["rejected_water"] = int(rep["rejected_water"]) + 1
				return
			if shore <= 0.0 and _shore_ring_raw > 0.0:
				shore = _shore_proximity(wx, wy)
			var floor_raw := _sample_floor(wx, wy)
			# 2026-09-19 : pas d'herbe sous les batiments. Un brin sous un
			# plancher est invisible et coute autant qu'un brin visible.
			if _under_building(wx, wy, floor_raw):
				rep["rejected_building"] = int(rep.get("rejected_building", 0)) + 1
				return
			# 2026-09-15 : les bandes ne couvrent pas les plans d'eau par HAUTEUR
			# (lacs, ocean) ; un sol sous la surface d'eau du runtime garde un brin
			# sur dix, pour ne pas tapisser le fond des lacs d'herbe.
			if _underwater(wx, wy, floor_raw):
				rep["underwater_samples"] = int(rep.get("underwater_samples", 0)) + 1
				if _stable_rand01(_zone_id + 41, seed_x, seed_y) > _underwater_keep_ratio:
					rep["rejected_underwater"] = int(rep.get("rejected_underwater", 0)) + 1
					return
			var yaw := _stable_rand01(_zone_id + 31, seed_x, seed_y) * TAU
			var width_scale := lerpf(0.72, 1.24, _stable_rand01(_zone_id + 37, seed_x, seed_y))
			# Le retour visuel montre que seules les pousses situees au sommet de
			# l'ancienne variation sont trop grandes. On conserve donc toutes les
			# petites tailles et on plafonne la valeur haute 30 % sous son ancien max,
			# au lieu d'appliquer une reduction uniforme a chaque brin.
			var legacy_height_scale := lerpf(0.72, LEGACY_MAX_HEIGHT_SCALE,
				_stable_rand01(_zone_id + 41, seed_y, seed_x))
			var height_scale := minf(legacy_height_scale, MAX_HEIGHT_SCALE)
			var tint: Color = ground.get("tint", Color.WHITE) as Color
			if shore > 0.0:
				# Joncs : plus hauts et plus serres vers la rive, teinte d'herbe
				# grasse et humide.
				height_scale *= 1.0 + shore * 0.55
				width_scale *= 1.0 + shore * 0.15
				tint = tint.lerp(Color(0.62, 0.78, 0.42), shore * 0.45)
				rep["shore_samples"] = int(rep.get("shore_samples", 0)) + 1
				if shore > 0.35:
					ground["native_seed_habitat"] = "wetland"
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
			var pos := _origin + Vector3(wx * _world_scale,
				(floor_raw * _height_exaggeration + _vertical_offset_raw) * _world_scale,
				wy * _world_scale)
			# Tampon MultiMesh direct (12 flottants de transformation, 4 de couleur,
			# 4 de donnees) : bien moins cher que trois set_instance_* par brin.
			var t := Transform3D(basis, pos)
			var buffer: PackedFloat32Array = job["buffer"]
			var grass_variant := _select_grass_variant(ground, wx, wy, seed_x, seed_y)
			buffer.append_array([
				t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x,
				t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
				t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z,
				tint.r, tint.g, tint.b, tint.a,
				_stable_rand01(_zone_id + 43, seed_x, seed_y),
				_stable_rand01(_zone_id + 47, seed_y, seed_x),
				_stable_rand01(_zone_id + 53, seed_x, seed_y),
				(float(grass_variant) + 0.5) / float(GRASS_TEXTURE_PATHS.size())])
			job["buffer"] = buffer
			job["count"] = int(job["count"]) + 1
			if not _strict_grassmap_authority and semantic_coverage > native_map_weight:
				rep["semantic_samples"] = int(rep["semantic_samples"]) + 1
			else:
				rep["native_fallback_samples"] = int(rep["native_fallback_samples"]) + 1
			if native_seed_coverage > maxf(native_map_weight, semantic_coverage):
				rep["native_seed_samples"] = int(rep.get("native_seed_samples", 0)) + 1
			if explicit_alt_override:
				job["alt"] = int(job["alt"]) + 1
				if job["alt_pos"] == Vector3.ZERO:
					job["alt_pos"] = pos
			rep["vegetal_samples"] = int(rep["vegetal_samples"]) + 1


func _sample_ground_material(wx: float, wy: float) -> Dictionary:
	var details: Array = _manifest.get("details", []) as Array
	var patches: Dictionary = _manifest.get("patches", {}) as Dictionary
	if details.is_empty() or patches.is_empty():
		var legacy := _sample_byte_map(_grass_pixels, _grass_width, _grass_height, wx, wy)
		return {"vegetal": legacy, "semantic_vegetal": legacy,
			"tint": Color(0.72, 0.82, 0.62), "ground_texture": ""}
	var sx := clampi(floori(wx / (ZONE_SIZE_RAW / 8.0)), 0, 7)
	var sy := clampi(floori(wy / (ZONE_SIZE_RAW / 8.0)), 0, 7)
	var layers: Array = patches.get("%d,%d" % [sx, sy], []) as Array
	if layers.is_empty():
		return {"vegetal": 0.0, "semantic_vegetal": 0.0, "tint": Color.WHITE}
	var local_u := fposmod(wx, ZONE_SIZE_RAW / 8.0) / (ZONE_SIZE_RAW / 8.0)
	var local_v := fposmod(wy, ZONE_SIZE_RAW / 8.0) / (ZONE_SIZE_RAW / 8.0)
	var first := layers[0] as Dictionary
	var first_name := _detail_name(details, int(first.get("tex", -1)))
	var dominant_name := first_name
	var first_tiles := float(first.get("tiles", 256.0))
	var coverage := 1.0 if _is_vegetal_cached(first_name, first_tiles) else 0.0
	var tint := _sample_detail_color(first_name, first_tiles, wx, wy)
	for layer_index in range(1, layers.size()):
		var layer := layers[layer_index] as Dictionary
		var tiles := float(layer.get("tiles", 256.0))
		var weight := _sample_mask(int(layer.get("mask", -1)), int(layer.get("sub", 0)), local_u, local_v)
		if weight <= 0.001:
			continue
		var detail_name := _detail_name(details, int(layer.get("tex", -1)))
		if weight >= 0.45:
			dominant_name = detail_name
		# Une carte overall participe bien a la couleur finale du shader terrain,
		# mais pas a la semantique de matiere : elle ne doit pas transformer a elle
		# seule toute la zone en prairie.
		if tiles > 1.5:
			var layer_vegetal := 1.0 if _is_vegetal_cached(detail_name, tiles) else 0.0
			coverage = lerpf(coverage, layer_vegetal, weight)
		tint = tint.lerp(_sample_detail_color(detail_name, tiles, wx, wy), weight)
	return {"vegetal": coverage, "semantic_vegetal": coverage,
		"tint": _calibrated_tint(tint), "ground_texture": dominant_name}


func _select_grass_variant(ground: Dictionary, wx: float, wy: float,
		seed_x: int, seed_y: int) -> int:
	var name := str(ground.get("ground_texture", "")).to_lower()
	var native_seed_habitat := str(ground.get("native_seed_habitat", ""))
	var catalog_habitat := ""
	var catalog_habitats := _zone_ecology.get("habitats", []) as Array
	if not catalog_habitats.is_empty():
		catalog_habitat = str(catalog_habitats[0])
	# P1-134 : la famille ne depend que du nom et des habitats -> memoisee ;
	# la pente (cinq lectures de hauteur) n est calculee que si elle decide.
	var family_key := "%s|%s|%s" % [name, native_seed_habitat, catalog_habitat]
	var family: int = _variant_family_cache.get(family_key, -1)
	if family < 0:
		family = _variant_family(name, native_seed_habitat, catalog_habitat)
		_variant_family_cache[family_key] = family
	if family == 3:
		var height := _sample_floor(wx, wy)
		var probe := 160.0
		var dx := _sample_floor(minf(ZONE_SIZE_RAW, wx + probe), wy) - _sample_floor(maxf(0.0, wx - probe), wy)
		var dy := _sample_floor(wx, minf(ZONE_SIZE_RAW, wy + probe)) - _sample_floor(wx, maxf(0.0, wy - probe))
		var slope := atan(Vector2(dx, dy).length() / (probe * 2.0))
		if slope > deg_to_rad(24.0) or height > 46000.0:
			family = 2
	var pool: PackedInt32Array
	if family == 0:
		# P1-118 : sans vurt_brownplants (8), qui rendait des touffes brun-noir en berge.
		pool = PackedInt32Array([7, 15, 16, 17, 2])
	elif family == 1:
		pool = PackedInt32Array([4, 5, 6, 13, 15, 16]) if _autumn_groundcover_enabled else PackedInt32Array([4, 5, 13, 15, 16])
	elif family == 2:
		pool = PackedInt32Array([9, 10, 17, 18, 19, 20])
	else:
		pool = PackedInt32Array([0, 1, 2, 3, 11, 12, 13, 14, 20])
	var patch_x := floori(wx / 960.0)
	var patch_y := floori(wy / 960.0)
	var pick := floori(_stable_rand01(_zone_id + 67, patch_x, patch_y) * pool.size())
	if _stable_rand01(_zone_id + 71, seed_x, seed_y) < 0.20:
		pick = floori(_stable_rand01(_zone_id + 73, seed_y, seed_x) * pool.size())
	return pool[clampi(pick, 0, pool.size() - 1)]


func _contains_any(value: String, tokens: Array) -> bool:
	for token_value in tokens:
		if value.contains(str(token_value)):
			return true
	return false


func _load_zone_ecology() -> void:
	if not FileAccess.file_exists(ECOLOGY_CATALOG_PATH):
		return
	var file := FileAccess.open(ECOLOGY_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_zone_ecology = ((parsed as Dictionary).get("zones", {}) as Dictionary).get("%03d" % _zone_id, {}) as Dictionary


func _load_native_vegetation_seeds() -> void:
	_native_seed_grid.clear()
	_native_seed_cache.clear()
	_native_seed_count = 0
	var path := _data_dir.path_join("zone%03d_placement.json" % _zone_id)
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var placement := parsed as Dictionary
	var models := placement.get("models", {}) as Dictionary
	for fixture_value in placement.get("fixtures", []) as Array:
		if not fixture_value is Dictionary:
			continue
		var fixture := fixture_value as Dictionary
		var nif_id := str(int(fixture.get("nif", -1)))
		var model_name := str(models.get(nif_id, ""))
		var classification := _classify_native_seed(
			"%s %s" % [str(fixture.get("name", "")), model_name])
		if classification.is_empty():
			continue
		var x := float(fixture.get("x", -1.0))
		var y := float(fixture.get("y", -1.0))
		if x < 0.0 or y < 0.0 or x > ZONE_SIZE_RAW or y > ZONE_SIZE_RAW:
			continue
		var seed := {
			"id": int(fixture.get("id", _native_seed_count)),
			"position": Vector2(x, y),
			"habitat": str(classification.get("habitat", "forest")),
			"radius": float(classification.get("radius", NATIVE_TREE_RADIUS_RAW)),
		}
		var key := Vector2i(floori(x / NATIVE_SEED_GRID_RAW), floori(y / NATIVE_SEED_GRID_RAW))
		if not _native_seed_grid.has(key):
			_native_seed_grid[key] = []
		(_native_seed_grid[key] as Array).append(seed)
		_native_seed_count += 1


func _classify_native_seed(label: String) -> Dictionary:
	var value := label.to_lower().replace("-", "_")
	# Les arbres morts, portes et tours contenant accidentellement "tree" ne
	# doivent pas creer de sous-bois artificiel.
	if _contains_any(value, ["deadtree", "dead_tree", "bare1", "killdoor", "treetower", "dummy_tree"]):
		return {}
	if _contains_any(value, ["willow", "reed", "rush", "cattail"]):
		return {"habitat": "wetland", "radius": _native_tree_radius_raw}
	if _contains_any(value, ["tree", "pine", "elm", "oak", "holly", "beech", "ash", "birch", "shroom", "mushroom", "fern"]):
		return {"habitat": "forest", "radius": _native_tree_radius_raw}
	if _contains_any(value, ["grass", "flower", "plant", "bush", "shrub", "hedge"]):
		return {"habitat": "meadow", "radius": _native_plant_radius_raw}
	return {}


## P1-134 — mesure du 2026-09-29, zone 8 (Campacorentin, 2414 arbres) : 300 ms
## par bloc d herbe pour ce seul calcul, chaque brin parcourant tous les arbres
## d un carre de 6 km. En foret dense la file de construction ne rattrapait
## plus le joueur et l herbe disparaissait. L influence est un degrade sur
## ~1450 unites : elle est mise en cache par maille de 128, et un arbre trop
## loin est ecarte AVANT le tirage de son bruit.
const NATIVE_SEED_CACHE_RAW := 128.0
var _native_seed_cache: Dictionary = {}


func _native_seed_influence(wx: float, wy: float) -> Dictionary:
	if _native_seed_count <= 0:
		return {}
	var cache_key := Vector2i(floori(wx / NATIVE_SEED_CACHE_RAW), floori(wy / NATIVE_SEED_CACHE_RAW))
	var cached: Variant = _native_seed_cache.get(cache_key)
	if cached != null:
		return cached
	if _native_seed_cache.size() > 200000:
		_native_seed_cache.clear()
	var result := _native_seed_influence_uncached((float(cache_key.x) + 0.5) * NATIVE_SEED_CACHE_RAW,
		(float(cache_key.y) + 0.5) * NATIVE_SEED_CACHE_RAW)
	_native_seed_cache[cache_key] = result
	return result


func _native_seed_influence_uncached(wx: float, wy: float) -> Dictionary:
	var cell := Vector2i(floori(wx / NATIVE_SEED_GRID_RAW), floori(wy / NATIVE_SEED_GRID_RAW))
	var search_ring := maxi(1, ceili(maxf(_native_tree_radius_raw,
		_native_plant_radius_raw) * 1.22 / NATIVE_SEED_GRID_RAW))
	var best_strength := 0.0
	var best_habitat := ""
	for oy in range(-search_ring, search_ring + 1):
		for ox in range(-search_ring, search_ring + 1):
			var candidates := _native_seed_grid.get(cell + Vector2i(ox, oy), []) as Array
			for seed_value in candidates:
				var seed := seed_value as Dictionary
				var seed_pos := seed.get("position", Vector2.ZERO) as Vector2
				var base_radius := float(seed.get("radius", NATIVE_TREE_RADIUS_RAW))
				var distance := Vector2(wx, wy).distance_to(seed_pos)
				if distance >= base_radius * 1.22:
					continue
				var seed_id := int(seed.get("id", 0))
				# Deux bruits stables deformant le rayon cassent les disques parfaits.
				var coarse_x := floori(wx / 420.0)
				var coarse_y := floori(wy / 420.0)
				var radius_noise := lerpf(0.78, 1.22,
					_stable_rand01(_zone_id + seed_id + 83, coarse_x, coarse_y))
				var radius := base_radius * radius_noise
				if distance >= radius:
					continue
				var normalized := 1.0 - distance / radius
				var strength := smoothstep(0.0, 1.0, normalized)
				if strength > best_strength:
					best_strength = strength
					best_habitat = str(seed.get("habitat", "forest"))
	return {} if best_strength <= 0.0 else {"strength": best_strength, "habitat": best_habitat}


func _native_seed_ground_compatibility(ground: Dictionary) -> float:
	var name := str(ground.get("ground_texture", "")).to_lower()
	if name == "":
		return 0.45
	# Une texture explicitement vegetale est toujours un bon support, meme si
	# son nom contient aussi "stone" (par exemple stone_on_grass).
	if TerrainGrassClassifier.is_vegetal(name, 256.0):
		return 1.0
	if _contains_any(name, ["road", "path", "cobble", "paved", "stone", "rock", "cliff",
			"sand", "mud", "dirt", "soil", "water", "river", "ocean", "floor"]):
		return 0.0
	# Les anciennes textures globales ou non classees peuvent recevoir un
	# sous-bois modere uniquement lorsqu'une fixture vegetale le confirme.
	return 0.55


func _sample_mask(mask_index: int, channel: int, u: float, v: float) -> float:
	if mask_index < 0:
		return 0.0
	var image: Image = _mask_images.get(mask_index, null) as Image
	if image == null:
		var path := _data_dir.path_join("zone%03d_splat/masks/%03d.png" % [_zone_id, mask_index])
		image = Image.new()
		if image.load(path) != OK:
			return 0.0
		_mask_images[mask_index] = image
	var px := clampi(floori(u * float(image.get_width() - 1)), 0, image.get_width() - 1)
	var py := clampi(floori(v * float(image.get_height() - 1)), 0, image.get_height() - 1)
	var color := image.get_pixel(px, py)
	match channel:
		1: return color.g
		2: return color.b
		3: return color.a
		_: return color.r


func _detail_name(details: Array, index: int) -> String:
	if index < 0 or index >= details.size():
		return ""
	return str(details[index])


func _detail_average_color(detail_name: String) -> Color:
	if detail_name == "":
		return Color.WHITE
	if _detail_color_cache.has(detail_name):
		return _detail_color_cache[detail_name] as Color
	var path := _client_root.path_join("zones/TerrainTex").path_join(detail_name + ".png")
	var image := Image.new()
	var color := Color(0.55, 0.62, 0.48)
	if image.load(path) == OK:
		image.convert(Image.FORMAT_RGB8)
		image.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		color = image.get_pixel(0, 0)
	_detail_color_cache[detail_name] = color
	return color


func _sample_detail_color(detail_name: String, tiles: float, wx: float, wy: float) -> Color:
	if detail_name == "":
		return Color.WHITE
	var image: Image = _detail_images.get(detail_name, null) as Image
	if image == null:
		var path := _client_root.path_join("zones/TerrainTex").path_join(detail_name + ".png")
		image = Image.new()
		if image.load(path) != OK:
			_detail_images[detail_name] = image
			return _detail_average_color(detail_name)
		image.convert(Image.FORMAT_RGB8)
		_detail_images[detail_name] = image
	elif image.is_empty():
		return _detail_average_color(detail_name)
	var scale := 1.0 if tiles <= 1.5 else tiles
	var u := fposmod(wx / ZONE_SIZE_RAW * scale, 1.0)
	var v := fposmod(wy / ZONE_SIZE_RAW * scale, 1.0)
	var px := clampi(floori(u * float(image.get_width())), 0, image.get_width() - 1)
	var py := clampi(floori(v * float(image.get_height())), 0, image.get_height() - 1)
	return image.get_pixel(px, py)


func _calibrated_tint(ground: Color) -> Color:
	# On transmet l'etalonnage du sol (valeur/saturation), mais le shader n'en
	# applique que 58 % afin de conserver les nuances naturelles du sprite.
	var value := clampf(maxf(ground.r, maxf(ground.g, ground.b)) * 1.18, 0.48, 1.12)
	var neutralized := ground.lerp(Color(value, value, value), 0.18)
	return Color(neutralized.r, neutralized.g, neutralized.b, 1.0)


func _sample_byte_map(pixels: PackedByteArray, width: int, height: int,
		wx: float, wy: float) -> float:
	if pixels.is_empty() or width <= 0 or height <= 0:
		return 0.0
	var px := clampi(floori(wx / ZONE_SIZE_RAW * float(width)), 0, width - 1)
	var py := clampi(floori(wy / ZONE_SIZE_RAW * float(height)), 0, height - 1)
	return float(pixels[py * width + px]) / 255.0


func _sample_floor(wx: float, wy: float) -> float:
	if _height_resolution <= 0 or _height_bytes.size() < _height_resolution * _height_resolution * 2:
		if _host != null and _host.has_method("sample_daoc_floor_z"):
			return float(_host.call("sample_daoc_floor_z", _zone_id, wx, wy, 0.0))
		return 0.0
	# L'echantillonnage direct du r16 evite des dizaines de milliers d'appels au
	# service de collision lors de la creation d'un anneau. Bilineaire, il reste
	# visuellement colle au meme heightmap que le terrain.
	# Contrat exact de DaocTerrainRuntime._sample_height : les valeurs r16 sont
	# au centre des cellules, d'ou le -0.5. Le moindre autre mapping fait flotter
	# les touffes sur les pentes raides.
	var fx := clampf(wx / ZONE_SIZE_RAW * float(_height_resolution) - 0.5, 0.0, float(_height_resolution - 1))
	var fy := clampf(wy / ZONE_SIZE_RAW * float(_height_resolution) - 0.5, 0.0, float(_height_resolution - 1))
	var x0 := floori(fx)
	var y0 := floori(fy)
	var x1 := mini(x0 + 1, _height_resolution - 1)
	var y1 := mini(y0 + 1, _height_resolution - 1)
	var h00 := _height_at(x0, y0)
	var h10 := _height_at(x1, y0)
	var h01 := _height_at(x0, y1)
	var h11 := _height_at(x1, y1)
	return lerpf(lerpf(h00, h10, fx - float(x0)), lerpf(h01, h11, fx - float(x0)), fy - float(y0))


func _height_at(x: int, y: int) -> float:
	var offset := (y * _height_resolution + x) * 2
	return float(_height_bytes[offset] | (_height_bytes[offset + 1] << 8))


## Vrai quand le sol est sous la surface d'un plan d'eau du runtime (hauteur).
func _underwater(wx: float, wy: float, floor_raw: float) -> bool:
	if _host == null or not _host.has_method("sample_daoc_water_info"):
		return false
	var info: Dictionary = _host.call("sample_daoc_water_info", _zone_id, wx, wy, floor_raw) as Dictionary
	return not info.is_empty() and float(info.get("height", -1.0e9)) > floor_raw + 1.0


## Relit les corps de collision de props sur l'hote et en retient les
## empreintes de taille batiment. Rend true quand la liste a CHANGE.
func _refresh_building_footprints() -> bool:
	if _host == null:
		return false
	var runtime_value: Variant = _host.get("_prop_collision_runtime")
	if not (runtime_value is Dictionary):
		return false
	var zone_props: Array = (runtime_value as Dictionary).get(_zone_id, []) as Array
	if zone_props.size() == _building_footprint_source_count:
		return false
	# Les props arrivent UN PAR UN sur plusieurs images (peuplement R9 differe,
	# recharge de zone). Rebatir a chaque ajout couterait une reconstruction
	# complete par image ; on attend que le compte soit stable.
	var now := Time.get_ticks_msec()
	if zone_props.size() != _pending_footprint_count:
		_pending_footprint_count = zone_props.size()
		_pending_footprint_since_msec = now
		return false
	if now - _pending_footprint_since_msec < BUILDING_REFRESH_SETTLE_MSEC:
		return false
	_building_footprint_source_count = zone_props.size()
	_building_footprints.clear()
	for item_value in zone_props:
		var item := item_value as Dictionary
		if item == null or not bool(item.get("has_daoc_aabb", false)):
			continue
		var mn: Vector3 = item.get("daoc_min", Vector3.ZERO) as Vector3
		var mx: Vector3 = item.get("daoc_max", Vector3.ZERO) as Vector3
		if minf(mx.x - mn.x, mx.y - mn.y) < BUILDING_MIN_EXTENT_RAW:
			continue
		_building_footprints.append({
			"min_x": mn.x + BUILDING_INSET_RAW, "min_y": mn.y + BUILDING_INSET_RAW,
			"max_x": mx.x - BUILDING_INSET_RAW, "max_y": mx.y - BUILDING_INSET_RAW,
			"floor_z": mn.z, "top_z": mx.z,
		})
	_report["building_footprints"] = _building_footprints.size()
	return true


## Vrai quand le point est dans l'emprise au sol d'un batiment dont le
## plancher est au niveau du sol (un pont haut laisse pousser dessous).
func _under_building(wx: float, wy: float, floor_raw: float) -> bool:
	for footprint in _building_footprints:
		if wx < float(footprint["min_x"]) or wx > float(footprint["max_x"]):
			continue
		if wy < float(footprint["min_y"]) or wy > float(footprint["max_y"]):
			continue
		var building_floor := float(footprint["floor_z"])
		if building_floor > floor_raw + BUILDING_FLOOR_TOLERANCE_RAW:
			continue
		if float(footprint["top_z"]) < floor_raw:
			continue
		return true
	return false


## Proximite de la rive d'un plan d'eau NON oceanique, 1 contre la berge, 0 au
## dela de `_shore_ring_raw`. Les bandes sont prefiltrees par leur boite
## englobante (calculee une fois) : le calcul exact ne tourne que pres de l'eau.
func _shore_proximity(wx: float, wy: float) -> float:
	if _shore_ring_raw <= 0.0 or _water_bands.is_empty():
		return 0.0
	var point := Vector2(wx, wy)
	var best := INF
	for band_index in _water_bands.size():
		var body := _water_bands[band_index]
		if _is_height_only_water(body):
			continue
		var bounds: Rect2 = _shore_band_bounds(band_index)
		if not bounds.has_point(point):
			continue
		var lefts: Array = body.get("lefts", []) as Array
		var rights: Array = body.get("rights", []) as Array
		for index in range(mini(lefts.size(), rights.size()) - 1):
			var l0 := lefts[index] as Vector2
			var r0 := rights[index] as Vector2
			var l1 := lefts[index + 1] as Vector2
			var r1 := rights[index + 1] as Vector2
			best = minf(best, _distance_to_segment(point, l0, l1))
			best = minf(best, _distance_to_segment(point, r0, r1))
			if index == 0:
				best = minf(best, _distance_to_segment(point, l0, r0))
			if index == mini(lefts.size(), rights.size()) - 2:
				best = minf(best, _distance_to_segment(point, l1, r1))
	if best >= _shore_ring_raw:
		return 0.0
	# La marge d'eau (96) reste vide ; l'ourlet commence juste derriere elle.
	return clampf(1.0 - (best - _water_margin_raw) / maxf(1.0, _shore_ring_raw - _water_margin_raw), 0.0, 1.0)


func _shore_band_bounds(band_index: int) -> Rect2:
	if _shore_band_bounds_cache.has(band_index):
		return _shore_band_bounds_cache[band_index] as Rect2
	var body := _water_bands[band_index]
	var rect := Rect2()
	var first := true
	for key in ["lefts", "rights"]:
		for point_value in body.get(key, []) as Array:
			var point := point_value as Vector2
			if first:
				rect = Rect2(point, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(point)
	rect = rect.grow(_shore_ring_raw)
	_shore_band_bounds_cache[band_index] = rect
	return rect


func _inside_water(wx: float, wy: float) -> bool:
	if _water_bands.is_empty():
		return false
	var point := Vector2(wx, wy)
	for band_index in _water_bands.size():
		var body := _water_bands[band_index]
		# Les rectangles OCEAN/DEEPOCEAN du SECTOR.DAT couvrent souvent des
		# quadrants entiers, y compris la terre située au-dessus du niveau marin.
		# Le filtre de hauteur `_underwater` traite ce cas plus bas ; les prendre
		# ici pour des rivières supprimait toute végétation de la zone 027.
		if _is_height_only_water(body):
			continue
		# 2026-09-27 : boite englobante (+ marge) calculee une fois par bande.
		if not _water_band_bounds(band_index).has_point(point):
			continue
		var lefts: Array = body.get("lefts", []) as Array
		var rights: Array = body.get("rights", []) as Array
		for index in range(mini(lefts.size(), rights.size()) - 1):
			var l0 := lefts[index] as Vector2
			var r0 := rights[index] as Vector2
			var l1 := lefts[index + 1] as Vector2
			var r1 := rights[index + 1] as Vector2
			var quad: Array = [l0, l1, r1, r0]
			if _point_in_poly(point, quad):
				return true
			# Une faible marge evite les brins flottant exactement sur la rive, sans
			# transformer le cours d'eau en gros tube qui mange les champs voisins.
			if _distance_to_segment(point, l0, l1) <= _water_margin_raw \
					or _distance_to_segment(point, r0, r1) <= _water_margin_raw \
					or _distance_to_segment(point, l0, r0) <= _water_margin_raw \
					or _distance_to_segment(point, l1, r1) <= _water_margin_raw:
				return true
	return false


var _water_bounds_cache: Dictionary = {}


func _water_band_bounds(band_index: int) -> Rect2:
	var body := _water_bands[band_index]
	var cached: Variant = _water_bounds_cache.get(band_index, null)
	if cached is Rect2:
		return cached as Rect2
	var rect := Rect2()
	var first := true
	for key in ["lefts", "rights"]:
		for point_value in body.get(key, []) as Array:
			var point := point_value as Vector2
			if first:
				rect = Rect2(point, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(point)
	rect = rect.grow(_water_margin_raw + 1.0)
	_water_bounds_cache[band_index] = rect
	return rect


func _point_in_poly(point: Vector2, polygon: Array) -> bool:
	var inside := false
	var previous := polygon.size() - 1
	for current in polygon.size():
		var a := polygon[current] as Vector2
		var b := polygon[previous] as Vector2
		if ((a.y > point.y) != (b.y > point.y)) \
				and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		previous = current
	return inside


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _load_manifest() -> void:
	var path := _data_dir.path_join("zone%03d_splat/manifest.json" % _zone_id)
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	_report["manifest_path"] = path
	_report["terrain_details"] = (_manifest.get("details", []) as Array).duplicate()


func _make_grass_material() -> ShaderMaterial:
	# Atlas runtime de quatre silhouettes : aucune texture intermediaire n'est
	# bakee et les quatre variantes restent un seul materiau / draw call.
	var atlas := Image.create_empty(GRASS_ATLAS_CELL_SIZE * GRASS_TEXTURE_PATHS.size(),
		GRASS_ATLAS_CELL_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var normal_atlas := Image.create_empty(GRASS_ATLAS_CELL_SIZE * GRASS_TEXTURE_PATHS.size(),
		GRASS_ATLAS_CELL_SIZE, false, Image.FORMAT_RGBA8)
	normal_atlas.fill(Color(0.5, 0.5, 1.0, 1.0))
	var loaded_count := 0
	var normal_count := 0
	for index in GRASS_TEXTURE_PATHS.size():
		var path := GRASS_TEXTURE_PATHS[index]
		var image := _load_grass_source_image(path)
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		image.resize(GRASS_ATLAS_CELL_SIZE, GRASS_ATLAS_CELL_SIZE, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(image, Rect2i(0, 0, GRASS_ATLAS_CELL_SIZE, GRASS_ATLAS_CELL_SIZE),
			Vector2i(index * GRASS_ATLAS_CELL_SIZE, 0))
		var normal_path := GRASS_NORMAL_PATHS[index]
		if normal_path != "":
			var normal_image := _load_grass_source_image(normal_path)
			if normal_image != null and not normal_image.is_empty():
				normal_image.convert(Image.FORMAT_RGBA8)
				normal_image.resize(GRASS_ATLAS_CELL_SIZE, GRASS_ATLAS_CELL_SIZE, Image.INTERPOLATE_LANCZOS)
				normal_atlas.blit_rect(normal_image, Rect2i(0, 0, GRASS_ATLAS_CELL_SIZE, GRASS_ATLAS_CELL_SIZE), Vector2i(index * GRASS_ATLAS_CELL_SIZE, 0))
				normal_count += 1
		loaded_count += 1
	if loaded_count != GRASS_TEXTURE_PATHS.size():
		push_warning("Grass Remaster: %d/%d variantes du catalogue mixte chargees" % [loaded_count, GRASS_TEXTURE_PATHS.size()])
		if loaded_count == 0:
			return null
	atlas.generate_mipmaps()
	normal_atlas.generate_mipmaps()
	var texture := ImageTexture.create_from_image(atlas)
	var normal_texture := ImageTexture.create_from_image(normal_atlas)
	var material := ShaderMaterial.new()
	material.shader = GrassShader
	material.set_shader_parameter("grass_texture", texture)
	material.set_shader_parameter("grass_normal_texture", normal_texture)
	material.set_shader_parameter("variant_count", float(GRASS_TEXTURE_PATHS.size()))
	material.set_shader_parameter("fade_start", _fade_start_raw * _world_scale)
	material.set_shader_parameter("fade_end", _fade_end_raw * _world_scale)
	material.set_shader_parameter("wind_strength", _wind_strength)
	material.set_shader_parameter("wind_speed", _wind_speed)
	material.set_shader_parameter("wind_gust_strength", _wind_gust_strength)
	_report["normal_map_variants"] = normal_count
	_report["ecological_distribution"] = "zone_catalog+terrain_material+slope+altitude+stable_patches"
	return material


func _load_grass_source_image(path: String) -> Image:
	# ResourceLoader suit les remaps d'export. Le chargement PNG brut ne sert que
	# de repli aux tests headless executes avant le premier import Godot.
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var imported := texture.get_image()
			if imported != null and not imported.is_empty():
				return imported
	var raw := Image.new()
	if raw.load(path) == OK:
		return raw
	return null


func _all_grass_textures_exist() -> bool:
	for path in GRASS_TEXTURE_PATHS:
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			return false
	return true


func _all_grass_textures_have_cutout() -> bool:
	for path in GRASS_TEXTURE_PATHS:
		var image := _load_grass_source_image(path)
		if image == null or image.is_empty() or not image.detect_alpha():
			return false
	return true


func _make_grass_mesh(cluster_count: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_width := _card_width_raw * _world_scale * 0.5
	var height := _card_height_raw * _world_scale
	# Trois petites touffes par instance densifient le tapis sans tripler les
	# MultiMesh, les tests de masque ou le nombre de draw calls.
	var cluster_offsets := [Vector2.ZERO, Vector2(-28.0, 18.0), Vector2(26.0, -24.0)]
	var cluster_scales := [1.0, 0.84, 0.72]
	var variant_offsets := [0.0, 0.0, 0.0]
	for cluster in mini(cluster_count, cluster_offsets.size()):
		var offset2 := (cluster_offsets[cluster] as Vector2) * _world_scale
		var cluster_scale := float(cluster_scales[cluster])
		for plane in 2:
			var base_index := vertices.size()
			for level in 4:
				var t := float(level) / 3.0
				var width := half_width * cluster_scale * lerpf(1.0, 0.78, t)
				var y := height * cluster_scale * t
				if plane == 0:
					vertices.append(Vector3(offset2.x - width, y, offset2.y))
					vertices.append(Vector3(offset2.x + width, y, offset2.y))
					normals.append(Vector3(0.0, 0.15, 1.0).normalized())
					normals.append(Vector3(0.0, 0.15, 1.0).normalized())
				else:
					vertices.append(Vector3(offset2.x, y, offset2.y - width))
					vertices.append(Vector3(offset2.x, y, offset2.y + width))
					normals.append(Vector3(1.0, 0.15, 0.0).normalized())
					normals.append(Vector3(1.0, 0.15, 0.0).normalized())
				uvs.append(Vector2(0.0, 1.0 - t))
				uvs.append(Vector2(1.0, 1.0 - t))
				uvs2.append(Vector2(float(variant_offsets[cluster]), 0.0))
				uvs2.append(Vector2(float(variant_offsets[cluster]), 0.0))
			for segment in 3:
				var lower := base_index + segment * 2
				var upper := lower + 2
				indices.append_array([lower, lower + 1, upper + 1, lower, upper + 1, upper])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _recount_report() -> void:
	var instances := 0
	var effective_cards := 0
	var explicit_alt_override_instances := 0
	var lod_counts := {"near_3": 0, "mid_2": 0, "far_1": 0}
	for node_value in _chunks.values():
		var node := node_value as MultiMeshInstance3D
		if node != null and node.multimesh != null:
			var instance_count := node.multimesh.instance_count
			var lod_clusters := clampi(int(node.get_meta("lod_clusters", 1)), 1, 3)
			instances += instance_count
			explicit_alt_override_instances += int(node.get_meta(
				"explicit_alt_override_instances", 0))
			effective_cards += instance_count * lod_clusters
			match lod_clusters:
				3:
					lod_counts["near_3"] = int(lod_counts["near_3"]) + 1
				2:
					lod_counts["mid_2"] = int(lod_counts["mid_2"]) + 1
				_:
					lod_counts["far_1"] = int(lod_counts["far_1"]) + 1
	_report["chunks"] = _chunks.size()
	_report["instances"] = instances
	_report["effective_cards"] = effective_cards
	_report["explicit_alt_override_samples"] = explicit_alt_override_instances
	_report["chunk_lod"] = lod_counts


func _stable_rand01(a: int, b: int, c: int) -> float:
	var value: int = int((a * 73856093) ^ (b * 19349663) ^ (c * 83492791))
	value = abs(value % 1000000)
	return float(value) / 1000000.0


## Les sprites sont melanges par defaut ; seuls les rochers sont optionnels.
func set_outward_rocks_enabled(rocks_enabled: bool) -> void:
	_outward_rocks_enabled = rocks_enabled
	for value in _chunks.values():
		_populate_outward_rocks(value as MultiMeshInstance3D)


func set_outward_flowers_enabled(flowers_enabled: bool) -> void:
	_outward_flowers_enabled = flowers_enabled
	for value in _chunks.values():
		_populate_outward_flowers(value as MultiMeshInstance3D)


func _populate_outward_rocks(chunk: MultiMeshInstance3D) -> void:
	for old in chunk.get_children():
		if old.has_meta("outward_decorative_rock"):
			chunk.remove_child(old)
			old.queue_free()
	if not _outward_rocks_enabled or chunk.multimesh.instance_count < 32:
		return
	var cell: Vector2i = chunk.get_meta("chunk", Vector2i.ZERO)
	# Petits cailloux déterministes, choisis parmi les emplacements végétaux.
	if _stable_rand01(_zone_id + 801, cell.x, cell.y) > 0.72:
		return
	if _outward_rock_meshes.is_empty():
		for label in ["a", "b", "c"]:
			var mesh := load("res://assets/outward/rock_%s.obj" % label) as Mesh
			if mesh != null:
				_outward_rock_meshes.append(mesh)
		_outward_rock_material = _decorative_rock_material()
	if _outward_rock_meshes.is_empty():
		return
	var stone_count := 2 + posmod(cell.x * 7 + cell.y * 3, 3)
	for stone_index in stone_count:
		var pick := int(_stable_rand01(_zone_id + 809 + stone_index, cell.x, cell.y) * chunk.multimesh.instance_count)
		pick = clampi(pick, 0, chunk.multimesh.instance_count - 1)
		var source := chunk.multimesh.get_instance_transform(pick)
		var stone := MeshInstance3D.new()
		stone.name = "OutwardRock_%d_%d_%d" % [cell.x, cell.y, stone_index]
		stone.mesh = _outward_rock_meshes[posmod(cell.x + cell.y + stone_index, _outward_rock_meshes.size())]
		stone.material_override = _outward_rock_material
		var bounds := stone.mesh.get_aabb()
		var diameter := lerpf(28.0, 72.0, _stable_rand01(_zone_id + 811 + stone_index, cell.y, cell.x)) * _world_scale
		var scale_factor := diameter / maxf(0.001, maxf(bounds.size.x, bounds.size.z))
		var basis := Basis(Vector3.UP, _stable_rand01(_zone_id + 813 + stone_index, cell.x, cell.y) * TAU).scaled(Vector3.ONE * scale_factor)
		# OBJ origin is not the foot: place its lowest vertex below the ground.
		var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		stone.transform = Transform3D(basis, source.origin - basis * center - Vector3.UP * (3.0 + _vertical_offset_raw) * _world_scale)
		stone.set_meta("outward_decorative_rock", true)
		stone.visibility_range_end = _fade_end_raw * _world_scale
		stone.visibility_range_end_margin = 800.0 * _world_scale
		stone.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		chunk.add_child(stone)


func _populate_outward_flowers(chunk: MultiMeshInstance3D) -> void:
	for old in chunk.get_children():
		if old.has_meta("outward_decorative_flowers"):
			chunk.remove_child(old)
			old.queue_free()
	if not _outward_flowers_enabled or chunk.multimesh == null or chunk.multimesh.instance_count < 48:
		return
	var cell: Vector2i = chunk.get_meta("chunk", Vector2i.ZERO)
	if _stable_rand01(_zone_id + 901, cell.x, cell.y) > 0.98:
		return
	_ensure_flower_resources()
	var flower_count := clampi(int(round(float(chunk.multimesh.instance_count) / 16.0)), 28, 72)
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "OutwardFlowers_%d_%d" % [cell.x, cell.y]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _outward_flower_mesh
	mm.instance_count = flower_count
	for flower_index in flower_count:
		var pick := int(_stable_rand01(_zone_id + 907 + flower_index, cell.x, cell.y) * chunk.multimesh.instance_count)
		pick = clampi(pick, 0, chunk.multimesh.instance_count - 1)
		var source := chunk.multimesh.get_instance_transform(pick)
		var height_raw := lerpf(20.0, 38.0, _stable_rand01(_zone_id + 911, cell.x + flower_index, cell.y))
		var diameter_raw := lerpf(7.0, 12.0, _stable_rand01(_zone_id + 919, cell.y, cell.x + flower_index))
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * diameter_raw * _world_scale)
		mm.set_instance_transform(flower_index, Transform3D(basis,
			source.origin + Vector3.UP * (height_raw - _vertical_offset_raw) * _world_scale))
		var palette := [Color(1.0, 0.93, 0.70, 1.0), Color(1.0, 0.72, 0.78, 1.0), Color(0.78, 0.86, 1.0, 1.0)]
		mm.set_instance_color(flower_index, palette[posmod(cell.x + cell.y + flower_index, palette.size())])
	flowers.multimesh = mm
	flowers.material_override = _outward_flower_material
	flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flowers.visibility_range_end = minf(_fade_end_raw, 6500.0) * _world_scale
	flowers.visibility_range_end_margin = 500.0 * _world_scale
	flowers.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	flowers.set_meta("outward_decorative_flowers", true)
	chunk.add_child(flowers)


func _ensure_flower_resources() -> void:
	if _outward_flower_mesh != null and _outward_flower_material != null:
		return
	_outward_flower_material = StandardMaterial3D.new()
	_outward_flower_material.albedo_color = Color.WHITE
	_outward_flower_material.vertex_color_use_as_albedo = true
	_outward_flower_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_outward_flower_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outward_flower_material.roughness = 0.88
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in 5:
		var angle := float(petal) * TAU / 5.0
		var left := angle - 0.48
		var right := angle + 0.48
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3(0.0, 0.0, 0.0))
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3(cos(left), 0.18, sin(left)))
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3(cos(right), 0.18, sin(right)))
	surface.generate_normals()
	var flower_head := surface.commit()
	flower_head.surface_set_material(0, _outward_flower_material)
	_outward_flower_mesh = flower_head


## P1-118 — les cailloux Outward sortaient presque noirs : leur albédo est une
## texture tuilée, leur normale un atlas dessiné pour d'autres UV. Projection
## triplanaire de l'albédo, normale d'atlas retirée, valeur relevée vers celle
## des pierres du sol. Décor pur : aucune collision.
func _decorative_rock_material() -> Material:
	var source := load("res://assets/outward/rock_material.tres") as StandardMaterial3D
	if source == null:
		return null
	var material := source.duplicate() as StandardMaterial3D
	material.normal_enabled = false
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (1.0 / maxf(0.001, 60.0 * _world_scale))
	material.albedo_color = Color(1.55, 1.5, 1.4)
	material.roughness = 0.92
	return material


## P1-119 — pelouse rase en couches (DaocLawnShell.gdshader), bâtie par morceau
## de 4096 dans `_lawn_radius_raw` autour du joueur. Rebâtie avec l'herbe (même
## déclencheur : changement de morceau ou d'emprises de bâtiments).
func _refresh_lawn(focus: Vector2, force: bool) -> void:
	if force:
		for old_value in _lawn_chunks.values():
			var old_node := old_value as Node
			if old_node != null:
				old_node.queue_free()
		_lawn_chunks.clear()
		_clear_reserves()
	if not _lawn_enabled:
		return
	if _lawn_material == null:
		_lawn_material = ShaderMaterial.new()
		_lawn_material.shader = LawnShader
		_lawn_material.set_shader_parameter("world_scale", _world_scale)
		_lawn_material.set_shader_parameter("fade_start_raw", _lawn_radius_raw * 0.7)
		_lawn_material.set_shader_parameter("fade_end_raw", _lawn_radius_raw)
		_lawn_material.set_shader_parameter("wind_speed", _wind_speed)
	# P1-133 : Midgard (zones 1xx) -> neige au lieu de la pelouse ; Hibernia et
	# Albion gardent l herbe (decision utilisateur du 2026-09-29).
	_lawn_material.set_shader_parameter("snow_mode", 1.0 if _lawn_snow else 0.0)
	var wanted: Dictionary = {}
	var reach := _lawn_radius_raw + _chunk_size_raw * 0.72
	var player_chunk := Vector2i(floori(focus.x / _chunk_size_raw), floori(focus.y / _chunk_size_raw))
	for cy in range(player_chunk.y - 2, player_chunk.y + 3):
		for cx in range(player_chunk.x - 2, player_chunk.x + 3):
			if cx < 0 or cy < 0 or float(cx) * _chunk_size_raw >= ZONE_SIZE_RAW or float(cy) * _chunk_size_raw >= ZONE_SIZE_RAW:
				continue
			var center := Vector2((float(cx) + 0.5) * _chunk_size_raw, (float(cy) + 0.5) * _chunk_size_raw)
			if center.distance_to(focus) > reach:
				continue
			var key := "%d,%d" % [cx, cy]
			wanted[key] = true
			if not _lawn_chunks.has(key) and not force:
				var kept_lawn := _reserve_take(_lawn_reserve, _lawn_reserve_order, key)
				if kept_lawn != null:
					_lawn_chunks[key] = kept_lawn
			if not _lawn_chunks.has(key):
				if force and center.distance_to(focus) <= _force_sync_radius_raw:
					var lawn := _build_lawn_chunk(cx, cy)
					_lawn_chunks[key] = lawn
					if lawn != null:
						add_child(lawn)
				else:
					# La pelouse passe APRES l herbe du meme rayon (elle ne fait que
					# combler le sol sous les brins).
					_enqueue_build("lawn", cx, cy, 0, center.distance_to(focus) + 1.0)
	_wanted_lawn = wanted
	for key_value in _lawn_chunks.keys():
		if wanted.has(str(key_value)):
			continue
		var old := _lawn_chunks[key_value] as Node
		_lawn_chunks.erase(key_value)
		if old != null:
			_reserve_put(_lawn_reserve, _lawn_reserve_order, str(key_value), old)


## Masque « pelouse » d'un point : les règles de `_build_chunk`, sans le tirage.
func _lawn_coverage(wx: float, wy: float, floor_raw: float) -> Dictionary:
	var ground := _sample_ground_material(wx, wy)
	var native_map_weight := _sample_byte_map(_grass_pixels, _grass_width, _grass_height, wx, wy)
	var coverage := native_map_weight if _strict_grassmap_authority \
		else maxf(native_map_weight, float(ground.get("semantic_vegetal", 0.0)))
	if coverage > 0.0 and (_inside_water(wx, wy) or _under_building(wx, wy, floor_raw) \
			or _underwater(wx, wy, floor_raw)):
		coverage = 0.0
	return {"coverage": coverage, "tint": ground.get("tint", Color.WHITE)}


func _build_lawn_chunk(chunk_x: int, chunk_y: int) -> MultiMeshInstance3D:
	var job := _lawn_job_begin(chunk_x, chunk_y)
	_lawn_job_step(job, -1)
	return _lawn_job_finish(job)


func _lawn_job_begin(chunk_x: int, chunk_y: int) -> Dictionary:
	var cells := maxi(1, ceili(_chunk_size_raw / _lawn_grid_raw))
	return {"kind": "lawn", "cx": chunk_x, "cy": chunk_y, "cells": cells,
		"step": _chunk_size_raw / float(cells), "index": 0, "any": false,
		"started_usec": Time.get_ticks_usec(), "vertices": PackedVector3Array(),
		"colors": PackedColorArray()}


func _lawn_job_step(job: Dictionary, deadline_usec: int) -> bool:
	var cells := int(job["cells"])
	var row := cells + 1
	var total := row * row
	var step := float(job["step"])
	var start_x := float(job["cx"]) * _chunk_size_raw
	var start_y := float(job["cy"]) * _chunk_size_raw
	var vertices: PackedVector3Array = job["vertices"]
	var colors: PackedColorArray = job["colors"]
	var index := int(job["index"])
	while index < total:
		var wx := start_x + float(index % row) * step
		var wy := start_y + float(index / row) * step
		var floor_raw := _sample_floor(wx, wy)
		var sample := _lawn_coverage(wx, wy, floor_raw)
		var coverage := clampf(float(sample["coverage"]), 0.0, 1.0)
		if coverage > 0.12:
			job["any"] = true
		var tint := sample["tint"] as Color
		vertices.append(_origin + Vector3(wx * _world_scale,
			(floor_raw * _height_exaggeration + 1.0) * _world_scale, wy * _world_scale))
		colors.append(Color(tint.r, tint.g, tint.b, coverage))
		index += 1
		if deadline_usec >= 0 and (index & 7) == 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	job["index"] = index
	job["vertices"] = vertices
	job["colors"] = colors
	return index >= total


func _lawn_job_finish(job: Dictionary) -> MultiMeshInstance3D:
	if not bool(job["any"]):
		return null
	var chunk_x := int(job["cx"])
	var chunk_y := int(job["cy"])
	var cells := int(job["cells"])
	var vertices: PackedVector3Array = job["vertices"]
	var colors: PackedColorArray = job["colors"]
	var started := int(int(job["started_usec"]) / 1000)
	var indices := PackedInt32Array()
	var row := cells + 1
	for gy in cells:
		for gx in cells:
			var a := gy * row + gx
			# On ne garde que les quads qui touchent de la pelouse.
			if colors[a].a <= 0.01 and colors[a + 1].a <= 0.01 \
					and colors[a + row].a <= 0.01 and colors[a + row + 1].a <= 0.01:
				continue
			indices.append_array([a, a + 1, a + row + 1, a, a + row + 1, a + row])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = _lawn_shells
	for shell in _lawn_shells:
		multimesh.set_instance_transform(shell, Transform3D.IDENTITY)
		multimesh.set_instance_custom_data(shell, Color(float(shell) / float(_lawn_shells - 1), 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Lawn_%02d_%02d" % [chunk_x, chunk_y]
	instance.multimesh = multimesh
	instance.material_override = _lawn_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 12.0 * _world_scale
	instance.set_meta("daoc_lawn", true)
	instance.set_meta("lawn_triangles", indices.size() / 3)
	instance.set_meta("lawn_build_ms", Time.get_ticks_msec() - started)
	_report["lawn_chunks"] = int(_report.get("lawn_chunks", 0)) + 1
	_report["lawn_triangles_per_shell"] = int(_report.get("lawn_triangles_per_shell", 0)) + indices.size() / 3
	_report["lawn_build_ms"] = int(_report.get("lawn_build_ms", 0)) + Time.get_ticks_msec() - started
	return instance


func set_lawn_enabled(value: bool) -> void:
	_lawn_enabled = value
	_refresh_lawn(_player_local_raw(), true)


## ═══════════════════════════════════════════════════════════════════════════
## 2026-09-27 — COMBLER LES TROUS. Zone par zone, `analyze_holes` compare ce
## que la pose d'herbe couvre deja (grassmap, ALT, sol vegetal, graines) a la
## COULEUR REELLE du sol (la teinte que le shader terrain rend) : un sol
## franchement vert, hors eau et hors matiere dure (roche, pave, chemin...),
## que rien ne couvre, est un trou. L'outil tools/grass_fill_build.gd en fait
## une carte data/gameplay/grass_fill/zoneNNN.png, lue ici a la configuration.
## Les fichiers du client ne sont jamais modifies.
## ═══════════════════════════════════════════════════════════════════════════
const FILL_DIR := "res://data/gameplay/grass_fill"
const FILL_HARD_TOKENS: PackedStringArray = [
	"rock", "stone", "cliff", "cobble", "paved", "pebble", "rubble", "snow", "ice", "lava",
	"sulfur", "coral", "ocean", "river", "water", "crater", "cavewall", "floor", "grid",
	"path", "road", "sand", "mud", "nukelayer",
]
var _fill_pixels := PackedByteArray()
var _fill_resolution := 0


func _load_fill_map() -> void:
	var path := FILL_DIR.path_join("zone%03d.png" % _zone_id)
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_L8)
	_fill_resolution = image.get_width()
	_fill_pixels = image.get_data()
	_report["fill_map"] = path


## Vert franc : la composante verte domine le rouge et le bleu.
static func greenness(color: Color) -> float:
	var excess := color.g - maxf(color.r, color.b)
	return clampf(excess / maxf(0.04, color.g) * 4.0, 0.0, 1.0)


func _fill_is_hard_ground(texture_name: String) -> bool:
	var base := texture_name.get_file().get_basename().to_lower()
	for token in FILL_HARD_TOKENS:
		if base.contains(token):
			return true
	return false


func analyze_holes(resolution: int = 256, min_greenness: float = 0.35) -> Dictionary:
	var fill := PackedByteArray()
	fill.resize(resolution * resolution)
	var stats := {"cells": resolution * resolution, "green_ground": 0, "covered": 0, "holes": 0,
		"water": 0, "hard": 0}
	var cell := ZONE_SIZE_RAW / float(resolution)
	for py in resolution:
		for px in resolution:
			var wx := (float(px) + 0.5) * cell
			var wy := (float(py) + 0.5) * cell
			var ground := _sample_ground_material(wx, wy)
			var green := greenness(ground.get("tint", Color.WHITE) as Color)
			if green < min_greenness:
				continue
			if _fill_is_hard_ground(str(ground.get("ground_texture", ""))):
				stats["hard"] = int(stats["hard"]) + 1
				continue
			if _inside_water(wx, wy) or _underwater(wx, wy, _sample_floor(wx, wy)):
				stats["water"] = int(stats["water"]) + 1
				continue
			stats["green_ground"] = int(stats["green_ground"]) + 1
			var native := _sample_byte_map(_grass_pixels, _grass_width, _grass_height, wx, wy)
			var semantic := float(ground.get("semantic_vegetal", 0.0))
			var coverage := native if _strict_grassmap_authority else maxf(native, semantic)
			if _native_seed_enabled and not _strict_grassmap_authority:
				var seed := _native_seed_influence(wx, wy)
				if not seed.is_empty():
					coverage = maxf(coverage, float(seed.get("strength", 0.0)) * _native_seed_ground_compatibility(ground))
			if coverage >= _coverage_threshold:
				stats["covered"] = int(stats["covered"]) + 1
				continue
			stats["holes"] = int(stats["holes"]) + 1
			fill[py * resolution + px] = int(lerpf(0.6, 1.0, green) * 255.0)
	return {"fill": fill, "resolution": resolution, "stats": stats}


static func _normalized(pixels: PackedByteArray, maximum: int) -> PackedByteArray:
	if pixels.is_empty() or maximum <= 0 or maximum >= 255:
		return pixels
	var out := PackedByteArray()
	out.resize(pixels.size())
	for index in pixels.size():
		out[index] = mini(255, int(round(float(pixels[index]) * 255.0 / float(maximum))))
	return out


func _apply_detail_level(level: int, rebuild: bool) -> void:
	_detail_level = clampi(level, 0, DETAIL_LEVELS.size() - 1)
	var values: Dictionary = DETAIL_LEVELS[_detail_level]
	_lawn_radius_raw = float(values["lawn_radius_raw"])
	_lod2_spacing = float(values["lod2_spacing"])
	_lod1_spacing = float(values["lod1_spacing"])
	_report["detail_level"] = _detail_level
	if not rebuild:
		return
	_clear_reserves()
	for chunk in _chunks.values():
		if chunk != null and is_instance_valid(chunk):
			(chunk as Node).queue_free()
	_chunks.clear()
	for lawn in _lawn_chunks.values():
		if lawn != null and is_instance_valid(lawn):
			(lawn as Node).queue_free()
	_lawn_chunks.clear()
	_refresh_chunks(true)


## Option graphique « Densite de l herbe », appliquee a chaud.
func set_detail_level(level: int) -> void:
	if clampi(level, 0, DETAIL_LEVELS.size() - 1) != _detail_level:
		_apply_detail_level(level, true)


func detail_level() -> int:
	return _detail_level


## 2026-09-29 : OCEAN/DEEPOCEAN et SWAMP sont des nappes a HAUTEUR fixe dont le
## polygone couvre des quadrants entiers, terre emergee comprise (Lyonesse,
## zone 010 : deux bandes SWAMP a 2700 couvrent toute la zone et rejetaient
## 100 % de l'herbe). Seul `_underwater` (sol sous la surface) les juge.
func _is_height_only_water(body: Dictionary) -> bool:
	var water_type := str(body.get("type", "")).to_upper()
	return water_type.contains("OCEAN") or water_type.contains("SWAMP")


## P1-134 — un bloc d herbe en attente a moins d un bloc et demi du joueur.
func _near_chunk_missing() -> bool:
	var near := _chunk_size_raw * 1.5
	for entry in _build_queue:
		if str(entry["kind"]) == "grass" and float(entry["distance"]) <= near:
			return true
	return not _active_job.is_empty() and str(_active_job["kind"]) == "grass" \
		and float(_active_job.get("distance", INF)) <= near


## P1-134 — memoisations du bloc d herbe (mesure zone 8 : 841 ms de sol et
## 214 ms de variante sur 1,6 s par bloc). Resultats identiques a l appel direct.
var _vegetal_cache: Dictionary = {}
var _variant_family_cache: Dictionary = {}


func _is_vegetal_cached(texture_name: String, tiles: float) -> bool:
	var key := "%s|%d" % [texture_name, 1 if tiles > 1.5 else 0]
	var cached: Variant = _vegetal_cache.get(key)
	if cached == null:
		cached = TerrainGrassClassifier.is_vegetal(texture_name, tiles)
		_vegetal_cache[key] = cached
	return bool(cached)


## 0 marais, 1 foret, 2 sec, 3 prairie (sauf pente forte ou altitude : sec).
func _variant_family(name: String, native_seed_habitat: String, catalog_habitat: String) -> int:
	if native_seed_habitat == "wetland" or _contains_any(name, ["bog", "marsh", "peat", "wet", "swamp", "moss"]) or (name == "" and catalog_habitat == "wetland"):
		return 0
	if native_seed_habitat == "forest" or _contains_any(name, ["forest", "leaf", "root", "pine", "evergreen", "wood"]) or (name == "" and catalog_habitat == "forest"):
		return 1
	if native_seed_habitat == "dry" or _contains_any(name, ["rock", "heath", "scrub", "tundra", "dry", "sand"]) or (name == "" and catalog_habitat == "dry"):
		return 2
	return 3


## 2026-09-29 — reserve des blocs quittes (voir CHUNK_RESERVE_MAX).
func _reserve_put(reserve: Dictionary, order: Array, key: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if reserve.has(key):
		var previous := reserve[key] as Node
		if previous != null and previous != node and is_instance_valid(previous):
			previous.queue_free()
		order.erase(key)
	(node as Node3D).visible = false
	reserve[key] = node
	order.append(key)
	while order.size() > CHUNK_RESERVE_MAX:
		var oldest := str(order.pop_front())
		var dropped := reserve.get(oldest) as Node
		reserve.erase(oldest)
		if dropped != null and is_instance_valid(dropped):
			dropped.queue_free()


func _reserve_take(reserve: Dictionary, order: Array, key: String) -> Node:
	if not reserve.has(key):
		return null
	var node := reserve[key] as Node
	reserve.erase(key)
	order.erase(key)
	if node == null or not is_instance_valid(node):
		return null
	(node as Node3D).visible = true
	return node


func _clear_reserves() -> void:
	for reserve in [_chunk_reserve, _lawn_reserve]:
		for node_value in (reserve as Dictionary).values():
			var node := node_value as Node
			if node != null and is_instance_valid(node):
				node.queue_free()
		(reserve as Dictionary).clear()
	_chunk_reserve_order.clear()
	_lawn_reserve_order.clear()


## ═══════════════════════════════════════════════════════════════════════════
## 2026-09-30 — MULTITHREADING. Un chunk coute ~1 s d echantillonnage (DOL
## local, zone 8) : a 6-16 ms par image, la file mettait des minutes a remplir
## l anneau. Le calcul part sur le WorkerThreadPool, UN chunk a la fois (les
## caches d echantillonnage ne sont pas partages entre deux taches) ; la tache
## n ecrit que dans son `job` (compteurs compris). L installation dans la scene
## reste sur le thread principal. Decoche = file budgetee d avant, inchangee.
## ═══════════════════════════════════════════════════════════════════════════
@export var threaded_build := true
var _worker_task := -1
var _worker_job: Dictionary = {}

const _SAMPLE_REPORT_KEYS := ["fill_samples", "rejected_non_vegetal", "rejected_water",
	"rejected_building", "underwater_samples", "rejected_underwater", "shore_samples",
	"semantic_samples", "native_fallback_samples", "native_seed_samples", "vegetal_samples"]


func _pump_threaded() -> void:
	if _worker_task >= 0:
		if not WorkerThreadPool.is_task_completed(_worker_task):
			return
		_drain_worker()
	while not _build_queue.is_empty():
		var entry: Dictionary = _build_queue.pop_front()
		var key := "%d,%d" % [int(entry["cx"]), int(entry["cy"])]
		if not (_wanted_lawn if str(entry["kind"]) == "lawn" else _wanted_grass).has(key):
			continue
		var job: Dictionary
		if str(entry["kind"]) == "lawn":
			job = _lawn_job_begin(int(entry["cx"]), int(entry["cy"]))
		else:
			job = _chunk_job_begin(int(entry["cx"]), int(entry["cy"]), int(entry["lod"]))
			var rep := {}
			for k in _SAMPLE_REPORT_KEYS:
				rep[k] = 0
			job["report"] = rep
		job["qkey"] = entry["qkey"]
		job["distance"] = entry["distance"]
		_worker_job = job
		_worker_task = WorkerThreadPool.add_task(_run_job_in_worker.bind(job), false, "grass_chunk")
		return


func _run_job_in_worker(job: Dictionary) -> void:
	if str(job["kind"]) == "lawn":
		_lawn_job_step(job, -1)
	else:
		_chunk_job_step(job, -1)


## Attend la tache en cours puis l installe (si elle est toujours voulue).
func _drain_worker() -> void:
	if _worker_task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_worker_task)
	_worker_task = -1
	var job := _worker_job
	_worker_job = {}
	var rep: Dictionary = job.get("report", {}) as Dictionary
	for k in rep.keys():
		_report[k] = int(_report.get(k, 0)) + int(rep[k])
	if is_inside_tree():
		_install_job(job)
		_recount_report()


func _exit_tree() -> void:
	if _worker_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_worker_task)
		_worker_task = -1
		_worker_job = {}
