extends RefCounted
class_name DaocOfflineWorldPreview

const SCOPE: String = "P1-17E2P offline world preview placeholders"
const CHECKPOINT: String = "P1_17E2P_OFFLINE_WORLD_PREVIEW_PLACEHOLDERS"
const ROOT_NAME: String = "OfflineWorldPreviewRoot_P1_17E2P"
const DEFAULT_JSON_PATH: String = "res://reports/p1_17e2p_offline_world_preview.json"
const DEFAULT_TEXT_PATH: String = "res://reports/p1_17e2p_offline_world_preview.txt"
const QUALITY_JSON_PATH: String = "res://reports/p1_17f5_preview_quality.json"
const QUALITY_TEXT_PATH: String = "res://reports/p1_17f5_preview_quality.txt"
const ENTITY_TYPE_PRIORITY: Array = ["mob", "door", "zonepoint", "jumppoint", "bindpoint", "startuplocation"]
const CLIENT_ZONE_SIZE: float = 65536.0
const CLIENT_LOC_AXIS_MIN: float = 0.0
const CLIENT_LOC_AXIS_MAX: float = 65535.0

var last_report: Dictionary = {}
var last_attach_report: Dictionary = {}
var last_quality_report: Dictionary = {}


func build_preview_report(sql_report: Dictionary, options: Dictionary = {}) -> Dictionary:
	var entities: Array = []
	for table_value in (sql_report.get("tables", []) as Array):
		if typeof(table_value) != TYPE_DICTIONARY:
			continue
		entities.append_array(_entities_from_table(table_value as Dictionary))
	var source_counts: Dictionary = _count_entities(entities, "entity_type")
	var raw_region_counts: Dictionary = _count_entities(entities, "region_id")
	var coordinate_filter: Dictionary = _filter_entities_for_client_loc_xy_range(entities, options)
	entities = coordinate_filter.get("entities", []) as Array
	var coordinate_filter_report: Dictionary = coordinate_filter.duplicate(true)
	coordinate_filter_report.erase("entities")
	var zone_filter: Dictionary = _filter_entities_for_visible_client_zones(entities, options)
	entities = zone_filter.get("entities", []) as Array
	var zone_filter_report: Dictionary = zone_filter.duplicate(true)
	zone_filter_report.erase("entities")
	var max_entities: int = int(options.get("max_entities", 512))
	var selection: Dictionary = _apply_balanced_entity_budget(entities, max_entities)
	entities = selection.get("entities", []) as Array
	var counts: Dictionary = _count_entities(entities, "entity_type")
	var regions: Dictionary = _count_entities(entities, "region_id")
	last_report = {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"offline_preview": true,
		"server_authority": false,
		"gameplay_fake": false,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"source_checkpoint": str(sql_report.get("checkpoint", "")),
		"source_status": str(sql_report.get("status", "")),
		"entity_selection_strategy": str(selection.get("strategy", "")),
		"entity_budget": max_entities,
		"source_entity_count_raw": int(coordinate_filter.get("source_entity_count_raw", 0)),
		"source_region_counts_raw": raw_region_counts,
		"source_entity_count_before_budget": int(selection.get("source_entity_count", 0)),
		"source_entity_counts_before_budget": source_counts,
		"coordinate_range_filter": coordinate_filter_report,
		"server_client_zone_mapping_runtime": true,
		"server_client_zone_mapping_scope": str(zone_filter.get("mapping_scope", "")),
		"visible_client_zone_filter": zone_filter_report,
		"entity_count": entities.size(),
		"entity_counts": counts,
		"region_counts": regions,
		"entities": entities,
		"notes": [
			"placeholders are visual debug only",
			"server DB coordinates are not applied to player spawn",
			"coordinate frame remains unconfirmed",
		],
	}
	return last_report



func _filter_entities_for_client_loc_xy_range(entities: Array, options: Dictionary) -> Dictionary:
	if not bool(options.get("validate_client_loc_xy_range", true)):
		return {
			"enabled": false,
			"source_entity_count_raw": entities.size(),
			"filtered_out": 0,
			"coordinate_space": "server_coordinates_unvalidated",
			"entities": entities,
		}
	var allow_out_of_range: bool = bool(options.get("allow_out_of_range_client_loc_preview", false))
	var allow_region_global: bool = bool(options.get("allow_region_global_coordinate_preview", true))
	var out: Array = []
	var filtered_out: int = 0
	var global_coordinate_count: int = 0
	var local_coordinate_count: int = 0
	var skipped_by_region: Dictionary = {}
	var skipped_by_type: Dictionary = {}
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value as Dictionary
		var p: Dictionary = entity.get("position_daoc", {}) as Dictionary
		var x: float = float(p.get("x", 0.0))
		var y: float = float(p.get("y", 0.0))
		var valid_xy: bool = _is_client_loc_axis(x) and _is_client_loc_axis(y)
		var region_global_xy: bool = x >= 0.0 and y >= 0.0 and (not valid_xy)
		if valid_xy or allow_out_of_range or (allow_region_global and region_global_xy):
			var with_loc: Dictionary = entity.duplicate(true)
			with_loc["loc_xy_range_valid"] = valid_xy
			with_loc["client_loc_axis_min"] = CLIENT_LOC_AXIS_MIN
			with_loc["client_loc_axis_max"] = CLIENT_LOC_AXIS_MAX
			if valid_xy:
				with_loc["coordinate_space"] = "server_client_loc_xy_0_65535"
				with_loc["coordinate_fold_required"] = false
				local_coordinate_count += 1
			elif region_global_xy:
				with_loc["coordinate_space"] = "server_region_global_xy_projected_to_client_loc"
				with_loc["coordinate_fold_required"] = true
				with_loc["server_region_chunk_x"] = int(floor(x / CLIENT_ZONE_SIZE))
				with_loc["server_region_chunk_y"] = int(floor(y / CLIENT_ZONE_SIZE))
				with_loc["position_daoc_local_preview"] = {"x": _fold_daoc_axis(x), "y": _fold_daoc_axis(y), "z": float(p.get("z", 0.0))}
				global_coordinate_count += 1
			else:
				with_loc["coordinate_space"] = "server_coordinate_outside_client_loc_range"
			out.append(with_loc)
		else:
			filtered_out += 1
			var region_key: String = str(entity.get("region_id", "unknown"))
			var type_key: String = str(entity.get("entity_type", "unknown"))
			skipped_by_region[region_key] = int(skipped_by_region.get(region_key, 0)) + 1
			skipped_by_type[type_key] = int(skipped_by_type.get(type_key, 0)) + 1
	return {
		"enabled": true,
		"coordinate_space": "server_client_loc_or_region_global_xy",
		"axis_min": CLIENT_LOC_AXIS_MIN,
		"axis_max": CLIENT_LOC_AXIS_MAX,
		"source_entity_count_raw": entities.size(),
		"kept": out.size(),
		"filtered_out": filtered_out,
		"local_coordinate_count": local_coordinate_count,
		"global_coordinate_count": global_coordinate_count,
		"skipped_by_region": skipped_by_region,
		"skipped_by_type": skipped_by_type,
		"allow_out_of_range_client_loc_preview": allow_out_of_range,
		"allow_region_global_coordinate_preview": allow_region_global,
		"entities": out,
	}


func _is_client_loc_axis(value: float) -> bool:
	return value >= CLIENT_LOC_AXIS_MIN and value <= CLIENT_LOC_AXIS_MAX

func _filter_entities_for_visible_client_zones(entities: Array, options: Dictionary) -> Dictionary:
	if not bool(options.get("filter_to_visible_client_zones", false)):
		return {
			"enabled": false,
			"filtered_out": 0,
			"mapping_scope": "runtime_adapter_not_filtering",
			"entities": entities,
		}
	var visible_zone_ids: Array = _visible_zone_id_array(options.get("visible_client_zone_ids", []))
	if visible_zone_ids.is_empty():
		return {
			"enabled": true,
			"visible_client_zone_ids": [],
			"filtered_out": 0,
			"reason": "no visible zones supplied",
			"mapping_scope": "runtime_adapter_no_visible_zone",
			"entities": entities,
		}
	var out: Array = []
	var filtered_out: int = 0
	var skipped_by_region: Dictionary = {}
	var kept_by_mapping_basis: Dictionary = {}
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value as Dictionary
		var mapping: Dictionary = _client_zone_mapping_for_entity(entity, options)
		var client_zone_id: int = int(mapping.get("client_zone_id", -1))
		if visible_zone_ids.has(client_zone_id):
			var with_zone: Dictionary = entity.duplicate(true)
			with_zone["client_zone_id"] = client_zone_id
			with_zone["client_zone_mapping_basis"] = str(mapping.get("mapping_basis", ""))
			with_zone["client_zone_mapping_confidence"] = str(mapping.get("mapping_confidence", ""))
			with_zone["client_zone_mapping_runtime"] = true
			out.append(with_zone)
			var basis_key: String = str(mapping.get("mapping_basis", "unknown"))
			kept_by_mapping_basis[basis_key] = int(kept_by_mapping_basis.get(basis_key, 0)) + 1
		else:
			filtered_out += 1
			var region_key: String = str(entity.get("region_id", "unknown"))
			skipped_by_region[region_key] = int(skipped_by_region.get(region_key, 0)) + 1
	return {
		"enabled": true,
		"visible_client_zone_ids": visible_zone_ids,
		"filtered_out": filtered_out,
		"skipped_by_region": skipped_by_region,
		"kept_by_mapping_basis": kept_by_mapping_basis,
		"mapping_scope": "runtime_server_client_zone_adapter",
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"entities": out,
	}


func _apply_balanced_entity_budget(entities: Array, max_entities: int) -> Dictionary:
	if max_entities <= 0 or entities.size() <= max_entities:
		return {
			"strategy": "no_global_truncation",
			"source_entity_count": entities.size(),
			"entities": entities,
		}
	var buckets: Dictionary = {}
	var bucket_indices: Dictionary = {}
	for entity_type in ENTITY_TYPE_PRIORITY:
		buckets[str(entity_type)] = []
		bucket_indices[str(entity_type)] = 0
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value as Dictionary
		var entity_type: String = str(entity.get("entity_type", "unknown"))
		if not buckets.has(entity_type):
			buckets[entity_type] = []
			bucket_indices[entity_type] = 0
		(buckets[entity_type] as Array).append(entity)
	var ordered_types: Array = []
	for entity_type in ENTITY_TYPE_PRIORITY:
		if (buckets.get(str(entity_type), []) as Array).size() > 0:
			ordered_types.append(str(entity_type))
	for entity_type in buckets.keys():
		var key: String = str(entity_type)
		if not ordered_types.has(key) and (buckets.get(key, []) as Array).size() > 0:
			ordered_types.append(key)
	var out: Array = []
	var made_progress: bool = true
	while out.size() < max_entities and made_progress:
		made_progress = false
		for entity_type in ordered_types:
			if out.size() >= max_entities:
				break
			var bucket: Array = buckets.get(str(entity_type), []) as Array
			var index: int = int(bucket_indices.get(str(entity_type), 0))
			if index >= bucket.size():
				continue
			out.append(bucket[index])
			bucket_indices[str(entity_type)] = index + 1
			made_progress = true
	return {
		"strategy": "balanced_round_robin_by_entity_type",
		"source_entity_count": entities.size(),
		"entities": out,
	}


func attach_placeholders(host: Node, preview_report: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = preview_report if not preview_report.is_empty() else last_report
	var root: Node3D = _ensure_root(host, bool(options.get("clear_existing", true)))
	if root == null:
		last_attach_report = _attach_result(false, 0, "missing host/root")
		return last_attach_report
	var entities: Array = report.get("entities", []) as Array
	var attached: int = 0
	var folded_coordinate_count: int = 0
	var floor_snapped_count: int = 0
	var quality_entries: Array = []
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var node: Node3D = _make_placeholder(entity_value as Dictionary, options)
		if node == null:
			continue
		root.add_child(node)
		attached += 1
		if bool(node.get_meta("coordinate_folded_preview", false)):
			folded_coordinate_count += 1
		if bool(node.get_meta("floor_snapped_preview", false)):
			floor_snapped_count += 1
		quality_entries.append(_quality_entry_from_placeholder(node))
	var debug_beacon_added: bool = false
	if bool(options.get("add_debug_beacon", false)):
		var beacon: Node3D = _make_debug_beacon(options, report)
		if beacon != null:
			root.add_child(beacon)
			debug_beacon_added = true
	var near_sample_count: int = 0
	if bool(options.get("add_near_player_samples", false)):
		near_sample_count = _attach_near_player_samples(root, entities, options)
	last_attach_report = _attach_result(true, attached, "")
	last_attach_report["root_name"] = ROOT_NAME
	last_attach_report["entity_counts"] = _count_entities(entities, "entity_type")
	last_attach_report["placement_mode"] = str(options.get("placement_mode", "host_daoc_to_godot_if_available"))
	last_attach_report["debug_beacon_added"] = debug_beacon_added
	last_attach_report["near_player_sample_count"] = near_sample_count
	last_attach_report["folded_coordinate_count"] = folded_coordinate_count
	last_attach_report["floor_snapped_count"] = floor_snapped_count
	last_quality_report = _build_quality_report_from_entries(quality_entries, report, last_attach_report)
	last_attach_report["quality_report"] = last_quality_report.duplicate(true)
	if not last_report.is_empty():
		last_report["last_attach_report"] = last_attach_report.duplicate(true)
		last_report["last_quality_report"] = last_quality_report.duplicate(true)
	return last_attach_report


func detach_placeholders(host: Node) -> Dictionary:
	if host == null:
		last_attach_report = _attach_result(true, 0, "missing host")
		return last_attach_report
	var existing: Node = host.get_node_or_null(NodePath(ROOT_NAME))
	if existing != null:
		existing.queue_free()
	last_attach_report = {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"offline_preview": true,
		"detached": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
	}
	return last_attach_report


func build_quality_report_from_scene(host: Node, preview_report: Dictionary = {}) -> Dictionary:
	var root: Node = null
	if host != null:
		root = host.get_node_or_null(NodePath(ROOT_NAME))
	var entries: Array = []
	if root != null:
		for child in root.get_children():
			if child is Node and bool((child as Node).get_meta("offline_preview", false)) and not bool((child as Node).get_meta("debug_beacon", false)) and not bool((child as Node).get_meta("diagnostic_sample", false)):
				entries.append(_quality_entry_from_placeholder(child as Node))
	var source_report: Dictionary = preview_report if not preview_report.is_empty() else last_report
	last_quality_report = _build_quality_report_from_entries(entries, source_report, last_attach_report)
	return last_quality_report


func export_last_report_json(path: String = DEFAULT_JSON_PATH) -> Dictionary:
	return _write_text(path, JSON.stringify(last_report, "  "), "json")


func export_last_report_text(path: String = DEFAULT_TEXT_PATH) -> Dictionary:
	return _write_text(path, _report_as_text(last_report), "text")


func export_last_quality_report_json(path: String = QUALITY_JSON_PATH) -> Dictionary:
	return _write_text(path, JSON.stringify(last_quality_report, "  "), "json")


func export_last_quality_report_text(path: String = QUALITY_TEXT_PATH) -> Dictionary:
	return _write_text(path, _quality_report_as_text(last_quality_report), "text")


func _entities_from_table(table: Dictionary) -> Array:
	var table_id: String = str(table.get("table_id", "")).to_lower()
	var entity_type: String = _entity_type_from_table(table_id)
	if entity_type == "":
		return []
	var out: Array = []
	var rows: Array = table.get("rows_sample", []) as Array
	for i in range(rows.size()):
		if typeof(rows[i]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = rows[i] as Dictionary
		var entity: Dictionary = _normalize_entity(entity_type, table_id, row, i)
		if not entity.is_empty():
			out.append(entity)
	return out


func _normalize_entity(entity_type: String, table_id: String, row: Dictionary, index: int) -> Dictionary:
	var region_id: int = _row_first_int(row, ["Region", "RegionID", "region", "target_region", "TargetRegion"])
	var source_region_id: int = _row_first_int(row, ["Region", "RegionID", "region", "SourceRegion", "source_region"])
	var target_region_id: int = _row_first_int(row, ["TargetRegion", "target_region", "Region", "RegionID", "region"])
	var x: float = _row_first_float(row, ["X", "x", "XPos", "Xpos", "xpos", "TargetX", "target_x"])
	var y: float = _row_first_float(row, ["Y", "y", "YPos", "Ypos", "ypos", "TargetY", "target_y"])
	var z: float = _row_first_float(row, ["Z", "z", "ZPos", "Zpos", "zpos", "TargetZ", "target_z"])
	if region_id == 0 and x == 0.0 and y == 0.0 and z == 0.0:
		return {}
	var record_id: String = str(_row_first_any(row, ["Mob_ID", "DoorID", "Id", "ID", "id", "Name"]))
	if record_id == "" or record_id == "<null>":
		record_id = "%s_%03d" % [entity_type, index]
	var display_name: String = str(_row_first_any(row, ["Name", "name", "Guild", "ClassType"]))
	if display_name == "" or display_name == "<null>":
		display_name = "%s %s" % [entity_type.capitalize(), record_id]
	var heading: int = _row_first_int(row, ["Heading", "heading", "TargetHeading", "target_heading"])
	return {
		"entity_id": "%s_%s" % [entity_type, record_id],
		"entity_type": entity_type,
		"display_name": display_name,
		"region_id": region_id,
		"source_region_id": source_region_id,
		"target_region_id": target_region_id,
		"position_daoc": {"x": x, "y": y, "z": z},
		"heading_raw": heading,
		"model_ref": str(_row_first_any(row, ["Model", "model", "ModelID", "ClassType"])),
		"source_table": table_id,
		"source_table_id": table_id,
		"source_record_id": record_id,
		"source_row": row.duplicate(true),
		"offline_preview": true,
		"server_authority": false,
		"gameplay_fake": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
	}


func _make_placeholder(entity: Dictionary, options: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = _safe_node_name("%s_%s" % [str(entity.get("entity_type", "entity")), str(entity.get("entity_id", ""))])
	var placement: Dictionary = _placeholder_position(entity, options)
	node.position = placement.get("position", Vector3.ZERO) as Vector3
	node.set_meta("offline_preview", true)
	node.set_meta("server_authority", false)
	node.set_meta("gameplay_fake", false)
	node.set_meta("coordinate_frame_confirmed", false)
	node.set_meta("placement_mode", str(placement.get("mode", "")))
	node.set_meta("client_zone_id", int(placement.get("client_zone_id", -1)))
	node.set_meta("client_zone_mapping_basis", str(placement.get("client_zone_mapping_basis", entity.get("client_zone_mapping_basis", ""))))
	node.set_meta("client_zone_mapping_confidence", str(placement.get("client_zone_mapping_confidence", entity.get("client_zone_mapping_confidence", ""))))
	node.set_meta("coordinate_folded_preview", bool(placement.get("coordinate_folded_preview", false)))
	node.set_meta("floor_snapped_preview", bool(placement.get("floor_snapped_preview", false)))
	node.set_meta("server_z_raw", float(placement.get("server_z_raw", 0.0)))
	node.set_meta("floor_z_raw", float(placement.get("floor_z_raw", 0.0)))
	node.set_meta("vertical_delta_raw", float(placement.get("vertical_delta_raw", 0.0)))
	node.set_meta("position_daoc_local_preview", placement.get("position_daoc_local_preview", {}))
	node.set_meta("entity", entity.duplicate(true))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlaceholderMesh"
	var entity_type: String = str(entity.get("entity_type", ""))
	mesh_instance.mesh = _mesh_for_type(entity_type)
	mesh_instance.material_override = _material_for_type(entity_type)
	mesh_instance.position = Vector3(0.0, _visual_floor_offset(entity_type), 0.0)
	node.add_child(mesh_instance)
	var mast := _make_visibility_mast(entity_type)
	if mast != null:
		node.add_child(mast)
	var label := Label3D.new()
	label.name = "PlaceholderLabel"
	label.text = "%s\nR%d %s%s" % [
		str(entity.get("display_name", "")),
		int(entity.get("region_id", 0)),
		str(entity.get("entity_type", "")),
		"\nFOLDED PREVIEW" if bool(placement.get("coordinate_folded_preview", false)) else "",
	]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 260.0, 0.0)
	label.pixel_size = 0.035
	node.add_child(label)
	return node


func _attach_near_player_samples(root: Node3D, entities: Array, options: Dictionary) -> int:
	var max_samples: int = int(options.get("near_player_sample_count", 16))
	if max_samples <= 0:
		return 0
	var samples: Array = []
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value as Dictionary
		if str(entity.get("entity_type", "")) != "mob":
			continue
		samples.append(entity)
		if samples.size() >= max_samples:
			break
	var count: int = samples.size()
	for i in range(count):
		var node: Node3D = _make_near_player_sample(samples[i] as Dictionary, options, i, count)
		if node != null:
			root.add_child(node)
	return count


func _make_near_player_sample(entity: Dictionary, options: Dictionary, index: int, count: int) -> Node3D:
	var node := Node3D.new()
	node.name = _safe_node_name("near_sample_%02d_%s" % [index, str(entity.get("entity_id", ""))])
	var radius: float = float(options.get("near_player_sample_radius", 1150.0))
	var angle: float = TAU * float(index) / float(maxi(count, 1))
	node.position = _debug_sample_origin(options) + Vector3(cos(angle) * radius, 40.0, sin(angle) * radius)
	node.set_meta("offline_preview", true)
	node.set_meta("server_authority", false)
	node.set_meta("gameplay_fake", false)
	node.set_meta("diagnostic_sample", true)
	node.set_meta("entity", entity.duplicate(true))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NearSampleMobMesh"
	mesh_instance.mesh = _mesh_for_type("mob")
	mesh_instance.material_override = _sample_material()
	mesh_instance.scale = Vector3(3.0, 3.0, 3.0)
	mesh_instance.position = Vector3(0.0, _visual_floor_offset("mob") * 3.0, 0.0)
	node.add_child(mesh_instance)
	var mast := _make_visibility_mast("sample")
	if mast != null:
		node.add_child(mast)
	var label := Label3D.new()
	label.name = "NearSampleLabel"
	label.text = "MOB SAMPLE\n%s" % str(entity.get("display_name", "mob"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 520.0, 0.0)
	label.pixel_size = 0.065
	node.add_child(label)
	return node


func _debug_sample_origin(options: Dictionary) -> Vector3:
	var player: Node3D = options.get("player", null) as Node3D
	if player != null:
		if player.is_inside_tree():
			return player.global_position
		return player.position
	var host: Node3D = options.get("host", null) as Node3D
	if host != null:
		if host.is_inside_tree():
			return host.global_position
		return host.position
	return Vector3(32768.0, 2100.0, 32768.0)


func _make_debug_beacon(options: Dictionary, report: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "OfflinePreviewDebugBeacon_CTRL_F1"
	node.position = _debug_beacon_position(options)
	node.set_meta("offline_preview", true)
	node.set_meta("server_authority", false)
	node.set_meta("gameplay_fake", false)
	node.set_meta("debug_beacon", true)
	var sphere := MeshInstance3D.new()
	sphere.name = "BeaconMesh"
	var mesh := SphereMesh.new()
	mesh.radius = 360.0
	mesh.height = 720.0
	sphere.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.05, 0.05, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.05, 0.05)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.set("no_depth_test", true)
	sphere.material_override = mat
	node.add_child(sphere)
	var label := Label3D.new()
	label.name = "BeaconLabel"
	label.text = "OFFLINE PREVIEW ON\nentities=%d counts=%s" % [
		int(report.get("entity_count", 0)),
		str(report.get("entity_counts", {})),
	]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 540.0, 0.0)
	label.pixel_size = 0.08
	node.add_child(label)
	return node


func _debug_beacon_position(options: Dictionary) -> Vector3:
	var player: Node3D = options.get("player", null) as Node3D
	if player != null:
		if player.is_inside_tree():
			return player.global_position + Vector3(0.0, 320.0, 0.0)
		return player.position + Vector3(0.0, 320.0, 0.0)
	var host: Node3D = options.get("host", null) as Node3D
	if host != null:
		if host.is_inside_tree():
			return host.global_position + Vector3(0.0, 1400.0, 0.0)
		return host.position + Vector3(0.0, 1400.0, 0.0)
	return Vector3(32768.0, 2800.0, 32768.0)


func _placeholder_position(entity: Dictionary, options: Dictionary) -> Dictionary:
	var p: Dictionary = entity.get("position_daoc", {}) as Dictionary
	var x: float = float(p.get("x", 0.0))
	var y: float = float(p.get("y", 0.0))
	var z: float = float(p.get("z", 0.0))
	var preview_xy: Vector2 = _preview_zone_xy(x, y, options)
	var use_x: float = preview_xy.x
	var use_y: float = preview_xy.y
	var folded: bool = absf(use_x - x) > 0.001 or absf(use_y - y) > 0.001
	var client_zone_mapping: Dictionary = _client_zone_mapping_for_entity(entity, options)
	var client_zone_id: int = int(client_zone_mapping.get("client_zone_id", -1))
	var host: Object = options.get("host", null) as Object
	if host != null and client_zone_id >= 0 and host.has_method("daoc_to_godot"):
		var z_for_place: float = z
		var floor_snapped: bool = false
		var floor_z_value: float = z
		var vertical_delta_raw: float = 0.0
		if host.has_method("sample_daoc_floor_z"):
			var should_snap_all: bool = bool(options.get("snap_all_placeholders_to_floor", true))
			var should_snap_mob: bool = bool(options.get("snap_mobs_to_floor", true)) and str(entity.get("entity_type", "")) == "mob"
			if should_snap_all or should_snap_mob:
				floor_z_value = float(host.call("sample_daoc_floor_z", client_zone_id, use_x, use_y, z))
				vertical_delta_raw = floor_z_value - z
				# P1-17F4: for offline exterior preview, server Z is not trusted enough
				# to drive visual height. F3 only raised buried markers, which left
				# valid X/Y placeholders floating when DB Z was above terrain.
				# Snap to the sampled client terrain floor in both directions.
				if bool(options.get("force_floor_height_for_preview", true)):
					z_for_place = floor_z_value
					floor_snapped = absf(vertical_delta_raw) > float(options.get("floor_snap_epsilon_raw", 1.0))
				elif floor_z_value > z_for_place:
					z_for_place = floor_z_value
					floor_snapped = true
		return {
			"mode": "host_daoc_to_godot_region_folded_floor_preview" if folded else "host_daoc_to_godot_floor_preview",
			"client_zone_id": client_zone_id,
			"client_zone_mapping_basis": str(client_zone_mapping.get("mapping_basis", entity.get("client_zone_mapping_basis", ""))),
			"client_zone_mapping_confidence": str(client_zone_mapping.get("mapping_confidence", entity.get("client_zone_mapping_confidence", ""))),
			"coordinate_folded_preview": folded,
			"floor_snapped_preview": floor_snapped,
			"server_z_raw": z,
			"floor_z_raw": floor_z_value,
			"vertical_delta_raw": vertical_delta_raw,
			"position_daoc_local_preview": {"x": use_x, "y": use_y, "z": z_for_place},
			"position": host.call("daoc_to_godot", client_zone_id, use_x, use_y, z_for_place) as Vector3,
		}
	return {
		"mode": "raw_preview_scaled_region_folded_fallback" if folded else "raw_preview_scaled_fallback",
		"client_zone_id": client_zone_id,
		"client_zone_mapping_basis": str(client_zone_mapping.get("mapping_basis", entity.get("client_zone_mapping_basis", ""))),
		"client_zone_mapping_confidence": str(client_zone_mapping.get("mapping_confidence", entity.get("client_zone_mapping_confidence", ""))),
		"coordinate_folded_preview": folded,
		"floor_snapped_preview": false,
		"position_daoc_local_preview": {"x": use_x, "y": use_y, "z": z},
		"position": _daoc_to_preview_position(use_x, use_y, z, float(options.get("world_scale", 0.10))),
	}


func _preview_zone_xy(x: float, y: float, options: Dictionary) -> Vector2:
	# DOL/OpenDAoC exterior tables often store region-global X/Y, while the
	# client /loc inside a loaded zone is local 0..65535. Placement may fold
	# region-global coordinates for visual preview only; the report keeps this
	# marked as unconfirmed and never applies it to player spawn.
	if _is_client_loc_axis(x) and _is_client_loc_axis(y):
		return Vector2(x, y)
	if bool(options.get("fold_region_coordinates_to_zone", false)):
		return Vector2(_fold_daoc_axis(x), _fold_daoc_axis(y))
	return Vector2(x, y)


func _fold_daoc_axis(value: float) -> float:
	return fposmod(value, CLIENT_ZONE_SIZE)


func _client_zone_for_entity(entity: Dictionary, options: Dictionary) -> int:
	return int(_client_zone_mapping_for_entity(entity, options).get("client_zone_id", -1))


func _client_zone_mapping_for_entity(entity: Dictionary, options: Dictionary) -> Dictionary:
	if entity.has("client_zone_id"):
		return {
			"ok": true,
			"client_zone_id": int(entity.get("client_zone_id", -1)),
			"mapping_basis": str(entity.get("client_zone_mapping_basis", "entity_pre_resolved_runtime_mapping")),
			"mapping_confidence": str(entity.get("client_zone_mapping_confidence", "pre_resolved")),
			"runtime_enabled": false,
			"coordinate_frame_confirmed": false,
			"player_spawn_applied": false,
		}
	var region_id: int = int(entity.get("region_id", -1))
	var mapper: Object = options.get("server_client_zone_map", null) as Object
	if mapper != null and mapper.has_method("resolve_region"):
		return mapper.call("resolve_region", region_id, options) as Dictionary
	var region_to_client_zone: Dictionary = options.get("region_to_client_zone", {}) as Dictionary
	if region_to_client_zone.has(region_id):
		return {"ok": true, "client_zone_id": int(region_to_client_zone[region_id]), "mapping_basis": "legacy_runtime_dictionary", "mapping_confidence": "legacy_explicit", "coordinate_frame_confirmed": false, "player_spawn_applied": false}
	if region_to_client_zone.has(str(region_id)):
		return {"ok": true, "client_zone_id": int(region_to_client_zone[str(region_id)]), "mapping_basis": "legacy_runtime_dictionary", "mapping_confidence": "legacy_explicit", "coordinate_frame_confirmed": false, "player_spawn_applied": false}
	return {"ok": false, "client_zone_id": int(options.get("default_client_zone_id", -1)), "mapping_basis": "default_client_zone_fallback", "mapping_confidence": "fallback", "coordinate_frame_confirmed": false, "player_spawn_applied": false}


func _visible_zone_id_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_PACKED_INT32_ARRAY:
		for item in (value as PackedInt32Array):
			if not out.has(int(item)):
				out.append(int(item))
		return out
	if typeof(value) != TYPE_ARRAY:
		return out
	for item_value in (value as Array):
		var item: int = int(item_value)
		if not out.has(item):
			out.append(item)
	return out


func _mesh_for_type(entity_type: String) -> Mesh:
	if entity_type == "door":
		var box := BoxMesh.new()
		box.size = Vector3(55.0, 150.0, 18.0)
		return box
	if entity_type == "bindpoint" or entity_type == "startuplocation" or entity_type == "zonepoint" or entity_type == "jumppoint":
		var sphere := SphereMesh.new()
		sphere.radius = 42.0
		sphere.height = 84.0
		return sphere
	var capsule := CapsuleMesh.new()
	capsule.radius = 35.0
	capsule.height = 130.0
	return capsule


func _visual_floor_offset(entity_type: String) -> float:
	if entity_type == "door":
		return 75.0
	if entity_type == "bindpoint" or entity_type == "startuplocation" or entity_type == "zonepoint" or entity_type == "jumppoint":
		return 48.0
	return 75.0


func _make_visibility_mast(entity_type: String) -> Node3D:
	var mast := MeshInstance3D.new()
	mast.name = "VisibilityMast"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 7.0
	mesh.bottom_radius = 7.0
	mesh.height = 760.0
	mast.mesh = mesh
	mast.position = Vector3(0.0, 380.0, 0.0)
	mast.material_override = _mast_material(entity_type)
	return mast


func _material_for_type(entity_type: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.35, 0.25, 0.78)
	if entity_type == "door":
		mat.albedo_color = Color(0.35, 0.75, 1.0, 0.78)
	elif entity_type == "bindpoint":
		mat.albedo_color = Color(0.3, 1.0, 0.45, 0.78)
	elif entity_type == "startuplocation":
		mat.albedo_color = Color(1.0, 0.9, 0.25, 0.78)
	elif entity_type == "zonepoint" or entity_type == "jumppoint":
		mat.albedo_color = Color(0.7, 0.45, 1.0, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.6
	return mat


func _mast_material(entity_type: String) -> StandardMaterial3D:
	var mat := _material_for_type(entity_type)
	mat.albedo_color.a = 0.95
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	mat.set("no_depth_test", true)
	return mat


func _sample_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.25, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.25)
	mat.emission_energy_multiplier = 3.5
	mat.set("no_depth_test", true)
	return mat


func _daoc_to_preview_position(x: float, y: float, z: float, scale: float) -> Vector3:
	return Vector3(x * scale, z * scale, -y * scale)


func _entity_type_from_table(table_id: String) -> String:
	if table_id.contains("mob"):
		return "mob"
	if table_id.contains("door"):
		return "door"
	if table_id.contains("bindpoint"):
		return "bindpoint"
	if table_id.contains("startup"):
		return "startuplocation"
	if table_id.contains("zonepoint"):
		return "zonepoint"
	if table_id.contains("jumppoint"):
		return "jumppoint"
	return ""


func _ensure_root(host: Node, clear_existing: bool) -> Node3D:
	if host == null:
		return null
	var existing: Node = host.get_node_or_null(NodePath(ROOT_NAME))
	if existing != null and clear_existing:
		host.remove_child(existing)
		existing.free()
		existing = null
	if existing != null:
		return existing as Node3D
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("offline_preview", true)
	root.set_meta("server_authority", false)
	root.set_meta("gameplay_fake", false)
	root.set_meta("coordinate_frame_confirmed", false)
	host.add_child(root)
	return root


func _attach_result(ok: bool, attached_count: int, error: String) -> Dictionary:
	return {
		"ok": ok,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"offline_preview": true,
		"server_authority": false,
		"gameplay_fake": false,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"attached_placeholder_count": attached_count,
		"error": error,
	}


func _count_entities(entities: Array, key: String) -> Dictionary:
	var out: Dictionary = {}
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value as Dictionary
		var k: String = str(entity.get(key, "unknown"))
		out[k] = int(out.get(k, 0)) + 1
	return out


func _row_first_any(row: Dictionary, keys: Array):
	for key_value in keys:
		var key: String = str(key_value)
		if row.has(key):
			return row[key]
	return null


func _row_first_int(row: Dictionary, keys: Array) -> int:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0
	return int(value)


func _row_first_float(row: Dictionary, keys: Array) -> float:
	var value = _row_first_any(row, keys)
	if value == null:
		return 0.0
	return float(value)


func _safe_node_name(value: String) -> String:
	var out: String = value
	for ch in [" ", "/", "\\", ":", ".", ";", ",", "'", "\"", "(", ")", "[", "]"]:
		out = out.replace(str(ch), "_")
	return out.substr(0, mini(out.length(), 80))


func _write_text(path: String, text: String, kind: String) -> Dictionary:
	var target: String = path.strip_edges()
	if target == "":
		return {"ok": false, "kind": kind, "path": target, "error": "empty path"}
	var global_path: String = ProjectSettings.globalize_path(target)
	var parent: String = global_path.get_base_dir()
	var dir_error: int = DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return {"ok": false, "kind": kind, "path": target, "error": "cannot create parent dir: %d" % dir_error}
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "kind": kind, "path": target, "error": "cannot open for write"}
	file.store_string(text)
	file.close()
	return {"ok": true, "kind": kind, "path": target, "runtime_enabled": false, "coordinate_frame_confirmed": false}


func _build_quality_report_from_entries(entries: Array, preview_report: Dictionary, attach_report: Dictionary) -> Dictionary:
	var counts_by_type: Dictionary = _zero_entity_type_counts()
	var vertical_counts: Dictionary = {"ok": 0, "suspect": 0, "bad": 0}
	var mapping_basis_counts: Dictionary = {}
	var local_coordinate_count: int = 0
	var region_global_projected_count: int = 0
	var floor_snapped_count: int = 0
	var total_abs_delta: float = 0.0
	var max_abs_delta: float = 0.0
	var clean_entries: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var entity_type: String = str(entry.get("entity_type", "unknown"))
		counts_by_type[entity_type] = int(counts_by_type.get(entity_type, 0)) + 1
		if bool(entry.get("floor_snapped", false)):
			floor_snapped_count += 1
		if bool(entry.get("region_global_projected", false)):
			region_global_projected_count += 1
		elif bool(entry.get("local_coordinates", false)):
			local_coordinate_count += 1
		var basis: String = str(entry.get("mapping_basis", "unknown"))
		mapping_basis_counts[basis] = int(mapping_basis_counts.get(basis, 0)) + 1
		var abs_delta: float = absf(float(entry.get("vertical_delta_raw", 0.0)))
		total_abs_delta += abs_delta
		max_abs_delta = maxf(max_abs_delta, abs_delta)
		var classification: String = _vertical_quality_class(abs_delta)
		entry["vertical_classification"] = classification
		entry["abs_vertical_delta_raw"] = abs_delta
		vertical_counts[classification] = int(vertical_counts.get(classification, 0)) + 1
		clean_entries.append(entry)
	var top_vertical_deltas: Array = clean_entries.duplicate(true)
	top_vertical_deltas.sort_custom(Callable(self, "_sort_quality_entry_by_abs_delta_desc"))
	if top_vertical_deltas.size() > 20:
		top_vertical_deltas = top_vertical_deltas.slice(0, 20)
	var coord_filter: Dictionary = preview_report.get("coordinate_range_filter", {}) as Dictionary
	var zone_filter: Dictionary = preview_report.get("visible_client_zone_filter", {}) as Dictionary
	var attached_count: int = clean_entries.size()
	var mean_abs_delta: float = total_abs_delta / float(maxi(attached_count, 1))
	return {
		"ok": true,
		"scope": "P1-17F5 preview quality",
		"checkpoint": "P1_17F5_PREVIEW_QUALITY",
		"offline_preview": true,
		"server_authority": false,
		"gameplay_fake": false,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"player_spawn_applied": false,
		"attached_placeholder_count": attached_count,
		"entity_counts": counts_by_type,
		"floor_snapped_count": floor_snapped_count,
		"region_global_projected_count": region_global_projected_count,
		"local_coordinate_count": local_coordinate_count,
		"loc_filtered_count": int(coord_filter.get("filtered_out", 0)),
		"zone_filtered_count": int(zone_filter.get("filtered_out", 0)),
		"invalid_count": maxi(0, int(preview_report.get("source_entity_count_raw", 0)) - int(coord_filter.get("kept", attached_count)) - int(coord_filter.get("filtered_out", 0))),
		"visible_client_zone_ids": zone_filter.get("visible_client_zone_ids", []),
		"mapping_basis_counts": mapping_basis_counts,
		"vertical_classification": vertical_counts,
		"vertical_thresholds_raw": {"ok_max_abs": 256.0, "suspect_max_abs": 1500.0, "bad_min_abs_exclusive": 1500.0},
		"mean_abs_vertical_delta_raw": mean_abs_delta,
		"max_abs_vertical_delta_raw": max_abs_delta,
		"server_z_vs_terrain_summary": _vertical_quality_summary(vertical_counts, attached_count, mean_abs_delta, max_abs_delta),
		"top_20_abs_vertical_delta_raw": top_vertical_deltas,
		"attached_entities": clean_entries,
		"source_preview_entity_count": int(preview_report.get("entity_count", attached_count)),
		"source_attach_ok": bool(attach_report.get("ok", attached_count > 0)),
	}


func _quality_entry_from_placeholder(node: Node) -> Dictionary:
	var entity: Dictionary = node.get_meta("entity", {}) as Dictionary
	var p: Dictionary = entity.get("position_daoc", {}) as Dictionary
	var local_preview: Dictionary = node.get_meta("position_daoc_local_preview", {}) as Dictionary
	var coordinate_space: String = str(entity.get("coordinate_space", ""))
	var folded: bool = bool(node.get_meta("coordinate_folded_preview", false))
	var source_region_id: int = int(entity.get("source_region_id", entity.get("region_id", 0)))
	var target_region_id: int = int(entity.get("target_region_id", entity.get("region_id", 0)))
	return {
		"entity_type": str(entity.get("entity_type", "unknown")),
		"source_table_id": str(entity.get("source_table_id", entity.get("source_table", ""))),
		"record_id": str(entity.get("source_record_id", entity.get("entity_id", ""))),
		"source_region_id": source_region_id,
		"target_region_id": target_region_id,
		"client_zone_id": int(node.get_meta("client_zone_id", -1)),
		"mapping_basis": str(node.get_meta("client_zone_mapping_basis", entity.get("client_zone_mapping_basis", ""))),
		"x_raw": float(p.get("x", 0.0)),
		"y_raw": float(p.get("y", 0.0)),
		"z_raw": float(p.get("z", node.get_meta("server_z_raw", 0.0))),
		"x_local_preview": float(local_preview.get("x", p.get("x", 0.0))),
		"y_local_preview": float(local_preview.get("y", p.get("y", 0.0))),
		"floor_z_raw": float(node.get_meta("floor_z_raw", p.get("z", 0.0))),
		"vertical_delta_raw": float(node.get_meta("vertical_delta_raw", 0.0)),
		"floor_snapped": bool(node.get_meta("floor_snapped_preview", false)),
		"region_global_projected": folded or coordinate_space == "server_region_global_xy_projected_to_client_loc",
		"local_coordinates": coordinate_space == "server_client_loc_xy_0_65535" or (not folded and _is_client_loc_axis(float(p.get("x", 0.0))) and _is_client_loc_axis(float(p.get("y", 0.0)))),
	}


func _vertical_quality_class(abs_delta: float) -> String:
	if abs_delta <= 256.0:
		return "ok"
	if abs_delta <= 1500.0:
		return "suspect"
	return "bad"


func _vertical_quality_summary(vertical_counts: Dictionary, total: int, mean_abs_delta: float, max_abs_delta: float) -> String:
	if total <= 0:
		return "no attached offline preview placeholder to measure"
	var bad_count: int = int(vertical_counts.get("bad", 0))
	var suspect_count: int = int(vertical_counts.get("suspect", 0))
	var ok_count: int = int(vertical_counts.get("ok", 0))
	if bad_count > 0:
		return "server Z is often far from sampled Godot terrain: ok=%d suspect=%d bad=%d mean_abs=%.1f max_abs=%.1f" % [ok_count, suspect_count, bad_count, mean_abs_delta, max_abs_delta]
	if suspect_count > 0:
		return "server Z is partially close but needs manual inspection: ok=%d suspect=%d bad=0 mean_abs=%.1f max_abs=%.1f" % [ok_count, suspect_count, mean_abs_delta, max_abs_delta]
	return "server Z is globally close to sampled Godot terrain: ok=%d suspect=0 bad=0 mean_abs=%.1f max_abs=%.1f" % [ok_count, mean_abs_delta, max_abs_delta]


func _sort_quality_entry_by_abs_delta_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("abs_vertical_delta_raw", 0.0)) > float(b.get("abs_vertical_delta_raw", 0.0))


func _zero_entity_type_counts() -> Dictionary:
	var out: Dictionary = {}
	for entity_type in ENTITY_TYPE_PRIORITY:
		out[str(entity_type)] = 0
	return out


func _report_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-17E2P offline world preview placeholders")
	lines.append("ok=%s entities=%d counts=%s regions=%s" % [
		str(report.get("ok", false)),
		int(report.get("entity_count", 0)),
		str(report.get("entity_counts", {})),
		str(report.get("region_counts", {})),
	])
	lines.append("offline_preview=%s server_authority=%s gameplay_fake=%s frame=%s spawn=%s" % [
		str(report.get("offline_preview", true)),
		str(report.get("server_authority", false)),
		str(report.get("gameplay_fake", false)),
		str(report.get("coordinate_frame_confirmed", false)),
		str(report.get("player_spawn_applied", false)),
	])
	var coord_filter: Dictionary = report.get("coordinate_range_filter", {}) as Dictionary
	if not coord_filter.is_empty():
		lines.append("client_loc_xy_filter enabled=%s range=%.0f..%.0f kept=%d filtered_out=%d local=%d region_global=%d skipped_regions=%s" % [
			str(coord_filter.get("enabled", false)),
			float(coord_filter.get("axis_min", CLIENT_LOC_AXIS_MIN)),
			float(coord_filter.get("axis_max", CLIENT_LOC_AXIS_MAX)),
			int(coord_filter.get("kept", 0)),
			int(coord_filter.get("filtered_out", 0)),
			int(coord_filter.get("local_coordinate_count", 0)),
			int(coord_filter.get("global_coordinate_count", 0)),
			str(coord_filter.get("skipped_by_region", {})),
		])
	var zone_filter: Dictionary = report.get("visible_client_zone_filter", {}) as Dictionary
	if not zone_filter.is_empty():
		lines.append("visible_zone_filter enabled=%s visible=%s filtered_out=%d skipped_regions=%s mapping=%s" % [
			str(zone_filter.get("enabled", false)),
			str(zone_filter.get("visible_client_zone_ids", [])),
			int(zone_filter.get("filtered_out", 0)),
			str(zone_filter.get("skipped_by_region", {})),
			str(zone_filter.get("kept_by_mapping_basis", {})),
		])
	var sample: Array = report.get("entities", []) as Array
	for i in range(mini(sample.size(), 12)):
		if typeof(sample[i]) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = sample[i] as Dictionary
		var p: Dictionary = entity.get("position_daoc", {}) as Dictionary
		lines.append("%s region=%d name=%s pos=(%.1f, %.1f, %.1f)" % [
			str(entity.get("entity_type", "")),
			int(entity.get("region_id", 0)),
			str(entity.get("display_name", "")),
			float(p.get("x", 0.0)),
			float(p.get("y", 0.0)),
			float(p.get("z", 0.0)),
		])
	return "\n".join(lines)


func _quality_report_as_text(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("P1-17F5 preview quality")
	lines.append("ok=%s attached=%d counts=%s floor_snapped=%d local=%d region_global_projected=%d loc_filtered=%d zone_filtered=%d invalid=%d" % [
		str(report.get("ok", false)),
		int(report.get("attached_placeholder_count", 0)),
		str(report.get("entity_counts", {})),
		int(report.get("floor_snapped_count", 0)),
		int(report.get("local_coordinate_count", 0)),
		int(report.get("region_global_projected_count", 0)),
		int(report.get("loc_filtered_count", 0)),
		int(report.get("zone_filtered_count", 0)),
		int(report.get("invalid_count", 0)),
	])
	lines.append("vertical=%s mean_abs_delta=%.1f max_abs_delta=%.1f" % [
		str(report.get("vertical_classification", {})),
		float(report.get("mean_abs_vertical_delta_raw", 0.0)),
		float(report.get("max_abs_vertical_delta_raw", 0.0)),
	])
	lines.append("summary=%s" % str(report.get("server_z_vs_terrain_summary", "")))
	lines.append("visible_zones=%s mapping=%s" % [
		str(report.get("visible_client_zone_ids", [])),
		str(report.get("mapping_basis_counts", {})),
	])
	lines.append("authority=%s fake=%s runtime=%s frame=%s spawn=%s" % [
		str(report.get("server_authority", false)),
		str(report.get("gameplay_fake", false)),
		str(report.get("runtime_enabled", false)),
		str(report.get("coordinate_frame_confirmed", false)),
		str(report.get("player_spawn_applied", false)),
	])
	lines.append("")
	lines.append("Top 20 abs(vertical_delta_raw)")
	var top_entries: Array = report.get("top_20_abs_vertical_delta_raw", []) as Array
	for i in range(top_entries.size()):
		if typeof(top_entries[i]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = top_entries[i] as Dictionary
		lines.append("%02d %s table=%s record=%s zone=%d basis=%s raw=(%.1f, %.1f, %.1f) local=(%.1f, %.1f) floor=%.1f delta=%.1f class=%s" % [
			i + 1,
			str(entry.get("entity_type", "")),
			str(entry.get("source_table_id", "")),
			str(entry.get("record_id", "")),
			int(entry.get("client_zone_id", -1)),
			str(entry.get("mapping_basis", "")),
			float(entry.get("x_raw", 0.0)),
			float(entry.get("y_raw", 0.0)),
			float(entry.get("z_raw", 0.0)),
			float(entry.get("x_local_preview", 0.0)),
			float(entry.get("y_local_preview", 0.0)),
			float(entry.get("floor_z_raw", 0.0)),
			float(entry.get("vertical_delta_raw", 0.0)),
			str(entry.get("vertical_classification", "")),
		])
	return "\n".join(lines)
