extends CanvasLayer
class_name DaocDolCharacterSelectHud1127

## P1-N5H: pré-écran texte/HUD de sélection personnage.
## P1-N6C: flux DAoC offline respecté : chargement pregame -> sélection royaume -> sélection personnage -> chargement monde.
## P1-N6D: branchement resolver offline des sources assets pregame/loading, sans import runtime.
## Ce n'est pas l'UI finale DAoC : c'est un panneau debug local, alimenté par P1-N5E/F/G.

const UI_PHASE_LOADING: String = "LOADING"
const UI_PHASE_REALM_SELECT: String = "REALM_SELECT"
const UI_PHASE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const UI_PHASE_WORLD_LOADING: String = "WORLD_LOADING"
const UI_PHASE_READY_TO_ENTER: String = "READY_TO_ENTER"

@export var visible_by_default: bool = false
@export var update_interval_sec: float = 0.20
@export var max_character_rows: int = 10
@export var auto_refresh_enabled: bool = true
@export var start_phase: String = UI_PHASE_LOADING

var character_bootstrap_1127: Node = null
var dol_client: Node = null
var player: Node = null
var asset_resolver: RefCounted = null
var _label: Label = null
var _accum: float = 0.0
var _selected_index: int = 0
var _last_text: String = ""
var _last_model: Dictionary = {}
var _ui_phase: String = UI_PHASE_LOADING
var _selected_realm_id: int = 0
var _loading_progress: float = 0.0
var _loading_reason: String = "offline"
var _world_loading_progress: float = 0.0
var _world_loading_reason: String = "character_selected"


func setup(p_bootstrap: Node = null, p_dol_client: Node = null, p_player: Node = null, p_asset_resolver: RefCounted = null) -> void:
	character_bootstrap_1127 = p_bootstrap
	dol_client = p_dol_client
	player = p_player
	asset_resolver = p_asset_resolver
	_ui_phase = start_phase if start_phase in ui_flow_order() else UI_PHASE_LOADING
	visible = visible_by_default
	_ensure_label()
	refresh_panel()
	set_process(true)


func set_character_bootstrap_1127(p_bootstrap: Node) -> void:
	character_bootstrap_1127 = p_bootstrap
	refresh_panel()


func set_dol_client(p_dol_client: Node) -> void:
	dol_client = p_dol_client
	refresh_panel()


func set_player(p_player: Node) -> void:
	player = p_player


func set_asset_resolver(p_asset_resolver: RefCounted) -> void:
	asset_resolver = p_asset_resolver
	refresh_panel()


func set_visible_enabled(enabled: bool) -> void:
	visible = enabled
	if enabled:
		refresh_panel()


func show_panel() -> void:
	set_visible_enabled(true)


func hide_panel() -> void:
	set_visible_enabled(false)


func toggle_panel() -> bool:
	set_visible_enabled(not visible)
	return visible


func is_panel_visible() -> bool:
	return visible


func set_auto_refresh_enabled(enabled: bool) -> void:
	auto_refresh_enabled = enabled


func is_auto_refresh_enabled() -> bool:
	return auto_refresh_enabled


func set_selected_index(index: int) -> void:
	_selected_index = clampi(index, 0, max_character_rows - 1)
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_selection_from_index"):
		character_bootstrap_1127.call("set_selection_from_index", _selected_index)
	if _ui_phase == UI_PHASE_CHARACTER_SELECT:
		start_world_loading_screen("character_selected")
	refresh_panel()


func selected_index() -> int:
	return _selected_index


func reset_login_selection_flow() -> void:
	_ui_phase = UI_PHASE_LOADING
	_selected_realm_id = 0
	_selected_index = 0
	_loading_progress = 0.0
	_loading_reason = "reset"
	_world_loading_progress = 0.0
	_world_loading_reason = "reset"
	refresh_panel()


func start_loading_screen(reason: String = "offline") -> Dictionary:
	_ui_phase = UI_PHASE_LOADING
	_loading_reason = reason
	_loading_progress = 0.0
	refresh_panel()
	return build_login_selection_flow_model()


func complete_loading_to_realm_select(reason: String = "offline_ready") -> Dictionary:
	_loading_reason = reason
	_loading_progress = 1.0
	_ui_phase = UI_PHASE_REALM_SELECT
	refresh_panel()
	return build_login_selection_flow_model()


func start_world_loading_screen(reason: String = "character_selected") -> Dictionary:
	_world_loading_reason = reason
	_world_loading_progress = 0.0
	_ui_phase = UI_PHASE_WORLD_LOADING
	refresh_panel()
	return build_login_selection_flow_model()


func complete_world_loading_to_ready(reason: String = "world_ready") -> Dictionary:
	_world_loading_reason = reason
	_world_loading_progress = 1.0
	_ui_phase = UI_PHASE_READY_TO_ENTER
	refresh_panel()
	return build_login_selection_flow_model()


func pregame_asset_root_hint() -> String:
	return "<DAOC>/pregame"


func post_character_loading_asset_root_hint() -> String:
	return "<DAOC>/Data/loading"


func character_select_scene_source_hint() -> String:
	return "pregame + scène 3D NIF post-Catacombs probable; Eden peut remplacer par visuel launcher custom."


func loading_asset_rule_basis() -> Dictionary:
	var basis := {
		"pregame_loading": pregame_asset_root_hint(),
		"post_character_loading": post_character_loading_asset_root_hint(),
		"character_select_scene": character_select_scene_source_hint(),
		"rule_status": "à auditer dans le client: probablement dépendance royaume / version / zone / custom Eden",
		"eden_custom_visuals": "non trouvés dans pregame standard; probablement installés/écrasés par launcher custom",
		"p1_n6d_resolver_attached": asset_resolver != null,
	}
	if asset_resolver != null and asset_resolver.has_method("status_snapshot"):
		basis["p1_n6d_status"] = asset_resolver.call("status_snapshot")
	return basis


func set_ui_phase(phase: String) -> Dictionary:
	var normalized := phase.strip_edges().to_upper()
	if not (normalized in ui_flow_order()):
		normalized = UI_PHASE_LOADING
	_ui_phase = normalized
	refresh_panel()
	return build_login_selection_flow_model()


func ui_phase() -> String:
	return _ui_phase


func ui_phase_index() -> int:
	return ui_flow_order().find(_ui_phase)


func ui_phase_label() -> String:
	match _ui_phase:
		UI_PHASE_LOADING:
			return "chargement"
		UI_PHASE_REALM_SELECT:
			return "sélection royaume"
		UI_PHASE_CHARACTER_SELECT:
			return "sélection personnage"
		UI_PHASE_WORLD_LOADING:
			return "chargement monde"
		UI_PHASE_READY_TO_ENTER:
			return "prêt entrée monde"
	return _ui_phase


func ui_flow_order() -> PackedStringArray:
	return PackedStringArray([UI_PHASE_LOADING, UI_PHASE_REALM_SELECT, UI_PHASE_CHARACTER_SELECT, UI_PHASE_WORLD_LOADING, UI_PHASE_READY_TO_ENTER])


func available_realms() -> Array:
	return [
		{"id": 1, "name": "Albion", "short": "alb", "enabled": true},
		{"id": 2, "name": "Midgard", "short": "mid", "enabled": true},
		{"id": 3, "name": "Hibernia", "short": "hib", "enabled": true},
	]


func selected_realm_snapshot() -> Dictionary:
	for realm in available_realms():
		var d: Dictionary = realm as Dictionary
		if int(d.get("id", 0)) == _selected_realm_id:
			return d.duplicate(true)
	return {}


func select_realm(realm_value) -> Dictionary:
	var realm_id := 0
	if typeof(realm_value) == TYPE_INT or typeof(realm_value) == TYPE_FLOAT:
		realm_id = int(realm_value)
	else:
		realm_id = realm_id_for_name(str(realm_value))
	if realm_id < 1 or realm_id > 3:
		return {"ok": false, "reason": "unknown realm", "value": str(realm_value), "phase": _ui_phase}
	_selected_realm_id = realm_id
	_ui_phase = UI_PHASE_CHARACTER_SELECT
	if dol_client != null and dol_client.has_method("import_bootstrap_charlist_to_client"):
		dol_client.call("import_bootstrap_charlist_to_client")
	refresh_panel()
	return {"ok": true, "realm": selected_realm_snapshot(), "phase": _ui_phase}


func realm_id_for_name(name: String) -> int:
	var n := name.strip_edges().to_lower()
	if n.is_valid_int():
		return int(n)
	for realm in available_realms():
		var d: Dictionary = realm as Dictionary
		if n == str(d.get("name", "")).to_lower() or n == str(d.get("short", "")).to_lower():
			return int(d.get("id", 0))
	return 0


func realm_name_for_id(realm_id: int) -> String:
	for realm in available_realms():
		var d: Dictionary = realm as Dictionary
		if int(d.get("id", 0)) == realm_id:
			return str(d.get("name", "Unknown"))
	return "Unknown"


func transition_to_character_select() -> Dictionary:
	if _selected_realm_id <= 0:
		_selected_realm_id = 1
	_ui_phase = UI_PHASE_CHARACTER_SELECT
	refresh_panel()
	return build_login_selection_flow_model()


func transition_to_ready_to_enter() -> Dictionary:
	_ui_phase = UI_PHASE_READY_TO_ENTER
	refresh_panel()
	return build_login_selection_flow_model()


func can_show_realm_select() -> bool:
	return _ui_phase == UI_PHASE_REALM_SELECT


func can_show_character_select() -> bool:
	return _ui_phase == UI_PHASE_CHARACTER_SELECT or _ui_phase == UI_PHASE_READY_TO_ENTER


func can_enter_world_from_ui() -> bool:
	return _ui_phase == UI_PHASE_READY_TO_ENTER and not selected_character_snapshot().is_empty()


func build_character_rows() -> Array:
	if character_bootstrap_1127 == null:
		return []
	if character_bootstrap_1127.has_method("build_character_overview_enriched_packet_1127") and character_bootstrap_1127.has_method("character_list_from_overview_packet"):
		var realm_id := _selected_realm_id if _selected_realm_id > 0 else 1
		var packet: PackedByteArray = character_bootstrap_1127.call("build_character_overview_enriched_packet_1127", {}, realm_id) as PackedByteArray
		var chars: Array = character_bootstrap_1127.call("character_list_from_overview_packet", packet, realm_id) as Array
		return chars
	return []


func build_loading_panel_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("phase=chargement pré-sélection progress=%.0f%% reason=%s" % [_loading_progress * 100.0, _loading_reason])
	lines.append("source assets: %s" % pregame_asset_root_hint())
	if asset_resolver != null and asset_resolver.has_method("build_asset_source_panel_lines"):
		lines.append_array(asset_resolver.call("build_asset_source_panel_lines", selected_realm_id_or_default(), -1, -1, "pregame_loading") as PackedStringArray)
	lines.append("commande: /dol loading done -> sélection royaume")
	return lines


func build_world_loading_panel_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("phase=chargement monde après personnage progress=%.0f%% reason=%s" % [_world_loading_progress * 100.0, _world_loading_reason])
	lines.append("source assets: %s" % post_character_loading_asset_root_hint())
	lines.append("règle assets: royaume/zone/version/Eden custom à auditer")
	if asset_resolver != null and asset_resolver.has_method("build_asset_source_panel_lines"):
		lines.append_array(asset_resolver.call("build_asset_source_panel_lines", selected_realm_id_or_default(), selected_character_region_or_default(), -1, "world_loading") as PackedStringArray)
	lines.append("commande: /dol worldloading done -> prêt entrée monde")
	return lines


func build_asset_source_panel_lines() -> PackedStringArray:
	if asset_resolver != null and asset_resolver.has_method("build_asset_source_panel_lines"):
		return asset_resolver.call("build_asset_source_panel_lines", selected_realm_id_or_default(), selected_character_region_or_default(), -1, "hud") as PackedStringArray
	var source := loading_asset_rule_basis()
	var lines := PackedStringArray()
	lines.append("assets pregame=%s" % str(source.get("pregame_loading", "")))
	lines.append("assets post-char=%s" % str(source.get("post_character_loading", "")))
	lines.append("scene perso=%s" % str(source.get("character_select_scene", "")))
	return lines


func build_realm_panel_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("phase=sélection royaume")
	lines.append("commande: /dol realm Albion|Midgard|Hibernia")
	for realm in available_realms():
		var d: Dictionary = realm as Dictionary
		var marker := ">" if int(d.get("id", 0)) == _selected_realm_id else " "
		lines.append("%s [%d] %s" % [marker, int(d.get("id", 0)), str(d.get("name", "?"))])
	return lines


func build_character_panel_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var realm := selected_realm_snapshot()
	var realm_name := str(realm.get("name", "Albion")) if not realm.is_empty() else "Albion"
	lines.append("phase=sélection personnage royaume=%s" % realm_name)
	lines.append("/dol choose <index> · /dol selected · /dol bootstrap")
	var chars := build_character_rows()
	if chars.is_empty():
		lines.append("aucun personnage offline parsé")
	else:
		for i in range(mini(chars.size(), max_character_rows)):
			var ch: Dictionary = chars[i] as Dictionary
			var marker := ">" if int(ch.get("index", i)) == _selected_index else " "
			if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("character_ui_row"):
				lines.append("%s %s" % [marker, str(character_bootstrap_1127.call("character_ui_row", ch))])
			else:
				lines.append("%s [%d] %s" % [marker, i, str(ch.get("name", "?"))])
	var selected := selected_character_snapshot()
	if selected.is_empty():
		lines.append("selected=<none>")
	else:
		lines.append("selected=%s slot=%d region=%d model=%d" % [str(selected.get("name", "?")), int(selected.get("account_slot", -1)), int(selected.get("region", 0)), int(selected.get("model", 0))])
	return lines


func build_panel_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("DAoC P1-N5H · pré-écran sélection offline")
	lines.append("P1-N6C flow: chargement pregame -> royaume -> personnage -> chargement monde")
	match _ui_phase:
		UI_PHASE_LOADING:
			lines.append_array(build_loading_panel_lines())
		UI_PHASE_REALM_SELECT:
			lines.append_array(build_realm_panel_lines())
		UI_PHASE_WORLD_LOADING:
			lines.append_array(build_world_loading_panel_lines())
		_:
			lines.append_array(build_character_panel_lines())
	lines.append("live_server=false real_ui=false apply_default=dry")
	return lines


func build_panel_text() -> String:
	return "\n".join(build_panel_lines())


func refresh_panel() -> String:
	_ensure_label()
	_last_model = build_ui_model()
	_last_text = build_panel_text()
	if _label != null:
		_label.text = _last_text
	return _last_text


func force_refresh() -> String:
	return refresh_panel()


func character_count() -> int:
	return build_character_rows().size()


func selected_character_snapshot() -> Dictionary:
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("selected_character_snapshot"):
		return character_bootstrap_1127.call("selected_character_snapshot") as Dictionary
	return {}


func select_character(index: int = 0) -> Dictionary:
	if _selected_realm_id <= 0:
		_selected_realm_id = 1
	_selected_index = clampi(index, 0, max_character_rows - 1)
	var result := {}
	if dol_client != null and dol_client.has_method("choose_bootstrap_character"):
		result = dol_client.call("choose_bootstrap_character", _selected_index) as Dictionary
	elif character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_selection_from_index"):
		result = character_bootstrap_1127.call("set_selection_from_index", _selected_index) as Dictionary
	else:
		return {}
	start_world_loading_screen("character_selected")
	return result


func unselect_character() -> bool:
	_ui_phase = UI_PHASE_CHARACTER_SELECT if _selected_realm_id > 0 else UI_PHASE_REALM_SELECT
	if dol_client != null and dol_client.has_method("unchoose_bootstrap_character"):
		var ok := bool(dol_client.call("unchoose_bootstrap_character"))
		refresh_panel()
		return ok
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("clear_selection"):
		character_bootstrap_1127.call("clear_selection")
		refresh_panel()
		return true
	return false


func build_ui_model() -> Dictionary:
	var model := {"screen": "login_selection_flow", "character_count": 0, "characters": [], "selected": {}}
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("build_selection_hud_model"):
		model = character_bootstrap_1127.call("build_selection_hud_model", build_character_rows()) as Dictionary
	model["screen"] = "daoc_offline_login_selection_flow"
	model["ui_phase"] = _ui_phase
	model["ui_phase_label"] = ui_phase_label()
	model["flow_order"] = ui_flow_order()
	model["selected_realm"] = selected_realm_snapshot()
	model["available_realms"] = available_realms()
	model["loading_progress"] = _loading_progress
	model["world_loading_progress"] = _world_loading_progress
	model["loading_asset_sources"] = loading_asset_rule_basis()
	model["p1_n6d_asset_summary"] = build_p1_n6d_asset_audit_snapshot()
	model["p1_n6d_asset_line"] = build_p1_n6d_asset_compact_line()
	model["flow_matches_daoc_order"] = true
	return model


func build_login_selection_flow_model() -> Dictionary:
	return build_ui_model()


func get_debug_snapshot() -> Dictionary:
	return {
		"scope": "P1-N5H/P1-N6C offline DAoC login selection HUD flow",
		"visible": visible,
		"auto_refresh_enabled": auto_refresh_enabled,
		"has_label": _label != null,
		"has_bootstrap": has_bootstrap(),
		"has_dol_client": dol_client != null,
		"character_count": character_count(),
		"selected_index": _selected_index,
		"selected": selected_character_snapshot(),
		"ui_phase": _ui_phase,
		"ui_phase_label": ui_phase_label(),
		"flow_order": ui_flow_order(),
		"selected_realm": selected_realm_snapshot(),
		"loading_asset_sources": loading_asset_rule_basis(),
		"p1_n6d_asset_summary": build_p1_n6d_asset_audit_snapshot(),
			"p1_n6d_asset_line": build_p1_n6d_asset_compact_line(),
		"world_loading_progress": _world_loading_progress,
		"flow_matches_daoc_order": true,
		"real_ui_final": false,
		"live_server_required": false,
	}


func status_snapshot() -> Dictionary:
	return get_debug_snapshot()


func has_bootstrap() -> bool:
	return character_bootstrap_1127 != null


func has_character_rows() -> bool:
	return character_count() > 0


func p1_n5h_scope() -> String:
	return "P1-N5H offline character select text HUD; debug/pre-UI only; no live server."


func p1_n6c_scope() -> String:
	return "P1-N6C offline UI flow: pregame loading, realm selection, character selection/3D scene, then Data/loading world loading; no live server."


func selected_realm_id_or_default() -> int:
	return _selected_realm_id if _selected_realm_id > 0 else 1


func selected_character_region_or_default() -> int:
	var selected := selected_character_snapshot()
	return int(selected.get("region", -1)) if not selected.is_empty() else -1


func build_p1_n6d_asset_audit_snapshot() -> Dictionary:
	if asset_resolver != null and asset_resolver.has_method("build_audit_summary_snapshot"):
		return asset_resolver.call("build_audit_summary_snapshot", selected_realm_id_or_default(), selected_character_region_or_default(), -1, "hud") as Dictionary
	if asset_resolver != null and asset_resolver.has_method("status_snapshot"):
		var status: Dictionary = asset_resolver.call("status_snapshot") as Dictionary
		status["report_is_compact"] = true
		return status
	return {"scope": "P1-N6D asset resolver", "attached": false, "status_name": "MISSING", "no_runtime_import": true, "report_is_compact": true}


func build_p1_n6d_asset_compact_line() -> String:
	if asset_resolver != null and asset_resolver.has_method("build_audit_compact_line"):
		return str(asset_resolver.call("build_audit_compact_line", selected_realm_id_or_default(), selected_character_region_or_default(), -1, "hud"))
	return "P1-N6D assets missing"


func p1_n6d_scope() -> String:
	return "P1-N6D offline HUD bridge: affiche les candidats pregame/loading du resolver, sans import runtime ni règle finale hardcodée."


func is_real_ui_final() -> bool:
	return false


func is_live_server_required() -> bool:
	return false


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"setup", "set_character_bootstrap_1127", "set_dol_client", "set_player", "set_asset_resolver", "set_visible_enabled", "show_panel", "hide_panel", "toggle_panel", "is_panel_visible", "set_auto_refresh_enabled", "is_auto_refresh_enabled", "set_selected_index", "selected_index", "reset_login_selection_flow", "start_loading_screen", "complete_loading_to_realm_select", "start_world_loading_screen", "complete_world_loading_to_ready", "pregame_asset_root_hint", "post_character_loading_asset_root_hint", "character_select_scene_source_hint", "loading_asset_rule_basis", "set_ui_phase", "ui_phase", "ui_phase_index", "ui_phase_label", "ui_flow_order", "available_realms", "selected_realm_snapshot", "select_realm", "realm_id_for_name", "realm_name_for_id", "transition_to_character_select", "transition_to_ready_to_enter", "can_show_realm_select", "can_show_character_select", "can_enter_world_from_ui", "build_character_rows", "build_loading_panel_lines", "build_world_loading_panel_lines", "build_asset_source_panel_lines", "build_realm_panel_lines", "build_character_panel_lines", "build_panel_lines", "build_panel_text", "refresh_panel", "force_refresh", "character_count", "selected_character_snapshot", "select_character", "unselect_character", "build_ui_model", "build_login_selection_flow_model", "get_debug_snapshot", "status_snapshot", "has_bootstrap", "has_character_rows", "p1_n5h_scope", "p1_n6c_scope", "selected_realm_id_or_default", "selected_character_region_or_default", "build_p1_n6d_asset_audit_snapshot", "build_p1_n6d_asset_compact_line", "p1_n6d_scope", "is_real_ui_final", "is_live_server_required", "get_function_names"
	])


func _ready() -> void:
	_ensure_label()
	_ui_phase = start_phase if start_phase in ui_flow_order() else UI_PHASE_LOADING
	visible = visible_by_default
	refresh_panel()
	set_process(true)


func _process(delta: float) -> void:
	if not auto_refresh_enabled:
		return
	_accum += delta
	if _accum < update_interval_sec:
		return
	_accum = 0.0
	if visible:
		refresh_panel()


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = "DaocCharacterSelectHudLabel"
	_label.position = Vector2(14, 126)
	_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
