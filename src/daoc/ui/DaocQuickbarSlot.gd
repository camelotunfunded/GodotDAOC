extends Panel
class_name DaocQuickbarSlot

## Une case de barre. Le sort s'y glisse depuis le grimoire ; UN clic gauche le
## lance (demande du 2026-09-15 : pas de double clic, comme le client d'origine),
## le clic droit le retire. L'icone est celle du client (DaocSpellIconAtlas).

signal spell_dropped(bar_index: int, slot_index: int, spell: Dictionary)
signal clear_requested(bar_index: int, slot_index: int)
signal activation_requested(bar_index: int, slot_index: int)
var bar_index := 0
var slot_index := 0
var reference: Dictionary = {}
var icon_atlas: RefCounted = null
var _icon: TextureRect = null
## P1-113 : (bar, slot) -> bool. Quand la souris PORTE une icone (macro
## fraichement creee, ou icone reprise d une autre case), un clic gauche la
## DEPOSE ici au lieu d activer la case ; le rappel rend true s il a consomme.
var carry_drop_handler: Callable = Callable()
var _macro_badge: Label = null


func setup(p_bar: int, p_slot: int) -> void:
	bar_index = p_bar
	slot_index = p_slot
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.position = Vector2(1, 1)
		_icon.size = size - Vector2(2, 2)
		_icon.stretch_mode = TextureRect.STRETCH_SCALE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
	refresh({})


func refresh(value: Dictionary) -> void:
	reference = value.duplicate(true)
	tooltip_text = "Quickbar %d — case %d (vide)" % [bar_index + 1, slot_index + 1] if reference.is_empty() else "%s\nClic gauche : lancer · clic droit : retirer" % str(reference.get("name", "Sort"))
	if str(reference.get("kind", "")) == "macro":
		tooltip_text = "Macro %s\n%s\nClic gauche : executer · clic droit : retirer" % [str(reference.get("name", "")), str(reference.get("command", ""))]
	if _icon != null:
		_icon.size = size - Vector2(2, 2)
		var texture: Texture2D = null
		if not reference.is_empty() and str(reference.get("kind", "")) == "item" and icon_atlas != null and icon_atlas.has_method("texture_for_item_model"):
			# P1-98 : un objet porte l icone de son modele (objects.csv -> itm_/wpn_).
			texture = icon_atlas.call("texture_for_item_model", int(reference.get("model", 0))) as Texture2D
		elif not reference.is_empty() and icon_atlas != null and icon_atlas.has_method("texture_for"):
			texture = icon_atlas.call("texture_for", int(reference.get("icon", 0)), str(reference.get("icon_family", "spell"))) as Texture2D
		_icon.texture = texture
		_icon.visible = texture != null
	_refresh_macro_badge()
	if disabled_seconds > 0.0:
		set_disabled(0.0)  # P1-108 : une case reassignee repart normale, le prochain tic la regrise si besoin


func has_icon() -> bool:
	return (_icon != null and _icon.texture != null) or (_macro_badge != null and _macro_badge.visible)


## P1-113 — une macro n a pas d icone dans le client : elle se dessine en
## GRIS, a la taille d une case de sort, avec les premieres lettres de son
## nom (retour utilisateur du 2026-09-22). Statique, partage avec l icone
## portee par la souris (DaocQuickbars.make_macro_icon).
static func macro_icon_text(name: String) -> String:
	var clean := name.strip_edges()
	return clean.substr(0, 4).to_upper() if clean != "" else "MAC"


static func style_macro_panel(panel: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.42, 0.44, 0.95)
	style.border_color = Color(0.72, 0.72, 0.74, 1.0)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)


func _refresh_macro_badge() -> void:
	var is_macro := str(reference.get("kind", "")) == "macro"
	if _macro_badge == null:
		if not is_macro:
			return
		var panel := Panel.new()
		panel.name = "MacroIcon"
		panel.position = Vector2(1, 1)
		panel.size = size - Vector2(2, 2)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_macro_panel(panel)
		add_child(panel)
		_macro_badge = Label.new()
		_macro_badge.name = "MacroText"
		_macro_badge.add_theme_font_size_override("font_size", 9)
		_macro_badge.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		_macro_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_macro_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_macro_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_macro_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(_macro_badge)
	_macro_badge.get_parent().visible = is_macro
	_macro_badge.visible = is_macro
	if is_macro:
		_macro_badge.text = macro_icon_text(str(reference.get("name", "")))


## P1-108 — le grise de delai vient du SERVEUR (0xD6 DisableSkills) : la case
## s assombrit et affiche les secondes restantes, comme dans le client
## d origine ; 0 rend la case normale. Le clic reste possible (le serveur
## refuse lui-meme un sort en delai), seul l aspect change.
var disabled_seconds := 0.0
var _cooldown: Label = null


func set_disabled(seconds: float) -> void:
	disabled_seconds = maxf(0.0, seconds)
	if _icon != null:
		_icon.modulate = Color(0.35, 0.35, 0.35) if disabled_seconds > 0.0 else Color.WHITE
	if _cooldown == null:
		_cooldown = Label.new()
		_cooldown.name = "Cooldown"
		_cooldown.add_theme_font_size_override("font_size", 10)
		_cooldown.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		_cooldown.add_theme_color_override("font_shadow_color", Color.BLACK)
		_cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_cooldown)
	_cooldown.visible = disabled_seconds > 0.0
	if disabled_seconds > 0.0:
		_cooldown.text = str(ceili(disabled_seconds)) if disabled_seconds < 100.0 else "%dm" % int(disabled_seconds / 60.0)


func is_disabled() -> bool:
	return disabled_seconds > 0.0


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str((data as Dictionary).get("kind", "")) in ["spell", "item"]


func _drop_data(_position: Vector2, data: Variant) -> void:
	spell_dropped.emit(bar_index, slot_index, (data as Dictionary).duplicate(true))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		# P1-113 : la souris porte une icone -> le clic gauche la depose ici.
		if mouse.button_index == MOUSE_BUTTON_LEFT and carry_drop_handler.is_valid() \
				and bool(carry_drop_handler.call(bar_index, slot_index)):
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			clear_requested.emit(bar_index, slot_index)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.double_click and not reference.is_empty():
			activation_requested.emit(bar_index, slot_index)
			accept_event()
