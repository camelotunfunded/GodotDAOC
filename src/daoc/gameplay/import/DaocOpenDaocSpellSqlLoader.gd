extends RefCounted
class_name DaocOpenDaocSpellSqlLoader

## P1-18D — OpenDAoC spell.sql -> DaocSpellDef rows.
## Parse-only, offline, prediction-only. No runtime gameplay and no server authority claim.

const CHECKPOINT: String = "P1_18D_OPENDAOC_SPELL_SQL_SPELLBOOK"
const SCOPE: String = "P1-18D OpenDAoC spell SQL -> Godot SpellBook"
const SPELL_FILE_CANDIDATES: Array = ["spell.sql", "spells.sql", "Spell.sql", "Spells.sql"]
const DEFAULT_MAX_ROWS: int = 8192

func load_spell_defs_from_candidates(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var checked: Array = []
	for value in candidate_dirs:
		var candidate: String = str(value).strip_edges()
		if candidate == "":
			continue
		checked.append(candidate)
		var resolved: String = _resolve_directory_path(candidate)
		if resolved == "":
			continue
		var result: Dictionary = load_spell_defs_from_directory(resolved, options)
		result["checked_paths"] = checked.duplicate(true)
		if bool(result.get("ok", false)):
			return result
	return _waiting_result(checked)

func load_spell_defs_from_directory(directory_path: String, options: Dictionary = {}) -> Dictionary:
	var resolved_dir: String = _resolve_directory_path(directory_path)
	if resolved_dir == "":
		return _error_result("directory_not_found", directory_path, "")
	var spell_path: String = _find_spell_sql_file(resolved_dir)
	if spell_path == "":
		return _error_result("spell_sql_not_found", directory_path, resolved_dir)
	return load_spell_defs_from_sql_file(spell_path, options)

func load_spell_defs_from_sql_file(path: String, options: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error_result("spell_sql_file_not_found", path, "")
	var text: String = FileAccess.get_file_as_string(path)
	return load_spell_defs_from_sql_text(text, path, options)

func load_spell_defs_from_sql_text(sql_text: String, source_path: String = "", options: Dictionary = {}) -> Dictionary:
	var max_rows: int = int(options.get("max_rows", DEFAULT_MAX_ROWS))
	var columns: Array = _infer_insert_columns(sql_text)
	var rows: Array = _parse_insert_rows(sql_text, columns, max_rows)
	var spell_defs: Array = []
	var skipped_rows: int = 0
	var type_counts: Dictionary = {}
	var damage_type_counts: Dictionary = {}
	var sample: Array = []
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			skipped_rows += 1
			continue
		var row: Dictionary = row_value as Dictionary
		var spell: Dictionary = _row_to_spell_def_dict(row)
		if int(spell.get("id", 0)) <= 0:
			skipped_rows += 1
			continue
		spell_defs.append(spell)
		var spell_type: String = str(spell.get("spell_type", ""))
		var damage_type: String = str(spell.get("damage_type", ""))
		type_counts[spell_type] = int(type_counts.get(spell_type, 0)) + 1
		damage_type_counts[damage_type] = int(damage_type_counts.get(damage_type, 0)) + 1
		if sample.size() < int(options.get("sample_limit", 20)):
			sample.append(_compact_spell_sample(spell))
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"coordinate_frame_confirmed": false,
		"status": "parsed_spell_sql",
		"source_path": source_path,
		"columns": columns,
		"insert_column_count": columns.size(),
		"estimated_insert_row_count": _estimate_insert_row_count(sql_text),
		"rows_sample_count": rows.size(),
		"spell_def_count": spell_defs.size(),
		"skipped_rows": skipped_rows,
		"type_counts": type_counts,
		"damage_type_counts": damage_type_counts,
		"spell_defs": spell_defs,
		"sample_spells": sample,
		"notes": [
			"OpenDAoC spell.sql rows are converted to DaocSpellDef dictionaries.",
			"Only handler-supported spell types should be used for prediction; server remains authoritative.",
		],
	}

func build_text_report(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-18D OpenDAoC spell SQL -> Godot SpellBook")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(report.get("ok", false)), str(report.get("status", "")), str(report.get("checkpoint", ""))])
	lines.append("source_path=%s" % str(report.get("source_path", "")))
	lines.append("spell_defs=%d skipped=%d estimated_rows=%d" % [int(report.get("spell_def_count", 0)), int(report.get("skipped_rows", 0)), int(report.get("estimated_insert_row_count", 0))])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true")
	lines.append("type_counts=%s" % str(report.get("type_counts", {})))
	var samples: Array = report.get("sample_spells", []) as Array
	for item in samples:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var spell: Dictionary = item as Dictionary
		lines.append("- id=%d type=%s dmg=%s value=%s name=%s" % [int(spell.get("id", 0)), str(spell.get("spell_type", "")), str(spell.get("damage", 0)), str(spell.get("value", 0)), str(spell.get("name", ""))])
	return "\n".join(lines) + "\n"

func _row_to_spell_def_dict(row: Dictionary) -> Dictionary:
	var spell_id: int = _row_int(row, ["SpellID", "ID", "Id", "id", "spellid"], 0)
	var raw_type: String = _row_string(row, ["Type", "SpellType", "type"], "DirectDamage")
	var raw_damage_type: Variant = _row_value(row, ["DamageType", "damage_type", "DamageTypeId"], "Natural")
	var out: Dictionary = {
		"id": spell_id,
		"name": _row_string(row, ["Name", "name"], "Spell %d" % spell_id),
		"spell_type": _canonical_spell_type(raw_type),
		"damage_type": raw_damage_type,
		"level": _row_int(row, ["Level", "level"], 1),
		"damage": _row_float(row, ["Damage", "damage"], 0.0),
		"value": _row_float(row, ["Value", "value"], 0.0),
		"range": _row_int(row, ["Range", "range"], 0),
		"radius": _row_int(row, ["Radius", "radius"], 0),
		"cast_time": _row_int(row, ["CastTime", "casttime", "cast_time"], 0),
		"recast_delay": _row_int(row, ["RecastDelay", "Recast", "recast_delay"], 0),
		"duration": _row_int(row, ["Duration", "duration"], 0),
		"frequency": _row_int(row, ["Frequency", "frequency"], 0),
		"power": _row_int(row, ["Power", "PowerCost", "power"], 0),
		"pulse_power": _row_int(row, ["PulsePower", "pulse_power"], 0),
		"target": _row_string(row, ["Target", "target"], "ENEMY"),
		"client_effect": _row_int(row, ["ClientEffect", "ClientEffectID", "client_effect"], 0),
		"effect_group": _row_int(row, ["EffectGroup", "effect_group"], 0),
		"life_drain_return": _row_int(row, ["LifeDrainReturn", "life_drain_return"], 0),
		"spec_line": _row_string(row, ["LineName", "SpellLine", "Spec", "PackageID"], ""),
		"source_table": "opendaoc_spell.sql",
		"opendaoc_raw_type": raw_type,
		"raw": row.duplicate(true),
	}
	return out

func _canonical_spell_type(value: Variant) -> String:
	var t: String = str(value).strip_edges()
	var lower: String = t.to_lower().replace("_", "").replace(" ", "")
	match lower:
		"directdamage", "dd", "nuke": return DaocCombatEnums.SPELL_DIRECT_DAMAGE
		"damageovertime", "dot", "damagingover_time": return DaocCombatEnums.SPELL_DAMAGE_OVER_TIME
		"bolt": return DaocCombatEnums.SPELL_BOLT
		"heal", "healingspell": return DaocCombatEnums.SPELL_HEAL
		"damagespeeddecrease", "ddsnare", "snaredd": return DaocCombatEnums.SPELL_DAMAGE_SPEED_DECREASE
		"damageadd", "damageadder": return DaocCombatEnums.SPELL_DAMAGE_ADD
		"damageshield", "damageshieldspell": return DaocCombatEnums.SPELL_DAMAGE_SHIELD
		_:
			return t

func _compact_spell_sample(spell: Dictionary) -> Dictionary:
	return {
		"id": int(spell.get("id", 0)),
		"name": str(spell.get("name", "")),
		"spell_type": str(spell.get("spell_type", "")),
		"opendaoc_raw_type": str(spell.get("opendaoc_raw_type", "")),
		"damage_type": str(spell.get("damage_type", "")),
		"damage": spell.get("damage", 0),
		"value": spell.get("value", 0),
		"range": int(spell.get("range", 0)),
		"cast_time": int(spell.get("cast_time", 0)),
		"duration": int(spell.get("duration", 0)),
		"client_effect": int(spell.get("client_effect", 0)),
	}

func _row_value(row: Dictionary, keys: Array, default_value: Variant = null) -> Variant:
	for key_value in keys:
		var key: String = str(key_value)
		if row.has(key):
			return row[key]
		for existing_key in row.keys():
			if str(existing_key).to_lower() == key.to_lower():
				return row[existing_key]
	return default_value

func _row_string(row: Dictionary, keys: Array, default_value: String = "") -> String:
	return str(_row_value(row, keys, default_value))

func _row_int(row: Dictionary, keys: Array, default_value: int = 0) -> int:
	return int(_row_value(row, keys, default_value))

func _row_float(row: Dictionary, keys: Array, default_value: float = 0.0) -> float:
	return float(_row_value(row, keys, default_value))

func _resolve_directory_path(path: String) -> String:
	var candidate: String = path.strip_edges()
	if candidate == "":
		return ""
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	var globalized: String = ProjectSettings.globalize_path(candidate)
	if DirAccess.dir_exists_absolute(globalized):
		return globalized
	return ""

func _find_spell_sql_file(dir_path: String) -> String:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for wanted_value in SPELL_FILE_CANDIDATES:
		var wanted: String = str(wanted_value).to_lower()
		for file_name_value in files:
			var file_name: String = str(file_name_value)
			if file_name.to_lower() == wanted:
				return dir_path.path_join(file_name)
	return ""

func _infer_insert_columns(sql_text: String) -> Array:
	var dml_idx: int = _find_dml_start(sql_text)
	if dml_idx < 0:
		return []
	var lower: String = sql_text.to_lower()
	var values_idx: int = lower.find("values", dml_idx)
	if values_idx < 0:
		return []
	var first_paren: int = sql_text.find("(", dml_idx)
	if first_paren < 0 or first_paren > values_idx:
		return []
	var close_paren: int = _find_matching_paren(sql_text, first_paren)
	if close_paren < 0 or close_paren > values_idx:
		return []
	var chunk: String = sql_text.substr(first_paren + 1, close_paren - first_paren - 1)
	return _split_identifier_list(chunk)

func _split_identifier_list(chunk: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = chunk.split(",", false)
	for part_value in parts:
		var item: String = str(part_value).strip_edges().strip_edges(true, true).strip_edges()
		item = item.replace("`", "").replace("\"", "").strip_edges()
		if item != "":
			out.append(item)
	return out

func _find_dml_start(sql_text: String) -> int:
	var lower: String = sql_text.to_lower()
	var replace_idx: int = lower.find("replace into")
	var insert_idx: int = lower.find("insert into")
	if replace_idx < 0:
		return insert_idx
	if insert_idx < 0:
		return replace_idx
	return mini(replace_idx, insert_idx)

func _parse_insert_rows(sql_text: String, columns: Array, max_rows: int) -> Array:
	var out: Array = []
	if columns.is_empty():
		return out
	var lower: String = sql_text.to_lower()
	var dml_idx: int = _find_dml_start(sql_text)
	if dml_idx < 0:
		return out
	var values_idx: int = lower.find("values", dml_idx)
	if values_idx < 0:
		return out
	var i: int = sql_text.find("(", values_idx)
	while i >= 0 and i < sql_text.length():
		if max_rows > 0 and out.size() >= max_rows:
			break
		var end_idx: int = _find_matching_paren(sql_text, i)
		if end_idx < 0:
			break
		var tuple_text: String = sql_text.substr(i + 1, end_idx - i - 1)
		var values: Array = _split_sql_tuple(tuple_text)
		var row: Dictionary = {}
		var max_col: int = mini(columns.size(), values.size())
		for col_index in range(max_col):
			row[str(columns[col_index])] = values[col_index]
		out.append(row)
		var next_pos: int = end_idx + 1
		while next_pos < sql_text.length() and sql_text.substr(next_pos, 1).strip_edges() == "":
			next_pos += 1
		if next_pos >= sql_text.length() or sql_text.substr(next_pos, 1) != ",":
			break
		i = sql_text.find("(", next_pos)
	return out

func _find_matching_paren(text: String, open_idx: int) -> int:
	var depth: int = 0
	var in_string: bool = false
	var escape_next: bool = false
	for index in range(open_idx, text.length()):
		var ch: String = text.substr(index, 1)
		if in_string:
			if escape_next:
				escape_next = false
			elif ch == "\\":
				escape_next = true
			elif ch == "'":
				if index + 1 < text.length() and text.substr(index + 1, 1) == "'":
					escape_next = true
				else:
					in_string = false
			continue
		if ch == "'":
			in_string = true
		elif ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return index
	return -1

func _split_sql_tuple(tuple_text: String) -> Array:
	var out: Array = []
	var current: String = ""
	var in_string: bool = false
	var escape_next: bool = false
	var index: int = 0
	while index < tuple_text.length():
		var ch: String = tuple_text.substr(index, 1)
		if in_string:
			current += ch
			if escape_next:
				escape_next = false
			elif ch == "\\":
				escape_next = true
			elif ch == "'":
				if index + 1 < tuple_text.length() and tuple_text.substr(index + 1, 1) == "'":
					current += "'"
					index += 1
				else:
					in_string = false
		elif ch == "'":
			in_string = true
			current += ch
		elif ch == ",":
			out.append(_clean_sql_value(current))
			current = ""
		else:
			current += ch
		index += 1
	out.append(_clean_sql_value(current))
	return out

func _clean_sql_value(value: String) -> Variant:
	var v: String = value.strip_edges()
	if v == "" or v.to_upper() == "NULL":
		return ""
	if v.begins_with("'") and v.ends_with("'") and v.length() >= 2:
		var inner: String = v.substr(1, v.length() - 2)
		inner = inner.replace("\\'", "'").replace("''", "'").replace("\\\\", "\\")
		return inner
	if v.is_valid_int():
		return int(v)
	if v.is_valid_float():
		return float(v)
	return v

func _estimate_insert_row_count(sql_text: String) -> int:
	var lower: String = sql_text.to_lower()
	var dml_idx: int = _find_dml_start(sql_text)
	if dml_idx < 0:
		return 0
	var values_idx: int = lower.find("values", dml_idx)
	if values_idx < 0:
		return 0
	var count: int = 0
	var in_string: bool = false
	var escape_next: bool = false
	for index in range(values_idx, sql_text.length()):
		var ch: String = sql_text.substr(index, 1)
		if in_string:
			if escape_next:
				escape_next = false
			elif ch == "\\":
				escape_next = true
			elif ch == "'":
				if index + 1 < sql_text.length() and sql_text.substr(index + 1, 1) == "'":
					escape_next = true
				else:
					in_string = false
			continue
		if ch == "'":
			in_string = true
		elif ch == "(":
			count += 1
	return count

func _waiting_result(checked: Array) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"coordinate_frame_confirmed": false,
		"status": "waiting_for_local_sql_directory",
		"checked_paths": checked.duplicate(true),
		"spell_def_count": 0,
		"spell_defs": [],
	}

func _error_result(status: String, source_path: String, resolved_path: String) -> Dictionary:
	return {
		"ok": false,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"abstract_only": true,
		"runtime_enabled": false,
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"coordinate_frame_confirmed": false,
		"status": status,
		"source_path": source_path,
		"resolved_path": resolved_path,
		"spell_def_count": 0,
		"spell_defs": [],
	}
