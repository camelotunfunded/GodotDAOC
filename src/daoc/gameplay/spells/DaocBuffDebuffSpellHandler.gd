extends DaocSpellHandler
class_name DaocBuffDebuffSpellHandler

const DaocActiveEffectScript = preload("res://src/daoc/gameplay/effects/DaocActiveEffect.gd")

## P1-18G — offline Buff/Debuff state model.
## Produces structured active effects only; final stat math remains server-authoritative.

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "BuffDebuff"

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.ok = caster != null and target != null and spell != null
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if spell == null:
		result.messages = ["missing spell"]
		return result.to_dict()
	if caster == null or target == null:
		result.messages = ["missing caster or target"]
		return result.to_dict()
	var descriptor: Dictionary = _descriptor_for_spell_type(spell.spell_type)
	if descriptor.is_empty():
		result.ok = false
		result.effects.append({
			"effect_type": "unsupported_buff_debuff",
			"spell_type": spell.spell_type,
			"prediction_only": true,
			"server_authority": true,
			"damage_final": false,
		})
		result.messages = ["Unsupported buff/debuff type %s is reported, not routed to damage." % spell.spell_type]
		return result.to_dict()
	descriptor["modifier_value"] = _predicted_modifier_value(descriptor)
	var active_effect: RefCounted = DaocActiveEffectScript.new()
	active_effect.call("setup_from_spell", spell, caster, target, descriptor)
	result.effects.append(active_effect.to_dict())
	result.messages = ["%s predicts active %s effect %s on %s." % [spell.name, str(descriptor.get("effect_category", "utility")), spell.spell_type, target.name]]
	return result.to_dict()

func _predicted_modifier_value(descriptor: Dictionary) -> float:
	var value: float = spell.value if spell != null else 0.0
	if value == 0.0 and spell != null:
		value = spell.damage
	if bool(descriptor.get("is_debuff", false)):
		return -absf(value)
	return absf(value)

func _descriptor_for_spell_type(type_name: String) -> Dictionary:
	var t: String = type_name
	if t in ["StrengthBuff", "StrengthDebuff"]:
		return _stat("Strength", t.ends_with("Debuff"))
	if t in ["DexterityBuff", "DexterityDebuff"]:
		return _stat("Dexterity", t.ends_with("Debuff"))
	if t in ["ConstitutionBuff", "ConstitutionDebuff"]:
		return _stat("Constitution", t.ends_with("Debuff"))
	if t in ["QuicknessBuff", "QuicknessDebuff"]:
		return _stat("Quickness", t.ends_with("Debuff"))
	if t in ["AcuityBuff", "AcuityDebuff"]:
		return _stat("Acuity", t.ends_with("Debuff"))
	if t in ["StrengthConstitutionBuff", "StrengthConstitutionDebuff"]:
		return _stat_pair("StrengthConstitution", t.ends_with("Debuff"))
	if t in ["DexterityQuicknessBuff", "DexterityQuicknessDebuff"]:
		return _stat_pair("DexterityQuickness", t.ends_with("Debuff"))
	if t in ["DexterityConstitutionBuff", "DexterityConstitutionDebuff"]:
		return _stat_pair("DexterityConstitution", t.ends_with("Debuff"))
	if t in ["HeatResistBuff", "HeatResistDebuff"]:
		return _resist("Heat", t.ends_with("Debuff"))
	if t in ["ColdResistBuff", "ColdResistDebuff"]:
		return _resist("Cold", t.ends_with("Debuff"))
	if t in ["MatterResistBuff", "MatterResistDebuff"]:
		return _resist("Matter", t.ends_with("Debuff"))
	if t in ["BodyResistBuff", "BodyResistDebuff"]:
		return _resist("Body", t.ends_with("Debuff"))
	if t in ["SpiritResistBuff", "SpiritResistDebuff"]:
		return _resist("Spirit", t.ends_with("Debuff"))
	if t in ["EnergyResistBuff", "EnergyResistDebuff"]:
		return _resist("Energy", t.ends_with("Debuff"))
	if t in ["SlashResistBuff", "SlashResistDebuff", "SavageSlashResistanceBuff"]:
		return _resist("Slash", t.ends_with("Debuff"))
	if t == "SavageThrustResistanceBuff":
		return _resist("Thrust", false)
	if t == "SavageCrushResistanceBuff":
		return _resist("Crush", false)
	if t == "HeatColdMatterBuff":
		return _resist("HeatColdMatter", false)
	if t == "BodySpiritEnergyBuff":
		return _resist("BodySpiritEnergy", false)
	if t in ["ArmorFactorDebuff"]:
		return _armor("ArmorFactor", true)
	if t in ["ArmorAbsorptionDebuff"]:
		return _armor("ArmorAbsorption", true)
	if t in ["ArmorFactorBuff", "BaseArmorFactorBuff", "SpecArmorFactorBuff", "PaladinArmorFactorBuff"]:
		return _armor(t.replace("Buff", ""), false)
	if t in ["ArmorAbsorptionBuff", "AblativeArmor", "Bladeturn"]:
		return _armor(t, false)
	if t in ["SpeedEnhancement", "CombatSpeedBuff", "CombatSpeedDebuff", "StyleCombatSpeedDebuff", "SavageCombatSpeedBuff"]:
		return _speed(t, t.ends_with("Debuff"))
	if t in ["PowerRegenBuff", "EnduranceRegenBuff", "AllRegenBuff", "PowerHealthEnduranceRegenBuff"]:
		return _regen(t)
	if t in ["MeleeDamageBuff", "MeleeDamageDebuff", "SavageDPSBuff", "SavageParryBuff", "SavageEvadeBuff", "SavageStyleParryBuff", "SavageStyleEvadeBuff"]:
		return _melee(t, t.ends_with("Debuff"))
	if t in ["FatigueConsumptionBuff", "AllStatsBarrel"]:
		return _utility(t, false)
	# P1-108 — les types que P1-35 laissait sans gestionnaire : un effet actif
	# NOMME, sans regle propre (DOL : ConfusionSpellHandler fait attaquer un
	# pet au hasard, Nearsight reduit la portee, Taunt gonfle l aggro,
	# Amnesia efface les styles memorises...). Le serveur tranche en ligne.
	if t in ["Confusion", "Amnesia", "Nearsight", "Taunt", "StyleTaunt", "PreventFlight", "FatigueConsumptionDebuff", "RvrResurrectionIllness"]:
		return _utility(t, true)
	if t in ["PiercingMagic", "NaturesShield", "StyleRange", "DefensiveProc", "CureNearsightCustom"]:
		return _utility(t, false)
	return {}

func _base(category: String, stat: String, kind: String, debuff: bool) -> Dictionary:
	return {
		"effect_category": category,
		"modifier_kind": kind,
		"modifier_stat": stat,
		"stacking_group": "%s:%s" % [category, stat],
		"is_buff": not debuff,
		"is_debuff": debuff,
		"is_regen": category == "regen",
		"is_resist": category == "resists",
		"is_speed": category == "speed",
	}

func _stat(stat: String, debuff: bool) -> Dictionary:
	return _base("stats", stat, "stat_delta", debuff)

func _stat_pair(stat: String, debuff: bool) -> Dictionary:
	return _base("stats", stat, "stat_pair_delta", debuff)

func _resist(stat: String, debuff: bool) -> Dictionary:
	return _base("resists", stat, "resist_percent_delta", debuff)

func _armor(stat: String, debuff: bool) -> Dictionary:
	return _base("armor", stat, "armor_delta", debuff)

func _speed(stat: String, debuff: bool) -> Dictionary:
	return _base("speed", stat, "speed_delta", debuff)

func _regen(stat: String) -> Dictionary:
	return _base("regen", stat, "regen_delta", false)

func _melee(stat: String, debuff: bool) -> Dictionary:
	return _base("melee", stat, "melee_delta", debuff)

func _utility(stat: String, debuff: bool) -> Dictionary:
	return _base("utility", stat, "utility_delta", debuff)
