extends RefCounted
class_name DaocOpenDaocTrainerCodec

## P1-107 — l entraineur, tel que DOL et le client d origine se parlent.
##
##   Serveur 0x7B TrainerWindow (PacketLib1105.SendTrainerWindow) : PLUSIEURS
##   paquets, l octet 2 dit lequel :
##     code 0 : u8 nombre, u8 points de spe, 0, 0, puis par spe u8 index,
##              u8 niveau, u8 niveau + 1, nom Pascal ;
##     code 1 : u8 nombre, u8 points de royaume, 1, 0, puis par capacite u8
##              index, u8 niveau, u8 cout du prochain niveau, nom Pascal
##              (entre crochets si les prerequis manquent) ;
##     code 4 : noms des competences d une spe (u8 nombre, u8 points, 4, 0,
##              u8 index de depart, noms Pascal) ;
##     code 3 : descriptions (niveau minimum, autotrain...) - conserve brut.
##   Le serveur les envoie quand on parle a un entraineur (GameTrainer.Interact)
##   ou sur un 0x7B client (TrainWindowHandler, 1 octet ; refuse sans
##   entraineur cible sauf ALLOW_TRAIN_ANYWHERE).
##
##   Client 0x53 TrainHandler, 0x108 = 264 octets (game.dll FUN_0042b461, puis
##   htonl) : 8 x u32 index de spe termines par 0xFFFFFFFF, 8 x u32 niveaux
##   vises (dans le meme ordre), 50 x u32 niveaux vises de capacites de
##   royaume (index = position dans la liste code 1, 0 = rien). DOL ne
##   forme que si le niveau vise depasse l actuel, et c est lui qui compte
##   les points (train.cs : /train <ligne> <niveau> fait la meme chose).

const OPCODE_TRAINER_WINDOW := 0x7B
const OPCODE_TRAIN := 0x53
const CODE_SPECS := 0
const CODE_REALM_ABILITIES := 1
const CODE_DESCRIPTIONS := 3
const CODE_NAMES := 4
const TRAIN_SLOTS := 8
const RA_SLOTS := 50


static func decode_trainer_window(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 4:
		return {"ok": false, "error": "trainer_window_too_short"}
	var count := int(payload[0])
	var points := int(payload[1])
	var code := int(payload[2])
	var out := {"ok": true, "code": code, "count": count, "points": points}
	var offset := 4
	if code == CODE_SPECS or code == CODE_REALM_ABILITIES:
		var entries: Array = []
		for i in range(count):
			if offset + 3 > payload.size():
				return {"ok": false, "error": "trainer_entry_truncated", "index": i}
			var name := _pascal(payload, offset + 3)
			if not bool(name.get("ok", false)):
				return {"ok": false, "error": "trainer_name_truncated", "index": i}
			var text := str(name["text"])
			var entry := {"index": int(payload[offset]), "level": int(payload[offset + 1]), "name": text}
			if code == CODE_SPECS:
				entry["next_level"] = int(payload[offset + 2])
				entry["name"] = text
			else:
				entry["cost"] = int(payload[offset + 2])
				entry["available"] = not text.begins_with("[")
				entry["name"] = text.trim_prefix("[").trim_suffix("]")
			entries.append(entry)
			offset = int(name["next"])
		out["kind"] = "specs" if code == CODE_SPECS else "realm_abilities"
		out["entries"] = entries
	elif code == CODE_NAMES:
		if offset >= payload.size():
			return {"ok": false, "error": "trainer_names_truncated"}
		var start := int(payload[offset])
		offset += 1
		var names: Array = []
		for i in range(count):
			var name := _pascal(payload, offset)
			if not bool(name.get("ok", false)):
				return {"ok": false, "error": "trainer_skill_name_truncated", "index": i}
			names.append(str(name["text"]))
			offset = int(name["next"])
		out["kind"] = "skill_names"
		out["start_index"] = start
		out["names"] = names
	else:
		out["kind"] = "descriptions" if code == CODE_DESCRIPTIONS else "code_%d" % code
		out["raw"] = payload.slice(4).hex_encode()
		offset = payload.size()
	out["trailing_bytes"] = payload.size() - offset
	return out


## `spec_targets` : index de spe -> niveau vise ; `ra_targets` : index de
## capacite -> niveau vise. Rend les 264 octets du 0x53.
static func build_train_payload(spec_targets: Dictionary, ra_targets: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var indices: Array = spec_targets.keys()
	indices.sort()
	for slot in range(TRAIN_SLOTS):
		if slot < indices.size():
			_w32(out, int(indices[slot]))
		else:
			_w32(out, 0xFFFFFFFF if slot == indices.size() else 0)
	for slot in range(TRAIN_SLOTS):
		_w32(out, int(spec_targets.get(indices[slot], 0)) if slot < indices.size() else 0)
	for slot in range(RA_SLOTS):
		_w32(out, int(ra_targets.get(slot, 0)))
	return out


## Cout classique d un niveau de spe : le niveau vise lui-meme (DOL
## Specialization : monter de L a L+1 coute L+1 points). Sert a l AFFICHAGE
## de la fenetre, le serveur reste juge.
static func spec_training_cost(current_level: int, target_level: int) -> int:
	var cost := 0
	for level in range(current_level + 1, target_level + 1):
		cost += level
	return cost


## Encodeurs pour les suites a faux pair.
static func encode_specs(points: int, specs: Array) -> PackedByteArray:
	var out := PackedByteArray([specs.size(), points, CODE_SPECS, 0])
	for i in specs.size():
		var s := specs[i] as Dictionary
		out.append(i)
		out.append(int(s.get("level", 0)))
		out.append(int(s.get("level", 0)) + 1)
		_write_pascal(out, str(s.get("name", "")))
	return out


static func encode_realm_abilities(points: int, abilities: Array) -> PackedByteArray:
	var out := PackedByteArray([abilities.size(), points, CODE_REALM_ABILITIES, 0])
	for i in abilities.size():
		var a := abilities[i] as Dictionary
		out.append(i)
		out.append(int(a.get("level", 0)))
		out.append(int(a.get("cost", 1)))
		var name := str(a.get("name", ""))
		_write_pascal(out, name if bool(a.get("available", true)) else "[%s]" % name)
	return out


static func _pascal(payload: PackedByteArray, offset: int) -> Dictionary:
	if offset >= payload.size():
		return {"ok": false}
	var size := int(payload[offset])
	if offset + 1 + size > payload.size():
		return {"ok": false}
	return {"ok": true, "text": payload.slice(offset + 1, offset + 1 + size).get_string_from_ascii(), "next": offset + 1 + size}


static func _write_pascal(out: PackedByteArray, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	out.append(bytes.size() & 0xff)
	out.append_array(bytes)


static func _w32(out: PackedByteArray, v: int) -> void:
	out.append((v >> 24) & 0xff)
	out.append((v >> 16) & 0xff)
	out.append((v >> 8) & 0xff)
	out.append(v & 0xff)
