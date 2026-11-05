extends RefCounted
class_name DaocZoneViewerStateRegistry


## P1-15E — Regroupe l'état résiduel que ZoneViewer gardait en variables séparées.
## Le registre ne change pas la logique runtime : il porte les mêmes dictionnaires,
## arrays et références, avec compatibilité get/set pour les anciens noms privés.

var zone_runtime: Dictionary = {} # zone -> {origin3, hb, res}
var zone_scene_assembler_results: Dictionary = {} # zone -> assembler result snapshot

var terrain_runtime_obj: RefCounted = null
var terrain_build_results: Dictionary = {}
var terrain_static_index: Array = []
var terrain_meshes_by_zone: Dictionary = {}
var terrain_collision_bodies_by_zone: Dictionary = {}
var terrain_index_signature_by_zone: Dictionary = {}

var water_runtime: Dictionary = {}
var water_runtime_obj: RefCounted = null
var water_build_results: Dictionary = {}
var water_static_index: Array = []
var water_meshes_by_zone: Dictionary = {}
var water_index_signature_by_zone: Dictionary = {}

var boundary_runtime: Dictionary = {}
var collision_runtime_obj: RefCounted = null
var boundary_build_results: Dictionary = {}
var collision_static_boundary_index: Array = []
var collision_static_prop_index: Array = []
var collision_boundary_signature_by_zone: Dictionary = {}
var collision_prop_signature_by_zone: Dictionary = {}
var prop_collision_runtime: Dictionary = {}
var fixture_collide_table_cache: Dictionary = {}

var prop_runtime_obj: RefCounted = null
var prop_build_results: Dictionary = {}
var prop_static_index: Array = []
var prop_nodes_by_zone: Dictionary = {}
var prop_index_signature_by_zone: Dictionary = {}

var zonejump_runtime: RefCounted = null
var zonejump_entries_by_zone: Dictionary = {}
var zonejump_build_results: Dictionary = {}
var zonejump_static_index: Array = []
var zonejump_areas_by_zone: Dictionary = {}
var zonejump_index_signature_by_zone: Dictionary = {}
var last_zonejump_debug: Dictionary = {}
var last_zonejump_transition_stub: Dictionary = {}
var last_zonejump_transition_result: Dictionary = {}
var zonejump_event_log: Array[Dictionary] = []
var zonejump_transition_log: Array[Dictionary] = []
var zonejump_last_enter_msec: Dictionary = {}

var splat_details: Texture2DArray = null
var splat_masks: Texture2DArray = null
var splat_shader: Shader = null
## Sol PBR : par zone, les tableaux normale/rugosite/occlusion et le rapport de
## `DaocTerrainPbrUpgrade.load_zone_maps`. Par zone et non partages, parce que
## la liste `details` du manifeste splat change d'une zone a l'autre.
var splat_pbr_by_zone: Dictionary = {}

const COMPAT_NAMES := {
	"_zone_runtime": "zone_runtime",
	"_zone_scene_assembler_results": "zone_scene_assembler_results",
	"_terrain_runtime_obj": "terrain_runtime_obj",
	"_terrain_build_results": "terrain_build_results",
	"_terrain_static_index": "terrain_static_index",
	"_terrain_meshes_by_zone": "terrain_meshes_by_zone",
	"_terrain_collision_bodies_by_zone": "terrain_collision_bodies_by_zone",
	"_terrain_index_signature_by_zone": "terrain_index_signature_by_zone",
	"_water_runtime": "water_runtime",
	"_water_runtime_obj": "water_runtime_obj",
	"_water_build_results": "water_build_results",
	"_water_static_index": "water_static_index",
	"_water_meshes_by_zone": "water_meshes_by_zone",
	"_water_index_signature_by_zone": "water_index_signature_by_zone",
	"_boundary_runtime": "boundary_runtime",
	"_collision_runtime_obj": "collision_runtime_obj",
	"_boundary_build_results": "boundary_build_results",
	"_collision_static_boundary_index": "collision_static_boundary_index",
	"_collision_static_prop_index": "collision_static_prop_index",
	"_collision_boundary_signature_by_zone": "collision_boundary_signature_by_zone",
	"_collision_prop_signature_by_zone": "collision_prop_signature_by_zone",
	"_prop_collision_runtime": "prop_collision_runtime",
	"_fixture_collide_table_cache": "fixture_collide_table_cache",
	"_prop_runtime_obj": "prop_runtime_obj",
	"_prop_build_results": "prop_build_results",
	"_prop_static_index": "prop_static_index",
	"_prop_nodes_by_zone": "prop_nodes_by_zone",
	"_prop_index_signature_by_zone": "prop_index_signature_by_zone",
	"_zonejump_runtime": "zonejump_runtime",
	"_zonejump_entries_by_zone": "zonejump_entries_by_zone",
	"_zonejump_build_results": "zonejump_build_results",
	"_zonejump_static_index": "zonejump_static_index",
	"_zonejump_areas_by_zone": "zonejump_areas_by_zone",
	"_zonejump_index_signature_by_zone": "zonejump_index_signature_by_zone",
	"_last_zonejump_debug": "last_zonejump_debug",
	"_last_zonejump_transition_stub": "last_zonejump_transition_stub",
	"_last_zonejump_transition_result": "last_zonejump_transition_result",
	"_zonejump_event_log": "zonejump_event_log",
	"_zonejump_transition_log": "zonejump_transition_log",
	"_zonejump_last_enter_msec": "zonejump_last_enter_msec",
	"_splat_details": "splat_details",
	"_splat_masks": "splat_masks",
	"_splat_shader": "splat_shader",
}


func has_compat_name(name: String) -> bool:
	return COMPAT_NAMES.has(name)


func compatibility_get(name: String) -> Variant:
	if not COMPAT_NAMES.has(name):
		return null
	return get(str(COMPAT_NAMES[name]))


func compatibility_set(name: String, value: Variant) -> bool:
	if not COMPAT_NAMES.has(name):
		return false
	set(str(COMPAT_NAMES[name]), value)
	return true


func debug_snapshot() -> Dictionary:
	return {
		"scope": "P1-15E ZoneViewer state grouping / residual state reduction",
		"group_count": 6,
		"compat_name_count": COMPAT_NAMES.size(),
		"zone_runtime_size": zone_runtime.size(),
		"terrain": {
			"runtime_present": terrain_runtime_obj != null,
			"build_results": terrain_build_results.size(),
			"static_index": terrain_static_index.size(),
			"mesh_zones": terrain_meshes_by_zone.size(),
			"collision_body_zones": terrain_collision_bodies_by_zone.size(),
		},
		"water": {
			"runtime_present": water_runtime_obj != null,
			"runtime_zones": water_runtime.size(),
			"build_results": water_build_results.size(),
			"static_index": water_static_index.size(),
			"mesh_zones": water_meshes_by_zone.size(),
		},
		"collision": {
			"runtime_present": collision_runtime_obj != null,
			"boundary_zones": boundary_runtime.size(),
			"boundary_results": boundary_build_results.size(),
			"boundary_static_index": collision_static_boundary_index.size(),
			"prop_static_index": collision_static_prop_index.size(),
			"prop_collision_zones": prop_collision_runtime.size(),
		},
		"props": {
			"runtime_present": prop_runtime_obj != null,
			"build_results": prop_build_results.size(),
			"static_index": prop_static_index.size(),
			"node_zones": prop_nodes_by_zone.size(),
		},
		"zonejump": {
			"runtime_present": zonejump_runtime != null,
			"entry_zones": zonejump_entries_by_zone.size(),
			"build_results": zonejump_build_results.size(),
			"static_index": zonejump_static_index.size(),
			"area_zones": zonejump_areas_by_zone.size(),
			"event_log": zonejump_event_log.size(),
			"transition_log": zonejump_transition_log.size(),
		},
		"splat": {
			"details_present": splat_details != null,
			"masks_present": splat_masks != null,
			"shader_present": splat_shader != null,
		},
	}
