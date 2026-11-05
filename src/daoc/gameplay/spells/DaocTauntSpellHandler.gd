extends DaocDirectDamageSpellHandler
class_name DaocTauntSpellHandler

## P1-109 — Taunt et StyleTaunt, fideles a DOL.
##   TauntSpellHandler : des degats de sort ordinaires, PUIS, si la cible est
##   un PNJ et Value > 0, max(1, Value x niveau du lanceur x 0,1) points
##   d aggro ajoutes au lanceur (AddToAggroList). Une cible en incantation est
##   interrompue.
##   StyleTaunt (proc de style) : jamais resiste, pas de degats propres ;
##   l aggro vaut degats du dernier coup x Value — negatif pour un detaunt.
## L aggro est un effet immediat « aggro_add » que l arbitre local applique a
## son registre (DaocLocalServer.add_aggro).


func mechanism_id() -> String:
	return spell.spell_type if spell != null else "Taunt"


static func taunt_aggro(value: float, caster_level: int) -> int:
	if value <= 0.0:
		return 0
	return maxi(1, int(value * float(caster_level) * 0.1))


static func style_taunt_aggro(value: float, last_damage: int) -> int:
	return int(round(float(last_damage) * value))


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	if caster == null or target == null or not target.is_alive or spell == null:
		var empty = DaocCombatResult.new()
		empty.ok = false
		empty.mechanism = mechanism_id()
		empty.messages = ["invalid or dead target"]
		empty.guardrails = DaocGameplayAuthority.result_guard()
		return empty.to_dict()
	var is_style := spell.spell_type == "StyleTaunt"
	var result: DaocCombatResult
	var aggro := 0
	if is_style:
		result = DaocCombatResult.new()
		result.mechanism = mechanism_id()
		result.guardrails = DaocGameplayAuthority.result_guard()
		aggro = style_taunt_aggro(spell.value, int(options.get("last_damage", 0)))
		result.messages = ["%s %s %s (aggro %+d)." % [spell.name, "taunts" if aggro >= 0 else "detaunts", target.name, aggro]]
	else:
		var ad := calculate_damage_to_target(caster, target, options)
		if bool(options.get("apply_to_target", false)):
			target.change_health(-ad.total_damage())
		result = DaocCombatResult.from_attack(mechanism_id(), ad, ["%s hits %s for %d %s damage." % [spell.name, target.name, ad.damage, ad.damage_type]])
		aggro = taunt_aggro(spell.value, caster.level)
		if aggro > 0:
			result.messages.append("%s draws %s's attention (aggro +%d)." % [caster.name, target.name, aggro])
		if target.in_combat or bool(options.get("target_casting", false)):
			result.effects.append({"effect_type": "interrupt", "target_id": target.entity_id, "caster_id": caster.entity_id, "prediction_only": true, "server_authority": true})
	if not target.is_player and aggro != 0:
		result.effects.append({"effect_type": "aggro_add", "target_id": target.entity_id, "caster_id": caster.entity_id, "amount": aggro,
			"source_spell_id": spell.id, "prediction_only": true, "server_authority": true, "damage_final": false})
	return result.to_dict()
