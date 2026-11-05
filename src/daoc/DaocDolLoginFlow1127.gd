extends Node
class_name DaocDolLoginFlow1127

## P1-N5B: encodeur offline du flow login/charselect/worldinit DOL 1127.
## Source de vocabulaire : DOLSharp LoginRequestHandler, CharacterOverviewRequestHandler,
## CharacterSelectRequestHandler, WorldInitRequestHandler, IPacketLib/eClientPackets.
## Cette couche produit des paquets DOL TCP checksummés mais ne les envoie pas.

const CLIENT_PACKET_CRYPT_KEY_REQUEST: int = 0xF4
const CLIENT_PACKET_LOGIN_REQUEST: int = 0xA7
const CLIENT_PACKET_CHARACTER_OVERVIEW_REQUEST: int = 0xFC
const CLIENT_PACKET_CHARACTER_SELECT_REQUEST: int = 0x10
const CLIENT_PACKET_WORLD_INIT_REQUEST: int = 0xD4
const CLIENT_PACKET_REGION_LIST_REQUEST: int = 0x9D

const SERVER_PACKET_CRYPT_KEY: int = 0x22
const SERVER_PACKET_LOGIN_GRANTED: int = 0x2A
const SERVER_PACKET_LOGIN_DENIED: int = 0x2C
const SERVER_PACKET_SESSION_ID: int = 0x28
const SERVER_PACKET_CHARACTER_OVERVIEW_1126: int = 0xFC
const SERVER_PACKET_REALM: int = 0xFE

const REALM_NONE: int = 0
const REALM_ALBION: int = 1
const REALM_MIDGARD: int = 2
const REALM_HIBERNIA: int = 3

@export var debug_flow: bool = false
@export var offline_account: String = "testgodot"
@export var offline_password: String = "testgodot"
@export var offline_realm: int = REALM_ALBION
@export var offline_character_index: int = 0
@export var offline_session_id: int = 0

var wire_1127: Node = null
var last_error: Dictionary = {}
var last_flow_snapshot: Dictionary = {}


func reset_flow_profile() -> void:
	last_error.clear()
	last_flow_snapshot.clear()
	offline_account = "testgodot"
	offline_password = "testgodot"
	offline_realm = REALM_ALBION
	offline_character_index = 0
	offline_session_id = 0


func setup_flow(p_wire_1127: Node = null) -> void:
	wire_1127 = p_wire_1127
	last_error.clear()


func set_wire_1127(p_wire_1127: Node) -> void:
	wire_1127 = p_wire_1127
	last_error.clear()


func configure_account(account: String = "testgodot", password: String = "testgodot") -> void:
	offline_account = sanitize_account_name(account)
	offline_password = sanitize_password(password)
	last_error.clear()


func configure_character(realm: int = REALM_ALBION, character_index: int = 0, session_id: int = 0) -> void:
	offline_realm = clampi(int(realm), REALM_NONE, REALM_HIBERNIA)
	offline_character_index = clampi(int(character_index), 0, 255)
	offline_session_id = clampi(int(session_id), 0, 65535)
	last_error.clear()


func set_debug_enabled(enabled: bool) -> void:
	debug_flow = enabled


func is_debug_enabled() -> bool:
	return debug_flow


func default_account() -> String:
	return offline_account


func default_password() -> String:
	return offline_password


func sanitize_account_name(account: String) -> String:
	var s := account.strip_edges()
	var out := ""
	for i in range(s.length()):
		var code := s.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			out += s.substr(i, 1)
	out = out.substr(0, 32)
	if out == "":
		out = "testgodot"
	return out


func sanitize_password(password: String) -> String:
	var s := password.strip_edges()
	if s.length() > 64:
		s = s.substr(0, 64)
	return s


func account_valid(account: String) -> bool:
	var s := sanitize_account_name(account)
	return s != "" and s == account.strip_edges() and s.length() <= 32


func password_valid(password: String) -> bool:
	return password.strip_edges() != "" and password.length() <= 64


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


func append_u16_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
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


func append_fixed_string(data: PackedByteArray, text: String, length: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var bytes := ascii_bytes(text)
	for i in range(maxi(0, int(length))):
		out.append(int(bytes[i]) if i < bytes.size() else 0)
	return out


func append_c_string(data: PackedByteArray, text: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	out.append_array(ascii_bytes(text))
	out.append(0)
	return out


func append_pascal_i32_le_string(data: PackedByteArray, text: String, include_null: bool = true) -> PackedByteArray:
	var bytes := ascii_bytes(text)
	var stored_len := bytes.size() + (1 if include_null else 0)
	var out := append_u32_le(data, stored_len)
	out.append_array(bytes)
	if include_null:
		out.append(0)
	return out


func read_u8(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset >= data.size():
		make_error("read_u8", "offset out of range")
		return 0
	return int(data[offset]) & 0xff


func read_u16_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 1 >= data.size():
		make_error("read_u16_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8)


func read_u32_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 3 >= data.size():
		make_error("read_u32_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8) | ((int(data[offset + 2]) & 0xff) << 16) | ((int(data[offset + 3]) & 0xff) << 24)


func read_fixed_string(data: PackedByteArray, offset: int, length: int) -> String:
	var slice := PackedByteArray()
	var start := clampi(offset, 0, data.size())
	var stop := clampi(start + maxi(0, length), start, data.size())
	for i in range(start, stop):
		slice.append(int(data[i]) & 0xff)
	return bytes_to_ascii(slice)


func read_c_string(data: PackedByteArray, offset: int = 0) -> Dictionary:
	var out := PackedByteArray()
	var i := clampi(offset, 0, data.size())
	while i < data.size():
		var b := int(data[i]) & 0xff
		i += 1
		if b == 0:
			break
		out.append(b)
	return {"text": bytes_to_ascii(out), "next_offset": i}


func read_pascal_i32_le_string(data: PackedByteArray, offset: int = 0) -> Dictionary:
	if offset < 0 or offset + 4 > data.size():
		return make_error("pascal_i32_short", "missing i32 length")
	var length := read_u32_le(data, offset)
	var start := offset + 4
	var stop := clampi(start + length, start, data.size())
	var raw := data.slice(start, stop)
	return {"text": bytes_to_ascii(raw), "length": length, "next_offset": stop, "ok": stop <= data.size()}


func client_packet_id_map() -> Dictionary:
	return {
		"CryptKeyRequest": CLIENT_PACKET_CRYPT_KEY_REQUEST,
		"LoginRequest": CLIENT_PACKET_LOGIN_REQUEST,
		"CharacterOverviewRequest": CLIENT_PACKET_CHARACTER_OVERVIEW_REQUEST,
		"CharacterSelectRequest": CLIENT_PACKET_CHARACTER_SELECT_REQUEST,
		"WorldInitRequest": CLIENT_PACKET_WORLD_INIT_REQUEST,
		"RegionListRequest": CLIENT_PACKET_REGION_LIST_REQUEST,
	}


func client_packet_name_for_id(packet_id: int) -> String:
	for k in client_packet_id_map().keys():
		if int(client_packet_id_map()[k]) == int(packet_id):
			return str(k)
	return "UNKNOWN_0x%02X" % (int(packet_id) & 0xff)


func client_packet_id_for_name(name: String) -> int:
	return int(client_packet_id_map().get(name, -1))


func build_login_payload_1127(account: String = "", password: String = "") -> PackedByteArray:
	var acc := sanitize_account_name(account if account != "" else offline_account)
	var pwd := sanitize_password(password if password != "" else offline_password)
	var out := PackedByteArray()
	out = append_pascal_i32_le_string(out, acc, true)
	out = append_pascal_i32_le_string(out, pwd, true)
	return out


func decode_login_payload_1127(payload: PackedByteArray) -> Dictionary:
	var acc: Dictionary = read_pascal_i32_le_string(payload, 0)
	var pwd: Dictionary = read_pascal_i32_le_string(payload, int(acc.get("next_offset", 0)))
	return {"ok": bool(acc.get("ok", false)) and bool(pwd.get("ok", false)), "account": str(acc.get("text", "")), "password": str(pwd.get("text", "")), "account_len": int(acc.get("length", 0)), "password_len": int(pwd.get("length", 0))}


func build_login_packet_1127(account: String = "", password: String = "", sequence: int = 1, session_id: int = 0) -> PackedByteArray:
	return _wire_build_packet(CLIENT_PACKET_LOGIN_REQUEST, build_login_payload_1127(account, password), sequence, session_id, 0)


func decode_login_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := _wire_parse_packet(packet)
	parsed["decoded"] = decode_login_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_character_overview_payload_1127(realm: int = -1) -> PackedByteArray:
	var r := offline_realm if realm < 0 else clampi(realm, REALM_NONE, REALM_HIBERNIA)
	return PackedByteArray([r & 0xff])


func decode_character_overview_payload_1127(payload: PackedByteArray) -> Dictionary:
	var realm := read_u8(payload, 0) if payload.size() > 0 else REALM_NONE
	return {"ok": payload.size() >= 1, "realm": realm, "realm_name": realm_name_for_id(realm)}


func build_character_overview_packet_1127(realm: int = -1, sequence: int = 2, session_id: int = 0) -> PackedByteArray:
	return _wire_build_packet(CLIENT_PACKET_CHARACTER_OVERVIEW_REQUEST, build_character_overview_payload_1127(realm), sequence, session_id, 0)


func decode_character_overview_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := _wire_parse_packet(packet)
	parsed["decoded"] = decode_character_overview_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
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


func build_character_select_payload_1127(character_index: int = -1) -> PackedByteArray:
	var idx := offline_character_index if character_index < 0 else clampi(character_index, 0, 255)
	return PackedByteArray([idx & 0xff])


func decode_character_select_payload_1127(payload: PackedByteArray) -> Dictionary:
	var idx := read_u8(payload, 0) if payload.size() > 0 else 0
	return {"ok": payload.size() >= 1, "character_index": idx, "account_slot_albion": character_slot_to_account_slot(idx, REALM_ALBION)}


func build_character_select_packet_1127(character_index: int = -1, sequence: int = 3, session_id: int = 0) -> PackedByteArray:
	return _wire_build_packet(CLIENT_PACKET_CHARACTER_SELECT_REQUEST, build_character_select_payload_1127(character_index), sequence, session_id, 0)


func decode_character_select_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := _wire_parse_packet(packet)
	parsed["decoded"] = decode_character_select_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func character_slot_to_account_slot(character_index: int, realm: int = REALM_ALBION) -> int:
	var r := clampi(realm, REALM_ALBION, REALM_HIBERNIA)
	var idx := clampi(character_index, 0, 255)
	var realm_offset := idx - (r * 10 - 10)
	return r * 100 + realm_offset


func account_slot_to_character_slot(account_slot: int, realm: int = REALM_ALBION) -> int:
	var r := clampi(realm, REALM_ALBION, REALM_HIBERNIA)
	var realm_offset := int(account_slot) - r * 100
	return realm_offset + (r * 10 - 10)


func build_world_init_payload_1127() -> PackedByteArray:
	return PackedByteArray()


func decode_world_init_payload_1127(payload: PackedByteArray) -> Dictionary:
	return {"ok": payload.size() == 0, "payload_size": payload.size()}


func build_world_init_packet_1127(sequence: int = 4, session_id: int = 0) -> PackedByteArray:
	return _wire_build_packet(CLIENT_PACKET_WORLD_INIT_REQUEST, build_world_init_payload_1127(), sequence, session_id, 0)


func decode_world_init_packet_1127(packet: PackedByteArray) -> Dictionary:
	var parsed := _wire_parse_packet(packet)
	parsed["decoded"] = decode_world_init_payload_1127(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	return parsed


func build_full_offline_flow_packets(account: String = "", password: String = "", realm: int = -1, character_index: int = -1) -> Array:
	var packets: Array = []
	if wire_1127 != null and wire_1127.has_method("build_version_probe_1127_packet"):
		packets.append({"name": "CryptKeyRequestVersionProbe", "packet": wire_1127.call("build_version_probe_1127_packet") as PackedByteArray})
	packets.append({"name": "LoginRequest", "packet": build_login_packet_1127(account, password, 1, 0)})
	packets.append({"name": "CharacterOverviewRequest", "packet": build_character_overview_packet_1127(realm, 2, offline_session_id)})
	packets.append({"name": "CharacterSelectRequest", "packet": build_character_select_packet_1127(character_index, 3, offline_session_id)})
	packets.append({"name": "WorldInitRequest", "packet": build_world_init_packet_1127(4, offline_session_id)})
	last_flow_snapshot = {"count": packets.size(), "account": sanitize_account_name(account if account != "" else offline_account), "realm": realm_name_for_id(offline_realm), "character_index": offline_character_index}
	return packets


func decode_full_offline_flow_packets(packets: Array) -> Array:
	var out: Array = []
	for item in packets:
		var d: Dictionary = item as Dictionary
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		var parsed := _wire_parse_packet(packet)
		parsed["name"] = str(d.get("name", client_packet_name_for_id(int(parsed.get("packet_id", -1)))))
		out.append(parsed)
	return out


func flow_packet_count(flow: Array) -> int:
	return flow.size()


func flow_to_hex_lines(flow: Array, max_bytes: int = 96) -> PackedStringArray:
	var lines := PackedStringArray()
	for item in flow:
		var d: Dictionary = item as Dictionary
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		lines.append("%s %s" % [str(d.get("name", "packet")), bytes_to_hex(packet, max_bytes)])
	return lines


func bytes_to_hex(data: PackedByteArray, max_bytes: int = 96) -> String:
	var parts: Array[String] = []
	var stop := mini(data.size(), maxi(0, max_bytes))
	for i in range(stop):
		parts.append("%02X" % (int(data[i]) & 0xff))
	if data.size() > stop:
		parts.append("...")
	return " ".join(parts)


func packet_summary(packet: PackedByteArray) -> String:
	var parsed := _wire_parse_packet(packet)
	return "%s id=0x%02X size=%d checksum=%s" % [client_packet_name_for_id(int(parsed.get("packet_id", -1))), int(parsed.get("packet_id", 0)), int(parsed.get("data_size", 0)), str(parsed.get("checksum_ok", false))]


func flow_summary(flow: Array) -> String:
	var names: Array[String] = []
	for item in flow:
		var d: Dictionary = item as Dictionary
		names.append(str(d.get("name", "packet")))
	return "P1-N5B offline flow count=%d [%s]" % [flow.size(), ", ".join(names)]


func checksum_ok_for_packet(packet: PackedByteArray) -> bool:
	if wire_1127 != null and wire_1127.has_method("verify_dol_tcp_checksum16"):
		return bool(wire_1127.call("verify_dol_tcp_checksum16", packet))
	return false


func validate_client_packet(packet: PackedByteArray, expected_id: int = -1) -> Dictionary:
	var parsed := _wire_parse_packet(packet)
	var id := int(parsed.get("packet_id", -1))
	var ok_id := expected_id < 0 or id == expected_id
	return {"ok": bool(parsed.get("ok", false)) and bool(parsed.get("checksum_ok", false)) and ok_id, "packet_id": id, "packet_name": client_packet_name_for_id(id), "checksum_ok": bool(parsed.get("checksum_ok", false)), "expected_id": expected_id}


func describe_source_basis() -> String:
	return "DOLSharp 1127 offline: LoginRequest reads IntPascalLE account/password; CharacterOverview reads realm byte; CharacterSelect reads char index byte; WorldInit has empty client payload."


func p1_n5b_scope() -> String:
	return "P1-N5B: encodeur offline LoginRequest/CharacterOverview/CharacterSelect/WorldInit DOL 1127; aucun envoi TCP live."


func is_real_network_send_enabled() -> bool:
	return false


func can_build_offline_login_flow() -> bool:
	return wire_1127 != null and account_valid(offline_account) and password_valid(offline_password)


func status_snapshot() -> Dictionary:
	var flow := build_full_offline_flow_packets(offline_account, offline_password, offline_realm, offline_character_index)
	return {
		"scope": "P1-N5B DOL login/charselect/worldinit offline",
		"account": offline_account,
		"realm": realm_name_for_id(offline_realm),
		"character_index": offline_character_index,
		"flow_count": flow.size(),
		"client_packet_ids": client_packet_id_map(),
		"can_build": can_build_offline_login_flow(),
		"real_network_send_enabled": false,
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
		"reset_flow_profile", "setup_flow", "set_wire_1127", "configure_account", "configure_character",
		"set_debug_enabled", "is_debug_enabled", "default_account", "default_password", "sanitize_account_name",
		"sanitize_password", "account_valid", "password_valid", "ascii_bytes", "bytes_to_ascii",
		"append_u8", "append_u16_le", "append_u32_le", "append_fixed_string", "append_c_string",
		"append_pascal_i32_le_string", "read_u8", "read_u16_le", "read_u32_le", "read_fixed_string",
		"read_c_string", "read_pascal_i32_le_string", "client_packet_id_map", "client_packet_name_for_id", "client_packet_id_for_name",
		"build_login_payload_1127", "decode_login_payload_1127", "build_login_packet_1127", "decode_login_packet_1127", "build_character_overview_payload_1127",
		"decode_character_overview_payload_1127", "build_character_overview_packet_1127", "decode_character_overview_packet_1127", "realm_name_for_id", "realm_id_for_name",
		"build_character_select_payload_1127", "decode_character_select_payload_1127", "build_character_select_packet_1127", "decode_character_select_packet_1127", "character_slot_to_account_slot",
		"account_slot_to_character_slot", "build_world_init_payload_1127", "decode_world_init_payload_1127", "build_world_init_packet_1127", "decode_world_init_packet_1127",
		"build_full_offline_flow_packets", "decode_full_offline_flow_packets", "flow_packet_count", "flow_to_hex_lines", "bytes_to_hex",
		"packet_summary", "flow_summary", "checksum_ok_for_packet", "validate_client_packet", "describe_source_basis",
		"p1_n5b_scope", "is_real_network_send_enabled", "can_build_offline_login_flow", "status_snapshot", "last_error_snapshot",
		"clear_last_error", "make_error", "get_function_names",
	])


func _wire_build_packet(packet_id: int, payload: PackedByteArray, sequence: int, session_id: int, parameter: int) -> PackedByteArray:
	if wire_1127 == null or not wire_1127.has_method("build_gspacket_12"):
		make_error("wire_missing", "DaocDolWire1127 is required")
		return PackedByteArray()
	return wire_1127.call("build_gspacket_12", packet_id, payload, sequence, session_id, parameter) as PackedByteArray


func _wire_parse_packet(packet: PackedByteArray) -> Dictionary:
	if wire_1127 == null or not wire_1127.has_method("parse_gspacket_12"):
		return make_error("wire_missing", "DaocDolWire1127 is required")
	return wire_1127.call("parse_gspacket_12", packet) as Dictionary
