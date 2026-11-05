extends CanvasLayer
class_name DaocQuickbars

const SLOT := 34
const COUNT := 10
const QuickbarStateScript = preload("res://src/daoc/gameplay/spells/DaocPlayerQuickbarState.gd")
const SlotScript = preload("res://src/daoc/ui/DaocQuickbarSlot.gd")
const SpellBookScript = preload("res://src/daoc/ui/DaocSpellBookPanel.gd")
var bars: Array[Control] = []
var available_spells: Array = []
var state: RefCounted = null
var server: DaocLocalServer = null
var combat_client: DaocCombatClient = null
var save_path := "user://daoc_quickbar.json"
var _slots: Dictionary = {}
var _spellbook: PanelContainer = null
var _stylebook: Control = null
var icon_atlas: RefCounted = null

func setup(p_server: DaocLocalServer, p_client: DaocCombatClient, character_key: String = "default", p_save_path: String = "") -> void:
	server = p_server
	combat_client = p_client
	save_path = p_save_path if p_save_path != "" else "user://daoc_quickbar_%s.json" % character_key.validate_filename()
	state = QuickbarStateScript.new().setup(character_key)
	state.load(save_path)
	if server != null:
		available_spells = server.known_spells(server.player_object_id).get("usable", []) as Array
		available_spells.append_array(server.known_master_level_abilities(server.player_object_id))
		available_spells.append_array(server.known_champion_level_abilities(server.player_object_id))

func _ready() -> void:
	layer = 18
	_layout = _load_layout()
	if state == null:
		state = QuickbarStateScript.new().setup("default")
	for index in 3:
		var bar := _make_bar(index)
		bar.position = Vector2(2, 2) if index == 0 else Vector2(2 + (index - 1) * 38, 205)
		var saved: Variant = _layout.get(str(index), null)
		if saved is Array and (saved as Array).size() == 2:
			bar.position = Vector2(float((saved as Array)[0]), float((saved as Array)[1]))
		bar.visible = index < 2
		add_child(bar)
		bars.append(bar)
	_spellbook = SpellBookScript.new()
	_spellbook.name = "DaocSpellBookPanel"
	add_child(_spellbook)
	_spellbook.set_spells(available_spells)
	# P1-129 : les coups physiques (styles) vivent dans la fenetre « Combat »
	# (stats_combat), pas dans le grimoire — retour utilisateur du 28/09.
	_stylebook = SpellBookScript.new()
	_stylebook.name = "DaocStyleBookPanel"
	_stylebook.visible = false
	add_child(_stylebook)
	_refresh_all()


## 2026-09-15 : le grimoire n'est plus une fenetre flottante, il vit DANS la
## fenetre « Sorts » (stats_spells) de l'interface du client. Il suit donc son
## ouverture, sa fermeture et sa position ; sans cette fenetre il reste flottant.
func attach_spellbook_to(frame: Control) -> Dictionary:
	if _spellbook == null or frame == null:
		return {"ok": false, "reason": "grimoire ou fenetre absent"}
	var parent := _spellbook.get_parent()
	if parent != null:
		parent.remove_child(_spellbook)
	frame.add_child(_spellbook)
	_spellbook.call("fit_into_window", frame)
	return {"ok": true, "window": frame.name, "size": frame.size}


func attach_stylebook_to(frame: Control) -> Dictionary:
	if _stylebook == null or frame == null:
		return {"ok": false, "reason": "panneau des styles ou fenetre absent"}
	var parent := _stylebook.get_parent()
	if parent != null:
		parent.remove_child(_stylebook)
	frame.add_child(_stylebook)
	_stylebook.visible = true
	_stylebook.call("fit_into_window", frame)
	return {"ok": true, "window": frame.name, "size": frame.size}


static func is_style_entry(entry: Dictionary) -> bool:
	return str(entry.get("skill_kind", "")) == "style"


func spellbook_parent_name() -> String:
	return str(_spellbook.get_parent().name) if _spellbook != null and _spellbook.get_parent() != null else ""

func _make_bar(index: int) -> Control:
	var root := Control.new()
	root.name = "Quickbar%d" % (index + 1)
	var vertical := index > 0
	root.size = Vector2(SLOT, 24 + COUNT * SLOT) if vertical else Vector2(24 + COUNT * SLOT, SLOT)
	var page := Label.new()
	page.text = "‹1›"
	page.position = Vector2(0, 0 if vertical else 8)
	page.size = Vector2(SLOT, 24) if vertical else Vector2(24, 18)
	page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_theme_font_size_override("font_size", 9)
	root.add_child(page)
	# P1-104 : la poignee « <1> » DEPLACE la barre (clic gauche maintenu), comme
	# la barre de titre d une fenetre du client d origine ; la position survit
	# dans user:// (retour utilisateur du 2026-09-21 : les barres se superposent).
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.tooltip_text = "Glisser pour deplacer la quickbar %d" % (index + 1)
	page.gui_input.connect(_on_grip_input.bind(root))
	for slot_index in COUNT:
		var slot: Panel = SlotScript.new()
		slot.name = "DaocQuickbarSlot%d" % (slot_index + 1)
		slot.position = Vector2(0, 24 + slot_index * SLOT) if vertical else Vector2(24 + slot_index * SLOT, 0)
		slot.size = Vector2(SLOT - 1, SLOT - 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.027, 0.034, 0.82)
		style.border_color = Color(0.48, 0.39, 0.22, 0.95)
		style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)
		slot.icon_atlas = icon_atlas
		root.add_child(slot)
		slot.setup(index, slot_index)
		slot.spell_dropped.connect(_on_spell_dropped)
		slot.clear_requested.connect(_on_clear_requested)
		slot.activation_requested.connect(_on_activation_requested)
		slot.carry_drop_handler = Callable(self, "drop_carried_into")
		_slots["%d:%d" % [index, slot_index]] = slot
		var number := Label.new()
		number.text = str((slot_index + 1) % 10)
		number.position = Vector2(2, 0)
		number.add_theme_font_size_override("font_size", 8)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)
	return root

## Les icones du client pour les cases et le grimoire.
func set_icon_atlas(atlas: RefCounted) -> void:
	icon_atlas = atlas
	for key in _slots.keys():
		(_slots[key] as Panel).icon_atlas = atlas
	if _spellbook != null:
		_spellbook.set_icon_atlas(atlas)
	if _stylebook != null:
		_stylebook.set_icon_atlas(atlas)
	_refresh_all()


func slots_with_icons() -> int:
	var count := 0
	for key in _slots.keys():
		if (_slots[key] as Panel).has_icon():
			count += 1
	return count


## P1-84 — les CAPACITES du serveur (Sprint, Quickcast...) restent assignables
## aux barres, mais ne s'affichent pas dans le grimoire : dans le client
## d'origine on les glisse depuis la fenetre Specializations / Abilities.
func set_available_spells(spells: Array) -> void:
	available_spells = spells.duplicate(true)
	if _spellbook != null:
		_spellbook.set_spells(available_spells.filter(func(entry): return not str((entry as Dictionary).get("skill_kind", "")).contains("ability") and not is_style_entry(entry as Dictionary)))
	if _stylebook != null:
		_stylebook.set_spells(available_spells.filter(func(entry): return is_style_entry(entry as Dictionary)))

func _on_spell_dropped(bar_index: int, slot_index: int, spell: Dictionary) -> void:
	state.assign_entry(bar_index, slot_index, spell, available_spells)
	state.save(save_path)
	_refresh_slot(bar_index, slot_index)

func _on_clear_requested(bar_index: int, slot_index: int) -> void:
	state.clear_slot(bar_index, slot_index)
	state.save(save_path)
	_refresh_slot(bar_index, slot_index)

## En ligne, le lancement part au serveur (0x7D) par ce rappel : (entree, cible).
var online_caster: Callable = Callable()
## P1-98 : (logement d inventaire, type d usage) -> 0x71, ou un rappel hors ligne.
var online_item_user: Callable = Callable()
## P1-105 : (commande) -> void, la macro d une case part par le chat.
var macro_runner: Callable = Callable()
var last_activation: Dictionary = {}


func _on_activation_requested(bar_index: int, slot_index: int) -> void:
	# P1-98 : un objet ne demande pas l arbitre (0x71 part au serveur) ; un sort si.
	var target_id := combat_client.current_target_id if combat_client != null else (server.player_object_id if server != null else -1)
	var intent: Dictionary = state.build_use_intent(bar_index, slot_index, target_id)
	# P1-105 : une macro envoie sa commande par le chemin du chat.
	if bool(intent.get("ok", false)) and str(intent.get("kind", "")) == "run_macro":
		if macro_runner.is_valid():
			macro_runner.call(str(intent.get("command", "")))
			last_activation = {"ok": true, "macro": str(intent.get("name", ""))}
		else:
			last_activation = {"ok": false, "reason": "aucun chemin de commande"}
		return
	# P1-98 : un objet part par 0x71 UseSlot (en ligne) ou par le rappel local.
	if bool(intent.get("ok", false)) and str(intent.get("kind", "")) == "use_item":
		if online_item_user.is_valid():
			last_activation = online_item_user.call(int(intent.get("inventory_slot", -1)), int(intent.get("use_type", 0))) as Dictionary
		else:
			last_activation = {"ok": false, "reason": "usage d objet indisponible hors ligne"}
		if console_target != null and console_target.has_method("push_console_line"):
			console_target.call("push_console_line", "Objet %s : %s" % [str(intent.get("name", "")), "envoye" if bool(last_activation.get("ok", false)) else str(last_activation.get("reason", last_activation.get("error", "refuse")))])
		return
	if server == null:
		return
	if bool(intent.get("ok", false)) and online_caster.is_valid() and str(intent.get("kind", "")) == "use_spell":
		for value in available_spells:
			var entry := value as Dictionary
			if int(entry.get("spell_id", 0)) == int(intent.get("spell_id", -1)) and str(entry.get("line", "")) == str(intent.get("line", "")):
				last_activation = online_caster.call(entry, target_id) as Dictionary
				return
		last_activation = {"ok": false, "reason": "sort absent du livre serveur"}
		return
	if bool(intent.get("ok", false)):
		if str(intent.get("kind", "")) == "use_master_level_ability":
			server.request_master_level_ability(server.player_object_id, int(intent.get("target_id", -1)), str(intent.get("ability_id", "")))
		elif str(intent.get("kind", "")) == "use_champion_ability":
			server.request_champion_level_ability(server.player_object_id, int(intent.get("target_id", -1)), str(intent.get("ability_id", "")))
		else:
			last_activation = server.request_spell(server.player_object_id, int(intent.get("target_id", -1)), int(intent.get("spell_id", 0)), str(intent.get("line", "")))
		# Un refus de l'arbitre se lit dans la console, jamais en silence.
		if not bool(last_activation.get("ok", false)) and console_target != null and console_target.has_method("push_console_line"):
			console_target.call("push_console_line", "Sort refuse : %s" % str(last_activation.get("reason", last_activation.get("error", "?"))))


var console_target: Node = null

func _refresh_all() -> void:
	for key in _slots.keys():
		var parts := str(key).split(":")
		_refresh_slot(int(parts[0]), int(parts[1]))

func _refresh_slot(bar_index: int, slot_index: int) -> void:
	var slot: Panel = _slots.get("%d:%d" % [bar_index, slot_index]) as Panel
	if slot != null:
		var reference: Dictionary = state.slot(bar_index, slot_index)
		# L'etat sauvegarde ne porte que la reference ; l'icone vient du grimoire.
		# P1-128 : meme avec une icone, la famille vient du grimoire (une barre
		# sauvegardee avant P1-128 portait "skill" pour les styles).
		if not reference.is_empty():
			for value in available_spells:
				var spell := value as Dictionary
				if int(spell.get("spell_id", -1)) == int(reference.get("spell_id", -2)) and str(spell.get("line", "")) == str(reference.get("line", str(spell.get("line", "")))) and int(spell.get("icon", 0)) > 0:
					reference = reference.duplicate(true)
					reference["icon"] = int(spell.get("icon", 0))
					reference["icon_family"] = str(spell.get("icon_family", "spell"))
					break
		slot.refresh(reference)

## P1-108 — le grise de delai (0xD6 DisableSkills). `disabled_until` : cle
## (`disable_key` d une entree du livre serveur : « spell:<ligne>:<index> »
## ou « skill:<index> ») -> echeance en msec de Time.get_ticks_msec(). Les
## cases concernees s assombrissent avec le compte a rebours, rafraichi
## quatre fois par seconde ; une echeance passee rend la case normale.
var disabled_until: Dictionary = {}
var _disabled_clock := 0.0


func set_disabled_skills(until: Dictionary) -> void:
	disabled_until = until.duplicate(true)
	_refresh_disabled()


func disable_key_for_reference(reference: Dictionary) -> String:
	if reference.is_empty() or str(reference.get("kind", "")) != "spell":
		return ""
	for value in available_spells:
		var entry := value as Dictionary
		if int(entry.get("spell_id", -1)) == int(reference.get("spell_id", -2)) and str(entry.get("line", "")) == str(reference.get("line", "")):
			return str(entry.get("disable_key", ""))
	return ""


func disabled_remaining(reference: Dictionary) -> float:
	var key := disable_key_for_reference(reference)
	if key == "" or not disabled_until.has(key):
		return 0.0
	return maxf(0.0, float(int(disabled_until[key]) - Time.get_ticks_msec()) / 1000.0)


func _refresh_disabled() -> void:
	for key in _slots.keys():
		var slot: Panel = _slots[key] as Panel
		if slot != null and slot.has_method("set_disabled"):
			var remaining := disabled_remaining(slot.get("reference") as Dictionary)
			if remaining > 0.0 or bool(slot.call("is_disabled")):
				slot.call("set_disabled", remaining)


func _process(delta: float) -> void:
	_follow_mouse()
	if disabled_until.is_empty():
		return
	_disabled_clock += delta
	if _disabled_clock < 0.25:
		return
	_disabled_clock = 0.0
	_refresh_disabled()


func disabled_slots() -> int:
	var count := 0
	for key in _slots.keys():
		var slot: Panel = _slots[key] as Panel
		if slot != null and slot.has_method("is_disabled") and bool(slot.call("is_disabled")):
			count += 1
	return count


func get_debug_snapshot() -> Dictionary:
	return {"bars": bars.size(), "visible": 2, "slots_per_bar": COUNT, "disabled_slots": disabled_slots(),
		"empty_by_default": state == null or state.slots.is_empty(),
		"assigned": 0 if state == null else state.slots.size(),
		"available_spells": available_spells.size(), "manual_placement": true}


## P1-101 — les touches du client d'origine : 1..0 = cases 1..10 de la
## quickbar 1, Ctrl+1..0 = quickbar 2, Alt+1..0 = quickbar 3 (contexte
## utilisateur du 2026-09-21 ; l'ordre des modificateurs est un choix, la
## mecanique est la meme). Une case VIDE ne consomme pas la touche : les
## anciens raccourcis (1 = attaque, 2-4 = styles) restent alors joignables.
const KEY_SLOTS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
var key_activations := 0


func bar_for_modifiers(ctrl: bool, alt: bool) -> int:
	if alt:
		return 2
	if ctrl:
		return 1
	return 0


## Vrai si la touche a active une case (donc a ete consommee).
func try_activate_key(keycode: int, ctrl: bool, alt: bool) -> bool:
	var slot_index := KEY_SLOTS.find(keycode)
	if slot_index < 0 or state == null:
		return false
	var bar_index := bar_for_modifiers(ctrl, alt)
	if state.slot(bar_index, slot_index).is_empty():
		return false
	key_activations += 1
	_on_activation_requested(bar_index, slot_index)
	return true


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	# Le chat a le clavier : une touche tapee dans la ligne de commande n est pas un raccourci.
	if get_viewport() != null and get_viewport().gui_get_focus_owner() is LineEdit:
		return
	# Sans modificateur, c est DaocCombatClient qui appelle try_activate_key en
	# premier (priorite sur 1 = attaque, 2-4 = styles) ; ici Ctrl et Alt.
	if not (key_event.ctrl_pressed or key_event.alt_pressed):
		return
	if try_activate_key(key_event.keycode, key_event.ctrl_pressed, key_event.alt_pressed):
		get_viewport().set_input_as_handled()


## P1-104 — deplacement des barres par leur poignee, position sauvegardee.
var _layout: Dictionary = {}
var _dragging: Control = null
var _drag_offset := Vector2.ZERO
var moves_saved := 0


func layout_path() -> String:
	return save_path.get_basename() + "_layout.json"


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(layout_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path()))
	return parsed if parsed is Dictionary else {}


func _save_layout() -> void:
	var out: Dictionary = {}
	for index in bars.size():
		out[str(index)] = [bars[index].position.x, bars[index].position.y]
	var file := FileAccess.open(layout_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(out))
		file.close()
		moves_saved += 1
	_layout = out


func _on_grip_input(event: InputEvent, bar: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_dragging = bar
			_drag_offset = bar.get_global_mouse_position() - bar.position
		elif _dragging == bar:
			_dragging = null
			_save_layout()
	elif event is InputEventMouseMotion and _dragging == bar and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		# 2026-09-29 : le relachement a pu tomber hors de la poignee (autre
		# controle sous la souris) ; sans bouton enfonce, la barre est posee.
		_dragging = null
		_save_layout()
	elif event is InputEventMouseMotion and _dragging == bar:
		var viewport_size := bar.get_viewport().get_visible_rect().size
		var target := bar.get_global_mouse_position() - _drag_offset
		bar.position = Vector2(clampf(target.x, 0.0, maxf(0.0, viewport_size.x - bar.size.x)), clampf(target.y, 0.0, maxf(0.0, viewport_size.y - bar.size.y)))


func move_bar(index: int, position: Vector2) -> void:
	if index < 0 or index >= bars.size():
		return
	bars[index].position = position
	_save_layout()


func bar_position(index: int) -> Vector2:
	return bars[index].position if index >= 0 and index < bars.size() else Vector2.ZERO




## P1-113 — L ICONE PORTEE PAR LA SOURIS. Le client d origine attache une
## icone au curseur (nouvelle macro, ou icone reprise) et la depose au clic
## dans la case voulue ; deposer sur une case prise ECHANGE : l ancienne
## icone reste au curseur pour etre replacee ; Echap ou clic droit hors des
## cases la lache. `/macro` ne remplit donc plus « la premiere case libre » :
## il met la macro au curseur (retour utilisateur du 2026-09-22).
var carried: Dictionary = {}
var _carried_icon: Control = null
var carry_events: Array = []


func carry(reference: Dictionary) -> Dictionary:
	if reference.is_empty():
		return {"ok": false, "reason": "rien a porter"}
	carried = reference.duplicate(true)
	_ensure_carried_icon()
	_carried_icon.visible = true
	_refresh_carried_icon()
	carry_events.append({"kind": "carry", "reference": carried.duplicate(true)})
	return {"ok": true, "carried": carried.duplicate(true)}


func is_carrying() -> bool:
	return not carried.is_empty()


func drop_carried() -> Dictionary:
	if carried.is_empty():
		return {"ok": false}
	var dropped := carried.duplicate(true)
	carried = {}
	if _carried_icon != null:
		_carried_icon.visible = false
	carry_events.append({"kind": "discard", "reference": dropped})
	return {"ok": true, "dropped": dropped}


## Le clic gauche sur une case pendant qu on porte : depose, et reprend ce
## qui s y trouvait. Rend true si le clic est consomme.
func drop_carried_into(bar_index: int, slot_index: int) -> bool:
	if carried.is_empty() or state == null:
		return false
	var previous: Dictionary = state.slot(bar_index, slot_index)
	var assigned: Dictionary = state.assign_entry(bar_index, slot_index, carried, available_spells)
	if not bool(assigned.get("ok", false)):
		carry_events.append({"kind": "refused", "reason": str(assigned.get("reason", "")), "bar": bar_index, "slot": slot_index})
		return true
	state.save(save_path)
	_refresh_slot(bar_index, slot_index)
	carry_events.append({"kind": "drop", "bar": bar_index, "slot": slot_index, "reference": carried.duplicate(true),
		"swapped_out": previous.duplicate(true)})
	if previous.is_empty():
		carried = {}
		if _carried_icon != null:
			_carried_icon.visible = false
	else:
		carried = previous.duplicate(true)
		_refresh_carried_icon()
	return true


func _ensure_carried_icon() -> void:
	if _carried_icon != null:
		return
	var panel := Panel.new()
	panel.name = "CarriedIcon"
	panel.size = Vector2(SLOT - 1, SLOT - 1)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 100
	panel.visible = false
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(1, 1)
	icon.size = panel.size - Vector2(2, 2)
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var text := Label.new()
	text.name = "Text"
	text.add_theme_font_size_override("font_size", 9)
	text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(text)
	add_child(panel)
	_carried_icon = panel


func _refresh_carried_icon() -> void:
	if _carried_icon == null:
		return
	var icon := _carried_icon.get_node("Icon") as TextureRect
	var text := _carried_icon.get_node("Text") as Label
	var kind := str(carried.get("kind", ""))
	var texture: Texture2D = null
	if kind == "item" and icon_atlas != null and icon_atlas.has_method("texture_for_item_model"):
		texture = icon_atlas.call("texture_for_item_model", int(carried.get("model", 0))) as Texture2D
	elif kind != "macro" and icon_atlas != null and icon_atlas.has_method("texture_for"):
		texture = icon_atlas.call("texture_for", int(carried.get("icon", 0)), str(carried.get("icon_family", "spell"))) as Texture2D
	icon.texture = texture
	icon.visible = texture != null
	if kind == "macro":
		SlotScript.style_macro_panel(_carried_icon)
		text.text = SlotScript.macro_icon_text(str(carried.get("name", "")))
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.027, 0.034, 0.82)
		style.border_color = Color(0.48, 0.39, 0.22, 0.95)
		style.set_border_width_all(1)
		_carried_icon.add_theme_stylebox_override("panel", style)
		text.text = "" if texture != null else str(carried.get("name", "?")).substr(0, 4)
	text.visible = text.text != ""
	_carried_icon.position = get_viewport().get_mouse_position() - _carried_icon.size * 0.5 if is_inside_tree() else Vector2.ZERO


func _follow_mouse() -> void:
	if _carried_icon != null and _carried_icon.visible and is_inside_tree():
		_carried_icon.position = get_viewport().get_mouse_position() - _carried_icon.size * 0.5


## Echap ou clic droit hors des cases lache l icone portee.
func _unhandled_input(event: InputEvent) -> void:
	if carried.is_empty():
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		drop_carried()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		drop_carried()
		get_viewport().set_input_as_handled()


## P1-105 — /macro <nom> <commande>. Depuis P1-113 la macro va AU CURSEUR ;
## `bar_index` >= 0 force l ancien comportement (premiere case libre), pour
## les suites et les scripts.
func define_macro(name: String, command: String, bar_index: int = -1) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "quickbar absente"}
	var reference := {"kind": "macro", "name": name, "command": command}
	if bar_index < 0:
		var carried_result := carry(reference)
		if bool(carried_result.get("ok", false)):
			carried_result["key"] = "curseur"
		return carried_result
	var slot_index: int = state.first_empty_slot(bar_index)
	if slot_index < 0:
		return {"ok": false, "reason": "barre %d pleine" % (bar_index + 1)}
	var assigned: Dictionary = state.assign_entry(bar_index, slot_index, reference, [])
	if bool(assigned.get("ok", false)):
		state.save(save_path)
		_refresh_slot(bar_index, slot_index)
		assigned["key"] = "%s%d" % ["" if bar_index == 0 else ("Ctrl+" if bar_index == 1 else "Alt+"), (slot_index + 1) % 10]
	return assigned
