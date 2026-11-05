extends DaocSpellHandler
class_name DaocFaithfulEffectSpellHandler

## P1-123 — les derniers types « routes » de P1-108, portes d'OpenDAoC :
##   PreventFlight            ralentit de Value % (StatDebuffECSEffect -> MaxSpeed)
##   FatigueConsumptionDebuff +Value % d'endurance depensee (SingleStatDebuff)
##   RvrResurrectionIllness   -Value % d'efficacite (ResurrectionIllnessECSEffect)
##   PiercingMagic            +Value au toucher des sorts du lanceur
##                            (SpellHandler.CalculateToHitChance)
##   CureNearsight            retire Nearsight et Silence (CureNearsight.cs)
##   MultiTarget, NaturesShield, StyleRange : ce sont des procs de STYLE ;
##   lances seuls ils ne font rien (SpellHandler nu), leur effet vit dans le
##   coup de style (DaocLocalServer._fire_style_procs / natures_shield_*).

const STYLE_ONLY := ["MultiTarget", "NaturesShield", "StyleRange"]


func mechanism_id() -> String:
	return spell.spell_type if spell != null else "FaithfulEffect"


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null or not target.is_alive:
		result.ok = false
		result.messages = ["invalid or dead target"]
		return result.to_dict()
	result.ok = true
	var value := absf(spell.value)
	match spell.spell_type:
		"PreventFlight":
			result.effects.append(_effect(caster, target, "speed_decrease", "movement", "", 0.0, {"snare_percent": value, "stacking_group": ""}))
			result.messages = ["%s : %s est ralenti de %d %%." % [spell.name, target.name, int(value)]]
		"FatigueConsumptionDebuff":
			result.effects.append(_effect(caster, target, "stat_debuff", "stats", "FatigueConsumption", value, {"is_debuff": true}))
			result.messages = ["%s : %s depense %d %% d'endurance en plus." % [spell.name, target.name, int(value)]]
		"RvrResurrectionIllness", "PveResurrectionIllness":
			result.effects.append(_effect(caster, target, "resurrection_illness", "stats", "Effectiveness", -value, {"is_debuff": true}))
			result.messages = ["%s : efficacite de %s reduite de %d %%." % [spell.name, target.name, int(value)]]
		"PiercingMagic":
			result.effects.append(_effect(caster, target, "piercing_magic", "stats", "PiercingMagic", value, {}))
			result.messages = ["%s : +%d %% au toucher des sorts." % [spell.name, int(value)]]
		"CureNearsight":
			for category in ["nearsight", "silence"]:
				result.effects.append({"effect_type": "cure_state", "removes_effect_category": category, "target_id": target.entity_id})
			result.messages = ["%s : la myopie et le silence de %s sont dissipes." % [spell.name, target.name]]
		_:
			if STYLE_ONLY.has(spell.spell_type):
				result.messages = ["%s n'agit qu'au sein d'un style." % spell.name]
			else:
				result.ok = false
				result.messages = ["type %s non porte" % spell.spell_type]
	return result.to_dict()


func _effect(caster: DaocCombatEntityState, target: DaocCombatEntityState, effect_type: String, category: String,
		stat: String, amount: float, extra: Dictionary) -> Dictionary:
	var out := {
		"effect_type": effect_type, "effect_category": category, "modifier_stat": stat, "modifier_value": amount,
		"duration": spell.duration, "frequency": 0, "effect_group": spell.effect_group,
		"stacking_group": spell.spell_type if spell.effect_group == 0 else "",
		"source_spell_id": spell.id, "spell_name": spell.name, "spell_type": spell.spell_type,
		"caster_id": caster.entity_id, "target_id": target.entity_id,
	}
	# PreventFlight : HasConflictingEffectWith rend faux, deux lancers coexistent.
	out.merge(extra, true)
	return out
