extends RefCounted
class_name DaocPlayerSizeContract

## Contrat exact recoupe entre game.dll 1.109 et DOL GamePlayer.eSize.
## Le modele monde conserve l'identifiant dans 0x07ff et la taille dans 0x1800.
const BASE_MODEL_MASK := 0x07FF
const SIZE_BITS_MASK := 0x1800
const SHORT_BITS := 0x0800
const AVERAGE_BITS := 0x1000
const TALL_BITS := 0x1800


static func describe_packed_model(packed_model: int) -> Dictionary:
	var source_bits := packed_model & SIZE_BITS_MASK
	var choice := "average"
	var canonical_bits := AVERAGE_BITS
	var factor := 1.0
	var overview_value := 2
	if source_bits == SHORT_BITS:
		choice = "short"
		canonical_bits = SHORT_BITS
		factor = 0.95
		overview_value = 1
	elif source_bits == TALL_BITS:
		choice = "tall"
		canonical_bits = TALL_BITS
		factor = 1.05
		overview_value = 3
	return {
		"ok": packed_model >= 0 and packed_model <= 0xFFFF,
		"packed_model": packed_model,
		"base_model": packed_model & BASE_MODEL_MASK,
		"source_size_model_bits": source_bits,
		"size_model_bits": canonical_bits,
		"size_choice": choice,
		"size_visual_factor": factor,
		"size_scale_percent": int(roundf(factor * 100.0)),
		"character_overview_size_value": overview_value,
		"source": "game.dll 1.109 FUN_0041A7CF/FUN_00423DDF + DOL GamePlayer.eSize",
	}


static func visual_scale_for_packed_model(average_visual_scale: float, packed_model: int) -> Dictionary:
	if average_visual_scale <= 0.0 or not is_finite(average_visual_scale):
		return {"ok": false, "error": "average_visual_scale_invalid"}
	var contract := describe_packed_model(packed_model)
	if not bool(contract.get("ok", false)):
		return contract
	contract["average_visual_scale"] = average_visual_scale
	contract["visual_scale"] = average_visual_scale * float(contract["size_visual_factor"])
	return contract

