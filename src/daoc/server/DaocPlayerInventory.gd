extends RefCounted
class_name DaocPlayerInventory

## P1-93 — l'inventaire du joueur, cote AUTORITE.
##
## Jusqu'ici le personnage etait presente DEJA EQUIPE : la scene du Lab cuisait
## la panoplie dans ses textures, et l'arbitre lisait l'equipement de depart du
## metier comme s'il etait porte. Rien ne passait par un sac.
##
## Ici, la panoplie de depart entre dans le SAC (logements 40..79, comme
## `eInventorySlot.FirstBackpack..LastBackpack`), et les logements d'equipement
## restent VIDES tant que le joueur n'equipe pas. Equiper deplace l'objet du sac
## vers le logement que son `Item_Type` declare ; l'objet deja porte revient
## dans le sac. C'est l'arbitre qui decide, jamais le client : le client
## demande `equip`/`unequip` et recoit un instantane.
##
## L'objet garde le format de l'index P1-24 (`id_nb`, `model`, `item_type`,
## `object_type`, `dps_af`, `spd_abs`...) : c'est deja celui que
## `DaocLocalServerVitals` sait traduire en arme, armure et bouclier.

const StarterEquipmentScript = preload("res://src/daoc/gameplay/items/DaocStarterEquipmentIndex.gd")

const SLOT_RIGHT_HAND := 10
const SLOT_LEFT_HAND := 11
const SLOT_TWO_HAND := 12
const SLOT_DISTANCE := 13
const SLOT_HEAD := 21
const SLOT_HANDS := 22
const SLOT_FEET := 23
const SLOT_JEWELRY := 24
const SLOT_TORSO := 25
const SLOT_CLOAK := 26
const SLOT_LEGS := 27
const SLOT_ARMS := 28
const SLOT_NECK := 29
const SLOT_WAIST := 32
const SLOT_LEFT_BRACER := 33
const SLOT_RIGHT_BRACER := 34
const SLOT_LEFT_RING := 35
const SLOT_RIGHT_RING := 36
const FIRST_BACKPACK := 40
const LAST_BACKPACK := 79

const EQUIPMENT_SLOTS := [
	SLOT_RIGHT_HAND, SLOT_LEFT_HAND, SLOT_TWO_HAND, SLOT_DISTANCE,
	SLOT_HEAD, SLOT_HANDS, SLOT_FEET, SLOT_JEWELRY, SLOT_TORSO, SLOT_CLOAK,
	SLOT_LEGS, SLOT_ARMS, SLOT_NECK, SLOT_WAIST, SLOT_LEFT_BRACER, SLOT_RIGHT_BRACER,
	SLOT_LEFT_RING, SLOT_RIGHT_RING,
]
const ARMOR_SLOTS := [SLOT_HEAD, SLOT_HANDS, SLOT_FEET, SLOT_TORSO, SLOT_LEGS, SLOT_ARMS]
const OBJECT_TYPE_SHIELD := 42

## `Item_Type` d'un objet a deux mains vaut 12 ; a une main 10 ; bouclier 11.
## Les bracelets et anneaux declarent un seul type pour deux logements : le
## second est pris si le premier est occupe.
const PAIRED_SLOTS := {SLOT_LEFT_BRACER: SLOT_RIGHT_BRACER, SLOT_LEFT_RING: SLOT_RIGHT_RING}

var _slots: Dictionary = {}
var _revision: int = 0
var _source: String = "empty"


func clear() -> void:
	_slots.clear()
	_revision += 1
	_source = "empty"


## La panoplie de depart du metier, dans le SAC. `auto_equip` la porte tout de
## suite : c'est l'ancien comportement (P1-24), conserve pour les suites qui
## mesurent le combat avec l'epee et le bouclier en main.
func seed_starter_kit(class_id: int, auto_equip: bool = false, index: RefCounted = null) -> Dictionary:
	clear()
	var source: RefCounted = index
	if source == null:
		source = StarterEquipmentScript.new()
		if not source.load_index():
			return {"ok": false, "reason": source.error, "items": 0}
	var placed := 0
	var equipped := 0
	for value in source.items_for_class(class_id):
		var item := (value as Dictionary).duplicate(true)
		var slot := first_free_backpack_slot()
		if slot < 0:
			break
		_slots[slot] = item
		placed += 1
	if auto_equip:
		for slot in backpack_slots_in_use():
			if bool(equip_from_backpack(slot).get("ok", false)):
				equipped += 1
	_source = "starter_kit_class_%d" % class_id
	_revision += 1
	return {"ok": placed > 0, "items": placed, "equipped": equipped, "class_id": class_id}


func item_at(slot: int) -> Dictionary:
	return (_slots.get(slot, {}) as Dictionary).duplicate(true)


func has_item(slot: int) -> bool:
	return _slots.has(slot)


func first_free_backpack_slot() -> int:
	for slot in range(FIRST_BACKPACK, LAST_BACKPACK + 1):
		if not _slots.has(slot):
			return slot
	return -1


func backpack_slots_in_use() -> Array:
	var out: Array = []
	for slot in range(FIRST_BACKPACK, LAST_BACKPACK + 1):
		if _slots.has(slot):
			out.append(slot)
	return out


## Le logement qu'un objet occupe une fois porte, d'apres son `Item_Type`.
static func target_slot_for(item: Dictionary) -> int:
	var declared := int(item.get("item_type", 0))
	if EQUIPMENT_SLOTS.has(declared):
		return declared
	return -1


## Equiper depuis le sac. L'objet deja porte revient dans le logement du sac
## libere, ce qui fait de l'echange une operation sans perte.
func equip_from_backpack(from_slot: int) -> Dictionary:
	if from_slot < FIRST_BACKPACK or from_slot > LAST_BACKPACK or not _slots.has(from_slot):
		return {"ok": false, "reason": "rien dans ce logement du sac", "from_slot": from_slot}
	var item := _slots[from_slot] as Dictionary
	var target := target_slot_for(item)
	if target < 0:
		return {"ok": false, "reason": "objet non equipable (Item_Type %d)" % int(item.get("item_type", 0)), "from_slot": from_slot}
	if PAIRED_SLOTS.has(target) and _slots.has(target) and not _slots.has(int(PAIRED_SLOTS[target])):
		target = int(PAIRED_SLOTS[target])
	var previous: Dictionary = _slots.get(target, {}) as Dictionary
	_slots.erase(from_slot)
	_slots[target] = item
	if not previous.is_empty():
		_slots[from_slot] = previous
	_revision += 1
	return {"ok": true, "from_slot": from_slot, "to_slot": target, "item": item.duplicate(true),
		"swapped_out": previous.duplicate(true)}


## Retirer un objet porte vers le sac.
func unequip(slot: int) -> Dictionary:
	if not EQUIPMENT_SLOTS.has(slot) or not _slots.has(slot):
		return {"ok": false, "reason": "rien de porte a cet emplacement", "slot": slot}
	var free := first_free_backpack_slot()
	if free < 0:
		return {"ok": false, "reason": "sac plein", "slot": slot}
	var item := _slots[slot] as Dictionary
	_slots.erase(slot)
	_slots[free] = item
	_revision += 1
	return {"ok": true, "from_slot": slot, "to_slot": free, "item": item.duplicate(true)}


## Depose un objet dans le premier logement libre du sac (butin, marchand).
func add_to_backpack(item: Dictionary) -> int:
	var slot := first_free_backpack_slot()
	if slot < 0:
		return -1
	_slots[slot] = item.duplicate(true)
	_revision += 1
	return slot


func equipped() -> Dictionary:
	var out: Dictionary = {}
	for slot in EQUIPMENT_SLOTS:
		if _slots.has(slot):
			out[slot] = (_slots[slot] as Dictionary).duplicate(true)
	return out


## L'arme qui frappe : la deux-mains si elle est portee seule, sinon la main
## droite. Vide = mains nues, et la chaine de degats prend la branche
## `GameLiving` (DOL_CODE_LIVING_BRANCH) — c'est un vrai cas, pas un repli.
func active_weapon() -> Dictionary:
	if _slots.has(SLOT_RIGHT_HAND):
		return (_slots[SLOT_RIGHT_HAND] as Dictionary).duplicate(true)
	if _slots.has(SLOT_TWO_HAND):
		return (_slots[SLOT_TWO_HAND] as Dictionary).duplicate(true)
	return {}


func shield() -> Dictionary:
	var left: Dictionary = _slots.get(SLOT_LEFT_HAND, {}) as Dictionary
	if int(left.get("object_type", 0)) == OBJECT_TYPE_SHIELD:
		return left.duplicate(true)
	return {}


func armor_by_slot() -> Dictionary:
	var out: Dictionary = {}
	for slot in ARMOR_SLOTS:
		if _slots.has(slot):
			out[slot] = (_slots[slot] as Dictionary).duplicate(true)
	return out


func revision() -> int:
	return _revision


func snapshot() -> Dictionary:
	var slots: Dictionary = {}
	for slot in _slots.keys():
		slots[int(slot)] = (_slots[slot] as Dictionary).duplicate(true)
	return {
		"revision": _revision,
		"source": _source,
		"slots": slots,
		"equipped": equipped(),
		"backpack": backpack_slots_in_use(),
		"weapon": active_weapon(),
		"shield": shield(),
	}


## P1-121 — le logement de l arme qui frappe (celui d active_weapon), -1 a mains nues.
func active_weapon_slot() -> int:
	if _slots.has(SLOT_RIGHT_HAND):
		return SLOT_RIGHT_HAND
	if _slots.has(SLOT_TWO_HAND):
		return SLOT_TWO_HAND
	return -1


## P1-121 — l arbitre remplace un objet use ou repare, sans le deplacer.
func replace_item(slot: int, item: Dictionary) -> bool:
	if not _slots.has(slot):
		return false
	_slots[slot] = item.duplicate(true)
	_revision += 1
	return true
