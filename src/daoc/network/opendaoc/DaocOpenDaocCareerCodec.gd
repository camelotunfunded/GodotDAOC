extends RefCounted
class_name DaocOpenDaocCareerCodec

## P1-109 — la carriere du personnage : rangs de royaume, titres, Master
## Levels, Champion Levels, niveau gratuit, liste des bonus. Tout est lu dans
## DOL (`DOLSharp-master`, remis sur le disque le 21/09) et confronte a
## game.dll (`sources tierces daoc/eden.dll.c`) pour ce que le client ENVOIE.
##
##   Rang de royaume : DOL `GamePlayer.REALMPOINTS_FOR_LEVEL` (131 seuils,
##   RR14L0 = niveau 130) et `CalculateRealmLevelFromRPs` ; au-dela de la table,
##   la formule de Linulo. Le titre : `GlobalConstants.REALM_RANK_NAMES`
##   [royaume][sexe][niveau / 10]. « RR5L3 = 43 » (commentaire DOL) : rang =
##   niveau / 10 + 1, echelon = niveau % 10.
##
##   Titres : `/settitle` sans argument -> 0xC4 DetailWindow AVEC l octet 0 a
##   1 (PacketLib1113/181.SendPlayerTitles) : 1, 0, « Player Statistics »,
##   lignes (u8 numero, Pascal), puis 200, [u8 longueur du bloc en 1.81+],
##   u8 nombre de titres, (u8 index, Pascal) x n, 0. `/settitle <index>`
##   choisit ; le serveur confirme par 0x4C VisualEffect sous-code 0x0B
##   (u16 oid, 0x0B, u8 drapeau, [u16 longueur, u16 0, texte]).
##
##   Niveau gratuit : 0x4C sous-code 0x09 (PacketLib171) : u16 oid, 0x09,
##   u8 etat (1 au-dessus du niveau, 2 eligible, 3 delai, 4 niveau + delai,
##   5 niveau), u16 0, u16 minutes restantes. `/freelevel` le reclame,
##   `/freelevel decline` le refuse.
##
##   Master Levels : 0x13 MasterLevelWindow (PacketLib190) : u8 % MLXP, u8 %
##   d etapes, u8 ML courant + 1, 0, u16 0, u16 0, u8 ML demande, 10 x
##   description Pascal, 0. Le serveur l envoie a l entree monde (ML 0) et
##   sur la reponse au dialogue 0x19 (DialogResponseHandler).
##
##   Champion Levels : 0x7B TrainerWindow code 2 (PacketLib168
##   .SendChampionTrainerWindow) : u8 index de ligne, u8 points CL, 2, 0, u8
##   nombre de sous-lignes, puis par sous-ligne u8 numero, u8 nombre, et par
##   competence u8 numero, u8 genre (1 capacite, 2 style, 3 sort), u16 icone
##   PETIT-boutiste, nom Pascal, u8 statut (0 grise, 1 acquise, 2 formable),
##   u8 nombre d attaches, attaches. Le clic forme par 0x7C TrainRequest,
##   12 octets (game.dll FUN_0042b3d6 puis htons) : u32 0, u32 0, u8 ligne,
##   u8 1, u8 rangee, u8 competence. Le meme 0x7C avec ligne 0 forme UNE spe
##   (u8 competence = index) ou UNE capacite de royaume (index + 100,
##   FUN_0042b41e) - la voie « un clic » du client, a cote du 0x53 de P1-107.
##
##   Bonus : 0xCA BonusesListRequest, 1 octet nul (game.dll FUN_0042a0af,
##   DOL PlayerBonusesListRequestHandler) ; le serveur repond par un 0xC4
##   « Bonuses » ordinaire.

const OPCODE_VISUAL_EFFECT := 0x4C
const OPCODE_MASTER_LEVEL_WINDOW := 0x13
const OPCODE_BONUSES_REQUEST := 0xCA
const OPCODE_TRAIN_REQUEST := 0x7C
const SUBCODE_FREE_LEVEL := 0x09
const SUBCODE_TITLE_UPDATE := 0x0B
const TRAINER_CODE_CHAMPION := 2
const TITLES_SEPARATOR := 200
const RA_TRAIN_OFFSET := 100

const REALMPOINTS_FOR_LEVEL: Array = [
	0, 0, 25, 125, 350, 750, 1375, 2275, 3500, 5100, 7125, 9625, 12650, 16250, 20475, 25375, 31000, 37400, 44625, 52725,
	61750, 71750, 82775, 94875, 108100, 122500, 138125, 155025, 173250, 192850, 213875, 236375, 260400, 286000, 313225, 342125,
	372750, 405150, 439375, 475475, 513500, 553500, 595525, 639625, 685850, 734250, 784875, 837775, 893000, 950600, 1010625,
	1073125, 1138150, 1205750, 1275975, 1348875, 1424500, 1502900, 1584125, 1668225, 1755250, 1845250, 1938275, 2034375,
	2133600, 2236000, 2341625, 2450525, 2562750, 2678350, 2797375, 2919875, 3045900, 3175500, 3308725, 3445625, 3586250,
	3730650, 3878875, 4030975, 4187000, 4347000, 4511025, 4679125, 4851350, 5027750, 5208375, 5393275, 5582500, 5776100,
	5974125, 6176625, 6383650, 6595250, 6811475, 7032375, 7258000, 7488400, 7723625, 7963725, 8208750, 9111713, 10114001,
	11226541, 12461460, 13832221, 15353765, 17042680, 18917374, 20998286, 23308097, 25871988, 28717906, 31876876, 35383333,
	39275499, 43595804, 48391343, 53714390, 59622973, 66181501, 73461466, 81542227, 90511872, 100468178, 111519678,
	123786843, 137403395, 152517769, 169294723, 187917143,
]

## [royaume 1..3][sexe 0 homme / 1 femme][rang 0..13] — GlobalConstants.REALM_RANK_NAMES.
const REALM_RANK_NAMES := {
	1: [["Guardian", "Warder", "Myrmidon", "Gryphon Knight", "Eagle Knight", "Phoenix Knight", "Alerion Knight", "Unicorn Knight", "Lion Knight", "Dragon Knight", "Lord", "Baronet", "Baron", "Arch Duke"],
		["Guardian", "Warder", "Myrmidon", "Gryphon Knight", "Eagle Knight", "Phoenix Knight", "Alerion Knight", "Unicorn Knight", "Lion Knight", "Dragon Knight", "Lady", "Baronetess", "Baroness", "Arch Duchess"]],
	2: [["Skiltvakten", "Isen Vakten", "Flammen Vakten", "Elding Vakten", "Stormur Vakten", "Isen Herra", "Flammen Herra", "Elding Herra", "Stormur Herra", "Einherjar", "Herra", "Hersir", "Vicomte", "Stor Jarl"],
		["Skiltvakten", "Isen Vakten", "Flammen Vakten", "Elding Vakten", "Stormur Vakten", "Isen Fru", "Flammen Fru", "Elding Fru", "Stormur Fru", "Einherjar", "Fru", "Baronsfru", "Vicomtessa", "Stor Hurfru"]],
	3: [["Savant", "Cosantoir", "Brehon", "Grove Protector", "Raven Ardent", "Silver Hand", "Thunderer", "Gilded Spear", "Tiarna", "Emerald Ridere", "Barun", "Ard Tiarna", "Ciann Cath", "Ard Diuc"],
		["Savant", "Cosantoir", "Brehon", "Grove Protector", "Raven Ardent", "Silver Hand", "Thunderer", "Gilded Spear", "Bantiarna", "Emerald Ridere", "Banbharun", "Ard Bantiarna", "Ciann Cath", "Ard Bandiuc"]],
}

const FREE_LEVEL_STATES := {1: "above_level", 2: "eligible", 3: "waiting", 4: "level_and_waiting", 5: "level_waiting"}
const CHAMPION_SKILL_KINDS := {1: "ability", 2: "style", 3: "spell"}
const CHAMPION_STATUS := {0: "locked", 1: "trained", 2: "trainable"}


## DOL CalculateRPsFromRealmLevel : la table, puis la formule de Linulo.
static func realm_points_for_level(realm_level: int) -> int:
	if realm_level < 0:
		return 0
	if realm_level < REALMPOINTS_FOR_LEVEL.size():
		return int(REALMPOINTS_FOR_LEVEL[realm_level])
	var l := float(realm_level)
	return int(25.0 / 3.0 * (l * l * l) - 25.0 / 2.0 * (l * l) + 25.0 / 6.0 * l)


## DOL CalculateRealmLevelFromRPs : 0 sans point, sinon le plus haut seuil
## atteint dans la table (elle s arrete a 130 = RR14L0).
static func realm_level_from_points(realm_points: int) -> int:
	if realm_points <= 0:
		return 0
	for i in range(REALMPOINTS_FOR_LEVEL.size() - 1, 0, -1):
		if int(REALMPOINTS_FOR_LEVEL[i]) <= realm_points:
			return i
	return 0


## « RR5L3 = 43 » : rang = niveau / 10 + 1, echelon = niveau % 10.
static func realm_rank_of(realm_level: int) -> Dictionary:
	var level := maxi(0, realm_level)
	return {"rank": level / 10 + 1, "step": level % 10, "label": "RR%dL%d" % [level / 10 + 1, level % 10]}


## GamePlayer.RealmTitle : REALM_RANK_NAMES[royaume][sexe][niveau / 10].
static func realm_rank_title(realm: int, realm_level: int, female: bool = false) -> String:
	if not REALM_RANK_NAMES.has(realm):
		return "Unknown Realm"
	var names: Array = (REALM_RANK_NAMES[realm] as Array)[1 if female else 0]
	var index := maxi(0, realm_level) / 10
	if index >= names.size():
		return "Unknown Rank"
	return str(names[index])


## Le 0x91 de P1-78 enrichi de ce que le client d origine affiche : le niveau
## de royaume, le rang, le titre, les points jusqu au prochain echelon.
static func describe_realm_points(points: Dictionary, realm: int, female: bool = false) -> Dictionary:
	var rp := int(points.get("realm_points", 0))
	var level := realm_level_from_points(rp)
	var rank := realm_rank_of(level)
	var next_level := level + 1
	var next_needed := realm_points_for_level(next_level)
	return {
		"realm_points": rp,
		"bounty_points": int(points.get("bounty_points", 0)),
		"realm_level": level,
		"realm_rank": int(rank["rank"]),
		"realm_rank_step": int(rank["step"]),
		"realm_rank_label": str(rank["label"]),
		"realm_title": realm_rank_title(realm, level, female),
		"next_level_points": next_needed,
		"points_to_next_level": maxi(0, next_needed - rp),
	}


## 0xC4 avec l octet 0 a 1 : « Player Statistics » puis le bloc des titres.
static func decode_titles_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "titles_window_too_short", "size": payload.size()}
	if int(payload[0]) != 1:
		return {"ok": false, "error": "titles_window_flag_not_set", "flag": int(payload[0])}
	var offset := 2
	var caption := _pascal(payload, offset)
	if not bool(caption.get("ok", false)):
		return {"ok": false, "error": "titles_window_caption_truncated"}
	offset = int(caption["next"])
	var lines: Array = []
	var titles: Array = []
	var separator_seen := false
	while offset < payload.size():
		var index := int(payload[offset])
		if index == 0:
			offset += 1
			break
		if index == TITLES_SEPARATOR:
			separator_seen = true
			offset += 1
			break
		var line := _pascal(payload, offset + 1)
		if not bool(line.get("ok", false)):
			return {"ok": false, "error": "titles_window_line_truncated", "line": index}
		lines.append(str(line["text"]))
		offset = int(line["next"])
	var block_length := -1
	if separator_seen:
		if offset >= payload.size():
			return {"ok": false, "error": "titles_window_count_truncated"}
		# 1.81+ : u8 longueur du bloc AVANT le nombre ; 1.75 : le nombre tout de
		# suite. La longueur se reconnait a ce qu elle tombe EXACTEMENT sur le
		# zero final du paquet (PacketLib181 la mesure du nombre au dernier
		# titre inclus).
		var first := int(payload[offset])
		var count := first
		var block_end := offset + 1 + first
		if offset + 1 < payload.size() and (block_end == payload.size() - 1 or block_end == payload.size()):
			block_length = first
			count = int(payload[offset + 1])
			offset += 2
		else:
			offset += 1
		for i in range(count):
			if offset >= payload.size():
				return {"ok": false, "error": "titles_window_title_truncated", "index": i}
			var title_index := int(payload[offset])
			var title := _pascal(payload, offset + 1)
			if not bool(title.get("ok", false)):
				return {"ok": false, "error": "titles_window_title_text_truncated", "index": i}
			titles.append({"index": title_index, "text": str(title["text"])})
			offset = int(title["next"])
		if offset < payload.size() and int(payload[offset]) == 0:
			offset += 1
	return {"ok": true, "caption": str(caption["text"]), "lines": lines, "titles": titles,
		"block_length": block_length, "trailing_bytes": payload.size() - offset}


## Les 0x4C que ce jalon lit ; les autres sous-codes restent {"ok": false}.
static func decode_visual_effect(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 3:
		return {"ok": false, "error": "visual_effect_too_short", "size": payload.size()}
	var object_id := _u16(payload, 0)
	var subcode := int(payload[2])
	if subcode == SUBCODE_FREE_LEVEL:
		if payload.size() < 8:
			return {"ok": false, "error": "free_level_too_short", "size": payload.size()}
		var state := int(payload[3])
		return {"ok": true, "kind": "free_level", "object_id": object_id, "subcode": subcode, "state": state,
			"state_name": str(FREE_LEVEL_STATES.get(state, "state_%d" % state)),
			"minutes_remaining": _u16(payload, 6), "eligible": state == 2 or state == 5}
	if subcode == SUBCODE_TITLE_UPDATE:
		if payload.size() < 8:
			return {"ok": false, "error": "title_update_too_short", "size": payload.size()}
		var flag := int(payload[3])
		var title := ""
		if flag != 0:
			var length := _u16(payload, 4)
			if 8 + length > payload.size():
				return {"ok": false, "error": "title_update_text_truncated"}
			title = payload.slice(8, 8 + length).get_string_from_ascii()
		return {"ok": true, "kind": "title_update", "object_id": object_id, "subcode": subcode, "cleared": flag == 0, "title": title}
	return {"ok": false, "error": "visual_effect_subcode_not_handled", "object_id": object_id, "subcode": subcode}


## 0x13 MasterLevelWindow.
static func decode_master_level_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 9:
		return {"ok": false, "error": "master_level_window_too_short", "size": payload.size()}
	var out := {
		"ok": true,
		"experience_percent": int(payload[0]),
		"steps_percent": int(payload[1]),
		"current_level_plus_one": int(payload[2]),
		"current_level": maxi(0, int(payload[2]) - 1),
		"requested_level": int(payload[8]),
		"steps": [],
	}
	var offset := 9
	var steps: Array = []
	for i in range(10):
		var step := _pascal(payload, offset)
		if not bool(step.get("ok", false)):
			break
		steps.append({"step": i + 1, "description": str(step["text"])})
		offset = int(step["next"])
	out["steps"] = steps
	if offset < payload.size() and int(payload[offset]) == 0:
		offset += 1
	out["trailing_bytes"] = payload.size() - offset
	return out


## 0x7B code 2 : la page Champion d un entraineur.
static func decode_champion_trainer_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 5 or int(payload[2]) != TRAINER_CODE_CHAMPION:
		return {"ok": false, "error": "not_a_champion_trainer_window", "size": payload.size()}
	var out := {"ok": true, "kind": "champion", "line_index": int(payload[0]), "champion_points": int(payload[1]), "sublines": []}
	var offset := 5
	var sublines: Array = []
	for s in range(int(payload[4])):
		if offset + 2 > payload.size():
			return {"ok": false, "error": "champion_subline_truncated", "subline": s}
		var subline := {"row": int(payload[offset]), "skills": []}
		var count := int(payload[offset + 1])
		offset += 2
		var skills: Array = []
		for k in range(count):
			if offset + 4 > payload.size():
				return {"ok": false, "error": "champion_skill_truncated", "subline": s, "skill": k}
			var kind := int(payload[offset + 1])
			var icon := int(payload[offset + 2]) | (int(payload[offset + 3]) << 8)
			var name := _pascal(payload, offset + 4)
			if not bool(name.get("ok", false)):
				return {"ok": false, "error": "champion_skill_name_truncated", "subline": s, "skill": k}
			offset = int(name["next"])
			if offset + 2 > payload.size():
				return {"ok": false, "error": "champion_skill_status_truncated", "subline": s, "skill": k}
			var status := int(payload[offset])
			var attached_count := int(payload[offset + 1])
			offset += 2
			var attached: Array = []
			for a in range(attached_count):
				if offset >= payload.size():
					return {"ok": false, "error": "champion_attached_truncated"}
				attached.append(int(payload[offset]))
				offset += 1
			skills.append({"column": k + 1,
				"kind": str(CHAMPION_SKILL_KINDS.get(kind, "kind_%d" % kind)), "kind_code": kind, "icon": icon,
				"name": str(name["text"]), "status": str(CHAMPION_STATUS.get(status, "status_%d" % status)),
				"status_code": status, "attached": attached})
		subline["skills"] = skills
		sublines.append(subline)
	out["sublines"] = sublines
	out["trailing_bytes"] = payload.size() - offset
	return out


## 0x7C TrainRequest, 12 octets : u32 0, u32 0, u8 ligne, u8 1, u8 rangee,
## u8 competence (FUN_0042b3d6 : les u16 sont ecrits puis passes par htons,
## d ou l ordre ligne, 1, rangee, competence sur le fil).
static func build_champion_train_payload(line_index: int, row: int, column: int) -> PackedByteArray:
	return PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, line_index & 0xff, 1, row & 0xff, column & 0xff])


## 0x7C avec ligne 0 : forme UNE spe (index) ou UNE capacite de royaume
## (index + 100) — FUN_0042b41e ; DOL PlayerTrainRequestHandler lit
## skillIndex a l octet 11.
static func build_train_one_payload(index: int, realm_ability: bool = false) -> PackedByteArray:
	var skill := index + (RA_TRAIN_OFFSET if realm_ability else 0)
	return PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, skill & 0xff])


static func build_bonuses_request_payload() -> PackedByteArray:
	return PackedByteArray([0])


## Encodeurs pour les suites a faux pair.
static func encode_titles_window(lines: Array, titles: Array, with_block_length: bool = true) -> PackedByteArray:
	var out := PackedByteArray([1, 0])
	_write_pascal(out, "Player Statistics")
	for i in lines.size():
		out.append(i + 1)
		_write_pascal(out, str(lines[i]))
	out.append(TITLES_SEPARATOR)
	var block := PackedByteArray([titles.size() & 0xff])
	for i in titles.size():
		block.append(i)
		_write_pascal(block, str(titles[i]))
	if with_block_length:
		out.append(block.size() & 0xff)
	out.append_array(block)
	out.append(0)
	return out


static func encode_free_level(object_id: int, state: int, minutes: int) -> PackedByteArray:
	return PackedByteArray([(object_id >> 8) & 0xff, object_id & 0xff, SUBCODE_FREE_LEVEL, state & 0xff, 0, 0, (minutes >> 8) & 0xff, minutes & 0xff])


static func encode_title_update(object_id: int, title: String) -> PackedByteArray:
	var out := PackedByteArray([(object_id >> 8) & 0xff, object_id & 0xff, SUBCODE_TITLE_UPDATE])
	if title == "":
		out.append_array(PackedByteArray([0, 0, 0, 0, 0]))
		return out
	out.append(1)
	out.append_array(PackedByteArray([(title.length() >> 8) & 0xff, title.length() & 0xff, 0, 0]))
	out.append_array(title.to_ascii_buffer())
	return out


static func encode_master_level_window(xp_percent: int, steps_percent: int, current_level: int, requested: int, steps: Array) -> PackedByteArray:
	var out := PackedByteArray([xp_percent & 0xff, steps_percent & 0xff, (current_level + 1) & 0xff, 0, 0, 0, 0, 0, requested & 0xff])
	for i in range(10):
		_write_pascal(out, str(steps[i]) if i < steps.size() else "")
	out.append(0)
	return out


## `sublines` : [{"skills": [{"kind_code", "icon", "name", "status_code", "attached": []}]}]
static func encode_champion_trainer_window(line_index: int, points: int, sublines: Array) -> PackedByteArray:
	var out := PackedByteArray([line_index & 0xff, points & 0xff, TRAINER_CODE_CHAMPION, 0, sublines.size() & 0xff])
	for s in sublines.size():
		var skills: Array = (sublines[s] as Dictionary).get("skills", [])
		out.append(s + 1)
		out.append(skills.size() & 0xff)
		for k in skills.size():
			var skill := skills[k] as Dictionary
			out.append(k + 1)
			out.append(int(skill.get("kind_code", 1)))
			var icon := int(skill.get("icon", 0))
			out.append(icon & 0xff)
			out.append((icon >> 8) & 0xff)
			_write_pascal(out, str(skill.get("name", "")))
			out.append(int(skill.get("status_code", 0)))
			var attached: Array = skill.get("attached", [])
			out.append(attached.size() & 0xff)
			for a in attached:
				out.append(int(a) & 0xff)
	return out


static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": payload.slice(offset + 1, offset + 1 + size).get_string_from_ascii(), "next": offset + 1 + size}


static func _write_pascal(out: PackedByteArray, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	out.append(bytes.size() & 0xff)
	out.append_array(bytes)


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])
