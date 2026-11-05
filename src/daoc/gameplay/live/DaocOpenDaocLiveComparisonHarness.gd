extends RefCounted
class_name DaocOpenDaocLiveComparisonHarness

const DEFAULT_CONFIG_PATH: String = "res://config/opendaoc_live_comparison.json"
const REPORT_JSON_PATH: String = "res://reports/prediction_vs_server_result.json"
const REPORT_TEXT_PATH: String = "res://reports/prediction_vs_server_result.txt"
const CHECKPOINT: String = "P1_18L_LIVE_COMPARISON_HARNESS"

var last_report: Dictionary = {}

func default_config() -> Dictionary:
	return {
		"enabled": false,
		"host": "127.0.0.1",
		"port": 10300,
		"timeout_msec": 500,
		"mode": "dry_run",
		"server_result_source": "",
	}

func load_config(path: String = DEFAULT_CONFIG_PATH) -> Dictionary:
	var config: Dictionary = default_config()
	if not FileAccess.file_exists(path):
		config["config_path"] = path
		config["config_status"] = "missing_using_defaults"
		return config
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		config["config_path"] = path
		config["config_status"] = "cannot_open_using_defaults"
		return config
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed as Dictionary
		for key in data.keys():
			config[str(key)] = data[key]
		config["config_status"] = "loaded"
	else:
		config["config_status"] = "invalid_json_using_defaults"
	config["config_path"] = path
	return config

func build_status_report(options: Dictionary = {}) -> Dictionary:
	var config: Dictionary = _merged_config(options)
	var enabled: bool = bool(config.get("enabled", false))
	var report: Dictionary = _base_report(config, "status")
	report["ok"] = true
	report["server_configured"] = enabled
	report["skipped"] = not enabled
	report["skip_reason"] = "live comparison disabled" if not enabled else ""
	report["server_reachable"] = false
	report["comparison_status"] = "skipped_no_server_configured" if not enabled else "configured_not_probed"
	report["notes"] = [
		"Status does not cast and does not infer a server result.",
		"Set enabled=true only for a local or controlled OpenDAoC server.",
	]
	last_report = report.duplicate(true)
	return last_report.duplicate(true)

func run_direct_damage_comparison(lab: RefCounted, spell_id: int, candidate_dirs: Array = [], options: Dictionary = {}) -> Dictionary:
	var config: Dictionary = _merged_config(options)
	var report: Dictionary = _base_report(config, "direct_damage")
	report["spell_id"] = spell_id
	report["caster"] = _test_caster()
	report["target"] = _test_target()
	report["prediction_result"] = _prediction_result(lab, spell_id, candidate_dirs, options)
	report["prediction_summary"] = _prediction_summary(report.get("prediction_result", {}) as Dictionary)
	report["server_configured"] = bool(config.get("enabled", false))
	if not bool(config.get("enabled", false)):
		report["ok"] = true
		report["skipped"] = true
		report["skip_reason"] = "live comparison disabled"
		report["comparison_status"] = "skipped_no_server_configured"
		last_report = report.duplicate(true)
		return last_report.duplicate(true)
	var reachable: Dictionary = _check_server_reachable(config)
	report["server_reachable"] = bool(reachable.get("ok", false))
	report["server_reachability"] = reachable
	if not bool(reachable.get("ok", false)):
		report["ok"] = false
		report["error"] = "server_unreachable"
		report["comparison_status"] = "server_unreachable"
		last_report = report.duplicate(true)
		return last_report.duplicate(true)
	var server_result: Dictionary = _server_result_from_options(config, options)
	report["server_result"] = server_result
	if server_result.is_empty():
		report["ok"] = false
		report["error"] = "server_result_capture_missing"
		report["comparison_status"] = "server_reachable_no_repeatable_capture"
		report["notes"] = [
			"Server was reachable, but no explicit repeatable server result was supplied.",
			"No server result is inferred from client formulas.",
		]
		last_report = report.duplicate(true)
		return last_report.duplicate(true)
	report["comparison"] = _compare_prediction_to_server(report.get("prediction_summary", {}) as Dictionary, server_result)
	report["ok"] = bool((report.get("prediction_result", {}) as Dictionary).get("ok", false)) and bool(server_result.get("captured", false))
	report["comparison_status"] = "comparison_written"
	last_report = report.duplicate(true)
	return last_report.duplicate(true)

func export_last_report_json(path: String = REPORT_JSON_PATH) -> Dictionary:
	if last_report.is_empty():
		build_status_report()
	return _write_text(path, JSON.stringify(last_report, "\t"))

func export_last_report_text(path: String = REPORT_TEXT_PATH) -> Dictionary:
	if last_report.is_empty():
		build_status_report()
	return _write_text(path, build_text_report(last_report))

func build_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_report
	var lines: Array = []
	lines.append("P1-18L OpenDAoC live comparison harness")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("comparison_status", "")), str(r.get("checkpoint", ""))])
	lines.append("scenario=%s spell_id=%d server_configured=%s server_reachable=%s skipped=%s" % [
		str(r.get("scenario", "")),
		int(r.get("spell_id", 0)),
		str(r.get("server_configured", false)),
		str(r.get("server_reachable", false)),
		str(r.get("skipped", false)),
	])
	var config: Dictionary = r.get("config", {}) as Dictionary
	lines.append("host=%s port=%d enabled=%s mode=%s" % [str(config.get("host", "")), int(config.get("port", 0)), str(config.get("enabled", false)), str(config.get("mode", ""))])
	var prediction: Dictionary = r.get("prediction_summary", {}) as Dictionary
	if not prediction.is_empty():
		lines.append("prediction ok=%s damage=%d crit=%d total=%d hp_delta=%d" % [
			str(prediction.get("ok", false)),
			int(prediction.get("damage", 0)),
			int(prediction.get("critical_damage", 0)),
			int(prediction.get("total_damage", 0)),
			int(prediction.get("hp_delta_predicted", 0)),
		])
	var server_result: Dictionary = r.get("server_result", {}) as Dictionary
	if not server_result.is_empty():
		lines.append("server captured=%s source=%s damage=%d crit=%d total=%d" % [
			str(server_result.get("captured", false)),
			str(server_result.get("capture_source", "")),
			int(server_result.get("damage", 0)),
			int(server_result.get("critical_damage", 0)),
			int(server_result.get("total_damage", 0)),
		])
	var comparison: Dictionary = r.get("comparison", {}) as Dictionary
	if not comparison.is_empty():
		lines.append("delta total_damage=%d hp_delta=%d exact_damage_match=%s" % [
			int(comparison.get("total_damage_delta", 0)),
			int(comparison.get("hp_delta_delta", 0)),
			str(comparison.get("exact_total_damage_match", false)),
		])
	if str(r.get("skip_reason", "")) != "":
		lines.append("skip_reason=%s" % str(r.get("skip_reason", "")))
	if str(r.get("error", "")) != "":
		lines.append("error=%s" % str(r.get("error", "")))
	lines.append("guardrails server_authority=true prediction_only=true damage_final=false runtime_enabled=false")
	lines.append("No client formula becomes authoritative; server values require repeatable capture.")
	return "\n".join(lines) + "\n"

func _merged_config(options: Dictionary) -> Dictionary:
	var config_path: String = str(options.get("config_path", DEFAULT_CONFIG_PATH))
	var config: Dictionary = load_config(config_path)
	for key in ["enabled", "host", "port", "timeout_msec", "mode", "server_result_source"]:
		if options.has(key):
			config[key] = options[key]
	return config

func _base_report(config: Dictionary, scenario: String) -> Dictionary:
	return {
		"checkpoint": CHECKPOINT,
		"scope": "P1-18L Live Comparison Harness OpenDAoC",
		"scenario": scenario,
		"ok": false,
		"status": "built",
		"comparison_status": "not_run",
		"config": config.duplicate(true),
		"server_reachable": false,
		"skipped": false,
		"guardrails": DaocGameplayAuthority.guardrails(),
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"runtime_enabled": false,
		"pet_spawn_applied": false,
		"player_spawn_applied": false,
		"server_result_inferred": false,
		"msec": Time.get_ticks_msec(),
	}

func _prediction_result(lab: RefCounted, spell_id: int, candidate_dirs: Array, options: Dictionary) -> Dictionary:
	if lab == null:
		return {"ok": false, "status": "missing_lab", "guardrails": DaocGameplayAuthority.result_guard()}
	if candidate_dirs.is_empty():
		if lab.has_method("load_default_fixtures"):
			lab.call("load_default_fixtures")
		return lab.call("cast_spell_by_id", spell_id, {"seed": int(options.get("seed", 42)), "verbose": true, "distance": int(options.get("distance", 900))}) as Dictionary
	return lab.call("cast_opendaoc_spell_by_id", spell_id, candidate_dirs, {"seed": int(options.get("seed", 42)), "verbose": true, "max_rows": int(options.get("max_rows", 8192)), "distance": int(options.get("distance", 900))}) as Dictionary

func _prediction_summary(prediction_result: Dictionary) -> Dictionary:
	var detail: Dictionary = prediction_result.get("detail", {}) as Dictionary
	var damage: Dictionary = detail.get("damage_summary", {}) as Dictionary
	return {
		"ok": bool(prediction_result.get("ok", false)),
		"spell_id": int(prediction_result.get("spell_id", 0)),
		"mechanism": str(detail.get("mechanism", "")),
		"damage": int(damage.get("damage", 0)),
		"critical_damage": int(damage.get("critical_damage", 0)),
		"total_damage": int(damage.get("total_damage", 0)),
		"hp_delta_predicted": int(detail.get("hp_delta_predicted", 0)),
		"target_hp_before": int(detail.get("target_hp_before", 0)),
		"target_hp_after_predicted": int(detail.get("target_hp_after_predicted", 0)),
		"damage_final": false,
		"prediction_only": true,
	}

func _check_server_reachable(config: Dictionary) -> Dictionary:
	var host: String = str(config.get("host", "")).strip_edges()
	var port: int = int(config.get("port", 0))
	var timeout_msec: int = maxi(50, int(config.get("timeout_msec", 500)))
	if host == "" or port <= 0:
		return {"ok": false, "status": "invalid_host_or_port", "host": host, "port": port}
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	var err: Error = peer.connect_to_host(host, port)
	if err != OK:
		return {"ok": false, "status": "connect_to_host_error", "error_code": int(err), "host": host, "port": port}
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_msec:
		peer.poll()
		var status: int = peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			return {"ok": true, "status": "connected", "host": host, "port": port, "elapsed_msec": Time.get_ticks_msec() - start}
		if status == StreamPeerTCP.STATUS_ERROR:
			peer.disconnect_from_host()
			return {"ok": false, "status": "status_error", "host": host, "port": port, "elapsed_msec": Time.get_ticks_msec() - start}
		OS.delay_msec(10)
	peer.disconnect_from_host()
	return {"ok": false, "status": "timeout", "host": host, "port": port, "elapsed_msec": Time.get_ticks_msec() - start}

func _server_result_from_options(config: Dictionary, options: Dictionary) -> Dictionary:
	if typeof(options.get("server_result", {})) == TYPE_DICTIONARY:
		return _normalize_server_result(options.get("server_result", {}) as Dictionary, "options")
	var source_path: String = str(options.get("server_result_source", config.get("server_result_source", ""))).strip_edges()
	if source_path == "":
		return {}
	if not FileAccess.file_exists(source_path):
		return {"captured": false, "capture_source": source_path, "error": "server_result_source_missing"}
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"captured": false, "capture_source": source_path, "error": "cannot_open_server_result_source"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"captured": false, "capture_source": source_path, "error": "invalid_server_result_json"}
	return _normalize_server_result(parsed as Dictionary, source_path)

func _normalize_server_result(data: Dictionary, source: String) -> Dictionary:
	var damage: int = int(data.get("damage", data.get("server_damage", 0)))
	var critical: int = int(data.get("critical_damage", data.get("server_critical_damage", 0)))
	var total: int = int(data.get("total_damage", damage + critical))
	var hp_delta: int = int(data.get("hp_delta", data.get("server_hp_delta", -total)))
	return {
		"captured": bool(data.get("captured", true)),
		"capture_source": source,
		"capture_method": str(data.get("capture_method", "explicit_repeatable_capture")),
		"spell_id": int(data.get("spell_id", 0)),
		"damage": damage,
		"critical_damage": critical,
		"total_damage": total,
		"hp_delta": hp_delta,
		"raw": data.duplicate(true),
	}

func _compare_prediction_to_server(prediction: Dictionary, server_result: Dictionary) -> Dictionary:
	var prediction_total: int = int(prediction.get("total_damage", 0))
	var server_total: int = int(server_result.get("total_damage", 0))
	var prediction_hp_delta: int = int(prediction.get("hp_delta_predicted", 0))
	var server_hp_delta: int = int(server_result.get("hp_delta", 0))
	return {
		"prediction_total_damage": prediction_total,
		"server_total_damage": server_total,
		"total_damage_delta": prediction_total - server_total,
		"prediction_hp_delta": prediction_hp_delta,
		"server_hp_delta": server_hp_delta,
		"hp_delta_delta": prediction_hp_delta - server_hp_delta,
		"exact_total_damage_match": prediction_total == server_total,
		"server_authority": true,
		"client_formula_promoted": false,
	}

func _test_caster() -> Dictionary:
	return {"id": 1, "name": "Offline Caster", "level": 50, "explicit": true}

func _test_target() -> Dictionary:
	return {"id": 2, "name": "Training Dummy", "level": 50, "explicit": true}

func _write_text(path: String, text: String) -> Dictionary:
	var dir_path: String = path.get_base_dir()
	if dir_path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": str(FileAccess.get_open_error())}
	file.store_string(text)
	file.close()
	return {"ok": true, "path": path, "global_path": ProjectSettings.globalize_path(path), "bytes": text.to_utf8_buffer().size()}
