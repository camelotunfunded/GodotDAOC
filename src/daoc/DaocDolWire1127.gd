extends Node
class_name DaocDolWire1127

## P1-N5A: profil wire DOL 1.127 offline.
## Source: DOLSharp GameClient/GSPacketIn/PacketProcessor/PacketEncoding1110.
## Cette couche ne tente pas encore un login réel : elle formalise le header TCP 12 bytes,
## la détection version 1127 et le checksum TCP DOL pour futurs probes locaux.

const DOL_TCP_HEADER_SIZE: int = 12
const DOL_TCP_PREFIX_SIZE: int = 10
const DOL_CLIENT_PACKET_VERSION: int = 1127
const DOL_PACKET_PROCESSOR_VERSION: int = 168
const DOL_PACKET_LIB_NAME: String = "PacketLib1127"
const DOL_CLIENT_TYPE_NAME: String = "LabyrinthOfTheMinotaur"
const DOL_DEFAULT_HOST: String = "127.0.0.1"
const DOL_DEFAULT_PORT: int = 10300
const DOL_DEFAULT_UDP_PORT: int = 10400
const CLIENT_PACKET_CRYPT_KEY_REQUEST: int = 0xF4
const CLIENT_PACKET_VERSION_PROBE: int = 0xF4
const CLIENT_PACKET_LOGIN_REQUEST: int = 0xA7

@export var debug_wire: bool = false
@export var local_host: String = DOL_DEFAULT_HOST
@export var local_port: int = DOL_DEFAULT_PORT
@export var local_udp_port: int = DOL_DEFAULT_UDP_PORT

var last_error: Dictionary = {}
var last_packet_snapshot: Dictionary = {}


func reset_wire_profile() -> void:
	last_error.clear()
	last_packet_snapshot.clear()
	local_host = DOL_DEFAULT_HOST
	local_port = DOL_DEFAULT_PORT
	local_udp_port = DOL_DEFAULT_UDP_PORT


func configure_wire_profile(p_host: String = DOL_DEFAULT_HOST, p_port: int = DOL_DEFAULT_PORT, p_udp_port: int = DOL_DEFAULT_UDP_PORT, p_debug: bool = false) -> void:
	local_host = p_host.strip_edges()
	if local_host == "":
		local_host = DOL_DEFAULT_HOST
	local_port = clampi(int(p_port), 0, 65535)
	local_udp_port = clampi(int(p_udp_port), 0, 65535)
	debug_wire = p_debug
	last_error.clear()


func packet_header_size() -> int:
	return DOL_TCP_HEADER_SIZE


func dol_profile_snapshot() -> Dictionary:
	return {
		"scope": "P1-N5A DOL wire 1127 offline profile",
		"host": local_host,
		"port": local_port,
		"udp_port": local_udp_port,
		"client_version": DOL_CLIENT_PACKET_VERSION,
		"packet_processor_version": DOL_PACKET_PROCESSOR_VERSION,
		"packet_lib": DOL_PACKET_LIB_NAME,
		"client_type": DOL_CLIENT_TYPE_NAME,
		"tcp_header_size": DOL_TCP_HEADER_SIZE,
		"version_probe_packet_id": CLIENT_PACKET_VERSION_PROBE,
		"login_request_packet_id": CLIENT_PACKET_LOGIN_REQUEST,
		"crypt_key_request_packet_id": CLIENT_PACKET_CRYPT_KEY_REQUEST,
		"checksum": "DOL PacketProcessor.CalculateChecksum",
		"encryption_state_initial": "NotEncrypted",
		"real_login_implemented": false,
	}


func expected_version_probe_offsets() -> Dictionary:
	return {"major_index": 11, "minor_index": 12, "build_index": 13, "major": 1, "minor": 1, "build": 27, "version": 1127}


func dol_client_version_from_bytes(data: PackedByteArray) -> int:
	if data.size() < 14:
		make_error("version_probe_short", "DOL first packet needs at least 14 bytes for 1127 detection")
		return 0
	return (int(data[11]) & 0xff) * 1000 + (int(data[12]) & 0xff) * 100 + (int(data[13]) & 0xff)


func append_u16_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func append_u32_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffffffff
	out.append((n >> 24) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func read_u16_be(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		make_error("read_u16_be", "offset out of range")
		return 0
	return ((int(data[i]) & 0xff) << 8) | (int(data[i + 1]) & 0xff)


func read_u32_be(data: PackedByteArray, offset: int = 0) -> int:
	var i := int(offset)
	if i < 0 or i + 3 >= data.size():
		make_error("read_u32_be", "offset out of range")
		return 0
	return ((int(data[i]) & 0xff) << 24) | ((int(data[i + 1]) & 0xff) << 16) | ((int(data[i + 2]) & 0xff) << 8) | (int(data[i + 3]) & 0xff)


func build_gspacket_header_12(data_size: int, sequence: int, session_id: int, parameter: int, packet_id: int) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u16_be(out, data_size)
	out = append_u16_be(out, sequence)
	out = append_u16_be(out, session_id)
	out = append_u16_be(out, parameter)
	out = append_u16_be(out, packet_id)
	return out


func parse_gspacket_header_12(packet: PackedByteArray) -> Dictionary:
	if packet.size() < DOL_TCP_HEADER_SIZE:
		return make_error("dol_header_short", "packet shorter than DOL TCP header")
	var data_size := read_u16_be(packet, 0)
	var total_size := data_size + DOL_TCP_HEADER_SIZE
	var snap := {
		"ok": packet.size() >= total_size,
		"data_size": data_size,
		"total_size": total_size,
		"sequence": read_u16_be(packet, 2),
		"session_id": read_u16_be(packet, 4),
		"parameter": read_u16_be(packet, 6),
		"packet_id_word": read_u16_be(packet, 8),
		"packet_id": int(packet[9]) & 0xff,
		"checksum_offset": total_size - 2,
	}
	last_packet_snapshot = snap.duplicate(true)
	return snap


func dol_tcp_checksum16_region(data: PackedByteArray, offset: int, size: int) -> int:
	var val1 := 0x7e
	var val2 := 0x7e
	var start := clampi(int(offset), 0, data.size())
	var finish := clampi(start + int(size), start, data.size())
	for i in range(start, finish):
		val1 = (val1 + (int(data[i]) & 0xff)) & 0xff
		val2 = (val2 + val1) & 0xff
	return (val2 - (((val1 + val2) & 0xffff) << 8)) & 0xffff


func dol_tcp_checksum16(packet_without_checksum: PackedByteArray) -> int:
	return dol_tcp_checksum16_region(packet_without_checksum, 0, packet_without_checksum.size())


func append_dol_tcp_checksum16(packet_without_checksum: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(packet_without_checksum)
	var checksum := dol_tcp_checksum16(packet_without_checksum)
	out.append((checksum >> 8) & 0xff)
	out.append(checksum & 0xff)
	return out


func read_attached_checksum16(packet: PackedByteArray) -> int:
	if packet.size() < 2:
		make_error("checksum_missing", "packet has no checksum bytes")
		return 0
	return read_u16_be(packet, packet.size() - 2)


func verify_dol_tcp_checksum16(packet: PackedByteArray) -> bool:
	if packet.size() < DOL_TCP_HEADER_SIZE:
		make_error("verify_short", "packet too short")
		return false
	var header := parse_gspacket_header_12(packet)
	var total_size := int(header.get("total_size", 0))
	if packet.size() < total_size or total_size < 2:
		make_error("verify_size", "packet smaller than declared size")
		return false
	var calc := dol_tcp_checksum16_region(packet, 0, total_size - 2)
	var attached := read_u16_be(packet, total_size - 2)
	return calc == attached


func build_gspacket_12(packet_id: int, payload: PackedByteArray = PackedByteArray(), sequence: int = 0, session_id: int = 0, parameter: int = 0) -> PackedByteArray:
	var data_size := payload.size()
	var out := build_gspacket_header_12(data_size, sequence, session_id, parameter, packet_id)
	out.append_array(payload)
	return append_dol_tcp_checksum16(out)


func parse_gspacket_12(packet: PackedByteArray) -> Dictionary:
	var header := parse_gspacket_header_12(packet)
	if not bool(header.get("ok", false)):
		return header
	var total_size := int(header.get("total_size", 0))
	var payload := PackedByteArray()
	if total_size > DOL_TCP_HEADER_SIZE:
		payload = packet.slice(DOL_TCP_PREFIX_SIZE, total_size - 2)
	header["payload"] = payload
	header["payload_size"] = payload.size()
	header["checksum"] = read_u16_be(packet, total_size - 2)
	header["checksum_ok"] = verify_dol_tcp_checksum16(packet)
	last_packet_snapshot = header.duplicate(true)
	return header


func split_dol_tcp_stream_once(stream: PackedByteArray) -> Dictionary:
	if stream.size() < DOL_TCP_HEADER_SIZE:
		return {"ok": false, "packet": PackedByteArray(), "remaining": stream, "need_more": true}
	var data_size := read_u16_be(stream, 0)
	var total := data_size + DOL_TCP_HEADER_SIZE
	if stream.size() < total:
		return {"ok": false, "packet": PackedByteArray(), "remaining": stream, "need_more": true, "expected_total": total}
	return {"ok": true, "packet": stream.slice(0, total), "remaining": stream.slice(total, stream.size()), "need_more": false, "expected_total": total}


func split_dol_tcp_stream_all(stream: PackedByteArray) -> Array:
	var out: Array = []
	var rest := PackedByteArray()
	rest.append_array(stream)
	var guard := 0
	while rest.size() >= DOL_TCP_HEADER_SIZE and guard < 64:
		guard += 1
		var one: Dictionary = split_dol_tcp_stream_once(rest)
		if not bool(one.get("ok", false)):
			break
		out.append(one.get("packet", PackedByteArray()))
		rest = one.get("remaining", PackedByteArray()) as PackedByteArray
	return out


func detect_packet_id(packet: PackedByteArray) -> int:
	if packet.size() < 10:
		return -1
	return int(packet[9]) & 0xff


func describe_dol_gspacket(packet: PackedByteArray) -> String:
	var parsed := parse_gspacket_12(packet)
	return "DOL1127 id=0x%02X size=%d seq=0x%04X session=%d param=%d checksum=%s" % [
		int(parsed.get("packet_id", 0)),
		int(parsed.get("data_size", 0)),
		int(parsed.get("sequence", 0)),
		int(parsed.get("session_id", 0)),
		int(parsed.get("parameter", 0)),
		str(parsed.get("checksum_ok", false)),
	]


func describe_profile() -> String:
	return "DOL local profile host=%s port=%d client=%d processor=v%d lib=%s tcp_header=%d" % [
		local_host, local_port, DOL_CLIENT_PACKET_VERSION, DOL_PACKET_PROCESSOR_VERSION, DOL_PACKET_LIB_NAME, DOL_TCP_HEADER_SIZE
	]


func can_attempt_local_dol_probe() -> bool:
	return local_host.strip_edges() != "" and local_port > 0 and local_port <= 65535


func build_version_probe_1127_packet() -> PackedByteArray:
	# DOL GameClient.OnReceive lit bytes 11,12,13 du premier paquet pour obtenir 1127.
	# Avec le header DOL, cela correspond à payload[1], payload[2], payload[3].
	var payload := PackedByteArray([0, 1, 1, 27, 0, 0, 0, 0])
	return build_gspacket_12(CLIENT_PACKET_VERSION_PROBE, payload, 0, 0, 0)


func version_probe_1127_valid(packet: PackedByteArray) -> bool:
	return detect_packet_id(packet) == CLIENT_PACKET_VERSION_PROBE and dol_client_version_from_bytes(packet) == DOL_CLIENT_PACKET_VERSION and verify_dol_tcp_checksum16(packet)


func status_snapshot() -> Dictionary:
	var probe := build_version_probe_1127_packet()
	return {
		"scope": "P1-N5A DOL wire 1127 offline",
		"profile": dol_profile_snapshot(),
		"probe_size": probe.size(),
		"probe_version": dol_client_version_from_bytes(probe),
		"probe_packet_id": detect_packet_id(probe),
		"probe_checksum_ok": verify_dol_tcp_checksum16(probe),
		"last_error": last_error_snapshot(),
		"real_login_implemented": false,
	}


func p1_n5a_scope() -> String:
	return "P1-N5A: profil DOL local 1127 offline, header GSPacketIn 12 bytes, checksum PacketProcessor, version probe/CryptKeyRequest 0xF4, LoginRequest 0xA7; aucun login réel."


func is_real_login_implemented() -> bool:
	return false


func make_error(code: String, message: String) -> Dictionary:
	last_error = {"code": code, "message": message, "msec": Time.get_ticks_msec()}
	return last_error.duplicate(true)


func last_error_snapshot() -> Dictionary:
	return last_error.duplicate(true)


func clear_last_error() -> void:
	last_error.clear()


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"reset_wire_profile", "configure_wire_profile", "packet_header_size", "dol_profile_snapshot", "expected_version_probe_offsets",
		"dol_client_version_from_bytes", "append_u16_be", "append_u32_be", "read_u16_be", "read_u32_be",
		"build_gspacket_header_12", "parse_gspacket_header_12", "dol_tcp_checksum16_region", "dol_tcp_checksum16", "append_dol_tcp_checksum16",
		"read_attached_checksum16", "verify_dol_tcp_checksum16", "build_gspacket_12", "parse_gspacket_12", "split_dol_tcp_stream_once",
		"split_dol_tcp_stream_all", "detect_packet_id", "describe_dol_gspacket", "describe_profile", "can_attempt_local_dol_probe",
		"build_version_probe_1127_packet", "version_probe_1127_valid", "status_snapshot", "p1_n5a_scope", "is_real_login_implemented",
	])
