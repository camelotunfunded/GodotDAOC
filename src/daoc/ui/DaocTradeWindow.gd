extends CanvasLayer
class_name DaocTradeWindow

const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")

## P1-114 — la fenêtre d échange (0xEA TradeWindow, PacketLib1109 : la 1.109 a
## fait passer les objets du partenaire par le même `WriteItemData` que
## l inventaire 0x02, donc le bloc de 24 octets de P1-95). Le serveur la
## rouvre à chaque changement ; **40 octets nuls la FERMENT**
## (SendCloseTradeWindow).
##
## Les trois boutons envoient le MÊME paquet 0xEB ModifyTrade (28 octets,
## game.dll FUN_0042a8be / FUN_0042a935), seul le premier octet change :
## 0 fermer, 1 mettre à jour (logements offerts + argent + réparation +
## combinaison), 2 accepter. DOL n accepte l échange que lorsque les DEUX
## côtés ont envoyé un 2 (PlayerTradeWindow.AcceptTrade).

signal update_requested(slots: Array, copper: int, repairing: bool, combine: bool)
signal accept_requested
signal close_requested

var last_trade: Dictionary = {}
var offered_slots: Array = []
var offered_copper := 0
var repairing := false
var combine := false
var shown_count := 0
var updates_sent := 0
var accepts_sent := 0
var _panel: PanelContainer = null
var _title: Label = null
var _mine: Label = null
var _theirs: Label = null
var _flags: Label = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "TradeWindow"
	_panel.position = Vector2(300, 140)
	_panel.custom_minimum_size = Vector2(380, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.06, 0.94)
	style.border_color = Color(0.6, 0.72, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.93, 0.98, 0.78))
	box.add_child(_title)
	_mine = Label.new()
	_mine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mine.add_theme_font_size_override("font_size", 11)
	box.add_child(_mine)
	_theirs = Label.new()
	_theirs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_theirs.add_theme_font_size_override("font_size", 11)
	box.add_child(_theirs)
	_flags = Label.new()
	_flags.add_theme_font_size_override("font_size", 10)
	box.add_child(_flags)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["Mettre a jour", "_on_update"], ["Accepter", "_on_accept"], ["Annuler", "_on_close"]]:
		var button := Button.new()
		button.text = str(pair[0])
		button.pressed.connect(Callable(self, str(pair[1])))
		buttons.add_child(button)
	box.add_child(buttons)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func show_trade(trade: Dictionary) -> void:
	last_trade = trade.duplicate(true)
	if bool(trade.get("closed", false)):
		hide_window()
		return
	if _panel == null:
		return
	if not _panel.visible:
		shown_count += 1
	repairing = bool(trade.get("repairing", false))
	combine = bool(trade.get("combine", false))
	var partner := str(trade.get("partner_name", ""))
	_title.text = str(trade.get("caption", "")) if str(trade.get("caption", "")) != "" else ("Echange avec %s" % partner)
	var mine: Array[String] = ["Vous offrez : %s" % MerchantCodec.money_text(int(trade.get("my_money", 0)))]
	var my_slots: Array = trade.get("my_slots", [])
	if not my_slots.is_empty():
		mine.append("  logements : %s" % ", ".join(my_slots.map(func(s): return str(s))))
	_mine.text = "\n".join(mine)
	var theirs: Array[String] = ["%s offre : %s" % [partner if partner != "" else "Le partenaire", MerchantCodec.money_text(int(trade.get("partner_money", 0)))]]
	for value in (trade.get("partner_items", []) as Array):
		var item := value as Dictionary
		if bool(item.get("empty", false)):
			continue
		theirs.append("  %s (qualite %d, condition %d %%)" % [str(item.get("name", "")), int(item.get("quality", 0)), int(item.get("condition", 0))])
	_theirs.text = "\n".join(theirs)
	_flags.text = "%s%s" % ["reparation " if repairing else "", "combinaison" if combine else ""]
	_panel.visible = true


## Ce que J OFFRE : des logements d inventaire et de l argent, envoyés au
## serveur par un 0xEB à réponse 1.
func set_offer(slots: Array, copper: int) -> void:
	offered_slots = slots.duplicate()
	offered_copper = maxi(0, copper)


func _on_update() -> void:
	updates_sent += 1
	update_requested.emit(offered_slots.duplicate(), offered_copper, repairing, combine)


func _on_accept() -> void:
	accepts_sent += 1
	accept_requested.emit()


func _on_close() -> void:
	close_requested.emit()
	hide_window()


func hide_window() -> void:
	if _panel != null:
		_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func get_debug_snapshot() -> Dictionary:
	return {"shown": is_shown(), "shown_count": shown_count, "updates_sent": updates_sent, "accepts_sent": accepts_sent,
		"partner": str(last_trade.get("partner_name", "")), "partner_items": (last_trade.get("partner_items", []) as Array).size(),
		"partner_money": int(last_trade.get("partner_money", 0)), "offered_slots": offered_slots.duplicate(),
		"offered_copper": offered_copper, "repairing": repairing, "combine": combine}
