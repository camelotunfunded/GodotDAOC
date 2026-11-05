extends RefCounted
class_name DaocDistantTerrain

const DaocWaterMaterialFactoryScript = preload("res://src/daoc/water/DaocWaterMaterialFactory.gd")
const DaocDistantCliffShader = preload("res://src/daoc/world/DaocDistantCliff.gdshader")
const DaocDistantBorderFogShader = preload("res://src/daoc/world/DaocDistantBorderFog.gdshader")

## Horizon : le terrain des zones VOISINES, en version grossiere.
##
## Le probleme observe : une seule zone est chargee, donc au-dela de ses bords
## il n'y a rien a dessiner. On prend ce vide pour du LOD alors que c'est
## simplement la fin du monde — un mur clair a l'horizon.
##
## LE CLIENT D'ORIGINE FAIT PAREIL, EN MIEUX
## Chaque zone livre un dossier `lod0XX/` : une version simplifiee de son
## terrain, destinee justement a etre vue de loin. C'est la meme idee que le
## « distant land » des moteurs modernes, et elle date de 2001.
##
## MAIS ON A DEJA MIEUX QUE CES TUILES POUR LE RELIEF
## Le cache du projet contient, pour chaque zone deja traitee, sa carte de
## hauteurs complete en `.r16`. Lue a pas grossier — un point sur quatre — elle
## donne un relief lointain sans convertir un seul fichier de plus. Les tuiles
## `lod0XX` existaient pour economiser la memoire d'une machine de 2001 ; ce
## n'est plus la contrainte.
##
## CE QUE CE MAILLAGE N'EST PAS
## Les 64 PNG `lodXX-YY.png` restent toutefois la meilleure autorite pour la
## COULEUR lointaine. Ils sont lus directement dans le client, reduits puis
## assembles en un atlas runtime de 512 px : aucun pixel client n'est copie
## dans le projet et la memoire reste bornee a environ 1,33 Mio par zone avec
## mipmaps, au lieu de charger les 64 sources 256 px en textures GPU.
##
## Pas de collision, pas de props, pas d'eau, pas de splat. On ne peut pas
## marcher dessus et ce n'est pas voulu : c'est un decor d'horizon. Le jour ou
## le joueur doit y entrer, c'est la zone entiere qu'il faut charger, par le
## chemin normal.

## Une hauteur brute vaut une unite monde ; le sommet observe en region 51 est
## a 5104. On colore du plus bas au plus haut pour donner un relief lisible
## sans aucune texture.
const COLOUR_LOW := Color(0.19, 0.23, 0.17)
const COLOUR_HIGH := Color(0.38, 0.39, 0.35)
## Sous le niveau de la mer, on ne dessine pas un fond marin : on dessine la
## surface. Sans ca, le lit de l'ocean d'une zone voisine se dresse en plateau
## pale au-dessus de l'eau de la zone active — un mur, exactement ce qu'on
## voulait supprimer.
const COLOUR_SEA := Color(0.20, 0.30, 0.40)

## Repli GEOMETRIQUE pour les falaises et le cyclorama quand une region ne
## declare aucune mer. Il ne doit jamais, a lui seul, autoriser une surface
## d'eau : 2925 est propre a Avalon et noyait Salisbury quand il etait traite
## comme un niveau marin universel.
const DEFAULT_SEA_LEVEL := 2925.0

const ROOT_NAME := "DaocDistantTerrainRoot"
const CATALOG_NAME := "daoc_zone_catalog.json"
const ZONE_WORLD_SIZE := 65536.0
const LOD_TILE_GRID := 8
const DEFAULT_LOD_ATLAS_SIZE := 512
## P1-33 — le palier PROCHE d'une zone lointaine.
##
## Les 64 tuiles `lodXX-YY.png` du client font 256 px CHACUNE : leur assemblage
## natif fait donc 2048 px, soit 32 unites DAoC par texel. L'atlas d'horizon les
## reduit a 64 px pour tenir 512 px au total — 128 unites par texel, et les trois
## quarts de la source jetes. Vu de l'autre bout de la region c'est le bon
## marche ; vu a 2000 unites, c'est la bouillie qu'on observe au bord.
##
## 2048 N'EST DONC PAS UNE MONTEE EN RESOLUTION, c'est l'arret d'une REDUCTION :
## a ce palier chaque texel du client est rendu tel quel, 1 pour 1. Au-dela il
## n'y a plus rien a gagner, la source ne porte pas davantage.
const NATIVE_LOD_ATLAS_SIZE := 2048
const DEFAULT_NEAR_LOD_ATLAS_SIZE := NATIVE_LOD_ATLAS_SIZE
## Un point sur N de la carte de hauteurs dans la bande proche d'une frontiere
## partagee. 1 = tous les points, soit le maximum que le `.r16` porte.
const DEFAULT_NEAR_STEP := 1
## Largeur de cette bande, en unites DAoC brutes.
const DEFAULT_NEAR_BAND_RAW := 8192.0
## Sur quelle distance la densite retombe du pas fin au pas grossier. Une reprise
## brutale se lit comme une arete sur le relief ; le pas double a chaque palier.
const DEFAULT_NEAR_RAMP_RAW := 8192.0
## Largeur du fondu au bord des tranches REELLEMENT exposees, en unites DAoC.
##
## Elle valait implicitement « trois points de la grille », ce qui liait le fondu
## au pas d'echantillonnage : densifier un bord retrecissait le fondu d'un autre
## bord sans que rien ne le dise. Elle est desormais une DISTANCE, donc stable
## quel que soit le palier. 3084 reproduit les trois points du pas 4 d'origine.
const TERRAIN_EDGE_FADE_RAW := 3084.0
const CLIFF_TEXTURE_RELATIVE_PATH := "zones/TerrainTex/oceanuscliff.png"
const CLIFF_BOTTOM_BELOW_SEA := 320.0
const CLIFF_MIN_LAND_ABOVE_SEA := 72.0
## Opacite volontairement tres faible au sommet : ce voile local efface la
## tranche rectangulaire sans blanchir tout l'horizon ni fermer la mer.
const CLIFF_HAZE_TOP_OPACITY := 0.0
const CLIFF_HAZE_BOTTOM_OPACITY := 0.18

## ===========================================================================
## ATTENTION — EXPERIMENTAL, CONCU EN OBSERVANT ISLE OF GLASS / AVALON ISLE
## Cette nappe de brouillard masque les coupures artificielles des zones en
## escalier de la region Avalon. Elle peut cacher un relief legitime ou devenir
## genante dans une autre region/royaume. Toute generalisation doit donc etre
## revalidee VISUELLEMENT zone par zone. La garde maritime ci-dessous est
## volontairement stricte : si un seul bout du segment touche la mer, PAS de
## nappe. Ne pas assouplir ce test sans captures hors d'Avalon.
## ===========================================================================
const BORDER_FOG_INWARD_WIDTH := 2300.0
const BORDER_FOG_OUTWARD_WIDTH := 1200.0
const BORDER_FOG_TOP_RISE := 1500.0
const BORDER_FOG_PEAK_OPACITY := 0.22


## Construit l'horizon autour des zones actives.
##
## `host` doit exposer `world_scale`, `height_exaggeration` et `_base`, comme
## ZoneViewer. On ne recalcule pas le repere : on emprunte le sien, sinon
## l'horizon ne serait pas aligne sur le terrain de pres.
##
## R4 — `settings["parent"]` déplace la branche produite sans rien changer au
## repère : `host` reste la source des réglages et de `_base`, mais l'horizon
## peut vivre ailleurs que sous lui. C'est ce qui permet au `DaocZoneStreamer`
## d'en devenir propriétaire, l'horizon étant JETABLE au même titre qu'une zone —
## il dépend des zones résidentes, donc il meurt avec elles.
static func build(host: Node3D, active_zones: Array, settings: Dictionary = {}) -> Dictionary:
	var parent: Node3D = _horizon_parent(host, settings)
	clear(parent)
	var report := {
		"ok": false, "built_zones": [], "skipped": [], "vertex_count": 0,
		"triangle_count": 0, "region": -1, "step": 0,
	}

	var data_dir := str(settings.get("data_dir", ""))
	if data_dir.is_empty():
		data_dir = _resolve_data_dir(host)
	if data_dir.is_empty():
		report["error"] = "cache_data_dir_introuvable"
		return report

	var catalog := _read_catalog(data_dir)
	if catalog.is_empty():
		report["error"] = "catalogue de zones illisible"
		return report

	var active: Array[int] = []
	for value in active_zones:
		active.append(int(value))
	if active.is_empty():
		report["error"] = "aucune zone active"
		return report

	# La region vient de la premiere zone active : l'horizon est celui de la
	# region ou l'on se trouve, pas du monde entier.
	var region := int((catalog.get(active[0], {}) as Dictionary).get("region", -1))
	report["region"] = region
	if region < 0:
		report["error"] = "region inconnue pour la zone %d" % active[0]
		return report

	var step := maxi(1, int(settings.get("step", 4)))
	var max_zones := int(settings.get("max_zones", 24))
	report["step"] = step
	var world_scale := float(host.get("world_scale"))
	var height_exaggeration := float(host.get("height_exaggeration"))
	var base: Vector2 = host.get("_base") as Vector2
	var client_root := str(settings.get("client_root", host.get("daoc_client_root"))).strip_edges().replace("\\", "/").trim_suffix("/")
	# Une nappe globale n'est permise que si un OCEAN natif existe dans cette
	# region. Surtout pas de sondage au centre de la zone : Salisbury y rencontre
	# au mieux une riviere, et l'ancien repli Avalon (2925) la submergeait.
	var sea_profile := _resolve_region_sea_profile(catalog, region, client_root)
	var explicit_sea_level := settings.has("sea_level")
	var sea_level := float(settings.get("sea_level", sea_profile.get("level", DEFAULT_SEA_LEVEL)))
	var sea_authorized := explicit_sea_level or bool(sea_profile.get("has_ocean", false))
	report["sea_level"] = sea_level
	report["sea_level_source"] = "settings" if explicit_sea_level else str(sea_profile.get("source", "none"))
	report["sea_ocean_zones"] = (sea_profile.get("ocean_zones", []) as Array).duplicate()
	report["sea_level_drawn"] = false
	report["sea_gap_only"] = true
	var cliff_texture_path := str(settings.get("cliff_texture_path", client_root.path_join(CLIFF_TEXTURE_RELATIVE_PATH)))
	var cliff_texture := _load_external_png(cliff_texture_path)
	var cliff_material := _make_cliff_material(cliff_texture)
	var border_fog_color := settings.get("border_fog_color", Color8(85, 140, 166)) as Color
	var border_fog_material := _make_border_fog_material(border_fog_color)
	var region_footprints := _region_footprints(catalog, region)
	var placement_debug: Array = []
	for footprint_value in region_footprints:
		var footprint := footprint_value as Dictionary
		var rect := footprint.get("rect", Rect2()) as Rect2
		placement_debug.append({
			"zone": int(footprint.get("zone", -1)),
			"world_origin": [rect.position.x, rect.position.y],
			"size": [rect.size.x, rect.size.y],
		})
	placement_debug.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("zone", -1)) < int(b.get("zone", -1))
	)
	report["region_placements"] = placement_debug
	report["placement_source"] = "daoc_zone_catalog derived from zones.dat"
	report["cliff_texture_path"] = cliff_texture_path
	report["cliff_texture_loaded"] = cliff_texture != null
	report["cliff_texture_external_runtime"] = cliff_texture != null and cliff_texture.resource_path.is_empty()
	report["cliff_segments"] = 0
	report["cliff_local_haze"] = true
	report["cliff_haze_top_opacity"] = CLIFF_HAZE_TOP_OPACITY
	report["cliff_haze_bottom_opacity"] = CLIFF_HAZE_BOTTOM_OPACITY
	report["terrain_exposed_edges_feathered"] = true
	report["border_fog_experimental_avalon"] = true
	report["border_fog_warning"] = "Concu sur Isle of Glass/Avalon Isle; peut gener ailleurs, validation visuelle par zone obligatoire"
	report["border_fog_segments"] = 0
	report["border_fog_maritime_segments_skipped"] = 0
	report["border_fog_maritime_authority"] = "SECTOR.DAT type=OCEAN leftXX/rightXX + garde de hauteur"
	report["border_fog_unknown_maritime_zones"] = 0
	report["horizon_segments"] = 0
	report["horizon_sea_gaps"] = 0
	report["horizon_gap_edges_feathered"] = true
	report["lod_colour_source"] = "client PNG zones/zoneXXX/lodXXX/lodXX-YY.png"
	report["lod_atlas_size"] = int(settings.get("lod_atlas_size", DEFAULT_LOD_ATLAS_SIZE))
	report["lod_atlas_zones"] = 0
	report["lod_atlas_tiles_loaded"] = 0
	report["lod_atlas_estimated_bytes"] = 0
	report["lod_atlas_external_runtime"] = true

	# P1-33 — les zones qui meritent le palier PROCHE, et par quels bords. La
	# selection vient de `DaocZoneLodPlanner` : cet objet ne decide pas QUI est
	# proche, il rend ce qu'on lui demande de rendre.
	var near_zones: Array = []
	for value in (settings.get("near_zones", []) as Array):
		near_zones.append(int(value))
	var near_edges := settings.get("near_edges", {}) as Dictionary
	var near_atlas_size := int(settings.get("near_lod_atlas_size", DEFAULT_NEAR_LOD_ATLAS_SIZE))
	var near_step := maxi(1, int(settings.get("near_step", DEFAULT_NEAR_STEP)))
	var near_band_raw := maxf(0.0, float(settings.get("near_band_raw", DEFAULT_NEAR_BAND_RAW)))
	var near_ramp_raw := maxf(1.0, float(settings.get("near_ramp_raw", DEFAULT_NEAR_RAMP_RAW)))
	report["near_zones"] = near_zones.duplicate()
	report["near_lod_atlas_size"] = near_atlas_size
	report["near_step"] = near_step
	report["near_band_raw"] = near_band_raw
	report["near_zones_built"] = 0

	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("offline_only", true)
	root.set_meta("distant_only", true)
	root.set_meta("region", region)
	parent.add_child(root)

	# Les planches de controle veulent parfois voir la zone active a sa place
	# dans l'archipel ; le runtime, lui, ne doit jamais la redessiner.
	var include_active := bool(settings.get("include_active_zones", false))

	var candidates: Array = []
	for zone_id in catalog:
		var entry := catalog[zone_id] as Dictionary
		if int(entry.get("region", -1)) != region:
			continue
		if active.has(int(zone_id)) and not include_active:
			continue  # deja affichee en pleine definition
		if str(entry.get("pipeline", "")) != "terrain_heightmap":
			continue
		if int(entry.get("enabled", 0)) != 1:
			continue
		candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("zone", 0)) < int(b.get("zone", 0)))

	var vertices := 0
	var triangles := 0
	for value in candidates:
		var entry := value as Dictionary
		var zone_id := int(entry.get("zone", -1))
		if (report["built_zones"] as Array).size() >= max_zones:
			(report["skipped"] as Array).append({"zone": zone_id, "reason": "plafond max_zones atteint"})
			continue
		var heights := _read_heightmap(data_dir, zone_id)
		if heights.is_empty():
			(report["skipped"] as Array).append({"zone": zone_id, "reason": "carte de hauteurs absente du cache"})
			continue
		var maritime_edges := _read_ocean_border_ranges(client_root, zone_id)
		# Le palier de CETTE zone. Une zone lointaine ordinaire garde exactement
		# le rendu d'avant P1-33 ; seules les voisines contigues et proches
		# paient le prix fort, et elles seules.
		var is_near := near_zones.has(zone_id)
		var zone_fine_edges: Array = (near_edges.get(zone_id, []) as Array) if is_near else []
		var zone_atlas_size := near_atlas_size if is_near else int(settings.get("lod_atlas_size", DEFAULT_LOD_ATLAS_SIZE))
		var lod_atlas_info := _load_lod_colour_atlas(client_root, zone_id, zone_atlas_size)
		var built := _build_zone_mesh(entry, heights, step, base, world_scale,
			height_exaggeration, sea_level, region_footprints, cliff_material,
			bool(settings.get("cliffs_enabled", true)), border_fog_material,
			bool(settings.get("border_fog_enabled", true)), maritime_edges,
			lod_atlas_info.get("texture", null) as Texture2D,
			zone_fine_edges, near_step, near_band_raw, near_ramp_raw)
		if is_near:
			report["near_zones_built"] = int(report["near_zones_built"]) + 1
		if built.is_empty():
			(report["skipped"] as Array).append({"zone": zone_id, "reason": "maillage vide"})
			continue
		root.add_child(built["node"] as Node3D)
		vertices += int(built["vertices"])
		triangles += int(built["triangles"])
		report["cliff_segments"] = int(report["cliff_segments"]) + int(built.get("cliff_segments", 0))
		report["border_fog_segments"] = int(report["border_fog_segments"]) + int(built.get("border_fog_segments", 0))
		report["border_fog_maritime_segments_skipped"] = int(report["border_fog_maritime_segments_skipped"]) + int(built.get("border_fog_maritime_segments_skipped", 0))
		if bool(lod_atlas_info.get("complete", false)):
			report["lod_atlas_zones"] = int(report["lod_atlas_zones"]) + 1
		report["lod_atlas_tiles_loaded"] = int(report["lod_atlas_tiles_loaded"]) + int(lod_atlas_info.get("tiles_loaded", 0))
		report["lod_atlas_estimated_bytes"] = int(report["lod_atlas_estimated_bytes"]) + int(lod_atlas_info.get("estimated_bytes", 0))
		if not bool(maritime_edges.get("known", false)):
			report["border_fog_unknown_maritime_zones"] = int(report["border_fog_unknown_maritime_zones"]) + 1
		(report["built_zones"] as Array).append({
			"zone": zone_id, "name": str(entry.get("name", "")),
			"vertices": int(built["vertices"]),
			"lod_atlas_complete": bool(lod_atlas_info.get("complete", false)),
			"lod_tiles_loaded": int(lod_atlas_info.get("tiles_loaded", 0)),
			"lod_atlas_path": str(lod_atlas_info.get("directory", "")),
			"lod_tier": "NEAR" if is_near else "FAR",
			"lod_atlas_size": int(lod_atlas_info.get("atlas_size", 0)),
			"fine_edges": zone_fine_edges.duplicate(),
			"grid_side": int(built.get("grid_side", 0)),
		})

	# La mer remplit seulement les intervalles qui ne correspondent a AUCUNE zone.
	#
	# Une nappe rectangulaire unique recouvrait aussi toutes les zones terrestres.
	# Cela passait a Avalon, dont les iles sont au-dessus de 2925, mais noyait les
	# regions plus basses comme Salisbury. Le maillage est maintenant decoupe aux
	# emprises de zones : aucune eau d'horizon ne peut entrer dans une zone jouable.
	if bool(settings.get("sea_enabled", true)) and sea_authorized:
		var water_settings := settings.duplicate(true)
		if not water_settings.has("client_root"):
			water_settings["client_root"] = str(host.get("daoc_client_root"))
		var sea := _build_sea(catalog, region, base, world_scale,
			height_exaggeration, sea_level, region_footprints, water_settings)
		if sea != null:
			root.add_child(sea)
			report["sea_level_drawn"] = true
			report["sea_gap_cells"] = int(sea.get_meta("daoc_sea_gap_cells", 0))
			report["sea_excluded_zone_footprints"] = int(sea.get_meta("daoc_excluded_zone_footprints", 0))

	# Un relief d'arriere-plan ferme le cyclorama sans transformer la region en
	# cuvette. Des trouees deterministes restent ouvertes sur la mer ; la brume
	# fond le reste avant que le joueur ne puisse en lire la geometrie.
	if bool(settings.get("horizon_backdrop_enabled", true)):
		var horizon := _build_horizon_backdrop(catalog, region, base, world_scale,
			height_exaggeration, sea_level, cliff_material, settings)
		if not horizon.is_empty():
			root.add_child(horizon["node"] as Node3D)
			report["horizon_segments"] = int(horizon.get("segments", 0))
			report["horizon_sea_gaps"] = int(horizon.get("sea_gaps", 0))
			report["horizon_backdrop_drawn"] = true

	report["vertex_count"] = vertices
	report["triangle_count"] = triangles
	report["ok"] = not (report["built_zones"] as Array).is_empty()
	return report


## Une grille de quads couvrant seulement le vide autour des emprises de zones.
##
## Il est pose LEGEREMENT sous le niveau declare : la zone active dessine deja
## sa propre eau a la hauteur exacte, et deux surfaces coplanaires se
## disputeraient le pixel. Quelques unites suffisent a trancher, et l'ecart est
## invisible a la distance ou ce plan se voit.
static func _build_sea(catalog: Dictionary, region: int, base: Vector2,
		world_scale: float, height_exaggeration: float, sea_level: float,
		region_footprints: Array, settings: Dictionary) -> MeshInstance3D:
	var bounds := Rect2()
	var seen := false
	for zone_id in catalog:
		var entry := catalog[zone_id] as Dictionary
		if int(entry.get("region", -1)) != region:
			continue
		var origin_values := entry.get("world_origin", []) as Array
		if origin_values.size() < 2:
			continue
		var rect := Rect2(
			float(origin_values[0]), float(origin_values[1]),
			ZONE_WORLD_SIZE, ZONE_WORLD_SIZE
		)
		bounds = rect if not seen else bounds.merge(rect)
		seen = true
	if not seen:
		return null

	# Une marge franche : l'horizon ne doit pas s'arreter net au dernier ilot.
	bounds = bounds.grow(ZONE_WORLD_SIZE)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := (sea_level - 6.0) * world_scale * height_exaggeration
	var cuts_x: Array[float] = [bounds.position.x, bounds.end.x]
	var cuts_y: Array[float] = [bounds.position.y, bounds.end.y]
	for footprint_value in region_footprints:
		var footprint := footprint_value as Dictionary
		var rect := footprint.get("rect", Rect2()) as Rect2
		if rect.size == Vector2.ZERO:
			continue
		cuts_x.append(clampf(rect.position.x, bounds.position.x, bounds.end.x))
		cuts_x.append(clampf(rect.end.x, bounds.position.x, bounds.end.x))
		cuts_y.append(clampf(rect.position.y, bounds.position.y, bounds.end.y))
		cuts_y.append(clampf(rect.end.y, bounds.position.y, bounds.end.y))
	cuts_x.sort()
	cuts_y.sort()
	cuts_x = _unique_sorted_floats(cuts_x)
	cuts_y = _unique_sorted_floats(cuts_y)

	var gap_cells := 0
	for yi in range(cuts_y.size() - 1):
		for xi in range(cuts_x.size() - 1):
			var cell := Rect2(
				Vector2(cuts_x[xi], cuts_y[yi]),
				Vector2(cuts_x[xi + 1] - cuts_x[xi], cuts_y[yi + 1] - cuts_y[yi])
			)
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var centre := cell.get_center()
			if _covered_by_any_zone(centre, region_footprints):
				continue
			var local_min := (cell.position - base) * world_scale
			var local_max := (cell.end - base) * world_scale
			var corners := [
				Vector3(local_min.x, y, local_min.y),
				Vector3(local_max.x, y, local_min.y),
				Vector3(local_max.x, y, local_max.y),
				Vector3(local_min.x, y, local_max.y),
			]
			for triple in [[0, 1, 2], [0, 2, 3]]:
				for corner in triple:
					surface.set_color(COLOUR_SEA)
					surface.add_vertex(corners[corner] as Vector3)
			gap_cells += 1
	if gap_cells <= 0:
		return null
	surface.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DistantSea"
	mesh_instance.mesh = surface.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = DaocWaterMaterialFactoryScript.make_material({
		"type": "OCEAN", "texture": "watery", "multitexture": "ripl",
		"flow": 0, "bankpoints": 0,
	}, settings)
	mesh_instance.set_meta("daoc_distant_only", true)
	mesh_instance.set_meta("daoc_sea_level", sea_level)
	mesh_instance.set_meta("daoc_water_surface", true)
	mesh_instance.set_meta("daoc_sea_gap_only", true)
	mesh_instance.set_meta("daoc_sea_gap_cells", gap_cells)
	mesh_instance.set_meta("daoc_excluded_zone_footprints", region_footprints.size())
	return mesh_instance


## Autorite maritime regionale : uniquement les bandes explicitement OCEAN des
## SECTOR.DAT. Une riviere, un marais ou l'absence d'eau ne peut donc plus se
## transformer en niveau marin global. En cas de plusieurs hauteurs, la valeur
## la plus frequente gagne (puis la plus basse en cas d'egalite).
static func _resolve_region_sea_profile(catalog: Dictionary, region: int,
		client_root: String) -> Dictionary:
	var counts := {}
	var ocean_zones: Array[int] = []
	for zone_id_value in catalog:
		var entry := catalog[zone_id_value] as Dictionary
		if int(entry.get("region", -1)) != region or int(entry.get("enabled", 0)) != 1:
			continue
		var zone_id := int(zone_id_value)
		var source := _sector_path_for_entry(entry, client_root, zone_id)
		if source.is_empty():
			continue
		var sections := _read_ini_sections(source)
		var zone_has_ocean := false
		for section_name_value in sections:
			var section_name := str(section_name_value)
			if not section_name.begins_with("river"):
				continue
			var body := sections[section_name] as Dictionary
			if str(body.get("type", "")).strip_edges().to_upper() != "OCEAN":
				continue
			var height := float(str(body.get("height", "0")))
			if height <= 0.0:
				continue
			counts[height] = int(counts.get(height, 0)) + 1
			zone_has_ocean = true
		if zone_has_ocean:
			ocean_zones.append(zone_id)
	if counts.is_empty():
		return {"has_ocean": false, "level": DEFAULT_SEA_LEVEL, "source": "none", "ocean_zones": []}
	var chosen := INF
	var chosen_count := -1
	for height_value in counts:
		var height := float(height_value)
		var count := int(counts[height_value])
		if count > chosen_count or (count == chosen_count and height < chosen):
			chosen = height
			chosen_count = count
	ocean_zones.sort()
	return {
		"has_ocean": true,
		"level": chosen,
		"source": "SECTOR.DAT type=OCEAN region %d" % region,
		"ocean_zones": ocean_zones,
	}


static func _sector_path_for_entry(entry: Dictionary, client_root: String,
		zone_id: int) -> String:
	var key_files := entry.get("key_files", {}) as Dictionary
	var catalog_path := str(key_files.get("sector.dat", "")).strip_edges().replace("\\", "/")
	if not catalog_path.is_empty() and FileAccess.file_exists(catalog_path):
		return catalog_path
	if client_root.is_empty():
		return ""
	var derived := client_root.path_join("zones/zone%03d/dat%03d/SECTOR.DAT" % [zone_id, zone_id])
	return derived if FileAccess.file_exists(derived) else ""


static func _unique_sorted_floats(values: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		if result.is_empty() or not is_equal_approx(result[result.size() - 1], value):
			result.append(value)
	return result


static func _covered_by_any_zone(point: Vector2, footprints: Array) -> bool:
	for value in footprints:
		var rect := (value as Dictionary).get("rect", Rect2()) as Rect2
		if rect.has_point(point):
			return true
	return false


## Le parent de la branche d'horizon. `host` par defaut, donc rien ne change
## pour un appelant qui ne demande rien.
static func _horizon_parent(host: Node3D, settings: Dictionary) -> Node3D:
	var parent: Node3D = settings.get("parent", null) as Node3D
	return parent if parent != null else host


## Detruit la branche d'horizon sous `parent`.
##
## Meme piege qu'a R1 et pour la meme raison : `queue_free` ne detruit qu'en fin
## de trame. La branche est DETACHEE tout de suite, sinon une reconstruction dans
## la meme trame trouverait deux `DaocDistantTerrainRoot` et Godot renommerait le
## neuf.
static func clear(parent: Node3D) -> void:
	var previous := parent.get_node_or_null(ROOT_NAME)
	if previous != null:
		parent.remove_child(previous)
		previous.queue_free()


## Un maillage par zone, en coordonnees monde puis ramene au repere de l'hote.
static func _build_zone_mesh(entry: Dictionary, heights: PackedByteArray, step: int,
		base: Vector2, world_scale: float, height_exaggeration: float,
		sea_level: float, region_footprints: Array, cliff_material: Material,
		cliffs_enabled: bool, border_fog_material: Material,
		border_fog_enabled: bool, maritime_edges: Dictionary,
		lod_colour_atlas: Texture2D = null, fine_edges: Array = [],
		near_step: int = DEFAULT_NEAR_STEP, near_band_raw: float = DEFAULT_NEAR_BAND_RAW,
		near_ramp_raw: float = DEFAULT_NEAR_RAMP_RAW) -> Dictionary:
	var resolution := int(entry.get("resolution", 256))
	if resolution <= 1 or heights.size() < resolution * resolution * 2:
		return {}

	var origin_values := entry.get("world_origin", [0, 0]) as Array
	if origin_values.size() < 2:
		return {}
	var origin := Vector2(float(origin_values[0]), float(origin_values[1]))
	var offset := (origin - base) * world_scale

	# Grille. On garde toujours la derniere colonne et la derniere rangee, sinon
	# les zones voisines ne se touchent pas et on recree un trou.
	var columns: Array[int] = _build_columns(resolution, step, fine_edges,
		near_step, near_band_raw, near_ramp_raw)

	# Les echantillons du r16 sont au CENTRE de leur cellule — c'est ce que fait
	# DaocTerrainRuntime avec son `- 0.5`. Poses tels quels, du premier au
	# dernier, ils couvrent 65280 unites au lieu de 65536 : il manque une demi
	# cellule de chaque cote, et deux zones voisines laisseraient une couture
	# fine entre elles.
	#
	# Pour un decor d'horizon, l'absence de couture prime sur 0,4 % de justesse.
	# On etire donc la grille pour qu'elle couvre exactement le pave de la zone,
	# de 0 a 65536. Le terrain de PRES, lui, garde l'echantillonnage exact.
	var lowest := INF
	var highest := -INF
	var grid: Array = []
	for row_index in columns:
		var row: Array = []
		for column_index in columns:
			var height := float(_height_at(heights, resolution, column_index, row_index))
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
			row.append(height)
		grid.append(row)

	var span := maxf(highest - lowest, 1.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	if lod_colour_atlas != null:
		terrain_material.albedo_texture = lod_colour_atlas
		# ANISOTROPE AU PALIER PROCHE, et ce n'est pas une coquetterie : le sol
		# d'une voisine se regarde en RASANT depuis le bord partagé. À cet angle,
		# le filtrage mipmap ordinaire choisit un niveau très bas et efface tout
		# le gain de résolution — le palier natif aurait coûté 22 Mio pour rien.
		# Constaté sur la première planche de contrôle du jalon : les deux
		# captures étaient indiscernables tant que ce filtre manquait.
		terrain_material.texture_filter = \
			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if not fine_edges.is_empty() \
			else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	terrain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	terrain_material.roughness = 0.95
	terrain_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	surface.set_material(terrain_material)

	var side := columns.size()
	for row in range(side - 1):
		for column in range(side - 1):
			var quad := [
				Vector2i(column, row), Vector2i(column + 1, row),
				Vector2i(column + 1, row + 1), Vector2i(column, row + 1),
			]
			# Deux triangles. L'ordre compte : inverse, les normales pointent vers
			# le bas, la surface est eliminee vue d'en haut et il ne reste que les
			# pentes. Le relief plat devient alors invisible — c'est exactement le
			# symptome qu'on cherchait a corriger.
			for triple in [[0, 1, 2], [0, 2, 3]]:
				for corner in triple:
					var point := quad[corner] as Vector2i
					var height := float((grid[point.y] as Array)[point.x])
					var colour := Color.WHITE if lod_colour_atlas != null else COLOUR_LOW.lerp(COLOUR_HIGH, clampf((height - lowest) / span, 0.0, 1.0))
					colour.a = _terrain_edge_opacity(int(entry.get("zone", -1)), origin,
						point, columns, resolution, region_footprints)
					surface.set_color(colour)
					surface.set_uv(Vector2(
						float(columns[point.x]) / float(resolution - 1),
						float(columns[point.y]) / float(resolution - 1)
					))
					surface.add_vertex(Vector3(
						offset.x + _span_position(columns[point.x], resolution) * world_scale,
						height * world_scale * height_exaggeration,
						offset.y + _span_position(columns[point.y], resolution) * world_scale
					))
	surface.generate_normals()
	var mesh := surface.commit() as ArrayMesh
	var cliff_segments := 0
	if cliffs_enabled and mesh != null:
		cliff_segments = _append_exposed_cliffs(mesh, int(entry.get("zone", -1)),
			origin, offset, grid, columns, resolution, world_scale,
			height_exaggeration, sea_level, region_footprints, cliff_material)
	var border_fog := {"segments": 0, "maritime_skipped": 0}
	if border_fog_enabled and mesh != null:
		border_fog = _append_non_maritime_border_fog(mesh, int(entry.get("zone", -1)),
			origin, offset, grid, columns, resolution, world_scale,
			height_exaggeration, sea_level, region_footprints, border_fog_material,
			maritime_edges)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DistantZone%03d" % int(entry.get("zone", 0))
	mesh_instance.mesh = mesh
	# Un decor d'horizon ne projette pas d'ombre et n'en recoit pas : c'est du
	# cout pur pour un detail qu'on ne verra jamais a cette distance.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("daoc_zone", int(entry.get("zone", -1)))
	mesh_instance.set_meta("daoc_zone_name", str(entry.get("name", "")))
	mesh_instance.set_meta("daoc_distant_only", true)
	mesh_instance.set_meta("daoc_lod_colour_atlas", lod_colour_atlas != null)
	mesh_instance.set_meta("daoc_exposed_cliff_segments", cliff_segments)
	mesh_instance.set_meta("daoc_border_fog_segments", int(border_fog.get("segments", 0)))
	mesh_instance.set_meta("daoc_border_fog_maritime_skipped", int(border_fog.get("maritime_skipped", 0)))

	var vertex_count := (side - 1) * (side - 1) * 6
	return {
		"node": mesh_instance,
		"grid_side": side,
		"vertices": vertex_count,
		"triangles": vertex_count / 3,
		"cliff_segments": cliff_segments,
		"border_fog_segments": int(border_fog.get("segments", 0)),
		"border_fog_maritime_segments_skipped": int(border_fog.get("maritime_skipped", 0)),
	}


## Les indices d'echantillonnage d'un cote de la zone.
##
## UNE SEULE LISTE SERT AUX DEUX AXES, et c'est un choix, pas un oubli. Le
## maillage, les falaises, le voile de bord et le fondu partagent tous ce tableau
## depuis P1-20J ; en tenir deux demanderait de recroiser quatre fonctions pour
## un gain qui n'existe pas. Densifier le bord `x_min` densifie donc aussi les
## rangees, ce qui produit au pire quelques quads fins de trop dans un coin — et
## AUCUNE difference de nettete de texture, l'atlas etant echantillonne par
## fragment via les UV, jamais par sommet.
##
## Sans bord fin declare, le resultat est EXACTEMENT la grille reguliere d'avant
## P1-33 : c'est ce qui garantit qu'une zone lointaine ordinaire n'a pas bouge.
static func _build_columns(resolution: int, step: int, fine_edges: Array,
		near_step: int, band_raw: float, ramp_raw: float) -> Array[int]:
	var columns: Array[int] = []
	if resolution <= 1:
		return columns
	var coarse := maxi(1, step)
	var fine := clampi(near_step, 1, coarse)
	var fine_low := fine_edges.has("x_min") or fine_edges.has("y_min")
	var fine_high := fine_edges.has("x_max") or fine_edges.has("y_max")
	var index := 0
	while index < resolution:
		columns.append(index)
		index += _step_at(index, resolution, coarse, fine, band_raw, ramp_raw,
			fine_low, fine_high)
	if columns[columns.size() - 1] != resolution - 1:
		columns.append(resolution - 1)
	return columns


## Le pas a utiliser a cet endroit : fin dans la bande, puis DOUBLE a chaque
## palier de rampe jusqu'a retrouver le pas grossier. Une reprise brutale du pas
## se lit comme une arete franche sur le relief, exactement le genre de couture
## que ce jalon cherche a supprimer.
static func _step_at(index: int, resolution: int, coarse: int, fine: int,
		band_raw: float, ramp_raw: float, fine_low: bool, fine_high: bool) -> int:
	if not fine_low and not fine_high:
		return coarse
	var distance := INF
	if fine_low:
		distance = minf(distance, _span_position(index, resolution))
	if fine_high:
		distance = minf(distance, ZONE_WORLD_SIZE - _span_position(index, resolution))
	if distance <= band_raw:
		return fine
	var ramps := int((distance - band_raw) / maxf(ramp_raw, 1.0))
	return clampi(fine << mini(ramps, 16), fine, coarse)


## Assemble les 64 tuiles LOD de couleur du client dans UNE texture reduite.
## La convention native est colonne-rangee (`lodXX-YY`), identique aux secteurs
## terrain. On n'essaie jamais le DDS : le client fourni contient deja les PNG.
static func _load_lod_colour_atlas(client_root: String, zone_id: int,
		requested_size: int) -> Dictionary:
	# Le plafond etait 1024. Il monte a la taille NATIVE de l'assemblage — huit
	# tuiles de 256 px — parce qu'en dessous on jette de la source qui existe.
	var atlas_size := clampi(requested_size, 256, NATIVE_LOD_ATLAS_SIZE)
	atlas_size -= atlas_size % LOD_TILE_GRID
	var tile_size := maxi(1, atlas_size / LOD_TILE_GRID)
	var zone_name := "zone%03d" % zone_id
	var lod_name := "lod%03d" % zone_id
	var directory := client_root.path_join("zones").path_join(zone_name).path_join(lod_name)
	var atlas := Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.28, 0.32, 0.25, 1.0))
	var loaded := 0
	for tile_y in LOD_TILE_GRID:
		for tile_x in LOD_TILE_GRID:
			var path := directory.path_join("lod%02d-%02d.png" % [tile_x, tile_y])
			if not FileAccess.file_exists(path):
				continue
			var tile := Image.new()
			if tile.load(path) != OK:
				continue
			tile.convert(Image.FORMAT_RGBA8)
			# A la taille native la tuile est posee TELLE QUELLE : redimensionner
			# une image vers sa propre taille depenserait un Lanczos complet pour
			# recopier des pixels identiques.
			if tile.get_width() != tile_size or tile.get_height() != tile_size:
				tile.resize(tile_size, tile_size, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(tile, Rect2i(0, 0, tile_size, tile_size),
				Vector2i(tile_x * tile_size, tile_y * tile_size))
			loaded += 1
	if loaded != LOD_TILE_GRID * LOD_TILE_GRID:
		return {
			"texture": null, "complete": false, "tiles_loaded": loaded,
			"directory": directory, "estimated_bytes": 0, "atlas_size": atlas_size,
		}
	atlas.generate_mipmaps()
	var texture := ImageTexture.create_from_image(atlas)
	return {
		"texture": texture,
		"complete": texture != null,
		"tiles_loaded": loaded,
		"directory": directory,
		"atlas_size": atlas_size,
		# RGBA8 + chaine mipmap complete ~= taille de base * 4/3.
		"estimated_bytes": int(atlas_size * atlas_size * 4 * 4 / 3),
	}


## Fond le dessus du terrain avant sa tranche, sur trois points de la grille
## grossiere. Un raccord couvert par une autre zone reste totalement opaque ;
## seules les vraies limites de l'assemblage sont dissoutes.
## P1-33 — le fondu est desormais une DISTANCE et non un nombre de points de
## grille. Avec une grille reguliere les deux reviennent au meme, et 3084 unites
## reproduisent la courbe `0 / 0,38 / 0,72` du pas 4 d'origine a un centieme
## pres. Avec une grille densifiee, en revanche, compter des POINTS retrecissait
## le fondu d'un bord expose parce qu'un AUTRE bord avait ete affine — un effet
## de bord silencieux, et le mot est pour une fois litteral.
static func _terrain_edge_opacity(zone_id: int, origin: Vector2, point: Vector2i,
		columns: Array[int], resolution: int,
		region_footprints: Array) -> float:
	var opacity := 1.0
	var local := Vector2(
		_span_position(columns[point.x], resolution),
		_span_position(columns[point.y], resolution)
	)
	if not _covered_by_other_zone(origin + Vector2(0.0, local.y) + Vector2(-128.0, 0.0), zone_id, region_footprints):
		opacity = minf(opacity, _edge_fade(local.x))
	if not _covered_by_other_zone(origin + Vector2(ZONE_WORLD_SIZE, local.y) + Vector2(128.0, 0.0), zone_id, region_footprints):
		opacity = minf(opacity, _edge_fade(ZONE_WORLD_SIZE - local.x))
	if not _covered_by_other_zone(origin + Vector2(local.x, 0.0) + Vector2(0.0, -128.0), zone_id, region_footprints):
		opacity = minf(opacity, _edge_fade(local.y))
	if not _covered_by_other_zone(origin + Vector2(local.x, ZONE_WORLD_SIZE) + Vector2(0.0, 128.0), zone_id, region_footprints):
		opacity = minf(opacity, _edge_fade(ZONE_WORLD_SIZE - local.y))
	return opacity


## Opacite a `distance` unites d'une tranche exposee. L'exposant 0,85 reproduit
## la courbe d'origine, legerement plus rapide qu'une rampe lineaire.
static func _edge_fade(distance: float) -> float:
	if distance >= TERRAIN_EDGE_FADE_RAW:
		return 1.0
	return pow(clampf(distance / TERRAIN_EDGE_FADE_RAW, 0.0, 1.0), 0.85)


## Ferme seulement les tranches terrestres qui donnent réellement sur le vide.
## Une sonde juste a l'exterieur de chaque segment elimine les recouvrements et
## raccords en escalier avec les autres zones de la region.
static func _append_exposed_cliffs(mesh: ArrayMesh, zone_id: int, origin: Vector2,
		offset: Vector2, grid: Array, columns: Array[int], resolution: int,
		world_scale: float, height_exaggeration: float, sea_level: float,
		region_footprints: Array, cliff_material: Material) -> int:
	if grid.is_empty() or columns.size() < 2:
		return 0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(cliff_material)
	var last := columns.size() - 1
	var segment_count := 0
	var edge_specs := [
		{"name": "north", "outward": Vector2(0.0, -1.0)},
		{"name": "south", "outward": Vector2(0.0, 1.0)},
		{"name": "west", "outward": Vector2(-1.0, 0.0)},
		{"name": "east", "outward": Vector2(1.0, 0.0)},
	]
	for edge_value in edge_specs:
		var edge := edge_value as Dictionary
		var edge_name := str(edge["name"])
		var outward := edge["outward"] as Vector2
		for segment in range(last):
			var a_index: Vector2i
			var b_index: Vector2i
			match edge_name:
				"north":
					a_index = Vector2i(segment, 0)
					b_index = Vector2i(segment + 1, 0)
				"south":
					a_index = Vector2i(segment + 1, last)
					b_index = Vector2i(segment, last)
				"west":
					a_index = Vector2i(0, segment + 1)
					b_index = Vector2i(0, segment)
				_:
					a_index = Vector2i(last, segment)
					b_index = Vector2i(last, segment + 1)
			var local_a := Vector2(
				_span_position(columns[a_index.x], resolution),
				_span_position(columns[a_index.y], resolution)
			)
			var local_b := Vector2(
				_span_position(columns[b_index.x], resolution),
				_span_position(columns[b_index.y], resolution)
			)
			var outside_probe := origin + (local_a + local_b) * 0.5 + outward * 128.0
			if _covered_by_other_zone(outside_probe, zone_id, region_footprints):
				continue
			var height_a := float((grid[a_index.y] as Array)[a_index.x])
			var height_b := float((grid[b_index.y] as Array)[b_index.x])
			# Les ouvertures sous-marines restent de la vraie mer, pas un mur.
			if maxf(height_a, height_b) <= sea_level + CLIFF_MIN_LAND_ABOVE_SEA:
				continue
			var top_a := Vector3(
				offset.x + local_a.x * world_scale,
				height_a * world_scale * height_exaggeration,
				offset.y + local_a.y * world_scale
			)
			var top_b := Vector3(
				offset.x + local_b.x * world_scale,
				height_b * world_scale * height_exaggeration,
				offset.y + local_b.y * world_scale
			)
			var bottom_y := (sea_level - CLIFF_BOTTOM_BELOW_SEA) * world_scale * height_exaggeration
			var bottom_a := Vector3(top_a.x, bottom_y, top_a.z)
			var bottom_b := Vector3(top_b.x, bottom_y, top_b.z)
			var u0 := float(segment) * 0.72
			var u1 := float(segment + 1) * 0.72
			var va := maxf((height_a - (sea_level - CLIFF_BOTTOM_BELOW_SEA)) / 1800.0, 0.15)
			var vb := maxf((height_b - (sea_level - CLIFF_BOTTOM_BELOW_SEA)) / 1800.0, 0.15)
			_add_textured_quad(surface,
				top_a, top_b, bottom_b, bottom_a,
				Vector2(u0, va), Vector2(u1, vb), Vector2(u1, 0.0), Vector2(u0, 0.0),
				CLIFF_HAZE_TOP_OPACITY, CLIFF_HAZE_TOP_OPACITY,
				CLIFF_HAZE_BOTTOM_OPACITY, CLIFF_HAZE_BOTTOM_OPACITY)
			segment_count += 1
	if segment_count <= 0:
		return 0
	surface.generate_normals()
	surface.commit(mesh)
	return segment_count


## Nappe locale posee SUR une frontiere terrestre exposee. Contrairement au
## fog global, elle ne delave ni la mer ni le reste de l'horizon. Le test
## `min(height_a, height_b)` est la garantie « si et seulement si pas de mer » :
## un segment mixte plage/terre est classe maritime et ne recoit rien.
##
## ATTENTION AVALON : voir l'avertissement majuscule pres des constantes. Cette
## geometrie a ete calibree sur la coupure Isle of Glass -> Avalon Isle et peut
## etre trop large ou masquer un relief voulu ailleurs.
static func _append_non_maritime_border_fog(mesh: ArrayMesh, zone_id: int,
		origin: Vector2, offset: Vector2, grid: Array, columns: Array[int],
		resolution: int, world_scale: float, height_exaggeration: float,
		sea_level: float, region_footprints: Array, fog_material: Material,
		maritime_edges: Dictionary) -> Dictionary:
	if grid.is_empty() or columns.size() < 2:
		return {"segments": 0, "maritime_skipped": 0}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(fog_material)
	var last := columns.size() - 1
	var segment_count := 0
	var maritime_skipped := 0
	var edge_specs := [
		{"name": "north", "outward": Vector2(0.0, -1.0)},
		{"name": "south", "outward": Vector2(0.0, 1.0)},
		{"name": "west", "outward": Vector2(-1.0, 0.0)},
		{"name": "east", "outward": Vector2(1.0, 0.0)},
	]
	for edge_value in edge_specs:
		var edge := edge_value as Dictionary
		var edge_name := str(edge["name"])
		var outward := edge["outward"] as Vector2
		var outward_3d := Vector3(outward.x, 0.0, outward.y)
		for segment in range(last):
			var a_index: Vector2i
			var b_index: Vector2i
			match edge_name:
				"north":
					a_index = Vector2i(segment, 0)
					b_index = Vector2i(segment + 1, 0)
				"south":
					a_index = Vector2i(segment + 1, last)
					b_index = Vector2i(segment, last)
				"west":
					a_index = Vector2i(0, segment + 1)
					b_index = Vector2i(0, segment)
				_:
					a_index = Vector2i(last, segment)
					b_index = Vector2i(last, segment + 1)
			var local_a := Vector2(
				_span_position(columns[a_index.x], resolution),
				_span_position(columns[a_index.y], resolution)
			)
			var local_b := Vector2(
				_span_position(columns[b_index.x], resolution),
				_span_position(columns[b_index.y], resolution)
			)
			var outside_probe := origin + (local_a + local_b) * 0.5 + outward * 128.0
			if _covered_by_other_zone(outside_probe, zone_id, region_footprints):
				continue
			# Si SECTOR.DAT est absent/illisible on ne peut pas prouver que le bord
			# est terrestre : la politique « si et seulement si » interdit la nappe.
			if not bool(maritime_edges.get("known", false)):
				maritime_skipped += 1
				continue
			if _border_segment_is_maritime(edge_name, local_a, local_b, maritime_edges):
				maritime_skipped += 1
				continue
			var height_a := float((grid[a_index.y] as Array)[a_index.x])
			var height_b := float((grid[b_index.y] as Array)[b_index.x])
			# GARDE MARITIME STRICTE : un seul sommet marin suffit pour interdire
			# la nappe sur tout le segment.
			if minf(height_a, height_b) <= sea_level + CLIFF_MIN_LAND_ABOVE_SEA:
				maritime_skipped += 1
				continue

			var edge_a := Vector3(
				offset.x + local_a.x * world_scale,
				height_a * world_scale * height_exaggeration,
				offset.y + local_a.y * world_scale
			)
			var edge_b := Vector3(
				offset.x + local_b.x * world_scale,
				height_b * world_scale * height_exaggeration,
				offset.y + local_b.y * world_scale
			)
			var lift := 180.0 * world_scale * height_exaggeration
			var mid_a := edge_a + Vector3.UP * lift + outward_3d * (120.0 * world_scale)
			var mid_b := edge_b + Vector3.UP * lift + outward_3d * (120.0 * world_scale)
			var low_y := (sea_level + CLIFF_MIN_LAND_ABOVE_SEA) * world_scale * height_exaggeration
			var low_a := Vector3(mid_a.x, low_y, mid_a.z)
			var low_b := Vector3(mid_b.x, low_y, mid_b.z)
			var high_a := mid_a + Vector3.UP * (BORDER_FOG_TOP_RISE * world_scale * height_exaggeration)
			var high_b := mid_b + Vector3.UP * (BORDER_FOG_TOP_RISE * world_scale * height_exaggeration)
			var u0 := float(segment) * 0.77
			var u1 := float(segment + 1) * 0.77
			_add_fog_quad(surface, low_a, low_b, mid_b, mid_a,
				Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.5), Vector2(u0, 0.5),
				0.0, 0.0, BORDER_FOG_PEAK_OPACITY, BORDER_FOG_PEAK_OPACITY)
			_add_fog_quad(surface, mid_a, mid_b, high_b, high_a,
				Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, 1.0), Vector2(u0, 1.0),
				BORDER_FOG_PEAK_OPACITY, BORDER_FOG_PEAK_OPACITY, 0.0, 0.0)

			# Ruban horizontal : il couvre le bord superieur en dents de scie que
			# la seule jupe verticale ne pouvait pas masquer dans la vue joueur.
			var inward := -outward_3d * (BORDER_FOG_INWARD_WIDTH * world_scale)
			var outward_span := outward_3d * (BORDER_FOG_OUTWARD_WIDTH * world_scale)
			var inner_a := edge_a + inward + Vector3.UP * lift
			var inner_b := edge_b + inward + Vector3.UP * lift
			var outer_a := edge_a + outward_span + Vector3.UP * lift
			var outer_b := edge_b + outward_span + Vector3.UP * lift
			_add_fog_quad(surface, inner_a, inner_b, mid_b, mid_a,
				Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.5), Vector2(u0, 0.5),
				0.0, 0.0, BORDER_FOG_PEAK_OPACITY, BORDER_FOG_PEAK_OPACITY)
			_add_fog_quad(surface, mid_a, mid_b, outer_b, outer_a,
				Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, 1.0), Vector2(u0, 1.0),
				BORDER_FOG_PEAK_OPACITY, BORDER_FOG_PEAK_OPACITY, 0.0, 0.0)
			segment_count += 1
	if segment_count > 0:
		surface.generate_normals()
		surface.commit(mesh)
	return {"segments": segment_count, "maritime_skipped": maritime_skipped}


static func _add_fog_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2,
		uv_d: Vector2, alpha_a: float, alpha_b: float, alpha_c: float,
		alpha_d: float) -> void:
	var vertices := [a, b, c, d]
	var uvs := [uv_a, uv_b, uv_c, uv_d]
	var alphas := [alpha_a, alpha_b, alpha_c, alpha_d]
	for triple in [[0, 1, 2], [0, 2, 3]]:
		for index_value in triple:
			var index := int(index_value)
			surface.set_uv(uvs[index] as Vector2)
			surface.set_color(Color(1.0, 1.0, 1.0, float(alphas[index])))
			surface.add_vertex(vertices[index] as Vector3)


static func _add_textured_quad(surface: SurfaceTool, top_a: Vector3, top_b: Vector3,
		bottom_b: Vector3, bottom_a: Vector3, uv_top_a: Vector2,
		uv_top_b: Vector2, uv_bottom_b: Vector2, uv_bottom_a: Vector2,
		top_a_opacity: float = 1.0, top_b_opacity: float = 1.0,
		bottom_b_opacity: float = 1.0, bottom_a_opacity: float = 1.0) -> void:
	var vertices := [top_a, top_b, bottom_b, bottom_a]
	var uvs := [uv_top_a, uv_top_b, uv_bottom_b, uv_bottom_a]
	var opacities := [top_a_opacity, top_b_opacity, bottom_b_opacity, bottom_a_opacity]
	for triple in [[0, 1, 2], [0, 2, 3]]:
		for index_value in triple:
			var index := int(index_value)
			surface.set_uv(uvs[index] as Vector2)
			surface.set_color(Color(1.0, 1.0, 1.0, float(opacities[index])))
			surface.add_vertex(vertices[index] as Vector3)


static func _covered_by_other_zone(point: Vector2, zone_id: int, footprints: Array) -> bool:
	for value in footprints:
		var footprint := value as Dictionary
		if int(footprint.get("zone", -1)) == zone_id:
			continue
		var rect := footprint.get("rect", Rect2()) as Rect2
		if rect.has_point(point):
			return true
	return false


## Lit les bandes OCEAN natives qui touchent chaque cote du carre de zone.
## Ce sont elles — pas une supposition sur la couleur/hauteur du terrain — qui
## disent qu'une coupure est deja bordee par la mer et ne doit pas recevoir la
## nappe experimentale Avalon.
static func _read_ocean_border_ranges(client_root: String, zone_id: int) -> Dictionary:
	var result := {
		"known": false,
		"source": "",
		"north": [], "south": [], "west": [], "east": [],
	}
	if client_root.is_empty():
		return result
	var source := client_root.path_join("zones/zone%03d/dat%03d/SECTOR.DAT" % [zone_id, zone_id])
	result["source"] = source
	if not FileAccess.file_exists(source):
		return result
	var sections := _read_ini_sections(source)
	if sections.is_empty():
		return result
	result["known"] = true
	for section_name_value in sections:
		var section_name := str(section_name_value)
		if not section_name.begins_with("river"):
			continue
		var body := sections[section_name] as Dictionary
		if str(body.get("type", "")).strip_edges().to_upper() != "OCEAN":
			continue
		var bankpoints := int(str(body.get("bankpoints", "0")))
		if bankpoints < 2:
			continue
		for point_index in range(bankpoints - 1):
			var keys := [
				"left%02d" % point_index, "right%02d" % point_index,
				"left%02d" % (point_index + 1), "right%02d" % (point_index + 1),
			]
			var points: Array[Vector2] = []
			for key_value in keys:
				var key := str(key_value)
				if body.has(key) and not str(body[key]).strip_edges().is_empty():
					points.append(_sector_dat_point_raw(str(body[key])))
			if points.size() < 4:
				continue
			var min_x := INF
			var max_x := -INF
			var min_y := INF
			var max_y := -INF
			for point in points:
				min_x = minf(min_x, point.x)
				max_x = maxf(max_x, point.x)
				min_y = minf(min_y, point.y)
				max_y = maxf(max_y, point.y)
			if min_y <= 1.0:
				(result["north"] as Array).append(Vector2(min_x, max_x))
			if max_y >= ZONE_WORLD_SIZE - 1.0:
				(result["south"] as Array).append(Vector2(min_x, max_x))
			if min_x <= 1.0:
				(result["west"] as Array).append(Vector2(min_y, max_y))
			if max_x >= ZONE_WORLD_SIZE - 1.0:
				(result["east"] as Array).append(Vector2(min_y, max_y))
	return result


static func _border_segment_is_maritime(edge_name: String, local_a: Vector2,
		local_b: Vector2, maritime_edges: Dictionary) -> bool:
	var segment_min := minf(local_a.x, local_b.x) if edge_name in ["north", "south"] else minf(local_a.y, local_b.y)
	var segment_max := maxf(local_a.x, local_b.x) if edge_name in ["north", "south"] else maxf(local_a.y, local_b.y)
	for range_value in maritime_edges.get(edge_name, []) as Array:
		var ocean_range := range_value as Vector2
		# Une petite marge evite une fente de brouillard a la jointure entre deux
		# quads de la bande oceanique native.
		if segment_max >= ocean_range.x - 128.0 and segment_min <= ocean_range.y + 128.0:
			return true
	return false


static func _read_ini_sections(path: String) -> Dictionary:
	var sections := {}
	var active := ""
	for raw_line in _read_legacy_text(path).split("\n"):
		var line := str(raw_line).strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.contains("]"):
			active = line.substr(1, line.find("]") - 1).strip_edges().to_lower()
			if not sections.has(active):
				sections[active] = {}
			continue
		if active.is_empty() or not line.contains("="):
			continue
		var separator := line.find("=")
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		var comment := value.find(";")
		if comment >= 0:
			value = value.substr(0, comment).strip_edges()
		(sections[active] as Dictionary)[key] = value
	return sections


static func _read_legacy_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	var characters := PackedStringArray()
	characters.resize(bytes.size())
	for index in range(bytes.size()):
		characters[index] = String.chr(int(bytes[index]))
	return "".join(characters)


static func _sector_dat_point_raw(value: String) -> Vector2:
	var parts := value.split(",", false)
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(float(parts[0].strip_edges()) * 256.0,
		float(parts[1].strip_edges()) * 256.0)


## Relief purement visuel situe au-dela de l'emprise connue. Il brise la ligne
## ciel/mer trop vide, mais laisse environ un quart de son perimetre ouvert afin
## que l'archipel conserve de vraies echappees maritimes.
static func _build_horizon_backdrop(catalog: Dictionary, region: int, base: Vector2,
		world_scale: float, height_exaggeration: float, sea_level: float,
		cliff_material: Material, settings: Dictionary) -> Dictionary:
	var bounds := _region_bounds(catalog, region)
	if bounds.size == Vector2.ZERO:
		return {}
	var distance_raw := float(settings.get("horizon_backdrop_distance_raw", ZONE_WORLD_SIZE * 0.72))
	bounds = bounds.grow(distance_raw)
	var segments_per_side := maxi(8, int(settings.get("horizon_segments_per_side", 28)))
	var bottom_y := (sea_level - 180.0) * world_scale * height_exaggeration
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(cliff_material)
	var corners := [
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]
	var segments := 0
	var sea_gaps := 0
	for side_index in range(4):
		var side_a := corners[side_index] as Vector2
		var side_b := corners[(side_index + 1) % 4] as Vector2
		for segment in range(segments_per_side):
			# Trois cases ouvertes sur onze : assez de terre pour habiller, assez
			# de mer pour ne pas enfermer visuellement toute la region.
			if _horizon_segment_is_gap(side_index, segment):
				sea_gaps += 1
				continue
			var t0 := float(segment) / float(segments_per_side)
			var t1 := float(segment + 1) / float(segments_per_side)
			var world_a := side_a.lerp(side_b, t0)
			var world_b := side_a.lerp(side_b, t1)
			var height_a := sea_level + _horizon_height(side_index, segment)
			var height_b := sea_level + _horizon_height(side_index, segment + 1)
			var local_a := (world_a - base) * world_scale
			var local_b := (world_b - base) * world_scale
			var top_a := Vector3(local_a.x, height_a * world_scale * height_exaggeration, local_a.y)
			var top_b := Vector3(local_b.x, height_b * world_scale * height_exaggeration, local_b.y)
			var bottom_a := Vector3(local_a.x, bottom_y, local_a.y)
			var bottom_b := Vector3(local_b.x, bottom_y, local_b.y)
			var u0 := float(side_index * segments_per_side + segment) * 1.15
			var u1 := u0 + 1.15
			# Le premier/dernier point contigu a une trouee maritime devient quasi
			# transparent. L'interpolation sur tout le segment supprime la tranche
			# verticale que l'oeil reperait en plein champ de vision.
			var opacity_a := 0.06 if _horizon_segment_is_gap(side_index, posmod(segment - 1, segments_per_side)) else 1.0
			var opacity_b := 0.06 if _horizon_segment_is_gap(side_index, posmod(segment + 1, segments_per_side)) else 1.0
			_add_textured_quad(surface,
				top_a, top_b, bottom_b, bottom_a,
				Vector2(u0, (height_a - sea_level + 180.0) / 1800.0),
				Vector2(u1, (height_b - sea_level + 180.0) / 1800.0),
				Vector2(u1, 0.0), Vector2(u0, 0.0),
				opacity_a, opacity_b, opacity_b, opacity_a)
			segments += 1
	if segments <= 0:
		return {}
	surface.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DistantHorizonBackdrop"
	mesh_instance.mesh = surface.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("daoc_distant_only", true)
	mesh_instance.set_meta("daoc_horizon_backdrop", true)
	mesh_instance.set_meta("daoc_horizon_segments", segments)
	mesh_instance.set_meta("daoc_horizon_sea_gaps", sea_gaps)
	return {"node": mesh_instance, "segments": segments, "sea_gaps": sea_gaps}


static func _horizon_height(side_index: int, point_index: int) -> float:
	var phase := float(point_index + side_index * 37)
	return 1600.0 + 1400.0 * (0.5 + 0.5 * sin(phase * 1.73)) + 900.0 * (0.5 + 0.5 * sin(phase * 0.61 + 1.2))


static func _horizon_segment_is_gap(side_index: int, segment: int) -> bool:
	return posmod(segment + side_index * 2, 11) in [3, 4, 5]


static func _region_footprints(catalog: Dictionary, region: int) -> Array:
	var footprints: Array = []
	for zone_id in catalog:
		var entry := catalog[zone_id] as Dictionary
		if int(entry.get("region", -1)) != region or int(entry.get("enabled", 0)) != 1:
			continue
		if str(entry.get("pipeline", "")) != "terrain_heightmap":
			continue
		var values := entry.get("world_origin", []) as Array
		if values.size() < 2:
			continue
		footprints.append({
			"zone": int(zone_id),
			"rect": Rect2(float(values[0]), float(values[1]), ZONE_WORLD_SIZE, ZONE_WORLD_SIZE),
		})
	return footprints


static func _region_bounds(catalog: Dictionary, region: int) -> Rect2:
	var bounds := Rect2()
	var seen := false
	for value in _region_footprints(catalog, region):
		var rect := (value as Dictionary).get("rect", Rect2()) as Rect2
		bounds = rect if not seen else bounds.merge(rect)
		seen = true
	return bounds if seen else Rect2()


static func _make_cliff_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DaocDistantCliffShader
	material.set_shader_parameter("cliff_texture", texture)
	material.set_shader_parameter("cliff_tint", Color(0.68, 0.70, 0.66))
	material.set_shader_parameter("local_haze_tint", Color(0.62, 0.70, 0.74))
	return material


static func _make_border_fog_material(fog_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DaocDistantBorderFogShader
	material.set_shader_parameter("fog_color", fog_color.lerp(Color.WHITE, 0.42))
	return material


static func _load_external_png(path: String) -> Texture2D:
	if path.is_empty() or not path.to_lower().ends_with(".png") or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Position d'un echantillon, etiree pour que la grille couvre exactement le
## pave de la zone. Voir la note sur la couture dans _build_zone_mesh.
static func _span_position(sample_index: int, resolution: int) -> float:
	if resolution <= 1:
		return 0.0
	return float(sample_index) / float(resolution - 1) * ZONE_WORLD_SIZE


## Meme decodage que DaocTerrainRuntime : entier 16 bits peu-boutiste, et la
## valeur EST la hauteur monde.
static func _height_at(heights: PackedByteArray, resolution: int, column: int, row: int) -> int:
	var index := (row * resolution + column) * 2
	if index < 0 or index + 1 >= heights.size():
		return 0
	return heights[index] | (heights[index + 1] << 8)


static func _read_heightmap(data_dir: String, zone_id: int) -> PackedByteArray:
	var path := data_dir.path_join("zone%03d_height.r16" % zone_id)
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


## Le catalogue indexe les 456 zones du client en un seul fichier : region,
## origine monde et nom. On evite ainsi d'ouvrir 456 metadonnees.
static func _read_catalog(data_dir: String) -> Dictionary:
	var path := data_dir.path_join(CATALOG_NAME)
	if not FileAccess.file_exists(path):
		# Le catalogue vit a la racine du cache, pas dans data/.
		path = data_dir.get_base_dir().path_join(CATALOG_NAME)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var zones: Variant = (parsed as Dictionary).get("zones", [])
	if not zones is Array:
		return {}
	var out := {}
	for value in zones as Array:
		if not value is Dictionary:
			continue
		var entry := (value as Dictionary).duplicate(true)
		if not entry.has("resolution"):
			entry["resolution"] = 256
		out[int(entry.get("zone", -1))] = entry
	return out


static func _resolve_data_dir(host: Node3D) -> String:
	for property in ["daoc_client_root", "client_root"]:
		var root := str(host.get(property))
		if root.is_empty():
			continue
		var candidate := root.replace("\\", "/").path_join("_godot_daoc_cache/data")
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""
