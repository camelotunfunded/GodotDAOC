extends RefCounted
class_name DaocServerBackendAdapter

## P1-17E1 — interface minimale d'adaptateur serveur.
## Les sous-classes doivent retourner un Dictionary compatible DaocWorldDestination.

func backend_id() -> String:
	return "abstract"


func supports_backend(backend_name: String) -> bool:
	return backend_name.strip_edges().to_lower() == backend_id()


func resolve_destination_for_zone(_target_zone_id: int, _context: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"backend": backend_id(),
		"source": "adapter_not_implemented",
		"authenticity": "fallback",
		"error": "adapter does not implement resolve_destination_for_zone",
	}


func debug_snapshot() -> Dictionary:
	return {
		"backend": backend_id(),
		"implemented": false,
	}
