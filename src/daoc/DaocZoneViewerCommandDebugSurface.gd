extends RefCounted
class_name DaocZoneViewerCommandDebugSurface

## P1-15F — surface commandes/debug ZoneViewer.
## Ce module sort de ZoneViewer la logique de commande/debug zonejump et la
## transition locale gardée P1-N6G. Il ne construit aucune géométrie et ne
## modifie pas les builders 14A/14B/14C/14D/14E.

var _host: Node = null
var _state: RefCounted = null


func configure(host: Node, state_registry: RefCounted) -> void:
	_host = host
	_state = state_registry


func debug_snapshot() -> Dictionary:
	var audit: Dictionary = {}
	if _host != null and _host.has_method("get_zoneviewer_p1_15a_audit_snapshot"):
		audit = _host.call("get_zoneviewer_p1_15a_audit_snapshot") as Dictionary
	var domains: Dictionary = audit.get("domains", {}) as Dictionary
	return {
		"scope": "P1-15F ZoneViewer command/debug surface extraction",
		"checkpoint": "D_COMMAND_DEBUG_SURFACE",
		"configured": _host != null and _state != null,
		"command_debug_surface_present": true,
		"audit": audit,
		"line_count": int(audit.get("line_count", 0)),
		"function_count": int(audit.get("function_count", 0)),
		"var_count": int(audit.get("var_count", 0)),
		"zonejump_runtime_debug_residue": int(domains.get("zonejump_runtime_debug", 999)),
		"asset_index_residue": int(domains.get("asset_model_texture_index", 999)),
		"vegetation_legacy_residue": int(domains.get("vegetation_legacy", 999)),
		"legacy_lights_residue": int(domains.get("legacy_lights", 999)),
		"commands": ["/zonejump status", "/zonejump last", "/zonejump log", "/zonejump nearest", "/zonejump transition", "/zonejump go nearest", "/zonejump go <id>", "/zonejump auto on|off|status"],
		"event_log_size": _array("zonejump_event_log").size(),
		"transition_log_size": _array("zonejump_transition_log").size(),
		"last_event_present": not _dict("last_zonejump_debug").is_empty(),
		"last_transition_present": not _dict("last_zonejump_transition_result").is_empty(),
		"recommended_next_step": "P1-15G Viewer shell final / bootstrap cleanup",
	}


func on_zonejump_runtime_body_entered(body: Node, data: Dictionary) -> void:
	if _player() == null or body != _player():
		return
	var key := "%s:%s" % [str(data.get("zone", -1)), str(data.get("id", -1))]
	var now := Time.get_ticks_msec()
	var last_enter := _dict("zonejump_last_enter_msec")
	var last := int(last_enter.get(key, -1000000))
	if now - last < 900:
		return
	last_enter[key] = now
	var target := int(data.get("target", -1))
	var decorated := _decorate_runtime_event(data, "entered", now)
	_set_state_value("last_zonejump_debug", decorated)
	_append_event(decorated)
	if target < 0:
		if _b("log_zonejump", true):
			print("zonejump entered id=%s name=%s target=empty -> ignored" % [str(decorated.get("id", "?")), str(decorated.get("name", ""))])
		return
	if _b("zonejump_auto_transition_enabled", false) and _b("zonejump_direct_transition_enabled", true):
		_request_zone_change_now(target, decorated, "area_enter_auto")
	else:
		_request_zone_change_stub(target, decorated)


func on_zonejump_runtime_body_exited(body: Node, data: Dictionary) -> void:
	if _player() == null or body != _player():
		return
	var event_data: Dictionary = _decorate_runtime_event(data, "exited", Time.get_ticks_msec())
	_append_event(event_data)
	if _b("log_zonejump", true):
		print("zonejump exited id=%s name=%s target=%s" % [str(event_data.get("id", "?")), str(event_data.get("name", "")), str(event_data.get("target", ""))])


func set_zonejump_auto_transition_enabled(enabled: bool) -> Dictionary:
	if _host != null:
		_host.set("zonejump_auto_transition_enabled", enabled)
	return {
		"ok": true,
		"scope": "P1-N6G zonejump direct guarded local transition",
		"auto_transition_enabled": _b("zonejump_auto_transition_enabled", false),
		"direct_transition_enabled": _b("zonejump_direct_transition_enabled", true),
	}


func execute_zonejump_nearest_transition(radius_raw: float = -1.0, reason: String = "command_nearest") -> Dictionary:
	if radius_raw <= 0.0:
		radius_raw = _f("zonejump_nearest_go_radius_raw", 2400.0)
	var near: Dictionary = _resolve_nearest_transition_entry(radius_raw)
	if not bool(near.get("ok", false)):
		var fail: Dictionary = {
			"ok": false,
			"scope": "P1-N6G zonejump direct guarded local transition",
			"reason": str(near.get("reason", "nearest not found")),
			"radius_raw": radius_raw,
			"entry_count": int(near.get("entry_count", 0)),
		}
		_set_state_value("last_zonejump_transition_result", fail)
		_append_transition_result(fail)
		return fail
	var entry: Dictionary = near.get("entry", {}) as Dictionary
	var event_data: Dictionary = _make_event_dictionary_from_entry("command_nearest", int(near.get("zone", -1)), entry, Time.get_ticks_msec())
	event_data["distance_raw"] = float(near.get("distance_raw", -1.0))
	_set_state_value("last_zonejump_debug", event_data)
	_append_event(event_data)
	return _request_zone_change_now(int(entry.get("target", -1)), event_data, reason)


func execute_zonejump_transition_by_id(jump_id: int, source_zone: int = -1, reason: String = "command_id") -> Dictionary:
	if _player() == null and source_zone < 0:
		return {"ok": false, "scope": "P1-N6G zonejump direct guarded local transition", "reason": "player missing"}
	var znum := source_zone
	if znum < 0:
		znum = int(_player().get("daoc_zone"))
	var entries: Array = _dict("zonejump_entries_by_zone").get(znum, []) as Array
	for item in entries:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("id", -1)) != jump_id:
			continue
		if int(entry.get("target", -1)) < 0:
			return {"ok": false, "scope": "P1-N6G zonejump direct guarded local transition", "reason": "zonejump has no target", "id": jump_id, "zone": znum}
		var event_data: Dictionary = _make_event_dictionary_from_entry("command_id", znum, entry, Time.get_ticks_msec())
		_set_state_value("last_zonejump_debug", event_data)
		_append_event(event_data)
		return _request_zone_change_now(int(entry.get("target", -1)), event_data, reason)
	return {"ok": false, "scope": "P1-N6G zonejump direct guarded local transition", "reason": "zonejump id not found", "id": jump_id, "zone": znum, "entry_count": entries.size()}


func execute_zonejump_transition_to_target(target: int, source_event: Dictionary, reason: String = "manual") -> Dictionary:
	var before: Dictionary = _capture_player_state("before")
	var result: Dictionary = {
		"ok": false,
		"scope": "P1-N6G zonejump direct guarded local transition",
		"reason": reason,
		"target": target,
		"source_zone": int(source_event.get("zone", -1)),
		"source_id": int(source_event.get("id", -1)),
		"auto_transition_enabled": _b("zonejump_auto_transition_enabled", false),
		"direct_transition_enabled": _b("zonejump_direct_transition_enabled", true),
		"before": before,
	}
	if not _b("zonejump_direct_transition_enabled", true):
		result["reason"] = "direct transition disabled"
		return result
	if _player() == null:
		result["reason"] = "player missing"
		return result
	if target < 0:
		result["reason"] = "target missing"
		return result
	var ensure: Dictionary = _ensure_zone_loaded(target)
	result["ensure"] = ensure
	if not bool(ensure.get("ok", false)):
		result["reason"] = str(ensure.get("reason", "target zone unavailable"))
		return result
	var spawn: Dictionary = _resolve_target_spawn(target, source_event)
	result["spawn"] = spawn
	if not bool(spawn.get("ok", false)):
		result["reason"] = str(spawn.get("reason", "spawn invalid"))
		return result
	var applied: Dictionary = _apply_player_position(target, float(spawn.get("x", 32768.0)), float(spawn.get("y", 32768.0)), float(spawn.get("z", 0.0)), float(spawn.get("heading_deg", 0.0)))
	result["after"] = applied
	if not bool(applied.get("ok", false)):
		result["reason"] = str(applied.get("reason", "apply failed"))
		_restore_player_state(before, "rollback_apply_failed")
		result["rollback"] = _capture_player_state("after_rollback")
		return result
	result["ok"] = true
	result["reason"] = "transition applied"
	result["rollback_available"] = bool(before.get("ok", false))
	return result


func get_zonejump_transition_debug_snapshot() -> Dictionary:
	var transition_log := _array("zonejump_transition_log")
	return {
		"scope": "P1-N6G zonejump direct guarded local transition",
		"direct_transition_enabled": _b("zonejump_direct_transition_enabled", true),
		"auto_transition_enabled": _b("zonejump_auto_transition_enabled", false),
		"load_missing_target_zone": _b("zonejump_load_missing_target_zone", true),
		"last_transition": _dict("last_zonejump_transition_result"),
		"transition_log_size": transition_log.size(),
		"transition_log_tail": transition_log.slice(maxi(0, transition_log.size() - 6), transition_log.size()),
		"commands": ["/zonejump go nearest", "/zonejump go <id>", "/zonejump auto on", "/zonejump auto off"],
	}


func get_zonejump_transition_lines(max_events: int = 4) -> PackedStringArray:
	var lines := PackedStringArray()
	var transition_log := _array("zonejump_transition_log")
	var last_transition := _dict("last_zonejump_transition_result")
	lines.append("P1-N6G zonejump direct guarded local transition")
	lines.append("direct=%s auto=%s load_missing=%s" % [str(_b("zonejump_direct_transition_enabled", true)), str(_b("zonejump_auto_transition_enabled", false)), str(_b("zonejump_load_missing_target_zone", true))])
	if last_transition.is_empty():
		lines.append("last_transition=none")
	else:
		lines.append("last_transition ok=%s target=%s reason=%s" % [str(last_transition.get("ok", false)), str(last_transition.get("target", "")), str(last_transition.get("reason", ""))])
	var start := maxi(0, transition_log.size() - maxi(0, max_events))
	for i in range(start, transition_log.size()):
		var item: Dictionary = transition_log[i] as Dictionary
		lines.append("transition[%d] ok=%s target=%s reason=%s" % [i, str(item.get("ok", false)), str(item.get("target", "")), str(item.get("reason", ""))])
	return lines


func get_zonejump_interaction_debug_snapshot() -> Dictionary:
	var totals: Dictionary = _totals()
	return {
		"scope": "P1-N6F/P1-N6G zonejump debug/direct transition",
		"enabled": _b("build_zonejump_debug", true),
		"area_enabled": _b("zonejump_area_enabled", true),
		"area_count": _area_count(),
		"zones_with_entries": int(totals.get("zones_with_entries", 0)),
		"entries_total": int(totals.get("entries_total", 0)),
		"targets_total": int(totals.get("targets_total", 0)),
		"event_log_size": _array("zonejump_event_log").size(),
		"event_log_limit": _i("zonejump_event_log_limit", 24),
		"last_event": _dict("last_zonejump_debug"),
		"last_transition_stub": _dict("last_zonejump_transition_stub"),
		"last_transition_result": _dict("last_zonejump_transition_result"),
		"auto_transition_enabled": _b("zonejump_auto_transition_enabled", false),
		"direct_transition_enabled": _b("zonejump_direct_transition_enabled", true),
		"transition_allowed": _b("zonejump_direct_transition_enabled", true),
		"transition_stage": "P1-N6G local direct guarded transition",
		"commands": ["/zonejump status", "/zonejump last", "/zonejump log", "/zonejump nearest", "/zonejump go nearest", "/zonejump go <id>", "/zonejump auto on|off"],
	}


func get_zonejump_status_lines(max_events: int = 4) -> PackedStringArray:
	var totals: Dictionary = _totals()
	var event_log := _array("zonejump_event_log")
	var last_debug := _dict("last_zonejump_debug")
	var last_stub := _dict("last_zonejump_transition_stub")
	var last_result := _dict("last_zonejump_transition_result")
	var lines := PackedStringArray()
	lines.append("P1-N6F/N6G zonejump debug + direct guarded transition")
	lines.append("enabled=%s areas=%d zones=%d entries=%d targets=%d auto_transition=%s direct=%s" % [
		str(_b("build_zonejump_debug", true)),
		_area_count(),
		int(totals.get("zones_with_entries", 0)),
		int(totals.get("entries_total", 0)),
		int(totals.get("targets_total", 0)),
		str(_b("zonejump_auto_transition_enabled", false)),
		str(_b("zonejump_direct_transition_enabled", true)),
	])
	if last_debug.is_empty():
		lines.append("last=none")
	else:
		lines.append("last %s" % _event_debug_line(last_debug))
	if not last_stub.is_empty():
		lines.append("transition_request target=%03d deferred=%s reason=%s" % [
			int(last_stub.get("target", -1)),
			str(last_stub.get("deferred", true)),
			str(last_stub.get("reason", "")),
		])
	if not last_result.is_empty():
		lines.append("transition_result ok=%s target=%s reason=%s" % [
			str(last_result.get("ok", false)),
			str(last_result.get("target", "")),
			str(last_result.get("reason", "")),
		])
	var start := maxi(0, event_log.size() - maxi(0, max_events))
	for i in range(start, event_log.size()):
		var event_data: Dictionary = event_log[i] as Dictionary
		lines.append("log[%d] %s" % [i, _event_debug_line(event_data)])
	return lines


func get_zonejump_last_event_lines() -> PackedStringArray:
	var last_debug := _dict("last_zonejump_debug")
	var last_stub := _dict("last_zonejump_transition_stub")
	var last_result := _dict("last_zonejump_transition_result")
	var lines := PackedStringArray()
	lines.append("P1-N6F/N6G zonejump last")
	if last_debug.is_empty():
		lines.append("last=none")
	else:
		lines.append(_event_debug_line(last_debug))
	if last_stub.is_empty():
		lines.append("transition_request=none")
	else:
		lines.append("transition_request target=%03d deferred=%s allowed=%s" % [
			int(last_stub.get("target", -1)),
			str(last_stub.get("deferred", true)),
			str(last_stub.get("transition_allowed", false)),
		])
	if last_result.is_empty():
		lines.append("transition_result=none")
	else:
		lines.append("transition_result ok=%s target=%s reason=%s" % [
			str(last_result.get("ok", false)),
			str(last_result.get("target", "")),
			str(last_result.get("reason", "")),
		])
	return lines


func get_zonejump_nearest_debug_snapshot(radius_raw: float = 1600.0) -> Dictionary:
	if _player() == null:
		return {"ok": false, "reason": "player missing"}
	var pzone := int(_player().get("daoc_zone"))
	var pp := Vector2(float(_player().get("daoc_x")), float(_player().get("daoc_y")))
	var runtime: RefCounted = _state_value("zonejump_runtime") as RefCounted
	if runtime == null or not runtime.has_method("nearest_daoc"):
		return {"ok": false, "reason": "zonejump runtime missing", "zone": pzone}
	var near: Dictionary = runtime.call("nearest_daoc", pzone, pp) as Dictionary
	if not bool(near.get("ok", false)):
		near["radius_raw"] = radius_raw
		return near
	var dist := float(near.get("distance_raw", INF))
	if dist > radius_raw:
		return {
			"ok": false,
			"reason": "none within radius",
			"zone": pzone,
			"radius_raw": radius_raw,
			"entry_count": int(near.get("entry_count", 0)),
		}
	return {
		"ok": true,
		"zone": pzone,
		"id": int(near.get("id", -1)),
		"name": str(near.get("name", "")),
		"target": int(near.get("target", near.get("target_zone", -1))),
		"distance_raw": dist,
		"radius_raw": radius_raw,
		"extra1": str(near.get("extra1", "")),
		"extra2": str(near.get("extra2", "")),
		"transition_deferred": not _b("zonejump_direct_transition_enabled", true),
		"transition_allowed": _b("zonejump_direct_transition_enabled", true),
	}


func _decorate_runtime_event(data: Dictionary, event_name: String, msec: int) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var heading := 0.0
	if _player() != null:
		heading = float(_player().get("heading_deg"))
	out["scope"] = "P1-N6F/P1-N6G zonejump debug/direct transition via P1-14A runtime"
	out["event"] = event_name
	out["msec"] = msec
	out["zone"] = int(out.get("zone", out.get("source_zone", -1)))
	out["target"] = int(out.get("target", out.get("target_zone", -1)))
	out["raw_a"] = out.get("raw_a", out.get("a", Vector2.ZERO))
	out["raw_b"] = out.get("raw_b", out.get("b", Vector2.ZERO))
	out["player_heading_deg"] = heading
	out["transition_deferred"] = not _b("zonejump_auto_transition_enabled", false)
	out["transition_allowed"] = _b("zonejump_direct_transition_enabled", true)
	out["rule_status"] = "DÉCISION"
	out["decision"] = "P1-N6G peut faire un changement local direct gardé; auto reste OFF par défaut. P1-14A déplace la couture build/runtime hors ZoneViewer. P1-15F sort la surface commandes/debug."
	return out


func _append_event(data: Dictionary) -> void:
	var event_log := _array("zonejump_event_log")
	event_log.append(data.duplicate(true))
	var limit := maxi(1, _i("zonejump_event_log_limit", 24))
	while event_log.size() > limit:
		event_log.pop_front()


func _append_transition_result(result: Dictionary) -> void:
	var transition_log := _array("zonejump_transition_log")
	transition_log.append(result.duplicate(true))
	var limit := maxi(1, _i("zonejump_transition_log_limit", 16))
	while transition_log.size() > limit:
		transition_log.pop_front()


func _request_zone_change_stub(target: int, data: Dictionary) -> void:
	var stub := {
		"scope": "P1-N6G zonejump transition guarded request",
		"requested": true,
		"target": target,
		"source_zone": int(data.get("zone", -1)),
		"source_id": int(data.get("id", -1)),
		"source_name": str(data.get("name", "")),
		"deferred": true,
		"transition_allowed": _b("zonejump_direct_transition_enabled", true),
		"auto_transition_enabled": _b("zonejump_auto_transition_enabled", false),
		"reason": "auto transition OFF; use /zonejump go nearest, /zonejump go <id>, or /zonejump auto on.",
	}
	_set_state_value("last_zonejump_transition_stub", stub)
	if _b("log_zonejump", true):
		print("zonejump transition ready: zone%03d id=%s -> target=%03d auto=%s" % [int(data.get("zone", -1)), str(data.get("id", "?")), target, str(_b("zonejump_auto_transition_enabled", false))])


func _request_zone_change_now(target: int, data: Dictionary, reason: String) -> Dictionary:
	var result: Dictionary = execute_zonejump_transition_to_target(target, data, reason)
	_set_state_value("last_zonejump_transition_result", result)
	_append_transition_result(result)
	if _b("log_zonejump", true):
		print("zonejump direct result ok=%s target=%03d reason=%s" % [str(result.get("ok", false)), target, str(result.get("reason", ""))])
	return result


func _ensure_zone_loaded(znum: int) -> Dictionary:
	if _dict("zone_runtime").has(znum):
		return {"ok": true, "zone": znum, "already_loaded": true, "built_now": false}
	if not _b("zonejump_load_missing_target_zone", true):
		return {"ok": false, "zone": znum, "reason": "target zone not loaded and on-demand load disabled"}
	var meta_path := ""
	if _host != null and _host.has_method("_asset_data_15d"):
		meta_path = str(_host.call("_asset_data_15d", "zone%03d.json" % znum))
	if meta_path == "" or not FileAccess.file_exists(meta_path):
		return {"ok": false, "zone": znum, "reason": "target zone json missing", "path": meta_path}
	var origin := Vector2.ZERO
	if _host != null and _host.has_method("_origin"):
		origin = _host.call("_origin", znum) as Vector2
	var base := Vector2.ZERO
	if _host != null:
		base = _host.get("_base") as Vector2
	if _dict("zone_runtime").size() > 0 and (origin.x < base.x or origin.y < base.y):
		return {"ok": false, "zone": znum, "reason": "target origin would require base rebuild", "origin": origin, "base": base}
	if _host != null and _host.has_method("_append_zone_to_active_list"):
		_host.call("_append_zone_to_active_list", znum)
	if _host != null and _host.has_method("_build_zone"):
		_host.call("_build_zone", znum)
	return {"ok": _dict("zone_runtime").has(znum), "zone": znum, "already_loaded": false, "built_now": _dict("zone_runtime").has(znum), "path": meta_path}


func _capture_player_state(label: String) -> Dictionary:
	if _player() == null:
		return {"ok": false, "label": label, "reason": "player missing"}
	return {
		"ok": true,
		"label": label,
		"zone": int(_player().get("daoc_zone")),
		"x": float(_player().get("daoc_x")),
		"y": float(_player().get("daoc_y")),
		"z": float(_player().get("daoc_z")),
		"heading_deg": float(_player().get("heading_deg")),
		"msec": Time.get_ticks_msec(),
	}


func _restore_player_state(state: Dictionary, _reason: String) -> Dictionary:
	if not bool(state.get("ok", false)):
		return {"ok": false, "reason": "restore state invalid"}
	return _apply_player_position(int(state.get("zone", 0)), float(state.get("x", 32768.0)), float(state.get("y", 32768.0)), float(state.get("z", 0.0)), float(state.get("heading_deg", 0.0)))


func _apply_player_position(znum: int, x: float, y: float, z: float, heading_deg: float) -> Dictionary:
	if _player() == null:
		return {"ok": false, "reason": "player missing"}
	if not _dict("zone_runtime").has(znum):
		return {"ok": false, "reason": "target zone runtime missing", "zone": znum}
	_player().set("daoc_zone", znum)
	_player().set("daoc_x", clampf(x, 0.0, 65536.0))
	_player().set("daoc_y", clampf(y, 0.0, 65536.0))
	_player().set("daoc_z", z)
	_player().set("heading_deg", heading_deg)
	_player().set("vertical_velocity_raw", 0.0)
	_player().set("on_ground", true)
	_player().set("climb_flag_local_placeholder", false)
	_player().set("movement_state", 0)
	if _player().has_method("_apply_daoc_transform"):
		_player().call("_apply_daoc_transform")
	elif _host != null and _host.has_method("daoc_to_godot"):
		var p3: Vector3 = _host.call("daoc_to_godot", znum, x, y, z) as Vector3
		_player().set("global_position", p3)
		_player().set("rotation_degrees", Vector3(0.0, -heading_deg, 0.0))
	return _capture_player_state("after")


func _resolve_target_spawn(target: int, source_event: Dictionary) -> Dictionary:
	var source_zone := int(source_event.get("zone", -1))
	var counterpart: Dictionary = _find_counterpart_entry(target, source_zone)
	var candidates: Array[Dictionary] = []
	if not counterpart.is_empty():
		var a: Vector2 = counterpart.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = counterpart.get("b", Vector2.ZERO) as Vector2
		var mid: Vector2 = (a + b) * 0.5
		var d: Vector2 = b - a
		var normal: Vector2 = Vector2(0.0, 1.0)
		if d.length() > 1.0:
			normal = Vector2(-d.y, d.x).normalized()
		var offsets: Array[float] = [_f("zonejump_spawn_offset_raw", 900.0), -_f("zonejump_spawn_offset_raw", 900.0), _f("zonejump_spawn_offset_raw", 900.0) * 1.75, -_f("zonejump_spawn_offset_raw", 900.0) * 1.75, 0.0]
		for offset in offsets:
			var p: Vector2 = mid + normal * offset
			candidates.append({"x": p.x, "y": p.y, "basis": "counterpart", "counterpart_id": int(counterpart.get("id", -1)), "offset": offset})
	candidates.append({"x": 32768.0, "y": 32768.0, "basis": "target_center"})
	for candidate_var in candidates:
		var c: Dictionary = candidate_var as Dictionary
		var valid: Dictionary = _validate_spawn_candidate(target, float(c.get("x", 32768.0)), float(c.get("y", 32768.0)))
		if bool(valid.get("ok", false)):
			valid["basis"] = str(c.get("basis", ""))
			valid["counterpart_id"] = int(c.get("counterpart_id", -1))
			valid["heading_deg"] = float(_player().get("heading_deg")) if _player() != null else 0.0
			return valid
	return {"ok": false, "reason": "no safe spawn candidate", "target": target, "candidate_count": candidates.size(), "counterpart_found": not counterpart.is_empty()}


func _find_counterpart_entry(target_zone: int, source_zone: int) -> Dictionary:
	var entries: Array = _dict("zonejump_entries_by_zone").get(target_zone, []) as Array
	for item in entries:
		var d: Dictionary = item as Dictionary
		if int(d.get("target", -1)) == source_zone:
			return d
	return {}


func _validate_spawn_candidate(znum: int, x: float, y: float) -> Dictionary:
	if x < 256.0 or y < 256.0 or x > 65280.0 or y > 65280.0:
		return {"ok": false, "reason": "candidate outside safe zone bounds", "x": x, "y": y}
	if _host != null and _host.has_method("_point_near_boundary_2d") and bool(_host.call("_point_near_boundary_2d", znum, Vector2(x, y), 160.0)):
		return {"ok": false, "reason": "candidate too near boundary", "x": x, "y": y}
	var floor_z := 0.0
	if _host != null and _host.has_method("sample_daoc_floor_z"):
		floor_z = float(_host.call("sample_daoc_floor_z", znum, x, y, 0.0))
	if floor_z != floor_z or absf(floor_z) > 10000000.0:
		return {"ok": false, "reason": "floor not finite", "x": x, "y": y}
	var z: float = floor_z + _f("zonejump_spawn_z_offset_raw", 3.0)
	if _host != null and _host.has_method("_collision_14c_is_prop_position_blocked") and bool(_host.call("_collision_14c_is_prop_position_blocked", znum, Vector2(x, y), z, 48.0, 136.0)):
		return {"ok": false, "reason": "candidate blocked by prop", "x": x, "y": y, "z": z}
	return {"ok": true, "zone": znum, "x": x, "y": y, "z": z, "floor_z": floor_z}


func _make_event_dictionary_from_entry(event_name: String, znum: int, entry: Dictionary, msec: int) -> Dictionary:
	var raw_a: Vector2 = entry.get("a", Vector2.ZERO) as Vector2
	var raw_b: Vector2 = entry.get("b", Vector2.ZERO) as Vector2
	return {
		"scope": "P1-N6G zonejump direct guarded local transition",
		"event": event_name,
		"msec": msec,
		"zone": znum,
		"id": int(entry.get("id", -1)),
		"name": str(entry.get("name", "")),
		"target": int(entry.get("target", -1)),
		"extra1": str(entry.get("extra1", "")),
		"extra2": str(entry.get("extra2", "")),
		"source": str(entry.get("source", "")),
		"raw_a": raw_a,
		"raw_b": raw_b,
		"transition_deferred": false,
		"transition_allowed": _b("zonejump_direct_transition_enabled", true),
	}


func _resolve_nearest_transition_entry(radius_raw: float) -> Dictionary:
	if _player() == null:
		return {"ok": false, "reason": "player missing"}
	var pzone := int(_player().get("daoc_zone"))
	var pp := Vector2(float(_player().get("daoc_x")), float(_player().get("daoc_y")))
	var entries: Array = _dict("zonejump_entries_by_zone").get(pzone, []) as Array
	var best: Dictionary = {}
	var best_dist: float = INF
	for item in entries:
		var d: Dictionary = item as Dictionary
		if int(d.get("target", -1)) < 0:
			continue
		var a: Vector2 = d.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = d.get("b", Vector2.ZERO) as Vector2
		var dist := _distance_to_segment(pp, a, b)
		if dist < best_dist and dist <= radius_raw:
			best_dist = dist
			best = d
	if best.is_empty():
		return {"ok": false, "reason": "none within radius", "zone": pzone, "radius_raw": radius_raw, "entry_count": entries.size()}
	return {"ok": true, "zone": pzone, "entry": best, "distance_raw": best_dist, "radius_raw": radius_raw, "entry_count": entries.size()}


func _totals() -> Dictionary:
	var total := 0
	var targets := 0
	var zones_with_entries := 0
	var by_zone := _dict("zonejump_entries_by_zone")
	var keys: Array = by_zone.keys()
	for z_key in keys:
		var entries: Array = by_zone.get(z_key, []) as Array
		if entries.size() > 0:
			zones_with_entries += 1
		total += entries.size()
		for item in entries:
			var d: Dictionary = item as Dictionary
			if int(d.get("target", -1)) >= 0:
				targets += 1
	return {
		"zones_with_entries": zones_with_entries,
		"entries_total": total,
		"targets_total": targets,
	}


func _area_count(node: Node = null) -> int:
	if _host == null:
		return 0
	var root: Node = _host if node == null else node
	var count := 0
	if root.has_meta("daoc_zonejump"):
		count += 1
	for child in root.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			count += _area_count(child_node)
	return count


func _event_debug_line(data: Dictionary) -> String:
	if data.is_empty():
		return "last=none"
	return "event=%s zone=%03d id=%s name=%s target=%s deferred=%s extra1=%s extra2=%s" % [
		str(data.get("event", "?")),
		int(data.get("zone", -1)),
		str(data.get("id", "?")),
		str(data.get("name", "")),
		str(data.get("target", "")),
		str(data.get("transition_deferred", true)),
		str(data.get("extra1", "")),
		str(data.get("extra2", "")),
	]


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	if _host != null and _host.has_method("_distance_to_segment_2d"):
		return float(_host.call("_distance_to_segment_2d", p, a, b))
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.00001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _player() -> Node3D:
	if _host == null:
		return null
	return _host.get("_player") as Node3D


func _dict(name: String) -> Dictionary:
	var v: Variant = _state_value(name)
	if typeof(v) == TYPE_DICTIONARY:
		return v as Dictionary
	return {}


func _array(name: String) -> Array:
	var v: Variant = _state_value(name)
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	return []


func _state_value(name: String) -> Variant:
	if _state == null:
		return null
	return _state.get(name)


func _set_state_value(name: String, value: Variant) -> void:
	if _state != null:
		_state.set(name, value)


func _b(name: String, default_value: bool) -> bool:
	if _host == null:
		return default_value
	var v: Variant = _host.get(name)
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	return default_value


func _i(name: String, default_value: int) -> int:
	if _host == null:
		return default_value
	var v: Variant = _host.get(name)
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	return default_value


func _f(name: String, default_value: float) -> float:
	if _host == null:
		return default_value
	var v: Variant = _host.get(name)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return default_value
