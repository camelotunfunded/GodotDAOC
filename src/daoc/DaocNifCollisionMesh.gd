extends RefCounted
class_name DaocNifCollisionMesh

## P1-133 — LA COLLISION QUE LE MOTEUR D'ORIGINE UTILISE : celle du NIF.
##
## game.dll nomme les branches de service d'une fixture (`cDungeon::_LoadFixture*`,
## chaînes « Collidee », « pickee », « Bounding », « Climbs », « !door »,
## « alwayscollide ») : le moteur ne bute pas sur une boîte englobante, il bute
## sur le maillage que l'artiste a posé sous `collidee`. Mesuré dans les NIF :
##   Btavern      Collidee > « collision BTavernExt », « collision stair »,
##                « collision Btavern2Int », tabourets, tonneaux…
##   Bfarmhouse   collidee > « collision inside », « collision steps », « collision loft »
##   Bwearyhouse  collidee > « coll house », « COLL PORCH », « COLL STEPS »…
##   BCaerSidiBridge  collidee > « coll bridge », « coll bridge uprights »
## Une maison a donc des murs AVEC une ouverture de porte et un plancher, un pont
## un tablier praticable : l'entrée est dans la géométrie, pas dans une règle.
##
## Sortie : triangles en espace MODÈLE (même conversion d'axes que
## NifConverter._add_surface), prêts pour un ConcavePolygonShape3D. Vide = le NIF
## n'a pas de branche de collision ; l'appelant garde alors l'ancienne AABB.

const MAX_DEPTH := 96

static var _cache: Dictionary = {} # chemin absolu -> PackedVector3Array


static func faces_for_nif(abs_path: String) -> PackedVector3Array:
	if abs_path == "":
		return PackedVector3Array()
	var key := abs_path.to_lower()
	if _cache.has(key):
		return _cache[key] as PackedVector3Array
	var faces := PackedVector3Array()
	var reader := NifReader.new()
	if reader.read(abs_path) and not reader.failed:
		faces = faces_for_reader(reader)
	_cache[key] = faces
	return faces


static func faces_for_reader(nif: NifReader) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var roots: Array = nif.roots if nif.roots.size() > 0 else ([0] if nif.blocks.size() > 0 else [])
	var seen: Dictionary = {}
	for r in roots:
		_walk(nif, int(r), Transform3D.IDENTITY, false, faces, seen, 0)
	return faces


## Nom d'un noeud qui OUVRE une branche de collision. « collisionswitch » n'en est
## pas une : c'est l'aiguillage visible / collidee, on le traverse.
static func is_collision_node_name(name_value: String) -> bool:
	var n := name_value.strip_edges().to_lower()
	if n == "" or n.contains("switch"):
		return false
	return n.begins_with("collidee") or n.begins_with("collision") or n.begins_with("coll ") \
		or n.begins_with("coll-") or n.begins_with("collhouse") or n == "coll" or n == "alwayscollide"


static func _walk(nif: NifReader, idx: int, parent: Transform3D, inside: bool, faces: PackedVector3Array, seen: Dictionary, depth: int) -> void:
	if idx < 0 or depth > MAX_DEPTH:
		return
	var b: Dictionary = NifConverter._block_for_ref(nif, idx)
	if b.is_empty():
		return
	var t := str(b.get("type", ""))
	var accum: Transform3D = parent * (b.get("nif_transform", Transform3D.IDENTITY) as Transform3D)
	var here := inside or is_collision_node_name(str(b.get("name", "")))
	if t == "NiNode" or t == "NiBillboardNode" or t == "NiLODNode" or t == "NiSwitchNode":
		# Tous les enfants : la collision d'un aiguillage vit souvent dans son
		# DEUXIÈME enfant, que le rendu (kids[0]) ne parcourt jamais.
		for c in b.get("children", []):
			_walk(nif, int(c), accum, here, faces, seen, depth + 1)
	elif here and (t == "NiTriShape" or t == "NiTriStrips"):
		var block_index := int(b.get("index", idx))
		if seen.has(block_index):
			return
		seen[block_index] = true
		var data: Dictionary = NifConverter._data_block_for_ref(nif, int(b.get("data_ref", -1)))
		var verts: PackedVector3Array = data.get("vertices", PackedVector3Array())
		var indices: PackedInt32Array = data.get("indices", PackedInt32Array())
		var n := verts.size()
		for i in range(0, indices.size() - 2, 3):
			var a := indices[i]
			var bb := indices[i + 1]
			var c := indices[i + 2]
			if a >= n or bb >= n or c >= n:
				continue
			faces.append(NifCoordinateSystem.position(accum * verts[a]))
			faces.append(NifCoordinateSystem.position(accum * verts[bb]))
			faces.append(NifCoordinateSystem.position(accum * verts[c]))


static func clear_cache() -> void:
	_cache.clear()
