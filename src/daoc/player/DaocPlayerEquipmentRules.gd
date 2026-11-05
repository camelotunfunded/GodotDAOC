extends RefCounted
class_name DaocPlayerEquipmentRules

## Vue runtime en lecture seule du manifeste extrait de DOLSharp/OpenDAoC.
## Source générée hors ligne par Character Lab ; aucune règle n'est devinée ici.

const DEFAULT_RULES_PATH := "res://data/player/opendaoc_player_rules.json"
const EXPECTED_RULES_SHA256 := "13effc293b0a2f444f76dd8039bc2dc45139030b9c8076a1af8cad39b04a1fe0"

var _cached_path := ""
var _cached_rules: Dictionary = {}


func load_rules(path: String = DEFAULT_RULES_PATH) -> Dictionary:
	if path == _cached_path and not _cached_rules.is_empty():
		return _cached_rules
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "equipment_rules_missing", "path": path}
	var source_sha256 := FileAccess.get_sha256(path).to_lower()
	if path == DEFAULT_RULES_PATH and source_sha256 != EXPECTED_RULES_SHA256:
		return {
			"ok": false,
			"error": "equipment_rules_hash_mismatch",
			"path": path,
			"expected_sha256": EXPECTED_RULES_SHA256,
			"actual_sha256": source_sha256,
		}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "equipment_rules_invalid_json", "path": path}
	_cached_path = path
	_cached_rules = (parsed as Dictionary).duplicate(true)
	_cached_rules["ok"] = true
	_cached_rules["path"] = path
	_cached_rules["source_sha256"] = source_sha256
	return _cached_rules


func class_record(class_id: int, path: String = DEFAULT_RULES_PATH) -> Dictionary:
	var rules := load_rules(path)
	if not bool(rules.get("ok", false)):
		return {}
	for raw_record in rules.get("classes", []) as Array:
		if raw_record is Dictionary and int((raw_record as Dictionary).get("id", -1)) == class_id:
			return (raw_record as Dictionary).duplicate(true)
	return {}


func armor_type_for_level(class_id: int, player_level: int, path: String = DEFAULT_RULES_PATH) -> String:
	var record := class_record(class_id, path)
	if record.is_empty():
		return "unknown"
	var selected_type := "unknown"
	var selected_level := -1
	for raw_step in record.get("armor_progression", []) as Array:
		if not raw_step is Dictionary:
			continue
		var step := raw_step as Dictionary
		var unlock_level := int(step.get("player_level", 0))
		if unlock_level <= player_level and unlock_level >= selected_level:
			selected_level = unlock_level
			selected_type = str(step.get("armor_type", "unknown"))
	if selected_level < 0:
		selected_type = str(record.get("armor_type", "unknown"))
	return selected_type


func is_race_eligible(class_id: int, race_id: int, path: String = DEFAULT_RULES_PATH) -> bool:
	var record := class_record(class_id, path)
	if record.is_empty():
		return false
	for raw_race in record.get("eligible_races", []) as Array:
		if raw_race is Dictionary and int((raw_race as Dictionary).get("id", -1)) == race_id:
			return true
	return false


func describe_character(class_id: int, race_id: int, player_level: int, path: String = DEFAULT_RULES_PATH) -> Dictionary:
	var record := class_record(class_id, path)
	if record.is_empty():
		return {
			"ok": false,
			"error": "class_rules_not_found",
			"class_id": class_id,
			"race_id": race_id,
			"player_level": player_level,
		}
	return {
		"ok": true,
		"class_id": class_id,
		"class_name": str(record.get("name", "")),
		"race_id": race_id,
		"race_eligible": is_race_eligible(class_id, race_id, path),
		"player_level": player_level,
		"armor_type": armor_type_for_level(class_id, player_level, path),
		"realm": str(record.get("realm", "Unknown")),
		"base_class_id": int(record.get("base_class_id", 0)),
	}
