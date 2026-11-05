extends RefCounted
class_name DaocStyleDef

var id: int = 0
var name: String = "Style"
var opening_requirement_type: String = "Any"
var opening_requirement_value: int = 0
var attack_result_requirement: String = "Any"
var stealth_requirement: bool = false
var weapon_type_requirement: String = "Any"
var bonus_to_hit: int = 0
var bonus_to_defense: int = 0
var growth_rate: float = 0.0
## P1-29 — la part FIXE de la croissance, celle qui ne suit pas la
## specialisation. Tous les styles du dump lu le 2026-09-09 l ont a zero,
## ce qui rend la specialisation INDISPENSABLE pour qu un style rende quoi
## que ce soit. La colonne existe : l ignorer serait supposer sa valeur.
var growth_offset: float = 0.0
var endurance_cost: int = 0
var animation_id: int = 0
## P1-133 : Style.TwoHandAnimation, joue a la place d animation_id avec une arme a deux mains.
var two_hand_animation: int = 0
var spec_level_requirement: int = 1
var effects: Array = []
## P1-123 — les procs du style (stylexspell) : [{spell_id, class_id, chance}],
## la classe du style (ClassId) et RandomProc (OpenDAoC StyleProcessor).
var procs: Array = []
var class_id: int = 0
var random_proc: bool = false

static func from_dict(data: Dictionary) -> DaocStyleDef:
	var s = DaocStyleDef.new()
	s.id = int(data.get("id", data.get("ID", 0)))
	s.name = str(data.get("name", data.get("Name", "Style")))
	s.opening_requirement_type = str(data.get("opening_requirement_type", data.get("OpeningRequirementType", "Any")))
	s.opening_requirement_value = int(data.get("opening_requirement_value", data.get("OpeningRequirementValue", 0)))
	s.attack_result_requirement = str(data.get("attack_result_requirement", data.get("AttackResultRequirement", "Any")))
	s.stealth_requirement = bool(data.get("stealth_requirement", data.get("StealthRequirement", false)))
	s.weapon_type_requirement = str(data.get("weapon_type_requirement", data.get("WeaponTypeRequirement", "Any")))
	s.bonus_to_hit = int(data.get("bonus_to_hit", data.get("BonusToHit", 0)))
	s.bonus_to_defense = int(data.get("bonus_to_defense", data.get("BonusToDefense", 0)))
	s.growth_rate = float(data.get("growth_rate", data.get("GrowthRate", 0.0)))
	s.growth_offset = float(data.get("growth_offset", data.get("GrowthOffset", 0.0)))
	s.endurance_cost = int(data.get("endurance_cost", data.get("EnduranceCost", 0)))
	# P1-133 : DOL envoie Style.Icon (ID styles.csv) comme animation ; l index P1-29 le nomme « icon ».
	s.animation_id = int(data.get("animation_id", data.get("AnimationId", data.get("icon", data.get("Icon", 0)))))
	s.two_hand_animation = int(data.get("two_hand_animation", data.get("TwoHandAnimation", 0)))
	s.spec_level_requirement = int(data.get("spec_level_requirement", data.get("SpecLevelRequirement", 1)))
	if typeof(data.get("effects", [])) == TYPE_ARRAY:
		s.effects = (data.get("effects", []) as Array).duplicate(true)
	s.procs = (data.get("procs", []) as Array).duplicate(true)
	s.class_id = int(data.get("class_id", data.get("ClassId", 0)))
	s.random_proc = bool(data.get("random_proc", false))
	return s

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"opening_requirement_type": opening_requirement_type,
		"opening_requirement_value": opening_requirement_value,
		"attack_result_requirement": attack_result_requirement,
		"stealth_requirement": stealth_requirement,
		"weapon_type_requirement": weapon_type_requirement,
		"bonus_to_hit": bonus_to_hit,
		"bonus_to_defense": bonus_to_defense,
		"growth_rate": growth_rate,
		"growth_offset": growth_offset,
		"endurance_cost": endurance_cost,
		"animation_id": animation_id,
		"two_hand_animation": two_hand_animation,
		"spec_level_requirement": spec_level_requirement,
		"effects": effects.duplicate(true),
	}
