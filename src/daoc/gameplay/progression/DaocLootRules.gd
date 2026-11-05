extends RefCounted
class_name DaocLootRules

## P1-22C — ce que laisse un mort : les objets, et l'argent.
##
## CE QUE LE DUMP DONNE VRAIMENT, mesuré et non supposé. `loottemplate` ne porte
## que **659 tables** pour les **3072 mobs** que `mobxloottemplate` nomme, et sur
## les 28 tables citées par les PNJ de Gothwaite, **4** existent réellement.
## Ce n'est pas un défaut de lecture : la table `lootgenerator` déclare quatre
## générateurs, et les deux qui portent le gros du butin —
## `DOL.GS.LootGeneratorMoney` et `DOL.GS.ROGMobGenerator`, les objets générés au
## hasard — vivent dans le CODE d'OpenDAoC, pas dans ses tables.
##
## D'où le partage de ce fichier, et il est net :
##
##   | ce qui tombe          | provenance                                  |
##   | --------------------- | ------------------------------------------- |
##   | objets de table       | **DUMP** — chances et objets réels          |
##   | argent                | **PLACEHOLDER** — la formule est du code    |
##   | objets générés (ROG)  | **PAS IMPLÉMENTÉ** — ni inventé, ni promis  |
##
## LE TIRAGE EST DÉTERMINISTE, comme tout ce que décide l'arbitre depuis P1-21A :
## même graine, même mort, même butin. Sans cela aucun bug de butin ne serait
## reproductible, et une session rejouée cesserait d'être une preuve.
##
## LES CHANCES NÉGATIVES sont conservées telles quelles et NE FONT RIEN TOMBER.
## 239 des 1792 lignes du dump en portent une ; leur sens vit dans le code du
## générateur. Un `-3` traité comme « 3 % » serait une invention silencieuse, et
## traité comme 0 il disparaîtrait du relevé. Il est donc porté, compté, et sans
## effet — jusqu'à ce qu'une source explique ce qu'il veut dire.

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")

const BASIS_DUMP := "DUMP"
const BASIS_PLACEHOLDER := "PLACEHOLDER"
## P1-23 — porte du code de DOL, avec citation. Voir `DaocDolFormulas`.
const BASIS_DOL_CODE := "DOL_CODE"

## Les dénominations de DAoC. Règle de jeu connue, pas un réglage.
const COPPER_PER_SILVER := 100
const SILVER_PER_GOLD := 100
const GOLD_PER_PLATINUM := 1000


## L'argent que laisse une créature, en cuivre.
##
## P1-23 — `LootGeneratorMoney.GenerateLoot` EST SUR LE DISQUE, et le tableau de
## ce fichier vient d'être corrigé : la ligne « argent — PLACEHOLDER, la formule
## est du code » se lit désormais `DOL_CODE`.
##
## L'ÉCART AVEC LE PLACEHOLDER EST ÉNORME, et dans le sens qu'on n'attendait pas.
## La vraie somme est CUBIQUE en niveau, l'inventée était quadratique : un rat de
## niveau 1 laissait 3 cuivres et en laisse 3 ; un niveau 40 laissait 4800 cuivres
## et en laisse près de 10 700. La progression de DAoC est bien plus violente que
## la forme « plausible » choisie en P1-22C.
static func money_for_kill(victim_level: int, roll: float = 0.5, use_dol_formulas: bool = true) -> Dictionary:
	if use_dol_formulas:
		# DOL tire `Util.Random(minLoot >> 1)`. Le tirage reste DÉTERMINISTE ici :
		# l'appelant fournit `roll`, jamais le générateur.
		var lvl: int = maxi(1, victim_level + 1)
		var min_loot: int = 2 + ((lvl * lvl * lvl) >> 3)
		var span: int = maxi(0, (min_loot >> 1) - 1)
		var drawn: int = int(round(clampf(roll, 0.0, 1.0) * float(span)))
		var dol: Dictionary = DolFormulas.money_for_kill(victim_level, drawn)
		return {"copper": int(dol.get("copper", 1)), "basis": BASIS_DOL_CODE}
	return placeholder_money_for_kill(victim_level, roll)


## La somme inventée de P1-22C. CONSERVÉE POUR LA CONTRE-ÉPREUVE.
static func placeholder_money_for_kill(victim_level: int, roll: float = 0.5) -> Dictionary:
	var level: int = maxi(1, victim_level)
	var base: float = 3.0 * float(level) * float(level)
	# +/- 25 % autour de la base, pour que deux morts identiques ne rendent pas
	# exactement la meme piece — ce que le joueur remarque tout de suite.
	var spread: float = 0.75 + clampf(roll, 0.0, 1.0) * 0.5
	return {
		"copper": maxi(1, int(round(base * spread))),
		"basis": BASIS_PLACEHOLDER,
	}


## Découpe une somme en cuivre selon les dénominations de DAoC.
static func split_money(copper: int) -> Dictionary:
	var total: int = maxi(0, copper)
	var c: int = total % COPPER_PER_SILVER
	var silver_total: int = total / COPPER_PER_SILVER
	var s: int = silver_total % SILVER_PER_GOLD
	var gold_total: int = silver_total / SILVER_PER_GOLD
	var g: int = gold_total % GOLD_PER_PLATINUM
	var p: int = gold_total / GOLD_PER_PLATINUM
	return {"copper": c, "silver": s, "gold": g, "platinum": p, "total_copper": total}


## Le texte d'une somme, dans l'ordre du jeu et sans dénomination vide.
static func money_text(copper: int) -> String:
	var parts: Dictionary = split_money(copper)
	var out: Array = []
	if int(parts["platinum"]) > 0:
		out.append("%d platine" % int(parts["platinum"]))
	if int(parts["gold"]) > 0:
		out.append("%d or" % int(parts["gold"]))
	if int(parts["silver"]) > 0:
		out.append("%d argent" % int(parts["silver"]))
	if int(parts["copper"]) > 0 or out.is_empty():
		out.append("%d cuivre" % int(parts["copper"]))
	return ", ".join(out)


## Tire le butin d'une table, avec un générateur fourni par l'appelant.
##
## `templates` est le dictionnaire `templates` de l'index P1-22C ; `items` son
## dictionnaire d'objets. `names` est la liste des tables du mob.
##
## Un objet dont l'`Id_nb` n'est pas dans l'index N'EST PAS INVENTÉ : il est
## compté dans `skipped_unknown_items`. Une référence morte du dump ne doit pas
## devenir un objet fantôme dans un sac.
static func roll_table(names: Array, templates: Dictionary, items: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var dropped: Array = []
	var considered: int = 0
	var skipped_unknown: int = 0
	var skipped_negative: int = 0
	for value in names:
		var table_name: String = str((value as Dictionary).get("template", value))
		var entries: Array = templates.get(table_name, []) as Array
		for entry_value in entries:
			var entry: Dictionary = entry_value as Dictionary
			considered += 1
			if str(entry.get("chance_basis", "")) != "PERCENT":
				skipped_negative += 1
				continue
			var chance: int = int(entry.get("chance_percent", 0))
			if chance <= 0:
				continue
			if rng.randi_range(1, 100) > chance:
				continue
			var item_id: String = str(entry.get("item_id", ""))
			if not items.has(item_id):
				skipped_unknown += 1
				continue
			var item: Dictionary = (items[item_id] as Dictionary).duplicate(true)
			item["count"] = maxi(1, int(entry.get("count", 1)))
			item["chance_percent"] = chance
			item["basis"] = BASIS_DUMP
			dropped.append(item)
	return {
		"items": dropped,
		"considered": considered,
		"skipped_unknown_items": skipped_unknown,
		"skipped_negative_chance": skipped_negative,
	}
