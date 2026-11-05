extends CanvasLayer
class_name DaocQuestJournalWindow

## P1-110 — le journal de quêtes du client d origine (touche « Quest Journal »,
## action 82 du keyboard.dat, ou /journal) : les quêtes du 0x83 QuestEntry
## (P1-78 : nom, description ou objectifs cochés d une RewardQuest) et la tâche
## de l index 0 (SendTaskInfo). « Abandonner » envoie 0x4F RemoveQuestRequest
## avec l index de la quête ; le serveur répond par un 0x83 vide qui la retire.

signal abandon_requested(quest_index: int)

var quests: Dictionary = {}
var task_text := ""
var shown_count := 0
var abandons_requested := 0
var _panel: PanelContainer = null
var _rows: VBoxContainer = null
var _task: Label = null


func _ready() -> void:
	layer = 22
	_panel = PanelContainer.new()
	_panel.name = "QuestJournal"
	_panel.position = Vector2(760, 300)
	_panel.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Journal de quetes"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(title)
	_task = Label.new()
	_task.add_theme_font_size_override("font_size", 11)
	_task.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task.custom_minimum_size = Vector2(344, 0)
	box.add_child(_task)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_panel.add_child(box)
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)
	_rebuild()


## `journal` : index -> quete du 0x83 (name, description, goals[{text, achieved}], level, reward_quest).
func set_quests(journal: Dictionary) -> void:
	quests = journal.duplicate(true)
	_rebuild()


func set_task(text: String) -> void:
	task_text = text
	_rebuild()


func toggle() -> void:
	if _panel == null:
		return
	if _panel.visible:
		_panel.visible = false
	else:
		show_journal()


func show_journal() -> void:
	shown_count += 1
	_rebuild()
	if _panel != null:
		_panel.visible = true


func hide_journal() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _rebuild() -> void:
	if _rows == null:
		return
	_task.text = "Tache : %s" % task_text if task_text != "" else "Aucune tache en cours."
	for child in _rows.get_children():
		child.queue_free()
	var keys: Array = quests.keys()
	keys.sort()
	if keys.is_empty():
		var empty := Label.new()
		empty.text = "(aucune quete)"
		empty.add_theme_font_size_override("font_size", 11)
		_rows.add_child(empty)
		return
	for key in keys:
		var quest := quests[key] as Dictionary
		var block := VBoxContainer.new()
		var head := HBoxContainer.new()
		var name := Label.new()
		name.text = str(quest.get("name", "")) + (" (niveau %d)" % int(quest.get("level", 0)) if int(quest.get("level", 0)) > 0 else "")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_size_override("font_size", 12)
		name.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
		head.add_child(name)
		var abandon := Button.new()
		abandon.text = "Abandonner"
		abandon.add_theme_font_size_override("font_size", 10)
		abandon.tooltip_text = "0x4F RemoveQuestRequest, index %d" % (int(key) - 1)
		abandon.pressed.connect(_on_abandon.bind(int(key)))
		head.add_child(abandon)
		block.add_child(head)
		var description := Label.new()
		description.text = str(quest.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(344, 0)
		description.add_theme_font_size_override("font_size", 11)
		block.add_child(description)
		for goal_value in quest.get("goals", []):
			var goal := goal_value as Dictionary
			var line := Label.new()
			line.text = "  %s %s" % ["[x]" if bool(goal.get("achieved", false)) else "[ ]", str(goal.get("text", ""))]
			line.add_theme_font_size_override("font_size", 11)
			line.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if bool(goal.get("achieved", false)) else Color(0.9, 0.9, 0.9))
			block.add_child(line)
		_rows.add_child(block)


## L index du 0x83 commence a 1 ; le 0x4F compte les quetes actives depuis 0.
func _on_abandon(journal_index: int) -> void:
	abandons_requested += 1
	abandon_requested.emit(journal_index - 1)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		hide_journal()


func _unhandled_input(event: InputEvent) -> void:
	if is_shown() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_journal()


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "quests": quests.size(), "task": task_text, "abandons_requested": abandons_requested}
