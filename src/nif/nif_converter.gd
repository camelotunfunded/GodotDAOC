## NifConverter — transforme l'arbre de blocs (NifReader) en GABARIT Godot,
## compatible avec le pipeline de placement existant de ZoneViewer.gd.
##
## Contrat respecte (pour reutiliser tel quel _place_fixtures / _apply_textures /
## _template_min_y de ZoneViewer) :
##   * racine = Node3D contenant UN MeshInstance3D multi-surfaces ;
##   * geometrie CUITE en espace modele Godot (Y-up), transforms de noeud a
##     l'identite -> le min-Y du maillage est directement utilisable pour l'ancrage ;
##   * chaque surface porte un Material dont `resource_name` = nom du fichier
##     texture -> _apply_textures() de ZoneViewer le resout (DDS decode inclus).
##
## Architecture NIF reprise de godotwind (MIT, (c) 2026 Liho). NiTriShapeData
## suit la disposition CONFIRMEE DAoC 4.2.2.0 (NOTE_TERRAIN §11).
class_name NifConverter
extends RefCounted

const TravelCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTravelCodec.gd")

## P1-115 : les nœuds « door… » (règle de nommage du client d origine,
## `FUN_00463f6d`) deviennent des MeshInstance3D à part, cuits au MÊME endroit
## que le reste : fermés, le gabarit est identique à celui d avant, AABB et
## ancrage compris. Décoché, tout retombe dans le maillage unique.
static var split_door_nodes := true


## Construit le gabarit d'un modele. `model_name` sert de nom de noeud.
static func build_template(nif: NifReader, model_name: String, prefer_dense_lod: bool = false) -> Node3D:
	return _build_template_with_options(nif, model_name, false, prefer_dense_lod)


## Variante reservee au DungeonLab : parcourt tous les enfants de NiLODNode /
## NiSwitchNode au lieu de ne garder que le premier. Les chunks de donjon DAoC
## peuvent sinon apparaitre comme des portes/morceaux isoles alors que le NIF
## contient davantage de geometrie dans des branches voisines.
static func build_template_full_hierarchy(nif: NifReader, model_name: String) -> Node3D:
	return _build_template_with_options(nif, model_name, true)


static func _build_template_with_options(nif: NifReader, model_name: String, include_all_lod_children: bool, prefer_dense_lod: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = model_name

	# Racines : footer si present, sinon bloc 0.
	var root_indices: Array = []
	if nif.roots.size() > 0:
		root_indices = nif.roots
	elif nif.blocks.size() > 0:
		root_indices = [0]
	var original_root_indices := root_indices.duplicate()
	# Règle historique : seule la famille explicitement relevée ci-dessous est
	# extraite par sa branche `visible`. Les maisons ordinaires gardent exactement
	# leur hiérarchie et leur pivot antérieurs.
	var use_visible_only := _should_use_visible_only(model_name)
	var named_visible_indices := _find_named_node_refs(nif, "visible")
	var visible_indices := named_visible_indices if use_visible_only else []
	if use_visible_only and not visible_indices.is_empty():
		root_indices = visible_indices

	# 1) Rassemble les shapes avec leur transform NIF accumulee (espace NIF).
	var shapes: Array = []
	for ri in root_indices:
		_gather_with_options(nif, ri, Transform3D.IDENTITY, shapes, include_all_lod_children, use_visible_only, prefer_dense_lod)
	_add_repaired_coverage_if_needed(nif, root_indices, shapes, include_all_lod_children, use_visible_only, prefer_dense_lod)
	# Le sens d'un noeud `visible` varie selon les exports DAoC. Il ne devient un
	# masque global que si ses triangles représentent au moins la moitié de la
	# géométrie collectée. Une petite branche `visible` de porte ou de fenêtre ne
	# peut ainsi plus rendre transparent le bâtiment entier (cas Btavern), tandis
	# qu'un vrai couple coque-visible/coque-collision conserve son filtrage.
	if not use_visible_only and not named_visible_indices.is_empty() and not shapes.is_empty():
		var visible_shapes: Array = []
		for ri in named_visible_indices:
			_gather_with_options(nif, ri, Transform3D.IDENTITY, visible_shapes,
				include_all_lod_children, true, prefer_dense_lod)
		var total_weight := _geometry_weight(nif, shapes)
		var visible_weight := _geometry_weight(nif, visible_shapes)
		if visible_weight > 0 and visible_weight * 2 >= total_weight:
			var visible_blocks: Dictionary = {}
			for visible_shape_value in visible_shapes:
				var visible_shape: Dictionary = visible_shape_value as Dictionary
				var visible_block: Dictionary = visible_shape.get("block", {}) as Dictionary
				visible_blocks[int(visible_block.get("index", -1))] = true
			for shape_value in shapes:
				var shape: Dictionary = shape_value as Dictionary
				var block: Dictionary = shape.get("block", {}) as Dictionary
				if not visible_blocks.has(int(block.get("index", -1))):
					shape["daoc_hidden_collision"] = true
	if shapes.is_empty() and use_visible_only:
		use_visible_only = false
		root_indices = original_root_indices
		for ri in root_indices:
			_gather_with_options(nif, ri, Transform3D.IDENTITY, shapes, include_all_lod_children, false, prefer_dense_lod)
		_add_repaired_coverage_if_needed(nif, root_indices, shapes, include_all_lod_children, false, prefer_dense_lod)
	if shapes.is_empty():
		return root

	# 2) Cuit chaque shape en une surface de l'unique ArrayMesh.
	var mesh := ArrayMesh.new()
	var door_groups: Dictionary = {}
	for sh in shapes:
		var door: Dictionary = (sh as Dictionary).get("door", {}) as Dictionary
		if split_door_nodes and not door.is_empty():
			var key := int(door.get("block", -1))
			if not door_groups.has(key):
				door_groups[key] = {"door": door, "shapes": []}
			(door_groups[key]["shapes"] as Array).append(sh)
			continue
		_add_surface(nif, mesh, sh["block"], sh["accum"], bool(sh.get("daoc_hidden_collision", false)))
	if mesh.get_surface_count() == 0 and use_visible_only and door_groups.is_empty():
		use_visible_only = false
		shapes.clear()
		root_indices = original_root_indices
		for ri in root_indices:
			_gather_with_options(nif, ri, Transform3D.IDENTITY, shapes, include_all_lod_children, false, prefer_dense_lod)
		_add_repaired_coverage_if_needed(nif, root_indices, shapes, include_all_lod_children, false, prefer_dense_lod)
		mesh = ArrayMesh.new()
		for sh in shapes:
			_add_surface(nif, mesh, sh["block"], sh["accum"])
	if mesh.get_surface_count() == 0 and door_groups.is_empty():
		return root

	if mesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = model_name + "_mesh"
		mi.mesh = mesh
		root.add_child(mi)
	for key in door_groups:
		_add_door_mesh(nif, root, door_groups[key] as Dictionary)
	if not door_groups.is_empty():
		root.set_meta("daoc_door_count", door_groups.size())
	return root


## P1-115 : une porte = un MeshInstance3D a transform IDENTITE, sommets cuits en
## espace modele comme le reste. Le pivot (origine du nœud « door… ») et la
## hauteur voyagent en métadonnées ; `DaocGameWorld.apply_door_visual` fait
## pivoter autour de lui. L identifiant complet se pose au placement
## (`DaocPropBuilder`), seul endroit qui connaisse zone et fixture.
static func _add_door_mesh(nif: NifReader, root: Node3D, group: Dictionary) -> void:
	var door: Dictionary = group.get("door", {}) as Dictionary
	var door_mesh := ArrayMesh.new()
	var leaves: Dictionary = {}
	for sh in group.get("shapes", []) as Array:
		_add_surface(nif, door_mesh, sh["block"], sh["accum"], bool(sh.get("daoc_hidden_collision", false)))
		var leaf := int((sh as Dictionary).get("door_leaf", -1))
		if not leaves.has(leaf):
			leaves[leaf] = ArrayMesh.new()
		_add_surface(nif, leaves[leaf] as ArrayMesh, sh["block"], sh["accum"], bool(sh.get("daoc_hidden_collision", false)))
	if door_mesh.get_surface_count() == 0:
		return
	var info: Dictionary = door.get("info", {}) as Dictionary
	var accum: Transform3D = door.get("accum", Transform3D.IDENTITY)
	var node_pivot := NifCoordinateSystem.position(accum.origin)
	var split := _double_door_leaves(door_mesh.get_aabb(), leaves)
	if split.is_empty():
		split = [{"mesh": door_mesh, "pivot": node_pivot, "sign": 1.0, "suffix": ""}]
	for part in split:
		var mesh := (part as Dictionary)["mesh"] as ArrayMesh
		var mi := MeshInstance3D.new()
		mi.name = "door_" + str(door.get("name", "door")).validate_node_name() + str(part["suffix"])
		mi.mesh = mesh
		mi.set_meta("daoc_door_node", str(door.get("name", "")))
		mi.set_meta("daoc_door_kind", int(info.get("kind", 1)))
		if info.has("absolute_id"):
			mi.set_meta("daoc_door_absolute_id", int(info["absolute_id"]))
		else:
			mi.set_meta("daoc_door_piece", int(info.get("piece", 0)))
		mi.set_meta("daoc_door_pivot", part["pivot"])
		mi.set_meta("daoc_door_turn_sign", float(part["sign"]))
		mi.set_meta("daoc_door_height", mesh.get_aabb().size.y)
		mi.add_to_group("daoc_doors", true)
		root.add_child(mi)


## 2026-09-27 — PORTES DOUBLES (retour utilisateur : « elles tournent d un
## seul bloc sur l axe central »). Le nœud « door… » d une porte double porte
## deux battants côte à côte, et son origine est au MILIEU. Deux sous-branches
## qui couvrent chacune une bonne part de la largeur sans se recouvrir sont
## deux battants : chacun pivote sur son bord EXTÉRIEUR, en sens opposés, pour
## s ouvrir du même côté. Sinon (porte simple, cadre + panneau…) : rien.
static func _double_door_leaves(total: AABB, leaves: Dictionary) -> Array:
	var parts: Array = []
	for key in leaves:
		var mesh := leaves[key] as ArrayMesh
		if mesh != null and mesh.get_surface_count() > 0:
			parts.append({"mesh": mesh, "aabb": mesh.get_aabb()})
	if parts.size() != 2:
		return []
	var along_x := total.size.x >= total.size.z
	var width := total.size.x if along_x else total.size.z
	if width <= 0.0:
		return []
	var center := total.get_center()
	var a: AABB = parts[0]["aabb"]
	var b: AABB = parts[1]["aabb"]
	var a_min := a.position.x if along_x else a.position.z
	var a_max := a_min + (a.size.x if along_x else a.size.z)
	var b_min := b.position.x if along_x else b.position.z
	var b_max := b_min + (b.size.x if along_x else b.size.z)
	var overlap := maxf(0.0, minf(a_max, b_max) - maxf(a_min, b_min))
	if (a_max - a_min) < width * 0.3 or (b_max - b_min) < width * 0.3 or overlap > width * 0.1:
		return []
	var out: Array = []
	for index in 2:
		var part: Dictionary = parts[index]
		var box: AABB = part["aabb"]
		var lo := box.position.x if along_x else box.position.z
		var hi := lo + (box.size.x if along_x else box.size.z)
		var mid := (lo + hi) * 0.5
		var on_low_side := mid < (center.x if along_x else center.z)
		var hinge := lo if on_low_side else hi
		var box_center := box.get_center()
		var pivot := Vector3(hinge, box_center.y, box_center.z) if along_x \
			else Vector3(box_center.x, box_center.y, hinge)
		out.append({"mesh": part["mesh"], "pivot": pivot,
			"sign": 1.0 if on_low_side else -1.0, "suffix": "_L" if on_low_side else "_R"})
	return out


## Parcourt l'arbre en accumulant les transforms NIF (sans conversion d'axes).
static func _gather(nif: NifReader, idx: int, parent_accum: Transform3D, shapes: Array) -> void:
	_gather_with_options(nif, idx, parent_accum, shapes, false, false)


static func _gather_with_options(nif: NifReader, idx: int, parent_accum: Transform3D, shapes: Array, include_all_lod_children: bool, filter_non_visual: bool = false, prefer_dense_lod: bool = false, hidden_collision_branch: bool = false, depth: int = 0, ancestors: Dictionary = {}) -> void:
	# Les lectures partielles Gamebryo peuvent conserver une référence enfant
	# cyclique située après le point de désynchronisation. Une limite explicite
	# empêche qu'un modèle récupérable fasse déborder la pile du runtime.
	var visits := int(ancestors.get("__visits", 0)) + 1
	ancestors["__visits"] = visits
	if idx < 0 or depth >= 128 or visits > 512 or ancestors.has(idx):
		return
	ancestors[idx] = true
	var b: Dictionary = _block_for_ref(nif, idx)
	if b.is_empty():
		ancestors.erase(idx)
		return
	var t: String = b.get("type", "")
	if filter_non_visual and _is_non_visual_fx_or_collision_branch(str(b.get("name", ""))):
		ancestors.erase(idx)
		return
	var hidden_here := hidden_collision_branch or _is_unambiguous_collision_branch(str(b.get("name", "")))
	var accum: Transform3D = parent_accum * b.get("nif_transform", Transform3D.IDENTITY)
	# P1-115 : la première porte rencontrée en descendant garde toute sa branche.
	var door_here := false
	if split_door_nodes and not ancestors.has("__door") and (t == "NiNode" or t == "NiLODNode" or t == "NiSwitchNode"):
		var door_info: Dictionary = TravelCodecScript.door_node_info(str(b.get("name", "")))
		if not door_info.is_empty():
			ancestors["__door"] = {"name": str(b.get("name", "")), "info": door_info, "accum": accum, "block": int(b.get("index", idx))}
			door_here = true
	if t == "NiNode" or t == "NiBillboardNode":
		for c in b.get("children", []):
			# 2026-09-27 : chaque enfant direct d une porte est un BATTANT possible
			# (portes doubles : deux battants sous le même nœud « door… »).
			if door_here:
				ancestors["__door_leaf"] = int(c)
			_gather_with_options(nif, c, accum, shapes, include_all_lod_children, filter_non_visual, prefer_dense_lod, hidden_here, depth + 1, ancestors)
		if door_here:
			ancestors.erase("__door_leaf")
	elif t == "NiLODNode" or t == "NiSwitchNode":
		var kids: Array = b.get("children", [])
		if include_all_lod_children:
			for c in kids:
				_gather_with_options(nif, c, accum, shapes, include_all_lod_children, filter_non_visual, prefer_dense_lod, hidden_here, depth + 1, ancestors)
		elif kids.size() > 0:
			# NiSwitchNode reste un choix de variante, jamais un niveau de detail.
			var selected: int = select_dense_lod_child(nif, kids, filter_non_visual) if prefer_dense_lod and t == "NiLODNode" else int(kids[0])
			_gather_with_options(nif, selected, accum, shapes, include_all_lod_children, filter_non_visual, prefer_dense_lod, hidden_here, depth + 1, ancestors)
	elif t == "NiTriShape" or t == "NiTriStrips" or t == "NiParticles" or t == "NiAutoNormalParticles" or t == "NiRotatingParticles" or t == "NiParticleSystem":
		shapes.append({"block": b, "accum": accum, "daoc_hidden_collision": hidden_here, "door": ancestors.get("__door", {}),
			"door_leaf": int(ancestors.get("__door_leaf", -1))})
	if door_here:
		ancestors.erase("__door")
	ancestors.erase(idx)


## P1-21U : heuristique de densite, pas une lecture des distances LOD.
## Egalite / absence de geometrie : conserver le premier enfant, stable.
static func select_dense_lod_child(nif: NifReader, kids: Array, filter_non_visual: bool = false) -> int:
	var selected := int(kids[0]) if not kids.is_empty() else -1
	var best := -1
	for child in kids:
		var score := lod_triangle_count(nif, int(child), filter_non_visual)
		if score > best:
			best = score
			selected = int(child)
	return selected


## Compte le maillage rendu : somme des branches ordinaires, MAX des LOD
## imbriques, premier enfant des Switch. Les particules ne sont pas des triangles.
static func lod_triangle_count(nif: NifReader, idx: int, filter_non_visual: bool = false, ancestors: Array = []) -> int:
	if idx < 0 or ancestors.has(idx) or ancestors.size() >= 128:
		return 0
	var b := _block_for_ref(nif, idx)
	if b.is_empty() or (filter_non_visual and _is_non_visual_fx_or_collision_branch(str(b.get("name", "")))):
		return 0
	var kind := str(b.get("type", ""))
	if kind == "NiTriShape" or kind == "NiTriStrips":
		var data := _data_block_for_ref(nif, int(b.get("data_ref", -1)))
		var vertices: PackedVector3Array = data.get("vertices", PackedVector3Array())
		var indices: PackedInt32Array = data.get("indices", PackedInt32Array())
		return indices.size() / 3 if not vertices.is_empty() else 0
	if kind not in ["NiNode", "NiBillboardNode", "NiLODNode", "NiSwitchNode"]:
		return 0
	var trail := ancestors.duplicate()
	trail.append(idx)
	var kids: Array = b.get("children", [])
	if kind == "NiSwitchNode":
		return lod_triangle_count(nif, int(kids[0]), filter_non_visual, trail) if not kids.is_empty() else 0
	var total := 0
	for child in kids:
		var count := lod_triangle_count(nif, int(child), filter_non_visual, trail)
		total = maxi(total, count) if kind == "NiLODNode" else total + count
	return total


static func _add_repaired_coverage_if_needed(nif: NifReader, root_indices: Array, shapes: Array, include_all_lod_children: bool, filter_non_visual: bool, prefer_dense_lod: bool = false) -> void:
	var total_geometry := _count_geometry_blocks(nif)
	if total_geometry <= 1 or shapes.size() >= total_geometry:
		return
	# Some old DAoC NIFs contain recoverable particle/controller chunks. After a
	# soft resync, a few child refs can point one block after the intended node.
	# Keep the normal path first, then repair coverage only when it clearly lost
	# most of the geometry, as with brghouse.nif.
	if shapes.size() * 2 > total_geometry:
		return
	var existing: Dictionary = {}
	for sh in shapes:
		var block: Dictionary = (sh as Dictionary).get("block", {}) as Dictionary
		existing[int(block.get("index", -1))] = true
	var visited: Dictionary = {}
	for ri in root_indices:
		_gather_repaired(nif, int(ri), Transform3D.IDENTITY, shapes, include_all_lod_children, visited, existing, filter_non_visual, prefer_dense_lod)


static func _gather_repaired(nif: NifReader, idx: int, parent_accum: Transform3D, shapes: Array, include_all_lod_children: bool, visited: Dictionary, existing: Dictionary, filter_non_visual: bool, prefer_dense_lod: bool = false) -> void:
	if idx < 0:
		return
	var b: Dictionary = _block_for_ref(nif, idx)
	if b.is_empty():
		return
	var block_index := int(b.get("index", idx))
	var visit_key := "%d" % block_index
	if visited.has(visit_key):
		return
	visited[visit_key] = true
	var t: String = b.get("type", "")
	if filter_non_visual and _is_non_visual_fx_or_collision_branch(str(b.get("name", ""))):
		return
	var accum: Transform3D = parent_accum * b.get("nif_transform", Transform3D.IDENTITY)
	if t == "NiNode" or t == "NiBillboardNode":
		for c in b.get("children", []):
			for candidate in _child_ref_candidates(nif, int(c)):
				_gather_repaired(nif, candidate, accum, shapes, include_all_lod_children, visited, existing, filter_non_visual, prefer_dense_lod)
	elif t == "NiLODNode" or t == "NiSwitchNode":
		var kids: Array = b.get("children", [])
		if include_all_lod_children:
			for c in kids:
				for candidate in _child_ref_candidates(nif, int(c)):
					_gather_repaired(nif, candidate, accum, shapes, include_all_lod_children, visited, existing, filter_non_visual, prefer_dense_lod)
		elif kids.size() > 0:
			var selected: int = select_dense_lod_child(nif, kids, filter_non_visual) if prefer_dense_lod and t == "NiLODNode" else int(kids[0])
			# Une reference LOD valide ne doit pas recuperer sa voisine (autre LOD).
			var candidates: Array = [selected] if prefer_dense_lod and t == "NiLODNode" and not _block_for_ref(nif, selected).is_empty() else _child_ref_candidates(nif, selected)
			for candidate in candidates:
				_gather_repaired(nif, candidate, accum, shapes, include_all_lod_children, visited, existing, filter_non_visual, prefer_dense_lod)
	elif t == "NiTriShape" or t == "NiTriStrips" or t == "NiParticles" or t == "NiAutoNormalParticles" or t == "NiRotatingParticles" or t == "NiParticleSystem":
		if not existing.has(block_index):
			shapes.append({"block": b, "accum": accum})
			existing[block_index] = true


## Ajoute la geometrie d'une shape comme surface du maillage partage, cuite en
## espace modele Godot (sommets convertis une fois, transforms appliquees).
static func _add_surface(nif: NifReader, mesh: ArrayMesh, shape: Dictionary,
		accum: Transform3D, hidden_collision: bool = false) -> void:
	var data_ref: int = shape.get("data_ref", -1)
	if data_ref < 0:
		return
	var d: Dictionary = _data_block_for_ref(nif, data_ref)
	if d.is_empty():
		return
	var verts: PackedVector3Array = d.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = d.get("indices", PackedInt32Array())
	if verts.is_empty():
		return
	if indices.is_empty():
		# HF7 : un NiTriShapeData statique marque gb10_bad_triangle_indices n'est pas
		# une particule ; le transformer en nuage de quads produirait un faux visuel.
		# On le saute et on garde les autres surfaces deja valides du NIF.
		if bool(d.get("gb10_bad_triangle_indices", false)):
			return
		_add_particle_surface(nif, mesh, shape, accum, d, hidden_collision)
		return

	# Sommets : accumulation NIF -> conversion d'axes CENTRALISEE -> espace modele.
	var gverts := PackedVector3Array()
	gverts.resize(verts.size())
	for i in range(verts.size()):
		gverts[i] = NifCoordinateSystem.position(accum * verts[i])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = gverts

	var normals: PackedVector3Array = d.get("normals", PackedVector3Array())
	var have_normals := normals.size() == verts.size()
	if have_normals:
		var gn := PackedVector3Array()
		gn.resize(normals.size())
		for i in range(normals.size()):
			gn[i] = NifCoordinateSystem.normal(accum.basis * normals[i])
		arrays[Mesh.ARRAY_NORMAL] = gn

	var uvs: PackedVector2Array = d.get("uvs", PackedVector2Array())
	if uvs.size() == verts.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs

	# Jeu d'UV 1 : tuilage de la couche detail. Absent de la grande majorite des
	# NIF, present sur les surfaces multitexture (troncs, rochers a grain).
	var uvs2: PackedVector2Array = d.get("uvs2", PackedVector2Array())
	if uvs2.size() == verts.size():
		arrays[Mesh.ARRAY_TEX_UV2] = uvs2

	var colors: PackedColorArray = d.get("colors", PackedColorArray())
	if colors.size() == verts.size():
		arrays[Mesh.ARRAY_COLOR] = colors

	arrays[Mesh.ARRAY_INDEX] = indices

	# Pas de normales dans le NIF -> on les genere proprement avant d'ajouter.
	if not have_normals:
		var tmp := ArrayMesh.new()
		tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var st := SurfaceTool.new()
		st.create_from(tmp, 0)
		st.generate_normals()
		arrays = st.commit().surface_get_arrays(0)

	var si := mesh.get_surface_count()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Materiau : nom de texture dans resource_name (lu par DaocAssetIndexRegistry).
	# La couche detail voyage en metadonnee : le convertisseur ne connait que des
	# noms de fichiers, c'est le registre qui charge et cable les Texture2D.
	var mat := StandardMaterial3D.new()
	var layers := _find_texture_layers(nif, shape)
	var texname: String = layers.get("base", "")
	if texname != "":
		mat.resource_name = texname
	var detailname: String = layers.get("detail", "")
	if detailname != "":
		mat.set_meta("daoc_detail_texture", detailname)
		mat.set_meta("daoc_detail_uv_set", int(layers.get("detail_uv_set", 0)))
	if hidden_collision:
		_make_collision_material_invisible(mat)
	mesh.surface_set_material(si, mat)


## Fallback visuel pour NiParticles/NiAutoNormalParticles/NiRotatingParticles :
## les vieux NIF DAoC s'en servent pour feux, portails, fumee. Pour le viewer
## statique, on les represente par de petits quads non animes afin que le modele
## soit "place" et visible au lieu d'etre compte missing.
static func _add_particle_surface(nif: NifReader, mesh: ArrayMesh, shape: Dictionary,
		accum: Transform3D, d: Dictionary, hidden_collision: bool = false) -> void:
	var verts: PackedVector3Array = d.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return

	var radius: float = float(d.get("particle_radius", d.get("radius", 8.0)))
	var size: float = clampf(radius, 4.0, 64.0)

	var out_verts := PackedVector3Array()
	var out_indices := PackedInt32Array()
	var out_colors := PackedColorArray()
	var out_uvs := PackedVector2Array()
	var colors: PackedColorArray = d.get("colors", PackedColorArray())
	var use_colors := colors.size() == verts.size()

	var max_particles := mini(verts.size(), 2048)
	out_verts.resize(max_particles * 4)
	out_indices.resize(max_particles * 6)
	out_uvs.resize(max_particles * 4)
	if use_colors:
		out_colors.resize(max_particles * 4)

	for i in range(max_particles):
		var c := NifCoordinateSystem.position(accum * verts[i])
		var right := Vector3(size, 0.0, 0.0)
		var up := Vector3(0.0, size, 0.0)
		var vi := i * 4
		out_verts[vi + 0] = c - right - up
		out_verts[vi + 1] = c + right - up
		out_verts[vi + 2] = c + right + up
		out_verts[vi + 3] = c - right + up
		out_uvs[vi + 0] = Vector2(0.0, 1.0)
		out_uvs[vi + 1] = Vector2(1.0, 1.0)
		out_uvs[vi + 2] = Vector2(1.0, 0.0)
		out_uvs[vi + 3] = Vector2(0.0, 0.0)

		var ii := i * 6
		out_indices[ii + 0] = vi + 0
		out_indices[ii + 1] = vi + 1
		out_indices[ii + 2] = vi + 2
		out_indices[ii + 3] = vi + 0
		out_indices[ii + 4] = vi + 2
		out_indices[ii + 5] = vi + 3

		if use_colors:
			var col := colors[i]
			out_colors[vi + 0] = col
			out_colors[vi + 1] = col
			out_colors[vi + 2] = col
			out_colors[vi + 3] = col

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_verts
	arrays[Mesh.ARRAY_INDEX] = out_indices
	arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	if use_colors:
		arrays[Mesh.ARRAY_COLOR] = out_colors

	var si := mesh.get_surface_count()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var layers := _find_texture_layers(nif, shape)
	var texture_name := str(layers.get("base", ""))
	if texture_name != "":
		# Le registre chargera la vraie texture. Avant ce lien, chaque particule
		# devenait un gros carre blanc opaque autour des feux et des batiments.
		mat.resource_name = texture_name
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.82)
	else:
		# Un effet sans texture est incomplet : mieux vaut l'omettre visuellement
		# que dessiner une plaque blanche qui n'existait pas dans DAoC.
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	mat.vertex_color_use_as_albedo = use_colors
	mat.set_meta("daoc_particle_surface", true)
	if hidden_collision:
		_make_collision_material_invisible(mat)
	mesh.surface_set_material(si, mat)


static func _make_collision_material_invisible(material: StandardMaterial3D) -> void:
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.set_meta("daoc_hidden_collision_surface", true)


## Remonte les proprietes de la shape -> NiTexturingProperty -> NiSourceTexture.
## Renvoie les couches trouvees : `base` (slot 0), `detail` (slot 2) et le jeu
## d'UV que la couche detail utilise. `detail` reste vide sur l'immense majorite
## des NIF, qui n'ont qu'une seule couche.
static func _find_texture_layers(nif: NifReader, shape: Dictionary) -> Dictionary:
	var out := {"base": "", "detail": "", "detail_uv_set": 0}
	for pr in shape.get("property_refs", []):
		if pr < 0:
			continue
		var p: Dictionary = _property_block_for_ref(nif, pr)
		if p.is_empty():
			continue
		if p.get("type", "") == "NiSourceTexture":
			out["base"] = p.get("file_name", "")
			return out
		if p.get("type", "") == "NiTexturingProperty":
			var src_block: Dictionary = _source_texture_block_for_ref(nif, int(p.get("base_source_ref", -1)))
			if src_block.is_empty():
				continue
			out["base"] = src_block.get("file_name", "")
			var detail_block: Dictionary = _source_texture_block_for_ref(nif, int(p.get("detail_source_ref", -1)))
			if not detail_block.is_empty():
				out["detail"] = detail_block.get("file_name", "")
				out["detail_uv_set"] = int(p.get("detail_uv_set", 0))
			return out
	return out


## Conservee pour les appelants qui ne veulent que la couche de base.
static func _find_texture_name(nif: NifReader, shape: Dictionary) -> String:
	return str(_find_texture_layers(nif, shape).get("base", ""))


## NIF refs point to the original block index. The reader can soft-resync and
## skip unread blocks, so Array position is not always the same as block["index"].
static func _block_for_ref(nif: NifReader, ref: int) -> Dictionary:
	if ref < 0:
		return {}
	if ref < nif.blocks.size():
		var direct: Dictionary = nif.blocks[ref]
		if int(direct.get("index", ref)) == ref:
			return direct
	for block_value in nif.blocks:
		var block: Dictionary = block_value as Dictionary
		if int(block.get("index", -999999)) == ref:
			return block
	return {}


static func _data_block_for_ref(nif: NifReader, ref: int) -> Dictionary:
	for candidate in [ref, ref - 1, ref + 1]:
		var block := _block_for_ref(nif, int(candidate))
		if not block.is_empty() and block.has("vertices"):
			return block
	return {}


static func _property_block_for_ref(nif: NifReader, ref: int) -> Dictionary:
	var block := _block_for_ref(nif, ref)
	var t := str(block.get("type", ""))
	if t == "NiTexturingProperty" or t == "NiSourceTexture" or t == "NiMaterialProperty":
		return block
	return {}


static func _source_texture_block_for_ref(nif: NifReader, ref: int) -> Dictionary:
	var block := _block_for_ref(nif, ref)
	if str(block.get("type", "")) == "NiSourceTexture":
		return block
	return {}


static func _child_ref_candidates(nif: NifReader, ref: int) -> Array[int]:
	var out: Array[int] = []
	for candidate in [ref, ref - 1]:
		var block := _block_for_ref(nif, int(candidate))
		if block.is_empty():
			continue
		var t := str(block.get("type", ""))
		if t == "NiNode" or t == "NiBillboardNode" or t == "NiLODNode" or t == "NiSwitchNode" or t == "NiTriShape" or t == "NiTriStrips" or t == "NiParticles" or t == "NiAutoNormalParticles" or t == "NiRotatingParticles" or t == "NiParticleSystem":
			if not out.has(int(candidate)):
				out.append(int(candidate))
	return out


static func _count_geometry_blocks(nif: NifReader) -> int:
	var count := 0
	for block_value in nif.blocks:
		var block: Dictionary = block_value as Dictionary
		var t := str(block.get("type", ""))
		if t == "NiTriShape" or t == "NiTriStrips" or t == "NiParticles" or t == "NiAutoNormalParticles" or t == "NiRotatingParticles" or t == "NiParticleSystem":
			count += 1
	return count


static func _geometry_weight(nif: NifReader, shapes: Array) -> int:
	var total := 0
	var seen: Dictionary = {}
	for shape_value in shapes:
		var shape: Dictionary = (shape_value as Dictionary).get("block", {}) as Dictionary
		var block_index := int(shape.get("index", -1))
		if seen.has(block_index):
			continue
		seen[block_index] = true
		var data := _data_block_for_ref(nif, int(shape.get("data_ref", -1)))
		var indices: PackedInt32Array = data.get("indices", PackedInt32Array())
		if not indices.is_empty():
			total += indices.size()
		else:
			var vertices: PackedVector3Array = data.get("vertices", PackedVector3Array())
			total += vertices.size()
	return total


static func _find_named_node_refs(nif: NifReader, wanted_name: String) -> Array:
	var out: Array = []
	var wanted := wanted_name.to_lower()
	for block_value in nif.blocks:
		var block: Dictionary = block_value as Dictionary
		var t := str(block.get("type", ""))
		if (t == "NiNode" or t == "NiBillboardNode" or t == "NiLODNode" or t == "NiSwitchNode") and str(block.get("name", "")).to_lower() == wanted:
			out.append(int(block.get("index", -1)))
	return out


static func _should_use_visible_only(model_name: String) -> bool:
	var n := model_name.get_file().get_basename().to_lower()
	return n == "brghouse" or n.begins_with("brghouse_") or n == "bridgehouse" or n.begins_with("bridgehouse_")


static func _is_non_visual_fx_or_collision_branch(name_value: String) -> bool:
	var n := name_value.strip_edges().to_lower()
	if n == "":
		return false
	# Ce switch porte a la fois la branche `collidee` et la branche `visible` :
	# on le traverse, puis on coupe uniquement ses enfants de collision.
	if n == "collisionswitch":
		return false
	# Les branches de collision sont des volumes de service, jamais du rendu.
	# Les emitters/fire/anim restent parcourus : leurs particules ont maintenant
	# un fallback texture et ne doivent plus disparaitre avec les collisions.
	return n.begins_with("coll") or n.find("collision") >= 0


static func _is_unambiguous_collision_branch(name_value: String) -> bool:
	var n := name_value.strip_edges().to_lower()
	if n == "" or n == "collisionswitch":
		return false
	return n.begins_with("collid") or n.find("collision") >= 0 \
		or n.find("-coll-") >= 0 or n.begins_with("fenc-coll") \
		or n in ["co01", "nopick"]
