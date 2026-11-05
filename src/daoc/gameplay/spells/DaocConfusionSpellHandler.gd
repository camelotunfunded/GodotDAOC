extends DaocSpellHandler
class_name DaocConfusionSpellHandler

## P1-109 — Confusion, fidele a DOL (ConfusionSpellHandler) :
##   - sur un JOUEUR : Value < 0 ou Value % de chance -> interruption, et
##     l effet s annule aussitot (pas de duree) ;
##   - sur un PNJ : Value < 0 = toujours confus, sinon Value % de chance ;
##     confus, il lache sa cible et en prend une AU HASARD parmi ce qui
##     l entoure (1000 unites) ; Value < 0 lui fait attaquer aussi ses amis
##     (|Value| % de chance) ; l effet pulse toutes les 5 s et rechoisit ;
##     un pet de Theurgiste confus MEURT.
## Un effet actif « confusion » de categorie « control » que l arbitre local
## traduit dans le cerveau de la creature (retarget aleatoire).

const PULSE_MSEC := 5000
const RADIUS_RAW := 1000


func mechanism_id() -> String:
	return "Confusion"


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
	var always := spell.value < 0.0
	var chance := int(absf(spell.value))
	if target.is_player:
		var interrupted := always or roll < chance
		if interrupted:
			result.effects.append({"effect_type": "interrupt", "target_id": target.entity_id, "caster_id": caster.entity_id, "prediction_only": true, "server_authority": true})
		result.messages = ["%s : %s %s." % [spell.name, target.name, "is interrupted" if interrupted else "shrugs off the confusion"]]
		return result.to_dict()
	var confused := always or roll < chance
	if not confused:
		result.messages = ["%s : %s is not confused (%d%%)." % [spell.name, target.name, chance]]
		return result.to_dict()
	var attack_friends := always and ((roll * 7) % 100) < chance
	result.effects.append({
		"effect_type": "confusion", "effect_category": "control", "stacking_group": "Confusion", "duration": spell.duration,
		"frequency": PULSE_MSEC, "radius_raw": RADIUS_RAW, "attack_friends": attack_friends, "kills_theurgist_pet": true,
		"source_spell_id": spell.id, "spell_name": spell.name, "spell_type": spell.spell_type,
		"caster_id": caster.entity_id, "target_id": target.entity_id, "prediction_only": true, "server_authority": true, "damage_final": false,
	})
	result.messages = ["%s : %s is confused%s and picks a random target every 5 s for %d s." % [spell.name, target.name, " (may attack allies)" if attack_friends else "", spell.duration / 1000]]
	return result.to_dict()
