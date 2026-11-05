extends RefCounted
class_name DaocCombatEntityState

var entity_id: int = 0
var name: String = "Entity"
var level: int = 1
var max_health: int = 100
var health: int = 100
var mana: int = 100
var endurance: int = 100
## P1-23C — LES DEUX PLAFONDS QUI MANQUAIENT. Sans eux, `mana` et `endurance`
## etaient des absolus que le pont d'interface ne pouvait pas convertir en jauge,
## et que la regeneration ne pouvait pas borner. `CalculateMaxMana` et
## `FatigueCalculator` les donnent ; voir `DaocDolFormulas`.
var max_mana: int = 100
var max_endurance: int = 100
var is_player: bool = false
var character_class_id: int = 0
var is_alive: bool = true
var is_diseased: bool = false
var is_moving: bool = false
var in_combat: bool = false
var attacker_melee_count: int = 0
var stats: Dictionary = {}
var resists: Dictionary = {}
var properties: Dictionary = {}
var spec_levels: Dictionary = {}
var effect_properties: Dictionary = {}
var effect_resists: Dictionary = {}
## Lignes de SORTS distinctes des spécialisations de combat. La clef est le
## KeyName de spellline, la valeur est le niveau qui ouvre linexspell.
var spell_line_levels: Dictionary = {}
var master_level_path: String = ""
var master_level: int = 0
var champion_enabled: bool = false
var champion_level: int = 0
var champion_trained_lines: Dictionary = {}
var champion_abilities: Array = []
## P1-109 — les capacites de royaume passives (nom -> niveau) et ce qu elles
## ajoutent : proprietes (Strength, CriticalMeleeHitChance, MaxHealth...) et
## resistances, hors des buffs (DaocRealmAbilityRules). Le rang de royaume
## et les bounty points, tels que le 0x91 les donne.
var realm_abilities: Dictionary = {}
var ability_properties: Dictionary = {}
var ability_resists: Dictionary = {}
var realm_level: int = 0
var bounty_points: int = 0

static func from_dict(data: Dictionary) -> DaocCombatEntityState:
	var s = DaocCombatEntityState.new()
	s.entity_id = int(data.get("id", data.get("entity_id", 0)))
	s.name = str(data.get("name", "Entity"))
	s.level = int(data.get("level", 1))
	s.max_health = maxi(1, int(data.get("max_health", data.get("maxHealth", 100))))
	s.health = clampi(int(data.get("health", s.max_health)), 0, s.max_health)
	s.max_mana = int(data.get("max_mana", 100))
	s.max_endurance = int(data.get("max_endurance", 100))
	s.mana = clampi(int(data.get("mana", s.max_mana)), 0, maxi(0, s.max_mana))
	s.endurance = clampi(int(data.get("endurance", s.max_endurance)), 0, maxi(0, s.max_endurance))
	s.is_player = bool(data.get("is_player", data.get("player", false)))
	s.character_class_id = int(data.get("character_class_id", 0))
	s.is_alive = bool(data.get("is_alive", s.health > 0)) and s.health > 0
	s.is_diseased = bool(data.get("is_diseased", data.get("diseased", false)))
	s.is_moving = bool(data.get("is_moving", data.get("moving", false)))
	s.in_combat = bool(data.get("in_combat", false))
	s.attacker_melee_count = int(data.get("attacker_melee_count", 0))
	if typeof(data.get("stats", {})) == TYPE_DICTIONARY:
		s.stats = (data.get("stats", {}) as Dictionary).duplicate(true)
	if typeof(data.get("resists", {})) == TYPE_DICTIONARY:
		s.resists = (data.get("resists", {}) as Dictionary).duplicate(true)
	if typeof(data.get("properties", {})) == TYPE_DICTIONARY:
		s.properties = (data.get("properties", {}) as Dictionary).duplicate(true)
	if typeof(data.get("effect_properties", {})) == TYPE_DICTIONARY:
		s.effect_properties = (data.get("effect_properties", {}) as Dictionary).duplicate(true)
	if typeof(data.get("effect_resists", {})) == TYPE_DICTIONARY:
		s.effect_resists = (data.get("effect_resists", {}) as Dictionary).duplicate(true)
	if typeof(data.get("spec_levels", {})) == TYPE_DICTIONARY:
		s.spec_levels = (data.get("spec_levels", {}) as Dictionary).duplicate(true)
	if typeof(data.get("spell_line_levels", {})) == TYPE_DICTIONARY:
		s.spell_line_levels = (data.get("spell_line_levels", {}) as Dictionary).duplicate(true)
	s.master_level_path = str(data.get("master_level_path", ""))
	s.master_level = clampi(int(data.get("master_level", 0)), 0, 10)
	s.champion_enabled = bool(data.get("champion_enabled", false))
	s.champion_level = clampi(int(data.get("champion_level", 0)), 0, 15)
	s.champion_trained_lines = (data.get("champion_trained_lines", {}) as Dictionary).duplicate(true)
	s.champion_abilities = (data.get("champion_abilities", []) as Array).duplicate(true)
	if typeof(data.get("realm_abilities", {})) == TYPE_DICTIONARY:
		s.realm_abilities = (data.get("realm_abilities", {}) as Dictionary).duplicate(true)
	if typeof(data.get("ability_properties", {})) == TYPE_DICTIONARY:
		s.ability_properties = (data.get("ability_properties", {}) as Dictionary).duplicate(true)
	if typeof(data.get("ability_resists", {})) == TYPE_DICTIONARY:
		s.ability_resists = (data.get("ability_resists", {}) as Dictionary).duplicate(true)
	s.realm_level = int(data.get("realm_level", 0))
	s.bounty_points = int(data.get("bounty_points", 0))
	return s

func duplicate_state() -> DaocCombatEntityState:
	return DaocCombatEntityState.from_dict(to_dict())

func to_dict() -> Dictionary:
	return {
		"id": entity_id,
		"name": name,
		"level": level,
		"max_health": max_health,
		"health": health,
		"mana": mana,
		"endurance": endurance,
		"max_mana": max_mana,
		"max_endurance": max_endurance,
		"is_player": is_player,
		"character_class_id": character_class_id,
		"is_alive": is_alive,
		"is_diseased": is_diseased,
		"is_moving": is_moving,
		"in_combat": in_combat,
		"attacker_melee_count": attacker_melee_count,
		"stats": stats.duplicate(true),
		"resists": resists.duplicate(true),
		"properties": properties.duplicate(true),
		"effect_properties": effect_properties.duplicate(true),
		"effect_resists": effect_resists.duplicate(true),
		"spec_levels": spec_levels.duplicate(true),
		"spell_line_levels": spell_line_levels.duplicate(true),
		"master_level_path": master_level_path,
		"master_level": master_level,
		"champion_enabled": champion_enabled,
		"champion_level": champion_level,
		"champion_trained_lines": champion_trained_lines.duplicate(true),
		"champion_abilities": champion_abilities.duplicate(true),
		"realm_abilities": realm_abilities.duplicate(true),
		"ability_properties": ability_properties.duplicate(true),
		"ability_resists": ability_resists.duplicate(true),
		"realm_level": realm_level,
		"bounty_points": bounty_points,
	}

func get_modified(property_name: String, fallback: float = 0.0) -> float:
	# P1-109 : les capacites de royaume passives s ajoutent aux buffs (DOL :
	# AbilityBonus est une categorie a part de BuffBonus).
	var effect_value := float(effect_properties.get(property_name, 0.0)) + float(ability_properties.get(property_name, 0.0))
	if properties.has(property_name):
		return float(properties[property_name]) + effect_value
	if stats.has(property_name):
		return float(stats[property_name]) + effect_value
	return fallback + effect_value

func get_resist_percent(damage_type: String) -> float:
	if resists.has(damage_type):
		return float(resists[damage_type]) + float(effect_resists.get(damage_type, 0.0)) + float(ability_resists.get(damage_type, 0.0))
	var lower = damage_type.to_lower()
	for key in resists.keys():
		if str(key).to_lower() == lower:
			return float(resists[key]) + float(effect_resists.get(str(key), 0.0)) + float(ability_resists.get(str(key), 0.0))
	return float(effect_resists.get(damage_type, 0.0)) + float(ability_resists.get(damage_type, 0.0))

func get_spec_level(spec_name: String, fallback: float = 1.0) -> float:
	if spec_levels.has(spec_name):
		return float(spec_levels[spec_name])
	return fallback

func change_health(amount: int) -> int:
	var before = health
	health = clampi(health + amount, 0, max_health)
	is_alive = health > 0
	return health - before
