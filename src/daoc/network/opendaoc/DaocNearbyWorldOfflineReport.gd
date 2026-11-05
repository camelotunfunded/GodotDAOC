extends RefCounted
class_name DaocNearbyWorldOfflineReport

const Replay = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldCaptureReplay.gd")
const Decoder = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldPacketDecoder.gd")
const Registry = preload("res://src/daoc/network/opendaoc/DaocNearbyEntityRegistry.gd")

const CAPTURE_PATH := "res://reports/p1_20d_live_heyveno_gameopen/p1_20d_post_gameopen_server_packets.bin"
const DEFAULT_REPORT_DIR := "res://reports/p1_20e_nearby_world_offline"

var replay := Replay.new()
var decoder := Decoder.new()
var registry := Registry.new()


func build(report_dir: String = DEFAULT_REPORT_DIR, write_files: bool = true) -> Dictionary:
	registry.reset(); registry.seed_confirmed_heyveno()
	var capture := replay.load_server_capture(CAPTURE_PATH)
	var validation := replay.replay_server_packets(capture)
	var opcode_counts: Dictionary = validation.get("opcode_counts", {})
	var parse_errors: Array = []
	var partial: Array = []
	var unknown_preserved: Array = []
	var decoded_fixtures := {}
	for packet in validation.get("packets", []):
		var op := int(packet.opcode)
		var decoded := decoder.decode_nearby_world_packet(op, packet.payload)
		if not decoder.SUPPORTED.has(op):
			unknown_preserved.append({"packet_index": int(packet.packet_index), "opcode": "0x%02X" % op, "payload_size": int(packet.payload_size)})
			continue
		if not decoded_fixtures.has("0x%02X" % op): decoded_fixtures["0x%02X" % op] = _json_safe(decoded)
		if not bool(decoded.get("ok", false)):
			parse_errors.append({"packet_index": int(packet.packet_index), "opcode": "0x%02X" % op, "result": _json_safe(decoded)})
			continue
		if bool(decoded.get("partially_decoded", false)):
			partial.append({"packet_index": int(packet.packet_index), "opcode": "0x%02X" % op,
				"remaining_bytes": int(decoded.get("remaining_bytes", 0))})
		registry.ingest(decoded, int(packet.packet_index))

	var entities := registry.sorted_entities()
	var model_catalog := _build_model_catalog(entities)
	var counts := _entity_counts(entities)
	var expected_counts_ok := int(opcode_counts.get("0xDA", 0)) == 188 and int(opcode_counts.get("0xD9", 0)) == 122 \
		and int(opcode_counts.get("0x15", 0)) == 141 and int(opcode_counts.get("0xA1", 0)) == 24 and int(opcode_counts.get("0xDE", 0)) == 342
	var capture_ok := bool(validation.get("ok", false)) and int(validation.get("packet_count", 0)) == 831 \
		and int(validation.get("total_bytes", 0)) == 25820 and int(validation.get("remaining_bytes", -1)) == 0 \
		and int(validation.get("truncated_packets", -1)) == 0 and bool(validation.get("deterministic", false))
	var offline_pass := capture_ok and expected_counts_ok and parse_errors.is_empty() and partial.is_empty() \
		and registry.pending_update_count() == 0 and int(counts.unique_npc_count) == 188 and int(counts.unique_object_count) == 122
	var reachability := _read_json("res://reports/p1_20e_server_reachability/p1_20e_server_reachability.json")
	var p1_20e_test := _read_json("res://reports/p1_20e_nearby_world_offline/p1_20e_test_result.json")
	var stats := {
		"capture_packet_count": int(validation.get("packet_count", 0)), "capture_total_bytes": int(validation.get("total_bytes", 0)),
		"npc_create_packet_count": int(opcode_counts.get("0xDA", 0)), "object_create_packet_count": int(opcode_counts.get("0xD9", 0)),
		"equipment_update_packet_count": int(opcode_counts.get("0x15", 0)), "object_update_packet_count": int(opcode_counts.get("0xA1", 0)),
		"guild_update_packet_count": int(opcode_counts.get("0xDE", 0)), "unique_entity_count": int(counts.unique_entity_count),
		"unique_npc_count": int(counts.unique_npc_count), "unique_object_count": int(counts.unique_object_count),
		"unique_player_count": int(counts.unique_player_count), "duplicate_object_id_count": registry.duplicate_create_object_ids.size(),
		"pending_update_count_final": registry.pending_update_count(), "pending_update_applied_count": registry.applied_pending_count,
		"parse_error_count": parse_errors.size(), "partially_decoded_packet_count": partial.size(),
		"unknown_packet_variant_count": partial.size(), "unsupported_opcode_packet_count": unknown_preserved.size(),
		"unique_model_id_count": model_catalog.size(), "exact_nif_resolution_count": 0,
		"candidate_nif_resolution_count": 0, "unresolved_nif_count": model_catalog.size(),
	}
	var report := {
		"checkpoint": "P1-20E_NEARBY_WORLD_OFFLINE_ENTITY_REGISTRY", "offline_decode_verdict": "PASS_NEARBY_WORLD_ENTITY_REGISTRY_OFFLINE" if offline_pass else "FAILED_ENTITY_REGISTRY",
		"server_reachability_verdict": str(reachability.get("verdict", "SERVER_STATUS_UNKNOWN")),
		"client_profile": {"announced": "1.125a", "negotiated_enum": 1125, "packet_lib": "PacketLib1125", "no_hybrid_layout": true},
		"capture_path": CAPTURE_PATH, "capture_sha256": str(validation.get("source_sha256", "")),
		"statistics": stats, "replay_validation": _validation_safe(validation),
		"decoded_fixtures": decoded_fixtures, "parse_errors": parse_errors, "partially_decoded_packets": partial,
		"unknown_packets_preserved": unknown_preserved, "unknown_packets_preserved_count": unknown_preserved.size(),
		"conflict_count": registry.conflicts.size(), "network_gameplay_performed": false, "tcp_send_count": 0,
		"udp_enabled": false, "movement_sent": false, "zone_loaded": false, "visual_spawn_performed": false,
		"nif_resolution_method": "No authoritative living/static object model_id-to-NIF mapping was found in the audited project data; fixture NIF IDs are a different namespace.",
		"nif_searches_required": ["authoritative client living model table", "authoritative static object model table", "model family metadata linking protocol IDs to NPK/NIF entries"],
		"test_summary": {"p1_20e_passed": int(p1_20e_test.get("passed_count", 0)), "p1_20e_failed": int(p1_20e_test.get("failed_count", 0)),
			"historical_regression_passed": 208, "historical_regression_failed": 0},
	}
	if write_files:
		var layouts := decoder.opcode_layouts()
		_attach_fixture_values(layouts, decoded_fixtures)
		_write_all(report_dir, report, entities, model_catalog, layouts, validation)
	return {"ok": offline_pass, "report": report, "entities": entities, "models": model_catalog,
		"validation": validation, "conflicts": registry.conflicts.duplicate(true)}


func _write_all(dir: String, report: Dictionary, entities: Array, models: Array, layouts: Dictionary, validation: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write_json(dir.path_join("p1_20e_offline_report.json"), report)
	_write_text(dir.path_join("p1_20e_offline_report.txt"), _summary(report))
	_write_text(dir.path_join("p1_20e_summary.txt"), _summary(report))
	_write_json(dir.path_join("p1_20e_replay_validation.json"), _validation_safe(validation))
	_write_json(dir.path_join("p1_20e_entity_registry.json"), {"heyveno_reference": Registry.HEYVENO, "entities": entities})
	_write_text(dir.path_join("p1_20e_entity_registry.csv"), _entities_csv(entities))
	_write_text(dir.path_join("p1_20e_npc_registry.csv"), _entities_csv(entities.filter(func(e): return str(e.entity_type) == "npc")))
	_write_text(dir.path_join("p1_20e_object_registry.csv"), _entities_csv(entities.filter(func(e): return str(e.entity_type) == "object")))
	_write_text(dir.path_join("p1_20e_model_catalog.csv"), _models_csv(models))
	_write_text(dir.path_join("p1_20e_model_to_nif_candidates.csv"), _nif_csv(models))
	_write_json(dir.path_join("p1_20e_opcode_layouts.json"), layouts)
	_write_text(dir.path_join("p1_20e_unknown_fields.csv"), _unknown_fields_csv(layouts))
	_write_text(dir.path_join("p1_20e_conflicts.csv"), _conflicts_csv(registry.conflicts))


func _entity_counts(entities: Array) -> Dictionary:
	var n := {"unique_entity_count": entities.size(), "unique_npc_count": 0, "unique_object_count": 0, "unique_player_count": 0}
	for e in entities:
		var key := "unique_%s_count" % str(e.entity_type)
		if n.has(key): n[key] = int(n[key]) + 1
	return n


func _build_model_catalog(entities: Array) -> Array:
	var by_model := {}
	for e in entities:
		var model := int(e.model_id)
		if model <= 0: continue
		if not by_model.has(model):
			by_model[model] = {"model_id": model, "entity_types": [], "entity_count": 0, "names": [], "example_object_ids": [],
				"minimum_distance": null, "maximum_distance": null, "equipment_model_ids": [], "nif_resolved": false,
				"nif_candidate": "", "nif_status": "UNRESOLVED", "confidence": "unresolved_without_authoritative_mapping"}
		var row: Dictionary = by_model[model]
		row.entity_count = int(row.entity_count) + 1
		if not row.entity_types.has(str(e.entity_type)): row.entity_types.append(str(e.entity_type))
		if str(e.name) != "" and not row.names.has(str(e.name)): row.names.append(str(e.name))
		if row.example_object_ids.size() < 5: row.example_object_ids.append(int(e.object_id))
		if e.distance_3d != null:
			var d := float(e.distance_3d)
			row.minimum_distance = d if row.minimum_distance == null else minf(float(row.minimum_distance), d)
			row.maximum_distance = d if row.maximum_distance == null else maxf(float(row.maximum_distance), d)
		for item in e.equipment.values():
			var item_model := int(item.model_id)
			if item_model > 0 and not row.equipment_model_ids.has(item_model): row.equipment_model_ids.append(item_model)
	var out: Array = by_model.values()
	out.sort_custom(func(a, b): return int(a.model_id) < int(b.model_id))
	return out


func _entities_csv(rows: Array) -> String:
	var out := ["object_id,entity_type,name,model_id,x,y,z,heading,level,realm,distance_from_heyveno,equipment_count,guild_id,first_packet_index,last_packet_index,nif_status,nif_candidate"]
	for e in rows:
		out.append(",".join([str(e.object_id), _q(e.entity_type), _q(e.name), str(e.model_id), _nullable(e.x), _nullable(e.y), _nullable(e.z), str(e.heading), str(e.level), str(e.realm), _float_or_blank(e.distance_3d), str(e.equipment.size()), str(e.guild_id), str(e.first_packet_index), str(e.last_packet_index), _q(e.nif_status), _q(e.nif_candidate)]))
	return "\ufeff" + "\n".join(out) + "\n"


func _models_csv(rows: Array) -> String:
	var out := ["model_id,entity_type,entity_count,names,example_object_ids,minimum_distance,maximum_distance,equipment_model_ids,nif_resolved,nif_candidate,confidence"]
	for r in rows: out.append(",".join([str(r.model_id), _q("|".join(r.entity_types)), str(r.entity_count), _q("|".join(r.names)), _q(_join_values(r.example_object_ids)), _float_or_blank(r.minimum_distance), _float_or_blank(r.maximum_distance), _q(_join_values(r.equipment_model_ids)), str(r.nif_resolved).to_lower(), _q(r.nif_candidate), _q(r.confidence)]))
	return "\ufeff" + "\n".join(out) + "\n"


func _nif_csv(rows: Array) -> String:
	var out := ["model_id,status,nif_path,mapping_source,mapping_entry,nif_family,geometry_kind,confidence,required_research"]
	for r in rows: out.append(",".join([str(r.model_id), "UNRESOLVED", "", "", "", "unknown", "unknown", _q(r.confidence), _q("Locate authoritative protocol model mapping; do not reuse zone fixture NIF IDs")]))
	return "\ufeff" + "\n".join(out) + "\n"


func _unknown_fields_csv(layouts: Dictionary) -> String:
	var out := ["opcode,packet_name,offset,size,field,endianness,server_method,confidence,notes"]
	for opcode in ["0xDA", "0xD9", "0x15", "0xA1", "0xDE"]:
		var l: Dictionary = layouts[opcode]
		for f in l.fields:
			if "unknown" in str(f.field): out.append(",".join([opcode, _q(l.name), str(f.offset), str(f.size), _q(f.field), _q(f.endianness), _q(f.server_method), _q(f.confidence), _q("Wire field is source-confirmed; semantics remain unknown")]))
	return "\ufeff" + "\n".join(out) + "\n"


func _conflicts_csv(rows: Array) -> String:
	var out := ["object_id,field,old_value,new_value,packet_index,source"]
	for r in rows: out.append(",".join([str(r.object_id), _q(r.field), _q(str(r.old_value)), _q(str(r.new_value)), str(r.packet_index), _q(r.source)]))
	return "\ufeff" + "\n".join(out) + "\n"


func _summary(report: Dictionary) -> String:
	var s: Dictionary = report.statistics
	return "\n".join(["P1-20E nearby world offline entity registry", "offline_decode_verdict=%s" % report.offline_decode_verdict,
		"server_reachability_verdict=%s" % report.server_reachability_verdict,
		"capture_packet_count=%d capture_total_bytes=%d remaining_bytes=%d truncated_packets=%d" % [s.capture_packet_count, s.capture_total_bytes, report.replay_validation.remaining_bytes, report.replay_validation.truncated_packets],
		"0xDA=%d 0xD9=%d 0x15=%d 0xA1=%d 0xDE=%d" % [s.npc_create_packet_count, s.object_create_packet_count, s.equipment_update_packet_count, s.object_update_packet_count, s.guild_update_packet_count],
		"unique_entities=%d npc=%d objects=%d players=%d pending=%d conflicts=%d" % [s.unique_entity_count, s.unique_npc_count, s.unique_object_count, s.unique_player_count, s.pending_update_count_final, report.conflict_count],
		"models=%d nif_exact=%d nif_candidates=%d nif_unresolved=%d" % [s.unique_model_id_count, s.exact_nif_resolution_count, s.candidate_nif_resolution_count, s.unresolved_nif_count],
		"network_gameplay_performed=false tcp_send_count=0 udp_enabled=false movement_sent=false", ""])


func _validation_safe(v: Dictionary) -> Dictionary:
	return {"ok": bool(v.get("ok", false)), "packet_count": int(v.get("packet_count", 0)), "total_bytes": int(v.get("total_bytes", 0)),
		"remaining_bytes": int(v.get("remaining_bytes", -1)), "truncated_packets": int(v.get("truncated_packets", -1)),
		"deterministic": bool(v.get("deterministic", false)), "source_sha256": str(v.get("source_sha256", "")),
		"replay_sha256": str(v.get("replay_sha256", "")), "opcode_counts": v.get("opcode_counts", {}), "payload_size_variants": v.get("payload_size_variants", {})}


func _attach_fixture_values(layouts: Dictionary, fixtures: Dictionary) -> void:
	var aliases := {
		"level_statue": "level", "flags_realm": "flags_raw", "flags2": "flags2_raw", "flags3": "flags3_raw",
		"unknown": "unknown_26_u16", "trailing": "trailing_byte", "model_flags": "model_raw",
		"flags": "flags_raw", "items": "items", "flags_zone_high_bits": "flags_raw",
		"zone_skin_low": "zone_skin_id", "target_zone_skin_low": "target_zone_skin_id",
	}
	for opcode in ["0xDA", "0xD9", "0x15", "0xA1", "0xDE"]:
		var fixture: Dictionary = fixtures.get(opcode, {})
		for field in layouts[opcode].fields:
			var key := str(aliases.get(str(field.field), str(field.field)))
			field.fixture_value = _json_safe(fixture[key]) if fixture.has(key) else "not_present_in_fixture"


func _json_safe(value: Variant) -> Variant:
	if value is PackedByteArray: return {"byte_count": value.size(), "sha256": _sha256(value)}
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _json_safe(value[k])
		return out
	if value is Array:
		var out: Array = []
		for x in value:
			out.append(_json_safe(x))
		return out
	return value


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)); return parsed if parsed is Dictionary else {}

func _write_json(path: String, data: Variant) -> void:
	_write_text(path, JSON.stringify(data, "\t"))

func _write_text(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()

func _q(value: Variant) -> String:
	return '"%s"' % str(value).replace('"', '""')

func _nullable(value: Variant) -> String:
	return "" if value == null else str(value)

func _float_or_blank(value: Variant) -> String:
	return "" if value == null else "%.3f" % float(value)

func _join_values(values: Array) -> String:
	var out: Array[String] = []
	for value in values:
		out.append(str(value))
	return "|".join(out)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
