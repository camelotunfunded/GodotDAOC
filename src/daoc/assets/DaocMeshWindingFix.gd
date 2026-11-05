extends RefCounted
class_name DaocMeshWindingFix

## LES DECORS DAOC ETAIENT ECLAIRES PAR L'ARRIERE.
##
## Les maillages convertis depuis les NIF arrivent avec des triangles enroules
## dans le sens TRIGONOMETRIQUE vus de leur face visible. Godot dessine ses faces
## avant dans le sens HORAIRE : ces faces sont donc des faces ARRIERE pour lui.
## Le convertisseur a contourne le probleme en posant `cull_mode = DISABLED`
## sur 1197 materiaux de la zone 51, ce qui rend la geometrie visible... mais
## sur une face arriere Godot RETOURNE la normale avant d'eclairer. Le plancher
## du ponton, les murs des maisons, les toits : tout etait eclaire comme s'il
## regardait l'interieur, donc SANS soleil direct et SANS ombre portee recue.
## Seule l'ambiance les eclairait — c'est le « monde plat » signale le
## 2026-09-18 (P1-90), mesure en retournant l'enroulement a chaud dans
## `DaocGame` : le ponton passe de l'ombre uniforme a un plancher ensoleille
## qui recoit l'ombre de ses propres poteaux.
##
## Ce correctif retourne l'enroulement des SEULES surfaces dont le materiau est
## en `CULL_DISABLED` : celles qui s'affichent deja correctement (cull arriere,
## 1418 materiaux de la population) ne sont pas touchees, puisqu'elles n'ont pu
## etre visibles qu'en etant deja dans le bon sens. Les normales stockees ne
## sont PAS modifiees : elles etaient justes, c'est le sens des faces qui ne
## l'etait pas. Le maillage est corrige EN PLACE et marque, donc partage par
## toutes les instances et jamais retourne deux fois.
##
## La bonne correction vit dans le convertisseur du Lab ; celle-ci protege le
## client de toute scene deja convertie, y compris celles qu'on n'a pas encore
## regenerees.

const META_KEY := "daoc_winding_fixed_p1_90"


## Parcourt `root` et corrige chaque `MeshInstance3D` dont le maillage est un
## `ArrayMesh`. Rend des comptes pour les suites et les journaux.
## P1-129 : `rendered_material_first` = decider sur le materiau REELLEMENT rendu
## (surcharge d instance). Reserve aux NIF d objets equipes (casques albHelm01…,
## maillage cull arriere + surcharge cull_disabled : sinon NOIRS). Jamais pour le
## decor : l essai global a blanchi et desassemble les batiments.
static func apply(root: Node, rendered_material_first: bool = false) -> Dictionary:
	var stats := {"meshes_seen": 0, "meshes_fixed": 0, "surfaces_flipped": 0,
		"surfaces_kept": 0, "non_indexed_skipped": 0}
	if root == null:
		return stats
	stats["rendered_material_first"] = rendered_material_first
	_walk(root, stats)
	return stats


static func _walk(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		_fix_instance(node as MeshInstance3D, stats, bool(stats.get("rendered_material_first", false)))
	for child in node.get_children():
		_walk(child, stats)


static func _fix_instance(instance: MeshInstance3D, stats: Dictionary, rendered_first: bool = false) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	stats["meshes_seen"] = int(stats["meshes_seen"]) + 1
	if mesh.has_meta(META_KEY):
		return
	# Decision par surface : le materiau du maillage d'abord, puis celui que
	# l'instance pose par-dessus, car les scenes du Lab portent l'un ou l'autre.
	var surfaces := []
	var any_flip := false
	for i in range(mesh.get_surface_count()):
		var material: Material = instance.get_active_material(i) if rendered_first else mesh.surface_get_material(i)
		if material == null:
			material = instance.get_active_material(i)
		var flip := _is_cull_disabled(material)
		var arrays := mesh.surface_get_arrays(i)
		if flip:
			if arrays[Mesh.ARRAY_INDEX] == null:
				# Sans index, retourner demande de reordonner toutes les
				# colonnes de sommets : compte, pas fait, pour rester sur.
				flip = false
				stats["non_indexed_skipped"] = int(stats["non_indexed_skipped"]) + 1
			else:
				arrays[Mesh.ARRAY_INDEX] = _reverse_winding(arrays[Mesh.ARRAY_INDEX])
				any_flip = true
				stats["surfaces_flipped"] = int(stats["surfaces_flipped"]) + 1
		if not flip:
			stats["surfaces_kept"] = int(stats["surfaces_kept"]) + 1
		surfaces.append({
			"primitive": mesh.surface_get_primitive_type(i),
			"arrays": arrays,
			"blend_shapes": mesh.surface_get_blend_shape_arrays(i),
			"format": mesh.surface_get_format(i),
			"material": mesh.surface_get_material(i),
			"name": mesh.surface_get_name(i),
		})
	mesh.set_meta(META_KEY, true)
	if not any_flip:
		return
	# Reconstruction en place : un ArrayMesh ne sait pas remplacer les index
	# d'une surface existante. Les formes de melange (blend shapes) sont
	# reposees telles quelles, le format aussi, pour ne pas perdre les os.
	var blend_names: Array[String] = []
	for b in range(mesh.get_blend_shape_count()):
		blend_names.append(mesh.get_blend_shape_name(b))
	var blend_mode := mesh.blend_shape_mode
	mesh.clear_surfaces()
	mesh.clear_blend_shapes()
	for blend_name in blend_names:
		mesh.add_blend_shape(blend_name)
	mesh.blend_shape_mode = blend_mode
	for surface in surfaces:
		mesh.add_surface_from_arrays(int(surface["primitive"]), surface["arrays"] as Array,
			surface["blend_shapes"] as Array, {}, int(surface["format"]))
		var idx := mesh.get_surface_count() - 1
		if surface["material"] != null:
			mesh.surface_set_material(idx, surface["material"] as Material)
		mesh.surface_set_name(idx, str(surface["name"]))
	stats["meshes_fixed"] = int(stats["meshes_fixed"]) + 1


static func _is_cull_disabled(material: Material) -> bool:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	return false


static func _reverse_winding(indices: PackedInt32Array) -> PackedInt32Array:
	var flipped := PackedInt32Array()
	flipped.resize(indices.size())
	for i in range(0, indices.size() - 2, 3):
		flipped[i] = indices[i]
		flipped[i + 1] = indices[i + 2]
		flipped[i + 2] = indices[i + 1]
	return flipped
