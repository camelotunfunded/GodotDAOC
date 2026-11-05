extends RefCounted
class_name DaocSpellVisualCatalogue

## P1-76 — ce que le CLIENT D'ORIGINE joue pour un effet de sort.
##
## Le serveur ne nomme qu'un entier : `Spell.ClientEffect`, porté par 0x72
## (incantation) et 0x1B (résolution). Tout le reste est écrit dans les tables
## du client, et rien ici n'est inventé :
##
##   gamedata/spells.csv     ClientEffect -> Anim1/2/3 (COLONNES de anims.csv :
##                           début, milieu, fin du geste), Effect1A/1B/2/3
##                           (effets sur le lanceur), Projectile, Target,
##                           Buildup, Pulse, Radius, Resist (ids speffects)
##   gamedata/speffects.csv  id effet -> NIF (id spnifs), noeud d'accroche
##                           (« Bip01 R Held », « rootnode »…), durée ms, échelle
##   gamedata/spnifs.csv     id NIF -> nom de fichier dans effects/ (sans .nif)
##   gamedata/anims.csv      jeu d'animations -> id KFA par colonne
##   gamedata/animnifs.csv   id KFA -> fichier .kfa, images, fps, loop/clamp
##
## Vérifié sur l'effet 151 « Ice Cloud (Minor) », celui que Heyvena a lancé en
## live le 2026-09-14 : Anim1..3 = 41,42,43 (geste « Bk-Hand »), mains
## `alb_cold_sum` (39) gauche et droite, `alb_cold_gat` (38) au bassin, cible
## `alb_frostspray_hit` (41).
##
## Les trois colonnes d'animation désignent l'un des huit GESTES d'incantation
## d'anims.csv, toujours par triplet contigu début/milieu/fin. Le nom de geste
## est celui que le Character Lab exporte dans les scènes joueur
## (`cast_<geste>_start|mid|end`) : c'est le contrat d'insertion.

const CAST_GESTURE_BY_COLUMN := {
	16: "default", 32: "circ", 35: "wax", 38: "upraised", 41: "bkhand",
	44: "stamp", 47: "crossed", 50: "z",
}

const CP1252_DECODE := {
	0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
	0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
	0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
	0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
	0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
	0x9E: 0x017E, 0x9F: 0x0178,
}

var loaded := false
var error := ""
var client_root := ""
var _spells: Dictionary = {}
var _speffects: Dictionary = {}
var _spnifs: Dictionary = {}
var _anim_sets: Dictionary = {}
var _animnifs: Dictionary = {}


func load_tables(root: String) -> bool:
	loaded = false
	error = ""
	client_root = root
	var gamedata := root.path_join("gamedata")
	_spells = _load_id_csv(gamedata.path_join("spells.csv"), 2)
	_speffects = _load_id_csv(gamedata.path_join("speffects.csv"), 2)
	_spnifs = _load_id_csv(gamedata.path_join("spnifs.csv"), 2)
	_anim_sets = _load_id_csv(gamedata.path_join("anims.csv"), 2)
	_animnifs = _load_id_csv(gamedata.path_join("animnifs.csv"), 2)
	for pair in [["spells.csv", _spells], ["speffects.csv", _speffects], ["spnifs.csv", _spnifs],
			["anims.csv", _anim_sets], ["animnifs.csv", _animnifs]]:
		if (pair[1] as Dictionary).is_empty():
			error = "gamedata/%s absent ou vide sous %s" % [str(pair[0]), root]
			return false
	loaded = true
	return true


func table_counts() -> Dictionary:
	return {"spells": _spells.size(), "speffects": _speffects.size(), "spnifs": _spnifs.size(),
		"anim_sets": _anim_sets.size(), "animnifs": _animnifs.size()}


## Tout ce que le client joue pour un ClientEffect : geste, effets nommés par
## rôle, chacun résolu jusqu'au fichier NIF. Un id absent est SIGNALÉ, pas
## remplacé.
func resolve_client_effect(client_effect: int) -> Dictionary:
	var out := {"ok": false, "client_effect": client_effect, "name": "", "icon": -1,
		"gesture": "", "anim_columns": [], "effects": {}, "sound_set": 0,
		"projectile_lag": 0, "missing": []}
	if not loaded:
		out["reason"] = "tables non chargées"
		return out
	if not _spells.has(client_effect):
		out["reason"] = "effet client %d absent de spells.csv" % client_effect
		return out
	var row: PackedStringArray = _spells[client_effect]
	out["name"] = _cell(row, 1)
	out["icon"] = _cell_int(row, 2, -1)
	var anim_columns := [_cell_int(row, 3, 0), _cell_int(row, 4, 0), _cell_int(row, 5, 0)]
	out["anim_columns"] = anim_columns
	out["gesture"] = str(CAST_GESTURE_BY_COLUMN.get(anim_columns[0], ""))
	if out["gesture"] == "" and anim_columns[0] > 0:
		out["missing"].append("geste inconnu pour la colonne %d" % anim_columns[0])
	out["sound_set"] = _cell_int(row, 14, 0)
	out["projectile_lag"] = _cell_int(row, 17, 0)
	var roles := {"caster_1a": 6, "caster_1b": 7, "caster_2": 8, "caster_3": 9,
		"projectile": 10, "target": 11, "buildup": 12, "pulse": 13, "radius": 15, "resist": 16}
	var effects := {}
	for role_value in roles:
		var role := str(role_value)
		var effect_id := _cell_int(row, int(roles[role]), 0)
		if effect_id <= 0:
			continue
		var effect := resolve_effect(effect_id)
		if not bool(effect.get("ok", false)):
			out["missing"].append("%s: %s" % [role, str(effect.get("reason", ""))])
			continue
		effects[role] = effect
	out["effects"] = effects
	out["ok"] = true
	return out


## Un effet de speffects.csv, jusqu'au fichier NIF de effects/.
func resolve_effect(effect_id: int) -> Dictionary:
	if not _speffects.has(effect_id):
		return {"ok": false, "reason": "effet %d absent de speffects.csv" % effect_id}
	var row: PackedStringArray = _speffects[effect_id]
	var nif_id := _cell_int(row, 2, -1)
	var out := {"ok": true, "effect_id": effect_id, "name": _cell(row, 1).strip_edges(),
		"nif_id": nif_id, "nif_file": "", "nif_path": "", "attach_node": _cell(row, 3).strip_edges(),
		"duration_ms": _cell_int(row, 4, 0), "rate": _cell_int(row, 5, 100),
		"angle": _cell_int(row, 6, 0), "scale": _cell_float(row, 7, 1.0)}
	if _spnifs.has(nif_id):
		var nif_row: PackedStringArray = _spnifs[nif_id]
		var file := _cell(nif_row, 2).strip_edges()
		out["nif_file"] = file
		out["nif_name"] = _cell(nif_row, 1).strip_edges()
		if file != "":
			var path := client_root.path_join("effects").path_join(file + ".nif")
			if FileAccess.file_exists(path):
				out["nif_path"] = path
			elif FileAccess.file_exists(client_root.path_join("effects").path_join(file + ".NIF")):
				out["nif_path"] = client_root.path_join("effects").path_join(file + ".NIF")
	else:
		out["ok"] = false
		out["reason"] = "NIF %d absent de spnifs.csv" % nif_id
	return out


## Les trois KFA d'un geste pour un jeu d'animations donné (ligne d'anims.csv).
func resolve_cast_clips(anim_set_id: int, gesture: String) -> Dictionary:
	var out := {"ok": false, "anim_set_id": anim_set_id, "gesture": gesture, "clips": {}, "missing": {}}
	if not _anim_sets.has(anim_set_id):
		out["reason"] = "jeu d'animations %d absent de anims.csv" % anim_set_id
		return out
	var start_column := -1
	for column_value in CAST_GESTURE_BY_COLUMN:
		if str(CAST_GESTURE_BY_COLUMN[column_value]) == gesture:
			start_column = int(column_value)
	if start_column < 0:
		out["reason"] = "geste inconnu : %s" % gesture
		return out
	var row: PackedStringArray = _anim_sets[anim_set_id]
	var phases := ["start", "mid", "end"]
	for index in phases.size():
		var clip_name := cast_clip_name(gesture, str(phases[index]))
		var anim_id := _cell_int(row, start_column + index + 2, -1)
		if anim_id <= 0:
			out["missing"][clip_name] = "colonne %d vide dans le jeu %d" % [start_column + index, anim_set_id]
			continue
		var clip := resolve_animation(anim_id)
		if not bool(clip.get("ok", false)):
			out["missing"][clip_name] = str(clip.get("reason", ""))
			continue
		out["clips"][clip_name] = clip
	out["ok"] = not (out["clips"] as Dictionary).is_empty()
	return out


static func cast_clip_name(gesture: String, phase: String) -> String:
	return "cast_%s_%s" % [gesture, phase]


func resolve_animation(anim_id: int) -> Dictionary:
	if not _animnifs.has(anim_id):
		return {"ok": false, "reason": "animation %d absente de animnifs.csv" % anim_id}
	var row: PackedStringArray = _animnifs[anim_id]
	return {"ok": true, "anim_id": anim_id, "name": _cell(row, 1).strip_edges(),
		"file": _cell(row, 2).strip_edges(), "frames": _cell_int(row, 3, 0),
		"fps": _cell_int(row, 4, 15), "loop": _cell(row, 6).strip_edges().to_lower() == "loop"}


func _load_id_csv(path: String, skip_lines: int) -> Dictionary:
	var rows := {}
	if not FileAccess.file_exists(path):
		return rows
	var raw := FileAccess.get_file_as_bytes(path)
	var line_bytes := PackedByteArray()
	var line_number := 0
	var index := 0
	while index <= raw.size():
		var at_end := index == raw.size()
		var byte := 10 if at_end else int(raw[index])
		index += 1
		if byte == 13:
			continue
		if byte != 10:
			line_bytes.append(byte)
			continue
		line_number += 1
		if line_number > skip_lines and not line_bytes.is_empty():
			var cells := _parse_csv_line(_decode_windows_1252(line_bytes))
			if not cells.is_empty():
				var id_text := str(cells[0]).strip_edges()
				if id_text.is_valid_int():
					rows[int(id_text)] = cells
		line_bytes = PackedByteArray()
	return rows


func _parse_csv_line(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	var cell := ""
	var quoted := false
	var index := 0
	while index < line.length():
		var character := line[index]
		if character == '"':
			if quoted and index + 1 < line.length() and line[index + 1] == '"':
				cell += '"'
				index += 2
				continue
			quoted = not quoted
		elif character == "," and not quoted:
			cells.append(cell)
			cell = ""
		else:
			cell += character
		index += 1
	cells.append(cell)
	return cells


func _decode_windows_1252(bytes: PackedByteArray) -> String:
	var out := ""
	for raw in bytes:
		var value := int(raw) & 0xff
		out += String.chr(int(CP1252_DECODE.get(value, value)))
	return out


func _cell(row: PackedStringArray, index: int) -> String:
	return str(row[index]) if index < row.size() else ""


func _cell_int(row: PackedStringArray, index: int, fallback: int) -> int:
	var text := _cell(row, index).strip_edges()
	return int(float(text)) if text.is_valid_float() else fallback


func _cell_float(row: PackedStringArray, index: int, fallback: float) -> float:
	var text := _cell(row, index).strip_edges()
	return float(text) if text.is_valid_float() else fallback
