extends RefCounted
class_name DaocSpellDef

var id: int = 0
var name: String = "Spell"
var spell_type: String = "DirectDamage"
var damage_type: String = "Natural"
var level: int = 1
var damage: float = 0.0
var value: float = 0.0
var range: int = 1500
var radius: int = 0
var cast_time: int = 0
var recast_delay: int = 0
var duration: int = 0
var frequency: int = 0
var power: int = 0
var pulse_power: int = 0
var concentration: int = 0
var target: String = "ENEMY"
var client_effect: int = 0
var effect_group: int = 0
var life_drain_return: int = 0
## P1-124 : le sous-sort (PetSpell : le sort que lance le familier).
var sub_spell_id: int = 0
var move_cast: bool = false
var uninterruptible: bool = false
var spec_line: String = ""
var source_table: String = "offline_fixture"
var raw: Dictionary = {}

static func from_dict(data: Dictionary) -> DaocSpellDef:
	var s = DaocSpellDef.new()
	var from_database := str(data.get("source_table", "")) == "spell.sql"
	s.id = int(data.get("id", data.get("ID", data.get("SpellID", 0))))
	s.name = str(data.get("name", data.get("Name", "Spell")))
	s.spell_type = str(data.get("spell_type", data.get("Type", data.get("SpellType", "DirectDamage"))))
	s.damage_type = DaocCombatEnums.canonical_damage_type(data.get("damage_type", data.get("DamageType", "Natural")))
	s.level = int(data.get("level", data.get("Level", 1)))
	s.damage = float(data.get("damage", data.get("Damage", 0.0)))
	s.value = float(data.get("value", data.get("Value", 0.0)))
	s.range = int(data.get("range", data.get("Range", 1500)))
	s.radius = int(data.get("radius", data.get("Radius", 0)))
	var raw_cast_time := float(data.get("cast_time", data.get("CastTime", 0)))
	var raw_recast_delay := float(data.get("recast_delay", data.get("RecastDelay", 0)))
	var raw_duration := float(data.get("duration", data.get("Duration", 0)))
	var raw_frequency := float(data.get("frequency", data.get("Frequency", 0)))
	# DBSpell est en secondes (Frequency en dixiemes) ; Spell.cs convertit vers
	# les millisecondes utilisées par l'exécution. Les fixtures sont déjà dans
	# cette unité. La provenance empêche toute heuristique sur la valeur.
	s.cast_time = int(round(raw_cast_time * 1000.0)) if from_database else int(raw_cast_time)
	s.recast_delay = int(round(raw_recast_delay * 1000.0)) if from_database else int(raw_recast_delay)
	s.duration = int(round(raw_duration * 1000.0)) if from_database else int(raw_duration)
	s.frequency = int(round(raw_frequency * 100.0)) if from_database else int(raw_frequency)
	s.power = int(data.get("power", data.get("Power", 0)))
	s.pulse_power = int(data.get("pulse_power", data.get("PulsePower", 0)))
	s.concentration = int(data.get("concentration", data.get("Concentration", 0)))
	s.target = str(data.get("target", data.get("Target", "ENEMY")))
	s.client_effect = int(data.get("client_effect", data.get("ClientEffect", 0)))
	s.effect_group = int(data.get("effect_group", data.get("EffectGroup", 0)))
	s.life_drain_return = int(data.get("life_drain_return", data.get("LifeDrainReturn", 0)))
	s.sub_spell_id = int(data.get("sub_spell_id", data.get("SubSpellID", 0)))
	s.move_cast = bool(int(data.get("move_cast", data.get("MoveCast", 0))))
	s.uninterruptible = bool(int(data.get("uninterruptible", data.get("Uninterruptible", 0))))
	s.spec_line = str(data.get("spec_line", data.get("Spec", data.get("SpellLine", ""))))
	s.source_table = str(data.get("source_table", "offline_fixture"))
	s.raw = data.duplicate(true)
	return s

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"spell_type": spell_type,
		"damage_type": damage_type,
		"level": level,
		"damage": damage,
		"value": value,
		"range": range,
		"radius": radius,
		"cast_time": cast_time,
		"recast_delay": recast_delay,
		"duration": duration,
		"frequency": frequency,
		"power": power,
		"concentration": concentration,
		"target": target,
		"client_effect": client_effect,
		"effect_group": effect_group,
		"life_drain_return": life_drain_return,
		"move_cast": move_cast,
		"uninterruptible": uninterruptible,
		"spec_line": spec_line,
		"source_table": source_table,
		"raw": raw.duplicate(true),
	}
