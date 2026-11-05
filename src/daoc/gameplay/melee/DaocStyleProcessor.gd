extends RefCounted
class_name DaocStyleProcessor

## P1-18B — l'exécution d'un style. P1-29 y branche la formule de DOL.
##
## CE QUE P1-29 A CORRIGÉ. La formule d'origine était inventée :
## `dégâts non stylés * GrowthRate`, moitié moins si le style « échouait ». Elle
## ignorait TROIS choses que DOL calcule :
##
##   - **le seuil de DPS.** `absorbRatio` reste à zéro sous 15 de DPS, et comme
##     les dégâts de style sont un produit, **tout s'annule**. Une arme faible ne
##     tire aucun bénéfice d'un style ;
##   - **le niveau de spécialisation.** La croissance vaut
##     `GrowthOffset + GrowthRate * spé` : sans spé, un style à offset nul — tous
##     ceux du dump — ne vaut rien ;
##   - **la vitesse de l'arme**, qui multiplie le résultat en secondes. Une arme
##     lente frappe moins souvent mais son style rend davantage.
##
## Et un style raté ne rend pas « moitié dégâts » : il ne rend RIEN, et coûte la
## moitié de son endurance.

const DolFormulas = preload("res://src/daoc/gameplay/rules/DaocDolFormulas.gd")

func can_use_style(last_attack: DaocAttackData, living: DaocCombatEntityState, target: DaocCombatEntityState, style: DaocStyleDef, options: Dictionary = {}) -> Dictionary:
	var out = {"ok": true, "reason": "ok", "source": "StyleProcessor.cs"}
	if living == null or target == null or style == null:
		out["ok"] = false
		out["reason"] = "missing living/target/style"
		return out
	if not living.is_alive:
		out["ok"] = false
		out["reason"] = "living dead"
		return out
	if style.stealth_requirement and not bool(options.get("is_stealthed", false)):
		out["ok"] = false
		out["reason"] = "stealth required"
		return out
	# P1-31B — LES TROIS OUVERTURES DE `Style.eOpening`, portees depuis
	# StyleProcessor.cs:85-163. Jusqu'ici seule la branche OFFENSIVE existait, et
	# encore : sans sa condition d'ENCHAINEMENT.
	#
	# LA DISTINCTION QUI COMPTE, et qu'un seul `last_attack` ne peut pas rendre :
	# une ouverture offensive regarde le coup que J'AI porte ; une ouverture
	# DEFENSIVE regarde le coup que L'ADVERSAIRE m'a porte. Confondre les deux
	# rendrait toute la famille defensive - les ripostes apres parade, blocage ou
	# esquive - soit toujours refusee, soit toujours accordee.
	var opening := style.opening_requirement_type.to_lower()
	if opening == "defensive":
		var enemy_attack: DaocAttackData = options.get("target_last_attack", null) as DaocAttackData
		if style.attack_result_requirement != "Any":
			# `targetsLastAD.Target != living` dans la source : le coup doit avoir
			# ete porte SUR MOI. Un adversaire qui frappe quelqu'un d'autre
			# n'ouvre rien.
			if enemy_attack == null or enemy_attack.target != living:
				out["ok"] = false
				out["reason"] = "defensive opening requires an attack on you"
				return out
			if enemy_attack.attack_result != style.attack_result_requirement:
				out["ok"] = false
				out["reason"] = "defensive opening requires %s" % style.attack_result_requirement
				return out
	elif opening == "offensive":
		# L'ENCHAINEMENT : `OpeningRequirementValue` non nul designe le style qui
		# doit PRECEDER celui-ci. Trois conditions, et la troisieme est facile a
		# oublier — « style chains are possible only on the same target ».
		if style.opening_requirement_value != 0:
			var previous_style: Dictionary = {} if last_attack == null else last_attack.style
			if last_attack == null \
					or last_attack.attack_result != DaocCombatEnums.RESULT_HIT_STYLE \
					or previous_style.is_empty() \
					or int(previous_style.get("id", -1)) != style.opening_requirement_value \
					or last_attack.target != target:
				out["ok"] = false
				out["reason"] = "chain requires style %d on the same target" % style.opening_requirement_value
				return out
		if style.attack_result_requirement != "Any":
			if last_attack == null or last_attack.attack_result != style.attack_result_requirement:
				out["ok"] = false
				out["reason"] = "attack result requirement not met"
				return out
	if opening == "positional":
		# P1-31 — LA CORRESPONDANCE ETAIT DECALEE D'UN CRAN, et personne ne
		# pouvait s'en apercevoir tant qu'aucun style n'etait declenche.
		# `Style.eOpeningPosition` (Style.cs:56-70) dit Back = 0, Side = 1,
		# Front = 2 ; ce code comparait a « 1 » pour le dos et « 2 » pour le
		# flanc. Un style « dans le dos » etait donc exigible DE FACE, et un
		# style de flanc n'etait JAMAIS executable.
		#
		# P1-31B — ET LA POSITION N'EST PAS CALCULABLE ICI. DOL la tire de
		# `target.GetAngleTo(living.Coordinate)` compare au CAP de la cible
		# (StyleProcessor.cs:140-162) : dos entre 150 et 210 degres, flanc entre
		# 45-150 et 210-315, face au-dela de 315 ou sous 45. L'arbitre local ne
		# tient AUCUN cap — ni pour les PNJ, ni pour le joueur, dont l'orientation
		# vit cote client dans la capsule.
		#
		# Le defaut « front » qui trainait ici etait donc une INVENTION SILENCIEUSE
		# a double detente : il accordait tous les styles de face sans rien
		# mesurer, et refusait dos et flanc sans jamais dire pourquoi. Une
		# position ABSENTE est desormais un refus NOMME.
		var position := str(options.get("relative_position", "")).to_lower()
		if position == "":
			out["ok"] = false
			out["reason"] = "positional styles need a heading the authority does not hold"
			return out
		var required := str(DaocStyleIndex.POSITION_NAME_BY_ID.get(
			int(style.opening_requirement_value), ""))
		if required != "" and position != required:
			out["ok"] = false
			out["reason"] = "%s positional required" % required
	if living.endurance < style.endurance_cost:
		out["ok"] = false
		out["reason"] = "not enough endurance"
	return out

## Le point d'entrée. Route vers l'une des deux formules, et n'en mélange aucune.
func execute_style(base_attack: DaocAttackData, style: DaocStyleDef, options: Dictionary = {}) -> Dictionary:
	if bool(options.get("use_dol_formulas", true)):
		return execute_style_dol(base_attack, style, options)
	return execute_style_p1_18b(base_attack, style, options)


## P1-29 — `StyleProcessor.ExecuteStyle`, StyleProcessor.cs:407-438.
##
## CE QUE L'APPELANT DOIT FOURNIR, et pourquoi ce n'est pas devinable ici :
## `weapon_dps_af`, `attack_speed_msec` et `spec_level` appartiennent à
## l'attaquant et à son arme. Les valeurs par défaut sont NEUTRES et non
## plausibles — un DPS de zéro annule les dégâts de style, ce qui est le
## comportement de DOL pour une arme absente, pas un repli inventé.
func execute_style_dol(base_attack: DaocAttackData, style: DaocStyleDef, options: Dictionary = {}) -> Dictionary:
	var out := {
		"ok": false, "style_damage": 0, "animation_id": 0,
		"source": "StyleProcessor.ExecuteStyle",
	}
	if base_attack == null or style == null:
		out["reason"] = "missing base attack/style"
		return out

	var resolved: Dictionary = DolFormulas.style_damage(
		base_attack.damage,
		base_attack.base_damage_cap,
		int(options.get("weapon_dps_af", 0)),
		int(options.get("attack_speed_msec", base_attack.interval)),
		style.growth_rate,
		style.growth_offset,
		int(options.get("spec_level", 1)),
		style.stealth_requirement
	)

	base_attack.style = style.to_dict()
	base_attack.style_damage = int(resolved.get("style_damage", 0))
	base_attack.damage += base_attack.style_damage
	base_attack.animation_id = style.animation_id
	base_attack.attack_result = DaocCombatEnums.RESULT_HIT_STYLE

	out["ok"] = true
	out["style_damage"] = base_attack.style_damage
	out["absorb_ratio"] = float(resolved.get("absorb_ratio", 0.0))
	out["style_growth"] = float(resolved.get("style_growth", 0.0))
	# LE SEUIL EST DIT, jamais subi en silence : un style qui ne rend rien parce
	# que l'arme est trop faible doit pouvoir s'expliquer.
	out["below_dps_threshold"] = bool(resolved.get("below_dps_threshold", false))
	out["endurance_cost"] = DolFormulas.style_endurance_cost(
		int(options.get("weapon_spd_abs", 0)), style.endurance_cost
	)
	out["basis"] = DolFormulas.BASIS_DOL_CODE
	out["animation_id"] = style.animation_id
	return out


## La formule de P1-18B, conservée pour la contre-épreuve.
func execute_style_p1_18b(base_attack: DaocAttackData, style: DaocStyleDef, options: Dictionary = {}) -> Dictionary:
	var out = {"ok": false, "style_damage": 0, "style_damage_cap": 0, "animation_id": 0, "source": "StyleProcessor.ExecuteStyle"}
	if base_attack == null or style == null:
		out["reason"] = "missing base attack/style"
		return out
	var perfect = bool(options.get("perfect", true))
	var unstyled = float(base_attack.damage)
	var style_damage = 0.0
	if perfect:
		style_damage = unstyled * maxf(0.0, style.growth_rate)
	else:
		style_damage = unstyled * maxf(0.0, style.growth_rate) * 0.5
	base_attack.style = style.to_dict()
	base_attack.style_damage = int(floor(style_damage))
	base_attack.damage += base_attack.style_damage
	base_attack.animation_id = style.animation_id
	base_attack.attack_result = DaocCombatEnums.RESULT_HIT_STYLE
	out["ok"] = true
	out["perfect"] = perfect
	out["style_damage"] = base_attack.style_damage
	out["style_damage_cap"] = int(floor(base_attack.base_damage_cap * maxf(0.0, style.growth_rate)))
	out["animation_id"] = style.animation_id
	out["attack"] = base_attack.to_dict()
	return out
