extends RefCounted
class_name DaocPropBuildResult

## P1-14D: résultat statique du PropBuilder.
## Le builder ne parente rien ; ZoneViewer reste propriétaire du root.

var root: Node3D = null
var prop_nodes: Array[Node3D] = []
var static_index: Array = []
var metrics: Dictionary = {}
var index_signature: String = ""
var placement_path: String = ""
