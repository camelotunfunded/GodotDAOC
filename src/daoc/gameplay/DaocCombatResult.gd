extends RefCounted
class_name DaocCombatResult

var ok: bool = true
var mechanism: String = ""
var attack_data: DaocAttackData = null
var effects: Array = []
var messages: Array = []
var guardrails: Dictionary = {}

static func from_attack(mechanism_name: String, ad: DaocAttackData, extra_messages: Array = []) -> DaocCombatResult:
	var r = DaocCombatResult.new()
	r.mechanism = mechanism_name
	r.attack_data = ad
	r.messages = extra_messages.duplicate(true)
	r.guardrails = DaocGameplayAuthority.result_guard()
	return r

func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"mechanism": mechanism,
		"attack_data": attack_data.to_dict() if attack_data != null else {},
		"effects": effects.duplicate(true),
		"messages": messages.duplicate(true),
		"guardrails": guardrails.duplicate(true),
	}
