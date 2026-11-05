extends RefCounted
class_name DaocOpenDaocSqlImport

## P1-17E2D — import préparatoire OpenDAoC SQL -> slots abstraits.
## Aucun effet runtime: ce parseur extrait seulement des métadonnées et quelques
## lignes normalisées depuis les fichiers .sql OpenDAoC-Database.

const SCOPE: String = "P1-17E2D OpenDAoC SQL DB import preparation"
const CHECKPOINT: String = "P1_17E2D_OPENDAOC_SQL_DB_IMPORT"
const DEFAULT_SLOT_DB_PATH: String = "res://data/server_instruction_db/opendaoc_sql_import_slots_p1_17e2d.db"
const E2E_SCOPE: String = "P1-17E2E OpenDAoC real SQL local directory report"
const E2E_CHECKPOINT: String = "P1_17E2E_OPENDAOC_REAL_SQL_LOCAL_REPORT"
const DEFAULT_REAL_DB_JSON_REPORT_PATH: String = "res://reports/daoc_opendaoc_sql_realdb_report.json"
const DEFAULT_REAL_DB_TEXT_REPORT_PATH: String = "res://reports/daoc_opendaoc_sql_realdb_report.txt"
const DEFAULT_LOCAL_SQL_DIRS: Array = [
	"res://data/server_dumps/opendaoc/opendaoc-db-core",
	"res://data/server_instruction_db/opendaoc-db-core",
	"res://opendaoc-db-core",
]

const WORLD_DESTINATION_TABLE_HINTS: Array = [
	"zonepoint",
	"jumppoint",
	"dbjumppoint",
	"regions",
	"region",
	"startuplocation",
	"door",
	"bindpoint",
	"teleport",
]

const DUNGEON_REGION_IDS: Array = [20, 21]
const DUNGEON_NAMES: Array = ["barrows", "stonehenge", "mithra", "tomb of mithra"]

var loaded_slot_db: Dictionary = {}
var loaded_tables: Dictionary = {}
var last_report: Dictionary = {}
var warnings: Array = []
var errors: Array = []


func load_slot_db(path: String = DEFAULT_SLOT_DB_PATH) -> Dictionary:
	loaded_slot_db.clear()
	warnings.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("slot db not found: %s" % path)
		return _result(false, path)
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("slot db is not JSON dictionary: %s" % path)
		return _result(false, path)
	loaded_slot_db = parsed as Dictionary
	if str(loaded_slot_db.get("checkpoint", "")) != CHECKPOINT:
		warnings.append("slot db checkpoint mismatch: %s" % str(loaded_slot_db.get("checkpoint", "")))
	return _result(true, path)


func parse_sql_text(table_id: String, sql_text: String, options: Dictionary = {}) -> Dictionary:
	var normalized_table_id: String = _normalize_id(table_id)
	var table_name: String = str(options.get("table_name", "")).strip_edges()
	if table_name == "":
		table_name = _infer_table_name(sql_text, normalized_table_id)
	var expected_columns: Array = options.get("expected_columns", []) as Array
	var columns: Array = _infer_insert_columns(sql_text, expected_columns)
	var default_max_rows: int = 32
	if _is_world_destination_table_id(normalized_table_id):
		default_max_rows = 512
	if _is_offline_preview_entity_table_id(normalized_table_id):
		default_max_rows = 512
	var rows: Array = _parse_insert_rows(sql_text, columns, int(options.get("max_rows", default_max_rows)))
	var mentioned_regions: Array = _extract_region_mentions(sql_text)
	var name_hits: Array = _extract_name_hits(sql_text)
	var missing_expected: Array = []
	for col_value in expected_columns:
		var col: String = str(col_value)
		if not _array_has_case_insensitive(columns, col):
			missing_expected.append(col)
	var result: Dictionary = {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"table_id": normalized_table_id,
		"table_name": table_name,
		"source_kind": "sql_text",
		"insert_column_count": columns.size(),
		"columns": columns,
		"rows_sample": rows,
		"rows_sample_count": rows.size(),
		"estimated_insert_row_count": _estimate_insert_row_count(sql_text),
		"mentioned_regions": mentioned_regions,
		"dungeon_region_mentions": _filter_ints(mentioned_regions, DUNGEON_REGION_IDS),
		"name_hits": name_hits,
		"expected_columns": expected_columns.duplicate(true),
		"missing_expected_columns": missing_expected,
		"coverage_status": "parsed" if missing_expected.is_empty() else "parsed_missing_expected_columns",
	}
	loaded_tables[normalized_table_id] = result.duplicate(true)
	return result


func parse_sql_file(table_id: String, path: String, options: Dictionary = {}) -> Dictionary:
	if path.strip_edges() == "":
		return _table_error(table_id, path, "empty sql path")
	if not FileAccess.file_exists(path):
		return _table_error(table_id, path, "sql file not found")
	var text: String = FileAccess.get_file_as_string(path)
	var opts: Dictionary = options.duplicate(true)
	opts["source_path"] = path
	var result: Dictionary = parse_sql_text(table_id, text, opts)
	result["source_kind"] = "sql_file"
	result["source_path"] = path
	loaded_tables[_normalize_id(table_id)] = result.duplicate(true)
	return result


func parse_sql_directory(path: String, requested_slots: Array = [], options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _empty_report("sql_directory", path)
	if path.strip_edges() == "":
		report["errors"].append("empty directory path")
		return report
	if not DirAccess.dir_exists_absolute(path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		report["errors"].append("directory not found: %s" % path)
		return report
	var dir_path: String = path
	if not DirAccess.dir_exists_absolute(dir_path):
		dir_path = ProjectSettings.globalize_path(path)
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	var slot_specs: Array = requested_slots
	if slot_specs.is_empty() and not loaded_slot_db.is_empty():
		slot_specs = loaded_slot_db.get("opendaoc_sql_slots", []) as Array
	for spec_value in slot_specs:
		if typeof(spec_value) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = spec_value as Dictionary
		var table_id: String = str(spec.get("id", ""))
		var candidates: Array = spec.get("file_candidates", []) as Array
		var found_path: String = _find_candidate_file(dir_path, files, candidates)
		if found_path == "":
			report["missing_slots"].append(table_id)
			continue
		var parse_options: Dictionary = {"expected_columns": spec.get("expected_columns", [])}
		var max_rows_by_table: Dictionary = options.get("max_rows_by_table", {}) as Dictionary
		if max_rows_by_table.has(table_id):
			parse_options["max_rows"] = int(max_rows_by_table[table_id])
		elif max_rows_by_table.has(str(table_id).to_lower()):
			parse_options["max_rows"] = int(max_rows_by_table[str(table_id).to_lower()])
		elif options.has("max_rows"):
			parse_options["max_rows"] = int(options.get("max_rows", 0))
		var parsed: Dictionary = parse_sql_file(table_id, found_path, parse_options)
		report["tables"].append(parsed)
	_finalize_report(report)
	last_report = report.duplicate(true)
	return report


func build_coverage_report(tables: Array = []) -> Dictionary:
	var report: Dictionary = _empty_report("loaded_tables", "")
	var table_list: Array = tables
	if table_list.is_empty():
		for value in loaded_tables.values():
			table_list.append((value as Dictionary).duplicate(true))
	for table_value in table_list:
		if typeof(table_value) == TYPE_DICTIONARY:
			report["tables"].append((table_value as Dictionary).duplicate(true))
	_finalize_report(report)
	last_report = report.duplicate(true)
	return report


func normalize_world_destination_rows(table_result: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = table_result.get("rows_sample", []) as Array
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value as Dictionary
		var dest: Dictionary = _normalize_world_destination_row(str(table_result.get("table_id", "")), row)
		if not dest.is_empty():
			out.append(dest)
	return out



func find_local_sql_directory(paths: Array = []) -> Dictionary:
	var candidates: Array = paths.duplicate(true)
	if candidates.is_empty():
		candidates = DEFAULT_LOCAL_SQL_DIRS.duplicate(true)
	var checked: Array = []
	for candidate_value in candidates:
		var candidate: String = str(candidate_value).strip_edges()
		if candidate == "":
			continue
		checked.append(candidate)
		var resolved: String = _resolve_directory_path(candidate)
		if resolved != "":
			var sql_count: int = _count_sql_files(resolved)
			if sql_count > 0:
				return {
					"ok": true,
					"scope": E2E_SCOPE,
					"checkpoint": E2E_CHECKPOINT,
					"abstract_only": true,
					"runtime_enabled": false,
					"coordinate_frame_confirmed": false,
					"status": "found_local_sql_directory",
					"source_path": candidate,
					"resolved_path": resolved,
					"sql_file_count": sql_count,
					"checked_paths": checked,
				}
	return {
		"ok": true,
		"scope": E2E_SCOPE,
		"checkpoint": E2E_CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"status": "waiting_for_local_sql_directory",
		"source_path": "",
		"resolved_path": "",
		"sql_file_count": 0,
		"checked_paths": checked,
		"message": "Copier opendaoc-db-core dans un des chemins attendus ou passer un chemin explicite; aucun effet runtime.",
	}


func parse_configured_directory(path: String = "", candidate_paths: Array = [], options: Dictionary = {}) -> Dictionary:
	var chosen_path: String = path.strip_edges()
	if chosen_path == "":
		var found: Dictionary = find_local_sql_directory(candidate_paths)
		if str(found.get("status", "")) != "found_local_sql_directory":
			var waiting: Dictionary = _empty_report("configured_directory", "")
			waiting["scope"] = E2E_SCOPE
			waiting["checkpoint"] = E2E_CHECKPOINT
			waiting["ok"] = true
			waiting["status"] = "waiting_for_local_sql_directory"
			waiting["checked_paths"] = found.get("checked_paths", [])
			waiting["message"] = found.get("message", "")
			last_report = waiting.duplicate(true)
			return waiting
		chosen_path = str(found.get("resolved_path", ""))
	var report: Dictionary = parse_sql_directory(chosen_path, [], options)
	report["scope"] = E2E_SCOPE
	report["checkpoint"] = E2E_CHECKPOINT
	report["status"] = "parsed_local_sql_directory" if bool(report.get("ok", false)) else "local_sql_directory_parse_error"
	report["barrows_mithra_summary"] = build_barrows_mithra_summary(report)
	last_report = report.duplicate(true)
	return report


func build_barrows_mithra_summary(report: Dictionary = {}) -> Dictionary:
	var source: Dictionary = report
	if source.is_empty():
		source = last_report
	var tables: Array = source.get("tables", []) as Array
	var out: Dictionary = {
		"scope": E2E_SCOPE,
		"checkpoint": E2E_CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"barrows": _dungeon_target_summary("barrows", 20, ["barrows", "stonehenge"], tables),
		"mithra": _dungeon_target_summary("mithra", 21, ["mithra", "tomb of mithra"], tables),
		"decision": "do_not_apply_runtime_spawn_until_coordinate_frame_confirmed",
	}
	return out


func export_last_report_json(path: String = DEFAULT_REAL_DB_JSON_REPORT_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_REAL_DB_JSON_REPORT_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"scope": E2E_SCOPE,
			"checkpoint": E2E_CHECKPOINT,
			"path": target_path,
			"error": "cannot open report for write",
		}
	file.store_string(JSON.stringify(last_report, "  "))
	file.close()
	return {
		"ok": true,
		"scope": E2E_SCOPE,
		"checkpoint": E2E_CHECKPOINT,
		"path": target_path,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
	}


func export_last_report_text(path: String = DEFAULT_REAL_DB_TEXT_REPORT_PATH) -> Dictionary:
	var target_path: String = path.strip_edges()
	if target_path == "":
		target_path = DEFAULT_REAL_DB_TEXT_REPORT_PATH
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"scope": E2E_SCOPE,
			"checkpoint": E2E_CHECKPOINT,
			"path": target_path,
			"error": "cannot open report for write",
		}
	file.store_string(_report_as_text(last_report))
	file.close()
	return {
		"ok": true,
		"scope": E2E_SCOPE,
		"checkpoint": E2E_CHECKPOINT,
		"path": target_path,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
	}


func debug_snapshot() -> Dictionary:
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"slot_db_loaded": not loaded_slot_db.is_empty(),
		"loaded_table_count": loaded_tables.size(),
		"last_report": last_report.duplicate(true),
		"warnings": warnings.duplicate(true),
		"errors": errors.duplicate(true),
	}


func _infer_table_name(sql_text: String, fallback: String) -> String:
	var dml_idx: int = _find_dml_start(sql_text)
	if dml_idx < 0:
		return fallback
	var lower: String = sql_text.to_lower()
	var key_len: int = 0
	if lower.find("insert into", dml_idx) == dml_idx:
		key_len = "insert into".length()
	elif lower.find("replace into", dml_idx) == dml_idx:
		key_len = "replace into".length()
	if key_len <= 0:
		return fallback
	var tail: String = sql_text.substr(dml_idx + key_len, 160).strip_edges()
	if tail.begins_with("`"):
		var end_tick: int = tail.find("`", 1)
		if end_tick > 1:
			return tail.substr(1, end_tick - 1)
	var stop: int = tail.find(" ")
	var paren: int = tail.find("(")
	if stop < 0 or (paren >= 0 and paren < stop):
		stop = paren
	if stop > 0:
		return tail.substr(0, stop).strip_edges().trim_prefix("`").trim_suffix("`")
	return fallback


func _infer_insert_columns(sql_text: String, fallback_columns: Array = []) -> Array:
	var dml_idx: int = _find_dml_start(sql_text)
	if dml_idx >= 0:
		var lower: String = sql_text.to_lower()
		var values_idx: int = lower.find("values", dml_idx)
		if values_idx > dml_idx:
			var first_paren: int = sql_text.find("(", dml_idx)
			# OpenDAoC real dumps use REPLACE INTO `table` (`Col`, ...) VALUES.
			# If the first parenthesis is after VALUES, it is a row tuple, not a column list.
			if first_paren >= 0 and first_paren < values_idx:
				var close_paren: int = _find_matching_paren(sql_text, first_paren)
				if close_paren > first_paren and close_paren < values_idx:
					var chunk: String = sql_text.substr(first_paren + 1, close_paren - first_paren - 1)
					var columns: Array = _parse_column_list(chunk)
					if not columns.is_empty():
						return columns
	var create_columns: Array = _infer_create_table_columns(sql_text)
	if not create_columns.is_empty():
		return create_columns
	return fallback_columns.duplicate(true)


func _parse_column_list(chunk: String) -> Array:
	var columns: Array = []
	for part_value in chunk.split(",", false):
		var col: String = str(part_value).strip_edges().trim_prefix("`").trim_suffix("`")
		if col != "":
			columns.append(col)
	return columns


func _infer_create_table_columns(sql_text: String) -> Array:
	var lower: String = sql_text.to_lower()
	var create_idx: int = lower.find("create table")
	if create_idx < 0:
		return []
	var first_paren: int = sql_text.find("(", create_idx)
	if first_paren < 0:
		return []
	var close_paren: int = _find_matching_paren(sql_text, first_paren)
	if close_paren <= first_paren:
		return []
	var body: String = sql_text.substr(first_paren + 1, close_paren - first_paren - 1)
	var columns: Array = []
	for raw_line in body.split("\n", true):
		var line: String = str(raw_line).strip_edges()
		if not line.begins_with("`"):
			continue
		var end_tick: int = line.find("`", 1)
		if end_tick > 1:
			columns.append(line.substr(1, end_tick - 1))
	return columns


func _find_dml_start(sql_text: String) -> int:
	var lower: String = sql_text.to_lower()
	var insert_idx: int = lower.find("insert into")
	var replace_idx: int = lower.find("replace into")
	if insert_idx < 0:
		return replace_idx
	if replace_idx < 0:
		return insert_idx
	return mini(insert_idx, replace_idx)


func _parse_insert_rows(sql_text: String, columns: Array, max_rows: int) -> Array:
	var out: Array = []
	if columns.is_empty() or max_rows == 0:
		return out
	var lower: String = sql_text.to_lower()
	var dml_idx: int = _find_dml_start(sql_text)
	var values_idx: int = lower.find("values", maxi(dml_idx, 0))
	if values_idx < 0:
		return out
	var i: int = sql_text.find("(", values_idx)
	while i >= 0 and (max_rows < 0 or out.size() < max_rows):
		var end: int = _find_matching_paren(sql_text, i)
		if end <= i:
			break
		var tuple_text: String = sql_text.substr(i + 1, end - i - 1)
		var values: Array = _split_sql_tuple(tuple_text)
		var row: Dictionary = {}
		var max_col: int = columns.size()
		if values.size() < max_col:
			max_col = values.size()
		for col_index in range(max_col):
			row[str(columns[col_index])] = values[col_index]
		out.append(row)
		var next_pos: int = end + 1
		while next_pos < sql_text.length() and sql_text.substr(next_pos, 1).strip_edges() == "":
			next_pos += 1
		if next_pos >= sql_text.length() or sql_text.substr(next_pos, 1) != ",":
			break
		i = sql_text.find("(", next_pos)
	return out


func _split_sql_tuple(tuple_text: String) -> Array:
	var out: Array = []
	var current: String = ""
	var in_quote: bool = false
	var escape_next: bool = false
	for i in range(tuple_text.length()):
		var ch: String = tuple_text.substr(i, 1)
		if escape_next:
			current += ch
			escape_next = false
			continue
		if ch == "\\" and in_quote:
			escape_next = true
			continue
		if ch == "'":
			in_quote = not in_quote
			continue
		if ch == "," and not in_quote:
			out.append(_clean_sql_value(current))
			current = ""
		else:
			current += ch
	out.append(_clean_sql_value(current))
	return out


func _clean_sql_value(value: String):
	var text: String = value.strip_edges()
	if text.to_upper() == "NULL":
		return null
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	return text


func _find_matching_paren(text: String, start: int) -> int:
	var depth: int = 0
	var in_quote: bool = false
	var escape_next: bool = false
	for i in range(start, text.length()):
		var ch: String = text.substr(i, 1)
		if escape_next:
			escape_next = false
			continue
		if ch == "\\" and in_quote:
			escape_next = true
			continue
		if ch == "'":
			in_quote = not in_quote
			continue
		if in_quote:
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i
	return -1


func _estimate_insert_row_count(sql_text: String) -> int:
	var lower: String = sql_text.to_lower()
	var values_idx: int = lower.find("values")
	if values_idx < 0:
		return 0
	var count: int = 0
	var in_quote: bool = false
	var escape_next: bool = false
	for i in range(values_idx, sql_text.length()):
		var ch: String = sql_text.substr(i, 1)
		if escape_next:
			escape_next = false
			continue
		if ch == "\\" and in_quote:
			escape_next = true
			continue
		if ch == "'":
			in_quote = not in_quote
			continue
		if not in_quote and ch == "(":
			count += 1
	return count


func _extract_region_mentions(sql_text: String) -> Array:
	var mentions: Array = []
	var lower: String = sql_text.to_lower()
	for rid_value in DUNGEON_REGION_IDS:
		var rid: int = int(rid_value)
		if lower.contains("region") and lower.contains(str(rid)):
			mentions.append(rid)
		elif lower.contains(",%d," % rid) or lower.contains("(%d," % rid) or lower.contains(",%d)" % rid):
			mentions.append(rid)
	return mentions


func _extract_name_hits(sql_text: String) -> Array:
	var out: Array = []
	var lower: String = sql_text.to_lower()
	for name_value in DUNGEON_NAMES:
		var name: String = str(name_value)
		if lower.contains(name):
			out.append(name)
	return out


func _filter_ints(values: Array, allowed: Array) -> Array:
	var out: Array = []
	for value in values:
		var as_int: int = int(value)
		if allowed.has(as_int) and not out.has(as_int):
			out.append(as_int)
	return out


func _array_has_case_insensitive(values: Array, needle: String) -> bool:
	var n: String = needle.to_lower()
	for value in values:
		if str(value).to_lower() == n:
			return true
	return false


func _find_candidate_file(dir_path: String, files: PackedStringArray, candidates: Array) -> String:
	for candidate_value in candidates:
		var candidate: String = str(candidate_value).strip_edges()
		for file_name in files:
			if file_name.to_lower() == candidate.to_lower():
				return dir_path.path_join(file_name)
	return ""


func _normalize_world_destination_row(table_id: String, row: Dictionary) -> Dictionary:
	var lower_id: String = table_id.to_lower()
	var dest: Dictionary = {
		"backend": "opendaoc",
		"source": "opendaoc_sql_import",
		"authenticity": "server_db_imported_unconfirmed_frame",
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"runtime_enabled": false,
		"table_id": table_id,
		"metadata": row.duplicate(true),
	}
	if lower_id.contains("zonepoint") or lower_id.contains("jumppoint"):
		dest["target_region_id"] = _row_first_int(row, ["TargetRegion", "target_region", "RegionID", "region"])
		dest["x"] = _row_first_float(row, ["TargetX", "target_x", "X", "x"])
		dest["y"] = _row_first_float(row, ["TargetY", "target_y", "Y", "y"])
		dest["z"] = _row_first_float(row, ["TargetZ", "target_z", "Z", "z"])
		dest["heading_raw"] = _row_first_int(row, ["TargetHeading", "target_heading", "Heading", "heading"])
		dest["record_id"] = str(_row_first_any(row, ["Id", "ID", "id"]))
		return dest
	if lower_id.contains("startup"):
		dest["target_region_id"] = _row_first_int(row, ["Region", "RegionID", "region"])
		dest["x"] = _row_first_float(row, ["XPos", "X", "x"])
		dest["y"] = _row_first_float(row, ["YPos", "Y", "y"])
		dest["z"] = _row_first_float(row, ["ZPos", "Z", "z"])
		dest["heading_raw"] = _row_first_int(row, ["Heading", "heading"])
		return dest
	return {}


func _row_first_any(row: Dictionary, keys: Array):
	for key_value in keys:
		var key: String = str(key_value)
		if row.has(key):
			return row[key]
	return null


func _row_first_int(row: Dictionary, keys: Array) -> int:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0
	return int(value)


func _row_first_float(row: Dictionary, keys: Array) -> float:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0.0
	return float(value)


func _is_world_destination_table_id(table_id: String) -> bool:
	var lower_id: String = table_id.to_lower()
	return lower_id.contains("zonepoint") or lower_id.contains("jumppoint") or lower_id.contains("startup") or lower_id.contains("bindpoint") or lower_id.contains("door") or lower_id.contains("teleport")


func _is_offline_preview_entity_table_id(table_id: String) -> bool:
	var lower_id: String = table_id.to_lower()
	return lower_id.contains("mob") or lower_id.contains("door") or lower_id.contains("bindpoint") or lower_id.contains("startup") or lower_id.contains("zonepoint") or lower_id.contains("jumppoint")


func _empty_report(source_kind: String, source_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"source_kind": source_kind,
		"source_path": source_path,
		"tables": [],
		"missing_slots": [],
		"present_table_count": 0,
		"world_destination_table_count": 0,
		"dungeon_candidate_table_count": 0,
		"barrows_mithra_coverage_status": "not_checked",
		"normalized_destination_sample_count": 0,
		"warnings": [],
		"errors": [],
	}


func _finalize_report(report: Dictionary) -> void:
	var tables: Array = report.get("tables", []) as Array
	var world_count: int = 0
	var dungeon_count: int = 0
	var normalized_count: int = 0
	for table_value in tables:
		if typeof(table_value) != TYPE_DICTIONARY:
			continue
		var table: Dictionary = table_value as Dictionary
		var table_name: String = "%s %s" % [str(table.get("table_id", "")), str(table.get("table_name", ""))]
		var lower: String = table_name.to_lower()
		for hint in WORLD_DESTINATION_TABLE_HINTS:
			if lower.contains(str(hint)):
				world_count += 1
				break
		if (table.get("dungeon_region_mentions", []) as Array).size() > 0 or (table.get("name_hits", []) as Array).size() > 0:
			dungeon_count += 1
		normalized_count += normalize_world_destination_rows(table).size()
	report["present_table_count"] = tables.size()
	report["world_destination_table_count"] = world_count
	report["dungeon_candidate_table_count"] = dungeon_count
	report["normalized_destination_sample_count"] = normalized_count
	report["barrows_mithra_coverage_status"] = "candidate_data_present_unconfirmed" if dungeon_count > 0 else "no_candidate_data_loaded"
	report["ok"] = (report.get("errors", []) as Array).is_empty()


func _table_error(table_id: String, path: String, error: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"table_id": _normalize_id(table_id),
		"source_path": path,
		"error": error,
	}


func _result(ok: bool, path: String) -> Dictionary:
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"path": path,
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"slot_count": (loaded_slot_db.get("opendaoc_sql_slots", []) as Array).size() if not loaded_slot_db.is_empty() else 0,
		"warnings": warnings.duplicate(true),
		"errors": errors.duplicate(true),
	}



func _resolve_directory_path(path: String) -> String:
	if path.strip_edges() == "":
		return ""
	if DirAccess.dir_exists_absolute(path):
		return path
	var globalized: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(globalized):
		return globalized
	return ""


func _count_sql_files(dir_path: String) -> int:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	var count: int = 0
	for file_name in files:
		if str(file_name).to_lower().ends_with(".sql"):
			count += 1
	return count


func _dungeon_target_summary(target_id: String, region_id: int, names: Array, tables: Array) -> Dictionary:
	var table_hits: Array = []
	var normalized_destination_count: int = 0
	var normalized_samples: Array = []
	for table_value in tables:
		if typeof(table_value) != TYPE_DICTIONARY:
			continue
		var table: Dictionary = table_value as Dictionary
		var hits_region: bool = (table.get("dungeon_region_mentions", []) as Array).has(region_id)
		var hits_name: bool = false
		var name_hits: Array = table.get("name_hits", []) as Array
		for name_value in names:
			if name_hits.has(str(name_value)):
				hits_name = true
				break
		var dest_rows: Array = normalize_world_destination_rows(table)
		for dest_value in dest_rows:
			if typeof(dest_value) != TYPE_DICTIONARY:
				continue
			var dest: Dictionary = dest_value as Dictionary
			if int(dest.get("target_region_id", -1)) == region_id:
				normalized_destination_count += 1
				if normalized_samples.size() < 4:
					normalized_samples.append(dest.duplicate(true))
		if hits_region or hits_name:
			table_hits.append({
				"table_id": table.get("table_id", ""),
				"table_name": table.get("table_name", ""),
				"hits_region": hits_region,
				"hits_name": hits_name,
				"rows_sample_count": table.get("rows_sample_count", 0),
			})
	var status: String = "missing"
	if normalized_destination_count > 0:
		status = "destination_candidates_unconfirmed"
	elif not table_hits.is_empty():
		status = "table_candidates_unconfirmed"
	return {
		"id": target_id,
		"server_region_id": region_id,
		"status": status,
		"table_hit_count": table_hits.size(),
		"destination_candidate_count": normalized_destination_count,
		"table_hits": table_hits,
		"normalized_destination_samples": normalized_samples,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
	}


func _report_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s" % str(report.get("scope", E2E_SCOPE)))
	lines.append("checkpoint=%s" % str(report.get("checkpoint", E2E_CHECKPOINT)))
	lines.append("ok=%s status=%s" % [str(report.get("ok", false)), str(report.get("status", ""))])
	lines.append("source_path=%s" % str(report.get("source_path", "")))
	lines.append("present_table_count=%d" % int(report.get("present_table_count", 0)))
	lines.append("world_destination_table_count=%d" % int(report.get("world_destination_table_count", 0)))
	lines.append("dungeon_candidate_table_count=%d" % int(report.get("dungeon_candidate_table_count", 0)))
	lines.append("normalized_destination_sample_count=%d" % int(report.get("normalized_destination_sample_count", 0)))
	lines.append("runtime_enabled=%s coordinate_frame_confirmed=%s" % [str(report.get("runtime_enabled", false)), str(report.get("coordinate_frame_confirmed", false))])
	var summary: Dictionary = report.get("barrows_mithra_summary", {}) as Dictionary
	if not summary.is_empty():
		var barrows: Dictionary = summary.get("barrows", {}) as Dictionary
		var mithra: Dictionary = summary.get("mithra", {}) as Dictionary
		lines.append("barrows=%s destinations=%d tables=%d" % [str(barrows.get("status", "")), int(barrows.get("destination_candidate_count", 0)), int(barrows.get("table_hit_count", 0))])
		lines.append("mithra=%s destinations=%d tables=%d" % [str(mithra.get("status", "")), int(mithra.get("destination_candidate_count", 0)), int(mithra.get("table_hit_count", 0))])
		lines.append("decision=%s" % str(summary.get("decision", "")))
	return "\n".join(lines)


func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
