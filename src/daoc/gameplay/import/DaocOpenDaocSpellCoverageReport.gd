extends RefCounted
class_name DaocOpenDaocSpellCoverageReport

## P1-18E — OpenDAoC spell coverage and unsupported Type backlog.
## This is an audit/report helper only. It does not execute gameplay and does not promote formulas.

const CHECKPOINT: String = "P1_18E_OPENDAOC_SPELL_COVERAGE"
const SCOPE: String = "P1-18E OpenDAoC spell coverage and unsupported Type backlog"
const DEFAULT_TOP_LIMIT: int = 50
const DEFAULT_SAMPLE_LIMIT: int = 6

func build(spell_book: DaocSpellBook, registered_handler_types: Array, options: Dictionary = {}) -> Dictionary:
	var top_limit: int = int(options.get("top_limit", DEFAULT_TOP_LIMIT))
	var sample_limit: int = int(options.get("sample_limit", DEFAULT_SAMPLE_LIMIT))
	var registered: Array = []
	for value in registered_handler_types:
		registered.append(str(value))
	var type_rows: Array = []
	var supported_rows: Array = []
	var unsupported_rows: Array = []
	var total_spells: int = 0
	var supported_spells: int = 0
	var unsupported_spells: int = 0
	if spell_book != null:
		for type_key in spell_book.spells_by_type.keys():
			var type_name: String = str(type_key)
			var spells: Array = spell_book.spells_by_type.get(type_key, []) as Array
			var count: int = spells.size()
			total_spells += count
			var supported: bool = type_name in registered
			if supported:
				supported_spells += count
			else:
				unsupported_spells += count
			var row: Dictionary = _build_type_row(type_name, spells, supported, sample_limit)
			type_rows.append(row)
			if supported:
				supported_rows.append(row)
			else:
				unsupported_rows.append(row)
	_sort_rows_by_count_desc(type_rows)
	_sort_rows_by_count_desc(supported_rows)
	_sort_rows_by_count_desc(unsupported_rows)
	var top_unsupported: Array = _limit_rows(unsupported_rows, top_limit)
	return {
		"checkpoint": CHECKPOINT,
		"scope": SCOPE,
		"ok": spell_book != null and total_spells > 0,
		"status": "coverage_built" if spell_book != null and total_spells > 0 else "empty_spellbook",
		"guardrails": DaocGameplayAuthority.guardrails(),
		"registered_handler_types": registered,
		"total_spell_count": total_spells,
		"supported_spell_count": supported_spells,
		"unsupported_spell_count": unsupported_spells,
		"supported_ratio": float(supported_spells) / float(maxi(total_spells, 1)),
		"unsupported_ratio": float(unsupported_spells) / float(maxi(total_spells, 1)),
		"type_count": type_rows.size(),
		"supported_type_count": supported_rows.size(),
		"unsupported_type_count": unsupported_rows.size(),
		"type_rows": type_rows,
		"supported_rows": supported_rows,
		"unsupported_rows": unsupported_rows,
		"top_unsupported_types": top_unsupported,
		"handler_backlog": _build_handler_backlog(unsupported_rows),
		"recommended_next_handlers": _recommend_next_handlers(unsupported_rows),
		"prediction_only": true,
		"damage_final": false,
		"runtime_enabled": false,
		"server_authority": true,
		"notes": [
			"Every OpenDAoC spell Type is counted before adding more fake handlers.",
			"Unsupported Types are backlog items, not routed through DirectDamage by default.",
			"Prioritize live OpenDAoC comparison for damage, heal, CC, buff and pet handlers.",
		],
	}

func build_text_report(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-18E OpenDAoC spell coverage and unsupported Type backlog")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(report.get("ok", false)), str(report.get("status", "")), str(report.get("checkpoint", ""))])
	lines.append("total=%d supported=%d unsupported=%d types=%d unsupported_types=%d" % [int(report.get("total_spell_count", 0)), int(report.get("supported_spell_count", 0)), int(report.get("unsupported_spell_count", 0)), int(report.get("type_count", 0)), int(report.get("unsupported_type_count", 0))])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true")
	lines.append("registered_handlers=%s" % str(report.get("registered_handler_types", [])))
	lines.append("")
	lines.append("Top unsupported OpenDAoC spell Types:")
	var rows: Array = report.get("top_unsupported_types", []) as Array
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		lines.append("- type=%s count=%d priority=%s proposed=%s samples=%s" % [str(row.get("spell_type", "")), int(row.get("count", 0)), str(row.get("priority", "")), str(row.get("proposed_handler", "")), str(row.get("sample_spell_ids", []))])
	lines.append("")
	lines.append("Recommended next handlers:")
	var backlog: Array = report.get("recommended_next_handlers", []) as Array
	for item in backlog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item as Dictionary
		lines.append("- %s priority=%s spell_count=%d types=%s" % [str(rec.get("handler", "")), str(rec.get("priority", "")), int(rec.get("spell_count", 0)), str(rec.get("types", []))])
	lines.append("Next: implement highest-priority handlers one by one, still prediction_only, then compare to live OpenDAoC logs.")
	return "\n".join(lines) + "\n"

func _build_type_row(type_name: String, spells: Array, supported: bool, sample_limit: int) -> Dictionary:
	var samples: Array = []
	var ids: Array = []
	var damage_like_count: int = 0
	var heal_like_count: int = 0
	for item in spells:
		var spell: DaocSpellDef = item as DaocSpellDef
		if spell == null:
			continue
		if float(spell.damage) != 0.0:
			damage_like_count += 1
		if _looks_like_heal(spell):
			heal_like_count += 1
		if samples.size() < sample_limit:
			samples.append(_sample_spell(spell))
			ids.append(spell.id)
	var proposed: Dictionary = _propose_handler(type_name, spells)
	return {
		"spell_type": type_name,
		"count": spells.size(),
		"supported": supported,
		"damage_like_count": damage_like_count,
		"heal_like_count": heal_like_count,
		"sample_spell_ids": ids,
		"sample_spells": samples,
		"priority": str(proposed.get("priority", "P3")) if not supported else "implemented",
		"proposed_handler": str(proposed.get("handler", "already_implemented")) if not supported else "implemented",
		"rationale": str(proposed.get("rationale", "")) if not supported else "Registered handler exists.",
	}

func _sample_spell(spell: DaocSpellDef) -> Dictionary:
	return {
		"id": spell.id,
		"name": spell.name,
		"spell_type": spell.spell_type,
		"damage_type": spell.damage_type,
		"level": spell.level,
		"damage": spell.damage,
		"value": spell.value,
		"range": spell.range,
		"cast_time": spell.cast_time,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"target": spell.target,
		"client_effect": spell.client_effect,
		"effect_group": spell.effect_group,
	}

func _looks_like_heal(spell: DaocSpellDef) -> bool:
	var text: String = (spell.spell_type + " " + spell.name + " " + spell.target).to_lower()
	return text.contains("heal") or text.contains("health") or text.contains("resurrect") or text.contains("rez")

func _propose_handler(type_name: String, spells: Array) -> Dictionary:
	var lower: String = type_name.to_lower().replace("_", "").replace(" ", "")
	var names: String = _sample_names_joined(spells, 6)
	var all_text: String = lower + " " + names.to_lower()
	if all_text.contains("lifedrain") or all_text.contains("drain"):
		return {"handler": "DaocLifeDrainSpellHandler", "priority": "P0", "rationale": "Damage + heal return; important for combat parity."}
	if all_text.contains("directdamage") or lower == "dd" or all_text.contains("nuke"):
		return {"handler": "DaocDirectDamageSpellHandler_alias", "priority": "P0", "rationale": "Damage family probably alias/mapping issue."}
	if all_text.contains("heal") or all_text.contains("resurrect") or all_text.contains("rez"):
		return {"handler": "DaocHealOrResurrectSpellHandler", "priority": "P0", "rationale": "Core group/PvE support."}
	if all_text.contains("mez") or all_text.contains("mesmer") or all_text.contains("stun") or all_text.contains("root") or all_text.contains("snare") or all_text.contains("speeddecrease"):
		return {"handler": "DaocCrowdControlSpellHandler", "priority": "P0", "rationale": "Core DAoC combat feel: mez/root/stun/snare."}
	if all_text.contains("buff") or all_text.contains("enhance") or all_text.contains("stat") or all_text.contains("speed") or all_text.contains("haste") or all_text.contains("armor") or all_text.contains("absorb") or all_text.contains("resist"):
		return {"handler": "DaocBuffDebuffSpellHandler", "priority": "P1", "rationale": "Persistent stat/resist/speed/armor effects."}
	if all_text.contains("debuff") or all_text.contains("weaken"):
		return {"handler": "DaocBuffDebuffSpellHandler", "priority": "P1", "rationale": "Persistent negative stat/resist effects."}
	if all_text.contains("pet") or all_text.contains("summon") or all_text.contains("minion") or all_text.contains("charm"):
		return {"handler": "DaocPetSpellHandler", "priority": "P1", "rationale": "Pet/summon/charm requires entity replication later."}
	if all_text.contains("dot") or all_text.contains("poison") or all_text.contains("bleed") or all_text.contains("disease"):
		return {"handler": "DaocDoTOrDiseaseSpellHandler", "priority": "P1", "rationale": "Periodic damage/disease family."}
	if all_text.contains("bolt"):
		return {"handler": "DaocBoltSpellHandler_alias", "priority": "P1", "rationale": "Bolt family probably alias/mapping issue."}
	if all_text.contains("shield") or all_text.contains("bladeturn") or all_text.contains("absorb"):
		return {"handler": "DaocDefensiveReactiveSpellHandler", "priority": "P2", "rationale": "Reactive/defensive mitigation handler."}
	if _type_has_damage(spells):
		return {"handler": "DaocGenericDamageEffectHandler", "priority": "P1", "rationale": "Rows have non-zero Damage but unknown Type."}
	return {"handler": "DaocGenericEffectHandler", "priority": "P3", "rationale": "Needs source audit before execution."}

func _sample_names_joined(spells: Array, limit: int) -> String:
	var names: Array = []
	for item in spells:
		var spell: DaocSpellDef = item as DaocSpellDef
		if spell == null:
			continue
		names.append(spell.name)
		if names.size() >= limit:
			break
	return " ".join(names)

func _type_has_damage(spells: Array) -> bool:
	for item in spells:
		var spell: DaocSpellDef = item as DaocSpellDef
		if spell != null and float(spell.damage) != 0.0:
			return true
	return false

func _build_handler_backlog(unsupported_rows: Array) -> Array:
	var groups: Dictionary = {}
	for item in unsupported_rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		var handler: String = str(row.get("proposed_handler", "DaocGenericEffectHandler"))
		if not groups.has(handler):
			groups[handler] = {"handler": handler, "priority": str(row.get("priority", "P3")), "spell_count": 0, "types": [], "sample_spell_ids": []}
		var group: Dictionary = groups[handler] as Dictionary
		group["spell_count"] = int(group.get("spell_count", 0)) + int(row.get("count", 0))
		var types: Array = group.get("types", []) as Array
		types.append(str(row.get("spell_type", "")))
		group["types"] = types
		var ids: Array = group.get("sample_spell_ids", []) as Array
		var row_sample_ids: Array = row.get("sample_spell_ids", []) as Array
		for id_value in row_sample_ids:
			if ids.size() < 12:
				ids.append(id_value)
		group["sample_spell_ids"] = ids
	var out: Array = []
	for key in groups.keys():
		out.append(groups[key])
	_sort_rows_by_count_desc(out, "spell_count")
	return out

func _recommend_next_handlers(unsupported_rows: Array) -> Array:
	var backlog: Array = _build_handler_backlog(unsupported_rows)
	var p0: Array = []
	var p1: Array = []
	var other: Array = []
	for item in backlog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		var priority: String = str(row.get("priority", "P3"))
		if priority == "P0":
			p0.append(row)
		elif priority == "P1":
			p1.append(row)
		else:
			other.append(row)
	var out: Array = []
	for arr in [p0, p1, other]:
		for item in arr:
			out.append(item)
			if out.size() >= 12:
				return out
	return out

func _limit_rows(rows: Array, limit: int) -> Array:
	var out: Array = []
	for item in rows:
		out.append(item)
		if limit > 0 and out.size() >= limit:
			break
	return out

func _sort_rows_by_count_desc(rows: Array, count_key: String = "count") -> void:
	var n: int = rows.size()
	for i in range(n):
		var best: int = i
		for j in range(i + 1, n):
			var a: Dictionary = rows[best] as Dictionary
			var b: Dictionary = rows[j] as Dictionary
			if int(b.get(count_key, 0)) > int(a.get(count_key, 0)):
				best = j
		if best != i:
			var tmp: Variant = rows[i]
			rows[i] = rows[best]
			rows[best] = tmp
