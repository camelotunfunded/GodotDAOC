extends RefCounted
class_name DaocZoneSceneAssembler

## P1-15B — ZoneSceneAssembler foundation.
##
## This is deliberately conservative: it moves the per-zone assembly order out of
## ZoneViewer, but still calls the existing ZoneViewer domain wrappers. The
## domain builders/runtimes validated in 14A→14E remain the source of truth.

const BUILD_ORDER = [
	"terrain_14e",
	"collision_14c_boundary",
	"zonejump_14a",
	"water_14b",
	"legacy_lights",
	"legacy_vegetation",
	"props_14d",
]

var _results_by_zone: Dictionary = {}
var _last_result: Dictionary = {}


func build_zone(host: Node, znum: int) -> Dictionary:
	var plan := _prepare_zone(host, znum)
	var result: Dictionary = plan["result"]
	if not bool(plan.get("ready", false)):
		return result
	for step in plan["steps"] as Array:
		(step as Callable).call()
	return _finish_zone(host, znum, plan)


## 2026-09-27 (optimisation) — même construction, ÉTALÉE : le préchargement
## d une zone voisine figeait le jeu ~4,5 s (P1-33). Le terrain, les frontières
## et les zonejumps partent dans la première image (la zone est praticable tout
## de suite), puis une étape par image. À appeler avec `await`.
func build_zone_spread(host: Node, znum: int) -> Dictionary:
	var plan := _prepare_zone(host, znum)
	var result: Dictionary = plan["result"]
	if not bool(plan.get("ready", false)):
		return result
	var steps := plan["steps"] as Array
	for index in steps.size():
		(steps[index] as Callable).call()
		if index >= 2 and index < steps.size() - 1 and host.is_inside_tree():
			await host.get_tree().process_frame
	return _finish_zone(host, znum, plan)


func _finish_zone(host: Node, znum: int, plan: Dictionary) -> Dictionary:
	var result: Dictionary = plan["result"]
	var meta: Dictionary = plan["meta"]
	var hud_zones := str(host.get("_hud_zones"))
	var uses_splat := bool(host.call("_terrain_14e_zone_uses_splat", znum))
	hud_zones += "  zone%d (%s)%s" % [znum, str(meta.get("zone", znum)), " [splat]" if uses_splat else ""]
	host.set("_hud_zones", hud_zones)

	result["ok"] = _steps_all_ok(result.get("steps", []) as Array)
	_remember(znum, result)
	return result


func _prepare_zone(host: Node, znum: int) -> Dictionary:
	var result := {
		"scope": "P1-15B ZoneSceneAssembler foundation",
		"ok": false,
		"zone": znum,
		"meta_path": "",
		"heightmap_path": "",
		"resolution": 0,
		"origin3": Vector3.ZERO,
		"build_order": BUILD_ORDER.duplicate(),
		"steps": [],
		"error": "",
	}
	var failed := {"result": result, "ready": false}
	if host == null:
		result["error"] = "host is null"
		_remember(znum, result)
		return failed

	var meta_path := _asset_data_path(host, "zone%03d.json" % znum)
	result["meta_path"] = meta_path
	var mf := FileAccess.open(meta_path, FileAccess.READ)
	if mf == null:
		result["error"] = "missing %s" % meta_path
		_remember(znum, result)
		return failed

	var meta_variant: Variant = JSON.parse_string(mf.get_as_text())
	mf.close()
	if typeof(meta_variant) != TYPE_DICTIONARY:
		result["error"] = "bad zone metadata %s" % meta_path
		_remember(znum, result)
		return failed
	var meta: Dictionary = meta_variant as Dictionary
	var res := int(meta.get("resolution", 256))
	result["resolution"] = res

	var heightmap_path := _asset_data_path(host, str(meta.get("heightmap", "")))
	result["heightmap_path"] = heightmap_path
	var hf := FileAccess.open(heightmap_path, FileAccess.READ)
	if hf == null:
		result["error"] = "missing heightmap %s" % heightmap_path
		_remember(znum, result)
		return failed
	var hb := hf.get_buffer(hf.get_length())
	hf.close()

	host.call("_get_zone_root", znum)

	# Runtime gameplay data used by the player capsule and downstream builders.
	# P1-15B keeps the 14E legacy mirror intact; TerrainRuntime remains the sampler authority.
	var origin2: Vector2 = host.call("_origin", znum) as Vector2
	var base2: Vector2 = host.get("_base") as Vector2
	var off_rt := origin2 - base2
	var ws := float(host.get("world_scale"))
	var origin3_rt := Vector3(off_rt.x * ws, 0.0, off_rt.y * ws)
	result["origin3"] = origin3_rt
	var zone_runtime: Dictionary = host.get("_zone_runtime") as Dictionary
	zone_runtime[znum] = {"origin3": origin3_rt, "hb": hb, "res": res}
	host.set("_zone_runtime", zone_runtime)
	host.call("_ensure_terrain_runtime_14e")

	var steps: Array[Callable] = [
		func() -> void: _run_zone_step(host, result, "terrain_14e", "terrain", "_setup_terrain_builder_for_zone",
			[znum, meta, hb, res, origin3_rt, meta_path], func(services: DaocZoneBuildServices) -> void:
				DaocZoneTerrainStep.build(services, znum, meta, hb, res, origin3_rt, meta_path,
					services.step_settings("terrain"), services.step_logging("terrain"))),
		func() -> void: _run_zone_step(host, result, "collision_14c_boundary", "collisions",
			"_setup_collision_boundary_builder_for_zone",
			[znum, origin3_rt], func(services: DaocZoneBuildServices) -> void:
				DaocZoneCollisionStep.build(services, znum, origin3_rt,
					services.step_settings("collisions"), services.step_logging("collisions"))),
		func() -> void: _run_zone_step(host, result, "zonejump_14a", "zonejumps", "_setup_zonejump_builder_for_zone",
			[znum, origin3_rt], func(services: DaocZoneBuildServices) -> void:
				DaocZoneJumpStep.build(services, znum, origin3_rt,
					services.step_settings("zonejumps"), services.step_logging("zonejumps"))),
		func() -> void: _run_zone_step(host, result, "water_14b", "water", "_setup_water_builder_for_zone",
			[znum, origin3_rt], func(services: DaocZoneBuildServices) -> void:
				DaocZoneWaterStep.build(services, znum, origin3_rt,
					services.step_settings("water"), services.step_logging("water"))),
		func() -> void: _run_zone_step(host, result, "legacy_lights", "lights", "_setup_visual_stage_lamps_15c",
			[znum, origin3_rt], func(services: DaocZoneBuildServices) -> void:
				DaocZoneLightsStep.build(services, znum, origin3_rt,
					services.step_settings("lights"), services.step_logging("lights"))),
		func() -> void: _run_zone_step(host, result, "legacy_vegetation", "vegetation", "_setup_visual_stage_cards_15c",
			[znum, origin3_rt, hb, res], func(services: DaocZoneBuildServices) -> void:
				DaocZoneVegetationStep.build(services, znum, origin3_rt, hb, res,
					services.step_settings("vegetation"), services.step_logging("vegetation"))),
		func() -> void: _run_zone_step(host, result, "props_14d", "props", "_setup_prop_builder_for_zone",
			[meta, origin3_rt, hb, res], func(services: DaocZoneBuildServices) -> void:
				DaocZonePropsStep.build(services, meta, origin3_rt, hb, res,
					services.step_settings("props"), services.step_logging("props"))),
	]
	return {"result": result, "ready": true, "meta": meta, "steps": steps}


func status() -> Dictionary:
	return {
		"scope": "P1-15B ZoneSceneAssembler foundation",
		"zones": _results_by_zone.keys(),
		"result_count": _results_by_zone.size(),
		"build_order": BUILD_ORDER.duplicate(),
		"last": _last_result,
	}


func result_for_zone(znum: int) -> Dictionary:
	return _results_by_zone.get(znum, {}) as Dictionary


func _asset_data_path(host: Node, file_name: String) -> String:
	if host != null and host.has_method("get_asset_index_registry_15d"):
		var reg_obj: Object = host.call("get_asset_index_registry_15d") as Object
		if reg_obj != null and reg_obj.has_method("data_path"):
			return str(reg_obj.call("data_path", file_name))
	# Compatibility fallback for pre-15D local bases only.
	if host != null and host.has_method("_asset_data_15d"):
		return str(host.call("_asset_data_15d", file_name))
	if host != null and host.has_method("_data_path"):
		return str(host.call("_data_path", file_name))
	return file_name


## R4 — pilote une etape, par l'objet quand elle a bascule, par l'ancien rappel
## sinon.
##
## C'est ICI que la reconstruction se voit : une etape migree n'appelle plus le
## ZoneViewer par le nom d'une methode de construction. L'assembleur ne lui
## demande que ses reglages, en donnees, et lance l'objet. Une etape decochee
## dans l'inspecteur n'est pas lancee du tout et le rapport le dit.
##
## Tant que les six autres etapes ne sont pas migrees, elles passent par le
## chemin d'origine, inchange : R4 avance par tranches, sans big-bang.
func _run_zone_step(host: Node, result: Dictionary, step_name: String, step_key: String,
		method_name: String, args: Array, runner: Callable) -> void:
	if not _step_migrated(host, step_key):
		_call_zone_step(host, result, step_name, method_name, args)
		return

	var started_usec := Time.get_ticks_usec()
	var step := {"name": step_name, "method": "DaocZoneBuildStep(%s)" % step_key,
		"ok": false, "error": ""}
	var services: DaocZoneBuildServices = host.call("zone_build_services_r4")
	if services == null or not services.usable():
		step["error"] = "services de zone indisponibles"
	elif not services.step_enabled(step_key):
		step["ok"] = true
		step["skipped"] = "etape decochee dans l'inspecteur"
	else:
		runner.call(services)
		step["ok"] = true
	step["ms"] = float(Time.get_ticks_usec() - started_usec) / 1000.0

	var steps: Array = result.get("steps", []) as Array
	steps.append(step)
	result["steps"] = steps


func _step_migrated(host: Node, step_key: String) -> bool:
	return host != null and host.has_method("zone_step_migrated_r4") \
		and bool(host.call("zone_step_migrated_r4", step_key))


func _call_zone_step(host: Node, result: Dictionary, step_name: String, method_name: String, args: Array) -> void:
	var step := {
		"name": step_name,
		"method": method_name,
		"ok": false,
		"error": "",
	}
	if not host.has_method(method_name):
		step["error"] = "missing host method"
		var missing_steps: Array = result.get("steps", []) as Array
		missing_steps.append(step)
		result["steps"] = missing_steps
		return
	var started_usec := Time.get_ticks_usec()
	host.callv(method_name, args)
	step["ok"] = true
	step["ms"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var steps: Array = result.get("steps", []) as Array
	steps.append(step)
	result["steps"] = steps


func _steps_all_ok(steps: Array) -> bool:
	if steps.is_empty():
		return false
	for raw in steps:
		var step: Dictionary = raw as Dictionary
		if not bool(step.get("ok", false)):
			return false
	return true


func _remember(znum: int, result: Dictionary) -> void:
	_results_by_zone[znum] = result
	_last_result = result
