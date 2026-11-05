extends CanvasLayer
class_name DaocQuestOfferWindow

## P1-110 — la fenêtre d offre / de récompense de quête du client d origine
## (0x81 code 0x22 offre, 0x21 récompense — PacketLib194.SendQuestWindow) :
## nom, résumé, histoire, objectifs, argent, % d expérience, récompenses
## fixes et récompenses AU CHOIX (cocher jusqu à `optional_choices`).
## « Accepter » / « Terminer » envoie 0x40 QuestRewardChosen (réponse 1 +
## index cochés) ; « Refuser » / « Pas encore » ferme sans rien envoyer — DOL
## ignore toute réponse autre que 1 (QuestRewardChosenHandler).

signal answered(accept: bool, chosen: Array, quest_id: int, npc_object_id: int)

var last_window: Dictionary = {}
var shown_count := 0
var answers_sent := 0
var chosen: Array = []
var _panel: PanelContainer = null
var _title: Label = null
var _body: Label = null
var _rewards: VBoxContainer = null
var _accept: Button = null
var _decline: Button = null
var _checks: Array = []


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "QuestOffer"
	_panel.position = Vector2(400, 100)
	_panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(400, 0)
	_body.add_theme_font_size_override("font_size", 11)
	box.add_child(_body)
	_rewards = VBoxContainer.new()
	box.add_child(_rewards)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_accept = Button.new()
	_accept.pressed.connect(_on_answer.bind(true))
	buttons.add_child(_accept)
	_decline = Button.new()
	_decline.pressed.connect(_on_answer.bind(false))
	buttons.add_child(_decline)
	box.add_child(buttons)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func show_window(window: Dictionary) -> void:
	last_window = window.duplicate(true)
	shown_count += 1
	chosen = []
	_checks = []
	if _panel == null:
		return
	var offer := str(window.get("kind", "offer")) == "offer"
	_title.text = "%s%s" % [str(window.get("name", "")), " (offre)" if offer else " (recompense)"]
	var texts: Array[String] = []
	if str(window.get("summary", "")) != "":
		texts.append(str(window.get("summary", "")))
	if str(window.get("story", "")) != "":
		texts.append("")
		texts.append(str(window.get("story", "")))
	var goals: Array = window.get("goals", [])
	if not goals.is_empty():
		texts.append("")
		texts.append("Objectifs :")
		for goal in goals:
			texts.append("  - %s" % str(goal))
	var money := int(window.get("money", 0))
	var xp := int(window.get("experience_percent", 0))
	if money > 0 or xp > 0:
		texts.append("")
		texts.append("Recompense : %s%s" % [_money_text(money) if money > 0 else "", (" · %d %% d experience" % xp) if xp > 0 else ""])
	_body.text = "\n".join(texts)
	for child in _rewards.get_children():
		child.queue_free()
	var fixed: Array = window.get("rewards", [])
	if not fixed.is_empty():
		var head := Label.new()
		head.text = "Objets :"
		head.add_theme_font_size_override("font_size", 11)
		_rewards.add_child(head)
		for item in fixed:
			var line := Label.new()
			line.text = "  %s" % str((item as Dictionary).get("name", ""))
			line.add_theme_font_size_override("font_size", 11)
			_rewards.add_child(line)
	var optional: Array = window.get("optional_rewards", [])
	if not optional.is_empty():
		var head2 := Label.new()
		head2.text = "Au choix (%d) :" % int(window.get("optional_choices", 1))
		head2.add_theme_font_size_override("font_size", 11)
		_rewards.add_child(head2)
		for i in optional.size():
			var check := CheckBox.new()
			check.text = str((optional[i] as Dictionary).get("name", ""))
			check.add_theme_font_size_override("font_size", 11)
			check.toggled.connect(_on_check.bind(i))
			_rewards.add_child(check)
			_checks.append(check)
	_accept.text = "Accepter" if offer else "Terminer"
	_decline.text = "Refuser" if offer else "Pas encore"
	_panel.visible = true


static func _money_text(copper: int) -> String:
	var parts: Array[String] = []
	var remaining := copper
	# DAoC : 100 cuivres = 1 argent, 100 argent = 1 or, 1000 or = 1 platine (DOL Money.cs).
	for pair in [["platine", 10000000], ["or", 10000], ["argent", 100]]:
		var unit := int(pair[1])
		var count := remaining / unit
		remaining %= unit
		if count > 0:
			parts.append("%d %s" % [count, str(pair[0])])
	if remaining > 0 or parts.is_empty():
		parts.append("%d cuivre" % remaining)
	return " ".join(parts)


## Les cases cochees sont bornees par le nombre de choix : la derniere cochee
## de trop se decoche.
func _on_check(pressed: bool, index: int) -> void:
	var limit := maxi(1, int(last_window.get("optional_choices", 1)))
	if pressed:
		if chosen.size() >= limit:
			(_checks[index] as CheckBox).set_pressed_no_signal(false)
			return
		if not chosen.has(index):
			chosen.append(index)
	else:
		chosen.erase(index)


func _on_answer(accept: bool) -> void:
	answers_sent += 1
	answered.emit(accept, chosen.duplicate(), int(last_window.get("quest_id", 0)), int(last_window.get("npc_object_id", 0)))
	hide_window()


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "answers_sent": answers_sent, "kind": str(last_window.get("kind", "")),
		"quest_id": int(last_window.get("quest_id", 0)), "chosen": chosen.duplicate(), "optional": (last_window.get("optional_rewards", []) as Array).size()}
