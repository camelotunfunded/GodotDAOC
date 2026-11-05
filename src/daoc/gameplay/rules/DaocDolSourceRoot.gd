extends RefCounted
class_name DaocDolSourceRoot

## P1-23 — la racine de l'arbre de sources DOL, quelle que soit la LETTRE.
##
## MÊME PIÈGE, MÊME REMÈDE. `DaocClientRoot` existe parce que le projet est
## ouvert depuis plusieurs machines et que le disque n'y porte pas la même
## lettre — piège payé trois fois dans la même journée. L'arbre `DOLSharp-master`
## vit dans le même voisinage que le client, et se perdrait de la même façon.
##
## LA DIFFÉRENCE AVEC LE CLIENT, et elle est structurante : **rien au runtime ne
## dépend de cette racine.** Les formules de `DaocDolFormulas` sont PORTÉES, pas
## lues. Cette racine ne sert qu'aux OUTILS et aux SUITES qui veulent confronter
## le portage à sa source. Une racine introuvable n'est donc pas une panne : elle
## veut dire « la contre-épreuve ne peut pas être jouée ici », et la suite doit
## le DIRE au lieu de passer au vert en silence.
##
## L'ordre de résolution est celui de `DaocClientRoot`, sans exception :
##   1. le chemin configuré, s'il existe ;
##   2. le même, avec la lettre du lecteur où se trouve `res://` ;
##   3. la variable d'environnement `DOL_SOURCE_ROOT`, telle quelle ;
##   4. la même, relettrée ;
##   5. le voisinage de `res://` — trois niveaux au-dessus du projet.
##
## Le voisinage est à TROIS niveaux, pas deux comme pour le client : le client
## vit dans `0_ version GODOT`, l'arbre DOL vit un cran plus haut, à côté de lui.

const DOL_FOLDER_NAME := "DOLSharp-master"

## Le fichier témoin qui prouve qu'un dossier est bien l'arbre DOL et pas un
## homonyme vide. Un dossier qui existe mais ne porte pas ce fichier n'est pas
## une racine — c'est exactement le genre de faux positif qui rend une suite
## verte sur rien.
const WITNESS_RELATIVE_PATH := "GameServer/gameobjects/GameLiving.cs"


static func project_drive() -> String:
	var absolute := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if absolute.length() >= 2 and absolute[1] == ":":
		return absolute.substr(0, 2)
	return ""


static func with_project_drive(path: String) -> String:
	var normalised := path.replace("\\", "/").strip_edges()
	if normalised.length() < 2 or normalised[1] != ":":
		return normalised
	var drive := project_drive()
	if drive == "":
		return normalised
	return drive + normalised.substr(2)


## Trois niveaux au-dessus de `res://`. Dans cette arborescence :
## `<lecteur>/00_Mod HD daoc test`.
static func project_neighbourhood() -> String:
	var absolute := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	return absolute.get_base_dir().get_base_dir().get_base_dir()


static func _is_dol_root(path: String) -> bool:
	var candidate := path.replace("\\", "/").strip_edges().trim_suffix("/")
	if candidate == "":
		return false
	if not DirAccess.dir_exists_absolute(candidate):
		return false
	return FileAccess.file_exists(candidate.path_join(WITNESS_RELATIVE_PATH))


## Rend TOUJOURS un dictionnaire, jamais une chaîne nue : l'appelant doit pouvoir
## dire d'où vient le chemin retenu, et surtout pouvoir dire « aucun ».
static func resolve(configured: String = "") -> Dictionary:
	var tried: Array[String] = []
	var candidates: Array = []

	var wanted := configured.replace("\\", "/").strip_edges().trim_suffix("/")
	if wanted != "":
		candidates.append(["configure", wanted])
		var relettered := with_project_drive(wanted)
		if relettered != wanted:
			candidates.append(["lettre_du_projet", relettered])

	var from_env := OS.get_environment("DOL_SOURCE_ROOT").replace("\\", "/").strip_edges().trim_suffix("/")
	if from_env != "":
		candidates.append(["environnement", from_env])
		var env_relettered := with_project_drive(from_env)
		if env_relettered != from_env:
			candidates.append(["environnement_relettre", env_relettered])

	candidates.append(["voisinage_du_projet", project_neighbourhood().path_join(DOL_FOLDER_NAME)])

	for entry in candidates:
		var source: String = str(entry[0])
		var path: String = str(entry[1])
		tried.append("%s=%s" % [source, path])
		if _is_dol_root(path):
			return {
				"ok": true,
				"root": path,
				"source": source,
				"healed": source != "configure" and source != "environnement",
				"tried": tried,
			}

	return {"ok": false, "root": "", "source": "aucun", "healed": false, "tried": tried}


static func resolve_path(configured: String = "") -> String:
	return str(resolve(configured).get("root", ""))


## Le chemin absolu d'un fichier source, ou la chaîne vide si la racine manque.
static func source_file(relative_path: String, configured: String = "") -> String:
	var root := resolve_path(configured)
	if root == "":
		return ""
	var absolute := root.path_join(relative_path)
	return absolute if FileAccess.file_exists(absolute) else ""
