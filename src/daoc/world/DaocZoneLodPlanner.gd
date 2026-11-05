extends RefCounted
class_name DaocZoneLodPlanner

## P1-33 — QUI charger d'avance, et QUI dessiner fin.
##
## Deux défauts observés au bord d'une zone, et ils n'ont pas la même cause :
##
##   1. **le passage est violent.** `cross_zone_border_r5` bâtit la voisine à
##      l'instant EXACT où le joueur franchit le bord. Le monde s'arrête donc
##      pile au moment où l'on a le plus besoin qu'il ne s'arrête pas ;
##   2. **la texture de la voisine est ignoble quand on l'approche**, et celle
##      de la zone quittée l'est tout autant quand on se retourne. Ce n'est PAS
##      un défaut de maillage : l'atlas d'horizon fait 512 px pour 65 536 unités
##      DAoC, soit **128 unités par texel**. Vu de l'autre bout de la région
##      c'est correct ; vu à 2 000 unités c'est une bouillie.
##
## Cet objet ne bâtit rien et ne dessine rien. Il RÉPOND à deux questions, à
## partir des seules emprises de `DaocZoneTransition` :
##
##   - quelles voisines faut-il faire naître MAINTENANT, avant le bord ;
##   - quelles zones lointaines méritent le rendu fin, parce qu'on est près
##     d'une frontière qu'elles partagent RÉELLEMENT avec une zone résidente.
##
## LES DEUX RAYONS DÉPENDENT DE LA VITESSE, et c'est le point : un joueur au pas
## et un joueur en sprint n'ont pas le même temps devant eux. Le rayon vaut
## `base + vitesse × secondes` — autrement dit « ce que le joueur peut atteindre
## dans les N prochaines secondes », plus une marge fixe. À vitesse nulle la
## marge fixe subsiste : rester immobile à trois mètres du bord ne doit pas
## éteindre la voisine.
##
## UNE FRONTIÈRE CONTIGUË N'EST PAS UNE ZONE PROCHE, et c'est toute la subtilité
## de cette région. L'archipel d'Avalon est en ESCALIER : deux zones peuvent être
## à 3 000 unités l'une de l'autre sans partager le moindre bord. Affiner une
## zone que rien ne relie au sol sur lequel on marche ne corrige aucune couture
## et coûte le prix fort. Le test porte donc sur un bord PARTAGÉ, de longueur non
## nulle, pas sur une distance.

## Un secteur DAoC. Les sept zones d'Avalon font 8x8 secteurs, donc 65 536.
const SECTOR_SIZE := 8192.0

## Deux emprises se touchent quand leurs bords coïncident. Les origines sont des
## multiples de 8192 en entier : une unité de tolérance suffit, et éviter un
## `==` sur des flottants évite un raccord manqué pour une erreur d'arrondi.
const EDGE_TOUCH_EPSILON := 1.0

## Un contact de longueur nulle est un COIN, pas une frontière. Deux zones qui
## ne se touchent que par un angle n'ont aucune couture à corriger.
const MIN_SHARED_EDGE_LENGTH := 1.0

## Les quatre bords d'une emprise, nommés du point de vue de la zone LOINTAINE.
const EDGE_X_MIN := "x_min"
const EDGE_X_MAX := "x_max"
const EDGE_Y_MIN := "y_min"
const EDGE_Y_MAX := "y_max"

## Réglages par défaut, en unités DAoC brutes. `local_run_speed_raw` vaut 1500 :
## quatre secondes de course valent donc 6 000 unités, et le rayon de
## préchargement atteint alors ~12 000 — de quoi bâtir la voisine bien avant que
## le joueur ne voie son bord.
const DEFAULTS: Dictionary = {
	"prefetch_base_raw": 6000.0,
	"prefetch_seconds": 4.0,
	"near_lod_base_raw": 12000.0,
	"near_lod_seconds": 6.0,
	"max_prefetch_zones": 2,
	"max_near_zones": 3,
	"max_speed_raw": 4000.0,
}


## Les bords de `rect` qui touchent `other`, avec un vrai segment en commun.
##
## Le nom rendu est celui du bord DE `rect` : `x_max` signifie « la limite haute
## en X de cette zone donne sur l'autre ». C'est ce dont le maillage a besoin
## pour savoir de quel côté il doit se densifier.
static func shared_edges(rect: Rect2, other: Rect2) -> Array:
	var edges: Array = []
	if rect.size == Vector2.ZERO or other.size == Vector2.ZERO:
		return edges
	var overlap_y := minf(rect.end.y, other.end.y) - maxf(rect.position.y, other.position.y)
	var overlap_x := minf(rect.end.x, other.end.x) - maxf(rect.position.x, other.position.x)
	if overlap_y >= MIN_SHARED_EDGE_LENGTH:
		if absf(rect.position.x - other.end.x) <= EDGE_TOUCH_EPSILON:
			edges.append(EDGE_X_MIN)
		if absf(rect.end.x - other.position.x) <= EDGE_TOUCH_EPSILON:
			edges.append(EDGE_X_MAX)
	if overlap_x >= MIN_SHARED_EDGE_LENGTH:
		if absf(rect.position.y - other.end.y) <= EDGE_TOUCH_EPSILON:
			edges.append(EDGE_Y_MIN)
		if absf(rect.end.y - other.position.y) <= EDGE_TOUCH_EPSILON:
			edges.append(EDGE_Y_MAX)
	return edges


## Distance du point au pavé, nulle à l'intérieur. Godot n'expose pas ce calcul
## sur `Rect2` ; l'écrire ici évite qu'il soit refait différemment ailleurs.
static func distance_to_rect(point: Vector2, rect: Rect2) -> float:
	if rect.size == Vector2.ZERO:
		return INF
	var nearest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(nearest)


## Le rayon utile pour cette vitesse : une marge fixe, plus ce que le joueur
## peut parcourir dans les `seconds` qui viennent.
static func radius_for_speed(base_raw: float, seconds: float, speed_raw: float,
		max_speed_raw: float) -> float:
	var speed := clampf(absf(speed_raw), 0.0, maxf(max_speed_raw, 0.0))
	return maxf(base_raw, 0.0) + speed * maxf(seconds, 0.0)


## LE geste du jalon. `transition` est le `DaocZoneTransition` de R5 : une seule
## vérité sur l'endroit où vit chaque zone, partagée avec l'horizon et le
## franchissement.
##
## `resident` est le jeu des zones réellement bâties, `active` celle où se trouve
## le joueur. Les deux comptent : le rendu fin sert aussi à la zone qu'on vient
## de QUITTER, contiguë à la nouvelle zone active et qu'on regarde en se
## retournant.
static func plan(transition, active: int, daoc_x: float, daoc_y: float,
		speed_raw: float, resident: Array, settings: Dictionary = {}) -> Dictionary:
	var options := DEFAULTS.duplicate(true)
	for key in settings.keys():
		if options.has(key):
			options[key] = settings[key]

	var report := {
		"ok": false,
		"active": active,
		"speed_raw": maxf(absf(speed_raw), 0.0),
		"prefetch_radius_raw": 0.0,
		"near_radius_raw": 0.0,
		"contiguous": [],
		"prefetch": [],
		"near_zones": [],
		"near_edges": {},
		"distances": {},
		"resident": [],
	}
	if transition == null or not transition.known():
		report["reason"] = "emprises inconnues"
		return report
	var active_rect: Rect2 = transition.footprint(active)
	if active_rect.size == Vector2.ZERO:
		report["reason"] = "zone active %d absente du catalogue" % active
		return report

	var resident_ids: Array = []
	for value in resident:
		if not resident_ids.has(int(value)):
			resident_ids.append(int(value))
	if not resident_ids.has(active):
		resident_ids.append(active)
	resident_ids.sort()
	report["resident"] = resident_ids.duplicate()

	var player_world: Vector2 = transition.world_point(active, daoc_x, daoc_y)
	report["player_world"] = player_world
	var prefetch_radius := radius_for_speed(
		float(options["prefetch_base_raw"]), float(options["prefetch_seconds"]),
		speed_raw, float(options["max_speed_raw"]))
	var near_radius := radius_for_speed(
		float(options["near_lod_base_raw"]), float(options["near_lod_seconds"]),
		speed_raw, float(options["max_speed_raw"]))
	report["prefetch_radius_raw"] = prefetch_radius
	report["near_radius_raw"] = near_radius

	var region: int = transition.region_of(active)
	var ranked: Array = []
	for value in transition.zones_of_region(region):
		var zone_id := int(value)
		if zone_id == active:
			continue
		var rect: Rect2 = transition.footprint(zone_id)
		if rect.size == Vector2.ZERO:
			continue
		var distance := distance_to_rect(player_world, rect)
		(report["distances"] as Dictionary)[zone_id] = distance
		# Les bords que cette zone partage avec N'IMPORTE QUELLE zone résidente.
		# Passer par le seul `active` raterait la zone que l'on vient de quitter
		# dès qu'une troisième zone reste chargée entre les deux.
		var edges: Array = []
		for other in resident_ids:
			if int(other) == zone_id:
				continue
			for edge in shared_edges(rect, transition.footprint(int(other))):
				if not edges.has(edge):
					edges.append(edge)
		if edges.is_empty():
			continue
		(report["contiguous"] as Array).append(zone_id)
		ranked.append({"zone": zone_id, "distance": distance, "edges": edges})

	(report["contiguous"] as Array).sort()
	# Le plus proche d'abord : c'est celui vers lequel on va, et c'est lui qui
	# doit gagner quand le budget ne permet pas de tout servir.
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"]))

	for item in ranked:
		var zone_id := int(item["zone"])
		var distance := float(item["distance"])
		if distance <= near_radius \
				and (report["near_zones"] as Array).size() < int(options["max_near_zones"]) \
				and not resident_ids.has(zone_id):
			(report["near_zones"] as Array).append(zone_id)
			(report["near_edges"] as Dictionary)[zone_id] = (item["edges"] as Array).duplicate()
		if distance <= prefetch_radius \
				and not resident_ids.has(zone_id) \
				and (report["prefetch"] as Array).size() < int(options["max_prefetch_zones"]):
			(report["prefetch"] as Array).append(zone_id)

	report["ok"] = true
	return report


## Deux plans décrivent-ils le même horizon ? Utilisé pour ne RECONSTRUIRE que
## sur un vrai changement : rebâtir le relief lointain à chaque image, sous
## prétexte que la vitesse a bougé de trois unités, coûterait bien plus cher que
## la bouillie qu'on veut corriger.
static func same_lod_selection(a: Dictionary, b: Dictionary) -> bool:
	if (a.get("near_zones", []) as Array) != (b.get("near_zones", []) as Array):
		return false
	return (a.get("near_edges", {}) as Dictionary) == (b.get("near_edges", {}) as Dictionary)


## L'horizon bâti est-il PÉRIMÉ ? Deux raisons, et non une : les zones
## résidentes ont changé, OU le palier proche a changé sans elles. La seconde
## est le cas de tout ce qui précède le premier franchissement — la liste des
## résidentes y est celle du démarrage, et ne juger que sur elle laissait la
## voisine floue jusqu'à la première traversée (constat visuel du 2026-09-10).
static func horizon_is_stale(resident: Array, built_resident: Array,
		plan: Dictionary, built_selection: Dictionary, near_lod_enabled: bool) -> bool:
	if resident != built_resident:
		return true
	if not near_lod_enabled:
		return false
	return not same_lod_selection(built_selection, plan)
