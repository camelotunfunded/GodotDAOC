extends RefCounted
class_name DaocPlayerVisualProfileRegistry

const DaocPlayerEquipmentRulesScript = preload("res://src/daoc/player/DaocPlayerEquipmentRules.gd")
const DaocPlayerSizeContractScript = preload("res://src/daoc/player/DaocPlayerSizeContract.gd")

## Relie un CharacterOverview décodé à une scène déjà exportée par Character Lab.
## Aucun NIF n'est lu ni converti au runtime.

const DEFAULT_REGISTRY_PATH := "res://config/player_visual_profiles.json"
const EQUIPMENT_U16_COUNT := 20


func load_registry(path: String = DEFAULT_REGISTRY_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "registry_missing", "path": path, "profiles": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "registry_invalid_json", "path": path, "profiles": []}
	var registry := (parsed as Dictionary).duplicate(true)
	registry["ok"] = true
	registry["path"] = path
	return registry


func resolve_character(character: Dictionary, registry_path: String = DEFAULT_REGISTRY_PATH) -> Dictionary:
	var registry := load_registry(registry_path)
	if not bool(registry.get("ok", false)):
		return registry
	var identity := normalize_identity(character)
	if not bool(identity.get("ok", false)):
		return identity
	var equipment_rules: RefCounted = DaocPlayerEquipmentRulesScript.new()
	var character_rules: Dictionary = equipment_rules.call(
		"describe_character",
		int(identity.get("class_id", 0)),
		int(identity.get("race_id", 0)),
		int(identity.get("level", 1))
	) as Dictionary
	identity["rules"] = character_rules
	identity["armor_type"] = str(character_rules.get("armor_type", "unknown"))
	var profiles := registry.get("profiles", []) as Array
	var class_fallback: Dictionary = {}
	var body_fallback: Dictionary = {}
	for raw_profile in profiles:
		if not raw_profile is Dictionary:
			continue
		var profile := raw_profile as Dictionary
		if not _body_matches(profile, identity):
			continue
		var expected_equipment := profile.get("equipment_u16", []) as Array
		if not expected_equipment.is_empty():
			if _equipment_equal(expected_equipment, identity.get("equipment", []) as Array) and _appearance_matches(profile, identity):
				return _resolved(profile, identity, "exact_equipment", registry_path)
			continue
		var class_ids := profile.get("class_ids", []) as Array
		if not _fallback_armor_matches(profile, identity):
			continue
		if not class_ids.is_empty() and _int_array_has(class_ids, int(identity.get("class_id", 0))):
			if class_fallback.is_empty():
				class_fallback = profile
		elif class_ids.is_empty() and body_fallback.is_empty():
			body_fallback = profile
	if not class_fallback.is_empty():
		return _resolved(class_fallback, identity, "class_fallback", registry_path)
	if not body_fallback.is_empty():
		return _resolved(body_fallback, identity, "body_fallback", registry_path)
	return {
		"ok": false,
		"error": "visual_profile_not_exported_for_armor" if str(identity.get("armor_type", "unknown")) != "unknown" else "unsupported_character_body",
		"expected_armor_type": str(identity.get("armor_type", "unknown")),
		"identity": identity,
		"registry_path": registry_path,
	}


func resolve_overview(overview: Dictionary, character_name: String = "", registry_path: String = DEFAULT_REGISTRY_PATH) -> Dictionary:
	var characters := overview.get("characters", []) as Array
	var wanted := character_name.strip_edges().to_lower()
	var selected: Dictionary = {}
	for raw_character in characters:
		if not raw_character is Dictionary:
			continue
		var character := raw_character as Dictionary
		if bool(character.get("empty", false)):
			continue
		if wanted.is_empty() or str(character.get("name", "")).strip_edges().to_lower() == wanted:
			selected = character
			break
	if selected.is_empty():
		return {
			"ok": false,
			"error": "overview_character_not_found",
			"character_name": character_name,
			"character_count": characters.size(),
		}
	var resolved := resolve_character(selected, registry_path)
	resolved["selected_character"] = selected.duplicate(true)
	return resolved


func normalize_identity(character: Dictionary) -> Dictionary:
	var race_id := int(character.get("race_id", 0))
	if race_id == 0 and str(character.get("race_name", "")).strip_edges().to_lower() == "briton":
		race_id = 1
	var class_id := int(character.get("class_id", 0))
	var gender := _gender_name(character)
	var packed_model := int(character.get("current_model", character.get("model", character.get("model_id", 0))))
	var size_contract := DaocPlayerSizeContractScript.describe_packed_model(packed_model)
	var appearance := character.get("appearance", {}) as Dictionary
	var face_raw := int(appearance.get("face_type", character.get("face_type", 0)))
	var hair_style_raw := int(appearance.get("hair_style", character.get("hair_style", 0)))
	var hair_color_raw := int(appearance.get("hair_color", character.get("hair_color", 0)))
	var equipment := character.get("equipment", []) as Array
	if not equipment.is_empty() and equipment.size() != EQUIPMENT_U16_COUNT:
		return {
			"ok": false,
			"error": "equipment_count_must_equal_20",
			"equipment_count": equipment.size(),
		}
	return {
		"ok": race_id > 0 and gender != "unknown",
		"error": "identity_incomplete" if race_id <= 0 or gender == "unknown" else "",
		"name": str(character.get("name", "")),
		"race_id": race_id,
		"class_id": class_id,
		"level": maxi(1, int(character.get("level", 1))),
		"gender": gender,
		"packed_model": packed_model,
		"model_id": int(size_contract.get("base_model", 0)),
		"size_choice": str(size_contract.get("size_choice", "average")),
		"size_model_bits": int(size_contract.get("size_model_bits", 0x1000)),
		"source_size_model_bits": int(size_contract.get("source_size_model_bits", 0)),
		"size_visual_factor": float(size_contract.get("size_visual_factor", 1.0)),
		"character_overview_size_value": int(size_contract.get("character_overview_size_value", 2)),
		"face_type_raw": face_raw,
		"hair_style_raw": hair_style_raw,
		"hair_color_raw": hair_color_raw,
		"face_choice": clampi(face_raw + 1, 1, 8),
		"hair_style": maxi(1, hair_style_raw + 1),
		"hair_color": clampi(hair_color_raw + 1, 1, 16),
		"equipment": _normalized_equipment(equipment),
		"equipment_signature": equipment_signature(equipment),
	}


func equipment_signature(equipment: Array) -> String:
	var fields: PackedStringArray = []
	for value in equipment:
		fields.append(str(int(value)))
	return ",".join(fields)


func _gender_name(character: Dictionary) -> String:
	if character.has("race_and_gender"):
		return "female" if ((int(character.get("race_and_gender", 0)) >> 4) & 1) == 1 else "male"
	var raw: Variant = character.get("gender", character.get("gender_name", ""))
	if raw is int or raw is float:
		return "female" if int(raw) == 1 else "male"
	var text := str(raw).strip_edges().to_lower()
	if text in ["f", "female", "femme"]:
		return "female"
	if text in ["m", "male", "homme"]:
		return "male"
	return "unknown"


func _body_matches(profile: Dictionary, identity: Dictionary) -> bool:
	var race_ids := profile.get("race_ids", []) as Array
	return _int_array_has(race_ids, int(identity.get("race_id", 0))) \
		and str(profile.get("gender", "")).to_lower() == str(identity.get("gender", "")).to_lower()


func _fallback_armor_matches(profile: Dictionary, identity: Dictionary) -> bool:
	var level := int(identity.get("level", 1))
	if level < int(profile.get("min_level", 1)):
		return false
	if profile.has("max_level") and level > int(profile.get("max_level", 50)):
		return false
	var profile_armor := str(profile.get("armor_type", "")).strip_edges().to_lower()
	if profile_armor.is_empty():
		return true
	return profile_armor == str(identity.get("armor_type", "unknown")).strip_edges().to_lower()


func _appearance_matches(profile: Dictionary, identity: Dictionary) -> bool:
	var choices := profile.get("appearance_choices", {}) as Dictionary
	if choices.is_empty():
		return true
	return int(choices.get("face_choice", -1)) == int(identity.get("face_choice", 1)) \
		and int(choices.get("hair_style", -1)) == int(identity.get("hair_style", 1)) \
		and int(choices.get("hair_color", -1)) == int(identity.get("hair_color", 1))


func _resolved(profile: Dictionary, identity: Dictionary, resolution: String, registry_path: String) -> Dictionary:
	var scene_path := str(profile.get("scene_path", ""))
	var manifest_path := str(profile.get("manifest_path", ""))
	var files_ok := FileAccess.file_exists(scene_path) and FileAccess.file_exists(manifest_path)
	var manifest := _read_manifest(manifest_path)
	var manifest_contract := manifest.get("scale_contract", {}) as Dictionary
	var manifest_visual_scale := float(manifest_contract.get("visual_scale_for_target", 0.0))
	var manifest_size_factor := float(manifest_contract.get("size_visual_factor", 1.0))
	var manifest_scale_valid := manifest_visual_scale > 0.0 and is_finite(manifest_visual_scale) \
		and manifest_size_factor > 0.0 and is_finite(manifest_size_factor)
	var average_visual_scale := manifest_visual_scale / manifest_size_factor \
		if manifest_scale_valid else float(profile.get("visual_scale", 1.0))
	var scale_source := "manifest_scale_contract" if manifest_scale_valid else "registry_visual_scale_fallback"
	var visual_scale := average_visual_scale * float(identity.get("size_visual_factor", 1.0))
	return {
		"ok": files_ok,
		"error": "" if files_ok else "profile_asset_missing",
		"resolution": resolution,
		"profile_id": str(profile.get("id", "")),
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"average_visual_scale": average_visual_scale,
		"visual_scale": visual_scale,
		"scale_source": scale_source,
		"manifest_size_choice": str(manifest_contract.get("size_choice", "unknown")),
		"manifest_size_visual_factor": manifest_size_factor if manifest_scale_valid else 0.0,
		"size_choice": str(identity.get("size_choice", "average")),
		"size_model_bits": int(identity.get("size_model_bits", 0x1000)),
		"size_visual_factor": float(identity.get("size_visual_factor", 1.0)),
		"identity": identity,
		"registry_path": registry_path,
		"runtime_options": {
			"walk_scene_path": scene_path,
			"run_scene_path": scene_path,
			"visual_scale": visual_scale,
			"scale_source": scale_source,
			"size_choice": str(identity.get("size_choice", "average")),
			"size_model_bits": int(identity.get("size_model_bits", 0x1000)),
			"size_visual_factor": float(identity.get("size_visual_factor", 1.0)),
		},
	}


func _read_manifest(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _equipment_equal(expected: Array, actual: Array) -> bool:
	if expected.size() != EQUIPMENT_U16_COUNT or actual.size() != EQUIPMENT_U16_COUNT:
		return false
	for index in range(EQUIPMENT_U16_COUNT):
		if int(expected[index]) != int(actual[index]):
			return false
	return true


func _int_array_has(values: Array, expected: int) -> bool:
	for value in values:
		if int(value) == expected:
			return true
	return false


func _normalized_equipment(equipment: Array) -> Array[int]:
	var result: Array[int] = []
	for value in equipment:
		result.append(int(value))
	return result
