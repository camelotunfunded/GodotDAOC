extends RefCounted
class_name DaocSpellEffectScenes

## P1-76 — les VRAIS effets de sort du client, lus dans `effects/*.nif`.
##
## Ces NIF (version 4.2.1) sont lisibles par `nif_reader.gd` : bouclier
## d'Améthyste (`alb_eshield1_hit` : sphère + pointes texturées `amethmap.tga`,
## `prpspike.tga`), sphères de Midgard, gerbes… 579 des 608 NIF cités par
## `speffects.csv` se lisent et rendent une géométrie (sonde P1-76). Les 29
## autres sont des exports Gamebryo 10 ou des variantes de données de
## particules non alignées : ils retombent sur `DaocSpellVfxPlaceholder`.
##
## P1-76 ter — la HIÉRARCHIE est conservée et les CONTRÔLEURS sont rejoués :
## un Node3D par NiNode, un MeshInstance3D par forme, et un AnimationPlayer
## bâti depuis les clés que le lecteur conserve désormais :
##
##   NiKeyframeController  -> pistes position / rotation / échelle du noeud
##                            (quaternions et translations converties NIF->Godot
##                            par NifCoordinateSystem, jamais à la main) ;
##   NiVisController       -> piste `visible` (discrète) ;
##   NiAlphaController     -> piste alpha des surfaces qui portent ce
##                            NiMaterialProperty.
##
## Non rejoués, et nommés : rotations Euler XYZ (type 4, rares), NiUVController,
## NiMaterialColorController, NiGeomMorpherController. Les émetteurs de
## particules (NiRotatingParticles) restent les quads statiques du convertisseur.
##
## Les textures sont cherchées dans `effects/` (png, tga, dds), jamais copiées.

const NifReaderScript = preload("res://src/nif/nif_reader.gd")
const NifConverterScript = preload("res://src/nif/nif_converter.gd")

const NODE_TYPES := ["NiNode", "NiBillboardNode", "NiLODNode", "NiSwitchNode"]
const SHAPE_TYPES := ["NiTriShape", "NiTriStrips", "NiParticles", "NiAutoNormalParticles",
	"NiRotatingParticles", "NiParticleSystem", "NiParticleMeshes"]
## Bits 1-2 de `ctrl_flags` : 0 boucle, 1 aller-retour, 2 arrêt sur la dernière clé.
const CYCLE_LOOP := 0
const CYCLE_CLAMP := 2

var client_root := ""
var _templates: Dictionary = {}
var _textures: Dictionary = {}
var _failures: Dictionary = {}
var _reports: Dictionary = {}


func setup(root: String) -> void:
	client_root = root


## Un template (Node3D) pour ce NIF, ou null si illisible / sans géométrie.
## Mis en cache : chaque instance est un `duplicate()` du template.
func template_for(nif_path: String) -> Node3D:
	if nif_path == "":
		return null
	if _templates.has(nif_path):
		return _templates[nif_path] as Node3D
	if _failures.has(nif_path):
		return null
	var reader = NifReaderScript.new()
	if not reader.read(nif_path) or bool(reader.get("failed")):
		_failures[nif_path] = "nif illisible"
		return null
	var node := _build_hierarchy(reader, nif_path.get_file().get_basename())
	if node == null or node.find_children("*", "MeshInstance3D", true, false).is_empty():
		_failures[nif_path] = "aucune géométrie"
		if node != null:
			node.free()
		return null
	_templates[nif_path] = node
	return node


func instantiate(nif_path: String) -> Node3D:
	var template := template_for(nif_path)
	if template == null:
		return null
	var copy := template.duplicate() as Node3D
	# Les pistes alpha écrivent dans le matériau : chaque instance a le sien.
	for child in copy.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for si in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(si)
			if mat != null:
				mi.set_surface_override_material(si, mat.duplicate())
	var player := copy.get_node_or_null("EffectAnimation") as AnimationPlayer
	if player != null and player.has_animation("effect"):
		player.play("effect")
	return copy


func failure_reason(nif_path: String) -> String:
	return str(_failures.get(nif_path, ""))


func report() -> Dictionary:
	return {"templates": _templates.size(), "failures": _failures.duplicate(),
		"textures": _textures.size(), "animation": _reports.duplicate(true)}


func animation_report(nif_path: String) -> Dictionary:
	return (_reports.get(nif_path.get_file().get_basename(), {}) as Dictionary).duplicate(true)


# --------------------------------------------------------------------------
# Hiérarchie
# --------------------------------------------------------------------------

func _build_hierarchy(nif, model_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = model_name
	var ctx := {"nodes": {}, "shapes_by_material": {}, "controllers": [], "nif": nif}
	var roots: Array = nif.roots if nif.roots.size() > 0 else ([0] if nif.blocks.size() > 0 else [])
	for ri in roots:
		_build_node(nif, int(ri), root, ctx)
	_build_animation(root, ctx, model_name)
	return root


func _build_node(nif, idx: int, parent: Node3D, ctx: Dictionary, env_texture: String = "") -> void:
	if idx < 0:
		return
	var block: Dictionary = NifConverterScript._block_for_ref(nif, idx)
	if block.is_empty():
		return
	var type := str(block.get("type", ""))
	var is_node := NODE_TYPES.has(type)
	var is_shape := SHAPE_TYPES.has(type)
	if not is_node and not is_shape:
		return
	# NiTextureEffect porté par un NiNode : carte d'environnement héritée par
	# toute sa descendance (bouclier d'Améthyste : `amethmap.tga` sur « shield »).
	for effect_ref in block.get("effect_refs", []) as Array:
		var fx: Dictionary = NifConverterScript._block_for_ref(nif, int(effect_ref))
		if str(fx.get("type", "")) == "NiTextureEffect":
			var src: Dictionary = NifConverterScript._source_texture_block_for_ref(nif, int(fx.get("source_texture_ref", -1)))
			if str(src.get("file_name", "")) != "":
				env_texture = str(src.get("file_name", ""))
	var node: Node3D
	if is_shape:
		var mesh := ArrayMesh.new()
		NifConverterScript._add_surface(nif, mesh, block, Transform3D.IDENTITY, false)
		if mesh.get_surface_count() == 0:
			return
		# P1-89 — NiGeomMorpherController : cibles de morphing en formes de melange.
		var morph := _morph_data_for(nif, block)
		if not morph.is_empty():
			mesh = _mesh_with_blend_shapes(mesh, morph)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_shape_materials(nif, block, mi, env_texture)
		node = mi
		for prop_ref in block.get("property_refs", []) as Array:
			var list: Array = ctx["shapes_by_material"].get(int(prop_ref), [])
			list.append(mi)
			ctx["shapes_by_material"][int(prop_ref)] = list
			# Les controleurs d'une PROPRIETE (NiAlphaController sur un
			# NiMaterialProperty) pendent de la propriete, pas de la forme.
			var prop: Dictionary = NifConverterScript._block_for_ref(nif, int(prop_ref))
			if not prop.is_empty() and not (ctx.get("seen_props", {}) as Dictionary).has(int(prop_ref)):
				if not ctx.has("seen_props"):
					ctx["seen_props"] = {}
				ctx["seen_props"][int(prop_ref)] = true
				_collect_controllers(nif, prop, mi, ctx)
	else:
		node = Node3D.new()
	var raw_name := str(block.get("name", "")).strip_edges()
	node.name = (raw_name if raw_name != "" else "%s_%d" % [type, idx]).validate_node_name()
	node.transform = _convert_transform(block.get("nif_transform", Transform3D.IDENTITY) as Transform3D)
	# Bit 0 des drapeaux NiAVObject : caché. Un NiVisController le rallumera.
	node.visible = (int(block.get("flags", 0)) & 1) == 0
	parent.add_child(node)
	ctx["nodes"][idx] = node
	_collect_controllers(nif, block, node, ctx)
	if is_node:
		for child_ref in block.get("children", []) as Array:
			_build_node(nif, int(child_ref), node, ctx, env_texture)


func _collect_controllers(nif, block: Dictionary, node: Node3D, ctx: Dictionary) -> void:
	var ref := int(block.get("controller_ref", -1))
	var guard := 0
	while ref >= 0 and guard < 16:
		guard += 1
		var ctrl: Dictionary = NifConverterScript._block_for_ref(nif, ref)
		if ctrl.is_empty():
			break
		(ctx["controllers"] as Array).append({"block": ctrl, "node": node, "owner_index": int(block.get("index", -1))})
		ref = int(ctrl.get("next_controller_ref", -1))


## NIF -> Godot par la matrice de changement de base S : T' = S T S^-1.
static func _convert_transform(t: Transform3D) -> Transform3D:
	var s: Basis = NifCoordinateSystem.S
	return Transform3D(s * t.basis * s.inverse(), s * t.origin)


static func _convert_quaternion(q: Quaternion) -> Quaternion:
	var s: Basis = NifCoordinateSystem.S
	return (s * Basis(q.normalized()) * s.inverse()).get_rotation_quaternion()


# --------------------------------------------------------------------------
# Animation
# --------------------------------------------------------------------------

func _build_animation(root: Node3D, ctx: Dictionary, model_name: String) -> void:
	var controllers: Array = ctx["controllers"]
	var report := {"keyframe": 0, "vis": 0, "alpha": 0, "skipped": {}, "tracks": 0, "length": 0.0, "loop": false}
	if controllers.is_empty():
		_reports[model_name] = report
		return
	var animation := Animation.new()
	var length := 0.0
	var any_loop := false
	var nif = ctx["nif"]
	for entry_value in controllers:
		var entry: Dictionary = entry_value
		var ctrl: Dictionary = entry["block"]
		var node: Node3D = entry["node"]
		var type := str(ctrl.get("type", ""))
		var stop := float(ctrl.get("stop_time", 0.0))
		var cycle := (int(ctrl.get("ctrl_flags", 0)) >> 1) & 0x3
		var data: Dictionary = NifConverterScript._block_for_ref(nif, int(ctrl.get("data_ref", -1)))
		var added := 0
		match type:
			"NiKeyframeController":
				added = _add_keyframe_tracks(animation, root, node, data)
				if added > 0:
					report["keyframe"] += 1
			"NiVisController":
				added = _add_vis_track(animation, root, node, data)
				if added > 0:
					report["vis"] += 1
			"NiAlphaController":
				# La cible est un NiMaterialProperty : toutes les formes qui le
				# portent reçoivent la piste.
				var target := int(ctrl.get("target_ref", -1))
				var shapes: Array = ctx["shapes_by_material"].get(target, [])
				if shapes.is_empty():
					shapes = ctx["shapes_by_material"].get(int(entry.get("owner_index", -1)), [])
				added = _add_alpha_tracks(animation, root, shapes, data)
				if added > 0:
					report["alpha"] += 1
			"NiGeomMorpherController":
				added = _add_morph_tracks(animation, root, node, data)
				if added > 0:
					report["morph"] = int(report.get("morph", 0)) + 1
			_:
				report["skipped"][type] = int(report["skipped"].get(type, 0)) + 1
		if added > 0:
			length = maxf(length, stop)
			if cycle == CYCLE_LOOP:
				any_loop = true
	report["tracks"] = animation.get_track_count()
	if animation.get_track_count() == 0:
		_reports[model_name] = report
		return
	if length <= 0.0:
		length = _max_key_time(animation)
	animation.length = maxf(length, 0.05)
	animation.loop_mode = Animation.LOOP_LINEAR if any_loop else Animation.LOOP_NONE
	report["length"] = animation.length
	report["loop"] = any_loop
	var library := AnimationLibrary.new()
	library.add_animation("effect", animation)
	var player := AnimationPlayer.new()
	player.name = "EffectAnimation"
	root.add_child(player)
	player.add_animation_library("", library)
	_reports[model_name] = report


## P1-89 — la donnee de morphing d'une forme, par son NiGeomMorpherController.
func _morph_data_for(nif, block: Dictionary) -> Dictionary:
	var ref := int(block.get("controller_ref", -1))
	var guard := 0
	while ref >= 0 and guard < 16:
		guard += 1
		var ctrl: Dictionary = NifConverterScript._block_for_ref(nif, ref)
		if ctrl.is_empty():
			break
		if str(ctrl.get("type", "")) == "NiGeomMorpherController":
			var data: Dictionary = NifConverterScript._block_for_ref(nif, int(ctrl.get("data_ref", -1)))
			if (data.get("morphs", []) as Array).size() >= 2:
				return data
		ref = int(ctrl.get("next_controller_ref", -1))
	return {}


## Le maillage rebati avec une forme de melange par cible (la cible 0 est la
## base). Cibles RELATIVES (deltas) -> mode RELATIVE ; absolues -> NORMALIZED.
## Les sommets suivent l'ordre du NIF, comme `_add_surface` (1 pour 1).
func _mesh_with_blend_shapes(source: ArrayMesh, morph: Dictionary) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var morphs: Array = morph.get("morphs", [])
	var relative := bool(morph.get("relative", false))
	var origin := NifCoordinateSystem.position(Vector3.ZERO)
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE if relative else Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var shapes: Array = []
	for i in range(1, morphs.size()):
		var target: PackedVector3Array = (morphs[i] as Dictionary).get("vertices", PackedVector3Array())
		if target.size() != base.size():
			continue
		var verts := PackedVector3Array()
		verts.resize(base.size())
		for v in base.size():
			verts[v] = (NifCoordinateSystem.position(target[v]) - origin) if relative else NifCoordinateSystem.position(target[v])
		var shape: Array = []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		mesh.add_blend_shape("morph_%d" % i)
		shapes.append(shape)
	if shapes.is_empty():
		return source
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	var material := source.surface_get_material(0)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh


static func _has_blend_shape(mesh: Mesh, name: String) -> bool:
	for i in mesh.get_blend_shape_count():
		if str(mesh.get_blend_shape_name(i)) == name:
			return true
	return false

## Une piste par cible dotee de cles : `blend_shapes/morph_i` de la forme.
func _add_morph_tracks(animation: Animation, root: Node3D, node: Node3D, data: Dictionary) -> int:
	var mi := node as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_blend_shape_count() == 0:
		return 0
	var morphs: Array = data.get("morphs", [])
	var added := 0
	for i in range(1, morphs.size()):
		var keys: Array = (morphs[i] as Dictionary).get("keys", [])
		if keys.is_empty() or not _has_blend_shape(mi.mesh, "morph_%d" % i):
			continue
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, "%s:blend_shapes/morph_%d" % [root.get_path_to(mi), i])
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for key in keys:
			animation.track_insert_key(track, float((key as Dictionary).get("time", 0.0)), float((key as Dictionary).get("value", 0.0)))
		added += 1
	return added

func _add_keyframe_tracks(animation: Animation, root: Node3D, node: Node3D, data: Dictionary) -> int:
	if data.is_empty():
		return 0
	var path := root.get_path_to(node)
	var added := 0
	var rot_keys: Array = data.get("rot_keys", [])
	if not rot_keys.is_empty() and int(data.get("rot_type", 1)) != 4:
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		for key in rot_keys:
			var q: Variant = (key as Dictionary).get("value")
			if q is Quaternion:
				animation.rotation_track_insert_key(track, float((key as Dictionary).get("time", 0.0)), _convert_quaternion(q))
		added += 1
	var trans_keys: Array = data.get("trans_keys", [])
	if not trans_keys.is_empty():
		var track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track, path)
		for key in trans_keys:
			var v: Variant = (key as Dictionary).get("value")
			if v is Vector3:
				animation.position_track_insert_key(track, float((key as Dictionary).get("time", 0.0)), NifCoordinateSystem.position(v))
		added += 1
	var scale_keys: Array = data.get("scale_keys", [])
	if not scale_keys.is_empty():
		var track := animation.add_track(Animation.TYPE_SCALE_3D)
		animation.track_set_path(track, path)
		for key in scale_keys:
			var f := float((key as Dictionary).get("value", 1.0))
			animation.scale_track_insert_key(track, float((key as Dictionary).get("time", 0.0)), Vector3.ONE * f)
		added += 1
	return added


func _add_vis_track(animation: Animation, root: Node3D, node: Node3D, data: Dictionary) -> int:
	var keys: Array = data.get("vis_keys", [])
	if keys.is_empty():
		return 0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, str(root.get_path_to(node)) + ":visible")
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for key in keys:
		animation.track_insert_key(track, float((key as Dictionary).get("time", 0.0)), bool((key as Dictionary).get("visible", true)))
	return 1


func _add_alpha_tracks(animation: Animation, root: Node3D, shapes: Array, data: Dictionary) -> int:
	var keys: Array = data.get("keys", [])
	if keys.is_empty() or shapes.is_empty():
		return 0
	var added := 0
	for shape_value in shapes:
		var mi := shape_value as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var track := animation.add_track(Animation.TYPE_VALUE)
			var is_shader := mi.get_surface_override_material(si) is ShaderMaterial
			if is_shader:
				# Le controleur REMPLACE l'alpha du materiau (souvent 0 a t=0) :
				# l'albedo garde sa couleur, l'alpha vient de la piste.
				var sm := mi.get_surface_override_material(si) as ShaderMaterial
				var c: Color = sm.get_shader_parameter("albedo")
				sm.set_shader_parameter("albedo", Color(c.r, c.g, c.b, 1.0))
			animation.track_set_path(track, "%s:surface_material_override/%d:%s" % [root.get_path_to(mi), si,
				"shader_parameter/alpha" if is_shader else "albedo_color"])
			animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
			for key in keys:
				var a := clampf(float((key as Dictionary).get("value", 1.0)), 0.0, 1.0)
				animation.track_insert_key(track, float((key as Dictionary).get("time", 0.0)), a if is_shader else Color(1.0, 1.0, 1.0, a))
			added += 1
	return added


static func _max_key_time(animation: Animation) -> float:
	var best := 0.0
	for t in animation.get_track_count():
		var n := animation.track_get_key_count(t)
		if n > 0:
			best = maxf(best, animation.track_get_key_time(t, n - 1))
	return best


# --------------------------------------------------------------------------
# Matériaux et textures
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Matériaux : ce que le NIF déclare, pas un aplat
# --------------------------------------------------------------------------

## Un effet n'est pas un décor : non éclairé, deux faces, sans écriture de
## profondeur. Tout le reste vient des propriétés de la forme :
##   NiMaterialProperty  -> couleur (diffuse, ou émissive si plus claire) et alpha ;
##   NiAlphaProperty     -> fusion : bit 0 = mélange actif, bits 5-8 = facteur de
##                          destination (0 ONE -> additif, sinon alpha) ;
##   NiTexturingProperty -> texture de base ;
##   NiTextureEffect     -> carte d'environnement héritée, plaquée en sphère sur
##                          la normale vue (ce que fait le client d'origine).
## Les surfaces de particules gardent un StandardMaterial3D en panneau.
const SHADER_SOURCE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, %s;
uniform sampler2D base_tex : source_color, filter_linear_mipmap;
uniform sampler2D env_tex : source_color, filter_linear_mipmap;
uniform bool has_base = false;
uniform bool has_env = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float alpha = 1.0;
void fragment() {
	vec4 c = albedo * COLOR;
	if (has_base) {
		c *= texture(base_tex, UV);
	}
	if (has_env) {
		vec3 n = normalize(NORMAL);
		c.rgb += texture(env_tex, n.xy * 0.5 + 0.5).rgb * albedo.rgb;
	}
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a * alpha, 0.0, 1.0);
}
"""
var _shaders: Dictionary = {}


func _shader(additive: bool) -> Shader:
	var key := "add" if additive else "mix"
	if _shaders.has(key):
		return _shaders[key] as Shader
	var shader := Shader.new()
	shader.code = SHADER_SOURCE % ("blend_add" if additive else "blend_mix")
	_shaders[key] = shader
	return shader


func _apply_shape_materials(nif, block: Dictionary, mi: MeshInstance3D, env_texture: String) -> void:
	var color := Color(1, 1, 1, 1)
	var material_alpha := 1.0
	var additive := false
	var blending := false
	var base_name := ""
	for prop_ref in block.get("property_refs", []) as Array:
		var p: Dictionary = NifConverterScript._block_for_ref(nif, int(prop_ref))
		match str(p.get("type", "")):
			"NiMaterialProperty":
				var diffuse: Color = p.get("diffuse", Color.WHITE)
				var emissive: Color = p.get("emissive", Color.BLACK)
				color = diffuse if diffuse.get_luminance() >= emissive.get_luminance() else emissive
				material_alpha = clampf(float(p.get("alpha", 1.0)), 0.0, 1.0)
			"NiAlphaProperty":
				var flags := int(p.get("flags", 0))
				blending = (flags & 1) != 0
				additive = blending and ((flags >> 5) & 0xF) == 0
			"NiTexturingProperty":
				var src: Dictionary = NifConverterScript._source_texture_block_for_ref(nif, int(p.get("base_source_ref", -1)))
				base_name = str(src.get("file_name", ""))
			"NiSourceTexture":
				base_name = str(p.get("file_name", ""))
	for si in mi.mesh.get_surface_count():
		var src_mat := mi.mesh.surface_get_material(si)
		if src_mat != null and src_mat.has_meta("daoc_particle_surface"):
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			pm.vertex_color_use_as_albedo = true
			pm.albedo_color = Color(color, material_alpha)
			var ptex := _texture(base_name if base_name != "" else str(src_mat.resource_name))
			if ptex != null:
				pm.albedo_texture = ptex
			mi.set_surface_override_material(si, pm)
			continue
		var sm := ShaderMaterial.new()
		sm.shader = _shader(additive)
		sm.resource_name = base_name
		sm.set_shader_parameter("albedo", Color(color.r, color.g, color.b, material_alpha if blending else 1.0))
		sm.set_shader_parameter("alpha", 1.0)
		var base := _texture(base_name)
		sm.set_shader_parameter("has_base", base != null)
		if base != null:
			sm.set_shader_parameter("base_tex", base)
		var env := _texture(env_texture)
		sm.set_shader_parameter("has_env", env != null)
		if env != null:
			sm.set_shader_parameter("env_tex", env)
		mi.set_surface_override_material(si, sm)


func _texture(name: String) -> Texture2D:
	var stem := name.get_basename().to_lower()
	if stem == "":
		return null
	if _textures.has(stem):
		return _textures[stem] as Texture2D
	var dir := client_root.path_join("effects")
	var tex: Texture2D = null
	for ext in ["png", "tga", "PNG", "TGA", "dds", "DDS"]:
		var path := dir.path_join(stem + "." + ext)
		if not FileAccess.file_exists(path):
			path = dir.path_join(name.get_basename() + "." + ext)
			if not FileAccess.file_exists(path):
				continue
		var image := Image.new()
		if image.load(path) != OK:
			continue
		image.generate_mipmaps()
		tex = ImageTexture.create_from_image(image)
		break
	_textures[stem] = tex
	return tex
