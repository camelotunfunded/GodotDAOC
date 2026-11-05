extends CanvasLayer
class_name DaocMinimapWindow

## 2026-09-30 — la carte de zone, comme la fenetre « map_window » du client
## d origine : titre = nom de la zone (zones.dat), l image `ui/maps/zNNN.png`
## du client (256 px pour les 65 536 unites d une zone, nord en haut), le
## joueur en fleche jaune, PNJ et joueurs proches en points. Deplacable,
## fermable, transparence au clic droit (DaocWindowDrag, par DaocGameWorld).
## /map la montre ou la cache.

const ZONE_UNITS := 65536.0
const MAP_SIZE := 240.0

var client_root := ""
## Fournis par le monde a chaque image : zone, position DAoC locale, direction.
var zone_id := -1
var player_zone_xy := Vector2.ZERO
var player_forward := Vector2(0, -1)
## Points [Vector2 zone_xy, Color].
var markers: Array = []

var _panel: PanelContainer = null
var _title: Label = null
var _map: TextureRect = null
var _overlay: Control = null
var _loaded_zone := -2
var _zone_names := {}


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.name = "MinimapWindow"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.92)
	style.border_color = Color(0.55, 0.45, 0.28)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.custom_minimum_size = Vector2(MAP_SIZE - 30.0, 0)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	box.add_child(_title)
	_map = TextureRect.new()
	_map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.set_meta("daoc_no_fade", true)
	box.add_child(_map)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_map.add_child(_overlay)
	_panel.add_child(box)
	add_child(_panel)
	_panel.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = Vector2(viewport_size.x - MAP_SIZE - 24.0, viewport_size.y - MAP_SIZE - 150.0)
	_panel.visible = bool(DaocGraphicsOptionsWindow.load_option("minimap", "visible", true))


func toggle() -> void:
	set_shown(not _panel.visible)


func set_shown(value: bool) -> void:
	if _panel == null:
		return
	_panel.visible = value
	DaocGraphicsOptionsWindow.save_option("minimap", "visible", value)


func hide_window() -> void:
	set_shown(false)


func is_shown() -> bool:
	return _panel != null and _panel.visible


func update_view(p_zone: int, p_xy: Vector2, p_forward: Vector2, p_markers: Array) -> void:
	zone_id = p_zone
	player_zone_xy = p_xy
	if p_forward.length_squared() > 0.0001:
		player_forward = p_forward.normalized()
	markers = p_markers
	if _panel == null or not _panel.visible:
		return
	if _loaded_zone != zone_id:
		_load_zone(zone_id)
	_overlay.queue_redraw()


func _load_zone(zone: int) -> void:
	_loaded_zone = zone
	_title.text = zone_name(zone)
	var texture: Texture2D = null
	for relative in ["ui/maps/z%03d.png" % zone, "ui/custom/Maps/z%03d.png" % zone, "ui/maps/no_map.png"]:
		var path := client_root.path_join(relative)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
				break
	_map.texture = texture


func zone_name(zone: int) -> String:
	if _zone_names.is_empty():
		_zone_names = _read_zone_names(client_root.path_join("zones/zones/zones.dat"))
	return str(_zone_names.get(zone, "Zone %d" % zone))


static func _read_zone_names(path: String) -> Dictionary:
	var names := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return names
	var current := -1
	while not file.eof_reached():
		# « [zone051] ;Briton Expansion » : le commentaire suit l en-tete.
		var line := file.get_line().get_slice(";", 0).strip_edges()
		if line.begins_with("["):
			current = line.substr(5, line.length() - 6).to_int() if line.begins_with("[zone") and line.ends_with("]") else -1
		elif current >= 0 and line.to_lower().begins_with("name="):
			names[current] = line.substr(5).strip_edges()
	return names


func _to_map(zone_xy: Vector2) -> Vector2:
	return zone_xy / ZONE_UNITS * _overlay.size


func _draw_overlay() -> void:
	for value in markers:
		var marker := value as Array
		var point := _to_map(marker[0] as Vector2)
		if Rect2(Vector2.ZERO, _overlay.size).has_point(point):
			_overlay.draw_circle(point, 2.0, marker[1] as Color)
	var center := _to_map(player_zone_xy)
	var forward := player_forward
	var side := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([center + forward * 10.0, center - forward * 6.0 + side * 6.0, center - forward * 2.0, center - forward * 6.0 - side * 6.0])
	_overlay.draw_colored_polygon(arrow, Color(1.0, 0.85, 0.1))
	_overlay.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.05, 0.0), 1.0)
