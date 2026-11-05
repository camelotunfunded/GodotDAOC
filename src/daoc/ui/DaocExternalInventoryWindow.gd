extends CanvasLayer
class_name DaocExternalInventoryWindow

## P1-122 — coffre (0x02 type 3, logements 110..149), coffre de maison (4) et
## marchand de consignation (5 proprietaire, 6 visiteur ; logements 150..249).
## Le serveur (OpenDAoC GameVaultKeeper / GameInventoryObject) fait tout ;
## cette fenetre ne fait que DEPLACER : 0xDD entre le sac (40..79) et le
## premier logement libre de la fenetre, ou l'inverse. Proprietaire d'un
## marchand : « Prix » envoie 0x1A (logement RELATIF), « Retirer l'argent »
## 0x1C ; la caisse vient du 0x1E. Visiteur : prendre un objet = l'acheter
## (le serveur debite et confirme).

signal move_requested(from_slot: int, to_slot: int)
signal price_requested(relative_slot: int, price: int)
signal withdraw_requested

const EconomyCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEconomyCodec.gd")
const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")

var window_type := -1
var items: Array = []
var backpack: Array = []   # [{slot, name}] du sac
var till_copper := 0
var shown_count := 0
var _panel: PanelContainer = null
var _title: Label = null
var _till: Label = null
var _rows: VBoxContainer = null
var _bag: VBoxContainer = null
var _price: SpinBox = null
var _withdraw: Button = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "ExternalInventoryWindow"
	_panel.position = Vector2(640, 90)
	_panel.custom_minimum_size = Vector2(360, 0)
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
	_till = Label.new()
	_till.add_theme_font_size_override("font_size", 11)
	box.add_child(_till)
	var price_row := HBoxContainer.new()
	var price_label := Label.new()
	price_label.text = "Prix (cuivre) :"
	price_label.add_theme_font_size_override("font_size", 11)
	price_row.add_child(price_label)
	_price = SpinBox.new()
	_price.max_value = 2000000000
	_price.step = 1
	price_row.add_child(_price)
	_withdraw = Button.new()
	_withdraw.text = "Retirer l'argent"
	_withdraw.pressed.connect(func() -> void: withdraw_requested.emit())
	price_row.add_child(_withdraw)
	box.add_child(price_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 220)
	_rows = VBoxContainer.new()
	scroll.add_child(_rows)
	box.add_child(scroll)
	var bag_head := Label.new()
	bag_head.text = "Votre sac"
	bag_head.add_theme_font_size_override("font_size", 12)
	bag_head.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(bag_head)
	var bag_scroll := ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(340, 140)
	_bag = VBoxContainer.new()
	bag_scroll.add_child(_bag)
	box.add_child(bag_scroll)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	box.add_child(close)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


## Le contenu envoye par le serveur ({window_type, items}).
func apply_window(window: Dictionary) -> void:
	var incoming := int(window.get("window_type", -1))
	if incoming >= 0:
		if not _panel.visible:
			shown_count += 1
		window_type = incoming
		_panel.visible = true
	items = (window.get("items", []) as Array).duplicate(true)
	_refresh()


func set_backpack(value: Array) -> void:
	backpack = value.duplicate(true)
	if _panel != null and _panel.visible:
		_refresh()


func set_till(copper: int) -> void:
	till_copper = copper
	_refresh()


func is_owner_merchant() -> bool:
	return window_type == EconomyCodec.WINDOW_CONSIGNMENT_OWNER


func first_free_slot() -> int:
	var used := {}
	for value in items:
		used[int((value as Dictionary).get("slot", -1))] = true
	for slot in range(EconomyCodec.first_slot_of(window_type), EconomyCodec.last_slot_of(window_type) + 1):
		if not used.has(slot):
			return slot
	return -1


func first_free_backpack_slot() -> int:
	var used := {}
	for value in backpack:
		used[int((value as Dictionary).get("slot", -1))] = true
	for slot in range(40, 80):
		if not used.has(slot):
			return slot
	return -1


func deposit(backpack_slot: int) -> void:
	var to := first_free_slot()
	if to >= 0:
		move_requested.emit(backpack_slot, to)


func take(window_slot: int) -> void:
	var to := first_free_backpack_slot()
	if to >= 0:
		move_requested.emit(window_slot, to)


func set_price(window_slot: int, price: int) -> void:
	price_requested.emit(window_slot - EconomyCodec.first_slot_of(window_type), price)


func hide_window() -> void:
	_panel.visible = false


func is_shown() -> bool:
	return _panel != null and _panel.visible


func _refresh() -> void:
	if _panel == null:
		return
	_title.text = str(EconomyCodec.WINDOW_NAMES.get(window_type, "Coffre"))
	var owner := is_owner_merchant()
	_till.visible = owner
	_till.text = "Caisse : %s" % MerchantCodec.money_text(till_copper)
	_price.get_parent().visible = owner
	for child in _rows.get_children():
		child.queue_free()
	for value in items:
		var item := value as Dictionary
		var slot := int(item.get("slot", -1))
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%d  %s" % [slot, str(item.get("name", "?"))]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var take_button := Button.new()
		take_button.text = "Acheter" if window_type == EconomyCodec.WINDOW_CONSIGNMENT_VIEWER else "Prendre"
		take_button.pressed.connect(take.bind(slot))
		row.add_child(take_button)
		if owner:
			var price_button := Button.new()
			price_button.text = "Prix"
			price_button.pressed.connect(func() -> void: set_price(slot, int(_price.value)))
			row.add_child(price_button)
		_rows.add_child(row)
	for child in _bag.get_children():
		child.queue_free()
	if window_type == EconomyCodec.WINDOW_CONSIGNMENT_VIEWER:
		return
	for value in backpack:
		var item := value as Dictionary
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%d  %s" % [int(item.get("slot", -1)), str(item.get("name", "?"))]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var deposit_button := Button.new()
		deposit_button.text = "Deposer"
		deposit_button.pressed.connect(deposit.bind(int(item.get("slot", -1))))
		row.add_child(deposit_button)
		_bag.add_child(row)
