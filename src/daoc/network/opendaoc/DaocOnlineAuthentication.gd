extends Node
class_name DaocOnlineAuthentication

const LoginLayoutsScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const CharacterSelectScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterSelectCodec.gd")

signal outbound_packet_ready(packet: PackedByteArray, purpose: String)
signal character_overview_received(overview: Dictionary)
signal authentication_ready(session_id: int, overview: Dictionary)
## Le SessionID (0x28) arrive APRES le CharacterSelect (0x10), pas avant :
## mesure en live le 2026-09-15, conforme a PROTOCOL_FLOW_LOGIN_TO_PLAYING.md.
signal session_id_received(session_id: int)
signal authentication_failed(reason: String)

const IDLE := "IDLE"
const WAIT_CRYPT_KEY := "WAIT_CRYPT_KEY"
const WAIT_LOGIN_GRANTED := "WAIT_LOGIN_GRANTED"
const WAIT_OVERVIEW := "WAIT_OVERVIEW"
const READY := "READY"
const FAILED := "FAILED"

var state := IDLE
var session_id := 0
var _sequence := 0
var _realm := 1
var _account := ""
var _password := ""
var _overview: Dictionary = {}
var _layouts: Node = LoginLayoutsScript.new()
var _codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()
var _character_select: RefCounted = CharacterSelectScript.new()
var _character_create: RefCounted = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterCreateCodec.gd").new()


func _init() -> void:
	_layouts.name = "ProtocolLayouts"
	add_child(_layouts)


func begin(profile: Dictionary, realm: int = 1) -> Dictionary:
	if not bool(profile.get("ok", false)):
		return _fail("invalid_online_profile")
	_account = str(profile.get("account", ""))
	_password = str(profile.get("password", ""))
	_realm = clampi(realm, 1, 3)
	if _account == "" or _password == "":
		return _fail("credentials_missing")
	var layout: Dictionary = _layouts.call("build_crypt_key_request_payload", "1.125a") as Dictionary
	if not bool(layout.get("ok", false)):
		return _fail("crypt_key_layout_failed")
	state = WAIT_CRYPT_KEY
	_emit_packet(0xF4, layout.get("payload", PackedByteArray()) as PackedByteArray, "crypt_key_request")
	return snapshot()


func accept_server_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return _fail("invalid_server_packet")
	var opcode := int(parsed.get("opcode", -1))
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	if opcode == 0x22:
		if state != WAIT_CRYPT_KEY or not bool((_layouts.call("decode_crypt_key_payload", payload) as Dictionary).get("ok", false)):
			return _fail("invalid_crypt_key_reply")
		var login: Dictionary = _layouts.call("build_login_request_payload", _account, _password, "1.125a") as Dictionary
		_password = ""
		if not bool(login.get("ok", false)):
			return _fail("login_layout_failed")
		state = WAIT_LOGIN_GRANTED
		_emit_packet(0xA7, login.get("payload", PackedByteArray()) as PackedByteArray, "login_request")
	elif opcode == 0x2A:
		# Mesure en live le 2026-09-15 : le serveur RENVOIE un 0x2A apres le 0x10.
		# Une fois READY il n'apprend rien et ne doit surtout pas tuer la session.
		if state == READY:
			# 2026-09-30 : en 1.124+, DOL répond à un 0xFF par un 0x2A et NON par la
			# liste (CharacterCreateRequestHandler._HandlePacket1124 :
			# « live actually just sends server login request response »). Le
			# client d'origine redemande alors la liste : 0xFC du royaume courant.
			if _awaiting_create_overview:
				var again: Dictionary = _layouts.call("build_character_overview_request_payload", _realm) as Dictionary
				_emit_packet(0xFC, again.get("payload", PackedByteArray()) as PackedByteArray, "character_overview_request_after_create")
				return {"ok": true, "opcode": opcode, "overview_requested_after_create": true, "snapshot": snapshot()}
			return {"ok": true, "opcode": opcode, "ignored": "login_granted_after_ready", "snapshot": snapshot()}
		if state != WAIT_LOGIN_GRANTED or not bool((_layouts.call("decode_login_granted_payload", payload) as Dictionary).get("ok", false)):
			return _fail("invalid_login_granted")
		var request: Dictionary = _layouts.call("build_character_overview_request_payload", _realm) as Dictionary
		state = WAIT_OVERVIEW
		_emit_packet(0xFC, request.get("payload", PackedByteArray()) as PackedByteArray, "character_overview_request")
	elif opcode == 0x28:
		var session: Dictionary = _layouts.call("decode_session_id_payload", payload) as Dictionary
		if not bool(session.get("ok", false)):
			return _fail("invalid_session_id")
		session_id = int(session.get("session_id", 0))
		session_id_received.emit(session_id)
		_try_ready()
	elif opcode == 0xFC or opcode == 0xFD:
		if state == READY:
			# 2026-09-30 : après un 0xFF, DOL renvoie la liste (création réussie
			# ou non) ; c'est la seule qu'on relaie une fois READY.
			if _awaiting_create_overview:
				_awaiting_create_overview = false
				var refreshed: Dictionary = _layouts.call("decode_character_overview_payload", payload) as Dictionary
				if bool(refreshed.get("ok", false)):
					_overview = refreshed
					character_overview_received.emit(_overview.duplicate(true))
					return {"ok": true, "opcode": opcode, "refreshed_after_create": true, "snapshot": snapshot()}
			return {"ok": true, "opcode": opcode, "ignored": "overview_after_ready", "snapshot": snapshot()}
		if state != WAIT_OVERVIEW:
			return _fail("overview_in_invalid_state")
		_overview = _layouts.call("decode_character_overview_payload", payload) as Dictionary
		if not bool(_overview.get("ok", false)):
			return _fail("invalid_character_overview")
		character_overview_received.emit(_overview.duplicate(true))
		_try_ready()
	return {"ok": state != FAILED, "opcode": opcode, "snapshot": snapshot()}


func snapshot() -> Dictionary:
	return {"ok": state != FAILED, "state": state, "session_id_received": session_id != 0,
		"overview_received": not _overview.is_empty(), "character_count": int((_overview.get("characters", []) as Array).size()),
		"credentials_retained": _password != ""}


func request_character_select(character: Dictionary) -> Dictionary:
	if state != READY:
		return {"ok": false, "error": "authentication_not_ready"}
	var validation: Dictionary = _character_select.call("validate_selectable_character", character) as Dictionary
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": "invalid_character", "validation": validation}
	var packet: PackedByteArray = _character_select.call("build_character_select_packet_named_1125", character, _sequence, session_id, 0) as PackedByteArray
	if packet.is_empty():
		return {"ok": false, "error": "character_select_packet_failed"}
	_sequence = (_sequence + 1) & 0xffff
	outbound_packet_ready.emit(packet, "character_select")
	return {"ok": true, "character": str(character.get("name", "")), "slot": int(character.get("slot", -1))}


var _awaiting_create_overview := false


## 2026-09-30 — création depuis la fenêtre simplifiée. `data` vient de
## `DaocCharacterCreationRules.build_create_data` ; même encodage que la
## création live de P1-20, et même numérotation que le 0x10.
func request_character_create(data: Dictionary) -> Dictionary:
	if state != READY:
		return {"ok": false, "error": "authentication_not_ready"}
	var packet: PackedByteArray = _character_create.call("build_character_create_packet_1125", data, _sequence, session_id, 0) as PackedByteArray
	if packet.is_empty():
		return {"ok": false, "error": "character_create_packet_failed"}
	_sequence = (_sequence + 1) & 0xffff
	_awaiting_create_overview = true
	outbound_packet_ready.emit(packet, "character_create")
	return {"ok": true, "character": str(data.get("name", "")), "slot": int(data.get("slot_index", -1))}


func next_sequence_value() -> int:
	return _sequence


## READY des l'overview : le 0x10 part avec un SessionID a zero (comme la sonde
## P1-20B prouvee en live), et c'est LUI qui declenche le 0x28.
func _try_ready() -> void:
	if state == READY:
		return
	if not _overview.is_empty():
		state = READY
		_account = ""
		authentication_ready.emit(session_id, _overview.duplicate(true))


func _emit_packet(opcode: int, payload: PackedByteArray, purpose: String) -> void:
	var unsigned: PackedByteArray = _codec.call("build_client_packet", opcode, payload, _sequence, session_id, 0, 0) as PackedByteArray
	var sum := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	var packet: PackedByteArray = _codec.call("build_client_packet", opcode, payload, _sequence, session_id, 0, sum) as PackedByteArray
	_sequence = (_sequence + 1) & 0xffff
	outbound_packet_ready.emit(packet, purpose)


func _fail(reason: String) -> Dictionary:
	state = FAILED
	_account = ""
	_password = ""
	authentication_failed.emit(reason)
	return {"ok": false, "error": reason, "snapshot": snapshot()}
