extends CanvasLayer
class_name DaocMasterLevelWindow

## P1-109 — la fenetre des Master Levels (0x13 MasterLevelWindow,
## PacketLib190) : la barre d experience ML (bleue), la barre des etapes
## (rouge), le ML courant et les dix etapes du ML affiche, avec leur
## description (DOL : « Complete » / « Uncomplete » par etape). Les fleches
## demandent un autre ML au serveur par le dialogue 0x19 (0x82 dont l octet
## de reponse est le ML) ; il repond par un nouveau 0x13.

signal master_level_requested(master_level: int)

const MAX_MASTER_LEVEL := 10

var last_window: Dictionary = {}
var shown_count := 0
var requests_sent := 0
var _panel: PanelContainer = null
var _title: Label = null
var _experience: ProgressBar = null
var _steps_bar: ProgressBar = null
var _steps: Label = null
var _previous: Button = null
var _next: Button = null


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "MasterLevels"
	# Sous le compte a rebours, a gauche du delve.
	_panel.position = Vector2(60, 300)
	_panel.custom_minimum_size = Vector2(340, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var header := HBoxContainer.new()
	_previous = Button.new()
	_previous.text = "<"
	_previous.pressed.connect(func(): _request(int(last_window.get("displayed_level", 1)) - 1))
	header.add_child(_previous)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	header.add_child(_title)
	_next = Button.new()
	_next.text = ">"
	_next.pressed.connect(func(): _request(int(last_window.get("displayed_level", 1)) + 1))
	header.add_child(_next)
	box.add_child(header)
	_experience = ProgressBar.new()
	_experience.custom_minimum_size = Vector2(320, 14)
	_experience.show_percentage = true
	_experience.modulate = Color(0.6, 0.7, 1.0)
	box.add_child(_experience)
	_steps_bar = ProgressBar.new()
	_steps_bar.custom_minimum_size = Vector2(320, 14)
	_steps_bar.show_percentage = true
	_steps_bar.modulate = Color(1.0, 0.6, 0.6)
	box.add_child(_steps_bar)
	_steps = Label.new()
	_steps.add_theme_font_size_override("font_size", 11)
	_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_steps.custom_minimum_size = Vector2(320, 0)
	box.add_child(_steps)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)


func show_window(window: Dictionary) -> void:
	last_window = window.duplicate(true)
	shown_count += 1
	if _panel == null:
		return
	var requested := int(window.get("requested_level", 0))
	var current := int(window.get("current_level", 0))
	# DOL : un ML demande a 0 montre le ML courant (ou 1 a ML 0).
	var displayed := requested if requested > 0 else maxi(1, current)
	last_window["displayed_level"] = displayed
	_title.text = "Master Level %d  (ML courant : %d)" % [displayed, current]
	_experience.value = clampf(float(window.get("experience_percent", 0)), 0.0, 100.0)
	_steps_bar.value = clampf(float(window.get("steps_percent", 0)), 0.0, 100.0)
	var texts: Array[String] = []
	for value in window.get("steps", []):
		var step := value as Dictionary
		var description := str(step.get("description", ""))
		if description != "":
			texts.append("%2d. %s" % [int(step.get("step", 0)), description])
	_steps.text = "\n".join(texts) if not texts.is_empty() else "(aucune etape decrite par le serveur)"
	_previous.disabled = displayed <= 1
	_next.disabled = displayed >= MAX_MASTER_LEVEL
	_panel.visible = true


func _request(master_level: int) -> void:
	if master_level < 1 or master_level > MAX_MASTER_LEVEL:
		return
	requests_sent += 1
	master_level_requested.emit(master_level)


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_window()


func _unhandled_input(event: InputEvent) -> void:
	if is_shown() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_window()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "requests_sent": requests_sent,
		"current_level": int(last_window.get("current_level", 0)), "requested_level": int(last_window.get("requested_level", 0)),
		"steps": (last_window.get("steps", []) as Array).size()}
