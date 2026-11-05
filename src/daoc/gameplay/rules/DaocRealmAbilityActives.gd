class_name DaocRealmAbilityActives
extends RefCounted

## P1-125 — les capacites de royaume ACTIVES, portees de DOL
## (GameServer/realmabilities/handlers), bareme USE_NEW_ACTIVES_RAS_SCALING
## (cinq niveaux, celui que P1-109 a retenu pour les passives). Chaque entree :
## genre, valeurs par niveau, delai de reutilisation (secondes), duree (ms),
## et les etats qui interdisent l'activation (CheckPreconditions).

const TABLE := {
	"Purge": {"kind": "purge", "values": [5, 0, 0, 0, 0], "reuse": [900, 900, 600, 450, 300]},
	"Second Wind": {"kind": "endurance_full", "reuse": [900, 600, 300, 210, 120]},
	"Raging Power": {"kind": "mana_percent", "values": [25, 35, 50, 65, 80], "reuse": [600, 600, 600, 600, 600]},
	"First Aid": {"kind": "health_percent", "values": [25, 40, 60, 80, 100], "reuse": [180, 180, 180, 180, 180], "no_combat": true},
	"Ignore Pain": {"kind": "health_percent", "values": [20, 35, 50, 65, 80], "reuse": [900, 900, 900, 900, 900]},
	"Mastery of Concentration": {"kind": "effect", "effect": "interrupt_immune", "values": [25, 35, 50, 60, 75], "duration": 30000, "reuse": [600, 600, 600, 600, 600]},
	"Charge": {"kind": "effect", "effect": "charge", "values": [0, 0, 0, 0, 0], "duration": 15000, "reuse": [900, 600, 300, 180, 90]},
	"Adrenaline Rush": {"kind": "effect", "effect": "adrenaline_rush", "values": [100, 100, 100, 100, 100], "duration": 20000, "reuse": [1200, 900, 600, 450, 300]},
	"Volcanic Pillar": {"kind": "damage_target", "values": [200, 350, 500, 625, 750], "range": 1500, "reuse": [900, 900, 900, 900, 900]},
	"Anger of the Gods": {"kind": "effect", "effect": "damage_add", "values": [10, 15, 20, 25, 30], "duration": 30000, "reuse": [600, 600, 600, 600, 600]},
	"Barrier of Fortitude": {"kind": "effect", "effect": "damage_decrease", "values": [10, 15, 20, 30, 40], "duration": 30000, "reuse": [600, 600, 600, 600, 600]},
	"The Empty Mind": {"kind": "effect", "effect": "magic_resist", "values": [10, 15, 20, 25, 30], "duration": 45000, "reuse": [600, 600, 600, 600, 600]},
	"Speed of Sound": {"kind": "effect", "effect": "speed_of_sound", "values": [10000, 20000, 30000, 45000, 60000], "reuse": [600, 600, 600, 600, 600]},
}


static func definition(name: String) -> Dictionary:
	for key in TABLE.keys():
		if str(key).nocasecmp_to(name) == 0:
			var out := (TABLE[key] as Dictionary).duplicate(true)
			out["name"] = str(key)
			return out
	return {}


static func value_at(entry: Dictionary, level: int) -> int:
	var values: Array = entry.get("values", []) as Array
	return int(values[clampi(level, 1, values.size()) - 1]) if not values.is_empty() else 0


static func reuse_seconds(entry: Dictionary, level: int) -> int:
	var reuse: Array = entry.get("reuse", [600]) as Array
	return int(reuse[clampi(level, 1, reuse.size()) - 1])
