extends RefCounted
class_name DaocWorldDestinationResolver

const DaocWorldDestinationScript = preload("res://src/daoc/world/DaocWorldDestination.gd")
const DaocDolDestinationAdapterScript = preload("res://src/daoc/world/DaocDolDestinationAdapter.gd")
const DaocOpenDaocDestinationAdapterScript = preload("res://src/daoc/world/DaocOpenDaocDestinationAdapter.gd")
const DaocFallbackDestinationAdapterScript = preload("res://src/daoc/world/DaocFallbackDestinationAdapter.gd")

const SCOPE: String = "P1-17E1 WorldDestination neutral server abstraction"
const CHECKPOINT: String = "P1_17E1_WORLD_DESTINATION_ABSTRACTION"

var adapters: Array = []
var last_result: Dictionary = {}
var last_backend_attempts: Array = []


func _init() -> void:
	adapters = [
		DaocDolDestinationAdapterScript.new(),
		DaocOpenDaocDestinationAdapterScript.new(),
		DaocFallbackDestinationAdapterScript.new(),
	]


func resolve_destination_for_zone(target_zone_id: int, context: Dictionary = {}) -> Dictionary:
	last_backend_attempts = []
	var explicit_result: Dictionary = _resolve_explicit_destination(target_zone_id, context)
	if bool(explicit_result.get("ok", false)):
		last_result = _wrap_result(true, explicit_result, [])
		return last_result
	var preference: String = str(context.get("destination_backend_preference", context.get("backend_preference", "auto"))).strip_edges().to_lower()
	var ordered: Array = _ordered_adapters(preference)
	for adapter_value in ordered:
		var adapter: RefCounted = adapter_value
		if adapter == null or not adapter.has_method("resolve_destination_for_zone"):
			continue
		var result: Dictionary = adapter.call("resolve_destination_for_zone", target_zone_id, context) as Dictionary
		last_backend_attempts.append(_compact_attempt(result))
		if bool(result.get("ok", false)):
			var normalized: Dictionary = _normalize_destination_dict(result, target_zone_id)
			last_result = _wrap_result(true, normalized, last_backend_attempts)
			return last_result
	last_result = _wrap_result(false, {
		"ok": false,
		"backend": "none",
		"source": "no_server_destination_available",
		"authenticity": "fallback",
		"target_zone_id": target_zone_id,
		"target_region_id": target_zone_id,
		"error": "No DOL/OpenDAoC/manual WorldDestination available",
	}, last_backend_attempts)
	return last_result


func debug_snapshot() -> Dictionary:
	var adapter_snaps: Array = []
	for adapter_value in adapters:
		var adapter: RefCounted = adapter_value
		if adapter != null and adapter.has_method("debug_snapshot"):
			adapter_snaps.append(adapter.call("debug_snapshot"))
	return {
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"adapter_count": adapters.size(),
		"adapters": adapter_snaps,
		"last_result": last_result.duplicate(true),
		"last_backend_attempts": last_backend_attempts.duplicate(true),
	}


func _resolve_explicit_destination(target_zone_id: int, context: Dictionary) -> Dictionary:
	if context.has("world_destination") and typeof(context.get("world_destination")) == TYPE_DICTIONARY:
		var explicit_world: Dictionary = context.get("world_destination") as Dictionary
		return _normalize_destination_dict(explicit_world, target_zone_id)
	if context.has("server_destination") and typeof(context.get("server_destination")) == TYPE_DICTIONARY:
		var explicit_server: Dictionary = context.get("server_destination") as Dictionary
		return _normalize_destination_dict(explicit_server, target_zone_id)
	if context.has("spawn_daoc_x") and context.has("spawn_daoc_y"):
		var manual: Dictionary = {
			"ok": true,
			"backend": "manual_options",
			"source": "spawn_daoc_x/y/z options",
			"authenticity": "manual",
			"target_zone_id": target_zone_id,
			"target_region_id": target_zone_id,
			"x": float(context.get("spawn_daoc_x", 0.0)),
			"y": float(context.get("spawn_daoc_y", 0.0)),
			"z": float(context.get("spawn_daoc_z", context.get("spawn_z", 0.0))),
			"heading_deg": float(context.get("heading_deg", 0.0)),
		}
		return _normalize_destination_dict(manual, target_zone_id)
	return {"ok": false}


func _ordered_adapters(preference: String) -> Array:
	if preference == "" or preference == "auto" or preference == "neutral":
		return adapters.duplicate()
	var preferred: Array = []
	var rest: Array = []
	for adapter_value in adapters:
		var adapter: RefCounted = adapter_value
		if adapter != null and adapter.has_method("supports_backend") and bool(adapter.call("supports_backend", preference)):
			preferred.append(adapter)
		else:
			rest.append(adapter)
	preferred.append_array(rest)
	return preferred


func _normalize_destination_dict(data: Dictionary, target_zone_id: int) -> Dictionary:
	var destination: RefCounted = DaocWorldDestinationScript.new()
	var normalized_input: Dictionary = data.duplicate(true)
	normalized_input["target_zone_id"] = int(normalized_input.get("target_zone_id", normalized_input.get("zone_id", normalized_input.get("zone", target_zone_id))))
	if not normalized_input.has("target_region_id"):
		normalized_input["target_region_id"] = int(normalized_input.get("region_id", normalized_input.get("RegionID", normalized_input.get("TargetRegion", normalized_input.get("target_zone_id", target_zone_id)))))
	destination.call("from_dictionary", normalized_input)
	return destination.call("to_dictionary") as Dictionary


func _wrap_result(ok: bool, destination: Dictionary, attempts: Array) -> Dictionary:
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"destination": destination.duplicate(true),
		"backend": str(destination.get("backend", "none")),
		"source": str(destination.get("source", "none")),
		"authenticity": str(destination.get("authenticity", "fallback")),
		"target_zone_id": int(destination.get("target_zone_id", -1)),
		"target_region_id": int(destination.get("target_region_id", -1)),
		"attempts": attempts.duplicate(true),
		"error": str(destination.get("error", "")),
	}


func _compact_attempt(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"backend": str(result.get("backend", "")),
		"source": str(result.get("source", "")),
		"authenticity": str(result.get("authenticity", "")),
		"error": str(result.get("error", "")),
	}
