extends CanvasLayer
class_name DaocEffectBar

## P1-99 — la barre des effets actifs, en haut de l'ecran, comme dans le
## client d'origine : une icone par buff / debuff, et au survol le nom et le
## temps restant. La liste vient du serveur (0x7F UpdateIcons ; le runtime
## fusionne les deltas de 1.110+ et rend la liste complete) ; le compte a
## rebours est LOCAL entre deux 0x7F, a partir des secondes restantes recues.
## P1-108 — le CLIC DROIT sur une case demande l'annulation (0xF8, comme le
## client d'origine) : `cancel_requested(effect)`. Un effet negatif porte un
## cadre rouge, une immunite un cadre orange (l'original dit « protected by »
## et ne l'annule pas) ; le serveur reste juge et repond par un 0x7F.

signal cancel_requested(effect: Dictionary)
var cancel_requests := 0

const CELL := 28
const GAP := 2
const MARGIN_TOP := 4.0
const MARGIN_LEFT := 300.0

var icon_atlas: RefCounted = null
var effects: Array = []
var _received_msec := 0
var _root: HBoxContainer = null
var _cells: Array = []
var _last_tooltip_second := -1


func _ready() -> void:
	layer = 21
	_root = HBoxContainer.new()
	_root.name = "Effects"
	_root.add_theme_constant_override("separation", GAP)
	# A droite de la premiere quickbar (qui occupe le coin haut gauche), comme
	# la barre d effets du client d origine qui court en haut de l ecran.
	_root.position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_rebuild()


func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas
	_rebuild()


## `list` : [{effect_id, name, remaining_seconds, immunity, index}], la liste
## COMPLETE ; vide = plus aucun effet.
func set_effects(list: Array) -> void:
	effects = list.duplicate(true)
	_received_msec = Time.get_ticks_msec()
	_rebuild()


func remaining_seconds(effect: Dictionary) -> int:
	var base := int(effect.get("remaining_seconds", 0))
	if base <= 0:
		return 0
	var elapsed := int((Time.get_ticks_msec() - _received_msec) / 1000)
	return maxi(0, base - elapsed)


static func format_remaining(seconds: int) -> String:
	if seconds <= 0:
		return "permanent"
	if seconds >= 3600:
		return "%dh%02d" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%d min %02d s" % [seconds / 60, seconds % 60]
	return "%d s" % seconds


func _tooltip_for(effect: Dictionary) -> String:
	var label := str(effect.get("name", "effet"))
	if bool(effect.get("immunity", false)):
		label += " (immunite)"
	elif bool(effect.get("negative", false)):
		label += " (effet negatif)"
	var lines := "%s\n%s" % [label, format_remaining(remaining_seconds(effect))]
	if can_cancel(effect):
		lines += "\nClic droit : annuler"
	return lines


## Le client d origine n annule pas une immunite ; un debuff ne s annule pas
## non plus (le serveur le refuserait). Tout le reste part en 0xF8.
static func can_cancel(effect: Dictionary) -> bool:
	return not bool(effect.get("immunity", false)) and not bool(effect.get("negative", false)) and int(effect.get("tooltip_id", effect.get("effect_id", 0))) > 0


func _on_cell_input(event: InputEvent, effect: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if can_cancel(effect):
			cancel_requests += 1
			cancel_requested.emit(effect.duplicate(true))


func _rebuild() -> void:
	if _root == null:
		return
	for child in _root.get_children():
		child.queue_free()
	_cells.clear()
	for value in effects:
		var effect := value as Dictionary
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(CELL, CELL)
		cell.tooltip_text = _tooltip_for(effect)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
		if bool(effect.get("immunity", false)):
			style.border_color = Color(0.95, 0.6, 0.2)
		elif bool(effect.get("negative", false)):
			style.border_color = Color(0.85, 0.25, 0.2)
		else:
			style.border_color = Color(0.75, 0.65, 0.4)
		style.set_border_width_all(1)
		cell.add_theme_stylebox_override("panel", style)
		cell.gui_input.connect(_on_cell_input.bind(effect))
		var icon := TextureRect.new()
		icon.position = Vector2(1, 1)
		icon.size = Vector2(CELL - 2, CELL - 2)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icon_atlas != null and icon_atlas.has_method("texture_for"):
			icon.texture = icon_atlas.call("texture_for", int(effect.get("icon", effect.get("effect_id", 0))), "skill" if bool(effect.get("ability_icon", false)) else "spell") as Texture2D
		cell.add_child(icon)
		if icon.texture == null:
			var fallback := Label.new()
			fallback.text = str(effect.get("name", "?")).left(3)
			fallback.add_theme_font_size_override("font_size", 8)
			fallback.position = Vector2(2, 8)
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(fallback)
		_root.add_child(cell)
		_cells.append(cell)


func _process(_delta: float) -> void:
	# Les infobulles suivent le compte a rebours, une fois par seconde.
	var second := int(Time.get_ticks_msec() / 1000)
	if second == _last_tooltip_second or _cells.is_empty():
		return
	_last_tooltip_second = second
	for i in range(mini(_cells.size(), effects.size())):
		(_cells[i] as Control).tooltip_text = _tooltip_for(effects[i] as Dictionary)


func get_debug_snapshot() -> Dictionary:
	var out: Array = []
	for effect in effects:
		out.append({"name": str((effect as Dictionary).get("name", "")), "effect_id": int((effect as Dictionary).get("effect_id", 0)),
			"remaining": remaining_seconds(effect as Dictionary), "icon": (_cells.size() > out.size()) and ((_cells[out.size()] as Control).get_child(0) as TextureRect).texture != null})
	return {"count": effects.size(), "effects": out}
