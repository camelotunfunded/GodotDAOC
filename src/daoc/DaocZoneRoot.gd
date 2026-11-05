extends Node3D
class_name DaocZoneRoot

## Lightweight scene organizer for one DAoC zone.
## This does not own gameplay yet. It only separates visual/mechanics branches
## so ZoneViewer can stay a test harness instead of becoming a monolith.

var zone_id: int = -1
var terrain_root: Node3D
var static_props_root: Node3D
var water_root: Node3D
var vegetation_root: Node3D
var lighting_root: Node3D
var mechanics_debug_root: Node3D
var collision_root: Node3D


func setup(p_zone_id: int) -> void:
	zone_id = p_zone_id
	name = "Zone%03d_Root" % zone_id
	terrain_root = _ensure_branch("TerrainRoot")
	static_props_root = _ensure_branch("StaticPropsRoot")
	water_root = _ensure_branch("WaterRoot")
	vegetation_root = _ensure_branch("VegetationRoot")
	lighting_root = _ensure_branch("LightingRoot")
	mechanics_debug_root = _ensure_branch("MechanicsDebugRoot")
	collision_root = _ensure_branch("CollisionRoot")


func get_branch(branch_name: String) -> Node3D:
	match branch_name:
		"TerrainRoot":
			return terrain_root
		"StaticPropsRoot":
			return static_props_root
		"WaterRoot":
			return water_root
		"VegetationRoot":
			return vegetation_root
		"LightingRoot":
			return lighting_root
		"MechanicsDebugRoot":
			return mechanics_debug_root
		"CollisionRoot":
			return collision_root
		_:
			return _ensure_branch(branch_name)


func _ensure_branch(branch_name: String) -> Node3D:
	var existing := get_node_or_null(branch_name)
	if existing != null and existing is Node3D:
		return existing as Node3D
	var n := Node3D.new()
	n.name = branch_name
	add_child(n)
	return n
