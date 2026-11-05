extends RefCounted
class_name DaocPropRuntime

## P1-14D: runtime léger de l'index props visibles.
## Ne possède aucun node de scène ; il expose seulement l'index DAoC brut.

var _static_index: Array = []
var _by_zone: Dictionary = {}
var _by_fixture_id: Dictionary = {}


func bind(static_index: Array) -> void:
	_static_index = static_index.duplicate(true)
	_rebuild_maps()


func status() -> Dictionary:
	return {
		"scope": "P1-14D PropRuntime",
		"props": _static_index.size(),
		"zones": _by_zone.keys(),
	}


func props_for_zone(zone_num: int) -> Array:
	return (_by_zone.get(zone_num, []) as Array).duplicate(true)


func find_by_fixture_id(zone_num: int, fixture_id: int) -> Dictionary:
	var key := "%03d:%d" % [zone_num, fixture_id]
	if not _by_fixture_id.has(key):
		return {}
	return (_by_fixture_id[key] as Dictionary).duplicate(true)


func _rebuild_maps() -> void:
	_by_zone.clear()
	_by_fixture_id.clear()
	for item in _static_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		if not _by_zone.has(z):
			_by_zone[z] = []
		(_by_zone[z] as Array).append(d)
		var fixture_id := int(d.get("fixture_id", d.get("id", 0)))
		_by_fixture_id["%03d:%d" % [z, fixture_id]] = d
