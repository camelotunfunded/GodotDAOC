extends RefCounted
class_name DaocAttackData

var attacker: DaocCombatEntityState = null
var target: DaocCombatEntityState = null
var damage_type: String = "Natural"
var attack_type: String = "Unknown"
var attack_result: String = "Any"
var damage: int = 0
var base_damage: float = 0.0
var style_damage: int = 0
var base_damage_cap: float = 0.0
var critical_damage: int = 0
var critical_chance: int = 0
var interval: int = 0
var is_offhand: bool = false
var style: Dictionary = {}
var style_effects: Array = []
var causes_combat: bool = true
var parry_chance: float = 0.0
var evade_chance: float = 0.0
var block_chance: float = 0.0
var miss_chance: float = 0.0
var defense_penetration: float = 0.0
var armor_hit_location: String = "NOTSET"
var spell_id: int = 0
var spell_type: String = ""
var is_spell_resisted: bool = false
var modifier: int = 0
var animation_id: int = 0
var notes: Array = []

func is_melee_attack() -> bool:
	return DaocCombatEnums.is_melee_attack(attack_type)

func is_hit() -> bool:
	return attack_result in [DaocCombatEnums.RESULT_HIT_UNSTYLED, DaocCombatEnums.RESULT_HIT_STYLE]

func total_damage() -> int:
	return damage + critical_damage

func to_dict() -> Dictionary:
	return {
		"attacker": attacker.to_dict() if attacker != null else {},
		"target": target.to_dict() if target != null else {},
		"damage_type": damage_type,
		"attack_type": attack_type,
		"attack_result": attack_result,
		"damage": damage,
		"base_damage": base_damage,
		"style_damage": style_damage,
		"base_damage_cap": base_damage_cap,
		"critical_damage": critical_damage,
		"critical_chance": critical_chance,
		"interval": interval,
		"is_offhand": is_offhand,
		"style": style.duplicate(true),
		"causes_combat": causes_combat,
		"parry_chance": parry_chance,
		"evade_chance": evade_chance,
		"block_chance": block_chance,
		"miss_chance": miss_chance,
		"defense_penetration": defense_penetration,
		"armor_hit_location": armor_hit_location,
		"spell_id": spell_id,
		"spell_type": spell_type,
		"is_spell_resisted": is_spell_resisted,
		"modifier": modifier,
		"animation_id": animation_id,
		"notes": notes.duplicate(true),
	}
