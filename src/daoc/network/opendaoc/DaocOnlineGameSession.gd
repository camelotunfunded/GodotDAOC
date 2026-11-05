extends RefCounted
class_name DaocOnlineGameSession

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const InventoryControllerScript = preload("res://src/daoc/network/opendaoc/DaocOnlineInventoryController.gd")
const TrainerCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTrainerCodec.gd")
const ProgressCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocProgressCodec.gd")
const MovementCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMovementCodec.gd")
const CareerCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCareerCodec.gd")
const CombatControlCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCombatControlCodec.gd")
const QuestSocialCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocQuestSocialCodec.gd")
const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")
const TravelCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTravelCodec.gd")
const EconomyCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEconomyCodec.gd")

signal state_changed(previous: String, current: String)
signal outbound_packet_ready(packet: PackedByteArray, purpose: String)
signal inventory_changed(snapshot: Dictionary)
signal external_inventory_changed(window: Dictionary)

const DISCONNECTED := "DISCONNECTED"
const CONNECTING := "CONNECTING"
const AUTHENTICATING := "AUTHENTICATING"
const CHARACTER_SELECTION := "CHARACTER_SELECTION"
const ENTERING_WORLD := "ENTERING_WORLD"
const PLAYING := "PLAYING"
const FAILED := "FAILED"

var state := DISCONNECTED
var session_id := 0
var selected_character: Dictionary = {}
var last_error := ""
var received_packet_count := 0
var inventory_decode_failures := 0
var _sequence := 0
var _codec: RefCounted = PacketCodecScript.new()
var _inventory: RefCounted = InventoryControllerScript.new()
var _movement: RefCounted = MovementCodecScript.new()
var _last_position: Dictionary = {}


func _init() -> void:
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_inventory.external_inventory_changed.connect(func(window: Dictionary) -> void: external_inventory_changed.emit(window))
	_inventory.equipment_request_ready.connect(_on_equipment_request_ready)


func begin_connection() -> Dictionary:
	if state != DISCONNECTED and state != FAILED:
		return {"ok": false, "error": "session_already_started", "state": state}
	session_id = 0
	selected_character.clear()
	last_error = ""
	received_packet_count = 0
	_sequence = 0
	_set_state(CONNECTING)
	return snapshot()


func transport_connected() -> Dictionary:
	if state != CONNECTING:
		return fail("transport_connected_in_invalid_state")
	_set_state(AUTHENTICATING)
	return snapshot()


func choose_character(character: Dictionary) -> Dictionary:
	if state != CHARACTER_SELECTION:
		return {"ok": false, "error": "character_selection_not_ready", "state": state}
	if str(character.get("name", "")) == "":
		return {"ok": false, "error": "character_name_missing", "state": state}
	selected_character = character.duplicate(true)
	_set_state(ENTERING_WORLD)
	return snapshot()


func accept_server_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return fail(str(parsed.get("parse_status", "invalid_server_packet")))
	received_packet_count += 1
	var opcode := int(parsed.get("opcode", -1))
	match opcode:
		0x28:
			var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
			if payload.size() != 2:
				return fail("invalid_session_id_packet")
			session_id = int(_codec.call("u16_le_read", payload, 0))
		0x2A, 0xFC, 0xFD:
			if state == AUTHENTICATING:
				_set_state(CHARACTER_SELECTION)
		0x2D:
			# Un GameOpenReply hors de l'entree monde (rejoue, changement de
			# region) ne coupe pas : on l'ignore et on le compte.
			if state != ENTERING_WORLD and state != PLAYING:
				return fail("game_open_reply_in_invalid_state")
		0x2B:
			if state == PLAYING:
				pass
			elif state != ENTERING_WORLD:
				return fail("player_init_finished_in_invalid_state")
			else:
				_set_state(PLAYING)
		0x02:
			if state != PLAYING and state != ENTERING_WORLD:
				return {"ok": true, "opcode": opcode, "ignored": "inventory_before_world", "state": state}
			var inventory_result: Dictionary = _inventory.call("ingest_server_packet", packet) as Dictionary
			if not bool(inventory_result.get("ok", false)):
				# Un inventaire illisible se compte, il ne deconnecte pas.
				inventory_decode_failures += 1
	return {"ok": true, "opcode": opcode, "state": state, "snapshot": snapshot()}


func request_staff_equipment() -> Dictionary:
	if state != PLAYING:
		return {"ok": false, "error": "equipment_requires_playing_state", "state": state}
	var result: Dictionary = _inventory.call("prepare_staff_equipment", _next_sequence(), session_id, 0) as Dictionary
	return result


## P1-115 : le rejeu de l entree monde (changement de region) reprend ici.
func next_sequence_value() -> int:
	return _sequence


func set_next_sequence(value: int) -> void:
	_sequence = value & 0xffff


func set_authoritative_position(value: Dictionary) -> void:
	_last_position = value.duplicate(true)


## Le client d'origine envoie un PingRequest (0xA3) toutes les quelques
## secondes ; sans lui, DOL coupe la session au bout de PING_TIMEOUT (6 min par
## defaut, moins sur Eden) — c'est ce qui rendait « Play » inerte apres une
## attente a l'ecran de selection le 2026-09-15. Charge utile
## (PingRequestHandler.cs) : 4 octets ignores puis un u32 horodatage.
func request_ping() -> Dictionary:
	if state in [DISCONNECTED, CONNECTING, FAILED]:
		return {"ok": false, "error": "ping_requires_connection"}
	var payload := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	var stamp := int(Time.get_ticks_msec()) & 0xffffffff
	payload[4] = (stamp >> 24) & 0xff; payload[5] = (stamp >> 16) & 0xff; payload[6] = (stamp >> 8) & 0xff; payload[7] = stamp & 0xff
	var sequence := _next_sequence()
	var unsigned: PackedByteArray = _codec.call("build_client_packet", 0xA3, payload, sequence, session_id, 0, 0) as PackedByteArray
	var sum := int(_ping_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	var packet: PackedByteArray = _codec.call("build_client_packet", 0xA3, payload, sequence, session_id, 0, sum) as PackedByteArray
	if packet.is_empty():
		return {"ok": false, "error": "ping_packet_build_failed"}
	pings_sent += 1
	outbound_packet_ready.emit(packet, "ping")
	return {"ok": true, "pings_sent": pings_sent}


var pings_sent := 0
const SkillListCodec := preload("res://src/daoc/network/opendaoc/DaocOpenDaocSkillListCodec.gd")


## B6 — les intentions de combat, signees et sequencees comme le 0xA9.
func _send_signed(opcode: int, payload: PackedByteArray, purpose: String) -> Dictionary:
	if state != PLAYING:
		return {"ok": false, "error": purpose + "_requires_playing_state"}
	var sequence := _next_sequence()
	var unsigned: PackedByteArray = _codec.call("build_client_packet", opcode, payload, sequence, session_id, 0, 0) as PackedByteArray
	var sum := int(_ping_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	var packet: PackedByteArray = _codec.call("build_client_packet", opcode, payload, sequence, session_id, 0, sum) as PackedByteArray
	if packet.is_empty():
		return {"ok": false, "error": purpose + "_packet_build_failed"}
	combat_packets_sent += 1
	outbound_packet_ready.emit(packet, purpose)
	return {"ok": true, "opcode": opcode, "purpose": purpose}


var combat_packets_sent := 0


func request_use_spell(level: int, line_index: int, target_visible: bool = true) -> Dictionary:
	var position := _last_position if not _last_position.is_empty() else {}
	return _send_signed(0x7D, SkillListCodec.build_use_spell_payload(position, level, line_index, target_visible), "use_spell")


## P1-79 — 0xBB UseSkill : styles, capacites, chants. `index` et `type` tels
## que la liste 0x16/0x01 les numerote (voir DaocOpenDaocSkillListCodec).
func request_use_skill(index: int, type: int, target_visible: bool = true) -> Dictionary:
	var position := _last_position if not _last_position.is_empty() else {}
	return _send_signed(0xBB, SkillListCodec.build_use_skill_payload(position, index, type, target_visible), "use_skill")


## P1-98 — 0x71 UseSlot : MEME charge utile que 0xBB (position + drapeaux +
## u8 logement + u8 type), opcode different. Trouve dans game.dll decompile :
## FUN_0042b72f(slot, type) -> paquet 0x71 de 0x18 octets ; les touches
## « arme 1 main / 2 mains / distance » l appellent avec 10 / 12 / 13 et le
## type 0, la quickbar avec le logement d un objet et son type d usage (0 clic,
## 1 use1, 2 use2). DOL : UseSlotHandler (0xD9 ^ 168 = 0x71).
func request_use_slot(slot: int, use_type: int = 0, target_visible: bool = true) -> Dictionary:
	var position := _last_position if not _last_position.is_empty() else {}
	return _send_signed(0x71, SkillListCodec.build_use_skill_payload(position, slot, use_type, target_visible), "use_slot")


## P1-98 — 0xDD PlayerMoveItem, tel que P1-56 le construit pour le baton :
## u16 id (0), u16 vers, u16 depuis, u16 nombre.
func request_move_item(from_slot: int, to_slot: int, item_count: int = 1) -> Dictionary:
	var codec: RefCounted = _inventory.get("_codec") as RefCounted
	return _send_signed(0xDD, codec.call("build_move_item_payload", 0, to_slot, from_slot, item_count) as PackedByteArray, "move_item")


## P1-102 — 0xD8 DetailRequest, tel que le client d origine le construit
## (FUN_0042b8ab puis htons/htonl) : u16 type, u16 0, u32 id, u32 0. Type 1 =
## objet d inventaire (id = logement), 9 = entree de liste (sorts, styles).
func request_detail(object_type: int, object_id: int) -> Dictionary:
	var payload := PackedByteArray([(object_type >> 8) & 0xff, object_type & 0xff, 0, 0,
		(object_id >> 24) & 0xff, (object_id >> 16) & 0xff, (object_id >> 8) & 0xff, object_id & 0xff, 0, 0, 0, 0])
	return _send_signed(0xD8, payload, "detail_request")


## P1-108 — 0xF8 PlayerCancelsEffect (clic droit sur la barre d effets : u16
## TooltipId + u16 0, `FUN_0042af96`), 0x76 RemoveConcentrationEffect (u8
## index + 3 x 0, `FUN_0042afcb`), 0x8A PetWindow (u8 agressivite, u8
## deplacement, u8 commande, u8 0, `FUN_0042adb2`). Dispositions dans
## DaocOpenDaocProgressCodec.
func request_cancel_effect(tooltip_id: int) -> Dictionary:
	return _send_signed(0xF8, ProgressCodec.build_cancel_effect_payload(tooltip_id), "cancel_effect")


func request_remove_concentration(index: int) -> Dictionary:
	if index < 0 or index >= 50:
		return {"ok": false, "error": "concentration_index_out_of_range"}
	return _send_signed(0x76, ProgressCodec.build_remove_concentration_payload(index), "remove_concentration")


func request_pet_command(aggro: int, walk: int, command: int) -> Dictionary:
	return _send_signed(0x8A, ProgressCodec.build_pet_window_payload(aggro, walk, command), "pet_window")


## P1-107 — 0x7B (1 octet, comme game.dll) ouvre la fenetre d entraineur ;
## 0x53 (264 octets) forme les spes et capacites de royaume visees.
func request_trainer_window() -> Dictionary:
	return _send_signed(0x7B, PackedByteArray([0]), "trainer_window")


func request_train(spec_targets: Dictionary, ra_targets: Dictionary) -> Dictionary:
	var payload: PackedByteArray = TrainerCodec.build_train_payload(spec_targets, ra_targets)
	return _send_signed(0x53, payload, "train")


## P1-109 — la carriere et les commandes de combat (DaocOpenDaocCareerCodec,
## DaocOpenDaocCombatControlCodec) : 0xCA bonus (1 octet), 0x7C former UNE spe
## / capacite ou une competence Champion (12 octets), 0xEC cible au sol (16
## octets), 0xF5 commande de siege (16 octets, une par seconde comme game.dll).
## Un 0x82 dont la reponse n est pas oui / non : DialogResponseHandler lit
## data1..3, le code, puis UN octet de reponse ; pour le code 0x19
## (MasterLevelWindow) cet octet est le ML demande -> le serveur repond 0x13.
func request_dialog_value(code: int, value: int) -> Dictionary:
	var payload := PackedByteArray([0, 0, 0, 0, 0, 0, code & 0xff, value & 0xff])
	return _send_signed(0x82, payload, "dialog_value")


func request_bonuses_list() -> Dictionary:
	return _send_signed(0xCA, CareerCodec.build_bonuses_request_payload(), "bonuses_list")


func request_train_one(index: int, realm_ability: bool = false) -> Dictionary:
	return _send_signed(0x7C, CareerCodec.build_train_one_payload(index, realm_ability), "train_one")


func request_champion_train(line_index: int, row: int, column: int) -> Dictionary:
	if line_index <= 0:
		return {"ok": false, "error": "champion_line_index_required"}
	return _send_signed(0x7C, CareerCodec.build_champion_train_payload(line_index, row, column), "champion_train")


func request_ground_target(x: int, y: int, z: int, visible: bool = true) -> Dictionary:
	return _send_signed(0xEC, CombatControlCodec.build_ground_target_payload(x, y, z, visible), "ground_target")


var _last_siege_command_msec := -100000


func request_siege_command(action: int, ammo: int = 0) -> Dictionary:
	if action <= 0 or action > 10:
		return {"ok": false, "error": "siege_action_out_of_range"}
	var now := Time.get_ticks_msec()
	if now - _last_siege_command_msec < CombatControlCodec.SIEGE_CLIENT_COOLDOWN_MSEC:
		return {"ok": false, "error": "siege_command_too_soon"}
	var result := _send_signed(0xF5, CombatControlCodec.build_siege_command_payload(action, ammo), "siege_command")
	if bool(result.get("ok", false)):
		_last_siege_command_msec = now
	return result


## P1-110 — quêtes, LFG, emblème, ramassage (DaocOpenDaocQuestSocialCodec).
func request_quest_reward(accept: bool, chosen: Array, quest_id: int, npc_object_id: int) -> Dictionary:
	return _send_signed(0x40, QuestSocialCodec.build_quest_reward_payload(accept, chosen, quest_id, npc_object_id), "quest_reward_chosen")


func request_remove_quest(quest_index: int) -> Dictionary:
	return _send_signed(0x4F, QuestSocialCodec.build_remove_quest_payload(quest_index), "remove_quest")


func request_lfg_flag(flag: bool) -> Dictionary:
	return _send_signed(0x84, QuestSocialCodec.build_lfg_flag_payload(flag), "lfg_flag")


func request_lfg_list(grouped: bool = false) -> Dictionary:
	return _send_signed(0x85, QuestSocialCodec.build_lfg_list_payload(grouped), "lfg_list")


func request_emblem(primary_color: int, secondary_color: int, pattern: int, logo: int) -> Dictionary:
	return _send_signed(0xE2, QuestSocialCodec.build_emblem_response_payload(primary_color, secondary_color, pattern, logo), "emblem")


## 0xB5, un octet comme game.dll : DOL ramasse la CIBLE courante (0xB0 avant).
func request_pickup() -> Dictionary:
	return _send_signed(0xB5, QuestSocialCodec.build_pickup_payload(), "pickup")


## P1-114 — marchand, vente, estimation, échange (DaocOpenDaocMerchantCodec).
## Les x / y que game.dll recopie sont ceux du joueur ; DOL les lit dans le
## vide et travaille sur la CIBLE, comme pour le 0x7A d interaction.
func request_buy(page_slot: int, count: int, window_type: int) -> Dictionary:
	if page_slot < 0 or page_slot > 0xffff:
		return {"ok": false, "error": "buy_slot_out_of_range"}
	var x := int(_last_position.get("x", 0))
	var y := int(_last_position.get("y", 0))
	return _send_signed(MerchantCodec.OPCODE_BUY, MerchantCodec.build_buy_payload(x, y, session_id, page_slot, count, window_type), "merchant_buy")


func request_sell(inventory_slot: int) -> Dictionary:
	if inventory_slot < 0 or inventory_slot > 0xffff:
		return {"ok": false, "error": "sell_slot_out_of_range"}
	var x := int(_last_position.get("x", 0))
	var y := int(_last_position.get("y", 0))
	return _send_signed(MerchantCodec.OPCODE_SELL, MerchantCodec.build_sell_payload(x, y, session_id, inventory_slot), "merchant_sell")


func request_appraise(inventory_slot: int) -> Dictionary:
	if inventory_slot < 0 or inventory_slot > 0xffff:
		return {"ok": false, "error": "appraise_slot_out_of_range"}
	var x := int(_last_position.get("x", 0))
	var y := int(_last_position.get("y", 0))
	return _send_signed(MerchantCodec.OPCODE_APPRAISE, MerchantCodec.build_appraise_payload(x, y, session_id, inventory_slot), "merchant_appraise")


## `response` : 0 fermer, 1 mettre à jour, 2 accepter.
func request_modify_trade(response: int, slots: Array = [], copper: int = 0, repairing: bool = false, combine: bool = false) -> Dictionary:
	if response < 0 or response > 2:
		return {"ok": false, "error": "trade_response_out_of_range"}
	return _send_signed(MerchantCodec.OPCODE_MODIFY_TRADE, MerchantCodec.build_modify_trade_payload(response, slots, copper, repairing, combine), "modify_trade")


## P1-115 — portes, monture, changement de région (DaocOpenDaocTravelCodec).
## 0x99 : ouvrir (true) ou fermer une porte, par son identifiant complet.
func request_door(door_id: int, open: bool = true) -> Dictionary:
	if door_id <= 0:
		return {"ok": false, "error": "door_id_invalid"}
	return _send_signed(TravelCodec.OPCODE_DOOR, TravelCodec.build_door_request_payload(door_id, open), "door_request")


## 0xC8 : descendre de monture. DOL ne lit pas la charge utile.
func request_dismount() -> Dictionary:
	return _send_signed(TravelCodec.OPCODE_DISMOUNT_REQUEST, TravelCodec.build_dismount_payload(), "dismount_request")


## 0x90 : franchir un point de saut vers une autre région.
func request_region_change(jump_point_id: int) -> Dictionary:
	if jump_point_id <= 0:
		return {"ok": false, "error": "jump_point_id_invalid"}
	return _send_signed(TravelCodec.OPCODE_REGION_CHANGE_REQUEST, TravelCodec.build_region_change_request_payload(jump_point_id), "region_change_request")


func request_target(object_id: int, attack_mode: bool = false) -> Dictionary:
	return _send_signed(0xB0, SkillListCodec.build_target_payload(object_id, attack_mode), "player_target")


func request_attack_mode(on: bool) -> Dictionary:
	return _send_signed(0x74, SkillListCodec.build_attack_mode_payload(on), "attack_mode")


## P1-78 — 0x7A ObjectInteractRequest : u32 x, u32 y (position MONDE du
## joueur), u16 session, u16 OID de la cible. Disposition confirmee en live le
## 14/09 par la sonde (Morwenna a repondu).
func request_interact(object_id: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(12)
	var x := int(_last_position.get("x", 0))
	var y := int(_last_position.get("y", 0))
	for i in range(4):
		payload[i] = (x >> (8 * (3 - i))) & 0xff
		payload[4 + i] = (y >> (8 * (3 - i))) & 0xff
	payload[8] = (session_id >> 8) & 0xff
	payload[9] = session_id & 0xff
	payload[10] = (object_id >> 8) & 0xff
	payload[11] = object_id & 0xff
	return _send_signed(0x7A, payload, "interact")


## P1-78 — 0x82 DialogResponse : data1..3 du 0x81 recopies, code, reponse.
func request_dialog_response(dialog: Dictionary, accept: bool) -> Dictionary:
	return _send_signed(0x82, DaocOpenDaocProgressCodec.build_dialog_response_payload(dialog, accept), "dialog_response")


## 0xAF client : commande texte du client classique. DOL attend huit octets
## reserves, puis la commande terminee par zero. L'interface accepte la forme
## familiere `/release` et la convertit en `&release` sur le fil.
func request_command(command: String) -> Dictionary:
	var wire_command := command.strip_edges()
	if wire_command.begins_with("/"):
		wire_command = "&" + wire_command.substr(1)
	elif not wire_command.begins_with("&"):
		wire_command = "&say " + wire_command
	if wire_command == "&":
		return {"ok": false, "error": "empty_command"}
	var payload := PackedByteArray()
	payload.resize(8)
	payload.append_array(wire_command.to_utf8_buffer())
	payload.append(0)
	return _send_signed(0xAF, payload, "command")


## Le serveur demande une confirmation de ligne de vue avant de resoudre
## certains sorts. La sonde live du 14/09 a confirme que les quatre premiers
## octets doivent etre recopies, suivis du verdict visible 0x0100.
func request_los_response(request: PackedByteArray) -> Dictionary:
	if request.size() < 4:
		return {"ok": false, "error": "los_request_too_short"}
	var payload := PackedByteArray(); payload.resize(8)
	for index in 4:
		payload[index] = request[index]
	payload[4] = 0x01
	payload[5] = 0x00
	return _send_signed(0xD0, payload, "line_of_sight")


var _ping_checksum: RefCounted = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd").new()


func request_movement(value: Dictionary) -> Dictionary:
	if state != PLAYING:
		return {"ok": false, "error": "movement_requires_playing_state"}
	if not _last_position.is_empty():
		var dx := float(value.get("x", 0.0)) - float(_last_position.get("x", 0.0))
		var dy := float(value.get("y", 0.0)) - float(_last_position.get("y", 0.0))
		if sqrt(dx * dx + dy * dy) > 1024.0:
			return {"ok": false, "error": "movement_step_too_large"}
	var packet: PackedByteArray = _movement.call("build_packet", value, _next_sequence(), session_id) as PackedByteArray
	if packet.is_empty(): return {"ok": false, "error": "movement_packet_build_failed"}
	_last_position = value.duplicate(true)
	outbound_packet_ready.emit(packet, "player_movement")
	return {"ok": true, "position": _last_position.duplicate(true)}


func fail(reason: String) -> Dictionary:
	last_error = reason
	_set_state(FAILED)
	return {"ok": false, "error": reason, "state": state}


func snapshot() -> Dictionary:
	return {
		"ok": state != FAILED,
		"state": state,
		"pings_sent": pings_sent,
		"session_id_received": session_id != 0,
		"selected_character": str(selected_character.get("name", "")),
		"received_packet_count": received_packet_count,
		"inventory": _inventory.call("snapshot"),
		"last_error": last_error,
	}


func _next_sequence() -> int:
	var value := _sequence
	_sequence = (_sequence + 1) & 0xffff
	return value


func _set_state(value: String) -> void:
	if state == value:
		return
	var previous := state
	state = value
	state_changed.emit(previous, state)


func _on_inventory_changed(value: Dictionary) -> void:
	inventory_changed.emit(value)


func _on_equipment_request_ready(packet: PackedByteArray, _plan: Dictionary) -> void:
	outbound_packet_ready.emit(packet, "equip_staff")


## P1-122 — artisanat, consignation, marche (DaocOpenDaocEconomyCodec).
func request_craft(recipe_id: int) -> Dictionary:
	var payload := EconomyCodec.build_craft_payload(recipe_id)
	if payload.is_empty():
		return {"ok": false, "error": "recipe_id_out_of_range"}
	return _send_signed(EconomyCodec.OPCODE_CRAFT_REQUEST, payload, "craft_request")


func request_set_market_price(relative_slot: int, price: int) -> Dictionary:
	var payload := EconomyCodec.build_set_price_payload(relative_slot, price)
	if payload.is_empty():
		return {"ok": false, "error": "market_price_out_of_range"}
	return _send_signed(EconomyCodec.OPCODE_SET_MARKET_PRICE, payload, "set_market_price")


func request_withdraw_merchant_money() -> Dictionary:
	return _send_signed(EconomyCodec.OPCODE_WITHDRAW_MERCHANT_MONEY, EconomyCodec.build_withdraw_payload(), "withdraw_merchant_money")


func request_market_search(search: Dictionary) -> Dictionary:
	return _send_signed(EconomyCodec.OPCODE_MARKET_SEARCH, EconomyCodec.build_market_search_payload(search), "market_search")
