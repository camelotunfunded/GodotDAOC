extends Node
class_name DaocOnlineTcpTransport

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")

signal connected
signal disconnected(reason: String)
signal server_packet_received(packet: PackedByteArray)
signal transport_error(reason: String)

const STATUS_NONE := 0
const STATUS_CONNECTING := 1
const STATUS_CONNECTED := 2
const STATUS_ERROR := 3
const MAX_RECEIVE_BUFFER := 4 * 1024 * 1024

var _peer: Variant = null
var _codec: RefCounted = PacketCodecScript.new()
var _receive_buffer := PackedByteArray()
var _send_queue: Array[PackedByteArray] = []
var _send_offset := 0
var _connected_emitted := false
var _last_error := ""
var _host_label := ""
var _port := 0


func _ready() -> void:
	set_process(false)


func connect_profile(profile: Dictionary) -> Dictionary:
	if not bool(profile.get("ok", false)):
		return _fail("invalid_online_profile")
	var host := str(profile.get("host", "")).strip_edges()
	var port := int(profile.get("port", 0))
	if host == "" or port < 1 or port > 65535:
		return _fail("invalid_endpoint")
	if _peer == null:
		_peer = StreamPeerTCP.new()
	var error := int(_peer.call("connect_to_host", host, port))
	if error != OK:
		return _fail("connect_start_failed_%d" % error)
	_host_label = host
	_port = port
	_last_error = ""
	_connected_emitted = false
	set_process(true)
	return snapshot()


func queue_packet(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty():
		return {"ok": false, "error": "empty_packet"}
	_send_queue.append(packet.duplicate())
	return {"ok": true, "queued_packet_count": _send_queue.size()}


func pump_once() -> Dictionary:
	if _peer == null:
		return {"ok": false, "error": "transport_not_initialized"}
	_peer.call("poll")
	var status := int(_peer.call("get_status"))
	if status == STATUS_ERROR:
		return _fail("tcp_status_error")
	if status == STATUS_NONE:
		if _connected_emitted:
			disconnected.emit("remote_closed")
			set_process(false)
		return snapshot()
	if status == STATUS_CONNECTED and not _connected_emitted:
		_connected_emitted = true
		connected.emit()
	if status == STATUS_CONNECTED:
		_receive_available()
		_flush_send_queue()
	return snapshot()


func close(reason: String = "client_close") -> void:
	if _peer != null and _peer.has_method("disconnect_from_host"):
		_peer.call("disconnect_from_host")
	_send_queue.clear()
	_receive_buffer.clear()
	_send_offset = 0
	set_process(false)
	if _connected_emitted:
		disconnected.emit(reason)
	_connected_emitted = false


func snapshot() -> Dictionary:
	var status := STATUS_NONE if _peer == null else int(_peer.call("get_status"))
	return {
		"ok": _last_error == "",
		"status": status,
		"connected": status == STATUS_CONNECTED,
		"endpoint": "%s:%d" % [_host_label, _port] if _host_label != "" else "",
		"receive_buffer_size": _receive_buffer.size(),
		"queued_packet_count": _send_queue.size(),
		"send_offset": _send_offset,
		"last_error": _last_error,
	}


func set_peer_for_test(peer: Variant) -> void:
	_peer = peer


func _process(_delta: float) -> void:
	pump_once()


func _receive_available() -> void:
	var available := int(_peer.call("get_available_bytes"))
	while available > 0:
		var result := _peer.call("get_partial_data", min(available, 65536)) as Array
		if result.size() != 2 or int(result[0]) != OK:
			_fail("tcp_read_failed")
			return
		var chunk := result[1] as PackedByteArray
		if chunk.is_empty():
			break
		_receive_buffer.append_array(chunk)
		if _receive_buffer.size() > MAX_RECEIVE_BUFFER:
			_fail("receive_buffer_limit")
			return
		available = int(_peer.call("get_available_bytes"))
	var extracted: Dictionary = _codec.call("try_extract_server_packets", _receive_buffer) as Dictionary
	if not bool(extracted.get("ok", false)):
		_fail("invalid_server_frame")
		return
	_receive_buffer = extracted.get("remaining_buffer", PackedByteArray()) as PackedByteArray
	for raw in extracted.get("packets", []) as Array:
		server_packet_received.emit((raw as Dictionary).get("packet", PackedByteArray()) as PackedByteArray)


func _flush_send_queue() -> void:
	while not _send_queue.is_empty():
		var packet := _send_queue[0]
		var remaining := packet.slice(_send_offset, packet.size())
		var result := _peer.call("put_partial_data", remaining) as Array
		if result.size() != 2 or int(result[0]) != OK:
			_fail("tcp_write_failed")
			return
		var written := int(result[1])
		if written <= 0:
			return
		_send_offset += written
		if _send_offset >= packet.size():
			_send_queue.pop_front()
			_send_offset = 0


func _fail(reason: String) -> Dictionary:
	_last_error = reason
	set_process(false)
	transport_error.emit(reason)
	return {"ok": false, "error": reason, "snapshot": snapshot()}
