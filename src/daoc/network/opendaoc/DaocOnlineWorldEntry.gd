extends RefCounted
class_name DaocOnlineWorldEntry

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const WorldInitScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocWorldInitCodec.gd")
const GameOpenScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocGameOpenCodec.gd")
const PositionScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocWorldBootstrapCapture.gd")

signal outbound_packet_ready(packet: PackedByteArray, purpose: String)
signal world_position_received(position: Dictionary)
signal client_world_loading_requested
signal world_ready
## P1-115 : pendant un changement de region, la construction du monde est
## demandee a la scene de jeu, pas a l ecran de chargement du frontend.
signal region_world_loading_requested

const IDLE := "IDLE"
const WAIT_POSITION := "WAIT_POSITION"
const WAIT_GAME_OPEN := "WAIT_GAME_OPEN"
const WAIT_CLIENT_WORLD := "WAIT_CLIENT_WORLD"
const WAIT_PLAYER_INIT := "WAIT_PLAYER_INIT"
const READY := "READY"
const FAILED := "FAILED"

var state := IDLE
var _sequence := 0
var _session_id := 0
var _codec: RefCounted = PacketCodecScript.new()
var _world_init: RefCounted = WorldInitScript.new()
var _game_open: RefCounted = GameOpenScript.new()
var _position: RefCounted = PositionScript.new()
var _character: Dictionary = {}
## Vrai entre le 0xB7 RegionChanged et le 0x2B qui clot la nouvelle entree.
var region_change_in_progress := false


func begin(character: Dictionary, sequence: int, session_id: int) -> Dictionary:
	_character = character.duplicate(true)
	_sequence = sequence & 0xffff
	_session_id = session_id
	var packet: PackedByteArray = _world_init.call("build_world_init_packet_1125", character, _take_sequence(), session_id, 0) as PackedByteArray
	if packet.is_empty(): return _fail("world_init_build_failed")
	state = WAIT_POSITION
	outbound_packet_ready.emit(packet, "world_init")
	return snapshot()


func accept_server_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)): return _fail("invalid_server_packet")
	var opcode := int(parsed.get("opcode", -1))
	# 0x20 est l'alias source de PlayerPositionAndObjectID que la sonde P1-20C
	# acceptait aussi. Un paquet de position illisible n'arrete pas l'attente.
	if (opcode == 0x88 or opcode == 0x20) and state == WAIT_POSITION:
		var decoded: Dictionary = _position.call("decode_position_packet", packet) as Dictionary
		if not bool(decoded.get("ok", false)):
			return {"ok": true, "opcode": opcode, "ignored": "undecodable_position", "snapshot": snapshot()}
		world_position_received.emit(decoded)
		var request: PackedByteArray = _game_open.call("build_game_open_packet_tcp_only_1125", _take_sequence(), _session_id, 0) as PackedByteArray
		state = WAIT_GAME_OPEN
		outbound_packet_ready.emit(request, "game_open_tcp")
	elif opcode == 0x2D and state == WAIT_GAME_OPEN:
		if not bool((_game_open.call("decode_game_open_reply", packet) as Dictionary).get("ok", false)): return _fail("invalid_game_open_reply")
		# Le client d'origine cree son monde de region sous l'ecran de chargement
		# avant de finaliser PlayerInit. Tant que 0xE8 n'est pas parti, le serveur
		# ne doit pas placer le personnage jouable dans le monde et l'aggro.
		state = WAIT_CLIENT_WORLD
		if region_change_in_progress:
			region_world_loading_requested.emit()
		else:
			client_world_loading_requested.emit()
	elif opcode == 0x2B and state == WAIT_PLAYER_INIT:
		if not bool((_game_open.call("decode_player_init_finished", packet) as Dictionary).get("ok", false)): return _fail("invalid_player_init_finished")
		state = READY
		region_change_in_progress = false
		world_ready.emit()
	return {"ok": state != FAILED, "opcode": opcode, "snapshot": snapshot()}


func finish_client_world_loading() -> Dictionary:
	if state != WAIT_CLIENT_WORLD:
		return {"ok": false, "error": "client_world_not_waiting", "state": state}
	var init: PackedByteArray = _game_open.call("build_player_init_packet_1125", _take_sequence(), _session_id, 0) as PackedByteArray
	if init.is_empty():
		return _fail("player_init_build_failed")
	state = WAIT_PLAYER_INIT
	outbound_packet_ready.emit(init, "player_init")
	return snapshot()


func snapshot() -> Dictionary:
	return {"ok": state != FAILED, "state": state, "session_id_present": _session_id != 0, "next_sequence": _sequence, "region_change_in_progress": region_change_in_progress}


func next_sequence_value() -> int:
	return _sequence


func _take_sequence() -> int:
	var value := _sequence
	_sequence = (_sequence + 1) & 0xffff
	return value


func _fail(reason: String) -> Dictionary:
	state = FAILED
	return {"ok": false, "error": reason, "snapshot": snapshot()}


## P1-115 — le 0xB7 RegionChanged rejoue l'entree dans le monde. Le client
## d'origine (`eden.dll.c`, case 0xb7 -> DAT_00d913c0) detruit son monde,
## charge la nouvelle region puis renvoie un 0xD4 WorldInit (`FUN_0042a87b`) ;
## la suite est celle de la premiere entree : position (0x88/0x20), GameOpen,
## monde client, PlayerInit (0xE8), 0x2B. La numerotation reprend celle de la
## session, qui a envoye des paquets depuis la premiere entree.
## A CONFIRMER EN LIVE : que ce serveur attende bien un second GameOpen.
func begin_region_change(sequence: int, session_id: int) -> Dictionary:
	if _character.is_empty():
		return {"ok": false, "error": "region_change_without_first_entry", "state": state}
	_sequence = sequence & 0xffff
	if session_id != 0:
		_session_id = session_id
	region_change_in_progress = true
	var packet: PackedByteArray = _world_init.call("build_world_init_packet_1125", _character, _take_sequence(), _session_id, 0) as PackedByteArray
	if packet.is_empty(): return _fail("world_init_build_failed")
	state = WAIT_POSITION
	outbound_packet_ready.emit(packet, "world_init_region_change")
	return snapshot()
