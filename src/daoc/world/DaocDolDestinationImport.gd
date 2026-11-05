extends RefCounted
class_name DaocDolDestinationImport

## P1-17E2 offline import for DOL Teleport/ZonePoint rows.
## This only builds WorldDestination-compatible dictionaries. It does not apply
## server coordinates to the runtime scene by itself.

const SCOPE: String = "P1-17E2 DOL destination import offline"
const CHECKPOINT: String = "P1_17E2_DOL_DESTINATION_IMPORT_OFFLINE"

const TELEPORT_DEFAULT_COLUMNS := ["TeleportID", "Type", "Realm", "RegionID", "X", "Y", "Z", "Heading"]
const ZONEPOINT_DEFAULT_COLUMNS := ["Id", "SourceRegion", "SourceX", "SourceY", "SourceZ", "TargetRegion", "TargetX", "TargetY", "TargetZ", "TargetHeading", "Realm", "ClassType"]


func parse_teleport_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing Teleport.csv path", "Teleport", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("Teleport.csv not found", "Teleport", normalized_path)
	return parse_teleport_text(FileAccess.get_file_as_string(normalized_path), normalized_path)


func parse_zonepoint_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing ZonePoint.csv path", "ZonePoint", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("ZonePoint.csv not found", "ZonePoint", normalized_path)
	return parse_zonepoint_text(FileAccess.get_file_as_string(normalized_path), normalized_path)


func parse_teleport_text(text: String, source_path: String = "") -> Dictionary:
	return _parse_destination_text(text, source_path, "Teleport", TELEPORT_DEFAULT_COLUMNS)


func parse_zonepoint_text(text: String, source_path: String = "") -> Dictionary:
	return _parse_destination_text(text, source_path, "ZonePoint", ZONEPOINT_DEFAULT_COLUMNS)


func import_folder(folder_path: String) -> Dictionary:
	var normalized_path: String = folder_path.strip_edges()
	if normalized_path == "":
		return _folder_result(false, normalized_path, "", "", {}, {}, {}, ["missing DOL destination folder path"], [])
	var warnings: Array = []
	var errors: Array = []
	var teleport_path: String = _find_table_file(normalized_path, ["Teleport.csv", "teleport.csv", "Teleports.csv", "teleports.csv"])
	var zonepoint_path: String = _find_table_file(normalized_path, ["ZonePoint.csv", "zonepoint.csv", "ZonePoints.csv", "zonepoints.csv"])
	var teleport_result: Dictionary = {}
	var zonepoint_result: Dictionary = {}
	if teleport_path == "":
		warnings.append("Teleport.csv not found")
	else:
		teleport_result = parse_teleport_file(teleport_path)
		if not bool(teleport_result.get("ok", false)):
			errors.append(str(teleport_result.get("error", "Teleport.csv import failed")))
	if zonepoint_path == "":
		warnings.append("ZonePoint.csv not found")
	else:
		zonepoint_result = parse_zonepoint_file(zonepoint_path)
		if not bool(zonepoint_result.get("ok", false)):
			errors.append(str(zonepoint_result.get("error", "ZonePoint.csv import failed")))
	if teleport_path == "" and zonepoint_path == "":
		errors.append("no DOL destination CSV found")
	var context: Dictionary = build_context(teleport_result, zonepoint_result)
	return _folder_result(errors.is_empty(), normalized_path, teleport_path, zonepoint_path, teleport_result, zonepoint_result, context, errors, warnings)


func build_context(teleport_result: Dictionary = {}, zonepoint_result: Dictionary = {}) -> Dictionary:
	return {
		"dol_teleport_by_zone": _destinations_from_result(teleport_result),
		"dol_zonepoint_by_zone": _destinations_from_result(zonepoint_result),
		"dol_destination_import": {
			"scope": SCOPE,
			"checkpoint": CHECKPOINT,
			"teleport": _compact_result(teleport_result),
			"zonepoint": _compact_result(zonepoint_result),
		},
	}


func _parse_destination_text(text: String, source_path: String, table_name: String, default_columns: Array) -> Dictionary:
	var data_lines: Array = []
	var raw_lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for raw_line in raw_lines:
		var line: String = str(raw_line).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("//"):
			continue
		data_lines.append(line)
	if data_lines.is_empty():
		return _ok_result(table_name, source_path, 0, 0, 0, 0, {}, {}, [], [])

	var delimiter: String = _detect_delimiter(str(data_lines[0]))
	var first_columns: Array = _split_csv_line(str(data_lines[0]), delimiter)
	var has_header: bool = _looks_like_header(first_columns, table_name)
	var headers: Array = _normalized_headers(first_columns if has_header else default_columns)
	var first_data_index: int = 1 if has_header else 0
	var destinations_by_zone: Dictionary = {}
	var records_by_zone: Dictionary = {}
	var errors: Array = []
	var warnings: Array = []
	var parsed_count: int = 0
	var duplicate_count: int = 0
	var skipped_count: int = 0

	for i in range(first_data_index, data_lines.size()):
		var raw: String = str(data_lines[i])
		var columns: Array = _split_csv_line(raw, delimiter)
		var row: Dictionary = _row_dictionary(headers, columns)
		var destination: Dictionary = _destination_from_row(table_name, row, i + 1, raw, source_path)
		if not bool(destination.get("ok", false)):
			skipped_count += 1
			errors.append(str(destination.get("error", "invalid %s row" % table_name)))
			continue
		parsed_count += 1
		var key: int = int(destination.get("target_zone_id", -1))
		if key < 0:
			skipped_count += 1
			errors.append("%s line %d has no target zone/region" % [table_name, i + 1])
			continue
		if not records_by_zone.has(key):
			records_by_zone[key] = []
		var records: Array = records_by_zone[key] as Array
		records.append(destination)
		records_by_zone[key] = records
		if destinations_by_zone.has(key):
			duplicate_count += 1
			warnings.append("%s duplicate destination for target %d kept first row" % [table_name, key])
		else:
			destinations_by_zone[key] = destination

	return _ok_result(table_name, source_path, data_lines.size() - first_data_index, parsed_count, skipped_count, duplicate_count, destinations_by_zone, records_by_zone, errors, warnings)


func _destination_from_row(table_name: String, row: Dictionary, line_number: int, raw: String, source_path: String) -> Dictionary:
	if table_name == "Teleport":
		return _teleport_destination_from_row(row, line_number, raw, source_path)
	return _zonepoint_destination_from_row(row, line_number, raw, source_path)


func _teleport_destination_from_row(row: Dictionary, line_number: int, raw: String, source_path: String) -> Dictionary:
	var missing: Array = _missing_fields(row, [
		["RegionID", "Region", "target_region_id"],
		["X", "TargetX", "target_x"],
		["Y", "TargetY", "target_y"],
		["Z", "TargetZ", "target_z"],
	])
	if not missing.is_empty():
		return {"ok": false, "error": "Teleport line %d missing %s" % [line_number, _join_strings(missing)]}
	var region_id: int = _row_int(row, ["RegionID", "Region", "target_region_id"], -1)
	var record_id: String = _row_string(row, ["TeleportID", "TeleportId", "Id", "ID", "id"], "")
	var heading_raw: int = _row_int(row, ["Heading", "heading", "TargetHeading"], 0)
	return {
		"ok": true,
		"backend": "dol",
		"source": "dol.teleport.import",
		"authenticity": "server_imported",
		"table": "Teleport",
		"record_id": record_id,
		"TeleportID": record_id,
		"target_zone_id": region_id,
		"target_zone_id_basis": "DOL RegionID; client zone mapping unconfirmed",
		"target_region_id": region_id,
		"RegionID": region_id,
		"x": _row_float(row, ["X", "TargetX", "target_x"], 0.0),
		"y": _row_float(row, ["Y", "TargetY", "target_y"], 0.0),
		"z": _row_float(row, ["Z", "TargetZ", "target_z"], 0.0),
		"heading_raw": heading_raw,
		"Heading": heading_raw,
		"Type": _row_string(row, ["Type"], ""),
		"Realm": _row_string(row, ["Realm"], ""),
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"line_number": line_number,
		"raw": raw,
		"source_path": source_path,
	}


func _zonepoint_destination_from_row(row: Dictionary, line_number: int, raw: String, source_path: String) -> Dictionary:
	var missing: Array = _missing_fields(row, [
		["TargetRegion", "TargetRegionID", "target_region_id"],
		["TargetX", "X", "target_x"],
		["TargetY", "Y", "target_y"],
		["TargetZ", "Z", "target_z"],
	])
	if not missing.is_empty():
		return {"ok": false, "error": "ZonePoint line %d missing %s" % [line_number, _join_strings(missing)]}
	var target_region: int = _row_int(row, ["TargetRegion", "TargetRegionID", "target_region_id"], -1)
	var record_id: String = _row_string(row, ["Id", "ID", "ZonePointID", "ZonePointId"], "")
	var heading_raw: int = _row_int(row, ["TargetHeading", "Heading", "heading"], 0)
	return {
		"ok": true,
		"backend": "dol",
		"source": "dol.zonepoint.import",
		"authenticity": "server_imported",
		"table": "ZonePoint",
		"record_id": record_id,
		"Id": record_id,
		"source_region_id": _row_int(row, ["SourceRegion", "SourceRegionID", "source_region_id"], -1),
		"target_zone_id": target_region,
		"target_zone_id_basis": "DOL TargetRegion; client zone mapping unconfirmed",
		"target_region_id": target_region,
		"TargetRegion": target_region,
		"x": _row_float(row, ["TargetX", "X", "target_x"], 0.0),
		"y": _row_float(row, ["TargetY", "Y", "target_y"], 0.0),
		"z": _row_float(row, ["TargetZ", "Z", "target_z"], 0.0),
		"heading_raw": heading_raw,
		"TargetHeading": heading_raw,
		"Realm": _row_string(row, ["Realm"], ""),
		"ClassType": _row_string(row, ["ClassType"], ""),
		"coordinate_frame_confirmed": false,
		"requires_coordinate_frame_validation": true,
		"line_number": line_number,
		"raw": raw,
		"source_path": source_path,
	}


func _split_csv_line(line: String, delimiter: String) -> Array:
	var out: Array = []
	var current: String = ""
	var in_quotes: bool = false
	var i: int = 0
	while i < line.length():
		var ch: String = line.substr(i, 1)
		if ch == "\"":
			var next_is_quote: bool = i + 1 < line.length() and line.substr(i + 1, 1) == "\""
			if in_quotes and next_is_quote:
				current += "\""
				i += 2
				continue
			in_quotes = not in_quotes
		elif ch == delimiter and not in_quotes:
			out.append(current.strip_edges())
			current = ""
		else:
			current += ch
		i += 1
	out.append(current.strip_edges())
	return out


func _detect_delimiter(line: String) -> String:
	var candidates := [",", ";", "\t"]
	var best: String = ","
	var best_count: int = -1
	for candidate in candidates:
		var count: int = _count_delimiter_outside_quotes(line, str(candidate))
		if count > best_count:
			best_count = count
			best = str(candidate)
	return best


func _count_delimiter_outside_quotes(line: String, delimiter: String) -> int:
	var count: int = 0
	var in_quotes: bool = false
	for i in range(line.length()):
		var ch: String = line.substr(i, 1)
		if ch == "\"":
			in_quotes = not in_quotes
		elif ch == delimiter and not in_quotes:
			count += 1
	return count


func _looks_like_header(columns: Array, table_name: String) -> bool:
	var known_count: int = 0
	for column in columns:
		if _is_known_header(str(column), table_name):
			known_count += 1
	if known_count >= 2:
		return true
	if columns.size() > 0 and known_count >= 1 and not _is_numeric_text(str(columns[0])):
		return true
	return false


func _is_known_header(value: String, table_name: String) -> bool:
	var key: String = _norm_key(value)
	var known: Array = TELEPORT_DEFAULT_COLUMNS if table_name == "Teleport" else ZONEPOINT_DEFAULT_COLUMNS
	for item in known:
		if key == _norm_key(str(item)):
			return true
	return key in ["id", "teleportid", "zonepointid", "region", "regionid", "targetregion", "targetregionid", "targetx", "targety", "targetz", "targetheading"]


func _normalized_headers(columns: Array) -> Array:
	var out: Array = []
	for column in columns:
		out.append(_norm_key(str(column)))
	return out


func _row_dictionary(headers: Array, columns: Array) -> Dictionary:
	var out: Dictionary = {}
	for i in range(headers.size()):
		if i >= columns.size():
			continue
		var key: String = str(headers[i])
		if key == "":
			continue
		out[key] = str(columns[i]).strip_edges()
	return out


func _missing_fields(row: Dictionary, required_groups: Array) -> Array:
	var missing: Array = []
	for group in required_groups:
		var names: Array = group as Array
		if not _row_has_any(row, names):
			missing.append(str(names[0]))
	return missing


func _row_has_any(row: Dictionary, names: Array) -> bool:
	for name in names:
		var key: String = _norm_key(str(name))
		if row.has(key) and str(row[key]).strip_edges() != "":
			return true
	return false


func _row_string(row: Dictionary, names: Array, default_value: String = "") -> String:
	for name in names:
		var key: String = _norm_key(str(name))
		if row.has(key):
			return str(row[key]).strip_edges()
	return default_value


func _row_int(row: Dictionary, names: Array, default_value: int = 0) -> int:
	var text: String = _row_string(row, names, "")
	if text == "":
		return default_value
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	return default_value


func _row_float(row: Dictionary, names: Array, default_value: float = 0.0) -> float:
	var text: String = _row_string(row, names, "")
	if text == "":
		return default_value
	if text.is_valid_float() or text.is_valid_int():
		return float(text)
	return default_value


func _norm_key(text: String) -> String:
	return text.strip_edges().to_lower().replace("_", "").replace(" ", "").replace("-", "").replace(".", "")


func _is_numeric_text(text: String) -> bool:
	var s: String = text.strip_edges()
	return s.is_valid_int() or s.is_valid_float()


func _destinations_from_result(result: Dictionary) -> Dictionary:
	if typeof(result.get("destinations_by_zone", {})) == TYPE_DICTIONARY:
		return (result.get("destinations_by_zone", {}) as Dictionary).duplicate(true)
	return {}


func _find_table_file(folder_path: String, names: Array) -> String:
	for name in names:
		var candidate: String = folder_path.path_join(str(name))
		if FileAccess.file_exists(candidate):
			return candidate
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return ""
	var wanted: Dictionary = {}
	for name in names:
		wanted[_norm_filename(str(name))] = true
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and wanted.has(_norm_filename(file_name)):
			dir.list_dir_end()
			return folder_path.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""


func _norm_filename(text: String) -> String:
	return text.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"table": str(result.get("table", "")),
		"row_count": int(result.get("row_count", 0)),
		"record_count": int(result.get("record_count", 0)),
		"destination_count": int(result.get("destination_count", 0)),
		"skipped_count": int(result.get("skipped_count", 0)),
		"duplicate_count": int(result.get("duplicate_count", 0)),
		"error": str(result.get("error", "")),
	}


func _folder_result(ok: bool, folder_path: String, teleport_path: String, zonepoint_path: String, teleport_result: Dictionary, zonepoint_result: Dictionary, context: Dictionary, errors: Array, warnings: Array) -> Dictionary:
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"backend": "dol",
		"folder_path": folder_path,
		"teleport_path": teleport_path,
		"zonepoint_path": zonepoint_path,
		"teleport": teleport_result.duplicate(true),
		"zonepoint": zonepoint_result.duplicate(true),
		"context": context.duplicate(true),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"error": "" if errors.is_empty() else _join_strings(errors),
	}


func _ok_result(table_name: String, source_path: String, row_count: int, record_count: int, skipped_count: int, duplicate_count: int, destinations_by_zone: Dictionary, records_by_zone: Dictionary, errors: Array, warnings: Array) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"backend": "dol",
		"table": table_name,
		"source_path": source_path,
		"row_count": row_count,
		"record_count": record_count,
		"destination_count": destinations_by_zone.size(),
		"skipped_count": skipped_count,
		"duplicate_count": duplicate_count,
		"destinations_by_zone": destinations_by_zone.duplicate(true),
		"records_by_zone": records_by_zone.duplicate(true),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"error": "" if errors.is_empty() else _join_strings(errors),
	}


func _error(message: String, table_name: String, source_path: String) -> Dictionary:
	return _ok_result(table_name, source_path, 0, 0, 0, 0, {}, {}, [message], [])


func _join_strings(values: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for value in values:
		out.append(str(value))
	return "; ".join(out)
