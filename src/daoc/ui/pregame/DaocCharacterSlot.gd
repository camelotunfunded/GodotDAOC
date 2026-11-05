extends Control
class_name DaocCharacterSlot

signal slot_pressed(slot_index: int, character_data: Dictionary)

var slot_index := 0
var character_data: Dictionary = {}
var selected := false
var disabled := false
var hovered := false

@onready var hitbox: Button = $Hitbox
@onready var radio: TextureRect = $Radio
@onready var top_label: Label = $TopLabel
@onready var bottom_label: Label = $BottomLabel


func _ready() -> void:
	hitbox.pressed.connect(_on_pressed)
	hitbox.mouse_entered.connect(_on_hover.bind(true))
	hitbox.mouse_exited.connect(_on_hover.bind(false))
	_refresh()


func set_slot(index: int, data: Dictionary) -> void:
	slot_index = clampi(index, 0, 9)
	character_data = data.duplicate(true)
	character_data["slot_index"] = slot_index
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func set_disabled(value: bool) -> void:
	disabled = value
	_refresh()


func is_empty() -> bool:
	return not bool(character_data.get("valid", false)) or str(character_data.get("name", "")).strip_edges() == ""


func snapshot() -> Dictionary:
	return {"slot_index": slot_index, "empty": is_empty(), "selected": selected, "disabled": disabled, "character": character_data.duplicate(true)}


func _on_pressed() -> void:
	if not disabled:
		slot_pressed.emit(slot_index, character_data.duplicate(true))


func _on_hover(value: bool) -> void:
	hovered = value
	_refresh()


func _refresh() -> void:
	if hitbox == null:
		return
	hitbox.disabled = disabled
	var empty := is_empty()
	if empty:
		top_label.text = "Emplacement libre"
		bottom_label.text = ""
	else:
		top_label.text = str(character_data.get("name", "Personnage"))
		var level := int(character_data.get("level", 0))
		var profession := str(character_data.get("class_name", character_data.get("class", "")))
		var race := str(character_data.get("race_name", character_data.get("race", "")))
		var location := str(character_data.get("location", ""))
		var details := PackedStringArray()
		if profession != "":
			details.append(profession)
		if race != "":
			details.append(race)
		if location != "":
			details.append(location)
		bottom_label.text = "Niv. %d  %s" % [level, " · ".join(details)]
	var gold := Color(1.0, 0.78, 0.27, 1.0)
	var normal_color := Color(0.78, 0.78, 0.72, 1.0)
	var dim := Color(0.46, 0.46, 0.43, 1.0)
	top_label.modulate = dim if empty else (gold if selected or hovered else normal_color)
	bottom_label.modulate = Color(0.67, 0.63, 0.51, 1.0) if not empty else dim
	if radio.texture is AtlasTexture:
		var atlas := radio.texture as AtlasTexture
		if selected or hovered:
			atlas.region = Rect2(186, 8, 20, 20)
		else:
			atlas.region = Rect2(216, 8, 20, 20)
	radio.modulate = Color.WHITE if not disabled else Color(0.45, 0.45, 0.45, 1.0)
