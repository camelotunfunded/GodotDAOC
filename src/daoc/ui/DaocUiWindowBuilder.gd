extends RefCounted
class_name DaocUiWindowBuilder

## P1-21D - construit une fenetre Godot a partir de sa declaration XML.
##
## La separation du format se transpose telle quelle :
##   `*Template` porte l'apparence, mutualisee  -> region d'atlas + police
##   `*Def`      porte l'instance, placee       -> un noeud Control
##
## Les coordonnees XML sont en PIXELS et l'original interdit tout etirement :
## une zone de 16x16 texels occupait exactement 16x16 pixels a l'ecran. Cette
## contrainte appartenait a l'ancien moteur ; ici la fenetre est batie a sa
## taille native puis peut etre mise a l'echelle par son parent.
##
## Deux sources alimentent le meme emplacement de texte : `<Data>` porte le
## texte fixe, `<Adapter>` le texte vivant. Quand les deux sont presents, le
## `<Data>` est un texte de previsualisation laisse par l'editeur d'interface
## (`C:999`, `Ability0`) : l'adaptateur l'emporte.
##
## Ce constructeur n'invente RIEN. Un gabarit introuvable, un type de controle
## non gere ou un canal muet sont COMPTES et nommes, jamais combles.

## Types de controles batis par cette passe.
const HANDLED := [
	"FullResizeImageDef", "ImageAreaDef", "LabelDef", "ScalarLabelDef",
	"ButtonDef", "InvisibleButtonDef", "CheckBoxDef", "StatusBarDef",
	"StatusIconDef", "HorizontalResizeButtonDef", "HorizontalResizeImageButtonDef",
	"TextAreaDef", "IconDef", "DockableIconDef", "ListBoxDef",
	# P1-134 (audit des fenetres du 2026-09-29) : bandeaux, curseurs, onglets.
	"HorizontalResizeImageDef", "HorizontalSliderDef", "VerticalSliderDef", "TabsDef",
]


## P1-134 — curseur d un `Horizontal/VerticalSliderDef` : une bande a trois
## tranches et un index (`Hslider_indicator`). La valeur est une FRACTION
## 0..1 posee par la fenetre qui le pilote ; un clic avant / apres l index
## emet `stepped(-1 / +1)`, la molette aussi. Le client d origine glisse
## l index a la souris ; le pas a pas suffit aux niveaux entiers.
class SliderControl extends Control:
	signal stepped(delta: int)
	var vertical := false
	var indicator: Control = null
	var fraction := 0.0

	func set_fraction(value: float) -> void:
		fraction = clampf(value, 0.0, 1.0)
		if indicator == null:
			return
		if vertical:
			indicator.position.y = roundf((size.y - indicator.size.y) * fraction)
		else:
			indicator.position.x = roundf((size.x - indicator.size.x) * fraction)

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button == null or not button.pressed:
			return
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				stepped.emit(-1 if vertical else 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				stepped.emit(1 if vertical else -1)
			MOUSE_BUTTON_LEFT:
				var at := button.position.y if vertical else button.position.x
				var mark := (indicator.position.y + indicator.size.y * 0.5) if vertical else (indicator.position.x + indicator.size.x * 0.5)
				stepped.emit(1 if at > mark else -1)
			_:
				return
		accept_event()

const DEFAULT_FONT_SIZE := 12

var library: DaocUiTextureLibrary = null
var bus: DaocUiAdapterBus = null

## Type -> nom -> gabarit, fusionne sur tout le skin.
var templates: Dictionary = {}

## Nom logique de police -> taille en pixels, lue dans `assets.xml`.
var font_sizes: Dictionary = {}

## Police TTF commune. Choix acte : on abandonne les polices bitmap, dont les
## metriques sont encodees dans les pixels de l'image.
var font: Font = null

## Provenance de la police reellement utilisee : `ARIAL` ou `GODOT_DEFAULT`.
var font_provenance: String = "GODOT_DEFAULT"

# --- releve de la derniere construction ---
var built_counts: Dictionary = {}
var skipped_counts: Dictionary = {}
var missing_templates: PackedStringArray = PackedStringArray()
var bound_channels: PackedStringArray = PackedStringArray()

## Emplacements d'icone batis sans illustration : les planches `*_icons.xml`
## adressees par `IconId` sont un sous-systeme a part.
var icon_slots_without_art: int = 0

## Hauteur de la fenetre en cours de construction (ancrage `OffsetBottom`).
var _window_height: int = 0


static func create(ui_root: String, contract: DaocUiSkinContract, adapter_bus: DaocUiAdapterBus) -> DaocUiWindowBuilder:
	var builder: DaocUiWindowBuilder = DaocUiWindowBuilder.new()
	builder.library = DaocUiTextureLibrary.from_contract(ui_root, contract)
	builder.bus = adapter_bus
	builder.templates = contract.merged_templates()
	builder._read_fonts(contract)
	builder._load_font()
	return builder


## Construit une fenetre. Renvoie un `Control` a la taille native declaree.
func build(window: Dictionary) -> Control:
	var root: Control = Control.new()
	root.name = _str(window, "Name", "window")
	var width: int = _int(window, "Width", 0)
	var height: int = _int(window, "Height", 0)
	root.custom_minimum_size = Vector2(width, height)
	root.size = Vector2(width, height)
	root.clip_contents = true
	_window_height = height

	for tag: String in window:
		if not tag.ends_with("Def"):
			continue
		for entry: Variant in _as_array(window[tag]):
			if entry is Dictionary:
				_build_control(root, tag, entry as Dictionary)
	if root.name.to_lower() == "summary":
		_fix_summary_target_spacing(root)
	_wire_tabs(root)
	return root


func get_debug_snapshot() -> Dictionary:
	return {
		"font_provenance": font_provenance,
		"built": built_counts,
		"skipped": skipped_counts,
		"missing_templates": missing_templates.size(),
		"bound_channels": bound_channels.size(),
		"icon_slots_without_art": icon_slots_without_art,
		"textures": library.get_debug_snapshot() if library != null else {},
	}


# ---------------------------------------------------------------------------
# repartition par type

func _build_control(parent: Control, tag: String, def: Dictionary) -> void:
	if not HANDLED.has(tag):
		skipped_counts[tag] = int(skipped_counts.get(tag, 0)) + 1
		return

	var node: Control = null
	match tag:
		"FullResizeImageDef":
			node = _make_full_resize(def)
		"ImageAreaDef":
			node = _make_image_area(def)
		"LabelDef", "ScalarLabelDef":
			node = _make_label(def)
		"ButtonDef":
			node = _make_button(def)
		"InvisibleButtonDef":
			node = _make_invisible_button(def)
		"CheckBoxDef":
			node = _make_checkbox(def)
		"StatusBarDef":
			node = _make_status_bar(def)
		"StatusIconDef":
			node = _make_status_icon(def)
		"HorizontalResizeButtonDef", "HorizontalResizeImageButtonDef":
			node = _make_h_resize_button(def)
		"TextAreaDef":
			node = _make_text_area(def)
		"IconDef", "DockableIconDef":
			node = _make_icon(def)
		"ListBoxDef":
			node = _make_list_box(def)
		"HorizontalResizeImageDef":
			node = _h_resize_strip(_str(def, "TemplateName", ""), _int(def, "Width", 0))
		"HorizontalSliderDef", "VerticalSliderDef":
			node = _make_slider(def, tag == "VerticalSliderDef")
		"TabsDef":
			node = _make_tabs(def)

	if node == null:
		skipped_counts[tag] = int(skipped_counts.get(tag, 0)) + 1
		return

	node.position = Vector2(_vec(def, "Position"))
	# P1-134 : `OffsetBottom` compte Y depuis le BAS de la fenetre (les boutons
	# TRAIN / RESET / CANCEL de training_window.xml sont a Y=3 et Y=25).
	var alignment: Variant = def.get("Alignment", {})
	if alignment is Dictionary and _bool_case_insensitive(alignment as Dictionary, "OffsetBottom") and _window_height > 0:
		node.position.y = _window_height - node.position.y - node.size.y
	# Godot renomme les freres homonymes en `@Control@28` : le nom du noeud ne
	# survit pas. La balise d'origine est donc portee par une metadonnee, seul
	# moyen fiable de retrouver un controle par son type.
	node.set_meta("daoc_def", tag)
	# `ControlId` est un handle intra-fenetre choisi par l'auteur du skin, pas un
	# nom que le moteur connait. C'est neanmoins la SEULE cle qui distingue les
	# six cases du menu `stats_index`, qui ne portent aucun evenement.
	var control_id: String = _str(def, "ControlId", "")
	if control_id != "":
		node.set_meta("daoc_control_id", control_id)
	parent.add_child(node)
	built_counts[tag] = int(built_counts.get(tag, 0)) + 1


# ---------------------------------------------------------------------------
# fabriques

## Fond a neuf tranches. Les neuf coins sont des points ARBITRAIRES de l'atlas,
## pas forcement contigus : chaque piece est donc dessinee separement plutot que
## via un NinePatchRect, qui supposerait une region d'un seul tenant.
func _make_full_resize(def: Dictionary) -> Control:
	var template: Dictionary = _template("FullResizeImageTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var texture_block: Dictionary = template.get("Texture", {}) as Dictionary
	if texture_block.is_empty():
		return null
	var texture_name: String = _str(texture_block, "TextureName", "")

	var widths: Array[int] = [
		_int(template, "LeftWidth", 0), _int(template, "MiddleWidth", 0), _int(template, "RightWidth", 0),
	]
	var heights: Array[int] = [
		_int(template, "TopHeight", 0), _int(template, "MiddleHeight", 0), _int(template, "BottomHeight", 0),
	]
	var rows: Array[String] = ["Top", "Middle", "Bottom"]
	var columns: Array[String] = ["Left", "Middle", "Right"]

	var total: Vector2i = Vector2i(
		_int(def, "Width", widths[0] + widths[1] + widths[2]),
		_int(def, "Height", heights[0] + heights[1] + heights[2]))
	var holder: Control = Control.new()
	holder.name = "FullResizeImage"
	holder.custom_minimum_size = Vector2(total)
	holder.size = Vector2(total)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La tranche centrale absorbe l'espace restant ; les bords gardent leur taille.
	var span_x: Array[int] = [widths[0], maxi(0, total.x - widths[0] - widths[2]), widths[2]]
	var span_y: Array[int] = [heights[0], maxi(0, total.y - heights[0] - heights[2]), heights[2]]

	var offset_y: int = 0
	for row: int in 3:
		var offset_x: int = 0
		for column: int in 3:
			var key: String = rows[row] + columns[column]
			var origin: Vector2i = _vec(texture_block, key)
			var piece_size: Vector2i = Vector2i(widths[column], heights[row])
			var region: AtlasTexture = library.get_region(texture_name, origin, piece_size)
			if region != null and span_x[column] > 0 and span_y[row] > 0:
				var rect: TextureRect = TextureRect.new()
				rect.texture = region
				rect.stretch_mode = TextureRect.STRETCH_SCALE
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.position = Vector2(offset_x, offset_y)
				rect.size = Vector2(span_x[column], span_y[row])
				rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(rect)
			offset_x += span_x[column]
		offset_y += span_y[row]
	return holder


func _make_image_area(def: Dictionary) -> Control:
	var template: Dictionary = _template("ImageAreaTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var size: Vector2i = _vec(template, "Size")
	var region: AtlasTexture = library.get_region(
		_str(template, "TextureName", ""), _vec(template, "TopLeft"), size)
	if region == null:
		return null
	var rect: TextureRect = TextureRect.new()
	rect.name = "ImageArea"
	rect.texture = region
	rect.size = Vector2(size)
	rect.custom_minimum_size = Vector2(size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_label(def: Dictionary) -> Control:
	var label: Label = Label.new()
	label.name = "Label"
	label.text = _str(def, "Data", "")
	label.size = Vector2(_int(def, "Width", 0), _int(def, "Height", 0))
	label.custom_minimum_size = label.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true

	if _bool(def, "TextCentered"):
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif _bool(def, "EndAligned"):
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		var alignment: Variant = def.get("Alignment", {})
		if alignment is Dictionary:
			var block := alignment as Dictionary
			if _bool_case_insensitive(block, "CenterHorizontally"):
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", _font_size(_str(def, "FontName", "")))
	label.add_theme_color_override("font_color", _color(def.get("Color", {})))
	# 2026-09-30 : la ligne tient dans sa case (hauteur), le texte vivant s abrege.
	_fit_caption(label, Vector2(_int(def, "Width", 0), _int(def, "Height", 0)), _adapter_of(def).is_empty())

	# L'adaptateur l'emporte sur le texte de previsualisation.
	var channel: String = _adapter_of(def)
	if channel != "":
		label.set_meta("daoc_adapter", channel)
		_bind(channel, label, func(value: Variant) -> void: label.text = str(value))
		# P1-106 : le canal `<ColorAdapter>` (stats_strength_color...) colore le
		# texte : blanc sans bonus, vert avec un bonus, rouge avec un malus —
		# le client d origine fait pareil. Une Color ou un nom de couleur.
		var colour_channel: String = _colour_adapter_of(def)
		if colour_channel != "":
			label.set_meta("daoc_color_adapter", colour_channel)
			_bind(colour_channel, label, func(value: Variant) -> void:
				label.add_theme_color_override("font_color", _colour_value(value)))
		# Et le canal `<adapter>_tooltip` porte l infobulle (base et bonus au survol).
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		_bind(channel + "_tooltip", label, func(value: Variant) -> void: label.tooltip_text = str(value))
	return label


const COLOUR_NAMES := {"white": Color.WHITE, "green": Color(0.45, 1.0, 0.45), "red": Color(1.0, 0.4, 0.4),
	"yellow": Color(1.0, 0.95, 0.5), "grey": Color(0.6, 0.6, 0.6), "gray": Color(0.6, 0.6, 0.6)}


func _colour_adapter_of(def: Dictionary) -> String:
	for key: String in def:
		if key.to_lower() == "coloradapter":
			var value: String = _str(def, key, "")
			if value != "" and value.to_lower() != "none":
				return value
	return ""


func _colour_value(value: Variant) -> Color:
	if value is Color:
		return value
	var text := str(value).strip_edges().to_lower()
	if COLOUR_NAMES.has(text):
		return COLOUR_NAMES[text]
	if text.is_valid_html_color():
		return Color.html(text)
	return Color.WHITE


func _make_button(def: Dictionary) -> Control:
	var template: Dictionary = _template("ButtonTemplate", _str(def, "TemplateName", ""))
	var size: Vector2i = _vec(template, "Size") if not template.is_empty() else Vector2i.ZERO
	if size == Vector2i.ZERO:
		size = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null

	var button: TextureButton = TextureButton.new()
	button.name = "Button"
	button.size = Vector2(size)
	button.custom_minimum_size = Vector2(size)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE

	var texture_block: Dictionary = template.get("Texture", {}) as Dictionary
	if not texture_block.is_empty():
		var texture_name: String = _str(texture_block, "TextureName", "")
		button.texture_normal = library.get_region(texture_name, _vec(texture_block, "Normal"), size)
		button.texture_pressed = library.get_region(texture_name, _vec(texture_block, "Pressed"), size)
		button.texture_hover = library.get_region(texture_name, _vec(texture_block, "NormalHighlit"), size)
		button.texture_disabled = library.get_region(texture_name, _vec(texture_block, "Disabled"), size)

	# P1-134 : un gabarit qui porte une `<Font>` affiche le `<Data>` du bouton
	# (BUY, SELL, APPRAISE, PREV, NEXT...). Sans police, le Data reste un
	# argument d evenement et n est pas dessine.
	var caption: String = _str(def, "Label", _str(def, "Data", ""))
	if caption != "" and template.get("Font") is Dictionary:
		var label := Label.new()
		label.name = "Caption"
		label.text = caption
		label.size = Vector2(size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		_apply_font(label, template["Font"])
		_fit_caption(label, Vector2(size))
		button.add_child(label)
	var event: String = _event_of(def)
	if event != "":
		button.set_meta("daoc_event", event)
		button.set_meta("daoc_event_data", _str(def, "Data", ""))
	return button


func _make_slider(def: Dictionary, vertical: bool) -> Control:
	var template: Dictionary = _template("VerticalSliderTemplate" if vertical else "HorizontalSliderTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var length: int = _int(def, "Height" if vertical else "Width", 0)
	if length <= 0:
		return null
	var slider := SliderControl.new()
	slider.name = "Slider"
	slider.vertical = vertical
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	var track: Control = null
	if vertical:
		track = _v_resize_strip(_str(template, "BackgroundVResizeTemplate", ""), length)
	else:
		track = _h_resize_strip(_str(template, "BackgroundHResizeTemplate", ""), length)
	var thickness := _int(template, "Width" if vertical else "Height", 13)
	slider.size = Vector2(thickness, length) if vertical else Vector2(length, thickness)
	slider.custom_minimum_size = slider.size
	if track != null:
		slider.add_child(track)
	var indicator := _make_image_area({"TemplateName": _str(template, "ImageAreaTemplate", "")})
	if indicator != null:
		# L index est centre sur la bande, dans l axe transversal.
		if vertical:
			indicator.position.x = roundf((thickness - indicator.size.x) * 0.5)
		else:
			indicator.position.y = roundf((thickness - indicator.size.y) * 0.5)
		slider.add_child(indicator)
		slider.indicator = indicator
	return slider


## Pendant vertical de `_h_resize_strip` (Top / Repeat / Bottom).
func _v_resize_strip(template_name: String, height: int) -> Control:
	var template: Dictionary = _template("VerticalResizeImageTemplate", template_name)
	if template.is_empty():
		return null
	var texture_block: Dictionary = template.get("Texture", {}) as Dictionary
	var texture_name: String = _str(texture_block, "TextureName", "")
	var width: int = _int(template, "Width", 0)
	if width <= 0:
		return null
	var top: int = _int(template, "TopHeight", 0)
	var bottom: int = _int(template, "BottomHeight", 0)
	var repeat: int = _int(template, "RepeatHeight", 0)
	var holder := Control.new()
	holder.name = "VStrip"
	holder.size = Vector2(width, height)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var middle: int = maxi(0, height - top - bottom)
	var pieces: Array = [["Top", top, 0, top], ["Bottom", bottom, top + middle, bottom]]
	var cursor := 0
	while repeat > 0 and cursor < middle:
		pieces.append(["Repeat", repeat, top + cursor, mini(repeat, middle - cursor)])
		cursor += repeat
	for piece: Array in pieces:
		if int(piece[1]) <= 0 or int(piece[3]) <= 0:
			continue
		var region: AtlasTexture = library.get_region(texture_name, _vec(texture_block, str(piece[0])), Vector2i(width, int(piece[1])))
		if region == null:
			continue
		var rect := TextureRect.new()
		rect.texture = region
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP
		rect.position = Vector2(0, int(piece[2]))
		rect.size = Vector2(width, int(piece[3]))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	return holder


## Onglets : un fond interieur, une rangee de boutons `TabButtonTemplate`, et
## la liste `<TabControl>` qui dit quel ControlId appartient a quel onglet. Le
## basculement lui-meme est pose par `_wire_tabs` une fois tous les freres batis.
func _make_tabs(def: Dictionary) -> Control:
	var template: Dictionary = _template("TabsTemplate", _str(def, "TemplateName", ""))
	var size := Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if template.is_empty() or size.x <= 0 or size.y <= 0:
		return null
	var holder := Control.new()
	holder.name = "Tabs"
	holder.size = Vector2(size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button_template: Dictionary = _template("ButtonTemplate", _str(template, "TabButtonTemplate", ""))
	var button_size: Vector2i = _vec(button_template, "Size") if not button_template.is_empty() else Vector2i(100, 16)
	var x_offset := _int(template, "TabXOffset", 0)
	var y_offset := _int(template, "TabYOffset", 0)
	var area := _full_resize_named(_str(template, "ControlAreaFullResizeImageTemplate", ""),
		Vector2i(size.x, size.y - button_size.y - y_offset))
	if area != null:
		area.position = Vector2(0, button_size.y + y_offset)
		holder.add_child(area)
	var membership := {}
	for entry: Variant in _as_array(def.get("TabControl", [])):
		if entry is Dictionary:
			membership[_str(entry as Dictionary, "ControlId", "")] = _str(entry as Dictionary, "TabId", "")
	holder.set_meta("daoc_tab_membership", membership)
	holder.set_meta("daoc_tab_header", float(button_size.y + y_offset))
	var tab_ids: Array = []
	var index := 0
	for entry: Variant in _as_array(def.get("Tab", [])):
		if not (entry is Dictionary):
			continue
		var tab_id := _str(entry as Dictionary, "Id", str(index + 1))
		tab_ids.append(tab_id)
		var button := _make_button({"TemplateName": _str(template, "TabButtonTemplate", ""), "Data": _str(entry as Dictionary, "Name", "")})
		if button != null:
			button.name = "Tab_%s" % tab_id
			button.toggle_mode = true
			button.position = Vector2(x_offset + index * (button_size.x + 1), 0)
			button.set_meta("daoc_tab_id", tab_id)
			holder.add_child(button)
		index += 1
	holder.set_meta("daoc_tab_ids", tab_ids)
	return holder


## Rattache les ControlId des freres a leur onglet et montre le premier. Le
## XML place la zone d onglets a Y=70, au milieu de l en-tete des points : la
## rangee est donc recalee juste au-dessus du premier controle membre (DERIVE,
## pas lu), ce qui laisse l en-tete et les boutons du bas degages.
func _wire_tabs(root: Control) -> void:
	for tabs: Node in root.get_children():
		if str(tabs.get_meta("daoc_def", "")) != "TabsDef":
			continue
		var membership: Dictionary = tabs.get_meta("daoc_tab_membership", {})
		var members: Array[Control] = []
		var top := INF
		for child: Node in root.get_children():
			var id := str(child.get_meta("daoc_control_id", ""))
			if id != "" and membership.has(id) and child is Control:
				child.set_meta("daoc_tab", str(membership[id]))
				members.append(child as Control)
				top = minf(top, (child as Control).position.y)
		if members.is_empty():
			continue
		var tabs_control := tabs as Control
		var header := float(tabs_control.get_meta("daoc_tab_header", 18.0))
		tabs_control.position.y = top - header - 2.0
		root.move_child(tabs_control, members[0].get_index())
		var show := func(tab_id: String) -> void:
			for member: Control in members:
				member.visible = str(member.get_meta("daoc_tab")) == tab_id
			for button: Node in tabs_control.get_children():
				if button is BaseButton and button.has_meta("daoc_tab_id"):
					(button as BaseButton).set_pressed_no_signal(str(button.get_meta("daoc_tab_id")) == tab_id)
			tabs_control.set_meta("daoc_tab_current", tab_id)
		tabs_control.set_meta("daoc_tab_show", show)
		for button: Node in tabs_control.get_children():
			if button is BaseButton and button.has_meta("daoc_tab_id"):
				(button as BaseButton).pressed.connect(show.bind(str(button.get_meta("daoc_tab_id"))))
		var ids: Array = tabs_control.get_meta("daoc_tab_ids", [])
		if not ids.is_empty():
			show.call(str(ids[0]))


func _make_invisible_button(def: Dictionary) -> Control:
	var size: Vector2i = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null
	var area: Control = Control.new()
	area.name = "InvisibleButton"
	area.size = Vector2(size)
	area.custom_minimum_size = Vector2(size)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	var event: String = _event_of(def)
	if event != "":
		area.set_meta("daoc_event", event)
	return area


func _make_checkbox(def: Dictionary) -> Control:
	var template: Dictionary = _template("CheckBoxTemplate", _str(def, "TemplateName", ""))
	var size: Vector2i = _vec(template, "Size") if not template.is_empty() else Vector2i.ZERO
	if size == Vector2i.ZERO:
		size = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null
	var box: TextureButton = TextureButton.new()
	box.name = "CheckBox"
	box.toggle_mode = true
	box.size = Vector2(size)
	box.custom_minimum_size = Vector2(size)
	box.ignore_texture_size = true
	box.stretch_mode = TextureButton.STRETCH_SCALE
	var texture_block: Dictionary = template.get("Texture", {}) as Dictionary
	if not texture_block.is_empty():
		var texture_name: String = _str(texture_block, "TextureName", "")
		box.texture_normal = library.get_region(texture_name, _vec(texture_block, "Normal"), size)
		box.texture_pressed = library.get_region(texture_name, _vec(texture_block, "Pressed"), size)
	# P1-134 : le libelle d une case (« Keep Qty ») suit la case, sur `LabelWidth`.
	var caption: String = _str(def, "Label", _str(def, "Data", ""))
	if caption != "":
		var label := Label.new()
		label.text = caption
		label.position = Vector2(size.x + 3, 0)
		label.size = Vector2(_int(def, "LabelWidth", 80), size.y)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_font(label, template.get("Font", {}))
		_fit_caption(label, Vector2(_int(def, "LabelWidth", 80), size.y))
		label.position = Vector2(size.x + 3, 0)
		box.add_child(label)
	return box


## La jauge recoit un POURCENTAGE : le format ne permet pas de connaitre un
## maximum. La tranche pleine est donc coupee a `value / 100` de la largeur.
func _make_status_bar(def: Dictionary) -> Control:
	var template: Dictionary = _template("StatusBarTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var width: int = _int(def, "Width", 0)
	var height: int = _int(template, "Height", 0)
	if width <= 0 or height <= 0:
		return null

	var holder: Control = Control.new()
	holder.name = "StatusBar"
	holder.size = Vector2(width, height)
	holder.custom_minimum_size = holder.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background: Control = _h_resize_strip(
		_str(template, "BackgroundHResizeTemplate", ""), width)
	if background != null:
		holder.add_child(background)

	var fill_holder: Control = Control.new()
	fill_holder.name = "Fill"
	fill_holder.size = holder.size
	fill_holder.clip_contents = true
	fill_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_holder.position = Vector2(_vec(template, "ForegroundOffset"))
	holder.add_child(fill_holder)

	var foreground: Control = _h_resize_strip(
		_str(template, "ForegroundHResizeTemplate", ""), width)
	if foreground != null:
		fill_holder.add_child(foreground)

	# La tranche pleine est COUPEE, jamais compressee : une barre a 50 % montre
	# la moitie gauche de son motif, pas le motif entier en deux fois moins large.
	var fill_height: float = foreground.size.y if foreground != null else float(height)
	fill_holder.size = Vector2(0.0, fill_height)
	var channel: String = _adapter_of(def)
	if channel != "":
		holder.set_meta("daoc_adapter", channel)
		_bind(channel, fill_holder, func(value: Variant) -> void:
			var percent: float = clampf(float(value), 0.0, 100.0)
			fill_holder.size = Vector2(float(width) * percent / 100.0, fill_height))
	return holder


func _fix_summary_target_spacing(root: Control) -> void:
	var target_label := _find_adapter_control(root, "summary_target") as Label
	var target_bar := _find_adapter_control(root, "summary_target_hits", "StatusBarDef")
	if target_label == null or target_bar == null:
		return
	# La police TTF de substitution possède une ligne plus haute que la bitmap
	# arial9 du client. On la clippe à sa bande réservée et on descend la jauge
	# jusqu'à la dernière ligne disponible du cadre 128 x 100.
	var clip := Control.new()
	clip.name = "SummaryTargetNameClip"
	clip.position = target_label.position
	clip.size = Vector2(target_label.size.x, 15)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_meta("daoc_adapter", "summary_target_clip")
	root.remove_child(target_label)
	target_label.position = Vector2.ZERO
	clip.add_child(target_label)
	root.add_child(clip)
	target_bar.position.y = 93.0


func _find_adapter_control(node: Node, adapter: String, def_name: String = "") -> Control:
	if node is Control and str(node.get_meta("daoc_adapter", "")) == adapter:
		if def_name == "" or str(node.get_meta("daoc_def", "")) == def_name:
			return node as Control
	for child: Node in node.get_children():
		var found := _find_adapter_control(child, adapter, def_name)
		if found != null:
			return found
	return null


## Bande horizontale a trois tranches : deux bouts a taille fixe et un centre
## repete. `BackgroundHResizeTemplate` et `ForegroundHResizeTemplate` ne sont
## PAS des types de gabarit : ce sont des champs qui portent le NOM d'un
## `HorizontalResizeImageTemplate`. Sa hauteur lui est propre - 6 pixels de
## barre dans un controle de 16.
func _h_resize_strip(template_name: String, width: int) -> Control:
	var template: Dictionary = _template("HorizontalResizeImageTemplate", template_name)
	if template.is_empty():
		return null
	var texture_block: Dictionary = template.get("Texture", {}) as Dictionary
	if texture_block.is_empty():
		return null
	var texture_name: String = _str(texture_block, "TextureName", "")
	var strip_height: int = _int(template, "Height", 0)
	if strip_height <= 0:
		return null

	var left_width: int = _int(template, "LeftWidth", 0)
	var right_width: int = _int(template, "RightWidth", 0)
	var repeat_width: int = _int(template, "RepeatWidth", 0)

	var holder: Control = Control.new()
	holder.name = "HStrip"
	holder.size = Vector2(width, strip_height)
	holder.custom_minimum_size = holder.size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var middle_width: int = maxi(0, width - left_width - right_width)
	var pieces: Array = [
		["Left", left_width, 0, left_width],
		["Repeat", repeat_width, left_width, middle_width],
		["Right", right_width, left_width + middle_width, right_width],
	]
	for piece: Array in pieces:
		var source_width: int = int(piece[1])
		var span: int = int(piece[3])
		if source_width <= 0 or span <= 0:
			continue
		var region: AtlasTexture = library.get_region(
			texture_name, _vec(texture_block, str(piece[0])),
			Vector2i(source_width, strip_height))
		if region == null:
			continue
		if str(piece[0]) == "Repeat":
			# AtlasTexture ne se répète pas fiablement avec STRETCH_TILE suivant le
			# backend. On pose donc chaque cellule à sa largeur native. Pour l'XP,
			# 90 px / 9 px donne exactement les dix bulles du client.
			var cursor := 0
			while cursor < span:
				var tile := TextureRect.new()
				tile.texture = region
				tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tile.stretch_mode = TextureRect.STRETCH_KEEP
				tile.position = Vector2(int(piece[2]) + cursor, 0)
				tile.size = Vector2(mini(source_width, span - cursor), strip_height)
				tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.set_meta("daoc_tiled_repeat", true)
				holder.add_child(tile)
				cursor += source_width
			continue
		var rect: TextureRect = TextureRect.new()
		rect.texture = region
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		# Sans cela, la taille minimale d'un TextureRect est celle de sa texture :
		# une tranche de 100 px refuse d'etre reduite a 90 et deborde du cadre.
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.position = Vector2(int(piece[2]), 0)
		rect.size = Vector2(span, strip_height)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	return holder


## Icone a plusieurs niveaux : `MaxLevels` vignettes rangees dans l'atlas, en
## colonne ou en ligne selon `Horizontal`. L'adaptateur donne le niveau a
## montrer, pas une image. Niveau 0 tant que rien n'est publie.
func _make_status_icon(def: Dictionary) -> Control:
	var template: Dictionary = _template("StatusIconTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var cell: Vector2i = Vector2i(_int(template, "Width", 0), _int(template, "Height", 0))
	if cell.x <= 0 or cell.y <= 0:
		return null

	var texture_name: String = _str(template, "TextureName", "")
	var start: Vector2i = _vec(template, "TextureStart")
	var levels: int = maxi(1, _int(template, "MaxLevels", 1))
	var horizontal: bool = _bool(template, "Horizontal")

	var rect: TextureRect = TextureRect.new()
	rect.name = "StatusIcon"
	rect.size = Vector2(cell)
	rect.custom_minimum_size = Vector2(cell)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frames: Array[AtlasTexture] = []
	for level: int in levels:
		var origin: Vector2i = start
		if horizontal:
			origin.x += level * cell.x
		else:
			origin.y += level * cell.y
		frames.append(library.get_region(texture_name, origin, cell))
	if frames.is_empty() or frames[0] == null:
		return null
	rect.texture = frames[0]

	var channel: String = _adapter_of(def)
	if channel != "":
		_bind(channel, rect, func(value: Variant) -> void:
			var level: int = clampi(int(value), 0, frames.size() - 1)
			if frames[level] != null:
				rect.texture = frames[level])
	return rect


## Bouton dont le fond est une bande a trois tranches. Ses champs `Normal`,
## `Pressed`... portent des NOMS de `HorizontalResizeImageTemplate`, comme les
## jauges - pas des coordonnees.
func _make_h_resize_button(def: Dictionary) -> Control:
	var template: Dictionary = _template("HorizontalResizeButtonTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var width: int = _int(def, "Width", 0)
	var height: int = _int(template, "Height", 0)
	if width <= 0 or height <= 0:
		return null

	var holder: Control = Control.new()
	holder.name = "HResizeButton"
	holder.size = Vector2(width, height)
	holder.custom_minimum_size = holder.size

	var background: Control = _h_resize_strip(_str(template, "Normal", ""), width)
	if background != null:
		holder.add_child(background)

	# P1-134 : training_window.xml ecrit le libelle dans `<Label>` (TRAIN, RESET...).
	var caption: String = _str(def, "Data", _str(def, "Label", ""))
	if caption == "":
		caption = _str(def, "Label", "")
	if caption != "":
		var label: Label = Label.new()
		label.text = caption
		label.size = holder.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_font(label, template.get("Font", {}))
		_fit_caption(label, holder.size)
		holder.add_child(label)

	var event: String = _event_of(def)
	if event != "":
		holder.set_meta("daoc_event", event)
	return holder


## Zone de texte defilante : un fond, puis le texte decale de `TextOffset`.
func _make_text_area(def: Dictionary) -> Control:
	var template: Dictionary = _template("TextAreaTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var size: Vector2i = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null

	var holder: Control = Control.new()
	holder.name = "TextArea"
	holder.size = Vector2(size)
	holder.custom_minimum_size = holder.size
	holder.clip_contents = true

	var background: Control = _full_resize_named(_str(template, "BackgroundTemplate", ""), size)
	if background != null:
		holder.add_child(background)

	var offset: Vector2i = _vec(template, "TextOffset")
	var text: RichTextLabel = RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = false
	text.scroll_active = true
	text.position = Vector2(offset)
	text.size = Vector2(size) - Vector2(offset) * 2.0
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(text, template.get("Font", {}))
	text.text = _str(def, "Data", "")
	holder.add_child(text)

	var channel: String = _adapter_of(def)
	if channel != "":
		_bind(channel, text, func(value: Variant) -> void: text.text = str(value))
	return holder


## Emplacement d'icone. L'ILLUSTRATION vient des planches `*_icons.xml`
## adressees par `IconId` : c'est un sous-systeme a part, hors de cette passe.
## L'emplacement est donc bati a sa taille exacte et COMPTE comme sans image,
## plutot que dessine en creux comme s'il etait complet.
func _make_icon(def: Dictionary) -> Control:
	var template: Dictionary = _template("IconTemplate", _str(def, "TemplateName", ""))
	var size: Vector2i = _vec(template, "Size") if not template.is_empty() else Vector2i.ZERO
	if size == Vector2i.ZERO:
		size = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null

	var slot: Control = Control.new()
	slot.name = "IconSlot"
	slot.size = Vector2(size)
	slot.custom_minimum_size = slot.size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("daoc_icon_id", _str(def, "IconId", ""))
	icon_slots_without_art += 1

	var channel: String = _adapter_of(def)
	if channel != "":
		_bind(channel, slot, func(value: Variant) -> void: slot.set_meta("daoc_icon_id", str(value)))
	return slot


## Liste : fond, puis une ligne de texte par entree publiee, dans un conteneur
## qui defile. Le tri et les colonnes restent a faire.
func _make_list_box(def: Dictionary) -> Control:
	var template: Dictionary = _template("ListBoxTemplate", _str(def, "TemplateName", ""))
	if template.is_empty():
		return null
	var size: Vector2i = Vector2i(_int(def, "Width", 0), _int(def, "Height", 0))
	if size.x <= 0 or size.y <= 0:
		return null

	var holder: Control = Control.new()
	holder.name = "ListBox"
	holder.size = Vector2(size)
	holder.custom_minimum_size = holder.size
	holder.clip_contents = true

	var background: Control = _full_resize_named(_str(template, "BackgroundTemplate", ""), size)
	if background != null:
		holder.add_child(background)

	# 2026-09-29 : une liste plus longue que sa fenetre defile (molette ou barre
	# verticale, qui n apparait que si le contenu deborde).
	var padding := Vector2(_int(template, "CellPadding", 0), _int(template, "LinePadding", 0))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = padding
	scroll.size = Vector2(size) - padding
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	holder.add_child(scroll)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", _int(template, "LinePadding", 0))
	scroll.add_child(rows)

	var font_block: Variant = template.get("TextFont", {})
	var channel: String = _adapter_of(def)
	if channel != "":
		_bind(channel, rows, func(value: Variant) -> void:
			for child: Node in rows.get_children():
				rows.remove_child(child)
				child.queue_free()
			for entry: Variant in (value if value is Array else [value]):
				rows.add_child(_make_list_row(entry, font_block)))
	return holder


## P1-83 — une ligne de liste est un texte nu, ou un dictionnaire
## `{text, state, on_click, drag}` : `state` choisit la couleur du gabarit
## (`normal`, `highlit`, `greyed`), `on_click` fait de la ligne un bouton plat,
## `drag` (une reference de sort/capacite) fait de la ligne une SOURCE DE
## GLISSER-DEPOSER vers les quickbars — P1-84 : dans DAoC tout passe par la
## barre, on glisse Sprint depuis la fenetre des capacites.
func _make_list_row(entry: Variant, font_block: Variant) -> Control:
	var data: Dictionary = entry as Dictionary if entry is Dictionary else {"text": str(entry)}
	var text := str(data.get("text", ""))
	var state := str(data.get("state", "normal"))
	var line: Control
	if data.has("drag") and data["drag"] is Dictionary:
		var drag_button: Button = DaocSpellDragButton.new()
		drag_button.flat = true
		drag_button.text = text
		drag_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		drag_button.focus_mode = Control.FOCUS_NONE
		for style_name in ["normal", "hover", "pressed", "focus"]:
			drag_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		drag_button.set_meta("spell_reference", (data["drag"] as Dictionary).duplicate(true))
		drag_button.tooltip_text = str(data.get("tooltip", "Glisser vers une quickbar"))
		if data.get("icon_texture") is Texture2D:
			drag_button.icon = data["icon_texture"]
			drag_button.expand_icon = true
			drag_button.add_theme_constant_override("icon_max_width", 16)
		# Une ligne glissable peut aussi s activer d un clic (Stealth).
		if data.get("on_click") is Callable:
			var drag_click: Callable = data["on_click"]
			drag_button.pressed.connect(func() -> void: drag_click.call())
		line = drag_button
	elif data.has("on_click") and data["on_click"] is Callable:
		var button := Button.new()
		button.flat = true
		button.text = text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var callable: Callable = data["on_click"]
		button.pressed.connect(func() -> void: callable.call())
		button.tooltip_text = str(data.get("tooltip", ""))
		if data.get("icon_texture") is Texture2D:
			button.icon = data["icon_texture"]
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 16)
			button.custom_minimum_size.y = 18
		line = button
	else:
		var label := Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line = label
	_apply_font(line, font_block)
	var block: Dictionary = font_block as Dictionary if font_block is Dictionary else {}
	var colour_key := "ColorHighlit" if state == "highlit" else ("ColorGreyed" if state == "greyed" else "")
	if colour_key != "" and block.has(colour_key):
		line.add_theme_color_override("font_color", _color(block[colour_key]))
	if line is Button:
		var base: Color = line.get_theme_color("font_color")
		line.add_theme_color_override("font_hover_color", base.lightened(0.35))
		line.add_theme_color_override("font_pressed_color", base)
		line.add_theme_color_override("font_focus_color", base)
	line.set_meta("daoc_list_state", state)
	return line


## Fond a neuf tranches designe par son NOM, pour les gabarits qui en citent un
## (`BackgroundTemplate` d'une liste ou d'une zone de texte).
func _full_resize_named(template_name: String, size: Vector2i) -> Control:
	if template_name == "" or template_name.to_lower() == "none":
		return null
	return _make_full_resize({
		"TemplateName": template_name,
		"Width": str(size.x),
		"Height": str(size.y),
	})


## Un bloc `<Font>` porte un nom de police et ses couleurs par etat.
func _apply_font(node: Control, block: Variant) -> void:
	var entry: Dictionary = block as Dictionary if block is Dictionary else {}
	if font != null:
		node.add_theme_font_override("font", font)
		if node is RichTextLabel:
			node.add_theme_font_override("normal_font", font)
	var font_name: String = _str(entry, "Name", "")
	var size: int = _font_size(font_name)
	node.add_theme_font_size_override("font_size", size)
	if node is RichTextLabel:
		node.add_theme_font_size_override("normal_font_size", size)
	if entry.has("ColorNormal"):
		node.add_theme_color_override("font_color", _color(entry["ColorNormal"]))
	elif entry.has("FontColor"):
		node.add_theme_color_override("font_color", _color(entry["FontColor"]))


# ---------------------------------------------------------------------------
# liaisons et polices

## `owner` est le noeud que la lambda pilote : le bus s'en sert pour oublier la
## liaison quand la fenetre est detruite.
func _bind(channel: String, owner: Object, handler: Callable) -> void:
	if bus == null:
		return
	bus.subscribe(channel, handler, owner)
	if not bound_channels.has(channel):
		bound_channels.append(channel)


## `Adapter`, `AdapterName` : deux balises, un seul mecanisme.
##
## La casse de la balise n'est PAS signifiante cote client - `summary.xml`
## ecrit `<Adaptername>` pour ses six barres d'etat, avec un `n` minuscule.
## Une recherche exacte ne trouvait rien, le controle n'etait relie a aucun
## canal, et sa tranche pleine restait donc a zero pixel : la barre de vie de
## la cible paraissait grise alors que la valeur arrivait bien sur le bus.
func _adapter_of(def: Dictionary) -> String:
	# L'ordre reste celui d'avant - `Adapter` d'abord - et ne depend donc pas de
	# l'ordre d'ecriture du fichier.
	for wanted: String in ["adapter", "adaptername"]:
		for key: String in def:
			if key.to_lower() != wanted:
				continue
			var value: String = _str(def, key, "")
			if value != "" and value.to_lower() != "none":
				return value
	return ""


func _event_of(def: Dictionary) -> String:
	for key: String in def:
		if key.to_lower() == "onclickevent":
			var value: String = str(def[key]).strip_edges()
			if value != "":
				return value
	return ""


## Les polices bitmap encodent leur taille dans le NOM du fichier
## (`button_10.tga`, `arial09.tga`) ; les TTF la declarent en clair.
func _read_fonts(contract: DaocUiSkinContract) -> void:
	for result: DaocUiParseResult in contract.files:
		if result.source_path.get_file().to_lower() != "assets.xml":
			continue
		var file: FileAccess = FileAccess.open(result.source_path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()

		var bitmap: RegEx = RegEx.new()
		bitmap.compile("<Font>\\s*<Name>([^<]+)</Name>\\s*<File>([^<]+)</File>")
		for found: RegExMatch in bitmap.search_all(text):
			font_sizes[found.get_string(1).strip_edges()] = _size_in_name(found.get_string(2))

		var ttf: RegEx = RegEx.new()
		ttf.compile("<TTFFont>\\s*<Name>([^<]+)</Name>\\s*<File>[^<]+</File>\\s*<Height>([0-9]+)</Height>")
		for found: RegExMatch in ttf.search_all(text):
			font_sizes[found.get_string(1).strip_edges()] = int(found.get_string(2))


func _size_in_name(file_name: String) -> int:
	var digits: RegEx = RegEx.new()
	digits.compile("([0-9]{1,2})")
	var found: RegExMatch = digits.search(file_name.get_file())
	if found == null:
		return DEFAULT_FONT_SIZE
	return clampi(int(found.get_string(1)), 6, 48)


func _font_size(font_name: String) -> int:
	return int(font_sizes.get(font_name.strip_edges(), DEFAULT_FONT_SIZE))


## Choix acte : tout en Arial au depart. Si la police systeme est absente, la
## police par defaut de Godot prend le relais et la PROVENANCE le declare.
func _load_font() -> void:
	var candidate: String = "C:/Windows/Fonts/arial.ttf"
	if FileAccess.file_exists(candidate):
		var loaded: FontFile = FontFile.new()
		if loaded.load_dynamic_font(candidate) == OK:
			font = loaded
			font_provenance = "ARIAL"
			return
	font = null
	font_provenance = "GODOT_DEFAULT"


# ---------------------------------------------------------------------------
# accesseurs de l'arbre XML

func _template(type_name: String, name: String) -> Dictionary:
	var clean: String = name.strip_edges()
	if clean == "" or clean.to_lower() == "none":
		return {}
	var by_name: Dictionary = templates.get(type_name, {}) as Dictionary
	if by_name.has(clean):
		return by_name[clean] as Dictionary
	var key: String = "%s/%s" % [type_name, clean]
	if not missing_templates.has(key):
		missing_templates.append(key)
	return {}


func _str(node: Dictionary, key: String, fallback: String) -> String:
	if not node.has(key):
		return fallback
	var value: Variant = node[key]
	if value is Dictionary or value is Array:
		return fallback
	return str(value).strip_edges()


func _int(node: Dictionary, key: String, fallback: int) -> int:
	var text: String = _str(node, key, "")
	return int(text) if text.is_valid_int() else fallback


func _bool(node: Dictionary, key: String) -> bool:
	return _str(node, key, "").to_lower() == "true"


func _bool_case_insensitive(node: Dictionary, wanted: String) -> bool:
	for key: String in node:
		if key.to_lower() == wanted.to_lower():
			return str(node[key]).strip_edges().to_lower() == "true"
	return false


func _vec(node: Dictionary, key: String) -> Vector2i:
	var block: Variant = node.get(key, null)
	if not (block is Dictionary):
		return Vector2i.ZERO
	var entry: Dictionary = block as Dictionary
	return Vector2i(_int(entry, "X", 0), _int(entry, "Y", 0))


func _color(block: Variant) -> Color:
	if not (block is Dictionary):
		return Color(1, 1, 1, 1)
	var entry: Dictionary = block as Dictionary
	return Color8(
		_int(entry, "R", 255), _int(entry, "G", 255),
		_int(entry, "B", 255), _int(entry, "A", 255))


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return [value]


## P1-134 — un bouton bati depuis son seul gabarit (la croix `window_close`
## que le moteur pose sur les fenetres a `CloseButton`).
func make_named_button(template_name: String) -> TextureButton:
	return _make_button({"TemplateName": template_name}) as TextureButton


## 2026-09-30 — un libelle de bouton ou d etiquette tient DANS sa case, centre :
## la police de substitution est plus large que celle du client (barb10, etc.)
## et debordait (« ATTACK » coupe, texte descendu sous le bouton). On reduit la
## taille jusqu a ce que la ligne tienne en largeur ET en hauteur ; en dernier
## recours, des points de suspension. La taille du controle ne bouge jamais.
const CAPTION_MIN_FONT := 7


func _fit_caption(label: Label, box: Vector2, shrink_to_width: bool = true) -> void:
	if label == null or box.x <= 0.0 or box.y <= 0.0:
		return
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_constant_override("line_spacing", 0)
	var empty := StyleBoxEmpty.new()
	label.add_theme_stylebox_override("normal", empty)
	var used_font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if used_font != null and label.text != "":
		var text := label.text.split("\n")[0]
		while font_size > CAPTION_MIN_FONT and (
				(shrink_to_width and used_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > box.x - 4.0)
				or used_font.get_height(font_size) > box.y + 1.0):
			font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)
	label.position = Vector2.ZERO
	label.custom_minimum_size = Vector2.ZERO
	label.size = box
	# Hors de l arbre, le Label se mesure avec la police par defaut (16 px) et
	# refuse de descendre sous cette taille : on la repose a son entree.
	label.tree_entered.connect(func() -> void:
		var keep := label.position
		label.update_minimum_size()
		(func() -> void:
			if is_instance_valid(label):
				label.size = box
				label.position = keep).call_deferred(), CONNECT_ONE_SHOT)
