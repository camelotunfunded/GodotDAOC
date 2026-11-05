extends Node
class_name DaocDolClient

## P1-N1/P1-N2: squelette réseau DOL côté client.
## Cette classe ne parle pas encore au vrai serveur Eden/DOL.
## Elle formalise les états login -> charlist -> enter world, les snapshots debug,
## puis les paquets simulés position / heading / regionchange.

signal state_changed(old_state: int, new_state: int, reason: String)

enum ConnectionState {
	OFFLINE,
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	LOGGING_IN,
	LOGIN_OK,
	CHARLIST_READY,
	ENTERING_WORLD,
	IN_WORLD,
	ERROR,
}

@export var simulate_by_default: bool = true
@export var default_host: String = ""
@export var default_port: int = 0
@export var debug_network: bool = false
@export var default_account: String = "debug"

var zone_viewer: Node = null
var player: Node = null
var transport: Node = null
var packet_layer: Node = null
var wire_1127: Node = null
var login_flow_1127: Node = null
var server_fixtures_1127: Node = null
var character_bootstrap_1127: Node = null
var character_select_hud_1127: Node = null
var pregame_loading_asset_resolver: RefCounted = null

var state: int = ConnectionState.DISCONNECTED
var last_error: String = ""
var last_action: String = "init"
var session_id: String = ""
var account_name: String = ""
var selected_character_index: int = -1
var selected_character: Dictionary = {}
var character_select_phase: String = "NONE"
var last_bootstrap_apply_snapshot: Dictionary = {}
var last_bootstrap_safe_apply_snapshot: Dictionary = {}
var last_bootstrap_rollback_snapshot: Dictionary = {}
var charlist: Array = []
var event_log: Array = []
var packet_flow: Array = []
var login_started_msec: int = 0
var last_transition_msec: int = 0
var last_position_snapshot: Dictionary = {}
var last_position_ack_snapshot: Dictionary = {}
var last_heading_snapshot: Dictionary = {}
var last_regionchange_snapshot: Dictionary = {}
var position_sequence: int = 0
var heading_sequence: int = 0
var regionchange_sequence: int = 0
var last_region_id: int = -1
var last_zone_id: int = -1



func setup(p_zone_viewer: Node = null, p_player: Node = null) -> void:
	zone_viewer = p_zone_viewer
	player = p_player
	if state == ConnectionState.OFFLINE:
		state = ConnectionState.DISCONNECTED
	last_transition_msec = Time.get_ticks_msec()
	if transport != null and transport.has_method("setup_transport"):
		transport.call("setup_transport", self)


func set_transport(p_transport: Node) -> void:
	transport = p_transport
	if transport != null and transport.has_method("setup_transport"):
		transport.call("setup_transport", self)
	_append_event("transport", {"attached": transport != null})


func set_packet_layer(p_packet_layer: Node) -> void:
	packet_layer = p_packet_layer
	if packet_layer != null and packet_layer.has_method("register_default_debug_opcodes"):
		packet_layer.call("register_default_debug_opcodes")
	_append_event("packet_layer", {"attached": packet_layer != null})


func set_wire_1127(p_wire: Node) -> void:
	wire_1127 = p_wire
	if wire_1127 != null and wire_1127.has_method("configure_wire_profile"):
		wire_1127.call("configure_wire_profile", "127.0.0.1", 10300, 10400, debug_network)
	if login_flow_1127 != null and login_flow_1127.has_method("set_wire_1127"):
		login_flow_1127.call("set_wire_1127", wire_1127)
	_append_event("wire_1127", {"attached": wire_1127 != null})


func set_login_flow_1127(p_login_flow: Node) -> void:
	login_flow_1127 = p_login_flow
	if login_flow_1127 != null and login_flow_1127.has_method("set_wire_1127") and wire_1127 != null:
		login_flow_1127.call("set_wire_1127", wire_1127)
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("set_login_flow_1127"):
		server_fixtures_1127.call("set_login_flow_1127", login_flow_1127)
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_login_flow_1127"):
		character_bootstrap_1127.call("set_login_flow_1127", login_flow_1127)
	_append_event("login_flow_1127", {"attached": login_flow_1127 != null})


func set_server_fixtures_1127(p_server_fixtures: Node) -> void:
	server_fixtures_1127 = p_server_fixtures
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("set_login_flow_1127") and login_flow_1127 != null:
		server_fixtures_1127.call("set_login_flow_1127", login_flow_1127)
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_server_fixtures_1127"):
		character_bootstrap_1127.call("set_server_fixtures_1127", server_fixtures_1127)
	_append_event("server_fixtures_1127", {"attached": server_fixtures_1127 != null})


func set_character_bootstrap_1127(p_character_bootstrap: Node) -> void:
	character_bootstrap_1127 = p_character_bootstrap
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_server_fixtures_1127") and server_fixtures_1127 != null:
		character_bootstrap_1127.call("set_server_fixtures_1127", server_fixtures_1127)
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("set_login_flow_1127") and login_flow_1127 != null:
		character_bootstrap_1127.call("set_login_flow_1127", login_flow_1127)
	_append_event("character_bootstrap_1127", {"attached": character_bootstrap_1127 != null})


func set_character_select_hud_1127(p_hud: Node) -> void:
	character_select_hud_1127 = p_hud
	if character_select_hud_1127 != null:
		if character_select_hud_1127.has_method("set_character_bootstrap_1127"):
			character_select_hud_1127.call("set_character_bootstrap_1127", character_bootstrap_1127)
		if character_select_hud_1127.has_method("set_dol_client"):
			character_select_hud_1127.call("set_dol_client", self)
		if character_select_hud_1127.has_method("set_player"):
			character_select_hud_1127.call("set_player", player)
		if pregame_loading_asset_resolver != null and character_select_hud_1127.has_method("set_asset_resolver"):
			character_select_hud_1127.call("set_asset_resolver", pregame_loading_asset_resolver)
	_append_event("character_select_hud_1127", {"attached": character_select_hud_1127 != null})


func set_pregame_loading_asset_resolver(p_resolver: RefCounted) -> void:
	pregame_loading_asset_resolver = p_resolver
	if character_select_hud_1127 != null and character_select_hud_1127.has_method("set_asset_resolver"):
		character_select_hud_1127.call("set_asset_resolver", pregame_loading_asset_resolver)
	_append_event("p1_n6d_asset_resolver", {"attached": pregame_loading_asset_resolver != null})


func configure(host: String, port: int, account: String = "") -> void:
	default_host = host.strip_edges()
	default_port = maxi(0, port)
	if account.strip_edges() != "":
		default_account = account.strip_edges()
	_append_event("configure", {"host": default_host, "port": default_port, "account": default_account})
	if transport != null and transport.has_method("configure_transport"):
		transport.call("configure_transport", default_host, default_port, false, 2500)


func reset_to_disconnected() -> void:
	last_error = ""
	last_action = "reset"
	session_id = ""
	account_name = ""
	selected_character_index = -1
	selected_character.clear()
	character_select_phase = "NONE"
	last_bootstrap_apply_snapshot.clear()
	last_bootstrap_safe_apply_snapshot.clear()
	last_bootstrap_rollback_snapshot.clear()
	charlist.clear()
	last_position_snapshot.clear()
	last_position_ack_snapshot.clear()
	last_heading_snapshot.clear()
	last_regionchange_snapshot.clear()
	position_sequence = 0
	heading_sequence = 0
	regionchange_sequence = 0
	last_region_id = -1
	last_zone_id = -1
	event_log.clear()
	packet_flow.clear()
	_transition(ConnectionState.DISCONNECTED, "reset")


func start_login(account: String = "", password: String = "", simulate: bool = true) -> bool:
	# Mot de passe volontairement ignoré et jamais stocké dans les snapshots.
	var _ignored_password := password
	last_error = ""
	charlist.clear()
	selected_character.clear()
	selected_character_index = -1
	last_position_snapshot.clear()
	last_position_ack_snapshot.clear()
	last_heading_snapshot.clear()
	last_regionchange_snapshot.clear()
	position_sequence = 0
	heading_sequence = 0
	regionchange_sequence = 0
	last_region_id = -1
	last_zone_id = -1
	login_started_msec = Time.get_ticks_msec()
	account_name = account.strip_edges()
	if account_name == "":
		account_name = default_account
	if account_name == "":
		account_name = "debug"
	var use_sim := simulate or simulate_by_default
	if not use_sim:
		if transport != null and transport.has_method("connect_to_configured_host"):
			_transition(ConnectionState.CONNECTING, "P1-N3 transport connect attempt")
			var transport_ok := bool(transport.call("connect_to_configured_host"))
			if transport_ok:
				_transition(ConnectionState.CONNECTED, "P1-N3 TCP transport connecting/connected")
				last_error = "Real DOL protocol framing/login is not implemented after TCP transport. Use simulation until P1-N4."
				last_action = "real_protocol_not_implemented"
				_append_event("login_refused", {"reason": last_error, "account": account_name, "transport": true})
				_transition(ConnectionState.ERROR, last_error)
				return false
			last_error = "P1-N3 TCP transport could not start; check host/port or keep simulation enabled."
			last_action = "transport_connect_failed"
			_append_event("login_refused", {"reason": last_error, "account": account_name, "transport": false})
			_transition(ConnectionState.ERROR, last_error)
			return false
		last_error = "Real DOL socket/protocol is not implemented before P1-N3 transport is attached. Use simulation."
		last_action = "real_login_not_implemented"
		_append_event("login_refused", {"reason": last_error, "account": account_name})
		_transition(ConnectionState.ERROR, last_error)
		return false
	_transition(ConnectionState.CONNECTING, "simulate connect")
	_record_packet("client", "CONNECT_STUB", {"host": default_host, "port": default_port})
	_transition(ConnectionState.CONNECTED, "simulate connected")
	_transition(ConnectionState.LOGGING_IN, "simulate login request")
	_record_packet("client", "LOGIN_REQUEST_STUB", {"account": account_name})
	session_id = "SIM-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec() % 100000]
	_record_packet("server", "LOGIN_OK_STUB", {"session_id": session_id})
	_transition(ConnectionState.LOGIN_OK, "simulate login ok")
	return true


func request_charlist() -> bool:
	if state < ConnectionState.LOGIN_OK:
		last_error = "charlist requires LOGIN_OK"
		last_action = "charlist_rejected"
		_append_event("charlist_rejected", {"state": get_state_name()})
		return false
	_transition(ConnectionState.LOGIN_OK, "request charlist")
	_record_packet("client", "CHARLIST_REQUEST_STUB", {"session_id": session_id})
	charlist = _build_debug_charlist()
	_record_packet("server", "CHARLIST_RESPONSE_STUB", {"count": charlist.size()})
	_transition(ConnectionState.CHARLIST_READY, "charlist ready")
	return true


func enter_world(character_index: int = 0) -> bool:
	if state < ConnectionState.CHARLIST_READY:
		if not request_charlist():
			return false
	if charlist.is_empty():
		last_error = "no characters available"
		last_action = "enter_world_rejected"
		_append_event("enter_world_rejected", {"reason": last_error})
		return false
	var idx := clampi(character_index, 0, charlist.size() - 1)
	selected_character_index = idx
	selected_character = charlist[idx].duplicate(true)
	_transition(ConnectionState.ENTERING_WORLD, "enter world request")
	_record_packet("client", "ENTER_WORLD_REQUEST_STUB", {"slot": idx, "name": selected_character.get("name", "")})
	var loc := _local_player_location_snapshot()
	selected_character["enter_world_local_snapshot"] = loc
	_record_packet("server", "ENTER_WORLD_OK_STUB", loc)
	last_position_snapshot = capture_local_position_snapshot("enter_world")
	last_position_ack_snapshot.clear()
	last_region_id = int(last_position_snapshot.get("region_id", -1))
	last_zone_id = int(last_position_snapshot.get("zone", -1))
	_transition(ConnectionState.IN_WORLD, "in world")
	return true


func disconnect_from_server(reason: String = "local disconnect") -> bool:
	_record_packet("client", "DISCONNECT_STUB", {"reason": reason})
	selected_character_index = -1
	selected_character.clear()
	session_id = ""
	last_position_snapshot.clear()
	last_position_ack_snapshot.clear()
	last_heading_snapshot.clear()
	last_regionchange_snapshot.clear()
	last_region_id = -1
	last_zone_id = -1
	_transition(ConnectionState.DISCONNECTED, reason)
	return true


func is_ready_for_charlist() -> bool:
	return state >= ConnectionState.LOGIN_OK and state != ConnectionState.ERROR


func is_in_world() -> bool:
	return state == ConnectionState.IN_WORLD


func capture_local_position_snapshot(reason: String = "sample") -> Dictionary:
	var loc := _local_player_location_snapshot()
	var zone := int(loc.get("zone", 0))
	var x := float(loc.get("x", 0.0))
	var y := float(loc.get("y", 0.0))
	var z := float(loc.get("z", 0.0))
	var heading_deg := float(loc.get("heading_deg", 0.0))
	var region_id := _derive_region_id(zone)
	return {
		"scope": "P1-N2 position-heading-regionchange skeleton",
		"reason": reason,
		"msec": Time.get_ticks_msec(),
		"zone": zone,
		"region_id": region_id,
		"sector_x": _sector_index_from_coord(x),
		"sector_y": _sector_index_from_coord(y),
		"x": x,
		"y": y,
		"z": z,
		"heading_deg": heading_deg,
		"heading_units": heading_deg_to_daoc_units(heading_deg),
		"movement_state": _player_movement_state_name(),
		"in_world": is_in_world(),
	}


func send_position_update_stub(reason: String = "manual") -> bool:
	if not is_in_world():
		last_error = "position update requires IN_WORLD"
		last_action = "position_update_rejected"
		_append_event("position_rejected", {"state": get_state_name(), "reason": reason})
		return false
	position_sequence += 1
	var snap := capture_local_position_snapshot(reason)
	snap["sequence"] = position_sequence
	last_position_snapshot = snap.duplicate(true)
	_record_packet("client", "POSITION_UPDATE_STUB", _compact_position_payload(snap))
	last_position_ack_snapshot = {
		"sequence": position_sequence,
		"accepted": true,
		"zone": int(snap.get("zone", 0)),
		"region_id": int(snap.get("region_id", 0)),
		"heading_units": int(snap.get("heading_units", 0)),
		"msec": Time.get_ticks_msec(),
	}
	_record_packet("server", "POSITION_ACK_STUB", last_position_ack_snapshot)
	last_action = "position update stub"
	return true


func send_heading_update_stub(reason: String = "manual") -> bool:
	if not is_in_world():
		last_error = "heading update requires IN_WORLD"
		last_action = "heading_update_rejected"
		_append_event("heading_rejected", {"state": get_state_name(), "reason": reason})
		return false
	heading_sequence += 1
	var snap := capture_local_position_snapshot(reason)
	last_heading_snapshot = {
		"sequence": heading_sequence,
		"zone": int(snap.get("zone", 0)),
		"region_id": int(snap.get("region_id", 0)),
		"heading_deg": float(snap.get("heading_deg", 0.0)),
		"heading_units": int(snap.get("heading_units", 0)),
		"msec": Time.get_ticks_msec(),
	}
	_record_packet("client", "HEADING_UPDATE_STUB", last_heading_snapshot)
	last_action = "heading update stub"
	return true


func simulate_regionchange_stub(target_zone: int = -1, target_region_id: int = -1, reason: String = "manual") -> bool:
	if not is_in_world():
		last_error = "regionchange requires IN_WORLD"
		last_action = "regionchange_rejected"
		_append_event("regionchange_rejected", {"state": get_state_name(), "reason": reason})
		return false
	regionchange_sequence += 1
	var current := capture_local_position_snapshot(reason)
	var old_zone := last_zone_id if last_zone_id >= 0 else int(current.get("zone", 0))
	var old_region := last_region_id if last_region_id >= 0 else int(current.get("region_id", 0))
	var new_zone := int(current.get("zone", 0)) if target_zone < 0 else target_zone
	var new_region := _derive_region_id(new_zone) if target_region_id < 0 else target_region_id
	last_regionchange_snapshot = {
		"sequence": regionchange_sequence,
		"reason": reason,
		"old_zone": old_zone,
		"new_zone": new_zone,
		"old_region_id": old_region,
		"new_region_id": new_region,
		"local_position": _compact_position_payload(current),
		"msec": Time.get_ticks_msec(),
	}
	last_zone_id = new_zone
	last_region_id = new_region
	_record_packet("client", "REGIONCHANGE_REQUEST_STUB", last_regionchange_snapshot)
	_record_packet("server", "REGIONCHANGE_OK_STUB", {
		"sequence": regionchange_sequence,
		"zone": new_zone,
		"region_id": new_region,
	})
	last_action = "regionchange stub"
	return true


const DaocHeadingScript = preload("res://src/daoc/world/DaocHeading.gd")


## P1-112 : conversions par DaocHeading (cap DOL 0 = +Y, moteur 0 = +X).
func heading_deg_to_daoc_units(deg: float) -> int:
	return DaocHeadingScript.motor_deg_to_raw(deg)


func heading_units_to_deg(units: int) -> float:
	return DaocHeadingScript.raw_to_motor_deg(units)


func get_state_name() -> String:
	return state_name_for_value(state)


func state_name_for_value(value: int) -> String:
	match int(value):
		ConnectionState.OFFLINE:
			return "OFFLINE"
		ConnectionState.DISCONNECTED:
			return "DISCONNECTED"
		ConnectionState.CONNECTING:
			return "CONNECTING"
		ConnectionState.CONNECTED:
			return "CONNECTED"
		ConnectionState.LOGGING_IN:
			return "LOGGING_IN"
		ConnectionState.LOGIN_OK:
			return "LOGIN_OK"
		ConnectionState.CHARLIST_READY:
			return "CHARLIST_READY"
		ConnectionState.ENTERING_WORLD:
			return "ENTERING_WORLD"
		ConnectionState.IN_WORLD:
			return "IN_WORLD"
		ConnectionState.ERROR:
			return "ERROR"
	return "UNKNOWN"


func get_connection_state_for_restore() -> Dictionary:
	return {
		"state": state,
		"last_error": last_error,
		"last_action": last_action,
		"session_id": session_id,
		"account_name": account_name,
		"selected_character_index": selected_character_index,
		"selected_character": selected_character.duplicate(true),
		"charlist": _duplicate_array_of_dicts(charlist),
		"event_log": _duplicate_array_of_dicts(event_log),
		"packet_flow": _duplicate_array_of_dicts(packet_flow),
		"last_position_snapshot": last_position_snapshot.duplicate(true),
		"last_position_ack_snapshot": last_position_ack_snapshot.duplicate(true),
		"last_heading_snapshot": last_heading_snapshot.duplicate(true),
		"last_regionchange_snapshot": last_regionchange_snapshot.duplicate(true),
		"position_sequence": position_sequence,
		"heading_sequence": heading_sequence,
		"regionchange_sequence": regionchange_sequence,
		"last_region_id": last_region_id,
		"last_zone_id": last_zone_id,
		"login_started_msec": login_started_msec,
		"last_transition_msec": last_transition_msec,
	}


func restore_connection_state(saved: Dictionary) -> void:
	state = int(saved.get("state", ConnectionState.DISCONNECTED))
	last_error = str(saved.get("last_error", ""))
	last_action = str(saved.get("last_action", "restore"))
	session_id = str(saved.get("session_id", ""))
	account_name = str(saved.get("account_name", ""))
	selected_character_index = int(saved.get("selected_character_index", -1))
	selected_character = (saved.get("selected_character", {}) as Dictionary).duplicate(true)
	charlist = _duplicate_array_of_dicts(saved.get("charlist", []) as Array)
	event_log = _duplicate_array_of_dicts(saved.get("event_log", []) as Array)
	packet_flow = _duplicate_array_of_dicts(saved.get("packet_flow", []) as Array)
	last_position_snapshot = (saved.get("last_position_snapshot", {}) as Dictionary).duplicate(true)
	last_position_ack_snapshot = (saved.get("last_position_ack_snapshot", {}) as Dictionary).duplicate(true)
	last_heading_snapshot = (saved.get("last_heading_snapshot", {}) as Dictionary).duplicate(true)
	last_regionchange_snapshot = (saved.get("last_regionchange_snapshot", {}) as Dictionary).duplicate(true)
	position_sequence = int(saved.get("position_sequence", 0))
	heading_sequence = int(saved.get("heading_sequence", 0))
	regionchange_sequence = int(saved.get("regionchange_sequence", 0))
	last_region_id = int(saved.get("last_region_id", -1))
	last_zone_id = int(saved.get("last_zone_id", -1))
	login_started_msec = int(saved.get("login_started_msec", 0))
	last_transition_msec = int(saved.get("last_transition_msec", Time.get_ticks_msec()))


func get_network_debug_snapshot() -> Dictionary:
	return {
		"enabled": true,
		"scope": "P1-N1/P1-N2 DOL skeleton",
		"simulated": simulate_by_default,
		"real_socket_implemented": false,
		"host": default_host,
		"port": default_port,
		"state": state,
		"state_name": get_state_name(),
		"last_action": last_action,
		"last_error": last_error,
		"account": account_name,
		"session_id_present": session_id != "",
		"char_count": charlist.size(),
		"selected_character_index": selected_character_index,
		"selected_character": _compact_character_snapshot(selected_character),
		"event_log_size": event_log.size(),
		"event_log_tail": _compact_event_tail(5),
		"packet_flow_size": packet_flow.size(),
		"packet_flow_tail": _compact_packet_tail(6),
		"transport": get_p1_n3_debug_snapshot(),
		"packet_layer": get_p1_n4_debug_snapshot(),
		"wire_1127": get_p1_n5a_debug_snapshot(),
		"login_flow_1127": get_p1_n5b_debug_snapshot(),
		"server_fixtures_1127": get_p1_n5d_debug_snapshot(),
		"character_bootstrap_1127": get_p1_n5efg_debug_snapshot(),
		"character_select_hud_1127": get_p1_n5hij_debug_snapshot(),
		"p1_n6b_apply_guard": get_p1_n6b_debug_snapshot(),
		"p1_n6c_login_selection_flow": get_p1_n6c_debug_snapshot(),
	}


func get_protocol_stage_snapshot() -> Dictionary:
	return {
		"stages": ["DISCONNECTED", "CONNECTING", "CONNECTED", "LOGGING_IN", "LOGIN_OK", "CHARLIST_READY", "ENTERING_WORLD", "IN_WORLD"],
		"current": get_state_name(),
		"login_ok": state >= ConnectionState.LOGIN_OK and state != ConnectionState.ERROR,
		"charlist_ready": state >= ConnectionState.CHARLIST_READY and state != ConnectionState.ERROR,
		"in_world": state == ConnectionState.IN_WORLD,
	}


func get_authority_boundary_snapshot() -> Dictionary:
	return {
		"client_local": ["input", "camera", "HUD debug", "local motor prediction/feel", "local targeting debug"],
		"server_authority_future": ["account auth", "character list", "enter world approval", "position authority", "combat", "spells", "items", "realm/state"],
		"mixed_future": ["position snapshots", "heading", "regionchange", "animation feedback", "cast/combat UI feedback"],
		"p1_n1_scope": ["login state machine", "charlist snapshot", "enter-world state", "debug commands", "F12 validation"],
		"p1_n2_scope": ["position snapshot", "heading units", "regionchange stub", "packet flow debug", "server authority boundary"],
		"p1_n3_scope": ["isolated TCP transport", "host/port guard", "poll/send/read/close wrappers", "function log", "simulation fallback"],
		"p1_n4_scope": ["packet/framing helper layer", "opcode registry", "encode/decode stubs", "receive buffer", "checksum/log/snapshot", "one F12 test per public function"],
		"p1_n5a_scope": ["DOL wire 1127 offline", "client packet header 12 bytes", "DOL checksum", "version probe", "no live socket"],
		"p1_n5b_scope": ["offline client login flow", "LoginRequest", "CharacterOverviewRequest", "CharacterSelectRequest", "WorldInitRequest", "no live socket"],
		"p1_n5c_deferred": ["TCP guarded send requires DOL server launched", "skipped until local server can run safely"],
		"p1_n5d_scope": ["offline server response fixtures", "GSTCPPacketOut 3-byte header", "LoginGranted", "SessionID", "Realm", "CharacterOverview1126", "PositionAndObjectID"],
		"p1_n5hij_scope": ["character select text HUD", "normalized character model", "selection phase", "offline bootstrap apply dry/real command"],
	}


func get_packet_flow_debug_snapshot() -> Dictionary:
	return {
		"simulated": simulate_by_default,
		"count": packet_flow.size(),
		"tail": _compact_packet_tail(8),
	}


func get_position_sync_debug_snapshot() -> Dictionary:
	var current := capture_local_position_snapshot("debug")
	return {
		"scope": "P1-N2 position-heading-regionchange skeleton",
		"in_world": is_in_world(),
		"position_sequence": position_sequence,
		"heading_sequence": heading_sequence,
		"current": _compact_position_payload(current),
		"last_sent": _compact_position_payload(last_position_snapshot),
		"last_ack": last_position_ack_snapshot.duplicate(true),
		"last_heading": last_heading_snapshot.duplicate(true),
	}


func get_regionchange_debug_snapshot() -> Dictionary:
	return {
		"scope": "P1-N2 regionchange skeleton",
		"sequence": regionchange_sequence,
		"last_zone_id": last_zone_id,
		"last_region_id": last_region_id,
		"last": last_regionchange_snapshot.duplicate(true),
	}


func get_p1_n2_debug_snapshot() -> Dictionary:
	return {
		"position": get_position_sync_debug_snapshot(),
		"regionchange": get_regionchange_debug_snapshot(),
		"packet_flow": get_packet_flow_debug_snapshot(),
	}


func poll_transport() -> bool:
	if transport != null and transport.has_method("poll_transport"):
		return bool(transport.call("poll_transport"))
	last_error = "transport missing"
	_append_event("transport_poll_missing", {"reason": last_error})
	return false


func get_p1_n3_debug_snapshot() -> Dictionary:
	if transport != null and transport.has_method("get_transport_debug_snapshot"):
		return {
			"scope": "P1-N3 DOL TCP transport preparatoire",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"real_protocol_implemented": false,
			"transport": transport.call("get_transport_debug_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N3 DOL TCP transport preparatoire",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"real_protocol_implemented": false,
		"transport": {"enabled": false, "status_name": "MISSING"},
	}


func get_p1_n4_debug_snapshot() -> Dictionary:
	if packet_layer != null and packet_layer.has_method("status_snapshot"):
		return {
			"scope": "P1-N4 DOL packet/framing preparatoire",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"real_protocol_implemented": false,
			"packet_layer": packet_layer.call("status_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N4 DOL packet/framing preparatoire",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"real_protocol_implemented": false,
		"packet_layer": {"scope": "P1-N4 packet/framing preparatoire", "status_name": "MISSING"},
	}


func get_p1_n5a_debug_snapshot() -> Dictionary:
	if wire_1127 != null and wire_1127.has_method("status_snapshot"):
		return {
			"scope": "P1-N5A DOL wire 1127 offline",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"real_login_implemented": false,
			"wire": wire_1127.call("status_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N5A DOL wire 1127 offline",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"real_login_implemented": false,
		"wire": {"status_name": "MISSING"},
	}



func get_p1_n5b_debug_snapshot() -> Dictionary:
	if login_flow_1127 != null and login_flow_1127.has_method("status_snapshot"):
		return {
			"scope": "P1-N5B DOL login flow 1127 offline",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"real_network_send_enabled": false,
			"flow": login_flow_1127.call("status_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N5B DOL login flow 1127 offline",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"real_network_send_enabled": false,
		"flow": {"status_name": "MISSING"},
	}


func get_p1_n5d_debug_snapshot() -> Dictionary:
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("status_snapshot"):
		return {
			"scope": "P1-N5D DOL server response fixtures 1127 offline",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"live_server_required": false,
			"fixtures": server_fixtures_1127.call("status_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N5D DOL server response fixtures 1127 offline",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"live_server_required": false,
		"fixtures": {"status_name": "MISSING"},
	}


func get_p1_n5efg_debug_snapshot() -> Dictionary:
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("status_snapshot"):
		return {
			"scope": "P1-N5E/F/G DOL character overview/select/bootstrap offline",
			"attached": true,
			"simulation_fallback": simulate_by_default,
			"live_server_required": false,
			"real_ui_implemented": false,
			"bootstrap": character_bootstrap_1127.call("status_snapshot") as Dictionary,
		}
	return {
		"scope": "P1-N5E/F/G DOL character overview/select/bootstrap offline",
		"attached": false,
		"simulation_fallback": simulate_by_default,
		"live_server_required": false,
		"real_ui_implemented": false,
		"bootstrap": {"status_name": "MISSING"},
	}



func import_bootstrap_charlist_to_client() -> Array:
	if character_bootstrap_1127 == null:
		last_error = "character bootstrap missing"
		return []
	if not character_bootstrap_1127.has_method("build_character_overview_enriched_packet_1127"):
		last_error = "character bootstrap charlist builder missing"
		return []
	var packet: PackedByteArray = character_bootstrap_1127.call("build_character_overview_enriched_packet_1127", {}, 1) as PackedByteArray
	var chars: Array = character_bootstrap_1127.call("character_list_from_overview_packet", packet, 1) as Array
	charlist = _duplicate_array_of_dicts(chars)
	character_select_phase = "CHARLIST_READY"
	_append_event("p1_n5hij_charlist_import", {"count": charlist.size()})
	return _duplicate_array_of_dicts(charlist)


func choose_bootstrap_character(index: int = 0) -> Dictionary:
	var chars := charlist
	if chars.is_empty():
		chars = import_bootstrap_charlist_to_client()
	if character_bootstrap_1127 == null or not character_bootstrap_1127.has_method("select_character_by_index"):
		last_error = "character bootstrap select missing"
		return {}
	var selected: Dictionary = character_bootstrap_1127.call("select_character_by_index", chars, index) as Dictionary
	if selected.is_empty():
		last_error = "character index not found"
		return {}
	selected_character = selected.duplicate(true)
	selected_character_index = int(selected.get("index", index))
	character_select_phase = "CHARACTER_SELECTED"
	_append_event("p1_n5hij_choose", {"index": selected_character_index, "name": str(selected.get("name", ""))})
	return selected.duplicate(true)


func unchoose_bootstrap_character() -> bool:
	selected_character.clear()
	selected_character_index = -1
	character_select_phase = "CHARLIST_READY" if charlist.size() > 0 else "NONE"
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("clear_selection"):
		character_bootstrap_1127.call("clear_selection")
	_append_event("p1_n5hij_unchoose", {})
	return true


func selected_bootstrap_character_snapshot() -> Dictionary:
	return selected_character.duplicate(true)


func mark_bootstrap_ready_from_selected() -> Dictionary:
	if selected_character.is_empty():
		choose_bootstrap_character(0)
	if selected_character.is_empty():
		last_error = "no selected character"
		return {"ready": false, "reason": last_error}
	var ready := {"ready": true, "selected": selected_character.duplicate(true), "phase": "BOOTSTRAP_READY"}
	if character_bootstrap_1127 != null and character_bootstrap_1127.has_method("bootstrap_ready_snapshot"):
		ready = character_bootstrap_1127.call("bootstrap_ready_snapshot") as Dictionary
	character_select_phase = "BOOTSTRAP_READY"
	_append_event("p1_n5hij_bootstrap_ready", {"ready": bool(ready.get("ready", false))})
	return ready


func apply_bootstrap_to_player_offline(apply_real: bool = false) -> Dictionary:
	if selected_character.is_empty():
		choose_bootstrap_character(0)
	if character_bootstrap_1127 == null or not character_bootstrap_1127.has_method("apply_bootstrap_to_player"):
		last_error = "character bootstrap apply missing"
		return {"ok": false, "reason": last_error}
	var snap: Dictionary = character_bootstrap_1127.call("apply_bootstrap_to_player", player, apply_real, "dol_client") as Dictionary
	last_bootstrap_apply_snapshot = snap.duplicate(true)
	character_select_phase = "BOOTSTRAP_APPLIED_LOCAL" if bool(snap.get("would_move_player", false)) else "BOOTSTRAP_DRY_RUN"
	_append_event("p1_n6a_applybootstrap", {"mode": str(snap.get("apply_mode", "?")), "would_move_player": bool(snap.get("would_move_player", false))})
	return snap


func apply_bootstrap_to_player_safe_real(confirm_real: bool = false, reason: String = "dol_client") -> Dictionary:
	if selected_character.is_empty():
		choose_bootstrap_character(0)
	if character_bootstrap_1127 == null or not character_bootstrap_1127.has_method("apply_bootstrap_to_player_guarded"):
		last_error = "character bootstrap guarded apply missing"
		return {"ok": false, "handled": false, "reason": last_error}
	var snap: Dictionary = character_bootstrap_1127.call("apply_bootstrap_to_player_guarded", player, confirm_real, reason) as Dictionary
	last_bootstrap_safe_apply_snapshot = snap.duplicate(true)
	last_bootstrap_apply_snapshot = snap.duplicate(true)
	if bool(snap.get("ok", false)) and bool(snap.get("would_move_player", false)):
		character_select_phase = "BOOTSTRAP_REAL_APPLIED_GUARDED"
	elif bool(snap.get("guard_denied", false)):
		character_select_phase = "BOOTSTRAP_REAL_DENIED_NEEDS_CONFIRM"
	else:
		character_select_phase = "BOOTSTRAP_REAL_APPLY_FAILED"
	_append_event("p1_n6b_applybootstrap_guarded", {"ok": bool(snap.get("ok", false)), "confirm": confirm_real, "phase": character_select_phase})
	return snap


func rollback_last_bootstrap_apply(reason: String = "dol_client") -> Dictionary:
	if character_bootstrap_1127 == null or not character_bootstrap_1127.has_method("rollback_last_player_apply"):
		last_error = "character bootstrap rollback missing"
		return {"ok": false, "handled": false, "reason": last_error}
	var snap: Dictionary = character_bootstrap_1127.call("rollback_last_player_apply", player, reason) as Dictionary
	last_bootstrap_rollback_snapshot = snap.duplicate(true)
	if bool(snap.get("ok", false)):
		character_select_phase = "BOOTSTRAP_ROLLED_BACK"
	else:
		character_select_phase = "BOOTSTRAP_ROLLBACK_FAILED"
	_append_event("p1_n6b_rollbackbootstrap", {"ok": bool(snap.get("ok", false)), "phase": character_select_phase})
	return snap


func get_p1_n6b_debug_snapshot() -> Dictionary:
	var guard := {"status_name": "MISSING"}
	var can_rollback := false
	if character_bootstrap_1127 != null:
		if character_bootstrap_1127.has_method("build_apply_guard_snapshot"):
			guard = character_bootstrap_1127.call("build_apply_guard_snapshot", player) as Dictionary
		if character_bootstrap_1127.has_method("can_rollback_last_apply"):
			can_rollback = bool(character_bootstrap_1127.call("can_rollback_last_apply"))
	return {
		"scope": "P1-N6B offline guarded real bootstrap apply + rollback",
		"attached": character_bootstrap_1127 != null,
		"live_server_required": false,
		"real_network_send_enabled": false,
		"safe_real_requires_confirm": true,
		"phase": character_select_phase,
		"can_rollback": can_rollback,
		"guard": guard,
		"last_safe_apply": last_bootstrap_safe_apply_snapshot.duplicate(true),
		"last_rollback": last_bootstrap_rollback_snapshot.duplicate(true),
	}


func p1_n6b_scope() -> String:
	return "P1-N6B offline: explicit confirmed real apply, pre-apply snapshot, rollback; no DOL live socket."


func get_character_selection_phase_snapshot() -> Dictionary:
	return {
		"scope": "P1-N5J character selection state offline",
		"phase": character_select_phase,
		"char_count": charlist.size(),
		"selected_character_index": selected_character_index,
		"selected_character": selected_character.duplicate(true),
		"last_bootstrap_apply": last_bootstrap_apply_snapshot.duplicate(true),
		"last_safe_apply": last_bootstrap_safe_apply_snapshot.duplicate(true),
		"last_rollback": last_bootstrap_rollback_snapshot.duplicate(true),
	}


func get_p1_n5hij_debug_snapshot() -> Dictionary:
	var hud_snap := {"status_name": "MISSING"}
	if character_select_hud_1127 != null and character_select_hud_1127.has_method("status_snapshot"):
		hud_snap = character_select_hud_1127.call("status_snapshot") as Dictionary
	return {
		"scope": "P1-N5H/I/J + P1-N6A offline character select HUD/model/state/apply",
		"attached": character_select_hud_1127 != null,
		"simulation_fallback": simulate_by_default,
		"live_server_required": false,
		"real_ui_final": false,
		"real_network_send_enabled": false,
		"selection_phase": get_character_selection_phase_snapshot(),
		"hud": hud_snap,
		"p1_n6b": get_p1_n6b_debug_snapshot(),
	}


func p1_n5hij_scope() -> String:
	return "P1-N5H/I/J + P1-N6A offline: text HUD, normalized character model, client selection phase, dry/explicit bootstrap apply."


func set_login_selection_ui_phase(phase: String) -> Dictionary:
	if character_select_hud_1127 == null or not character_select_hud_1127.has_method("set_ui_phase"):
		return {"ok": false, "reason": "character select HUD missing", "phase": phase}
	var snap: Dictionary = character_select_hud_1127.call("set_ui_phase", phase) as Dictionary
	_append_event("p1_n6c_ui_phase", {"phase": str(snap.get("ui_phase", phase))})
	return snap


func select_login_realm_offline(realm_value) -> Dictionary:
	if character_select_hud_1127 == null or not character_select_hud_1127.has_method("select_realm"):
		return {"ok": false, "reason": "character select HUD missing", "realm": str(realm_value)}
	var snap: Dictionary = character_select_hud_1127.call("select_realm", realm_value) as Dictionary
	if bool(snap.get("ok", false)):
		_append_event("p1_n6c_realm_selected", {"realm": snap.get("realm", {})})
	return snap


func get_p1_n6d_debug_snapshot() -> Dictionary:
	var resolver_status := {"status_name": "MISSING"}
	var audit_summary := {"status_name": "MISSING", "report_is_compact": true}
	var audit_line := "P1-N6D assets missing"
	if pregame_loading_asset_resolver != null:
		if pregame_loading_asset_resolver.has_method("status_snapshot"):
			resolver_status = pregame_loading_asset_resolver.call("status_snapshot") as Dictionary
		if pregame_loading_asset_resolver.has_method("build_audit_summary_snapshot"):
			audit_summary = pregame_loading_asset_resolver.call("build_audit_summary_snapshot", 1, -1, -1, "dol_snapshot") as Dictionary
		if pregame_loading_asset_resolver.has_method("build_audit_compact_line"):
			audit_line = str(pregame_loading_asset_resolver.call("build_audit_compact_line", 1, -1, -1, "dol_snapshot"))
	return {
		"scope": "P1-N6D offline pregame/loading asset source resolver",
		"attached": pregame_loading_asset_resolver != null,
		"live_server_required": false,
		"real_network_send_enabled": false,
		"real_ui_final": false,
		"no_runtime_import": true,
		"rule_confirmed": false,
		"report_is_compact": true,
		"resolver": resolver_status,
		"audit_line": audit_line,
		"audit_summary": audit_summary,
	}


func p1_n6d_scope() -> String:
	return "P1-N6D offline: DOL client bridge exposes pregame/loading asset resolver audit only; no network and no final visual rule."


func get_p1_n6c_debug_snapshot() -> Dictionary:
	var hud_snap := {"status_name": "MISSING"}
	var model := {"status_name": "MISSING"}
	if character_select_hud_1127 != null:
		if character_select_hud_1127.has_method("status_snapshot"):
			hud_snap = character_select_hud_1127.call("status_snapshot") as Dictionary
		if character_select_hud_1127.has_method("build_login_selection_flow_model"):
			model = character_select_hud_1127.call("build_login_selection_flow_model") as Dictionary
	return {
		"scope": "P1-N6C offline DAoC login UI flow: pregame loading -> realm -> character -> Data/loading world loading",
		"attached": character_select_hud_1127 != null,
		"live_server_required": false,
		"real_network_send_enabled": false,
		"real_ui_final": false,
		"flow_matches_daoc_order": true,
		"hud": hud_snap,
		"model": model,
		"p1_n6d": get_p1_n6d_debug_snapshot(),
	}


func p1_n6c_scope() -> String:
	return "P1-N6C offline: DAoC-like post-login UI order is pregame loading, realm selection, character selection/3D scene, then post-character Data/loading world loading; no live network."


func debug_compact_string() -> String:
	return "dol=%s sim=%s chars=%d world=%s pos=%d region=%d last=%s" % [
		get_state_name(), str(simulate_by_default), charlist.size(), str(is_in_world()), position_sequence, regionchange_sequence, last_action
	]


func _transition(new_state: int, reason: String) -> void:
	var old := state
	state = int(new_state)
	last_action = reason
	last_transition_msec = Time.get_ticks_msec()
	_append_event("state", {"from": state_name_for_value(old), "to": get_state_name(), "reason": reason})
	if debug_network:
		print("DOL P1-N1 %s -> %s : %s" % [state_name_for_value(old), get_state_name(), reason])
	if old != state:
		state_changed.emit(old, state, reason)


func _append_event(kind: String, data: Dictionary) -> void:
	event_log.append({
		"msec": Time.get_ticks_msec(),
		"kind": kind,
		"data": data.duplicate(true),
	})
	if event_log.size() > 64:
		event_log = event_log.slice(event_log.size() - 64, event_log.size())


func _record_packet(direction: String, opcode: String, payload: Dictionary) -> void:
	packet_flow.append({
		"msec": Time.get_ticks_msec(),
		"direction": direction,
		"opcode": opcode,
		"payload": payload.duplicate(true),
	})
	if packet_flow.size() > 64:
		packet_flow = packet_flow.slice(packet_flow.size() - 64, packet_flow.size())


func _build_debug_charlist() -> Array:
	var loc := _local_player_location_snapshot()
	var out: Array = []
	out.append({
		"slot": 0,
		"id": 1,
		"name": "GodotLocalDebug",
		"realm": "Albion",
		"race": "Debug",
		"class": "LocalClient",
		"level": 1,
		"zone": int(loc.get("zone", 0)),
		"x": float(loc.get("x", 32768.0)),
		"y": float(loc.get("y", 32768.0)),
		"z": float(loc.get("z", 0.0)),
		"heading_deg": float(loc.get("heading_deg", 0.0)),
		"source": "P1-N1 simulated charlist",
	})
	return out


func _local_player_location_snapshot() -> Dictionary:
	if player != null:
		return {
			"zone": int(player.get("daoc_zone")),
			"x": float(player.get("daoc_x")),
			"y": float(player.get("daoc_y")),
			"z": float(player.get("daoc_z")),
			"heading_deg": float(player.get("heading_deg")),
		}
	return {"zone": 0, "x": 32768.0, "y": 32768.0, "z": 0.0, "heading_deg": 0.0}


func _compact_character_snapshot(ch: Dictionary) -> Dictionary:
	if ch.is_empty():
		return {}
	var out := {
		"slot": int(ch.get("slot", -1)),
		"id": int(ch.get("id", 0)),
		"name": str(ch.get("name", "")),
		"realm": str(ch.get("realm", "")),
		"race": str(ch.get("race", "")),
		"class": str(ch.get("class", "")),
		"level": int(ch.get("level", 0)),
		"zone": int(ch.get("zone", 0)),
		"x": float(ch.get("x", 0.0)),
		"y": float(ch.get("y", 0.0)),
		"z": float(ch.get("z", 0.0)),
		"heading_deg": float(ch.get("heading_deg", 0.0)),
	}
	if ch.has("enter_world_local_snapshot"):
		out["enter_world_local_snapshot_present"] = true
	return out


func _compact_event_tail(max_count: int = 5) -> Array:
	var out: Array = []
	var start := maxi(0, event_log.size() - max_count)
	for item in event_log.slice(start, event_log.size()):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ev := item as Dictionary
		out.append({
			"msec": int(ev.get("msec", 0)),
			"kind": str(ev.get("kind", "")),
			"data": _compact_payload(ev.get("data", {}) as Dictionary),
		})
	return out


func _compact_packet_tail(max_count: int = 8) -> Array:
	var out: Array = []
	var start := maxi(0, packet_flow.size() - max_count)
	for item in packet_flow.slice(start, packet_flow.size()):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var pkt := item as Dictionary
		out.append({
			"msec": int(pkt.get("msec", 0)),
			"direction": str(pkt.get("direction", "")),
			"opcode": str(pkt.get("opcode", "")),
			"payload": _compact_payload(pkt.get("payload", {}) as Dictionary),
		})
	return out


func _compact_payload(payload: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in payload.keys():
		var k := str(key)
		if k == "session_id":
			out["session_id_present"] = str(payload.get(key, "")) != ""
		elif typeof(payload[key]) == TYPE_DICTIONARY:
			out[k + "_present"] = not (payload[key] as Dictionary).is_empty()
		else:
			out[k] = payload[key]
	return out

func _compact_position_payload(pos: Dictionary) -> Dictionary:
	if pos.is_empty():
		return {}
	return {
		"zone": int(pos.get("zone", 0)),
		"region_id": int(pos.get("region_id", _derive_region_id(int(pos.get("zone", 0))))),
		"sector_x": int(pos.get("sector_x", _sector_index_from_coord(float(pos.get("x", 0.0))))),
		"sector_y": int(pos.get("sector_y", _sector_index_from_coord(float(pos.get("y", 0.0))))),
		"x": float(pos.get("x", 0.0)),
		"y": float(pos.get("y", 0.0)),
		"z": float(pos.get("z", 0.0)),
		"heading_deg": float(pos.get("heading_deg", 0.0)),
		"heading_units": int(pos.get("heading_units", heading_deg_to_daoc_units(float(pos.get("heading_deg", 0.0))))),
		"movement_state": str(pos.get("movement_state", "")),
	}


func _derive_region_id(zone: int) -> int:
	# P1-N2: placeholder stable. Le vrai mapping region/zone viendra du protocole DOL/Eden.
	return maxi(0, zone)


func _sector_index_from_coord(v: float) -> int:
	return clampi(int(floor(clampf(v, 0.0, 65535.0) / 8192.0)), 0, 7)


func _player_movement_state_name() -> String:
	if player != null and player.has_method("get_movement_state_name"):
		return str(player.call("get_movement_state_name"))
	return "UNKNOWN"


func _duplicate_array_of_dicts(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if typeof(item) == TYPE_DICTIONARY:
			out.append((item as Dictionary).duplicate(true))
	return out
