extends RefCounted
class_name DaocSpellVfxPlaceholder

## P1-76 — les effets de sort à l'écran.
##
## `spawn` pose d'abord le VRAI effet du client (DaocSpellEffectScenes : la
## géométrie texturée de `effects/*.nif`, 579 NIF sur 608 lisibles). Quand le
## NIF est illisible ou sans géométrie, le remplaçant `spawn_placeholder` pose
## des particules Godot :
##
##   - SUR LE BON NOEUD : `attach_node` de speffects.csv (« Bip01 R Held »,
##     « Bip01 Pelvis », « rootnode ») cherché comme os du squelette de la
##     scène, sinon à la racine de l'entité, à mi-hauteur ;
##   - POUR LA BONNE DURÉE : `duration_ms` de speffects.csv (0 = en continu
##     jusqu'au retrait, borné ici à 10 s) ;
##   - DE LA COULEUR DE SA FAMILLE, devinée dans le nom du NIF : froid, feu,
##     ténèbres, soin, terre/poison, foudre, sinon blanc.
##
## Tout ce qui est deviné est nommé dans les métadonnées du noeud
## (`daoc_vfx_placeholder = true`, `daoc_effect_nif`), pour qu'un contrôle de
## présence ne le prenne jamais pour l'effet d'origine.

const FAMILY_COLORS := {
	"cold": Color(0.55, 0.85, 1.0), "ice": Color(0.55, 0.85, 1.0), "frost": Color(0.7, 0.9, 1.0),
	"fire": Color(1.0, 0.45, 0.1), "flame": Color(1.0, 0.45, 0.1), "heat": Color(1.0, 0.55, 0.15), "burn": Color(1.0, 0.4, 0.1),
	"dark": Color(0.55, 0.2, 0.8), "shadow": Color(0.45, 0.15, 0.7), "necro": Color(0.4, 0.8, 0.3), "death": Color(0.35, 0.1, 0.5),
	"heal": Color(1.0, 0.9, 0.4), "holy": Color(1.0, 0.95, 0.6), "bless": Color(1.0, 0.9, 0.5), "regen": Color(0.6, 1.0, 0.6),
	"earth": Color(0.6, 0.45, 0.2), "acid": Color(0.5, 1.0, 0.2), "poison": Color(0.4, 0.9, 0.2), "disease": Color(0.6, 0.7, 0.2),
	"light": Color(1.0, 1.0, 0.7), "bolt": Color(1.0, 1.0, 0.5), "spirit": Color(0.7, 0.8, 1.0), "mind": Color(0.9, 0.5, 1.0),
	"resist": Color(0.9, 0.9, 0.9), "sparkle": Color(1.0, 1.0, 1.0),
}
const MAX_CONTINUOUS_SEC := 10.0


## P1-76 bis — le VRAI effet quand `scenes` (DaocSpellEffectScenes) sait lire
## son NIF : la géométrie texturée du client, posée sur le bon noeud pour la
## bonne durée. Sinon, le remplaçant en particules ci-dessous.
static func spawn(target: Node3D, effect: Dictionary, world_scale: float = 1.0, scenes: RefCounted = null) -> Node3D:
	if target == null or not is_instance_valid(target):
		return null
	if scenes != null and scenes.has_method("instantiate"):
		var real: Node3D = scenes.call("instantiate", str(effect.get("nif_path", ""))) as Node3D
		if real != null:
			return _mount_real(target, real, effect, world_scale)
	return spawn_placeholder(target, effect, world_scale)


static func _mount_real(target: Node3D, real: Node3D, effect: Dictionary, world_scale: float) -> Node3D:
	var duration_sec := float(effect.get("duration_ms", 0)) / 1000.0
	if duration_sec <= 0.0:
		duration_sec = MAX_CONTINUOUS_SEC
	var scale := maxf(0.05, float(effect.get("scale", 1.0)))
	real.name = "vfx_%s" % str(effect.get("nif_file", "effet")).validate_node_name()
	real.set_meta("daoc_vfx_placeholder", false)
	real.set_meta("daoc_vfx_real_nif", true)
	real.set_meta("daoc_effect_nif", str(effect.get("nif_file", "")))
	real.set_meta("daoc_effect_id", int(effect.get("effect_id", -1)))
	var parent := _attach_parent(target, str(effect.get("attach_node", "")))
	parent.add_child(real)
	var player := real.get_node_or_null("EffectAnimation") as AnimationPlayer
	if player != null and player.has_animation("effect"):
		player.play("effect")
	# Les NIF d'effet sont en unités DAoC, comme les props : le facteur visé est
	# `world_scale`. Sous un os, le squelette porte déjà l'échelle du modèle :
	# on la déduit pour ne pas la compter deux fois.
	var inherited := 1.0
	if parent.is_inside_tree():
		inherited = maxf(0.0001, parent.global_transform.basis.get_scale().x)
	real.scale = Vector3.ONE * (world_scale * scale / inherited)
	if parent == target:
		real.position = Vector3(0.0, _half_height(target), 0.0) if str(effect.get("attach_node", "")).to_lower() != "rootnode" else Vector3.ZERO
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration_sec
	timer.autostart = true
	timer.timeout.connect(func():
		if is_instance_valid(real):
			real.queue_free())
	real.add_child(timer)
	return real


static func spawn_placeholder(target: Node3D, effect: Dictionary, world_scale: float = 1.0) -> GPUParticles3D:
	var nif_file := str(effect.get("nif_file", "")).to_lower()
	var name := str(effect.get("name", "")).to_lower()
	var color := family_color(nif_file + " " + name)
	var duration_sec := float(effect.get("duration_ms", 0)) / 1000.0
	var continuous := duration_sec <= 0.0
	if continuous:
		duration_sec = MAX_CONTINUOUS_SEC
	var scale := maxf(0.05, float(effect.get("scale", 1.0)))

	var particles := GPUParticles3D.new()
	particles.name = "vfx_%s" % nif_file.get_basename().validate_node_name()
	particles.set_meta("daoc_vfx_placeholder", true)
	particles.set_meta("daoc_effect_nif", str(effect.get("nif_file", "")))
	particles.set_meta("daoc_effect_id", int(effect.get("effect_id", -1)))
	particles.amount = 48 if continuous else 96
	particles.lifetime = 0.9
	particles.one_shot = not continuous
	particles.explosiveness = 0.0 if continuous else 0.6
	particles.local_coords = true
	particles.emitting = true

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 60.0
	material.initial_velocity_min = 20.0 * world_scale
	material.initial_velocity_max = 60.0 * world_scale
	material.gravity = Vector3(0.0, -10.0 * world_scale, 0.0)
	material.scale_min = 4.0 * world_scale * scale
	material.scale_max = 9.0 * world_scale * scale
	material.color = color
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0 * world_scale * scale
	particles.process_material = material

	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var quad_material := StandardMaterial3D.new()
	quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_material.vertex_color_use_as_albedo = true
	quad_material.albedo_color = Color(color, 0.85)
	quad_material.emission_enabled = true
	quad_material.emission = color
	quad_material.emission_energy_multiplier = 2.0
	mesh.material = quad_material
	particles.draw_pass_1 = mesh

	var parent := _attach_parent(target, str(effect.get("attach_node", "")))
	parent.add_child(particles)
	if parent == target:
		# Pas d'os nommé : à mi-hauteur de l'entité, comme le ferait « rootnode »
		# sur un corps sans squelette.
		particles.position = Vector3(0.0, _half_height(target), 0.0)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration_sec + particles.lifetime
	timer.autostart = true
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free())
	particles.add_child(timer)
	return particles


static func family_color(text: String) -> Color:
	for key in FAMILY_COLORS:
		if text.find(str(key)) != -1:
			return FAMILY_COLORS[key] as Color
	return Color(1.0, 1.0, 1.0)


## Le noeud sous lequel poser l'effet : un BoneAttachment3D sur l'os nommé
## par speffects.csv quand la scène a ce squelette, sinon l'entité elle-même.
static func _attach_parent(target: Node3D, attach_node: String) -> Node3D:
	var bone := attach_node.strip_edges()
	if bone == "" or bone.to_lower() == "rootnode":
		return target
	var skeleton := _find_skeleton(target)
	if skeleton == null:
		return target
	var bone_index := skeleton.find_bone(bone)
	if bone_index < 0:
		return target
	var existing := skeleton.get_node_or_null("vfx_attach_%s" % bone.validate_node_name())
	if existing is BoneAttachment3D:
		return existing as Node3D
	var attachment := BoneAttachment3D.new()
	attachment.name = "vfx_attach_%s" % bone.validate_node_name()
	attachment.bone_name = bone
	attachment.bone_idx = bone_index
	skeleton.add_child(attachment)
	return attachment


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


static func _half_height(target: Node3D) -> float:
	var best := 0.0
	for child in target.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb := mi.get_aabb()
		best = maxf(best, aabb.position.y + aabb.size.y)
	return best * 0.5
