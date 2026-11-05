extends RefCounted
class_name DaocAttackComponent

## P1-18B — le calcul d'un coup. P1-23B y branche la CHAÎNE DE DÉGÂTS DE DOL.
##
## DEUX CHEMINS COEXISTENT, ET C'EST VOULU.
##
##   - `make_attack_p1_18b` garde la formule de P1-18B, inspirée du vocabulaire
##     de DOL sans en être : `dps * vitesse * (0,75 + force / 400)`, un plafond
##     à trois fois les dégâts de base, et rien d'autre. Elle reste appelable, et
##     la suite s'en sert comme CONTRE-ÉPREUVE ;
##   - `make_attack_dol` porte la vraie chaîne de `GameLiving.Attack`
##     (GameServer/gameobjects/GameLiving.cs:1725-1805), dans son ordre : dégâts
##     bruts, rapport arme/armure, absorption, variance, résistances, plafond,
##     plancher à 1.
##
## CE QUE LE CHEMIN DOL N'A PAS, ET QUI EST DIT PLUTÔT QUE COMBLÉ :
##
##   - **le joueur n'a pas d'équipement.** `GamePlayer.AttackDamage` lit un
##     `InventoryItem` — DPS, vitesse, qualité, condition — que l'arbitre local
##     n'a pas. Tant qu'une arme ne décrit pas ses champs à la manière de DOL
##     (`DPS_AF`, `SPD_ABS`), c'est la branche `GameLiving` qui sert, et le coup
##     le DIT dans ses notes : `damage_basis` vaut alors `DOL_CODE_LIVING_BRANCH`
##     et non `DOL_CODE_PLAYER_WEAPON` ;
##   - **personne ne porte d'armure.** `GetArmorAF` d'un PNJ rend sa propriété
##     `ArmorFactor`, zéro par défaut, et le joueur n'a pas d'inventaire. Le
##     dénominateur du rapport arme/armure vaut donc `20 * 4,67 = 93,4` tout
##     seul. Ce n'est PAS une simplification : c'est ce que DOL calcule pour une
##     cible nue ;
##   - **la spécialisation vaut 1.** La borne basse de variance reste à 75, son
##     minimum. Un personnage spécialisé frapperait plus régulièrement, jamais
##     plus fort — c'est la variance qui se resserre, pas la moyenne qui monte.
##
## LE TIRAGE EST DÉTERMINISTE. DOL tire `Util.Random(50)` ; ici la graine vient
## de l'appelant, sinon une session rejouée cesserait d'être une preuve.

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")

## Base de compétence d'arme du métier de la fixture canonique — `Armsman`,
## `BaseWeaponSkill = 440` dans `CharacterClassDB.cs`. Même discipline que
## `DaocLocalServerVitals.FIXTURE_CLASS_BASE_HP` : une constante nommée, tirée de
## la table extraite, et non un nombre choisi.
const FIXTURE_CLASS_WEAPON_SKILL_BASE: int = 440


func attack_damage_type(weapon: Dictionary, owner: DaocCombatEntityState = null) -> String:
	if weapon.is_empty():
		return DaocCombatEnums.DAMAGE_NATURAL
	if str(weapon.get("object_type", "")).to_lower() == "shield":
		return DaocCombatEnums.DAMAGE_CRUSH
	return DaocCombatEnums.canonical_damage_type(weapon.get("damage_type", weapon.get("Type_Damage", "Natural")))

func attack_speed(owner: DaocCombatEntityState, main_weapon: Dictionary, left_weapon: Dictionary = {}) -> int:
	if owner == null or main_weapon.is_empty():
		return 0
	var speed = float(main_weapon.get("SPD_ABS", main_weapon.get("speed", 25)))
	if not left_weapon.is_empty() and int(owner.get_modified("UsedHandOnLastDualWieldAttack", 0.0)) == 2:
		speed = (speed + float(left_weapon.get("SPD_ABS", left_weapon.get("speed", speed)))) / 2.0
	var quickness = minf(250.0, owner.get_modified("Quickness", 60.0))
	var melee_speed = owner.get_modified("MeleeSpeed", 100.0) * 0.01
	var computed = speed * (1.0 - (quickness - 60.0) * 0.002) * melee_speed * 100.0
	return int(maxf(1500.0 if owner.is_player else 500.0, computed))

func calculate_critical_chance(owner: DaocCombatEntityState, attack_type: String) -> int:
	if attack_type == DaocCombatEnums.ATTACK_RANGED:
		return int(owner.get_modified("CriticalArcheryHitChance", 0.0)) if owner != null else 0
	return int(owner.get_modified("CriticalMeleeHitChance", 0.0)) if owner != null else 0


## Le point d'entrée. Route vers l'une des deux chaînes, et n'en mélange aucune.
func make_attack(owner: DaocCombatEntityState, target: DaocCombatEntityState, weapon: Dictionary, style: DaocStyleDef = null, options: Dictionary = {}) -> DaocAttackData:
	if bool(options.get("use_dol_formulas", true)):
		return make_attack_dol(owner, target, weapon, style, options)
	return make_attack_p1_18b(owner, target, weapon, style, options)


## Un tirage entier déterministe dans `[0, bound[`, du même genre que celui de
## `DaocMeleeExchange.roll_percent`. DOL tire `Util.Random(50)` ; l'arbitre local
## ne peut pas se le permettre sans perdre la reproductibilité d'une session.
static func deterministic_roll(seed_value: int, salt: int, bound: int) -> int:
	if bound <= 0:
		return 0
	var mixed: int = seed_value * 1103515245 + salt * 12345 + 1013904223
	return absi(mixed) % bound


## P1-23B — la chaîne de `GameLiving.Attack`, dans son ordre.
func make_attack_dol(owner: DaocCombatEntityState, target: DaocCombatEntityState, weapon: Dictionary, style: DaocStyleDef = null, options: Dictionary = {}) -> DaocAttackData:
	var ad := DaocAttackData.new()
	ad.attacker = owner
	ad.target = target
	ad.attack_type = str(options.get("attack_type", DaocCombatEnums.ATTACK_MELEE_ONE_HAND))
	ad.attack_result = DaocCombatEnums.RESULT_HIT_UNSTYLED
	ad.damage_type = attack_damage_type(weapon, owner)
	if owner == null or target == null:
		return ad

	var level: int = maxi(0, owner.level)
	var quickness: int = int(owner.get_modified("Quickness", 60.0))
	var strength: int = int(owner.get_modified("Strength", 60.0))

	# 1. VITESSE ET DÉGÂTS BRUTS. La branche du joueur exige une arme décrite à
	#    la manière de DOL ; sans elle, c'est la branche `GameLiving`, et le coup
	#    le déclare au lieu de laisser croire qu'une arme a été lue.
	var has_dol_weapon: bool = weapon.has("DPS_AF") and weapon.has("SPD_ABS")
	var damage_basis := "DOL_CODE_LIVING_BRANCH"
	var interval: int = 0
	var attack_damage: float = 0.0
	var unstyled_cap: float = 0.0
	if owner.is_player and has_dol_weapon:
		var spd_abs: float = float(weapon.get("SPD_ABS", 30))
		var dps_af: int = int(weapon.get("DPS_AF", 16))
		interval = DolFormulas.player_attack_speed_msec(spd_abs, quickness)
		attack_damage = DolFormulas.player_attack_damage(dps_af, spd_abs, level)
		unstyled_cap = DolFormulas.player_unstyled_damage_cap(dps_af, spd_abs, level)
		damage_basis = "DOL_CODE_PLAYER_WEAPON"
	else:
		interval = DolFormulas.npc_attack_speed_msec(quickness)
		attack_damage = DolFormulas.npc_attack_damage(level, interval)
		unstyled_cap = DolFormulas.npc_unstyled_damage_cap(attack_damage, interval)
	ad.interval = int(options.get("interval", interval))

	# 2. COMPÉTENCE D'ARME. Celle du joueur passe par le `BaseWeaponSkill` de son
	#    métier ; celle d'un PNJ par la formule générique de `GameLiving`, dont
	#    le commentaire d'origine prévient : « base factor (not 400) ».
	var weapon_skill: float = 0.0
	if owner.is_player:
		weapon_skill = DolFormulas.player_weapon_skill(level, FIXTURE_CLASS_WEAPON_SKILL_BASE, strength)
	else:
		weapon_skill = DolFormulas.npc_weapon_skill(level, strength)

	# 3. DÉFENSE DE LA CIBLE.
	#
	#    P1-24 — UNE CIBLE PEUT ENFIN PORTER UNE ARMURE. `options.target_armor`
	#    donne les pièces par logement ; le coup en tire une selon la table de
	#    `CalculateArmorHitLocation` — 40 % torse, 25 % jambes, 15 % bras, 10 %
	#    tête, 5 % mains, 5 % pieds — et lit SON facteur et SON absorption.
	#
	#    Sans armure, on garde le chemin d'avant : facteur nul, absorption tirée
	#    du seul palier de niveau et de la constitution. C'est ce que DOL calcule
	#    pour un PNJ, qui n'a pas d'inventaire.
	var target_armor: Dictionary = options.get("target_armor", {}) as Dictionary
	var armor_af: float = DolFormulas.npc_armor_af(target.get_modified("ArmorFactor", 0.0))
	var target_constitution: int = int(target.get_modified("Constitution", 60.0))
	var absorb: float = DolFormulas.living_armor_absorb(target.level, target_constitution)
	var hit_location: int = 0
	var armor_basis := "DOL_CODE_BARE"
	if not target_armor.is_empty():
		var location_roll: int = deterministic_roll(int(options.get("seed", 0)) + target.entity_id, 61, 100) + 1
		hit_location = DolFormulas.armor_hit_location(location_roll)
		var piece: Dictionary = target_armor.get(hit_location, {}) as Dictionary
		if not piece.is_empty():
			armor_af = DolFormulas.player_armor_af(
				float(piece.get("dps_af", 0)),
				target.level,
				int(piece.get("object_type", 0)) == DolFormulas.OBJECT_TYPE_CLOTH,
				int(piece.get("quality", 100)),
				int(piece.get("condition", 100)),
				int(piece.get("max_condition", 100))
			)
			absorb = DolFormulas.player_armor_absorb(int(piece.get("spd_abs", 0)))
			armor_basis = "DUMP_STARTER"
		else:
			# UN LOGEMENT NU EST UN VRAI CAS, pas un repli : DOL rend zéro pour un
			# emplacement vide, et un coup sur une épaule sans armure fait mal.
			armor_basis = "DOL_CODE_EMPTY_SLOT"
			armor_af = 0.0
			absorb = 0.0

	# 4. LA CHAÎNE, ordre de DOL, avec le tirage rendu déterministe.
	var seed_value: int = int(options.get("seed", 0)) + owner.entity_id
	var variance: int = deterministic_roll(seed_value, 97, 50)
	var resist: float = target.get_resist_percent(ad.damage_type)
	# P1-27 — LE NIVEAU DE SPECIALISATION DE L ARME, enfin autre chose que 1.
	#
	# `GamePlayer.WeaponSpecLevel` passe par le `Object_Type` de l arme
	# (GamePlayer.cs:6870) ; l auto-entrainement fait monter certaines
	# specialisations jusqu a `niveau / 4` sans depense.
	#
	# CE QUE LA SPECIALISATION FAIT, VERIFIE ET NON SUPPOSE. Le premier jet de ce
	# commentaire disait « elle releve la borne basse, jamais le plafond ». Faux :
	# DOL calcule `degats * (borne_basse + alea(50)) * 0,01`, donc relever la
	# borne basse DECALE TOUTE LA FENETRE vers le haut — plancher et plafond
	# montent d autant, la largeur de 50 points ne bougeant pas.
	#
	# Un specialiste frappe donc plus FORT en moyenne, et sa variance RELATIVE se
	# resserre parce que la meme largeur de 50 pese moins sur un plus grand
	# nombre. Ce n est pas la meme chose que « plus regulierement ».
	var weapon_spec_level: int = 1
	var weapon_spec: String = DolFormulas.spec_for_object_type(int(weapon.get("object_type", -1)))
	if weapon_spec != "":
		weapon_spec_level = maxi(1, int(owner.get_spec_level(weapon_spec, 1.0)))

	var resolved: Dictionary = DolFormulas.melee_damage(
		attack_damage, weapon_skill, armor_af, absorb, unstyled_cap,
		variance, weapon_spec_level, target.level, resist
	)

	ad.base_damage = attack_damage
	ad.base_damage_cap = unstyled_cap
	ad.damage = int(resolved.get("damage", 1))
	ad.modifier = int(resolved.get("modifier", 0))
	ad.critical_chance = calculate_critical_chance(owner, ad.attack_type)
	var crit_pct: float = DaocDamageVariance.deterministic_crit_percent(float(ad.critical_chance), seed_value, 1.0)
	ad.critical_damage = int(floor(float(ad.damage) * crit_pct))
	if style != null:
		# P1-29 — LE STYLE A BESOIN DE L'ARME ET DE LA SPÉCIALISATION. Le
		# processeur ne peut pas les deviner : il les reçoit, et ses valeurs par
		# défaut sont NEUTRES — un DPS de zéro annule les dégâts de style, ce qui
		# est le comportement de DOL pour une arme absente.
		var style_options: Dictionary = options.duplicate()
		style_options["weapon_dps_af"] = int(weapon.get("DPS_AF", 0))
		style_options["weapon_spd_abs"] = int(weapon.get("SPD_ABS", 0))
		style_options["attack_speed_msec"] = ad.interval
		style_options["spec_level"] = weapon_spec_level
		var proc := DaocStyleProcessor.new()
		proc.execute_style(ad, style, style_options)
	ad.armor_hit_location = str(hit_location) if hit_location > 0 else "NOTSET"
	ad.notes.append({
		"source": "DaocAttackComponent/DOL",
		"damage_basis": damage_basis,
		"armor_basis": armor_basis,
		"armor_hit_location": hit_location,
		"weapon_skill": weapon_skill,
		"target_absorb": absorb,
		"target_armor_af": armor_af,
		"lower_boundary": int(resolved.get("lower_boundary", 75)),
		"weapon_spec": weapon_spec,
		"weapon_spec_level": weapon_spec_level,
		"capped": bool(resolved.get("capped", false)),
		"prediction_only": true,
	})
	return ad


## La chaîne de P1-18B, conservée pour la contre-épreuve. Plus appelée par
## défaut : elle n'a ni absorption, ni rapport arme/armure, ni variance, et son
## plafond à trois fois les dégâts de base ne vient d'aucune source.
func make_attack_p1_18b(owner: DaocCombatEntityState, target: DaocCombatEntityState, weapon: Dictionary, style: DaocStyleDef = null, options: Dictionary = {}) -> DaocAttackData:
	var ad = DaocAttackData.new()
	ad.attacker = owner
	ad.target = target
	ad.attack_type = str(options.get("attack_type", DaocCombatEnums.ATTACK_MELEE_ONE_HAND))
	ad.attack_result = DaocCombatEnums.RESULT_HIT_UNSTYLED
	ad.damage_type = attack_damage_type(weapon, owner)
	ad.interval = int(options.get("interval", attack_speed(owner, weapon)))
	ad.critical_chance = calculate_critical_chance(owner, ad.attack_type)
	var weapon_dps = float(weapon.get("DPS_AF", weapon.get("dps", 16.5)))
	var weapon_speed = float(weapon.get("SPD_ABS", weapon.get("speed", 25))) * 0.1
	var stat = owner.get_modified("Strength", 60.0) if owner != null else 60.0
	var base_damage_raw = maxf(1.0, weapon_dps * weapon_speed * (0.75 + stat / 400.0))
	var resist = target.get_resist_percent(ad.damage_type) if target != null else 0.0
	ad.base_damage = maxf(0.0, base_damage_raw - base_damage_raw * resist * 0.01)
	ad.base_damage_cap = ad.base_damage * 3.0
	ad.damage = int(floor(ad.base_damage))
	var seed = int(options.get("seed", 0)) + (owner.entity_id if owner != null else 0)
	var crit_pct = DaocDamageVariance.deterministic_crit_percent(float(ad.critical_chance), seed, 1.0)
	ad.critical_damage = int(floor(float(ad.damage) * crit_pct))
	if style != null:
		var proc = DaocStyleProcessor.new()
		proc.execute_style(ad, style, options)
	ad.notes.append({"source": "AttackComponent/WeaponAction inspired", "prediction_only": true})
	return ad
