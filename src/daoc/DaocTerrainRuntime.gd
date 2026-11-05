extends RefCounted
class_name DaocTerrainRuntime

## P1-14E: runtime léger du terrain.
## Il ne possède aucun node de scène. Il garde les heightmaps déjà chargées et expose le sampling DAoC.

var _static_index: Array = []
var _zones: Dictionary = {}
var _by_zone: Dictionary = {}


func bind(static_index: Array, zones_data: Dictionary) -> void:
	_static_index = static_index.duplicate(true)
	_zones = zones_data.duplicate(true)
	_rebuild_maps()


func status() -> Dictionary:
	return {
		"scope": "P1-14E TerrainRuntime",
		"terrain_items": _static_index.size(),
		"zones": _zones.keys(),
	}


func has_zone(zone_num: int) -> bool:
	return _zones.has(zone_num)


func zone_data(zone_num: int) -> Dictionary:
	return (_zones.get(zone_num, {}) as Dictionary).duplicate(true)


func sectors_for_zone(zone_num: int) -> Array:
	return (_by_zone.get(zone_num, []) as Array).duplicate(true)


func sample_floor(zone_num: int, daoc_x: float, daoc_y: float, _daoc_z: float = 0.0) -> float:
	var rt: Dictionary = _zones.get(zone_num, {}) as Dictionary
	if rt.is_empty():
		return 0.0
	var hb: PackedByteArray = rt.get("hb", PackedByteArray()) as PackedByteArray
	var res := int(rt.get("res", 0))
	if hb.is_empty() or res <= 0:
		return 0.0
	return _sample_height(hb, res, daoc_x, daoc_y)


func _rebuild_maps() -> void:
	_by_zone.clear()
	for item in _static_index:
		var d: Dictionary = item as Dictionary
		var z := int(d.get("source_zone", d.get("zone", -1)))
		if not _by_zone.has(z):
			_by_zone[z] = []
		(_by_zone[z] as Array).append(d)


static func _sample_height(hb: PackedByteArray, res: int, wx: float, wy: float) -> float:
	# Bilinear sample of the r16 heightmap at zone-local DAoC coords -> raw units.
	var fx: float = clampf(wx / 65536.0 * res - 0.5, 0.0, res - 1.0)
	var fy: float = clampf(wy / 65536.0 * res - 0.5, 0.0, res - 1.0)
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var x1: int = min(x0 + 1, res - 1)
	var y1: int = min(y0 + 1, res - 1)
	var dx: float = fx - x0
	var dy: float = fy - y0
	var i00: int = (y0 * res + x0) * 2
	var i10: int = (y0 * res + x1) * 2
	var i01: int = (y1 * res + x0) * 2
	var i11: int = (y1 * res + x1) * 2
	var h00: float = float(hb[i00] | (hb[i00 + 1] << 8))
	var h10: float = float(hb[i10] | (hb[i10 + 1] << 8))
	var h01: float = float(hb[i01] | (hb[i01 + 1] << 8))
	var h11: float = float(hb[i11] | (hb[i11 + 1] << 8))
	return (h00 * (1 - dx) * (1 - dy) + h10 * dx * (1 - dy)
		+ h01 * (1 - dx) * dy + h11 * dx * dy)
