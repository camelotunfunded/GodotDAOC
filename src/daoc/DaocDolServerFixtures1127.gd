extends Node
class_name DaocDolServerFixtures1127

## P1-N5D: fixtures et parseur offline des premiers paquets serveur DOL 1127.
## Source de vocabulaire : DOLSharp PacketLib168/1126/1127, GSTCPPacketOut,
## PacketOut, IPacketLib/eServerPackets, WorldInitRequestHandler.
## Cette couche ne lance pas de serveur et ne fait aucun envoi réseau.

const SERVER_TCP_HEADER_SIZE: int = 3
const SERVER_PACKET_POSITION_AND_OBJECT_ID: int = 0x20
const SERVER_PACKET_CRYPT_KEY: int = 0x22
const SERVER_PACKET_SESSION_ID: int = 0x28
const SERVER_PACKET_LOGIN_GRANTED: int = 0x2A
const SERVER_PACKET_LOGIN_DENIED: int = 0x2C
const SERVER_PACKET_REALM: int = 0xFE
const SERVER_PACKET_CHARACTER_OVERVIEW_1126: int = 0xFC
const SERVER_PACKET_CHARACTER_OVERVIEW_LEGACY: int = 0xFD

const REALM_NONE: int = 0
const REALM_ALBION: int = 1
const REALM_MIDGARD: int = 2
const REALM_HIBERNIA: int = 3

@export var debug_fixtures: bool = false
@export var offline_account: String = "testgodot"
@export var offline_server_name: String = "GodotDOL"
@export var offline_session_id: int = 1
@export var offline_realm: int = REALM_ALBION
@export var offline_object_id: int = 1
@export var offline_x: int = 32768
@export var offline_y: int = 32768
@export var offline_z: int = 2075
@export var offline_heading: int = 0

var login_flow_1127: Node = null
var last_error: Dictionary = {}
var last_fixture_snapshot: Dictionary = {}


func reset_fixture_profile() -> void:
	last_error.clear()
	last_fixture_snapshot.clear()
	offline_account = "testgodot"
	offline_server_name = "GodotDOL"
	offline_session_id = 1
	offline_realm = REALM_ALBION
	offline_object_id = 1
	offline_x = 32768
	offline_y = 32768
	offline_z = 2075
	offline_heading = 0


func setup_fixtures(p_login_flow_1127: Node = null) -> void:
	login_flow_1127 = p_login_flow_1127
	last_error.clear()


func set_login_flow_1127(p_login_flow_1127: Node) -> void:
	login_flow_1127 = p_login_flow_1127
	last_error.clear()


func configure_identity(account: String = "testgodot", server_name: String = "GodotDOL", session_id: int = 1, realm: int = REALM_ALBION) -> void:
	offline_account = sanitize_ascii(account, 32, "testgodot")
	offline_server_name = sanitize_ascii(server_name, 32, "GodotDOL")
	offline_session_id = clampi(session_id, 0, 65535)
	offline_realm = clampi(realm, REALM_NONE, REALM_HIBERNIA)
	last_error.clear()


func configure_position(object_id: int = 1, x: int = 32768, y: int = 32768, z: int = 2075, heading: int = 0) -> void:
	offline_object_id = clampi(object_id, 0, 65535)
	offline_x = clampi(x, 0, 16777215)
	offline_y = clampi(y, 0, 16777215)
	offline_z = clampi(z, 0, 65535)
	offline_heading = clampi(heading, 0, 4095)
	last_error.clear()


func set_debug_enabled(enabled: bool) -> void:
	debug_fixtures = enabled


func is_debug_enabled() -> bool:
	return debug_fixtures


func server_packet_header_size() -> int:
	return SERVER_TCP_HEADER_SIZE


func default_account() -> String:
	return offline_account


func default_server_name() -> String:
	return offline_server_name


func sanitize_ascii(text: String, max_len: int = 64, fallback: String = "") -> String:
	var s := text.strip_edges()
	var out := ""
	for i in range(s.length()):
		var code := s.unicode_at(i)
		if code >= 32 and code <= 126:
			out += s.substr(i, 1)
	out = out.substr(0, maxi(0, max_len))
	if out == "":
		out = fallback
	return out


func ascii_bytes(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in range(text.length()):
		out.append(text.unicode_at(i) & 0x7f)
	return out


func bytes_to_ascii(data: PackedByteArray) -> String:
	var clean := PackedByteArray()
	for b in data:
		var n := int(b) & 0xff
		if n == 0:
			break
		clean.append(n)
	return clean.get_string_from_ascii()


func append_u8(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	out.append(int(v) & 0xff)
	return out


func append_u16_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func append_u16_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
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


func append_u32_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffffffff
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 24) & 0xff)
	return out


func read_u8(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset >= data.size():
		make_error("read_u8", "offset out of range")
		return 0
	return int(data[offset]) & 0xff


func read_u16_be(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 1 >= data.size():
		make_error("read_u16_be", "offset out of range")
		return 0
	return ((int(data[offset]) & 0xff) << 8) | (int(data[offset + 1]) & 0xff)


func read_u16_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 1 >= data.size():
		make_error("read_u16_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8)


func read_u32_be(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 3 >= data.size():
		make_error("read_u32_be", "offset out of range")
		return 0
	return ((int(data[offset]) & 0xff) << 24) | ((int(data[offset + 1]) & 0xff) << 16) | ((int(data[offset + 2]) & 0xff) << 8) | (int(data[offset + 3]) & 0xff)


func read_u32_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 3 >= data.size():
		make_error("read_u32_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8) | ((int(data[offset + 2]) & 0xff) << 16) | ((int(data[offset + 3]) & 0xff) << 24)


func append_pascal_string(data: PackedByteArray, text: String) -> PackedByteArray:
	var bytes := ascii_bytes(text)
	var out := append_u8(data, bytes.size())
	out.append_array(bytes)
	return out


func read_pascal_string(data: PackedByteArray, offset: int = 0) -> Dictionary:
	if offset < 0 or offset >= data.size():
		return make_error("pascal_short", "missing pascal length")
	var length := read_u8(data, offset)
	var start := offset + 1
	var stop := clampi(start + length, start, data.size())
	var raw := data.slice(start, stop)
	return {"ok": stop <= data.size(), "text": bytes_to_ascii(raw), "length": length, "next_offset": stop}


func append_fixed_string(data: PackedByteArray, text: String, length: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var bytes := ascii_bytes(text)
	for i in range(maxi(0, length)):
		out.append(int(bytes[i]) if i < bytes.size() else 0)
	return out


func read_fixed_string(data: PackedByteArray, offset: int, length: int) -> String:
	var start := clampi(offset, 0, data.size())
	var stop := clampi(start + maxi(0, length), start, data.size())
	return bytes_to_ascii(data.slice(start, stop))


func server_packet_id_map() -> Dictionary:
	return {
		"PositionAndObjectID": SERVER_PACKET_POSITION_AND_OBJECT_ID,
		"CryptKey": SERVER_PACKET_CRYPT_KEY,
		"SessionID": SERVER_PACKET_SESSION_ID,
		"LoginGranted": SERVER_PACKET_LOGIN_GRANTED,
		"LoginDenied": SERVER_PACKET_LOGIN_DENIED,
		"Realm": SERVER_PACKET_REALM,
		"CharacterOverview1126": SERVER_PACKET_CHARACTER_OVERVIEW_1126,
		"CharacterOverviewLegacy": SERVER_PACKET_CHARACTER_OVERVIEW_LEGACY,
	}


func server_packet_name_for_id(packet_id: int) -> String:
	for k in server_packet_id_map().keys():
		if int(server_packet_id_map()[k]) == int(packet_id):
			return str(k)
	return "SERVER_UNKNOWN_0x%02X" % (int(packet_id) & 0xff)


func server_packet_id_for_name(name: String) -> int:
	return int(server_packet_id_map().get(name, -1))


func build_server_tcp_packet(packet_id: int, payload: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u16_be(out, payload.size())
	out = append_u8(out, packet_id)
	out.append_array(payload)
	return out


func parse_server_tcp_packet(packet: PackedByteArray) -> Dictionary:
	if packet.size() < SERVER_TCP_HEADER_SIZE:
		return make_error("server_packet_short", "packet shorter than server TCP header")
	var data_size := read_u16_be(packet, 0)
	var total_size := data_size + SERVER_TCP_HEADER_SIZE
	var payload := PackedByteArray()
	if packet.size() >= total_size:
		payload = packet.slice(SERVER_TCP_HEADER_SIZE, total_size)
	var snap := {
		"ok": packet.size() >= total_size,
		"data_size": data_size,
		"total_size": total_size,
		"packet_id": read_u8(packet, 2),
		"packet_name": server_packet_name_for_id(read_u8(packet, 2)),
		"payload": payload,
		"payload_size": payload.size(),
		"has_checksum": false,
	}
	last_fixture_snapshot = snap.duplicate(true)
	return snap


func split_server_tcp_stream_once(stream: PackedByteArray) -> Dictionary:
	if stream.size() < SERVER_TCP_HEADER_SIZE:
		return {"ok": false, "need_more": true, "packet": PackedByteArray(), "remaining": stream}
	var data_size := read_u16_be(stream, 0)
	var total := data_size + SERVER_TCP_HEADER_SIZE
	if stream.size() < total:
		return {"ok": false, "need_more": true, "expected_total": total, "packet": PackedByteArray(), "remaining": stream}
	return {"ok": true, "need_more": false, "expected_total": total, "packet": stream.slice(0, total), "remaining": stream.slice(total, stream.size())}


func split_server_tcp_stream_all(stream: PackedByteArray) -> Array:
	var out: Array = []
	var rest := PackedByteArray()
	rest.append_array(stream)
	var guard := 0
	while rest.size() >= SERVER_TCP_HEADER_SIZE and guard < 64:
		guard += 1
		var one: Dictionary = split_server_tcp_stream_once(rest)
		if not bool(one.get("ok", false)):
			break
		out.append(one.get("packet", PackedByteArray()))
		rest = one.get("remaining", PackedByteArray()) as PackedByteArray
	return out


func detect_server_packet_id(packet: PackedByteArray) -> int:
	if packet.size() < SERVER_TCP_HEADER_SIZE:
		return -1
	return read_u8(packet, 2)


func packet_payload(packet: PackedByteArray) -> PackedByteArray:
	var parsed := parse_server_tcp_packet(packet)
	return parsed.get("payload", PackedByteArray()) as PackedByteArray


func packet_summary(packet: PackedByteArray) -> String:
	var parsed := parse_server_tcp_packet(packet)
	return "%s id=0x%02X size=%d checksum=%s" % [str(parsed.get("packet_name", "?")), int(parsed.get("packet_id", 0)), int(parsed.get("data_size", 0)), str(parsed.get("has_checksum", false))]


func bytes_to_hex(data: PackedByteArray, max_bytes: int = 96) -> String:
	var parts: Array[String] = []
	var stop := mini(data.size(), maxi(0, max_bytes))
	for i in range(stop):
		parts.append("%02X" % (int(data[i]) & 0xff))
	if data.size() > stop:
		parts.append("...")
	return " ".join(parts)


func build_login_granted_payload_1127(account: String = "", server_name: String = "", color: int = 7) -> PackedByteArray:
	var acc := sanitize_ascii(account if account != "" else offline_account, 32, offline_account)
	var srv := sanitize_ascii(server_name if server_name != "" else offline_server_name, 32, offline_server_name)
	var out := PackedByteArray()
	out = append_u8(out, 0x01)
	out = append_u8(out, 0x01)
	out = append_u8(out, 0x27)
	out = append_u8(out, 0x00)
	out = append_pascal_string(out, acc)
	out = append_pascal_string(out, srv)
	out = append_u8(out, 0x0C)
	out = append_u8(out, color)
	out = append_u8(out, 0x00)
	return out


func decode_login_granted_payload_1127(payload: PackedByteArray) -> Dictionary:
	var account := read_pascal_string(payload, 4)
	var server := read_pascal_string(payload, int(account.get("next_offset", 4)))
	var next := int(server.get("next_offset", payload.size()))
	return {
		"ok": payload.size() >= next + 3,
		"flag": read_u8(payload, 0) if payload.size() > 0 else 0,
		"version_hi": read_u8(payload, 1) if payload.size() > 1 else 0,
		"version_lo": read_u8(payload, 2) if payload.size() > 2 else 0,
		"account": str(account.get("text", "")),
		"server_name": str(server.get("text", "")),
		"server_id": read_u8(payload, next) if payload.size() > next else 0,
		"color": read_u8(payload, next + 1) if payload.size() > next + 1 else 0,
	}


func build_login_granted_packet_1127(account: String = "", server_name: String = "", color: int = 7) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_LOGIN_GRANTED, build_login_granted_payload_1127(account, server_name, color))


func decode_login_granted_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_login_granted_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_login_denied_payload_1127(error_code: int = 1) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u8(out, error_code)
	out = append_u8(out, 0x01)
	out = append_u8(out, 0x01)
	out = append_u8(out, 0x27)
	out = append_u8(out, 0x00)
	return out


func decode_login_denied_payload_1127(payload: PackedByteArray) -> Dictionary:
	var err := read_u8(payload, 0) if payload.size() > 0 else 0
	return {"ok": payload.size() >= 5, "error_code": err, "error_name": login_error_name(err), "version_hi": read_u8(payload, 2) if payload.size() > 2 else 0, "version_lo": read_u8(payload, 3) if payload.size() > 3 else 0}


func build_login_denied_packet_1127(error_code: int = 1) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_LOGIN_DENIED, build_login_denied_payload_1127(error_code))


func decode_login_denied_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_login_denied_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func login_error_name(error_code: int) -> String:
	match int(error_code):
		0:
			return "None"
		1:
			return "AccountInvalid_or_NoAccess"
		2:
			return "AccountAlreadyLoggedIn"
		3:
			return "GameCurrentlyClosed"
		4:
			return "TooManyPlayers"
	return "LoginError_%d" % int(error_code)


func build_session_id_payload_1127(session_id: int = -1) -> PackedByteArray:
	var sid := offline_session_id if session_id < 0 else clampi(session_id, 0, 65535)
	return append_u16_le(PackedByteArray(), sid)


func decode_session_id_payload_1127(payload: PackedByteArray) -> Dictionary:
	return {"ok": payload.size() >= 2, "session_id": read_u16_le(payload, 0) if payload.size() >= 2 else 0}


func build_session_id_packet_1127(session_id: int = -1) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_SESSION_ID, build_session_id_payload_1127(session_id))


func decode_session_id_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_session_id_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_realm_payload_1127(realm: int = -1) -> PackedByteArray:
	var r := offline_realm if realm < 0 else clampi(realm, REALM_NONE, REALM_HIBERNIA)
	return PackedByteArray([r & 0xff])


func decode_realm_payload_1127(payload: PackedByteArray) -> Dictionary:
	var r := read_u8(payload, 0) if payload.size() > 0 else REALM_NONE
	return {"ok": payload.size() >= 1, "realm": r, "realm_name": realm_name_for_id(r)}


func build_realm_packet_1127(realm: int = -1) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_REALM, build_realm_payload_1127(realm))


func decode_realm_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_realm_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_character_overview_empty_payload_1127(enable_realm_switcher: bool = false) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u32_le(out, 1 if enable_realm_switcher else 0)
	out = append_u32_le(out, 0)
	out = append_u32_le(out, 0)
	out = append_u32_le(out, 0)
	return out


func decode_character_overview_header_1127(payload: PackedByteArray) -> Dictionary:
	return {"ok": payload.size() >= 16, "realm_switcher_flags": read_u32_le(payload, 0) if payload.size() >= 4 else 0, "header_size": mini(payload.size(), 16), "remaining_size": maxi(0, payload.size() - 16)}


func build_character_overview_empty_packet_1127(enable_realm_switcher: bool = false) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_CHARACTER_OVERVIEW_1126, build_character_overview_empty_payload_1127(enable_realm_switcher))


func decode_character_overview_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_character_overview_header_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_position_object_payload_1127(object_id: int = -1, x: int = -1, y: int = -1, z: int = -1, heading: int = -1, flags: int = 0) -> PackedByteArray:
	var oid := offline_object_id if object_id < 0 else clampi(object_id, 0, 65535)
	var px := offline_x if x < 0 else clampi(x, 0, 16777215)
	var py := offline_y if y < 0 else clampi(y, 0, 16777215)
	var pz := offline_z if z < 0 else clampi(z, 0, 65535)
	var h := offline_heading if heading < 0 else clampi(heading, 0, 4095)
	var out := PackedByteArray()
	out = append_u16_be(out, oid)
	out = append_u16_be(out, pz)
	out = append_u32_be(out, px)
	out = append_u32_be(out, py)
	out = append_u16_be(out, h)
	out = append_u8(out, flags)
	out = append_u8(out, 0)
	return out


func decode_position_object_payload_1127(payload: PackedByteArray) -> Dictionary:
	return {
		"ok": payload.size() >= 16,
		"object_id": read_u16_be(payload, 0) if payload.size() >= 2 else 0,
		"z": read_u16_be(payload, 2) if payload.size() >= 4 else 0,
		"x": read_u32_be(payload, 4) if payload.size() >= 8 else 0,
		"y": read_u32_be(payload, 8) if payload.size() >= 12 else 0,
		"heading": read_u16_be(payload, 12) if payload.size() >= 14 else 0,
		"flags": read_u8(payload, 14) if payload.size() >= 15 else 0,
	}


func build_position_object_packet_1127(object_id: int = -1, x: int = -1, y: int = -1, z: int = -1, heading: int = -1, flags: int = 0) -> PackedByteArray:
	return build_server_tcp_packet(SERVER_PACKET_POSITION_AND_OBJECT_ID, build_position_object_payload_1127(object_id, x, y, z, heading, flags))


func decode_position_object_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	parsed["decoded"] = decode_position_object_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func realm_name_for_id(realm: int) -> String:
	match int(realm):
		REALM_ALBION:
			return "Albion"
		REALM_MIDGARD:
			return "Midgard"
		REALM_HIBERNIA:
			return "Hibernia"
	return "None"


func realm_id_for_name(name: String) -> int:
	match name.strip_edges().to_lower():
		"albion", "alb":
			return REALM_ALBION
		"midgard", "mid":
			return REALM_MIDGARD
		"hibernia", "hib":
			return REALM_HIBERNIA
	return REALM_NONE


func build_server_fixture_flow() -> Array:
	var flow: Array = []
	flow.append({"name": "LoginGranted", "packet": build_login_granted_packet_1127(offline_account, offline_server_name, 7)})
	flow.append({"name": "SessionID", "packet": build_session_id_packet_1127(offline_session_id)})
	flow.append({"name": "Realm", "packet": build_realm_packet_1127(offline_realm)})
	flow.append({"name": "CharacterOverview1126Empty", "packet": build_character_overview_empty_packet_1127(false)})
	flow.append({"name": "PositionAndObjectID", "packet": build_position_object_packet_1127(offline_object_id, offline_x, offline_y, offline_z, offline_heading, 0)})
	last_fixture_snapshot = {"flow_count": flow.size(), "account": offline_account, "session_id": offline_session_id, "realm": realm_name_for_id(offline_realm)}
	return flow


func decode_server_fixture_flow(flow: Array) -> Array:
	var out: Array = []
	for item in flow:
		var d: Dictionary = item as Dictionary
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		var parsed := parse_server_tcp_packet(packet)
		parsed["name"] = str(d.get("name", parsed.get("packet_name", "packet")))
		out.append(parsed)
	return out


func fixture_flow_packet_count(flow: Array) -> int:
	return flow.size()


func fixture_flow_to_hex_lines(flow: Array, max_bytes: int = 96) -> PackedStringArray:
	var lines := PackedStringArray()
	for item in flow:
		var d: Dictionary = item as Dictionary
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		lines.append("%s %s" % [str(d.get("name", "packet")), bytes_to_hex(packet, max_bytes)])
	return lines


func fixture_flow_summary(flow: Array) -> String:
	var names: Array[String] = []
	for item in flow:
		var d: Dictionary = item as Dictionary
		names.append(str(d.get("name", "packet")))
	return "P1-N5D server fixture flow count=%d [%s]" % [flow.size(), ", ".join(names)]


func validate_server_packet(packet: PackedByteArray, expected_id: int = -1) -> Dictionary:
	var parsed := parse_server_tcp_packet(packet)
	var id := int(parsed.get("packet_id", -1))
	var ok_id := expected_id < 0 or id == expected_id
	return {"ok": bool(parsed.get("ok", false)) and ok_id, "packet_id": id, "packet_name": str(parsed.get("packet_name", "?")), "expected_id": expected_id, "data_size": int(parsed.get("data_size", 0))}


func describe_source_basis() -> String:
	return "P1-N5D source basis: GSTCPPacketOut size+id header, PacketLib168 SendLoginGranted/Denied/SessionID/Realm/PositionAndObjectID, PacketLib1126 CharacterOverview1126."


func p1_n5d_scope() -> String:
	return "P1-N5D offline server response fixtures/parser; no DOL server required; no socket live."


func is_live_server_required() -> bool:
	return false


func can_parse_offline_server_fixtures() -> bool:
	return true


func status_snapshot() -> Dictionary:
	var flow := build_server_fixture_flow()
	return {
		"scope": "P1-N5D DOL server response fixtures offline",
		"account": offline_account,
		"server_name": offline_server_name,
		"session_id": offline_session_id,
		"realm": realm_name_for_id(offline_realm),
		"flow_count": flow.size(),
		"server_packet_ids": server_packet_id_map(),
		"can_parse": can_parse_offline_server_fixtures(),
		"live_server_required": is_live_server_required(),
		"last_error": last_error_snapshot(),
	}


func last_error_snapshot() -> Dictionary:
	return last_error.duplicate(true)


func clear_last_error() -> void:
	last_error.clear()


func make_error(code: String, message: String) -> Dictionary:
	last_error = {"code": code, "message": message, "msec": Time.get_ticks_msec()}
	return last_error.duplicate(true)


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"reset_fixture_profile", "setup_fixtures", "set_login_flow_1127", "configure_identity", "configure_position",
		"set_debug_enabled", "is_debug_enabled", "server_packet_header_size", "default_account", "default_server_name",
		"sanitize_ascii", "ascii_bytes", "bytes_to_ascii", "append_u8", "append_u16_be",
		"append_u16_le", "append_u32_be", "append_u32_le", "read_u8", "read_u16_be",
		"read_u16_le", "read_u32_be", "read_u32_le", "append_pascal_string", "read_pascal_string",
		"append_fixed_string", "read_fixed_string", "server_packet_id_map", "server_packet_name_for_id", "server_packet_id_for_name",
		"build_server_tcp_packet", "parse_server_tcp_packet", "split_server_tcp_stream_once", "split_server_tcp_stream_all", "detect_server_packet_id",
		"packet_payload", "packet_summary", "bytes_to_hex", "build_login_granted_payload_1127", "decode_login_granted_payload_1127",
		"build_login_granted_packet_1127", "decode_login_granted_packet_1127", "build_login_denied_payload_1127", "decode_login_denied_payload_1127", "build_login_denied_packet_1127",
		"decode_login_denied_packet_1127", "login_error_name", "build_session_id_payload_1127", "decode_session_id_payload_1127", "build_session_id_packet_1127",
		"decode_session_id_packet_1127", "build_realm_payload_1127", "decode_realm_payload_1127", "build_realm_packet_1127", "decode_realm_packet_1127",
		"build_character_overview_empty_payload_1127", "decode_character_overview_header_1127", "build_character_overview_empty_packet_1127", "decode_character_overview_packet_1127", "build_position_object_payload_1127",
		"decode_position_object_payload_1127", "build_position_object_packet_1127", "decode_position_object_packet_1127", "realm_name_for_id", "realm_id_for_name",
		"build_server_fixture_flow", "decode_server_fixture_flow", "fixture_flow_packet_count", "fixture_flow_to_hex_lines", "fixture_flow_summary",
		"validate_server_packet", "describe_source_basis", "p1_n5d_scope", "is_live_server_required", "can_parse_offline_server_fixtures",
		"status_snapshot", "last_error_snapshot", "clear_last_error", "make_error", "get_function_names",
	])
