extends CanvasLayer
class_name DaocEmblemWindow

## P1-110 — la fenêtre d emblème de guilde : le serveur l ouvre par 0xE2
## EmblemDialogue (quatre zéros, `/gc emblem` chez un PNJ d emblème, chef de
## guilde seulement) ; le client répond 0xE2 : couleur 1 (0-15), couleur 2
## (0-7), motif (0-3), logo (0-255) — game.dll FUN_0042bdd5, DOL
## EmblemDialogReponseHandler. Le client d origine dessine l emblème ; ici
## quatre champs et « Valider ».

signal emblem_chosen(primary_color: int, secondary_color: int, pattern: int, logo: int)

var shown_count := 0
var emblems_sent := 0
var _panel: PanelContainer = null
var _fields: Dictionary = {}


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "Emblem"
	_panel.position = Vector2(460, 200)
	_panel.custom_minimum_size = Vector2(260, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Embleme de guilde"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(title)
	for spec in [["primary_color", "Couleur 1 (0-15)", 15], ["secondary_color", "Couleur 2 (0-7)", 7], ["pattern", "Motif (0-3)", 3], ["logo", "Logo (0-255)", 255]]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(spec[1])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = int(spec[2])
		spin.step = 1
		row.add_child(spin)
		_fields[str(spec[0])] = spin
		box.add_child(row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok := Button.new()
	ok.text = "Valider (0xE2)"
	ok.pressed.connect(_on_validate)
	buttons.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(hide_window)
	buttons.add_child(cancel)
	box.add_child(buttons)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func show_window() -> void:
	shown_count += 1
	if _panel != null:
		_panel.visible = true


func set_values(primary_color: int, secondary_color: int, pattern: int, logo: int) -> void:
	(_fields["primary_color"] as SpinBox).value = primary_color
	(_fields["secondary_color"] as SpinBox).value = secondary_color
	(_fields["pattern"] as SpinBox).value = pattern
	(_fields["logo"] as SpinBox).value = logo


func _on_validate() -> void:
	emblems_sent += 1
	emblem_chosen.emit(int((_fields["primary_color"] as SpinBox).value), int((_fields["secondary_color"] as SpinBox).value),
		int((_fields["pattern"] as SpinBox).value), int((_fields["logo"] as SpinBox).value))
	hide_window()


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "emblems_sent": emblems_sent}
