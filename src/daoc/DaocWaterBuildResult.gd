extends RefCounted
class_name DaocWaterBuildResult

## P1-14B: résultat statique du WaterBuilder.
## Le root n'est pas parenté par le builder. ZoneViewer en reste propriétaire.

var root: Node3D = null
var meshes: Array[MeshInstance3D] = []
var static_index: Array = []
var metrics: Dictionary = {}
var index_signature: String = ""
var sector_path: String = ""
