extends Node3D
class_name DaocZoneStreamer

## R1 - le proprietaire du cote JETABLE.
##
## R0 a donne un proprietaire aux systemes qui survivent. R1 donne le sien a ce
## qui doit mourir : les `DaocZoneRoot`, et tout ce qu'un jalon 14A-14E accroche
## dessous - terrain, collision, eau, vegetation, lumieres, props.
##
## Les deux durees de vie ont enfin chacune leur noeud. C'est tout ce que R1
## prouve, et c'est deja beaucoup : jusqu'ici, decharger une zone signifiait
## reconstruire la session entiere, soit environ sept minutes.
##
## Ce noeud ne CONSTRUIT rien. Il cree la branche vide et la detruit ; le
## remplissage reste `DaocZoneSceneAssembler`, dont l'ordre est valide depuis
## P1-15B. Meme discipline qu'a chaque couture du projet : on deplace la
## propriete, jamais la logique.
##
## Piege paye ici, et pas ailleurs : `queue_free` ne detruit qu'en FIN de trame.
## Recharger une zone dans la meme trame ajouterait un second `Zone051_Root`
## pendant que le premier agonise, Godot renommerait le nouveau, et les
## `find_child("Zone%03d_Root")` de l'audit, de la sonde NIF et de
## `DaocZoneCreator` trouveraient le cadavre. La branche est donc DETACHEE
## immediatement, puis liberee.
##
## `Node3D` et non `Node` : les branches de zone portent des positions monde. Le
## streamer reste a l'identite, donc les transformations globales sont
## inchangees - la suite le verifie plutot que de le supposer.

## R4, dernière pièce — le jeu des zones résidentes a changé.
##
## L'horizon P1-20J dessine le relief des zones de la région QUI NE SONT PAS
## résidentes. Il dépend donc de cette liste, et pas seulement au démarrage :
## charger une voisine sans le redire dessinerait cette voisine DEUX fois, une
## fois en vrai et une fois en relief lointain, et la zone quittée n'aurait plus
## aucun horizon à sa place.
##
## Le streamer ne reconstruit rien lui-même — il PRÉVIENT. Même discipline qu'à
## R1 : il possède la durée de vie, jamais la logique.
signal resident_zones_changed(zones: Array)

## Nom de la branche d'horizon. Elle vit SOUS le streamer, à l'identité comme lui,
## donc les positions monde de P1-20J sont inchangées.
const HORIZON_BRANCH_NAME := "Horizon"

## zone_id -> DaocZoneRoot vivant.
var _roots: Dictionary = {}

## Compteurs de cycle. Une recharge doit se PROUVER : sans eux, un test ne peut
## pas distinguer une zone rebatie d'une zone jamais detruite.
var loads: int = 0
var unloads: int = 0


## Rend la branche de la zone, en la creant au besoin. Remplace exactement
## l'ancien corps de `ZoneViewer._get_zone_root`.
func acquire(zone_id: int) -> DaocZoneRoot:
	if _roots.has(zone_id):
		var existing: Variant = _roots[zone_id]
		if is_instance_valid(existing):
			return existing as DaocZoneRoot
		# Libere par ailleurs : on ne rend pas une reference morte.
		_roots.erase(zone_id)

	var root := DaocZoneRoot.new()
	root.setup(zone_id)
	add_child(root)
	_roots[zone_id] = root
	loads += 1
	resident_zones_changed.emit(loaded_zones())
	return root


## Detruit la branche d'une zone. Vraie si quelque chose a ete decharge.
##
## La session n'est pas touchee : c'est LE point du jalon.
func unload(zone_id: int) -> bool:
	if not _roots.has(zone_id):
		return false
	var root: Variant = _roots[zone_id]
	_roots.erase(zone_id)
	unloads += 1
	if not is_instance_valid(root):
		return true
	var node := root as Node
	# Detacher AVANT de liberer : voir l'entete, le nom doit se liberer tout de
	# suite pour qu'une reconstruction immediate ne tombe pas sur le cadavre.
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()
	resident_zones_changed.emit(loaded_zones())
	return true


## Decharge tout. Utile a une suite qui rejoue plusieurs montages.
func unload_all() -> int:
	var count: int = 0
	for zone_id: int in _roots.keys():
		if unload(zone_id):
			count += 1
	return count


func has_zone(zone_id: int) -> bool:
	return _roots.has(zone_id) and is_instance_valid(_roots[zone_id])


func loaded_zones() -> Array:
	var out: Array = []
	for zone_id: int in _roots.keys():
		if is_instance_valid(_roots[zone_id]):
			out.append(zone_id)
	out.sort()
	return out


## La branche d'horizon, creee au besoin.
##
## Elle est SOUS le streamer et non sous le viewer, parce que l'horizon a la meme
## duree de vie que le jeu des zones residentes : il change avec elles. C'est ce
## qui manquait pour que franchir une frontiere ne laisse pas un relief lointain
## en desaccord avec le monde reellement charge.
func horizon_branch() -> Node3D:
	var existing := get_node_or_null(HORIZON_BRANCH_NAME)
	if existing != null and existing is Node3D:
		return existing as Node3D
	var branch := Node3D.new()
	branch.name = HORIZON_BRANCH_NAME
	add_child(branch)
	return branch


func has_horizon_branch() -> bool:
	return get_node_or_null(HORIZON_BRANCH_NAME) != null


func describe() -> Dictionary:
	return {
		"ok": true,
		"loaded": loaded_zones(),
		"resident": loaded_zones().size(),
		"loads": loads,
		"unloads": unloads,
		"horizon_owned": has_horizon_branch(),
	}
