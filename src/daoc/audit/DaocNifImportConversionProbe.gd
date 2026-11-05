extends RefCounted
class_name DaocNifImportConversionProbe

const NifReaderScript = preload("res://src/nif/nif_reader.gd")

const CHECKPOINT: String = "P1_18N_HF6_NIF_IMPORT_CONVERSION_PROBE"
const DEFAULT_REPORT_DIR: String = "res://reports/p1_18n_nif_import_probe"
const DEFAULT_FOCUS_NIF_IDS: Array[int] = [408, 423, 424]
const DEFAULT_FOCUS_FILES: Array[String] = [
	"brghouse.nif", "bridge.nif", "camwall.nif", "keep.nif",
	"borderkeep1.nif", "A_PhouseGatein.nif"
]
const DEFAULT_FOCUS_TOKENS: Array[String] = [
	"bridge", "brg", "house", "gate", "wall", "keep", "tower", "door", "portal"
]


func default_options() -> Dictionary:
	return {
		"zone": 0,
		"write_csv": true,
		"write_json": true,
		"write_txt": true,
		"report_dir": DEFAULT_REPORT_DIR,
		"max_fixtures": 0,
		"focus_bridgehouse": true,
		"focus_nif_ids": DEFAULT_FOCUS_NIF_IDS,
		"focus_files": DEFAULT_FOCUS_FILES,
		"focus_tokens": DEFAULT_FOCUS_TOKENS,
		"probe_source_nifs": true,
		"max_source_probes": 160,
	}


func run_zone_probe(zone_viewer: Node, znum: int = 0, options: Dictionary = {}) -> Dictionary:
	var opts := default_options()
	for k in options.keys():
		opts[k] = options[k]
	opts["zone"] = znum
	var started := Time.get_ticks_msec()
	var report: Dictionary = {
		"scope": "P1-18N-HF6 NIF Import Conversion Probe & Anomaly Audit",
		"checkpoint": CHECKPOINT,
		"zone": znum,
		"ok": true,
		"non_destructive": true,
		"runtime_modified": false,
		"recommendation": "audit only: do not hand-fix brghouse; inspect systemic NIF conversion issues",
		"options": opts.duplicate(true),
		"paths": {},
		"summary": {},
		"fixtures": [],
		"anomalies": [],
		"focus_rows": [],
		"materials_rows": [],
		"source_probes": {},
		"brghouse": {},
		"warnings": [],
		"errors": [],
		"written_files": {},
	}
	var registry := _get_asset_registry(zone_viewer)
	if registry == null:
		report["ok"] = false
		(report["errors"] as Array).append("asset registry unavailable on ZoneViewer")
		return report
	var placement_path := _find_placement_path(registry, znum)
	(report["paths"] as Dictionary)["placement"] = placement_path
	var placement := _load_placement(placement_path)
	var model_index := _build_model_index(registry)
	var texture_index := _build_texture_index(registry)
	(report["paths"] as Dictionary)["model_index_size"] = model_index.size()
	(report["paths"] as Dictionary)["texture_index_size"] = texture_index.size()
	if placement.is_empty():
		report["ok"] = false
		(report["errors"] as Array).append("zone%03d placement JSON unavailable" % znum)
		_finish_report(report, opts, started)
		return report
	var rows := _build_fixture_rows(zone_viewer, znum, placement, model_index, texture_index, opts)
	report["fixtures"] = rows
	report["materials_rows"] = _build_material_rows(rows)
	if bool(opts.get("probe_source_nifs", true)):
		report["source_probes"] = _probe_source_nifs(rows, model_index, int(opts.get("max_source_probes", 160)))
		_apply_source_probe_anomalies(rows, report["source_probes"] as Dictionary)
	var anomalies := []
	var focus_rows := []
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		var flags := _detect_anomalies(row)
		row["anomaly_flags"] = flags
		row["anomaly"] = not flags.is_empty()
		row["severity"] = _severity_for_flags(flags)
		if bool(row.get("anomaly", false)):
			anomalies.append(row)
		if bool(row.get("focus", false)):
			focus_rows.append(row)
	report["anomalies"] = anomalies
	report["focus_rows"] = focus_rows
	report["brghouse"] = _brghouse_verdict(rows)
	report["summary"] = _build_summary(report)
	_finish_report(report, opts, started)
	return report


func summarize_for_console(report: Dictionary) -> String:
	var s: Dictionary = report.get("summary", {}) as Dictionary
	var brg: Dictionary = report.get("brghouse", {}) as Dictionary
	return "P1-18N-HF6 zone%03d fixtures=%d unique_nifs=%d anomalies=%d high=%d medium=%d brghouse=%s report=%s" % [
		int(report.get("zone", 0)),
		int(s.get("total_fixtures_inspected", 0)),
		int(s.get("total_unique_nifs_inspected", 0)),
		int(s.get("total_anomalies", 0)),
		int(s.get("high_severity_anomalies", 0)),
		int(s.get("medium_severity_anomalies", 0)),
		str(brg.get("verdict", "missing")),
		str((report.get("written_files", {}) as Dictionary).get("txt", "")),
	]


func apply_visual_debug(zone_viewer: Node, znum: int, target_fixture_id: int = 556, draw_aabb: bool = true, highlight: bool = true, label: bool = true) -> Dictionary:
	var out := {"ok": false, "fixture_id": target_fixture_id, "node_found": false, "non_destructive": true}
	if zone_viewer == null:
		out["reason"] = "no zone_viewer"
		return out
	var root := _runtime_root(zone_viewer, znum)
	var node := _find_node_by_fixture_meta(root, target_fixture_id)
	if node == null:
		node = root.find_child("f%d_*" % target_fixture_id, true, false)
	if node == null:
		out["reason"] = "fixture node not found"
		return out
	out["node_found"] = true
	var marker_root := root.get_node_or_null("P1_18N_HF6_NifProbeVisualDebug")
	if marker_root != null:
		marker_root.queue_free()
	marker_root = Node3D.new()
	marker_root.name = "P1_18N_HF6_NifProbeVisualDebug"
	root.add_child(marker_root)
	if highlight:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.05, 0.1, 0.86)
		for mi_value in node.find_children("*", "MeshInstance3D", true, false):
			var mi := mi_value as MeshInstance3D
			if mi != null:
				mi.material_overlay = mat
	if draw_aabb or label:
		var desc := _describe_runtime_node(node, {})
		var marker := Node3D.new()
		marker.name = "nifprobe_marker_%d" % target_fixture_id
		if node is Node3D:
			marker.global_transform = (node as Node3D).global_transform
		marker_root.add_child(marker)
		if draw_aabb:
			var box := MeshInstance3D.new()
			box.name = "AABB_%d" % target_fixture_id
			var mesh := BoxMesh.new()
			mesh.size = _parse_vec3(str(desc.get("local_aabb_size", "0,0,0")))
			box.mesh = mesh
			var box_mat := StandardMaterial3D.new()
			box_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			box_mat.albedo_color = Color(0.05, 1.0, 0.2, 0.28)
			box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			box.material_override = box_mat
			marker.add_child(box)
		if label:
			var lbl := Label3D.new()
			lbl.name = "Label_%d" % target_fixture_id
			lbl.text = "f%d brghouse" % target_fixture_id
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0.0, maxf(120.0, _parse_vec3(str(desc.get("local_aabb_size", "0,0,0"))).y + 80.0), 0.0)
			marker.add_child(lbl)
	out["ok"] = true
	out["node_path"] = str(node.get_path())
	return out


func _finish_report(report: Dictionary, opts: Dictionary, started: int) -> void:
	report["elapsed_ms"] = Time.get_ticks_msec() - started
	if bool(opts.get("write_csv", true)) or bool(opts.get("write_json", true)) or bool(opts.get("write_txt", true)):
		_write_reports(report, str(opts.get("report_dir", DEFAULT_REPORT_DIR)), opts)


func _build_fixture_rows(zone_viewer: Node, znum: int, placement: Dictionary, model_index: Dictionary, texture_index: Dictionary, opts: Dictionary) -> Array:
	var fixtures: Array = placement.get("fixtures", []) as Array
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var max_fixtures := int(opts.get("max_fixtures", 0))
	var rows: Array = []
	var inspected := 0
	for fx_raw in fixtures:
		if max_fixtures > 0 and inspected >= max_fixtures:
			break
		var fx: Dictionary = fx_raw as Dictionary
		var nif_id := int(fx.get("nif", -1))
		var filename := str(models.get(str(nif_id), models.get(nif_id, "")))
		if filename == "":
			filename = "nif_%d" % nif_id
		var row := _placement_row(fx, nif_id, filename)
		row["focus"] = _is_focus(row, opts)
		row["expected_ref_height"] = _model_ref_value(row, "Ref Height")
		row["expected_ref_width"] = _model_ref_value(row, "Ref Width")
		row["indexed_path"] = str(model_index.get(filename.get_basename().to_lower(), ""))
		row["texture_catalog_hint"] = _texture_hint(filename, texture_index)
		var node := _find_runtime_node(zone_viewer, znum, int(row.get("fixture_id", -1)), filename)
		var runtime := _describe_runtime_node(node, row)
		for k in runtime.keys():
			row[k] = runtime[k]
		rows.append(row)
		inspected += 1
	return rows


func _placement_row(fx: Dictionary, nif_id: int, filename: String) -> Dictionary:
	return {
		"fixture_id": int(fx.get("id", 0)),
		"nif_id": nif_id,
		"filename": filename,
		"node_path_runtime": "",
		"node_found": false,
		"visible": false,
		"mesh_instance_count": 0,
		"surface_count": 0,
		"material_count": 0,
		"vertex_count": 0,
		"triangle_count": 0,
		"albedo_texture_slots": 0,
		"local_aabb_pos": "0,0,0",
		"local_aabb_size": "0,0,0",
		"global_origin": "0,0,0",
		"daoc_x": float(fx.get("x", 0.0)),
		"daoc_y": float(fx.get("y", 0.0)),
		"daoc_z": float(fx.get("z", 0.0)),
		"daoc_a": float(fx.get("a", 0.0)),
		"daoc_scale": float(fx.get("scale", 1.0)),
		"daoc_ground": int(fx.get("ground", 0)),
	}


func _describe_runtime_node(node: Node, base_row: Dictionary) -> Dictionary:
	var out := {
		"node_found": node != null,
		"node_path_runtime": str(node.get_path()) if node != null else "",
		"visible": false,
		"mesh_instance_count": 0,
		"surface_count": 0,
		"material_count": 0,
		"vertex_count": 0,
		"triangle_count": 0,
		"albedo_texture_slots": 0,
		"local_aabb_pos": "0,0,0",
		"local_aabb_size": "0,0,0",
		"global_origin": "0,0,0",
		"runtime_scale": "0,0,0",
		"material_names": [],
	}
	if node == null:
		return out
	if node is Node3D:
		var n3d := node as Node3D
		out["visible"] = n3d.visible
		out["global_origin"] = _vec3_string(n3d.global_transform.origin)
		out["runtime_scale"] = _vec3_string(n3d.scale)
	var mesh_nodes := node.find_children("*", "MeshInstance3D", true, false)
	out["mesh_instance_count"] = mesh_nodes.size()
	var combined := AABB()
	var has_aabb := false
	var mat_names: Array[String] = []
	for mi_value in mesh_nodes:
		var mi := mi_value as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh_aabb := mi.mesh.get_aabb()
		if has_aabb:
			combined = combined.merge(mesh_aabb)
		else:
			combined = mesh_aabb
			has_aabb = true
		var surfaces := mi.mesh.get_surface_count()
		out["surface_count"] = int(out["surface_count"]) + surfaces
		for si in range(surfaces):
			var arrays := mi.mesh.surface_get_arrays(si)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				out["vertex_count"] = int(out["vertex_count"]) + (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				out["triangle_count"] = int(out["triangle_count"]) + int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
			var mat := mi.get_surface_override_material(si)
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			if mat != null:
				out["material_count"] = int(out["material_count"]) + 1
				if mat.resource_name != "" and not mat_names.has(mat.resource_name):
					mat_names.append(mat.resource_name)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				out["albedo_texture_slots"] = int(out["albedo_texture_slots"]) + 1
	if has_aabb:
		out["local_aabb_pos"] = _vec3_string(combined.position)
		out["local_aabb_size"] = _vec3_string(combined.size)
	out["material_names"] = mat_names
	return out


func _detect_anomalies(row: Dictionary) -> Array[String]:
	var flags: Array[String] = []
	var filename := str(row.get("filename", "")).to_lower()
	var size := _parse_vec3(str(row.get("local_aabb_size", "0,0,0")))
	var max_dim := maxf(size.x, maxf(size.y, size.z))
	var vertex_count := int(row.get("vertex_count", 0))
	var complex_name := _contains_any(filename, DEFAULT_FOCUS_TOKENS)
	if vertex_count > 500 and max_dim < 256.0:
		flags.append("vertex_count_gt_500_tiny_aabb")
	if vertex_count > 1000 and max_dim < 512.0:
		flags.append("vertex_count_gt_1000_small_aabb")
	if complex_name and max_dim < 512.0:
		flags.append("complex_model_tiny_aabb")
	var ref_h := float(row.get("expected_ref_height", 0.0))
	var ref_w := float(row.get("expected_ref_width", 0.0))
	var ref_max := maxf(ref_h, ref_w)
	if ref_max > 0.0 and max_dim > 0.0 and max_dim < ref_max * 0.35:
		flags.append("runtime_aabb_below_reference_size")
	if int(row.get("material_count", 0)) <= 1 and (vertex_count > 1000 or complex_name):
		flags.append("material_count_le_1_complex_model")
	if int(row.get("albedo_texture_slots", 0)) == 0 and vertex_count > 0:
		flags.append("no_albedo_texture_slots")
	if int(row.get("surface_count", 0)) == 1 and vertex_count > 1000:
		flags.append("single_surface_high_vertex_count")
	if not bool(row.get("node_found", false)):
		flags.append("node_found_false")
	if not bool(row.get("visible", false)) and bool(row.get("node_found", false)):
		flags.append("visible_false")
	if int(row.get("mesh_instance_count", 0)) == 0:
		flags.append("mesh_instance_count_0")
	if vertex_count == 0:
		flags.append("vertex_count_0")
	if max_dim <= 0.0 or is_nan(max_dim) or max_dim > 1000000.0:
		flags.append("local_aabb_size_aberrant")
	if absf(float(row.get("daoc_scale", 1.0)) - 1.0) > 4.0:
		flags.append("scale_unexpected")
	var source: Dictionary = row.get("source_probe", {}) as Dictionary
	if bool(source.get("source_probe_available", false)):
		var source_geometry_count := int(source.get("visible_geometry_node_count", 0))
		if source_geometry_count <= 0:
			source_geometry_count = int(source.get("geometry_node_count", 0))
		var runtime_surface_count := int(row.get("surface_count", 0))
		if source_geometry_count > 1 and int(row.get("mesh_instance_count", 0)) <= 1 and runtime_surface_count < source_geometry_count:
			flags.append("possible_hierarchy_or_children_loss")
		if int(source.get("children_count", 0)) > 0 and int(row.get("mesh_instance_count", 0)) <= 1 and runtime_surface_count < source_geometry_count:
			flags.append("possible_hierarchy_or_transform_loss")
	if str(row.get("texture_catalog_hint", "")) != "" and int(row.get("albedo_texture_slots", 0)) == 0:
		flags.append("texture_catalog_present_but_runtime_albedo_absent")
	return flags


func _severity_for_flags(flags: Array[String]) -> String:
	if flags.has("node_found_false") or flags.has("mesh_instance_count_0") or flags.has("vertex_count_0"):
		return "high"
	if flags.has("complex_model_tiny_aabb"):
		return "high"
	if flags.has("single_surface_high_vertex_count") or flags.has("no_albedo_texture_slots") or flags.has("runtime_aabb_below_reference_size"):
		return "medium"
	if flags.has("possible_hierarchy_or_transform_loss") or flags.has("possible_hierarchy_or_children_loss"):
		return "medium"
	if not flags.is_empty():
		return "low"
	return "none"


func _probe_source_nifs(rows: Array, model_index: Dictionary, max_source_probes: int) -> Dictionary:
	var out: Dictionary = {}
	var count := 0
	for row_value in rows:
		if max_source_probes > 0 and count >= max_source_probes:
			break
		var row: Dictionary = row_value as Dictionary
		var nif_id := str(int(row.get("nif_id", -1)))
		if out.has(nif_id):
			continue
		var filename := str(row.get("filename", ""))
		var path := str(model_index.get(filename.get_basename().to_lower(), ""))
		out[nif_id] = _probe_source_nif(path)
		count += 1
	return out


func _probe_source_nif(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"source_probe_available": false, "source_probe_reason": "indexed NIF path missing", "path": path}
	var reader: RefCounted = NifReaderScript.new()
	reader.set("quiet_errors", true)
	var ok := bool(reader.call("read", path))
	if not ok:
		return {
			"source_probe_available": false,
			"source_probe_reason": str(reader.get("fail_reason")),
			"path": path,
			"total_blocks": int((reader.get("blocks") as Array).size()) if typeof(reader.get("blocks")) == TYPE_ARRAY else 0,
		}
	var blocks: Array = reader.get("blocks") as Array
	var counts := {
		"source_probe_available": true,
		"source_probe_reason": "",
		"path": path,
		"total_blocks": blocks.size(),
		"node_count": 0,
		"geometry_node_count": 0,
		"visible_geometry_node_count": 0,
		"NiTriShape_count": 0,
		"NiTriStrips_count": 0,
		"texture_property_block_count": 0,
		"children_count": 0,
		"root_transform": "",
		"raw_aabb_before_transform": "",
		"aabb_after_cumulative_transform": "",
	}
	var raw_aabb := AABB()
	var has_raw := false
	for b_value in blocks:
		var b: Dictionary = b_value as Dictionary
		var t := str(b.get("type", ""))
		if t == "NiNode" or t == "NiLODNode":
			counts["node_count"] = int(counts["node_count"]) + 1
		if t == "NiTriShape" or t == "NiTriStrips":
			counts["geometry_node_count"] = int(counts["geometry_node_count"]) + 1
		if t == "NiTriShape":
			counts["NiTriShape_count"] = int(counts["NiTriShape_count"]) + 1
		if t == "NiTriStrips":
			counts["NiTriStrips_count"] = int(counts["NiTriStrips_count"]) + 1
		if t == "NiTexturingProperty" or t == "NiSourceTexture" or t == "NiMaterialProperty":
			counts["texture_property_block_count"] = int(counts["texture_property_block_count"]) + 1
		if b.has("children"):
			counts["children_count"] = int(counts["children_count"]) + (b.get("children", []) as Array).size()
		if counts["root_transform"] == "" and b.has("nif_transform"):
			counts["root_transform"] = str(b.get("nif_transform"))
		if b.has("vertices"):
			for v in b.get("vertices", []) as PackedVector3Array:
				var point_aabb := AABB(v, Vector3.ZERO)
				raw_aabb = raw_aabb.merge(point_aabb) if has_raw else point_aabb
				has_raw = true
	if has_raw:
		counts["raw_aabb_before_transform"] = "%s size=%s" % [_vec3_string(raw_aabb.position), _vec3_string(raw_aabb.size)]
	counts["aabb_after_cumulative_transform"] = "not_available_without_converter_walk"
	counts["visible_geometry_node_count"] = _source_visible_geometry_count(blocks)
	return counts


func _source_visible_geometry_count(blocks: Array) -> int:
	var visible_refs: Array[int] = []
	for b_value in blocks:
		var b: Dictionary = b_value as Dictionary
		var t := str(b.get("type", ""))
		if (t == "NiNode" or t == "NiBillboardNode" or t == "NiLODNode" or t == "NiSwitchNode") and str(b.get("name", "")).to_lower() == "visible":
			visible_refs.append(int(b.get("index", -1)))
	var visited: Dictionary = {}
	var geometry: Dictionary = {}
	for ref in visible_refs:
		_source_count_visible_walk(blocks, ref, visited, geometry)
	return geometry.size()


func _source_count_visible_walk(blocks: Array, ref: int, visited: Dictionary, geometry: Dictionary) -> void:
	if ref < 0:
		return
	var b := _source_block_for_ref(blocks, ref)
	if b.is_empty():
		return
	var idx := int(b.get("index", ref))
	if visited.has(str(idx)):
		return
	visited[str(idx)] = true
	var name := str(b.get("name", "")).strip_edges().to_lower()
	if _source_non_visual_name(name):
		return
	var t := str(b.get("type", ""))
	if t == "NiTriShape" or t == "NiTriStrips" or t == "NiParticles" or t == "NiAutoNormalParticles" or t == "NiRotatingParticles" or t == "NiParticleSystem":
		geometry[str(idx)] = true
		return
	for child in b.get("children", []) as Array:
		for candidate in [int(child), int(child) - 1]:
			var cb := _source_block_for_ref(blocks, candidate)
			if not cb.is_empty():
				_source_count_visible_walk(blocks, candidate, visited, geometry)


func _source_block_for_ref(blocks: Array, ref: int) -> Dictionary:
	if ref < 0:
		return {}
	if ref < blocks.size():
		var direct: Dictionary = blocks[ref] as Dictionary
		if int(direct.get("index", ref)) == ref:
			return direct
	for b_value in blocks:
		var b: Dictionary = b_value as Dictionary
		if int(b.get("index", -999999)) == ref:
			return b
	return {}


func _source_non_visual_name(name: String) -> bool:
	if name == "" or name == "collisionswitch":
		return false
	return name.begins_with("coll") or name.find("collision") >= 0 or name.find("emitter") >= 0 or name.find("gravity") >= 0 or name.begins_with("fire") or name.begins_with("anim")


func _apply_source_probe_anomalies(rows: Array, source_probes: Dictionary) -> void:
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		var key := str(int(row.get("nif_id", -1)))
		row["source_probe"] = source_probes.get(key, {"source_probe_available": false, "source_probe_reason": "not probed"})


func _build_material_rows(rows: Array) -> Array:
	var out: Array = []
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		out.append({
			"fixture_id": int(row.get("fixture_id", 0)),
			"nif_id": int(row.get("nif_id", -1)),
			"filename": str(row.get("filename", "")),
			"surface_count": int(row.get("surface_count", 0)),
			"material_count": int(row.get("material_count", 0)),
			"albedo_texture_slots": int(row.get("albedo_texture_slots", 0)),
			"material_names": row.get("material_names", []),
			"texture_catalog_hint": str(row.get("texture_catalog_hint", "")),
		})
	return out


func _build_summary(report: Dictionary) -> Dictionary:
	var rows: Array = report.get("fixtures", []) as Array
	var anomalies: Array = report.get("anomalies", []) as Array
	var unique: Dictionary = {}
	var high := 0
	var medium := 0
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		unique[str(int(row.get("nif_id", -1)))] = true
	for row_value in anomalies:
		var row: Dictionary = row_value as Dictionary
		if str(row.get("severity", "")) == "high":
			high += 1
		elif str(row.get("severity", "")) == "medium":
			medium += 1
	anomalies.sort_custom(func(a, b):
		var da := a as Dictionary
		var db := b as Dictionary
		var ra := _severity_rank(str(da.get("severity", "")))
		var rb := _severity_rank(str(db.get("severity", "")))
		if ra != rb:
			return ra > rb
		if bool(da.get("focus", false)) != bool(db.get("focus", false)):
			return bool(da.get("focus", false))
		return int(da.get("vertex_count", 0)) > int(db.get("vertex_count", 0))
	)
	return {
		"total_fixtures_inspected": rows.size(),
		"total_unique_nifs_inspected": unique.size(),
		"total_anomalies": anomalies.size(),
		"high_severity_anomalies": high,
		"medium_severity_anomalies": medium,
		"top_20_anomaly_candidates": _limit_array(anomalies, 20),
	}


func _brghouse_verdict(rows: Array) -> Dictionary:
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		if int(row.get("fixture_id", -1)) == 556 or int(row.get("nif_id", -1)) == 424 or str(row.get("filename", "")).to_lower() == "brghouse.nif":
			return {
				"fixture_id": int(row.get("fixture_id", -1)),
				"nif_id": int(row.get("nif_id", -1)),
				"filename": str(row.get("filename", "")),
				"node_found": bool(row.get("node_found", false)),
				"vertex_count": int(row.get("vertex_count", 0)),
				"local_aabb_size": str(row.get("local_aabb_size", "")),
				"anomaly": bool(row.get("anomaly", false)),
				"severity": str(row.get("severity", "none")),
				"reasons": row.get("anomaly_flags", []),
				"verdict": "anomaly" if bool(row.get("anomaly", false)) else "present_no_current_anomaly",
				"row": row,
			}
	return {"verdict": "missing", "fixture_id": 556, "nif_id": 424, "filename": "brghouse.nif", "reasons": ["brghouse fixture not found in inspected rows"]}


func _write_reports(report: Dictionary, report_dir: String, opts: Dictionary) -> void:
	_ensure_dir(report_dir)
	var zone := int(report.get("zone", 0))
	var json_path := report_dir.path_join("zone%03d_nif_import_probe.json" % zone)
	var txt_path := report_dir.path_join("zone%03d_nif_import_probe.txt" % zone)
	var all_csv := report_dir.path_join("zone%03d_nif_import_probe_all.csv" % zone)
	var anomalies_csv := report_dir.path_join("zone%03d_nif_import_probe_anomalies.csv" % zone)
	var focus_csv := report_dir.path_join("zone%03d_nif_import_probe_focus.csv" % zone)
	var brg_json := report_dir.path_join("zone%03d_nif_import_probe_brghouse.json" % zone)
	var materials_csv := report_dir.path_join("zone%03d_nif_import_probe_materials.csv" % zone)
	if bool(opts.get("write_json", true)):
		_write_text(json_path, JSON.stringify(report, "\t"))
		_write_text(brg_json, JSON.stringify(report.get("brghouse", {}), "\t"))
	if bool(opts.get("write_txt", true)):
		_write_text(txt_path, _format_text_report(report))
	if bool(opts.get("write_csv", true)):
		_write_any_rows_csv(all_csv, report.get("fixtures", []) as Array)
		_write_any_rows_csv(anomalies_csv, report.get("anomalies", []) as Array)
		_write_any_rows_csv(focus_csv, report.get("focus_rows", []) as Array)
		_write_any_rows_csv(materials_csv, report.get("materials_rows", []) as Array)
	report["written_files"] = {
		"json": ProjectSettings.globalize_path(json_path),
		"txt": ProjectSettings.globalize_path(txt_path),
		"all_csv": ProjectSettings.globalize_path(all_csv),
		"anomalies_csv": ProjectSettings.globalize_path(anomalies_csv),
		"focus_csv": ProjectSettings.globalize_path(focus_csv),
		"brghouse_json": ProjectSettings.globalize_path(brg_json),
		"materials_csv": ProjectSettings.globalize_path(materials_csv),
	}
	if bool(opts.get("write_json", true)):
		_write_text(json_path, JSON.stringify(report, "\t"))
	if bool(opts.get("write_txt", true)):
		_write_text(txt_path, _format_text_report(report))


func _format_text_report(report: Dictionary) -> String:
	var s: Dictionary = report.get("summary", {}) as Dictionary
	var b: Dictionary = report.get("brghouse", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("# P1-18N-HF6 NIF Import Conversion Probe")
	lines.append("")
	lines.append("total fixtures inspected: %d" % int(s.get("total_fixtures_inspected", 0)))
	lines.append("total unique NIFs inspected: %d" % int(s.get("total_unique_nifs_inspected", 0)))
	lines.append("total anomalies: %d" % int(s.get("total_anomalies", 0)))
	lines.append("high severity anomalies: %d" % int(s.get("high_severity_anomalies", 0)))
	lines.append("medium severity anomalies: %d" % int(s.get("medium_severity_anomalies", 0)))
	lines.append("")
	lines.append("dedicated brghouse verdict:")
	lines.append("brghouse.nif:")
	lines.append("- fixture_id=%d" % int(b.get("fixture_id", 556)))
	lines.append("- nif_id=%d" % int(b.get("nif_id", 424)))
	lines.append("- node_found=%s" % str(b.get("node_found", false)))
	lines.append("- vertex_count=%d" % int(b.get("vertex_count", 0)))
	lines.append("- local_aabb_size=%s" % str(b.get("local_aabb_size", "")))
	lines.append("- anomaly=%s" % str(b.get("anomaly", false)))
	lines.append("- severity=%s" % str(b.get("severity", "none")))
	lines.append("- reasons=%s" % str(b.get("reasons", [])))
	lines.append("")
	lines.append("top 20 anomaly candidates:")
	for row_value in s.get("top_20_anomaly_candidates", []) as Array:
		var row: Dictionary = row_value as Dictionary
		lines.append("- severity=%s fixture=%d nif=%d file=%s vertices=%d aabb=%s reasons=%s" % [
			str(row.get("severity", "")),
			int(row.get("fixture_id", 0)),
			int(row.get("nif_id", -1)),
			str(row.get("filename", "")),
			int(row.get("vertex_count", 0)),
			str(row.get("local_aabb_size", "")),
			str(row.get("anomaly_flags", [])),
		])
	lines.append("")
	lines.append("written files: %s" % str(report.get("written_files", {})))
	return "\n".join(lines) + "\n"


func _write_any_rows_csv(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var headers: Array[String] = []
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		for key in row.keys():
			if typeof(row.get(key)) != TYPE_DICTIONARY and not headers.has(str(key)):
				headers.append(str(key))
	headers.sort()
	f.store_line(";".join(headers))
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		var cells: Array[String] = []
		for h in headers:
			cells.append(_csv(row.get(h, "")))
		f.store_line(";".join(cells))
	f.close()


func _get_asset_registry(zone_viewer: Node) -> RefCounted:
	if zone_viewer == null:
		return null
	if zone_viewer.has_method("get_asset_index_registry_15d"):
		return zone_viewer.call("get_asset_index_registry_15d") as RefCounted
	var v: Variant = zone_viewer.get("_asset_index_registry_obj")
	return v as RefCounted if v is RefCounted else null


func _find_placement_path(registry: RefCounted, znum: int) -> String:
	var candidates: Array[String] = []
	if registry != null and registry.has_method("data_path"):
		candidates.append(str(registry.call("data_path", "zone%03d_placement.json" % znum)))
	if registry != null and registry.has_method("find_zone_dat_asset"):
		candidates.append(str(registry.call("find_zone_dat_asset", znum, "placement.json")))
	for p in candidates:
		if p != "" and p.get_file().to_lower().find("placement") >= 0 and FileAccess.file_exists(p):
			return p
	return ""


func _load_placement(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _build_model_index(registry: RefCounted) -> Dictionary:
	if registry != null and registry.has_method("ensure_model_index"):
		registry.call("ensure_model_index")
	var idx: Variant = registry.get("_model_index") if registry != null else {}
	if typeof(idx) == TYPE_DICTIONARY and (idx as Dictionary).size() > 0:
		return idx as Dictionary
	var out: Dictionary = {}
	var snap: Dictionary = registry.call("status_snapshot") as Dictionary if registry != null and registry.has_method("status_snapshot") else {}
	for d in snap.get("model_search_dirs", []) as Array:
		_scan_dir_for_index(str(d), [".nif"], out)
	return out


func _build_texture_index(registry: RefCounted) -> Dictionary:
	if registry != null and registry.has_method("ensure_texture_index"):
		registry.call("ensure_texture_index")
	var idx: Variant = registry.get("_texture_index") if registry != null else {}
	if typeof(idx) == TYPE_DICTIONARY and (idx as Dictionary).size() > 0:
		return idx as Dictionary
	var out: Dictionary = {}
	var snap: Dictionary = registry.call("status_snapshot") as Dictionary if registry != null and registry.has_method("status_snapshot") else {}
	for d in snap.get("texture_search_dirs", []) as Array:
		_scan_dir_for_index(str(d), [".png", ".tga", ".bmp", ".dds"], out)
	return out


func _scan_dir_for_index(path: String, extensions: Array, out: Dictionary) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if da.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir_for_index(path.path_join(fname), extensions, out)
		else:
			var low := fname.to_lower()
			for ext in extensions:
				if low.ends_with(str(ext)):
					var stem := fname.get_basename().to_lower()
					if not out.has(stem):
						out[stem] = path.path_join(fname)
					break
		fname = da.get_next()
	da.list_dir_end()


func _find_runtime_node(zone_viewer: Node, znum: int, fixture_id: int, filename: String) -> Node:
	var root := _runtime_root(zone_viewer, znum)
	var expected := "f%d_%s" % [fixture_id, filename.get_basename()]
	var node := root.find_child(expected, true, false)
	if node != null:
		return node
	return _find_node_by_fixture_meta(root, fixture_id)


func _runtime_root(zone_viewer: Node, znum: int) -> Node:
	if zone_viewer == null:
		return null
	var root := zone_viewer.find_child("Zone%03d_Root" % znum, true, false)
	return root if root != null else zone_viewer


func _find_node_by_fixture_meta(root: Node, fixture_id: int) -> Node:
	if root == null:
		return null
	for n_value in root.find_children("*", "Node3D", true, false):
		var n := n_value as Node
		if n != null and n.has_meta("fixture_id") and int(n.get_meta("fixture_id")) == fixture_id:
			return n
	return null


func _is_focus(row: Dictionary, opts: Dictionary) -> bool:
	var nif_id := int(row.get("nif_id", -1))
	var filename := str(row.get("filename", "")).to_lower()
	if (opts.get("focus_nif_ids", []) as Array).has(nif_id):
		return true
	for f in opts.get("focus_files", []) as Array:
		if filename == str(f).to_lower():
			return true
	for t in opts.get("focus_tokens", []) as Array:
		if filename.find(str(t).to_lower()) >= 0:
			return true
	return false


func _model_ref_value(_row: Dictionary, _key: String) -> float:
	return 0.0


func _texture_hint(filename: String, texture_index: Dictionary) -> String:
	var stem := filename.get_basename().to_lower()
	var hints: Array[String] = []
	for key in texture_index.keys():
		var k := str(key).to_lower()
		if k.find(stem) >= 0 or stem.find(k) >= 0:
			hints.append(k)
			if hints.size() >= 5:
				break
	return ",".join(hints)


func _contains_any(value: String, tokens: Array[String]) -> bool:
	for t in tokens:
		if value.find(t) >= 0:
			return true
	return false


func _severity_rank(value: String) -> int:
	match value:
		"high":
			return 3
		"medium":
			return 2
		"low":
			return 1
		_:
			return 0


func _limit_array(values: Array, max_items: int) -> Array:
	var out: Array = []
	for i in range(min(values.size(), max_items)):
		out.append(values[i])
	return out


func _parse_vec3(value: String) -> Vector3:
	var parts := value.split(",", false)
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _vec3_string(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()


func _csv(value: Variant) -> String:
	var s := str(value).replace("\n", " ").replace("\r", " ").replace("\"", "'")
	if s.find(";") >= 0 or s.find(",") >= 0:
		return "\"%s\"" % s
	return s
