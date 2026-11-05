extends DaocServerBackendAdapter
class_name DaocDolDestinationAdapter

## P1-17E1 — adaptateur DOL neutre.
## Pour l'instant il consomme uniquement des tables déjà importées/passées en contexte.
## Données attendues plus tard : Teleport.csv / ZonePoint.csv -> WorldDestination.

func backend_id() -> String:
	return "dol"


func resolve_destination_for_zone(target_zone_id: int, context: Dictionary = {}) -> Dictionary:
	var direct: Dictionary = _lookup_table(context.get("dol_destination_by_zone", {}), target_zone_id)
	if not direct.is_empty():
		return _normalize_direct(direct, target_zone_id, "dol_context_destination_by_zone")
	var teleport: Dictionary = _lookup_table(context.get("dol_teleport_by_zone", {}), target_zone_id)
	if not teleport.is_empty():
		var out_teleport: Dictionary = _normalize_direct(teleport, target_zone_id, "dol.teleport")
		out_teleport["table"] = "Teleport"
		out_teleport["authenticity"] = "server_imported"
		return out_teleport
	var zonepoint: Dictionary = _lookup_table(context.get("dol_zonepoint_by_zone", {}), target_zone_id)
	if not zonepoint.is_empty():
		var out_zonepoint: Dictionary = _normalize_direct(zonepoint, target_zone_id, "dol.zonepoint")
		out_zonepoint["table"] = "ZonePoint"
		out_zonepoint["authenticity"] = "server_imported"
		return out_zonepoint
	return {
		"ok": false,
		"backend": backend_id(),
		"source": "dol_tables_not_loaded",
		"authenticity": "fallback",
		"target_zone_id": target_zone_id,
		"error": "No DOL Teleport/ZonePoint destination imported for target zone",
	}


func debug_snapshot() -> Dictionary:
	return {
		"backend": backend_id(),
		"implemented": true,
		"inputs": ["dol_destination_by_zone", "dol_teleport_by_zone", "dol_zonepoint_by_zone"],
		"tables": ["Teleport", "ZonePoint"],
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
	out["authenticity"] = str(out.get("authenticity", "server_imported"))
	out["target_zone_id"] = int(out.get("target_zone_id", out.get("zone_id", out.get("zone", target_zone_id))))
	out["target_region_id"] = int(out.get("target_region_id", out.get("region_id", out.get("RegionID", out.get("TargetRegion", target_zone_id)))))
	return out
