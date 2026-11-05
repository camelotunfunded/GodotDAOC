extends DaocDirectDamageSpellHandler
class_name DaocDamageSpeedDecreaseSpellHandler

func mechanism_id() -> String:
	return "DamageSpeedDecrease"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var r: Dictionary = super.execute(caster, target, options)
	var effects: Array = r.get("effects", []) as Array
	effects.append({
		"effect_type": "speed_decrease",
		"value_percent": spell.value if spell != null else 0.0,
		"duration": spell.duration if spell != null else 0,
		"is_dual_component_spell": true,
	})
	if spell != null and spell.life_drain_return != 0:
		var ad: Dictionary = r.get("attack_data", {}) as Dictionary
		var heal = int((int(ad.get("damage", 0)) + int(ad.get("critical_damage", 0))) * spell.life_drain_return / 100.0)
		if caster != null and caster.is_diseased:
			heal = heal >> 1
		effects.append({"effect_type": "life_drain_return", "heal": heal, "percent": spell.life_drain_return})
	r["effects"] = effects
	r["mechanism"] = mechanism_id()
	return r
