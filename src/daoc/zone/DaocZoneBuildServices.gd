extends RefCounted
class_name DaocZoneBuildServices

## R4 — la couture qui remplace les rappels de l'assembleur vers le ZoneViewer.
##
## `DaocZoneSceneAssembler` connaissait l'ordre de construction depuis P1-15B,
## mais pour CHAQUE etape il rappelait le ZoneViewer : sept `host.callv`, plus
## quatre autres rappels pour l'origine, le runtime terrain, le test « splat » et
## le HUD. Le chef d'orchestre n'avait pas d'orchestre.
##
## L'hote fournit desormais ses services UNE FOIS, sous forme d'objet. Les etapes
## consomment cet objet ; elles n'appellent plus le ZoneViewer par nom, et ne
## savent meme pas qu'il existe. Le jour ou la vraie scene remplace le viewer,
## c'est cet objet qu'on reconstruit — pas les etapes.
##
## Discipline habituelle : R4 deplace la PROPRIETE, pas la logique. Les
## constructeurs de domaine valides en 14A-14E (`DaocWaterBuilder`,
## `DaocTerrainBuilder`, `DaocPropBuilder`…) sont deja hors du monolithe et ne
## sont pas touches. Ce qui remonte ici, c'est la plomberie qui les entourait :
## collecte des reglages, resolution des chemins, accrochage dans la branche,
## ecriture des index de session.
##
## PROVISOIRE ET ASSUME : pour cette premiere tranche, la plupart des methodes
## delegent encore a l'hote. La couture est DECLAREE avant d'etre remplie —
## meme demarche qu'a R0, ou `DaocGameSession` a d'abord tenu des references
## avant de tenir quoi que ce soit d'autre. Chaque tranche suivante remplace une
## delegation par une implementation propre, sans jamais toucher aux etapes.

## L'hote qui expose encore les services. `null` est accepte : une suite peut
## fournir ses propres reponses sans monter un ZoneViewer.
var host: Node = null

## Le registre d'etat de session (`DaocZoneViewerStateRegistry`), ou les etapes
## deposent leurs index. Ces index sont PAR SESSION et non par zone : ils
## survivent au dechargement d'une zone, comme R1 l'a etabli.
var state: RefCounted = null


static func create(p_host: Node, p_state: RefCounted) -> DaocZoneBuildServices:
	var services := DaocZoneBuildServices.new()
	services.host = p_host
	services.state = p_state
	return services


## La branche d'une zone (`WaterRoot`, `TerrainRoot`…). Depuis R1 elle appartient
## au `DaocZoneStreamer` ; l'etape n'a pas a le savoir.
func zone_branch(znum: int, branch_name: String) -> Node3D:
	if host != null and host.has_method("_zone_branch"):
		return host.call("_zone_branch", znum, branch_name) as Node3D
	return null


## Chemin du `SECTOR.DAT` d'une zone. Six appelants le lisent dans le projet —
## eau, ciel, mer de region — donc c'est un service partage, pas un detail de
## l'etape eau.
func sector_dat_path(znum: int) -> String:
	if host != null and host.has_method("_find_sector_dat"):
		return str(host.call("_find_sector_dat", znum))
	return ""


func parse_sector_dat(path: String) -> Dictionary:
	if host != null and host.has_method("_parse_sector_dat"):
		return host.call("_parse_sector_dat", path) as Dictionary
	return {}


## Journalisation d'une etape. Centralisee pour qu'un futur mode silencieux ne
## demande pas de retoucher les sept etapes.
func log_step(enabled: bool, message: String) -> void:
	if enabled:
		print(message)


## Vraie si l'hote expose reellement ce qu'il faut pour construire. Une etape
## refuse de travailler a l'aveugle plutot que de produire une zone muette.
func usable() -> bool:
	return host != null and state != null


## Les reglages d'une etape, en DONNEES.
##
## C'est ce qui permet a l'assembleur de piloter une etape sans rappeler l'hote
## par le nom d'une methode de construction : il demande des reglages, pas un
## service rendu. Une etape ne lit jamais un `@export` elle-meme - elle refuse
## d'inventer une valeur par defaut qui divergerait de celle du viewer.
func step_settings(step_name: String) -> Dictionary:
	if host != null and host.has_method("zone_step_settings_r4"):
		return host.call("zone_step_settings_r4", step_name) as Dictionary
	return {}


## Une etape desactivee dans l'inspecteur ne doit pas etre lancee du tout.
func step_enabled(step_name: String) -> bool:
	if host != null and host.has_method("zone_step_enabled_r4"):
		return bool(host.call("zone_step_enabled_r4", step_name))
	return true


func step_logging(step_name: String) -> bool:
	if host != null and host.has_method("zone_step_logging_r4"):
		return bool(host.call("zone_step_logging_r4", step_name))
	return false


## Le module de rendu legacy (`DaocLegacyVisuals`), qui porte les lumieres de
## zone et les cartes de vegetation.
##
## POINT A DEBRANCHER, et c'est dit ici pour qu'on ne l'oublie pas : ce module
## se configure LUI-MEME depuis l'hote, par `configure_from_host`. Les etapes
## lumieres et vegetation ont donc bien change de proprietaire - l'assembleur ne
## rappelle plus le viewer - mais le module, lui, va encore chercher ses
## reglages dans le viewer. Couper ce dernier fil est la suite naturelle, et
## c'est aussi la ou des options de qualite graphique par reglage viendront se
## brancher proprement.
func visual_module() -> RefCounted:
	if host != null and host.has_method("_ensure_visual_module_15c"):
		return host.call("_ensure_visual_module_15c") as RefCounted
	return null


## Chemin d'un fichier de donnees 15D. Le registre d'assets sait ou il vit :
## cache decompresse, dossier local, ou `res://` pour une base pre-15D.
func asset_data_path(file_name: String) -> String:
	if host != null and host.has_method("_asset_data_15d"):
		return str(host.call("_asset_data_15d", file_name))
	return file_name


func asset_read_json(asset_file: String) -> Variant:
	if host != null and host.has_method("_asset_read_15d"):
		return host.call("_asset_read_15d", asset_file)
	return null


func asset_texture(asset_file: String) -> Texture2D:
	if host != null and host.has_method("_asset_tex_15d"):
		return host.call("_asset_tex_15d", asset_file) as Texture2D
	return null


## Prepare le shader « splat » et ses deux tableaux d'images pour une zone.
##
## Ces trois ressources sont PARTAGEES : elles vivent dans l'etat de session et
## non dans la branche de zone. C'est aussi ici que le repli qualite retire
## l'anisotropie du sampler `details` sans toucher au `.gdshader` source.
func prepare_terrain_splat_resources(znum: int, manifest: Dictionary) -> void:
	if host != null and host.has_method("_prepare_terrain_splat_resources_14e"):
		host.call("_prepare_terrain_splat_resources_14e", znum, manifest)


## La branche de collision d'une zone. Distincte de `zone_branch` parce que le
## terrain ecrit dans DEUX branches : le relief visible et les corps physiques.
func collision_branch(znum: int) -> Node3D:
	if host != null and host.has_method("_collision_root"):
		return host.call("_collision_root", znum) as Node3D
	return null


## Chemin d'un fichier de zone dans le client decompresse (`bound.csv`,
## `lights.csv`...). Distinct de `asset_data_path` : le registre 15D cherche ici
## dans le `datXXX` de la zone, pas dans les donnees generees.
func asset_zone_file(znum: int, file_name: String) -> String:
	if host != null and host.has_method("_asset_zone_file_15d"):
		return str(host.call("_asset_zone_file_15d", znum, file_name))
	return ""


func parse_zonejump_csv(path: String) -> Array:
	if host != null and host.has_method("get_asset_index_registry_15d"):
		var registry: Object = host.call("get_asset_index_registry_15d") as Object
		if registry != null and registry.has_method("parse_zonejump_csv"):
			return registry.call("parse_zonejump_csv", path) as Array
	return []


## Le runtime des transitions de zone, cree si besoin.
##
## Il n'est pas cree ici : sa construction CONNECTE un signal a la surface de
## debogage 15F de l'hote. Une etape qui l'instancierait elle-meme obtiendrait un
## runtime muet, dont personne n'ecouterait les entrees de corps.
func ensure_zonejump_runtime() -> Object:
	if host != null and host.has_method("_ensure_zonejump_runtime"):
		host.call("_ensure_zonejump_runtime")
	if state != null:
		return state.zonejump_runtime as Object
	return null


## Le registre d'assets 15D : index des modeles, resolution des chemins, releve
## des modeles manquants. L'etape props le consomme directement plutot que par
## six delegations distinctes — il porte deja son propre contrat.
func asset_index_registry() -> RefCounted:
	if host != null and host.has_method("get_asset_index_registry_15d"):
		return host.call("get_asset_index_registry_15d") as RefCounted
	return null


## Altitude du sol sous un point DAoC de zone.
##
## L'hote reste l'autorite : il arbitre entre le pont de donjon 17D, le runtime
## terrain 14E et la carte de hauteurs brute. Une etape qui echantillonnerait
## elle-meme la carte poserait les props sous le sol des donjons generes.
func sample_floor_z(znum: int, daoc_x: float, daoc_y: float, daoc_z: float = 0.0) -> float:
	if host != null and host.has_method("sample_daoc_floor_z"):
		return float(host.call("sample_daoc_floor_z", znum, daoc_x, daoc_y, daoc_z))
	return 0.0


## La branche des corps de collision de props, sous `CollisionRoot`. Distincte de
## `collision_branch` : les frontieres de zone et les props y sont voisins mais
## se rechargent separement.
func props_collision_branch(znum: int) -> Node3D:
	if host != null and host.has_method("_props_collision_root"):
		return host.call("_props_collision_root", znum) as Node3D
	return null


## Les reglages de collision de props, tels que le constructeur 14C les attend.
## Ils ne passent pas par `step_settings` : la DECISION appartient au
## constructeur, et c'est lui qui declare la forme de ce dictionnaire.
func prop_collision_settings() -> Dictionary:
	if host != null and host.has_method("_collision_prop_settings_14c"):
		return host.call("_collision_prop_settings_14c") as Dictionary
	return {}


## La table `fixtures.csv` d'une zone, mise en cache par l'hote. Une etape qui la
## relirait par fixture relirait le fichier des centaines de fois.
func fixture_collide_table(znum: int) -> Dictionary:
	if host != null and host.has_method("_load_fixture_collide_table_14c"):
		return host.call("_load_fixture_collide_table_14c", znum) as Dictionary
	return {}


## Ajoute un fragment a la ligne d'etat de l'ecran de debogage. Service et non
## champ : la vraie scene R6 n'aura pas le meme HUD que le banc.
func hud_append(fragment: String) -> void:
	if host != null and host.has_method("hud_append_zone_fragment_r4"):
		host.call("hud_append_zone_fragment_r4", fragment)
