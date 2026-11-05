extends DaocDirectDamageSpellHandler
class_name DaocDirectDamageWithDebuffSpellHandler

## P1-18F — prediction-only DD + debuff alias.
## Hit calculation reuses DirectDamage; debuff is surfaced as a non-authoritative effect.

func mechanism_id() -> String:
	return "DirectDamageWithDebuff"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var r: Dictionary = super.execute(caster, target, options)
	var effects: Array = r.get("effects", []) as Array
	effects.append({
		"effect_type": "debuff",
		"debuff_type": "resist_or_stat_debuff",
		"spell_type": spell.spell_type if spell != null else "DirectDamageWithDebuff",
		"damage_type": spell.damage_type if spell != null else "",
		"value_percent": spell.value if spell != null else 0.0,
		"duration": spell.duration if spell != null else 0,
		"effect_group": spell.effect_group if spell != null else 0,
		"prediction_only": true,
		"server_authority": true,
	})
	r["effects"] = effects
	r["mechanism"] = mechanism_id()
	return r
