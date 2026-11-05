extends CanvasLayer
class_name DaocChampionTrainerWindow

## P1-109 — la page Champion d un entraineur (0x7B code 2,
## PacketLib168.SendChampionTrainerWindow) : des sous-lignes de competences
## (capacite / style / sort, avec leur icone) que le joueur forme une par une
## avec ses points de Champion. Le statut vient du serveur : grise (prerequis
## manquant), acquise, formable. Un CLIC sur une competence formable envoie le
## 0x7C (ligne, rangee, colonne) ; DOL repond par un nouveau 0x7B code 2 et
## un 0x91 (les points).

signal champion_train_requested(line_index: int, row: int, column: int)

const ROW := 20
const ICON := 18
const STATUS_COLORS := {"locked": Color(0.5, 0.5, 0.5), "trained": Color(0.6, 0.9, 0.6), "trainable": Color(0.98, 0.93, 0.72)}

var icon_atlas: RefCounted = null
var last_page: Dictionary = {}
var shown_count := 0
var trains_sent := 0
var _panel: PanelContainer = null
var _title: Label = null
var _rows: VBoxContainer = null


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "ChampionTrainer"
	_panel.position = Vector2(300, 100)
	_panel.custom_minimum_size = Vector2(360, 0)
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
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)


func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas


func show_page(page: Dictionary) -> void:
	last_page = page.duplicate(true)
	shown_count += 1
	if _panel == null:
		return
	_title.text = "Champion — ligne %d, %d point(s)" % [int(page.get("line_index", 0)), int(page.get("champion_points", 0))]
	for child in _rows.get_children():
		child.queue_free()
	for value in page.get("sublines", []):
		var subline := value as Dictionary
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		var row_label := Label.new()
		row_label.text = "%d." % int(subline.get("row", 0))
		row_label.add_theme_font_size_override("font_size", 11)
		line.add_child(row_label)
		for skill_value in subline.get("skills", []):
			line.add_child(_make_skill(int(page.get("line_index", 0)), int(subline.get("row", 0)), skill_value as Dictionary))
		_rows.add_child(line)
	_panel.visible = true


func _make_skill(line_index: int, row: int, skill: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW)
	button.add_theme_font_size_override("font_size", 10)
	var status := str(skill.get("status", "locked"))
	button.text = str(skill.get("name", ""))
	button.add_theme_color_override("font_color", STATUS_COLORS.get(status, Color.WHITE))
	button.disabled = status != "trainable"
	button.tooltip_text = "%s (%s)\nStatut : %s%s" % [str(skill.get("name", "")), str(skill.get("kind", "")), status, "\nClic : former (0x7C)" if status == "trainable" else ""]
	if icon_atlas != null and icon_atlas.has_method("texture_for") and int(skill.get("icon", 0)) > 0:
		button.icon = icon_atlas.call("texture_for", int(skill.get("icon", 0)), DaocSpellIconAtlas.family_for_kind(str(skill.get("kind", "")))) as Texture2D
		button.expand_icon = true
	button.pressed.connect(_on_skill_pressed.bind(line_index, row, int(skill.get("column", 0))))
	return button


func _on_skill_pressed(line_index: int, row: int, column: int) -> void:
	trains_sent += 1
	champion_train_requested.emit(line_index, row, column)


func hide_page() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_page()


func _unhandled_input(event: InputEvent) -> void:
	if is_shown() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_page()


func get_debug_snapshot() -> Dictionary:
	var trainable := 0
	for value in last_page.get("sublines", []):
		for skill in (value as Dictionary).get("skills", []):
			if str((skill as Dictionary).get("status", "")) == "trainable":
				trainable += 1
	return {"shown": is_shown(), "shown_count": shown_count, "trains_sent": trains_sent, "line_index": int(last_page.get("line_index", 0)),
		"points": int(last_page.get("champion_points", 0)), "sublines": (last_page.get("sublines", []) as Array).size(), "trainable": trainable}
