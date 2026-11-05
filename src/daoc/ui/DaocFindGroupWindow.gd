extends CanvasLayer
class_name DaocFindGroupWindow

## P1-110 — la fenêtre « cherche groupe » du client d origine : la liste des
## joueurs LFG (0x86 FindGroupUpdate, PacketLib176 — chefs de groupe d abord,
## solos ensuite, niveau, classe, zone), le bouton « Rafraîchir » (0x85) et la
## case « Je cherche un groupe » (0x84). `/lfg <message>` reste une commande
## DOL (texte). Le client d origine n a pas d autre voie pour rejoindre : on
## /invite ou on /send.

signal refresh_requested
signal flag_changed(flag: bool)

var players: Array = []
var shown_count := 0
var refreshes_requested := 0
var flags_sent := 0
var _panel: PanelContainer = null
var _rows: VBoxContainer = null
var _flag: CheckBox = null


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "FindGroup"
	_panel.position = Vector2(60, 120)
	_panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Cherche groupe"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	head.add_child(title)
	var refresh := Button.new()
	refresh.text = "Rafraichir"
	refresh.add_theme_font_size_override("font_size", 10)
	refresh.pressed.connect(_on_refresh)
	head.add_child(refresh)
	box.add_child(head)
	_flag = CheckBox.new()
	_flag.text = "Je cherche un groupe (0x84)"
	_flag.add_theme_font_size_override("font_size", 11)
	_flag.toggled.connect(_on_flag)
	box.add_child(_flag)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)
	_rebuild()


func set_players(list: Array) -> void:
	players = list.duplicate(true)
	_rebuild()


func show_window() -> void:
	shown_count += 1
	_rebuild()
	if _panel != null:
		_panel.visible = true


func toggle() -> void:
	if _panel != null and _panel.visible:
		hide_window()
	else:
		show_window()


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _rebuild() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	if players.is_empty():
		var empty := Label.new()
		empty.text = "(personne ne cherche de groupe)"
		empty.add_theme_font_size_override("font_size", 11)
		_rows.add_child(empty)
		return
	for value in players:
		var p := value as Dictionary
		var line := Label.new()
		line.text = "%s%s  niv %d  %s  zone %d" % ["[chef] " if bool(p.get("leader", false)) else "", str(p.get("name", "")), int(p.get("level", 0)), str(p.get("class_short", "")), int(p.get("zone_skin_id", 0))]
		line.add_theme_font_size_override("font_size", 11)
		line.tooltip_text = "/invite %s   ·   /send %s <message>" % [str(p.get("name", "")), str(p.get("name", ""))]
		_rows.add_child(line)


func _on_refresh() -> void:
	refreshes_requested += 1
	refresh_requested.emit()


func _on_flag(pressed: bool) -> void:
	flags_sent += 1
	flag_changed.emit(pressed)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_window()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "players": players.size(), "refreshes_requested": refreshes_requested, "flags_sent": flags_sent}
