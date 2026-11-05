extends DaocDirectDamageSpellHandler
class_name DaocLifeDrainSpellHandler

## P1-18F — prediction-only Lifedrain.
## Uses DirectDamage path for the hit, then reports a heal return effect.

func mechanism_id() -> String:
	return "Lifedrain"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var r: Dictionary = super.execute(caster, target, options)
	var effects: Array = r.get("effects", []) as Array
	var ad: Dictionary = r.get("attack_data", {}) as Dictionary
	var damage_done: int = int(ad.get("damage", 0)) + int(ad.get("critical_damage", 0))
	var heal_percent: float = absf(spell.value if spell != null else 0.0)
	if heal_percent <= 0.0:
		heal_percent = 50.0
	var heal_amount: int = int(floor(float(damage_done) * heal_percent * 0.01))
	var disease_halved: bool = caster != null and caster.is_diseased
	if disease_halved:
		heal_amount = heal_amount >> 1
	var effective: int = heal_amount
	if caster != null:
		effective = mini(heal_amount, caster.max_health - caster.health)
		if bool(options.get("apply_to_target", false)):
			caster.change_health(effective)
	effects.append({
		"effect_type": "life_drain_return",
		"heal": heal_amount,
		"effective_heal": effective,
		"percent": heal_percent,
		"disease_halved": disease_halved,
		"prediction_only": true,
		"server_authority": true,
	})
	r["effects"] = effects
	r["mechanism"] = mechanism_id()
	return r
