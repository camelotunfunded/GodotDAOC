extends RefCounted
class_name DaocPlayerSpellLoadout

## Construit la liste des sorts qu'un personnage peut reellement proposer au
## joueur. Le catalogue repond « connu a ce niveau » ; le registre repond
## « executable par le moteur ». Ce composant est la couture entre les deux.

const BASIS := "DUMP_LINEXSPELL_AND_HANDLER_REGISTRY"


func build(catalogue: DaocSpellCatalogue, registry: DaocGameplayMechanicsRegistry,
		line_levels: Dictionary) -> Dictionary:
	if catalogue == null or not catalogue.loaded:
		return _failure("catalogue de sorts non charge")
	if registry == null:
		return _failure("registre de gestionnaires absent")

	var usable: Array = []
	var blocked: Array = []
	var unknown_lines: Array = []
	var known_lines: Dictionary = {}
	for known in catalogue.line_names():
		known_lines[str(known)] = true

	var requested_lines: Array = line_levels.keys()
	requested_lines.sort()
	for line_value in requested_lines:
		var line_name := str(line_value)
		var specialization_level := maxi(0, int(line_levels[line_value]))
		if not known_lines.has(line_name):
			unknown_lines.append(line_name)
			continue
		for assignment_value in catalogue.spells_up_to_level(line_name, specialization_level):
			var assignment := assignment_value as Dictionary
			var spell_id := int(assignment.get("spell_id", 0))
			var raw := catalogue.raw_spell(spell_id)
			if raw.is_empty():
				blocked.append(_entry(line_name, specialization_level, assignment, {}, "sort absent du catalogue"))
				continue
			var spell := DaocSpellDef.from_dict(raw)
			if registry.create_handler(spell, line_name) == null:
				blocked.append(_entry(line_name, specialization_level, assignment, raw,
					"Type sans gestionnaire : %s" % spell.spell_type))
				continue
			usable.append(_entry(line_name, specialization_level, assignment, raw, ""))

	return {
		"ok": true,
		"basis": BASIS,
		"requested_line_count": requested_lines.size(),
		"usable_count": usable.size(),
		"blocked_count": blocked.size(),
		"unknown_lines": unknown_lines,
		"usable": usable,
		"blocked": blocked,
	}


func _entry(line_name: String, specialization_level: int, assignment: Dictionary,
		raw: Dictionary, reason: String) -> Dictionary:
	return {
		"line": line_name,
		"specialization_level": specialization_level,
		"required_level": int(assignment.get("level", 0)),
		"spell_id": int(assignment.get("spell_id", 0)),
		"name": str(raw.get("Name", "")),
		"spell_type": str(raw.get("Type", "")),
		"power": int(raw.get("Power", 0)),
		"cast_time": DaocSpellDef.from_dict(raw).cast_time if not raw.is_empty() else 0,
		"range": int(raw.get("Range", 0)),
		"icon": int(raw.get("Icon", 0)),
		"client_effect": int(raw.get("ClientEffect", 0)),
		"blocked_reason": reason,
	}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "basis": BASIS, "usable": [], "blocked": []}
