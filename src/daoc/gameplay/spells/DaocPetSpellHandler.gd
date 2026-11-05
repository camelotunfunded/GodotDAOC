extends DaocSpellHandler
class_name DaocPetSpellHandler

## P1-18J — prediction-only pet/summon/charm intent model.
## This never creates, moves, charms or spawns a runtime entity.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "PetIntent"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and spell != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if spell == null:
		result.messages = ["missing spell"]
		return result.to_dict()
	var intent_kind: String = _intent_kind_for_spell_type(spell.spell_type)
	result.effects.append({
		"effect_type": "pet_summon_intent",
		"intent_kind": intent_kind,
		"source_spell_id": spell.id,
		"spell_name": spell.name,
		"spell_type": spell.spell_type,
		"caster_id": caster.entity_id if caster != null else 0,
		"target_id": target.entity_id if target != null else 0,
		"duration": spell.duration,
		"frequency": spell.frequency,
		"remaining_duration": spell.duration,
		"effect_group": spell.effect_group,
		"effect_category": "pet_intent",
		"stacking_group": "pet:%s" % spell.spell_type,
		"pet_family": _pet_family_for_spell_type(spell.spell_type),
		"requires_server_entity": true,
		"runtime_spawn_applied": false,
		"player_spawn_applied": false,
		"coordinate_frame_confirmed": false,
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
	})
	result.messages = ["%s records %s only; no pet entity is spawned client-side." % [spell.name, intent_kind]]
	return result.to_dict()

func _intent_kind_for_spell_type(type_name: String) -> String:
	if type_name == "Charm":
		return "charm_intent"
	if type_name.begins_with("SummonSiege"):
		return "siege_summon_intent"
	return "summon_intent"

func _pet_family_for_spell_type(type_name: String) -> String:
	if type_name.contains("Animist"):
		return "animist"
	if type_name.contains("Theurgist"):
		return "theurgist"
	if type_name.contains("Hunter"):
		return "hunter"
	if type_name.contains("Spirit"):
		return "spiritmaster"
	if type_name.contains("Underhill"):
		return "enchanter"
	if type_name.contains("Siege"):
		return "siege"
	if type_name == "Charm":
		return "charm"
	return "summon"
