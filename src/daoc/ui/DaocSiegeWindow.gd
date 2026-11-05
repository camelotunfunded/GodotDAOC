extends CanvasLayer
class_name DaocSiegeWindow

## P1-109 — l interface d une arme de siege (0xF5 SiegeWeaponInterface,
## PacketLib1124) : le nom et l etat de l arme, l action en cours et son
## delai, les munitions chargees, et les boutons du client d origine —
## Armer, Viser, Tirer, Deplacer (vers la cible au sol), Reparer, Recycler,
## Relacher, Arreter. Chaque bouton envoie un 0xF5 client (action, munition)
## ; game.dll n en laisse partir qu un par seconde. Un 0xF5 de fermeture
## (octet 3 a 1) cache la fenetre.

signal siege_command_requested(action: int, ammo: int)

const BUTTONS := [["Armer", 2], ["Viser", 3], ["Tirer", 4], ["Deplacer", 5], ["Reparer", 6], ["Recycler", 7], ["Relacher", 8], ["Arreter", 9]]

var last_siege: Dictionary = {}
var shown_count := 0
var commands_sent := 0
var _panel: PanelContainer = null
var _title: Label = null
var _status: Label = null
var _ammo: Label = null
var _buttons: GridContainer = null
var _timer: Label = null
var _time_left := 0.0


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "Siege"
	_panel.position = Vector2(16, 420)
	_panel.custom_minimum_size = Vector2(260, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 10)
	box.add_child(_status)
	_timer = Label.new()
	_timer.add_theme_font_size_override("font_size", 10)
	_timer.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	box.add_child(_timer)
	_ammo = Label.new()
	_ammo.add_theme_font_size_override("font_size", 10)
	box.add_child(_ammo)
	_buttons = GridContainer.new()
	_buttons.columns = 4
	for pair in BUTTONS:
		var button := Button.new()
		button.text = str(pair[0])
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_on_button.bind(int(pair[1])))
		_buttons.add_child(button)
	box.add_child(_buttons)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left = maxf(0.0, _time_left - delta)
		if _timer != null:
			_timer.text = "%s : %.1f s" % [str(last_siege.get("action", "")), _time_left] if _time_left > 0.0 else ""


func apply_siege_interface(siege: Dictionary) -> void:
	last_siege = siege.duplicate(true)
	if bool(siege.get("close", false)):
		hide_siege()
		return
	shown_count += 1
	if _panel == null:
		return
	_title.text = str(siege.get("name", "Arme de siege"))
	_status.text = "Action : %s · %s · munition type %d" % [str(siege.get("action", "none")), "peut bouger" if bool(siege.get("can_move", false)) else "immobile", int(siege.get("ammo_type", 0))]
	_time_left = float(int(siege.get("time_msec", 0))) / 1000.0
	_timer.text = "%s : %.1f s" % [str(siege.get("action", "")), _time_left] if _time_left > 0.0 else ""
	var texts: Array[String] = []
	var ammo: Array = siege.get("ammo", [])
	for i in ammo.size():
		var item := ammo[i] as Dictionary
		if item.is_empty():
			texts.append("%d. (vide)" % (i + 1))
		else:
			texts.append("%d. %s" % [i + 1, str(item.get("name", ""))])
	_ammo.text = "Munitions : " + (", ".join(texts) if not texts.is_empty() else "aucune")
	_panel.visible = true


## `load(slot)` : charger la munition du logement (action 1).
func request_load(slot: int) -> void:
	_on_button(1, slot)


func _on_button(action: int, ammo: int = 0) -> void:
	commands_sent += 1
	siege_command_requested.emit(action, ammo)


func hide_siege() -> void:
	_time_left = 0.0
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "commands_sent": commands_sent, "name": str(last_siege.get("name", "")),
		"action": str(last_siege.get("action", "")), "ammo": (last_siege.get("ammo", []) as Array).size(), "time_left": _time_left}
