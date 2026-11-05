extends RefCounted
class_name DaocServerClientZoneMap

## P1-17F1 — runtime-only server RegionID -> client zone adapter.
## This is deliberately NOT generated-scene data. It is an external bridge used
## by offline/server preview tools to decide whether a server entity belongs to
## the currently visible client zone(s).

const SCOPE: String = "P1-17F1 runtime server/client zone mapping"
const CHECKPOINT: String = "P1_17F1_RUNTIME_SERVER_CLIENT_ZONE_MAPPING"

const EXPLICIT_REGION_ZONE_MAPPING: Array = [
	{
		"region_id": 1,
		"region_name": "Albion exterior preview baseline",
		"client_zone_id": 0,
		"client_zone_name": "zone000",
		"zone_kind": "terrain_heightmap",
		"confidence": "validated_offline_preview_mapping",
		"mapping_basis": "explicit_runtime_mapping",
		"source": "P1-17E2V offline preview user validation on zone000",
		"coordinate_frame_confirmed": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
		"server_region_scope": "multi_client_zone_exterior",
		"allow_visible_zone_projection": true,
	},
	{
		"region_id": 20,
		"region_name": "Stonehenge Barrows",
		"client_zone_id": 19,
		"client_zone_name": "zone019",
		"zone_kind": "dungeon_chunk",
		"confidence": "validated_marker_only_mapping",
		"mapping_basis": "explicit_runtime_mapping",
		"source": "P1-17E2F/E2J OpenDAoC ZonePoint marker-only",
		"coordinate_frame_confirmed": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
	},
	{
		"region_id": 21,
		"region_name": "Tomb of Mithra",
		"client_zone_id": 21,
		"client_zone_name": "zone021",
		"zone_kind": "dungeon_chunk",
		"confidence": "validated_marker_only_mapping",
		"mapping_basis": "explicit_runtime_mapping",
		"source": "P1-17E2F/E2J OpenDAoC ZonePoint marker-only",
		"coordinate_frame_confirmed": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
	},
]


func known_mappings() -> Array:
	var out: Array = []
	for mapping_value in EXPLICIT_REGION_ZONE_MAPPING:
		out.append((mapping_value as Dictionary).duplicate(true))
	return out


func region_to_client_zone_dictionary(include_string_keys: bool = true) -> Dictionary:
	var out: Dictionary = {}
	for mapping_value in EXPLICIT_REGION_ZONE_MAPPING:
		var mapping: Dictionary = mapping_value as Dictionary
		var region_id: int = int(mapping.get("region_id", -1))
		var client_zone_id: int = int(mapping.get("client_zone_id", -1))
		if region_id < 0 or client_zone_id < 0:
			continue
		out[region_id] = client_zone_id
		if include_string_keys:
			out[str(region_id)] = client_zone_id
	return out


func resolve_entity(entity: Dictionary, options: Dictionary = {}) -> Dictionary:
	return resolve_region(int(entity.get("region_id", entity.get("target_region_id", -1))), options)


func resolve_region(region_id: int, options: Dictionary = {}) -> Dictionary:
	var visible_zone_ids: Array = _int_array(options.get("visible_client_zone_ids", []))
	var default_client_zone_id: int = int(options.get("default_client_zone_id", -1))
	var explicit: Dictionary = _explicit_mapping_for_region(region_id)
	if not explicit.is_empty():
		var explicit_result: Dictionary = _resolution_from_mapping(region_id, explicit, visible_zone_ids)
		if bool(explicit_result.get("visible_client_zone_match", false)):
			return explicit_result
		if _can_project_explicit_region_to_visible_zone(explicit, options, visible_zone_ids):
			return _candidate_resolution(region_id, int(visible_zone_ids[0]), "server_region_global_visible_zone_projection", visible_zone_ids)
		return explicit_result
	if bool(options.get("allow_visible_zone_candidate_mapping", true)):
		var minus_one_zone: int = region_id - 1
		if region_id > 0 and visible_zone_ids.has(minus_one_zone):
			return _candidate_resolution(region_id, minus_one_zone, "region_minus_one_visible_zone_candidate", visible_zone_ids)
		if visible_zone_ids.has(region_id):
			return _candidate_resolution(region_id, region_id, "region_equal_visible_zone_candidate", visible_zone_ids)
	if bool(options.get("allow_default_zone_fallback", false)) and default_client_zone_id >= 0:
		return _candidate_resolution(region_id, default_client_zone_id, "default_visible_zone_preview_fallback", visible_zone_ids)
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"region_id": region_id,
		"client_zone_id": -1,
		"mapping_basis": "unmapped_region_runtime_adapter",
		"mapping_confidence": "unmapped",
		"visible_client_zone_match": false,
		"visible_client_zone_ids": visible_zone_ids,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
	}


func _resolution_from_mapping(region_id: int, mapping: Dictionary, visible_zone_ids: Array) -> Dictionary:
	var client_zone_id: int = int(mapping.get("client_zone_id", -1))
	var visible_match: bool = visible_zone_ids.is_empty() or visible_zone_ids.has(client_zone_id)
	var result: Dictionary = mapping.duplicate(true)
	result["ok"] = client_zone_id >= 0
	result["scope"] = SCOPE
	result["checkpoint"] = CHECKPOINT
	result["region_id"] = region_id
	result["client_zone_id"] = client_zone_id
	result["client_zone_name"] = str(result.get("client_zone_name", "zone%03d" % client_zone_id))
	result["mapping_basis"] = str(result.get("mapping_basis", "explicit_runtime_mapping"))
	result["mapping_confidence"] = str(result.get("confidence", "explicit"))
	result["visible_client_zone_match"] = visible_match
	result["visible_client_zone_ids"] = visible_zone_ids
	result["runtime_enabled"] = false
	result["coordinate_frame_confirmed"] = false
	result["player_spawn_applied"] = false
	return result



func _can_project_explicit_region_to_visible_zone(mapping: Dictionary, options: Dictionary, visible_zone_ids: Array) -> bool:
	if visible_zone_ids.is_empty():
		return false
	if not bool(options.get("allow_explicit_region_visible_zone_projection", true)):
		return false
	if not bool(mapping.get("allow_visible_zone_projection", false)):
		return false
	# This is preview-only: server regions such as Albion Region001 can span
	# several client terrain zones. We project their global server coordinates
	# into the currently visible terrain zone with local /loc folding, without
	# confirming the authoritative coordinate frame.
	return true

func _candidate_resolution(region_id: int, client_zone_id: int, basis: String, visible_zone_ids: Array) -> Dictionary:
	return {
		"ok": client_zone_id >= 0,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"region_id": region_id,
		"region_name": "Region%03d" % region_id,
		"client_zone_id": client_zone_id,
		"client_zone_name": "zone%03d" % client_zone_id,
		"zone_kind": "unknown",
		"mapping_basis": basis,
		"mapping_confidence": "preview_candidate_unconfirmed",
		"visible_client_zone_match": visible_zone_ids.is_empty() or visible_zone_ids.has(client_zone_id),
		"visible_client_zone_ids": visible_zone_ids,
		"server_authority": false,
		"gameplay_fake": false,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
	}


func _explicit_mapping_for_region(region_id: int) -> Dictionary:
	for mapping_value in EXPLICIT_REGION_ZONE_MAPPING:
		var mapping: Dictionary = mapping_value as Dictionary
		if int(mapping.get("region_id", -1)) == region_id:
			return mapping.duplicate(true)
	return {}


func _int_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_PACKED_INT32_ARRAY:
		for item in (value as PackedInt32Array):
			if not out.has(int(item)):
				out.append(int(item))
		return out
	if typeof(value) != TYPE_ARRAY:
		return out
	for item_value in (value as Array):
		var item: int = int(item_value)
		if not out.has(item):
			out.append(item)
	return out
