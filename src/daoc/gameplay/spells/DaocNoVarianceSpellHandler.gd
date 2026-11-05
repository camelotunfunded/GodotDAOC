extends DaocDirectDamageSpellHandler
class_name DaocNoVarianceSpellHandler

## P1-123 — DirectDamageNoVariance (OpenDAoC NoVarianceSpells.cs) : degats de
## base = Spell.Damage tel quel, variance fixee a 1,0 (min = max = 1).
## NightshadeNuke n'a pas besoin de classe : c'est un DirectDamage nu.


func mechanism_id() -> String:
	return "DirectDamageNoVariance"


func calculate_damage_base(_target: DaocCombatEntityState) -> float:
	return spell.damage


func damage_variance_bounds(_caster: DaocCombatEntityState) -> Dictionary:
	return {"min": 1.0, "max": 1.0}
