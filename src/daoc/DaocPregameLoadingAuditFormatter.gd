extends RefCounted
class_name DaocPregameLoadingAuditFormatter

## P1-N6D hotfix: formatage compact des rapports pregame/loading.
## Le resolver peut construire des dictionnaires complets, mais la console/F12 ne doivent jamais
## imprimer le snapshot brut : Godot coupe avec "output overflow".

const MAX_LINES_DEFAULT: int = 80


func build_report_lines(summary: Dictionary, section: String = "summary", max_lines: int = MAX_LINES_DEFAULT) -> PackedStringArray:
	var lines := PackedStringArray()
	var sec := section.strip_edges().to_lower()
	if sec == "":
		sec = "summary"
	match sec:
		"help":
			_append_help(lines)
		"roots":
			_append_roots(lines, summary)
		"pregame":
			_append_pregame(lines, summary)
		"loading":
			_append_loading(lines, summary)
		"realm":
			_append_realm(lines, summary)
		"audit":
			_append_summary(lines, summary)
			lines.append("")
			_append_roots(lines, summary)
			lines.append("")
			_append_pregame(lines, summary)
			lines.append("")
			_append_loading(lines, summary)
			lines.append("")
			_append_realm(lines, summary)
		_:
			_append_summary(lines, summary)
	if lines.size() > max_lines:
		var clipped := PackedStringArray()
		for i in range(max_lines):
			clipped.append(lines[i])
		clipped.append("... sortie tronquée volontairement; utilise /dol assets roots|pregame|loading|realm")
		return clipped
	return lines


func compact_one_line(summary: Dictionary) -> String:
	var pregame := summary.get("pregame", {}) as Dictionary
	var loading := summary.get("loading", {}) as Dictionary
	var realm := summary.get("realm", {}) as Dictionary
	return "P1-N6D assets root=%s pregame=%s/%s loading=%s/%s realm=%s rule_confirmed=false" % [
		str(summary.get("root_exists", false)),
		str(pregame.get("existing_files", 0)),
		str(pregame.get("expected_files", 0)),
		str(loading.get("existing_sets", 0)),
		str(loading.get("expected_sets", 0)),
		str(realm.get("name", "?")),
	]


func _append_help(lines: PackedStringArray) -> void:
	lines.append("P1-N6D commandes assets compactes:")
	lines.append("  /dol assets              résumé court")
	lines.append("  /dol assets audit        audit compact multi-section")
	lines.append("  /dol assets roots        racines pregame/loading")
	lines.append("  /dol assets pregame      fichiers pregame attendus")
	lines.append("  /dol assets loading      sets Data/loading attendus")
	lines.append("  /dol assets realm alb|mid|hib")
	lines.append("Note: le JSON complet n'est pas imprimé en console pour éviter output overflow.")


func _append_summary(lines: PackedStringArray, summary: Dictionary) -> void:
	lines.append(compact_one_line(summary))
	lines.append("root=%s" % str(summary.get("root", "")))
	lines.append("pregame_path=%s" % str(summary.get("selected_pregame_path", "")))
	lines.append("loading_path=%s" % str(summary.get("selected_loading_path", "")))
	lines.append("no_runtime_import=%s real_network_required=%s" % [str(summary.get("no_runtime_import", true)), str(summary.get("real_network_required", false))])
	lines.append("next_step=%s" % str(summary.get("next_step", "")))
	lines.append("commands=/dol assets roots | pregame | loading | realm alb|mid|hib")


func _append_roots(lines: PackedStringArray, summary: Dictionary) -> void:
	lines.append("P1-N6D roots:")
	lines.append("  root_exists=%s" % str(summary.get("root_exists", false)))
	var pregame_roots: Array = summary.get("pregame_roots", []) as Array
	for c in pregame_roots:
		_append_candidate_line(lines, "  pregame", c as Dictionary)
	var loading_roots: Array = summary.get("loading_roots", []) as Array
	for c in loading_roots:
		_append_candidate_line(lines, "  loading", c as Dictionary)


func _append_pregame(lines: PackedStringArray, summary: Dictionary) -> void:
	var pregame := summary.get("pregame", {}) as Dictionary
	lines.append("P1-N6D pregame: exists=%s files=%s/%s realmdesc_fixture_ok=%s" % [
		str(pregame.get("exists", false)),
		str(pregame.get("existing_files", 0)),
		str(pregame.get("expected_files", 0)),
		str(pregame.get("realmdesc_fixture_ok", false)),
	])
	var files: Array = pregame.get("files", []) as Array
	for c in files:
		_append_candidate_line(lines, "  file", c as Dictionary)


func _append_loading(lines: PackedStringArray, summary: Dictionary) -> void:
	var loading := summary.get("loading", {}) as Dictionary
	lines.append("P1-N6D loading: exists=%s sets=%s/%s rule_confirmed=false" % [
		str(loading.get("exists", false)),
		str(loading.get("existing_sets", 0)),
		str(loading.get("expected_sets", 0)),
	])
	var sets: Array = loading.get("sets", []) as Array
	for c in sets:
		var d: Dictionary = c as Dictionary
		lines.append("  set %s folder=%s mpk=%s source=%s" % [
			str(d.get("name", "")),
			str(d.get("folder_status", "")),
			str(d.get("mpk_status", "")),
			str(d.get("source_status", "")),
		])
	var tips := loading.get("tips", {}) as Dictionary
	if not tips.is_empty():
		_append_candidate_line(lines, "  tips", tips)


func _append_realm(lines: PackedStringArray, summary: Dictionary) -> void:
	var realm := summary.get("realm", {}) as Dictionary
	lines.append("P1-N6D realm %s/%s rule_confirmed=false" % [str(realm.get("id", 0)), str(realm.get("name", "?"))])
	var char_candidates: Array = realm.get("character_candidates", []) as Array
	for c in char_candidates:
		_append_candidate_line(lines, "  char", c as Dictionary)
	var load_candidates: Array = realm.get("loading_candidates", []) as Array
	for c in load_candidates:
		var d: Dictionary = c as Dictionary
		lines.append("  load %s score=%s folder=%s mpk=%s source=%s" % [str(d.get("set", "")), str(d.get("score", 0)), str(d.get("folder_status", "")), str(d.get("mpk_status", "")), str(d.get("source_status", ""))])


func _append_candidate_line(lines: PackedStringArray, prefix: String, c: Dictionary) -> void:
	lines.append("%s %s fs=%s source=%s" % [prefix, str(c.get("label", c.get("name", ""))), str(c.get("fs_status", c.get("status", ""))), str(c.get("source_status", ""))])
