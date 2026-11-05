extends RefCounted
class_name DaocSpellIconAtlas

## Les icones du client d'origine, lues sur place, jamais copiees dans res://.
##
## P1-85 — LA VRAIE CORRESPONDANCE, prouvee sur Sprint : le serveur envoie
## l'icone 409 (capture Eden `p1_20c_live_heyveno_worldinit`, 0x16/0x01), et
## `gamedata/icons.csv` ligne 409 dit « sprint, baseIconId 1602 » : planche
## `skl_1600.bmp`, case 2 = la botte ailee. L'identifiant que le serveur envoie
## N'EST PAS une case de planche : c'est une LIGNE de `icons.csv`
## (`ID,Name,baseIconId,borderId,up left,up,up right,right,down right,down,left,spell`),
## et `baseIconId` designe la case : planche = `<famille>_<centaine>.bmp`,
## case = `baseIconId % 100` dans une grille 10 x 10 de 32 px. Les centaines
## sont uniques entre familles (spl 0-400 et 1800, cbt 500-800, wpn 900-1100 et
## 1700, itm 1200-1500, skl 1600) ; `wgsm_0` et `wglg_100` (lueurs d'arme)
## doublent 0 et 100 et sont ecartees. `borderId` >= 0 superpose un cadre de
## `brdr_0.bmp` (10 x 2 cases, BMP 32 bits a alpha). Les colonnes
## directionnelles et `spell` sont lues et COMPTEES, pas encore dessinees.
##
## P1-88 — ET POUR LES SORTS, UNE MARCHE DE PLUS, trouvee dans `gamedata/spells.csv`
## (colonnes `ID, Name, Icon, Anim1..`) : l'identifiant que le serveur envoie pour
## un SORT est l'ID d'effet client (Amethyst Shield = 1, Ice Cloud = 151, Fire
## Bolt = 311 — les memes valeurs que ClientEffect dans la base DOL), et c'est
## la colonne `Icon` de spells.csv (1000, 1040, 1425) qui designe la ligne de
## icons.csv (bases 91, 56, 431 : le bouclier vert, la nuee, la flamme). Les
## competences (Sprint 409) vont a icons.csv directement. `family` = "spell"
## (defaut) ou "skill" choisit la marche.
##
## P1-128 — LES STYLES (kit de coups), la meme marche par `gamedata/styles.csv`
## (`ID, name, Icon, Animation, ...`). OpenDAoC ecrit `style.Icon` dans le
## 0x16 (PacketLib1105) ET s en sert comme identifiant d ANIMATION de style
## (StyleProcessor : `animationId = style.Icon`) : c est donc l ID de
## styles.csv, pas une ligne de icons.csv. Preuve par les noms : Staff 1 (24)
## -> Icon 644 -> icons.csv 644 « Defender's Aegis » (un style de baton),
## Spinning Staff (230) -> 690 « Spinning Staff ». Avant P1-128 les styles
## passaient par "skill" : la ligne 24 de icons.csv, une icone sans rapport.
## `family_for_kind` donne la famille de chaque type du 0x16 pour TOUTES les
## classes ; ne plus coder "skill" en dur ailleurs.
##
## AVANT P1-85 la case etait `Icon % 100` dans `spl_<centaine>` : Fire Bolt
## (311) rendait un viseur, Amethyst Shield (1) un crane. Sans `icons.csv`
## sur le disque, ce repli reste en place et le rapport le dit.

const CELL := 32
const PER_ROW := 10
const SPELL_PREFIX := "spl"
const BORDER_SHEET := "brdr_0"
const IGNORED_FAMILIES := ["wgsm", "wglg", "brdr"]

var client_root := ""
var _planches: Dictionary = {}   # "spl:100" -> chemin
var _by_hundred: Dictionary = {}  # 1600 -> chemin (familles non ecartees)
var _border_path := ""
var _rows: Dictionary = {}        # icon id -> {base, border, spell, directional}
var _spell_icons: Dictionary = {} # P1-88 : ID d'effet client (spells.csv) -> Icon
var _style_icons: Dictionary = {} # P1-128 : ID de style (styles.csv) -> Icon
var styles_loaded := false
var spells_loaded := false
## P1-96 : modele d objet (colonne ID d objects.csv, = `model` du 0x02) -> Icon.
var _object_icons: Dictionary = {}
var objects_loaded := false
var _textures: Dictionary = {}
var _cache: Dictionary = {}
var loaded := false
var csv_loaded := false
var report: Dictionary = {}


func setup(root: String) -> Dictionary:
	client_root = root.replace("\\", "/")
	_planches.clear(); _by_hundred.clear(); _textures.clear(); _cache.clear(); _rows.clear()
	_border_path = ""
	var icons_dir := client_root.path_join("icons")
	var dir := DirAccess.open(icons_dir)
	var families: Dictionary = {}
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			var lower := name.to_lower()
			if lower.ends_with(".bmp") and lower.contains("_"):
				var stem := lower.get_basename()
				var prefix := stem.get_slice("_", 0)
				var hundred := stem.get_slice("_", 1)
				if stem == BORDER_SHEET:
					_border_path = icons_dir.path_join(name)
				elif hundred.is_valid_int():
					_planches["%s:%d" % [prefix, int(hundred)]] = icons_dir.path_join(name)
					families[prefix] = int(families.get(prefix, 0)) + 1
					if not IGNORED_FAMILIES.has(prefix):
						_by_hundred[int(hundred)] = icons_dir.path_join(name)
			name = dir.get_next()
		dir.list_dir_end()
	loaded = int(families.get(SPELL_PREFIX, 0)) > 0
	var csv_report := _load_icons_csv(client_root.path_join("gamedata").path_join("icons.csv"))
	var spells_report := _load_spells_csv(client_root.path_join("gamedata").path_join("spells.csv"))
	var objects_report := _load_objects_csv(client_root.path_join("gamedata").path_join("objects.csv"))
	var styles_report := _load_styles_csv(client_root.path_join("gamedata").path_join("styles.csv"))
	report = {"ok": loaded, "planches": _planches.size(), "families": families, "sheets_by_hundred": _by_hundred.size(),
		"border_sheet": _border_path != "", "icons_csv": csv_report, "spells_csv": spells_report,
		"objects_csv": objects_report, "styles_csv": styles_report,
		"source": "CLIENT_ICONS_CSV_THEN_BMP" if csv_loaded else "CLIENT_ICONS_BMP_MODULO_FALLBACK"}
	return report


func _load_icons_csv(path: String) -> Dictionary:
	csv_loaded = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "icons.csv absent", "path": path}
	var rows := 0
	var with_border := 0
	var with_spell := 0
	var directional := 0
	while not file.eof_reached():
		var line := file.get_line()
		var cols := line.split(",")
		if cols.size() < 4 or not cols[0].is_valid_int():
			continue
		var entry := {"base": int(cols[2]), "border": int(cols[3]), "name": cols[1],
			"spell": int(cols[11]) if cols.size() > 11 and cols[11].is_valid_int() else -1, "directional": false}
		for index in range(4, mini(11, cols.size())):
			if cols[index].is_valid_int() and int(cols[index]) >= 0:
				entry["directional"] = true
		_rows[int(cols[0])] = entry
		rows += 1
		if int(entry["border"]) >= 0: with_border += 1
		if int(entry["spell"]) >= 0: with_spell += 1
		if bool(entry["directional"]): directional += 1
	csv_loaded = rows > 0
	return {"ok": csv_loaded, "rows": rows, "with_border": with_border, "with_spell_column": with_spell,
		"directional": directional, "path": path}


func _load_spells_csv(path: String) -> Dictionary:
	spells_loaded = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "spells.csv absent", "path": path}
	var rows := 0
	while not file.eof_reached():
		var cols := file.get_line().split(",")
		if cols.size() < 3 or not cols[0].is_valid_int() or not cols[2].is_valid_int():
			continue
		_spell_icons[int(cols[0])] = int(cols[2])
		rows += 1
	spells_loaded = rows > 0
	return {"ok": spells_loaded, "rows": rows, "path": path}


func _load_styles_csv(path: String) -> Dictionary:
	styles_loaded = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "styles.csv absent", "path": path}
	var rows := 0
	while not file.eof_reached():
		var cols := file.get_line().split(",")
		if cols.size() < 3 or not cols[0].is_valid_int() or not cols[2].is_valid_int():
			continue
		_style_icons[int(cols[0])] = int(cols[2])
		rows += 1
	styles_loaded = rows > 0
	return {"ok": styles_loaded, "rows": rows, "path": path}


## P1-128 — la famille d icone de chaque type d entree du 0x16 (SKILL_TYPES de
## DaocOpenDaocSkillListCodec) : style -> styles.csv, sort/chant -> spells.csv,
## capacite / capacite de royaume -> icons.csv direct.
static func family_for_kind(kind: String) -> String:
	match kind:
		"style":
			return "style"
		"spell", "song", "ability_spell":
			return "spell"
		_:
			return "skill"


## P1-88 — la ligne de icons.csv qu'un identifiant du serveur designe, selon
## la famille : un sort passe par spells.csv, une competence n'y passe pas.
func icons_row_for(icon_id: int, family: String = "spell") -> int:
	if (family == "spell" or family == SPELL_PREFIX) and spells_loaded and _spell_icons.has(icon_id) and int(_spell_icons[icon_id]) > 0:
		return int(_spell_icons[icon_id])
	if family == "style" and styles_loaded and _style_icons.has(icon_id) and int(_style_icons[icon_id]) > 0:
		return int(_style_icons[icon_id])
	return icon_id

## La texture 32 x 32 d'un identifiant d'icone du serveur, ou null si rien
## n'est sur le disque. `prefix` ne sert qu'au repli sans icons.csv.
func texture_for(icon_id: int, family: String = "spell") -> Texture2D:
	if icon_id <= 0:
		return null
	var key := "%s:%d" % [family, icon_id]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var result: Texture2D = null
	var row_id := icons_row_for(icon_id, family)
	if csv_loaded and _rows.has(row_id):
		result = _compose(_rows[row_id] as Dictionary)
	elif not csv_loaded:
		result = _cell_texture(str(_planches.get("%s:%d" % [SPELL_PREFIX, (icon_id / 100) * 100], "")), icon_id % 100)
	_cache[key] = result
	return result


func resolve(icon_id: int, family: String = "spell") -> Dictionary:
	var row_id := icons_row_for(icon_id, family)
	if csv_loaded and _rows.has(row_id):
		var row: Dictionary = _rows[row_id]
		var base := int(row["base"])
		return {"icon_id": icon_id, "family": family, "icons_csv_row": row_id, "via_spells_csv": row_id != icon_id,
			"name": str(row["name"]), "base": base, "border": int(row["border"]),
			"planche": str(_by_hundred.get((base / 100) * 100, "")), "cell": base % 100,
			"spell_column": int(row["spell"]), "directional": bool(row["directional"]),
			"found": texture_for(icon_id, family) != null, "via": "icons.csv"}
	var hundred := (icon_id / 100) * 100
	return {"icon_id": icon_id, "family": family, "icons_csv_row": row_id, "planche": str(_planches.get("%s:%d" % [SPELL_PREFIX, hundred], "")),
		"cell": icon_id % 100, "found": texture_for(icon_id, family) != null, "via": "modulo_fallback" if not csv_loaded else "icons.csv_row_missing"}


func _compose(row: Dictionary) -> Texture2D:
	var base := int(row["base"])
	var path := str(_by_hundred.get((base / 100) * 100, ""))
	if path == "":
		return null
	var border := int(row["border"])
	if border < 0 or _border_path == "":
		return _cell_texture(path, base % 100)
	var sheet := _image(path)
	var frames := _image(_border_path)
	if sheet == null:
		return null
	var image := _cell_image(sheet, base % 100)
	if frames != null:
		# brdr_0.bmp est un BMP 32 bits : l'interieur du cadre est alpha 0.
		image.blend_rect(_cell_image(frames, border), Rect2i(0, 0, CELL, CELL), Vector2i.ZERO)
	return ImageTexture.create_from_image(image)


func _cell_image(sheet: Image, cell: int) -> Image:
	return sheet.get_region(Rect2i((cell % PER_ROW) * CELL, (cell / PER_ROW) * CELL, CELL, CELL))


func _cell_texture(path: String, cell: int) -> Texture2D:
	if path == "":
		return null
	var planche := _planche(path)
	if planche == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = planche
	atlas.region = Rect2((cell % PER_ROW) * CELL, (cell / PER_ROW) * CELL, CELL, CELL)
	return atlas


func _image(path: String) -> Image:
	var key := "img:" + path
	if _textures.has(key):
		return _textures[key] as Image
	var image := Image.load_from_file(path)
	if image != null and image.is_empty():
		image = null
	if image != null and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_textures[key] = image
	return image


func _planche(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	var image := Image.load_from_file(path)
	var texture: Texture2D = null
	if image != null and not image.is_empty():
		texture = ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


## P1-96 — LES OBJETS ONT UNE TROISIEME MARCHE, dans `gamedata/objects.csv`
## (`ID, name, NIF, Icon, ...`) : l'ID est le MODELE que le 0x02 envoie pour
## chaque objet du sac, et `Icon` designe la ligne de icons.csv, donc la case
## des planches `itm_1200..1500` (armures, bijoux) et `wpn_900..1100, 1700`
## (armes). Preuve sur Heyvena : baton modele 19 -> Icon 209 -> base 909
## (wpn_900, case 9) ; cloth vest 139 -> 104 -> 1204 (itm_1200, case 4).
func _load_objects_csv(path: String) -> Dictionary:
	objects_loaded = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "objects.csv absent", "path": path}
	var rows := 0
	while not file.eof_reached():
		var cols := file.get_line().split(",")
		if cols.size() < 4 or not cols[0].is_valid_int() or not cols[3].is_valid_int():
			continue
		_object_icons[int(cols[0])] = int(cols[3])
		rows += 1
	objects_loaded = rows > 0
	return {"ok": objects_loaded, "rows": rows, "path": path}


func item_icon_id(model_id: int) -> int:
	return int(_object_icons.get(model_id, 0)) if objects_loaded else 0


func texture_for_item_model(model_id: int) -> Texture2D:
	var icon_id := item_icon_id(model_id)
	return texture_for(icon_id, "item") if icon_id > 0 else null


func resolve_item_model(model_id: int) -> Dictionary:
	var icon_id := item_icon_id(model_id)
	if icon_id <= 0:
		return {"model_id": model_id, "icon_id": 0, "found": false, "via": "objects.csv_row_missing" if objects_loaded else "objects.csv_absent"}
	var resolved := resolve(icon_id, "item")
	resolved["model_id"] = model_id
	resolved["via"] = "objects.csv->icons.csv"
	return resolved
