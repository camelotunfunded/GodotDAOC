extends RefCounted
class_name DaocWorldDestination

## P1-17E1 — modèle neutre de destination serveur.
## Ne dépend ni de DOL ni d'OpenDAoC : les adaptateurs remplissent ce contrat.

const AUTH_SERVER_IMPORTED: String = "server_imported"
const AUTH_SERVER_RUNTIME: String = "server_runtime"
const AUTH_MANUAL: String = "manual"
const AUTH_FALLBACK: String = "fallback"

var ok: bool = false
var backend: String = "none"
var source: String = "none"
var authenticity: String = AUTH_FALLBACK
var target_region_id: int = -1
var target_zone_id: int = -1
var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var heading_deg: float = 0.0
var heading_raw: int = 0
var table_name: String = ""
var record_id: String = ""
var source_region_id: int = -1
var source_zone_id: int = -1
var error: String = ""
var metadata: Dictionary = {}


func clear() -> void:
	ok = false
	backend = "none"
	source = "none"
	authenticity = AUTH_FALLBACK
	target_region_id = -1
	target_zone_id = -1
	x = 0.0
	y = 0.0
	z = 0.0
	heading_deg = 0.0
	heading_raw = 0
	table_name = ""
	record_id = ""
	source_region_id = -1
	source_zone_id = -1
	error = ""
	metadata.clear()


func from_dictionary(data: Dictionary) -> RefCounted:
	clear()
	ok = bool(data.get("ok", true))
	backend = str(data.get("backend", data.get("server_backend", "unknown")))
	source = str(data.get("source", data.get("destination_source", "unknown")))
	authenticity = str(data.get("authenticity", data.get("destination_authenticity", AUTH_SERVER_IMPORTED)))
	target_region_id = int(data.get("target_region_id", data.get("region_id", data.get("RegionID", -1))))
	target_zone_id = int(data.get("target_zone_id", data.get("zone_id", data.get("zone", target_region_id))))
	x = float(data.get("x", data.get("X", data.get("target_x", data.get("TargetX", 0.0)))))
	y = float(data.get("y", data.get("Y", data.get("target_y", data.get("TargetY", 0.0)))))
	z = float(data.get("z", data.get("Z", data.get("target_z", data.get("TargetZ", 0.0)))))
	heading_raw = int(data.get("heading_raw", data.get("heading", data.get("Heading", data.get("TargetHeading", 0)))))
	heading_deg = float(data.get("heading_deg", _heading_raw_to_degrees(heading_raw)))
	table_name = str(data.get("table", data.get("table_name", "")))
	record_id = str(data.get("record_id", data.get("id", data.get("TeleportID", data.get("Id", "")))))
	source_region_id = int(data.get("source_region_id", data.get("SourceRegion", -1)))
	source_zone_id = int(data.get("source_zone_id", source_region_id))
	error = str(data.get("error", ""))
	metadata = data.duplicate(true)
	return self


func to_dictionary() -> Dictionary:
	return {
		"ok": ok,
		"backend": backend,
		"source": source,
		"authenticity": authenticity,
		"target_region_id": target_region_id,
		"target_zone_id": target_zone_id,
		"x": x,
		"y": y,
		"z": z,
		"heading_deg": heading_deg,
		"heading_raw": heading_raw,
		"table": table_name,
		"record_id": record_id,
		"source_region_id": source_region_id,
		"source_zone_id": source_zone_id,
		"target_zone_id_basis": str(metadata.get("target_zone_id_basis", "")),
		"coordinate_frame_confirmed": bool(metadata.get("coordinate_frame_confirmed", false)),
		"requires_coordinate_frame_validation": bool(metadata.get("requires_coordinate_frame_validation", false)),
		"error": error,
		"metadata": metadata.duplicate(true),
	}


func is_usable() -> bool:
	return ok and target_zone_id >= 0 and error == ""


func _heading_raw_to_degrees(raw_heading: int) -> float:
	## DOL expose souvent le heading DAoC 0..4095. Si une valeur déjà en degrés
	## est passée par un adaptateur, celui-ci peut fournir heading_deg explicitement.
	if raw_heading < 0:
		return 0.0
	if raw_heading <= 4096:
		return preload("res://src/daoc/world/DaocHeading.gd").raw_to_motor_deg(raw_heading)  # P1-112
	return float(raw_heading)
