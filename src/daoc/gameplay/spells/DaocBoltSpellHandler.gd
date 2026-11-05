extends DaocSpellHandler
class_name DaocBoltSpellHandler

func mechanism_id() -> String:
	return "Bolt"

func modify_damage_with_target_resist(ad: DaocAttackData, raw_damage: float) -> float:
	if ad == null or ad.target == null:
		return raw_damage
	var magic_half = raw_damage * 0.5
	var physical_half = raw_damage * 0.5
	var resist = ad.target.get_resist_percent(spell.damage_type if spell != null else "Natural")
	magic_half = maxf(0.0, magic_half - magic_half * resist * 0.01)
	var blocked = false
	if ad.target.in_combat and ad.target.attacker_melee_count > 0:
		var block_chance = clampf(float(ad.target.attacker_melee_count) * 20.0, 0.0, 80.0)
		blocked = bool(ad.target.get_modified("ForceBoltBlock", 0.0) > 0.0) or block_chance >= 80.0
		ad.block_chance = block_chance
	if blocked:
		ad.attack_result = DaocCombatEnums.RESULT_BLOCKED
		physical_half = 0.0
		ad.notes.append("bolt physical half blocked")
	else:
		var armor_factor = maxf(1.0, ad.target.get_modified("ArmorFactor", 100.0))
		var fake_weapon_skill = maxf(1.0, float(ad.attacker.level if ad.attacker != null else 1) * 2.5)
		physical_half = physical_half * clampf(fake_weapon_skill / armor_factor, 0.15, 1.25)
	ad.modifier = int(round((magic_half + physical_half) - raw_damage))
	return maxf(0.0, magic_half + physical_half)

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var ad = calculate_damage_to_target(caster, target, options)
	var distance = int(options.get("distance", 850))
	var ticks_to_target = distance * 1000 / 850
	ad.notes.append({"bolt_ticks_to_target": ticks_to_target, "projectile_speed_raw": 850, "source": "BoltSpellHandler.cs"})
	var r = DaocCombatResult.from_attack(mechanism_id(), ad, ["bolt prediction delay=%dms" % ticks_to_target])
	r.effects.append({"effect_type": "projectile", "client_effect": spell.client_effect if spell != null else 0, "delay_msec": ticks_to_target})
	return r.to_dict()
