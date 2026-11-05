extends CanvasLayer
class_name DaocConcentrationWindow

## P1-108 — la fenetre de concentration du client d origine : la liste des
## buffs de concentration que le joueur maintient (0x75 ConcentrationList),
## chacun avec son icone, son cout de concentration, son nom et le nom de
## celui qui le porte. Le CLIC DROIT sur une ligne demande son retrait (0x76
## RemoveConcentrationEffect, u8 index — le serveur repond par un nouveau
## 0x75). La fenetre se cache quand la liste est vide, comme l original qui
## ne la montre qu aux classes a concentration.

signal remove_requested(index: int)

const ROW := 20
const ICON := 18

var icon_atlas: RefCounted = null
var effects: Array = []
var remove_requests := 0
var _panel: PanelContainer = null
var _rows: VBoxContainer = null
var _title: Label = null


func _ready() -> void:
	layer = 21
	_panel = PanelContainer.new()
	_panel.name = "Concentration"
	# L emplacement « concentration » de DaocUiWindowManager (TOP_LEFT 16,252).
	_panel.position = Vector2(16, 252)
	_panel.custom_minimum_size = Vector2(200, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.text = "Concentration"
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	box.add_child(_rows)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)
	_rebuild()


func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas
	_rebuild()


## `list` : [{index, concentration, icon, name, owner}], la liste COMPLETE.
func set_effects(list: Array) -> void:
	effects = list.duplicate(true)
	_rebuild()


func total_concentration() -> int:
	var total := 0
	for effect in effects:
		total += int((effect as Dictionary).get("concentration", 0))
	return total


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _rebuild() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	_panel.visible = not effects.is_empty()
	_title.text = "Concentration (%d)" % total_concentration()
	for value in effects:
		var effect := value as Dictionary
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ROW)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "%s sur %s\nConcentration : %d\nClic droit : retirer" % [str(effect.get("name", "")), str(effect.get("owner", "")), int(effect.get("concentration", 0))]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icon_atlas != null and icon_atlas.has_method("texture_for"):
			icon.texture = icon_atlas.call("texture_for", int(effect.get("icon", 0)), "spell") as Texture2D
		row.add_child(icon)
		var label := Label.new()
		label.text = "%2d  %s  (%s)" % [int(effect.get("concentration", 0)), str(effect.get("name", "")), str(effect.get("owner", ""))]
		label.add_theme_font_size_override("font_size", 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		row.gui_input.connect(_on_row_input.bind(int(effect.get("index", 0))))
		_rows.add_child(row)


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		remove_requests += 1
		remove_requested.emit(index)


func get_debug_snapshot() -> Dictionary:
	var names: Array = []
	for effect in effects:
		names.append(str((effect as Dictionary).get("name", "")))
	return {"count": effects.size(), "total": total_concentration(), "names": names, "shown": is_shown(), "remove_requests": remove_requests}
