extends Node
class_name DaocLocalServer

## P1-21A — l'arbitre local.
##
## Ce noeud occupe LA PLACE DU SERVEUR, pas celle du client. Il detient les
## points de vie, decide si un coup touche, applique les degats et declare la
## mort. Le client ne connait aucune de ces regles : il envoie des intentions
## (`request_attack`) et recoit des evenements (`combat_event`, `entity_died`).
##
## C'est le meme decoupage que `DaocEnvironmentController` devant Sky3D et que
## `DaocNearbyWorldEntitySource` devant le monde : l'autorite est separee du
## rendu, donc remplacable. Le jour ou un vrai OpenDAoC est joignable, on
## debranche ce noeud et le reste du projet ne bouge pas.
##
## Ce qu'il n'est PAS :
##   - il ne fait aucun reseau, jamais ;
##   - il ne remplace pas le lab P1-18B : il l'utilise ;
##   - il ne connait pas le RELIEF. Il decide des positions en X et Y ; le `z`
##     reste au client, seul a savoir echantillonner le sol.
##
## CE QU'IL FAIT DEPUIS P1-22, et qui a change la nature de ce fichier. Il ne
## tranchait qu'un echange de coups ; il tient maintenant la boucle de jeu :
##
##   P1-22A  les PNJ ont les statistiques, l'aggro et le butin de `mob.sql`
##   P1-22B  la mort donne de l'experience, laisse un cadavre, puis on revient
##   P1-22C  le cadavre porte de l'argent et les objets de `loottemplate`
##   P1-22D  les creatures agressives reperent, poursuivent, et rentrent chez
##           elles — la ligne « il ne deplace personne » de P1-21A n'est plus
##           vraie, et c'est le seul endroit ou elle etait ecrite.
##
## Toutes les valeurs numeriques non issues de la capture ni des dumps sont
## declarees PLACEHOLDER dans `DaocLocalServerVitals`, `DaocExperienceRules` et
## `DaocLootRules`, et remontent dans `report()`.

const VitalsScript = preload("res://src/daoc/server/DaocLocalServerVitals.gd")
const PlayerInventoryScript = preload("res://src/daoc/server/DaocPlayerInventory.gd")
const MobDbIndexScript = preload("res://src/daoc/gameplay/mobdb/DaocMobDbIndex.gd")
const FactionIndexScript = preload("res://src/daoc/gameplay/factions/DaocFactionIndex.gd")
const FactionRulesScript = preload("res://src/daoc/gameplay/rules/DaocFactionRules.gd")
const ExperienceRules = preload("res://src/daoc/gameplay/progression/DaocExperienceRules.gd")
const LootRules = preload("res://src/daoc/gameplay/progression/DaocLootRules.gd")
const LootIndexScript = preload("res://src/daoc/gameplay/mobdb/DaocLootIndex.gd")
const NpcBrain = preload("res://src/daoc/gameplay/ai/DaocNpcBrain.gd")
const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")
const RaceIndexScript = preload("res://src/daoc/gameplay/items/DaocRaceIndex.gd")
const StyleIndexScript = preload("res://src/daoc/gameplay/items/DaocStyleIndex.gd")
const StyleProcessorScript = preload("res://src/daoc/gameplay/melee/DaocStyleProcessor.gd")
const SpellCatalogueScript = preload("res://src/daoc/gameplay/spells/DaocSpellCatalogue.gd")
const SpellLoadoutScript = preload("res://src/daoc/gameplay/spells/DaocPlayerSpellLoadout.gd")
const SpellLinesScript = preload("res://src/daoc/gameplay/spells/DaocPlayerSpellLines.gd")
const SpellRegistryScript = preload("res://src/daoc/gameplay/DaocGameplayMechanicsRegistry.gd")
const ClassTableScript = preload("res://src/daoc/gameplay/items/DaocDolClassTable.gd")
const MasterLevelStateScript = preload("res://src/daoc/gameplay/progression/DaocPlayerMasterLevelState.gd")
const ChampionLevelStateScript = preload("res://src/daoc/gameplay/progression/DaocPlayerChampionLevelState.gd")
const ItemConditionRules = preload("res://src/daoc/gameplay/rules/DaocItemConditionRules.gd")

const AUTHORITY: String = "local_server"
const CHECKPOINT: String = "P1_21A_LOCAL_SERVER"

signal state_changed(object_id: int, snapshot: Dictionary)
## P1-93 — le sac ou l'equipement du joueur a change ; l'instantane est celui de
## DaocPlayerInventory.snapshot().
signal player_inventory_changed(snapshot: Dictionary)
signal entity_died(object_id: int, snapshot: Dictionary)
signal combat_event(event: Dictionary)
## R3 — une disparition du flux n'est pas une mort de combat. Les clients qui
## suivent cette entite doivent pourtant pouvoir effacer leur cible.
signal entity_removed(object_id: int, snapshot: Dictionary, reason: String)
## P1-22B — la mort DONNE quelque chose. Le tueur gagne de l'experience, et si
## un seuil est franchi il monte de niveau. Deux signaux et non un : un gain est
## frequent et discret, une montee est rare et bruyante.
signal experience_gained(object_id: int, report: Dictionary)
signal level_gained(object_id: int, level: int, report: Dictionary)
## P1-22B — le cadavre disparait, puis la creature revient a son point
## d'apparition. Deux moments distincts, deux signaux : le client efface un
## corps a `corpse_decayed` et rallume une scene a `entity_respawned`.
signal corpse_decayed(object_id: int, snapshot: Dictionary)
signal entity_respawned(object_id: int, snapshot: Dictionary)
## P1-22C — le butin. `corpse_loot_ready` annonce ce qu'un corps CONTIENT ;
## `loot_taken` annonce ce qui en SORT. Les deux existent parce qu'un cadavre
## peut etre ouvert plusieurs fois, et qu'un client doit pouvoir afficher le
## contenu sans le prendre.
signal corpse_loot_ready(object_id: int, loot: Dictionary)
signal loot_taken(object_id: int, taker_id: int, loot: Dictionary)
## P1-22D — l'arbitre DEPLACE desormais les creatures. Le client ne devine pas
## ou elles sont : il ecoute. Coordonnees DAoC MONDE, comme partout ailleurs.
signal entity_moved(object_id: int, world_position: Vector3)
## P1-22D — changement d'humeur : repos, poursuite, combat, retour. Un client
## peut y accrocher une animation ou un cri sans connaitre la regle.
signal brain_state_changed(object_id: int, state: String, reason: String)

## Portee de melee, en unites DAoC brutes. DAoC compte environ 200 unites pour
## une portee d'arme au corps a corps.
var melee_range_raw: float = 200.0
## Les PNJ ripostent quand on les frappe, meme pacifiques. Depuis P1-22D, les
## AGRESSIFS n'attendent plus d'etre frappes : voir `npc_ai_enabled`.
var retaliation_enabled: bool = true
## Graine de depart des tirages. Une meme session rejouee redonne les memes coups.
var seed_base: int = 20260902
## Avance automatiquement a chaque frame. Les tests le mettent a false et
## appellent `advance()` a la main.
var auto_tick: bool = true
var log_events: bool = false

## P1-22B — l'index P1-22A alimente les statistiques, la portee d'aggro et le
## delai de reapparition. Decoche, l'arbitre retombe exactement sur les
## PLACEHOLDER de P1-21A : c'est le drapeau qui permet la contre-epreuve.
var mob_db_enabled: bool = true
## P1-23C — la vie, le mana et l'endurance remontent tout seuls.
##
## Trois horloges distinctes, chacune avec sa periode et son ralentissement en
## combat, portees de `GameLiving` : 3000 ms pour la vie et le mana, 1000 pour
## l'endurance ; en combat le tic de vie vaut CINQ fois sa periode et celui de
## mana 3,4 fois. Decoche, rien ne remonte — c'est l'etat d'avant P1-23C.
var regeneration_enabled: bool = true
## P1-23 — les formules du code DOL remplacent les PLACEHOLDER de P1-21A/B/C :
## vie maximale, mana, endurance, experience, argent, taux de rate.
##
## Decoche, l'arbitre retombe EXACTEMENT sur les formules inventees, et c'est
## tout l'interet du drapeau : une suite qui ne peut pas montrer la difference
## entre les deux chemins ne prouve pas que le nouveau est emprunte.
var use_dol_formulas: bool = true
## P1-22B — la mort rapporte de l'experience au tueur.
var experience_enabled: bool = true
## P1-22B — le cadavre s'efface, puis la creature revient.
var respawn_enabled: bool = true
## P1-22C — les morts laissent quelque chose.
var loot_enabled: bool = true
## P1-31 — les styles de melee peuvent enfin etre DECLENCHES. Decoche, l'arbitre
## retombe exactement sur P1-29 : le catalogue est charge, la formule est
## branchee, et rien ne les appelle.
var styles_enabled: bool = true
## P1-22D — les creatures agressives reperent, poursuivent et rentrent chez
## elles. Decoche, elles retombent exactement sur le comportement de P1-21A :
## immobiles, ripostant sur place.
var npc_ai_enabled: bool = true
## P1-22D — accepter l'hostilite d'un profil EMPRUNTE.
##
## DECOCHE PAR DEFAUT, et ce n'est pas de la prudence : coche, 103 des 188 PNJ
## de Gothwaite deviennent agressifs, marchands compris, parce qu'ils partagent
## un modele avec un monstre. Voir `_apply_mob_db_profile`.
##
## CONSEQUENCE ASSUMEE de le laisser decoche : la capture ne contient AUCUNE
## creature hostile confirmee — deux `SPAWN_MATCH` seulement, aucun agressif —
## donc l'IA de P1-22D ne se declenche jamais dans ce monde-la. Le mecanisme est
## prouve par sa suite, pas par la promenade. Ce drapeau existe pour le VOIR
## tourner en jeu, en sachant que l'hostilite affichee est alors empruntee.
var aggro_from_borrowed_profiles: bool = false
## P1-34 — l'hostilite de FACTION. Un mob dont `AggroLevel` vaut zero est quand
## meme agressif si sa faction l'est (StandardMobBrain.cs:279-287) : jusqu'ici le
## projet ne regardait que `AggroLevel`, donc un membre d'une faction hostile
## passait pour un marchand tranquille.
##
## LA FACTION NE S'EMPRUNTE PAS DAVANTAGE QUE L'AGGRO, et c'est la meme lecon
## qu'en P1-22D. Mesure sur la capture : 25 des 188 PNJ portent un `FactionID`,
## et **AUCUN** ne vient d'un `SPAWN_MATCH` — les 25 sont empruntes a un
## sosie. Elle est donc soumise au meme garde que l'aggro, et
## `aggro_from_borrowed_profiles` la libere en meme temps.
var factions_enabled: bool = true
## Duree d'un cadavre avant effacement, en secondes. PLACEHOLDER : le dump ne
## porte pas cette duree, elle vit dans le code serveur.
var corpse_decay_seconds: float = 30.0
## Delai de reapparition quand `mob.sql` en declare zero, en secondes.
## `RespawnInterval = 0` signifie « valeur par defaut du serveur », pas
## « instantane » — un zero pris au pied de la lettre ferait clignoter les mobs.
var default_respawn_seconds: float = 60.0
## 2026-09-15 — MODE MIROIR, pour le jeu en ligne. L'arbitre garde ses etats
## (noms, niveaux, positions, vie) pour que le ciblage et l'interface marchent,
## mais il n'ARBITRE plus rien : aucune attaque, aucun sort, aucun style,
## aucune IA, aucune regeneration, aucune mort locale. Le serveur reel decide ;
## ce noeud n'est plus qu'un reflet de ce qu'il a envoye. C'est le geste que
## P1-28 avait prepare : le client ne lit que snapshot(), la source change.
var mirror_mode: bool = false
## P1-110 - les objets du monde (0xD9) entrent dans le ciblage en ligne, pour
## ramasser un sac de butin ou prier sur sa pierre tombale. Hors ligne la
## capture porte 110 props : ils restent hors ciblage (false) pour ne pas
## changer P1-21A / P1-21H.
var world_objects_targetable: bool = false

var booted: bool = false
var player_object_id: int = -1
## P1-93 — l'inventaire du joueur. `starter_kit_auto_equip` = true porte la
## panoplie de depart des le demarrage (comportement P1-24, garde pour les
## suites de combat) ; false la met dans le SAC et laisse les logements vides.
var inventory_enabled: bool = true
var starter_kit_auto_equip: bool = true
var player_class_id: int = VitalsScript.FIXTURE_CLASS_ID
var _player_inventory: RefCounted = null

var _states: Dictionary = {}          # object_id -> DaocCombatEntityState
var _meta: Dictionary = {}            # object_id -> Dictionary (basis, weapon, flags, ...)
var _positions: Dictionary = {}       # object_id -> Vector3 (unites DAoC monde)
var _nodes: Dictionary = {}           # object_id -> Node3D
var _sessions: Dictionary = {}        # attacker_id -> Dictionary (cible, prochain coup)
var _spell_casts: Dictionary = {}     # caster_id -> incantation en cours
var _spell_cooldowns: Dictionary = {} # "caster_id:spell_id" -> disponible a
var _active_spell_effects: Array = [] # effets dont le temps appartient au serveur
var _clock_msec: float = 0.0
var _swing_counter: int = 0
var _boot_report: Dictionary = {}
var _event_log: Array = []
var _event_log_limit: int = 64
var _player_level_override: int = 1
var _stream_spawn_events: int = 0
var _stream_move_events: int = 0
var _stream_despawn_events: int = 0

# P1-22B
var _mob_db: RefCounted = null
var _mob_db_report: Dictionary = {}
var _factions: RefCounted = null
var _faction_report: Dictionary = {}
var _corpses: Dictionary = {}         # object_id -> { died_msec, decay_msec, respawn_msec, killer_id }
var _spawn_records: Dictionary = {}   # object_id -> { world_position, max_health, respawn_seconds }
var _experience: Dictionary = {}      # object_id -> { total, level }
var _deaths_resolved: int = 0
## P1-23C — prochaine echeance de chaque regeneration, par entite et par pool.
var _regen_next_msec: Dictionary = {}  # object_id -> { health, power, endurance }
## Compteur de tics, pour que la decimale tiree soit deterministe ET differente
## d'un tic a l'autre. Sans lui, un meme taux rendrait toujours le meme tirage.
var _regen_tick_counter: int = 0

# P1-31 — les styles
## Le catalogue P1-29, charge PARESSEUSEMENT : 1199 styles pour 152 Kio, et une
## session qui ne declenche jamais de style n'a aucune raison de les lire.
var _style_index: RefCounted = null
var _spell_catalogue: DaocSpellCatalogue = null
var _spell_registry: DaocGameplayMechanicsRegistry = null
var _style_processor: RefCounted = null
## Le style ARME, en attente du prochain coup. Une INTENTION, pas un etat : DAoC
## arme un style pour le swing suivant, il ne se met pas « en posture ».
var _pending_style: Dictionary = {}   # object_id -> DaocStyleDef
## Le dernier coup PORTE par chaque attaquant. `can_use_style` en a besoin :
## certains styles exigent que le coup precedent ait ete une parade, une esquive
## ou un blocage — c'est `AttackResultRequirement`.
var _last_attack: Dictionary = {}     # object_id -> DaocAttackData
var _styles_executed: int = 0
## P1-26 — l index des races, charge une seule fois par arbitre.
var _race_index: RefCounted = null
var _respawns_resolved: int = 0

# P1-22C
var _loot_index: RefCounted = null
var _loot_report: Dictionary = {}
var _purses: Dictionary = {}          # object_id -> cuivre detenu
var _loot_rolls: int = 0

# P1-22D
var _brains: Dictionary = {}          # object_id -> { state, target_id }
var _aggro_triggered: int = 0
var _leash_returns: int = 0


func _process(delta: float) -> void:
	if auto_tick and booted:
		advance(delta)


# --------------------------------------------------------------------------
# Amorcage
# --------------------------------------------------------------------------

## Construit l'etat de toutes les entites a partir de la capture P1-20E.
## `entities` est exactement la liste que consomme `DaocGothwaitePopulation` :
## les deux lisent la meme verite.
func boot(entities: Array, options: Dictionary = {}) -> Dictionary:
	shutdown()
	var player_level_override: int = int(options.get("player_level", 1))
	_player_level_override = player_level_override
	melee_range_raw = float(options.get("melee_range_raw", melee_range_raw))
	retaliation_enabled = bool(options.get("retaliation_enabled", retaliation_enabled))
	seed_base = int(options.get("seed_base", seed_base))
	mob_db_enabled = bool(options.get("mob_db_enabled", mob_db_enabled))
	experience_enabled = bool(options.get("experience_enabled", experience_enabled))
	respawn_enabled = bool(options.get("respawn_enabled", respawn_enabled))
	corpse_decay_seconds = float(options.get("corpse_decay_seconds", corpse_decay_seconds))
	default_respawn_seconds = float(options.get("default_respawn_seconds", default_respawn_seconds))
	loot_enabled = bool(options.get("loot_enabled", loot_enabled))
	inventory_enabled = bool(options.get("inventory_enabled", inventory_enabled))
	starter_kit_auto_equip = bool(options.get("starter_kit_auto_equip", starter_kit_auto_equip))
	player_class_id = int(options.get("player_class_id", player_class_id))
	npc_ai_enabled = bool(options.get("npc_ai_enabled", npc_ai_enabled))
	aggro_from_borrowed_profiles = bool(options.get("aggro_from_borrowed_profiles", aggro_from_borrowed_profiles))
	factions_enabled = bool(options.get("factions_enabled", factions_enabled))
	mirror_mode = bool(options.get("mirror_mode", mirror_mode))
	world_objects_targetable = bool(options.get("world_objects_targetable", world_objects_targetable))
	if mirror_mode:
		retaliation_enabled = false
		npc_ai_enabled = false
		regeneration_enabled = false
		experience_enabled = false
		respawn_enabled = false
		loot_enabled = false
	_load_mob_db()
	_load_faction_index()
	_load_loot_index()

	var npc_count: int = 0
	var attackable_count: int = 0
	var object_count: int = 0
	var skipped: int = 0
	var basis_counts: Dictionary = {}

	for value in entities:
		if not value is Dictionary:
			skipped += 1
			continue
		var entity: Dictionary = value as Dictionary
		var object_id: int = int(entity.get("object_id", -1))
		if object_id < 0 or _states.has(object_id):
			skipped += 1
			continue
		var entity_type: String = str(entity.get("entity_type", ""))
		var built: Dictionary = {}
		if entity_type == "player":
			built = VitalsScript.player_state_from_capture(entity, player_level_override, use_dol_formulas)
			player_object_id = object_id
			player_bind_position = Vector3(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)), float(entity.get("z", 0.0)))
			player_bind_region = int(entity.get("region_id", options.get("player_region", player_bind_region)))
		elif entity_type == "npc":
			built = VitalsScript.npc_state_from_capture(entity, use_dol_formulas)
			npc_count += 1
		else:
			# Decor : `objects.csv` le rend visible, mais il n'a pas de vie et ne
			# doit jamais devenir une cible. On ne lui invente pas d'etat.
			object_count += 1
			continue

		var state: DaocCombatEntityState = built.get("state") as DaocCombatEntityState
		if state == null:
			skipped += 1
			continue
		_states[object_id] = state
		_meta[object_id] = {
			"basis": built.get("basis", {}),
			"weapon": built.get("weapon", {}),
		"armor": built.get("armor", {}),
		"shield": built.get("shield", {}),
			"realm": int(built.get("realm", 0)),
			"entity_type": str(built.get("entity_type", entity_type)),
			"model_id": int(built.get("model_id", -1)),
			"attackable": bool(built.get("attackable", false)),
			"flags": built.get("flags", {}),
		}
		_positions[object_id] = built.get("world_position", Vector3.ZERO) as Vector3
		_apply_mob_db_profile(object_id, entity, state)
		if entity_type == "player":
			_install_player_inventory()
		_remember_spawn(object_id, state)
		if bool(built.get("attackable", false)):
			attackable_count += 1
		for key in (built.get("basis", {}) as Dictionary).keys():
			var basis_value: String = str((built.get("basis", {}) as Dictionary)[key])
			basis_counts[basis_value] = int(basis_counts.get(basis_value, 0)) + 1

	booted = not _states.is_empty()
	_boot_report = {
		"ok": booted,
		"checkpoint": CHECKPOINT,
		"authority": AUTHORITY,
		"network_access_performed": false,
		"entity_states": _states.size(),
		"npc_states": npc_count,
		"attackable": attackable_count,
		"world_objects_ignored": object_count,
		"skipped": skipped,
		"player_object_id": player_object_id,
		"melee_range_raw": melee_range_raw,
		"retaliation_enabled": retaliation_enabled,
		"basis_field_counts": basis_counts,
		"mob_db": _mob_db_report.duplicate(true),
		"factions": _faction_report.duplicate(true),
		"experience_enabled": experience_enabled,
		"respawn_enabled": respawn_enabled,
	}
	if player_object_id >= 0 and not _experience.has(player_object_id):
		var player_state: DaocCombatEntityState = _states.get(player_object_id) as DaocCombatEntityState
		var start_level: int = 1 if player_state == null else player_state.level
		_experience[player_object_id] = {
			"total": ExperienceRules.experience_for_level(start_level, use_dol_formulas),
			"level": start_level,
		}
	return _boot_report


# --------------------------------------------------------------------------
# P1-22B — la base des PNJ, l'apparition d'origine, l'experience
# --------------------------------------------------------------------------

## Ouvre l'index P1-22A. Son ABSENCE n'est pas une panne : l'arbitre retombe sur
## les PLACEHOLDER de P1-21A et le dit dans son rapport. C'est la difference
## entre un jeu degrade et un jeu casse.
func _load_mob_db() -> void:
	_mob_db = null
	_mob_db_report = {"enabled": mob_db_enabled, "loaded": false, "entries": 0, "applied": 0, "error": ""}
	if not mob_db_enabled:
		return
	var index: RefCounted = MobDbIndexScript.new()
	if not index.load_index():
		_mob_db_report["error"] = str(index.error)
		return
	_mob_db = index
	_mob_db_report["loaded"] = true
	_mob_db_report["entries"] = int(index.entry_count())


## Ouvre l'index des factions P1-34. Son absence n'est pas une panne : sans lui,
## l'hostilite retombe exactement sur le seul `AggroLevel` d'avant le jalon.
func _load_faction_index() -> void:
	_factions = null
	_faction_report = {
		"enabled": factions_enabled, "loaded": false, "factions": 0,
		"applied": 0, "hostile_by_faction": 0, "borrowed_factions_ignored": 0,
		"error": "",
	}
	if not factions_enabled:
		return
	var index: RefCounted = FactionIndexScript.new()
	if not index.load_index():
		_faction_report["error"] = str(index.error)
		return
	_factions = index
	_faction_report["loaded"] = true
	var described: Dictionary = index.describe()
	_faction_report["factions"] = int(described.get("factions", 0))
	_faction_report["link_counts"] = described.get("link_counts", {})
	# Le constat du jalon voyage avec le rapport de session : `factionaggrolevel`
	# est VIDE, donc aucune reputation personnelle n'existe et l'hostilite se lit
	# entierement sur `BaseAggroLevel`.
	_faction_report["character_reputation_rows"] = int(described.get("character_reputation_rows", 0))
	_faction_report["character_reputation_state"] = str(described.get("character_reputation_state", "UNKNOWN"))


## Ouvre l'index de butin P1-22C. Absent, les cadavres n'ont que leur argent.
func _load_loot_index() -> void:
	_loot_index = null
	_loot_report = {"enabled": loot_enabled, "loaded": false, "templates": 0, "items": 0, "error": ""}
	if not loot_enabled:
		return
	var index: RefCounted = LootIndexScript.new()
	if not index.load_index():
		_loot_report["error"] = str(index.error)
		return
	_loot_index = index
	_loot_report["loaded"] = true
	_loot_report["templates"] = int(index.template_count())
	_loot_report["items"] = int(index.item_count())


## Verse dans l'etat d'un PNJ ce que la base sait de lui.
##
## CE QUI EST REMPLACE : les quatre statistiques, le type de degats au corps a
## corps, la portee et le niveau d'aggro, le delai de reapparition, le rayon
## d'errance, la vitesse, la table de butin.
##
## CE QUI NE L'EST PAS, et le contrat de P1-22A le dit : la VIE MAXIMALE. La
## regle qui la calcule vit dans le code d'OpenDAoC, pas dans ses tables. Avoir
## la vraie constitution ne donne pas la vraie formule.
func _apply_mob_db_profile(object_id: int, entity: Dictionary, state: DaocCombatEntityState) -> void:
	if _mob_db == null:
		return
	var profile: Dictionary = _mob_db.profile_for(entity)
	if not bool(profile.get("resolved", false)):
		return
	var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
	var basis: Dictionary = meta.get("basis", {}) as Dictionary

	var stats: Dictionary = profile.get("stats", {}) as Dictionary
	if not stats.is_empty():
		for key in stats:
			state.stats[key] = float(stats[key])
			basis[key] = VitalsScript.BASIS_MOB_DB

	# P1-26 — LES RESISTANCES RACIALES DE CE SPAWN-LA.
	#
	# `mob.sql` porte une colonne `Race` et `GameNPC` la lit ; `race.sql` declare
	# 41 races, dont des familles de monstres. Sur les 188 PNJ de la capture, 88
	# en declarent une — 25 Animal, 51 Humanoid, 12 Undead.
	#
	# UNE RACE ZERO EST UNE ABSENCE, PAS UNE RACE : les 85 restants gardent leurs
	# resistances nulles, et la provenance reste PLACEHOLDER pour eux.
	if use_dol_formulas and int(profile.get("race", 0)) > 0:
		if _race_index == null:
			_race_index = RaceIndexScript.new()
			_race_index.load_index()
		var race_resists: Dictionary = _race_index.resists_for_id(int(profile["race"]))
		if not race_resists.is_empty():
			state.resists = race_resists
			basis["resists"] = VitalsScript.BASIS_DUMP_RACE
			meta["race_name"] = _race_index.name_for_id(int(profile["race"]))

	# P1-23 — LES DEUX MOITIES SE REJOIGNENT ICI, ET C'EST LE JALON.
	#
	# P1-22A disait, et il avait raison a l'epoque : « avoir la vraie
	# constitution ne donne pas la vraie formule ». La base donnait la
	# constitution, la formule vivait dans le code, et les deux ne se
	# rencontraient nulle part — d'ou une vie maximale PLACEHOLDER malgre une
	# constitution MOB_DB juste a cote.
	#
	# La formule est portee depuis `MaxHealthCalculator`. La vie maximale est
	# donc RECALCULEE avec la constitution de ce PNJ-la, et le POURCENTAGE de vie
	# observe dans la capture est conserve : un mob deja blesse le reste, il ne
	# guerit pas en changeant d'echelle.
	# DEFAUT ATTRAPE PAR LA SONDE DE P1-25 : ce bloc s'appliquait AUSSI au joueur.
	# Heyveno se fait rapprocher d'un mob par l'index P1-22A — elle en herite les
	# statistiques — et sa vie maximale etait donc recalculee par la formule des
	# PNJ — `MaxHealthCalculator` branche GameNPC — alors que `GamePlayer` a la
	# sienne, qui depend du `BaseHP` de son metier. Deux courbes tres differentes,
	# et rien ne le disait : la provenance affichait DOL_CODE dans les deux cas.
	if use_dol_formulas and not state.is_player and stats.has("Constitution"):
		var constitution: int = int(stats["Constitution"])
		if constitution > 0:
			var previous_max: int = maxi(1, state.max_health)
			var percent: float = float(state.health) / float(previous_max)
			state.max_health = VitalsScript.dol_max_health(state.level, constitution)
			state.health = clampi(int(round(float(state.max_health) * percent)), 0, state.max_health)
			if state.health <= 0 and percent > 0.0:
				state.health = 1
			state.is_alive = state.health > 0
			basis["max_health"] = VitalsScript.BASIS_DOL_CODE
			basis["constitution_for_health"] = VitalsScript.BASIS_MOB_DB
	# L'HOSTILITE NE S'EMPRUNTE PAS, et c'est la lecon la plus chere de P1-22D.
	#
	# Mesure avant la regle : sur les 188 PNJ de la capture, **103** se
	# retrouvaient agressifs — des marchands et des gardes de Gothwaite qui
	# heritaient l'aggro d'un monstre partageant leur modele et leur niveau.
	# Entrer en ville, c'etait etre pris en chasse par une douzaine de niveaux 60.
	#
	# Une statistique empruntee reste une approximation defendable : deux
	# creatures de meme apparence et de meme niveau ont des forces voisines.
	# L'HOSTILITE, elle, est une propriete de CE spawn-la, pas de son modele.
	# Elle n'est donc reprise QUE d'un `SPAWN_MATCH` — le meme mob, au meme
	# endroit — et jamais d'un rapprochement par modele.
	#
	# La CAPTURE tranche par-dessus : elle porte un drapeau `peaceful` observe
	# sur le vrai serveur. Une valeur observee bat toujours une valeur empruntee.
	var spawn_matched: bool = str(profile.get("basis", "")) == "SPAWN_MATCH"
	var flags: Dictionary = (entity.get("flags", {}) as Dictionary)
	var captured_peaceful: bool = bool(flags.get("peaceful", false))
	var trusted: bool = spawn_matched or aggro_from_borrowed_profiles
	var aggro_level: int = int(profile.get("aggro_level", 0)) if trusted else 0
	var aggro_basis: String = "SPAWN_MATCH" if spawn_matched else "BORROWED_BY_CHOICE"
	if captured_peaceful:
		aggro_level = 0
		aggro_basis = "CAPTURE_PEACEFUL"
	elif not trusted:
		aggro_basis = "NOT_BORROWED"

	# P1-34 — LA FACTION SUIT EXACTEMENT LA MEME REGLE QUE L'AGGRO. Une faction
	# empruntee a un sosie n'est pas la faction de CE spawn-la : la reprendre
	# rendrait hostiles des PNJ dont on ne sait rien, ce qui est precisement le
	# defaut que P1-22D a paye au prix fort.
	#
	# Mesure : 25 des 188 PNJ de la capture portent un `FactionID`, et AUCUN
	# d'eux n'est un `SPAWN_MATCH`. Dans ce monde-la, ce bloc ne changera donc
	# rien a l'ecran — et le rapport le compte plutot que de le taire.
	var declared_faction: int = int(profile.get("faction_id", 0))
	var faction_id: int = declared_faction if trusted else 0
	var faction_aggro: int = 0
	var faction_name: String = ""
	var faction_basis: String = "NO_FACTION"
	if declared_faction > 0 and not trusted:
		faction_basis = "NOT_BORROWED"
		_faction_report["borrowed_factions_ignored"] = int(
			_faction_report.get("borrowed_factions_ignored", 0)) + 1
	if faction_id > 0 and _factions != null and not captured_peaceful:
		if bool(_factions.known(faction_id)):
			# Aucune reputation personnelle n'existe dans ce dump, donc
			# `aggro_to_player` retombe TOUJOURS sur `BaseAggroLevel` ici. Le
			# dictionnaire vide est passe explicitement pour que le jour ou une
			# vraie partie en produira une, il n'y ait rien a rebrancher.
			var resolved: Dictionary = FactionRulesScript.aggro_to_player(
				int(_factions.base_aggro_level(faction_id)), {}, "")
			faction_aggro = int(resolved.get("aggro", 0))
			faction_name = str(_factions.name_of(faction_id))
			faction_basis = str(resolved.get("basis", "BASE_AGGRO_LEVEL"))
			_faction_report["applied"] = int(_faction_report.get("applied", 0)) + 1
			if FactionRulesScript.is_aggressive_to_player(aggro_level, faction_aggro):
				if aggro_level <= 0:
					# Le cas que le projet ne savait pas voir : hostile SANS
					# `AggroLevel`, uniquement parce que sa faction l'est.
					_faction_report["hostile_by_faction"] = int(
						_faction_report.get("hostile_by_faction", 0)) + 1
		else:
			faction_basis = "FACTION_ABSENT_FROM_INDEX"

	meta["mob_db"] = {
		"db_name": str(profile.get("db_name", "")),
		"basis": str(profile.get("basis", "")),
		"aggro_level": aggro_level,
		"aggro_basis": aggro_basis,
		"aggro_level_in_db": int(profile.get("aggro_level", 0)),
		"aggro_range_raw": int(profile.get("aggro_range_raw", 0)),
		"roaming_range_raw": int(profile.get("roaming_range_raw", 0)),
		"speed_raw": int(profile.get("speed_raw", 0)),
		"respawn_interval_sec": int(profile.get("respawn_interval_sec", 0)),
		"body_type": int(profile.get("body_type", 0)),
		"faction_id": faction_id,
		"faction_id_in_db": declared_faction,
		"faction_name": faction_name,
		"faction_basis": faction_basis,
		"faction_aggro": faction_aggro,
		"faction_enemies": _factions.enemies_of(faction_id) if _factions != null and faction_id > 0 else [],
		"aggro_level_string": FactionRulesScript.aggro_level_string(faction_aggro) if faction_id > 0 else "",
		"hostile_to_player": FactionRulesScript.is_aggressive_to_player(aggro_level, faction_aggro),
		"loot_templates": profile.get("loot_templates", []),
	}
	var weapon: Dictionary = meta.get("weapon", {}) as Dictionary
	if profile.has("melee_damage_type") and int(profile.get("melee_damage_type", 0)) > 0:
		weapon["damage_type"] = int(profile["melee_damage_type"])
		weapon["basis"] = VitalsScript.BASIS_MOB_DB
		meta["weapon"] = weapon
	meta["basis"] = basis
	_meta[object_id] = meta
	_mob_db_report["applied"] = int(_mob_db_report.get("applied", 0)) + 1


## Retient de quoi faire REVENIR une creature : ou elle etait, et en quelle
## sante. Sans cet enregistrement, une reapparition devrait relire la capture.
func _remember_spawn(object_id: int, state: DaocCombatEntityState) -> void:
	var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
	var mob_db: Dictionary = meta.get("mob_db", {}) as Dictionary
	var declared: int = int(mob_db.get("respawn_interval_sec", 0))
	_spawn_records[object_id] = {
		"world_position": _positions.get(object_id, Vector3.ZERO) as Vector3,
		"max_health": state.max_health,
		# Un `RespawnInterval` de 0 dans la base veut dire « defaut serveur ».
		"respawn_seconds": float(declared) if declared > 0 else default_respawn_seconds,
		"respawn_basis": "MOB_DB" if declared > 0 else "PLACEHOLDER",
	}


func shutdown() -> void:
	_corpses.clear()
	_purses.clear()
	_loot_rolls = 0
	_brains.clear()
	_aggro_triggered = 0
	_leash_returns = 0
	_spawn_records.clear()
	_experience.clear()
	_deaths_resolved = 0
	_respawns_resolved = 0
	_states.clear()
	_meta.clear()
	_positions.clear()
	_nodes.clear()
	_sessions.clear()
	_spell_casts.clear()
	_spell_cooldowns.clear()
	_active_spell_effects.clear()
	_event_log.clear()
	_clock_msec = 0.0
	_swing_counter = 0
	_stream_spawn_events = 0
	_stream_move_events = 0
	_stream_despawn_events = 0
	player_object_id = -1
	booted = false


## Relie chaque etat au noeud 3D construit par `DaocGothwaitePopulation`.
## Le serveur n'a pas besoin des noeuds pour arbitrer : il s'en sert seulement
## pour que le client sache quoi surligner et quoi faire tomber.
## B5 — en MIROIR, les jauges du joueur viennent du 0xAD du serveur. Rien
## n'est calcule : les valeurs sont posees telles quelles et state_changed
## previent le pont d'interface, qui ne lit que snapshot() (P1-28).
func apply_remote_player_status(status: Dictionary) -> Dictionary:
	if not mirror_mode:
		return {"ok": false, "reason": "pas en mode miroir"}
	var state: DaocCombatEntityState = _states.get(player_object_id) as DaocCombatEntityState
	if state == null:
		return {"ok": false, "reason": "joueur absent de l'arbitre"}
	var max_health := int(status.get("max_health", state.max_health))
	if max_health > 0:
		state.max_health = max_health
		state.health = clampi(int(status.get("health", state.health)), 0, max_health)
	else:
		state.health = clampi(int(round(float(status.get("health_percent", 100)) * state.max_health / 100.0)), 0, state.max_health)
	state.max_mana = int(status.get("max_mana", state.max_mana))
	state.mana = clampi(int(status.get("mana", state.mana)), 0, maxi(state.max_mana, 0))
	state.max_endurance = int(status.get("max_endurance", state.max_endurance))
	state.endurance = clampi(int(status.get("endurance", state.endurance)), 0, maxi(state.max_endurance, 0))
	state.is_alive = state.health > 0
	var meta: Dictionary = _meta.get(player_object_id, {}) as Dictionary
	meta["status_source"] = "SERVER_0xAD"
	_meta[player_object_id] = meta
	_remote_status_updates += 1
	state_changed.emit(player_object_id, snapshot(player_object_id))
	return {"ok": true, "health": state.health, "max_health": state.max_health,
		"mana": state.mana, "max_mana": state.max_mana, "endurance": state.endurance}


var _remote_status_updates := 0


func apply_remote_entity_health_percent(object_id: int, health_percent: int) -> Dictionary:
	if not mirror_mode:
		return {"ok": false, "reason": "pas en mode miroir"}
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {"ok": false, "reason": "entite inconnue"}
	var percent := clampi(health_percent, 0, 100)
	state.health = int(round(float(state.max_health) * float(percent) / 100.0))
	state.is_alive = percent > 0
	state_changed.emit(object_id, snapshot(object_id))
	return {"ok": true, "object_id": object_id, "health_percent": percent}


func attach_nodes(population_root: Node) -> int:
	_nodes.clear()
	if population_root == null:
		return 0
	for child in population_root.get_children():
		if not child is Node3D:
			continue
		var node: Node3D = child as Node3D
		if not node.has_meta("daoc_object_id"):
			continue
		var object_id: int = int(node.get_meta("daoc_object_id"))
		if _states.has(object_id):
			_nodes[object_id] = node
	return _nodes.size()


## R3 — fait entrer une apparition R2 dans l'arbitrage. C'est la version
## incrementale de la boucle de `boot` : seules les entites qui ont reellement
## atteint le flux existent ici. Le decor reste volontairement sans etat de
## combat, exactement comme lors de l'amorcage historique.
func spawn_stream_entity(entity: Dictionary, node: Node3D = null) -> Dictionary:
	_stream_spawn_events += 1
	var object_id := int(entity.get("object_id", -1))
	if object_id < 0:
		return {"ok": false, "reason": "object_id invalide", "object_id": object_id}
	if _states.has(object_id):
		if node != null:
			_nodes[object_id] = node
		return {"ok": true, "outcome": "already_present", "object_id": object_id}

	var entity_type := str(entity.get("entity_type", ""))
	var built: Dictionary = {}
	# P1-94 : un 0x4B est aussi un « player », mais ce n'est PAS le notre. Le
	# premier joueur inscrit (capture ou 0x88) reste le joueur local ; les
	# suivants sont des joueurs DISTANTS : etat de joueur pour le ciblage et
	# l'UI, mais ni identite locale ni inventaire.
	var is_remote_player := entity_type == "player" and player_object_id >= 0 and player_object_id != object_id
	if is_remote_player:
		built = VitalsScript.player_state_from_capture(entity, maxi(1, int(entity.get("level", 1))), use_dol_formulas)
		built["entity_type"] = "player"
		built["remote_player"] = true
		_boot_report["remote_players"] = int(_boot_report.get("remote_players", 0)) + 1
	elif entity_type == "player":
		built = VitalsScript.player_state_from_capture(entity, _player_level_override, use_dol_formulas)
		player_object_id = object_id
	elif entity_type == "npc":
		built = VitalsScript.npc_state_from_capture(entity, use_dol_formulas)
	elif entity_type == "object" and world_objects_targetable:
		# P1-110 : un objet du monde (0xD9 — sac de butin, pierre tombale,
		# piece de siege) est CIBLABLE sans etre un combattant : DOL ramasse
		# et prie sur la CIBLE du joueur (PickUpObject, Pray). Aucune vie,
		# aucun cerveau, jamais attaquable.
		var object_state := DaocCombatEntityState.new()
		object_state.entity_id = object_id
		object_state.name = str(entity.get("name", "objet %d" % object_id))
		object_state.level = 0
		object_state.max_health = 1
		object_state.health = 1
		object_state.is_player = false
		object_state.is_alive = true
		built = {"state": object_state, "basis": {"name": "CAPTURE", "kind": "WORLD_OBJECT"}, "entity_type": "object",
			"model_id": int(entity.get("model_id", -1)), "attackable": false, "flags": entity.get("flags", {}),
			"world_position": Vector3(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)), float(entity.get("z", 0.0)))}
		_boot_report["world_objects_targetable"] = int(_boot_report.get("world_objects_targetable", 0)) + 1
	else:
		_boot_report["world_objects_ignored"] = int(_boot_report.get("world_objects_ignored", 0)) + 1
		return {
			"ok": true, "outcome": "world_object_ignored", "object_id": object_id,
			"combat_state": false,
		}

	var state: DaocCombatEntityState = built.get("state") as DaocCombatEntityState
	if state == null:
		_boot_report["skipped"] = int(_boot_report.get("skipped", 0)) + 1
		return {"ok": false, "reason": "etat de combat absent", "object_id": object_id}

	_states[object_id] = state
	_meta[object_id] = {
		"basis": built.get("basis", {}),
		"weapon": built.get("weapon", {}),
		"armor": built.get("armor", {}),
		"shield": built.get("shield", {}),
		"realm": int(built.get("realm", 0)),
		"entity_type": str(built.get("entity_type", entity_type)),
		"model_id": int(built.get("model_id", -1)),
		"attackable": bool(built.get("attackable", false)),
		"flags": built.get("flags", {}),
		"remote_player": is_remote_player,
	}
	if entity_type != "object":
		_apply_mob_db_profile(object_id, entity, state)
	if entity_type == "player" and not is_remote_player:
		_install_player_inventory()
	_remember_spawn(object_id, state)
	_positions[object_id] = built.get("world_position", Vector3.ZERO) as Vector3
	var basis_counts: Dictionary = _boot_report.get("basis_field_counts", {}) as Dictionary
	for key in (built.get("basis", {}) as Dictionary).keys():
		var basis_value := str((built.get("basis", {}) as Dictionary)[key])
		basis_counts[basis_value] = int(basis_counts.get(basis_value, 0)) + 1
	_boot_report["basis_field_counts"] = basis_counts
	if node != null:
		_nodes[object_id] = node
	booted = not _states.is_empty()
	var born := snapshot(object_id)
	state_changed.emit(object_id, born)
	return {
		"ok": true, "outcome": "combat_entity_spawned", "object_id": object_id,
		"combat_state": true, "snapshot": born,
	}


## R3 — attache le corps visuel cree par le meme evenement. Separe de
## `spawn_stream_entity` pour garder un chemin valable meme quand une entite
## combat existe sans scene exploitable.
func attach_entity_node(object_id: int, node: Node3D) -> bool:
	if not _states.has(object_id) or node == null:
		return false
	_nodes[object_id] = node
	return true


## R3 — suit un 0xA1 dans le meme referentiel MONDE que l'arbitrage. La
## conversion zone -> monde reste chez l'appelant, qui connait l'origine.
func move_stream_entity(object_id: int, world_position: Vector3) -> Dictionary:
	_stream_move_events += 1
	if not _states.has(object_id):
		return {"ok": true, "outcome": "no_combat_state", "object_id": object_id}
	_positions[object_id] = world_position
	return {"ok": true, "outcome": "combat_entity_moved", "object_id": object_id}


## R3 — retire une entite de TOUT l'arbitrage, y compris comme attaquant ou
## cible d'une session. Ce n'est pas une mort : aucun butin, aucune animation
## d'agonie et aucun evenement `entity_died` ne sont inventes.
func despawn_stream_entity(object_id: int, reason: String = "entity_stream") -> Dictionary:
	_stream_despawn_events += 1
	if not _states.has(object_id):
		_nodes.erase(object_id)
		_positions.erase(object_id)
		_meta.erase(object_id)
		return {"ok": true, "outcome": "no_combat_state", "object_id": object_id}

	var before := snapshot(object_id)
	_cancel_sessions_involving(object_id)
	# P1-22B — une entite retiree du flux ne revient pas : son cadavre et son
	# point d apparition partent avec elle. Les laisser ferait reapparaitre une
	# creature que le monde ne contient plus.
	_corpses.erase(object_id)
	_spawn_records.erase(object_id)
	_brains.erase(object_id)
	_cancel_sessions_involving(object_id)
	_states.erase(object_id)
	_meta.erase(object_id)
	_positions.erase(object_id)
	_nodes.erase(object_id)
	if player_object_id == object_id:
		player_object_id = -1
	booted = not _states.is_empty()
	entity_removed.emit(object_id, before, reason)
	return {
		"ok": true, "outcome": "combat_entity_despawned", "object_id": object_id,
		"snapshot": before,
	}


# --------------------------------------------------------------------------
# Flux du monde vers l'autorite
# --------------------------------------------------------------------------

## Le joueur bouge cote client ; l'autorite doit connaitre sa position pour
## juger la portee. Coordonnees DAoC MONDE, comme la capture.
func set_entity_world_position(object_id: int, world_position: Vector3) -> void:
	if _states.has(object_id):
		_positions[object_id] = world_position


func get_entity_world_position(object_id: int) -> Vector3:
	return _positions.get(object_id, Vector3.ZERO) as Vector3


# --------------------------------------------------------------------------
# Intentions du client
# --------------------------------------------------------------------------

## Demande d'engagement. Le client ne decide de rien : il demande.
# --------------------------------------------------------------------------
# P1-31 — LES STYLES SE DECLENCHENT
#
# P1-29 a catalogue 1199 styles et branche la vraie formule de `StyleProcessor`.
# Puis RIEN NE LES APPELAIT : ni routeur de commandes, ni interface. Troisieme
# fois de suite le meme motif dans ce depot - une regle prouvee, inatteignable -
# apres `loot_corpse` et le niveau du joueur ecrit en dur.
#
# TOUTE LA DECISION EST ICI, ET C'EST LE POINT DU JALON. Le client envoie un NOM
# de style ; l'arbitre decide s'il est connu, s'il est legal maintenant, ce qu'il
# coute et ce qu'il rend. Un client qui choisirait lui-meme contredirait un vrai
# OpenDAoC le jour ou il repond, et P1-28 tomberait en le nommant.
# --------------------------------------------------------------------------

## Le catalogue, charge au premier besoin. Une session sans style ne le lit pas.
func _ensure_style_index() -> RefCounted:
	if _style_index == null:
		_style_index = StyleIndexScript.new()
		_style_index.load_index()
	return _style_index


func _ensure_spell_catalogue() -> DaocSpellCatalogue:
	if _spell_catalogue == null:
		_spell_catalogue = SpellCatalogueScript.new()
		_spell_catalogue.load_index()
	if _spell_registry == null:
		_spell_registry = SpellRegistryScript.new()
	return _spell_catalogue


## Livre effectivement appris par l'entité. Il est calculé depuis ses lignes,
## jamais depuis tout le catalogue et jamais depuis le contenu de la barre.
func known_spells(object_id: int) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {"ok": false, "reason": "acteur inconnu", "usable": [], "blocked": []}
	var catalogue := _ensure_spell_catalogue()
	return SpellLoadoutScript.new().build(catalogue, _spell_registry, state.spell_line_levels)


## Ouvre toutes les specialisations du metier au niveau donne (personnage frais,
## le serveur ne dit pas encore les points depenses - B7). La table des metiers
## est une REGLE : elle se lit ici, cote autorite, jamais dans le monde (P1-28).
func configure_player_class_career(object_id: int, class_id: int, level: int) -> Dictionary:
	var classes = ClassTableScript.new()
	if not classes.load_index():
		return {"ok": false, "reason": "table des metiers indisponible"}
	var specs: Dictionary = {}
	for spec in classes.career_specs(class_id):
		specs[str(spec)] = maxi(1, level)
	return configure_player_specializations(object_id, class_id, specs)


## Applique les choix explicites sauvegardes du personnage. Les possibilites du
## metier servent uniquement de filtre et ne deviennent jamais des choix.
func configure_player_specializations(object_id: int, class_id: int, trained_specs: Dictionary) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null or not state.is_player:
		return {"ok": false, "reason": "joueur inconnu"}
	var classes := ClassTableScript.new()
	if not classes.load_index():
		return {"ok": false, "reason": "table des metiers indisponible"}
	var resolved: Dictionary = SpellLinesScript.new().resolve(
		_ensure_spell_catalogue(), classes, class_id, state.level, trained_specs)
	if not bool(resolved.get("ok", false)):
		return resolved
	state.character_class_id = class_id
	state.spec_levels = (resolved.get("selected_specs", {}) as Dictionary).duplicate(true)
	state.spell_line_levels = (resolved.get("line_levels", {}) as Dictionary).duplicate(true)
	state_changed.emit(object_id, snapshot(object_id))
	return {
		"ok": true,
		"trained_specs": state.spec_levels.duplicate(true),
		"spell_line_levels": state.spell_line_levels.duplicate(true),
	}


## Monte une unique voie ToA dans le livre autoritaire. Changer de voie retire
## l'ancienne avant d'ajouter la nouvelle ; aucune capacite n'est placee en barre.
func configure_player_master_level(object_id: int, class_id: int, path_name: String, master_level: int) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null or not state.is_player:
		return {"ok": false, "reason": "joueur inconnu"}
	if state.character_class_id > 0 and class_id != state.character_class_id:
		return {"ok": false, "reason": "metier different de celui du personnage"}
	var progression = MasterLevelStateScript.new().setup(state.name, class_id)
	if path_name != "" and not bool(progression.choose_path(path_name).get("ok", false)):
		return {"ok": false, "reason": "voie ML indisponible pour ce metier"}
	if not bool(progression.set_master_level(master_level).get("ok", false)):
		return {"ok": false, "reason": "niveau ML sans voie choisie"}
	if state.master_level_path != "":
		state.spell_line_levels.erase(state.master_level_path)
	state.master_level_path = progression.path_name
	state.master_level = progression.master_level
	if path_name != "" and state.master_level > 0:
		state.spell_line_levels[path_name] = state.master_level
	state_changed.emit(object_id, snapshot(object_id))
	var rows := progression.unlocked_abilities()
	return {"ok": true, "path": path_name, "master_level": state.master_level,
		"abilities": rows, "data_complete": rows.size() == state.master_level}


func known_master_level_abilities(object_id: int) -> Array:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null or state.master_level_path == "":
		return []
	var progression = MasterLevelStateScript.new().setup(state.name, state.character_class_id)
	progression.choose_path(state.master_level_path)
	progression.set_master_level(state.master_level)
	return progression.unlocked_abilities()


func request_master_level_ability(caster_id: int, target_id: int, ability_id: String) -> Dictionary:
	for value in known_master_level_abilities(caster_id):
		var ability := value as Dictionary
		if str(ability.get("ability_id", "")) == ability_id:
			return {"ok": false, "reason": "gestionnaire ML non branche", "target_id": target_id,
				"ability": ability.duplicate(true)}
	return {"ok": false, "reason": "capacite ML non acquise"}


func configure_player_champion_levels(object_id: int, class_id: int, champion_level: int,
		trained_lines: Dictionary, catalogue_lines: Dictionary) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null or not state.is_player:
		return {"ok": false, "reason": "joueur inconnu"}
	if state.character_class_id > 0 and class_id != state.character_class_id:
		return {"ok": false, "reason": "metier different de celui du personnage"}
	var progression = ChampionLevelStateScript.new().setup(state.name, class_id, state.level)
	var embarked: Dictionary = progression.embark()
	if not bool(embarked.get("ok", false)):
		return embarked
	var leveled: Dictionary = progression.set_champion_level(champion_level)
	if not bool(leveled.get("ok", false)):
		return leveled
	for line_key_value in trained_lines:
		var line_key := str(line_key_value)
		var requested_rank := int(trained_lines[line_key_value])
		var profession := str((catalogue_lines.get(line_key, {}) as Dictionary).get("profession", ""))
		for rank in range(1, requested_rank + 1):
			var trained: Dictionary = progression.train_line(profession, line_key, rank, catalogue_lines)
			if not bool(trained.get("ok", false)):
				return trained
	state.champion_enabled = true
	state.champion_level = progression.champion_level
	state.champion_trained_lines = progression.trained_lines.duplicate(true)
	state.champion_abilities = progression.unlocked_abilities(catalogue_lines)
	# DOL accorde un pool aux tanks purs sans ManaStat des le CL1. La valeur 100
	# est conservee comme estimation DOL explicite, pas comme formule officielle.
	if state.champion_level > 0 and state.max_mana <= 0:
		state.max_mana = 100
		state.mana = 100
	state_changed.emit(object_id, snapshot(object_id))
	return {"ok": true, "champion_level": state.champion_level,
		"total_points": progression.total_points(), "available_points": progression.available_points(),
		"trained_lines": state.champion_trained_lines.duplicate(true),
		"abilities": state.champion_abilities.duplicate(true)}


func known_champion_level_abilities(object_id: int) -> Array:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	return [] if state == null else state.champion_abilities.duplicate(true)


func request_champion_level_ability(caster_id: int, target_id: int, ability_id: String) -> Dictionary:
	for value in known_champion_level_abilities(caster_id):
		var ability := value as Dictionary
		if str(ability.get("ability_id", "")) == ability_id:
			return {"ok": false, "reason": "gestionnaire CL non branche", "target_id": target_id,
				"ability": ability.duplicate(true)}
	return {"ok": false, "reason": "capacite CL non acquise"}


## Première couture sort -> arbitre : vérifie que le sort est appris, qu'il a
## un gestionnaire, une cible légale, assez de mana et la portée. Les sorts à
## temps d'incantation sont refusés tant que l'horloge D3 n'existe pas : les
## exécuter instantanément serait une règle fausse.
func request_spell(caster_id: int, target_id: int, spell_id: int, line_name: String) -> Dictionary:
	if mirror_mode:
		return {"ok": false, "reason": "autorite distante : sort non branche (B6)"}
	var caster: DaocCombatEntityState = _states.get(caster_id) as DaocCombatEntityState
	if caster == null:
		return {"ok": false, "reason": "acteur inconnu"}
	if not caster.is_alive:
		return {"ok": false, "reason": "acteur mort"}
	var learned: Dictionary = {}
	for value in (known_spells(caster_id).get("usable", []) as Array):
		var entry := value as Dictionary
		if int(entry.get("spell_id", 0)) == spell_id and str(entry.get("line", "")) == line_name:
			learned = entry
			break
	if learned.is_empty():
		return {"ok": false, "reason": "sort non appris", "spell_id": spell_id, "line": line_name}

	var raw := _spell_catalogue.raw_spell(spell_id)
	var spell := DaocSpellDef.from_dict(raw)
	var handler: DaocSpellHandler = _spell_registry.create_handler(spell, line_name)
	if handler == null:
		return {"ok": false, "reason": "type de sort non gere", "spell_id": spell_id}
	if _spell_casts.has(caster_id):
		return {"ok": false, "reason": "incantation deja en cours"}
	if caster.is_moving and not spell.move_cast:
		return {"ok": false, "reason": "acteur en mouvement"}

	var target: DaocCombatEntityState = caster if spell.target.to_upper() == "SELF" else (_states.get(target_id) as DaocCombatEntityState)
	if target == null or not target.is_alive:
		return {"ok": false, "reason": "cible invalide"}
	var distance := _horizontal_distance(caster_id, target.entity_id)
	if target.entity_id != caster_id and spell.range > 0 and distance > _effective_spell_range(caster, spell):
		return {"ok": false, "reason": "hors de portee", "distance_raw": distance, "range": spell.range, "effective_range": _effective_spell_range(caster, spell)}
	var cost := maxi(0, handler.power_cost(target))
	if caster.mana < cost:
		return {"ok": false, "reason": "mana insuffisante", "required": cost, "available": caster.mana}
	var cooldown_key := "%d:%d" % [caster_id, spell_id]
	var ready_at := float(_spell_cooldowns.get(cooldown_key, 0.0))
	if _clock_msec < ready_at:
		return {"ok": false, "reason": "delai de reutilisation", "remaining_msec": ready_at - _clock_msec}

	if spell.cast_time > 0:
		_spell_casts[caster_id] = {
			"target_id": target.entity_id, "spell_id": spell_id, "line": line_name,
			"complete_msec": _clock_msec + float(spell.cast_time),
			"start_position": (_positions.get(caster_id, Vector3.ZERO) as Vector3),
			"move_cast": spell.move_cast, "uninterruptible": spell.uninterruptible,
		}
		var start_event := {
			"kind": "spell_cast_start", "attacker_id": caster_id, "target_id": target.entity_id,
			"spell_id": spell_id, "spell_name": spell.name, "cast_time": spell.cast_time,
			"client_effect": spell.client_effect,
			"text": "%s commence a incanter %s." % [caster.name, spell.name],
		}
		_emit_event(start_event)
		return {"ok": true, "pending": true, "complete_msec": _clock_msec + float(spell.cast_time), "event": start_event}

	return _complete_spell(caster_id, target.entity_id, spell, line_name, handler)


func _complete_spell(caster_id: int, target_id: int, spell: DaocSpellDef, line_name: String,
		handler: DaocSpellHandler = null) -> Dictionary:
	var caster: DaocCombatEntityState = _states.get(caster_id) as DaocCombatEntityState
	var target: DaocCombatEntityState = caster if spell.target.to_upper() == "SELF" else (_states.get(target_id) as DaocCombatEntityState)
	if caster == null or not caster.is_alive or target == null or not target.is_alive:
		return {"ok": false, "reason": "cible ou acteur invalide a la resolution"}
	var distance := _horizontal_distance(caster_id, target.entity_id)
	if target.entity_id != caster_id and spell.range > 0 and distance > _effective_spell_range(caster, spell):
		return {"ok": false, "reason": "hors de portee", "distance_raw": distance, "range": spell.range, "effective_range": _effective_spell_range(caster, spell)}
	if handler == null:
		handler = _spell_registry.create_handler(spell, line_name)
	if handler == null:
		return {"ok": false, "reason": "type de sort non gere"}
	var cost := maxi(0, handler.power_cost(target))
	if caster.mana < cost:
		return {"ok": false, "reason": "mana insuffisante", "required": cost, "available": caster.mana}

	caster.mana -= cost
	# P1-123 : un style NaturesShield arme bloque le sort ennemi (AttackComponent).
	if target.entity_id != caster_id and spell.target.to_lower() == "enemy" and natures_shield_blocks_spell(target.entity_id):
		natures_shield_blocks += 1
		var blocked := {"kind": "spell_blocked", "attacker_id": caster_id, "target_id": target.entity_id,
			"spell_id": spell.id, "text": "%s bloque %s (Nature's Shield)." % [target.name, spell.name]}
		_emit_event(blocked)
		return {"ok": true, "event": blocked, "blocked": true, "mana_after": caster.mana}
	# P1-123 : la cible peut RESISTER (SpellHandler.CalculateSpellResistChance =
	# 100 - chance de toucher). Jusqu'ici un sort hors ligne touchait toujours.
	if spell_resists_enabled and target.entity_id != caster_id and spell.target.to_lower() == "enemy":
		_spell_resist_rolls += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base + spell.id * 131 + _spell_resist_rolls
		var hit_chance := handler.calculate_to_hit_chance(caster, target)
		if rng.randf() * 100.0 >= hit_chance:
			spells_resisted += 1
			var resisted := {"kind": "spell_resisted", "attacker_id": caster_id, "target_id": target.entity_id,
				"spell_id": spell.id, "hit_chance": hit_chance,
				"text": "%s resiste a %s (%.1f %%)." % [target.name, spell.name, 100.0 - hit_chance]}
			_emit_event(resisted)
			return {"ok": true, "event": resisted, "resisted": true, "mana_after": caster.mana}
	var health_before := target.health
	var result := handler.execute(caster, target, {
		"seed": seed_base + spell.id, "distance": distance, "apply_to_target": true,
		"defer_periodic": true,
	})
	_register_spell_effects(caster_id, target.entity_id, spell, result.get("effects", []) as Array)
	var event := {
		"kind": "spell", "attacker_id": caster_id, "target_id": target.entity_id,
		"spell_id": spell.id, "spell_name": spell.name, "spell_type": spell.spell_type,
		"client_effect": spell.client_effect, "mana_cost": cost,
		"target_health_before": health_before, "target_health": target.health,
		"result": result.duplicate(true),
		"text": "%s lance %s sur %s." % [caster.name, spell.name, target.name],
	}
	_emit_event(event)
	state_changed.emit(caster_id, snapshot(caster_id))
	if target.entity_id != caster_id:
		state_changed.emit(target.entity_id, snapshot(target.entity_id))
	if not target.is_alive:
		_handle_death(target.entity_id, caster_id)
	if spell.recast_delay > 0:
		_spell_cooldowns["%d:%d" % [caster_id, spell.id]] = _clock_msec + float(spell.recast_delay)
	return {"ok": true, "event": event, "mana_after": caster.mana}


func _advance_spell_casts() -> Array:
	var produced: Array = []
	for caster_value in _spell_casts.keys().duplicate():
		var caster_id := int(caster_value)
		var cast := _spell_casts[caster_id] as Dictionary
		var caster: DaocCombatEntityState = _states.get(caster_id) as DaocCombatEntityState
		var interruption := ""
		if caster == null or not caster.is_alive:
			interruption = "acteur invalide"
		elif not bool(cast.get("move_cast", false)) and (caster.is_moving or (_positions.get(caster_id, Vector3.ZERO) as Vector3).distance_to(cast.get("start_position", Vector3.ZERO) as Vector3) > 0.01):
			interruption = "mouvement"
		if interruption != "":
			_spell_casts.erase(caster_id)
			var interrupted := {"kind": "spell_cast_interrupted", "attacker_id": caster_id,
				"target_id": int(cast.get("target_id", -1)), "spell_id": int(cast.get("spell_id", 0)),
				"reason": interruption, "text": "Incantation interrompue : %s." % interruption}
			_emit_event(interrupted)
			produced.append(interrupted)
			continue
		if _clock_msec < float(cast.get("complete_msec", INF)):
			continue
		_spell_casts.erase(caster_id)
		var raw := _spell_catalogue.raw_spell(int(cast.get("spell_id", 0)))
		var spell := DaocSpellDef.from_dict(raw)
		var completed := _complete_spell(caster_id, int(cast.get("target_id", -1)), spell, str(cast.get("line", "")))
		if bool(completed.get("ok", false)):
			produced.append(completed.get("event", {}) as Dictionary)
		else:
			var failed_event := {"kind": "spell_cast_interrupted", "attacker_id": caster_id,
				"target_id": int(cast.get("target_id", -1)), "spell_id": spell.id,
				"reason": str(completed.get("reason", "resolution refusee")),
				"text": "Incantation echouee : %s." % str(completed.get("reason", "resolution refusee"))}
			_emit_event(failed_event)
			produced.append(failed_event)
	return produced


func interrupt_spell_cast(caster_id: int, reason: String = "interruption", forced: bool = false) -> Dictionary:
	if not _spell_casts.has(caster_id):
		return {"ok": false, "reason": "aucune incantation en cours"}
	var cast := _spell_casts[caster_id] as Dictionary
	if bool(cast.get("uninterruptible", false)) and not forced:
		return {"ok": false, "reason": "sort ininterruptible"}
	# P1-124 : FacilitatePainworking rend le familier insensible aux interruptions.
	if not forced and _has_effect(caster_id, "interrupt_immune"):
		return {"ok": false, "reason": "insensible aux interruptions"}
	_spell_casts.erase(caster_id)
	var event := {"kind": "spell_cast_interrupted", "attacker_id": caster_id,
		"target_id": int(cast.get("target_id", -1)), "spell_id": int(cast.get("spell_id", 0)),
		"reason": reason, "text": "Incantation interrompue : %s." % reason}
	_emit_event(event)
	return {"ok": true, "event": event}


func active_spell_effects(target_id: int = -1) -> Array:
	var out: Array = []
	for value in _active_spell_effects:
		var effect := value as Dictionary
		if target_id < 0 or int(effect.get("target_id", -1)) == target_id:
			out.append(effect.duplicate(true))
	return out


func cancel_concentration(caster_id: int, spell_id: int = 0) -> Dictionary:
	var removed := 0
	for index in range(_active_spell_effects.size() - 1, -1, -1):
		var effect := _active_spell_effects[index] as Dictionary
		if int(effect.get("caster_id", -1)) != caster_id or int(effect.get("concentration", 0)) <= 0:
			continue
		if spell_id > 0 and int(effect.get("spell_id", 0)) != spell_id:
			continue
		_active_spell_effects.remove_at(index)
		removed += 1
	_rebuild_effect_modifiers()
	return {"ok": removed > 0, "removed": removed}


func _register_spell_effects(caster_id: int, target_id: int, spell: DaocSpellDef, effects: Array) -> void:
	for value in effects:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var raw := (value as Dictionary).duplicate(true)
		var effect_type := str(raw.get("effect_type", ""))
		# P1-109 : aggro, amnesie, interruption, transfert de vie - immediats.
		if _apply_immediate_spell_effect(caster_id, target_id, raw):
			continue
		if effect_type == "cure_state":
			_remove_effect_category(target_id, str(raw.get("removes_effect_category", "")))
			continue
		var duration := int(raw.get("duration", spell.duration))
		var frequency := int(raw.get("frequency", spell.frequency))
		if duration <= 0 and frequency <= 0 and spell.concentration <= 0:
			continue
		raw["spell_id"] = spell.id
		raw["caster_id"] = caster_id
		raw["target_id"] = target_id
		raw["duration"] = duration
		raw["frequency"] = frequency
		raw["concentration"] = spell.concentration
		raw["expires_msec"] = _clock_msec + float(duration) if duration > 0 else INF
		raw["next_tick_msec"] = _clock_msec + float(frequency) if frequency > 0 else INF
		raw["tick_index"] = 0
		_replace_stacking_effect(raw)
		_active_spell_effects.append(raw)
		# P1-109 : Confusion retarget des le debut (DOL OnEffectStart), puis a chaque pulsation.
		if effect_type == "confusion":
			_confuse(target_id, raw, 0)
	_rebuild_effect_modifiers()


func _replace_stacking_effect(incoming: Dictionary) -> void:
	var group := str(incoming.get("stacking_group", ""))
	var numeric_group := int(incoming.get("effect_group", 0))
	if group == "" and numeric_group <= 0:
		return
	for index in range(_active_spell_effects.size() - 1, -1, -1):
		var current := _active_spell_effects[index] as Dictionary
		if int(current.get("target_id", -1)) != int(incoming.get("target_id", -2)):
			continue
		if (group != "" and str(current.get("stacking_group", "")) == group) or (numeric_group > 0 and int(current.get("effect_group", 0)) == numeric_group):
			_active_spell_effects.remove_at(index)


func _remove_effect_category(target_id: int, category: String) -> void:
	for index in range(_active_spell_effects.size() - 1, -1, -1):
		var effect := _active_spell_effects[index] as Dictionary
		if int(effect.get("target_id", -1)) == target_id and (str(effect.get("effect_category", "")) == category or str(effect.get("effect_type", "")) == category):
			_active_spell_effects.remove_at(index)
	_rebuild_effect_modifiers()


func _advance_spell_effects() -> Array:
	var produced: Array = []
	var changed_targets: Dictionary = {}
	for index in range(_active_spell_effects.size() - 1, -1, -1):
		var effect := _active_spell_effects[index] as Dictionary
		var target_id := int(effect.get("target_id", -1))
		var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
		if target == null or not target.is_alive:
			_active_spell_effects.remove_at(index)
			continue
		var expires := float(effect.get("expires_msec", INF))
		var frequency := int(effect.get("frequency", 0))
		while frequency > 0 and float(effect.get("next_tick_msec", INF)) <= _clock_msec and float(effect.get("next_tick_msec", INF)) <= expires:
			_apply_spell_effect_tick(effect, target)
			effect["tick_index"] = int(effect.get("tick_index", 0)) + 1
			effect["next_tick_msec"] = float(effect.get("next_tick_msec", 0.0)) + float(frequency)
			changed_targets[target_id] = true
			var tick_event := {"kind": "spell_effect_tick", "attacker_id": int(effect.get("caster_id", -1)),
				"target_id": target_id, "spell_id": int(effect.get("spell_id", 0)),
				"effect_type": str(effect.get("effect_type", "")), "target_health": target.health,
				"text": "%s : pulsation." % str(effect.get("spell_name", effect.get("effect_type", "Effet")))}
			_emit_event(tick_event)
			produced.append(tick_event)
			if not target.is_alive:
				_handle_death(target_id, int(effect.get("caster_id", -1)))
				_active_spell_effects.remove_at(index)
				break
		if not target.is_alive:
			continue
		if expires <= _clock_msec:
			_active_spell_effects.remove_at(index)
			var expired := {"kind": "spell_effect_expired", "target_id": target_id,
				"spell_id": int(effect.get("spell_id", 0)), "effect_type": str(effect.get("effect_type", "")),
				"text": "%s expire." % str(effect.get("spell_name", effect.get("effect_type", "Effet")))}
			_emit_event(expired)
			produced.append(expired)
	_rebuild_effect_modifiers()
	for target_value in changed_targets.keys():
		state_changed.emit(int(target_value), snapshot(int(target_value)))
	return produced


func _apply_spell_effect_tick(effect: Dictionary, target: DaocCombatEntityState) -> void:
	match str(effect.get("effect_type", "")):
		"dot":
			var ticks := effect.get("ticks", []) as Array
			var tick_index := int(effect.get("tick_index", 0))
			if not ticks.is_empty():
				var tick := ticks[mini(tick_index, ticks.size() - 1)] as Dictionary
				target.change_health(-maxi(0, int(tick.get("damage", 0)) + int(tick.get("critical_damage", 0))))
		"heal_over_time":
			target.change_health(maxi(0, int(effect.get("per_tick", 0))))
		"resource_restore":
			var amount := maxi(0, int(effect.get("amount", 0)))
			match str(effect.get("resource", "")):
				"power": target.mana = clampi(target.mana + amount, 0, target.max_mana)
				"endurance": target.endurance = clampi(target.endurance + amount, 0, target.max_endurance)
		"tri_regen_buff":
			target.change_health(int(effect.get("health_value", 0)))
			target.mana = clampi(target.mana + int(effect.get("power_value", 0)), 0, target.max_mana)
			target.endurance = clampi(target.endurance + int(effect.get("endurance_value", 0)), 0, target.max_endurance)
		"confusion":
			_confuse(target.entity_id, effect, int(effect.get("tick_index", 0)) + 1)


func _rebuild_effect_modifiers() -> void:
	for value in _states.values():
		var state := value as DaocCombatEntityState
		state.effect_properties.clear()
		state.effect_resists.clear()
	for value in _active_spell_effects:
		var effect := value as Dictionary
		var target: DaocCombatEntityState = _states.get(int(effect.get("target_id", -1))) as DaocCombatEntityState
		if target == null:
			continue
		var stat := str(effect.get("modifier_stat", ""))
		var amount := float(effect.get("modifier_value", 0.0))
		if stat == "":
			continue
		if bool(effect.get("is_resist", false)) or str(effect.get("effect_category", "")) == "resists":
			target.effect_resists[stat] = float(target.effect_resists.get(stat, 0.0)) + amount
		elif str(effect.get("effect_category", "")) == "stats" or str(effect.get("effect_category", "")) == "range":
			target.effect_properties[stat] = float(target.effect_properties.get(stat, 0.0)) + amount


## Ce que cette entite peut REELLEMENT executer, et rien de plus.
##
## LA SOURCE EST P1-27, ET ELLE EST ETROITE. Seules les specialisations
## AUTO-ENTRAINEES sont connaissables : elles montent seules a `niveau / 4`, donc
## se deduisent du seul metier. Les points DEPENSES ne sont nulle part sur ce
## disque, et un Armsman de niveau 1 ne connait donc que les styles de niveau de
## spe 1 de Slash et Thrust. C'est EXACT, pas une restriction inventee.
func known_styles(object_id: int) -> Array:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null or not styles_enabled:
		return []
	var index: RefCounted = _ensure_style_index()
	if not bool(index.get("loaded")):
		return []
	var out: Array = []
	for spec_name_value in state.spec_levels.keys():
		var spec_name := str(spec_name_value)
		var spec_level: int = maxi(1, int(state.get_spec_level(spec_name, 1.0)))
		for entry_value in index.styles_for_spec(spec_name, spec_level):
			var entry: Dictionary = entry_value as Dictionary
			entry["spec_name"] = spec_name
			out.append(entry)
	return out


## Arme un style pour le PROCHAIN coup. Le nom est cherche parmi ceux que
## l'entite connait — jamais dans le catalogue entier, sinon un personnage de
## niveau 1 executerait un style de niveau 50 en le nommant.
func request_style(actor_id: int, style_name: String) -> Dictionary:
	if mirror_mode:
		return {"ok": false, "reason": "autorite distante : style non branche (B6)"}
	if not styles_enabled:
		return {"ok": false, "reason": "styles desactives"}
	var actor: DaocCombatEntityState = _states.get(actor_id) as DaocCombatEntityState
	if actor == null:
		return {"ok": false, "reason": "acteur inconnu"}
	if not actor.is_alive:
		return {"ok": false, "reason": "acteur mort"}

	var found: Dictionary = {}
	for entry_value in known_styles(actor_id):
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("name", "")) == style_name:
			found = entry
			break
	if found.is_empty():
		# NE PAS CONFONDRE « inconnu de ce personnage » ET « inexistant ». Le
		# premier est le cas courant et se corrige en montant ; le second est une
		# faute d'appel. Les melanger rendrait le catalogue impossible a deboguer.
		return {"ok": false, "reason": "style non appris", "style_name": style_name}

	# PAS `DaocStyleDef.from_dict` DIRECTEMENT : l'index garde les exigences en
	# ENTIERS et le def les attend en CHAINES. Sans la traduction, `str(0)` vaut
	# « 0 », qui n'est pas « Any », et TOUS les styles seraient refuses avec un
	# motif trompeur — « attack result requirement not met ».
	var style: DaocStyleDef = StyleIndexScript.style_def_from_entry(found)
	var session: Dictionary = _sessions.get(actor_id, {}) as Dictionary
	var target: DaocCombatEntityState = _states.get(int(session.get("target_id", -1))) as DaocCombatEntityState
	if _style_processor == null:
		_style_processor = StyleProcessorScript.new()
	# P1-31B — LES DEUX COUPS, ET C'EST TOUT LE SUJET DES OUVERTURES.
	#
	# `_last_attack` est indexe par ATTAQUANT, donc la meme table rend les deux :
	# le coup que J'AI porte, et - a la cle de ma cible - le coup QU'ELLE a
	# porte. Le processeur verifie ensuite que ce dernier me visait bien moi ;
	# un adversaire qui frappe quelqu'un d'autre n'ouvre rien.
	var target_id: int = int(session.get("target_id", -1))
	if target == null:
		# UN STYLE S'ARME CONTRE QUELQU'UN. `CanUseStyle` prend une cible, et pour
		# une bonne raison : les ouvertures se jugent par rapport a elle — le
		# meme adversaire pour un enchainement, celui qui m'a frappe pour une
		# defensive. Sans cible, le processeur repondrait
		# « missing living/target/style », un motif exact et inutilisable pour
		# qui joue. Le refus est donc NOMME ici.
		return {"ok": false, "reason": "aucune cible engagee", "style_name": style_name}
	var allowed: Dictionary = _style_processor.can_use_style(
		_last_attack.get(actor_id, null) as DaocAttackData, actor, target, style, {
			"target_last_attack": _last_attack.get(target_id, null),
		})
	if not bool(allowed.get("ok", false)):
		return {
			"ok": false, "reason": str(allowed.get("reason", "refus sans motif")),
			"style_name": style_name,
		}

	_pending_style[actor_id] = style
	return {
		"ok": true, "style_name": style_name,
		"spec_name": str(found.get("spec_name", "")),
		"endurance_cost": int(found.get("endurance_cost", 0)),
	}


## Le style arme, s'il y en a un. LE CONSOMMER EST LE POINT : un style vaut pour
## UN coup. Le laisser en place le rejouerait a chaque swing, gratuitement, ce
## qui n'est pas ce que DAoC fait.
func _take_pending_style(actor_id: int) -> DaocStyleDef:
	if not _pending_style.has(actor_id):
		return null
	var style: DaocStyleDef = _pending_style[actor_id] as DaocStyleDef
	_pending_style.erase(actor_id)
	return style


## En miroir, l'attaque part au serveur reel par ce rappel (B6) ; sans rappel,
## refus explicite.
var remote_attack_callback: Callable = Callable()


func request_attack(attacker_id: int, target_id: int) -> Dictionary:
	if mirror_mode:
		if remote_attack_callback.is_valid():
			return remote_attack_callback.call(attacker_id, target_id) as Dictionary
		return {"ok": false, "reason": "autorite distante : attaque non branchee (B6)"}
	if not _states.has(attacker_id):
		return {"ok": false, "reason": "attaquant inconnu"}
	if not _states.has(target_id):
		return {"ok": false, "reason": "cible inconnue"}
	if attacker_id == target_id:
		return {"ok": false, "reason": "cible = attaquant"}
	var attacker: DaocCombatEntityState = _states[attacker_id]
	var target: DaocCombatEntityState = _states[target_id]
	if not attacker.is_alive:
		return {"ok": false, "reason": "attaquant mort"}
	if not target.is_alive:
		return {"ok": false, "reason": "cible morte"}
	if not bool((_meta.get(target_id, {}) as Dictionary).get("attackable", false)):
		return {"ok": false, "reason": "cible non attaquable"}

	var weapon: Dictionary = (_meta.get(attacker_id, {}) as Dictionary).get("weapon", {}) as Dictionary
	var interval: int = DaocMeleeExchange.swing_interval_msec(attacker, weapon, use_dol_formulas)
	_sessions[attacker_id] = {
		"target_id": target_id,
		"interval_msec": interval,
		# Premier coup immediat : en DAoC on frappe des l'engagement, pas apres
		# un cycle d'attente.
		"next_swing_msec": _clock_msec,
		"swings": 0,
	}
	attacker.in_combat = true
	target.in_combat = true
	_emit_event({
		"kind": "engage",
		"attacker_id": attacker_id,
		"target_id": target_id,
		"text": "%s attaque %s." % [attacker.name, target.name],
	})
	return {"ok": true, "interval_msec": interval, "target": target.name}


func stop_attack(attacker_id: int) -> Dictionary:
	if not _sessions.has(attacker_id):
		return {"ok": false, "reason": "aucun combat en cours"}
	var session: Dictionary = _sessions[attacker_id] as Dictionary
	_sessions.erase(attacker_id)
	var attacker: DaocCombatEntityState = _states.get(attacker_id) as DaocCombatEntityState
	if attacker != null:
		attacker.in_combat = _is_targeted_by_anyone(attacker_id)
		_emit_event({
			"kind": "disengage",
			"attacker_id": attacker_id,
			"target_id": int(session.get("target_id", -1)),
			"text": "%s cesse d'attaquer." % attacker.name,
		})
	return {"ok": true}


func is_attacking(attacker_id: int) -> bool:
	return _sessions.has(attacker_id)


func current_target_of(attacker_id: int) -> int:
	if not _sessions.has(attacker_id):
		return -1
	return int((_sessions[attacker_id] as Dictionary).get("target_id", -1))


# --------------------------------------------------------------------------
# Boucle d'arbitrage
# --------------------------------------------------------------------------

## Avance l'horloge de l'autorite et resout les coups arrives a echeance.
## Retourne les evenements produits pendant cet appel.
func advance(delta_seconds: float) -> Array:
	var produced: Array = []
	if not booted or mirror_mode:
		return produced
	_clock_msec += maxf(0.0, delta_seconds) * 1000.0
	produced.append_array(_advance_spell_casts())
	produced.append_array(_advance_spell_effects())

	# Copie des cles : une mort peut retirer une session en cours d'iteration.
	for attacker_id in _sessions.keys().duplicate():
		if not _sessions.has(attacker_id):
			continue
		var session: Dictionary = _sessions[attacker_id] as Dictionary
		if _clock_msec < float(session.get("next_swing_msec", 0.0)):
			continue
		var event: Dictionary = _resolve_swing(int(attacker_id), session)
		if not event.is_empty():
			produced.append(event)
	# P1-22D — les cervelles decident APRES les coups : une creature qui vient de
	# mourir ne prend pas une decision dans la meme trame.
	produced.append_array(_advance_brains(maxf(0.0, delta_seconds)))
	_advance_pets(maxf(0.0, delta_seconds))
	_advance_realm_abilities()
	# P1-22B — les cadavres et les reapparitions avancent en dernier : une
	# creature tuee a l'instant ne peut pas revenir dans le meme appel, meme
	# avec un delai nul.
	produced.append_array(_advance_world())
	# P1-23C — LA REGENERATION EN DERNIER, ET APRES LES REAPPARITIONS. Une
	# creature qui vient de revenir est deja en pleine sante : la faire
	# regenerer dans la meme trame ne veut rien dire. Elle n'emet aucun
	# evenement de combat — un journal qui annoncerait chaque point de vie
	# regagne serait illisible — mais elle previent l'interface.
	_advance_regeneration()
	return produced


## P1-23C — les trois regenerations de `GameLiving`.
##
## CE QUI EST PORTE : les taux (`HealthRegenerationRateCalculator`,
## `PowerRegenerationRateCalculator`, `EnduranceRegenerationRateCalculator`), les
## trois periodes, et le ralentissement en combat.
##
## CE QUI NE L'EST PAS, et qui est dit : DOL tire la partie decimale au sort
## (`Util.ChanceDouble`) pour compenser l'arrondi entier. Un tirage libre ferait
## diverger deux sessions rejouees, ce que l'arbitre local s'interdit depuis
## P1-21A. La decimale est donc resolue par un tirage DETERMINISTE, graine de
## session plus numero de tic — meme session, memes points de vie.
##
## UN MORT NE REGENERE PAS, et une creature au maximum ne declenche aucun tic :
## DOL arrete son minuteur dans les deux cas.
func _advance_regeneration() -> void:
	if not regeneration_enabled:
		return
	for key in _states.keys():
		var object_id: int = int(key)
		var state: DaocCombatEntityState = _states[key] as DaocCombatEntityState
		if state == null or not state.is_alive:
			continue
		var timers: Dictionary = _regen_next_msec.get(object_id, {}) as Dictionary
		var changed := false

		if state.health < state.max_health:
			var next_health: float = float(timers.get("health", 0.0))
			if _clock_msec >= next_health:
				var rate: float = DolFormulas.health_regen_per_tick(
					state.level, state.in_combat, not state.is_player, state.is_diseased
				)
				var gained: int = _resolve_regen_amount(rate, object_id, 11)
				if gained > 0:
					state.change_health(gained)
					changed = true
				timers["health"] = _clock_msec + float(DolFormulas.health_regen_interval_msec(state.in_combat))
		else:
			# DEFAUT ATTRAPE PAR LA SUITE P1-21A, et il faisait du bruit : poser
			# l'echeance a MAINTENANT quand la jauge est pleine la rend echue,
			# donc le premier point perdu etait rendu a la trame suivante — la
			# regeneration devenait instantanee et le joueur ne baissait jamais.
			# DOL ARRETE SON MINUTEUR a plein et le REDEMARRE quand la jauge
			# bouge : le premier tic coute donc une periode entiere.
			timers["health"] = _clock_msec + float(DolFormulas.health_regen_interval_msec(state.in_combat))

		if state.max_mana > 0 and state.mana < state.max_mana:
			var next_power: float = float(timers.get("power", 0.0))
			if _clock_msec >= next_power:
				var power_rate: float = DolFormulas.power_regen_per_tick(
					state.level, state.in_combat, not state.is_player
				)
				var power_gained: int = _resolve_regen_amount(power_rate, object_id, 23)
				if power_gained > 0:
					state.mana = clampi(state.mana + power_gained, 0, state.max_mana)
					changed = true
				timers["power"] = _clock_msec + float(DolFormulas.power_regen_interval_msec(state.in_combat))
		else:
			timers["power"] = _clock_msec + float(DolFormulas.power_regen_interval_msec(state.in_combat))

		if state.max_endurance > 0 and state.endurance < state.max_endurance:
			var next_endurance: float = float(timers.get("endurance", 0.0))
			if _clock_msec >= next_endurance:
				var endurance_rate: float = DolFormulas.endurance_regen_per_tick(
					state.is_player, state.in_combat, false
				)
				var endurance_gained: int = _resolve_regen_amount(endurance_rate, object_id, 37)
				if endurance_gained > 0:
					state.endurance = clampi(state.endurance + endurance_gained, 0, state.max_endurance)
					changed = true
				timers["endurance"] = _clock_msec + float(DolFormulas.ENDURANCE_REGEN_PERIOD_MSEC)
		else:
			timers["endurance"] = _clock_msec + float(DolFormulas.ENDURANCE_REGEN_PERIOD_MSEC)

		_regen_next_msec[object_id] = timers
		if changed:
			state_changed.emit(object_id, snapshot(object_id))


## La partie entiere du taux, plus la decimale resolue par un tirage
## DETERMINISTE. C'est le seul endroit ou l'arbitre s'ecarte de DOL, et il le
## fait pour tenir une promesse plus ancienne : une session rejouee rend les
## memes chiffres.
func _resolve_regen_amount(rate: float, object_id: int, salt: int) -> int:
	if rate <= 0.0:
		return 0
	var whole: int = int(rate)
	var fraction: float = rate - float(whole)
	if fraction > 0.0:
		_regen_tick_counter += 1
		var seed_value: int = seed_base + object_id * 7919 + _regen_tick_counter
		var roll: int = DaocAttackComponent.deterministic_roll(seed_value, salt, 1000)
		if float(roll) < fraction * 1000.0:
			whole += 1
	return whole


func _resolve_swing(attacker_id: int, session: Dictionary) -> Dictionary:
	var target_id: int = int(session.get("target_id", -1))
	var attacker: DaocCombatEntityState = _states.get(attacker_id) as DaocCombatEntityState
	var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
	if attacker == null or target == null or not attacker.is_alive:
		_sessions.erase(attacker_id)
		return {}
	if not target.is_alive:
		_sessions.erase(attacker_id)
		return {}

	var interval: float = float(session.get("interval_msec", 2500))
	session["next_swing_msec"] = _clock_msec + interval

	# Portee : horizontale seulement. Les Z de la capture et ceux du joueur
	# recale au terrain ne vivent pas dans le meme contrat (cf. P1-20G-H2), donc
	# les comparer verticalement produirait de faux hors-portee.
	var distance: float = _horizontal_distance(attacker_id, target_id)
	if distance > melee_range_raw:
		var out_of_range: Dictionary = {
			"kind": "out_of_range",
			"attacker_id": attacker_id,
			"target_id": target_id,
			"distance_raw": distance,
			"text": "%s est trop loin (%.0f)." % [target.name, distance],
		}
		_emit_event(out_of_range)
		return out_of_range

	_swing_counter += 1
	session["swings"] = int(session.get("swings", 0)) + 1
	var weapon: Dictionary = (_meta.get(attacker_id, {}) as Dictionary).get("weapon", {}) as Dictionary
	# P1-31 — le style arme vaut pour CE coup et disparait, qu'il porte ou non.
	# Un style rate coute quand meme la moitie de son endurance dans DOL : le
	# rendre a l'attaquant serait un cadeau que la regle ne fait pas.
	var pending_style: DaocStyleDef = _take_pending_style(attacker_id) if styles_enabled else null
	var attack: DaocAttackData = DaocMeleeExchange.resolve(attacker, target, weapon, {
		"style": pending_style,
		"seed": seed_base + _swing_counter * 7919 + attacker_id,
		"interval": int(interval),
		"attack_type": DaocCombatEnums.ATTACK_MELEE_ONE_HAND,
		"use_dol_formulas": use_dol_formulas,
		# P1-24 — L'ARMURE DE LA CIBLE, quand elle en porte une. Elle vit dans le
		# meta et non dans l'etat : c'est de l'equipement, pas une statistique.
		"target_armor": (_meta.get(target_id, {}) as Dictionary).get("armor", {}),
		# P1-25 — LE BOUCLIER DE LA CIBLE. Sans lui, la chance de blocage vaut
		# zero : DOL exige un bouclier en main gauche pour qu un joueur bloque.
		"target_shield": (_meta.get(target_id, {}) as Dictionary).get("shield", {}),
	})

	var total: int = attack.total_damage() if attack.is_hit() else 0
	# P1-123 : ResurrectionIllnessECSGameEffect retire Value % d efficacite ;
	# l arbitre l applique aux degats de melee (propriete « Effectiveness »).
	var effectiveness := 1.0 + attacker.get_modified("Effectiveness", 0.0) * 0.01
	if total > 0 and effectiveness < 1.0:
		total = maxi(1, int(float(total) * maxf(0.0, effectiveness)))
	# P1-125 : Adrenaline Rush (+Value % en melee), Anger of the Gods (ajout de
	# degats par seconde de l arme), Barrier of Fortitude (-Value % recus).
	if total > 0:
		total = int(float(total) * (1.0 + _effect_value(attacker_id, "adrenaline_rush") * 0.01))
		total += int(_effect_value(attacker_id, "damage_add") * interval / 1000.0)
		total = maxi(1, int(float(total) * (1.0 - _effect_value(target_id, "damage_decrease") * 0.01)))
	# P1-123 : le style se PAIE (StyleProcessor.cs:373) — plein tarif s il
	# porte, moitie s il echoue — x FatigueConsumption (100 % + debuffs).
	if pending_style != null:
		var fatigue := int(100.0 + attacker.get_modified("FatigueConsumption", 0.0))
		var style_cost := DolFormulas.style_endurance_cost(int(weapon.get("SPD_ABS", 0)), pending_style.endurance_cost, fatigue)
		if attack.attack_result != DaocCombatEnums.RESULT_HIT_STYLE:
			style_cost = DolFormulas.failed_style_endurance_cost(style_cost)
		attacker.endurance = maxi(0, attacker.endurance - style_cost)
	if total > 0:
		target.change_health(-total)
		interrupt_spell_cast(target_id, "degats recus")
	var event: Dictionary = {
		"kind": "swing",
		"attacker_id": attacker_id,
		"target_id": target_id,
		"attacker": attacker.name,
		"target": target.name,
		"result": attack.attack_result,
		"damage": total,
		"damage_type": attack.damage_type,
		"distance_raw": distance,
		"target_health": target.health,
		"target_max_health": target.max_health,
		"text": _swing_text(attacker, target, attack, total),
	}
	# P1-31 — le coup DIT s'il portait un style, et ce que le style a rendu.
	if pending_style != null:
		_styles_executed += 1
		event["style_name"] = pending_style.name
		# P1-133 — ce que le 0xBC porterait : Style.Icon, ou TwoHandAnimation
		# avec une arme a deux mains (StyleProcessor.cs, Hand == 1).
		var anim_id := pending_style.animation_id
		if int(weapon.get("Hand", weapon.get("hand", 0))) == 1 and pending_style.two_hand_animation > 0:
			anim_id = pending_style.two_hand_animation
		event["style"] = anim_id
		event["style_damage"] = attack.style_damage
		# LE SEUIL DE 15 DPS EST LE PIEGE DE CE JALON, et il doit etre ANNONCE.
		# En dessous, `absorbRatio` vaut zero et les degats de style s'annulent :
		# l'epee d'entrainement de P1-24 a un DPS de 12, donc un personnage de
		# depart execute ses styles, en paye l'endurance, et ne gagne RIEN. C'est
		# la regle de DOL. Un joueur qui verrait « rien » sans explication
		# chercherait un bug qui n'existe pas - et le prochain agent aussi.
		var below: bool = int(weapon.get("DPS_AF", 0)) < DolFormulas.STYLE_MIN_WEAPON_DPS
		event["style_below_dps_threshold"] = below
		if below:
			event["text"] += " (%s : sans effet, arme sous %d de DPS)" % [
				pending_style.name, DolFormulas.STYLE_MIN_WEAPON_DPS]
		elif attack.style_damage > 0:
			event["text"] += " (%s : +%d)" % [pending_style.name, attack.style_damage]
	_last_attack[attacker_id] = attack
	_emit_event(event)
	_wear_player_items(attacker_id, target_id, attack)
	_fire_procs(attacker_id, target_id, attack, pending_style)
	state_changed.emit(target_id, snapshot(target_id))

	if retaliation_enabled and not target.is_player and target.is_alive and not _sessions.has(target_id):
		# Riposte sur place : le PNJ rend les coups mais ne se deplace pas.
		# L'aggro et l'approche sont le chantier suivant.
		request_attack(target_id, attacker_id)

	if not target.is_alive:
		_handle_death(target_id, attacker_id)
	return event


func _handle_death(dead_id: int, killer_id: int) -> void:
	var dead: DaocCombatEntityState = _states.get(dead_id) as DaocCombatEntityState
	if dead == null:
		return
	dead.is_alive = false
	dead.health = 0
	dead.in_combat = false
	_sessions.erase(dead_id)
	for attacker_id in _sessions.keys().duplicate():
		var session: Dictionary = _sessions[attacker_id] as Dictionary
		if int(session.get("target_id", -1)) == dead_id:
			_sessions.erase(attacker_id)
			var attacker: DaocCombatEntityState = _states.get(attacker_id) as DaocCombatEntityState
			if attacker != null:
				attacker.in_combat = _is_targeted_by_anyone(attacker_id)
	var killer: DaocCombatEntityState = _states.get(killer_id) as DaocCombatEntityState
	_deaths_resolved += 1
	_emit_event({
		"kind": "death",
		"target_id": dead_id,
		"attacker_id": killer_id,
		"text": "%s meurt%s." % [dead.name, "" if killer == null else " sous les coups de %s" % killer.name],
	})
	entity_died.emit(dead_id, snapshot(dead_id))
	# L'ORDRE COMPTE : la mort est annoncee d'abord. Un client qui joue une
	# animation de mort doit la recevoir avant le gain d'experience, sinon le
	# journal de combat annonce la recompense avant le coup fatal.
	_award_experience(killer_id, dead_id)
	_open_corpse(dead_id, killer_id)


## L'experience du tueur.
##
## RESERVE AUX PERSONNAGES. Un PNJ qui tue un autre PNJ ne gagne rien : dans DAoC
## la progression est le fait des joueurs, et compter l'experience d'un garde
## remplirait la table pour personne.
##
## Un gris ne rapporte RIEN — c'est la regle de couleur qui le decide, et le
## rapport garde la couleur pour que le journal puisse le dire.
func _award_experience(killer_id: int, dead_id: int) -> void:
	if not experience_enabled:
		return
	var killer: DaocCombatEntityState = _states.get(killer_id) as DaocCombatEntityState
	var dead: DaocCombatEntityState = _states.get(dead_id) as DaocCombatEntityState
	if killer == null or dead == null or not killer.is_player or dead.is_player:
		return
	var purse: Dictionary = _experience.get(killer_id, {
		"total": ExperienceRules.experience_for_level(killer.level, use_dol_formulas), "level": killer.level,
	}) as Dictionary
	var award: Dictionary = ExperienceRules.kill_experience(killer.level, dead.level, {"use_dol_formulas": use_dol_formulas})
	var applied: Dictionary = ExperienceRules.apply_gain(
		int(purse.get("total", 0)), int(purse.get("level", killer.level)), int(award.get("amount", 0)))
	_experience[killer_id] = {"total": int(applied["total_experience"]), "level": int(applied["level"])}

	var report: Dictionary = {
		"object_id": killer_id,
		"victim_id": dead_id,
		"victim_name": dead.name,
		"gained": int(applied["gained"]),
		"total_experience": int(applied["total_experience"]),
		"level": int(applied["level"]),
		"levels_gained": applied["levels_gained"],
		"to_next_level": int(applied["to_next_level"]),
		"con": str(award.get("con", "")),
		"con_factor": float(award.get("con_factor", 0.0)),
		"basis": str(award.get("basis", "")),
	}
	if int(applied["gained"]) > 0:
		_emit_event({
			"kind": "experience",
			"attacker_id": killer_id,
			"target_id": dead_id,
			"text": "Vous gagnez %d points d'experience (%s)." % [int(applied["gained"]), str(award.get("con", ""))],
		})
	else:
		# Le silence serait pire que le message : le joueur croirait a un bug.
		_emit_event({
			"kind": "experience",
			"attacker_id": killer_id,
			"target_id": dead_id,
			"text": "%s ne vaut plus aucune experience pour vous." % dead.name,
		})
	experience_gained.emit(killer_id, report)

	var levels: Array = applied["levels_gained"] as Array
	if not levels.is_empty():
		killer.level = int(applied["level"])
		for level in levels:
			_emit_event({
				"kind": "level",
				"attacker_id": killer_id,
				"target_id": killer_id,
				"text": "Vous atteignez le niveau %d." % int(level),
			})
			level_gained.emit(killer_id, int(level), report)


## Ouvre un cadavre : deux echeances, jamais une seule.
##
## Le corps s'efface a `corpse_decay_seconds`, la creature revient a son delai
## de reapparition — qui est PLUS LONG. Confondre les deux ferait disparaitre le
## cadavre et le mob au meme instant, ce qui se lit comme une teleportation.
func _open_corpse(dead_id: int, killer_id: int) -> void:
	var record: Dictionary = _spawn_records.get(dead_id, {}) as Dictionary
	var respawn_seconds: float = float(record.get("respawn_seconds", default_respawn_seconds))
	_corpses[dead_id] = {
		"died_msec": _clock_msec,
		"killer_id": killer_id,
		"decay_msec": _clock_msec + maxf(0.0, corpse_decay_seconds) * 1000.0,
		"respawn_msec": _clock_msec + maxf(0.0, respawn_seconds) * 1000.0,
		"respawn_basis": str(record.get("respawn_basis", "PLACEHOLDER")),
		"decayed": false,
		"loot": _roll_loot(dead_id),
	}
	var loot: Dictionary = (_corpses[dead_id] as Dictionary).get("loot", {}) as Dictionary
	if not loot.is_empty():
		corpse_loot_ready.emit(dead_id, loot.duplicate(true))


## P1-22D — les creatures reperent, poursuivent, frappent et rentrent.
##
## UNE SEULE CIBLE POSSIBLE POUR L'INSTANT : le joueur. Ce n'est pas une
## simplification cachee mais le perimetre du jalon — un PNJ agressif envers un
## autre PNJ demanderait les FACTIONS, que `factionaggrolevel.sql` porte et que
## personne n'a encore lues. Le jour venu, seule `_aggro_candidate_for` change.
func _advance_brains(delta_seconds: float) -> Array:
	var produced: Array = []
	if not npc_ai_enabled or delta_seconds <= 0.0:
		return produced

	for key in _states.keys():
		var object_id: int = int(key)
		if object_id == player_object_id:
			continue
		var state: DaocCombatEntityState = _states[object_id] as DaocCombatEntityState
		if state == null or not state.is_alive or state.is_player:
			continue
		if _pets.has(object_id):
			continue
		var profile: Dictionary = mob_db_profile(object_id)
		var brain: Dictionary = _brains.get(object_id, {"state": NpcBrain.STATE_IDLE, "target_id": -1}) as Dictionary
		var previous_state: String = str(brain.get("state", NpcBrain.STATE_IDLE))

		# Une creature deja engagee garde SA cible ; au repos, elle cherche.
		var target_id: int = int(brain.get("target_id", -1))
		if previous_state == NpcBrain.STATE_IDLE:
			target_id = _aggro_candidate_for(object_id, profile)
		var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
		var spawn: Vector3 = ((_spawn_records.get(object_id, {}) as Dictionary)
			.get("world_position", _positions.get(object_id, Vector3.ZERO))) as Vector3

		var decision: Dictionary = NpcBrain.decide({
			"profile": profile,
			"state": previous_state,
			"has_target": target != null,
			"target_alive": target != null and target.is_alive,
			"distance_to_target_raw": INF if target == null else _horizontal_distance(object_id, target_id),
			"distance_to_spawn_raw": _flat_distance(_positions.get(object_id, Vector3.ZERO) as Vector3, spawn),
			"melee_range_raw": melee_range_raw,
		})
		var new_state: String = str(decision.get("state", NpcBrain.STATE_IDLE))
		var intent: String = str(decision.get("intent", "wait"))

		match intent:
			"approach":
				_step_creature(object_id, _positions.get(target_id, Vector3.ZERO) as Vector3, profile, delta_seconds)
				_aggro_triggered += 1 if previous_state == NpcBrain.STATE_IDLE else 0
			"engage":
				if not _sessions.has(object_id):
					request_attack(object_id, target_id)
			"disengage":
				stop_attack(object_id)
				target_id = -1
				if str(decision.get("reason", "")) == "laisse":
					_leash_returns += 1
			"return":
				_step_creature(object_id, spawn, profile, delta_seconds)
			"arrived":
				# Rentree chez elle, une creature repart en pleine sante : c'est
				# la regle de DAoC, et sans elle un joueur userait un mob par
				# allers-retours successifs.
				state.health = state.max_health
				target_id = -1

		brain["state"] = new_state
		brain["target_id"] = target_id
		_brains[object_id] = brain
		if new_state != previous_state:
			var event: Dictionary = {
				"kind": "brain", "target_id": object_id, "attacker_id": target_id,
				"text": "%s : %s." % [state.name, new_state],
			}
			produced.append(event)
			brain_state_changed.emit(object_id, new_state, str(decision.get("reason", "")))
	return produced


## La cible qu'une creature agressive vient de reperer, ou -1.
##
## SEULEMENT LE JOUEUR, et seulement s'il est vivant et dans la portee que la
## base declare. Une creature pacifique — `AggroLevel` a zero, ce qui est le cas
## de la quasi-totalite des PNJ de ville — ne repere jamais personne.
func _aggro_candidate_for(object_id: int, profile: Dictionary) -> int:
	if not NpcBrain.is_aggressive(profile) or player_object_id < 0:
		return -1
	var player: DaocCombatEntityState = _states.get(player_object_id) as DaocCombatEntityState
	if player == null or not player.is_alive:
		return -1
	if _horizontal_distance(object_id, player_object_id) > NpcBrain.aggro_range_of(profile):
		return -1
	return player_object_id


## Avance une creature d'un pas vers un point, et l'annonce.
##
## L'ALTITUDE N'EST PAS CALCULEE ICI : l'arbitre ne connait pas le relief. Le
## client, qui sait echantillonner le sol, repose la creature dessus. Un serveur
## qui deciderait du `z` ferait voler ses mobs au-dessus des pentes.
func _step_creature(object_id: int, towards: Vector3, profile: Dictionary, delta_seconds: float) -> void:
	var from: Vector3 = _positions.get(object_id, Vector3.ZERO) as Vector3
	var speed: Dictionary = NpcBrain.speed_of(profile)
	# P1-123 : un ralentissement (SpeedDecrease, PreventFlight) multiplie la
	# vitesse par 1 - Value % (StatDebuffECSEffect : MaxSpeed x (1 - v / 100)).
	var speed_raw := float(speed.get("speed_raw", 0.0)) * snare_speed_factor(object_id)
	var moved: Vector3 = NpcBrain.step_towards(from, towards, speed_raw, delta_seconds)
	if moved.is_equal_approx(from):
		return
	_positions[object_id] = moved
	entity_moved.emit(object_id, moved)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


## L'humeur d'une creature : son etat et sa cible. Vide si elle n'a jamais
## decide quoi que ce soit.
func brain_report(object_id: int) -> Dictionary:
	if not _brains.has(object_id):
		return {}
	var brain: Dictionary = (_brains[object_id] as Dictionary).duplicate(true)
	brain["object_id"] = object_id
	brain["profile"] = mob_db_profile(object_id)
	brain["leash_raw"] = NpcBrain.leash_of(brain["profile"] as Dictionary)
	return brain


## Tire le contenu d'un cadavre. DETERMINISTE : la graine combine celle de la
## session et l'identifiant du mort, donc rejouer la meme session redonne le
## meme butin — sans quoi aucun defaut de butin ne serait reproductible.
##
## L'ARGENT TOMBE TOUJOURS, les objets seulement si le mob a une vraie table.
## Sur les 28 tables citees par les PNJ de la capture, QUATRE existent : un
## cadavre sans objet est donc le cas NORMAL ici, pas un echec de tirage.
func _roll_loot(dead_id: int) -> Dictionary:
	if not loot_enabled:
		return {}
	var state: DaocCombatEntityState = _states.get(dead_id) as DaocCombatEntityState
	if state == null or state.is_player:
		return {}
	_loot_rolls += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:loot" % [seed_base, dead_id])

	var money: Dictionary = LootRules.money_for_kill(state.level, rng.randf(), use_dol_formulas)
	var loot := {
		"object_id": dead_id,
		"copper": int(money.get("copper", 0)),
		"money_basis": str(money.get("basis", "")),
		"items": [],
		"has_table": false,
		"taken": false,
	}
	var profile: Dictionary = mob_db_profile(dead_id)
	var names: Array = profile.get("loot_templates", []) as Array
	if _loot_index != null and not names.is_empty():
		loot["has_table"] = bool(_loot_index.has_any_table(names))
		var rolled: Dictionary = LootRules.roll_table(names, _loot_index.templates(), _loot_index.items(), rng)
		loot["items"] = rolled.get("items", [])
		loot["considered"] = int(rolled.get("considered", 0))
		loot["skipped_unknown_items"] = int(rolled.get("skipped_unknown_items", 0))
		loot["skipped_negative_chance"] = int(rolled.get("skipped_negative_chance", 0))
	return loot


## Ce qu'un cadavre contient, sans y toucher. Vide si le corps n'existe pas,
## s'est dissipe, ou a deja ete pille.
func corpse_loot(object_id: int) -> Dictionary:
	if not is_corpse(object_id):
		return {}
	var loot: Dictionary = (_corpses[object_id] as Dictionary).get("loot", {}) as Dictionary
	if loot.is_empty() or bool(loot.get("taken", false)):
		return {}
	return loot.duplicate(true)


## Prend le contenu d'un cadavre.
##
## L'AUTORITE REFUSE, elle ne se contente pas d'ignorer : un corps dissipe, deja
## pille, hors de portee ou appartenant a un autre rend une raison. Le client ne
## decide de rien — c'est la meme regle que `request_attack`.
func loot_corpse(taker_id: int, object_id: int) -> Dictionary:
	if mirror_mode:
		return {"ok": false, "reason": "autorite distante : butin non branche (B8)"}
	if not loot_enabled:
		return {"ok": false, "reason": "butin desactive"}
	if not _states.has(taker_id):
		return {"ok": false, "reason": "pilleur inconnu"}
	if not _corpses.has(object_id):
		return {"ok": false, "reason": "aucun cadavre"}
	var corpse: Dictionary = _corpses[object_id] as Dictionary
	if bool(corpse.get("decayed", false)):
		return {"ok": false, "reason": "le corps s'est dissipe"}
	var loot: Dictionary = corpse.get("loot", {}) as Dictionary
	if loot.is_empty():
		return {"ok": false, "reason": "corps vide"}
	if bool(loot.get("taken", false)):
		return {"ok": false, "reason": "deja pille"}
	var distance: float = _horizontal_distance(taker_id, object_id)
	if distance > melee_range_raw:
		return {"ok": false, "reason": "trop loin", "distance_raw": distance}

	loot["taken"] = true
	corpse["loot"] = loot
	_corpses[object_id] = corpse
	_purses[taker_id] = int(_purses.get(taker_id, 0)) + int(loot.get("copper", 0))

	var taken: Dictionary = loot.duplicate(true)
	var items: Array = taken.get("items", []) as Array
	var text: String = "Vous ramassez %s" % LootRules.money_text(int(taken.get("copper", 0)))
	if not items.is_empty():
		var names: Array = []
		for item in items:
			names.append(str((item as Dictionary).get("name", "?")))
		text += " et %s" % ", ".join(names)
	_emit_event({
		"kind": "loot", "attacker_id": taker_id, "target_id": object_id, "text": text + ".",
	})
	loot_taken.emit(object_id, taker_id, taken)
	return {"ok": true, "loot": taken, "purse_copper": int(_purses.get(taker_id, 0))}


## La bourse d'une entite, en cuivre et decoupee par denomination.
func purse(object_id: int) -> Dictionary:
	var copper: int = int(_purses.get(object_id, 0))
	var split: Dictionary = LootRules.split_money(copper)
	split["object_id"] = object_id
	split["text"] = LootRules.money_text(copper)
	return split


## Fait avancer cadavres et reapparitions. Appele par `advance`, jamais seul :
## l'horloge de l'autorite est la seule qui compte.
func _advance_world() -> Array:
	var produced: Array = []
	if not respawn_enabled:
		return produced
	for key in _corpses.keys().duplicate():
		var object_id: int = int(key)
		var corpse: Dictionary = _corpses[object_id] as Dictionary
		if not bool(corpse.get("decayed", false)) and _clock_msec >= float(corpse.get("decay_msec", 0.0)):
			corpse["decayed"] = true
			_corpses[object_id] = corpse
			var decay_event: Dictionary = {
				"kind": "corpse_decay", "target_id": object_id, "attacker_id": -1,
				"text": "Le corps se dissipe.",
			}
			_emit_event(decay_event)
			produced.append(decay_event)
			corpse_decayed.emit(object_id, snapshot(object_id))
		if _clock_msec >= float(corpse.get("respawn_msec", 0.0)):
			var event: Dictionary = _respawn(object_id)
			if not event.is_empty():
				produced.append(event)
	return produced


## Remet une creature debout a son point d'apparition.
##
## Le retrait d'une entite par le flux R3 efface aussi son cadavre : une
## creature qui n'existe plus ne revient pas. C'est pourquoi on verifie encore
## `_states` ici, et non seulement a l'ouverture du cadavre.
func _respawn(object_id: int) -> Dictionary:
	_corpses.erase(object_id)
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {}
	var record: Dictionary = _spawn_records.get(object_id, {}) as Dictionary
	state.is_alive = true
	state.health = int(record.get("max_health", state.max_health))
	state.max_health = maxi(1, int(record.get("max_health", state.max_health)))
	state.in_combat = false
	if record.has("world_position"):
		_positions[object_id] = record["world_position"] as Vector3
	_respawns_resolved += 1
	var event: Dictionary = {
		"kind": "respawn", "target_id": object_id, "attacker_id": -1,
		"text": "%s reapparait." % state.name,
	}
	_emit_event(event)
	entity_respawned.emit(object_id, snapshot(object_id))
	return event


func _swing_text(attacker: DaocCombatEntityState, target: DaocCombatEntityState, attack: DaocAttackData, total: int) -> String:
	match attack.attack_result:
		DaocCombatEnums.RESULT_MISSED:
			return "%s manque %s." % [attacker.name, target.name]
		DaocCombatEnums.RESULT_FUMBLED:
			return "%s rate son coup." % attacker.name
		DaocCombatEnums.RESULT_BLOCKED:
			return "%s bloque le coup de %s." % [target.name, attacker.name]
		DaocCombatEnums.RESULT_PARRIED:
			return "%s pare le coup de %s." % [target.name, attacker.name]
		DaocCombatEnums.RESULT_EVADED:
			return "%s esquive le coup de %s." % [target.name, attacker.name]
		_:
			return "%s touche %s pour %d." % [attacker.name, target.name, total]


# --------------------------------------------------------------------------
# Lecture
# --------------------------------------------------------------------------

func has_entity(object_id: int) -> bool:
	return _states.has(object_id)


func get_state(object_id: int) -> DaocCombatEntityState:
	return _states.get(object_id) as DaocCombatEntityState


func get_node_for(object_id: int) -> Node3D:
	return _nodes.get(object_id) as Node3D


## Le meta d'une entite — equipement, provenances, drapeaux — en COPIE.
##
## Il vit a cote de l'etat et non dedans : une arme et une armure sont de
## l'EQUIPEMENT, pas des statistiques. La copie est deliberee ; laisser modifier
## le meta par reference ferait entrer des regles par la porte de service.
func entity_meta(object_id: int) -> Dictionary:
	return (_meta.get(object_id, {}) as Dictionary).duplicate(true)


## Change l'arme d'une entite. LE SEUL CHEMIN, et il passe par l'arbitre.
##
## P1-24 equipe la panoplie de depart au demarrage ; changer d'arme en cours de
## partie n'existait pas, faute de marchand et de sac. Ce point d'entree existe
## pour les outils et les suites, et le jour ou un marchand arrivera il passera
## par ici — jamais par le client, qui ne doit pas decider de ce qu'on porte.
func set_entity_weapon(object_id: int, weapon: Dictionary) -> bool:
	if not _meta.has(object_id):
		return false
	var meta: Dictionary = _meta[object_id] as Dictionary
	meta["weapon"] = weapon.duplicate(true)
	_meta[object_id] = meta
	return true


# ============================================================================
# P1-93 — L'INVENTAIRE. Le joueur ne porte que ce qu'il a equipe depuis son sac.
#
# Avant : la scene du Lab etait cuite « deja equipee » et `player_state_from_capture`
# posait l'epee et l'armure du metier comme portees. Le sac n'existait pas.
# Maintenant : la panoplie de depart entre dans le SAC ; equiper et retirer
# passent par ICI, et c'est cet arbitre qui recalcule l'arme, l'armure et le
# bouclier qui comptent dans `DaocMeleeExchange`. Le client n'en decide pas.
#
# `starter_kit_auto_equip` (vrai par defaut) reproduit P1-24 : la panoplie est
# portee au demarrage et l'arme/armure/bouclier de Vitals — avec sa borne du
# gris — restent tels quels. La scene de jeu le met a FAUX.
# ============================================================================

func _install_player_inventory() -> void:
	if not inventory_enabled or player_object_id < 0:
		return
	_player_inventory = PlayerInventoryScript.new()
	var seeded: Dictionary = _player_inventory.seed_starter_kit(player_class_id, starter_kit_auto_equip)
	var meta: Dictionary = _meta.get(player_object_id, {}) as Dictionary
	meta["inventory_seed"] = seeded
	_meta[player_object_id] = meta
	if not starter_kit_auto_equip:
		_apply_player_equipment()
	player_inventory_changed.emit(_player_inventory.snapshot())


## Traduit l'equipement PORTE en arme/armure/bouclier de combat. Rien de porte
## = mains nues, sans armure : la chaine de degats prend la branche GameLiving
## et le declare (`DOL_CODE_LIVING_BRANCH`), et l'armure absorbe zero.
func _apply_player_equipment() -> void:
	if _player_inventory == null or player_object_id < 0 or not _meta.has(player_object_id):
		return
	var meta: Dictionary = _meta[player_object_id] as Dictionary
	var weapon_item: Dictionary = _player_inventory.active_weapon()
	meta["weapon"] = VitalsScript.weapon_from_item(weapon_item) if not weapon_item.is_empty() else {}
	meta["armor"] = _player_inventory.armor_by_slot()
	meta["shield"] = _player_inventory.shield()
	meta["equipment_source"] = "PLAYER_INVENTORY"
	_meta[player_object_id] = meta


func player_inventory_snapshot() -> Dictionary:
	if _player_inventory == null:
		return {"revision": 0, "source": "none", "slots": {}, "equipped": {}, "backpack": [], "weapon": {}, "shield": {}}
	return _player_inventory.snapshot()


## Le client demande a equiper l'objet d'un logement du sac.
func request_equip(from_slot: int) -> Dictionary:
	if _player_inventory == null:
		return {"ok": false, "reason": "inventaire absent"}
	if mirror_mode:
		return {"ok": false, "reason": "en miroir, l'equipement est celui du serveur"}
	var result: Dictionary = _player_inventory.equip_from_backpack(from_slot)
	if bool(result.get("ok", false)):
		_apply_player_equipment()
		player_inventory_changed.emit(_player_inventory.snapshot())
		state_changed.emit(player_object_id, snapshot(player_object_id))
	return result


## Le client demande a retirer un objet porte vers le sac.
func request_unequip(slot: int) -> Dictionary:
	if _player_inventory == null:
		return {"ok": false, "reason": "inventaire absent"}
	if mirror_mode:
		return {"ok": false, "reason": "en miroir, l'equipement est celui du serveur"}
	var result: Dictionary = _player_inventory.unequip(slot)
	if bool(result.get("ok", false)):
		_apply_player_equipment()
		player_inventory_changed.emit(_player_inventory.snapshot())
		state_changed.emit(player_object_id, snapshot(player_object_id))
	return result


## ═══════════════════════════════════════════════════════════════════════════
## P1-123 — LES PROCS, fideles a OpenDAoC (ProcSpellHandler, StyleProcessor,
## AttackComponent). Jusqu'ici un OffensiveProc posait son effet et ne
## partait JAMAIS : l'arbitre n'avait aucun declencheur.
##   - offensif : sur un coup porte (HitUnstyled / HitStyle) par le porteur,
##     Frequency / 100 % de chance, sous-sort Value sur la cible (ENEMY) ou
##     sur soi ; « PvE » seulement contre un PNJ ;
##   - defensif : sur un coup RECU, sous-sort sur l'attaquant (ENEMY) ou sur soi ;
##   - procs de style : apres un coup de style reussi, chaque proc de la classe
##     du joueur (ou du style, ou 0 — la classe exacte l'emporte) tire sa
##     chance ; MultiTarget frappe Value cibles de plus a portee de melee,
##     NaturesShield bloque les sorts tant que le style est ARME.
## Les tirages sont deterministes (graine de session + coup + rang).
## ═══════════════════════════════════════════════════════════════════════════
var procs_fired := 0
## P1-123 : le point de lien du joueur (sa position a l entree en jeu).
signal player_moved_to_bind(world_position: Vector3, region: int)
var player_bind_position := Vector3.INF
var player_bind_region := 51
## P1-123 : les sorts ennemis peuvent etre resistes (decoche = ancien toujours-touche).
var spell_resists_enabled := true
var spells_resisted := 0
var _spell_resist_rolls := 0
var extra_targets_hit := 0
var natures_shield_blocks := 0
var _proc_roll_counter := 0


func _proc_roll(chance_percent: float, salt: int) -> bool:
	_proc_roll_counter += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + _swing_counter * 7907 + _proc_roll_counter * 31 + salt
	return rng.randf() * 100.0 < chance_percent


func _fire_procs(attacker_id: int, target_id: int, attack: DaocAttackData, style: DaocStyleDef) -> void:
	var hit := attack.attack_result in [DaocCombatEnums.RESULT_HIT_UNSTYLED, DaocCombatEnums.RESULT_HIT_STYLE]
	if not hit:
		return
	var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
	for value in _active_spell_effects.duplicate():
		var effect := value as Dictionary
		var owner_id := int(effect.get("target_id", -1))
		var spell_id := int(effect.get("proc_spell_id", 0))
		match str(effect.get("effect_type", "")):
			"offensive_proc":
				if owner_id != attacker_id or spell_id <= 0:
					continue
				if bool(effect.get("pve_only", false)) and (target == null or target.is_player):
					continue
				if _proc_roll(float(effect.get("proc_chance", 0.0)), spell_id):
					_cast_sub_spell(attacker_id, target_id, spell_id, "offensive_proc")
			"defensive_proc":
				if owner_id != target_id or spell_id <= 0:
					continue
				if _proc_roll(float(effect.get("proc_chance", 0.0)), spell_id):
					_cast_sub_spell(target_id, attacker_id, spell_id, "defensive_proc")
	if style != null and attack.attack_result == DaocCombatEnums.RESULT_HIT_STYLE:
		_fire_style_procs(attacker_id, target_id, style)


## StyleProcessor.cs l.389 : la liste des procs a executer.
func style_procs_to_execute(style: DaocStyleDef, attacker_class_id: int) -> Array:
	var chosen: Array = []
	var class_specific := false
	for value in style.procs:
		var proc := value as Dictionary
		var proc_class := int(proc.get("class_id", 0))
		if attacker_class_id > 0 and proc_class == attacker_class_id:
			chosen.append(proc)
			class_specific = true
		elif proc_class == style.class_id or proc_class == 0:
			chosen.append(proc)
	if class_specific:
		chosen = chosen.filter(func(p: Dictionary) -> bool: return int(p.get("class_id", 0)) != 0)
	return chosen


func _fire_style_procs(attacker_id: int, target_id: int, style: DaocStyleDef) -> void:
	if style.procs.is_empty():
		return
	var class_id := player_class_id if attacker_id == player_object_id else -1
	var procs: Array = []
	if style.random_proc:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base + _swing_counter * 7919
		procs = [style.procs[rng.randi_range(0, style.procs.size() - 1)]]
	else:
		procs = style_procs_to_execute(style, class_id).filter(
			func(p: Dictionary) -> bool: return _proc_roll(float(p.get("chance", 0)), int(p.get("spell_id", 0))))
	for value in procs:
		var spell_id := int((value as Dictionary).get("spell_id", 0))
		var raw := _ensure_spell_catalogue().raw_spell(spell_id)
		if str(raw.get("Type", "")) == "MultiTarget":
			_hit_extra_targets(attacker_id, target_id, int(float(raw.get("Value", 0))))
		elif str(raw.get("Type", "")) != "NaturesShield":
			_cast_sub_spell(attacker_id, target_id, spell_id, "style_proc")


## AttackComponent.cs l.875 : Value cibles de plus, attaquables, a portee de
## melee, la cible principale exclue — chacune recoit un coup ordinaire.
func _hit_extra_targets(attacker_id: int, primary_id: int, count: int) -> void:
	if count <= 0:
		return
	var candidates: Array = []
	for value in _states.keys():
		var other_id := int(value)
		var other: DaocCombatEntityState = _states[other_id] as DaocCombatEntityState
		if other_id == attacker_id or other_id == primary_id or not other.is_alive:
			continue
		if not bool((_meta.get(other_id, {}) as Dictionary).get("attackable", false)):
			continue
		var distance := _horizontal_distance(attacker_id, other_id)
		if distance <= melee_range_raw:
			candidates.append([distance, other_id])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var attacker: DaocCombatEntityState = _states.get(attacker_id) as DaocCombatEntityState
	var weapon: Dictionary = (_meta.get(attacker_id, {}) as Dictionary).get("weapon", {}) as Dictionary
	for pair in candidates.slice(0, count):
		var extra_id := int(pair[1])
		var extra: DaocCombatEntityState = _states[extra_id] as DaocCombatEntityState
		var attack: DaocAttackData = DaocMeleeExchange.resolve(attacker, extra, weapon, {
			"seed": seed_base + _swing_counter * 7919 + extra_id,
			"attack_type": DaocCombatEnums.ATTACK_MELEE_ONE_HAND, "use_dol_formulas": use_dol_formulas,
			"target_armor": (_meta.get(extra_id, {}) as Dictionary).get("armor", {}),
			"target_shield": (_meta.get(extra_id, {}) as Dictionary).get("shield", {}),
		})
		var total: int = attack.total_damage() if attack.is_hit() else 0
		if total > 0:
			extra.change_health(-total)
		extra_targets_hit += 1
		_emit_event({"kind": "swing", "attacker_id": attacker_id, "target_id": extra_id, "multi_target": true,
			"attacker": attacker.name, "target": extra.name, "result": attack.attack_result, "damage": total,
			"target_health": extra.health, "target_max_health": extra.max_health,
			"text": "%s frappe aussi %s (%d)." % [attacker.name, extra.name, total]})
		state_changed.emit(extra_id, snapshot(extra_id))
		if not extra.is_alive:
			_handle_death(extra_id, attacker_id)


## AttackComponent.cs l.1330 : tant qu'un style portant NaturesShield est
## ARME, les tirs et les sorts sont bloques (BlockChance = Value, 100 dans la
## base). L'arbitre local ne tient pas l'orientation des entites : le cone
## frontal de 120 degres n'est pas verifie ici.
func natures_shield_blocks_spell(target_id: int) -> bool:
	var style: DaocStyleDef = _pending_style.get(target_id, null) as DaocStyleDef
	if style == null or style.procs.is_empty():
		return false
	for value in style.procs:
		var raw := _ensure_spell_catalogue().raw_spell(int((value as Dictionary).get("spell_id", 0)))
		if str(raw.get("Type", "")) == "NaturesShield":
			return _proc_roll(float(raw.get("Value", 100)), 97)
	return false


## Un sous-sort (proc) : ni mana, ni incantation, ni portee — il part du coup.
func _cast_sub_spell(caster_id: int, enemy_id: int, spell_id: int, origin: String) -> Dictionary:
	var raw := _ensure_spell_catalogue().raw_spell(spell_id)
	if raw.is_empty():
		return {"ok": false, "reason": "sous-sort %d introuvable" % spell_id}
	var spell := DaocSpellDef.from_dict(raw)
	var caster: DaocCombatEntityState = _states.get(caster_id) as DaocCombatEntityState
	var target_id := enemy_id if spell.target.to_lower() == "enemy" else caster_id
	var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
	if caster == null or target == null or not caster.is_alive or not target.is_alive:
		return {"ok": false, "reason": "acteur invalide"}
	var handler := _spell_registry.create_handler(spell, "Combat Styles Effect")
	if handler == null:
		_emit_event({"kind": "proc", "origin": origin, "attacker_id": caster_id, "target_id": target_id, "spell_id": spell_id,
			"handled": false, "text": "%s : aucun gestionnaire pour %s (le serveur non plus)." % [spell.name, spell.spell_type]})
		return {"ok": false, "reason": "type de sort sans gestionnaire"}
	var result := handler.execute(caster, target, {"seed": seed_base + _swing_counter + spell_id, "apply_to_target": true, "defer_periodic": true})
	_register_spell_effects(caster_id, target_id, spell, result.get("effects", []) as Array)
	procs_fired += 1
	_emit_event({"kind": "proc", "origin": origin, "attacker_id": caster_id, "target_id": target_id, "spell_id": spell_id,
		"spell_name": spell.name, "spell_type": spell.spell_type, "handled": true, "target_health": target.health,
		"text": "%s declenche %s sur %s." % [caster.name, spell.name, target.name]})
	state_changed.emit(target_id, snapshot(target_id))
	if not target.is_alive:
		_handle_death(target_id, caster_id)
	return {"ok": true, "result": result}


## P1-121 — l'usure DOL apres un coup : l'arme du JOUEUR qui frappe (coup,
## style, rate, parade, maladresse — GamePlayer.cs:6295), la piece touchee du
## JOUEUR frappe, ou son bouclier s'il bloque (GamePlayer.cs:6570). Le tirage
## est deterministe (graine de session + numero de coup), comme tout l'arbitre.
var item_wear_enabled := true
var _items_worn := 0


func _wear_player_items(attacker_id: int, target_id: int, attack: DaocAttackData) -> void:
	if not item_wear_enabled or _player_inventory == null or player_object_id < 0:
		return
	var result := attack.attack_result
	var slot := -1
	if attacker_id == player_object_id and result in [DaocCombatEnums.RESULT_HIT_UNSTYLED,
			DaocCombatEnums.RESULT_HIT_STYLE, DaocCombatEnums.RESULT_MISSED,
			DaocCombatEnums.RESULT_PARRIED, DaocCombatEnums.RESULT_FUMBLED]:
		slot = int(_player_inventory.active_weapon_slot())
	elif target_id == player_object_id and attack.is_hit():
		slot = int(attack.armor_hit_location) if attack.armor_hit_location.is_valid_int() else -1
	elif target_id == player_object_id and result == DaocCombatEnums.RESULT_BLOCKED:
		slot = DaocPlayerInventory.SLOT_LEFT_HAND
	if slot < 0:
		return
	var item: Dictionary = _player_inventory.item_at(slot)
	if item.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + _swing_counter * 104729 + slot
	var player: DaocCombatEntityState = _states.get(player_object_id) as DaocCombatEntityState
	var worn: Dictionary = ItemConditionRules.wear(item, player.level if player != null else 1, rng.randi_range(0, 99))
	if not bool(worn.get("changed", false)):
		return
	_items_worn += 1
	_player_inventory.replace_item(slot, worn["item"] as Dictionary)
	_apply_player_equipment()
	player_inventory_changed.emit(_player_inventory.snapshot())
	if str(worn.get("message", "")) != "":
		_emit_event({"kind": "item_condition", "slot": slot, "percent": int(worn.get("percent", 0)),
			"text": str(worn["message"])})


## P1-121 — reparer chez un forgeron hors ligne : l'offre (prix) puis le
## paiement. Hors ligne il n'y a ni forgeron ni bourse fidele ; ces deux appels
## portent la regle pour le jour ou l'arbitre en aura un.
func repair_offer(slot: int) -> Dictionary:
	if _player_inventory == null:
		return {"ok": false, "reason": "inventaire absent"}
	var item: Dictionary = _player_inventory.item_at(slot)
	if item.is_empty():
		return {"ok": false, "reason": "logement vide"}
	return ItemConditionRules.repair_offer(item)


func repair_item(slot: int) -> Dictionary:
	var offer := repair_offer(slot)
	if not bool(offer.get("ok", false)):
		return offer
	var repaired: Dictionary = ItemConditionRules.repair(_player_inventory.item_at(slot))
	_player_inventory.replace_item(slot, repaired["item"] as Dictionary)
	_apply_player_equipment()
	player_inventory_changed.emit(_player_inventory.snapshot())
	return {"ok": true, "cost": int(offer.get("cost", 0)), "rather_old": bool(repaired["rather_old"]),
		"item": repaired["item"]}


## Butin ou marchand : un objet entre dans le sac. Rend le logement, -1 si plein.
func give_player_item(item: Dictionary) -> int:
	if _player_inventory == null:
		return -1
	var slot: int = _player_inventory.add_to_backpack(item)
	if slot >= 0:
		player_inventory_changed.emit(_player_inventory.snapshot())
	return slot


## Entites POINTABLES a la souris : celles qui ont a la fois un etat et un noeud
## 3D attache. Le client s'en sert pour resoudre un rayon camera vers un
## `object_id` — les PNJ n'ayant pas de corps physique, la resolution se fait
## contre leur emprise visuelle cote client, pas ici. Lecture seule : l'autorite
## ne decide de rien, elle expose seulement ce qu'elle sait deja.
func targetable_entries() -> Array:
	var out: Array = []
	for object_id in _nodes.keys():
		var node: Node3D = _nodes[object_id] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
		if state == null:
			continue
		var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
		out.append({
			"object_id": int(object_id),
			"node": node,
			"attackable": bool(meta.get("attackable", false)),
			"alive": state.is_alive,
			"is_player": state.is_player,
		})
	return out


func snapshot(object_id: int) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {}
	var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
	return {
		"object_id": object_id,
		"name": state.name,
		"level": state.level,
		"health": state.health,
		"max_health": state.max_health,
		"health_percent": 0.0 if state.max_health <= 0 else float(state.health) * 100.0 / float(state.max_health),
		"mana": state.mana,
		"endurance": state.endurance,
		"max_mana": state.max_mana,
		"max_endurance": state.max_endurance,
		"master_level_path": state.master_level_path,
		"master_level": state.master_level,
		"champion_enabled": state.champion_enabled,
		"champion_level": state.champion_level,
		# P1-23C — UN POURCENTAGE N'EXISTE QUE S'IL Y A UN PLAFOND. Une jauge du
		# XML ne peut structurellement pas connaitre son maximum ; l'arbitre le
		# convertit donc, et SEULEMENT quand il en connait un. Un metier sans
		# mana rend zero et ce champ reste absent : le pont continue de compter
		# la valeur comme non publiable, ce qui est la verite.
		"mana_percent": (float(state.mana) * 100.0 / float(state.max_mana)) if state.max_mana > 0 else null,
		"is_alive": state.is_alive,
		"is_player": state.is_player,
		"in_combat": state.in_combat,
		"attackable": bool(meta.get("attackable", false)),
		"realm": int(meta.get("realm", 0)),
		"model_id": int(meta.get("model_id", -1)),
		"entity_type": str(meta.get("entity_type", "")),
		"remote_player": bool(meta.get("remote_player", false)),
		"basis": (meta.get("basis", {}) as Dictionary).duplicate(true),
	}


## Cible vivante et attaquable la plus proche d'une position monde.
## C'est l'autorite qui repond, pas le client : lui ne sait pas qui est vivant.
## `exclude_object_id` sert au demandeur a s'exclure lui-meme.
func nearest_attackable(from_world: Vector3, radius_raw: float, exclude_object_id: int = -1) -> Dictionary:
	var best_id: int = -1
	var best_distance: float = INF
	var requester_realm := int((_meta.get(exclude_object_id, {}) as Dictionary).get("realm", 0))
	for object_id in _states.keys():
		if int(object_id) == exclude_object_id:
			continue
		var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
		if not bool(meta.get("attackable", false)):
			continue
		var candidate_realm := int(meta.get("realm", 0))
		# Les gardes et PNJ du royaume du joueur ne font pas partie du cycle Tab.
		# Les monstres PvE neutres portent realm=0 et restent donc sélectionnables.
		if requester_realm > 0 and candidate_realm == requester_realm:
			continue
		var state: DaocCombatEntityState = _states[object_id] as DaocCombatEntityState
		if not state.is_alive:
			continue
		var position: Vector3 = _positions.get(object_id, Vector3.ZERO) as Vector3
		var distance: float = Vector2(from_world.x, from_world.y).distance_to(Vector2(position.x, position.y))
		if distance < best_distance and distance <= radius_raw:
			best_distance = distance
			best_id = int(object_id)
	if best_id < 0:
		return {"ok": false, "reason": "aucune cible vivante dans le rayon", "radius_raw": radius_raw}
	var found: Dictionary = snapshot(best_id)
	found["ok"] = true
	found["distance_raw"] = best_distance
	return found


func recent_events(limit: int = 12) -> Array:
	var count: int = mini(limit, _event_log.size())
	return _event_log.slice(_event_log.size() - count, _event_log.size())


func report() -> Dictionary:
	var alive: int = 0
	var dead: int = 0
	var npc_states: int = 0
	var attackable: int = 0
	for object_id in _states.keys():
		var state: DaocCombatEntityState = _states[object_id] as DaocCombatEntityState
		if state.is_alive:
			alive += 1
		else:
			dead += 1
		var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
		if str(meta.get("entity_type", "")) == "npc":
			npc_states += 1
		if bool(meta.get("attackable", false)):
			attackable += 1
	var out: Dictionary = _boot_report.duplicate(true)
	# Ces valeurs sont VIVANTES depuis R3. Le rapport d'amorcage ne doit pas
	# continuer d'annoncer une entite apres son retrait du flux.
	out["entity_states"] = _states.size()
	out["npc_states"] = npc_states
	out["attackable"] = attackable
	out["alive"] = alive
	out["dead"] = dead
	out["active_sessions"] = _sessions.size()
	out["clock_msec"] = _clock_msec
	out["swings_resolved"] = _swing_counter
	out["nodes_attached"] = _nodes.size()
	out["stream_spawn_events"] = _stream_spawn_events
	out["stream_move_events"] = _stream_move_events
	out["stream_despawn_events"] = _stream_despawn_events
	out["mirror_mode"] = mirror_mode
	out["remote_status_updates"] = _remote_status_updates
	out["guardrails"] = DaocGameplayAuthority.guardrails()
	out["corpses"] = _corpses.size()
	out["deaths_resolved"] = _deaths_resolved
	out["respawns_resolved"] = _respawns_resolved
	out["styles"] = {
		"enabled": styles_enabled,
		"executed": _styles_executed,
		"armed": _pending_style.size(),
		"catalog_loaded": _style_index != null and bool(_style_index.get("loaded")),
	}
	out["mob_db"] = _mob_db_report.duplicate(true)
	out["factions"] = _faction_report.duplicate(true)
	out["loot"] = _loot_report.duplicate(true)
	out["loot_rolls"] = _loot_rolls
	out["ai"] = {"enabled": npc_ai_enabled, "brains": _brains.size(), "aggro_triggered": _aggro_triggered, "leash_returns": _leash_returns}
	if player_object_id >= 0:
		out["player_progress"] = experience_report(player_object_id)
	return out


## L'etat d'avancement d'un personnage : total, niveau, reste a parcourir.
## Rend un dictionnaire VIDE pour une entite qui n'en a pas — un PNJ, ou un
## joueur avant son premier gain.
## P1-78 — en miroir, la progression est celle que le serveur envoie (0x91) :
## `level_permill` est la barre d'experience, l'experience brute est conservee.
var _remote_points: Dictionary = {}


func apply_remote_player_points(points: Dictionary) -> Dictionary:
	if not mirror_mode:
		return {"ok": false, "reason": "pas en mode miroir"}
	_remote_points = points.duplicate(true)
	_remote_points["source"] = "SERVER_0x91"
	if _states.has(player_object_id):
		state_changed.emit(player_object_id, snapshot(player_object_id))
	return {"ok": true, "level_permill": int(points.get("level_permill", 0))}


func experience_report(object_id: int) -> Dictionary:
	if mirror_mode and object_id == player_object_id and not _remote_points.is_empty():
		var permill := int(_remote_points.get("level_permill", 0))
		var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
		return {
			"object_id": object_id,
			"total_experience": permill,
			"level": int(state.level) if state != null else 0,
			"level_floor": 0,
			"next_level_at": 1000,
			"to_next_level": 1000 - permill,
			"experience": int(_remote_points.get("experience", 0)),
			"experience_next_level": int(_remote_points.get("experience_next_level", 0)),
			"basis": "SERVER_0x91",
		}
	if not _experience.has(object_id):
		return {}
	var purse: Dictionary = _experience[object_id] as Dictionary
	var total: int = int(purse.get("total", 0))
	var level: int = int(purse.get("level", 1))
	return {
		"object_id": object_id,
		"total_experience": total,
		"level": level,
		"level_floor": ExperienceRules.experience_for_level(level, use_dol_formulas),
		"next_level_at": ExperienceRules.experience_for_level(level + 1, use_dol_formulas),
		"to_next_level": ExperienceRules.experience_to_next_level(total, level, use_dol_formulas),
		"basis": ExperienceRules.BASIS_DOL_CODE if use_dol_formulas else ExperienceRules.BASIS_PLACEHOLDER,
	}


## Vrai tant que le corps d'une creature morte est encore au sol.
func is_corpse(object_id: int) -> bool:
	return _corpses.has(object_id) and not bool((_corpses[object_id] as Dictionary).get("decayed", false))


## L'etat d'un cadavre : quand il s'efface, quand la creature revient.
func corpse_report(object_id: int) -> Dictionary:
	if not _corpses.has(object_id):
		return {}
	var corpse: Dictionary = (_corpses[object_id] as Dictionary).duplicate(true)
	corpse["object_id"] = object_id
	corpse["decay_in_msec"] = maxf(0.0, float(corpse.get("decay_msec", 0.0)) - _clock_msec)
	corpse["respawn_in_msec"] = maxf(0.0, float(corpse.get("respawn_msec", 0.0)) - _clock_msec)
	return corpse


## Ce que la base OpenDAoC sait d'une entite, ou un dictionnaire vide.
## C'est par ici que P1-22C lira la table de butin et P1-22D la portee d'aggro.
func mob_db_profile(object_id: int) -> Dictionary:
	return ((_meta.get(object_id, {}) as Dictionary).get("mob_db", {}) as Dictionary).duplicate(true)


# --------------------------------------------------------------------------
# Interne
# --------------------------------------------------------------------------

func _horizontal_distance(a_id: int, b_id: int) -> float:
	var a: Vector3 = _positions.get(a_id, Vector3.ZERO) as Vector3
	var b: Vector3 = _positions.get(b_id, Vector3.ZERO) as Vector3
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


func _is_targeted_by_anyone(object_id: int) -> bool:
	for attacker_id in _sessions.keys():
		if int((_sessions[attacker_id] as Dictionary).get("target_id", -1)) == object_id:
			return true
	return false


## Annule atomiquement les combats ou l'entite intervient. La copie des cles
## evite de modifier le dictionnaire pendant son parcours.
func _cancel_sessions_involving(object_id: int) -> void:
	var affected: Dictionary = {}
	for attacker_id in _sessions.keys().duplicate():
		var session: Dictionary = _sessions[attacker_id] as Dictionary
		if int(attacker_id) == object_id or int(session.get("target_id", -1)) == object_id:
			affected[int(attacker_id)] = true
			affected[int(session.get("target_id", -1))] = true
			_sessions.erase(attacker_id)
	for affected_id in affected.keys():
		var state: DaocCombatEntityState = _states.get(int(affected_id)) as DaocCombatEntityState
		if state != null:
			state.in_combat = _sessions.has(int(affected_id)) or _is_targeted_by_anyone(int(affected_id))


func _emit_event(event: Dictionary) -> void:
	event["clock_msec"] = _clock_msec
	_event_log.append(event)
	if _event_log.size() > _event_log_limit:
		_event_log = _event_log.slice(_event_log.size() - _event_log_limit, _event_log.size())
	if log_events:
		print("LOCAL_SERVER %s" % str(event.get("text", event.get("kind", "?"))))
	combat_event.emit(event)


# --------------------------------------------------------------------------
# P1-109 — CAPACITES DE ROYAUME, RANG, AGGRO, ET LES SORTS DEVENUS FIDELES
#
# Hors ligne, le joueur n'avait ni capacite de royaume ni rang ; les sorts
# Taunt / Amnesia / Confusion / Nearsight etaient routes vers des familles
# voisines sans regle propre (P1-108). Ici : un registre d'aggro par creature
# (DOL : AggroList), que Taunt nourrit et qu'Amnesia efface ; Confusion qui
# retarget au hasard a chaque pulsation ; Nearsight qui raccourcit la portee
# des sorts dans _complete_spell ; et les capacites passives qui s'ajoutent
# aux formules (DaocRealmAbilityRules). Tout reste une prediction locale.
# --------------------------------------------------------------------------
const RealmAbilityRules = preload("res://src/daoc/gameplay/rules/DaocRealmAbilityRules.gd")
var _aggro: Dictionary = {}          # npc_id -> { attacker_id: amount }
var _taunts_applied: int = 0
var _amnesias_applied: int = 0
var _confusion_retargets: int = 0
var _remote_career: Dictionary = {}


## `abilities` : nom DOL -> niveau (ce que le 0x7B code 1 liste, ou une
## fixture). Les passives connues deviennent des bonus ; les actives et les
## inconnues sont rapportees, pas appliquees.
func configure_player_realm_abilities(object_id: int, abilities: Dictionary) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {"ok": false, "reason": "entite inconnue"}
	var meta: Dictionary = _meta.get(object_id, {}) as Dictionary
	if not meta.has("base_max_health"):
		meta["base_max_health"] = state.max_health
		meta["base_max_mana"] = state.max_mana
	var bonuses: Dictionary = RealmAbilityRules.bonuses_for(abilities)
	state.realm_abilities = abilities.duplicate(true)
	state.ability_properties = (bonuses.get("properties", {}) as Dictionary).duplicate(true)
	state.ability_resists = (bonuses.get("resists", {}) as Dictionary).duplicate(true)
	# Toughness / Ethereal Bond : des points de vie et de mana PLATS (DOL
	# MaxHealthCalculator : hpBase + itemBonus + buffBonus + abilityBonus).
	var health_bonus := int(state.ability_properties.get("MaxHealth", 0))
	var mana_bonus := int(state.ability_properties.get("MaxMana", 0))
	var health_ratio := float(state.health) / float(maxi(1, state.max_health))
	state.max_health = int(meta["base_max_health"]) + health_bonus
	state.health = clampi(int(round(health_ratio * float(state.max_health))), 0, state.max_health)
	state.max_mana = int(meta["base_max_mana"]) + mana_bonus
	state.mana = clampi(state.mana, 0, state.max_mana)
	_meta[object_id] = meta
	state_changed.emit(object_id, snapshot(object_id))
	return {"ok": true, "applied": bonuses.get("applied", []), "ignored": bonuses.get("ignored", []),
		"properties": state.ability_properties.duplicate(true), "resists": state.ability_resists.duplicate(true),
		"max_health": state.max_health, "max_mana": state.max_mana}


func realm_abilities_report(object_id: int) -> Dictionary:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return {}
	return {"abilities": state.realm_abilities.duplicate(true), "properties": state.ability_properties.duplicate(true),
		"resists": state.ability_resists.duplicate(true), "realm_level": state.realm_level, "bounty_points": state.bounty_points}


## Le rang de royaume et les bounty points du 0x91 (DaocOpenDaocCareerCodec).
func apply_remote_player_career(career: Dictionary) -> Dictionary:
	_remote_career = career.duplicate(true)
	var state: DaocCombatEntityState = _states.get(player_object_id) as DaocCombatEntityState
	if state == null:
		return {"ok": false, "reason": "joueur absent"}
	state.realm_level = int(career.get("realm_level", 0))
	state.bounty_points = int(career.get("bounty_points", 0))
	state_changed.emit(player_object_id, snapshot(player_object_id))
	return {"ok": true, "realm_level": state.realm_level, "bounty_points": state.bounty_points}


func career_report() -> Dictionary:
	return _remote_career.duplicate(true)


## ── aggro ────────────────────────────────────────────────────────────────
func add_aggro(npc_id: int, attacker_id: int, amount: int) -> Dictionary:
	if not _states.has(npc_id):
		return {"ok": false, "reason": "creature inconnue"}
	var ledger: Dictionary = _aggro.get(npc_id, {}) as Dictionary
	ledger[attacker_id] = maxi(0, int(ledger.get(attacker_id, 0)) + amount)
	_aggro[npc_id] = ledger
	# Une creature au repos qui recoit de l'aggro engage l'attaquant (DOL :
	# AddToAggroList sur un cerveau inactif le reveille).
	var brain: Dictionary = _brains.get(npc_id, {"state": NpcBrain.STATE_IDLE, "target_id": -1}) as Dictionary
	if amount > 0 and int(brain.get("target_id", -1)) < 0 and _states.has(attacker_id):
		brain["state"] = NpcBrain.STATE_CHASING
		brain["target_id"] = attacker_id
		_brains[npc_id] = brain
	return {"ok": true, "aggro": ledger.duplicate(true)}


func clear_aggro(npc_id: int) -> Dictionary:
	_aggro.erase(npc_id)
	if _brains.has(npc_id):
		var brain: Dictionary = _brains[npc_id]
		brain["state"] = NpcBrain.STATE_IDLE
		brain["target_id"] = -1
		_brains[npc_id] = brain
	stop_attack(npc_id)
	return {"ok": true}


func aggro_report(npc_id: int) -> Dictionary:
	return (_aggro.get(npc_id, {}) as Dictionary).duplicate(true)


## Les effets IMMEDIATS des sorts fideles de P1-109, appliques a
## l'enregistrement (comme « cure_state » avant eux).
func _apply_immediate_spell_effect(caster_id: int, target_id: int, effect: Dictionary) -> bool:
	match str(effect.get("effect_type", "")):
		"aggro_add":
			add_aggro(target_id, caster_id, int(effect.get("amount", 0)))
			_taunts_applied += 1
			return true
		"amnesia":
			if bool(effect.get("forgets", false)):
				clear_aggro(target_id)
				_amnesias_applied += 1
			return true
		"cancel_cast", "interrupt":
			interrupt_spell_cast(target_id, "amnesia" if str(effect.get("effect_type", "")) == "cancel_cast" else "interruption", true)
			if bool(effect.get("clears_pending_style", false)):
				_pending_style.erase(target_id)
			return true
		"life_transfer":
			# Deja applique par le gestionnaire (apply_to_target) ; rien a garder.
			return true
		"summon_pet":
			summon_pet(caster_id, effect)
			return true
		"pet_cast":
			var pet_id := pet_of(caster_id)
			if pet_id >= 0:
				_cast_sub_spell(pet_id, int(effect.get("target_id", -1)), int(effect.get("sub_spell_id", 0)), "pet_spell")
			return true
		"pets_release_area":
			_release_pets_near(caster_id, int(effect.get("target_id", caster_id)), float(effect.get("radius", 0)), 0.0)
			return true
		"pet_conversion":
			var converted_target := int(effect.get("target_id", -1))
			if not _pets.has(converted_target):
				converted_target = pet_of(caster_id)
			if converted_target >= 0:
				_release_pets_near(caster_id, converted_target, float(effect.get("radius", 0)), float(effect.get("percent", 0.0)))
			return true
		"move_to_bind":
			# P1-123 : GatewayPersonalBind -> GamePlayer.MoveToBind.
			if caster_id == player_object_id and player_bind_position != Vector3.INF:
				_positions[caster_id] = player_bind_position
				player_moved_to_bind.emit(player_bind_position, player_bind_region)
			return true
	return false


## Confusion : la creature lache sa cible et en prend une au hasard dans les
## 1000 unites — le joueur, et ses semblables si l'effet le permet.
func _confuse(npc_id: int, effect: Dictionary, salt: int) -> void:
	if npc_id == player_object_id or not _states.has(npc_id):
		return
	var candidates: Array = []
	var radius := float(effect.get("radius_raw", 1000))
	for key in _states.keys():
		var other_id := int(key)
		if other_id == npc_id:
			continue
		var other: DaocCombatEntityState = _states[other_id] as DaocCombatEntityState
		if other == null or not other.is_alive:
			continue
		if _horizontal_distance(npc_id, other_id) > radius:
			continue
		if other.is_player or bool(effect.get("attack_friends", false)):
			candidates.append(other_id)
	if candidates.is_empty():
		return
	var pick: int = candidates[(seed_base + npc_id + salt) % candidates.size()]
	stop_attack(npc_id)
	interrupt_spell_cast(npc_id, "confusion", true)
	var brain: Dictionary = _brains.get(npc_id, {"state": NpcBrain.STATE_IDLE, "target_id": -1}) as Dictionary
	brain["target_id"] = pick
	brain["state"] = NpcBrain.STATE_CHASING
	_brains[npc_id] = brain
	request_attack(npc_id, pick)
	_confusion_retargets += 1


func spell_fidelity_report() -> Dictionary:
	return {"taunts_applied": _taunts_applied, "amnesias_applied": _amnesias_applied, "confusion_retargets": _confusion_retargets,
		"aggro": _aggro.duplicate(true)}


## P1-109 : Nearsight raccourcit la portee du LANCEUR (DOL : DebuffCategory
## SpellRange en pourcent ; l archerie lit ArcheryRange).
func _effective_spell_range(caster: DaocCombatEntityState, spell: DaocSpellDef) -> float:
	var range_property := "ArcheryRange" if spell.spell_type in ["Archery", "SiegeArrow", "ArrowDamageTypes"] else "SpellRange"
	return float(spell.range) * maxf(0.0, 1.0 + caster.get_modified(range_property, 0.0) * 0.01)


## P1-123 — le plus fort ralentissement actif sur l'entite (DOL : les
## debuffs de vitesse d'une meme categorie ne s'additionnent pas).
func snare_speed_factor(object_id: int) -> float:
	if _snare_immune(object_id):
		return 1.0
	var strongest := 0.0
	for value in _active_spell_effects:
		var effect := value as Dictionary
		if int(effect.get("target_id", -1)) != object_id:
			continue
		strongest = maxf(strongest, float(effect.get("snare_percent", 0.0)))
	return clampf(1.0 - strongest * 0.01, 0.0, 1.0)


## ═══════════════════════════════════════════════════════════════════════════
## P1-124 — LES FAMILIERS VIVENT HORS LIGNE (OpenDAoC SummonSpellHandler,
## GameSummonedPet, ControlledMobBrain en mode defensif) : un vrai PNJ tire de
## npctemplate, au niveau de SetPetLevel, qui suit son maitre (150 unites,
## 100 pour un familier de compagnie), attaque ce que le maitre attaque ou ce
## qui attaque le maitre ou lui-meme, et disparait a l'expiration du sort ou a
## la mort du maitre. Un seul familier de combat a la fois.
## ═══════════════════════════════════════════════════════════════════════════
const PET_TEMPLATES_PATH := "res://data/gameplay/dol/p1_124_pet_templates.json"
const PET_ID_BASE := 3000000
const PET_FOLLOW_DISTANCE := 150.0
const NOVELTY_FOLLOW_DISTANCE := 100.0
signal pet_summoned(entity: Dictionary)
signal pet_released(pet_id: int, reason: String)
var pets_summoned := 0
var _pets: Dictionary = {}
var _pet_templates: Dictionary = {}
var _next_pet_serial := 0


func _has_effect(object_id: int, effect_type: String) -> bool:
	for value in _active_spell_effects:
		var effect := value as Dictionary
		if int(effect.get("target_id", -1)) == object_id and str(effect.get("effect_type", "")) == effect_type:
			return true
	return false


func pet_of(owner_id: int) -> int:
	for pet_id in _pets.keys():
		var pet := _pets[pet_id] as Dictionary
		if int(pet.get("owner_id", -1)) == owner_id and not bool(pet.get("novelty", false)):
			return int(pet_id)
	return -1


func pets_snapshot() -> Dictionary:
	return _pets.duplicate(true)


func pet_template(template_id: int) -> Dictionary:
	if _pet_templates.is_empty() and FileAccess.file_exists(PET_TEMPLATES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PET_TEMPLATES_PATH))
		if parsed is Dictionary:
			_pet_templates = (parsed as Dictionary).get("templates", {}) as Dictionary
	return (_pet_templates.get(str(template_id), {}) as Dictionary).duplicate(true)


static func _first_int(value: String, fallback: int) -> int:
	for part in value.replace("-", ";").split(";", false):
		if part.strip_edges().is_valid_int():
			return int(part.strip_edges())
	return fallback


func summon_pet(owner_id: int, effect: Dictionary) -> Dictionary:
	var owner: DaocCombatEntityState = _states.get(owner_id) as DaocCombatEntityState
	if owner == null or not owner.is_alive:
		return {"ok": false, "reason": "maitre invalide"}
	var template_id := int(effect.get("template_id", 0))
	var template := pet_template(template_id)
	if template.is_empty():
		_emit_event({"kind": "pet", "attacker_id": owner_id, "text": "NPC template %d not found!" % template_id})
		return {"ok": false, "reason": "modele %d absent" % template_id}
	var novelty := bool(effect.get("novelty", false))
	if not novelty:
		var previous := pet_of(owner_id)
		if previous >= 0:
			release_pet(previous, "remplace")
	_next_pet_serial += 1
	var pet_id := PET_ID_BASE + _next_pet_serial
	var at: Vector3 = (_positions.get(owner_id, Vector3.ZERO) as Vector3) + Vector3(64, 0, 0)
	var name := str(template.get("name", "familier"))
	if novelty:
		name = "%s's %s" % [owner.name, name]
	var entity := {"object_id": pet_id, "entity_type": "npc", "name": name, "level": int(effect.get("pet_level", 1)),
		"model_id": _first_int(str(template.get("model", "")), 0), "size": _first_int(str(template.get("size", "50")), 50),
		"x": at.x, "y": at.y, "z": at.z, "realm": int((_meta.get(owner_id, {}) as Dictionary).get("realm", 1)),
		"health_percent": 100, "flags": {"peaceful": novelty}, "pet_owner": owner_id}
	spawn_stream_entity(entity, null)
	var meta: Dictionary = _meta.get(pet_id, {}) as Dictionary
	meta["pet_owner"] = owner_id
	meta["attackable"] = false
	meta["mob_db"] = {}
	_meta[pet_id] = meta
	_brains.erase(pet_id)
	var duration := int(effect.get("duration", 0))
	_pets[pet_id] = {"owner_id": owner_id, "template_id": template_id, "novelty": novelty,
		"expires_msec": _clock_msec + float(duration) if duration > 0 else INF}
	pets_summoned += 1
	_emit_event({"kind": "pet", "attacker_id": owner_id, "target_id": pet_id,
		"text": "The %s is now under your control." % name})
	pet_summoned.emit(entity)
	return {"ok": true, "pet_id": pet_id, "entity": entity}


func release_pet(pet_id: int, reason: String = "libere") -> void:
	if not _pets.has(pet_id):
		return
	_pets.erase(pet_id)
	_cancel_sessions_involving(pet_id)
	despawn_stream_entity(pet_id, "pet_%s" % reason)
	pet_released.emit(pet_id, reason)


## TurretsRelease / PetConversion : les familiers du maitre dans `radius`
## autour du centre ; la conversion rend percent % de leur vie en mana.
func _release_pets_near(owner_id: int, center_id: int, radius: float, percent: float) -> void:
	var owner: DaocCombatEntityState = _states.get(owner_id) as DaocCombatEntityState
	var center: Vector3 = _positions.get(center_id, _positions.get(owner_id, Vector3.ZERO)) as Vector3
	for pet_value in _pets.keys().duplicate():
		var pet_id := int(pet_value)
		if int((_pets[pet_id] as Dictionary).get("owner_id", -1)) != owner_id:
			continue
		var pos: Vector3 = _positions.get(pet_id, Vector3.ZERO) as Vector3
		if pet_id != center_id and (radius <= 0.0 or _flat_distance(pos, center) > radius):
			continue
		var pet: DaocCombatEntityState = _states.get(pet_id) as DaocCombatEntityState
		if percent > 0.0 and owner != null and pet != null:
			owner.mana = mini(owner.max_mana, owner.mana + int(float(pet.health) * percent / 100.0))
		release_pet(pet_id, "converti" if percent > 0.0 else "dissipe")


func _advance_pets(delta_seconds: float) -> void:
	for pet_value in _pets.keys().duplicate():
		var pet_id := int(pet_value)
		var info := _pets[pet_id] as Dictionary
		var owner_id := int(info.get("owner_id", -1))
		var owner: DaocCombatEntityState = _states.get(owner_id) as DaocCombatEntityState
		var pet: DaocCombatEntityState = _states.get(pet_id) as DaocCombatEntityState
		if pet == null or not pet.is_alive:
			release_pet(pet_id, "mort")
			continue
		if owner == null or not owner.is_alive or _clock_msec >= float(info.get("expires_msec", INF)):
			release_pet(pet_id, "expire")
			continue
		var target_id := -1
		if not bool(info.get("novelty", false)):
			target_id = int((_sessions.get(owner_id, {}) as Dictionary).get("target_id", -1))
			if target_id < 0:
				for attacker in _sessions.keys():
					var aimed := int((_sessions[attacker] as Dictionary).get("target_id", -1))
					if aimed == owner_id or aimed == pet_id:
						target_id = int(attacker)
						break
		var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
		var pet_pos: Vector3 = _positions.get(pet_id, Vector3.ZERO) as Vector3
		if target != null and target.is_alive and target_id != pet_id:
			var target_pos: Vector3 = _positions.get(target_id, pet_pos) as Vector3
			if _flat_distance(pet_pos, target_pos) > melee_range_raw * 0.9:
				_step_creature(pet_id, target_pos, mob_db_profile(pet_id), delta_seconds)
			if int((_sessions.get(pet_id, {}) as Dictionary).get("target_id", -1)) != target_id:
				if bool((_meta.get(target_id, {}) as Dictionary).get("attackable", false)):
					request_attack(pet_id, target_id)
			continue
		if _sessions.has(pet_id):
			_sessions.erase(pet_id)
		var follow := NOVELTY_FOLLOW_DISTANCE if bool(info.get("novelty", false)) else PET_FOLLOW_DISTANCE
		var owner_pos: Vector3 = _positions.get(owner_id, pet_pos) as Vector3
		if _flat_distance(pet_pos, owner_pos) > follow:
			_step_creature(pet_id, owner_pos, mob_db_profile(pet_id), delta_seconds)


## ═══════════════════════════════════════════════════════════════════════════
## P1-125 — LES CAPACITES DE ROYAUME ACTIVES hors ligne (DOL realmabilities,
## bareme a cinq niveaux, DaocRealmAbilityActives). Preconditions : mort,
## assis (et en combat pour First Aid) ; delai de reutilisation par capacite.
## ═══════════════════════════════════════════════════════════════════════════
const RealmAbilityActives = preload("res://src/daoc/gameplay/rules/DaocRealmAbilityActives.gd")
const MAGIC_DAMAGE_TYPES := ["Heat", "Cold", "Matter", "Body", "Spirit", "Energy"]
var realm_abilities_used := 0
var _ra_cooldowns: Dictionary = {}
var _pending_purges: Array = []


func realm_ability_level(object_id: int, name: String) -> int:
	var state: DaocCombatEntityState = _states.get(object_id) as DaocCombatEntityState
	if state == null:
		return 0
	for key in state.realm_abilities.keys():
		if str(key).nocasecmp_to(name) == 0:
			return int(state.realm_abilities[key])
	return 0


func request_realm_ability(actor_id: int, name: String, target_id: int = -1) -> Dictionary:
	var actor: DaocCombatEntityState = _states.get(actor_id) as DaocCombatEntityState
	var entry := RealmAbilityActives.definition(name)
	if actor == null or entry.is_empty():
		return {"ok": false, "reason": "capacite active inconnue"}
	var level := realm_ability_level(actor_id, str(entry["name"]))
	if level <= 0:
		return {"ok": false, "reason": "capacite non apprise"}
	if not actor.is_alive:
		return {"ok": false, "reason": "mort"}
	if bool(entry.get("no_combat", false)) and actor.in_combat:
		return {"ok": false, "reason": "You can't use this ability while in combat!"}
	var key := "%d:%s" % [actor_id, str(entry["name"])]
	if _clock_msec < float(_ra_cooldowns.get(key, -1.0)):
		return {"ok": false, "reason": "pas encore disponible", "ready_in_msec": float(_ra_cooldowns[key]) - _clock_msec}
	var value := RealmAbilityActives.value_at(entry, level)
	var text := ""
	match str(entry["kind"]):
		"purge":
			if level == 1:
				_pending_purges.append({"object_id": actor_id, "at_msec": _clock_msec + 5000.0})
				text = "Purge dans 5 secondes."
			else:
				text = "Purge : %d effet(s) retire(s)." % _purge(actor_id)
		"endurance_full":
			actor.endurance = actor.max_endurance
			text = "Votre endurance est restauree."
		"mana_percent":
			var gained := mini(actor.max_mana * value / 100, actor.max_mana - actor.mana)
			actor.mana += gained
			text = "You gain %d mana." % gained if gained > 0 else "You have full mana."
		"health_percent":
			var healed := actor.change_health(actor.max_health * value / 100)
			text = "You heal yourself for %d hit points." % healed if healed > 0 else "You are fully healed."
		"damage_target":
			var target: DaocCombatEntityState = _states.get(target_id) as DaocCombatEntityState
			if target == null or not target.is_alive or target_id == actor_id:
				return {"ok": false, "reason": "aucune cible"}
			var reach := float(entry.get("range", 1500)) * (1.0 + actor.get_modified("SpellRange", 0.0) * 0.01)
			if _horizontal_distance(actor_id, target_id) > reach:
				return {"ok": false, "reason": "hors de portee"}
			var damage := maxi(0, int(float(value) * (1.0 - target.get_resist_percent("Heat") * 0.01)))
			target.change_health(-damage)
			text = "%s inflige %d degats a %s." % [str(entry["name"]), damage, target.name]
			state_changed.emit(target_id, snapshot(target_id))
			if not target.is_alive:
				_handle_death(target_id, actor_id)
		"effect":
			var effect_type := str(entry.get("effect", ""))
			var duration := value if effect_type == "speed_of_sound" else int(entry.get("duration", 0))
			var effect := {"effect_type": effect_type, "effect_category": "realm_ability", "ra_value": value,
				"duration": duration, "frequency": 0, "stacking_group": "ra:%s" % str(entry["name"]),
				"spell_name": str(entry["name"]), "caster_id": actor_id, "target_id": actor_id}
			var effects: Array = [effect]
			if effect_type == "magic_resist":
				for damage_type in MAGIC_DAMAGE_TYPES:
					effects.append({"effect_type": "magic_resist_part", "effect_category": "resists", "modifier_stat": damage_type,
						"modifier_value": float(value), "duration": duration, "frequency": 0,
						"stacking_group": "ra:Empty Mind:%s" % damage_type, "caster_id": actor_id, "target_id": actor_id})
			_register_spell_effects(actor_id, actor_id, DaocSpellDef.from_dict({"id": 0, "name": str(entry["name"]), "duration": duration}), effects)
			text = "%s est actif." % str(entry["name"])
	_ra_cooldowns[key] = _clock_msec + float(RealmAbilityActives.reuse_seconds(entry, level)) * 1000.0
	realm_abilities_used += 1
	_emit_event({"kind": "realm_ability", "attacker_id": actor_id, "target_id": target_id, "ability": str(entry["name"]),
		"level": level, "text": text})
	state_changed.emit(actor_id, snapshot(actor_id))
	return {"ok": true, "ability": str(entry["name"]), "level": level, "text": text}


## Purge : retire les effets NEFASTES (debuffs, ralentissements, CC, degats
## periodiques) portes par l'entite.
func _purge(object_id: int) -> int:
	var removed := 0
	for index in range(_active_spell_effects.size() - 1, -1, -1):
		var effect := _active_spell_effects[index] as Dictionary
		if int(effect.get("target_id", -1)) != object_id:
			continue
		var harmful := bool(effect.get("is_debuff", false)) or float(effect.get("snare_percent", 0.0)) > 0.0 \
			or bool(effect.get("prevents_movement", false)) or str(effect.get("effect_type", "")) in ["dot", "disease", "nearsight", "resurrection_illness"]
		if harmful:
			_active_spell_effects.remove_at(index)
			removed += 1
	_rebuild_effect_modifiers()
	return removed


func _advance_realm_abilities() -> void:
	for index in range(_pending_purges.size() - 1, -1, -1):
		var pending := _pending_purges[index] as Dictionary
		if _clock_msec >= float(pending.get("at_msec", 0.0)):
			_pending_purges.remove_at(index)
			var removed := _purge(int(pending.get("object_id", -1)))
			_emit_event({"kind": "realm_ability", "attacker_id": int(pending.get("object_id", -1)), "ability": "Purge",
				"text": "Purge : %d effet(s) retire(s)." % removed})


## Charge et Speed of Sound rendent insensible aux ralentissements.
func _snare_immune(object_id: int) -> bool:
	return _has_effect(object_id, "charge") or _has_effect(object_id, "speed_of_sound")


func _effect_value(object_id: int, effect_type: String) -> float:
	var best := 0.0
	for value in _active_spell_effects:
		var effect := value as Dictionary
		if int(effect.get("target_id", -1)) == object_id and str(effect.get("effect_type", "")) == effect_type:
			best = maxf(best, float(effect.get("ra_value", 0.0)))
	return best
