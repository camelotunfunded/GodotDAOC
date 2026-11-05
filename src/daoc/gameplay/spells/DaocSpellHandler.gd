extends RefCounted
class_name DaocSpellHandler

var spell: DaocSpellDef = null
var spell_line: String = ""
var last_attack_data: DaocAttackData = null

func setup(p_spell: DaocSpellDef, p_spell_line: String = "") -> DaocSpellHandler:
	spell = p_spell
	spell_line = p_spell_line
	return self

func mechanism_id() -> String:
	return spell.spell_type if spell != null else "UnknownSpell"

func power_cost(_target: DaocCombatEntityState = null) -> int:
	return spell.power if spell != null else 0

func calculate_damage_base(target: DaocCombatEntityState) -> float:
	if spell == null:
		return 0.0
	if spell.damage < 0.0 and target != null:
		return (float(target.max_health) * -spell.damage * 0.01) / 2.5
	return maxf(0.0, spell.damage)

func calculate_damage_cap(effectiveness: float = 1.0, target: DaocCombatEntityState = null) -> float:
	if spell == null:
		return 0.0
	if spell.damage < 0.0 and target != null:
		return float(target.max_health) * -spell.damage * 0.01 * 3.0 * effectiveness
	return maxf(0.0, spell.damage * 3.0 * effectiveness)

## P1-123 — OpenDAoC SpellHandler.CalculateToHitChance (l.2230) : 87,5 (taux
## de resistance de 12,5 % mesure en live), + (niveau du sort - niveau de la
## cible) / 2, + ToHitBonus, + 1 par niveau d ecart sauf joueur contre
## joueur, + la valeur de Piercing Magic (propriete « PiercingMagic »). Pas
## de plancher ni de plafond : la resistance est 100 - cette chance.
func calculate_to_hit_chance(caster: DaocCombatEntityState, target: DaocCombatEntityState) -> float:
	if caster == null or target == null or spell == null:
		return 100.0
	var chance := 87.5
	chance += float(spell.level - target.level) / 2.0
	chance += caster.get_modified("ToHitBonus", 0.0)
	if not (caster.is_player and target.is_player):
		chance += float(caster.level - target.level)
	chance += caster.get_modified("PiercingMagic", 0.0)
	return chance

func modify_damage_with_target_resist(ad: DaocAttackData, raw_damage: float) -> float:
	if ad == null or ad.target == null or spell == null:
		return raw_damage
	var resist = ad.target.get_resist_percent(spell.damage_type)
	var resisted = raw_damage * resist * 0.01
	ad.modifier = -int(round(resisted))
	return maxf(0.0, raw_damage - resisted)

func calculate_damage_to_target(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> DaocAttackData:
	var ad = DaocAttackData.new()
	ad.attacker = caster
	ad.target = target
	ad.attack_type = DaocCombatEnums.ATTACK_SPELL
	ad.attack_result = DaocCombatEnums.RESULT_HIT_UNSTYLED
	if spell != null:
		ad.damage_type = spell.damage_type
		ad.spell_id = spell.id
		ad.spell_type = spell.spell_type
	var base_damage_raw = calculate_damage_base(target)
	var bounds = damage_variance_bounds(caster)
	var seed = int(options.get("seed", 0)) + (spell.id if spell != null else 0) + (target.entity_id if target != null else 0)
	var variance = DaocDamageVariance.deterministic_variance(float(bounds.get("min", 1.0)), float(bounds.get("max", 1.0)), seed)
	var damage = base_damage_raw * variance
	damage = modify_damage_with_target_resist(ad, damage)
	var cap = calculate_damage_cap(float(options.get("effectiveness", 1.0)), target)
	if cap > 0.0:
		damage = minf(damage, cap)
	ad.base_damage = base_damage_raw
	ad.base_damage_cap = cap
	ad.damage = int(floor(damage))
	ad.critical_chance = int(caster.get_modified("CriticalSpellHitChance", 0.0)) if caster != null else 0
	var crit_pct = DaocDamageVariance.deterministic_crit_percent(float(ad.critical_chance), seed + 77, 1.0)
	ad.critical_damage = int(floor(float(ad.damage) * crit_pct))
	ad.notes.append({"variance": variance, "variance_bounds": bounds, "prediction_only": true})
	last_attack_data = ad
	return ad

func execute(caster: DaocCombatEntityState, target: DaocCombatEntityState, options: Dictionary = {}) -> Dictionary:
	var ad = calculate_damage_to_target(caster, target, options)
	return DaocCombatResult.from_attack(mechanism_id(), ad, ["generic spell prediction"]).to_dict()


## P1-123 — la fourchette de variance (SpellHandler.CalculateDamageVariance) ;
## les sorts « NoVariance » d'OpenDAoC la fixent a 1,0.
func damage_variance_bounds(caster: DaocCombatEntityState) -> Dictionary:
	return DaocDamageVariance.spell_variance_bounds(caster, spell, spell_line)
