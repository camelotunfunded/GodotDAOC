extends CanvasLayer
class_name DaocPetWindow

## P1-108 — la fenetre du pet du client d origine : le nom « [niveau] nom »
## du familier, sa vie, et les neuf boutons de PetWindowHandler (DOL) —
## Agressif / Defensif / Passif, Suivre / Rester / Aller / Venir, Attaquer /
## Relacher. Le serveur l ouvre par un 0x88 (action 2), la met a jour (1 :
## l etat d agressivite et de deplacement en surbrillance) et la ferme (0).
## Chaque bouton envoie un 0x8A (`command_requested(aggro, walk, command)`)
## et n change RIEN localement : la surbrillance suit le 0x88 de mise a jour
## qui revient. Les commandes texte du client d origine passent par ici aussi
## (`/pet`… n existe pas dans DOL : ce sont ces boutons).

signal command_requested(aggro: int, walk: int, command: int)

const AGGRO_BUTTONS := [["Agressif", 1], ["Defensif", 2], ["Passif", 3]]
const WALK_BUTTONS := [["Suivre", 1], ["Rester", 2], ["Aller", 3], ["Venir", 4]]
const COMMAND_BUTTONS := [["Attaquer", 1], ["Relacher", 2]]

var pet: Dictionary = {}
var commands_sent := 0
var _panel: PanelContainer = null
var _name: Label = null
var _health: ProgressBar = null
var _aggro_buttons: Array = []
var _walk_buttons: Array = []
var icon_atlas: RefCounted = null
var _icons: HBoxContainer = null
## (object_id) -> {name, level, health_percent} ; fourni par le monde.
var entity_lookup: Callable = Callable()


func _ready() -> void:
	layer = 21
	_panel = PanelContainer.new()
	_panel.name = "Pet"
	_panel.position = Vector2(16, 400)
	_panel.custom_minimum_size = Vector2(190, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_name = Label.new()
	_name.text = "Pet"
	_name.add_theme_font_size_override("font_size", 11)
	_name.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	# P1-129 : le nom sert de poignee — la fenetre se deplace comme celles du
	# client (clic gauche maintenu), position gardee pour la session.
	_name.mouse_filter = Control.MOUSE_FILTER_STOP
	_name.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_name.tooltip_text = "Glisser pour deplacer"
	_name.gui_input.connect(_on_grip_input)
	box.add_child(_name)
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(0, 10)
	_health.show_percentage = false
	_health.max_value = 100
	_health.value = 100
	box.add_child(_health)
	_icons = HBoxContainer.new()
	box.add_child(_icons)
	_aggro_buttons = _make_button_row(box, AGGRO_BUTTONS, "aggro")
	_walk_buttons = _make_button_row(box, WALK_BUTTONS, "walk")
	_make_button_row(box, COMMAND_BUTTONS, "command")
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func _make_button_row(parent: Control, defs: Array, kind: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var buttons: Array = []
	for def in defs:
		var button := Button.new()
		button.text = str(def[0])
		button.add_theme_font_size_override("font_size", 9)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = kind != "command"
		button.pressed.connect(_on_button.bind(kind, int(def[1])))
		row.add_child(button)
		buttons.append(button)
	parent.add_child(row)
	return buttons


func _on_button(kind: String, code: int) -> void:
	commands_sent += 1
	match kind:
		"aggro":
			command_requested.emit(code, 0, 0)
		"walk":
			command_requested.emit(0, code, 0)
		_:
			command_requested.emit(0, 0, code)
	# La surbrillance suit le serveur (0x88 update), pas le clic.
	_refresh_toggles()


func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas


## Un 0x88 decode : action open / update / close.
func apply_pet_window(value: Dictionary) -> void:
	var action := str(value.get("action", ""))
	if action == "close" or int(value.get("pet_id", 0)) <= 0:
		pet = {}
		if _panel != null:
			_panel.visible = false
		return
	pet = value.duplicate(true)
	if _panel == null:
		return
	_panel.visible = true
	refresh_entity()
	_refresh_toggles()
	for child in _icons.get_children():
		child.queue_free()
	for icon_id in value.get("icons", []) as Array:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		if icon_atlas != null and icon_atlas.has_method("texture_for"):
			icon.texture = icon_atlas.call("texture_for", int(icon_id), "spell") as Texture2D
		_icons.add_child(icon)


## Nom, niveau et vie viennent de l entite du monde (0xDA / 0xA9) : le 0x88
## ne porte que l identifiant. A rappeler quand l entite change.
func refresh_entity() -> void:
	if pet.is_empty() or _name == null:
		return
	var info: Dictionary = {}
	if entity_lookup.is_valid():
		info = entity_lookup.call(int(pet.get("pet_id", 0))) as Dictionary
	if info.is_empty():
		_name.text = "Pet #%d" % int(pet.get("pet_id", 0))
		return
	_name.text = "[%d] %s" % [int(info.get("level", 0)), str(info.get("name", ""))]
	_health.value = float(info.get("health_percent", 100))


func _refresh_toggles() -> void:
	for i in range(_aggro_buttons.size()):
		(_aggro_buttons[i] as Button).set_pressed_no_signal(int(pet.get("aggro_code", 0)) == int(AGGRO_BUTTONS[i][1]))
	for i in range(_walk_buttons.size()):
		(_walk_buttons[i] as Button).set_pressed_no_signal(int(pet.get("walk_code", 0)) == int(WALK_BUTTONS[i][1]))


func is_shown() -> bool:
	return _panel != null and _panel.visible


var _refresh_clock := 0.0


func _process(delta: float) -> void:
	# La vie du pet suit l entite du monde, relue deux fois par seconde.
	if not is_shown():
		return
	_refresh_clock += delta
	if _refresh_clock >= 0.5:
		_refresh_clock = 0.0
		refresh_entity()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "pet_id": int(pet.get("pet_id", 0)), "aggro": str(pet.get("aggro", "")), "walk": str(pet.get("walk", "")),
		"name": _name.text if _name != null else "", "commands_sent": commands_sent}


var _dragging := false
var _drag_offset := Vector2.ZERO


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		_drag_offset = _panel.position - (event as InputEventMouseButton).global_position
	elif event is InputEventMouseMotion and _dragging:
		var viewport_size := _panel.get_viewport_rect().size
		var target := (event as InputEventMouseMotion).global_position + _drag_offset
		_panel.position = target.clamp(Vector2.ZERO, viewport_size - _panel.size)


func window_position() -> Vector2:
	return _panel.position if _panel != null else Vector2.ZERO
