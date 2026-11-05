extends RefCounted
class_name DaocOpenDaocQuestSocialCodec

## P1-110 — quêtes, PNJ, joueurs distants, social. Lu dans DOL
## (`DOLSharp-master`) et confronté à game.dll (`eden.dll.c`) pour ce que le
## client ENVOIE.
##
##   Fenêtres d offre / de récompense : 0x81 Dialog dont le PREMIER u16 est
##   0x22 (offre : Accepter / Refuser) ou 0x21 (récompense : Terminer / Pas
##   encore) — PacketLib194.SendQuestWindow : u16 code, u16 id de quête, u16
##   oid du PNJ, 4 x 0, u8 2/1, u8 1, nom Pascal, résumé Pascal, u16 longueur
##   + histoire (offre) ou texte de fin (récompense), u16 id de quête, u8
##   nombre d objectifs, objectifs Pascal (terminés par \r), u32 argent, u8 %
##   d expérience, u8 nombre de récompenses fixes + objets (WriteItemData
##   1.124 : 24 octets + nom Pascal), u8 nombre de choix, u8 nombre de
##   récompenses au choix + objets. La réponse est 0x40 QuestRewardChosen,
##   20 octets (game.dll FUN_0042bfxx, DOL QuestRewardChosenHandler) : u8
##   réponse (1 = accepter / terminer, sinon ignoré), u8 nombre choisi, 8 x u8
##   index choisis, 3 x u16 0, u16 id de quête, u16 oid du PNJ.
##
##   Journal : 0x83 QuestEntry (P1-78) ; l index 0 est la TÂCHE
##   (PacketLib184.SendTaskInfo : u8 0, u16 LE longueur, 3 x 0, texte).
##   Abandon : 0x4F RemoveQuestRequest, 8 octets (game.dll FUN_0042a1f2) : u16
##   0, u16 index, u16 0, u16 0 — DOL compte les quêtes actives dans l ordre.
##
##   Icône de quête : 0x4C VisualEffect sous-code 0x07 (PacketLib173
##   .SendNPCsQuestEffect) : u16 oid, 0x07, u8 indicateur (0 rien, 1
##   disponible, 2 à rendre, 4 leçon, 8 lore, 0x10 en cours), u32 0.
##
##   Modèle et taille : 0xDB ModelChange (PacketLib168.SendModelAndSizeChange) :
##   u16 oid, u16 modèle, u32 PETIT-boutiste taille (0 = inchangée).
##
##   LFG : 0x84 LookingForGroupFlag et 0x85 LookingForGroup, 124 octets chacun
##   (game.dll FUN_0042a4xx : l octet 0 est le drapeau / « déjà groupé », le
##   reste des zéros) ; DOL ne lit que le premier octet. 0x86 FindGroupUpdate
##   (PacketLib176) : u8 nombre, puis par joueur u8 index (chefs 0.., solos
##   0x1E..), u8 niveau, nom Pascal, classe sur 4 octets, u16 zone, u8 durée,
##   u8 objectif, u8 0, u8 0, u8 groupé, u8 0.
##
##   Emblème : 0xE2 EmblemDialogue (4 zéros) ouvre la fenêtre ; la réponse est
##   0xE2 client, 4 octets (game.dll FUN_0042bdd5) : u8 couleur 1 (4 bits), u8
##   couleur 2 (3 bits), u8 motif (2 bits), u8 logo — DOL
##   EmblemDialogReponseHandler exige le rang de chef de guilde.
##
##   Ramasser : 0xB5 PickUpRequest, UN octet nul (game.dll FUN_0042a89e) ;
##   DOL lit x, y, id, oid dans le vide et prend de toute façon la CIBLE du
##   joueur (PlayerPickUpRequestHandler) — cibler le sac, puis 0xB5.

const OPCODE_DIALOG := 0x81
const OPCODE_QUEST_ENTRY := 0x83
const OPCODE_QUEST_REWARD_CHOSEN := 0x40
const OPCODE_REMOVE_QUEST := 0x4F
const OPCODE_VISUAL_EFFECT := 0x4C
const OPCODE_MODEL_CHANGE := 0xDB
const OPCODE_LFG_FLAG := 0x84
const OPCODE_LFG_LIST := 0x85
const OPCODE_FIND_GROUP_UPDATE := 0x86
const OPCODE_EMBLEM_DIALOGUE := 0xE2
const OPCODE_PICKUP := 0xB5
const SUBCODE_QUEST_INDICATOR := 0x07
const QUEST_WINDOW_OFFER := 0x22
const QUEST_WINDOW_REWARD := 0x21
const LFG_PAYLOAD_SIZE := 124
const ITEM_FIXED_SIZE := 24

const QUEST_INDICATORS := {0: "none", 1: "available", 2: "finish", 4: "lesson", 8: "lore", 16: "pending"}
const QUEST_INDICATOR_GLYPHS := {"available": "!", "finish": "?", "lesson": "L", "lore": "i", "pending": "…"}


static func is_quest_window(payload: PackedByteArray) -> bool:
	return payload.size() >= 12 and int(payload[0]) == 0 and (int(payload[1]) == QUEST_WINDOW_OFFER or int(payload[1]) == QUEST_WINDOW_REWARD)


static func decode_quest_window(payload: PackedByteArray) -> Dictionary:
	if not is_quest_window(payload):
		return {"ok": false, "error": "not_a_quest_window", "size": payload.size()}
	var code := int(payload[1])
	var out := {
		"ok": true, "kind": "offer" if code == QUEST_WINDOW_OFFER else "reward", "code": code,
		"quest_id": _u16(payload, 2), "npc_object_id": _u16(payload, 4), "buttons": int(payload[10]), "wrap": int(payload[11]) != 0,
		"name": "", "summary": "", "story": "", "goals": [], "money": 0, "experience_percent": 0,
		"rewards": [], "optional_choices": 0, "optional_rewards": [],
	}
	var name := _pascal(payload, 12)
	if not bool(name.get("ok", false)):
		return {"ok": false, "error": "quest_window_name_truncated"}
	out["name"] = str(name["text"])
	var summary := _pascal(payload, int(name["next"]))
	if not bool(summary.get("ok", false)):
		return {"ok": false, "error": "quest_window_summary_truncated"}
	out["summary"] = str(summary["text"])
	var offset := int(summary["next"])
	if offset + 2 > payload.size():
		return {"ok": false, "error": "quest_window_story_truncated"}
	var story_length := _u16(payload, offset)
	offset += 2
	if offset + story_length > payload.size():
		return {"ok": false, "error": "quest_window_story_text_truncated"}
	out["story"] = _text(payload, offset, story_length)
	offset += story_length
	if offset + 3 > payload.size():
		return {"ok": false, "error": "quest_window_goals_truncated"}
	out["quest_id_again"] = _u16(payload, offset)
	var goal_count := int(payload[offset + 2])
	offset += 3
	var goals: Array = []
	for i in range(goal_count):
		var goal := _pascal(payload, offset)
		if not bool(goal.get("ok", false)):
			return {"ok": false, "error": "quest_window_goal_truncated", "goal": i}
		goals.append(str(goal["text"]).strip_edges())
		offset = int(goal["next"])
	out["goals"] = goals
	if offset + 6 > payload.size():
		return {"ok": false, "error": "quest_window_money_truncated"}
	out["money"] = _u32(payload, offset)
	out["experience_percent"] = int(payload[offset + 4])
	var reward_count := int(payload[offset + 5])
	offset += 6
	var rewards: Array = []
	for i in range(reward_count):
		var item := decode_item(payload, offset)
		if not bool(item.get("ok", false)):
			return {"ok": false, "error": "quest_window_reward_truncated", "reward": i}
		rewards.append(item["item"])
		offset = int(item["next"])
	out["rewards"] = rewards
	if offset + 2 > payload.size():
		return {"ok": false, "error": "quest_window_optional_truncated"}
	out["optional_choices"] = int(payload[offset])
	var optional_count := int(payload[offset + 1])
	offset += 2
	var optional: Array = []
	for i in range(optional_count):
		var item := decode_item(payload, offset)
		if not bool(item.get("ok", false)):
			return {"ok": false, "error": "quest_window_optional_reward_truncated", "reward": i}
		optional.append(item["item"])
		offset = int(item["next"])
	out["optional_rewards"] = optional
	out["trailing_bytes"] = payload.size() - offset
	return out


## WriteItemData 1.124 (le même objet que le 0x02 de P1-95, sans l octet de
## logement) : 24 octets fixes + nom Pascal ; 24 zéros = objet absent.
static func decode_item(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset + ITEM_FIXED_SIZE > payload.size():
		return {"ok": false}
	var all_zero := true
	for i in range(ITEM_FIXED_SIZE):
		if int(payload[offset + i]) != 0:
			all_zero = false
			break
	if all_zero:
		return {"ok": true, "item": {"empty": true}, "next": offset + ITEM_FIXED_SIZE}
	var name_size := int(payload[offset + 23])
	var next := offset + ITEM_FIXED_SIZE + name_size
	if next > payload.size():
		return {"ok": false}
	var type_byte := int(payload[offset + 6])
	return {"ok": true, "next": next, "item": {
		"empty": false, "level": int(payload[offset + 2]), "value1": int(payload[offset + 3]), "value2": int(payload[offset + 4]),
		"hand": (int(payload[offset + 5]) >> 6) & 0x03, "object_type": type_byte & 0x3f, "damage_type": (type_byte >> 6) & 0x03,
		"weight": _u16(payload, offset + 8), "condition": int(payload[offset + 10]), "durability": int(payload[offset + 11]),
		"quality": int(payload[offset + 12]), "bonus": int(payload[offset + 13]), "bonus_level": int(payload[offset + 14]),
		"model": _u16(payload, offset + 15), "extension": int(payload[offset + 17]), "color_or_emblem": _u16(payload, offset + 18),
		"flags": int(payload[offset + 20]), "effect": _u16(payload, offset + 21),
		"name": _text(payload, offset + ITEM_FIXED_SIZE, name_size),
	}}


static func build_quest_reward_payload(accept: bool, chosen: Array, quest_id: int, npc_object_id: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(20)
	out[0] = 1 if accept else 0
	out[1] = mini(chosen.size(), 8)
	for i in range(mini(chosen.size(), 8)):
		out[2 + i] = int(chosen[i]) & 0xff
	_w16(out, 16, quest_id)
	_w16(out, 18, npc_object_id)
	return out


static func build_remove_quest_payload(quest_index: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(8)
	_w16(out, 2, quest_index)
	return out


## 0x83 index 0 : la tâche (PacketLib184.SendTaskInfo).
static func decode_task_entry(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 6 or int(payload[0]) != 0:
		return {"ok": false, "error": "not_a_task_entry"}
	var length := int(payload[1]) | (int(payload[2]) << 8)
	if 6 + length > payload.size():
		return {"ok": false, "error": "task_entry_truncated"}
	return {"ok": true, "index": 0, "task": true, "text": _text(payload, 6, length)}


static func decode_quest_indicator(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4 or int(payload[2]) != SUBCODE_QUEST_INDICATOR:
		return {"ok": false, "error": "not_a_quest_indicator"}
	var indicator := int(payload[3])
	var name := str(QUEST_INDICATORS.get(indicator, "indicator_%d" % indicator))
	return {"ok": true, "object_id": _u16(payload, 0), "indicator": indicator, "name": name, "glyph": str(QUEST_INDICATOR_GLYPHS.get(name, ""))}


static func decode_model_change(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 8:
		return {"ok": false, "error": "model_change_too_short", "size": payload.size()}
	var size := int(payload[4]) | (int(payload[5]) << 8) | (int(payload[6]) << 16) | (int(payload[7]) << 24)
	return {"ok": true, "object_id": _u16(payload, 0), "model_id": _u16(payload, 2), "size": size, "size_changed": size > 0}


static func build_lfg_flag_payload(flag: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(LFG_PAYLOAD_SIZE)
	out[0] = 1 if flag else 0
	return out


static func build_lfg_list_payload(grouped: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(LFG_PAYLOAD_SIZE)
	out[0] = 1 if grouped else 0
	return out


static func decode_find_group_update(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 1:
		return {"ok": false, "error": "find_group_too_short"}
	var count := int(payload[0])
	var offset := 1
	var players: Array = []
	for i in range(count):
		if offset + 2 > payload.size():
			return {"ok": false, "error": "find_group_entry_truncated", "index": i}
		var index := int(payload[offset])
		var level := int(payload[offset + 1])
		var name := _pascal(payload, offset + 2)
		if not bool(name.get("ok", false)):
			return {"ok": false, "error": "find_group_name_truncated", "index": i}
		offset = int(name["next"])
		if offset + 12 > payload.size():
			return {"ok": false, "error": "find_group_tail_truncated", "index": i}
		players.append({
			"index": index, "leader": index < 0x1E, "level": level, "name": str(name["text"]),
			"class_short": _text(payload, offset, 4).strip_edges().replace(char(0), ""), "zone_skin_id": _u16(payload, offset + 4),
			"duration": int(payload[offset + 6]), "objective": int(payload[offset + 7]), "grouped": int(payload[offset + 10]) != 0,
		})
		offset += 12
	return {"ok": true, "players": players, "trailing_bytes": payload.size() - offset}


static func decode_emblem_dialogue(payload: PackedByteArray) -> Dictionary:
	return {"ok": payload.size() >= 4, "size": payload.size()}


static func build_emblem_response_payload(primary_color: int, secondary_color: int, pattern: int, logo: int) -> PackedByteArray:
	return PackedByteArray([primary_color & 0x0F, secondary_color & 0x07, pattern & 0x03, logo & 0xff])


static func build_pickup_payload() -> PackedByteArray:
	return PackedByteArray([0])


## Encodeurs pour les suites à faux pair.
static func encode_item(item: Dictionary) -> PackedByteArray:
	if item.is_empty() or bool(item.get("empty", false)):
		var zeros := PackedByteArray()
		zeros.resize(ITEM_FIXED_SIZE)
		return zeros
	var name := str(item.get("name", "")).to_ascii_buffer()
	var model := int(item.get("model", 0))
	var out := PackedByteArray([0, 0, int(item.get("level", 0)), int(item.get("value1", 0)), int(item.get("value2", 0)), (int(item.get("hand", 0)) << 6) & 0xff,
		(int(item.get("object_type", 0)) & 0x3f) | ((int(item.get("damage_type", 0)) & 3) << 6), 0, 0, int(item.get("weight", 0)) & 0xff,
		int(item.get("condition", 100)), int(item.get("durability", 100)), int(item.get("quality", 100)), int(item.get("bonus", 0)), 0,
		(model >> 8) & 0xff, model & 0xff, 0, 0, 0, 0, 0, 0, name.size() & 0xff])
	out.append_array(name)
	return out


static func encode_quest_window(offer: bool, quest_id: int, npc_id: int, name: String, summary: String, story: String, goals: Array, money: int, xp: int, rewards: Array, optional_choices: int, optional: Array) -> PackedByteArray:
	var out := PackedByteArray([0, QUEST_WINDOW_OFFER if offer else QUEST_WINDOW_REWARD, (quest_id >> 8) & 0xff, quest_id & 0xff, (npc_id >> 8) & 0xff, npc_id & 0xff, 0, 0, 0, 0, 2 if offer else 1, 1])
	_write_pascal(out, name)
	_write_pascal(out, summary)
	var story_bytes := story.to_ascii_buffer()
	out.append((story_bytes.size() >> 8) & 0xff)
	out.append(story_bytes.size() & 0xff)
	out.append_array(story_bytes)
	out.append((quest_id >> 8) & 0xff)
	out.append(quest_id & 0xff)
	out.append(goals.size() & 0xff)
	for goal in goals:
		_write_pascal(out, str(goal) + "\r")
	out.append_array(PackedByteArray([(money >> 24) & 0xff, (money >> 16) & 0xff, (money >> 8) & 0xff, money & 0xff, xp & 0xff, rewards.size() & 0xff]))
	for item in rewards:
		out.append_array(encode_item(item as Dictionary))
	out.append(optional_choices & 0xff)
	out.append(optional.size() & 0xff)
	for item in optional:
		out.append_array(encode_item(item as Dictionary))
	return out


static func encode_quest_indicator(object_id: int, indicator: int) -> PackedByteArray:
	return PackedByteArray([(object_id >> 8) & 0xff, object_id & 0xff, SUBCODE_QUEST_INDICATOR, indicator & 0xff, 0, 0, 0, 0])


static func encode_model_change(object_id: int, model_id: int, size: int) -> PackedByteArray:
	return PackedByteArray([(object_id >> 8) & 0xff, object_id & 0xff, (model_id >> 8) & 0xff, model_id & 0xff, size & 0xff, (size >> 8) & 0xff, (size >> 16) & 0xff, (size >> 24) & 0xff])


static func encode_task_entry(text: String) -> PackedByteArray:
	var bytes := text.to_ascii_buffer()
	var out := PackedByteArray([0, bytes.size() & 0xff, (bytes.size() >> 8) & 0xff, 0, 0, 0])
	out.append_array(bytes)
	return out


## `players` : [{index, level, name, class_short, zone_skin_id, grouped}]
static func encode_find_group_update(players: Array) -> PackedByteArray:
	var out := PackedByteArray([players.size() & 0xff])
	for value in players:
		var p := value as Dictionary
		out.append(int(p.get("index", 0)) & 0xff)
		out.append(int(p.get("level", 1)) & 0xff)
		_write_pascal(out, str(p.get("name", "")))
		var cls := str(p.get("class_short", "")).to_ascii_buffer()
		cls.resize(4)
		out.append_array(cls)
		var zone := int(p.get("zone_skin_id", 0))
		out.append_array(PackedByteArray([(zone >> 8) & 0xff, zone & 0xff, 0, 0, 0, 0, 1 if bool(p.get("grouped", false)) else 0, 0]))
	return out


static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": _text(payload, offset + 1, size), "next": offset + 1 + size}


static func _text(payload: PackedByteArray, start: int, length: int) -> String:
	var bytes := payload.slice(start, start + length)
	var text := bytes.get_string_from_utf8()
	if text == "" and length > 0:
		text = bytes.get_string_from_ascii()
	return text


static func _write_pascal(out: PackedByteArray, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	out.append(bytes.size() & 0xff)
	out.append_array(bytes)


static func _u16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


static func _u32(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


static func _w16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
