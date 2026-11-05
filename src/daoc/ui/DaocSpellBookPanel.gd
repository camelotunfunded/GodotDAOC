extends PanelContainer
class_name DaocSpellBookPanel

## Le grimoire : une GRILLE d'icones du client, groupee par ligne, qui tient
## dans la fenetre « Sorts » (192 x 416 en atlantis). Chaque icone se glisse
## vers une case de barre ; le survol donne nom, ligne et niveau.
## Avant le 2026-09-15 c'etait une liste de boutons texte plus large que la
## fenetre, avec un lancement au double clic.
## Depuis le 2026-09-30 (capture du client d origine) : une categorie par
## ligne, repliee par defaut, avec sa puce ; chaque sort est une rangee icone +
## nom, tronque proprement s il deborde.

const CELL := 34
const ROW_HEIGHT := 24
const DragButtonScript = preload("res://src/daoc/ui/DaocSpellDragButton.gd")

var available_spells: Array = []
var icon_atlas: RefCounted = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _columns := 5
## Lignes depliees, gardees d une reconstruction a l autre.
var _expanded: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(172, 300)
	position = Vector2(10, 34)
	var style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	_rebuild()


## Cadre le panneau dans la zone utile d'une fenetre XML : sous sa barre de
## titre, jusqu'a son bord. La fenetre decide de la visibilite.
func fit_into_window(frame: Control) -> void:
	var inset := Vector2(10.0, 34.0)
	position = inset
	var area := frame.size - inset - Vector2(10.0, 12.0)
	if area.x < 100.0 or area.y < 100.0:
		area = Vector2(172.0, 370.0)
	custom_minimum_size = area
	size = area
	_columns = maxi(1, int(area.x) / CELL)
	if _scroll != null:
		_scroll.custom_minimum_size = area
	_rebuild()


func set_spells(spells: Array) -> void:
	available_spells = spells.duplicate(true)
	if _list != null:
		_rebuild()


func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas
	if _list != null:
		_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if available_spells.is_empty():
		var empty := Label.new()
		empty.text = "Aucun sort appris."
		empty.add_theme_font_size_override("font_size", 11)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		_list.add_child(empty)
		return
	# Groupe par ligne, dans l'ordre des niveaux requis.
	var by_line: Dictionary = {}
	for value in available_spells:
		var spell := value as Dictionary
		var line := str(spell.get("display_line", spell.get("line", spell.get("path", "Capacites"))))
		if not by_line.has(line):
			by_line[line] = []
		(by_line[line] as Array).append(spell)
	var lines: Array = by_line.keys()
	lines.sort()
	# 2026-09-30 : comme le grimoire d origine, une categorie par ligne, repliee
	# ou depliee par sa puce ; les deux boutons du haut deplient / replient tout.
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	toolbar.add_child(_toolbar_button("Tout ouvrir", func() -> void: _set_all_expanded(lines, true)))
	toolbar.add_child(_toolbar_button("Tout fermer", func() -> void: _set_all_expanded(lines, false)))
	_list.add_child(toolbar)
	for line in lines:
		var spells: Array = by_line[line] as Array
		spells.sort_custom(func(a, b): return int(a.get("required_level", 0)) < int(b.get("required_level", 0)))
		var expanded := bool(_expanded.get(str(line), false))
		var grid := GridContainer.new()
		grid.columns = 1
		grid.add_theme_constant_override("v_separation", 1)
		grid.visible = expanded
		var header := Button.new()
		header.flat = true
		header.focus_mode = Control.FOCUS_NONE
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.clip_text = true
		header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		header.text = "%s  %s  (%d)" % ["▾" if expanded else "▸", str(line), spells.size()]
		header.tooltip_text = str(line)
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", Color(0.93, 0.82, 0.55))
		header.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
		header.pressed.connect(func() -> void:
			_expanded[str(line)] = not grid.visible
			grid.visible = not grid.visible
			header.text = "%s  %s  (%d)" % ["▾" if grid.visible else "▸", str(line), spells.size()])
		_list.add_child(header)
		_list.add_child(grid)
		for value in spells:
			var spell := value as Dictionary
			var button: Button = DragButtonScript.new()
			button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.text = str(spell.get("name", "Capacite"))
			button.add_theme_font_size_override("font_size", 10)
			button.tooltip_text = "%s\n%s · niveau %d" % [str(spell.get("name", "Capacite")), str(spell.get("display_line", spell.get("line", spell.get("path", "")))), int(spell.get("required_level", 0))]
			button.set_meta("spell_reference", spell.duplicate(true))
			var texture: Texture2D = null
			if icon_atlas != null and icon_atlas.has_method("texture_for"):
				texture = icon_atlas.call("texture_for", int(spell.get("icon", 0)), str(spell.get("icon_family", "spell"))) as Texture2D
			if texture != null:
				button.icon = texture
				button.expand_icon = true
				button.add_theme_constant_override("icon_max_width", ROW_HEIGHT - 4)
			grid.add_child(button)


func _toolbar_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(action)
	return button


func _set_all_expanded(lines: Array, value: bool) -> void:
	for line in lines:
		_expanded[str(line)] = value
	_rebuild()


func icon_count() -> int:
	var count := 0
	if _list == null:
		return 0
	for grid in _list.get_children():
		if grid is GridContainer:
			for button in grid.get_children():
				if (button as Button).icon != null:
					count += 1
	return count
