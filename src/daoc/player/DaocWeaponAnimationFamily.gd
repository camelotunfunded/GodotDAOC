extends RefCounted
class_name DaocWeaponAnimationFamily

## P1-130 — le clip de combat suit l ARME EN MAIN, pour toutes les classes.
##
## Sources, rien de memoire :
## - `gamedata/canims.csv` : familles de combat du client d origine (Att Med/Low/
##   High generiques, 1HT, 2H, Pole, Staff, Dual, H2H, Scy ; C-Idle 2H / Pole /
##   Staff / Bow / H2H / Scy ; Parry 1H / Pole / 2H, Evade 1H / Pole / 2H) ;
## - `DOLSharp-master/GameServer/GlobalConstants.cs` eObjectType : 2 Crushing,
##   3 Slashing, 4 Thrust, 6 TwoHanded, 7 Polearm, 8 Staff, 9 Longbow,
##   10 Crossbow, 11 Sword, 12 Hammer, 13 Axe, 14 Spear, 15 CompositeBow,
##   16 Thrown, 17 LeftAxe, 18 RecurvedBow, 19 Blades, 20 Blunt, 21 Piercing,
##   22 LargeWeapons, 23 CelticSpear, 24 Flexible, 25 HandToHand, 26 Scythe,
##   27 FistWraps, 28 MaulerStaff, 42 Shield ;
## - noms de clips : bibliotheque du catalogue exportee par le Lab (P1-130,
##   `attack_staff_med`, `combat_idle_2h`, `parry_pole_low`…).
## Une famille sans clip retombe sur les clips generiques : jamais de geste vide.

const STAFF_TYPES := [8, 28]
const TWO_HAND_TYPES := [6, 22]
const POLE_TYPES := [7, 14, 23]
const SCYTHE_TYPES := [26]
const H2H_TYPES := [25, 27]
const THRUST_TYPES := [4, 21]
const BOW_TYPES := [5, 9, 10, 15, 18]
const SHIELD_TYPE := 42
const FIRST_WEAPON := 1
const LAST_WEAPON := 28


## `items` : eInventorySlot -> objet (`object_type`, `hand` : 1 = deux mains
## dans le 0x02) ; `active` : octet VisibleActiveWeaponSlots (-1 inconnu).
static func family_for(items: Dictionary, active: int) -> String:
	var right_slot := active & 0x0f if active >= 0 else -1
	var left_slot := (active >> 4) & 0x0f if active >= 0 else -1
	if active < 0:
		right_slot = 2 if not items.has(10) and items.has(12) else 0
		left_slot = 1
	if right_slot == 3:
		return "bow"
	var main: Dictionary = items.get(10 + right_slot, {}) as Dictionary if right_slot >= 0 and right_slot <= 3 else {}
	var type := int(main.get("object_type", 0))
	if main.is_empty():
		return "h2h" if right_slot == 0 else ""
	if STAFF_TYPES.has(type):
		return "staff"
	if POLE_TYPES.has(type):
		return "pole"
	if SCYTHE_TYPES.has(type):
		return "scythe"
	if H2H_TYPES.has(type):
		return "h2h"
	if BOW_TYPES.has(type):
		return "bow"
	if TWO_HAND_TYPES.has(type) or right_slot == 2 or int(main.get("hand", 0)) == 1:
		return "2h"
	var left: Dictionary = items.get(11, {}) as Dictionary if left_slot == 1 else {}
	var left_type := int(left.get("object_type", 0))
	if left_type >= FIRST_WEAPON and left_type <= LAST_WEAPON:
		return "dual"
	if THRUST_TYPES.has(type):
		return "1ht"
	return ""


static func attack_clips(family: String, swing_index: int) -> Array:
	var heights := ["med", "high", "low"]
	var out: Array = []
	for i in heights.size():
		var height := str(heights[(swing_index + i) % heights.size()])
		if family != "" and family != "bow":
			out.append("attack_%s_%s" % [family, height])
		out.append("attack_%s" % height)
	return out


## Le baton n a pas de parade propre dans canims.csv : celle des deux mains
## (Parry 2H) est un CHOIX, a corriger si une capture dit mieux.
static func defense_clips(family: String, result: String) -> Array:
	var suffix := {"2h": "2h", "staff": "2h", "pole": "pole", "scythe": "pole"}.get(family, "") as String
	match result:
		"Parried":
			return (["parry_%s_high" % suffix, "parry_%s_low" % suffix] if suffix != "" else []) + ["parry_high", "parry_low"]
		"Evaded":
			return (["evade_%s" % suffix] if suffix != "" else []) + ["evade"]
		"Blocked":
			return ["block_high", "block_low"]
	return []


static func combat_idle_clip(family: String) -> String:
	return "combat_idle_%s" % family if family in ["2h", "staff", "pole", "scythe", "h2h", "bow"] else "combat_idle"
