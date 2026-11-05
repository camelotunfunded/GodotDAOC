extends Node
class_name DaocServerAnimationRuntime

## P1-76 — le serveur NOMME l'animation, ce noeud la joue.
##
## En ligne, l'arbitre miroir refuse tout arbitrage : aucun `combat_event`
## local ne part, donc `DaocCombatClient._animate_event` ne joue jamais rien.
## Ce que le client d'origine joue vient de quatre paquets, décodés par
## `DaocOpenDaocAnimationCodec` et émis par `DaocOnlineRuntime` :
##
##   0x72  incantation : geste `cast_<geste>_start` puis `_mid` en boucle
##         pendant `casting_time`, le geste étant lu dans spells.csv par
##         `DaocSpellVisualCatalogue` ; effets « lanceur » posés sur le joueur ;
##   0x1B  résolution : `cast_<geste>_end`, effet « cible » posé sur la cible
##         (ou « résistance » si le serveur dit l'échec) ;
##   0x73  interruption : retour à la machine idle/marche ;
##   0xBC  coup de mêlée : attaque si le joueur frappe, parade / blocage /
##         esquive / flinch si c'est lui qui encaisse, d'après le résultat.
##
## Les PNJ n'ont que leur clip `death` (exporté par le Lab) : rien ne leur est
## substitué, comme pour l'arbitre local.
##
## VFX : `DaocSpellVfxPlaceholder`, des particules Godot colorées par famille
## d'effet, posées sur le bon noeud et pour la bonne durée de speffects.csv.
## C'est un REMPLAÇANT ASSUMÉ : les NIF de effects/ sont des
## NiRotatingParticles que le lecteur NIF ne convertit pas encore. Le jour où
## le Lab les convertira, seul `DaocSpellVfxPlaceholder.spawn` change.

const CatalogueScript = preload("res://src/daoc/gameplay/effects/DaocSpellVisualCatalogue.gd")
const VfxScript = preload("res://src/daoc/gameplay/effects/DaocSpellVfxPlaceholder.gd")
const EffectScenesScript = preload("res://src/daoc/gameplay/effects/DaocSpellEffectScenes.gd")
const StyleCatalogueScript = preload("res://src/daoc/gameplay/effects/DaocStyleVisualCatalogue.gd")
const MeleeVfxScript = preload("res://src/daoc/gameplay/effects/DaocMeleeHitVfx.gd")
## P1-133 : styles.csv / canims.csv (clip + couleur du style du 0xBC).
var style_catalogue: RefCounted = null

const DEFENSE_CLIP_BY_RESULT: Dictionary = {
	"Parried": ["parry_high", "parry_low"],
	"Evaded": ["evade"],
	"Blocked": ["block_high", "block_low"],
}
const ATTACK_CLIPS := ["attack_med", "attack_high", "attack_low"]
## P1-130 : famille de l arme EN MAIN du joueur (DaocWeaponAnimationFamily),
## posee par le monde a chaque 0x02. "" = clips generiques.
var weapon_family := ""
## Marge après `casting_time` avant d'abandonner une incantation dont ni la
## résolution (0x1B) ni l'interruption (0x73) ne sont arrivées.
const CAST_GRACE_SEC := 1.5

var combat_client: Node = null
var server: Node = null
var catalogue: RefCounted = null
var effect_scenes: RefCounted = null
var world_scale: float = 1.0
var vfx_enabled: bool = true
var log_to_console: bool = false

var _player_object_id: int = -1
var _swing_index := 0
var _cast: Dictionary = {}
var _counts := {"cast": 0, "effect": 0, "swing": 0, "interrupt": 0, "vfx": 0}
var _last: Dictionary = {}


func setup(p_combat_client: Node, p_server: Node, player_object_id: int, options: Dictionary = {}) -> void:
	combat_client = p_combat_client
	server = p_server
	_player_object_id = player_object_id
	world_scale = float(options.get("world_scale", world_scale))
	vfx_enabled = bool(options.get("vfx_enabled", vfx_enabled))
	log_to_console = bool(options.get("log_to_console", log_to_console))
	var client_root := str(options.get("client_root", ""))
	if client_root != "":
		catalogue = CatalogueScript.new()
		if not catalogue.load_tables(client_root):
			push_warning("P1-76: tables de sorts non chargées : %s" % str(catalogue.error))
		effect_scenes = EffectScenesScript.new()
		effect_scenes.setup(client_root)
		style_catalogue = StyleCatalogueScript.new()
		if not style_catalogue.load_tables(client_root):
			push_warning("P1-133: styles.csv/canims.csv non chargés : %s" % str(style_catalogue.error))


func bind(online_runtime: Node) -> Dictionary:
	if online_runtime == null:
		return {"ok": false, "reason": "runtime absent"}
	var bound := 0
	for pair in [["spell_cast_animation_received", "_on_spell_cast"],
			["spell_effect_animation_received", "_on_spell_effect"],
			["combat_animation_received", "_on_combat_animation"],
			["spell_cast_interrupted", "_on_spell_interrupted"]]:
		if not online_runtime.has_signal(str(pair[0])):
			continue
		var receiver := Callable(self, str(pair[1]))
		if not online_runtime.is_connected(str(pair[0]), receiver):
			online_runtime.connect(str(pair[0]), receiver)
		bound += 1
	return {"ok": bound == 4, "bound": bound}


func _process(_delta: float) -> void:
	if _cast.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now >= int(_cast.get("deadline_msec", 0)):
		_finish_cast(false)
		return
	# Le milieu prend la main UNE FOIS, a la fin du debut, et boucle tout seul
	# (play_looping) : le relancer a chaque cycle repartait de la premiere image.
	var visual: Node = _player_visual()
	if visual == null:
		return
	var mid := str(_cast.get("mid", ""))
	if mid != "" and not bool(_cast.get("mid_started", false)) and now >= int(_cast.get("start_end_msec", 0)):
		_cast["mid_started"] = true
		if visual.has_method("play_looping"):
			visual.call("play_looping", mid)
		else:
			visual.call("play_one_shot", mid)


# --------------------------------------------------------------------------
# Paquets
# --------------------------------------------------------------------------

func _on_spell_cast(cast: Dictionary) -> void:
	_counts["cast"] += 1
	_last["cast"] = cast
	var caster := int(cast.get("caster_id", -1))
	var visual_info := _resolve_visual(int(cast.get("client_effect", 0)))
	if caster == _player_object_id:
		_begin_player_cast(visual_info, float(cast.get("casting_time_sec", 0.0)))
	var node: Node3D = _node_for(caster)
	if node != null:
		for role in ["caster_1a", "caster_1b", "caster_2", "caster_3"]:
			_spawn_vfx(node, visual_info, role)
	_log("0x72 lanceur %d effet %d (%s) geste %s %.1f s" % [caster, int(cast.get("client_effect", 0)),
		str(visual_info.get("name", "?")), str(visual_info.get("gesture", "?")), float(cast.get("casting_time_sec", 0.0))])


func _on_spell_effect(effect: Dictionary) -> void:
	_counts["effect"] += 1
	_last["effect"] = effect
	var caster := int(effect.get("caster_id", -1))
	var target := int(effect.get("target_id", -1))
	var visual_info := _resolve_visual(int(effect.get("client_effect", 0)))
	if caster == _player_object_id and not _cast.is_empty():
		_finish_cast(true)
	var target_node: Node3D = _node_for(target)
	if target_node != null:
		_spawn_vfx(target_node, visual_info, "target" if bool(effect.get("success", true)) else "resist")
	_log("0x1B lanceur %d cible %d effet %d (%s) %s" % [caster, target, int(effect.get("client_effect", 0)),
		str(visual_info.get("name", "?")), "réussi" if bool(effect.get("success", true)) else "résisté"])


func _on_spell_interrupted(living_id: int) -> void:
	_counts["interrupt"] += 1
	_last["interrupt"] = living_id
	if living_id == _player_object_id and not _cast.is_empty():
		_cast = {}
		var visual: Node = _player_visual()
		if visual != null and visual.has_method("clear_persistent_pose"):
			visual.call("clear_persistent_pose")
	_log("0x73 interruption de %d" % living_id)


func _on_combat_animation(swing: Dictionary) -> void:
	_counts["swing"] += 1
	_last["swing"] = swing
	var attacker := int(swing.get("attacker_id", -1))
	var defender := int(swing.get("defender_id", -1))
	var result := str(swing.get("result", ""))
	# P1-133 — le champ « style » du 0xBC est Style.Icon = ID de styles.csv
	# (StyleProcessor.cs). Son clip canims passe AVANT les coups génériques.
	var style_info := _style_info(int(swing.get("style", 0)))
	var style_clip := str(style_info.get("clip", ""))
	var style_color: Variant = style_info.get("color") if bool(style_info.get("ok", false)) else null
	if attacker == _player_object_id:
		# Le coup part même quand il rate : c'est la défense d'en face qui
		# l'annule, pas l'absence de geste.
		_swing_index += 1
		var clips := DaocWeaponAnimationFamily.attack_clips(weapon_family, _swing_index)
		if style_clip != "":
			clips.push_front(style_clip)
		_play_player(clips)
	_spawn_melee_vfx(attacker, defender, result, style_color)
	if defender == _player_object_id:
		if DEFENSE_CLIP_BY_RESULT.has(result):
			_play_player(DaocWeaponAnimationFamily.defense_clips(weapon_family, result))
		elif bool(swing.get("hit", false)):
			_play_player(["flinch"])
	# P1-81 — les PNJ aussi, quand leur scene porte les clips de combat du Lab
	# (canims.csv de LEUR jeu d'animations) : coup porte, defense ou flinch.
	if attacker != _player_object_id:
		_swing_index += 1
		var npc_clips := _attack_candidates()
		if style_clip != "":
			npc_clips.push_front(style_clip)
		_play_npc(attacker, npc_clips)
	if defender != _player_object_id:
		if DEFENSE_CLIP_BY_RESULT.has(result):
			_play_npc(defender, DEFENSE_CLIP_BY_RESULT[result] as Array)
		elif bool(swing.get("hit", false)) and int(swing.get("target_health_percent", 100)) > 0:
			_play_npc(defender, ["flinch"])
	_log("0xBC %d -> %d %s (%d %%)" % [attacker, defender, result, int(swing.get("target_health_percent", -1))])


# --------------------------------------------------------------------------
# Incantation du joueur
# --------------------------------------------------------------------------

func _begin_player_cast(visual_info: Dictionary, casting_time_sec: float) -> void:
	var gesture := str(visual_info.get("gesture", ""))
	if gesture == "":
		gesture = "default"
	var visual: Node = _player_visual()
	var start := CatalogueScript.cast_clip_name(gesture, "start")
	var mid := CatalogueScript.cast_clip_name(gesture, "mid")
	var end := CatalogueScript.cast_clip_name(gesture, "end")
	var now := Time.get_ticks_msec()
	var start_end := now
	if visual != null and bool(visual.call("has_clip", start)):
		visual.call("play_one_shot", start)
		var player: AnimationPlayer = visual.get("walk_animation_player") as AnimationPlayer
		if player != null and player.has_animation(start):
			start_end = now + int(player.get_animation(start).length * 1000.0)
	_cast = {
		"gesture": gesture,
		"mid": mid if visual != null and bool(visual.call("has_clip", mid)) else "",
		"end": end,
		"start_end_msec": start_end,
		"deadline_msec": now + int((casting_time_sec + CAST_GRACE_SEC) * 1000.0),
	}


func _finish_cast(resolved: bool) -> void:
	var end := str(_cast.get("end", ""))
	_cast = {}
	var visual: Node = _player_visual()
	if visual == null:
		return
	if resolved and bool(visual.call("has_clip", end)):
		visual.call("play_one_shot", end)
	elif visual.has_method("clear_persistent_pose"):
		visual.call("clear_persistent_pose")


# --------------------------------------------------------------------------
# Outils
# --------------------------------------------------------------------------

func _resolve_visual(client_effect: int) -> Dictionary:
	if catalogue == null or not bool(catalogue.get("loaded")):
		return {"ok": false, "gesture": "", "effects": {}, "name": ""}
	return catalogue.resolve_client_effect(client_effect)


func _spawn_vfx(node: Node3D, visual_info: Dictionary, role: String) -> void:
	if not vfx_enabled:
		return
	var effects: Dictionary = visual_info.get("effects", {})
	if not effects.has(role):
		return
	if VfxScript.spawn(node, effects[role] as Dictionary, world_scale, effect_scenes) != null:
		_counts["vfx"] += 1


func _node_for(object_id: int) -> Node3D:
	if object_id == _player_object_id and combat_client != null:
		return combat_client.get("player") as Node3D
	if server != null and server.has_method("get_node_for"):
		return server.call("get_node_for", object_id) as Node3D
	return null


func _player_visual() -> Node:
	if combat_client == null or not combat_client.has_method("_resolve_player_visual"):
		return null
	return combat_client.call("_resolve_player_visual") as Node


## Un geste PNJ : premier clip present, puis retour au clip par defaut de la
## scene quand il finit (les PNJ n'ont pas de machine d'etats). Une creature
## en train de mourir n'est jamais interrompue. Les PNJ sans clips de combat
## (scenes anterieures a P1-81) ne bougent pas : rien n'est substitue.
## Variante d'attaque du tour, puis les autres en repli : une scene qui n'a
## qu'un clip d'attaque frappe quand meme.
func _attack_candidates() -> Array:
	var out: Array = []
	for i in ATTACK_CLIPS.size():
		out.append(str(ATTACK_CLIPS[(_swing_index + i) % ATTACK_CLIPS.size()]))
	return out


func _play_npc(object_id: int, candidates: Array) -> bool:
	var node: Node3D = _node_for(object_id)
	if node == null:
		return false
	var player := _find_animation_player(node)
	if player == null or player.current_animation == "death":
		return false
	for clip_value in candidates:
		var clip := str(clip_value)
		if not player.has_animation(clip):
			continue
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_NONE
		player.stop()
		player.play(clip)
		if not player.has_meta("daoc_gesture_hook"):
			player.set_meta("daoc_gesture_hook", true)
			player.animation_finished.connect(_on_npc_gesture_finished.bind(player, node))
		_counts["npc_gestures"] = int(_counts.get("npc_gestures", 0)) + 1
		return true
	return false


func _on_npc_gesture_finished(finished: StringName, player: AnimationPlayer, node: Node3D) -> void:
	if not is_instance_valid(player) or str(finished) == "death":
		return
	var idle := str(node.get_meta("daoc_default_animation", "idle")) if is_instance_valid(node) else "idle"
	if idle == "" or not player.has_animation(idle):
		return
	player.play(idle)


## L'AnimationPlayer du PERSONNAGE : les effets de sort poses sous le meme
## noeud portent le leur (« EffectAnimation »), a ne jamais confondre.
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node.has_meta("daoc_effect_nif") or node.has_meta("daoc_vfx_placeholder"):
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _style_info(style_id: int) -> Dictionary:
	if style_catalogue == null or style_id <= 0 or StyleCatalogueScript.is_special(style_id):
		return {"ok": false}
	return style_catalogue.resolve(style_id)


## P1-133 : sillage sur l'arme de l'attaquant + impact selon le résultat.
func _spawn_melee_vfx(attacker: int, defender: int, result: String, style_color: Variant) -> void:
	if not vfx_enabled:
		return
	var attacker_node := _node_for(attacker)
	var defender_node := _node_for(defender)
	if attacker_node != null and result != "Fumbled":
		if MeleeVfxScript.spawn_trail(attacker_node, style_color, 0.45, world_scale) != null:
			_counts["melee_vfx"] = int(_counts.get("melee_vfx", 0)) + 1
	if defender_node != null:
		if MeleeVfxScript.spawn_impact(defender_node, attacker_node, result, style_color, world_scale) != null:
			_counts["melee_vfx"] = int(_counts.get("melee_vfx", 0)) + 1


func _play_player(candidates: Array) -> bool:
	if combat_client == null or not combat_client.has_method("_play_first_available"):
		return false
	return bool(combat_client.call("_play_first_available", candidates))


func _log(text: String) -> void:
	if log_to_console:
		print("SERVER_ANIM %s" % text)


func get_debug_snapshot() -> Dictionary:
	return {
		"player_object_id": _player_object_id,
		"catalogue_loaded": catalogue != null and bool(catalogue.get("loaded")),
		"effect_scenes": effect_scenes.report() if effect_scenes != null else {},
		"counts": _counts.duplicate(),
		"casting": not _cast.is_empty(),
		"cast": _cast.duplicate(),
		"last": _last.duplicate(true),
	}
