extends Node
class_name DaocDolTransport

## P1-N3: transport TCP préparatoire isolé.
## Cette classe sait préparer un StreamPeerTCP, mais le protocole DOL/Eden réel
## reste au niveau supérieur et n'est pas décodé ici.

@export var enabled: bool = false
@export var host: String = ""
@export var port: int = 0
@export var connect_timeout_msec: int = 2500
@export var debug_transport: bool = false

var owner_client: Node = null
var peer: StreamPeerTCP = null
var last_error: String = ""
var last_action: String = "init"
var connection_started_msec: int = 0
var last_poll_msec: int = 0
var sent_bytes_total: int = 0
var received_bytes_total: int = 0
var send_sequence: int = 0
var receive_sequence: int = 0
var function_log: Array = []


func setup_transport(p_owner_client: Node = null) -> void:
	owner_client = p_owner_client
	last_action = "setup_transport"
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "setup_transport", "owner": owner_client != null})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())


func configure_transport(p_host: String, p_port: int, p_enabled: bool = false, p_timeout_msec: int = 2500) -> void:
	host = p_host.strip_edges()
	port = int(p_port)
	enabled = p_enabled
	connect_timeout_msec = maxi(100, int(p_timeout_msec))
	last_error = ""
	last_action = "configure_transport"
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "configure_transport", "host": host, "port": port, "enabled": enabled, "timeout": connect_timeout_msec})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())


func can_attempt_connection() -> bool:
	var ok := enabled and host != "" and port > 0 and port <= 65535
	last_action = "can_attempt_connection"
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "can_attempt_connection", "ok": ok, "host": host, "port": port, "enabled": enabled})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return ok


func create_peer_if_needed() -> bool:
	if peer == null:
		peer = StreamPeerTCP.new()
	last_action = "create_peer_if_needed"
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "create_peer_if_needed", "has_peer": peer != null})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return peer != null


func connect_to_configured_host() -> bool:
	last_action = "connect_to_configured_host"
	if not can_attempt_connection():
		last_error = "transport disabled or host/port invalid"
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "connect_to_configured_host", "ok": false, "reason": last_error})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return false
	if not create_peer_if_needed():
		last_error = "cannot allocate StreamPeerTCP"
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "connect_to_configured_host", "ok": false, "reason": last_error})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return false
	connection_started_msec = Time.get_ticks_msec()
	var err := peer.connect_to_host(host, port)
	if err != OK:
		last_error = "connect_to_host error=%d" % int(err)
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "connect_to_configured_host", "ok": false, "error": int(err)})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return false
	last_error = ""
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "connect_to_configured_host", "ok": true, "host": host, "port": port})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return true


func poll_transport() -> bool:
	last_action = "poll_transport"
	last_poll_msec = Time.get_ticks_msec()
	if peer == null:
		function_log.append({"msec": last_poll_msec, "fn": "poll_transport", "ok": false, "reason": "no_peer"})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return false
	var err := peer.poll()
	var status := int(peer.get_status())
	if err != OK:
		last_error = "poll error=%d" % int(err)
	function_log.append({"msec": last_poll_msec, "fn": "poll_transport", "ok": err == OK, "status": status, "error": int(err)})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return err == OK


func send_raw_bytes(data: PackedByteArray, label: String = "raw") -> bool:
	last_action = "send_raw_bytes"
	if peer == null or int(peer.get_status()) != StreamPeerTCP.STATUS_CONNECTED:
		last_error = "send requires connected TCP peer"
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "send_raw_bytes", "ok": false, "label": label, "size": data.size(), "reason": last_error})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return false
	var err := peer.put_data(data)
	if err == OK:
		send_sequence += 1
		sent_bytes_total += data.size()
	else:
		last_error = "put_data error=%d" % int(err)
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "send_raw_bytes", "ok": err == OK, "label": label, "size": data.size(), "seq": send_sequence, "error": int(err)})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return err == OK


func read_available_bytes(max_bytes: int = 8192) -> PackedByteArray:
	last_action = "read_available_bytes"
	var out := PackedByteArray()
	if peer == null:
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "read_available_bytes", "ok": false, "reason": "no_peer"})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return out
	poll_transport()
	var available := int(peer.get_available_bytes())
	if available <= 0:
		function_log.append({"msec": Time.get_ticks_msec(), "fn": "read_available_bytes", "ok": true, "available": 0, "read": 0})
		if function_log.size() > 80:
			function_log = function_log.slice(function_log.size() - 80, function_log.size())
		return out
	var to_read := mini(available, maxi(1, int(max_bytes)))
	var result := peer.get_data(to_read)
	if result.size() >= 2 and int(result[0]) == OK:
		out = result[1] as PackedByteArray
		receive_sequence += 1
		received_bytes_total += out.size()
	else:
		last_error = "get_data error"
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "read_available_bytes", "ok": out.size() > 0, "available": available, "read": out.size(), "seq": receive_sequence})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return out


func close_transport(reason: String = "local close") -> bool:
	last_action = "close_transport"
	if peer != null:
		peer.disconnect_from_host()
	peer = null
	connection_started_msec = 0
	function_log.append({"msec": Time.get_ticks_msec(), "fn": "close_transport", "reason": reason})
	if function_log.size() > 80:
		function_log = function_log.slice(function_log.size() - 80, function_log.size())
	return true


func get_transport_debug_snapshot() -> Dictionary:
	var status := -1
	if peer != null:
		status = int(peer.get_status())
	var status_name := "NO_PEER"
	match status:
		StreamPeerTCP.STATUS_NONE:
			status_name = "NONE"
		StreamPeerTCP.STATUS_CONNECTING:
			status_name = "CONNECTING"
		StreamPeerTCP.STATUS_CONNECTED:
			status_name = "CONNECTED"
		StreamPeerTCP.STATUS_ERROR:
			status_name = "ERROR"
	var tail: Array = []
	var start := maxi(0, function_log.size() - 10)
	for item in function_log.slice(start, function_log.size()):
		if typeof(item) == TYPE_DICTIONARY:
			tail.append((item as Dictionary).duplicate(true))
	return {
		"scope": "P1-N3 transport TCP preparatoire",
		"enabled": enabled,
		"host": host,
		"port": port,
		"can_attempt": enabled and host != "" and port > 0 and port <= 65535,
		"status": status,
		"status_name": status_name,
		"last_action": last_action,
		"last_error": last_error,
		"sent_bytes_total": sent_bytes_total,
		"received_bytes_total": received_bytes_total,
		"send_sequence": send_sequence,
		"receive_sequence": receive_sequence,
		"function_log_size": function_log.size(),
		"function_log_tail": tail,
	}


func get_function_log_snapshot(max_count: int = 20) -> Array:
	var out: Array = []
	var start := maxi(0, function_log.size() - maxi(1, max_count))
	for item in function_log.slice(start, function_log.size()):
		if typeof(item) == TYPE_DICTIONARY:
			out.append((item as Dictionary).duplicate(true))
	return out
