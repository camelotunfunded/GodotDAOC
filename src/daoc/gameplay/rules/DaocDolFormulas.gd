extends RefCounted
class_name DaocDolFormulas

## P1-23 — LES FORMULES QUI VIVAIENT DANS LE CODE.
##
## CE QUE CE FICHIER CHANGE. Depuis P1-21A, tout ce que l'arbitre local calcule
## porte sa PROVENANCE, et une phrase revient partout : « cette règle vit dans le
## CODE d'OpenDAoC, pas dans ses tables ». Elle est écrite dans
## `DaocLocalServerVitals`, dans `DaocExperienceRules`, dans `DaocLootRules`,
## dans `DaocMeleeExchange`, et elle est la raison pour laquelle la vie maximale,
## la courbe d'expérience, l'argent et le taux de rate étaient `PLACEHOLDER`.
##
## **Le code est sur le disque.** `DOLSharp-master`, l'émulateur communautaire
## Dawn of Light, 2299 fichiers C#. Ce fichier-ci porte ses formules, portées à
## l'identique, **chacune avec le chemin et la ligne d'où elle vient**.
##
## D'où une CINQUIÈME provenance, et une seule : `DOL_CODE`.
##
## ---
##
## CE QUE `DOL_CODE` VEUT DIRE, ET CE QU'IL NE VEUT PAS DIRE.
##
## Il veut dire : ce chiffre n'a pas été inventé, il est recopié d'une source
## lisible, et la citation permet de le vérifier en trente secondes.
##
## Il NE veut PAS dire « c'est la règle de Mythic ». DOL est une
## RÉIMPLÉMENTATION, écrite par observation. Ses propres commentaires le disent :
## « approx to original formula, thx to mathematica », « noret: first 52 are from
## exp table, think mythic has changed some values ». Un écart entre DOL et un
## guide de joueur n'est donc pas automatiquement une erreur du guide.
##
## `DOL_CODE` est un cran AU-DESSUS de `PLACEHOLDER` et un cran EN DESSOUS d'une
## mesure faite contre un vrai serveur. Ne jamais le présenter autrement.
##
## ---
##
## CE QUI N'EST PAS ICI, ET POURQUOI.
##
## Les bonus d'objet, les buffs, les capacités de royaume, les styles, les
## spécialisations : le vrai `GameLiving` les lit sur des indexeurs de propriétés
## (`ItemBonus`, `BaseBuffBonusCategory`, `AbilityBonus`) qui n'existent pas dans
## l'arbitre local. Chaque fonction ci-dessous prend donc les MODIFICATEURS en
## paramètre, avec une valeur par défaut neutre, et **le comportement à zéro
## modificateur est exactement celui de DOL sur un personnage nu**. Rien n'est
## simplifié en silence : ce qui manque est un paramètre non fourni, visible.
##
## Les propriétés serveur (`ServerProperties`) sont portées à leur valeur PAR
## DÉFAUT déclarée dans l'attribut `[ServerProperty(...)]`, jamais à une valeur
## choisie ici. Un serveur réel peut les avoir changées.
##
## ---
##
## LES SOURCES. Les chemins sont relatifs à la racine `DOLSharp-master`, les
## numéros de ligne sont ceux de l'arbre lu le 2026-09-08. `DaocDolSourceRoot`
## sait retrouver cette racine ; aucun fichier C# n'est recopié dans ce projet.

const BASIS_DOL_CODE: String = "DOL_CODE"

## La révision de l'arbre DOL contre laquelle ces formules ont été portées.
## Sert au rapport, pas au calcul.
const PORTED_FROM: String = "DOLSharp-master, lu le 2026-09-08"


# =============================================================================
# 1. EXPÉRIENCE
# =============================================================================

## `GameLiving.XPForLiving` — GameServer/gameobjects/GameLiving.cs:1362.
##
## CE QUE VAUT UNE VICTIME DE CE NIVEAU. **Ce n'est PAS la courbe de progression
## du joueur**, et les confondre était le premier défaut de ce jalon : le premier
## jet s'en servait pour les deux, et la suite P1-22B l'a immédiatement attrapé
## par « le niveau 1 ne coûte rien » — ici l'entrée 1 vaut 10, pas 0.
##
## Les deux tables sont dans DOL, distinctes, et à cinq mille lignes l'une de
## l'autre : celle-ci dans `GameLiving`, `XP_FOR_LEVEL` dans `GamePlayer`. Les
## ordres de grandeur n'ont rien à voir — un niveau 50 VAUT 41 943 040 et il en
## COÛTE 169 999 999 950 pour l'atteindre, quatre mille fois plus.
##
## Les 52 premières entrées viennent de la table de jeu observée, le reste est
## calculé — le commentaire d'origine le dit lui-même, et explique les
## irrégularités (le niveau 22 vaut moins que la progression géométrique ne le
## voudrait).
const XP_FOR_LIVING: Array = [
	5, 10, 20, 40, 80, 160, 320, 640, 1280, 2560,
	5120, 7240, 10240, 14480, 20480, 28980, 40960, 57930, 81920, 115850,
	163840, 206435, 231705, 327680, 412850, 520160, 655360, 825702, 1040319, 1310720,
	1651404, 2080638, 2621440, 3302807, 4161277, 5242880, 6022488, 6918022, 7946720, 9128384,
	10485760, 12044975, 13836043, 15893440, 18258769, 20971520, 24089951, 27672087, 31625241, 36513537,
	41943040, 48179911, 52428800, 63573760, 73027074, 83886080, 96359802, 110688346, 127147521, 146054148,
	167772160, 192719604, 221376692, 254295042, 292108296, 335544320, 385439208, 442753384, 508590084, 584216593,
	671088640, 770878416, 885506769, 1017180169, 1168433187, 1342177280, 1541756833, 1771013538, 2034360338, 2336866374,
	2684354560, 3083513667, 3542027077, 4068720676, 4673732748, 5368709120, 6167027334, 7084054154, 8137441353, 9347465497,
	10737418240, 12334054669, 14168108308, 16274882707, 18694930994, 21474836480, 24668109338, 28336216617, 32549765415, 37389861988,
	42949672960,
]

## `GameLiving.NoXPForLevel` — GameServer/gameobjects/GameLiving.cs:1474.
##
## LE GRIS, ET C'EST UNE TABLE, PAS UNE FORMULE. Pour un tueur de niveau `n`,
## toute victime de niveau INFÉRIEUR OU ÉGAL à `NO_XP_FOR_LEVEL[n]` ne rapporte
## rien. La progression est irrégulière exprès : elle stagne à 6 entre les
## niveaux 9 et 12, à 13 entre 19 et 22, à 25 entre 34 et 40. Une formule
## « niveau / 10 » ne reproduit aucun de ces plateaux.
##
## C'est la règle qui empêche de monter au niveau 50 en tapant des rats.
const NO_XP_FOR_LEVEL: Array = [
	-3, -2, -1, 0, 1, 2, 3, 4, 5, 6,
	6, 6, 6, 7, 8, 9, 10, 11, 12, 13,
	13, 13, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 25, 25, 25, 25, 25,
	25, 26, 27, 28, 29, 30, 31, 32, 33, 34,
	35,
]

## `GamePlayer.XPForLevel` — GameServer/gameobjects/GamePlayer.cs:4711.
##
## LA COURBE DE PROGRESSION DU JOUEUR, la vraie, celle que P1-22B remplaçait par
## une cubique lisse faute de la trouver dans les dumps. Elle n'a rien d'une
## fonction : les paliers 41 à 44 sautent de 8,6 à 12,9 puis 20,7 puis 30
## milliards, et le niveau 51 est une borne artificielle à 999 999 999 950.
##
## PIÈGE D'INDEXATION, ET IL EST DANS DOL, PAS DANS CE PORTAGE :
## `GetExperienceNeededForLevel(n)` rend `XPForLevel[n - 1]`
## (GamePlayer.cs:4679). L'entrée 0 est donc « ce qu'il faut pour être niveau
## 1 » — zéro — et l'entrée 1 « ce qu'il faut pour le niveau 2 ». Lire la table à
## l'index `n` décalerait toute la progression d'un niveau, en silence.
## `experience_needed_for_level` fait la soustraction ; ne pas indexer la table
## directement.
const XP_FOR_LEVEL: Array = [
	0, 50, 250, 850, 2300, 6350, 15950, 37950, 88950, 203950,
	459950, 839950, 1399950, 2199950, 3399950, 5199950, 7899950, 11799950, 17499950, 25899950,
	38199950, 54699950, 76999950, 106999950, 146999950, 199999950, 269999950, 359999950, 479999950, 639999950,
	849999950, 1119999950, 1469999950, 1929999950, 2529999950, 3319999950, 4299999950, 5499999950, 6899999950, 8599999950,
	12899999950, 20699999950, 29999999950, 40799999950, 53999999950, 69599999950, 88499999950, 110999999950, 137999999950, 169999999950,
	999999999950,
]


## `GamePlayer.GetExperienceNeededForLevel` — GamePlayer.cs:4679.
## L'expérience CUMULÉE qu'il faut avoir atteinte pour être de ce niveau.
static func experience_needed_for_level(level: int) -> int:
	if level <= 0:
		return int(XP_FOR_LEVEL[0])
	if level > MAX_LEVEL + 1:
		return int(XP_FOR_LEVEL[MAX_LEVEL])
	return int(XP_FOR_LEVEL[level - 1])


## `ServerProperties.XP_CAP_PERCENT` — GameServer/serverproperty/ServerProperties.cs:835.
## Valeur par défaut déclarée : 125. Un tueur ne peut pas gagner plus de 125 %
## de ce que vaut une victime de son propre niveau.
const XP_CAP_PERCENT: int = 125

## `ServerProperties.MAX_CAMP_BONUS` — ServerProperties.cs:1944. Défaut 0.55.
const MAX_CAMP_BONUS: float = 0.55

const MAX_LEVEL: int = 50


## `AbstractServerRules.GetExperienceForLiving` — serverrules/AbstractServerRules.cs:604.
## Hors table, DOL applique une formule ; ce projet ne dépasse jamais le niveau
## 100, donc la table suffit et le hors-table est borné à sa dernière entrée.
static func xp_for_living(level: int) -> int:
	var lvl: int = maxi(0, level)
	if lvl < XP_FOR_LIVING.size():
		return int(XP_FOR_LIVING[lvl])
	return int(XP_FOR_LIVING[XP_FOR_LIVING.size() - 1])


## `GameLiving.IsObjectGreyCon` — GameServer/gameobjects/GameLiving.cs:1547.
##
## Au-delà de la table (niveau > 50), DOL retombe sur `GetConLevel(...) <= -3`.
static func is_grey(source_level: int, target_level: int) -> bool:
	var src: int = maxi(0, source_level)
	if src < NO_XP_FOR_LEVEL.size():
		return target_level <= int(NO_XP_FOR_LEVEL[src])
	return con_level(src, target_level) <= -3.0


## `GameObject.GetConLevel` — GameServer/gameobjects/GameObject.cs:1072.
##
## Rend un écart en CRANS DE COULEUR, pas en niveaux : <=-3 gris, -2 vert,
## -1 bleu, 0 jaune, 1 orange, 2 rouge, >=3 violet. La largeur d'un cran est
## `max(1, (niveau + 9) / 10)` en division ENTIÈRE — d'où un cran de 1 jusqu'au
## niveau 10, de 2 jusqu'à 20, et ainsi de suite.
static func con_level(level: int, compare_level: int) -> float:
	var constep: int = maxi(1, int((level + 9) / 10.0))
	var stepping: float = 1.0 / float(constep)
	var leveldiff: int = level - compare_level
	return 0.0 - float(leveldiff) * stepping


## `GameObject.GetLevelFromCon` — GameServer/gameobjects/GameObject.cs:1086.
##
## PIÈGE RECOPIÉ TEL QUEL : le pas y vaut `(level + 10) / 10`, pas `(level + 9)
## / 10` comme dans `GetConLevel`. Les deux fonctions ne sont donc PAS
## réciproques dans DOL. Ce n'est pas une faute de frappe de ce portage.
static func level_from_con(level: int, con: float) -> int:
	var constep: int = maxi(1, int((level + 10) / 10.0))
	return maxi(0, int(float(level) + float(constep) * con))


const CON_GREY := "grey"
const CON_GREEN := "green"
const CON_BLUE := "blue"
const CON_YELLOW := "yellow"
const CON_ORANGE := "orange"
const CON_RED := "red"
const CON_PURPLE := "purple"


## La couleur affichée, depuis l'écart en crans documenté à `GetConLevel`
## (GameObject.cs:1043-1053). C'est le commentaire de DOL qui donne la table de
## correspondance, pas une convention choisie ici.
static func con_colour(killer_level: int, victim_level: int) -> String:
	var con: float = con_level(killer_level, victim_level)
	if con <= -3.0:
		return CON_GREY
	if con <= -2.0:
		return CON_GREEN
	if con <= -1.0:
		return CON_BLUE
	if con < 1.0:
		return CON_YELLOW
	if con < 2.0:
		return CON_ORANGE
	if con < 3.0:
		return CON_RED
	return CON_PURPLE


## Ce qu'un tueur gagne réellement pour une victime, en solo.
##
## `AbstractServerRules.OnNPCKilled` — AbstractServerRules.cs:1179-1242.
## L'enchaînement porté ici est celui du cas simple, sans groupe ni animal :
##
##   1. la valeur de base est celle de la victime, `ExperienceValue` ;
##   2. le plafond est `xp_for_living(niveau du tueur) * XP_CAP_PERCENT / 100` ;
##   3. si la victime est GRISE, le gain est nul — c'est `NoXPForLevel`, pas le
##      plafond, qui le décide.
##
## CE QUI N'EST PAS PORTÉ, et qui est nommé pour ne pas être oublié : le partage
## par pourcentage de dégâts (`damagePercent`), le code de défi de groupe
## (`Challenge Code`), le bonus de camp, les points de royaume et de prime.
## L'arbitre local n'a ni groupe, ni animal, ni horloge de spawn.
static func kill_experience(killer_level: int, victim_level: int, options: Dictionary = {}) -> Dictionary:
	var colour: String = con_colour(killer_level, victim_level)
	var grey: bool = is_grey(killer_level, victim_level)
	var base_value: int = xp_for_living(maxi(0, victim_level))
	var cap: int = int(float(xp_for_living(maxi(0, killer_level))) * float(XP_CAP_PERCENT) / 100.0)

	var damage_share: float = clampf(float(options.get("damage_share", 1.0)), 0.0, 1.0)
	var bonus: float = maxf(0.0, float(options.get("bonus_multiplier", 1.0)))

	var amount: int = 0
	var capped: bool = false
	if not grey:
		amount = int(round(float(base_value) * damage_share))
		if amount > cap:
			amount = cap
			capped = true
		amount = int(round(float(amount) * bonus))

	return {
		"amount": amount,
		"con": colour,
		"con_level": con_level(killer_level, victim_level),
		"grey": grey,
		"base": base_value,
		"cap": cap,
		"capped": capped,
		"killer_level": killer_level,
		"victim_level": victim_level,
		"basis": BASIS_DOL_CODE,
		"con_basis": BASIS_DOL_CODE,
	}


# =============================================================================
# 2. VIE, MANA, ENDURANCE
# =============================================================================

## `ServerProperties.GAMENPC_BASE_CON` — ServerProperties.cs:1344. Défaut 30.
const GAMENPC_BASE_CON: int = 30
## `ServerProperties.GAMENPC_HP_GAIN_PER_CON` — ServerProperties.cs:1338. Défaut 2.
const GAMENPC_HP_GAIN_PER_CON: int = 2


## `MaxHealthCalculator.CalcValue`, branche `GameNPC` —
## GameServer/propertycalc/MaxHealthCalculator.cs:61-95.
##
## LA FORMULE QUI MANQUAIT DEPUIS P1-21A. Trois morceaux, dans cet ordre :
##
##   1. la vie de base par le niveau — linéaire sous 10, quadratique au-dessus,
##      avec un palier de +20 sous 25 (DOL commente : « approx to original
##      formula, thx to mathematica ») ;
##   2. l'ajustement par la constitution DE BASE du mob, celle de `mob.sql`,
##      à raison de 2 points de vie par point au-dessus de 30 ;
##   3. l'ajustement par la constitution MODIFIÉE (buffs), borné à ±50 %.
##
## L'arbitre local n'a pas de buffs : `modified_constitution` vaut par défaut la
## constitution de base, et le troisième morceau ne fait alors rien — exactement
## comme DOL sur un mob nu.
static func npc_max_health(level: int, base_constitution: int = GAMENPC_BASE_CON, modified_constitution: int = -1) -> int:
	var lvl: int = maxi(0, level)
	var hp: int = 0
	if lvl < 10:
		hp = lvl * 20 + 20
	else:
		hp = int(50.0 + 11.0 * float(lvl) + 0.548331 * float(lvl) * float(lvl))
		if lvl < 25:
			hp += 20

	var basecon: int = base_constitution
	if basecon != GAMENPC_BASE_CON:
		hp = maxi(1, hp + (basecon - GAMENPC_BASE_CON) * GAMENPC_HP_GAIN_PER_CON)

	var modcon: int = modified_constitution if modified_constitution >= 0 else basecon
	var conmod: int = 20
	var conhp: int = hp + int(float(conmod * lvl * (modcon - basecon)) / 250.0)

	# Plafond de buff/debuff a 50 %, recopie tel quel : DOL compare a
	# `hp * 1.5` en flottant et divise par 2 en ENTIER.
	if float(conhp) > float(hp) * 1.5:
		conhp = int(float(hp) * 1.5)
	elif conhp < int(hp / 2.0):
		conhp = int(hp / 2.0)
	return conhp


## `MaxHealthCalculator.CalcValue`, branche par défaut —
## MaxHealthCalculator.cs:100-115. Une entité vivante qui n'est ni joueur, ni
## PNJ, ni élément de fort. Portée pour que le cas existe, pas parce qu'il sert.
static func generic_max_health(level: int) -> int:
	var lvl: int = maxi(0, level)
	if lvl < 10:
		return lvl * 20 + 20
	var hp: int = int(50.0 + 11.0 * float(lvl) + 0.548331 * float(lvl) * float(lvl))
	if lvl < 25:
		hp += 20
	return hp


## `GamePlayer.CalculateMaxHealth` — GameServer/gameobjects/GamePlayer.cs:2500.
##
## RIEN À VOIR AVEC CELLE DES PNJ, et c'est le point : la vie d'un joueur dépend
## du `BaseHP` de sa CLASSE, une valeur qui va de 560 à 880 selon le métier. Une
## seule formule pour les deux aurait été une invention.
##
## La constitution entre par un écart à 50, DOUBLÉ quand il est négatif — un
## personnage sous les 50 de constitution est puni deux fois.
static func player_max_health(level: int, constitution: int, class_base_hp: int) -> int:
	var con: int = constitution - 50
	if con < 0:
		con *= 2
	var hp1: int = class_base_hp * maxi(0, level)
	var hp2: int = int(float(hp1 * con) / 10000.0)
	var hp4: float = 20.0 + float(int(float(hp1) / 50.0)) + float(hp2)
	return maxi(1, int(hp4))


## `GamePlayer.CalculateMaxMana` — GamePlayer.cs:2538.
##
## LA JAUGE QUI N'AVAIT PAS D'ÉCHELLE. `mana` et `endurance` n'étaient jamais
## publiés par l'arbitre local, comptés dans `unpublished_for_lack_of_scale`,
## parce qu'aucune source ne donnait leur maximum. La voici.
##
## Un métier sans caractéristique d'incantation (`mana_stat` non déclarée) a un
## pool de zéro — un guerrier n'a pas de mana, ce n'est pas un défaut.
static func player_max_mana(level: int, mana_stat_value: int, has_mana_stat: bool = true) -> int:
	if not has_mana_stat:
		return 0
	return maxi(5, (maxi(0, level) * 5) + (mana_stat_value - 50))


## `FatigueCalculator.CalcValue` — GameServer/propertycalc/FatigueCalculator.cs:20.
##
## L'endurance maximale n'est PAS calculée : c'est `DBMaxEndurance`, une colonne
## du personnage, et sa valeur de départ est 100 pour tout le monde. Les objets
## peuvent l'augmenter de 15 % au plus.
const PLAYER_BASE_MAX_ENDURANCE: int = 100

static func player_max_endurance(db_max_endurance: int = PLAYER_BASE_MAX_ENDURANCE, item_bonus_percent: int = 0) -> int:
	var endurance: float = float(db_max_endurance)
	endurance += endurance * (float(mini(15, item_bonus_percent)) * 0.01)
	return int(endurance)


# =============================================================================
# 3. RÉGÉNÉRATION
# =============================================================================

## Périodes de régénération, en millisecondes.
## `GameLiving` — GameServer/gameobjects/GameLiving.cs:5106, 5119, 5132.
const HEALTH_REGEN_PERIOD_MSEC: int = 3000
const POWER_REGEN_PERIOD_MSEC: int = 3000
const ENDURANCE_REGEN_PERIOD_MSEC: int = 1000


## `HealthRegenerationRateCalculator.CalcValue` — propertycalc/HealthRegenerationRateCalculator.cs:45.
##
## Le point de bascule est le niveau 26 : sous lui la régénération vaut
## `10 + niveau * 0,2`, au-dessus elle vaut `niveau * 0,6`. Un PNJ en combat
## régénère moitié moins.
##
## LA PARTIE DÉCIMALE EST TIRÉE AU SORT dans DOL (`Util.ChanceDouble`) pour
## compenser l'arrondi entier. Ici elle est rendue telle quelle, et l'appelant
## décide : l'arbitre local tire de façon DÉTERMINISTE, sinon deux sessions
## rejouées divergeraient.
static func health_regen_per_tick(level: int, in_combat: bool = false, is_npc: bool = false, diseased: bool = false) -> float:
	if diseased:
		return 0.0
	var lvl: float = float(maxi(0, level))
	var regen: float = (10.0 + lvl * 0.2) if level < 26 else (lvl * 0.6)
	if is_npc and in_combat:
		regen /= 2.0
	return regen


## `PowerRegenerationRateCalculator.CalcValue` — propertycalc/PowerRegenerationRateCalculator.cs:40.
## Plancher de 1 recopié : personne ne régénère zéro mana.
static func power_regen_per_tick(level: int, in_combat: bool = false, is_npc: bool = false) -> float:
	var regen: float = 5.0 + (float(maxi(0, level)) / 2.75)
	if is_npc and in_combat:
		regen /= 2.0
	return maxf(1.0, regen)


## `EnduranceRegenerationRateCalculator.CalcValue` — propertycalc/EnduranceRegenerationRateCalculator.cs:44.
##
## L'endurance ne dépend PAS du niveau. Un joueur régénère 1 par tic en combat,
## 5 hors combat debout — et le patch 1.87 a supprimé la nécessité de s'asseoir.
## Un joueur qui SPRINTE ne régénère pas : il paye (voir `SPRINT_COST_PER_TICK`).
static func endurance_regen_per_tick(is_player: bool, in_combat: bool = false, sprinting: bool = false) -> float:
	var regen: float = 0.0
	if is_player:
		regen = 1.0
	if not in_combat and is_player and not sprinting:
		regen += 4.0
	return maxf(0.0, regen)


## `GamePlayer.EnduranceRegenerationTimerCallback` — GamePlayer.cs:2416-2445.
## Le sprint retire 5 points d'endurance par tic — la capacité « Long Wind » les
## réduit, et n'est pas portée. Le tic d'endurance vaut `500 + alea(1000)` ms.
const SPRINT_COST_PER_TICK: int = 5


## Intervalle avant le prochain tic, en millisecondes.
## `GameLiving.HealthRegenerationTimerCallback` — GameLiving.cs:5305-5312 : en
## combat, un tic vaut cinq fois la période, « aprox 15 seconds - tolakram ».
static func health_regen_interval_msec(in_combat: bool) -> int:
	return HEALTH_REGEN_PERIOD_MSEC * 5 if in_combat else HEALTH_REGEN_PERIOD_MSEC


## `GameLiving.PowerRegenerationTimerCallback` — GameLiving.cs:5358-5364.
static func power_regen_interval_msec(in_combat: bool) -> int:
	return int(float(POWER_REGEN_PERIOD_MSEC) * 3.4) if in_combat else POWER_REGEN_PERIOD_MSEC


# =============================================================================
# 4. MÊLÉE
# =============================================================================

## `GameLiving.AttackSpeed` — GameServer/gameobjects/GameLiving.cs:844.
##
## LA VITESSE D'UN PNJ NE DÉPEND PAS DE SON ARME. C'est 3000 ms corrigés par la
## vivacité seule, avec un plancher de 500 ms. Une arme de PNJ n'a pas de
## `SPD_ABS` qui compte : DOL ne le lit pas dans cette branche.
static func npc_attack_speed_msec(quickness: int = 60, melee_speed_percent: int = 100) -> int:
	var speed: float = 3000.0 * (1.0 - (float(quickness) - 60.0) / 500.0)
	speed *= float(melee_speed_percent) * 0.01
	return int(maxf(500.0, speed))


## `GamePlayer.AttackSpeed` — GameServer/gameobjects/GamePlayer.cs:7297.
##
## Celle du joueur, elle, part de la vitesse de l'arme (`SPD_ABS`, en dixièmes de
## seconde) et applique la vivacité PLAFONNÉE À 250. Le plancher est de 15
## dixièmes, soit 1500 ms.
static func player_attack_speed_msec(weapon_spd_abs: float, quickness: int = 60, melee_speed_percent: int = 100) -> int:
	var qui: int = mini(250, quickness)
	var speed: float = weapon_spd_abs
	speed *= (1.0 - (float(qui) - 60.0) * 0.002) * 0.01 * float(melee_speed_percent)
	if speed < 15.0:
		speed = 15.0
	return int(speed * 100.0)


## `GameLiving.AttackDamage` — GameLiving.cs:870.
##
## Les dégâts BRUTS d'un PNJ, avant toute défense. Ils ne dépendent que du niveau
## et de la vitesse d'attaque — plus on frappe lentement, plus on frappe fort.
static func npc_attack_damage(level: int, attack_speed_msec: int, melee_damage_percent: int = 0) -> float:
	var lvl: float = float(maxi(0, level))
	var damage: float = (1.0 + lvl / 3.7 + lvl * lvl / 175.0) * float(attack_speed_msec) * 0.001
	return damage * (1.0 + float(melee_damage_percent) * 0.01)


## `GamePlayer.WeaponDamage` — GamePlayer.cs:7050.
##
## LE PLAFOND DE DPS EST LE POINT IMPORTANT : `12 + 3 * niveau`. Une arme de DPS
## 50 dans les mains d'un niveau 5 frappe comme une arme de DPS 27. C'est ce qui
## empêche un objet trouvé trop tôt de casser la progression.
static func player_weapon_damage(weapon_dps_af: int, level: int, quality: int = 100, condition: int = 100, max_condition: int = 100) -> float:
	var dps: int = weapon_dps_af
	var cap: int = 12 + 3 * maxi(0, level)
	if dps > cap:
		dps = cap
	return (0.001 * float(dps) * float(quality) * float(condition)) / float(maxi(1, max_condition))


## `GamePlayer.AttackDamage` — GamePlayer.cs:7382.
## Le bonus deux mains vaut 10 % plus un demi-point par niveau de spécialisation.
static func player_attack_damage(weapon_dps_af: int, weapon_spd_abs: float, level: int, two_handed: bool = false, weapon_spec_level: int = 1, quality: int = 100, condition: int = 100, max_condition: int = 100, melee_damage_percent: int = 0) -> float:
	var damage: float = player_weapon_damage(weapon_dps_af, level, quality, condition, max_condition) * weapon_spd_abs * 0.1
	if two_handed:
		damage *= 1.1 + float(maxi(0, weapon_spec_level - 1)) * 0.005
	return damage * (1.0 + float(melee_damage_percent) * 0.01)


## `GameLiving.UnstyledDamageCap` — GameLiving.cs:906.
static func npc_unstyled_damage_cap(attack_damage: float, attack_speed_msec: int) -> float:
	return attack_damage * (2.82 + 0.00009 * float(attack_speed_msec))


## `GamePlayer.UnstyledDamageCap` — GamePlayer.cs:7087.
static func player_unstyled_damage_cap(weapon_dps_af: int, weapon_spd_abs: float, level: int, two_handed: bool = false, weapon_spec_level: int = 1) -> float:
	var dps: int = weapon_dps_af
	var cap: int = 12 + 3 * maxi(0, level)
	if dps > cap:
		dps = cap
	var result: float = float(dps) * weapon_spd_abs * 0.03 * (0.94 + 0.003 * weapon_spd_abs)
	if two_handed:
		result *= 1.1 + float(maxi(0, weapon_spec_level - 1)) * 0.005
	return result


## `SkillBase.InitializeObjectTypeToSpec` — gameutils/SkillBase.cs:1027.
##
## QUELLE SPÉCIALISATION GOUVERNE UNE ARME. Le `Object_Type` d'`itemtemplate` y
## renvoie : 3 est une arme tranchante, donc la spécialisation « Slash ».
##
## LES NOMS SONT LES VALEURS DES CONSTANTES `Specs`, jamais leurs identifiants
## C# : `Specs.Two_Handed` vaut « Two Handed », avec une espace.
##
## L'ARC LONG EST AMBIGU DANS DOL LUI-MÊME : `ALLOW_OLD_ARCHERY` le renvoie vers
## « Longbow » ou vers « Archery ». Le défaut de la propriété serveur tranche, et
## c'est déclaré ici plutôt que choisi en silence.
const OBJECT_TYPE_TO_SPEC: Dictionary = {
	2: "Crush",          # CrushingWeapon
	3: "Slash",          # SlashingWeapon
	4: "Thrust",         # ThrustWeapon
	5: "Shortbow",       # Fired
	6: "Two Handed",     # TwoHandedWeapon
	7: "Polearms",       # PolearmWeapon
	8: "Staff",          # Staff
	10: "Crossbow",      # Crossbow
	11: "Sword",         # Sword
	12: "Hammer",        # Hammer
	13: "Axe",           # Axe
	14: "Spear",         # Spear
	16: "Thrown Weapons",# Thrown
	17: "Left Axe",      # LeftAxe
	19: "Blades",        # Blades
	20: "Blunt",         # Blunt
	21: "Piercing",      # Piercing
	22: "Large Weapons", # LargeWeapons
	23: "Celtic Spear",  # CelticSpear
	24: "Flexible",      # Flexible
	25: "Hand to Hand",  # HandToHand
	26: "Scythe",        # Scythe
}


static func spec_for_object_type(object_type: int) -> String:
	return str(OBJECT_TYPE_TO_SPEC.get(object_type, ""))


## `GamePlayer.GetAutoTrainPoints` — GamePlayer.cs:5274.
##
## LE SEUL MORCEAU DE PROGRESSION DE PERSONNAGE QUI SOIT DÉRIVABLE. Certaines
## spécialisations montent SEULES jusqu'à `niveau / 4`, sans dépense : ce n'est
## pas un choix de build, c'est une règle du métier.
##
## Le plancher est 1 et non 0 : DOL écrit `if (max_autotrain == 0) max_autotrain = 1`.
static func auto_train_spec_level(character_level: int) -> int:
	var maximum: int = int(maxi(0, character_level) / 4.0)
	return maximum if maximum > 0 else 1


## `GameLiving.GetWeaponSkill` — GameLiving.cs:1041.
## Le commentaire d'origine prévient : « base factor (not 400) ».
static func npc_weapon_skill(level: int, weapon_stat: int) -> float:
	var bs: float = 128.0 / 50.0
	var lvl: float = float(maxi(0, level))
	return float(int((lvl + 1.0) * bs * (1.0 + (float(weapon_stat) - 50.0) * 0.005) * lvl * 2.0 / 50.0))


## `GamePlayer.GetWeaponSkill` — GamePlayer.cs:6925.
## `class_weapon_skill_base` est le `BaseWeaponSkill` du métier — 440 pour un
## Armsman, 360 pour un Scout. Il vit dans `CharacterClassDB.cs`.
static func player_weapon_skill(level: int, class_weapon_skill_base: int, weapon_stat: int, effectiveness: float = 1.0) -> float:
	var lvl: float = float(maxi(0, level))
	return maxf(0.0, lvl * float(class_weapon_skill_base) * 0.02 * (1.0 + (float(weapon_stat) - 50.0) * 0.005) * effectiveness)


## `GameLiving.GetArmorAbsorb` — GameLiving.cs:1006.
##
## L'ABSORPTION DE BASE EST UN ESCALIER À TROIS MARCHES : 10 % au niveau 10,
## 19 % au niveau 20, 27 % au niveau 30, et plus rien ensuite. La constitution de
## base y ajoute un écart à 60 divisé par 12.
static func living_armor_absorb(level: int, base_constitution: int = 60, absorb_bonus_percent: int = 0) -> float:
	var base_absorb: float = 0.0
	if level >= 30:
		base_absorb = 0.27
	elif level >= 20:
		base_absorb = 0.19
	elif level >= 10:
		base_absorb = 0.10

	var constitution_absorb: float = (float(base_constitution) - 60.0) / 12.0 / 100.0
	var absorb_bonus: float = float(absorb_bonus_percent) / 100.0
	return 1.0 - (1.0 - absorb_bonus) * (1.0 - base_absorb) * (1.0 - constitution_absorb)


## `GamePlayer.GetArmorAF` — GamePlayer.cs:6985.
##
## Le facteur d'armure d'un joueur est celui de la PIÈCE touchée, plafonné au
## niveau (doublé si l'armure n'est pas du tissu), puis multiplié par 4,67 —
## « compensate *4.67 in damage formula », dit le commentaire. Ce facteur revient
## à l'identique dans `melee_damage` : les deux se répondent.
static func player_armor_af(item_dps_af: float, level: int, is_cloth: bool = false, quality: int = 100, condition: int = 100, max_condition: int = 100, realm_level: int = 0) -> float:
	var item_af_cap: int = maxi(0, level)
	if realm_level > 39:
		item_af_cap += 1
	if not is_cloth:
		item_af_cap = item_af_cap << 1
	var eaf: float = minf(item_dps_af, float(item_af_cap))
	eaf *= 4.67
	eaf *= float(quality) * 0.01 * float(condition) / float(maxi(1, max_condition))
	return eaf


## `GamePlayer.CalculateArmorHitLocation` — GamePlayer.cs:6833.
##
## OÙ LE COUP TOMBE, et ce n'est pas uniforme : le torse encaisse 40 % des
## coups, les jambes 25, les bras 15, la tête 10, les mains 5, les pieds 5. Un
## tirage uniforme sur six logements donnerait 16,7 % partout et rendrait les
## bottes aussi souvent touchées que le torse.
##
## `roll_1_100` est fourni par l'appelant : DOL tire `Util.Random(1, 100)`,
## l'arbitre local tire de façon déterministe.
## `eObjectType.Cloth` — GameServer/GlobalConstants.cs:150. Le plafond de
## facteur d'armure d'une piece de TISSU n'est PAS double comme celui des autres.
const OBJECT_TYPE_CLOTH: int = 32

const ARMOR_SLOT_HEAD: int = 21
const ARMOR_SLOT_HANDS: int = 22
const ARMOR_SLOT_FEET: int = 23
const ARMOR_SLOT_TORSO: int = 25
const ARMOR_SLOT_LEGS: int = 27
const ARMOR_SLOT_ARMS: int = 28

static func armor_hit_location(roll_1_100: int) -> int:
	var roll: int = clampi(roll_1_100, 1, 100)
	if roll <= 40:
		return ARMOR_SLOT_TORSO
	if roll <= 65:
		return ARMOR_SLOT_LEGS
	if roll <= 80:
		return ARMOR_SLOT_ARMS
	if roll <= 90:
		return ARMOR_SLOT_HEAD
	if roll <= 95:
		return ARMOR_SLOT_HANDS
	return ARMOR_SLOT_FEET


## `GamePlayer.GetArmorAbsorb` — GamePlayer.cs:7021.
##
## POUR UNE ARMURE, `SPD_ABS` N'EST PAS UNE VITESSE : c'est le POURCENTAGE
## D'ABSORPTION. Le même champ porte deux sens selon le type d'objet — 25 sur
## une épée veut dire 2,5 secondes, 19 sur un plastron veut dire 19 %. Lire
## l'un pour l'autre est silencieux et faux.
static func player_armor_absorb(item_spd_abs: int, absorb_bonus_percent: int = 0) -> float:
	return float(item_spd_abs + absorb_bonus_percent) * 0.01


## `GameLiving.GetArmorAF` — GameLiving.cs:996. Un PNJ n'a pas d'inventaire : son
## facteur d'armure est sa propriété `ArmorFactor`, zéro par défaut.
static func npc_armor_af(armor_factor: float = 0.0) -> float:
	return armor_factor


## LA CHAÎNE DE DÉGÂTS COMPLÈTE — `GameLiving.Attack`, GameLiving.cs:1725-1805.
##
## L'ordre est celui de DOL, et il compte :
##
##   1. dégâts bruts de l'attaquant (`AttackDamage`) ;
##   2. rapport arme / armure : `(compétence + 90,68) / (AF + 93,4)` — le 93,4
##      est le `20 * 4,67` écrit en clair dans la source ;
##   3. absorption, plafonnée à 85 % ;
##   4. variance : `(borne basse + alea(50)) / 100`, la borne basse allant de 75
##      à 125 selon la spécialisation ;
##   5. résistances de la cible ;
##   6. PLAFOND `UnstyledDamageCap` — appliqué APRÈS tout le reste ;
##   7. plancher : un coup qui touche fait au moins 1.
##
## `random_0_49` est fourni par l'appelant, exprès : l'arbitre local tire de
## façon déterministe et une session rejouée doit rendre les mêmes chiffres.
static func melee_damage(
	attack_damage: float,
	weapon_skill: float,
	target_armor_af: float,
	target_absorb: float,
	unstyled_cap: float,
	random_0_49: int = 25,
	weapon_spec_level: int = 1,
	target_effective_level: int = 1,
	resist_percent: float = 0.0
) -> Dictionary:
	var damage: float = attack_damage

	var lowerboundary: int = int(float((maxi(0, weapon_spec_level) - 1) * 50) / float(maxi(0, target_effective_level) + 1)) + 75
	lowerboundary = clampi(lowerboundary, 75, 125)

	damage *= (weapon_skill + 90.68) / (target_armor_af + 20.0 * 4.67)
	damage *= 1.0 - minf(0.85, target_absorb)
	damage *= float(lowerboundary + clampi(random_0_49, 0, 49)) * 0.01

	var modifier: float = damage * resist_percent * -0.01
	damage += modifier

	var uncapped: int = int(damage)
	var final_damage: int = uncapped
	var capped: bool = false
	if unstyled_cap > 0.0 and float(final_damage) > unstyled_cap:
		final_damage = int(unstyled_cap)
		capped = true
	if final_damage < 1:
		final_damage = 1

	return {
		"damage": final_damage,
		"uncapped_damage": uncapped,
		"capped": capped,
		"modifier": int(modifier),
		"lower_boundary": lowerboundary,
		"basis": BASIS_DOL_CODE,
	}


## `ServerProperties.MISSRATE_REDUCTION_PER_ATTACKERS` — ServerProperties.cs:1918.
## Défaut 0 : par défaut, être à plusieurs ne réduit PAS le taux de rate.
const MISSRATE_REDUCTION_PER_ATTACKERS: int = 0


## `GameLiving.CalculateEnemyAttackResult` — GameLiving.cs:3600-3675.
##
## LE TAUX DE RATE DE BASE EST UNE CONSTANTE, ET ELLE DIFFÈRE SELON L'ATTAQUANT :
## 20 % pour un joueur, 25 % pour un PNJ. « player vs player tests show 20% miss
## on any level », dit la source.
##
## L'écart de niveau entre en `5 * con_level`, et ce terme ne s'applique QU'EN
## PvE : un joueur contre un joueur n'en a pas.
##
## PIÈGE RECOPIÉ : le bonus d'armure entre en POURCENTAGE en PvE
## (`missrate += missrate * armorBonus / 100`) mais en POINTS en PvP.
static func miss_rate_percent(
	attacker_level: int,
	target_level: int,
	attacker_is_player: bool,
	target_is_player: bool,
	options: Dictionary = {}
) -> float:
	var missrate: float = 20.0 if attacker_is_player else 25.0
	missrate -= float(options.get("to_hit_bonus", 0))

	var pve: bool = not (attacker_is_player and target_is_player)
	if pve:
		missrate += 5.0 * con_level(attacker_level, target_level)
		var attackers: int = maxi(1, int(options.get("attacker_count", 1)))
		missrate -= float((attackers - 1) * MISSRATE_REDUCTION_PER_ATTACKERS)

	var armor_bonus: float = float(options.get("armor_bonus", 0)) - float(options.get("weapon_bonus", 0))
	if attacker_is_player and target_is_player:
		missrate += armor_bonus
	else:
		missrate += missrate * armor_bonus / 100.0

	missrate -= float(options.get("style_bonus_to_hit", 0))
	missrate += float(options.get("last_style_bonus_to_defense", 0))

	if bool(options.get("target_is_sitting", false)):
		missrate = float(int(missrate) >> 1)

	return missrate


# =============================================================================
# 4 bis. LES TROIS DÉFENSES ACTIVES
# =============================================================================

## Plafonds — `ServerProperties` : block_cap 0.60 (ServerProperties.cs:925),
## evade_cap 0.50 (:931), parry_cap 0.50 (:937). Ils ne s'appliquent QUE joueur
## contre joueur ; en PvE, le plafond dur est 99,5 %.
const BLOCK_CAP: float = 0.60
const EVADE_CAP: float = 0.50
const PARRY_CAP: float = 0.50

## `eObjectType.Shield` — GlobalConstants.cs:161.
const OBJECT_TYPE_SHIELD: int = 42

## `BlockChanceCalculator.CalcValue` — propertycalc/BlockChanceCalculator.cs.
##
## Rend des MILLIÈMES, pas des pourcents : `TryBlock` multiplie ensuite par
## 0,001. Un joueur sans spécialisation Boucliers part quand même de 50 —
## c'est-à-dire 5 % — plus un quart de son excès de dextérité.
static func player_block_chance_raw(dexterity: int, shield_spec_level: int = 1, ability_bonus: int = 0) -> int:
	var shield: int = (maxi(1, shield_spec_level) - 1) * 5
	return 50 + shield + int((dexterity * 2 - 100) / 4.0) + ability_bonus * 10


## `ParryChanceCalculator.CalcValue` — propertycalc/ParryChanceCalculator.cs.
##
## ZÉRO SANS LA SPÉCIALISATION, et ce n'est pas un oubli : `HasSpecialization`
## garde toute la formule. Un personnage qui n'a jamais appris à parer ne pare
## jamais, quelle que soit sa dextérité.
static func player_parry_chance_raw(dexterity: int, has_parry_spec: bool, parry_spec_level: int = 1) -> int:
	if not has_parry_spec:
		return 0
	var chance: int = int((dexterity * 2 - 100) / 4.0) + (maxi(1, parry_spec_level) - 1) * 5 + 50
	return mini(500, chance)


## `EvadeChanceCalculator.CalcValue` — propertycalc/EvadeChanceCalculator.cs.
##
## MÊME RÈGLE QUE LA PARADE : sans la capacité Esquive, rien. Et la formule ne
## dépend PAS que de la dextérité — la vivacité compte autant.
static func player_evade_chance_raw(quickness: int, dexterity: int, evade_ability_level: int = 0) -> int:
	if evade_ability_level <= 0:
		return 0
	return int((1000 + quickness + dexterity - 100) * evade_ability_level * 5 / 100.0)


## `GameLiving.TryEvade` — GameLiving.cs:3736.
##
## L'ORDRE DES OPÉRATIONS COMPTE, et il est recopié tel quel : le malus pour
## attaquants multiples est retiré AVANT la conversion en millièmes, l'écart de
## con est ajouté APRÈS. Les inverser change le résultat.
##
## `attacker_con_level` est l'écart vu par le DÉFENSEUR — `-GetConLevel(attaquant)`
## — donc positif quand l'attaquant est plus faible que lui.
static func evade_chance(raw_chance: int, attacker_con_level: float, attacker_count: int = 1,
		last_style_bonus_to_defense: int = 0, is_ranged: bool = false,
		pvp: bool = false, stunned_or_sitting: bool = false) -> float:
	if raw_chance <= 0 or stunned_or_sitting:
		return 0.0
	var chance: float = float(raw_chance)
	if attacker_count > 1:
		chance -= float(attacker_count - 1) * 0.03
	chance *= 0.001
	chance += 0.01 * attacker_con_level
	chance += float(last_style_bonus_to_defense) * 0.01
	if is_ranged:
		chance /= 5.0
	if chance < 0.01:
		return 0.01
	if pvp and chance > EVADE_CAP:
		return EVADE_CAP
	return minf(chance, 0.995)


## `GameLiving.TryParry` — GameLiving.cs:3810.
##
## PIÈGE RECOPIÉ TEL QUEL : le partage entre attaquants est `chance /= n / 2` en
## division ENTIÈRE. À deux attaquants, `2 / 2` vaut 1 et la parade n'est donc
## PAS réduite ; à trois, `3 / 2` vaut 1 aussi. Le premier partage réel arrive à
## quatre. Ce n'est pas ce que le commentaire de DOL décrit, et ce portage ne le
## « corrige » pas.
static func parry_chance(raw_chance: int, attacker_con_level: float, attacker_count: int = 1,
		pvp: bool = false, stunned_or_sitting: bool = false) -> float:
	if raw_chance <= 0 or stunned_or_sitting:
		return 0.0
	var chance: float = float(raw_chance)
	if attacker_count > 1:
		var divisor: int = int(attacker_count / 2.0)
		if divisor > 0:
			chance /= float(divisor)
	chance *= 0.001
	chance += 0.05 * attacker_con_level
	if chance < 0.01:
		return 0.01
	if pvp and chance > PARRY_CAP:
		return PARRY_CAP
	return minf(chance, 0.995)


## `GameLiving.TryBlock` — GameLiving.cs:3893.
##
## LA QUALITÉ DU BOUCLIER ENTRE DANS LA CHANCE, ce qui n'est le cas d'aucune
## autre défense : `chance * qualité * 0,01`.
##
## ET `Type_Damage` D'UN BOUCLIER EST SA TAILLE — 1 petit, 2 moyen, 3 grand. Ce
## champ porte donc un TROISIÈME sens : type de dégâts sur une arme, taille sur
## un bouclier. La taille décide combien d'attaquants un bouclier peut couvrir,
## et le plafond en PvE.
static func block_chance(raw_chance: int, shield_quality: int, shield_size: int,
		attacker_con_level: float, attacker_count: int = 1,
		attacker_is_player: bool = false, stunned_or_sitting: bool = false) -> float:
	if raw_chance <= 0 or shield_size <= 0 or stunned_or_sitting:
		return 0.0
	var chance: float = float(raw_chance) * float(shield_quality) * 0.01
	if attacker_count > shield_size:
		chance *= float(shield_size) / float(attacker_count)
	chance *= 0.001
	chance += attacker_con_level * 0.05
	if chance < 0.01:
		return 0.01
	if attacker_is_player and chance > BLOCK_CAP:
		return BLOCK_CAP
	# EN PvE LE PLAFOND DÉPEND DE LA TAILLE DU BOUCLIER : 80 % pour un petit,
	# 90 % pour un moyen, 99 % pour un grand.
	if not attacker_is_player:
		if shield_size == 1:
			return minf(chance, 0.80)
		if shield_size == 2:
			return minf(chance, 0.90)
		if shield_size == 3:
			return minf(chance, 0.99)
	return minf(chance, 0.995)


# =============================================================================
# 4 ter. LES STYLES
# =============================================================================

## LE SEUIL QUI ANNULE TOUT, et il n'a rien d'évident.
##
## `StyleProcessor.ExecuteStyle` (GameServer/styles/StyleProcessor.cs:411) écrit :
## `if (weapon.DPS_AF >= 15) absorbRatio = ...`. En dessous, `absorbRatio` reste
## à **zéro**, et comme les dégâts de style sont un PRODUIT, tout s'annule.
##
## **Une arme de DPS inférieur à 15 ne tire AUCUN bénéfice d'un style.** L'épée
## d'entraînement de P1-24 a un DPS de 12 : un personnage de départ peut exécuter
## ses styles, en payer l'endurance, et ne gagner strictement rien. Ce n'est pas
## un défaut de portage, c'est la règle — et elle explique pourquoi les styles ne
## servent à rien avant la première vraie arme.
const STYLE_MIN_WEAPON_DPS: int = 15

## `ServerProperties.CS_OPENING_EFFECTIVENESS` — ServerProperties.cs. Défaut 1.0.
## Ne sert qu'aux styles à croissance STATIQUE, ceux qui exigent la furtivité.
const CS_OPENING_EFFECTIVENESS: float = 1.0


## `StyleProcessor.ExecuteStyle` — StyleProcessor.cs:407-438.
##
## LA CROISSANCE A DEUX TERMES, et les confondre viderait la moitié des styles :
## `GrowthOffset` est la part FIXE, `GrowthRate` la part qui suit la
## spécialisation. Un style à offset nul — c'est le cas de TOUS ceux du dump lu
## le 2026-09-09 — ne vaut donc rien sans spécialisation.
##
## LA VITESSE DE L'ARME MULTIPLIE LE RÉSULTAT, en SECONDES : une arme lente
## frappe moins souvent mais son style rend davantage. Un style n'est donc pas un
## bonus plat, c'est une part du rythme de l'arme.
##
## `attack_speed_msec` est celui de l'attaquant, pas la vitesse brute de l'arme :
## la vivacité y est déjà entrée.
static func style_damage(
	unstyled_damage: int,
	unstyled_damage_cap: float,
	weapon_dps_af: int,
	attack_speed_msec: int,
	growth_rate: float,
	growth_offset: float,
	spec_level: int,
	static_growth: bool = false
) -> Dictionary:
	var absorb_ratio: float = 0.0
	var below_threshold: bool = weapon_dps_af < STYLE_MIN_WEAPON_DPS
	if not below_threshold and unstyled_damage_cap > 0.0:
		absorb_ratio = float(unstyled_damage) / unstyled_damage_cap

	var style_growth: float = maxf(0.0, growth_offset + growth_rate * float(maxi(0, spec_level)))
	var damage: int = 0
	if static_growth:
		# Les styles FURTIFS ne suivent pas la vitesse de l'arme — « static growth
		# is not a function of (effective) weapon speed », dit la source.
		damage = int(absorb_ratio * style_growth * CS_OPENING_EFFECTIVENESS)
	else:
		damage = int(absorb_ratio * style_growth * float(attack_speed_msec) * 0.001)

	return {
		"style_damage": maxi(0, damage),
		"absorb_ratio": absorb_ratio,
		"style_growth": style_growth,
		"below_dps_threshold": below_threshold,
		"basis": BASIS_DOL_CODE,
	}


## `StyleProcessor.CalculateEnduranceCost` — StyleProcessor.cs:540.
##
## LE COÛT SUIT LA VITESSE DE L'ARME, pas seulement le style : `vitesse * coût /
## 40`, plus un point si l'arme est plus rapide que 4 secondes. Une arme lente
## coûte donc plus cher par coup, ce qui compense en partie son rendement.
static func style_endurance_cost(weapon_spd_abs: int, style_endurance_cost: int,
		fatigue_consumption_percent: int = 100) -> int:
	var cost: int = int(weapon_spd_abs * style_endurance_cost / 40.0)
	if weapon_spd_abs < 40:
		cost += 1
	return maxi(0, int(ceil(float(cost) * float(fatigue_consumption_percent) * 0.01)))


## `StyleProcessor.ExecuteStyle` — StyleProcessor.cs:373-383.
##
## UN STYLE RATÉ COÛTE QUAND MÊME, mais moitié moins — et jamais moins de 1.
## Bloqué, esquivé, paré, raté : les quatre coûtent la même demi-endurance.
static func failed_style_endurance_cost(full_cost: int) -> int:
	return maxi(1, int(full_cost / 2.0))


# =============================================================================
# 5. ARGENT
# =============================================================================

## `ServerProperties.MONEY_DROP` — ServerProperties.cs:949. Défaut 1.0.
const MONEY_DROP: float = 1.0

## Dénominations — `Money.GetMoney`, GameServer/gameutils/Money.cs:51.
## 100 cuivres font un argent, 100 argents font un or, 1000 ors font un platine,
## 1000 platines font un mithril. LE MITHRIL EXISTE, et il manquait au découpage
## de P1-22C : une somme énorme s'y serait affichée en platines sans plafond.
const COPPER_PER_SILVER: int = 100
const SILVER_PER_GOLD: int = 100
const GOLD_PER_PLATINUM: int = 1000
const PLATINUM_PER_MITHRIL: int = 1000


## `LootGeneratorMoney.GenerateLoot` — GameServer/gameutils/LootGeneratorMoney.cs:38.
##
## L'ARGENT EST CUBIQUE EN NIVEAU, pas quadratique : `2 + ((n+1)^3 >> 3)`, plus
## un aléa entre zéro et la moitié de cette base. Le placeholder de P1-22C était
## quadratique — il surpayait les bas niveaux et sous-payait gravement les hauts.
static func money_for_kill(victim_level: int, random_0_to_half: int = 0) -> Dictionary:
	var lvl: int = maxi(1, victim_level + 1)
	var min_loot: int = 2 + ((lvl * lvl * lvl) >> 3)
	var money_count: int = min_loot + clampi(random_0_to_half, 0, maxi(0, (min_loot >> 1) - 1))
	money_count = int(float(money_count) * MONEY_DROP)
	return {
		"copper": maxi(1, money_count),
		"min_loot": min_loot,
		"basis": BASIS_DOL_CODE,
	}


## Découpe une somme en cuivre selon les cinq dénominations de `Money.cs`.
static func split_money(copper: int) -> Dictionary:
	var total: int = maxi(0, copper)
	var c: int = total % COPPER_PER_SILVER
	var silver_total: int = int(total / COPPER_PER_SILVER)
	var s: int = silver_total % SILVER_PER_GOLD
	var gold_total: int = int(silver_total / SILVER_PER_GOLD)
	var g: int = gold_total % GOLD_PER_PLATINUM
	var platinum_total: int = int(gold_total / GOLD_PER_PLATINUM)
	var p: int = platinum_total % PLATINUM_PER_MITHRIL
	var m: int = int(platinum_total / PLATINUM_PER_MITHRIL)
	return {
		"copper": c, "silver": s, "gold": g, "platinum": p, "mithril": m,
		"total_copper": total,
	}


# =============================================================================
# 6. RACES
# =============================================================================

## `GlobalConstants.STARTING_STATS_DICT` — GameServer/GlobalConstants.cs:1897.
##
## LES STATISTIQUES DE DÉPART DES 22 RACES. Elles ferment une question ouverte du
## dossier `daoc_gameplay_context` : sa trouvaille `F-003` portait cette table
## pour Albion, relevée dans un fil de forum de 2003 et conservée comme « cible
## de recoupement, à supprimer dès que la table est lue directement ».
##
## Elle est lue. Les cinq races d'Albion de 2003 concordent EXACTEMENT.
##
## Ce que le forum ne disait pas : le Half Ogre et le Korazh, postérieurs, et les
## trois Minotaures qui partagent une même ligne 80/70/50/40.
const RACE_STARTING_STATS: Dictionary = {
	"Unknown":          {"STR": 60, "CON": 60, "DEX": 60, "QUI": 60, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Briton":           {"STR": 60, "CON": 60, "DEX": 60, "QUI": 60, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Avalonian":        {"STR": 45, "CON": 45, "DEX": 60, "QUI": 70, "INT": 80, "PIE": 60, "EMP": 60, "CHR": 60},
	"Highlander":       {"STR": 70, "CON": 70, "DEX": 50, "QUI": 50, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Saracen":          {"STR": 50, "CON": 50, "DEX": 80, "QUI": 60, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Norseman":         {"STR": 70, "CON": 70, "DEX": 50, "QUI": 50, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Troll":            {"STR": 100, "CON": 70, "DEX": 35, "QUI": 35, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Dwarf":            {"STR": 60, "CON": 80, "DEX": 50, "QUI": 50, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Kobold":           {"STR": 50, "CON": 50, "DEX": 70, "QUI": 70, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Celt":             {"STR": 60, "CON": 60, "DEX": 60, "QUI": 60, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Firbolg":          {"STR": 90, "CON": 60, "DEX": 40, "QUI": 40, "INT": 60, "PIE": 60, "EMP": 70, "CHR": 60},
	"Elf":              {"STR": 40, "CON": 40, "DEX": 75, "QUI": 75, "INT": 70, "PIE": 60, "EMP": 60, "CHR": 60},
	"Lurikeen":         {"STR": 40, "CON": 40, "DEX": 80, "QUI": 80, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Inconnu":          {"STR": 50, "CON": 60, "DEX": 70, "QUI": 50, "INT": 70, "PIE": 60, "EMP": 60, "CHR": 60},
	"Valkyn":           {"STR": 55, "CON": 45, "DEX": 65, "QUI": 75, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Sylvan":           {"STR": 70, "CON": 60, "DEX": 55, "QUI": 45, "INT": 70, "PIE": 60, "EMP": 60, "CHR": 60},
	"HalfOgre":         {"STR": 90, "CON": 70, "DEX": 40, "QUI": 40, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"Frostalf":         {"STR": 55, "CON": 55, "DEX": 55, "QUI": 60, "INT": 60, "PIE": 75, "EMP": 60, "CHR": 60},
	"Shar":             {"STR": 60, "CON": 80, "DEX": 50, "QUI": 50, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"AlbionMinotaur":   {"STR": 80, "CON": 70, "DEX": 50, "QUI": 40, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"MidgardMinotaur":  {"STR": 80, "CON": 70, "DEX": 50, "QUI": 40, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
	"HiberniaMinotaur": {"STR": 80, "CON": 70, "DEX": 50, "QUI": 40, "INT": 60, "PIE": 60, "EMP": 60, "CHR": 60},
}


static func race_starting_stats(race_name: String) -> Dictionary:
	var found: Variant = RACE_STARTING_STATS.get(race_name, null)
	if found == null:
		return {}
	return (found as Dictionary).duplicate()


# =============================================================================
# 7. DÉPLACEMENT
# =============================================================================

## `GamePlayer.PLAYER_BASE_SPEED` — GameServer/gameobjects/GamePlayer.cs:10272.
##
## À NE PAS CONFONDRE avec `player_run_speed_raw` de la scène, qui vaut 450 et a
## été VALIDÉ VISUELLEMENT par l'utilisateur. Les deux ne sont pas dans la même
## unité et rien ici n'autorise à toucher au second.
const PLAYER_BASE_SPEED: int = 191

## `MaxSpeedCalculator.CalcValue` — propertycalc/MaxSpeedCalculator.cs:70.
## Hors combat, hors furtivité, hors zone RvR : 125 % de la vitesse de base.
const PVE_OUT_OF_COMBAT_SPEED_FACTOR: float = 1.25

## Les cinq paliers de buff de vitesse — MaxSpeedCalculator.cs:41-45.
const SPEED_BUFF_TIERS: Array = [1.753, 1.816, 1.91, 1.989, 2.068]
