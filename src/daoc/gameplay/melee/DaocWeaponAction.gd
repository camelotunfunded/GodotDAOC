extends RefCounted
class_name DaocWeaponAction

var owner: DaocCombatEntityState = null
var target: DaocCombatEntityState = null
var attack_weapon: Dictionary = {}
var left_weapon: Dictionary = {}
var effectiveness: float = 1.0
var interval: int = 0
var style: DaocStyleDef = null
var ranged_attack_type: String = ""
var ammo: Dictionary = {}
var active_weapon_slot: String = "Standard"
var extra_swing_count: int = 0

func setup_melee(p_owner: DaocCombatEntityState, p_target: DaocCombatEntityState, p_weapon: Dictionary, p_left_weapon: Dictionary = {}, p_style: DaocStyleDef = null, p_interval: int = 0) -> DaocWeaponAction:
	owner = p_owner
	target = p_target
	attack_weapon = p_weapon.duplicate(true)
	left_weapon = p_left_weapon.duplicate(true)
	style = p_style
	interval = p_interval
	active_weapon_slot = "Standard"
	return self

func calculate_extra_swings(options: Dictionary = {}) -> int:
	if left_weapon.is_empty():
		extra_swing_count = 0
		return 0
	if bool(options.get("force_left_axe", false)):
		extra_swing_count = 1
		return 1
	var chance = float(options.get("left_hand_swing_chance", owner.get_modified("LeftHandSwingChance", 0.0) if owner != null else 0.0))
	var seed = int(options.get("seed", 0))
	var roll = float(abs(seed * 1103515245 + 12345) % 10000) / 10000.0
	extra_swing_count = 1 if roll < chance else 0
	return extra_swing_count

func execute(options: Dictionary = {}) -> Dictionary:
	var attack_component = DaocAttackComponent.new()
	var main = attack_component.make_attack(owner, target, attack_weapon, style, options)
	var attacks: Array = [main.to_dict()]
	calculate_extra_swings(options)
	for i in range(extra_swing_count):
		var extra = attack_component.make_attack(owner, target, left_weapon if i % 2 == 0 else attack_weapon, null, options)
		extra.is_offhand = true
		attacks.append(extra.to_dict())
	return {"ok": true, "mechanism": "WeaponAction", "attack_count": attacks.size(), "attacks": attacks, "guardrails": DaocGameplayAuthority.result_guard()}
