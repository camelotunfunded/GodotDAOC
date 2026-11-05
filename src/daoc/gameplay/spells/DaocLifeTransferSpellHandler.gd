extends DaocSpellHandler
class_name DaocLifeTransferSpellHandler

## P1-109 — LifeTransfer, fidele a DOL (LifeTransferSpellHandler) : le
## lanceur donne de sa vie. Le transfert vaut MaxHealth du lanceur / 100 x
## |Value| ; il est borne pour ne jamais le tuer (si sa moitie atteint la vie
## du lanceur, transfert = (vie - 1) x 2) ; une cible malade ne recoit que la
## moitie ; on ne se transfere pas a soi-meme ; le lanceur perd la MOITIE de
## ce qui est soigne (m_caster.Health -= transferHeal >> 1). Sans soin, le
## cout de mana est reduit de moitie.


func mechanism_id() -> String:
	return "LifeTransfer"


static func transfer_amount(caster_max_health: int, caster_health: int, value: float) -> int:
	var transfer := int(float(caster_max_health) / 100.0 * absf(value))
	if transfer <= 0:
		return 0
	if (transfer >> 1) >= caster_health:
		transfer = (caster_health - 1) << 1
	return maxi(0, transfer)


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null:
		result.ok = false
		result.messages = ["missing caster or target"]
		return result.to_dict()
	if target.entity_id == caster.entity_id:
		result.ok = false
		result.messages = ["You cannot transfer life to yourself."]
		return result.to_dict()
	if not target.is_alive:
		result.ok = false
		result.messages = ["%s is dead!" % target.name]
		return result.to_dict()
	var transfer := transfer_amount(caster.max_health, caster.health, spell.value)
	if transfer <= 0:
		result.ok = false
		result.messages = ["You do not have enough health to transfer."]
		return result.to_dict()
	if target.is_diseased:
		transfer >>= 1
		result.messages.append("Your target is diseased!")
	var healed := mini(transfer, target.max_health - target.health)
	var caster_loss := transfer >> 1
	result.effects.append({"effect_type": "life_transfer", "target_id": target.entity_id, "caster_id": caster.entity_id, "amount": transfer,
		"healed": healed, "caster_loss": caster_loss, "source_spell_id": spell.id, "prediction_only": true, "server_authority": true, "damage_final": false})
	if bool(options.get("apply_to_target", false)):
		target.change_health(transfer)
		caster.change_health(-caster_loss)
	result.messages.append("%s transfers %d life to %s (%d healed, %s loses %d)." % [caster.name, transfer, target.name, healed, caster.name, caster_loss])
	return result.to_dict()
