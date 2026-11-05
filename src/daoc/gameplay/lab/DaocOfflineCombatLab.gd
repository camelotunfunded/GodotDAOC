extends RefCounted
class_name DaocOfflineCombatLab

const DaocOpenDaocSpellSqlLoaderScript = preload("res://src/daoc/gameplay/import/DaocOpenDaocSpellSqlLoader.gd")
const DaocOpenDaocSpellCoverageReportScript = preload("res://src/daoc/gameplay/import/DaocOpenDaocSpellCoverageReport.gd")
const DaocEffectStateScript = preload("res://src/daoc/gameplay/effects/DaocEffectState.gd")

const DEFAULT_SPELL_FIXTURE_PATH: String = "res://data/gameplay/opendaoc_spell_fixture_p1_18b.json"
const REPORT_JSON_PATH: String = "res://reports/p1_18b_offline_combat_lab.json"
const REPORT_TEXT_PATH: String = "res://reports/p1_18b_offline_combat_lab.txt"
const DETAILED_REPORT_JSON_PATH: String = "res://reports/p1_18c_combat_lab.json"
const DETAILED_REPORT_TEXT_PATH: String = "res://reports/p1_18c_combat_lab.txt"
const OPENDAOC_SPELLBOOK_JSON_PATH: String = "res://reports/p1_18d_opendaoc_spellbook.json"
const OPENDAOC_SPELLBOOK_TEXT_PATH: String = "res://reports/p1_18d_opendaoc_spellbook.txt"
const OPENDAOC_COVERAGE_JSON_PATH: String = "res://reports/p1_18e_opendaoc_spell_coverage.json"
const OPENDAOC_COVERAGE_TEXT_PATH: String = "res://reports/p1_18e_opendaoc_spell_coverage.txt"
const OPENDAOC_P0_HANDLERS_JSON_PATH: String = "res://reports/p1_18f_opendaoc_p0_handlers.json"
const OPENDAOC_P0_HANDLERS_TEXT_PATH: String = "res://reports/p1_18f_opendaoc_p0_handlers.txt"
const OPENDAOC_BUFF_DEBUFF_JSON_PATH: String = "res://reports/p1_18g_buff_debuff_state.json"
const OPENDAOC_BUFF_DEBUFF_TEXT_PATH: String = "res://reports/p1_18g_buff_debuff_state.txt"
const OPENDAOC_DOT_DISEASE_PROC_JSON_PATH: String = "res://reports/p1_18h_dot_disease_proc_state.json"
const OPENDAOC_DOT_DISEASE_PROC_TEXT_PATH: String = "res://reports/p1_18h_dot_disease_proc_state.txt"
const OPENDAOC_GENERIC_DAMAGE_JSON_PATH: String = "res://reports/p1_18i_generic_damage_effects.json"
const OPENDAOC_GENERIC_DAMAGE_TEXT_PATH: String = "res://reports/p1_18i_generic_damage_effects.txt"
const OPENDAOC_PET_INTENT_JSON_PATH: String = "res://reports/p1_18j_pet_summon_intent.json"
const OPENDAOC_PET_INTENT_TEXT_PATH: String = "res://reports/p1_18j_pet_summon_intent.txt"
const OPENDAOC_K25_JSON_PATH: String = "res://reports/p1_18k_2_5_lab_runtime.json"
const OPENDAOC_K25_TEXT_PATH: String = "res://reports/p1_18k_2_5_lab_runtime.txt"

var spell_book: DaocSpellBook = DaocSpellBook.new()
var registry: DaocGameplayMechanicsRegistry = DaocGameplayMechanicsRegistry.new()
var last_report: Dictionary = {}
var last_detailed_report: Dictionary = {}
var last_opendaoc_spellbook_report: Dictionary = {}
var last_opendaoc_coverage_report: Dictionary = {}
var last_opendaoc_p0_report: Dictionary = {}
var last_buff_debuff_state_report: Dictionary = {}
var last_dot_disease_proc_report: Dictionary = {}
var last_generic_damage_effect_report: Dictionary = {}
var last_pet_intent_report: Dictionary = {}
var last_k25_lab_runtime_report: Dictionary = {}
var active_effect_state: RefCounted = DaocEffectStateScript.new()


func load_default_fixtures() -> Dictionary:
	return spell_book.load_from_json_file(DEFAULT_SPELL_FIXTURE_PATH)


func build_default_actor_pair() -> Dictionary:
	var caster: DaocCombatEntityState = DaocCombatEntityState.from_dict({
		"id": 1,
		"name": "Offline Caster",
		"level": 50,
		"max_health": 1600,
		"health": 1600,
		"mana": 1000,
		"is_player": true,
		"stats": {"Dexterity": 250, "Intelligence": 250, "Strength": 120, "Quickness": 180},
		"properties": {"CriticalSpellHitChance": 10, "DebuffCriticalChance": 10, "CriticalHealHitChance": 10, "HealingEffectiveness": 0, "MeleeSpeed": 100, "CriticalMeleeHitChance": 5},
		"spec_levels": {"Fire": 50, "Body": 44, "Rejuvenation": 40, "Enhancement": 40},
	})
	var target: DaocCombatEntityState = DaocCombatEntityState.from_dict({
		"id": 2,
		"name": "Training Dummy",
		"level": 50,
		"max_health": 2200,
		"health": 2200,
		"is_player": false,
		"resists": {"Heat": 26, "Body": 18, "Matter": 10, "Cold": 5},
		"properties": {"ArmorFactor": 250, "Quickness": 60},
		"in_combat": true,
		"attacker_melee_count": 1,
	})
	return {"caster": caster, "target": target}


func dummy_snapshot() -> Dictionary:
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
	return {
		"checkpoint": "P1_18C_COMBAT_LAB_DUMMY",
		"ok": caster != null and target != null,
		"caster": caster.to_dict() if caster != null else {},
		"target": target.to_dict() if target != null else {},
		"guardrails": DaocGameplayAuthority.guardrails(),
	}


func run_spell_suite(options: Dictionary = {}) -> Dictionary:
	if spell_book.spells_by_id.is_empty():
		load_default_fixtures()
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
	var results: Array = []
	var spell_types: Array = [
		DaocCombatEnums.SPELL_DIRECT_DAMAGE,
		DaocCombatEnums.SPELL_DAMAGE_OVER_TIME,
		DaocCombatEnums.SPELL_BOLT,
		DaocCombatEnums.SPELL_HEAL,
		DaocCombatEnums.SPELL_DAMAGE_SPEED_DECREASE,
	]
	for spell_type in spell_types:
		var spell: DaocSpellDef = spell_book.first_by_type(str(spell_type))
		if spell == null:
			results.append({"ok": false, "mechanism": spell_type, "reason": "missing fixture"})
			continue
		var handler: DaocSpellHandler = registry.create_handler(spell)
		if handler == null:
			results.append({"ok": false, "mechanism": spell_type, "reason": "missing handler"})
			continue
		var target_for_spell: DaocCombatEntityState = caster if spell.spell_type == DaocCombatEnums.SPELL_HEAL else target
		results.append(handler.execute(caster, target_for_spell, {"seed": int(options.get("seed", 42)), "distance": 900}))
	var melee: Dictionary = run_melee_suite(options)
	last_report = {
		"checkpoint": "P1_18B_OFFLINE_COMBAT_LAB",
		"scope": "P1-18B offline combat/spell mechanics lab",
		"ok": true,
		"guardrails": DaocGameplayAuthority.guardrails(),
		"spellbook": spell_book.snapshot(),
		"registry": registry.snapshot(),
		"spell_results": results,
		"melee": melee,
		"notes": [
			"Prediction-only scaffolding. Not server authoritative.",
			"Validate against a running OpenDAoC server before using as final gameplay.",
		],
	}
	return last_report.duplicate(true)


func run_detailed_suite(options: Dictionary = {}) -> Dictionary:
	if spell_book.spells_by_id.is_empty():
		load_default_fixtures()
	var seed_value: int = int(options.get("seed", 42))
	var verbose: bool = bool(options.get("verbose", false))
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
	var entries: Array = []
	var ordered_types: Array = [
		DaocCombatEnums.SPELL_DIRECT_DAMAGE,
		DaocCombatEnums.SPELL_DAMAGE_OVER_TIME,
		DaocCombatEnums.SPELL_BOLT,
		DaocCombatEnums.SPELL_HEAL,
		DaocCombatEnums.SPELL_DAMAGE_SPEED_DECREASE,
	]
	for spell_type in ordered_types:
		var spell: DaocSpellDef = spell_book.first_by_type(str(spell_type))
		var target_for_spell: DaocCombatEntityState = caster if spell != null and _is_friendly_or_self_spell_type(spell.spell_type) else target
		entries.append(_run_spell_detail(spell, caster, target_for_spell, {"seed": seed_value, "distance": int(options.get("distance", 900)), "verbose": verbose}))
	var reactive_entries: Array = _run_reactive_effect_details(caster, target, {"seed": seed_value, "verbose": verbose})
	for reactive_entry in reactive_entries:
		entries.append(reactive_entry)
	var melee: Dictionary = run_melee_suite({"seed": seed_value, "left_hand_swing_chance": 1.0})
	var totals: Dictionary = _summarize_detailed_entries(entries, melee)
	last_detailed_report = {
		"checkpoint": "P1_18C_COMBAT_LAB_DETAILED_REPORT",
		"scope": "P1-18C combat lab detailed prediction report",
		"ok": true,
		"guardrails": DaocGameplayAuthority.guardrails(),
		"report_paths": {"json": DETAILED_REPORT_JSON_PATH, "txt": DETAILED_REPORT_TEXT_PATH},
		"spellbook": spell_book.snapshot(),
		"registry": registry.snapshot(),
		"dummy": dummy_snapshot(),
		"entries": entries,
		"melee": melee,
		"summary": totals,
		"notes": [
			"Detailed numbers are prediction-only and designed for comparison against a live OpenDAoC server.",
			"No gameplay authority is granted to this lab; server_authority=true and damage_final=false remain mandatory.",
		],
	}
	return last_detailed_report.duplicate(true)


func cast_spell_by_id(spell_id: int, options: Dictionary = {}) -> Dictionary:
	if spell_book.spells_by_id.is_empty():
		load_default_fixtures()
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
	var spell: DaocSpellDef = spell_book.get_spell(spell_id)
	var target_for_spell: DaocCombatEntityState = caster if spell != null and _is_friendly_or_self_spell_type(spell.spell_type) else target
	var detail: Dictionary = _run_spell_detail(spell, caster, target_for_spell, {"seed": int(options.get("seed", 42)), "distance": int(options.get("distance", 900)), "verbose": bool(options.get("verbose", true))})
	return {
		"checkpoint": "P1_18C_COMBAT_LAB_CAST",
		"ok": bool(detail.get("ok", false)),
		"spell_id": spell_id,
		"detail": detail,
		"guardrails": DaocGameplayAuthority.guardrails(),
	}


func run_melee_suite(options: Dictionary = {}) -> Dictionary:
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
	var style: DaocStyleDef = DaocStyleDef.from_dict({"id": 1001, "name": "Prediction Slash", "growth_rate": 0.55, "bonus_to_hit": 10, "animation_id": 11, "endurance_cost": 5})
	var weapon: Dictionary = {"name": "Test Sword", "damage_type": "Slash", "DPS_AF": 16.5, "SPD_ABS": 32, "object_type": "Sword"}
	var left: Dictionary = {"name": "Test Offhand", "damage_type": "Slash", "DPS_AF": 15.0, "SPD_ABS": 28, "object_type": "Sword"}
	var action: DaocWeaponAction = DaocWeaponAction.new().setup_melee(caster, target, weapon, left, style, 0)
	return action.execute({"seed": int(options.get("seed", 42)), "left_hand_swing_chance": float(options.get("left_hand_swing_chance", 1.0))})


func export_last_report_json(path: String = REPORT_JSON_PATH) -> Dictionary:
	if last_report.is_empty():
		run_spell_suite()
	return _write_text(path, JSON.stringify(last_report, "\t"))


func export_last_report_text(path: String = REPORT_TEXT_PATH) -> Dictionary:
	if last_report.is_empty():
		run_spell_suite()
	return _write_text(path, build_text_report(last_report))


func export_detailed_report_json(path: String = DETAILED_REPORT_JSON_PATH) -> Dictionary:
	if last_detailed_report.is_empty():
		run_detailed_suite({"seed": 42, "verbose": true})
	return _write_text(path, JSON.stringify(last_detailed_report, "\t"))


func export_detailed_report_text(path: String = DETAILED_REPORT_TEXT_PATH) -> Dictionary:
	if last_detailed_report.is_empty():
		run_detailed_suite({"seed": 42, "verbose": true})
	return _write_text(path, build_detailed_text_report(last_detailed_report))


func build_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_report
	var lines: Array = []
	lines.append("P1-18B offline combat lab")
	lines.append("ok=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("checkpoint", ""))])
	var sb: Dictionary = r.get("spellbook", {}) as Dictionary
	lines.append("spell_count=%d type_counts=%s" % [int(sb.get("spell_count", 0)), str(sb.get("type_counts", {}))])
	var spell_results: Array = r.get("spell_results", []) as Array
	for item in spell_results:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item as Dictionary
		var ad: Dictionary = d.get("attack_data", {}) as Dictionary
		var effects: Array = d.get("effects", []) as Array
		lines.append("- %s ok=%s damage=%d crit=%d effects=%d" % [str(d.get("mechanism", "")), str(d.get("ok", false)), int(ad.get("damage", 0)), int(ad.get("critical_damage", 0)), effects.size()])
	var melee: Dictionary = r.get("melee", {}) as Dictionary
	lines.append("melee attack_count=%d" % int(melee.get("attack_count", 0)))
	lines.append("authority=server prediction_only=true damage_final=false")
	return "\n".join(lines) + "\n"


func build_detailed_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_detailed_report
	var lines: Array = []
	lines.append("P1-18C combat lab detailed report")
	lines.append("ok=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("checkpoint", ""))])
	var guard: Dictionary = r.get("guardrails", {}) as Dictionary
	lines.append("server_authority=%s prediction_only=%s damage_final=%s runtime_enabled=%s" % [str(guard.get("server_authority", false)), str(guard.get("prediction_only", false)), str(guard.get("damage_final", true)), str(guard.get("runtime_enabled", true))])
	var summary: Dictionary = r.get("summary", {}) as Dictionary
	lines.append("entries=%d ok=%d total_predicted_damage=%d total_predicted_heal=%d max_abs_hp_delta=%d" % [int(summary.get("entry_count", 0)), int(summary.get("ok_count", 0)), int(summary.get("total_predicted_damage", 0)), int(summary.get("total_predicted_heal", 0)), int(summary.get("max_abs_hp_delta", 0))])
	var entries: Array = r.get("entries", []) as Array
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item as Dictionary
		var dmg: Dictionary = entry.get("damage_summary", {}) as Dictionary
		lines.append("- spell_id=%s %-22s hp %d -> %d delta=%+d base=%.1f final=%d crit=%d resist_mod=%d result=%s" % [
			str(entry.get("spell_id", "")),
			str(entry.get("mechanism", "")),
			int(entry.get("target_hp_before", 0)),
			int(entry.get("target_hp_after_predicted", 0)),
			int(entry.get("hp_delta_predicted", 0)),
			float(dmg.get("base_damage", 0.0)),
			int(dmg.get("damage", 0)),
			int(dmg.get("critical_damage", 0)),
			int(dmg.get("resist_modifier", 0)),
			str(dmg.get("attack_result", "")),
		])
	var melee: Dictionary = r.get("melee", {}) as Dictionary
	lines.append("melee attack_count=%d" % int(melee.get("attack_count", 0)))
	lines.append("Next: compare these prediction-only values with live OpenDAoC logs before promoting any formula.")
	return "\n".join(lines) + "\n"


func _run_spell_detail(spell: DaocSpellDef, caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	if spell == null:
		return {"ok": false, "mechanism": "missing_spell", "reason": "missing fixture", "guardrails": DaocGameplayAuthority.result_guard()}
	var handler: DaocSpellHandler = registry.create_handler(spell)
	if handler == null:
		return {"ok": false, "spell_id": spell.id, "mechanism": spell.spell_type, "reason": "missing handler", "guardrails": DaocGameplayAuthority.result_guard()}
	var hp_before: int = target.health if target != null else 0
	var raw_result: Dictionary = handler.execute(caster, target, options)
	var detail: Dictionary = _detail_from_result(spell, target, hp_before, raw_result, options)
	return detail


func _run_reactive_effect_details(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Array:
	var entries: Array = []
	var source_attack: DaocAttackData = DaocAttackData.new()
	source_attack.attacker = caster
	source_attack.target = target
	source_attack.attack_type = DaocCombatEnums.ATTACK_MELEE_ONE_HAND
	source_attack.attack_result = DaocCombatEnums.RESULT_HIT_UNSTYLED
	source_attack.damage_type = DaocCombatEnums.DAMAGE_SLASH
	source_attack.damage = 120
	source_attack.base_damage = 120.0
	source_attack.base_damage_cap = 350.0
	source_attack.interval = 3200
	var reactive_types: Array = [DaocCombatEnums.SPELL_DAMAGE_ADD, DaocCombatEnums.SPELL_DAMAGE_SHIELD]
	for spell_type in reactive_types:
		var spell: DaocSpellDef = spell_book.first_by_type(str(spell_type))
		if spell == null:
			entries.append({"ok": false, "mechanism": spell_type, "reason": "missing fixture", "guardrails": DaocGameplayAuthority.result_guard()})
			continue
		var handler: DaocSpellHandler = registry.create_handler(spell)
		if handler == null or not handler.has_method("execute_from_attack"):
			entries.append({"ok": false, "spell_id": spell.id, "mechanism": spell.spell_type, "reason": "missing reactive handler", "guardrails": DaocGameplayAuthority.result_guard()})
			continue
		var hp_before: int = target.health if target != null else 0
		var raw_result: Dictionary = handler.call("execute_from_attack", source_attack, 1.0, options) as Dictionary
		entries.append(_detail_from_result(spell, target, hp_before, raw_result, options))
	return entries


func _detail_from_result(spell: DaocSpellDef, target: DaocCombatEntityState, hp_before: int, raw_result: Dictionary, options: Dictionary = {}) -> Dictionary:
	var damage_summary: Dictionary = _extract_damage_summary(raw_result)
	var hp_delta: int = _estimate_hp_delta(raw_result, damage_summary)
	var hp_after: int = hp_before + hp_delta
	if target != null:
		hp_after = clampi(hp_after, 0, target.max_health)
	var effects: Array = raw_result.get("effects", []) as Array
	var messages: Array = raw_result.get("messages", []) as Array
	var entry: Dictionary = {
		"ok": bool(raw_result.get("ok", false)),
		"mechanism": str(raw_result.get("mechanism", spell.spell_type)),
		"spell_id": spell.id,
		"spell_name": spell.name,
		"spell_type": spell.spell_type,
		"damage_type": spell.damage_type,
		"source_table": spell.source_table,
		"target": target.name if target != null else "",
		"target_hp_before": hp_before,
		"target_hp_after_predicted": hp_after,
		"hp_delta_predicted": hp_after - hp_before,
		"damage_summary": damage_summary,
		"effects": effects.duplicate(true),
		"messages": messages.duplicate(true),
		"raw_result": raw_result.duplicate(true) if bool(options.get("verbose", false)) else {},
		"guardrails": DaocGameplayAuthority.result_guard(),
	}
	return entry


func _extract_damage_summary(result: Dictionary) -> Dictionary:
	var ad: Dictionary = result.get("attack_data", {}) as Dictionary
	var summary: Dictionary = {
		"has_attack_data": not ad.is_empty(),
		"base_damage": float(ad.get("base_damage", 0.0)),
		"base_damage_cap": float(ad.get("base_damage_cap", 0.0)),
		"damage": int(ad.get("damage", 0)),
		"critical_damage": int(ad.get("critical_damage", 0)),
		"total_damage": int(ad.get("damage", 0)) + int(ad.get("critical_damage", 0)),
		"critical_chance": int(ad.get("critical_chance", 0)),
		"resist_modifier": int(ad.get("modifier", 0)),
		"damage_type": str(ad.get("damage_type", "")),
		"attack_result": str(ad.get("attack_result", "")),
		"variance": 0.0,
		"variance_min": 0.0,
		"variance_max": 0.0,
	}
	var notes: Array = ad.get("notes", []) as Array
	for note_item in notes:
		if typeof(note_item) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = note_item as Dictionary
		if note.has("variance"):
			summary["variance"] = float(note.get("variance", 0.0))
		var bounds: Dictionary = note.get("variance_bounds", {}) as Dictionary
		if not bounds.is_empty():
			summary["variance_min"] = float(bounds.get("min", 0.0))
			summary["variance_max"] = float(bounds.get("max", 0.0))
	return summary


func _estimate_hp_delta(result: Dictionary, damage_summary: Dictionary) -> int:
	var mechanism: String = str(result.get("mechanism", ""))
	var effects: Array = result.get("effects", []) as Array
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		var effect_type: String = str(effect.get("effect_type", ""))
		if effect_type == "heal":
			return int(effect.get("effective_amount", effect.get("amount", 0)))
		if effect_type == "heal_over_time":
			return int(effect.get("effective_amount", effect.get("total_predicted_heal", 0)))
		if effect_type == "dot":
			return -int(effect.get("total_predicted_damage", 0))
	# Lifedrain target HP still changes by damage only; the returned heal is on caster.
	if mechanism == "Heal" or mechanism == "CombatHeal" or mechanism == "SpreadHeal":
		return 0
	return -int(damage_summary.get("total_damage", 0))


func _summarize_detailed_entries(entries: Array, melee: Dictionary) -> Dictionary:
	var ok_count: int = 0
	var total_damage: int = 0
	var total_heal: int = 0
	var max_abs_delta: int = 0
	var by_mechanism: Dictionary = {}
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item as Dictionary
		if bool(entry.get("ok", false)):
			ok_count += 1
		var mechanism: String = str(entry.get("mechanism", ""))
		by_mechanism[mechanism] = int(by_mechanism.get(mechanism, 0)) + 1
		var delta: int = int(entry.get("hp_delta_predicted", 0))
		if delta < 0:
			total_damage += -delta
		else:
			total_heal += delta
		max_abs_delta = maxi(max_abs_delta, absi(delta))
	return {
		"entry_count": entries.size(),
		"ok_count": ok_count,
		"failed_count": entries.size() - ok_count,
		"total_predicted_damage": total_damage,
		"total_predicted_heal": total_heal,
		"max_abs_hp_delta": max_abs_delta,
		"by_mechanism": by_mechanism,
		"melee_attack_count": int(melee.get("attack_count", 0)),
	}



func load_opendaoc_spellbook_from_candidates(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var loader: RefCounted = DaocOpenDaocSpellSqlLoaderScript.new()
	var opts: Dictionary = options.duplicate(true)
	if not opts.has("max_rows"):
		opts["max_rows"] = 8192
	var loaded: Dictionary = loader.call("load_spell_defs_from_candidates", candidate_dirs, opts) as Dictionary
	return _accept_opendaoc_spell_load_report(loaded, opts)

func load_opendaoc_spellbook_from_directory(directory_path: String, options: Dictionary = {}) -> Dictionary:
	var loader: RefCounted = DaocOpenDaocSpellSqlLoaderScript.new()
	var opts: Dictionary = options.duplicate(true)
	if not opts.has("max_rows"):
		opts["max_rows"] = 8192
	var loaded: Dictionary = loader.call("load_spell_defs_from_directory", directory_path, opts) as Dictionary
	return _accept_opendaoc_spell_load_report(loaded, opts)

func _accept_opendaoc_spell_load_report(loaded: Dictionary, options: Dictionary = {}) -> Dictionary:
	var defs: Array = loaded.get("spell_defs", []) as Array
	if bool(loaded.get("ok", false)) and defs.size() > 0:
		spell_book.load_from_array_reset(defs)
	var supported_types: Array = _registered_spell_types()
	var book_snap: Dictionary = spell_book.snapshot()
	var supported_count: int = 0
	var unsupported_count: int = 0
	var first_supported_spell_id: int = 0
	var supported_type_counts: Dictionary = {}
	var unsupported_type_counts: Dictionary = {}
	var type_counts: Dictionary = book_snap.get("type_counts", {}) as Dictionary
	for type_key in type_counts.keys():
		var type_name: String = str(type_key)
		var count: int = int(type_counts[type_key])
		if type_name in supported_types:
			supported_count += count
			supported_type_counts[type_name] = count
			if first_supported_spell_id == 0:
				var ids: Array = spell_book.ids_by_type(type_name, 1)
				if ids.size() > 0:
					first_supported_spell_id = int(ids[0])
		else:
			unsupported_count += count
			unsupported_type_counts[type_name] = count
	var sample_supported_ids: Dictionary = {}
	for supported_type in supported_types:
		sample_supported_ids[str(supported_type)] = spell_book.ids_by_type(str(supported_type), 8)
	last_opendaoc_spellbook_report = {
		"checkpoint": "P1_18D_OPENDAOC_SPELLBOOK_TO_COMBAT_LAB",
		"scope": "P1-18D OpenDAoC spell SQL -> Godot SpellBook",
		"ok": bool(loaded.get("ok", false)) and int(book_snap.get("spell_count", 0)) > 0,
		"status": str(loaded.get("status", "")),
		"source_path": str(loaded.get("source_path", "")),
		"checked_paths": loaded.get("checked_paths", []),
		"guardrails": DaocGameplayAuthority.guardrails(),
		"loader": _strip_heavy_spell_defs(loaded),
		"spellbook": book_snap,
		"registered_handler_types": supported_types,
		"supported_spell_count": supported_count,
		"unsupported_spell_count": unsupported_count,
		"supported_type_counts": supported_type_counts,
		"unsupported_type_counts": unsupported_type_counts,
		"first_supported_spell_id": first_supported_spell_id,
		"sample_supported_ids": sample_supported_ids,
		"prediction_only": true,
		"damage_final": false,
		"runtime_enabled": false,
		"server_authority": true,
		"notes": [
			"OpenDAoC spell.sql is now feeding the offline SpellBook.",
			"Unsupported spell types are catalogued, not forced through fake formulas.",
			"Live OpenDAoC comparison is still required before promoting formulas.",
		],
	}
	return last_opendaoc_spellbook_report.duplicate(true)

func run_opendaoc_spellbook_detailed_suite(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var load_report: Dictionary = load_opendaoc_spellbook_from_candidates(candidate_dirs, options)
	if not bool(load_report.get("ok", false)):
		return load_report
	var suite_options: Dictionary = {"seed": int(options.get("seed", 42)), "verbose": bool(options.get("verbose", false)), "distance": int(options.get("distance", 900))}
	var suite: Dictionary = run_detailed_suite(suite_options)
	load_report["detailed_suite"] = _strip_verbose_suite(suite)
	last_opendaoc_spellbook_report = load_report.duplicate(true)
	return load_report

func cast_opendaoc_spell_by_id(spell_id: int, candidate_dirs: Array = [], options: Dictionary = {}) -> Dictionary:
	if spell_book.get_spell(spell_id) == null and candidate_dirs.size() > 0:
		load_opendaoc_spellbook_from_candidates(candidate_dirs, options)
	var spell: DaocSpellDef = spell_book.get_spell(spell_id)
	if spell == null:
		return {"ok": false, "checkpoint": "P1_18D_OPENDAOC_SPELLBOOK_TO_COMBAT_LAB", "spell_id": spell_id, "status": "spell_not_found", "guardrails": DaocGameplayAuthority.result_guard()}
	if not (spell.spell_type in _registered_spell_types()):
		return {"ok": false, "checkpoint": "P1_18E_OPENDAOC_SPELL_COVERAGE", "spell_id": spell_id, "status": "unsupported_spell_type", "spell_type": spell.spell_type, "guardrails": DaocGameplayAuthority.result_guard(), "note": "Unsupported OpenDAoC Type is reported, not forced through a fake DirectDamage handler."}
	return cast_spell_by_id(spell_id, options)


func run_opendaoc_spell_coverage_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var load_report: Dictionary = load_opendaoc_spellbook_from_candidates(candidate_dirs, options)
	if not bool(load_report.get("ok", false)):
		last_opendaoc_coverage_report = {
			"checkpoint": "P1_18E_OPENDAOC_SPELL_COVERAGE",
			"scope": "P1-18E OpenDAoC spell coverage and unsupported Type backlog",
			"ok": false,
			"status": str(load_report.get("status", "")),
			"source_path": str(load_report.get("source_path", "")),
			"checked_paths": load_report.get("checked_paths", []),
			"guardrails": DaocGameplayAuthority.guardrails(),
			"runtime_enabled": false,
			"prediction_only": true,
			"damage_final": false,
			"server_authority": true,
		}
		return last_opendaoc_coverage_report.duplicate(true)
	var reporter: RefCounted = DaocOpenDaocSpellCoverageReportScript.new()
	var coverage: Dictionary = reporter.call("build", spell_book, _registered_spell_types(), options) as Dictionary
	coverage["source_path"] = str(load_report.get("source_path", ""))
	coverage["checked_paths"] = load_report.get("checked_paths", [])
	coverage["loader_status"] = str(load_report.get("status", ""))
	coverage["first_supported_spell_id"] = int(load_report.get("first_supported_spell_id", 0))
	coverage["spellbook_checkpoint"] = str(load_report.get("checkpoint", ""))
	last_opendaoc_coverage_report = coverage.duplicate(true)
	return coverage

func export_opendaoc_spell_coverage_report_json(path: String = OPENDAOC_COVERAGE_JSON_PATH) -> Dictionary:
	if last_opendaoc_coverage_report.is_empty():
		last_opendaoc_coverage_report = {"ok": false, "checkpoint": "P1_18E_OPENDAOC_SPELL_COVERAGE", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_opendaoc_coverage_report, "\t"))

func export_opendaoc_spell_coverage_report_text(path: String = OPENDAOC_COVERAGE_TEXT_PATH) -> Dictionary:
	if last_opendaoc_coverage_report.is_empty():
		last_opendaoc_coverage_report = {"ok": false, "checkpoint": "P1_18E_OPENDAOC_SPELL_COVERAGE", "status": "no_report_built"}
	var reporter: RefCounted = DaocOpenDaocSpellCoverageReportScript.new()
	return _write_text(path, str(reporter.call("build_text_report", last_opendaoc_coverage_report)))

func export_opendaoc_spellbook_report_json(path: String = OPENDAOC_SPELLBOOK_JSON_PATH) -> Dictionary:
	if last_opendaoc_spellbook_report.is_empty():
		last_opendaoc_spellbook_report = {"ok": false, "checkpoint": "P1_18D_OPENDAOC_SPELLBOOK_TO_COMBAT_LAB", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_opendaoc_spellbook_report, "\t"))

func export_opendaoc_spellbook_report_text(path: String = OPENDAOC_SPELLBOOK_TEXT_PATH) -> Dictionary:
	if last_opendaoc_spellbook_report.is_empty():
		last_opendaoc_spellbook_report = {"ok": false, "checkpoint": "P1_18D_OPENDAOC_SPELLBOOK_TO_COMBAT_LAB", "status": "no_report_built"}
	return _write_text(path, build_opendaoc_spellbook_text_report(last_opendaoc_spellbook_report))

func build_opendaoc_spellbook_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_opendaoc_spellbook_report
	var lines: Array = []
	lines.append("P1-18D OpenDAoC spell SQL -> Godot SpellBook")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("status", "")), str(r.get("checkpoint", ""))])
	lines.append("source_path=%s" % str(r.get("source_path", "")))
	var book: Dictionary = r.get("spellbook", {}) as Dictionary
	lines.append("spell_count=%d supported=%d unsupported=%d first_supported_spell_id=%d" % [int(book.get("spell_count", 0)), int(r.get("supported_spell_count", 0)), int(r.get("unsupported_spell_count", 0)), int(r.get("first_supported_spell_id", 0))])
	lines.append("supported_type_counts=%s" % str(r.get("supported_type_counts", {})))
	lines.append("unsupported_type_counts=%s" % str(r.get("unsupported_type_counts", {})))
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true")
	var suite: Dictionary = r.get("detailed_suite", {}) as Dictionary
	if not suite.is_empty():
		var summary: Dictionary = suite.get("summary", {}) as Dictionary
		lines.append("detailed_suite entries=%d total_predicted_damage=%d total_predicted_heal=%d" % [int(summary.get("entry_count", 0)), int(summary.get("total_predicted_damage", 0)), int(summary.get("total_predicted_heal", 0))])
	lines.append("Next: compare selected real spell IDs against live OpenDAoC server logs.")
	return "\n".join(lines) + "\n"

func _registered_spell_types() -> Array:
	var out: Array = []
	for key in registry.handler_scripts.keys():
		out.append(str(key))
	out.sort()
	return out

func _strip_heavy_spell_defs(report: Dictionary) -> Dictionary:
	var out: Dictionary = report.duplicate(true)
	out.erase("spell_defs")
	return out

func _strip_verbose_suite(suite: Dictionary) -> Dictionary:
	var out: Dictionary = suite.duplicate(true)
	var entries: Array = out.get("entries", []) as Array
	var compact_entries: Array = []
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (item as Dictionary).duplicate(true)
		entry.erase("raw_result")
		compact_entries.append(entry)
	out["entries"] = compact_entries
	return out



func _is_friendly_or_self_spell_type(spell_type: String) -> bool:
	return spell_type in [
		DaocCombatEnums.SPELL_HEAL,
		"HealthRegenBuff",
		"ConstitutionBuff",
		"Resurrect",
		"HealOverTime",
		"BodyResistBuff",
		"PowerHeal",
		"CombatHeal",
		"BodyResistDebuff",
		"EnduranceHeal",
		"SpreadHeal",
		"SavageEnduranceHeal",
		"PowerHealthEnduranceRegenBuff",
		"PveResurrectionIllness",
	]

func p1_18f_p0_spell_types() -> Array:
	return [
		"SpeedDecrease",
		"Mesmerize",
		"Stun",
		"StyleSpeedDecrease",
		"UnbreakableSpeedDecrease",
		"StyleStun",
		"CureMezz",
		"MesmerizeDurationBuff",
		"Lifedrain",
		"DirectDamageWithDebuff",
		"HealthRegenBuff",
		"ConstitutionBuff",
		"Resurrect",
		"HealOverTime",
		"BodyResistBuff",
		"PowerHeal",
		"CombatHeal",
		"BodyResistDebuff",
		"EnduranceHeal",
		"SpreadHeal",
		"SavageEnduranceHeal",
		"PowerHealthEnduranceRegenBuff",
		"PveResurrectionIllness",
	]

func run_opendaoc_p0_handler_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var coverage: Dictionary = run_opendaoc_spell_coverage_report(candidate_dirs, options)
	if not bool(coverage.get("ok", false)):
		last_opendaoc_p0_report = {
			"checkpoint": "P1_18F_OPENDAOC_P0_HANDLERS",
			"scope": "P1-18F OpenDAoC P0 spell handlers",
			"ok": false,
			"status": str(coverage.get("status", "")),
			"guardrails": DaocGameplayAuthority.guardrails(),
			"runtime_enabled": false,
			"prediction_only": true,
			"damage_final": false,
			"server_authority": true,
		}
		return last_opendaoc_p0_report.duplicate(true)
	var p0_types: Array = p1_18f_p0_spell_types()
	var registered: Array = _registered_spell_types()
	var missing_registered: Array = []
	for type_name in p0_types:
		if not (str(type_name) in registered):
			missing_registered.append(str(type_name))
	var casts: Array = []
	var type_rows: Array = coverage.get("type_rows", []) as Array
	for item in type_rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		var row_type: String = str(row.get("spell_type", ""))
		if not (row_type in p0_types):
			continue
		var sample_ids: Array = row.get("sample_spell_ids", []) as Array
		if sample_ids.is_empty():
			continue
		var sample_id: int = int(sample_ids[0])
		var cast_result: Dictionary = cast_opendaoc_spell_by_id(sample_id, candidate_dirs, {"seed": int(options.get("seed", 42)), "verbose": bool(options.get("verbose", false)), "max_rows": int(options.get("max_rows", 8192))})
		casts.append(_compact_cast_probe(row_type, sample_id, cast_result))
	var ok_cast_count: int = 0
	var by_handler: Dictionary = {}
	for cast_item in casts:
		if typeof(cast_item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = cast_item as Dictionary
		if bool(cast.get("ok", false)):
			ok_cast_count += 1
		var handler_name: String = str(cast.get("handler_family", "unknown"))
		by_handler[handler_name] = int(by_handler.get(handler_name, 0)) + 1
	last_opendaoc_p0_report = {
		"checkpoint": "P1_18F_OPENDAOC_P0_HANDLERS",
		"scope": "P1-18F OpenDAoC P0 spell handlers",
		"ok": missing_registered.is_empty() and casts.size() > 0 and ok_cast_count == casts.size(),
		"status": "p0_handlers_built",
		"guardrails": DaocGameplayAuthority.guardrails(),
		"source_path": str(coverage.get("source_path", "")),
		"checked_paths": coverage.get("checked_paths", []),
		"registered_handler_types": registered,
		"p0_registered_types": p0_types,
		"missing_registered_types": missing_registered,
		"total_spell_count": int(coverage.get("total_spell_count", 0)),
		"supported_spell_count": int(coverage.get("supported_spell_count", 0)),
		"unsupported_spell_count": int(coverage.get("unsupported_spell_count", 0)),
		"supported_ratio": float(coverage.get("supported_ratio", 0.0)),
		"coverage_checkpoint": str(coverage.get("checkpoint", "")),
		"cast_probe_count": casts.size(),
		"ok_cast_probe_count": ok_cast_count,
		"cast_probes": casts,
		"handler_probe_counts": by_handler,
		"runtime_enabled": false,
		"prediction_only": true,
		"damage_final": false,
		"server_authority": true,
		"notes": [
			"P0 handlers are prediction-only scaffolds for lab reporting and later live-server comparison.",
			"Unsupported spell Types are still not forced through fake damage handlers.",
			"Crowd-control, lifedrain, DD+debuff and heal/support/rez families now have explicit effect models.",
		],
	}
	return last_opendaoc_p0_report.duplicate(true)

func _compact_cast_probe(row_type: String, spell_id: int, cast_result: Dictionary) -> Dictionary:
	var detail: Dictionary = cast_result.get("detail", {}) as Dictionary
	var damage_summary: Dictionary = detail.get("damage_summary", {}) as Dictionary
	var effects: Array = detail.get("effects", []) as Array
	var effect_types: Array = []
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		effect_types.append(str(effect.get("effect_type", "")))
	return {
		"spell_type": row_type,
		"spell_id": spell_id,
		"ok": bool(cast_result.get("ok", false)),
		"status": str(cast_result.get("status", "")),
		"mechanism": str(detail.get("mechanism", "")),
		"handler_family": _handler_family_for_type(row_type),
		"hp_delta_predicted": int(detail.get("hp_delta_predicted", 0)),
		"damage": int(damage_summary.get("damage", 0)),
		"critical_damage": int(damage_summary.get("critical_damage", 0)),
		"effect_count": effects.size(),
		"effect_types": effect_types,
		"guardrails": DaocGameplayAuthority.result_guard(),
	}

func _handler_family_for_type(spell_type: String) -> String:
	if spell_type in p1_18g_buff_debuff_types():
		return "DaocBuffDebuffSpellHandler"
	if spell_type in p1_18h_dot_disease_proc_types():
		return "DaocDoTDiseaseProcSpellHandler"
	if spell_type in p1_18i_generic_damage_effect_types():
		return "DaocGenericDamageEffectSpellHandler"
	if spell_type in p1_18j_pet_types():
		return "DaocPetSpellHandler"
	if spell_type in ["SpeedDecrease", "Mesmerize", "Stun", "StyleSpeedDecrease", "UnbreakableSpeedDecrease", "StyleStun", "CureMezz", "MesmerizeDurationBuff"]:
		return "DaocCrowdControlSpellHandler"
	if spell_type == "Lifedrain":
		return "DaocLifeDrainSpellHandler"
	if spell_type == "DirectDamageWithDebuff":
		return "DaocDirectDamageWithDebuffSpellHandler"
	if spell_type in ["HealthRegenBuff", "ConstitutionBuff", "Resurrect", "HealOverTime", "BodyResistBuff", "PowerHeal", "CombatHeal", "BodyResistDebuff", "EnduranceHeal", "SpreadHeal", "SavageEnduranceHeal", "PowerHealthEnduranceRegenBuff", "PveResurrectionIllness"]:
		return "DaocHealOrResurrectSpellHandler"
	return "unknown"

func p1_18g_buff_debuff_types() -> Array:
	return registry.p1_18g_buff_debuff_types()

func p1_18h_dot_disease_proc_types() -> Array:
	return registry.p1_18h_dot_disease_proc_types()

func p1_18i_generic_damage_effect_types() -> Array:
	return registry.p1_18i_generic_damage_effect_types()

func p1_18j_pet_types() -> Array:
	return registry.p1_18j_pet_types()

func run_opendaoc_buff_debuff_state_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var coverage: Dictionary = run_opendaoc_spell_coverage_report(candidate_dirs, options)
	if not bool(coverage.get("ok", false)):
		var requested_waiting_types: Array = p1_18g_buff_debuff_types()
		last_buff_debuff_state_report = {
			"checkpoint": "P1_18G_BUFF_DEBUFF_STATE_MODEL",
			"scope": "P1-18G Buff/Debuff state model",
			"ok": false,
			"status": str(coverage.get("status", "")),
			"guardrails": DaocGameplayAuthority.guardrails(),
			"registered_types": requested_waiting_types,
			"missing_registered_types": [],
			"supported": 0,
			"unsupported": 0,
			"sample_casts": [],
			"active_effect_summary": active_effect_state.call("summary"),
			"runtime_enabled": false,
			"prediction_only": true,
			"damage_final": false,
			"server_authority": true,
		}
		return last_buff_debuff_state_report.duplicate(true)
	active_effect_state.call("clear")
	var requested_types: Array = p1_18g_buff_debuff_types()
	var registered: Array = _registered_spell_types()
	var missing_registered: Array = []
	for type_name in requested_types:
		if not (str(type_name) in registered):
			missing_registered.append(str(type_name))
	var casts: Array = []
	var type_rows: Array = coverage.get("type_rows", []) as Array
	var supported_count: int = 0
	var unsupported_count: int = 0
	for item in type_rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		var row_type: String = str(row.get("spell_type", ""))
		if not (row_type in requested_types):
			continue
		var row_count: int = int(row.get("count", 0))
		if row_type in registered:
			supported_count += row_count
		else:
			unsupported_count += row_count
		var sample_ids: Array = row.get("sample_spell_ids", []) as Array
		if sample_ids.is_empty():
			continue
		var sample_id: int = int(sample_ids[0])
		var cast_result: Dictionary = cast_opendaoc_spell_by_id(sample_id, candidate_dirs, {"seed": int(options.get("seed", 42)), "verbose": bool(options.get("verbose", false)), "max_rows": int(options.get("max_rows", 8192))})
		var compact: Dictionary = _compact_buff_debuff_cast(row_type, sample_id, cast_result)
		casts.append(compact)
		var effects: Array = compact.get("active_effects", []) as Array
		for effect_item in effects:
			if typeof(effect_item) == TYPE_DICTIONARY:
				active_effect_state.call("add_effect_dict", effect_item as Dictionary)
	var effect_summary: Dictionary = active_effect_state.call("summary") as Dictionary
	var ok_cast_count: int = 0
	for cast_item in casts:
		if typeof(cast_item) == TYPE_DICTIONARY and bool((cast_item as Dictionary).get("ok", false)):
			ok_cast_count += 1
	last_buff_debuff_state_report = {
		"checkpoint": "P1_18G_BUFF_DEBUFF_STATE_MODEL",
		"scope": "P1-18G Buff/Debuff state model",
		"ok": missing_registered.is_empty() and casts.size() > 0 and ok_cast_count == casts.size() and int(effect_summary.get("active_effect_count", 0)) > 0,
		"status": "buff_debuff_state_built",
		"guardrails": DaocGameplayAuthority.guardrails(),
		"source_path": str(coverage.get("source_path", "")),
		"checked_paths": coverage.get("checked_paths", []),
		"supported": supported_count,
		"unsupported": unsupported_count,
		"total_spell_count": int(coverage.get("total_spell_count", 0)),
		"supported_spell_count": int(coverage.get("supported_spell_count", 0)),
		"unsupported_spell_count": int(coverage.get("unsupported_spell_count", 0)),
		"supported_ratio": float(coverage.get("supported_ratio", 0.0)),
		"registered_types": requested_types,
		"missing_registered_types": missing_registered,
		"sample_casts": casts,
		"sample_cast_count": casts.size(),
		"ok_sample_cast_count": ok_cast_count,
		"active_effects": active_effect_state.call("to_array"),
		"active_effect_summary": effect_summary,
		"runtime_enabled": false,
		"prediction_only": true,
		"damage_final": false,
		"server_authority": true,
		"notes": [
			"Buff/Debuff effects are represented as offline active state only.",
			"No final stat, resist, damage, spawn, movement or runtime server authority is granted to the client.",
			"Unsupported OpenDAoC Types remain explicit backlog items and are not forced through DirectDamage.",
		],
	}
	return last_buff_debuff_state_report.duplicate(true)

func effects_state_snapshot() -> Dictionary:
	if int((active_effect_state.call("summary") as Dictionary).get("active_effect_count", 0)) == 0 and not last_buff_debuff_state_report.is_empty():
		var stored: Array = last_buff_debuff_state_report.get("active_effects", []) as Array
		for item in stored:
			if typeof(item) == TYPE_DICTIONARY:
				active_effect_state.call("add_effect_dict", item as Dictionary)
	var summary: Dictionary = active_effect_state.call("summary") as Dictionary
	return {
		"checkpoint": "P1_18G_EFFECTS_STATE",
		"ok": int(summary.get("active_effect_count", 0)) > 0,
		"active_effect_summary": summary,
		"active_effects": active_effect_state.call("to_array"),
		"guardrails": DaocGameplayAuthority.guardrails(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func _compact_buff_debuff_cast(row_type: String, spell_id: int, cast_result: Dictionary) -> Dictionary:
	var detail: Dictionary = cast_result.get("detail", {}) as Dictionary
	var effects: Array = detail.get("effects", []) as Array
	var active_effects: Array = []
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		if effect.has("source_spell_id"):
			active_effects.append(effect.duplicate(true))
	return {
		"spell_type": row_type,
		"spell_id": spell_id,
		"ok": bool(cast_result.get("ok", false)) and active_effects.size() > 0,
		"mechanism": str(detail.get("mechanism", "")),
		"handler_family": _handler_family_for_type(row_type),
		"active_effect_count": active_effects.size(),
		"active_effects": active_effects,
		"guardrails": DaocGameplayAuthority.result_guard(),
	}

func export_buff_debuff_state_report_json(path: String = OPENDAOC_BUFF_DEBUFF_JSON_PATH) -> Dictionary:
	if last_buff_debuff_state_report.is_empty():
		last_buff_debuff_state_report = {"ok": false, "checkpoint": "P1_18G_BUFF_DEBUFF_STATE_MODEL", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_buff_debuff_state_report, "\t"))

func export_buff_debuff_state_report_text(path: String = OPENDAOC_BUFF_DEBUFF_TEXT_PATH) -> Dictionary:
	if last_buff_debuff_state_report.is_empty():
		last_buff_debuff_state_report = {"ok": false, "checkpoint": "P1_18G_BUFF_DEBUFF_STATE_MODEL", "status": "no_report_built"}
	return _write_text(path, build_buff_debuff_state_text_report(last_buff_debuff_state_report))

func build_buff_debuff_state_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_buff_debuff_state_report
	var lines: Array = []
	lines.append("P1-18G Buff/Debuff state model")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("status", "")), str(r.get("checkpoint", ""))])
	lines.append("total=%d supported=%d unsupported=%d ratio=%.1f%%" % [int(r.get("total_spell_count", 0)), int(r.get("supported_spell_count", 0)), int(r.get("unsupported_spell_count", 0)), float(r.get("supported_ratio", 0.0)) * 100.0])
	lines.append("buff_debuff_supported=%d buff_debuff_unsupported=%d registered_types=%d" % [int(r.get("supported", 0)), int(r.get("unsupported", 0)), (r.get("registered_types", []) as Array).size()])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true")
	var summary: Dictionary = r.get("active_effect_summary", {}) as Dictionary
	lines.append("active_effects=%d categories=%s" % [int(summary.get("active_effect_count", 0)), str(summary.get("effects_by_category", {}))])
	lines.append("stats=%s" % str(summary.get("modifiers_by_stat", {})))
	lines.append("resists=%s" % str(summary.get("modifiers_by_resist", {})))
	lines.append("speed=%d armor=%d regen=%d" % [(summary.get("speed_modifiers", []) as Array).size(), (summary.get("armor_modifiers", []) as Array).size(), (summary.get("regen_modifiers", []) as Array).size()])
	var casts: Array = r.get("sample_casts", []) as Array
	for item in casts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = item as Dictionary
		lines.append("- type=%s spell_id=%d ok=%s handler=%s effects=%d" % [str(cast.get("spell_type", "")), int(cast.get("spell_id", 0)), str(cast.get("ok", false)), str(cast.get("handler_family", "")), int(cast.get("active_effect_count", 0))])
	lines.append("Next: compare active effect state with live OpenDAoC server packets before promoting formulas.")
	return "\n".join(lines) + "\n"

func run_opendaoc_dot_disease_proc_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	last_dot_disease_proc_report = _run_opendaoc_group_report(
		"P1_18H_DOT_DISEASE_PROC_STATE_MODEL",
		"P1-18H DoT/Disease/Proc state model",
		"dot_disease_proc_state_built",
		p1_18h_dot_disease_proc_types(),
		candidate_dirs,
		options
	)
	return last_dot_disease_proc_report.duplicate(true)

func run_opendaoc_generic_damage_effect_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	last_generic_damage_effect_report = _run_opendaoc_group_report(
		"P1_18I_GENERIC_DAMAGE_EFFECTS",
		"P1-18I Generic damage effects",
		"generic_damage_effects_built",
		p1_18i_generic_damage_effect_types(),
		candidate_dirs,
		options
	)
	return last_generic_damage_effect_report.duplicate(true)

func run_opendaoc_pet_summon_intent_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	last_pet_intent_report = _run_opendaoc_group_report(
		"P1_18J_PET_SUMMON_INTENT_MODEL",
		"P1-18J Pet/Summon intent model",
		"pet_summon_intent_built",
		p1_18j_pet_types(),
		candidate_dirs,
		options
	)
	return last_pet_intent_report.duplicate(true)

func _run_opendaoc_group_report(checkpoint: String, scope: String, built_status: String, requested_types: Array, candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var coverage: Dictionary = run_opendaoc_spell_coverage_report(candidate_dirs, options)
	if not bool(coverage.get("ok", false)):
		return {
			"checkpoint": checkpoint,
			"scope": scope,
			"ok": false,
			"status": str(coverage.get("status", "")),
			"guardrails": DaocGameplayAuthority.guardrails(),
			"registered_types": requested_types,
			"missing_registered_types": [],
			"supported": 0,
			"unsupported": 0,
			"sample_casts": [],
			"runtime_enabled": false,
			"prediction_only": true,
			"damage_final": false,
			"server_authority": true,
		}
	var registered: Array = _registered_spell_types()
	var missing_registered: Array = []
	for type_name in requested_types:
		if not (str(type_name) in registered):
			missing_registered.append(str(type_name))
	var casts: Array = []
	var type_rows: Array = coverage.get("type_rows", []) as Array
	var supported_count: int = 0
	var unsupported_count: int = 0
	for item in type_rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item as Dictionary
		var row_type: String = str(row.get("spell_type", ""))
		if not (row_type in requested_types):
			continue
		var row_count: int = int(row.get("count", 0))
		if row_type in registered:
			supported_count += row_count
		else:
			unsupported_count += row_count
		var sample_ids: Array = row.get("sample_spell_ids", []) as Array
		if sample_ids.is_empty():
			continue
		var sample_id: int = int(sample_ids[0])
		var cast_result: Dictionary = cast_opendaoc_spell_by_id(sample_id, candidate_dirs, {"seed": int(options.get("seed", 42)), "verbose": bool(options.get("verbose", false)), "max_rows": int(options.get("max_rows", 8192))})
		casts.append(_compact_effect_family_cast(row_type, sample_id, cast_result))
	var ok_cast_count: int = 0
	var effect_type_counts: Dictionary = {}
	var handler_counts: Dictionary = {}
	for cast_item in casts:
		if typeof(cast_item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = cast_item as Dictionary
		if bool(cast.get("ok", false)):
			ok_cast_count += 1
		var handler_name: String = str(cast.get("handler_family", "unknown"))
		handler_counts[handler_name] = int(handler_counts.get(handler_name, 0)) + 1
		var effect_types: Array = cast.get("effect_types", []) as Array
		for effect_type in effect_types:
			effect_type_counts[str(effect_type)] = int(effect_type_counts.get(str(effect_type), 0)) + 1
	return {
		"checkpoint": checkpoint,
		"scope": scope,
		"ok": missing_registered.is_empty() and casts.size() > 0 and ok_cast_count == casts.size(),
		"status": built_status,
		"guardrails": DaocGameplayAuthority.guardrails(),
		"source_path": str(coverage.get("source_path", "")),
		"checked_paths": coverage.get("checked_paths", []),
		"supported": supported_count,
		"unsupported": unsupported_count,
		"total_spell_count": int(coverage.get("total_spell_count", 0)),
		"supported_spell_count": int(coverage.get("supported_spell_count", 0)),
		"unsupported_spell_count": int(coverage.get("unsupported_spell_count", 0)),
		"supported_ratio": float(coverage.get("supported_ratio", 0.0)),
		"registered_types": requested_types,
		"missing_registered_types": missing_registered,
		"sample_casts": casts,
		"sample_cast_count": casts.size(),
		"ok_sample_cast_count": ok_cast_count,
		"handler_probe_counts": handler_counts,
		"effect_type_counts": effect_type_counts,
		"runtime_enabled": false,
		"prediction_only": true,
		"damage_final": false,
		"server_authority": true,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"notes": [
			"OpenDAoC rows are represented for offline lab reporting only.",
			"Final damage, proc triggers, cures, charm, pet entities, siege entities and spawns remain server-authoritative.",
			"Unsupported spell Types remain explicit backlog items and are not forced through DirectDamage.",
		],
	}

func _compact_effect_family_cast(row_type: String, spell_id: int, cast_result: Dictionary) -> Dictionary:
	var detail: Dictionary = cast_result.get("detail", {}) as Dictionary
	var effects: Array = detail.get("effects", []) as Array
	var damage_summary: Dictionary = detail.get("damage_summary", {}) as Dictionary
	var effect_types: Array = []
	var categories: Array = []
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		effect_types.append(str(effect.get("effect_type", "")))
		categories.append(str(effect.get("effect_category", "")))
	return {
		"spell_type": row_type,
		"spell_id": spell_id,
		"ok": bool(cast_result.get("ok", false)) and effects.size() > 0,
		"mechanism": str(detail.get("mechanism", "")),
		"handler_family": _handler_family_for_type(row_type),
		"effect_count": effects.size(),
		"effect_types": effect_types,
		"effect_categories": categories,
		"hp_delta_predicted": int(detail.get("hp_delta_predicted", 0)),
		"damage": int(damage_summary.get("damage", 0)),
		"guardrails": DaocGameplayAuthority.result_guard(),
	}

func export_dot_disease_proc_report_json(path: String = OPENDAOC_DOT_DISEASE_PROC_JSON_PATH) -> Dictionary:
	if last_dot_disease_proc_report.is_empty():
		last_dot_disease_proc_report = {"ok": false, "checkpoint": "P1_18H_DOT_DISEASE_PROC_STATE_MODEL", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_dot_disease_proc_report, "\t"))

func export_dot_disease_proc_report_text(path: String = OPENDAOC_DOT_DISEASE_PROC_TEXT_PATH) -> Dictionary:
	if last_dot_disease_proc_report.is_empty():
		last_dot_disease_proc_report = {"ok": false, "checkpoint": "P1_18H_DOT_DISEASE_PROC_STATE_MODEL", "status": "no_report_built"}
	return _write_text(path, build_effect_family_text_report(last_dot_disease_proc_report))

func export_generic_damage_effect_report_json(path: String = OPENDAOC_GENERIC_DAMAGE_JSON_PATH) -> Dictionary:
	if last_generic_damage_effect_report.is_empty():
		last_generic_damage_effect_report = {"ok": false, "checkpoint": "P1_18I_GENERIC_DAMAGE_EFFECTS", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_generic_damage_effect_report, "\t"))

func export_generic_damage_effect_report_text(path: String = OPENDAOC_GENERIC_DAMAGE_TEXT_PATH) -> Dictionary:
	if last_generic_damage_effect_report.is_empty():
		last_generic_damage_effect_report = {"ok": false, "checkpoint": "P1_18I_GENERIC_DAMAGE_EFFECTS", "status": "no_report_built"}
	return _write_text(path, build_effect_family_text_report(last_generic_damage_effect_report))

func export_pet_summon_intent_report_json(path: String = OPENDAOC_PET_INTENT_JSON_PATH) -> Dictionary:
	if last_pet_intent_report.is_empty():
		last_pet_intent_report = {"ok": false, "checkpoint": "P1_18J_PET_SUMMON_INTENT_MODEL", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_pet_intent_report, "\t"))

func export_pet_summon_intent_report_text(path: String = OPENDAOC_PET_INTENT_TEXT_PATH) -> Dictionary:
	if last_pet_intent_report.is_empty():
		last_pet_intent_report = {"ok": false, "checkpoint": "P1_18J_PET_SUMMON_INTENT_MODEL", "status": "no_report_built"}
	return _write_text(path, build_effect_family_text_report(last_pet_intent_report))

func build_effect_family_text_report(report: Dictionary) -> String:
	var lines: Array = []
	lines.append(str(report.get("scope", "")))
	lines.append("ok=%s status=%s checkpoint=%s" % [str(report.get("ok", false)), str(report.get("status", "")), str(report.get("checkpoint", ""))])
	lines.append("total=%d supported=%d unsupported=%d ratio=%.1f%%" % [int(report.get("total_spell_count", 0)), int(report.get("supported_spell_count", 0)), int(report.get("unsupported_spell_count", 0)), float(report.get("supported_ratio", 0.0)) * 100.0])
	lines.append("family_supported=%d family_unsupported=%d registered_types=%d" % [int(report.get("supported", 0)), int(report.get("unsupported", 0)), (report.get("registered_types", []) as Array).size()])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true coordinate_frame_confirmed=false player_spawn_applied=false")
	lines.append("sample_cast_count=%d ok_sample_cast_count=%d handlers=%s effects=%s" % [int(report.get("sample_cast_count", 0)), int(report.get("ok_sample_cast_count", 0)), str(report.get("handler_probe_counts", {})), str(report.get("effect_type_counts", {}))])
	var casts: Array = report.get("sample_casts", []) as Array
	for item in casts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = item as Dictionary
		lines.append("- type=%s spell_id=%d ok=%s handler=%s effects=%s categories=%s damage=%d" % [str(cast.get("spell_type", "")), int(cast.get("spell_id", 0)), str(cast.get("ok", false)), str(cast.get("handler_family", "")), str(cast.get("effect_types", [])), str(cast.get("effect_categories", [])), int(cast.get("damage", 0))])
	lines.append("Next: compare these prediction-only states against live OpenDAoC/DOL logs before promoting formulas or entity behavior.")
	return "\n".join(lines) + "\n"

func run_opendaoc_k25_lab_runtime_report(candidate_dirs: Array, options: Dictionary = {}) -> Dictionary:
	var coverage: Dictionary = run_opendaoc_spell_coverage_report(candidate_dirs, options)
	if not bool(coverage.get("ok", false)):
		last_k25_lab_runtime_report = {
			"checkpoint": "P1_18K_2_5_LAB_RUNTIME",
			"scope": "P1-18K.2-K.5 heal/buff/dot/pet lab runtime observation",
			"ok": false,
			"status": str(coverage.get("status", "")),
			"guardrails": DaocGameplayAuthority.guardrails(),
			"runtime_enabled": false,
			"prediction_only": true,
			"damage_final": false,
			"server_authority": true,
		}
		return last_k25_lab_runtime_report.duplicate(true)
	var buff_report: Dictionary = run_opendaoc_buff_debuff_state_report(candidate_dirs, options)
	var dot_report: Dictionary = run_opendaoc_dot_disease_proc_report(candidate_dirs, options)
	var pet_report: Dictionary = run_opendaoc_pet_summon_intent_report(candidate_dirs, options)
	var k2: Dictionary = _run_k25_heal_simple(coverage, options)
	var k3: Dictionary = _run_k25_buff_debuff_duration(buff_report, int(options.get("advance_msec", 1000)))
	var k4: Dictionary = _run_k25_dot_tick_minimal(coverage, options)
	var k5: Dictionary = _run_k25_pet_observation(pet_report)
	last_k25_lab_runtime_report = {
		"checkpoint": "P1_18K_2_5_LAB_RUNTIME",
		"scope": "P1-18K.2-K.5 heal/buff/dot/pet lab runtime observation",
		"ok": bool(k2.get("ok", false)) and bool(k3.get("ok", false)) and bool(k4.get("ok", false)) and bool(k5.get("ok", false)),
		"status": "k25_lab_runtime_built",
		"guardrails": DaocGameplayAuthority.guardrails(),
		"source_path": str(coverage.get("source_path", "")),
		"supported_spell_count": int(coverage.get("supported_spell_count", 0)),
		"unsupported_spell_count": int(coverage.get("unsupported_spell_count", 0)),
		"supported_ratio": float(coverage.get("supported_ratio", 0.0)),
		"k2_heal_simple": k2,
		"k3_buff_debuff_duration": k3,
		"k4_dot_tick_minimal": k4,
		"k5_pet_summon_observation": k5,
		"runtime_enabled": false,
		"prediction_only": true,
		"damage_final": false,
		"server_authority": true,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"notes": [
			"K.2 applies heal only to an isolated lab actor.",
			"K.3 advances active-effect duration in offline state; no final stat mutation is applied.",
			"K.4 applies one minimal DoT tick only to an isolated lab actor and keeps damage_final=false.",
			"K.5 observes pet/summon intents only; no entity, movement, charm or spawn is created.",
		],
	}
	return last_k25_lab_runtime_report.duplicate(true)

func _run_k25_heal_simple(coverage: Dictionary, options: Dictionary = {}) -> Dictionary:
	var spell_id: int = _first_sample_spell_id_for_types(coverage, ["Heal", "CombatHeal", "SpreadHeal", "PowerHeal"])
	var actors: Dictionary = build_default_actor_pair()
	var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
	if caster != null:
		caster.health = maxi(1, caster.max_health - 420)
	var spell: DaocSpellDef = spell_book.get_spell(spell_id)
	var handler: DaocSpellHandler = registry.create_handler(spell)
	if spell == null or handler == null or caster == null:
		return {"ok": false, "status": "missing_heal_probe", "spell_id": spell_id, "guardrails": DaocGameplayAuthority.result_guard()}
	var hp_before: int = caster.health
	var result: Dictionary = handler.execute(caster, caster, {"seed": int(options.get("seed", 42)), "apply_to_target": true})
	var effects: Array = result.get("effects", []) as Array
	var heal_effect: Dictionary = effects[0] as Dictionary if effects.size() > 0 and typeof(effects[0]) == TYPE_DICTIONARY else {}
	return {
		"ok": bool(result.get("ok", false)) and caster.health > hp_before and int(heal_effect.get("effective_amount", 0)) > 0,
		"checkpoint": "P1_18K_2_HEAL_SIMPLE",
		"spell_id": spell_id,
		"spell_type": spell.spell_type,
		"spell_name": spell.name,
		"hp_before": hp_before,
		"hp_after": caster.health,
		"effective_amount": int(heal_effect.get("effective_amount", 0)),
		"applied_to_lab_target": bool(heal_effect.get("applied_to_lab_target", false)),
		"guardrails": DaocGameplayAuthority.result_guard(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func _run_k25_buff_debuff_duration(buff_report: Dictionary, advance_msec: int) -> Dictionary:
	var state: RefCounted = DaocEffectStateScript.new()
	var active: Array = buff_report.get("active_effects", []) as Array
	for item in active:
		if typeof(item) == TYPE_DICTIONARY:
			state.call("add_effect_dict", item as Dictionary)
	var before: Dictionary = state.call("summary") as Dictionary
	var advanced: Dictionary = state.call("advance_time", advance_msec) as Dictionary
	var after: Dictionary = advanced.get("active_effect_summary", {}) as Dictionary
	return {
		"ok": int(before.get("active_effect_count", 0)) > 0 and bool(advanced.get("ok", false)) and int(after.get("active_effect_count", 0)) >= 0,
		"checkpoint": "P1_18K_3_BUFF_DEBUFF_DURATION",
		"advanced_msec": int(advanced.get("advanced_msec", 0)),
		"active_before": int(before.get("active_effect_count", 0)),
		"active_after": int(after.get("active_effect_count", 0)),
		"expired_count": int(advanced.get("expired_count", 0)),
		"summary_before": before,
		"summary_after": after,
		"guardrails": DaocGameplayAuthority.result_guard(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func _run_k25_dot_tick_minimal(coverage: Dictionary, options: Dictionary = {}) -> Dictionary:
	var sample_ids: Array = _sample_spell_ids_for_types(coverage, ["StyleBleeding", DaocCombatEnums.SPELL_DAMAGE_OVER_TIME, "ArcheryDoT"])
	var spell_id: int = 0
	var spell: DaocSpellDef = null
	var hp_before: int = 0
	var tick_damage: int = 0
	var applied_delta: int = 0
	var target_health_after: int = 0
	for sample_id in sample_ids:
		var actors: Dictionary = build_default_actor_pair()
		var caster: DaocCombatEntityState = actors.get("caster") as DaocCombatEntityState
		var target: DaocCombatEntityState = actors.get("target") as DaocCombatEntityState
		var candidate_spell: DaocSpellDef = spell_book.get_spell(int(sample_id))
		var handler: DaocSpellHandler = registry.create_handler(candidate_spell)
		if candidate_spell == null or handler == null or caster == null or target == null:
			continue
		var result: Dictionary = handler.execute(caster, target, {"seed": int(options.get("seed", 42)), "distance": int(options.get("distance", 900))})
		var candidate_tick_damage: int = _first_dot_tick_damage(result)
		if candidate_tick_damage <= 0:
			continue
		spell_id = int(sample_id)
		spell = candidate_spell
		hp_before = target.health
		tick_damage = candidate_tick_damage
		applied_delta = target.change_health(-tick_damage)
		target_health_after = target.health
		break
	if spell == null:
		return {"ok": false, "status": "missing_positive_dot_tick_probe", "sample_ids": sample_ids, "guardrails": DaocGameplayAuthority.result_guard()}
	return {
		"ok": tick_damage > 0 and applied_delta < 0,
		"checkpoint": "P1_18K_4_DOT_TICK_MINIMAL",
		"spell_id": spell_id,
		"spell_type": spell.spell_type,
		"spell_name": spell.name,
		"hp_before": hp_before,
		"hp_after_lab_tick": target_health_after,
		"tick_damage": tick_damage,
		"applied_delta": applied_delta,
		"lab_tick_applied": true,
		"final_damage_applied": false,
		"guardrails": DaocGameplayAuthority.result_guard(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func _run_k25_pet_observation(pet_report: Dictionary) -> Dictionary:
	var casts: Array = pet_report.get("sample_casts", []) as Array
	var observed: Array = []
	var intent_counts: Dictionary = {}
	var family_counts: Dictionary = {}
	for item in casts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = item as Dictionary
		var effect_types: Array = cast.get("effect_types", []) as Array
		if not effect_types.has("pet_summon_intent"):
			continue
		var observation: Dictionary = {
			"spell_id": int(cast.get("spell_id", 0)),
			"spell_type": str(cast.get("spell_type", "")),
			"handler_family": str(cast.get("handler_family", "")),
			"observed_only": true,
			"runtime_spawn_applied": false,
			"player_spawn_applied": false,
			"coordinate_frame_confirmed": false,
			"server_authority": true,
			"prediction_only": true,
		}
		observed.append(observation)
		var spell_type: String = str(cast.get("spell_type", ""))
		var intent_kind: String = "charm_intent" if spell_type == "Charm" else "summon_intent"
		if spell_type.begins_with("SummonSiege"):
			intent_kind = "siege_summon_intent"
		var family: String = "siege" if spell_type.contains("Siege") else "summon"
		intent_counts[intent_kind] = int(intent_counts.get(intent_kind, 0)) + 1
		family_counts[family] = int(family_counts.get(family, 0)) + 1
	return {
		"ok": observed.size() > 0,
		"checkpoint": "P1_18K_5_PET_SUMMON_OBSERVATION",
		"observed_intent_count": observed.size(),
		"observed_intents": observed,
		"intent_counts": intent_counts,
		"family_counts": family_counts,
		"runtime_spawn_applied": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"guardrails": DaocGameplayAuthority.result_guard(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func _first_dot_tick_damage(result: Dictionary) -> int:
	var effects: Array = result.get("effects", []) as Array
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		var ticks: Array = effect.get("ticks", []) as Array
		if ticks.is_empty() or typeof(ticks[0]) != TYPE_DICTIONARY:
			continue
		var tick: Dictionary = ticks[0] as Dictionary
		return int(tick.get("damage", 0)) + int(tick.get("critical_damage", 0))
	return 0

func _first_sample_spell_id_for_types(coverage: Dictionary, type_names: Array) -> int:
	var ids: Array = _sample_spell_ids_for_types(coverage, type_names)
	return int(ids[0]) if not ids.is_empty() else 0

func _sample_spell_ids_for_types(coverage: Dictionary, type_names: Array) -> Array:
	var type_rows: Array = coverage.get("type_rows", []) as Array
	var out: Array = []
	for type_name in type_names:
		for item in type_rows:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = item as Dictionary
			if str(row.get("spell_type", "")) != str(type_name):
				continue
			var sample_ids: Array = row.get("sample_spell_ids", []) as Array
			for sample_id in sample_ids:
				out.append(int(sample_id))
	return out

func export_k25_lab_runtime_report_json(path: String = OPENDAOC_K25_JSON_PATH) -> Dictionary:
	if last_k25_lab_runtime_report.is_empty():
		last_k25_lab_runtime_report = {"ok": false, "checkpoint": "P1_18K_2_5_LAB_RUNTIME", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_k25_lab_runtime_report, "\t"))

func export_k25_lab_runtime_report_text(path: String = OPENDAOC_K25_TEXT_PATH) -> Dictionary:
	if last_k25_lab_runtime_report.is_empty():
		last_k25_lab_runtime_report = {"ok": false, "checkpoint": "P1_18K_2_5_LAB_RUNTIME", "status": "no_report_built"}
	return _write_text(path, build_k25_lab_runtime_text_report(last_k25_lab_runtime_report))

func build_k25_lab_runtime_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_k25_lab_runtime_report
	var k2: Dictionary = r.get("k2_heal_simple", {}) as Dictionary
	var k3: Dictionary = r.get("k3_buff_debuff_duration", {}) as Dictionary
	var k4: Dictionary = r.get("k4_dot_tick_minimal", {}) as Dictionary
	var k5: Dictionary = r.get("k5_pet_summon_observation", {}) as Dictionary
	var lines: Array = []
	lines.append("P1-18K.2-K.5 lab runtime observation")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("status", "")), str(r.get("checkpoint", ""))])
	lines.append("supported=%d unsupported=%d ratio=%.1f%%" % [int(r.get("supported_spell_count", 0)), int(r.get("unsupported_spell_count", 0)), float(r.get("supported_ratio", 0.0)) * 100.0])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true coordinate_frame_confirmed=false player_spawn_applied=false")
	lines.append("K.2 heal spell_id=%d hp=%d->%d effective=%d applied_lab=%s" % [int(k2.get("spell_id", 0)), int(k2.get("hp_before", 0)), int(k2.get("hp_after", 0)), int(k2.get("effective_amount", 0)), str(k2.get("applied_to_lab_target", false))])
	lines.append("K.3 effects active=%d->%d advanced_msec=%d expired=%d" % [int(k3.get("active_before", 0)), int(k3.get("active_after", 0)), int(k3.get("advanced_msec", 0)), int(k3.get("expired_count", 0))])
	lines.append("K.4 dot spell_id=%d tick_damage=%d hp=%d->%d final_damage=false" % [int(k4.get("spell_id", 0)), int(k4.get("tick_damage", 0)), int(k4.get("hp_before", 0)), int(k4.get("hp_after_lab_tick", 0))])
	lines.append("K.5 observed_intents=%d spawn=false counts=%s" % [int(k5.get("observed_intent_count", 0)), str(k5.get("intent_counts", {}))])
	lines.append("Next: compare all K lab observations with live OpenDAoC server packets before enabling any real runtime authority.")
	return "\n".join(lines) + "\n"

func export_opendaoc_p0_handler_report_json(path: String = OPENDAOC_P0_HANDLERS_JSON_PATH) -> Dictionary:
	if last_opendaoc_p0_report.is_empty():
		last_opendaoc_p0_report = {"ok": false, "checkpoint": "P1_18F_OPENDAOC_P0_HANDLERS", "status": "no_report_built"}
	return _write_text(path, JSON.stringify(last_opendaoc_p0_report, "\t"))

func export_opendaoc_p0_handler_report_text(path: String = OPENDAOC_P0_HANDLERS_TEXT_PATH) -> Dictionary:
	if last_opendaoc_p0_report.is_empty():
		last_opendaoc_p0_report = {"ok": false, "checkpoint": "P1_18F_OPENDAOC_P0_HANDLERS", "status": "no_report_built"}
	return _write_text(path, build_opendaoc_p0_handler_text_report(last_opendaoc_p0_report))

func build_opendaoc_p0_handler_text_report(report: Dictionary = {}) -> String:
	var r: Dictionary = report if not report.is_empty() else last_opendaoc_p0_report
	var lines: Array = []
	lines.append("P1-18F OpenDAoC P0 spell handlers")
	lines.append("ok=%s status=%s checkpoint=%s" % [str(r.get("ok", false)), str(r.get("status", "")), str(r.get("checkpoint", ""))])
	lines.append("total=%d supported=%d unsupported=%d ratio=%.1f%%" % [int(r.get("total_spell_count", 0)), int(r.get("supported_spell_count", 0)), int(r.get("unsupported_spell_count", 0)), float(r.get("supported_ratio", 0.0)) * 100.0])
	lines.append("runtime_enabled=false prediction_only=true damage_final=false server_authority=true")
	lines.append("p0_types=%d missing_registered=%s" % [(r.get("p0_registered_types", []) as Array).size(), str(r.get("missing_registered_types", []))])
	lines.append("cast_probe_count=%d ok_cast_probe_count=%d" % [int(r.get("cast_probe_count", 0)), int(r.get("ok_cast_probe_count", 0))])
	var casts: Array = r.get("cast_probes", []) as Array
	for item in casts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cast: Dictionary = item as Dictionary
		lines.append("- type=%s spell_id=%d ok=%s mech=%s handler=%s delta=%+d damage=%d effects=%s" % [str(cast.get("spell_type", "")), int(cast.get("spell_id", 0)), str(cast.get("ok", false)), str(cast.get("mechanism", "")), str(cast.get("handler_family", "")), int(cast.get("hp_delta_predicted", 0)), int(cast.get("damage", 0)), str(cast.get("effect_types", []))])
	lines.append("Next: compare P0 prediction effects against live OpenDAoC logs before promoting formulas.")
	return "\n".join(lines) + "\n"

func _write_text(path: String, text: String) -> Dictionary:
	var dir_path: String = path.get_base_dir()
	if dir_path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "path": path, "error": str(FileAccess.get_open_error())}
	f.store_string(text)
	f.close()
	return {"ok": true, "path": path, "bytes": text.to_utf8_buffer().size()}
