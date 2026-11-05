extends RefCounted
class_name DaocClientRoot

## R10-HF1 — la racine du client DAoC, quelle que soit la LETTRE DE LECTEUR.
##
## POURQUOI CE FICHIER EXISTE. Le projet est ouvert depuis plusieurs machines, et
## le disque n'y porte pas la même lettre : `D:` sur l'une, `E:` sur l'autre. Un
## chemin absolu écrit en dur est donc faux la moitié du temps, et il l'a été
## trois fois dans la même journée le 2026-09-08 — le protocole de test,
## `DaocGame.tscn`, et la jonction des arbres.
##
## AUCUN DE CES TROIS ÉCHECS N'A DIT SON NOM. Un client introuvable ne lève pas
## d'erreur : il rend des listes vides, des zones sans texture, des arbres
## absents. C'est ce qui rend la panne coûteuse — elle ressemble à un bug de
## rendu.
##
## LA RÈGLE, dans cet ordre :
##
##   1. le chemin CONFIGURÉ, s'il existe — la correction à la main gagne
##      TOUJOURS, et c'est ce qui permet un client rangé ailleurs ;
##   2. le même chemin, avec la lettre du lecteur où se trouve `res://` — le cas
##      courant : même arborescence, autre machine ;
##   3. la variable d'environnement `DAOC_CLIENT_ROOT`, telle quelle ;
##   4. la variable d'environnement, relettrée de la même façon ;
##   5. le voisinage de `res://` — deux niveaux au-dessus du projet, où le client
##      vit dans cette arborescence.
##
## La règle 1 avant tout le reste est le point important : on ne « corrige »
## jamais un chemin qui marche.

## Le nom du dossier du client dans l'arborescence du projet, pour la règle 5.
const CLIENT_FOLDER_NAME := "Dark Age of Camelot"


## La lettre du lecteur où vit le projet, `E:` par exemple. Vide hors Windows.
static func project_drive() -> String:
	var absolute := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if absolute.length() >= 2 and absolute[1] == ":":
		return absolute.substr(0, 2)
	return ""


## Le dossier qui contient le projet, deux niveaux au-dessus de `res://`.
## Dans cette arborescence : `<lecteur>/00_Mod HD daoc test/0_ version GODOT`.
static func project_neighbourhood() -> String:
	var absolute := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	return absolute.get_base_dir().get_base_dir()


## Remplace la lettre de lecteur d'un chemin par celle du projet. Rend le chemin
## inchangé s'il n'en porte pas — un chemin relatif ou UNC n'est pas concerné.
static func with_project_drive(path: String) -> String:
	var normalised := path.replace("\\", "/").strip_edges()
	if normalised.length() < 2 or normalised[1] != ":":
		return normalised
	var drive := project_drive()
	if drive == "":
		return normalised
	return drive + normalised.substr(2)


static func _exists(path: String) -> bool:
	var candidate := path.replace("\\", "/").strip_edges().trim_suffix("/")
	if candidate == "":
		return false
	return DirAccess.dir_exists_absolute(candidate)


## Résout la racine du client. Rend TOUJOURS un dictionnaire, jamais une chaîne
## nue : l'appelant doit pouvoir dire d'où vient le chemin retenu, et un
## diagnostic muet est exactement ce qui a coûté trois heures.
##
## `ok` faux ne veut pas dire « erreur » : un outil hors ligne peut légitimement
## travailler sans client. Il veut dire « aucun des cinq candidats n'existe ».
static func resolve(configured: String = "") -> Dictionary:
	var tried: Array[String] = []
	var candidates: Array = []

	var wanted := configured.replace("\\", "/").strip_edges().trim_suffix("/")
	if wanted != "":
		candidates.append(["configure", wanted])
		var relettered := with_project_drive(wanted)
		if relettered != wanted:
			candidates.append(["lettre_du_projet", relettered])

	var from_env := OS.get_environment("DAOC_CLIENT_ROOT").replace("\\", "/").strip_edges().trim_suffix("/")
	if from_env != "":
		candidates.append(["environnement", from_env])
		var env_relettered := with_project_drive(from_env)
		if env_relettered != from_env:
			candidates.append(["environnement_relettre", env_relettered])

	var neighbour := project_neighbourhood().path_join(CLIENT_FOLDER_NAME)
	candidates.append(["voisinage_du_projet", neighbour])

	for entry in candidates:
		var source: String = str(entry[0])
		var path: String = str(entry[1])
		tried.append("%s=%s" % [source, path])
		if _exists(path):
			return {
				"ok": true,
				"root": path,
				"source": source,
				"healed": source != "configure" and source != "environnement",
				"tried": tried,
			}

	return {"ok": false, "root": "", "source": "aucun", "healed": false, "tried": tried}


## Le chemin seul, pour les appelants qui n'ont pas besoin du diagnostic.
static func resolve_path(configured: String = "") -> String:
	return str(resolve(configured).get("root", ""))
