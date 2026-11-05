extends RefCounted
class_name DaocOpenDaocPacketLog

const DaocOpenDaocPacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")

var entries: Array = []
var codec: RefCounted = DaocOpenDaocPacketCodecScript.new()


func clear() -> void:
	entries.clear()


func log_packet(direction: String, parsed: Dictionary, raw_packet: PackedByteArray, checksum_report: Dictionary = {}, note: String = "", redact_payload: bool = true) -> Dictionary:
	var payload: PackedByteArray = parsed.get("payload", PackedByteArray()) as PackedByteArray
	var header_size := 3 if direction == "server_to_client" else 10
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"direction": direction,
		"opcode_hex": str(parsed.get("opcode_hex", "0x??")),
		"opcode_name": str(parsed.get("opcode_name", "")),
		"payload_size": int(parsed.get("payload_size", payload.size())),
		"total_size": int(parsed.get("total_size", raw_packet.size())),
		"sequence": int(parsed.get("sequence", 0)),
		"session_id": int(parsed.get("session_id", 0)),
		"parameter": int(parsed.get("parameter", 0)),
		"checksum_value": int(parsed.get("checksum", checksum_report.get("actual", 0))),
		"checksum_status": str(checksum_report.get("checksum_status", "not_checked")),
		"parse_status": str(parsed.get("parse_status", "unknown")),
		"hex_header": codec.call("hex_dump", raw_packet.slice(0, mini(raw_packet.size(), header_size)), header_size),
		"hex_payload_redacted_or_limited": "[redacted size=%d]" % payload.size() if redact_payload else codec.call("hex_dump", payload, 96),
		"note": note,
	}
	entries.append(entry)
	return entry


func log_event(note: String, direction: String = "local") -> Dictionary:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"direction": direction,
		"opcode_hex": "",
		"opcode_name": "",
		"payload_size": 0,
		"total_size": 0,
		"sequence": 0,
		"session_id": 0,
		"parameter": 0,
		"checksum_value": 0,
		"checksum_status": "",
		"parse_status": "event",
		"hex_header": "",
		"hex_payload_redacted_or_limited": "",
		"note": note,
	}
	entries.append(entry)
	return entry


func write_reports(report_dir: String) -> Dictionary:
	_ensure_dir(report_dir)
	var json_path := report_dir.path_join("p1_20a_packet_log.json")
	var csv_path := report_dir.path_join("p1_20a_packet_log.csv")
	var json_ok := _write_text(json_path, JSON.stringify(entries, "\t"))
	var csv_ok := _write_text(csv_path, build_csv())
	return {
		"json": ProjectSettings.globalize_path(json_path) if json_ok else "",
		"csv": ProjectSettings.globalize_path(csv_path) if csv_ok else "",
		"ok": json_ok and csv_ok,
	}


func build_csv() -> String:
	var headers: Array[String] = [
		"timestamp", "direction", "opcode_hex", "opcode_name", "payload_size", "total_size",
		"sequence", "session_id", "parameter", "checksum_value", "checksum_status",
		"parse_status", "hex_header", "hex_payload_redacted_or_limited", "note",
	]
	var lines: Array[String] = [",".join(headers)]
	for raw in entries:
		var entry: Dictionary = raw as Dictionary
		var cols: Array[String] = []
		for h in headers:
			cols.append(_csv_cell(entry.get(h, "")))
		lines.append(",".join(cols))
	return "\n".join(lines) + "\n"


func _csv_cell(value: Variant) -> String:
	var s := str(value).replace("\"", "\"\"")
	if s.contains(",") or s.contains("\n") or s.contains("\""):
		return "\"%s\"" % s
	return s


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
