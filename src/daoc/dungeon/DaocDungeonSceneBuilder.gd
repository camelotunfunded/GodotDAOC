extends RefCounted
class_name DaocDungeonSceneBuilder

## P1-17C1/C2 — builder donjon configurable, réutilisable par DungeonLab et ZoneCreator.
##
## Le builder ne dépend plus de Mithra/zone021 en dur. DungeonLab peut garder
## Mithra comme cible de contrôle, tandis que ZoneCreator peut exporter une
## GeneratedDungeonScene pour n'importe quelle zone classée dungeon_chunk.

const SCOPE: String = "P1-17C1 configurable dungeon_chunk scene builder"
const CHECKPOINT: String = "P1_17C1_CONFIGURABLE_DUNGEON_CHUNK_BUILDER"

const FileResolverScript: Script = preload("res://src/daoc/dungeon/DaocDungeonFileResolver.gd")
const ChunkParserScript: Script = preload("res://src/daoc/dungeon/DaocDungeonChunkParser.gd")
const PlaceParserScript: Script = preload("res://src/daoc/dungeon/DaocDungeonPlaceParser.gd")
const PortalParserScript: Script = preload("res://src/daoc/dungeon/DaocDungeonPortalParser.gd")
const LightsParserScript: Script = preload("res://src/daoc/dungeon/DaocDungeonLightsParser.gd")
const NifReaderScript: Script = preload("res://src/nif/nif_reader.gd")
const TextureResolverScript: Script = preload("res://src/daoc/dungeon/DaocDungeonTextureResolver.gd")


func build(
	client_root: String,
	zone_id: int,
	zone_name: String,
	world_scale: float = 0.10,
	placeholder_extent: float = 80.0,
	try_runtime_nif_preview: bool = true,
	nif_preview_scale: float = 0.10,
	link_runtime_textures: bool = true,
	texture_alpha_scissor: float = 0.5,
	build_runtime_collisions: bool = true,
	collision_shape_mode: String = "trimesh",
	show_debug_footprints: bool = false,
	show_debug_axes: bool = false,
	show_debug_labels: bool = false,
	show_portal_debug: bool = true,
	show_light_debug: bool = false,
	metadata: Dictionary = {}
) -> Dictionary:
	var active_scope: String = str(metadata.get("scope", SCOPE))
	var active_checkpoint: String = str(metadata.get("checkpoint", CHECKPOINT))
	var generated_scene_type: String = str(metadata.get("generated_scene_type", "DungeonLabRuntime"))
	var source_region_hint: String = str(metadata.get("source_region_hint", "configurable dungeon target zone%03d" % zone_id))
	var previous_note: String = str(metadata.get("previous_wrong_target_note", ""))
	var root_name_override: String = str(metadata.get("root_name", ""))
	var files_info: Dictionary = FileResolverScript.resolve_dungeon_files(client_root, zone_id, zone_name)
	var files: Dictionary = files_info.get("files", {}) as Dictionary
	var chunk_result: Dictionary = ChunkParserScript.new().parse_file(str(files.get("dungeon.chunk", "")))
	var place_result: Dictionary = PlaceParserScript.new().parse_file(str(files.get("dungeon.place", "")))
	var portal_result: Dictionary = PortalParserScript.new().parse_file(str(files.get("portals.csv", "")))
	var lights_result: Dictionary = LightsParserScript.new().parse_file(str(files.get("lights.csv", "")))
	var root: Node3D = Node3D.new()
	root.name = root_name_override if root_name_override != "" else "DungeonLabZone_%03d_%s" % [zone_id, _safe_name(zone_name)]
	root.set_meta("scope", active_scope)
	root.set_meta("checkpoint", active_checkpoint)
	root.set_meta("zone_id", zone_id)
	root.set_meta("zone", zone_id)
	root.set_meta("zone_name", zone_name)
	root.set_meta("generated_scene_type", generated_scene_type)
	root.set_meta("dat_folder", str(files_info.get("dat_folder", "")))
	var status: Dictionary = {
		"scope": active_scope,
		"checkpoint": active_checkpoint,
		"zone_id": zone_id,
		"zone": zone_id,
		"zone_name": zone_name,
		"generated_scene_type": generated_scene_type,
		"source_region_hint": source_region_hint,
		"previous_wrong_target_note": previous_note,
		"client_root": FileResolverScript.normalize_path(client_root),
		"dat_folder": str(files_info.get("dat_folder", "")),
		"files": files,
		"chunk_result": _compact_chunk_result(chunk_result),
		"place_result": _compact_place_result(place_result),
		"portal_result": _compact_portal_result(portal_result),
		"lights_result": _compact_lights_result(lights_result),
		"world_scale": world_scale,
		"placeholder_extent": placeholder_extent,
		"try_runtime_nif_preview": try_runtime_nif_preview,
		"nif_preview_scale": nif_preview_scale,
		"link_runtime_textures": link_runtime_textures,
		"texture_alpha_scissor": texture_alpha_scissor,
		"build_runtime_collisions": build_runtime_collisions,
		"collision_shape_mode": collision_shape_mode,
		"show_debug_footprints": show_debug_footprints,
		"show_debug_axes": show_debug_axes,
		"show_debug_labels": show_debug_labels,
		"show_portal_debug": show_portal_debug,
		"show_light_debug": show_light_debug,
		"nif_converter_mode": "full_hierarchy",
		"dungeon_transform_mode": "nif_coordinate_system_xy_minus_y_negative_angle",
		"portal_graph": {},
		"nif_resolution": [],
		"material_surface_count": 0,
		"material_texture_requests": 0,
		"material_textures_resolved": 0,
		"material_textures_missing": 0,
		"material_unique_names": [],
		"material_missing_names": [],
		"material_resolved_paths": [],
		"texture_resolver": {},
		"collision_bodies": 0,
		"collision_shapes": 0,
		"collision_mesh_instances": 0,
		"collision_surfaces": 0,
		"collision_trimesh_shapes": 0,
		"collision_aabb_fallbacks": 0,
		"collision_failures": 0,
		"collision_errors": [],
		"placeholder_nodes": 0,
		"nif_preview_nodes": 0,
		"nif_preview_failures": 0,
		"portal_debug_lines": 0,
		"portal_debug_thick_edges": 0,
		"portal_debug_endpoint_markers": 0,
		"logical_connector_nodes": 0,
		"logical_empty_nif_nodes": 0,
		"logical_no_mesh_nif_nodes": 0,
		"connector_proxy_nodes": 0,
		"connector_proxy_edges": 0,
		"light_debug_nodes": 0,
		"ok": false,
		"error": "",
	}
	if not bool(chunk_result.get("ok", false)):
		status["error"] = str(chunk_result.get("error", "chunk parse failed"))
		return {"ok": false, "root": root, "status": status}
	if not bool(place_result.get("ok", false)):
		status["error"] = str(place_result.get("error", "place parse failed"))
		return {"ok": false, "root": root, "status": status}
	var chunks: Array = chunk_result.get("chunks", []) as Array
	var placements: Array = place_result.get("placements", []) as Array
	var links: Array = portal_result.get("links", []) as Array
	var lights: Array = lights_result.get("lights", []) as Array
	var instances_root: Node3D = Node3D.new()
	instances_root.name = "DungeonChunkInstances"
	root.add_child(instances_root)
	var portal_root: Node3D = Node3D.new()
	portal_root.name = "DungeonPortalDebug"
	root.add_child(portal_root)
	var lights_root: Node3D = Node3D.new()
	lights_root.name = "DungeonLightDebug"
	root.add_child(lights_root)
	var positions_by_instance: Dictionary = {}
	var texture_resolver: Object = null
	if link_runtime_textures:
		texture_resolver = TextureResolverScript.new()
		texture_resolver.call("configure", client_root, texture_alpha_scissor)
	var nif_resolution: Array = []
	var material_surface_count: int = 0
	var material_texture_requests: int = 0
	var material_textures_resolved: int = 0
	var material_textures_missing: int = 0
	var material_unique_names: Array = []
	var material_missing_names: Array = []
	var material_resolved_paths: Array = []
	var collision_bodies: int = 0
	var collision_shapes: int = 0
	var collision_mesh_instances: int = 0
	var collision_surfaces: int = 0
	var collision_trimesh_shapes: int = 0
	var collision_aabb_fallbacks: int = 0
	var collision_failures: int = 0
	var collision_errors: Array = []
	var placeholder_count: int = 0
	var nif_preview_count: int = 0
	var nif_failure_count: int = 0
	var logical_connector_count: int = 0
	var logical_empty_nif_count: int = 0
	var logical_no_mesh_nif_count: int = 0
	for placement_value in placements:
		var placement: Dictionary = placement_value as Dictionary
		var chunk_index: int = int(placement.get("chunk_index", -1))
		var nif_name: String = _chunk_nif_name(chunks, chunk_index)
		var nif_info: Dictionary = FileResolverScript.resolve_nif_path_info(client_root, nif_name)
		var nif_path: String = str(nif_info.get("path", ""))
		var instance_index: int = int(placement.get("instance_index", 0))
		var node: Node3D = _make_instance_root(placement, nif_name, world_scale)
		var preview_status: Dictionary = _attach_runtime_nif_preview(node, nif_path, nif_name, nif_preview_scale, try_runtime_nif_preview, texture_resolver, link_runtime_textures, build_runtime_collisions, collision_shape_mode)
		if bool(preview_status.get("preview_ok", false)):
			nif_preview_count += 1
		else:
			if bool(preview_status.get("logical_connector", false)):
				logical_connector_count += 1
				var logical_reason: String = str(preview_status.get("logical_connector_reason", ""))
				if logical_reason.find("empty") != -1 or logical_reason.find("too_small") != -1:
					logical_empty_nif_count += 1
				else:
					logical_no_mesh_nif_count += 1
			else:
				_attach_placeholder_mesh(node, chunk_index, placeholder_extent)
				placeholder_count += 1
				if nif_path != "":
					nif_failure_count += 1
		material_surface_count += int(preview_status.get("material_surface_count", 0))
		material_texture_requests += int(preview_status.get("material_texture_requests", 0))
		material_textures_resolved += int(preview_status.get("material_textures_resolved", 0))
		material_textures_missing += int(preview_status.get("material_textures_missing", 0))
		_append_unique_array(material_unique_names, preview_status.get("material_names", []))
		_append_unique_array(material_missing_names, preview_status.get("material_missing_names", []))
		_append_unique_array(material_resolved_paths, preview_status.get("material_resolved_paths", []))
		collision_bodies += int(preview_status.get("collision_bodies", 0))
		collision_shapes += int(preview_status.get("collision_shapes", 0))
		collision_mesh_instances += int(preview_status.get("collision_mesh_instances", 0))
		collision_surfaces += int(preview_status.get("collision_surfaces", 0))
		collision_trimesh_shapes += int(preview_status.get("collision_trimesh_shapes", 0))
		collision_aabb_fallbacks += int(preview_status.get("collision_aabb_fallbacks", 0))
		collision_failures += int(preview_status.get("collision_failures", 0))
		_append_unique_array(collision_errors, preview_status.get("collision_errors", []))
		if show_debug_footprints:
			_attach_footprint(node, chunk_index, placeholder_extent)
		if show_debug_axes:
			_attach_orientation_debug(node, placeholder_extent)
		if show_debug_labels:
			_attach_label(node, placement, nif_name, nif_path, preview_status, placeholder_extent)
		instances_root.add_child(node)
		positions_by_instance[instance_index] = node.position
		nif_resolution.append({
			"instance_index": instance_index,
			"chunk_index": chunk_index,
			"nif_name": nif_name,
			"nif_path": nif_path,
			"nif_found": nif_path != "",
			"nif_resolve_method": str(nif_info.get("method", "")),
			"nif_candidate_count": int(nif_info.get("candidate_count", 0)),
			"nif_candidate_roots": nif_info.get("candidate_roots", []),
			"preview_ok": bool(preview_status.get("preview_ok", false)),
			"preview_error": str(preview_status.get("preview_error", "")),
			"preview_header": str(preview_status.get("preview_header", "")),
			"preview_blocks": int(preview_status.get("preview_blocks", 0)),
			"preview_meshes": int(preview_status.get("preview_meshes", 0)),
			"material_surface_count": int(preview_status.get("material_surface_count", 0)),
			"material_texture_requests": int(preview_status.get("material_texture_requests", 0)),
			"material_textures_resolved": int(preview_status.get("material_textures_resolved", 0)),
			"material_textures_missing": int(preview_status.get("material_textures_missing", 0)),
			"material_names": preview_status.get("material_names", []),
			"material_missing_names": preview_status.get("material_missing_names", []),
			"material_resolved_paths": preview_status.get("material_resolved_paths", []),
			"collision_bodies": int(preview_status.get("collision_bodies", 0)),
			"collision_shapes": int(preview_status.get("collision_shapes", 0)),
			"collision_mesh_instances": int(preview_status.get("collision_mesh_instances", 0)),
			"collision_surfaces": int(preview_status.get("collision_surfaces", 0)),
			"collision_trimesh_shapes": int(preview_status.get("collision_trimesh_shapes", 0)),
			"collision_aabb_fallbacks": int(preview_status.get("collision_aabb_fallbacks", 0)),
			"collision_failures": int(preview_status.get("collision_failures", 0)),
			"collision_errors": preview_status.get("collision_errors", []),
			"logical_connector": bool(preview_status.get("logical_connector", false)),
			"logical_connector_reason": str(preview_status.get("logical_connector_reason", "")),
		})
	status["material_surface_count"] = material_surface_count
	status["material_texture_requests"] = material_texture_requests
	status["material_textures_resolved"] = material_textures_resolved
	status["material_textures_missing"] = material_textures_missing
	status["material_unique_names"] = material_unique_names
	status["material_missing_names"] = material_missing_names
	status["material_resolved_paths"] = material_resolved_paths
	status["collision_bodies"] = collision_bodies
	status["collision_shapes"] = collision_shapes
	status["collision_mesh_instances"] = collision_mesh_instances
	status["collision_surfaces"] = collision_surfaces
	status["collision_trimesh_shapes"] = collision_trimesh_shapes
	status["collision_aabb_fallbacks"] = collision_aabb_fallbacks
	status["collision_failures"] = collision_failures
	status["collision_errors"] = collision_errors
	if texture_resolver != null:
		status["texture_resolver"] = texture_resolver.call("debug_snapshot")
	status["placeholder_nodes"] = placeholder_count
	status["nif_preview_nodes"] = nif_preview_count
	status["nif_preview_failures"] = nif_failure_count
	status["logical_connector_nodes"] = logical_connector_count
	status["logical_empty_nif_nodes"] = logical_empty_nif_count
	status["logical_no_mesh_nif_nodes"] = logical_no_mesh_nif_count
	status["nif_resolution"] = nif_resolution
	var portal_graph: Dictionary = _build_portal_graph_diagnostics(links, positions_by_instance, nif_resolution)
	status["portal_graph"] = portal_graph
	var connector_proxy: Dictionary = _build_logical_connector_proxies(root, links, positions_by_instance, nif_resolution)
	status["connector_proxy_nodes"] = int(connector_proxy.get("node_count", 0))
	status["connector_proxy_edges"] = int(connector_proxy.get("edge_count", 0))
	if show_portal_debug:
		var portal_debug: Dictionary = _build_portal_lines(portal_root, links, positions_by_instance, nif_resolution, portal_graph)
		status["portal_debug_lines"] = int(portal_debug.get("line_count", 0))
		status["portal_debug_thick_edges"] = int(portal_debug.get("thick_edge_count", 0))
		status["portal_debug_endpoint_markers"] = int(portal_debug.get("endpoint_marker_count", 0))
	else:
		status["portal_debug_lines"] = 0
		status["portal_debug_thick_edges"] = 0
		status["portal_debug_endpoint_markers"] = 0
	if show_light_debug:
		var light_count: int = _build_light_debug_nodes(lights_root, lights, world_scale)
		status["light_debug_nodes"] = light_count
	else:
		status["light_debug_nodes"] = 0
	status["ok"] = true
	status["error"] = ""
	root.set_meta("status", status)
	return {"ok": true, "root": root, "status": status}


func _make_instance_root(placement: Dictionary, nif_name: String, world_scale: float) -> Node3D:
	var instance_index: int = int(placement.get("instance_index", 0))
	var chunk_index: int = int(placement.get("chunk_index", -1))
	var node: Node3D = Node3D.new()
	node.name = "Instance_%03d_chunk_%02d_%s" % [instance_index, chunk_index, _safe_name(nif_name.get_file().get_basename())]
	node.position = _daoc_local_to_godot(placement, world_scale)
	var axis: Vector3 = Vector3(float(placement.get("axis_x", 0.0)), float(placement.get("axis_y", 0.0)), float(placement.get("axis_z", 0.0)))
	var angle: float = float(placement.get("angle", 0.0))
	var godot_axis: Vector3 = _daoc_axis_to_godot(axis)
	if godot_axis.length() > 0.0001 and absf(angle) > 0.0001:
		# HF3 : les positions HF2 etaient meilleures, mais les ouvertures restaient
		# incoherentes. Hypothese testee : dungeon.place stocke le sens de rotation
		# oppose a Basis(axis, angle) de Godot.
		node.basis = Basis(godot_axis.normalized(), -angle)
	node.set_meta("instance_index", instance_index)
	node.set_meta("chunk_index", chunk_index)
	node.set_meta("nif_name", nif_name)
	node.set_meta("daoc_x", float(placement.get("x", 0.0)))
	node.set_meta("daoc_y", float(placement.get("y", 0.0)))
	node.set_meta("daoc_z", float(placement.get("z", 0.0)))
	node.set_meta("daoc_angle", angle)
	node.set_meta("godot_angle", -angle)
	node.set_meta("daoc_axis", axis)
	node.set_meta("daoc_flags", placement.get("flags", []))
	return node


func _attach_runtime_nif_preview(node: Node3D, nif_path: String, nif_name: String, nif_preview_scale: float, enabled: bool, texture_resolver: Object = null, link_runtime_textures: bool = true, build_runtime_collisions: bool = true, collision_shape_mode: String = "trimesh") -> Dictionary:
	var status: Dictionary = {
		"preview_ok": false,
		"preview_error": "disabled" if not enabled else "",
		"preview_header": "",
		"preview_blocks": 0,
		"preview_meshes": 0,
		"material_surface_count": 0,
		"material_texture_requests": 0,
		"material_textures_resolved": 0,
		"material_textures_missing": 0,
		"material_names": [],
		"material_missing_names": [],
		"material_resolved_paths": [],
		"logical_connector": false,
		"logical_connector_reason": "",
	}
	if not enabled:
		return status
	if nif_path == "":
		status["preview_error"] = "nif not found"
		return status
	var file_size: int = 0
	if FileAccess.file_exists(nif_path):
		var f: FileAccess = FileAccess.open(nif_path, FileAccess.READ)
		if f != null:
			file_size = int(f.get_length())
			f.close()
	if file_size < 32:
		status["preview_error"] = "nif file empty or too small (%d bytes)" % file_size
		status["logical_connector"] = _looks_like_logical_connector_nif(nif_name, "empty_or_too_small")
		if bool(status.get("logical_connector", false)):
			status["logical_connector_reason"] = "empty_or_too_small"
		return status
	var reader: NifReader = NifReaderScript.new() as NifReader
	if reader == null:
		status["preview_error"] = "cannot instantiate NifReader"
		return status
	reader.quiet_errors = true
	var read_ok: bool = reader.read(nif_path)
	status["preview_header"] = str(reader.version_str)
	var blocks_value: Variant = reader.blocks
	if blocks_value is Array:
		status["preview_blocks"] = int((blocks_value as Array).size())
	if (not read_ok) or reader.failed:
		status["preview_error"] = str(reader.fail_reason)
		return status
	var template: Node3D = NifConverter.build_template_full_hierarchy(reader, nif_name.get_file().get_basename())
	if template == null:
		status["preview_error"] = "converter returned null"
		return status
	var mesh_count: int = _count_mesh_instances(template)
	status["preview_meshes"] = mesh_count
	var material_status: Dictionary = _apply_or_collect_materials(template, nif_path, texture_resolver, link_runtime_textures)
	status["material_surface_count"] = int(material_status.get("surface_count", 0))
	status["material_texture_requests"] = int(material_status.get("texture_requests", 0))
	status["material_textures_resolved"] = int(material_status.get("textures_resolved", 0))
	status["material_textures_missing"] = int(material_status.get("textures_missing", 0))
	status["material_names"] = material_status.get("material_names", [])
	status["material_missing_names"] = material_status.get("missing_names", [])
	status["material_resolved_paths"] = material_status.get("resolved_paths", [])
	if mesh_count <= 0:
		status["preview_error"] = "converter produced no MeshInstance3D"
		status["logical_connector"] = _looks_like_logical_connector_nif(nif_name, "converter_no_mesh")
		if bool(status.get("logical_connector", false)):
			status["logical_connector_reason"] = "converter_no_mesh"
		template.queue_free()
		return status
	template.name = "NifPreview_%s" % _safe_name(nif_name.get_file().get_basename())
	template.scale = Vector3.ONE * maxf(nif_preview_scale, 0.0001)
	var collision_status: Dictionary = _attach_runtime_collision_shapes(template, build_runtime_collisions, collision_shape_mode)
	status["collision_bodies"] = int(collision_status.get("bodies", 0))
	status["collision_shapes"] = int(collision_status.get("shapes", 0))
	status["collision_mesh_instances"] = int(collision_status.get("mesh_instances", 0))
	status["collision_surfaces"] = int(collision_status.get("surfaces", 0))
	status["collision_trimesh_shapes"] = int(collision_status.get("trimesh_shapes", 0))
	status["collision_aabb_fallbacks"] = int(collision_status.get("aabb_fallbacks", 0))
	status["collision_failures"] = int(collision_status.get("failures", 0))
	status["collision_errors"] = collision_status.get("errors", [])
	node.add_child(template)
	status["preview_ok"] = true
	status["preview_error"] = ""
	return status


func _looks_like_logical_connector_nif(nif_name: String, reason: String) -> bool:
	var base: String = nif_name.get_file().get_basename().to_lower()
	# Ne pas masquer les vrais problèmes : seuls les noms qui ressemblent
	# explicitement à des connecteurs sont classés logiques.
	if base.find("trans") != -1 or base.find("portal") != -1:
		return true
	if base.find("hall27") != -1:
		return true
	if base.find("connector") != -1 or base.find("connect") != -1:
		return true
	return false


func _apply_or_collect_materials(template: Node3D, nif_path: String, texture_resolver: Object, link_runtime_textures: bool) -> Dictionary:
	if link_runtime_textures and texture_resolver != null:
		return texture_resolver.call("apply_textures", template, nif_path) as Dictionary
	return _collect_materials_without_loading(template)


func _collect_materials_without_loading(root: Node) -> Dictionary:
	var status: Dictionary = {
		"surface_count": 0,
		"texture_requests": 0,
		"textures_resolved": 0,
		"textures_missing": 0,
		"material_names": [],
		"missing_names": [],
		"resolved_paths": [],
	}
	if root == null:
		return status
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh: Mesh = mi.mesh
		for si in range(mesh.get_surface_count()):
			status["surface_count"] = int(status.get("surface_count", 0)) + 1
			var src: Material = mesh.surface_get_material(si)
			if src != null and src.resource_name.strip_edges() != "":
				status["texture_requests"] = int(status.get("texture_requests", 0)) + 1
				_append_unique(status["material_names"] as Array, src.resource_name.strip_edges())
	return status


func _attach_runtime_collision_shapes(template: Node3D, enabled: bool, shape_mode: String) -> Dictionary:
	var status: Dictionary = {
		"enabled": enabled,
		"mode": shape_mode,
		"bodies": 0,
		"shapes": 0,
		"mesh_instances": 0,
		"surfaces": 0,
		"trimesh_shapes": 0,
		"aabb_fallbacks": 0,
		"failures": 0,
		"errors": [],
	}
	if not enabled or template == null:
		return status
	var mode: String = shape_mode.strip_edges().to_lower()
	if mode == "":
		mode = "trimesh"
	var mesh_nodes: Array = template.find_children("*", "MeshInstance3D", true, false)
	for idx in range(mesh_nodes.size()):
		var mi: MeshInstance3D = mesh_nodes[idx] as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		status["mesh_instances"] = int(status.get("mesh_instances", 0)) + 1
		var mesh: Mesh = mi.mesh
		status["surfaces"] = int(status.get("surfaces", 0)) + mesh.get_surface_count()
		var shape: Shape3D = null
		var shape_kind: String = mode
		var shape_offset: Vector3 = Vector3.ZERO
		if mode == "aabb":
			shape = _make_aabb_collision_shape(mesh)
			shape_offset = _mesh_aabb_center(mesh)
			shape_kind = "aabb"
		else:
			shape = mesh.create_trimesh_shape()
			if shape != null:
				shape_kind = "trimesh"
			else:
				shape = _make_aabb_collision_shape(mesh)
				shape_offset = _mesh_aabb_center(mesh)
				shape_kind = "aabb_fallback"
		if shape == null:
			status["failures"] = int(status.get("failures", 0)) + 1
			var errors: Array = status.get("errors", []) as Array
			errors.append("%s: collision shape null" % mi.name)
			status["errors"] = errors
			continue
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "CollisionBody_%02d_%s" % [idx, _safe_name(mi.name)]
		body.set_meta("source_mesh", mi.name)
		body.set_meta("shape_kind", shape_kind)
		body.add_to_group("daoc_dungeon_collision")
		body.add_to_group("daoc_dungeon_runtime_collision")
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "CollisionShape_%s" % shape_kind
		collision.shape = shape
		collision.position = shape_offset
		body.add_child(collision)
		mi.add_child(body)
		status["bodies"] = int(status.get("bodies", 0)) + 1
		status["shapes"] = int(status.get("shapes", 0)) + 1
		if shape_kind == "trimesh":
			status["trimesh_shapes"] = int(status.get("trimesh_shapes", 0)) + 1
		else:
			status["aabb_fallbacks"] = int(status.get("aabb_fallbacks", 0)) + 1
	return status


func _make_aabb_collision_shape(mesh: Mesh) -> Shape3D:
	if mesh == null:
		return null
	var aabb: AABB = mesh.get_aabb()
	var size: Vector3 = aabb.size
	size.x = maxf(size.x, 0.25)
	size.y = maxf(size.y, 0.25)
	size.z = maxf(size.z, 0.25)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	return shape


func _mesh_aabb_center(mesh: Mesh) -> Vector3:
	if mesh == null:
		return Vector3.ZERO
	var aabb: AABB = mesh.get_aabb()
	return aabb.position + aabb.size * 0.5


func _append_unique_array(target: Array, values: Variant) -> void:
	if values is Array:
		var arr: Array = values as Array
		for value in arr:
			_append_unique(target, value)


func _append_unique(target: Array, value: Variant) -> void:
	if not target.has(value):
		target.append(value)


func _attach_placeholder_mesh(node: Node3D, chunk_index: int, placeholder_extent: float) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "FallbackPlaceholderMesh"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(placeholder_extent * 1.35, maxf(placeholder_extent * 0.25, 6.0), placeholder_extent * 1.35)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material_for_chunk(chunk_index, 0.85)
	node.add_child(mesh_instance)


func _attach_footprint(node: Node3D, chunk_index: int, placeholder_extent: float) -> void:
	var footprint: MeshInstance3D = MeshInstance3D.new()
	footprint.name = "OrientedFootprint"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(placeholder_extent * 1.55, 1.5, placeholder_extent * 1.55)
	footprint.mesh = mesh
	var mat: StandardMaterial3D = _material_for_chunk(chunk_index, 0.30)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint.material_override = mat
	footprint.position.y = -1.0
	node.add_child(footprint)


func _attach_orientation_debug(node: Node3D, placeholder_extent: float) -> void:
	var axes: Node3D = Node3D.new()
	axes.name = "OrientationDebug"
	node.add_child(axes)
	_add_debug_line(axes, "ForwardBlue", Vector3.ZERO, Vector3.FORWARD * placeholder_extent * 0.85, Color(0.2, 0.55, 1.0, 1.0))
	_add_debug_line(axes, "RightRed", Vector3.ZERO, Vector3.RIGHT * placeholder_extent * 0.45, Color(1.0, 0.25, 0.25, 1.0))
	_add_debug_line(axes, "UpGreen", Vector3.ZERO, Vector3.UP * placeholder_extent * 0.35, Color(0.2, 1.0, 0.3, 1.0))


func _attach_label(node: Node3D, placement: Dictionary, nif_name: String, nif_path: String, preview_status: Dictionary, placeholder_extent: float) -> void:
	var label: Label3D = Label3D.new()
	label.name = "DebugLabel"
	var instance_index: int = int(placement.get("instance_index", 0))
	var chunk_index: int = int(placement.get("chunk_index", -1))
	var mode: String = "NIF" if bool(preview_status.get("preview_ok", false)) else "BOX"
	var found: String = "found" if nif_path != "" else "missing"
	label.text = "%02d c%d %s\n%s / %s" % [instance_index, chunk_index, nif_name.get_file(), mode, found]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, placeholder_extent * 0.58, 0.0)
	label.pixel_size = 0.028
	node.add_child(label)


func _add_debug_line(parent: Node3D, name: String, a: Vector3, b: Vector3, color: Color) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = name
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_end()
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)


func _build_logical_connector_proxies(root: Node3D, links: Array, positions_by_instance: Dictionary, nif_resolution: Array) -> Dictionary:
	var result: Dictionary = {
		"node_count": 0,
		"edge_count": 0,
	}
	if root == null or links.is_empty():
		return result
	var preview_by_instance: Dictionary = {}
	var logical_by_instance: Dictionary = {}
	var name_by_instance: Dictionary = {}
	for nif_value in nif_resolution:
		var nif: Dictionary = nif_value as Dictionary
		var idx: int = int(nif.get("instance_index", -1))
		if idx < 0:
			continue
		preview_by_instance[idx] = bool(nif.get("preview_ok", false))
		logical_by_instance[idx] = bool(nif.get("logical_connector", false))
		name_by_instance[idx] = str(nif.get("nif_name", ""))

	var proxy_root: Node3D = Node3D.new()
	proxy_root.name = "DungeonLogicalConnectorProxies"
	var seen_edges: Dictionary = {}
	var edge_count: int = 0
	for link_value in links:
		var link: Dictionary = link_value as Dictionary
		var from_idx: int = int(link.get("from_instance", -1))
		var to_idx: int = int(link.get("to_instance", -1))
		if not positions_by_instance.has(from_idx) or not positions_by_instance.has(to_idx):
			continue
		var from_logical: bool = bool(logical_by_instance.get(from_idx, false))
		var to_logical: bool = bool(logical_by_instance.get(to_idx, false))
		var from_failed: bool = (not bool(preview_by_instance.get(from_idx, false))) and (not from_logical)
		var to_failed: bool = (not bool(preview_by_instance.get(to_idx, false))) and (not to_logical)
		if not (from_logical or to_logical or from_failed or to_failed):
			continue
		var lo: int = mini(from_idx, to_idx)
		var hi: int = maxi(from_idx, to_idx)
		var edge_key: String = "%d:%d" % [lo, hi]
		if seen_edges.has(edge_key):
			continue
		seen_edges[edge_key] = true
		var a: Vector3 = positions_by_instance[from_idx] as Vector3
		var b: Vector3 = positions_by_instance[to_idx] as Vector3
		var proxy: MeshInstance3D = _make_connector_proxy_mesh(edge_key, a, b, from_logical or to_logical, from_failed or to_failed)
		if proxy == null:
			continue
		proxy.set_meta("from_instance", from_idx)
		proxy.set_meta("to_instance", to_idx)
		proxy.set_meta("from_name", str(name_by_instance.get(from_idx, "")))
		proxy.set_meta("to_name", str(name_by_instance.get(to_idx, "")))
		proxy_root.add_child(proxy)
		edge_count += 1
	if edge_count > 0:
		root.add_child(proxy_root)
		result["node_count"] = 1
		result["edge_count"] = edge_count
	else:
		proxy_root.queue_free()
	return result


func _make_connector_proxy_mesh(edge_key: String, a: Vector3, b: Vector3, logical_edge: bool, failed_edge: bool) -> MeshInstance3D:
	var proxy: MeshInstance3D = MeshInstance3D.new()
	proxy.name = "LogicalConnectorProxy_%s" % edge_key.replace(":", "_")
	var mesh: BoxMesh = BoxMesh.new()
	var dir: Vector3 = b - a
	var length: float = dir.length()
	var visual_lift: Vector3 = Vector3.UP * 5.0
	if length < 0.25:
		mesh.size = Vector3(18.0, 10.0, 18.0)
		proxy.position = a + visual_lift
	else:
		mesh.size = Vector3(12.0 if logical_edge else 16.0, 8.0 if logical_edge else 12.0, length)
		var center: Vector3 = (a + b) * 0.5 + visual_lift
		proxy.look_at_from_position(center, center + dir.normalized(), Vector3.UP)
	proxy.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	if failed_edge:
		mat.albedo_color = Color(1.0, 0.25, 0.85, 0.28)
	else:
		mat.albedo_color = Color(0.35, 0.55, 0.75, 0.22)
	proxy.material_override = mat
	return proxy


func _build_portal_lines(root: Node3D, links: Array, positions_by_instance: Dictionary, nif_resolution: Array, portal_graph: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"line_count": 0,
		"thick_edge_count": 0,
		"endpoint_marker_count": 0,
	}
	if links.is_empty():
		return result

	var preview_by_instance: Dictionary = {}
	for nif_value in nif_resolution:
		var nif: Dictionary = nif_value as Dictionary
		preview_by_instance[int(nif.get("instance_index", -1))] = bool(nif.get("preview_ok", false))

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "PortalLinks_AllThin"
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var line_count: int = 0
	var thick_count: int = 0
	var marker_count: int = 0
	var seen_edges: Dictionary = {}
	var y_lift: Vector3 = Vector3.UP * 18.0
	for link_value in links:
		var link: Dictionary = link_value as Dictionary
		var from_idx: int = int(link.get("from_instance", -1))
		var to_idx: int = int(link.get("to_instance", -1))
		if not positions_by_instance.has(from_idx) or not positions_by_instance.has(to_idx):
			continue
		var lo: int = mini(from_idx, to_idx)
		var hi: int = maxi(from_idx, to_idx)
		var edge_key: String = "%d:%d" % [lo, hi]
		if seen_edges.has(edge_key):
			continue
		seen_edges[edge_key] = true
		var a: Vector3 = positions_by_instance[from_idx] as Vector3
		var b: Vector3 = positions_by_instance[to_idx] as Vector3
		var ap: Vector3 = a + y_lift
		var bp: Vector3 = b + y_lift
		mesh.surface_add_vertex(ap)
		mesh.surface_add_vertex(bp)
		line_count += 1
		var distance: float = ap.distance_to(bp)
		var missing_preview: bool = not bool(preview_by_instance.get(from_idx, false)) or not bool(preview_by_instance.get(to_idx, false))
		var long_edge: bool = distance >= float(portal_graph.get("long_edge_threshold", 110.0))
		if missing_preview or long_edge:
			_add_portal_edge_marker(root, "PortalEdge_%s" % edge_key.replace(":", "_"), ap, bp, missing_preview, long_edge)
			thick_count += 1
			marker_count += _add_portal_endpoint_markers(root, "PortalEndpoints_%s" % edge_key.replace(":", "_"), ap, bp, missing_preview)
	mesh.surface_end()
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(0.9, 0.9, 1.0, 0.85)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	result["line_count"] = line_count
	result["thick_edge_count"] = thick_count
	result["endpoint_marker_count"] = marker_count
	return result


func _add_portal_edge_marker(root: Node3D, name: String, a: Vector3, b: Vector3, missing_preview: bool, long_edge: bool) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.001:
		return
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = name
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.8 if missing_preview else 1.1, 1.8 if missing_preview else 1.1, length)
	marker.mesh = box
	var center: Vector3 = (a + b) * 0.5
	marker.look_at_from_position(center, center + dir.normalized(), Vector3.UP)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	if missing_preview:
		mat.albedo_color = Color(1.0, 0.15, 0.95, 1.0)
	elif long_edge:
		mat.albedo_color = Color(1.0, 0.85, 0.15, 1.0)
	else:
		mat.albedo_color = Color(0.9, 0.9, 1.0, 1.0)
	marker.material_override = mat
	root.add_child(marker)


func _add_portal_endpoint_markers(root: Node3D, name: String, a: Vector3, b: Vector3, missing_preview: bool) -> int:
	var parent: Node3D = Node3D.new()
	parent.name = name
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.15, 0.95, 1.0) if missing_preview else Color(1.0, 0.85, 0.15, 1.0)
	for i in range(2):
		var s: MeshInstance3D = MeshInstance3D.new()
		s.name = "Endpoint_%d" % i
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 3.5 if missing_preview else 2.2
		sphere.height = 7.0 if missing_preview else 4.4
		s.mesh = sphere
		s.position = a if i == 0 else b
		s.material_override = mat
		parent.add_child(s)
	root.add_child(parent)
	return 2


func _build_portal_graph_diagnostics(links: Array, positions_by_instance: Dictionary, nif_resolution: Array) -> Dictionary:
	var preview_by_instance: Dictionary = {}
	var logical_by_instance: Dictionary = {}
	var chunk_by_instance: Dictionary = {}
	var name_by_instance: Dictionary = {}
	for nif_value in nif_resolution:
		var nif: Dictionary = nif_value as Dictionary
		var idx: int = int(nif.get("instance_index", -1))
		if idx < 0:
			continue
		preview_by_instance[idx] = bool(nif.get("preview_ok", false))
		logical_by_instance[idx] = bool(nif.get("logical_connector", false))
		chunk_by_instance[idx] = int(nif.get("chunk_index", -1))
		name_by_instance[idx] = str(nif.get("nif_name", ""))

	var adjacency: Dictionary = {}
	for key in positions_by_instance.keys():
		adjacency[int(key)] = []

	var unique_edges: Dictionary = {}
	for link_value in links:
		var link: Dictionary = link_value as Dictionary
		var a: int = int(link.get("from_instance", -1))
		var b: int = int(link.get("to_instance", -1))
		if a < 0 or b < 0:
			continue
		if not adjacency.has(a):
			adjacency[a] = []
		if not adjacency.has(b):
			adjacency[b] = []
		(adjacency[a] as Array).append(b)
		(adjacency[b] as Array).append(a)
		var lo: int = mini(a, b)
		var hi: int = maxi(a, b)
		unique_edges["%d:%d" % [lo, hi]] = {"a": lo, "b": hi}

	var components: Array = []
	var seen: Dictionary = {}
	for key in adjacency.keys():
		var start: int = int(key)
		if seen.has(start):
			continue
		var stack: Array = [start]
		var comp: Array = []
		seen[start] = true
		while not stack.is_empty():
			var u: int = int(stack.pop_back())
			comp.append(u)
			var neigh: Array = adjacency.get(u, []) as Array
			for v_value in neigh:
				var v: int = int(v_value)
				if not seen.has(v):
					seen[v] = true
					stack.append(v)
		comp.sort()
		components.append(comp)

	var component_sizes: Array = []
	for comp_value in components:
		var comp_arr: Array = comp_value as Array
		component_sizes.append(comp_arr.size())
	component_sizes.sort()
	component_sizes.reverse()

	var failed_connectors: Array = []
	var logical_connectors: Array = []
	for key in adjacency.keys():
		var idx: int = int(key)
		var degree: int = (adjacency.get(idx, []) as Array).size()
		if degree > 0 and preview_by_instance.has(idx) and not bool(preview_by_instance[idx]):
			var row_connector: Dictionary = {
				"instance": idx,
				"degree": degree,
				"chunk": int(chunk_by_instance.get(idx, -1)),
				"name": str(name_by_instance.get(idx, "")),
			}
			if bool(logical_by_instance.get(idx, false)):
				logical_connectors.append(row_connector)
			else:
				failed_connectors.append(row_connector)

	var edge_lengths: Array = []
	var missing_preview_edges: Array = []
	for edge_key in unique_edges.keys():
		var edge: Dictionary = unique_edges[edge_key] as Dictionary
		var a: int = int(edge.get("a", -1))
		var b: int = int(edge.get("b", -1))
		if not positions_by_instance.has(a) or not positions_by_instance.has(b):
			continue
		var pa: Vector3 = positions_by_instance[a] as Vector3
		var pb: Vector3 = positions_by_instance[b] as Vector3
		var distance: float = pa.distance_to(pb)
		var row: Dictionary = {
			"from": a,
			"to": b,
			"distance": distance,
			"from_chunk": int(chunk_by_instance.get(a, -1)),
			"to_chunk": int(chunk_by_instance.get(b, -1)),
			"from_name": str(name_by_instance.get(a, "")),
			"to_name": str(name_by_instance.get(b, "")),
			"from_preview_ok": bool(preview_by_instance.get(a, false)),
			"to_preview_ok": bool(preview_by_instance.get(b, false)),
			"from_logical_connector": bool(logical_by_instance.get(a, false)),
			"to_logical_connector": bool(logical_by_instance.get(b, false)),
		}
		edge_lengths.append(row)
		if not bool(row.get("from_preview_ok", false)) or not bool(row.get("to_preview_ok", false)):
			missing_preview_edges.append(row)
	edge_lengths.sort_custom(Callable(self, "_sort_edge_distance_desc"))
	missing_preview_edges.sort_custom(Callable(self, "_sort_edge_distance_desc"))

	var long_edges: Array = []
	for row_value in edge_lengths:
		var row_dict: Dictionary = row_value as Dictionary
		if float(row_dict.get("distance", 0.0)) >= 110.0:
			long_edges.append(row_dict)

	return {
		"component_count": components.size(),
		"component_sizes": component_sizes,
		"connected_all_instances": components.size() == 1,
		"unique_edge_count": unique_edges.size(),
		"long_edge_threshold": 110.0,
		"long_edge_count": long_edges.size(),
		"long_edges_top": long_edges.slice(0, mini(long_edges.size(), 24)),
		"missing_preview_edge_count": missing_preview_edges.size(),
		"missing_preview_edges_top": missing_preview_edges.slice(0, mini(missing_preview_edges.size(), 24)),
		"failed_connector_instances": failed_connectors,
		"logical_connector_instances": logical_connectors,
	}


func _sort_edge_distance_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("distance", 0.0)) > float(b.get("distance", 0.0))


func _build_light_debug_nodes(root: Node3D, lights: Array, world_scale: float) -> int:
	for light_value in lights:
		var light_row: Dictionary = light_value as Dictionary
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "Light_%03d" % int(light_row.get("light_index", 0))
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 8.0
		sphere.height = 16.0
		marker.mesh = sphere
		marker.position = Vector3(
			float(light_row.get("x", 0.0)) * world_scale,
			float(light_row.get("z", 0.0)) * world_scale,
			-float(light_row.get("y", 0.0)) * world_scale
		)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.45, 1.0)
		marker.material_override = mat
		root.add_child(marker)
	return lights.size()


func _daoc_local_to_godot(placement: Dictionary, world_scale: float) -> Vector3:
	# Les chunks NIF sont convertis par NifCoordinateSystem :
	# Godot.x = DAoC/NIF.x ; Godot.y = DAoC/NIF.z ; Godot.z = -DAoC/NIF.y.
	# Les placements dungeon.place doivent utiliser exactement la meme convention ;
	# sinon les salles semblent proches mais les portes ne tombent pas en face.
	# HF3 garde cette position mais inverse le signe de rotation dans _make_instance_root().
	return Vector3(
		float(placement.get("x", 0.0)) * world_scale,
		float(placement.get("z", 0.0)) * world_scale,
		-float(placement.get("y", 0.0)) * world_scale
	)


func _daoc_axis_to_godot(axis: Vector3) -> Vector3:
	# Meme changement de base que NifCoordinateSystem.S pour les axes de rotation
	# des instances : (x, y, z) DAoC/NIF -> (x, z, -y) Godot.
	return Vector3(axis.x, axis.z, -axis.y)


func _chunk_nif_name(chunks: Array, chunk_index: int) -> String:
	if chunk_index < 0 or chunk_index >= chunks.size():
		return "missing_chunk_%d.nif" % chunk_index
	var entry: Dictionary = chunks[chunk_index] as Dictionary
	return str(entry.get("nif_name", "missing_chunk_%d.nif" % chunk_index))


func _material_for_chunk(chunk_index: int, alpha: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var col: Color = _color_for_chunk(chunk_index)
	col.a = alpha
	mat.albedo_color = col
	mat.roughness = 0.85
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _color_for_chunk(chunk_index: int) -> Color:
	var palette: Array = [
		Color(0.50, 0.62, 0.80, 1.0),
		Color(0.70, 0.58, 0.45, 1.0),
		Color(0.45, 0.72, 0.58, 1.0),
		Color(0.72, 0.50, 0.64, 1.0),
		Color(0.75, 0.70, 0.45, 1.0),
	]
	var idx: int = absi(chunk_index) % palette.size()
	return palette[idx] as Color


func _count_mesh_instances(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _compact_chunk_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"source_path": str(result.get("source_path", "")),
		"chunk_count": int(result.get("chunk_count", 0)),
		"chunks": result.get("chunks", []),
		"error": str(result.get("error", "")),
	}


func _compact_place_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"source_path": str(result.get("source_path", "")),
		"placement_count": int(result.get("placement_count", 0)),
		"placements": result.get("placements", []),
		"error": str(result.get("error", "")),
	}


func _compact_portal_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"source_path": str(result.get("source_path", "")),
		"declared_count": int(result.get("declared_count", 0)),
		"link_count": int(result.get("link_count", 0)),
		"links": result.get("links", []),
		"error": str(result.get("error", "")),
	}


func _compact_lights_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"source_path": str(result.get("source_path", "")),
		"light_count": int(result.get("light_count", 0)),
		"lights": result.get("lights", []),
		"error": str(result.get("error", "")),
	}


func _safe_name(value: String) -> String:
	var out: String = value.strip_edges().replace(" ", "_")
	for ch in ["/", "\\", ":", ";", ",", ".", "'", "\"", "[", "]", "(", ")"]:
		out = out.replace(ch, "_")
	while out.find("__") != -1:
		out = out.replace("__", "_")
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	if out == "":
		return "unnamed"
	return out
