extends RefCounted
class_name DaocOpenDaocPacketCodec

## OpenDAoC uses asymmetric TCP framing:
## - client -> server: 10-byte header + payload + 2-byte checksum
## - server -> client: 2-byte payload size + opcode + payload (no checksum)
const CLIENT_HEADER_SIZE: int = 10
const CLIENT_CHECKSUM_SIZE: int = 2
const CLIENT_OVERHEAD_SIZE: int = 12
const SERVER_HEADER_SIZE: int = 3
const MAX_PACKET_SIZE: int = 65535

# Compatibility names used by the existing P1-20A diagnostics.
const HEADER_PREFIX_SIZE: int = CLIENT_HEADER_SIZE
const CHECKSUM_SIZE: int = CLIENT_CHECKSUM_SIZE
const HEADER_TOTAL_SIZE: int = CLIENT_OVERHEAD_SIZE

const OPCODE_NAMES: Dictionary = {
	0x10: "CharacterSelectRequest",
	0x22: "CryptKey",
	0x28: "SessionID",
	0x2A: "LoginGranted",
	0x2B: "CharacterInitFinished",
	0x2D: "GameOpenReply",
	0x88: "PlayerPositionAndObjectID",
	0xA7: "LoginRequest",
	0xBF: "GameOpenRequest",
	0xD4: "WorldInitRequest",
	0xE8: "PlayerInitRequest",
	0xF4: "CryptKeyRequest",
	0xFC: "CharacterOverview",
	0xFD: "CharacterOverview",
	0xFF: "CharacterCreateRequest",
}

const CP1252_DECODE: Dictionary = {
	0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
	0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6,
	0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
	0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
	0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
	0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
	0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
}

var _cp1252_encode: Dictionary = {}


## Compatibility entry point: packets built by this client are always the full
## client -> server form.
func build_packet(opcode: int, payload: PackedByteArray, sequence: int = 0, session_id: int = 0, parameter: int = 0, checksum: int = 0) -> PackedByteArray:
	return build_client_packet(opcode, payload, sequence, session_id, parameter, checksum)


func build_client_packet(opcode: int, payload: PackedByteArray, sequence: int = 0, session_id: int = 0, parameter: int = 0, checksum: int = 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(u16_be_write(payload.size()))
	out.append_array(u16_be_write(sequence))
	out.append_array(u16_be_write(session_id))
	out.append_array(u16_be_write(parameter))
	out.append(0)
	out.append(int(opcode) & 0xff)
	out.append_array(payload)
	out.append_array(u16_be_write(checksum))
	return out


func build_server_packet(opcode: int, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(u16_be_write(payload.size()))
	out.append(int(opcode) & 0xff)
	out.append_array(payload)
	return out


## Compatibility entry point for client -> server packets.
func parse_packet(data: PackedByteArray) -> Dictionary:
	return parse_client_packet(data)


func parse_client_packet(data: PackedByteArray) -> Dictionary:
	if data.size() < CLIENT_OVERHEAD_SIZE:
		return {"ok": false, "direction": "client_to_server", "parse_status": "short_packet", "error": "packet shorter than 12 bytes", "total_size": data.size()}
	var payload_size := u16_be_read(data, 0)
	var total_size := payload_size + CLIENT_OVERHEAD_SIZE
	if total_size > MAX_PACKET_SIZE:
		return {"ok": false, "direction": "client_to_server", "parse_status": "declared_size_too_large", "payload_size": payload_size, "total_size": total_size}
	if data.size() < total_size:
		return {"ok": false, "direction": "client_to_server", "parse_status": "incomplete_packet", "payload_size": payload_size, "total_size": total_size, "available": data.size()}
	var opcode := int(data[9]) & 0xff
	var payload := data.slice(CLIENT_HEADER_SIZE, CLIENT_HEADER_SIZE + payload_size) if payload_size > 0 else PackedByteArray()
	return {
		"ok": true,
		"direction": "client_to_server",
		"parse_status": "ok",
		"payload_size": payload_size,
		"sequence": u16_be_read(data, 2),
		"session_id": u16_be_read(data, 4),
		"parameter": u16_be_read(data, 6),
		"reserved": int(data[8]) & 0xff,
		"opcode": opcode,
		"opcode_hex": "0x%02X" % opcode,
		"opcode_name": opcode_name(opcode),
		"payload": payload,
		"checksum": u16_be_read(data, total_size - CLIENT_CHECKSUM_SIZE),
		"checksum_present": true,
		"total_size": total_size,
		"packet": data.slice(0, total_size),
	}


func parse_server_packet(data: PackedByteArray) -> Dictionary:
	if data.size() < SERVER_HEADER_SIZE:
		return {"ok": false, "direction": "server_to_client", "parse_status": "short_packet", "error": "server packet shorter than 3 bytes", "total_size": data.size()}
	var payload_size := u16_be_read(data, 0)
	var total_size := payload_size + SERVER_HEADER_SIZE
	if total_size > MAX_PACKET_SIZE:
		return {"ok": false, "direction": "server_to_client", "parse_status": "declared_size_too_large", "payload_size": payload_size, "total_size": total_size}
	if data.size() < total_size:
		return {"ok": false, "direction": "server_to_client", "parse_status": "incomplete_packet", "payload_size": payload_size, "total_size": total_size, "available": data.size()}
	var opcode := int(data[2]) & 0xff
	var payload := data.slice(SERVER_HEADER_SIZE, total_size) if payload_size > 0 else PackedByteArray()
	return {
		"ok": true,
		"direction": "server_to_client",
		"parse_status": "ok",
		"payload_size": payload_size,
		"sequence": 0,
		"session_id": 0,
		"parameter": 0,
		"opcode": opcode,
		"opcode_hex": "0x%02X" % opcode,
		"opcode_name": opcode_name(opcode),
		"payload": payload,
		"checksum": 0,
		"checksum_present": false,
		"total_size": total_size,
		"packet": data.slice(0, total_size),
	}


## Compatibility entry point for fragmented client -> server streams.
func try_extract_packets(buffer: PackedByteArray) -> Dictionary:
	return try_extract_client_packets(buffer)


func try_extract_client_packets(buffer: PackedByteArray) -> Dictionary:
	return _try_extract(buffer, CLIENT_OVERHEAD_SIZE, true)


func try_extract_server_packets(buffer: PackedByteArray) -> Dictionary:
	return _try_extract(buffer, SERVER_HEADER_SIZE, false)


func _try_extract(buffer: PackedByteArray, overhead: int, client_packets: bool) -> Dictionary:
	var packets: Array = []
	var remaining := PackedByteArray()
	remaining.append_array(buffer)
	var errors: Array = []
	while remaining.size() >= overhead:
		var payload_size := u16_be_read(remaining, 0)
		var total_size := payload_size + overhead
		if total_size > MAX_PACKET_SIZE:
			errors.append({"parse_status": "declared_size_too_large", "payload_size": payload_size, "total_size": total_size, "available": remaining.size()})
			remaining = PackedByteArray()
			break
		if remaining.size() < total_size:
			break
		var parsed := parse_client_packet(remaining.slice(0, total_size)) if client_packets else parse_server_packet(remaining.slice(0, total_size))
		if bool(parsed.get("ok", false)):
			packets.append(parsed)
		else:
			errors.append(parsed)
			remaining = PackedByteArray()
			break
		remaining = remaining.slice(total_size, remaining.size())
	return {"ok": errors.is_empty(), "packets": packets, "remaining_buffer": remaining, "errors": errors}


func u16_be_read(data: PackedByteArray, offset: int) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		return 0
	return ((int(data[i]) & 0xff) << 8) | (int(data[i + 1]) & 0xff)


func u16_be_write(value: int) -> PackedByteArray:
	var n := int(value) & 0xffff
	return PackedByteArray([(n >> 8) & 0xff, n & 0xff])


func u16_le_read(data: PackedByteArray, offset: int) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		return 0
	return (int(data[i]) & 0xff) | ((int(data[i + 1]) & 0xff) << 8)


func u16_le_write(value: int) -> PackedByteArray:
	var n := int(value) & 0xffff
	return PackedByteArray([n & 0xff, (n >> 8) & 0xff])


func u32_le_read(data: PackedByteArray, offset: int) -> int:
	var i := int(offset)
	if i < 0 or i + 3 >= data.size():
		return 0
	return (int(data[i]) & 0xff) \
		| ((int(data[i + 1]) & 0xff) << 8) \
		| ((int(data[i + 2]) & 0xff) << 16) \
		| ((int(data[i + 3]) & 0xff) << 24)


func u32_le_write(value: int) -> PackedByteArray:
	var n := int(value)
	return PackedByteArray([n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff])


func encode_windows_1252(text: String) -> PackedByteArray:
	_ensure_cp1252_encode()
	var out := PackedByteArray()
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code <= 0x7f or (code >= 0xa0 and code <= 0xff):
			out.append(code)
		elif _cp1252_encode.has(code):
			out.append(int(_cp1252_encode[code]))
		else:
			out.append(0x3f)
	return out


func decode_windows_1252(bytes: PackedByteArray) -> String:
	var out := ""
	for raw in bytes:
		var value := int(raw) & 0xff
		var code := int(CP1252_DECODE.get(value, value))
		out += String.chr(code)
	return out


func pascal_u32_le_write(text: String) -> PackedByteArray:
	var bytes := encode_windows_1252(text)
	var out := u32_le_write(bytes.size())
	out.append_array(bytes)
	return out


func pascal_u32_le_read(data: PackedByteArray, offset: int) -> Dictionary:
	var start := int(offset)
	if start < 0 or start + 4 > data.size():
		return {"ok": false, "error": "missing_pascal_u32_length", "offset": start}
	var size := u32_le_read(data, start)
	var text_start := start + 4
	var next := text_start + size
	if size < 0 or next > data.size():
		return {"ok": false, "error": "truncated_pascal_u32_string", "offset": start, "declared_size": size, "available": data.size() - text_start}
	var text_bytes := data.slice(text_start, next)
	# OpenDAoC may include a trailing C-style NUL in the declared Pascal length.
	# Keep next_offset based on the wire length, but do not expose the terminator as text.
	while not text_bytes.is_empty() and int(text_bytes[text_bytes.size() - 1]) == 0:
		text_bytes.resize(text_bytes.size() - 1)
	return {"ok": true, "text": decode_windows_1252(text_bytes), "byte_length": size, "text_byte_length": text_bytes.size(), "next_offset": next}


func pascal_u8_read(data: PackedByteArray, offset: int) -> Dictionary:
	var start := int(offset)
	if start < 0 or start >= data.size():
		return {"ok": false, "error": "missing_pascal_u8_length", "offset": start}
	var size := int(data[start]) & 0xff
	var text_start := start + 1
	var next := text_start + size
	if next > data.size():
		return {"ok": false, "error": "truncated_pascal_u8_string", "offset": start, "declared_size": size, "available": data.size() - text_start}
	var text_bytes := data.slice(text_start, next)
	while not text_bytes.is_empty() and int(text_bytes[text_bytes.size() - 1]) == 0:
		text_bytes.resize(text_bytes.size() - 1)
	return {"ok": true, "text": decode_windows_1252(text_bytes), "byte_length": size, "text_byte_length": text_bytes.size(), "next_offset": next}


func hex_dump(data: PackedByteArray, max_len: int = 256) -> String:
	var parts: Array[String] = []
	var count := mini(data.size(), maxi(0, int(max_len)))
	for i in range(count):
		parts.append("%02X" % (int(data[i]) & 0xff))
	if data.size() > count:
		parts.append("...")
	return " ".join(parts)


func opcode_name(opcode: int) -> String:
	return str(OPCODE_NAMES.get(int(opcode) & 0xff, "Opcode_0x%02X" % (int(opcode) & 0xff)))


func _ensure_cp1252_encode() -> void:
	if not _cp1252_encode.is_empty():
		return
	for byte_value in CP1252_DECODE.keys():
		_cp1252_encode[int(CP1252_DECODE[byte_value])] = int(byte_value)
