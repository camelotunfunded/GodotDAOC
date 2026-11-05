extends RefCounted
## Offline-cooked assets only. One batch per recipe/material and spatial chunk.
## Source fixture IDs remain in the normal prop index; collisions use native NIFs.

const Catalog = preload("res://src/daoc/DaocTreeCatalog.gd")
const FoliageWind = preload("res://src/daoc/vegetation/DaocFoliageWind.gd")
const MANIFEST := "res://generated/trees/scene_manifest.json"

## R10-HF2 — le vent dans les feuilles. Les materiaux cuits au Lab se
## repartissent en trois familles : `*_leaf` porte le shader de cartes
## billboardees, `*_frond` est un StandardMaterial3D en alpha scissor, `*_bark`
## est opaque. Les deux premieres recoivent le vent, la troisieme reste rigide -
## un tronc qui ondulerait serait pire qu'un arbre immobile.
##
## DECOCHE, les materiaux du Lab sont laisses TELS QUELS : aucune variante n'est
## creee, et le rendu est exactement celui d'avant ce jalon.
var foliage_wind_enabled := true
var foliage_wind_settings: Dictionary = {}
var foliage_wind_surfaces := 0
var catalog: Dictionary = {}
var assets: Dictionary = {}
var meshes: Dictionary = {}
var groups: Dictionary = {}
var world_scale := 1.0
var unit_scale := 12.0
var distance := 30000.0
var count := 0
var fallback_count := 0

func configure(client: String, settings: Dictionary) -> void:
	catalog = Catalog.load_client(client)
	world_scale = float(settings.get("world_scale", 1.0))
	unit_scale = float(settings.get("speedtree_units_to_daoc", 12.0))
	distance = float(settings.get("speedtree_visible_distance_raw", 30000.0)) * world_scale
	foliage_wind_enabled = bool(settings.get("foliage_wind_enabled", true))
	foliage_wind_settings = {"world_scale": world_scale}
	for key: String in FoliageWind.default_settings().keys():
		if settings.has(key):
			foliage_wind_settings[key] = settings[key]
	if FileAccess.file_exists(MANIFEST):
		var document = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if document is Dictionary:
			assets = document.get("entries", {})

func try_add(entry: Dictionary) -> bool:
	var token := Catalog.key(str(entry.get("file", "")))
	var offsets: Array = [Vector3.ZERO]
	if catalog.get("clusters", {}).has(token):
		var cluster: Dictionary = catalog.clusters[token]
		token = cluster.tree_key
		offsets = cluster.offsets_raw
	if not catalog.get("trees", {}).has(token) or not catalog.trees[token].has_replacement:
		return false
	if not assets.has(token):
		fallback_count += 1
		return false
	var record: Dictionary = assets[token]
	var variants: Array = record.get("variants", [])
	if variants.size() != 4 or variants.has(""):
		fallback_count += 1
		return false
	# Resolve every required mesh before mutating groups: a bosquet is all-or-none.
	var resolved: Array = []
	for i in offsets.size():
		var variant := posmod(int(entry.get("fixture_id", 0)) + i, 4)
		var path := str(variants[variant])
		var mesh := _mesh(path)
		if mesh == null:
			fallback_count += 1
			return false
		resolved.append({"path": path, "mesh": mesh})
	var mapping: Dictionary = catalog.trees[token]
	var fixture: Transform3D = entry.get("transform", Transform3D.IDENTITY)
	for i in offsets.size():
		var raw: Vector3 = offsets[i]
		var local_offset := NifCoordinateSystem.position(raw)
		local_offset.y += float(mapping.zoffset_raw)
		var local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * unit_scale * float(mapping.scale_factor)), local_offset)
		var xform := fixture * local
		var cell := Vector2i(floori(xform.origin.x / maxf(4096 * world_scale, 1)), floori(xform.origin.z / maxf(4096 * world_scale, 1)))
		var key := "%s:%d:%d" % [resolved[i].path, cell.x, cell.y]
		if not groups.has(key):
			groups[key] = {"mesh": resolved[i].mesh, "transforms": []}
		groups[key].transforms.append(xform)
		count += 1
	return true

func finish(parent: Node3D) -> int:
	for key in groups:
		var group: Dictionary = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = group.mesh
		mm.instance_count = group.transforms.size()
		var origin: Vector3 = group.transforms[0].origin
		var largest_scale := 0.0
		for i in group.transforms.size():
			var local: Transform3D = group.transforms[i]
			largest_scale = maxf(largest_scale, local.basis.x.length())
			local.origin -= origin
			mm.set_instance_transform(i, local)
		var node := MultiMeshInstance3D.new()
		node.name = "SpeedTreeBatch_%d" % parent.get_child_count()
		node.multimesh = mm
		node.position = origin
		node.visibility_range_end = distance
		# Leaf cards rotate around their native centers in the shader. Their
		# static mesh bounds describe only the exporter's camera direction.
		# One transformed mesh diagonal safely encloses every card rotation.
		node.extra_cull_margin = group.mesh.get_aabb().size.length() * largest_scale
		parent.add_child(node)
	return groups.size()

func _mesh(path: String) -> ArrayMesh:
	if meshes.has(path):
		return meshes[path]
	if not ResourceLoader.exists(path):
		return null
	var packed = load(path)
	if not packed is PackedScene:
		return null
	var scene: Node = packed.instantiate()
	var result: ArrayMesh = null
	if scene.get_child_count() == 1 and scene.get_child(0) is MeshInstance3D:
		var mi: MeshInstance3D = scene.get_child(0)
		result = mi.mesh.duplicate()
		for s in result.get_surface_count():
			var material := mi.get_surface_override_material(s)
			if material != null:
				# R10-HF2 : la variante ventee remplace le materiau du Lab quand
				# la surface est du feuillage. Le materiau d'origine n'est jamais
				# modifie - c'est une ressource partagee du paquet cuit.
				if foliage_wind_enabled:
					var animated := FoliageWind.build_any(material, foliage_wind_settings)
					if animated != null:
						foliage_wind_surfaces += 1
						material = animated
				result.surface_set_material(s, material)
	scene.free()
	meshes[path] = result
	return result
