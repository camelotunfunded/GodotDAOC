extends RefCounted
class_name DaocZoneTerrainStep

## R4 — troisième tranche : le terrain quitte le ZoneViewer.
##
## C'est la première étape de la bascule qui écrit dans DEUX branches — le relief
## sous `TerrainRoot`, les corps de collision sous `CollisionRoot` — et la seule
## dont l'index alimente un runtime que le joueur interroge à chaque image :
## `DaocTerrainRuntime` est l'échantillonneur d'altitude. Une divergence ici ne
## se verrait pas comme une texture manquante, elle se verrait comme un joueur
## qui traverse le sol.
##
## Ce qui bouge : la lecture du manifeste « splat », la préparation de ses
## ressources, la texture de sol, l'accrochage dans les deux branches et
## l'écriture des index de session. Ce qui ne bouge PAS : `DaocTerrainBuilder`,
## validé en 14E, qui reste l'autorité de construction. Aucune règle de relief
## n'est réécrite ici.
##
## AUCUN GARDE N'A ÉTÉ AJOUTÉ, même raison qu'à la tranche 2 : le relais
## d'origine ne testait aucun drapeau — il n'existe pas de `build_terrain`, et
## `build_terrain_collision` agit plus loin, dans le constructeur 14E.
## Introduire ici une condition inexistante changerait le comportement au lieu
## de déplacer la propriété. La trace suit la même règle : elle était
## inconditionnelle, elle le reste.

const TerrainBuilderScript = preload("res://src/daoc/DaocTerrainBuilder.gd")
const TerrainRuntimeScript = preload("res://src/daoc/DaocTerrainRuntime.gd")

## Réglages lus dans l'inspecteur. Rassemblés par l'hôte, jamais devinés ici :
## l'étape refuse d'inventer une valeur par défaut qui divergerait de celle du
## viewer.
const SETTING_KEYS := [
	"world_scale", "height_exaggeration", "build_terrain_collision",
	"terrain_collision_layer", "terrain_collision_mask", "tile_scale",
	"terrain_pbr",
]


## Construit le relief d'une zone. Le retour décrit ce qui s'est passé, y compris
## les raisons de ne rien faire : une zone sans manifeste « splat » n'est pas une
## erreur — elle est simplement rendue avec sa texture de sol unique.
static func build(services: DaocZoneBuildServices, znum: int, meta: Dictionary,
		hb: PackedByteArray, res: int, origin3: Vector3, meta_path: String,
		settings: Dictionary, log_enabled: bool = true) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}
	if hb.is_empty() or res <= 0:
		# Le relief EST la carte de hauteurs. Sans elle il n'y a rien à bâtir, et
		# un plan à plat serait pire qu'un refus : le joueur marcherait dessus.
		return {"ok": false, "reason": "carte de hauteurs vide", "zone": znum}

	var splat_manifest: Dictionary = {}
	var splat_manifest_path: String = services.asset_data_path("zone%03d_splat/manifest.json" % znum)
	if FileAccess.file_exists(splat_manifest_path):
		var loaded: Variant = services.asset_read_json(splat_manifest_path)
		if typeof(loaded) == TYPE_DICTIONARY:
			splat_manifest = loaded as Dictionary
			services.prepare_terrain_splat_resources(znum, splat_manifest)

	var ground_texture: Texture2D = null
	var ground_path: String = services.asset_data_path("zone%03d_ground.png" % znum)
	if FileAccess.file_exists(ground_path) \
			or (ground_path.begins_with("res://") and ResourceLoader.exists(ground_path)):
		ground_texture = services.asset_texture(ground_path)

	var state: RefCounted = services.state
	var full_settings: Dictionary = settings.duplicate(true)
	full_settings["source_path"] = meta_path
	full_settings["splat_manifest"] = splat_manifest
	# Les trois ressources « splat » vivent dans l'état de session, pas dans les
	# réglages : elles sont préparées juste au-dessus et partagées entre zones.
	full_settings["splat_shader"] = state.splat_shader
	full_settings["splat_details"] = state.splat_details
	full_settings["splat_masks"] = state.splat_masks
	full_settings["ground_texture"] = ground_texture
	# Sol PBR : les tableaux de la zone vivent dans l'etat de session comme les
	# trois ressources splat ; les reglages (coche, intensites) viennent de
	# l'hote, dans `terrain_pbr`. Les deux sont reunis ici, et seulement ici.
	var pbr_options: Dictionary = (settings.get("terrain_pbr", {}) as Dictionary).duplicate()
	var pbr_maps: Dictionary = state.splat_pbr_by_zone.get(znum, {}) as Dictionary
	if bool(pbr_options.get("enabled", false)) and bool(pbr_maps.get("ok", false)):
		pbr_options["normals"] = pbr_maps.get("normals")
		pbr_options["roughness"] = pbr_maps.get("roughness")
		pbr_options["ao"] = pbr_maps.get("ao")
		full_settings["splat_pbr"] = pbr_options

	var result: RefCounted = TerrainBuilderScript.build(znum, meta, hb, origin3, full_settings)
	_publish_indexes(services, znum, result)
	if result == null:
		return {"ok": false, "reason": "le constructeur 14E n'a rien rendu", "zone": znum}

	var metrics: Dictionary = result.get("metrics") as Dictionary
	services.log_step(log_enabled,
		"zone%03d terrain: %d sector(s), %d mesh(es), %d collision body/bodies [14E builder sig=%s]" % [
			znum,
			int(metrics.get("sectors", 0)),
			int(metrics.get("terrain_meshes", 0)),
			int(metrics.get("collision_bodies", 0)),
			str(result.get("index_signature")),
		])

	return {
		"ok": true, "built": true, "zone": znum,
		"sectors": int(metrics.get("sectors", 0)),
		"meshes": int(metrics.get("terrain_meshes", 0)),
		"collision_bodies": int(metrics.get("collision_bodies", 0)),
		"uses_splat": int(metrics.get("sectors", 0)) > 1,
		"index_signature": str(result.get("index_signature")),
	}


## Dépose les index dans l'état de SESSION et relie le runtime.
##
## Un constructeur qui ne rend rien n'est pas ignoré : la zone est RETIRÉE des
## index. Sans cela, une reconstruction ratée laisserait l'échantillonneur
## d'altitude répondre depuis l'ancien relief — le sol invisible du pire genre,
## celui qui a l'air de marcher.
static func _publish_indexes(services: DaocZoneBuildServices, znum: int, result: RefCounted) -> void:
	var state: RefCounted = services.state
	if result == null:
		state.terrain_build_results.erase(znum)
		state.terrain_meshes_by_zone[znum] = []
		state.terrain_collision_bodies_by_zone[znum] = []
		_replace_static_index(state, znum, [])
		_bind_runtime(state)
		return

	state.terrain_build_results[znum] = result

	var root: Node3D = result.get("root") as Node3D
	if root != null:
		var branch: Node3D = services.zone_branch(znum, "TerrainRoot")
		if branch != null:
			branch.add_child(root)
	var collision_root: Node3D = result.get("collision_root") as Node3D
	if collision_root != null and collision_root.get_child_count() > 0:
		var collision_branch: Node3D = services.collision_branch(znum)
		if collision_branch != null:
			collision_branch.add_child(collision_root)

	state.terrain_meshes_by_zone[znum] = result.get("terrain_meshes") as Array
	state.terrain_collision_bodies_by_zone[znum] = result.get("collision_bodies") as Array
	state.terrain_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_static_index(state, znum, result.get("static_index") as Array)
	_bind_runtime(state)


## L'index statique est REMPLACÉ zone par zone plutôt que vidé : sinon recharger
## une zone effacerait le relief de toutes les autres, et l'horizon P1-20J avec.
static func _replace_static_index(state: RefCounted, znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in state.terrain_static_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in zone_index:
		kept.append(item)
	state.terrain_static_index = kept


static func _bind_runtime(state: RefCounted) -> void:
	if state.terrain_runtime_obj == null:
		state.terrain_runtime_obj = TerrainRuntimeScript.new()
	state.terrain_runtime_obj.call("bind", state.terrain_static_index, state.zone_runtime)
