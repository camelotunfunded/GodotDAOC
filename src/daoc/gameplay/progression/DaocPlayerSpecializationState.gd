extends RefCounted
class_name DaocPlayerSpecializationState

## Choix de progression propres a un personnage. La table de metier ne decrit
## que les choix possibles : elle ne doit jamais remplir ce dictionnaire.

var character_key: String = "default"
var class_id: int = 0
var character_level: int = 1
var trained_specs: Dictionary = {}


func setup(p_character_key: String, p_class_id: int, p_character_level: int) -> DaocPlayerSpecializationState:
	character_key = p_character_key.strip_edges() if p_character_key.strip_edges() != "" else "default"
	class_id = p_class_id
	character_level = maxi(1, p_character_level)
	return self


func replace_choices(requested: Dictionary, available_specs: Array) -> Dictionary:
	var allowed: Dictionary = {}
	for value in available_specs:
		allowed[str(value)] = true
	var accepted: Dictionary = {}
	var rejected: Array = []
	for value in requested:
		var spec_name := str(value)
		var spec_level := int(requested.get(value, 0))
		if not allowed.has(spec_name) or spec_level <= 0:
			rejected.append(spec_name)
			continue
		accepted[spec_name] = clampi(spec_level, 1, character_level)
	trained_specs = accepted
	rejected.sort()
	return {"ok": rejected.is_empty(), "trained_specs": trained_specs.duplicate(true), "rejected": rejected}


func save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "sauvegarde inaccessible"}
	file.store_string(JSON.stringify({
		"version": 1, "character": character_key, "class_id": class_id,
		"character_level": character_level, "trained_specs": trained_specs,
	}, "\t"))
	file.close()
	return {"ok": true, "trained_count": trained_specs.size()}


func load(path: String, available_specs: Array) -> Dictionary:
	trained_specs.clear()
	if not FileAccess.file_exists(path):
		return {"ok": true, "trained_count": 0, "new_file": true}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "sauvegarde illisible"}
	var payload := parsed as Dictionary
	if str(payload.get("character", "")) != character_key or int(payload.get("class_id", -1)) != class_id:
		return {"ok": false, "reason": "sauvegarde d'un autre personnage ou metier"}
	var result := replace_choices(payload.get("trained_specs", {}) as Dictionary, available_specs)
	result["trained_count"] = trained_specs.size()
	return result
