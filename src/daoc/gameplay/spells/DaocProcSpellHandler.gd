extends DaocSpellHandler
class_name DaocProcSpellHandler

## P1-123 — OffensiveProc, OffensiveProcPvE et DefensiveProc, fideles a
## OpenDAoC ProcSpellHandler.cs : le sort pose un effet qui dure `Duration`
## (x (1 + SpellDuration %)) ; le SOUS-SORT est l'identifiant `Value` ; la
## chance est `Frequency / 100` %. Offensif : sur ses propres coups portes
## (HitUnstyled / HitStyle), sous-sort sur la cible s'il est ENEMY, sinon sur
## soi. Defensif : quand on est TOUCHE en melee, sous-sort sur l'attaquant s'il
## est ENEMY, sinon sur soi. PvE : l'offensif ne part que contre un PNJ non
## controle. Le declenchement vit dans l'arbitre (DaocLocalServer._fire_procs).

const PROC_TYPES := {"OffensiveProc": "offensive_proc", "OffensiveProcPvE": "offensive_proc",
	"DefensiveProc": "defensive_proc"}


func mechanism_id() -> String:
	return spell.spell_type if spell != null else "Proc"


func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, _options: Dictionary = {}) -> Dictionary:
	var result: DaocCombatResult = DaocCombatResult.new()
	result.mechanism = mechanism_id()
	result.guardrails = DaocGameplayAuthority.result_guard()
	if caster == null or target == null or spell == null or not target.is_alive:
		result.ok = false
		result.messages = ["invalid or dead target"]
		return result.to_dict()
	var duration := int(float(spell.duration) * (1.0 + caster.get_modified("SpellDuration", 0.0) * 0.01))
	result.effects.append({
		"effect_type": str(PROC_TYPES.get(spell.spell_type, "offensive_proc")), "effect_category": "proc",
		"proc_spell_id": int(spell.value), "proc_chance": float(spell.frequency) / 100.0,
		"pve_only": spell.spell_type == "OffensiveProcPvE",
		# La « frequence » d'un proc est sa CHANCE, pas une pulsation.
		"frequency": 0, "duration": duration, "effect_group": spell.effect_group,
		"stacking_group": "proc:%s" % spell.spell_type if spell.effect_group == 0 else "",
		"source_spell_id": spell.id, "spell_name": spell.name, "spell_type": spell.spell_type,
		"caster_id": caster.entity_id, "target_id": target.entity_id,
	})
	result.messages = ["%s : %d %% de chance de declencher le sort %d." % [spell.name, spell.frequency / 100, int(spell.value)]]
	return result.to_dict()
