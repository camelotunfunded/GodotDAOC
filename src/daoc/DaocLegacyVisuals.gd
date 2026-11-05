extends RefCounted
class_name DaocLegacyVisuals

const DaocGrassRemasterScript = preload("res://src/daoc/vegetation/DaocGrassRemaster.gd")
const LocalLightShadowsScript = preload("res://src/daoc/lighting/DaocLocalLightShadows.gd")
const VEGETATION_MAP_THRESHOLD := 26 # 10 % de luminance, comme le seuil Remaster.

## P1-15C-A — legacy visual domains extracted from ZoneViewer.
## Owns old grass-card vegetation and approximate legacy lights.
## It remains visual/debug only: no gameplay, no collision, no network.

var _host: Node = null
## R6 - les services de zone, quand la configuration vient de DONNEES et non
## d'un hote. Les branches et l'echantillonnage du sol passent alors par eux.
var _services: RefCounted = null
var _viewer_sun: DirectionalLight3D = null
var _viewer_environment: Environment = null

var daoc_client_root: String = ""
var external_data_dir: String = ""
var world_scale: float = 1.0
var height_exaggeration: float = 1.0

var build_vegetation: bool = true
var vegetation_visible: bool = true
var vegetation_render_mode: int = 0
var outward_rocks_enabled: bool = false
var outward_flowers_enabled: bool = false
var vegetation_density: float = 0.85
var vegetation_sample_step: int = 2
var vegetation_max_instances_per_sector: int = 2400
var vegetation_density_threshold: float = 0.0
var vegetation_grass_presence_floor: float = 0.32
var vegetation_dense_floor: float = 0.40
var vegetation_max_cards_per_sample: int = 2
var vegetation_card_width: float = 8.2
var vegetation_card_height: float = 21.0
var vegetation_vertical_offset: float = 6.0
var vegetation_random_yaw: bool = true
var vegetation_exclude_water: bool = true
var vegetation_water_margin: float = 260.0
var vegetation_color: Color = Color(0.26, 0.42, 0.20, 0.86)
var vegetation_use_unshaded_material: bool = true
var vegetation_use_daoc_grass_csv: bool = true
var vegetation_grass_csv_name: String = "grass_alb.csv"
var vegetation_grass_atlas_name: String = ""
var vegetation_grass_group_offset: int = -1
var vegetation_csv_size_scale: float = 0.8
var vegetation_alpha_scissor_threshold: float = 0.32
var log_vegetation: bool = true

## R10 — les quinze réglages du Grass Remaster P1-20M.
##
## Ils étaient lus sur l'hôte PAR LEUR NOM, quinze `_host.get()` au moment de
## bâtir. C'est le même défaut qu'à R4 et R7, et il était le plus silencieux des
## trois : sur un hôte qui ne les déclare pas, `float(null)` vaut 0.0 et
## `int(null)` vaut 0, donc espacement nul, densité nulle, plafond
## d'instances nul — AUCUN brin d'herbe, et un nœud `GrassRemasterRuntime`
## parfaitement présent pour tout contrôle qui se contenterait de le compter.
##
## Les valeurs ci-dessous sont celles du BANC, relevées une à une dans
## `ZoneViewer.gd` ; sa scène enregistrée n'en surcharge aucune.
var grass_remaster_prefer_alternative_map: bool = true
var grass_remaster_alternative_map_name: String = "grassmapALT.pcx"
var grass_remaster_use_densemap: bool = false
var grass_remaster_chunk_size_raw: float = 4096.0
## Option graphique « Densite de l herbe » : 0 Bas, 1 Moyen, 2 Eleve.
var grass_detail_level: int = 2
var grass_remaster_spacing_raw: float = 60.0
var grass_remaster_autumn_groundcover_enabled: bool = true
var grass_remaster_fade_start_raw: float = 8500.0
var grass_remaster_fade_end_raw: float = 12000.0
var grass_remaster_density: float = 1.40
var grass_remaster_coverage_threshold: float = 0.10
var grass_remaster_max_instances_per_chunk: int = 5000
var grass_remaster_card_width_raw: float = 64.0
var grass_remaster_card_height_raw: float = 70.0
var grass_remaster_wind_strength: float = 30.0
var grass_remaster_wind_speed: float = 1.35
var grass_remaster_wind_gust_strength: float = 0.72
var grass_remaster_native_seed_enabled: bool = true
var grass_remaster_native_tree_radius_raw: float = 1450.0
var grass_remaster_native_plant_radius_raw: float = 900.0

var build_legacy_lights: bool = true
var legacy_lights_visible: bool = true
var legacy_light_energy: float = 3.0
var legacy_light_range: float = 4200.0
var legacy_light_attenuation: float = 0.18
var legacy_light_vertical_offset: float = 24.0
var use_legacy_light_type_colors: bool = true
var legacy_lights_cast_shadows: bool = false
## P1-91 : ombres des lampes, sous budget (voir DaocLocalLightShadows).
var legacy_light_shadow_budget: int = 4
var legacy_light_shadow_blur: float = 2.6
var legacy_light_shadow_opacity: float = 0.82
var legacy_lights_flicker: bool = true
var legacy_light_flicker_amount: float = 0.12
var legacy_lights_show_markers: bool = true
var legacy_light_marker_radius: float = 95.0
var legacy_lights_preview_dark_scene: bool = false
var legacy_preview_sun_energy: float = 0.0
var legacy_preview_ambient_energy: float = 0.015
var log_legacy_lights: bool = true


## R6 — configuration par DONNÉES, pour un hôte qui n'a pas d'inspecteur.
##
## `configure_from_host` reste le chemin du BANC, et ce n'est pas un oubli : le
## ZoneViewer relit ses propriétés à chaque image pour permettre le réglage à
## chaud depuis l'inspecteur distant. Une scène de jeu n'a rien à relire — elle
## passe ici un dictionnaire, une fois.
##
## Une clé absente laisse la valeur par défaut du module en place, au lieu de
## la remplacer par un zéro. C'est la différence exacte avec `host.get()` sur un
## hôte qui ne déclare pas la propriété : celui-là rend `null`, et `float(null)`
## vaut 0.0 — une végétation configurée à zéro qui a l'air d'être configurée.
func configure_from_settings(settings: Dictionary, services: RefCounted = null) -> void:
	_services = services
	for key: String in settings.keys():
		if key in SETTABLE_FIELDS:
			set(key, settings[key])


## Les champs qu'un réglage a le droit d'écrire. Une liste explicite plutôt
## qu'un `set()` libre : un dictionnaire de réglages venu d'ailleurs ne doit pas
## pouvoir écraser `_host` ou un cache interne.
const SETTABLE_FIELDS := [
	"daoc_client_root", "external_data_dir", "world_scale", "height_exaggeration",
	"build_vegetation", "vegetation_visible", "vegetation_render_mode",
	"outward_rocks_enabled", "outward_flowers_enabled",
	"vegetation_density", "vegetation_sample_step",
	"vegetation_max_instances_per_sector", "vegetation_density_threshold",
	"vegetation_grass_presence_floor", "vegetation_dense_floor",
	"vegetation_max_cards_per_sample", "vegetation_card_width",
	"vegetation_card_height", "vegetation_vertical_offset",
	"vegetation_random_yaw", "vegetation_exclude_water", "vegetation_water_margin",
	"vegetation_color", "vegetation_use_unshaded_material",
	"vegetation_use_daoc_grass_csv", "vegetation_grass_csv_name",
	"vegetation_grass_atlas_name", "vegetation_grass_group_offset",
	"vegetation_csv_size_scale", "vegetation_alpha_scissor_threshold",
	"log_vegetation",
	"grass_remaster_prefer_alternative_map", "grass_remaster_alternative_map_name",
	"grass_remaster_use_densemap", "grass_remaster_chunk_size_raw",
	"grass_remaster_spacing_raw", "grass_remaster_fade_start_raw",
	"grass_remaster_autumn_groundcover_enabled",
	"grass_remaster_fade_end_raw", "grass_remaster_density",
	"grass_remaster_coverage_threshold", "grass_remaster_max_instances_per_chunk",
	"grass_remaster_card_width_raw", "grass_remaster_card_height_raw",
	"grass_remaster_wind_strength", "grass_remaster_wind_speed",
	"grass_remaster_wind_gust_strength", "grass_remaster_native_seed_enabled",
	"grass_remaster_native_tree_radius_raw", "grass_remaster_native_plant_radius_raw",
	"grass_detail_level",
	"build_legacy_lights", "legacy_lights_visible", "legacy_light_energy",
	"legacy_light_range", "legacy_light_attenuation",
	"legacy_light_vertical_offset", "use_legacy_light_type_colors",
	"legacy_lights_cast_shadows", "legacy_lights_show_markers",
	"legacy_light_shadow_budget", "legacy_light_shadow_blur", "legacy_light_shadow_opacity",
	"legacy_lights_flicker", "legacy_light_flicker_amount",
	"legacy_light_marker_radius", "legacy_lights_preview_dark_scene",
	"legacy_preview_sun_energy", "legacy_preview_ambient_energy",
	"log_legacy_lights",
]


func configure_from_host(host: Node) -> void:
	_host = host
	if _host == null:
		return
	daoc_client_root = str(_host_get_or("daoc_client_root", daoc_client_root))
	external_data_dir = str(_host_get_or("external_data_dir", external_data_dir))
	world_scale = float(_host_get_or("world_scale", world_scale))
	height_exaggeration = float(_host_get_or("height_exaggeration", height_exaggeration))
	build_vegetation = bool(_host_get_or("build_vegetation", build_vegetation))
	vegetation_visible = bool(_host_get_or("vegetation_visible", vegetation_visible))
	vegetation_render_mode = int(_host_get_or("vegetation_render_mode", vegetation_render_mode))
	outward_rocks_enabled = bool(_host_get_or("outward_rocks_enabled", outward_rocks_enabled))
	outward_flowers_enabled = bool(_host_get_or("outward_flowers_enabled", outward_flowers_enabled))
	vegetation_density = float(_host_get_or("vegetation_density", vegetation_density))
	vegetation_sample_step = int(_host_get_or("vegetation_sample_step", vegetation_sample_step))
	vegetation_max_instances_per_sector = int(_host_get_or("vegetation_max_instances_per_sector", vegetation_max_instances_per_sector))
	vegetation_density_threshold = float(_host_get_or("vegetation_density_threshold", vegetation_density_threshold))
	vegetation_grass_presence_floor = float(_host_get_or("vegetation_grass_presence_floor", vegetation_grass_presence_floor))
	vegetation_dense_floor = float(_host_get_or("vegetation_dense_floor", vegetation_dense_floor))
	vegetation_max_cards_per_sample = int(_host_get_or("vegetation_max_cards_per_sample", vegetation_max_cards_per_sample))
	vegetation_card_width = float(_host_get_or("vegetation_card_width", vegetation_card_width))
	vegetation_card_height = float(_host_get_or("vegetation_card_height", vegetation_card_height))
	vegetation_vertical_offset = float(_host_get_or("vegetation_vertical_offset", vegetation_vertical_offset))
	vegetation_random_yaw = bool(_host_get_or("vegetation_random_yaw", vegetation_random_yaw))
	vegetation_exclude_water = bool(_host_get_or("vegetation_exclude_water", vegetation_exclude_water))
	vegetation_water_margin = float(_host_get_or("vegetation_water_margin", vegetation_water_margin))
	vegetation_color = _host.get("vegetation_color") as Color
	vegetation_use_unshaded_material = bool(_host_get_or("vegetation_use_unshaded_material", vegetation_use_unshaded_material))
	vegetation_use_daoc_grass_csv = bool(_host_get_or("vegetation_use_daoc_grass_csv", vegetation_use_daoc_grass_csv))
	vegetation_grass_csv_name = str(_host_get_or("vegetation_grass_csv_name", vegetation_grass_csv_name))
	vegetation_grass_atlas_name = str(_host_get_or("vegetation_grass_atlas_name", vegetation_grass_atlas_name))
	vegetation_grass_group_offset = int(_host_get_or("vegetation_grass_group_offset", vegetation_grass_group_offset))
	vegetation_csv_size_scale = float(_host_get_or("vegetation_csv_size_scale", vegetation_csv_size_scale))
	vegetation_alpha_scissor_threshold = float(_host_get_or("vegetation_alpha_scissor_threshold", vegetation_alpha_scissor_threshold))
	log_vegetation = bool(_host_get_or("log_vegetation", log_vegetation))
	# R10 — le Grass Remaster lisait ces quinze valeurs sur l'hôte au moment de
	# bâtir. Elles sont désormais des champs du module, et le banc les remplit
	# ici : son chemin est inchangé, y compris le réglage à chaud par image.
	grass_remaster_prefer_alternative_map = bool(_host_get_or("grass_remaster_prefer_alternative_map", grass_remaster_prefer_alternative_map))
	grass_remaster_alternative_map_name = str(_host_get_or("grass_remaster_alternative_map_name", grass_remaster_alternative_map_name))
	grass_remaster_use_densemap = bool(_host_get_or("grass_remaster_use_densemap", grass_remaster_use_densemap))
	grass_remaster_chunk_size_raw = float(_host_get_or("grass_remaster_chunk_size_raw", grass_remaster_chunk_size_raw))
	grass_remaster_spacing_raw = float(_host_get_or("grass_remaster_spacing_raw", grass_remaster_spacing_raw))
	grass_remaster_autumn_groundcover_enabled = bool(_host_get_or("grass_remaster_autumn_groundcover_enabled", grass_remaster_autumn_groundcover_enabled))
	grass_remaster_fade_start_raw = float(_host_get_or("grass_remaster_fade_start_raw", grass_remaster_fade_start_raw))
	grass_remaster_fade_end_raw = float(_host_get_or("grass_remaster_fade_end_raw", grass_remaster_fade_end_raw))
	grass_remaster_density = float(_host_get_or("grass_remaster_density", grass_remaster_density))
	grass_remaster_coverage_threshold = float(_host_get_or("grass_remaster_coverage_threshold", grass_remaster_coverage_threshold))
	grass_remaster_max_instances_per_chunk = int(_host_get_or("grass_remaster_max_instances_per_chunk", grass_remaster_max_instances_per_chunk))
	grass_remaster_card_width_raw = float(_host_get_or("grass_remaster_card_width_raw", grass_remaster_card_width_raw))
	grass_remaster_card_height_raw = float(_host_get_or("grass_remaster_card_height_raw", grass_remaster_card_height_raw))
	grass_remaster_wind_strength = float(_host_get_or("grass_remaster_wind_strength", grass_remaster_wind_strength))
	grass_remaster_wind_speed = float(_host_get_or("grass_remaster_wind_speed", grass_remaster_wind_speed))
	grass_remaster_wind_gust_strength = float(_host_get_or("grass_remaster_wind_gust_strength", grass_remaster_wind_gust_strength))
	grass_remaster_native_seed_enabled = bool(_host_get_or("grass_remaster_native_seed_enabled", grass_remaster_native_seed_enabled))
	grass_remaster_native_tree_radius_raw = float(_host_get_or("grass_remaster_native_tree_radius_raw", grass_remaster_native_tree_radius_raw))
	grass_remaster_native_plant_radius_raw = float(_host_get_or("grass_remaster_native_plant_radius_raw", grass_remaster_native_plant_radius_raw))
	build_legacy_lights = bool(_host_get_or("build_legacy_lights", build_legacy_lights))
	legacy_lights_visible = bool(_host_get_or("legacy_lights_visible", legacy_lights_visible))
	legacy_light_energy = float(_host_get_or("legacy_light_energy", legacy_light_energy))
	legacy_light_range = float(_host_get_or("legacy_light_range", legacy_light_range))
	legacy_light_attenuation = float(_host_get_or("legacy_light_attenuation", legacy_light_attenuation))
	legacy_light_vertical_offset = float(_host_get_or("legacy_light_vertical_offset", legacy_light_vertical_offset))
	use_legacy_light_type_colors = bool(_host_get_or("use_legacy_light_type_colors", use_legacy_light_type_colors))
	legacy_lights_cast_shadows = bool(_host_get_or("legacy_lights_cast_shadows", legacy_lights_cast_shadows))
	legacy_light_shadow_budget = int(_host_get_or("legacy_light_shadow_budget", legacy_light_shadow_budget))
	legacy_light_shadow_blur = float(_host_get_or("legacy_light_shadow_blur", legacy_light_shadow_blur))
	legacy_light_shadow_opacity = float(_host_get_or("legacy_light_shadow_opacity", legacy_light_shadow_opacity))
	legacy_lights_flicker = bool(_host_get_or("legacy_lights_flicker", legacy_lights_flicker))
	legacy_light_flicker_amount = float(_host_get_or("legacy_light_flicker_amount", legacy_light_flicker_amount))
	legacy_lights_show_markers = bool(_host_get_or("legacy_lights_show_markers", legacy_lights_show_markers))
	legacy_light_marker_radius = float(_host_get_or("legacy_light_marker_radius", legacy_light_marker_radius))
	legacy_lights_preview_dark_scene = bool(_host_get_or("legacy_lights_preview_dark_scene", legacy_lights_preview_dark_scene))
	legacy_preview_sun_energy = float(_host_get_or("legacy_preview_sun_energy", legacy_preview_sun_energy))
	legacy_preview_ambient_energy = float(_host_get_or("legacy_preview_ambient_energy", legacy_preview_ambient_energy))
	log_legacy_lights = bool(_host_get_or("log_legacy_lights", log_legacy_lights))
	_viewer_sun = _host.get("_viewer_sun") as DirectionalLight3D
	_viewer_environment = _host.get("_viewer_environment") as Environment


## R10 — l'hôte réel, quelle que soit la façon dont le module a été configuré.
##
## Le banc passe par `configure_from_host` et `_host` est le viewer. La scène de
## jeu passe par `configure_from_settings`, qui ne fixe volontairement PAS
## `_host` : c'est tout l'intérêt du découplage R6. Mais le Grass Remaster a
## besoin d'un nœud vivant pour suivre le joueur, et les services en portent un.
##
## Sans cela, `configure` recevait `null` et le Remaster plantait sur
## `_host.get("_player")` — un chemin que personne n'avait pu voir, puisque le
## jeu n'a jamais bâti de végétation avant R10.
func _effective_host() -> Node:
	if _host != null:
		return _host
	if _services != null:
		return _services.get("host") as Node
	return null


func _zone_branch_host(znum: int, branch_name: String) -> Node3D:
	if _host != null and _host.has_method("_zone_branch"):
		return _host.call("_zone_branch", znum, branch_name) as Node3D
	if _services != null and _services.has_method("zone_branch"):
		return _services.call("zone_branch", znum, branch_name) as Node3D
	return null


func _is_underwater_host(znum: int, wx: float, wy: float, floor_raw: float) -> bool:
	if _host == null or not _host.has_method("sample_daoc_water_info"):
		return false
	var info: Dictionary = _host.call("sample_daoc_water_info", znum, wx, wy, floor_raw) as Dictionary
	return not info.is_empty() and float(info.get("height", -1.0e9)) > floor_raw + 1.0


func _sample_floor_host(znum: int, wx: float, wy: float, fallback_z: float = 0.0) -> float:
	if _host != null and _host.has_method("sample_daoc_floor_z"):
		return float(_host.call("sample_daoc_floor_z", znum, wx, wy, fallback_z))
	if _services != null and _services.has_method("sample_floor_z"):
		return float(_services.call("sample_floor_z", znum, wx, wy, fallback_z))
	return fallback_z


func _tree() -> SceneTree:
	var host := _effective_host()
	return host.get_tree() if host != null and host.is_inside_tree() else null


## `host.get()` sur une propriete que l'hote ne declare pas rend null, et
## `float(null)` vaut 0 : un reglage absent deviendrait un zero silencieux
## (piege R7). Les reglages ajoutes apres coup passent par ici.
func _host_get_or(property: String, fallback: Variant) -> Variant:
	if _host == null:
		return fallback
	var value: Variant = _host.get(property)
	return fallback if value == null else value


func _norm_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p


func _effective_data_dir() -> String:
	var d := _norm_path(external_data_dir)
	if d != "":
		return d
	var root := _effective_daoc_root()
	if root != "":
		return root.path_join("_godot_daoc_cache").path_join("data")
	return "res://data"


func _effective_daoc_root() -> String:
	var root := _norm_path(daoc_client_root)
	if root != "":
		return root
	var d := _norm_path(external_data_dir)
	var marker := "/_godot_daoc_cache/data"
	if d.to_lower().ends_with(marker):
		return d.substr(0, d.length() - marker.length())
	return ""


func build_zone_vegetation(znum: int, origin3: Vector3, hb: PackedByteArray, res: int) -> void:
	if not build_vegetation:
		return
	var grass_path: String = _find_zone_dat_asset(znum, "grassmap.pcx")
	if grass_path == "":
		if log_vegetation:
			print("zone%03d vegetation: no grassmap.pcx found" % znum)
		return
	var dense_path: String = _find_zone_dat_asset(znum, "densemap.pcx")
	var grass: Dictionary = _decode_pcx8(grass_path)
	if grass.is_empty():
		push_warning("vegetation: cannot decode grassmap %s" % grass_path)
		return
	var dense: Dictionary = {}
	if dense_path != "":
		dense = _decode_pcx8(dense_path)
	var grass_pixels: PackedByteArray = grass.get("pixels", PackedByteArray())
	var dense_pixels: PackedByteArray = dense.get("pixels", PackedByteArray())
	var w: int = int(grass.get("width", 0))
	var h: int = int(grass.get("height", 0))
	if w <= 0 or h <= 0 or grass_pixels.is_empty():
		return
	var grass_max: int = max(1, int(grass.get("max", 255)))
	var dense_max: int = max(1, int(dense.get("max", 255)))

	var root: Node3D = Node3D.new()
	root.name = "Zone%03d_Vegetation" % znum
	root.visible = vegetation_visible
	root.add_to_group("daoc_vegetation_root")
	_zone_branch_host(znum, "VegetationRoot").add_child(root)

	var water_masks: Array[Dictionary] = []
	if vegetation_exclude_water:
		water_masks = _load_zone_water_bands_for_vegetation(znum)

	if vegetation_render_mode == 1:
		var remaster_grass: Dictionary = grass
		var remaster_grass_path := grass_path
		var strict_alternative_authority := false
		var alternative_difference: Dictionary = {}
		if grass_remaster_prefer_alternative_map:
			var alternative_name := grass_remaster_alternative_map_name.strip_edges()
			if alternative_name != "":
				var alternative_path := _find_zone_dat_asset(znum, alternative_name)
				if alternative_path != "":
					var alternative := _decode_pcx8(alternative_path)
					if not alternative.is_empty():
						remaster_grass = alternative
						remaster_grass_path = alternative_path
						strict_alternative_authority = true
						alternative_difference = _grassmap_difference_report(grass, alternative)
		var remaster: Node = DaocGrassRemasterScript.new()
		remaster.name = "GrassRemasterRuntime"
		root.add_child(remaster)
		remaster.call("configure", _effective_host(), znum, origin3, hb, res, remaster_grass, dense,
			water_masks, {
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"client_root": _effective_daoc_root(),
				"data_dir": _effective_data_dir(),
				"grass_map_path": remaster_grass_path,
				"strict_grassmap_authority": strict_alternative_authority,
				"original_grass_data": grass if strict_alternative_authority else {},
				"use_densemap": grass_remaster_use_densemap,
				"outward_rocks_enabled": outward_rocks_enabled,
				"outward_flowers_enabled": outward_flowers_enabled,
				"water_margin_raw": 96.0,
				"original_densemap_diagnostic": _grass_dense_relation_report(grass, dense),
				"alternative_difference": alternative_difference,
				"chunk_size_raw": grass_remaster_chunk_size_raw,
				"spacing_raw": grass_remaster_spacing_raw,
				"autumn_groundcover_enabled": grass_remaster_autumn_groundcover_enabled,
				"fade_start_raw": grass_remaster_fade_start_raw,
				"fade_end_raw": grass_remaster_fade_end_raw,
				"density": grass_remaster_density,
				"coverage_threshold": grass_remaster_coverage_threshold,
				"max_instances_per_chunk": grass_remaster_max_instances_per_chunk,
				"vertical_offset_raw": vegetation_vertical_offset,
				"card_width_raw": grass_remaster_card_width_raw,
				"card_height_raw": grass_remaster_card_height_raw,
				"wind_strength": grass_remaster_wind_strength,
				"wind_speed": grass_remaster_wind_speed,
				"wind_gust_strength": grass_remaster_wind_gust_strength,
				"native_seed_enabled": grass_remaster_native_seed_enabled,
				"native_tree_radius_raw": grass_remaster_native_tree_radius_raw,
				"native_plant_radius_raw": grass_remaster_native_plant_radius_raw,
				"grass_detail_level": grass_detail_level,
			})
		if log_vegetation:
			print("zone%03d vegetation: Grass Remaster actif map=%s stricte=%s densemap=%s" % [
				znum, remaster_grass_path.get_file(), str(strict_alternative_authority),
				str(grass_remaster_use_densemap)])
		return

	var csv_info: Dictionary = _load_daoc_grass_csv_info(znum)
	var atlas_info: Dictionary = _load_daoc_grass_atlas_info(znum, str(csv_info.get("path", "")))
	var atlas_texture: Texture2D = atlas_info.get("texture", null) as Texture2D
	var atlas_w: int = int(atlas_info.get("width", 0))
	var atlas_h: int = int(atlas_info.get("height", 0))
	var grouped_defs: Dictionary = {}
	var grouped_defs_var: Variant = csv_info.get("groups", {})
	if grouped_defs_var is Dictionary:
		grouped_defs = grouped_defs_var
	var use_daoc_csv: bool = vegetation_use_daoc_grass_csv and atlas_texture != null and atlas_w > 0 and atlas_h > 0 and not grouped_defs.is_empty()

	var fallback_mesh: ArrayMesh = _make_grass_card_mesh()
	var fallback_mat: Material = _make_grass_material()
	var mesh_cache: Dictionary = {}
	var material_cache: Dictionary = {}

	var total_instances: int = 0
	var candidate_samples: int = 0
	var spawn_attempts: int = 0
	var rejected_water: int = 0
	var missing_group_samples: int = 0
	var sector_px_x: int = max(1, w / 8)
	var sector_px_y: int = max(1, h / 8)
	var step: int = maxi(1, vegetation_sample_step)
	for sy in 8:
		for sx in 8:
			var sector_batches: Dictionary = {}
			var x0: int = sx * sector_px_x
			var y0: int = sy * sector_px_y
			var x1: int = mini(w, x0 + sector_px_x)
			var y1: int = mini(h, y0 + sector_px_y)
			var sector_instance_total: int = 0
			for py in range(y0, y1, step):
				if sector_instance_total >= vegetation_max_instances_per_sector:
					break
				for px in range(x0, x1, step):
					if sector_instance_total >= vegetation_max_instances_per_sector:
						break
					var idx: int = py * w + px
					var grass_raw: int = int(grass_pixels[idx])
					if grass_raw <= 0:
						continue
					candidate_samples += 1
					var grass_level: float = clampf(float(grass_raw) / float(grass_max), 0.0, 1.0)
					var grass_presence: float = clampf(maxf(grass_level, vegetation_grass_presence_floor), 0.0, 1.0)
					var dense_level: float = 1.0
					if dense_pixels.size() == grass_pixels.size():
						dense_level = clampf(float(dense_pixels[idx]) / float(dense_max), 0.0, 1.0)
					var dense_weight: float = lerpf(vegetation_dense_floor, 1.0, dense_level)
					var spawn_score: float = grass_presence * dense_weight * vegetation_density
					if spawn_score < vegetation_density_threshold:
						continue
					var spawn_count: int = int(floor(spawn_score))
					var fractional: float = spawn_score - float(spawn_count)
					if _stable_rand01(znum + 17, px, py) < fractional:
						spawn_count += 1
					spawn_count = mini(spawn_count, vegetation_max_cards_per_sample)
					if spawn_count <= 0:
						continue
					var group_id: int = _grass_group_from_map_value(grass_raw)
					for spawn_i in spawn_count:
						if sector_instance_total >= vegetation_max_instances_per_sector:
							break
						spawn_attempts += 1
						var seed_x: int = px + spawn_i * 101
						var seed_y: int = py + spawn_i * 211
						var jitter_span: float = float(step) * 256.0 * 0.85
						var jx: float = (_stable_rand01(znum + 31, seed_x, seed_y) - 0.5) * jitter_span
						var jy: float = (_stable_rand01(znum + 47, seed_x, seed_y) - 0.5) * jitter_span
						var wx: float = clampf((float(px) + 0.5) / float(w) * 65536.0 + jx, 0.0, 65535.0)
						var wy: float = clampf((float(py) + 0.5) / float(h) * 65536.0 + jy, 0.0, 65535.0)
						if vegetation_exclude_water and _is_daoc_xy_inside_water_bands(wx, wy, water_masks):
							rejected_water += 1
							continue
						var h_units: float = _sample_floor_host(znum, wx, wy, 0.0)
						# 2026-09-15 : sous la surface d'un plan d'eau par HAUTEUR, un brin sur dix.
						if _is_underwater_host(znum, wx, wy, h_units) and _stable_rand01(znum + 83, seed_x, seed_y) > 0.1:
							rejected_water += 1
							continue
						var pos: Vector3 = origin3 + Vector3(
							wx * world_scale,
							h_units * world_scale * height_exaggeration + vegetation_vertical_offset * world_scale,
							wy * world_scale
						)
						var yaw: float = 0.0
						if vegetation_random_yaw:
							yaw = _stable_rand01(znum + 59, seed_x, seed_y) * TAU
						var random_scale: float = lerpf(0.70, 1.22, _stable_rand01(znum + 71, seed_x, seed_y))
						var density_scale: float = lerpf(0.78, 1.18, grass_level)
						var mesh_key: String = "fallback"
						var mesh_scale: float = random_scale * density_scale
						if use_daoc_csv:
							var def: Dictionary = _pick_daoc_grass_def(grouped_defs, group_id, znum, seed_x, seed_y)
							if def.is_empty():
								missing_group_samples += 1
							else:
								mesh_key = "def_%03d" % int(def.get("id", 0))
								if not mesh_cache.has(mesh_key):
									mesh_cache[mesh_key] = _make_daoc_grass_card_mesh(def, atlas_w, atlas_h)
								if not material_cache.has(mesh_key):
									material_cache[mesh_key] = _make_daoc_grass_material(atlas_texture, def)
								mesh_scale *= _grass_def_instance_scale(def, znum, seed_x, seed_y)
						var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * mesh_scale)
						var transforms: Array = []
						if sector_batches.has(mesh_key):
							transforms = sector_batches[mesh_key]
						transforms.append(Transform3D(basis, pos))
						sector_batches[mesh_key] = transforms
						sector_instance_total += 1
			for key_var in sector_batches.keys():
				var mesh_key_out: String = str(key_var)
				var transforms_out: Array = sector_batches[mesh_key_out]
				if transforms_out.is_empty():
					continue
				var mesh_out: ArrayMesh = fallback_mesh
				var mat_out: Material = fallback_mat
				if mesh_cache.has(mesh_key_out):
					mesh_out = mesh_cache[mesh_key_out] as ArrayMesh
				if material_cache.has(mesh_key_out):
					mat_out = material_cache[mesh_key_out] as Material
				var mm: MultiMesh = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh_out
				mm.instance_count = transforms_out.size()
				for i in transforms_out.size():
					var tr: Transform3D = transforms_out[i]
					mm.set_instance_transform(i, tr)
				var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
				if mesh_key_out == "fallback":
					mmi.name = "grass_%02d_%02d_fallback" % [sx, sy]
				else:
					mmi.name = "grass_%02d_%02d_%s" % [sx, sy, mesh_key_out]
				mmi.multimesh = mm
				mmi.material_override = mat_out
				mmi.add_to_group("daoc_vegetation")
				root.add_child(mmi)
				total_instances += transforms_out.size()

	if log_vegetation:
		var dense_label: String = dense_path if dense_path != "" else "<none>"
		var water_label: String = "water-filter rejected %d" % rejected_water if vegetation_exclude_water else "water-filter off"
		if use_daoc_csv:
			print("zone%03d vegetation: %d DAoC grass card(s) from %s + %s; csv=%s atlas=%s; candidates=%d attempts=%d missing_groups=%d; %s" % [znum, total_instances, grass_path, dense_label, str(csv_info.get("path", "")), str(atlas_info.get("path", "")), candidate_samples, spawn_attempts, missing_group_samples, water_label])
		else:
			print("zone%03d vegetation: %d fallback grass card(s) from %s + %s; candidates=%d attempts=%d; %s" % [znum, total_instances, grass_path, dense_label, candidate_samples, spawn_attempts, water_label])


func _load_daoc_grass_csv_info(znum: int) -> Dictionary:
	var out: Dictionary = {"path": "", "groups": {}}
	if not vegetation_use_daoc_grass_csv:
		return out
	var csv_path: String = _find_daoc_grass_csv_asset(znum)
	if csv_path == "":
		return out
	var f: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		return out
	var groups: Dictionary = {}
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "" or line.begins_with("ID,") or line.begins_with(",,"):
			continue
		var cols: PackedStringArray = line.split(",", true)
		if cols.size() < 16:
			continue
		var id_val: int = _csv_int(cols, 0, -1)
		if id_val <= 0:
			continue
		var group_id: int = _csv_int(cols, 2, -1)
		if group_id < 0:
			continue
		var def: Dictionary = {
			"id": id_val,
			"name": _csv_col(cols, 1),
			"group": group_id,
			"chance": maxf(0.0, _csv_float(cols, 3, 0.0)),
			"shape": _csv_int(cols, 4, 0),
			"height": maxf(1.0, _csv_float(cols, 5, 16.0)),
			"delta_height": maxf(0.0, _csv_float(cols, 6, 0.0)),
			"length": maxf(1.0, _csv_float(cols, 7, 12.0)),
			"delta_length": maxf(0.0, _csv_float(cols, 8, 0.0)),
			"width": maxf(1.0, _csv_float(cols, 9, 8.0)),
			"delta_width": maxf(0.0, _csv_float(cols, 10, 0.0)),
			"delta_scale": maxf(0.0, _csv_float(cols, 11, 0.0)),
			"x1": _csv_float(cols, 12, 0.0),
			"x2": _csv_float(cols, 13, 1.0),
			"y1": _csv_float(cols, 14, 0.0),
			"y2": _csv_float(cols, 15, 1.0),
			"has_rgb": _csv_col(cols, 16) != "" and _csv_col(cols, 17) != "" and _csv_col(cols, 18) != "",
			"r": _csv_float(cols, 16, 255.0),
			"g": _csv_float(cols, 17, 255.0),
			"b": _csv_float(cols, 18, 255.0),
		}
		var arr: Array = []
		if groups.has(group_id):
			arr = groups[group_id] as Array
		arr.append(def)
		groups[group_id] = arr
	f.close()
	out["path"] = csv_path
	out["groups"] = groups
	return out


func _load_daoc_grass_atlas_info(znum: int, csv_path: String) -> Dictionary:
	var out: Dictionary = {"path": "", "texture": null, "width": 0, "height": 0}
	var atlas_path: String = _find_daoc_grass_atlas_asset(znum, csv_path)
	if atlas_path == "":
		return out
	var img: Image = Image.new()
	var err: int = img.load(atlas_path)
	if err != OK:
		return out
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	out["path"] = atlas_path
	out["texture"] = tex
	out["width"] = img.get_width()
	out["height"] = img.get_height()
	return out


func _find_daoc_grass_csv_asset(znum: int) -> String:
	if vegetation_grass_csv_name.strip_edges() != "":
		var explicit_path: String = _find_zones_texture_asset(vegetation_grass_csv_name.strip_edges())
		if explicit_path != "":
			return explicit_path
	var fallback_names: Array[String] = ["grass_alb.csv", "grass_albexp.csv", "grass_mid.csv", "grass_midexp.csv", "grass_hib.csv", "grass_hibexp.csv"]
	for name in fallback_names:
		var p: String = _find_zones_texture_asset(name)
		if p != "":
			return p
	return ""


func _find_daoc_grass_atlas_asset(znum: int, csv_path: String) -> String:
	var names: Array[String] = []
	if vegetation_grass_atlas_name.strip_edges() != "":
		names.append(vegetation_grass_atlas_name.strip_edges())
	if csv_path != "":
		var csv_name: String = csv_path.get_file()
		var dot: int = csv_name.rfind(".")
		var base: String = csv_name.substr(0, dot) if dot >= 0 else csv_name
		names.append(base + ".png")
		names.append(base + ".PNG")
		names.append(base + ".dds.png")
		names.append(base + ".DDS.png")
		names.append(base + ".webp")
		names.append(base + ".dds")
		names.append(base + ".DDS")
	for name in names:
		var p: String = _find_zones_texture_asset(name)
		if p != "":
			return p
	return ""


func _find_zones_texture_asset(file_name: String) -> String:
	var data_dir: String = _effective_data_dir()
	var root: String = _effective_daoc_root()
	var names: Array[String] = []
	names.append(file_name)
	names.append(file_name.to_lower())
	names.append(file_name.to_upper())
	var candidates: Array[String] = []
	for name in names:
		candidates.append(data_dir.path_join(name))
		candidates.append(data_dir.path_join("textures").path_join(name))
		candidates.append(data_dir.path_join("zones").path_join("textures").path_join(name))
	if root != "":
		var texture_roots: Array[String] = [
			root.path_join("zones").path_join("textures"),
			root.path_join("frontiers").path_join("zones").path_join("textures"),
			root.path_join("phousing").path_join("zones").path_join("textures"),
			root.path_join("tutorial").path_join("zones").path_join("textures"),
			root.path_join("Tutorial").path_join("zones").path_join("textures"),
		]
		for tr in texture_roots:
			for name in names:
				candidates.append(tr.path_join(name))
	for p in candidates:
		if p != "" and FileAccess.file_exists(p):
			return p
	return ""


func _grass_group_from_map_value(grass_raw: int) -> int:
	var group_id: int = int(round(float(grass_raw) / 10.0)) + vegetation_grass_group_offset
	return maxi(0, group_id)


func _pick_daoc_grass_def(groups: Dictionary, group_id: int, znum: int, sx: int, sy: int) -> Dictionary:
	var defs: Array = []
	if groups.has(group_id):
		defs = groups[group_id] as Array
	elif groups.has(group_id - 1):
		defs = groups[group_id - 1] as Array
	elif groups.has(group_id + 1):
		defs = groups[group_id + 1] as Array
	elif groups.has(0):
		defs = groups[0] as Array
	if defs.is_empty():
		return {}
	var total: float = 0.0
	for def_var in defs:
		var def: Dictionary = def_var as Dictionary
		total += maxf(0.0, float(def.get("chance", 0.0)))
	if total <= 0.0:
		return defs[0]
	var roll: float = _stable_rand01(znum + 101, sx, sy) * total
	var acc: float = 0.0
	for def_var in defs:
		var def: Dictionary = def_var as Dictionary
		acc += maxf(0.0, float(def.get("chance", 0.0)))
		if roll <= acc:
			return def
	return defs[defs.size() - 1]


func _grass_def_instance_scale(def: Dictionary, znum: int, sx: int, sy: int) -> float:
	var delta_scale: float = float(def.get("delta_scale", 0.0)) / 100.0
	if delta_scale <= 0.0:
		return 1.0
	return 1.0 + (_stable_rand01(znum + 131, sx, sy) * 2.0 - 1.0) * delta_scale


func _make_daoc_grass_card_mesh(def: Dictionary, atlas_w: int, atlas_h: int) -> ArrayMesh:
	var shape: int = int(def.get("shape", 0))
	var height_units: float = maxf(1.0, float(def.get("height", 16.0))) * vegetation_csv_size_scale
	var width_units: float = maxf(float(def.get("width", 8.0)), float(def.get("length", 12.0))) * vegetation_csv_size_scale
	var half_w: float = width_units * world_scale * 0.5
	var h: float = height_units * world_scale
	var u0: float = clampf(float(def.get("x1", 0.0)) / maxf(1.0, float(atlas_w)), 0.0, 1.0)
	var u1: float = clampf(float(def.get("x2", 1.0)) / maxf(1.0, float(atlas_w)), 0.0, 1.0)
	var v0: float = clampf(float(def.get("y1", 0.0)) / maxf(1.0, float(atlas_h)), 0.0, 1.0)
	var v1: float = clampf(float(def.get("y2", 1.0)) / maxf(1.0, float(atlas_h)), 0.0, 1.0)
	if u1 <= u0:
		u1 = minf(1.0, u0 + 0.01)
	if v1 <= v0:
		v1 = minf(1.0, v0 + 0.01)
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	if shape == 2:
		# Shape 2 appears to be used by small rocks/leaves: keep it close to the ground.
		verts.append(Vector3(-half_w, 0.0, -half_w)); uvs.append(Vector2(u0, v1)); normals.append(Vector3.UP)
		verts.append(Vector3( half_w, 0.0, -half_w)); uvs.append(Vector2(u1, v1)); normals.append(Vector3.UP)
		verts.append(Vector3( half_w, 0.0,  half_w)); uvs.append(Vector2(u1, v0)); normals.append(Vector3.UP)
		verts.append(Vector3(-half_w, 0.0,  half_w)); uvs.append(Vector2(u0, v0)); normals.append(Vector3.UP)
		indices.append_array([0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0])
	else:
		verts.append(Vector3(-half_w, 0.0, 0.0)); uvs.append(Vector2(u0, v1)); normals.append(Vector3(0.0, 0.0, 1.0))
		verts.append(Vector3( half_w, 0.0, 0.0)); uvs.append(Vector2(u1, v1)); normals.append(Vector3(0.0, 0.0, 1.0))
		verts.append(Vector3( half_w, h,   0.0)); uvs.append(Vector2(u1, v0)); normals.append(Vector3(0.0, 0.0, 1.0))
		verts.append(Vector3(-half_w, h,   0.0)); uvs.append(Vector2(u0, v0)); normals.append(Vector3(0.0, 0.0, 1.0))
		verts.append(Vector3(0.0, 0.0, -half_w)); uvs.append(Vector2(u0, v1)); normals.append(Vector3(1.0, 0.0, 0.0))
		verts.append(Vector3(0.0, 0.0,  half_w)); uvs.append(Vector2(u1, v1)); normals.append(Vector3(1.0, 0.0, 0.0))
		verts.append(Vector3(0.0, h,    half_w)); uvs.append(Vector2(u1, v0)); normals.append(Vector3(1.0, 0.0, 0.0))
		verts.append(Vector3(0.0, h,   -half_w)); uvs.append(Vector2(u0, v0)); normals.append(Vector3(1.0, 0.0, 0.0))
		indices.append_array([0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0])
		indices.append_array([4, 5, 6, 4, 6, 7, 6, 5, 4, 7, 6, 4])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_daoc_grass_material(atlas_texture: Texture2D, def: Dictionary) -> Material:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = atlas_texture
	mat.albedo_color = _grass_def_color(def)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = vegetation_alpha_scissor_threshold
	if vegetation_use_unshaded_material:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _grass_def_color(def: Dictionary) -> Color:
	if bool(def.get("has_rgb", false)):
		return Color(clampf(float(def.get("r", 255.0)) / 255.0, 0.0, 1.0), clampf(float(def.get("g", 255.0)) / 255.0, 0.0, 1.0), clampf(float(def.get("b", 255.0)) / 255.0, 0.0, 1.0), 1.0)
	return Color.WHITE


func _csv_col(cols: PackedStringArray, idx: int) -> String:
	if idx < 0 or idx >= cols.size():
		return ""
	return cols[idx].strip_edges()


func _csv_int(cols: PackedStringArray, idx: int, default_value: int = 0) -> int:
	var s: String = _csv_col(cols, idx)
	if s == "":
		return default_value
	return int(float(s))


func _csv_float(cols: PackedStringArray, idx: int, default_value: float = 0.0) -> float:
	var s: String = _csv_col(cols, idx)
	if s == "":
		return default_value
	return float(s)


func _find_sector_dat(znum: int) -> String:
	if _host != null and _host.has_method("_find_sector_dat"):
		return str(_host.call("_find_sector_dat", znum))
	# Scene de jeu (R6+) : pas d'hote, les services portent le SECTOR.DAT.
	# Sans ce repli, la vegetation du jeu ignorait les bandes d'eau en silence.
	if _services != null and _services.has_method("sector_dat_path"):
		return str(_services.call("sector_dat_path", znum))
	return ""


func _parse_sector_dat(path: String) -> Dictionary:
	if _host != null and _host.has_method("_parse_sector_dat"):
		var parsed: Variant = _host.call("_parse_sector_dat", path)
		if parsed is Dictionary:
			return parsed as Dictionary
	if _services != null and _services.has_method("parse_sector_dat"):
		var parsed_services: Variant = _services.call("parse_sector_dat", path)
		if parsed_services is Dictionary:
			return parsed_services as Dictionary
	return {}


func _load_zone_water_bands_for_vegetation(znum: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sector_path := _find_sector_dat(znum)
	if sector_path == "":
		return out
	var sector := _parse_sector_dat(sector_path)
	if sector.is_empty() or not sector.has("waterdefs"):
		return out
	var waterdefs: Dictionary = sector.get("waterdefs", {})
	var body_count := int(str(waterdefs.get("num", "0")))
	for i in body_count:
		var section_name := "river%02d" % i
		if not sector.has(section_name):
			continue
		var body: Dictionary = sector[section_name]
		var bankpoints := int(str(body.get("bankpoints", "0")))
		if bankpoints < 2:
			continue
		var lefts: Array[Vector2] = []
		var rights: Array[Vector2] = []
		for j in bankpoints:
			if not body.has("left%02d" % j) or not body.has("right%02d" % j):
				continue
			lefts.append(_sector_dat_point_2d_units(str(body.get("left%02d" % j, "0,0,0"))))
			rights.append(_sector_dat_point_2d_units(str(body.get("right%02d" % j, "0,0,0"))))
		# 2026-09-29 : OCEAN et SWAMP sont des nappes a hauteur fixe couvrant la
		# terre emergee (Lyonesse) ; le filtre de hauteur ci-dessous les juge.
		var water_type := str(body.get("type", "")).strip_edges().to_upper()
		if water_type.contains("OCEAN") or water_type.contains("SWAMP"):
			continue
		if lefts.size() >= 2 and rights.size() == lefts.size():
			out.append({"lefts": lefts, "rights": rights, "section": section_name,
				"type": str(body.get("type", "")).strip_edges().to_upper()})
	return out


func _sector_dat_point_2d_units(value: String) -> Vector2:
	var parts := value.split(",", false)
	if parts.size() >= 2:
		return Vector2(float(parts[0].strip_edges()) * 256.0, float(parts[1].strip_edges()) * 256.0)
	return Vector2.ZERO


func _is_daoc_xy_inside_water_bands(wx: float, wy: float, water_bands: Array[Dictionary]) -> bool:
	if water_bands.is_empty():
		return false
	var p := Vector2(wx, wy)
	for body in water_bands:
		var lefts: Array = body.get("lefts", [])
		var rights: Array = body.get("rights", [])
		var count: int = mini(lefts.size(), rights.size())
		if count < 2:
			continue
		for i in count - 1:
			var l0: Vector2 = lefts[i]
			var r0: Vector2 = rights[i]
			var l1: Vector2 = lefts[i + 1]
			var r1: Vector2 = rights[i + 1]
			var c0 := (l0 + r0) * 0.5
			var c1 := (l1 + r1) * 0.5
			var half_width := maxf(l0.distance_to(r0), l1.distance_to(r1)) * 0.5 + vegetation_water_margin
			if _distance_point_to_segment_2d(p, c0, c1) <= half_width:
				return true
	return false


func _distance_point_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _make_grass_card_mesh() -> ArrayMesh:
	var half_w: float = vegetation_card_width * world_scale * 0.5
	var h: float = vegetation_card_height * world_scale
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	# Quad 1: vertical plane along local X.
	verts.append(Vector3(-half_w, 0.0, 0.0)); uvs.append(Vector2(0.0, 1.0)); normals.append(Vector3(0.0, 0.0, 1.0))
	verts.append(Vector3( half_w, 0.0, 0.0)); uvs.append(Vector2(1.0, 1.0)); normals.append(Vector3(0.0, 0.0, 1.0))
	verts.append(Vector3( half_w, h,   0.0)); uvs.append(Vector2(1.0, 0.0)); normals.append(Vector3(0.0, 0.0, 1.0))
	verts.append(Vector3(-half_w, h,   0.0)); uvs.append(Vector2(0.0, 0.0)); normals.append(Vector3(0.0, 0.0, 1.0))
	# Quad 2: crossed plane along local Z.
	verts.append(Vector3(0.0, 0.0, -half_w)); uvs.append(Vector2(0.0, 1.0)); normals.append(Vector3(1.0, 0.0, 0.0))
	verts.append(Vector3(0.0, 0.0,  half_w)); uvs.append(Vector2(1.0, 1.0)); normals.append(Vector3(1.0, 0.0, 0.0))
	verts.append(Vector3(0.0, h,    half_w)); uvs.append(Vector2(1.0, 0.0)); normals.append(Vector3(1.0, 0.0, 0.0))
	verts.append(Vector3(0.0, h,   -half_w)); uvs.append(Vector2(0.0, 0.0)); normals.append(Vector3(1.0, 0.0, 0.0))
	var indices := PackedInt32Array()
	indices.append_array([0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0])
	indices.append_array([4, 5, 6, 4, 6, 7, 6, 5, 4, 7, 6, 4])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_grass_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vegetation_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic = 0.0
	if vegetation_color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if vegetation_use_unshaded_material:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func apply_vegetation_runtime_settings() -> void:
	# R6 - sans hote, pas d'arbre : ce reglage a chaud est propre au banc.
	if _tree() == null:
		return
	var enabled := build_vegetation and vegetation_visible
	for root in _tree().get_nodes_in_group("daoc_vegetation_root"):
		if root is Node3D:
			(root as Node3D).visible = enabled


func _stable_rand01(a: int, b: int, c: int) -> float:
	var n: int = int((a * 73856093) ^ (b * 19349663) ^ (c * 83492791))
	n = abs(n % 1000000)
	return float(n) / 1000000.0


func _find_zone_dat_asset(znum: int, file_name: String) -> String:
	var zp := "zone%03d" % znum
	var dp := "dat%03d" % znum
	var cp := "csv%03d" % znum
	var data_dir := _effective_data_dir()
	var root := _effective_daoc_root()
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
		var zone_roots: Array[String] = [
			root.path_join("zones").path_join(zp),
			root.path_join("frontiers/zones").path_join(zp),
			root.path_join("phousing/zones").path_join(zp),
			root.path_join("tutorial/zones").path_join(zp),
			root.path_join("zones"),
			root.path_join("frontiers/zones"),
			root.path_join("phousing/zones"),
			root.path_join("tutorial/zones"),
		]
		for zr in zone_roots:
			candidates.append(zr.path_join(dp).path_join(file_name))
			candidates.append(zr.path_join(cp).path_join(file_name))
			candidates.append(zr.path_join("dat").path_join(file_name))
			candidates.append(zr.path_join("csv").path_join(file_name))
			candidates.append(zr.path_join(file_name))
			candidates.append(zr.path_join("terrain").path_join(file_name))
	for p in candidates:
		if p != "" and FileAccess.file_exists(p):
			return p
	return ""


func _decode_pcx8(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if data.size() < 128 or int(data[0]) != 10:
		return {}
	var bits_per_pixel: int = int(data[3])
	var x_min: int = int(data[4]) | (int(data[5]) << 8)
	var y_min: int = int(data[6]) | (int(data[7]) << 8)
	var x_max: int = int(data[8]) | (int(data[9]) << 8)
	var y_max: int = int(data[10]) | (int(data[11]) << 8)
	var w: int = x_max - x_min + 1
	var h: int = y_max - y_min + 1
	var planes: int = int(data[65])
	var bytes_per_line: int = int(data[66]) | (int(data[67]) << 8)
	if bits_per_pixel != 8 or planes < 1 or w <= 0 or h <= 0 or bytes_per_line <= 0:
		return {}
	var raw := PackedByteArray()
	raw.resize(h * bytes_per_line * planes)
	var src: int = 128
	var dst: int = 0
	while src < data.size() and dst < raw.size():
		var b: int = int(data[src])
		src += 1
		var count: int = 1
		var value: int = b
		if (b & 0xC0) == 0xC0 and src < data.size():
			count = b & 0x3F
			value = int(data[src])
			src += 1
		for _i in count:
			if dst >= raw.size():
				break
			raw[dst] = value
			dst += 1
	var pixels := PackedByteArray()
	pixels.resize(w * h)
	var max_v: int = 0
	for row in h:
		var row_src: int = row * bytes_per_line * planes
		for col in w:
			var v: int = int(raw[row_src + col])
			pixels[row * w + col] = v
			if v > max_v:
				max_v = v
	# Les cartes de zone sont des PCX 8 bits indexes. L'index n'est pas une
	# intensite : la palette VGA de fin de fichier porte la valeur visuelle. Les
	# anciennes passes utilisaient par erreur l'index brut, ce qui rendait une
	# grassmap noire "presente" presque partout.
	var luminance_pixels := pixels.duplicate()
	var max_luminance := max_v
	var palette_marker := data.size() - 769
	if palette_marker >= 0 and int(data[palette_marker]) == 12:
		var palette_start := palette_marker + 1
		max_luminance = 0
		for index in pixels.size():
			var palette_index := int(pixels[index])
			var palette_offset := palette_start + palette_index * 3
			var red := float(data[palette_offset])
			var green := float(data[palette_offset + 1])
			var blue := float(data[palette_offset + 2])
			var luminance := clampi(roundi(red * 0.2126 + green * 0.7152 + blue * 0.0722), 0, 255)
			luminance_pixels[index] = luminance
			max_luminance = maxi(max_luminance, luminance)
	return {"width": w, "height": h, "pixels": pixels, "max": max_v,
		"luminance_pixels": luminance_pixels, "max_luminance": max_luminance}


func _grass_dense_relation_report(grass: Dictionary, dense: Dictionary) -> Dictionary:
	var grass_pixels: PackedByteArray = grass.get("luminance_pixels",
		grass.get("pixels", PackedByteArray())) as PackedByteArray
	var dense_pixels: PackedByteArray = dense.get("luminance_pixels",
		dense.get("pixels", PackedByteArray())) as PackedByteArray
	if grass_pixels.is_empty() or dense_pixels.size() != grass_pixels.size():
		return {"available": false}
	var grass_count := 0
	var empty_count := 0
	var dense_positive_on_grass := 0
	var dense_positive_without_grass := 0
	var dense_sum_on_grass := 0
	var dense_sum_without_grass := 0
	var grass_values: Dictionary = {}
	for index in grass_pixels.size():
		var grass_raw := int(grass_pixels[index])
		var dense_raw := int(dense_pixels[index])
		grass_values[str(grass_raw)] = true
		if grass_raw >= VEGETATION_MAP_THRESHOLD:
			grass_count += 1
			dense_sum_on_grass += dense_raw
			if dense_raw > 0:
				dense_positive_on_grass += 1
		else:
			empty_count += 1
			dense_sum_without_grass += dense_raw
			if dense_raw > 0:
				dense_positive_without_grass += 1
	var values := grass_values.keys()
	values.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b))
	return {
		"available": true,
		"pixels": grass_pixels.size(),
		"grass_pixels": grass_count,
		"empty_pixels": empty_count,
		"grass_values": values,
		"dense_positive_on_grass": dense_positive_on_grass,
		"dense_positive_without_grass": dense_positive_without_grass,
		"dense_mean_on_grass": float(dense_sum_on_grass) / maxf(1.0, float(grass_count)),
		"dense_mean_without_grass": float(dense_sum_without_grass) / maxf(1.0, float(empty_count)),
	}


func _grassmap_difference_report(original: Dictionary, alternative: Dictionary) -> Dictionary:
	var original_pixels: PackedByteArray = original.get("luminance_pixels",
		original.get("pixels", PackedByteArray())) as PackedByteArray
	var alternative_pixels: PackedByteArray = alternative.get("luminance_pixels",
		alternative.get("pixels", PackedByteArray())) as PackedByteArray
	if original_pixels.is_empty() or alternative_pixels.size() != original_pixels.size():
		return {"comparable": false}
	var changed := 0
	var added := 0
	var removed := 0
	var brighter := 0
	var darker := 0
	var min_x := int(original.get("width", 0))
	var min_y := int(original.get("height", 0))
	var max_x := -1
	var max_y := -1
	var width := int(original.get("width", 0))
	var height := int(original.get("height", 0))
	for index in original_pixels.size():
		var before := int(original_pixels[index])
		var after := int(alternative_pixels[index])
		if before != after:
			changed += 1
			if width > 0:
				var px := index % width
				var py := index / width
				min_x = mini(min_x, px)
				min_y = mini(min_y, py)
				max_x = maxi(max_x, px)
				max_y = maxi(max_y, py)
			if after > before:
				brighter += 1
			else:
				darker += 1
		if before < VEGETATION_MAP_THRESHOLD and after >= VEGETATION_MAP_THRESHOLD:
			added += 1
		elif before >= VEGETATION_MAP_THRESHOLD and after < VEGETATION_MAP_THRESHOLD:
			removed += 1
	var changed_bbox_pixels := []
	var changed_bbox_zone_raw := []
	if changed > 0 and width > 0 and height > 0:
		changed_bbox_pixels = [min_x, min_y, max_x, max_y]
		changed_bbox_zone_raw = [
			roundi(float(min_x) / float(width) * 65536.0),
			roundi(float(min_y) / float(height) * 65536.0),
			roundi(float(max_x + 1) / float(width) * 65536.0),
			roundi(float(max_y + 1) / float(height) * 65536.0),
		]
	return {"comparable": true, "changed_pixels": changed,
		"brighter_pixels": brighter, "darker_pixels": darker,
		"added_pixels": added, "removed_pixels": removed,
		"changed_bbox_pixels": changed_bbox_pixels,
		"changed_bbox_zone_raw": changed_bbox_zone_raw,
		"map_orientation": "x->DAoC X, y->DAoC Y (contrat Vanilla natif)"}


# --- DAoC zone legacy lights -------------------------------------------------
# Visual/debug first pass. These lights are deliberately approximate: lights.csv
# only gives x,y,z,type. Exact type semantics can be reverse-engineered later.

func build_zone_lights(znum: int, origin3: Vector3) -> void:
	if not build_legacy_lights:
		return
	var lighting_root := _zone_branch_host(znum, "LightingRoot")
	if lighting_root == null or lighting_root.get_node_or_null("Zone%03d_LegacyLights" % znum) != null:
		return
	var lights_path := _find_lights_csv(znum)
	if lights_path == "":
		if log_legacy_lights:
			print("zone%03d lights: no lights.csv found; expected zone%03d_lights.csv or raw dat%03d/lights.csv" % [znum, znum, znum])
		return
	var entries: Array[Dictionary] = _parse_lights_csv(lights_path)
	if entries.is_empty():
		return

	var root := Node3D.new()
	root.name = "Zone%03d_LegacyLights" % znum
	root.visible = legacy_lights_visible
	root.add_to_group("daoc_legacy_lights_root")
	root.set_meta("daoc_zone", znum)
	lighting_root.add_child(root)

	var by_type: Dictionary = {}
	for i in entries.size():
		var e: Dictionary = entries[i]
		var t := int(e.get("type", 0))
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "light_%03d_type_%d" % [i, t]
		var base_position := origin3 + Vector3(
			float(e.get("x", 0.0)) * world_scale,
			float(e.get("z", 0.0)) * world_scale * height_exaggeration,
			float(e.get("y", 0.0)) * world_scale
		)
		light.position = base_position + Vector3.UP * legacy_light_vertical_offset * world_scale * height_exaggeration
		light.light_energy = legacy_light_energy * _legacy_light_type_energy(t)
		light.set_meta("daoc_base_energy", light.light_energy)
		light.omni_range = legacy_light_range * world_scale * _legacy_light_type_range_mul(t)
		light.omni_attenuation = legacy_light_attenuation
		# Les ombres ne sont plus armees lampe par lampe : DaocLocalLightShadows
		# les distribue sous budget aux plus proches de la camera (P1-91).
		light.shadow_enabled = false
		if use_legacy_light_type_colors:
			light.light_color = _legacy_light_type_color(t)
		light.set_meta("daoc_zone", znum)
		light.set_meta("daoc_light_type", t)
		light.set_meta("daoc_light_source", lights_path)
		light.set_meta("daoc_base_position", base_position)
		light.add_to_group("daoc_legacy_light")
		root.add_child(light)
		if legacy_lights_show_markers:
			var marker: MeshInstance3D = _make_legacy_light_marker(t)
			light.add_child(marker)
		by_type[t] = int(by_type.get(t, 0)) + 1

	if log_legacy_lights:
		print("zone%03d lights: %d light(s) from %s types=%s" % [znum, entries.size(), lights_path, str(by_type)])
	_sync_local_light_shadows(legacy_lights_visible, root)


func _find_lights_csv(znum: int) -> String:
	var zp := "zone%03d" % znum
	var dp := "dat%03d" % znum
	var cp := "csv%03d" % znum
	var data_dir := _effective_data_dir()
	var root := _effective_daoc_root()
	var candidates: Array[String] = []

	# Cache-friendly paths. Future cache generators can emit either flat or nested.
	candidates.append(data_dir.path_join("zone%03d_lights.csv" % znum))
	candidates.append(data_dir.path_join("zone%03d_lights.CSV" % znum))
	candidates.append(data_dir.path_join(zp).path_join("lights.csv"))
	candidates.append(data_dir.path_join(zp).path_join(dp).path_join("lights.csv"))
	candidates.append(data_dir.path_join(zp).path_join(cp).path_join("lights.csv"))
	candidates.append(data_dir.path_join(dp).path_join("lights.csv"))
	candidates.append(data_dir.path_join(cp).path_join("lights.csv"))
	candidates.append(data_dir.path_join("lights.csv"))

	if root != "":
		var zone_roots: Array[String] = [
			root.path_join("zones").path_join(zp),
			root.path_join("frontiers/zones").path_join(zp),
			root.path_join("phousing/zones").path_join(zp),
			root.path_join("tutorial/zones").path_join(zp),
			root.path_join("zones"),
			root.path_join("frontiers/zones"),
			root.path_join("phousing/zones"),
			root.path_join("tutorial/zones"),
		]
		for zr in zone_roots:
			candidates.append(zr.path_join(dp).path_join("lights.csv"))
			candidates.append(zr.path_join(cp).path_join("lights.csv"))
			candidates.append(zr.path_join("dat").path_join("lights.csv"))
			candidates.append(zr.path_join("csv").path_join("lights.csv"))
			candidates.append(zr.path_join("lights.csv"))
			candidates.append(zr.path_join("terrain").path_join("lights.csv"))

	for p in candidates:
		if p != "" and FileAccess.file_exists(p):
			return p
	return ""


func _parse_lights_csv(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with(";"):
			continue
		var parts := line.split(",", false)
		if parts.size() < 4:
			continue
		var e: Dictionary = {
			"x": float(parts[0].strip_edges()),
			"y": float(parts[1].strip_edges()),
			"z": float(parts[2].strip_edges()),
			"type": int(parts[3].strip_edges()),
		}
		out.append(e)
	f.close()
	return out



func _make_legacy_light_marker(t: int) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "debug_marker"
	marker.add_to_group("daoc_legacy_light_marker")
	var sphere := SphereMesh.new()
	var r: float = max(8.0, legacy_light_marker_radius * world_scale)
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	marker.mesh = sphere
	var mat := StandardMaterial3D.new()
	var c := _legacy_light_type_color(t)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 1.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	marker.visible = legacy_lights_visible and legacy_lights_show_markers
	return marker


func apply_legacy_light_runtime_settings() -> void:
	# Le viewer fournit `_host`; DaocGame fournit le meme noeud vivant via les
	# services. Dans les deux cas les groupes de SceneTree restent l'autorite.
	if _tree() == null:
		return
	var enabled := build_legacy_lights and legacy_lights_visible
	for root in _tree().get_nodes_in_group("daoc_legacy_lights_root"):
		if root is Node3D:
			(root as Node3D).visible = enabled
	for n in _tree().get_nodes_in_group("daoc_legacy_light"):
		if n is OmniLight3D:
			var l := n as OmniLight3D
			var t := int(l.get_meta("daoc_light_type", 0))
			l.visible = enabled
			l.light_energy = legacy_light_energy * _legacy_light_type_energy(t)
			l.set_meta("daoc_base_energy", l.light_energy)
			l.omni_range = legacy_light_range * world_scale * _legacy_light_type_range_mul(t)
			l.omni_attenuation = legacy_light_attenuation
			if not legacy_lights_cast_shadows:
				l.shadow_enabled = false
			l.light_color = _legacy_light_type_color(t) if use_legacy_light_type_colors else Color.WHITE
			if l.has_meta("daoc_base_position"):
				l.position = (l.get_meta("daoc_base_position") as Vector3) \
					+ Vector3.UP * legacy_light_vertical_offset * world_scale * height_exaggeration
	for n in _tree().get_nodes_in_group("daoc_legacy_light_marker"):
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = enabled and legacy_lights_show_markers
	_sync_local_light_shadows(enabled)
	# The P1-20K controller owns global light and ambience. Legacy local lamps
	# may still be toggled, but they must not reset the dynamic sun every time.
	var dynamic_environment := _host != null and _host.get("_environment_controller") != null
	if _viewer_sun != null and not dynamic_environment:
		_viewer_sun.light_energy = legacy_preview_sun_energy if legacy_lights_preview_dark_scene else 1.15
	if _viewer_environment != null and not dynamic_environment:
		if legacy_lights_preview_dark_scene:
			_viewer_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_viewer_environment.ambient_light_color = Color(0.02, 0.02, 0.025)
			_viewer_environment.ambient_light_energy = legacy_preview_ambient_energy
		else:
			_viewer_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			_viewer_environment.ambient_light_energy = 0.6


## Un seul gestionnaire d'ombres de lampes par arbre, pose a cote des racines
## de lampes. `legacy_lights_cast_shadows` decoche : il est neutralise et
## toutes les ombres retombent, comme avant P1-91.
func _sync_local_light_shadows(lights_enabled: bool, anchor: Node = null) -> void:
	var tree := _tree()
	if tree == null:
		return
	var roots := tree.get_nodes_in_group("daoc_legacy_lights_root")
	var manager: Node = null
	for node in tree.get_nodes_in_group("daoc_local_light_shadows"):
		manager = node
		break
	var want := lights_enabled and legacy_lights_cast_shadows
	if manager == null:
		if not want:
			return
		# Au moment de la construction, la racine des lampes n est pas encore dans
		# l arbre, donc pas dans son groupe : l anchor est la racine qu on vient
		# de creer.
		var first_root: Node = (roots[0] as Node) if not roots.is_empty() else anchor
		if first_root == null:
			return
		var parent: Node = first_root.get_parent()
		if parent == null:
			return
		manager = LocalLightShadowsScript.new()
		manager.name = "DaocLocalLightShadows"
		manager.add_to_group("daoc_local_light_shadows")
		parent.add_child(manager)
	manager.call("configure", {
		"enabled": want,
		"max_shadowed_lights": legacy_light_shadow_budget,
		"shadow_blur": legacy_light_shadow_blur,
		"shadow_opacity": legacy_light_shadow_opacity,
		"flicker_enabled": legacy_lights_flicker,
		"flicker_amount": legacy_light_flicker_amount,
	})


func _legacy_light_type_color(t: int) -> Color:
	match t:
		2:
			return Color(1.00, 0.78, 0.48)
		3:
			return Color(1.00, 0.86, 0.62)
		5:
			return Color(0.60, 0.95, 0.62)
		9:
			return Color(0.52, 0.72, 1.00)
		12:
			return Color(0.85, 0.60, 1.00)
		15:
			return Color(1.00, 0.55, 0.28)
		16:
			return Color(0.60, 1.00, 0.95)
		17:
			return Color(1.00, 0.95, 0.80)
		_:
			return Color(1.0, 0.88, 0.68)


func _legacy_light_type_energy(t: int) -> float:
	match t:
		9:
			return 0.70
		12, 15, 16, 17:
			return 1.15
		_:
			return 1.0


func _legacy_light_type_range_mul(t: int) -> float:
	match t:
		9:
			return 1.25
		12, 15, 16, 17:
			return 0.85
		_:
			return 1.0
