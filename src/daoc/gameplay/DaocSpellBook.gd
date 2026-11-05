extends RefCounted
class_name DaocSpellBook

var spells_by_id: Dictionary = {}
var spells_by_type: Dictionary = {}

func clear() -> void:
	spells_by_id.clear()
	spells_by_type.clear()


func add_spell(spell: DaocSpellDef) -> void:
	if spell == null:
		return
	spells_by_id[spell.id] = spell
	if not spells_by_type.has(spell.spell_type):
		spells_by_type[spell.spell_type] = []
	(spells_by_type[spell.spell_type] as Array).append(spell)

func load_from_array(rows: Array) -> void:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			add_spell(DaocSpellDef.from_dict(row as Dictionary))

func load_from_json_file(path: String) -> Dictionary:
	var out = {"ok": false, "path": path, "loaded": 0}
	if not FileAccess.file_exists(path):
		out["error"] = "missing file"
		return out
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["error"] = "open failed"
		return out
	var text = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		out["error"] = "expected array"
		return out
	load_from_array(parsed as Array)
	out["ok"] = true
	out["loaded"] = spells_by_id.size()
	return out

func get_spell(id: int) -> DaocSpellDef:
	return spells_by_id.get(id, null) as DaocSpellDef

func first_by_type(spell_type: String) -> DaocSpellDef:
	var arr: Array = spells_by_type.get(spell_type, []) as Array
	return arr[0] as DaocSpellDef if arr.size() > 0 else null

func snapshot() -> Dictionary:
	var counts = {}
	for key in spells_by_type.keys():
		counts[key] = (spells_by_type[key] as Array).size()
	return {"spell_count": spells_by_id.size(), "type_counts": counts}


func load_from_array_reset(rows: Array) -> void:
	clear()
	load_from_array(rows)

func first_by_supported_types(types: Array) -> DaocSpellDef:
	for type_value in types:
		var spell: DaocSpellDef = first_by_type(str(type_value))
		if spell != null:
			return spell
	return null

func ids_by_type(spell_type: String, limit: int = 50) -> Array:
	var out: Array = []
	var arr: Array = spells_by_type.get(spell_type, []) as Array
	for item in arr:
		var spell: DaocSpellDef = item as DaocSpellDef
		if spell == null:
			continue
		out.append(spell.id)
		if limit > 0 and out.size() >= limit:
			break
	return out
