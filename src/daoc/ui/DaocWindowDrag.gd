extends RefCounted
class_name DaocWindowDrag

## P1-129 — toute fenetre de l interface se deplace, comme dans le client
## d origine : clic gauche maintenu sur son FOND (les boutons, listes et champs
## gardent leurs clics, les etiquettes laissent passer). La fenetre reste dans
## l ecran. Les fenetres XML ont deja leur poignee (DaocUiWindowManager).

const META_DRAGGABLE := "daoc_window_draggable"


static func make_draggable(panel: Control) -> bool:
	if panel == null or panel.has_meta(META_DRAGGABLE):
		return false
	# P1-130 : un conteneur TRANSPARENT aux clics n est pas une fenetre. La racine
	# plein ecran de DaocUiWindowManager (IGNORE) rendue STOP par P1-129b avalait
	# TOUS les clics sur le monde : plus de ciblage a la souris (soi compris).
	if panel.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	panel.set_meta(META_DRAGGABLE, true)
	var state := {"dragging": false, "offset": Vector2.ZERO}
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			state["dragging"] = (event as InputEventMouseButton).pressed
			state["offset"] = panel.global_position - (event as InputEventMouseButton).global_position
			if bool(state["dragging"]):
				panel.accept_event()
		elif event is InputEventMouseMotion and bool(state["dragging"]) and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			state["dragging"] = false  # relachement perdu : la fenetre est posee
		elif event is InputEventMouseMotion and bool(state["dragging"]):
			var viewport_size := panel.get_viewport_rect().size
			var target := (event as InputEventMouseMotion).global_position + (state["offset"] as Vector2)
			panel.global_position = target.clamp(Vector2.ZERO, (viewport_size - panel.size).max(Vector2.ZERO))
			panel.accept_event())
	return true


## Le panneau d une fenetre du projet : `_panel` (fenetres Godot) ou `_root`
## (inventaire pperdoll). Rien pour une couche sans l un ni l autre.
static func window_panel(layer: Node) -> Control:
	if layer == null or not (layer is CanvasLayer):
		return null
	for property in ["_panel", "_root"]:
		var value: Variant = layer.get(property)
		if value is Control and is_instance_valid(value):
			return value as Control
	return null


const META_CLOSABLE := "daoc_window_closable"


## 2026-09-29 — toute fenetre du projet se ferme : un bouton « × » dans son
## coin haut droit (frere du panneau dans la meme couche, donc au-dessus de
## lui). La fermeture passe par `hide_window()` quand la fenetre l expose
## (etat interne), sinon le panneau est simplement cache.
static func add_close_button(layer: Node, panel: Control) -> Button:
	if layer == null or panel == null or panel.has_meta(META_CLOSABLE):
		return null
	if panel.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return null
	panel.set_meta(META_CLOSABLE, true)
	var button := Button.new()
	button.name = "DaocCloseButton"
	button.text = "×"
	button.tooltip_text = "Fermer"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(20, 20)
	button.add_theme_font_size_override("font_size", 14)
	layer.add_child(button)
	var place := func() -> void:
		if not is_instance_valid(button) or not is_instance_valid(panel):
			return
		button.visible = panel.is_visible_in_tree()
		button.reset_size()
		button.global_position = panel.global_position + Vector2(panel.size.x - button.size.x - 3.0, 3.0)
	panel.item_rect_changed.connect(place)
	panel.visibility_changed.connect(place)
	button.pressed.connect(func() -> void:
		if layer.has_method("hide_window"):
			layer.call("hide_window")
		else:
			panel.visible = false
		place.call())
	place.call()
	return button


## ═══════════════════════════════════════════════════════════════════════════
## 2026-09-30 — TRANSPARENCE DES FENETRES
##
## Comme le client d origine : clic droit sur le fond d une fenetre -> un menu
## d opacite. Seuls les FONDS s estompent (panneaux, cadres, grandes images) :
## textes, boutons et icones restent nets. Choix memorise par fenetre dans
## user://daoc_options.cfg, section [window_opacity].
## ═══════════════════════════════════════════════════════════════════════════
const META_OPACITY := "daoc_window_opacity_key"
const OPACITY_CONFIG := "user://daoc_options.cfg"
const OPACITY_STEPS := [100, 90, 80, 70, 60, 50, 40, 30]
## En dessous de cette aire (px²), une image est une icone, pas un fond.
const BACKGROUND_MIN_AREA := 1500.0


static func add_opacity_menu(panel: Control, key: String, extra_inputs: Array = []) -> bool:
	if panel == null or key == "" or panel.has_meta(META_OPACITY):
		return false
	panel.set_meta(META_OPACITY, key)
	var popup := PopupMenu.new()
	popup.name = "DaocOpacityMenu"
	for step in OPACITY_STEPS:
		popup.add_item("Opacite %d %%" % step, int(step))
	panel.add_child(popup)
	popup.id_pressed.connect(func(id: int) -> void:
		set_window_opacity(panel, float(id) / 100.0)
		_store_opacity(key, float(id) / 100.0))
	var on_input := func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			var viewport := panel.get_viewport()
			popup.position = Vector2i(viewport.get_mouse_position()) if viewport.gui_embed_subwindows else DisplayServer.mouse_get_position()
			popup.popup()
			panel.accept_event()
	panel.gui_input.connect(on_input)
	for value in extra_inputs:
		var control := value as Control
		if control != null and control != panel:
			control.gui_input.connect(on_input)
	var stored := _load_opacity(key)
	if stored < 0.999:
		# La fenetre batit parfois son contenu apres coup : appliquer une trame plus tard aussi.
		set_window_opacity(panel, stored)
		(func() -> void:
			if is_instance_valid(panel):
				set_window_opacity(panel, stored)).call_deferred()
	return true


static func set_window_opacity(panel: Control, alpha: float) -> void:
	if panel == null:
		return
	alpha = clampf(alpha, 0.1, 1.0)
	panel.set_meta("daoc_window_opacity", alpha)
	_fade_backgrounds(panel, alpha)


static func _fade_backgrounds(node: Node, alpha: float) -> void:
	var control := node as CanvasItem
	if control != null and _is_background(node):
		var tint := control.self_modulate
		tint.a = alpha
		control.self_modulate = tint
	for child in node.get_children():
		if child is Label or child is BaseButton or child is RichTextLabel or child is LineEdit or child is TextEdit or child is Window:
			continue
		_fade_backgrounds(child, alpha)


static func _is_background(node: Node) -> bool:
	if node.has_meta("daoc_no_fade"):
		return false
	if node is Panel or node is PanelContainer or node is NinePatchRect or node is ColorRect:
		return true
	if node is TextureRect:
		var size := (node as Control).size
		return size.x * size.y >= BACKGROUND_MIN_AREA
	return false


static func _load_opacity(key: String) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(OPACITY_CONFIG) != OK:
		return 1.0
	return float(cfg.get_value("window_opacity", key, 1.0))


static func _store_opacity(key: String, alpha: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(OPACITY_CONFIG)
	cfg.set_value("window_opacity", key, alpha)
	cfg.save(OPACITY_CONFIG)
