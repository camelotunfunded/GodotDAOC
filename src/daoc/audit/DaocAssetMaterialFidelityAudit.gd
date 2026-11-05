extends RefCounted
class_name DaocAssetMaterialFidelityAudit

## P1-18N — audit non destructif géométrie/materials zone000.
## Objectif: diagnostiquer modèles manquants, candidats critiques (pont/Camelot/Cotswold)
## et textures secondaires/lightmaps ignorées sans modifier le rendu runtime.

const CHECKPOINT: String = "P1_18N_ASSET_MATERIAL_FIDELITY_AUDIT"
const DEFAULT_REPORT_DIR: String = "res://reports/p1_18n_asset_material_audit"
const DEFAULT_CRITICAL_TOKENS: Array[String] = [
	"bridge", "bridg", "brg", "brghouse", "bridgehouse", "pont", "camelot", "cotswold", "cots", "road", "gate", "wall", "entrance", "keep"
]
const DEFAULT_TARGET_NIF_IDS: Array[int] = [408, 423, 424]
const DEFAULT_TARGET_FILES: Array[String] = ["bridge.nif", "camwall.nif", "brghouse.nif"]
const DEFAULT_FOCUS_RECT: Dictionary = {
	"x_min": 3000.0,
	"x_max": 12000.0,
	"y_min": 24000.0,
	"y_max": 32000.0,
}

func default_options() -> Dictionary:
	return {
		"zone": 0,
		"write_reports": true,
		"scan_model_index": true,
		"scan_texture_index": true,
		"inspect_runtime_materials": true,
		"load_missing_candidate_models": false,
		"max_model_loads": 32,
		"max_texture_samples": 250,
		"max_runtime_material_nodes": 1600,
		"report_dir": DEFAULT_REPORT_DIR,
		"critical_tokens": DEFAULT_CRITICAL_TOKENS,
		"target_nif_ids": DEFAULT_TARGET_NIF_IDS,
		"target_files": DEFAULT_TARGET_FILES,
		"focus_rect": DEFAULT_FOCUS_RECT.duplicate(true),
	}

func run_zone_audit(zone_viewer: Node, znum: int = 0, options: Dictionary = {}) -> Dictionary:
	var opts: Dictionary = default_options()
	for k in options.keys():
		opts[k] = options[k]
	opts["zone"] = znum

	var started_msec: int = Time.get_ticks_msec()
	var report: Dictionary = {
		"scope": "P1-18N Asset & Material Fidelity Audit",
		"checkpoint": CHECKPOINT,
		"zone": znum,
		"ok": true,
		"non_destructive": true,
		"runtime_modified": false,
		"geometry_fix_applied": false,
		"material_fix_applied": false,
		"recommendation": "audit only: use missing/candidate reports before fixing bridge or materials",
		"options": opts.duplicate(true),
		"paths": {},
		"asset_registry": {},
		"placement": {},
		"models": {},
		"critical_candidates": {},
		"critical_placements": {},
		"critical_runtime": {},
		"focus_rect_placements": {},
		"focus_rect_runtime": {},
		"runtime_scene": {},
		"textures": {},
		"runtime_materials": {},
		"warnings": [],
		"errors": [],
		"written_files": {},
	}

	var registry: RefCounted = _get_asset_registry(zone_viewer)
	if registry == null:
		report["ok"] = false
		(report["errors"] as Array).append("asset registry unavailable on ZoneViewer")
		return report

	report["asset_registry"] = _registry_snapshot(registry)
	var placement_path: String = _find_placement_path(registry, znum)
	(report["paths"] as Dictionary)["placement"] = placement_path
	var placement: Dictionary = _load_placement(placement_path)
	var placement_status: Dictionary = _summarize_placement(placement_path, placement)
	report["placement"] = placement_status

	var model_index: Dictionary = {}
	if bool(opts.get("scan_model_index", true)):
		model_index = _build_model_index(registry)
	var source_model_report: Dictionary = _audit_source_models(placement, model_index)
	report["models"] = source_model_report
	report["critical_candidates"] = _find_critical_candidates(
		placement,
		model_index,
		opts.get("critical_tokens", DEFAULT_CRITICAL_TOKENS) as Array,
		opts.get("target_nif_ids", DEFAULT_TARGET_NIF_IDS) as Array,
		opts.get("target_files", DEFAULT_TARGET_FILES) as Array
	)
	report["critical_placements"] = _inspect_critical_placements(placement, report["critical_candidates"] as Dictionary)
	report["focus_rect_placements"] = _inspect_focus_rect_placements(
		placement,
		model_index,
		opts.get("focus_rect", DEFAULT_FOCUS_RECT) as Dictionary,
		opts.get("target_nif_ids", DEFAULT_TARGET_NIF_IDS) as Array,
		opts.get("target_files", DEFAULT_TARGET_FILES) as Array
	)

	if bool(opts.get("inspect_runtime_materials", true)):
		report["runtime_scene"] = _inspect_runtime_scene(zone_viewer, znum)
		report["critical_runtime"] = _inspect_critical_runtime(zone_viewer, znum, report["critical_placements"] as Dictionary)
		report["focus_rect_runtime"] = _inspect_critical_runtime(zone_viewer, znum, report["focus_rect_placements"] as Dictionary)
		report["runtime_materials"] = _inspect_runtime_materials(zone_viewer, znum, int(opts.get("max_runtime_material_nodes", 1600)))
	else:
		report["runtime_scene"] = {"skipped": true}
		report["critical_runtime"] = {"skipped": true}
		report["focus_rect_runtime"] = {"skipped": true}
		report["runtime_materials"] = {"skipped": true}

	if bool(opts.get("scan_texture_index", true)):
		var texture_index: Dictionary = _build_texture_index(registry)
		report["textures"] = _audit_textures(texture_index, int(opts.get("max_texture_samples", 250)))
	else:
		report["textures"] = {"skipped": true, "texture_index_size": 0}

	if placement_path == "":
		(report["warnings"] as Array).append("zone placement JSON not found; audit is structural only")
	if int((report["models"] as Dictionary).get("source_model_count", 0)) == 0:
		(report["warnings"] as Array).append("no source model references found for zone%03d" % znum)

	report["elapsed_ms"] = Time.get_ticks_msec() - started_msec
	if bool(opts.get("write_reports", true)):
		_write_reports(report, str(opts.get("report_dir", DEFAULT_REPORT_DIR)))
	return report

func summarize_for_console(report: Dictionary) -> String:
	var placement: Dictionary = report.get("placement", {}) as Dictionary
	var models: Dictionary = report.get("models", {}) as Dictionary
	var crit: Dictionary = report.get("critical_candidates", {}) as Dictionary
	var textures: Dictionary = report.get("textures", {}) as Dictionary
	var runtime_scene: Dictionary = report.get("runtime_scene", {}) as Dictionary
	var focus: Dictionary = report.get("focus_rect_placements", {}) as Dictionary
	return "P1-18N zone%03d ok=%s fixtures=%d source_models=%d missing_by_index=%d critical=%d critical_missing=%d focus_rows=%d exported=%d texture_index=%d lightmap_candidates=%d report=%s" % [
		int(report.get("zone", 0)),
		str(report.get("ok", false)),
		int(placement.get("fixture_count", 0)),
		int(models.get("source_model_count", 0)),
		int(models.get("missing_by_model_index_count", 0)),
		int(crit.get("candidate_count", 0)),
		int(crit.get("missing_candidate_count", 0)),
		int(focus.get("row_count", 0)),
		int(runtime_scene.get("exported_prop_static_count", 0)),
		int(textures.get("texture_index_size", 0)),
		int(textures.get("lightmap_candidate_count", 0)),
		str((report.get("written_files", {}) as Dictionary).get("txt", "")),
	]

func _get_asset_registry(zone_viewer: Node) -> RefCounted:
	if zone_viewer == null:
		return null
	if zone_viewer.has_method("get_asset_index_registry_15d"):
		return zone_viewer.call("get_asset_index_registry_15d") as RefCounted
	var v: Variant = zone_viewer.get("_asset_index_registry_obj")
	if v is RefCounted:
		return v as RefCounted
	return null

func _registry_snapshot(registry: RefCounted) -> Dictionary:
	if registry != null and registry.has_method("status_snapshot"):
		return registry.call("status_snapshot") as Dictionary
	return {"present": registry != null}

func _find_placement_path(registry: RefCounted, znum: int) -> String:
	if registry == null:
		return ""
	var candidates: Array[String] = []
	if registry.has_method("data_path"):
		candidates.append(str(registry.call("data_path", "zone%03d_placement.json" % znum)))
	if registry.has_method("find_zone_dat_asset"):
		candidates.append(str(registry.call("find_zone_dat_asset", znum, "placement.json")))
		candidates.append(str(registry.call("find_zone_dat_asset", znum, "fixtures.csv")))
	for p in candidates:
		if p != "" and p.get_file().to_lower().find("placement") >= 0 and FileAccess.file_exists(p):
			return p
	# Fallback : only return a placement JSON, not fixtures.csv.
	for p in candidates:
		if p != "" and p.get_file().to_lower().find("placement") >= 0:
			return p
	return ""

func _load_placement(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}

func _summarize_placement(path: String, placement: Dictionary) -> Dictionary:
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var fixtures: Array = placement.get("fixtures", []) as Array
	return {
		"path": path,
		"exists": path != "" and FileAccess.file_exists(path),
		"loaded": not placement.is_empty(),
		"model_table_count": models.size(),
		"fixture_count": fixtures.size(),
	}

func _build_model_index(registry: RefCounted) -> Dictionary:
	if registry != null and registry.has_method("ensure_model_index"):
		registry.call("ensure_model_index")
	var idx: Variant = registry.get("_model_index") if registry != null else {}
	if typeof(idx) == TYPE_DICTIONARY and (idx as Dictionary).size() > 0:
		return idx as Dictionary
	# Public fallback: private registry dictionaries are not always visible through Object.get().
	# Rebuild a read-only index from the registry status search dirs so the audit can be trusted.
	var out: Dictionary = {}
	var snap: Dictionary = _registry_snapshot(registry)
	var dirs: Array = snap.get("model_search_dirs", []) as Array
	var want_ext: String = ".nif" if bool(snap.get("use_nif_reader", true)) else ".glb"
	for d in dirs:
		_scan_dir_for_index(str(d), [want_ext], out, false)
	return out

func _build_texture_index(registry: RefCounted) -> Dictionary:
	if registry != null and registry.has_method("ensure_texture_index"):
		registry.call("ensure_texture_index")
	var idx: Variant = registry.get("_texture_index") if registry != null else {}
	if typeof(idx) == TYPE_DICTIONARY and (idx as Dictionary).size() > 0:
		return idx as Dictionary
	var out: Dictionary = {}
	var snap: Dictionary = _registry_snapshot(registry)
	var dirs: Array = snap.get("texture_search_dirs", []) as Array
	for d in dirs:
		_scan_dir_for_index(str(d), [".png", ".tga", ".bmp", ".dds"], out, true)
	return out

func _scan_dir_for_index(path: String, extensions: Array, out: Dictionary, prefer_texture_rank: bool) -> void:
	if path == "":
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if da.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir_for_index(path.path_join(fname), extensions, out, prefer_texture_rank)
		else:
			var low := fname.to_lower()
			var matched := false
			for ext_value in extensions:
				if low.ends_with(str(ext_value)):
					matched = true
					break
			if matched:
				var stem := fname.get_basename().to_lower()
				var full_path := path.path_join(fname)
				if not out.has(stem):
					out[stem] = full_path
				elif prefer_texture_rank:
					var cur: String = str(out.get(stem, ""))
					if _img_rank(low) > _img_rank(cur.get_file().to_lower()):
						out[stem] = full_path
		fname = da.get_next()
	da.list_dir_end()

func _img_rank(filename: String) -> int:
	var n := filename.to_lower()
	# When several converted/source textures share the same stem, prefer the
	# original DDS because DAoC material fidelity depends on DDS alpha/mip data.
	if n.ends_with(".dds"):
		return 100
	if n.ends_with(".png"):
		return 80
	if n.ends_with(".tga"):
		return 70
	if n.ends_with(".webp"):
		return 60
	if n.ends_with(".jpg") or n.ends_with(".jpeg"):
		return 50
	if n.ends_with(".bmp"):
		return 40
	return 0

func _audit_source_models(placement: Dictionary, model_index: Dictionary) -> Dictionary:
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var fixtures: Array = placement.get("fixtures", []) as Array
	var used_nif_ids: Dictionary = {}
	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		used_nif_ids[str(int(fx.get("nif", -1)))] = true
	var rows: Array = []
	var missing_rows: Array = []
	for id_value in models.keys():
		var nif_id: String = str(id_value)
		var filename: String = str(models.get(id_value, ""))
		var stem: String = filename.get_basename().to_lower()
		var indexed_path: String = str(model_index.get(stem, ""))
		var used: bool = used_nif_ids.has(nif_id)
		var row: Dictionary = {
			"nif_id": nif_id,
			"file": filename,
			"stem": stem,
			"used_by_fixture": used,
			"indexed": indexed_path != "",
			"indexed_path": indexed_path,
		}
		rows.append(row)
		if indexed_path == "":
			missing_rows.append(row)
	rows.sort_custom(func(a, b): return str(a.get("stem", "")) < str(b.get("stem", "")))
	missing_rows.sort_custom(func(a, b): return str(a.get("stem", "")) < str(b.get("stem", "")))
	return {
		"source_model_count": models.size(),
		"used_model_id_count": used_nif_ids.size(),
		"model_index_size": model_index.size(),
		"missing_by_model_index_count": missing_rows.size(),
		"source_model_rows": rows,
		"missing_by_model_index": missing_rows,
	}

func _find_critical_candidates(placement: Dictionary, model_index: Dictionary, token_values: Array, target_nif_values: Array = [], target_file_values: Array = []) -> Dictionary:
	var tokens: Array[String] = []
	for t in token_values:
		var token: String = str(t).strip_edges().to_lower()
		if token != "" and not tokens.has(token):
			tokens.append(token)
	var target_nif_ids: Dictionary = _target_nif_id_dict(target_nif_values)
	var target_files: Dictionary = _target_file_dict(target_file_values)
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var fixtures: Array = placement.get("fixtures", []) as Array
	var fixture_count_by_nif: Dictionary = {}
	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		var nif_id: String = str(int(fx.get("nif", -1)))
		fixture_count_by_nif[nif_id] = int(fixture_count_by_nif.get(nif_id, 0)) + 1
	var rows: Array = []
	var missing: Array = []
	for id_value in models.keys():
		var nif_id: String = str(id_value)
		var filename: String = str(models.get(id_value, ""))
		var low: String = filename.to_lower()
		var stem_low: String = filename.get_basename().to_lower()
		var matched: Array[String] = []
		for token in tokens:
			if low.find(token) >= 0:
				matched.append(token)
		var target_hit := false
		if target_nif_ids.has(str(int(nif_id))):
			target_hit = true
			matched.append("target_nif_id")
		if target_files.has(low) or target_files.has(stem_low):
			target_hit = true
			matched.append("target_file")
		if matched.is_empty() and not target_hit:
			continue
		var stem: String = filename.get_basename().to_lower()
		var indexed_path: String = str(model_index.get(stem, ""))
		var row := {
			"nif_id": nif_id,
			"file": filename,
			"matched_tokens": matched,
			"fixture_count": int(fixture_count_by_nif.get(nif_id, 0)),
			"indexed": indexed_path != "",
			"indexed_path": indexed_path,
		}
		rows.append(row)
		if indexed_path == "":
			missing.append(row)
	rows.sort_custom(func(a, b): return str(a.get("file", "")) < str(b.get("file", "")))
	return {
		"tokens": tokens,
		"candidate_count": rows.size(),
		"missing_candidate_count": missing.size(),
		"candidates": rows,
		"missing_candidates": missing,
	}

func _target_nif_id_dict(values: Array) -> Dictionary:
	var out: Dictionary = {}
	for v in values:
		var id_value := int(v)
		if id_value >= 0:
			out[str(id_value)] = true
	return out

func _target_file_dict(values: Array) -> Dictionary:
	var out: Dictionary = {}
	for v in values:
		var low := str(v).strip_edges().to_lower()
		if low == "":
			continue
		out[low] = true
		out[low.get_basename()] = true
	return out

func _inspect_focus_rect_placements(placement: Dictionary, model_index: Dictionary, rect: Dictionary, target_nif_values: Array, target_file_values: Array) -> Dictionary:
	var x_min := float(rect.get("x_min", 3000.0))
	var x_max := float(rect.get("x_max", 12000.0))
	var y_min := float(rect.get("y_min", 24000.0))
	var y_max := float(rect.get("y_max", 32000.0))
	if x_min > x_max:
		var tmp_x := x_min
		x_min = x_max
		x_max = tmp_x
	if y_min > y_max:
		var tmp_y := y_min
		y_min = y_max
		y_max = tmp_y
	var target_nif_ids := _target_nif_id_dict(target_nif_values)
	var target_files := _target_file_dict(target_file_values)
	var fixtures: Array = placement.get("fixtures", []) as Array
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var rows: Array = []
	var rect_count := 0
	var target_count := 0
	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		var nif_id := str(int(fx.get("nif", -1)))
		var file := str(models.get(nif_id, ""))
		var low := file.to_lower()
		var stem_low := file.get_basename().to_lower()
		var x := float(fx.get("x", 0.0))
		var y := float(fx.get("y", 0.0))
		var in_rect := x >= x_min and x <= x_max and y >= y_min and y <= y_max
		var is_target := target_nif_ids.has(nif_id) or target_files.has(low) or target_files.has(stem_low)
		if not in_rect and not is_target:
			continue
		if in_rect:
			rect_count += 1
		if is_target:
			target_count += 1
		var reason: Array[String] = []
		if in_rect:
			reason.append("focus_rect")
		if is_target:
			reason.append("target_bridge_camwall_brghouse")
		var stem := file.get_basename().to_lower()
		rows.append({
			"fixture_id": int(fx.get("id", 0)),
			"nif_id": int(fx.get("nif", -1)),
			"file": file,
			"stem": stem,
			"reason": reason,
			"in_focus_rect": in_rect,
			"is_target": is_target,
			"indexed": str(model_index.get(stem, "")) != "",
			"indexed_path": str(model_index.get(stem, "")),
			"x": x,
			"y": y,
			"z": float(fx.get("z", 0.0)),
			"a": float(fx.get("a", 0.0)),
			"scale": float(fx.get("scale", 1.0)),
			"ground": int(fx.get("ground", 0)),
		})
	rows.sort_custom(func(a, b): return int(a.get("fixture_id", 0)) < int(b.get("fixture_id", 0)))
	return {
		"rect": {"x_min": x_min, "x_max": x_max, "y_min": y_min, "y_max": y_max},
		"row_count": rows.size(),
		"focus_rect_fixture_count": rect_count,
		"target_fixture_count": target_count,
		"target_nif_ids": target_nif_values,
		"target_files": target_file_values,
		"rows": rows,
	}

func _inspect_critical_placements(placement: Dictionary, critical_candidates: Dictionary) -> Dictionary:
	var candidates: Array = critical_candidates.get("candidates", []) as Array
	var candidate_by_nif: Dictionary = {}
	for item_value in candidates:
		var item: Dictionary = item_value as Dictionary
		candidate_by_nif[str(item.get("nif_id", ""))] = item
	var fixtures: Array = placement.get("fixtures", []) as Array
	var models: Dictionary = placement.get("models", {}) as Dictionary
	var rows: Array = []
	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		var nif_id := str(int(fx.get("nif", -1)))
		if not candidate_by_nif.has(nif_id):
			continue
		var file := str(models.get(nif_id, ""))
		var cand: Dictionary = candidate_by_nif[nif_id] as Dictionary
		rows.append({
			"fixture_id": int(fx.get("id", 0)),
			"nif_id": int(fx.get("nif", -1)),
			"file": file,
			"matched_tokens": cand.get("matched_tokens", []),
			"x": float(fx.get("x", 0.0)),
			"y": float(fx.get("y", 0.0)),
			"z": float(fx.get("z", 0.0)),
			"a": float(fx.get("a", 0.0)),
			"scale": float(fx.get("scale", 1.0)),
			"ground": int(fx.get("ground", 0)),
		})
	rows.sort_custom(func(a, b): return int(a.get("fixture_id", 0)) < int(b.get("fixture_id", 0)))
	return {
		"critical_fixture_count": rows.size(),
		"rows": rows,
	}

func _inspect_critical_runtime(zone_viewer: Node, znum: int, critical_placements: Dictionary) -> Dictionary:
	if zone_viewer == null:
		return {"ok": false, "reason": "no zone_viewer"}
	var root: Node = zone_viewer.find_child("Zone%03d_Root" % znum, true, false)
	if root == null:
		root = zone_viewer
	var props_root: Node = root.find_child("StaticPropsRoot", true, false)
	if props_root == null:
		props_root = root
	var rows: Array = []
	var missing_node_count := 0
	var zero_mesh_count := 0
	var zero_vertex_count := 0
	for row_value in critical_placements.get("rows", []) as Array:
		var placement_row: Dictionary = row_value as Dictionary
		var fixture_id := int(placement_row.get("fixture_id", 0))
		var file := str(placement_row.get("file", ""))
		var expected_name := "f%d_%s" % [fixture_id, file.get_basename()]
		var node := props_root.find_child(expected_name, true, false)
		if node == null:
			node = _find_node_by_fixture_meta(props_root, fixture_id)
		var desc := _describe_prop_node(zone_viewer, node, placement_row)
		desc["expected_name"] = expected_name
		rows.append(desc)
		if not bool(desc.get("node_found", false)):
			missing_node_count += 1
		if int(desc.get("mesh_instance_count", 0)) == 0:
			zero_mesh_count += 1
		if int(desc.get("vertex_count", 0)) == 0:
			zero_vertex_count += 1
	return {
		"ok": true,
		"critical_runtime_count": rows.size(),
		"missing_node_count": missing_node_count,
		"zero_mesh_count": zero_mesh_count,
		"zero_vertex_count": zero_vertex_count,
		"rows": rows,
	}

func _find_node_by_fixture_meta(root: Node, fixture_id: int) -> Node:
	if root == null:
		return null
	var nodes: Array = root.find_children("*", "Node3D", true, false)
	for node_value in nodes:
		var n: Node = node_value as Node
		if n != null and n.has_meta("fixture_id") and int(n.get_meta("fixture_id")) == fixture_id:
			return n
	return null

func _describe_prop_node(zone_viewer: Node, node: Node, placement_row: Dictionary) -> Dictionary:
	var out: Dictionary = placement_row.duplicate(true)
	out["node_found"] = node != null
	out["node_name"] = node.name if node != null else ""
	out["node_path"] = str(node.get_path()) if node != null else ""
	out["visible"] = false
	out["global_origin"] = ""
	out["mesh_instance_count"] = 0
	out["surface_count"] = 0
	out["vertex_count"] = 0
	out["material_count"] = 0
	out["albedo_texture_slots"] = 0
	out["mesh_samples"] = []
	if node == null:
		return out
	if node is Node3D:
		var n3d: Node3D = node as Node3D
		out["visible"] = n3d.visible
		out["global_origin"] = _vec3_string(n3d.global_transform.origin)
	var mesh_nodes: Array = node.find_children("*", "MeshInstance3D", true, false)
	out["mesh_instance_count"] = mesh_nodes.size()
	var samples: Array = []
	for mi_value in mesh_nodes:
		var mi: MeshInstance3D = mi_value as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh_vertices := 0
		var mesh_surfaces := mi.mesh.get_surface_count()
		out["surface_count"] = int(out.get("surface_count", 0)) + mesh_surfaces
		for si in range(mesh_surfaces):
			var arrays: Array = mi.mesh.surface_get_arrays(si)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
				if vertices is PackedVector3Array:
					mesh_vertices += (vertices as PackedVector3Array).size()
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			if mat != null:
				out["material_count"] = int(out.get("material_count", 0)) + 1
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				out["albedo_texture_slots"] = int(out.get("albedo_texture_slots", 0)) + 1
		out["vertex_count"] = int(out.get("vertex_count", 0)) + mesh_vertices
		if samples.size() < 8:
			var aabb: AABB = mi.mesh.get_aabb()
			samples.append({
				"mesh_node": mi.name,
				"surfaces": mesh_surfaces,
				"vertices": mesh_vertices,
				"local_aabb_pos": _vec3_string(aabb.position),
				"local_aabb_size": _vec3_string(aabb.size),
				"global_origin": _vec3_string(mi.global_transform.origin),
			})
	out["mesh_samples"] = samples
	return out

func _vec3_string(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]

func _inspect_runtime_scene(zone_viewer: Node, znum: int) -> Dictionary:
	var prop_static_index: Array = _get_array(zone_viewer, "_prop_static_index")
	var exported_rows: Array = []
	var missing_rows: Array = []
	for item in prop_static_index:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item as Dictionary
		if int(d.get("zone", d.get("source_zone", -1))) != znum:
			continue
		exported_rows.append({
			"fixture_id": int(d.get("fixture_id", -1)),
			"nif_id": int(d.get("nif_id", -1)),
			"file": str(d.get("file", "")),
			"missing": bool(d.get("missing", false)),
		})
		if bool(d.get("missing", false)):
			missing_rows.append(exported_rows[exported_rows.size() - 1])
	return {
		"exported_prop_static_count": exported_rows.size(),
		"exported_missing_count": missing_rows.size(),
		"exported_rows_sample": _limit_array(exported_rows, 80),
		"exported_missing_sample": _limit_array(missing_rows, 80),
	}

func _inspect_runtime_materials(zone_viewer: Node, znum: int, max_nodes: int) -> Dictionary:
	if zone_viewer == null:
		return {"ok": false, "reason": "no zone_viewer"}
	var root: Node = null
	if zone_viewer.has_method("find_child"):
		root = zone_viewer.find_child("Zone%03d_Root" % znum, true, false)
	if root == null:
		root = zone_viewer
	var props_root: Node = root.find_child("StaticPropsRoot", true, false)
	var terrain_meshes: Array = root.find_children("Zone%03d_S*" % znum, "MeshInstance3D", true, false)
	var mesh_nodes: Array = []
	if props_root != null:
		mesh_nodes = props_root.find_children("*", "MeshInstance3D", true, false)
	else:
		mesh_nodes = root.find_children("*", "MeshInstance3D", true, false)
	var inspected := 0
	var surface_count := 0
	var material_name_count := 0
	var albedo_texture_count := 0
	var lightmap_named_material_count := 0
	var material_samples: Array = []
	for node_value in mesh_nodes:
		if inspected >= max_nodes:
			break
		var mi: MeshInstance3D = node_value as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		inspected += 1
		for si in range(mi.mesh.get_surface_count()):
			surface_count += 1
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			var mat_name := ""
			if mat != null:
				mat_name = mat.resource_name
			if mat_name != "":
				material_name_count += 1
				if _classify_texture_name(mat_name) == "lightmap":
					lightmap_named_material_count += 1
			if mat is BaseMaterial3D:
				var bm: BaseMaterial3D = mat as BaseMaterial3D
				if bm.albedo_texture != null:
					albedo_texture_count += 1
			if material_samples.size() < 120:
				material_samples.append({"node": mi.name, "surface": si, "material": mat_name, "path": str(mi.get_path())})
	return {
		"ok": true,
		"mesh_nodes_found": mesh_nodes.size(),
		"prop_mesh_nodes_found": mesh_nodes.size(),
		"terrain_mesh_nodes_found": terrain_meshes.size(),
		"mesh_nodes_inspected": inspected,
		"surface_count": surface_count,
		"material_name_count": material_name_count,
		"albedo_texture_count": albedo_texture_count,
		"lightmap_named_material_count": lightmap_named_material_count,
		"material_samples": material_samples,
		"note": "props-first scan; terrain sectors are counted separately to avoid hiding prop material issues",
	}

func _audit_textures(texture_index: Dictionary, max_samples: int) -> Dictionary:
	var counts: Dictionary = {}
	var samples: Dictionary = {}
	for key in texture_index.keys():
		var stem: String = str(key).to_lower()
		var path: String = str(texture_index[key])
		var kind: String = _classify_texture_name(stem)
		counts[kind] = int(counts.get(kind, 0)) + 1
		if not samples.has(kind):
			samples[kind] = []
		var arr: Array = samples[kind] as Array
		if arr.size() < max_samples:
			arr.append({"stem": stem, "path": path, "ext": path.get_extension().to_lower()})
	var lightmap_count: int = int(counts.get("lightmap", 0))
	return {
		"texture_index_size": texture_index.size(),
		"classification_counts": counts,
		"samples": samples,
		"lightmap_candidate_count": lightmap_count,
		"secondary_texture_candidate_count": int(counts.get("lightmap", 0)) + int(counts.get("detail", 0)) + int(counts.get("glow", 0)) + int(counts.get("normal_or_bump", 0)),
		"note": "filename classifier only; do not bind lightmaps as albedo without UV/material confirmation",
	}

func _classify_texture_name(name_value: String) -> String:
	var n := name_value.to_lower()
	if n.find("lightmap") >= 0 or n.ends_with("_lm") or n.find("_lm_") >= 0 or n.find("lm_") == 0 or n.find("_light") >= 0:
		return "lightmap"
	if n.find("detail") >= 0 or n.find("_det") >= 0 or n.find("det_") == 0:
		return "detail"
	if n.find("glow") >= 0 or n.find("emit") >= 0 or n.find("emiss") >= 0:
		return "glow"
	if n.find("normal") >= 0 or n.find("bump") >= 0 or n.ends_with("_n") or n.find("_n_") >= 0:
		return "normal_or_bump"
	if n.find("alpha") >= 0 or n.find("opacity") >= 0:
		return "alpha_or_opacity"
	return "diffuse_or_unknown"

func _get_array(obj: Object, property_name: String) -> Array:
	if obj == null:
		return []
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	return []

func _limit_array(values: Array, max_items: int) -> Array:
	var out: Array = []
	for i in range(min(values.size(), max_items)):
		out.append(values[i])
	return out

func _write_reports(report: Dictionary, report_dir: String) -> void:
	_ensure_dir(report_dir)
	var zone: int = int(report.get("zone", 0))
	var json_path := report_dir.path_join("zone%03d_asset_material_audit.json" % zone)
	var txt_path := report_dir.path_join("zone%03d_asset_material_audit.txt" % zone)
	var source_csv := report_dir.path_join("zone%03d_source_models.csv" % zone)
	var missing_csv := report_dir.path_join("zone%03d_missing_models.csv" % zone)
	var texture_csv := report_dir.path_join("zone%03d_texture_classification.csv" % zone)
	var critical_placement_csv := report_dir.path_join("zone%03d_critical_placements.csv" % zone)
	var critical_runtime_csv := report_dir.path_join("zone%03d_critical_runtime.csv" % zone)
	var focus_placement_csv := report_dir.path_join("zone%03d_focus_rect_placements.csv" % zone)
	var focus_runtime_csv := report_dir.path_join("zone%03d_focus_rect_runtime.csv" % zone)
	_write_text(json_path, JSON.stringify(report, "\t"))
	_write_text(txt_path, _format_txt_report(report))
	_write_model_csv(source_csv, ((report.get("models", {}) as Dictionary).get("source_model_rows", []) as Array))
	_write_model_csv(missing_csv, ((report.get("models", {}) as Dictionary).get("missing_by_model_index", []) as Array))
	_write_texture_csv(texture_csv, report.get("textures", {}) as Dictionary)
	_write_any_rows_csv(critical_placement_csv, ((report.get("critical_placements", {}) as Dictionary).get("rows", []) as Array))
	_write_any_rows_csv(critical_runtime_csv, ((report.get("critical_runtime", {}) as Dictionary).get("rows", []) as Array))
	_write_any_rows_csv(focus_placement_csv, ((report.get("focus_rect_placements", {}) as Dictionary).get("rows", []) as Array))
	_write_any_rows_csv(focus_runtime_csv, ((report.get("focus_rect_runtime", {}) as Dictionary).get("rows", []) as Array))
	report["written_files"] = {
		"json": ProjectSettings.globalize_path(json_path),
		"txt": ProjectSettings.globalize_path(txt_path),
		"source_models_csv": ProjectSettings.globalize_path(source_csv),
		"missing_models_csv": ProjectSettings.globalize_path(missing_csv),
		"texture_classification_csv": ProjectSettings.globalize_path(texture_csv),
		"critical_placements_csv": ProjectSettings.globalize_path(critical_placement_csv),
		"critical_runtime_csv": ProjectSettings.globalize_path(critical_runtime_csv),
		"focus_rect_placements_csv": ProjectSettings.globalize_path(focus_placement_csv),
		"focus_rect_runtime_csv": ProjectSettings.globalize_path(focus_runtime_csv),
	}
	# Rewrite JSON/TXT once written_files are known.
	_write_text(json_path, JSON.stringify(report, "\t"))
	_write_text(txt_path, _format_txt_report(report))

func _ensure_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path)

func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()

func _write_model_csv(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("nif_id;file;stem;used_by_fixture;indexed;indexed_path;fixture_count;matched_tokens")
	for r_value in rows:
		var r: Dictionary = r_value as Dictionary
		f.store_line(";".join([
			_csv(r.get("nif_id", "")),
			_csv(r.get("file", "")),
			_csv(r.get("stem", str(r.get("file", "")).get_basename().to_lower())),
			_csv(r.get("used_by_fixture", "")),
			_csv(r.get("indexed", "")),
			_csv(r.get("indexed_path", "")),
			_csv(r.get("fixture_count", "")),
			_csv(r.get("matched_tokens", [])),
		]))
	f.close()

func _write_texture_csv(path: String, textures: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("kind;stem;ext;path")
	var samples: Dictionary = textures.get("samples", {}) as Dictionary
	for kind in samples.keys():
		var arr: Array = samples[kind] as Array
		for item in arr:
			var d: Dictionary = item as Dictionary
			f.store_line(";".join([_csv(kind), _csv(d.get("stem", "")), _csv(d.get("ext", "")), _csv(d.get("path", ""))]))
	f.close()

func _write_any_rows_csv(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var headers: Array = []
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		for key in row.keys():
			if not headers.has(str(key)):
				headers.append(str(key))
	headers.sort()
	f.store_line(";".join(headers))
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		var cells: Array[String] = []
		for key in headers:
			cells.append(_csv(row.get(key, "")))
		f.store_line(";".join(cells))
	f.close()

func _format_txt_report(report: Dictionary) -> String:
	var placement: Dictionary = report.get("placement", {}) as Dictionary
	var models: Dictionary = report.get("models", {}) as Dictionary
	var crit: Dictionary = report.get("critical_candidates", {}) as Dictionary
	var textures: Dictionary = report.get("textures", {}) as Dictionary
	var runtime_scene: Dictionary = report.get("runtime_scene", {}) as Dictionary
	var critical_placements: Dictionary = report.get("critical_placements", {}) as Dictionary
	var critical_runtime: Dictionary = report.get("critical_runtime", {}) as Dictionary
	var runtime_materials: Dictionary = report.get("runtime_materials", {}) as Dictionary
	var focus_placements: Dictionary = report.get("focus_rect_placements", {}) as Dictionary
	var focus_runtime: Dictionary = report.get("focus_rect_runtime", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("# P1-18N Asset & Material Fidelity Audit")
	lines.append("")
	lines.append("zone=%03d checkpoint=%s ok=%s" % [int(report.get("zone", 0)), str(report.get("checkpoint", "")), str(report.get("ok", false))])
	lines.append("non_destructive=%s runtime_modified=%s" % [str(report.get("non_destructive", false)), str(report.get("runtime_modified", true))])
	lines.append("")
	lines.append("## Placement")
	lines.append("path=%s exists=%s loaded=%s fixtures=%d model_table=%d" % [str(placement.get("path", "")), str(placement.get("exists", false)), str(placement.get("loaded", false)), int(placement.get("fixture_count", 0)), int(placement.get("model_table_count", 0))])
	lines.append("")
	lines.append("## Models")
	lines.append("source_models=%d used_model_ids=%d model_index=%d missing_by_index=%d" % [int(models.get("source_model_count", 0)), int(models.get("used_model_id_count", 0)), int(models.get("model_index_size", 0)), int(models.get("missing_by_model_index_count", 0))])
	lines.append("")
	lines.append("## Critical candidates")
	lines.append("tokens=%s" % str(crit.get("tokens", [])))
	lines.append("candidates=%d missing_candidates=%d" % [int(crit.get("candidate_count", 0)), int(crit.get("missing_candidate_count", 0))])
	for item_value in _limit_array(crit.get("candidates", []) as Array, 20):
		var item: Dictionary = item_value as Dictionary
		lines.append("- %s fixtures=%d indexed=%s tokens=%s" % [str(item.get("file", "")), int(item.get("fixture_count", 0)), str(item.get("indexed", false)), str(item.get("matched_tokens", []))])
	lines.append("")
	lines.append("## Runtime scene")
	lines.append("exported_prop_static_count=%d exported_missing_count=%d" % [int(runtime_scene.get("exported_prop_static_count", 0)), int(runtime_scene.get("exported_missing_count", 0))])
	lines.append("")
	lines.append("## Critical placements/runtime")
	lines.append("critical_fixtures=%d runtime_rows=%d missing_nodes=%d zero_mesh=%d zero_vertices=%d" % [int(critical_placements.get("critical_fixture_count", 0)), int(critical_runtime.get("critical_runtime_count", 0)), int(critical_runtime.get("missing_node_count", 0)), int(critical_runtime.get("zero_mesh_count", 0)), int(critical_runtime.get("zero_vertex_count", 0))])
	for item_value in _limit_array(critical_runtime.get("rows", []) as Array, 20):
		var item: Dictionary = item_value as Dictionary
		lines.append("- fixture=%d file=%s node_found=%s meshes=%d vertices=%d origin=%s" % [int(item.get("fixture_id", 0)), str(item.get("file", "")), str(item.get("node_found", false)), int(item.get("mesh_instance_count", 0)), int(item.get("vertex_count", 0)), str(item.get("global_origin", ""))])
	lines.append("")
	lines.append("## Focus rectangle / targeted bridgehouse")
	lines.append("rect=%s rows=%d focus_rect=%d targets=%d runtime_rows=%d missing_nodes=%d zero_mesh=%d zero_vertices=%d" % [str(focus_placements.get("rect", {})), int(focus_placements.get("row_count", 0)), int(focus_placements.get("focus_rect_fixture_count", 0)), int(focus_placements.get("target_fixture_count", 0)), int(focus_runtime.get("critical_runtime_count", 0)), int(focus_runtime.get("missing_node_count", 0)), int(focus_runtime.get("zero_mesh_count", 0)), int(focus_runtime.get("zero_vertex_count", 0))])
	for item_value in _limit_array(focus_runtime.get("rows", []) as Array, 40):
		var item: Dictionary = item_value as Dictionary
		lines.append("- fixture=%d nif=%d file=%s reason=%s node_found=%s meshes=%d vertices=%d origin=%s" % [int(item.get("fixture_id", 0)), int(item.get("nif_id", 0)), str(item.get("file", "")), str(item.get("reason", [])), str(item.get("node_found", false)), int(item.get("mesh_instance_count", 0)), int(item.get("vertex_count", 0)), str(item.get("global_origin", ""))])
	lines.append("")
	lines.append("## Textures")
	lines.append("texture_index=%d secondary_candidates=%d lightmap_candidates=%d" % [int(textures.get("texture_index_size", 0)), int(textures.get("secondary_texture_candidate_count", 0)), int(textures.get("lightmap_candidate_count", 0))])
	lines.append("classification_counts=%s" % str(textures.get("classification_counts", {})))
	lines.append("")
	lines.append("## Runtime materials")
	lines.append("mesh_nodes_found=%d prop_mesh_nodes=%d terrain_mesh_nodes=%d inspected=%d surfaces=%d albedo_texture_slots=%d lightmap_named_materials=%d" % [int(runtime_materials.get("mesh_nodes_found", 0)), int(runtime_materials.get("prop_mesh_nodes_found", 0)), int(runtime_materials.get("terrain_mesh_nodes_found", 0)), int(runtime_materials.get("mesh_nodes_inspected", 0)), int(runtime_materials.get("surface_count", 0)), int(runtime_materials.get("albedo_texture_count", 0)), int(runtime_materials.get("lightmap_named_material_count", 0))])
	lines.append("")
	lines.append("## Warnings")
	for warning in report.get("warnings", []) as Array:
		lines.append("- %s" % str(warning))
	return "\n".join(lines) + "\n"

func _csv(value: Variant) -> String:
	var s := str(value).replace("\n", " ").replace("\r", " ").replace("\"", "'")
	if s.find(";") >= 0 or s.find(",") >= 0:
		return "\"%s\"" % s
	return s
