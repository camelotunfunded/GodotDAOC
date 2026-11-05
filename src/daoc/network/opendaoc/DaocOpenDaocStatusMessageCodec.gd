extends RefCounted
class_name DaocOpenDaocStatusMessageCodec

## B5 — les deux paquets qui font parler le serveur au joueur.
##
## 0xAD CharacterStatusUpdate, disposition PacketLib190 (DOLSharp
## GameServer/packets/Server/PacketLib190.cs:76), 22 octets, verifiee sur la
## capture P1-20D (payload 22) :
##   u8 health%, u8 mana%, u8 sitting, u8 endurance%, u8 concentration%, u8 0,
##   puis huit u16 BE : maxMana, maxEnd, maxConc, maxHealth, health, endurance,
##   mana, concentration.
##
## 0xAF Message, disposition PacketLib173 (heritee jusqu'a 1.125,
## PacketLib173.cs:501) : u16 0xFFFF, u16 sessionId, u8 type, 3 x 0, chaine
## terminee par 0. Le texte commence par « @@ » pour la fenetre de chat, « ## »
## pour une fenetre surgissante, rien pour la fenetre systeme (eChatLoc).
## eChatType : IPacketLib.cs:276.

const OPCODE_STATUS := 0xAD
const OPCODE_MESSAGE := 0xAF

const CHAT_TYPES := {
	0x01: "say", 0x02: "send", 0x03: "group", 0x04: "guild", 0x05: "broadcast",
	0x06: "emote", 0x07: "help", 0x08: "chat", 0x09: "advise", 0x0a: "officer",
	0x0b: "alliance", 0x0c: "battlegroup", 0x0d: "battlegroup_leader",
	0x23: "lfg", 0x24: "trade",
}
const SYSTEM_TYPES := {
	0x00: "system", 0x0f: "staff", 0x10: "spell", 0x11: "you_hit", 0x12: "you_were_hit",
	0x13: "skill", 0x14: "merchant", 0x15: "you_died", 0x16: "player_died",
	0x17: "others_combat", 0x18: "damage_add", 0x19: "spell_expires", 0x1a: "loot",
	0x1b: "spell_resisted", 0x1c: "important", 0x1d: "damaged", 0x1e: "missed",
	0x1f: "spell_pulse", 0x20: "killed_by_alb", 0x21: "killed_by_mid", 0x22: "killed_by_hib",
	0x64: "social", 0xC8: "screen_center", 0xC9: "screen_center_smaller",
	0xCA: "screen_center_and_system", 0xCB: "screen_center_smaller_and_system",
}


static func decode_status_payload(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 22:
		return {"ok": false, "error": "status_payload_too_short", "size": payload.size()}
	return {
		"ok": true,
		"health_percent": int(payload[0]), "mana_percent": int(payload[1]),
		"sitting": int(payload[2]) != 0, "endurance_percent": int(payload[3]),
		"concentration_percent": int(payload[4]),
		"max_mana": _u16(payload, 6), "max_endurance": _u16(payload, 8),
		"max_concentration": _u16(payload, 10), "max_health": _u16(payload, 12),
		"health": _u16(payload, 14), "endurance": _u16(payload, 16),
		"mana": _u16(payload, 18), "concentration": _u16(payload, 20),
	}


static func decode_message_payload(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 9:
		return {"ok": false, "error": "message_payload_too_short", "size": payload.size()}
	var type := int(payload[4])
	var end := payload.size()
	for index in range(8, payload.size()):
		if payload[index] == 0:
			end = index
			break
	var text := payload.slice(8, end).get_string_from_utf8()
	if text == "" and end > 8:
		text = payload.slice(8, end).get_string_from_ascii()
	var window := "system"
	if text.begins_with("@@"):
		window = "chat"
		text = text.substr(2)
	elif text.begins_with("##"):
		window = "popup"
		text = text.substr(2)
	var kind := str(CHAT_TYPES.get(type, SYSTEM_TYPES.get(type, "type_0x%02X" % type)))
	# Le chat du jeu : ce que disent les joueurs. La console : tout le reste
	# (systeme, combat, sorts, butin), meme quand le serveur le marque « chat ».
	var console := not CHAT_TYPES.has(type)
	return {"ok": true, "type": type, "kind": kind, "window": window,
		"console": console, "chat": not console, "text": text,
		"session_id": _u16(payload, 2)}


static func _u16(data: PackedByteArray, offset: int) -> int:
	return ((int(data[offset]) & 0xff) << 8) | (int(data[offset + 1]) & 0xff)
