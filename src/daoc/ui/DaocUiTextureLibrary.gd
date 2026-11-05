extends RefCounted
class_name DaocUiTextureLibrary

## P1-21D - resout les noms de texture de l'interface vers les images du client.
##
## `assets.xml` associe un NOM logique (`page1`, `frames_win`) a un fichier
## relatif a `ui/`. Les gabarits ne citent ensuite que le nom. Un nom non resolu
## ne leve aucune erreur dans le client d'origine : la zone reste vide. Ici il
## est COMPTE et nomme, parce qu'une fenetre vide est indiscernable d'une
## fenetre correcte tant qu'on ne regarde pas.
##
## Les images sont lues DIRECTEMENT dans le client, jamais copiees ni importees
## dans `res://`, comme les PNG de terrain, d'eau et de ciel.
##
## Etat du disque au 2026-09-03 : `atlantis/slider.tga` est declare par
## `assets.xml` mais ABSENT. C'est un trou du client, pas du lecteur.

## Extensions que Godot sait decoder depuis un tampon memoire.
const LOADERS := ["tga", "bmp", "png", "jpg", "jpeg", "webp", "dds"]

## Racine `ui/` du client, hors depot.
var ui_root: String = ""

## Nom logique -> chemin relatif declare par `assets.xml`.
var declared: Dictionary = {}

## Nom logique -> Texture2D chargee.
var textures: Dictionary = {}

## Noms cites par les gabarits et introuvables dans `assets.xml`.
var undeclared: PackedStringArray = PackedStringArray()

## Noms declares dont le fichier n'existe pas sur le disque.
var missing_files: PackedStringArray = PackedStringArray()

## Fichiers presents mais que Godot n'a pas su decoder.
var undecodable: PackedStringArray = PackedStringArray()


## Lit les declarations `<Texture>` d'un `assets.xml` deja analyse.
static func from_contract(ui_root_path: String, contract: DaocUiSkinContract) -> DaocUiTextureLibrary:
	var library: DaocUiTextureLibrary = DaocUiTextureLibrary.new()
	library.ui_root = ui_root_path
	for result: DaocUiParseResult in contract.files:
		if result.source_path.get_file().to_lower() != "assets.xml":
			continue
		library._read_declarations(result)
	return library


## Renvoie la texture d'un nom logique, ou `null`. Le premier appel charge le
## fichier ; les suivants relisent le cache.
func get_texture(logical_name: String) -> Texture2D:
	var name: String = logical_name.strip_edges()
	if name == "" or name.to_lower() == "none":
		return null
	if textures.has(name):
		return textures[name]
	if not declared.has(name):
		if not undeclared.has(name):
			undeclared.append(name)
		return null

	var relative: String = str(declared[name])
	var absolute: String = ui_root.path_join(relative)
	if not FileAccess.file_exists(absolute):
		if not missing_files.has(name):
			missing_files.append(name)
		textures[name] = null
		return null

	var image: Image = _load_image(absolute)
	if image == null:
		if not undecodable.has(name):
			undecodable.append(name)
		textures[name] = null
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[name] = texture
	return texture


## Decoupe une region d'atlas. Les coordonnees XML sont en pixels, origine en
## haut a gauche, et correspondent 1:1 aux pixels de la texture.
func get_region(logical_name: String, top_left: Vector2i, size: Vector2i) -> AtlasTexture:
	var base: Texture2D = get_texture(logical_name)
	if base == null or size.x <= 0 or size.y <= 0:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(top_left, size)
	atlas.filter_clip = true
	return atlas


func is_ok() -> bool:
	return undeclared.is_empty() and missing_files.is_empty() and undecodable.is_empty()


func get_debug_snapshot() -> Dictionary:
	return {
		"declared": declared.size(),
		"loaded": _loaded_count(),
		"undeclared": undeclared.size(),
		"missing_files": missing_files.size(),
		"undecodable": undecodable.size(),
	}


# ---------------------------------------------------------------------------

func _read_declarations(result: DaocUiParseResult) -> void:
	var file: FileAccess = FileAccess.open(result.source_path, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("<Texture>\\s*<Name>([^<]+)</Name>\\s*<File>([^<]+)</File>")
	for found: RegExMatch in pattern.search_all(text):
		var name: String = found.get_string(1).strip_edges()
		var path: String = found.get_string(2).strip_edges().replace("\\", "/")
		if name != "":
			declared[name] = path


## Godot choisit le decodeur d'apres l'extension : le format n'est jamais
## devine d'apres le contenu, et une extension inconnue n'est pas tentee.
func _load_image(absolute_path: String) -> Image:
	var extension: String = absolute_path.get_extension().to_lower()
	if not LOADERS.has(extension):
		return null
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		return null

	var image: Image = Image.new()
	var error: int = FAILED
	match extension:
		"tga":
			error = image.load_tga_from_buffer(bytes)
		"bmp":
			error = image.load_bmp_from_buffer(bytes)
		"png":
			error = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			error = image.load_jpg_from_buffer(bytes)
		"webp":
			error = image.load_webp_from_buffer(bytes)
		"dds":
			if image.has_method("load_dds_from_buffer"):
				error = image.call("load_dds_from_buffer", bytes)
	if error != OK or image.is_empty():
		return null
	return image


func _loaded_count() -> int:
	var total: int = 0
	for name: String in textures:
		if textures[name] != null:
			total += 1
	return total
