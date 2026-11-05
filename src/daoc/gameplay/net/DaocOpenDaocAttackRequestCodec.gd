extends RefCounted
class_name DaocOpenDaocAttackRequestCodec

func decode_attack_request(bytes: PackedByteArray) -> Dictionary:
	var out = {"ok": false, "packet": "PlayerAttackRequest", "source": "PlayerAttackRequestHandler.cs"}
	if bytes.size() < 2:
		out["reason"] = "need two bytes: start, userActionFlag"
		return out
	var start = int(bytes[0]) != 0
	var user_action = int(bytes[1]) == 0
	out["ok"] = true
	out["start"] = start
	out["user_action"] = user_action
	out["action"] = "RequestStartAttack" if start and user_action else "StopAttack"
	return out

func build_attack_request(start: bool, user_action: bool = true) -> PackedByteArray:
	var out = PackedByteArray()
	out.append(1 if start else 0)
	out.append(0 if user_action else 1)
	return out
