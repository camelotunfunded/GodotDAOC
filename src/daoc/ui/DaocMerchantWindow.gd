extends CanvasLayer
class_name DaocMerchantWindow

const XmlFrame = preload("res://src/daoc/ui/DaocXmlEngineFrame.gd")
const MerchantCodec = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")

## P1-114 — la boutique du marchand : les pages du 0x17 MerchantWindow
## (PacketLib168.SendMerchantWindow, disposition encore valable en 1.124) et
## les trois paquets que le client renvoie — 0x78 acheter, 0x79 vendre, 0xE0
## estimer (game.dll FUN_0042aff8 / FUN_0042b31d / FUN_0042b378).
##
## Un objet GRISÉ est un objet que le serveur a marqué inutilisable par la
## classe du joueur (l octet 6 du bloc) : DOL laisse quand même l acheter.
## Le prix est dans la monnaie de la PAGE (cuivre, points de prime, mithril,
## troc) — le type de fenêtre voyage tel quel dans le 0x78.
##
## Le client d origine vend en FAISANT GLISSER un objet du sac sur la boutique ;
## ici les lignes du sac portent « Estimer » et « Vendre », qui envoient
## exactement les mêmes deux paquets.

signal buy_requested(page_slot: int, count: int, window_type: int)
signal sell_requested(inventory_slot: int)
signal appraise_requested(inventory_slot: int)

## P1-122 : eMerchantWindowType 3..0x0D (IPacketLib) — les boutiques de maison.
const HOUSING_SHOP_TITLES := {
	3: "actes de propriete", 4: "exterieur", 5: "PNJ de maison", 6: "interieur", 7: "jardin",
	8: "coffres", 9: "artisanat", 10: "pierres de lien", 11: "menu interieur", 12: "tickets", 13: "tickets de guilde",
}
const CURRENCY_LABELS := {
	"copper": "", "bounty_points": " points de prime", "mithril": " mithril", "barter": " (troc)",
}

var pages: Dictionary = {}
var merchant_name := ""
var current_page := 0
var shown_count := 0
var buys_sent := 0
var sells_sent := 0
var appraisals_sent := 0
var last_backpack: Array = []
var _panel: PanelContainer = null
var _title: Label = null
var _tabs: HBoxContainer = null
var _items: VBoxContainer = null
var _bag: VBoxContainer = null
var _count: SpinBox = null


func _ready() -> void:
	layer = 23
	_panel = PanelContainer.new()
	_panel.name = "MerchantWindow"
	_panel.position = Vector2(180, 90)
	_panel.custom_minimum_size = Vector2(430, 0)
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
	_tabs = HBoxContainer.new()
	box.add_child(_tabs)
	_items = VBoxContainer.new()
	box.add_child(_items)
	var quantity := HBoxContainer.new()
	var quantity_label := Label.new()
	quantity_label.text = "Nombre :"
	quantity_label.add_theme_font_size_override("font_size", 11)
	quantity.add_child(quantity_label)
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 255
	_count.value = 1
	quantity.add_child(_count)
	box.add_child(quantity)
	var bag_head := Label.new()
	bag_head.text = "Votre sac"
	bag_head.add_theme_font_size_override("font_size", 12)
	bag_head.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	box.add_child(bag_head)
	_bag = VBoxContainer.new()
	box.add_child(_bag)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide_window)
	box.add_child(close)
	_panel.add_child(box)
	_panel.visible = false
	add_child(_panel)


## Une page du 0x17. DOL en envoie une par page du catalogue, donc la fenêtre
## s enrichit paquet après paquet sans se réinitialiser.
func add_page(page: Dictionary) -> void:
	pages[int(page.get("page", 0))] = page.duplicate(true)
	if not is_shown():
		shown_count += 1
		current_page = int(page.get("page", 0))
	_set_shown(true)
	_refresh()


func set_merchant_name(value: String) -> void:
	merchant_name = value
	_refresh()


## Les lignes du sac, telles que l inventaire les tient (P1-95).
func set_backpack(items: Array) -> void:
	last_backpack = items.duplicate(true)
	if is_shown():
		_refresh()


func select_page(page: int) -> void:
	current_page = page
	_refresh()


func _refresh() -> void:
	if _xml != null:
		_refresh_xml()
	if _panel == null:
		return
	var page: Dictionary = pages.get(current_page, {}) as Dictionary
	var shop_kind := str(HOUSING_SHOP_TITLES.get(int((pages.get(current_page, {}) as Dictionary).get("window_type", 0)), ""))
	_title.text = "%s%s — page %d" % [merchant_name if merchant_name != "" else "Marchand", " (%s)" % shop_kind if shop_kind != "" else "", current_page + 1]
	for child in _tabs.get_children():
		child.queue_free()
	var numbers := pages.keys()
	numbers.sort()
	if numbers.size() > 1:
		for number in numbers:
			var tab := Button.new()
			tab.text = str(int(number) + 1)
			tab.disabled = int(number) == current_page
			tab.pressed.connect(select_page.bind(int(number)))
			_tabs.add_child(tab)
	for child in _items.get_children():
		child.queue_free()
	var currency := str(page.get("currency", "copper"))
	for value in (page.get("items", []) as Array):
		var item := value as Dictionary
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (niv. %d) — %s" % [str(item.get("name", "")), int(item.get("level", 0)), _price_text(int(item.get("price", 0)), currency)]
		label.add_theme_font_size_override("font_size", 11)
		if bool(item.get("unusable", false)):
			label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		label.custom_minimum_size = Vector2(320, 0)
		line.add_child(label)
		var buy := Button.new()
		buy.text = "Acheter"
		buy.pressed.connect(_on_buy.bind(int(item.get("page_slot", 0))))
		line.add_child(buy)
		_items.add_child(line)
	for child in _bag.get_children():
		child.queue_free()
	for value in last_backpack:
		# L arbitre rend parfois des numeros de logement nus : seules les lignes
		# decrites servent ici.
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item := value as Dictionary
		if bool(item.get("empty", false)):
			continue
		var slot := int(item.get("slot", -1))
		if slot < 0:
			continue
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = str(item.get("name", ""))
		label.add_theme_font_size_override("font_size", 11)
		label.custom_minimum_size = Vector2(280, 0)
		line.add_child(label)
		var appraise := Button.new()
		appraise.text = "Estimer"
		appraise.pressed.connect(_on_appraise.bind(slot))
		line.add_child(appraise)
		var sell := Button.new()
		sell.text = "Vendre"
		sell.pressed.connect(_on_sell.bind(slot))
		line.add_child(sell)
		_bag.add_child(line)


func _price_text(price: int, currency: String) -> String:
	# P1-122 : les boutiques de maison (types 3..0x0D) se paient en cuivre (DOL
	# GameHousingMerchant / HousingMenu).
	if currency == "copper" or currency.begins_with("housing_"):
		return MerchantCodec.money_text(price)
	return "%d%s" % [price, str(CURRENCY_LABELS.get(currency, ""))]


func _on_buy(page_slot: int) -> void:
	buys_sent += 1
	var page: Dictionary = pages.get(current_page, {}) as Dictionary
	buy_requested.emit(page_slot, quantity if _xml != null else int(_count.value), int(page.get("window_type", 0)))
	if _xml != null and not keep_quantity and quantity != 1:
		quantity = 1
		_refresh()


func _on_sell(slot: int) -> void:
	sells_sent += 1
	sell_requested.emit(slot)


func _on_appraise(slot: int) -> void:
	appraisals_sent += 1
	appraise_requested.emit(slot)


func hide_window() -> void:
	_set_shown(false)
	pages.clear()
	selected_item = -1
	sell_slot = -1


func is_shown() -> bool:
	if _xml != null:
		return _xml.visible
	return _panel != null and _panel.visible


func _set_shown(value: bool) -> void:
	if _xml != null:
		_xml.visible = value
		if value:
			_xml.position = _xml.position.clamp(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size) - _xml.size * 0.5)
	elif _panel != null:
		_panel.visible = value


## ═══ P1-134 : la fenetre `merchant` de merchant_window.xml ═══════════════
## Audit des fenetres du 2026-09-29 : 350 x 458, liste 1005 sur le canal
## `merchant_page0`, titre `merchant_title`, page `merchant_page_display`,
## quantite `merchant_quantity`, cinq compteurs `merchant_mithril..copper`
## (la bourse du JOUEUR, pas un prix). Boutons par ControlId : 1000/1001
## pages, 1002 BUY, 1003 SELL, 1004 APPRAISE, 1007/1008 quantite, 1009 Keep
## Qty. Le XML ne dit pas ce que fait chaque bouton : le moteur d origine le
## code en dur, d ou le branchement ici.
##
## Vendre et estimer : on LACHE un objet de l inventaire sur la fenetre (le
## geste d origine). Le lacher estime (0xE0, sans rien engager) et retient
## l objet ; SELL le vend (0x79), APPRAISE le re-estime. Sans le XML du
## client, l ancien panneau Godot reste en place.
var _xml: XmlFrame = null
var _bus: DaocUiAdapterBus = null
var _icon_atlas: RefCounted = null
var selected_item := -1
var sell_slot := -1
var sell_name := ""
var quantity := 1
var keep_quantity := false
var purse_copper := 0


func use_xml_window(builder: DaocUiWindowBuilder, window: Dictionary, bus: DaocUiAdapterBus) -> bool:
	var frame := XmlFrame.create(builder, window)
	if frame == null:
		return false
	_bus = bus
	if _icon_atlas == null and builder.library != null:
		_icon_atlas = preload("res://src/daoc/ui/DaocSpellIconAtlas.gd").new()
		_icon_atlas.setup(builder.library.ui_root.get_base_dir())
	_xml = frame
	_xml.accepts_items = true
	_xml.position = Vector2(180, 90)
	_xml.visible = _panel != null and _panel.visible
	_xml.scale = get_meta("daoc_ui_scale", Vector2.ONE)
	add_child(_xml)
	if _panel != null:
		_panel.visible = false
	_xml.close_requested.connect(hide_window)
	_xml.item_dropped.connect(_on_item_dropped)
	XmlFrame.on_click(_xml.control("1000"), func() -> void: _step_page(-1))
	XmlFrame.on_click(_xml.control("1001"), func() -> void: _step_page(1))
	XmlFrame.on_click(_xml.control("1002"), _on_buy_selected)
	XmlFrame.on_click(_xml.control("1003"), func() -> void:
		if sell_slot >= 0:
			_on_sell(sell_slot)
			sell_slot = -1
			_refresh())
	XmlFrame.on_click(_xml.control("1004"), func() -> void:
		if sell_slot >= 0:
			_on_appraise(sell_slot))
	XmlFrame.on_click(_xml.control("1007"), func() -> void: _step_quantity(-1))
	XmlFrame.on_click(_xml.control("1008"), func() -> void: _step_quantity(1))
	var keep := _xml.control("1009") as BaseButton
	if keep != null:
		keep.toggled.connect(func(on: bool) -> void: keep_quantity = on)
	_publish_purse()
	_refresh()
	return true


func uses_xml() -> bool:
	return _xml != null


## La bourse du joueur, en cuivre (0xFA en ligne, `purse()` hors ligne).
func set_purse(copper: int) -> void:
	purse_copper = maxi(0, copper)
	_publish_purse()


func _publish_purse() -> void:
	if _bus == null:
		return
	# Monnaie DOL (gameutils/Money.cs) : 100 cu = 1 ar, 100 ar = 1 or,
	# 1000 or = 1 pl, 1000 pl = 1 mi.
	var rest := purse_copper
	var copper := rest % 100
	rest /= 100
	var silver := rest % 100
	rest /= 100
	var gold := rest % 1000
	rest /= 1000
	_bus.publish_many({"merchant_mithril": str(rest / 1000), "merchant_platinum": str(rest % 1000),
		"merchant_gold": str(gold), "merchant_silver": str(silver), "merchant_copper": str(copper)})


func _step_page(delta: int) -> void:
	var numbers := pages.keys()
	numbers.sort()
	var index := numbers.find(current_page)
	if index < 0 or numbers.is_empty():
		return
	select_page(int(numbers[clampi(index + delta, 0, numbers.size() - 1)]))


func _step_quantity(delta: int) -> void:
	quantity = clampi(quantity + delta, 1, 255)
	if _count != null:
		_count.value = quantity
	_refresh()


func _select_item(page_slot: int) -> void:
	# Deuxieme clic sur la ligne deja choisie = acheter, comme le double clic.
	if selected_item == page_slot:
		_on_buy(page_slot)
		return
	selected_item = page_slot
	_refresh()


func _on_buy_selected() -> void:
	if selected_item < 0:
		return
	_on_buy(selected_item)


func _on_item_dropped(slot: int) -> void:
	sell_slot = slot
	sell_name = ""
	for value in last_backpack:
		if value is Dictionary and int((value as Dictionary).get("slot", -1)) == slot:
			sell_name = str((value as Dictionary).get("name", ""))
	_on_appraise(slot)
	_refresh()


func _refresh_xml() -> void:
	var page: Dictionary = pages.get(current_page, {}) as Dictionary
	var currency := str(page.get("currency", "copper"))
	var rows: Array = []
	for value in (page.get("items", []) as Array):
		var item := value as Dictionary
		var slot := int(item.get("page_slot", 0))
		var state := "highlit" if slot == selected_item else ("greyed" if bool(item.get("unusable", false)) else "normal")
		var level := int(item.get("level", 0))
		rows.append({"text": "%s%s   %s" % [str(item.get("name", "")), " (%d)" % level if level > 0 else "", _price_text(int(item.get("price", 0)), currency)],
			"icon_texture": _icon_atlas.texture_for_item_model(int(item.get("model", 0))) if _icon_atlas != null else null,
			"state": state, "on_click": _select_item.bind(slot), "tooltip": "Clic : choisir, second clic ou BUY : acheter"})
	var numbers := pages.keys()
	var shop_kind := str(HOUSING_SHOP_TITLES.get(int(page.get("window_type", 0)), ""))
	var title := merchant_name if merchant_name != "" else "Merchant"
	if shop_kind != "":
		title += " (%s)" % shop_kind
	if sell_slot >= 0:
		title += " — vendre : %s" % (sell_name if sell_name != "" else "logement %d" % sell_slot)
	if _bus != null:
		_bus.publish_many({"merchant_page0": rows, "merchant_title": title,
			"merchant_page_display": "Page %d of %d" % [numbers.find(current_page) + 1, maxi(1, numbers.size())],
			"merchant_quantity": str(quantity)})


func get_debug_snapshot() -> Dictionary:
	var page: Dictionary = pages.get(current_page, {}) as Dictionary
	return {"shown": is_shown(), "shown_count": shown_count, "pages": pages.size(), "current_page": current_page,
		"items": (page.get("items", []) as Array).size(), "currency": str(page.get("currency", "")),
		"merchant": merchant_name, "buys_sent": buys_sent, "sells_sent": sells_sent, "appraisals_sent": appraisals_sent,
		"bag_lines": last_backpack.size()}
