extends Node
class_name DaocDolPacket

## P1-N4: couche packet/framing préparatoire DOL.
## Elle ne prétend PAS connaître le vrai protocole Eden/DOL.
## Objectif: manipuler proprement header/opcode/payload, logs, buffer, stubs et hexdumps.

const HEADER_SIZE: int = 4
const MAX_TOTAL_SIZE: int = 65535
const MAX_PAYLOAD_SIZE: int = MAX_TOTAL_SIZE - HEADER_SIZE

@export var debug_packet: bool = false
@export var little_endian_default: bool = true

var opcode_registry: Dictionary = {}
var name_registry: Dictionary = {}
var receive_buffer: PackedByteArray = PackedByteArray()
var packet_log: Array = []
var sequence: int = 0
var last_error: Dictionary = {}


func reset_packet_layer() -> void:
	opcode_registry.clear()
	name_registry.clear()
	receive_buffer = PackedByteArray()
	packet_log.clear()
	sequence = 0
	last_error.clear()


func configure_packet_layer(p_debug: bool = false, p_little_endian: bool = true) -> void:
	debug_packet = p_debug
	little_endian_default = p_little_endian
	last_error.clear()


func set_debug_enabled(v: bool) -> void:
	debug_packet = v


func is_debug_enabled() -> bool:
	return debug_packet


func set_default_endian_little(v: bool) -> void:
	little_endian_default = v


func uses_little_endian() -> bool:
	return little_endian_default


func clamp_u8(v: int) -> int:
	return clampi(int(v), 0, 0xff)


func clamp_u16(v: int) -> int:
	return clampi(int(v), 0, 0xffff)


func clamp_u32(v: int) -> int:
	return clampi(int(v), 0, 0xffffffff)


func signed_i16_from_u16(v: int) -> int:
	var n := int(v) & 0xffff
	if n >= 0x8000:
		return n - 0x10000
	return n


func u16_from_signed_i16(v: int) -> int:
	return int(v) & 0xffff


func byte_array_empty() -> PackedByteArray:
	return PackedByteArray()


func byte_array_size(data: PackedByteArray) -> int:
	return data.size()


func byte_array_clone(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	return out


func byte_array_equals(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


func byte_array_prefix(data: PackedByteArray, count: int) -> PackedByteArray:
	return data.slice(0, clampi(int(count), 0, data.size()))


func byte_array_suffix(data: PackedByteArray, count: int) -> PackedByteArray:
	var c := clampi(int(count), 0, data.size())
	return data.slice(data.size() - c, data.size())


func concat_bytes(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(a)
	out.append_array(b)
	return out


func append_u8(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := byte_array_clone(data)
	out.append(clamp_u8(v))
	return out


func append_u16_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := byte_array_clone(data)
	var n := clamp_u16(v)
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
	return out


func append_u16_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := byte_array_clone(data)
	var n := clamp_u16(v)
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func append_u32_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := byte_array_clone(data)
	var n := clamp_u32(v)
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 24) & 0xff)
	return out


func append_u32_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := byte_array_clone(data)
	var n := clamp_u32(v)
	out.append((n >> 24) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func append_i16_le(data: PackedByteArray, v: int) -> PackedByteArray:
	return append_u16_le(data, u16_from_signed_i16(v))


func append_i32_le(data: PackedByteArray, v: int) -> PackedByteArray:
	return append_u32_le(data, int(v))


func append_bytes(data: PackedByteArray, extra: PackedByteArray) -> PackedByteArray:
	return concat_bytes(data, extra)


func read_u8(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i >= data.size():
		make_error("read_u8", "offset out of range")
		return 0
	return int(data[i]) & 0xff


func read_u16_le(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		make_error("read_u16_le", "offset out of range")
		return 0
	return (int(data[i]) & 0xff) | ((int(data[i + 1]) & 0xff) << 8)


func read_u16_be(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		make_error("read_u16_be", "offset out of range")
		return 0
	return ((int(data[i]) & 0xff) << 8) | (int(data[i + 1]) & 0xff)


func read_u32_le(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 3 >= data.size():
		make_error("read_u32_le", "offset out of range")
		return 0
	return (int(data[i]) & 0xff) | ((int(data[i + 1]) & 0xff) << 8) | ((int(data[i + 2]) & 0xff) << 16) | ((int(data[i + 3]) & 0xff) << 24)


func read_u32_be(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 3 >= data.size():
		make_error("read_u32_be", "offset out of range")
		return 0
	return ((int(data[i]) & 0xff) << 24) | ((int(data[i + 1]) & 0xff) << 16) | ((int(data[i + 2]) & 0xff) << 8) | (int(data[i + 3]) & 0xff)


func read_i16_le(data: PackedByteArray, offset: int = 0) -> int:
	return signed_i16_from_u16(read_u16_le(data, offset))


func read_i32_le(data: PackedByteArray, offset: int = 0) -> int:
	var v := read_u32_le(data, offset)
	if v >= 0x80000000:
		return v - 0x100000000
	return v


func bytes_to_hex(data: PackedByteArray, separator: String = " ") -> String:
	var parts: Array[String] = []
	for b in data:
		parts.append("%02X" % (int(b) & 0xff))
	return separator.join(parts)


func hex_to_bytes(text: String) -> PackedByteArray:
	var cleaned := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1).to_upper()
		if "0123456789ABCDEF".find(ch) >= 0:
			cleaned += ch
	var out := PackedByteArray()
	var i := 0
	while i + 1 < cleaned.length():
		var hi := "0123456789ABCDEF".find(cleaned.substr(i, 1))
		var lo := "0123456789ABCDEF".find(cleaned.substr(i + 1, 1))
		out.append(((hi & 0xf) << 4) | (lo & 0xf))
		i += 2
	return out


func ascii_to_bytes(text: String) -> PackedByteArray:
	return text.to_utf8_buffer()


func bytes_to_ascii_lossy(data: PackedByteArray) -> String:
	var s := ""
	for b in data:
		var n := int(b) & 0xff
		if n >= 32 and n <= 126:
			var one := PackedByteArray([n])
			s += one.get_string_from_utf8()
		else:
			s += "."
	return s


func sanitize_opcode_name(name: String) -> String:
	var s := name.strip_edges().to_upper()
	var out := ""
	for i in range(s.length()):
		var ch := s.substr(i, 1)
		if "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".find(ch) >= 0:
			out += ch
		elif ch == " " or ch == "-":
			out += "_"
	return out


func normalize_opcode_id(opcode: int) -> int:
	return clamp_u16(opcode)


func register_opcode(opcode: int, name: String) -> bool:
	var id := normalize_opcode_id(opcode)
	var clean := sanitize_opcode_name(name)
	if clean == "":
		make_error("register_opcode", "empty opcode name")
		return false
	opcode_registry[id] = clean
	name_registry[clean] = id
	return true


func unregister_opcode(opcode: int) -> bool:
	var id := normalize_opcode_id(opcode)
	if not opcode_registry.has(id):
		return false
	var name := str(opcode_registry[id])
	opcode_registry.erase(id)
	if name_registry.has(name):
		name_registry.erase(name)
	return true


func has_opcode(opcode: int) -> bool:
	return opcode_registry.has(normalize_opcode_id(opcode))


func opcode_name(opcode: int) -> String:
	var id := normalize_opcode_id(opcode)
	return str(opcode_registry.get(id, "OP_%04X" % id))


func opcode_id_by_name(name: String) -> int:
	var clean := sanitize_opcode_name(name)
	return int(name_registry.get(clean, -1))


func registry_size() -> int:
	return opcode_registry.size()


func registry_snapshot() -> Dictionary:
	var entries: Array = []
	var keys := opcode_registry.keys()
	keys.sort()
	for k in keys:
		entries.append({"opcode": int(k), "name": str(opcode_registry[k])})
	return {"count": opcode_registry.size(), "entries": entries}


func clear_registry() -> void:
	opcode_registry.clear()
	name_registry.clear()


func register_default_debug_opcodes() -> int:
	register_opcode(0x0001, "LOGIN_STUB")
	register_opcode(0x0002, "CHARLIST_REQUEST_STUB")
	register_opcode(0x0003, "ENTER_WORLD_STUB")
	register_opcode(0x0010, "POSITION_STUB")
	register_opcode(0x0011, "HEADING_STUB")
	register_opcode(0x0012, "REGIONCHANGE_STUB")
	register_opcode(0x00ff, "HANDSHAKE_PLACEHOLDER")
	return registry_size()


func compute_payload_length(payload: PackedByteArray) -> int:
	return payload.size()


func payload_length_valid(payload: PackedByteArray) -> bool:
	return payload.size() <= MAX_PAYLOAD_SIZE


func header_size() -> int:
	return HEADER_SIZE


func build_header_le(total_length: int, opcode: int) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u16_le(out, total_length)
	out = append_u16_le(out, opcode)
	return out


func build_header_be(total_length: int, opcode: int) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u16_be(out, total_length)
	out = append_u16_be(out, opcode)
	return out


func parse_header_le(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_SIZE:
		return make_error("parse_header_le", "not enough header bytes")
	return {"ok": true, "total_length": read_u16_le(data, 0), "opcode": read_u16_le(data, 2), "header_size": HEADER_SIZE, "little_endian": true}


func parse_header_be(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_SIZE:
		return make_error("parse_header_be", "not enough header bytes")
	return {"ok": true, "total_length": read_u16_be(data, 0), "opcode": read_u16_be(data, 2), "header_size": HEADER_SIZE, "little_endian": false}


func validate_header(header: Dictionary) -> bool:
	if not bool(header.get("ok", false)):
		return false
	var total := int(header.get("total_length", 0))
	var opcode := int(header.get("opcode", -1))
	if total < HEADER_SIZE or total > MAX_TOTAL_SIZE:
		make_error("validate_header", "invalid total length")
		return false
	if opcode < 0 or opcode > 0xffff:
		make_error("validate_header", "invalid opcode")
		return false
	return true


func build_packet(opcode: int, payload: PackedByteArray = PackedByteArray(), little_endian: bool = true) -> PackedByteArray:
	if not payload_length_valid(payload):
		make_error("build_packet", "payload too large")
		return PackedByteArray()
	var total := HEADER_SIZE + payload.size()
	var header := build_header_le(total, opcode) if little_endian else build_header_be(total, opcode)
	return concat_bytes(header, payload)


func parse_packet(data: PackedByteArray, little_endian: bool = true) -> Dictionary:
	var header := parse_header_le(data) if little_endian else parse_header_be(data)
	if not validate_header(header):
		return {"ok": false, "header": header, "payload": PackedByteArray()}
	var total := int(header.get("total_length", 0))
	if data.size() < total:
		return make_error("parse_packet", "incomplete packet")
	var payload := data.slice(HEADER_SIZE, total)
	return {"ok": true, "header": header, "opcode": int(header.get("opcode", 0)), "payload": payload, "packet_size": total}


func split_stream_once(stream: PackedByteArray, little_endian: bool = true) -> Dictionary:
	if stream.size() < HEADER_SIZE:
		return {"ok": false, "need_more": true, "packet": {}, "remaining": stream}
	var header := parse_header_le(stream) if little_endian else parse_header_be(stream)
	if not validate_header(header):
		return {"ok": false, "need_more": false, "packet": {}, "remaining": stream}
	var total := int(header.get("total_length", 0))
	if stream.size() < total:
		return {"ok": false, "need_more": true, "packet": {}, "remaining": stream}
	var packet_bytes := stream.slice(0, total)
	var remaining := stream.slice(total, stream.size())
	return {"ok": true, "need_more": false, "packet": parse_packet(packet_bytes, little_endian), "remaining": remaining}


func split_stream_all(stream: PackedByteArray, little_endian: bool = true) -> Dictionary:
	var packets: Array = []
	var rest := byte_array_clone(stream)
	while rest.size() >= HEADER_SIZE:
		var one := split_stream_once(rest, little_endian)
		if not bool(one.get("ok", false)):
			break
		packets.append(one.get("packet", {}))
		rest = one.get("remaining", PackedByteArray()) as PackedByteArray
	return {"packets": packets, "remaining": rest, "count": packets.size()}


func append_to_receive_buffer(data: PackedByteArray) -> int:
	receive_buffer.append_array(data)
	return receive_buffer.size()


func receive_buffer_size() -> int:
	return receive_buffer.size()


func pop_next_packet_from_buffer(little_endian: bool = true) -> Dictionary:
	var one := split_stream_once(receive_buffer, little_endian)
	if bool(one.get("ok", false)):
		receive_buffer = one.get("remaining", PackedByteArray()) as PackedByteArray
		return one.get("packet", {}) as Dictionary
	return {"ok": false, "need_more": bool(one.get("need_more", false))}


func clear_receive_buffer() -> void:
	receive_buffer = PackedByteArray()


func encode_login_stub(account: String = "debug") -> PackedByteArray:
	return ascii_to_bytes("account=%s" % account.strip_edges())


func decode_login_stub(payload: PackedByteArray) -> Dictionary:
	var text := bytes_to_ascii_lossy(payload)
	var out := {"account": ""}
	for part in text.split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() >= 2 and str(kv[0]) == "account":
			out["account"] = str(kv[1])
	return out


func encode_charlist_request_stub(session_id: String = "") -> PackedByteArray:
	return ascii_to_bytes("session=%s" % session_id.strip_edges())


func decode_charlist_request_stub(payload: PackedByteArray) -> Dictionary:
	var text := bytes_to_ascii_lossy(payload)
	var out := {"session": ""}
	for part in text.split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() >= 2 and str(kv[0]) == "session":
			out["session"] = str(kv[1])
	return out


func encode_enter_world_stub(slot: int = 0) -> PackedByteArray:
	return ascii_to_bytes("slot=%d" % int(slot))


func decode_enter_world_stub(payload: PackedByteArray) -> Dictionary:
	var text := bytes_to_ascii_lossy(payload)
	var slot := 0
	for part in text.split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() >= 2 and str(kv[0]) == "slot" and str(kv[1]).is_valid_int():
			slot = int(str(kv[1]))
	return {"slot": slot}


func encode_position_stub(pos: Dictionary) -> PackedByteArray:
	return ascii_to_bytes("zone=%d;x=%.1f;y=%.1f;z=%.1f;h=%d" % [int(pos.get("zone", 0)), float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)), int(pos.get("heading_units", 0))])


func decode_position_stub(payload: PackedByteArray) -> Dictionary:
	var out := {"zone": 0, "x": 0.0, "y": 0.0, "z": 0.0, "heading_units": 0}
	for part in bytes_to_ascii_lossy(payload).split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() < 2:
			continue
		var k := str(kv[0])
		var v := str(kv[1])
		match k:
			"zone":
				if v.is_valid_int():
					out["zone"] = int(v)
			"x":
				if v.is_valid_float():
					out["x"] = float(v)
			"y":
				if v.is_valid_float():
					out["y"] = float(v)
			"z":
				if v.is_valid_float():
					out["z"] = float(v)
			"h":
				if v.is_valid_int():
					out["heading_units"] = int(v)
	return out


func encode_heading_stub(heading_units: int = 0) -> PackedByteArray:
	return ascii_to_bytes("heading=%d" % normalize_opcode_id(heading_units))


func decode_heading_stub(payload: PackedByteArray) -> Dictionary:
	var heading := 0
	for part in bytes_to_ascii_lossy(payload).split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() >= 2 and str(kv[0]) == "heading" and str(kv[1]).is_valid_int():
			heading = int(str(kv[1]))
	return {"heading_units": heading}


func encode_regionchange_stub(zone: int = 0, region: int = 0) -> PackedByteArray:
	return ascii_to_bytes("zone=%d;region=%d" % [int(zone), int(region)])


func decode_regionchange_stub(payload: PackedByteArray) -> Dictionary:
	var out := {"zone": 0, "region": 0}
	for part in bytes_to_ascii_lossy(payload).split(";", false):
		var kv := str(part).split("=", false)
		if kv.size() < 2:
			continue
		if str(kv[0]) == "zone" and str(kv[1]).is_valid_int():
			out["zone"] = int(str(kv[1]))
		elif str(kv[0]) == "region" and str(kv[1]).is_valid_int():
			out["region"] = int(str(kv[1]))
	return out


func make_packet_log_entry(direction: String, opcode: int, payload_size: int, note: String = "") -> Dictionary:
	return {"msec": Time.get_ticks_msec(), "direction": direction, "opcode": normalize_opcode_id(opcode), "name": opcode_name(opcode), "payload_size": int(payload_size), "note": note}


func record_packet_event(direction: String, opcode: int, payload: PackedByteArray, note: String = "") -> int:
	packet_log.append(make_packet_log_entry(direction, opcode, payload.size(), note))
	if packet_log.size() > 128:
		packet_log = packet_log.slice(packet_log.size() - 128, packet_log.size())
	return packet_log.size()


func packet_log_size() -> int:
	return packet_log.size()


func packet_log_tail(max_count: int = 10) -> Array:
	var out: Array = []
	var start := maxi(0, packet_log.size() - maxi(1, int(max_count)))
	for item in packet_log.slice(start, packet_log.size()):
		if typeof(item) == TYPE_DICTIONARY:
			out.append((item as Dictionary).duplicate(true))
	return out


func clear_packet_log() -> void:
	packet_log.clear()


func set_sequence(v: int) -> void:
	sequence = maxi(0, int(v))


func next_sequence() -> int:
	sequence += 1
	return sequence


func current_sequence() -> int:
	return sequence


func sequence_valid(v: int) -> bool:
	return int(v) >= 0 and int(v) <= 0x7fffffff


func payload_checksum8(payload: PackedByteArray) -> int:
	var sum := 0
	for b in payload:
		sum = (sum + (int(b) & 0xff)) & 0xff
	return sum


func packet_checksum8(packet: PackedByteArray) -> int:
	return payload_checksum8(packet)


func attach_checksum8(payload: PackedByteArray) -> PackedByteArray:
	var out := byte_array_clone(payload)
	out.append(payload_checksum8(payload))
	return out


func verify_attached_checksum8(payload_with_checksum: PackedByteArray) -> bool:
	if payload_with_checksum.size() <= 0:
		return false
	var payload := payload_with_checksum.slice(0, payload_with_checksum.size() - 1)
	var chk := int(payload_with_checksum[payload_with_checksum.size() - 1]) & 0xff
	return payload_checksum8(payload) == chk


func describe_packet(packet: Dictionary) -> String:
	var ok := bool(packet.get("ok", false))
	var opcode := int(packet.get("opcode", -1))
	var payload: PackedByteArray = packet.get("payload", PackedByteArray()) as PackedByteArray
	return "ok=%s opcode=0x%04X name=%s payload=%d" % [str(ok), opcode & 0xffff, opcode_name(opcode), payload.size()]


func describe_header(header: Dictionary) -> String:
	return "len=%d opcode=0x%04X endian=%s" % [int(header.get("total_length", 0)), int(header.get("opcode", 0)) & 0xffff, "LE" if bool(header.get("little_endian", true)) else "BE"]


func make_error(code: String, message: String) -> Dictionary:
	last_error = {"ok": false, "code": code, "message": message, "msec": Time.get_ticks_msec()}
	return last_error.duplicate(true)


func last_error_snapshot() -> Dictionary:
	return last_error.duplicate(true)


func clear_last_error() -> void:
	last_error.clear()


func status_snapshot() -> Dictionary:
	return {"scope": p1_n4_scope(), "debug": debug_packet, "little_endian": little_endian_default, "registry_size": registry_size(), "receive_buffer_size": receive_buffer.size(), "packet_log_size": packet_log.size(), "sequence": sequence, "real_protocol_implemented": is_real_protocol_implemented()}


func p1_n4_scope() -> String:
	return "P1-N4 packet/framing preparatoire"


func is_real_protocol_implemented() -> bool:
	return false


func can_use_against_local_dol() -> bool:
	return true


func make_handshake_placeholder_packet() -> PackedByteArray:
	return build_packet(0x00ff, ascii_to_bytes("P1N4_HANDSHAKE_PLACEHOLDER"), little_endian_default)


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"reset_packet_layer", "configure_packet_layer", "set_debug_enabled", "is_debug_enabled", "set_default_endian_little",
		"uses_little_endian", "clamp_u8", "clamp_u16", "clamp_u32", "signed_i16_from_u16",
		"u16_from_signed_i16", "byte_array_empty", "byte_array_size", "byte_array_clone", "byte_array_equals",
		"byte_array_prefix", "byte_array_suffix", "concat_bytes", "append_u8", "append_u16_le",
		"append_u16_be", "append_u32_le", "append_u32_be", "append_i16_le", "append_i32_le",
		"append_bytes", "read_u8", "read_u16_le", "read_u16_be", "read_u32_le",
		"read_u32_be", "read_i16_le", "read_i32_le", "bytes_to_hex", "hex_to_bytes",
		"ascii_to_bytes", "bytes_to_ascii_lossy", "sanitize_opcode_name", "normalize_opcode_id", "register_opcode",
		"unregister_opcode", "has_opcode", "opcode_name", "opcode_id_by_name", "registry_size",
		"registry_snapshot", "clear_registry", "register_default_debug_opcodes", "compute_payload_length", "payload_length_valid",
		"header_size", "build_header_le", "build_header_be", "parse_header_le", "parse_header_be",
		"validate_header", "build_packet", "parse_packet", "split_stream_once", "split_stream_all",
		"append_to_receive_buffer", "receive_buffer_size", "pop_next_packet_from_buffer", "clear_receive_buffer", "encode_login_stub",
		"decode_login_stub", "encode_charlist_request_stub", "decode_charlist_request_stub", "encode_enter_world_stub", "decode_enter_world_stub",
		"encode_position_stub", "decode_position_stub", "encode_heading_stub", "decode_heading_stub", "encode_regionchange_stub",
		"decode_regionchange_stub", "make_packet_log_entry", "record_packet_event", "packet_log_size", "packet_log_tail",
		"clear_packet_log", "set_sequence", "next_sequence", "current_sequence", "sequence_valid",
		"payload_checksum8", "packet_checksum8", "attach_checksum8", "verify_attached_checksum8", "describe_packet",
		"describe_header", "make_error", "last_error_snapshot", "clear_last_error", "status_snapshot",
		"p1_n4_scope", "is_real_protocol_implemented", "can_use_against_local_dol", "make_handshake_placeholder_packet", "get_function_names"
	])
