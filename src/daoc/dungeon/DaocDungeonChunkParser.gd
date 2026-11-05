extends RefCounted
class_name DaocDungeonChunkParser

## P1-17A1 — parser minimal de dungeon.chunk.
## Format observé : texte, une salle NIF par ligne.

const SCOPE: String = "P1-17A1 DungeonLab foundation"
const CHECKPOINT: String = "P1_17A1_DUNGEON_CHUNK_PARSER"


func parse_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing dungeon.chunk path", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("dungeon.chunk not found", normalized_path)
	var text: String = FileAccess.get_file_as_string(normalized_path)
	return parse_text(text, normalized_path)


func parse_text(text: String, source_path: String = "") -> Dictionary:
	var chunks: Array = []
	var raw_lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var line_no: int = 0
	for raw_line in raw_lines:
		line_no += 1
		var line: String = str(raw_line).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("//"):
			continue
		chunks.append({
			"chunk_index": chunks.size(),
			"line_no": line_no,
			"nif_name": line,
			"nif_stem": line.get_file().get_basename(),
		})
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"chunk_count": chunks.size(),
		"chunks": chunks,
		"error": "",
	}


func _error(message: String, source_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"chunk_count": 0,
		"chunks": [],
		"error": message,
	}
