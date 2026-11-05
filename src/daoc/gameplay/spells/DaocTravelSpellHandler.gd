extends DaocSpellHandler
class_name DaocTravelSpellHandler

## P1-108 puis P1-123 — les sorts de deplacement, fideles a OpenDAoC :
##   GatewayPersonalBind : refuse en mouvement (« You must be standing still to
##   use this item! ») ou en combat (« You have been in combat recently… ») ;
##   sinon MoveToBind — l'arbitre local renvoie le joueur a son point de lien.
##   UniPortal : sa destination est une ligne `teleport` donnee par le PNJ
##   teleporteur qui le construit ; lance seul, il n'a nulle part ou aller.


func mechanism_id() -> String:
	return spell.spell_type if spell != null else "TravelIntent"


func execute(caster: DaocCombatEntityState, _target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if spell == null or caster == null:
		result.ok = false
		result.messages = ["missing spell"]
		return result.to_dict()
	if spell.spell_type == "UniPortal":
		result.ok = false
		result.messages = ["%s : aucune destination (seul un teleporteur la donne)." % spell.name]
		return result.to_dict()
	if caster.is_moving:
		result.ok = false
		result.messages = ["You must be standing still to use this item!"]
		return result.to_dict()
	if caster.in_combat:
		result.ok = false
		result.messages = ["You have been in combat recently and cannot use this item!"]
		return result.to_dict()
	result.ok = true
	result.effects.append({"effect_type": "move_to_bind", "caster_id": caster.entity_id, "spell_name": spell.name})
	result.messages = ["%s vous ramene a votre point de lien." % spell.name]
	return result.to_dict()
