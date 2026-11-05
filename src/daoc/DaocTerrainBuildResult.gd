extends RefCounted
class_name DaocTerrainBuildResult

## P1-14E: résultat statique du TerrainBuilder.
## Le builder ne parente rien ; ZoneViewer reste propriétaire du root terrain et du root collision.

var root: Node3D = null
var collision_root: Node3D = null
var terrain_meshes: Array[MeshInstance3D] = []
var collision_bodies: Array[StaticBody3D] = []
var static_index: Array = []
var metrics: Dictionary = {}
var index_signature: String = ""
var source_path: String = ""
