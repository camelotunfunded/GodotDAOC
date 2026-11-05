extends RefCounted
class_name DaocOpenDaocProgressCodec

## P1-78 — la progression et les interactions PNJ, telles que le serveur les dit.
##
## Dispositions lues dans OpenDAoC (`PacketLib190.SendUpdatePoints`,
## `PacketLib168.SendDialogBox / SendPlayerDied`, `PacketLib1124.SendQuestPacket`)
## et confrontées aux tailles des captures live du 14/09 (0x91 : 48 octets).
##
##   0x91 CharacterPointsUpdate, 48 octets :
##     u32 realm points, u16 level permill (0..1000 : la barre d'expérience),
##     u16 points de spécialisation, u32 bounty points, u16 points de royaume,
##     u16 champion level permill, puis quatre u64 PETIT-boutistes :
##     expérience, expérience du niveau suivant, expérience champion (0), suivante (0).
##
##   0x81 Dialog :
##     u8 0, u8 code (eDialogCode : 100 = QuestSubscribe, 101 = QuestAbort,
##     102 = CustomDialog, 104 = SimpleWarning…), u16 data1..data4, u8 type
##     (0 = Ok, 1 = Yes/No, 2 = None), u8 autoWrap, chaîne, 0.
##     Pour une offre de quête : data1 = id de quête, data2 = OID du PNJ.
##     La réponse 0x82 recopie data1, data2, data3, puis u8 code, u8 réponse.
##
##   0xAE PlayerDeath : u16 OID du mort, u16 OID du tueur (0 si aucun), 4 x 0.
##
##   0x83 QuestEntry (1.124) :
##     u8 index, u8 longueur du nom, u16 PETIT-boutiste longueur de la
##     description, u8 zone (0), u8 0, nom, description (sans 0 final).
##     Une entrée vide (index, 5 x 0) EFFACE la case du journal.
##     Les quêtes « Reward » ont une autre queue (objectifs) : lues jusqu'au
##     nom + description, le reste est conservé brut.

const OPCODE_POINTS := 0x91
const OPCODE_DIALOG := 0x81
const OPCODE_PLAYER_DEATH := 0xAE
const OPCODE_QUEST_ENTRY := 0x83
## P1-82 — 0xB6 MaxSpeed (PacketLib168.SendUpdateMaxSpeed) : u16 vitesse en
## POURCENT de PLAYER_BASE_SPEED (191), u8 rotation interdite, u8 vitesse dans
## l'eau en pourcent. Capture locale du 02/09 : `00 7D 00 00` hors combat
## (125 %), `00 64` en combat (100 %), `00 A2` en sprint (162 % = 125 x 1,3).
## Le serveur l'envoie a chaque bascule du sprint (0xBB sur la capacite Sprint)
## et quand l'endurance tombe a zero.
const OPCODE_MAX_SPEED := 0xB6

## P1-105 : codes RELUS dans DOL (IPacketLib.cs eDialogCode) ; la table de
## P1-78 (100..113) etait inventee, seul 100 = QuestSubscribe tombait juste.
const DIALOG_CODES := {
	0x00: "simple_warning", 0x03: "guild_invite", 0x05: "group_invite", 0x06: "custom_dialog",
	0x08: "guild_leave", 0x14: "house_payrent", 0x19: "master_level_window", 0x1A: "keep_claim",
	0x20: "buy_respec", 0x30: "warmap_window", 0x31: "warmap_window", 0x32: "warmap_window",
	0x64: "quest_subscribe",
}
const DIALOG_TYPES := {0: "ok", 1: "yes_no", 2: "none"}


static func decode_points(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 16:
		return {"ok": false, "error": "points_payload_too_short", "size": payload.size()}
	var out := {
		"ok": true,
		"realm_points": _u32(payload, 0),
		"level_permill": _u16(payload, 4),
		"skill_specialty_points": _u16(payload, 6),
		"bounty_points": _u32(payload, 8),
		"realm_specialty_points": _u16(payload, 12),
		"champion_level_permill": _u16(payload, 14),
		"experience": 0, "experience_next_level": 0,
		"layout": "168_16",
	}
	if payload.size() >= 32:
		out["experience"] = _u64_le(payload, 16)
		out["experience_next_level"] = _u64_le(payload, 24)
		out["layout"] = "190_48" if payload.size() >= 48 else "190_32"
	out["level_percent"] = float(out["level_permill"]) / 10.0
	return out


static func decode_dialog(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 12:
		return {"ok": false, "error": "dialog_payload_too_short", "size": payload.size()}
	var code := int(payload[1])
	var end := payload.size()
	for index in range(12, payload.size()):
		if payload[index] == 0:
			end = index
			break
	var text := payload.slice(12, end).get_string_from_utf8()
	if text == "" and end > 12:
		text = payload.slice(12, end).get_string_from_ascii()
	var out := {
		"ok": true,
		"code": code,
		"kind": str(DIALOG_CODES.get(code, "code_%d" % code)),
		"data1": _u16(payload, 2), "data2": _u16(payload, 4),
		"data3": _u16(payload, 6), "data4": _u16(payload, 8),
		"type": int(payload[10]),
		"type_name": str(DIALOG_TYPES.get(int(payload[10]), "type_%d" % int(payload[10]))),
		"auto_wrap": int(payload[11]) != 0,
		"text": text,
	}
	if code == 100 or code == 101:
		out["quest_id"] = out["data1"]
		out["npc_object_id"] = out["data2"]
	return out


## Réponse 0x82 : data1..3 recopiés, code, réponse (1 oui / 0 non).
static func build_dialog_response_payload(dialog: Dictionary, accept: bool) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(8)
	_w16(payload, 0, int(dialog.get("data1", 0)))
	_w16(payload, 2, int(dialog.get("data2", 0)))
	_w16(payload, 4, int(dialog.get("data3", 0)))
	payload[6] = int(dialog.get("code", 0)) & 0xff
	payload[7] = 1 if accept else 0
	return payload


static func decode_max_speed(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 2:
		return {"ok": false, "error": "max_speed_payload_too_short", "size": payload.size()}
	return {
		"ok": true,
		"percent": _u16(payload, 0),
		"turning_disabled": payload.size() > 2 and int(payload[2]) != 0,
		"water_percent": int(payload[3]) if payload.size() > 3 else 0,
	}


static func decode_player_death(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "death_payload_too_short", "size": payload.size()}
	return {"ok": true, "killed_id": _u16(payload, 0), "killer_id": _u16(payload, 2)}


static func decode_quest_entry(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 6:
		return {"ok": false, "error": "quest_payload_too_short", "size": payload.size()}
	var index := int(payload[0])
	var name_length := int(payload[1])
	if name_length == 0:
		return {"ok": true, "index": index, "cleared": true, "name": "", "description": ""}
	var out := {"ok": true, "index": index, "cleared": false, "name": "", "description": "", "goals": [], "reward_quest": false}
	# Quête classique : u16 LE longueur description, u8 zone, u8 0, nom, description.
	var desc_length := int(payload[2]) | (int(payload[3]) << 8)
	var cursor := 6
	if cursor + name_length + desc_length <= payload.size() and desc_length > 0:
		out["name"] = _text(payload, cursor, name_length)
		out["description"] = _text(payload, cursor + name_length, desc_length)
		return out
	# Quête « Reward » (1.124) : u16 0, u8 nb objectifs, u8 niveau, nom, puis
	# description en chaîne Pascal (u8 longueur).
	out["reward_quest"] = true
	out["goal_count"] = int(payload[4])
	out["level"] = int(payload[5])
	if cursor + name_length > payload.size():
		return out
	out["name"] = _text(payload, cursor, name_length)
	cursor += name_length
	if cursor < payload.size():
		var pascal := int(payload[cursor])
		cursor += 1
		if cursor + pascal <= payload.size():
			out["description"] = _text(payload, cursor, pascal)
			cursor += pascal
	# Objectifs : u16 LE longueur + texte terminé par \r, puis 9 u16 LE, u8 fait, u8 objet…
	for _i in range(int(out["goal_count"])):
		if cursor + 2 > payload.size():
			break
		var goal_length := int(payload[cursor]) | (int(payload[cursor + 1]) << 8)
		cursor += 2
		if cursor + goal_length > payload.size():
			break
		var goal_text := _text(payload, cursor, goal_length).strip_edges()
		cursor += goal_length
		var achieved := false
		if cursor + 19 <= payload.size():
			achieved = int(payload[cursor + 18]) != 0
		(out["goals"] as Array).append({"text": goal_text, "achieved": achieved})
		cursor += 20
		# Un objet de quête (WriteTemplateData) suit parfois : sa longueur n'est
		# pas décodée ici, les objectifs suivants sont alors abandonnés.
		if cursor - 1 < payload.size() and cursor - 1 >= 0 and int(payload[cursor - 1]) != 0:
			break
	return out


static func _text(payload: PackedByteArray, start: int, length: int) -> String:
	var bytes := payload.slice(start, start + length)
	var text := bytes.get_string_from_utf8()
	if text == "" and length > 0:
		text = bytes.get_string_from_ascii()
	return text


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func _u32(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


static func _u64_le(data: PackedByteArray, offset: int) -> int:
	var value := 0
	for i in range(8):
		value |= int(data[offset + i]) << (8 * i)
	return value


static func _w16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


## P1-99 — 0x7F UpdateIcons : la barre des effets actifs (buffs, debuffs).
## Disposition MESUREE en live le 2026-09-21 sur Amethyst Shield lance par
## Heyvena (30 octets) :
##   01 00 01 00 | 00 00 00 00 01 04 b0 00 01 00 0f "Amethyst Shield"
## P1-108 — RELUE dans OpenDAoC (`PacketLib1110.SendUpdateIcons`, celle que
## ce serveur emploie pour un client 1.110+) et dans game.dll (`FUN_0041cab6`,
## le decodeur du client d origine, table de 150 effets de 0xA8 octets) ; les
## trois octets « (?) » de P1-99 ont un sens :
##   en-tete 4 : u8 nombre d ENTREES du paquet, u8 0, u8 1 (icons, 1.105+), u8 0 ;
##   par entree : u8 case (0..), u8 source d icone (0xFF = capacite dont
##   l icone <= 5000, sinon = la case), u8 immunite / effet desactive
##   (« protected by » au clic droit dans l original), u16 ICONE (1 = Amethyst
##   Shield, la marche spells.csv de P1-88 donne l icone 1000), u16 SECONDES
##   restantes (0x04b0 = 1200 = 20 min), u16 TooltipId (l InternalID du sort :
##   c est CE nombre que le clic droit renvoie en 0xF8 pour annuler, et que le
##   client d origine range a +0x4c de sa table), u8 1 si l effet est NEGATIF
##   (0 = positif), nom Pascal.
## LA LISTE N EST PAS COMPLETE EN 1.110+ : le serveur n envoie que les entrees
## qui ont change, et une case liberee arrive comme la case suivie de dix
## octets a zero (icone 0, nom vide). P1-99 croyait la liste toujours complete
## parce qu un seul effet avait ete observe : `apply_update_icons` fusionne
## desormais par case, et une entree a icone 0 efface la sienne.
const OPCODE_UPDATE_ICONS := 0x7F


static func decode_update_icons(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "update_icons_too_short", "size": payload.size()}
	var count := int(payload[0])
	var effects: Array = []
	var offset := 4
	for i in range(count):
		if offset + 11 > payload.size():
			return {"ok": false, "error": "update_icons_effect_truncated", "index": i}
		var name_size := int(payload[offset + 10])
		if offset + 11 + name_size > payload.size():
			return {"ok": false, "error": "update_icons_name_truncated", "index": i}
		var icon := _u16(payload, offset + 3)
		var tooltip_id := _u16(payload, offset + 7)
		effects.append({
			"index": int(payload[offset]),
			"icon_source": int(payload[offset + 1]),
			"ability_icon": int(payload[offset + 1]) == 0xFF,
			"immunity": int(payload[offset + 2]) != 0,
			"icon": icon,
			"remaining_seconds": _u16(payload, offset + 5),
			"tooltip_id": tooltip_id,
			# Compatibilite P1-99 : `effect_id` etait le u16 a +7, c est le TooltipId.
			"effect_id": tooltip_id,
			"negative": int(payload[offset + 9]) != 0,
			"name": payload.slice(offset + 11, offset + 11 + name_size).get_string_from_ascii(),
			"removed": icon == 0 and name_size == 0,
		})
		offset += 11 + name_size
	return {"ok": true, "count": count, "header": [int(payload[1]), int(payload[2]), int(payload[3])],
		"effects": effects, "trailing_bytes": payload.size() - offset}


## Fusionne un 0x7F decode dans la liste courante (par case) : une entree
## `removed` libere sa case, les autres remplacent la leur. Rend la liste
## complete triee par case.
static func apply_update_icons(current: Array, decoded: Dictionary) -> Array:
	var by_index: Dictionary = {}
	for value in current:
		var effect := value as Dictionary
		by_index[int(effect.get("index", 0))] = effect
	for value in decoded.get("effects", []) as Array:
		var effect := value as Dictionary
		var index := int(effect.get("index", 0))
		if bool(effect.get("removed", false)):
			by_index.erase(index)
		else:
			by_index[index] = effect.duplicate(true)
	var keys: Array = by_index.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		out.append(by_index[key])
	return out


## P1-108 — 0xF8 PlayerCancelsEffect, tel que le client d origine le construit
## (`FUN_0042af96` : u16 htons(id), u16 poubelle — ici 0 ; 4 octets) sur le
## clic droit d une case de la barre d effets (`FUN_0042081b` rend le +0x4c de
## la table = TooltipId). DOL 1.110+ : `TryGetEffectByTooltipId(effectId).End()`.
static func build_cancel_effect_payload(tooltip_id: int) -> PackedByteArray:
	return PackedByteArray([(tooltip_id >> 8) & 0xff, tooltip_id & 0xff, 0, 0])


## P1-108 — 0x75 ConcentrationList (`PacketLib168.SendConcentrationList`, relu
## dans OpenDAoC ; `FUN_0041ccef` du client d origine lit la meme chose) :
## u8 nombre, u8 0, u8 0, u8 0, puis par effet u8 index, u8 0, u8 concentration
## consommee, u16 icone, nom Pascal (tronque a 12 + « .. » au-dela de 14),
## proprietaire Pascal (le nom de la cible qui porte le buff).
const OPCODE_CONCENTRATION_LIST := 0x75


static func decode_concentration_list(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "concentration_list_too_short", "size": payload.size()}
	var count := int(payload[0])
	var effects: Array = []
	var offset := 4
	for i in range(count):
		if offset + 6 > payload.size():
			return {"ok": false, "error": "concentration_effect_truncated", "index": i}
		var entry := {"index": int(payload[offset]), "concentration": int(payload[offset + 2]), "icon": _u16(payload, offset + 3)}
		offset += 5
		var name_size := int(payload[offset])
		if offset + 1 + name_size >= payload.size():
			return {"ok": false, "error": "concentration_name_truncated", "index": i}
		entry["name"] = payload.slice(offset + 1, offset + 1 + name_size).get_string_from_ascii()
		offset += 1 + name_size
		var owner_size := int(payload[offset])
		if offset + 1 + owner_size > payload.size():
			return {"ok": false, "error": "concentration_owner_truncated", "index": i}
		entry["owner"] = payload.slice(offset + 1, offset + 1 + owner_size).get_string_from_ascii()
		offset += 1 + owner_size
		effects.append(entry)
	return {"ok": true, "count": count, "effects": effects, "trailing_bytes": payload.size() - offset}


## P1-108 — 0x76 RemoveConcentrationEffect (`FUN_0042afcb` : u8 index 0..49
## puis trois octets, 4 en tout ; DOL `StopConcentrationEffect(index)`).
static func build_remove_concentration_payload(index: int) -> PackedByteArray:
	return PackedByteArray([index & 0xff, 0, 0, 0])


## P1-108 — 0xD6 DisableSkills (`PacketLib168.SendDisableSkill`, relu dans
## OpenDAoC ; l opcode n est PAS 0x7E, qui est l heure — `FUN_0041aa21` du
## client d origine le confirme). u16 duree en SECONDES, u8 nombre, u8 code :
##   code 2 (sorts de liste) : par entree u8 index de LIGNE, u8 index du sort
##     dans la ligne, tous a la duree de l en-tete ;
##   code 1 (competences hybrides, styles, capacites) : u16 index dans la liste
##     des competences HORS specialisations (la regle de send_use_skill), u16
##     duree propre, et la duree de l en-tete vaut 0.
## Une duree de 0 REACTIVE la competence. Le client d origine range
## GetTickCount() + duree * 1000 par competence et grise la case tant que
## l echeance n est pas passee.
## MESURE sur un paquet REEL (capture P1-20D du 2026-09-07, entree monde de
## Heyveno, 100 octets) : `00 00 18 01 | 00 00 00 00 | 00 01 00 00 | ... |
## 00 17 00 00` = duree 0, 24 competences, code 1, index 0..23 tous a 0 —
## DOL remet les delais a zero a l entree monde.
const OPCODE_DISABLE_SKILLS := 0xD6


static func decode_disable_skills(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "disable_skills_too_short", "size": payload.size()}
	var duration := _u16(payload, 0)
	var count := int(payload[2])
	var code := int(payload[3])
	var entries: Array = []
	var offset := 4
	if code == 2:
		for i in range(count):
			if offset + 2 > payload.size():
				return {"ok": false, "error": "disable_spell_truncated", "index": i}
			entries.append({"kind": "spell", "line_index": int(payload[offset]), "spell_index": int(payload[offset + 1]), "seconds": duration})
			offset += 2
	elif code == 1:
		for i in range(count):
			if offset + 4 > payload.size():
				return {"ok": false, "error": "disable_skill_truncated", "index": i}
			entries.append({"kind": "skill", "skill_index": _u16(payload, offset), "seconds": _u16(payload, offset + 2)})
			offset += 4
	else:
		return {"ok": false, "error": "disable_skills_unknown_code", "code": code}
	return {"ok": true, "code": code, "duration": duration, "count": count, "entries": entries, "trailing_bytes": payload.size() - offset}


## P1-108 — 0x88 PetWindow (`PacketLib168.SendPetWindow`, relu dans OpenDAoC ;
## `FUN_00422d45` du client d origine — meme opcode que la position 0x88 de
## l ENTREE MONDE, que DaocOnlineWorldEntry consomme avant PLAYING) : u16 id
## d objet du pet (0 = aucun), u8 0, u8 0, u8 action (0 fermer, 1 mettre a
## jour, 2 ouvrir), u8 agressivite (1 agressif, 2 defensif, 3 passif), u8
## deplacement (1 suivre, 2 rester, 3 aller a la cible, 4 venir), u8 0, puis
## jusqu a 9 u16 icones d effets du pet, u8 0 final.
const OPCODE_PET_WINDOW := 0x88
const PET_AGGRO := {0: "", 1: "aggressive", 2: "defensive", 3: "passive"}
const PET_WALK := {0: "", 1: "follow", 2: "stay", 3: "go_target", 4: "come_here"}
const PET_ACTIONS := {0: "close", 1: "update", 2: "open"}


static func decode_pet_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 8:
		return {"ok": false, "error": "pet_window_too_short", "size": payload.size()}
	var icons: Array = []
	var offset := 8
	while offset + 2 <= payload.size():
		var icon := _u16(payload, offset)
		if icon == 0:
			break
		icons.append(icon)
		offset += 2
	return {"ok": true, "pet_id": _u16(payload, 0), "action_code": int(payload[4]), "action": str(PET_ACTIONS.get(int(payload[4]), "unknown")),
		"aggro_code": int(payload[5]), "aggro": str(PET_AGGRO.get(int(payload[5]), "unknown")),
		"walk_code": int(payload[6]), "walk": str(PET_WALK.get(int(payload[6]), "unknown")), "icons": icons}


## P1-108 — 0x8A PetWindow client (`FUN_0042adb2` : u8 agressivite, u8
## deplacement, u8 commande, u8 poubelle — 4 octets ; DOL `PetWindowHandler`
## lit les trois et ignore un 0). Commande : 1 attaquer, 2 relacher.
const PET_COMMANDS := {"attack": 1, "release": 2}


static func build_pet_window_payload(aggro: int, walk: int, command: int) -> PackedByteArray:
	return PackedByteArray([aggro & 0xff, walk & 0xff, command & 0xff, 0])


## P1-102 — 0xC4 DetailWindow (SendCustomTextWindow), MESURE en live le
## 2026-09-21 sur le delve du baton « trimmed branch » (207 octets) :
##   00 00 | 0e "trimmed branch" | 01 13 "Total utility: 0.00" | 02 01 " " ...
##   | 0d 09 "- 1.1 DPS" | 00
## u8 0, u8 0, titre Pascal, puis lignes (u8 numero a partir de 1, texte
## Pascal), et un 0 final.
const OPCODE_DETAIL_WINDOW := 0xC4


static func decode_detail_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "detail_window_too_short", "size": payload.size()}
	var offset := 2
	var caption_size := int(payload[offset])
	if offset + 1 + caption_size > payload.size():
		return {"ok": false, "error": "detail_window_caption_truncated"}
	var caption := payload.slice(offset + 1, offset + 1 + caption_size).get_string_from_ascii()
	offset += 1 + caption_size
	var lines: Array = []
	while offset < payload.size():
		var index := int(payload[offset])
		if index == 0:
			offset += 1
			break
		if offset + 2 > payload.size():
			return {"ok": false, "error": "detail_window_line_truncated", "line": index}
		var size := int(payload[offset + 1])
		if offset + 2 + size > payload.size():
			return {"ok": false, "error": "detail_window_line_text_truncated", "line": index}
		lines.append(payload.slice(offset + 2, offset + 2 + size).get_string_from_ascii())
		offset += 2 + size
	return {"ok": true, "caption": caption, "lines": lines, "header": [int(payload[0]), int(payload[1])], "trailing_bytes": payload.size() - offset}
