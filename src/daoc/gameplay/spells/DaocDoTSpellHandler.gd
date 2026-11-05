extends DaocSpellHandler
class_name DaocDoTSpellHandler

func mechanism_id() -> String:
	return "DamageOverTime"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var tick_count = 1
	if spell != null and spell.frequency > 0 and spell.duration > 0:
		tick_count = maxi(1, int(floor(float(spell.duration) / float(spell.frequency))))
	var ticks: Array = []
	var total = 0
	var crit_percent = -1.0
	for i in range(tick_count):
		var tick_opts = options.duplicate(true)
		tick_opts["seed"] = int(options.get("seed", 0)) + i * 13
		var ad = calculate_damage_to_target(caster, target, tick_opts)
		ad.causes_combat = i == 0
		if crit_percent < 0.0:
			crit_percent = 0.0
			ad.critical_chance = int(caster.get_modified("DebuffCriticalChance", 0.0)) if caster != null else 0
			crit_percent = DaocDamageVariance.deterministic_crit_percent(float(ad.critical_chance), int(options.get("seed", 0)) + 900, 1.0)
		ad.critical_damage = int(floor(float(ad.damage) * crit_percent))
		total += ad.total_damage()
		ticks.append(ad.to_dict())
	var result = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.effects.append({
		"effect_type": "dot",
		"duration": spell.duration if spell != null else 0,
		"frequency": spell.frequency if spell != null else 0,
		"tick_count": tick_count,
		"total_predicted_damage": total,
		"ticks": ticks,
	})
	result.messages = ["%s predicted DoT ticks=%d total=%d" % [spell.name if spell != null else "DoT", tick_count, total]]
	result.guardrails = DaocGameplayAuthority.result_guard()
	return result.to_dict()
