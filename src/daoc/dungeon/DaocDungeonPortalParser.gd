extends RefCounted
class_name DaocDungeonPortalParser

## P1-17A1 — parser minimal de portals.csv.
## Format observé : première ligne = count, lignes suivantes = from_instance, from_portal, to_instance, to_portal.

const SCOPE: String = "P1-17A1 DungeonLab foundation"
const CHECKPOINT: String = "P1_17A1_DUNGEON_PORTAL_PARSER"


func parse_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing portals.csv path", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("portals.csv not found", normalized_path)
	var text: String = FileAccess.get_file_as_string(normalized_path)
	return parse_text(text, normalized_path)


func parse_text(text: String, source_path: String = "") -> Dictionary:
	var links: Array = []
	var errors: Array = []
	var data_lines: Array = []
	var raw_lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for raw_line in raw_lines:
		var line: String = str(raw_line).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("//"):
			continue
		data_lines.append(line)
	if data_lines.is_empty():
		return {
			"ok": true,
			"scope": SCOPE,
			"checkpoint": CHECKPOINT,
			"source_path": source_path,
			"declared_count": 0,
			"link_count": 0,
			"links": [],
			"errors": [],
			"error": "",
		}
	var declared_count: int = int(float(str(data_lines[0])))
	for i in range(1, data_lines.size()):
		var columns: Array = _split_csv_line(str(data_lines[i]))
		if columns.size() < 4:
			errors.append("line %d has %d columns" % [i + 1, columns.size()])
			continue
		links.append({
			"link_index": links.size(),
			"from_instance": int(float(str(columns[0]))),
			"from_portal": int(float(str(columns[1]))),
			"to_instance": int(float(str(columns[2]))),
			"to_portal": int(float(str(columns[3]))),
			"raw": str(data_lines[i]),
		})
	if declared_count != links.size():
		errors.append("declared_count=%d parsed_links=%d" % [declared_count, links.size()])
	return {
		"ok": errors.is_empty(),
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"declared_count": declared_count,
		"link_count": links.size(),
		"links": links,
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


func _error(message: String, source_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"declared_count": 0,
		"link_count": 0,
		"links": [],
		"errors": [message],
		"error": message,
	}
