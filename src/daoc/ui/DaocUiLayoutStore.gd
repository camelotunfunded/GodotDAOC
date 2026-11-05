extends RefCounted
class_name DaocUiLayoutStore

## P1-21F - se souvient de la disposition choisie par le joueur.
##
## L'original ecrit un `.ini` dans les donnees utilisateur : position de chaque
## fenetre et liste de celles qui sont ouvertes. `user://` est l'equivalent
## exact sous Godot - sur Windows, `%APPDATA%\Godot\app_userdata\<projet>` - et
## `ConfigFile` lit et ecrit ce format nativement.
##
## Le fichier appartient au JOUEUR. Il n'est jamais livre avec le projet, et son
## absence n'est pas une erreur : la premiere session part de la disposition par
## defaut, puis ecrit la sienne.
##
## Rien n'est valide a l'ecriture. En revanche une position relue est BORNEE a
## l'ecran courant : un joueur qui change de resolution ne doit pas retrouver
## ses fenetres hors cadre, et un fichier corrompu ne doit pas les faire
## disparaitre.

const DEFAULT_PATH: String = "user://daoc_ui_layout.ini"

## Marge minimale visible a l'ecran quand une position est ramenee dans le cadre.
const MIN_VISIBLE: float = 24.0

var path: String = DEFAULT_PATH

## Vrai si un fichier existait a la lecture.
var loaded_from_disk: bool = false

## Nombre de positions ramenees dans le cadre a la lecture.
var clamped: int = 0

var _config: ConfigFile = null


func _init(store_path: String = DEFAULT_PATH) -> void:
	path = store_path
	_config = ConfigFile.new()


## Lit le fichier s'il existe. Une absence renvoie `false` sans erreur.
func load_layout() -> bool:
	loaded_from_disk = _config.load(path) == OK
	return loaded_from_disk


func save_layout() -> int:
	return _config.save(path)


func has_window(name: String) -> bool:
	return _config.has_section(name)


## Position enregistree, ramenee dans `screen`. `fallback` sert quand la
## fenetre est inconnue du fichier.
func get_position(name: String, size: Vector2, screen: Vector2, fallback: Vector2) -> Vector2:
	if not _config.has_section_key(name, "x") or not _config.has_section_key(name, "y"):
		return fallback
	var stored: Vector2 = Vector2(
		float(_config.get_value(name, "x", fallback.x)),
		float(_config.get_value(name, "y", fallback.y)))
	var bounded: Vector2 = _clamp_to_screen(stored, size, screen)
	if not bounded.is_equal_approx(stored):
		clamped += 1
	return bounded


func get_visible(name: String, fallback: bool) -> bool:
	if not _config.has_section_key(name, "visible"):
		return fallback
	return bool(_config.get_value(name, "visible", fallback))


func set_window(name: String, position: Vector2, visible: bool) -> void:
	_config.set_value(name, "x", int(round(position.x)))
	_config.set_value(name, "y", int(round(position.y)))
	_config.set_value(name, "visible", visible)


func get_debug_snapshot() -> Dictionary:
	return {
		"path": path,
		"absolute": ProjectSettings.globalize_path(path),
		"loaded_from_disk": loaded_from_disk,
		"windows": _config.get_sections().size(),
		"clamped": clamped,
	}


# ---------------------------------------------------------------------------

## Une fenetre doit toujours garder un morceau attrapable a l'ecran : on borne
## la position, on ne la rejette pas.
func _clamp_to_screen(position: Vector2, size: Vector2, screen: Vector2) -> Vector2:
	if screen.x <= 1.0 or screen.y <= 1.0:
		return position
	return Vector2(
		clampf(position.x, MIN_VISIBLE - size.x, screen.x - MIN_VISIBLE),
		clampf(position.y, 0.0, screen.y - MIN_VISIBLE))
