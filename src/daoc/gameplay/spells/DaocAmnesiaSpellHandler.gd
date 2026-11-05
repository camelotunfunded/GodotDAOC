extends DaocSpellHandler
class_name DaocAmnesiaSpellHandler

## P1-109 — Amnesia, fidele a DOL (AmnesiaSpellHandler) :
##   - la cible perd son style prepare et son incantation en cours (meme sous
##     MoC / QuickCast) ;
##   - une cible mezzee est reveillee (le mez est annule) et rien d autre ;
##   - un PNJ oublie TOUT le monde avec AmnesiaChance % de chance
##     (ClearAggroList) — c est le point du sort : le monstre lache sa cible.
## Un effet immediat, sans duree : « amnesia » pour l arbitre local, qui
## efface son registre d aggro et renvoie la creature au repos.


func mechanism_id() -> String:
	return "Amnesia"


func amnesia_chance() -> int:
	if spell == null:
		return 100
	var raw: Dictionary = spell.raw
	return int(raw.get("AmnesiaChance", raw.get("amnesia_chance", 100)))


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null or not target.is_alive:
		result.ok = false
		result.messages = ["invalid or dead target"]
		return result.to_dict()
	var seed := int(options.get("seed", 0)) + spell.id + target.entity_id
	var roll := seed % 100
	var forgets := roll < amnesia_chance()
	result.effects.append({"effect_type": "cancel_cast", "target_id": target.entity_id, "caster_id": caster.entity_id, "clears_pending_style": true,
		"prediction_only": true, "server_authority": true, "damage_final": false})
	if bool(options.get("target_mesmerized", false)):
		result.effects.append({"effect_type": "cure_state", "removes_effect_category": "Mesmerize", "target_id": target.entity_id})
		result.messages = ["%s wakes %s from its mesmerize." % [spell.name, target.name]]
		return result.to_dict()
	if not target.is_player:
		result.effects.append({"effect_type": "amnesia", "target_id": target.entity_id, "caster_id": caster.entity_id, "forgets": forgets,
			"chance": amnesia_chance(), "roll": roll, "prediction_only": true, "server_authority": true, "damage_final": false})
		result.messages = ["%s : %s %s." % [spell.name, target.name, "forgets everyone" if forgets else "resists the amnesia (%d%%)" % amnesia_chance()]]
	else:
		result.messages = ["%s : %s's mind goes blank (cast and style lost)." % [spell.name, target.name]]
	return result.to_dict()
