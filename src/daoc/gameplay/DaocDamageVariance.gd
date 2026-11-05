extends RefCounted
class_name DaocDamageVariance

static func spell_variance_bounds(caster: DaocCombatEntityState, spell: DaocSpellDef, line_spec: String = "") -> Dictionary:
	var min_v = 0.25
	var max_v = 1.25
	if caster == null or spell == null:
		return {"min": min_v, "max": max_v, "basis": "fallback"}
	if not caster.is_player:
		return {"min": 1.25, "max": 1.25, "basis": "npc_fixed_open_daoc"}
	var spec_name = line_spec if line_spec != "" else spell.spec_line
	var spec_level = caster.get_spec_level(spec_name, 1.0)
	if spell.level > 0:
		min_v += (maxf(1.0, spec_level) - 1.0) / float(spell.level)
		min_v = minf(min_v, 1.25)
	return {"min": min_v, "max": max_v, "basis": "OpenDAoC SpellHandler/HealSpellHandler-inspired"}

static func deterministic_variance(min_v: float, max_v: float, seed_value: int = 0) -> float:
	if max_v <= min_v:
		return min_v
	var n = abs(seed_value * 1103515245 + 12345) % 10000
	return min_v + (float(n) / 9999.0) * (max_v - min_v)

static func deterministic_crit_percent(chance_percent: float, seed_value: int = 0, max_player_crit: float = 1.0) -> float:
	var roll = abs(seed_value * 1664525 + 1013904223) % 10000
	if float(roll) / 100.0 >= chance_percent:
		return 0.0
	var roll2 = abs(seed_value * 22695477 + 1) % 10000
	return 0.1 + (float(roll2) / 9999.0) * max(0.0, max_player_crit - 0.1)
