extends RefCounted
class_name DaocPregameDataAdapter

const UI_PHASE_REALM_SELECT := "REALM_SELECT"
const UI_PHASE_CHARACTER_SELECT := "CHARACTER_SELECT"
const REALMDESC_PATH := "res://assets/daoc/pregame/ui/realmdesc.txt"


func available_realms() -> Array[Dictionary]:
	var descriptions := parse_realm_descriptions()
	return [
		{"id": 1, "name": "Albion", "short": "alb", "description": str(descriptions.get(1, "")), "enabled": true},
		{"id": 2, "name": "Midgard", "short": "mid", "description": str(descriptions.get(2, "")), "enabled": true},
		{"id": 3, "name": "Hibernia", "short": "hib", "description": str(descriptions.get(3, "")), "enabled": true},
	]


func visual_realm_order() -> Array[int]:
	return [1, 3, 2]


func parse_realm_descriptions(path: String = REALMDESC_PATH) -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(path):
		return result
	var text := FileAccess.get_file_as_string(path)
	var current_id := 0
	var lines := PackedStringArray()
	for raw in text.replace("\r", "").split("\n"):
		var line := str(raw).strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			if current_id > 0:
				result[current_id] = " ".join(lines)
			current_id = realm_id_for_name(line.substr(1, line.length() - 2))
			lines = PackedStringArray()
		elif line != "" and current_id > 0:
			lines.append(line)
	if current_id > 0:
		result[current_id] = " ".join(lines)
	return result


func fixture_catalog() -> Array[Dictionary]:
	return [
		_character(0, 1, "Aelynn", 34, "Clerc", "Bretonne", "Camelot", 1),
		_character(1, 1, "Gareth", 18, "Maître d'armes", "Highlander", "Cotswold", 1),
		_character(0, 2, "Sigrun", 41, "Valkyrie", "Norse", "Jordheim", 100),
		_character(1, 2, "Bruni", 22, "Guérisseur", "Nain", "Mularn", 100),
		_character(0, 3, "Liora", 29, "Enchanteresse", "Elfe", "Tir na Nog", 200),
		_character(1, 3, "Caolan", 12, "Champion", "Celte", "Mag Mell", 200),
	]


func offline_fixture(selected_realm_id: int = 1) -> Dictionary:
	var realm_id := clampi(selected_realm_id, 1, 3)
	var characters: Array[Dictionary] = []
	for character in fixture_catalog():
		if int(character.get("realm_id", 0)) == realm_id:
			characters.append(character.duplicate(true))
	return normalize_model({
		"ui_phase": UI_PHASE_CHARACTER_SELECT,
		"selected_realm": realm_snapshot(realm_id),
		"available_realms": available_realms(),
		"characters": characters,
		"character_count": characters.size(),
		"selected": {},
		"source": "offline",
	})


func empty_overview_model(selected_realm_id: int = 1, source: String = "live") -> Dictionary:
	var realm_id := clampi(selected_realm_id, 1, 3)
	return normalize_model({
		"ui_phase": UI_PHASE_CHARACTER_SELECT,
		"selected_realm": realm_snapshot(realm_id),
		"available_realms": available_realms(),
		"characters": [],
		"character_count": 0,
		"selected": {},
		"source": source,
	})


func model_from_hud(hud: Node) -> Dictionary:
	if hud == null or not hud.has_method("build_login_selection_flow_model"):
		return empty_overview_model(1, "offline")
	return normalize_model(hud.call("build_login_selection_flow_model") as Dictionary)


func normalize_model(raw: Dictionary) -> Dictionary:
	var model := normalize_character_overview(raw)
	var realm_id := int((model.get("selected_realm", {}) as Dictionary).get("id", 1))
	if realm_id < 1 or realm_id > 3:
		realm_id = 1
	model["selected_realm"] = realm_snapshot(realm_id)
	model["available_realms"] = available_realms()
	model["selected"] = raw.get("selected", {}) as Dictionary
	model["source"] = str(raw.get("source", model.get("source", "offline")))
	model["ui_phase"] = str(raw.get("ui_phase", UI_PHASE_CHARACTER_SELECT))
	return model


func normalize_character_overview(raw_overview: Dictionary) -> Dictionary:
	var model := raw_overview.duplicate(true)
	var selected_realm_raw: Dictionary = model.get("selected_realm", {}) as Dictionary
	var realm_id := int(selected_realm_raw.get("id", model.get("realm_id", 1)))
	if realm_id < 1 or realm_id > 3:
		realm_id = 1
	var slots: Array[Dictionary] = []
	for i in range(10):
		slots.append(_empty_slot(i, realm_id))

	var warnings: Array[String] = []
	var uses_slots := model.has("slots") and typeof(model.get("slots")) == TYPE_ARRAY
	var input_entries: Array = (model.get("slots", []) if uses_slots else model.get("characters", [])) as Array
	for array_index in range(input_entries.size()):
		if typeof(input_entries[array_index]) != TYPE_DICTIONARY:
			_add_warning(warnings, "overview entry %d ignored: expected Dictionary" % array_index)
			continue
		var raw_character := (input_entries[array_index] as Dictionary).duplicate(true)
		var slot_index := _resolve_slot_index(raw_character, array_index)
		if slot_index < 0 or slot_index >= 10:
			_add_warning(warnings, "overview entry %d ignored: slot index %d is outside 0..9" % [array_index, slot_index])
			continue
		slots[slot_index] = _normalize_slot(raw_character, slot_index, realm_id)

	var characters: Array[Dictionary] = []
	for slot in slots:
		if bool(slot.get("valid", false)):
			characters.append(slot.duplicate(true))
	model["selected_realm"] = realm_snapshot(realm_id)
	model["available_realms"] = available_realms()
	model["slots"] = slots
	model["characters"] = characters
	model["character_count"] = _valid_count(slots)
	model["selected"] = model.get("selected", {}) as Dictionary
	model["source"] = str(model.get("source", "offline"))
	model["ui_phase"] = str(model.get("ui_phase", UI_PHASE_CHARACTER_SELECT))
	model["overview_input"] = "slots" if uses_slots else "characters"
	model["warnings"] = warnings
	return model


func _resolve_slot_index(character: Dictionary, array_index: int) -> int:
	for alias in ["slot", "slot_index", "index", "account_slot"]:
		if character.has(alias):
			return int(character.get(alias, array_index))
	return array_index


func _normalize_slot(character: Dictionary, slot_index: int, default_realm_id: int) -> Dictionary:
	var name := str(character.get("name", "")).strip_edges()
	var is_empty := name == ""
	if character.has("is_empty"):
		is_empty = bool(character.get("is_empty", true))
	elif character.has("empty"):
		is_empty = bool(character.get("empty", true))
	if character.has("valid") and not bool(character.get("valid", false)):
		is_empty = true
	if name == "":
		is_empty = true
	var profession_name := str(character.get("class_name", character.get("class", ""))).strip_edges()
	var race_name := str(character.get("race_name", character.get("race", ""))).strip_edges()
	var location := str(character.get("location", character.get("location_description", character.get("region_name", "")))).strip_edges()
	return {
		"slot_index": slot_index,
		"is_empty": is_empty,
		"empty": is_empty,
		"valid": not is_empty,
		"name": name,
		"level": int(character.get("level", 0)),
		"class_name": profession_name,
		"race_name": race_name,
		"location": location,
		"region_id": int(character.get("region_id", 0)),
		"realm_id": int(character.get("realm_id", default_realm_id)),
		"raw": character.duplicate(true),
	}


func _empty_slot(slot_index: int, realm_id: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"is_empty": true,
		"empty": true,
		"valid": false,
		"name": "",
		"level": 0,
		"class_name": "",
		"race_name": "",
		"location": "",
		"region_id": 0,
		"realm_id": realm_id,
		"raw": {},
	}


func _add_warning(warnings: Array[String], message: String) -> void:
	warnings.append(message)
	push_warning("P1-20UI-B: %s" % message)


func realm_snapshot(realm_id: int) -> Dictionary:
	for realm in available_realms():
		if int(realm.get("id", 0)) == realm_id:
			return realm.duplicate(true)
	return {}


func realm_id_for_name(value: String) -> int:
	match value.strip_edges().to_lower():
		"alb", "albion": return 1
		"mid", "midgard": return 2
		"hib", "hibernia": return 3
	return 0


func _valid_count(slots: Array[Dictionary]) -> int:
	var count := 0
	for slot in slots:
		if bool(slot.get("valid", false)):
			count += 1
	return count


func _character(slot_index: int, realm_id: int, name: String, level: int, profession: String, race: String, location: String, region_id: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"realm_id": realm_id,
		"name": name,
		"level": level,
		"class_name": profession,
		"class": profession,
		"race_name": race,
		"race": race,
		"location": location,
		"region_id": region_id,
		"valid": true,
		"empty": false,
	}
