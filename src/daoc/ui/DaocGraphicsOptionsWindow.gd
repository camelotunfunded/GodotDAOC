extends CanvasLayer
class_name DaocGraphicsOptionsWindow

## 2026-09-27 — la fenetre d options graphiques (/options en jeu, bouton
## Options de l ecran de selection). Premier reglage : la densite de l herbe.
## Les choix sont memorises dans user://daoc_options.cfg.

signal grass_detail_changed(level: int)
signal ui_scale_changed(value: float)
signal animation_polish_changed(enabled: bool)

const CONFIG_PATH := "user://daoc_options.cfg"
const GRASS_LEVELS := ["Bas (plus rapide)", "Moyen", "Eleve (plus beau)"]
const UI_SCALES := [0.70, 0.85, 1.0, 1.15]

var grass_detail_level := 2
var _panel: PanelContainer = null
var _grass: OptionButton = null
var _ui_scale: OptionButton = null


static func load_grass_detail_level(fallback: int = 2) -> int:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return fallback
	return clampi(int(config.get_value("graphics", "grass_detail_level", fallback)), 0, GRASS_LEVELS.size() - 1)


static func save_grass_detail_level(level: int) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("graphics", "grass_detail_level", level)
	config.save(CONFIG_PATH)


static func load_option(section: String, key: String, fallback: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return fallback
	return config.get_value(section, key, fallback)


static func save_option(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)


func _ready() -> void:
	# Le frontend pré-jeu vit sur la couche 100 : la fenêtre doit être au-dessus.
	layer = 110
	_panel = PanelContainer.new()
	_panel.name = "GraphicsOptionsWindow"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-220, -220)
	_panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Options de jeu"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(title)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Densite de l'herbe"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_grass = OptionButton.new()
	for index in GRASS_LEVELS.size():
		_grass.add_item(str(GRASS_LEVELS[index]), index)
	_grass.item_selected.connect(func(index: int) -> void: set_grass_detail_level(index))
	row.add_child(_grass)
	box.add_child(row)
	_ui_scale = OptionButton.new()
	for value in UI_SCALES:
		_ui_scale.add_item("%d %%" % roundi(float(value) * 100.0))
	var saved_scale := float(load_option("interface", "scale", 1.0))
	var scale_index := UI_SCALES.find(saved_scale)
	_ui_scale.select(maxi(0, scale_index))
	_ui_scale.item_selected.connect(_on_ui_scale_selected)
	box.add_child(_option_row("Taille de l'interface", _ui_scale))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Plein écran"
	fullscreen.button_pressed = bool(load_option("display", "fullscreen", false))
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	box.add_child(fullscreen)
	var vsync := CheckButton.new()
	vsync.text = "Synchronisation verticale"
	vsync.button_pressed = bool(load_option("display", "vsync", true))
	vsync.toggled.connect(_on_vsync_toggled)
	box.add_child(vsync)
	var vanilla_title := Label.new()
	vanilla_title.text = "Vanilla +"
	vanilla_title.add_theme_color_override("font_color", Color(0.84, 0.72, 0.44))
	box.add_child(vanilla_title)
	var animation_polish := CheckButton.new()
	animation_polish.name = "SmoothAnimationsToggle"
	animation_polish.text = "Animations adoucies"
	animation_polish.tooltip_text = "Interpolation plus douce et transitions fondues (désactivable instantanément)."
	animation_polish.button_pressed = bool(load_option("animations", "smooth_playback", true))
	animation_polish.toggled.connect(_on_animation_polish_toggled)
	box.add_child(animation_polish)
	box.add_child(_saved_toggle("Papillons localisés", "butterflies", true))
	box.add_child(_saved_toggle("Feuilles sous les arbres", "falling_leaves", true))
	# 2026-09-30 : les noms au-dessus des tetes (/shownames, /hidenames du client d origine).
	var names_title := Label.new()
	names_title.text = "Noms affichés"
	names_title.add_theme_color_override("font_color", Color(0.84, 0.72, 0.44))
	box.add_child(names_title)
	for entry in [["Mon nom", "self"], ["Autres joueurs", "players"], ["PNJ et monstres", "monsters"]]:
		box.add_child(_names_toggle(str(entry[0]), str(entry[1])))
	var hint := Label.new()
	hint.text = "Plus dense = l'herbe couvre plus loin, mais coute plus cher."
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	box.add_child(close)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)
	grass_detail_level = load_grass_detail_level(grass_detail_level)
	_grass.select(grass_detail_level)


func set_grass_detail_level(level: int) -> void:
	grass_detail_level = clampi(level, 0, GRASS_LEVELS.size() - 1)
	if _grass != null and _grass.selected != grass_detail_level:
		_grass.select(grass_detail_level)
	save_grass_detail_level(grass_detail_level)
	grass_detail_changed.emit(grass_detail_level)


func toggle() -> void:
	_panel.visible = not _panel.visible


func show_window() -> void:
	if _panel == null:
		call_deferred("show_window")
		return
	_panel.visible = true


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _option_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row


func _saved_toggle(caption: String, key: String, fallback: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(load_option("vanilla_plus", key, fallback))
	toggle.toggled.connect(func(value: bool) -> void: save_option("vanilla_plus", key, value))
	return toggle


## Coche le meme [names] que DaocNameplates ; le gestionnaire le relit.
func _names_toggle(caption: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(load_option("names", key, true))
	toggle.toggled.connect(func(value: bool) -> void:
		save_option("names", key, value)
		for node in get_tree().get_nodes_in_group("daoc_nameplates"):
			node.call("load_settings"))
	return toggle


func _on_ui_scale_selected(index: int) -> void:
	var value := float(UI_SCALES[clampi(index, 0, UI_SCALES.size() - 1)])
	save_option("interface", "scale", value)
	ui_scale_changed.emit(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	save_option("display", "fullscreen", enabled)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_vsync_toggled(enabled: bool) -> void:
	save_option("display", "vsync", enabled)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


func _on_animation_polish_toggled(enabled: bool) -> void:
	save_option("animations", "smooth_playback", enabled)
	animation_polish_changed.emit(enabled)
