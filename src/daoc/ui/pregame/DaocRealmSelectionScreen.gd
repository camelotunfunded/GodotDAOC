extends Control
class_name DaocRealmSelectionScreen

signal realm_selected(realm_id: int)
signal realm_confirmed(realm_id: int)
signal quit_requested()

const VISUAL_ORDER := [1, 3, 2]

@export var debug_ui_labels_enabled := false

var model: Dictionary = {}
var selected_realm_id := 0
var hovered_realm_id := 0

@onready var visual_buttons := {1: $AlbionVisual, 3: $HiberniaVisual, 2: $MidgardVisual}
@onready var hitboxes := {1: $AlbionHitbox, 3: $HiberniaHitbox, 2: $MidgardHitbox}
@onready var descriptions := {1: $AlbionDescription, 3: $HiberniaDescription, 2: $MidgardDescription}
@onready var population_bonuses := {1: $AlbionLowPopBonus, 3: $HiberniaLowPopBonus, 2: $MidgardLowPopBonus}
@onready var selection_hint: Label = $SelectionHint
@onready var quit_button: TextureButton = $QuitButton


func _ready() -> void:
	for realm_id in VISUAL_ORDER:
		var hitbox := hitboxes[realm_id] as Button
		hitbox.pressed.connect(_on_realm_pressed.bind(realm_id))
		hitbox.mouse_entered.connect(_on_realm_hover.bind(realm_id, true))
		hitbox.mouse_exited.connect(_on_realm_hover.bind(realm_id, false))
	quit_button.pressed.connect(request_quit)
	selection_hint.visible = debug_ui_labels_enabled
	set_process_unhandled_key_input(true)
	_apply_descriptions()
	_refresh_visuals()


func set_model(value: Dictionary) -> void:
	model = value.duplicate(true)
	selected_realm_id = int((model.get("selected_realm", {}) as Dictionary).get("id", 0))
	_apply_descriptions()
	_refresh_visuals()


func visual_order() -> Array[int]:
	return VISUAL_ORDER.duplicate()


func select_realm(realm_id: int) -> void:
	if realm_id not in VISUAL_ORDER:
		return
	selected_realm_id = realm_id
	realm_selected.emit(realm_id)
	_refresh_visuals()


func confirm_selected() -> bool:
	if selected_realm_id not in VISUAL_ORDER:
		return false
	realm_confirmed.emit(selected_realm_id)
	return true


func request_quit() -> void:
	quit_requested.emit()


func set_population_bonus(realm_id: int, text: String) -> void:
	if not population_bonuses.has(realm_id):
		return
	var label := population_bonuses[realm_id] as Label
	label.text = text.strip_edges()
	label.visible = label.text != ""


func _on_realm_pressed(realm_id: int) -> void:
	if selected_realm_id == realm_id:
		confirm_selected()
	else:
		select_realm(realm_id)


func _on_realm_hover(realm_id: int, entered: bool) -> void:
	hovered_realm_id = realm_id if entered else (0 if hovered_realm_id == realm_id else hovered_realm_id)
	_refresh_visuals()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
		confirm_selected()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_1:
		select_realm(1)
	elif key.keycode == KEY_2:
		select_realm(2)
	elif key.keycode == KEY_3:
		select_realm(3)
	elif key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
		var index := VISUAL_ORDER.find(selected_realm_id)
		if index < 0:
			index = 0
		else:
			index = wrapi(index + (-1 if key.keycode == KEY_LEFT else 1), 0, VISUAL_ORDER.size())
		select_realm(VISUAL_ORDER[index])
	else:
		return
	get_viewport().set_input_as_handled()


func _apply_descriptions() -> void:
	if descriptions.is_empty():
		return
	var realms: Array = model.get("available_realms", []) as Array
	for raw in realms:
		var realm := raw as Dictionary
		var realm_id := int(realm.get("id", 0))
		if descriptions.has(realm_id):
			(descriptions[realm_id] as Label).text = str(realm.get("description", "Description originale indisponible."))


func _refresh_visuals() -> void:
	if visual_buttons.is_empty():
		return
	for realm_id in VISUAL_ORDER:
		var visual := visual_buttons[realm_id] as TextureButton
		visual.button_pressed = selected_realm_id == realm_id
		visual.modulate = Color.WHITE if hovered_realm_id == realm_id or selected_realm_id == realm_id else Color(0.76, 0.76, 0.76, 1.0)
		var desc := descriptions[realm_id] as Label
		desc.modulate = Color(1.0, 0.82, 0.38, 1.0) if selected_realm_id == realm_id else Color(0.72, 0.72, 0.68, 1.0)
	selection_hint.text = "Cliquez une seconde fois ou appuyez sur Entrée pour continuer" if selected_realm_id > 0 else "Choisissez votre royaume"
	selection_hint.visible = debug_ui_labels_enabled
