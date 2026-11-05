extends CanvasLayer
class_name DaocCombatHud

## P1-21A — affichage minimal du combat.
##
## PROVISOIRE ASSUME. Le client d'origine decrit ses fenetres en XML dans
## `ui/isles/*.xml` (67 fenetres, skins TGA, atlas d'icones). Les relire est un
## jalon a part entiere. En attendant, ce HUD montre ce que l'autorite locale
## sait deja dire, sans rien inventer de plus : vie du joueur, vie de la cible,
## journal de combat.
##
## Il ne calcule RIEN. Il n'affiche que ce que `DaocLocalServer` lui envoie.

const LOG_LINES: int = 8

var log_limit: int = LOG_LINES
var show_status_panels: bool = true

var _root: Control = null
var _player_name: Label = null
var _player_bar: ProgressBar = null
var _player_values: Label = null
var _target_panel: PanelContainer = null
var _target_name: Label = null
var _target_bar: ProgressBar = null
var _target_values: Label = null
var _log_label: Label = null
var _hint: Label = null
var _lines: Array[String] = []
var _log_panel: PanelContainer = null
## 2026-09-15 : quand une console existe (DaocTextWindows), le journal y part et
## le panneau provisoire se cache. Le HUD garde ses jauges de repli.
var console_target: Node = null


func _ready() -> void:
	_build()


func _build() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "CombatHudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- joueur, en haut a gauche ---
	var player_panel: PanelContainer = _make_panel()
	player_panel.position = Vector2(16, 16)
	player_panel.custom_minimum_size = Vector2(260, 0)
	_root.add_child(player_panel)
	var player_box: VBoxContainer = VBoxContainer.new()
	player_panel.add_child(player_box)
	_player_name = _make_label("", 15)
	player_box.add_child(_player_name)
	_player_bar = _make_bar(Color(0.30, 0.72, 0.30))
	player_box.add_child(_player_bar)
	_player_values = _make_label("", 12)
	player_box.add_child(_player_values)

	# --- cible, en haut au centre ---
	_target_panel = _make_panel()
	_target_panel.anchor_left = 0.5
	_target_panel.anchor_right = 0.5
	_target_panel.offset_left = -140.0
	_target_panel.offset_right = 140.0
	_target_panel.offset_top = 16.0
	_target_panel.custom_minimum_size = Vector2(280, 0)
	_root.add_child(_target_panel)
	var target_box: VBoxContainer = VBoxContainer.new()
	_target_panel.add_child(target_box)
	_target_name = _make_label("", 15)
	target_box.add_child(_target_name)
	_target_bar = _make_bar(Color(0.78, 0.26, 0.24))
	target_box.add_child(_target_bar)
	_target_values = _make_label("", 12)
	target_box.add_child(_target_values)
	_target_panel.visible = false
	if not show_status_panels:
		player_panel.visible = false
		_target_panel.visible = false

	# --- journal, en bas a gauche ---
	var log_panel: PanelContainer = _make_panel()
	_log_panel = log_panel
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 16.0
	log_panel.offset_right = 476.0
	log_panel.offset_top = -186.0
	log_panel.offset_bottom = -16.0
	log_panel.custom_minimum_size = Vector2(460, 0)
	_root.add_child(log_panel)
	_log_label = _make_label("", 13)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_panel.add_child(_log_label)

	# --- rappel des touches ---
	_hint = _make_label("", 12)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -430.0
	_hint.offset_top = -34.0
	_hint.offset_right = -16.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_hint)
	if not show_status_panels:
		_hint.visible = false


func set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func update_player(snapshot: Dictionary) -> void:
	if _player_name == null or snapshot.is_empty():
		return
	_player_name.text = "%s  (niv %d)" % [str(snapshot.get("name", "?")), int(snapshot.get("level", 0))]
	var max_health: int = maxi(1, int(snapshot.get("max_health", 1)))
	var health: int = int(snapshot.get("health", 0))
	_player_bar.max_value = max_health
	_player_bar.value = health
	var suffix: String = "" if bool(snapshot.get("is_alive", true)) else "   — MORT"
	_player_values.text = "%d / %d PV%s" % [health, max_health, suffix]


func update_target(snapshot: Dictionary, distance_raw: float, in_range: bool) -> void:
	if _target_panel == null:
		return
	if not show_status_panels:
		_target_panel.visible = false
		return
	if snapshot.is_empty():
		_target_panel.visible = false
		return
	_target_panel.visible = true
	_target_name.text = "%s  (niv %d)" % [str(snapshot.get("name", "?")), int(snapshot.get("level", 0))]
	var max_health: int = maxi(1, int(snapshot.get("max_health", 1)))
	var health: int = int(snapshot.get("health", 0))
	_target_bar.max_value = max_health
	_target_bar.value = health
	var percent: float = float(health) * 100.0 / float(max_health)
	var range_text: String = "a portee" if in_range else "trop loin"
	if not bool(snapshot.get("is_alive", true)):
		range_text = "mort"
	_target_values.text = "%d %%   ·   %.0f unites   ·   %s" % [percent, distance_raw, range_text]


func clear_target() -> void:
	if _target_panel != null:
		_target_panel.visible = false


func set_console_target(target: Node) -> void:
	console_target = target
	if _log_panel != null:
		_log_panel.visible = target == null
	if target != null and target.has_method("push_console_line"):
		for line in _lines:
			target.call("push_console_line", line)


func push_line(text: String) -> void:
	if text.strip_edges() == "":
		return
	if console_target != null and is_instance_valid(console_target) and console_target.has_method("push_console_line"):
		console_target.call("push_console_line", text)
	_lines.append(text)
	while _lines.size() > log_limit:
		_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_lines)


func get_debug_snapshot() -> Dictionary:
	return {
		"lines": _lines.size(),
		"target_visible": _target_panel != null and _target_panel.visible,
		"built": _root != null,
	}


# --------------------------------------------------------------------------

func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.62)
	style.border_color = Color(0.62, 0.56, 0.36, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _make_label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_bar(fill: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.10, 0.10, 0.12, 0.85)
	background.set_corner_radius_all(2)
	var foreground: StyleBoxFlat = StyleBoxFlat.new()
	foreground.bg_color = fill
	foreground.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", foreground)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
