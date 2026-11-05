extends Node3D
class_name DaocPlayerVisualRuntime

const DaocVisualFeetResolverScript = preload("res://src/daoc/player/DaocVisualFeetResolver.gd")
const DaocPlayerTextureApplicatorScript = preload("res://src/daoc/player/DaocPlayerTextureApplicator.gd")
const AnimationPresentation = preload("res://src/daoc/player/DaocAnimationPresentation.gd")

const CHECKPOINT: String = "P1_18M_PLAYER_VISUAL_MESHY_SWAP"
const DEFAULT_WALK_SCENE_PATH: String = "res://assets/daoc/player/meshy/Meshy_AI_T_Pose_Character_Mode_biped_Animation_Walking_withSkin.glb"
const DEFAULT_RUN_SCENE_PATH: String = "res://assets/daoc/player/meshy/Meshy_AI_T_Pose_Character_Mode_biped_Animation_Running_withSkin.glb"
const WALK_NODE_NAME: String = "MeshyWalkVisual"
const RUN_NODE_NAME: String = "MeshyRunVisual"

## Clips qui representent un ETAT qui dure. Tout le reste est un geste : il se
## joue une fois et rend la main a la machine d'etats.
const CONTINUOUS_CLIP_NAMES := ["idle", "walk", "run", "sprint", "combat_idle"]
## Nom du clip de garde exporte par le Character Lab depuis canims.csv.
const COMBAT_IDLE_CLIP_NAME: String = "combat_idle"
## 2026-09-19 — Sprint. anims.csv n'a AUCUNE colonne de sprint : le client
## d'origine joue la course plus vite. Ici la cadence de la course suit la
## vitesse REELLE du moteur rapportee a l'allure de course calibree
## (`local_run_speed_raw`, 1500) — 1,18 hors ligne par la touche, 162/125 en
## ligne quand 0xB6 monte apres un Sprint, et 100/125 en combat. Si une scene
## exporte un jour un clip `sprint`, il remplace la course acceleree.
const SPRINT_CLIP_NAME: String = "sprint"
## Au-dela de ce rapport de vitesse, la course est un sprint.
const SPRINT_PACE_THRESHOLD: float = 1.08
const RUN_PACE_MIN: float = 0.75
const RUN_PACE_MAX: float = 1.75

var player_body: Node = null
var walk_scene_path: String = DEFAULT_WALK_SCENE_PATH
var run_scene_path: String = DEFAULT_RUN_SCENE_PATH
var visual_scale: float = 60.0
var size_choice: String = "average"
var size_model_bits: int = 0x1000
var size_visual_factor: float = 1.0
var ground_offset: float = 0.0
var yaw_degrees: float = 90.0
var walk_threshold: float = 0.05
var run_threshold: float = 4.0
## Seuils en unites DAoC brutes, utilises des que le corps est un moteur DAoC.
## Reperes du moteur : course 1500, marche 0,45 x 1500 = 675. Le seuil de course
## se place donc entre les deux.
var walk_threshold_raw: float = 1.0
var run_threshold_raw: float = 900.0
var force_state: String = ""
var idle_mode: String = "walk_loop"
var requested_idle_animation_name: String = ""
var requested_walk_animation_name: String = ""
var requested_run_animation_name: String = ""
var feet_alignment_enabled: bool = false
var feet_alignment_mode: String = "auto"
var feet_alignment_offset: float = 0.0
var feet_alignment_max_step: float = 128.0
var feet_alignment_source: String = "none"
var textures_enabled: bool = false
var surface_textures: Dictionary = {}
var texture_status: Dictionary = {}
var animation_polish_enabled: bool = true

var walk_node: Node3D = null
var run_node: Node3D = null
var walk_animation_player: AnimationPlayer = null
var run_animation_player: AnimationPlayer = null
var idle_animation_name: String = ""
var walk_animation_name: String = ""
var run_animation_name: String = ""
var current_state: String = "uninitialized"
var install_error: String = ""

var _last_global_position: Vector3 = Vector3.ZERO
var _last_position_valid: bool = false

## Posture de garde : l'arret devient `combat_idle` au lieu de `idle`. Pilotee
## par le serveur local, jamais deduite ici.
var combat_stance: bool = false
var combat_idle_animation_name: String = ""
## Rapport vitesse reelle / allure de course, 1,0 = course calibree.
var locomotion_pace: float = 1.0
var sprinting: bool = false
var sprint_animation_name: String = ""
var _one_shot_name: String = ""
var _one_shot_end_msec: int = 0
var _persistent_pose_name: String = ""


func configure(options: Dictionary = {}) -> void:
	walk_scene_path = str(options.get("walk_scene_path", walk_scene_path))
	run_scene_path = str(options.get("run_scene_path", run_scene_path))
	visual_scale = maxf(0.0001, float(options.get("visual_scale", visual_scale)))
	size_choice = str(options.get("size_choice", size_choice)).strip_edges().to_lower()
	size_model_bits = int(options.get("size_model_bits", size_model_bits))
	size_visual_factor = float(options.get("size_visual_factor", size_visual_factor))
	ground_offset = float(options.get("ground_offset", ground_offset))
	yaw_degrees = float(options.get("yaw_degrees", yaw_degrees))
	walk_threshold = maxf(0.0, float(options.get("walk_threshold", walk_threshold)))
	run_threshold = maxf(walk_threshold, float(options.get("run_threshold", run_threshold)))
	walk_threshold_raw = maxf(0.0, float(options.get("walk_threshold_raw", walk_threshold_raw)))
	run_threshold_raw = maxf(walk_threshold_raw, float(options.get("run_threshold_raw", run_threshold_raw)))
	var requested_force_state := str(options.get("force_state", force_state)).strip_edges().to_lower()
	force_state = "" if requested_force_state == "auto" else requested_force_state
	idle_mode = str(options.get("idle_mode", idle_mode)).strip_edges().to_lower()
	if idle_mode != "walk_loop":
		idle_mode = "freeze"
	requested_idle_animation_name = str(options.get("idle_animation_name", requested_idle_animation_name)).strip_edges()
	requested_walk_animation_name = str(options.get("walk_animation_name", requested_walk_animation_name)).strip_edges()
	requested_run_animation_name = str(options.get("run_animation_name", requested_run_animation_name)).strip_edges()
	feet_alignment_enabled = bool(options.get("feet_alignment_enabled", feet_alignment_enabled))
	feet_alignment_mode = str(options.get("feet_alignment_mode", feet_alignment_mode)).strip_edges().to_lower()
	if feet_alignment_mode != "aabb" and feet_alignment_mode != "skeleton":
		feet_alignment_mode = "auto"
	feet_alignment_offset = float(options.get("feet_alignment_offset", feet_alignment_offset))
	feet_alignment_max_step = maxf(0.0, float(options.get("feet_alignment_max_step", feet_alignment_max_step)))
	textures_enabled = bool(options.get("textures_enabled", textures_enabled))
	animation_polish_enabled = bool(options.get("animation_polish_enabled", AnimationPresentation.load_enabled(true)))
	if options.has("surface_textures") and options.get("surface_textures") is Dictionary:
		surface_textures = (options.get("surface_textures") as Dictionary).duplicate(true)
	if options.has("player_body") and options.get("player_body") is Node:
		player_body = options.get("player_body") as Node
	_apply_visual_transform()


func install_visuals(options: Dictionary = {}) -> Dictionary:
	if not options.is_empty():
		configure(options)
	install_error = ""
	_clear_visual_children()
	if not FileAccess.file_exists(walk_scene_path):
		install_error = "missing_walk_glb"
		return build_status_report()
	if not FileAccess.file_exists(run_scene_path):
		install_error = "missing_run_glb"
		return build_status_report()
	walk_node = _instantiate_visual_scene(walk_scene_path, WALK_NODE_NAME)
	if walk_node == null:
		install_error = "cannot_instantiate_walk_glb"
		return build_status_report()
	run_node = _instantiate_visual_scene(run_scene_path, RUN_NODE_NAME)
	if run_node == null:
		install_error = "cannot_instantiate_run_glb"
		return build_status_report()
	texture_status = _apply_player_textures()
	if textures_enabled and not bool(texture_status.get("ok", false)):
		install_error = "player_textures_incomplete"
		return build_status_report()
	add_child(walk_node)
	add_child(run_node)
	walk_animation_player = _find_animation_player(walk_node)
	run_animation_player = _find_animation_player(run_node)
	AnimationPresentation.apply_to_player(walk_animation_player, animation_polish_enabled)
	AnimationPresentation.apply_to_player(run_animation_player, animation_polish_enabled)
	idle_animation_name = _preferred_animation_name(walk_animation_player, requested_idle_animation_name)
	# Verification STRICTE : `_preferred_animation_name` retombe sur le premier
	# clip venu, ce qui donnerait une garde en jouant une marche. Ici on veut
	# savoir si le clip existe, pas obtenir un remplacant.
	combat_idle_animation_name = COMBAT_IDLE_CLIP_NAME if (walk_animation_player != null and walk_animation_player.has_animation(COMBAT_IDLE_CLIP_NAME)) else ""
	walk_animation_name = _preferred_animation_name(walk_animation_player, requested_walk_animation_name)
	run_animation_name = _preferred_animation_name(run_animation_player, requested_run_animation_name)
	sprint_animation_name = SPRINT_CLIP_NAME if (run_animation_player != null and run_animation_player.has_animation(SPRINT_CLIP_NAME)) else ""
	locomotion_pace = 1.0
	sprinting = false
	_set_animation_loops(walk_animation_player)
	_set_animation_loops(run_animation_player)
	_last_position_valid = false
	set_process(true)
	var initial_state := force_state if (force_state == "idle" or force_state == "walk" or force_state == "run") else "idle"
	_set_state(initial_state, true)
	return build_status_report()


func build_status_report() -> Dictionary:
	return {
		"checkpoint": CHECKPOINT,
		"ok": install_error == "" and walk_node != null and run_node != null,
		"install_error": install_error,
		"walk_scene_path": walk_scene_path,
		"run_scene_path": run_scene_path,
		"walk_glb_exists": FileAccess.file_exists(walk_scene_path),
		"run_glb_exists": FileAccess.file_exists(run_scene_path),
		"walk_visual_instanced": walk_node != null,
		"run_visual_instanced": run_node != null,
		"walk_animation_player_found": walk_animation_player != null,
		"run_animation_player_found": run_animation_player != null,
		"idle_animation_name": idle_animation_name,
		"walk_animation_name": walk_animation_name,
		"run_animation_name": run_animation_name,
		"combat_idle_animation_name": combat_idle_animation_name,
		"combat_stance": combat_stance,
		"sprint_animation_name": sprint_animation_name,
		"sprint_model": "dedicated_clip" if sprint_animation_name != "" else "run_clip_paced_by_motor_speed",
		"locomotion_pace": locomotion_pace,
		"sprinting": sprinting,
		"one_shot_playing": _one_shot_name,
		"available_clips": (walk_animation_player.get_animation_list() if walk_animation_player != null else PackedStringArray()),
		"current_state": current_state,
		"force_state": force_state if force_state != "" else "auto",
		"idle_mode": idle_mode,
		"visual_scale": visual_scale,
		"size_choice": size_choice,
		"size_model_bits": size_model_bits,
		"size_visual_factor": size_visual_factor,
		"ground_offset": ground_offset,
		"yaw_degrees": yaw_degrees,
		"feet_alignment_enabled": feet_alignment_enabled,
		"feet_alignment_mode": feet_alignment_mode,
		"feet_alignment_source": feet_alignment_source,
		"feet_alignment_offset": feet_alignment_offset,
		"feet_alignment_max_step": feet_alignment_max_step,
		"textures_enabled": textures_enabled,
		"texture_status": texture_status,
		"texture_surface_count": int(texture_status.get("unique_surfaces", 0)),
		"texture_material_applications": int(texture_status.get("material_applications", 0)),
		"collision_replaced": false,
		"character_body_replaced": false,
		"network_authority_changed": false,
		"server_authority_unchanged": true,
		"root_motion_enabled": false,
	}


func _apply_player_textures() -> Dictionary:
	if not textures_enabled:
		return {"checkpoint": "PLAYER_TEXTURES_H61", "ok": true, "enabled": false, "unique_surfaces": 0, "material_applications": 0}
	var walk_report := DaocPlayerTextureApplicatorScript.apply(walk_node, surface_textures) as Dictionary
	var run_report := DaocPlayerTextureApplicatorScript.apply(run_node, surface_textures) as Dictionary
	return {
		"checkpoint": "PLAYER_TEXTURES_H61",
		"ok": bool(walk_report.get("ok", false)) and bool(run_report.get("ok", false)),
		"enabled": true,
		"unique_surfaces": surface_textures.size(),
		"material_applications": int(walk_report.get("material_applications", 0)) + int(run_report.get("material_applications", 0)),
		"walk": walk_report,
		"run": run_report,
	}


func _ready() -> void:
	set_process(true)
	if player_body == null:
		player_body = get_parent()
	_apply_visual_transform()
	if walk_node == null and run_node == null:
		install_visuals()


func _process(delta: float) -> void:
	if player_body == null:
		player_body = get_parent()
	# Un geste en cours garde la main : sans cela la machine d'etats, qui ne
	# regarde que la vitesse, couperait un coup d'epee des la premiere frame.
	# P1-87 — assis : se deplacer releve, comme dans le client d'origine.
	if sitting and _read_motor_speed_raw() >= walk_threshold_raw:
		stand()
	if _one_shot_name != "":
		if Time.get_ticks_msec() < _one_shot_end_msec:
			_apply_runtime_feet_alignment()
			return
		if _queued_loop_clip != "":
			var queued := _queued_loop_clip
			_queued_loop_clip = ""
			if play_looping(queued):
				_apply_runtime_feet_alignment()
				return
		if _persistent_pose_name == _one_shot_name:
			var held := walk_animation_player.get_animation(_one_shot_name) if walk_animation_player != null else null
			if held != null:
				walk_animation_player.seek(maxf(held.length - 0.001, 0.0), true)
				walk_animation_player.pause()
			_apply_runtime_feet_alignment()
			return
		_one_shot_name = ""
		_set_state(_wanted_state(delta), true)
		_apply_runtime_feet_alignment()
		return
	var wanted_state := _wanted_state(delta)
	_set_state(wanted_state)
	_update_locomotion_pace()
	_apply_runtime_feet_alignment()


## Cadence de la course d'apres la vitesse reelle du moteur. Hors moteur DAoC
## (corps generique), la cadence reste 1,0. Un passage sous/dessus le seuil de
## sprint bascule le clip `sprint` quand la scene en exporte un.
func _update_locomotion_pace() -> void:
	var pace := 1.0
	if player_body != null and _has_property(player_body, "local_run_speed_raw"):
		var reference := absf(float(player_body.get("local_run_speed_raw")))
		var motor_speed := _read_motor_speed_raw()
		if reference > 0.001 and motor_speed > 0.0:
			pace = clampf(motor_speed / reference, RUN_PACE_MIN, RUN_PACE_MAX)
	# 2026-09-27 : cadence lissee (la vitesse du moteur varie d une image a
	# l autre) et sprint a hysteresis (entree 1,08, sortie 1,0).
	locomotion_pace = lerpf(locomotion_pace, pace, 0.15) if locomotion_pace > 0.0 else pace
	pace = locomotion_pace
	var sprint_threshold := 1.0 if sprinting else SPRINT_PACE_THRESHOLD
	var now_sprinting := current_state == "run" and pace >= sprint_threshold
	if now_sprinting != sprinting:
		sprinting = now_sprinting
		if current_state == "run" and sprint_animation_name != "":
			_play_animation(run_animation_player, _run_clip_name())
	if current_state == "run" and run_animation_player != null:
		# Avec un clip de sprint dedie, il porte deja sa cadence ; la course
		# acceleree, elle, suit la vitesse.
		run_animation_player.speed_scale = 1.0 if (sprinting and sprint_animation_name != "") else pace


func _run_clip_name() -> String:
	if sprinting and sprint_animation_name != "":
		return sprint_animation_name
	return run_animation_name


## Le clip existe-t-il vraiment dans la scene exportee ?
func has_clip(clip_name: String) -> bool:
	return walk_animation_player != null and walk_animation_player.has_animation(clip_name)


## Posture de garde. Le serveur local decide de l'engagement ; ce noeud ne fait
## que traduire. Sans clip `combat_idle` exporte, l'appel est sans effet plutot
## que de choisir un remplacant.
func set_combat_stance(value: bool) -> void:
	if combat_stance == value:
		return
	combat_stance = value
	# P1-133 : hors combat les armes Belt=1 vont a la ceinture / au dos (objects.csv).
	preload("res://src/daoc/player/DaocPlayerEquipmentVisuals.gd").apply_sheath_state(self, not value)
	if _one_shot_name == "":
		_set_state(current_state, true)


## Joue un geste une seule fois, puis rend la main a la machine d'etats.
## Retourne false si le clip n'est pas dans la scene : l'appelant saura que le
## geste n'existe pas, au lieu de croire qu'il a ete joue.
func play_one_shot(clip_name: String) -> bool:
	_persistent_pose_name = ""
	return _play_gesture(clip_name)


## Joue un geste puis conserve sa derniere pose. Une mort ne repasse ainsi
## jamais dans la machine idle/marche tant qu'un respawn ne l'a pas liberee.
func play_persistent(clip_name: String) -> bool:
	_persistent_pose_name = clip_name
	if not _play_gesture(clip_name):
		_persistent_pose_name = ""
		return false
	return true


## P1-76 — joue un clip EN BOUCLE et garde la main jusqu'a `clear_persistent_pose`
## (ou un autre geste). Un clip « loop » d'animnifs.csv relance par `play_one_shot`
## a chaque cycle repartait de sa premiere image : c'est le saccade vu en fin
## d'incantation. Ici l'AnimationPlayer boucle seul, sans jamais s'arreter.
func play_looping(clip_name: String) -> bool:
	if not _play_gesture(clip_name):
		return false
	var animation := walk_animation_player.get_animation(clip_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_persistent_pose_name = ""
	_one_shot_end_msec = 0x7FFFFFFFFFFFFFFF
	return true


## P1-87 — un geste puis une boucle : `sit_down` puis `sit_idle`. La boucle
## demarre quand le geste finit, dans `_process`.
func play_then_loop(gesture: String, loop_clip: String) -> bool:
	if not has_clip(loop_clip):
		return false
	if not play_one_shot(gesture):
		return play_looping(loop_clip)
	_queued_loop_clip = loop_clip
	return true


## /sit : `sit_down` puis `sit_idle` en boucle ; /stand ou un pas : `stand_up`.
var sitting := false
var _queued_loop_clip := ""


func sit() -> bool:
	if sitting:
		return true
	if not play_then_loop("sit_down", "sit_idle"):
		return false
	sitting = true
	return true


func stand() -> bool:
	if not sitting:
		return false
	sitting = false
	_queued_loop_clip = ""
	if not play_one_shot("stand_up"):
		clear_persistent_pose()
	return true


func clear_persistent_pose() -> void:
	_queued_loop_clip = ""
	_persistent_pose_name = ""
	_one_shot_name = ""
	_one_shot_end_msec = 0
	_set_state(_wanted_state(0.0), true)


func _play_gesture(clip_name: String) -> bool:
	if clip_name == "" or walk_animation_player == null:
		return false
	if not walk_animation_player.has_animation(clip_name):
		return false
	var animation := walk_animation_player.get_animation(clip_name)
	if animation == null or animation.length <= 0.0:
		return false
	_set_node_visible(walk_node, true)
	_set_node_visible(run_node, false)
	_stop_animation(run_animation_player)
	walk_animation_player.speed_scale = 1.0
	if not animation_polish_enabled:
		walk_animation_player.stop()
	_queued_loop_clip = ""
	walk_animation_player.play(clip_name, AnimationPresentation.blend_seconds(animation_polish_enabled))
	_one_shot_name = clip_name
	_one_shot_end_msec = Time.get_ticks_msec() + int(animation.length * 1000.0)
	current_state = "one_shot:%s" % clip_name
	return true


func _wanted_state(delta: float) -> String:
	if force_state == "idle" or force_state == "walk" or force_state == "run":
		return force_state
	var motor_speed := _read_motor_speed_raw()
	if motor_speed >= 0.0:
		# Voie DAoC : vitesse en unites brutes, seuils bruts.
		if motor_speed < walk_threshold_raw:
			return "idle"
		# Le seuil de course suit l'allure CALIBREE du moteur quand il la
		# declare : `DaocGame.tscn` court a 300 unites (le banc a 1500), et un
		# seuil fixe a 900 y faisait MARCHER le joueur a pleine vitesse — donc
		# aucun sprint visible. La marche vaut 0,45 x course : le seuil est
		# pose a 0,7 x course.
		var run_threshold := run_threshold_raw
		if _has_property(player_body, "local_run_speed_raw"):
			var reference := absf(float(player_body.get("local_run_speed_raw")))
			if reference > 0.001:
				run_threshold = maxf(walk_threshold_raw, reference * (0.5 if current_state == "run" else 0.7))  # 2026-09-27 : hysteresis course/marche
		if motor_speed >= run_threshold:
			return "run"
		return "walk"
	var speed := _read_player_speed(delta)
	if speed < walk_threshold:
		return "idle"
	if speed >= run_threshold:
		return "run"
	return "walk"


## Vitesse horizontale reelle, en unites DAoC brutes, ou -1 si le corps n'est
## pas un moteur DAoC.
##
## `DaocPlayerMotor` derive de CharacterBody3D mais deplace le joueur en
## ECRIVANT SA POSITION : il n'appelle jamais `move_and_slide` et laisse donc
## `velocity` a zero en permanence. Lire `velocity` renvoyait par consequent
## toujours 0, la machine d'etats restait sur `idle`, et ni la marche ni la
## course ne se voyaient. Le moteur publie en revanche son intention de
## deplacement (`last_move_vector`, sans dimension) et sa vitesse effective
## (`last_speed_raw`, en unites DAoC) : leur produit est la vraie vitesse.
func _read_motor_speed_raw() -> float:
	if player_body == null:
		return -1.0
	if not _has_property(player_body, "last_move_vector") or not _has_property(player_body, "last_speed_raw"):
		return -1.0
	var move_value: Variant = player_body.get("last_move_vector")
	if typeof(move_value) != TYPE_VECTOR2:
		return -1.0
	return (move_value as Vector2).length() * absf(float(player_body.get("last_speed_raw")))


func _read_player_speed(delta: float) -> float:
	if player_body != null and _has_property(player_body, "velocity"):
		var velocity_value: Variant = player_body.get("velocity")
		if typeof(velocity_value) == TYPE_VECTOR3:
			var velocity_vec: Vector3 = velocity_value
			if velocity_vec.length_squared() > 0.0:
				return velocity_vec.length()
	if player_body != null and player_body is Node3D:
		var current_position: Vector3 = (player_body as Node3D).global_position
		if _last_position_valid and delta > 0.00001:
			var dist := current_position.distance_to(_last_global_position)
			_last_global_position = current_position
			return dist / delta
		_last_global_position = current_position
		_last_position_valid = true
	return 0.0


func _set_state(state: String, force: bool = false) -> void:
	if not force and state == current_state:
		return
	current_state = state
	if state == "run":
		_set_node_visible(walk_node, false)
		_set_node_visible(run_node, true)
		_stop_animation(walk_animation_player)
		_play_animation(run_animation_player, _run_clip_name())
	elif state == "walk":
		_set_node_visible(walk_node, true)
		_set_node_visible(run_node, false)
		_stop_animation(run_animation_player)
		_play_animation(walk_animation_player, walk_animation_name)
	else:
		_set_node_visible(walk_node, true)
		_set_node_visible(run_node, false)
		_stop_animation(run_animation_player)
		# A l'arret, la posture depend de l'engagement : garde arme en combat,
		# maintien neutre sinon. C'est la distinction que l'export apportait
		# jusqu'ici en ecrasant `idle`, ce qui figeait l'epee en main.
		var resting_name := idle_animation_name
		if combat_stance and combat_idle_animation_name != "":
			resting_name = combat_idle_animation_name
		if idle_mode == "walk_loop" or combat_stance:
			_play_animation(walk_animation_player, resting_name)
		else:
			_freeze_first_frame(walk_animation_player, resting_name)


func _apply_visual_transform() -> void:
	position = Vector3(0.0, ground_offset, 0.0)
	rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	scale = Vector3.ONE * visual_scale


func _apply_runtime_feet_alignment() -> void:
	if not feet_alignment_enabled:
		return
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var feet := DaocVisualFeetResolverScript.resolve(self, feet_alignment_mode) as Dictionary
	if not bool(feet.get("ok", false)):
		return
	feet_alignment_source = str(feet.get("source", "none"))
	var target_y := parent.global_position.y + feet_alignment_offset
	var delta := target_y - float(feet.get("lowest_y", target_y))
	if absf(delta) <= 0.001:
		return
	if feet_alignment_max_step > 0.0:
		delta = clampf(delta, -feet_alignment_max_step, feet_alignment_max_step)
	position.y += delta
func _instantiate_visual_scene(path: String, node_name: String) -> Node3D:
	# Les scenes du Character Lab peuvent etre regenerees pendant que DaocGame
	# est deja ouvert. `load()` reutilisait alors le PackedScene mis en cache et
	# remontait l'ancien skin (notamment les liaisons L ForeTwist), bien que le
	# fichier corrige soit present sur disque. Le montage du joueur est un point
	# de rafraichissement explicite : on remplace donc l'entree du cache.
	var resource: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null or not (resource is PackedScene):
		return null
	var instanced: Node = (resource as PackedScene).instantiate()
	preload("res://src/daoc/assets/DaocMeshWindingFix.gd").apply(instanced)
	if instanced == null:
		return null
	# Effectue la correction sur les objets Godot reels. Les matrices ecrites
	# directement dans les .tscn par l'outil de maintenance n'avaient pas la
	# meme convention de stockage que Transform3D et projetaient les sommets du
	# bras au loin. Ici Godot compose lui-meme les transformations.
	_remap_left_forearm_skins(instanced)
	if instanced is Node3D:
		var node3d := instanced as Node3D
		node3d.name = node_name
		node3d.position = Vector3.ZERO
		node3d.rotation_degrees = Vector3.ZERO
		node3d.scale = Vector3.ONE
		return node3d
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.add_child(instanced)
	return wrapper


func _remap_left_forearm_skins(root: Node) -> int:
	var changed := 0
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
		if mesh_instance.skin != null and skeleton != null:
			# Deux instances de la meme scene (marche/course) ne doivent pas
			# modifier une ressource Skin partagee entre elles.
			mesh_instance.skin = mesh_instance.skin.duplicate(true) as Skin
			var skin := mesh_instance.skin
			for bind_index in range(skin.get_bind_count()):
				var old_bone := skin.get_bind_bone(bind_index)
				if old_bone < 0 or old_bone >= skeleton.get_bone_count():
					continue
				var old_name := skeleton.get_bone_name(old_bone)
				var new_name := "Bip01 L Forearm" if old_name == "Bip01 L ForeTwist" else ("Bip01 L Hand" if old_name == "Bip01 L ForeTwist1" else "")
				if new_name.is_empty():
					continue
				var new_bone := skeleton.find_bone(new_name)
				if new_bone < 0:
					continue
				var corrected_bind := skeleton.get_bone_global_rest(new_bone).affine_inverse() \
					* skeleton.get_bone_global_rest(old_bone) * skin.get_bind_pose(bind_index)
				skin.set_bind_bone(bind_index, new_bone)
				skin.set_bind_pose(bind_index, corrected_bind)
				changed += 1
	for child in root.get_children():
		changed += _remap_left_forearm_skins(child)
	return changed


func _clear_visual_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	walk_node = null
	run_node = null
	walk_animation_player = null
	run_animation_player = null
	idle_animation_name = ""
	walk_animation_name = ""
	run_animation_name = ""
	current_state = "uninitialized"


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _first_animation_name(player: AnimationPlayer) -> String:
	if player == null:
		return ""
	var names: PackedStringArray = player.get_animation_list()
	for name_value in names:
		var name := str(name_value)
		var lower := name.to_lower()
		if lower != "reset" and lower != "rest" and not lower.contains("t-pose"):
			return name
	if names.size() > 0:
		return str(names[0])
	return ""


func _preferred_animation_name(player: AnimationPlayer, preferred: String) -> String:
	if player != null and not preferred.is_empty() and player.has_animation(preferred):
		return preferred
	return _first_animation_name(player)


## Ne force la boucle que sur les etats CONTINUS.
##
## Cette fonction bouclait autrefois TOUTES les animations, ce qui etait sans
## consequence tant que la scene ne portait que idle/walk/run. Depuis que le
## Character Lab exporte aussi les attaques, le flinch et la mort, boucler
## aveuglement ferait rejouer un coup d'epee ou une agonie sans fin. Le mode
## boucle des autres clips vient de la colonne `type` de animnifs.csv et doit
## etre respecte tel quel.
func _set_animation_loops(player: AnimationPlayer) -> void:
	if player == null:
		return
	for name_value in player.get_animation_list():
		var animation_name := str(name_value)
		if not CONTINUOUS_CLIP_NAMES.has(animation_name):
			continue
		var animation := player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


func _play_animation(player: AnimationPlayer, animation_name: String) -> void:
	if player == null or animation_name == "":
		return
	player.speed_scale = 1.0
	if player.current_animation != animation_name or not player.is_playing():
		player.play(animation_name, AnimationPresentation.blend_seconds(animation_polish_enabled))


func _stop_animation(player: AnimationPlayer) -> void:
	if player == null:
		return
	player.stop()


func _freeze_first_frame(player: AnimationPlayer, animation_name: String) -> void:
	if player == null or animation_name == "":
		return
	player.stop()
	player.play(animation_name)
	player.seek(0.0, true)
	player.stop(true)


func _set_node_visible(node: Node, value: bool) -> void:
	if node != null and node is Node3D:
		(node as Node3D).visible = value


func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for property_info in obj.get_property_list():
		if typeof(property_info) == TYPE_DICTIONARY and str(property_info.get("name", "")) == property_name:
			return true
	return false
