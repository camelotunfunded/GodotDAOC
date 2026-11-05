extends DaocHealSpellHandler
class_name DaocHealOrResurrectSpellHandler

## P1-18F — prediction-only P0 heal/support/resurrect family.
## Keeps non-HP support effects explicit instead of pretending they are final server state.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "HealOrResurrect"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	if spell == null:
		return _invalid("missing spell")
	match spell.spell_type:
		"Resurrect":
			return _execute_resurrect(caster, target, options)
		"HealOverTime", "HealthRegenBuff":
			return _execute_heal_over_time(caster, target, options)
		"PowerHeal":
			return _execute_resource_restore(caster, target, "power", options)
		"EnduranceHeal", "SavageEnduranceHeal":
			return _execute_resource_restore(caster, target, "endurance", options)
		"PowerHealthEnduranceRegenBuff":
			return _execute_tri_regen(caster, target, options)
		"CombatHeal", "SpreadHeal", "LifeTransfer":
			# P1-108 : LifeTransfer (DOL LifeTransferSpellHandler) soigne la cible
			# de spell.value en prenant la meme somme au lanceur ; le soin est la
			# part portee ici, le cout au lanceur reste au serveur.
			var r: Dictionary = super.execute(caster, target, options)
			r["mechanism"] = mechanism_id()
			return r
		_:
			return _execute_support_effect(caster, target, options)

func _invalid(reason: String) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = false
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	result.messages = [reason]
	return result.to_dict()

func _execute_resurrect(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	var percent: float = spell.value
	if percent <= 0.0:
		percent = 10.0
	var resurrect_health: int = int(floor(float(target.max_health if target != null else 0) * percent * 0.01))
	result.effects.append({
		"effect_type": "resurrect",
		"health_percent": percent,
		"predicted_health": resurrect_health,
		"requires_dead_target": true,
		"duration": spell.duration,
		"prediction_only": true,
		"server_authority": true,
	})
	result.messages = ["%s predicts resurrection for %s at %d HP." % [spell.name, target.name if target != null else "target", resurrect_health]]
	return result.to_dict()

func _execute_heal_over_time(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	var tick_count: int = _tick_count()
	var per_tick: int = int(floor(absf(spell.value)))
	if per_tick <= 0:
		per_tick = int(floor(absf(spell.damage)))
	var total_heal: int = per_tick * maxi(tick_count, 1)
	var effective: int = total_heal
	if target != null:
		effective = mini(total_heal, target.max_health - target.health)
		if bool(options.get("apply_to_target", false)) and not bool(options.get("defer_periodic", false)):
			target.change_health(effective)
	result.effects.append({
		"effect_type": "heal_over_time",
		"per_tick": per_tick,
		"tick_count": maxi(tick_count, 1),
		"total_predicted_heal": total_heal,
		"effective_amount": effective,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"prediction_only": true,
		"server_authority": true,
	})
	result.messages = ["%s predicts %d HP over time on %s." % [spell.name, effective, target.name if target != null else "target"]]
	return result.to_dict()

func _execute_resource_restore(caster: DaocCombatEntityState, target: DaocCombatEntityState, resource_name: String, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	var amount: int = int(floor(absf(spell.value)))
	result.effects.append({
		"effect_type": "resource_restore",
		"resource": resource_name,
		"amount": amount,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"prediction_only": true,
		"server_authority": true,
	})
	result.messages = ["%s predicts %s restore %d on %s." % [spell.name, resource_name, amount, target.name if target != null else "target"]]
	return result.to_dict()

func _execute_tri_regen(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	result.effects.append({
		"effect_type": "tri_regen_buff",
		"health_value": absf(spell.value),
		"power_value": absf(spell.value),
		"endurance_value": absf(spell.value),
		"duration": spell.duration,
		"frequency": spell.frequency,
		"prediction_only": true,
		"server_authority": true,
	})
	result.messages = ["%s predicts health/power/endurance regeneration." % spell.name]
	return result.to_dict()

func _execute_support_effect(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	result.effects.append({
		"effect_type": "support_buff_or_debuff",
		"spell_type": spell.spell_type,
		"value": spell.value,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"effect_group": spell.effect_group,
		"prediction_only": true,
		"server_authority": true,
	})
	result.messages = ["%s predicts support effect %s on %s." % [spell.name, spell.spell_type, target.name if target != null else "target"]]
	return result.to_dict()

func _tick_count() -> int:
	if spell == null:
		return 1
	if spell.frequency <= 0:
		return 1
	return maxi(1, int(ceil(float(spell.duration) / float(spell.frequency))))
