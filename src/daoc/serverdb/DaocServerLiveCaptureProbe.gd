extends RefCounted
class_name DaocServerLiveCaptureProbe

const REPORT_JSON_PATH: String = "res://reports/p1_17f6_server_capture.json"
const REPORT_TEXT_PATH: String = "res://reports/p1_17f6_server_capture.txt"
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 10300
const DEFAULT_TIMEOUT_MSEC: int = 1200
const DEFAULT_POLL_COUNT: int = 10

var last_report: Dictionary = {}


func build_readiness_report(dol_client: Node = null, transport: Node = null, wire_1127: Node = null, options: Dictionary = {}) -> Dictionary:
	var host := _host_from_inputs(dol_client, transport, wire_1127, options)
	var port := _port_from_inputs(dol_client, transport, wire_1127, options)
	var transport_snapshot := _transport_snapshot(transport)
	var wire_snapshot := _wire_snapshot(wire_1127)
	var probe_packet := _version_probe_packet(wire_1127)
	var packet_summary := _packet_summary(wire_1127, probe_packet)
	var can_prepare_probe := probe_packet.size() > 0 and bool(packet_summary.get("checksum_ok", false))
	var report := {
		"checkpoint": "P1_17F6_SERVER_LIVE_CAPTURE",
		"scope": "P1-17F6 server live capture readiness",
		"ok": true,
		"msec": Time.get_ticks_msec(),
		"host": host,
		"port": port,
		"transport_attached": transport != null,
		"wire_1127_attached": wire_1127 != null,
		"dol_client_attached": dol_client != null,
		"capture_ready": transport != null and wire_1127 != null and can_prepare_probe and host != "" and port > 0,
		"live_probe_attempted": false,
		"connect_attempted": false,
		"connected": false,
		"sent_version_probe": false,
		"received_bytes": 0,
		"received_packet_count": 0,
		"received_packets": [],
		"version_probe_packet": packet_summary,
		"transport": transport_snapshot,
		"wire": wire_snapshot,
		"guardrails": _guardrails(),
		"notes": [
			"Readiness only by default; no login and no credentials.",
			"Use /servercapture probe only against a local test server.",
			"coordinate_frame_confirmed remains false until external evidence exists.",
		],
	}
	last_report = report.duplicate(true)
	return last_report.duplicate(true)


func attempt_local_probe(dol_client: Node = null, transport: Node = null, wire_1127: Node = null, options: Dictionary = {}) -> Dictionary:
	var report := build_readiness_report(dol_client, transport, wire_1127, options)
	report["live_probe_attempted"] = true
	report["connect_attempted"] = true
	report["probe_mode"] = "version_probe_only"
	if not bool(options.get("allow_network_probe", false)):
		report["ok"] = false
		report["error"] = "network probe not allowed by caller"
		last_report = report.duplicate(true)
		return last_report.duplicate(true)
	if transport == null or wire_1127 == null:
		report["ok"] = false
		report["error"] = "transport or wire layer missing"
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	var host := str(report.get("host", DEFAULT_HOST))
	var port := int(report.get("port", DEFAULT_PORT))
	var timeout_msec := int(options.get("timeout_msec", DEFAULT_TIMEOUT_MSEC))
	if transport.has_method("configure_transport"):
		transport.call("configure_transport", host, port, true, timeout_msec)
	if not transport.has_method("connect_to_configured_host") or not bool(transport.call("connect_to_configured_host")):
		report["ok"] = false
		report["error"] = "connect_to_configured_host failed"
		report["transport"] = _transport_snapshot(transport)
		_close_transport(transport, "P1-17F6 probe failed")
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	var poll_count := maxi(1, int(options.get("poll_count", DEFAULT_POLL_COUNT)))
	var poll_delay_msec := clampi(int(options.get("poll_delay_msec", 30)), 0, 250)
	var connected := false
	for _i in range(poll_count):
		if transport.has_method("poll_transport"):
			transport.call("poll_transport")
		var snap := _transport_snapshot(transport)
		if str(snap.get("status_name", "")) == "CONNECTED":
			connected = true
			break
		if poll_delay_msec > 0:
			OS.delay_msec(poll_delay_msec)
	report["connected"] = connected
	report["transport"] = _transport_snapshot(transport)
	if not connected:
		report["ok"] = false
		report["error"] = "TCP peer did not reach CONNECTED during bounded probe"
		_close_transport(transport, "P1-17F6 probe not connected")
		last_report = report.duplicate(true)
		return last_report.duplicate(true)

	var probe_packet := _version_probe_packet(wire_1127)
	if probe_packet.size() > 0 and transport.has_method("send_raw_bytes"):
		report["sent_version_probe"] = bool(transport.call("send_raw_bytes", probe_packet, "P1-17F6 1127 version probe"))

	var received := PackedByteArray()
	for _i in range(poll_count):
		if transport.has_method("read_available_bytes"):
			var chunk: PackedByteArray = transport.call("read_available_bytes", 8192) as PackedByteArray
			if chunk.size() > 0:
				received.append_array(chunk)
		if poll_delay_msec > 0:
			OS.delay_msec(poll_delay_msec)

	var rx_summary := build_received_packet_summary(wire_1127, received)
	report["received_bytes"] = received.size()
	report["received_packet_count"] = int(rx_summary.get("packet_count", 0))
	report["received_packets"] = rx_summary.get("packets", [])
	report["raw_hex_prefix"] = _bytes_to_hex(received, 96)
	report["transport"] = _transport_snapshot(transport)
	_close_transport(transport, "P1-17F6 probe complete")
	last_report = report.duplicate(true)
	return last_report.duplicate(true)


func build_received_packet_summary(wire_1127: Node, data: PackedByteArray) -> Dictionary:
	var out := {
		"ok": wire_1127 != null and data.size() > 0,
		"byte_count": data.size(),
		"packet_count": 0,
		"packets": [],
	}
	if wire_1127 == null or data.size() <= 0:
		return out
	if not wire_1127.has_method("split_dol_tcp_stream_all"):
		out["ok"] = false
		out["error"] = "wire layer cannot split stream"
		return out
	var packets: Array = wire_1127.call("split_dol_tcp_stream_all", data) as Array
	var summaries: Array = []
	for packet_value in packets:
		if typeof(packet_value) != TYPE_PACKED_BYTE_ARRAY:
			continue
		var packet: PackedByteArray = packet_value as PackedByteArray
		summaries.append(_packet_summary(wire_1127, packet))
	out["packet_count"] = summaries.size()
	out["packets"] = summaries
	return out


func export_last_report_json(path: String = REPORT_JSON_PATH) -> Dictionary:
	if last_report.is_empty():
		build_readiness_report()
	return _write_text(path, JSON.stringify(last_report, "\t"))


func export_last_report_text(path: String = REPORT_TEXT_PATH) -> Dictionary:
	if last_report.is_empty():
		build_readiness_report()
	return _write_text(path, build_text_report(last_report))


func build_text_report(report: Dictionary = {}) -> String:
	var r := report if not report.is_empty() else last_report
	var lines: Array = []
	lines.append("P1-17F6 server live capture")
	lines.append("ok=%s capture_ready=%s live_probe_attempted=%s" % [str(r.get("ok", false)), str(r.get("capture_ready", false)), str(r.get("live_probe_attempted", false))])
	lines.append("host=%s port=%d transport=%s wire1127=%s connected=%s" % [
		str(r.get("host", "")),
		int(r.get("port", 0)),
		str(r.get("transport_attached", false)),
		str(r.get("wire_1127_attached", false)),
		str(r.get("connected", false)),
	])
	var probe: Dictionary = r.get("version_probe_packet", {}) as Dictionary
	lines.append("version_probe size=%d packet_id=0x%02X checksum_ok=%s version=%d" % [
		int(probe.get("size", 0)),
		int(probe.get("packet_id", 0)),
		str(probe.get("checksum_ok", false)),
		int(probe.get("client_version", 0)),
	])
	lines.append("sent_version_probe=%s received_bytes=%d received_packets=%d" % [
		str(r.get("sent_version_probe", false)),
		int(r.get("received_bytes", 0)),
		int(r.get("received_packet_count", 0)),
	])
	if r.has("error"):
		lines.append("error=%s" % str(r.get("error", "")))
	var guard: Dictionary = r.get("guardrails", {}) as Dictionary
	lines.append("guardrails coordinate_frame_confirmed=%s runtime_enabled=%s player_spawn_applied=%s fake_gameplay=%s" % [
		str(guard.get("coordinate_frame_confirmed", true)),
		str(guard.get("runtime_enabled", true)),
		str(guard.get("player_spawn_applied", true)),
		str(guard.get("gameplay_fake", true)),
	])
	lines.append("interpretation:")
	if bool(r.get("live_probe_attempted", false)):
		if bool(r.get("connected", false)):
			lines.append("- A local TCP server answered; inspect received_packets before implementing login.")
		else:
			lines.append("- No connected local server was observed during this bounded probe.")
	else:
		lines.append("- No network probe was attempted; this is a safe readiness report.")
	lines.append("- This does not confirm the server/client coordinate frame.")
	return "\n".join(lines) + "\n"


func _host_from_inputs(dol_client: Node, transport: Node, wire_1127: Node, options: Dictionary) -> String:
	var host := str(options.get("host", "")).strip_edges()
	if host != "":
		return host
	if transport != null:
		var t_host := str(transport.get("host")).strip_edges()
		if t_host != "":
			return t_host
	if dol_client != null:
		var c_host := str(dol_client.get("default_host")).strip_edges()
		if c_host != "":
			return c_host
	if wire_1127 != null:
		var w_host := str(wire_1127.get("local_host")).strip_edges()
		if w_host != "":
			return w_host
	return DEFAULT_HOST


func _port_from_inputs(dol_client: Node, transport: Node, wire_1127: Node, options: Dictionary) -> int:
	var opt_port := int(options.get("port", 0))
	if opt_port > 0:
		return opt_port
	if transport != null and int(transport.get("port")) > 0:
		return int(transport.get("port"))
	if dol_client != null and int(dol_client.get("default_port")) > 0:
		return int(dol_client.get("default_port"))
	if wire_1127 != null and int(wire_1127.get("local_port")) > 0:
		return int(wire_1127.get("local_port"))
	return DEFAULT_PORT


func _transport_snapshot(transport: Node) -> Dictionary:
	if transport != null and transport.has_method("get_transport_debug_snapshot"):
		return transport.call("get_transport_debug_snapshot") as Dictionary
	return {"status_name": "MISSING", "enabled": false, "can_attempt": false}


func _wire_snapshot(wire_1127: Node) -> Dictionary:
	if wire_1127 != null and wire_1127.has_method("status_snapshot"):
		return wire_1127.call("status_snapshot") as Dictionary
	return {"status_name": "MISSING", "real_login_implemented": false}


func _version_probe_packet(wire_1127: Node) -> PackedByteArray:
	if wire_1127 != null and wire_1127.has_method("build_version_probe_1127_packet"):
		return wire_1127.call("build_version_probe_1127_packet") as PackedByteArray
	return PackedByteArray()


func _packet_summary(wire_1127: Node, packet: PackedByteArray) -> Dictionary:
	if packet.size() <= 0:
		return {"ok": false, "size": 0}
	var out := {
		"ok": true,
		"size": packet.size(),
		"hex_prefix": _bytes_to_hex(packet, 64),
	}
	if wire_1127 != null:
		if wire_1127.has_method("parse_gspacket_12"):
			var parsed: Dictionary = wire_1127.call("parse_gspacket_12", packet) as Dictionary
			out["packet_id"] = int(parsed.get("packet_id", -1))
			out["data_size"] = int(parsed.get("data_size", 0))
			out["sequence"] = int(parsed.get("sequence", 0))
			out["session_id"] = int(parsed.get("session_id", 0))
			out["parameter"] = int(parsed.get("parameter", 0))
			out["checksum_ok"] = bool(parsed.get("checksum_ok", false))
		if wire_1127.has_method("dol_client_version_from_bytes"):
			out["client_version"] = int(wire_1127.call("dol_client_version_from_bytes", packet))
		if wire_1127.has_method("describe_dol_gspacket"):
			out["description"] = str(wire_1127.call("describe_dol_gspacket", packet))
	return out


func _guardrails() -> Dictionary:
	return {
		"coordinate_frame_confirmed": false,
		"runtime_enabled": false,
		"player_spawn_applied": false,
		"server_authority": false,
		"gameplay_fake": false,
		"login_implemented": false,
		"credentials_sent": false,
	}


func _close_transport(transport: Node, reason: String) -> void:
	if transport != null and transport.has_method("close_transport"):
		transport.call("close_transport", reason)


func _write_text(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "cannot open file"}
	file.store_string(text)
	file.close()
	return {"ok": true, "path": path, "global_path": ProjectSettings.globalize_path(path)}


func _bytes_to_hex(data: PackedByteArray, max_bytes: int = 64) -> String:
	var parts: Array = []
	var count := mini(data.size(), maxi(0, max_bytes))
	for i in range(count):
		parts.append("%02X" % (int(data[i]) & 0xff))
	if data.size() > count:
		parts.append("...")
	return " ".join(parts)
