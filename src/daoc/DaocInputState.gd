extends RefCounted
class_name DaocInputState

## Etat d'input DAoC haut niveau.
## Le routeur remplit cette structure ; le motor, la caméra et les routeurs
## d'actions la consomment. Le motor ne lit pas Input.* directement.

var forward_axis: float = 0.0
var strafe_axis: float = 0.0
var turn_axis: float = 0.0

var walk_held: bool = false
var sprint_held: bool = false
var jump_held: bool = false
var down_held: bool = false
var strafe_toggle_held: bool = false
var run_lock_enabled: bool = false
var run_lock_pressed_frame: bool = false
var sprint_pressed_frame: bool = false

var mouse_left_held: bool = false
var mouse_right_held: bool = false
var mouse_middle_held: bool = false
var mouse_both_held: bool = false
var mouse_look_held: bool = false
var mouse_pan_held: bool = false
var mouse_forward_held: bool = false
var mouse_backward_held: bool = false
var mouse_legacy_move_used: bool = false

var raw_mouse_delta: Vector2 = Vector2.ZERO
var input_source_label: String = "fallback"
var keyboard_action_states: Dictionary = {}
var active_keyboard_action_ids: PackedInt32Array = PackedInt32Array()
var active_keyboard_action_names: PackedStringArray = PackedStringArray()
var keyboard_action_debug: String = ""
var last_action_debug: String = ""


func reset_axes() -> void:
	forward_axis = 0.0
	strafe_axis = 0.0
	turn_axis = 0.0
	walk_held = false
	sprint_held = false
	jump_held = false
	down_held = false
	strafe_toggle_held = false
	mouse_forward_held = false
	mouse_backward_held = false
	mouse_legacy_move_used = false
	keyboard_action_states.clear()
	active_keyboard_action_ids = PackedInt32Array()
	active_keyboard_action_names = PackedStringArray()
	keyboard_action_debug = ""
	input_source_label = "fallback"


func reset_frame_delta() -> void:
	raw_mouse_delta = Vector2.ZERO
	run_lock_pressed_frame = false
	sprint_pressed_frame = false


func has_horizontal_movement() -> bool:
	return absf(forward_axis) > 0.001 or absf(strafe_axis) > 0.001 or absf(turn_axis) > 0.001


func has_translation_movement() -> bool:
	return absf(forward_axis) > 0.001 or absf(strafe_axis) > 0.001


func set_mouse_buttons(left: bool, right: bool, middle: bool) -> void:
	mouse_left_held = left
	mouse_right_held = right
	mouse_middle_held = middle
	mouse_both_held = left and right


func set_keyboard_action_debug(states: Dictionary, active_ids: PackedInt32Array, active_names: PackedStringArray, debug_text: String) -> void:
	keyboard_action_states = states.duplicate(true)
	active_keyboard_action_ids = active_ids
	active_keyboard_action_names = active_names
	keyboard_action_debug = debug_text


func action_debug_string() -> String:
	if active_keyboard_action_names.size() == 0:
		return "actions=none"
	return "actions=" + ",".join(active_keyboard_action_names)


func get_locomotion_flags_snapshot() -> Dictionary:
	return {
		"forward_axis": forward_axis,
		"strafe_axis": strafe_axis,
		"turn_axis": turn_axis,
		"walk_held": walk_held,
		"sprint_held": sprint_held,
		"jump_held": jump_held,
		"down_held": down_held,
		"strafe_toggle_held": strafe_toggle_held,
		"run_lock_enabled": run_lock_enabled,
		"has_horizontal_movement": has_horizontal_movement(),
		"has_translation_movement": has_translation_movement(),
		"mouse_legacy_move_used": mouse_legacy_move_used,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"source": input_source_label,
		"forward_axis": forward_axis,
		"strafe_axis": strafe_axis,
		"turn_axis": turn_axis,
		"walk_held": walk_held,
		"sprint_held": sprint_held,
		"jump_held": jump_held,
		"down_held": down_held,
		"strafe_toggle_held": strafe_toggle_held,
		"run_lock_enabled": run_lock_enabled,
		"active_keyboard_action_ids": active_keyboard_action_ids,
		"active_keyboard_action_names": active_keyboard_action_names,
		"keyboard_action_debug": keyboard_action_debug,
		"mouse_legacy_move_used": mouse_legacy_move_used,
		"last_action_debug": last_action_debug,
		"locomotion_flags": get_locomotion_flags_snapshot(),
	}


func debug_string() -> String:
	return "src=%s f=%.1f s=%.1f t=%.1f walk=%s sprint=%s jump=%s down=%s ml=%s mr=%s both=%s mm=%s mlook=%s mpan=%s runlock=%s legacy=%s %s" % [
		input_source_label,
		forward_axis,
		strafe_axis,
		turn_axis,
		str(walk_held),
		str(sprint_held),
		str(jump_held),
		str(down_held),
		str(mouse_left_held),
		str(mouse_right_held),
		str(mouse_both_held),
		str(mouse_middle_held),
		str(mouse_look_held),
		str(mouse_pan_held),
		str(run_lock_enabled),
		str(mouse_legacy_move_used),
		action_debug_string()
	]
