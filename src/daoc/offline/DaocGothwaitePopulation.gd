extends RefCounted
class_name DaocGothwaitePopulation

## Consommateur hors ligne de la capture P1-20E.
##
## La fixture porte des coordonnees MONDE de la region 51, alors que
## ZoneViewer attend des coordonnees locales a la zone 51. Le passage par
## world_origin_x/y est donc volontaire et fait partie du contrat.

const DaocHeadingScript = preload("res://src/daoc/world/DaocHeading.gd")
const ROOT_NAME := "GothwaitePopulationRoot"
const WATER_PROP_MODEL_IDS := [1615, 1616]

var root: Node3D
var last_report: Dictionary = {}
var _grounding_enabled: bool = true

## R2 - object_id -> noeud de l'entite. Tenu a l'apparition pour qu'un paquet de
## deplacement ou de retrait retrouve sa cible sans balayer les 307 enfants.
var _by_object_id: Dictionary = {}

## R2 - ce que la boucle de `build` calculait une fois, conserve pour qu'une
## apparition tardive soit placee exactement comme les premieres.
var _context: Dictionary = {}


func build(host: Node3D, fixture_path: String, manifest_path: String, overrides: Dictionary = {}) -> Dictionary:
	clear(host)
	_grounding_enabled = bool(overrides.get("grounding_enabled", true))

	# P1-20I : la liste d'entites peut venir d'ailleurs que du fichier fige.
	# `DaocNearbyWorldEntitySource` sait la produire en decodant la capture de
	# paquets, et il est prouve que les deux provenances donnent le meme
	# resultat. On accepte donc une liste deja construite, sans rien changer au
	# chemin historique quand elle est absente.
	var injected: Variant = overrides.get("entities", null)
	var entity_source := "FIXTURE"
	var fixture := {}
	if injected is Array and not (injected as Array).is_empty():
		entity_source = str(overrides.get("entity_source", "INJECTED"))
	else:
		fixture = _read_json(fixture_path)
		if fixture.is_empty():
			last_report = {"ok": false, "error": "fixture_unreadable", "fixture_path": fixture_path}
			return last_report

	var manifest := _read_json(manifest_path)
	var prop_manifest_path := str(overrides.get("prop_manifest_path", ""))
	var prop_manifest := _read_json(prop_manifest_path) if not prop_manifest_path.is_empty() else {}
	if manifest.is_empty():
		last_report = {"ok": false, "error": "manifest_unreadable", "manifest_path": manifest_path}
		return last_report
	if not prop_manifest_path.is_empty() and prop_manifest.is_empty():
		last_report = {"ok": false, "error": "prop_manifest_unreadable", "prop_manifest_path": prop_manifest_path}
		return last_report

	var entities := (injected as Array) if entity_source != "FIXTURE" else (fixture.get("entities", []) as Array)
	var manifest_entries := manifest.get("entries", []) as Array
	var entries_by_model := {}
	for value in manifest_entries:
		if value is Dictionary:
			var entry := value as Dictionary
			entries_by_model[str(int(entry.get("model_id", -1)))] = entry
	var prop_entries_by_model := {}
	var raw_prop_entries: Variant = prop_manifest.get("entries", {})
	if raw_prop_entries is Dictionary:
		for key in raw_prop_entries as Dictionary:
			var prop_value: Variant = (raw_prop_entries as Dictionary)[key]
			if prop_value is Dictionary:
				prop_entries_by_model[str(int((prop_value as Dictionary).get("model_id", int(str(key)))))] = prop_value

	var player := _find_player(entities)
	if player.is_empty():
		last_report = {"ok": false, "error": "captured_player_missing", "source_entity_count": entities.size()}
		return last_report

	var zone_id := int(overrides.get("zone", 51))
	var region_id := int(overrides.get("region", 51))
	var world_origin_x := float(overrides.get("world_origin_x", 491520.0))
	var world_origin_y := float(overrides.get("world_origin_y", 491520.0))
	var source_units_per_meter := float(overrides.get("source_units_per_meter", 100.0))
	var show_ready_labels := bool(overrides.get("show_ready_labels", false))
	var show_fallback_labels := bool(overrides.get("show_fallback_labels", true))
	var play_animations := bool(overrides.get("play_default_animations", true))
	var culling_distance_m := float(overrides.get("culling_distance_m", 80.0))
	var culling_distance_raw := culling_distance_m * source_units_per_meter

	root = Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("offline_only", true)
	root.set_meta("network_access_performed", false)
	root.set_meta("fixture_path", fixture_path)
	root.set_meta("manifest_path", manifest_path)
	root.set_meta("prop_manifest_path", prop_manifest_path)
	root.set_meta("zone_id", zone_id)
	root.set_meta("region_id", region_id)
	root.set_meta("world_origin", Vector2(world_origin_x, world_origin_y))
	host.add_child(root)

	var ready_instances := 0
	var living_scene_instances := 0
	var prop_scene_instances := 0
	var fallback_instances := 0
	var deferred_objects := 0
	var scene_load_failures: Array[int] = []
	var ready_model_counts := {}
	var fallback_model_counts := {}
	var deferred_object_model_counts := {}
	var records: Array[Dictionary] = []
	var stripped_helpers := 0
	var animations_started := 0

	# R2 : le contexte est fige une fois, puis chaque entite passe par la MEME
	# porte - `spawn_one`. Le peuplement en bloc n'est plus qu'une boucle
	# dessus, et le flux vivant appelle exactement la meme fonction. Sans cette
	# porte unique, une entite apparue au paquet 806 serait placee par un autre
	# code que celle du paquet 14, et rien ne garantirait qu'elles se ressemblent.
	_context = {
		"zone_id": zone_id,
		"world_origin_x": world_origin_x,
		"world_origin_y": world_origin_y,
		"source_units_per_meter": source_units_per_meter,
		"show_ready_labels": show_ready_labels,
		"show_fallback_labels": show_fallback_labels,
		"play_animations": play_animations,
		"culling_distance_raw": culling_distance_raw,
		"entries_by_model": entries_by_model,
		"prop_entries_by_model": prop_entries_by_model,
		"player_object_id": int(player.get("object_id", -2)),
	}

	for value in entities:
		if not value is Dictionary:
			continue
		var outcome := spawn_one(host, value as Dictionary)
		match str(outcome.get("outcome", "")):
			"skipped_player", "not_an_entity":
				pass
			"living_scene":
				ready_instances += 1
				living_scene_instances += 1
				_bump(ready_model_counts, outcome)
				stripped_helpers += int(outcome.get("stripped_helpers", 0))
				animations_started += int(outcome.get("animation_started", 0))
				records.append(outcome.get("record", {}) as Dictionary)
			"prop_scene":
				ready_instances += 1
				prop_scene_instances += 1
				_bump(ready_model_counts, outcome)
				stripped_helpers += int(outcome.get("stripped_helpers", 0))
				records.append(outcome.get("record", {}) as Dictionary)
			"fallback":
				if bool(outcome.get("scene_load_failed", false)):
					scene_load_failures.append(int(outcome.get("model_id", -1)))
				fallback_instances += 1
				_bump(fallback_model_counts, outcome)
			"deferred_object":
				deferred_objects += 1
				_bump(deferred_object_model_counts, outcome)

	var player_count := 1
	var accounted := player_count + ready_instances + fallback_instances + deferred_objects
	var grounding_stats := _collect_grounding_stats()
	last_report = {
		"ok": scene_load_failures.is_empty() and accounted == entities.size(),
		"milestone": "P1-20G-D-MAIN-EXPORT",
		"offline_only": true,
		"network_access_performed": false,
		"fixture_path": fixture_path,
		"entity_source": entity_source,
		"manifest_path": manifest_path,
		"prop_manifest_path": prop_manifest_path,
		"zone_id": zone_id,
		"region_id": region_id,
		"zone_name": "Isle of Glass",
		"world_origin": [world_origin_x, world_origin_y],
		"source_entity_count": entities.size(),
		"player_instances": player_count,
		"player_object_id": int(player.get("object_id", -1)),
		"player_world_position": [float(player.get("x", 0.0)), float(player.get("y", 0.0)), float(player.get("z", 0.0))],
		"player_zone_position": [float(player.get("x", 0.0)) - world_origin_x, float(player.get("y", 0.0)) - world_origin_y, float(player.get("z", 0.0))],
		"ready_scene_instances": ready_instances,
		"living_scene_instances": living_scene_instances,
		"prop_scene_instances": prop_scene_instances,
		"prop_registry_model_count": prop_entries_by_model.size(),
		"fallback_instances": fallback_instances,
		"deferred_object_instances": deferred_objects,
		"accounted_entities": accounted,
		"spawned_world_entities": ready_instances + fallback_instances,
		"ready_model_counts": ready_model_counts,
		"fallback_model_counts": fallback_model_counts,
		"deferred_object_model_counts": deferred_object_model_counts,
		"deferred_objects_reason": "aucun" if deferred_objects == 0 else "model_id objects.csv sans scene validee",
		"scene_load_failure_model_ids": scene_load_failures,
		"source_units_per_meter": source_units_per_meter,
		"culling_distance_m": culling_distance_m,
		"stripped_studio_helpers": stripped_helpers,
		"animations_started": animations_started,
		"grounding_enabled": _grounding_enabled,
		"grounding_stats": grounding_stats,
		"records": records,
	}
	# Ne pas deverser les 197 enregistrements dans les logs du F5 : le rapport
	# complet reste disponible par get_gothwaite_population_debug_snapshot().
	print("GOTHWAITE_POPULATION={\"ok\":%s,\"zone\":%d,\"region\":%d,\"source\":%d,\"scenes\":%d,\"fallbacks\":%d,\"props_deferred\":%d}" % [
		str(bool(last_report.get("ok", false))).to_lower(),
		zone_id,
		region_id,
		entities.size(),
		ready_instances,
		fallback_instances,
		deferred_objects,
	])
	return last_report.duplicate(true)


## R2 - LA PORTE UNIQUE. Fait apparaitre une entite et rend sa classification.
##
## `build` en est la boucle ; le flux vivant appelle la meme fonction quand un
## paquet 0xDA/0xD9 arrive. Les deux chemins ne peuvent donc pas diverger, ce
## qui est exactement ce que la suite R2 verifie en comparant le monde bati en
## bloc et le monde bati au fil des paquets.
##
## `outcome` vaut `living_scene`, `prop_scene`, `fallback`, `deferred_object`,
## `skipped_player` ou `not_an_entity`. `deferred_object` ne cree AUCUN noeud :
## c'est un `model_id` d'`objects.csv` sans scene validee, et on refuse de lui
## inventer un remplacant.
func spawn_one(host: Node3D, entity: Dictionary, context: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = context if not context.is_empty() else _context
	if ctx.is_empty() or root == null or not is_instance_valid(root):
		return {"outcome": "not_an_entity", "reason": "aucun contexte de peuplement"}

	var object_id := int(entity.get("object_id", -1))
	if object_id == int(ctx.get("player_object_id", -2)):
		return {"outcome": "skipped_player", "object_id": object_id}

	var model_id := int(entity.get("model_id", -1))
	var model_key := str(model_id)
	var entity_type := str(entity.get("entity_type", ""))
	var entries_by_model: Dictionary = ctx.get("entries_by_model", {})
	var prop_entries_by_model: Dictionary = ctx.get("prop_entries_by_model", {})

	var zone_id := int(ctx.get("zone_id", 51))
	var ox := float(ctx.get("world_origin_x", 491520.0))
	var oy := float(ctx.get("world_origin_y", 491520.0))
	var upm := float(ctx.get("source_units_per_meter", 100.0))
	var culling := float(ctx.get("culling_distance_raw", 8000.0))

	# P1-110 : un AUTRE joueur (0x4B) dont le Lab a deja assemble la scene
	# depuis son CharacterOverview (P1-73, assets/daoc/player/online/online_<nom>)
	# la recoit, avec le facteur racial de son manifeste. Sans scene exportee,
	# le modele de race decide (32/35/61 existent), sinon le cone.
	if entity_type == "player":
		var exported := _exported_player_entry(str(entity.get("name", "")), upm)
		if exported.is_empty():
			exported = _catalog_player_entry(model_id, upm)
		if not exported.is_empty():
			var player_result := _spawn_scene_entity(host, entity, exported, zone_id, ox, oy, upm,
				bool(ctx.get("show_ready_labels", false)), bool(ctx.get("play_animations", true)), culling, "online_export")
			if bool(player_result.get("ok", false)):
				return {"outcome": "living_scene", "object_id": object_id, "model_id": model_id, "exported_player_scene": str(exported.get("scene", "")),
					"stripped_helpers": int(player_result.get("stripped_helpers", 0)), "animation_started": int(player_result.get("animation_started", 0)),
					"record": player_result.get("record", {})}

	# force_catalog : un PNJ qui recoit un 0x15 est remonte sur la base de race.
	if entries_by_model.has(model_key) and not bool(entity.get("force_catalog", false)):
		var result := _spawn_scene_entity(
			host, entity, entries_by_model[model_key] as Dictionary,
			zone_id, ox, oy, upm,
			bool(ctx.get("show_ready_labels", false)), bool(ctx.get("play_animations", true)),
			culling, "living"
		)
		if bool(result.get("ok", false)):
			return {
				"outcome": "living_scene", "object_id": object_id, "model_id": model_id,
				"stripped_helpers": int(result.get("stripped_helpers", 0)),
				"animation_started": int(result.get("animation_started", 0)),
				"record": result.get("record", {}),
			}
		_spawn_fallback_entity(host, entity, zone_id, ox, oy,
			bool(ctx.get("show_fallback_labels", true)), culling)
		return {"outcome": "fallback", "object_id": object_id, "model_id": model_id,
			"scene_load_failed": true}

	if entity_type == "object" and prop_entries_by_model.has(model_key):
		var prop_result := _spawn_scene_entity(
			host, entity, prop_entries_by_model[model_key] as Dictionary,
			zone_id, ox, oy, upm,
			bool(ctx.get("show_ready_labels", false)), false,
			culling, "objects.csv"
		)
		if bool(prop_result.get("ok", false)):
			return {
				"outcome": "prop_scene", "object_id": object_id, "model_id": model_id,
				"stripped_helpers": int(prop_result.get("stripped_helpers", 0)),
				"record": prop_result.get("record", {}),
			}
		_spawn_fallback_entity(host, entity, zone_id, ox, oy,
			bool(ctx.get("show_fallback_labels", true)), culling)
		return {"outcome": "fallback", "object_id": object_id, "model_id": model_id,
			"scene_load_failed": true}

	if entity_type == "object":
		return {"outcome": "deferred_object", "object_id": object_id, "model_id": model_id}

	# 2026-09-29 (serveur DOL local) : un PNJ humanoide dont le modele est une
	# race jouable absente du manifeste (marchand / entraineur Avalonien 62)
	# recoit la base nue du catalogue, comme un autre joueur (P1-120).
	if entity_type == "npc":
		var catalog := _catalog_player_entry(model_id, upm)
		if not catalog.is_empty():
			var npc_result := _spawn_scene_entity(host, entity, catalog, zone_id, ox, oy, upm,
				bool(ctx.get("show_ready_labels", false)), bool(ctx.get("play_animations", true)), culling, "catalog_npc")
			if bool(npc_result.get("ok", false)):
				return {"outcome": "living_scene", "object_id": object_id, "model_id": model_id,
					"catalog_scene": str(catalog.get("scene", "")),
					"stripped_helpers": int(npc_result.get("stripped_helpers", 0)),
					"animation_started": int(npc_result.get("animation_started", 0)),
					"record": npc_result.get("record", {})}

	_spawn_fallback_entity(host, entity, zone_id, ox, oy,
		bool(ctx.get("show_fallback_labels", true)), culling)
	return {"outcome": "fallback", "object_id": object_id, "model_id": model_id,
		"scene_load_failed": false}


const SERVER_NOMINAL_SIZE := 50.0


static func _server_size_factor(entity: Dictionary) -> float:
	var size := int(entity.get("size", 0))
	if size <= 0:
		return 1.0
	return float(size) / SERVER_NOMINAL_SIZE


## R2 - deplace une entite deja presente, en coordonnees de ZONE.
##
## Le paquet `0xA1` porte `zone_x/zone_y/zone_z`, pas les coordonnees MONDE du
## paquet de creation : il n'y a donc aucune origine a soustraire ici. Confondre
## les deux placerait l'entite a 491 520 unites de sa vraie position.
func move_one(host: Node3D, object_id: int, zone_x: float, zone_y: float, zone_z: float,
		heading: int, context: Dictionary = {}) -> Dictionary:
	var wrapper: Node3D = wrapper_of(object_id)
	if wrapper == null:
		return {"ok": false, "reason": "entite absente", "object_id": object_id}

	# Le contexte de l'appelant COMPLETE celui du peuplement (zone, origine) : un
	# appelant qui ne passe que « smooth » ne doit pas perdre la zone.
	# Copie SUPERFICIELLE : le contexte porte tout le catalogue de modeles, et un
	# duplicate(true) par deplacement le recopiait a chaque 0xA1 du serveur.
	var ctx: Dictionary = _context.duplicate(false)
	for key in context.keys():
		ctx[key] = context[key]
	var zone_id := int(ctx.get("zone_id", 51))
	var entity := {
		"object_id": object_id,
		"entity_type": str(wrapper.get_meta("daoc_entity_type", "")),
		"model_id": int(wrapper.get_meta("daoc_model_id", -1)),
		"flags": {"flying": bool(wrapper.get_meta("daoc_flying", false))},
	}
	var grounding := _resolve_vertical_placement(host, entity, zone_id, zone_x, zone_y, zone_z)
	var placement_z := float(grounding.get("z", zone_z))

	var target := _to_godot(host, zone_id, zone_x, zone_y, placement_z)
	var yaw := heading_to_yaw(heading)
	# 2026-09-15 : en ligne, un 0xA1 est une DESTINATION, pas une teleportation.
	# Observe en live : les PNJ sautaient de A a D sans passer par B et C. Avec
	# `smooth`, le noeud glisse vers la cible a la vitesse du paquet (unites DAoC
	# par seconde) dans advance_motions ; l'arbitre, lui, prend la position tout
	# de suite. Un saut trop grand pour etre une marche reste une teleportation.
	if bool(ctx.get("smooth", false)):
		# 2026-09-16 : estime a l'avance (« dead reckoning »), comme le client
		# d'origine. SendObjectUpdate porte la position ACTUELLE du PNJ et sa
		# DESTINATION ; entre deux paquets (5 s par defaut sur OpenDAoC) le
		# client marche seul de l'une vers l'autre a `speed`. Glisser vers la
		# position du paquet, comme avant, revenait a viser un point deja
		# depasse : le PNJ trainait derriere, puis sautait.
		var speed_raw := float(ctx.get("speed", 0.0))
		var scale := float(host.get("world_scale")) if host.get("world_scale") != null else 1.0
		var distance_to_packet := wrapper.position.distance_to(target)
		var dest_x := float(ctx.get("target_zone_x", 0.0))
		var dest_y := float(ctx.get("target_zone_y", 0.0))
		var has_destination := speed_raw > 0.0 and (dest_x != 0.0 or dest_y != 0.0) \
			and (absf(dest_x - zone_x) > 1.0 or absf(dest_y - zone_y) > 1.0)
		if has_destination:
			# La position du paquet est autoritaire : on s'y recale si l'on a
			# derive de plus d'une demi-seconde de marche, sinon on garde la
			# continuite visuelle et on repart vers la destination.
			if distance_to_packet > maxf(speed_raw * 0.5, 64.0) * scale:
				wrapper.position = target
			var dest_z := float(ctx.get("target_zone_z", zone_z))
			var dest_ground := _resolve_vertical_placement(host, entity, zone_id, dest_x, dest_y, dest_z)
			var destination := _to_godot(host, zone_id, dest_x, dest_y, float(dest_ground.get("z", dest_z)))
			_motions[object_id] = {"target": destination, "yaw": yaw, "speed": speed_raw * scale, "speed_raw": speed_raw}
		elif distance_to_packet > 0.001:
			# Arret : on rejoint la position finale en marchant si elle est
			# proche, sinon c'est une vraie teleportation serveur.
			var snap_distance := MAX_SMOOTH_DISTANCE_RAW * scale
			if distance_to_packet > snap_distance:
				wrapper.position = target
				wrapper.rotation.y = yaw
				_motions.erase(object_id)
			else:
				_motions[object_id] = {"target": target, "yaw": yaw, "speed": DEFAULT_MOVE_SPEED_RAW * scale, "speed_raw": DEFAULT_MOVE_SPEED_RAW}
		else:
			wrapper.rotation.y = yaw
			_motions.erase(object_id)
	else:
		wrapper.position = target
		wrapper.rotation.y = yaw
	wrapper.set_meta("daoc_zone_position", Vector3(zone_x, zone_y, zone_z))
	wrapper.set_meta("daoc_grounding_z", placement_z)
	wrapper.set_meta("daoc_grounding_method", str(grounding.get("method", "source_z")))
	return {
		"ok": true, "object_id": object_id,
		"zone_position": [zone_x, zone_y, zone_z],
		"grounding_method": str(grounding.get("method", "source_z")),
	}


## Vitesse par defaut quand le paquet dit 0 mais que la position a change :
## la marche DAoC (unites/s). Au-dela de MAX_SMOOTH_DISTANCE_RAW on teleporte.
const DEFAULT_MOVE_SPEED_RAW := 190.0
const MAX_SMOOTH_DISTANCE_RAW := 2500.0
var _motions: Dictionary = {}


## Fait glisser les entites en mouvement vers leur destination. A appeler a
## chaque trame par l'hote (en ligne). Rend le nombre d'entites encore en route.
## P1-80 — un PNJ qui se deplace joue `walk` ou `run` (clips exportes par le
## Lab pour toutes les scenes modernes et le rat), et revient a son clip par
## defaut a l'arret. Seuil course / marche en unites DAoC par seconde, le meme
## que celui du joueur (DaocPlayerVisualRuntime.run_threshold_raw = 900 par
## defaut ; les PNJ d'OpenDAoC courent a ~ 200-300, marchent a ~ 100-150 : c'est
## donc la VITESSE DU PAQUET qui decide, pas une regle client). Une creature en
## train de mourir n'est jamais relevee.
var npc_run_threshold_raw: float = 200.0


func advance_motions(delta: float) -> int:
	if _motions.is_empty():
		return 0
	for object_id in _motions.keys():
		var wrapper: Node3D = wrapper_of(int(object_id))
		var motion: Dictionary = _motions[object_id] as Dictionary
		if wrapper == null:
			_motions.erase(object_id)
			continue
		var target: Vector3 = motion["target"] as Vector3
		var step := float(motion["speed"]) * maxf(delta, 0.0)
		var remaining := wrapper.position.distance_to(target)
		wrapper.rotation.y = float(motion["yaw"])
		if not bool(motion.get("clip_started", false)):
			motion["clip_started"] = true
			var speed_raw := float(motion.get("speed_raw", 0.0))
			_play_locomotion(wrapper, "run" if speed_raw >= npc_run_threshold_raw else "walk")
		if remaining <= step or step <= 0.0:
			wrapper.position = target
			_motions.erase(object_id)
			_play_locomotion(wrapper, str(wrapper.get_meta("daoc_default_animation", "idle")))
		else:
			wrapper.position += (target - wrapper.position) / remaining * step
	return _motions.size()


func _play_locomotion(wrapper: Node3D, clip_name: String) -> bool:
	var player := _find_animation_player(wrapper)
	if player == null or clip_name == "":
		return false
	if player.current_animation == "death" or player.current_animation == clip_name:
		return false
	if not player.has_animation(clip_name):
		# Sans clip de marche, on ne remplace rien : la scene glisse, comme avant.
		return false
	player.play(clip_name)
	return true


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func motions_in_progress() -> int:
	return _motions.size()


## R2 - retire une entite du monde.
##
## AUCUN paquet de la capture P1-20D ne declenche ce chemin : le flux ne porte
## ni opcode de suppression, ni decodeur pour un tel opcode. Il est donc ecrit
## et teste par un evenement SYNTHETIQUE, jamais valide contre du serveur reel.
## Ne pas presenter ce chemin comme prouve tant qu'une capture ne porte pas de
## retrait observe.
func despawn_one(object_id: int) -> bool:
	var wrapper: Node3D = wrapper_of(object_id)
	if wrapper == null:
		return false
	_by_object_id.erase(object_id)
	var parent := wrapper.get_parent()
	if parent != null:
		parent.remove_child(wrapper)
	wrapper.queue_free()
	return true


## Retrouve le noeud d'une entite. L'index est tenu a l'apparition ; sans lui il
## faudrait balayer les 307 enfants a chaque paquet de deplacement.
## P1-110 — la scene exportee par le Lab pour un personnage serveur, et son
## echelle : `scale_contract.visual_scale_for_target` du manifeste (celle que
## DaocGameWorld donne au joueur local pour la meme scene), ramenee au
## `display_scale` que _spawn_scene_entity multiplie par les unites par metre.
static func _exported_player_entry(name: String, source_units_per_meter: float) -> Dictionary:
	if name.strip_edges() == "":
		return {}
	var scene_path := "res://assets/daoc/player/online/online_%s.tscn" % name.to_lower().validate_filename()
	if not ResourceLoader.exists(scene_path):
		return {}
	var visual_scale := 1.0
	var manifest_path := scene_path.get_basename() + ".manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			var contract: Variant = (manifest as Dictionary).get("scale_contract", {})
			if contract is Dictionary and float((contract as Dictionary).get("visual_scale_for_target", 0.0)) > 0.0:
				visual_scale = float((contract as Dictionary).get("visual_scale_for_target", 1.0))
	return {"scene": scene_path, "display_scale": visual_scale / maxf(source_units_per_meter, 0.0001), "default_animation": "idle",
		"label": "online export %s" % name, "registry_source": "ONLINE_EXPORT"}


## Un autre joueur sans scene exportee : la base nue du catalogue de sa race,
## deduite du modele 0x4B. Son 0x15 l'habille ensuite piece par piece.
static func _catalog_player_entry(model_id: int, source_units_per_meter: float) -> Dictionary:
	var scene_path := DaocPlayerCatalogAppearance.base_scene_for(
		DaocPlayerCatalogAppearance.appearance_for_model(model_id))
	if scene_path == "":
		return {}
	var visual_scale := DaocPlayerCatalogAppearance.visual_scale_for_scene(scene_path)
	if visual_scale <= 0.0:
		visual_scale = 1.0
	return {"scene": scene_path, "display_scale": visual_scale / maxf(source_units_per_meter, 0.0001), "default_animation": "idle",
		"label": "catalogue %s" % scene_path.get_file().get_basename(), "registry_source": "CATALOG_BASE"}


func wrapper_of(object_id: int) -> Node3D:
	if not _by_object_id.has(object_id):
		return null
	var node: Variant = _by_object_id[object_id]
	if not is_instance_valid(node):
		_by_object_id.erase(object_id)
		return null
	return node as Node3D


func live_object_ids() -> Array:
	var out: Array = []
	for object_id: int in _by_object_id.keys():
		if is_instance_valid(_by_object_id[object_id]):
			out.append(object_id)
	out.sort()
	return out


## Ouvre une session de peuplement VIDE, prete a recevoir un flux. C'est le
## `t=0` que R2 introduit : le monde commence sans personne, au lieu de naitre
## deja peuple.
func begin_stream(host: Node3D, manifest_path: String, overrides: Dictionary = {}) -> Dictionary:
	return build(host, "", manifest_path, _with_empty_entities(overrides))


static func _with_empty_entities(overrides: Dictionary) -> Dictionary:
	var out := overrides.duplicate(true)
	out["entities"] = [_stream_placeholder_player(overrides)]
	out["entity_source"] = "STREAM"
	return out


## `build` exige un joueur pour son rapport. En mode flux il n'est pas encore
## arrive : on reprend celui que l'appelant declare, sinon un marqueur inerte
## qui ne fait apparaitre aucun noeud.
static func _stream_placeholder_player(overrides: Dictionary) -> Dictionary:
	var declared: Variant = overrides.get("stream_player", null)
	if declared is Dictionary:
		return declared as Dictionary
	return {"object_id": -1, "entity_type": "player", "model_id": -1, "x": 0.0, "y": 0.0, "z": 0.0}


static func _bump(counts: Dictionary, outcome: Dictionary) -> void:
	var key := str(int(outcome.get("model_id", -1)))
	counts[key] = int(counts.get(key, 0)) + 1


func clear(host: Node3D) -> void:
	var previous := host.get_node_or_null(ROOT_NAME)
	if previous != null:
		host.remove_child(previous)
		previous.free()
	root = null
	last_report = {}
	_by_object_id.clear()
	_context = {}


static func heading_to_yaw(heading: int) -> float:
	# P1-112 : cap DOL -> lacet Godot par DaocHeading (+90 degres, mesure en live).
	return DaocHeadingScript.raw_to_godot_yaw(heading)


## Scenes conservees en memoire par chemin. Mesure le 2026-09-16 : une scene
## `.tscn` du showcase (3,6 Mo de texte, images incluses) coute ~255 ms a
## charger, et le cache de ResourceLoader la lache des que plus personne ne la
## reference — une instance vivante ne compte pas. Chaque apparition rechargeait
## donc le fichier, y compris pour un modele deja a l'ecran : 1,3 s par PNJ,
## 250 s pour Gothwaite. Le client d'origine appelle ca « Precache Skins ».
var _packed_scenes: Dictionary = {}
## Dossier des copies BINAIRES des scenes du showcase (tools/convert_npc_scenes_to_binary.gd) :
## 6 ms au lieu de 255. Facultatif : sans lui, la scene texte du manifeste est lue.
const BINARY_SCENE_DIR := "res://generated/npc_scenes_bin/"


func _packed_scene_for(scene_path: String) -> PackedScene:
	if _packed_scenes.has(scene_path):
		return _packed_scenes[scene_path] as PackedScene
	var packed: PackedScene = null
	var binary_path := BINARY_SCENE_DIR + scene_path.trim_prefix("res://").get_basename().replace("/", "_") + ".scn"
	if ResourceLoader.exists(binary_path):
		packed = load(binary_path) as PackedScene
	if packed == null:
		packed = load(scene_path) as PackedScene
	if packed != null:
		_packed_scenes[scene_path] = packed
	return packed


## Charge d'avance les scenes d'une liste d'entites (ou de tout le manifeste si
## la liste est vide), pour que les apparitions ne payent plus le disque.
func precache_scenes(entities: Array = []) -> Dictionary:
	var started := Time.get_ticks_msec()
	var wanted: Dictionary = {}
	var entries_by_model: Dictionary = _context.get("entries_by_model", {})
	var prop_entries_by_model: Dictionary = _context.get("prop_entries_by_model", {})
	if entities.is_empty():
		for entry in entries_by_model.values():
			wanted[str((entry as Dictionary).get("scene", ""))] = true
	else:
		for value in entities:
			if not value is Dictionary:
				continue
			var key := str(int((value as Dictionary).get("model_id", -1)))
			var registry: Dictionary = entries_by_model if entries_by_model.has(key) else prop_entries_by_model
			if registry.has(key):
				wanted[str((registry[key] as Dictionary).get("scene", ""))] = true
	wanted.erase("")
	var loaded := 0
	for path in wanted.keys():
		if _packed_scene_for(path) != null:
			loaded += 1
	return {"ok": true, "scenes": wanted.size(), "loaded": loaded, "elapsed_msec": Time.get_ticks_msec() - started}


func _spawn_scene_entity(
	host: Node3D,
	entity: Dictionary,
	entry: Dictionary,
	zone_id: int,
	world_origin_x: float,
	world_origin_y: float,
	source_units_per_meter: float,
	show_label: bool,
	play_animation: bool,
	culling_distance_raw: float,
	registry: String
) -> Dictionary:
	var scene_path := str(entry.get("scene", ""))
	var packed := _packed_scene_for(scene_path)
	if packed == null:
		return {"ok": false}
	var visual := packed.instantiate() as Node3D
	# Sens des faces (P1-90) : sans cela, un PNJ aux materiaux cull_disabled est
	# eclaire par l interieur et ne recoit aucune ombre.
	preload("res://src/daoc/assets/DaocMeshWindingFix.gd").apply(visual)
	if visual == null:
		return {"ok": false}
	var wrapper := _make_wrapper(host, entity, zone_id, world_origin_x, world_origin_y)
	root.add_child(wrapper)
	wrapper.add_child(visual)
	wrapper.set_meta("daoc_scene_registry", registry)
	visual.name = "Visual"
	var stripped := _strip_studio_helpers(visual)
	# P1-94 : le byte `size` du 0xDA (50 = taille nominale, DOL GameNPC.Size)
	# etait decode depuis P1-20E et jamais applique : un rat des neiges a 8
	# s'affichait comme un chien. Confronte au client officiel le 2026-09-21.
	# 0 = non renseigne -> nominal, comme le client d'origine.
	var runtime_scale := float(entry.get("display_scale", 0.02)) * source_units_per_meter * _server_size_factor(entity)
	# P1-110 : l echelle nominale (taille serveur 50) sert au 0xDB ModelChange.
	visual.set_meta("daoc_runtime_scale_nominal", float(entry.get("display_scale", 0.02)) * source_units_per_meter)
	visual.scale = Vector3.ONE * runtime_scale
	var grounding_method := str(wrapper.get_meta("daoc_grounding_method", "source_z"))
	var preserve_pivot := grounding_method == "water_surface" or (registry == "objects.csv" and grounding_method == "source_z")
	var anchor_contract := "water_pivot_z" if grounding_method == "water_surface" else ("server_pivot_z" if preserve_pivot else "support_visual_base")
	if not preserve_pivot:
		_align_visual_base(visual, wrapper, entry)
	else:
		# Un bateau coupe la surface avec son pivot NIF ; aligner le bas de sa
		# coque sur l'eau poserait le navire entier au-dessus de la surface.
		visual.position = Vector3.ZERO
	wrapper.set_meta("daoc_anchor_contract", anchor_contract)
	wrapper.set_meta("daoc_runtime_visual_scale", runtime_scale)
	_apply_visibility_range(visual, culling_distance_raw)
	var animation_started := play_animation and _play_animation(visual, str(entry.get("default_animation", "")))
	wrapper.set_meta("daoc_default_animation", str(entry.get("default_animation", "")))
	if show_label:
		_add_label(wrapper, entity, str(entry.get("status", "READY")), 250.0)
	var record := {
		"object_id": int(entity.get("object_id", -1)),
		"entity_type": str(entity.get("entity_type", "")),
		"name": str(entity.get("name", "")),
		"model_id": int(entity.get("model_id", -1)),
		"status": str(entry.get("status", "UNKNOWN")),
		"scene": scene_path,
		"registry": registry,
		"runtime_visual_scale": runtime_scale,
		"vertical_anchor": anchor_contract,
		"grounding_method": grounding_method,
		"grounding_z": float(wrapper.get_meta("daoc_grounding_z", entity.get("z", 0.0))),
		"source_position": [float(entity.get("x", 0.0)), float(entity.get("y", 0.0)), float(entity.get("z", 0.0))],
		"zone_position": [float(entity.get("x", 0.0)) - world_origin_x, float(entity.get("y", 0.0)) - world_origin_y, float(entity.get("z", 0.0))],
		"godot_position": [wrapper.position.x, wrapper.position.y, wrapper.position.z],
		"heading": int(entity.get("heading", 0)),
		"yaw_radians": wrapper.rotation.y,
	}
	return {"ok": true, "record": record, "stripped_helpers": stripped, "animation_started": 1 if animation_started else 0}


func _spawn_fallback_entity(host: Node3D, entity: Dictionary, zone_id: int, world_origin_x: float, world_origin_y: float, show_label: bool, culling_distance_raw: float) -> void:
	var wrapper := _make_wrapper(host, entity, zone_id, world_origin_x, world_origin_y)
	root.add_child(wrapper)
	var marker := MeshInstance3D.new()
	marker.name = "FallbackMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 9.0
	mesh.bottom_radius = 16.0
	mesh.height = 72.0
	mesh.radial_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = _fallback_color(int(entity.get("model_id", -1)))
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.28
	mesh.material = material
	marker.mesh = mesh
	marker.position.y = 36.0
	marker.visibility_range_end = culling_distance_raw
	wrapper.add_child(marker)
	if show_label:
		_add_label(wrapper, entity, "FALLBACK", 105.0)


func _make_wrapper(host: Node3D, entity: Dictionary, zone_id: int, world_origin_x: float, world_origin_y: float) -> Node3D:
	var object_id := int(entity.get("object_id", -1))
	var model_id := int(entity.get("model_id", -1))
	var local_x := float(entity.get("x", 0.0)) - world_origin_x
	var local_y := float(entity.get("y", 0.0)) - world_origin_y
	var source_z := float(entity.get("z", 0.0))
	var grounding := _resolve_vertical_placement(host, entity, zone_id, local_x, local_y, source_z)
	var placement_z := float(grounding.get("z", source_z))
	var wrapper := Node3D.new()
	wrapper.name = "Entity_%d_Model_%d" % [object_id, model_id]
	wrapper.position = _to_godot(host, zone_id, local_x, local_y, placement_z)
	wrapper.rotation.y = heading_to_yaw(int(entity.get("heading", 0)))
	wrapper.set_meta("daoc_object_id", object_id)
	wrapper.set_meta("daoc_model_id", model_id)
	wrapper.set_meta("daoc_entity_name", str(entity.get("name", "")))
	wrapper.set_meta("daoc_entity_guild", str(entity.get("guild_name", "")))
	wrapper.set_meta("daoc_entity_size", int(entity.get("size", 0)))
	wrapper.set_meta("daoc_entity_heading", int(entity.get("heading", 0)))
	wrapper.set_meta("daoc_world_position", Vector3(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)), source_z))
	wrapper.set_meta("daoc_zone_position", Vector3(local_x, local_y, source_z))
	wrapper.set_meta("daoc_grounding_z", placement_z)
	wrapper.set_meta("daoc_grounding_method", str(grounding.get("method", "source_z")))
	wrapper.set_meta("daoc_flying", bool((entity.get("flags", {}) as Dictionary).get("flying", false)))
	# R2 : l'entite doit rester retrouvable par son identifiant serveur, sinon
	# un paquet de deplacement n'a aucune cible.
	wrapper.set_meta("daoc_entity_type", str(entity.get("entity_type", "")))
	if object_id >= 0:
		_by_object_id[object_id] = wrapper
	return wrapper


func _resolve_vertical_placement(host: Node3D, entity: Dictionary, zone_id: int, local_x: float, local_y: float, source_z: float) -> Dictionary:
	if not _grounding_enabled or not host.has_method("sample_daoc_floor_z"):
		return {"z": source_z, "method": "source_z"}
	var flags: Dictionary = entity.get("flags", {}) as Dictionary
	if bool(flags.get("flying", false)):
		return {"z": source_z, "method": "flying_source_z"}
	var floor_z := float(host.call("sample_daoc_floor_z", zone_id, local_x, local_y, source_z))
	if str(entity.get("entity_type", "")) == "object" and int(entity.get("model_id", -1)) in WATER_PROP_MODEL_IDS:
		if host.has_method("sample_daoc_water_info"):
			# Le Z D9 des bateaux est au-dessus de l'eau dans la capture. Passer le
			# sol comme altitude de requete permet de retrouver le plan d'eau local.
			var water := host.call("sample_daoc_water_info", zone_id, local_x, local_y, floor_z) as Dictionary
			if not water.is_empty() and water.has("height"):
				return {"z": float(water.get("height", floor_z)), "method": "water_surface"}
	return {"z": floor_z, "method": "terrain"}


func refine_living_supports(host: Node3D, options: Dictionary = {}) -> Dictionary:
	if root == null or not is_instance_valid(root) or host == null or not _grounding_enabled:
		return last_report.duplicate(true)
	var world := host.get_world_3d()
	if world == null:
		return last_report.duplicate(true)
	var scale_y := float(host.get("world_scale")) * float(host.get("height_exaggeration"))
	var probe_above := float(options.get("probe_above_raw", 128.0)) * scale_y
	var probe_below := float(options.get("probe_below_raw", 4096.0)) * scale_y
	var tolerance := float(options.get("source_tolerance_raw", 256.0)) * scale_y
	var collision_mask := int(options.get("collision_mask", 5))
	var refined := 0
	for child in root.get_children():
		var wrapper := child as Node3D
		if wrapper == null or bool(wrapper.get_meta("daoc_flying", false)):
			continue
		if str(wrapper.get_meta("daoc_scene_registry", "fallback")) == "objects.csv":
			continue
		var zone_pos := wrapper.get_meta("daoc_zone_position", Vector3.ZERO) as Vector3
		var source_global := _to_godot(host, int(last_report.get("zone_id", 51)), zone_pos.x, zone_pos.y, zone_pos.z)
		var from := wrapper.global_position
		from.y = maxf(source_global.y, wrapper.global_position.y) + probe_above
		var to := wrapper.global_position - Vector3(0.0, probe_below, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal := hit.get("normal", Vector3.UP) as Vector3
		var hit_position := hit.get("position", wrapper.global_position) as Vector3
		if normal.normalized().dot(Vector3.UP) < 0.64:
			continue
		# Une surface proche du Z serveur est un vrai ponton/plancher. Un impact
		# beaucoup plus bas confirme au contraire que l'entite devait rester sur
		# le terrain deja choisi par la premiere passe.
		if absf(hit_position.y - source_global.y) > tolerance:
			continue
		var global_pos := wrapper.global_position
		global_pos.y = hit_position.y
		wrapper.global_position = global_pos
		wrapper.set_meta("daoc_grounding_method", "collision_support")
		refined += 1
	last_report["collision_support_refined"] = refined
	last_report["grounding_stats"] = _collect_grounding_stats()
	return last_report.duplicate(true)


func _collect_grounding_stats() -> Dictionary:
	var stats := {}
	if root == null:
		return stats
	for child in root.get_children():
		var method := str(child.get_meta("daoc_grounding_method", "unknown"))
		stats[method] = int(stats.get(method, 0)) + 1
	return stats


func _find_player(entities: Array) -> Dictionary:
	for value in entities:
		if value is Dictionary:
			var entity := value as Dictionary
			if str(entity.get("name", "")).to_lower() == "heyveno" or str(entity.get("entity_type", "")) == "player":
				return entity
	return {}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _to_godot(host: Node3D, zone_id: int, local_x: float, local_y: float, source_z: float) -> Vector3:
	if host.has_method("daoc_to_godot"):
		return host.call("daoc_to_godot", zone_id, local_x, local_y, source_z) as Vector3
	return Vector3(local_x, source_z, local_y)


func _strip_studio_helpers(node: Node) -> int:
	var removed := 0
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is WorldEnvironment or str(child.name) == "ReferenceGround":
			node.remove_child(child)
			child.free()
			removed += 1
		else:
			removed += _strip_studio_helpers(child)
	return removed


func _align_visual_base(visual: Node3D, wrapper: Node3D, entry: Dictionary) -> void:
	if entry.has("base_offset_native"):
		visual.position.y -= float(entry["base_offset_native"]) * visual.scale.y
		return
	if visual.has_meta("daoc_skinned_aabb_position"):
		visual.position.y -= (visual.get_meta("daoc_skinned_aabb_position") as Vector3).y * visual.scale.y
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	var min_y := INF
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		var to_wrapper := _transform_to_ancestor(mesh_instance, wrapper)
		for corner_index in 8:
			var corner := Vector3(
				aabb.position.x + (aabb.size.x if (corner_index & 1) != 0 else 0.0),
				aabb.position.y + (aabb.size.y if (corner_index & 2) != 0 else 0.0),
				aabb.position.z + (aabb.size.z if (corner_index & 4) != 0 else 0.0)
			)
			min_y = minf(min_y, (to_wrapper * corner).y)
	if is_finite(min_y):
		visual.position.y -= min_y


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _apply_visibility_range(node: Node, distance_raw: float) -> void:
	if distance_raw <= 0.0:
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = distance_raw
	for child in node.get_children():
		_apply_visibility_range(child, distance_raw)


func _play_animation(node: Node, animation_name: String) -> bool:
	if animation_name.is_empty():
		return false
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		if player.has_animation(animation_name):
			player.play(animation_name)
			return true
	for child in node.get_children():
		if _play_animation(child, animation_name):
			return true
	return false


func _add_label(wrapper: Node3D, entity: Dictionary, status: String, height: float) -> void:
	var label := Label3D.new()
	label.name = "EntityLabel"
	label.text = "%s\nID %d - %s" % [str(entity.get("name", "Sans nom")), int(entity.get("model_id", -1)), status]
	label.position.y = height
	label.font_size = 32
	label.outline_size = 8
	label.pixel_size = 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	wrapper.add_child(label)


func _transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var current := node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _fallback_color(model_id: int) -> Color:
	var hue := fmod(float(abs(model_id) * 37), 360.0) / 360.0
	return Color.from_hsv(hue, 0.55, 0.95)


## P1-110 — 0xDB ModelChange : une TAILLE change (u32 taille, 50 = nominale,
## 0 = inchangee) sans changer de modele. Le visuel est rescale depuis son
## echelle nominale ; un modele qui change passe par despawn + spawn_one
## (DaocGameWorld._on_online_model_changed).
func resize_one(object_id: int, size: int) -> bool:
	var wrapper: Node3D = wrapper_of(object_id)
	if wrapper == null or size <= 0:
		return false
	var visual: Node3D = wrapper.get_node_or_null("Visual") as Node3D
	if visual == null or not visual.has_meta("daoc_runtime_scale_nominal"):
		# Un cone de repli : on rescale le marqueur lui-meme.
		var marker: Node3D = wrapper.get_node_or_null("FallbackMarker") as Node3D
		if marker == null:
			return false
		marker.scale = Vector3.ONE * (float(size) / SERVER_NOMINAL_SIZE)
		return true
	visual.scale = Vector3.ONE * float(visual.get_meta("daoc_runtime_scale_nominal")) * (float(size) / SERVER_NOMINAL_SIZE)
	return true


## P1-110 — l icone de quete au-dessus d un PNJ (0x4C sous-code 0x07) : un
## Label3D « ! » (disponible), « ? » (a rendre)... au-dessus du corps ; un
## indicateur nul la retire.
func set_quest_indicator(object_id: int, glyph: String) -> bool:
	var wrapper: Node3D = wrapper_of(object_id)
	if wrapper == null:
		return false
	var existing: Label3D = wrapper.get_node_or_null("QuestIndicator") as Label3D
	if glyph == "":
		if existing != null:
			existing.queue_free()
		return true
	if existing == null:
		existing = Label3D.new()
		existing.name = "QuestIndicator"
		existing.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		existing.no_depth_test = true
		existing.font_size = 96
		existing.pixel_size = 0.6
		existing.modulate = Color(1.0, 0.85, 0.2)
		existing.outline_modulate = Color(0.1, 0.05, 0.0)
		existing.outline_size = 12
		existing.position = Vector3(0.0, 95.0, 0.0)
		wrapper.add_child(existing)
	existing.text = glyph
	return true
