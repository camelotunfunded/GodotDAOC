extends RefCounted
class_name DaocEffectModifier

var modifier_kind: String = "flat"
var modifier_stat: String = ""
var modifier_value: float = 0.0
var prediction_only: bool = true
var server_authority: bool = true
var damage_final: bool = false

func setup(p_kind: String, p_stat: String, p_value: float) -> DaocEffectModifier:
	modifier_kind = p_kind
	modifier_stat = p_stat
	modifier_value = p_value
	return self

func to_dict() -> Dictionary:
	return {
		"modifier_kind": modifier_kind,
		"modifier_stat": modifier_stat,
		"modifier_value": modifier_value,
		"prediction_only": prediction_only,
		"server_authority": server_authority,
		"damage_final": damage_final,
	}
