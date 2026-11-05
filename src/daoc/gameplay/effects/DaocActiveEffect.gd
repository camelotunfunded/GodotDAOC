extends RefCounted
class_name DaocActiveEffect

const DaocEffectModifierScript = preload("res://src/daoc/gameplay/effects/DaocEffectModifier.gd")

var source_spell_id: int = 0
var spell_name: String = ""
var spell_type: String = ""
var caster_id: int = 0
var target_id: int = 0
var duration: int = 0
var frequency: int = 0
var remaining_duration: int = 0
var effect_group: int = 0
var stacking_group: String = ""
var effect_category: String = "utility"
var modifier_kind: String = "effect"
var modifier_stat: String = ""
var modifier_value: float = 0.0
var is_buff: bool = false
var is_debuff: bool = false
var is_regen: bool = false
var is_resist: bool = false
var is_speed: bool = false
var prediction_only: bool = true
var server_authority: bool = true
var damage_final: bool = false

func setup_from_spell(spell: DaocSpellDef, caster: DaocCombatEntityState, target: DaocCombatEntityState, descriptor: Dictionary) -> RefCounted:
	if spell != null:
		source_spell_id = spell.id
		spell_name = spell.name
		spell_type = spell.spell_type
		duration = spell.duration
		frequency = spell.frequency
		remaining_duration = spell.duration
		effect_group = spell.effect_group
	caster_id = caster.entity_id if caster != null else 0
	target_id = target.entity_id if target != null else 0
	effect_category = str(descriptor.get("effect_category", "utility"))
	modifier_kind = str(descriptor.get("modifier_kind", "effect"))
	modifier_stat = str(descriptor.get("modifier_stat", ""))
	modifier_value = float(descriptor.get("modifier_value", 0.0))
	stacking_group = str(descriptor.get("stacking_group", spell_type))
	is_buff = bool(descriptor.get("is_buff", false))
	is_debuff = bool(descriptor.get("is_debuff", false))
	is_regen = bool(descriptor.get("is_regen", false))
	is_resist = bool(descriptor.get("is_resist", false))
	is_speed = bool(descriptor.get("is_speed", false))
	prediction_only = true
	server_authority = true
	damage_final = false
	return self

func to_modifier() -> RefCounted:
	return DaocEffectModifierScript.new().setup(modifier_kind, modifier_stat, modifier_value)

func to_dict() -> Dictionary:
	return {
		"source_spell_id": source_spell_id,
		"spell_name": spell_name,
		"spell_type": spell_type,
		"caster_id": caster_id,
		"target_id": target_id,
		"duration": duration,
		"frequency": frequency,
		"remaining_duration": remaining_duration,
		"effect_group": effect_group,
		"stacking_group": stacking_group,
		"effect_category": effect_category,
		"modifier_kind": modifier_kind,
		"modifier_stat": modifier_stat,
		"modifier_value": modifier_value,
		"is_buff": is_buff,
		"is_debuff": is_debuff,
		"is_regen": is_regen,
		"is_resist": is_resist,
		"is_speed": is_speed,
		"prediction_only": prediction_only,
		"server_authority": server_authority,
		"damage_final": damage_final,
	}
