extends CanvasLayer
class_name DaocDevHud

## HUD dev compact. Il ne remplace pas l'UI DAoC : il expose l'état local client pendant les paquets 1→8.

@export var visible_by_default: bool = true
@export var update_interval_sec: float = 0.15

var zone_viewer: Node = null
var player: Node = null
var player_camera: Node = null
var input_router: Node = null
var command_router: Node = null
var targeting: Node = null
var dol_client: Node = null

var _label: Label = null
var _accum: float = 0.0


func setup(p_zone_viewer: Node, p_player: Node, p_camera: Node, p_input_router: Node, p_command_router: Node, p_targeting: Node, p_dol_client: Node = null) -> void:
	zone_viewer = p_zone_viewer
	player = p_player
	player_camera = p_camera
	input_router = p_input_router
	command_router = p_command_router
	targeting = p_targeting
	dol_client = p_dol_client
	visible = visible_by_default
	_ensure_label()
	_refresh()
	set_process(true)


func _ready() -> void:
	_ensure_label()
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval_sec:
		return
	_accum = 0.0
	_refresh()


func toggle_visible() -> void:
	visible = not visible


func get_debug_snapshot() -> Dictionary:
	return {
		"exists": true,
		"visible": visible,
		"has_label": _label != null,
		"has_player": player != null,
		"has_input_router": input_router != null,
		"has_targeting": targeting != null,
		"has_dol_client": dol_client != null,
	}


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = "DaocDevHudLabel"
	_label.position = Vector2(12, 12)
	_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.82))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _refresh() -> void:
	_ensure_label()
	if _label == null:
		return
	var lines := PackedStringArray()
	lines.append("DAoC local client dev HUD · F12 test · /loc /where /targetnearest /targetjump /cleartarget /dol")
	if player != null:
		var state_name := "?"
		if player.has_method("get_movement_state_name"):
			state_name = str(player.call("get_movement_state_name"))
		var motor_speed := float(player.get("last_speed_raw"))
		var climb_flag := false
		if player.has_method("get_motor_local_flags_snapshot"):
			var motor_flags: Dictionary = player.call("get_motor_local_flags_snapshot") as Dictionary
			climb_flag = bool(motor_flags.get("climb_flag_local_placeholder", false))
		lines.append("zone%03d x=%.1f y=%.1f z=%.1f h=%.1f state=%s speed=%.1f water=%s wading=%s climb=%s" % [
			int(player.get("daoc_zone")),
			float(player.get("daoc_x")),
			float(player.get("daoc_y")),
			float(player.get("daoc_z")),
			float(player.get("heading_deg")),
			state_name,
			motor_speed,
			str(player.get("is_in_water")),
			str(player.get("is_wading")),
			str(climb_flag),
		])
	if input_router != null and input_router.has_method("get_input_state"):
		var st: Object = input_router.call("get_input_state") as Object
		if st != null and st.has_method("debug_string"):
			lines.append("input " + str(st.call("debug_string")))
		if st != null and st.has_method("action_debug_string"):
			lines.append("keys " + str(st.call("action_debug_string")))
	if player_camera != null:
		var cam_mode := "?"
		var cam_action := ""
		if player_camera.has_method("get_camera_debug_snapshot"):
			var cam_snap: Dictionary = player_camera.call("get_camera_debug_snapshot") as Dictionary
			cam_mode = str(cam_snap.get("mode", "?"))
			cam_action = str(cam_snap.get("last_camera_action_debug", ""))
		lines.append("cam dist=%.1f height=%.1f tilt=%.1f angle=%.1f mode=%s snap=%s %s" % [
			float(player_camera.get("distance_raw")),
			float(player_camera.get("height_raw")),
			float(player_camera.get("tilt_raw")),
			float(player_camera.get("angle_raw")),
			cam_mode,
			str(player_camera.get("snapback_enabled")),
			cam_action,
		])
	if dol_client != null and dol_client.has_method("get_network_debug_snapshot"):
		var dol_snap: Dictionary = dol_client.call("get_network_debug_snapshot") as Dictionary
		var pos_seq := 0
		var region_seq := 0
		if dol_client.has_method("get_position_sync_debug_snapshot"):
			var pos_snap: Dictionary = dol_client.call("get_position_sync_debug_snapshot") as Dictionary
			pos_seq = int(pos_snap.get("position_sequence", 0))
		if dol_client.has_method("get_regionchange_debug_snapshot"):
			var region_snap: Dictionary = dol_client.call("get_regionchange_debug_snapshot") as Dictionary
			region_seq = int(region_snap.get("sequence", 0))
		lines.append("dol state=%s sim=%s chars=%d world=%s pos=%d region=%d last=%s" % [
			str(dol_snap.get("state_name", "?")),
			str(dol_snap.get("simulated", false)),
			int(dol_snap.get("char_count", 0)),
			str(str(dol_snap.get("state_name", "")) == "IN_WORLD"),
			pos_seq,
			region_seq,
			str(dol_snap.get("last_action", "")),
		])
		if dol_client.has_method("get_p1_n5hij_debug_snapshot"):
			var hij_snap: Dictionary = dol_client.call("get_p1_n5hij_debug_snapshot") as Dictionary
			var phase: Dictionary = hij_snap.get("selection_phase", {}) as Dictionary
			var hud: Dictionary = hij_snap.get("hud", {}) as Dictionary
			lines.append("charselect phase=%s hud=%s selected=%d" % [str(phase.get("phase", "NONE")), str(hud.get("visible", false)), int(phase.get("selected_character_index", -1))])
	if targeting != null and targeting.has_method("get_target_debug_string"):
		lines.append(str(targeting.call("get_target_debug_string")))
	_label.text = "\n".join(lines)
