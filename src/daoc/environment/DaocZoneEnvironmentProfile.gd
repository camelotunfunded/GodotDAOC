extends RefCounted
class_name DaocZoneEnvironmentProfile

## Exact, lossless view of the DAoC zone environment fields used by the
## rendering layer. Missing source values stay missing: this class does not
## invent a temperature, a sky override, or a snow map.

enum SkyMode {
	OUTDOOR_DYNAMIC,
	SKY_OVERRIDE,
	NO_SKY,
}

var zone_id: int = -1
var zone_name: String = ""
var region_id: int = -1
var zone_type: int = -1
var realm_id: int = 0
var realm_name: String = "Unknown"
var sky_asset_root: String = ""

var has_temperature: bool = false
var temperature: int = 0
var has_override_time: bool = false
var override_time_seconds: int = 0
var noskyflag: bool = false
var skynif: String = ""
var skydome: String = ""
var snowmap_path: String = ""

var fog_amount: int = -1
var fog_color: Color = Color(0.72, 0.78, 0.85, 1.0)
var fog_clip: float = -1.0
var sky_color: Color = Color(0.50, 0.84, 1.0, 1.0)
var horizon_asset: String = ""
var cloud_asset: String = ""

var zones_dat_path: String = ""
var sector_dat_path: String = ""
var source_warnings: Array[String] = []


func load_from_client(p_zone_id: int, client_root: String) -> RefCounted:
	zone_id = p_zone_id
	realm_id = realm_id_for_zone(zone_id)
	realm_name = realm_name_for_id(realm_id)
	var root := client_root.strip_edges().replace("\\", "/").trim_suffix("/")
	if root.is_empty():
		source_warnings.append("DAOC client root is empty")
		return self
	sky_asset_root = root.path_join("zones/sky")

	zones_dat_path = root.path_join("zones/zones/zones.dat")
	var zone_key := "zone%03d" % p_zone_id
	var zone_values := _read_ini_section(zones_dat_path, zone_key)
	if zone_values.is_empty():
		source_warnings.append("Missing [%s] in zones.dat" % zone_key)
	else:
		zone_name = str(zone_values.get("name", ""))
		region_id = _parse_int(zone_values.get("region", -1), -1)
		zone_type = _parse_int(zone_values.get("type", -1), -1)
		has_temperature = zone_values.has("temperature")
		temperature = _parse_int(zone_values.get("temperature", 0), 0)
		has_override_time = zone_values.has("override_time")
		override_time_seconds = _parse_int(zone_values.get("override_time", 0), 0)
		noskyflag = _parse_bool(zone_values.get("noskyflag", false))
		skynif = str(zone_values.get("skynif", "")).strip_edges()
		# This client data set calls the zone sky recipe `skydome`. Preserve it
		# separately instead of pretending it is a converted NIF.
		skydome = str(zone_values.get("skydome", "")).strip_edges()
	var zone_dir := root.path_join("zones/zone%03d" % p_zone_id)
	sector_dat_path = zone_dir.path_join("dat%03d/SECTOR.DAT" % p_zone_id)
	var fog_values := _read_ini_section(sector_dat_path, "fog")
	if not fog_values.is_empty():
		fog_amount = _parse_int(fog_values.get("amount", -1), -1)
		fog_clip = _parse_float(fog_values.get("clip", -1.0), -1.0)
		fog_color = _rgb_from_section(fog_values, fog_color)
	var sky_values := _read_ini_section(sector_dat_path, "sky")
	if not sky_values.is_empty():
		sky_color = _rgb_from_section(sky_values, sky_color)
	var terrain_values := _read_ini_section(sector_dat_path, "terrain")
	horizon_asset = str(terrain_values.get("horizon", "")).strip_edges()
	cloud_asset = str(terrain_values.get("clouds", "")).strip_edges()

	for candidate in _snowmap_candidates(zone_dir, p_zone_id):
		if FileAccess.file_exists(candidate):
			snowmap_path = candidate
			break
	return self


func sky_mode() -> int:
	if noskyflag:
		return SkyMode.NO_SKY
	if not skynif.is_empty() or not skydome.is_empty():
		return SkyMode.SKY_OVERRIDE
	return SkyMode.OUTDOOR_DYNAMIC


func sky_mode_name() -> String:
	match sky_mode():
		SkyMode.SKY_OVERRIDE:
			return "SKY_OVERRIDE"
		SkyMode.NO_SKY:
			return "NO_SKY"
	return "OUTDOOR_DYNAMIC"


func effective_time_seconds(server_time_seconds: int) -> int:
	return posmod(override_time_seconds if has_override_time else server_time_seconds, 86400)


func to_dict() -> Dictionary:
	return {
		"zone_id": zone_id,
		"zone_name": zone_name,
		"region_id": region_id,
		"zone_type": zone_type,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"sky_asset_root": sky_asset_root,
		"sky_mode": sky_mode_name(),
		"has_temperature": has_temperature,
		"temperature": temperature if has_temperature else null,
		"has_override_time": has_override_time,
		"override_time_seconds": override_time_seconds if has_override_time else null,
		"noskyflag": noskyflag,
		"skynif": skynif,
		"skydome": skydome,
		"snowmap_path": snowmap_path,
		"snowmap_present": not snowmap_path.is_empty(),
		"fog_amount": fog_amount,
		"fog_color": fog_color.to_html(false),
		"fog_clip": fog_clip,
		"sky_color": sky_color.to_html(false),
		"horizon_asset": horizon_asset,
		"cloud_asset": cloud_asset,
		"zones_dat_path": zones_dat_path,
		"sector_dat_path": sector_dat_path,
		"source_warnings": source_warnings.duplicate(),
	}


## DAoC's outdoor zone-id families are grouped by realm: 0xx Albion,
## 1xx Midgard and 2xx Hibernia. Instance/override skies remain governed by
## noskyflag/skydome/skynif and do not silently become a realm sky.
static func realm_id_for_zone(p_zone_id: int) -> int:
	if p_zone_id >= 0 and p_zone_id < 100:
		return 1
	if p_zone_id >= 100 and p_zone_id < 200:
		return 2
	if p_zone_id >= 200 and p_zone_id < 300:
		return 3
	return 0


static func realm_name_for_id(p_realm_id: int) -> String:
	match p_realm_id:
		1:
			return "Albion"
		2:
			return "Midgard"
		3:
			return "Hibernia"
	return "Unknown"


static func _snowmap_candidates(zone_dir: String, p_zone_id: int) -> PackedStringArray:
	return PackedStringArray([
		zone_dir.path_join("snowmap.tga"),
		zone_dir.path_join("terrain/snowmap.tga"),
		zone_dir.path_join("dat%03d/snowmap.tga" % p_zone_id),
		zone_dir.path_join("ter%03d/snowmap.tga" % p_zone_id),
		zone_dir.path_join("ter%03d/terrain/snowmap.tga" % p_zone_id),
	])


static func _read_ini_section(path: String, wanted_section: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var result := {}
	var active := false
	for raw_line in _read_legacy_text(path).split("\n"):
		var line := str(raw_line).strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.contains("]"):
			var closing := line.find("]")
			active = line.substr(1, closing - 1).strip_edges().to_lower() == wanted_section.to_lower()
			continue
		if not active or not line.contains("="):
			continue
		var separator := line.find("=")
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		var comment := value.find(";")
		if comment >= 0:
			value = value.substr(0, comment).strip_edges()
		result[key] = value
	return result


## Client INI/DAT files predate UTF-8 and contain Windows-1252 bytes. The
## environment keys are ASCII; decoding every byte as a single code point keeps
## them exact and avoids lossy UTF-8 warnings during offline tests.
static func _read_legacy_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	var characters := PackedStringArray()
	characters.resize(bytes.size())
	for index in range(bytes.size()):
		characters[index] = String.chr(int(bytes[index]))
	return "".join(characters)


static func _rgb_from_section(values: Dictionary, fallback: Color) -> Color:
	if not values.has("red") or not values.has("green") or not values.has("blue"):
		return fallback
	return Color8(
		clampi(_parse_int(values.get("red", 0), 0), 0, 255),
		clampi(_parse_int(values.get("green", 0), 0), 0, 255),
		clampi(_parse_int(values.get("blue", 0), 0), 0, 255),
		255
	)


static func _parse_int(value: Variant, fallback: int) -> int:
	var text := str(value).strip_edges()
	return text.to_int() if text.is_valid_int() else fallback


static func _parse_float(value: Variant, fallback: float) -> float:
	var text := str(value).strip_edges()
	return text.to_float() if text.is_valid_float() else fallback


static func _parse_bool(value: Variant) -> bool:
	return str(value).strip_edges().to_lower() in ["1", "true", "yes", "on"]
