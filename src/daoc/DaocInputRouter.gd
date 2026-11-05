extends Node
class_name DaocInputRouter

const DaocKeyboardBindingsScript = preload("res://src/daoc/DaocKeyboardBindings.gd")

## Emis quand un clic souris atteint le MONDE (hors interface). Le garde
## `_pointer_over_ui()` a deja rendu la main aux fenetres : parvenir ici signifie
## que le pointeur ne survole aucun Control. Le ciblage a la souris s'y abonne
## sans que le routeur connaisse la moindre regle de jeu.
signal world_click(screen_position: Vector2, button_index: int)

## P1-30-HF1 — le DOUBLE clic gauche parvenu au monde, signal SEPARE.
##
## Il en fallait un nouveau plutot qu'un troisieme argument a `world_click` :
## celui-la est deja consomme par le ciblage P1-21H, par la scene de jeu et par
## le banc, et changer sa signature aurait demande de toucher aux trois pour un
## besoin qui n'est pas le leur.
##
## GODOT EMET LES DEUX. Un double clic produit d'abord un clic simple, puis un
## second evenement portant `double_click`. Le ciblage se declenche donc AVANT le
## ramassage — ce qui est l'ordre voulu : on designe, puis on ouvre.
signal world_double_click(screen_position: Vector2, button_index: int)
## 2026-09-29 : un clic DROIT court (sans rotation de camera) vise le monde :
## dans DAoC c est le geste qui parle a un PNJ (« Right click to display a
## shop window », DOL). Emis au relachement, position du pressage.
signal world_right_click(screen_position: Vector2)
## P1-82 — la touche Sprint (action 0x42 du keyboard.dat) a ete pressee. En
## ligne, le monde l'envoie au serveur comme la capacite Sprint (0xBB) ; hors
## ligne le place-holder local reste ce qu'il etait.
signal sprint_requested()
## P1-109 — les touches Follow (62), Stick (63), Face (64) et Ground Target
## (44) du keyboard.dat, telles que game.dll les nomme (actions 0x69, 0x6a,
## 0x6c, 0x2c de sa table). Ce sont des gestes CLIENT : DOL n a pas de
## commande /face, /stick ou /follow — le monde tourne ou suit, et le 0xA9
## porte la position. La cible au sol part en 0xEC.
signal follow_requested(mode: String)
signal face_requested()
signal ground_target_requested(screen_position: Vector2)
## Le suivi automatique (stick / follow) vient d etre rompu par une entree de
## deplacement du joueur — comme dans le client d origine.
signal auto_move_broken()
## P1-110 — Nearest Loot (72) et Quest Journal (82) du keyboard.dat.
signal loot_requested()
signal quest_journal_requested()

const KEYBOARD_MOVEMENT_ACTION_IDS: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0x14, 0x21, 0x2A, 0x42, 0x53]
const ACTION_GROUND_TARGET := 44
const ACTION_FOLLOW := 62
const ACTION_STICK := 63
const ACTION_FACE := 64
const ACTION_NEAREST_LOOT := 72
const ACTION_QUEST_JOURNAL := 82

## P1-109 — un deplacement AUTOMATIQUE (stick / follow) : tant qu il est actif
## et que le joueur ne touche a rien, l axe avant vaut `auto_forward`.
var auto_move_active := false
var auto_forward := 0.0


func set_auto_move(active: bool, forward: float = 0.0) -> void:
	auto_move_active = active
	auto_forward = clampf(forward, -1.0, 1.0)
	if not active:
		auto_forward = 0.0

## Routeur input global DAoC.
## Paquet 02 : les axes joueur viennent prioritairement de keyboard.dat.
## Paquet 03/04 : la souris est UI/caméra/mouselook ; le déplacement souris devient legacy,
## désactivé par défaut et gardé uniquement derrière exports.
## Paquet 05 : runlock/walk/sprint local minimal, sans réseau.

@export var use_keyboard_dat_bindings: bool = true
@export var keyboard_preset: String = "rpgdefault"
@export var respect_keyboard_shift_raw: bool = false
@export var debug_print_keyboard_bindings: bool = false
@export_global_dir var keyboard_dat_root_override: String = ""

@export var right_mouse_turns_player: bool = false
@export var capture_mouse_on_right_button: bool = true

## Emet `world_click` au clic gauche parvenu au monde. Le deplacement de camera
## et les fenetres ne sont pas touches : c'est un signal en plus, pas un
## detournement.
@export var emit_world_click_events: bool = true
const RIGHT_CLICK_MAX_MOTION_PX := 6.0
const RIGHT_CLICK_MAX_MSEC := 350
var _right_press_position := Vector2.ZERO
var _right_press_msec := 0
var _right_press_motion := 0.0

## Legacy/prototype : désactivé par défaut. Le déplacement principal doit venir du clavier.
@export var mouse_right_moves_forward: bool = false
@export var mouse_left_moves_backward: bool = false
@export var mouse_both_buttons_move_forward: bool = false
@export var mouse_legacy_disabled_when_ui_hovered: bool = true
@export var mouse_legacy_disabled_when_chat_focused: bool = true
@export var mouse_legacy_warning_log_once: bool = true

@export var runlock_cancel_on_backward: bool = true
@export var walk_is_toggle: bool = true
@export var runlock_forward_breaks_runlock: bool = false
@export var sprint_is_local_placeholder: bool = true
@export var debug_input: bool = false

var player: Node = null
var player_camera: Node = null
var input_state: DaocInputState = DaocInputState.new()
var keyboard_bindings: RefCounted = null

var _right_mouse_down: bool = false
var _left_mouse_down: bool = false
var _middle_mouse_down: bool = false
var _warned_legacy_mouse: bool = false
var _logged_movement_profile: bool = false
var _walk_toggle_enabled: bool = false
var _camera_toggled_frame: bool = false
var _camera_mouse_motion_events: int = 0
var _camera_wheel_notches_total: float = 0.0
var _last_mouse_delta: Vector2 = Vector2.ZERO
var _last_camera_input_kind: String = "none"


func setup(p_player: Node, p_camera: Node, p_daoc_root: String = "") -> void:
	player = p_player
	player_camera = p_camera
	process_priority = -100
	set_process_input(true)
	set_process(true)
	set_physics_process(true)
	_connect_state_consumers()
	_setup_keyboard_bindings(p_daoc_root)
	_log_movement_profile()


func _setup_keyboard_bindings(p_daoc_root: String) -> void:
	keyboard_bindings = DaocKeyboardBindingsScript.new()
	var root := keyboard_dat_root_override.strip_edges()
	if root == "":
		root = p_daoc_root
	var ok: bool = bool(keyboard_bindings.call("load_from_daoc_root", root))
	if not ok:
		if debug_print_keyboard_bindings:
			push_warning(str(keyboard_bindings.get("last_error")))
		return
	keyboard_bindings.set("active_section", keyboard_preset)
	if debug_print_keyboard_bindings:
		print(keyboard_bindings.call("debug_dump_preset", keyboard_preset))


func get_input_state() -> DaocInputState:
	return input_state


func _connect_state_consumers() -> void:
	if player != null and player.has_method("set_input_state"):
		player.call("set_input_state", input_state)
	if player_camera != null and player_camera.has_method("set_input_state"):
		player_camera.call("set_input_state", input_state)


func _process(_delta: float) -> void:
	_refresh_continuous_state()


func _physics_process(_delta: float) -> void:
	_refresh_continuous_state()
	input_state.reset_frame_delta()


func _input(event: InputEvent) -> void:
	if player == null and player_camera == null:
		return
	if _is_chat_focused():
		return

	# `_input()` passe AVANT le GUI dans Godot, et plusieurs branches ci-dessous
	# appellent `set_input_as_handled()`. Sans ce garde, aucune fenetre de
	# l'interface ne recoit jamais un clic : rien n'est deplacable ni cliquable.
	# On rend donc la main des que le pointeur survole un Control. En vue souris
	# capturee (clic droit maintenu) il n'y a aucun survol, donc la camera garde
	# la priorite comme avant.
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if _pointer_over_ui():
			return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return

	if event is InputEventKey:
		_handle_key(event)
		return


## Vrai quand le pointeur survole un Control qui accepte la souris. En souris
## capturee il n'y a pas de survol : la camera reprend la main d'elle-meme.
func _pointer_over_ui() -> bool:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	return viewport.gui_get_hovered_control() != null


func _refresh_continuous_state() -> void:
	input_state.reset_axes()
	# La saisie du chat lit les memes lettres que les raccourcis de mouvement.
	# Tant qu'un champ texte a le focus, le routeur rend donc un etat neutre.
	if _is_chat_focused():
		input_state.jump_held = false
		input_state.down_held = false
		input_state.strafe_toggle_held = false
		input_state.walk_held = false
		input_state.sprint_held = false
		input_state.set_mouse_buttons(false, false, false)
		input_state.mouse_look_held = false
		input_state.mouse_pan_held = false
		return

	var forward_axis := input_forward_axis()
	var backward_axis := input_backward_axis()
	var turn_axis := input_turn_axis()
	var strafe_axis := input_strafe_axis()

	input_state.jump_held = input_jump_up()
	input_state.down_held = input_down()
	input_state.strafe_toggle_held = input_strafe_toggle()
	input_state.walk_held = input_walk() or _walk_toggle_enabled
	input_state.sprint_held = input_sprint()
	input_state.input_source_label = "keyboard.dat" if _keyboard_dat_ready() and use_keyboard_dat_bindings else "fallback"
	_refresh_keyboard_action_debug()

	if input_state.strafe_toggle_held:
		strafe_axis = clampf(strafe_axis + turn_axis, -1.0, 1.0)
		turn_axis = 0.0

	if backward_axis > 0.0 and runlock_cancel_on_backward:
		runlock_disable()
	if forward_axis > 0.0 and runlock_forward_breaks_runlock:
		runlock_disable()
	if input_state.run_lock_enabled:
		forward_axis = maxf(forward_axis, 1.0)

	var translated_forward := clampf(forward_axis - backward_axis, -1.0, 1.0)
	translated_forward = _apply_legacy_mouse_movement(translated_forward)

	# P1-109 : le suivi automatique tient tant que le joueur ne bouge pas lui-meme.
	if auto_move_active:
		if translated_forward != 0.0 or strafe_axis != 0.0 or turn_axis != 0.0:
			set_auto_move(false)
			auto_move_broken.emit()
		else:
			translated_forward = auto_forward

	input_state.forward_axis = translated_forward
	input_state.strafe_axis = clampf(strafe_axis, -1.0, 1.0)
	input_state.turn_axis = clampf(turn_axis, -1.0, 1.0)
	input_state.set_mouse_buttons(_left_mouse_down, _right_mouse_down, _middle_mouse_down)
	input_state.mouse_look_held = mouse_right_mouselook_state()
	input_state.mouse_pan_held = mouse_middle_mousepan_state()


func input_forward_axis() -> float:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_axis(PackedInt32Array([0, 0x14]))
	return 1.0 if Input.is_key_pressed(KEY_Z) else 0.0


func input_backward_axis() -> float:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_axis(PackedInt32Array([1, 0x21]))
	return 1.0 if Input.is_key_pressed(KEY_S) else 0.0


func input_turn_axis() -> float:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_axis(PackedInt32Array([3])) - _action_axis(PackedInt32Array([2]))
	var v := 0.0
	if Input.is_key_pressed(KEY_D):
		v += 1.0
	if Input.is_key_pressed(KEY_Q):
		v -= 1.0
	return clampf(v, -1.0, 1.0)


func input_strafe_axis() -> float:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_axis(PackedInt32Array([9])) - _action_axis(PackedInt32Array([8]))
	var v := 0.0
	if Input.is_key_pressed(KEY_E):
		v += 1.0
	if Input.is_key_pressed(KEY_A):
		v -= 1.0
	return clampf(v, -1.0, 1.0)


func input_jump_up() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(4)
	return Input.is_key_pressed(KEY_SPACE)


func input_down() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(5)
	return Input.is_key_pressed(KEY_C)


func input_strafe_toggle() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(6)
	return false


func input_walk() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(7)
	return Input.is_key_pressed(KEY_SHIFT)


func input_sprint() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(0x42)
	return false


func input_runlock() -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return _action_pressed(0x2A) or _action_pressed(0x53)
	return Input.is_key_pressed(KEY_NUMLOCK)


func input_debug_string_from_keyboard_dat() -> String:
	if not _keyboard_dat_ready():
		return "keyboard.dat absent"
	return str(keyboard_bindings.call("debug_compact_actions", keyboard_preset, PackedInt32Array(KEYBOARD_MOVEMENT_ACTION_IDS)))


func get_input_action_snapshot() -> Dictionary:
	var keyboard_snapshot: Dictionary = {}
	if _keyboard_dat_ready():
		keyboard_snapshot = keyboard_bindings.call("get_actions_debug_snapshot", keyboard_preset, PackedInt32Array(KEYBOARD_MOVEMENT_ACTION_IDS), respect_keyboard_shift_raw, true) as Dictionary
	return {
		"source": input_state.input_source_label,
		"keyboard_ready": _keyboard_dat_ready(),
		"keyboard_preset": keyboard_preset,
		"keyboard_actions": keyboard_snapshot,
		"input_state": input_state.get_debug_snapshot() if input_state.has_method("get_debug_snapshot") else input_state.debug_string(),
	}


func mouse_left_ui_click_state() -> bool:
	return _left_mouse_down


func mouse_right_ui_context_state() -> bool:
	return _right_mouse_down and not right_mouse_turns_player


func mouse_right_mouselook_state() -> bool:
	return _right_mouse_down


func mouse_middle_mousepan_state() -> bool:
	return _middle_mouse_down


func mouse_both_chord_state() -> bool:
	return _left_mouse_down and _right_mouse_down


func legacy_mouse_right_moves_forward() -> bool:
	return mouse_right_moves_forward


func legacy_mouse_left_moves_backward() -> bool:
	return mouse_left_moves_backward


func legacy_mouse_both_moves_forward() -> bool:
	return mouse_both_buttons_move_forward


func runlock_toggle() -> void:
	input_state.run_lock_enabled = not input_state.run_lock_enabled
	input_state.run_lock_pressed_frame = true
	input_state.last_action_debug = "runlock=%s" % str(input_state.run_lock_enabled)


func runlock_enable() -> void:
	input_state.run_lock_enabled = true
	input_state.last_action_debug = "runlock=true"


func runlock_disable() -> void:
	if input_state.run_lock_enabled:
		input_state.last_action_debug = "runlock=false"
	input_state.run_lock_enabled = false


func sprint_send_command_stub() -> void:
	sprint_requested.emit()
	if sprint_is_local_placeholder:
		input_state.sprint_pressed_frame = true
		input_state.last_action_debug = "&sprint stub local"
		if debug_input:
			print("daoc input sprint stub: &sprint")


func sprint_debug_state() -> String:
	return "sprint held=%s pressed=%s local_stub=%s" % [str(input_state.sprint_held), str(input_state.sprint_pressed_frame), str(sprint_is_local_placeholder)]


func get_locomotion_router_snapshot() -> Dictionary:
	return {
		"walk_is_toggle": walk_is_toggle,
		"walk_toggle_enabled": _walk_toggle_enabled,
		"runlock_cancel_on_backward": runlock_cancel_on_backward,
		"runlock_forward_breaks_runlock": runlock_forward_breaks_runlock,
		"run_lock_enabled": input_state.run_lock_enabled,
		"sprint_is_local_placeholder": sprint_is_local_placeholder,
		"sprint_held": input_state.sprint_held,
		"strafe_toggle_held": input_state.strafe_toggle_held,
		"movement_axes": {
			"forward": input_state.forward_axis,
			"strafe": input_state.strafe_axis,
			"turn": input_state.turn_axis,
		},
		"input_flags": input_state.get_locomotion_flags_snapshot() if input_state.has_method("get_locomotion_flags_snapshot") else {},
		"last_action_debug": input_state.last_action_debug,
	}


func get_router_debug_snapshot() -> Dictionary:
	return {
		"use_keyboard_dat_bindings": use_keyboard_dat_bindings,
		"keyboard_preset": keyboard_preset,
		"keyboard_ready": _keyboard_dat_ready(),
		"legacy_right": mouse_right_moves_forward,
		"legacy_left": mouse_left_moves_backward,
		"legacy_both": mouse_both_buttons_move_forward,
		"walk_is_toggle": walk_is_toggle,
		"walk_toggle_enabled": _walk_toggle_enabled,
		"runlock_cancel_on_backward": runlock_cancel_on_backward,
		"runlock_forward_breaks_runlock": runlock_forward_breaks_runlock,
		"sprint_is_local_placeholder": sprint_is_local_placeholder,
		"locomotion": get_locomotion_router_snapshot(),
		"keyboard_actions": input_state.keyboard_action_debug,
		"mouse_camera": get_mouse_camera_debug_snapshot(),
		"state": input_state.debug_string(),
	}


func get_mouse_camera_debug_snapshot() -> Dictionary:
	return {
		"right_mouse_down": _right_mouse_down,
		"left_mouse_down": _left_mouse_down,
		"middle_mouse_down": _middle_mouse_down,
		"right_mouse_turns_player": right_mouse_turns_player,
		"capture_mouse_on_right_button": capture_mouse_on_right_button,
		"camera_mouse_motion_events": _camera_mouse_motion_events,
		"camera_wheel_notches_total": _camera_wheel_notches_total,
		"last_mouse_delta": _last_mouse_delta,
		"last_camera_input_kind": _last_camera_input_kind,
		"legacy_mouse_move_allowed": _legacy_mouse_allowed(),
	}


func walk_toggle() -> void:
	_walk_toggle_enabled = not _walk_toggle_enabled
	input_state.walk_held = _walk_toggle_enabled
	input_state.last_action_debug = "walk_toggle=%s" % str(_walk_toggle_enabled)


func walk_disable() -> void:
	_walk_toggle_enabled = false
	input_state.walk_held = false


func _refresh_keyboard_action_debug() -> void:
	var states: Dictionary = {}
	var active_ids := PackedInt32Array()
	var active_names := PackedStringArray()
	var parts := PackedStringArray()
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		for action_id in KEYBOARD_MOVEMENT_ACTION_IDS:
			var pressed := _action_pressed(int(action_id))
			states[int(action_id)] = pressed
			var name := str(keyboard_bindings.call("get_action_display_name", int(action_id)))
			if pressed:
				active_ids.append(int(action_id))
				active_names.append(name)
			var binding: Dictionary = keyboard_bindings.call("get_action_binding", keyboard_preset, int(action_id)) as Dictionary
			var key_label := "?"
			if not binding.is_empty():
				key_label = "UNBOUND" if bool(binding.get("unbound", true)) else str(binding.get("key_name", "?"))
			parts.append("%02d=%s%s" % [int(action_id), key_label, "*" if pressed else ""])
	else:
		parts.append("fallback keyboard path")
	input_state.set_keyboard_action_debug(states, active_ids, active_names, " ".join(parts))


func _action_axis(action_ids: PackedInt32Array) -> float:
	return 1.0 if bool(keyboard_bindings.call("is_any_action_pressed", keyboard_preset, action_ids, respect_keyboard_shift_raw)) else 0.0


func _action_pressed(action_id: int) -> bool:
	return bool(keyboard_bindings.call("is_action_pressed", keyboard_preset, action_id, respect_keyboard_shift_raw))


func _keyboard_dat_ready() -> bool:
	return keyboard_bindings != null and bool(keyboard_bindings.get("loaded")) and bool(keyboard_bindings.call("has_preset", keyboard_preset))


func _apply_legacy_mouse_movement(current_forward_axis: float) -> float:
	input_state.mouse_forward_held = false
	input_state.mouse_backward_held = false
	input_state.mouse_legacy_move_used = false
	if not _legacy_mouse_allowed():
		return current_forward_axis

	var mouse_both_down := mouse_both_chord_state()
	if legacy_mouse_both_moves_forward() and mouse_both_down:
		input_state.mouse_forward_held = true
		input_state.mouse_backward_held = false
		input_state.mouse_legacy_move_used = true
		_log_legacy_mouse_once()
		return maxf(current_forward_axis, 1.0)
	if legacy_mouse_right_moves_forward() and _right_mouse_down:
		input_state.mouse_forward_held = true
		input_state.mouse_legacy_move_used = true
		_log_legacy_mouse_once()
		return maxf(current_forward_axis, 1.0)
	if legacy_mouse_left_moves_backward() and _left_mouse_down:
		input_state.mouse_backward_held = true
		input_state.mouse_legacy_move_used = true
		_log_legacy_mouse_once()
		return minf(current_forward_axis, -1.0)
	return current_forward_axis


func _legacy_mouse_allowed() -> bool:
	if not mouse_right_moves_forward and not mouse_left_moves_backward and not mouse_both_buttons_move_forward:
		return false
	if mouse_legacy_disabled_when_ui_hovered and _is_ui_hovered():
		return false
	if mouse_legacy_disabled_when_chat_focused and _is_chat_focused():
		return false
	return true


func _is_ui_hovered() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focused := vp.gui_get_focus_owner()
	return focused != null


func _is_chat_focused() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focused := vp.gui_get_focus_owner()
	if focused == null:
		return false
	var n := focused.name.to_lower()
	return n.contains("chat") or n.contains("edit") or n.contains("line")


func _log_movement_profile() -> void:
	if _logged_movement_profile:
		return
	_logged_movement_profile = true
	var source := "keyboard.dat" if _keyboard_dat_ready() and use_keyboard_dat_bindings else "fallback"
	var legacy_enabled := mouse_right_moves_forward or mouse_left_moves_backward or mouse_both_buttons_move_forward
	if legacy_enabled:
		print("DAoC movement profile: source=%s; legacy mouse movement ENABLED behind flags." % source)
	else:
		print("DAoC movement profile: source=%s; legacy mouse movement disabled; mouse is camera/UI." % source)


func _log_legacy_mouse_once() -> void:
	if not mouse_legacy_warning_log_once or _warned_legacy_mouse:
		return
	_warned_legacy_mouse = true
	print("DAoC legacy mouse movement is enabled in this profile; keyboard.dat remains the primary movement source.")


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_mouse_down = event.pressed
		# Le pointeur ne survole aucun Control (garde en amont) : ce clic vise le
		# monde. On previent le ciblage souris AVANT de consommer l'evenement.
		if event.pressed and emit_world_click_events:
			world_click.emit(event.position, MOUSE_BUTTON_LEFT)
			if event.double_click:
				world_double_click.emit(event.position, MOUSE_BUTTON_LEFT)
		_refresh_continuous_state()
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input left_mouse=", _left_mouse_down, " state=", input_state.debug_string())
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		_right_mouse_down = event.pressed
		if event.pressed:
			_right_press_position = event.position
			_right_press_msec = Time.get_ticks_msec()
			_right_press_motion = 0.0
		elif emit_world_click_events and _right_press_motion <= RIGHT_CLICK_MAX_MOTION_PX \
				and Time.get_ticks_msec() - _right_press_msec <= RIGHT_CLICK_MAX_MSEC:
			world_right_click.emit(_right_press_position)
		if capture_mouse_on_right_button:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _right_mouse_down else Input.MOUSE_MODE_VISIBLE
		_refresh_continuous_state()
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input right_mouse=", _right_mouse_down, " state=", input_state.debug_string())
		return

	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_mouse_down = event.pressed
		_refresh_continuous_state()
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input middle_mouse_pan=", _middle_mouse_down, " state=", input_state.debug_string())
		return

	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera_wheel_notches_total += 1.0
		_last_camera_input_kind = "wheel_up"
		if player_camera != null and player_camera.has_method("zoom_wheel_notches"):
			player_camera.call("zoom_wheel_notches", 1.0)
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input wheel up")
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera_wheel_notches_total -= 1.0
		_last_camera_input_kind = "wheel_down"
		if player_camera != null and player_camera.has_method("zoom_wheel_notches"):
			player_camera.call("zoom_wheel_notches", -1.0)
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input wheel down")
		return


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	input_state.raw_mouse_delta += event.relative
	if _right_mouse_down:
		_right_press_motion += event.relative.length()
	_last_mouse_delta = event.relative
	if not _right_mouse_down and not _middle_mouse_down:
		return
	_camera_mouse_motion_events += 1
	_last_camera_input_kind = "mouselook" if _right_mouse_down else "mousepan"
	mouse_motion_to_camera_orbit(event.relative)
	get_viewport().set_input_as_handled()
	if debug_input:
		print("daoc input motion dx=", event.relative.x, " dy=", event.relative.y, " state=", input_state.debug_string())


func mouse_motion_to_camera_orbit(delta: Vector2) -> void:
	if right_mouse_turns_player and _right_mouse_down:
		mouse_motion_to_player_steering(delta)
	else:
		if player_camera != null and player_camera.has_method("orbit_mouse_dx"):
			player_camera.call("orbit_mouse_dx", delta.x)
	if player_camera != null and player_camera.has_method("tilt_mouse_dy"):
		player_camera.call("tilt_mouse_dy", delta.y)


func mouse_motion_to_player_steering(delta: Vector2) -> void:
	if player == null or not player.has_method("turn_by_degrees"):
		return
	var camera_angle_per_pixel := 1.35
	if player_camera != null:
		var v: Variant = player_camera.get("mouse_angle_units_per_pixel")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			camera_angle_per_pixel = float(v)
	var deg_per_pixel := camera_angle_per_pixel * 360.0 / 4096.0
	player.call("turn_by_degrees", -delta.x * deg_per_pixel)
	if player_camera != null and player_camera.has_method("set_angle_raw"):
		player_camera.call("set_angle_raw", 0.0)


func mouse_capture_release_policy(release: bool = false) -> void:
	if release:
		_right_mouse_down = false
		_left_mouse_down = false
		_middle_mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_continuous_state()


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		mouse_capture_release_policy(true)
		get_viewport().set_input_as_handled()
		return

	if _event_is_walk(event):
		if walk_is_toggle:
			walk_toggle()
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input walk_toggle=", _walk_toggle_enabled)
		return

	if _event_is_runlock(event):
		runlock_toggle()
		get_viewport().set_input_as_handled()
		if debug_input:
			print("daoc input run_lock=", input_state.run_lock_enabled)
		return

	if _event_is_camera_reset(event):
		if player_camera != null and player_camera.has_method("reset_camera"):
			player_camera.call("reset_camera")
		get_viewport().set_input_as_handled()
		return

	if _event_is_camera_toggle(event):
		_camera_toggled_frame = true
		if player_camera != null and player_camera.has_method("toggle_camera_mode"):
			player_camera.call("toggle_camera_mode")
		get_viewport().set_input_as_handled()
		return

	if _event_is_sprint(event):
		sprint_send_command_stub()
		get_viewport().set_input_as_handled()
		return

	# P1-109 : Follow / Stick / Face / Ground Target, gestes client.
	if _event_is_keyboard_action(event, ACTION_FOLLOW):
		follow_requested.emit("follow")
		get_viewport().set_input_as_handled()
		return
	if _event_is_keyboard_action(event, ACTION_STICK):
		follow_requested.emit("stick")
		get_viewport().set_input_as_handled()
		return
	if _event_is_keyboard_action(event, ACTION_FACE):
		face_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _event_is_keyboard_action(event, ACTION_NEAREST_LOOT):
		loot_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _event_is_keyboard_action(event, ACTION_QUEST_JOURNAL):
		quest_journal_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _event_is_keyboard_action(event, ACTION_GROUND_TARGET):
		ground_target_requested.emit(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return

	# Prototype des commandes caméra les plus utiles. Ctrl+D évite le conflit avec Turn Right.
	if event.keycode == KEY_D and event.ctrl_pressed:
		if player_camera != null and player_camera.has_method("reset_camera"):
			player_camera.call("reset_camera")
		get_viewport().set_input_as_handled()
		return


func _event_is_walk(event: InputEventKey) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_action", event, keyboard_preset, 7, respect_keyboard_shift_raw))
	return event.keycode == KEY_SHIFT


func _event_is_camera_reset(event: InputEventKey) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_action", event, keyboard_preset, 14, respect_keyboard_shift_raw))
	return event.keycode == KEY_KP_5


func _event_is_camera_toggle(event: InputEventKey) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_action", event, keyboard_preset, 86, respect_keyboard_shift_raw))
	return event.keycode == KEY_F11


func _event_is_runlock(event: InputEventKey) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_any_action", event, keyboard_preset, PackedInt32Array([0x2A, 0x53]), respect_keyboard_shift_raw))
	return event.keycode == KEY_NUMLOCK


## Sans keyboard.dat ces quatre gestes n ont pas de touche de repli : ils
## restent joignables par la console (/follow, /stick, /face, /gt).
func _event_is_keyboard_action(event: InputEventKey, action_id: int) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_action", event, keyboard_preset, action_id, respect_keyboard_shift_raw))
	return false


func _event_is_sprint(event: InputEventKey) -> bool:
	if _keyboard_dat_ready() and use_keyboard_dat_bindings:
		return bool(keyboard_bindings.call("is_event_for_action", event, keyboard_preset, 0x42, respect_keyboard_shift_raw))
	return false
