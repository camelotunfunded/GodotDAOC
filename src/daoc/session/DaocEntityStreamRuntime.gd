extends Node
class_name DaocEntityStreamRuntime

## R2 — le consommateur du flux : ce qui fait enfin RESPIRER le monde.
##
## Jusqu'ici Gothwaite naissait deja peuple. `DaocGothwaitePopulation.build`
## recevait les 311 entites d'un coup et les posait toutes ; rien n'apparaissait,
## rien ne bougeait, rien ne disparaissait. Le monde etait une photographie.
##
## Ce noeud consomme `DaocWorldEntityStream` et applique ses evenements un par
## un, dans l'ordre des paquets. La fixture des 311 entites n'est plus un bloc :
## elle devient le cas `t = fin` d'un flux qui commence VIDE.
##
## LA PORTE EST LA MEME. Une apparition passe par `population.spawn_one`,
## exactement la fonction dont `build` est desormais la boucle. Les deux chemins
## ne peuvent donc pas diverger sur le choix de scene, l'echelle, l'orientation
## ou l'ancrage — c'est ce que la suite R2 verifie en comparant les deux mondes.
##
## CE QUI EST PROUVE ET CE QUI NE L'EST PAS.
##
##   apparition   310 entites, paquets 14 a 806. Rejouee et comparee.
##   deplacement   24 paquets, 12 entites touchees, 8 deplacees pour de vrai.
##                 Rejoue et compare. Les distances sont petites — quelques
##                 dizaines d'unites DAoC — parce que la capture est courte.
##   retrait       ECRIT MAIS NON PROUVE. La capture ne porte aucun opcode de
##                 suppression et le decodeur n'en connait aucun. Ce chemin
##                 n'est exerce que par un evenement SYNTHETIQUE dans la suite.
##                 Ne pas le presenter comme valide contre un vrai serveur.
##
## Le debit est volontairement reglable. `apply_all` sert aux suites et au
## montage instantane ; `pump` etale l'application sur plusieurs trames pour que
## le monde se remplisse sous les yeux du joueur au lieu d'apparaitre d'un bloc.

signal entity_spawned(object_id: int, outcome: String)
signal entity_moved(object_id: int)
signal entity_despawned(object_id: int)
## R3 — evenement complet APRES application au monde. Le pont de combat lit la
## meme apparition / position / disparition sans redechiffrer la capture.
signal entity_event_applied(event: Dictionary, outcome: Dictionary)
signal stream_finished(report: Dictionary)

## Le peuplement qui detient les noeuds. Ce runtime ne cree aucun noeud lui-meme :
## il ne fait qu'ordonner, ce qui garde une seule autorite de placement.
var population: RefCounted = null

## L'hote qui sait convertir les coordonnees et sonder le terrain — le ZoneViewer.
var host: Node3D = null

var events: Array = []
var cursor: int = 0

var spawned: int = 0
var moved: int = 0
var despawned: int = 0
var ignored_moves: int = 0
var outcomes: Dictionary = {}

## Evenements appliques par trame quand le runtime se pompe lui-meme.
##
## `0` desactive le pompage automatique : l'appelant decide, ce que font les
## suites et la sonde. Une valeur positive etale le remplissage sur plusieurs
## trames — le monde se peuple alors SOUS LES YEUX du joueur, ce qui est
## precisement la difference entre un flux et un bloc.
##
## Attention au cout reel : une apparition instancie une scene DAoC complete.
## Un budget trop large rend le flux indistinguable d'un bloc et fige une trame.
var events_per_frame: int = 0
## En ligne, un deplacement glisse vers sa destination au lieu de sauter.
var smooth_moves: bool = false
## En ligne, seules les APPARITIONS coutent une scene : un deplacement ou un
## retrait est bon marche et ne doit pas attendre son tour derriere le budget.
## Sinon, des que le serveur envoie plus d'un 0xA1 par trame, la file grossit
## sans fin et les creatures prennent un retard croissant. Les suites qui
## pompent un evenement a la fois gardent le comportement historique (false).
var free_moves: bool = false


func _process(_delta: float) -> void:
	if events_per_frame <= 0 or finished():
		return
	pump(events_per_frame)


func setup(p_host: Node3D, p_population: RefCounted, p_events: Array) -> Dictionary:
	host = p_host
	population = p_population
	events = p_events
	cursor = 0
	spawned = 0
	moved = 0
	despawned = 0
	ignored_moves = 0
	outcomes = {}
	if host == null or population == null:
		return {"ok": false, "error": "hote ou peuplement absent"}
	return {"ok": true, "event_count": events.size()}


func finished() -> bool:
	return cursor >= events.size()


## Applique jusqu'a `budget` evenements. Rend le nombre reellement applique.
##
## `-1` applique tout ce qui reste : c'est ce qu'utilisent les suites, ou un
## montage qui veut le monde complet immediatement.
func pump(budget: int = -1) -> int:
	if population == null or host == null:
		return 0
	var applied := 0
	var spawns := 0
	while cursor < events.size():
		var event := events[cursor] as Dictionary
		var is_spawn := str(event.get("kind", "")) == DaocWorldEntityStream.KIND_SPAWN
		if budget >= 0:
			if free_moves:
				if is_spawn and spawns >= budget:
					break
			elif applied >= budget:
				break
		_apply(event)
		cursor += 1
		applied += 1
		if is_spawn:
			spawns += 1
	if finished():
		stream_finished.emit(report())
	return applied


func apply_all() -> int:
	return pump(-1)


func report() -> Dictionary:
	return {
		"ok": true,
		"event_count": events.size(),
		"applied": cursor,
		"finished": finished(),
		"spawned": spawned,
		"moved": moved,
		"despawned": despawned,
		"ignored_moves": ignored_moves,
		"outcomes": outcomes.duplicate(true),
		"live_object_ids": population.live_object_ids().size() if population != null else 0,
	}


func _apply(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		DaocWorldEntityStream.KIND_SPAWN:
			var entity: Variant = event.get("entity", {})
			if not entity is Dictionary:
				return
			var outcome: Dictionary = population.spawn_one(host, entity as Dictionary)
			var kind := str(outcome.get("outcome", "inconnu"))
			outcomes[kind] = int(outcomes.get(kind, 0)) + 1
			# `deferred_object` et `skipped_player` ne creent volontairement
			# aucun noeud : ils sont comptes, jamais remplaces par une invention.
			if kind == "living_scene" or kind == "prop_scene" or kind == "fallback":
				spawned += 1
			entity_spawned.emit(int(event.get("object_id", -1)), kind)
			entity_event_applied.emit(event.duplicate(true), outcome.duplicate(true))

		DaocWorldEntityStream.KIND_MOVE:
			var object_id := int(event.get("object_id", -1))
			var result: Dictionary = population.move_one(
				host, object_id,
				float(event.get("zone_x", 0)), float(event.get("zone_y", 0)),
				float(event.get("zone_z", 0)), int(event.get("heading", 0)),
				{"smooth": smooth_moves, "speed": float(event.get("speed", 0)),
					"target_zone_x": float(event.get("target_zone_x", 0)),
					"target_zone_y": float(event.get("target_zone_y", 0)),
					"target_zone_z": float(event.get("target_zone_z", 0))} if smooth_moves else {})
			if bool(result.get("ok", false)):
				moved += 1
				entity_moved.emit(object_id)
			else:
				# Un deplacement pour une entite jamais apparue, ou differee
				# faute de scene. Compte, jamais silencieux.
				ignored_moves += 1
			entity_event_applied.emit(event.duplicate(true), result.duplicate(true))

		DaocWorldEntityStream.KIND_DESPAWN:
			var gone := int(event.get("object_id", -1))
			var removed: bool = population.despawn_one(gone)
			if removed:
				despawned += 1
				entity_despawned.emit(gone)
			entity_event_applied.emit(event.duplicate(true), {
				"ok": removed, "object_id": gone, "removed_from_world": removed,
			})
