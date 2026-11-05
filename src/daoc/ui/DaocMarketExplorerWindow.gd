extends CanvasLayer
class_name DaocMarketExplorerWindow

## P1-122 — l'explorateur du marche (PNJ Market Explorer, zones de logement).
## Interagir avec lui ouvre une fenetre vide (0x1F = 255) ; « Chercher »
## envoie 0x11 (nom, niveaux, prix, page) ; le serveur repond par 0x1F avec
## une page d'objets. « Acheter » deplace la ligne vers le sac : 0xDD depuis
## 1000 + index (OpenDAoC MarketExplorer.FirstClientSlot) ; le serveur passe
## par le marchand de consignation de la maison (numero de lot) et debite.

signal search_requested(search: Dictionary)
signal buy_requested(from_slot: int)

const EconomyCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEconomyCodec.gd")
const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")

var results: Array = []
var page := 0
var max_page := 0
var searches := 0
var _panel: PanelContainer = null
var _name: LineEdit = null
var _level_min: SpinBox = null
var _level_max: SpinBox = null
var _price_max: SpinBox = null
var _crafted: CheckBox = null
var _rows: VBoxContainer = null
var _pages: Label = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "MarketExplorerWindow"
	_panel.position = Vector2(200, 70)
	_panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.65, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Explorateur du marche"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(title)
	var criteria := HBoxContainer.new()
	_name = LineEdit.new()
	_name.placeholder_text = "Nom"
	_name.custom_minimum_size = Vector2(150, 0)
	criteria.add_child(_name)
	_level_min = _spin(criteria, "Niv.", 1, 51, 1)
	_level_max = _spin(criteria, "a", 1, 51, 51)
	_price_max = _spin(criteria, "Prix max", 0, 2000000000, 0)
	_crafted = CheckBox.new()
	_crafted.text = "Artisan"
	criteria.add_child(_crafted)
	box.add_child(criteria)
	var actions := HBoxContainer.new()
	var search := Button.new()
	search.text = "Chercher"
	search.pressed.connect(func() -> void: request_search(0))
	actions.add_child(search)
	var previous := Button.new()
	previous.text = "<"
	previous.pressed.connect(func() -> void: request_search(maxi(0, page - 1)))
	actions.add_child(previous)
	_pages = Label.new()
	actions.add_child(_pages)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(func() -> void: request_search(mini(max_page, page + 1)))
	actions.add_child(next)
	box.add_child(actions)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 280)
	_rows = VBoxContainer.new()
	scroll.add_child(_rows)
	box.add_child(scroll)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	box.add_child(close)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


func _spin(parent: Control, caption: String, min_value: float, max_value: float, value: float) -> SpinBox:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	parent.add_child(spin)
	return spin


func current_search(target_page: int) -> Dictionary:
	return {"name": _name.text, "level_min": int(_level_min.value), "level_max": int(_level_max.value),
		"price_max": int(_price_max.value), "player_crafted": _crafted.button_pressed, "page": target_page}


func request_search(target_page: int) -> void:
	searches += 1
	search_requested.emit(current_search(target_page))


func apply_market(market: Dictionary) -> void:
	_panel.visible = true
	results = (market.get("items", []) as Array).duplicate(true)
	page = int(market.get("page", 0))
	max_page = int(market.get("max_page", 0))
	_refresh()


func buy(index: int) -> void:
	buy_requested.emit(EconomyCodec.MARKET_EXPLORER_FIRST + index)


func hide_window() -> void:
	_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _refresh() -> void:
	_pages.text = "page %d / %d" % [page + 1, max_page + 1]
	for child in _rows.get_children():
		child.queue_free()
	for value in results:
		var item := value as Dictionary
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%2d  %s  (lot %d)  %s" % [int(item.get("level", 0)), str(item.get("name", "")),
			int(item.get("lot", 0)), MerchantCodec.money_text(int(item.get("price", 0)))]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(item.get("unusable", false)):
			label.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
		row.add_child(label)
		var button := Button.new()
		button.text = "Acheter"
		button.pressed.connect(buy.bind(int(item.get("index", 0))))
		row.add_child(button)
		_rows.add_child(row)
