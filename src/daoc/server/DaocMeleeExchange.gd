extends RefCounted
class_name DaocMeleeExchange

## P1-21A — resolution d'un coup de melee pour le serveur local.
##
## `DaocAttackComponent` (P1-18B) sait deja calculer les DEGATS, mais il touche
## toujours : il ne tire ni rate, ni parade, ni esquive, ni blocage. Ce fichier
## ajoute cette couche defensive puis lui delegue le calcul de degats.
##
## P1-23 — LE TAUX DE RATE EST DESORMAIS CELUI DE DOL, porte depuis
## `GameLiving.CalculateEnemyAttackResult`. Le TODO de P1-21A est paye.
##
## CE QUE LE PORTAGE A CORRIGE, et ce n'etait pas un detail de reglage :
##
##   - le taux de base n'est pas un nombre unique, il DEPEND DE L'ATTAQUANT —
##     20 % pour un joueur, 25 % pour un PNJ ;
##   - l'ecart de niveau n'entre pas en niveaux mais en CRANS DE COULEUR, par
##     `5 * con_level`. La largeur d'un cran grandit avec le niveau : a 5, deux
##     niveaux d'ecart coutent 10 points de rate ; a 45, ils n'en coutent que 2.
##     Le placeholder appliquait 1,5 point par niveau a tous les niveaux, donc
##     punissait beaucoup trop les hauts niveaux ;
##   - DOL ne BORNE PAS le resultat. Le placeholder le serrait entre 5 et 60 %.
##     La borne est conservee A L'AFFICHAGE et au tirage — un taux negatif ou
##     superieur a 100 ferait un coup toujours sur ou toujours rate — mais le
##     taux BRUT de DOL est rendu a cote, pour que l'ecart soit visible.
##
## P1-25 — L'ORDRE DES TESTS ETAIT FAUX, ET DEUX FOIS.
##
## Ce fichier annoncait depuis P1-21A : « maladresse, rate, blocage, parade,
## esquive », en precisant que l'ordre suivait celui de DOL. Il ne le suivait
## pas. `GameLiving.CalculateEnemyAttackResult` teste les DEFENSES D'ABORD, a la
## ligne 3444, et le taux de rate seulement a la ligne 3600 ; et leur ordre
## interne est ESQUIVE, PARADE, BLOCAGE — l'inverse de ce qui etait ecrit.
##
## La maladresse, elle, vient APRES la rate (GameLiving.cs:3676), pas avant.
##
## L'ordre est donc : esquive, parade (melee seulement), blocage, rate,
## maladresse. Il compte : une defense qui se declenche n'est pas une rate, et
## les styles reagissent differemment aux deux.

const BASIS: String = "PLACEHOLDER"
const BASIS_DOL_CODE: String = "DOL_CODE"

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")

const FUMBLE_PERCENT: float = 1.0
const BASE_MISS_PERCENT: float = 18.0
const MISS_PER_LEVEL_PERCENT: float = 1.5
const MISS_MIN_PERCENT: float = 5.0
const MISS_MAX_PERCENT: float = 60.0


## Tirage deterministe 0..100. Le serveur local avance sa graine a chaque coup,
## donc une meme session rejouee donne exactement les memes resultats.
static func roll_percent(seed_value: int, salt: int) -> float:
	var mixed: int = seed_value * 1103515245 + salt * 12345 + 1013904223
	return float(absi(mixed) % 10000) * 0.01


static func miss_percent(attacker: DaocCombatEntityState, target: DaocCombatEntityState, use_dol_formulas: bool = true) -> float:
	if attacker == null or target == null:
		return BASE_MISS_PERCENT
	if use_dol_formulas:
		return clampf(dol_miss_percent_raw(attacker, target), 0.0, 100.0)
	var level_gap: float = float(target.level - attacker.level)
	var pct: float = BASE_MISS_PERCENT + level_gap * MISS_PER_LEVEL_PERCENT
	return clampf(pct, MISS_MIN_PERCENT, MISS_MAX_PERCENT)


## Le taux BRUT de DOL, sans bornes. Rendu a part pour que la suite puisse
## montrer les cas ou DOL sort de [0, 100] au lieu de les cacher.
static func dol_miss_percent_raw(attacker: DaocCombatEntityState, target: DaocCombatEntityState) -> float:
	if attacker == null or target == null:
		return BASE_MISS_PERCENT
	return DolFormulas.miss_rate_percent(
		attacker.level, target.level, attacker.is_player, target.is_player
	)


## Les trois defenses actives, en POURCENTS, portees de DOL.
##
## CE QUI LES REND ENFIN NON NULLES : P1-24 a mis un bouclier dans la main du
## joueur. `BlockChanceCalculator` part de 50 millièmes — 5 % — pour n'importe
## quel joueur, plus sa dexterite ; il ne manquait que le bouclier.
##
## LA PARADE ET L'ESQUIVE RESTENT A ZERO, et ce n'est PAS un oubli : DOL les
## garde derriere `HasSpecialization(Parry)` et `HasAbility(Evade)`. Aucune
## source du disque ne dit ce que Heyveno a appris — `classxspecialization`
## existe mais ne donne pas le NIVEAU appris d'un personnage. Les inventer
## serait exactement ce que ce projet s'interdit.
static func defense_percents(
	attacker: DaocCombatEntityState,
	target: DaocCombatEntityState,
	options: Dictionary
) -> Dictionary:
	var out := {"block": 0.0, "parry": 0.0, "evade": 0.0, "basis": BASIS}
	if attacker == null or target == null:
		return out

	# L'ECART DE CON EST CELUI VU PAR LE DEFENSEUR : `-GetConLevel(attaquant)`,
	# donc positif quand l'attaquant lui est inferieur. L'inverser rendrait les
	# defenses meilleures contre plus fort que soi.
	var attacker_con_level: float = -DolFormulas.con_level(target.level, attacker.level)
	var attacker_count: int = maxi(1, int(options.get("attacker_count", target.attacker_melee_count)))
	var pvp: bool = attacker.is_player and target.is_player

	if target.is_player:
		var dexterity: int = int(target.get_modified("Dexterity", 60.0))
		var shield: Dictionary = options.get("target_shield", {}) as Dictionary
		if not shield.is_empty():
			var raw_block: int = DolFormulas.player_block_chance_raw(
				dexterity, int(options.get("shield_spec_level", 1))
			)
			# `Type_Damage` D'UN BOUCLIER EST SA TAILLE, pas un type de degats.
			out["block"] = DolFormulas.block_chance(
				raw_block,
				int(shield.get("quality", 100)),
				int(shield.get("damage_type", 0)),
				attacker_con_level, attacker_count, attacker.is_player,
				bool(options.get("target_stunned_or_sitting", false))
			) * 100.0
			out["basis"] = BASIS_DOL_CODE
		var raw_parry: int = DolFormulas.player_parry_chance_raw(
			dexterity, bool(options.get("target_has_parry_spec", false))
		)
		if raw_parry > 0:
			out["parry"] = DolFormulas.parry_chance(raw_parry, attacker_con_level, attacker_count, pvp) * 100.0
		var raw_evade: int = DolFormulas.player_evade_chance_raw(
			int(target.get_modified("Quickness", 60.0)), dexterity,
			int(options.get("target_evade_ability_level", 0))
		)
		if raw_evade > 0:
			out["evade"] = DolFormulas.evade_chance(raw_evade, attacker_con_level, attacker_count, 0, false, pvp) * 100.0
	else:
		# UN PNJ N'A NI INVENTAIRE NI SPECIALISATION : DOL lit ses proprietes
		# `BlockChance`, `ParryChance` et `EvadeChance`, en dixiemes de pourcent,
		# et elles valent zero pour tous les PNJ de la capture.
		var npc_block: float = maxf(0.0, target.get_modified("BlockChance", 0.0))
		var npc_parry: float = maxf(0.0, target.get_modified("ParryChance", 0.0))
		var npc_evade: float = maxf(0.0, target.get_modified("EvadeChance", 0.0))
		if npc_block > 0.0:
			out["block"] = DolFormulas.block_chance(
				int(npc_block * 10.0), 100, 1, attacker_con_level, attacker_count, attacker.is_player
			) * 100.0
			out["basis"] = BASIS_DOL_CODE
		if npc_parry > 0.0:
			out["parry"] = DolFormulas.parry_chance(int(npc_parry * 10.0), attacker_con_level, attacker_count) * 100.0
		if npc_evade > 0.0:
			out["evade"] = DolFormulas.evade_chance(int(npc_evade * 10.0), attacker_con_level, attacker_count) * 100.0
	return out


## Conservee pour la contre-epreuve : la lecture nue d'une propriete, sans
## aucune formule. C'est ce que faisait P1-21A.
static func defense_percent(target: DaocCombatEntityState, property_name: String) -> float:
	if target == null:
		return 0.0
	return maxf(0.0, target.get_modified(property_name, 0.0))


## Resout un coup complet : defenses d'abord, degats ensuite.
static func resolve(
	attacker: DaocCombatEntityState,
	target: DaocCombatEntityState,
	weapon: Dictionary,
	options: Dictionary = {}
) -> DaocAttackData:
	var seed_value: int = int(options.get("seed", 0))
	var attack_type: String = str(options.get("attack_type", DaocCombatEnums.ATTACK_MELEE_ONE_HAND))

	var use_dol: bool = bool(options.get("use_dol_formulas", true))
	var miss_pct: float = miss_percent(attacker, target, use_dol)

	var block_pct: float = 0.0
	var parry_pct: float = 0.0
	var evade_pct: float = 0.0
	var defense_basis: String = BASIS
	if use_dol:
		var defenses: Dictionary = defense_percents(attacker, target, options)
		block_pct = float(defenses.get("block", 0.0))
		parry_pct = float(defenses.get("parry", 0.0))
		evade_pct = float(defenses.get("evade", 0.0))
		defense_basis = str(defenses.get("basis", BASIS))
	else:
		block_pct = defense_percent(target, "BlockChance")
		parry_pct = defense_percent(target, "ParryChance")
		evade_pct = defense_percent(target, "EvadeChance")

	# L'ORDRE DE DOL : esquive, parade, blocage, PUIS la rate, PUIS la maladresse.
	var melee: bool = DaocCombatEnums.is_melee_attack(attack_type)
	var outcome: String = ""
	if evade_pct > 0.0 and roll_percent(seed_value, 71) < evade_pct:
		outcome = DaocCombatEnums.RESULT_EVADED
	elif melee and parry_pct > 0.0 and roll_percent(seed_value, 53) < parry_pct:
		outcome = DaocCombatEnums.RESULT_PARRIED
	elif block_pct > 0.0 and roll_percent(seed_value, 37) < block_pct:
		outcome = DaocCombatEnums.RESULT_BLOCKED
	elif roll_percent(seed_value, 23) < miss_pct:
		outcome = DaocCombatEnums.RESULT_MISSED
	elif roll_percent(seed_value, 11) < FUMBLE_PERCENT:
		outcome = DaocCombatEnums.RESULT_FUMBLED

	if outcome != "":
		var missed: DaocAttackData = DaocAttackData.new()
		missed.attacker = attacker
		missed.target = target
		missed.attack_type = attack_type
		missed.attack_result = outcome
		missed.damage = 0
		missed.critical_damage = 0
		missed.damage_type = DaocCombatEnums.canonical_damage_type(weapon.get("damage_type", DaocCombatEnums.DAMAGE_NATURAL))
		missed.interval = int(options.get("interval", 0))
		missed.miss_chance = miss_pct
		missed.block_chance = block_pct
		missed.parry_chance = parry_pct
		missed.evade_chance = evade_pct
		missed.notes.append({
			"source": "DaocMeleeExchange",
			"miss_basis": BASIS_DOL_CODE if use_dol else BASIS,
			"defense_basis": defense_basis,
			"prediction_only": true,
		})
		return missed

	var component: DaocAttackComponent = DaocAttackComponent.new()
	var ad: DaocAttackData = component.make_attack(attacker, target, weapon, options.get("style", null) as DaocStyleDef, options)
	ad.miss_chance = miss_pct
	ad.block_chance = block_pct
	ad.parry_chance = parry_pct
	ad.evade_chance = evade_pct
	ad.notes.append({
		"source": "DaocMeleeExchange",
		"miss_basis": BASIS_DOL_CODE if use_dol else BASIS,
		"defense_basis": defense_basis,
		"prediction_only": true,
	})
	return ad


## Intervalle entre deux coups, en millisecondes.
##
## P1-23B — LA VITESSE D'UN PNJ NE DEPEND PAS DE SON ARME dans DOL :
## `GameLiving.AttackSpeed` part de 3000 ms corriges par la seule vivacite. Le
## chemin de P1-18B, lui, lisait le `SPD_ABS` de l'arme pour tout le monde. Les
## deux plafonds different aussi — 500 ms pour un vivant, 1500 pour un joueur.
static func swing_interval_msec(owner: DaocCombatEntityState, weapon: Dictionary, use_dol_formulas: bool = true) -> int:
	if use_dol_formulas and owner != null:
		var quickness: int = int(owner.get_modified("Quickness", 60.0))
		if owner.is_player and weapon.has("SPD_ABS"):
			return DolFormulas.player_attack_speed_msec(float(weapon["SPD_ABS"]), quickness)
		return DolFormulas.npc_attack_speed_msec(quickness)
	var component: DaocAttackComponent = DaocAttackComponent.new()
	var interval: int = component.attack_speed(owner, weapon)
	if interval <= 0:
		return 2500
	return interval
