extends RefCounted
class_name DaocDungeonPlaceParser

## P1-17A1 — parser minimal de dungeon.place.
## Format observé : CSV texte, 13 colonnes.
## 0: chunk_index, 1..3: x/y/z, 4: angle, 5..7: axis x/y/z, 8..12: flags/unknown.

const SCOPE: String = "P1-17A1 DungeonLab foundation"
const CHECKPOINT: String = "P1_17A1_DUNGEON_PLACE_PARSER"
const MIN_COLUMN_COUNT: int = 8


func parse_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing dungeon.place path", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("dungeon.place not found", normalized_path)
	var text: String = FileAccess.get_file_as_string(normalized_path)
	return parse_text(text, normalized_path)


func parse_text(text: String, source_path: String = "") -> Dictionary:
	var placements: Array = []
	var errors: Array = []
	var raw_lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var line_no: int = 0
	for raw_line in raw_lines:
		line_no += 1
		var line: String = str(raw_line).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("//"):
			continue
		var columns: Array = _split_csv_line(line)
		if columns.size() < MIN_COLUMN_COUNT:
			errors.append("line %d has %d columns" % [line_no, columns.size()])
			continue
		var flags: Array = []
		for i in range(8, columns.size()):
			flags.append(int(float(str(columns[i]))))
		var axis: Vector3 = Vector3(_to_float(columns[5]), _to_float(columns[6]), _to_float(columns[7]))
		placements.append({
			"instance_index": placements.size(),
			"line_no": line_no,
			"chunk_index": int(float(str(columns[0]))),
			"x": _to_float(columns[1]),
			"y": _to_float(columns[2]),
			"z": _to_float(columns[3]),
			"angle": _to_float(columns[4]),
			"axis_x": axis.x,
			"axis_y": axis.y,
			"axis_z": axis.z,
			"axis": axis,
			"flags": flags,
			"raw": line,
		})
	return {
		"ok": errors.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"placement_count": placements.size(),
		"placements": placements,
		"errors": errors,
		"error": "" if errors.is_empty() else _join_strings(errors),
	}


func _split_csv_line(line: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = line.split(",", false)
	for part in parts:
		out.append(str(part).strip_edges())
	return out


func _to_float(value: Variant) -> float:
	return float(str(value).strip_edges())


func _join_strings(values: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for value in values:
		out.append(str(value))
	return "; ".join(out)


func _error(message: String, source_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"placement_count": 0,
		"placements": [],
		"errors": [message],
		"error": message,
	}
