extends CanvasLayer
class_name DaocTrainerWindow

## P1-107 — la fenetre d entraineur : les specialisations (niveau, cout du
## prochain niveau) et les capacites de royaume, avec les points disponibles.
## « + » et « - » preparent un niveau vise ; « Former » envoie le 0x53. Le
## client ne forme rien lui-meme : il compte les points pour l affichage et le
## serveur repond par un nouveau 0x7B et un 0x91.

signal train_requested(spec_targets: Dictionary, ra_targets: Dictionary)
signal closed

const XmlFrame = preload("res://src/daoc/ui/DaocXmlEngineFrame.gd")
const TrainerCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTrainerCodec.gd")

var trainer: Dictionary = {}
var planned_specs: Dictionary = {}
var planned_abilities: Dictionary = {}
var _panel: PanelContainer = null
var _title: Label = null
var _points: Label = null
var _spec_rows: VBoxContainer = null
var _ra_rows: VBoxContainer = null
var _train_button: Button = null
var train_requests := 0


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "Trainer"
	_panel.position = Vector2(340, 90)
	_panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.text = "Entraineur"
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 11)
	var specs_head := Label.new()
	specs_head.text = "Specialisations"
	specs_head.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	_spec_rows = VBoxContainer.new()
	var ra_head := Label.new()
	ra_head.text = "Capacites de royaume"
	ra_head.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	_ra_rows = VBoxContainer.new()
	# 30 capacites de royaume pour un Wizard (mesure live) : la liste defile.
	var ra_scroll := ScrollContainer.new()
	ra_scroll.custom_minimum_size = Vector2(500, 260)
	ra_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ra_scroll.add_child(_ra_rows)
	var buttons := HBoxContainer.new()
	_train_button = Button.new()
	_train_button.text = "Former"
	_train_button.pressed.connect(_on_train_pressed)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	buttons.add_child(_train_button)
	buttons.add_child(close)
	for node in [_title, _points, specs_head, _spec_rows, ra_head, ra_scroll, buttons]:
		box.add_child(node)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func show_trainer(value: Dictionary) -> void:
	trainer = value.duplicate(true)
	planned_specs.clear()
	planned_abilities.clear()
	realm_scroll = 0
	_rebuild()
	_set_shown(true)


func hide_window() -> void:
	_set_shown(false)
	closed.emit()


func is_shown() -> bool:
	if _xml != null:
		return _xml.visible
	return _panel != null and _panel.visible


func _set_shown(value: bool) -> void:
	if _xml != null:
		_xml.visible = value
	elif _panel != null:
		_panel.visible = value


func spec_points_available() -> int:
	return int(trainer.get("spec_points", 0)) - planned_spec_cost()


func planned_spec_cost() -> int:
	var cost := 0
	for value in trainer.get("specs", []):
		var spec := value as Dictionary
		var index := int(spec.get("index", 0))
		if planned_specs.has(index):
			cost += TrainerCodec.spec_training_cost(int(spec.get("level", 0)), int(planned_specs[index]))
	return cost


func realm_points_available() -> int:
	var cost := 0
	for value in trainer.get("realm_abilities", []):
		var ra := value as Dictionary
		var index := int(ra.get("index", 0))
		if planned_abilities.has(index):
			cost += int(ra.get("cost", 0)) * (int(planned_abilities[index]) - int(ra.get("level", 0)))
	return int(trainer.get("realm_points", 0)) - cost


## Monte ou descend le niveau vise d une spe ; refuse au-dela des points.
func adjust_spec(index: int, delta: int) -> bool:
	var spec := _spec(index)
	if spec.is_empty():
		return false
	var current := int(spec.get("level", 0))
	var planned := int(planned_specs.get(index, current))
	var wanted := maxi(current, planned + delta)
	if wanted == planned:
		return false
	var others := planned_spec_cost() - TrainerCodec.spec_training_cost(current, planned)
	if TrainerCodec.spec_training_cost(current, wanted) + others > int(trainer.get("spec_points", 0)):
		return false
	if wanted == current:
		planned_specs.erase(index)
	else:
		planned_specs[index] = wanted
	_rebuild()
	return true


func adjust_ability(index: int, delta: int) -> bool:
	var ra := _ability(index)
	if ra.is_empty() or not bool(ra.get("available", true)):
		return false
	var current := int(ra.get("level", 0))
	var planned := int(planned_abilities.get(index, current))
	var wanted := maxi(current, planned + delta)
	if wanted == planned:
		return false
	var others := realm_points_available() - int(trainer.get("realm_points", 0)) + int(ra.get("cost", 0)) * (planned - current)
	if int(ra.get("cost", 0)) * (wanted - current) - others > int(trainer.get("realm_points", 0)):
		return false
	if wanted == current:
		planned_abilities.erase(index)
	else:
		planned_abilities[index] = wanted
	_rebuild()
	return true


func _on_train_pressed() -> void:
	if planned_specs.is_empty() and planned_abilities.is_empty():
		return
	train_requests += 1
	train_requested.emit(planned_specs.duplicate(true), planned_abilities.duplicate(true))


func _spec(index: int) -> Dictionary:
	for value in trainer.get("specs", []):
		if int((value as Dictionary).get("index", -1)) == index:
			return value as Dictionary
	return {}


func _ability(index: int) -> Dictionary:
	for value in trainer.get("realm_abilities", []):
		if int((value as Dictionary).get("index", -1)) == index:
			return value as Dictionary
	return {}


func _rebuild() -> void:
	if _xml != null:
		_rebuild_xml()
	if _panel == null:
		return
	_points.text = "Points de specialisation : %d   Points de royaume : %d" % [spec_points_available(), realm_points_available()]
	for child in _spec_rows.get_children():
		child.queue_free()
	for value in trainer.get("specs", []):
		var spec := value as Dictionary
		var index := int(spec.get("index", 0))
		var current := int(spec.get("level", 0))
		var planned := int(planned_specs.get(index, current))
		_spec_rows.add_child(_row("%s  %d%s" % [str(spec.get("name", "")), current, "  -> %d (%d pts)" % [planned, TrainerCodec.spec_training_cost(current, planned)] if planned > current else "  (prochain : %d pt)" % (current + 1)],
			func(): adjust_spec(index, -1), func(): adjust_spec(index, 1), true))
	for child in _ra_rows.get_children():
		child.queue_free()
	for value in trainer.get("realm_abilities", []):
		var ra := value as Dictionary
		var index := int(ra.get("index", 0))
		var current := int(ra.get("level", 0))
		var planned := int(planned_abilities.get(index, current))
		var label := "%s  %d%s" % [str(ra.get("name", "")), current, "  -> %d" % planned if planned > current else "  (prochain : %d pts)" % int(ra.get("cost", 0))]
		if not bool(ra.get("available", true)):
			label += "  [prerequis manquants]"
		_ra_rows.add_child(_row(label, func(): adjust_ability(index, -1), func(): adjust_ability(index, 1), bool(ra.get("available", true))))
	_train_button.disabled = planned_specs.is_empty() and planned_abilities.is_empty()


func _row(text: String, on_minus: Callable, on_plus: Callable, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(420, 0)
	label.add_theme_font_size_override("font_size", 11)
	if not enabled:
		label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(on_minus)
	minus.disabled = not enabled
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(on_plus)
	plus.disabled = not enabled
	row.add_child(label)
	row.add_child(minus)
	row.add_child(plus)
	return row


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "specs": (trainer.get("specs", []) as Array).size(), "realm_abilities": (trainer.get("realm_abilities", []) as Array).size(),
		"spec_points": int(trainer.get("spec_points", 0)), "planned_specs": planned_specs.duplicate(true), "planned_abilities": planned_abilities.duplicate(true), "train_requests": train_requests}


## ═══ P1-134 : la fenetre `training_window` de training_window.xml ═══════
## Audit des fenetres du 2026-09-29 : WindowId Training, 390 x 536, c est la
## fenetre du 0x7B de PacketLib1105 (evenements NewTrain / NewTrainInfo /
## NewTrainRealmInfo) ; train.xml (WindowId Train, 300 x 450) est l ancienne,
## non montee. Trois onglets (TabsDef 1000) : Specializations (lignes 0..7 :
## spec_name, curseur 1102+4i, spec_level), Ability Summary, Realm Abilities
## (lignes 0..13 : realm_name, curseur 1302+5i, realm_level, realm_cost ; le
## curseur vertical 1399 fait defiler). En-tete : training_spec_avail /
## needed / remaining et training_realm_*. Boutons du bas : TRAIN, RESET,
## CANCEL. Les /RESPEC ne sont PAS branches : un clic de travers effacerait
## les points du personnage.
const SPEC_ROWS := 8
const REALM_ROWS := 14
var _xml: XmlFrame = null
var realm_scroll := 0


func use_xml_window(builder: DaocUiWindowBuilder, window: Dictionary) -> bool:
	var frame := XmlFrame.create(builder, window)
	if frame == null:
		return false
	_xml = frame
	_xml.position = Vector2(340, 90)
	_xml.visible = _panel != null and _panel.visible
	_xml.scale = get_meta("daoc_ui_scale", Vector2.ONE)
	add_child(_xml)
	if _panel != null:
		_panel.visible = false
	_xml.close_requested.connect(hide_window)
	for row in SPEC_ROWS:
		var slider := _xml.control(str(1102 + row * 4))
		if slider != null and slider.has_signal("stepped"):
			slider.connect("stepped", func(delta: int) -> void: _step_spec_row(row, delta))
	for row in REALM_ROWS:
		var slider := _xml.control(str(1302 + row * 5))
		if slider != null and slider.has_signal("stepped"):
			slider.connect("stepped", func(delta: int) -> void: _step_realm_row(row, delta))
	for id in ["1299", "1399"]:
		var scroll := _xml.control(id)
		if scroll != null and scroll.has_signal("stepped"):
			scroll.connect("stepped", func(delta: int) -> void: _scroll_realm(delta))
	XmlFrame.on_click(_xml.control("1900", "TRAIN"), _on_train_pressed)
	XmlFrame.on_click(_xml.control("1901"), func() -> void:
		planned_specs.clear()
		planned_abilities.clear()
		_rebuild())
	XmlFrame.on_click(_xml.control("1902"), hide_window)
	_rebuild()
	return true


func uses_xml() -> bool:
	return _xml != null


func _step_spec_row(row: int, delta: int) -> void:
	var specs: Array = trainer.get("specs", [])
	if row < specs.size():
		adjust_spec(int((specs[row] as Dictionary).get("index", 0)), delta)


func _step_realm_row(row: int, delta: int) -> void:
	var abilities: Array = trainer.get("realm_abilities", [])
	if row + realm_scroll < abilities.size():
		adjust_ability(int((abilities[row + realm_scroll] as Dictionary).get("index", 0)), delta)


func _scroll_realm(delta: int) -> void:
	var count := (trainer.get("realm_abilities", []) as Array).size()
	realm_scroll = clampi(realm_scroll + delta, 0, maxi(0, count - REALM_ROWS))
	_rebuild()


func _rebuild_xml() -> void:
	var spec_cost := planned_spec_cost()
	var spec_total := int(trainer.get("spec_points", 0))
	var realm_total := int(trainer.get("realm_points", 0))
	var realm_left := realm_points_available()
	_xml.set_text("training_spec_avail", str(spec_total))
	_xml.set_text("training_spec_needed", str(spec_cost))
	_xml.set_text("training_spec_remaining", str(spec_total - spec_cost))
	_xml.set_text("training_realm_avail", str(realm_total))
	_xml.set_text("training_realm_needed", str(realm_total - realm_left))
	_xml.set_text("training_realm_remaining", str(realm_left))
	_xml.set_text("train_min_level", "")
	var specs: Array = trainer.get("specs", [])
	for row in SPEC_ROWS:
		var has := row < specs.size()
		var spec: Dictionary = specs[row] as Dictionary if has else {}
		var current := int(spec.get("level", 0))
		var planned := int(planned_specs.get(int(spec.get("index", -1)), current))
		_xml.set_text("spec_name%d" % row, str(spec.get("name", "")))
		_xml.set_text("spec_level%d" % row, ("%d" % current if planned == current else "%d>%d" % [current, planned]) if has else "")
		_row_visible([str(1100 + row * 4), str(1102 + row * 4)], has)
		_set_slider(str(1102 + row * 4), float(planned) / 50.0)
	var abilities: Array = trainer.get("realm_abilities", [])
	realm_scroll = clampi(realm_scroll, 0, maxi(0, abilities.size() - REALM_ROWS))
	for row in REALM_ROWS:
		var index := row + realm_scroll
		var has := index < abilities.size()
		var ra: Dictionary = abilities[index] as Dictionary if has else {}
		var current := int(ra.get("level", 0))
		var planned := int(planned_abilities.get(int(ra.get("index", -1)), current))
		_xml.set_text("realm_name%d" % row, str(ra.get("name", "")))
		_xml.set_text("realm_level%d" % row, ("%d" % current if planned == current else "%d>%d" % [current, planned]) if has else "")
		_xml.set_text("realm_cost%d" % row, "Cost: %d" % int(ra.get("cost", 0)) if has else "")
		_row_visible([str(1300 + row * 5), str(1302 + row * 5)], has)
		_set_slider(str(1302 + row * 5), float(planned) / 9.0)
		var name_label := _xml.control(str(1301 + row * 5))
		if name_label != null:
			name_label.modulate = Color(0.6, 0.6, 0.6) if has and not bool(ra.get("available", true)) else Color.WHITE
	var span := maxi(1, abilities.size() - REALM_ROWS)
	for id in ["1299", "1399"]:
		_set_slider(id, float(realm_scroll) / float(span))


func _row_visible(ids: Array, value: bool) -> void:
	# Les controles d un onglet cache restent caches : on ne touche qu a
	# `modulate`, jamais a `visible`, que les onglets pilotent.
	for id in ids:
		var node := _xml.control(str(id))
		if node != null:
			node.modulate.a = 1.0 if value else 0.0
			node.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE


func _set_slider(id: String, fraction: float) -> void:
	var slider := _xml.control(id)
	if slider != null and slider.has_method("set_fraction"):
		slider.call("set_fraction", fraction)
