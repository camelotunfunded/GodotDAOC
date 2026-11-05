extends DaocDoTSpellHandler
class_name DaocDoTDiseaseProcSpellHandler

## P1-18H — prediction-only DoT/Disease/Proc active state.
## Proc and disease rows are represented as explicit effects; no final server state is applied.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "DoTDiseaseProc"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	if spell == null:
		return _invalid("missing spell")
	match spell.spell_type:
		"Disease":
			return _execute_disease(caster, target, options)
		"CurePoison", "CureDisease":
			return _execute_cure_state(caster, target, options)
		"OffensiveProc":
			return _execute_proc_state(caster, target, options)
		"ArcheryDoT", "StyleBleeding":
			return _execute_dot_family(caster, target, options)
		_:
			return _invalid("unsupported DoT/Disease/Proc type %s" % spell.spell_type)

func _execute_dot_family(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.execute(caster, target, options)
	result["mechanism"] = mechanism_id()
	var effects: Array = result.get("effects", []) as Array
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = item as Dictionary
		effect["source_spell_id"] = spell.id
		effect["spell_name"] = spell.name
		effect["spell_type"] = spell.spell_type
		effect["effect_category"] = "damage_over_time"
		effect["stacking_group"] = "dot:%s" % spell.spell_type
		effect["remaining_duration"] = spell.duration
		effect["prediction_only"] = true
		effect["server_authority"] = true
		effect["damage_final"] = false
	return result

func _execute_disease(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	result.effects.append(_base_effect(caster, target, "disease", "utility", "Disease", -absf(spell.value)))
	result.messages = ["%s predicts disease state on %s." % [spell.name, target.name if target != null else "target"]]
	return result.to_dict()

func _execute_proc_state(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	var effect: Dictionary = _base_effect(caster, target, "offensive_proc", "proc", spell.damage_type, absf(spell.value if spell.value != 0.0 else spell.damage))
	effect["triggers_from_attack"] = true
	effect["proc_damage_type"] = spell.damage_type
	result.effects.append(effect)
	result.messages = ["%s predicts offensive proc state; trigger and final damage remain server-authoritative." % spell.name]
	return result.to_dict()

func _execute_cure_state(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	var cure_kind: String = "poison" if spell.spell_type == "CurePoison" else "disease"
	var effect: Dictionary = _base_effect(caster, target, "cure_state", "cure", cure_kind, 0.0)
	effect["removes_effect_category"] = cure_kind
	effect["is_cure"] = true
	result.effects.append(effect)
	result.messages = ["%s predicts %s cure intent on %s." % [spell.name, cure_kind, target.name if target != null else "target"]]
	return result.to_dict()

func _base_effect(caster: DaocCombatEntityState, target: DaocCombatEntityState, effect_type: String, category: String, stat: String, value: float) -> Dictionary:
	return {
		"effect_type": effect_type,
		"source_spell_id": spell.id,
		"spell_name": spell.name,
		"spell_type": spell.spell_type,
		"caster_id": caster.entity_id if caster != null else 0,
		"target_id": target.entity_id if target != null else 0,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"remaining_duration": spell.duration,
		"effect_group": spell.effect_group,
		"effect_category": category,
		"stacking_group": "%s:%s" % [category, stat],
		"modifier_kind": effect_type,
		"modifier_stat": stat,
		"modifier_value": value,
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
	}

func _invalid(reason: String) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = false
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	result.messages = [reason]
	return result.to_dict()
