extends CanvasLayer
class_name DaocDeathScreen

## P1-110 — l écran de mort du client d origine : le monde vire au rouge
## sombre, « Vous êtes mort », qui vous a tué, ce que la mort a coûté (points
## d expérience perdus, lus sur le 0x91 qui suit ; constitution perdue, lue
## sur le 0xFB de P1-106) et le bouton « Libérer » qui envoie /release. Le
## compte à rebours de release est le 0xF3 de P1-109 (DaocTimerWindow). Le
## 0x89 PlayerRevive efface tout (P1-97).

signal release_requested

var shown_count := 0
var releases_requested := 0
var last_death: Dictionary = {}
var _vignette: ColorRect = null
var _panel: PanelContainer = null
var _title: Label = null
var _lines: Label = null
var _release: Button = null


func _ready() -> void:
	layer = 40
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.color = Color(0.35, 0.0, 0.0, 0.35)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	add_child(_vignette)
	_panel = PanelContainer.new()
	_panel.name = "Death"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(440, 160)
	_panel.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.02, 0.94)
	style.border_color = Color(0.8, 0.3, 0.2)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.text = "Vous etes mort."
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	box.add_child(_title)
	_lines = Label.new()
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.custom_minimum_size = Vector2(380, 0)
	_lines.add_theme_font_size_override("font_size", 12)
	box.add_child(_lines)
	_release = Button.new()
	_release.text = "Liberer (/release)"
	_release.pressed.connect(_on_release)
	box.add_child(_release)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func show_death(death: Dictionary) -> void:
	last_death = death.duplicate(true)
	shown_count += 1
	_refresh()
	if _vignette != null:
		_vignette.visible = true
	if _panel != null:
		_panel.visible = true


## Les pertes arrivent APRES la mort (0x91, 0xFB) : la fenetre se complete.
func set_losses(experience_permill_lost: int, constitution_lost: int) -> void:
	last_death["experience_permill_lost"] = experience_permill_lost
	last_death["constitution_lost"] = constitution_lost
	_refresh()


func _refresh() -> void:
	if _lines == null:
		return
	var texts: Array[String] = []
	var killer := str(last_death.get("killer_name", ""))
	if killer != "":
		texts.append("Tue par %s." % killer)
	var xp := int(last_death.get("experience_permill_lost", -1))
	if xp > 0:
		texts.append("Experience perdue : %d %% du niveau." % int(round(float(xp) / 10.0)))
	elif xp == 0:
		texts.append("Aucune experience perdue.")
	var con := int(last_death.get("constitution_lost", 0))
	if con > 0:
		texts.append("Constitution perdue a la mort : %d." % con)
	texts.append("Tapez /release ou cliquez pour revenir a votre point de liaison.")
	_lines.text = "\n".join(texts)


func hide_death() -> void:
	if _vignette != null:
		_vignette.visible = false
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _on_release() -> void:
	releases_requested += 1
	release_requested.emit()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "releases_requested": releases_requested,
		"experience_permill_lost": int(last_death.get("experience_permill_lost", -1)), "constitution_lost": int(last_death.get("constitution_lost", 0)),
		"killer_name": str(last_death.get("killer_name", ""))}
