extends RefCounted
class_name DaocEquipmentTables

## P1-93 — ce qu'un OBJET fait voir sur un personnage, lu dans les tables du
## client d'origine. Port cote client de `daoc_modern_player_tables.gd`
## (Character Lab), reduit a la chaine d'equipement :
##
##   armure  : objects.csv (Cata Body/Arms/Gloves/Legs/Boots/Cloak)
##             -> pskins.csv (BaseTex) -> mskins.csv -> figures/Mskins/.../*.png
##   arme    : objects.csv (ItemNif) -> items.csv -> items/*.nif
##             (+ objects.csv ApplyTexture -> pskins.csv -> items/pskins/*.png)
##   casque  : objects.csv (Cata Nif1..12 par race/genre) -> items.csv
##
## AUCUN NIF n'est converti ici et aucune texture n'est copiee dans res:// :
## on rend des CHEMINS relatifs au client. Le PNG lu au runtime est celui que la
## generation PBR a deja pose a cote du DDS ; un DDS seul n'est pas lu.
##
## L'armure moderne (fig3) est une TEXTURE posee sur la piece de corps, pas un
## maillage : « equiper » un plastron, c'est changer l'image du slot Body.

const CSV_SKIP := 2

const COL_MSKIN_LABEL := 1
const COL_MSKIN_FILE := 2
const COL_MSKIN_ARCHIVE := 4

const COL_PSKIN_LABEL := 1
const COL_PSKIN_FILE := 2
const COL_PSKIN_ARCHIVE := 4
const COL_PSKIN_BASE_TEX := 6

const COL_OBJECT_LABEL := 1
const COL_OBJECT_ITEM_NIF := 2
## P1-133 — objects.csv « Belt » (1 = l arme se range a la ceinture ou au dos
## hors combat), « Shield », « Combat Stance » (1 une main, 2 deux mains, 3
## lance, 7 estoc…) et « Left Hand ». Mesure : baton, lance, arc, bouclier = Belt 0.
const COL_OBJECT_BELT := 17
const COL_OBJECT_SHIELD := 18
const COL_OBJECT_STANCE := 19
const COL_OBJECT_LEFT_HAND := 20
const COL_OBJECT_APPLY_TEXTURE := 22
const COL_OBJECT_CATA_STATUS := 65
const COL_OBJECT_CATA_BODY := 66
const COL_OBJECT_CATA_FEMALE_BODY := 67
const COL_OBJECT_CATA_ARMS := 68
const COL_OBJECT_CATA_GLOVES := 69
const COL_OBJECT_CATA_LEGS := 70
const COL_OBJECT_CATA_BOOTS := 71
const COL_OBJECT_CATA_CLOAK := 72
const COL_OBJECT_CATA_HELM_NIF_FIRST := 79

const COL_ITEM_LABEL := 1
const COL_ITEM_FILE := 2
const COL_ITEM_HELM_HAIR := 23

const EQUIPMENT_SLOT_TO_CATA_PSKIN_COLUMN := {
	"body": COL_OBJECT_CATA_BODY,
	"arms": COL_OBJECT_CATA_ARMS,
	"gloves": COL_OBJECT_CATA_GLOVES,
	"legs": COL_OBJECT_CATA_LEGS,
	"boots": COL_OBJECT_CATA_BOOTS,
	"cloak": COL_OBJECT_CATA_CLOAK,
}

## objects.csv Nif1..Nif12 est ordonne par paire male/femme pour les six races
## d'Albion (verifie par items.csv : 1242 albHelm01_Bri_m, 1246 albHelm01_brit_f).
const ALBION_APPEARANCE_TO_CATA_HELM_OFFSET := {
	1: 0, 2: 1, 3: 2, 4: 3, 13: 4, 14: 5, 9: 6, 10: 7, 23: 8, 24: 9, 25: 10, 26: 11,
	# P1-129 : Midgard (midrp04 : nor, dwa, kob, tro, val, fro) et Hibernia
	# (hibrp04 : cel, elf, lur, fir, syl, sha), meme ordre male/femme.
	15: 0, 16: 1, 21: 2, 22: 3, 19: 4, 20: 5, 31: 6, 32: 7, 27: 8, 28: 9, 5: 10, 6: 11,
	33: 0, 34: 1, 11: 2, 12: 3, 17: 4, 18: 5, 29: 6, 30: 7, 35: 8, 36: 9, 7: 10, 8: 11,
}

const UNARMORED_TEXTURES_BY_APPEARANCE := {
	2: {"body": "figures/skins/skin001/b_cth1_body1f.png", "arms": "figures/skins/skin001/b_cth1_arm1.png", "legs": "figures/skins/skin001/b_cth1_leg1.png", "gloves": "figures/skins/skin001/b_cth1_glov1.png", "boots": "figures/skins/skin001/b_cth1_boot1.png"},
	10: {"body": "figures/skins/skin001/a_cth1_body1f.png", "arms": "figures/skins/skin002/a_cth1_arm1.png", "legs": "figures/skins/skin002/a_cth1_leg1.png", "gloves": "figures/skins/skin002/a_cth1_glov1.png", "boots": "figures/skins/skin002/a_cth1_boot1.png"},
}

## P1-129 — LA TENUE « NUE » DE CHAQUE RACE, lue dans `gamedata/skins.csv` du client :
## `<prefixe>_cth1_body1<m|f>` pour les races classiques (b Briton, h Highlander,
## s Saracen, a Avalonian, t Troll, v Norse, k Kobold, d Dwarf), `_cth0_` pour les
## autres (e Elf, f Firbolg, l Lurikeen, c Celt, i Inconnu, va Valkyn, syl Sylvan,
## HO Half Ogre, SV Frostalf, Sh Shar) ; bras, jambes, gants, bottes = `arm1`,
## `leg1`, `glov1`, `boot1`, communs aux deux sexes. Avant P1-129 seules les
## apparences 2 et 10 l avaient : les 34 autres recevaient le tissu generique
## mskin 217/220. Minotaure exclu (pas d apparence de catalogue).
const UNARMORED_PREFIX_BY_RACE_PAIR := {
	1: ["b", 1], 3: ["s", 1], 5: ["SV", 0], 7: ["Sh", 0], 9: ["a", 1], 11: ["e", 0],
	13: ["h", 1], 15: ["v", 1], 17: ["l", 0], 19: ["k", 1], 21: ["d", 1], 23: ["i", 0],
	25: ["HO", 0], 27: ["va", 0], 29: ["f", 0], 31: ["t", 1], 33: ["c", 0], 35: ["syl", 0],
}
const UNARMORED_PART_SUFFIX := {"body": "body1", "arms": "arm1", "legs": "leg1", "gloves": "glov1", "boots": "boot1"}


## `eInventorySlot` -> logement visuel.
const INVENTORY_SLOT_TO_VISUAL := {
	10: "right_hand", 11: "left_hand", 12: "two_hand", 13: "distance",
	21: "head", 22: "gloves", 23: "boots", 25: "body", 26: "cloak", 27: "legs", 28: "arms",
}

const RUNTIME_TEXTURE_EXTENSIONS := ["png", "dds", "tga", "bmp"]

const CP1252_DECODE := {
	0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
	0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6,
	0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
	0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
	0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
	0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
	0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
}

var client_root: String = ""
var loaded: bool = false
var load_error: String = ""

var _mskins: Dictionary = {}
var _pskins: Dictionary = {}
var _objects: Dictionary = {}
var _items: Dictionary = {}
var _dir_cache: Dictionary = {}


func load_tables(root: String) -> bool:
	client_root = root.replace("\\", "/").trim_suffix("/")
	loaded = false
	load_error = ""
	_dir_cache.clear()
	for spec in [["gamedata/mskins.csv", _mskins], ["gamedata/pskins.csv", _pskins],
			["gamedata/objects.csv", _objects], ["gamedata/items.csv", _items]]:
		var target := spec[1] as Dictionary
		target.clear()
		var result := _read_csv(client_root.path_join(str(spec[0])), CSV_SKIP)
		if not bool(result.get("ok", false)):
			load_error = str(result.get("error", "table illisible"))
			return false
		for value in result["rows"]:
			var row := value as PackedStringArray
			var id_text := _cell(row, 0)
			if id_text.is_valid_int():
				target[int(id_text)] = row
	loaded = true
	return true


func table_counts() -> Dictionary:
	return {"mskins": _mskins.size(), "pskins": _pskins.size(), "objects": _objects.size(), "items": _items.size()}


## Texture de base d'un logement d'armure VIDE, pour un genre.
func base_armor_texture(visual_slot: String, _gender: String, appearance_id: int = -1) -> Dictionary:
	var race_textures: Dictionary = unarmored_textures_for(appearance_id)
	if race_textures.has(visual_slot):
		var relative := str(race_textures[visual_slot])
		return {"ok": FileAccess.file_exists(client_root.path_join(relative)), "mskin_id": -1,
			"runtime_relative": relative, "visual_slot": visual_slot,
			"source": "race_unarmored_skin", "appearance_id": appearance_id}
	return {"ok": false, "reason": "texture raciale de base absente", "visual_slot": visual_slot, "appearance_id": appearance_id}



## Le modele d'un objet (colonne `Model` d'itemtemplate, ou `model` du paquet
## 0x02) -> ce qu'il faut afficher pour ce logement et cette apparence.
func resolve_equipment_model(model_id: int, visual_slot: String, appearance_id: int) -> Dictionary:
	var slot := visual_slot.strip_edges().to_lower()
	var out := {
		"ok": false, "model_id": model_id, "visual_slot": slot, "appearance_id": appearance_id,
		"reason": "", "label": "", "resolution_kind": "", "pskin_id": -1, "mskin": {},
		"texture_relative": "", "nif_relative": "", "item_id": -1, "item_texture_relative": "",
	}
	if not loaded:
		out["reason"] = "tables non chargees"
		return out
	if not _objects.has(model_id):
		out["reason"] = "model_id absent de objects.csv"
		return out
	var row: PackedStringArray = _objects[model_id]
	out["label"] = _cell(row, COL_OBJECT_LABEL)
	if slot == "head":
		if not ALBION_APPEARANCE_TO_CATA_HELM_OFFSET.has(appearance_id):
			out["reason"] = "ordre Cata Nif1..12 confirme uniquement pour les apparences Albion"
			return out
		var item_id := _cell_int(row, COL_OBJECT_CATA_HELM_NIF_FIRST + int(ALBION_APPEARANCE_TO_CATA_HELM_OFFSET[appearance_id]), -1)
		out["item_id"] = item_id
		if item_id <= 0:
			out["reason"] = "casque sans NIF Catacombs pour cette race/genre"
			return out
		var item := resolve_item_nif(item_id)
		if not bool(item.get("ok", false)):
			out["reason"] = str(item.get("reason", ""))
			return out
		out["nif_relative"] = str(item.get("relative", ""))
		out["helm_hair_mode"] = int(item.get("helm_hair_mode", -1))
		out["resolution_kind"] = "catacombs_rigid_item"
		# P1-129 : la PEAU du casque. Le NIF ne cite qu une texture generique
		# (albHelm01 -> B_plt1_helm1, de la plaque) ; la matiere vient de
		# objects.csv ApplyTexture (col 22, sinon Helm col 12) -> pskins.csv :
		# 62 cuir -> b_lea2_helm1, 1229 tissu -> B_cth1_helm1. Sans elle le casque
		# sortait noir ou en plaque, quel que soit l objet.
		for column in [COL_OBJECT_APPLY_TEXTURE, 12]:
			var helm_texture_id := _cell_int(row, column, -1)
			if _pskins.has(helm_texture_id):
				var helm_texture := resolve_item_pskin_texture(helm_texture_id)
				if bool(helm_texture.get("ok", false)):
					out["pskin_id"] = helm_texture_id
					out["item_texture_relative"] = str(helm_texture.get("runtime_relative", ""))
					break
		out["ok"] = true
		return out
	if slot in ["right_hand", "left_hand", "two_hand", "distance"]:
		var item_id := _cell_int(row, COL_OBJECT_ITEM_NIF, -1)
		out["item_id"] = item_id
		var item := resolve_item_nif(item_id)
		if not bool(item.get("ok", false)):
			out["reason"] = str(item.get("reason", "item d'arme non resolu"))
			return out
		out["nif_relative"] = str(item.get("relative", ""))
		out["resolution_kind"] = "rigid_item"
		var object_texture_id := _cell_int(row, COL_OBJECT_APPLY_TEXTURE, -1)
		if _pskins.has(object_texture_id):
			var object_texture := resolve_item_pskin_texture(object_texture_id)
			if bool(object_texture.get("ok", false)):
				out["pskin_id"] = object_texture_id
				out["item_texture_relative"] = str(object_texture.get("runtime_relative", ""))
		out["ok"] = true
		return out
	if not EQUIPMENT_SLOT_TO_CATA_PSKIN_COLUMN.has(slot):
		out["reason"] = "logement visuel non pris en charge"
		return out
	if _cell_int(row, COL_OBJECT_CATA_STATUS, 0) <= 0:
		out["reason"] = "objet sans redirection Catacombs"
		return out
	var pskin_column := int(EQUIPMENT_SLOT_TO_CATA_PSKIN_COLUMN[slot])
	if slot == "body" and appearance_id % 2 == 0:
		pskin_column = COL_OBJECT_CATA_FEMALE_BODY
	var pskin_id := _cell_int(row, pskin_column, -1)
	out["pskin_id"] = pskin_id
	if pskin_id <= 0:
		out["reason"] = "objet sans pskin Catacombs pour cet emplacement/genre"
		return out
	var pskin := resolve_pskin(pskin_id)
	if not bool(pskin.get("ok", false)):
		out["reason"] = str(pskin.get("reason", "pskin Catacombs non resolue"))
		return out
	out["mskin"] = pskin.get("mskin", {})
	out["texture_relative"] = str((pskin.get("mskin", {}) as Dictionary).get("runtime_relative", ""))
	out["resolution_kind"] = "catacombs_pskin_mskin"
	out["ok"] = true
	return out


func resolve_mskin(mskin_id: int) -> Dictionary:
	var out := {"ok": false, "mskin_id": mskin_id, "reason": "", "label": "", "runtime_relative": ""}
	if not loaded:
		out["reason"] = "tables non chargees"
		return out
	if not _mskins.has(mskin_id):
		out["reason"] = "mskin_id absent de mskins.csv"
		return out
	var row: PackedStringArray = _mskins[mskin_id]
	out["label"] = _cell(row, COL_MSKIN_LABEL)
	var declared := _cell(row, COL_MSKIN_FILE)
	if declared == "":
		out["reason"] = "nom de texture vide dans mskins.csv"
		return out
	var archive := _cell_int(row, COL_MSKIN_ARCHIVE, -1)
	var dirs: Array[String] = []
	if archive >= 0:
		dirs.append("figures/Mskins/mskin%03d" % archive)
	dirs.append("figures/Mskins")
	var relative := _find_first(dirs, declared.get_basename(), RUNTIME_TEXTURE_EXTENSIONS)
	if relative == "":
		out["reason"] = "texture Mskins '%s' introuvable (archive %d)" % [declared, archive]
		return out
	out["runtime_relative"] = relative
	out["ok"] = true
	return out


func resolve_pskin(pskin_id: int) -> Dictionary:
	var out := {"ok": false, "pskin_id": pskin_id, "reason": "", "label": "", "base_mskin_id": -1, "mskin": {}}
	if not loaded:
		out["reason"] = "tables non chargees"
		return out
	if not _pskins.has(pskin_id):
		out["reason"] = "pskin_id absent de pskins.csv"
		return out
	var row: PackedStringArray = _pskins[pskin_id]
	out["label"] = _cell(row, COL_PSKIN_LABEL)
	var base_id := _cell_int(row, COL_PSKIN_BASE_TEX, 0)
	out["base_mskin_id"] = base_id
	if base_id <= 0:
		out["reason"] = "pskin legacy ou sans BaseTex Mskins"
		return out
	var mskin := resolve_mskin(base_id)
	out["mskin"] = mskin
	if not bool(mskin.get("ok", false)):
		out["reason"] = "BaseTex Mskins non resolue : %s" % str(mskin.get("reason", ""))
		return out
	out["ok"] = true
	return out


func resolve_item_nif(item_id: int) -> Dictionary:
	var out := {"ok": false, "item_id": item_id, "reason": "", "label": "", "relative": "", "helm_hair_mode": -1}
	if not loaded:
		out["reason"] = "tables non chargees"
		return out
	if not _items.has(item_id):
		out["reason"] = "item_id absent de items.csv"
		return out
	var row: PackedStringArray = _items[item_id]
	out["label"] = _cell(row, COL_ITEM_LABEL)
	out["helm_hair_mode"] = _cell_int(row, COL_ITEM_HELM_HAIR, -1)
	var declared := _cell(row, COL_ITEM_FILE)
	if declared == "":
		out["reason"] = "nom de NIF vide dans items.csv"
		return out
	var relative := _find_first(["items"], declared.get_basename(), ["nif"])
	if relative == "":
		out["reason"] = "NIF item '%s' introuvable" % declared
		return out
	out["relative"] = relative
	out["ok"] = true
	return out


func resolve_item_pskin_texture(pskin_id: int) -> Dictionary:
	var out := {"ok": false, "pskin_id": pskin_id, "reason": "", "runtime_relative": ""}
	if not loaded or not _pskins.has(pskin_id):
		out["reason"] = "pskin item absente"
		return out
	var row := _pskins[pskin_id] as PackedStringArray
	var declared := _cell(row, COL_PSKIN_FILE)
	if declared.is_empty():
		out["reason"] = "pskin item sans fichier"
		return out
	var dirs: Array[String] = []
	var archive := _cell_int(row, COL_PSKIN_ARCHIVE, -1)
	if archive >= 0:
		dirs.append("items/pskins/pskin%03d" % archive)
	dirs.append("items/pskins")
	dirs.append("items")
	var relative := _find_first(dirs, declared.get_basename(), RUNTIME_TEXTURE_EXTENSIONS)
	if relative.is_empty():
		out["reason"] = "texture runtime item introuvable"
		return out
	out["runtime_relative"] = relative
	out["ok"] = true
	return out


func absolute(relative: String) -> String:
	return client_root.path_join(relative) if relative != "" else ""


func _find_first(dirs: Array[String], stem: String, extensions: Array) -> String:
	var want := stem.to_lower()
	for ext in extensions:
		var key := "%s.%s" % [want, str(ext).to_lower()]
		for relative_dir in dirs:
			var listing := _list_dir(relative_dir)
			if listing.has(key):
				return relative_dir.path_join(str(listing[key]))
	return ""


func _list_dir(relative_dir: String) -> Dictionary:
	if _dir_cache.has(relative_dir):
		return _dir_cache[relative_dir]
	var out := {}
	var d := DirAccess.open(client_root.path_join(relative_dir))
	if d != null:
		d.list_dir_begin()
		var name := d.get_next()
		while name != "":
			if not d.current_is_dir():
				out[name.to_lower()] = name
			name = d.get_next()
		d.list_dir_end()
	_dir_cache[relative_dir] = out
	return out


func _read_csv(path: String, skip: int) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "table illisible : %s" % path, "rows": []}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var rows: Array[PackedStringArray] = []
	var line_no := 0
	var start := 0
	var n := bytes.size()
	var i := 0
	while i <= n:
		var at_end := i == n
		if at_end or bytes[i] == 0x0A:
			var stop := i
			if stop > start and bytes[stop - 1] == 0x0D:
				stop -= 1
			if stop > start or not at_end:
				line_no += 1
				if line_no > skip:
					var line := _decode_windows_1252(bytes.slice(start, stop))
					if line.strip_edges() != "":
						rows.append(_parse_csv_line(line))
			start = i + 1
		i += 1
	return {"ok": true, "error": "", "rows": rows}


func _decode_windows_1252(bytes: PackedByteArray) -> String:
	var out := ""
	for b in bytes:
		var code := int(b)
		if code >= 0x80 and CP1252_DECODE.has(code):
			out += char(int(CP1252_DECODE[code]))
		else:
			out += char(code)
	return out


func _parse_csv_line(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\"":
			if in_quotes and i + 1 < line.length() and line[i + 1] == "\"":
				cur += "\""
				i += 2
				continue
			in_quotes = not in_quotes
			i += 1
			continue
		if c == "," and not in_quotes:
			out.append(cur)
			cur = ""
			i += 1
			continue
		cur += c
		i += 1
	out.append(cur)
	return out


func _cell(row: PackedStringArray, index: int) -> String:
	if index < 0 or index >= row.size():
		return ""
	return str(row[index]).strip_edges()


func _cell_int(row: PackedStringArray, index: int, fallback: int) -> int:
	var value := _cell(row, index)
	if value == "" or not value.is_valid_int():
		return fallback
	return int(value)


## P1-129 — les cinq textures nues d une apparence (1..36, impair = homme),
## chemins relatifs au client, trouvees dans figures/skins/skinNNN. Vide si la
## race est inconnue ou si un fichier manque : l appelant retombe alors sur mskin.
var _unarmored_cache: Dictionary = {}
var _skin_files: Dictionary = {}

func unarmored_textures_for(appearance_id: int) -> Dictionary:
	if _unarmored_cache.has(appearance_id):
		return _unarmored_cache[appearance_id] as Dictionary
	var out: Dictionary = {}
	var pair := appearance_id - ((appearance_id + 1) % 2)
	if appearance_id > 0 and UNARMORED_PREFIX_BY_RACE_PAIR.has(pair):
		_index_skin_files()
		var spec: Array = UNARMORED_PREFIX_BY_RACE_PAIR[pair]
		var stem := "%s_cth%d_" % [str(spec[0]), int(spec[1])]
		var gender_letter := "m" if appearance_id % 2 == 1 else "f"
		for visual in UNARMORED_PART_SUFFIX.keys():
			var name := stem + str(UNARMORED_PART_SUFFIX[visual]) + (gender_letter if visual == "body" else "") + ".png"
			var relative := str(_skin_files.get(name.to_lower(), ""))
			if relative == "":
				out = {}
				break
			out[visual] = relative
	elif UNARMORED_TEXTURES_BY_APPEARANCE.has(appearance_id):
		out = UNARMORED_TEXTURES_BY_APPEARANCE[appearance_id] as Dictionary
	_unarmored_cache[appearance_id] = out
	return out


func _index_skin_files() -> void:
	if not _skin_files.is_empty() or client_root == "":
		return
	var skins_dir := client_root.path_join("figures/skins")
	var dir := DirAccess.open(skins_dir)
	if dir == null:
		return
	for sub in dir.get_directories():
		for file in DirAccess.get_files_at(skins_dir.path_join(sub)):
			var lower := str(file).to_lower()
			if lower.contains("_cth") and lower.ends_with(".png") and not _skin_files.has(lower):
				_skin_files[lower] = "figures/skins/%s/%s" % [sub, file]


## P1-133 — OU L'ARME VA QUAND ON NE SE BAT PAS. Rien d'invente :
##   - `objects.csv` Belt = 1 : l'arme se range ; Belt = 0 (batons, lances,
##     arcs, boucliers, instruments) : elle reste en main, comme dans le client
##     d'origine ;
##   - points d'attache du squelette nommes dans game.dll : `Bip01 L/R Belt`,
##     `Bip01 L/R Back` (chaine « Attachpoints ») ;
##   - Combat Stance 2 (deux mains) : au DOS ; sinon a la CEINTURE, cote oppose
##     a la main qui tire (droite -> `L Belt`, gauche -> `R Belt`). Le cote est
##     un CHOIX de lecture : le client ne l'ecrit dans aucune table.
## `hand_visual` : "right_hand" / "left_hand" / "two_hand".
func weapon_sheath_bone(model_id: int, hand_visual: String) -> String:
	if not loaded or not _objects.has(model_id):
		return ""
	var row: PackedStringArray = _objects[model_id]
	if _cell_int(row, COL_OBJECT_BELT, 0) != 1 or _cell_int(row, COL_OBJECT_SHIELD, 0) == 1:
		return ""
	var stance := _cell_int(row, COL_OBJECT_STANCE, 0)
	if stance == 2 or hand_visual == "two_hand":
		return "Bip01 L Back" if hand_visual == "left_hand" else "Bip01 R Back"
	return "Bip01 R Belt" if hand_visual == "left_hand" else "Bip01 L Belt"


## objects.csv Shield choisit l'attache ; la case gauche peut porter une arme.
## game.dll : "Bip01 L Held" (0x521A8C), "Bip01 L Shield" (0x521A6C).
func weapon_hand_bone(model_id: int, visual: String) -> String:
	if visual != "left_hand":
		return "Bip01 R Held"
	if loaded and _objects.has(model_id):
		return "Bip01 L Shield" if _cell_int(_objects[model_id], COL_OBJECT_SHIELD, 0) == 1 else "Bip01 L Held"
	return ""
