extends RefCounted
class_name DaocNearbyWorldCaptureReplay

const Codec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const Decoder = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")

var _codec := Codec.new()
var _decoder := Decoder.new()


func load_server_capture(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "capture_not_found", "path": path, "packets": [], "total_bytes": 0}
	var bytes := FileAccess.get_file_as_bytes(path)
	var extracted: Dictionary = _codec.try_extract_server_packets(bytes)
	var packets: Array = extracted.get("packets", [])
	var remaining: PackedByteArray = extracted.get("remaining_buffer", PackedByteArray())
	for i in range(packets.size()): packets[i]["packet_index"] = i
	return {"ok": bool(extracted.get("ok", false)) and remaining.is_empty(), "path": path,
		"total_bytes": bytes.size(), "packet_count": packets.size(), "packets": packets,
		"remaining_bytes": remaining.size(), "truncated_packets": 1 if not remaining.is_empty() else 0,
		"frame_errors": extracted.get("errors", []), "raw_sha256": _sha256(bytes)}


func replay_server_packets(capture: Dictionary) -> Dictionary:
	if not bool(capture.get("ok", false)):
		return {"ok": false, "error": "invalid_capture", "packets": []}
	var replayed: Array = []
	var opcode_counts := {}
	var payload_sizes := {}
	var serialized := PackedByteArray()
	for source in capture.get("packets", []):
		var packet: Dictionary = source
		var wire: PackedByteArray = packet.get("packet", PackedByteArray())
		var parsed: Dictionary = _codec.parse_server_packet(wire)
		if not bool(parsed.get("ok", false)):
			return {"ok": false, "error": "replay_frame_rejected", "packet_index": replayed.size(), "packets": replayed}
		parsed.packet_index = replayed.size()
		replayed.append(parsed); serialized.append_array(wire)
		var key := "0x%02X" % int(parsed.opcode)
		opcode_counts[key] = int(opcode_counts.get(key, 0)) + 1
		if not payload_sizes.has(key): payload_sizes[key] = []
		if not payload_sizes[key].has(int(parsed.payload_size)): payload_sizes[key].append(int(parsed.payload_size))
	return {"ok": serialized.size() == int(capture.total_bytes), "packets": replayed,
		"packet_count": replayed.size(), "total_bytes": serialized.size(), "remaining_bytes": 0,
		"truncated_packets": 0, "opcode_counts": opcode_counts, "payload_size_variants": payload_sizes,
		"replay_sha256": _sha256(serialized), "source_sha256": str(capture.get("raw_sha256", "")),
		"deterministic": _sha256(serialized) == str(capture.get("raw_sha256", ""))}


func decode_nearby_world_packet(opcode: int, payload: PackedByteArray) -> Dictionary:
	return _decoder.decode_nearby_world_packet(opcode, payload)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
