extends RefCounted
class_name DaocNearbyWorldEntitySource

## Une seule sortie — la liste d'entites du monde — deux provenances.
##
##   FIXTURE  le JSON fige, ce que le monde consomme aujourd'hui
##   CAPTURE  les paquets serveur, decodes a l'instant
##
## LES DEUX DOIVENT PRODUIRE LA MEME CHOSE, et ce n'est pas un espoir : la
## fixture a ete GENEREE par ce decodage, par DaocNearbyWorldOfflineReport.
## Le basculement de l'un vers l'autre est donc verifiable au lieu d'etre un
## acte de foi — c'est tout l'interet de passer par ici.
##
## POURQUOI CETTE CLASSE EXISTE
## Le decodeur reseau (DaocNearbyEntityRegistry) savait deja lire 0xDA, 0xD9,
## 0xA1, 0x15 et 0xDE, mais rien dans le runtime ne le consommait : le monde
## lisait un fichier fige. Cette classe est la couture qui manquait entre les
## deux, et elle est volontairement mince — elle ne decide rien, elle fournit.
##
## Elle ne touche pas au reseau. La capture est un fichier deja sur le disque.

const Replay = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldCaptureReplay.gd")
const Decoder = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")
const Registry = preload("res://src/daoc/network/opendaoc/DaocNearbyEntityRegistry.gd")

## La capture canonique P1-20D : 831 paquets, 25 820 octets, deja rejouee et
## hachee par le jalon P1-20E.
const DEFAULT_CAPTURE := "res://reports/p1_20d_live_heyveno_gameopen/p1_20d_post_gameopen_server_packets.bin"
const DEFAULT_FIXTURE := "res://reports/p1_20e_nearby_world_offline/p1_20e_entity_registry.json"

## Champs compares entre les deux provenances. On ne compare pas les
## dictionnaires en profondeur : le passage par JSON transforme tout nombre en
## flottant et ne garantit pas l'ordre des cles. On compare donc ce qui porte du
## SENS, explicitement.
const COMPARED_FIELDS := [
	"entity_type", "name", "model_id", "x", "y", "z", "heading",
	"level", "realm", "size", "guild_id", "first_packet_index", "last_packet_index",
]

## Tolerance sur les distances, seuls champs reellement flottants.
const DISTANCE_EPSILON := 0.001


## Lit la liste d'entites depuis le JSON fige.
static func from_fixture(path: String = DEFAULT_FIXTURE) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "fixture_not_found", "path": path, "entities": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "fixture_unreadable", "path": path, "entities": []}
	var entities: Variant = (parsed as Dictionary).get("entities", [])
	if not entities is Array:
		return {"ok": false, "error": "fixture_without_entities", "path": path, "entities": []}
	return {
		"ok": true, "source": "FIXTURE", "path": path,
		"entities": entities, "entity_count": (entities as Array).size(),
	}


## Rejoue la capture et decode jusqu'a la liste d'entites.
##
## Aucun fichier n'est ecrit et aucun rapport n'est produit : on ne veut ici
## que les entites. Les statistiques restent le travail de
## DaocNearbyWorldOfflineReport, qui garde son role de jalon.
static func from_capture(path: String = DEFAULT_CAPTURE) -> Dictionary:
	var replay := Replay.new()
	var decoder := Decoder.new()
	var registry := Registry.new()
	registry.reset()
	registry.seed_confirmed_heyveno()

	var capture := replay.load_server_capture(path)
	if not bool(capture.get("ok", false)):
		return {
			"ok": false, "error": str(capture.get("error", "capture_unreadable")),
			"path": path, "entities": [],
		}
	var validation := replay.replay_server_packets(capture)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false, "error": str(validation.get("error", "replay_failed")),
			"path": path, "entities": [],
		}

	var decoded_count := 0
	var skipped_unsupported := 0
	var decode_failures := 0
	for packet in validation.get("packets", []):
		var opcode := int(packet.opcode)
		if not decoder.SUPPORTED.has(opcode):
			skipped_unsupported += 1
			continue
		var decoded := decoder.decode_nearby_world_packet(opcode, packet.payload)
		if not bool(decoded.get("ok", false)):
			decode_failures += 1
			continue
		registry.ingest(decoded, int(packet.packet_index))
		decoded_count += 1

	var entities := registry.sorted_entities()
	return {
		"ok": decode_failures == 0 and registry.pending_update_count() == 0,
		"source": "CAPTURE", "path": path, "entities": entities,
		"entity_count": entities.size(),
		"packet_count": int(validation.get("packet_count", 0)),
		"total_bytes": int(validation.get("total_bytes", 0)),
		"deterministic": bool(validation.get("deterministic", false)),
		"decoded_packet_count": decoded_count,
		"unsupported_packet_count": skipped_unsupported,
		"decode_failure_count": decode_failures,
		"pending_update_count": registry.pending_update_count(),
		"conflict_count": registry.conflicts.size(),
	}


## Confronte deux listes d'entites, champ par champ, et rend le detail.
##
## Le verdict n'est utile que si les ecarts sont NOMMES : un simple booleen ne
## dirait pas lequel des cent champs a bouge. On renvoie donc les differences,
## bornees, pour qu'un test puisse les afficher.
static func compare(left: Array, right: Array, max_differences: int = 20) -> Dictionary:
	var left_by_id := _index_by_object_id(left)
	var right_by_id := _index_by_object_id(right)

	var only_left: Array = []
	var only_right: Array = []
	for object_id in left_by_id:
		if not right_by_id.has(object_id):
			only_left.append(object_id)
	for object_id in right_by_id:
		if not left_by_id.has(object_id):
			only_right.append(object_id)

	var differences: Array = []
	var compared := 0
	for object_id in left_by_id:
		if not right_by_id.has(object_id):
			continue
		compared += 1
		var a := left_by_id[object_id] as Dictionary
		var b := right_by_id[object_id] as Dictionary
		for field in COMPARED_FIELDS:
			if not _same_value(a.get(field), b.get(field)):
				if differences.size() < max_differences:
					differences.append({
						"object_id": object_id, "field": field,
						"left": a.get(field), "right": b.get(field),
					})
		if not _same_distance(a.get("distance_3d"), b.get("distance_3d")):
			if differences.size() < max_differences:
				differences.append({
					"object_id": object_id, "field": "distance_3d",
					"left": a.get("distance_3d"), "right": b.get("distance_3d"),
				})
		var left_equipment: Variant = a.get("equipment", {})
		var right_equipment: Variant = b.get("equipment", {})
		var left_size := -1
		var right_size := -1
		if left_equipment is Dictionary:
			left_size = (left_equipment as Dictionary).size()
		if right_equipment is Dictionary:
			right_size = (right_equipment as Dictionary).size()
		if left_size != right_size:
			if differences.size() < max_differences:
				differences.append({
					"object_id": object_id, "field": "equipment_count",
					"left": left_size, "right": right_size,
				})

	return {
		"identical": only_left.is_empty() and only_right.is_empty() and differences.is_empty(),
		"left_count": left.size(), "right_count": right.size(),
		"compared_count": compared,
		"only_left": only_left, "only_right": only_right,
		"difference_count": differences.size(), "differences": differences,
	}


static func _index_by_object_id(entities: Array) -> Dictionary:
	var out := {}
	for value in entities:
		if value is Dictionary:
			out[int((value as Dictionary).get("object_id", -1))] = value
	return out


## Le JSON de Godot rend tout nombre en flottant : 6155 devient 6155.0, et une
## comparaison stricte echouerait sur des valeurs pourtant identiques. On
## compare donc par type de sens, pas par type machine.
static func _same_value(left: Variant, right: Variant) -> bool:
	if left == null or right == null:
		return left == null and right == null
	if (left is float or left is int) and (right is float or right is int):
		return is_equal_approx(float(left), float(right))
	if left is Dictionary and right is Dictionary:
		return (left as Dictionary).size() == (right as Dictionary).size()
	if left is Array and right is Array:
		return (left as Array).size() == (right as Array).size()
	return str(left) == str(right)


static func _same_distance(left: Variant, right: Variant) -> bool:
	if left == null or right == null:
		return left == null and right == null
	return absf(float(left) - float(right)) <= DISTANCE_EPSILON
