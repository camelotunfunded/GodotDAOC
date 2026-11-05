extends DaocSpellHandler
class_name DaocDamageAddSpellHandler

func mechanism_id() -> String:
	return "DamageAdd"

func execute_from_attack(source_attack: DaocAttackData, effectiveness: float = 1.0, options: Dictionary = {}) -> Dictionary:
	var ad = DaocAttackData.new()
	ad.attacker = source_attack.attacker
	ad.target = source_attack.target
	ad.attack_type = DaocCombatEnums.ATTACK_SPELL
	ad.attack_result = DaocCombatEnums.RESULT_HIT_UNSTYLED
	ad.damage_type = spell.damage_type if spell != null else source_attack.damage_type
	ad.spell_id = spell.id if spell != null else 0
	ad.spell_type = mechanism_id()
	var damage = 0.0
	if spell != null and spell.damage > 0.0:
		damage = spell.damage * float(maxi(0, source_attack.interval)) * 0.001
	elif spell != null:
		damage = source_attack.base_damage * -spell.damage * 0.01
	var variance = DaocDamageVariance.deterministic_variance(0.75, 1.25, int(options.get("seed", 0)) + ad.spell_id)
	damage *= variance * effectiveness
	ad.base_damage = damage
	ad.base_damage_cap = source_attack.base_damage_cap
	if source_attack.base_damage_cap > 0.0:
		damage = minf(damage, source_attack.base_damage_cap)
	ad.damage = int(floor(damage))
	ad.notes.append({"source": "DamageAddAndShield.cs", "clamped_to_base_damage_cap": source_attack.base_damage_cap > 0.0})
	return DaocCombatResult.from_attack(mechanism_id(), ad, ["damage add predicted +%d" % ad.damage]).to_dict()
