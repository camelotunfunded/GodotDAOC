extends RefCounted
class_name DaocCombatEnums

const ATTACK_UNKNOWN: String = "Unknown"
const ATTACK_MELEE_ONE_HAND: String = "MeleeOneHand"
const ATTACK_MELEE_DUAL_WIELD: String = "MeleeDualWield"
const ATTACK_MELEE_HAND_TO_HAND: String = "MeleeHandToHand"
const ATTACK_MELEE_TWO_HAND: String = "MeleeTwoHand"
const ATTACK_RANGED: String = "Ranged"
const ATTACK_SPELL: String = "Spell"

const RESULT_ANY: String = "Any"
const RESULT_HIT_UNSTYLED: String = "HitUnstyled"
const RESULT_HIT_STYLE: String = "HitStyle"
const RESULT_MISSED: String = "Missed"
const RESULT_BLOCKED: String = "Blocked"
const RESULT_EVADED: String = "Evaded"
const RESULT_FUMBLED: String = "Fumbled"
const RESULT_PARRIED: String = "Parried"
const RESULT_OUT_OF_RANGE: String = "OutOfRange"
const RESULT_RESISTED: String = "SpellResisted"

const DAMAGE_NATURAL: String = "Natural"
const DAMAGE_CRUSH: String = "Crush"
const DAMAGE_SLASH: String = "Slash"
const DAMAGE_THRUST: String = "Thrust"
const DAMAGE_HEAT: String = "Heat"
const DAMAGE_COLD: String = "Cold"
const DAMAGE_MATTER: String = "Matter"
const DAMAGE_BODY: String = "Body"
const DAMAGE_SPIRIT: String = "Spirit"
const DAMAGE_ENERGY: String = "Energy"

const SPELL_DIRECT_DAMAGE: String = "DirectDamage"
const SPELL_DAMAGE_OVER_TIME: String = "DamageOverTime"
const SPELL_BOLT: String = "Bolt"
const SPELL_HEAL: String = "Heal"
const SPELL_DAMAGE_SPEED_DECREASE: String = "DamageSpeedDecrease"
const SPELL_DAMAGE_ADD: String = "DamageAdd"
const SPELL_DAMAGE_SHIELD: String = "DamageShield"

static func is_melee_attack(attack_type: String) -> bool:
	return attack_type in [ATTACK_MELEE_ONE_HAND, ATTACK_MELEE_DUAL_WIELD, ATTACK_MELEE_HAND_TO_HAND, ATTACK_MELEE_TWO_HAND]

## P1-24 — `eDamageType`, GameServer/GlobalConstants.cs:299.
##
## LES DUMPS PARLENT EN NOMBRES. `mob.sql` porte `MeleeDamageType` et
## `itemtemplate` porte `Type_Damage`, tous deux ENTIERS. Jusqu'ici un `2` passait
## par `str()` et ressortait « 2 » : un type de dégâts qui ne correspond à aucune
## résistance, donc une résistance jamais appliquée — et rien ne le disait.
##
## La numérotation n'est pas continue : 0 à 3 pour le physique, puis un trou
## jusqu'à 10 pour le magique. Une table, pas un calcul.
const DAMAGE_TYPE_BY_ID := {
	0: DAMAGE_NATURAL,
	1: DAMAGE_CRUSH,
	2: DAMAGE_SLASH,
	3: DAMAGE_THRUST,
	10: DAMAGE_BODY,
	11: DAMAGE_COLD,
	12: DAMAGE_ENERGY,
	13: DAMAGE_HEAT,
	14: DAMAGE_MATTER,
	15: DAMAGE_SPIRIT,
}


static func canonical_damage_type(value: Variant) -> String:
	# Un ENTIER est un `eDamageType`, jamais un nom. Le tester AVANT la
	# conversion en chaîne est ce qui empêche « 2 » de sortir tel quel.
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var id := int(value)
		if DAMAGE_TYPE_BY_ID.has(id):
			return str(DAMAGE_TYPE_BY_ID[id])
	var t = str(value).strip_edges()
	if t.is_valid_int() and DAMAGE_TYPE_BY_ID.has(int(t)):
		return str(DAMAGE_TYPE_BY_ID[int(t)])
	if t == "":
		return DAMAGE_NATURAL
	var lower = t.to_lower()
	match lower:
		"crush", "blunt": return DAMAGE_CRUSH
		"slash", "slashing": return DAMAGE_SLASH
		"thrust", "pierce", "piercing": return DAMAGE_THRUST
		"heat", "fire": return DAMAGE_HEAT
		"cold", "ice": return DAMAGE_COLD
		"matter": return DAMAGE_MATTER
		"body": return DAMAGE_BODY
		"spirit": return DAMAGE_SPIRIT
		"energy": return DAMAGE_ENERGY
		_: return t
