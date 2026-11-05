extends RefCounted
class_name DaocZonePropsStep

## R4 — sixième et dernière tranche : les props quittent le ZoneViewer.
##
## La plus grosse des sept étapes, 122 lignes mesurées avant d'ouvrir R4, et la
## seule qui fasse TROIS choses au lieu d'une : elle prépare le placement de
## chaque fixture, elle bâtit les corps de collision de props au passage, puis
## elle accroche le résultat du constructeur 14D et écrit deux index de session.
##
## Ce qui bouge : la lecture du `zoneXXX_placement.json`, l'ancrage au sol, la
## décision de collision par fixture, l'accrochage sous `StaticPropsRoot` et
## `PropsCollisionRoot`, et l'écriture des index. Ce qui ne bouge PAS :
## `DaocPropBuilder` (14D) et `DaocCollisionBuilder` (14C), qui restent les
## autorités de construction — aucune règle de placement n'est réécrite.
##
## DEUX GARDES EXISTENT ICI, et tous DEUX restent DANS l'étape — comme les
## zonejumps de la tranche 5, et contrairement aux tranches 2, 3 et 4 :
##
##   * `place_real_models` décoché ne s'abstient PAS : il bascule sur les
##     marqueurs cubes, qui passent eux aussi par le constructeur 14D et
##     écrivent le même index. Le remonter en `zone_step_enabled_r4` viderait la
##     zone de ses repères au lieu de les simplifier ;
##   * `generate_prop_collisions` décoché ne construit aucun corps, mais le
##     placement visuel, lui, a toujours lieu.
##
## VERROUILLÉ, et c'est le piège propre à cette étape : une zone SANS fichier de
## placement et SANS fixtures dans son `zoneXXX.json` écrit quand même un
## résultat 14D vide, donc REMPLACE son index au lieu de le laisser tel quel. La
## recharge de zone ouverte par R1 laisserait sinon le runtime de props répondre
## depuis les props de la zone précédente — un obstacle invisible, celui qui a
## l'air de marcher.

const PropBuilderScript = preload("res://src/daoc/DaocPropBuilder.gd")
const PropRuntimeScript = preload("res://src/daoc/DaocPropRuntime.gd")
const CollisionBuilderScript = preload("res://src/daoc/DaocCollisionBuilder.gd")
const CollisionRuntimeScript = preload("res://src/daoc/DaocCollisionRuntime.gd")

## Taille du cube témoin d'un marqueur de fixture, en unités DAoC brutes.
## Valeur historique du repli `place_real_models` décoché, conservée telle quelle.
const MARKER_BOX_RAW := 140.0

## Réglages lus dans l'inspecteur. Rassemblés par l'hôte, jamais devinés ici.
## `hb` et `res` n'y figurent pas : ce sont des données de zone, que l'étape
## reçoit en arguments comme les autres tranches.
const SETTING_KEYS := [
	"place_real_models", "mark_missing", "world_scale", "height_exaggeration",
	"anchor_to_base", "heading_sign", "heading_offset_deg",
	"generate_prop_collisions", "prop_collision_log_decisions",
	"export_missing_models_csv", "brghouse_floor_anchor_offset_raw",
	"speedtree_enabled", "speedtree_units_to_daoc", "speedtree_visible_distance_raw",
]

## Les deux seuls modèles dont le pivot n'est pas au sol : leur géométrie descend
## sous l'origine et le client d'origine les pose par leur PLANCHER. Relevé
## nominatif conservé depuis P1-20G-D — ne pas l'élargir sans mesure.
const FLOOR_ANCHOR_STEMS := ["brghouse", "bridgehouse"]


## Construit les props d'une zone.
##
## `base` est l'origine monde de la zone, telle que l'assembleur l'a calculée ;
## `hb`/`res` accompagnent la signature historique de l'étape et servent au repli
## par marqueurs, qui échantillonne le même relief.
static func build(services: DaocZoneBuildServices, meta: Dictionary, base: Vector3,
		hb: PackedByteArray, res: int, settings: Dictionary,
		log_enabled: bool = false) -> Dictionary:
	if services == null or not services.usable():
		return {"ok": false, "reason": "services indisponibles", "zone": -1}

	var znum := int(meta.get("zone", -1))
	var placement_path: String = services.asset_data_path("zone%03d_placement.json" % znum)

	# Garde n°1 : décoché, on ne s'abstient pas — on bascule sur les marqueurs.
	if not bool(settings.get("place_real_models", true)) or not FileAccess.file_exists(placement_path):
		return _build_markers(services, meta, base, settings)

	var placement_file := FileAccess.open(placement_path, FileAccess.READ)
	var placement_variant: Variant = JSON.parse_string(placement_file.get_as_text())
	placement_file.close()
	if typeof(placement_variant) != TYPE_DICTIONARY:
		push_warning("placement: bad json %s" % placement_path)
		return _build_markers(services, meta, base, settings)

	var placement: Dictionary = placement_variant as Dictionary
	var registry: RefCounted = services.asset_index_registry()
	if registry == null:
		return {"ok": false, "reason": "registre d'assets indisponible", "zone": znum}
	registry.call("ensure_model_index")

	var models: Dictionary = placement.get("models", {}) as Dictionary
	var fixtures: Array = placement.get("fixtures", []) as Array
	var prepared: Array = []
	var collision_counts := {
		"built": 0, "missing_flag_fallback": 0,
		"skipped_no_flag": 0, "skipped_excluded": 0, "skipped_flag_zero": 0,
	}

	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	var anchor_to_base := bool(settings.get("anchor_to_base", true))
	var heading_sign := float(settings.get("heading_sign", 1.0))
	var heading_offset_deg := float(settings.get("heading_offset_deg", 0.0))
	var generate_collisions := bool(settings.get("generate_prop_collisions", false))

	for fixture_raw in fixtures:
		var fixture: Dictionary = fixture_raw as Dictionary
		var nif_id := int(fixture.get("nif", -1))
		var file_name: String = str(models.get(str(nif_id), ""))
		var template: Node3D = registry.call("get_model", file_name) as Node3D
		var placed_scale: float = float(fixture.get("scale", 1.0)) * world_scale
		var wx := float(fixture.get("x", 0.0))
		var wy := float(fixture.get("y", 0.0))
		var h_units := float(fixture.get("z", 0.0))
		var force_floor_anchor := _is_floor_anchor_model(file_name)
		var grounded := int(fixture.get("ground", 0)) == 1 or h_units == 0.0 or force_floor_anchor
		if grounded:
			h_units = services.sample_floor_z(znum, wx, wy, 0.0)
			if force_floor_anchor:
				h_units += float(settings.get("brghouse_floor_anchor_offset_raw", 0.0))
		var pos := base + Vector3(wx * world_scale,
			h_units * world_scale * height_exaggeration,
			wy * world_scale)
		# `ground=1` veut dire « repose SUR le sol ». On ne DESCEND que les modèles
		# qui flottent au-dessus de leur origine (`min_y > 0`) ; jamais l'inverse,
		# sinon les vrais arbres 3D lévitent.
		if grounded and anchor_to_base:
			var min_y := float(registry.call("model_min_y", file_name))
			pos.y -= _ground_anchor_min_y(file_name, min_y) * placed_scale
		var yaw := deg_to_rad(heading_sign * float(fixture.get("a", 0.0)) + heading_offset_deg)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * placed_scale)
		var fixture_id := int(fixture.get("id", 0))
		prepared.append({
			"fixture_id": fixture_id,
			"nif_id": nif_id,
			"file": file_name,
			"template": template,
			"transform": Transform3D(basis, pos),
			"marker_transform": Transform3D(Basis().scaled(Vector3.ONE * placed_scale), pos),
			"position": pos,
			"x": wx,
			"y": wy,
			"z": h_units,
			"a": float(fixture.get("a", 0.0)),
			"scale": float(fixture.get("scale", 1.0)),
			"ground": int(fixture.get("ground", 0)),
			"node_name": "f%d_%s" % [fixture_id, file_name.get_basename()],
			"source": placement_path,
			"missing": template == null,
		})

		if template == null:
			registry.call("record_missing_model", znum, fixture, file_name)
			continue
		# Garde n°2 : sans lui, aucun corps n'est bâti — mais le prop est placé.
		if generate_collisions:
			_build_prop_collision(services, znum, fixture, file_name, template,
				pos, yaw, placed_scale, collision_counts)

	if generate_collisions:
		services.log_step(log_enabled,
			"zone%03d prop collision: %d AABB body/bodies" % [znum, int(collision_counts["built"])])
		services.log_step(log_enabled and bool(settings.get("prop_collision_log_decisions", false)),
			"zone%03d prop collision details: fallback_missing_flag=%d skipped_flag_zero=%d skipped_no_flag=%d skipped_excluded=%d" % [
				znum,
				int(collision_counts["missing_flag_fallback"]),
				int(collision_counts["skipped_flag_zero"]),
				int(collision_counts["skipped_no_flag"]),
				int(collision_counts["skipped_excluded"]),
			])

	var result: RefCounted = PropBuilderScript.build(znum, prepared, {
		"placement_path": placement_path,
		"mark_missing": bool(settings.get("mark_missing", false)),
		"world_scale": world_scale,
		"daoc_client_root": str(registry.call("effective_daoc_root")),
		"speedtree_enabled": bool(settings.get("speedtree_enabled", false)),
		"speedtree_units_to_daoc": float(settings.get("speedtree_units_to_daoc", 12.0)),
		"speedtree_visible_distance_raw": float(settings.get("speedtree_visible_distance_raw", 0.0)),
	})
	register_result(services, znum, result)

	var metrics: Dictionary = result.get("metrics") as Dictionary
	# La trace d'origine était INCONDITIONNELLE : elle le reste. Inventer ici un
	# `log_props` couperait une ligne que quelqu'un lit peut-être.
	print("zone%03d placement: %d placed, %d missing model, %d fixtures [14D builder nodes=%d sig=%s]" % [
		znum,
		int(metrics.get("placed", 0)),
		int(metrics.get("missing", 0)),
		int(metrics.get("fixtures", fixtures.size())),
		int(metrics.get("nodes", 0)),
		str(result.get("index_signature")),
	])
	if bool(settings.get("export_missing_models_csv", false)) and int(metrics.get("missing", 0)) > 0:
		registry.call("write_missing_models_csv")
	services.hud_append("  [%d/%d props]" % [
		int(metrics.get("placed", 0)),
		int(metrics.get("fixtures", fixtures.size())),
	])

	return {
		"ok": true, "built": true, "zone": znum, "markers": false,
		"source_path": placement_path,
		"fixtures": int(metrics.get("fixtures", fixtures.size())),
		"placed": int(metrics.get("placed", 0)),
		"missing": int(metrics.get("missing", 0)),
		"prop_collisions": int(collision_counts["built"]),
		"index_signature": str(result.get("index_signature")),
	}


## Repli par marqueurs cubes : pas de fichier de placement, ou modèles réels
## décochés. Il passe par le MÊME constructeur 14D et écrit le MÊME index — une
## zone en marqueurs reste donc une zone connue du runtime de props.
static func _build_markers(services: DaocZoneBuildServices, meta: Dictionary,
		base: Vector3, settings: Dictionary) -> Dictionary:
	var znum := int(meta.get("zone", -1))
	var fixtures: Array = meta.get("fixtures", []) as Array
	if fixtures.is_empty():
		# Résultat VIDE et non « rien » : voir l'en-tête, c'est ce qui empêche
		# une zone rechargée d'hériter des props de la précédente.
		register_result(services, znum, PropBuilderScript.build(znum, [], {"mark_missing": false}))
		return {"ok": true, "built": false, "zone": znum, "markers": true,
			"reason": "aucune fixture", "fixtures": 0, "placed": 0}

	var world_scale := float(settings.get("world_scale", 1.0))
	var height_exaggeration := float(settings.get("height_exaggeration", 1.0))
	var entries: Array = []
	for fixture_raw in fixtures:
		var fixture: Dictionary = fixture_raw as Dictionary
		var wx := float(fixture.get("x", 0.0))
		var wy := float(fixture.get("y", 0.0))
		var h_units := float(fixture.get("z", 0.0))
		if int(fixture.get("ground", 0)) == 1 or h_units == 0.0:
			h_units = services.sample_floor_z(znum, wx, wy, 0.0)
		var pos := base + Vector3(wx * world_scale,
			h_units * world_scale * height_exaggeration,
			wy * world_scale)
		var fixture_id := int(fixture.get("id", 0))
		entries.append({
			"fixture_id": fixture_id,
			"nif_id": int(fixture.get("nif", -1)),
			"file": "fixture_box",
			"template": _marker_node(world_scale),
			"transform": Transform3D(Basis(), pos),
			"marker_transform": Transform3D(Basis(), pos),
			"position": pos,
			"x": wx,
			"y": wy,
			"z": h_units,
			"a": float(fixture.get("a", 0.0)),
			"scale": float(fixture.get("scale", 1.0)),
			"ground": int(fixture.get("ground", 0)),
			"node_name": "fixture_box_%d" % fixture_id,
			"source": "fallback_meta",
			"missing": false,
		})

	var result: RefCounted = PropBuilderScript.build(znum, entries,
		{"mark_missing": false, "world_scale": world_scale})
	register_result(services, znum, result)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	return {
		"ok": true, "built": true, "zone": znum, "markers": true,
		"source_path": "fallback_meta",
		"fixtures": entries.size(),
		"placed": int(metrics.get("placed", 0)),
		"index_signature": str(result.get("index_signature")),
	}


static func _marker_node(world_scale: float) -> Node3D:
	var box := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * MARKER_BOX_RAW * world_scale
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.45, 0.15)
	mesh_instance.material_override = material
	box.add_child(mesh_instance)
	return box


## Accroche le résultat 14D et REMPLACE les deux écritures de session de la zone.
##
## `null` est un cas légitime, pas une erreur : il efface la zone. C'est le
## chemin qu'emprunte un déchargement.
static func register_result(services: DaocZoneBuildServices, znum: int, result: RefCounted) -> void:
	var state: RefCounted = services.state
	if result == null:
		state.prop_build_results.erase(znum)
		state.prop_nodes_by_zone[znum] = []
		_replace_static_index(state, znum, [])
		_bind_runtime(state)
		return
	state.prop_build_results[znum] = result
	var result_root: Node3D = result.get("root") as Node3D
	if result_root != null:
		var branch: Node3D = services.zone_branch(znum, "StaticPropsRoot")
		if branch != null:
			branch.add_child(result_root)
	state.prop_nodes_by_zone[znum] = result.get("prop_nodes") as Array
	state.prop_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_static_index(state, znum, result.get("static_index") as Array)
	_bind_runtime(state)


## Un corps de collision de prop, quand la fixture le demande.
##
## La DÉCISION appartient au constructeur 14C : l'étape ne fait que lui poser la
## question, compter la réponse et accrocher le corps produit.
static func _build_prop_collision(services: DaocZoneBuildServices, znum: int,
		fixture: Dictionary, file_name: String, template: Node, pos: Vector3,
		yaw_rad: float, placed_scale: float, counts: Dictionary) -> void:
	var collision_settings: Dictionary = services.prop_collision_settings()
	var table: Dictionary = services.fixture_collide_table(znum)
	var decision: Dictionary = CollisionBuilderScript.prop_collision_decision(
		fixture, file_name, table, collision_settings)
	var reason := str(decision.get("reason", ""))
	if not bool(decision.get("wants", false)):
		match reason:
			"excluded_by_name":
				counts["skipped_excluded"] = int(counts["skipped_excluded"]) + 1
			"flag_zero":
				counts["skipped_flag_zero"] = int(counts["skipped_flag_zero"]) + 1
			"missing_flag_no_fallback":
				counts["skipped_no_flag"] = int(counts["skipped_no_flag"]) + 1
		return
	if reason == "missing_flag_fallback":
		counts["missing_flag_fallback"] = int(counts["missing_flag_fallback"]) + 1

	var state: RefCounted = services.state
	var zone_data: Dictionary = state.zone_runtime.get(znum, {}) as Dictionary
	var origin3: Vector3 = zone_data.get("origin3", Vector3.ZERO) as Vector3
	var built: Dictionary = CollisionBuilderScript.build_prop_aabb(znum, fixture, file_name,
		template, pos, yaw_rad, placed_scale, origin3, collision_settings) as Dictionary
	if not bool(built.get("ok", false)):
		return
	var body: StaticBody3D = built.get("body", null) as StaticBody3D
	var runtime_item: Dictionary = built.get("runtime_item", {}) as Dictionary
	if body == null or runtime_item.is_empty():
		return
	var branch: Node3D = services.props_collision_branch(znum)
	if branch != null:
		branch.add_child(body)
	if not state.prop_collision_runtime.has(znum):
		state.prop_collision_runtime[znum] = []
	(state.prop_collision_runtime[znum] as Array).append(runtime_item)
	_replace_collision_prop_index(state, znum, state.prop_collision_runtime[znum] as Array)
	state.collision_prop_signature_by_zone[znum] = CollisionBuilderScript.compute_prop_signature(
		state.prop_collision_runtime[znum] as Array)
	_bind_collision_runtime(state)
	counts["built"] = int(counts["built"]) + 1


static func _is_floor_anchor_model(file_name: String) -> bool:
	return file_name.get_basename().to_lower() in FLOOR_ANCHOR_STEMS


static func _ground_anchor_min_y(file_name: String, min_y: float) -> float:
	if _is_floor_anchor_model(file_name):
		return min_y
	return maxf(0.0, min_y)


static func _replace_static_index(state: RefCounted, znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in state.prop_static_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in zone_index:
		kept.append(item)
	state.prop_static_index = kept


static func _replace_collision_prop_index(state: RefCounted, znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in state.collision_static_prop_index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	for item in zone_index:
		kept.append(item)
	state.collision_static_prop_index = kept


static func _bind_runtime(state: RefCounted) -> void:
	if state.prop_runtime_obj == null:
		state.prop_runtime_obj = PropRuntimeScript.new()
	state.prop_runtime_obj.call("bind", state.prop_static_index)


## Même règle qu'à la tranche 4 : le runtime de collisions relie les DEUX index.
## N'en rebrancher qu'un laisserait le solveur sans les frontières de zone.
static func _bind_collision_runtime(state: RefCounted) -> void:
	if state.collision_runtime_obj == null:
		state.collision_runtime_obj = CollisionRuntimeScript.new()
	state.collision_runtime_obj.call("bind_boundary", state.collision_static_boundary_index)
	state.collision_runtime_obj.call("bind_props", state.collision_static_prop_index)
