extends Control
class_name DaocXmlEngineFrame

## P1-134 — cadre d une fenetre XML PILOTEE PAR LE MOTEUR (marchand,
## entraineur). Le `DaocUiWindowManager` monte les fenetres que le joueur
## ouvre depuis le menu ; celles-ci s ouvrent sur un paquet serveur et leur
## logique vit dans leur script (DaocMerchantWindow, DaocTrainerWindow). Le
## cadre apporte ce que le XML declare sans le dessiner : la barre de titre
## (`TitleHeight`) qui deplace, la croix (`CloseButton`, gabarit
## `window_close` de styles.xml) et l acces aux controles par `ControlId`
## ou par canal.
##
## Il accepte aussi le LACHER d un objet de l inventaire : c est le geste du
## client d origine pour vendre ou estimer chez un marchand.

signal close_requested
signal item_dropped(inventory_slot: int)

var content: Control = null
var title_height := 18.0
var accepts_items := false
var _dragging := false
var _drag_offset := Vector2.ZERO


static func create(builder: DaocUiWindowBuilder, window: Dictionary) -> DaocXmlEngineFrame:
	if builder == null or window.is_empty():
		return null
	var built: Control = builder.build(window)
	if built == null:
		return null
	var frame := DaocXmlEngineFrame.new()
	frame.name = "Frame_%s" % built.name
	frame.content = built
	frame.size = built.size
	frame.custom_minimum_size = built.size
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(built)
	var title := str(window.get("TitleHeight", "18")).strip_edges()
	frame.title_height = float(int(title)) if title.is_valid_int() and int(title) > 0 else 18.0
	if str(window.get("CloseButton", "")).strip_edges().to_lower() == "true":
		var close := builder.make_named_button("window_close")
		if close != null:
			close.name = "CloseButton"
			close.position = Vector2(built.size.x - close.size.x - 5.0, 4.0)
			close.pressed.connect(func() -> void: frame.close_requested.emit())
			frame.add_child(close)
	return frame


## Premier controle portant ce ControlId ; `caption` departage les homonymes
## (training_window.xml reutilise 1900 pour quatre boutons).
func control(control_id: String, caption: String = "") -> Control:
	return _find(content, control_id, caption)


func controls_with_id(control_id: String) -> Array[Control]:
	var out: Array[Control] = []
	_collect(content, control_id, out)
	return out


## Pose le texte d un label par son canal, sans passer par le bus.
func set_text(channel: String, text: String) -> void:
	var node := _find_adapter(content, channel)
	if node is Label:
		(node as Label).text = text


## Relie un clic gauche, que le controle soit un bouton ou une zone nue.
static func on_click(node: Control, callback: Callable) -> void:
	if node == null:
		return
	if node is BaseButton:
		(node as BaseButton).pressed.connect(callback)
		return
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			callback.call())


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed and button.position.y <= title_height
		_drag_offset = button.position
		if _dragging:
			if get_parent() != null:
				get_parent().move_child(self, -1)
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		position += motion.position - _drag_offset
		accept_event()


## Les controles batis arretent la souris (MOUSE_FILTER_STOP) : un lacher sur
## la liste n atteindrait jamais le cadre. Pendant un glisser seulement, une
## surface transparente couvre la fenetre et recoit le depot.
var _drop_catcher: Control = null


func _notification(what: int) -> void:
	if not accepts_items:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		if _drop_catcher == null:
			_drop_catcher = Control.new()
			_drop_catcher.name = "DropCatcher"
			_drop_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
			_drop_catcher.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
			add_child(_drop_catcher)
		_drop_catcher.size = size
		move_child(_drop_catcher, -1)
		_drop_catcher.visible = _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data())
	elif what == NOTIFICATION_DRAG_END and _drop_catcher != null:
		_drop_catcher.visible = false


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not accepts_items or typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	return str(d.get("kind", "")) == "item" and int(d.get("inventory_slot", -1)) >= 0


func _drop_data(_at: Vector2, data: Variant) -> void:
	item_dropped.emit(int((data as Dictionary).get("inventory_slot", -1)))


func _find(node: Node, control_id: String, caption: String) -> Control:
	if node is Control and str(node.get_meta("daoc_control_id", "")) == control_id:
		if caption == "" or _caption_of(node) == caption:
			return node as Control
	for child in node.get_children():
		var found := _find(child, control_id, caption)
		if found != null:
			return found
	return null


func _collect(node: Node, control_id: String, out: Array[Control]) -> void:
	if node is Control and str(node.get_meta("daoc_control_id", "")) == control_id:
		out.append(node as Control)
	for child in node.get_children():
		_collect(child, control_id, out)


func _caption_of(node: Node) -> String:
	for child in node.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func _find_adapter(node: Node, channel: String) -> Control:
	if node is Control and str(node.get_meta("daoc_adapter", "")) == channel:
		return node as Control
	for child in node.get_children():
		var found := _find_adapter(child, channel)
		if found != null:
			return found
	return null
