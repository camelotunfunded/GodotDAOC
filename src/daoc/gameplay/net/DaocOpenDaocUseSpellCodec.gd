extends RefCounted
class_name DaocOpenDaocUseSpellCodec

const CLIENT_PACKET_NAME: String = "UseSpell"
const CLIENT_VERSION_MIN_POSITION_FLOATS: int = 1124

func build_use_spell_request_1127(position: Vector3, speed: float, heading: int, spell_line_index: int, spell_level: int, flags: Dictionary = {}) -> Dictionary:
	var flag_speed_data = 0
	if bool(flags.get("strafing", false)):
		flag_speed_data |= 0x4000
	if bool(flags.get("target_in_view", true)):
		flag_speed_data |= 0xa000
	if bool(flags.get("ground_target_in_view", false)):
		flag_speed_data |= 0x1000
	return {
		"ok": true,
		"packet": CLIENT_PACKET_NAME,
		"client_version_family": ">=1124",
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"speed": speed,
		"heading": heading,
		"flag_speed_data": flag_speed_data,
		"spell_level": spell_level,
		"spell_line_index": spell_line_index,
		"dispatch": "spell_or_style_or_ability",
		"source": "UseSpellHandler.cs",
	}

func resolve_skill_request(spell_book: DaocSpellBook, spell_line_index: int, spell_level: int, lines: Array = []) -> Dictionary:
	var out = {"ok": false, "spell_line_index": spell_line_index, "spell_level": spell_level, "source": "UseSpellHandler.GetSkill"}
	if spell_book == null:
		out["reason"] = "missing spell_book"
		return out
	for spell_id in spell_book.spells_by_id.keys():
		var spell: DaocSpellDef = spell_book.spells_by_id[spell_id] as DaocSpellDef
		if spell != null and spell.level == spell_level:
			out["ok"] = true
			out["skill_kind"] = "Spell"
			out["spell"] = spell.to_dict()
			return out
	out["reason"] = "not resolved in offline spellbook"
	return out
