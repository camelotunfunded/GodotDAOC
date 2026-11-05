extends DaocDamageAddSpellHandler
class_name DaocDamageShieldSpellHandler

func mechanism_id() -> String:
	return "DamageShield"

func execute_from_attack(source_attack: DaocAttackData, effectiveness: float = 1.0, options: Dictionary = {}) -> Dictionary:
	var swapped = DaocAttackData.new()
	swapped.attacker = source_attack.target
	swapped.target = source_attack.attacker
	swapped.attack_type = source_attack.attack_type
	swapped.attack_result = source_attack.attack_result
	swapped.base_damage = source_attack.base_damage
	swapped.base_damage_cap = source_attack.base_damage_cap
	swapped.interval = source_attack.interval
	var r: Dictionary = super.execute_from_attack(swapped, effectiveness, options)
	r["mechanism"] = mechanism_id()
	return r
