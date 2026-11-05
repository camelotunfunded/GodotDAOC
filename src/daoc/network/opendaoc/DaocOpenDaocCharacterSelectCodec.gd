extends RefCounted

const PacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const ChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")

const CHARACTER_SELECT_OPCODE := 0x10
const LOGIN_GRANTED_OPCODE := 0x2A
const SESSION_ID_OPCODE := 0x28
const TARGET_NAME := "Heyvena"

var _packet_codec: RefCounted = PacketCodecScript.new()
var _checksum: RefCounted = ChecksumScript.new()


func build_character_select_payload_1125(_character: Dictionary) -> PackedByteArray:
	# Reuses DaocOpenDaocTcpLoginProbe.build_character_select_request_payload:
	# this validated 1.125a/OpenDAoC profile sends no payload for 0x10.
	return PackedByteArray()


func build_character_select_packet_1125(character: Dictionary, sequence: int, session_id: int, parameter: int) -> PackedByteArray:
	var payload := build_character_select_payload_1125(character)
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", CHARACTER_SELECT_OPCODE, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	return _packet_codec.call("build_client_packet", CHARACTER_SELECT_OPCODE, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray


## Source-derived OpenDAoC Version1125 branch:
## ReadByte(type), Skip(1), ReadString(24). This is used by P1-20C so the
## server really loads Heyveno before WorldInit. The legacy empty P1-20B
## builder above remains unchanged for regression evidence.
func build_character_select_payload_named_1125(character: Dictionary) -> PackedByteArray:
	var name_bytes: PackedByteArray = _packet_codec.call("encode_windows_1252", str(character.get("name", ""))) as PackedByteArray
	if name_bytes.is_empty() or name_bytes.size() > 24:
		return PackedByteArray()
	var payload := PackedByteArray([0, 0])
	payload.append_array(name_bytes)
	while payload.size() < 26:
		payload.append(0)
	return payload


func build_character_select_packet_named_1125(character: Dictionary, sequence: int, session_id: int, parameter: int) -> PackedByteArray:
	var payload := build_character_select_payload_named_1125(character)
	if payload.size() != 26:
		return PackedByteArray()
	var unsigned: PackedByteArray = _packet_codec.call("build_client_packet", CHARACTER_SELECT_OPCODE, payload, sequence, session_id, parameter, 0) as PackedByteArray
	var checksum_value := int(_checksum.call("compute_checksum", unsigned.slice(0, unsigned.size() - 2)))
	return _packet_codec.call("build_client_packet", CHARACTER_SELECT_OPCODE, payload, sequence, session_id, parameter, checksum_value) as PackedByteArray


## 2026-09-27 (retour utilisateur : « je dois pouvoir me connecter avec tous
## les persos de la liste ») — la validation du JEU. Celle d en dessous, stricte,
## verrouillait Heyvena seule (nom exact, emplacement 5, Wizard avalonienne) :
## tout autre personnage rendait `invalid_character`. Elle reste pour les sondes
## et les suites. Ici on ne refuse que ce qui ne peut pas partir dans le 0x10 :
## un nom vide ou de plus de 24 octets, un emplacement vide, un royaume hors 1..3.
## Le serveur reste juge du reste.
func validate_selectable_character(character: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var name := str(character.get("name", "")).strip_edges()
	var realm := int(character.get("realm_id", 0))
	if name == "":
		errors.append("name_missing")
	elif (_packet_codec.call("encode_windows_1252", name) as PackedByteArray).size() > 24:
		errors.append("name_longer_than_24_bytes")
	if bool(character.get("empty", false)):
		errors.append("empty_slot")
	if realm != 0 and (realm < 1 or realm > 3):
		errors.append("realm_out_of_range")
	return {"ok": errors.is_empty(), "errors": errors, "name": name,
		"slot": int(character.get("slot", character.get("slot_index", -1))), "realm_id": realm}


func validate_character_select_data(character: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var name := str(character.get("name", ""))
	var slot := int(character.get("slot", character.get("slot_index", -1)))
	var realm := int(character.get("realm_id", 0))
	var race_name := str(character.get("race_name", character.get("race", "")))
	var race_id := int(character.get("race_id", 0))
	var class_label := str(character.get("class_name", character.get("class", "")))
	var class_id := int(character.get("class_id", 0))
	var model := int(character.get("current_model", 0))
	var race_gender := int(character.get("race_and_gender", -1))
	if name != TARGET_NAME:
		errors.append("name_must_be_exact_Heyvena")
	if slot != 5:
		errors.append("slot_must_be_five")
	if realm != 1:
		errors.append("realm_must_be_albion")
	if race_name.to_lower() != "avalonian" and race_id != 2:
		errors.append("race_must_be_avalonian")
	if class_label.to_lower() != "wizard" and class_id != 7:
		errors.append("class_must_be_wizard")
	# P1-94 : 64 = Avalonienne (PlayerRace DOL). 42 etait une Highlander, valeur
	# envoyee a la creation par erreur ; le serveur a ete corrige le 2026-09-21
	# et l overview renvoie 64 depuis. 42 reste tolere pour un compte non corrige.
	# P1-112 : 65 est la bonne valeur (Avalonian Female) ; 64 (male) et 42 sont
	# toleres pour un compte pas encore corrige en base.
	if model != 0 and model != 65 and model != 64 and model != 42:
		errors.append("model_must_be_avalonian_female_65_when_present")
	if race_gender >= 0 and ((race_gender >> 4) & 1) != 1:
		errors.append("gender_must_be_female_when_present")
	var female: Variant = null
	if race_gender >= 0:
		female = ((race_gender >> 4) & 1) == 1
	return {
		"ok": errors.is_empty(), "errors": errors, "name": name, "slot": slot,
		"realm_id": realm, "race_name": race_name, "race_id": race_id,
		"class_name": class_label, "class_id": class_id, "current_model": model,
		"female": female,
	}


func select_heyveno_from_overview(overview: Dictionary) -> Dictionary:
	var characters := overview.get("characters", []) as Array
	var matches: Array[Dictionary] = []
	for raw in characters:
		var character := raw as Dictionary
		if str(character.get("name", "")).to_lower() == TARGET_NAME.to_lower():
			matches.append(character.duplicate(true))
	if matches.is_empty():
		return {"ok": false, "verdict": "ABORTED_HEYVENO_NOT_FOUND", "heyveno_match_count": 0}
	if matches.size() > 1:
		return {"ok": false, "verdict": "ABORTED_DUPLICATE_HEYVENO", "heyveno_match_count": matches.size()}
	var selected := matches[0]
	var slot := int(selected.get("slot", selected.get("slot_index", -1)))
	if slot != 5:
		return {"ok": false, "verdict": "ABORTED_SLOT_MISMATCH", "heyveno_match_count": 1, "character": selected}
	var validation := validate_character_select_data(selected)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "verdict": "ABORTED_CHARACTER_DATA_MISMATCH", "heyveno_match_count": 1, "character": selected, "validation": validation}
	return {"ok": true, "verdict": "READY_TO_SELECT", "heyveno_match_count": 1, "character": selected, "validation": validation}


func decode_session_id_packet(packet: PackedByteArray) -> Dictionary:
	var parsed: Dictionary = _packet_codec.call("parse_server_packet", packet) as Dictionary
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error": parsed.get("parse_status", "invalid_server_packet"), "session_id_value_redacted": true}
	if int(parsed.get("opcode", -1)) != SESSION_ID_OPCODE:
		return {"ok": false, "error": "unexpected_opcode", "opcode": int(parsed.get("opcode", -1)), "session_id_value_redacted": true}
	if int(parsed.get("payload_size", -1)) != 2 or int(parsed.get("total_size", -1)) != 5 or packet.size() != 5:
		return {"ok": false, "error": "session_id_payload_size_must_equal_2", "session_id_payload_size": int(parsed.get("payload_size", -1)), "session_id_value_redacted": true}
	var payload := parsed.get("payload", PackedByteArray()) as PackedByteArray
	var value := int(_packet_codec.call("u16_le_read", payload, 0))
	return {
		"ok": true, "opcode": SESSION_ID_OPCODE, "session_id": value,
		"session_id_received": true, "session_id_payload_size": 2,
		"session_id_nonzero": value != 0, "session_id_value_redacted": true,
		"checksum_present": false, "checksum_status": "not_present_server_to_client",
	}


func describe_character_select_offsets_1125() -> Array[Dictionary]:
	return [{
		"offset": "none", "size": 0, "field": "payload", "value": "empty",
		"endianness": "n/a",
		"source": "DaocOpenDaocTcpLoginProbe.build_character_select_request_payload",
		"confidence": "PROJECT-VALIDATED / SERVER-RESPONSE-INDEPENDENT",
	}]


func fixture_heyveno() -> Dictionary:
	return {
		"name": "Heyveno", "slot": 0, "realm_id": 1, "race_name": "Briton",
		"class_id": 2, "class_name": "Armsman", "race_and_gender": 0x11,
		"current_model": 35, "level": 1, "region_id": 51, "location": "Gothwaite Harbor",
	}
