extends DaocDirectDamageSpellHandler
class_name DaocArcherySpellHandler

## P1-109 — l archerie FIDELE a DOL (`spells/Archery/Archery.cs`), et non plus
## un DirectDamage ordinaire (P1-108 la routait). Ce que DOL fait de plus :
##   - le cout est en ENDURANCE : MaxEndurance x Power %, jamais de mana ;
##   - la base est Spell.Damage x (stat de mana + 300) / 275 (Dexterite pour
##     un archer) ;
##   - contre un PNJ qui n est pas un pet, les degats sont x 1,57 ; un tir de
##     zone (« area ») est x 0,815 ;
##   - le facteur de niveau (GetLevelModFactor) est 0,025 au lieu de 0,05 ;
##   - le temps de tir baisse avec la Dexterite : -0,15 % par point au-dessus
##     de 60, -0,05 % de plus au-dessus de 250 ;
##   - la chance de toucher n a pas de plancher a 5 % : 100 + bonus - con.
## Le SiegeArrow (SiegeShot.cs) et les ArrowDamageTypes suivent la meme base.

const NPC_DAMAGE_FACTOR := 1.57
const AREA_DAMAGE_FACTOR := 0.815


func mechanism_id() -> String:
	return "Archery"


func power_cost(_target: DaocCombatEntityState = null) -> int:
	return 0


func endurance_cost(caster: DaocCombatEntityState) -> int:
	if spell == null or caster == null:
		return 0
	return int(float(caster.max_endurance) * float(spell.power) * 0.01)


func calculate_damage_base(_target: DaocCombatEntityState) -> float:
	if spell == null:
		return 0.0
	return maxf(0.0, spell.damage)


static func damage_base_for(spell_damage: float, mana_stat_value: float) -> float:
	return maxf(0.0, spell_damage * (mana_stat_value + 300.0) / 275.0)


## Archery.CalculateCastingTime : la Dexterite raccourcit le tir.
static func casting_time_msec(base_msec: int, dexterity: int, casting_speed_percent: float = 0.0) -> int:
	var percent := 1.0
	if dexterity >= 250:
		percent = 1.0 - (float(dexterity - 60) * 0.15 + float(dexterity - 250) * 0.05) * 0.01
	elif dexterity >= 60:
		percent = 1.0 - float(dexterity - 60) * 0.15 * 0.01
	percent *= 1.0 - casting_speed_percent * 0.01
	return int(float(base_msec) * maxf(0.4, percent))


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	if caster == null or target == null or not target.is_alive:
		var empty = DaocCombatResult.new()
		empty.ok = false
		empty.mechanism = mechanism_id()
		empty.messages = ["invalid or dead target"]
		empty.guardrails = DaocGameplayAuthority.result_guard()
		return empty.to_dict()
	var cost := endurance_cost(caster)
	if caster.endurance < cost:
		var refused = DaocCombatResult.new()
		refused.ok = false
		refused.mechanism = mechanism_id()
		refused.messages = ["not enough endurance (%d needed, %d available)" % [cost, caster.endurance]]
		refused.guardrails = DaocGameplayAuthority.result_guard()
		return refused.to_dict()
	var mana_stat := caster.get_modified("Dexterity", 60.0)
	var ad := calculate_damage_to_target(caster, target, options)
	# La base DOL remplace celle du DirectDamage : Damage x (stat + 300) / 275.
	var scale := (mana_stat + 300.0) / 275.0
	var damage := float(ad.damage) * scale
	if not target.is_player and not bool(options.get("target_is_pet", false)):
		damage *= NPC_DAMAGE_FACTOR
	if spell.target.to_lower() == "area":
		damage *= AREA_DAMAGE_FACTOR
	ad.damage = int(floor(damage))
	ad.base_damage = damage_base_for(spell.damage, mana_stat)
	ad.critical_damage = int(floor(float(ad.critical_damage) * scale))
	ad.notes.append({"archery": true, "mana_stat": mana_stat, "npc_factor": NPC_DAMAGE_FACTOR if not target.is_player else 1.0, "endurance_cost": cost,
		"cast_time_msec": casting_time_msec(spell.cast_time, int(mana_stat))})
	var messages: Array = ["%s shoots %s for %d %s damage (endurance -%d)." % [spell.name, target.name, ad.damage, ad.damage_type, cost]]
	if bool(options.get("apply_to_target", false)):
		caster.endurance = maxi(0, caster.endurance - cost)
		target.change_health(-ad.total_damage())
	return DaocCombatResult.from_attack(mechanism_id(), ad, messages).to_dict()
