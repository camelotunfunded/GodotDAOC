extends RefCounted
class_name DaocOpenDaocCharacterCreateCodec

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const OPCODE := 0xFF
const PAYLOAD_SIZE_1125 := 119
const ARRAY_SIZE_MARKER := 24
const TARGET_NAME := "Heyvena"
const TARGET_REALM := 1
const TARGET_RACE := 2
const TARGET_CLASS := 7
## P1-112 (2026-09-22) : LE MODELE 64 EST UN AVALONIEN MALE. Le GM, depuis un
## client d origine, voyait Heyvena « avalo mais homme » alors que le serveur
## la dit femme. `gamedata/monsters.csv` du client tranche : 61-64 « Avalonian
## Male » (quatre visages), 65-68 « Avalonian Female » ; DOL eLivingModel :
## AvalonianMale = 61, AvalonianFemale = 65 (GlobalConstants.cs:1049). P1-94
## avait ecrit 61/64 de memoire et l admin a pose 64 en base : a corriger
## cote serveur en 65 (/player model 65). 42 etait un Highlander MALE (39-42,
## HighlanderFemale = 43), autre erreur de P1-94. Toute creation future envoie 65.
const TARGET_MODEL := 65
const TARGET_RACE_GENDER := 0x82
const TARGET_REGION := 0
const MAX_STARTING_BONUS_POINTS := 30

var _codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func heyveno_fixture(slot_index: int = 0) -> Dictionary:
	return {
		"slot_index": slot_index,
		"name": TARGET_NAME,
		"realm_id": TARGET_REALM,
		"realm_name": "Albion",
		"race_id": TARGET_RACE,
		"race_name": "Avalonian",
		"class_id": TARGET_CLASS,
		"class_name_protocol": "Wizard",
		"class_name_ui": "Wizard",
		"gender": "female",
		"race_gender_byte": TARGET_RACE_GENDER,
		"creation_model": TARGET_MODEL,
		"region_id": TARGET_REGION,
		"operation": 1,
		"customize_type": 0,
		"custom_mode": 0,
		"eye_size": 0,
		"lip_size": 0,
		"eye_color": 0,
		"hair_color": 0,
		"face_type": 0,
		"hair_style": 0,
		"mood_type": 0,
		"level": 1,
		"strength": 45,
		"constitution": 55,
		"dexterity": 70,
		"quickness": 70,
		"intelligence": 90,
		"piety": 60,
		"empathy": 60,
		"charisma": 60,
		"new_constitution": 55,
		"location_placeholder": "",
		"class_placeholder": "",
		"race_placeholder": "",
	}


func build_character_create_payload_1125(data: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var realm_id := int(data.get("realm_id", 0))
	var local_slot := int(data.get("slot_index", -1))
	var wire_slot := local_slot + (realm_id - 1) * 10
	out.append(wire_slot & 0xff)
	out.append_array(_codec.call("pascal_u32_le_write", str(data.get("name", ""))) as PackedByteArray)
	out.append_array(_codec.call("u32_le_write", ARRAY_SIZE_MARKER) as PackedByteArray)
	out.append(int(data.get("custom_mode", 0)) & 0xff)
	out.append(int(data.get("eye_size", 0)) & 0xff)
	out.append(int(data.get("lip_size", 0)) & 0xff)
	out.append(int(data.get("eye_color", 0)) & 0xff)
	out.append(int(data.get("hair_color", 0)) & 0xff)
	out.append(int(data.get("face_type", 0)) & 0xff)
	out.append(int(data.get("hair_style", 0)) & 0xff)
	_append_zeroes(out, 3)
	out.append(int(data.get("mood_type", 0)) & 0xff)
	_append_zeroes(out, 9)
	out.append(int(data.get("operation", 0)) & 0xff)
	out.append(int(data.get("customize_type", 0)) & 0xff)
	_append_zeroes(out, 2)
	# The 1.125 client writes an empty C string as length=1 plus its NUL terminator.
	# GSPacketIn.ReadIntPascalStringLowEndian consumes 4 + 1 bytes and returns "".
	out.append_array(_empty_int_pascal_cstring())
	out.append_array(_empty_int_pascal_cstring())
	out.append_array(_empty_int_pascal_cstring())
	out.append(int(data.get("level", 1)) & 0xff)
	out.append(int(data.get("class_id", 0)) & 0xff)
	out.append(realm_id & 0xff)
	out.append(int(data.get("race_gender_byte", 0)) & 0xff)
	out.append_array(_codec.call("u16_le_write", int(data.get("creation_model", 0))) as PackedByteArray)
	out.append(int(data.get("region_id", 0)) & 0xff)
	_append_zeroes(out, 1)
	_append_zeroes(out, 4)
	out.append(int(data.get("strength", 0)) & 0xff)
	out.append(int(data.get("dexterity", 0)) & 0xff)
	out.append(int(data.get("constitution", 0)) & 0xff)
	out.append(int(data.get("quickness", 0)) & 0xff)
	out.append(int(data.get("intelligence", 0)) & 0xff)
	out.append(int(data.get("piety", 0)) & 0xff)
	out.append(int(data.get("empathy", 0)) & 0xff)
	out.append(int(data.get("charisma", 0)) & 0xff)
	_append_zeroes(out, 16 * 2)
	_append_zeroes(out, 4 * 2)
	_append_zeroes(out, 3)
	out.append(int(data.get("new_constitution", 0)) & 0xff)
	return out


func build_character_create_packet_1125(data: Dictionary, sequence: int, session_id: int = 0, parameter: int = 0) -> PackedByteArray:
	var payload := build_character_create_payload_1125(data)
	var packet_without_checksum: PackedByteArray = _codec.call("build_client_packet", OPCODE, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", packet_without_checksum.slice(0, packet_without_checksum.size() - 2)))
	return _codec.call("build_client_packet", OPCODE, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray


func validate_character_create_data_1125(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var name := str(data.get("name", ""))
	if name.length() < 3:
		errors.append("name_too_short")
	elif not _is_ascii_upper(name.substr(0, 1)) or not _is_ascii_alpha(name):
		errors.append("invalid_name_format")
	var slot := int(data.get("slot_index", -1))
	if slot < 0 or slot > 9:
		errors.append("slot_out_of_range")
	if int(data.get("realm_id", 0)) != TARGET_REALM:
		errors.append("realm_must_be_albion")
	if int(data.get("race_id", 0)) != TARGET_RACE:
		errors.append("race_must_be_avalonian")
	if int(data.get("class_id", 0)) != TARGET_CLASS:
		errors.append("class_must_be_wizard")
	if int(data.get("race_gender_byte", 0)) != TARGET_RACE_GENDER:
		errors.append("female_avalonian_requires_0x82")
	if int(data.get("creation_model", 0)) != TARGET_MODEL:
		errors.append("model_must_be_avalonian_female_65")
	if int(data.get("operation", 0)) != 1:
		errors.append("operation_must_be_create_1")
	if int(data.get("customize_type", -1)) != 0:
		errors.append("customize_type_must_be_zero")
	if int(data.get("custom_mode", -1)) != 0:
		errors.append("custom_mode_must_be_zero")
	for appearance_field in ["eye_size", "lip_size", "eye_color", "hair_color", "face_type", "hair_style", "mood_type"]:
		if int(data.get(appearance_field, -1)) != 0:
			errors.append("neutral_appearance_requires_zero_%s" % appearance_field)
	if int(data.get("region_id", -1)) != TARGET_REGION:
		errors.append("region_must_be_server_derived_zero")
	if int(data.get("level", 0)) != 1:
		errors.append("level_must_be_one")
	var points := starting_points_used(data)
	if points != MAX_STARTING_BONUS_POINTS:
		errors.append("starting_points_must_equal_30")
	if int(data.get("new_constitution", 0)) != int(data.get("constitution", -1)):
		errors.append("new_constitution_mismatch")
	var payload := build_character_create_payload_1125(data)
	if payload.size() != PAYLOAD_SIZE_1125:
		errors.append("payload_size_mismatch")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"points_used": points,
		"stats_distribution_valid": points == MAX_STARTING_BONUS_POINTS,
		"payload_size": payload.size(),
		"payload_size_confirmed": payload.size() == PAYLOAD_SIZE_1125,
		"all_offsets_confirmed": true,
		"reserved_bytes_confirmed": true,
		"region_source": "OpenDAoC StartupLocations ClientRegionID=0 fallback for RealmID=1",
		"region_confidence": "SERVER-DERIVED",
		"appearance_source": "OpenDAoC ignores face fields when CustomMode=0",
	}


func starting_points_used(data: Dictionary) -> int:
	var points := 0
	var base := {"strength": 45, "constitution": 45, "dexterity": 60, "quickness": 70, "intelligence": 80, "piety": 60, "empathy": 60, "charisma": 60}
	for stat_name in base.keys():
		var above := int(data.get(stat_name, 0)) - int(base[stat_name])
		if above < 0:
			return -1
		points += above
		points += maxi(0, above - 10)
		points += maxi(0, above - 15)
	return points


func decode_character_create_payload_for_test_1125(payload: PackedByteArray) -> Dictionary:
	return emulate_server_parser_1125(payload)


## 119 octets = 112 fixes + le nom de Heyvena (7). Un autre nom change la taille.
static func payload_size_for_name_1125(name: String) -> int:
	return PAYLOAD_SIZE_1125 - TARGET_NAME.length() + name.to_ascii_buffer().size()


func emulate_server_parser_1125(payload: PackedByteArray) -> Dictionary:
	var name_length := int(_codec.call("u32_le_read", payload, 1)) if payload.size() >= 5 else -1
	if name_length < 0 or payload.size() != PAYLOAD_SIZE_1125 - TARGET_NAME.length() + name_length:
		return {"ok": false, "error": "payload_size_mismatch", "payload_size": payload.size()}
	var state := {"cursor": 0, "trace": []}
	var values := {}
	values["wire_slot"] = _server_read_byte(payload, state, "CharacterSlot")
	values["name"] = _server_read_int_pascal(payload, state, "CharName")
	_server_skip(payload, state, "array_size_marker", 4)
	values["custom_mode"] = _server_read_byte(payload, state, "CustomMode")
	values["eye_size"] = _server_read_byte(payload, state, "EyeSize")
	values["lip_size"] = _server_read_byte(payload, state, "LipSize")
	values["eye_color"] = _server_read_byte(payload, state, "EyeColor")
	values["hair_color"] = _server_read_byte(payload, state, "HairColor")
	values["face_type"] = _server_read_byte(payload, state, "FaceType")
	values["hair_style"] = _server_read_byte(payload, state, "HairStyle")
	_server_skip(payload, state, "appearance_reserved", 3)
	values["mood_type"] = _server_read_byte(payload, state, "MoodType")
	_server_skip(payload, state, "pre_operation_reserved", 9)
	values["operation"] = _server_read_byte(payload, state, "Operation")
	values["customize_type"] = _server_read_byte(payload, state, "CustomizeType")
	_server_skip(payload, state, "operation_tail", 2)
	values["location_placeholder"] = _server_read_int_pascal(payload, state, "Location")
	values["class_placeholder"] = _server_read_int_pascal(payload, state, "ClassName")
	values["race_placeholder"] = _server_read_int_pascal(payload, state, "RaceName")
	var level_bytes := _server_skip(payload, state, "Level_Version1125", 1)
	values["level"] = int(level_bytes[0]) & 0xff
	values["class_id"] = _server_read_byte(payload, state, "Class")
	values["realm_id"] = _server_read_byte(payload, state, "Realm")
	values["race_gender_byte"] = _server_read_byte(payload, state, "RaceGenderPacked")
	values["creation_model"] = _server_read_short_le(payload, state, "CreationModel")
	values["region_id"] = _server_read_byte(payload, state, "Region_Version1125")
	_server_skip(payload, state, "region_second_byte", 1)
	_server_skip(payload, state, "region_unknown_int", 4)
	for field in ["strength", "dexterity", "constitution", "quickness", "intelligence", "piety", "empathy", "charisma"]:
		values[field] = _server_read_byte(payload, state, field)
	_server_skip(payload, state, "equipment_16_uint16", 32)
	_server_skip(payload, state, "active_equipment_4_uint16", 8)
	_server_skip(payload, state, "final_reserved", 3)
	values["new_constitution"] = _server_read_byte(payload, state, "NewConstitution")
	var packed := int(values.get("race_gender_byte", 0))
	return {
		"ok": int(state.get("cursor", -1)) == payload.size(),
		"wire_slot": int(values.get("wire_slot", -1)), "slot_index": int(values.get("wire_slot", -1)) % 10,
		"name": str(values.get("name", "")), "array_size_marker": int(_codec.call("u32_le_read", payload, 12)),
		"custom_mode": int(values.get("custom_mode", -1)), "eye_size": int(values.get("eye_size", -1)), "lip_size": int(values.get("lip_size", -1)),
		"eye_color": int(values.get("eye_color", -1)), "hair_color": int(values.get("hair_color", -1)), "face_type": int(values.get("face_type", -1)),
		"hair_style": int(values.get("hair_style", -1)), "mood_type": int(values.get("mood_type", -1)),
		"operation": int(values.get("operation", -1)), "customize_type": int(values.get("customize_type", -1)),
		"location_placeholder": str(values.get("location_placeholder", "")), "class_placeholder": str(values.get("class_placeholder", "")), "race_placeholder": str(values.get("race_placeholder", "")),
		"level": int(values.get("level", -1)), "class_id": int(values.get("class_id", -1)), "realm_id": int(values.get("realm_id", -1)),
		"race_gender_byte": packed, "race_id": packed & 0x1f, "female_bit": (packed >> 7) & 1,
		"creation_model": int(values.get("creation_model", -1)), "region_id": int(values.get("region_id", -1)),
		"strength": int(values.get("strength", -1)), "dexterity": int(values.get("dexterity", -1)), "constitution": int(values.get("constitution", -1)),
		"quickness": int(values.get("quickness", -1)), "intelligence": int(values.get("intelligence", -1)), "piety": int(values.get("piety", -1)),
		"empathy": int(values.get("empathy", -1)), "charisma": int(values.get("charisma", -1)), "new_constitution": int(values.get("new_constitution", -1)),
		"payload_size": payload.size(), "cursor": int(state.get("cursor", -1)), "cursor_at_payload_end": int(state.get("cursor", -1)) == payload.size(),
		"trace": state.get("trace", []),
	}


func _server_read_byte(payload: PackedByteArray, state: Dictionary, field: String) -> int:
	var before := int(state.get("cursor", 0))
	var value := int(payload[before]) & 0xff
	state["cursor"] = before + 1
	(state["trace"] as Array).append({"call": "ReadByte", "field": field, "cursor_before": before, "cursor_after": before + 1, "value": value})
	return value


func _server_read_int_pascal(payload: PackedByteArray, state: Dictionary, field: String) -> String:
	var before := int(state.get("cursor", 0))
	var decoded: Dictionary = _codec.call("pascal_u32_le_read", payload, before) as Dictionary
	if not bool(decoded.get("ok", false)):
		return "__PARSE_ERROR__"
	var after := int(decoded.get("next_offset", before))
	state["cursor"] = after
	var value := str(decoded.get("text", ""))
	(state["trace"] as Array).append({"call": "ReadIntPascalStringLowEndian", "field": field, "cursor_before": before, "cursor_after": after, "value": value, "wire_length": after - before - 4})
	return value


func _server_skip(payload: PackedByteArray, state: Dictionary, field: String, count: int) -> PackedByteArray:
	var before := int(state.get("cursor", 0))
	var after := before + count
	var bytes := payload.slice(before, after)
	state["cursor"] = after
	(state["trace"] as Array).append({"call": "Skip", "field": field, "count": count, "cursor_before": before, "cursor_after": after, "bytes": bytes})
	return bytes


func _server_read_short_le(payload: PackedByteArray, state: Dictionary, field: String) -> int:
	var before := int(state.get("cursor", 0))
	var value := int(_codec.call("u16_le_read", payload, before))
	state["cursor"] = before + 2
	(state["trace"] as Array).append({"call": "ReadShortLowEndian", "field": field, "cursor_before": before, "cursor_after": before + 2, "value": value})
	return value


func describe_payload_offsets_1125(_payload: PackedByteArray = PackedByteArray()) -> Array[Dictionary]:
	var source := "OpenDAoC CharacterCreateRequestHandler.CreationCharacterData1124 (Version1125 branch)"
	return [
		_row(0, 0, "CharacterSlot", "slot + (realm-1)*10", "byte", source, "SERVER-DERIVED"),
		_row(1, 4, "CharName length", 7, "uint32 LE", source, "CONFIRMED"),
		_row(5, 11, "CharName bytes", "Heyveno", "Windows-1252", source, "CONFIRMED"),
		_row(12, 15, "array size marker", 24, "uint32 LE", source, "SERVER-DERIVED"),
		_row(16, 16, "CustomMode", 0, "byte", source, "SERVER-DERIVED"),
		_row(17, 22, "appearance fields", "0,0,0,0,0,0", "6 bytes", source, "SERVER-DERIVED"),
		_row(23, 25, "reserved appearance", "00 00 00", "bytes", source, "SERVER-DERIVED"),
		_row(26, 26, "MoodType", 0, "byte", source, "SERVER-DERIVED"),
		_row(27, 35, "reserved before operation", "9 zero bytes", "bytes", source, "SERVER-DERIVED"),
		_row(36, 36, "Operation", 1, "byte", source, "CONFIRMED"),
		_row(37, 37, "CustomizeType", 0, "byte", source, "SERVER-DERIVED"),
		_row(38, 39, "reserved operation tail", "00 00", "bytes", source, "SERVER-DERIVED"),
		_row(40, 44, "Location placeholder", "empty: length=1 plus NUL", "uint32 LE Pascal C string", source, "CONFIRMED"),
		_row(45, 49, "ClassName placeholder", "empty: length=1 plus NUL", "uint32 LE Pascal C string", source, "CONFIRMED"),
		_row(50, 54, "RaceName placeholder", "empty: length=1 plus NUL", "uint32 LE Pascal C string", source, "CONFIRMED"),
		_row(55, 55, "level (Version1125 only)", 1, "byte", source, "CONFIRMED"),
		_row(56, 56, "Class", 2, "byte", source, "CONFIRMED"),
		_row(57, 57, "Realm", 1, "byte", source, "CONFIRMED"),
		_row(58, 58, "race/gender packed", "0x81", "byte", source, "CONFIRMED"),
		_row(59, 60, "CreationModel", 35, "uint16 LE", source, "CONFIRMED"),
		_row(61, 61, "Region", 0, "byte", "StartupLocations ClientRegionID fallback", "SERVER-DERIVED"),
		_row(62, 66, "reserved region tail", "5 zero bytes", "bytes", source, "SERVER-DERIVED"),
		_row(67, 74, "STR DEX CON QUI INT PIE EMP CHA", "70 70 70 60 60 60 60 60", "8 bytes", source, "CONFIRMED"),
		_row(75, 106, "equipment block", "16 zero uint16", "uint16 LE", source, "SERVER-DERIVED"),
		_row(107, 114, "active/equipment reserved", "4 zero uint16", "uint16 LE", source, "SERVER-DERIVED"),
		_row(115, 117, "reserved final prefix", "00 00 00", "bytes", source, "SERVER-DERIVED"),
		_row(118, 118, "NewConstitution", 70, "byte", source, "CONFIRMED"),
	]


func _row(start: int, end: int, field: String, value: Variant, endian: String, source: String, confidence: String) -> Dictionary:
	return {"offset_start": start, "offset_end": end, "size": end - start + 1, "field": field, "value_heyveno": value, "endianness": endian, "source": source, "confidence": confidence}


func _append_zeroes(out: PackedByteArray, count: int) -> void:
	for _i in range(count):
		out.append(0)


func _empty_int_pascal_cstring() -> PackedByteArray:
	return PackedByteArray([1, 0, 0, 0, 0])


func _is_ascii_upper(value: String) -> bool:
	if value.length() != 1:
		return false
	var code := value.unicode_at(0)
	return code >= 65 and code <= 90


func _is_ascii_alpha(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if not ((code >= 65 and code <= 90) or (code >= 97 and code <= 122)):
			return false
	return value.length() > 0
