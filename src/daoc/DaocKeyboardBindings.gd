extends RefCounted
class_name DaocKeyboardBindings

## Lecteur keyboard.dat DAoC.
## Paquet 01 : parser neutre.
## Paquet 02 : helpers de lecture d'actions clavier, sans dépendre des touches hardcodées Godot.
## Les codes du fichier DAoC sont des scancodes DirectInput : on privilégie donc
## Input.is_physical_key_pressed() pour respecter les profils WASD/ESDF/MMO sur clavier localisé.

const ACTION_COUNT: int = 90
const UNBOUND_SENTINEL: int = 109

const ACTION_MOVE_FORWARD: int = 0
const ACTION_MOVE_BACKWARD: int = 1
const ACTION_TURN_LEFT: int = 2
const ACTION_TURN_RIGHT: int = 3
const ACTION_JUMP_UP: int = 4
const ACTION_DOWN: int = 5
const ACTION_STRAFE_TOGGLE: int = 6
const ACTION_WALK: int = 7
const ACTION_STRAFE_LEFT: int = 8
const ACTION_STRAFE_RIGHT: int = 9
const ACTION_MOVE_FORWARD_ALIAS: int = 0x14
const ACTION_MOVE_BACKWARD_ALIAS: int = 0x21
const ACTION_MOUSE_LOOK: int = 0x27
const ACTION_RUNLOCK: int = 0x2A
const ACTION_SPRINT: int = 0x42
const ACTION_MOUSE_PAN: int = 0x4E
const ACTION_RUNLOCK_2: int = 0x53

const DEFAULT_SECTIONS = [
	"fpsdefault",
	"rpgdefault",
	"mmodefault",
]

const ACTION_NAMES: Dictionary = {
	0: "Move Forward",
	1: "Move Backward",
	2: "Turn Left",
	3: "Turn Right",
	4: "Jump/Up",
	5: "Down",
	6: "Strafe Toggle",
	7: "Walk",
	8: "Strafe Left",
	9: "Strafe Right",
	10: "Look Left",
	11: "Look Right",
	12: "Look Up",
	13: "Look Down",
	14: "Camera Reset",
	18: "Mouselook Toggle",
	19: "Toggle Names",
	20: "Move Forward Alias",
	21: "Get Item",
	22: "Torch",
	23: "Chat",
	24: "Nearest Enemy",
	25: "Nearest Friend",
	26: "Nearest Object",
	27: "Attack Mode",
	28: "Show Spells",
	29: "Sell",
	30: "Show Stats",
	31: "Show Inventory",
	32: "Show Group",
	33: "Move Backward Alias",
	34: "Use Item",
	35: "Last Attacker",
	36: "Reply",
	37: "Chat Logging",
	38: "Destroy Item",
	39: "Mouse Look",
	40: "Show Skills",
	41: "Show Combat",
	42: "Run Lock",
	43: "Consider",
	44: "Ground Target",
	45: "Target Group #1",
	46: "Target Group #2",
	47: "Target Group #3",
	48: "Target Group #4",
	49: "Target Group #5",
	50: "Target Group #6",
	51: "Target Group #7",
	52: "Target Group #8",
	53: "Chat Page Up",
	54: "Chat Page Down",
	57: "Sit/Stand",
	58: "Perf. Meter",
	59: "Compass",
	60: "Information/Delve",
	61: "Camera Pan",
	62: "Follow",
	63: "Stick",
	64: "Face",
	65: "Craft/Salvage",
	66: "Sprint",
	67: "Command Window",
	68: "Right Hand Weapon",
	69: "Two Handed Weapon",
	70: "Ranged Weapon",
	71: "Use Item 2nd",
	72: "Nearest Loot",
	78: "Mouse Pan",
	79: "Map Window",
	80: "Toggle Interface",
	81: "Realm War Map",
	82: "Quest Journal",
	83: "Run Lock 2",
	84: "Show Character Info",
	85: "Take Screenshot",
	86: "Camera Toggle",
}

## Noms DirectInput classiques observés dans keyboard.dat.
const DI_NAMES: Dictionary = {
	0: "UNBOUND",
	1: "Escape",
	2: "1",
	3: "2",
	4: "3",
	5: "4",
	6: "5",
	7: "6",
	8: "7",
	9: "8",
	10: "9",
	11: "0",
	12: "Minus",
	13: "Equals",
	14: "Backspace",
	15: "Tab",
	16: "Q",
	17: "W",
	18: "E",
	19: "R",
	20: "T",
	21: "Y",
	22: "U",
	23: "I",
	24: "O",
	25: "P",
	26: "LeftBracket",
	27: "RightBracket",
	28: "Enter",
	29: "LeftCtrl",
	30: "A",
	31: "S",
	32: "D",
	33: "F",
	34: "G",
	35: "H",
	36: "J",
	37: "K",
	38: "L",
	39: "Semicolon",
	40: "Apostrophe",
	41: "Grave",
	42: "LeftShift",
	43: "Backslash",
	44: "Z",
	45: "X",
	46: "C",
	47: "V",
	48: "B",
	49: "N",
	50: "M",
	51: "Comma",
	52: "Period",
	53: "Slash",
	54: "RightShift",
	56: "LeftAlt",
	57: "Space",
	59: "F1",
	60: "F2",
	61: "F3",
	62: "F4",
	63: "F5",
	64: "F6",
	65: "F7",
	66: "F8",
	67: "F9",
	68: "F10",
	69: "NumLock",
	70: "ScrollLock",
	72: "Numpad8/Up",
	73: "Numpad9/PageUp",
	74: "NumpadMinus",
	75: "Numpad4/Left",
	76: "Numpad5",
	77: "Numpad6/Right",
	78: "NumpadPlus",
	79: "Numpad1/End",
	80: "Numpad2/Down",
	81: "Numpad3/PageDown",
	82: "Numpad0/Insert",
	83: "NumpadDecimal/Delete",
	87: "F11",
	88: "F12",
	100: "F13",
	101: "F14",
	109: "UNBOUND_SENTINEL",
	110: "Intl/ABNT_C2",
}

const DI_TO_GODOT_KEY: Dictionary = {
	1: KEY_ESCAPE,
	2: KEY_1,
	3: KEY_2,
	4: KEY_3,
	5: KEY_4,
	6: KEY_5,
	7: KEY_6,
	8: KEY_7,
	9: KEY_8,
	10: KEY_9,
	11: KEY_0,
	14: KEY_BACKSPACE,
	15: KEY_TAB,
	16: KEY_Q,
	17: KEY_W,
	18: KEY_E,
	19: KEY_R,
	20: KEY_T,
	21: KEY_Y,
	22: KEY_U,
	23: KEY_I,
	24: KEY_O,
	25: KEY_P,
	28: KEY_ENTER,
	29: KEY_CTRL,
	30: KEY_A,
	31: KEY_S,
	32: KEY_D,
	33: KEY_F,
	34: KEY_G,
	35: KEY_H,
	36: KEY_J,
	37: KEY_K,
	38: KEY_L,
	44: KEY_Z,
	45: KEY_X,
	46: KEY_C,
	47: KEY_V,
	48: KEY_B,
	49: KEY_N,
	50: KEY_M,
	57: KEY_SPACE,
	59: KEY_F1,
	60: KEY_F2,
	61: KEY_F3,
	62: KEY_F4,
	63: KEY_F5,
	64: KEY_F6,
	65: KEY_F7,
	66: KEY_F8,
	67: KEY_F9,
	68: KEY_F10,
	69: KEY_NUMLOCK,
	70: KEY_SCROLLLOCK,
	72: KEY_KP_8,
	73: KEY_KP_9,
	75: KEY_KP_4,
	76: KEY_KP_5,
	77: KEY_KP_6,
	79: KEY_KP_1,
	80: KEY_KP_2,
	81: KEY_KP_3,
	82: KEY_KP_0,
	87: KEY_F11,
	88: KEY_F12,
}

var sections: Dictionary = {}
var active_section: String = "rpgdefault"
var source_path: String = ""
var loaded: bool = false
var last_error: String = ""


func load_from_daoc_root(daoc_root: String) -> bool:
	sections.clear()
	loaded = false
	last_error = ""
	source_path = _resolve_keyboard_dat_path(daoc_root)
	if source_path == "":
		last_error = "keyboard.dat introuvable"
		return false

	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		last_error = "impossible d'ouvrir keyboard.dat: %s" % source_path
		return false

	var parsed := _parse_ini_text(file.get_as_text())
	for section_name in DEFAULT_SECTIONS:
		if parsed.has(section_name):
			sections[section_name] = _parse_keyboard_section(section_name, parsed[section_name] as Dictionary)

	loaded = sections.size() > 0
	if not loaded:
		last_error = "aucune section keyboard.dat reconnue dans %s" % source_path
		return false
	return true


func _resolve_keyboard_dat_path(daoc_root: String) -> String:
	var candidates: PackedStringArray = PackedStringArray()
	var root := daoc_root.strip_edges()
	if root != "":
		var normalized_root := root.replace("\\", "/")
		candidates.append(normalized_root + ("keyboard.dat" if normalized_root.ends_with("/") else "/keyboard.dat"))

	var project_root := str(ProjectSettings.get_setting("daoc/client_root", "")).strip_edges()
	if project_root != "" and project_root != root:
		var normalized_project_root := project_root.replace("\\", "/")
		candidates.append(normalized_project_root + ("keyboard.dat" if normalized_project_root.ends_with("/") else "/keyboard.dat"))

	candidates.append("res://data/keyboard.dat")

	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _parse_ini_text(text: String) -> Dictionary:
	var result: Dictionary = {}
	var current_section := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			if not result.has(current_section):
				result[current_section] = {}
			continue
		var eq := line.find("=")
		if eq < 0 or current_section == "":
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		var section: Dictionary = result[current_section] as Dictionary
		section[key] = value
		section[key.to_lower()] = value
	return result


func _parse_keyboard_section(section_name: String, data: Dictionary) -> Dictionary:
	var parsed: Dictionary = {
		"name": section_name,
		"flags": _read_global_flags(data),
		"actions": {},
	}
	var actions: Dictionary = parsed["actions"] as Dictionary
	for action_id in range(ACTION_COUNT):
		actions[action_id] = _parse_action_binding(data, action_id)
	return parsed


func _parse_action_binding(section: Dictionary, action_id: int) -> Dictionary:
	var suffix := "%02d" % action_id
	var di_key := _read_int_field(section, "key" + suffix, 0)
	var shift_raw := _read_int_field(section, "shift" + suffix, 0)
	var godot_key := _directinput_to_godot_key(di_key)
	return {
		"action_id": action_id,
		"action_name": str(ACTION_NAMES.get(action_id, "Action %02d" % action_id)),
		"key_raw": di_key,
		"shift_raw": shift_raw,
		"godot_key": godot_key,
		"key_name": str(DI_NAMES.get(di_key, "DIK_%d" % di_key)),
		"unbound": is_unbound_key(di_key),
	}


func _read_int_field(section: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = section.get(key, section.get(key.to_lower(), default_value))
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	return default_value


func _read_global_flags(section: Dictionary) -> Dictionary:
	return {
		"AltModifier": _read_int_field(section, "AltModifier", -1),
		"CtrlModifier": _read_int_field(section, "CtrlModifier", -1),
		"ModifiersBreakMoveKeys": _read_int_field(section, "ModifiersBreakMoveKeys", -1),
		"ForwardBreaksRunlock": _read_int_field(section, "ForwardBreaksRunlock", -1),
	}


func _directinput_to_godot_key(di_key: int) -> int:
	if is_unbound_key(di_key):
		return KEY_NONE
	return int(DI_TO_GODOT_KEY.get(di_key, KEY_NONE))


func is_unbound_key(di_key: int) -> bool:
	return di_key == 0 or di_key == UNBOUND_SENTINEL


func has_preset(section_name: String) -> bool:
	return loaded and sections.has(section_name.strip_edges().to_lower())


func get_preset_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in sections.keys():
		out.append(str(k))
	return out


func get_action_binding(section_name: String, action_id: int) -> Dictionary:
	var normalized := section_name.strip_edges().to_lower()
	if not loaded or not sections.has(normalized):
		return {}
	var section: Dictionary = sections[normalized] as Dictionary
	var actions: Dictionary = section.get("actions", {}) as Dictionary
	return actions.get(action_id, {}) as Dictionary




func get_action_display_name(action_id: int) -> String:
	return str(ACTION_NAMES.get(action_id, "Action %02d" % action_id))


func is_action_bound(section_name: String, action_id: int) -> bool:
	var binding := get_action_binding(section_name, action_id)
	return not binding.is_empty() and not bool(binding.get("unbound", true)) and int(binding.get("godot_key", KEY_NONE)) != KEY_NONE


func get_action_debug_record(section_name: String, action_id: int, respect_shift_raw: bool = false, sample_pressed: bool = false) -> Dictionary:
	var binding := get_action_binding(section_name, action_id)
	var pressed := false
	if sample_pressed:
		pressed = is_action_pressed(section_name, action_id, respect_shift_raw)
	if binding.is_empty():
		return {
			"action_id": action_id,
			"action_name": get_action_display_name(action_id),
			"bound": false,
			"pressed": pressed,
			"missing": true,
		}
	return {
		"action_id": action_id,
		"action_name": str(binding.get("action_name", get_action_display_name(action_id))),
		"bound": is_action_bound(section_name, action_id),
		"pressed": pressed,
		"key_raw": int(binding.get("key_raw", 0)),
		"shift_raw": int(binding.get("shift_raw", 0)),
		"godot_key": int(binding.get("godot_key", KEY_NONE)),
		"key_name": str(binding.get("key_name", "?")),
		"unbound": bool(binding.get("unbound", true)),
	}


func get_actions_debug_snapshot(section_name: String, action_ids: PackedInt32Array, respect_shift_raw: bool = false, sample_pressed: bool = false) -> Dictionary:
	var normalized := section_name.strip_edges().to_lower()
	var records: Array = []
	var bound_count := 0
	var unbound_count := 0
	var pressed_count := 0
	for action_id in action_ids:
		var rec := get_action_debug_record(normalized, int(action_id), respect_shift_raw, sample_pressed)
		records.append(rec)
		if bool(rec.get("bound", false)):
			bound_count += 1
		else:
			unbound_count += 1
		if bool(rec.get("pressed", false)):
			pressed_count += 1
	return {
		"loaded": loaded,
		"source_path": source_path,
		"preset": normalized,
		"preset_exists": has_preset(normalized),
		"action_count": records.size(),
		"bound_count": bound_count,
		"unbound_count": unbound_count,
		"pressed_count": pressed_count,
		"actions": records,
	}

func is_action_pressed(section_name: String, action_id: int, respect_shift_raw: bool = false) -> bool:
	var binding := get_action_binding(section_name, action_id)
	if binding.is_empty() or bool(binding.get("unbound", true)):
		return false
	var key := int(binding.get("godot_key", KEY_NONE))
	if key == KEY_NONE:
		return false
	if respect_shift_raw and not _shift_raw_matches(int(binding.get("shift_raw", 0))):
		return false
	if Input.has_method("is_physical_key_pressed"):
		return Input.is_physical_key_pressed(key)
	return Input.is_key_pressed(key)


func is_any_action_pressed(section_name: String, action_ids: PackedInt32Array, respect_shift_raw: bool = false) -> bool:
	for action_id in action_ids:
		if is_action_pressed(section_name, action_id, respect_shift_raw):
			return true
	return false


func is_event_for_action(event: InputEventKey, section_name: String, action_id: int, respect_shift_raw: bool = false) -> bool:
	var binding := get_action_binding(section_name, action_id)
	if binding.is_empty() or bool(binding.get("unbound", true)):
		return false
	var key := int(binding.get("godot_key", KEY_NONE))
	if key == KEY_NONE:
		return false
	if respect_shift_raw and not _shift_raw_matches_event(int(binding.get("shift_raw", 0)), event):
		return false
	if event.physical_keycode != 0:
		return event.physical_keycode == key
	return event.keycode == key


func is_event_for_any_action(event: InputEventKey, section_name: String, action_ids: PackedInt32Array, respect_shift_raw: bool = false) -> bool:
	for action_id in action_ids:
		if is_event_for_action(event, section_name, action_id, respect_shift_raw):
			return true
	return false


func _shift_raw_matches(shift_raw: int) -> bool:
	## Encodage exact encore en observation. Mapping provisoire classique :
	## 1=Shift, 2=Ctrl, 4=Alt. Les paquets actuels ne l'activent pas par défaut.
	if shift_raw == 0:
		return true
	if (shift_raw & 1) != 0 and not Input.is_key_pressed(KEY_SHIFT):
		return false
	if (shift_raw & 2) != 0 and not Input.is_key_pressed(KEY_CTRL):
		return false
	if (shift_raw & 4) != 0 and not Input.is_key_pressed(KEY_ALT):
		return false
	return true


func _shift_raw_matches_event(shift_raw: int, event: InputEventKey) -> bool:
	if shift_raw == 0:
		return true
	if (shift_raw & 1) != 0 and not event.shift_pressed:
		return false
	if (shift_raw & 2) != 0 and not event.ctrl_pressed:
		return false
	if (shift_raw & 4) != 0 and not event.alt_pressed:
		return false
	return true


func debug_dump_preset(section_name: String) -> String:
	var normalized := section_name.strip_edges().to_lower()
	if not loaded:
		return "keyboard.dat non chargé: %s" % last_error
	if not sections.has(normalized):
		return "preset keyboard.dat introuvable: %s ; presets=%s" % [section_name, str(sections.keys())]

	var section: Dictionary = sections[normalized] as Dictionary
	var flags: Dictionary = section["flags"] as Dictionary
	var actions: Dictionary = section["actions"] as Dictionary
	var lines: PackedStringArray = PackedStringArray()
	lines.append("keyboard.dat source=%s" % source_path)
	lines.append("[%s] actions=%d flags=%s" % [normalized, actions.size(), str(flags)])
	for action_id in range(ACTION_COUNT):
		var binding: Dictionary = actions[action_id] as Dictionary
		var bound_label := "UNBOUND" if bool(binding["unbound"]) else str(binding["key_name"])
		lines.append("%02d %-24s shift=%d key=%d %-22s godot_key=%d" % [
			action_id,
			str(binding["action_name"]),
			int(binding["shift_raw"]),
			int(binding["key_raw"]),
			bound_label,
			int(binding["godot_key"]),
		])
	return "\n".join(lines)


func debug_compact_actions(section_name: String, action_ids: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for action_id in action_ids:
		var b := get_action_binding(section_name, action_id)
		if b.is_empty():
			parts.append("%02d:%s=?" % [action_id, get_action_display_name(int(action_id))])
		else:
			var key_label := "UNBOUND" if bool(b.get("unbound", true)) else str(b.get("key_name", "?"))
			parts.append("%02d:%s=%s" % [action_id, get_action_display_name(int(action_id)), key_label])
	return " ".join(parts)
