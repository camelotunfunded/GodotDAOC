extends Control
class_name DaocCharacterSelectionScreen

signal character_selected(slot_index: int, character_data: Dictionary)
signal play_requested(slot_index: int, character_data: Dictionary)
signal create_requested(slot_index: int)
signal delete_requested(slot_index: int, character_data: Dictionary)
signal customize_requested(slot_index: int, character_data: Dictionary)
signal options_requested()
signal quit_requested()
signal back_requested()

@export var debug_ui_labels_enabled := false

var model: Dictionary = {}
var selected_slot_index := -1
var selected_data: Dictionary = {}
var emitted_intents: Array[String] = []
var network_packet_count := 0

@onready var backdrop: DaocCharacterBackdrop = $CharacterBackdrop
@onready var preview: DaocCharacterPreview = $CharacterPreview
@onready var slots_root: Control = $Slots
@onready var play_button: TextureButton = $PlayButton
@onready var play_label: Label = $PlayLabel
@onready var customize_button: TextureButton = $CustomizeButton
@onready var customize_label: Label = $CustomizeLabel
@onready var delete_button: TextureButton = $DeleteButton
@onready var delete_label: Label = $DeleteLabel
@onready var back_button: TextureButton = $BackButton
@onready var options_button: TextureButton = $OptionsButton
@onready var quit_button: TextureButton = $QuitButton
@onready var detail_label: Label = $DetailLabel
@onready var source_label: Label = $SourceLabel


func _ready() -> void:
	for i in range(slots_root.get_child_count()):
		var slot := slots_root.get_child(i) as DaocCharacterSlot
		if slot != null:
			slot.slot_pressed.connect(_on_slot_pressed)
	play_button.pressed.connect(request_main_action)
	customize_button.pressed.connect(request_customize)
	delete_button.pressed.connect(request_delete)
	back_button.pressed.connect(request_back)
	options_button.pressed.connect(request_options)
	quit_button.pressed.connect(request_quit)
	source_label.visible = debug_ui_labels_enabled
	_refresh_actions()


func set_model(value: Dictionary) -> void:
	model = value.duplicate(true)
	selected_slot_index = -1
	selected_data = {}
	var realm_id := int((model.get("selected_realm", {}) as Dictionary).get("id", 1))
	backdrop.set_realm(realm_id)
	var slots: Array = model.get("slots", []) as Array
	for i in range(10):
		var slot_data: Dictionary = (slots[i] as Dictionary) if i < slots.size() else {"slot_index": i, "empty": true, "valid": false, "realm_id": realm_id}
		var slot := slots_root.get_child(i) as DaocCharacterSlot
		slot.set_slot(i, slot_data)
		slot.set_selected(false)
	preview.clear_character()
	source_label.text = "Source : %s · %d personnage(s)" % [str(model.get("source", "offline")), int(model.get("character_count", 0))]
	source_label.visible = debug_ui_labels_enabled
	detail_label.text = "Sélectionnez un personnage" if int(model.get("character_count", 0)) > 0 else "Aucun personnage sur ce royaume — les dix emplacements sont disponibles."
	_refresh_actions()


func set_animation_polish_enabled(enabled: bool) -> void:
	preview.set_animation_polish_enabled(enabled)


func slot_count() -> int:
	return slots_root.get_child_count() if slots_root != null else 0


func slot_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in slots_root.get_children():
		result.append((child as DaocCharacterSlot).snapshot())
	return result


func select_slot(index: int) -> Dictionary:
	if index < 0 or index >= slot_count():
		return {}
	var slot := slots_root.get_child(index) as DaocCharacterSlot
	selected_slot_index = index
	selected_data = slot.character_data.duplicate(true)
	for i in range(slot_count()):
		(slots_root.get_child(i) as DaocCharacterSlot).set_selected(i == index)
	if bool(selected_data.get("valid", false)):
		preview.show_character(selected_data)
		detail_label.text = "%s — niveau %d %s, %s · %s" % [
			str(selected_data.get("name", "")), int(selected_data.get("level", 0)),
			str(selected_data.get("class_name", selected_data.get("class", ""))),
			str(selected_data.get("race_name", selected_data.get("race", ""))), str(selected_data.get("location", "")),
		]
	else:
		preview.clear_character()
		detail_label.text = "Emplacement %d libre" % (index + 1)
	character_selected.emit(index, selected_data.duplicate(true))
	emitted_intents.append("character_selected")
	_refresh_actions()
	return selected_data.duplicate(true)


func request_main_action() -> bool:
	if can_play():
		return request_play()
	return request_create()


func request_play() -> bool:
	if not can_play():
		return false
	play_requested.emit(selected_slot_index, selected_data.duplicate(true))
	emitted_intents.append("play_requested")
	return true


func request_create() -> bool:
	if selected_slot_index < 0 or bool(selected_data.get("valid", false)):
		return false
	create_requested.emit(selected_slot_index)
	emitted_intents.append("create_requested")
	return true


func request_customize() -> bool:
	if not can_play():
		return false
	customize_requested.emit(selected_slot_index, selected_data.duplicate(true))
	emitted_intents.append("customize_requested")
	return true


func request_delete() -> bool:
	if not can_play():
		return false
	delete_requested.emit(selected_slot_index, selected_data.duplicate(true))
	emitted_intents.append("delete_requested")
	return true


func request_back() -> void:
	back_requested.emit()
	emitted_intents.append("back_requested")


func request_options() -> void:
	options_requested.emit()
	emitted_intents.append("options_requested")


func request_quit() -> void:
	quit_requested.emit()
	emitted_intents.append("quit_requested")


func can_play() -> bool:
	return selected_slot_index >= 0 and bool(selected_data.get("valid", false)) and str(selected_data.get("name", "")) != ""


func safety_snapshot() -> Dictionary:
	return {
		"network_packet_count": network_packet_count,
		"play_is_intent_only": true,
		"character_select_packet_sent": false,
		"udp_enabled": false,
		"create_network_enabled": false,
		"delete_network_enabled": false,
		"customize_network_enabled": false,
		"options_network_enabled": false,
		"quit_is_signal_only": true,
	}


func _on_slot_pressed(index: int, _data: Dictionary) -> void:
	select_slot(index)


func _refresh_actions() -> void:
	if play_button == null:
		return
	var has_selection := selected_slot_index >= 0
	var valid_character := can_play()
	play_button.disabled = not has_selection
	play_label.text = "Play" if valid_character else "Create"
	customize_button.disabled = not valid_character
	delete_button.disabled = not valid_character
	customize_label.modulate = Color(1.0, 0.78, 0.27, 1.0) if valid_character else Color(0.52, 0.48, 0.39, 1.0)
	delete_label.modulate = Color(1.0, 0.78, 0.27, 1.0) if valid_character else Color(0.52, 0.48, 0.39, 1.0)
