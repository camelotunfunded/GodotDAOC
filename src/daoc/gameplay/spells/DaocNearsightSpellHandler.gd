extends DaocSpellHandler
class_name DaocNearsightSpellHandler

## P1-109 — Nearsight, fidele a DOL (NearsightSpellHandler, un
## ImmunityEffectSpellHandler) : pendant la duree, la portee des sorts ET des
## tirs de la cible est reduite de Value % (DebuffCategory SpellRange /
## ArcheryRange) ; un mez en cours est annule ; a l expiration, 60 s
## d immunite. Deux effets actifs de categorie « range », que l arbitre local
## applique dans son controle de portee (_complete_spell).

const IMMUNITY_MSEC := 60000


func mechanism_id() -> String:
	return "Nearsight"


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null or not target.is_alive:
		result.ok = false
		result.messages = ["invalid or dead target"]
		return result.to_dict()
	var percent := absf(spell.value)
	for stat in ["SpellRange", "ArcheryRange"]:
		result.effects.append({
			"effect_type": "nearsight", "effect_category": "range", "modifier_kind": "range_percent_delta", "modifier_stat": stat,
			"modifier_value": -percent, "is_debuff": true, "stacking_group": "Nearsight", "duration": spell.duration, "frequency": 0,
			"immunity_msec": IMMUNITY_MSEC, "source_spell_id": spell.id, "spell_name": spell.name, "spell_type": spell.spell_type,
			"caster_id": caster.entity_id, "target_id": target.entity_id, "prediction_only": true, "server_authority": true, "damage_final": false,
		})
	result.effects.append({"effect_type": "cure_state", "removes_effect_category": "Mesmerize", "target_id": target.entity_id})
	result.messages = ["%s : %s's ranged reach is reduced by %d%% for %d s." % [spell.name, target.name, int(percent), spell.duration / 1000]]
	return result.to_dict()
