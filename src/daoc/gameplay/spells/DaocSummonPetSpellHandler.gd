extends DaocSpellHandler
class_name DaocSummonPetSpellHandler

## P1-124 — les familiers, fideles a OpenDAoC. L'arbitre local fait vivre le
## familier (DaocLocalServer.summon_pet / _advance_pets) ; ce gestionnaire ne
## fait que decrire ce que le sort demande :
##   Summon* (SummonSpellHandler) : modele npctemplate = LifeDrainReturn ;
##     niveau = Damage s'il est positif, sinon niveau du lanceur x -Damage %,
##     plafonne par Value, au moins 1 (GameSummonedPet.SetPetLevel) ; le sort
##     ne se resiste pas ; la duree est celle du sort (0 = permanent).
##     SummonNoveltyPet : pacifique, « <lanceur>'s <nom> », suit a 100.
##   PetSpell : le FAMILIER lance le sous-sort SubSpellID sur la cible du maitre.
##   TurretsRelease : tue les familiers du lanceur dans Radius autour de la cible.
##   PetConversion : libere la cible (ou son familier) et rend Value % de ses
##     points de vie en mana au lanceur.
##   PowerTransferPet : donne min(Value, mana du lanceur) de mana a la cible.
##   PowerDrainPet : degats directs, puis Damage x LifeDrainReturn % en mana.
##   FacilitatePainworking : le familier ne peut plus etre interrompu.

const SUMMON_PREFIX := "Summon"


func mechanism_id() -> String:
	return spell.spell_type if spell != null else "SummonPet"


static func pet_level(caster_level: int, spell_damage: float, spell_value: float) -> int:
	var level := 0
	if spell_damage >= 0.0:
		level = int(spell_damage)
	else:
		level = int(float(caster_level) * spell_damage * -0.01)
	if spell_value > 0.0 and level > int(spell_value):
		level = int(spell_value)
	return maxi(1, level)


func calculate_to_hit_chance(_caster: DaocCombatEntityState, _target: DaocCombatEntityState) -> float:
	# SummonSpellHandler.CalculateSpellResistChance rend 0.
	return 1000.0


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or spell == null:
		result.ok = false
		result.messages = ["missing caster or spell"]
		return result.to_dict()
	result.ok = true
	var type := spell.spell_type
	if type.begins_with(SUMMON_PREFIX):
		result.effects.append({"effect_type": "summon_pet", "template_id": spell.life_drain_return,
			"pet_level": pet_level(caster.level, spell.damage, spell.value), "novelty": type == "SummonNoveltyPet",
			"duration": spell.duration, "spell_name": spell.name, "spell_type": type, "caster_id": caster.entity_id})
		result.messages = ["%s : un familier repond a l'appel." % spell.name]
		return result.to_dict()
	match type:
		"PetSpell":
			result.effects.append({"effect_type": "pet_cast", "sub_spell_id": spell.sub_spell_id,
				"target_id": target.entity_id if target != null else -1, "caster_id": caster.entity_id})
			result.messages = ["%s : votre familier lance le sort %d." % [spell.name, spell.sub_spell_id]]
		"TurretsRelease":
			result.effects.append({"effect_type": "pets_release_area", "radius": spell.radius,
				"target_id": target.entity_id if target != null else caster.entity_id, "caster_id": caster.entity_id})
			result.messages = ["%s : vos tourelles se dissipent." % spell.name]
		"PetConversion":
			result.effects.append({"effect_type": "pet_conversion", "percent": spell.value, "radius": spell.radius,
				"target_id": target.entity_id if target != null else -1, "caster_id": caster.entity_id})
			result.messages = ["%s : le familier est converti en energie." % spell.name]
		"PowerTransferPet":
			if target == null or target.entity_id == caster.entity_id:
				result.ok = false
				result.messages = ["You cannot transfer power to yourself!"]
				return result.to_dict()
			var transfer := mini(int(spell.value), caster.mana)
			var healed := mini(transfer, maxi(0, target.max_mana - target.mana))
			caster.mana -= healed
			target.mana += healed
			result.messages = ["You transfer %d power to %s!" % [healed, target.name] if healed > 0 else "%s is at full power already!" % target.name]
		"PowerDrainPet":
			var dd := DaocDirectDamageSpellHandler.new()
			dd.spell = spell
			dd.spell_line = spell_line
			var damage_result: Dictionary = dd.execute(caster, target, options)
			var dealt := 0
			for key in ["damage", "critical_damage"]:
				dealt += int((damage_result.get("attack", {}) as Dictionary).get(key, damage_result.get(key, 0)))
			var gain := mini(dealt * spell.life_drain_return / 100, maxi(0, caster.max_mana - caster.mana))
			caster.mana += gain
			damage_result["messages"] = (damage_result.get("messages", []) as Array) + ["Vous gagnez %d de mana." % gain]
			return damage_result
		"FacilitatePainworking":
			result.effects.append({"effect_type": "interrupt_immune", "effect_category": "utility", "duration": spell.duration,
				"frequency": 0, "stacking_group": "FacilitatePainworking", "spell_name": spell.name, "spell_type": type,
				"caster_id": caster.entity_id, "target_id": target.entity_id if target != null else caster.entity_id})
			result.messages = ["%s : le familier ne peut plus etre interrompu." % spell.name]
		_:
			result.ok = false
			result.messages = ["type de familier %s non porte" % type]
	return result.to_dict()
