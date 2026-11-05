extends CanvasLayer
class_name DaocTimerWindow

## P1-109 — la fenetre de compte a rebours du client d origine (0xF3
## TimerWindow, PacketLib168.SendTimerWindow) : un titre et des secondes qui
## descendent — le « Release Timer » de la mort, les delais de siege, les
## quetes chronometrees. Le serveur la ferme par un 0xF3 nul
## (SendCloseTimerWindow) ; le client la cache aussi a zero.

var last_timer: Dictionary = {}
var shown_count := 0
var seconds_left := 0.0
var _panel: PanelContainer = null
var _title: Label = null
var _value: Label = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "Timer"
	# Sous le centre de l ecran, comme l original.
	_panel.position = Vector2(420, 40)
	_panel.custom_minimum_size = Vector2(180, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(_title)
	_value = Label.new()
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.add_theme_font_size_override("font_size", 16)
	box.add_child(_value)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func _process(delta: float) -> void:
	if seconds_left <= 0.0:
		return
	seconds_left = maxf(0.0, seconds_left - delta)
	_refresh()
	if seconds_left <= 0.0:
		hide_timer()


func apply_timer(timer: Dictionary) -> void:
	last_timer = timer.duplicate(true)
	if bool(timer.get("close", false)) or int(timer.get("seconds", 0)) <= 0:
		hide_timer()
		return
	shown_count += 1
	seconds_left = float(int(timer.get("seconds", 0)))
	if _panel == null:
		return
	_title.text = str(timer.get("title", ""))
	_refresh()
	_panel.visible = true


func _refresh() -> void:
	if _value == null:
		return
	var total := int(ceil(seconds_left))
	_value.text = "%d:%02d" % [total / 60, total % 60]


func hide_timer() -> void:
	seconds_left = 0.0
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "title": str(last_timer.get("title", "")), "seconds_left": seconds_left}
