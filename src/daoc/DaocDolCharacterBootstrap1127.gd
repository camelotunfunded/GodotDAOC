extends Node
class_name DaocDolCharacterBootstrap1127

## P1-N5E/F/G: CharacterOverview1126 enrichi + sélection personnage locale + bootstrap entrée monde offline.
## Aucun serveur DOL lancé, aucune socket, aucun déplacement réel du joueur par défaut.

const SERVER_PACKET_SESSION_ID: int = 0x28
const SERVER_PACKET_REALM: int = 0xFE
const SERVER_PACKET_CHARACTER_OVERVIEW_1126: int = 0xFC
const SERVER_PACKET_POSITION_AND_OBJECT_ID: int = 0x20
const CLIENT_PACKET_CHARACTER_SELECT: int = 0x10
const CLIENT_PACKET_WORLD_INIT: int = 0xD4

const REALM_NONE: int = 0
const REALM_ALBION: int = 1
const REALM_MIDGARD: int = 2
const REALM_HIBERNIA: int = 3
const SLOT_COUNT_1126: int = 10
const CHAR_STRING_MAX: int = 0x18
## PacketLib1125/1126.SendCharacterOverview ecrit exactement 20 ushort :
## 8 modeles/couleur main droite, 8 couleurs, puis 4 modeles d'armes.
const EQUIPMENT_U16_COUNT: int = 20

const CLASS_NAMES := {
	0: "Unknown",
	1: "Paladin", 2: "Armsman", 3: "Scout", 4: "Minstrel", 5: "Theurgist",
	6: "Cleric", 7: "Wizard", 8: "Sorcerer", 9: "Infiltrator", 10: "Friar",
	11: "Mercenary", 12: "Necromancer", 13: "Cabalist", 14: "Fighter",
	15: "Elementalist", 16: "Acolyte", 17: "AlbionRogue", 18: "Mage", 19: "Reaver",
	20: "Disciple", 21: "Thane", 22: "Warrior", 23: "Shadowblade", 24: "Skald",
	25: "Hunter", 26: "Healer", 27: "Spiritmaster", 28: "Shaman", 29: "Runemaster",
	30: "Bonedancer", 31: "Berserker", 32: "Savage", 33: "Heretic", 34: "Valkyrie",
	35: "Viking", 36: "Mystic", 37: "Seer", 38: "MidgardRogue", 39: "Bainshee",
	40: "Eldritch", 41: "Enchanter", 42: "Mentalist", 43: "Blademaster", 44: "Hero",
	45: "Champion", 46: "Warden", 47: "Druid", 48: "Bard", 49: "Nightshade",
	50: "Ranger", 51: "Magician", 52: "Guardian", 53: "Naturalist", 54: "Stalker",
	55: "Animist", 56: "Valewalker", 57: "Forester", 58: "Vampiir", 59: "Warlock",
	60: "MaulerAlb", 61: "MaulerMid", 62: "MaulerHib",
}

const RACE_NAMES := {
	0: "Unknown", 1: "Briton", 2: "Avalonian", 3: "Highlander", 4: "Saracen",
	5: "Norseman", 6: "Troll", 7: "Dwarf", 8: "Kobold", 9: "Celt",
	10: "Firbolg", 11: "Elf", 12: "Lurikeen", 13: "Inconnu", 14: "Valkyn",
	15: "Sylvan", 16: "HalfOgre", 17: "Frostalf", 18: "Shar",
	19: "AlbionMinotaur", 20: "MidgardMinotaur", 21: "HiberniaMinotaur",
}

@export var debug_bootstrap: bool = false
@export var offline_account: String = "testgodot"
@export var offline_realm: int = REALM_ALBION
@export var offline_selected_index: int = 0
@export var offline_session_id: int = 1
@export var offline_object_id: int = 1
@export var offline_x: int = 32768
@export var offline_y: int = 32768
@export var offline_z: int = 2075
@export var offline_heading: int = 0

var server_fixtures_1127: Node = null
var login_flow_1127: Node = null
var last_error: Dictionary = {}
var last_decoded_characters: Array = []
var selected_character: Dictionary = {}
var last_bootstrap_snapshot: Dictionary = {}
var last_safe_apply_snapshot: Dictionary = {}
var last_pre_apply_player_snapshot: Dictionary = {}
var last_rollback_player_snapshot: Dictionary = {}


func reset_bootstrap_profile() -> void:
	last_error.clear()
	last_decoded_characters.clear()
	selected_character.clear()
	last_bootstrap_snapshot.clear()
	last_safe_apply_snapshot.clear()
	last_pre_apply_player_snapshot.clear()
	last_rollback_player_snapshot.clear()
	offline_account = "testgodot"
	offline_realm = REALM_ALBION
	offline_selected_index = 0
	offline_session_id = 1
	offline_object_id = 1
	offline_x = 32768
	offline_y = 32768
	offline_z = 2075
	offline_heading = 0


func setup_bootstrap(p_server_fixtures_1127: Node = null, p_login_flow_1127: Node = null) -> void:
	server_fixtures_1127 = p_server_fixtures_1127
	login_flow_1127 = p_login_flow_1127
	last_error.clear()
	if selected_character.is_empty():
		selected_character = normalize_character_dict(default_character())


func set_server_fixtures_1127(p_server_fixtures_1127: Node) -> void:
	server_fixtures_1127 = p_server_fixtures_1127
	last_error.clear()


func set_login_flow_1127(p_login_flow_1127: Node) -> void:
	login_flow_1127 = p_login_flow_1127
	last_error.clear()


func configure_character_fixture(character: Dictionary = {}) -> void:
	var source := character
	if source.is_empty():
		source = default_character()
	selected_character = normalize_character_dict(source)
	offline_selected_index = int(selected_character.get("index", 0))
	offline_realm = int(selected_character.get("realm", REALM_ALBION))
	offline_object_id = int(selected_character.get("object_id", offline_object_id))
	offline_x = int(selected_character.get("x", offline_x))
	offline_y = int(selected_character.get("y", offline_y))
	offline_z = int(selected_character.get("z", offline_z))
	offline_heading = int(selected_character.get("heading", offline_heading))
	last_error.clear()


func configure_selection(index: int = 0, realm: int = REALM_ALBION) -> void:
	offline_selected_index = clamp_slot_index(index)
	offline_realm = clamp_realm(realm)
	selected_character = normalize_character_dict(default_character())
	selected_character["index"] = offline_selected_index
	selected_character["account_slot"] = account_slot_for_index(offline_selected_index, offline_realm)
	selected_character["realm"] = offline_realm
	selected_character["realm_name"] = realm_name_for_id(offline_realm)
	last_error.clear()


func set_debug_enabled(enabled: bool) -> void:
	debug_bootstrap = enabled


func is_debug_enabled() -> bool:
	return debug_bootstrap


func default_character() -> Dictionary:
	return {
		"index": offline_selected_index,
		"account_slot": account_slot_for_index(offline_selected_index, offline_realm),
		"object_id": offline_object_id,
		"name": "GodotServerDebug",
		"level": 1,
		"class_id": 2,
		"class_name": "Armsman",
		"race_id": 1,
		"race_name": "Briton",
		"realm": offline_realm,
		"realm_name": realm_name_for_id(offline_realm),
		"gender": 0,
		"gender_name": "Male",
		"region": 1,
		"region_expansion": 0,
		"model": 50,
		"location": "Camelot Hills",
		"x": offline_x,
		"y": offline_y,
		"z": offline_z,
		"heading": offline_heading,
		"equipment": default_equipment_u16(),
		"stats": default_stats(),
	}


func default_character_name() -> String:
	return str(default_character().get("name", "GodotServerDebug"))


func sanitize_text(text: String, max_len: int = 24, fallback: String = "") -> String:
	var s := text.strip_edges()
	var out := ""
	for i in range(s.length()):
		var c := s.unicode_at(i)
		if c >= 32 and c <= 126:
			out += s.substr(i, 1)
	out = out.substr(0, maxi(0, max_len))
	if out == "":
		out = fallback
	return out


func clamp_realm(realm: int) -> int:
	return clampi(realm, REALM_NONE, REALM_HIBERNIA)


func clamp_slot_index(index: int) -> int:
	return clampi(index, 0, SLOT_COUNT_1126 - 1)


func realm_base_account_slot(realm: int = REALM_ALBION) -> int:
	return clamp_realm(realm) * 100


func account_slot_for_index(index: int = 0, realm: int = REALM_ALBION) -> int:
	return realm_base_account_slot(realm) + clamp_slot_index(index)


func index_for_account_slot(account_slot: int, realm: int = REALM_ALBION) -> int:
	return clamp_slot_index(int(account_slot) - realm_base_account_slot(realm))


func realm_name_for_id(realm: int) -> String:
	match int(realm):
		REALM_ALBION:
			return "Albion"
		REALM_MIDGARD:
			return "Midgard"
		REALM_HIBERNIA:
			return "Hibernia"
	return "None"


func realm_id_for_name(name: String) -> int:
	match name.strip_edges().to_lower():
		"albion", "alb":
			return REALM_ALBION
		"midgard", "mid":
			return REALM_MIDGARD
		"hibernia", "hib":
			return REALM_HIBERNIA
	return REALM_NONE


func class_name_for_id(class_id: int) -> String:
	return str(CLASS_NAMES.get(int(class_id), "Class_%d" % int(class_id)))


func race_name_for_id(race_id: int, realm: int = REALM_ALBION) -> String:
	return str(RACE_NAMES.get(int(race_id), "Race_%d" % int(race_id)))


func gender_name_for_id(gender: int) -> String:
	return "Female" if int(gender) != 0 else "Male"


func ascii_bytes(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in range(text.length()):
		out.append(text.unicode_at(i) & 0x7f)
	return out


func bytes_to_ascii(data: PackedByteArray) -> String:
	var clean := PackedByteArray()
	for b in data:
		var n := int(b) & 0xff
		if n == 0:
			break
		clean.append(n)
	return clean.get_string_from_ascii()


func append_u8(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	out.append(int(v) & 0xff)
	return out


func append_u16_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
	return out


func append_u16_be(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffff
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func append_u32_le(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffffffff
	out.append(n & 0xff)
	out.append((n >> 8) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 24) & 0xff)
	return out


func read_u8(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset >= data.size():
		make_error("read_u8", "offset out of range")
		return 0
	return int(data[offset]) & 0xff


func read_u16_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 1 >= data.size():
		make_error("read_u16_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8)


func read_u16_be(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 1 >= data.size():
		make_error("read_u16_be", "offset out of range")
		return 0
	return ((int(data[offset]) & 0xff) << 8) | (int(data[offset + 1]) & 0xff)


func read_u32_le(data: PackedByteArray, offset: int = 0) -> int:
	if offset < 0 or offset + 3 >= data.size():
		make_error("read_u32_le", "offset out of range")
		return 0
	return (int(data[offset]) & 0xff) | ((int(data[offset + 1]) & 0xff) << 8) | ((int(data[offset + 2]) & 0xff) << 16) | ((int(data[offset + 3]) & 0xff) << 24)


func append_pascal_i32_le_string(data: PackedByteArray, text: String, max_len: int = CHAR_STRING_MAX) -> PackedByteArray:
	var clean := sanitize_text(text, maxi(0, max_len - 1), "")
	var bytes := ascii_bytes(clean)
	var out := append_u32_le(data, bytes.size() + 1)
	out.append_array(bytes)
	out.append(0)
	return out


func read_pascal_i32_le_string(data: PackedByteArray, offset: int = 0) -> Dictionary:
	if offset < 0 or offset + 3 >= data.size():
		return make_error("read_pascal_i32_le_string", "missing length")
	var length := read_u32_le(data, offset)
	var start := offset + 4
	var stop := clampi(start + length, start, data.size())
	var raw := data.slice(start, stop)
	return {"ok": stop <= data.size(), "text": bytes_to_ascii(raw), "length": length, "next_offset": stop}


func append_zero_fill(data: PackedByteArray, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	for _i in range(maxi(0, count)):
		out.append(0)
	return out


func append_equipment_u16_list(data: PackedByteArray, values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	for i in range(EQUIPMENT_U16_COUNT):
		out = append_u16_le(out, int(values[i]) if i < values.size() else 0)
	return out


func read_equipment_u16_list(data: PackedByteArray, offset: int = 0, count: int = EQUIPMENT_U16_COUNT) -> Dictionary:
	var values: Array = []
	var pos := offset
	for _i in range(maxi(0, count)):
		if pos + 1 >= data.size():
			return {"ok": false, "values": values, "next_offset": pos}
		values.append(read_u16_le(data, pos))
		pos += 2
	return {"ok": true, "values": values, "next_offset": pos}


func normalize_character_dict(character: Dictionary) -> Dictionary:
	var d := default_character()
	for k in character.keys():
		d[k] = character[k]
	d["index"] = clamp_slot_index(int(d.get("index", 0)))
	d["realm"] = clamp_realm(int(d.get("realm", REALM_ALBION)))
	d["account_slot"] = int(d.get("account_slot", account_slot_for_index(int(d["index"]), int(d["realm"]))))
	d["name"] = sanitize_text(str(d.get("name", "GodotServerDebug")), CHAR_STRING_MAX - 1, "GodotServerDebug")
	d["level"] = clampi(int(d.get("level", 1)), 1, 50)
	d["class_id"] = clampi(int(d.get("class_id", 2)), 0, 255)
	d["class_name"] = sanitize_text(str(d.get("class_name", class_name_for_id(int(d["class_id"])))), CHAR_STRING_MAX - 1, class_name_for_id(int(d["class_id"])))
	d["race_id"] = clampi(int(d.get("race_id", 1)), 0, 255)
	d["race_name"] = sanitize_text(str(d.get("race_name", race_name_for_id(int(d["race_id"]), int(d["realm"])))), CHAR_STRING_MAX - 1, race_name_for_id(int(d["race_id"]), int(d["realm"])))
	d["gender"] = clampi(int(d.get("gender", 0)), 0, 1)
	d["gender_name"] = gender_name_for_id(int(d["gender"]))
	d["realm_name"] = realm_name_for_id(int(d["realm"]))
	d["region"] = clampi(int(d.get("region", 1)), 0, 255)
	d["region_expansion"] = clampi(int(d.get("region_expansion", 0)), 0, 255)
	d["model"] = clampi(int(d.get("model", 50)), 0, 65535)
	d["location"] = sanitize_text(str(d.get("location", "Camelot Hills")), CHAR_STRING_MAX - 1, "Camelot Hills")
	d["x"] = clampi(int(d.get("x", offline_x)), 0, 16777215)
	d["y"] = clampi(int(d.get("y", offline_y)), 0, 16777215)
	d["z"] = clampi(int(d.get("z", offline_z)), 0, 65535)
	d["heading"] = clampi(int(d.get("heading", offline_heading)), 0, 4095)
	if not d.has("equipment") or typeof(d["equipment"]) != TYPE_ARRAY:
		d["equipment"] = default_equipment_u16()
	if not d.has("stats") or typeof(d["stats"]) != TYPE_DICTIONARY:
		d["stats"] = default_stats()
	return d


func compact_character_dict(character: Dictionary) -> Dictionary:
	return {
		"index": int(character.get("index", -1)),
		"account_slot": int(character.get("account_slot", -1)),
		"object_id": int(character.get("object_id", 0)),
		"name": str(character.get("name", "")),
		"level": int(character.get("level", 0)),
		"class_id": int(character.get("class_id", 0)),
		"class_name": str(character.get("class_name", "")),
		"race_id": int(character.get("race_id", 0)),
		"race_name": str(character.get("race_name", "")),
		"realm": int(character.get("realm", 0)),
		"realm_name": str(character.get("realm_name", "")),
		"gender": int(character.get("gender", 0)),
		"region": int(character.get("region", 0)),
		"model": int(character.get("model", 0)),
		"location": str(character.get("location", "")),
	}


func validate_character_dict(character: Dictionary) -> Dictionary:
	var ok := not character.is_empty() and int(character.get("level", 0)) > 0 and str(character.get("name", "")) != ""
	return {"ok": ok, "name": str(character.get("name", "")), "index": int(character.get("index", -1)), "account_slot": int(character.get("account_slot", -1))}


func character_display_name(character: Dictionary) -> String:
	return "%s L%d %s %s" % [str(character.get("name", "?")), int(character.get("level", 0)), str(character.get("race_name", "Race")), str(character.get("class_name", "Class"))]


func character_slot_summary(character: Dictionary) -> String:
	if character.is_empty():
		return "empty character"
	return "idx=%d slot=%d %s realm=%s region=%d model=%d" % [int(character.get("index", -1)), int(character.get("account_slot", -1)), character_display_name(character), str(character.get("realm_name", "")), int(character.get("region", 0)), int(character.get("model", 0))]


func character_slot_empty_marker(index: int, realm: int = REALM_ALBION) -> Dictionary:
	return {"empty": true, "index": clamp_slot_index(index), "account_slot": account_slot_for_index(index, realm), "realm": clamp_realm(realm)}


func build_character_slot_payload_1127(character: Dictionary) -> PackedByteArray:
	var c := normalize_character_dict(character)
	var out := PackedByteArray()
	out = append_u8(out, int(c.get("level", 1)))
	out = append_pascal_i32_le_string(out, str(c.get("name", "GodotServerDebug")), CHAR_STRING_MAX)
	out = append_u32_le(out, CHAR_STRING_MAX)
	out = append_u8(out, 1)
	out = append_u8(out, int(c.get("eye_size", 0)))
	out = append_u8(out, int(c.get("lip_size", 0)))
	out = append_u8(out, int(c.get("eye_color", 0)))
	out = append_u8(out, int(c.get("hair_color", 0)))
	out = append_u8(out, int(c.get("face_type", 0)))
	out = append_u8(out, int(c.get("hair_style", 0)))
	out = append_u8(out, int(c.get("extension_boots_gloves", 0)))
	out = append_u8(out, int(c.get("extension_torso_hood", 0)))
	out = append_u8(out, int(c.get("customisation_step", 2)))
	out = append_u8(out, int(c.get("mood_type", 0)))
	out = append_zero_fill(out, 13)
	out = append_pascal_i32_le_string(out, str(c.get("location", "Camelot Hills")), CHAR_STRING_MAX)
	out = append_pascal_i32_le_string(out, str(c.get("class_name", "Armsman")), CHAR_STRING_MAX)
	out = append_pascal_i32_le_string(out, str(c.get("race_name", "Briton")), CHAR_STRING_MAX)
	out = append_u16_le(out, int(c.get("model", 50)))
	out = append_u8(out, int(c.get("region", 1)))
	out = append_u8(out, int(c.get("region_expansion", 0)))
	out = append_equipment_u16_list(out, c.get("equipment", default_equipment_u16()) as Array)
	var st: Dictionary = c.get("stats", default_stats()) as Dictionary
	for key in ["strength", "dexterity", "constitution", "quickness", "intelligence", "piety", "empathy", "charisma"]:
		out = append_u8(out, int(st.get(key, 60)))
	return out


func decode_character_slot_payload_1127(payload: PackedByteArray, offset: int, index: int = 0, realm: int = REALM_ALBION) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false, "need_more": true, "next_offset": offset, "character": {}}
	var level := read_u8(payload, offset)
	var pos := offset + 1
	if level <= 0:
		return {"ok": true, "empty": true, "next_offset": pos, "character": character_slot_empty_marker(index, realm)}
	var name := read_pascal_i32_le_string(payload, pos)
	pos = int(name.get("next_offset", pos))
	var declared_name_block := read_u32_le(payload, pos)
	pos += 4
	var appearance := {}
	appearance["always_one"] = read_u8(payload, pos); pos += 1
	appearance["eye_size"] = read_u8(payload, pos); pos += 1
	appearance["lip_size"] = read_u8(payload, pos); pos += 1
	appearance["eye_color"] = read_u8(payload, pos); pos += 1
	appearance["hair_color"] = read_u8(payload, pos); pos += 1
	appearance["face_type"] = read_u8(payload, pos); pos += 1
	appearance["hair_style"] = read_u8(payload, pos); pos += 1
	appearance["extension_boots_gloves"] = read_u8(payload, pos); pos += 1
	appearance["extension_torso_hood"] = read_u8(payload, pos); pos += 1
	appearance["customisation_step"] = read_u8(payload, pos); pos += 1
	appearance["mood_type"] = read_u8(payload, pos); pos += 1
	pos += 13
	var location := read_pascal_i32_le_string(payload, pos)
	pos = int(location.get("next_offset", pos))
	var class_name_data := read_pascal_i32_le_string(payload, pos)
	pos = int(class_name_data.get("next_offset", pos))
	var race_name := read_pascal_i32_le_string(payload, pos)
	pos = int(race_name.get("next_offset", pos))
	var model := read_u16_le(payload, pos); pos += 2
	var region := read_u8(payload, pos); pos += 1
	var region_expansion := read_u8(payload, pos); pos += 1
	var equipment := read_equipment_u16_list(payload, pos, EQUIPMENT_U16_COUNT)
	pos = int(equipment.get("next_offset", pos))
	var stats := {}
	for key in ["strength", "dexterity", "constitution", "quickness", "intelligence", "piety", "empathy", "charisma"]:
		stats[key] = read_u8(payload, pos) if pos < payload.size() else 0
		pos += 1
	var ch := normalize_character_dict({
		"index": index,
		"account_slot": account_slot_for_index(index, realm),
		"name": str(name.get("text", "")),
		"level": level,
		"class_name": str(class_name_data.get("text", "")),
		"race_name": str(race_name.get("text", "")),
		"realm": clamp_realm(realm),
		"region": region,
		"region_expansion": region_expansion,
		"model": model,
		"location": str(location.get("text", "")),
		"equipment": equipment.get("values", []) as Array,
		"stats": stats,
	})
	ch["appearance"] = appearance
	ch["declared_name_block"] = declared_name_block
	return {"ok": true, "empty": false, "next_offset": pos, "character": ch}


func build_missing_slot_payload_1127() -> PackedByteArray:
	return PackedByteArray([0])


func build_character_overview_enriched_payload_1127(character: Dictionary = {}, realm: int = -1, enable_realm_switcher: bool = false) -> PackedByteArray:
	var r := offline_realm if realm < 0 else clamp_realm(realm)
	var source := character
	if source.is_empty():
		source = default_character()
	var c := normalize_character_dict(source)
	var selected_idx := clamp_slot_index(int(c.get("index", offline_selected_index)))
	var out := PackedByteArray()
	out = append_u32_le(out, 1 if enable_realm_switcher else 0)
	out = append_u32_le(out, 0)
	out = append_u32_le(out, 0)
	out = append_u32_le(out, 0)
	for i in range(SLOT_COUNT_1126):
		if i == selected_idx:
			out.append_array(build_character_slot_payload_1127(c))
		else:
			out.append_array(build_missing_slot_payload_1127())
	return out


func build_character_overview_enriched_packet_1127(character: Dictionary = {}, realm: int = -1) -> PackedByteArray:
	var payload := build_character_overview_enriched_payload_1127(character, realm, false)
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("build_server_tcp_packet"):
		return server_fixtures_1127.call("build_server_tcp_packet", SERVER_PACKET_CHARACTER_OVERVIEW_1126, payload) as PackedByteArray
	return build_server_tcp_packet_local(SERVER_PACKET_CHARACTER_OVERVIEW_1126, payload)


func decode_character_overview_enriched_payload_1127(payload: PackedByteArray, realm: int = -1) -> Dictionary:
	var r := offline_realm if realm < 0 else clamp_realm(realm)
	if payload.size() < 16:
		return make_error("decode_character_overview", "payload shorter than 16-byte header")
	var pos := 16
	var chars: Array = []
	var empty_count := 0
	for i in range(SLOT_COUNT_1126):
		var decoded := decode_character_slot_payload_1127(payload, pos, i, r)
		pos = int(decoded.get("next_offset", pos + 1))
		if bool(decoded.get("empty", false)):
			empty_count += 1
		else:
			chars.append(decoded.get("character", {}) as Dictionary)
	last_decoded_characters = chars.duplicate(true)
	return {"ok": true, "realm": r, "realm_name": realm_name_for_id(r), "header_flags": read_u32_le(payload, 0), "slot_count": SLOT_COUNT_1126, "character_count": chars.size(), "empty_count": empty_count, "characters": chars, "next_offset": pos}


func decode_character_overview_enriched_packet_1127(packet: PackedByteArray, realm: int = -1) -> Dictionary:
	var parsed := parse_server_packet_local(packet)
	var payload: PackedByteArray = parsed.get("payload", PackedByteArray()) as PackedByteArray
	parsed["decoded"] = decode_character_overview_enriched_payload_1127(payload, realm)
	return parsed


func character_list_from_overview_packet(packet: PackedByteArray, realm: int = -1) -> Array:
	var dec := decode_character_overview_enriched_packet_1127(packet, realm)
	var body: Dictionary = dec.get("decoded", {}) as Dictionary
	return body.get("characters", []) as Array


func character_count(characters: Array = []) -> int:
	return characters.size()


func get_character_by_index(characters: Array, index: int = 0) -> Dictionary:
	for item in characters:
		var ch: Dictionary = item as Dictionary
		if int(ch.get("index", -1)) == clamp_slot_index(index):
			return ch
	return {}


func get_character_by_account_slot(characters: Array, account_slot: int = 100) -> Dictionary:
	for item in characters:
		var ch: Dictionary = item as Dictionary
		if int(ch.get("account_slot", -1)) == int(account_slot):
			return ch
	return {}


func select_character_by_index(characters: Array, index: int = 0) -> Dictionary:
	var ch := get_character_by_index(characters, index)
	if ch.is_empty():
		make_error("select_character_by_index", "character index not found")
		return {}
	selected_character = normalize_character_dict(ch)
	offline_selected_index = int(selected_character.get("index", 0))
	return selected_character_snapshot()


func select_character_by_account_slot(characters: Array, account_slot: int = 100) -> Dictionary:
	var ch := get_character_by_account_slot(characters, account_slot)
	if ch.is_empty():
		make_error("select_character_by_account_slot", "account slot not found")
		return {}
	selected_character = normalize_character_dict(ch)
	offline_selected_index = int(selected_character.get("index", 0))
	return selected_character_snapshot()


func selected_character_snapshot() -> Dictionary:
	return compact_character_dict(selected_character)


func clear_selection() -> void:
	selected_character.clear()
	last_error.clear()


func has_selection() -> bool:
	return not selected_character.is_empty()


func selection_valid() -> bool:
	return bool(validate_character_dict(selected_character).get("ok", false))


func build_client_select_packet_for_selected(sequence: int = 3, session_id: int = 0) -> PackedByteArray:
	if login_flow_1127 != null and login_flow_1127.has_method("build_character_select_packet_1127"):
		return login_flow_1127.call("build_character_select_packet_1127", int(selected_character.get("index", offline_selected_index)), sequence, session_id) as PackedByteArray
	return PackedByteArray()


func decode_client_select_packet_for_selected(packet: PackedByteArray) -> Dictionary:
	if login_flow_1127 != null and login_flow_1127.has_method("decode_character_select_packet_1127"):
		return login_flow_1127.call("decode_character_select_packet_1127", packet) as Dictionary
	return {"ok": false, "reason": "login_flow_missing"}


func build_server_session_for_selection() -> PackedByteArray:
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("build_session_id_packet_1127"):
		return server_fixtures_1127.call("build_session_id_packet_1127", offline_session_id) as PackedByteArray
	return build_server_tcp_packet_local(SERVER_PACKET_SESSION_ID, append_u16_le(PackedByteArray(), offline_session_id))


func build_bootstrap_position_for_character(character: Dictionary = {}) -> PackedByteArray:
	var source := character
	if source.is_empty():
		if not selected_character.is_empty():
			source = selected_character
		else:
			source = default_character()
	var ch := normalize_character_dict(source)
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("build_position_object_packet_1127"):
		return server_fixtures_1127.call("build_position_object_packet_1127", int(ch.get("object_id", 1)), int(ch.get("x", offline_x)), int(ch.get("y", offline_y)), int(ch.get("z", offline_z)), int(ch.get("heading", offline_heading)), 0) as PackedByteArray
	var payload := PackedByteArray()
	payload = append_u16_be(payload, int(ch.get("object_id", 1)))
	payload = append_u16_be(payload, int(ch.get("z", offline_z)))
	payload = append_u32_be_local(payload, int(ch.get("x", offline_x)))
	payload = append_u32_be_local(payload, int(ch.get("y", offline_y)))
	payload = append_u16_be(payload, int(ch.get("heading", offline_heading)))
	payload = append_u8(payload, 0)
	payload = append_u8(payload, 0)
	return build_server_tcp_packet_local(SERVER_PACKET_POSITION_AND_OBJECT_ID, payload)


func decode_bootstrap_position(packet: PackedByteArray) -> Dictionary:
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("decode_position_object_packet_1127"):
		return server_fixtures_1127.call("decode_position_object_packet_1127", packet) as Dictionary
	return parse_server_packet_local(packet)


func build_offline_bootstrap_flow(character: Dictionary = {}) -> Array:
	var source := character
	if source.is_empty():
		if not selected_character.is_empty():
			source = selected_character
		else:
			source = default_character()
	var ch := normalize_character_dict(source)
	var flow: Array = []
	flow.append({"name": "CharacterOverview1126Enriched", "packet": build_character_overview_enriched_packet_1127(ch, int(ch.get("realm", offline_realm)))})
	flow.append({"name": "CharacterSelectRequestForSelected", "packet": build_client_select_packet_for_selected(3, 0)})
	flow.append({"name": "SessionID", "packet": build_server_session_for_selection()})
	flow.append({"name": "WorldInitRequest", "packet": build_world_init_packet_local(4, 0)})
	flow.append({"name": "PositionAndObjectID", "packet": build_bootstrap_position_for_character(ch)})
	last_bootstrap_snapshot = {"flow_count": flow.size(), "selected": compact_character_dict(ch), "would_move_player": false}
	return flow


func decode_offline_bootstrap_flow(flow: Array) -> Array:
	var out: Array = []
	for item in flow:
		var d: Dictionary = item as Dictionary
		var name := str(d.get("name", "packet"))
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		var decoded := {}
		if name == "CharacterOverview1126Enriched":
			decoded = decode_character_overview_enriched_packet_1127(packet)
		elif name == "PositionAndObjectID":
			decoded = decode_bootstrap_position(packet)
		elif name == "CharacterSelectRequestForSelected":
			decoded = decode_client_select_packet_for_selected(packet)
		else:
			decoded = parse_server_packet_local(packet) if packet.size() >= 3 else {"ok": packet.size() > 0, "raw_size": packet.size()}
		decoded["name"] = name
		out.append(decoded)
	return out


func bootstrap_flow_count(flow: Array) -> int:
	return flow.size()


func bootstrap_flow_summary(flow: Array) -> String:
	var names: Array[String] = []
	for item in flow:
		var d: Dictionary = item as Dictionary
		names.append(str(d.get("name", "packet")))
	return "P1-N5E/F/G bootstrap flow count=%d [%s]" % [flow.size(), ", ".join(names)]


func bootstrap_to_hex_lines(flow: Array, max_bytes: int = 96) -> PackedStringArray:
	var lines := PackedStringArray()
	for item in flow:
		var d: Dictionary = item as Dictionary
		var packet: PackedByteArray = d.get("packet", PackedByteArray()) as PackedByteArray
		lines.append("%s %s" % [str(d.get("name", "packet")), bytes_to_hex(packet, max_bytes)])
	return lines


func apply_bootstrap_to_snapshot(character: Dictionary = {}, position_decoded: Dictionary = {}) -> Dictionary:
	var source := character
	if source.is_empty():
		if not selected_character.is_empty():
			source = selected_character
		else:
			source = default_character()
	var ch := compact_character_dict(normalize_character_dict(source))
	var pos := position_decoded
	if pos.has("decoded"):
		pos = pos.get("decoded", {}) as Dictionary
	var snap := {"would_move_player": false, "reason": "offline bootstrap only", "selected_character": ch, "position": pos}
	last_bootstrap_snapshot = snap.duplicate(true)
	return snap


func can_apply_bootstrap_without_moving_player() -> bool:
	return true


func build_local_ui_model_snapshot(characters: Array = []) -> Dictionary:
	var chars := characters if characters.size() > 0 else last_decoded_characters
	var compact: Array = []
	for item in chars:
		compact.append(compact_character_dict(item as Dictionary))
	return {"screen": "character_select_future", "ui_implemented": false, "character_count": compact.size(), "characters": compact, "selected": selected_character_snapshot()}


func selection_screen_needed_now() -> bool:
	return false


func selection_screen_next_step() -> String:
	return "Après validation P1-N5E/F/G, créer une scène UI minimale branchée sur build_local_ui_model_snapshot()."


func describe_selection_screen_contract() -> String:
	return "UI future: afficher characters[], appeler /dol choose ou select_character_by_index, puis lire selected_character_snapshot; aucun réseau requis."


func normalized_ui_character(character: Dictionary) -> Dictionary:
	var c := normalize_character_dict(character)
	return {
		"character_id": int(c.get("object_id", 0)),
		"index": int(c.get("index", 0)),
		"account_slot": int(c.get("account_slot", 0)),
		"display_name": character_display_name(c),
		"name": str(c.get("name", "")),
		"realm": int(c.get("realm", 0)),
		"realm_name": str(c.get("realm_name", "")),
		"race_id": int(c.get("race_id", 0)),
		"race_name": str(c.get("race_name", "")),
		"class_id": int(c.get("class_id", 0)),
		"class_name": str(c.get("class_name", "")),
		"level": int(c.get("level", 0)),
		"region": int(c.get("region", 0)),
		"location": str(c.get("location", "")),
		"model": int(c.get("model", 0)),
		"equipment_preview": equipment_preview(c.get("equipment", []) as Array),
		"is_selectable": is_character_selectable(c),
		"selection_reason": selection_reason(c),
	}


func equipment_preview(equipment: Array = []) -> Dictionary:
	return {
		"slot_count": equipment.size(),
		"helmet": int(equipment[0]) if equipment.size() > 0 else 0,
		"gloves": int(equipment[1]) if equipment.size() > 1 else 0,
		"boots": int(equipment[2]) if equipment.size() > 2 else 0,
		"right_hand_color": int(equipment[3]) if equipment.size() > 3 else 0,
		"torso": int(equipment[4]) if equipment.size() > 4 else 0,
		"cloak": int(equipment[5]) if equipment.size() > 5 else 0,
		"legs": int(equipment[6]) if equipment.size() > 6 else 0,
		"arms": int(equipment[7]) if equipment.size() > 7 else 0,
		"helmet_color": int(equipment[8]) if equipment.size() > 8 else 0,
		"gloves_color": int(equipment[9]) if equipment.size() > 9 else 0,
		"boots_color": int(equipment[10]) if equipment.size() > 10 else 0,
		"left_hand_color": int(equipment[11]) if equipment.size() > 11 else 0,
		"torso_color": int(equipment[12]) if equipment.size() > 12 else 0,
		"cloak_color": int(equipment[13]) if equipment.size() > 13 else 0,
		"legs_color": int(equipment[14]) if equipment.size() > 14 else 0,
		"arms_color": int(equipment[15]) if equipment.size() > 15 else 0,
		"right_hand": int(equipment[16]) if equipment.size() > 16 else 0,
		"left_hand": int(equipment[17]) if equipment.size() > 17 else 0,
		"two_hand": int(equipment[18]) if equipment.size() > 18 else 0,
		"distance": int(equipment[19]) if equipment.size() > 19 else 0,
		"non_zero_count": count_non_zero_equipment(equipment),
	}


func count_non_zero_equipment(equipment: Array = []) -> int:
	var count := 0
	for item in equipment:
		if int(item) != 0:
			count += 1
	return count


func is_character_selectable(character: Dictionary) -> bool:
	return bool(validate_character_dict(normalize_character_dict(character)).get("ok", false))


func selection_reason(character: Dictionary) -> String:
	if is_character_selectable(character):
		return "selectable"
	if character.is_empty():
		return "empty"
	return "invalid_character_data"


func character_ui_row(character: Dictionary) -> String:
	var c := normalized_ui_character(character)
	return "[%d] %s · %s %s L%d · %s · region=%d model=%d" % [
		int(c.get("index", 0)),
		str(c.get("name", "?")),
		str(c.get("race_name", "Race")),
		str(c.get("class_name", "Class")),
		int(c.get("level", 0)),
		str(c.get("location", "?")),
		int(c.get("region", 0)),
		int(c.get("model", 0)),
	]


func build_character_ui_rows(characters: Array = []) -> PackedStringArray:
	var rows := PackedStringArray()
	var chars := characters if characters.size() > 0 else last_decoded_characters
	for item in chars:
		rows.append(character_ui_row(item as Dictionary))
	return rows


func selection_panel_lines(characters: Array = []) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("P1-N5H/I/J character selection model offline")
	var chars := characters if characters.size() > 0 else last_decoded_characters
	if chars.is_empty():
		lines.append("no parsed characters")
	else:
		for item in chars:
			var ch: Dictionary = item as Dictionary
			var marker := ">" if int(ch.get("index", -1)) == offline_selected_index else " "
			lines.append("%s %s" % [marker, character_ui_row(ch)])
	var selected := selected_character_snapshot()
	lines.append("selected=%s" % (str(selected.get("name", "<none>")) if not selected.is_empty() else "<none>"))
	lines.append("live_server=false real_ui=false apply_default=dry")
	return lines


func selection_panel_text(characters: Array = []) -> String:
	return "\n".join(selection_panel_lines(characters))


func set_selection_from_index(index: int = 0) -> Dictionary:
	var packet := build_character_overview_enriched_packet_1127({}, offline_realm)
	var chars := character_list_from_overview_packet(packet, offline_realm)
	return select_character_by_index(chars, index)


func unselect_character() -> bool:
	clear_selection()
	return true


func selected_character_full_snapshot() -> Dictionary:
	if selected_character.is_empty():
		return {}
	return normalize_character_dict(selected_character).duplicate(true)


func get_bootstrap_position_snapshot(character: Dictionary = {}) -> Dictionary:
	var pkt := build_bootstrap_position_for_character(character)
	return decode_bootstrap_position(pkt)


func dry_apply_bootstrap(character: Dictionary = {}) -> Dictionary:
	var source := character
	if source.is_empty():
		source = selected_character if not selected_character.is_empty() else default_character()
	var ch := normalize_character_dict(source)
	var pos := get_bootstrap_position_snapshot(ch)
	var snap := {
		"ok": true,
		"apply_mode": "dry",
		"would_move_player": false,
		"selected_character": compact_character_dict(ch),
		"position": pos,
		"reason": "dry run only; command must explicitly request real apply",
	}
	last_bootstrap_snapshot = snap.duplicate(true)
	return snap


func apply_bootstrap_to_player(p_player: Node = null, apply_real: bool = false, reason: String = "command") -> Dictionary:
	var source := selected_character if not selected_character.is_empty() else default_character()
	var ch := normalize_character_dict(source)
	if not apply_real:
		var dry := dry_apply_bootstrap(ch)
		dry["reason"] = reason
		return dry
	if p_player == null:
		return make_error("apply_bootstrap_to_player", "player missing")
	p_player.set("daoc_x", float(ch.get("x", offline_x)))
	p_player.set("daoc_y", float(ch.get("y", offline_y)))
	p_player.set("daoc_z", float(ch.get("z", offline_z)))
	p_player.set("heading_deg", heading_units_to_degrees(int(ch.get("heading", offline_heading))))
	if p_player.has_method("_apply_daoc_transform"):
		p_player.call("_apply_daoc_transform")
	var snap := {
		"ok": true,
		"apply_mode": "real_local",
		"would_move_player": true,
		"selected_character": compact_character_dict(ch),
		"x": float(ch.get("x", offline_x)),
		"y": float(ch.get("y", offline_y)),
		"z": float(ch.get("z", offline_z)),
		"heading_deg": heading_units_to_degrees(int(ch.get("heading", offline_heading))),
		"reason": reason,
	}
	last_bootstrap_snapshot = snap.duplicate(true)
	return snap


func make_player_transform_snapshot(p_player: Node = null, label: String = "", reason: String = "") -> Dictionary:
	if p_player == null:
		return {"ok": false, "reason": "player missing", "label": label}
	var snap := {
		"ok": true,
		"label": label,
		"reason": reason,
		"zone": int(p_player.get("daoc_zone")),
		"x": float(p_player.get("daoc_x")),
		"y": float(p_player.get("daoc_y")),
		"z": float(p_player.get("daoc_z")),
		"heading_deg": float(p_player.get("heading_deg")),
		"vertical_velocity_raw": float(p_player.get("vertical_velocity_raw")),
		"movement_state": int(p_player.get("movement_state")),
		"msec": Time.get_ticks_msec(),
	}
	return snap


func bootstrap_target_transform_snapshot(character: Dictionary = {}) -> Dictionary:
	var source := character
	if source.is_empty():
		source = selected_character if not selected_character.is_empty() else default_character()
	var ch := normalize_character_dict(source)
	return {
		"ok": true,
		"zone": int(ch.get("zone", 0)),
		"region": int(ch.get("region", 0)),
		"x": float(ch.get("x", offline_x)),
		"y": float(ch.get("y", offline_y)),
		"z": float(ch.get("z", offline_z)),
		"heading_units": int(ch.get("heading", offline_heading)) & 4095,
		"heading_deg": heading_units_to_degrees(int(ch.get("heading", offline_heading))),
		"selected_character": compact_character_dict(ch),
	}


func validate_player_transform_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if not bool(snapshot.get("ok", false)):
		return false
	for key in ["x", "y", "z", "heading_deg"]:
		if not snapshot.has(key):
			return false
		var v := float(snapshot.get(key, 0.0))
		if is_nan(v) or is_inf(v):
			return false
	return true


func validate_bootstrap_target_snapshot(snapshot: Dictionary) -> bool:
	if not validate_player_transform_snapshot(snapshot):
		return false
	var x := float(snapshot.get("x", 0.0))
	var y := float(snapshot.get("y", 0.0))
	var z := float(snapshot.get("z", 0.0))
	return x >= 0.0 and x <= 16777215.0 and y >= 0.0 and y <= 16777215.0 and z > -100000.0 and z < 1000000.0


func player_transform_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	if before.is_empty() or after.is_empty():
		return {"ok": false, "reason": "missing snapshot"}
	return {
		"ok": true,
		"dx": float(after.get("x", 0.0)) - float(before.get("x", 0.0)),
		"dy": float(after.get("y", 0.0)) - float(before.get("y", 0.0)),
		"dz": float(after.get("z", 0.0)) - float(before.get("z", 0.0)),
		"dheading": float(after.get("heading_deg", 0.0)) - float(before.get("heading_deg", 0.0)),
	}


func apply_transform_snapshot_to_player(p_player: Node = null, snapshot: Dictionary = {}, reason: String = "restore") -> Dictionary:
	if p_player == null:
		return make_error("apply_transform_snapshot_to_player", "player missing")
	if not validate_player_transform_snapshot(snapshot):
		return make_error("apply_transform_snapshot_to_player", "invalid snapshot")
	p_player.set("daoc_zone", int(snapshot.get("zone", int(p_player.get("daoc_zone")))))
	p_player.set("daoc_x", float(snapshot.get("x", 0.0)))
	p_player.set("daoc_y", float(snapshot.get("y", 0.0)))
	p_player.set("daoc_z", float(snapshot.get("z", 0.0)))
	p_player.set("heading_deg", float(snapshot.get("heading_deg", 0.0)))
	p_player.set("vertical_velocity_raw", float(snapshot.get("vertical_velocity_raw", 0.0)))
	if p_player.has_method("_apply_daoc_transform"):
		p_player.call("_apply_daoc_transform")
	var after := make_player_transform_snapshot(p_player, "after_restore", reason)
	after["restored_from"] = snapshot.duplicate(true)
	after["apply_mode"] = "restore_snapshot"
	return after


func safe_real_apply_requires_confirm() -> bool:
	return true


func build_apply_guard_snapshot(p_player: Node = null) -> Dictionary:
	var before := make_player_transform_snapshot(p_player, "current", "guard")
	var target := bootstrap_target_transform_snapshot()
	return {
		"scope": "P1-N6B safe real bootstrap apply guard",
		"safe_real_requires_confirm": safe_real_apply_requires_confirm(),
		"player_present": p_player != null,
		"before_valid": validate_player_transform_snapshot(before),
		"target_valid": validate_bootstrap_target_snapshot(target),
		"rollback_available": can_rollback_last_apply(),
		"before": before,
		"target": target,
	}


func apply_bootstrap_to_player_guarded(p_player: Node = null, confirm_real: bool = false, reason: String = "command") -> Dictionary:
	var guard := build_apply_guard_snapshot(p_player)
	if not confirm_real:
		var denied := dry_apply_bootstrap(selected_character if not selected_character.is_empty() else default_character())
		denied["ok"] = false
		denied["handled"] = true
		denied["guard_denied"] = true
		denied["confirm_required"] = true
		denied["would_move_player"] = false
		denied["apply_mode"] = "real_denied_needs_confirm"
		denied["guard"] = guard
		denied["reason"] = reason
		last_safe_apply_snapshot = denied.duplicate(true)
		return denied
	if p_player == null:
		return make_error("apply_bootstrap_to_player_guarded", "player missing")
	if not bool(guard.get("before_valid", false)):
		return make_error("apply_bootstrap_to_player_guarded", "invalid player snapshot")
	if not bool(guard.get("target_valid", false)):
		return make_error("apply_bootstrap_to_player_guarded", "invalid bootstrap target")
	last_pre_apply_player_snapshot = (guard.get("before", {}) as Dictionary).duplicate(true)
	var applied := apply_bootstrap_to_player(p_player, true, reason)
	var after := make_player_transform_snapshot(p_player, "after_real_apply", reason)
	applied["handled"] = true
	applied["guard"] = guard
	applied["before_player"] = last_pre_apply_player_snapshot.duplicate(true)
	applied["after_player"] = after
	applied["delta"] = player_transform_delta(last_pre_apply_player_snapshot, after)
	applied["rollback_available"] = validate_player_transform_snapshot(last_pre_apply_player_snapshot)
	last_safe_apply_snapshot = applied.duplicate(true)
	return applied


func rollback_last_player_apply(p_player: Node = null, reason: String = "command") -> Dictionary:
	if p_player == null:
		return make_error("rollback_last_player_apply", "player missing")
	if not validate_player_transform_snapshot(last_pre_apply_player_snapshot):
		return make_error("rollback_last_player_apply", "no valid rollback snapshot")
	var before_rollback := make_player_transform_snapshot(p_player, "before_rollback", reason)
	var restored := apply_transform_snapshot_to_player(p_player, last_pre_apply_player_snapshot, reason)
	var after_rollback := make_player_transform_snapshot(p_player, "after_rollback", reason)
	var snap := {
		"ok": bool(restored.get("ok", false)),
		"handled": true,
		"apply_mode": "rollback",
		"before_rollback": before_rollback,
		"after_rollback": after_rollback,
		"restored_to": last_pre_apply_player_snapshot.duplicate(true),
		"delta_after_restore": player_transform_delta(last_pre_apply_player_snapshot, after_rollback),
		"reason": reason,
	}
	last_rollback_player_snapshot = snap.duplicate(true)
	last_bootstrap_snapshot = snap.duplicate(true)
	return snap


func can_rollback_last_apply() -> bool:
	return validate_player_transform_snapshot(last_pre_apply_player_snapshot)


func get_last_safe_apply_snapshot() -> Dictionary:
	return last_safe_apply_snapshot.duplicate(true)


func last_rollback_snapshot() -> Dictionary:
	return last_rollback_player_snapshot.duplicate(true)


func clear_apply_guard_snapshots() -> void:
	last_safe_apply_snapshot.clear()
	last_pre_apply_player_snapshot.clear()
	last_rollback_player_snapshot.clear()


func p1_n6b_scope() -> String:
	return "P1-N6B offline: guarded real bootstrap apply requires explicit confirm, stores pre-apply player snapshot, supports local rollback; no network."


func heading_units_to_degrees(units: int) -> float:
	# P1-112 : cap DOL -> moteur, +90 degres (DaocHeading).
	return preload("res://src/daoc/world/DaocHeading.gd").raw_to_motor_deg(int(units))


func bootstrap_apply_contract() -> String:
	return "P1-N6A offline: dry by default; real local player move only via explicit command /dol applybootstrap real."


func bootstrap_ready_snapshot() -> Dictionary:
	var flow := build_offline_bootstrap_flow(selected_character if not selected_character.is_empty() else default_character())
	return {"ready": flow.size() >= 5 and selection_valid(), "flow_count": flow.size(), "selected": selected_character_snapshot(), "apply_default": "dry"}


func is_real_player_move_default() -> bool:
	return false


func can_apply_bootstrap_to_player(p_player: Node = null) -> bool:
	return p_player != null and selection_valid()


func build_selection_state_snapshot() -> Dictionary:
	var chars := last_decoded_characters
	if chars.is_empty():
		var packet := build_character_overview_enriched_packet_1127({}, offline_realm)
		chars = character_list_from_overview_packet(packet, offline_realm)
	return {
		"scope": "P1-N5I/J character model and selection state offline",
		"character_count": chars.size(),
		"selected_index": offline_selected_index,
		"has_selection": has_selection(),
		"selection_valid": selection_valid(),
		"selected": selected_character_snapshot(),
		"ui_model": build_selection_hud_model(chars),
	}


func build_selection_hud_model(characters: Array = []) -> Dictionary:
	var chars := characters if characters.size() > 0 else last_decoded_characters
	var compact: Array = []
	for item in chars:
		compact.append(normalized_ui_character(item as Dictionary))
	return {
		"screen": "character_select_text_hud",
		"ui_implemented": false,
		"real_ui_final": false,
		"character_count": compact.size(),
		"characters": compact,
		"selected": normalized_ui_character(selected_character) if not selected_character.is_empty() else {},
		"commands": ["/dol charhud", "/dol choose <index>", "/dol selected", "/dol bootstrap", "/dol applybootstrap dry"],
	}


func describe_source_basis() -> String:
	return "P1-N5E/F/G source basis: PacketLib1126.SendCharacterOverview, CharacterSelectRequestHandler, WorldInitRequestHandler, PacketLib1124/174 PositionAndObjectID vocabulary."


func p1_n5efg_scope() -> String:
	return "P1-N5E/F/G offline character overview enriched + local selection + enter-world bootstrap; no live server; no real UI yet."


func is_live_server_required() -> bool:
	return false


func is_real_ui_implemented() -> bool:
	return false


func can_build_enriched_charlist() -> bool:
	return true


func status_snapshot() -> Dictionary:
	var source := selected_character
	if source.is_empty():
		source = default_character()
	var pkt := build_character_overview_enriched_packet_1127(source, offline_realm)
	var chars := character_list_from_overview_packet(pkt, offline_realm)
	return {
		"scope": "P1-N5E/F/G character overview/select/bootstrap offline",
		"selected_index": offline_selected_index,
		"realm": realm_name_for_id(offline_realm),
		"character_count": chars.size(),
		"selected": selected_character_snapshot(),
		"can_build": can_build_enriched_charlist(),
		"live_server_required": false,
		"real_ui_implemented": false,
		"selection_screen_needed_now": selection_screen_needed_now(),
		"p1_n6b": build_apply_guard_snapshot(null),
		"last_safe_apply": last_safe_apply_snapshot.duplicate(true),
		"last_rollback": last_rollback_player_snapshot.duplicate(true),
		"last_error": last_error.duplicate(true),
	}


func last_error_snapshot() -> Dictionary:
	return last_error.duplicate(true)


func clear_last_error() -> void:
	last_error.clear()


func make_error(code: String, message: String) -> Dictionary:
	last_error = {"ok": false, "code": code, "message": message}
	return last_error.duplicate(true)


func get_function_names() -> PackedStringArray:
	return PackedStringArray([
		"reset_bootstrap_profile", "setup_bootstrap", "set_server_fixtures_1127", "set_login_flow_1127", "configure_character_fixture", "configure_selection", "set_debug_enabled", "is_debug_enabled", "default_character", "default_character_name", "sanitize_text", "clamp_realm", "clamp_slot_index", "realm_base_account_slot", "account_slot_for_index", "index_for_account_slot", "realm_name_for_id", "realm_id_for_name", "class_name_for_id", "race_name_for_id", "gender_name_for_id", "ascii_bytes", "bytes_to_ascii", "append_u8", "append_u16_le", "append_u16_be", "append_u32_le", "read_u8", "read_u16_le", "read_u16_be", "read_u32_le", "append_pascal_i32_le_string", "read_pascal_i32_le_string", "append_zero_fill", "append_equipment_u16_list", "read_equipment_u16_list", "normalize_character_dict", "compact_character_dict", "validate_character_dict", "character_display_name", "character_slot_summary", "character_slot_empty_marker", "build_character_slot_payload_1127", "decode_character_slot_payload_1127", "build_missing_slot_payload_1127", "build_character_overview_enriched_payload_1127", "build_character_overview_enriched_packet_1127", "decode_character_overview_enriched_payload_1127", "decode_character_overview_enriched_packet_1127", "character_list_from_overview_packet", "character_count", "get_character_by_index", "get_character_by_account_slot", "select_character_by_index", "select_character_by_account_slot", "selected_character_snapshot", "clear_selection", "has_selection", "selection_valid", "build_client_select_packet_for_selected", "decode_client_select_packet_for_selected", "build_server_session_for_selection", "build_bootstrap_position_for_character", "decode_bootstrap_position", "build_offline_bootstrap_flow", "decode_offline_bootstrap_flow", "bootstrap_flow_count", "bootstrap_flow_summary", "bootstrap_to_hex_lines", "apply_bootstrap_to_snapshot", "can_apply_bootstrap_without_moving_player", "build_local_ui_model_snapshot", "normalized_ui_character", "equipment_preview", "count_non_zero_equipment", "is_character_selectable", "selection_reason", "character_ui_row", "build_character_ui_rows", "selection_panel_lines", "selection_panel_text", "set_selection_from_index", "unselect_character", "selected_character_full_snapshot", "get_bootstrap_position_snapshot", "dry_apply_bootstrap", "apply_bootstrap_to_player", "make_player_transform_snapshot", "bootstrap_target_transform_snapshot", "validate_player_transform_snapshot", "validate_bootstrap_target_snapshot", "player_transform_delta", "apply_transform_snapshot_to_player", "safe_real_apply_requires_confirm", "build_apply_guard_snapshot", "apply_bootstrap_to_player_guarded", "rollback_last_player_apply", "can_rollback_last_apply", "get_last_safe_apply_snapshot", "last_rollback_snapshot", "clear_apply_guard_snapshots", "p1_n6b_scope", "heading_units_to_degrees", "bootstrap_apply_contract", "bootstrap_ready_snapshot", "is_real_player_move_default", "can_apply_bootstrap_to_player", "build_selection_state_snapshot", "build_selection_hud_model", "selection_screen_needed_now", "selection_screen_next_step", "describe_selection_screen_contract", "describe_source_basis", "p1_n5efg_scope", "is_live_server_required", "is_real_ui_implemented", "can_build_enriched_charlist", "status_snapshot", "last_error_snapshot", "clear_last_error", "make_error", "get_function_names", "default_equipment_u16", "default_stats", "build_server_tcp_packet_local", "parse_server_packet_local", "build_world_init_packet_local", "append_u32_be_local", "bytes_to_hex"
	])


func default_equipment_u16() -> Array:
	var values: Array = []
	for _i in range(EQUIPMENT_U16_COUNT):
		values.append(0)
	values[0] = 101
	values[4] = 110
	values[16] = 500
	return values


func default_stats() -> Dictionary:
	return {"strength": 60, "dexterity": 60, "constitution": 60, "quickness": 60, "intelligence": 60, "piety": 60, "empathy": 60, "charisma": 60}


func build_server_tcp_packet_local(packet_id: int, payload: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out = append_u16_be(out, payload.size())
	out = append_u8(out, packet_id)
	out.append_array(payload)
	return out


func parse_server_packet_local(packet: PackedByteArray) -> Dictionary:
	if server_fixtures_1127 != null and server_fixtures_1127.has_method("parse_server_tcp_packet") and packet.size() >= 3:
		return server_fixtures_1127.call("parse_server_tcp_packet", packet) as Dictionary
	if packet.size() < 3:
		return {"ok": false, "reason": "short", "payload": PackedByteArray()}
	var size := read_u16_be(packet, 0)
	var total := 3 + size
	return {"ok": packet.size() >= total, "data_size": size, "total_size": total, "packet_id": read_u8(packet, 2), "payload": packet.slice(3, mini(packet.size(), total))}


func build_world_init_packet_local(sequence: int = 4, session_id: int = 0) -> PackedByteArray:
	if login_flow_1127 != null and login_flow_1127.has_method("build_world_init_packet_1127"):
		return login_flow_1127.call("build_world_init_packet_1127", sequence, session_id) as PackedByteArray
	return PackedByteArray()


func append_u32_be_local(data: PackedByteArray, v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(data)
	var n := int(v) & 0xffffffff
	out.append((n >> 24) & 0xff)
	out.append((n >> 16) & 0xff)
	out.append((n >> 8) & 0xff)
	out.append(n & 0xff)
	return out


func bytes_to_hex(data: PackedByteArray, max_bytes: int = 96) -> String:
	var parts: Array[String] = []
	var n := mini(data.size(), maxi(0, max_bytes))
	for i in range(n):
		parts.append("%02X" % (int(data[i]) & 0xff))
	if data.size() > n:
		parts.append("...")
	return " ".join(parts)
