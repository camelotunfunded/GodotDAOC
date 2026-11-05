extends RefCounted
class_name DaocNearbyEntityRegistry

const HEYVENO := {"object_id": 6155, "x": 525472.0, "y": 544419.0, "z": 3120.0, "region": 51}
const MAX_PENDING_PER_ENTITY := 16

var entities: Dictionary = {}
var pending: Dictionary = {}
var conflicts: Array = []
var duplicate_create_object_ids: Dictionary = {}
var applied_pending_count := 0
var player_position := Vector3(float(HEYVENO.x), float(HEYVENO.y), float(HEYVENO.z))


func reset() -> void:
	entities.clear(); pending.clear(); conflicts.clear(); duplicate_create_object_ids.clear(); applied_pending_count = 0


func set_player_position(x: float, y: float, z: float) -> void:
	player_position = Vector3(x, y, z)
	for entity in entities.values():
		if (entity as Dictionary).get("x") != null:
			_update_distance(entity as Dictionary)


func seed_confirmed_heyveno() -> void:
	# Source is the already validated P1-20C/P1-20D player-position packet, never 0xDE.
	var e := _new_entity(int(HEYVENO.object_id), "player", -1)
	e.name = "Heyveno"; e.model_id = 35; e.x = int(HEYVENO.x); e.y = int(HEYVENO.y); e.z = int(HEYVENO.z)
	e.region = int(HEYVENO.region); e.confidence.identity = "confirmed_prior_capture"
	e.confidence.position = "confirmed_prior_capture"; e.source_opcodes.append("P1-20C-player-position")
	_update_distance(e); entities[int(HEYVENO.object_id)] = e


func ingest(decoded: Dictionary, packet_index: int) -> void:
	if not bool(decoded.get("ok", false)) or not decoded.has("object_id"):
		return
	var oid := int(decoded.object_id)
	if oid <= 0: return
	var opcode := int(decoded.opcode)
	if opcode == 0xDA or opcode == 0xD9 or opcode == 0x4B:
		_ingest_create(decoded, packet_index)
	elif entities.has(oid):
		_apply_update(entities[oid], decoded, packet_index)
	else:
		if not pending.has(oid): pending[oid] = []
		var rows: Array = pending[oid]
		rows.append({"decoded": decoded.duplicate(true), "packet_index": packet_index})
		# En live, une entite sortie de portee continue d'envoyer des 0xA1 sans
		# jamais etre recreee : seules les dernieres mises a jour comptent.
		if rows.size() > MAX_PENDING_PER_ENTITY:
			rows.pop_front()


func _ingest_create(d: Dictionary, packet_index: int) -> void:
	var oid := int(d.object_id)
	if entities.has(oid):
		duplicate_create_object_ids[oid] = true
		var old: Dictionary = entities[oid]
		if str(old.entity_type) != str(d.entity_type) or (str(old.name) != "" and str(old.name) != str(d.get("name", ""))):
			_log_conflict(oid, "create_identity", {"type": old.entity_type, "name": old.name}, {"type": d.entity_type, "name": d.get("name", "")}, packet_index)
		_apply_create_fields(old, d, packet_index)
	else:
		var entity := _new_entity(oid, str(d.entity_type), packet_index)
		entities[oid] = entity
		_apply_create_fields(entity, d, packet_index)
	if pending.has(oid):
		var queued: Array = pending[oid]
		for q in queued:
			_apply_update(entities[oid], q.decoded, int(q.packet_index)); applied_pending_count += 1
		pending.erase(oid)


func _apply_create_fields(e: Dictionary, d: Dictionary, packet_index: int) -> void:
	for key in ["entity_type", "name", "model_id", "heading", "level", "realm", "size", "guild_name", "flags", "last_name", "session_id", "object_kind", "door_id"]:
		if d.has(key): _set_checked(e, key, d[key], int(d.object_id), packet_index, "create")
	if d.has("x") and d.has("y") and d.has("z"):
		e.x = int(d.x); e.y = int(d.y); e.z = int(d.z); _update_distance(e)
	elif d.has("zone_x") and d.has("zone_y"):
		# 0x4B : coordonnees LOCALES a la zone, comme un 0xA1. Le monde les
		# resout par l origine de zone_skin_id ; ici x/y restent null.
		e.zone_x = int(d.zone_x); e.zone_y = int(d.zone_y); e.zone_z = int(d.get("zone_z", d.get("z", 0)))
		e.zone_skin_id = int(d.get("zone_skin_id", 0)); e.z = int(d.get("z", 0))
	_touch(e, int(d.opcode), packet_index)


func _apply_update(e: Dictionary, d: Dictionary, packet_index: int) -> void:
	match int(d.opcode):
		0x15:
			e.active_weapon_slots = int(d.active_weapon_slots)
			e.equipment.clear()
			for item in d.items: e.equipment[int(item.slot)] = item.duplicate(true)
		0xA1:
			e.zone_x = int(d.zone_x); e.zone_y = int(d.zone_y); e.zone_z = int(d.zone_z)
			e.zone_skin_id = int(d.zone_skin_id); e.heading = int(d.heading); e.speed = int(d.speed)
			e.health_percent = int(d.health_percent); e.update_flags_raw = int(d.flags_raw)
		0xDE:
			_set_checked(e, "guild_id", int(d.guild_id), int(d.object_id), packet_index, "guild_update")
	_touch(e, int(d.opcode), packet_index)


func _new_entity(oid: int, entity_type: String, packet_index: int) -> Dictionary:
	return {"object_id": oid, "entity_type": entity_type, "name": "", "model_id": 0,
		"x": null, "y": null, "z": null, "heading": 0, "level": 0, "realm": 0, "size": 0,
		"equipment": {}, "guild_id": 0, "flags": {}, "source_opcodes": [],
		"first_packet_index": packet_index, "last_packet_index": packet_index,
		"confidence": {"identity": "source_derived", "position": "source_derived"},
		"delta_x": null, "delta_y": null, "delta_z": null, "distance_horizontal": null, "distance_3d": null,
		"nif_status": "UNRESOLVED", "nif_candidate": ""}


func _set_checked(e: Dictionary, key: String, value: Variant, oid: int, packet_index: int, source: String) -> void:
	if e.has(key) and e[key] != value and not _is_unset(e[key]):
		_log_conflict(oid, key, e[key], value, packet_index, source)
	e[key] = value


func _is_unset(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL: return true
		TYPE_INT, TYPE_FLOAT: return value == 0
		TYPE_STRING, TYPE_STRING_NAME: return str(value).is_empty()
		TYPE_DICTIONARY, TYPE_ARRAY: return value.is_empty()
	return false


func _touch(e: Dictionary, opcode: int, packet_index: int) -> void:
	if not e.source_opcodes.has("0x%02X" % opcode): e.source_opcodes.append("0x%02X" % opcode)
	e.first_packet_index = mini(int(e.first_packet_index), packet_index)
	e.last_packet_index = maxi(int(e.last_packet_index), packet_index)


func _update_distance(e: Dictionary) -> void:
	var dx := float(e.x) - player_position.x; var dy := float(e.y) - player_position.y; var dz := float(e.z) - player_position.z
	e.delta_x = dx; e.delta_y = dy; e.delta_z = dz
	e.distance_horizontal = sqrt(dx * dx + dy * dy); e.distance_3d = sqrt(dx * dx + dy * dy + dz * dz)


func _log_conflict(oid: int, field: String, old_value: Variant, new_value: Variant, packet_index: int, source: String = "") -> void:
	conflicts.append({"object_id": oid, "field": field, "old_value": old_value, "new_value": new_value,
		"packet_index": packet_index, "source": source})


func pending_update_count() -> int:
	var count := 0
	for rows in pending.values(): count += rows.size()
	return count


func sorted_entities() -> Array:
	var out: Array = []
	for e in entities.values(): out.append(e.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary):
		var ad := INF if a.distance_3d == null else float(a.distance_3d)
		var bd := INF if b.distance_3d == null else float(b.distance_3d)
		return int(a.object_id) < int(b.object_id) if is_equal_approx(ad, bd) else ad < bd)
	return out
