extends RefCounted
class_name DaocZoneCreator

## P1-16A1/A2/A3a — ZoneCreator foundation + export editor-visible.
##
## But : créer une base de scène de zone propre, hors refactor ZoneViewer, puis
## sauvegarder un .tscn rechargeable dans l'éditeur. A2 exportait un shell sûr ;
## A3a ajoute la population visuelle terrain + eau, sans props/collisions.
## HOTFIX2 recentre la scène générée autour de la grille éditeur, sans toucher au runtime.
## A3b ajoute une stratégie preview props bornée/sectorisée.
## A3c tranche l’architecture : une scène complète par zone, avec full props zone000.
## A4 ajoute les données éditeur non-visuelles : collisions + zonejumps.
## A5a ajoute un batch multi-zone limité, basé sur la liste de zones configurée.
## A6 ajoute un export service orienté znum, découplé des oracles zone000.
## A7 ajoute un batch contrôlé explicite + manifest disque, hors F12 global lourd.
## A10A ajoute la classification explicite terrain/donjon/tileworld avant export.

const DaocZoneCreationResultScript = preload("res://src/daoc/DaocZoneCreationResult.gd")
const DaocZoneKindResolverScript = preload("res://src/daoc/DaocZoneKindResolver.gd")
const DaocDungeonSceneBuilderScript = preload("res://src/daoc/dungeon/DaocDungeonSceneBuilder.gd")
const DaocDungeonFileResolverScript = preload("res://src/daoc/dungeon/DaocDungeonFileResolver.gd")

const SCOPE: String = "P1-16A1 ZoneCreator foundation"
const CHECKPOINT: String = "P1_16A1_ZONECREATOR_FOUNDATION"
const EXPORT_SCOPE: String = "P1-16A2 ZoneCreator editor scene export"
const EXPORT_CHECKPOINT: String = "P1_16A2_ZONECREATOR_EDITOR_SCENE_EXPORT"
const TERRAIN_WATER_SCOPE: String = "P1-16A3a ZoneCreator terrain water population"
const TERRAIN_WATER_CHECKPOINT: String = "P1_16A3A_ZONECREATOR_TERRAIN_WATER_POPULATION"
const PROPS_STRATEGY_SCOPE: String = "P1-16A3b ZoneCreator props strategy"
const PROPS_STRATEGY_CHECKPOINT: String = "P1_16A3B_ZONECREATOR_PROPS_STRATEGY"
const FULL_ZONE_PROPS_SCOPE: String = "P1-16A3c ZoneCreator full zone props"
const FULL_ZONE_PROPS_CHECKPOINT: String = "P1_16A3C_ZONECREATOR_FULL_ZONE_PROPS"
const GAMEPLAY_DEBUG_SCOPE: String = "P1-16A4 ZoneCreator collision zonejump editor data"
const GAMEPLAY_DEBUG_CHECKPOINT: String = "P1_16A4_ZONECREATOR_COLLISION_ZONEJUMP_EDITOR_DATA"
const MULTI_ZONE_BATCH_SCOPE: String = "P1-16A5a ZoneCreator multi-zone batch foundation"
const MULTI_ZONE_BATCH_CHECKPOINT: String = "P1_16A5A_ZONECREATOR_MULTI_ZONE_BATCH_FOUNDATION"
const ZONE_EXPORT_SERVICE_SCOPE: String = "P1-16A6 ZoneSceneExportService"
const ZONE_EXPORT_SERVICE_CHECKPOINT: String = "P1_16A6_ZONE_SCENE_EXPORT_SERVICE"
const CONTROLLED_BATCH_MANIFEST_SCOPE: String = "P1-16A7 ZoneCreator controlled multi-zone batch manifest"
const CONTROLLED_BATCH_MANIFEST_CHECKPOINT: String = "P1_16A7_CONTROLLED_MULTI_ZONE_BATCH_MANIFEST"
const ZONE_KIND_CLASSIFICATION_SCOPE: String = "P1-16A10A zone kind classification manifest"
const ZONE_KIND_CLASSIFICATION_CHECKPOINT: String = "P1_16A10A_ZONE_KIND_CLASSIFICATION_MANIFEST"
const DUNGEON_SCENE_EXPORT_SCOPE: String = "P1-17C2 ZoneCreator dungeon_chunk integration"
const DUNGEON_SCENE_EXPORT_CHECKPOINT: String = "P1_17C2_ZONECREATOR_DUNGEON_CHUNK_INTEGRATION"
const DUNGEON_BATCH_SCOPE: String = "P1-17C2 GeneratedDungeonScene regression batch"
const DUNGEON_BATCH_CHECKPOINT: String = "P1_17C2_GENERATED_DUNGEON_SCENE_BATCH"
const GENERATED_DUNGEON_REPORT_SCOPE: String = "P1-17C3 GeneratedDungeonScene regression report"
const GENERATED_DUNGEON_REPORT_CHECKPOINT: String = "P1_17C3_GENERATED_DUNGEON_SCENE_REGRESSION_REPORT"
const DEFAULT_ZONE_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"
const DEFAULT_DUNGEON_MANIFEST_PATH: String = "res://reports/generated/zones/dungeon_manifest.json"
const DEFAULT_DUNGEON_REPORT_JSON_PATH: String = "res://reports/daoc_generated_dungeon_report.json"
const DEFAULT_DUNGEON_REPORT_TXT_PATH: String = "res://reports/daoc_generated_dungeon_report.txt"
const DEFAULT_PROP_PREVIEW_LIMIT: int = 256
const DEFAULT_BRANCHES = [
	"TerrainRoot",
	"StaticPropsRoot",
	"CollisionRoot",
	"WaterRoot",
	"ZoneJumpRoot",
	"VisualsRoot",
	"DebugRoot",
]

const EXPECTED_SIGNATURES := {
	"zonejump": "27a4632b710a6cdb202c18e182793954",
	"water": "9fb7474a4dab25cb828a4973b2c12e15",
	"boundary": "1154ee2f495873b7f8461dd88536908e",
	"prop": "46d670df525a69230158d643f5a70468",
	"terrain": "7601093f060a7b75f2c3e6824c40f05f",
}

var _last_result: RefCounted = null


func create_zone_scene(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var result: RefCounted = DaocZoneCreationResultScript.new()
	result.set("scope", SCOPE)
	result.set("checkpoint", CHECKPOINT)
	result.set("zone", znum)
	result.set("creation_mode", str(options.get("creation_mode", "detached_editor_ready_shell")))
	result.set("generated_scene_path", _default_scene_path(znum))
	_apply_zone_kind_to_result(host, znum, result)

	var root := _create_zone_root(znum)
	result.set("root", root)
	_apply_zone_kind_meta(root, result)
	for branch_name in DEFAULT_BRANCHES:
		var branch := _ensure_branch(root, str(branch_name))
		result.call("set_branch", str(branch_name), branch)

	result.set("source_snapshots", _collect_source_snapshots(host))
	if bool(options.get("zone_aware_metrics", false)):
		result.set("signatures", _extract_zone_signatures(host, znum, result.get("source_snapshots") as Dictionary))
		result.set("metrics", _build_zone_aware_metrics(host, znum, root, result))
		if bool(options.get("require_zone_sources", false)):
			_validate_zone_aware_sources(result)
	else:
		result.set("signatures", _extract_signatures(result.get("source_snapshots") as Dictionary))
		result.set("metrics", _build_metrics(root, result))
		if not bool(options.get("skip_fixed_signature_validation", false)):
			_validate_against_expected_signatures(result)

	var attach := bool(options.get("attach_to_host", false))
	if attach:
		if host != null:
			host.add_child(root)
			result.set("attached_to_host", true)
		else:
			result.call("add_error", "attach_to_host requested but host is null")

	var packable_ok := _pack_probe(root)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["packable_ok"] = packable_ok
	result.set("metrics", metrics)
	if not packable_ok:
		result.call("add_error", "generated root is not packable")

	if (result.get("errors") as Array).is_empty():
		result.set("ok", true)
	_last_result = result
	return result


func create_zone_scene_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := create_zone_scene(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_generated_scene(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	export_options["creation_mode"] = str(options.get("creation_mode", "exported_editor_visible_shell"))
	export_options["attach_to_host"] = false
	var result := create_zone_scene(host, znum, export_options)
	if result == null:
		return result

	var active_scope := str(options.get("export_scope", EXPORT_SCOPE))
	var active_checkpoint := str(options.get("export_checkpoint", EXPORT_CHECKPOINT))
	var active_export_mode := str(options.get("export_mode", "editor_visible_shell"))
	result.set("scope", active_scope)
	result.set("checkpoint", active_checkpoint)
	result.set("export_mode", active_export_mode)
	result.set("include_runtime_nodes", bool(options.get("include_runtime_nodes", false)))
	result.set("recommended_next_step", str(options.get("recommended_next_step", "P1-16A3 populate GeneratedZone_000 with runtime visual roots")))

	var scene_path := str(options.get("scene_path", _default_scene_path(znum)))
	result.set("generated_scene_path", scene_path)
	result.set("exported_scene_path", scene_path)
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot export: generated root is null")
		return result

	root.set_meta("daoc_scope", active_scope)
	root.set_meta("daoc_checkpoint", active_checkpoint)
	root.set_meta("daoc_export_mode", active_export_mode)
	root.set_meta("daoc_exported_scene_path", scene_path)
	root.set_meta("daoc_include_runtime_nodes", bool(options.get("include_runtime_nodes", false)))
	root.set_meta("daoc_include_terrain_water_visuals", bool(options.get("include_terrain_water_visuals", false)))
	root.set_meta("daoc_include_props_strategy", bool(options.get("include_props_strategy", false)))
	root.set_meta("daoc_include_collision_editor_data", bool(options.get("include_collision_editor_data", false)))
	root.set_meta("daoc_include_zonejump_editor_data", bool(options.get("include_zonejump_editor_data", false)))
	root.set_meta("daoc_props_strategy", str(options.get("props_strategy", "none")))
	root.set_meta("daoc_collision_editor_strategy", str(options.get("collision_editor_strategy", "none")))
	root.set_meta("daoc_zonejump_editor_strategy", str(options.get("zonejump_editor_strategy", "none")))
	root.set_meta("daoc_props_export_limit", int(options.get("prop_export_limit", DEFAULT_PROP_PREVIEW_LIMIT)))
	root.set_meta("daoc_editor_recenter_enabled", bool(options.get("editor_recenter_to_zone_center", false)))

	if bool(options.get("include_terrain_water_visuals", false)):
		_populate_terrain_water_visuals(host, znum, result)
		if not (result.get("errors") as Array).is_empty():
			return result

	if bool(options.get("include_props_strategy", false)):
		_populate_props_preview_strategy(host, znum, result, options)
		if not (result.get("errors") as Array).is_empty():
			return result

	if bool(options.get("include_collision_editor_data", false)):
		_populate_collision_editor_data(host, znum, result, options)
		if not (result.get("errors") as Array).is_empty():
			return result

	if bool(options.get("include_zonejump_editor_data", false)):
		_populate_zonejump_editor_data(host, znum, result, options)
		if not (result.get("errors") as Array).is_empty():
			return result

	if bool(options.get("editor_recenter_to_zone_center", false)):
		_apply_editor_recenter_to_zone_center(
			host,
			znum,
			result,
			float(options.get("editor_anchor_daoc_x", 32768.0)),
			float(options.get("editor_anchor_daoc_y", 32768.0))
		)
		if not (result.get("errors") as Array).is_empty():
			return result

	var parent_ok := _ensure_scene_parent_dir(scene_path)
	if not parent_ok:
		result.call("add_error", "cannot create scene parent directory: %s" % scene_path)
		return result

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	result.set("pack_error_code", int(pack_err))
	if pack_err != OK:
		result.call("add_error", "PackedScene.pack failed: %d" % int(pack_err))
		return result

	var save_err := ResourceSaver.save(packed, scene_path)
	result.set("export_error_code", int(save_err))
	if save_err != OK:
		result.call("add_error", "ResourceSaver.save failed: %d path=%s" % [int(save_err), scene_path])
		return result

	var file_exists := FileAccess.file_exists(scene_path)
	result.set("file_exists_after_save", file_exists)
	if not file_exists:
		result.call("add_error", "saved scene not found after export: %s" % scene_path)
		return result

	_validate_reloaded_scene(result, scene_path)
	if bool(result.get("reload_ok")) and (result.get("errors") as Array).is_empty():
		result.set("export_ok", true)
		result.set("ok", true)
	_last_result = result
	return result


func export_generated_scene_with_terrain_water(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	export_options["include_terrain_water_visuals"] = true
	export_options["include_runtime_nodes"] = false
	export_options["include_props"] = false
	export_options["include_collisions"] = false
	export_options["editor_recenter_to_zone_center"] = true
	export_options["editor_anchor_daoc_x"] = float(options.get("editor_anchor_daoc_x", 32768.0))
	export_options["editor_anchor_daoc_y"] = float(options.get("editor_anchor_daoc_y", 32768.0))
	export_options["export_scope"] = TERRAIN_WATER_SCOPE
	export_options["export_checkpoint"] = TERRAIN_WATER_CHECKPOINT
	export_options["export_mode"] = "editor_visible_terrain_water"
	export_options["creation_mode"] = "exported_editor_visible_terrain_water"
	export_options["recommended_next_step"] = "P1-16A3b populate GeneratedZone_000 with props strategy"
	return export_generated_scene(host, znum, export_options)


func export_generated_scene_with_terrain_water_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_generated_scene_with_terrain_water(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_generated_scene_with_props_strategy(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	export_options["include_terrain_water_visuals"] = true
	export_options["include_props_strategy"] = true
	export_options["include_runtime_nodes"] = false
	export_options["include_props"] = true
	export_options["include_collisions"] = false
	export_options["editor_recenter_to_zone_center"] = true
	export_options["editor_anchor_daoc_x"] = float(options.get("editor_anchor_daoc_x", 32768.0))
	export_options["editor_anchor_daoc_y"] = float(options.get("editor_anchor_daoc_y", 32768.0))
	export_options["prop_export_limit"] = int(options.get("prop_export_limit", DEFAULT_PROP_PREVIEW_LIMIT))
	export_options["props_strategy"] = str(options.get("props_strategy", "editor_preview_even_sample_sector_buckets"))
	export_options["export_scope"] = PROPS_STRATEGY_SCOPE
	export_options["export_checkpoint"] = PROPS_STRATEGY_CHECKPOINT
	export_options["export_mode"] = "editor_visible_terrain_water_props_preview"
	export_options["creation_mode"] = "exported_editor_visible_props_preview"
	export_options["recommended_next_step"] = "P1-16A3c decide full props export / instancing strategy"
	return export_generated_scene(host, znum, export_options)


func export_generated_scene_with_props_strategy_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_generated_scene_with_props_strategy(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_generated_scene_full_zone_props(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	export_options["include_terrain_water_visuals"] = true
	export_options["include_props_strategy"] = true
	export_options["include_runtime_nodes"] = false
	export_options["include_props"] = true
	export_options["include_collisions"] = false
	export_options["editor_recenter_to_zone_center"] = true
	export_options["editor_anchor_daoc_x"] = float(options.get("editor_anchor_daoc_x", 32768.0))
	export_options["editor_anchor_daoc_y"] = float(options.get("editor_anchor_daoc_y", 32768.0))
	export_options["full_props_export"] = true
	export_options["props_population_kind"] = "full_zone_scene"
	export_options["prop_export_limit"] = int(options.get("prop_export_limit", 99999999))
	export_options["props_strategy"] = str(options.get("props_strategy", "full_zone_scene_sector_buckets"))
	export_options["export_scope"] = FULL_ZONE_PROPS_SCOPE
	export_options["export_checkpoint"] = FULL_ZONE_PROPS_CHECKPOINT
	export_options["export_mode"] = "editor_visible_terrain_water_full_zone_props"
	export_options["creation_mode"] = "exported_editor_visible_full_zone_props"
	export_options["recommended_next_step"] = "P1-16A4 add collisions/zonejump editor data to generated zone scene"
	return export_generated_scene(host, znum, export_options)


func export_generated_scene_full_zone_props_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_generated_scene_full_zone_props(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_generated_scene_with_collision_zonejump_editor_data(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	export_options["include_terrain_water_visuals"] = true
	export_options["include_props_strategy"] = true
	export_options["include_collision_editor_data"] = true
	export_options["include_zonejump_editor_data"] = true
	export_options["include_runtime_nodes"] = false
	export_options["include_props"] = true
	export_options["include_collisions"] = true
	export_options["editor_recenter_to_zone_center"] = true
	export_options["editor_anchor_daoc_x"] = float(options.get("editor_anchor_daoc_x", 32768.0))
	export_options["editor_anchor_daoc_y"] = float(options.get("editor_anchor_daoc_y", 32768.0))
	export_options["full_props_export"] = true
	export_options["props_population_kind"] = "full_zone_scene"
	export_options["prop_export_limit"] = int(options.get("prop_export_limit", 99999999))
	export_options["props_strategy"] = str(options.get("props_strategy", "full_zone_scene_sector_buckets"))
	export_options["collision_editor_strategy"] = str(options.get("collision_editor_strategy", "editor_data_staticbody_roots"))
	export_options["zonejump_editor_strategy"] = str(options.get("zonejump_editor_strategy", "editor_data_area_roots_monitoring_off"))
	export_options["export_scope"] = GAMEPLAY_DEBUG_SCOPE
	export_options["export_checkpoint"] = GAMEPLAY_DEBUG_CHECKPOINT
	export_options["export_mode"] = "editor_visible_full_zone_collision_zonejump"
	export_options["creation_mode"] = "exported_editor_visible_full_zone_collision_zonejump"
	export_options["recommended_next_step"] = "P1-16A5 multi-zone scene generation batch"
	return export_generated_scene(host, znum, export_options)


func export_generated_scene_with_collision_zonejump_editor_data_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_generated_scene_with_collision_zonejump_editor_data(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_generated_zone_scenes_batch(host: Node, options: Dictionary = {}) -> Dictionary:
	var requested_zones: Array[int] = _resolve_batch_zone_list(host, options)
	var max_batch_zones: int = int(options.get("max_batch_zones", 1))
	if max_batch_zones < 1:
		max_batch_zones = 1

	var zones_to_export: Array[int] = []
	for znum in requested_zones:
		if zones_to_export.size() >= max_batch_zones:
			break
		if not zones_to_export.has(int(znum)):
			zones_to_export.append(int(znum))

	var result_items: Array = []
	var exported_zones: Array[int] = []
	var exported_paths: Array[String] = []
	var failed_zones: Array[int] = []
	var ok_count: int = 0
	var fail_count: int = 0
	var zone000_oracle_ok: bool = false
	var zone000_export_path: String = ""

	for znum in zones_to_export:
		var zone_options: Dictionary = options.duplicate(true)
		zone_options.erase("zones")
		zone_options["batch_parent_scope"] = MULTI_ZONE_BATCH_SCOPE
		var zone_result := export_generated_scene_with_collision_zonejump_editor_data(host, int(znum), zone_options)
		var snap: Dictionary = {}
		if zone_result != null and zone_result.has_method("to_debug_dict"):
			snap = zone_result.call("to_debug_dict", false) as Dictionary
		else:
			snap = {"ok": false, "zone": int(znum), "errors": ["zone export result missing"]}

		var zone_ok: bool = bool(snap.get("ok", false)) and bool(snap.get("export_ok", false)) and bool(snap.get("reload_ok", false))
		if zone_ok:
			ok_count += 1
			exported_zones.append(int(znum))
			exported_paths.append(str(snap.get("exported_scene_path", "")))
		else:
			fail_count += 1
			failed_zones.append(int(znum))
		result_items.append(snap)

		if int(znum) == 0:
			zone000_oracle_ok = zone_ok
			zone000_export_path = str(snap.get("exported_scene_path", ""))

		var detached_root: Node = null
		if zone_result != null:
			detached_root = zone_result.get("root") as Node
			if detached_root != null and not detached_root.is_inside_tree():
				detached_root.free()
				zone_result.set("root", null)

	var batch_ok: bool = zones_to_export.size() > 0 and fail_count == 0
	var batch := {
		"scope": MULTI_ZONE_BATCH_SCOPE,
		"checkpoint": MULTI_ZONE_BATCH_CHECKPOINT,
		"ok": batch_ok,
		"batch_mode": "configured_zones_limited_full_a4_export",
		"one_scene_per_zone": true,
		"uses_configured_zone_list": true,
		"default_limited_for_f12": true,
		"requested_zones": requested_zones.duplicate(),
		"zones_to_export": zones_to_export.duplicate(),
		"max_batch_zones": max_batch_zones,
		"zone_count": zones_to_export.size(),
		"ok_count": ok_count,
		"fail_count": fail_count,
		"exported_zones": exported_zones.duplicate(),
		"failed_zones": failed_zones.duplicate(),
		"exported_paths": exported_paths.duplicate(),
		"result_count": result_items.size(),
		"results": result_items,
		"zone000_oracle_ok": zone000_oracle_ok,
		"zone000_export_path": zone000_export_path,
		"a4_export_mode": "editor_visible_full_zone_collision_zonejump",
		"recommended_next_step": "P1-16A5b expand configured zone list / move batch outside global F12",
	}
	return batch


func export_generated_zone_scenes_batch_debug_snapshot(host: Node, options: Dictionary = {}) -> Dictionary:
	return export_generated_zone_scenes_batch(host, options)


func ensure_zone_built_a6(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var before: Dictionary = _zone_source_availability(host, znum)
	var build_called := false
	var build_method_available := host != null and host.has_method("_build_zone")
	if bool(options.get("ensure_zone_built", true)) and not bool(before.get("ready_full_export", false)) and build_method_available:
		host.call("_build_zone", znum)
		build_called = true
	var after: Dictionary = _zone_source_availability(host, znum)
	after["scope"] = ZONE_EXPORT_SERVICE_SCOPE
	after["checkpoint"] = ZONE_EXPORT_SERVICE_CHECKPOINT
	after["zone"] = znum
	after["already_ready"] = bool(before.get("ready_full_export", false))
	after["build_called"] = build_called
	after["build_method_available"] = build_method_available
	after["before"] = before
	return after


func export_zone_scene_a6(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var export_options := options.duplicate(true)
	var classification: Dictionary = classify_zone_kind_a10a(host, znum)
	if not bool(classification.get("supported_for_generated_scene", false)):
		return _make_unsupported_zone_export_result(host, znum, classification)
	var ensure_snapshot: Dictionary = ensure_zone_built_a6(host, znum, export_options)
	export_options["zone_aware_metrics"] = true
	export_options["require_zone_sources"] = bool(options.get("require_zone_sources", true))
	export_options["skip_fixed_signature_validation"] = true
	export_options["include_terrain_water_visuals"] = true
	export_options["include_props_strategy"] = true
	export_options["include_collision_editor_data"] = true
	export_options["include_zonejump_editor_data"] = true
	export_options["include_runtime_nodes"] = false
	export_options["include_props"] = true
	export_options["include_collisions"] = true
	export_options["editor_recenter_to_zone_center"] = true
	export_options["editor_anchor_daoc_x"] = float(options.get("editor_anchor_daoc_x", 32768.0))
	export_options["editor_anchor_daoc_y"] = float(options.get("editor_anchor_daoc_y", 32768.0))
	export_options["full_props_export"] = true
	export_options["props_population_kind"] = "full_zone_scene"
	export_options["prop_export_limit"] = int(options.get("prop_export_limit", 99999999))
	export_options["props_strategy"] = str(options.get("props_strategy", "a6_zone_aware_full_zone_scene_sector_buckets"))
	export_options["collision_editor_strategy"] = str(options.get("collision_editor_strategy", "a6_zone_aware_editor_data_staticbody_roots"))
	export_options["zonejump_editor_strategy"] = str(options.get("zonejump_editor_strategy", "a6_zone_aware_area_roots_monitoring_off"))
	export_options["export_scope"] = ZONE_EXPORT_SERVICE_SCOPE
	export_options["export_checkpoint"] = ZONE_EXPORT_SERVICE_CHECKPOINT
	export_options["export_mode"] = "a6_zone_aware_full_zone_collision_zonejump"
	export_options["creation_mode"] = "a6_zone_scene_export_service"
	export_options["scene_path"] = str(options.get("scene_path", _default_scene_path(znum)))
	export_options["recommended_next_step"] = "P1-16A7 controlled multi-zone batch + manifest"
	var result := export_generated_scene(host, znum, export_options)
	if result != null:
		var metrics: Dictionary = result.get("metrics") as Dictionary
		metrics["a6_ensure_zone_built"] = ensure_snapshot
		metrics["a6_export_service"] = true
		metrics["a6_target_zone"] = znum
		metrics["a6_zone_source_ready"] = bool(ensure_snapshot.get("ready_full_export", false))
		result.set("metrics", metrics)
		if not bool(ensure_snapshot.get("ready_full_export", false)):
			result.call("add_error", "A6 zone sources not ready for zone%03d" % znum)
	return result


func export_zone_scene_a6_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_zone_scene_a6(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {"ok": false, "zone": znum, "scope": ZONE_EXPORT_SERVICE_SCOPE, "checkpoint": ZONE_EXPORT_SERVICE_CHECKPOINT, "errors": ["A6 export result missing"]}


func export_zones_batch_a7(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var requested_zones: Array[int] = _normalize_zone_ids_a7(zone_ids, 0)
	var max_batch_zones: int = int(options.get("max_batch_zones", 0))
	var zones_to_export: Array[int] = _normalize_zone_ids_a7(zone_ids, max_batch_zones)
	var manifest_path := str(options.get("manifest_path", DEFAULT_ZONE_MANIFEST_PATH))
	var write_manifest := bool(options.get("write_manifest", true))
	var require_manifest_write := bool(options.get("require_manifest_write", write_manifest))
	var dry_run := bool(options.get("dry_run", false))

	var result_items: Array = []
	var exported_zones: Array[int] = []
	var exported_paths: Array[String] = []
	var failed_zones: Array[int] = []
	var ok_count := 0
	var fail_count := 0
	var fallback_detected := false
	var batch_errors: Array[String] = []

	if zones_to_export.is_empty():
		batch_errors.append("A7 requires an explicit non-empty zone list")

	for znum in zones_to_export:
		var zone_started_msec := Time.get_ticks_msec()
		var classification: Dictionary = classify_zone_kind_a10a(host, int(znum))
		var snap: Dictionary = {}
		if dry_run:
			snap = {
				"ok": true,
				"zone": int(znum),
				"scope": ZONE_EXPORT_SERVICE_SCOPE,
				"checkpoint": ZONE_EXPORT_SERVICE_CHECKPOINT,
				"exported_scene_path": _default_scene_path(int(znum)),
				"generated_scene_path": _default_scene_path(int(znum)),
				"export_ok": false,
				"reload_ok": false,
				"dry_run": true,
				"metrics": {},
				"errors": [],
				"warnings": [],
				"zone_kind": str(classification.get("zone_kind", "unknown")),
				"generated_scene_status": str(classification.get("generated_scene_status", "unknown_unclassified")),
				"supported_for_generated_scene": bool(classification.get("supported_for_generated_scene", false)),
				"zone_kind_reason": str(classification.get("reason", "")),
				"zone_kind_evidence": classification.get("evidence", {}),
			}
		else:
			var zone_options: Dictionary = options.duplicate(true)
			zone_options.erase("zones")
			zone_options.erase("zone_ids")
			zone_options.erase("max_batch_zones")
			zone_options.erase("manifest_path")
			zone_options.erase("write_manifest")
			zone_options.erase("require_manifest_write")
			zone_options.erase("dry_run")
			zone_options["batch_parent_scope"] = CONTROLLED_BATCH_MANIFEST_SCOPE
			zone_options["recommended_next_step"] = "P1-16A8 runtime load generated scenes"
			var zone_result := export_zone_scene_a6(host, int(znum), zone_options)
			if zone_result != null and zone_result.has_method("to_debug_dict"):
				snap = zone_result.call("to_debug_dict", false) as Dictionary
			else:
				snap = {"ok": false, "zone": int(znum), "errors": ["A7 zone export result missing"], "metrics": {}}
			_ensure_snap_zone_kind_a10a(snap, classification)
			var detached_root: Node = null
			if zone_result != null:
				detached_root = zone_result.get("root") as Node
				if detached_root != null and not detached_root.is_inside_tree():
					detached_root.free()
					zone_result.set("root", null)

		_ensure_snap_zone_kind_a10a(snap, classification)
		var expected_path := _default_scene_path(int(znum))
		var actual_path := str(snap.get("exported_scene_path", snap.get("generated_scene_path", "")))
		var fallback_error := ""
		if actual_path != expected_path:
			fallback_detected = true
			fallback_error = "A7 path mismatch/fallback detected for zone%03d actual=%s expected=%s" % [int(znum), actual_path, expected_path]
		var entry := _make_manifest_entry_a7(int(znum), snap, Time.get_ticks_msec() - zone_started_msec, fallback_error)
		result_items.append(entry)
		if bool(entry.get("ok", false)):
			ok_count += 1
			exported_zones.append(int(znum))
			exported_paths.append(str(entry.get("scene_path", "")))
		else:
			fail_count += 1
			failed_zones.append(int(znum))

	var elapsed_ms := Time.get_ticks_msec() - started_msec
	var batch_ok := zones_to_export.size() > 0 and fail_count == 0 and not fallback_detected and batch_errors.is_empty()
	var manifest := {
		"schema": "daoc.generated_zones_manifest.v1",
		"scope": CONTROLLED_BATCH_MANIFEST_SCOPE,
		"checkpoint": CONTROLLED_BATCH_MANIFEST_CHECKPOINT,
		"ok": batch_ok,
		"batch_mode": "a7_explicit_zone_list_manifest",
		"one_scene_per_zone": true,
		"explicit_zone_list": true,
		"no_silent_zone000_fallback": not fallback_detected,
		"dry_run": dry_run,
		"manifest_path": manifest_path,
		"manifest_written": false,
		"requested_zones": requested_zones.duplicate(),
		"zones_to_export": zones_to_export.duplicate(),
		"zone_count": zones_to_export.size(),
		"ok_count": ok_count,
		"fail_count": fail_count,
		"supported_count": _count_manifest_entries_bool_a10a(result_items, "supported_for_generated_scene", true),
		"unsupported_count": _count_manifest_entries_bool_a10a(result_items, "supported_for_generated_scene", false),
		"supported_zones": _manifest_zone_ids_by_support_a10a(result_items, true),
		"unsupported_zones": _manifest_zone_ids_by_support_a10a(result_items, false),
		"kind_counts": _manifest_kind_counts_a10a(result_items),
		"generated_scene_primary_allowed_only_for": ["terrain_heightmap"],
		"exported_zones": exported_zones.duplicate(),
		"failed_zones": failed_zones.duplicate(),
		"exported_paths": exported_paths.duplicate(),
		"result_count": result_items.size(),
		"zones": result_items,
		"errors": batch_errors.duplicate(),
		"elapsed_ms": elapsed_ms,
		"recommended_next_step": "P1-16A10B generated primary only for terrain_heightmap; unsupported zone kinds remain fallback",
	}

	if write_manifest and not dry_run:
		var write_result := _write_manifest_a7(manifest_path, manifest)
		manifest["manifest_write"] = write_result
		manifest["manifest_written"] = bool(write_result.get("ok", false))
		if require_manifest_write and not bool(write_result.get("ok", false)):
			manifest["ok"] = false
			var errors: Array = manifest.get("errors", []) as Array
			errors.append(str(write_result.get("error", "manifest write failed")))
			manifest["errors"] = errors
		elif bool(write_result.get("ok", false)):
			_write_manifest_a7(manifest_path, manifest)
	else:
		manifest["manifest_write"] = {"ok": false, "skipped": true, "reason": "dry_run" if dry_run else "write_manifest=false"}

	return manifest


func export_zones_batch_a7_debug_snapshot(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	return export_zones_batch_a7(host, zone_ids, options)


func classify_zone_kind_a10a(host: Node, znum: int) -> Dictionary:
	var resolver: RefCounted = DaocZoneKindResolverScript.new()
	if resolver == null or not resolver.has_method("classify_zone"):
		return {
			"scope": ZONE_KIND_CLASSIFICATION_SCOPE,
			"checkpoint": ZONE_KIND_CLASSIFICATION_CHECKPOINT,
			"zone_id": znum,
			"zone_name": "zone%03d" % znum,
			"zone_kind": "unknown",
			"generated_scene_status": "unknown_unclassified",
			"supported_for_generated_scene": false,
			"ready_full_export": false,
			"reason": "DaocZoneKindResolver unavailable",
			"evidence": {},
		}
	return resolver.call("classify_zone", host, znum) as Dictionary


func classify_zones_manifest_a10a(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	var resolver: RefCounted = DaocZoneKindResolverScript.new()
	if resolver == null or not resolver.has_method("classify_zones"):
		return {"ok": false, "scope": ZONE_KIND_CLASSIFICATION_SCOPE, "checkpoint": ZONE_KIND_CLASSIFICATION_CHECKPOINT, "error": "DaocZoneKindResolver unavailable"}
	var manifest: Dictionary = resolver.call("classify_zones", host, zone_ids) as Dictionary
	manifest["write_manifest"] = false
	manifest["manifest_path"] = str(options.get("manifest_path", ""))
	if bool(options.get("write_manifest", false)):
		var manifest_path: String = str(options.get("manifest_path", "res://reports/generated/zones/zone_kind_manifest.json"))
		var write_result: Dictionary = _write_manifest_a7(manifest_path, manifest)
		manifest["manifest_path"] = manifest_path
		manifest["manifest_write"] = write_result
		manifest["write_manifest"] = bool(write_result.get("ok", false))
		if not bool(write_result.get("ok", false)):
			manifest["ok"] = false
			manifest["error"] = str(write_result.get("error", "manifest write failed"))
	return manifest



func export_dungeon_scene_c2(host: Node, znum: int, options: Dictionary = {}) -> RefCounted:
	var result: RefCounted = DaocZoneCreationResultScript.new()
	result.set("scope", DUNGEON_SCENE_EXPORT_SCOPE)
	result.set("checkpoint", DUNGEON_SCENE_EXPORT_CHECKPOINT)
	result.set("zone", znum)
	result.set("creation_mode", "c2_generated_dungeon_scene_export")
	result.set("export_mode", "generated_dungeon_scene")
	result.set("include_runtime_nodes", true)
	result.set("recommended_next_step", "P1-17C3 clean default dungeon rendering and regression report Barrows+Mithra")

	var client_root: String = str(options.get("client_root", "")).strip_edges()
	if client_root == "":
		client_root = DaocDungeonFileResolverScript.default_client_root()
	var zone_name: String = str(options.get("zone_name", DaocDungeonFileResolverScript.default_zone_name(znum)))
	var classification: Dictionary = classify_zone_kind_a10a(host, znum)
	var zone_kind: String = str(classification.get("zone_kind", "unknown"))
	if zone_kind != "dungeon_chunk" and client_root != "":
		var direct_files_info: Dictionary = DaocDungeonFileResolverScript.resolve_dungeon_files(client_root, znum, zone_name)
		var direct_files: Dictionary = direct_files_info.get("files", {}) as Dictionary
		if str(direct_files.get("dungeon.chunk", "")) != "" and str(direct_files.get("dungeon.place", "")) != "":
			zone_kind = "dungeon_chunk"
			classification["zone_kind"] = zone_kind
			classification["reason"] = "dungeon files resolved from explicit/project client_root"
	result.set("zone_kind", zone_kind)
	result.set("generated_scene_status", "supported_generated_dungeon_scene" if zone_kind == "dungeon_chunk" else str(classification.get("generated_scene_status", "unsupported_yet")))
	result.set("supported_for_generated_scene", zone_kind == "dungeon_chunk")
	result.set("zone_kind_reason", str(classification.get("reason", "")))
	result.set("zone_kind_evidence", classification.get("evidence", {}))

	var scene_path: String = str(options.get("scene_path", _default_dungeon_scene_path(znum)))
	result.set("generated_scene_path", scene_path)
	result.set("exported_scene_path", scene_path)

	if zone_kind != "dungeon_chunk":
		result.set("metrics", {
			"zone_kind": zone_kind,
			"generated_scene_type": "GeneratedDungeonScene",
			"supported_for_generated_dungeon_scene": false,
			"reason": "zone is not dungeon_chunk",
		})
		result.call("add_error", "GeneratedDungeonScene export requires dungeon_chunk zone%03d, got kind=%s" % [znum, zone_kind])
		_last_result = result
		return result

	var builder: RefCounted = DaocDungeonSceneBuilderScript.new()
	if builder == null or not builder.has_method("build"):
		result.call("add_error", "DaocDungeonSceneBuilder unavailable")
		_last_result = result
		return result

	var build_metadata: Dictionary = {
		"scope": DUNGEON_SCENE_EXPORT_SCOPE,
		"checkpoint": DUNGEON_SCENE_EXPORT_CHECKPOINT,
		"generated_scene_type": "GeneratedDungeonScene",
		"root_name": "GeneratedDungeon_%03d" % znum,
		"source_region_hint": str(options.get("source_region_hint", "ZoneCreator dungeon_chunk export zone%03d" % znum)),
		"previous_wrong_target_note": str(options.get("previous_wrong_target_note", "P1-17C2 generated dungeon export; Barrows and Mithra remain regression targets")),
	}
	var build_result: Dictionary = builder.call(
		"build",
		client_root,
		znum,
		zone_name,
		float(options.get("world_scale", 0.10)),
		float(options.get("placeholder_extent", 90.0)),
		bool(options.get("try_runtime_nif_preview", true)),
		float(options.get("nif_preview_scale", 0.10)),
		bool(options.get("link_runtime_textures", true)),
		float(options.get("texture_alpha_scissor", 0.5)),
		bool(options.get("build_runtime_collisions", true)),
		str(options.get("collision_shape_mode", "trimesh")),
		bool(options.get("show_debug_footprints", false)),
		bool(options.get("show_debug_axes", false)),
		bool(options.get("show_debug_labels", false)),
		bool(options.get("show_portal_debug", false)),
		bool(options.get("show_light_debug", false)),
		build_metadata
	) as Dictionary

	var root: Node3D = build_result.get("root", null) as Node3D
	var status: Dictionary = build_result.get("status", {}) as Dictionary
	var metrics: Dictionary = status.duplicate(true)
	metrics["zone_kind"] = zone_kind
	metrics["generated_scene_type"] = "GeneratedDungeonScene"
	metrics["supported_for_generated_dungeon_scene"] = true
	metrics["scene_path"] = scene_path
	metrics["client_root"] = DaocDungeonFileResolverScript.normalize_path(client_root)
	result.set("metrics", metrics)
	result.set("root", root)
	var portal_status: Dictionary = status.get("portal_result", {}) as Dictionary
	result.set("signatures", {
		"dungeon_chunk_instances": str(status.get("nif_preview_nodes", 0)),
		"portal_links": str(portal_status.get("link_count", 0)),
		"collision_bodies": str(status.get("collision_bodies", 0)),
	})
	if root != null:
		for child in root.get_children():
			if child is Node3D:
				result.call("set_branch", str((child as Node3D).name), child)

	if not bool(build_result.get("ok", false)) or not bool(status.get("ok", false)):
		result.call("add_error", "dungeon builder failed: %s" % str(status.get("error", "unknown builder error")))
		_last_result = result
		return result
	if root == null:
		result.call("add_error", "dungeon builder returned null root")
		_last_result = result
		return result

	root.set_meta("daoc_scope", DUNGEON_SCENE_EXPORT_SCOPE)
	root.set_meta("daoc_checkpoint", DUNGEON_SCENE_EXPORT_CHECKPOINT)
	root.set_meta("daoc_zone", znum)
	root.set_meta("daoc_zone_kind", zone_kind)
	root.set_meta("daoc_generated_scene_type", "GeneratedDungeonScene")
	root.set_meta("daoc_exported_scene_path", scene_path)
	root.set_meta("daoc_clean_default_debug_portals", not bool(options.get("show_portal_debug", false)))
	_set_scene_owner_recursive(root, root)

	if not _ensure_scene_parent_dir(scene_path):
		result.call("add_error", "cannot create dungeon scene parent directory: %s" % scene_path)
		_last_result = result
		return result

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	result.set("pack_error_code", int(pack_err))
	if pack_err != OK:
		result.call("add_error", "PackedScene.pack dungeon failed: %d" % int(pack_err))
		_last_result = result
		return result

	var save_err := ResourceSaver.save(packed, scene_path)
	result.set("export_error_code", int(save_err))
	if save_err != OK:
		result.call("add_error", "ResourceSaver.save dungeon failed: %d path=%s" % [int(save_err), scene_path])
		_last_result = result
		return result

	var file_exists := FileAccess.file_exists(scene_path)
	result.set("file_exists_after_save", file_exists)
	if not file_exists:
		result.call("add_error", "saved dungeon scene not found after export: %s" % scene_path)
		_last_result = result
		return result

	_validate_reloaded_dungeon_scene_c2(result, scene_path)
	if bool(result.get("reload_ok")) and (result.get("errors") as Array).is_empty():
		result.set("export_ok", true)
		result.set("ok", true)
	_last_result = result
	return result


func export_dungeon_scene_c2_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_dungeon_scene_c2(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func export_dungeon_scenes_batch_c2(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	var zones_to_export: Array = _normalize_zone_ids_c2(zone_ids, int(options.get("max_batch_zones", 0)))
	var dry_run: bool = bool(options.get("dry_run", false))
	var write_manifest: bool = bool(options.get("write_manifest", not dry_run))
	var manifest_path: String = str(options.get("manifest_path", DEFAULT_DUNGEON_MANIFEST_PATH))
	var result_items: Array = []
	var exported_zones: Array = []
	var failed_zones: Array = []
	var ok_count: int = 0
	var fail_count: int = 0
	var started_msec := Time.get_ticks_msec()

	for znum_value in zones_to_export:
		var znum: int = int(znum_value)
		var item: Dictionary = {}
		var classification: Dictionary = classify_zone_kind_a10a(host, znum)
		if dry_run:
			item = {
				"zone": znum,
				"zone_id": znum,
				"ok": str(classification.get("zone_kind", "")) == "dungeon_chunk",
				"dry_run": true,
				"export_ok": false,
				"reload_ok": false,
				"exported_scene_path": _default_dungeon_scene_path(znum),
				"zone_kind": str(classification.get("zone_kind", "unknown")),
				"generated_scene_type": "GeneratedDungeonScene",
				"supported_for_generated_dungeon_scene": str(classification.get("zone_kind", "")) == "dungeon_chunk",
				"zone_kind_reason": str(classification.get("reason", "")),
			}
		else:
			var zone_options: Dictionary = options.duplicate(true)
			zone_options.erase("dry_run")
			zone_options.erase("write_manifest")
			zone_options.erase("manifest_path")
			zone_options.erase("max_batch_zones")
			var zone_result := export_dungeon_scene_c2(host, znum, zone_options)
			if zone_result != null and zone_result.has_method("to_debug_dict"):
				item = zone_result.call("to_debug_dict", false) as Dictionary
			else:
				item = {"zone": znum, "ok": false, "errors": ["dungeon export result missing"]}
			var detached_root: Node = null
			if zone_result != null:
				detached_root = zone_result.get("root") as Node
				if detached_root != null and not detached_root.is_inside_tree():
					detached_root.free()
					zone_result.set("root", null)
		var zone_ok: bool = bool(item.get("ok", false)) and (dry_run or (bool(item.get("export_ok", false)) and bool(item.get("reload_ok", false))))
		if zone_ok:
			ok_count += 1
			exported_zones.append(znum)
		else:
			fail_count += 1
			failed_zones.append(znum)
		result_items.append(item)

	var manifest := {
		"schema": "daoc.generated_dungeons_manifest.v1",
		"scope": DUNGEON_BATCH_SCOPE,
		"checkpoint": DUNGEON_BATCH_CHECKPOINT,
		"ok": zones_to_export.size() > 0 and fail_count == 0,
		"dry_run": dry_run,
		"zone_count": zones_to_export.size(),
		"zones_to_export": zones_to_export.duplicate(),
		"ok_count": ok_count,
		"fail_count": fail_count,
		"exported_zones": exported_zones.duplicate(),
		"failed_zones": failed_zones.duplicate(),
		"results": result_items,
		"manifest_path": manifest_path,
		"manifest_written": false,
		"elapsed_ms": Time.get_ticks_msec() - started_msec,
		"recommended_next_step": "P1-17C3 clean default dungeon rendering and regression report Barrows+Mithra",
	}
	if write_manifest and not dry_run:
		var write_result := _write_manifest_a7(manifest_path, manifest)
		manifest["manifest_write"] = write_result
		manifest["manifest_written"] = bool(write_result.get("ok", false))
		if not bool(write_result.get("ok", false)):
			manifest["ok"] = false
			manifest["error"] = str(write_result.get("error", "manifest write failed"))
	return manifest


func export_dungeon_scenes_batch_c2_debug_snapshot(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	return export_dungeon_scenes_batch_c2(host, zone_ids, options)


func validate_generated_dungeon_scenes_c3(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	var zones_to_validate: Array = _normalize_zone_ids_c2(zone_ids, int(options.get("max_batch_zones", 0)))
	if zones_to_validate.is_empty():
		zones_to_validate = [19, 21]
	var write_reports: bool = bool(options.get("write_reports", true))
	var auto_export_missing: bool = bool(options.get("auto_export_missing", true))
	var auto_export_failed: bool = bool(options.get("auto_export_failed", false))
	var json_path: String = str(options.get("report_json_path", DEFAULT_DUNGEON_REPORT_JSON_PATH))
	var txt_path: String = str(options.get("report_txt_path", DEFAULT_DUNGEON_REPORT_TXT_PATH))
	var result_items: Array = []
	var auto_export_items: Array = []
	var ok_count: int = 0
	var fail_count: int = 0
	var started_msec := Time.get_ticks_msec()
	for znum_value in zones_to_validate:
		var znum: int = int(znum_value)
		var scene_path: String = str(options.get("scene_path_%03d" % znum, _default_dungeon_scene_path(znum)))
		var auto_export_attempted := false
		var auto_export_debug: Dictionary = {}
		if auto_export_missing and not FileAccess.file_exists(scene_path):
			auto_export_attempted = true
			auto_export_debug = _auto_export_generated_dungeon_for_report_c3(host, znum, scene_path, options)
			auto_export_items.append(auto_export_debug)
		var item: Dictionary = _validate_one_generated_dungeon_scene_c3(znum, scene_path, _expected_generated_dungeon_metrics_c3(znum))
		if (not bool(item.get("ok", false))) and auto_export_failed and not auto_export_attempted:
			auto_export_attempted = true
			auto_export_debug = _auto_export_generated_dungeon_for_report_c3(host, znum, scene_path, options)
			auto_export_items.append(auto_export_debug)
			item = _validate_one_generated_dungeon_scene_c3(znum, scene_path, _expected_generated_dungeon_metrics_c3(znum))
		item["auto_export_missing_enabled"] = auto_export_missing
		item["auto_export_failed_enabled"] = auto_export_failed
		item["auto_export_attempted"] = auto_export_attempted
		if auto_export_attempted:
			item["auto_export"] = auto_export_debug
			item["auto_export_ok"] = bool(auto_export_debug.get("ok", false)) and bool(auto_export_debug.get("export_ok", false)) and bool(auto_export_debug.get("reload_ok", false))
		if bool(item.get("ok", false)):
			ok_count += 1
		else:
			fail_count += 1
		result_items.append(item)
	var report := {
		"schema": "daoc.generated_dungeon_regression_report.v1",
		"scope": GENERATED_DUNGEON_REPORT_SCOPE,
		"checkpoint": GENERATED_DUNGEON_REPORT_CHECKPOINT,
		"ok": zones_to_validate.size() > 0 and fail_count == 0,
		"zone_count": zones_to_validate.size(),
		"zones": zones_to_validate.duplicate(),
		"ok_count": ok_count,
		"fail_count": fail_count,
		"results": result_items,
		"auto_export_missing": auto_export_missing,
		"auto_export_failed": auto_export_failed,
		"auto_export_count": auto_export_items.size(),
		"auto_exports": auto_export_items,
		"report_json_path": json_path,
		"report_txt_path": txt_path,
		"reports_written": false,
		"elapsed_ms": Time.get_ticks_msec() - started_msec,
		"recommended_next_step": "P1-17D GeneratedDungeonScene runtime attach / player spawn on generated dungeon collision",
	}
	if write_reports:
		var json_write: Dictionary = _write_manifest_a7(json_path, report)
		var txt_write: Dictionary = _write_text_report_c3(txt_path, _format_generated_dungeon_report_txt_c3(report))
		report["json_write"] = json_write
		report["txt_write"] = txt_write
		report["reports_written"] = bool(json_write.get("ok", false)) and bool(txt_write.get("ok", false))
		if bool(report.get("reports_written", false)):
			# Rewrite once so the files visible to the user contain reports_written=true.
			_write_manifest_a7(json_path, report)
			_write_text_report_c3(txt_path, _format_generated_dungeon_report_txt_c3(report))
		else:
			report["ok"] = false
			report["error"] = "generated dungeon report write failed"
	return report


func _auto_export_generated_dungeon_for_report_c3(host: Node, znum: int, scene_path: String, options: Dictionary) -> Dictionary:
	var export_options: Dictionary = options.duplicate(true)
	export_options.erase("write_reports")
	export_options.erase("report_json_path")
	export_options.erase("report_txt_path")
	export_options.erase("max_batch_zones")
	export_options.erase("auto_export_missing")
	export_options.erase("auto_export_failed")
	export_options["scene_path"] = scene_path
	var result := export_dungeon_scene_c2(host, znum, export_options)
	var debug: Dictionary = {
		"zone": znum,
		"scene_path": scene_path,
		"ok": false,
		"export_ok": false,
		"reload_ok": false,
		"file_exists_after_export": FileAccess.file_exists(scene_path),
		"errors": ["export result missing"],
	}
	if result != null and result.has_method("to_debug_dict"):
		debug = result.call("to_debug_dict", false) as Dictionary
		debug["scene_path"] = scene_path
		debug["file_exists_after_export"] = FileAccess.file_exists(scene_path)
		var detached_root: Node = result.get("root") as Node
		if detached_root != null and not detached_root.is_inside_tree():
			detached_root.free()
			result.set("root", null)
	return debug


func validate_generated_dungeon_scenes_c3_debug_snapshot(host: Node, zone_ids: Array, options: Dictionary = {}) -> Dictionary:
	return validate_generated_dungeon_scenes_c3(host, zone_ids, options)


func export_generated_scene_debug_snapshot(host: Node, znum: int, options: Dictionary = {}) -> Dictionary:
	var result := export_generated_scene(host, znum, options)
	if result != null and result.has_method("to_debug_dict"):
		return result.call("to_debug_dict", false) as Dictionary
	return {}


func get_last_result() -> RefCounted:
	return _last_result


func status() -> Dictionary:
	var last := {}
	if _last_result != null and _last_result.has_method("to_debug_dict"):
		last = _last_result.call("to_debug_dict", false) as Dictionary
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"export_scope": EXPORT_SCOPE,
		"export_checkpoint": EXPORT_CHECKPOINT,
		"terrain_water_scope": TERRAIN_WATER_SCOPE,
		"terrain_water_checkpoint": TERRAIN_WATER_CHECKPOINT,
		"props_strategy_scope": PROPS_STRATEGY_SCOPE,
		"props_strategy_checkpoint": PROPS_STRATEGY_CHECKPOINT,
		"full_zone_props_scope": FULL_ZONE_PROPS_SCOPE,
		"full_zone_props_checkpoint": FULL_ZONE_PROPS_CHECKPOINT,
		"gameplay_debug_scope": GAMEPLAY_DEBUG_SCOPE,
		"gameplay_debug_checkpoint": GAMEPLAY_DEBUG_CHECKPOINT,
		"multi_zone_batch_scope": MULTI_ZONE_BATCH_SCOPE,
		"multi_zone_batch_checkpoint": MULTI_ZONE_BATCH_CHECKPOINT,
		"zone_export_service_scope": ZONE_EXPORT_SERVICE_SCOPE,
		"zone_export_service_checkpoint": ZONE_EXPORT_SERVICE_CHECKPOINT,
		"controlled_batch_manifest_scope": CONTROLLED_BATCH_MANIFEST_SCOPE,
		"controlled_batch_manifest_checkpoint": CONTROLLED_BATCH_MANIFEST_CHECKPOINT,
		"zone_kind_classification_scope": ZONE_KIND_CLASSIFICATION_SCOPE,
		"zone_kind_classification_checkpoint": ZONE_KIND_CLASSIFICATION_CHECKPOINT,
		"dungeon_scene_export_scope": DUNGEON_SCENE_EXPORT_SCOPE,
		"dungeon_scene_export_checkpoint": DUNGEON_SCENE_EXPORT_CHECKPOINT,
		"dungeon_batch_scope": DUNGEON_BATCH_SCOPE,
		"dungeon_batch_checkpoint": DUNGEON_BATCH_CHECKPOINT,
		"generated_dungeon_report_scope": GENERATED_DUNGEON_REPORT_SCOPE,
		"generated_dungeon_report_checkpoint": GENERATED_DUNGEON_REPORT_CHECKPOINT,
		"default_zone_manifest_path": DEFAULT_ZONE_MANIFEST_PATH,
		"default_dungeon_manifest_path": DEFAULT_DUNGEON_MANIFEST_PATH,
		"default_dungeon_report_json_path": DEFAULT_DUNGEON_REPORT_JSON_PATH,
		"default_dungeon_report_txt_path": DEFAULT_DUNGEON_REPORT_TXT_PATH,
		"generated_dungeon_report_auto_export_missing_default": true,
		"default_prop_preview_limit": DEFAULT_PROP_PREVIEW_LIMIT,
		"has_last_result": _last_result != null,
		"default_branches": DEFAULT_BRANCHES.duplicate(),
		"expected_signatures": EXPECTED_SIGNATURES.duplicate(),
		"last": last,
		"recommended_next_step": "P1-16A2 exporter GeneratedZone_000.tscn",
		"recommended_next_step_after_export": "P1-16A3a populate GeneratedZone_000 with terrain + water visual roots",
		"recommended_next_step_after_terrain_water": "P1-16A3b populate GeneratedZone_000 with props strategy",
		"recommended_next_step_after_props_strategy": "P1-16A3c one complete scene per zone with full props",
		"recommended_next_step_after_full_zone_props": "P1-16A4 add collisions/zonejump editor data to generated zone scene",
		"recommended_next_step_after_collision_zonejump_editor_data": "P1-16A5 multi-zone scene generation batch",
		"recommended_next_step_after_multi_zone_batch": "P1-16A6 ZoneSceneExportService / dynamic per-zone validation",
		"recommended_next_step_after_zone_export_service": "P1-16A7 controlled multi-zone batch + manifest",
		"recommended_next_step_after_controlled_batch_manifest": "P1-16A8 runtime load generated scenes",
		"recommended_next_step_after_runtime_bridge": "P1-16A10A classify zone kinds before generated primary",
		"recommended_next_step_after_zone_kind_classification": "P1-17C integrate dungeon_chunk into ZoneCreator / GeneratedDungeonScene",
		"recommended_next_step_after_dungeon_scene_export": "P1-17C3 clean default dungeon rendering and regression report Barrows+Mithra",
		"recommended_next_step_after_generated_dungeon_report": "P1-17D GeneratedDungeonScene runtime attach / player spawn on generated dungeon collision",
	}


func _create_zone_root(znum: int) -> Node3D:
	var root := Node3D.new()
	root.name = "GeneratedZone_%03d" % znum
	root.set_meta("daoc_zone", znum)
	root.set_meta("daoc_scope", SCOPE)
	root.set_meta("daoc_checkpoint", CHECKPOINT)
	root.set_meta("daoc_generated_scene_path", _default_scene_path(znum))
	return root


func _ensure_branch(root: Node3D, branch_name: String) -> Node3D:
	var existing := root.get_node_or_null(branch_name)
	if existing != null and existing is Node3D:
		return existing as Node3D
	var branch := Node3D.new()
	branch.name = branch_name
	branch.set_meta("daoc_zone_branch", branch_name)
	branch.set_meta("daoc_scope", SCOPE)
	root.add_child(branch)
	branch.owner = root
	return branch


func _collect_source_snapshots(host: Node) -> Dictionary:
	return {
		"zonejump_14a": _call_snapshot(host, "get_zonejump_14a_debug_snapshot"),
		"water_14b": _call_snapshot(host, "get_water_14b_debug_snapshot"),
		"collision_14c": _call_snapshot(host, "get_collision_14c_debug_snapshot"),
		"prop_14d": _call_snapshot(host, "get_prop_14d_debug_snapshot"),
		"terrain_14e": _call_snapshot(host, "get_terrain_14e_debug_snapshot"),
		"zone_scene_15b": _call_snapshot(host, "get_zone_scene_15b_debug_snapshot"),
		"freeze_15h": _call_snapshot(host, "get_zoneviewer_freeze_15h_snapshot"),
	}


func _call_snapshot(host: Node, method_name: String) -> Dictionary:
	if host == null or not host.has_method(method_name):
		return {}
	var value: Variant = host.call(method_name)
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _extract_signatures(snapshots: Dictionary) -> Dictionary:
	var zonejump: Dictionary = snapshots.get("zonejump_14a", {}) as Dictionary
	var water: Dictionary = snapshots.get("water_14b", {}) as Dictionary
	var collision: Dictionary = snapshots.get("collision_14c", {}) as Dictionary
	var prop: Dictionary = snapshots.get("prop_14d", {}) as Dictionary
	var terrain: Dictionary = snapshots.get("terrain_14e", {}) as Dictionary
	return {
		"zonejump": str(zonejump.get("zone0_index_signature", "")),
		"water": str(water.get("zone0_index_signature", "")),
		"boundary": str(collision.get("zone0_boundary_signature", "")),
		"prop": str(prop.get("zone0_index_signature", "")),
		"terrain": str(terrain.get("zone0_index_signature", "")),
	}


func _build_metrics(root: Node3D, result: RefCounted) -> Dictionary:
	var snapshots: Dictionary = result.get("source_snapshots") as Dictionary
	var terrain: Dictionary = snapshots.get("terrain_14e", {}) as Dictionary
	var prop: Dictionary = snapshots.get("prop_14d", {}) as Dictionary
	var water: Dictionary = snapshots.get("water_14b", {}) as Dictionary
	var collision: Dictionary = snapshots.get("collision_14c", {}) as Dictionary
	var zonejump: Dictionary = snapshots.get("zonejump_14a", {}) as Dictionary
	return {
		"root_present": root != null,
		"root_name": root.name if root != null else "",
		"branch_count": int(result.call("branch_count")),
		"terrain_meshes_source": int(terrain.get("zone0_meshes", 0)),
		"terrain_collision_bodies_source": int(terrain.get("zone0_collision_bodies", 0)),
		"prop_nodes_source": int(prop.get("zone0_nodes", 0)),
		"water_meshes_source": int(water.get("zone0_meshes", 0)),
		"boundary_segments_source": int(collision.get("zone0_boundary_count", 0)),
		"prop_collision_bodies_source": int(collision.get("zone0_prop_count", 0)),
		"zonejump_entries_source": int(zonejump.get("zone0_index_size", 0)),
		"detached_by_default": true,
		"zoneviewer_refactor_closed": _freeze_says_closed(snapshots.get("freeze_15h", {}) as Dictionary),
	}


func _extract_zone_signatures(host: Node, znum: int, snapshots: Dictionary) -> Dictionary:
	var terrain_result := _get_zone_build_result(host, "_terrain_build_results", znum)
	var water_result := _get_zone_build_result(host, "_water_build_results", znum)
	var prop_result := _get_zone_build_result(host, "_prop_build_results", znum)
	var boundary_result := _get_zone_build_result(host, "_boundary_build_results", znum)
	return {
		"zonejump": _zone_result_signature(host, "_zonejump_build_results", "index_signature", znum),
		"water": str(water_result.get("index_signature")) if water_result != null else "",
		"boundary": str(boundary_result.get("boundary_index_signature")) if boundary_result != null else "",
		"prop": str(prop_result.get("index_signature")) if prop_result != null else "",
		"terrain": str(terrain_result.get("index_signature")) if terrain_result != null else "",
		"prop_collision": _zone_dict_signature(host, "_collision_prop_signature_by_zone", znum),
		"zone_aware": true,
		"zone": znum,
	}


func _build_zone_aware_metrics(host: Node, znum: int, root: Node3D, result: RefCounted) -> Dictionary:
	var terrain_result := _get_zone_build_result(host, "_terrain_build_results", znum)
	var water_result := _get_zone_build_result(host, "_water_build_results", znum)
	var prop_result := _get_zone_build_result(host, "_prop_build_results", znum)
	var boundary_result := _get_zone_build_result(host, "_boundary_build_results", znum)
	var zonejump_result := _get_zone_build_result(host, "_zonejump_build_results", znum)
	var terrain_meshes: Array = []
	var terrain_collision_bodies: Array = []
	var water_meshes: Array = []
	var prop_nodes: Array = []
	var boundary_segments: Array = []
	var zonejump_index: Array = []
	if terrain_result != null:
		terrain_meshes = terrain_result.get("terrain_meshes") as Array
		terrain_collision_bodies = terrain_result.get("collision_bodies") as Array
	if water_result != null:
		water_meshes = water_result.get("meshes") as Array
	if prop_result != null:
		prop_nodes = prop_result.get("prop_nodes") as Array
	if boundary_result != null:
		boundary_segments = boundary_result.get("boundary_segments") as Array
	if zonejump_result != null:
		zonejump_index = zonejump_result.get("static_index") as Array
	var prop_collision: Array = _get_zone_array(host, "_prop_collision_runtime", znum)
	var availability: Dictionary = _zone_source_availability(host, znum)
	return {
		"root_present": root != null,
		"root_name": root.name if root != null else "",
		"branch_count": int(result.call("branch_count")),
		"zone_aware_metrics": true,
		"dynamic_zone_validation": true,
		"target_zone": znum,
		"terrain_meshes_source": terrain_meshes.size(),
		"terrain_collision_bodies_source": terrain_collision_bodies.size(),
		"prop_nodes_source": prop_nodes.size(),
		"water_meshes_source": water_meshes.size(),
		"boundary_segments_source": boundary_segments.size(),
		"prop_collision_bodies_source": prop_collision.size(),
		"zonejump_entries_source": zonejump_index.size(),
		"detached_by_default": true,
		"zoneviewer_refactor_closed": _freeze_says_closed((result.get("source_snapshots") as Dictionary).get("freeze_15h", {}) as Dictionary),
		"zone_source_availability": availability,
		"zone_source_ready": bool(availability.get("ready_full_export", false)),
	}


func _validate_zone_aware_sources(result: RefCounted) -> void:
	var metrics: Dictionary = result.get("metrics") as Dictionary
	var znum := int(result.get("zone"))
	if int(metrics.get("terrain_meshes_source", 0)) <= 0:
		result.call("add_error", "A6 zone%03d terrain source missing" % znum)
	if int(metrics.get("prop_nodes_source", 0)) <= 0:
		result.call("add_error", "A6 zone%03d prop source missing" % znum)
	if int(metrics.get("boundary_segments_source", 0)) <= 0:
		result.call("add_error", "A6 zone%03d boundary source missing" % znum)
	if int(metrics.get("zonejump_entries_source", 0)) <= 0:
		result.call("add_error", "A6 zone%03d zonejump source missing" % znum)
	if int(metrics.get("water_meshes_source", 0)) < 0:
		result.call("add_error", "A6 zone%03d water source invalid" % znum)


func _normalize_zone_ids_a7(zone_ids: Array, max_count: int = 0) -> Array[int]:
	var out: Array[int] = []
	for raw_zone in zone_ids:
		var znum := int(raw_zone)
		if znum < 0:
			continue
		if out.has(znum):
			continue
		out.append(znum)
		if max_count > 0 and out.size() >= max_count:
			break
	return out


func _make_manifest_entry_a7(znum: int, snap: Dictionary, elapsed_ms: int, forced_error: String = "") -> Dictionary:
	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	var raw_errors: Array = snap.get("errors", []) as Array
	var errors: Array = []
	for raw_error in raw_errors:
		errors.append(str(raw_error))
	if forced_error != "":
		errors.append(forced_error)
	var raw_warnings: Array = snap.get("warnings", []) as Array
	var warnings: Array = []
	for raw_warning in raw_warnings:
		warnings.append(str(raw_warning))

	var terrain_count := _metric_int_a7(metrics, "terrain_visual_mesh_nodes", "terrain_meshes_source")
	var water_count := _metric_int_a7(metrics, "water_visual_mesh_nodes", "water_meshes_source")
	var prop_count := _metric_int_a7(metrics, "props_visual_nodes", "prop_nodes_source")
	var boundary_collision_count := _metric_int_a7(metrics, "boundary_collision_bodies", "boundary_segments_source")
	var prop_collision_count := _metric_int_a7(metrics, "prop_collision_bodies", "prop_collision_bodies_source")
	var zonejump_count := _metric_int_a7(metrics, "zonejump_area_nodes", "zonejump_entries_source")
	var collision_total := int(metrics.get("collision_static_bodies", boundary_collision_count + prop_collision_count))
	var scene_path := str(snap.get("exported_scene_path", snap.get("generated_scene_path", _default_scene_path(znum))))
	var entry_ok := bool(snap.get("ok", false)) and errors.is_empty()
	if bool(snap.get("dry_run", false)):
		entry_ok = errors.is_empty()
	return {
		"zone_id": znum,
		"zone_name": "zone%03d" % znum,
		"scene_path": scene_path,
		"ok": entry_ok,
		"failed": not entry_ok,
		"error": "; ".join(errors),
		"errors": errors,
		"warnings": warnings,
		"terrain_count": terrain_count,
		"water_count": water_count,
		"prop_count": prop_count,
		"boundary_collision_count": boundary_collision_count,
		"prop_collision_count": prop_collision_count,
		"zonejump_count": zonejump_count,
		"collision_total": collision_total,
		"elapsed_ms": elapsed_ms,
		"checkpoint": str(snap.get("checkpoint", ZONE_EXPORT_SERVICE_CHECKPOINT)),
		"scope": str(snap.get("scope", ZONE_EXPORT_SERVICE_SCOPE)),
		"export_mode": str(snap.get("export_mode", "")),
		"file_exists": bool(snap.get("file_exists_after_save", false)),
		"export_ok": bool(snap.get("export_ok", false)),
		"reload_ok": bool(snap.get("reload_ok", false)),
		"pack_error_code": int(snap.get("pack_error_code", -1)),
		"export_error_code": int(snap.get("export_error_code", -1)),
		"dry_run": bool(snap.get("dry_run", false)),
		"zone_kind": str(snap.get("zone_kind", "unknown")),
		"generated_scene_status": str(snap.get("generated_scene_status", "unknown_unclassified")),
		"supported_for_generated_scene": bool(snap.get("supported_for_generated_scene", false)),
		"zone_kind_reason": str(snap.get("zone_kind_reason", "")),
	}



func _ensure_snap_zone_kind_a10a(snap: Dictionary, classification: Dictionary) -> void:
	if not snap.has("zone_kind"):
		snap["zone_kind"] = str(classification.get("zone_kind", "unknown"))
	if not snap.has("generated_scene_status"):
		snap["generated_scene_status"] = str(classification.get("generated_scene_status", "unknown_unclassified"))
	if not snap.has("supported_for_generated_scene"):
		snap["supported_for_generated_scene"] = bool(classification.get("supported_for_generated_scene", false))
	if not snap.has("zone_kind_reason"):
		snap["zone_kind_reason"] = str(classification.get("reason", ""))
	if not snap.has("zone_kind_evidence"):
		snap["zone_kind_evidence"] = classification.get("evidence", {})
	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	metrics["zone_kind"] = str(snap.get("zone_kind", "unknown"))
	metrics["supported_for_generated_scene"] = bool(snap.get("supported_for_generated_scene", false))
	metrics["generated_scene_status"] = str(snap.get("generated_scene_status", "unknown_unclassified"))
	snap["metrics"] = metrics


func _apply_zone_kind_to_result(host: Node, znum: int, result: RefCounted) -> Dictionary:
	var classification: Dictionary = classify_zone_kind_a10a(host, znum)
	result.set("zone_kind", str(classification.get("zone_kind", "unknown")))
	result.set("generated_scene_status", str(classification.get("generated_scene_status", "unknown_unclassified")))
	result.set("supported_for_generated_scene", bool(classification.get("supported_for_generated_scene", false)))
	result.set("zone_kind_reason", str(classification.get("reason", "")))
	result.set("zone_kind_evidence", classification.get("evidence", {}))
	return classification


func _apply_zone_kind_meta(root: Node, result: RefCounted) -> void:
	if root == null or result == null:
		return
	root.set_meta("daoc_zone_kind", str(result.get("zone_kind")))
	root.set_meta("daoc_generated_scene_status", str(result.get("generated_scene_status")))
	root.set_meta("daoc_supported_for_generated_scene", bool(result.get("supported_for_generated_scene")))
	root.set_meta("daoc_zone_kind_reason", str(result.get("zone_kind_reason")))


func _make_unsupported_zone_export_result(host: Node, znum: int, classification: Dictionary) -> RefCounted:
	var result: RefCounted = DaocZoneCreationResultScript.new()
	result.set("scope", ZONE_EXPORT_SERVICE_SCOPE)
	result.set("checkpoint", ZONE_EXPORT_SERVICE_CHECKPOINT)
	result.set("zone", znum)
	result.set("creation_mode", "a6_refused_unsupported_zone_kind")
	result.set("generated_scene_path", _default_scene_path(znum))
	result.set("exported_scene_path", _default_scene_path(znum))
	result.set("export_mode", "unsupported_zone_kind_refused")
	result.set("recommended_next_step", "P1-16A10A classify zone kinds before export; implement dedicated builder for this family")
	result.set("zone_kind", str(classification.get("zone_kind", "unknown")))
	result.set("generated_scene_status", str(classification.get("generated_scene_status", "unsupported_yet")))
	result.set("supported_for_generated_scene", false)
	result.set("zone_kind_reason", str(classification.get("reason", "unsupported zone kind")))
	result.set("zone_kind_evidence", classification.get("evidence", {}))
	result.set("metrics", {
		"zone_kind": str(classification.get("zone_kind", "unknown")),
		"supported_for_generated_scene": false,
		"generated_scene_status": str(classification.get("generated_scene_status", "unsupported_yet")),
		"zone_kind_reason": str(classification.get("reason", "unsupported zone kind")),
		"a6_export_service": true,
		"a6_target_zone": znum,
		"a6_zone_source_ready": false,
	})
	result.call("add_error", "GeneratedZone export unsupported for zone%03d kind=%s: %s" % [znum, str(classification.get("zone_kind", "unknown")), str(classification.get("reason", ""))])
	_last_result = result
	return result


func _count_manifest_entries_bool_a10a(entries: Array, key: String, expected: bool) -> int:
	var count: int = 0
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and bool((entry_value as Dictionary).get(key, false)) == expected:
			count += 1
	return count


func _manifest_zone_ids_by_support_a10a(entries: Array, supported: bool) -> Array:
	var out: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		if bool(entry.get("supported_for_generated_scene", false)) == supported:
			out.append(int(entry.get("zone_id", -1)))
	out.sort()
	return out


func _manifest_kind_counts_a10a(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var kind: String = str((entry_value as Dictionary).get("zone_kind", "unknown"))
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func _metric_int_a7(metrics: Dictionary, primary_key: String, fallback_key: String, fallback_value: int = 0) -> int:
	if metrics.has(primary_key):
		return int(metrics.get(primary_key, fallback_value))
	if metrics.has(fallback_key):
		return int(metrics.get(fallback_key, fallback_value))
	return fallback_value


func _write_manifest_a7(manifest_path: String, manifest: Dictionary) -> Dictionary:
	if manifest_path == "":
		return {"ok": false, "error": "manifest path empty"}
	if not _ensure_scene_parent_dir(manifest_path):
		return {"ok": false, "path": manifest_path, "error": "cannot create manifest parent directory"}
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": manifest_path, "error": "FileAccess.open failed", "error_code": FileAccess.get_open_error()}
	file.store_string(JSON.stringify(manifest, "	"))
	file.close()
	return {"ok": FileAccess.file_exists(manifest_path), "path": manifest_path, "error": "" if FileAccess.file_exists(manifest_path) else "manifest not found after write"}


func _zone_source_availability(host: Node, znum: int) -> Dictionary:
	var terrain_result := _get_zone_build_result(host, "_terrain_build_results", znum)
	var water_result := _get_zone_build_result(host, "_water_build_results", znum)
	var prop_result := _get_zone_build_result(host, "_prop_build_results", znum)
	var boundary_result := _get_zone_build_result(host, "_boundary_build_results", znum)
	var zonejump_result := _get_zone_build_result(host, "_zonejump_build_results", znum)
	var prop_collision: Array = _get_zone_array(host, "_prop_collision_runtime", znum)
	var terrain_meshes := 0
	var terrain_collision_bodies := 0
	var water_meshes := 0
	var prop_nodes := 0
	var boundary_segments := 0
	var zonejump_entries := 0
	if terrain_result != null:
		terrain_meshes = (terrain_result.get("terrain_meshes") as Array).size()
		terrain_collision_bodies = (terrain_result.get("collision_bodies") as Array).size()
	if water_result != null:
		water_meshes = (water_result.get("meshes") as Array).size()
	if prop_result != null:
		prop_nodes = (prop_result.get("prop_nodes") as Array).size()
	if boundary_result != null:
		boundary_segments = (boundary_result.get("boundary_segments") as Array).size()
	if zonejump_result != null:
		zonejump_entries = (zonejump_result.get("static_index") as Array).size()
	var prop_collision_branch_present := _find_runtime_child_branch(host, znum, "CollisionRoot", "PropsCollisionRoot") != null
	return {
		"zone": znum,
		"terrain_result_present": terrain_result != null,
		"water_result_present": water_result != null,
		"prop_result_present": prop_result != null,
		"boundary_result_present": boundary_result != null,
		"zonejump_result_present": zonejump_result != null,
		"prop_collision_branch_present": prop_collision_branch_present,
		"terrain_meshes": terrain_meshes,
		"terrain_collision_bodies": terrain_collision_bodies,
		"water_meshes": water_meshes,
		"prop_nodes": prop_nodes,
		"boundary_segments": boundary_segments,
		"prop_collision_bodies": prop_collision.size(),
		"zonejump_entries": zonejump_entries,
		"ready_full_export": terrain_meshes > 0 and prop_nodes > 0 and boundary_segments > 0 and zonejump_entries > 0 and prop_collision_branch_present,
	}


func _get_zone_array(host: Node, compat_name: String, znum: int) -> Array:
	if host == null:
		return []
	var value: Variant = host.get(compat_name)
	if typeof(value) != TYPE_DICTIONARY:
		return []
	var dict := value as Dictionary
	var arr_value: Variant = dict.get(znum, [])
	if typeof(arr_value) == TYPE_ARRAY:
		return arr_value as Array
	return []


func _zone_result_signature(host: Node, compat_name: String, signature_name: String, znum: int) -> String:
	var result := _get_zone_build_result(host, compat_name, znum)
	if result == null:
		return ""
	return str(result.get(signature_name))


func _zone_dict_signature(host: Node, compat_name: String, znum: int) -> String:
	if host == null:
		return ""
	var value: Variant = host.get(compat_name)
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	var dict := value as Dictionary
	return str(dict.get(znum, ""))


func _validate_against_expected_signatures(result: RefCounted) -> void:
	var signatures: Dictionary = result.get("signatures") as Dictionary
	for key in EXPECTED_SIGNATURES.keys():
		var expected := str(EXPECTED_SIGNATURES.get(key, ""))
		var actual := str(signatures.get(key, ""))
		if actual != expected:
			result.call("add_error", "signature mismatch %s actual=%s expected=%s" % [str(key), actual, expected])


func _freeze_says_closed(snap: Dictionary) -> bool:
	return bool(snap.get("refactor_closed", false)) and bool(snap.get("do_not_continue_zoneviewer_refactor_now", false))


func _pack_probe(root: Node3D) -> bool:
	if root == null:
		return false
	var packed := PackedScene.new()
	return packed.pack(root) == OK


func _ensure_scene_parent_dir(scene_path: String) -> bool:
	if scene_path == "":
		return false
	var base_dir := scene_path.get_base_dir()
	if base_dir == "":
		return false
	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	var err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	return err == OK or err == ERR_ALREADY_EXISTS


func _populate_terrain_water_visuals(host: Node, znum: int, result: RefCounted) -> void:
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot populate terrain/water: generated root is null")
		return
	var branches: Dictionary = result.get("branches") as Dictionary
	var terrain_branch: Node3D = branches.get("TerrainRoot", null) as Node3D
	var water_branch: Node3D = branches.get("WaterRoot", null) as Node3D
	if terrain_branch == null or water_branch == null:
		result.call("add_error", "cannot populate terrain/water: required branches missing")
		return

	var terrain_result := _get_zone_build_result(host, "_terrain_build_results", znum)
	var water_result := _get_zone_build_result(host, "_water_build_results", znum)
	var terrain_source: Node3D = null
	var water_source: Node3D = null
	if terrain_result != null:
		terrain_source = terrain_result.get("root") as Node3D
	if water_result != null:
		water_source = water_result.get("root") as Node3D
	if terrain_source == null:
		result.call("add_error", "cannot populate terrain: source root missing")
		return
	if water_source == null:
		result.call("add_error", "cannot populate water: source root missing")
		return

	_clear_children(terrain_branch)
	_clear_children(water_branch)

	var terrain_copy := _duplicate_scene_branch(terrain_source, "Zone%03d_TerrainVisuals" % znum)
	var water_copy := _duplicate_scene_branch(water_source, "Zone%03d_WaterVisuals" % znum)
	if terrain_copy == null:
		result.call("add_error", "cannot duplicate terrain source root")
		return
	if water_copy == null:
		result.call("add_error", "cannot duplicate water source root")
		terrain_copy.free()
		return

	terrain_branch.add_child(terrain_copy)
	water_branch.add_child(water_copy)
	_assign_owner_recursive(terrain_copy, root)
	_assign_owner_recursive(water_copy, root)
	terrain_copy.set_meta("daoc_generated_population", "terrain_visuals_14e")
	water_copy.set_meta("daoc_generated_population", "water_visuals_14b")

	var terrain_mesh_count := _count_mesh_instances(terrain_copy)
	var water_mesh_count := _count_mesh_instances(water_copy)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["visual_population_mode"] = "terrain_water_only"
	metrics["terrain_visual_root_present"] = true
	metrics["water_visual_root_present"] = true
	metrics["terrain_visual_mesh_nodes"] = terrain_mesh_count
	metrics["water_visual_mesh_nodes"] = water_mesh_count
	metrics["props_visual_nodes"] = 0
	metrics["collision_visual_nodes"] = 0
	metrics["props_included"] = false
	metrics["collisions_included"] = false
	metrics["runtime_nodes_duplicated"] = false
	result.set("metrics", metrics)

	if terrain_mesh_count != int(metrics.get("terrain_meshes_source", 0)):
		result.call("add_error", "terrain mesh count mismatch exported=%d source=%d" % [terrain_mesh_count, int(metrics.get("terrain_meshes_source", 0))])
	if water_mesh_count != int(metrics.get("water_meshes_source", 0)):
		result.call("add_error", "water mesh count mismatch exported=%d source=%d" % [water_mesh_count, int(metrics.get("water_meshes_source", 0))])


func _populate_props_preview_strategy(host: Node, znum: int, result: RefCounted, options: Dictionary) -> void:
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot populate props: generated root is null")
		return
	var branches: Dictionary = result.get("branches") as Dictionary
	var props_branch: Node3D = branches.get("StaticPropsRoot", null) as Node3D
	if props_branch == null:
		result.call("add_error", "cannot populate props: StaticPropsRoot missing")
		return

	var prop_result := _get_zone_build_result(host, "_prop_build_results", znum)
	if prop_result == null:
		result.call("add_error", "cannot populate props: P1-14D prop build result missing")
		return

	var source_nodes: Array = prop_result.get("prop_nodes") as Array
	var static_index: Array = prop_result.get("static_index") as Array
	if source_nodes.is_empty():
		result.call("add_error", "cannot populate props: source prop_nodes empty")
		return

	_clear_children(props_branch)

	var full_export_requested: bool = bool(options.get("full_props_export", false))
	var requested_limit: int = int(options.get("prop_export_limit", DEFAULT_PROP_PREVIEW_LIMIT))
	if full_export_requested:
		requested_limit = source_nodes.size()
	var limit: int = clampi(requested_limit, 0, source_nodes.size())
	var strategy: String = str(options.get("props_strategy", "editor_preview_even_sample_sector_buckets"))
	var population_kind: String = str(options.get("props_population_kind", "preview"))
	var root_suffix: String = "PropsFull" if full_export_requested else "PropsPreview"
	var generated_population: String = "props_full_zone_14d" if full_export_requested else "props_preview_14d"
	var visual_mode: String = "terrain_water_full_zone_props" if full_export_requested else "terrain_water_props_preview"
	var props_root_name: String = "Zone%03d_%s_%04d" % [znum, root_suffix, limit]
	var preview_root := Node3D.new()
	preview_root.name = props_root_name
	preview_root.set_meta("daoc_generated_population", generated_population)
	preview_root.set_meta("daoc_props_strategy", strategy)
	preview_root.set_meta("daoc_props_population_kind", population_kind)
	preview_root.set_meta("daoc_props_export_limit", limit)
	preview_root.set_meta("daoc_props_source_total", source_nodes.size())
	props_branch.add_child(preview_root)
	preview_root.owner = root

	var buckets := {}
	var exported := 0
	var sampled_indices: Array[int] = _sample_indices_evenly(source_nodes.size(), limit)
	for source_index in sampled_indices:
		if source_index < 0 or source_index >= source_nodes.size():
			continue
		var source_node: Node = source_nodes[source_index] as Node
		if source_node == null:
			continue
		var row: Dictionary = {}
		if source_index < static_index.size():
			row = static_index[source_index] as Dictionary
		var bucket := _get_or_create_prop_bucket(preview_root, root, buckets, row)
		var copy_node := source_node.duplicate() as Node
		var copy_3d := copy_node as Node3D
		if copy_3d == null:
			if copy_node != null:
				copy_node.free()
			continue
		_clear_owner_recursive(copy_3d)
		copy_3d.name = str(source_node.name)
		copy_3d.set_meta("daoc_generated_population", generated_population)
		copy_3d.set_meta("daoc_props_strategy", strategy)
		copy_3d.set_meta("daoc_props_population_kind", population_kind)
		copy_3d.set_meta("daoc_source_prop_index", source_index)
		copy_3d.set_meta("fixture_id", int(row.get("fixture_id", copy_3d.get_meta("fixture_id", 0))))
		copy_3d.set_meta("source_file", str(row.get("file", copy_3d.get_meta("source_file", ""))))
		bucket.add_child(copy_3d)
		_assign_owner_recursive(copy_3d, root)
		exported += 1

	var bucket_count := preview_root.get_child_count()
	var mesh_count := _count_mesh_instances(preview_root)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["visual_population_mode"] = visual_mode
	metrics["props_strategy"] = strategy
	metrics["props_population_kind"] = population_kind
	metrics["props_root_present"] = true
	metrics["props_root_name"] = props_root_name
	metrics["props_preview_root_present"] = not full_export_requested
	metrics["props_preview_root_name"] = props_root_name if not full_export_requested else ""
	metrics["props_full_root_present"] = full_export_requested
	metrics["props_full_root_name"] = props_root_name if full_export_requested else ""
	metrics["props_preview_limit"] = limit
	metrics["props_export_limit"] = limit
	metrics["props_source_total"] = source_nodes.size()
	metrics["props_visual_nodes"] = exported
	metrics["props_visual_mesh_nodes"] = mesh_count
	metrics["props_skipped_nodes"] = max(0, source_nodes.size() - exported)
	metrics["props_sector_bucket_count"] = bucket_count
	metrics["props_sector_bucket_max"] = 64
	metrics["props_included"] = true
	metrics["props_full_export"] = exported == source_nodes.size()
	metrics["props_preview_capped"] = exported < source_nodes.size()
	metrics["props_full_zone_scene"] = full_export_requested and exported == source_nodes.size()
	metrics["collisions_included"] = false
	metrics["collision_visual_nodes"] = 0
	metrics["runtime_nodes_duplicated"] = false
	result.set("metrics", metrics)

	root.set_meta("daoc_props_strategy", strategy)
	root.set_meta("daoc_props_population_kind", population_kind)
	root.set_meta("daoc_props_root_name", props_root_name)
	root.set_meta("daoc_props_preview_root_name", props_root_name if not full_export_requested else "")
	root.set_meta("daoc_props_full_root_name", props_root_name if full_export_requested else "")
	root.set_meta("daoc_props_exported_nodes", exported)
	root.set_meta("daoc_props_source_total", source_nodes.size())

	if exported != limit:
		result.call("add_warning", "props preview exported %d nodes for requested limit %d" % [exported, limit])
	if exported <= 0 and limit > 0:
		result.call("add_error", "props preview exported no nodes")


func _populate_collision_editor_data(host: Node, znum: int, result: RefCounted, options: Dictionary) -> void:
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot populate collision editor data: generated root is null")
		return
	var branches: Dictionary = result.get("branches") as Dictionary
	var collision_branch: Node3D = branches.get("CollisionRoot", null) as Node3D
	if collision_branch == null:
		result.call("add_error", "cannot populate collision editor data: CollisionRoot missing")
		return

	_clear_children(collision_branch)

	var strategy: String = str(options.get("collision_editor_strategy", "editor_data_staticbody_roots"))
	var collision_root := Node3D.new()
	collision_root.name = "Zone%03d_CollisionEditorData" % znum
	collision_root.set_meta("daoc_generated_population", "collision_editor_data_14c")
	collision_root.set_meta("daoc_collision_editor_strategy", strategy)
	collision_root.set_meta("daoc_runtime_active", false)
	collision_branch.add_child(collision_root)
	collision_root.owner = root

	var boundary_container := Node3D.new()
	boundary_container.name = "BoundaryCollisionRoot"
	boundary_container.set_meta("daoc_generated_population", "boundary_collision_editor_data_14c")
	boundary_container.set_meta("daoc_runtime_active", false)
	collision_root.add_child(boundary_container)
	boundary_container.owner = root

	var prop_container := Node3D.new()
	prop_container.name = "PropCollisionRoot"
	prop_container.set_meta("daoc_generated_population", "prop_collision_editor_data_14c")
	prop_container.set_meta("daoc_runtime_active", false)
	collision_root.add_child(prop_container)
	prop_container.owner = root

	var boundary_result := _get_zone_build_result(host, "_boundary_build_results", znum)
	var boundary_source: Node3D = null
	if boundary_result != null:
		boundary_source = boundary_result.get("root") as Node3D
	if boundary_source == null:
		result.call("add_error", "cannot populate boundary collision editor data: source root missing")
		return
	var boundary_copy := _duplicate_scene_branch(boundary_source, "Zone%03d_BoundaryCollision" % znum)
	if boundary_copy == null:
		result.call("add_error", "cannot duplicate boundary collision root")
		return
	boundary_copy.set_meta("daoc_generated_population", "boundary_collision_editor_data_14c")
	boundary_copy.set_meta("daoc_runtime_active", false)
	boundary_container.add_child(boundary_copy)
	_assign_owner_recursive(boundary_copy, root)
	_deactivate_runtime_area_nodes(boundary_copy)

	var prop_source := _find_runtime_child_branch(host, znum, "CollisionRoot", "PropsCollisionRoot")
	if prop_source == null:
		result.call("add_error", "cannot populate prop collision editor data: PropsCollisionRoot missing")
		boundary_copy.free()
		return
	var prop_copy := _duplicate_scene_branch(prop_source, "Zone%03d_PropCollisionAABBs" % znum)
	if prop_copy == null:
		result.call("add_error", "cannot duplicate prop collision root")
		return
	prop_copy.set_meta("daoc_generated_population", "prop_collision_editor_data_14c")
	prop_copy.set_meta("daoc_runtime_active", false)
	prop_container.add_child(prop_copy)
	_assign_owner_recursive(prop_copy, root)
	_deactivate_runtime_area_nodes(prop_copy)

	var boundary_body_count := _count_static_bodies(boundary_copy)
	var prop_body_count := _count_static_bodies(prop_copy)
	var shape_count := _count_collision_shapes(collision_root)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["collision_editor_data_included"] = true
	metrics["collision_editor_strategy"] = strategy
	metrics["collisions_included"] = true
	metrics["collision_root_present"] = true
	metrics["collision_root_name"] = collision_root.name
	metrics["boundary_collision_root_present"] = true
	metrics["boundary_collision_root_name"] = boundary_copy.name
	metrics["boundary_collision_bodies"] = boundary_body_count
	metrics["prop_collision_root_present"] = true
	metrics["prop_collision_root_name"] = prop_copy.name
	metrics["prop_collision_bodies"] = prop_body_count
	metrics["collision_static_bodies"] = boundary_body_count + prop_body_count
	metrics["collision_shape_nodes"] = shape_count
	metrics["collision_visual_nodes"] = 0
	result.set("metrics", metrics)

	root.set_meta("daoc_collision_editor_strategy", strategy)
	root.set_meta("daoc_collision_root_name", collision_root.name)
	root.set_meta("daoc_boundary_collision_bodies", boundary_body_count)
	root.set_meta("daoc_prop_collision_bodies", prop_body_count)

	if boundary_body_count != int(metrics.get("boundary_segments_source", 0)):
		result.call("add_error", "boundary collision count mismatch exported=%d source=%d" % [boundary_body_count, int(metrics.get("boundary_segments_source", 0))])
	if prop_body_count != int(metrics.get("prop_collision_bodies_source", 0)):
		result.call("add_error", "prop collision count mismatch exported=%d source=%d" % [prop_body_count, int(metrics.get("prop_collision_bodies_source", 0))])


func _populate_zonejump_editor_data(host: Node, znum: int, result: RefCounted, options: Dictionary) -> void:
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot populate zonejump editor data: generated root is null")
		return
	var branches: Dictionary = result.get("branches") as Dictionary
	var zonejump_branch: Node3D = branches.get("ZoneJumpRoot", null) as Node3D
	if zonejump_branch == null:
		result.call("add_error", "cannot populate zonejump editor data: ZoneJumpRoot missing")
		return

	_clear_children(zonejump_branch)

	var zonejump_result := _get_zone_build_result(host, "_zonejump_build_results", znum)
	var zonejump_source: Node3D = null
	if zonejump_result != null:
		zonejump_source = zonejump_result.get("root") as Node3D
	if zonejump_source == null:
		result.call("add_error", "cannot populate zonejump editor data: source root missing")
		return

	var strategy: String = str(options.get("zonejump_editor_strategy", "editor_data_area_roots_monitoring_off"))
	var zonejump_copy := _duplicate_scene_branch(zonejump_source, "Zone%03d_ZoneJumpEditorData" % znum)
	if zonejump_copy == null:
		result.call("add_error", "cannot duplicate zonejump editor data root")
		return
	zonejump_copy.set_meta("daoc_generated_population", "zonejump_editor_data_14a")
	zonejump_copy.set_meta("daoc_zonejump_editor_strategy", strategy)
	zonejump_copy.set_meta("daoc_runtime_active", false)
	zonejump_branch.add_child(zonejump_copy)
	_assign_owner_recursive(zonejump_copy, root)
	_deactivate_runtime_area_nodes(zonejump_copy)

	var area_count := _count_area_nodes(zonejump_copy)
	var shape_count := _count_collision_shapes(zonejump_copy)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["zonejump_editor_data_included"] = true
	metrics["zonejump_editor_strategy"] = strategy
	metrics["zonejump_root_present"] = true
	metrics["zonejump_root_name"] = zonejump_copy.name
	metrics["zonejump_area_nodes"] = area_count
	metrics["zonejump_collision_shape_nodes"] = shape_count
	metrics["zonejump_runtime_monitoring_disabled"] = _all_area_nodes_monitoring_off(zonejump_copy)
	result.set("metrics", metrics)

	root.set_meta("daoc_zonejump_editor_strategy", strategy)
	root.set_meta("daoc_zonejump_root_name", zonejump_copy.name)
	root.set_meta("daoc_zonejump_area_nodes", area_count)

	if area_count != int(metrics.get("zonejump_entries_source", 0)):
		result.call("add_error", "zonejump area count mismatch exported=%d source=%d" % [area_count, int(metrics.get("zonejump_entries_source", 0))])


func _sample_indices_evenly(total: int, limit: int) -> Array[int]:
	var indices: Array[int] = []
	if total <= 0 or limit <= 0:
		return indices
	if limit >= total:
		for i in range(total):
			indices.append(i)
		return indices
	var denom: int = maxi(1, limit - 1)
	var used := {}
	for i in range(limit):
		var idx := int(round(float(i) * float(total - 1) / float(denom)))
		idx = clampi(idx, 0, total - 1)
		while used.has(idx) and idx < total - 1:
			idx += 1
		if used.has(idx):
			idx = 0
			while used.has(idx) and idx < total - 1:
				idx += 1
		used[idx] = true
		indices.append(idx)
	return indices


func _get_or_create_prop_bucket(preview_root: Node3D, scene_owner: Node, buckets: Dictionary, row: Dictionary) -> Node3D:
	var sx := clampi(int(floor(float(row.get("x", 0.0)) / 8192.0)), 0, 7)
	var sy := clampi(int(floor(float(row.get("y", 0.0)) / 8192.0)), 0, 7)
	var key := "%02d_%02d" % [sx, sy]
	if buckets.has(key):
		return buckets[key] as Node3D
	var bucket := Node3D.new()
	bucket.name = "Sector_%s" % key
	bucket.set_meta("daoc_generated_population", "props_preview_sector_bucket")
	bucket.set_meta("daoc_sector_x", sx)
	bucket.set_meta("daoc_sector_y", sy)
	preview_root.add_child(bucket)
	bucket.owner = scene_owner
	buckets[key] = bucket
	return bucket


func _find_runtime_zone_branch(host: Node, znum: int, branch_name: String) -> Node3D:
	if host == null:
		return null
	var zone_root: Node = null
	if host.has_method("_get_zone_root"):
		var root_value: Variant = host.call("_get_zone_root", znum)
		zone_root = root_value as Node
	if zone_root == null:
		zone_root = host.find_child("Zone%03d_Root" % znum, true, false)
	if zone_root == null:
		return null
	var branch := zone_root.get_node_or_null(branch_name)
	if branch != null and branch is Node3D:
		return branch as Node3D
	var found := zone_root.find_child(branch_name, true, false)
	if found != null and found is Node3D:
		return found as Node3D
	return null


func _find_runtime_child_branch(host: Node, znum: int, branch_name: String, child_name: String) -> Node3D:
	var branch := _find_runtime_zone_branch(host, znum, branch_name)
	if branch == null:
		return null
	var child := branch.get_node_or_null(child_name)
	if child != null and child is Node3D:
		return child as Node3D
	var found := branch.find_child(child_name, true, false)
	if found != null and found is Node3D:
		return found as Node3D
	return null


func _deactivate_runtime_area_nodes(node: Node) -> void:
	if node == null:
		return
	if node is Area3D:
		var area := node as Area3D
		area.monitoring = false
		area.monitorable = false
		area.set_meta("daoc_runtime_active", false)
	for child in node.get_children():
		if child is Node:
			_deactivate_runtime_area_nodes(child as Node)


func _count_static_bodies(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		if child is Node:
			count += _count_static_bodies(child as Node)
	return count


func _count_area_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is Area3D else 0
	for child in node.get_children():
		if child is Node:
			count += _count_area_nodes(child as Node)
	return count


func _count_collision_shapes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CollisionShape3D else 0
	for child in node.get_children():
		if child is Node:
			count += _count_collision_shapes(child as Node)
	return count


func _all_area_nodes_monitoring_off(node: Node) -> bool:
	if node == null:
		return true
	if node is Area3D:
		var area := node as Area3D
		if area.monitoring or area.monitorable:
			return false
	for child in node.get_children():
		if child is Node:
			if not _all_area_nodes_monitoring_off(child as Node):
				return false
	return true


func _apply_editor_recenter_to_zone_center(host: Node, znum: int, result: RefCounted, anchor_daoc_x: float, anchor_daoc_y: float) -> void:
	var root: Node3D = result.get("root") as Node3D
	if root == null:
		result.call("add_error", "cannot recenter editor scene: generated root is null")
		return
	if host == null:
		result.call("add_error", "cannot recenter editor scene: host is null")
		return
	if not host.has_method("sample_daoc_floor_z"):
		result.call("add_error", "cannot recenter editor scene: sample_daoc_floor_z missing")
		return

	var anchor_floor_z := float(host.call("sample_daoc_floor_z", znum, anchor_daoc_x, anchor_daoc_y, 0.0))
	var anchor_godot := Vector3(anchor_daoc_x, anchor_floor_z, anchor_daoc_y)
	if host.has_method("daoc_to_godot"):
		var converted_anchor: Variant = host.call("daoc_to_godot", znum, anchor_daoc_x, anchor_daoc_y, anchor_floor_z)
		if typeof(converted_anchor) == TYPE_VECTOR3:
			anchor_godot = converted_anchor as Vector3

	var offset := Vector3(-anchor_godot.x, -anchor_godot.y, -anchor_godot.z)
	root.position = offset
	root.set_meta("daoc_editor_recenter_enabled", true)
	root.set_meta("daoc_editor_recenter_mode", "zone_center_floor_to_origin")
	root.set_meta("daoc_editor_anchor_daoc_x", anchor_daoc_x)
	root.set_meta("daoc_editor_anchor_daoc_y", anchor_daoc_y)
	root.set_meta("daoc_editor_anchor_floor_z", anchor_floor_z)
	root.set_meta("daoc_editor_anchor_godot", anchor_godot)
	root.set_meta("daoc_editor_root_offset", offset)

	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["editor_recenter_enabled"] = true
	metrics["editor_recenter_mode"] = "zone_center_floor_to_origin"
	metrics["editor_anchor_daoc_x"] = anchor_daoc_x
	metrics["editor_anchor_daoc_y"] = anchor_daoc_y
	metrics["editor_anchor_floor_z"] = anchor_floor_z
	metrics["editor_anchor_godot_x"] = anchor_godot.x
	metrics["editor_anchor_godot_y"] = anchor_godot.y
	metrics["editor_anchor_godot_z"] = anchor_godot.z
	metrics["editor_root_offset_x"] = offset.x
	metrics["editor_root_offset_y"] = offset.y
	metrics["editor_root_offset_z"] = offset.z
	metrics["editor_center_floor_after_offset_x"] = anchor_godot.x + offset.x
	metrics["editor_center_floor_after_offset_y"] = anchor_godot.y + offset.y
	metrics["editor_center_floor_after_offset_z"] = anchor_godot.z + offset.z
	result.set("metrics", metrics)


func _get_zone_build_result(host: Node, compat_name: String, znum: int) -> RefCounted:
	if host == null:
		return null
	var value: Variant = host.get(compat_name)
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var dict := value as Dictionary
	return dict.get(znum, null) as RefCounted


func _duplicate_scene_branch(source: Node3D, new_name: String) -> Node3D:
	if source == null:
		return null
	var dup := source.duplicate() as Node3D
	if dup == null:
		return null
	dup.name = new_name
	_clear_owner_recursive(dup)
	return dup


func _clear_owner_recursive(node: Node) -> void:
	if node == null:
		return
	node.owner = null
	for child in node.get_children():
		if child is Node:
			_clear_owner_recursive(child as Node)


func _assign_owner_recursive(node: Node, scene_owner: Node) -> void:
	if node == null or scene_owner == null:
		return
	if node != scene_owner:
		node.owner = scene_owner
	for child in node.get_children():
		if child is Node:
			_assign_owner_recursive(child as Node, scene_owner)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Node:
			(child as Node).free()


func _count_mesh_instances(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		if child is Node:
			count += _count_mesh_instances(child as Node)
	return count


func _validate_reloaded_scene(result: RefCounted, scene_path: String) -> void:
	var loaded: Resource = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = loaded as PackedScene
	if packed == null:
		result.call("add_error", "ResourceLoader.load failed for exported scene: %s" % scene_path)
		return
	var inst := packed.instantiate()
	if inst == null:
		result.call("add_error", "PackedScene.instantiate failed for exported scene: %s" % scene_path)
		return
	result.set("reload_root_name", inst.name)
	var branch_names: Array = []
	for child in inst.get_children():
		if child is Node:
			branch_names.append(str((child as Node).name))
	result.set("reload_branch_names", branch_names)
	var expected_ok := true
	for branch_name in DEFAULT_BRANCHES:
		if not branch_names.has(str(branch_name)):
			expected_ok = false
			result.call("add_error", "reloaded scene missing branch: %s" % str(branch_name))
	var expected_root_name := ""
	var root: Node = result.get("root") as Node
	if root != null:
		expected_root_name = str(root.name)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	var reload_terrain_root: Node = inst.get_node_or_null("TerrainRoot")
	var reload_water_root: Node = inst.get_node_or_null("WaterRoot")
	var reload_static_props_root: Node = inst.get_node_or_null("StaticPropsRoot")
	metrics["reload_terrain_mesh_nodes"] = _count_mesh_instances(reload_terrain_root)
	metrics["reload_water_mesh_nodes"] = _count_mesh_instances(reload_water_root)
	metrics["reload_prop_mesh_nodes"] = _count_mesh_instances(reload_static_props_root)
	var props_root_name := str(metrics.get("props_root_name", ""))
	if props_root_name == "":
		props_root_name = str(metrics.get("props_preview_root_name", ""))
	var reload_props_root: Node = null
	if reload_static_props_root != null and props_root_name != "":
		reload_props_root = reload_static_props_root.get_node_or_null(props_root_name)
	metrics["reload_props_root_present"] = reload_props_root != null
	metrics["reload_props_bucket_count"] = reload_props_root.get_child_count() if reload_props_root != null else 0
	metrics["reload_props_exported_nodes"] = _count_direct_prop_nodes_in_buckets(reload_props_root)
	metrics["reload_props_preview_root_present"] = reload_props_root != null and bool(metrics.get("props_preview_root_present", false))
	metrics["reload_props_preview_bucket_count"] = int(metrics.get("reload_props_bucket_count", 0)) if bool(metrics.get("props_preview_root_present", false)) else 0
	metrics["reload_props_preview_exported_nodes"] = int(metrics.get("reload_props_exported_nodes", 0)) if bool(metrics.get("props_preview_root_present", false)) else 0
	metrics["reload_props_full_root_present"] = reload_props_root != null and bool(metrics.get("props_full_root_present", false))
	metrics["reload_props_full_bucket_count"] = int(metrics.get("reload_props_bucket_count", 0)) if bool(metrics.get("props_full_root_present", false)) else 0
	metrics["reload_props_full_exported_nodes"] = int(metrics.get("reload_props_exported_nodes", 0)) if bool(metrics.get("props_full_root_present", false)) else 0
	var reload_collision_root: Node = inst.get_node_or_null("CollisionRoot")
	var reload_zonejump_root: Node = inst.get_node_or_null("ZoneJumpRoot")
	metrics["reload_collision_static_bodies"] = _count_static_bodies(reload_collision_root)
	metrics["reload_collision_shape_nodes"] = _count_collision_shapes(reload_collision_root)
	metrics["reload_boundary_collision_root_present"] = reload_collision_root != null and reload_collision_root.find_child("Zone%03d_BoundaryCollision" % int(result.get("zone")), true, false) != null
	metrics["reload_prop_collision_root_present"] = reload_collision_root != null and reload_collision_root.find_child("Zone%03d_PropCollisionAABBs" % int(result.get("zone")), true, false) != null
	metrics["reload_zonejump_area_nodes"] = _count_area_nodes(reload_zonejump_root)
	metrics["reload_zonejump_collision_shape_nodes"] = _count_collision_shapes(reload_zonejump_root)
	metrics["reload_zonejump_root_present"] = reload_zonejump_root != null and reload_zonejump_root.find_child("Zone%03d_ZoneJumpEditorData" % int(result.get("zone")), true, false) != null
	metrics["reload_zonejump_runtime_monitoring_disabled"] = _all_area_nodes_monitoring_off(reload_zonejump_root)
	metrics["reload_total_mesh_nodes"] = int(metrics.get("reload_terrain_mesh_nodes", 0)) + int(metrics.get("reload_water_mesh_nodes", 0)) + int(metrics.get("reload_prop_mesh_nodes", 0))
	var inst3d: Node3D = inst as Node3D
	if inst3d != null:
		metrics["reload_root_position_x"] = inst3d.position.x
		metrics["reload_root_position_y"] = inst3d.position.y
		metrics["reload_root_position_z"] = inst3d.position.z
		metrics["reload_editor_recenter_enabled_meta"] = bool(inst3d.get_meta("daoc_editor_recenter_enabled", false))
		metrics["reload_editor_recenter_mode_meta"] = str(inst3d.get_meta("daoc_editor_recenter_mode", ""))
		metrics["reload_center_floor_after_offset_x"] = float(metrics.get("editor_anchor_godot_x", 0.0)) + inst3d.position.x
		metrics["reload_center_floor_after_offset_y"] = float(metrics.get("editor_anchor_godot_y", 0.0)) + inst3d.position.y
		metrics["reload_center_floor_after_offset_z"] = float(metrics.get("editor_anchor_godot_z", 0.0)) + inst3d.position.z
	result.set("metrics", metrics)
	result.set("reload_ok", expected_ok and str(inst.name) == expected_root_name)
	inst.free()


func _count_direct_prop_nodes_in_buckets(preview_root: Node) -> int:
	if preview_root == null:
		return 0
	var count := 0
	for bucket in preview_root.get_children():
		if bucket is Node:
			count += (bucket as Node).get_child_count()
	return count


func _validate_one_generated_dungeon_scene_c3(znum: int, scene_path: String, expected: Dictionary) -> Dictionary:
	var item := {
		"zone": znum,
		"zone_id": znum,
		"zone_name": str(expected.get("zone_name", "zone%03d" % znum)),
		"scene_path": scene_path,
		"expected": expected.duplicate(true),
		"ok": false,
		"exists": FileAccess.file_exists(scene_path),
		"load_ok": false,
		"instantiate_ok": false,
		"root_name": "",
		"root_name_ok": false,
		"branch_names": [],
		"required_roots_ok": false,
		"status_meta_present": false,
		"metrics": {},
		"metric_checks": [],
		"errors": [],
	}
	if not bool(item.get("exists", false)):
		(item["errors"] as Array).append("generated dungeon scene missing: %s" % scene_path)
		return item
	var loaded: Resource = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = loaded as PackedScene
	if packed == null:
		(item["errors"] as Array).append("ResourceLoader.load failed for %s" % scene_path)
		return item
	item["load_ok"] = true
	var inst := packed.instantiate()
	if inst == null:
		(item["errors"] as Array).append("PackedScene.instantiate failed for %s" % scene_path)
		return item
	item["instantiate_ok"] = true
	item["root_name"] = str(inst.name)
	var expected_root := "GeneratedDungeon_%03d" % znum
	item["root_name_ok"] = str(inst.name) == expected_root
	var branch_names: Array = []
	for child in inst.get_children():
		if child is Node:
			branch_names.append(str((child as Node).name))
	item["branch_names"] = branch_names
	var required_roots := ["DungeonChunkInstances", "DungeonPortalDebug", "DungeonLightDebug"]
	var missing_roots: Array = []
	for root_name_value in required_roots:
		var root_name: String = str(root_name_value)
		if not branch_names.has(root_name):
			missing_roots.append(root_name)
	item["required_roots_ok"] = missing_roots.is_empty()
	if not bool(item.get("root_name_ok", false)):
		(item["errors"] as Array).append("root name mismatch got=%s expected=%s" % [str(inst.name), expected_root])
	if not bool(item.get("required_roots_ok", false)):
		(item["errors"] as Array).append("missing required roots=%s" % str(missing_roots))
	var status: Dictionary = {}
	var raw_status: Variant = (inst as Node).get_meta("status", {})
	if typeof(raw_status) == TYPE_DICTIONARY:
		status = raw_status as Dictionary
	item["status_meta_present"] = not status.is_empty()
	if status.is_empty():
		(item["errors"] as Array).append("root status metadata missing")
	var metrics: Dictionary = _extract_generated_dungeon_metrics_c3(inst, status)
	item["metrics"] = metrics
	var checks: Array = []
	for key_value in (expected.get("metric_keys", []) as Array):
		var key: String = str(key_value)
		var expected_value: Variant = expected.get(key)
		var actual_value: Variant = metrics.get(key)
		var check_ok: bool = _metric_values_equal_c3(expected_value, actual_value)
		checks.append({"key": key, "expected": expected_value, "actual": actual_value, "ok": check_ok})
		if not check_ok:
			(item["errors"] as Array).append("metric mismatch %s actual=%s expected=%s" % [key, str(actual_value), str(expected_value)])
	item["metric_checks"] = checks
	item["ok"] = bool(item.get("exists", false)) and bool(item.get("load_ok", false)) and bool(item.get("instantiate_ok", false)) and bool(item.get("root_name_ok", false)) and bool(item.get("required_roots_ok", false)) and bool(item.get("status_meta_present", false)) and (item["errors"] as Array).is_empty()
	inst.free()
	return item


func _extract_generated_dungeon_metrics_c3(inst: Node, status: Dictionary) -> Dictionary:
	var chunk_result: Dictionary = status.get("chunk_result", {}) as Dictionary
	var place_result: Dictionary = status.get("place_result", {}) as Dictionary
	var portal_result: Dictionary = status.get("portal_result", {}) as Dictionary
	var lights_result: Dictionary = status.get("lights_result", {}) as Dictionary
	var portal_graph: Dictionary = status.get("portal_graph", {}) as Dictionary
	return {
		"zone": int(status.get("zone", status.get("zone_id", -1))),
		"zone_name": str(status.get("zone_name", "")),
		"generated_scene_type": str(status.get("generated_scene_type", (inst as Node).get_meta("daoc_generated_scene_type", ""))),
		"chunks": int(chunk_result.get("chunk_count", 0)),
		"instances": int(place_result.get("placement_count", 0)),
		"portal_declared": int(portal_result.get("declared_count", 0)),
		"portal_links": int(portal_result.get("link_count", 0)),
		"lights": int(lights_result.get("light_count", 0)),
		"placeholder_nodes": int(status.get("placeholder_nodes", 0)),
		"nif_preview_nodes": int(status.get("nif_preview_nodes", 0)),
		"nif_preview_failures": int(status.get("nif_preview_failures", 0)),
		"logical_connector_nodes": int(status.get("logical_connector_nodes", 0)),
		"collision_bodies": int(status.get("collision_bodies", 0)),
		"collision_failures": int(status.get("collision_failures", 0)),
		"material_textures_missing": int(status.get("material_textures_missing", 0)),
		"portal_graph_components": int(portal_graph.get("component_count", 0)),
		"portal_graph_connected_all": bool(portal_graph.get("connected_all_instances", false)),
		"portal_failed_connector_count": (portal_graph.get("failed_connector_instances", []) as Array).size(),
		"portal_logical_connector_count": (portal_graph.get("logical_connector_instances", []) as Array).size(),
		"reload_mesh_nodes": _count_mesh_instances(inst),
		"reload_collision_static_bodies": _count_static_bodies(inst),
		"reload_collision_shape_nodes": _count_collision_shapes(inst),
	}


func _expected_generated_dungeon_metrics_c3(znum: int) -> Dictionary:
	var common_keys := [
		"generated_scene_type",
		"chunks",
		"instances",
		"portal_links",
		"lights",
		"placeholder_nodes",
		"nif_preview_nodes",
		"nif_preview_failures",
		"logical_connector_nodes",
		"collision_bodies",
		"collision_failures",
		"material_textures_missing",
		"portal_graph_connected_all",
		"portal_failed_connector_count",
		"portal_logical_connector_count",
	]
	if znum == 19:
		return {
			"zone_name": "Stonehenge Barrows Dungeon",
			"metric_keys": common_keys.duplicate(),
			"generated_scene_type": "GeneratedDungeonScene",
			"chunks": 36,
			"instances": 75,
			"portal_links": 168,
			"lights": 28,
			"placeholder_nodes": 0,
			"nif_preview_nodes": 71,
			"nif_preview_failures": 0,
			"logical_connector_nodes": 4,
			"collision_bodies": 71,
			"collision_failures": 0,
			"material_textures_missing": 0,
			"portal_graph_connected_all": true,
			"portal_failed_connector_count": 0,
			"portal_logical_connector_count": 4,
		}
	if znum == 21:
		return {
			"zone_name": "Tomb of Mithra",
			"metric_keys": common_keys.duplicate(),
			"generated_scene_type": "GeneratedDungeonScene",
			"chunks": 20,
			"instances": 163,
			"portal_links": 356,
			"lights": 27,
			"placeholder_nodes": 0,
			"nif_preview_nodes": 162,
			"nif_preview_failures": 0,
			"logical_connector_nodes": 1,
			"collision_bodies": 162,
			"collision_failures": 0,
			"material_textures_missing": 0,
			"portal_graph_connected_all": true,
			"portal_failed_connector_count": 0,
			"portal_logical_connector_count": 1,
		}
	return {
		"zone_name": DaocDungeonFileResolverScript.default_zone_name(znum),
		"metric_keys": ["generated_scene_type", "placeholder_nodes", "nif_preview_failures", "collision_failures", "material_textures_missing"],
		"generated_scene_type": "GeneratedDungeonScene",
		"placeholder_nodes": 0,
		"nif_preview_failures": 0,
		"collision_failures": 0,
		"material_textures_missing": 0,
	}


func _metric_values_equal_c3(expected_value: Variant, actual_value: Variant) -> bool:
	if typeof(expected_value) == TYPE_BOOL:
		return bool(actual_value) == bool(expected_value)
	if typeof(expected_value) == TYPE_INT or typeof(expected_value) == TYPE_FLOAT:
		return int(actual_value) == int(expected_value)
	return str(actual_value) == str(expected_value)


func _write_text_report_c3(txt_path: String, text: String) -> Dictionary:
	if txt_path == "":
		return {"ok": false, "error": "text report path empty"}
	if not _ensure_scene_parent_dir(txt_path):
		return {"ok": false, "path": txt_path, "error": "cannot create text report parent directory"}
	var file := FileAccess.open(txt_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": txt_path, "error": "FileAccess.open failed", "error_code": FileAccess.get_open_error()}
	file.store_string(text)
	file.close()
	return {"ok": FileAccess.file_exists(txt_path), "path": txt_path, "error": "" if FileAccess.file_exists(txt_path) else "text report not found after write"}


func _format_generated_dungeon_report_txt_c3(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("DAoC GeneratedDungeonScene regression report")
	lines.append("scope=%s" % str(report.get("scope", "")))
	lines.append("checkpoint=%s" % str(report.get("checkpoint", "")))
	lines.append("ok=%s ok_count=%d fail_count=%d zones=%s" % [str(report.get("ok", false)), int(report.get("ok_count", 0)), int(report.get("fail_count", 0)), str(report.get("zones", []))])
	lines.append("")
	for item_value in (report.get("results", []) as Array):
		var item: Dictionary = item_value as Dictionary
		lines.append("[zone%03d] %s" % [int(item.get("zone", -1)), "OK" if bool(item.get("ok", false)) else "FAIL"])
		lines.append("scene=%s" % str(item.get("scene_path", "")))
		lines.append("root=%s branches=%s" % [str(item.get("root_name", "")), str(item.get("branch_names", []))])
		var metrics: Dictionary = item.get("metrics", {}) as Dictionary
		lines.append("metrics chunks=%d instances=%d portals=%d lights=%d previews=%d placeholders=%d collisions=%d connected=%s" % [
			int(metrics.get("chunks", 0)),
			int(metrics.get("instances", 0)),
			int(metrics.get("portal_links", 0)),
			int(metrics.get("lights", 0)),
			int(metrics.get("nif_preview_nodes", 0)),
			int(metrics.get("placeholder_nodes", 0)),
			int(metrics.get("collision_bodies", 0)),
			str(metrics.get("portal_graph_connected_all", false)),
		])
		if not bool(item.get("ok", false)):
			lines.append("errors=%s" % str(item.get("errors", [])))
		lines.append("")
	return "\n".join(lines)


func _default_dungeon_scene_path(znum: int) -> String:
	return "res://reports/generated/zones/zone%03d/GeneratedDungeon_%03d.tscn" % [znum, znum]


func _set_scene_owner_recursive(node: Node, owner: Node) -> void:
	if node == null or owner == null:
		return
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child == null:
			continue
		child.owner = owner
		_set_scene_owner_recursive(child, owner)


func _validate_reloaded_dungeon_scene_c2(result: RefCounted, scene_path: String) -> void:
	var loaded: Resource = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = loaded as PackedScene
	if packed == null:
		result.call("add_error", "ResourceLoader.load failed for exported dungeon scene: %s" % scene_path)
		return
	var inst := packed.instantiate()
	if inst == null:
		result.call("add_error", "PackedScene.instantiate failed for exported dungeon scene: %s" % scene_path)
		return
	result.set("reload_root_name", inst.name)
	var branch_names: Array = []
	for child in inst.get_children():
		if child is Node:
			branch_names.append(str((child as Node).name))
	result.set("reload_branch_names", branch_names)
	var expected_root_name := ""
	var root: Node = result.get("root") as Node
	if root != null:
		expected_root_name = str(root.name)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	metrics["reload_branch_names"] = branch_names.duplicate()
	metrics["reload_dungeon_chunk_instances_root_present"] = inst.get_node_or_null("DungeonChunkInstances") != null
	metrics["reload_dungeon_portal_debug_root_present"] = inst.get_node_or_null("DungeonPortalDebug") != null
	metrics["reload_dungeon_light_debug_root_present"] = inst.get_node_or_null("DungeonLightDebug") != null
	metrics["reload_dungeon_logical_connector_root_present"] = inst.get_node_or_null("DungeonLogicalConnectorProxies") != null
	metrics["reload_mesh_nodes"] = _count_mesh_instances(inst)
	metrics["reload_collision_static_bodies"] = _count_static_bodies(inst)
	metrics["reload_collision_shape_nodes"] = _count_collision_shapes(inst)
	metrics["reload_generated_scene_type_meta"] = str((inst as Node).get_meta("daoc_generated_scene_type", ""))
	result.set("metrics", metrics)
	var required_roots_ok: bool = branch_names.has("DungeonChunkInstances")
	result.set("reload_ok", required_roots_ok and str(inst.name) == expected_root_name)
	inst.free()


func _normalize_zone_ids_c2(zone_ids: Array, max_batch_zones: int = 0) -> Array:
	var out: Array = []
	for raw_zone in zone_ids:
		var znum: int = int(raw_zone)
		if znum < 0 or out.has(znum):
			continue
		out.append(znum)
		if max_batch_zones > 0 and out.size() >= max_batch_zones:
			break
	return out


func _resolve_batch_zone_list(host: Node, options: Dictionary) -> Array[int]:
	var resolved: Array[int] = []
	var raw_zones: Variant = options.get("zones", null)
	_append_zone_list_from_variant(resolved, raw_zones)
	if resolved.is_empty() and host != null:
		var host_zones: Variant = host.get("zones")
		_append_zone_list_from_variant(resolved, host_zones)
	if resolved.is_empty():
		resolved.append(0)
	return resolved


func _append_zone_list_from_variant(out_zones: Array[int], raw_value: Variant) -> void:
	if typeof(raw_value) == TYPE_PACKED_INT32_ARRAY:
		var packed: PackedInt32Array = raw_value as PackedInt32Array
		for znum in packed:
			var zi: int = int(znum)
			if not out_zones.has(zi):
				out_zones.append(zi)
	elif typeof(raw_value) == TYPE_ARRAY:
		var arr: Array = raw_value as Array
		for znum in arr:
			var zi: int = int(znum)
			if not out_zones.has(zi):
				out_zones.append(zi)
	elif typeof(raw_value) == TYPE_INT:
		var zi: int = int(raw_value)
		if not out_zones.has(zi):
			out_zones.append(zi)


func _default_scene_path(znum: int) -> String:
	return "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [znum, znum]
