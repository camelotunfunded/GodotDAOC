extends CanvasLayer
class_name DaocAlphaInventory

## Inventaire d'alpha adosse a la planche originale Atlantis.
## `data/atlantis/pperdoll.bmp` est la fenetre complete 192 x 448 : cadre,
## emplacements d'equipement, sacs et libelles. Le moteur ne superpose que les
## valeurs vivantes que la bitmap ne peut pas contenir.

const SIZE := Vector2(192, 448)
const SOURCE_RELATIVE_PATH := "data/atlantis/pperdoll.bmp"
const EQUIPMENT_SLOT_COUNT := 19
const BAG_SLOT_COUNT := 5
const CharacterPreviewScene := preload("res://scenes/ui/pregame/DaocCharacterPreview.tscn")
const EquipmentVisualsScript := preload("res://src/daoc/player/DaocPlayerEquipmentVisuals.gd")

## P1-93 — la fenetre devient VIVANTE : les logements d'equipement et les huit
## lignes du sac courant lisent l'instantane de DaocPlayerInventory, et un
## double clic demande a l'arbitre d'equiper (ligne du sac) ou de retirer
## (logement). Elle ne decide rien : elle relit l'instantane qui revient.
##
## Rectangles releves sur `pperdoll.bmp` (192 x 448), en pixels de la planche.
const EQUIPMENT_SLOT_RECTS := {
	25: Rect2(7, 38, 31, 30),    # TORSO
	29: Rect2(40, 37, 15, 13),   # NECK
	37: Rect2(72, 38, 13, 12),   # MYTHICAL
	26: Rect2(137, 37, 14, 13),  # CLOAK
	21: Rect2(154, 38, 32, 30),  # HELM
	28: Rect2(7, 77, 31, 30),    # ARMS
	22: Rect2(154, 77, 32, 30),  # HANDS
	24: Rect2(7, 117, 15, 15),   # JWLRY
	32: Rect2(172, 117, 14, 15), # WAIST
	35: Rect2(7, 143, 15, 15),   # L RING
	36: Rect2(172, 143, 14, 15), # R RING
	33: Rect2(7, 168, 15, 15),   # L WRIST
	34: Rect2(172, 168, 14, 15), # R WRIST
	27: Rect2(7, 197, 31, 30),   # LEGS
	23: Rect2(154, 197, 32, 30), # FEET
	10: Rect2(13, 237, 32, 30),  # R HAND
	11: Rect2(57, 237, 32, 30),  # L HAND
	12: Rect2(102, 237, 32, 30), # 2-HAND
	13: Rect2(146, 237, 32, 30), # RANGED
}
const BAG_ROW_Y := [281, 298, 315, 331, 348, 365, 381, 398]
const BAG_ROW_RECT := Rect2(13, 0, 153, 15)
const BAG_TAB_Y := [285, 310, 335, 360, 385]
const BAG_TAB_RECT := Rect2(170, 0, 20, 22)
const BAG_ROWS := 8
const FIRST_BACKPACK := 40

var _root: Control = null
var _visible := false
var _client_root := ""
var _source_path := ""
var _texture_loaded := false
var _fallback_reason := "not_built"
var _authority: Node = null
var _snapshot: Dictionary = {}
var _name_label: Label = null
## P1-114 — la bourse (0xFA) et l encombrement (0xBD) de la planche pperdoll.
var _money_label: Label = null
var _encumberance_label: Label = null
var money_copper := 0
var encumberance_current := 0
var encumberance_maximum := 0
var _current_bag := 0
var _slot_labels: Dictionary = {}
## P1-96 : icones des objets (planches itm_/wpn_ du client) par logement et par ligne du sac.
var _slot_icons: Dictionary = {}
var _row_icons: Array = []
var _icon_atlas: RefCounted = null
var _icon_report: Dictionary = {}
var _row_labels: Array = []
var _row_buttons: Array = []
var _slot_buttons: Dictionary = {}
## P1-98 : un objet glisse d un logement a un autre (from, to en eInventorySlot).
signal move_requested(from_slot: int, to_slot: int)
## P1-121 : objet lache sur le monde (a donner a ce qui est sous la souris).
signal give_requested(from_slot: int, screen_position: Vector2)
## P1-102 : clic droit sur un objet -> son detail (delve).
signal detail_requested(slot: int)
## P1-128 : clic gauche sur une arme equipee -> jeu d armes actif (0x71 UseSlot
## 10 / 11 / 12 / 13, comme les touches « 1 main / 2 mains / distance »).
signal weapon_use_requested(slot: int)
const WEAPON_SLOTS := [10, 11, 12, 13]
const ACTIVE_WEAPON_COLOR := Color(1.0, 0.84, 0.18, 0.95)
var _weapon_frames: Dictionary = {}
var _last_weapon_use := -1
var _last_detail_slot := -1
var _last_move: Dictionary = {}
var _tab_buttons: Array = []
var _last_request: Dictionary = {}
var _character_data: Dictionary = {}
var _paper_doll_preview: DaocCharacterPreview = null
var _paper_doll_equipment: RefCounted = null
var _appearance_id := 2


func setup(client_root: String, character_data: Dictionary = {}, appearance_id: int = 2) -> void:
	_client_root = client_root.replace("\\", "/").trim_suffix("/")
	_character_data = character_data.duplicate(true)
	_appearance_id = appearance_id
	_icon_atlas = preload("res://src/daoc/ui/DaocSpellIconAtlas.gd").new()
	_icon_report = _icon_atlas.call("setup", _client_root) as Dictionary
	_paper_doll_equipment = EquipmentVisualsScript.new()
	_paper_doll_equipment.call("configure", _client_root, _appearance_id, str(_character_data.get("gender", "female")))


func _ready() -> void:
	layer = 20
	_build()


func _build() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "InventoryAtlantisPperdoll"
	_root.size = SIZE
	_root.position = Vector2(_screen_width() - SIZE.x - 8.0, 38.0)
	add_child(_root)

	_source_path = _client_root.path_join(SOURCE_RELATIVE_PATH) if _client_root != "" else ""
	var texture := _load_external_texture(_source_path)
	if texture != null:
		var background := TextureRect.new()
		background.name = "OriginalPperdoll"
		background.texture = texture
		background.size = SIZE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(background)
		_texture_loaded = true
		_fallback_reason = ""
	else:
		_build_missing_asset_fallback()
	_build_character_preview()

	_name_label = _add_dynamic_label("Heyveno", Vector2(45, 3), Vector2(102, 14), 10, true)
	# P1-114 : ces deux lignes étaient des chiffres en dur depuis P1-21G ; elles
	# lisent maintenant le 0xBD Encumberance et le 0xFA MoneyUpdate.
	_encumberance_label = _add_dynamic_label("Enc: 0/0", Vector2(45, 238), Vector2(102, 13), 9, true)
	_money_label = _add_dynamic_label(_money_row_text(0), Vector2(16, 423), Vector2(168, 16), 9, false)
	_build_live_slots()
	_root.visible = _visible
	if not _snapshot.is_empty():
		_refresh_widgets()


func _build_character_preview() -> void:
	_paper_doll_preview = CharacterPreviewScene.instantiate() as DaocCharacterPreview
	_paper_doll_preview.name = "EquippedCharacterPreview"
	_paper_doll_preview.position = Vector2(43, 51)
	_paper_doll_preview.size = Vector2(106, 178)
	_paper_doll_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_doll_preview.set_static_pose(true)
	_paper_doll_preview.dress_from_overview = false  # P1-129 : le 0x02 habille ici
	_paper_doll_preview.set_presentation_yaw(0.0)
	_paper_doll_preview.model_ready.connect(_on_paper_doll_model_ready)
	_root.add_child(_paper_doll_preview)
	# Comme le client d'origine, la silhouette elle-meme accepte un objet du sac
	# et laisse l'autorite choisir le logement compatible.
	var drop_target := DaocInventoryDragButton.new()
	drop_target.name = "PaperDollAutoEquipTarget"
	drop_target.position = Vector2(43, 51)
	drop_target.size = Vector2(106, 178)
	drop_target.flat = true
	drop_target.focus_mode = Control.FOCUS_NONE
	drop_target.auto_equip_target = true
	drop_target.auto_equip_dropped.connect(request_equip)
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		drop_target.add_theme_stylebox_override(style_name, empty)
	_root.add_child(drop_target)
	if not _character_data.is_empty():
		_paper_doll_preview.call_deferred("show_character", _character_data)


## L'arbitre qui tient le sac. Sans lui la fenetre reste la planche muette.
func bind_authority(authority: Node) -> void:
	_authority = authority
	if _authority != null and _authority.has_signal("player_inventory_changed"):
		var receiver := Callable(self, "refresh_from_snapshot")
		if not _authority.player_inventory_changed.is_connected(receiver):
			_authority.player_inventory_changed.connect(receiver)
	if _authority != null and _authority.has_method("player_inventory_snapshot"):
		refresh_from_snapshot(_authority.call("player_inventory_snapshot") as Dictionary)


func refresh_from_snapshot(snapshot: Dictionary) -> void:
	var previous_active := int(_snapshot.get("active_weapon_slots", -1))
	_snapshot = snapshot.duplicate(true)
	# P1-128 : l instantane de l arbitre local ne porte pas l octet d arme active ;
	# garder le dernier connu plutot que retomber sur la regle par defaut.
	if not _snapshot.has("active_weapon_slots"):
		_snapshot["active_weapon_slots"] = previous_active
	if _root != null:
		_refresh_widgets()
		_refresh_paper_doll_equipment()


func _on_paper_doll_model_ready(_model: Node3D) -> void:
	_refresh_paper_doll_equipment()


func _refresh_paper_doll_equipment() -> void:
	if _paper_doll_preview == null or _paper_doll_equipment == null:
		return
	var model := _paper_doll_preview.model_root()
	if model == null:
		return
	var slots: Dictionary = _snapshot.get("slots", {}) as Dictionary
	var equipped: Dictionary = {}
	for slot_value in slots.keys():
		var slot := int(slot_value)
		if EQUIPMENT_SLOT_RECTS.has(slot):
			equipped[slot] = slots[slot_value]
	_paper_doll_equipment.call("apply", [model], equipped, int(_snapshot.get("active_weapon_slots", -1)))


func _build_live_slots() -> void:
	for slot_value in EQUIPMENT_SLOT_RECTS.keys():
		var slot := int(slot_value)
		var rect: Rect2 = EQUIPMENT_SLOT_RECTS[slot_value]
		var button := _make_hit_button(rect, "equip_%d" % slot)
		(button as DaocInventoryDragButton).inventory_slot = slot
		_slot_buttons[slot] = button
		button.gui_input.connect(_on_equipment_slot_input.bind(slot))
		var label := Label.new()
		label.position = rect.position
		label.size = rect.size
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := _make_icon_rect(rect)
		_slot_icons[slot] = icon
		_root.add_child(label)
		_slot_labels[slot] = label
	# P1-128 : liseré jaune autour du jeu d armes actif.
	for slot in WEAPON_SLOTS:
		var frame := Panel.new()
		frame.name = "active_weapon_%d" % slot
		var rect: Rect2 = EQUIPMENT_SLOT_RECTS[slot]
		frame.position = rect.position - Vector2(1, 1)
		frame.size = rect.size + Vector2(2, 2)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.9, 0.35, 0.12)
		box.border_color = ACTIVE_WEAPON_COLOR
		box.set_border_width_all(2)
		box.set_corner_radius_all(2)
		frame.add_theme_stylebox_override("panel", box)
		frame.visible = false
		_root.add_child(frame)
		_weapon_frames[slot] = frame
	for row in BAG_ROWS:
		var rect := Rect2(BAG_ROW_RECT.position.x, float(BAG_ROW_Y[row]), BAG_ROW_RECT.size.x, BAG_ROW_RECT.size.y)
		var button := _make_hit_button(rect, "bag_row_%d" % row)
		button.gui_input.connect(_on_bag_row_input.bind(row))
		_row_buttons.append(button)
		var label := _add_dynamic_label("", rect.position + Vector2(20, 0), Vector2(rect.size.x - 20, rect.size.y), 8, false)
		_row_labels.append(label)
		_row_icons.append(_make_icon_rect(Rect2(rect.position + Vector2(1, 0), Vector2(rect.size.y, rect.size.y))))
	for bag in BAG_TAB_Y.size():
		var rect := Rect2(BAG_TAB_RECT.position.x, float(BAG_TAB_Y[bag]), BAG_TAB_RECT.size.x, BAG_TAB_RECT.size.y)
		var button := _make_hit_button(rect, "bag_tab_%d" % bag)
		button.pressed.connect(_on_bag_tab_pressed.bind(bag))
		_tab_buttons.append(button)


func _make_hit_button(rect: Rect2, button_name: String) -> Button:
	# P1-98 : les cases se glissent et recoivent (DaocInventoryDragButton).
	var button := DaocInventoryDragButton.new()
	button.name = button_name
	button.item_dropped.connect(_on_item_dropped)
	button.item_dropped_on_world.connect(func(from_slot: int, screen_position: Vector2) -> void:
		give_requested.emit(from_slot, screen_position))
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty)
	_root.add_child(button)
	return button


func _refresh_widgets() -> void:
	var slots: Dictionary = _snapshot.get("slots", {}) as Dictionary
	# P1-95 : le nom vient de l instantane (Heyvena en ligne), plus du gabarit.
	if _name_label != null and str(_snapshot.get("character_name", "")) != "":
		_name_label.text = str(_snapshot.get("character_name", ""))
	for slot_value in _slot_labels.keys():
		var item: Dictionary = slots.get(int(slot_value), slots.get(str(slot_value), {})) as Dictionary
		(_slot_labels[slot_value] as Label).text = _short_name(item)
		if _slot_icons.has(slot_value):
			_apply_icon(_slot_icons[slot_value] as TextureRect, _slot_labels[slot_value] as Label, item, true)
		if _slot_buttons.has(slot_value):
			(_slot_buttons[slot_value] as DaocInventoryDragButton).set_item(item)
			(_slot_buttons[slot_value] as Button).tooltip_text = item_tooltip(item)
	for row in BAG_ROWS:
		var slot := FIRST_BACKPACK + _current_bag * BAG_ROWS + row
		var item: Dictionary = slots.get(slot, slots.get(str(slot), {})) as Dictionary
		(_row_labels[row] as Label).text = str(item.get("name", "")) if not item.is_empty() else ""
		if row < _row_icons.size():
			_apply_icon(_row_icons[row] as TextureRect, null, item, false)
		if row < _row_buttons.size():
			var row_button := _row_buttons[row] as DaocInventoryDragButton
			row_button.inventory_slot = slot
			row_button.set_item(item)
			row_button.tooltip_text = item_tooltip(item)
	_refresh_active_weapon_frames()
	var used := 0
	for slot_value in slots.keys():
		if int(slot_value) >= FIRST_BACKPACK:
			used += 1
	for child in _root.get_children():
		if child is Label and str((child as Label).text).begins_with("Enc:"):
			(child as Label).text = "Enc: %d/40" % used


func _short_name(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var name := str(item.get("name", ""))
	var words := name.split(" ", false)
	if words.size() >= 2:
		return "%s %s" % [words[words.size() - 2], words[words.size() - 1]]
	return name


func _on_equipment_slot_input(event: InputEvent, slot: int) -> void:
	# P1-102 : clic droit = detail de l objet (0xD8 en ligne).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_request_detail(slot)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).double_click \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		request_unequip(slot)
		return
	# P1-128 : clic simple sur une arme equipee = la mettre en main.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and WEAPON_SLOTS.has(slot):
		request_weapon_use(slot)


func _on_bag_row_input(event: InputEvent, row: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_request_detail(FIRST_BACKPACK + _current_bag * BAG_ROWS + row)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).double_click \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		request_equip(FIRST_BACKPACK + _current_bag * BAG_ROWS + row)


func _on_bag_tab_pressed(bag: int) -> void:
	_current_bag = clampi(bag, 0, BAG_TAB_Y.size() - 1)
	_refresh_widgets()


## Demande a l'arbitre. La fenetre ne bouge rien elle-meme : elle attend
## l'instantane emis par `player_inventory_changed`.
func request_equip(from_slot: int) -> Dictionary:
	if _authority == null or not _authority.has_method("request_equip"):
		_last_request = {"ok": false, "reason": "aucune autorite liee"}
		return _last_request.duplicate(true)
	_last_request = _authority.call("request_equip", from_slot) as Dictionary
	return _last_request.duplicate(true)


func request_unequip(slot: int) -> Dictionary:
	if _authority == null or not _authority.has_method("request_unequip"):
		_last_request = {"ok": false, "reason": "aucune autorite liee"}
		return _last_request.duplicate(true)
	_last_request = _authority.call("request_unequip", slot) as Dictionary
	return _last_request.duplicate(true)


func select_bag(bag: int) -> void:
	_on_bag_tab_pressed(bag)


func current_bag() -> int:
	return _current_bag


func last_request() -> Dictionary:
	return _last_request.duplicate(true)


func toggle_window() -> bool:
	set_window_visible(not _visible)
	return _visible


func set_window_visible(value: bool) -> void:
	_visible = value
	if _root != null:
		_root.visible = value


func set_window_position(value: Vector2) -> void:
	if _root != null:
		_root.position = value


func _screen_width() -> float:
	if get_viewport() != null:
		return get_viewport().get_visible_rect().size.x
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))


func _load_external_texture(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		_fallback_reason = "missing_original_pperdoll"
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fallback_reason = "unreadable_original_pperdoll"
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var image := Image.new()
	if image.load_bmp_from_buffer(bytes) != OK or image.is_empty():
		_fallback_reason = "undecodable_original_pperdoll"
		return null
	if image.get_size() != Vector2i(SIZE):
		_fallback_reason = "unexpected_original_pperdoll_size"
		return null
	return ImageTexture.create_from_image(image)


func _build_missing_asset_fallback() -> void:
	var panel := Panel.new()
	panel.name = "MissingOriginalPperdoll"
	panel.size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.02, 0.03, 0.96)
	style.border_color = Color(0.48, 0.39, 0.22, 1.0)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)


func _add_dynamic_label(text: String, position: Vector2, size: Vector2,
		font_size: int, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.87))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


## P1-114 — la ligne du bas de `pperdoll.bmp` porte quatre nombres : platine,
## or, argent, cuivre (DOL Money.cs ; le mithril ne s y affiche pas).
static func _money_row_text(copper: int) -> String:
	var total := maxi(0, copper)
	return "%d        %d        %d        %d" % [int(total / 10000000) % 1000, int(total / 10000) % 1000, int(total / 100) % 100, total % 100]


## 0xFA MoneyUpdate, en cuivre.
func set_money(copper: int) -> void:
	money_copper = maxi(0, copper)
	if _money_label != null:
		_money_label.text = _money_row_text(money_copper)


## 0xBD Encumberance : porté / maximum. Au-dessus du maximum, en rouge —
## DOL ralentit alors le joueur (UpdateEncumberance → 0xB6).
func set_encumberance(current: int, maximum: int) -> void:
	encumberance_current = current
	encumberance_maximum = maximum
	if _encumberance_label == null:
		return
	_encumberance_label.text = "Enc: %d/%d" % [current, maximum]
	_encumberance_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4) if current > maximum else Color(0.9, 0.9, 0.87))


func get_debug_snapshot() -> Dictionary:
	return {
		"built": _root != null,
		"money_copper": money_copper,
		"money_text": _money_row_text(money_copper),
		"encumberance": "%d/%d" % [encumberance_current, encumberance_maximum],
		"overencumbered": encumberance_maximum > 0 and encumberance_current > encumberance_maximum,
		"visible": _visible,
		"bag_slots": BAG_SLOT_COUNT,
		"equipment_slots": EQUIPMENT_SLOT_COUNT,
		"provenance": "CLIENT_DATA_ATLANTIS_PPERDOLL",
		"source": _source_path,
		"texture_loaded": _texture_loaded,
		"fallback_reason": _fallback_reason,
		"authority_bound": _authority != null,
		"snapshot_revision": int(_snapshot.get("revision", 0)),
		"equipped_count": (_snapshot.get("equipped", {}) as Dictionary).size(),
		"backpack_count": (_snapshot.get("backpack", []) as Array).size(),
		"current_bag": _current_bag,
		"character_preview": _paper_doll_preview != null,
	}


## P1-96 — une case d'icone 32 px du client, etiree a la taille du logement
## (les cases de la planche pperdoll font 30 a 32 px, les lignes du sac 15).
func _make_icon_rect(rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = rect.position
	icon.size = rect.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	_root.add_child(icon)
	return icon


func _icon_for(item: Dictionary) -> Texture2D:
	if item.is_empty() or _icon_atlas == null:
		return null
	var model := int(item.get("model", item.get("model_id", 0)))
	if model <= 0:
		return null
	return _icon_atlas.call("texture_for_item_model", model) as Texture2D


func _apply_icon(icon: TextureRect, label: Label, item: Dictionary, hide_label_when_iconed: bool) -> void:
	var texture := _icon_for(item)
	icon.texture = texture
	icon.visible = texture != null
	if label != null and hide_label_when_iconed:
		label.visible = texture == null


func icon_report() -> Dictionary:
	return _icon_report.duplicate(true)


## P1-98 — un objet lache sur une case : la fenetre ne fait que le dire.
func _on_item_dropped(from_slot: int, to_slot: int) -> void:
	_last_move = {"from": from_slot, "to": to_slot}
	move_requested.emit(from_slot, to_slot)


func last_move() -> Dictionary:
	return _last_move.duplicate(true)


## P1-102 — au survol, les caracteristiques que le 0x02 porte deja : rien
## n'est demande au serveur. Les sens de valeur1 / valeur2 suivent
## eObjectType de DOL : arme = DPS / vitesse (en dixiemes), armure = facteur
## d'armure / absorption, bouclier = taille, le reste = brut.
const WEAPON_TYPES := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]
const ARMOR_TYPES := [32, 33, 34, 35, 36, 37, 38]
const OBJECT_TYPE_NAMES := {
	0: "objet", 1: "arme", 2: "contondant", 3: "tranchant", 4: "perforant", 5: "arme de jet", 6: "deux mains",
	7: "arme d'hast", 8: "baton", 9: "arc long", 10: "arbalete", 11: "epee", 12: "marteau", 13: "hache", 14: "lance",
	15: "arc composite", 16: "hache gauche", 17: "arc recourbe", 18: "lames", 19: "arme contondante", 20: "arme percante",
	21: "grande arme", 22: "lance celte", 23: "arme flexible", 24: "mains nues", 25: "faux", 26: "poings", 27: "baton de mauler",
	32: "tissu", 33: "cuir", 34: "cuir cloute", 35: "mailles", 36: "plates", 37: "renforce", 38: "ecailles",
	41: "objet magique", 42: "bouclier", 43: "fleches", 44: "carreaux", 45: "instrument", 46: "poison", 47: "teinture", 48: "gemme",
}
const SHIELD_SIZES := {1: "petit", 2: "moyen", 3: "grand"}


static func item_tooltip(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var lines: Array[String] = [str(item.get("name", "objet"))]
	var object_type := int(item.get("object_type", -1))
	var type_name := str(OBJECT_TYPE_NAMES.get(object_type, ""))
	var level := int(item.get("level", 0))
	var head := ""
	if type_name != "":
		head = type_name.capitalize()
	if level > 0:
		head += ("  " if head != "" else "") + "niveau %d" % level
	if head != "":
		lines.append(head)
	var value1 := int(item.get("value1", 0))
	var value2 := int(item.get("value2", 0))
	if object_type in WEAPON_TYPES:
		lines.append("DPS %.1f  vitesse %.1f s" % [value1 / 10.0, value2 / 10.0])
	elif object_type in ARMOR_TYPES:
		lines.append("Facteur d'armure %d  absorption %d %%" % [value1, value2])
	elif object_type == 42:
		lines.append("Bouclier %s" % str(SHIELD_SIZES.get(int(item.get("damage_type", 0)), "")))
	var quality := int(item.get("quality", 0))
	var condition := int(item.get("condition", 0))
	var durability := int(item.get("durability", 0))
	if quality > 0 or condition > 0:
		lines.append("Qualite %d %%  condition %d %%  durabilite %d %%" % [quality, condition, durability])
	var weight := int(item.get("weight", 0))
	if weight > 0:
		lines.append("Poids %.1f" % (weight / 10.0))
	return "\n".join(lines)


func _request_detail(slot: int) -> void:
	var slots: Dictionary = _snapshot.get("slots", {}) as Dictionary
	var item: Dictionary = slots.get(slot, slots.get(str(slot), {})) as Dictionary
	if item.is_empty():
		return
	_last_detail_slot = slot
	detail_requested.emit(slot)


func last_detail_slot() -> int:
	return _last_detail_slot


## P1-128 — demande le jeu d armes du logement (le serveur tranche et renvoie
## un 0x02 dont l octet VisibleActiveWeaponSlots rallume le bon liseré).
func request_weapon_use(slot: int) -> bool:
	var slots: Dictionary = _snapshot.get("slots", {}) as Dictionary
	if not WEAPON_SLOTS.has(slot) or (slots.get(slot, slots.get(str(slot), {})) as Dictionary).is_empty():
		return false
	_last_weapon_use = slot
	weapon_use_requested.emit(slot)
	return true


## Logements d arme actifs d apres l octet VisibleActiveWeaponSlots (quartet
## bas = main droite 10 + n, haut = main gauche). Inconnu (-1) : la regle du
## client — deux mains seule en main, sinon droite + gauche.
static func active_weapon_slots_for(active_byte: int, slots: Dictionary) -> Array:
	var has := func(slot: int) -> bool: return not (slots.get(slot, slots.get(str(slot), {})) as Dictionary).is_empty()
	var out: Array = []
	if active_byte >= 0:
		for nibble in [active_byte & 0x0f, (active_byte >> 4) & 0x0f]:
			if nibble <= 3 and has.call(10 + nibble) and not out.has(10 + nibble):
				out.append(10 + nibble)
		return out
	if has.call(12) and not has.call(10):
		return [12]
	for slot in [10, 11]:
		if has.call(slot):
			out.append(slot)
	return out


func _refresh_active_weapon_frames() -> void:
	var active := active_weapon_slots_for(int(_snapshot.get("active_weapon_slots", -1)), _snapshot.get("slots", {}) as Dictionary)
	for slot in _weapon_frames.keys():
		(_weapon_frames[slot] as Control).visible = active.has(int(slot))


func active_weapon_frames() -> Array:
	var out: Array = []
	for slot in _weapon_frames.keys():
		if (_weapon_frames[slot] as Control).visible:
			out.append(int(slot))
	out.sort()
	return out


func last_weapon_use() -> int:
	return _last_weapon_use
