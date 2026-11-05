extends RefCounted
class_name DaocZoneJumpStep

## R4 — cinquième tranche : les zonejumps quittent le ZoneViewer.
##
## `zonejump.csv` décrit les zones de transition vers les régions voisines.
## L'étape écrit sous `MechanicsDebugRoot`, tient l'index de session et **câble**
## le runtime : c'est la seule des cinq migrées qui fasse les deux — `bind` sur
## l'index et `wire` sur les aires produites.
##
## UN GARDE EXISTE ICI, et il est conservé tel quel. Contrairement aux tranches
## 2, 3 et 4, le relais d'origine testait bien un drapeau : `build_zonejump_debug`
## décoché ne se contente pas de ne rien faire — il **vide** l'index de la zone et
## rebranche le runtime. C'est pour cela que le garde reste DANS l'étape et n'est
## pas remonté en `zone_step_enabled_r4` : une étape non lancée laisserait l'index
## en l'état, donc des aires de transition fantômes d'une zone précédente.
##
## Ce qui bouge : la résolution du chemin, la lecture du CSV, la dé-duplication
## optionnelle, le contexte de transformation, l'accrochage et les index. Ce qui
## ne bouge PAS : `DaocZoneJumpBuilder`, validé en 14A.

const ZoneJumpBuilderScript = preload("res://src/daoc/DaocZoneJumpBuilder.gd")
const TransformContextScript = preload("res://src/daoc/DaocZoneJumpTransformContext.gd")

## Réglages lus dans l'inspecteur. Rassemblés par l'hôte, jamais devinés ici.
const SETTING_KEYS := [
	"build_zonejump_debug", "world_scale", "height_exaggeration",
	"zonejump_thickness_raw", "zonejump_debug_visible", "zonejump_area_enabled",
	"zonejump_optional_dedupe_pairs",
]


## Construit les aires de transition d'une zone. Le retour décrit ce qui s'est
## passé, y compris les raisons de ne rien faire.
static func build(services: DaocZoneBuildServices, znum: int, origin3: Vector3,
		settings: Dictionary, log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": znum}

	var state: RefCounted = services.state

	# Le garde d'origine, deplacé sans être touché : décoché, il VIDE la zone.
	if not bool(settings.get("build_zonejump_debug", false)):
		_clear_zone(services, znum)
		return {"ok": true, "built": false, "reason": "zonejump_debug_decoche", "zone": znum}

	var path: String = services.asset_zone_file(znum, "zonejump.csv")
	if path == "":
		_clear_zone(services, znum)
		services.log_step(log_enabled, "zone%03d zonejump: no zonejump.csv found" % znum)
		return {"ok": true, "built": false, "reason": "zonejump_csv_absent", "zone": znum}

	var entries: Array = services.parse_zonejump_csv(path)
	if bool(settings.get("zonejump_optional_dedupe_pairs", false)):
		entries = ZoneJumpBuilderScript.dedupe_reverse_pairs(entries)
	state.zonejump_entries_by_zone[znum] = entries

	var xform := TransformContextScript.new()
	xform.call("setup", znum, origin3,
		float(settings.get("world_scale", 1.0)),
		float(settings.get("height_exaggeration", 1.0)),
		float(settings.get("zonejump_thickness_raw", 60.0)),
		bool(settings.get("zonejump_debug_visible", false)),
		bool(settings.get("zonejump_area_enabled", true)))

	var result: RefCounted = ZoneJumpBuilderScript.build(znum, entries, xform)
	if result == null:
		_clear_zone(services, znum)
		return {"ok": false, "reason": "le constructeur 14A n'a rien rendu", "zone": znum}

	state.zonejump_build_results[znum] = result
	state.zonejump_areas_by_zone[znum] = result.get("areas")
	state.zonejump_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_static_index(state, znum, result.get("static_index") as Array)

	var result_root: Node3D = result.get("root") as Node3D
	if result_root != null:
		var branch: Node3D = services.zone_branch(znum, "MechanicsDebugRoot")
		if branch != null:
			branch.add_child(result_root)

	# Deux gestes, pas un : `bind` sur l'index, `wire` sur les aires. Le second
	# est ce qui fait entrer le joueur en collision avec une transition ; l'index
	# seul ne declencherait rien.
	var runtime: Object = services.ensure_zonejump_runtime()
	if runtime != null:
		runtime.call("bind", state.zonejump_static_index)
		runtime.call("wire", result.get("areas") as Array)

	var metrics: Dictionary = result.get("metrics") as Dictionary
	services.log_step(log_enabled,
		"zone%03d zonejump: %d entry/entries (%d target(s)) from %s [14A builder areas=%d sig=%s]" % [
			znum,
			int(metrics.get("entries", entries.size())),
			int(metrics.get("targets", 0)),
			path,
			int(metrics.get("areas", 0)),
			str(result.get("index_signature")),
		])

	return {
		"ok": true, "built": true, "zone": znum,
		"source_path": path,
		"entries": entries.size(),
		"areas": int(metrics.get("areas", 0)),
		"index_signature": str(result.get("index_signature")),
	}


## Vide la zone et rebranche le runtime.
##
## Le rebranchement compte autant que le vidage : sans lui, le runtime
## continuerait de répondre depuis l'index précédent, et une aire de transition
## disparue téléporterait encore.
static func _clear_zone(services: DaocZoneBuildServices, znum: int) -> void:
	var state: RefCounted = services.state
	state.zonejump_entries_by_zone[znum] = []
	_replace_static_index(state, znum, [])
	var runtime: Object = services.ensure_zonejump_runtime()
	if runtime != null:
		runtime.call("bind", state.zonejump_static_index)


static func _replace_static_index(state: RefCounted, znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in state.zonejump_static_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in zone_index:
		kept.append(item)
	state.zonejump_static_index = kept
