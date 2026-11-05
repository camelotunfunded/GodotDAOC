extends Node
class_name DaocGameSession

## R0 - le socle de session : le proprietaire des systemes qui SURVIVENT.
##
## Le ZoneViewer melange aujourd'hui deux durees de vie au meme niveau. C'est
## la raison technique de la reconstruction, et elle dicte tout l'ordre :
##
##   PAR ZONE (jetable)     terrain, collision, eau, vegetation, props,
##                          lighting, zonejump, terrain lointain
##   PAR SESSION (persistant) joueur, camera, routeur d'entrees, autorite
##                          serveur, autorite environnement, source d'entites, UI
##
## Ce noeud ne prend en charge que la SECONDE colonne, et seulement sa
## POSSESSION. Il ne construit rien, ne connait aucune regle DAoC, ne branche
## aucun signal : la logique reste exactement ou elle est. R0 deplace le
## proprietaire, pas le comportement - c'est ce qui rend sa suite verifiable par
## simple parite avec l'existant.
##
## Pourquoi ce noeud d'abord, alors qu'il ne se voit pas : R2 - la boucle
## vivante - a besoin qu'une entite puisse apparaitre et disparaitre pendant
## qu'un decor est detruit et rebati. Tant que le joueur et l'arbitre sont des
## variables du ZoneViewer, recharger une zone les emporte.
##
## `DaocServerLink` est nomme ici des R0 pour une raison : c'est le point de
## debranchement OpenDAoC. Le jour ou un vrai serveur est joignable, on remplace
## le contenu de `server_link` et rien d'autre ne bouge. Le decoupage a deja ete
## tenu trois fois - `DaocEnvironmentController` devant Sky3D,
## `DaocNearbyWorldEntitySource` devant le monde, `DaocLocalServer` a la place
## du serveur.

## Horloge et meteo : l'autorite DAoC devant Sky3D (`DaocEnvironmentController`).
var world_clock: Node = null

## L'arbitre. `DaocLocalServer` aujourd'hui, un vrai lien reseau demain : c'est
## LE point de debranchement, et il porte deja son nom de destination.
var server_link: DaocLocalServer = null

## La population du monde (`DaocGothwaitePopulation`). En R2 elle cessera d'etre
## construite en une fois et deviendra le consommateur d'un flux.
var entity_population: RefCounted = null

## Retour visuel de l'eau : immersion, caustiques, sillage. Persistant parce
## qu'il suit la camera et le joueur, pas la zone.
var water_fx: Node = null

var player: Node3D = null
var player_camera: Node = null
var input_router: Node = null

## R1 - le proprietaire du cote JETABLE. Il est PERSISTANT lui-meme : ce sont
## les zones qu'il tient qui meurent, pas lui. C'est ce qui permet a une zone de
## disparaitre sans emporter le joueur.
var zone_streamer: DaocZoneStreamer = null

## R2 - le lecteur du flux d'entites. Il ne detient aucun noeud du monde : il
## ordonne a `entity_population` de faire apparaitre, deplacer ou retirer.
var entity_stream: DaocEntityStreamRuntime = null


## Les emplacements, dans l'ordre de declaration. Sert au rapport et a la suite :
## une reconstruction future ne doit pas en perdre un en silence.
##
## Sept a R0 ; huit depuis R1, ou `zone_streamer` s'ajoute parce qu'il survit aux
## zones qu'il charge ; neuf depuis R2 avec `entity_stream`.
const SLOTS := [
	"world_clock", "server_link", "entity_population", "water_fx",
	"player", "player_camera", "input_router",
	"zone_streamer", "entity_stream",
]


## Etat lisible par machine. `occupied` compte ce qui est REELLEMENT branche :
## une session vide est un cas normal (un test qui ne batit pas le monde), pas
## une erreur - c'est l'appelant qui sait ce qu'il attend.
func describe() -> Dictionary:
	var occupied: int = 0
	var slots: Dictionary = {}
	for slot: String in SLOTS:
		var held: bool = get(slot) != null
		slots[slot] = held
		if held:
			occupied += 1
	return {
		"ok": true,
		"slots": slots,
		"declared": SLOTS.size(),
		"occupied": occupied,
	}


## Relache les emplacements SANS toucher aux objets : la session ne les a pas
## crees, elle ne les detruit pas. Utile a une suite qui rejoue un montage.
func release_all() -> void:
	for slot: String in SLOTS:
		set(slot, null)
