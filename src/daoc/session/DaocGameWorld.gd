extends Node3D
class_name DaocGameWorld

signal startup_progress(text: String, value: float)

## R6 — la scène du JEU, enfin distincte du banc.
##
## `ZoneViewer.tscn` était le jeu ET l'atelier : 318 propriétés d'inspecteur, un
## HUD de diagnostic, des sondes, des captures, des grilles de parade. Rien de
## tout cela n'a sa place dans un client. Mais rien de tout cela ne pouvait
## partir tant que le viewer était aussi le PROPRIÉTAIRE du monde — c'est ce que
## R0 à R5 ont défait, un propriétaire à la fois :
##
##   R0  la session possède les systèmes persistants
##   R1  le streamer possède les zones jetables
##   R4  les étapes possèdent la construction, l'hôte ne renzdd que des services
##   R5  franchir une frontière charge la voisine et décharge l'ancienne
##
## Il ne restait donc plus, pour faire une scène de jeu, qu'à écrire un HÔTE.
## C'est tout ce que ce fichier est : les mêmes services, rendus sans inspecteur.
## Aucun constructeur, aucune étape, aucun runtime n'est réécrit — la preuve du
## jalon est que la MÊME zone bâtie par le banc et par le jeu donne les mêmes
## index de session, signature par signature.
##
## R7 y ajoute la PILE JOUEUR : la capsule, la caméra et le routeur d'entrées,
## montés dans les emplacements de session que R0 avait nommés. La scène cesse
## donc d'être un décor — on peut s'y tenir, s'y déplacer, et en sortir par une
## frontière, ce que R5 avait rendu possible.
##
## R8 a porte le ciel, R9 les 311 entites, R10 la vegetation et l'horizon, puis
## R11 l'autorite de combat locale et l'interface XML. Ces systemes vivent dans
## la session et survivent donc aux changements de zone. Les donjons generes
## 17D ne sont pas encore cables : `sample_floordz` retombe sur le relief.
##
## AUCUN NŒUD RÉSEAU n'est monté, et ce n'est pas un effet de bord : le garde
## `mount_dol_and_hud` le déclare explicitement à faux. Parmi les onze montages
## qu'il couvre se trouvent le transport DOL et le flux de login — les laisser
## dépendre de propriétés absentes reviendrait à laisser `bool(null)` décider
## d'ouvrir une connexion.

const AssetIndexRegistryScript = preload("res://src/daoc/DaocAssetIndexRegistry.gd")
const LegacyVisualsScript = preload("res://src/daoc/DaocLegacyVisuals.gd")
const TerrainRuntimeScript = preload("res://src/daoc/DaocTerrainRuntime.gd")
const ZoneJumpRuntimeScript = preload("res://src/daoc/DaocZoneJumpRuntime.gd")
const LocalViewerBootstrapScript = preload("res://src/daoc/DaocLocalViewerBootstrap.gd")
const DaocZoneEnvironmentProfileScript = preload("res://src/daoc/environment/DaocZoneEnvironmentProfile.gd")
const DaocWeatherFrontStateScript = preload("res://src/daoc/environment/DaocWeatherFrontState.gd")
const DaocVisualRoadmapProfileScript = preload("res://src/daoc/environment/DaocVisualRoadmapProfile.gd")
const DaocEnvironmentControllerScript = preload("res://src/daoc/environment/DaocEnvironmentController.gd")
const DaocSky3DAdapterScript = preload("res://src/daoc/environment/DaocSky3DAdapter.gd")
const DaocWeatherFxScript = preload("res://src/daoc/environment/DaocWeatherFx.gd")
const DaocAmbientWildlifeScript = preload("res://src/daoc/environment/DaocAmbientWildlife.gd")
const DaocWorldPbrUpgradeScript = preload("res://src/daoc/world/DaocWorldPbrUpgrade.gd")
const DaocPlayerTorchScript = preload("res://src/daoc/player/DaocPlayerTorch.gd")
const DaocHeadingScript = preload("res://src/daoc/world/DaocHeading.gd")
const DaocGothwaitePopulationScript = preload("res://src/daoc/offline/DaocGothwaitePopulation.gd")
const DaocDistantTerrainScript = preload("res://src/daoc/world/DaocDistantTerrain.gd")
const DaocPlayerVisualMeshySwapScript = preload("res://src/daoc/player/DaocPlayerVisualMeshySwap.gd")

const PLAYER_APPEARANCE_SCENES := {
	0: "res://assets/daoc/player/briton_female_modern/briton_female_simple_plate_04.tscn",
	1: "res://assets/daoc/player/troll_male_modern/troll_male_chain.tscn",
	2: "res://assets/daoc/player/lurikeen_male_modern/lurikeen_male_leather.tscn",
}
const DaocClientRootScript = preload("res://src/daoc/DaocClientRoot.gd")
const DaocLocalServerScript = preload("res://src/daoc/server/DaocLocalServer.gd")
const DaocCombatClientScript = preload("res://src/daoc/gameplay/runtime/DaocCombatClient.gd")
const DaocServerAnimationRuntimeScript = preload("res://src/daoc/gameplay/runtime/DaocServerAnimationRuntime.gd")
const DaocCombatHudScript = preload("res://src/daoc/ui/DaocCombatHud.gd")
const DaocUiWindowManagerScript = preload("res://src/daoc/ui/DaocUiWindowManager.gd")
const DaocUiAdapterBusScript = preload("res://src/daoc/ui/DaocUiAdapterBus.gd")
const DaocUiServerBridgeScript = preload("res://src/daoc/ui/DaocUiServerBridge.gd")
const DaocUiLayoutStoreScript = preload("res://src/daoc/ui/DaocUiLayoutStore.gd")
const DaocAlphaInventoryScript = preload("res://src/daoc/ui/DaocAlphaInventory.gd")
const DaocNearbyWorldEntitySourceScript = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldEntitySource.gd")

## L'ordre de ces déclarations est aussi celui de l'inspecteur Godot. Les noms
## techniques des propriétés restent stables pour préserver les scènes et les
## tests ; les groupes et les info-bulles présentent leur rôle en français.

@export_group("Monde et zones")
@export_subgroup("Profil visuel global")
## Lot esthétique uniquement. Décochez-le pour reprendre la main sur chaque
## réglage sans changer les données de zone, les collisions ou le réseau.
@export var visual_roadmap_enabled: bool = true
@export_enum("Faible:0", "Élevé:1", "Capture:2") var visual_roadmap_quality: int = 1
@export_subgroup("Chemins du client DAoC")
## Racine du client DAoC décompressé. Tout le reste en découle par le registre
## d'assets. Le dossier original est seulement lu : il n'est jamais modifié.
@export_global_dir var daoc_client_root: String = ""
## Surcharge facultative du dossier de données préparées. Laisser vide pour
## utiliser les données trouvées depuis la racine du client ou dans le projet.
@export_global_dir var external_data_dir: String = ""

@export_subgroup("Zone de départ et streaming")
## Numéro de la zone où commence la partie. Les zones voisines sont chargées
## ensuite lorsque le joueur franchit une frontière.
@export var start_zone: int = 51
## Construit la zone de départ automatiquement à l'ouverture de la scène.
## Décocher uniquement pour piloter le montage manuellement ou depuis un test.
@export var build_on_ready: bool = false
## Nombre maximal de zones conservées en mémoire. La zone occupée par le joueur
## n'est jamais déchargée ; 2 permet un aller-retour rapide à la frontière.
@export_range(1, 8, 1) var max_resident_zones: int = 2
## P1-33G — la voisine est bâtie AVANT le bord, pendant que le joueur marche, au
## lieu de l'instant du franchissement. Rayon = marge + vitesse × secondes,
## valeurs du banc dans `P1_33_SETTINGS`. Le figement de ~4,5 s n'est pas
## supprimé, il est déplacé ; le budget `max_resident_zones` reste maître.
@export var zone_prefetch_enabled: bool = true
## 2026-09-27 — le préchargement étale ses étapes sur plusieurs images (terrain
## et frontières d abord, puis une étape par image) au lieu d un seul gel.
@export var zone_prefetch_spread_enabled: bool = true
## P1-33G — palier PROCHE de l'horizon : la zone lointaine qui partage une vraie
## frontière avec une résidente et dont on s'approche est rendue à l'atlas natif
## 2048 px et au pas 1 dans une bande de 8192 unités. Décoché, l'horizon est
## exactement celui d'avant P1-33 — et c'est ~22 Mio de moins par zone servie.
@export var distant_near_border_lod_enabled: bool = true

@export_subgroup("Échelle du monde")
## Conversion des unités DAoC brutes vers les unités Godot. 1,0 conserve
## l'échelle native ; tous les réglages suffixés `_raw` sont appliqués avant.
@export var world_scale: float = 1.0
## Multiplicateur vertical du relief. Réglage visuel uniquement : garder 1,0
## pour respecter les hauteurs de jeu.
@export var height_exaggeration: float = 1.0

@export_group("Démarrage de la partie")
@export_subgroup("Montage automatique")
## Monte le joueur, sa caméra et le routeur d'entrées après la construction de
## la zone. Le joueur a besoin du relief pour être posé correctement.
@export var mount_player_on_ready: bool = true
## Attache le modèle visuel de Heyveno à la capsule du joueur après son montage.
## Ce chemin est local et n'active aucun composant réseau.
@export var mount_player_visual_on_ready: bool = true
## Monte l'autorité d'environnement DAoC et le ciel dynamique. Sans elle, la
## scène n'a aucune source de lumière puisque les lumières legacy sont coupées.
@export var mount_environment_on_ready: bool = true
## Ajoute oiseaux, papillons et insectes en trois lots instancies, sans gameplay.
@export var mount_ambient_wildlife_on_ready: bool = true
@export_subgroup("Faune ambiante")
## Chaque espece reste un seul lot de rendu, quelle que soit cette quantite.
@export_range(0, 128, 1) var ambient_bird_count: int = 24
@export_range(0, 256, 1) var ambient_butterfly_count: int = 16
@export_range(0, 512, 1) var ambient_insect_count: int = 72
## Feuilles mortes qui tombent autour du joueur (losanges low poly, 0 = aucune).
@export_range(0, 256, 1) var ambient_leaf_count: int = 18
## Peuple Gothwaite avec les 311 entités de la capture hors ligne. Cette étape
## instancie 307 scènes complètes et augmente sensiblement le temps de démarrage.
@export var mount_population_on_ready: bool = true
## Construit le relief lointain après les zones résidentes et le reconstruit
## automatiquement lorsque leur liste change.
@export var mount_horizon_on_ready: bool = true
## Monte l'autorite de combat locale puis l'interface XML, sans aucun transport.
@export var mount_gameplay_ui_on_ready: bool = true

@export_group("Interface de jeu")
@export var daoc_ui_enabled: bool = true
@export var daoc_ui_skin: String = "atlantis"
@export_range(0.5, 4.0, 0.05) var daoc_ui_scale: float = 1.0
## Laisser a zero pour employer la taille reelle de la fenetre. Une valeur
## explicite reste disponible pour les captures et les tests reproductibles.
@export var daoc_ui_reference_resolution: Vector2i = Vector2i.ZERO
@export_file("*.ini") var daoc_ui_layout_path: String = "user://daoc_ui_layout.ini"
@export var daoc_ui_windows: PackedStringArray = PackedStringArray([
	"stats_index", "summary", "float_target", "command",
	"stats_attributes", "stats_spec_abil", "stats_combat", "stats_spells", "stats_group",
	"minigroup", "miniinfo", "clock",
])
## Le journal provisoire reste present tant qu'aucune fenetre XML de chat ne le remplace.
@export var combat_log_fallback_enabled: bool = true
## P1-93 — le personnage demarre les logements VIDES, la panoplie de depart dans
## le sac ; il s'equipe depuis l'inventaire. Decoche = porte au demarrage (P1-24).
@export var player_starts_unequipped: bool = true
## Niveau du joueur remis a l'arbitre. IL ETAIT ECRIT EN DUR A 5, et ce n'etait
## pas anodin : un rat de niveau 1 est GRIS pour un niveau 5 - la bascule tombe
## au 4 - donc il ne rapporte AUCUNE experience et meurt en deux coups. Le
## 2026-09-09, deux verdicts visuels ont bute sur ce seul chiffre : ni gain
## d'experience, ni blocage au bouclier, ni absorption d'armure observables. Le
## defaut est desormais 1, et la valeur se regle sans toucher au code.
@export_range(1, 50, 1) var local_server_player_level: int = 1
## P1-30 — le clic DROIT sur un cadavre le ramasse. Decoche restaure exactement
## l'etat d'avant le jalon : le clic droit ne fait plus rien, et le butin reste
## prouve par sa suite sans etre atteignable en jeu.
@export var corpse_looting_enabled: bool = true
@export_range(50.0, 1000.0, 10.0) var local_server_melee_range_raw: float = 200.0
@export_range(200.0, 10000.0, 100.0) var combat_target_radius_raw: float = 2400.0
@export var combat_target_key: Key = KEY_TAB
@export var combat_attack_key: Key = KEY_1
@export var mouse_targeting_enabled: bool = true
@export_range(1.0, 64.0, 1.0) var mouse_targeting_pixel_tolerance: float = 8.0
@export_range(1000.0, 50000.0, 500.0) var mouse_targeting_max_distance_raw: float = 18000.0

@export_group("Joueur - apparition et contrôles")
@export_subgroup("Apparition")
## Coordonnée X de départ dans la zone, en unités DAoC. La valeur par défaut est
## la position canonique de Heyveno à Gothwaite.
@export var player_start_x: float = 33952.0
## Coordonnée Y de départ dans la zone, en unités DAoC.
@export var player_start_y: float = 52899.0
## Orientation initiale du joueur, en degrés.
@export_range(-360.0, 360.0, 1.0) var player_start_heading_deg: float = 0.0

@export_subgroup("Déplacement")
## Vitesse de course hors ligne, en unités DAoC par seconde. Dans un vrai client,
## cette valeur devra venir du serveur selon la classe, les bonus et la monture.
@export_range(0.0, 5000.0, 1.0) var player_run_speed_raw: float = 450.0
## Vitesse de rotation au clavier, en degrés par seconde.
@export_range(0.0, 720.0, 1.0) var player_turn_rate_deg_per_sec: float = 180.0

@export_subgroup("Caméra")
## Rend la caméra du joueur active dès son montage. La caméra libre reste un
## outil du banc ZoneViewer et n'existe pas dans cette scène de jeu.
@export var player_camera_current: bool = true
## Cadrage « moderne » de P1-38, aligne sur la scene enregistree du banc : r7 compare
## ces quatre valeurs cle par cle. Unites DAoC brutes, sauf le champ de vision.
@export_range(25.0, 700.0, 5.0) var player_camera_distance_raw: float = 125.0
@export_range(-50.0, 25.0, 1.0) var player_camera_height_raw: float = 14.0
@export_range(100.0, 1700.0, 1.0) var player_camera_tilt_raw: float = 205.0
@export_range(35.0, 100.0, 1.0) var player_camera_fov_degrees: float = 60.0

@export_subgroup("Torche du joueur")
## La touche T retrouve sa fonction historique, avec une lumiere chaude moderne.
@export var player_torch_enabled: bool = true
@export var player_torch_on_at_start: bool = false
@export_range(0.0, 30.0, 0.1) var player_torch_energy: float = 12.0
@export_range(400.0, 5000.0, 50.0) var player_torch_range_raw: float = 2100.0
@export var player_torch_shadows: bool = true
## Flou des bords de l ombre de la torche (1 = dur, Godot). Une flamme est large.
@export_range(0.0, 6.0, 0.1) var player_torch_shadow_blur: float = 2.4
## Opacite de l ombre (1 = noir). Moins de 1 laisse vivre l ambiance nocturne.
@export_range(0.0, 1.0, 0.05) var player_torch_shadow_opacity: float = 0.85
## Lacet du faisceau dans le repere du joueur. -90 = devant (l avant du joueur
## est son +X local, un spot vise son -Z) ; 0 = a gauche, 90 = derriere.
@export_range(-180.0, 180.0, 1.0) var player_torch_beam_yaw_deg: float = -90.0:
	set(value):
		player_torch_beam_yaw_deg = value
		_push_torch_beam_orientation()
## Tangage du faisceau (negatif = vers le sol).
@export_range(-60.0, 30.0, 1.0) var player_torch_beam_pitch_deg: float = -9.0:
	set(value):
		player_torch_beam_pitch_deg = value
		_push_torch_beam_orientation()
## Eclaircissement du monde torche allumee (0.10 = +10 % de luminosite sur
## l Environment). 0 = la torche n eclaire que son faisceau.
@export_range(0.0, 1.0, 0.01) var player_torch_world_brightness_boost: float = 0.10:
	set(value):
		player_torch_world_brightness_boost = value
		if _player_torch != null and is_instance_valid(_player_torch):
			_player_torch.call("set_world_brightness_boost", value)

@export_group("Ciel, jour-nuit et météo")
@export_subgroup("Cycle horaire")
## Heure de départ hors ligne, de 0 à 24 heures. Midi offre l'éclairage le plus
## lisible et correspond aux captures de référence P1-20K.
@export_range(0.0, 24.0, 0.25) var environment_time_hours: float = 12.0
## Fait défiler automatiquement le cycle jour-nuit. Désactivé par défaut pour
## rendre les captures et les comparaisons visuelles reproductibles.
@export var environment_cycle_enabled: bool = false
## Durée d'une journée complète simulée, en minutes réelles.
@export_range(1.0, 240.0, 1.0) var environment_minutes_per_day: float = 30.0

@export_subgroup("Météo")
## Météo hors ligne : `CLEAR` (clair), `RAIN` (pluie) ou `SNOW` (neige). En jeu
## connecté, le front météo devra être fourni par le serveur.
@export_enum("CLEAR", "RAIN", "SNOW") var environment_weather: String = "CLEAR"
## Intensité du front météo, de 0 (aucun effet) à 1 (effet maximal).
@export_range(0.0, 1.0, 0.01) var environment_weather_intensity: float = 0.45
## Le sol s'imbibe puis seche progressivement ; ces valeurs sont des secondes.
@export_range(1.0, 120.0, 1.0) var ground_wet_soak_seconds: float = 14.0
@export_range(5.0, 300.0, 1.0) var ground_wet_dry_seconds: float = 90.0
@export_range(0.0, 1.0, 0.01) var ground_wet_roughness: float = 0.16
@export_range(0.0, 0.5, 0.01) var ground_wet_darkening: float = 0.14
## Écrit dans la console les changements d'heure, de profil et de météo.
@export var environment_log_state: bool = false

@export_subgroup("Éclairage et atmosphère")
## Active le halo lumineux autour du soleil et des zones très brillantes du
## ciel. Son coût est faible ; décocher restitue un disque solaire plus plat.
@export var sky_glow_enabled: bool = true
## Force du halo lumineux. Une valeur trop élevée lave les contrastes du décor.
@export_range(0.0, 2.0, 0.05) var sky_glow_intensity: float = 0.8
## Luminance minimale à partir de laquelle une zone de l'image produit un halo.
## Plus la valeur est basse, plus de surfaces se mettent à rayonner.
@export_range(0.0, 4.0, 0.05) var sky_glow_hdr_threshold: float = 2.0
## Calcule la lumière ambiante à partir du ciel rendu. Le monde suit ainsi les
## couleurs de l'aube, du jour, du crépuscule et de la météo.
@export var sky_ambient_from_sky_enabled: bool = true
## Part de la lumière ambiante provenant du ciel, de 0 à 1. Le complément vient
## de la couleur d'ambiance déclarée par la zone DAoC.
@export_range(0.0, 1.0, 0.05) var sky_ambient_sky_contribution: float = 0.9
## Intensite ambiante : 1 conserve le rendu historique, moins de 1 creuse les ombres.
@export_range(0.0, 2.0, 0.05) var sky_ambient_energy_scale: float = 1.0
@export_range(0.0, 4.0, 0.05) var ground_contact_ssao_intensity: float = 2.0
## Recalcule en continu la lumière et les réflexions provenant du ciel. À
## désactiver en premier sur une configuration faible.
@export var sky_realtime_radiance_enabled: bool = true
## Applique le brouillard de zone dans la profondeur pour mieux distinguer les
## reliefs lointains. Cet effet est distinct du brouillard volumétrique.
@export var sky_aerial_perspective_enabled: bool = true
## Intensité de la perspective aérienne. Une valeur trop forte efface les zones
## voisines dans la brume.
@export_range(0.0, 1.0, 0.05) var sky_aerial_perspective_amount: float = 0.2

@export_subgroup("Brouillard volumétrique et rayons solaires")
## Active le brouillard volumétrique natif de Godot, nécessaire aux rayons de
## soleil. C'est l'option d'éclairage la plus coûteuse pour le processeur graphique.
@export var sky_volumetric_fog_enabled: bool = true
## Densité du brouillard volumétrique. L'échelle est très sensible dans un monde
## exprimé en unités DAoC brutes : procéder par petits ajustements.
@export_range(0.0, 0.00016, 0.000005) var sky_volumetric_fog_density: float = 0.000085
## Portée du brouillard devant la caméra, en unités DAoC brutes. Une portée plus
## grande étire la grille de calcul et réduit sa précision.
@export_range(500.0, 20000.0, 250.0) var sky_volumetric_fog_length_raw: float = 3750.0
## Énergie injectée par le soleil dans le brouillard. À 0, le brouillard reste
## visible mais ne forme aucun rayon lumineux.
@export_range(0.0, 2.0, 0.05) var sky_sun_rays_energy: float = 2.0
@export_subgroup("Palette solaire esthétique")
## Teinte la lumiere rendue selon la hauteur horaire du soleil. Ne change ni
## l'heure, ni la meteo, ni les coordonnees et peut etre coupee instantanement.
@export var sky_sun_warm_palette_enabled: bool = false
@export_color_no_alpha var sky_sun_day_color: Color = Color(1.0, 0.965, 0.90)
@export_color_no_alpha var sky_sun_low_color: Color = Color(1.0, 0.68, 0.42)
@export_range(0.0, 1.0, 0.05) var sky_sun_warmth_strength: float = 0.65
@export_subgroup("Ombres et étalonnage")
@export_range(-40.0, 60.0, 1.0) var sky_sun_arc_extra_tilt_degrees: float = 20.0
@export_range(0.0, 3.0, 0.05) var sky_shadow_softness_degrees: float = 0.0
@export_range(500.0, 20000.0, 250.0) var sky_shadow_max_distance_raw: float = 6500.0
@export_range(0.5, 2.5, 0.05) var sky_sun_energy_scale: float = 1.16
@export var sky_tonemap_agx_enabled: bool = true
@export_range(0.5, 2.0, 0.05) var sky_tonemap_exposure: float = 1.02
@export_range(0.0, 2.0, 0.02) var sky_color_saturation: float = 1.13
@export_range(0.5, 2.0, 0.02) var sky_color_contrast: float = 1.07
@export_range(0.0, 1.0, 0.05) var sky_cloud_shading: float = 0.78
@export_range(0.0, 2.0, 0.05) var sky_cloud_silver_lining: float = 0.68
@export var sky_cloud_drift_enabled: bool = true

@export_subgroup("Lumieres DAoC d'origine")
## Points lumineux lus dans lights.csv. Ils completent le ciel dynamique ; les
## marqueurs de debug du viewer restent volontairement caches dans le jeu.
@export var build_legacy_lights: bool = true:
	set(value):
		build_legacy_lights = value
		_refresh_legacy_lights()
@export var legacy_lights_visible: bool = true:
	set(value):
		legacy_lights_visible = value
		_refresh_legacy_lights()
@export_range(0.0, 12.0, 0.1) var legacy_light_energy: float = 2.2:
	set(value):
		legacy_light_energy = value
		_refresh_legacy_lights()
@export_range(200.0, 10000.0, 100.0) var legacy_light_range: float = 3200.0:
	set(value):
		legacy_light_range = value
		_refresh_legacy_lights()
@export_range(0.01, 2.0, 0.01) var legacy_light_attenuation: float = 0.22:
	set(value):
		legacy_light_attenuation = value
		_refresh_legacy_lights()
@export_range(-500.0, 1000.0, 1.0) var legacy_light_vertical_offset: float = 24.0:
	set(value):
		legacy_light_vertical_offset = value
		_refresh_legacy_lights()
@export var use_legacy_light_type_colors: bool = true:
	set(value):
		use_legacy_light_type_colors = value
		_refresh_legacy_lights()
@export var legacy_lights_cast_shadows: bool = false:
	set(value):
		legacy_lights_cast_shadows = value
		_refresh_legacy_lights()
## P1-91. Lampes qui projettent EN MEME TEMPS, les plus proches de la camera :
## chacune coute six faces de cubemap par image. L ombre fond avec la distance.
@export_range(0, 12, 1) var legacy_light_shadow_budget: int = 4:
	set(value):
		legacy_light_shadow_budget = value
		_refresh_legacy_lights()
## Flou des bords (1 = dur). Feux et lanternes : large.
@export_range(0.0, 6.0, 0.1) var legacy_light_shadow_blur: float = 2.6:
	set(value):
		legacy_light_shadow_blur = value
		_refresh_legacy_lights()
## Opacite (1 = noir). Une lampe n eteint pas la nuit autour d elle.
@export_range(0.0, 1.0, 0.05) var legacy_light_shadow_opacity: float = 0.82:
	set(value):
		legacy_light_shadow_opacity = value
		_refresh_legacy_lights()
## Les types de feu vacillent (energie et ombre) ; les lueurs magiques non.
@export var legacy_lights_flicker: bool = true:
	set(value):
		legacy_lights_flicker = value
		_refresh_legacy_lights()
@export_range(0.0, 0.5, 0.01) var legacy_light_flicker_amount: float = 0.12:
	set(value):
		legacy_light_flicker_amount = value
		_refresh_legacy_lights()

@export_group("Végétation")

@export_subgroup("Couverture du sol")
## Active uniquement le rendu de l'herbe. Aucun relief, collision ou état réseau.
@export var grass_remaster_enabled: bool = true
## Espacement brut entre échantillons. Plus grand = moins dense et plus rapide.
@export_range(45.0, 220.0, 1.0) var grass_remaster_spacing_inspector_raw: float = 85.0
## Option graphique « Densite de l herbe » (fenetre d options, /options) : 0 Bas
## (tapis 3400, eclaircissement fort), 1 Moyen, 2 Eleve (tapis 6500). Memorisee.
@export_enum("Bas:0", "Moyen:1", "Eleve:2") var grass_detail_level: int = 2
## Multiplicateur esthétique de présence végétale.
@export_range(0.0, 2.0, 0.05) var grass_remaster_density_inspector: float = 0.85
@export_range(8.0, 120.0, 1.0) var grass_remaster_card_width_inspector_raw: float = 48.0
@export_range(8.0, 140.0, 1.0) var grass_remaster_card_height_inspector_raw: float = 44.0

@export_subgroup("Decors Outward")
## Petits rochers decoratifs dans les zones herbeuses, sans collision ajoutee.
@export var outward_rocks_enabled: bool = true:
	set(value):
		outward_rocks_enabled = value
		call_deferred("_apply_outward_decor_options")
## Fleurs en cartes légères, purement visuelles et sans collision.
@export var outward_flowers_enabled: bool = true:
	set(value):
		outward_flowers_enabled = value
		call_deferred("_apply_outward_decor_options")

@export_subgroup("Vent dans les feuillages")
## Anime les cartes de feuilles et les frondes SpeedTree avec le même vent que
## l'herbe. Les troncs restent rigides. Décocher restitue le rendu antérieur.
@export var foliage_wind_enabled: bool = true
## Amplitude de l'oscillation générale de la cime, en unités DAoC brutes.
## Valeur plausible mais pas encore calibrée visuellement.
@export_range(0.0, 200.0, 1.0) var foliage_canopy_strength_raw: float = 40.0
## Amplitude du frisson rapide des feuilles, en unités DAoC brutes. Valeur
## plausible mais pas encore calibrée visuellement.
@export_range(0.0, 100.0, 1.0) var foliage_leaf_flutter_strength_raw: float = 16.0
## Hauteur de référence utilisée pour graduer le mouvement entre la base et la
## cime. Exprimée en unités DAoC brutes et pas encore calibrée visuellement.
@export_range(100.0, 6000.0, 50.0) var foliage_wind_height_reference_raw: float = 1200.0
## P1-134 : trouees de lumiere dans l ombre des feuillages (taches de soleil qui
## derivent avec le vent). 0 = ombre pleine, comme avant.
@export_range(0.0, 0.8, 0.01) var foliage_sunfleck_amount: float = 0.32
## Taille d une trouee, en unites DAoC brutes.
@export_range(10.0, 300.0, 1.0) var foliage_sunfleck_cell_raw: float = 55.0

@export_group("Horizon et zones lointaines")
@export_subgroup("Relief lointain")
## Active la construction du terrain simplifié des zones non résidentes.
@export var distant_terrain_enabled: bool = true
## Pas d'échantillonnage du relief lointain. Une valeur élevée réduit le coût
## mais simplifie davantage la silhouette des montagnes.
@export_range(1, 32, 1) var distant_terrain_step: int = 4
## Nombre maximal de zones lointaines représentées autour des zones chargées.
@export_range(1, 64, 1) var distant_terrain_max_zones: int = 24
## Définition de l'atlas de couleurs du terrain lointain. 1024 px correspond à
## la scène ZoneViewer validée ; une taille moindre réduit mémoire et précision.
@export_enum("256 px:256", "512 px:512", "1024 px:1024") var distant_lod_colour_atlas_size: int = 1024
## Ajoute les falaises aux silhouettes des zones lointaines.
@export var distant_cliffs_enabled: bool = true
## Ajoute une nappe de brouillard aux frontières non maritimes. Ce rendu reste
## expérimental hors Isle of Glass et Avalon Isle.
@export var distant_non_maritime_border_fog_enabled: bool = true

@export_subgroup("Fond d'horizon")
## Ferme le panorama derrière les zones lointaines avec un relief de fond.
@export var distant_horizon_backdrop_enabled: bool = true
## Nombre de segments du fond sur chaque côté du panorama.
@export_range(8, 64, 1) var distant_horizon_segments_per_side: int = 28
## Distance du fond d'horizon, en unités DAoC brutes.
@export_range(8192.0, 131072.0, 1024.0) var distant_horizon_backdrop_distance_raw: float = 47186.0

@export_group("Matières du joueur")
@export_subgroup("Tenue")
## Choisit uniquement l'apparence locale. La capsule, les déplacements et
## l'autorité de jeu restent ceux du joueur déjà monté.
@export_enum("Avalonienne — plate actuelle:0", "Troll — maille:1", "Lurikeen — cuir:2") var player_appearance_choice: int = 0:
	set(value):
		player_appearance_choice = clampi(value, 0, 2)
		call_deferred("_refresh_player_appearance")

@export_subgroup("PBR")
## Bascule Vanilla <-> PBR sur les surfaces du joueur. Décochée, aucune carte
## n'est chargée et les matériaux restent EXACTEMENT ceux de la scène exportée.
## Cochée, les cartes générées hors ligne sont branchées par-dessus.
##
## Une surface sans cartes reste en vanilla sans casser les autres. La plate
## simple 04 du personnage de test est couverte 7/7 (28 cartes).
@export var player_pbr_enabled: bool = false:
	set(value):
		player_pbr_enabled = value
		_refresh_player_pbr()
## Relief du relief. 0 aplatit la carte normale, 1 est l'intensité générée.
@export_range(0.0, 4.0, 0.05) var player_pbr_normal_strength: float = 1.0:
	set(value):
		player_pbr_normal_strength = value
		_refresh_player_pbr()
## Multiplicateur de rugosité appliqué par-dessus la carte. Baisser rend les
## surfaces plus brillantes.
@export_range(0.0, 1.0, 0.05) var player_pbr_roughness_amount: float = 1.0:
	set(value):
		player_pbr_roughness_amount = value
		_refresh_player_pbr()
## Part de l'occlusion ambiante rendue à la lumière directe. **0 l'éteint** :
## c'est la plus approximative des quatre cartes, estimée depuis la couleur et
## non cuite depuis la géométrie.
@export_range(0.0, 1.0, 0.05) var player_pbr_ao_amount: float = 0.35:
	set(value):
		player_pbr_ao_amount = value
		_refresh_player_pbr()

@export_subgroup("Reflets de l'environnement")
## Active une sonde de réflexion dynamique centrée sur le joueur. Les parties
## métalliques reprennent alors doucement les couleurs du décor proche : herbe,
## ciel, bâtiments et lumières. Décocher retire immédiatement cet effet sans
## modifier les textures ni le PBR de l'armure.
@export var player_environment_reflections_enabled: bool = true:
	set(value):
		player_environment_reflections_enabled = value
		_refresh_player_reflections()
## Rayon du voisinage capturé, en unités DAoC. Plus grand mélange davantage le
## paysage lointain ; plus petit donne des reflets locaux mais plus changeants.
@export_range(200.0, 5000.0, 50.0) var player_reflection_range_raw: float = 1400.0:
	set(value):
		player_reflection_range_raw = value
		_refresh_player_reflections()
## Force du reflet capturé. 0 rend la sonde neutre, 1 conserve le rendu naturel
## de la carte métallique et de la rugosité ; au-delà, l'effet est accentué.
@export_range(0.0, 2.0, 0.05) var player_reflection_intensity: float = 0.75:
	set(value):
		player_reflection_intensity = value
		_refresh_player_reflections()
## Hauteur du point de capture au-dessus des pieds. Le réglage livré vise le
## centre du personnage afin de voir à la fois le sol et le ciel.
@export_range(-200.0, 1000.0, 10.0) var player_reflection_height_raw: float = 70.0:
	set(value):
		player_reflection_height_raw = value
		_refresh_player_reflections()

@export_group("Matières du sol")
## Sol PBR : le shader de terrain lit, en plus de l'albédo, les cartes de
## normale, de rugosité et d'occlusion générées à côté de chaque texture de
## `zones/TerrainTex`. Décoché, le fragment est octet pour octet celui d'avant
## l'option — et c'est le réglage à couper sur un GPU modeste : trois tableaux
## de textures de plus par zone résidente. Réglable en cours de partie : les
## sols déjà bâtis sont mis à jour sans reconstruire la zone. Même traducteur
## que `ZoneViewer.terrain_pbr_quality_options` ; la taille des cartes reste
## celle du preset livré (1024 px), pas un réglage de jeu.
@export var terrain_pbr_enabled: bool = false:
	set(value):
		terrain_pbr_enabled = value
		_refresh_terrain_pbr()
## Profondeur de la carte de normale du sol. 1.0 = telle que générée.
@export_range(0.0, 4.0, 0.05) var terrain_pbr_normal_strength: float = 1.0:
	set(value):
		terrain_pbr_normal_strength = value
		_refresh_terrain_pbr()
## Part de l'occlusion ambiante du sol. 0 l'éteint sans décocher le PBR.
@export_range(0.0, 1.0, 0.05) var terrain_pbr_ao_amount: float = 1.0:
	set(value):
		terrain_pbr_ao_amount = value
		_refresh_terrain_pbr()
## P1-118 — relief virtuel (parallax par la carte AO du sol) : les pavés et
## cailloux semblent dépasser. Purement visuel, aucun sommet ni collision.
@export var terrain_virtual_relief_enabled: bool = false:
	set(value):
		terrain_virtual_relief_enabled = value
		_refresh_terrain_pbr()
@export_range(0.0, 0.08, 0.001) var terrain_virtual_relief_depth: float = 0.018:
	set(value):
		terrain_virtual_relief_depth = value
		_refresh_terrain_pbr()
@export_range(2, 12, 1) var terrain_virtual_relief_steps: int = 6:
	set(value):
		terrain_virtual_relief_steps = value
		_refresh_terrain_pbr()
## P1-118 — plancher de rugosité du sol sec (0 = cartes telles quelles).
@export_range(0.0, 1.0, 0.01) var terrain_dry_roughness_floor: float = 0.0:
	set(value):
		terrain_dry_roughness_floor = value
		_refresh_terrain_pbr()
## Part de l.AO du sol appliquée aussi au soleil direct (0 = ambiante seule).
@export_range(0.0, 1.0, 0.01) var terrain_ao_light_affect: float = 0.0:
	set(value):
		terrain_ao_light_affect = value
		_refresh_terrain_pbr()
## Réflexion spéculaire du sol sec (0,5 = valeur Godot par défaut).
@export_range(0.0, 1.0, 0.01) var terrain_dry_specular: float = 0.5:
	set(value):
		terrain_dry_specular = value
		_refresh_terrain_pbr()
@export_subgroup("Variation esthétique — sans relief")
## Variation procedurale de couleur/rugosite seulement : aucune heightmap,
## aucun sommet, aucune collision et aucune coordonnee reseau ne sont modifies.
@export var terrain_macro_variation_enabled: bool = false:
	set(value):
		terrain_macro_variation_enabled = value
		_refresh_terrain_pbr()
@export_range(4.0, 512.0, 1.0) var terrain_macro_variation_scale: float = 96.0:
	set(value):
		terrain_macro_variation_scale = value
		_refresh_terrain_pbr()
@export_range(0.0, 0.35, 0.01) var terrain_macro_color_strength: float = 0.08:
	set(value):
		terrain_macro_color_strength = value
		_refresh_terrain_pbr()
@export_range(0.0, 0.5, 0.01) var terrain_macro_roughness_strength: float = 0.12:
	set(value):
		terrain_macro_roughness_strength = value
		_refresh_terrain_pbr()
@export_range(0.0, 4096.0, 1.0) var terrain_macro_seed: float = 173.0:
	set(value):
		terrain_macro_seed = value
		_refresh_terrain_pbr()
var terrain_pbr_map_size: int = int(DaocTerrainPbrUpgrade.QUALITY_DEFAULTS["map_size"])

@export_subgroup("Lissage visuel bilinéaire")
## Ajoute uniquement des sommets d'affichage entre les points de la heightmap.
## Le runtime d'altitude et les collisions restent ceux du terrain historique :
## ce réglage ne change donc aucune coordonnée Z connue du serveur.
@export var terrain_bilinear_enabled: bool = false:
	set(value):
		terrain_bilinear_enabled = value
		_schedule_terrain_bilinear_refresh()
## ×2 est le compromis recommandé. ×4 et surtout ×8 augmentent rapidement le
## nombre de triangles ; ils sont fournis pour comparaison et peuvent être
## ramenés à ×2 ou désactivés immédiatement depuis l'inspecteur distant.
@export_enum("×2 (recommandé):2", "×4:4", "×8:8") var terrain_bilinear_factor: int = 2:
	set(value):
		terrain_bilinear_factor = value if value == 2 or value == 4 or value == 8 else 2
		_schedule_terrain_bilinear_refresh()
var _terrain_bilinear_refresh_pending: bool = false

@export_group("Eau — rendu uniquement")
## Ces options sont lues a la construction visuelle de la zone. Elles ne
## changent jamais les polygones d'eau utilises par DaocWaterRuntime.
@export var water_visual_enabled: bool = true
## Texture de vague moderne livree avec le projet. Decoche : texture watery.png
## historique du client, sans changer le shader ni les limites d'eau.
@export var water_modern_texture_enabled: bool = true
@export_range(0.05, 1.0, 0.01) var water_alpha: float = 0.62
@export_range(0.00001, 0.01, 0.00001) var water_uv_world_scale: float = 0.00055
@export var water_shore_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var water_shore_strength: float = 0.85
@export_range(0.0, 4.0, 0.05) var water_wave_strength_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var water_refraction_scale: float = 1.0
@export_range(0.0, 2.0, 0.05) var water_depth_colour_scale: float = 1.0

@export_group("Matières du monde")
## Active le PBR des objets NIF, bâtiments et PNJ déjà chargés ainsi que ceux à
## venir. Les interfaces, collisions invisibles, particules et shaders spécialisés
## sont exclus. La bascule est immédiate pendant que la scène tourne.
@export var world_pbr_enabled: bool = true:
	set(value):
		world_pbr_enabled = value
		_refresh_world_pbr()
## Résolution maximale des cartes générées à la volée pour chaque texture monde.
## Le plus grand côté est plafonné, proportions gardées, cartes compressées GPU (P1-118).
## 256 px aplatit les normales photo ; 1024 px garde le relief des sols et murs.
@export_enum("128 px:128", "256 px:256", "512 px:512", "1024 px:1024") var world_pbr_map_size: int = 256:
	set(value):
		world_pbr_map_size = value
		_refresh_world_pbr()
## Intensité du relief apparent des objets et bâtiments. 0 aplatit les normales.
@export_range(0.0, 4.0, 0.05) var world_pbr_normal_strength: float = 1.0:
	set(value):
		world_pbr_normal_strength = value
		_refresh_world_pbr()
## Multiplicateur de rugosité du monde. Plus bas rend les surfaces plus brillantes.
@export_range(0.0, 1.0, 0.05) var world_pbr_roughness_amount: float = 0.85:
	set(value):
		world_pbr_roughness_amount = value
		_refresh_world_pbr()
## Force de l'occlusion ambiante des objets. 0 la désactive sans couper le PBR.
@export_range(0.0, 1.0, 0.05) var world_pbr_ao_amount: float = 0.45:
	set(value):
		world_pbr_ao_amount = value
		_refresh_world_pbr()

@export_group("")

## Les réglages des sept étapes de zone, en DONNÉES.
##
## Le banc les tire de ses 318 `@export` ; le jeu les tire d'ici. C'est
## exactement le contrat que R4 a créé : une étape ne lit jamais un `@export`,
## elle reçoit un dictionnaire. Sans ce contrat, cette scène aurait dû
## redéclarer l'inspecteur du viewer pour bâtir une seule zone.
##
## LES VALEURS SONT CELLES DU BANC, relevées une à une dans `ZoneViewer.gd` et
## verrouillées par la suite R6 : une signature d'index qui diverge trahit un
## réglage recopié de travers, et c'est arrivé pendant l'écriture de ce jalon —
## `zonejump_thickness_raw` à 64 au lieu de 60 suffisait à changer la signature
## des huit aires de transition de la zone 51.
##
## Les lumieres `lights.csv`, autrefois coupees au profit du seul environnement
## dynamique P1-20K, sont de nouveau pilotables dans l'inspecteur du jeu. Leurs
## marqueurs de debug restent caches. Les traces `log_*` sont coupees : un client
## n'ecrit pas une ligne par zone
##     bâtie sur la sortie standard. La trace du terrain, elle, reste
##     inconditionnelle — c'est la seule qui dise qu'un sol existe.
##
## UN TROISIÈME ÉCART A ÉTÉ CORRIGÉ À R10, et il n'était pas assumé mais FAUX.
## `build_vegetation` et `speedtree_enabled` étaient coupés ici au motif qu'ils
## l'étaient « dans la scène enregistrée du banc ». Mesuré : cette scène ne
## surcharge PAS `build_vegetation`, donc le banc prend le défaut du script —
## `true` — et elle porte `vegetation_render_mode = 1` et
## `speedtree_enabled = true`. Le jeu était le seul des deux mondes sans herbe
## et sans arbres SpeedTree, et c'est ce que l'utilisateur a vu à l'écran.
##
## La leçon est celle de R7, re-payée : LA RÉFÉRENCE EST LA SCÈNE ENREGISTRÉE,
## PAS LE SCRIPT — ni un commentaire écrit de mémoire.
const DEFAULT_SETTINGS := {
	"water": {
		"build_water": true,
		"water_alpha": 0.62,
		"water_vertical_offset": 8.0,
		"water_tessellation_cap": 12,
		"water_uv_world_scale": 0.00055,
		"use_legacy_water_color": false,
		"water_shore_enabled": true,
		"water_shore_strength": 0.85,
		"log_water": false,
	},
	"terrain": {
		"build_terrain_collision": true,
		"terrain_collision_layer": 1,
		"terrain_collision_mask": 0,
		"tile_scale": 1.0,
		"terrain_anisotropic_filtering": true,
	},
	"collisions": {
		"build_bound_collision": true,
		"bound_collision_blocks_player": true,
		"bound_collision_layer": 1,
		"bound_collision_mask": 0,
		"bound_collision_thickness_raw": 90.0,
		"bound_collision_bottom_offset_raw": -1000.0,
		"bound_collision_top_offset_raw": 3000.0,
		"bound_collision_debug_visible": false,
		"log_collision": false,
	},
	"zonejumps": {
		"build_zonejump_debug": true,
		"zonejump_thickness_raw": 60.0,
		"zonejump_debug_visible": false,
		"zonejump_area_enabled": true,
		"zonejump_optional_dedupe_pairs": false,
		"log_zonejump": false,
	},
	"props": {
		"place_real_models": true,
		"mark_missing": true,
		"anchor_to_base": true,
		"heading_sign": -1.0,
		"heading_offset_deg": 0.0,
		"generate_prop_collisions": true,
		"prop_collision_log_decisions": false,
		"export_missing_models_csv": false,
		"brghouse_floor_anchor_offset_raw": -128.0,
		# R10 — le banc a `speedtree_enabled = true` dans sa SCÈNE ENREGISTRÉE,
		# pas dans son script. Cette valeur était donc à `false` ici, et le
		# commentaire du jalon affirmait à tort que les deux scènes étaient
		# d'accord. Les 71 substitutions Treemap manquaient au jeu.
		"speedtree_enabled": true,
		"speedtree_units_to_daoc": 12.0,
		"speedtree_visible_distance_raw": 30000.0,
		"prop_collision_layer": 4,
		"prop_collision_mask": 0,
		"prop_collision_debug_visible": false,
		"prop_collision_size_scale_xz": 0.72,
		"prop_collision_size_scale_y": 0.90,
		"prop_collision_fallback_when_flag_missing": true,
	},
	"lights": {
		"build_legacy_lights": false,
		"legacy_lights_visible": false,
	},
	# R10 — la végétation était COUPÉE ici, et le jalon le déclarait « comme dans
	# la scène enregistrée du banc ». C'était FAUX, et mesuré depuis :
	# `ZoneViewer.tscn` ne surcharge pas `build_vegetation`, donc le banc prend
	# le défaut du script, `true`, et il porte `vegetation_render_mode = 1` —
	# Grass Remaster. Le jeu était donc le seul monde sans herbe.
	#
	# L'oracle de R6 ne pouvait pas l'attraper : il compare CINQ signatures
	# d'index — terrain, eau, frontières, zonejumps, props — et la végétation
	# n'en écrit aucune. Le trou était dans l'oracle autant que dans la valeur.
	"vegetation": {
		"build_vegetation": true,
		"vegetation_render_mode": 1,
		"log_vegetation": false,
		# Les quinze réglages du Remaster. Ils étaient lus sur l'hôte PAR LEUR
		# NOM : sur cette scène, `float(null)` valait 0.0 et le Remaster aurait
		# bâti un espacement nul et un plafond d'instances nul — zéro brin, en
		# silence, avec un nœud parfaitement présent. Valeurs du banc.
		# La carte ALT de certaines zones, dont la 027, est vide autour du point
		# de départ. En mode strict elle annulait aussi la classification des
		# textures végétales : nœud présent, mais 0 chunk / 0 brin. DaocGame part
		# donc de la grassmap d'origine et complète par les matières du terrain.
		"grass_remaster_prefer_alternative_map": false,
		"grass_remaster_alternative_map_name": "grassmapALT.pcx",
		"grass_remaster_use_densemap": false,
		"grass_remaster_chunk_size_raw": 4096.0,
		"grass_remaster_spacing_raw": 60.0,
		"grass_remaster_fade_start_raw": 8500.0,
		"grass_remaster_fade_end_raw": 12000.0,
		"grass_remaster_density": 1.40,
		"grass_remaster_coverage_threshold": 0.10,
		"grass_remaster_max_instances_per_chunk": 5000,
		"grass_remaster_card_width_raw": 64.0,
		"grass_remaster_card_height_raw": 70.0,
		"grass_remaster_wind_strength": 30.0,
		"grass_remaster_wind_speed": 1.35,
		"grass_remaster_wind_gust_strength": 0.72,
		"grass_remaster_native_seed_enabled": true,
		"grass_remaster_native_tree_radius_raw": 1450.0,
		"grass_remaster_native_plant_radius_raw": 900.0,
	},
}

## Les feuillages exclus de la collision de props, relevés dans le banc.
##
## Ils vivent hors de `DEFAULT_SETTINGS` pour une raison de langage et non de
## conception : `PackedStringArray()` n'est pas une expression constante en
## GDScript, donc une constante de dictionnaire ne peut pas en contenir.
##
## Sans ces deux listes, un joueur se cognerait à chaque arbre — 482 fixtures de
## la seule zone 51 sont écartées par elles.
const PROP_COLLISION_EXCLUDED_TOKENS := ([
	"tree", "speedtree", "grass", "bush", "shrub", "plant", "flower",
	"fern", "weed", "leaf", "leaves", "foliage", "ivy", "moss",
	"oak", "pine", "birch", "elm", "beech", "chestnut", "maple",
	"grove", "sapling", "branch", "pintre", "pinetree", "birchtree",
	"oaktree", "deadtree", "vrgrn", "whitepine", "reed", "rush",
])
const PROP_COLLISION_EXCLUDED_NAMES := ([
	"b_htoak1", "b_htoakb", "bmtntre1", "beech", "bpinea", "bpinetree",
	"bpintre1", "chestnut", "elm1", "elm2", "hbareskny", "hbirchsingle",
	"hbirchtree", "hdeadtree", "helm", "helm1grey", "helm2", "helm2tan",
	"holdgrove", "hoaktree", "maple", "mightyoak", "mightyoak-small",
	"nbirchtree", "npinea", "npinea-s", "npinedk", "npinetree",
	"npinetree-s", "npintre-s", "npintre1", "nvrgrn1-s", "pintre1",
	"tall_whitepine", "tall_whitepine2", "tall_whitepine2_snow",
	"tall_whitepine3", "vrgrn1",
])

## Le socle R0 : le propriétaire des systèmes persistants. Il est créé AVANT
## toute construction, comme dans le banc — une zone doit pouvoir naître dans une
## session qui existe déjà.
var session: DaocGameSession = null

var _state: DaocZoneViewerStateRegistry = null
var _registry: RefCounted = null
var _assembler: DaocZoneSceneAssembler = null
var _services: DaocZoneBuildServices = null
var _visuals: RefCounted = null
var _transition: DaocZoneTransition = null

## Origines monde des zones, lues dans `zones_placement.json`, et le repère
## commun. `_base` est FIGÉ à la première zone : le recalculer en cours de partie
## déplacerait tout ce qui est déjà bâti.
var _placement: Dictionary = {}
var _base: Vector2 = Vector2.ZERO
var _base_frozen: bool = false

## La zone habitée. Le banc l'appelle `player_zone` ; ici c'est la seule notion
## de position que la scène statique a besoin de porter.
var current_zone: int = -1

## Ligne d'état, conservée pour que le service `hud_append` ait une destination.
## Le jeu ne l'affiche pas : c'est au HUD de la lire s'il en veut.
var _hud_zones: String = ""


## R10-HF1 — répare la lettre de lecteur AVANT que quoi que ce soit ne soit bâti.
##
## `daoc_client_root` est transmis tel quel à plusieurs constructeurs, qui ne
## passent pas tous par le registre 15D : le réparer ici, une fois, évite d'avoir
## à le faire à chaque point de passage. Un chemin configuré qui existe n'est
## jamais touché — corriger à la main reste possible et prioritaire.
func resolve_client_root_r10() -> Dictionary:
	var resolution: Dictionary = DaocClientRootScript.resolve(daoc_client_root)
	if bool(resolution.get("ok", false)):
		daoc_client_root = str(resolution["root"])
		if bool(resolution.get("healed", false)):
			print("DAOC_CLIENT_ROOT repare : %s (source=%s)" % [
				daoc_client_root, str(resolution.get("source", "?"))])
	else:
		# On ne vide PAS le chemin : l'erreur en aval doit nommer ce qui a ete
		# cherche. Une racine vide produirait des zones sans texture et des
		# listes vides, sans jamais dire pourquoi - exactement la panne muette
		# que ce correctif existe pour supprimer.
		push_warning("DAOC_CLIENT_ROOT introuvable, essais : %s"
			% str(resolution.get("tried", [])))
	return resolution


func _ready() -> void:
	_apply_visual_roadmap_profile()
	# P1-129 : toute fenetre de l interface se deplace (retour utilisateur).
	if not get_tree().node_added.is_connected(_on_tree_node_added_for_drag):
		get_tree().node_added.connect(_on_tree_node_added_for_drag)
	# 2026-09-27 : la densite de l herbe choisie dans les options (memorisee).
	grass_detail_level = DaocGraphicsOptionsWindow.load_grass_detail_level(grass_detail_level)
	_apply_saved_player_options()
	resolve_client_root_r10()
	_mount_session()
	if build_on_ready:
		_start_game_runtime()
	else:
		var frontend_script := load("res://src/daoc/ui/pregame/DaocGameFrontend.gd")
		if frontend_script != null:
			var frontend := frontend_script.new() as CanvasLayer
			frontend.name = "Frontend"
			add_child(frontend)


func _apply_saved_player_options() -> void:
	daoc_ui_scale = float(DaocGraphicsOptionsWindow.load_option("interface", "scale", daoc_ui_scale))
	if not bool(DaocGraphicsOptionsWindow.load_option("vanilla_plus", "butterflies", true)):
		ambient_butterfly_count = 0
	if not bool(DaocGraphicsOptionsWindow.load_option("vanilla_plus", "falling_leaves", true)):
		ambient_leaf_count = 0
	var fullscreen := bool(DaocGraphicsOptionsWindow.load_option("display", "fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var vsync := bool(DaocGraphicsOptionsWindow.load_option("display", "vsync", true))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _apply_visual_roadmap_profile() -> Dictionary:
	if not visual_roadmap_enabled:
		return {"enabled": false, "applied": {}}
	var applied: Dictionary = DaocVisualRoadmapProfileScript.apply_to(self, visual_roadmap_quality)
	return {"enabled": true, "quality": visual_roadmap_quality, "applied": applied}


## 2026-09-15 — le choix de l'ecran de selection pilote enfin le monde.
##
## Hors ligne : le personnage clique (Riri / Fifi / Loulou) decide de la scene
## du joueur via `DaocPlayableRoster`, la ou l'inspecteur seul decidait avant.
##
## En ligne : la position autoritaire recue en 0x88 (`online_position`) decide
## de la zone et du point de depart, le peuplement vient du flux serveur et
## l'arbitre local passe en MIROIR. Avant ce jour, le mode Online lancait le
## monde hors ligne complet a cote d'une session PLAYING qui ne pilotait rien.
func start_game_from_pregame(mode: String, realm_id: int, _slot_index: int, character_data: Dictionary) -> Dictionary:
	if current_zone >= 0:
		return {"ok": true, "already_started": true, "mode": mode}
	online_mode = mode.to_upper() == "ONLINE"
	if _fast_start_active():
		# Ces options multiplient textures, materiaux et sommets avant meme que le
		# joueur puisse reagir au serveur. Elles restent disponibles hors ligne.
		terrain_pbr_enabled = false
		terrain_bilinear_enabled = false
		world_pbr_enabled = false
	_online_character = character_data.duplicate(true)
	player_appearance_choice = DaocPlayableRosterScript.appearance_choice_for(character_data)
	_chosen_visual_scene = DaocPlayableRosterScript.preview_scene_for(character_data)
	var start_report: Dictionary = {"zone_source": "inspector", "zone": start_zone}
	if online_mode:
		start_report = _apply_online_start_position(character_data.get("online_position", {}) as Dictionary)
	elif bool(character_data.get("valid", false)) and int(character_data.get("region_id", 0)) == DaocPlayableRosterScript.OFFLINE_REGION_ID:
		# Le roster hors ligne vit a Gothwaite : la fixture canonique, pas
		# `start_zone` de l'inspecteur (P1-39 l'avait laisse a 0).
		start_zone = 51
		start_report = {"zone_source": "offline_roster", "zone": 51}
	_start_game_runtime()
	_online_start_report = start_report
	return {"ok": current_zone >= 0, "mode": mode, "realm_id": realm_id,
		"character": str(character_data.get("name", "")),
		"appearance_choice": player_appearance_choice, "start": start_report,
		"online": online_mode}


func _fast_start_active() -> bool:
	return online_fast_start if online_mode else offline_fast_start


## B1 — la zone et le point de depart viennent du 0x88 du serveur, pas du nom du
## personnage. Le paquet porte des coordonnees MONDE et la region ; la zone est
## celle dont l'emprise contient le point (`zones_placement.json`).
func _apply_online_start_position(position: Dictionary) -> Dictionary:
	if position.is_empty() or not position.has("x") or not position.has("y"):
		return {"zone_source": "inspector_fallback", "zone": start_zone,
			"reason": "aucune position serveur recue avant PLAYING"}
	var region := int(position.get("region_id", 0))
	var world_x := float(position.get("x", 0.0))
	var world_y := float(position.get("y", 0.0))
	var zone := resolve_zone_for_world_point(region, world_x, world_y)
	if zone < 0:
		return {"zone_source": "inspector_fallback", "zone": start_zone,
			"reason": "aucune zone de la region %d ne couvre (%d, %d)" % [region, int(world_x), int(world_y)],
			"region_id": region}
	var origin := _origin(zone)
	start_zone = zone
	player_start_x = world_x - origin.x
	player_start_y = world_y - origin.y
	# P1-112 : cap DOL (0 = +Y) -> moteur (0 = +X), +90 degres, mesure en live
	# par le GM (reconnexion tournee de 90 degres). Voir DaocHeading.
	player_start_heading_deg = DaocHeadingScript.raw_to_motor_deg(int(position.get("heading", 0)))
	return {"zone_source": "server_0x88", "zone": zone, "region_id": region,
		"world": [world_x, world_y, float(position.get("z", 0.0))],
		"zone_local": [player_start_x, player_start_y],
		"heading_deg": player_start_heading_deg, "heading_convention": "DOL_POINT2D_MEASURED_LIVE_P1_112"}


## La zone dont l'emprise contient un point MONDE de la region, ou -1.
func resolve_zone_for_world_point(region: int, world_x: float, world_y: float) -> int:
	var transition := _ensure_transition()
	if transition == null or not transition.known():
		return -1
	var candidates: Array = transition.zones_of_region(region) if region > 0 else []
	if candidates.is_empty():
		_ensure_placement()
		candidates = _placement.keys()
	for value in candidates:
		var zone := int(value)
		var rect: Rect2 = transition.footprint(zone)
		if rect.size == Vector2.ZERO:
			continue
		if rect.has_point(Vector2(world_x, world_y)):
			return zone
	return -1


func _start_game_runtime() -> void:
	_report_startup_progress("Construction du terrain et des bâtiments…", 45.0)
	enter_start_zone()
	_report_startup_progress("Zone locale construite", 62.0)
	# R7 — le joueur APRES la zone, jamais avant : `_resolve_player_start`
	# échantillonne le relief, et sans sol il tomberait à l'altitude zéro.
	if mount_player_on_ready:
		mount_player_r7()
		# R10 — le modèle APRÈS la capsule : il s'y accroche.
		if mount_player_visual_on_ready:
			mount_player_visual_r10()
		if player_torch_enabled:
			mount_player_torch_p1_37()
	_report_startup_progress("Personnage prêt", 70.0)
	# R8 — le ciel APRES la zone : le profil est celui de la zone habitee.
	if mount_environment_on_ready:
		mount_environment_r8()
	if mount_ambient_wildlife_on_ready:
		mount_ambient_wildlife()
	_report_startup_progress("Décor et environnement prêts", 78.0)
	# La sonde suit le joueur et capture le décor une fois le ciel monté.
	mount_player_reflections_p1_37()
	# R9 — le peuplement EN DERNIER : chaque entite est reposee sur le relief,
	# et il lui faut donc la zone. Le raffinement par collision, lui, se differe
	# tout seul a la premiere trame physique.
	if mount_population_on_ready:
		if online_mode:
			mount_online_population()
		else:
			mount_population_r9()
	_report_startup_progress("Population locale prête", 88.0)
	if mount_gameplay_ui_on_ready:
		mount_gameplay_ui_r11()
		if online_mode:
			_bind_online_stream_to_authority()
	_report_startup_progress("Interface de jeu prête", 94.0)
	# R10 — l'horizon APRÈS tout le reste : il dessine les zones qui ne sont
	# PAS résidentes, donc il lui faut connaître celles qui le sont. Il se
	# rebâtit ensuite tout seul à chaque frontière franchie.
	if mount_horizon_on_ready and not _fast_start_active():
		mount_horizon_r10()
	_report_startup_progress("Finalisation du monde…", 98.0)


func _report_startup_progress(text: String, value: float) -> void:
	startup_progress.emit(text, value)
	# Le montage reste synchrone, mais force l'affichage du nouveau palier afin
	# que Windows ne donne plus l'impression d'un arrêt à 45 %.
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)


## Monte la session R0 et son streamer R1. Rien n'est bâti ici : la session doit
## exister avant la première zone, pas l'inverse.
func _mount_session() -> void:
	if session != null:
		return
	_state = DaocZoneViewerStateRegistry.new()
	session = DaocGameSession.new()
	session.name = "GameSession"
	add_child(session)
	var streamer := DaocZoneStreamer.new()
	streamer.name = "ZoneStreamer"
	session.zone_streamer = streamer
	session.add_child(streamer)


## Ouvre la partie sur `start_zone`.
func enter_start_zone() -> Dictionary:
	return enter_zone(start_zone)


## Bâtit une zone et la déclare habitée. C'est le geste que R5 rejoue à chaque
## frontière franchie.
func enter_zone(znum: int) -> Dictionary:
	_ensure_placement()
	if not _base_frozen:
		_base = _origin(znum)
		_base_frozen = true
	build_zone(znum)
	current_zone = znum
	_ensure_transition().note_entered(znum)
	_evict_beyond_budget()
	return {
		"ok": _state.zone_runtime.has(znum),
		"zone": znum,
		"resident": zone_streamer().loaded_zones(),
	}


## Franchir une frontière. Même contrat que le banc : rend `{ok:false}` quand
## aucune voisine ne couvre le point, et le rabotage reste alors la bonne
## réponse — la région est un archipel en escalier.
func cross_zone_border_r5(from_zone: int, daoc_x: float, daoc_y: float) -> Dictionary:
	var transition := _ensure_transition()
	var crossing: Dictionary = transition.resolve_border_crossing(from_zone, daoc_x, daoc_y)
	if not bool(crossing.get("ok", false)):
		return crossing
	var target := int(crossing["zone"])
	var built := not zone_streamer().has_zone(target)
	if built:
		build_zone(target)
	# Même verrou qu'au banc : sans repère, le passage poserait le joueur à
	# l'origine de la session et non dans la voisine.
	if not _state.zone_runtime.has(target):
		return {"ok": false, "reason": "zone %d sans repere, passage refuse" % target}
	transition.note_entered(from_zone)
	transition.note_entered(target)
	current_zone = target
	var report := crossing.duplicate(true)
	report["built"] = built
	report["evicted"] = _evict_beyond_budget()
	# P1-33G — le plan est PÉRIMÉ dès que la zone active change : la zone qu'on
	# vient de quitter devient lointaine, et c'est celle qu'on regarde en se
	# retournant. Replanifier ici évite de bâtir l'horizon deux fois.
	if zone_prefetch_enabled or distant_near_border_lod_enabled:
		var crossed_plan := plan_zone_lod_p1_33(target, float(crossing.get("x", 0.0)),
			float(crossing.get("y", 0.0)), 0.0, zone_streamer().loaded_zones())
		if bool(crossed_plan.get("ok", false)):
			_zone_lod_plan = crossed_plan
			_horizon_dirty = true
	refresh_distant_terrain_if_stale_r10()
	report["resident"] = zone_streamer().loaded_zones()
	return report


func _evict_beyond_budget() -> Array:
	var streamer := zone_streamer()
	var evicted: Array = []
	for zone_id in _ensure_transition().plan_eviction(
			streamer.loaded_zones(), max_resident_zones, current_zone):
		if _zones_building_spread.has(int(zone_id)):
			continue
		if streamer.unload(int(zone_id)):
			DaocZoneUnload.forget_zone(_state, int(zone_id))
			evicted.append(int(zone_id))
	return evicted


## Bâtit une zone par l'assembleur P1-15B. Le jeu n'a pas son propre ordre de
## construction : c'est le même, validé depuis P1-15B et migré en objets par R4.
func build_zone(znum: int) -> Dictionary:
	if _assembler == null:
		_assembler = DaocZoneSceneAssembler.new()
	var result: Dictionary = _assembler.build_zone(self, znum)
	_state.zone_scene_assembler_results[znum] = result
	_apply_ground_wetness(_ground_wetness)
	_reapply_door_states()
	return result


## 2026-09-27 (optimisation) — la même construction étalée sur plusieurs images,
## pour le PRÉCHARGEMENT (le joueur marche encore dans sa zone). Une seule à la
## fois ; une zone en cours n est jamais évincée.
var _zones_building_spread: Dictionary = {}


func build_zone_spread(znum: int) -> void:
	if _zones_building_spread.has(znum):
		return
	if _assembler == null:
		_assembler = DaocZoneSceneAssembler.new()
	_zones_building_spread[znum] = Time.get_ticks_msec()
	var started := Time.get_ticks_msec()
	var result: Dictionary = await _assembler.build_zone_spread(self, znum)
	_zones_building_spread.erase(znum)
	_state.zone_scene_assembler_results[znum] = result
	_apply_ground_wetness(_ground_wetness)
	_reapply_door_states()
	print("ZONE_PREFETCH_SPREAD={\"zone\":%d,\"ms_wall\":%d}" % [znum, Time.get_ticks_msec() - started])


# ============================================================================
# Le contrat d'hôte de zone. Ce sont les mêmes méthodes que le banc expose ;
# elles ne portent aucune règle, seulement de quoi bâtir.
# ============================================================================

## R4 — les services, fournis UNE FOIS.
func zone_build_services_r4() -> DaocZoneBuildServices:
	if _services == null:
		_services = DaocZoneBuildServices.create(self, _state)
	return _services


## Toutes les étapes sont migrées depuis R4 : le jeu n'a pas d'ancien chemin à
## proposer, et c'est précisément ce qui le rend écrivable.
func zone_step_migrated_r4(_step_name: String) -> bool:
	return true


func zone_step_settings_r4(step_name: String) -> Dictionary:
	var settings: Dictionary = (DEFAULT_SETTINGS.get(step_name, {}) as Dictionary).duplicate(true)
	# `PackedStringArray()` n'est pas une expression constante en GDScript : les
	# deux listes d'exclusion de collision de props sont donc posees ici, et non
	# dans DEFAULT_SETTINGS. Vides, comme dans la scene enregistree du banc.
	if step_name == "props":
		settings["prop_collision_excluded_name_tokens"] = PackedStringArray(PROP_COLLISION_EXCLUDED_TOKENS)
		settings["prop_collision_excluded_exact_names"] = PackedStringArray(PROP_COLLISION_EXCLUDED_NAMES)
		# R10-HF2 — le vent atteint les arbres SpeedTree par ce chemin :
		# DaocPropBuilder transmet les reglages de props a DaocSpeedTreeBatches.
		settings["foliage_wind_enabled"] = foliage_wind_enabled
		settings["foliage_canopy_strength_raw"] = foliage_canopy_strength_raw
		settings["foliage_leaf_flutter_strength_raw"] = foliage_leaf_flutter_strength_raw
		settings["foliage_wind_height_reference_raw"] = foliage_wind_height_reference_raw
		settings["foliage_sunfleck_amount"] = foliage_sunfleck_amount
		settings["foliage_sunfleck_cell_raw"] = foliage_sunfleck_cell_raw
		settings["world_pbr_enabled"] = world_pbr_enabled
		settings["world_pbr_map_size"] = world_pbr_map_size
		settings["world_pbr_normal_strength"] = world_pbr_normal_strength
		settings["world_pbr_roughness_amount"] = world_pbr_roughness_amount
		settings["world_pbr_ao_amount"] = world_pbr_ao_amount
	if step_name == "vegetation":
		settings["build_vegetation"] = grass_remaster_enabled
		settings["grass_remaster_spacing_raw"] = grass_remaster_spacing_inspector_raw
		settings["grass_detail_level"] = grass_detail_level
		settings["grass_remaster_density"] = grass_remaster_density_inspector
		settings["grass_remaster_card_width_raw"] = grass_remaster_card_width_inspector_raw
		settings["grass_remaster_card_height_raw"] = grass_remaster_card_height_inspector_raw
		settings["outward_rocks_enabled"] = outward_rocks_enabled
		settings["outward_flowers_enabled"] = outward_flowers_enabled
	if step_name == "water":
		# L'index logique doit toujours etre construit : cette case cache seulement
		# les MeshInstance3D, sans supprimer nage, profondeur ou limites DAoC.
		settings["build_water"] = true
		settings["water_surface_visible"] = water_visual_enabled
		settings["water_modern_texture_enabled"] = water_modern_texture_enabled
		settings["water_alpha"] = water_alpha
		settings["water_uv_world_scale"] = water_uv_world_scale
		settings["water_shore_enabled"] = water_shore_enabled
		settings["water_shore_strength"] = water_shore_strength
		settings["water_wave_strength_scale"] = water_wave_strength_scale
		settings["water_refraction_scale"] = water_refraction_scale
		settings["water_depth_colour_scale"] = water_depth_colour_scale
	if step_name == "terrain":
		settings["terrain_pbr"] = terrain_pbr_quality_options()
		settings["terrain_visual_bilinear_subdivision"] = terrain_bilinear_factor if terrain_bilinear_enabled else 1
	if step_name == "lights":
		settings["build_legacy_lights"] = build_legacy_lights
		settings["legacy_lights_visible"] = legacy_lights_visible
		settings["legacy_light_energy"] = legacy_light_energy
		settings["legacy_light_range"] = legacy_light_range
		settings["legacy_light_attenuation"] = legacy_light_attenuation
		settings["legacy_light_vertical_offset"] = legacy_light_vertical_offset
		settings["use_legacy_light_type_colors"] = use_legacy_light_type_colors
		settings["legacy_lights_cast_shadows"] = legacy_lights_cast_shadows
		settings["legacy_light_shadow_budget"] = legacy_light_shadow_budget
		settings["legacy_light_shadow_blur"] = legacy_light_shadow_blur
		settings["legacy_light_shadow_opacity"] = legacy_light_shadow_opacity
		settings["legacy_lights_flicker"] = legacy_lights_flicker
		settings["legacy_light_flicker_amount"] = legacy_light_flicker_amount
		settings["legacy_lights_show_markers"] = false
		settings["legacy_lights_preview_dark_scene"] = false
		settings["log_legacy_lights"] = false
	settings["world_scale"] = world_scale
	settings["height_exaggeration"] = height_exaggeration
	settings["client_root"] = daoc_client_root
	return settings


func zone_step_enabled_r4(step_name: String) -> bool:
	# En local, les props restent indispensables (arbres, bâtiments, portes et
	# leurs collisions). On diffère seulement les deux couches cosmétiques qui
	# causaient l'essentiel de l'attente. Le profil online historique peut, lui,
	# recevoir ses entités depuis le serveur et conserve son comportement.
	if online_mode and online_fast_start and step_name in ["props", "vegetation", "lights"]:
		return false
	if not online_mode and offline_fast_start and step_name in ["vegetation", "lights"]:
		return false
	if step_name == "water":
		return true
	return true


func zone_step_logging_r4(step_name: String) -> bool:
	var settings: Dictionary = DEFAULT_SETTINGS.get(step_name, {}) as Dictionary
	match step_name:
		"water":
			return bool(settings.get("log_water", false))
		"collisions", "props":
			return bool(settings.get("log_collision", false))
		"zonejumps":
			return bool(settings.get("log_zonejump", false))
		# Le relais d'origine tracait le terrain SANS condition, et le jeu ne
		# change pas cela : c'est la seule ligne qui dit qu'un sol a ete bati.
		"terrain":
			return true
		_:
			return false


func zone_streamer() -> DaocZoneStreamer:
	return session.zone_streamer


func _get_zone_root(znum: int) -> Node3D:
	return zone_streamer().acquire(znum)


func _zone_branch(znum: int, branch_name: String) -> Node3D:
	var root := _get_zone_root(znum)
	if root.has_method("get_branch"):
		return root.call("get_branch", branch_name) as Node3D
	return root


func _collision_root(znum: int) -> Node3D:
	return _zone_branch(znum, "CollisionRoot")


func _props_collision_root(znum: int) -> Node3D:
	var root := _collision_root(znum)
	var existing := root.get_node_or_null("PropsCollisionRoot")
	if existing != null and existing is Node3D:
		return existing as Node3D
	var branch := Node3D.new()
	branch.name = "PropsCollisionRoot"
	root.add_child(branch)
	return branch


func get_asset_index_registry_15d() -> RefCounted:
	if _registry == null:
		_registry = AssetIndexRegistryScript.new()
	_registry.call("configure", {
		"daoc_client_root": daoc_client_root,
		"external_data_dir": external_data_dir,
		"world_scale": world_scale,
		# R10-HF2 — le vent dans les feuilles des props NIF. Le registre pose les
		# materiaux : c'est lui qui sait quelles surfaces portent un canal alpha,
		# donc quelles surfaces sont du feuillage.
		"foliage_wind_enabled": foliage_wind_enabled,
		"foliage_canopy_strength_raw": foliage_canopy_strength_raw,
		"foliage_leaf_flutter_strength_raw": foliage_leaf_flutter_strength_raw,
		"foliage_wind_height_reference_raw": foliage_wind_height_reference_raw,
		"foliage_sunfleck_amount": foliage_sunfleck_amount,
		"foliage_sunfleck_cell_raw": foliage_sunfleck_cell_raw,
		"world_pbr_enabled": world_pbr_enabled,
		"world_pbr_map_size": world_pbr_map_size,
		"world_pbr_normal_strength": world_pbr_normal_strength,
		"world_pbr_roughness_amount": world_pbr_roughness_amount,
		"world_pbr_ao_amount": world_pbr_ao_amount,
	})
	return _registry


func _asset_data_15d(file_name: String) -> String:
	return str(get_asset_index_registry_15d().call("data_path", file_name))


func _asset_zone_file_15d(znum: int, file_name: String) -> String:
	return str(get_asset_index_registry_15d().call("find_zone_dat_asset", znum, file_name))


func _asset_read_15d(asset_file: String) -> Variant:
	return get_asset_index_registry_15d().call("load_json_file", asset_file)


func _asset_tex_15d(asset_file: String) -> Texture2D:
	return get_asset_index_registry_15d().call("load_texture_file", asset_file) as Texture2D


func _find_sector_dat(znum: int) -> String:
	return DaocSectorDat.find_path(
		str(get_asset_index_registry_15d().call("effective_data_dir")),
		str(get_asset_index_registry_15d().call("effective_daoc_root")), znum)


func _parse_sector_dat(path: String) -> Dictionary:
	return DaocSectorDat.parse(path)


## Le module de rendu hérité, configuré par DONNÉES et non depuis un hôte.
##
## C'est ici que le « fil encore attaché » signalé par la tranche 2 de R4 est
## coupé — pour cette scène. Le banc garde `configure_from_host`, et ce n'est pas
## un oubli : il relit ses 318 propriétés à chaque image pour permettre le
## réglage à chaud depuis l'inspecteur distant. Le jeu passe par les donnees ;
## ses setters rappellent explicitement ce module quand une valeur change.
func _ensure_visual_module_15c() -> RefCounted:
	if _visuals == null:
		_visuals = LegacyVisualsScript.new()
	var settings: Dictionary = zone_step_settings_r4("lights").duplicate(true)
	settings.merge(zone_step_settings_r4("vegetation"), true)
	settings["daoc_client_root"] = daoc_client_root
	settings["external_data_dir"] = external_data_dir
	_visuals.call("configure_from_settings", settings, zone_build_services_r4())
	return _visuals


## Les exports du groupe « Lumieres DAoC d'origine » sont des controles live.
## Un changement depuis l'inspecteur distant met a jour les 49 OmniLight3D deja
## presentes ; reactiver la construction cree aussi celles des zones chargees
## quand la scene avait demarre avec l'option coupee.
func _refresh_legacy_lights() -> void:
	if _visuals == null or _state == null:
		return
	var settings: Dictionary = zone_step_settings_r4("lights").duplicate(true)
	settings["daoc_client_root"] = daoc_client_root
	settings["external_data_dir"] = external_data_dir
	_visuals.call("configure_from_settings", settings, zone_build_services_r4())
	if build_legacy_lights:
		for zone_value in _state.zone_runtime.keys():
			var znum := int(zone_value)
			var zone_data: Dictionary = _state.zone_runtime.get(znum, {}) as Dictionary
			_visuals.call("build_zone_lights", znum,
				zone_data.get("origin3", Vector3.ZERO) as Vector3)
	_visuals.call("apply_legacy_light_runtime_settings")


func _world_pbr_options() -> Dictionary:
	return {
		"enabled": world_pbr_enabled,
		"map_size": world_pbr_map_size,
		"normal_strength": world_pbr_normal_strength,
		"roughness_amount": world_pbr_roughness_amount,
		"ao_amount": world_pbr_ao_amount,
	}


## Bascule Vanilla/PBR et intensites sans reconstruire ni recharger la zone.
## Les materiaux d'origine sont memorises lors de la premiere conversion, ce
## qui rend la comparaison reversible, y compris apres plusieurs changements.
func _refresh_world_pbr() -> void:
	if _state == null:
		return
	var options := _world_pbr_options()
	if _registry != null:
		_registry.call("configure_world_pbr_runtime", options)
		for result_value in _state.prop_build_results.values():
			var result := result_value as RefCounted
			if result == null:
				continue
			var props_root := result.get("root") as Node
			if props_root != null and is_instance_valid(props_root):
				_registry.call("apply_world_pbr_runtime", props_root)
	if _population != null:
		if _population_pbr == null:
			_population_pbr = DaocWorldPbrUpgradeScript.new()
		_population_pbr.call("configure", daoc_client_root, options)
		var population_root := _population.get("root") as Node
		if population_root != null and is_instance_valid(population_root):
			_population_pbr.call("apply_to_subtree", population_root)


func _ensure_terrain_runtime_14e() -> void:
	if _state.terrain_runtime_obj == null:
		_state.terrain_runtime_obj = TerrainRuntimeScript.new()
	_state.terrain_runtime_obj.call("bind", _state.terrain_static_index, _state.zone_runtime)


func _ensure_zonejump_runtime() -> void:
	if _state.zonejump_runtime == null:
		_state.zonejump_runtime = ZoneJumpRuntimeScript.new()


func _terrain_14e_zone_uses_splat(znum: int) -> bool:
	var result: RefCounted = _state.terrain_build_results.get(znum, null) as RefCounted
	if result == null:
		return false
	var metrics: Dictionary = result.get("metrics") as Dictionary
	return bool(metrics.get("uses_splat", false))


func _prepare_terrain_splat_resources_14e(znum: int, manifest: Dictionary) -> void:
	if _state.splat_shader == null:
		_state.splat_shader = load("res://terrain_splat.gdshader") as Shader
	var base := _asset_data_15d("zone%03d_splat" % znum)
	var detail_size := int(manifest.get("detail_size", 1024))
	var detail_count := int((manifest.get("details", []) as Array).size())
	var mask_count := int(manifest.get("mask_count", 0))
	_state.splat_details = get_asset_index_registry_15d().call(
		"load_image_array", base + "/details", detail_count, 2, detail_size, true) as Texture2DArray
	_state.splat_masks = get_asset_index_registry_15d().call(
		"load_image_array", base + "/masks", mask_count, 3, 128, false) as Texture2DArray
	if terrain_pbr_enabled and not _state.splat_pbr_by_zone.has(znum):
		var report: Dictionary = DaocTerrainPbrUpgrade.load_zone_maps(
			daoc_client_root, manifest.get("details", []) as Array, terrain_pbr_map_size)
		_state.splat_pbr_by_zone[znum] = report
		print("TERRAIN_PBR={\"zone\":%d,\"ok\":%s,\"couches\":%d,\"avec_cartes\":%d,\"sans_cartes\":%s}" % [
			znum, str(bool(report.get("ok", false))).to_lower(),
			int(report.get("couches_attendues", 0)), int(report.get("couches_avec_cartes", 0)),
			JSON.stringify(report.get("couches_sans_cartes", []))])


## Même traducteur que `ZoneViewer.terrain_pbr_quality_options` : une case, deux
## intensités ; la taille des cartes reste celle du preset livré.
func terrain_pbr_quality_options() -> Dictionary:
	return {
		"enabled": terrain_pbr_enabled,
		"map_size": terrain_pbr_map_size,
		"normal_strength": terrain_pbr_normal_strength,
		"ao_amount": terrain_pbr_ao_amount,
		"macro_variation_enabled": terrain_macro_variation_enabled,
		"macro_variation_scale": terrain_macro_variation_scale,
		"macro_color_strength": terrain_macro_color_strength,
		"macro_roughness_strength": terrain_macro_roughness_strength,
		"macro_seed": terrain_macro_seed,
		"virtual_relief_enabled": terrain_virtual_relief_enabled,
		"virtual_relief_depth": terrain_virtual_relief_depth,
		"virtual_relief_steps": terrain_virtual_relief_steps,
		"dry_roughness_floor": terrain_dry_roughness_floor,
		"ao_light_affect": terrain_ao_light_affect,
		"dry_specular": terrain_dry_specular,
	}


## Rejoue le sol PBR sur les zones bâties, sans reconstruire ; une zone cochée
## après coup charge ses cartes depuis son manifeste splat.
func apply_terrain_pbr_options() -> Dictionary:
	var options := terrain_pbr_quality_options()
	var report := {"checkpoint": DaocTerrainPbrUpgrade.CHECKPOINT, "zones": {}, "enabled": terrain_pbr_enabled}
	if _state == null:
		return report
	for key in _state.terrain_meshes_by_zone.keys():
		var znum := int(key)
		var zone_options := options.duplicate()
		if terrain_pbr_enabled and not _state.splat_pbr_by_zone.has(znum):
			var manifest_path := _asset_data_15d("zone%03d_splat/manifest.json" % znum)
			if FileAccess.file_exists(manifest_path):
				var loaded: Variant = _asset_read_15d(manifest_path)
				if typeof(loaded) == TYPE_DICTIONARY:
					_state.splat_pbr_by_zone[znum] = DaocTerrainPbrUpgrade.load_zone_maps(
						daoc_client_root, (loaded as Dictionary).get("details", []) as Array, terrain_pbr_map_size)
		var maps: Dictionary = _state.splat_pbr_by_zone.get(znum, {}) as Dictionary
		if bool(maps.get("ok", false)):
			zone_options["normals"] = maps.get("normals")
			zone_options["roughness"] = maps.get("roughness")
			zone_options["ao"] = maps.get("ao")
		var zone_report: Dictionary = DaocTerrainPbrUpgrade.apply(
			_state.terrain_meshes_by_zone[key] as Array, zone_options)
		zone_report["cartes"] = bool(maps.get("ok", false))
		zone_report["couches_sans_cartes"] = maps.get("couches_sans_cartes", [])
		(report["zones"] as Dictionary)[znum] = zone_report
	return report


## Setter des trois réglages : avant que le monde existe il n'y a rien à
## rejouer, la valeur sera lue à la construction du sol.
func _refresh_terrain_pbr() -> void:
	if _state == null or not is_inside_tree():
		return
	apply_terrain_pbr_options()


## Reconstruit seulement les branches terrain des zones résidentes. Le reste de
## la scène (joueur, caméra, végétation, bâtiments, réseau) ne redémarre pas.
## Le vieux terrain n'est libéré qu'après la création du nouveau, ce qui laisse
## un repli visuel intact si les données source sont indisponibles.
func apply_terrain_bilinear_options() -> Dictionary:
	var factor := terrain_bilinear_factor if terrain_bilinear_enabled else 1
	var report := {"ok": true, "enabled": terrain_bilinear_enabled, "factor": factor, "zones": {}}
	if _state == null:
		report["ok"] = false
		report["reason"] = "monde non initialise"
		return report
	var services := zone_build_services_r4()
	if services == null or not services.usable():
		report["ok"] = false
		report["reason"] = "services terrain indisponibles"
		return report
	for key in _state.zone_runtime.keys():
		var znum := int(key)
		var runtime: Dictionary = _state.zone_runtime.get(znum, {}) as Dictionary
		var hb: PackedByteArray = runtime.get("hb", PackedByteArray()) as PackedByteArray
		var res := int(runtime.get("res", 0))
		var origin3: Vector3 = runtime.get("origin3", Vector3.ZERO) as Vector3
		var meta_path := _asset_data_15d("zone%03d.json" % znum)
		var meta: Dictionary = {}
		if FileAccess.file_exists(meta_path):
			var file := FileAccess.open(meta_path, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				file.close()
				if typeof(parsed) == TYPE_DICTIONARY:
					meta = parsed as Dictionary
		if hb.is_empty() or res <= 0 or meta.is_empty():
			report["ok"] = false
			(report["zones"] as Dictionary)[znum] = {"ok": false, "reason": "sources terrain indisponibles"}
			continue

		var old_result: RefCounted = _state.terrain_build_results.get(znum, null) as RefCounted
		var old_root: Node = old_result.get("root") as Node if old_result != null else null
		var old_collision_root: Node = old_result.get("collision_root") as Node if old_result != null else null
		var zone_report := DaocZoneTerrainStep.build(services, znum, meta, hb, res, origin3,
			meta_path, zone_step_settings_r4("terrain"), zone_step_logging_r4("terrain"))
		if bool(zone_report.get("ok", false)):
			if old_root != null and is_instance_valid(old_root):
				old_root.queue_free()
			if old_collision_root != null and is_instance_valid(old_collision_root):
				old_collision_root.queue_free()
			_apply_ground_wetness(_ground_wetness)
		else:
			report["ok"] = false
		(report["zones"] as Dictionary)[znum] = zone_report
	return report


func _schedule_terrain_bilinear_refresh() -> void:
	if _state == null or not is_inside_tree() or _terrain_bilinear_refresh_pending:
		return
	_terrain_bilinear_refresh_pending = true
	call_deferred("_refresh_terrain_bilinear")


func _refresh_terrain_bilinear() -> void:
	_terrain_bilinear_refresh_pending = false
	var report := apply_terrain_bilinear_options()
	print("TERRAIN_BILINEAR=%s" % JSON.stringify(report))


func _collision_prop_settings_14c() -> Dictionary:
	var settings: Dictionary = zone_step_settings_r4("props")
	settings["world_scale"] = world_scale
	settings["height_exaggeration"] = height_exaggeration
	return settings


func _load_fixture_collide_table_14c(znum: int) -> Dictionary:
	if _state.fixture_collide_table_cache.has(znum):
		return _state.fixture_collide_table_cache[znum] as Dictionary
	var table: Dictionary = {}
	var path := _asset_zone_file_15d(znum, "fixtures.csv")
	if path != "":
		table = DaocCollisionBuilder.parse_fixture_collide_table(path)
	_state.fixture_collide_table_cache[znum] = table
	return table


func hud_append_zone_fragment_r4(fragment: String) -> void:
	_hud_zones += fragment


## L'altitude du sol. Le runtime terrain est l'autorité dès qu'il existe ; sinon
## on retombe sur la carte de hauteurs brute, exactement comme le banc.
##
## PAS DE PONT DE DONJON 17D ici : le jeu ne monte pas encore les donjons
## générés, et prétendre le contraire ferait répondre une altitude de surface
## sous un sol de donjon.
func sample_daoc_floor_z(znum: int, daoc_x: float, daoc_y: float, daoc_z: float = 0.0) -> float:
	if _state.terrain_runtime_obj != null and _state.terrain_runtime_obj.has_method("sample_floor"):
		return float(_state.terrain_runtime_obj.call("sample_floor", znum, daoc_x, daoc_y, daoc_z))
	var zone_data: Dictionary = _state.zone_runtime.get(znum, {}) as Dictionary
	if zone_data.is_empty():
		return 0.0
	return DaocTerrainRuntime._sample_height(zone_data["hb"], int(zone_data["res"]), daoc_x, daoc_y)


func daoc_to_godot(znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	var zone_data: Dictionary = _state.zone_runtime.get(znum, {}) as Dictionary
	var origin3: Vector3 = zone_data.get("origin3", Vector3.ZERO) as Vector3
	return origin3 + Vector3(
		daoc_x * world_scale,
		daoc_z * world_scale * height_exaggeration,
		daoc_y * world_scale)


func has_generated_dungeon_runtime_zone_17d(_znum: int) -> bool:
	return false


func _origin(znum: int) -> Vector2:
	_ensure_placement()
	return _placement.get(znum, Vector2.ZERO) as Vector2


func _ensure_placement() -> void:
	if not _placement.is_empty():
		return
	var file := FileAccess.open(_asset_data_15d("zones_placement.json"), FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for value in (parsed as Dictionary).get("zones", []) as Array:
		var entry: Dictionary = value as Dictionary
		var origin: Array = entry.get("world_origin", []) as Array
		if origin.size() >= 2:
			_placement[int(entry.get("zone", -1))] = Vector2(float(origin[0]), float(origin[1]))


func _ensure_transition() -> DaocZoneTransition:
	if _transition == null:
		_transition = DaocZoneTransition.from_placement_file(
			_asset_data_15d("zones_placement.json"))
	return _transition


func state_registry() -> DaocZoneViewerStateRegistry:
	return _state


## L'assembleur lit et écrit `_zone_runtime` et `_hud_zones` par nom, comme sur
## le banc : le registre d'état 15E porte les mêmes noms de compatibilité, donc
## la même passerelle suffit.
## R7 — les emplacements de session que `DaocLocalViewerBootstrap` adresse par
## leur nom d'origine. Le banc les expose en accesseurs vers la session depuis
## R0 ; ici la même passerelle suffit, et la session reste la propriétaire.
const SESSION_SLOT_ALIASES := {
	"_player": "player",
	"_player_camera": "player_camera",
	"_input_router": "input_router",
}


func _get(property: StringName) -> Variant:
	if property == &"_hud_zones":
		return _hud_zones
	if property == &"_state_15e":
		return _state
	if property == &"zones":
		# Le bootstrap n'y touche que pour retomber sur une zone bâtie quand
		# celle du joueur ne l'est pas. Ici la zone habitée est la seule vérité.
		return PackedInt32Array([current_zone]) if current_zone >= 0 else PackedInt32Array()
	if SESSION_SLOT_ALIASES.has(str(property)):
		return session.get(str(SESSION_SLOT_ALIASES[str(property)])) if session != null else null
	if _state != null and bool(_state.has_compat_name(str(property))):
		return _state.compatibility_get(str(property))
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property == &"_hud_zones":
		_hud_zones = str(value)
		return true
	if SESSION_SLOT_ALIASES.has(str(property)):
		if session == null:
			return false
		session.set(str(SESSION_SLOT_ALIASES[str(property)]), value)
		return true
	if _state == null:
		return false
	return bool(_state.compatibility_set(str(property), value))


## Le bootstrap P1-15G demande la racine du client par ce nom. Le registre 15D
## la connaît déjà : on ne la recalcule pas.
func _ensure_asset_index_registry_15d() -> RefCounted:
	return get_asset_index_registry_15d()


# ============================================================================
# R7 — la pile joueur. La scène de jeu cesse d'être un décor.
#
# R6 avait laissé le monde statique seul : un sol, de l'eau, des props, et
# personne dedans. Ce qui manquait n'était pas du code de joueur — il existe
# depuis P1-15G — mais le même problème qu'à R4 : `DaocLocalViewerBootstrap`
# lisait vingt-trois propriétés de l'hôte PAR LEUR NOM. Sur une scène qui ne les
# déclare pas, `host.get()` rend `null` et `float(null)` vaut 0.0 : on aurait
# obtenu un joueur immobile qui a l'air configuré.
#
# Le bootstrap accepte donc désormais un dictionnaire, exactement comme les
# étapes de zone depuis R4. Aucun comportement du banc ne change : le ZoneViewer
# n'expose pas `player_stack_settings_r7`, donc il continue d'être lu par nom.
# ============================================================================

# Les réglages du joueur sont regroupés en tête de fichier pour que l'inspecteur
# les présente ensemble. Leurs valeurs restent celles de la scène du banc.

## Le bootstrap P1-15G, qui possède l'assemblage de la pile joueur.
var _bootstrap: RefCounted = null


## Monte le joueur, sa caméra et le routeur d'entrées dans la session.
##
## À appeler après `enter_zone` : le joueur a besoin d'un sol sous lui, et
## `_resolve_player_start` échantillonne le relief de la zone.
func mount_player_r7() -> Dictionary:
	if session == null:
		return {"ok": false, "reason": "session absente"}
	if session.player != null and is_instance_valid(session.player):
		return {"ok": true, "reason": "deja monte", "zone": current_zone}
	if not _state.zone_runtime.has(current_zone):
		return {"ok": false, "reason": "aucune zone habitee, rien pour porter le joueur"}
	if _bootstrap == null:
		_bootstrap = LocalViewerBootstrapScript.new()
	_bootstrap.call("setup_player_stack", self)
	return {
		"ok": session.player != null,
		"zone": current_zone,
		"player": session.player != null,
		"camera": session.player_camera != null,
		"input_router": session.input_router != null,
	}


## Les réglages de la pile joueur, en DONNÉES — le pendant de
## `zone_step_settings_r4` pour ce que R7 monte.
##
## `mount_dol_and_hud` est à FAUX, et c'est le point sensible du jalon : parmi
## les onze montages que ce garde couvre se trouvent le transport DOL et le flux
## de login, c'est-à-dire du RÉSEAU. Les laisser dépendre de propriétés absentes
## reviendrait à laisser `bool(null)` décider d'ouvrir une connexion. Le jour où
## le jeu parlera à un serveur, ce sera par `DaocServerLink` et de façon
## explicite, pas par un drapeau oublié.
func player_stack_settings_r7() -> Dictionary:
	return {
		"spawn_player_capsule": true,
		"player_zone": current_zone,
		"player_run_speed_raw": player_run_speed_raw,
		"player_turn_rate_deg_per_sec": player_turn_rate_deg_per_sec,
		"player_use_client_camera_ini": true,
		"player_camera_ini_path": "res://data/default.ini",
		"player_camera_debug_input": false,
		"player_camera_snapback_enabled": true,
		"player_camera_snapback_speed_units_per_sec": 2048.0,
		"player_camera_current": player_camera_current,
		"player_camera_distance_raw": player_camera_distance_raw,
		"player_camera_height_raw": player_camera_height_raw,
		"player_camera_tilt_raw": player_camera_tilt_raw,
		"player_camera_fov_degrees": player_camera_fov_degrees,
		"player_right_mouse_turns_player": false,
		"player_use_keyboard_dat_bindings": true,
		"player_respect_keyboard_shift_raw": false,
		# Les trois variantes de deplacement a la souris de l'original restent
		# COUPEES, comme dans la scene enregistree du banc.
		"player_force_disable_legacy_mouse_movement": true,
		"player_mouse_right_moves_forward": false,
		"player_mouse_left_moves_backward": false,
		"player_mouse_both_buttons_move_forward": false,
		"player_keyboard_preset": "rpgdefault",
		"player_debug_print_keyboard_bindings": false,
		"player_show_debug_mesh": false,
		"build_local_targeting": true,
		"local_targeting_nearest_radius_raw": 2400.0,
		"log_player_spawn": false,
		"player_use_sector_start": false,
		"mount_dol_and_hud": false,
	}


## Le point de départ du joueur. Volontairement plus simple que celui du banc :
## une position explicite, ramenée sur le sol.
func _resolve_player_start(znum: int) -> Dictionary:
	var x := clampf(player_start_x, 0.0, 65536.0)
	var y := clampf(player_start_y, 0.0, 65536.0)
	return {
		"pos": Vector3(x, y, sample_daoc_floor_z(znum, x, y, 0.0)),
		"heading": player_start_heading_deg,
		"source": "configure",
	}


## Le solveur de frontières que le moteur du joueur interroge à chaque image.
## Il lit l'index de session, celui-là même que la tranche 4 de R4 a rendu
## propriétaire de `DaocZoneCollisionStep` et que R5 balaie au déchargement.
func solve_daoc_boundary_collision(znum: int, old_x: float, old_y: float,
		new_x: float, new_y: float, radius_raw: float = 40.0) -> Vector2:
	var target := Vector2(new_x, new_y)
	if _state.collision_runtime_obj == null \
			or not _state.collision_runtime_obj.has_method("solve_boundary_collision"):
		return target
	return _state.collision_runtime_obj.call("solve_boundary_collision",
		znum, old_x, old_y, new_x, new_y, radius_raw) as Vector2


func solve_daoc_prop_collision(znum: int, old_x: float, old_y: float,
		new_x: float, new_y: float, daoc_z: float,
		radius_raw: float = 40.0, height_raw: float = 136.0) -> Vector2:
	var target := Vector2(new_x, new_y)
	if _state.collision_runtime_obj == null \
			or not _state.collision_runtime_obj.has_method("solve_prop_collision"):
		return target
	return _state.collision_runtime_obj.call("solve_prop_collision",
		znum, old_x, old_y, new_x, new_y, daoc_z, radius_raw, height_raw) as Vector2


func sample_daoc_water_info(znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Dictionary:
	if _state.water_runtime_obj == null or not _state.water_runtime_obj.has_method("sample_daoc"):
		return {}
	var floor_z := sample_daoc_floor_z(znum, daoc_x, daoc_y, daoc_z)
	return _state.water_runtime_obj.call("sample_daoc",
		znum, daoc_x, daoc_y, daoc_z, floor_z) as Dictionary


# ============================================================================
# R8 — le ciel. Sans lui, la scène de jeu était un monde qu'on ne pouvait pas
# REGARDER.
#
# R6 avait coupé les lumières héritées, et pour une bonne raison : elles sont
# remplacées depuis P1-20K par l'autorité d'environnement DAoC. Mais cette
# autorité n'était montée que par le banc. La scène de jeu avait donc un sol, de
# l'eau, des props, un joueur — et aucune source de lumière. Un monde noir, dont
# aucun contrôle de présence n'aurait rien dit.
#
# C'est aussi le jalon qui débloque les verdicts visuels en attente : on ne juge
# pas un monde qu'on ne voit pas.
#
# Rien n'est réécrit ici non plus. `DaocEnvironmentController` reste l'autorité,
# `DaocSky3DAdapter` le backend, `DaocWeatherFx` les particules ; le contrôleur
# prend la place que R0 lui avait NOMMÉE dans la session — `world_clock`, décrit
# dès R0 comme « l'autorité DAoC devant Sky3D ».
# ============================================================================

# Les réglages de temps et de météo sont regroupés en tête de fichier. Le vrai
# front météo viendra du serveur par `set_daoc_weather_front`.

var _environment_controller: Node = null
var _sky3d_adapter: Node = null
var _weather_fx: Node = null
var _environment_report: Dictionary = {}
var _ground_wetness: float = 0.0
var _ambient_wildlife: Node3D = null
var _ambient_wildlife_report: Dictionary = {}


func mount_ambient_wildlife() -> Dictionary:
	if _ambient_wildlife != null and is_instance_valid(_ambient_wildlife):
		return _ambient_wildlife_report.duplicate(true)
	if session == null or session.player == null:
		return {"ok": false, "reason": "joueur absent"}
	_ambient_wildlife = DaocAmbientWildlifeScript.new()
	_ambient_wildlife.name = "DaocAmbientWildlife"
	add_child(_ambient_wildlife)
	_ambient_wildlife_report = _ambient_wildlife.call("setup", session.player, {
		"economical_mode": _fast_start_active(),
		"bird_count": ambient_bird_count,
		"butterfly_count": ambient_butterfly_count,
		"insect_count": ambient_insect_count,
		"leaf_count": ambient_leaf_count,
		"tree_anchors": _ambient_tree_anchors(session.player.global_position),
	}) as Dictionary
	return _ambient_wildlife_report.duplicate(true)


func _ambient_tree_anchors(origin: Vector3) -> Array[Vector3]:
	var anchors: Array[Vector3] = []
	if _state == null:
		return anchors
	for value in _state.prop_static_index:
		var entry := value as Dictionary
		var low := str(entry.get("file", "")).to_lower()
		if not (low.contains("tree") or low.contains("oak") or low.contains("pine") or low.contains("birch") or low.contains("elm")):
			continue
		var world := Vector3(float(entry.get("position_x", 0.0)), float(entry.get("position_y", 0.0)), float(entry.get("position_z", 0.0)))
		var local := world - origin
		if Vector2(local.x, local.z).length() <= 2400.0:
			anchors.append(local)
			if anchors.size() >= 24:
				break
	return anchors


## Monte l'autorité d'environnement, son backend de rendu et ses particules.
##
## À appeler après `enter_zone` : le profil est celui de la zone habitée, lu dans
## le `SECTOR.DAT` et le `zones.dat` du client.
func mount_environment_r8() -> Dictionary:
	if _environment_controller != null:
		return {"ok": true, "reason": "deja monte"}
	if current_zone < 0:
		return {"ok": false, "reason": "aucune zone habitee, aucun profil a lire"}

	var profile: RefCounted = DaocZoneEnvironmentProfileScript.new().load_from_client(
		current_zone, daoc_client_root)

	_sky3d_adapter = DaocSky3DAdapterScript.new()
	_sky3d_adapter.name = "DaocSky3DAdapter"
	add_child(_sky3d_adapter)
	_sky3d_adapter.call("setup")
	_sky3d_adapter.call("set_quality_options", sky_quality_options_r8())

	_weather_fx = DaocWeatherFxScript.new()
	_weather_fx.name = "DaocWeatherFX"
	add_child(_weather_fx)
	_weather_fx.call("setup", null)
	_weather_fx.set("wet_soak_seconds", ground_wet_soak_seconds)
	_weather_fx.set("wet_dry_seconds", ground_wet_dry_seconds)
	_weather_fx.connect("ground_wetness_changed", Callable(self, "_on_ground_wetness_changed"))

	_environment_controller = DaocEnvironmentControllerScript.new()
	_environment_controller.name = "DaocEnvironmentController"
	_environment_controller.connect("environment_state_changed",
		Callable(self, "_on_environment_state_changed"))
	add_child(_environment_controller)
	# R0 avait NOMMÉ cet emplacement avant qu'il ait un occupant dans le jeu.
	session.world_clock = _environment_controller
	_environment_controller.call("configure", profile, {
		"server_time_seconds": roundi(environment_time_hours * 3600.0),
		"offline_test_mode": true,
		"offline_cycle_enabled": environment_cycle_enabled,
		"offline_minutes_per_day": environment_minutes_per_day,
		"transition_seconds": 0.0,
	})
	_apply_offline_weather()
	_on_environment_state_changed(
		_environment_controller.call("emit_current_state", true) as Dictionary)

	if environment_log_state:
		print("DAOC_ENVIRONMENT=%s" % JSON.stringify(get_daoc_environment_debug_snapshot()))
	return {
		"ok": true,
		"zone": current_zone,
		"sun": _sky3d_adapter.call("sun_light") != null,
		"environment": _sky3d_adapter.call("environment_resource") != null,
	}


func sky_quality_options_r8() -> Dictionary:
	return {
		"glow_enabled": sky_glow_enabled,
		"glow_intensity": sky_glow_intensity,
		"glow_hdr_threshold": sky_glow_hdr_threshold,
		"ambient_from_sky_enabled": sky_ambient_from_sky_enabled,
		"ambient_sky_contribution": sky_ambient_sky_contribution,
		"ambient_energy_scale": sky_ambient_energy_scale,
		"ssao_intensity": ground_contact_ssao_intensity,
		"realtime_radiance_enabled": sky_realtime_radiance_enabled,
		"aerial_perspective_enabled": sky_aerial_perspective_enabled,
		"aerial_perspective_amount": sky_aerial_perspective_amount,
		"volumetric_fog_enabled": sky_volumetric_fog_enabled,
		"volumetric_fog_density": sky_volumetric_fog_density,
		"volumetric_fog_length": sky_volumetric_fog_length_raw * world_scale,
		"sun_rays_energy": sky_sun_rays_energy,
		"sun_arc_extra_tilt_degrees": sky_sun_arc_extra_tilt_degrees,
		"shadow_softness_degrees": sky_shadow_softness_degrees,
		"shadow_max_distance": sky_shadow_max_distance_raw * world_scale,
		"sun_energy_scale": sky_sun_energy_scale,
		"sun_warm_palette_enabled": sky_sun_warm_palette_enabled,
		"sun_day_color": sky_sun_day_color,
		"sun_low_color": sky_sun_low_color,
		"sun_warmth_strength": sky_sun_warmth_strength,
		"tonemap_agx_enabled": sky_tonemap_agx_enabled,
		"tonemap_exposure": sky_tonemap_exposure,
		"color_saturation": sky_color_saturation,
		"color_contrast": sky_color_contrast,
		"cloud_shading": sky_cloud_shading,
		"cloud_silver_lining": sky_cloud_silver_lining,
		"cloud_drift_enabled": sky_cloud_drift_enabled,
	}


func _apply_offline_weather() -> void:
	match environment_weather.to_upper():
		"RAIN":
			_environment_controller.call("set_offline_weather",
				DaocWeatherFrontStateScript.PrecipitationHint.RAIN,
				environment_weather_intensity, 0.0)
		"SNOW":
			_environment_controller.call("set_offline_weather",
				DaocWeatherFrontStateScript.PrecipitationHint.SNOW,
				environment_weather_intensity, 0.0)
		_:
			_environment_controller.call("set_weather_front_raw", {
				"x": 0.0, "width": 0.0, "speed": 0.0,
				"fogdiffusion": 0.0, "intensity": 0.0,
			}, DaocWeatherFrontStateScript.PrecipitationHint.UNKNOWN)


## L'autorité a parlé : le backend et les particules suivent. Aucun des deux ne
## décide de quoi que ce soit — c'est ce découpage qui permettra de brancher un
## vrai serveur sans toucher au rendu.
func _on_environment_state_changed(state: Dictionary) -> void:
	if _sky3d_adapter != null:
		_sky3d_adapter.call("apply_environment_state", state)
	if _weather_fx != null:
		_weather_fx.call("apply_environment_state", state)
	_environment_report = {
		"ok": true,
		"state": state.duplicate(true),
		"sky_backend": _sky3d_adapter.call("debug_snapshot") if _sky3d_adapter != null else {},
		"weather_fx": _weather_fx.call("debug_snapshot") if _weather_fx != null else {},
	}


func _on_ground_wetness_changed(amount: float) -> void:
	_ground_wetness = clampf(amount, 0.0, 1.0)
	_apply_ground_wetness(_ground_wetness)


func _apply_ground_wetness(amount: float) -> void:
	if _state == null:
		return
	for meshes_value in _state.terrain_meshes_by_zone.values():
		for mesh_value in (meshes_value as Array):
			var mesh := mesh_value as MeshInstance3D
			if mesh == null:
				continue
			var material := mesh.material_override as ShaderMaterial
			if material == null:
				continue
			material.set_shader_parameter("weather_wetness", amount)
			material.set_shader_parameter("wet_roughness", ground_wet_roughness)
			material.set_shader_parameter("wet_darkening", ground_wet_darkening)


## Les deux points d'entrée que les futurs gestionnaires de paquets DOL
## appelleront. Ils n'adressent JAMAIS Sky3D : c'est tout l'intérêt de l'autorité.
func set_daoc_server_time_seconds(seconds: int) -> void:
	if _environment_controller != null:
		_environment_controller.call("set_server_time_seconds", seconds)


func set_daoc_weather_front(raw: Dictionary, precipitation_hint: int = 0) -> void:
	if _environment_controller != null:
		_environment_controller.call("set_weather_front_raw", raw, precipitation_hint)


func get_daoc_environment_debug_snapshot() -> Dictionary:
	return _environment_report.duplicate(true)


# ============================================================================
# R9 — le monde se peuple. La scène de jeu cesse d'être VIDE.
#
# Après R8 elle avait un sol, de l'eau, des props, un joueur et un ciel — et
# personne d'autre. R9 y met les 311 entités de la capture : 197 scènes vivantes,
# 110 props par `objects.csv → items.csv`, 3 balises Minotaures sans scène.
#
# `DaocGothwaitePopulation` demande peu à son hôte, et c'est ce qui rend ce jalon
# court : cinq choses seulement — `daoc_to_godot`, `sample_daoc_floor_z`,
# `sample_daoc_water_info`, `world_scale`, `height_exaggeration`. La scène de jeu
# les fournit toutes depuis R6 et R7. Le vrai travail était ailleurs : ne pas
# réécrire les onze réglages de mémoire.
#
# LEÇON DE R7 APPLIQUÉE D'AVANCE : les valeurs ci-dessous sont relevées une à une
# dans `ZoneViewer.gd`, et la suite R9 les compare clé par clé au banc. À R7, sept
# valeurs écrites de mémoire divergeaient en silence ; l'oracle n'existait pas
# encore. Ici il est écrit avant le premier essai.
# ============================================================================

## La capture et les manifestes. Ce sont des chemins de PROJET et non de client :
## le registre de scènes vient du Character Lab, hors ligne, et c'est voulu — ce
## projet ne convertit aucun NIF au runtime.
const POPULATION_FIXTURE_PATH := "res://reports/p1_20e_nearby_world_offline/p1_20e_entity_registry.json"
const POPULATION_MANIFEST_PATH := "res://assets/daoc/npc_showcase/manifest.json"
const POPULATION_PROP_MANIFEST_PATH := "res://assets/daoc/gothwaite_props/manifest.json"

## Réglages du peuplement, relevés dans le banc. La zone et la région valent 51
## des deux côtés : c'est la fixture canonique du projet.
const POPULATION_SETTINGS := {
	"zone": 51,
	"region": 51,
	"world_origin_x": 491520.0,
	"world_origin_y": 491520.0,
	"source_units_per_meter": 100.0,
	"culling_distance_m": 80.0,
	"show_ready_labels": false,
	## Les trois balises Minotaures n'ont pas de scène : leur étiquette est la
	## seule chose qui dise qu'elles existent. Le banc les montre, le jeu aussi.
	"show_fallback_labels": true,
	"grounding_enabled": true,
}

## Le raffinement d'ancrage, qui a besoin d'une trame PHYSIQUE : les corps du
## terrain et des fixtures viennent d'entrer dans la scène, leur espace de
## collision n'est interrogeable qu'après.
const POPULATION_GROUNDING := {
	"collision_mask": 5,
	"probe_above_raw": 128.0,
	"probe_below_raw": 4096.0,
	"source_tolerance_raw": 256.0,
}

var _population: RefCounted = null
var _population_report: Dictionary = {}
var _population_pbr: RefCounted = null
var _population_pbr_queue: Array[Node] = []
var _population_pbr_report := {"upgraded": 0, "surfaces": 0, "missing": 0, "skipped": 0}


## Peuple le monde. À appeler après `enter_zone` : chaque entité est reposée sur
## le relief, et sans sol elles tomberaient toutes à l'altitude zéro.
##
## Le raffinement d'ancrage par collision est DIFFÉRÉ, comme dans le banc, et pour
## la même raison : il lui faut une trame physique. Appelé tout de suite, il
## interrogerait un espace de collision vide et ne raffinerait rien — en silence.
func mount_population_r9() -> Dictionary:
	if session == null:
		return {"ok": false, "reason": "session absente"}
	if _population != null:
		return {"ok": true, "reason": "deja peuple"}
	if not _state.zone_runtime.has(current_zone):
		return {"ok": false, "reason": "aucune zone habitee, rien pour porter les entites"}

	_population = DaocGothwaitePopulationScript.new()
	_population_report = _population.call("build", self,
		POPULATION_FIXTURE_PATH, POPULATION_MANIFEST_PATH,
		population_settings_r9()) as Dictionary
	if world_pbr_enabled:
		_population_pbr = DaocWorldPbrUpgradeScript.new()
		_population_pbr.call("configure", daoc_client_root, {
			"enabled": true,
			"map_size": world_pbr_map_size,
			"normal_strength": world_pbr_normal_strength,
			"roughness_amount": world_pbr_roughness_amount,
			"ao_amount": world_pbr_ao_amount,
		})
		var population_root := _population.get("root") as Node
		if population_root != null:
			for child in population_root.get_children():
				_population_pbr_queue.append(child)
			_population_report["pbr"] = {"pending": _population_pbr_queue.size()}
	# R0 avait nommé cet emplacement bien avant qu'il ait un occupant dans le jeu.
	session.entity_population = _population
	if bool(POPULATION_SETTINGS["grounding_enabled"]):
		call_deferred("refine_population_grounding_r9")
	return _population_report.duplicate(true)


func population_settings_r9() -> Dictionary:
	var settings: Dictionary = POPULATION_SETTINGS.duplicate(true)
	settings["prop_manifest_path"] = POPULATION_PROP_MANIFEST_PATH
	return settings


## Repose les entités sur les corps de collision réels plutôt que sur le relief
## échantillonné. Sans trame physique, il n'y a rien à interroger.
func refine_population_grounding_r9() -> Dictionary:
	if _population == null or not _population.has_method("refine_living_supports"):
		return {"ok": false, "reason": "aucun peuplement a raffiner"}
	if is_inside_tree():
		await get_tree().physics_frame
	_population_report = _population.call("refine_living_supports", self,
		POPULATION_GROUNDING.duplicate(true)) as Dictionary
	return _population_report.duplicate(true)


func get_gothwaite_population_debug_snapshot() -> Dictionary:
	return _population_report.duplicate(true)


# ============================================================================
# R11 — autorite de combat et interface du client dans la vraie scene de jeu.
# ============================================================================

var _local_server: DaocLocalServer = null
var _combat_client: DaocCombatClient = null
var _combat_hud: DaocCombatHud = null
var _daoc_ui_bus: DaocUiAdapterBus = null
var _daoc_ui_manager: DaocUiWindowManager = null
var _daoc_ui_bridge: DaocUiServerBridge = null
var _alpha_inventory: CanvasLayer = null
var _quickbars: CanvasLayer = null
var _text_windows: CanvasLayer = null
const DaocTextWindowsScript = preload("res://src/daoc/ui/DaocTextWindows.gd")
const DaocSpellIconAtlasScript = preload("res://src/daoc/ui/DaocSpellIconAtlas.gd")
var _spell_icon_atlas: RefCounted = null
var _gameplay_ui_report: Dictionary = {}
var _mouse_target_wired: bool = false


func mount_gameplay_ui_r11() -> Dictionary:
	if session == null or session.player == null:
		return {"ok": false, "reason": "joueur ou session absent"}
	if _local_server != null:
		return _gameplay_ui_report.duplicate(true)
	var boot_entities: Array = []
	var boot_options: Dictionary = {
		"player_level": local_server_player_level, "melee_range_raw": local_server_melee_range_raw,
		"retaliation_enabled": true, "seed_base": 20260902,
		"starter_kit_auto_equip": not player_starts_unequipped,
	}
	if online_mode:
		# B4 — en ligne l'arbitre n'arbitre plus : il REFLETE. Seul le joueur
		# est amorce, les PNJ entrent par le flux serveur (voir
		# _bind_online_stream_to_authority), exactement comme R3 le fait pour
		# le flux R2 dans le banc.
		boot_entities = [_online_player_entity()]
		boot_options["mirror_mode"] = true
		# P1-110 : les sacs de butin et pierres tombales (0xD9) se ciblent en ligne.
		boot_options["world_objects_targetable"] = true
	else:
		var source: Dictionary = DaocNearbyWorldEntitySourceScript.from_fixture(POPULATION_FIXTURE_PATH)
		if not bool(source.get("ok", false)):
			return {"ok": false, "reason": "fixture de population illisible"}
		boot_entities = (source.get("entities", []) as Array).duplicate(true)
		# Le personnage clique dans le menu (Riri/Fifi/Loulou) porte SON nom dans
		# l'arbitre et l'interface, pas celui de la capture.
		var chosen_name := str(_online_character.get("name", ""))
		if chosen_name != "":
			for index in boot_entities.size():
				if boot_entities[index] is Dictionary and str((boot_entities[index] as Dictionary).get("entity_type", "")) == "player":
					var player_entity: Dictionary = (boot_entities[index] as Dictionary).duplicate(true)
					player_entity["name"] = chosen_name
					boot_entities[index] = player_entity
	_local_server = DaocLocalServerScript.new()
	_local_server.name = "DaocLocalServer"
	add_child(_local_server)
	var server_report: Dictionary = _local_server.boot(boot_entities, boot_options)
	# P1-97 : hors ligne, la mort et la reapparition du joueur viennent de l arbitre.
	_local_server.entity_died.connect(func(object_id: int, _snapshot: Dictionary) -> void:
		if object_id == _local_server.player_object_id:
			set_player_dead(true, "Vous etes mort."))
	_local_server.entity_respawned.connect(func(object_id: int, _snapshot: Dictionary) -> void:
		if object_id == _local_server.player_object_id:
			set_player_dead(false))
	# P1-124 : un familier invoque hors ligne recoit un corps, et le perd a sa liberation.
	if _local_server.has_signal("pet_summoned"):
		_local_server.pet_summoned.connect(func(entity: Dictionary) -> void:
			if _population == null:
				return
			_population.spawn_one(self, entity)
			var node: Node3D = _population.call("wrapper_of", int(entity.get("object_id", -1))) as Node3D
			if node != null:
				_local_server.attach_entity_node(int(entity.get("object_id", -1)), node))
		_local_server.pet_released.connect(func(pet_id: int, _reason: String) -> void:
			if _population != null:
				_population.despawn_one(pet_id))
	# P1-123 : GatewayPersonalBind hors ligne ramene le joueur a son point de lien.
	if _local_server.has_signal("player_moved_to_bind"):
		_local_server.player_moved_to_bind.connect(func(world_position: Vector3, region: int) -> void:
			teleport_player_to_world_point(world_position.x, world_position.y, world_position.z, 0, region))
	if _population != null:
		server_report["nodes_attached"] = _local_server.attach_nodes(_population.get("root") as Node)
	# P1-93 — la poupee suit le sac : ce que le joueur porte est ce qu'on voit.
	server_report["equipment_visuals"] = mount_equipment_visuals_p1_93()

	if combat_log_fallback_enabled:
		_combat_hud = DaocCombatHudScript.new()
		_combat_hud.name = "DaocCombatLogFallback"
		_combat_hud.show_status_panels = false
		add_child(_combat_hud)
	_combat_client = DaocCombatClientScript.new()
	_combat_client.name = "DaocCombatClient"
	add_child(_combat_client)
	_combat_client.setup(self, session.player, _local_server, _combat_hud, {
		"world_origin": _population_world_origin(),
		"target_radius_raw": combat_target_radius_raw,
		"target_key": int(combat_target_key), "attack_key": int(combat_attack_key),
		"zone_id": start_zone,
	})
	# P1-133 : hors ligne aussi, le style joue son clip canims et le coup ses VFX.
	_combat_client.style_catalogue = preload("res://src/daoc/gameplay/effects/DaocStyleVisualCatalogue.gd").new()
	if not _combat_client.style_catalogue.load_tables(daoc_client_root):
		_combat_client.style_catalogue = null
	_combat_client.melee_vfx_world_scale = world_scale
	_combat_client.weapon_family = weapon_animation_family
	_wire_mouse_targeting_r11()
	var ui_report := _mount_xml_ui_r11()
	_alpha_inventory = DaocAlphaInventoryScript.new()
	_alpha_inventory.name = "DaocAlphaInventory"
	# `player_appearance_choice` vaut seulement 0/1/2 (les trois démonstrateurs
	# historiques). La poupée d'inventaire a besoin du vrai fig3 appearance_id
	# 1..36, sinon toute race retombe sur le même tissu générique du Lab.
	var paper_doll_appearance := preload("res://src/daoc/player/DaocPlayerCatalogAppearance.gd").appearance_for_character(_online_character)
	if paper_doll_appearance <= 0:
		paper_doll_appearance = int({0: 10, 1: 31, 2: 17}.get(player_appearance_choice, 10))
	_alpha_inventory.call("setup", daoc_client_root, _online_character, paper_doll_appearance)
	# P1-93 — le sac vit dans l arbitre ; la fenetre le montre et lui demande.
	# P1-95 — en ligne le sac est celui du SERVEUR (0x02) : la fenetre n ecoute
	# pas l arbitre miroir, dont l inventaire de depart local serait un mensonge.
	if not online_mode:
		_alpha_inventory.call("bind_authority", _local_server)
	# P1-98 : un objet glisse d une case a l autre part a l autorite (0xDD en ligne).
	_alpha_inventory.move_requested.connect(func(from_slot: int, to_slot: int) -> void: move_inventory_item(from_slot, to_slot))
	# P1-121 : un objet lache sur le monde est DONNE a ce qui est sous la souris.
	_alpha_inventory.give_requested.connect(func(from_slot: int, screen_position: Vector2) -> void: give_inventory_item_at_screen(from_slot, screen_position))
	# P1-102 : clic droit sur un objet -> 0xD8 en ligne, infobulle hors ligne ; 0xC4 -> fenetre de texte.
	_detail_window = preload("res://src/daoc/ui/DaocDetailWindow.gd").new()
	_detail_window.name = "DaocDetailWindow"
	add_child(_detail_window)
	_alpha_inventory.detail_requested.connect(request_item_detail)
	# P1-128 : clic sur une arme equipee -> 0x71 UseSlot (hors ligne : jeu visible).
	_alpha_inventory.weapon_use_requested.connect(func(slot: int) -> void: _use_inventory_slot(slot))
	# P1-107 : la fenetre d entraineur (0x7B -> fenetre, Former -> 0x53).
	_trainer_window = preload("res://src/daoc/ui/DaocTrainerWindow.gd").new()
	_trainer_window.name = "DaocTrainerWindow"
	add_child(_trainer_window)
	_trainer_window.train_requested.connect(request_train)
	_attach_xml_window_p1_134(_trainer_window, "training_window")
	add_child(_alpha_inventory)
	if online_mode and not _online_inventory_ui_snapshot.is_empty():
		# Le 0x02 est arrive avant que la fenetre existe : on le lui rejoue.
		_alpha_inventory.call("refresh_from_snapshot", _online_inventory_ui_snapshot)
	if _daoc_ui_manager != null:
		_daoc_ui_manager.engine_window_requested.connect(_on_engine_window_requested)
	# Le metier du personnage choisi ouvre ses lignes de sorts : un Wizard de
	# niveau 1 a deja des sorts. Jusqu'au 2026-09-15 le grimoire restait vide
	# parce que setup() n'etait jamais appele et qu'aucun metier n'etait declare.
	var spells_report := _configure_player_class_spells()
	_quickbars = preload("res://src/daoc/ui/DaocQuickbars.gd").new()
	_quickbars.name = "DaocQuickbars"
	_quickbars.setup(_local_server, _combat_client, str(_online_character.get("name", "default")))
	add_child(_quickbars)
	# Les icones de sorts du client d'origine (icons.csv + planches icons/*.bmp).
	_spell_icon_atlas = DaocSpellIconAtlasScript.new()
	var icon_report: Dictionary = _spell_icon_atlas.setup(daoc_client_root)
	_quickbars.set_icon_atlas(_spell_icon_atlas)
	# P1-99 : la barre des effets actifs (0x7F), en haut de l ecran.
	_effect_bar = preload("res://src/daoc/ui/DaocEffectBar.gd").new()
	_effect_bar.name = "DaocEffectBar"
	add_child(_effect_bar)
	_effect_bar.set_icon_atlas(_spell_icon_atlas)
	# P1-108 : clic droit sur un effet = 0xF8 ; la fenetre de concentration
	# (0x75 / 0x76) et la fenetre du pet (0x88 / 0x8A).
	_effect_bar.cancel_requested.connect(_on_effect_cancel_requested)
	_concentration_window = preload("res://src/daoc/ui/DaocConcentrationWindow.gd").new()
	_concentration_window.name = "DaocConcentrationWindow"
	add_child(_concentration_window)
	_concentration_window.set_icon_atlas(_spell_icon_atlas)
	_concentration_window.remove_requested.connect(_on_concentration_remove_requested)
	_pet_window = preload("res://src/daoc/ui/DaocPetWindow.gd").new()
	_pet_window.name = "DaocPetWindow"
	add_child(_pet_window)
	_pet_window.set_icon_atlas(_spell_icon_atlas)
	_pet_window.entity_lookup = Callable(self, "_pet_entity_info")
	_pet_window.command_requested.connect(_on_pet_command_requested)
	# P1-109 : titres, Master Levels, Champion, siege, compte a rebours ; /face /stick /follow, cible au sol.
	_mount_career_windows_p1_109()
	# P1-110 : ecran de mort, journal et fenetre de quete, cherche groupe, embleme ; ramasser.
	_mount_social_windows_p1_110()
	# P1-114 : boutique du marchand, fenetre d echange, bourse et encombrement.
	_mount_merchant_windows_p1_114()
	_mount_economy_windows_p1_122()
	# P1-98 : les objets de la quickbar (arme 1 main / 2 mains / distance, potions).
	_quickbars.online_item_user = Callable(self, "_use_inventory_slot")
	if _combat_client != null:
		_combat_client.quickbar_key_consumer = Callable(_quickbars, "try_activate_key")
	_quickbars.macro_runner = Callable(self, "_on_text_command_submitted")
	_quickbars.console_target = _text_windows
	# Le grimoire vit dans la fenetre « Sorts » du client, pas en flottant.
	var spellbook_report: Dictionary = {"ok": false, "reason": "fenetre stats_spells absente"}
	if _daoc_ui_manager != null:
		var spells_window: Control = _daoc_ui_manager.get_daoc_window("stats_spells")
		if spells_window != null:
			spellbook_report = _quickbars.attach_spellbook_to(spells_window)
		# P1-129 : les styles dans la fenetre « Combat » (STYLES du menu).
		var combat_window: Control = _daoc_ui_manager.get_daoc_window("stats_combat")
		if combat_window != null:
			_quickbars.attach_stylebook_to(combat_window)
	# Les deux fenetres de texte du client : chat et console. Le journal de
	# l'arbitre local part dans la console ; en ligne, le texte du serveur aussi.
	_text_windows = DaocTextWindowsScript.new()
	_text_windows.name = "DaocTextWindows"
	add_child(_text_windows)
	_text_windows.command_submitted.connect(_on_text_command_submitted)
	if _combat_hud != null:
		_combat_hud.set_console_target(_text_windows)
	if online_mode:
		_bind_online_status_and_text()
		_bind_online_combat()
		_bind_online_career()
		_bind_online_social()
		_bind_online_merchant()
		_bind_online_economy_p1_122()
		_bind_online_travel()
		_mount_server_animations_p1_76()
	_gameplay_ui_report = {"ok": bool(server_report.get("ok", false)), "server": server_report,
		"ui": ui_report, "inventory": _alpha_inventory.get_debug_snapshot(),
		"quickbars": _quickbars.get_debug_snapshot(),
		"spellbook": spellbook_report, "text_windows": _text_windows.get_debug_snapshot(),
		"class_spells": spells_report,
		"spell_icons": icon_report,
		"network_access_performed": false}
	return _gameplay_ui_report.duplicate(true)


# ============================================================================
# 2026-09-15 — le jeu EN LIGNE : ce que le serveur envoie arrive a l'ecran.
#
# B1 position (start_game_from_pregame), B2 entites (mount_online_population),
# B3 mouvement (_tick_online_movement), B4 arbitre en miroir (boot mirror_mode).
# Ce qui n'est PAS branche : les jauges/texte serveur (B5), l'emission de
# combat, sorts et styles (B6), mort/XP/quete (B7), l'inventaire (B8). Les
# refus de l'arbitre miroir le disent en clair dans le journal de combat.
# ============================================================================

const DaocPlayableRosterScript = preload("res://src/daoc/ui/pregame/DaocPlayableRoster.gd")

## Vrai quand la partie a ete lancee en mode Online depuis l'ecran de choix.
var online_mode: bool = false
var _online_runtime: Node = null
var _online_character: Dictionary = {}
var _chosen_visual_scene := ""
var _online_start_report: Dictionary = {}
var _online_stream: DaocEntityStreamRuntime = null
var _online_events_received: int = 0
var _online_move_clock: float = 0.0
var _online_move_sent: int = 0
var _online_move_refused: int = 0
var _online_last_move_error: String = ""
var _online_last_sent: Dictionary = {}

@export_group("En ligne")
## Cadence d'envoi de la position au serveur (0xA9), en secondes. Le client
## d'origine envoie environ quatre fois par seconde en mouvement.
@export_range(0.05, 2.0, 0.05) var online_movement_send_interval_sec: float = 0.25
## P1-112 : a l ARRET, un 0xA9 part quand meme toutes les N secondes. Le
## serveur ne diffuse notre position aux autres que sur nos 0xA9 ; le client
## d origine en envoie meme immobile. Sans ce battement, le GM nous voyait
## DISPARAITRE des qu on se figeait en combat et reapparaitre au premier
## mouvement (mesure le 2026-09-22). 0 = jamais (comportement d avant).
@export_range(0.0, 10.0, 0.1) var online_idle_position_keepalive_sec: float = 1.0
var _online_idle_clock := 0.0
## Apparitions appliquees par trame quand le flux serveur arrive : une scene
## DAoC complete par apparition, un budget large fige la trame.
@export_range(1, 32, 1) var online_stream_events_per_frame: int = 3
## Le serveur simule deja le personnage pendant la construction de zone. Ce
## profil rend d'abord le terrain et l'interface jouables ; le decor lourd ne
## bloque plus plusieurs secondes avant l'apparition des creatures proches.
@export var online_fast_start: bool = false
## Le monde local utilisait jusqu'ici le chemin complet alors que le serveur
## profitait du profil de demarrage allege. Active par defaut la meme parite.
@export var offline_fast_start: bool = true
## Apres PlayerInit, les 0xDA/0xD9 arrivent encore pendant plusieurs secondes.
## L'ecran de chargement attend leur application plutot que de livrer un monde
## ou les structures existent mais les creatures apparaissent apres le joueur.
@export_range(0.0, 10.0, 0.1) var online_world_settle_min_sec: float = 1.0
@export_range(0.1, 5.0, 0.1) var online_world_settle_quiet_sec: float = 0.6
@export_range(1.0, 30.0, 0.5) var online_world_settle_timeout_sec: float = 12.0
var _online_last_entity_event_msec := 0


## Le frontend confie son runtime Online AVANT start_game_from_pregame ; sans
## lui la partie en ligne retombe sur un monde vide et le dit.
func attach_online_runtime(runtime: Node) -> void:
	_online_runtime = runtime


## B2 — le peuplement en ligne commence VIDE et se remplit au fil des paquets,
## par la meme porte que la capture (population.spawn_one via R2).
func mount_online_population() -> Dictionary:
	if session == null:
		return {"ok": false, "reason": "session absente"}
	if _population != null:
		return {"ok": true, "reason": "deja peuple"}
	if not _state.zone_runtime.has(current_zone):
		return {"ok": false, "reason": "aucune zone habitee"}
	_population = DaocGothwaitePopulationScript.new()
	var settings := population_settings_r9()
	settings["zone"] = current_zone
	var origin := _origin(current_zone)
	settings["world_origin_x"] = origin.x
	settings["world_origin_y"] = origin.y
	settings["stream_player"] = _online_player_entity()
	var opened: Dictionary = _population.call("begin_stream", self, POPULATION_MANIFEST_PATH, settings) as Dictionary
	_population_report = opened.duplicate(true)
	_population_report["mode"] = "ONLINE_STREAM"
	# « Precache Skins » : toutes les scenes du manifeste sont chargees pendant
	# l'ecran de chargement, pour qu'aucune apparition ne paye le disque.
	if _population.has_method("precache_scenes"):
		_population_report["precache"] = _population.call("precache_scenes")
	session.entity_population = _population
	_online_stream = DaocEntityStreamRuntime.new()
	_online_stream.name = "OnlineEntityStream"
	session.entity_stream = _online_stream
	session.add_child(_online_stream)
	_online_stream.setup(self, _population, [])
	_online_stream.events_per_frame = online_stream_events_per_frame
	# Le budget par trame ne compte que les apparitions : un 0xA1 est appliqué
	# des sa trame, sinon la file diverge face au flux continu du serveur.
	_online_stream.free_moves = true
	# Le combat est deja arbitre par le serveur ; l'arbitre prend la position du
	# paquet tout de suite. Le visuel, lui, marche vers la DESTINATION du 0xA1
	# a la vitesse du paquet (dead reckoning, comme le client d'origine) et se
	# recale sur la position du paquet quand il a derive. L'ancienne
	# interpolation visait la position du paquet, deja depassee : le PNJ trainait
	# loin derriere puis sautait, d'ou son arret du 2026-09-15.
	_online_stream.smooth_moves = true
	if _online_runtime != null and _online_runtime.has_signal("world_entity_event"):
		_online_runtime.world_entity_event.connect(_on_online_entity_event)
		# Les paquets recus AVANT le montage (entre PLAYING et la fin de la
		# construction de zone) sont rejoues depuis le modele du monde.
		var snapshot: Dictionary = _online_runtime.call("world_snapshot") as Dictionary
		var replay_entities: Array = (snapshot.get("entities", []) as Array).duplicate(true)
		replay_entities.sort_custom(_online_entity_priority_less)
		for value in replay_entities:
			if value is Dictionary and int((value as Dictionary).get("object_id", -1)) > 0:
				# Cette liste est deja triee proche -> loin. La reinsertion prioritaire
				# de _on_online_entity_event inverserait tous les PNJ et repousserait
				# le rat au contact derriere les creatures lointaines.
				_online_events_received += 1
				_online_last_entity_event_msec = Time.get_ticks_msec()
				_online_stream.events.append({"kind": DaocWorldEntityStream.KIND_SPAWN,
					"object_id": int((value as Dictionary).get("object_id", -1)),
					"entity": (value as Dictionary).duplicate(true), "replayed": true})
		_population_report["online_runtime"] = "attached"
	else:
		_population_report["online_runtime"] = "ABSENT : aucun flux serveur, monde vide"
	return _population_report.duplicate(true)


func _on_online_entity_event(event: Dictionary) -> void:
	if _online_stream == null:
		return
	var object_id := int(event.get("object_id", -1))
	# Le joueur lui-meme est dans le flux serveur ; c'est la capsule R7 qui le
	# porte, pas le peuplement.
	if object_id == _online_player_object_id():
		return
	_online_events_received += 1
	_online_last_entity_event_msec = Time.get_ticks_msec()
	var queued := event.duplicate(true)
	var entity := queued.get("entity", {}) as Dictionary
	# P1-94 : un 0x4B (autre joueur) porte des coordonnees LOCALES a sa zone,
	# jamais de position monde. On la resout ici par l'origine de la zone
	# annoncee, comme un 0xA1 ; une zone inconnue laisse x/y nuls et l'entite
	# reste dans l'arbitre sans noeud (visible dans le rapport, pas a l'ecran).
	if str(queued.get("kind", "")) == DaocWorldEntityStream.KIND_SPAWN and entity.get("x") == null and entity.has("zone_x"):
		var skin := int(entity.get("zone_skin_id", current_zone))
		var origin := _origin(skin if skin > 0 else current_zone)
		if origin != Vector2.ZERO or skin == current_zone:
			entity["x"] = int(origin.x) + int(entity.get("zone_x", 0))
			entity["y"] = int(origin.y) + int(entity.get("zone_y", 0))
			entity["z"] = int(entity.get("zone_z", entity.get("z", 0)))
			entity["position_source"] = "0x4B_zone_local_resolved"
		queued["entity"] = entity
	# P1-112 : en 1.124+ le 0x4B porte des flottants REGION (mesure), le
	# decodeur rend x/y/z directement et la branche locale ci-dessus ne sert
	# plus qu a une disposition 172. Le rapport de parite garde chaque joueur.
	if str(queued.get("kind", "")) == DaocWorldEntityStream.KIND_SPAWN and str(entity.get("entity_type", "")) == "player":
		_record_online_player_create(entity)
	# P1-115 : un objet porte (0xD9, object_kind 4) garde son identifiant de porte.
	if str(queued.get("kind", "")) == DaocWorldEntityStream.KIND_SPAWN:
		_note_online_door_object(entity)
	# Une creature proche peut deja infliger des degats cote serveur. Elle passe
	# avant les objets de decor encore en attente afin d'etre visible au joueur.
	if str(queued.get("kind", "")) == DaocWorldEntityStream.KIND_SPAWN and str(entity.get("entity_type", "")) == "npc":
		_online_stream.events.insert(_online_stream.cursor, queued)
	else:
		_online_stream.events.append(queued)


## Attend que le flux initial du serveur ait ete applique au monde. Le timeout
## protege les serveurs qui diffusent en continu des mises a jour de position.
func wait_for_online_world_settled() -> Dictionary:
	var started := Time.get_ticks_msec()
	var minimum_msec := int(online_world_settle_min_sec * 1000.0)
	var quiet_msec := int(online_world_settle_quiet_sec * 1000.0)
	var timeout_msec := int(online_world_settle_timeout_sec * 1000.0)
	while Time.get_ticks_msec() - started < timeout_msec:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		var pending := 0
		if _online_stream != null:
			pending = maxi(0, _online_stream.events.size() - _online_stream.cursor)
		var quiet_for := now - _online_last_entity_event_msec if _online_last_entity_event_msec > 0 else now - started
		if now - started >= minimum_msec and pending == 0 and quiet_for >= quiet_msec:
			return {"ok": true, "timed_out": false, "pending": 0,
				"waited_msec": now - started, "events_received": _online_events_received}
	var remaining := 0
	if _online_stream != null:
		remaining = maxi(0, _online_stream.events.size() - _online_stream.cursor)
	return {"ok": true, "timed_out": true, "pending": remaining,
		"waited_msec": Time.get_ticks_msec() - started, "events_received": _online_events_received}


func _online_entity_priority_less(a_value: Variant, b_value: Variant) -> bool:
	var a := a_value as Dictionary
	var b := b_value as Dictionary
	var a_kind := 0 if str(a.get("entity_type", "")) == "npc" else (1 if str(a.get("entity_type", "")) == "player" else 2)
	var b_kind := 0 if str(b.get("entity_type", "")) == "npc" else (1 if str(b.get("entity_type", "")) == "player" else 2)
	if a_kind != b_kind:
		return a_kind < b_kind
	return float(a.get("distance_horizontal", INF)) < float(b.get("distance_horizontal", INF))


## R3 pour le flux serveur : chaque apparition / deplacement applique au monde
## entre dans l'arbitre miroir, qui tient noms, niveaux et positions pour le
## ciblage et l'interface.
func _bind_online_stream_to_authority() -> void:
	if _online_stream == null or _local_server == null:
		return
	var receiver := Callable(self, "_on_online_entity_applied")
	if not _online_stream.entity_event_applied.is_connected(receiver):
		_online_stream.entity_event_applied.connect(receiver)
	# Le ciblage ne doit pas attendre l'instanciation graphique. Le serveur a
	# deja donne l'identite et la position des PNJ : on les inscrit tout de suite
	# dans l'autorite miroir, puis l'evenement visuel attachera leur noeud. Ainsi
	# Tab peut prendre le rat au contact meme si son modele finit de se charger.
	for index in range(_online_stream.cursor, _online_stream.events.size()):
		var pending_event := _online_stream.events[index] as Dictionary
		if str(pending_event.get("kind", "")) != DaocWorldEntityStream.KIND_SPAWN:
			continue
		var pending_entity: Variant = pending_event.get("entity", {})
		if pending_entity is Dictionary:
			_local_server.spawn_stream_entity(pending_entity as Dictionary, null)


func _on_online_entity_applied(event: Dictionary, _outcome: Dictionary) -> void:
	if _local_server == null:
		return
	var object_id := int(event.get("object_id", -1))
	match str(event.get("kind", "")):
		DaocWorldEntityStream.KIND_SPAWN:
			var entity_value: Variant = event.get("entity", {})
			if not entity_value is Dictionary:
				return
			var node: Node3D = null
			if _population != null and _population.has_method("wrapper_of"):
				node = _population.call("wrapper_of", object_id) as Node3D
			_local_server.spawn_stream_entity(entity_value as Dictionary, node)
		DaocWorldEntityStream.KIND_MOVE:
			var origin := _population_world_origin()
			_local_server.move_stream_entity(object_id, Vector3(
				origin.x + float(event.get("zone_x", 0.0)),
				origin.y + float(event.get("zone_y", 0.0)),
				float(event.get("zone_z", 0.0))))
			if event.has("health_percent"):
				_local_server.apply_remote_entity_health_percent(object_id, int(event.get("health_percent", 100)))
		DaocWorldEntityStream.KIND_DESPAWN:
			_local_server.despawn_stream_entity(object_id, "online_stream")


func _population_world_origin() -> Vector2:
	if online_mode and current_zone >= 0:
		return _origin(current_zone)
	return Vector2(POPULATION_SETTINGS["world_origin_x"], POPULATION_SETTINGS["world_origin_y"])


func _online_player_object_id() -> int:
	var position: Dictionary = _online_character.get("online_position", {}) as Dictionary
	return int(position.get("object_id", -1))


## L'entite joueur de l'arbitre miroir, dans la forme de la capture P1-20E :
## object_id et position du 0x88, nom et niveau du CharacterOverview.
func _online_player_entity() -> Dictionary:
	var position: Dictionary = _online_character.get("online_position", {}) as Dictionary
	return {
		"object_id": _online_player_object_id(),
		"entity_type": "player",
		"name": str(_online_character.get("name", "")),
		"level": int(_online_character.get("level", 0)),
		"model_id": -1,
		"x": float(position.get("x", 0.0)),
		"y": float(position.get("y", 0.0)),
		"z": float(position.get("z", 0.0)),
		"heading": int(position.get("heading", 0)),
		"realm": int(_online_character.get("realm_id", 1)),
		"peaceful": true,
	}


## B3 — la position du moteur part vers le serveur a cadence fixe. Le serveur
## ne renvoie les jauges que d'un joueur qui existe pour lui : sans ce tic il
## reste a la position du 0x88 pour toujours.
func _tick_online_movement(delta: float) -> void:
	if not online_mode or _online_runtime == null or session == null or session.player == null:
		return
	_online_move_clock += maxf(delta, 0.0)
	if _online_move_clock < online_movement_send_interval_sec:
		return
	_online_move_clock = 0.0
	var motor: Node = session.player
	if not ("daoc_x" in motor):
		return
	var motor_zone := int(motor.get("daoc_zone"))
	var origin := _origin(motor_zone if motor_zone >= 0 else current_zone)
	var position: Dictionary = _online_character.get("online_position", {}) as Dictionary
	var heading_deg := float(motor.get("heading_deg"))
	var packet_position := {
		"x": origin.x + float(motor.get("daoc_x")),
		"y": origin.y + float(motor.get("daoc_y")),
		"z": float(motor.get("daoc_z")),
		# last_speed_raw est l'allure disponible (course/marche), pas la vitesse
		# effectivement appliquee. A l'arret elle reste donc non nulle. Envoyer
		# cette valeur brute fait croire au serveur que le joueur bouge et il
		# interrompt tous les sorts incantes.
		"speed": float(motor.get("last_speed_raw")) * (motor.get("last_move_vector") as Vector2).length(),
		"z_speed": float(motor.get("vertical_velocity_raw")),
		"region_id": int(position.get("region_id", 0)),
		"heading": DaocHeadingScript.motor_deg_to_raw(heading_deg),
		"health": 100, "mana": 0, "endurance": 100,
	}
	var idle := not _online_last_sent.is_empty() and _same_position(packet_position, _online_last_sent) and float(packet_position["speed"]) == 0.0
	if idle:
		_online_idle_clock += online_movement_send_interval_sec
		if online_idle_position_keepalive_sec <= 0.0 or _online_idle_clock < online_idle_position_keepalive_sec:
			return
	_online_idle_clock = 0.0
	var result: Dictionary = _online_runtime.call("send_player_movement", packet_position) as Dictionary
	if bool(result.get("ok", false)):
		_online_move_sent += 1
		_online_last_sent = packet_position
	else:
		_online_move_refused += 1
		_online_last_move_error = str(result.get("error", ""))


static func _same_position(a: Dictionary, b: Dictionary) -> bool:
	return is_equal_approx(float(a.get("x", 0.0)), float(b.get("x", 0.0))) \
		and is_equal_approx(float(a.get("y", 0.0)), float(b.get("y", 0.0))) \
		and int(a.get("heading", 0)) == int(b.get("heading", 0))


## B5 — les jauges (0xAD) et le texte (0xAF) du serveur atteignent l'ecran.
## Les jauges passent par l'arbitre miroir (apply_remote_player_status) pour
## que le pont d'interface continue de ne lire que snapshot() ; le texte va
## dans les deux fenetres de texte du client.
var _online_status_updates := 0
var _online_messages := 0
var _online_last_health := -1


func _bind_online_status_and_text() -> void:
	if _online_runtime == null:
		return
	if _online_runtime.has_signal("player_status_received"):
		var receiver := Callable(self, "_on_online_player_status")
		if not _online_runtime.player_status_received.is_connected(receiver):
			_online_runtime.player_status_received.connect(receiver)
		# Le dernier 0xAD est souvent arrive pendant la construction de zone.
		if _online_runtime.has_method("last_player_status"):
			var last: Dictionary = _online_runtime.call("last_player_status") as Dictionary
			if not last.is_empty():
				_on_online_player_status(last)
	if _online_runtime.has_signal("server_message_received"):
		var receiver_text := Callable(self, "_on_online_server_message")
		if not _online_runtime.server_message_received.is_connected(receiver_text):
			_online_runtime.server_message_received.connect(receiver_text)
	if _online_runtime.has_signal("player_quit_received"):
		var receiver_quit := Callable(self, "_on_online_player_quit")
		if not _online_runtime.player_quit_received.is_connected(receiver_quit):
			_online_runtime.player_quit_received.connect(receiver_quit)
	# P1-78 — progression, dialogues PNJ, mort, journal de quetes.
	for pair in [["player_points_received", "_on_online_player_points"], ["dialog_received", "_on_online_dialog"],
			["player_died_received", "_on_online_player_died"], ["quest_entry_received", "_on_online_quest_entry"],
			["player_revived", "_on_online_player_revived"], ["effects_received", "_on_online_effects"],
			["detail_window_received", "_on_online_detail_window"], ["group_changed", "_on_online_group"],
			["friends_changed", "_on_online_friends"], ["emote_received", "_on_online_emote"],
			["character_stats_received", "_on_online_character_stats"], ["character_resists_received", "_on_online_character_resists"],
			["weapon_armor_received", "_on_online_weapon_armor"], ["trainer_window_received", "_on_online_trainer_window"],
			["concentration_received", "_on_online_concentration"], ["skills_disabled", "_on_online_skills_disabled"],
			["pet_window_received", "_on_online_pet_window"]]:
		if _online_runtime.has_signal(str(pair[0])):
			var receiver_p78 := Callable(self, str(pair[1]))
			if not _online_runtime.is_connected(str(pair[0]), receiver_p78):
				_online_runtime.connect(str(pair[0]), receiver_p78)
	if _online_runtime.has_method("last_player_points"):
		var last_points: Dictionary = _online_runtime.call("last_player_points") as Dictionary
		if not last_points.is_empty():
			_on_online_player_points(last_points)
	if _online_runtime.has_method("last_effects"):
		var last_effects: Array = _online_runtime.call("last_effects") as Array
		if not last_effects.is_empty():
			_on_online_effects(last_effects)
	for pair in [["last_character_stats", "_on_online_character_stats"], ["last_character_resists", "_on_online_character_resists"], ["last_weapon_armor", "_on_online_weapon_armor"]]:
		if _online_runtime.has_method(str(pair[0])):
			var last: Dictionary = _online_runtime.call(str(pair[0])) as Dictionary
			if not last.is_empty():
				call(str(pair[1]), last)
	_bind_online_environment()


## P1-94 — l'heure et la meteo viennent du SERVEUR (0x7E, 0x92). Avant, la scene
## Online restait sur `environment_time_hours` local : le GM voyait le jour et
## nous la nuit. `set_daoc_server_time_seconds` existait depuis P1-20K sans
## appelant en ligne.
var _online_time_updates := 0
var _online_weather_updates := 0
var _online_player_creates: Array = []
const ONLINE_PARITY_PACKETS_REPORT := "res://reports/online/last_parity_packets.json"


func _bind_online_environment() -> void:
	if _online_runtime == null:
		return
	if _online_runtime.has_signal("server_time_received"):
		var receiver_time := Callable(self, "_on_online_server_time")
		if not _online_runtime.server_time_received.is_connected(receiver_time):
			_online_runtime.server_time_received.connect(receiver_time)
		# Le 0x7E arrive a l'entree monde, donc AVANT le montage de la scene :
		# le dernier recu est rejoue.
		if _online_runtime.has_method("last_server_time"):
			var last_time: Dictionary = _online_runtime.call("last_server_time") as Dictionary
			if not last_time.is_empty():
				_on_online_server_time(last_time)
	if _online_runtime.has_signal("weather_received"):
		var receiver_weather := Callable(self, "_on_online_weather")
		if not _online_runtime.weather_received.is_connected(receiver_weather):
			_online_runtime.weather_received.connect(receiver_weather)
		if _online_runtime.has_method("last_weather"):
			var last_weather: Dictionary = _online_runtime.call("last_weather") as Dictionary
			if not last_weather.is_empty():
				_on_online_weather(last_weather)


func _on_online_server_time(time: Dictionary) -> void:
	if _environment_controller == null or not bool(time.get("ok", false)):
		return
	_online_time_updates += 1
	_environment_controller.call("set_server_time_authority",
		int(time.get("server_time_seconds", 0)), int(time.get("day_increment", 0)))
	_environment_report["time_authority"] = "SERVER_0x7E"
	_environment_report["server_time_hours"] = float(time.get("time_hours", 0.0))
	_environment_report["server_day_increment"] = int(time.get("day_increment", 0))
	_write_online_parity_report()


func _on_online_weather(weather: Dictionary) -> void:
	if _environment_controller == null or not bool(weather.get("ok", false)):
		return
	_online_weather_updates += 1
	var raw := weather.get("raw", {}) as Dictionary
	# Le serveur ne dit pas pluie ou neige : le controleur garde son indice
	# UNKNOWN, comme P1-20K l'a laisse tant que le classement n'est pas prouve.
	set_daoc_weather_front(raw, 0)
	_environment_report["weather_authority"] = "SERVER_0x92"
	_environment_report["weather_front_raw"] = raw.duplicate(true)
	_write_online_parity_report()


func _record_online_player_create(entity: Dictionary) -> void:
	_online_player_creates.append({
		"object_id": int(entity.get("object_id", -1)), "name": str(entity.get("name", "")),
		"model_id": int(entity.get("model_id", 0)), "level": int(entity.get("level", 0)),
		"zone_skin_id": int(entity.get("zone_skin_id", 0)), "zone_x": int(entity.get("zone_x", 0)),
		"zone_y": int(entity.get("zone_y", 0)), "x": entity.get("x"), "y": entity.get("y"), "z": entity.get("z"),
		"guild_name": str(entity.get("guild_name", "")), "realm": int(entity.get("realm", 0)),
		"position_source": str(entity.get("position_source", "unresolved_zone")),
	})
	_write_online_parity_report()


func online_parity_summary() -> Dictionary:
	return {"time_updates": _online_time_updates, "weather_updates": _online_weather_updates,
		"player_creates": _online_player_creates.duplicate(true)}


## Les paquets bruts 0x4B / 0x7E / 0x92 en hexadecimal, avec ce que le decodeur
## en fait : c'est ce fichier qui confirmera (ou non) la disposition ASSUMEE
## du 0x4B contre un vrai paquet d'Eden.
func _write_online_parity_report() -> void:
	if _online_runtime == null or not _online_runtime.has_method("parity_packet_log"):
		return
	var report := {
		"written": Time.get_datetime_string_from_system(),
		"character": str(_online_character.get("name", "")),
		"packets": _online_runtime.call("parity_packet_log"),
		"player_creates_applied": _online_player_creates,
		"environment": _environment_report.duplicate(true),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/online"))
	var file := FileAccess.open(ONLINE_PARITY_PACKETS_REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))


func _on_online_player_status(status: Dictionary) -> void:
	if _local_server == null:
		return
	var applied: Dictionary = _local_server.apply_remote_player_status(status)
	if bool(applied.get("ok", false)):
		_online_status_updates += 1
		# P1-87 — la posture assise vient du serveur (u8 sitting) ; un /sit local a
		# 2 s de grace avant qu'un 0xAD anterieur ne le releve.
		if status.has("sitting"):
			var server_sitting := bool(status.get("sitting", false))
			if server_sitting != is_player_sitting() and (server_sitting or Time.get_ticks_msec() - _sit_requested_msec > 2000):
				set_player_sitting(server_sitting, false)
		var health := int(status.get("health", -1))
		if health >= 0:
			if health == 0 and _online_last_health != 0:
				_play_online_player_persistent_animation("death")
			elif health > 0 and _online_last_health == 0:
				_clear_online_player_persistent_animation()
			elif _online_last_health > health and health > 0:
				_play_online_player_animation(["flinch"])
			_online_last_health = health
		if _daoc_ui_bridge != null:
			_daoc_ui_bridge.push_player()
		if _combat_hud != null:
			_combat_hud.update_player(_local_server.snapshot(_local_server.player_object_id))


func _on_online_server_message(message: Dictionary) -> void:
	_online_messages += 1
	if _text_windows != null:
		_text_windows.push_message(message)


## ═══════════════════════════════════════════════════════════════════════════
## P1-97 — LA MORT IMMOBILISE ET FAIT TAIRE
##
## Client d'origine (game.dll decompile, `DAT_00d91490 + 0x60`) : le drapeau
## « mort » est pose a la mort du joueur (0xAE), leve a la resurrection
## (0x89 PlayerRevive), et douze gardes le lisent — mode combat (« You can't
## enter combat mode while dead! »), usage de raccourci, ciblage, mouvement,
## parole. Le serveur DOL refuse aussi le /say d'un mort ; le groupe et /tell
## restent permis (constat utilisateur). Ici : le moteur ignore toute entree
## (`movement_locked`), et les commandes de parole publique sont retenues.
## ═══════════════════════════════════════════════════════════════════════════
var player_dead: bool = false
const DEAD_MESSAGE := "Vous ne pouvez pas parler en etant mort."
const DEAD_BLOCKED_VERBS := ["/say", "/s", "/yell", "/y", "/emote", "/em", "/e", "/me", "/attack", "/stick", "/face", "/follow", "/sprint"]


func set_player_dead(value: bool, reason: String = "") -> void:
	if player_dead == value:
		return
	player_dead = value
	if session != null and session.player != null and "movement_locked" in session.player:
		session.player.set("movement_locked", value)
	if session != null and session.input_router != null and session.input_router.has_method("runlock_disable") and value:
		session.input_router.call("runlock_disable")
	_environment_report["player_dead"] = value
	if _text_windows != null and value and reason != "":
		_text_windows.push_console_line(reason)


func is_player_dead() -> bool:
	return player_dead


## Une commande qu'un mort peut envoyer : tout ce qui n'est pas de la parole
## publique. Le texte nu est un /say.
func command_allowed_while_dead(command: String) -> bool:
	var trimmed := command.strip_edges()
	if not trimmed.begins_with("/"):
		return false
	var verb := trimmed.to_lower().get_slice(" ", 0)
	# Parole publique et emotes : refusees. Groupe, guilde, /tell, /release, /quit... : permis.
	return not (verb in DEAD_BLOCKED_VERBS)

func _on_text_command_submitted(command: String) -> void:
	# P1-97 : mort, la parole publique est retenue.
	if player_dead and not command_allowed_while_dead(command):
		if _text_windows != null:
			_text_windows.push_console_line(DEAD_MESSAGE)
		return
	# P1-87 — /sit, /stand, /quit : la posture se joue ici, le serveur la confirme par 0xAD.
	var verb := command.strip_edges().to_lower().get_slice(" ", 0)
	# P1-105 : /macro <nom> <commande> vit dans le client (DOL ne le connait pas).
	if verb == "/macro":
		_define_macro_from_command(command)
		return
	# P1-107 : /train sans argument ouvre la fenetre (0x7B) ; /train <ligne> <niveau> part tel quel.
	if verb == "/train" and command.strip_edges().split(" ", false).size() == 1:
		request_trainer_window()
		return
	# P1-109 : /face /stick /follow /gt /bonuses /ml /siege sont des gestes client ; P1-110 : /journal /pickup /lfgflag /lfglist /emblem.
	if _handle_client_only_command_p1_110(command):
		return
	if verb == "/map":
		_tick_minimap(true)
		if _minimap != null:
			_minimap.toggle()
		return
	# 2026-09-30 : /shownames et /hidenames (&shownames de game.dll) vivent dans le client.
	if verb == "/shownames" or verb == "/hidenames":
		_tick_nameplates()
		if _nameplates != null and _text_windows != null:
			_text_windows.push_console_line(_nameplates.handle_command(command))
		return
	# 2026-09-27 : /options ouvre les options graphiques.
	if verb == "/options":
		toggle_graphics_options()
		return
	# P1-125 : /ra <capacite> active une capacite de royaume hors ligne.
	if verb == "/ra" and not online_mode:
		use_offline_realm_ability(command.strip_edges().substr(3).strip_edges())
		return
	# P1-122 : /craft ouvre la fenetre d artisanat (&craft du client d origine).
	if verb == "/craft":
		toggle_craft_window()
		return
	# P1-121 : /use et /use2 sont traites par le client d origine (&use) -> 0x71.
	if _handle_use_command_p1_121(command):
		return
	# P1-114 : /appraise et /shop sont des raccourcis du client ; /sell, /repair,
	# /salvage et /discard sont des commandes DOL et passent telles quelles.
	if _handle_client_only_command_p1_114(command):
		return
	if _handle_client_only_command(command):
		return
	if verb == "/sit":
		set_player_sitting(not is_player_sitting())
	elif verb == "/stand":
		set_player_sitting(false)
	elif verb == "/quit":
		set_player_sitting(true)
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_command"):
		if _text_windows != null:
			_text_windows.push_console_line("Commande serveur indisponible hors ligne.")
		return
	var result: Dictionary = _online_runtime.call("send_command", command) as Dictionary
	if bool(result.get("ok", false)):
		_text_windows.push_console_line("-> %s" % command)
	else:
		_text_windows.push_console_line("Commande non envoyee : %s" % str(result.get("error", "?")))


func _play_online_player_animation(candidates: Array) -> bool:
	if _combat_client == null or not _combat_client.has_method("_play_first_available"):
		return false
	return bool(_combat_client.call("_play_first_available", candidates))


func _play_online_player_persistent_animation(clip_name: String) -> bool:
	if _combat_client == null or not _combat_client.has_method("_resolve_player_visual"):
		return false
	var visual: Node = _combat_client.call("_resolve_player_visual") as Node
	return visual != null and visual.has_method("play_persistent") and bool(visual.call("play_persistent", clip_name))


func _clear_online_player_persistent_animation() -> void:
	if _combat_client == null or not _combat_client.has_method("_resolve_player_visual"):
		return
	var visual: Node = _combat_client.call("_resolve_player_visual") as Node
	if visual != null and visual.has_method("clear_persistent_pose"):
		visual.call("clear_persistent_pose")



## B6 — le livre de sorts vient du SERVEUR (0x16/0x02) et les intentions y
## repartent : 0x7D UseSpell (niveau, index de ligne), 0xB0 cible, 0x74 combat.
## Rien n'est arbitre ici ; le miroir tient les etats, le serveur decide, et ses
## reponses reviennent par 0xAF (console) et 0xAD (jauges).
var _online_spell_lines: Array = []
var _online_skills_sent := 0
var _online_casts_sent := 0
var _online_targets_sent := 0
var _online_attacks_sent := 0


func _bind_online_combat() -> void:
	if _online_runtime == null:
		return
	if _online_runtime.has_signal("spell_lines_received"):
		var receiver := Callable(self, "_on_online_spell_lines")
		if not _online_runtime.spell_lines_received.is_connected(receiver):
			_online_runtime.spell_lines_received.connect(receiver)
		if _online_runtime.has_method("spell_lines"):
			var already: Array = _online_runtime.call("spell_lines") as Array
			if not already.is_empty():
				_on_online_spell_lines(already)
	# P1-79 — styles et capacites du serveur (0x16/0x01), lances par 0xBB.
	if _online_runtime.has_signal("skills_received"):
		var receiver_skills := Callable(self, "_on_online_skills")
		if not _online_runtime.skills_received.is_connected(receiver_skills):
			_online_runtime.skills_received.connect(receiver_skills)
		if _online_runtime.has_method("skills"):
			var already_skills: Array = _online_runtime.call("skills") as Array
			if not already_skills.is_empty():
				_on_online_skills(already_skills)
	# P1-82 / P1-83 — Sprint par la touche ou par la fenetre des capacites ;
	# metiers ; vitesse dictee par 0xB6.
	if _online_runtime.has_signal("crafting_skills_received"):
		var receiver_craft := Callable(self, "_on_online_crafting_skills")
		if not _online_runtime.crafting_skills_received.is_connected(receiver_craft):
			_online_runtime.crafting_skills_received.connect(receiver_craft)
		if _online_runtime.has_method("crafting_skills"):
			var already_craft: Array = _online_runtime.call("crafting_skills") as Array
			if not already_craft.is_empty():
				_on_online_crafting_skills(already_craft)
	if _online_runtime.has_signal("max_speed_received"):
		var receiver_speed := Callable(self, "_on_online_max_speed")
		if not _online_runtime.max_speed_received.is_connected(receiver_speed):
			_online_runtime.max_speed_received.connect(receiver_speed)
		var last_speed: Dictionary = {}
		if _online_runtime.has_method("last_max_speed"):
			last_speed = _online_runtime.call("last_max_speed") as Dictionary
		# Avant le premier 0xB6, l'allure hors combat (125 %) : le sprint local
		# de la touche ne doit plus s'appliquer en ligne.
		_on_online_max_speed(last_speed if not last_speed.is_empty() else {"ok": true, "percent": 125, "implicit": true})
	if session != null and session.input_router != null and session.input_router.has_signal("sprint_requested"):
		var receiver_sprint := Callable(self, "_on_sprint_key")
		if not session.input_router.sprint_requested.is_connected(receiver_sprint):
			session.input_router.sprint_requested.connect(receiver_sprint)
	if _quickbars != null:
		_quickbars.online_caster = Callable(self, "_online_cast")
		_quickbars.console_target = _text_windows
	if _local_server != null:
		_local_server.remote_attack_callback = Callable(self, "_online_attack")
	if _combat_client != null:
		var target_receiver := Callable(self, "_on_online_target_changed")
		if not _combat_client.target_changed.is_connected(target_receiver):
			_combat_client.target_changed.connect(target_receiver)


## Le grimoire en ligne = la liste du serveur, avec SES icones et l'adresse
## (ligne, niveau) que UseSpell attend. Les sorts calcules localement par le
## metier sont remplaces : le serveur sait mieux que nous ce qu'elle connait.
func _on_online_spell_lines(lines: Array) -> void:
	_online_spell_lines = lines.duplicate(true)
	var spells: Array = []
	for line_value in lines:
		var line := line_value as Dictionary
		var entries_in_line: Array = line.get("entries", []) as Array
		for spell_index in range(entries_in_line.size()):
			var entry := entries_in_line[spell_index] as Dictionary
			if str(entry.get("kind", "")) != "spell":
				continue
			spells.append({
				"kind": "spell",
				# P1-108 : la position dans la ligne est l index que 0xD6 DisableSkills nomme.
				"online_spell_index": spell_index,
				"disable_key": "spell:%d:%d" % [int(line.get("line_index", 0)), spell_index],
				"spell_id": int(entry.get("internal_id", 0)),
				"name": str(entry.get("name", "")),
				"line": str(line.get("line_name", "")),
				"required_level": int(entry.get("level", 0)),
				"icon": int(entry.get("icon", 0)),
				"online_line_index": int(line.get("line_index", 0)),
				"online_level": int(entry.get("level", 0)),
				"source": "SERVER_0x16",
			})
	_online_spell_entries = spells
	_publish_online_book()
	if _text_windows != null:
		_text_windows.push_console_line("Livre de sorts du serveur : %d sorts sur %d lignes." % [spells.size(), lines.size()])
	_write_online_skill_packets_report()


var _online_spell_entries: Array = []
var _online_skill_entries: Array = []


## P1-79 — styles et capacites : la meme grille que les sorts, avec l'icone du
## serveur. L'identifiant `spell_id` = InternalID de la competence (unique
## dans la table Skill de DOL), la « ligne » nomme la source pour que le
## glisser-deposer et la sauvegarde de barre distinguent sort et competence.
func _on_online_skills(skills: Array) -> void:
	var entries: Array = []
	_online_all_skills = skills.duplicate(true)
	# P1-108 : l index que 0xD6 DisableSkills nomme pour une competence est
	# compte HORS specialisations — la regle de `send_use_skill`.
	var first_non_spec := 0
	for value in skills:
		if int((value as Dictionary).get("skill_type", 0)) == 0:
			first_non_spec += 1
		else:
			break
	for value in skills:
		var skill := value as Dictionary
		var kind := str(skill.get("kind", ""))
		# P1-128 : "spell" aussi — un HYBRIDE (Friar, Paladin, Minstrel…) recoit ses
		# sorts DANS cette liste (skill_type 3, mesure en live sur Vcx le 28/09 :
		# 13 sorts, 0x16/02 vide). Ils etaient jetes : ni grimoire ni barre.
		# Lances comme un style : 0xBB UseSkill (index hors specs, type 3).
		# 2026-09-29 : une SPE cliquable (DOL : seule Stealth a un ISpecActionHandler)
		# est utilisable comme une capacite ; 0xBB de type 0 a son index de spe.
		var spec_action := kind == "specialization" and SPEC_ACTION_NAMES.has(str(skill.get("name", "")))
		if not spec_action and not ["style", "ability", "song", "realm_ability", "ability_spell", "spell"].has(kind):
			continue
		entries.append({
			"kind": "spell",
			"disable_key": ("spec:%d" % int(skill.get("index", 0))) if spec_action else "skill:%d" % (int(skill.get("index", 0)) - first_non_spec),
			"skill_kind": kind,
			"spell_id": int(skill.get("internal_id", 0)),
			"name": str(skill.get("name", "")),
			"line": "SERVER_SKILLS_%s" % kind,
			"display_line": preload("res://src/daoc/network/opendaoc/DaocOpenDaocSkillListCodec.gd").display_group(skill, skills),
			"required_level": int(skill.get("level", 0)),
			"icon": int(skill.get("icon", 0)),
			"icon_family": DaocSpellIconAtlas.family_for_kind(kind),
			"online_skill": skill.duplicate(true),
			"source": "SERVER_0x16_SKILLS",
		})
	_online_skill_entries = entries
	_publish_online_book()
	_publish_online_skill_window()
	_write_online_skill_packets_report()
	if _text_windows != null:
		_text_windows.push_console_line("Competences du serveur : %d entrees, %d styles / capacites utilisables." % [skills.size(), entries.size()])


## P1-82 / P1-83 — la fenetre « Specializations / Abilities / Tradeskills »
## (`stats_spec_abil.xml`) : trois listes et le compteur de points publies sur
## le bus XML. Les specialisations s'affichent `Nom  niveau+bonus` en vert
## (ColorHighlit du gabarit), les capacites se GLISSENT vers les quickbars (P1-84 :
## dans DAoC tout passe par la barre) — Sprint est une capacite, pas un sort,
## et vit ici et non dans le grimoire.
var _online_all_skills: Array = []
var _online_crafting: Array = []
var _online_speed: Dictionary = {}
var _online_sprinting := false
var _online_sprints_sent := 0
var _online_speed_updates := 0


func _publish_online_skill_window() -> void:
	if _daoc_ui_bus == null:
		return
	var specs: Array = []
	var abilities: Array = []
	var ability_groups: Dictionary = {}
	for value in _online_all_skills:
		var skill := value as Dictionary
		var kind := str(skill.get("kind", ""))
		var name := str(skill.get("name", ""))
		if kind == "specialization":
			var bonus := int(skill.get("bonus", 0))
			specs.append({"text": "%s  %d%s" % [name, int(skill.get("level", 0)), ("+%d" % bonus) if bonus > 0 else ""],
				"state": "highlit", "icon": int(skill.get("icon", 0)),
				# Stealth : clic = activer, glisser = poser en quickbar.
				"icon_texture": _spell_icon_atlas.texture_for(int(skill.get("icon", 0)), DaocSpellIconAtlas.family_for_kind(kind)) if _spell_icon_atlas != null and SPEC_ACTION_NAMES.has(name) else null,
				"on_click": (func() -> void: request_stealth()) if SPEC_ACTION_NAMES.has(name) else null,
				"tooltip": ("%s — cliquer pour activer, glisser vers une quickbar" % name) if SPEC_ACTION_NAMES.has(name) else "",
				"drag": {"kind": "spell", "spell_id": int(skill.get("internal_id", 0)), "line": "SERVER_SKILLS_specialization",
					"name": name, "skill_kind": "specialization"} if SPEC_ACTION_NAMES.has(name) else null})
		elif kind == "ability" or kind == "realm_ability" or kind == "ability_spell":
			# P1-84 — la ligne se GLISSE vers une quickbar (reference = l'entree de
			# `_on_online_skills`, que `assign_entry` retrouve par spell_id + line).
			if not ability_groups.has(kind):
				ability_groups[kind] = []
			(ability_groups[kind] as Array).append({"text": name, "state": "normal", "icon": int(skill.get("icon", 0)),
				"icon_texture": _spell_icon_atlas.texture_for(int(skill.get("icon", 0)), DaocSpellIconAtlas.family_for_kind(kind)) if _spell_icon_atlas != null else null,
				"tooltip": "%s — glisser vers une quickbar" % name,
				"drag": {"kind": "spell", "spell_id": int(skill.get("internal_id", 0)), "line": "SERVER_SKILLS_%s" % kind,
					"name": name, "skill_kind": kind}})
	for kind in ["ability", "ability_spell", "realm_ability"]:
		if ability_groups.has(kind):
			abilities.append({"text": str(preload("res://src/daoc/network/opendaoc/DaocOpenDaocSkillListCodec.gd").CATEGORY_LABELS[kind]), "state": "highlit"})
			abilities.append_array(ability_groups[kind])
	var trades: Array = []
	for value in _online_crafting:
		var craft := value as Dictionary
		trades.append({"text": "%s  %d" % [str(craft.get("name", "")), int(craft.get("points", 0))], "state": "normal"})
	_daoc_ui_bus.publish_many({"stats_specs": specs, "stats_abil": abilities, "stats_trades": trades})


func _on_online_crafting_skills(skills: Array) -> void:
	_online_crafting = skills.duplicate(true)
	if _craft_window != null:
		_craft_window.set_server_skills(skills)
	_publish_online_skill_window()


func _find_online_ability(name: String) -> Dictionary:
	for value in _online_all_skills:
		var skill := value as Dictionary
		var kind := str(skill.get("kind", ""))
		if str(skill.get("name", "")).nocasecmp_to(name) == 0 and (kind == "ability" or kind == "realm_ability" or kind == "ability_spell"):
			return skill.duplicate(true)
	return {}


## Une capacite de la liste du serveur part par 0xBB, comme un style : la
## regle d'indexation est celle de `send_use_skill`.
func _online_use_ability(skill: Dictionary) -> Dictionary:
	var entry := {"kind": "spell", "skill_kind": str(skill.get("kind", "")), "name": str(skill.get("name", "")),
		"online_skill": skill.duplicate(true), "source": "SERVER_0x16_SKILLS"}
	var target_id := _combat_client.current_target_id if _combat_client != null else -1
	var result: Dictionary = _online_cast(entry, target_id)
	if bool(result.get("ok", false)) and str(skill.get("name", "")).nocasecmp_to("Sprint") == 0:
		_online_sprints_sent += 1
	return result


## Sprint = la capacite « Sprint » de la liste du serveur, a bascule : le
## serveur repond par 0xB6 (162 % en sprint, 125 % hors combat) et « You
## prepare to sprint! » ; il coupe seul quand l'endurance tombe a zero.
func request_online_sprint() -> Dictionary:
	if not online_mode or _online_runtime == null:
		return {"ok": false, "reason": "hors ligne : le sprint reste le place-holder local"}
	var sprint := _find_online_ability("Sprint")
	if sprint.is_empty():
		if _text_windows != null:
			_text_windows.push_console_line("Sprint : capacite absente de la liste du serveur (0x16/0x01 pas encore recue ?).")
		return {"ok": false, "reason": "Sprint absent de la liste du serveur"}
	return _online_use_ability(sprint)


func _on_sprint_key() -> void:
	if online_mode:
		request_online_sprint()


## 0xB6 — la vitesse autorisee, en pourcent de la base. Le moteur la prend
## comme facteur (125 % = l'allure calibree) ; une hausse apres un envoi de
## Sprint vaut « je sprinte », une baisse vaut « je ne sprinte plus ».
func _on_online_max_speed(speed: Dictionary) -> void:
	var percent := int(speed.get("percent", 125))
	var previous := int(_online_speed.get("percent", -1))
	if not bool(speed.get("implicit", false)):
		_online_speed_updates += 1
	_online_speed = speed.duplicate(true)
	if previous >= 0 and percent > previous and _online_sprints_sent > 0:
		_online_sprinting = true
	elif previous >= 0 and percent < previous:
		_online_sprinting = false
	if session != null and session.player != null and "server_speed_percent" in session.player:
		session.player.set("server_speed_percent", float(percent))
	if _text_windows != null and not bool(speed.get("implicit", false)):
		_text_windows.push_console_line("Vitesse serveur : %d %%%s." % [percent, " (sprint)" if _online_sprinting else ""])


func get_online_sprint_snapshot() -> Dictionary:
	var motor_percent := -1.0
	if session != null and session.player != null and "server_speed_percent" in session.player:
		motor_percent = float(session.player.get("server_speed_percent"))
	var ability_count := 0
	for value in _online_all_skills:
		if str((value as Dictionary).get("kind", "")) == "ability":
			ability_count += 1
	return {"sprinting": _online_sprinting, "sprints_sent": _online_sprints_sent, "speed": _online_speed.duplicate(true),
		"speed_updates": _online_speed_updates, "abilities": ability_count, "motor_percent": motor_percent}


func _publish_online_book() -> void:
	if _quickbars != null:
		_quickbars.set_available_spells(_online_spell_entries + _online_skill_entries)


func _online_cast(entry: Dictionary, target_id: int) -> Dictionary:
	if _online_runtime == null or not _online_runtime.has_method("send_use_spell"):
		return {"ok": false, "reason": "aucun runtime en ligne capable d'envoyer un sort"}
	# P1-79 — une competence (style, capacite) part par 0xBB, pas 0x7D.
	if entry.has("online_skill") and _online_runtime.has_method("send_use_skill"):
		_online_move_clock = online_movement_send_interval_sec
		_tick_online_movement(0.0)
		if target_id > 0 and target_id != _online_player_object_id():
			_online_runtime.call("send_target", target_id, false)
		var skill_result: Dictionary = _online_runtime.call("send_use_skill", entry.get("online_skill", {}) as Dictionary, true) as Dictionary
		if _text_windows != null:
			if bool(skill_result.get("ok", false)):
				_online_skills_sent += 1
				_text_windows.push_console_line("-> %s (%s) envoye au serveur." % [str(entry.get("name", "")), str(entry.get("skill_kind", ""))])
			else:
				_text_windows.push_console_line("Competence non envoyee : %s" % str(skill_result.get("error", "?")))
		return skill_result
	# Rafraichit d'abord la position utilisee par le paquet UseSpell. Sans cela,
	# un clic juste apres avoir relache une touche peut reutiliser pendant 250 ms
	# le dernier paquet de mouvement et provoquer une fausse interruption.
	_online_move_clock = online_movement_send_interval_sec
	_tick_online_movement(0.0)
	if target_id > 0 and target_id != _online_player_object_id():
		_online_runtime.call("send_target", target_id, false)
	var result: Dictionary = _online_runtime.call("send_use_spell", int(entry.get("online_level", 0)), int(entry.get("online_line_index", 0)), true) as Dictionary
	if bool(result.get("ok", false)):
		_online_casts_sent += 1
		_play_online_player_animation(["cast", "cast_spell", "spellcast"])
		if _text_windows != null:
			_text_windows.push_console_line("-> %s (ligne %d, niveau %d) envoye au serveur." % [str(entry.get("name", "")), int(entry.get("online_line_index", 0)), int(entry.get("online_level", 0))])
	elif _text_windows != null:
		_text_windows.push_console_line("Sort non envoye : %s" % str(result.get("error", "?")))
	return result
func _online_attack(_attacker_id: int, target_id: int) -> Dictionary:
	if _online_runtime == null or not _online_runtime.has_method("send_attack_mode"):
		return {"ok": false, "reason": "autorite distante : runtime sans envoi d'attaque"}
	_online_runtime.call("send_target", target_id, true)
	var result: Dictionary = _online_runtime.call("send_attack_mode", true) as Dictionary
	if bool(result.get("ok", false)):
		_online_attacks_sent += 1
		if _text_windows != null:
			_text_windows.push_console_line("-> attaque de la cible %d demandee au serveur." % target_id)
	return result if bool(result.get("ok", false)) else {"ok": false, "reason": str(result.get("error", "envoi refuse"))}


func _on_online_target_changed(object_id: int) -> void:
	if _online_runtime == null or object_id < 0 or not _online_runtime.has_method("send_target"):
		return
	if bool((_online_runtime.call("send_target", object_id, false) as Dictionary).get("ok", false)):
		_online_targets_sent += 1



func get_online_debug_snapshot() -> Dictionary:
	return {
		"online_mode": online_mode,
		"runtime_attached": _online_runtime != null,
		"start": _online_start_report.duplicate(true),
		"character": str(_online_character.get("name", "")),
		"player_object_id": _online_player_object_id(),
		"stream": _online_stream.report() if _online_stream != null else {},
		"events_received": _online_events_received,
		"movement": {"sent": _online_move_sent, "refused": _online_move_refused,
			"last_error": _online_last_move_error, "interval_sec": online_movement_send_interval_sec},
		"mirror": _local_server.report().get("mirror_mode", false) if _local_server != null else null,
		"status_updates": _online_status_updates, "messages": _online_messages,
		"combat": {"spell_lines": _online_spell_lines.size(), "casts_sent": _online_casts_sent, "targets_sent": _online_targets_sent, "attacks_sent": _online_attacks_sent, "skills_sent": _online_skills_sent, "sprints_sent": _online_sprints_sent},
		"server_animations": _server_animations.get_debug_snapshot() if _server_animations != null else {},
		"text_windows": _text_windows.get_debug_snapshot() if _text_windows != null else {},
	}



## Declare le metier du personnage a l'arbitre et ouvre toutes ses lignes de
## sorts au niveau du personnage (un personnage frais a chaque specialisation a
## 1 ; le serveur ne dit pas encore les points depenses — B7). Sans metier
## connu (fixture), rien n'est invente.
func _configure_player_class_spells() -> Dictionary:
	if _local_server == null:
		return {"ok": false, "reason": "arbitre absent"}
	var class_id := DaocPlayableRosterScript.class_id_for(_online_character)
	if class_id <= 0:
		return {"ok": false, "reason": "metier inconnu pour ce personnage"}
	var player_id := _local_server.player_object_id
	var state_snapshot: Dictionary = _local_server.snapshot(player_id)
	var level := maxi(1, int(_online_character.get("level", state_snapshot.get("level", 1))))
	var result: Dictionary = _local_server.configure_player_class_career(player_id, class_id, level)
	result["class_id"] = class_id
	result["level"] = level
	result["usable_spells"] = (_local_server.known_spells(player_id).get("usable", []) as Array).size()
	return result



func _on_engine_window_requested(window_name: String, visible: bool) -> void:
	if window_name == "inventory" and _alpha_inventory != null:
		var menu := _daoc_ui_manager.get_daoc_window("stats_index")
		if menu != null:
			_alpha_inventory.call("set_window_position", Vector2(menu.position.x, menu.position.y + menu.size.y))
		_alpha_inventory.call("set_window_visible", visible)


func _mount_xml_ui_r11() -> Dictionary:
	if not daoc_ui_enabled:
		return {"ok": true, "enabled": false}
	var ui_root := daoc_client_root.replace("\\", "/").path_join("ui")
	if not DirAccess.dir_exists_absolute(ui_root):
		return {"ok": false, "reason": "dossier ui introuvable"}
	_daoc_ui_bus = DaocUiAdapterBusScript.new()
	_daoc_ui_manager = DaocUiWindowManagerScript.new()
	_daoc_ui_manager.name = "DaocUiWindowManager"
	add_child(_daoc_ui_manager)
	var layout_store = DaocUiLayoutStoreScript.new(daoc_ui_layout_path)
	var reference_size := Vector2(daoc_ui_reference_resolution)
	if reference_size.x <= 1.0 or reference_size.y <= 1.0:
		reference_size = get_viewport().get_visible_rect().size
	var report: Dictionary = _daoc_ui_manager.setup(ui_root, daoc_ui_skin, _daoc_ui_bus,
		daoc_ui_windows, daoc_ui_scale, reference_size, layout_store)
	_daoc_ui_bridge = DaocUiServerBridgeScript.new()
	report["bridge"] = _daoc_ui_bridge.setup(_local_server, _daoc_ui_bus,
		int((_local_server.report() as Dictionary).get("player_object_id", -1)))
	_combat_client.target_changed.connect(_daoc_ui_bridge.set_target)
	_daoc_ui_bridge.set_target(_combat_client.current_target_id)
	report["target_wired"] = true
	report["reference_resolution"] = [int(reference_size.x), int(reference_size.y)]
	return report


func _wire_mouse_targeting_r11() -> void:
	var router: Node = session.input_router
	if not mouse_targeting_enabled or router == null or not router.has_signal("world_click"):
		return
	if not router.world_click.is_connected(_on_world_click_target_r11):
		router.world_click.connect(_on_world_click_target_r11)
	_mouse_target_wired = router.world_click.is_connected(_on_world_click_target_r11)
	# P1-30-HF1 — le ramassage passe par son propre signal. Un routeur qui ne
	# l'expose pas laisse le ciblage intact : le raccordement est facultatif.
	if router.has_signal("world_double_click"):
		if not router.world_double_click.is_connected(_on_world_double_click_loot_r11):
			router.world_double_click.connect(_on_world_double_click_loot_r11)
	if router.has_signal("world_right_click") and not router.world_right_click.is_connected(_on_world_right_click_interact):
		router.world_right_click.connect(_on_world_right_click_interact)


## 2026-09-29 : clic droit court sur un PNJ = lui parler (0x7A), le geste du
## client d origine ; le double clic gauche reste accepte.
func _on_world_right_click_interact(screen_position: Vector2) -> void:
	if online_mode and _combat_client != null:
		_try_online_interact_at_screen(screen_position)


func _on_world_click_target_r11(screen_position: Vector2, button_index: int) -> void:
	if _combat_client == null:
		return
	if button_index == MOUSE_BUTTON_LEFT:
		_combat_client.pick_target_at_screen(screen_position, mouse_targeting_pixel_tolerance,
			mouse_targeting_max_distance_raw)


## Repli apres le GUI : le routeur global ignore volontairement tout clic quand
## `gui_get_hovered_control()` rend un Control. Certains cadres XML transparents
## couvrent pourtant le monde. Si aucun widget n'a consomme le clic, il arrive
## ici et doit encore pouvoir cibler la creature visible.
func _unhandled_input(event: InputEvent) -> void:
	if not mouse_targeting_enabled or _combat_client == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_combat_client.pick_target_at_screen(mouse_event.position,
				mouse_targeting_pixel_tolerance, mouse_targeting_max_distance_raw)
			get_viewport().set_input_as_handled()


## P1-30-HF1 — le DOUBLE clic gauche ramasse le cadavre sous le pointeur.
##
## P1-30 avait choisi le clic DROIT, et ce choix etait faux DEUX FOIS. D'abord
## parce que l'utilisateur connait le client d'origine et a tranche : c'est le
## double clic gauche. Ensuite, et c'est le vrai defaut, parce que le routeur
## n'emet `world_click` QUE pour le bouton gauche — le bouton droit y pilote la
## capture de souris et ne sort jamais vers le monde. La branche droite de P1-30
## etait donc MORTE A L'ECRITURE : aucun clic ne l'a jamais atteinte, et rien ne
## le disait.
func _on_world_double_click_loot_r11(screen_position: Vector2, button_index: int) -> void:
	if _combat_client == null or not corpse_looting_enabled:
		return
	if button_index != MOUSE_BUTTON_LEFT:
		return
	# P1-78 — en ligne, le double clic sur un PNJ vivant PARLE au PNJ (0x7A),
	# comme dans le client d'origine ; le cadavre garde le ramassage.
	if online_mode and _try_online_interact_at_screen(screen_position):
		return
	if online_mode and _try_door_at_screen(screen_position):
		return
	_combat_client.loot_at_screen(screen_position, mouse_targeting_pixel_tolerance)


func get_gameplay_ui_debug_snapshot() -> Dictionary:
	var out := _gameplay_ui_report.duplicate(true)
	if _combat_client != null:
		out["combat_client"] = _combat_client.get_debug_snapshot()
	if _daoc_ui_manager != null:
		out["ui_runtime"] = _daoc_ui_manager.get_debug_snapshot()
	out["mouse_target_wired"] = _mouse_target_wired
	return out


## ═══════════════════════════════════════════════════════════════════════════
## R10 — LE MODÈLE DE PERSONNAGE
##
## Le joueur de la scène de jeu était une CAPSULE, et l'utilisateur l'a vu tout
## de suite. La cause paraissait rédhibitoire : le modèle est attaché par la
## commande `/playervisual meshy`, donc par le routeur de commandes, qui est
## l'un des ONZE montages couverts par le garde réseau `mount_dol_and_hud`.
##
## MESURÉ PLUTÔT QUE SUPPOSÉ : le routeur n'est qu'une COQUILLE. Tout le travail
## est fait par `DaocPlayerVisualMeshySwap.attach_to_player(player, options)`,
## qui ne demande ni hôte, ni session, ni transport — un nœud joueur et un
## dictionnaire, et sa configuration vient d'un JSON local.
##
## Le modèle n'était donc PAS couplé au réseau : il était couplé à la CONSOLE
## qui l'appelait. Rien n'est déplacé hors du garde, rien n'est affaibli — la
## scène de jeu appelle directement ce que la commande appelait, et
## `mount_dol_and_hud` reste faux.
## ═══════════════════════════════════════════════════════════════════════════
## R10-HF2 — LE VENT DANS LES FEUILLES
##
## Le Grass Remaster anime l'herbe depuis P1-20M ; les arbres restaient figés. Un
## monde où l'herbe ondule sous des arbres immobiles se lit comme deux mondes
## superposés.
##
## LE VENT EST LE MÊME QUE CELUI DE L'HERBE — direction, vitesse et rafales sont
## partagées — mais le MOUVEMENT diffère : une lame d'herbe plie depuis sa
## racine, une feuille est portée par une branche qui oscille et frissonne
## par-dessus.
##
## AUCUNE DE CES TROIS AMPLITUDES N'EST CALIBRÉE. Elles sont plausibles, pas
## mesurées, au même titre que `speedtree_units_to_daoc = 12`. Seul un œil humain
## peut dire si une cime bouge trop.
##
## Décoché, le rendu est exactement celui d'avant le jalon : aucun matériau de
## remplacement n'est créé.
var _player_visual_report: Dictionary = {}


## Attache le modèle de Heyveno à la capsule. À appeler APRÈS `mount_player_r7`.
func mount_player_visual_r10() -> Dictionary:
	if session == null or session.player == null:
		_player_visual_report = {"ok": false, "reason": "aucun joueur monte"}
		return _player_visual_report.duplicate(true)
	var swap = DaocPlayerVisualMeshySwapScript.new()
	_player_visual_report = swap.call("attach_to_player", session.player, build_player_visual_options()) as Dictionary
	# P1-129 : une scene (re)montee arrive avec TOUTES les armes cuites ; la
	# rhabiller aussitot avec le dernier etat connu (sinon « toutes les armes au lancement »).
	_watch_player_visual_root()
	call_deferred("_reapply_equipment_visuals")
	return _player_visual_report.duplicate(true)


## ═══════════════════════════════════════════════════════════════════════════
## P1-93 — LA POUPEE SUIT LE SAC
##
## La scene du Lab arrive « deja equipee » : la panoplie est cuite dans ses
## textures. Ici, l'inventaire de l'arbitre fait foi : au demarrage les
## logements sont vides (tenue de base), la panoplie de depart est dans le sac,
## et chaque equip/unequip re-habille les deux instances de la scene.
## En ligne, l'inventaire est celui du serveur (0x02) : memes modeles, meme
## traduction, l'arbitre local n'y touche pas.
## ═══════════════════════════════════════════════════════════════════════════
const DaocPlayerEquipmentVisualsScript = preload("res://src/daoc/player/DaocPlayerEquipmentVisuals.gd")
const DaocEquipmentTablesScript = preload("res://src/daoc/player/DaocEquipmentTables.gd")
var _equipment_visuals: RefCounted = null
var _equipment_visuals_report: Dictionary = {}


func mount_equipment_visuals_p1_93() -> Dictionary:
	if session == null or session.player == null:
		_equipment_visuals_report = {"ok": false, "reason": "joueur absent"}
		return _equipment_visuals_report.duplicate(true)
	var visual_root: Node = session.player.get_node_or_null(DaocPlayerVisualMeshySwapScript.VISUAL_ROOT_NAME)
	if visual_root == null:
		_equipment_visuals_report = {"ok": false, "reason": "modele de joueur non monte"}
		return _equipment_visuals_report.duplicate(true)
	# L'apparence (race/genre fig3) vient du manifeste de la scene montee.
	var appearance_id := 2
	var gender := "female"
	# Les recettes du catalogue portent directement cette identite. Elle prime
	# sur l'ancien manifeste lateral, absent pour une recette assemblable.
	for visual_value in _player_visual_scene_roots():
		var visual_scene := visual_value as Node
		if visual_scene != null and visual_scene.has_meta("daoc_appearance_id"):
			appearance_id = int(visual_scene.get_meta("daoc_appearance_id"))
			gender = "female" if appearance_id % 2 == 0 else "male"
			break
	var manifest_path := str(build_player_visual_options().get("pbr_manifest_path", ""))
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			appearance_id = int(manifest.get("appearance_id", appearance_id))
			gender = str(manifest.get("gender", gender))
	_watch_player_visual_root()
	_equipment_visuals = DaocPlayerEquipmentVisualsScript.new()
	var configured: Dictionary = _equipment_visuals.configure(daoc_client_root, appearance_id, gender)
	if not bool(configured.get("ok", false)):
		_equipment_visuals_report = {"ok": false, "reason": str(configured.get("reason", "")), "appearance_id": appearance_id}
		return _equipment_visuals_report.duplicate(true)
	if _local_server != null and _local_server.has_signal("player_inventory_changed"):
		var receiver := Callable(self, "_on_player_inventory_changed")
		if not _local_server.player_inventory_changed.is_connected(receiver):
			_local_server.player_inventory_changed.connect(receiver)
	if online_mode and _online_runtime != null and _online_runtime.has_signal("inventory_changed"):
		var online_receiver := Callable(self, "_on_online_inventory_for_visuals")
		if not _online_runtime.inventory_changed.is_connected(online_receiver):
			_online_runtime.inventory_changed.connect(online_receiver)
		if _online_runtime.has_method("inventory_snapshot"):
			var current: Dictionary = _online_runtime.call("inventory_snapshot") as Dictionary
			if not (current.get("items", []) as Array).is_empty():
				_on_online_inventory_for_visuals(current)
	var initial: Dictionary = _local_server.player_inventory_snapshot() if _local_server != null else {}
	_on_player_inventory_changed(initial)
	_equipment_visuals_report = {"ok": true, "appearance_id": appearance_id, "gender": gender,
		"tables": configured.get("tables", {}), "applied": _equipment_visuals.last_report()}
	return _equipment_visuals_report.duplicate(true)


var _last_visual_equipped: Dictionary = {}
var _last_visual_active := -1
var _last_visual_known := false


## P1-129 — toute scene ajoutee sous la racine visuelle (chargement differe,
## changement d apparence) est rhabillee avec le dernier etat connu.
func _watch_player_visual_root() -> void:
	if session == null or session.player == null:
		return
	var visual_root: Node = session.player.get_node_or_null(DaocPlayerVisualMeshySwapScript.VISUAL_ROOT_NAME)
	if visual_root == null:
		return
	var receiver := Callable(self, "_on_player_visual_child_added")
	if not visual_root.child_entered_tree.is_connected(receiver):
		visual_root.child_entered_tree.connect(receiver)


func _on_player_visual_child_added(_node: Node) -> void:
	call_deferred("_reapply_equipment_visuals")


func _reapply_equipment_visuals() -> void:
	if _equipment_visuals == null:
		return
	if not _last_visual_known:
		# Rien recu encore : au moins jamais toutes les armes en main.
		for root_value in _player_visual_scene_roots():
			DaocPlayerEquipmentVisualsScript.filter_baked_weapons(root_value as Node,
				DaocPlayerEquipmentVisualsScript.active_weapon_slots_from_overview(_online_character if online_mode else {}))
		return
	_equipment_visuals_report["applied"] = _equipment_visuals.apply(_player_visual_scene_roots(), _last_visual_equipped, _last_visual_active)
	_apply_weapon_family(_last_visual_equipped, _last_visual_active)  # P1-130 : garde de la nouvelle scene


func _player_visual_scene_roots() -> Array:
	var out: Array = []
	if session == null or session.player == null:
		return out
	var visual_root: Node = session.player.get_node_or_null(DaocPlayerVisualMeshySwapScript.VISUAL_ROOT_NAME)
	if visual_root == null:
		return out
	for child in visual_root.get_children():
		if child is Node3D:
			out.append(child)
	return out


func _on_player_inventory_changed(snapshot: Dictionary) -> void:
	if _equipment_visuals == null:
		return
	if online_mode:
		return
	var equipped: Dictionary = snapshot.get("equipped", {}) as Dictionary
	_last_visual_equipped = equipped.duplicate(true)
	_last_visual_active = _offline_active_weapon_slots
	_last_visual_known = true
	_apply_weapon_family(equipped, _offline_active_weapon_slots)
	var report: Dictionary = _equipment_visuals.apply(_player_visual_scene_roots(), equipped, _offline_active_weapon_slots)
	_equipment_visuals_report["applied"] = report
	if _alpha_inventory != null and _alpha_inventory.has_method("refresh_from_snapshot"):
		var ui_snapshot := snapshot.duplicate(true)
		ui_snapshot["active_weapon_slots"] = _offline_active_weapon_slots  # P1-128 : liseré hors ligne
		_alpha_inventory.call("refresh_from_snapshot", ui_snapshot)


## En ligne : le paquet 0x02 porte `slot` et `model` par objet, c'est tout ce
## que la poupee demande.
func _on_online_inventory_for_visuals(snapshot: Dictionary) -> void:
	# P1-95 : le sac du serveur (0x02) alimente AUSSI la fenetre d'inventaire,
	# dans la forme que l'arbitre local lui donne (slots / equipped / backpack).
	var slots: Dictionary = {}
	var equipped: Dictionary = {}
	var backpack: Array = []
	for value in snapshot.get("items", []):
		var item := value as Dictionary
		if bool(item.get("empty", true)):
			continue
		var slot := int(item.get("slot", -1))
		var entry := {"model": int(item.get("model", 0)), "name": str(item.get("name", "")),
			"object_type": int(item.get("object_type", 0)), "item_type": slot, "slot": slot,
			"level": int(item.get("level", 0)), "quality": int(item.get("quality", 0)),
			"condition": int(item.get("condition", 0)), "durability": int(item.get("durability", 0)),
			"value1": int(item.get("value1", 0)), "value2": int(item.get("value2", 0)),
			"hand": int(item.get("hand", 0)), "damage_type": int(item.get("damage_type", 0)), "weight": int(item.get("weight", 0))}
		slots[slot] = entry
		if DaocEquipmentTablesScript.INVENTORY_SLOT_TO_VISUAL.has(slot):
			equipped[slot] = entry
		elif slot >= 40:
			backpack.append(entry)
	var active := int(snapshot.get("active_weapon_slots", -1))
	var ui_snapshot := {"revision": int(snapshot.get("occupied_slot_count", 0)), "source": "server_0x02",
		"character_name": str(_online_character.get("name", "")),
		"slots": slots, "equipped": equipped, "backpack": backpack, "active_weapon_slots": active,
		"weapon": equipped.get(12, equipped.get(10, {})), "shield": equipped.get(11, {})}
	if _alpha_inventory != null and _alpha_inventory.has_method("refresh_from_snapshot"):
		_alpha_inventory.call("refresh_from_snapshot", ui_snapshot)
	_online_inventory_ui_snapshot = ui_snapshot
	if _equipment_visuals == null:
		return
	_last_visual_equipped = equipped.duplicate(true)
	_last_visual_active = active
	_last_visual_known = true
	_apply_weapon_family(equipped, active)
	_equipment_visuals_report["applied"] = _equipment_visuals.apply(_player_visual_scene_roots(), equipped, active)


var _online_inventory_ui_snapshot: Dictionary = {}


func online_inventory_ui_snapshot() -> Dictionary:
	return _online_inventory_ui_snapshot.duplicate(true)


func get_equipment_visuals_report() -> Dictionary:
	return _equipment_visuals_report.duplicate(true)


## Surcharges de l'inspecteur passees au chemin d'attache. Toutes vides ou
## decochees, le dictionnaire ne change rien au comportement d'avant.
func build_player_visual_options() -> Dictionary:
	var options: Dictionary = {
		"pbr_enabled": player_pbr_enabled,
		"pbr_client_root": daoc_client_root,
		"pbr_normal_strength": player_pbr_normal_strength,
		"pbr_roughness_amount": player_pbr_roughness_amount,
		"pbr_ao_amount": player_pbr_ao_amount,
	}
	var override_scene := str(PLAYER_APPEARANCE_SCENES.get(player_appearance_choice, PLAYER_APPEARANCE_SCENES[0]))
	# Le personnage choisi dans le menu impose sa scene (en ligne : la tenue de
	# depart de sa race/sexe, celle de l'apercu), sinon l'apparence de l'inspecteur.
	if _chosen_visual_scene != "" and ResourceLoader.exists(_chosen_visual_scene):
		override_scene = _chosen_visual_scene
	if override_scene != "":
		# Les deux personnages online deja exportes disposent desormais d'une
		# recette legere du catalogue. Le nom reste la cle stable envoyee par le
		# serveur ; aucune tenue n'est decidee localement.
		var online_name := override_scene.get_file().get_basename().to_lower()
		if online_name in ["online_heyveno", "online_heyvena"]:
			var catalog_scene := "res://generated/client_catalog/characters/%s.tscn" % online_name
			if ResourceLoader.exists(catalog_scene):
				override_scene = catalog_scene
		options["walk_scene_path"] = override_scene
		options["run_scene_path"] = override_scene
		# Le manifeste suit la scene, jamais celui de la tenue precedente.
		options["pbr_manifest_path"] = DaocPlayerVisualMeshySwapScript.manifest_path_for_scene(override_scene)
		# Les races fig3 partagent une hauteur native proche : leur manifeste
		# porte le multiplicateur racial, sans changer la capsule de gameplay.
		var manifest_path := str(options["pbr_manifest_path"])
		if FileAccess.file_exists(manifest_path):
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if manifest is Dictionary:
				var contract: Variant = manifest.get("scale_contract", {})
				if contract is Dictionary:
					var racial_scale := float(contract.get("visual_scale_for_target", 0.0))
					if is_finite(racial_scale) and racial_scale > 0.0:
						options["visual_scale"] = racial_scale
		else:
			# Une recette du catalogue n'a pas de manifeste lateral : son
			# echelle raciale est dans le manifeste du catalogue.
			var catalog_scale := DaocPlayerCatalogAppearance.visual_scale_for_scene(override_scene)
			if catalog_scale > 0.0:
				options["visual_scale"] = catalog_scale
	return options


## Permet aussi de changer la liste depuis l'inspecteur distant pendant le jeu.
func _refresh_player_appearance() -> void:
	if not is_inside_tree() or session == null or session.player == null:
		return
	mount_player_visual_r10()


## Rebranche ou retire les cartes PBR sur le modele DEJA monte, sans le
## recharger : c'est ce qui rend la bascule de l'inspecteur immediate, et
## reversible sans redemarrer la scene.
func _refresh_player_pbr() -> void:
	if session == null or session.player == null:
		return
	var visual_root := session.player.get_node_or_null("DaocPlayerVisualRoot")
	if visual_root == null:
		return
	var swap = DaocPlayerVisualMeshySwapScript.new()
	var config: Dictionary = swap.call("load_config") as Dictionary
	var options := build_player_visual_options()
	for key in options.keys():
		config[str(key)] = options[key]
	_player_visual_report["pbr_report"] = swap.call("apply_pbr_mode", visual_root, config)


func get_player_visual_debug_snapshot() -> Dictionary:
	return _player_visual_report.duplicate(true)


var _player_reflection_probe: ReflectionProbe = null


## Sonde locale mobile : la plaque reçoit les couleurs du décor au lieu de ne
## refléter que la radiance générale du ciel. UPDATE_ALWAYS est nécessaire car
## la sonde se déplace avec le joueur ; l'option d'inspecteur permet de couper
## entièrement ce coût et cet effet pendant la scène.
func mount_player_reflections_p1_37() -> Dictionary:
	if session == null or session.player == null:
		return {"ok": false, "reason": "aucun joueur monte"}
	if _player_reflection_probe == null or not is_instance_valid(_player_reflection_probe):
		_player_reflection_probe = ReflectionProbe.new()
		_player_reflection_probe.name = "DaocPlayerEnvironmentReflections"
		_player_reflection_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		_player_reflection_probe.box_projection = false
		_player_reflection_probe.enable_shadows = false
		session.player.add_child(_player_reflection_probe)
	_refresh_player_reflections()
	return get_player_reflection_debug_snapshot()


func _refresh_player_reflections() -> void:
	if session == null or session.player == null:
		return
	if _player_reflection_probe == null or not is_instance_valid(_player_reflection_probe):
		if player_environment_reflections_enabled:
			mount_player_reflections_p1_37()
		return
	var capture_range := maxf(200.0, player_reflection_range_raw * world_scale)
	_player_reflection_probe.visible = player_environment_reflections_enabled
	_player_reflection_probe.intensity = maxf(0.0, player_reflection_intensity)
	_player_reflection_probe.position = Vector3.UP * player_reflection_height_raw * world_scale
	_player_reflection_probe.size = Vector3(capture_range * 2.0, capture_range, capture_range * 2.0)
	_player_reflection_probe.max_distance = capture_range


func get_player_reflection_debug_snapshot() -> Dictionary:
	if _player_reflection_probe == null or not is_instance_valid(_player_reflection_probe):
		return {"ok": false, "mounted": false, "enabled": player_environment_reflections_enabled}
	return {
		"ok": true,
		"mounted": true,
		"enabled": _player_reflection_probe.visible,
		"update_always": _player_reflection_probe.update_mode == ReflectionProbe.UPDATE_ALWAYS,
		"range": _player_reflection_probe.max_distance,
		"intensity": _player_reflection_probe.intensity,
		"height": _player_reflection_probe.position.y,
		"parent_is_player": _player_reflection_probe.get_parent() == session.player,
	}


var _player_torch: Node3D = null


func mount_player_torch_p1_37() -> Dictionary:
	if session == null or session.player == null:
		return {"ok": false, "reason": "aucun joueur monte"}
	if _player_torch != null and is_instance_valid(_player_torch):
		return _player_torch.call("debug_snapshot") as Dictionary
	_player_torch = DaocPlayerTorchScript.new()
	_player_torch.name = "DaocPlayerTorch"
	session.player.add_child(_player_torch)
	_player_torch.call("setup", {
		"toggle_key": KEY_T,
		"enabled_on_start": player_torch_on_at_start,
		"energy": player_torch_energy,
		"range_raw": player_torch_range_raw * world_scale,
		"shadows": player_torch_shadows,
		"shadow_blur": player_torch_shadow_blur,
		"shadow_opacity": player_torch_shadow_opacity,
		"beam_yaw_deg": player_torch_beam_yaw_deg,
		"beam_pitch_deg": player_torch_beam_pitch_deg,
		"world_brightness_boost": player_torch_world_brightness_boost,
	})
	_player_torch.connect("torch_toggled", _on_player_torch_toggled)
	return _player_torch.call("debug_snapshot") as Dictionary


func get_player_torch_debug_snapshot() -> Dictionary:
	return _player_torch.call("debug_snapshot") as Dictionary if _player_torch != null else {}


func _push_torch_beam_orientation() -> void:
	if _player_torch != null and is_instance_valid(_player_torch):
		_player_torch.call("set_beam_orientation", player_torch_beam_yaw_deg, player_torch_beam_pitch_deg)


## Torche allumee : le monde s eclaircit un peu (adjustment_brightness de
## l Environment via l adaptateur Sky3D), pour que la nuit reste jouable.
## Eteinte : retour a 1.0. La torche elle-meme ne touche pas l Environment.
func _on_player_torch_toggled(_enabled: bool, world_brightness_boost: float) -> void:
	if _sky3d_adapter != null and is_instance_valid(_sky3d_adapter) \
			and _sky3d_adapter.has_method("set_brightness_boost"):
		_sky3d_adapter.call("set_brightness_boost", world_brightness_boost)


func get_world_brightness_boost() -> float:
	if _sky3d_adapter != null and is_instance_valid(_sky3d_adapter) \
			and _sky3d_adapter.has_method("brightness_boost"):
		return float(_sky3d_adapter.call("brightness_boost"))
	return 0.0


## ═══════════════════════════════════════════════════════════════════════════
## R10 — L'HORIZON
##
## Sans lui le monde s'arrête net au bord de la zone chargée, et ce vide se lit
## comme un mur clair : ce n'est pas du LOD, c'est la fin des données. C'est
## aussi, très concrètement, ce qui empêchait de trouver la zone voisine à
## l'œil — l'utilisateur l'a signalé après le premier essai de la scène de jeu.
##
## L'horizon N'EST PAS une étape de zone : il est bâti APRÈS elles, et il dessine
## le relief des zones de la région qui ne sont PAS résidentes. Il dépend donc du
## jeu des zones résidentes, et R4 en a confié la branche au `DaocZoneStreamer`
## pour cette raison exacte. Le streamer ne reconstruit rien : il PRÉVIENT par
## `resident_zones_changed`, et la reconstruction est différée en fin de trame.
##
## Sans ce report, une construction de zone — qui acquiert sa branche AU MILIEU
## de l'assemblage — ferait relire les cartes de hauteurs des voisines à chaque
## étape.
##
## LES VALEURS SONT CELLES DE LA SCÈNE ENREGISTRÉE DU BANC, et l'une d'elles
## diffère du script : `distant_lod_colour_atlas_size` vaut 512 dans
## `ZoneViewer.gd` et 1024 dans `ZoneViewer.tscn`. Recopier le script aurait
## donné un horizon deux fois moins défini que celui qui a été validé — la même
## erreur que `player_run_speed_raw` à R7.
var _distant_terrain_report: Dictionary = {}
var _horizon_dirty: bool = false
var _horizon_resident_zones: Array = []

## P1-33G — les réglages numériques du jalon, VALEURS DE LA SCÈNE ENREGISTRÉE DU
## BANC (qui y sont celles du script : `ZoneViewer.tscn` n'en surcharge aucune).
## Le jeu n'en expose que les deux cases ; la suite compare ce dictionnaire clé
## par clé au banc, pour qu'une valeur recopiée de mémoire ne diverge pas en
## silence — la leçon de R7.
const P1_33_SETTINGS := {
	"zone_prefetch_base_raw": 6000.0,
	"zone_prefetch_seconds": 4.0,
	"zone_prefetch_max_zones": 1,
	"distant_near_lod_atlas_size": 2048,
	"distant_near_lod_step": 1,
	"distant_near_lod_band_raw": 8192.0,
	"distant_near_lod_base_raw": 12000.0,
	"distant_near_lod_seconds": 6.0,
	"distant_near_lod_max_zones": 2,
	"zone_lod_plan_interval_seconds": 0.35,
}
## Le dernier plan rendu par `DaocZoneLodPlanner`, l'horloge qui borne sa
## cadence, et la sélection de palier AVEC laquelle l'horizon a été bâti — sans
## cette dernière, un plan qui ne change que `near_zones` était jugé « pas
## périmé » et la voisine restait floue jusqu'au premier franchissement.
var _zone_lod_plan: Dictionary = {}
var _zone_lod_plan_clock: float = 0.0
var _zone_prefetch_log: Array = []
var _horizon_lod_selection: Dictionary = {}


## Branche l'horizon sur le streamer et le bâtit une première fois.
func mount_horizon_r10() -> Dictionary:
	if not distant_terrain_enabled:
		return {"ok": false, "reason": "horizon desactive"}
	var streamer := zone_streamer()
	if streamer == null:
		return {"ok": false, "reason": "streamer absent"}
	if not streamer.resident_zones_changed.is_connected(_on_streamer_resident_zones_changed):
		streamer.resident_zones_changed.connect(_on_streamer_resident_zones_changed)
	_build_distant_terrain()
	return _distant_terrain_report.duplicate(true)


## Le jeu des zones résidentes a changé : l'horizon est PÉRIMÉ. On lève un
## drapeau et on rebâtit UNE fois en fin de trame, jamais sur-le-champ.
func _on_streamer_resident_zones_changed(_resident: Array) -> void:
	if not distant_terrain_enabled:
		return
	_horizon_dirty = true
	call_deferred("refresh_distant_terrain_if_stale_r10")


## Ne rebâtit que si la liste résidente a RÉELLEMENT changé. Le signal part
## plusieurs fois par zone bâtie ; sans cette garde, chaque tir relirait les
## cartes de hauteurs des voisines.
func refresh_distant_terrain_if_stale_r10() -> bool:
	if not _horizon_dirty or not distant_terrain_enabled:
		return false
	var streamer := zone_streamer()
	if streamer == null:
		return false
	if not DaocZoneLodPlanner.horizon_is_stale(streamer.loaded_zones(), _horizon_resident_zones,
			_zone_lod_plan, _horizon_lod_selection, distant_near_border_lod_enabled):
		_horizon_dirty = false
		return false
	_build_distant_terrain()
	return true


func _build_distant_terrain() -> void:
	var streamer := zone_streamer()
	if streamer == null:
		return
	var active: Array = streamer.loaded_zones()
	# Avant la première zone bâtie le streamer ne tient rien. La zone habitée
	# reste alors la seule vérité — le jeu n'a pas de liste d'inspecteur sur
	# laquelle retomber, contrairement au banc.
	if active.is_empty():
		if current_zone < 0:
			return
		active = [current_zone]
	_horizon_dirty = false
	_horizon_resident_zones = active.duplicate()
	_horizon_lod_selection = {
		"near_zones": (_zone_lod_plan.get("near_zones", []) as Array).duplicate(),
		"near_edges": (_zone_lod_plan.get("near_edges", {}) as Dictionary).duplicate(true),
	} if distant_near_border_lod_enabled else {}

	# La couleur de la nappe de bord vient du profil d'environnement de la zone,
	# comme dans le banc. Sans autorité montée, le gris-bleu d'Albion.
	var border_fog_color := Color8(85, 140, 166)
	var state: Dictionary = _environment_report.get("state", {}) as Dictionary
	var profile: Dictionary = state.get("zone_profile", {}) as Dictionary
	if profile.has("fog_color"):
		border_fog_color = Color.from_string(str(profile["fog_color"]), border_fog_color)

	_distant_terrain_report = DaocDistantTerrainScript.build(self, active, {
		"step": distant_terrain_step,
		"max_zones": distant_terrain_max_zones,
		"lod_atlas_size": distant_lod_colour_atlas_size,
		"client_root": daoc_client_root,
		"cliffs_enabled": distant_cliffs_enabled,
		"border_fog_enabled": distant_non_maritime_border_fog_enabled,
		"border_fog_color": border_fog_color,
		"horizon_backdrop_enabled": distant_horizon_backdrop_enabled,
		"horizon_segments_per_side": distant_horizon_segments_per_side,
		"horizon_backdrop_distance_raw": distant_horizon_backdrop_distance_raw,
		"parent": streamer.horizon_branch(),
		# P1-33G — le palier proche. Sans plan courant, les listes sont vides et
		# l'horizon est exactement celui d'avant le jalon.
		"near_zones": (_zone_lod_plan.get("near_zones", []) as Array) if distant_near_border_lod_enabled else [],
		"near_edges": (_zone_lod_plan.get("near_edges", {}) as Dictionary) if distant_near_border_lod_enabled else {},
		"near_lod_atlas_size": int(P1_33_SETTINGS["distant_near_lod_atlas_size"]),
		"near_step": int(P1_33_SETTINGS["distant_near_lod_step"]),
		"near_band_raw": float(P1_33_SETTINGS["distant_near_lod_band_raw"]),
	})
	_distant_terrain_report["owner"] = "DaocZoneStreamer"
	_distant_terrain_report["resident_zones"] = active.duplicate()


func get_distant_terrain_debug_snapshot() -> Dictionary:
	return _distant_terrain_report.duplicate(true)


# ============================================================================
# P1-33G — préchargement et palier proche, portés du banc. Même planificateur,
# mêmes chiffres, même chemin de construction (`build_zone`) : seul l'hôte change.
# ============================================================================

func _process(delta: float) -> void:
	_tick_zone_lod_plan_p1_33(delta)
	_tick_population_pbr_p1_37()
	_tick_follow()
	_tick_online_movement(delta)
	_tick_online_zonejumps()
	_tick_nameplates()
	_tick_minimap(false, delta)
	if online_mode and _population != null and _population.has_method("advance_motions"):
		_population.call("advance_motions", delta)


## Deux entites par image : le PBR des centaines de PNJ arrive progressivement
## sans transformer le premier affichage de la zone en longue image gelee.
func _tick_population_pbr_p1_37() -> void:
	if _population_pbr == null or _population_pbr_queue.is_empty():
		return
	for _index in range(mini(2, _population_pbr_queue.size())):
		var root: Node = _population_pbr_queue.pop_front() as Node
		if root == null or not is_instance_valid(root):
			continue
		var part: Dictionary = _population_pbr.call("apply_to_subtree", root) as Dictionary
		for key in ["upgraded", "surfaces", "missing", "skipped"]:
			_population_pbr_report[key] = int(_population_pbr_report.get(key, 0)) + int(part.get(key, 0))
	_population_pbr_report["pending"] = _population_pbr_queue.size()
	_population_report["pbr"] = _population_pbr_report.duplicate(true)


## Appelé à chaque image, ne TRAVAILLE qu'à la cadence du banc.
func _tick_zone_lod_plan_p1_33(delta: float) -> void:
	if not distant_terrain_enabled or session == null:
		return
	_zone_lod_plan_clock += maxf(delta, 0.0)
	if _zone_lod_plan_clock < float(P1_33_SETTINGS["zone_lod_plan_interval_seconds"]):
		return
	_zone_lod_plan_clock = 0.0
	refresh_zone_lod_plan_p1_33()


## Le plan, sans rien construire ni dessiner — ce que la suite interroge.
func plan_zone_lod_p1_33(active: int, daoc_x: float, daoc_y: float,
		speed_raw: float, resident: Array) -> Dictionary:
	return DaocZoneLodPlanner.plan(_ensure_transition(), active, daoc_x, daoc_y, speed_raw,
		resident, {
			"prefetch_base_raw": float(P1_33_SETTINGS["zone_prefetch_base_raw"]),
			"prefetch_seconds": float(P1_33_SETTINGS["zone_prefetch_seconds"]),
			"max_prefetch_zones": int(P1_33_SETTINGS["zone_prefetch_max_zones"]) if zone_prefetch_enabled else 0,
			"near_lod_base_raw": float(P1_33_SETTINGS["distant_near_lod_base_raw"]),
			"near_lod_seconds": float(P1_33_SETTINGS["distant_near_lod_seconds"]),
			"max_near_zones": int(P1_33_SETTINGS["distant_near_lod_max_zones"]) if distant_near_border_lod_enabled else 0,
		})


## Le plan courant, recalculé depuis la capsule du joueur, puis EXÉCUTÉ :
## préchargement par `build_zone`, et horizon rebâti si le palier a changé.
func refresh_zone_lod_plan_p1_33() -> Dictionary:
	if session == null or session.player == null or not is_instance_valid(session.player):
		return _zone_lod_plan
	var motor := session.player as DaocPlayerMotor
	if motor == null:
		return _zone_lod_plan
	var streamer := zone_streamer()
	if streamer == null:
		return _zone_lod_plan
	return _apply_zone_lod_plan_p1_33(plan_zone_lod_p1_33(motor.daoc_zone, motor.daoc_x,
		motor.daoc_y, motor.last_speed_raw, streamer.loaded_zones()))


func _apply_zone_lod_plan_p1_33(plan: Dictionary) -> Dictionary:
	if not bool(plan.get("ok", false)):
		return _zone_lod_plan
	var streamer := zone_streamer()
	if zone_prefetch_enabled:
		for value in (plan.get("prefetch", []) as Array):
			var zone_id := int(value)
			if streamer.has_zone(zone_id):
				continue
			# Le budget de résidence reste maître : précharger au-delà ferait
			# évincer une zone dans la foulée, construction payée pour rien.
			if streamer.loaded_zones().size() >= maxi(1, max_resident_zones):
				break
			if not _zones_building_spread.is_empty():
				break
			var started := Time.get_ticks_msec()
			if zone_prefetch_spread_enabled and is_inside_tree():
				build_zone_spread(zone_id)
				continue
			build_zone(zone_id)
			var elapsed := Time.get_ticks_msec() - started
			_zone_prefetch_log.append({"zone": zone_id, "milliseconds": elapsed,
				"speed_raw": float(plan.get("speed_raw", 0.0)),
				"radius_raw": float(plan.get("prefetch_radius_raw", 0.0))})
			print("ZONE_PREFETCH={\"zone\":%d,\"ms\":%d,\"speed_raw\":%.1f,\"radius_raw\":%.1f}" % [
				zone_id, elapsed, float(plan.get("speed_raw", 0.0)),
				float(plan.get("prefetch_radius_raw", 0.0))])
	if not DaocZoneLodPlanner.same_lod_selection(_zone_lod_plan, plan):
		_zone_lod_plan = plan
		_horizon_dirty = true
		refresh_distant_terrain_if_stale_r10()
	else:
		_zone_lod_plan = plan
	return _zone_lod_plan


func zone_lod_plan_report_p1_33() -> Dictionary:
	var report := _zone_lod_plan.duplicate(true)
	report["prefetch_enabled"] = zone_prefetch_enabled
	report["near_border_lod_enabled"] = distant_near_border_lod_enabled
	report["settings"] = P1_33_SETTINGS.duplicate()
	report["prefetch_log"] = _zone_prefetch_log.duplicate(true)
	return report


func describe() -> Dictionary:
	var streamer := zone_streamer() if session != null else null
	return {
		"ok": session != null,
		"scope": "R6 DaocGameWorld",
		"start_zone": start_zone,
		"current_zone": current_zone,
		"base": _base,
		"resident": streamer.loaded_zones() if streamer != null else [],
		"max_resident_zones": max_resident_zones,
		"horizon_owned": streamer != null and streamer.has_horizon_branch(),
		"session_slots_present": {
			"zone_streamer": session != null and session.zone_streamer != null,
		},
	}


func _apply_outward_decor_options() -> void:
	if not is_inside_tree():
		return
	for runtime in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("daoc_grass_runtime"):
		if is_ancestor_of(runtime):
			runtime.call("set_outward_rocks_enabled", outward_rocks_enabled)
			runtime.call("set_outward_flowers_enabled", outward_flowers_enabled)


# ============================================================================
# P1-76 — le serveur nomme l'animation (0x72 / 0x1B / 0x73 / 0xBC), le client
# la joue : gestes d'incantation exportes par le Lab (`cast_<geste>_<phase>`),
# coups et defenses de canims.csv, effets de speffects.csv en particules de
# remplacement. Voir DaocServerAnimationRuntime.
# ============================================================================

## Particules de remplacement pour les effets de sort (DaocSpellVfxPlaceholder).
## Decoche : gestes seuls, aucun effet visuel.
@export var server_spell_vfx_enabled: bool = true
## Trace chaque paquet d'animation du serveur dans la console Godot.
@export var server_animation_log: bool = false
var _server_animations: DaocServerAnimationRuntime = null


func _mount_server_animations_p1_76() -> void:
	if _online_runtime == null or _combat_client == null or _server_animations != null:
		return
	_server_animations = DaocServerAnimationRuntimeScript.new()
	_server_animations.name = "DaocServerAnimationRuntime"
	add_child(_server_animations)
	_server_animations.weapon_family = weapon_animation_family  # P1-130
	_server_animations.setup(_combat_client, _local_server, _online_player_object_id(), {
		"world_scale": world_scale,
		"vfx_enabled": server_spell_vfx_enabled,
		"log_to_console": server_animation_log,
		"client_root": daoc_client_root,
	})
	var bound: Dictionary = _server_animations.bind(_online_runtime)
	# P1-133 : 0x74 serveur -> garde du joueur -> armes degainees / rangees.
	if _online_runtime.has_signal("attack_mode_changed") and not _online_runtime.is_connected("attack_mode_changed", _on_online_attack_mode):
		_online_runtime.connect("attack_mode_changed", _on_online_attack_mode)
	_combat_client.server_attack_mode = 1 if _online_runtime.get("server_attack_mode") == true else 0
	if not bool(bound.get("ok", false)):
		push_warning("P1-76: animations serveur partiellement branchees : %s" % str(bound))


# ============================================================================
# P1-77 — /quit : retour a l'ecran de selection du personnage.
#
# Le serveur repond a /quit par un compte a rebours (0xAF), puis par 0xA4 Quit
# quand il a RETIRE le personnage du monde ; le client d'origine revient alors
# a la selection et redemande la liste (0xFC). Ici le monde n'a pas de
# demontage propre (zone, joueur, peuplement, UI, arbitre miroir) : on recharge
# la scene entiere, ce qui ferme la connexion, et le frontend REPREND tout seul
# jusqu'a la selection (mode Online, royaume, connexion, liste) grace a une
# consigne laissee sur la racine de l'arbre. Une reconnexion, pas une reprise
# de session : c'est assume, et note dans A_TESTER.
# ============================================================================

const RESUME_AFTER_QUIT_META := "daoc_resume_after_quit"


func _on_online_player_quit(total_out: bool, level: int) -> void:
	if _text_windows != null:
		_text_windows.push_console_line("Le serveur a retire %s du monde (niveau %d)%s. Retour a la selection..." % [
			str(_online_character.get("name", "le personnage")), level, ", deconnexion complete" if total_out else ""])
	var realm_id := int(_online_character.get("realm_id", 1))
	get_tree().root.set_meta(RESUME_AFTER_QUIT_META, {"mode": "ONLINE", "realm_id": realm_id,
		"character": str(_online_character.get("name", "")), "total_out": total_out})
	# 2026-09-27 (retour live /stuck, liste vide) : fermer la connexion
	# EXPLICITEMENT avant de recharger. Sans cela le socket mourait avec la
	# scene et le serveur gardait la session jusqu a son propre delai : la
	# reconnexion recevait une liste vide.
	if _online_runtime != null and is_instance_valid(_online_runtime) and _online_runtime.has_method("stop"):
		_online_runtime.call("stop", "player_quit")
	get_tree().call_deferred("reload_current_scene")


# ============================================================================
# P1-78 — progression et interactions PNJ en ligne.
#
# 0x91 CharacterPointsUpdate -> barre d'experience (via l'arbitre miroir, pour
# que le pont d'interface continue de ne lire que snapshot()) ; 0x81 Dialog ->
# fenetre Oui / Non qui repond par 0x82 ; 0xAE PlayerDeath -> message et
# rappel de /release ; 0x83 QuestEntry -> journal (console pour l'instant) ;
# double clic sur un PNJ -> 0xB0 + 0x7A ObjectInteractRequest.
# ============================================================================

var _online_points_updates := 0
var _online_dialogs := 0
var _online_quests: Dictionary = {}
var _online_dialog_panel: Control = null
var _online_pending_dialog: Dictionary = {}


func _on_online_player_points(points: Dictionary) -> void:
	_online_points_updates += 1
	if _local_server != null and _local_server.has_method("apply_remote_player_points"):
		_local_server.apply_remote_player_points(points)
	if _daoc_ui_bridge != null:
		_daoc_ui_bridge.push_player()
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_spec_points", "points: %d" % int(points.get("skill_specialty_points", 0)))
		# P1-106 : la fenetre des caracteristiques montre les points de royaume.
		_daoc_ui_bus.publish("stats_realm_points", str(int(points.get("realm_points", 0))))
	# P1-110 : la perte d experience a la mort se lit ici.
	_track_experience_after_points(points)
	# P1-109 : rang de royaume, titre, bounty points.
	_on_online_career(points)


func _on_online_player_died(death: Dictionary) -> void:
	var killed := int(death.get("killed_id", -1))
	if killed != _online_player_object_id():
		return
	_play_online_player_persistent_animation("death")
	set_player_dead(true)
	if _text_windows != null:
		var killer := int(death.get("killer_id", 0))
		var killer_name := ""
		if _local_server != null and killer > 0:
			killer_name = str((_local_server.snapshot(killer) as Dictionary).get("name", ""))
		var suffix := " (tue par %s)" % killer_name if killer_name != "" else ""
		_text_windows.push_console_line("Vous etes mort%s. Tapez /release pour revenir a votre point de liaison." % suffix)
	# P1-110 : l ecran de mort ; la perte d XP se lira sur le 0x91 suivant.
	_show_death_screen(death)


func _on_online_quest_entry(quest: Dictionary) -> void:
	var index := int(quest.get("index", 0))
	if bool(quest.get("cleared", false)):
		_online_quests.erase(index)
		_refresh_quest_journal()
		return
	_online_quests[index] = quest.duplicate(true)
	_refresh_quest_journal()
	if _text_windows != null:
		_text_windows.push_console_line("Quete %d : %s - %s" % [index, str(quest.get("name", "")), str(quest.get("description", ""))])
		for goal in quest.get("goals", []) as Array:
			var mark := "[x]" if bool((goal as Dictionary).get("achieved", false)) else "[ ]"
			_text_windows.push_console_line("   %s %s" % [mark, str((goal as Dictionary).get("text", ""))])


func _on_online_dialog(dialog: Dictionary) -> void:
	_online_dialogs += 1
	var text := str(dialog.get("text", ""))
	if _text_windows != null and text != "":
		_text_windows.push_console_line(text)
	if int(dialog.get("type", 0)) != 1:
		# Type Ok / None : rien a repondre, le texte suffit.
		return
	_online_pending_dialog = dialog.duplicate(true)
	_show_online_dialog_panel(text)


func _show_online_dialog_panel(text: String) -> void:
	if _online_dialog_panel == null:
		var layer := CanvasLayer.new()
		layer.name = "DaocOnlineDialogLayer"
		layer.layer = 90
		add_child(layer)
		var panel := PanelContainer.new()
		panel.name = "DaocOnlineDialog"
		panel.custom_minimum_size = Vector2(420, 0)
		var box := VBoxContainer.new()
		box.name = "Box"
		panel.add_child(box)
		var label := Label.new()
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(400, 0)
		box.add_child(label)
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(buttons)
		var yes := Button.new()
		yes.name = "Yes"
		yes.text = "Oui"
		yes.pressed.connect(func(): answer_online_dialog(true))
		buttons.add_child(yes)
		var no := Button.new()
		no.name = "No"
		no.text = "Non"
		no.pressed.connect(func(): answer_online_dialog(false))
		buttons.add_child(no)
		layer.add_child(panel)
		_online_dialog_panel = panel
	(_online_dialog_panel.get_node("Box/Text") as Label).text = text
	_online_dialog_panel.visible = true
	# Recentre : la taille minimale n'est connue qu'apres le texte.
	_online_dialog_panel.reset_size()
	_online_dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func answer_online_dialog(accept: bool) -> Dictionary:
	if _online_dialog_panel != null:
		_online_dialog_panel.visible = false
	if _online_pending_dialog.is_empty():
		return {"ok": false, "reason": "aucun dialogue en attente"}
	var dialog := _online_pending_dialog
	_online_pending_dialog = {}
	if _online_runtime == null or not _online_runtime.has_method("send_dialog_response"):
		return {"ok": false, "reason": "runtime sans reponse de dialogue"}
	var result: Dictionary = _online_runtime.call("send_dialog_response", dialog, accept) as Dictionary
	if _text_windows != null:
		_text_windows.push_console_line("-> %s (%s)" % ["Oui" if accept else "Non", str(dialog.get("kind", ""))])
	return result


func _try_online_interact_at_screen(screen_position: Vector2) -> bool:
	if _combat_client == null or _online_runtime == null or not _online_runtime.has_method("send_interact"):
		return false
	if not _combat_client.has_method("_pick_object_at_screen"):
		return false
	var object_id := int(_combat_client.call("_pick_object_at_screen", screen_position, mouse_targeting_pixel_tolerance, false))
	if object_id < 0 or object_id == _online_player_object_id():
		return false
	# P1-115 : double clic sur une porte = 0x99 (FUN_0042bd35), pas un 0x7A.
	if _online_door_objects.has(object_id):
		return bool(request_door_toggle_for_object(object_id).get("ok", false))
	return bool(request_online_interact(object_id).get("ok", false))


func request_online_interact(object_id: int) -> Dictionary:
	if _online_runtime == null or not _online_runtime.has_method("send_interact"):
		return {"ok": false, "reason": "runtime sans interaction"}
	# Meme precaution que pour un sort : la position du paquet doit etre la
	# position courante, pas celle d'il y a 250 ms.
	_online_move_clock = online_movement_send_interval_sec
	_tick_online_movement(0.0)
	_online_runtime.call("send_target", object_id, false)
	var result: Dictionary = _online_runtime.call("send_interact", object_id) as Dictionary
	if _text_windows != null:
		var name := str(object_id)
		if _local_server != null:
			name = str((_local_server.snapshot(object_id) as Dictionary).get("name", name))
		if bool(result.get("ok", false)):
			_text_windows.push_console_line("-> vous parlez a %s." % name)
		else:
			_text_windows.push_console_line("Interaction refusee : %s" % str(result.get("error", "?")))
	return result


func get_online_progress_snapshot() -> Dictionary:
	return {"points_updates": _online_points_updates, "dialogs": _online_dialogs,
		"quests": _online_quests.duplicate(true), "pending_dialog": not _online_pending_dialog.is_empty()}


## P1-86 — la preuve qui manque : les 0x16 d'Eden en hexadecimal, avec, pour
## chaque icone recue, ce que `icons.csv` en fait. Ecrit a chaque livre / liste
## recus, dans `reports/online/last_skill_packets.json`. C'est ce fichier qui
## dira si les identifiants d'icone du serveur suivent la table du client.
const ONLINE_SKILL_PACKETS_REPORT := "res://reports/online/last_skill_packets.json"


func _write_online_skill_packets_report() -> void:
	if _online_runtime == null or not _online_runtime.has_method("various_update_log"):
		return
	var icons: Dictionary = {}
	for entry_value in _online_spell_entries + _online_skill_entries:
		var entry := entry_value as Dictionary
		var icon := int(entry.get("icon", 0))
		if icon > 0 and _spell_icon_atlas != null and not icons.has(str(icon)):
			icons[str(icon)] = {"name": str(entry.get("name", "")), "line": str(entry.get("line", "")), "resolved": _spell_icon_atlas.resolve(icon, str(entry.get("icon_family", "spell")))}
	var report := {
		"written": Time.get_datetime_string_from_system(),
		"character": str(_online_character.get("name", "")),
		"packets_0x16": _online_runtime.call("various_update_log"),
		"spell_lines": _online_spell_lines,
		"skills": _online_all_skills,
		"icon_resolution": icons,
		"atlas": _spell_icon_atlas.report if _spell_icon_atlas != null else {},
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/online"))
	var file := FileAccess.open(ONLINE_SKILL_PACKETS_REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))


## P1-87 — /sit : `sit_down` puis `sit_idle` en boucle ; /stand ou un pas :
## `stand_up`. /quit assoit aussi (le serveur l'exige pendant le compte a
## rebours). Les clips viennent de anims.csv « Sit Down / Sit Idle / Stand Up »
## exportes par le Lab (online_heyvena : 43 clips).
var _sit_requested_msec := -100000
var _sit_changes := 0


func is_player_sitting() -> bool:
	var visual: Node = _combat_client.call("_resolve_player_visual") as Node if _combat_client != null and _combat_client.has_method("_resolve_player_visual") else null
	return visual != null and "sitting" in visual and bool(visual.get("sitting"))


func set_player_sitting(value: bool, local_request: bool = true) -> bool:
	var visual: Node = _combat_client.call("_resolve_player_visual") as Node if _combat_client != null and _combat_client.has_method("_resolve_player_visual") else null
	if visual == null or not visual.has_method("sit"):
		return false
	if local_request:
		_sit_requested_msec = Time.get_ticks_msec()
	var changed: bool = bool(visual.call("sit")) if value else bool(visual.call("stand"))
	if changed:
		_sit_changes += 1
	return changed


func get_player_pose_snapshot() -> Dictionary:
	var visual: Node = _combat_client.call("_resolve_player_visual") as Node if _combat_client != null and _combat_client.has_method("_resolve_player_visual") else null
	return {"sitting": is_player_sitting(), "changes": _sit_changes,
		"has_sit_clips": visual != null and visual.has_method("has_clip") and bool(visual.call("has_clip", "sit_idle")),
		"state": str(visual.get("current_state")) if visual != null and "current_state" in visual else ""}


## P1-97 — 0x89 : le serveur ressuscite (release, resurrection). Le drapeau
## mort tombe, la posture repart.
func _on_online_player_revived(object_id: int) -> void:
	if object_id != _online_player_object_id() and object_id > 0:
		return
	set_player_dead(false)
	_clear_online_player_persistent_animation()
	if _text_windows != null:
		_text_windows.push_console_line("Vous revenez a la vie.")
	_hide_death_screen()


## ═══════════════════════════════════════════════════════════════════════════
## P1-98 — GLISSER-DEPOSER : inventaire <-> sac, et objets dans la quickbar
##
## Client d'origine (game.dll decompile) : un objet de la quickbar et les
## touches « arme 1 main / 2 mains / distance » envoient 0x71 UseSlot
## (logement, type d'usage) ; un glisser-deposer entre deux logements envoie
## 0xDD PlayerMoveItem. Le serveur repond par 0x02 : c'est lui qui deplace.
## Hors ligne, l'arbitre local fait le meme travail (request_equip /
## request_unequip / request_move_item) et le jeu d'armes actif est un choix
## visuel tenu ici.
## ═══════════════════════════════════════════════════════════════════════════
var _offline_active_weapon_slots := -1
var _inventory_moves_sent := 0
var _items_given := 0


func _use_inventory_slot(inventory_slot: int, use_type: int = 0) -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	if online_mode and _online_runtime != null and _online_runtime.has_method("send_use_slot"):
		return _online_runtime.call("send_use_slot", inventory_slot, use_type) as Dictionary
	# Hors ligne : les logements d'arme changent le jeu d'armes visible.
	if inventory_slot in [10, 11]:
		_offline_active_weapon_slots = 0x10
	elif inventory_slot == 12:
		_offline_active_weapon_slots = 0x22
	elif inventory_slot == 13:
		_offline_active_weapon_slots = 0x33
	else:
		return {"ok": false, "reason": "usage d objet non arbitre hors ligne"}
	if _local_server != null:
		_on_player_inventory_changed(_local_server.player_inventory_snapshot())
	return {"ok": true, "offline_active_weapon_slots": _offline_active_weapon_slots}


## Un objet glisse d'un logement a un autre. `from`/`to` : eInventorySlot.
## P1-121 — donner un objet a ce qui est sous la souris, comme le client
## d origine : 0xDD vers `1000 + ObjectID` (OpenDAoC MoveItemToTargetObject).
## Le serveur decide : un forgeron propose la reparation (dialogue 0x81 avec
## le prix, oui = 0x82), un PNJ de quete prend l objet, un joueur ouvre un
## echange (0xEA). Hors ligne, personne ne recoit d objet.
func give_inventory_item_at_screen(from_slot: int, screen_position: Vector2) -> Dictionary:
	if from_slot < 0 or player_dead:
		return {"ok": false, "reason": "logement invalide ou mort"}
	if _combat_client == null or not _combat_client.has_method("_pick_object_at_screen"):
		return {"ok": false, "reason": "pas de ciblage"}
	var object_id := int(_combat_client.call("_pick_object_at_screen", screen_position, mouse_targeting_pixel_tolerance, false))
	if object_id < 0 or object_id == _online_player_object_id():
		return {"ok": false, "reason": "rien sous la souris"}
	return give_inventory_item_to(from_slot, object_id)


func give_inventory_item_to(from_slot: int, object_id: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_move_item"):
		_console("Donner un objet : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	# OpenDAoC ne demande que la distance (GIVE_ITEM_DISTANCE), pas la cible.
	var result: Dictionary = _online_runtime.call("send_move_item", from_slot, 1000 + object_id, 1) as Dictionary
	if bool(result.get("ok", false)):
		_items_given += 1
		var name := str(object_id)
		if _local_server != null:
			name = str((_local_server.snapshot(object_id) as Dictionary).get("name", name))
		_console("-> objet du logement %d donne a %s" % [from_slot, name])
	return result


func move_inventory_item(from_slot: int, to_slot: int) -> Dictionary:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0:
		return {"ok": false, "reason": "logements identiques ou invalides"}
	if player_dead:
		return {"ok": false, "reason": "mort"}
	var result: Dictionary = {}
	if online_mode:
		if _online_runtime == null or not _online_runtime.has_method("send_move_item"):
			return {"ok": false, "reason": "runtime absent"}
		result = _online_runtime.call("send_move_item", from_slot, to_slot, 1) as Dictionary
	elif _local_server != null:
		var to_equipment := to_slot < 40
		var from_equipment := from_slot < 40
		if from_equipment and not to_equipment and _local_server.has_method("request_unequip"):
			result = _local_server.request_unequip(from_slot)
		elif not from_equipment and to_equipment and _local_server.has_method("request_equip"):
			result = _local_server.request_equip(from_slot)
		elif _local_server.has_method("request_move_item"):
			result = _local_server.call("request_move_item", from_slot, to_slot) as Dictionary
		else:
			result = {"ok": false, "reason": "deplacement sac -> sac non arbitre hors ligne"}
	else:
		result = {"ok": false, "reason": "aucune autorite"}
	if bool(result.get("ok", false)):
		_inventory_moves_sent += 1
	if _text_windows != null:
		_text_windows.push_console_line("Deplacement %d -> %d : %s" % [from_slot, to_slot,
			"envoye" if bool(result.get("ok", false)) else str(result.get("reason", result.get("error", "refuse")))])
	return result


func inventory_drag_snapshot() -> Dictionary:
	return {"moves_sent": _inventory_moves_sent, "offline_active_weapon_slots": _offline_active_weapon_slots}


## P1-99 — 0x7F : la liste complete des effets actifs remplace la barre.
var _effect_bar: CanvasLayer = null
var _online_effect_updates := 0


func _on_online_effects(effects: Array) -> void:
	_online_effect_updates += 1
	if _effect_bar != null:
		_effect_bar.set_effects(effects)


func effect_bar_snapshot() -> Dictionary:
	var snapshot: Dictionary = _effect_bar.get_debug_snapshot() if _effect_bar != null else {"count": 0, "effects": []}
	snapshot["updates"] = _online_effect_updates
	snapshot["cancels_sent"] = _online_effect_cancels_sent
	return snapshot


## P1-108 — annuler un buff (clic droit, 0xF8), la concentration (0x75 /
## 0x76), le grise de delai (0xD6) et la fenetre du pet (0x88 / 0x8A). Tout
## part au serveur et rien ne change localement avant sa reponse : le 0x7F,
## le 0x75 et le 0x88 qui reviennent font l affichage.
var _concentration_window: CanvasLayer = null
var _pet_window: CanvasLayer = null
var _online_effect_cancels_sent := 0
var _online_concentration_updates := 0
var _online_disable_updates := 0
var _online_pet_updates := 0


func _on_effect_cancel_requested(effect: Dictionary) -> void:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_cancel_effect"):
		if _text_windows != null:
			_text_windows.push_console_line("Hors ligne : l annulation d un effet n est pas branchee sur l arbitre local.")
		return
	var result: Dictionary = _online_runtime.call("send_cancel_effect", int(effect.get("tooltip_id", effect.get("effect_id", 0)))) as Dictionary
	if bool(result.get("ok", false)):
		_online_effect_cancels_sent += 1
		if _text_windows != null:
			_text_windows.push_console_line("-> annulation de %s demandee au serveur." % str(effect.get("name", "?")))
	elif _text_windows != null:
		_text_windows.push_console_line("Annulation non envoyee : %s" % str(result.get("error", "?")))


func _on_online_concentration(effects: Array) -> void:
	_online_concentration_updates += 1
	if _concentration_window != null:
		_concentration_window.set_effects(effects)
	if _text_windows != null and not effects.is_empty():
		_text_windows.push_console_line("Concentration : %d buff(s) maintenu(s), %d point(s)." % [effects.size(), int(_concentration_window.total_concentration()) if _concentration_window != null else 0])


func _on_concentration_remove_requested(index: int) -> void:
	if _online_runtime == null or not _online_runtime.has_method("send_remove_concentration"):
		return
	var result: Dictionary = _online_runtime.call("send_remove_concentration", index) as Dictionary
	if _text_windows != null:
		_text_windows.push_console_line("-> retrait du buff de concentration %d %s." % [index, "demande" if bool(result.get("ok", false)) else "refuse : " + str(result.get("error", "?"))])


func _on_online_skills_disabled(entries: Array) -> void:
	_online_disable_updates += 1
	if _quickbars != null and _online_runtime != null and _online_runtime.has_method("disabled_skills"):
		_quickbars.set_disabled_skills(_online_runtime.call("disabled_skills") as Dictionary)
	if _text_windows != null:
		for value in entries:
			var entry := value as Dictionary
			var seconds := int(entry.get("seconds", 0))
			if seconds <= 0:
				continue
			var name := _online_entry_name_for_disable(entry)
			_text_windows.push_console_line("%s en delai : %d s." % [name, seconds])


func _online_entry_name_for_disable(entry: Dictionary) -> String:
	var key := ""
	if str(entry.get("kind", "")) == "spell":
		key = "spell:%d:%d" % [int(entry.get("line_index", 0)), int(entry.get("spell_index", 0))]
	else:
		key = "skill:%d" % int(entry.get("skill_index", 0))
	for value in _online_spell_entries + _online_skill_entries:
		if str((value as Dictionary).get("disable_key", "")) == key:
			return str((value as Dictionary).get("name", key))
	return key


func _on_online_pet_window(pet: Dictionary) -> void:
	_online_pet_updates += 1
	if _pet_window != null:
		_pet_window.apply_pet_window(pet)
	if _text_windows != null:
		match str(pet.get("action", "")):
			"open":
				_text_windows.push_console_line("Pet #%d : fenetre ouverte (%s, %s)." % [int(pet.get("pet_id", 0)), str(pet.get("aggro", "")), str(pet.get("walk", ""))])
			"close":
				_text_windows.push_console_line("Pet : fenetre fermee.")


func _pet_entity_info(object_id: int) -> Dictionary:
	if _local_server == null or object_id <= 0:
		return {}
	var snapshot: Dictionary = _local_server.snapshot(object_id)
	if snapshot.is_empty():
		return {}
	return {"name": str(snapshot.get("name", "")), "level": int(snapshot.get("level", 0)), "health_percent": float(snapshot.get("health_percent", 100.0))}


func _on_pet_command_requested(aggro: int, walk: int, command: int) -> void:
	if _online_runtime == null or not _online_runtime.has_method("send_pet_command"):
		return
	var result: Dictionary = _online_runtime.call("send_pet_command", aggro, walk, command) as Dictionary
	if _text_windows != null:
		_text_windows.push_console_line("-> ordre au pet (%d/%d/%d) %s." % [aggro, walk, command, "envoye" if bool(result.get("ok", false)) else "refuse : " + str(result.get("error", "?"))])


func spell_control_snapshot() -> Dictionary:
	return {"cancels_sent": _online_effect_cancels_sent, "concentration_updates": _online_concentration_updates,
		"disable_updates": _online_disable_updates, "pet_updates": _online_pet_updates,
		"concentration": _concentration_window.get_debug_snapshot() if _concentration_window != null else {},
		"pet": _pet_window.get_debug_snapshot() if _pet_window != null else {},
		"disabled_slots": _quickbars.disabled_slots() if _quickbars != null else 0}


## P1-102 — le delve. En ligne le serveur ecrit le texte (0xD8 -> 0xC4) ;
## hors ligne la fenetre montre ce que le 0x02 local porte.
var _detail_window: CanvasLayer = null
var _detail_requests_sent := 0


func request_item_detail(slot: int) -> Dictionary:
	if online_mode and _online_runtime != null and _online_runtime.has_method("send_detail_request"):
		var result: Dictionary = _online_runtime.call("send_detail_request", 1, slot) as Dictionary
		if bool(result.get("ok", false)):
			_detail_requests_sent += 1
		return result
	var snapshot: Dictionary = _local_server.player_inventory_snapshot() if _local_server != null else {}
	var slots: Dictionary = snapshot.get("slots", {}) as Dictionary
	var item: Dictionary = slots.get(slot, slots.get(str(slot), {})) as Dictionary
	if item.is_empty():
		return {"ok": false, "reason": "logement vide"}
	var text := DaocAlphaInventoryScript.item_tooltip(item)
	var lines: Array = text.split("\n")
	lines.pop_front()
	_on_online_detail_window({"ok": true, "caption": str(item.get("name", "")), "lines": lines, "source": "local_0x02"})
	return {"ok": true, "offline": true}


func _on_online_detail_window(detail: Dictionary) -> void:
	if _detail_window != null:
		_detail_window.show_detail(detail)
	if _text_windows != null:
		_text_windows.push_console_line("[%s] %s" % [str(detail.get("caption", "")), " | ".join(PackedStringArray(detail.get("lines", [])))])


func detail_snapshot() -> Dictionary:
	return {"requests_sent": _detail_requests_sent, "shown": _detail_window.shown_count if _detail_window != null else 0,
		"last": _detail_window.last_detail if _detail_window != null else {}}


## ═══════════════════════════════════════════════════════════════════════════
## P1-105 — LE GROUPE ET LE SOCIAL
##
## Le serveur tient le groupe ; le client recoit la liste (0x16/06) et les
## mises a jour (0x70) et remplit la fenetre `minigroup` du client d origine
## (canaux group_name0..7, group_health0..7, group_power0..7,
## group_endurance0..7). Sans groupe la fenetre se cache. Les commandes
## (/invite, /disband, /makeleader, /autosplit, /friend, /who, /afk, /anon,
## /send) passent par 0xAF ; l invitation recue est un dialogue 0x81 code 5
## que P1-78 sait deja accepter ou refuser (0x82).
## ═══════════════════════════════════════════════════════════════════════════
var _online_group: Dictionary = {}
var _online_group_updates := 0
var _online_friends: Array = []
var _online_emotes := 0
const GROUP_SLOTS := 8


func _on_online_group(group: Dictionary) -> void:
	_online_group = group.duplicate(true)
	_online_group_updates += 1
	var members: Array = group.get("members", [])
	if _daoc_ui_bus != null:
		for slot in range(GROUP_SLOTS):
			var member: Dictionary = {}
			for value in members:
				if int((value as Dictionary).get("index", -1)) == slot:
					member = value as Dictionary
			var label := ""
			if not member.is_empty():
				label = str(member.get("name", ""))
				if int(member.get("level", 0)) > 0:
					label += " (%d)" % int(member.get("level", 0))
				if "other_region" in (member.get("flags", []) as Array):
					label += " *"
				elif "dead" in (member.get("flags", []) as Array):
					label += " (mort)"
			_daoc_ui_bus.publish("group_name%d" % slot, label)
			_daoc_ui_bus.publish("group_health%d" % slot, int(member.get("health_percent", 0)) if not member.is_empty() else 0)
			_daoc_ui_bus.publish("group_power%d" % slot, int(member.get("mana_percent", 0)) if not member.is_empty() else 0)
			_daoc_ui_bus.publish("group_endurance%d" % slot, int(member.get("endurance_percent", 0)) if not member.is_empty() else 0)
			_daoc_ui_bus.publish("group_class%d" % slot, str(member.get("class_name", "")) if not member.is_empty() else "")
			_daoc_ui_bus.publish("group_level%d" % slot, int(member.get("level", 0)) if not member.is_empty() else 0)
	if _daoc_ui_manager != null:
		_daoc_ui_manager.set_window_visible("minigroup", bool(group.get("in_group", false)))


func _on_online_friends(friends: Array, added: Array, removed: Array) -> void:
	_online_friends = friends.duplicate(true)
	if _text_windows != null:
		for name in added:
			_text_windows.push_console_line("%s rejoint votre liste d'amis." % str(name))
		for name in removed:
			_text_windows.push_console_line("%s quitte votre liste d'amis." % str(name))


func _on_online_emote(emote: Dictionary) -> void:
	_online_emotes += 1
	var object_id := int(emote.get("object_id", -1))
	var clip := str(emote.get("name", ""))
	var who := "Vous" if object_id == _online_player_object_id() else str((_local_server.snapshot(object_id) as Dictionary).get("name", "quelqu'un")) if _local_server != null else "quelqu'un"
	if _text_windows != null:
		_text_windows.push_console_line("%s : /%s" % [who, clip])
	# Le clip d emote s il a ete exporte par le Lab (wave, bow, dance...) ;
	# sinon rien, jamais un clip de combat a la place.
	if object_id == _online_player_object_id():
		# P1-110 : /pray (DOL GamePlayer.Pray) assoit le joueur et diffuse l emote Pray.
		if int(emote.get("emote", -1)) == EMOTE_PRAY:
			set_player_sitting(true)
		_play_online_player_animation([clip, "emote_" + clip])
	else:
		# P1-110 : l emote d un AUTRE joue sur sa scene.
		_play_remote_emote(object_id, clip)


func group_snapshot() -> Dictionary:
	return {"group": _online_group.duplicate(true), "updates": _online_group_updates,
		"friends": _online_friends.duplicate(true), "emotes": _online_emotes}


## P1-105 — /macro <nom> <commande...> : une case de quickbar qui envoie la
## commande. Le client d origine fait pareil et le serveur n en voit que la
## commande finale. Sans arguments : le mode d emploi.
var _macros_defined := 0


func _define_macro_from_command(command: String) -> Dictionary:
	var parts := command.strip_edges().split(" ", false)
	if parts.size() < 3 or _quickbars == null:
		if _text_windows != null:
			_text_windows.push_console_line("Usage : /macro <nom> <commande>, ex. /macro Face /face")
		return {"ok": false, "reason": "usage"}
	var name := str(parts[1])
	var macro_command := " ".join(parts.slice(2))
	if not macro_command.begins_with("/"):
		macro_command = "/" + macro_command
	var result: Dictionary = _quickbars.define_macro(name, macro_command)
	if bool(result.get("ok", false)):
		_macros_defined += 1
		if _text_windows != null:
			# P1-113 : la macro est au CURSEUR, a deposer dans une case (clic gauche) ;
			# une case prise s echange, Echap ou clic droit lache l icone.
			_text_windows.push_console_line("Macro %s -> « %s » : cliquez une case de quickbar pour la poser (Echap pour lacher)." % [name, macro_command])
	elif _text_windows != null:
		_text_windows.push_console_line("Macro refusee : %s" % str(result.get("reason", "?")))
	return result


## ═══════════════════════════════════════════════════════════════════════════
## P1-106 — LES CARACTERISTIQUES DANS LA FENETRE DU CLIENT
##
## 0xFB (caracteristiques ou resistances) et 0x16/05 (degats, competence
## d arme, facteur d armure) remplissent `stats_attributes_window` : la valeur
## affichee est base + buffs + objets (plafonnes) + capacites de royaume ;
## blanche sans bonus, VERTE avec un bonus, ROUGE avec un malus, et le survol
## detaille base et bonus (constat utilisateur du 2026-09-21 sur le client
## d origine). Hors ligne, l arbitre local n envoie rien de tel : la fenetre
## garde ses valeurs de gabarit.
## ═══════════════════════════════════════════════════════════════════════════
var _online_stats_updates := 0
var _online_character_stats: Dictionary = {}
var _online_character_resists: Dictionary = {}
const STAT_LABELS := {"strength": "Force", "dexterity": "Dexterite", "constitution": "Constitution", "quickness": "Vivacite",
	"intelligence": "Intelligence", "piety": "Piete", "empathy": "Empathie", "charisma": "Charisme",
	"crush": "Contondant", "slash": "Tranchant", "thrust": "Perforant", "heat": "Chaleur", "cold": "Froid",
	"matter": "Matiere", "body": "Corps", "spirit": "Esprit", "energy": "Energie"}


static func stat_tooltip(label: String, entry: Dictionary, percent: bool = false) -> String:
	var unit := " %" if percent else ""
	var lines: Array[String] = ["%s : %d%s" % [label, int(entry.get("total", 0)), unit],
		"Base : %d%s" % [int(entry.get("base", 0)), unit]]
	var buff := int(entry.get("buff", 0))
	var item := int(entry.get("item", 0))
	var item_effective := int(entry.get("item_effective", 0))
	var ability := int(entry.get("ability", 0))
	if buff != 0:
		lines.append("Sorts : %+d%s" % [buff, unit])
	if item != 0:
		var cap_note := " (plafond %d, %d perdus)" % [int(entry.get("item_cap", 0)), item - item_effective] if item_effective < item else ""
		lines.append("Objets : %+d%s%s" % [item_effective, unit, cap_note])
	if ability != 0:
		lines.append("Capacites de royaume : %+d%s" % [ability, unit])
	if buff == 0 and item == 0 and ability == 0:
		lines.append("Aucun bonus")
	return "\n".join(lines)


func _publish_stat_table(table: Dictionary, percent: bool) -> void:
	if _daoc_ui_bus == null:
		return
	var entries: Dictionary = table.get("entries", {}) as Dictionary
	for name in entries:
		var entry := entries[name] as Dictionary
		var channel := "stats_%s" % str(name)
		_daoc_ui_bus.publish(channel, "%d%s" % [int(entry.get("total", 0)), "%" if percent else ""])
		_daoc_ui_bus.publish(channel + "_color", str(entry.get("colour", "white")))
		_daoc_ui_bus.publish(channel + "_tooltip", stat_tooltip(str(STAT_LABELS.get(name, name)), entry, percent))


func _on_online_character_stats(stats: Dictionary) -> void:
	_online_stats_updates += 1
	_online_character_stats = stats.duplicate(true)
	_publish_stat_table(stats, false)
	if _daoc_ui_bus != null and int(stats.get("max_health", 0)) > 0:
		_daoc_ui_bus.publish("stats_hitpoints", str(int(stats.get("max_health", 0))))
		_daoc_ui_bus.publish("stats_hitpoints_tooltip", "Vie maximale : %d\nConstitution perdue a la mort : %d" % [int(stats.get("max_health", 0)), int(stats.get("constitution_lost_at_death", 0))])
	if _local_server != null and _local_server.has_method("apply_remote_player_max_health") and int(stats.get("max_health", 0)) > 0:
		_local_server.call("apply_remote_player_max_health", int(stats.get("max_health", 0)))


func _on_online_character_resists(resists: Dictionary) -> void:
	_online_stats_updates += 1
	_online_character_resists = resists.duplicate(true)
	_publish_stat_table(resists, true)


func _on_online_weapon_armor(values: Dictionary) -> void:
	_online_stats_updates += 1
	if _daoc_ui_bus == null:
		return
	_daoc_ui_bus.publish("stats_weapon_damage", "%.2f" % float(values.get("weapon_damage", 0.0)))
	_daoc_ui_bus.publish("stats_weapon_skill", str(int(values.get("weapon_skill", 0))))
	_daoc_ui_bus.publish("stats_armor_factor", str(int(values.get("armor_factor", 0))))


func character_stats_snapshot() -> Dictionary:
	return {"updates": _online_stats_updates, "stats": _online_character_stats.duplicate(true), "resists": _online_character_resists.duplicate(true)}


## ═══════════════════════════════════════════════════════════════════════════
## P1-107 — L ENTRAINEUR
##
## Le serveur envoie la fenetre (0x7B, plusieurs pages) quand on parle a un
## entraineur ou sur demande (0x7B client) ; la fenetre prepare des niveaux
## vises et « Former » envoie le 0x53 (spes + capacites de royaume). Les
## points reviennent par 0x91, la fenetre par un nouveau 0x7B. /train
## <ligne> <niveau> reste la voie texte de DOL.
## ═══════════════════════════════════════════════════════════════════════════
var _trainer_window: CanvasLayer = null
var _trainer_pages := 0
var _train_requests_sent := 0


func request_trainer_window() -> Dictionary:
	if online_mode and _online_runtime != null and _online_runtime.has_method("send_trainer_window_request"):
		var result: Dictionary = _online_runtime.call("send_trainer_window_request") as Dictionary
		if _text_windows != null and not bool(result.get("ok", false)):
			_text_windows.push_console_line("Entraineur : %s" % str(result.get("error", "?")))
		return result
	if _text_windows != null:
		_text_windows.push_console_line("Entraineur : indisponible hors ligne.")
	return {"ok": false, "reason": "hors ligne"}


func request_train(spec_targets: Dictionary, ra_targets: Dictionary) -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_train"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_train", spec_targets, ra_targets) as Dictionary
	if bool(result.get("ok", false)):
		_train_requests_sent += 1
	if _text_windows != null:
		_text_windows.push_console_line("Formation demandee (%d spe, %d capacites) : %s" % [spec_targets.size(), ra_targets.size(), "envoyee" if bool(result.get("ok", false)) else str(result.get("error", "refusee"))])
	return result


func _on_online_trainer_window(trainer: Dictionary) -> void:
	_trainer_pages += 1
	if _trainer_window != null and (trainer.has("specs") or trainer.has("realm_abilities")):
		_trainer_window.show_trainer(trainer)


func trainer_snapshot() -> Dictionary:
	var snapshot: Dictionary = _trainer_window.get_debug_snapshot() if _trainer_window != null else {}
	snapshot["pages"] = _trainer_pages
	snapshot["train_requests_sent"] = _train_requests_sent
	return snapshot


## ═══════════════════════════════════════════════════════════════════════════
## P1-109 — CARRIERE ET COMMANDES DE COMBAT
##
## Personnage : le rang de royaume et son titre se DEDUISENT des points du
## 0x91 (DaocOpenDaocCareerCodec, table DOL) — le serveur ne les envoie pas ;
## les bounty points viennent du meme 0x91. `/settitle` ouvre la fenetre
## « Player Statistics » (0xC4 octet 0 a 1) ; un clic sur un titre renvoie
## `/settitle <index>`, le serveur confirme par 0x4C/0x0B. `/freelevel` :
## l etat arrive en 0x4C/0x09. `/ml` demande la fenetre des Master Levels
## (dialogue 0x19 -> 0x13). L entraineur de Champion (0x7B code 2) forme par
## 0x7C. `/bonuses` envoie le 0xCA (le bouton « Bonuses » du client
## d origine) et le serveur repond par un 0xC4 ordinaire. /respec, /level,
## /realm, /duel, /assist, /range, /cancelstyle, /gtrange, /groundassist sont
## des commandes DOL : elles partent telles quelles par 0xAF.
##
## Combat : /face, /stick, /follow n existent PAS dans DOL — ce sont les
## actions 64, 63, 62 du keyboard.dat (game.dll les nomme Face / Stick /
## Follow). Ici : /face tourne le moteur vers la cible (le 0xA9 porte le cap)
## ; /stick et /follow poussent l axe avant tant que la cible est loin
## (200 / 500 unites) et se rompent au premier deplacement du joueur. La
## cible au sol (touche 44 ou /gt) est le point du terrain sous la souris,
## envoye en 0xEC et marque au sol ; le serveur peut la deplacer (0xEC
## serveur). Les armes de siege : 0xF5 ouvre la fenetre, ses boutons
## renvoient 0xF5 (une commande par seconde). 0xF3 est le compte a rebours
## (release, siege). 0xF6 impose une cible (/assist).
## ═══════════════════════════════════════════════════════════════════════════
const CareerCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCareerCodec.gd")
const CombatControlCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocCombatControlCodec.gd")
const STICK_RANGE_RAW := 200.0
const FOLLOW_RANGE_RAW := 500.0
const FOLLOW_MAX_RANGE_RAW := 4000.0
const CLIENT_ONLY_VERBS := ["/face", "/stick", "/follow", "/gt", "/groundtarget", "/bonuses", "/ml", "/siege", "/stealth", "/hide"]
var _titles_window: CanvasLayer = null
var _master_level_window: CanvasLayer = null
var _champion_window: CanvasLayer = null
var _siege_window: CanvasLayer = null
var _timer_window: CanvasLayer = null
var _online_career: Dictionary = {}
var _online_free_level: Dictionary = {}
var _online_title := ""
var _online_titles_updates := 0
var _online_career_updates := 0
var _online_free_level_updates := 0
var _online_master_level_updates := 0
var _online_champion_updates := 0
var _online_siege_updates := 0
var _online_siege_animations := 0
var _online_timer_updates := 0
var _online_target_changes := 0
var _title_choices_sent := 0
var _bonuses_requests_sent := 0
var _master_level_requests_sent := 0
var _champion_trains_sent := 0
var _siege_commands_sent := 0
var _ground_targets_sent := 0
var _follow_mode := ""
var _follow_target_id := -1
var _faces_done := 0
var _follow_breaks := 0
var _ground_target: Dictionary = {}
var _ground_target_marker: Node3D = null


func _mount_career_windows_p1_109() -> void:
	_titles_window = preload("res://src/daoc/ui/DaocTitlesWindow.gd").new()
	_titles_window.name = "DaocTitlesWindow"
	add_child(_titles_window)
	_titles_window.title_chosen.connect(_on_title_chosen)
	_master_level_window = preload("res://src/daoc/ui/DaocMasterLevelWindow.gd").new()
	_master_level_window.name = "DaocMasterLevelWindow"
	add_child(_master_level_window)
	_master_level_window.master_level_requested.connect(request_master_level_window)
	_champion_window = preload("res://src/daoc/ui/DaocChampionTrainerWindow.gd").new()
	_champion_window.name = "DaocChampionTrainerWindow"
	add_child(_champion_window)
	if _spell_icon_atlas != null:
		_champion_window.set_icon_atlas(_spell_icon_atlas)
	_champion_window.champion_train_requested.connect(request_champion_train)
	_siege_window = preload("res://src/daoc/ui/DaocSiegeWindow.gd").new()
	_siege_window.name = "DaocSiegeWindow"
	add_child(_siege_window)
	_siege_window.siege_command_requested.connect(request_siege_command)
	_timer_window = preload("res://src/daoc/ui/DaocTimerWindow.gd").new()
	_timer_window.name = "DaocTimerWindow"
	add_child(_timer_window)
	var router: Node = session.input_router if session != null else null
	if router != null:
		for pair in [["follow_requested", "toggle_follow"], ["face_requested", "face_target"],
				["ground_target_requested", "set_ground_target_at_screen"], ["auto_move_broken", "_on_auto_move_broken"]]:
			if router.has_signal(str(pair[0])) and not router.is_connected(str(pair[0]), Callable(self, str(pair[1]))):
				router.connect(str(pair[0]), Callable(self, str(pair[1])))


func _bind_online_career() -> void:
	if _online_runtime == null:
		return
	for pair in [["titles_received", "_on_online_titles"], ["title_updated", "_on_online_title_updated"],
			["free_level_received", "_on_online_free_level"], ["master_level_window_received", "_on_online_master_level_window"],
			["champion_trainer_received", "_on_online_champion_page"], ["ground_target_received", "_on_online_ground_target"],
			["siege_interface_received", "_on_online_siege_interface"], ["siege_animation_received", "_on_online_siege_animation"],
			["timer_window_received", "_on_online_timer_window"], ["target_change_received", "_on_online_target_change"]]:
		if _online_runtime.has_signal(str(pair[0])):
			var receiver := Callable(self, str(pair[1]))
			if not _online_runtime.is_connected(str(pair[0]), receiver):
				_online_runtime.connect(str(pair[0]), receiver)
	for pair in [["last_titles", "_on_online_titles"], ["last_free_level", "_on_online_free_level"],
			["last_master_level_window", "_on_online_master_level_window"], ["last_timer_window", "_on_online_timer_window"]]:
		if _online_runtime.has_method(str(pair[0])):
			var last: Dictionary = _online_runtime.call(str(pair[0])) as Dictionary
			if not last.is_empty():
				call(str(pair[1]), last)


## Un verbe que le client traite lui-meme ; rend true s il a ete consomme.
func _handle_client_only_command(command: String) -> bool:
	var parts := command.strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var verb := str(parts[0]).to_lower()
	if not (verb in CLIENT_ONLY_VERBS):
		return false
	match verb:
		"/face":
			face_target()
		"/stick":
			toggle_follow("stick")
		"/follow":
			toggle_follow("follow")
		"/gt", "/groundtarget":
			set_ground_target_at_screen(get_viewport().get_mouse_position() if get_viewport() != null else Vector2.ZERO)
		"/bonuses":
			request_bonuses_list()
		"/stealth", "/hide":
			# Raccourci CLIENT : DOL n a pas de commande, la spe s active par 0xBB.
			var stealth_result := request_stealth()
			if not bool(stealth_result.get("ok", false)) and _text_windows != null:
				_text_windows.push_console_line("Stealth indisponible : %s" % str(stealth_result.get("reason", stealth_result.get("error", "?"))))
		"/ml":
			request_master_level_window(int(parts[1]) if parts.size() > 1 and str(parts[1]).is_valid_int() else 0)
		"/siege":
			var action := CombatControlCodecScript.siege_action_code(str(parts[1])) if parts.size() > 1 else 0
			if action <= 0:
				_console("Usage : /siege arm|aim|fire|move|repair|salvage|release|stop|load [munition]")
			else:
				request_siege_command(action, int(parts[2]) if parts.size() > 2 and str(parts[2]).is_valid_int() else 0)
	return true


func _console(text: String) -> void:
	if _text_windows != null:
		_text_windows.push_console_line(text)


## ── /face, /stick, /follow ───────────────────────────────────────────────
func _target_world_position() -> Dictionary:
	if _combat_client == null or _local_server == null:
		return {}
	var target_id := int(_combat_client.get("current_target_id"))
	if target_id < 0 or not _local_server.has_entity(target_id) or target_id == _local_server.player_object_id:
		return {}
	return {"target_id": target_id, "position": _local_server.get_entity_world_position(target_id)}


func _player_world_position() -> Vector3:
	if _local_server != null and _local_server.player_object_id >= 0:
		return _local_server.get_entity_world_position(_local_server.player_object_id)
	return Vector3.ZERO


## Tourne le moteur vers la cible : le cap part dans le prochain 0xA9 (en
## ligne) ou sert tel quel (hors ligne). Le mort ne tourne pas (P1-97).
func face_target() -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	var target := _target_world_position()
	if target.is_empty():
		_console("Vous n avez pas de cible.")
		return {"ok": false, "reason": "pas de cible"}
	var motor: Node = session.player if session != null else null
	if motor == null or not ("heading_deg" in motor):
		return {"ok": false, "reason": "pas de moteur"}
	var here := _player_world_position()
	var there: Vector3 = target["position"]
	var heading := rad_to_deg(atan2(there.y - here.y, there.x - here.x))
	motor.set("heading_deg", fposmod(heading, 360.0))
	_faces_done += 1
	return {"ok": true, "heading_deg": fposmod(heading, 360.0), "target_id": int(target["target_id"])}


## `mode` : « stick » (colle a 200) ou « follow » (suit a 500) ; le meme mode
## demande deux fois s eteint, comme la touche du client d origine.
func toggle_follow(mode: String) -> Dictionary:
	if _follow_mode == mode:
		stop_follow("toggle")
		return {"ok": true, "mode": ""}
	if player_dead:
		return {"ok": false, "reason": "mort"}
	var target := _target_world_position()
	if target.is_empty():
		_console("Vous n avez pas de cible.")
		return {"ok": false, "reason": "pas de cible"}
	_follow_mode = mode
	_follow_target_id = int(target["target_id"])
	if session != null and session.input_router != null and session.input_router.has_method("runlock_disable"):
		session.input_router.call("runlock_disable")
	_console("Vous %s %s." % ["collez a" if mode == "stick" else "suivez", str((_local_server.snapshot(_follow_target_id) as Dictionary).get("name", "?"))])
	return {"ok": true, "mode": mode, "target_id": _follow_target_id}


func stop_follow(reason: String = "") -> void:
	if _follow_mode == "":
		return
	_follow_mode = ""
	_follow_target_id = -1
	if session != null and session.input_router != null and session.input_router.has_method("set_auto_move"):
		session.input_router.call("set_auto_move", false)
	if reason == "moved":
		_follow_breaks += 1
	_console("Vous ne suivez plus personne.")


func _on_auto_move_broken() -> void:
	stop_follow("moved")


func follow_snapshot() -> Dictionary:
	return {"mode": _follow_mode, "target_id": _follow_target_id, "faces_done": _faces_done, "breaks": _follow_breaks}


## A chaque image : viser la cible et avancer si elle est plus loin que la
## distance du mode. Une cible morte, partie ou hors de 4000 unites arrete tout.
func _tick_follow() -> void:
	if _follow_mode == "":
		return
	var router: Node = session.input_router if session != null else null
	var motor: Node = session.player if session != null else null
	if router == null or motor == null or _local_server == null or player_dead or not _local_server.has_entity(_follow_target_id):
		stop_follow("lost")
		return
	var target_state: Dictionary = _local_server.snapshot(_follow_target_id) as Dictionary
	if not bool(target_state.get("is_alive", true)):
		stop_follow("dead")
		return
	var here := _player_world_position()
	var there: Vector3 = _local_server.get_entity_world_position(_follow_target_id)
	var dx := there.x - here.x
	var dy := there.y - here.y
	var distance := sqrt(dx * dx + dy * dy)
	if distance > FOLLOW_MAX_RANGE_RAW:
		stop_follow("range")
		return
	var stop_at := STICK_RANGE_RAW if _follow_mode == "stick" else FOLLOW_RANGE_RAW
	if distance > 1.0:
		motor.set("heading_deg", fposmod(rad_to_deg(atan2(dy, dx)), 360.0))
	if router.has_method("set_auto_move"):
		router.call("set_auto_move", true, 1.0 if distance > stop_at else 0.0)


## ── cible au sol ─────────────────────────────────────────────────────────
func godot_to_daoc(znum: int, global: Vector3) -> Vector3:
	var zone_data: Dictionary = _state.zone_runtime.get(znum, {}) as Dictionary
	var origin3: Vector3 = zone_data.get("origin3", Vector3.ZERO) as Vector3
	var local := global - origin3
	return Vector3(local.x / world_scale, local.z / world_scale, local.y / (world_scale * maxf(height_exaggeration, 0.0001)))


## Le point du terrain sous la souris : un rayon de la camera, contre le
## sol (masque 1, celui du moteur). Sans sol touche, rien n est envoye.
func set_ground_target_at_screen(screen_position: Vector2) -> Dictionary:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return {"ok": false, "reason": "pas de camera"}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var space := camera.get_world_3d().direct_space_state if camera.get_world_3d() != null else null
	if space == null:
		return {"ok": false, "reason": "pas d espace physique"}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 20000.0, 1)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_console("Aucun sol sous le pointeur.")
		return {"ok": false, "reason": "aucun sol"}
	var motor: Node = session.player if session != null else null
	var zone := int(motor.get("daoc_zone")) if motor != null and "daoc_zone" in motor else current_zone
	if zone < 0:
		zone = current_zone
	var local := godot_to_daoc(zone, hit["position"] as Vector3)
	var origin2 := _origin(zone)
	return set_ground_target(int(round(origin2.x + local.x)), int(round(origin2.y + local.y)), int(round(local.z)), true, hit["position"] as Vector3)


func set_ground_target(x: int, y: int, z: int, visible: bool = true, global: Variant = null) -> Dictionary:
	_ground_target = {"x": x, "y": y, "z": z, "visible": visible, "source": "client"}
	_place_ground_target_marker(global)
	if online_mode and _online_runtime != null and _online_runtime.has_method("send_ground_target"):
		var result: Dictionary = _online_runtime.call("send_ground_target", x, y, z, visible) as Dictionary
		if bool(result.get("ok", false)):
			_ground_targets_sent += 1
		else:
			_console("Cible au sol non envoyee : %s" % str(result.get("error", "?")))
		return result
	return {"ok": true, "offline": true}


func _place_ground_target_marker(global: Variant) -> void:
	if _ground_target_marker == null:
		_ground_target_marker = MeshInstance3D.new()
		_ground_target_marker.name = "DaocGroundTargetMarker"
		var mesh := TorusMesh.new()
		# Un anneau de 40 unites DAoC de rayon, pose a plat : visible a 500 unites.
		mesh.inner_radius = 30.0 * world_scale
		mesh.outer_radius = 40.0 * world_scale
		(_ground_target_marker as MeshInstance3D).mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.9, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(_ground_target_marker as MeshInstance3D).material_override = material
		add_child(_ground_target_marker)
	if global == null:
		var motor: Node = session.player if session != null else null
		var zone := int(motor.get("daoc_zone")) if motor != null and "daoc_zone" in motor else current_zone
		if zone < 0:
			zone = current_zone
		var origin2 := _origin(zone)
		global = daoc_to_godot(zone, float(_ground_target.get("x", 0)) - origin2.x, float(_ground_target.get("y", 0)) - origin2.y, float(_ground_target.get("z", 0)))
	_ground_target_marker.global_position = (global as Vector3) + Vector3(0.0, 2.0 * world_scale, 0.0)
	_ground_target_marker.visible = true


func clear_ground_target() -> void:
	_ground_target = {}
	if _ground_target_marker != null:
		_ground_target_marker.visible = false


func ground_target_snapshot() -> Dictionary:
	return {"target": _ground_target.duplicate(true), "sent": _ground_targets_sent, "marker_visible": _ground_target_marker != null and _ground_target_marker.visible}


func _on_online_ground_target(target: Dictionary) -> void:
	if bool(target.get("cleared", false)):
		clear_ground_target()
		return
	_ground_target = {"x": int(target.get("x", 0)), "y": int(target.get("y", 0)), "z": int(target.get("z", 0)), "visible": true, "source": "server"}
	_place_ground_target_marker(null)


## ── carriere ─────────────────────────────────────────────────────────────
func _on_online_career(points: Dictionary) -> void:
	var career: Dictionary = points.get("career", {}) as Dictionary
	if career.is_empty():
		return
	_online_career = career.duplicate(true)
	_online_career_updates += 1
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_realm_points_tooltip", "Points de royaume : %d\n%s — %s\nBounty points : %d\nProchain echelon : %d (reste %d)" % [
			int(career.get("realm_points", 0)), str(career.get("realm_rank_label", "")), str(career.get("realm_title", "")),
			int(career.get("bounty_points", 0)), int(career.get("next_level_points", 0)), int(career.get("points_to_next_level", 0))])
		_daoc_ui_bus.publish("stats_bounty_points", str(int(career.get("bounty_points", 0))))
		_daoc_ui_bus.publish("stats_realm_rank", "%s %s" % [str(career.get("realm_rank_label", "")), str(career.get("realm_title", ""))])
	if _local_server != null and _local_server.has_method("apply_remote_player_career"):
		_local_server.call("apply_remote_player_career", career)


func career_snapshot() -> Dictionary:
	return {"career": _online_career.duplicate(true), "updates": _online_career_updates, "title": _online_title, "free_level": _online_free_level.duplicate(true),
		"titles_updates": _online_titles_updates, "title_choices_sent": _title_choices_sent, "bonuses_requests_sent": _bonuses_requests_sent,
		"master_level_updates": _online_master_level_updates, "master_level_requests_sent": _master_level_requests_sent,
		"champion_updates": _online_champion_updates, "champion_trains_sent": _champion_trains_sent,
		"titles": _titles_window.get_debug_snapshot() if _titles_window != null else {},
		"master_levels": _master_level_window.get_debug_snapshot() if _master_level_window != null else {},
		"champion": _champion_window.get_debug_snapshot() if _champion_window != null else {}}


func _on_online_titles(titles: Dictionary) -> void:
	_online_titles_updates += 1
	if _titles_window != null:
		_titles_window.set_current_title(_online_title)
		_titles_window.show_titles(titles)
	_console("[%s] %d titre(s) disponible(s)." % [str(titles.get("caption", "")), (titles.get("titles", []) as Array).size()])


func _on_online_title_updated(update: Dictionary) -> void:
	if not bool(update.get("mine", true)):
		return
	_online_title = str(update.get("title", ""))
	if _titles_window != null:
		_titles_window.set_current_title(_online_title)
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_title", _online_title)
	_console("Titre : %s" % (_online_title if _online_title != "" else "(aucun)"))


func _on_title_chosen(index: int) -> void:
	_title_choices_sent += 1
	_on_text_command_submitted("/settitle %d" % index)


func _on_online_free_level(state: Dictionary) -> void:
	_online_free_level = state.duplicate(true)
	_online_free_level_updates += 1
	var text := ""
	match str(state.get("state_name", "")):
		"eligible":
			text = "Un niveau gratuit vous attend : /freelevel pour le prendre, /freelevel decline pour le refuser."
		"waiting":
			text = "Prochain niveau gratuit dans %d min." % int(state.get("minutes_remaining", 0))
		"level_and_waiting":
			text = "Niveau gratuit : il faut encore un niveau et %d min." % int(state.get("minutes_remaining", 0))
		"level_waiting":
			text = "Niveau gratuit : il faut encore un niveau."
		"above_level":
			text = "Niveau gratuit : vous depassez le niveau maximal."
	if text != "":
		_console(text)
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_free_level", str(state.get("state_name", "")))


func request_bonuses_list() -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_bonuses_request"):
		_console("Bonus : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_bonuses_request") as Dictionary
	if bool(result.get("ok", false)):
		_bonuses_requests_sent += 1
	return result


func request_master_level_window(master_level: int = 0) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_master_level_request"):
		_console("Master Levels : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_master_level_request", master_level) as Dictionary
	if bool(result.get("ok", false)):
		_master_level_requests_sent += 1
		_master_level_requested_msec = Time.get_ticks_msec()
	return result


## 2026-09-29 : la fenetre ne s ouvre QUE sur demande (/ml, fleches) ; un 0x13
## recu sans demande (entree monde, rejeu) est garde sans masquer la vue.
var _master_level_requested_msec := -1
const MASTER_LEVEL_REQUEST_WINDOW_MSEC := 15000


func _on_online_master_level_window(window: Dictionary) -> void:
	_online_master_level_updates += 1
	if _master_level_window == null:
		return
	var requested := _master_level_requested_msec >= 0 \
		and Time.get_ticks_msec() - _master_level_requested_msec <= MASTER_LEVEL_REQUEST_WINDOW_MSEC
	if requested or _master_level_window.is_shown():
		_master_level_requested_msec = -1
		_master_level_window.show_window(window)
	else:
		_master_level_window.last_window = window.duplicate(true)


func _on_online_champion_page(page: Dictionary) -> void:
	_online_champion_updates += 1
	if _champion_window != null:
		_champion_window.show_page(page)


func request_champion_train(line_index: int, row: int, column: int) -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_champion_train"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_champion_train", line_index, row, column) as Dictionary
	if bool(result.get("ok", false)):
		_champion_trains_sent += 1
	_console("Formation Champion (ligne %d, rangee %d, colonne %d) : %s" % [line_index, row, column, "envoyee" if bool(result.get("ok", false)) else str(result.get("error", "refusee"))])
	return result


## ── siege, compte a rebours, cible imposee ───────────────────────────────
func _on_online_siege_interface(siege: Dictionary) -> void:
	_online_siege_updates += 1
	if _siege_window != null:
		_siege_window.apply_siege_interface(siege)


func _on_online_siege_animation(animation: Dictionary) -> void:
	_online_siege_animations += 1
	_console("Siege %d : %s (%d ms)" % [int(animation.get("object_id", 0)), str(animation.get("action", "")), int(animation.get("time_msec", 0))])


func request_siege_command(action: int, ammo: int = 0) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_siege_command"):
		_console("Siege : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_siege_command", action, ammo) as Dictionary
	if bool(result.get("ok", false)):
		_siege_commands_sent += 1
	elif str(result.get("error", "")) == "siege_command_too_soon":
		_console("Trop tot : une commande de siege par seconde.")
	return result


func _on_online_timer_window(timer: Dictionary) -> void:
	_online_timer_updates += 1
	if _timer_window != null:
		_timer_window.apply_timer(timer)


func _on_online_target_change(object_id: int) -> void:
	_online_target_changes += 1
	if _combat_client == null:
		return
	if object_id <= 0:
		_combat_client.clear_target()
	elif _local_server != null and _local_server.has_entity(object_id):
		_combat_client.target_object(object_id)


func combat_control_snapshot() -> Dictionary:
	return {"siege_updates": _online_siege_updates, "siege_animations": _online_siege_animations, "siege_commands_sent": _siege_commands_sent,
		"timer_updates": _online_timer_updates, "target_changes": _online_target_changes,
		"siege": _siege_window.get_debug_snapshot() if _siege_window != null else {},
		"timer": _timer_window.get_debug_snapshot() if _timer_window != null else {},
		"follow": follow_snapshot(), "ground_target": ground_target_snapshot()}


## ═══════════════════════════════════════════════════════════════════════════
## P1-110 — MORT ET BUTIN, QUÊTES ET PNJ, JOUEURS DISTANTS, SOCIAL
##
## Mort : l écran de mort (DaocDeathScreen) se pose sur le 0xAE de P1-97 et
## se retire au 0x89 ; la perte d expérience se LIT sur le premier 0x91 qui
## suit (level_permill qui recule — DOL DeathXPLoss) et la constitution perdue
## sur le 0xFB (P1-106). `/pray` est une commande DOL : elle exige de cibler
## SA pierre tombale (0xD9 model 1) à moins de 2000, immobile ; le serveur
## assoit le joueur et diffuse l émote Pray (0xF9), jouée ici. Le butin en
## ligne : DOL dépose des OBJETS (0xD9 WorldInventoryItem, GameMoney) sur le
## cadavre ; ils deviennent ciblables dans l arbitre miroir
## (world_objects_targetable) et se ramassent par 0xB0 puis 0xB5 (un octet,
## comme game.dll) — touche « Nearest Loot » (72), double clic, ou /pickup.
##
## Quêtes : le journal (DaocQuestJournalWindow, touche 82 ou /journal) lit
## les 0x83 de P1-78 et la tâche (index 0) ; « Abandonner » envoie 0x4F. La
## fenêtre d offre / récompense (0x81 dont le premier u16 vaut 0x22 / 0x21,
## DaocQuestOfferWindow) répond par 0x40 (réponse 1 + choix). L icône au-dessus
## du PNJ vient du 0x4C sous-code 0x07 (Label3D). `/quest` et `/task` sont
## des commandes DOL (texte).
##
## PNJ et joueurs : 0xDB ModelChange rescale (taille) ou remplace (modèle :
## despawn + spawn) ; un autre joueur reçoit la scène que le Lab a exportée
## pour lui (P1-73, par son nom) et sa poupée suit le 0x15 (P1-93 sur sa
## scène) ; sans scène exportée ni scène de race, le cône. Les émotes des
## autres (0xF9) jouent leur clip sur leur scène.
##
## Social : LFG (0x84 drapeau, 0x85 → 0x86 liste, DaocFindGroupWindow),
## emblème (0xE2 → DaocEmblemWindow → 0xE2), guilde / alliance / battlegroup
## / chatgroup / ignore / roleplay = commandes DOL par 0xAF ; les dialogues
## 0x03 / 0x08 sont les oui/non de P1-78 ; les canaux de chat 0x04 / 0x0b /
## 0x0c / 0x08 arrivent déjà nommés (P1-70).
## ═══════════════════════════════════════════════════════════════════════════
const QuestSocialCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocQuestSocialCodec.gd")
const CLIENT_ONLY_VERBS_P1_110 := ["/journal", "/pickup", "/lfgflag", "/lfglist", "/emblem"]
const LOOT_PICKUP_RANGE_RAW := 700.0
const EMOTE_PRAY := 0x2b
var _death_screen: CanvasLayer = null
var _quest_journal: CanvasLayer = null
var _quest_offer: CanvasLayer = null
var _find_group_window: CanvasLayer = null
var _emblem_window: CanvasLayer = null
var _online_last_level_permill := -1
var _online_death_pending_loss := false
var _online_experience_lost_permill := 0
var _online_task := ""
var _online_quest_windows := 0
var _online_quest_indicators := 0
var _online_model_changes := 0
var _online_find_group_updates := 0
var _online_emblem_dialogues := 0
var _online_equipment_updates := 0
var _remote_dolls: Dictionary = {}
var _remote_doll_reports: Dictionary = {}
var _pickups_sent := 0
var _quest_answers_sent := 0
var _quest_abandons_sent := 0
var _lfg_requests_sent := 0
var _emblems_sent := 0
var _remote_emotes_played := 0


func _mount_social_windows_p1_110() -> void:
	_death_screen = preload("res://src/daoc/ui/DaocDeathScreen.gd").new()
	_death_screen.name = "DaocDeathScreen"
	add_child(_death_screen)
	_death_screen.release_requested.connect(func(): _on_text_command_submitted("/release"))
	_quest_journal = preload("res://src/daoc/ui/DaocQuestJournalWindow.gd").new()
	_quest_journal.name = "DaocQuestJournalWindow"
	add_child(_quest_journal)
	_quest_journal.abandon_requested.connect(request_abandon_quest)
	_quest_offer = preload("res://src/daoc/ui/DaocQuestOfferWindow.gd").new()
	_quest_offer.name = "DaocQuestOfferWindow"
	add_child(_quest_offer)
	_quest_offer.answered.connect(answer_quest_window)
	_find_group_window = preload("res://src/daoc/ui/DaocFindGroupWindow.gd").new()
	_find_group_window.name = "DaocFindGroupWindow"
	add_child(_find_group_window)
	_find_group_window.refresh_requested.connect(func(): request_lfg_list())
	_find_group_window.flag_changed.connect(request_lfg_flag)
	_emblem_window = preload("res://src/daoc/ui/DaocEmblemWindow.gd").new()
	_emblem_window.name = "DaocEmblemWindow"
	add_child(_emblem_window)
	_emblem_window.emblem_chosen.connect(request_emblem)
	var router: Node = session.input_router if session != null else null
	if router != null:
		for pair in [["loot_requested", "pickup_nearest_loot"], ["quest_journal_requested", "toggle_quest_journal"]]:
			if router.has_signal(str(pair[0])) and not router.is_connected(str(pair[0]), Callable(self, str(pair[1]))):
				router.connect(str(pair[0]), Callable(self, str(pair[1])))
		# Double clic gauche sur un objet du monde = ramasser (le cadavre hors ligne garde P1-30).
		if router.has_signal("world_double_click") and not router.world_double_click.is_connected(_on_world_double_click_pickup):
			router.world_double_click.connect(_on_world_double_click_pickup)


func _bind_online_social() -> void:
	if _online_runtime == null:
		return
	for pair in [["quest_window_received", "_on_online_quest_window"], ["task_received", "_on_online_task"],
			["quest_indicator_received", "_on_online_quest_indicator"], ["model_changed", "_on_online_model_changed"], ["model_type_changed", "_on_online_model_type_changed"],
			["find_group_received", "_on_online_find_group"], ["emblem_dialogue_received", "_on_online_emblem_dialogue"],
			["equipment_received", "_on_online_equipment"]]:
		if _online_runtime.has_signal(str(pair[0])):
			var receiver := Callable(self, str(pair[1]))
			if not _online_runtime.is_connected(str(pair[0]), receiver):
				_online_runtime.connect(str(pair[0]), receiver)
	if _online_runtime.has_method("quest_journal"):
		var journal: Dictionary = _online_runtime.call("quest_journal") as Dictionary
		for key in journal.keys():
			_on_online_quest_entry(journal[key] as Dictionary)
	if _online_runtime.has_method("last_task"):
		var task: Dictionary = _online_runtime.call("last_task") as Dictionary
		if not task.is_empty():
			_on_online_task(task)
	if _online_runtime.has_method("quest_indicators"):
		var indicators: Dictionary = _online_runtime.call("quest_indicators") as Dictionary
		for key in indicators.keys():
			_on_online_quest_indicator(indicators[key] as Dictionary)


func _handle_client_only_command_p1_110(command: String) -> bool:
	var parts := command.strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var verb := str(parts[0]).to_lower()
	if not (verb in CLIENT_ONLY_VERBS_P1_110):
		return false
	match verb:
		"/journal":
			# DOL a aussi /journal (quetes accomplies, en texte) : la fenetre s ouvre ET la commande part.
			toggle_quest_journal()
			return false
		"/pickup":
			pickup_target()
		"/lfgflag":
			request_lfg_flag(parts.size() < 2 or str(parts[1]).to_lower() in ["on", "1", "oui"])
		"/lfglist":
			request_lfg_list()
		"/emblem":
			if _emblem_window != null:
				_emblem_window.show_window()
	return true


## ── mort ─────────────────────────────────────────────────────────────────
func _show_death_screen(death: Dictionary) -> void:
	_online_death_pending_loss = true
	_online_experience_lost_permill = 0
	if _death_screen == null:
		return
	var killer := int(death.get("killer_id", 0))
	var killer_name := ""
	if _local_server != null and killer > 0:
		killer_name = str((_local_server.snapshot(killer) as Dictionary).get("name", ""))
	_death_screen.show_death({"killer_id": killer, "killer_name": killer_name, "killed_id": int(death.get("killed_id", -1))})
	var con_lost := int(_online_character_stats.get("constitution_lost_at_death", 0))
	_death_screen.set_losses(-1, con_lost)


func _hide_death_screen() -> void:
	_online_death_pending_loss = false
	if _death_screen != null:
		_death_screen.hide_death()


## Le 0x91 qui suit la mort dit ce qu elle a coute : level_permill recule.
func _track_experience_after_points(points: Dictionary) -> void:
	var permill := int(points.get("level_permill", -1))
	if permill < 0:
		return
	if _online_death_pending_loss and _online_last_level_permill >= 0 and permill < _online_last_level_permill:
		_online_experience_lost_permill = _online_last_level_permill - permill
		_online_death_pending_loss = false
		_console("Vous perdez %d %% de votre niveau d experience." % int(round(float(_online_experience_lost_permill) / 10.0)))
		if _death_screen != null:
			_death_screen.set_losses(_online_experience_lost_permill, int(_online_character_stats.get("constitution_lost_at_death", 0)))
	_online_last_level_permill = permill


func death_snapshot() -> Dictionary:
	return {"screen": _death_screen.get_debug_snapshot() if _death_screen != null else {}, "experience_lost_permill": _online_experience_lost_permill,
		"pending_loss": _online_death_pending_loss, "last_level_permill": _online_last_level_permill, "pickups_sent": _pickups_sent}


## ── butin en ligne ───────────────────────────────────────────────────────
func _world_objects_nearby(radius: float) -> Array:
	var out: Array = []
	if _local_server == null:
		return out
	var here := _player_world_position()
	for entry_value in _local_server.targetable_entries():
		var entry := entry_value as Dictionary
		var object_id := int(entry.get("object_id", -1))
		var snap: Dictionary = _local_server.snapshot(object_id) as Dictionary
		if str(snap.get("entity_type", "")) != "object":
			continue
		var there: Vector3 = _local_server.get_entity_world_position(object_id)
		var distance := Vector2(there.x - here.x, there.y - here.y).length()
		if distance <= radius:
			out.append({"object_id": object_id, "name": str(snap.get("name", "")), "distance_raw": distance})
	out.sort_custom(func(a, b): return float(a["distance_raw"]) < float(b["distance_raw"]))
	return out


## Cibler le sac le plus proche et le ramasser (touche « Nearest Loot »).
func pickup_nearest_loot() -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	var candidates := _world_objects_nearby(LOOT_PICKUP_RANGE_RAW)
	if candidates.is_empty():
		_console("Rien a ramasser a proximite.")
		return {"ok": false, "reason": "rien a proximite"}
	var object_id := int((candidates[0] as Dictionary).get("object_id", -1))
	if _combat_client != null:
		_combat_client.target_object(object_id, false)
	return pickup_target()


## Ramasser la CIBLE (DOL PlayerPickUpRequestHandler prend TargetObject).
func pickup_target() -> Dictionary:
	if player_dead:
		return {"ok": false, "reason": "mort"}
	if _combat_client == null or _local_server == null:
		return {"ok": false, "reason": "pas de client de combat"}
	var target_id := int(_combat_client.get("current_target_id"))
	if target_id < 0:
		_console("Vous n avez pas de cible.")
		return {"ok": false, "reason": "pas de cible"}
	var snap: Dictionary = _local_server.snapshot(target_id) as Dictionary
	if str(snap.get("entity_type", "")) != "object":
		_console("Ce n est pas un objet a ramasser.")
		return {"ok": false, "reason": "cible pas un objet"}
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_pickup"):
		_console("Ramasser : indisponible hors ligne (le butin hors ligne est sur le cadavre, P1-30).")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_pickup") as Dictionary
	if bool(result.get("ok", false)):
		_pickups_sent += 1
		_console("-> ramasser %s" % str(snap.get("name", "")))
	return result


func _on_world_double_click_pickup(screen_position: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT or not online_mode or _combat_client == null:
		return
	var picked: Dictionary = _combat_client.pick_target_at_screen(screen_position, mouse_targeting_pixel_tolerance, mouse_targeting_max_distance_raw) as Dictionary
	if bool(picked.get("ok", false)) and str(picked.get("entity_type", "")) == "object":
		pickup_target()


## ── quêtes ───────────────────────────────────────────────────────────────
func toggle_quest_journal() -> void:
	if _quest_journal != null:
		_quest_journal.set_quests(_online_quests)
		_quest_journal.toggle()


func _refresh_quest_journal() -> void:
	if _quest_journal != null:
		_quest_journal.set_quests(_online_quests)


func _on_online_task(task: Dictionary) -> void:
	_online_task = str(task.get("text", ""))
	if _quest_journal != null:
		_quest_journal.set_task(_online_task)
	if _online_task != "":
		_console("Tache : %s" % _online_task)


func _on_online_quest_window(window: Dictionary) -> void:
	_online_quest_windows += 1
	if _quest_offer != null:
		_quest_offer.show_window(window)
	_console("[%s] %s : %s" % ["Offre de quete" if str(window.get("kind", "")) == "offer" else "Recompense de quete", str(window.get("name", "")), str(window.get("summary", ""))])


func answer_quest_window(accept: bool, chosen: Array, quest_id: int, npc_object_id: int) -> Dictionary:
	if not accept:
		_console("Quete %d : refusee (rien n est envoye, DOL ignore un refus)." % quest_id)
		return {"ok": true, "sent": false}
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_quest_reward"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_quest_reward", true, chosen, quest_id, npc_object_id) as Dictionary
	if bool(result.get("ok", false)):
		_quest_answers_sent += 1
	_console("Quete %d : %s (%d objet(s) choisi(s))" % [quest_id, "acceptee" if bool(result.get("ok", false)) else str(result.get("error", "refusee")), chosen.size()])
	return result


func request_abandon_quest(quest_index: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_remove_quest"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_remove_quest", quest_index) as Dictionary
	if bool(result.get("ok", false)):
		_quest_abandons_sent += 1
	_console("Quete abandonnee (index %d) : %s" % [quest_index, "envoyee" if bool(result.get("ok", false)) else str(result.get("error", "refusee"))])
	return result


func _on_online_quest_indicator(indicator: Dictionary) -> void:
	_online_quest_indicators += 1
	if _population != null and _population.has_method("set_quest_indicator"):
		_population.call("set_quest_indicator", int(indicator.get("object_id", 0)), str(indicator.get("glyph", "")))


func quest_snapshot() -> Dictionary:
	return {"quests": _online_quests.size(), "task": _online_task, "windows": _online_quest_windows, "indicators": _online_quest_indicators,
		"answers_sent": _quest_answers_sent, "abandons_sent": _quest_abandons_sent,
		"journal": _quest_journal.get_debug_snapshot() if _quest_journal != null else {},
		"offer": _quest_offer.get_debug_snapshot() if _quest_offer != null else {}}


## ── Furtivite (Stealth) ──────────────────────────────────────────────────
## DOL : la spe Stealth est la SEULE a porter un ISpecActionHandler
## (StealthSpecHandler) ; on l active par un 0xBB de type 0 a son index de spe.
## Le serveur repond 0x8D (GamePlayer.Stealth : 3 cache, 2 visible), un 0xB6
## de vitesse et « You are now hidden ». Le client d origine (FUN_00413a55)
## pose alors un drapeau sur SON modele et le rend translucide.
const STEALTH_TRANSPARENCY := 0.6
const SPEC_ACTION_NAMES := ["Stealth"]
var player_stealthed := false


func _on_online_model_type_changed(change: Dictionary) -> void:
	if int(change.get("object_id", -1)) != _online_player_object_id():
		return
	var model_type := int(change.get("model_type", -1))
	if model_type == 3:
		set_player_stealthed(true)
	elif model_type == 2:
		set_player_stealthed(false)


func set_player_stealthed(stealthed: bool) -> void:
	player_stealthed = stealthed
	var player := get("_player") as Node3D
	if player == null:
		return
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = STEALTH_TRANSPARENCY if stealthed else 0.0


## L entree Stealth recue en 0x16/01 (spe, skill_type 0), ou vide.
func online_stealth_skill() -> Dictionary:
	for value in _online_all_skills:
		var skill := value as Dictionary
		if str(skill.get("kind", "")) == "specialization" and str(skill.get("name", "")) == "Stealth":
			return skill
	return {}


func request_stealth() -> Dictionary:
	var skill := online_stealth_skill()
	if skill.is_empty() or _online_runtime == null:
		return {"ok": false, "reason": "pas de specialisation Stealth"}
	return _online_runtime.call("send_use_skill", skill) as Dictionary


## ── PNJ et joueurs distants ──────────────────────────────────────────────
func _on_online_model_changed(change: Dictionary) -> void:
	_online_model_changes += 1
	var object_id := int(change.get("object_id", -1))
	if object_id == _online_player_object_id() or _local_server == null:
		return
	var meta: Dictionary = _local_server.entity_meta(object_id)
	var new_model := int(change.get("model_id", -1))
	if not meta.is_empty() and new_model > 0 and new_model != int(meta.get("model_id", -1)):
		# Un autre modele : la scene est rebatie par la meme porte que l apparition.
		var snap: Dictionary = _local_server.snapshot(object_id) as Dictionary
		var entity := {"object_id": object_id, "entity_type": str(meta.get("entity_type", "npc")), "name": str(snap.get("name", "")), "level": int(snap.get("level", 0)),
			"model_id": new_model, "size": int(change.get("size", 0)), "realm": int(meta.get("realm", 0)), "flags": meta.get("flags", {})}
		var position: Vector3 = _local_server.get_entity_world_position(object_id)
		entity["x"] = position.x; entity["y"] = position.y; entity["z"] = position.z
		if _population != null:
			_population.despawn_one(object_id)
			_population.spawn_one(self, entity)
			var node: Node3D = _population.call("wrapper_of", object_id) as Node3D
			if node != null:
				_local_server.attach_entity_node(object_id, node)
		meta["model_id"] = new_model
		return
	if bool(change.get("size_changed", false)) and _population != null and _population.has_method("resize_one"):
		_population.call("resize_one", object_id, int(change.get("size", 0)))


## L equipement d un AUTRE joueur (0x15) sur sa scene, par la poupee P1-93 :
## une DaocPlayerEquipmentVisuals par joueur, configuree depuis le manifeste
## de sa scene exportee (apparence, genre). Un cone de repli n a pas de corps.
func _on_online_equipment(object_id: int, equipment: Dictionary) -> void:
	_online_equipment_updates += 1
	if object_id == _online_player_object_id() or _population == null or _local_server == null:
		return
	var snap: Dictionary = _local_server.snapshot(object_id) as Dictionary
	var wrapper: Node3D = _population.call("wrapper_of", object_id) as Node3D
	var visual: Node3D = wrapper.get_node_or_null("Visual") as Node3D if wrapper != null else null
	if not bool(snap.get("remote_player", false)):
		# 2026-09-29 : un PNJ humanoide equipe (garde, marchand a gabarit
		# d equipement DOL) : sa scene PNJ porte des vetements cuits ; il est
		# remonte sur la base de race du catalogue, puis habille comme un joueur.
		var meta: Dictionary = _local_server.entity_meta(object_id)
		if meta.is_empty() or str(meta.get("entity_type", "")) != "npc" or wrapper == null:
			return
		if visual == null or not visual.has_meta("daoc_appearance_id"):
			var model_id := int(meta.get("model_id", -1))
			if DaocPlayerCatalogAppearance.appearance_for_model(model_id) <= 0:
				_remote_doll_reports[object_id] = {"ok": false, "reason": "modele %d hors catalogue de races" % model_id}
				return
			var entity := {"object_id": object_id, "entity_type": "npc", "name": str(snap.get("name", "")), "level": int(snap.get("level", 0)),
				"model_id": model_id, "size": int(wrapper.get_meta("daoc_entity_size", 0)), "realm": int(meta.get("realm", 0)), "flags": meta.get("flags", {}),
				"heading": int(wrapper.get_meta("daoc_entity_heading", 0)), "force_catalog": true}
			var position: Vector3 = _local_server.get_entity_world_position(object_id)
			entity["x"] = position.x; entity["y"] = position.y; entity["z"] = position.z
			_population.despawn_one(object_id)
			_population.spawn_one(self, entity)
			wrapper = _population.call("wrapper_of", object_id) as Node3D
			if wrapper != null:
				_local_server.attach_entity_node(object_id, wrapper)
			visual = wrapper.get_node_or_null("Visual") as Node3D if wrapper != null else null
			_remote_dolls.erase(object_id)
	if visual == null:
		_remote_doll_reports[object_id] = {"ok": false, "reason": "pas de scene (cone de repli)"}
		return
	if not _remote_dolls.has(object_id):
		var doll: RefCounted = DaocPlayerEquipmentVisualsScript.new()
		var appearance_id := 2
		var gender := "female"
		if visual.has_meta("daoc_appearance_id"):
			appearance_id = int(visual.get_meta("daoc_appearance_id"))
			gender = "female" if appearance_id % 2 == 0 else "male"
		var manifest_path := str(wrapper.get_meta("daoc_manifest_path", ""))
		if manifest_path == "" and visual.scene_file_path != "":
			manifest_path = visual.scene_file_path.get_basename() + ".manifest.json"
		if FileAccess.file_exists(manifest_path):
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if manifest is Dictionary:
				appearance_id = int((manifest as Dictionary).get("appearance_id", appearance_id))
				gender = str((manifest as Dictionary).get("gender", gender))
		var configured: Dictionary = doll.configure(daoc_client_root, appearance_id, gender)
		if not bool(configured.get("ok", false)):
			_remote_doll_reports[object_id] = {"ok": false, "reason": str(configured.get("reason", ""))}
			return
		_remote_dolls[object_id] = doll
	var equipped: Dictionary = {}
	for value in equipment.get("items", []):
		var item := value as Dictionary
		if int(item.get("model_id", 0)) <= 0:
			continue
		equipped[int(item.get("slot", 0))] = {"model": int(item.get("model_id", 0)), "color": int(item.get("color", 0)), "extension": int(item.get("extension", 0)), "name": ""}
	var report: Dictionary = (_remote_dolls[object_id] as RefCounted).apply([visual], equipped, int(equipment.get("active_weapon_slots", -1)))
	_remote_doll_reports[object_id] = report


func remote_players_snapshot() -> Dictionary:
	return {"model_changes": _online_model_changes, "equipment_updates": _online_equipment_updates, "dolls": _remote_dolls.size(),
		"doll_reports": _remote_doll_reports.duplicate(true), "emotes_played": _remote_emotes_played}


## ── social ───────────────────────────────────────────────────────────────
func request_lfg_flag(flag: bool) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_lfg_flag"):
		_console("LFG : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_lfg_flag", flag) as Dictionary
	if bool(result.get("ok", false)):
		_lfg_requests_sent += 1
		_console("Cherche groupe : %s." % ("oui" if flag else "non"))
	return result


func request_lfg_list() -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_lfg_list"):
		_console("LFG : indisponible hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_lfg_list", not (_online_group.get("in_group", false) == false)) as Dictionary
	if bool(result.get("ok", false)):
		_lfg_requests_sent += 1
	if _find_group_window != null:
		_find_group_window.show_window()
	return result


func _on_online_find_group(list: Dictionary) -> void:
	_online_find_group_updates += 1
	if _find_group_window != null:
		_find_group_window.set_players(list.get("players", []))
		_find_group_window.show_window()
	_console("Cherche groupe : %d joueur(s)." % (list.get("players", []) as Array).size())


func _on_online_emblem_dialogue() -> void:
	_online_emblem_dialogues += 1
	if _emblem_window != null:
		_emblem_window.show_window()


func request_emblem(primary_color: int, secondary_color: int, pattern: int, logo: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_emblem"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_emblem", primary_color, secondary_color, pattern, logo) as Dictionary
	if bool(result.get("ok", false)):
		_emblems_sent += 1
	_console("Embleme (%d, %d, %d, %d) : %s" % [primary_color, secondary_color, pattern, logo, "envoye" if bool(result.get("ok", false)) else str(result.get("error", "refuse"))])
	return result


## L emote d un AUTRE (0xF9) sur sa scene, par le meme chemin que ses gestes
## de combat (P1-76). Le clip doit exister dans la scene ; sinon rien.
func _play_remote_emote(object_id: int, clip: String) -> bool:
	if _server_animations == null or not _server_animations.has_method("_play_npc"):
		return false
	var played := bool(_server_animations.call("_play_npc", object_id, [clip, "emote_" + clip]))
	if played:
		_remote_emotes_played += 1
	return played


func social_snapshot() -> Dictionary:
	return {"find_group_updates": _online_find_group_updates, "emblem_dialogues": _online_emblem_dialogues, "lfg_requests_sent": _lfg_requests_sent,
		"emblems_sent": _emblems_sent, "find_group": _find_group_window.get_debug_snapshot() if _find_group_window != null else {},
		"emblem": _emblem_window.get_debug_snapshot() if _emblem_window != null else {}}


## ═══════════════════════════════════════════════════════════════════════════
## P1-114 — MARCHAND, ARGENT, ENCOMBREMENT, ÉCHANGE
##
## Le marchand : le double clic sur un PNJ part déjà en 0x7A (P1-78) ; DOL
## répond par un 0x17 MerchantWindow PAR PAGE du catalogue, que
## `DaocMerchantWindow` empile. Acheter = 0x78 (index DANS LA PAGE, nombre,
## type de fenêtre) ; vendre = 0x79 (logement d inventaire) ; estimer = 0xE0,
## auquel le serveur répond par un message de chat, pas par un paquet.
##
## L argent : 0xFA MoneyUpdate, en cuivre découpé par dénomination, écrit sur
## la ligne du bas de `pperdoll.bmp` (elle portait des chiffres EN DUR depuis
## P1-21G). L encombrement : 0xBD, porté / maximum, sur la ligne « Enc: » de
## la même planche ; au-dessus du maximum DOL ralentit (0xB6, P1-82).
##
## Hors ligne il n y a pas de marchand : la bourse vient de `purse()` de
## l arbitre (P1-22C) et le poids se calcule par la règle DOL — poids des
## objets en DIXIÈMES de livre, équipement et sac divisés séparément, maximum
## = la Force du personnage.
##
## L échange entre joueurs : 0xEA du serveur, 0xEB du client (0 fermer, 1
## mettre à jour, 2 accepter). `/sell`, `/repair`, `/salvage`, `/discard` sont
## des commandes DOL et partent telles quelles en 0xAF.
## ═══════════════════════════════════════════════════════════════════════════
const MerchantCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocMerchantCodec.gd")
## `/appraise` n est PAS une commande DOL : le client d origine estime en
## faisant glisser un objet sur le marchand. Ce verbe est un raccourci du
## client pour le même 0xE0, comme `/pickup` l est pour le 0xB5 (P1-110).
const CLIENT_ONLY_VERBS_P1_114 := ["/appraise", "/shop"]
var _merchant_window: CanvasLayer = null
var _trade_window: CanvasLayer = null
var _online_merchant_pages := 0
var _online_money_updates := 0
var _online_encumberance_updates := 0
var _online_trade_updates := 0
var _merchant_buys_sent := 0
var _merchant_sells_sent := 0
var _merchant_appraisals_sent := 0
var _trade_packets_sent := 0
var _last_money_copper := -1
var _last_encumberance: Dictionary = {}


func _mount_merchant_windows_p1_114() -> void:
	_merchant_window = preload("res://src/daoc/ui/DaocMerchantWindow.gd").new()
	_merchant_window.name = "DaocMerchantWindow"
	add_child(_merchant_window)
	_merchant_window.buy_requested.connect(request_buy)
	_merchant_window.sell_requested.connect(request_sell)
	_merchant_window.appraise_requested.connect(request_appraise)
	_attach_xml_window_p1_134(_merchant_window, "merchant")
	_trade_window = preload("res://src/daoc/ui/DaocTradeWindow.gd").new()
	_trade_window.name = "DaocTradeWindow"
	add_child(_trade_window)
	_trade_window.update_requested.connect(_on_trade_update_requested)
	_trade_window.accept_requested.connect(_on_trade_accept_requested)
	_trade_window.close_requested.connect(_on_trade_close_requested)
	# Hors ligne, la bourse et le poids viennent de l arbitre : premier calcul au montage.
	refresh_offline_purse_and_weight()


func _on_trade_update_requested(slots: Array, copper: int, repairing: bool, combine: bool) -> void:
	request_modify_trade(1, slots, copper, repairing, combine)


func _on_trade_accept_requested() -> void:
	request_modify_trade(2)


func _on_trade_close_requested() -> void:
	request_modify_trade(0)


func _bind_online_merchant() -> void:
	if _online_runtime == null:
		return
	for pair in [["merchant_window_received", "_on_online_merchant_window"], ["money_received", "_on_online_money"],
			["encumberance_received", "_on_online_encumberance"], ["trade_window_received", "_on_online_trade_window"]]:
		if _online_runtime.has_signal(str(pair[0])):
			var receiver := Callable(self, str(pair[1]))
			if not _online_runtime.is_connected(str(pair[0]), receiver):
				_online_runtime.connect(str(pair[0]), receiver)
	if _online_runtime.has_method("last_money"):
		var money: Dictionary = _online_runtime.call("last_money") as Dictionary
		if not money.is_empty():
			_on_online_money(money)
	if _online_runtime.has_method("last_encumberance"):
		var encumberance: Dictionary = _online_runtime.call("last_encumberance") as Dictionary
		if not encumberance.is_empty():
			_on_online_encumberance(encumberance)


func _handle_client_only_command_p1_114(command: String) -> bool:
	var parts := command.strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var verb := str(parts[0]).to_lower()
	if not (verb in CLIENT_ONLY_VERBS_P1_114):
		return false
	match verb:
		"/shop":
			# Rouvre la derniere boutique recue sans rien redemander au serveur.
			if _merchant_window != null and not (_merchant_window.pages as Dictionary).is_empty():
				_merchant_window.select_page(int(_merchant_window.current_page))
			else:
				_console("Aucune boutique ouverte.")
		"/appraise":
			if parts.size() < 2:
				_console("Usage : /appraise <logement>")
			else:
				request_appraise(int(str(parts[1])))
	return true


## ── marchand ─────────────────────────────────────────────────────────────
func _on_online_merchant_window(page: Dictionary) -> void:
	_online_merchant_pages += 1
	if _merchant_window == null:
		return
	_merchant_window.set_merchant_name(_merchant_target_name())
	_merchant_window.set_backpack(_backpack_lines())
	_merchant_window.add_page(page)
	_console("Boutique : page %d, %d objet(s)." % [int(page.get("page", 0)) + 1, (page.get("items", []) as Array).size()])


func _merchant_target_name() -> String:
	var target := _combat_client.current_target_id if _combat_client != null else -1
	if target == null or int(target) <= 0 or _local_server == null:
		return ""
	return str((_local_server.snapshot(int(target)) as Dictionary).get("name", ""))


func _backpack_lines() -> Array:
	if _local_server == null or not _local_server.has_method("player_inventory_snapshot"):
		return []
	var snapshot: Dictionary = _local_server.call("player_inventory_snapshot") as Dictionary
	return snapshot.get("backpack", []) as Array


func request_buy(page_slot: int, count: int, window_type: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_buy"):
		_console("Acheter : il n y a pas de marchand hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_buy", page_slot, count, window_type) as Dictionary
	if bool(result.get("ok", false)):
		_merchant_buys_sent += 1
	return result


func request_sell(inventory_slot: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_sell"):
		_console("Vendre : il n y a pas de marchand hors ligne.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_sell", inventory_slot) as Dictionary
	if bool(result.get("ok", false)):
		_merchant_sells_sent += 1
	return result


## En ligne c est le 0xE0 ; hors ligne la regle DOL du marchand s applique
## quand meme (GameMerchant.OnPlayerAppraise : prix x nombre / pile x 50 %).
func request_appraise(inventory_slot: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_appraise"):
		var item := _offline_backpack_item(inventory_slot)
		if item.is_empty():
			_console("Estimer : ce logement est vide.")
			return {"ok": false, "reason": "logement vide"}
		var value := int(MerchantCodecScript.sell_value(int(item.get("price", 0)), int(item.get("count", 1)), int(item.get("pack_size", 1))))
		_console("Un marchand vous en donnerait %s." % MerchantCodecScript.money_text(value))
		return {"ok": true, "offline": true, "value": value}
	var result: Dictionary = _online_runtime.call("send_appraise", inventory_slot) as Dictionary
	if bool(result.get("ok", false)):
		_merchant_appraisals_sent += 1
	return result


func _offline_backpack_item(slot: int) -> Dictionary:
	for value in _backpack_lines():
		var item := value as Dictionary
		if int(item.get("slot", -1)) == slot:
			return item
	return {}


## ── argent et encombrement ───────────────────────────────────────────────
func _on_online_money(money: Dictionary) -> void:
	_online_money_updates += 1
	_last_money_copper = int(money.get("total_copper", 0))
	if _merchant_window != null and _merchant_window.has_method("set_purse"):
		_merchant_window.call("set_purse", _last_money_copper)
	if _alpha_inventory != null and _alpha_inventory.has_method("set_money"):
		_alpha_inventory.call("set_money", _last_money_copper)
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_money", str(money.get("text", "")))


func _on_online_encumberance(encumberance: Dictionary) -> void:
	_online_encumberance_updates += 1
	_last_encumberance = encumberance.duplicate(true)
	var current := int(encumberance.get("current", 0))
	var maximum := int(encumberance.get("maximum", 0))
	if _alpha_inventory != null and _alpha_inventory.has_method("set_encumberance"):
		_alpha_inventory.call("set_encumberance", current, maximum)
	if _daoc_ui_bus != null:
		_daoc_ui_bus.publish("stats_encumberance", "%d/%d" % [current, maximum])
	if bool(encumberance.get("overencumbered", false)):
		_console("Vous etes surcharge et vous vous deplacez lentement.")


## Hors ligne : la bourse de l arbitre (P1-22C) et le poids calcule par la
## regle DOL. En ligne le serveur fait foi et cette fonction ne touche a rien.
func refresh_offline_purse_and_weight() -> Dictionary:
	if online_mode or _local_server == null or _alpha_inventory == null:
		return {"ok": false, "reason": "en ligne : le serveur fait foi"}
	var copper := 0
	if _local_server.has_method("purse"):
		copper = int((_local_server.call("purse", _local_server.player_object_id) as Dictionary).get("total_copper", 0))
	_last_money_copper = copper
	if _merchant_window != null and _merchant_window.has_method("set_purse"):
		_merchant_window.call("set_purse", copper)
	if _alpha_inventory.has_method("set_money"):
		_alpha_inventory.call("set_money", copper)
	var snapshot: Dictionary = {}
	if _local_server.has_method("player_inventory_snapshot"):
		snapshot = _local_server.call("player_inventory_snapshot") as Dictionary
	var equipped_weights: Array = []
	for value in (snapshot.get("equipped", {}) as Dictionary).values():
		if value is Dictionary:
			equipped_weights.append(int((value as Dictionary).get("weight", 0)))
	## Le sac du snapshot est une liste de LOGEMENTS (entiers) : l objet vit dans `slots`.
	var slots: Dictionary = snapshot.get("slots", {}) as Dictionary
	var backpack_weights: Array = []
	for value in (snapshot.get("backpack", []) as Array):
		var item: Variant = value if value is Dictionary else slots.get(int(value), {})
		if item is Dictionary:
			backpack_weights.append(int((item as Dictionary).get("weight", 0)))
	var weight := int(MerchantCodecScript.inventory_weight(equipped_weights, backpack_weights))
	var maximum := int(MerchantCodecScript.max_encumberance(_offline_strength()))
	if _alpha_inventory.has_method("set_encumberance"):
		_alpha_inventory.call("set_encumberance", weight, maximum)
	_last_encumberance = {"current": weight, "maximum": maximum, "overencumbered": weight > maximum}
	return {"ok": true, "copper": copper, "weight": weight, "maximum": maximum}


## La Force du personnage choisi ; en ligne le 0xFB (P1-106) la donne modifiee.
func _offline_strength() -> int:
	var entries: Dictionary = _online_character_stats.get("entries", {}) as Dictionary
	if entries.has("strength"):
		return int((entries["strength"] as Dictionary).get("total", 0))
	var stats: Dictionary = _online_character.get("stats", {}) as Dictionary
	return int(stats.get("strength", 0))


## ── échange ──────────────────────────────────────────────────────────────
func _on_online_trade_window(trade: Dictionary) -> void:
	_online_trade_updates += 1
	if _trade_window == null:
		return
	if bool(trade.get("closed", false)):
		_trade_window.hide_window()
		_console("Echange ferme.")
		return
	_trade_window.show_trade(trade)


func request_modify_trade(response: int, slots: Array = [], copper: int = 0, repairing: bool = false, combine: bool = false) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_modify_trade"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_modify_trade", response, slots, copper, repairing, combine) as Dictionary
	if bool(result.get("ok", false)):
		_trade_packets_sent += 1
	return result


func merchant_snapshot() -> Dictionary:
	return {"pages_received": _online_merchant_pages, "money_updates": _online_money_updates,
		"encumberance_updates": _online_encumberance_updates, "trade_updates": _online_trade_updates,
		"buys_sent": _merchant_buys_sent, "sells_sent": _merchant_sells_sent, "appraisals_sent": _merchant_appraisals_sent,
		"trade_packets_sent": _trade_packets_sent, "money_copper": _last_money_copper, "encumberance": _last_encumberance.duplicate(true),
		"merchant": _merchant_window.get_debug_snapshot() if _merchant_window != null else {},
		"trade": _trade_window.get_debug_snapshot() if _trade_window != null else {}}


# ============================================================================
# P1-115 — se déplacer autrement qu'en marchant : téléportation (0x04), portes
# (0x99), montures (0x4E / 0xC8), changement de région (0x90 → 0xB7). Les
# dispositions sont dans DaocOpenDaocTravelCodec, lues dans OpenDAoC et
# game.dll. Rien de tout cela n'existe hors ligne : c'est le serveur qui
# déplace, ouvre et monte.
# ============================================================================

## Le saut de région part quand le joueur entre dans une aire `zonejump.csv`
## (colonne 9 = le numéro du point de saut que le serveur attend). Décoché, on
## traverse les aires sans rien demander.
@export var online_zonejump_requests_enabled: bool = true
var _travel_stats := {"jumps": 0, "heading_only_jumps": 0, "doors": 0, "horses": 0,
	"ridings": 0, "region_changes": 0, "region_rebuilds": 0, "zonejump_requests": 0}
var _door_states: Dictionary = {}
## Objet serveur (0xD9 à object_kind 4) → identifiant de porte.
var _online_door_objects: Dictionary = {}
var _own_horse: Dictionary = {}
var _mounted_on := 0
var _region_change_pending: Dictionary = {}
var _last_zonejump_inside := -1
var _last_travel_error := ""


func _bind_online_travel() -> void:
	if _online_runtime == null:
		return
	var pairs := [["character_jump_received", "_on_online_character_jump"],
		["door_state_received", "_on_online_door_state"],
		["controlled_horse_received", "_on_online_controlled_horse"],
		["riding_received", "_on_online_riding"],
		["region_changed_received", "_on_online_region_changed"],
		["region_world_loading_requested", "_on_online_region_world_loading"]]
	for pair in pairs:
		if not _online_runtime.has_signal(pair[0]):
			continue
		var receiver := Callable(self, pair[1])
		if not _online_runtime.is_connected(pair[0], receiver):
			_online_runtime.connect(pair[0], receiver)
	# Les 0x99 recus pendant le chargement, avant cette liaison.
	if _online_runtime.has_method("door_states"):
		var known: Dictionary = _online_runtime.call("door_states") as Dictionary
		for door_id in known:
			_door_states[int(door_id)] = (known[door_id] as Dictionary).duplicate(true)
		_reapply_door_states()


## ── 0x04 : le serveur nous déplace ───────────────────────────────────────
func _on_online_character_jump(jump: Dictionary) -> void:
	var motor := session.player as DaocPlayerMotor if session != null else null
	if motor == null:
		return
	var position: Dictionary = _online_character.get("online_position", {}) as Dictionary
	if bool(jump.get("heading_only", false)):
		_travel_stats["heading_only_jumps"] = int(_travel_stats["heading_only_jumps"]) + 1
		motor.heading_deg = DaocHeadingScript.raw_to_motor_deg(int(jump.get("heading", 0)))
		motor._apply_daoc_transform()
		return
	var report := teleport_player_to_world_point(float(jump.get("x", 0)), float(jump.get("y", 0)),
		float(jump.get("z", 0)), int(jump.get("heading", 0)), int(position.get("region_id", 0)))
	_travel_stats["jumps"] = int(_travel_stats["jumps"]) + 1
	if not bool(report.get("ok", false)):
		_last_travel_error = str(report.get("reason", ""))
		_console("Teleportation refusee par le client : %s" % _last_travel_error)


## Poser le joueur sur un point MONDE de la région courante. La zone d'arrivée
## est bâtie si elle ne l'est pas ; le point reste le point du serveur, jamais
## corrigé ici — seule l'altitude se recale sur le sol si elle est dessous.
func teleport_player_to_world_point(world_x: float, world_y: float, world_z: float, heading_raw: int, region: int) -> Dictionary:
	var motor := session.player as DaocPlayerMotor if session != null else null
	if motor == null:
		return {"ok": false, "reason": "aucun joueur monte"}
	var zone := resolve_zone_for_world_point(region, world_x, world_y)
	if zone < 0:
		return {"ok": false, "reason": "aucune zone de la region %d ne couvre (%d, %d)" % [region, int(world_x), int(world_y)]}
	var built := false
	if not zone_streamer().has_zone(zone):
		build_zone(zone)
		built = true
	if not _state.zone_runtime.has(zone):
		return {"ok": false, "reason": "zone %d sans repere" % zone}
	_ensure_transition().note_entered(zone)
	current_zone = zone
	var origin := _origin(zone)
	motor.daoc_zone = zone
	motor.daoc_x = world_x - origin.x
	motor.daoc_y = world_y - origin.y
	motor.daoc_z = world_z
	motor.vertical_velocity_raw = 0.0
	motor.heading_deg = DaocHeadingScript.raw_to_motor_deg(heading_raw)
	motor._snap_to_floor(false)
	motor._apply_daoc_transform()
	var position: Dictionary = (_online_character.get("online_position", {}) as Dictionary).duplicate(true)
	position["x"] = world_x
	position["y"] = world_y
	position["z"] = world_z
	position["heading"] = heading_raw
	position["region_id"] = region
	_online_character["online_position"] = position
	# Le prochain 0xA9 part tout de suite, depuis la nouvelle position.
	_online_last_sent = {}
	_online_move_clock = online_movement_send_interval_sec
	var evicted := _evict_beyond_budget()
	refresh_distant_terrain_if_stale_r10()
	return {"ok": true, "zone": zone, "built": built, "evicted": evicted,
		"zone_local": [motor.daoc_x, motor.daoc_y, motor.daoc_z]}


## ── 0x99 : portes ────────────────────────────────────────────────────────
func _note_online_door_object(entity: Dictionary) -> void:
	var door_id := int(entity.get("door_id", 0))
	if door_id > 0:
		_online_door_objects[int(entity.get("object_id", -1))] = door_id


func _on_online_door_state(door: Dictionary) -> void:
	_travel_stats["doors"] = int(_travel_stats["doors"]) + 1
	var door_id := int(door.get("door_id", 0))
	_door_states[door_id] = door.duplicate(true)
	apply_door_visual(door_id, bool(door.get("open", false)))


## Ouvre (ou ferme, si elle est ouverte) la porte portée par un objet serveur.
func request_door_toggle_for_object(object_id: int) -> Dictionary:
	var door_id := int(_online_door_objects.get(object_id, 0))
	if door_id <= 0:
		return {"ok": false, "reason": "pas une porte"}
	return request_door(door_id, not bool((_door_states.get(door_id, {}) as Dictionary).get("open", false)))


func request_door(door_id: int, open: bool) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_door_request"):
		return {"ok": false, "reason": "hors ligne : les portes sont tenues par le serveur"}
	var result: Dictionary = _online_runtime.call("send_door_request", door_id, open) as Dictionary
	_console("-> %s la porte %d" % ["ouvrir" if open else "fermer", door_id])
	return result


## Le visuel d'une porte : les nœuds « door… » isolés par le convertisseur NIF
## portent la méta `daoc_door_id` et le groupe `daoc_doors`. Sans eux (NIF non
## découpé), rien ne bouge à l'écran mais l'état est tenu.
func apply_door_visual(door_id: int, open: bool) -> int:
	if not is_inside_tree():
		return 0
	var moved := 0
	for node in get_tree().get_nodes_in_group("daoc_doors"):
		if not node is Node3D or int(node.get_meta("daoc_door_id", -1)) != door_id:
			continue
		var door := node as Node3D
		if not door.has_meta("daoc_door_closed_transform"):
			door.set_meta("daoc_door_closed_transform", door.transform)
		var closed: Transform3D = door.get_meta("daoc_door_closed_transform")
		door.transform = _door_open_transform(door, closed) if open else closed
		moved += 1
	return moved


## Pivotante (type 1) : un quart de tour autour de la verticale de son pivot.
## Coulissante (type 3) : descend de sa hauteur. Le client d'origine anime les
## deux ; l'angle exact vit dans ses données d'animation, non lues ici.
static func _door_open_transform(door: Node3D, closed: Transform3D) -> Transform3D:
	if int(door.get_meta("daoc_door_kind", 1)) == 3:
		var height := float(door.get_meta("daoc_door_height", 0.0))
		return closed * Transform3D(Basis.IDENTITY, Vector3(0.0, -height, 0.0))
	# Les sommets sont cuits en espace modele : on pivote autour de l origine du
	# noeud « door… », pas de celle du MeshInstance3D.
	var pivot: Vector3 = door.get_meta("daoc_door_pivot", Vector3.ZERO)
	# Porte double : chaque battant a sa charniere au bord exterieur et tourne
	# en sens oppose de son voisin (nif_converter._double_door_leaves).
	var turn_sign := float(door.get_meta("daoc_door_turn_sign", 1.0))
	var turn := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0) * turn_sign), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	return closed * turn


func door_states() -> Dictionary:
	return _door_states.duplicate(true)


## ── 0x4E / 0xC8 : montures ───────────────────────────────────────────────
func _on_online_controlled_horse(horse: Dictionary) -> void:
	_travel_stats["horses"] = int(_travel_stats["horses"]) + 1
	if bool(horse.get("own", false)):
		_own_horse = horse.duplicate(true)
		if bool(horse.get("has_horse", false)):
			_console("Monture : %s" % str(horse.get("name", "cheval")))


func _on_online_riding(riding: Dictionary) -> void:
	_travel_stats["ridings"] = int(_travel_stats["ridings"]) + 1
	if int(riding.get("rider_id", -1)) != _online_player_object_id():
		return
	_mounted_on = int(riding.get("steed_id", 0)) if bool(riding.get("mounted", false)) else 0
	_console("Vous montez." if _mounted_on != 0 else "Vous descendez de votre monture.")


func request_dismount() -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_dismount"):
		return {"ok": false, "reason": "hors ligne"}
	return _online_runtime.call("send_dismount") as Dictionary


func is_mounted() -> bool:
	return _mounted_on != 0


## ── 0x90 → 0xB7 : changer de région ──────────────────────────────────────
## Le client d'origine demande le saut quand il entre dans une aire de saut ;
## ici, à chaque tic, on regarde l'aire sous le joueur. Un seul envoi par aire
## traversée, et le runtime tient le délai de dix secondes du client d'origine.
func _tick_online_zonejumps() -> void:
	if not online_mode or not online_zonejump_requests_enabled or _online_runtime == null:
		return
	if _state.zonejump_runtime == null or session == null or session.player == null:
		return
	var motor := session.player as DaocPlayerMotor
	if motor == null:
		return
	var inside: Array = _state.zonejump_runtime.volumes_at_daoc(motor.daoc_zone, Vector2(motor.daoc_x, motor.daoc_y)) as Array
	var jump_id := -1
	for value in inside:
		var entry := value as Dictionary
		var z_ok := motor.daoc_z >= float(entry.get("z_min", -INF)) - 64.0 and motor.daoc_z <= float(entry.get("z_max", INF)) + 64.0
		if z_ok and int(entry.get("target", -1)) > 0:
			jump_id = int(entry.get("target", -1))
			break
	if jump_id == _last_zonejump_inside:
		return
	_last_zonejump_inside = jump_id
	if jump_id > 0:
		var result: Dictionary = _online_runtime.call("send_region_change_request", jump_id) as Dictionary
		if bool(result.get("ok", false)):
			_travel_stats["zonejump_requests"] = int(_travel_stats["zonejump_requests"]) + 1
			_console("-> point de saut %d" % jump_id)


func _on_online_region_changed(region: Dictionary) -> void:
	_travel_stats["region_changes"] = int(_travel_stats["region_changes"]) + 1
	_region_change_pending = region.duplicate(true)
	_console("Changement de region : %d (zone %d)" % [int(region.get("region_id", 0)), int(region.get("zone_skin_id", 0))])


## Le serveur a renvoyé la position dans la nouvelle région : on détruit le
## monde de l'ancienne (zones, peuplement) et on bâtit la nouvelle, puis
## PlayerInit part — comme le client d'origine sous son écran de chargement.
func _on_online_region_world_loading() -> void:
	var snapshot: Dictionary = _online_runtime.call("world_snapshot") as Dictionary
	var report := rebuild_world_for_region_change(snapshot.get("player_position", {}) as Dictionary)
	if not bool(report.get("ok", false)):
		_last_travel_error = str(report.get("reason", ""))
		_console("Changement de region : %s" % _last_travel_error)
	_online_runtime.call("finish_region_world_loading")


func rebuild_world_for_region_change(position: Dictionary) -> Dictionary:
	if position.is_empty():
		return {"ok": false, "reason": "aucune position recue dans la nouvelle region"}
	var region := int(position.get("region_id", 0))
	var world_x := float(position.get("x", 0.0))
	var world_y := float(position.get("y", 0.0))
	var zone := resolve_zone_for_world_point(region, world_x, world_y)
	if zone < 0:
		return {"ok": false, "reason": "aucune zone de la region %d ne couvre (%d, %d)" % [region, int(world_x), int(world_y)]}
	# 1. Le peuplement de l'ancienne région : nœuds, arbitre miroir, flux.
	_clear_online_population_for_region_change()
	# 2. Les zones de l'ancienne région.
	var streamer := zone_streamer()
	var unloaded: Array = []
	for zone_id in streamer.loaded_zones():
		if streamer.unload(int(zone_id)):
			DaocZoneUnload.forget_zone(_state, int(zone_id))
			unloaded.append(int(zone_id))
	_door_states.clear()
	_online_door_objects.clear()
	_last_zonejump_inside = -1
	# 3. La nouvelle : zone, joueur, peuplement vide qui se remplira au flux.
	# Le 0x88 de la nouvelle region porte aussi le NOUVEL identifiant d objet.
	_online_character["online_position"] = position.duplicate(true)
	var teleport := teleport_player_to_world_point(world_x, world_y, float(position.get("z", 0.0)),
		int(position.get("heading", 0)), region)
	var population := mount_online_population()
	_bind_online_stream_to_authority()
	_travel_stats["region_rebuilds"] = int(_travel_stats["region_rebuilds"]) + 1
	_region_change_pending = {}
	return {"ok": bool(teleport.get("ok", false)), "region": region, "zone": zone,
		"unloaded": unloaded, "teleport": teleport, "population": population}


func _clear_online_population_for_region_change() -> void:
	if _population != null:
		for object_id in _population.call("live_object_ids") as Array:
			if _local_server != null and _local_server.has_method("despawn_stream_entity"):
				_local_server.despawn_stream_entity(int(object_id), "region_change")
		_population.call("clear", self)
	_population = null
	if session != null:
		session.entity_population = null
	if _online_stream != null:
		if _online_runtime != null and _online_runtime.has_signal("world_entity_event"):
			var receiver := Callable(self, "_on_online_entity_event")
			if _online_runtime.world_entity_event.is_connected(receiver):
				_online_runtime.world_entity_event.disconnect(receiver)
		if session != null and session.entity_stream == _online_stream:
			session.entity_stream = null
		_online_stream.queue_free()
		_online_stream = null


func get_travel_snapshot() -> Dictionary:
	var out := _travel_stats.duplicate(true)
	out["doors_known"] = _door_states.size()
	out["door_objects"] = _online_door_objects.size()
	out["mounted_on"] = _mounted_on
	out["own_horse"] = _own_horse.duplicate(true)
	out["region_change_pending"] = _region_change_pending.duplicate(true)
	out["last_error"] = _last_travel_error
	return out


## P1-115 (retour live du 2026-09-25, Cotswold) : les portes des maisons ne
## sont PAS des objets serveur — le serveur n envoie que leur état (0x99, déjà
## à l entrée monde). Le client d origine vise donc le NŒUD « door… » du décor
## sous la souris. Ici : rayon de la caméra contre l emprise de chaque porte
## isolée par le convertisseur ; la plus proche touchée gagne.
func pick_door_at_screen(screen_position: Vector2) -> int:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	if camera == null or not is_inside_tree():
		return -1
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var best_id := -1
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("daoc_doors"):
		var door := node as MeshInstance3D
		if door == null or door.mesh == null or not door.is_visible_in_tree():
			continue
		var door_id := int(door.get_meta("daoc_door_id", -1))
		if door_id <= 0:
			continue
		var box: AABB = door.global_transform * door.mesh.get_aabb()
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit == null:
			continue
		var distance := origin.distance_to(hit as Vector3)
		if distance < best_distance:
			best_distance = distance
			best_id = door_id
	return best_id


func _try_door_at_screen(screen_position: Vector2) -> bool:
	var door_id := pick_door_at_screen(screen_position)
	if door_id <= 0:
		return false
	var open := not bool((_door_states.get(door_id, {}) as Dictionary).get("open", false))
	return bool(request_door(door_id, open).get("ok", false))


## Les 0x99 de l entrée monde arrivent AVANT que les maisons soient bâties :
## chaque zone bâtie (et chaque liaison) rejoue les états connus.
func _reapply_door_states() -> void:
	for door_id in _door_states:
		apply_door_visual(int(door_id), bool((_door_states[door_id] as Dictionary).get("open", false)))


## ═══════════════════════════════════════════════════════════════════════════
## P1-121 — /use et /use2, comme le client d origine (eden.dll.c l.77045) :
## « &use <type> <index> », type 5 = inventaire ; l index CLIENT devient un
## eInventorySlot (0..3 -> 10..13, 10..25 -> 21..36, 40..79 tel quel), puis
## 0x71 UseSlot avec l usage 1 (use) ou 2 (use2). Sans argument, l objet
## selectionne dans l inventaire (ici : le dernier dont on a demande le delve).
## « /use <logement> » accepte aussi directement un eInventorySlot.
## ═══════════════════════════════════════════════════════════════════════════
static func use_command_slot(parts: PackedStringArray, selected_slot: int) -> int:
	if parts.size() >= 3:
		if int(parts[1]) != 5:
			return -1
		var index := int(parts[2])
		if index >= 0 and index <= 3:
			return index + 10
		if index >= 10 and index <= 25:
			return index + 11
		if index >= 40 and index <= 79:
			return index
		return -1
	if parts.size() == 2:
		return int(parts[1]) if parts[1].is_valid_int() else -1
	return selected_slot


func _handle_use_command_p1_121(command: String) -> bool:
	var parts := command.strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var verb := str(parts[0]).to_lower()
	if verb != "/use" and verb != "/use2":
		return false
	var selected := -1
	if _alpha_inventory != null and _alpha_inventory.has_method("last_detail_slot"):
		selected = int(_alpha_inventory.call("last_detail_slot"))
	var slot := use_command_slot(parts, selected)
	if slot < 0:
		_console("%s : aucun objet choisi (clic droit sur un objet, ou %s <logement>)." % [verb, verb])
		return true
	var use_type := 2 if verb == "/use2" else 1
	if online_mode and _online_runtime != null and _online_runtime.has_method("send_use_slot"):
		_online_runtime.call("send_use_slot", slot, use_type)
		_console("-> %s logement %d" % [verb, slot])
	else:
		_console("%s : utiliser un objet est decide par le serveur (en ligne seulement)." % verb)
	return true


## ═══════════════════════════════════════════════════════════════════════════
## P1-122 — l economie en ligne : artisanat (/craft -> DaocCraftWindow -> 0xED),
## coffres et consignation (0x02 types 3..6 -> DaocExternalInventoryWindow ->
## 0xDD, 0x1A, 0x1C ; caisse 0x1E), explorateur du marche (0x1F <-> 0x11,
## acheter = 0xDD depuis 1000 + index).
## ═══════════════════════════════════════════════════════════════════════════
var _craft_window: CanvasLayer = null
var _external_window: CanvasLayer = null
var _market_window: CanvasLayer = null
var _crafts_sent := 0
var _external_moves_sent := 0
var _market_prices_sent := 0
var _market_searches_sent := 0


func _mount_economy_windows_p1_122() -> void:
	_craft_window = preload("res://src/daoc/ui/DaocCraftWindow.gd").new()
	_craft_window.name = "DaocCraftWindow"
	add_child(_craft_window)
	_craft_window.craft_requested.connect(request_craft)
	_external_window = preload("res://src/daoc/ui/DaocExternalInventoryWindow.gd").new()
	_external_window.name = "DaocExternalInventoryWindow"
	add_child(_external_window)
	_external_window.move_requested.connect(request_external_move)
	_external_window.price_requested.connect(request_market_price)
	_external_window.withdraw_requested.connect(request_withdraw_merchant_money)
	_market_window = preload("res://src/daoc/ui/DaocMarketExplorerWindow.gd").new()
	_market_window.name = "DaocMarketExplorerWindow"
	add_child(_market_window)
	_market_window.search_requested.connect(request_market_search)
	_market_window.buy_requested.connect(func(from_slot: int) -> void: request_external_move(from_slot, _first_free_online_backpack_slot()))


func _bind_online_economy_p1_122() -> void:
	if _online_runtime == null:
		return
	for pair in [["external_inventory_changed", "_on_online_external_inventory"],
			["consignment_money_received", "_on_online_consignment_money"],
			["market_explorer_received", "_on_online_market"]]:
		if _online_runtime.has_signal(str(pair[0])):
			var receiver := Callable(self, str(pair[1]))
			if not _online_runtime.is_connected(str(pair[0]), receiver):
				_online_runtime.connect(str(pair[0]), receiver)


## Le livre de recettes du royaume du personnage, charge a la premiere ouverture.
func toggle_craft_window() -> void:
	if _craft_window == null:
		return
	if _craft_window.book == null:
		var realm := int(_chosen_character_realm_p1_122())
		_craft_window.set_book(DaocCraftRecipeBook.load_from_client(daoc_client_root, realm))
		if _online_runtime != null and _online_runtime.has_method("crafting_skills"):
			_craft_window.set_server_skills(_online_runtime.call("crafting_skills") as Array)
	_craft_window.toggle()


func _chosen_character_realm_p1_122() -> int:
	return clampi(int(_online_character.get("realm_id", _online_character.get("realm", 1))), 1, 3)


func request_craft(recipe_id: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_craft"):
		_console("Artisanat : le serveur fabrique, hors ligne il n y a pas d artisan.")
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_craft", recipe_id) as Dictionary
	if bool(result.get("ok", false)):
		_crafts_sent += 1
	return result


func request_external_move(from_slot: int, to_slot: int) -> Dictionary:
	if from_slot < 0 or to_slot < 0:
		_console("Plus de place.")
		return {"ok": false, "reason": "plein"}
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_move_item"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_move_item", from_slot, to_slot, 1) as Dictionary
	if bool(result.get("ok", false)):
		_external_moves_sent += 1
	return result


func request_market_price(relative_slot: int, price: int) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_set_market_price"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_set_market_price", relative_slot, price) as Dictionary
	if bool(result.get("ok", false)):
		_market_prices_sent += 1
	return result


func request_withdraw_merchant_money() -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_withdraw_merchant_money"):
		return {"ok": false, "reason": "hors ligne"}
	return _online_runtime.call("send_withdraw_merchant_money") as Dictionary


func request_market_search(search: Dictionary) -> Dictionary:
	if not online_mode or _online_runtime == null or not _online_runtime.has_method("send_market_search"):
		return {"ok": false, "reason": "hors ligne"}
	var result: Dictionary = _online_runtime.call("send_market_search", search) as Dictionary
	if bool(result.get("ok", false)):
		_market_searches_sent += 1
	return result


func _online_backpack_items() -> Array:
	var out: Array = []
	if _online_runtime == null or not _online_runtime.has_method("inventory_snapshot"):
		return out
	for value in (_online_runtime.call("inventory_snapshot") as Dictionary).get("items", []):
		var item := value as Dictionary
		var slot := int(item.get("slot", -1))
		if slot >= 40 and slot <= 79:
			out.append({"slot": slot, "name": str(item.get("name", ""))})
	return out


func _first_free_online_backpack_slot() -> int:
	var used := {}
	for value in _online_backpack_items():
		used[int((value as Dictionary)["slot"])] = true
	for slot in range(40, 80):
		if not used.has(slot):
			return slot
	return -1


func _on_online_external_inventory(window: Dictionary) -> void:
	if _external_window == null:
		return
	_external_window.set_backpack(_online_backpack_items())
	_external_window.apply_window(window)


func _on_online_consignment_money(money: Dictionary) -> void:
	if _external_window != null:
		_external_window.set_till(int(money.get("total_copper", 0)))


func _on_online_market(market: Dictionary) -> void:
	if _market_window != null:
		_market_window.apply_market(market)


## P1-125 — hors ligne, une capacite de royaume active (DOL) s'active par
## `/ra <nom>` ; l'arbitre applique son bareme et son delai.
func use_offline_realm_ability(name: String) -> Dictionary:
	if _local_server == null or not _local_server.has_method("request_realm_ability"):
		return {"ok": false, "reason": "arbitre absent"}
	var target_id: int = _combat_client.current_target_id if _combat_client != null else -1
	var result: Dictionary = _local_server.request_realm_ability(_local_server.player_object_id, name, target_id)
	if not bool(result.get("ok", false)):
		_console("%s : %s" % [name, str(result.get("reason", "refuse"))])
	return result


## 2026-09-27 — options graphiques en jeu (/options). La densite de l herbe
## s applique a chaud a toutes les zones baties et vaut pour les suivantes.
var _graphics_options: CanvasLayer = null


func toggle_graphics_options() -> void:
	if _graphics_options == null:
		_graphics_options = preload("res://src/daoc/ui/DaocGraphicsOptionsWindow.gd").new()
		_graphics_options.name = "DaocGraphicsOptionsWindow"
		add_child(_graphics_options)
		_graphics_options.grass_detail_changed.connect(set_grass_detail_level)
	_graphics_options.toggle()


func set_grass_detail_level(level: int) -> void:
	grass_detail_level = clampi(level, 0, 2)
	for runtime in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("daoc_grass_runtime"):
		if runtime.has_method("set_detail_level"):
			runtime.call("set_detail_level", grass_detail_level)


## P1-129 — fenetres deplacables : chaque CanvasLayer du projet qui porte un
## panneau (`_panel` / `_root`) le recoit des qu il entre dans l arbre (le
## panneau nait dans son _ready, d ou l appel differe). HUD, ecran de mort,
## barre d effets, chat et quickbars restent a part.
const DRAG_EXCLUDED_WINDOWS := ["DaocCombatHud.gd", "DaocDeathScreen.gd", "DaocEffectBar.gd", "DaocTextWindows.gd", "DaocQuickbars.gd", "DaocUiWindowManager.gd"]


func _on_tree_node_added_for_drag(node: Node) -> void:
	if node is CanvasLayer and node.get_script() != null:
		var script_file := str((node.get_script() as Script).resource_path).get_file()
		if script_file.begins_with("Daoc") and not DRAG_EXCLUDED_WINDOWS.has(script_file):
			_make_window_draggable.call_deferred(node)


func _make_window_draggable(layer: Node) -> void:
	if is_instance_valid(layer):
		DaocWindowDrag.make_draggable(DaocWindowDrag.window_panel(layer))
		DaocWindowDrag.add_close_button(layer, DaocWindowDrag.window_panel(layer))
		DaocWindowDrag.add_opacity_menu(DaocWindowDrag.window_panel(layer), str((layer.get_script() as Script).resource_path).get_file().get_basename())


## P1-130 — la famille de l arme en main choisit les clips de combat du
## joueur (attaques, parades, esquives, garde) : baton, deux mains, hast,
## faux, mains nues, double arme, estoc, arc. Voir DaocWeaponAnimationFamily.
var weapon_animation_family := ""


func _apply_weapon_family(equipped: Dictionary, active: int) -> void:
	weapon_animation_family = DaocWeaponAnimationFamily.family_for(equipped, active)
	if _combat_client != null:
		_combat_client.weapon_family = weapon_animation_family
	if _server_animations != null:
		_server_animations.weapon_family = weapon_animation_family
	var idle := DaocWeaponAnimationFamily.combat_idle_clip(weapon_animation_family)
	for root_value in _player_visual_runtimes():
		var runtime := root_value as Node
		if runtime.has_method("has_clip"):
			runtime.set("combat_idle_animation_name", idle if bool(runtime.call("has_clip", idle)) else ("combat_idle" if bool(runtime.call("has_clip", "combat_idle")) else ""))


func _player_visual_runtimes() -> Array:
	var out: Array = []
	if _combat_client != null and _combat_client.has_method("_resolve_player_visual"):
		var visual: Variant = _combat_client.call("_resolve_player_visual")
		if visual is Node:
			out.append(visual)
	return out


func _on_online_attack_mode(on: bool) -> void:
	if _combat_client != null:
		_combat_client.server_attack_mode = 1 if on else 0


## P1-134 — le marchand et l entraineur se construisent depuis leur XML du
## client (merchant_window.xml, training_window.xml) quand l interface XML est
## montee ; sinon ils gardent leur panneau Godot (suites sans client).
func _attach_xml_window_p1_134(target: Node, window_name: String) -> bool:
	if target == null or _daoc_ui_manager == null or _daoc_ui_manager.builder == null or _daoc_ui_manager.contract == null:
		return false
	var window: Dictionary = _daoc_ui_manager.contract.find_window_named(window_name)
	if window.is_empty():
		return false
	var ui_scale: Vector2 = _daoc_ui_manager._root.scale if _daoc_ui_manager._root != null else Vector2.ONE
	target.set_meta("daoc_ui_scale", ui_scale)
	if window_name == "merchant":
		return bool(target.call("use_xml_window", _daoc_ui_manager.builder, window, _daoc_ui_bus))
	return bool(target.call("use_xml_window", _daoc_ui_manager.builder, window))


## ═══════════════════════════════════════════════════════════════════════════
## 2026-09-30 — LES NOMS AU-DESSUS DES TETES
##
## Le client d'origine affiche nom et « <Guilde> » au-dessus des PNJ et des
## joueurs, le sien compris ; /shownames et /hidenames reglent chaque famille.
## ═══════════════════════════════════════════════════════════════════════════
const DaocNameplatesScript = preload("res://src/daoc/ui/DaocNameplates.gd")
var _nameplates: Node = null


func _tick_nameplates() -> void:
	if _nameplates == null:
		_nameplates = DaocNameplatesScript.new()
		_nameplates.name = "DaocNameplates"
		add_child(_nameplates)
	var population_root: Node = _population.get("root") as Node if _population != null else null
	_nameplates.set("population_root", population_root)
	_nameplates.set("local_player", session.player if session != null else null)
	var character_name := str(_online_character.get("name", ""))
	if character_name == "" and _local_server != null and _local_server.has_method("snapshot"):
		character_name = "Heyveno"
	_nameplates.set("local_name", character_name)
	_nameplates.set("local_guild", str(_online_character.get("guild", _online_character.get("guild_name", ""))))


## 2026-09-30 — la carte de zone (map_window du client d origine), /map.
const DaocMinimapWindowScript = preload("res://src/daoc/ui/DaocMinimapWindow.gd")
var _minimap: CanvasLayer = null
var _minimap_accum := 0.0


func _tick_minimap(force: bool = false, delta: float = 0.0) -> void:
	_minimap_accum += delta
	if not force and _minimap_accum < 0.1:
		return
	_minimap_accum = 0.0
	if current_zone < 0 or session == null or session.player == null or not is_instance_valid(session.player):
		return
	if _minimap == null:
		_minimap = DaocMinimapWindowScript.new()
		_minimap.name = "DaocMinimapWindow"
		_minimap.set("client_root", daoc_client_root)
		add_child(_minimap)
	var zone_data: Dictionary = _state.zone_runtime.get(current_zone, {}) as Dictionary
	var origin3: Vector3 = zone_data.get("origin3", Vector3.ZERO) as Vector3
	var scale := maxf(world_scale, 0.0001)
	var to_zone := func(p: Vector3) -> Vector2: return Vector2(p.x - origin3.x, p.z - origin3.z) / scale
	var player_node := session.player as Node3D
	var forward := Vector2(0, -1)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var f3 := -camera.global_basis.z
		forward = Vector2(f3.x, f3.z)
	var markers: Array = []
	var population_root: Node = _population.get("root") as Node if _population != null else null
	if population_root != null and is_instance_valid(population_root):
		for child in population_root.get_children():
			var wrapper := child as Node3D
			if wrapper == null:
				continue
			var kind := str(wrapper.get_meta("daoc_entity_type", ""))
			if kind == "npc" or kind == "player":
				markers.append([to_zone.call(wrapper.global_position), Color(1, 1, 1) if kind == "player" else Color(0.45, 0.85, 0.85)])
	_minimap.call("update_view", current_zone, to_zone.call(player_node.global_position), forward, markers)
