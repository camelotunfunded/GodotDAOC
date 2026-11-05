extends DaocSpellHandler
class_name DaocDirectDamageSpellHandler

func mechanism_id() -> String:
	return "DirectDamage"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var messages: Array = []
	if caster == null or target == null or not target.is_alive:
		var empty = DaocCombatResult.new()
		empty.ok = false
		empty.mechanism = mechanism_id()
		empty.messages = ["invalid or dead target"]
		empty.guardrails = DaocGameplayAuthority.result_guard()
		return empty.to_dict()
	var ad = calculate_damage_to_target(caster, target, options)
	messages.append("%s hits %s for %d %s damage." % [spell.name, target.name, ad.damage, ad.damage_type])
	if ad.critical_damage > 0:
		messages.append("Critical spell damage +%d." % ad.critical_damage)
	if bool(options.get("apply_to_target", false)):
		target.change_health(-ad.total_damage())
	return DaocCombatResult.from_attack(mechanism_id(), ad, messages).to_dict()
