extends RefCounted
class_name DaocFactionRules

## P1-34 — les factions, portées du code DOL.
##
## Ce fichier ne contient QUE des règles, sans état de monde et sans accès
## disque : il reçoit des chiffres et rend une décision. Même découpage que
## `DaocDolFormulas` et `DaocNpcBrain`, et pour la même raison — une règle sans
## monde se teste sans monde.
##
## CE QUI VIENT DU CODE DOL, avec son fichier et sa ligne :
##
##   `Faction.cs:32-36`      les quatre bornes : ±1 par meurtre, [-100, +100]
##   `Faction.cs:150`        `BaseAggroLevel` — « base aggro when player have
##                           never meet faction before »
##   `Faction.cs:219-229`    `KillMember` : +1 à la faction, +1 à ses AMIS,
##                           **-1 à ses ENNEMIS**
##   `Faction.cs:290-296`    `GetAggroToFaction` : la valeur mémorisée, sinon
##                           `BaseAggroLevel`
##   `StandardMobBrain.cs:279-287`  l'hostilité envers un joueur
##   `StandardMobBrain.cs:738-753`  l'hostilité envers un autre PNJ
##   `GameNPC.cs:3217-3228`  les quatre paliers du texte d'examen
##   `GameNPC.cs:3450`       un marchand hostile refuse de parler
##
## `DOL_CODE` reste ce qu'il est depuis P1-23 : une RÉIMPLÉMENTATION, un cran
## au-dessus de `PLACEHOLDER` et un cran en dessous d'une mesure contre un vrai
## serveur.

const BASIS_DOL_CODE := "DOL_CODE"
const BASIS_DUMP_FACTION := "DUMP_FACTION"

## Faction.cs:32-36. Le meurtre d'un membre déplace la relation d'UN point, et
## la relation est bornée. Ces quatre nombres sont recopiés, pas choisis.
const DECREASE_AGGRO_AMOUNT := -1
const INCREASE_AGGRO_AMOUNT := 1
const MAX_AGGRO_VALUE := 100
const MIN_AGGRO_VALUE := -100

## GameNPC.cs:3217-3228. Les seuils du texte affiché à l'examen. Ils sont
## STRICTEMENT supérieurs : à exactement 25 un PNJ est « amical », pas « neutre ».
const AGGRESSIVE_ABOVE := 75
const HOSTILE_ABOVE := 50
const NEUTRAL_ABOVE := 25

const LEVEL_AGGRESSIVE := "AGGRESSIVE"
const LEVEL_HOSTILE := "HOSTILE"
const LEVEL_NEUTRAL := "NEUTRAL"
const LEVEL_FRIENDLY := "FRIENDLY"


## Faction.cs:290-296 — ce que la faction pense de CE joueur.
##
## La réputation mémorisée gagne ; sinon c'est `BaseAggroLevel`, l'hostilité
## envers quelqu'un qui n'a jamais croisé la faction.
##
## `reputation` est volontairement un Dictionary `{character_id: valeur}` et non
## un entier : passer une valeur par défaut ferait disparaître la différence
## entre « ce joueur est à zéro » et « ce joueur n'a jamais rencontré cette
## faction », qui sont deux états distincts et donnent deux résultats distincts.
static func aggro_to_player(base_aggro_level: int, reputation: Dictionary,
		character_id: String) -> Dictionary:
	if character_id != "" and reputation.has(character_id):
		return {
			"aggro": clampi(int(reputation[character_id]), MIN_AGGRO_VALUE, MAX_AGGRO_VALUE),
			"basis": "CHARACTER_REPUTATION",
		}
	return {"aggro": base_aggro_level, "basis": "BASE_AGGRO_LEVEL"}


## Faction.cs:219-229 — tuer un membre d'une faction.
##
## LE SIGNE EST CONTRE-INTUITIF, ET IL EST RECOPIÉ TEL QUEL. Tuer un membre
## AUGMENTE l'aggro de cette faction et de ses AMIS, et la DIMINUE chez ses
## ENNEMIS : on se fait bien voir de ceux qui détestent la victime. Le message
## que DOL envoie au joueur dit d'ailleurs l'inverse du signe — `amount > 0`
## affiche « decreased » — parce qu'il parle de la RELATION, pas de l'aggro.
##
## Rend le plan des changements, jamais l'état : l'arbitre reste propriétaire de
## la réputation, ce fichier ne la stocke pas.
static func plan_kill_member(faction_id: int, friends: Array, enemies: Array) -> Array:
	var plan: Array = []
	plan.append({"faction_id": faction_id, "amount": INCREASE_AGGRO_AMOUNT, "reason": "MEMBER_KILLED"})
	for value in friends:
		plan.append({"faction_id": int(value), "amount": INCREASE_AGGRO_AMOUNT, "reason": "FRIEND_OF_VICTIM"})
	for value in enemies:
		plan.append({"faction_id": int(value), "amount": DECREASE_AGGRO_AMOUNT, "reason": "ENEMY_OF_VICTIM"})
	return plan


## Faction.cs:243-263 — applique un changement et le borne.
##
## Rend aussi l'ancienne valeur : DOL ne prévient le joueur QUE si la valeur a
## réellement changé, et à la borne elle ne change plus.
static func apply_aggro_change(current: int, amount: int) -> Dictionary:
	var updated := clampi(current + amount, MIN_AGGRO_VALUE, MAX_AGGRO_VALUE)
	return {
		"before": current,
		"after": updated,
		"changed": updated != current,
	}


## StandardMobBrain.cs:279-287 — ce PNJ attaque-t-il ce joueur à vue ?
##
## LE POINT DU JALON, ET IL ÉTAIT MANQUANT : un mob dont `AggroLevel` vaut ZÉRO
## est quand même agressif si sa FACTION l'est. Jusqu'ici le projet ne regardait
## que `AggroLevel`, donc un membre d'une faction hostile passait pour un
## marchand tranquille.
##
## L'aggro de faction NÉGATIVE est ramenée à zéro avant la comparaison — DOL le
## fait explicitement — donc une faction amicale ne rend jamais un mob agressif
## PACIFIQUE, elle ne peut que ne pas l'aider.
static func is_aggressive_to_player(mob_aggro_level: int, faction_aggro: int) -> bool:
	var faction_part: int = maxi(faction_aggro, 0)
	return not (faction_part <= 0 and mob_aggro_level <= 0)


## StandardMobBrain.cs:738-753 — combien ce PNJ en veut-il à cette cible.
##
## Trois branches, dans l'ordre de la source :
##   - une cible GRISE ne déclenche rien, quelle que soit la faction ;
##   - contre un joueur, c'est l'aggro de faction, plafonnée à 100 ;
##   - contre un autre PNJ dont la faction est ENNEMIE, c'est 100 sec.
##
## Et le garde-fou de la fin, qui explique pourquoi le monde n'est pas une
## bagarre générale : un PNJ SANS royaume ne s'en prend jamais à un autre PNJ
## hors relation de faction déclarée.
static func aggro_amount_to_target(mob_aggro_level: int, mob_realm: int,
		mob_faction_id: int, mob_enemy_factions: Array, faction_aggro_to_player: int,
		target: Dictionary) -> Dictionary:
	if bool(target.get("grey_con", false)):
		return {"aggro": 0, "reason": "TARGET_IS_GREY"}
	var target_is_player := bool(target.get("is_player", false))
	if mob_faction_id > 0:
		if target_is_player:
			return {
				"aggro": mini(MAX_AGGRO_VALUE, faction_aggro_to_player),
				"reason": "FACTION_AGGRO_TO_PLAYER",
			}
		var target_faction := int(target.get("faction_id", 0))
		if target_faction > 0 and mob_enemy_factions.has(target_faction):
			return {"aggro": MAX_AGGRO_VALUE, "reason": "TARGET_FACTION_IS_ENEMY"}
	# `eRealm.None` vaut 0. Sans ce refus, chaque monstre sans royaume
	# attaquerait tous les autres monstres du décor.
	if mob_realm == 0 and not target_is_player:
		return {"aggro": 0, "reason": "NO_REALM_NPC_VS_NPC"}
	return {"aggro": mini(MAX_AGGRO_VALUE, mob_aggro_level), "reason": "MOB_AGGRO_LEVEL"}


## GameNPC.cs:3217-3228 — le mot affiché quand on examine un PNJ à faction.
static func aggro_level_string(aggro: int) -> String:
	if aggro > AGGRESSIVE_ABOVE:
		return LEVEL_AGGRESSIVE
	if aggro > HOSTILE_ABOVE:
		return LEVEL_HOSTILE
	if aggro > NEUTRAL_ABOVE:
		return LEVEL_NEUTRAL
	return LEVEL_FRIENDLY


## GameNPC.cs:3450 — « il vous lance un regard mauvais » : au-dessus de 25, un
## PNJ d'un autre royaume refuse l'interaction. Un marchand d'une faction fâchée
## ne vend donc rien, et ce n'est pas un défaut d'interface.
static func interaction_refused(aggro: int, same_realm: bool) -> bool:
	return not same_realm and aggro > NEUTRAL_ABOVE
