extends RefCounted
class_name DaocWorldEntityStream

## R2 — la capture cesse d'etre une LISTE et redevient un FLUX.
##
## `DaocNearbyWorldEntitySource` rend l'etat FINAL des 311 entites : la photo
## prise a la fin du rejeu. C'est ce que le monde consomme depuis P1-20G-F, et
## c'est pour cela que Gothwaite naissait deja peuple, figé, sans que rien
## n'apparaisse jamais.
##
## Cette classe rend la meme capture sous sa forme d'origine — une SUITE
## d'evenements ordonnes par numero de paquet. Le decodage est strictement le
## meme : memes `DaocNearbyWorldCaptureReplay`, `DaocNearbyWorldPacketDecoder`
## et `DaocNearbyEntityRegistry`. On ne relit pas la capture autrement, on
## refuse simplement de jeter l'ordre.
##
## L'ORACLE. Replier tous les evenements doit redonner exactement l'etat final
## de `DaocNearbyWorldEntitySource.from_capture`. Ce n'est pas une valeur
## recopiee a la main : c'est la meme capture, lue deux fois, comparee a
## elle-meme. Si le flux perdait un paquet, l'egalite tomberait.
##
## CE QUE LA CAPTURE P1-20D CONTIENT REELLEMENT, mesure et non suppose :
##
##   310 apparitions   paquets 14 a 806, donc etalees et non en rafale
##    24 deplacements  paquets 807 a 830, touchant 12 entites,
##                     dont 8 changent reellement de position
##     0 retrait       AUCUN opcode de suppression n'est present dans le flux,
##                     et le decodeur n'en connait aucun
##
## Consequence assumee : `KIND_DESPAWN` existe, le consommateur sait l'appliquer,
## mais AUCUN evenement de ce type ne sort d'ici. Le chemin de retrait est ecrit
## et teste par un evenement synthetique ; il n'est pas prouve contre du serveur
## reel et ne doit pas etre presente comme tel.
##
## Les deplacements observes sont petits — quelques dizaines d'unites DAoC. Le
## flux prouve le mecanisme, il ne fournit pas une demonstration spectaculaire.

const Replay = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldCaptureReplay.gd")
const Decoder = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")
const Registry = preload("res://src/daoc/network/opendaoc/DaocNearbyEntityRegistry.gd")

const DEFAULT_CAPTURE := "res://reports/p1_20d_live_heyveno_gameopen/p1_20d_post_gameopen_server_packets.bin"

const KIND_SPAWN := "spawn"
const KIND_MOVE := "move"
const KIND_DESPAWN := "despawn"

## Opcodes qui font APPARAITRE une entite dans le monde.
const CREATE_OPCODES := [0xDA, 0xD9, 0x4B]
## Opcode qui la DEPLACE. Il porte des coordonnees de ZONE, pas de monde.
const MOVE_OPCODE := 0xA1


## Rejoue la capture et rend les evenements dans l'ordre des paquets.
##
## `entities_final` porte l'etat final du registre : c'est lui qui sert d'oracle
## face a `DaocNearbyWorldEntitySource.from_capture`.
static func from_capture(path: String = DEFAULT_CAPTURE) -> Dictionary:
	var replay := Replay.new()
	var decoder := Decoder.new()
	var registry := Registry.new()
	registry.reset()
	registry.seed_confirmed_heyveno()

	var capture := replay.load_server_capture(path)
	if not bool(capture.get("ok", false)):
		return _failure(str(capture.get("error", "capture_unreadable")), path)
	var validation := replay.replay_server_packets(capture)
	if not bool(validation.get("ok", false)):
		return _failure(str(validation.get("error", "replay_failed")), path)

	var events: Array = []
	var seen: Dictionary = {}
	var decode_failures := 0
	var spawn_count := 0
	var move_count := 0

	for packet in validation.get("packets", []):
		var opcode := int(packet.opcode)
		if not decoder.SUPPORTED.has(opcode):
			continue
		var decoded := decoder.decode_nearby_world_packet(opcode, packet.payload)
		if not bool(decoded.get("ok", false)):
			decode_failures += 1
			continue

		var packet_index := int(packet.packet_index)
		registry.ingest(decoded, packet_index)

		if not decoded.has("object_id"):
			continue
		var object_id := int(decoded.object_id)
		if object_id <= 0:
			continue

		if CREATE_OPCODES.has(opcode):
			# Une SECONDE creation pour le meme identifiant n'est pas une
			# nouvelle entite : le registre la traite comme un affinage, et le
			# monde n'a rien a faire apparaitre une deuxieme fois.
			if seen.has(object_id):
				continue
			seen[object_id] = true
			if not registry.entities.has(object_id):
				continue
			events.append({
				"kind": KIND_SPAWN,
				"packet_index": packet_index,
				"opcode": opcode,
				"object_id": object_id,
				# L'etat du registre APRES ingestion : c'est exactement ce que
				# le peuplement en bloc recevrait pour cette entite.
				"entity": (registry.entities[object_id] as Dictionary).duplicate(true),
			})
			spawn_count += 1
		elif opcode == MOVE_OPCODE:
			events.append({
				"kind": KIND_MOVE,
				"packet_index": packet_index,
				"opcode": opcode,
				"object_id": object_id,
				"zone_x": int(decoded.get("zone_x", 0)),
				"zone_y": int(decoded.get("zone_y", 0)),
				"zone_z": int(decoded.get("zone_z", 0)),
				"heading": int(decoded.get("heading", 0)),
				"speed": int(decoded.get("speed", 0)),
				"health_percent": int(decoded.get("health_percent", 0)),
			})
			move_count += 1

	var final_entities := registry.sorted_entities()
	return {
		"ok": decode_failures == 0 and registry.pending_update_count() == 0,
		"source": "CAPTURE_STREAM",
		"path": path,
		"events": events,
		"event_count": events.size(),
		"spawn_count": spawn_count,
		"move_count": move_count,
		"despawn_count": 0,
		"despawn_supported_by_capture": false,
		"despawn_note": "aucun opcode de suppression dans la capture ni dans le decodeur",
		"entities_final": final_entities,
		"entity_count": final_entities.size(),
		"packet_count": int(validation.get("packet_count", 0)),
		"decode_failure_count": decode_failures,
		"pending_update_count": registry.pending_update_count(),
		"first_spawn_packet_index": events[0].packet_index if not events.is_empty() else -1,
		"last_event_packet_index": events[-1].packet_index if not events.is_empty() else -1,
	}


## Les identifiants reellement deplaces, et de combien. Sert au rapport et a la
## suite : annoncer « le monde bouge » sans dire QUI bougerait etre creux.
static func movement_summary(events: Array) -> Dictionary:
	var by_object: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("kind", "")) != KIND_MOVE:
			continue
		var object_id := int(event.object_id)
		if not by_object.has(object_id):
			by_object[object_id] = []
		(by_object[object_id] as Array).append(
			Vector3i(int(event.zone_x), int(event.zone_y), int(event.zone_z)))

	var really_moved: Array = []
	for object_id: int in by_object:
		var positions: Array = by_object[object_id]
		var distinct: Dictionary = {}
		for p: Vector3i in positions:
			distinct[p] = true
		if distinct.size() > 1:
			really_moved.append(object_id)
	really_moved.sort()

	return {
		"touched_object_ids": by_object.keys().size(),
		"really_moved_object_ids": really_moved,
		"really_moved_count": really_moved.size(),
	}


## Qui sera PLACE DIFFEREMMENT par le flux que par le bloc.
##
## `movement_summary` repond a une autre question — qui change de position AU
## SEIN du flux de deplacement — et les deux comptes ne coincident pas. Une
## entite peut ne recevoir qu'un seul `0xA1` et avoir malgre tout quitte sa
## position de creation ; la sonde en conditions reelles a trouve exactement ce
## cas (`757`, un seul paquet, vitesse 200, deplace de 12 et 27 unites).
##
## C'est CE compte qui vaut face au peuplement en bloc, puisque le bloc pose
## chaque entite a sa position de creation et ignore les `0xA1`.
##
## Trois entites de la capture recoivent un `0xA1` a vitesse nulle qui redonne
## leur position de creation A L'UNITE PRES : elles ne sont pas comptees, et
## cette coincidence exacte confirme au passage que les deux jeux de
## coordonnees vivent bien dans le meme espace de zone.
static func displacement_summary(events: Array, world_origin_x: float = 491520.0,
		world_origin_y: float = 491520.0) -> Dictionary:
	var spawn_zone: Dictionary = {}
	var last_move: Dictionary = {}

	for event: Dictionary in events:
		var object_id := int(event.get("object_id", -1))
		match str(event.get("kind", "")):
			KIND_SPAWN:
				var entity: Variant = event.get("entity", {})
				if entity is Dictionary:
					var e := entity as Dictionary
					spawn_zone[object_id] = Vector2(
						float(e.get("x", 0.0)) - world_origin_x,
						float(e.get("y", 0.0)) - world_origin_y)
			KIND_MOVE:
				last_move[object_id] = Vector2(float(event.get("zone_x", 0)), float(event.get("zone_y", 0)))

	var displaced: Array = []
	var confirmed_in_place: Array = []
	for object_id: int in last_move:
		if not spawn_zone.has(object_id):
			continue
		if (last_move[object_id] as Vector2).is_equal_approx(spawn_zone[object_id] as Vector2):
			confirmed_in_place.append(object_id)
		else:
			displaced.append(object_id)
	displaced.sort()
	confirmed_in_place.sort()

	return {
		"displaced_object_ids": displaced,
		"displaced_count": displaced.size(),
		"confirmed_in_place_object_ids": confirmed_in_place,
		"confirmed_in_place_count": confirmed_in_place.size(),
	}


static func _failure(reason: String, path: String) -> Dictionary:
	return {
		"ok": false, "error": reason, "path": path,
		"events": [], "event_count": 0, "entities_final": [], "entity_count": 0,
	}
