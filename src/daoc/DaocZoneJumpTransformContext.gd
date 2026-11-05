extends RefCounted
class_name DaocZoneJumpTransformContext

## P1-14A: contexte de placement Godot pour le builder zonejump.
## Objet détaché : aucune lecture runtime ZoneViewer, uniquement des constantes copiées.

var zone_num: int = -1
var origin3: Vector3 = Vector3.ZERO
var world_scale: float = 1.0
var height_exaggeration: float = 1.0
var zonejump_thickness_raw: float = 60.0
var zonejump_debug_visible: bool = false
var zonejump_area_enabled: bool = true


func setup(p_zone_num: int, p_origin3: Vector3, p_world_scale: float, p_height_exaggeration: float, p_thickness_raw: float, p_debug_visible: bool, p_area_enabled: bool) -> void:
	zone_num = p_zone_num
	origin3 = p_origin3
	world_scale = p_world_scale
	height_exaggeration = p_height_exaggeration
	zonejump_thickness_raw = p_thickness_raw
	zonejump_debug_visible = p_debug_visible
	zonejump_area_enabled = p_area_enabled


func daoc_to_godot(_znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	return origin3 + Vector3(
		daoc_x * world_scale,
		daoc_z * world_scale * height_exaggeration,
		daoc_y * world_scale
	)
