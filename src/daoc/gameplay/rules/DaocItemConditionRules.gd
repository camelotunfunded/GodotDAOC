class_name DaocItemConditionRules
extends RefCounted

## P1-121 — l'usure et la reparation des objets, portees de DOL.
##
## Usure : `GameInventoryItem.OnStrikeTarget` (l'arme, a chaque coup porte,
## rate, pare ou maladroit) et `OnStruckByEnemy` (la piece d'armure touchee,
## le bouclier qui bloque). Seulement au-dessus de 70 % de condition, avec la
## chance `item_condition_loss_chance` (5 % par defaut, ServerProperties.cs).
## Perte = con(joueur, objet) + 4, con bornee a -3 ; doublee sous 91 %.
## Reparation : `Blacksmith.BlacksmithDialogResponse` et
## `InventoryItem.RepairCost` = (MaxCondition - Condition) * Price / MaxCondition.

const CONDITION_LOSS_CHANCE_PERCENT := 5
const NO_WEAR_BELOW_PERCENT := 70
## eObjectType que le forgeron refuse (Blacksmith.cs) : GenericItem, Magical,
## Instrument, Poison.
const UNREPAIRABLE_OBJECT_TYPES := [0, 41, 45, 46]
## Messages de GamePlayer.txt (EN), traduits.
const WEAR_MESSAGES := {
	90: "Votre %s aurait besoin d'une reparation.",
	80: "Votre %s a besoin d'etre repare.",
	70: "Votre %s a grandement besoin d'etre repare.",
}


static func condition_percent(item: Dictionary) -> int:
	var max_condition := int(item.get("max_condition", 0))
	if max_condition <= 0:
		return 0
	return int(round(float(item.get("condition", max_condition)) / float(max_condition) * 100.0))


## GameObject.GetConLevel(level, compareLevel).
static func con_level(level: int, compare_level: int) -> float:
	var constep: int = maxi(1, int((level + 9) / 10))
	return -float(level - compare_level) / float(constep)


## Un coup qui use l'objet : `roll` est un tirage 0..99. Rend l'objet modifie et
## le message a afficher quand le pourcentage franchit 90, 80 ou 70.
static func wear(item: Dictionary, player_level: int, roll: int) -> Dictionary:
	var out := item.duplicate(true)
	var old_percent := condition_percent(item)
	if old_percent <= NO_WEAR_BELOW_PERCENT or roll >= CONDITION_LOSS_CHANCE_PERCENT:
		return {"changed": false, "item": out}
	var con := maxf(-3.0, con_level(player_level, int(item.get("level", 0))))
	var sub := int(con + 4.0)
	if old_percent < 91:
		sub *= 2
	out["condition"] = maxi(0, int(item.get("condition", 0)) - sub)
	var new_percent := condition_percent(out)
	var message := ""
	if new_percent != old_percent and WEAR_MESSAGES.has(new_percent):
		message = str(WEAR_MESSAGES[new_percent]) % str(item.get("name", "objet"))
	return {"changed": true, "item": out, "lost": sub, "percent": new_percent, "message": message}


static func repair_cost(item: Dictionary) -> int:
	var max_condition := int(item.get("max_condition", 0))
	if max_condition <= 0:
		return 0
	return int((max_condition - int(item.get("condition", max_condition))) * int(item.get("price", 0)) / max_condition)


## Ce que le forgeron repond a l'objet qu'on lui tend (Blacksmith.ReceiveItem).
static func repair_offer(item: Dictionary) -> Dictionary:
	if UNREPAIRABLE_OBJECT_TYPES.has(int(item.get("object_type", 0))):
		return {"ok": false, "reason": "Je ne peux pas reparer cela."}
	var max_condition := int(item.get("max_condition", 0))
	if int(item.get("condition", max_condition)) >= max_condition:
		return {"ok": false, "reason": "Cet objet n'a pas besoin d'etre repare."}
	if int(item.get("durability", max_condition)) <= 0:
		return {"ok": false, "reason": "Cet objet ne peut plus etre repare."}
	return {"ok": true, "cost": repair_cost(item)}


## La reparation payee : la condition remonte au maximum et la durabilite
## paie ce qui a ete rendu (+1). Un objet trop use ne recupere que sa durabilite.
static func repair(item: Dictionary) -> Dictionary:
	var out := item.duplicate(true)
	var max_condition := int(item.get("max_condition", 0))
	var condition := int(item.get("condition", max_condition))
	var durability := int(item.get("durability", max_condition))
	var to_recover := max_condition - condition
	var rather_old := to_recover + 1 >= durability
	if rather_old:
		out["condition"] = condition + durability
		out["durability"] = 0
	else:
		out["condition"] = max_condition
		if not bool(item.get("is_not_losing_dur", false)):
			out["durability"] = durability - (to_recover + 1)
	return {"item": out, "rather_old": rather_old}
