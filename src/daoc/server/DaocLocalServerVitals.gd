extends RefCounted
class_name DaocLocalServerVitals

## P1-21A — construction de l'etat vital d'une entite pour le serveur local.
##
## Regle de ce fichier : chaque champ porte sa PROVENANCE. Ce qui vient de la
## capture serveur est marque CAPTURE ; ce qui est invente pour que la boucle
## tourne est marque PLACEHOLDER et doit rester remplacable en un seul endroit.
##
## Rien ici ne pretend etre la formule de Mythic ni celle d'OpenDAoC.
##
## P1-23 — CE PARAGRAPHE A CHANGE, ET C'EST LE JALON. Il disait « les sources
## serveur ne sont pas sur le disque ». Elles y sont : l'arbre `DOLSharp-master`,
## a cote du projet, resolu par `DaocDolSourceRoot`. La vie maximale, les degats,
## la vitesse d'attaque et l'absorption ne sont donc plus inventees — elles sont
## PORTEES, avec leur citation, dans `DaocDolFormulas`.
##
## Ce qui reste PLACEHOLDER est nomme et court : l'arme d'un PNJ, faute de
## `npcequipment.sql` indexe, et celle du joueur, faute de son equipement reel.

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")
const StarterEquipmentScript = preload("res://src/daoc/gameplay/items/DaocStarterEquipmentIndex.gd")
const RaceIndexScript = preload("res://src/daoc/gameplay/items/DaocRaceIndex.gd")
const ClassTableScript = preload("res://src/daoc/gameplay/items/DaocDolClassTable.gd")

const BASIS_CAPTURE: String = "CAPTURE"
const BASIS_PLACEHOLDER: String = "PLACEHOLDER"
const BASIS_INSPECTOR: String = "INSPECTOR"
## P1-23 — CINQUIEME PROVENANCE : la valeur est portee du CODE de DOL, avec le
## chemin et la ligne de sa source. Un cran au-dessus de PLACEHOLDER, un cran en
## dessous d'une mesure contre un vrai serveur. Voir `DaocDolFormulas`.
const BASIS_DOL_CODE: String = "DOL_CODE"
## P1-22A/P1-22B — la valeur vient des dumps OpenDAoC, par l'index pre-cuit.
##
## QUATRIEME PROVENANCE, et volontairement UNE SEULE. La force du rapprochement
## — meme spawn, meme modele et niveau, meme modele seulement — n'est PAS ici :
## elle vit dans `mob_db_profile(object_id).basis`, ou elle est lisible entite
## par entite. Ce champ-ci repond a une question plus simple et plus utile a un
## comptage : « ce chiffre a-t-il ete invente ? » Non.
##
## Elle N'EST PAS une promotion des PLACEHOLDER : la vie maximale, les degats
## d'arme et sa vitesse restent inventes, faute de formule dans les tables.
const BASIS_MOB_DB: String = "MOB_DB"
## P1-24 — l'objet vient de `starterequipment` + `itemtemplate`, par le METIER.
##
## SIXIEME PROVENANCE, et elle est plus faible que `CAPTURE` a dessein : ce
## n'est PAS l'equipement de ce personnage-la, c'est celui que son metier
## recoit au depart. La capture porte des MODELES d'objets, pas leurs
## identifiants — le rapprochement dans l'autre sens est impossible.
const BASIS_DUMP_STARTER: String = "DUMP_STARTER"
## P1-26 — la valeur vient de `race.sql`, par la race declaree.
##
## SEPTIEME PROVENANCE. Elle est FORTE : contrairement a l equipement, la race
## n est pas empruntee a un metier — c est la colonne `Race` de ce spawn-la
## pour un PNJ, et la race du personnage pour le joueur.
const BASIS_DUMP_RACE: String = "DUMP_RACE"

## Formule de vie maximale de P1-21A, PLACEHOLDER assume.
##
## CONSERVEE EXPRES, ET PLUS APPELEE PAR DEFAUT. Elle sert de CONTRE-EPREUVE :
## `DaocLocalServer.use_dol_formulas` decoche y retombe, et la suite P1-23 verifie
## que les deux chemins donnent bien des chiffres DIFFERENTS. Un jalon qui
## remplace une formule doit pouvoir montrer ce qu'il a remplace.
##
## Forme retenue a l'epoque : quadratique douce, calee pour qu'un rat niveau 1
## tombe en quelques coups (~23 PV). Elle n'etait tiree d'aucune source.
static func placeholder_max_health(level: int) -> int:
	var lvl: int = maxi(0, level)
	return maxi(1, 10 + lvl * 12 + lvl * lvl)


## P1-23 — LA VRAIE REGLE. `MaxHealthCalculator`, branche `GameNPC`.
##
## Le TODO de P1-21A disait : « remplacer par la vraie regle OpenDAoC
## (`GameNPC.MaxHealth`, Constitution issue de `mob.sql`) ». Les deux moities y
## sont enfin — la constitution vient de l'index P1-22A, la formule du code DOL.
##
## `constitution` a -1 vaut « inconnue » : on retombe sur la constitution de base
## d'un PNJ declaree par DOL (30), et non sur une valeur inventee.
static func dol_max_health(level: int, constitution: int = -1) -> int:
	var con: int = constitution if constitution > 0 else DolFormulas.GAMENPC_BASE_CON
	return DolFormulas.npc_max_health(level, con)


## LA FIXTURE CANONIQUE, et rien d'autre. Heyveno est une Briton Female Armsman.
##
## Ces deux valeurs ne sont PAS un reglage : le `BaseHP` vient de la table des
## metiers extraite par `tools/p1_23_extract_dol_tables.gd` (Armsman = 880), et
## la constitution de depart vient de `DaocDolFormulas.RACE_STARTING_STATS`
## (Briton = 60). Un autre personnage aurait d'autres chiffres — le jour ou la
## creation de personnage existera, ce sont ces deux champs qu'elle remplira.
##
## L'ARMSMAN N'A PAS DE MANA, et c'est une regle et non un oubli : sa
## `ManaStat` est indeclaree dans `CharacterClassDB.cs`. `player_max_mana` rend
## donc zero, et une jauge de mana vide chez un guerrier est CORRECTE.
const FIXTURE_CLASS_NAME: String = "Armsman"
## `eCharacterClass.Armsman` — GameServer/GlobalConstants.cs:889.
const FIXTURE_CLASS_ID: int = 2
const FIXTURE_CLASS_BASE_HP: int = 880
const FIXTURE_CLASS_HAS_MANA_STAT: bool = false
const FIXTURE_RACE_NAME: String = "Briton"


## Stats de combat par defaut, PLACEHOLDER assume.
##
## `mob.sql` porte les vraies valeurs Strength/Constitution/Dexterity/Quickness
## de chaque mob, et l'index P1-22A les resout desormais pour 173 des 188 PNJ de
## la capture. Cette forme ne sert plus que de repli pour les 15 restants.
static func placeholder_stats(level: int) -> Dictionary:
	var lvl: float = float(maxi(1, level))
	return {
		"Strength": 40.0 + lvl * 1.5,
		"Constitution": 40.0 + lvl * 1.5,
		"Dexterity": 40.0 + lvl * 1.0,
		"Quickness": 40.0 + lvl * 1.0,
	}


## Arme par defaut d'un PNJ, PLACEHOLDER assume.
## TODO P1-21B : resoudre via `npcequipment.sql` / `itemtemplate.sql`.
static func placeholder_npc_weapon(level: int) -> Dictionary:
	var lvl: float = float(maxi(1, level))
	return {
		"name": "arme naturelle",
		"dps": 1.2 + lvl * 0.3,
		"speed": 30.0,
		"damage_type": DaocCombatEnums.DAMAGE_CRUSH,
		"basis": BASIS_PLACEHOLDER,
	}


## P1-24 — l'arme de depart du METIER, lue dans l'index pre-cuit.
##
## Le TODO de P1-21A disait : « resoudre via l'equipement capture +
## `itemtemplate.sql` ». La seconde moitie y est ; la premiere ne le sera jamais,
## et c'est mesure et non suppose : la capture porte des MODELES d'objets, pas
## leurs `Id_nb`. On resout donc par le metier, et on le declare.
##
## LES CHAMPS SONT NOMMES A LA MANIERE DE DOL — `DPS_AF`, `SPD_ABS`, `Hand` —
## et ce n'est pas cosmetique : c'est ce qui fait basculer
## `DaocAttackComponent.make_attack_dol` sur la branche `GamePlayer`, celle qui
## lit vraiment une arme. Sans ces noms, la branche generique sert.
##
## Rend un dictionnaire VIDE quand l'index manque : l'appelant retombe alors sur
## le PLACEHOLDER de P1-21A, et le dit.
static func dol_player_weapon(class_id: int, index: RefCounted = null) -> Dictionary:
	var source: RefCounted = index
	if source == null:
		source = StarterEquipmentScript.new()
		if not source.load_index():
			return {}
	var item: Dictionary = source.melee_weapon_for_class(class_id)
	if item.is_empty():
		return {}
	return weapon_from_item(item)


## P1-93 — un objet de l'index (ou du sac) devient l'arme que la chaine de
## degats lit. Meme dictionnaire qu'avant : seul le point d'entree change,
## l'inventaire du joueur en a besoin pour n'importe quel objet equipe.
static func weapon_from_item(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	return {
		"name": str(item.get("name", "arme")),
		"id_nb": str(item.get("id_nb", "")),
		# LE NIVEAU DE L'OBJET, et il sert : c'est lui qui decide si cet
		# equipement est encore plausible pour son porteur. Voir
		# `starter_gear_is_grey`.
		"item_level": int(item.get("level", 0)),
		"DPS_AF": int(item.get("dps_af", 0)),
		"SPD_ABS": float(item.get("spd_abs", 25)),
		"Hand": int(item.get("hand", 0)),
		"Quality": int(item.get("quality", 100)),
		"Condition": int(item.get("condition", 100)),
		"MaxCondition": int(item.get("max_condition", 100)),
		"object_type": int(item.get("object_type", 0)),
		# Le type de degats d'`itemtemplate` est un ENTIER ; le vocabulaire local
		# est textuel. La conversion vit dans `DaocCombatEnums`, pas ici.
		"damage_type": int(item.get("damage_type", 0)),
		"basis": BASIS_DUMP_STARTER,
	}


## L'equipement de depart est-il devenu GRIS pour ce personnage ?
##
## `GameObject.GetConLevel` rend l'ecart en crans de couleur ; `<= -3` est le
## gris, le meme seuil que `IsObjectGreyCon` et que le clamp de
## `GameInventoryItem`. Un objet gris ne dit plus rien de ce que porte le
## personnage : la base est muette au-dela, et l'inventer serait pire que de
## l'avouer.
static func starter_gear_is_grey(player_level: int, kit_level: int) -> bool:
	return DolFormulas.con_level(maxi(1, player_level), maxi(1, kit_level)) <= -3.0


## Arme par defaut du joueur, PLACEHOLDER assume. Conservee pour la
## contre-epreuve, pour le cas ou l'index P1-24 manque, et pour tout personnage
## dont l'equipement de depart est devenu gris.
static func placeholder_player_weapon(level: int) -> Dictionary:
	var lvl: float = float(maxi(1, level))
	return {
		"name": "epee de depart",
		"dps": 1.2 + lvl * 0.3,
		"speed": 29.0,
		"damage_type": DaocCombatEnums.DAMAGE_SLASH,
		"basis": BASIS_PLACEHOLDER,
	}


## Construit l'etat d'un PNJ a partir d'une entite de la capture P1-20E.
##
## La capture fournit reellement `name`, `level`, `health_percent`, `realm` et
## les `flags`. Tout le reste est declare PLACEHOLDER.
static func npc_state_from_capture(entity: Dictionary, use_dol_formulas: bool = true) -> Dictionary:
	var object_id: int = int(entity.get("object_id", -1))
	var level: int = int(entity.get("level", 0))
	# LA CONSTITUTION N'EST PAS ENCORE CONNUE ICI : elle arrive avec l'index
	# P1-22A, plus tard, dans `_apply_mob_db_profile`. La vie maximale y est donc
	# RECALCULEE. Ce premier jet emploie la constitution de base d'un PNJ, celle
	# que DOL declare par defaut — et c'est ce que voit un PNJ non resolu.
	var max_health: int = dol_max_health(level) if use_dol_formulas else placeholder_max_health(level)

	# `health_percent` est la vraie valeur observee sur le serveur au moment de
	# la capture. On la respecte : un mob deja blesse le reste.
	var health_percent: float = 100.0
	var health_basis: String = BASIS_PLACEHOLDER
	if entity.has("health_percent"):
		health_percent = clampf(float(entity.get("health_percent", 100.0)), 0.0, 100.0)
		health_basis = BASIS_CAPTURE
	var health: int = clampi(int(round(float(max_health) * health_percent * 0.01)), 0, max_health)
	if health <= 0 and health_percent > 0.0:
		health = 1

	var flags: Dictionary = entity.get("flags", {}) as Dictionary
	var state: DaocCombatEntityState = DaocCombatEntityState.new()
	state.entity_id = object_id
	state.name = str(entity.get("name", "Entite %d" % object_id))
	state.level = level
	state.max_health = max_health
	state.health = health
	state.is_player = false
	state.is_alive = health > 0
	state.stats = placeholder_stats(level)

	var basis: Dictionary = {
		"name": BASIS_CAPTURE,
		"level": BASIS_CAPTURE,
		"realm": BASIS_CAPTURE,
		"flags": BASIS_CAPTURE,
		"health_percent": health_basis,
		"max_health": BASIS_DOL_CODE if use_dol_formulas else BASIS_PLACEHOLDER,
		"stats": BASIS_PLACEHOLDER,
		"weapon": BASIS_PLACEHOLDER,
		"resists": BASIS_PLACEHOLDER,
	}

	return {
		"state": state,
		"basis": basis,
		"weapon": placeholder_npc_weapon(level),
		"realm": int(entity.get("realm", 0)),
		"entity_type": str(entity.get("entity_type", "")),
		"model_id": int(entity.get("model_id", -1)),
		"attackable": is_attackable(entity),
		"world_position": Vector3(
			float(entity.get("x", 0.0)),
			float(entity.get("y", 0.0)),
			float(entity.get("z", 0.0))
		),
		"flags": flags.duplicate(true),
	}


## Construit l'etat du joueur.
##
## La capture ne porte PAS le niveau de Heyveno : son entree fixture annonce
## `level = 0`. Le niveau vient donc de l'inspecteur, et c'est declare.
static func player_state_from_capture(entity: Dictionary, level_override: int, use_dol_formulas: bool = true) -> Dictionary:
	var object_id: int = int(entity.get("object_id", -1))
	var captured_level: int = int(entity.get("level", 0))
	var level: int = captured_level if captured_level > 0 else maxi(1, level_override)
	var level_basis: String = BASIS_CAPTURE if captured_level > 0 else BASIS_INSPECTOR

	var stats: Dictionary = placeholder_stats(level)
	# P1-23 — LA VIE D'UN JOUEUR N'EST PAS CELLE D'UN PNJ. `GamePlayer` a sa
	# propre formule et elle depend du `BaseHP` du METIER : 880 pour un Armsman,
	# 560 pour un Wizard. Employer la formule des PNJ pour le joueur aurait ete
	# une invention silencieuse — deux courbes tres differentes.
	var max_health: int = placeholder_max_health(level)
	var mana: int = 0 if not FIXTURE_CLASS_HAS_MANA_STAT else 100
	var endurance: int = 100
	var max_mana: int = 0 if not FIXTURE_CLASS_HAS_MANA_STAT else 100
	var max_endurance: int = 100
	var health_basis: String = BASIS_PLACEHOLDER
	var pools_basis: String = BASIS_PLACEHOLDER
	if use_dol_formulas:
		var race_stats: Dictionary = DolFormulas.race_starting_stats(FIXTURE_RACE_NAME)
		var constitution: int = int(race_stats.get("CON", 60))
		var acuity: int = int(race_stats.get("PIE", 60))
		stats["Constitution"] = float(constitution)
		max_health = DolFormulas.player_max_health(level, constitution, FIXTURE_CLASS_BASE_HP)
		max_mana = DolFormulas.player_max_mana(level, acuity, FIXTURE_CLASS_HAS_MANA_STAT)
		max_endurance = DolFormulas.player_max_endurance()
		mana = max_mana
		endurance = max_endurance
		health_basis = BASIS_DOL_CODE
		pools_basis = BASIS_DOL_CODE

	# P1-24 — L'ARME ET L'ARMURE DU METIER, MAIS SEULEMENT TANT QU'ELLES SONT
	# PLAUSIBLES, et la borne est une regle de DOL, pas un seuil invente.
	#
	# MESURE QUI A IMPOSE CETTE BORNE : `starterequipment` donne du materiel de
	# niveau 2. Equipe sur un niveau 60, l'epee d'entrainement rend NEUF degats
	# par coup contre une cible de 2004 points de vie — 99 points en cinq
	# minutes, et la cible regenere plus vite. Le combat devient INGAGNABLE. Ce
	# n'est pas un defaut de la formule : c'est ce que vaut vraiment une epee
	# d'entrainement dans les mains d'un niveau 60. Le modele est faux, pas DOL.
	#
	# LA BORNE EST LE GRIS. DOL borne a `-3` cons l'interet d'un objet pour son
	# porteur (`GameInventoryItem`, con clampe a -3,0), et `-3` est exactement le
	# seuil du gris ailleurs. Au-dela, la base ne dit RIEN de ce que porte ce
	# personnage : on ne le devine pas, on retombe sur la branche generique de
	# `GameLiving` — celle qui suit le niveau — et la provenance le dit.
	var weapon: Dictionary = placeholder_player_weapon(level)
	var armor: Dictionary = {}
	var shield: Dictionary = {}
	if use_dol_formulas:
		var equipment: RefCounted = StarterEquipmentScript.new()
		if equipment.load_index():
			var dol_weapon: Dictionary = dol_player_weapon(FIXTURE_CLASS_ID, equipment)
			var kit_level: int = equipment.kit_level(FIXTURE_CLASS_ID)
			if not dol_weapon.is_empty() and not starter_gear_is_grey(level, kit_level):
				weapon = dol_weapon
				armor = equipment.armor_by_slot(FIXTURE_CLASS_ID)
				# P1-25 — LE BOUCLIER EST CE QUI REND LE BLOCAGE POSSIBLE.
				shield = equipment.shield_for_class(FIXTURE_CLASS_ID)

	# P1-26 — LES RESISTANCES RACIALES. `melee_damage` les applique deja depuis
	# P1-23B : les laisser a zero n etait pas une absence, c etait un chiffre.
	var resists: Dictionary = {}
	# P1-27 — LES SPECIALISATIONS AUTO-ENTRAINEES. Elles montent SEULES jusqu a
	# `niveau / 4` : c est une regle du metier, pas un choix de build, donc la
	# seule part de la progression d un personnage qui soit derivable ici.
	var spec_levels: Dictionary = {}
	if use_dol_formulas:
		var races: RefCounted = RaceIndexScript.new()
		if races.load_index():
			resists = races.resists_for_name(FIXTURE_RACE_NAME)
		var classes: RefCounted = ClassTableScript.new()
		if classes.load_index():
			spec_levels = classes.auto_trained_spec_levels(FIXTURE_CLASS_ID, level)

	var state: DaocCombatEntityState = DaocCombatEntityState.new()
	state.entity_id = object_id
	state.name = str(entity.get("name", "Joueur"))
	state.level = level
	state.max_health = max_health
	state.health = max_health
	state.mana = mana
	state.endurance = endurance
	state.max_mana = max_mana
	state.max_endurance = max_endurance
	state.is_player = true
	state.character_class_id = FIXTURE_CLASS_ID
	state.is_alive = true
	state.stats = stats
	state.resists = resists
	state.spec_levels = spec_levels

	return {
		"state": state,
		# LES DEUX JAUGES QUI N'AVAIENT PAS D'ECHELLE. `mana` et `endurance`
		# etaient publies en ABSOLU sans maximum, donc comptes dans
		# `unpublished_for_lack_of_scale` par le pont d'interface P1-21E : une
		# barre ne peut rien afficher sans son plafond. Il est la.
		"max_mana": max_mana,
		"max_endurance": max_endurance,
		"basis": {
			"name": BASIS_CAPTURE,
			"level": level_basis,
			"max_health": health_basis,
			"max_mana": pools_basis,
			"max_endurance": pools_basis,
			"stats": BASIS_PLACEHOLDER,
			"weapon": str(weapon.get("basis", BASIS_PLACEHOLDER)),
			"armor": BASIS_DUMP_STARTER if not armor.is_empty() else BASIS_PLACEHOLDER,
			"resists": BASIS_DUMP_RACE if not resists.is_empty() else BASIS_PLACEHOLDER,
			# L auto-entrainement est une REGLE du code, pas une donnee de dump :
			# sa provenance est donc DOL_CODE et non DUMP_STARTER.
			"spec_levels": BASIS_DOL_CODE if not spec_levels.is_empty() else BASIS_PLACEHOLDER,
		},
		"weapon": weapon,
		"armor": armor,
		"shield": shield,
		"realm": int(entity.get("realm", 0)),
		"entity_type": "player",
		"model_id": int(entity.get("model_id", -1)),
		# Le joueur EST une cible valide : sans cela un PNJ ne pourrait pas
		# riposter. Ne pas confondre avec « le joueur peut se cibler lui-meme »,
		# qui se regle par exclusion explicite au moment du ciblage.
		"attackable": true,
		"world_position": Vector3(
			float(entity.get("x", 0.0)),
			float(entity.get("y", 0.0)),
			float(entity.get("z", 0.0))
		),
		"flags": (entity.get("flags", {}) as Dictionary).duplicate(true),
	}


## Une entite peut-elle etre prise pour cible et frappee ?
##
## Les drapeaux viennent de la capture : le serveur les a reellement envoyes.
## Les objets du decor et les entites `cannot_target` sont exclus sans discussion.
static func is_attackable(entity: Dictionary) -> bool:
	if str(entity.get("entity_type", "")) != "npc":
		return false
	var flags: Dictionary = entity.get("flags", {}) as Dictionary
	if bool(flags.get("cannot_target", false)):
		return false
	if bool(flags.get("ghost", false)):
		return false
	if bool(flags.get("peaceful", false)):
		return false
	return true
