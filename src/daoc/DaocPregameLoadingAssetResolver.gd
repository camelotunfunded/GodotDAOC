extends RefCounted
class_name DaocPregameLoadingAssetResolver

const DaocPregameLoadingAuditFormatterScript = preload("res://src/daoc/DaocPregameLoadingAuditFormatter.gd")

## P1-N6D: resolver/audit offline des sources assets pregame/loading DAoC.
## Rôle volontairement limité : détecter, lister, classer et expliquer les candidats.
## Cette classe ne charge pas les NIF/images au runtime et ne fige pas les règles exactes du client original.

const STATUS_CONFIRMED: String = "CONFIRMÉ"
const STATUS_STRING_CONFIRMED: String = "STRING-CONFIRMÉ"
const STATUS_HYPOTHESIS: String = "HYPOTHÈSE"
const STATUS_DECISION: String = "DÉCISION"

const REALM_ALBION: int = 1
const REALM_MIDGARD: int = 2
const REALM_HIBERNIA: int = 3

func _expected_pregame_dirs() -> PackedStringArray:
	return PackedStringArray(["pregame", "pregame002", "pregame003"])


func _expected_loading_sets() -> PackedStringArray:
	return PackedStringArray(["alb1", "mid1", "hib1", "toa", "cat", "lab", "dr", "rvr1", "camcity"])

var daoc_root: String = ""
var last_root_scan: Dictionary = {}
var last_pregame_scan: Dictionary = {}
var last_loading_scan: Dictionary = {}
var last_audit_snapshot: Dictionary = {}
var _audit_formatter: RefCounted = null


func setup(p_daoc_root: String = "") -> void:
	configure(p_daoc_root)


func configure(p_daoc_root: String = "") -> Dictionary:
	daoc_root = _norm_path(p_daoc_root)
	return status_snapshot()


func set_daoc_root(p_daoc_root: String = "") -> Dictionary:
	return configure(p_daoc_root)


func effective_daoc_root() -> String:
	if daoc_root.strip_edges() != "":
		return daoc_root
	return _norm_path(str(ProjectSettings.get_setting("daoc/client_root", "")))


func scan_daoc_asset_roots(root_path: String = "") -> Dictionary:
	var root := _norm_path(root_path)
	if root == "":
		root = effective_daoc_root()
	var pregame_candidates: Array = []
	for d in _expected_pregame_dirs():
		pregame_candidates.append(_candidate(root.path_join(str(d)), str(d), "dir", STATUS_CONFIRMED, "Drive client/pregame + eden.dll strings"))
	var loading_data := _candidate(root.path_join("Data").path_join("loading"), "Data/loading", "dir", STATUS_CONFIRMED, "Drive client/loading + eden.dll Data/loading")
	var loading_lower := _candidate(root.path_join("data").path_join("loading"), "data/loading", "dir", STATUS_STRING_CONFIRMED, "eden.dll lower-case path")
	var loading_root := _candidate(root.path_join("loading"), "loading", "dir", STATUS_HYPOTHESIS, "fallback extraction layout only")
	last_root_scan = {
		"scope": "P1-N6D DAoC asset root scan",
		"root": root,
		"root_exists": _dir_exists(root),
		"pregame_candidates": pregame_candidates,
		"loading_candidates": [loading_data, loading_lower, loading_root],
		"selected_pregame_path": _first_existing_path(pregame_candidates, root.path_join("pregame")),
		"selected_loading_path": _first_existing_path([loading_data, loading_lower, loading_root], root.path_join("Data").path_join("loading")),
		"rule_status": STATUS_DECISION,
		"decision": "on scanne les sources connues et on garde les chemins manquants comme candidats; aucune hypothèse visuelle n'est chargée directement",
	}
	return last_root_scan.duplicate(true)


func scan_pregame_assets(pregame_path: String = "") -> Dictionary:
	var roots := scan_daoc_asset_roots() if last_root_scan.is_empty() else last_root_scan
	var path := _norm_path(pregame_path)
	if path == "":
		path = str(roots.get("selected_pregame_path", effective_daoc_root().path_join("pregame")))
	var files: Array = []
	var expected := PackedStringArray([
		"pregame.mpk", "pregame002.mpk", "pregame003.mpk", "realmdesc.mpk", "realmdesc.txt", "realm_selection.xml",
		"charScreenAlb.npk", "charScreenMid.npk", "charScreenHib.npk", "settings.dat", "splash.mpk", "splash.xml",
		"login.xml", "uimain.xml", "styles.xml", "trial.mpk", "pennant_alb.tga", "pennant_mid.tga", "pennant_hib.tga",
	])
	for file_name in expected:
		var status := STATUS_CONFIRMED
		if str(file_name).to_lower().begins_with("charscreen"):
			status = STATUS_STRING_CONFIRMED
		files.append(_candidate(path.path_join(str(file_name)), str(file_name), "file", status, "Drive pregame inventory / eden.dll strings"))
	last_pregame_scan = {
		"scope": "P1-N6D pregame asset scan",
		"pregame_path": path,
		"pregame_exists": _dir_exists(path),
		"files": files,
		"realmdesc_fixture_parse": parse_realmdesc_text(realmdesc_fixture_text()),
		"no_runtime_import": true,
		"rule_status": STATUS_DECISION,
	}
	return last_pregame_scan.duplicate(true)


func parse_realmdesc_text(text: String) -> Dictionary:
	var realms: Array = []
	var current_id := 0
	var current_name := ""
	var current_lines := PackedStringArray()
	for raw_line in text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			if current_id > 0:
				realms.append({"id": current_id, "name": current_name, "short": realm_short_for_id(current_id), "description": "\n".join(current_lines)})
			current_name = line.substr(1, line.length() - 2).strip_edges().capitalize()
			current_id = realm_id_for_name(current_name)
			current_lines = PackedStringArray()
		else:
			current_lines.append(line)
	if current_id > 0:
		realms.append({"id": current_id, "name": current_name, "short": realm_short_for_id(current_id), "description": "\n".join(current_lines)})
	return {
		"ok": realms.size() == 3,
		"realm_count": realms.size(),
		"realms": realms,
		"source_status": STATUS_CONFIRMED,
		"source": "pregame/realmdesc.txt dans Realmdesc.mpk",
	}


func realmdesc_fixture_text() -> String:
	return "[ALBION]\nAlbion est le royaume des chevaliers, des moines et des terres d'Arthur.\n\n[HIBERNIA]\nHibernia est le royaume de la nature, de la magie et des peuples anciens.\n\n[MIDGARD]\nMidgard est le royaume nordique des guerriers, trolls, nains et kobolds.\n"


func build_realm_asset_candidates(realm_id: int) -> Dictionary:
	var rid := clampi(realm_id, 1, 3)
	var short := realm_short_for_id(rid)
	var title := realm_name_for_id(rid)
	var roots := scan_daoc_asset_roots() if last_root_scan.is_empty() else last_root_scan
	var pregame_path := str(roots.get("selected_pregame_path", effective_daoc_root().path_join("pregame")))
	var char_scene := "charscreen%s.nif" % short
	var char_container := "charScreen%s.npk" % _realm_title_suffix(rid)
	var candidates: Array = []
	candidates.append(_candidate(pregame_path.path_join(char_scene), char_scene, "nif_scene", STATUS_STRING_CONFIRMED, "eden.dll FUN_005af053 strings"))
	candidates.append(_candidate(pregame_path.path_join(char_container), char_container, "npk_container", STATUS_CONFIRMED, "Drive pregame charScreen*.npk"))
	candidates.append(_candidate("archive://pregame/%s:%s" % [char_container, char_scene], "%s:%s" % [char_container, char_scene], "archive_candidate", STATUS_HYPOTHESIS, "conteneur probable; contenu exact à ouvrir/convertir plus tard"))
	candidates.append(_candidate(pregame_path.path_join("pennant_%s.tga" % short), "pennant_%s.tga" % short, "realm_pennant", STATUS_CONFIRMED, "Drive pregame pennant_*.tga"))
	candidates.append(_candidate(pregame_path.path_join("settings.dat"), "settings.dat#%s" % short, "realm_visual_settings", STATUS_STRING_CONFIRMED, "eden.dll FUN_005af3a7 lit alb/mid/hib depuis settings.dat"))
	return {
		"realm_id": rid,
		"realm_name": title,
		"realm_short": short,
		"candidates": candidates,
		"rule_confirmed": false,
		"rule_status": STATUS_DECISION,
		"decision": "exposer les candidats par royaume, ne pas charger la scène NIF ni supposer son contenu tant que charScreen*.npk n'est pas ouvert",
	}


func scan_loading_sets(loading_path: String = "") -> Dictionary:
	var roots := scan_daoc_asset_roots() if last_root_scan.is_empty() else last_root_scan
	var path := _norm_path(loading_path)
	if path == "":
		path = str(roots.get("selected_loading_path", effective_daoc_root().path_join("Data").path_join("loading")))
	var sets: Array = []
	for set_name in _expected_loading_sets():
		var s := str(set_name)
		var reason := "Drive Data/loading inventory"
		var status := STATUS_CONFIRMED
		if s == "dr":
			status = STATUS_STRING_CONFIRMED
			reason = "eden.dll Data/loading/DR.mpk string; dossier exact à confirmer"
		sets.append({
			"name": s,
			"folder": _candidate(path.path_join(s), s, "loading_folder", status, reason),
			"mpk": _candidate(path.path_join("%s.mpk" % s), "%s.mpk" % s, "loading_mpk", status, reason),
		})
	last_loading_scan = {
		"scope": "P1-N6D post-character loading asset scan",
		"loading_path": path,
		"loading_exists": _dir_exists(path),
		"sets": sets,
		"tips": _candidate(path.path_join("tips.dat"), "tips.dat", "loading_tips", STATUS_CONFIRMED, "Drive Data/loading/tips.dat"),
		"rule_confirmed": false,
		"rule_status": STATUS_DECISION,
		"decision": "l'ordre exact realm/zone/version/Eden custom reste non figé; build_loading_candidates retourne des candidats classés",
	}
	return last_loading_scan.duplicate(true)


func build_loading_candidates(realm_id: int, region_id: int = -1, expansion_id: int = -1, context: String = "") -> Dictionary:
	var rid := clampi(realm_id, 1, 3)
	var roots := scan_daoc_asset_roots() if last_root_scan.is_empty() else last_root_scan
	var loading_path := str(roots.get("selected_loading_path", effective_daoc_root().path_join("Data").path_join("loading")))
	var candidates: Array = []
	var primary := "alb1"
	if rid == REALM_MIDGARD:
		primary = "mid1"
	elif rid == REALM_HIBERNIA:
		primary = "hib1"
	candidates.append(_loading_candidate(loading_path, primary, 100, STATUS_CONFIRMED, "royaume sélectionné; règle probable mais non finale"))
	for common in PackedStringArray(["camcity", "toa", "cat", "lab", "dr", "rvr1"]):
		var score := 50
		var reason := "candidat commun/extension; à départager par région/expansion"
		if str(common) == "lab" and context.to_lower().contains("lab"):
			score = 90
			reason = "contexte Labyrinth"
		elif str(common) == "rvr1" and (context.to_lower().contains("rvr") or region_id >= 160):
			score = 80
			reason = "contexte RvR/frontiers probable"
		elif str(common) == "toa" and expansion_id >= 2:
			score = 75
			reason = "expansion ToA ou supérieure probable"
		elif str(common) == "cat" and expansion_id >= 3:
			score = 76
			reason = "expansion Catacombs ou supérieure probable"
		candidates.append(_loading_candidate(loading_path, str(common), score, STATUS_HYPOTHESIS if str(common) != "dr" else STATUS_STRING_CONFIRMED, reason))
	return {
		"realm_id": rid,
		"realm_name": realm_name_for_id(rid),
		"region_id": region_id,
		"expansion_id": expansion_id,
		"context": context,
		"candidates": candidates,
		"rule_confirmed": false,
		"rule_status": STATUS_DECISION,
		"decision": "candidats classés uniquement; aucune image loading choisie définitivement",
	}


func asset_candidate_status(path_or_container: String) -> Dictionary:
	var p := _norm_path(path_or_container)
	if p.begins_with("archive://"):
		return {"path": p, "exists": false, "status": "container_only", "reason": "chemin archive candidat; ouverture MPK/NPK non implémentée dans P1-N6D"}
	if p == "":
		return {"path": p, "exists": false, "status": "missing", "reason": "empty path"}
	if _dir_exists(p):
		return {"path": p, "exists": true, "status": "exists_direct", "reason": "directory exists"}
	if FileAccess.file_exists(p):
		return {"path": p, "exists": true, "status": "exists_direct", "reason": "file exists"}
	if p.to_lower().ends_with(".mpk") or p.to_lower().ends_with(".npk"):
		return {"path": p, "exists": false, "status": "unknown_container", "reason": "container not found or not mounted"}
	return {"path": p, "exists": false, "status": "missing", "reason": "not present on current filesystem"}


func build_pregame_loading_audit_snapshot() -> Dictionary:
	var roots := scan_daoc_asset_roots()
	var pregame := scan_pregame_assets(str(roots.get("selected_pregame_path", "")))
	var loading := scan_loading_sets(str(roots.get("selected_loading_path", "")))
	var realms: Array = []
	for rid in [1, 2, 3]:
		realms.append(build_realm_asset_candidates(int(rid)))
	var loading_candidates: Array = []
	for rid in [1, 2, 3]:
		loading_candidates.append(build_loading_candidates(int(rid), -1, -1, "audit"))
	last_audit_snapshot = {
		"scope": "P1-N6D asset source resolver offline pregame/loading",
		"roots": roots,
		"pregame": pregame,
		"loading": loading,
		"realm_asset_candidates": realms,
		"loading_candidates_by_realm": loading_candidates,
		"statuses": [STATUS_CONFIRMED, STATUS_STRING_CONFIRMED, STATUS_HYPOTHESIS, STATUS_DECISION],
		"no_runtime_import": true,
		"real_network_required": false,
		"rule_confirmed": false,
		"next_step": "ouvrir/extraire les MPK/NPK concernés puis remplacer les candidats par des règles confirmées",
	}
	return last_audit_snapshot.duplicate(true)


func build_audit_summary_snapshot(realm_id: int = 1, region_id: int = -1, expansion_id: int = -1, context: String = "summary") -> Dictionary:
	var rid := clampi(realm_id, 1, 3)
	var roots := scan_daoc_asset_roots()
	var pregame_scan := scan_pregame_assets(str(roots.get("selected_pregame_path", "")))
	var loading_scan := scan_loading_sets(str(roots.get("selected_loading_path", "")))
	var realm_assets := build_realm_asset_candidates(rid)
	var loading_assets := build_loading_candidates(rid, region_id, expansion_id, context)
	var pregame_files := _compact_candidate_array(pregame_scan.get("files", []) as Array, 64)
	var loading_sets := _compact_loading_sets(loading_scan.get("sets", []) as Array, 32)
	var realmdesc_parse := pregame_scan.get("realmdesc_fixture_parse", {}) as Dictionary
	return {
		"scope": "P1-N6D compact asset source resolver summary",
		"root": str(roots.get("root", "")),
		"root_exists": bool(roots.get("root_exists", false)),
		"selected_pregame_path": str(roots.get("selected_pregame_path", "")),
		"selected_loading_path": str(roots.get("selected_loading_path", "")),
		"pregame_roots": _compact_candidate_array(roots.get("pregame_candidates", []) as Array, 8),
		"loading_roots": _compact_candidate_array(roots.get("loading_candidates", []) as Array, 8),
		"pregame": {
			"path": str(pregame_scan.get("pregame_path", "")),
			"exists": bool(pregame_scan.get("pregame_exists", false)),
			"expected_files": pregame_files.size(),
			"existing_files": _count_existing_candidates(pregame_files),
			"realmdesc_fixture_ok": bool(realmdesc_parse.get("ok", false)),
			"realmdesc_realm_count": int(realmdesc_parse.get("realm_count", 0)),
			"files": pregame_files,
		},
		"loading": {
			"path": str(loading_scan.get("loading_path", "")),
			"exists": bool(loading_scan.get("loading_exists", false)),
			"expected_sets": loading_sets.size(),
			"existing_sets": _count_existing_loading_sets(loading_sets),
			"sets": loading_sets,
			"tips": _compact_candidate(loading_scan.get("tips", {}) as Dictionary),
			"rule_confirmed": false,
		},
		"realm": {
			"id": rid,
			"name": realm_name_for_id(rid),
			"short": realm_short_for_id(rid),
			"character_candidates": _compact_candidate_array(realm_assets.get("candidates", []) as Array, 16),
			"loading_candidates": _compact_loading_candidate_array(loading_assets.get("candidates", []) as Array, 16),
			"rule_confirmed": false,
		},
		"statuses": [STATUS_CONFIRMED, STATUS_STRING_CONFIRMED, STATUS_HYPOTHESIS, STATUS_DECISION],
		"no_runtime_import": true,
		"real_network_required": false,
		"rule_confirmed": false,
		"report_is_compact": true,
		"full_json_not_for_console": true,
		"next_step": "ouvrir/extraire les MPK/NPK concernés puis remplacer les candidats par des règles confirmées",
	}


func build_audit_report_lines(section: String = "summary", realm_id: int = 1, region_id: int = -1, expansion_id: int = -1, context: String = "command", max_lines: int = 80) -> PackedStringArray:
	var summary: Dictionary = build_audit_summary_snapshot(realm_id, region_id, expansion_id, context)
	return _formatter().call("build_report_lines", summary, section, max_lines) as PackedStringArray


func build_audit_compact_line(realm_id: int = 1, region_id: int = -1, expansion_id: int = -1, context: String = "compact") -> String:
	var summary: Dictionary = build_audit_summary_snapshot(realm_id, region_id, expansion_id, context)
	return str(_formatter().call("compact_one_line", summary))


func build_asset_source_panel_lines(realm_id: int = 1, region_id: int = -1, expansion_id: int = -1, context: String = "") -> PackedStringArray:
	var lines := PackedStringArray()
	var roots := scan_daoc_asset_roots() if last_root_scan.is_empty() else last_root_scan
	var realm_assets := build_realm_asset_candidates(realm_id)
	var loading_assets := build_loading_candidates(realm_id, region_id, expansion_id, context)
	lines.append("P1-N6D asset resolver: scan offline, no runtime import")
	lines.append("pregame=%s" % str(roots.get("selected_pregame_path", "")))
	lines.append("loading=%s" % str(roots.get("selected_loading_path", "")))
	lines.append("realm=%s rule_confirmed=false" % str(realm_assets.get("realm_name", "?")))
	var rcands: Array = realm_assets.get("candidates", []) as Array
	for i in range(mini(rcands.size(), 4)):
		var c: Dictionary = rcands[i] as Dictionary
		lines.append("  char[%d] %s status=%s fs=%s" % [i, str(c.get("label", "")), str(c.get("source_status", "")), str(c.get("fs_status", ""))])
	var lcands: Array = loading_assets.get("candidates", []) as Array
	for i in range(mini(lcands.size(), 4)):
		var c: Dictionary = lcands[i] as Dictionary
		lines.append("  load[%d] %s score=%d fs=%s" % [i, str(c.get("set", "")), int(c.get("score", 0)), str(c.get("folder_status", ""))])
	return lines


func status_snapshot() -> Dictionary:
	return {
		"scope": "P1-N6D asset source resolver offline pregame/loading",
		"root": effective_daoc_root(),
		"has_root_scan": not last_root_scan.is_empty(),
		"has_pregame_scan": not last_pregame_scan.is_empty(),
		"has_loading_scan": not last_loading_scan.is_empty(),
		"no_runtime_import": true,
		"rule_confirmed": false,
		"real_network_required": false,
	}


func p1_n6d_scope() -> String:
	return "P1-N6D offline: resolver/audit des sources pregame/loading, candidats royaume/personnage/loading, aucun chargement NIF/image runtime, aucune règle hypothétique codée en dur."


func is_runtime_import_enabled() -> bool:
	return false


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"setup", "configure", "set_daoc_root", "effective_daoc_root", "scan_daoc_asset_roots", "scan_pregame_assets", "parse_realmdesc_text", "realmdesc_fixture_text", "build_realm_asset_candidates", "scan_loading_sets", "build_loading_candidates", "asset_candidate_status", "build_pregame_loading_audit_snapshot", "build_audit_summary_snapshot", "build_audit_report_lines", "build_audit_compact_line", "build_asset_source_panel_lines", "status_snapshot", "p1_n6d_scope", "is_runtime_import_enabled", "realm_id_for_name", "realm_name_for_id", "realm_short_for_id",
	])


func realm_id_for_name(name: String) -> int:
	var n := name.strip_edges().to_lower()
	if n.is_valid_int():
		var v := int(n)
		return v if v >= 1 and v <= 3 else 0
	if n in ["alb", "albion"]:
		return REALM_ALBION
	if n in ["mid", "midgard"]:
		return REALM_MIDGARD
	if n in ["hib", "hibernia"]:
		return REALM_HIBERNIA
	return 0


func realm_name_for_id(realm_id: int) -> String:
	match realm_id:
		REALM_ALBION:
			return "Albion"
		REALM_MIDGARD:
			return "Midgard"
		REALM_HIBERNIA:
			return "Hibernia"
	return "Unknown"


func realm_short_for_id(realm_id: int) -> String:
	match realm_id:
		REALM_ALBION:
			return "alb"
		REALM_MIDGARD:
			return "mid"
		REALM_HIBERNIA:
			return "hib"
	return "unknown"


func _realm_title_suffix(realm_id: int) -> String:
	match realm_id:
		REALM_ALBION:
			return "Alb"
		REALM_MIDGARD:
			return "Mid"
		REALM_HIBERNIA:
			return "Hib"
	return "Unknown"


func _loading_candidate(base_path: String, set_name: String, score: int, status: String, reason: String) -> Dictionary:
	var folder_path := _norm_path(base_path).path_join(set_name)
	var mpk_path := _norm_path(base_path).path_join("%s.mpk" % set_name)
	return {
		"set": set_name,
		"score": score,
		"source_status": status,
		"reason": reason,
		"folder_path": folder_path,
		"folder_status": str(asset_candidate_status(folder_path).get("status", "missing")),
		"mpk_path": mpk_path,
		"mpk_status": str(asset_candidate_status(mpk_path).get("status", "missing")),
	}



func _formatter() -> RefCounted:
	if _audit_formatter == null:
		_audit_formatter = DaocPregameLoadingAuditFormatterScript.new()
	return _audit_formatter


func _compact_candidate_array(candidates: Array, max_items: int = 64) -> Array:
	var result: Array = []
	for i in range(mini(candidates.size(), max_items)):
		result.append(_compact_candidate(candidates[i] as Dictionary))
	return result


func _compact_candidate(c: Dictionary) -> Dictionary:
	if c.is_empty():
		return {}
	return {
		"label": str(c.get("label", c.get("name", ""))),
		"kind": str(c.get("kind", "")),
		"fs_status": str(c.get("fs_status", c.get("status", ""))),
		"exists": bool(c.get("exists", false)),
		"source_status": str(c.get("source_status", "")),
	}


func _compact_loading_sets(sets: Array, max_items: int = 32) -> Array:
	var result: Array = []
	for i in range(mini(sets.size(), max_items)):
		var item: Dictionary = sets[i] as Dictionary
		var folder: Dictionary = item.get("folder", {}) as Dictionary
		var mpk: Dictionary = item.get("mpk", {}) as Dictionary
		result.append({
			"name": str(item.get("name", "")),
			"folder_status": str(folder.get("fs_status", "")),
			"mpk_status": str(mpk.get("fs_status", "")),
			"exists": bool(folder.get("exists", false)) or bool(mpk.get("exists", false)),
			"source_status": str(folder.get("source_status", mpk.get("source_status", ""))),
		})
	return result


func _compact_loading_candidate_array(candidates: Array, max_items: int = 32) -> Array:
	var result: Array = []
	for i in range(mini(candidates.size(), max_items)):
		var c: Dictionary = candidates[i] as Dictionary
		result.append({
			"set": str(c.get("set", "")),
			"score": int(c.get("score", 0)),
			"folder_status": str(c.get("folder_status", "")),
			"mpk_status": str(c.get("mpk_status", "")),
			"source_status": str(c.get("source_status", "")),
		})
	return result


func _count_existing_candidates(candidates: Array) -> int:
	var count := 0
	for item in candidates:
		var c := item as Dictionary
		if bool(c.get("exists", false)):
			count += 1
	return count


func _count_existing_loading_sets(sets: Array) -> int:
	var count := 0
	for item in sets:
		var c := item as Dictionary
		if bool(c.get("exists", false)):
			count += 1
	return count


func _candidate(path: String, label: String, kind: String, source_status: String, source_reason: String) -> Dictionary:
	var st := asset_candidate_status(path)
	return {
		"label": label,
		"kind": kind,
		"path": _norm_path(path),
		"source_status": source_status,
		"source_reason": source_reason,
		"fs_status": str(st.get("status", "missing")),
		"exists": bool(st.get("exists", false)),
	}


func _first_existing_path(candidates: Array, fallback: String) -> String:
	for item in candidates:
		var c: Dictionary = item as Dictionary
		if bool(c.get("exists", false)):
			return str(c.get("path", fallback))
	return _norm_path(fallback)


func _norm_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	while p.ends_with("/") and not p.ends_with("://") and not (p.length() == 3 and p.substr(1, 2) == ":/"):
		p = p.substr(0, p.length() - 1)
	return p


func _dir_exists(path: String) -> bool:
	var p := _norm_path(path)
	return p != "" and DirAccess.open(p) != null
