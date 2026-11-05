extends RefCounted
class_name DaocOpenDaocAnimationCodec

## P1-76 — les quatre paquets par lesquels le serveur NOMME ce que le client
## doit jouer : incantation, effet de sort, coup de mêlée, interruption.
##
## Dispositions lues dans OpenDAoC `PacketLib168.cs` et confrontées aux
## captures live du 2026-09-14 (`reports/live_loop/step_38..42`, région 51,
## Heyvena + rats) :
##
##   0x72 SpellCastAnimation, 8 octets :
##     u16 casterOID, u16 clientEffect, u16 castingTime (dixièmes de seconde),
##     u16 0. Vu : `1848 0097 0019 0000` = Heyvena, effet client 151
##     (« Ice Cloud (Minor) » dans `gamedata/spells.csv`), 2,5 s.
##     ATTENTION : le second champ est `Spell.ClientEffect`, PAS l'identifiant
##     serveur du sort. C'est lui qui indexe `spells.csv` côté client.
##
##   0x1B SpellEffectAnimation, 10 octets sur Eden (12 sur OpenDAoC master,
##     qui ajoute un u16 0xFFBF) :
##     u16 casterOID, u16 clientEffect, u16 targetOID, u16 boltTime,
##     u8 noSound, u8 success. Vu à chaque entrée monde :
##     `1848 0001 1848 0000 00 01` (effet 1 sur soi-même).
##
##   0xBC CombatAnimation, 14 octets sur Eden (12 sur OpenDAoC master) :
##     u16 attackerOID, u16 defenderOID, u16 weaponID, u16 shieldID,
##     u16 style (petit-boutiste), u8 stance, u8 result, u8 targetHealth%,
##     u8 0. Vu : `04ca 1848 0000 0000 0000 00 0a 57 00` = le rat 0x04CA
##     frappe Heyvena, résultat 0x0A (coup non stylé), 87 % de vie restante.
##     Master : u8 style, u8 stance, u8 result (| 0x80 si style > 255),
##     u8 targetHealth%.
##
##   0x73 InterruptSpellCast, 4 octets : u16 livingOID, u16 1.
##
## Les codes de résultat sont ceux que `GameLiving.ShowAttackAnimation`
## envoie, pas l'énumération `eAttackResult` : 0 raté, 1 paré, 2 bloqué,
## 3 esquivé, 4 maladresse, 10 coup, 11 coup stylé.

const OPCODE_SPELL_CAST_ANIMATION := 0x72
const OPCODE_SPELL_EFFECT_ANIMATION := 0x1B
const OPCODE_COMBAT_ANIMATION := 0xBC
const OPCODE_INTERRUPT_SPELL_CAST := 0x73

const COMBAT_RESULTS := {
	0: "Missed", 1: "Parried", 2: "Blocked", 3: "Evaded", 4: "Fumbled",
	10: "HitUnstyled", 11: "HitStyle",
}


static func decode_spell_cast_animation(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 6:
		return {"ok": false, "error": "spell_cast_payload_too_short", "size": payload.size()}
	return {
		"ok": true,
		"caster_id": _u16(payload, 0),
		"client_effect": _u16(payload, 2),
		"casting_time_tenths": _u16(payload, 4),
		"casting_time_sec": float(_u16(payload, 4)) / 10.0,
	}


static func decode_spell_effect_animation(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 10:
		return {"ok": false, "error": "spell_effect_payload_too_short", "size": payload.size()}
	return {
		"ok": true,
		"caster_id": _u16(payload, 0),
		"client_effect": _u16(payload, 2),
		"target_id": _u16(payload, 4),
		"bolt_time_tenths": _u16(payload, 6),
		"bolt_time_sec": float(_u16(payload, 6)) / 10.0,
		"no_sound": int(payload[8]) != 0,
		"success": int(payload[9]) != 0,
		"layout": "eden_10" if payload.size() == 10 else "master_12",
	}


static func decode_combat_animation(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 12:
		return {"ok": false, "error": "combat_payload_too_short", "size": payload.size()}
	var out := {
		"ok": true,
		"attacker_id": _u16(payload, 0),
		"defender_id": _u16(payload, 2),
		"weapon_id": _u16(payload, 4),
		"shield_id": _u16(payload, 6),
	}
	var result_raw := 0
	if payload.size() >= 14:
		out["layout"] = "eden_14"
		out["style"] = int(payload[8]) | (int(payload[9]) << 8)
		out["stance"] = int(payload[10])
		result_raw = int(payload[11])
		out["target_health_percent"] = int(payload[12])
	else:
		out["layout"] = "master_12"
		out["style"] = int(payload[8])
		out["stance"] = int(payload[9])
		result_raw = int(payload[10])
		out["target_health_percent"] = int(payload[11])
	out["result_raw"] = result_raw
	var result_code := result_raw & 0x7F
	out["result_code"] = result_code
	out["result"] = str(COMBAT_RESULTS.get(result_code, "result_%d" % result_code))
	out["hit"] = result_code == 10 or result_code == 11
	return out


static func decode_interrupt_spell_cast(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2:
		return {"ok": false, "error": "interrupt_payload_too_short", "size": payload.size()}
	return {"ok": true, "living_id": _u16(payload, 0)}


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])
