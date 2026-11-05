extends RefCounted
class_name DaocExperienceRules

## P1-22B — l'expérience : combien vaut un mort, et quand on monte de niveau.
##
## RÈGLE D'HONNÊTETÉ DE CE FICHIER, la même qu'à `DaocLocalServerVitals` : chaque
## chiffre porte sa PROVENANCE, et aucun ne prétend être celui de Mythic.
##
## **La courbe d'expérience de DAoC n'est PAS dans les dumps.** On a cherché :
## `timexlevel.sql` porte un nom prometteur et ne contient que des STATISTIQUES
## de temps de jeu — table vide, sans une seule ligne. La table `XPLevel` vit
## dans le CODE d'OpenDAoC, et `OPENDAOC_SOURCE_ROOT` n'est toujours pas défini.
## Les valeurs ci-dessous sont donc `PLACEHOLDER`, remplaçables en un seul
## endroit le jour où la source arrive.
##
## LA COULEUR DE CONSIDÉRATION, elle, est une règle de JEU documentée depuis
## vingt ans : gris, vert, bleu, jaune, orange, rouge, violet, et une fenêtre qui
## s'élargit avec le niveau. Elle est implémentée telle qu'elle est connue, et
## marquée `KNOWN_RULE_UNVERIFIED` — connue, mais non confrontée à une source sur
## ce disque. Ne pas la présenter comme mesurée.
##
## CE QUI EST STRUCTUREL ET NE CHANGERA PAS avec les vrais chiffres :
##   - un gris ne rapporte RIEN, et c'est ce qui empêche de monter en tapant des
##     rats au niveau 20 ;
##   - l'expérience dépend du COUPLE tueur/victime, jamais de la victime seule ;
##   - la montée de niveau est un SEUIL CUMULÉ franchi, pas un compteur remis à
##     zéro — un joueur garde son surplus.

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")

const BASIS_PLACEHOLDER := "PLACEHOLDER"
const BASIS_KNOWN_RULE := "KNOWN_RULE_UNVERIFIED"
## P1-23 — porte du code de DOL, avec citation. Voir `DaocDolFormulas`.
const BASIS_DOL_CODE := "DOL_CODE"

const MAX_LEVEL := 50

const CON_GREY := "grey"
const CON_GREEN := "green"
const CON_BLUE := "blue"
const CON_YELLOW := "yellow"
const CON_ORANGE := "orange"
const CON_RED := "red"
const CON_PURPLE := "purple"

## Multiplicateur d'expérience par couleur. `grey` vaut zéro : c'est la seule
## valeur de ce tableau qui soit une RÈGLE et non un réglage.
const CON_FACTORS := {
	CON_GREY: 0.0,
	CON_GREEN: 0.25,
	CON_BLUE: 0.75,
	CON_YELLOW: 1.0,
	CON_ORANGE: 1.25,
	CON_RED: 1.5,
	CON_PURPLE: 2.0,
}


## L'expérience CUMULÉE nécessaire pour atteindre `level`.
##
## Forme retenue : croissance géométrique douce, calée pour que les premiers
## niveaux tombent en quelques minutes de chasse et que la pente devienne
## sérieuse ensuite. PLACEHOLDER ASSUMÉ — ce n'est pas la table de DAoC, dont les
## paliers sont irréguliers et vivent dans le code serveur.
static func experience_for_level(level: int, use_dol_formulas: bool = true) -> int:
	if use_dol_formulas:
		# DEUX TABLES DISTINCTES, et les confondre etait le premier defaut de
		# P1-23. `XPForLevel` (GamePlayer) est la PROGRESSION du joueur ;
		# `XPForLiving` (GameLiving) est ce que VAUT une victime. Le niveau 1 ne
		# coute rien dans la premiere et vaut 10 dans la seconde.
		return DolFormulas.experience_needed_for_level(clampi(level, 0, MAX_LEVEL + 1))
	return placeholder_experience_for_level(level)


## La courbe inventee de P1-22B. CONSERVEE POUR LA CONTRE-EPREUVE, plus appelee
## par defaut : geometrique et lisse, donc incapable de reproduire les paliers
## irreguliers de la vraie table — le niveau 22 y coute MOINS que le 21 ne le
## laisserait croire, et aucune formule ne rend cela.
static func placeholder_experience_for_level(level: int) -> int:
	var target: int = clampi(level, 1, MAX_LEVEL)
	if target <= 1:
		return 0
	var total: float = 0.0
	for step in range(2, target + 1):
		var l: float = float(step)
		total += 50.0 * pow(l, 3.0) / 8.0
	return int(round(total))


## L'expérience à gagner AVANT le prochain niveau, depuis le total courant.
static func experience_to_next_level(total_experience: int, level: int, use_dol_formulas: bool = true) -> int:
	if level >= MAX_LEVEL:
		return 0
	return maxi(0, experience_for_level(level + 1, use_dol_formulas) - maxi(0, total_experience))


## Le niveau qu'un total d'expérience donne, sans jamais dépasser MAX_LEVEL.
static func level_for_experience(total_experience: int, use_dol_formulas: bool = true) -> int:
	var level := 1
	while level < MAX_LEVEL and total_experience >= experience_for_level(level + 1, use_dol_formulas):
		level += 1
	return level


## La couleur de considération d'une victime pour un tueur donné.
##
## La fenêtre s'ÉLARGIT avec le niveau : à 5 un écart de deux niveaux est déjà
## sérieux, à 45 il ne se voit pas. `KNOWN_RULE_UNVERIFIED`.
static func con_colour(killer_level: int, victim_level: int, use_dol_formulas: bool = true) -> String:
	if use_dol_formulas:
		return DolFormulas.con_colour(killer_level, victim_level)
	return placeholder_con_colour(killer_level, victim_level)


## La regle de couleur telle qu'on la CROYAIT en P1-22B, marquee alors
## `KNOWN_RULE_UNVERIFIED`. Conservee pour la contre-epreuve.
##
## ELLE ETAIT PROCHE MAIS FAUSSE SUR DEUX POINTS, et la source les tranche : la
## largeur d'un cran vaut `(niveau + 9) / 10` en division entiere et non
## `niveau / 10 + 1`, et surtout le GRIS n'est pas une formule du tout — c'est
## la table `NoXPForLevel`, avec ses plateaux a 6, a 13 et a 25.
static func placeholder_con_colour(killer_level: int, victim_level: int) -> String:
	var killer: int = maxi(1, killer_level)
	var gap: int = victim_level - killer
	# Largeur d'un cran de couleur, arrondie a 1 minimum : environ un dixieme du
	# niveau du tueur. C'est ce qui fait qu'un rat cesse de rapporter.
	var band: int = maxi(1, int(floor(float(killer) / 10.0)) + 1)
	if gap <= -3 * band:
		return CON_GREY
	if gap <= -2 * band:
		return CON_GREEN
	if gap <= -band:
		return CON_BLUE
	if gap < band:
		return CON_YELLOW
	if gap < 2 * band:
		return CON_ORANGE
	if gap < 3 * band:
		return CON_RED
	return CON_PURPLE


## Ce que vaut une victime, tout compris.
##
## Rend `amount`, la couleur, le facteur appliqué et la BASE — pour qu'un journal
## de combat puisse dire « bleu, x0.75 » au lieu d'un nombre tombé du ciel.
static func kill_experience(killer_level: int, victim_level: int, options: Dictionary = {}) -> Dictionary:
	if bool(options.get("use_dol_formulas", true)):
		var dol: Dictionary = DolFormulas.kill_experience(killer_level, victim_level, options)
		# Le champ `con_factor` n'existe pas chez DOL : sa reduction ne passe pas
		# par un multiplicateur de couleur mais par un PLAFOND lie au niveau du
		# tueur, plus la table du gris. Il est rendu a titre d'AFFICHAGE, calcule
		# apres coup, pour que le journal de combat garde sa phrase — jamais
		# comme une entree du calcul.
		var base_value: int = maxi(1, int(dol.get("base", 1)))
		dol["con_factor"] = float(int(dol.get("amount", 0))) / float(base_value)
		return dol
	return placeholder_kill_experience(killer_level, victim_level, options)


## Ce que valait une victime en P1-22B. Conservee pour la contre-epreuve.
static func placeholder_kill_experience(killer_level: int, victim_level: int, options: Dictionary = {}) -> Dictionary:
	var colour: String = placeholder_con_colour(killer_level, victim_level)
	var factor: float = float(CON_FACTORS.get(colour, 0.0))
	# Valeur de base d'une victime, PLACEHOLDER : quadratique en son niveau, pour
	# qu'un niveau 40 vaille tres largement plus qu'un niveau 4 sans exploser.
	var base: float = 10.0 * pow(float(maxi(1, victim_level)), 2.0)
	var group_share: float = clampf(float(options.get("group_share", 1.0)), 0.0, 1.0)
	var bonus: float = maxf(0.0, float(options.get("bonus_multiplier", 1.0)))
	var amount: int = int(round(base * factor * group_share * bonus))
	return {
		"amount": amount,
		"con": colour,
		"con_factor": factor,
		"base": int(round(base)),
		"killer_level": killer_level,
		"victim_level": victim_level,
		"basis": BASIS_PLACEHOLDER,
		"con_basis": BASIS_KNOWN_RULE,
	}


## Applique un gain à un total, et dit ce qui s'est passé.
##
## Le surplus est CONSERVÉ : franchir un seuil ne remet aucun compteur à zéro.
## Plusieurs niveaux peuvent tomber d'un coup, et le rapport les liste tous —
## un gain unique qui ferait monter deux fois ne doit pas en perdre un.
static func apply_gain(total_experience: int, current_level: int, amount: int) -> Dictionary:
	var before_total: int = maxi(0, total_experience)
	var before_level: int = clampi(current_level, 1, MAX_LEVEL)
	var after_total: int = before_total + maxi(0, amount)
	var after_level: int = maxi(before_level, level_for_experience(after_total))
	var levels_gained: Array = []
	for level in range(before_level + 1, after_level + 1):
		levels_gained.append(level)
	return {
		"total_experience": after_total,
		"level": after_level,
		"levels_gained": levels_gained,
		"gained": maxi(0, amount),
		"to_next_level": experience_to_next_level(after_total, after_level),
	}
