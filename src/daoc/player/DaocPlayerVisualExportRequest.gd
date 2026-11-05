extends RefCounted
class_name DaocPlayerVisualExportRequest

const DaocPlayerVisualProfileRegistryScript = preload("res://src/daoc/player/DaocPlayerVisualProfileRegistry.gd")

const SCHEMA_VERSION := 1
const EQUIPMENT_U16_COUNT := 20

## Correspondance exacte avec ModernPlayerProfiles.BASE_APPEARANCES du lab.
## Les Minotaures et formes spéciales ne font pas partie des 36 corps de base.
const RACE_TO_APPEARANCE_PAIR := {
	1: [1, 2], 4: [3, 4], 17: [5, 6], 18: [7, 8], 2: [9, 10],
	11: [11, 12], 3: [13, 14], 5: [15, 16], 12: [17, 18], 8: [19, 20],
	7: [21, 22], 13: [23, 24], 16: [25, 26], 14: [27, 28], 10: [29, 30],
	6: [31, 32], 9: [33, 34], 15: [35, 36],
}


func build_for_character(character: Dictionary, registry_path: String = DaocPlayerVisualProfileRegistryScript.DEFAULT_REGISTRY_PATH) -> Dictionary:
	var registry: RefCounted = DaocPlayerVisualProfileRegistryScript.new()
	var identity: Dictionary = registry.call("normalize_identity", character) as Dictionary
	if not bool(identity.get("ok", false)):
		return {
			"ok": false,
			"error": str(identity.get("error", "identity_incomplete")),
			"schema_version": SCHEMA_VERSION,
			"identity": identity,
		}
	var appearance_id := appearance_id_for_identity(identity)
	if appearance_id <= 0:
		return {
			"ok": false,
			"error": "appearance_not_catalogued",
			"schema_version": SCHEMA_VERSION,
			"identity": identity,
		}
	var resolved: Dictionary = registry.call("resolve_character", character, registry_path) as Dictionary
	var exact := bool(resolved.get("ok", false)) and str(resolved.get("resolution", "")) == "exact_equipment"
	var equipment := identity.get("equipment", []) as Array
	var requested_id := _requested_scene_id(identity, appearance_id)
	return {
		"ok": true,
		"schema_version": SCHEMA_VERSION,
		"request_kind": "modern_player_scene_export",
		"required": not exact,
		"reason": "exact_profile_available" if exact else "exact_profile_missing",
		"source": "CharacterOverview decoded offline; no runtime NIF conversion",
		"requested_scene_id": requested_id,
		"appearance_id": appearance_id,
		"packed_model": int(identity.get("packed_model", 0)),
		"base_model": int(identity.get("model_id", 0)),
		"size_choice": str(identity.get("size_choice", "average")),
		"size_model_bits": int(identity.get("size_model_bits", 0x1000)),
		"size_visual_factor": float(identity.get("size_visual_factor", 1.0)),
		"face_choice": int(identity.get("face_choice", 1)),
		"hair_style": int(identity.get("hair_style", 1)),
		"hair_color": int(identity.get("hair_color", 1)),
		"race_id": int(identity.get("race_id", 0)),
		"gender": str(identity.get("gender", "unknown")),
		"class_id": int(identity.get("class_id", 0)),
		"level": int(identity.get("level", 1)),
		"armor_type": str((resolved.get("identity", identity) as Dictionary).get("armor_type", "unknown")),
		"equipment_u16": equipment.duplicate(),
		"equipment_signature": str(identity.get("equipment_signature", "")),
		"current_resolution": resolved,
		"consumer": "daoc_character_lab ModernPlayerProfiles + offline scene exporter",
		"target_registry": registry_path,
	}


func build_for_overview(overview: Dictionary, character_name: String = "", registry_path: String = DaocPlayerVisualProfileRegistryScript.DEFAULT_REGISTRY_PATH) -> Dictionary:
	var characters := overview.get("characters", []) as Array
	var wanted := character_name.strip_edges().to_lower()
	for raw_character in characters:
		if not raw_character is Dictionary:
			continue
		var character := raw_character as Dictionary
		if bool(character.get("empty", false)):
			continue
		if wanted.is_empty() or str(character.get("name", "")).strip_edges().to_lower() == wanted:
			return build_for_character(character, registry_path)
	return {"ok": false, "error": "overview_character_not_found", "schema_version": SCHEMA_VERSION}


func appearance_id_for_identity(identity: Dictionary) -> int:
	var race_id := int(identity.get("race_id", 0))
	if not RACE_TO_APPEARANCE_PAIR.has(race_id):
		return -1
	var pair := RACE_TO_APPEARANCE_PAIR[race_id] as Array
	return int(pair[1] if str(identity.get("gender", "")).to_lower() == "female" else pair[0])


func _requested_scene_id(identity: Dictionary, appearance_id: int) -> String:
	var signature := str(identity.get("equipment_signature", ""))
	var hash_value := signature.sha256_text().substr(0, 12) if not signature.is_empty() else "base"
	return "appearance_%02d_class_%02d_level_%02d_%s_f%02d_h%02d_c%02d_%s" % [
		appearance_id,
		int(identity.get("class_id", 0)),
		int(identity.get("level", 1)),
		hash_value,
		int(identity.get("face_choice", 1)),
		int(identity.get("hair_style", 1)),
		int(identity.get("hair_color", 1)),
		str(identity.get("size_choice", "average")),
	]
