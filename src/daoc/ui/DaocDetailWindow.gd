extends CanvasLayer
class_name DaocDetailWindow

## P1-102 — la fenetre de texte du delve (0xC4 DetailWindow) : un titre et
## des lignes, telles que le serveur les ecrit. Clic droit ou Echap la ferme.

var _panel: PanelContainer = null
var _title: Label = null
var _body: Label = null
var last_detail: Dictionary = {}
var shown_count := 0


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "Detail"
	_panel.position = Vector2(420, 120)
	_panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 11)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(284, 0)
	box.add_child(_title)
	box.add_child(_body)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_gui_input)
	_panel.visible = false
	add_child(_panel)


func show_detail(detail: Dictionary) -> void:
	last_detail = detail.duplicate(true)
	shown_count += 1
	if _panel == null:
		return
	_title.text = str(detail.get("caption", ""))
	var lines: Array = detail.get("lines", [])
	var texts: Array[String] = []
	for line in lines:
		texts.append(str(line))
	_body.text = "\n".join(texts)
	_panel.visible = true


func hide_detail() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_detail()


func _unhandled_input(event: InputEvent) -> void:
	if is_shown() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_detail()
