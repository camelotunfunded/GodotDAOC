extends RefCounted
class_name DaocRealmAbilityRules

## P1-109 — l EFFET des capacites de royaume passives, tel que DOL le calcule
## (`realmabilities/handlers/*`, bareme USE_NEW_PASSIVES_RAS_SCALING — celui
## des serveurs 1.90+ dont Eden). Le serveur en ligne les applique lui-meme
## et le 0xFB les montre (P1-106) ; ceci sert l arbitre HORS LIGNE, qui n en
## savait rien. Les actives (Purge, Ignore Pain, MoC...) restent des
## competences 0xBB : elles n ont pas de valeur permanente a porter ici.
##
##   RAStatEnhancer (Augmented Str/Dex/Con/Qui/Acuity) : 4 8 12 17 22 28 34 41 48
##   Toughness (MaxHealth, plat)               : 25 50 75 100 150 200 250 325 400
##   Mastery of Pain (crit melee %)            : 3 6 9 13 17 22 27 33 39
##   Wild Power (crit sort %)                  : idem
##   Mastery of Magery (degats de sort %)      : 2 3 4 6 8 10 12 14 16
##   Mastery of Parrying / Blocking (%)        : 2 4 6 9 12 15 18 21 25
##   Avoidance of Magic (6 resists magiques)   : 2 3 5 7 10 12 15 17 20
##   Physical Defense (3 resists melee)        : idem
##   Determination (duree mez/stun/snare -%)   : 4 8 12 17 23 30 38 46 55
##   Long Wind (cout du sprint -%)             : 20 40 60 80 100
##   Lifter (charge +%)                        : 10 20 30 40 50 60 70 80 90
##   Serenity (regen de mana)                  : 1 2 3 5 7
##   Ethereal Bond (MaxMana, plat)             : bareme des stats
##   Mastery of Healing (soins %)              : bareme de Magery
##   Wild Healing (crit soin %)                : bareme de Pain
##   Mastery of Focus (niveau de sort)         : 3 6 9 13 17 22 27 33 39

const STAT_LEVELS := [0, 4, 8, 12, 17, 22, 28, 34, 41, 48]
const TOUGHNESS_LEVELS := [0, 25, 50, 75, 100, 150, 200, 250, 325, 400]
const CRIT_LEVELS := [0, 3, 6, 9, 13, 17, 22, 27, 33, 39]
const MAGERY_LEVELS := [0, 2, 3, 4, 6, 8, 10, 12, 14, 16]
const DEFENSE_SKILL_LEVELS := [0, 2, 4, 6, 9, 12, 15, 18, 21, 25]
const RESIST_LEVELS := [0, 2, 3, 5, 7, 10, 12, 15, 17, 20]
const DETERMINATION_LEVELS := [0, 4, 8, 12, 17, 23, 30, 38, 46, 55]
const LONG_WIND_LEVELS := [0, 20, 40, 60, 80, 100]
const LIFTER_LEVELS := [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
const SERENITY_LEVELS := [0, 1, 2, 3, 5, 7]

const MAGIC_RESISTS := ["Body", "Cold", "Energy", "Heat", "Matter", "Spirit"]
const MELEE_RESISTS := ["Crush", "Slash", "Thrust"]

## nom DOL (tel que le 0x7B code 1 l ecrit) -> {table, properties | resists}
const PASSIVES := {
	"Augmented Strength": {"table": STAT_LEVELS, "properties": ["Strength"]},
	"Augmented Dexterity": {"table": STAT_LEVELS, "properties": ["Dexterity"]},
	"Augmented Constitution": {"table": STAT_LEVELS, "properties": ["Constitution"]},
	"Augmented Quickness": {"table": STAT_LEVELS, "properties": ["Quickness"]},
	"Augmented Acuity": {"table": STAT_LEVELS, "properties": ["Acuity"]},
	"Toughness": {"table": TOUGHNESS_LEVELS, "properties": ["MaxHealth"]},
	"Ethereal Bond": {"table": STAT_LEVELS, "properties": ["MaxMana"]},
	"Mastery of Pain": {"table": CRIT_LEVELS, "properties": ["CriticalMeleeHitChance"]},
	"Mastery of Archery": {"table": CRIT_LEVELS, "properties": ["CriticalArcheryHitChance"]},
	"Wild Power": {"table": CRIT_LEVELS, "properties": ["CriticalSpellHitChance"]},
	"Wild Healing": {"table": CRIT_LEVELS, "properties": ["CriticalHealHitChance"]},
	"Mastery of Magery": {"table": MAGERY_LEVELS, "properties": ["SpellDamage"]},
	"Mastery of Healing": {"table": MAGERY_LEVELS, "properties": ["HealingEffectiveness"]},
	"Mastery of Focus": {"table": CRIT_LEVELS, "properties": ["SpellLevel"]},
	"Mastery of Parrying": {"table": DEFENSE_SKILL_LEVELS, "properties": ["ParryChance"]},
	"Mastery of Blocking": {"table": DEFENSE_SKILL_LEVELS, "properties": ["BlockChance"]},
	"Avoidance of Magic": {"table": RESIST_LEVELS, "resists": MAGIC_RESISTS},
	"Physical Defense": {"table": RESIST_LEVELS, "resists": MELEE_RESISTS},
	"Determination": {"table": DETERMINATION_LEVELS, "properties": ["MesmerizeDurationReduction", "StunDurationReduction", "SpeedDecreaseDurationReduction"]},
	"Long Wind": {"table": LONG_WIND_LEVELS, "properties": ["SprintCostReduction"]},
	"Lifter": {"table": LIFTER_LEVELS, "properties": ["CarryBonus"]},
	"Serenity": {"table": SERENITY_LEVELS, "properties": ["PowerRegenerationRate"]},
}


static func is_passive(name: String) -> bool:
	return PASSIVES.has(name)


static func amount_for_level(name: String, level: int) -> int:
	if not PASSIVES.has(name) or level <= 0:
		return 0
	var table: Array = (PASSIVES[name] as Dictionary)["table"]
	return int(table[mini(level, table.size() - 1)])


## `abilities` : nom -> niveau. Rend {properties: {}, resists: {}, applied: [], ignored: []}.
static func bonuses_for(abilities: Dictionary) -> Dictionary:
	var properties: Dictionary = {}
	var resists: Dictionary = {}
	var applied: Array = []
	var ignored: Array = []
	for key in abilities.keys():
		var name := str(key)
		var level := int(abilities[key])
		if not PASSIVES.has(name):
			if level > 0:
				ignored.append(name)
			continue
		var amount := amount_for_level(name, level)
		if amount <= 0:
			continue
		var rule: Dictionary = PASSIVES[name]
		for property in rule.get("properties", []):
			properties[str(property)] = int(properties.get(str(property), 0)) + amount
		for resist in rule.get("resists", []):
			resists[str(resist)] = int(resists.get(str(resist), 0)) + amount
		applied.append({"name": name, "level": level, "amount": amount})
	return {"properties": properties, "resists": resists, "applied": applied, "ignored": ignored}
