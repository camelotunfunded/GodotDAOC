extends RefCounted
class_name DaocZoneTransition

## R5 — franchir une frontière de zone, pour de vrai.
##
## Jusqu'ici le monde s'arrêtait au bord de la zone chargée, et pas seulement
## visuellement : `DaocPlayerMotor.motor_clamp_zone_xy` RABOTAIT les coordonnées
## du joueur à `[0, 65536]`. Le garde-fou était volontaire — sans voisine bâtie,
## sortir de la zone aurait fait tomber le joueur sur un sol absent. R5 lui donne
## enfin une alternative : demander s'il existe une voisine sous ce point.
##
## Cet objet ne bâtit rien et ne déplace personne. Il RÉPOND à deux questions,
## et c'est tout ce qui manquait :
##
##   1. « ce point, hors de ma zone, appartient-il à une voisine de ma région ? »
##      — et si oui, quelles sont mes coordonnées dans SON repère ;
##   2. « quelles zones puis-je décharger sans toucher à celle où je suis ? »
##
## LA RÉGION EST UN ARCHIPEL EN ESCALIER, pas une grille. Les sept zones d'Avalon
## se touchent par leurs bords en X mais sont décalées en Y : la frontière ouest
## de la zone 51 ne donne sur la zone 52 que pour `y` entre 491520 et 507904.
## Ailleurs, il n'y a rien — et le rabotage reste alors la bonne réponse. C'est
## pourquoi la question porte sur un POINT et non sur une direction.
##
## Les emprises viennent de `zones_placement.json`, le même fichier que
## `ZoneViewer._load_placement` et que l'horizon P1-20J : une seule vérité sur
## l'endroit où vit chaque zone.

## Emprise d'une zone, en unités DAoC brutes. Le catalogue déclare `size_sectors`
## et un secteur vaut 8192 ; les sept zones d'Avalon font 8x8, donc 65536.
const SECTOR_SIZE := 8192.0

## zone_id -> {"region": int, "rect": Rect2, "name": String}
var _zones: Dictionary = {}
## region -> Array[int] trié
var _by_region: Dictionary = {}

## Les zones résidentes, de la moins récemment habitée à la plus récente.
## C'est cet ordre qui décide de l'éviction : une zone traversée puis quittée
## part avant une zone qu'on vient d'habiter.
var _residency_order: Array = []


static func from_placement_file(path: String) -> DaocZoneTransition:
	var transition := DaocZoneTransition.new()
	transition.load_placement(path)
	return transition


## Lit les emprises. Une zone `enabled=0` est ignorée : elle n'a pas de terrain
## à bâtir, donc on ne peut pas y marcher.
func load_placement(path: String) -> bool:
	_zones.clear()
	_by_region.clear()
	if path == "" or not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for value in (parsed as Dictionary).get("zones", []) as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value as Dictionary
		if int(entry.get("enabled", 0)) != 1:
			continue
		var origin_raw: Array = entry.get("world_origin", []) as Array
		var size_raw: Array = entry.get("size_sectors", []) as Array
		if origin_raw.size() < 2 or size_raw.size() < 2:
			continue
		var zone_id := int(entry.get("zone", -1))
		var region := int(entry.get("region", -1))
		var origin := Vector2(float(origin_raw[0]), float(origin_raw[1]))
		var size := Vector2(float(size_raw[0]) * SECTOR_SIZE, float(size_raw[1]) * SECTOR_SIZE)
		_zones[zone_id] = {
			"region": region,
			"rect": Rect2(origin, size),
			"name": str(entry.get("name", "")),
		}
		var siblings: Array = _by_region.get(region, []) as Array
		siblings.append(zone_id)
		siblings.sort()
		_by_region[region] = siblings
	return not _zones.is_empty()


func known() -> bool:
	return not _zones.is_empty()


func region_of(zone_id: int) -> int:
	return int((_zones.get(zone_id, {}) as Dictionary).get("region", -1))


func footprint(zone_id: int) -> Rect2:
	return (_zones.get(zone_id, {}) as Dictionary).get("rect", Rect2()) as Rect2


func zones_of_region(region: int) -> Array:
	return (_by_region.get(region, []) as Array).duplicate()


## Le point monde d'une coordonnée locale. C'est le seul repère commun aux
## zones : les coordonnées `daoc_x/y` sont locales et deux zones différentes en
## portent les mêmes.
func world_point(zone_id: int, daoc_x: float, daoc_y: float) -> Vector2:
	return footprint(zone_id).position + Vector2(daoc_x, daoc_y)


## Vrai tant que la coordonnée reste dans l'emprise de sa zone.
func inside(zone_id: int, daoc_x: float, daoc_y: float) -> bool:
	var rect := footprint(zone_id)
	if rect.size == Vector2.ZERO:
		return true
	return daoc_x >= 0.0 and daoc_y >= 0.0 \
		and daoc_x <= rect.size.x and daoc_y <= rect.size.y


## LA question de R5 : sortir de la zone `zone_id` en `(daoc_x, daoc_y)`, est-ce
## entrer quelque part ?
##
## Le retour porte les coordonnées dans le repère de la voisine, jamais une
## direction : c'est ce qui rend le passage sans téléportation. Le POINT MONDE
## est identique des deux côtés, seul le repère change.
func resolve_border_crossing(zone_id: int, daoc_x: float, daoc_y: float) -> Dictionary:
	if not known():
		return {"ok": false, "reason": "emprises inconnues"}
	if not _zones.has(zone_id):
		return {"ok": false, "reason": "zone %d absente du catalogue" % zone_id}
	if inside(zone_id, daoc_x, daoc_y):
		return {"ok": false, "reason": "toujours dans la zone"}

	var world := world_point(zone_id, daoc_x, daoc_y)
	var region := region_of(zone_id)
	for candidate: int in zones_of_region(region):
		if candidate == zone_id:
			continue
		var rect := footprint(candidate)
		if not rect.has_point(world):
			continue
		return {
			"ok": true,
			"from_zone": zone_id,
			"zone": candidate,
			"name": str((_zones[candidate] as Dictionary).get("name", "")),
			"x": world.x - rect.position.x,
			"y": world.y - rect.position.y,
			"world": world,
			"region": region,
		}
	# Pas de voisine sous ce point : l'archipel s'arrête là, et le rabotage
	# d'origine reste la bonne reponse.
	return {"ok": false, "reason": "aucune voisine sous ce point", "world": world}


## Note qu'on habite une zone. L'ordre est un ordre d'HABITATION, pas de
## chargement : c'est lui qui dit laquelle on a quittée depuis le plus longtemps.
func note_entered(zone_id: int) -> void:
	_residency_order.erase(zone_id)
	_residency_order.append(zone_id)


func residency_order() -> Array:
	return _residency_order.duplicate()


## Les zones à décharger pour tenir le budget, la plus anciennement habitée
## d'abord.
##
## `active` n'est JAMAIS évincée, même si le budget vaut 1 et qu'elle est la
## dernière arrivée : décharger la zone où se trouve le joueur le ferait tomber
## à travers le sol. Une zone résidente jamais habitée — la voisine que R5 vient
## de charger — passe avant celles qui ont un passé.
func plan_eviction(resident: Array, max_resident: int, active: int) -> Array:
	var budget: int = maxi(1, max_resident)
	var keep: Array = []
	for zone_id in resident:
		if int(zone_id) != active:
			keep.append(int(zone_id))
	keep.sort_custom(func(a: int, b: int) -> bool:
		return _residency_rank(a) < _residency_rank(b))

	var surplus: int = keep.size() + 1 - budget
	if surplus <= 0:
		return []
	return keep.slice(0, mini(surplus, keep.size()))


func _residency_rank(zone_id: int) -> int:
	var index := _residency_order.find(zone_id)
	# Jamais habitée : elle part la première, d'où un rang négatif.
	return index if index >= 0 else -1


func describe(active: int = -1) -> Dictionary:
	return {
		"ok": known(),
		"zones_known": _zones.size(),
		"regions_known": _by_region.size(),
		"active": active,
		"residency_order": residency_order(),
	}
