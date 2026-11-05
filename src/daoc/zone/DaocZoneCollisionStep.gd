extends RefCounted
class_name DaocZoneCollisionStep

## R4 — quatrième tranche : les frontières de zone quittent le ZoneViewer.
##
## `bound.csv` décrit les murs invisibles d'une zone. Deux consommateurs, et
## c'est toute la subtilité de l'étape : les corps physiques sous `CollisionRoot`
## quand `build_bound_collision` est coché, et l'index de session que le solveur
## du joueur interroge — lui, **toujours**, même sans corps physique. C'est
## pourquoi une zone sans `bound.csv` ne se contente pas de ne rien faire : elle
## **vide** explicitement son index et relie le runtime. Une frontière fantôme
## restée d'une zone précédente arrêterait le joueur au milieu de nulle part.
##
## Ce qui bouge : la résolution du chemin, la collecte des réglages,
## l'accrochage et l'écriture des index. Ce qui ne bouge PAS :
## `DaocCollisionBuilder`, validé en 14C, qui reste l'autorité de construction.
##
## AUCUN GARDE N'A ÉTÉ AJOUTÉ, même règle que les tranches 2 et 3 : le relais
## d'origine ne testait aucun drapeau avant de construire. `build_bound_collision`
## agit à l'intérieur — il décide de l'accrochage des corps, pas de la lecture du
## fichier ni de l'index. Le remonter en garde d'entrée priverait le solveur du
## joueur de ses segments, ce qui serait un changement de comportement et non un
## déplacement de propriété.

const CollisionBuilderScript = preload("res://src/daoc/DaocCollisionBuilder.gd")
const CollisionRuntimeScript = preload("res://src/daoc/DaocCollisionRuntime.gd")

## Réglages lus dans l'inspecteur. Rassemblés par l'hôte, jamais devinés ici.
## `hb` et `res` n'y figurent pas : ils viennent de `zone_runtime`, que l'étape
## lit dans l'état de session — ce sont des données de zone, pas des réglages.
const SETTING_KEYS := [
	"build_bound_collision", "world_scale", "height_exaggeration",
	"bound_collision_layer", "bound_collision_mask",
	"bound_collision_thickness_raw", "bound_collision_bottom_offset_raw",
	"bound_collision_top_offset_raw", "bound_collision_debug_visible",
	"bound_collision_blocks_player",
]


## Construit les frontières d'une zone. Le retour décrit ce qui s'est passé, y
## compris les raisons de ne rien faire : une zone sans `bound.csv` n'est pas une
## erreur — beaucoup de zones n'en ont pas.
static func build(services: DaocZoneBuildServices, znum: int, origin3: Vector3,
		settings: Dictionary, log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}

	var state: RefCounted = services.state
	var path: String = services.asset_zone_file(znum, "bound.csv")
	if path == "":
		_clear_zone(state, znum)
		# La trace d'origine ne parlait que si l'un des deux consommateurs était
		# actif : sans corps physique ni solveur, l'absence n'intéresse personne.
		services.log_step(
			log_enabled and (bool(settings.get("build_bound_collision", false))
				or bool(settings.get("bound_collision_blocks_player", false))),
			"zone%03d bound: no bound.csv found" % znum)
		return {"ok": true, "built": false, "reason": "bound_csv_absent", "zone": znum}

	var segments: Array = CollisionBuilderScript.parse_bound_csv(path)
	var zone_data: Dictionary = state.zone_runtime.get(znum, {}) as Dictionary

	var full_settings: Dictionary = settings.duplicate(true)
	full_settings["source_path"] = path
	# La carte de hauteurs ancre les murs sur le relief : sans elle, le
	# constructeur 14C les pose à plat. Elle vient de `zone_runtime`, remplie par
	# l'assembleur avant l'étape.
	full_settings["hb"] = zone_data.get("hb", PackedByteArray())
	full_settings["res"] = int(zone_data.get("res", 0))

	var result: RefCounted = CollisionBuilderScript.build_boundary(znum, segments, origin3, full_settings)
	if result == null:
		_clear_zone(state, znum)
		return {"ok": false, "reason": "le constructeur 14C n'a rien rendu", "zone": znum}

	var root: Node3D = result.get("root") as Node3D
	if root != null and bool(settings.get("build_bound_collision", false)):
		var branch: Node3D = services.collision_branch(znum)
		if branch != null:
			branch.add_child(root)

	state.boundary_build_results[znum] = result
	var static_index: Array = result.get("boundary_segments") as Array
	state.boundary_runtime[znum] = static_index.duplicate(true)
	state.collision_boundary_signature_by_zone[znum] = str(result.get("boundary_index_signature"))
	_replace_static_index(state, znum, static_index)
	_bind_runtime(state)

	if bool(settings.get("build_bound_collision", false)):
		services.log_step(log_enabled,
			"zone%03d bound: %d collision segment(s) from %s [14C builder sig=%s]"
				% [znum, static_index.size(), path, str(result.get("boundary_index_signature"))])
	else:
		services.log_step(log_enabled,
			"zone%03d bound: %d segment(s) registered for player solver only from %s [14C builder sig=%s]"
				% [znum, static_index.size(), path, str(result.get("boundary_index_signature"))])

	return {
		"ok": true, "built": true, "zone": znum,
		"source_path": path,
		"segments": static_index.size(),
		"collision_built": bool(settings.get("build_bound_collision", false)),
		"index_signature": str(result.get("boundary_index_signature")),
	}


## Une zone sans frontières VIDE son index au lieu de le laisser tel quel.
##
## C'est le point sensible de cette étape : le solveur du joueur lit l'index même
## quand aucun corps physique n'est bâti. Une frontière héritée d'une zone
## précédente l'arrêterait contre un mur qui n'existe pas.
static func _clear_zone(state: RefCounted, znum: int) -> void:
	state.boundary_runtime[znum] = []
	_replace_static_index(state, znum, [])
	_bind_runtime(state)


static func _replace_static_index(state: RefCounted, znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in state.collision_static_boundary_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in zone_index:
		kept.append(item)
	state.collision_static_boundary_index = kept


## Le runtime relie les DEUX index : frontières et props. L'étape ne touche que
## le premier, mais rebrancher sans le second laisserait le solveur sans les
## collisions de props — d'où le rappel des deux, comme le faisait le viewer.
static func _bind_runtime(state: RefCounted) -> void:
	if state.collision_runtime_obj == null:
		state.collision_runtime_obj = CollisionRuntimeScript.new()
	state.collision_runtime_obj.call("bind_boundary", state.collision_static_boundary_index)
	state.collision_runtime_obj.call("bind_props", state.collision_static_prop_index)
