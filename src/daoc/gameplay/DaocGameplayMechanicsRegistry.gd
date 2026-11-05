extends RefCounted
class_name DaocGameplayMechanicsRegistry

const DirectDamageScript = preload("res://src/daoc/gameplay/spells/DaocDirectDamageSpellHandler.gd")
const DoTScript = preload("res://src/daoc/gameplay/spells/DaocDoTSpellHandler.gd")
const BoltScript = preload("res://src/daoc/gameplay/spells/DaocBoltSpellHandler.gd")
const HealScript = preload("res://src/daoc/gameplay/spells/DaocHealSpellHandler.gd")
const DamageSpeedDecreaseScript = preload("res://src/daoc/gameplay/spells/DaocDamageSpeedDecreaseSpellHandler.gd")
const DamageAddScript = preload("res://src/daoc/gameplay/spells/DaocDamageAddSpellHandler.gd")
const DamageShieldScript = preload("res://src/daoc/gameplay/spells/DaocDamageShieldSpellHandler.gd")
const CrowdControlScript = preload("res://src/daoc/gameplay/spells/DaocCrowdControlSpellHandler.gd")
const LifeDrainScript = preload("res://src/daoc/gameplay/spells/DaocLifeDrainSpellHandler.gd")
const DirectDamageWithDebuffScript = preload("res://src/daoc/gameplay/spells/DaocDirectDamageWithDebuffSpellHandler.gd")
const HealOrResurrectScript = preload("res://src/daoc/gameplay/spells/DaocHealOrResurrectSpellHandler.gd")
const BuffDebuffScript = preload("res://src/daoc/gameplay/spells/DaocBuffDebuffSpellHandler.gd")
const DoTDiseaseProcScript = preload("res://src/daoc/gameplay/spells/DaocDoTDiseaseProcSpellHandler.gd")
const GenericDamageEffectScript = preload("res://src/daoc/gameplay/spells/DaocGenericDamageEffectSpellHandler.gd")
const PetScript = preload("res://src/daoc/gameplay/spells/DaocPetSpellHandler.gd")
const TravelScript = preload("res://src/daoc/gameplay/spells/DaocTravelSpellHandler.gd")
const ArcheryScript = preload("res://src/daoc/gameplay/spells/DaocArcherySpellHandler.gd")
const TauntScript = preload("res://src/daoc/gameplay/spells/DaocTauntSpellHandler.gd")
const AmnesiaScript = preload("res://src/daoc/gameplay/spells/DaocAmnesiaSpellHandler.gd")
const NearsightScript = preload("res://src/daoc/gameplay/spells/DaocNearsightSpellHandler.gd")
const ConfusionScript = preload("res://src/daoc/gameplay/spells/DaocConfusionSpellHandler.gd")
const LifeTransferScript = preload("res://src/daoc/gameplay/spells/DaocLifeTransferSpellHandler.gd")
const NoVarianceScript = preload("res://src/daoc/gameplay/spells/DaocNoVarianceSpellHandler.gd")
const ProcScript = preload("res://src/daoc/gameplay/spells/DaocProcSpellHandler.gd")
const FaithfulEffectScript = preload("res://src/daoc/gameplay/spells/DaocFaithfulEffectSpellHandler.gd")
const SummonPetScript = preload("res://src/daoc/gameplay/spells/DaocSummonPetSpellHandler.gd")

var handler_scripts: Dictionary = {}

func _init() -> void:
	register_default_handlers()

func register_default_handlers() -> void:
	handler_scripts.clear()
	handler_scripts[DaocCombatEnums.SPELL_DIRECT_DAMAGE] = DirectDamageScript
	handler_scripts[DaocCombatEnums.SPELL_DAMAGE_OVER_TIME] = DoTScript
	handler_scripts[DaocCombatEnums.SPELL_BOLT] = BoltScript
	handler_scripts[DaocCombatEnums.SPELL_HEAL] = HealScript
	handler_scripts[DaocCombatEnums.SPELL_DAMAGE_SPEED_DECREASE] = DamageSpeedDecreaseScript
	handler_scripts[DaocCombatEnums.SPELL_DAMAGE_ADD] = DamageAddScript
	handler_scripts[DaocCombatEnums.SPELL_DAMAGE_SHIELD] = DamageShieldScript
	_register_p1_18f_handlers()
	_register_p1_18g_buff_debuff_handlers()
	_register_p1_18h_dot_disease_proc_handlers()
	_register_p1_18i_generic_damage_effect_handlers()
	_register_p1_18j_pet_handlers()
	_register_p1_108_remaining_handlers()


## P1-108 — les 36 types que P1-35 comptait SANS gestionnaire (502 sorts),
## routes vers la famille la plus proche de leur `SpellHandler` DOL. Un sort
## route n est pas un sort FIDELE : l archerie tire comme un DirectDamage
## (DOL : ArcherySpellHandler herite de DirectDamage, le tir a l arc est un
## sort depuis 1.110), les pets restent des intentions (P1-18J), les debuffs
## exotiques (Confusion, Amnesia, Nearsight, Taunt...) ne portent qu un effet
## actif nomme sans regle propre. En ligne le serveur fait tout ; ceci ne
## sert que l arbitre local.
func p1_108_direct_damage_types() -> Array:
	return ["Archery", "SiegeArrow", "ArrowDamageTypes", "NightshadeNuke", "DirectDamageNoVariance", "MultiTarget"]


func p1_108_pet_types() -> Array:
	return ["PetSpell", "SummonNecroPet", "SummonNoveltyPet", "SummonSimulacrum", "SummonDruidPet",
		"SummonAnimistAmbusher", "SummonJuggernaut", "TurretsRelease", "PetConversion", "PowerTransferPet",
		"PowerDrainPet", "ComfortingFlames", "FacilitatePainworking", "EternalPlant"]


func p1_108_buff_debuff_types() -> Array:
	return ["Confusion", "Amnesia", "Nearsight", "Taunt", "StyleTaunt", "PreventFlight", "FatigueConsumptionDebuff",
		"RvrResurrectionIllness", "PiercingMagic", "CureNearsightCustom", "NaturesShield", "StyleRange", "DefensiveProc"]


func p1_108_travel_types() -> Array:
	return ["GatewayPersonalBind", "UniPortal"]


func _register_p1_108_remaining_handlers() -> void:
	for spell_type in p1_108_direct_damage_types():
		handler_scripts[str(spell_type)] = DirectDamageScript
	for spell_type in p1_108_pet_types():
		handler_scripts[str(spell_type)] = PetScript
	for spell_type in p1_108_buff_debuff_types():
		handler_scripts[str(spell_type)] = BuffDebuffScript
	for spell_type in p1_108_travel_types():
		handler_scripts[str(spell_type)] = TravelScript
	handler_scripts["LifeTransfer"] = HealOrResurrectScript
	_register_p1_109_faithful_handlers()


## P1-109 — sept des 36 types routes par P1-108 recoivent leur REGLE DOL :
## Archery / SiegeArrow / ArrowDamageTypes (endurance, base x (Dex+300)/275,
## x1,57 PNJ), Taunt / StyleTaunt (aggro), Amnesia (oubli de l aggro),
## Nearsight (portee -Value %), Confusion (retarget aleatoire), LifeTransfer
## (le lanceur paie la moitie). Les 28 autres restent routes (voir P1-108).
func p1_109_faithful_types() -> Dictionary:
	return {"Archery": ArcheryScript, "SiegeArrow": ArcheryScript, "ArrowDamageTypes": ArcheryScript,
		"Taunt": TauntScript, "StyleTaunt": TauntScript, "Amnesia": AmnesiaScript, "Nearsight": NearsightScript,
		"Confusion": ConfusionScript, "LifeTransfer": LifeTransferScript}


func _register_p1_109_faithful_handlers() -> void:
	var faithful := p1_109_faithful_types()
	for spell_type in faithful.keys():
		handler_scripts[str(spell_type)] = faithful[spell_type]
	_register_p1_123_faithful_handlers()


## P1-123 — les types restants de P1-108 recoivent leur regle OpenDAoC (hors
## pets, P1-124). Trois types de la base n'ont AUCUN gestionnaire dans
## OpenDAoC (CureNearsightCustom, ComfortingFlames, EternalPlant) : le serveur
## ne sait pas les lancer, l'arbitre local non plus — ils sont retires.
func p1_123_faithful_types() -> Dictionary:
	return {"DirectDamageNoVariance": NoVarianceScript, "NightshadeNuke": DirectDamageScript,
		"OffensiveProc": ProcScript, "OffensiveProcPvE": ProcScript, "DefensiveProc": ProcScript,
		"PreventFlight": FaithfulEffectScript, "FatigueConsumptionDebuff": FaithfulEffectScript,
		"RvrResurrectionIllness": FaithfulEffectScript, "PveResurrectionIllness": FaithfulEffectScript,
		"PiercingMagic": FaithfulEffectScript, "CureNearsight": FaithfulEffectScript,
		"MultiTarget": FaithfulEffectScript, "NaturesShield": FaithfulEffectScript, "StyleRange": FaithfulEffectScript,
		"GatewayPersonalBind": TravelScript, "UniPortal": TravelScript}


func p1_123_types_without_server_handler() -> Array:
	return ["CureNearsightCustom", "ComfortingFlames", "EternalPlant"]


func _register_p1_123_faithful_handlers() -> void:
	var faithful := p1_123_faithful_types()
	for spell_type in faithful.keys():
		handler_scripts[str(spell_type)] = faithful[spell_type]
	for spell_type in p1_123_types_without_server_handler():
		handler_scripts.erase(str(spell_type))
	for spell_type in p1_124_pet_types():
		handler_scripts[str(spell_type)] = SummonPetScript


## P1-124 — les familiers vivent dans l'arbitre local (DaocSummonPetSpellHandler +
## DaocLocalServer.summon_pet). Charm et les armes de siege restent des
## intentions (P1-18J) : ce ne sont pas des invocations de npctemplate.
func p1_124_pet_types() -> Array:
	var out: Array = []
	for spell_type in p1_18j_pet_types() + p1_108_pet_types():
		var name := str(spell_type)
		if name == "Charm" or name.begins_with("SummonSiege") or p1_123_types_without_server_handler().has(name):
			continue
		out.append(name)
	return out


func _register_p1_18f_handlers() -> void:
	var crowd_control_types: Array = [
		"SpeedDecrease",
		"Mesmerize",
		"Stun",
		"StyleSpeedDecrease",
		"UnbreakableSpeedDecrease",
		"StyleStun",
		"CureMezz",
		"MesmerizeDurationBuff",
	]
	for spell_type in crowd_control_types:
		handler_scripts[str(spell_type)] = CrowdControlScript
	handler_scripts["Lifedrain"] = LifeDrainScript
	handler_scripts["DirectDamageWithDebuff"] = DirectDamageWithDebuffScript
	var heal_or_resurrect_types: Array = [
		"HealthRegenBuff",
		"ConstitutionBuff",
		"Resurrect",
		"HealOverTime",
		"BodyResistBuff",
		"PowerHeal",
		"CombatHeal",
		"BodyResistDebuff",
		"EnduranceHeal",
		"SpreadHeal",
		"SavageEnduranceHeal",
		"PowerHealthEnduranceRegenBuff",
		"PveResurrectionIllness",
	]
	for spell_type in heal_or_resurrect_types:
		handler_scripts[str(spell_type)] = HealOrResurrectScript

func _register_p1_18g_buff_debuff_handlers() -> void:
	for spell_type in p1_18g_buff_debuff_types():
		handler_scripts[str(spell_type)] = BuffDebuffScript

func p1_18g_buff_debuff_types() -> Array:
	return [
		"BaseArmorFactorBuff",
		"CombatSpeedBuff",
		"StrengthConstitutionBuff",
		"DexterityQuicknessBuff",
		"SpeedEnhancement",
		"CombatSpeedDebuff",
		"ArmorAbsorptionBuff",
		"AblativeArmor",
		"Bladeturn",
		"SpecArmorFactorBuff",
		"PowerRegenBuff",
		"StrengthDebuff",
		"StrengthConstitutionDebuff",
		"MeleeDamageDebuff",
		"DexterityDebuff",
		"StrengthBuff",
		"DexterityQuicknessDebuff",
		"EnduranceRegenBuff",
		"DexterityBuff",
		"HeatResistBuff",
		"AcuityBuff",
		"ColdResistBuff",
		"EnergyResistBuff",
		"MatterResistBuff",
		"SpiritResistBuff",
		"StyleCombatSpeedDebuff",
		"PaladinArmorFactorBuff",
		"SavageSlashResistanceBuff",
		"SavageParryBuff",
		"HeatColdMatterBuff",
		"ArmorAbsorptionDebuff",
		"SavageDPSBuff",
		"SavageThrustResistanceBuff",
		"BodySpiritEnergyBuff",
		"SavageCrushResistanceBuff",
		"SpiritResistDebuff",
		"EnergyResistDebuff",
		"ConstitutionDebuff",
		"SavageEvadeBuff",
		"HeatResistDebuff",
		"ColdResistDebuff",
		"MatterResistDebuff",
		"SavageCombatSpeedBuff",
		"DexterityConstitutionDebuff",
		"FatigueConsumptionBuff",
		"MeleeDamageBuff",
		"SavageStyleParryBuff",
		"SlashResistDebuff",
		"ArmorFactorDebuff",
		"AllStatsBarrel",
		"AllRegenBuff",
		"SavageStyleEvadeBuff",
	]

func _register_p1_18h_dot_disease_proc_handlers() -> void:
	for spell_type in p1_18h_dot_disease_proc_types():
		handler_scripts[str(spell_type)] = DoTDiseaseProcScript

func p1_18h_dot_disease_proc_types() -> Array:
	return [
		"OffensiveProc",
		"Disease",
		"ArcheryDoT",
		"StyleBleeding",
		"CurePoison",
		"CureDisease",
	]

func _register_p1_18i_generic_damage_effect_handlers() -> void:
	for spell_type in p1_18i_generic_damage_effect_types():
		handler_scripts[str(spell_type)] = GenericDamageEffectScript

func p1_18i_generic_damage_effect_types() -> Array:
	return [
		"Bomber",
		"TurretPBAoE",
		"FrontalPulseConeDD",
	]

func _register_p1_18j_pet_handlers() -> void:
	for spell_type in p1_18j_pet_types():
		handler_scripts[str(spell_type)] = PetScript

func p1_18j_pet_types() -> Array:
	return [
		"SummonAnimistFnF",
		"SummonMinion",
		"SummonAnimistPet",
		"Charm",
		"SummonTheurgistPet",
		"SummonHunterPet",
		"SummonCommander",
		"SummonSpiritFighter",
		"SummonUnderhill",
		"SummonSiegeRam",
		"SummonSiegeBallista",
		"SummonSiegeCatapult",
		"SummonSiegeTrebuchet",
	]

func create_handler(spell: DaocSpellDef, spell_line: String = "") -> DaocSpellHandler:
	if spell == null:
		return null
	var script: Script = handler_scripts.get(spell.spell_type, null) as Script
	if script == null:
		return null
	var h: DaocSpellHandler = script.new() as DaocSpellHandler
	h.setup(spell, spell_line if spell_line != "" else spell.spec_line)
	return h

func snapshot() -> Dictionary:
	var types: Array = []
	for key in handler_scripts.keys():
		types.append(str(key))
	types.sort()
	return {"checkpoint": "P1_18B_GAMEPLAY_MECHANICS_REGISTRY", "handler_count": types.size(), "spell_types": types, "guardrails": DaocGameplayAuthority.guardrails()}
