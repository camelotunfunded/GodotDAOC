extends DaocSpellHandler
class_name DaocGenericDamageEffectSpellHandler

## P1-18I — prediction-only generic damage effect model.
## Bombers, turrets and cone rows are catalogued as pending damage effects, not final combat.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "GenericDamageEffect"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null and spell != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if spell == null:
		result.messages = ["missing spell"]
		return result.to_dict()
	var effect: Dictionary = {
		"effect_type": _effect_type_for_spell_type(spell.spell_type),
		"source_spell_id": spell.id,
		"spell_name": spell.name,
		"spell_type": spell.spell_type,
		"caster_id": caster.entity_id if caster != null else 0,
		"target_id": target.entity_id if target != null else 0,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"remaining_duration": spell.duration,
		"effect_group": spell.effect_group,
		"effect_category": "generic_damage",
		"stacking_group": "generic_damage:%s" % spell.spell_type,
		"damage_type": spell.damage_type,
		"base_value": spell.value,
		"base_damage": spell.damage,
		"radius": spell.radius,
		"range": spell.range,
		"requires_server_targeting": true,
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
	}
	if bool(options.get("include_prediction_damage", true)) and spell.damage != 0.0:
		var ad: DaocAttackData = calculate_damage_to_target(caster, target, options)
		effect["attack_data_preview"] = ad.to_dict()
	result.effects.append(effect)
	result.messages = ["%s predicts %s damage effect metadata; final hit and damage remain server-authoritative." % [spell.name, spell.spell_type]]
	return result.to_dict()

func _effect_type_for_spell_type(type_name: String) -> String:
	if type_name == "Bomber":
		return "bomber_damage_intent"
	if type_name == "TurretPBAoE":
		return "turret_pbaoe_damage_intent"
	if type_name == "FrontalPulseConeDD":
		return "frontal_cone_damage_intent"
	return "generic_damage_intent"
