extends RefCounted
class_name DaocStyleVisualCatalogue

## P1-133 — CE QUE LE CLIENT D'ORIGINE JOUE POUR UN STYLE DE COMBAT.
##
## Sources, rien de mémoire :
## - OpenDAoC/DOL `StyleProcessor.cs` : `attackData.AnimationId = Style.Icon`
##   (ou `Style.TwoHandAnimation` pour une arme à deux mains), envoyé tel quel
##   dans le champ « style » du 0xBC (`GameLiving.cs` ShowAttackAnimation) ;
##   0x3E81 / 0x3E82 / 0x3E83 = frappe d'une arme / des deux / tir à l'arc
##   (PacketLib186) ; 0 = coup sans style.
## - `gamedata/styles.csv` : ID, name, Icon, **Animation**, Imagenum, Duration,
##   Buildup, **Red, Green, Blue**, Hit Effect (0 partout sauf une ligne).
## - `gamedata/canims.csv` : la colonne d'indice `Animation` (ligne 1 = indices
##   0..N) nomme le geste : 42 « Style 1HC 1 », 70 « Staff Style 1 »…
## - Les clips du catalogue (Lab P1-130) portent ce nom en snake_case :
##   `style_1hc_1`, `staff_style_1`.
##
## La couleur RVB de styles.csv teinte le VFX physique du coup
## (DaocMeleeHitVfx) ; un style sans ligne garde la teinte neutre.

const SPECIAL_ONE_DUAL := 0x3E81
const SPECIAL_BOTH_DUAL := 0x3E82
const SPECIAL_BOW_SHOOT := 0x3E83

var loaded := false
var error := ""
var _styles: Dictionary = {} # id -> {name, animation, color, duration_ms}
var _canim_names: Dictionary = {} # indice -> clip snake_case


func load_tables(client_root: String) -> bool:
	var root := client_root.replace("\\", "/").trim_suffix("/").path_join("gamedata")
	var canims := FileAccess.open(root.path_join("canims.csv"), FileAccess.READ)
	if canims == null:
		error = "canims.csv absent"
		return false
	var header_idx := canims.get_csv_line()
	var header_names := canims.get_csv_line()
	canims.close()
	for i in range(2, mini(header_idx.size(), header_names.size())):
		var idx_text := str(header_idx[i]).strip_edges()
		if not idx_text.is_valid_int():
			continue
		_canim_names[int(idx_text)] = clip_name(str(header_names[i]))
	var styles := FileAccess.open(root.path_join("styles.csv"), FileAccess.READ)
	if styles == null:
		error = "styles.csv absent"
		return false
	styles.get_csv_line()
	styles.get_csv_line()
	while not styles.eof_reached():
		var row := styles.get_csv_line()
		if row.size() < 10 or not str(row[0]).strip_edges().is_valid_int():
			continue
		var r := clampi(int(row[7]), 0, 255)
		var g := clampi(int(row[8]), 0, 255)
		var b := clampi(int(row[9]), 0, 255)
		_styles[int(row[0])] = {
			"name": str(row[1]),
			"animation": int(row[3]) if str(row[3]).strip_edges().is_valid_int() else 0,
			"duration_ms": int(row[5]) if str(row[5]).strip_edges().is_valid_int() else 0,
			"color": Color8(r, g, b),
		}
	styles.close()
	loaded = true
	return true


## « Staff Style 1 » -> « staff_style_1 », « Style 1Ht 5 » -> « style_1ht_5 ».
static func clip_name(header: String) -> String:
	var out := ""
	var last_us := true
	for ch in header.strip_edges().to_lower():
		var ok := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if ok:
			out += ch
			last_us = false
		elif not last_us:
			out += "_"
			last_us = true
	return out.trim_suffix("_")


static func is_special(style_id: int) -> bool:
	return style_id == SPECIAL_ONE_DUAL or style_id == SPECIAL_BOTH_DUAL or style_id == SPECIAL_BOW_SHOOT


func has_style(style_id: int) -> bool:
	return _styles.has(style_id)


## {ok, name, clip, color, animation}. `clip` vide si la colonne canims n'a pas de nom.
func resolve(style_id: int) -> Dictionary:
	if style_id <= 0 or not _styles.has(style_id):
		return {"ok": false, "clip": "", "color": Color(1, 1, 1), "name": ""}
	var s: Dictionary = _styles[style_id]
	var anim := int(s["animation"])
	return {
		"ok": true, "name": str(s["name"]), "animation": anim,
		"clip": str(_canim_names.get(anim, "")) if anim > 0 else "",
		"color": s["color"], "duration_ms": int(s["duration_ms"]),
	}


func counts() -> Dictionary:
	return {"styles": _styles.size(), "canims": _canim_names.size()}
