extends DaocSpellHandler
class_name DaocHealSpellHandler

func mechanism_id() -> String:
	return "Heal"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or not target.is_alive or spell == null:
		result.ok = false
		result.messages = ["invalid heal target"]
		return result.to_dict()
	var amount = spell.value
	if amount < 0.0:
		amount = -amount * 0.01 * float(target.max_health)
	else:
		var bounds = DaocDamageVariance.spell_variance_bounds(caster, spell, spell_line)
		amount *= DaocDamageVariance.deterministic_variance(float(bounds.get("min", 1.0)), float(bounds.get("max", 1.0)), int(options.get("seed", 0)) + spell.id)
	if target.is_diseased:
		amount *= 0.5
	var effectiveness = 1.0 + caster.get_modified("HealingEffectiveness", 0.0) * 0.01
	amount *= effectiveness
	var crit_chance = caster.get_modified("CriticalHealHitChance", 0.0)
	var crit_pct = DaocDamageVariance.deterministic_crit_percent(crit_chance, int(options.get("seed", 0)) + 320, 1.0)
	var critical_amount = amount * crit_pct
	var final_amount = int(floor(amount + critical_amount))
	var effective = mini(final_amount, target.max_health - target.health)
	if bool(options.get("apply_to_target", false)):
		target.change_health(effective)
	result.effects.append({
		"effect_type": "heal",
		"amount": final_amount,
		"effective_amount": effective,
		"critical_amount": int(floor(critical_amount)),
		"disease_halved": target.is_diseased,
		"applied_to_lab_target": bool(options.get("apply_to_target", false)),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	})
	result.messages = ["%s heals %s for %d predicted HP." % [caster.name, target.name, effective]]
	return result.to_dict()
