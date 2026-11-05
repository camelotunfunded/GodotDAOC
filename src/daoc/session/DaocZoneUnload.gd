extends RefCounted
class_name DaocZoneUnload

## R5 — ce que R1 n'avait pas eu besoin de faire : oublier une zone.
##
## R1 savait déjà DÉTRUIRE la branche d'une zone, et cela suffisait, parce que le
## seul geste possible était `reload_zone_r1` : décharger puis rebâtir aussitôt.
## Les index de session survivaient au trou d'une trame, et les étapes R4 les
## remplaçaient entrée par entrée à la reconstruction.
##
## R5 décharge SANS rebâtir. Le trou devient permanent, et ce qui restait
## inoffensif devient dangereux : `DaocTerrainRuntime` continuerait de répondre
## une altitude pour une zone dont plus aucun maillage n'existe, le solveur de
## collisions continuerait d'arrêter le joueur contre des murs détruits, et le
## runtime de zonejumps le téléporterait par une frontière disparue. C'est le
## défaut « qui a l'air de marcher » que les tranches 3, 4, 5 et 6 de R4 ont déjà
## verrouillé chacune de leur côté — ici il s'agit du même geste, depuis
## l'extérieur, pour une zone qui ne reviendra pas.
##
## Cet objet ne détruit AUCUN nœud : le `DaocZoneStreamer` en reste seul
## propriétaire. Il ne touche qu'aux index et aux runtimes qui les lisent.

## Les index de session, avec la clé de zone qu'ils portent. Tous suivent la même
## convention depuis 14A : `source_zone`, avec `zone` en repli.
const STATIC_INDEX_FIELDS := [
	"terrain_static_index",
	"water_static_index",
	"collision_static_boundary_index",
	"collision_static_prop_index",
	"prop_static_index",
	"zonejump_static_index",
]

## Les dictionnaires indexés par zone. Ils ne sont pas seulement du confort de
## rapport : `zone_runtime` porte l'origine ET la carte de hauteurs, donc le
## laisser en place ferait échantillonner un relief détruit.
const PER_ZONE_FIELDS := [
	"zone_runtime",
	"zone_scene_assembler_results",
	"terrain_build_results", "terrain_meshes_by_zone",
	"terrain_collision_bodies_by_zone", "terrain_index_signature_by_zone",
	"water_runtime", "water_build_results", "water_meshes_by_zone",
	"water_index_signature_by_zone",
	"boundary_runtime", "boundary_build_results",
	"collision_boundary_signature_by_zone", "collision_prop_signature_by_zone",
	"prop_collision_runtime", "fixture_collide_table_cache",
	"prop_build_results", "prop_nodes_by_zone", "prop_index_signature_by_zone",
	"zonejump_entries_by_zone", "zonejump_build_results",
	"zonejump_areas_by_zone", "zonejump_index_signature_by_zone",
	"zonejump_last_enter_msec",
]


## Oublie une zone : ses entrées quittent les six index, ses tables par zone sont
## effacées, et les quatre runtimes sont rebranchés sur ce qui reste.
##
## Le rapport compte ce qui a été retiré. Un décompte à zéro sur une zone qu'on
## vient de décharger est un signal, pas un succès : c'est qu'elle n'avait jamais
## rien écrit.
static func forget_zone(state: RefCounted, znum: int) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "etat de session absent", "zone": znum}

	var removed: Dictionary = {}
	for field: String in STATIC_INDEX_FIELDS:
		removed[field] = _drop_zone_entries(state, field, znum)

	var cleared: Array = []
	for field: String in PER_ZONE_FIELDS:
		var table: Dictionary = state.get(field) as Dictionary
		if table != null and table.has(znum):
			table.erase(znum)
			cleared.append(field)

	_rebind_runtimes(state)

	return {
		"ok": true,
		"zone": znum,
		"index_entries_removed": removed,
		"per_zone_tables_cleared": cleared,
	}


## Retire d'un index toutes les entrées d'une zone, et rend leur nombre.
static func _drop_zone_entries(state: RefCounted, field: String, znum: int) -> int:
	var index: Array = state.get(field) as Array
	if index == null:
		return 0
	var kept: Array = []
	for item in index:
		var entry: Dictionary = item as Dictionary
		if int(entry.get("source_zone", entry.get("zone", -1))) != znum:
			kept.append(entry)
	var removed: int = index.size() - kept.size()
	state.set(field, kept)
	return removed


## Rebranche les quatre runtimes sur les index amputés.
##
## Ils sont rebranchés même s'ils n'existent pas encore : un runtime absent n'est
## pas créé ici. Créer un `DaocTerrainRuntime` pour une session qui n'en a jamais
## eu ferait répondre un échantillonneur vide là où le repli sur la carte de
## hauteurs brute est le comportement voulu.
static func _rebind_runtimes(state: RefCounted) -> void:
	# Le terrain est le seul a prendre DEUX arguments : l'index et les donnees de
	# zone. Lui rendre l'index ampute sans les donnees amputees le laisserait
	# echantillonner l'ancienne carte de hauteurs.
	if state.terrain_runtime_obj != null and state.terrain_runtime_obj.has_method("bind"):
		state.terrain_runtime_obj.call("bind", state.terrain_static_index, state.zone_runtime)
	if state.water_runtime_obj != null and state.water_runtime_obj.has_method("bind"):
		state.water_runtime_obj.call("bind", state.water_static_index)
	if state.collision_runtime_obj != null:
		state.collision_runtime_obj.call("bind_boundary", state.collision_static_boundary_index)
		state.collision_runtime_obj.call("bind_props", state.collision_static_prop_index)
	if state.prop_runtime_obj != null and state.prop_runtime_obj.has_method("bind"):
		state.prop_runtime_obj.call("bind", state.prop_static_index)
	if state.zonejump_runtime != null and state.zonejump_runtime.has_method("bind"):
		state.zonejump_runtime.call("bind", state.zonejump_static_index)
