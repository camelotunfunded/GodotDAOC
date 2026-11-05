extends RefCounted
class_name DaocPlayerQuickbarState

const BAR_COUNT := 3
const SLOT_COUNT := 10

var character_key: String = "default"
var slots: Dictionary = {}


func setup(p_character_key: String) -> DaocPlayerQuickbarState:
	character_key = p_character_key.strip_edges() if p_character_key.strip_edges() != "" else "default"
	return self


func assign_spell(bar_index: int, slot_index: int, spell_id: int, line_name: String,
		available_spells: Array) -> Dictionary:
	return assign_entry(bar_index, slot_index,
		{"kind": "spell", "spell_id": spell_id, "line": line_name}, available_spells)


func assign_entry(bar_index: int, slot_index: int, requested: Dictionary,
		available_entries: Array) -> Dictionary:
	if not _valid_slot(bar_index, slot_index):
		return {"ok": false, "reason": "emplacement invalide"}
	# P1-105 : une MACRO (/macro nom commande) : le client d origine la garde
	# dans la quickbar, le serveur n en sait rien ; l activer envoie la commande.
	if str(requested.get("kind", "")) == "macro":
		var command := str(requested.get("command", "")).strip_edges()
		if command == "":
			return {"ok": false, "reason": "macro sans commande"}
		var macro_reference := {"kind": "macro", "name": str(requested.get("name", command)), "command": command}
		slots[_key(bar_index, slot_index)] = macro_reference
		return {"ok": true, "bar": bar_index, "slot": slot_index, "reference": macro_reference.duplicate(true)}
	# P1-98 : un OBJET (arme equipee ou objet du sac) : la reference est son
	# logement d inventaire ; le serveur decide de ce qu un clic en fait (0x71).
	if str(requested.get("kind", "")) == "item":
		var inventory_slot := int(requested.get("inventory_slot", requested.get("slot", -1)))
		if inventory_slot < 0:
			return {"ok": false, "reason": "objet sans logement"}
		var item_reference := {"kind": "item", "inventory_slot": inventory_slot,
			"name": str(requested.get("name", "")), "model": int(requested.get("model", 0)),
			"use_type": int(requested.get("use_type", 0))}
		slots[_key(bar_index, slot_index)] = item_reference
		return {"ok": true, "bar": bar_index, "slot": slot_index, "reference": item_reference.duplicate(true)}
	var learned: Dictionary = {}
	for value in available_entries:
		var entry := value as Dictionary
		var same_spell := int(entry.get("spell_id", 0)) > 0 \
			and int(entry.get("spell_id", 0)) == int(requested.get("spell_id", 0)) \
			and str(entry.get("line", "")) == str(requested.get("line", ""))
		var same_ability := str(entry.get("ability_id", "")) != "" \
			and str(entry.get("ability_id", "")) == str(requested.get("ability_id", ""))
		if same_spell or same_ability:
			learned = entry
			break
	if learned.is_empty():
		return {"ok": false, "reason": "capacite indisponible"}
	var reference := {
		"kind": str(learned.get("kind", "spell")),
		"spell_id": int(learned.get("spell_id", 0)), "line": str(learned.get("line", learned.get("path", ""))),
		"ability_id": str(learned.get("ability_id", "")),
		"name": str(learned.get("name", "")), "client_effect": int(learned.get("client_effect", 0)),
	}
	slots[_key(bar_index, slot_index)] = reference
	return {"ok": true, "bar": bar_index, "slot": slot_index, "reference": reference.duplicate(true)}


func clear_slot(bar_index: int, slot_index: int) -> Dictionary:
	if not _valid_slot(bar_index, slot_index):
		return {"ok": false, "reason": "emplacement invalide"}
	slots.erase(_key(bar_index, slot_index))
	return {"ok": true}


func slot(bar_index: int, slot_index: int) -> Dictionary:
	return (slots.get(_key(bar_index, slot_index), {}) as Dictionary).duplicate(true)


func build_use_intent(bar_index: int, slot_index: int, target_id: int) -> Dictionary:
	var reference := slot(bar_index, slot_index)
	if reference.is_empty():
		return {"ok": false, "reason": "emplacement vide"}
	if str(reference.get("kind", "")) == "macro":
		return {"ok": true, "kind": "run_macro", "command": str(reference.get("command", "")), "name": str(reference.get("name", ""))}
	if str(reference.get("kind", "")) == "item":
		return {"ok": true, "kind": "use_item", "target_id": target_id,
			"inventory_slot": int(reference.get("inventory_slot", -1)), "use_type": int(reference.get("use_type", 0)),
			"name": str(reference.get("name", ""))}
	if str(reference.get("ability_id", "")) != "":
		var intent_kind := "use_champion_ability" if str(reference.get("ability_id", "")).begins_with("cl:") else "use_master_level_ability"
		return {"ok": true, "kind": intent_kind, "target_id": target_id,
			"ability_id": str(reference.get("ability_id", "")), "path": str(reference.get("line", ""))}
	return {"ok": true, "kind": "use_spell", "target_id": target_id,
		"spell_id": int(reference.get("spell_id", 0)), "line": str(reference.get("line", ""))}


func save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "sauvegarde inaccessible"}
	file.store_string(JSON.stringify({"version": 1, "character": character_key, "slots": slots}, "\t"))
	file.close()
	return {"ok": true, "assigned": slots.size()}


func load(path: String) -> Dictionary:
	slots.clear()
	if not FileAccess.file_exists(path):
		return {"ok": true, "assigned": 0, "new_file": true}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "sauvegarde illisible"}
	var payload := parsed as Dictionary
	if str(payload.get("character", "")) != character_key:
		return {"ok": false, "reason": "sauvegarde d'un autre personnage"}
	var stored := payload.get("slots", {}) as Dictionary
	for key in stored.keys():
		var parts := str(key).split(":")
		if parts.size() == 2 and _valid_slot(int(parts[0]), int(parts[1])):
			slots[str(key)] = (stored[key] as Dictionary).duplicate(true)
	return {"ok": true, "assigned": slots.size()}


func _valid_slot(bar_index: int, slot_index: int) -> bool:
	return bar_index >= 0 and bar_index < BAR_COUNT and slot_index >= 0 and slot_index < SLOT_COUNT


func _key(bar_index: int, slot_index: int) -> String:
	return "%d:%d" % [bar_index, slot_index]


## P1-105 — la premiere case libre d une barre, ou -1.
func first_empty_slot(bar_index: int) -> int:
	for slot_index in range(SLOT_COUNT):
		if slot(bar_index, slot_index).is_empty():
			return slot_index
	return -1
