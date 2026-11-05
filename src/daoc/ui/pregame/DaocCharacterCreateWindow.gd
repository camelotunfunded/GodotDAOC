extends CanvasLayer
class_name DaocCharacterCreateWindow

## 2026-09-30 — fenêtre de création SIMPLIFIÉE, sans aperçu 3D : race, sexe,
## classe, nom et les 30 points. Les règles viennent de
## `DaocCharacterCreationRules` ; la fenêtre ne décide rien, elle émet le
## dictionnaire 0xFF vers le frontend, qui l'envoie au serveur.
## La version fidèle viendra plus tard de `pregame/character_creation.xml`.

signal create_confirmed(data: Dictionary)
signal cancelled

const RulesScript := preload("res://src/daoc/ui/pregame/DaocCharacterCreationRules.gd")
const REALM_NAMES := {1: "Albion", 2: "Midgard", 3: "Hibernia"}

var rules: DaocCharacterCreationRules = RulesScript.new()
var realm_id := 1
var slot_index := 0
var added: Dictionary = {}

var _root: ColorRect = null
var _title: Label = null
var _race: OptionButton = null
var _gender: OptionButton = null
var _class: OptionButton = null
var _name: LineEdit = null
var _points: Label = null
var _status: Label = null
var _create_button: Button = null
var _stat_values: Dictionary = {}
var _races: Array = []
var _classes: Array = []


func _ready() -> void:
	layer = 105
	_build()


func open_for(realm: int, slot: int) -> void:
	realm_id = clampi(realm, 1, 3)
	slot_index = slot
	if _root == null:
		_build()
	_title.text = "Nouveau personnage — %s, emplacement %d" % [REALM_NAMES.get(realm_id, "?"), slot_index + 1]
	_name.text = ""
	_races = rules.races_for_realm(realm_id)
	_race.clear()
	for entry in _races:
		_race.add_item(str((entry as Dictionary).get("label")))
	_race.select(0)
	_on_race_changed(0)
	set_status("")
	_create_button.disabled = false
	visible = true


func close() -> void:
	visible = false


## Refus du serveur : les choix restent, le bouton se réarme.
func allow_retry(message: String) -> void:
	_create_button.disabled = false
	set_status(message, true)


func set_status(text: String, is_error: bool = false) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4) if is_error else Color(0.8, 0.85, 0.9))


func _build() -> void:
	_root = ColorRect.new()
	_root.name = "CharacterCreateBackdrop"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(0.01, 0.015, 0.03, 0.78)
	add_child(_root)

	var panel := PanelContainer.new()
	panel.name = "CharacterCreateWindow"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -290)
	panel.custom_minimum_size = Vector2(600, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	outer.add_child(_title)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	outer.add_child(form)
	_race = _add_option(form, "Race")
	_race.item_selected.connect(_on_race_changed)
	_gender = _add_option(form, "Sexe")
	_gender.item_selected.connect(func(_i: int): _refresh())
	_class = _add_option(form, "Classe")
	var name_label := Label.new()
	name_label.text = "Nom"
	form.add_child(name_label)
	_name = LineEdit.new()
	_name.placeholder_text = "Majuscule initiale, lettres seulement"
	_name.max_length = 20
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_name)

	var stats_title := Label.new()
	stats_title.text = "Caractéristiques"
	stats_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	outer.add_child(stats_title)
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 12)
	outer.add_child(stats)
	for stat in RulesScript.STATS:
		var label := Label.new()
		label.text = str(RulesScript.STAT_LABELS[stat])
		label.custom_minimum_size.x = 150
		stats.add_child(label)
		var minus := Button.new()
		minus.text = " − "
		minus.pressed.connect(_change_stat.bind(stat, -1))
		stats.add_child(minus)
		var value := Label.new()
		value.custom_minimum_size.x = 90
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_child(value)
		_stat_values[stat] = value
		var plus := Button.new()
		plus.text = " + "
		plus.pressed.connect(_change_stat.bind(stat, 1))
		stats.add_child(plus)
	_points = Label.new()
	outer.add_child(_points)
	var hint := Label.new()
	hint.text = "Coût : 1 point par niveau jusqu'à +10, 2 de +11 à +15, 3 au-delà."
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	outer.add_child(hint)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560, 40)
	outer.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	outer.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(func(): close(); cancelled.emit())
	buttons.add_child(cancel)
	_create_button = Button.new()
	_create_button.text = "Créer"
	_create_button.pressed.connect(_on_create_pressed)
	buttons.add_child(_create_button)


func _add_option(form: GridContainer, text: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	form.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(option)
	return option


func _race_key() -> String:
	var index := _race.selected
	if index < 0 or index >= _races.size():
		return ""
	return str((_races[index] as Dictionary).get("key"))


func _on_race_changed(_index: int) -> void:
	var entry := rules.race(realm_id, _race_key())
	_gender.clear()
	_gender.add_item("Homme")
	if int(entry.get("female", 0)) > 0:
		_gender.add_item("Femme")
	_gender.select(0)
	_classes = rules.classes_for_race(_race_key())
	_class.clear()
	for value in _classes:
		_class.add_item(str((value as Dictionary).get("name")))
	if not _classes.is_empty():
		_class.select(0)
	added = {}
	_refresh()


func _change_stat(stat: String, delta: int) -> void:
	var next := maxi(0, int(added.get(stat, 0)) + delta)
	var trial := added.duplicate()
	trial[stat] = next
	if rules.points_used(trial) > RulesScript.MAX_POINTS:
		return
	added = trial
	_refresh()


func _refresh() -> void:
	var base := rules.base_stats(realm_id, _race_key())
	for stat in RulesScript.STATS:
		var bonus := int(added.get(stat, 0))
		var text := str(int(base.get(stat, 0)) + bonus)
		if bonus > 0:
			text += "  (+%d)" % bonus
		(_stat_values[stat] as Label).text = text
	var used := rules.points_used(added)
	_points.text = "Points restants : %d / %d" % [RulesScript.MAX_POINTS - used, RulesScript.MAX_POINTS]


func current_data() -> Dictionary:
	var class_id := 0
	if _class.selected >= 0 and _class.selected < _classes.size():
		class_id = int((_classes[_class.selected] as Dictionary).get("id", 0))
	var female := _gender.get_item_text(maxi(_gender.selected, 0)) == "Femme"
	return rules.build_create_data(realm_id, slot_index, _name.text.strip_edges(), _race_key(), female, class_id, added)


func _on_create_pressed() -> void:
	var data := current_data()
	var errors := rules.validate(data, added)
	if not errors.is_empty():
		set_status("\n".join(errors), true)
		return
	_create_button.disabled = true
	set_status("Création de %s envoyée au serveur…" % str(data.get("name", "")))
	create_confirmed.emit(data)


## Pour les suites : pose les choix sans cliquer.
func set_choices_for_test(race_index: int, female: bool, class_index: int, char_name: String, stat_bonus: Dictionary) -> void:
	_race.select(race_index)
	_on_race_changed(race_index)
	_gender.select(1 if female and _gender.item_count > 1 else 0)
	_class.select(class_index)
	_name.text = char_name
	added = stat_bonus.duplicate()
	_refresh()
