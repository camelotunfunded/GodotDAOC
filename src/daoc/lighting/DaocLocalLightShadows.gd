extends Node
class_name DaocLocalLightShadows

## P1-91 — les ombres des lumieres ARTIFICIELLES : feux, lampes, torches.
##
## Le soleil projette une ombre unique, nette, qui structure la scene. Une
## flamme fait l'inverse : elle est PROCHE, donc ses ombres s'etirent et
## s'ecartent vite ; elle est PETITE mais vacillante, donc ses bords bougent ;
## et elle n'eteint jamais tout, la nuit garde son ambiance. D'ou une autre
## direction artistique que celle de P1-90 : ombres FLOUES (`shadow_blur`
## eleve), PAS TOUT A FAIT NOIRES (`shadow_opacity` < 1), et qui DANSENT avec
## la flamme pour les types de feu ; celles des lueurs magiques restent
## immobiles.
##
## Le cout est le vrai sujet : chaque OmniLight3D avec ombre rend SIX faces de
## cubemap par image. La zone 51 porte des dizaines de lampes ; les armer
## toutes est impossible. Ce noeud tient donc un BUDGET : seules les N lampes
## les plus proches de la camera (ponderees par leur portee) projettent, et
## leur opacite fond avec la distance pour qu'une lampe qui entre ou sort du
## budget ne fasse jamais « clignoter » son ombre.
##
## Il ne DECIDE d'aucune lumiere : les lampes viennent de `lights.csv` par
## `DaocLegacyVisuals`, la torche du joueur de `DaocPlayerTorch`. Il ne fait
## que regler `shadow_*` et moduler `light_energy` autour de la valeur de base
## que ces auteurs ont posee dans la meta `daoc_base_energy`.

const GROUP_LIGHT := "daoc_legacy_light"
const META_BASE_ENERGY := "daoc_base_energy"
const META_LIGHT_TYPE := "daoc_light_type"
## Types du lights.csv qui sont des FLAMMES (couleurs chaudes dans
## `DaocLegacyVisuals._legacy_light_type_color`). Les autres sont des lueurs
## magiques ou froides : elles ne vacillent pas.
const FIRE_TYPES: Array[int] = [0, 1, 2, 3, 4, 15, 17]

const DEFAULTS: Dictionary = {
	"enabled": true,
	# Lampes qui projettent en meme temps. 4 = 24 faces de cubemap par image.
	"max_shadowed_lights": 4,
	# Flou des bords : 1,0 est le defaut Godot (dur). Une flamme demande large.
	"shadow_blur": 2.6,
	# 1,0 = noir total. Une ombre de lanterne laisse passer l'ambiance nocturne.
	"shadow_opacity": 0.82,
	# Fraction de la portee de la lampe au-dela de laquelle l'ombre commence a
	# fondre, jusqu'a zero a la portee entiere.
	"fade_start_fraction": 0.55,
	# Vacillement des flammes : amplitude relative de l'energie, et vitesse.
	"flicker_enabled": true,
	"flicker_amount": 0.12,
	"flicker_speed": 1.0,
	# Toutes les 0,2 s : recalculer le budget. La camera bouge lentement a
	# l'echelle d'une place de village ; le vacillement, lui, tourne a chaque
	# image.
	"budget_interval": 0.2,
}

var _settings: Dictionary = DEFAULTS.duplicate(true)
var _budget_clock: float = 0.0
var _clock: float = 0.0
var _shadowed: Array[Light3D] = []
var _last_report: Dictionary = {}


func _ready() -> void:
	# Un seul budget par arbre : deux gestionnaires armeraient chacun leurs N
	# lampes. Celui qui arrive second se retire.
	add_to_group("daoc_local_light_shadows")
	for other in get_tree().get_nodes_in_group("daoc_local_light_shadows"):
		if other != self and is_instance_valid(other):
			queue_free()
			return


func configure(options: Dictionary) -> void:
	for key in options.keys():
		if _settings.has(key):
			_settings[key] = options[key]
	_budget_clock = 999.0
	if not bool(_settings["enabled"]):
		_release_all()


func settings() -> Dictionary:
	return _settings.duplicate(true)


func _process(delta: float) -> void:
	if not bool(_settings["enabled"]):
		return
	var step := maxf(delta, 0.0)
	_clock += step
	_budget_clock += step
	if _budget_clock >= float(_settings["budget_interval"]):
		_budget_clock = 0.0
		_rebuild_budget()
	_flicker()


## Choisit les lampes qui projettent. Score = distance a la camera divisee
## par la portee : une grande lampe lointaine peut battre une petite proche,
## puisque c'est elle qui couvre l'ecran.
func _rebuild_budget() -> void:
	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	var eye := camera.global_position if camera != null else Vector3.ZERO
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group(GROUP_LIGHT):
		var light := node as Light3D
		if light == null or not light.is_visible_in_tree():
			continue
		var reach := _reach(light)
		if reach <= 0.0:
			continue
		var distance := light.global_position.distance_to(eye)
		if distance > reach:
			continue
		candidates.append({"light": light, "score": distance / reach, "distance": distance, "reach": reach})
	candidates.sort_custom(func(a, b): return float(a["score"]) < float(b["score"]))
	var budget := maxi(0, int(_settings["max_shadowed_lights"]))
	var chosen: Array[Light3D] = []
	var fade_start := clampf(float(_settings["fade_start_fraction"]), 0.0, 0.99)
	for i in range(mini(budget, candidates.size())):
		var entry: Dictionary = candidates[i]
		var light: Light3D = entry["light"]
		var fraction := float(entry["distance"]) / float(entry["reach"])
		var fade := 1.0 - smoothstep(fade_start, 1.0, fraction)
		light.shadow_enabled = true
		light.shadow_blur = maxf(0.0, float(_settings["shadow_blur"]))
		light.shadow_opacity = clampf(float(_settings["shadow_opacity"]) * fade, 0.0, 1.0)
		chosen.append(light)
	for light in _shadowed:
		if is_instance_valid(light) and not chosen.has(light):
			light.shadow_enabled = false
	_shadowed = chosen
	_last_report = {
		"candidates": candidates.size(),
		"shadowed": chosen.size(),
		"budget": budget,
		"shadowed_names": chosen.map(func(l): return l.name),
	}


## Une flamme ne brule pas a energie constante : trois sinus incommensurables,
## dephases par la position de la lampe pour que deux torches voisines ne
## respirent jamais ensemble. L'ombre suit, puisqu'elle est celle de la lampe.
func _flicker() -> void:
	if not bool(_settings["flicker_enabled"]):
		return
	var amount := clampf(float(_settings["flicker_amount"]), 0.0, 0.5)
	var speed := maxf(0.0, float(_settings["flicker_speed"]))
	for node in get_tree().get_nodes_in_group(GROUP_LIGHT):
		var light := node as Light3D
		if light == null or not light.visible:
			continue
		if not light.has_meta(META_BASE_ENERGY):
			light.set_meta(META_BASE_ENERGY, light.light_energy)
		var base := float(light.get_meta(META_BASE_ENERGY))
		if not _is_fire(light):
			light.light_energy = base
			continue
		var p := light.global_position
		var phase := fmod(absf(p.x * 0.013 + p.z * 0.029 + p.y * 0.007), TAU)
		var t := _clock * speed
		var wave := sin(t * 8.7 + phase) * 0.55 + sin(t * 17.3 + phase * 1.7) * 0.30 \
			+ sin(t * 31.1 + phase * 0.4) * 0.15
		light.light_energy = base * (1.0 + wave * amount)


func _is_fire(light: Light3D) -> bool:
	if not light.has_meta(META_LIGHT_TYPE):
		return true
	return int(light.get_meta(META_LIGHT_TYPE)) in FIRE_TYPES


func _reach(light: Light3D) -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range
	return 0.0


func _release_all() -> void:
	for light in _shadowed:
		if is_instance_valid(light):
			light.shadow_enabled = false
	_shadowed.clear()
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(GROUP_LIGHT):
			var light := node as Light3D
			if light != null and light.has_meta(META_BASE_ENERGY):
				light.light_energy = float(light.get_meta(META_BASE_ENERGY))


func debug_snapshot() -> Dictionary:
	var report := _last_report.duplicate(true)
	report["settings"] = _settings.duplicate(true)
	return report
