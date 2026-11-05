extends Control
class_name DaocHeyvenoSelectConfirmation

signal confirmation_submitted(slot_index: int, exact_name: String, character_data: Dictionary)
signal confirmation_cancelled()

const REQUIRED_NAME := "Heyveno"
var selected_slot_index := -1
var selected_character: Dictionary = {}

@onready var summary_label: Label = $Panel/SummaryLabel
@onready var exact_name_edit: LineEdit = $Panel/ExactNameEdit
@onready var confirm_button: Button = $Panel/ConfirmButton
@onready var cancel_button: Button = $Panel/CancelButton


func _ready() -> void:
	exact_name_edit.text_changed.connect(_on_text_changed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(hide_dialog)
	visible = false
	_refresh_confirm_button()


func show_for_character(character: Dictionary) -> void:
	selected_character = character.duplicate(true)
	selected_slot_index = int(character.get("slot_index", character.get("slot", -1)))
	summary_label.text = "\n".join([
		"Sélectionner Heyveno et demander une session au serveur ?", "",
		"Nom : Heyveno", "Royaume : Albion", "Race : Briton", "Classe : Armswoman",
		"Niveau : %d" % int(character.get("level", 1)), "Slot : %d" % selected_slot_index, "",
		"Cette étape demandera un SessionID.", "Elle n’entrera pas dans le monde.", "",
		"Saisissez exactement Heyveno pour confirmer.",
	])
	exact_name_edit.text = ""
	visible = true
	_refresh_confirm_button()
	exact_name_edit.grab_focus()


func hide_dialog() -> void:
	var was_visible := visible
	visible = false
	exact_name_edit.text = ""
	_refresh_confirm_button()
	if was_visible:
		confirmation_cancelled.emit()


func confirmation_valid() -> bool:
	return visible and selected_slot_index == 0 and str(selected_character.get("name", "")) == REQUIRED_NAME and exact_name_edit.text == REQUIRED_NAME


func _on_text_changed(_new_text: String) -> void:
	_refresh_confirm_button()


func _on_confirm_pressed() -> void:
	if not confirmation_valid():
		return
	visible = false
	confirmation_submitted.emit(selected_slot_index, exact_name_edit.text, selected_character.duplicate(true))


func _refresh_confirm_button() -> void:
	if confirm_button != null:
		confirm_button.disabled = exact_name_edit == null or exact_name_edit.text != REQUIRED_NAME or selected_slot_index != 0 or str(selected_character.get("name", "")) != REQUIRED_NAME
