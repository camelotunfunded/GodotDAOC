extends RefCounted
class_name DaocOnlineInventoryController

const InventoryCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocInventoryCodec.gd")
const EconomyCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocEconomyCodec.gd")

signal inventory_changed(snapshot: Dictionary)
signal equipment_request_ready(packet: PackedByteArray, plan: Dictionary)
## P1-122 : le coffre, le coffre de maison et la consignation arrivent par le
## MEME 0x02, aux logements 110..249 (OpenDAoC FirstVault / HousingInventory) ;
## ils vivent a part pour ne jamais se meler au sac.
signal external_inventory_changed(window: Dictionary)

var _codec: RefCounted = InventoryCodecScript.new()
var _slots: Dictionary = {}
var _last_error := ""
var _pending_equipment: Dictionary = {}
## P1-95 : VisibleActiveWeaponSlots du dernier 0x02 (-1 = jamais recu).
var _active_weapon_slots := -1
var _window_type := -1
var _external_slots: Dictionary = {}
var _external_window_type := -1


func ingest_server_packet(packet: PackedByteArray) -> Dictionary:
	var update: Dictionary = _codec.call("decode_inventory_update_packet", packet) as Dictionary
	if not bool(update.get("ok", false)):
		_last_error = str(update.get("error", "inventory_decode_failed"))
		return {"ok": false, "error": _last_error}
	if update.has("active_weapon_slots"):
		_active_weapon_slots = int(update.get("active_weapon_slots", -1))
		_window_type = int(update.get("window_type", -1))
	var window_type := int(update.get("window_type", -1))
	var external_touched := EconomyCodecScript.is_external_window(window_type)
	if external_touched:
		# Ouvrir une fenetre envoie tout son contenu : l ancien est oublie.
		_external_window_type = window_type
		_external_slots.clear()
	for raw in update.get("items", []):
		var item := raw as Dictionary
		var slot := int(item.get("slot", -1))
		if EconomyCodecScript.is_external_slot(slot):
			external_touched = true
			if bool(item.get("empty", false)):
				_external_slots.erase(slot)
			else:
				_external_slots[slot] = item.duplicate(true)
			continue
		if bool(item.get("empty", false)):
			_slots.erase(slot)
		else:
			_slots[slot] = item.duplicate(true)
	_reconcile_pending_equipment()
	if external_touched:
		external_inventory_changed.emit(external_snapshot())
	var result := snapshot()
	inventory_changed.emit(result)
	return result


func prepare_staff_equipment(sequence: int, session_id: int, parameter: int = 0) -> Dictionary:
	if _slots.has(InventoryCodecScript.SLOT_TWO_HAND):
		var equipped := _slots[InventoryCodecScript.SLOT_TWO_HAND] as Dictionary
		if int(equipped.get("object_type", -1)) == InventoryCodecScript.OBJECT_TYPE_STAFF:
			return {"ok": true, "already_equipped": true, "item": equipped.duplicate(true)}
	var inventory := {"ok": true, "items": _slots.values()}
	var candidate: Dictionary = _codec.call("find_staff_to_equip", inventory) as Dictionary
	if not bool(candidate.get("ok", false)):
		return candidate
	var packet: PackedByteArray = _codec.call(
		"build_move_item_packet", 0, int(candidate["to_slot"]), int(candidate["from_slot"]),
		1, sequence, session_id, parameter
	) as PackedByteArray
	if packet.is_empty():
		return {"ok": false, "error": "equipment_packet_build_failed"}
	_pending_equipment = candidate.duplicate(true)
	_pending_equipment["state"] = "awaiting_server_inventory_update"
	var plan := _pending_equipment.duplicate(true)
	equipment_request_ready.emit(packet, plan)
	return {"ok": true, "packet": packet, "plan": plan}


func snapshot() -> Dictionary:
	var items: Array[Dictionary] = []
	var ordered_slots: Array = _slots.keys()
	ordered_slots.sort()
	for slot in ordered_slots:
		items.append((_slots[slot] as Dictionary).duplicate(true))
	return {
		"ok": true,
		"items": items,
		"occupied_slot_count": items.size(),
		"staff_equipped": _slot_contains_staff(InventoryCodecScript.SLOT_TWO_HAND),
		"pending_equipment": _pending_equipment.duplicate(true),
		"last_error": _last_error,
		"active_weapon_slots": _active_weapon_slots,
		"window_type": _window_type,
	}


func _reconcile_pending_equipment() -> void:
	if _pending_equipment.is_empty():
		return
	var from_slot := int(_pending_equipment.get("from_slot", -1))
	var to_slot := int(_pending_equipment.get("to_slot", -1))
	if not _slots.has(from_slot) and _slot_contains_staff(to_slot):
		_pending_equipment["state"] = "confirmed_by_server"


func _slot_contains_staff(slot: int) -> bool:
	return _slots.has(slot) and int((_slots[slot] as Dictionary).get("object_type", -1)) == InventoryCodecScript.OBJECT_TYPE_STAFF


func external_snapshot() -> Dictionary:
	var items: Array = []
	var ordered: Array = _external_slots.keys()
	ordered.sort()
	for slot in ordered:
		items.append((_external_slots[slot] as Dictionary).duplicate(true))
	return {"window_type": _external_window_type, "items": items}
