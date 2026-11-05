extends DaocServerBackendAdapter
class_name DaocFallbackDestinationAdapter

## P1-17E1 — fallback manuel explicite.
## Ne prétend jamais être une vérité serveur : authenticity=fallback/manual.

func backend_id() -> String:
	return "fallback"


func resolve_destination_for_zone(target_zone_id: int, context: Dictionary = {}) -> Dictionary:
	var direct: Dictionary = _lookup_table(context.get("fallback_destination_by_zone", {}), target_zone_id)
	if not direct.is_empty():
		return _normalize_direct(direct, target_zone_id, "fallback_destination_by_zone")
	if context.has("fallback_destination") and typeof(context.get("fallback_destination")) == TYPE_DICTIONARY:
		return _normalize_direct(context.get("fallback_destination") as Dictionary, target_zone_id, "fallback_destination")
	return {
		"ok": false,
		"backend": backend_id(),
		"source": "no_manual_fallback_destination",
		"authenticity": "fallback",
		"target_zone_id": target_zone_id,
		"error": "No manual fallback destination provided",
	}


func debug_snapshot() -> Dictionary:
	return {
		"backend": backend_id(),
		"implemented": true,
		"inputs": ["fallback_destination_by_zone", "fallback_destination"],
		"truth_level": "manual/fallback only",
	}


func _lookup_table(value: Variant, target_zone_id: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var table: Dictionary = value as Dictionary
	if table.has(target_zone_id):
		var direct_value: Variant = table[target_zone_id]
		if typeof(direct_value) == TYPE_DICTIONARY:
			return direct_value as Dictionary
	var key_text: String = str(target_zone_id)
	if table.has(key_text):
		var text_value: Variant = table[key_text]
		if typeof(text_value) == TYPE_DICTIONARY:
			return text_value as Dictionary
	return {}


func _normalize_direct(data: Dictionary, target_zone_id: int, source_name: String) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out["ok"] = bool(out.get("ok", true))
	out["backend"] = backend_id()
	out["source"] = str(out.get("source", source_name))
	out["authenticity"] = str(out.get("authenticity", "fallback"))
	out["target_zone_id"] = int(out.get("target_zone_id", out.get("zone_id", out.get("zone", target_zone_id))))
	out["target_region_id"] = int(out.get("target_region_id", out.get("region_id", out.get("RegionID", target_zone_id))))
	return out
