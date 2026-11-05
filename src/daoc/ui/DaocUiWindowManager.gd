extends CanvasLayer
class_name DaocUiWindowManager

## P1-21E - monte les vraies fenetres du client dans la scene vivante.
##
## Le XML dit a quoi une fenetre RESSEMBLE et quelle taille elle a. Il ne dit
## PAS ou elle se trouve a l'ecran : dans l'original, la position vient de la
## configuration du joueur, pas du skin. La disposition ci-dessous est donc
## NOTRE choix, declare comme tel - PROVENANCE `DEFAULT_CHOSEN` - et non une
## donnee du client.
##
## L'echelle est autorisee : la contrainte 1:1 appartenait a l'ancien moteur.
## `ui_scale` agit sur la couche entiere, sans toucher aux tailles natives.

## Disposition par defaut : ancrage puis decalage en pixels. NOTRE choix.
const DEFAULT_LAYOUT := {
	"summary": {"anchor": "BOTTOM_RIGHT", "offset": Vector2i(-5, -5)},
	# Le menu se pose SOUS le resume : sans entree ici il retombait sur le
	# placement en escalier et se superposait a lui.
	"stats_index": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 0)},
	"stats_attributes": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 32)},
	"stats_spec_abil": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 32)},
	"stats_combat": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 32)},
	"stats_spells": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 32)},
	"stats_group": {"anchor": "TOP_RIGHT", "offset": Vector2i(0, 32)},
	"float_target": {"anchor": "TOP_CENTER", "offset": Vector2i(0, 16)},
	"minigroup": {"anchor": "TOP_LEFT", "offset": Vector2i(16, 128)},
	"miniinfo": {"anchor": "TOP_RIGHT", "offset": Vector2i(-16, 16)},
	"clock": {"anchor": "TOP_RIGHT", "offset": Vector2i(-16, 140)},
	"concentration": {"anchor": "TOP_LEFT", "offset": Vector2i(16, 252)},
	"command": {"anchor": "BOTTOM_RIGHT", "offset": Vector2i(-16, -16)},
	"minipet": {"anchor": "TOP_RIGHT", "offset": Vector2i(-16, 190)},
}

const PROVENANCE_LAYOUT: String = "DEFAULT_CHOSEN"

## Fenetres ouvertes a la toute premiere session : le menu et le resume. Tout
## le reste, c'est le joueur qui l'ouvre.
const DEFAULT_VISIBLE := ["stats_index", "summary", "float_target", "command"]

## Les six ronds du menu `stats_index` ne portent AUCUN evenement : le moteur
## d'origine codait en dur quelle case ouvre quelle fenetre. La correspondance
## vient donc du joueur, qui connait le jeu - PROVENANCE `USER_CONFIRMED`,
## renseignee le 2026-09-03, de gauche a droite.
##
## Le deuxieme rond ouvre la fiche de personnage, l'equipement et le sac. Cette
## fenetre N'EXISTE PAS en XML : le skin atlantis ne declare ni inventaire, ni
## poupee d'equipement - seulement `item_icons.xml`, ses planches d'icones. Elle
## est donc dessinée par le moteur et pilotée par le même groupe d'onglets.
const MENU_TABS := {
	"1000": "stats_attributes",
	"1002": "stats_spec_abil",
	"1003": "stats_combat",
	"1004": "stats_spells",
	"1005": "stats_group",
}

## Rond declare sans cible XML, avec son motif. Ce n'est pas un oubli.
const MENU_TABS_ENGINE_DRAWN := {
	"1001": "fiche personnage / equipement / sac - dessinee par le moteur",
}

const PROVENANCE_MENU: String = "USER_CONFIRMED"

## Emis quand un controle porteur d'une commande est active.
signal ui_event(event: String, data: String)
signal engine_window_requested(window_name: String, visible: bool)

var bus: DaocUiAdapterBus = null
var builder: DaocUiWindowBuilder = null
var contract: DaocUiSkinContract = null

## Nom de fenetre -> son `Control` racine.
var windows: Dictionary = {}

## Fenetres demandees mais introuvables dans le skin.
var missing_windows: PackedStringArray = PackedStringArray()

## Disposition du joueur, relue et reecrite dans son `.ini`.
var store: DaocUiLayoutStore = null

var _root: Control = null
var _dragging: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _forced_screen: Vector2 = Vector2.ZERO
var _menu_tabs_wired: int = 0
var _syncing_menu_tabs: bool = false


func _exit_tree() -> void:
	if bus != null:
		bus.clear()
	windows.clear()
	builder = null
	contract = null
	store = null
	bus = null


## `ui_root_path` pointe le dossier `ui/` du client. `wanted` liste les fenetres
## a ouvrir, par `Name` ou `WindowId`.
## `screen_size` impose la reference de disposition. Sans elle, le gestionnaire
## interroge son viewport, ce qui donne des resultats differents selon qu'il vit
## dans la fenetre du jeu ou dans un `SubViewport` de capture.
func setup(ui_root_path: String, skin: String, adapter_bus: DaocUiAdapterBus,
		wanted: PackedStringArray, scale: float = 1.0,
		screen_size: Vector2 = Vector2.ZERO,
		layout_store: DaocUiLayoutStore = null) -> Dictionary:
	_forced_screen = screen_size
	store = layout_store if layout_store != null else DaocUiLayoutStore.new()
	store.load_layout()
	bus = adapter_bus
	contract = DaocUiSkinContract.read(ui_root_path, skin)
	if not contract.errors.is_empty():
		return {"ok": false, "reason": contract.errors[0]}
	builder = DaocUiWindowBuilder.create(ui_root_path, contract, bus)

	_root = Control.new()
	_root.name = "DaocUiRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.scale = Vector2(scale, scale)
	add_child(_root)

	for name: String in wanted:
		var window: Dictionary = contract.find_window(name)
		if window.is_empty():
			missing_windows.append(name)
			continue
		_open(name, window)

	_wire_menu()
	_normalize_menu_state()

	return {
		"ok": true,
		"available": windows.size(),
		"visible": visible_count(),
		"missing": missing_windows.size(),
		"menu_tabs_wired": _menu_tabs_wired,
		"menu_tabs_engine_drawn": MENU_TABS_ENGINE_DRAWN.size(),
		"provenance_layout": PROVENANCE_LAYOUT,
		"provenance_menu": PROVENANCE_MENU,
		"scale": scale,
		"viewport": "%dx%d" % [int(_viewport_size().x), int(_viewport_size().y)],
		"layout": store.get_debug_snapshot(),
		"builder": builder.get_debug_snapshot(),
	}


func visible_count() -> int:
	var total: int = 0
	for name: String in windows:
		if (windows[name] as Control).visible:
			total += 1
	return total


## Ouvre ou ferme une fenetre, comme une case du menu. Enregistre aussitot :
## l'original garde la disposition d'une session a l'autre.
func toggle(name: String) -> bool:
	var frame: Control = windows.get(name, null) as Control
	if frame == null:
		return false
	frame.visible = not frame.visible
	if frame.visible:
		raise(name)
	_remember(name)
	store.save_layout()
	return frame.visible


## Ecrit la disposition entiere. Appelee a la fermeture de la session.
func save_layout() -> int:
	for name: String in windows:
		_remember(name)
	return store.save_layout()


## Nomme `get_daoc_window` et non `get_window` : `Node` possede deja ce nom et
## le redefinir masquerait la methode native.
func get_daoc_window(name: String) -> Control:
	return windows.get(name, null) as Control


func set_window_visible(name: String, visible: bool) -> bool:
	var frame: Control = windows.get(name, null) as Control
	if frame == null:
		return false
	frame.visible = visible
	return true


## Remonte une fenetre au premier plan. L'ordre est celui de l'arbre : deplacer
## le noeud en dernier suffit, sans gerer d'index de profondeur separe.
func raise(name: String) -> void:
	var frame: Control = windows.get(name, null) as Control
	if frame != null and frame.get_parent() != null:
		frame.get_parent().move_child(frame, -1)


func get_debug_snapshot() -> Dictionary:
	var visible_names: PackedStringArray = PackedStringArray()
	for window_name: String in windows:
		var frame := windows[window_name] as Control
		if frame != null and frame.visible:
			visible_names.append(window_name)
	visible_names.sort()
	return {
		"available": windows.size(),
		"visible": visible_count(),
		"visible_names": visible_names,
		"missing_windows": missing_windows.size(),
		"menu_tabs_wired": _menu_tabs_wired,
		"provenance_layout": PROVENANCE_LAYOUT,
		"provenance_menu": PROVENANCE_MENU,
		"layout": store.get_debug_snapshot() if store != null else {},
		"bus": bus.get_debug_snapshot() if bus != null else {},
	}


# ---------------------------------------------------------------------------

func _open(name: String, window: Dictionary) -> void:
	var content: Control = builder.build(window)
	if content == null:
		return

	# Un cadre porte le deplacement et le premier plan ; le contenu bati reste
	# intact a l'interieur, a sa taille native.
	var frame: Control = Control.new()
	frame.name = "Frame_%s" % name
	frame.size = content.size
	frame.custom_minimum_size = content.size
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(content)
	_root.add_child(frame)

	frame.position = Vector2(_placement(name, content.size))
	frame.set_meta("daoc_window", name)

	# La barre de titre declaree par le XML sert de poignee. Sans hauteur de
	# titre, toute la fenetre devient la poignee.
	var title_height: int = _int_of(window, "TitleHeight")
	var handle_height: float = float(title_height) if title_height > 0 else content.size.y
	var handle: Control = Control.new()
	handle.name = "TitleHandle"
	handle.size = Vector2(content.size.x, handle_height)
	# Le menu n'a pas de barre de titre : une poignée haute de 32 px recouvrait
	# exactement ses six cases et absorbait tous les clics.
	# P1-86 — sans TitleHeight (stats_spec_abil, stats_spells... : dockees sous le
	# menu), la poignee couvrait TOUTE la fenetre en STOP et absorbait chaque
	# clic : rien n'etait cliquable ni glissable dedans. La poignee s'efface
	# alors et c'est le cadre (PASS, derriere les controles) qui porte le
	# deplacement : les boutons gardent leurs clics, le vide deplace.
	if title_height <= 0 or name == "stats_index":
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.gui_input.connect(_on_handle_input.bind(frame))
	else:
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.gui_input.connect(_on_handle_input.bind(frame))
	# 2026-09-30 : clic droit -> opacite de la fenetre (fonds seulement).
	DaocWindowDrag.add_opacity_menu(frame, name, [handle, content])
	frame.add_child(handle)

	# La disposition enregistree l'emporte sur la table par defaut ; sinon seules
	# les fenetres de `DEFAULT_VISIBLE` sont ouvertes a la premiere session.
	var default_visible: bool = DEFAULT_VISIBLE.has(name)
	frame.position = store.get_position(
		name, content.size, _viewport_size(), frame.position)
	frame.visible = store.get_visible(name, default_visible)

	windows[name] = frame
	_connect_events(content)


## Place une fenetre selon la disposition par defaut. Une fenetre absente de la
## table part en haut a gauche, en escalier, pour rester visible et distincte.
func _placement(name: String, size: Vector2) -> Vector2i:
	var viewport: Vector2 = _viewport_size()
	var entry: Dictionary = DEFAULT_LAYOUT.get(name, {}) as Dictionary
	if entry.is_empty():
		var index: int = windows.size()
		return Vector2i(24 + index * 24, 24 + index * 24)

	var offset: Vector2i = entry.get("offset", Vector2i.ZERO)
	var anchor: String = str(entry.get("anchor", "TOP_LEFT"))
	var position: Vector2 = Vector2.ZERO
	match anchor:
		"TOP_LEFT":
			position = Vector2(offset)
		"TOP_CENTER":
			position = Vector2(viewport.x * 0.5 - size.x * 0.5 + float(offset.x), float(offset.y))
		"TOP_RIGHT":
			position = Vector2(viewport.x - size.x + float(offset.x), float(offset.y))
		"BOTTOM_LEFT":
			position = Vector2(float(offset.x), viewport.y - size.y + float(offset.y))
		"BOTTOM_RIGHT":
			position = Vector2(viewport.x - size.x + float(offset.x), viewport.y - size.y + float(offset.y))
		"CENTER":
			position = viewport * 0.5 - size * 0.5 + Vector2(offset)
	return Vector2i(position)


## En mode sans affichage, la fenetre peut mesurer zero : la disposition serait
## alors calculee sur un ecran inexistant. La taille declaree du projet sert
## alors de reference, pour que la suite et le jeu placent les fenetres pareil.
func _viewport_size() -> Vector2:
	if _forced_screen.x > 1.0 and _forced_screen.y > 1.0:
		return _forced_screen
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var size: Vector2 = viewport.get_visible_rect().size
		if size.x > 1.0 and size.y > 1.0:
			return size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))


## Les commandes du XML sont portees par metadonnee a la construction. Le
## gestionnaire les relaie sans les interpreter : c'est au jeu de decider.
func _connect_events(node: Node) -> void:
	if node.has_meta("daoc_event"):
		var event: String = str(node.get_meta("daoc_event"))
		var data: String = str(node.get_meta("daoc_event_data", ""))
		if node is BaseButton:
			(node as BaseButton).pressed.connect(func() -> void: ui_event.emit(event, data))
		elif node is Control:
			(node as Control).gui_input.connect(func(input: InputEvent) -> void:
				if input is InputEventMouseButton and (input as InputEventMouseButton).pressed:
					ui_event.emit(event, data))
	for child: Node in node.get_children():
		_connect_events(child)


func _on_handle_input(input: InputEvent, frame: Control) -> void:
	if input is InputEventMouseButton:
		var button: InputEventMouseButton = input as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_dragging = frame
			_drag_offset = frame.get_global_mouse_position() - frame.global_position
			raise(str(frame.get_meta("daoc_window", "")))
		else:
			# Enregistrement a la FIN du deplacement, pas a chaque pixel : le
			# fichier du joueur n'a pas a etre reecrit soixante fois par seconde.
			if _dragging == frame:
				_remember(str(frame.get_meta("daoc_window", "")))
				store.save_layout()
			_dragging = null
	elif input is InputEventMouseMotion and _dragging == frame:
		frame.position = frame.get_global_mouse_position() - _drag_offset


func _remember(name: String) -> void:
	var frame: Control = windows.get(name, null) as Control
	if frame == null or store == null:
		return
	store.set_window(name, frame.position, frame.visible)


## Relie les six cases du menu aux fenetres qu'elles ouvrent. Elles ne portent
## aucun evenement : seul leur `ControlId` les distingue, d'ou la table DEDUITE
## `MENU_TABS`. Une case dont la fenetre n'est pas disponible reste inerte
## plutot que de pointer dans le vide.
func _wire_menu() -> void:
	var menu: Control = windows.get("stats_index", null) as Control
	if menu == null:
		return
	var boxes: Array = []
	_collect_control_ids(menu, boxes)
	for box: Control in boxes:
		var control_id: String = str(box.get_meta("daoc_control_id", ""))
		if MENU_TABS_ENGINE_DRAWN.has(control_id):
			box.set_meta("daoc_menu_target", "inventory")
			box.tooltip_text = "Inventaire et équipement"
			if box is BaseButton:
				(box as BaseButton).toggled.connect(
					_on_engine_menu_toggled.bind(box))
			_menu_tabs_wired += 1
			continue
		if not MENU_TABS.has(control_id):
			continue
		var target: String = MENU_TABS[control_id]
		if not windows.has(target):
			continue
		box.set_meta("daoc_menu_target", target)
		box.tooltip_text = target
		if box is BaseButton:
			(box as BaseButton).button_pressed = (windows[target] as Control).visible
			(box as BaseButton).toggled.connect(_on_xml_menu_toggled.bind(target, box))
		_menu_tabs_wired += 1


func _on_xml_menu_toggled(pressed: bool, target: String, source: BaseButton) -> void:
	if _syncing_menu_tabs:
		return
	_close_other_menu_windows(target, source)
	var frame := windows.get(target, null) as Control
	if frame == null:
		return
	frame.visible = pressed
	if pressed:
		_align_below_menu(frame)
		raise(target)
	_remember(target)
	store.save_layout()


func _on_engine_menu_toggled(pressed: bool, source: BaseButton) -> void:
	if _syncing_menu_tabs:
		return
	_close_other_menu_windows("inventory", source)
	engine_window_requested.emit("inventory", pressed)


func _close_other_menu_windows(keep: String, source: BaseButton) -> void:
	_syncing_menu_tabs = true
	for target: String in MENU_TABS.values():
		var frame := windows.get(target, null) as Control
		if frame != null and target != keep:
			frame.visible = false
			_remember(target)
	var menu := windows.get("stats_index", null) as Control
	if menu != null:
		var boxes: Array = []
		_collect_control_ids(menu, boxes)
		for box: Control in boxes:
			if box is BaseButton and box != source:
				var id := str(box.get_meta("daoc_control_id", ""))
				if MENU_TABS.has(id) or MENU_TABS_ENGINE_DRAWN.has(id):
					(box as BaseButton).button_pressed = false
	_syncing_menu_tabs = false
	if keep != "inventory":
		engine_window_requested.emit("inventory", false)


func _align_below_menu(frame: Control) -> void:
	var menu := windows.get("stats_index", null) as Control
	if menu == null:
		return
	frame.position = Vector2(menu.position.x + menu.size.x - frame.size.x,
		menu.position.y + menu.size.y)


func _normalize_menu_state() -> void:
	# Les anciennes versions mémorisaient plusieurs onglets visibles. À la
	# lecture, on conserve le premier et on ferme les autres immédiatement.
	var kept := ""
	for target: String in MENU_TABS.values():
		var frame := windows.get(target, null) as Control
		if frame == null or not frame.visible:
			continue
		if kept == "":
			kept = target
			_align_below_menu(frame)
		else:
			frame.visible = false
			_remember(target)


func _collect_control_ids(node: Node, out: Array) -> void:
	if node is Control and node.has_meta("daoc_control_id"):
		out.append(node)
	for child: Node in node.get_children():
		_collect_control_ids(child, out)


func _int_of(node: Dictionary, key: String) -> int:
	var text: String = str(node.get(key, "")).strip_edges()
	return int(text) if text.is_valid_int() else 0
