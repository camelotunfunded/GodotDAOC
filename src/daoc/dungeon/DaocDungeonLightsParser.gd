extends RefCounted
class_name DaocDungeonLightsParser

## P1-17A1 — parser minimal de lights.csv donjon.
## Format observé : x, y, z, radius_or_level.

const SCOPE: String = "P1-17A1 DungeonLab foundation"
const CHECKPOINT: String = "P1_17A1_DUNGEON_LIGHTS_PARSER"


func parse_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _empty(normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _empty(normalized_path)
	var text: String = FileAccess.get_file_as_string(normalized_path)
	return parse_text(text, normalized_path)


func parse_text(text: String, source_path: String = "") -> Dictionary:
	var lights: Array = []
	var errors: Array = []
	var raw_lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var line_no: int = 0
	for raw_line in raw_lines:
		line_no += 1
		var line: String = str(raw_line).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("//"):
			continue
		var columns: Array = _split_csv_line(line)
		if columns.size() < 4:
			errors.append("line %d has %d columns" % [line_no, columns.size()])
			continue
		lights.append({
			"light_index": lights.size(),
			"line_no": line_no,
			"x": float(str(columns[0])),
			"y": float(str(columns[1])),
			"z": float(str(columns[2])),
			"radius_or_level": float(str(columns[3])),
			"raw": line,
		})
	return {
		"ok": errors.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"light_count": lights.size(),
		"lights": lights,
		"errors": errors,
		"error": "" if errors.is_empty() else _join_strings(errors),
	}


func _split_csv_line(line: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = line.split(",", false)
	for part in parts:
		out.append(str(part).strip_edges())
	return out


func _join_strings(values: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for value in values:
		out.append(str(value))
	return "; ".join(out)


func _empty(source_path: String) -> Dictionary:
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"light_count": 0,
		"lights": [],
		"errors": [],
		"error": "",
	}
