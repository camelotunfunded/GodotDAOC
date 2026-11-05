extends RefCounted
class_name DaocZoneWaterStep

## R4 — première tranche : l'eau quitte le ZoneViewer.
##
## Étape pilote, choisie parce qu'elle est la plus propre des sept : quatre
## aides seulement, dont deux simples lecteurs de données. Ce qu'elle prouve
## vaudra pour le terrain, les collisions, les zonejumps et les props.
##
## Ce qui bouge : la collecte des réglages, l'accrochage dans `WaterRoot` et
## l'écriture des index de session. Ce qui ne bouge PAS : `DaocWaterBuilder`,
## validé en 14B puis étendu par P1-20L, qui reste l'autorité de construction.
## Aucune règle d'eau n'est réécrite ici.
##
## L'étape ne connaît pas le ZoneViewer. Elle reçoit des `settings` déjà
## rassemblés et un `DaocZoneBuildServices` ; c'est tout. Elle est donc
## appelable depuis l'assembleur sans que celui-ci rappelle l'hôte.

const WaterBuilderScript = preload("res://src/daoc/DaocWaterBuilder.gd")
const WaterRuntimeScript = preload("res://src/daoc/DaocWaterRuntime.gd")

## Réglages lus dans l'inspecteur. Rassemblés par l'hôte, jamais devinés ici :
## l'étape refuse d'inventer une valeur par défaut qui divergerait de celle du
## viewer.
const SETTING_KEYS := [
	"client_root", "world_scale", "height_exaggeration", "water_alpha",
	"water_vertical_offset", "water_tessellation_cap", "water_uv_world_scale",
	"use_legacy_water_color", "water_shore_enabled", "water_shore_strength",
]


## Construit l'eau d'une zone. Le retour décrit ce qui s'est passé, y compris
## les raisons de ne rien faire : une zone sans `SECTOR.DAT` n'est pas une
## erreur, et un silence non expliqué serait pire qu'un échec.
static func build(services: DaocZoneBuildServices, znum: int, origin3: Vector3,
		settings: Dictionary, log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}

	var sector_path: String = services.sector_dat_path(znum)
	if sector_path == "":
		services.log_step(log_enabled,
			"zone%03d water: no SECTOR.DAT found; expected zone%03d_sector.dat or raw dat%03d/SECTOR.DAT"
				% [znum, znum, znum])
		return {"ok": true, "built": false, "reason": "sector_dat_absent", "zone": znum}

	var sector: Dictionary = services.parse_sector_dat(sector_path)
	if sector.is_empty() or not sector.has("waterdefs"):
		return {"ok": true, "built": false, "reason": "aucun waterdef", "zone": znum}

	var full_settings: Dictionary = settings.duplicate(true)
	full_settings["sector_path"] = sector_path

	var res: RefCounted = WaterBuilderScript.build(znum, sector, origin3, full_settings)
	if res == null:
		return {"ok": false, "reason": "le constructeur 14B n'a rien rendu", "zone": znum}

	var root: Node3D = res.get("root") as Node3D
	if root != null:
		var branch: Node3D = services.zone_branch(znum, "WaterRoot")
		if branch == null:
			return {"ok": false, "reason": "branche WaterRoot introuvable", "zone": znum}
		branch.add_child(root)

	_publish_indexes(services, znum, res)

	var metrics: Dictionary = res.get("metrics") as Dictionary
	services.log_step(log_enabled,
		"zone%03d water: %d/%d body/bodies from %s [14B builder meshes=%d sig=%s]" % [
			znum,
			int(metrics.get("bodies", 0)),
			int(metrics.get("waterdefs", 0)),
			sector_path,
			int(metrics.get("meshes", 0)),
			str(res.get("index_signature")),
		])

	return {
		"ok": true, "built": true, "zone": znum,
		"sector_path": sector_path,
		"bodies": int(metrics.get("bodies", 0)),
		"meshes": int(metrics.get("meshes", 0)),
		"index_signature": str(res.get("index_signature")),
	}


## Dépose les index dans l'état de SESSION.
##
## Ces index survivent au déchargement de la zone : c'est la distinction que R1 a
## établie, et c'est pour cela qu'ils ne vivent pas dans la branche de zone.
## L'index statique est remplacé zone par zone plutôt que vidé, sinon recharger
## une zone effacerait l'eau de toutes les autres.
static func _publish_indexes(services: DaocZoneBuildServices, znum: int, res: RefCounted) -> void:
	var state: RefCounted = services.state
	var static_index: Array = res.get("static_index") as Array

	state.water_build_results[znum] = res
	state.water_meshes_by_zone[znum] = res.get("meshes") as Array
	state.water_index_signature_by_zone[znum] = str(res.get("index_signature"))

	var kept: Array = []
	for item in state.water_static_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in static_index:
		kept.append(item)
	state.water_static_index = kept

	state.water_runtime[znum] = static_index.duplicate(true)
	if state.water_runtime_obj == null:
		state.water_runtime_obj = WaterRuntimeScript.new()
	state.water_runtime_obj.call("bind", state.water_static_index)
