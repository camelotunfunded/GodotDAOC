extends RefCounted
class_name DaocMeleeHitVfx

## P1-133 — LES VFX DES COUPS PHYSIQUES, pendant des VFX de sorts.
##
## Le client d'origine n'a pas de NIF d'impact par style : `styles.csv`
## « Hit Effect » vaut 0 sur 584 lignes sur 585. Ce qu'il porte, c'est une
## COULEUR par style (Red/Green/Blue). On en fait :
##   - une TRAÎNÉE sur l'arme de l'attaquant (os `Bip01 R Held`), particules en
##     coordonnées monde : le geste laisse un sillage, teinté pour un style ;
##   - un IMPACT sur le défenseur selon le résultat du 0xBC :
##       coup      -> gerbe d'étincelles + éclat bref (plus gros et teinté si stylé),
##       paré/bloqué -> étincelles métalliques jaune-blanc, sans éclat rouge,
##       esquivé   -> bouffée de poussière aux pieds,
##       raté / maladresse -> rien.
## Tout est un one-shot GPUParticles3D libéré par minuterie : coût borné,
## aucune allocation persistante. Comme le placeholder magique, chaque noeud
## porte `daoc_vfx_placeholder = true`.

const SpellVfx = preload("res://src/daoc/gameplay/effects/DaocSpellVfxPlaceholder.gd")

const HIT_COLOR := Color(1.0, 0.82, 0.55)
const METAL_COLOR := Color(1.0, 0.95, 0.7)
const DUST_COLOR := Color(0.72, 0.66, 0.55)


## `result` : chaîne de DaocOpenDaocAnimationCodec.COMBAT_RESULTS.
static func spawn_impact(defender: Node3D, attacker: Node3D, result: String, style_color: Variant, world_scale: float) -> Node3D:
	if defender == null or not is_instance_valid(defender):
		return null
	var styled := style_color is Color
	match result:
		"HitUnstyled", "HitStyle":
			var c: Color = style_color if styled else HIT_COLOR
			var n := _burst(defender, attacker, c, 60 if styled else 28, 0.45, 45.0, world_scale * (1.4 if styled else 1.0), true)
			if styled:
				_burst(defender, attacker, c.lightened(0.4), 1, 0.22, 0.0, world_scale * 5.0, false)
			return n
		"Parried", "Blocked":
			return _burst(defender, attacker, METAL_COLOR, 40, 0.35, 70.0, world_scale * 0.8, true)
		"Evaded":
			return _dust(defender, world_scale)
	return null


## Sillage de l'arme pendant `duration_sec`.
static func spawn_trail(attacker: Node3D, style_color: Variant, duration_sec: float, world_scale: float) -> Node3D:
	if attacker == null or not is_instance_valid(attacker):
		return null
	var parent := SpellVfx._attach_parent(attacker, "Bip01 R Held")
	if parent == attacker:
		return null # sans squelette, pas de sillage crédible
	var c: Color = style_color if style_color is Color else Color(0.9, 0.9, 1.0)
	var p := GPUParticles3D.new()
	p.name = "vfx_melee_trail"
	p.set_meta("daoc_vfx_placeholder", true)
	p.amount = 48 if style_color is Color else 24
	p.lifetime = 0.28
	p.local_coords = false
	p.one_shot = false
	p.emitting = true
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.0
	m.scale_min = 5.0 * world_scale
	m.scale_max = 8.0 * world_scale
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Le long de la lame : l'os Held est à la poignée.
	m.emission_box_extents = Vector3(2.0, 2.0, 30.0) * world_scale
	var ramp := Gradient.new()
	ramp.set_color(0, Color(c, 0.55))
	ramp.set_color(1, Color(c, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	p.process_material = m
	p.draw_pass_1 = _quad(c, 1.6)
	parent.add_child(p)
	_free_after(p, maxf(0.15, duration_sec), p.lifetime)
	return p


static func _burst(defender: Node3D, attacker: Node3D, color: Color, amount: int, lifetime: float, spread: float, scale: float, sparks: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "vfx_melee_hit"
	p.set_meta("daoc_vfx_placeholder", true)
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = true
	p.emitting = true
	var m := ParticleProcessMaterial.new()
	var dir := Vector3.UP
	if attacker != null and is_instance_valid(attacker) and attacker.is_inside_tree() and defender.is_inside_tree():
		var d := attacker.global_position - defender.global_position
		d.y = 0.0
		if d.length_squared() > 0.0001:
			dir = (defender.global_transform.basis.inverse() * d.normalized() + Vector3.UP * 0.35).normalized()
	m.direction = dir
	m.spread = spread
	if sparks:
		m.initial_velocity_min = 60.0 * scale
		m.initial_velocity_max = 160.0 * scale
		m.gravity = Vector3(0.0, -260.0 * scale, 0.0)
		m.scale_min = 1.2 * scale
		m.scale_max = 2.6 * scale
		m.damping_min = 40.0 * scale
		m.damping_max = 90.0 * scale
	else:
		m.initial_velocity_min = 0.0
		m.initial_velocity_max = 0.0
		m.gravity = Vector3.ZERO
		m.scale_min = 6.0 * scale
		m.scale_max = 6.0 * scale
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.3), 1.0))
	ramp.set_color(1, Color(color, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	p.process_material = m
	p.draw_pass_1 = _quad(color, 3.0)
	defender.add_child(p)
	p.position = Vector3(0.0, SpellVfx._half_height(defender) * 1.2, 0.0)
	_free_after(p, lifetime, 0.1)
	return p


static func _dust(defender: Node3D, world_scale: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "vfx_melee_evade"
	p.set_meta("daoc_vfx_placeholder", true)
	p.amount = 16
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 80.0
	m.initial_velocity_min = 10.0 * world_scale
	m.initial_velocity_max = 30.0 * world_scale
	m.gravity = Vector3(0.0, -5.0 * world_scale, 0.0)
	m.scale_min = 8.0 * world_scale
	m.scale_max = 14.0 * world_scale
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 18.0 * world_scale
	m.emission_ring_inner_radius = 8.0 * world_scale
	m.emission_ring_height = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(DUST_COLOR, 0.45))
	ramp.set_color(1, Color(DUST_COLOR, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	p.process_material = m
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.draw_pass_1 = q
	defender.add_child(p)
	_free_after(p, p.lifetime, 0.1)
	return p


static func _quad(color: Color, energy: float) -> QuadMesh:
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	q.material = mat
	return q


static func _free_after(node: Node, emit_sec: float, tail_sec: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = emit_sec + tail_sec
	t.autostart = true
	t.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())
	node.add_child(t)
	if not (node as GPUParticles3D).one_shot:
		var stop := Timer.new()
		stop.one_shot = true
		stop.wait_time = emit_sec
		stop.autostart = true
		stop.timeout.connect(func():
			if is_instance_valid(node):
				(node as GPUParticles3D).emitting = false)
		node.add_child(stop)
