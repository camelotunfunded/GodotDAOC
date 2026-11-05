extends DaocSpellHandler
class_name DaocCrowdControlSpellHandler

## P1-18F — prediction-only crowd control handler.
## Covers OpenDAoC P0 CC Types without granting client authority.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "CrowdControl"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null:
		result.ok = false
		result.messages = ["invalid crowd-control target"]
		return result.to_dict()
	var cc: Dictionary = _build_crowd_control_effect(caster, target, options)
	result.ok = true
	result.effects.append(cc)
	result.messages = ["%s applies %s to %s for %d predicted seconds." % [spell.name, str(cc.get("cc_type", "crowd_control")), target.name, int(cc.get("duration", 0))]]
	return result.to_dict()

func _build_crowd_control_effect(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var type_name: String = spell.spell_type if spell != null else "CrowdControl"
	var lower: String = type_name.to_lower()
	var duration_value: int = spell.duration if spell != null else 0
	var effect: Dictionary = {
		"effect_type": "crowd_control",
		"cc_type": _cc_kind(type_name),
		"spell_type": type_name,
		"spell_id": spell.id if spell != null else 0,
		"source_name": caster.name if caster != null else "",
		"target_name": target.name if target != null else "",
		"duration": duration_value,
		"value_percent": spell.value if spell != null else 0.0,
		"frequency": spell.frequency if spell != null else 0,
		"effect_group": spell.effect_group if spell != null else 0,
		"break_on_damage": lower.contains("mez") or lower.contains("mesmer"),
		"prevents_movement": lower.contains("stun") or lower.contains("mez") or lower.contains("mesmer"),
		"prevents_action": lower.contains("stun") or lower.contains("mez") or lower.contains("mesmer"),
		"unbreakable": lower.contains("unbreakable"),
		"cure": lower.contains("cure"),
		"prediction_only": true,
		"server_authority": true,
	}
	if lower.contains("speeddecrease"):
		effect["snare_percent"] = absf(spell.value if spell != null else 0.0)
		effect["prevents_movement"] = false
	if lower.contains("durationbuff"):
		effect["duration_modifier"] = spell.value if spell != null else 0.0
		effect["prevents_movement"] = false
		effect["prevents_action"] = false
	return effect

func _cc_kind(type_name: String) -> String:
	var lower: String = type_name.to_lower()
	if lower.contains("curemezz"):
		return "cure_mez"
	if lower.contains("mesmer") or lower.contains("mezz") or lower.contains("mez"):
		return "mez"
	if lower.contains("stun"):
		return "stun"
	if lower.contains("speeddecrease"):
		return "speed_decrease"
	return "crowd_control"
