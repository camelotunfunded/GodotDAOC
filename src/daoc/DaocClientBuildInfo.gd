extends RefCounted
class_name DaocClientBuildInfo

## Offline extraction of stable client build hints from decompiled text.
## This is diagnostic-only: it does not infer protocol compatibility by itself.

const SCOPE: String = "P1-17E2 client build info offline"
const CHECKPOINT: String = "P1_17E2_CLIENT_BUILD_INFO_OFFLINE"


func parse_file(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path == "":
		return _error("missing client analysis file path", normalized_path)
	if not FileAccess.file_exists(normalized_path):
		return _error("client analysis file not found", normalized_path)
	return parse_text(FileAccess.get_file_as_string(normalized_path), normalized_path)


func parse_text(text: String, source_path: String = "") -> Dictionary:
	var version_line: String = _find_line(text, "Client Version:")
	var build_label: String = _between(version_line, "[", "]")
	var build_number: int = _digits_to_int(build_label)
	var build_stamp: String = _build_stamp_from_line(version_line)
	var feature_strings: Dictionary = {
		"warmap_teleport_request": text.find("WarmapTeleportRequest") >= 0,
		"zonejump_csv": text.to_lower().find("zonejump.csv") >= 0,
		"gsp_zonejump_collision_group": text.find("gspZoneJumpCollisionGroup") >= 0,
	}
	var ok: bool = version_line != "" and build_label != ""
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"client_version_line": version_line,
		"client_build_label": build_label,
		"client_build_number": build_number,
		"build_stamp": build_stamp,
		"feature_strings": feature_strings,
		"diagnostic_only": true,
		"error": "" if ok else "Client Version line not found",
	}


func _find_line(text: String, needle: String) -> String:
	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for raw_line in lines:
		var line: String = str(raw_line).strip_edges()
		if line.find(needle) >= 0:
			return line
	return ""


func _between(text: String, left: String, right: String) -> String:
	var start: int = text.find(left)
	if start < 0:
		return ""
	var end: int = text.find(right, start + left.length())
	if end < 0 or end <= start:
		return ""
	return text.substr(start + left.length(), end - start - left.length()).strip_edges()


func _build_stamp_from_line(line: String) -> String:
	var marker := "] - "
	var start: int = line.find(marker)
	if start < 0:
		return ""
	var out: String = line.substr(start + marker.length()).strip_edges()
	out = out.replace("\\n", "").replace("\");", "").replace("\"", "").strip_edges()
	return out


func _digits_to_int(text: String) -> int:
	var digits: String = ""
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 0
	return int(digits)


func _error(message: String, source_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"source_path": source_path,
		"client_version_line": "",
		"client_build_label": "",
		"client_build_number": 0,
		"build_stamp": "",
		"feature_strings": {},
		"diagnostic_only": true,
		"error": message,
	}
