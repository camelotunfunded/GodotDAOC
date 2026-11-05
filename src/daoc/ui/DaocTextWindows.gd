extends CanvasLayer
class_name DaocTextWindows

signal command_submitted(text: String)

## Les DEUX fenetres de texte du jeu d'origine : le CHAT (ce que disent les
## joueurs) et la CONSOLE (systeme, combat, sorts, butin, refus de l'arbitre).
##
## Demande du 2026-09-15 : le flux texte du serveur (0xAF) ne va pas dans une
## seule fenetre. `push_message` route selon `DaocOpenDaocStatusMessageCodec` ;
## `push_console_line` recoit aussi le journal de l'arbitre local, qui n'a plus
## de panneau a lui en ligne. Deux panneaux engine-drawn en bas de l'ecran :
## chat a gauche, console a droite, comme la disposition par defaut du client.

const MAX_LINES := 120
const PANEL_HEIGHT := 150.0

var chat_lines: int = 0
var console_lines: int = 0
var _root: Control = null
var _chat: RichTextLabel = null
var _console: RichTextLabel = null
var _chat_frame: PanelContainer = null
var _console_frame: PanelContainer = null
var _command_input: LineEdit = null


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.name = "TextWindowsRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_chat_frame = _make_frame("Chat", 0.0, 0.42)
	_chat = _chat_frame.get_meta("log") as RichTextLabel
	_command_input = LineEdit.new()
	_command_input.name = "ChatCommandInput"
	_command_input.placeholder_text = "Entrée : saisir une commande (ex. /release)"
	_command_input.visible = false
	_command_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_command_input.text_submitted.connect(_on_command_text_submitted)
	_command_input.gui_input.connect(_on_command_gui_input)
	(_chat_frame.get_meta("column") as VBoxContainer).add_child(_command_input)
	_console_frame = _make_frame("Console", 0.44, 0.86)
	_console = _console_frame.get_meta("log") as RichTextLabel


func push_message(message: Dictionary) -> void:
	var text := str(message.get("text", ""))
	if text.strip_edges() == "":
		return
	var kind := str(message.get("kind", ""))
	if bool(message.get("chat", false)) or str(message.get("window", "")) == "chat" and not bool(message.get("console", false)):
		_append(_chat, _colour_for(kind), text)
		chat_lines += 1
	else:
		_append(_console, _colour_for(kind), text)
		console_lines += 1


func push_console_line(text: String) -> void:
	if text.strip_edges() == "":
		return
	_append(_console, Color(0.78, 0.78, 0.72), text)
	console_lines += 1


func push_chat_line(text: String) -> void:
	_append(_chat, Color(0.9, 0.9, 0.9), text)
	chat_lines += 1


func get_debug_snapshot() -> Dictionary:
	return {"chat_lines": chat_lines, "console_lines": console_lines,
		"chat_visible": _chat_frame != null and _chat_frame.visible,
		"console_visible": _console_frame != null and _console_frame.visible,
		"command_input_active": _command_input != null and _command_input.visible}


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _command_input != null and not _command_input.visible:
			_command_input.visible = true
			_command_input.grab_focus()
			get_viewport().set_input_as_handled()


func _on_command_text_submitted(text: String) -> void:
	var command := text.strip_edges()
	_command_input.clear()
	_command_input.visible = false
	_command_input.release_focus()
	if command != "":
		command_submitted.emit(command)


func _on_command_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE:
		_command_input.clear()
		_command_input.visible = false
		_command_input.release_focus()
		get_viewport().set_input_as_handled()


func set_windows_visible(chat: bool, console: bool) -> void:
	if _chat_frame != null:
		_chat_frame.visible = chat
	if _console_frame != null:
		_console_frame.visible = console


func _append(label: RichTextLabel, colour: Color, text: String) -> void:
	if label == null:
		return
	var line := "[color=#%s]%s[/color]" % [colour.to_html(false), text.replace("[", "[lb]")]
	# Un journal borne : au-dela, les lignes les plus anciennes partent.
	# 2026-09-29 : `remove_paragraph(0)` plantait Godot 4.6 (signal 11, session
	# DOL locale) ; on garde les lignes en tampon et on reconstruit par paquets.
	var buffer: Array = label.get_meta("lines", []) as Array
	buffer.append(line)
	label.set_meta("lines", buffer)
	if buffer.size() > MAX_LINES + 40:
		buffer = buffer.slice(buffer.size() - MAX_LINES)
		label.set_meta("lines", buffer)
		label.clear()
		label.append_text("\n".join(buffer) + "\n")
	else:
		label.append_text(line + "\n")


func _colour_for(kind: String) -> Color:
	match kind:
		"say", "chat": return Color(0.92, 0.92, 0.92)
		"send": return Color(0.85, 0.55, 0.95)
		"group": return Color(0.55, 0.85, 1.0)
		"guild", "officer", "alliance": return Color(0.55, 0.95, 0.55)
		"broadcast", "lfg", "trade": return Color(1.0, 0.8, 0.45)
		"emote": return Color(0.95, 0.75, 0.95)
		"you_hit", "damage_add", "others_combat": return Color(1.0, 0.85, 0.5)
		"you_were_hit", "damaged", "you_died": return Color(1.0, 0.45, 0.45)
		"spell", "spell_pulse", "spell_expires", "spell_resisted": return Color(0.7, 0.75, 1.0)
		"loot", "merchant": return Color(0.95, 0.9, 0.5)
		"important", "screen_center", "screen_center_and_system": return Color(1.0, 0.95, 0.6)
		"missed", "skill": return Color(0.8, 0.8, 0.8)
		_: return Color(0.82, 0.82, 0.78)


func _make_frame(title: String, left: float, right: float) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = title + "Window"
	frame.anchor_left = left
	frame.anchor_right = right
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 8.0
	frame.offset_right = -8.0
	frame.offset_top = -PANEL_HEIGHT - 8.0
	frame.offset_bottom = -8.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.62)
	style.border_color = Color(0.55, 0.45, 0.25, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(6.0)
	frame.add_theme_stylebox_override("panel", style)
	_root.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.add_theme_font_size_override("font_size", 11)
	caption.modulate = Color(0.9, 0.78, 0.5)
	column.add_child(caption)
	var log := RichTextLabel.new()
	log.scroll_following = true
	log.scroll_active = true
	log.bbcode_enabled = true
	log.fit_content = false
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.add_theme_font_size_override("normal_font_size", 13)
	log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(log)
	frame.set_meta("log", log)
	frame.set_meta("column", column)
	return frame
