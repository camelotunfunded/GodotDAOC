extends Control
class_name DaocPregameFlowController

signal realm_confirmed(realm_id: int)
signal character_selected(slot_index: int, character_data: Dictionary)
signal play_requested(slot_index: int, character_data: Dictionary)
signal create_requested(slot_index: int)
signal delete_requested(slot_index: int, character_data: Dictionary)
signal customize_requested(slot_index: int, character_data: Dictionary)
signal options_requested()
signal quit_requested()
signal back_requested()
signal heyveno_select_confirmation_validated(slot_index: int, exact_name: String, character_data: Dictionary)

const UI_PHASE_REALM_SELECT := "REALM_SELECT"
const UI_PHASE_CHARACTER_SELECT := "CHARACTER_SELECT"
const LOGICAL_SIZE := Vector2i(1024, 768)
const MAX_UI_SCALE := 1.0
const DataAdapterScript = preload("res://src/daoc/ui/pregame/DaocPregameDataAdapter.gd")
const PlayableRosterScript = preload("res://src/daoc/ui/pregame/DaocPlayableRoster.gd")

@export var show_offline_fixture_on_ready := true
@export var start_with_empty_overview := false
@export var network_enabled := false
@export var udp_enabled := false
@export var debug_ui_labels_enabled := false
## Hors ligne, montre les trois personnages qui ont une scene (Riri, Fifi,
## Loulou) au lieu de la fixture de six noms sans modele. Les suites qui
## verifient la fixture passent leur propre modele a show_character_selection.
@export var use_playable_roster := true

var ui_phase := UI_PHASE_REALM_SELECT
var selected_realm_id := 0
var model: Dictionary = {}
var live_connection_attempted := false
var network_send_count := 0
var emitted_intents: Array[String] = []
var _adapter: DaocPregameDataAdapter = DataAdapterScript.new()
var _realm_background: TextureRect = null
var _character_background: Control = null

@onready var logical_canvas: Control = $LogicalCanvas
@onready var realm_screen: DaocRealmSelectionScreen = $LogicalCanvas/RealmScreen
@onready var character_screen: DaocCharacterSelectionScreen = $LogicalCanvas/CharacterScreen
@onready var heyveno_select_confirmation: DaocHeyvenoSelectConfirmation = $LogicalCanvas/HeyvenoSelectConfirmation


func _ready() -> void:
	_detach_fullscreen_backdrops()
	resized.connect(_update_logical_canvas_transform)
	_update_logical_canvas_transform()
	realm_screen.realm_confirmed.connect(_on_realm_confirmed)
	character_screen.character_selected.connect(_on_character_selected)
	character_screen.play_requested.connect(_on_play_requested)
	character_screen.create_requested.connect(_on_create_requested)
	character_screen.delete_requested.connect(_on_delete_requested)
	character_screen.customize_requested.connect(_on_customize_requested)
	character_screen.options_requested.connect(_on_options_requested)
	character_screen.quit_requested.connect(_on_quit_requested)
	character_screen.back_requested.connect(_on_back_requested)
	realm_screen.quit_requested.connect(_on_quit_requested)
	heyveno_select_confirmation.confirmation_submitted.connect(_on_heyveno_select_confirmation_submitted)
	realm_screen.debug_ui_labels_enabled = debug_ui_labels_enabled
	character_screen.debug_ui_labels_enabled = debug_ui_labels_enabled
	realm_screen.selection_hint.visible = debug_ui_labels_enabled
	character_screen.source_label.visible = debug_ui_labels_enabled
	var realm_model := {"available_realms": _adapter.available_realms(), "selected_realm": {}, "ui_phase": UI_PHASE_REALM_SELECT, "source": "offline"}
	realm_screen.set_model(realm_model)
	show_realm_selection()
	if not show_offline_fixture_on_ready:
		model = _adapter.empty_overview_model(1, "live")


func _update_logical_canvas_transform() -> void:
	if logical_canvas == null:
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		available = get_viewport_rect().size
	var uniform_scale := minf(available.x / float(LOGICAL_SIZE.x), available.y / float(LOGICAL_SIZE.y))
	# Sur les grands ecrans, les commandes restent a leur taille de reference.
	if ui_phase == UI_PHASE_REALM_SELECT:
		uniform_scale = minf(uniform_scale, MAX_UI_SCALE)
	uniform_scale = maxf(uniform_scale, 0.01)
	logical_canvas.scale = Vector2(uniform_scale, uniform_scale)
	logical_canvas.position = (available - Vector2(LOGICAL_SIZE) * uniform_scale) * 0.5
	_layout_frame_wings(available, uniform_scale, logical_canvas.position)


func _detach_fullscreen_backdrops() -> void:
	# Les vrais fonds quittent le canevas logique 1024x768 et remplissent la
	# fenetre. Les commandes, elles, restent sur le canevas centre : aucune
	# seconde copie de l'image n'est dessinee derriere elles.
	_realm_background = realm_screen.get_node("Background") as TextureRect
	_realm_background.reparent(self)
	_realm_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_realm_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	move_child(_realm_background, 1)
	_character_background = character_screen.get_node("CharacterBackdrop") as Control
	_character_background.reparent(self)
	_character_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_character_background, 2)


func logical_canvas_size() -> Vector2i:
	return LOGICAL_SIZE


func set_model(value: Dictionary) -> void:
	model = _adapter.normalize_model(value)
	selected_realm_id = int((model.get("selected_realm", {}) as Dictionary).get("id", 1))
	character_screen.set_model(model)


func set_animation_polish_enabled(enabled: bool) -> void:
	if character_screen != null:
		character_screen.set_animation_polish_enabled(enabled)


func setup_with_debug_hud(hud: Node) -> void:
	set_model(_adapter.model_from_hud(hud))


func show_realm_selection() -> void:
	if _realm_background != null:
		_realm_background.visible = true
	if _character_background != null:
		_character_background.visible = false
	heyveno_select_confirmation.hide_dialog()
	ui_phase = UI_PHASE_REALM_SELECT
	realm_screen.visible = true
	character_screen.visible = false
	_update_logical_canvas_transform()


func show_character_selection(realm_id: int, override_model: Dictionary = {}) -> void:
	if _realm_background != null:
		_realm_background.visible = false
	if _character_background != null:
		_character_background.visible = true
	if _frame_wings != null:
		_frame_wings.visible = false
	selected_realm_id = clampi(realm_id, 1, 3)
	ui_phase = UI_PHASE_CHARACTER_SELECT
	if override_model.is_empty():
		if start_with_empty_overview:
			model = _adapter.empty_overview_model(selected_realm_id, "live")
		elif use_playable_roster:
			model = _adapter.normalize_model(PlayableRosterScript.offline_overview(selected_realm_id))
		else:
			model = _adapter.offline_fixture(selected_realm_id)
	else:
		model = _adapter.normalize_model(override_model)
	character_screen.set_model(model)
	realm_screen.visible = false
	character_screen.visible = true
	_update_logical_canvas_transform()


func show_empty_live_overview(realm_id: int) -> void:
	show_character_selection(realm_id, _adapter.empty_overview_model(realm_id, "live"))


func apply_character_overview(raw_overview: Dictionary) -> Dictionary:
	var overview := raw_overview.duplicate(true)
	if not overview.has("selected_realm"):
		overview["selected_realm"] = _adapter.realm_snapshot(clampi(selected_realm_id if selected_realm_id > 0 else 1, 1, 3))
	if not overview.has("source"):
		overview["source"] = "live_fixture"
	model = _adapter.normalize_character_overview(overview)
	selected_realm_id = int((model.get("selected_realm", {}) as Dictionary).get("id", 1))
	ui_phase = UI_PHASE_CHARACTER_SELECT
	character_screen.set_model(model)
	realm_screen.visible = false
	character_screen.visible = true
	for slot in model.get("slots", []) as Array:
		if bool((slot as Dictionary).get("valid", false)):
			character_screen.select_slot(int((slot as Dictionary).get("slot_index", 0)))
			break
	return model.duplicate(true)


func status_snapshot() -> Dictionary:
	return {
		"checkpoint": "P1-20UI-B_FIDELITY_AND_LIVE_OVERVIEW_BRIDGE",
		"ui_phase": ui_phase,
		"selected_realm_id": selected_realm_id,
		"logical_size": LOGICAL_SIZE,
		"logical_canvas_runtime_size": logical_canvas.size if logical_canvas != null else Vector2.ZERO,
		"uniform_scale": logical_canvas.scale.x if logical_canvas != null else 0.0,
		"character_count": int(model.get("character_count", 0)),
		"network_enabled": network_enabled,
		"live_connection_attempted": live_connection_attempted,
		"network_send_count": network_send_count,
		"udp_enabled": udp_enabled,
		"character_select_packet_sent": false,
		"source": str(model.get("source", "offline")),
	}


func _on_realm_confirmed(realm_id: int) -> void:
	emitted_intents.append("realm_confirmed")
	realm_confirmed.emit(realm_id)
	show_character_selection(realm_id)


func _on_character_selected(slot_index: int, data: Dictionary) -> void:
	emitted_intents.append("character_selected")
	character_selected.emit(slot_index, data)


func _on_play_requested(slot_index: int, data: Dictionary) -> void:
	# Deliberately intent-only. P1-20B owns 0x10 and world entry.
	emitted_intents.append("play_requested")
	play_requested.emit(slot_index, data)
	if str(data.get("name", "")) == "Heyveno" and slot_index == 0:
		heyveno_select_confirmation.show_for_character(data)


func _on_create_requested(slot_index: int) -> void:
	emitted_intents.append("create_requested")
	create_requested.emit(slot_index)


func _on_delete_requested(slot_index: int, data: Dictionary) -> void:
	emitted_intents.append("delete_requested")
	delete_requested.emit(slot_index, data)


func _on_customize_requested(slot_index: int, data: Dictionary) -> void:
	emitted_intents.append("customize_requested")
	customize_requested.emit(slot_index, data)


func _on_options_requested() -> void:
	emitted_intents.append("options_requested")
	options_requested.emit()


func _on_quit_requested() -> void:
	# Signal only: an integrated ZoneViewer session must never be terminated here.
	emitted_intents.append("quit_requested")
	quit_requested.emit()



func _on_heyveno_select_confirmation_submitted(slot_index: int, exact_name: String, data: Dictionary) -> void:
	# Confirmation signal only. The controlled P1-20B probe owns the sole 0x10 send.
	emitted_intents.append("heyveno_select_confirmation_validated")
	heyveno_select_confirmation_validated.emit(slot_index, exact_name, data)


func _on_back_requested() -> void:
	emitted_intents.append("back_requested")
	back_requested.emit()
	show_realm_selection()


# P1-133 — le cadre de pierre de la sélection (`character_selection.png`) est
# une image 1024x768 : sur un écran plus large que 4:3 ses bandeaux s'arrêtaient
# net et laissaient voir le dégradé sur les côtés. Les « ailes » prolongent les
# bandeaux haut (lignes 0..78) et bas (666..768) en mosaïque de leur bord gauche,
# à la même échelle que le canevas logique.
const FRAME_TOP_REGION := Rect2(0, 0, 96, 78)
const FRAME_BOTTOM_REGION := Rect2(0, 666, 96, 102)
var _frame_wings: Control = null


func _layout_frame_wings(available: Vector2, scale_value: float, canvas_pos: Vector2) -> void:
	var in_character := ui_phase == UI_PHASE_CHARACTER_SELECT
	if _frame_wings == null:
		if not in_character:
			return
		var frame := character_screen.get_node_or_null("FrameOverlay") as TextureRect
		if frame == null or frame.texture == null:
			return
		_frame_wings = Control.new()
		_frame_wings.name = "FrameWings"
		_frame_wings.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame_wings)
		move_child(_frame_wings, (_character_background.get_index() + 1) if _character_background != null else 0)
		for region in [FRAME_TOP_REGION, FRAME_BOTTOM_REGION]:
			for side in ["L", "R"]:
				var atlas := AtlasTexture.new()
				atlas.atlas = frame.texture
				atlas.region = region
				var wing := TextureRect.new()
				wing.name = "%s%d" % [side, int(region.position.y)]
				wing.texture = atlas
				wing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				wing.stretch_mode = TextureRect.STRETCH_TILE
				wing.mouse_filter = Control.MOUSE_FILTER_IGNORE
				wing.set_meta("region", region)
				_frame_wings.add_child(wing)
	_frame_wings.visible = in_character and canvas_pos.x > 0.5
	if not _frame_wings.visible:
		return
	for child in _frame_wings.get_children():
		var wing := child as TextureRect
		var region: Rect2 = wing.get_meta("region")
		# La mosaïque se fait en pixels de la texture : on met le rect à l'échelle
		# du canevas en l'agrandissant par `scale`.
		wing.scale = Vector2(scale_value, scale_value)
		wing.size = Vector2(canvas_pos.x / scale_value + 1.0, region.size.y)
		var y := canvas_pos.y + region.position.y * scale_value
		wing.position = Vector2(0.0 if str(wing.name).begins_with("L") else canvas_pos.x + LOGICAL_SIZE.x * scale_value - 1.0, y)
