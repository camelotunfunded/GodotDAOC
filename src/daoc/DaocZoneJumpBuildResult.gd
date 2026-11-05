extends RefCounted
class_name DaocZoneJumpBuildResult

## P1-14A: résultat statique produit par DaocZoneJumpBuilder.
## Ne porte aucune référence ZoneViewer ni Callable : root packable + index brut.

var root: Node3D = null
var areas: Array[Area3D] = []
var static_index: Array = []
var metrics: Dictionary = {}
var index_signature: String = ""


func is_valid() -> bool:
	return root != null and metrics.has("entries") and metrics.has("areas")


func status() -> Dictionary:
	return {
		"root_valid": root != null,
		"areas": areas.size(),
		"static_index": static_index.size(),
		"metrics": metrics,
		"index_signature": index_signature,
	}
