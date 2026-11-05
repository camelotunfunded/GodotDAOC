extends Button
class_name DaocSpellDragButton

func _get_drag_data(_at_position: Vector2) -> Variant:
	var spell := (get_meta("spell_reference", {}) as Dictionary).duplicate(true)
	if spell.is_empty():
		return null
	spell["kind"] = "spell"
	if icon != null:
		var preview_icon := TextureRect.new()
		preview_icon.texture = icon
		preview_icon.size = Vector2(32, 32)
		set_drag_preview(preview_icon)
	else:
		var preview := Label.new()
		preview.text = str(spell.get("name", "Sort"))
		set_drag_preview(preview)
	return spell
