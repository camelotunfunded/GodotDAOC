extends Button
class_name DaocInventoryDragButton

## P1-98 — une case de la fenetre d'inventaire qui se GLISSE (vers une autre
## case ou vers la quickbar) et qui RECOIT (une case de l'inventaire ou du sac).
## Elle ne decide rien : elle porte le logement eInventorySlot qu'elle
## represente et l'objet qui s'y trouve (meta), et remonte les gestes.

signal item_dropped(from_slot: int, to_slot: int)
signal auto_equip_dropped(from_slot: int)
## P1-121 — l'objet est lache hors de toute fenetre, donc sur le monde : le
## client d'origine le donne alors a l'objet vise (MoveItem vers 1000 + id).
signal item_dropped_on_world(from_slot: int, screen_position: Vector2)

var inventory_slot := -1
var auto_equip_target := false
var item: Dictionary = {}
var _dragging := false


func set_item(value: Dictionary) -> void:
	item = value.duplicate(true)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	var data := {"kind": "item", "inventory_slot": inventory_slot, "slot": inventory_slot,
		"name": str(item.get("name", "")), "model": int(item.get("model", item.get("model_id", 0))),
		"object_type": int(item.get("object_type", 0)), "source": "inventory_window"}
	var preview := Label.new()
	preview.text = str(item.get("name", "objet"))
	preview.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 2)
	set_drag_preview(preview)
	_dragging = true
	return data


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	var viewport := get_viewport()
	if viewport == null or viewport.gui_is_drag_successful():
		return
	# Un lacher refuse PAR une fenetre reste un refus ; seul le vide est le monde.
	if viewport.gui_get_hovered_control() != null:
		return
	item_dropped_on_world.emit(inventory_slot, viewport.get_mouse_position())


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	if inventory_slot < 0 and not auto_equip_target:
		return false  # un onglet de sac n'est pas un logement
	var source_slot := int(d.get("inventory_slot", -1))
	if str(d.get("kind", "")) != "item" or str(d.get("source", "")) != "inventory_window" or source_slot < 0:
		return false
	return source_slot >= 40 if auto_equip_target else source_slot != inventory_slot


func _drop_data(_position: Vector2, data: Variant) -> void:
	var from_slot := int((data as Dictionary).get("inventory_slot", -1))
	if auto_equip_target:
		auto_equip_dropped.emit(from_slot)
	else:
		item_dropped.emit(from_slot, inventory_slot)
