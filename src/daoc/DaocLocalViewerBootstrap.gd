extends RefCounted
class_name DaocLocalViewerBootstrap

## P1-15G — Viewer shell final / bootstrap cleanup.
## Owns local viewer bootstrap glue: environment, optional fly camera,
## player capsule stack, local targeting, DOL offline helpers, command router and dev HUD.
## It must not build terrain/water/collision/props nor change gameplay rules.

const DaocPlayerMotorScript = preload("res://src/daoc/DaocPlayerMotor.gd")
const DaocPlayerCameraScript = preload("res://src/daoc/DaocPlayerCamera.gd")
const DaocInputRouterScript = preload("res://src/daoc/DaocInputRouter.gd")
const DaocCommandRouterScript = preload("res://src/daoc/DaocCommandRouter.gd")
const DaocDevHudScript = preload("res://src/daoc/DaocDevHud.gd")
const DaocLocalTargetingScript = preload("res://src/daoc/DaocLocalTargeting.gd")
const DaocDolClientScript = preload("res://src/daoc/DaocDolClient.gd")
const DaocDolTransportScript = preload("res://src/daoc/DaocDolTransport.gd")
const DaocDolPacketScript = preload("res://src/daoc/DaocDolPacket.gd")
const DaocDolWire1127Script = preload("res://src/daoc/DaocDolWire1127.gd")
const DaocDolLoginFlow1127Script = preload("res://src/daoc/DaocDolLoginFlow1127.gd")
const DaocDolServerFixtures1127Script = preload("res://src/daoc/DaocDolServerFixtures1127.gd")
const DaocDolCharacterBootstrap1127Script = preload("res://src/daoc/DaocDolCharacterBootstrap1127.gd")
const DaocDolCharacterSelectHud1127Script = preload("res://src/daoc/DaocDolCharacterSelectHud1127.gd")
const DaocPregameLoadingAssetResolverScript = preload("res://src/daoc/DaocPregameLoadingAssetResolver.gd")

var _configured: bool = false
var _last_result: Dictionary = {}


func build_ready_sequence(host: Node3D) -> Dictionary:
	if host == null:
		_last_result = {"ok": false, "error": "missing host"}
		return _last_result

	host.call("_load_placement")
	host.call("_compute_base")
	setup_environment(host)
	var zone_list: PackedInt32Array = host.get("zones") as PackedInt32Array
	for z in zone_list:
		host.call("_build_zone", int(z))
	setup_fly_camera(host)
	setup_player_stack(host)
	setup_legacy_hud(host)
	host.call("_apply_visual_stage_lamps_15c")
	host.call("_apply_visual_stage_cards_15c")

	_configured = true
	_last_result = {
		"ok": true,
		"scope": "P1-15G Viewer shell final / bootstrap cleanup",
		"zones_built": zone_list.size(),
		"environment_present": host.get("_viewer_environment") != null,
		"sun_present": host.get("_viewer_sun") != null,
		"fly_camera_present": host.get("_fly_camera") != null,
		"player_present": host.get("_player") != null,
		"player_camera_present": host.get("_player_camera") != null,
		"input_router_present": host.get("_input_router") != null,
		"command_router_present": host.get("_command_router") != null,
		"dev_hud_present": host.get("_dev_hud") != null,
		"local_targeting_present": host.get("_local_targeting") != null,
		"dol_client_present": host.get("_dol_client") != null,
		"dol_transport_present": host.get("_dol_transport") != null,
		"dol_packet_layer_present": host.get("_dol_packet_layer") != null,
		"dol_wire_1127_present": host.get("_dol_wire_1127") != null,
		"dol_login_flow_1127_present": host.get("_dol_login_flow_1127") != null,
		"dol_server_fixtures_1127_present": host.get("_dol_server_fixtures_1127") != null,
		"dol_character_bootstrap_1127_present": host.get("_dol_character_bootstrap_1127") != null,
		"dol_character_select_hud_1127_present": host.get("_dol_character_select_hud_1127") != null,
		"pregame_loading_asset_resolver_present": host.get("_daoc_pregame_loading_asset_resolver") != null,
	}
	return _last_result


func setup_environment(host: Node3D) -> void:
	if bool(host.get("daoc_environment_enabled")) and host.has_method("_build_daoc_environment"):
		host.call("_build_daoc_environment")
		if host.get("_viewer_environment") != null and host.get("_viewer_sun") != null:
			return
	var sun := DirectionalLight3D.new()
	host.set("_viewer_sun", sun)
	sun.rotation_degrees = Vector3(-52, -130, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	host.add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	host.set("_viewer_environment", env)

	var we := WorldEnvironment.new()
	we.environment = env
	host.add_child(we)


func setup_fly_camera(host: Node3D) -> void:
	if bool(host.get("spawn_player_capsule")) and not bool(host.get("keep_fly_camera")):
		return
	var span := Vector2.ZERO
	var zone_list: PackedInt32Array = host.get("zones") as PackedInt32Array
	var base: Vector2 = host.get("_base") as Vector2
	for z in zone_list:
		var o: Vector2 = (host.call("_origin", int(z)) as Vector2) - base
		span.x = max(span.x, o.x + 65536.0)
		span.y = max(span.y, o.y + 65536.0)
	var world_scale: float = float(host.get("world_scale"))
	var cam := Camera3D.new()
	host.set("_fly_camera", cam)
	cam.name = "FlyCamera"
	cam.set_script(load("res://FlyCamera.gd"))
	cam.position = Vector3(span.x * 0.5 * world_scale,
		18000.0 * world_scale, span.y * 1.15 * world_scale)
	host.add_child(cam)
	var fly_target := Vector3(span.x * 0.5 * world_scale, 0, span.y * 0.5 * world_scale)
	if cam.global_position.distance_squared_to(fly_target) > 0.000001:
		cam.look_at(fly_target, Vector3.UP)
	# La camera libre est un outil d'ATELIER : elle reste lue sur l'hote, la
	# scene de jeu ne la monte pas du tout.
	cam.current = not (bool(host.get("spawn_player_capsule")) and bool(host.get("player_camera_current")))


func setup_legacy_hud(host: Node3D) -> void:
	var layer := CanvasLayer.new()
	var lbl := Label.new()
	lbl.position = Vector2(12, 10)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	var player_help := ""
	if bool(host.get("spawn_player_capsule")):
		player_help = "\nCapsule: keyboard.dat physique actif · souris = caméra/mouselook · déplacement souris legacy désactivé"
	lbl.text = "assemblage:%s  ·  exagération ×%s\nCaméra libre: clic gauche regarder · ZQSD déplacer · A/E bas/haut · Shift vite · Échap relâcher%s" % [
		str(host.get("_hud_zones")), str(host.get("height_exaggeration")), player_help]
	layer.add_child(lbl)
	host.add_child(layer)


## R7 — les reglages de la pile joueur, en DONNEES.
##
## Meme mouvement qu'a R4 pour les etapes de zone : ce module lisait ~24
## proprietes de l'hote par leur nom. Sur un hote qui ne les declare pas - la
## scene de jeu R6 - `host.get()` rend `null`, et `float(null)` vaut 0.0 : on
## obtiendrait un joueur a vitesse nulle qui a l'air configure.
##
## Un hote qui expose `player_stack_settings_r7()` pilote donc la pile par un
## dictionnaire. Le ZoneViewer ne l'expose pas autrement que comme un miroir de
## ses `@export`, donc son chemin est inchange par construction.
const PLAYER_STACK_SETTING_KEYS := [
	"spawn_player_capsule", "player_zone", "player_run_speed_raw",
	"player_turn_rate_deg_per_sec", "player_use_client_camera_ini",
	"player_camera_ini_path", "player_camera_debug_input",
	"player_camera_snapback_enabled", "player_camera_snapback_speed_units_per_sec",
	"player_camera_distance_raw", "player_camera_height_raw", "player_camera_tilt_raw",
	"player_camera_fov_degrees",
	"player_camera_current", "player_right_mouse_turns_player",
	"player_use_keyboard_dat_bindings", "player_respect_keyboard_shift_raw",
	"player_force_disable_legacy_mouse_movement", "player_mouse_right_moves_forward",
	"player_mouse_left_moves_backward", "player_mouse_both_buttons_move_forward",
	"player_keyboard_preset", "player_debug_print_keyboard_bindings",
	"build_local_targeting", "local_targeting_nearest_radius_raw",
	"log_player_spawn", "player_use_sector_start",
]


## Les reglages de la pile joueur, tels que l'hote les declare.
##
## `mount_dol_and_hud` n'est PAS dans la liste ci-dessus : il n'a pas d'`@export`
## correspondant. C'est un garde d'ENTREE ajoute par R7 pour la scene de jeu -
## vrai par defaut, donc le banc monte comme avant l'ensemble transport DOL,
## routeur de commandes et HUD de developpement, chacun derriere son propre
## drapeau d'hote.
func player_stack_settings(host: Node3D) -> Dictionary:
	if host.has_method("player_stack_settings_r7"):
		var declared: Dictionary = host.call("player_stack_settings_r7") as Dictionary
		if not declared.has("mount_dol_and_hud"):
			declared["mount_dol_and_hud"] = true
		return declared
	var out: Dictionary = {"mount_dol_and_hud": true}
	for key: String in PLAYER_STACK_SETTING_KEYS:
		out[key] = host.get(key)
	return out


func setup_player_stack(host: Node3D) -> void:
	var settings: Dictionary = player_stack_settings(host)
	if not bool(settings.get("spawn_player_capsule", false)):
		return
	var znum: int = int(settings.get("player_zone", 0))
	var state: Object = host.get("_state_15e") as Object
	var zone_runtime: Dictionary = {}
	if state != null:
		zone_runtime = state.get("zone_runtime") as Dictionary
	if not zone_runtime.has(znum):
		var zone_list: PackedInt32Array = host.get("zones") as PackedInt32Array
		if zone_list.size() > 0:
			znum = int(zone_list[0])
		else:
			znum = 0
	var start: Dictionary = host.call("_resolve_player_start", znum) as Dictionary
	var start_pos: Vector3 = start["pos"] as Vector3

	var player: Node3D = DaocPlayerMotorScript.new()
	player.name = "DaocPlayerCapsule"
	player.set("local_run_speed_raw", float(settings.get("player_run_speed_raw", 0.0)))
	player.set("turn_rate_deg_per_sec", float(settings.get("player_turn_rate_deg_per_sec", 0.0)))
	player.set("show_debug_mesh", bool(settings.get("player_show_debug_mesh", true)))
	host.add_child(player)
	host.set("_player", player)
	player.call("setup", host, znum, start_pos, float(start["heading"]), false)

	var player_camera: Node = DaocPlayerCameraScript.new()
	player_camera.name = "DaocPlayerCamera"
	player_camera.set("use_client_camera_ini", bool(settings.get("player_use_client_camera_ini", false)))
	player_camera.set("camera_ini_path", str(settings.get("player_camera_ini_path", "")))
	player_camera.set("debug_camera", bool(settings.get("player_camera_debug_input", false)))
	player_camera.set("snapback_enabled", bool(settings.get("player_camera_snapback_enabled", false)))
	player_camera.set("snapback_speed_units_per_sec", float(settings.get("player_camera_snapback_speed_units_per_sec", 0.0)))
	player_camera.set("distance_raw", float(settings.get("player_camera_distance_raw", 240.0)))
	player_camera.set("height_raw", float(settings.get("player_camera_height_raw", 10.0)))
	player_camera.set("tilt_raw", float(settings.get("player_camera_tilt_raw", 174.0)))
	player_camera.set("camera_fov_degrees", float(settings.get("player_camera_fov_degrees", 75.0)))
	host.add_child(player_camera)
	host.set("_player_camera", player_camera)
	player_camera.call("setup", host, player, bool(settings.get("player_camera_current", true)))
	player.set("player_camera", player_camera)

	var input_router: Node = DaocInputRouterScript.new()
	input_router.name = "DaocInputRouter"
	input_router.set("right_mouse_turns_player", bool(settings.get("player_right_mouse_turns_player", false)))
	input_router.set("use_keyboard_dat_bindings", bool(settings.get("player_use_keyboard_dat_bindings", false)))
	input_router.set("respect_keyboard_shift_raw", bool(settings.get("player_respect_keyboard_shift_raw", false)))
	var legacy_mouse_allowed_by_viewer: bool = not bool(settings.get("player_force_disable_legacy_mouse_movement", true))
	input_router.set("mouse_right_moves_forward", bool(settings.get("player_mouse_right_moves_forward", false)) and legacy_mouse_allowed_by_viewer)
	input_router.set("mouse_left_moves_backward", bool(settings.get("player_mouse_left_moves_backward", false)) and legacy_mouse_allowed_by_viewer)
	input_router.set("mouse_both_buttons_move_forward", bool(settings.get("player_mouse_both_buttons_move_forward", false)) and legacy_mouse_allowed_by_viewer)
	input_router.set("debug_input", bool(settings.get("player_camera_debug_input", false)))
	input_router.set("keyboard_preset", str(settings.get("player_keyboard_preset", "")))
	input_router.set("debug_print_keyboard_bindings", bool(settings.get("player_debug_print_keyboard_bindings", false)))
	host.add_child(input_router)
	host.set("_input_router", input_router)
	input_router.call("setup", player, player_camera, _effective_daoc_root(host))

	if bool(settings.get("build_local_targeting", false)):
		var local_targeting: Node = DaocLocalTargetingScript.new()
		local_targeting.name = "DaocLocalTargeting"
		local_targeting.set("nearest_radius_raw", float(settings.get("local_targeting_nearest_radius_raw", 0.0)))
		host.add_child(local_targeting)
		host.set("_local_targeting", local_targeting)
		local_targeting.call("setup", host, player, player_camera)

	# R7 — garde d'ENTREE, et le seul de ce jalon. Chacun de ces onze montages a
	# deja son propre drapeau cote hote ; ce garde existe pour l'hote qui n'en
	# declare AUCUN. Sans lui, `bool(null)` deciderait a sa place - et parmi ces
	# onze se trouvent le transport DOL et le flux de login, c'est-a-dire du
	# reseau. Une decision reseau ne doit jamais dependre d'une propriete absente.
	if bool(settings.get("mount_dol_and_hud", true)):
		_setup_pregame_resolver(host)
		_setup_dol_transport(host)
		_setup_dol_packet_layer(host)
		_setup_dol_wire_1127(host)
		_setup_dol_login_flow_1127(host)
		_setup_dol_server_fixtures_1127(host)
		_setup_dol_character_bootstrap_1127(host)
		_setup_dol_client(host, player)
		_setup_dol_character_select_hud_1127(host, player)
		_setup_command_router(host, player, player_camera)
		_setup_dev_hud(host, player, player_camera, input_router)

	if bool(settings.get("log_player_spawn", false)):
		print("player capsule/router: zone%03d x=%.1f y=%.1f z=%.1f heading=%.1f source=%s sector_start=%s camera_ini=%s" % [
			znum, start_pos.x, start_pos.y, start_pos.z, float(start["heading"]), str(start.get("source", "?")), str(settings.get("player_use_sector_start", false)), str(settings.get("player_camera_ini_path", ""))
		])


func _effective_daoc_root(host: Node3D) -> String:
	var registry: RefCounted = host.call("_ensure_asset_index_registry_15d") as RefCounted
	if registry != null and registry.has_method("effective_daoc_root"):
		return str(registry.call("effective_daoc_root"))
	return ""


func _setup_pregame_resolver(host: Node3D) -> void:
	if not bool(host.get("build_daoc_pregame_loading_asset_resolver")):
		return
	var resolver: RefCounted = DaocPregameLoadingAssetResolverScript.new()
	host.set("_daoc_pregame_loading_asset_resolver", resolver)
	if resolver.has_method("setup"):
		resolver.call("setup", _effective_daoc_root(host))


func _setup_dol_transport(host: Node3D) -> void:
	if not bool(host.get("build_dol_transport")):
		return
	var transport: Node = DaocDolTransportScript.new()
	transport.name = "DaocDolTransport"
	transport.set("enabled", bool(host.get("dol_transport_enabled")))
	transport.set("host", str(host.get("dol_default_host")))
	transport.set("port", int(host.get("dol_default_port")))
	transport.set("connect_timeout_msec", int(host.get("dol_transport_timeout_msec")))
	transport.set("debug_transport", bool(host.get("dol_debug_network")))
	host.add_child(transport)
	host.set("_dol_transport", transport)
	transport.call("setup_transport", null)
	transport.call("configure_transport", str(host.get("dol_default_host")), int(host.get("dol_default_port")), bool(host.get("dol_transport_enabled")), int(host.get("dol_transport_timeout_msec")))


func _setup_dol_packet_layer(host: Node3D) -> void:
	if not bool(host.get("build_dol_packet_layer")):
		return
	var packet_layer: Node = DaocDolPacketScript.new()
	packet_layer.name = "DaocDolPacket"
	host.add_child(packet_layer)
	host.set("_dol_packet_layer", packet_layer)
	if packet_layer.has_method("configure_packet_layer"):
		packet_layer.call("configure_packet_layer", bool(host.get("dol_debug_network")), true)
	if packet_layer.has_method("register_default_debug_opcodes"):
		packet_layer.call("register_default_debug_opcodes")


func _setup_dol_wire_1127(host: Node3D) -> void:
	if not bool(host.get("build_dol_wire_1127")):
		return
	var wire: Node = DaocDolWire1127Script.new()
	wire.name = "DaocDolWire1127"
	host.add_child(wire)
	host.set("_dol_wire_1127", wire)
	if wire.has_method("configure_wire_profile"):
		wire.call("configure_wire_profile", "127.0.0.1", 10300, 10400, bool(host.get("dol_debug_network")))


func _setup_dol_login_flow_1127(host: Node3D) -> void:
	if not bool(host.get("build_dol_login_flow_1127")):
		return
	var flow: Node = DaocDolLoginFlow1127Script.new()
	flow.name = "DaocDolLoginFlow1127"
	host.add_child(flow)
	host.set("_dol_login_flow_1127", flow)
	var wire: Node = host.get("_dol_wire_1127") as Node
	if flow.has_method("setup_flow"):
		flow.call("setup_flow", wire)
	if flow.has_method("configure_account"):
		flow.call("configure_account", "testgodot", "testgodot")
	if flow.has_method("configure_character"):
		flow.call("configure_character", 1, 0, 0)


func _setup_dol_server_fixtures_1127(host: Node3D) -> void:
	if not bool(host.get("build_dol_server_fixtures_1127")):
		return
	var fixtures: Node = DaocDolServerFixtures1127Script.new()
	fixtures.name = "DaocDolServerFixtures1127"
	host.add_child(fixtures)
	host.set("_dol_server_fixtures_1127", fixtures)
	var login_flow: Node = host.get("_dol_login_flow_1127") as Node
	if fixtures.has_method("setup_fixtures"):
		fixtures.call("setup_fixtures", login_flow)
	if fixtures.has_method("configure_identity"):
		fixtures.call("configure_identity", "testgodot", "GodotDOL", 1, 1)
	if fixtures.has_method("configure_position"):
		fixtures.call("configure_position", 1, 32768, 32768, 2075, 0)


func _setup_dol_character_bootstrap_1127(host: Node3D) -> void:
	if not bool(host.get("build_dol_character_bootstrap_1127")):
		return
	var bootstrap: Node = DaocDolCharacterBootstrap1127Script.new()
	bootstrap.name = "DaocDolCharacterBootstrap1127"
	host.add_child(bootstrap)
	host.set("_dol_character_bootstrap_1127", bootstrap)
	var fixtures: Node = host.get("_dol_server_fixtures_1127") as Node
	var login_flow: Node = host.get("_dol_login_flow_1127") as Node
	if bootstrap.has_method("setup_bootstrap"):
		bootstrap.call("setup_bootstrap", fixtures, login_flow)
	if bootstrap.has_method("configure_selection"):
		bootstrap.call("configure_selection", 0, 1)


func _setup_dol_client(host: Node3D, player: Node3D) -> void:
	if not bool(host.get("build_dol_client")):
		return
	var client: Node = DaocDolClientScript.new()
	client.name = "DaocDolClient"
	client.set("simulate_by_default", bool(host.get("dol_simulation_enabled")))
	client.set("default_host", str(host.get("dol_default_host")))
	client.set("default_port", int(host.get("dol_default_port")))
	client.set("default_account", str(host.get("dol_default_account")))
	client.set("debug_network", bool(host.get("dol_debug_network")))
	host.add_child(client)
	host.set("_dol_client", client)
	client.call("setup", host, player)
	_link_if(client, "set_transport", host.get("_dol_transport"))
	_link_if(client, "set_packet_layer", host.get("_dol_packet_layer"))
	_link_if(client, "set_wire_1127", host.get("_dol_wire_1127"))
	_link_if(client, "set_login_flow_1127", host.get("_dol_login_flow_1127"))
	_link_if(client, "set_server_fixtures_1127", host.get("_dol_server_fixtures_1127"))
	_link_if(client, "set_character_bootstrap_1127", host.get("_dol_character_bootstrap_1127"))
	_link_if(client, "set_pregame_loading_asset_resolver", host.get("_daoc_pregame_loading_asset_resolver"))


func _setup_dol_character_select_hud_1127(host: Node3D, player: Node3D) -> void:
	if not bool(host.get("build_dol_character_select_hud_1127")):
		return
	var hud: Node = DaocDolCharacterSelectHud1127Script.new()
	hud.name = "DaocDolCharacterSelectHud1127"
	host.add_child(hud)
	host.set("_dol_character_select_hud_1127", hud)
	var bootstrap: Node = host.get("_dol_character_bootstrap_1127") as Node
	var client: Node = host.get("_dol_client") as Node
	var resolver: RefCounted = host.get("_daoc_pregame_loading_asset_resolver") as RefCounted
	if hud.has_method("setup"):
		hud.call("setup", bootstrap, client, player, resolver)
	elif resolver != null and hud.has_method("set_asset_resolver"):
		hud.call("set_asset_resolver", resolver)
	if client != null and client.has_method("set_character_select_hud_1127"):
		client.call("set_character_select_hud_1127", hud)


func _setup_command_router(host: Node3D, player: Node3D, player_camera: Node) -> void:
	var command_router: Node = DaocCommandRouterScript.new()
	command_router.name = "DaocCommandRouter"
	host.add_child(command_router)
	host.set("_command_router", command_router)
	command_router.call("setup", player_camera, player, host, host.get("_local_targeting"), host.get("_dol_client"))


func _setup_dev_hud(host: Node3D, player: Node3D, player_camera: Node, input_router: Node) -> void:
	if not bool(host.get("build_dev_hud")):
		return
	var dev_hud: CanvasLayer = DaocDevHudScript.new()
	dev_hud.name = "DaocDevHud"
	dev_hud.set("visible_by_default", bool(host.get("dev_hud_visible")))
	host.add_child(dev_hud)
	host.set("_dev_hud", dev_hud)
	dev_hud.call("setup", host, player, player_camera, input_router, host.get("_command_router"), host.get("_local_targeting"), host.get("_dol_client"))


func _link_if(target: Object, method_name: String, value: Variant) -> void:
	if target != null and value != null and target.has_method(method_name):
		target.call(method_name, value)


func status_snapshot(host: Node3D = null) -> Dictionary:
	var snap := {
		"scope": "P1-15G Viewer shell final / bootstrap cleanup",
		"checkpoint": "E_VIEWER_SHELL_BOOTSTRAP",
		"configured": _configured,
		"last_result": _last_result,
	}
	if host != null:
		snap["environment_present"] = host.get("_viewer_environment") != null
		snap["sun_present"] = host.get("_viewer_sun") != null
		snap["fly_camera_present"] = host.get("_fly_camera") != null
		snap["player_present"] = host.get("_player") != null
		snap["player_camera_present"] = host.get("_player_camera") != null
		snap["input_router_present"] = host.get("_input_router") != null
		snap["command_router_present"] = host.get("_command_router") != null
		snap["dev_hud_present"] = host.get("_dev_hud") != null
		snap["local_targeting_present"] = host.get("_local_targeting") != null
		snap["dol_client_present"] = host.get("_dol_client") != null
		snap["dol_transport_present"] = host.get("_dol_transport") != null
		snap["dol_packet_layer_present"] = host.get("_dol_packet_layer") != null
		snap["dol_wire_1127_present"] = host.get("_dol_wire_1127") != null
		snap["dol_login_flow_1127_present"] = host.get("_dol_login_flow_1127") != null
		snap["dol_server_fixtures_1127_present"] = host.get("_dol_server_fixtures_1127") != null
		snap["dol_character_bootstrap_1127_present"] = host.get("_dol_character_bootstrap_1127") != null
		snap["dol_character_select_hud_1127_present"] = host.get("_dol_character_select_hud_1127") != null
		snap["pregame_loading_asset_resolver_present"] = host.get("_daoc_pregame_loading_asset_resolver") != null
	return snap
