extends RefCounted
class_name DaocEffectState

const DaocActiveEffectScript = preload("res://src/daoc/gameplay/effects/DaocActiveEffect.gd")

var active_effects: Array = []

func clear() -> void:
	active_effects.clear()

func add_effect(effect: RefCounted) -> void:
	if effect != null:
		active_effects.append(effect)

func add_effect_dict(effect_dict: Dictionary) -> void:
	var effect: RefCounted = DaocActiveEffectScript.new()
	effect.source_spell_id = int(effect_dict.get("source_spell_id", 0))
	effect.spell_name = str(effect_dict.get("spell_name", ""))
	effect.spell_type = str(effect_dict.get("spell_type", ""))
	effect.caster_id = int(effect_dict.get("caster_id", 0))
	effect.target_id = int(effect_dict.get("target_id", 0))
	effect.duration = int(effect_dict.get("duration", 0))
	effect.frequency = int(effect_dict.get("frequency", 0))
	effect.remaining_duration = int(effect_dict.get("remaining_duration", effect.duration))
	effect.effect_group = int(effect_dict.get("effect_group", 0))
	effect.stacking_group = str(effect_dict.get("stacking_group", ""))
	effect.effect_category = str(effect_dict.get("effect_category", "utility"))
	effect.modifier_kind = str(effect_dict.get("modifier_kind", "effect"))
	effect.modifier_stat = str(effect_dict.get("modifier_stat", ""))
	effect.modifier_value = float(effect_dict.get("modifier_value", 0.0))
	effect.is_buff = bool(effect_dict.get("is_buff", false))
	effect.is_debuff = bool(effect_dict.get("is_debuff", false))
	effect.is_regen = bool(effect_dict.get("is_regen", false))
	effect.is_resist = bool(effect_dict.get("is_resist", false))
	effect.is_speed = bool(effect_dict.get("is_speed", false))
	effect.prediction_only = true
	effect.server_authority = true
	effect.damage_final = false
	add_effect(effect)

func advance_time(delta_msec: int) -> Dictionary:
	var elapsed: int = maxi(0, delta_msec)
	var remaining: Array = []
	var expired: Array = []
	for item in active_effects:
		var effect: RefCounted = item as RefCounted
		if effect == null:
			continue
		if effect.remaining_duration > 0:
			effect.remaining_duration = maxi(0, effect.remaining_duration - elapsed)
		if effect.duration > 0 and effect.remaining_duration <= 0:
			expired.append(effect.to_dict())
		else:
			remaining.append(effect)
	active_effects = remaining
	return {
		"ok": true,
		"advanced_msec": elapsed,
		"expired_count": expired.size(),
		"remaining_count": active_effects.size(),
		"expired_effects": expired,
		"active_effect_summary": summary(),
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
		"runtime_enabled": false,
	}

func to_array() -> Array:
	var out: Array = []
	for item in active_effects:
		var effect: RefCounted = item as RefCounted
		if effect != null:
			out.append(effect.to_dict())
	return out

func summary() -> Dictionary:
	var by_category: Dictionary = {}
	var stat_modifiers: Dictionary = {}
	var resist_modifiers: Dictionary = {}
	var speed_modifiers: Array = []
	var armor_modifiers: Array = []
	var regen_modifiers: Array = []
	for item in active_effects:
		var effect: RefCounted = item as RefCounted
		if effect == null:
			continue
		by_category[effect.effect_category] = int(by_category.get(effect.effect_category, 0)) + 1
		if effect.effect_category == "stats":
			stat_modifiers[effect.modifier_stat] = float(stat_modifiers.get(effect.modifier_stat, 0.0)) + effect.modifier_value
		if effect.is_resist:
			resist_modifiers[effect.modifier_stat] = float(resist_modifiers.get(effect.modifier_stat, 0.0)) + effect.modifier_value
		if effect.is_speed:
			speed_modifiers.append(effect.to_modifier().to_dict())
		if effect.effect_category == "armor":
			armor_modifiers.append(effect.to_modifier().to_dict())
		if effect.is_regen:
			regen_modifiers.append(effect.to_modifier().to_dict())
	return {
		"active_effect_count": active_effects.size(),
		"effects_by_category": by_category,
		"modifiers_by_stat": stat_modifiers,
		"modifiers_by_resist": resist_modifiers,
		"speed_modifiers": speed_modifiers,
		"armor_modifiers": armor_modifiers,
		"regen_modifiers": regen_modifiers,
		"prediction_only": true,
		"server_authority": true,
		"damage_final": false,
	}
