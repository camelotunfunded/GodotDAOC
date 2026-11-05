extends Node
class_name DaocOnlineRuntime

const SessionScript = preload("res://src/daoc/network/opendaoc/DaocOnlineGameSession.gd")
const TransportScript = preload("res://src/daoc/network/opendaoc/DaocOnlineTcpTransport.gd")
const AuthenticationScript = preload("res://src/daoc/network/opendaoc/DaocOnlineAuthentication.gd")
const WorldEntryScript = preload("res://src/daoc/network/opendaoc/DaocOnlineWorldEntry.gd")
const WorldModelScript = preload("res://src/daoc/network/opendaoc/DaocOnlineWorldModel.gd")
const StatusMessageCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocStatusMessageCodec.gd")

signal state_changed(state: String)
## Etat protocolaire interne : le serveur commence ici son flux d'entites, mais
## le frontend ne publie PLAYING qu'une fois ce flux initial applique au monde.
signal server_playing_received
signal connection_failed(reason: String)
signal inventory_changed(snapshot: Dictionary)
signal character_overview_received(overview: Dictionary)
signal player_position_changed(position: Dictionary)
signal world_entities_changed(snapshot: Dictionary)
## Evenement de flux R2 (spawn/move) pret pour DaocEntityStreamRuntime.
signal world_entity_event(event: Dictionary)
## B5 — 0xAD : jauges du joueur, decodees (voir DaocOpenDaocStatusMessageCodec).
signal player_status_received(status: Dictionary)
## B5 — 0xAF : texte du serveur, classe chat / console / popup.
signal server_message_received(message: Dictionary)
## B6 — le livre de sorts du serveur (0x16/0x02), lignes dans l'ordre que UseSpell adresse.
signal spell_lines_received(lines: Array)
## P1-79 — la liste des competences du serveur (0x16/0x01) : specialisations,
## capacites, styles ; c'est elle que UseSkill (0xBB) adresse.
signal skills_received(skills: Array)
## P1-83 — les metiers du serveur (0x16/0x08).
signal crafting_skills_received(skills: Array)
## P1-82 — 0xB6 MaxSpeed : la vitesse que le serveur autorise, en pourcent de
## la base ; change a chaque bascule du sprint.
signal max_speed_received(speed: Dictionary)
## P1-76 — le serveur NOMME ce que le client doit jouer (DaocOpenDaocAnimationCodec).
signal spell_cast_animation_received(cast: Dictionary)
signal spell_effect_animation_received(effect: Dictionary)
signal combat_animation_received(swing: Dictionary)
## P1-133 : 0x74 du serveur, vrai = mode combat (armes degainees).
signal attack_mode_changed(on: bool)
var server_attack_mode: bool = false
signal spell_cast_interrupted(living_id: int)
## P1-77 — 0xA4 Quit : le serveur a retire le personnage du monde (fin du
## compte a rebours de /quit). total_out=true : deconnexion complete.
signal player_quit_received(total_out: bool, level: int)
## P1-78 — progression et interactions PNJ (DaocOpenDaocProgressCodec).
signal player_points_received(points: Dictionary)
signal dialog_received(dialog: Dictionary)
signal player_died_received(death: Dictionary)
## P1-97 : 0x89 PlayerRevive, la resurrection (leve le drapeau mort).
signal player_revived(object_id: int)
## P1-99 : 0x7F UpdateIcons, la liste COMPLETE des effets actifs du joueur.
signal effects_received(effects: Array)
## P1-102 : 0xC4 DetailWindow, le delve d un objet ou d un sort (titre + lignes).
signal detail_window_received(detail: Dictionary)
var _last_effects: Array = []


func last_effects() -> Array:
	return _last_effects.duplicate(true)


## P1-108 — annuler un buff, la concentration, le grise de delai, le pet.
## 0x75 ConcentrationList : la liste complete des buffs de concentration.
signal concentration_received(effects: Array)
## 0xD6 DisableSkills : les competences en delai ; `disabled_skills()` rend
## les echeances courantes (cle -> msec de Time.get_ticks_msec()).
signal skills_disabled(entries: Array)
## 0x88 PetWindow (petit 0x88, apres l entree monde) : ouvrir / mettre a jour
## / fermer la fenetre du pet.
signal pet_window_received(pet: Dictionary)
var _last_concentration: Array = []
var _disabled_until: Dictionary = {}
var _last_pet_window: Dictionary = {}
var cancel_effects_sent := 0
var remove_concentrations_sent := 0
var pet_commands_sent := 0


func last_concentration() -> Array:
	return _last_concentration.duplicate(true)


func last_pet_window() -> Dictionary:
	return _last_pet_window.duplicate(true)


## Cle d une competence pour le grise : « spell:<ligne>:<index> » pour un sort
## de liste (les index du 0x16 et du 0xD6 sont les memes : position dans la
## ligne), « skill:<index> » pour une competence hors specialisations (la
## regle d indexation de `send_use_skill`).
static func disable_key_for_spell(line_index: int, spell_index: int) -> String:
	return "spell:%d:%d" % [line_index, spell_index]


static func disable_key_for_skill(skill_index: int) -> String:
	return "skill:%d" % skill_index


func disabled_skills() -> Dictionary:
	var now := Time.get_ticks_msec()
	var out: Dictionary = {}
	for key in _disabled_until.keys():
		if int(_disabled_until[key]) > now:
			out[key] = int(_disabled_until[key])
	return out


func disabled_remaining_seconds(key: String) -> float:
	return maxf(0.0, float(int(_disabled_until.get(key, 0)) - Time.get_ticks_msec()) / 1000.0)


func _apply_disable_skills(decoded: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for value in decoded.get("entries", []) as Array:
		var entry := value as Dictionary
		var key := ""
		if str(entry.get("kind", "")) == "spell":
			key = disable_key_for_spell(int(entry.get("line_index", 0)), int(entry.get("spell_index", 0)))
		else:
			key = disable_key_for_skill(int(entry.get("skill_index", 0)))
		var seconds := int(entry.get("seconds", 0))
		if seconds <= 0:
			_disabled_until.erase(key)
		else:
			_disabled_until[key] = now + seconds * 1000
	skills_disabled.emit((decoded.get("entries", []) as Array).duplicate(true))


func send_cancel_effect(tooltip_id: int) -> Dictionary:
	var result: Dictionary = _session.call("request_cancel_effect", tooltip_id) as Dictionary
	if bool(result.get("ok", false)):
		cancel_effects_sent += 1
	return result


func send_remove_concentration(index: int) -> Dictionary:
	var result: Dictionary = _session.call("request_remove_concentration", index) as Dictionary
	if bool(result.get("ok", false)):
		remove_concentrations_sent += 1
	return result


## aggro / walk : les codes de DaocOpenDaocProgressCodec.PET_AGGRO / PET_WALK
## (0 = inchange) ; command : 0 rien, 1 attaquer, 2 relacher.
func send_pet_command(aggro: int, walk: int, command: int) -> Dictionary:
	var result: Dictionary = _session.call("request_pet_command", aggro, walk, command) as Dictionary
	if bool(result.get("ok", false)):
		pet_commands_sent += 1
	return result
signal quest_entry_received(quest: Dictionary)
signal client_world_loading_requested

## P1-109 — la carriere (rangs, titres, ML, CL, niveau gratuit, bonus) et les
## commandes de combat (cible au sol, siege, compte a rebours).
const CareerCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCareerCodec.gd")
const CombatControlCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCombatControlCodec.gd")
const QuestSocialCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocQuestSocialCodec.gd")
const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")
const EconomyCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEconomyCodec.gd")
## 0xC4 avec l octet 0 a 1 : « Player Statistics » + la liste des titres (/settitle).
signal titles_received(titles: Dictionary)
## 0x4C sous-code 0x0B : le titre courant d un joueur a change.
signal title_updated(update: Dictionary)
## 0x4C sous-code 0x09 : l etat du niveau gratuit.
signal free_level_received(state: Dictionary)
## 0x13 : la fenetre des Master Levels.
signal master_level_window_received(window: Dictionary)
## 0x7B code 2 : la page Champion d un entraineur.
signal champion_trainer_received(page: Dictionary)
## 0xEC : la cible au sol que le serveur impose.
signal ground_target_received(target: Dictionary)
## 0xF5 : l interface d une arme de siege (ou sa fermeture).
signal siege_interface_received(siege: Dictionary)
## 0xE3 : l animation d une arme de siege.
signal siege_animation_received(animation: Dictionary)
## 0xF3 : la fenetre de compte a rebours (release, siege, quete).
signal timer_window_received(timer: Dictionary)
## 0xF6 : le serveur impose une cible (/assist, cible disparue = 0).
signal target_change_received(object_id: int)

## P1-110 — quêtes, PNJ, joueurs distants, social (DaocOpenDaocQuestSocialCodec).
## 0x81 code 0x22 / 0x21 : la fenêtre d offre / de récompense d une quête.
signal quest_window_received(window: Dictionary)
## 0x83 index 0 : la tâche courante.
signal task_received(task: Dictionary)
## 0x4C sous-code 0x07 : l icône de quête au-dessus d un PNJ.
signal quest_indicator_received(indicator: Dictionary)
## 0xDB : un modèle ou une taille change.
signal model_changed(change: Dictionary)
## 0x8D PlayerModelTypeChange (PacketLib168) : u16 oid, u8 type, u8 (0x08 si 3).
## game.dll FUN_00413a55 ne le lit QUE pour son propre personnage : 3 = cache
## (furtivite, GamePlayer.Stealth), 2 = de nouveau visible ; 1 / 0 = autre drapeau.
signal model_type_changed(change: Dictionary)
## 0x86 : la liste « cherche groupe ».
signal find_group_received(list: Dictionary)
## 0xE2 : le serveur ouvre la fenêtre d emblème.
signal emblem_dialogue_received
## 0x15 : l équipement d un joueur distant (relais du décodeur P1-94).
signal equipment_received(object_id: int, equipment: Dictionary)
var _nearby_decoder: RefCounted = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd").new()
var _last_quest_window: Dictionary = {}
var _last_task: Dictionary = {}
var _quest_indicators: Dictionary = {}
var _last_find_group: Dictionary = {}
var quest_rewards_sent := 0
var quest_removals_sent := 0
var lfg_sent := 0
var emblems_sent := 0
var pickups_sent := 0


func last_quest_window() -> Dictionary:
	return _last_quest_window.duplicate(true)


func last_task() -> Dictionary:
	return _last_task.duplicate(true)


func quest_indicators() -> Dictionary:
	return _quest_indicators.duplicate(true)


func last_find_group() -> Dictionary:
	return _last_find_group.duplicate(true)


func send_quest_reward(accept: bool, chosen: Array, quest_id: int, npc_object_id: int) -> Dictionary:
	var result: Dictionary = _session.call("request_quest_reward", accept, chosen, quest_id, npc_object_id) as Dictionary
	if bool(result.get("ok", false)):
		quest_rewards_sent += 1
	return result


func send_remove_quest(quest_index: int) -> Dictionary:
	var result: Dictionary = _session.call("request_remove_quest", quest_index) as Dictionary
	if bool(result.get("ok", false)):
		quest_removals_sent += 1
	return result


func send_lfg_flag(flag: bool) -> Dictionary:
	var result: Dictionary = _session.call("request_lfg_flag", flag) as Dictionary
	if bool(result.get("ok", false)):
		lfg_sent += 1
	return result


func send_lfg_list(grouped: bool = false) -> Dictionary:
	var result: Dictionary = _session.call("request_lfg_list", grouped) as Dictionary
	if bool(result.get("ok", false)):
		lfg_sent += 1
	return result


func send_emblem(primary_color: int, secondary_color: int, pattern: int, logo: int) -> Dictionary:
	var result: Dictionary = _session.call("request_emblem", primary_color, secondary_color, pattern, logo) as Dictionary
	if bool(result.get("ok", false)):
		emblems_sent += 1
	return result


func send_pickup() -> Dictionary:
	var result: Dictionary = _session.call("request_pickup") as Dictionary
	if bool(result.get("ok", false)):
		pickups_sent += 1
	return result


## P1-115 — téléportation, portes, montures, changement de région
## (DaocOpenDaocTravelCodec).
const TravelCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTravelCodec.gd")
## 0x04 : le serveur nous DÉPLACE dans la région (/stuck, pierre de liaison,
## téléporteur) ou ne fait que tourner notre cap (`heading_only`).
signal character_jump_received(jump: Dictionary)
## 0x99 : une porte s ouvre ou se ferme.
signal door_state_received(door: Dictionary)
## 0x4E : notre cheval (`own`) ou celui d un joueur visible.
signal controlled_horse_received(horse: Dictionary)
## 0xC8 : quelqu un monte ou descend d une monture.
signal riding_received(riding: Dictionary)
## 0xB7 : changement de région ; l entrée monde est rejouée derrière.
signal region_changed_received(region: Dictionary)
## Le rejeu de l entrée monde attend que la scène ait bâti la nouvelle région.
signal region_world_loading_requested
var _door_states: Dictionary = {}
var _own_horse: Dictionary = {}
var _last_character_jump: Dictionary = {}
var _last_region_change: Dictionary = {}
var _last_region_change_request_msec := -TravelCodec.REGION_CHANGE_REQUEST_COOLDOWN_MSEC
var door_requests_sent := 0
var dismount_requests_sent := 0
var region_change_requests_sent := 0


## Portes vues depuis l entrée : identifiant -> dernier 0x99.
func door_states() -> Dictionary:
	return _door_states.duplicate(true)


func own_horse() -> Dictionary:
	return _own_horse.duplicate(true)


func last_character_jump() -> Dictionary:
	return _last_character_jump.duplicate(true)


func last_region_change() -> Dictionary:
	return _last_region_change.duplicate(true)


func region_change_in_progress() -> bool:
	return bool(_world_entry.get("region_change_in_progress"))


func send_door_request(door_id: int, open: bool = true) -> Dictionary:
	var result: Dictionary = _session.call("request_door", door_id, open) as Dictionary
	if bool(result.get("ok", false)):
		door_requests_sent += 1
	return result


func send_dismount() -> Dictionary:
	var result: Dictionary = _session.call("request_dismount") as Dictionary
	if bool(result.get("ok", false)):
		dismount_requests_sent += 1
	return result


## Le client d origine n envoie pas deux 0x90 en moins de dix secondes
## (`DAT_00d90498 + 10000`) : rester dans l aire d un saut ne le rejoue pas.
func send_region_change_request(jump_point_id: int, now_msec: int = -1) -> Dictionary:
	var now := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	if now - _last_region_change_request_msec < TravelCodec.REGION_CHANGE_REQUEST_COOLDOWN_MSEC:
		return {"ok": false, "error": "region_change_request_cooldown"}
	if region_change_in_progress():
		return {"ok": false, "error": "region_change_in_progress"}
	var result: Dictionary = _session.call("request_region_change", jump_point_id) as Dictionary
	if bool(result.get("ok", false)):
		region_change_requests_sent += 1
		_last_region_change_request_msec = now
	return result


## La scène a bâti la nouvelle région : PlayerInit (0xE8) part.
func finish_region_world_loading() -> Dictionary:
	return _world_entry.call("finish_client_world_loading") as Dictionary


func _on_region_changed(region: Dictionary) -> void:
	_last_region_change = region.duplicate(true)
	_world_model.call("reset_entities")
	# Les entités de l ancienne région n existent plus pour le serveur.
	_door_states.clear()
	region_changed_received.emit(region)
	var sequence := int(_session.call("next_sequence_value"))
	var result: Dictionary = _world_entry.call("begin_region_change", sequence, int(_session.get("session_id"))) as Dictionary
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "region_change_failed")))

## P1-114 — marchand, argent, encombrement, échange (DaocOpenDaocMerchantCodec).
## 0x17 : une page de la boutique (DOL en envoie une par page du catalogue).
signal merchant_window_received(page: Dictionary)
## 0xFA : la bourse, en cuivre.
signal money_received(money: Dictionary)
## 0xBD : le poids porté et le maximum (la Force modifiée).
signal encumberance_received(encumberance: Dictionary)
## 0xEA : la fenêtre d échange (ou sa fermeture : 40 octets nuls).
signal trade_window_received(trade: Dictionary)
var _merchant_pages: Dictionary = {}
var _last_merchant_window: Dictionary = {}
var _last_money: Dictionary = {}
var _last_encumberance: Dictionary = {}
var _last_trade_window: Dictionary = {}
var merchant_buys_sent := 0
var merchant_sells_sent := 0
var merchant_appraisals_sent := 0
var trade_updates_sent := 0


## Toutes les pages reçues depuis la dernière ouverture, par numéro.
func merchant_pages() -> Dictionary:
	return _merchant_pages.duplicate(true)


func last_merchant_window() -> Dictionary:
	return _last_merchant_window.duplicate(true)


func last_money() -> Dictionary:
	return _last_money.duplicate(true)


func last_encumberance() -> Dictionary:
	return _last_encumberance.duplicate(true)


func last_trade_window() -> Dictionary:
	return _last_trade_window.duplicate(true)


func forget_merchant_pages() -> void:
	_merchant_pages.clear()


func send_buy(page_slot: int, count: int = 1, window_type: int = -1) -> Dictionary:
	var kind := window_type
	if kind < 0:
		kind = int(_last_merchant_window.get("window_type", 0))
	var result: Dictionary = _session.call("request_buy", page_slot, count, kind) as Dictionary
	if bool(result.get("ok", false)):
		merchant_buys_sent += 1
	return result


func send_sell(inventory_slot: int) -> Dictionary:
	var result: Dictionary = _session.call("request_sell", inventory_slot) as Dictionary
	if bool(result.get("ok", false)):
		merchant_sells_sent += 1
	return result


func send_appraise(inventory_slot: int) -> Dictionary:
	var result: Dictionary = _session.call("request_appraise", inventory_slot) as Dictionary
	if bool(result.get("ok", false)):
		merchant_appraisals_sent += 1
	return result


func send_modify_trade(response: int, slots: Array = [], copper: int = 0, repairing: bool = false, combine: bool = false) -> Dictionary:
	var result: Dictionary = _session.call("request_modify_trade", response, slots, copper, repairing, combine) as Dictionary
	if bool(result.get("ok", false)):
		trade_updates_sent += 1
	return result


var _last_titles: Dictionary = {}
var _current_title := ""
var _last_free_level: Dictionary = {}
var _last_master_level_window: Dictionary = {}
var _last_champion_page: Dictionary = {}
var _last_ground_target: Dictionary = {}
var _last_siege_interface: Dictionary = {}
var _last_timer_window: Dictionary = {}
var bonuses_requests_sent := 0
var ground_targets_sent := 0
var siege_commands_sent := 0
var train_one_sent := 0
var champion_trains_sent := 0


func last_titles() -> Dictionary:
	return _last_titles.duplicate(true)


func current_title() -> String:
	return _current_title


func last_free_level() -> Dictionary:
	return _last_free_level.duplicate(true)


func last_master_level_window() -> Dictionary:
	return _last_master_level_window.duplicate(true)


func last_champion_page() -> Dictionary:
	return _last_champion_page.duplicate(true)


func last_ground_target() -> Dictionary:
	return _last_ground_target.duplicate(true)


func last_siege_interface() -> Dictionary:
	return _last_siege_interface.duplicate(true)


func last_timer_window() -> Dictionary:
	return _last_timer_window.duplicate(true)


## Le rang de royaume se deduit des points (0x91) et du royaume / sexe du
## personnage choisi ; le serveur n envoie pas le rang lui-meme.
func _career_of(points: Dictionary) -> Dictionary:
	var character: Dictionary = _session.get("selected_character") as Dictionary
	var raw: Dictionary = character.get("raw", {}) as Dictionary
	var female := str(raw.get("gender", "")).to_lower() == "female" or int(raw.get("gender_id", 0)) == 2
	return CareerCodec.describe_realm_points(points, int(_profile_public.get("realm", 1)), female)


func send_master_level_request(master_level: int) -> Dictionary:
	return _session.call("request_dialog_value", ProgressCodec_DIALOG_MASTER_LEVEL, clampi(master_level, 0, 10)) as Dictionary


const ProgressCodec_DIALOG_MASTER_LEVEL := 0x19


func send_bonuses_request() -> Dictionary:
	var result: Dictionary = _session.call("request_bonuses_list") as Dictionary
	if bool(result.get("ok", false)):
		bonuses_requests_sent += 1
	return result


func send_train_one(index: int, realm_ability: bool = false) -> Dictionary:
	var result: Dictionary = _session.call("request_train_one", index, realm_ability) as Dictionary
	if bool(result.get("ok", false)):
		train_one_sent += 1
	return result


func send_champion_train(line_index: int, row: int, column: int) -> Dictionary:
	var result: Dictionary = _session.call("request_champion_train", line_index, row, column) as Dictionary
	if bool(result.get("ok", false)):
		champion_trains_sent += 1
	return result


func send_ground_target(x: int, y: int, z: int, visible: bool = true) -> Dictionary:
	var result: Dictionary = _session.call("request_ground_target", x, y, z, visible) as Dictionary
	if bool(result.get("ok", false)):
		ground_targets_sent += 1
		_last_ground_target = {"ok": true, "x": x, "y": y, "z": z, "visible": visible, "source": "client"}
	return result


func send_siege_command(action: int, ammo: int = 0) -> Dictionary:
	var result: Dictionary = _session.call("request_siege_command", action, ammo) as Dictionary
	if bool(result.get("ok", false)):
		siege_commands_sent += 1
	return result

var _session: RefCounted = SessionScript.new()
var _transport: Node = null
var _authentication: Node = null
var _world_entry: RefCounted = WorldEntryScript.new()
var _world_model: RefCounted = WorldModelScript.new()
var _profile_public: Dictionary = {}
var _connection_profile: Dictionary = {}
var _wired := false
var _client_playing_published := false


func _ready() -> void:
	_ensure_components()


## Cadence du PingRequest, en secondes. Le client d'origine est autour de 4 s.
@export var ping_interval_sec: float = 4.0
var _ping_clock := 0.0


func _process(delta: float) -> void:
	if _transport == null or not bool((_transport.call("snapshot") as Dictionary).get("connected", false)):
		return
	_ping_clock += delta
	# P1-115 : pendant le rejeu de l entree monde, c est _world_entry qui numerote
	# les paquets ; un ping de la session reprendrait les memes numeros.
	if _ping_clock >= ping_interval_sec and not region_change_in_progress():
		_ping_clock = 0.0
		_session.call("request_ping")


func _ensure_components() -> void:
	if _transport == null:
		_transport = TransportScript.new()
		_transport.name = "TcpTransport"
	if _transport.get_parent() == null:
		add_child(_transport)
	if _authentication == null:
		_authentication = AuthenticationScript.new()
		_authentication.name = "Authentication"
		add_child(_authentication)
	if not _wired:
		_wire_components()
		_wired = true


func start(profile: Dictionary, realm: int = 1) -> Dictionary:
	_ensure_components()
	_client_playing_published = false
	if not bool(profile.get("ok", false)):
		return {"ok": false, "error": "invalid_online_profile"}
	_profile_public = {
		"host": str(profile.get("host", "")),
		"port": int(profile.get("port", 0)),
		"account_configured": str(profile.get("account", "")) != "",
		"password_configured": str(profile.get("password", "")) != "",
		"character": str(profile.get("character", "")),
	}
	_profile_public["realm"] = clampi(realm, 1, 3)
	_connection_profile = profile.duplicate(true)
	var begun: Dictionary = _session.call("begin_connection") as Dictionary
	if not bool(begun.get("ok", false)):
		return begun
	var transport_result: Dictionary = _transport.call("connect_profile", profile) as Dictionary
	if not bool(transport_result.get("ok", false)):
		return _session.call("fail", str(transport_result.get("error", "transport_start_failed"))) as Dictionary
	return snapshot()


## Mesure en live le 2026-09-15 : l'overview (0x2A/0xFC) peut arriver AVANT le
## SessionID (0x28). Choisir dans cette fenetre rendait `authentication_not_ready`
## et tuait la session. La selection est donc mise en attente jusqu'a
## `authentication_ready`, puis envoyee.
var _pending_character: Dictionary = {}


## 2026-09-30 — création depuis l'écran de sélection. La liste renvoyée par le
## serveur ressort par `character_overview_received`, comme au login.
func create_character(data: Dictionary) -> Dictionary:
	if _authentication == null:
		return {"ok": false, "error": "not_connected"}
	return _authentication.call("request_character_create", data) as Dictionary


func choose_character(character: Dictionary) -> Dictionary:
	if str(_authentication.get("state")) != AuthenticationScript.READY:
		if str(_authentication.get("state")) == AuthenticationScript.FAILED:
			return {"ok": false, "error": "authentication_failed"}
		_pending_character = character.duplicate(true)
		return {"ok": true, "deferred": true, "reason": "session_id_not_yet_received"}
	return _select_now(character)


func _select_now(character: Dictionary) -> Dictionary:
	var session_result: Dictionary = _session.call("choose_character", character) as Dictionary
	if not bool(session_result.get("ok", false)):
		return session_result
	var selection_result: Dictionary = _authentication.call("request_character_select", character) as Dictionary
	if not bool(selection_result.get("ok", false)):
		return _session.call("fail", str(selection_result.get("error", "character_select_failed"))) as Dictionary
	# Le WorldInit (0xD4) porte le SessionID : il attend le 0x28 que le 0x10
	# vient de declencher. En suite a faux pair le 0x28 peut deja etre la.
	if int(_authentication.get("session_id")) != 0:
		var entry_result := _begin_world_entry(character)
		if not bool(entry_result.get("ok", false)):
			return entry_result
	else:
		_awaiting_world_entry = character.duplicate(true)
	return {"ok": true, "session": session_result, "selection": selection_result,
		"world_entry": "sent" if _awaiting_world_entry.is_empty() else "awaiting_session_id"}


var _awaiting_world_entry: Dictionary = {}
var _world_decode_failures := 0
var _last_world_decode_error := ""


func _begin_world_entry(character: Dictionary) -> Dictionary:
	var entry_result: Dictionary = _world_entry.call("begin", character, int(_authentication.call("next_sequence_value")), int(_authentication.get("session_id"))) as Dictionary
	if not bool(entry_result.get("ok", false)):
		return _session.call("fail", str(entry_result.get("error", "world_entry_failed"))) as Dictionary
	return entry_result


func _on_session_id_received(_session_id: int) -> void:
	if _awaiting_world_entry.is_empty():
		return
	var character := _awaiting_world_entry.duplicate(true)
	_awaiting_world_entry = {}
	var result := _begin_world_entry(character)
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "world_entry_failed")))


func request_staff_equipment() -> Dictionary:
	return _session.call("request_staff_equipment") as Dictionary


func send_player_movement(position: Dictionary) -> Dictionary:
	if region_change_in_progress():
		return {"ok": false, "error": "region_change_in_progress"}
	return _session.call("request_movement", position) as Dictionary


func world_snapshot() -> Dictionary:
	return _world_model.call("snapshot") as Dictionary


func is_playing() -> bool:
	return str((_session.call("snapshot") as Dictionary).get("state", "")) == SessionScript.PLAYING


func stop(reason: String = "client_close") -> void:
	if _transport != null:
		_transport.call("close", reason)


## 2026-09-27 (retour live /stuck) : retenter la liste des personnages. Un
## `start()` sur une session deja ouverte etait refuse (`session_already_started`)
## et les nouvelles tentatives du frontend ne faisaient RIEN. On ferme d abord,
## sans signaler d echec, puis on reconnecte.
var _restarting := false


func restart(profile: Dictionary, realm: int = 1) -> Dictionary:
	_ensure_components()
	_restarting = true
	stop("restart")
	var state := str((_session.call("snapshot") as Dictionary).get("state", ""))
	if state != SessionScript.DISCONNECTED and state != SessionScript.FAILED:
		_session.call("fail", "restart")
	_restarting = false
	_pending_character = {}
	_awaiting_world_entry = {}
	return start(profile, realm)


func snapshot() -> Dictionary:
	return {
		"ok": bool((_session.call("snapshot") as Dictionary).get("ok", false)),
		"session": _session.call("snapshot"),
		"authentication": _authentication.call("snapshot") if _authentication != null else {},
		"world_entry": _world_entry.call("snapshot"),
		"world": _world_model.call("snapshot"),
		"transport": _transport.call("snapshot") if _transport != null and _transport.has_method("snapshot") else {},
		"profile": _profile_public.duplicate(true),
		"world_decode_failures": _world_decode_failures,
		"status_packets": status_packets,
		"message_packets": message_packets,
		"animation_packets": animation_packets,
		"last_world_decode_error": _last_world_decode_error,
	}


func set_transport_for_test(transport: Node) -> void:
	_transport = transport


func _wire_components() -> void:
	_transport.connected.connect(_on_transport_connected)
	_transport.server_packet_received.connect(_on_server_packet_received)
	_transport.transport_error.connect(_on_transport_error)
	_transport.disconnected.connect(_on_transport_disconnected)
	_session.state_changed.connect(_on_session_state_changed)
	_session.outbound_packet_ready.connect(_on_outbound_packet_ready)
	_session.inventory_changed.connect(_on_inventory_changed)
	if _session.has_signal("external_inventory_changed"):
		_session.external_inventory_changed.connect(func(window: Dictionary) -> void: external_inventory_changed.emit(window))
	_authentication.outbound_packet_ready.connect(_on_outbound_packet_ready)
	_authentication.character_overview_received.connect(_on_character_overview_received)
	_authentication.authentication_failed.connect(_on_authentication_failed)
	_authentication.authentication_ready.connect(_on_authentication_ready)
	_authentication.session_id_received.connect(_on_session_id_received)
	_world_entry.outbound_packet_ready.connect(_on_outbound_packet_ready)
	_world_entry.client_world_loading_requested.connect(func(): client_world_loading_requested.emit())
	_world_entry.world_ready.connect(_on_world_ready)
	_world_entry.region_world_loading_requested.connect(func(): region_world_loading_requested.emit())
	_world_model.player_position_changed.connect(_on_player_position_model)
	_world_model.entities_changed.connect(func(value: Dictionary): world_entities_changed.emit(value))
	_world_model.entity_event.connect(func(event: Dictionary): world_entity_event.emit(event))


func _on_transport_connected() -> void:
	var result: Dictionary = _session.call("transport_connected") as Dictionary
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "transport_state_failed")))
		return
	result = _authentication.call("begin", _connection_profile, int(_profile_public.get("realm", 1))) as Dictionary
	_connection_profile.clear()
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "authentication_start_failed")))


var status_packets := 0
var message_packets := 0
var animation_packets := 0
var _last_status: Dictionary = {}
var _pending_spell_lines: Dictionary = {}
var _spell_lines: Array = []
const SkillListCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocSkillListCodec.gd")
const AnimationCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocAnimationCodec.gd")
const ProgressCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocProgressCodec.gd")
const EnvironmentCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEnvironmentCodec.gd")
const GroupCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocGroupCodec.gd")
const CharacterStatsCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCharacterStatsCodec.gd")
const TrainerCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTrainerCodec.gd")
## P1-107 — l entraineur : specs et capacites de royaume avec leurs points.
signal trainer_window_received(trainer: Dictionary)
var _trainer: Dictionary = {}


func trainer_snapshot() -> Dictionary:
	return _trainer.duplicate(true)


func send_trainer_window_request() -> Dictionary:
	return _session.call("request_trainer_window") as Dictionary


func send_train(spec_targets: Dictionary, ra_targets: Dictionary) -> Dictionary:
	return _session.call("request_train", spec_targets, ra_targets) as Dictionary
## P1-106 — caracteristiques, resistances, degats/competence d arme, AF.
signal character_stats_received(stats: Dictionary)
signal character_resists_received(resists: Dictionary)
signal weapon_armor_received(values: Dictionary)
var _last_character_stats: Dictionary = {}
var _last_character_resists: Dictionary = {}
var _last_weapon_armor: Dictionary = {}


func last_character_stats() -> Dictionary:
	return _last_character_stats.duplicate(true)


func last_character_resists() -> Dictionary:
	return _last_character_resists.duplicate(true)


func last_weapon_armor() -> Dictionary:
	return _last_weapon_armor.duplicate(true)
## P1-105 — le groupe : la liste (0x16/06) puis les mises a jour (0x70) sont
## fondues dans un modele par index ; `group_changed` porte l etat COMPLET.
signal group_changed(group: Dictionary)
signal friends_changed(friends: Array, added: Array, removed: Array)
signal emote_received(emote: Dictionary)
var _group_members: Dictionary = {}
var _friends: Array = []
var group_updates := 0


func group_snapshot() -> Dictionary:
	var members: Array = []
	var keys: Array = _group_members.keys()
	keys.sort()
	for key in keys:
		members.append((_group_members[key] as Dictionary).duplicate(true))
	return {"in_group": not members.is_empty(), "members": members, "updates": group_updates}


func friends() -> Array:
	return _friends.duplicate(true)


func _apply_group_window(window: Dictionary) -> void:
	var fresh: Dictionary = {}
	for value in window.get("members", []):
		var member := (value as Dictionary).duplicate(true)
		var previous: Dictionary = _group_members.get(int(member.get("index", 0)), {}) as Dictionary
		for key in ["health_percent", "mana_percent", "endurance_percent", "status", "flags", "zone_skin_id", "zone_x", "zone_y", "icons"]:
			if previous.has(key):
				member[key] = previous[key]
		fresh[int(member.get("index", 0))] = member
	_group_members = fresh
	group_updates += 1
	group_changed.emit(group_snapshot())


func _apply_member_updates(update: Dictionary) -> void:
	var touched := false
	for value in update.get("updates", []):
		var u := value as Dictionary
		var index := int(u.get("index", -1))
		if not _group_members.has(index):
			# Un 0x70 avant la liste : on retient l index, le nom viendra.
			_group_members[index] = {"index": index, "name": "", "class_name": "", "object_id": 0, "level": 0}
		var member: Dictionary = _group_members[index]
		match str(u.get("kind", "")):
			"status":
				for key in ["health_percent", "mana_percent", "endurance_percent", "status", "flags"]:
					member[key] = u[key]
			"map":
				for key in ["zone_skin_id", "zone_x", "zone_y"]:
					member[key] = u[key]
			"icons":
				member["icons"] = u.get("icons", [])
		touched = true
	if touched:
		group_updates += 1
		group_changed.emit(group_snapshot())
## P1-94 — l heure et la meteo du serveur (0x7E, 0x92), et le journal brut des
## paquets de parite (0x4B, 0x7E, 0x92) que la scene ecrit dans
## reports/online/last_parity_packets.json pour prouver les dispositions.
signal server_time_received(time: Dictionary)
signal weather_received(weather: Dictionary)
var _last_server_time: Dictionary = {}
var _last_weather: Dictionary = {}
var _parity_packet_log: Array = []
const PARITY_LOG_LIMIT := 64


func last_server_time() -> Dictionary:
	return _last_server_time.duplicate(true)


func last_weather() -> Dictionary:
	return _last_weather.duplicate(true)


func parity_packet_log() -> Array:
	return _parity_packet_log.duplicate(true)


func _log_parity_packet(opcode: int, payload: PackedByteArray, decoded: Dictionary) -> void:
	if _parity_packet_log.size() >= PARITY_LOG_LIMIT:
		return
	_parity_packet_log.append({"opcode": "0x%02X" % opcode, "size": payload.size(), "hex": payload.hex_encode(), "decoded": decoded})


func spell_lines() -> Array:
	return _spell_lines.duplicate(true)


func send_use_spell(level: int, line_index: int, target_visible: bool = true) -> Dictionary:
	return _session.call("request_use_spell", level, line_index, target_visible) as Dictionary


func send_target(object_id: int, attack_mode: bool = false) -> Dictionary:
	return _session.call("request_target", object_id, attack_mode) as Dictionary


func send_attack_mode(on: bool) -> Dictionary:
	return _session.call("request_attack_mode", on) as Dictionary


var _last_points: Dictionary = {}
var _pending_skills: Array = []
var _skills: Array = []
var _crafting_skills: Array = []
## P1-86 — chaque 0x16 recu, en hexadecimal : aucune capture ne porte encore les
## lignes de sorts d'Eden, et les icones en dependent. Le monde l'ecrit dans
## reports/online/last_skill_packets.json.
var _various_update_log: Array = []


func various_update_log() -> Array:
	return _various_update_log.duplicate(true)
var _last_max_speed: Dictionary = {}


func crafting_skills() -> Array:
	return _crafting_skills.duplicate(true)


func last_max_speed() -> Dictionary:
	return _last_max_speed.duplicate(true)


func skills() -> Array:
	return _skills.duplicate(true)


## Index et type que UseSkill attend pour une entree de la liste : les
## specialisations gardent leur index absolu (type 0) ; tout le reste est compte
## a partir de la premiere entree non-specialisation.
## P1-98 — 0x71 UseSlot : arme (10 / 12 / 13) ou objet du sac (40..79) glisse
## dans la quickbar ; 0xDD MoveItem : glisser-deposer inventaire <-> sac.
var use_slots_sent := 0
var move_items_sent := 0


func send_detail_request(object_type: int, object_id: int) -> Dictionary:
	return _session.call("request_detail", object_type, object_id) as Dictionary


func send_use_slot(slot: int, use_type: int = 0) -> Dictionary:
	var result: Dictionary = _session.call("request_use_slot", slot, use_type, true) as Dictionary
	if bool(result.get("ok", false)):
		use_slots_sent += 1
	return result


func send_move_item(from_slot: int, to_slot: int, item_count: int = 1) -> Dictionary:
	var result: Dictionary = _session.call("request_move_item", from_slot, to_slot, item_count) as Dictionary
	if bool(result.get("ok", false)):
		move_items_sent += 1
	return result


func send_use_skill(skill: Dictionary, target_visible: bool = true) -> Dictionary:
	var type := int(skill.get("skill_type", 0))
	var index := int(skill.get("index", 0))
	if type > 0:
		var first_non_spec := 0
		for entry in _skills:
			if int((entry as Dictionary).get("skill_type", 0)) == 0:
				first_non_spec += 1
			else:
				break
		index -= first_non_spec
	return _session.call("request_use_skill", index, type, target_visible) as Dictionary
var _quests: Dictionary = {}


func last_player_points() -> Dictionary:
	return _last_points.duplicate(true)


func quest_journal() -> Dictionary:
	return _quests.duplicate(true)


func send_interact(object_id: int) -> Dictionary:
	return _session.call("request_interact", object_id) as Dictionary


func send_dialog_response(dialog: Dictionary, accept: bool) -> Dictionary:
	return _session.call("request_dialog_response", dialog, accept) as Dictionary


func send_command(command: String) -> Dictionary:
	return _session.call("request_command", command) as Dictionary


func finish_client_world_loading() -> Dictionary:
	return _world_entry.call("finish_client_world_loading") as Dictionary


func publish_client_playing() -> void:
	if _client_playing_published:
		return
	_client_playing_published = true
	state_changed.emit(SessionScript.PLAYING)


func last_player_status() -> Dictionary:
	return _last_status.duplicate(true)


func _dispatch_status_and_messages(packet: PackedByteArray) -> void:
	var parsed: Dictionary = _codec_peek.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return
	var opcode := int(parsed.get("opcode", -1))
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	if opcode == EnvironmentCodec.OPCODE_TIME:
		var time: Dictionary = EnvironmentCodec.decode_time(payload)
		_log_parity_packet(opcode, payload, time)
		if bool(time.get("ok", false)):
			_last_server_time = time
			server_time_received.emit(time)
	elif opcode == EnvironmentCodec.OPCODE_WEATHER:
		var weather: Dictionary = EnvironmentCodec.decode_weather(payload)
		_log_parity_packet(opcode, payload, weather)
		if bool(weather.get("ok", false)):
			_last_weather = weather
			weather_received.emit(weather)
	elif opcode == 0x4B:
		_log_parity_packet(opcode, payload, {})
	elif opcode == ProgressCodec.OPCODE_DETAIL_WINDOW and payload.size() > 0 and int(payload[0]) == 1:
		# P1-109 : l octet 0 a 1 = « Player Statistics » + titres (/settitle).
		var titles: Dictionary = CareerCodec.decode_titles_window(payload)
		_log_parity_packet(opcode, payload, titles)
		if bool(titles.get("ok", false)):
			_last_titles = titles.duplicate(true)
			titles_received.emit(titles)
	elif opcode == ProgressCodec.OPCODE_DETAIL_WINDOW:
		var detail: Dictionary = ProgressCodec.decode_detail_window(payload)
		_log_parity_packet(opcode, payload, detail)
		if bool(detail.get("ok", false)):
			detail_window_received.emit(detail)
	elif opcode == CareerCodec.OPCODE_VISUAL_EFFECT and payload.size() >= 4 and int(payload[2]) == QuestSocialCodec.SUBCODE_QUEST_INDICATOR:
		# P1-110 : l icone de quete d un PNJ.
		var indicator: Dictionary = QuestSocialCodec.decode_quest_indicator(payload)
		_log_parity_packet(opcode, payload, indicator)
		if bool(indicator.get("ok", false)):
			if int(indicator.get("indicator", 0)) == 0:
				_quest_indicators.erase(int(indicator.get("object_id", 0)))
			else:
				_quest_indicators[int(indicator.get("object_id", 0))] = indicator.duplicate(true)
			quest_indicator_received.emit(indicator)
	elif opcode == CareerCodec.OPCODE_VISUAL_EFFECT and payload.size() >= 3 and (int(payload[2]) == CareerCodec.SUBCODE_FREE_LEVEL or int(payload[2]) == CareerCodec.SUBCODE_TITLE_UPDATE):
		var effect: Dictionary = CareerCodec.decode_visual_effect(payload)
		_log_parity_packet(opcode, payload, effect)
		if bool(effect.get("ok", false)):
			if str(effect.get("kind", "")) == "free_level":
				_last_free_level = effect.duplicate(true)
				free_level_received.emit(effect)
			else:
				var own_id := int(((_world_model.call("snapshot") as Dictionary).get("player_position", {}) as Dictionary).get("object_id", -1))
				effect["mine"] = own_id < 0 or own_id == int(effect.get("object_id", -2))
				if bool(effect["mine"]):
					_current_title = str(effect.get("title", ""))
				title_updated.emit(effect)
	elif opcode == CareerCodec.OPCODE_MASTER_LEVEL_WINDOW:
		var window: Dictionary = CareerCodec.decode_master_level_window(payload)
		_log_parity_packet(opcode, payload, window)
		if bool(window.get("ok", false)):
			_last_master_level_window = window.duplicate(true)
			master_level_window_received.emit(window)
	elif opcode == TrainerCodec.OPCODE_TRAINER_WINDOW and payload.size() >= 5 and int(payload[2]) == CareerCodec.TRAINER_CODE_CHAMPION:
		var page: Dictionary = CareerCodec.decode_champion_trainer_window(payload)
		_log_parity_packet(opcode, payload, page)
		if bool(page.get("ok", false)):
			_last_champion_page = page.duplicate(true)
			champion_trainer_received.emit(page)
	elif opcode == CombatControlCodec.OPCODE_GROUND_TARGET:
		var target: Dictionary = CombatControlCodec.decode_change_ground_target(payload)
		_log_parity_packet(opcode, payload, target)
		if bool(target.get("ok", false)):
			target["source"] = "server"
			_last_ground_target = target.duplicate(true)
			ground_target_received.emit(target)
	elif opcode == CombatControlCodec.OPCODE_SIEGE:
		var siege: Dictionary = CombatControlCodec.decode_siege_interface(payload)
		_log_parity_packet(opcode, payload, siege)
		if bool(siege.get("ok", false)):
			_last_siege_interface = siege.duplicate(true)
			siege_interface_received.emit(siege)
	elif opcode == CombatControlCodec.OPCODE_SIEGE_ANIMATION:
		var animation: Dictionary = CombatControlCodec.decode_siege_animation(payload)
		_log_parity_packet(opcode, payload, animation)
		if bool(animation.get("ok", false)):
			siege_animation_received.emit(animation)
	elif opcode == CombatControlCodec.OPCODE_CHANGE_TARGET:
		var change: Dictionary = CombatControlCodec.decode_change_target(payload)
		_log_parity_packet(opcode, payload, change)
		if bool(change.get("ok", false)):
			target_change_received.emit(int(change.get("object_id", 0)))
	elif opcode == CombatControlCodec.OPCODE_TIMER_WINDOW:
		var timer: Dictionary = CombatControlCodec.decode_timer_window(payload)
		_log_parity_packet(opcode, payload, timer)
		if bool(timer.get("ok", false)):
			_last_timer_window = timer.duplicate(true)
			timer_window_received.emit(timer)
	elif opcode == ProgressCodec.OPCODE_UPDATE_ICONS:
		var icons: Dictionary = ProgressCodec.decode_update_icons(payload)
		_log_parity_packet(opcode, payload, icons)
		if bool(icons.get("ok", false)):
			# P1-108 : un 0x7F de 1.110+ est un DELTA par case, pas la liste complete.
			_last_effects = ProgressCodec.apply_update_icons(_last_effects, icons)
			effects_received.emit(_last_effects.duplicate(true))
	elif opcode == ProgressCodec.OPCODE_CONCENTRATION_LIST:
		var conc: Dictionary = ProgressCodec.decode_concentration_list(payload)
		_log_parity_packet(opcode, payload, conc)
		if bool(conc.get("ok", false)):
			_last_concentration = (conc.get("effects", []) as Array).duplicate(true)
			concentration_received.emit(_last_concentration.duplicate(true))
	elif opcode == ProgressCodec.OPCODE_DISABLE_SKILLS:
		var disabled: Dictionary = ProgressCodec.decode_disable_skills(payload)
		_log_parity_packet(opcode, payload, disabled)
		if bool(disabled.get("ok", false)):
			_apply_disable_skills(disabled)
	elif opcode == ProgressCodec.OPCODE_PET_WINDOW and payload.size() < 28:
		# Le 0x88 de l entree monde (position, >= 28 octets) est consomme par
		# DaocOnlineWorldEntry ; un petit 0x88 en jeu est la fenetre du pet.
		var pet: Dictionary = ProgressCodec.decode_pet_window(payload)
		_log_parity_packet(opcode, payload, pet)
		if bool(pet.get("ok", false)):
			_last_pet_window = pet.duplicate(true)
			pet_window_received.emit(pet)
	if opcode == StatusMessageCodec.OPCODE_STATUS:
		var status: Dictionary = StatusMessageCodec.decode_status_payload(payload)
		if bool(status.get("ok", false)):
			status_packets += 1
			_last_status = status
			player_status_received.emit(status)
	elif opcode == StatusMessageCodec.OPCODE_MESSAGE:
		var message: Dictionary = StatusMessageCodec.decode_message_payload(payload)
		if bool(message.get("ok", false)):
			message_packets += 1
			server_message_received.emit(message)
	elif opcode == TrainerCodec.OPCODE_TRAINER_WINDOW and not (payload.size() >= 5 and int(payload[2]) == CareerCodec.TRAINER_CODE_CHAMPION):
		var page: Dictionary = TrainerCodec.decode_trainer_window(payload)
		_log_parity_packet(opcode, payload, page)
		if bool(page.get("ok", false)):
			match str(page.get("kind", "")):
				"specs":
					_trainer["specs"] = page.get("entries", [])
					_trainer["spec_points"] = int(page.get("points", 0))
				"realm_abilities":
					_trainer["realm_abilities"] = page.get("entries", [])
					_trainer["realm_points"] = int(page.get("points", 0))
				"skill_names":
					var names: Array = _trainer.get("skill_names", [])
					names.append_array(page.get("names", []))
					_trainer["skill_names"] = names
			_trainer["pages"] = int(_trainer.get("pages", 0)) + 1
			trainer_window_received.emit(trainer_snapshot())
	elif opcode == CharacterStatsCodec.OPCODE_STATS_UPDATE:
		var table: Dictionary = CharacterStatsCodec.decode_stats_update(payload)
		_log_parity_packet(opcode, payload, table)
		if bool(table.get("ok", false)):
			if str(table.get("kind", "")) == "resists":
				_last_character_resists = table
				character_resists_received.emit(table)
			else:
				_last_character_stats = table
				character_stats_received.emit(table)
	elif opcode == SkillListCodec.OPCODE_VARIOUS_UPDATE and payload.size() >= 2 and int(payload[0]) == CharacterStatsCodec.SUBCODE_WEAPON_ARMOR:
		var values: Dictionary = CharacterStatsCodec.decode_weapon_armor(payload)
		_log_parity_packet(opcode, payload, values)
		if bool(values.get("ok", false)):
			_last_weapon_armor = values
			weapon_armor_received.emit(values)
	elif opcode == SkillListCodec.OPCODE_VARIOUS_UPDATE and payload.size() >= 2 and int(payload[0]) == GroupCodec.SUBCODE_GROUP_WINDOW:
		var window: Dictionary = GroupCodec.decode_group_window(payload)
		_log_parity_packet(opcode, payload, window)
		if bool(window.get("ok", false)):
			_apply_group_window(window)
	elif opcode == GroupCodec.OPCODE_GROUP_MEMBER_UPDATE:
		var update: Dictionary = GroupCodec.decode_member_update(payload)
		_log_parity_packet(opcode, payload, update)
		if bool(update.get("ok", false)):
			_apply_member_updates(update)
	elif opcode == GroupCodec.OPCODE_ADD_FRIEND or opcode == GroupCodec.OPCODE_REMOVE_FRIEND:
		var list: Dictionary = GroupCodec.decode_friends(payload)
		if bool(list.get("ok", false)):
			var names: Array = list.get("names", [])
			var added: Array = []
			var removed: Array = []
			for name in names:
				if opcode == GroupCodec.OPCODE_ADD_FRIEND and not _friends.has(name):
					_friends.append(name)
					added.append(name)
				elif opcode == GroupCodec.OPCODE_REMOVE_FRIEND and _friends.has(name):
					_friends.erase(name)
					removed.append(name)
			friends_changed.emit(_friends.duplicate(true), added, removed)
	elif opcode == GroupCodec.OPCODE_EMOTE_ANIMATION:
		var emote: Dictionary = GroupCodec.decode_emote(payload)
		if bool(emote.get("ok", false)):
			emote_received.emit(emote)
	elif opcode == SkillListCodec.OPCODE_VARIOUS_UPDATE:
		var update: Dictionary = SkillListCodec.decode_various_update(payload)
		if _various_update_log.size() < 128:
			_various_update_log.append({"hex": payload.hex_encode(), "kind": str(update.get("kind", "")), "size": payload.size()})
		if str(update.get("kind", "")) == "skills_page":
			if int(update.get("first_index", 0)) == 0:
				_pending_skills = []
			_pending_skills.append_array(update.get("entries", []) as Array)
			if not bool(update.get("more", false)):
				_skills = _pending_skills.duplicate(true)
				_pending_skills = []
				skills_received.emit(_skills.duplicate(true))
		elif str(update.get("kind", "")) == "crafting_skills":
			_crafting_skills = (update.get("entries", []) as Array).duplicate(true)
			crafting_skills_received.emit(_crafting_skills.duplicate(true))
		elif str(update.get("kind", "")) == "spell_line":
			_pending_spell_lines[int(update.get("line_index", 0))] = update
		elif str(update.get("kind", "")) == "spell_lines_end":
			var keys: Array = _pending_spell_lines.keys()
			keys.sort()
			_spell_lines = []
			for key in keys:
				_spell_lines.append(_pending_spell_lines[key])
			_pending_spell_lines = {}
			spell_lines_received.emit(_spell_lines.duplicate(true))
	elif opcode == AnimationCodec.OPCODE_SPELL_CAST_ANIMATION:
		var cast: Dictionary = AnimationCodec.decode_spell_cast_animation(payload)
		if bool(cast.get("ok", false)):
			animation_packets += 1
			spell_cast_animation_received.emit(cast)
	elif opcode == AnimationCodec.OPCODE_SPELL_EFFECT_ANIMATION:
		var effect: Dictionary = AnimationCodec.decode_spell_effect_animation(payload)
		if bool(effect.get("ok", false)):
			animation_packets += 1
			spell_effect_animation_received.emit(effect)
	# P1-133 — 0x74 AttackMode serveur (PacketLib168.SendAttackMode) : u8 1/0 +
	# trois octets nuls. Le client d origine degaine en mode combat et rengaine
	# hors combat (points Bip01 L/R Belt et Back, game.dll).
	elif opcode == 0x74 and payload.size() >= 1:
		server_attack_mode = payload[0] != 0
		attack_mode_changed.emit(server_attack_mode)
	elif opcode == AnimationCodec.OPCODE_COMBAT_ANIMATION:
		var swing: Dictionary = AnimationCodec.decode_combat_animation(payload)
		if bool(swing.get("ok", false)):
			animation_packets += 1
			combat_animation_received.emit(swing)
	elif opcode == ProgressCodec.OPCODE_POINTS:
		var points: Dictionary = ProgressCodec.decode_points(payload)
		if bool(points.get("ok", false)):
			# P1-109 : le rang de royaume et son titre se deduisent des points.
			points["career"] = _career_of(points)
			_last_points = points
			player_points_received.emit(points)
	elif opcode == ProgressCodec.OPCODE_MAX_SPEED:
		var speed: Dictionary = ProgressCodec.decode_max_speed(payload)
		if bool(speed.get("ok", false)):
			_last_max_speed = speed
			max_speed_received.emit(speed)
	elif opcode == ProgressCodec.OPCODE_DIALOG and QuestSocialCodec.is_quest_window(payload):
		# P1-110 : un 0x81 dont le premier u16 vaut 0x22 / 0x21 est une fenetre de quete.
		var window: Dictionary = QuestSocialCodec.decode_quest_window(payload)
		_log_parity_packet(opcode, payload, window)
		if bool(window.get("ok", false)):
			_last_quest_window = window.duplicate(true)
			quest_window_received.emit(window)
	elif opcode == ProgressCodec.OPCODE_DIALOG:
		var dialog: Dictionary = ProgressCodec.decode_dialog(payload)
		if bool(dialog.get("ok", false)):
			dialog_received.emit(dialog)
	elif opcode == ProgressCodec.OPCODE_PLAYER_DEATH:
		var death: Dictionary = ProgressCodec.decode_player_death(payload)
		if bool(death.get("ok", false)):
			player_died_received.emit(death)
	elif opcode == ProgressCodec.OPCODE_QUEST_ENTRY and payload.size() > 0 and int(payload[0]) == 0:
		# P1-110 : l index 0 est la tache (SendTaskInfo), pas une quete.
		var task: Dictionary = QuestSocialCodec.decode_task_entry(payload)
		_log_parity_packet(opcode, payload, task)
		if bool(task.get("ok", false)):
			_last_task = task.duplicate(true)
			task_received.emit(task)
	elif opcode == ProgressCodec.OPCODE_QUEST_ENTRY:
		var quest: Dictionary = ProgressCodec.decode_quest_entry(payload)
		_log_parity_packet(opcode, payload, quest)
		if bool(quest.get("ok", false)):
			if bool(quest.get("cleared", false)):
				_quests.erase(int(quest.get("index", 0)))
			else:
				_quests[int(quest.get("index", 0))] = quest
			quest_entry_received.emit(quest)
	elif opcode == 0x8D:
		var model_type := {"ok": payload.size() >= 3, "object_id": (int(payload[0]) << 8) | int(payload[1]) if payload.size() >= 2 else -1,
			"model_type": int(payload[2]) if payload.size() >= 3 else -1}
		model_type["stealthed"] = int(model_type["model_type"]) == 3
		_log_parity_packet(opcode, payload, model_type)
		if bool(model_type["ok"]):
			model_type_changed.emit(model_type)
	elif opcode == QuestSocialCodec.OPCODE_MODEL_CHANGE:
		var change: Dictionary = QuestSocialCodec.decode_model_change(payload)
		_log_parity_packet(opcode, payload, change)
		if bool(change.get("ok", false)):
			model_changed.emit(change)
	elif opcode == QuestSocialCodec.OPCODE_FIND_GROUP_UPDATE:
		var list: Dictionary = QuestSocialCodec.decode_find_group_update(payload)
		_log_parity_packet(opcode, payload, list)
		if bool(list.get("ok", false)):
			_last_find_group = list.duplicate(true)
			find_group_received.emit(list)
	elif opcode == MerchantCodec.OPCODE_MERCHANT_WINDOW:
		# P1-114 : une page par paquet ; l ouverture d une boutique en envoie plusieurs.
		var page: Dictionary = MerchantCodec.decode_merchant_window(payload)
		_log_parity_packet(opcode, payload, page)
		if bool(page.get("ok", false)):
			_merchant_pages[int(page.get("page", 0))] = page.duplicate(true)
			_last_merchant_window = page.duplicate(true)
			merchant_window_received.emit(page)
	elif opcode == EconomyCodec.OPCODE_CONSIGNMENT_MONEY:
		# P1-122 : la caisse du marchand de consignation (meme bourse que 0xFA).
		var till: Dictionary = EconomyCodec.decode_consignment_money(payload)
		_log_parity_packet(opcode, payload, till)
		if bool(till.get("ok", false)):
			_last_consignment_money = till.duplicate(true)
			consignment_money_received.emit(till)
	elif opcode == EconomyCodec.OPCODE_MARKET_EXPLORER:
		var market: Dictionary = EconomyCodec.decode_market_explorer(payload)
		_log_parity_packet(opcode, payload, market)
		if bool(market.get("ok", false)):
			_last_market = market.duplicate(true)
			market_explorer_received.emit(market)
	elif opcode == MerchantCodec.OPCODE_MONEY_UPDATE:
		var money: Dictionary = MerchantCodec.decode_money(payload)
		_log_parity_packet(opcode, payload, money)
		if bool(money.get("ok", false)):
			_last_money = money.duplicate(true)
			money_received.emit(money)
	elif opcode == MerchantCodec.OPCODE_ENCUMBERANCE:
		var encumberance: Dictionary = MerchantCodec.decode_encumberance(payload)
		_log_parity_packet(opcode, payload, encumberance)
		if bool(encumberance.get("ok", false)):
			_last_encumberance = encumberance.duplicate(true)
			encumberance_received.emit(encumberance)
	elif opcode == MerchantCodec.OPCODE_TRADE_WINDOW:
		var trade: Dictionary = MerchantCodec.decode_trade_window(payload)
		_log_parity_packet(opcode, payload, trade)
		if bool(trade.get("ok", false)):
			_last_trade_window = trade.duplicate(true)
			trade_window_received.emit(trade)
	elif opcode == QuestSocialCodec.OPCODE_EMBLEM_DIALOGUE:
		_log_parity_packet(opcode, payload, {"ok": true})
		emblem_dialogue_received.emit()
	elif opcode == TravelCodec.OPCODE_CHARACTER_JUMP:
		var jump: Dictionary = TravelCodec.decode_character_jump(payload)
		_log_parity_packet(opcode, payload, jump)
		if bool(jump.get("ok", false)):
			_last_character_jump = jump.duplicate(true)
			_world_model.call("apply_character_jump", jump)
			character_jump_received.emit(jump)
	elif opcode == TravelCodec.OPCODE_DOOR:
		var door: Dictionary = TravelCodec.decode_door_state(payload)
		_log_parity_packet(opcode, payload, door)
		if bool(door.get("ok", false)):
			_door_states[int(door.get("door_id", 0))] = door.duplicate(true)
			door_state_received.emit(door)
	elif opcode == TravelCodec.OPCODE_CONTROLLED_HORSE:
		var horse: Dictionary = TravelCodec.decode_controlled_horse(payload)
		_log_parity_packet(opcode, payload, horse)
		if bool(horse.get("ok", false)):
			if bool(horse.get("own", false)):
				_own_horse = horse.duplicate(true)
			controlled_horse_received.emit(horse)
	elif opcode == TravelCodec.OPCODE_RIDING:
		var riding: Dictionary = TravelCodec.decode_riding(payload)
		_log_parity_packet(opcode, payload, riding)
		if bool(riding.get("ok", false)):
			riding_received.emit(riding)
	elif opcode == TravelCodec.OPCODE_REGION_CHANGED:
		var region: Dictionary = TravelCodec.decode_region_changed(payload)
		_log_parity_packet(opcode, payload, region)
		if bool(region.get("ok", false)):
			_on_region_changed(region)
	elif opcode == 0x15:
		# P1-110 : l equipement d un AUTRE joueur (0x15, decode par P1-94 dans le
		# registre) atteint la poupee de sa scene ; le modele du monde garde le
		# sien, ceci n est qu un relais.
		var equipment: Dictionary = _nearby_decoder.call("decode_equipment_update", payload) as Dictionary
		if bool(equipment.get("ok", false)):
			equipment_received.emit(int(equipment.get("object_id", 0)), equipment)
	elif opcode == 0x89:
		# PacketLib168.SendPlayerRevive : u16 object id du ressuscite, u16 0.
		player_revived.emit(((int(payload[0]) << 8) | int(payload[1])) if payload.size() >= 2 else -1)
	elif opcode == 0xA4:
		# PacketLib168.SendPlayerQuit : u8 totalOut, u8 niveau.
		player_quit_received.emit(payload.size() > 0 and int(payload[0]) != 0, int(payload[1]) if payload.size() > 1 else 0)
	elif opcode == AnimationCodec.OPCODE_INTERRUPT_SPELL_CAST:
		var interrupt: Dictionary = AnimationCodec.decode_interrupt_spell_cast(payload)
		if bool(interrupt.get("ok", false)):
			animation_packets += 1
			spell_cast_interrupted.emit(int(interrupt.get("living_id", 0)))


var _codec_peek: RefCounted = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd").new()


## 2026-09-29 : les derniers opcodes recus (sondes), le journal de parite
## etant plafonne a PARITY_LOG_LIMIT des l entree monde.
var _recent_opcodes: Array = []
var _received_count := 0
var _recent_packets: Array = []


func recent_server_opcodes() -> Dictionary:
	return {"count": _received_count, "recent": _recent_opcodes.duplicate(), "hex": _recent_packets.duplicate()}


func _on_server_packet_received(packet: PackedByteArray) -> void:
	_received_count += 1
	if packet.size() >= 3:
		_recent_opcodes.append("0x%02X" % int(packet[2]))
		_recent_packets.append(packet.hex_encode())
		if _recent_packets.size() > 64:
			_recent_packets.pop_front()
		if _recent_opcodes.size() > 256:
			_recent_opcodes.pop_front()
	_dispatch_status_and_messages(packet)
	var parsed: Dictionary = _codec_peek.call("parse_server_packet", packet) as Dictionary
	if bool(parsed.get("ok", false)) and int(parsed.get("opcode", -1)) == 0xD0:
		_session.call("request_los_response", parsed.get("payload", PackedByteArray()) as PackedByteArray)
	# Un paquet d'entite que le decodeur ne sait pas lire n'est PAS une raison
	# de tuer la session : les sondes de juillet les comptaient et continuaient.
	# Les journaux live de juillet et du 07/09 montrent 0x91, 0xD6, 0x4C, 0x92,
	# 0x7E, 0x5C, 0xF7, 0x13... entre les paquets connus.
	var world_result: Dictionary = _world_model.call("ingest_server_packet", packet) as Dictionary
	if not bool(world_result.get("ok", false)):
		_world_decode_failures += 1
		_last_world_decode_error = str(world_result.get("error", ""))
	var auth_result: Dictionary = _authentication.call("accept_server_packet", packet) as Dictionary
	if not bool(auth_result.get("ok", false)):
		connection_failed.emit(str(auth_result.get("error", "authentication_packet_failed")))
		return
	var entry_result: Dictionary = _world_entry.call("accept_server_packet", packet) as Dictionary
	if not bool(entry_result.get("ok", false)):
		_session.call("fail", str(entry_result.get("error", "world_entry_packet_failed")))
		connection_failed.emit(str(entry_result.get("error", "world_entry_packet_failed")))
		return
	var result: Dictionary = _session.call("accept_server_packet", packet) as Dictionary
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "server_packet_failed")))


func _on_outbound_packet_ready(packet: PackedByteArray, _purpose: String) -> void:
	var result: Dictionary = _transport.call("queue_packet", packet) as Dictionary
	if not bool(result.get("ok", false)):
		_session.call("fail", str(result.get("error", "outbound_queue_failed")))


func _on_session_state_changed(_previous: String, current: String) -> void:
	if current == SessionScript.PLAYING:
		server_playing_received.emit()
	else:
		state_changed.emit(current)


func _on_inventory_changed(value: Dictionary) -> void:
	inventory_changed.emit(value)


## P1-95 : le sac courant, pour le rejouer quand le monde se monte APRES le 0x02.
func inventory_snapshot() -> Dictionary:
	return ((_session.call("snapshot") as Dictionary).get("inventory", {}) as Dictionary).duplicate(true)


## Le dernier CharacterOverview recu est ecrit sur le disque : c'est la source
## du rendu fidele des personnages serveur (equipement, race, sexe, visage),
## consommee par tools/p1_73_export_online_characters.gd via le Character Lab.
## Aucune donnee de compte : noms, metiers, modeles d'equipement, apparence.
const OVERVIEW_DUMP_PATH := "res://reports/online/last_character_overview.json"


func _on_character_overview_received(value: Dictionary) -> void:
	_dump_overview(value)
	character_overview_received.emit(value)


func _dump_overview(value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OVERVIEW_DUMP_PATH.get_base_dir()))
	var file := FileAccess.open(OVERVIEW_DUMP_PATH, FileAccess.WRITE)
	if file == null:
		return
	var dump := {"received_utc": Time.get_datetime_string_from_system(true), "realm": int(_profile_public.get("realm", 0)),
		"characters": value.get("characters", [])}
	file.store_string(JSON.stringify(dump, "	"))
	file.close()


func _on_world_ready() -> void:
	_session.call("set_next_sequence", int(_world_entry.call("next_sequence_value")))


func _on_player_position_model(value: Dictionary) -> void:
	_session.call("set_authoritative_position", value)
	player_position_changed.emit(value)


func _on_authentication_ready(_session_id: int, _overview: Dictionary) -> void:
	if _pending_character.is_empty():
		return
	var character := _pending_character.duplicate(true)
	_pending_character = {}
	var result := _select_now(character)
	if not bool(result.get("ok", false)):
		connection_failed.emit(str(result.get("error", "deferred_character_select_failed")))


func _on_authentication_failed(reason: String) -> void:
	_connection_profile.clear()
	_session.call("fail", reason)
	connection_failed.emit(reason)


func _on_transport_error(reason: String) -> void:
	_connection_profile.clear()
	_session.call("fail", reason)
	connection_failed.emit(reason)


func _on_transport_disconnected(reason: String) -> void:
	_connection_profile.clear()
	if str((_session.call("snapshot") as Dictionary).get("state", "")) != SessionScript.FAILED:
		_session.call("fail", reason)
		if not _restarting and reason != "player_quit":
			connection_failed.emit("transport_disconnected: " + reason)


## ═══════════════════════════════════════════════════════════════════════════
## P1-122 — l economie : artisanat (0xED), consignation (0x1A, 0x1C, 0x1E),
## marche (0x11 -> 0x1F), coffres (0x02 aux logements 110..249).
## ═══════════════════════════════════════════════════════════════════════════
signal consignment_money_received(money: Dictionary)
signal market_explorer_received(market: Dictionary)
signal external_inventory_changed(window: Dictionary)
var _last_consignment_money: Dictionary = {}
var _last_market: Dictionary = {}
var crafts_sent := 0
var market_searches_sent := 0
var market_prices_sent := 0


func last_consignment_money() -> Dictionary:
	return _last_consignment_money.duplicate(true)


func last_market() -> Dictionary:
	return _last_market.duplicate(true)


func external_inventory() -> Dictionary:
	var controller: RefCounted = _session.get("_inventory") as RefCounted if _session != null else null
	return controller.call("external_snapshot") as Dictionary if controller != null else {}


func send_craft(recipe_id: int) -> Dictionary:
	var result: Dictionary = _session.call("request_craft", recipe_id) as Dictionary
	if bool(result.get("ok", false)):
		crafts_sent += 1
	return result


func send_set_market_price(relative_slot: int, price: int) -> Dictionary:
	var result: Dictionary = _session.call("request_set_market_price", relative_slot, price) as Dictionary
	if bool(result.get("ok", false)):
		market_prices_sent += 1
	return result


func send_withdraw_merchant_money() -> Dictionary:
	return _session.call("request_withdraw_merchant_money") as Dictionary


func send_market_search(search: Dictionary) -> Dictionary:
	var result: Dictionary = _session.call("request_market_search", search) as Dictionary
	if bool(result.get("ok", false)):
		market_searches_sent += 1
	return result
