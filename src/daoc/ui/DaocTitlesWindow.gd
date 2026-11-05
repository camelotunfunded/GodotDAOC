extends CanvasLayer
class_name DaocTitlesWindow

## P1-109 — la fenetre « Player Statistics » du client d origine : ce que
## `/settitle` sans argument rapporte (0xC4 avec l octet 0 a 1,
## PacketLib1113/181.SendPlayerTitles) — les statistiques du joueur (kills,
## deathblows, RP par royaume...) puis la liste des titres qu il peut porter.
## Un CLIC sur un titre envoie `/settitle <index>` ; « Aucun titre » envoie
## un index hors liste, que DOL prend pour ClearTitle. Le serveur confirme par
## 0x4C sous-code 0x0B, qui remplit la ligne « Titre courant ».

signal title_chosen(index: int)

const ROW := 18

var last_titles: Dictionary = {}
var current_title := ""
var shown_count := 0
var choices_sent := 0
var _panel: PanelContainer = null
var _caption: Label = null
var _current: Label = null
var _lines: Label = null
var _rows: VBoxContainer = null


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "Titles"
	# A droite de la fenetre de delve (420, 120), pour que /settitle et /bonuses se lisent ensemble.
	_panel.position = Vector2(740, 80)
	_panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(_caption)
	_current = Label.new()
	_current.add_theme_font_size_override("font_size", 11)
	_current.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	box.add_child(_current)
	_lines = Label.new()
	_lines.add_theme_font_size_override("font_size", 11)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.custom_minimum_size = Vector2(304, 0)
	box.add_child(_lines)
	var header := Label.new()
	header.text = "Titres (clic = porter)"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(header)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	box.add_child(_rows)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)


func show_titles(titles: Dictionary) -> void:
	last_titles = titles.duplicate(true)
	shown_count += 1
	if _panel == null:
		return
	_caption.text = str(titles.get("caption", "Player Statistics"))
	var texts: Array[String] = []
	for line in titles.get("lines", []):
		texts.append(str(line))
	_lines.text = "\n".join(texts)
	_refresh_current()
	for child in _rows.get_children():
		child.queue_free()
	var entries: Array = titles.get("titles", [])
	for value in entries:
		var entry := value as Dictionary
		_rows.add_child(_make_row(int(entry.get("index", 0)), str(entry.get("text", ""))))
	_rows.add_child(_make_row(-1, "(Aucun titre)"))
	_panel.visible = true


func set_current_title(title: String) -> void:
	current_title = title
	_refresh_current()


func _refresh_current() -> void:
	if _current != null:
		_current.text = "Titre courant : %s" % (current_title if current_title != "" else "(aucun)")


func _make_row(index: int, text: String) -> Control:
	var row := Button.new()
	row.text = text
	row.flat = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, ROW)
	row.add_theme_font_size_override("font_size", 11)
	row.tooltip_text = "Clic : /settitle %d" % index if index >= 0 else "Clic : retirer le titre"
	row.pressed.connect(_on_title_pressed.bind(index))
	return row


func _on_title_pressed(index: int) -> void:
	choices_sent += 1
	title_chosen.emit(index)


func hide_titles() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_titles()


func _unhandled_input(event: InputEvent) -> void:
	if is_shown() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_titles()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "titles": (last_titles.get("titles", []) as Array).size(),
		"lines": (last_titles.get("lines", []) as Array).size(), "current_title": current_title, "choices_sent": choices_sent}
