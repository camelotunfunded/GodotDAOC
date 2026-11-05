extends RefCounted
class_name DaocPlayerSpellLines

## Résout les lignes de sorts appartenant réellement au métier. Les lignes de
## base suivent le niveau du personnage ; les lignes spécialisées suivent le
## choix de progression fourni. Les choix possibles d'un métier ne sont jamais
## confondus avec les spécialisations effectivement choisies par le joueur.

const BASIS := "DUMP_SPELLLINE_AND_CLASSXSPECIALIZATION"


func resolve(catalogue: DaocSpellCatalogue, classes: DaocDolClassTable,
		class_id: int, character_level: int, trained_specs: Dictionary = {}) -> Dictionary:
	if catalogue == null or not catalogue.loaded:
		return _failure("catalogue de sorts non charge")
	if classes == null or not classes.loaded:
		return _failure("table des metiers non chargee")
	if classes.entry_for_id(class_id).is_empty():
		return _failure("metier inconnu : %d" % class_id)

	var careers: Dictionary = {}
	for value in classes.career_specs(class_id):
		careers[str(value)] = true
	var selected_specs: Dictionary = {}
	for value in trained_specs:
		var spec_name := str(value)
		if careers.has(spec_name) and int(trained_specs.get(value, 0)) > 0:
			selected_specs[spec_name] = clampi(int(trained_specs.get(value, 0)), 1, maxi(1, character_level))
	var levels: Dictionary = {}
	var base_lines: Array = []
	var specialized_lines: Array = []
	for value in catalogue.line_names():
		var line_name := str(value)
		var definition := catalogue.line_definition(line_name)
		if definition.is_empty():
			continue
		var spec_name := str(definition.get("spec", ""))
		var class_hint := int(definition.get("class_id_hint", 0))
		if not selected_specs.has(spec_name) or (class_hint != 0 and class_hint != class_id):
			continue
		if bool(definition.get("is_base_line", false)):
			levels[line_name] = maxi(1, character_level)
			base_lines.append(line_name)
		else:
			levels[line_name] = int(selected_specs[spec_name])
			specialized_lines.append(line_name)

	base_lines.sort()
	specialized_lines.sort()
	return {
		"ok": true,
		"basis": BASIS,
		"class_id": class_id,
		"character_level": maxi(1, character_level),
		"selected_specs": selected_specs,
		"line_levels": levels,
		"base_lines": base_lines,
		"specialized_lines": specialized_lines,
	}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "basis": BASIS, "line_levels": {}}
