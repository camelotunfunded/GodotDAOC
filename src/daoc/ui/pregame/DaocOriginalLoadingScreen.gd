extends Control
class_name DaocOriginalLoadingScreen

## 2026-09-30 — l'écran de chargement du client d'origine, reconstitué depuis
## `eden.dll.c` :
## - `FUN_0055c9da` ouvre la section `region%03d` de `gamedata/loading.dat`
##   (dans gamedata.mpk), lit `screens`, `widestyle`, `name`, `instance`, et
##   TIRE AU HASARD `screenNN` ; l'entrée est `archive://<mpk>:<nom>` et le
##   fichier réel `<nom>.dds` (`"%s.dds"`, FUN_0055fc33), casse ignorée ;
## - `FUN_0055fc33` pose la bannière sur TOUTE la largeur de l'écran, hauteur
##   au ratio de l'image (1024×256, donc largeur / 4), CENTRÉE verticalement,
##   fond noir ; l'élément suivant est 10 px sous la bannière ; le texte est en
##   MinionPro-Regular 20 (`ui/fonts/minionpro-regular.ttf`), centré ;
## - une astuce est tirée au hasard (`data/loading/tips.dat`, une par ligne).
## La barre de progression n'a pas de texture nommée dans le décompilé : elle
## est dessinée ici, sobre, sous la bannière. C'est la seule part non relevée.

const BANNER_ASPECT := 4.0

var client_root := ""
var region_id := -1
var region_name := ""
var banner_path := ""
var tip := ""

var _banner: TextureRect = null
var _title: Label = null
var _progress: ProgressBar = null
var _status: Label = null
var _tip: Label = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	if _banner != null:
		return
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_banner = TextureRect.new()
	_banner.name = "RegionBanner"
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_SCALE
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_title = _make_label(24)
	_title.name = "RegionName"
	_progress = ProgressBar.new()
	_progress.name = "LoadingProgress"
	_progress.show_percentage = false
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.05, 0.05, 1.0)
	back.border_color = Color(0.45, 0.38, 0.22)
	back.set_border_width_all(1)
	_progress.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.6, 0.3)
	_progress.add_theme_stylebox_override("fill", fill)
	add_child(_progress)
	_status = _make_label(16)
	_status.name = "LoadingText"
	_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_tip = _make_label(18)
	_tip.name = "Tip"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Bannière et nom de la région `region`, astuce au hasard. Rend ce qui a été choisi.
func prepare_for_region(root: String, region: int) -> Dictionary:
	_build()
	client_root = root.replace("\\", "/").trim_suffix("/")
	region_id = region
	_apply_font()
	var section := region_section(client_root, region)
	region_name = str(section.get("name", ""))
	var screens: Array = section.get("screens", []) as Array
	banner_path = ""
	_banner.texture = null
	if not screens.is_empty():
		banner_path = str(screens[_rng.randi_range(0, screens.size() - 1)])
		var image := load_screen_image(client_root, banner_path)
		if image != null:
			_banner.texture = ImageTexture.create_from_image(image)
	_title.text = region_name
	tip = random_tip(client_root, _rng)
	_tip.text = tip
	_layout()
	return {"region": region, "name": region_name, "screen": banner_path,
		"banner_loaded": _banner.texture != null, "tip": tip}


func set_status(text: String, progress: float) -> void:
	_build()
	_status.text = text
	_progress.value = clampf(progress, 0.0, 100.0)


func _layout() -> void:
	if _banner == null:
		return
	var w := size.x
	var h := w / BANNER_ASPECT
	var top := (size.y - h) * 0.5
	_banner.position = Vector2(0, top)
	_banner.size = Vector2(w, h)
	_title.position = Vector2(0, top - 44)
	_title.size = Vector2(w, 36)
	var below := top + h + 10.0
	_progress.position = Vector2(w * 0.25, below)
	_progress.size = Vector2(w * 0.5, 14)
	_status.position = Vector2(0, below + 20)
	_status.size = Vector2(w, 24)
	_tip.position = Vector2(w * 0.1, below + 52)
	_tip.size = Vector2(w * 0.8, 60)


func _apply_font() -> void:
	var path := client_root.path_join("ui/fonts/minionpro-regular.ttf")
	if not FileAccess.file_exists(path):
		return
	var font := FontFile.new()
	if font.load_dynamic_font(path) != OK:
		return
	for label in [_title, _status, _tip]:
		(label as Label).add_theme_font_override("font", font)


# --- lecture des données du client -----------------------------------------

## {name, screens[], widestyle, instance} de `[regionNNN]`, ou {} si absente.
static func region_section(root: String, region: int) -> Dictionary:
	var text := _read_client_text(root, "gamedata", "loading.dat")
	var wanted := "[region%03d]" % region
	var inside := false
	var out := {}
	var screens := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with(";") or line == "":
			continue
		if line.begins_with("["):
			if inside:
				break
			inside = line.to_lower() == wanted
			continue
		if not inside or not line.contains("="):
			continue
		var key := line.get_slice("=", 0).strip_edges().to_lower()
		var value := line.substr(line.find("=") + 1).strip_edges()
		if key.begins_with("screen") and key != "screens":
			screens[key] = value
		elif key in ["name"]:
			out[key] = value
		elif key in ["screens", "widestyle", "instance"]:
			out[key] = int(value)
	if not inside and out.is_empty():
		return {}
	var keys := screens.keys()
	keys.sort()
	var list: Array = []
	for key in keys:
		list.append(screens[key])
	# Comme le client : on ne tire que parmi les `screens` premiers.
	var count := int(out.get("screens", list.size()))
	out["screens"] = list.slice(0, count) if count > 0 else []
	return out


## `archive://data/loading/alb1.mpk:Avalon1` -> l'image de `Avalon1.dds`,
## prise dans le dossier extrait s'il existe, sinon dans l'archive.
static func load_screen_image(root: String, reference: String) -> Image:
	if not reference.begins_with("archive://") or not reference.contains(":"):
		return null
	var body := reference.substr("archive://".length())
	var archive_rel := body.substr(0, body.rfind(":"))
	var entry := body.substr(body.rfind(":") + 1) + ".dds"
	var archive_path := root.path_join(archive_rel)
	var bytes := PackedByteArray()
	var folder := archive_path.get_basename()
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			if file_name.to_lower() == entry.to_lower():
				bytes = FileAccess.get_file_as_bytes(folder.path_join(file_name))
				break
	if bytes.is_empty() and FileAccess.file_exists(archive_path):
		bytes = DaocMpkArchive.open(archive_path).read_file(entry)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_dds_from_buffer(bytes) != OK:
		return null
	if image.is_compressed():
		image.decompress()
	return image


static func random_tip(root: String, rng: RandomNumberGenerator) -> String:
	var lines: Array = []
	for raw in _read_client_text(root, "data/loading", "tips.dat").split("\n"):
		var line := raw.strip_edges()
		if line != "":
			lines.append(line)
	if lines.is_empty():
		return ""
	return str(lines[rng.randi_range(0, lines.size() - 1)])


## `<dir>/<file>` du client : fichier extrait, sinon `<dir>.mpk`
## (loading.dat vit dans gamedata.mpk).
static func _read_client_text(root: String, dir: String, file_name: String) -> String:
	var loose := root.path_join(dir).path_join(file_name)
	if FileAccess.file_exists(loose):
		return FileAccess.get_file_as_bytes(loose).get_string_from_ascii()
	var archive := root.path_join(dir + ".mpk")
	if FileAccess.file_exists(archive):
		return DaocMpkArchive.open(archive).read_file(file_name).get_string_from_ascii()
	return ""
