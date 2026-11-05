extends RefCounted
class_name DaocOnlineWorldModel

## Le modele du monde serveur cote client : position autoritaire du joueur
## (0x88) et entites proches (0xDA/0xD9/0x15/0xA1/0xDE), decodees par le MEME
## decodeur que la capture P1-20E.
##
## Depuis le 2026-09-15 il emet aussi `entity_event`, un evenement de la forme
## exacte de `DaocWorldEntityStream` (spawn / move), pour que
## `DaocEntityStreamRuntime` (R2) applique le flux serveur au monde avec la
## meme porte `population.spawn_one` que la capture rejouee. Rien n'est
## re-decode ni re-interprete : c'est l'etat du registre APRES ingestion.

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const PositionScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocWorldBootstrapCapture.gd")
const NearbyDecoderScript = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")
const RegistryScript = preload("res://src/daoc/network/opendaoc/DaocNearbyEntityRegistry.gd")
const StreamScript = preload("res://src/daoc/network/opendaoc/DaocWorldEntityStream.gd")

signal player_position_changed(position: Dictionary)
signal entities_changed(snapshot: Dictionary)
## Un evenement de flux R2 : {kind: spawn|move, object_id, entity|zone_x...}.
signal entity_event(event: Dictionary)

var _codec: RefCounted = PacketCodecScript.new()
var _position_decoder: RefCounted = PositionScript.new()
var _nearby_decoder: RefCounted = NearbyDecoderScript.new()
var _registry: RefCounted = RegistryScript.new()
var _player_position: Dictionary = {}
var _packet_index := 0
var _spawned_ids: Dictionary = {}
var _event_count := 0


func ingest_server_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error": "invalid_server_packet"}
	var opcode := int(parsed.get("opcode", -1))
	if opcode == 0x88 and (parsed.get("payload", PackedByteArray()) as PackedByteArray).size() < 28:
		# P1-108 : un 0x88 de moins de 28 octets est la fenetre du pet
		# (PetWindow, meme opcode), pas la position ; le runtime la decode.
		pass
	elif opcode == 0x88 or opcode == 0x20:
		var decoded: Dictionary = _position_decoder.call("decode_position_packet", packet) as Dictionary
		if not bool(decoded.get("ok", false)):
			return {"ok": false, "error": "invalid_player_position"}
		_player_position = decoded.duplicate(true)
		_registry.call("set_player_position", float(decoded["x"]), float(decoded["y"]), float(decoded["z"]))
		player_position_changed.emit(_player_position.duplicate(true))
	elif opcode == REMOVE_OBJECT_OPCODE:
		_ingest_remove_object(parsed.get("payload", PackedByteArray()) as PackedByteArray)
	elif opcode in NearbyDecoderScript.SUPPORTED:
		var decoded: Dictionary = _nearby_decoder.call("decode_nearby_world_packet", opcode, parsed.get("payload", PackedByteArray())) as Dictionary
		if not bool(decoded.get("ok", false)):
			return {"ok": false, "error": "nearby_packet_decode_failed", "opcode": opcode}
		_registry.call("ingest", decoded, _packet_index)
		_emit_stream_event(opcode, decoded)
		# 2026-09-16 : `snapshot()` copie et trie TOUT le registre (~4 ms a 310
		# entites) ; le calculer ici, deux fois par paquet, coutait 9 ms par 0xA1
		# alors que le serveur en envoie des dizaines par seconde. Le signal ne
		# porte plus que le compte ; qui veut le detail appelle snapshot().
		entities_changed.emit({"entity_count": int((_registry.get("entities") as Dictionary).size()), "opcode": opcode})
	_packet_index += 1
	return {"ok": true, "opcode": opcode}


## P1-129 — 0xA2 RemoveObject (IPacketLib : RemoveObject = 0xA2 ;
## PacketLib168.SendObjectRemove : u16 oid, u16 type 0 PNJ mort / 1 PNJ vivant /
## 2 joueur). Jamais traite jusqu ici : un familier relache, un mob sorti de
## portee ou un cadavre qui disparait RESTAIENT a l ecran (cone violet fige).
const REMOVE_OBJECT_OPCODE := 0xA2
var removed_objects := 0

func _ingest_remove_object(payload: PackedByteArray) -> void:
	if payload.size() < 2:
		return
	var object_id := (int(payload[0]) << 8) | int(payload[1])
	if object_id <= 0:
		return
	var entities: Dictionary = _registry.get("entities") as Dictionary
	entities.erase(object_id)
	_spawned_ids.erase(object_id)
	removed_objects += 1
	_event_count += 1
	entity_event.emit({
		"kind": StreamScript.KIND_DESPAWN,
		"packet_index": _packet_index,
		"opcode": REMOVE_OBJECT_OPCODE,
		"object_id": object_id,
		"object_type": (int(payload[2]) << 8) | int(payload[3]) if payload.size() >= 4 else -1,
	})
	entities_changed.emit({"entity_count": entities.size(), "opcode": REMOVE_OBJECT_OPCODE})


## Meme regle que `DaocWorldEntityStream.from_capture` : une seconde creation
## du meme identifiant est un affinage, pas une nouvelle apparition.
func _emit_stream_event(opcode: int, decoded: Dictionary) -> void:
	if not decoded.has("object_id"):
		return
	var object_id := int(decoded.get("object_id", -1))
	if object_id <= 0:
		return
	var entities: Dictionary = _registry.get("entities") as Dictionary
	if StreamScript.CREATE_OPCODES.has(opcode):
		if _spawned_ids.has(object_id) or not entities.has(object_id):
			return
		_spawned_ids[object_id] = true
		_event_count += 1
		entity_event.emit({
			"kind": StreamScript.KIND_SPAWN,
			"packet_index": _packet_index,
			"opcode": opcode,
			"object_id": object_id,
			"entity": (entities[object_id] as Dictionary).duplicate(true),
		})
	elif opcode == StreamScript.MOVE_OPCODE:
		_event_count += 1
		entity_event.emit({
			"kind": StreamScript.KIND_MOVE,
			"packet_index": _packet_index,
			"opcode": opcode,
			"object_id": object_id,
			"zone_x": int(decoded.get("zone_x", 0)),
			"zone_y": int(decoded.get("zone_y", 0)),
			"zone_z": int(decoded.get("zone_z", 0)),
			"heading": int(decoded.get("heading", 0)),
			"speed": int(decoded.get("speed", 0)),
			# Destination du PNJ (SendObjectUpdate) : le client d'origine marche
			# vers elle a `speed` entre deux paquets ; sans elle, un 0xA1 toutes
			# les 5 s ne peut etre qu'une teleportation.
			"target_zone_x": int(decoded.get("target_zone_x", 0)),
			"target_zone_y": int(decoded.get("target_zone_y", 0)),
			"target_zone_z": int(decoded.get("target_zone_z", 0)),
			"target_object_id": int(decoded.get("target_object_id", 0)),
			"health_percent": int(decoded.get("health_percent", 0)),
		})


func snapshot() -> Dictionary:
	return {"ok": true, "player_position": _player_position.duplicate(true),
		"entities": _registry.call("sorted_entities"), "entity_count": int((_registry.get("entities") as Dictionary).size()),
		"pending_update_count": int(_registry.call("pending_update_count")), "packet_count": _packet_index,
		"stream_event_count": _event_count, "spawned_ids": _spawned_ids.size()}


## P1-115 — 0xB7 : les entités de l ancienne région n existent plus. Le
## registre repart vide ; les nouvelles arrivent après le rejeu de l entrée.
func reset_entities() -> void:
	_registry = RegistryScript.new()
	_spawned_ids.clear()


## P1-115 — 0x04 CharacterJump : le serveur nous a déplacés DANS la région.
## La position autoritaire suit (région inchangée) ; un saut « cap seulement »
## ne change que le cap.
func apply_character_jump(jump: Dictionary) -> void:
	if _player_position.is_empty():
		return
	if not bool(jump.get("heading_only", false)):
		_player_position["x"] = int(jump.get("x", 0))
		_player_position["y"] = int(jump.get("y", 0))
		_player_position["z"] = int(jump.get("z", 0))
		_registry.call("set_player_position", float(_player_position["x"]), float(_player_position["y"]), float(_player_position["z"]))
	_player_position["heading"] = int(jump.get("heading", 0))
	player_position_changed.emit(_player_position.duplicate(true))
