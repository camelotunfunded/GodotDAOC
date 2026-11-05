extends RefCounted
class_name DaocGameplayAuthority

const AUTH_SERVER: String = "server"
const AUTH_CLIENT_PREDICTION: String = "client_prediction"
const AUTH_OFFLINE_LAB: String = "offline_lab"

static func guardrails() -> Dictionary:
	return {
		"checkpoint": "P1_18B_GAMEPLAY_GUARDRAILS",
		"server_authority": true,
		"prediction_only": true,
		"offline_lab": true,
		"runtime_enabled": false,
		"damage_final": false,
		"coordinate_frame_confirmed": false,
		"credentials_sent": false,
		"player_spawn_applied": false,
		"notes": [
			"These mechanics are OpenDAoC/DOL-informed client scaffolds.",
			"Server remains authoritative for final damage, state and movement.",
			"Use with a live OpenDAoC validation harness before promoting formulas.",
		],
	}

static func result_guard() -> Dictionary:
	return {
		"authority": AUTH_OFFLINE_LAB,
		"server_authority": true,
		"prediction_only": true,
		"damage_final": false,
		"validated_against_live_server": false,
	}
