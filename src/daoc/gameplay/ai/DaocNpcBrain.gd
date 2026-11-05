extends RefCounted
class_name DaocNpcBrain

## P1-22D — les créatures cessent d'être des meubles.
##
## Jusqu'ici l'arbitre le disait lui-même en tête de fichier : « il ne déplace
## personne : les PNJ frappent sur place, sans approche ». On pouvait donc tuer
## un mob en marchant jusqu'à lui, et rien d'autre n'arrivait jamais.
##
## CE FICHIER NE CONTIENT QUE DES RÈGLES, sans état de monde : il reçoit une
## situation et rend une DÉCISION. L'arbitre garde les positions, les états et
## l'horloge. C'est le même découpage qu'entre `DaocMeleeExchange` et
## `DaocLocalServer`, et il vaut pour la même raison : une règle sans monde se
## teste sans monde.
##
## CE QUI VIENT DE LA BASE, et n'est donc PAS inventé — c'est ce que P1-22A est
## allé chercher dans les 29 Mio de `mob.sql` :
##
##   `AggroLevel`   0 = pacifique ; au-dessus, la créature attaque à vue
##   `AggroRange`   la distance, en unités DAoC, à laquelle elle vous voit
##   `Speed`        sa vitesse de déplacement
##   `RoamingRange` son rayon d'errance autour du point d'apparition
##
## CE QUI RESTE INVENTÉ, et déclaré : la distance de LAISSE — jusqu'où une
## créature poursuit avant de renoncer et de rentrer. DAoC en a une, sa valeur
## vit dans le code du serveur.
##
## POURQUOI UNE LAISSE, et pourquoi elle n'est pas négociable : sans elle, un
## joueur traîne un mob à travers la zone entière, puis à travers la frontière
## que R5 vient d'ouvrir — dans une zone que le mob ne connaît pas, autour d'un
## point d'apparition déchargé. La laisse n'est pas un confort, c'est ce qui
## garde une créature dans le monde qui la contient.

const BASIS_MOB_DB := "MOB_DB"
const BASIS_PLACEHOLDER := "PLACEHOLDER"

## Ce que la créature est en train de faire. Un seul état à la fois.
const STATE_IDLE := "idle"        # au repos, elle regarde autour d'elle
const STATE_CHASING := "chasing"  # elle a une cible et court vers elle
const STATE_FIGHTING := "fighting" # elle est à portée et frappe
const STATE_RETURNING := "returning" # elle a renoncé et rentre

## Distance de laisse par défaut, en unités DAoC. PLACEHOLDER ASSUMÉ.
## Choisie à un peu plus de deux fois la portée d'aggro la plus courante (500)
## pour qu'une créature poursuive visiblement sans jamais quitter son coin.
const DEFAULT_LEASH_RAW := 1500.0

## Vitesse de repli quand la base n'en déclare aucune, en unités par seconde.
## PLACEHOLDER : un `Speed` de 0 dans `mob.sql` veut dire « immobile », mais
## certains agressifs en portent un — ils poursuivraient sans avancer.
const DEFAULT_SPEED_RAW := 180.0

## En deçà de cette distance du point d'apparition, le retour est terminé.
const RETURN_TOLERANCE_RAW := 30.0


## La créature est-elle agressive ?
##
## `AggroLevel` à zéro veut dire pacifique, et c'est le cas de la grande
## majorité des PNJ de ville. Une portée d'aggro sans niveau d'aggro ne suffit
## PAS : la portée dit jusqu'où elle voit, le niveau dit si elle attaque.
static func is_aggressive(profile: Dictionary) -> bool:
	return int(profile.get("aggro_level", 0)) > 0 and int(profile.get("aggro_range_raw", 0)) > 0


static func aggro_range_of(profile: Dictionary) -> float:
	return float(maxi(0, int(profile.get("aggro_range_raw", 0))))


## La vitesse d'une créature, jamais nulle quand elle poursuit.
static func speed_of(profile: Dictionary) -> Dictionary:
	var declared: int = int(profile.get("speed_raw", 0))
	if declared > 0:
		return {"speed_raw": float(declared), "basis": BASIS_MOB_DB}
	return {"speed_raw": DEFAULT_SPEED_RAW, "basis": BASIS_PLACEHOLDER}


## La laisse d'une créature, en unités DAoC.
##
## Elle s'appuie sur le rayon d'errance de la base quand il existe — un mob qui
## erre sur 200 unités n'a pas de raison de poursuivre sur 1500 — mais ne
## descend jamais sous la portée d'aggro, sinon la créature renoncerait avant
## d'avoir atteint ce qu'elle vient de voir.
static func leash_of(profile: Dictionary) -> float:
	var roaming: float = float(maxi(0, int(profile.get("roaming_range_raw", 0))))
	var aggro: float = aggro_range_of(profile)
	if roaming > 0.0:
		return maxf(aggro * 1.5, roaming * 3.0)
	return maxf(aggro * 1.5, DEFAULT_LEASH_RAW)


## La décision d'une créature pour cette trame.
##
## `situation` porte : `state`, `distance_to_target_raw`, `distance_to_spawn_raw`,
## `target_alive`, `has_target`, `melee_range_raw`, et le profil de la base.
##
## Rend `state` — le nouvel état — et `intent` : `engage`, `approach`,
## `disengage`, `return`, `arrived`, ou `wait`.
##
## AUCUNE DE CES DÉCISIONS N'AGIT : l'arbitre les applique, ou pas. C'est ce qui
## permet de les éprouver une par une, sans monde autour.
static func decide(situation: Dictionary) -> Dictionary:
	var profile: Dictionary = situation.get("profile", {}) as Dictionary
	var state: String = str(situation.get("state", STATE_IDLE))
	var has_target: bool = bool(situation.get("has_target", false))
	var target_alive: bool = bool(situation.get("target_alive", false))
	var to_target: float = float(situation.get("distance_to_target_raw", INF))
	var to_spawn: float = float(situation.get("distance_to_spawn_raw", 0.0))
	var melee: float = float(situation.get("melee_range_raw", 200.0))
	var leash: float = leash_of(profile)

	# 1. Rentrer prime sur tout : une creature qui rentre ne se laisse pas
	#    redistraire avant d'etre arrivee, sinon un joueur la maintient en
	#    yo-yo au bord de sa laisse indefiniment.
	if state == STATE_RETURNING:
		if to_spawn <= RETURN_TOLERANCE_RAW:
			return {"state": STATE_IDLE, "intent": "arrived"}
		return {"state": STATE_RETURNING, "intent": "return"}

	# 2. Plus de cible, ou cible morte : on rentre.
	if state in [STATE_CHASING, STATE_FIGHTING] and (not has_target or not target_alive):
		return {"state": STATE_RETURNING, "intent": "disengage", "reason": "cible perdue"}

	# 3. La laisse. Elle se mesure au POINT D'APPARITION, pas a la distance
	#    parcourue : une creature ramenee chez elle par un joueur qui recule ne
	#    doit pas renoncer.
	if state in [STATE_CHASING, STATE_FIGHTING] and to_spawn > leash:
		return {"state": STATE_RETURNING, "intent": "disengage", "reason": "laisse", "leash_raw": leash}

	# 4. Voir quelqu'un. On ne repere que depuis le repos : une creature deja
	#    engagee ne change pas de cible parce qu'une autre passe plus pres.
	if state == STATE_IDLE:
		if has_target and target_alive and is_aggressive(profile) and to_target <= aggro_range_of(profile):
			if to_target <= melee:
				return {"state": STATE_FIGHTING, "intent": "engage"}
			return {"state": STATE_CHASING, "intent": "approach"}
		return {"state": STATE_IDLE, "intent": "wait"}

	# 5. Poursuivre, puis frapper des qu'on touche.
	if to_target <= melee:
		return {"state": STATE_FIGHTING, "intent": "engage"}
	return {"state": STATE_CHASING, "intent": "approach"}


## Le pas d'approche d'une trame : de `from` vers `to`, sans jamais dépasser.
##
## LE DÉPASSEMENT EST LE PIÈGE ÉVIDENT de ce genre de code : une créature rapide
## traverse sa cible et repart en arrière la trame suivante, ce qui se voit à
## l'écran comme un tremblement. Le pas est donc borné par la distance restante.
##
## L'ALTITUDE N'EST PAS TOUCHÉE : le relief est l'affaire de l'hôte, qui sait
## échantillonner le sol. Une créature qui déciderait de son propre `z` volerait
## ou s'enterrerait.
static func step_towards(from: Vector3, to: Vector3, speed_raw: float, delta_seconds: float) -> Vector3:
	var flat_from := Vector2(from.x, from.y)
	var flat_to := Vector2(to.x, to.y)
	var remaining: float = flat_from.distance_to(flat_to)
	if remaining <= 0.001:
		return from
	var travel: float = minf(remaining, maxf(0.0, speed_raw) * maxf(0.0, delta_seconds))
	var moved: Vector2 = flat_from + (flat_to - flat_from).normalized() * travel
	return Vector3(moved.x, moved.y, from.z)
