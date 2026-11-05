extends RefCounted
class_name DaocCollisionBuildResult

## P1-14C: résultat statique du CollisionBuilder.
## Le builder ne parente rien ; ZoneViewer reste propriétaire du root.

var root: Node3D = null
var boundary_root: Node3D = null
var prop_root: Node3D = null
var boundary_segments: Array = []
var prop_bodies: Array = []
var boundary_bodies: Array[StaticBody3D] = []
var prop_nodes: Array[StaticBody3D] = []
var metrics: Dictionary = {}
var boundary_index_signature: String = ""
var prop_index_signature: String = ""
var source_path: String = ""
