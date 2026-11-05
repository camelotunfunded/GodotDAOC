extends DaocServerBackendAdapter
class_name DaocOpenDaocDestinationAdapter

## P1-17E1 — adaptateur OpenDAoC placeholder, volontairement non intrusif.
## Il fige le contrat sans supposer le nom réel des tables/protocoles OpenDAoC.

func backend_id() -> String:
	return "opendaoc"


func resolve_destination_for_zone(target_zone_id: int, context: Dictionary = {}) -> Dictionary:
	var direct: Dictionary = _lookup_table(context.get("opendaoc_destination_by_zone", {}), target_zone_id)
	if not direct.is_empty():
		var out: Dictionary = direct.duplicate(true)
		out["ok"] = bool(out.get("ok", true))
		out["backend"] = backend_id()
		out["source"] = str(out.get("source", "opendaoc_context_destination_by_zone"))
		out["authenticity"] = str(out.get("authenticity", "server_imported"))
		out["target_zone_id"] = int(out.get("target_zone_id", out.get("zone_id", out.get("zone", target_zone_id))))
		out["target_region_id"] = int(out.get("target_region_id", out.get("region_id", out.get("RegionID", target_zone_id))))
		return out
	return {
		"ok": false,
		"backend": backend_id(),
		"source": "opendaoc_tables_not_loaded",
		"authenticity": "fallback",
		"target_zone_id": target_zone_id,
		"error": "No OpenDAoC destination imported for target zone",
	}


func debug_snapshot() -> Dictionary:
	return {
		"backend": backend_id(),
		"implemented": true,
		"inputs": ["opendaoc_destination_by_zone"],
		"note": "Placeholder adapter; no OpenDAoC schema assumed yet.",
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
