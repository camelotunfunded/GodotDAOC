extends Node3D

const DaocClientRootScript = preload("res://src/daoc/DaocClientRoot.gd")
const DaocZoneRootScript = preload("res://src/daoc/DaocZoneRoot.gd")
const DaocDebugTestRunnerScript = preload("res://src/daoc/DaocDebugTestRunner.gd")
const DaocZoneViewerPostBuildersAuditScript = preload("res://src/daoc/DaocZoneViewerPostBuildersAudit.gd")
const DaocZoneSceneAssemblerScript = preload("res://src/daoc/DaocZoneSceneAssembler.gd")
const DaocLegacyVisualsScript = preload("res://src/daoc/DaocLegacyVisuals.gd")
const DaocAssetIndexRegistryScript = preload("res://src/daoc/DaocAssetIndexRegistry.gd")
const DaocZoneViewerStateRegistryScript = preload("res://src/daoc/DaocZoneViewerStateRegistry.gd")
const DaocZoneViewerCommandDebugSurfaceScript = preload("res://src/daoc/DaocZoneViewerCommandDebugSurface.gd")
const DaocLocalViewerBootstrapScript = preload("res://src/daoc/DaocLocalViewerBootstrap.gd")
const DaocNpcShowcaseScript = preload("res://src/daoc/offline/DaocNpcShowcase.gd")
const DaocGothwaitePopulationScript = preload("res://src/daoc/offline/DaocGothwaitePopulation.gd")
const DaocDistantTerrainScript = preload("res://src/daoc/world/DaocDistantTerrain.gd")
const DaocZoneEnvironmentProfileScript = preload("res://src/daoc/environment/DaocZoneEnvironmentProfile.gd")
const DaocWeatherFrontStateScript = preload("res://src/daoc/environment/DaocWeatherFrontState.gd")
const DaocEnvironmentControllerScript = preload("res://src/daoc/environment/DaocEnvironmentController.gd")
const DaocSky3DAdapterScript = preload("res://src/daoc/environment/DaocSky3DAdapter.gd")
const DaocWeatherFxScript = preload("res://src/daoc/environment/DaocWeatherFx.gd")
const DaocVisualRoadmapProfileScript = preload("res://src/daoc/environment/DaocVisualRoadmapProfile.gd")
const DaocZoneViewerFreezeAuditScript = preload("res://src/daoc/DaocZoneViewerFreezeAudit.gd")
const DaocZoneJumpBuilderScript = preload("res://src/daoc/DaocZoneJumpBuilder.gd")
const DaocZoneJumpRuntimeScript = preload("res://src/daoc/DaocZoneJumpRuntime.gd")
const DaocZoneJumpTransformContextScript = preload("res://src/daoc/DaocZoneJumpTransformContext.gd")
const DaocWaterBuilderScript = preload("res://src/daoc/DaocWaterBuilder.gd")
const DaocWaterRuntimeScript = preload("res://src/daoc/DaocWaterRuntime.gd")
const DaocWaterFxScript = preload("res://src/daoc/water/DaocWaterFx.gd")
const DaocCollisionBuilderScript = preload("res://src/daoc/DaocCollisionBuilder.gd")
const DaocCollisionRuntimeScript = preload("res://src/daoc/DaocCollisionRuntime.gd")
const DaocPropBuilderScript = preload("res://src/daoc/DaocPropBuilder.gd")
const DaocPropRuntimeScript = preload("res://src/daoc/DaocPropRuntime.gd")
const DaocTerrainBuilderScript = preload("res://src/daoc/DaocTerrainBuilder.gd")
const DaocTerrainRuntimeScript = preload("res://src/daoc/DaocTerrainRuntime.gd")
const DaocGeneratedDungeonRuntimeBridgeScript = preload("res://src/daoc/dungeon/DaocGeneratedDungeonRuntimeBridge.gd")
const DaocAssetMaterialFidelityAuditScript = preload("res://src/daoc/audit/DaocAssetMaterialFidelityAudit.gd")
const DaocNifImportConversionProbeScript = preload("res://src/daoc/audit/DaocNifImportConversionProbe.gd")
const DaocGroundingServiceScript = preload("res://src/daoc/player/DaocGroundingService.gd")
const DaocGeneratedSceneParityAuditScript = preload("res://src/daoc/audit/DaocGeneratedSceneParityAudit.gd")
const DaocOpenDaocTcpLoginProbeScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const DaocPregameFlowScene = preload("res://scenes/ui/pregame/DaocPregameFlow.tscn")
const DaocLocalServerScript = preload("res://src/daoc/server/DaocLocalServer.gd")
const DaocCombatHudScript = preload("res://src/daoc/ui/DaocCombatHud.gd")
const DaocUiWindowManagerScript = preload("res://src/daoc/ui/DaocUiWindowManager.gd")
const DaocUiAdapterBusScript = preload("res://src/daoc/ui/DaocUiAdapterBus.gd")
const DaocUiServerBridgeScript = preload("res://src/daoc/ui/DaocUiServerBridge.gd")
const DaocCombatClientScript = preload("res://src/daoc/gameplay/runtime/DaocCombatClient.gd")
const DaocNearbyWorldEntitySourceScript = preload("res://src/daoc/network/opendaoc/DaocNearbyWorldEntitySource.gd")

# =============================================================================
# INSPECTEUR ZoneViewer — regroupement par thème
#
# Charge une ou plusieurs zones depuis leurs cartes de hauteurs 16 bits (.r16) et
# place chacune à son origine monde (zones.dat, via zones_placement.json). Les
# hauteurs sont des unités de jeu exactes ; `height_exaggeration` est VISUEL. Les
# coordonnées sont recalées sur la première zone pour rester près de l'origine.
#
# Deux règles pour éditer ce bloc :
#   1. l'ordre de déclaration EST l'ordre de l'inspecteur. Un @export_group ou un
#      @export_subgroup capture TOUT ce qui suit jusqu'au suivant ;
#   2. un commentaire `##` collé au-dessus d'une propriété devient son infobulle
#      dans l'inspecteur. Pas de ligne vide entre les deux, sinon elle est perdue.
#
# Aucun nom de propriété n'est modifié ici : les valeurs déjà enregistrées dans
# ZoneViewer.tscn, les tests et les accès `get()/set()` restent valides.
# =============================================================================

@export_group("Monde et zones")
## Zones DAoC chargées, par numéro (zone000 → 0). Chacune est posée à son origine
## monde lue dans zones.dat ; la première sert de repère et les autres sont
## recalées sur elle pour rester près de l'origine Godot.
@export var zones: PackedInt32Array = PackedInt32Array([0])
## Multiplicateur d'altitude du relief. Réglage VISUEL uniquement : garder 1.0
## pour des hauteurs de jeu exactes.
@export var height_exaggeration: float = 1.0
## Conversion unités DAoC brutes → unités Godot. 1.0 = échelle native. Tous les
## réglages suffixés `_raw` de cet inspecteur sont exprimés en unités DAoC,
## AVANT ce facteur.
@export var world_scale: float = 1.0
## Range le contenu généré sous une branche par zone (TerrainRoot, StaticPropsRoot,
## WaterRoot…) au lieu de tout aplatir sous ZoneViewer. Les builders et les tests
## s'appuient sur cette arborescence : à laisser activé.
@export var use_structured_zone_root: bool = true
## R0 — confie les systèmes PERSISTANTS (joueur, caméra, entrées, autorité
## serveur, autorité environnement, population, effets d'eau) à un nœud
## `DaocGameSession` au lieu de les tenir en variables du ZoneViewer. Le
## comportement est identique : seul le PROPRIÉTAIRE change. Décoché, le viewer
## reprend exactement l'ancien stockage local. C'est le socle des jalons R1
## (streamer de zones) et R2 (boucle vivante) : une zone doit pouvoir mourir et
## renaître sans emporter le joueur.
@export var use_game_session: bool = true
## R1 — confie les branches de zone (`Zone0XX_Root` et tout ce que les builders
## y accrochent) à un `DaocZoneStreamer`, qui sait les créer ET les détruire.
## C'est ce qui permet de recharger une zone sans reconstruire la session — donc
## sans les ~7 minutes de démarrage. Décoché, le viewer reprend l'ancien
## dictionnaire local et ne sait plus décharger.
@export var use_zone_streamer: bool = true
## R4 — sort la construction du décor du ZoneViewer. Les étapes de zone
## deviennent des objets autonomes (`DaocZoneWaterStep`…) qui consomment un
## `DaocZoneBuildServices` au lieu de rappeler le viewer par nom. Aucune règle
## de construction ne change : les builders 14A-14E restent l'autorité.
## Décoché, le viewer reprend ses anciennes méthodes internes, à l'identique.
##
## Bascule par TRANCHES : seules les étapes déjà migrées passent par le nouveau
## chemin, les autres continuent comme avant. Le drapeau ne ment donc pas — il
## dit « utilise le nouveau chemin là où il existe ».
@export var use_zone_build_steps: bool = true
## R5 — franchir une frontière de zone charge la voisine et décharge l'ancienne,
## sans reconstruire la session. Décoché, le joueur est de nouveau RABOTÉ à
## l'emprise de sa zone par `motor_clamp_zone_xy` : c'est le garde-fou d'avant
## R5, pas un bug.
##
## Un passage ne téléporte pas : le point MONDE est identique des deux côtés,
## seul le repère de zone change. C'est ce que la suite R5 vérifie.
@export var zone_transition_enabled: bool = true
## Nombre maximal de zones tenues en mémoire par le `DaocZoneStreamer`. La zone
## où se trouve le joueur n'est JAMAIS déchargée, quel que soit ce budget : les
## autres partent de la plus anciennement habitée à la plus récente.
##
## 2 laisse la zone quittée résidente le temps d'un aller-retour à la frontière ;
## 1 décharge dès le passage.
@export_range(1, 8, 1) var max_resident_zones: int = 2
## P1-33 — bâtit la voisine AVANT d'atteindre son bord, au lieu de la bâtir à
## l'instant du franchissement. Décoché, R5 reprend son comportement exact : la
## zone naît quand le joueur pose le pied dessus.
##
## Le préchargement ne rend pas la construction gratuite ; il la déplace là où
## elle ne coupe pas un mouvement. Voir `A_TESTER.md` pour ce qui reste mesuré.
@export var zone_prefetch_enabled: bool = true
## Marge fixe du rayon de préchargement, en unités DAoC brutes. Elle vaut même à
## l'arrêt : rester immobile à trois mètres du bord ne doit pas éteindre la
## voisine qu'on vient de faire naître.
@export_range(0.0, 32768.0, 256.0) var zone_prefetch_base_raw: float = 6000.0
## Secondes d'anticipation. LE réglage dépendant de la vitesse : le rayon vaut
## `marge + vitesse × ce nombre`, donc un sprint charge plus tôt qu'un pas.
@export_range(0.0, 20.0, 0.5) var zone_prefetch_seconds: float = 4.0
## Nombre maximal de voisines préchargées d'un coup. Le budget
## `max_resident_zones` reste maître : le préchargement ne le dépasse jamais.
@export_range(0, 4, 1) var zone_prefetch_max_zones: int = 1

## Les étapes de zone déjà migrées en objets autonomes. R4 avance par tranches :
## cette liste dit exactement où en est la bascule, au lieu de laisser croire que
## tout est passé. Les SEPT étapes du `BUILD_ORDER` de P1-15B y figurent
## désormais — la bascule du statique est complète.
const MIGRATED_ZONE_STEPS_R4 := ["water", "lights", "vegetation", "terrain", "collisions", "zonejumps", "props"]

@export_group("Client DAoC - chemins sources")
@export_subgroup("Racines")
## Dossier du client DAoC/Eden qui contient `_godot_daoc_cache`. Renseigné, les
## données sont lues dans `<racine>/_godot_daoc_cache/data`. Le client original
## n'est jamais déplacé ni modifié.
@export_global_dir var daoc_client_root: String = ""
## Surcharge facultative : pointe directement sur `<DAoC>/_godot_daoc_cache/data`.
## Vide, le viewer retombe sur `res://data`, ce qui garde l'ancien montage zone000.
@export_global_dir var external_data_dir: String = ""
## Dossier facultatif des dumps SQL OpenDAoC (`OpenDAoC-Database/opendaoc-db-core`).
## Sert uniquement aux rapports et imports hors ligne : il n'active jamais de spawn
## au runtime par lui-même.
@export_global_dir var opendaoc_db_core_dir: String = ""
## Repli relatif au projet, si la base a été copiée dans le dépôt Godot.
@export var opendaoc_db_core_project_fallback_dir: String = "res://data/server_dumps/opendaoc/opendaoc-db-core"

@export_subgroup("Modèles")
## Racine facultative des modèles. Vide, les dossiers DAoC habituels sont détectés
## depuis `daoc_client_root`. En mode NIF ce dossier contient des .nif ; en repli
## glTF, des .glb.
@export_global_dir var models_dir: String = ""
## Dossiers de modèles supplémentaires, scannés récursivement après `models_dir`
## et les dossiers DAoC détectés automatiquement.
@export var extra_models_dirs: PackedStringArray = PackedStringArray()

@export_subgroup("Textures")
## Dossiers de textures, dans l'ordre de recherche. Indexer À LA FOIS l'arbre MPK
## extrait ET le client original libre : arbres, feuillages et TerrainTex vivent
## hors des MPK.
@export var texture_dirs: PackedStringArray = PackedStringArray()
## Dossiers de textures supplémentaires, scannés récursivement après `texture_dirs`
## et les dossiers détectés automatiquement.
@export var extra_texture_dirs: PackedStringArray = PackedStringArray()
## Audit exhaustif : scanne tout le client, soit plus de 100 000 images. À laisser
## OFF pour un lancement normal, où les dossiers modèles/TerrainTex suffisent.
@export var scan_full_texture_client_root: bool = false
## Relie les matériaux des modèles aux textures trouvées dans les dossiers ci-dessus.
## OFF = géométrie sans texture.
@export var link_textures: bool = true
## Seuil d'alpha-scissor des matériaux dont la texture porte un canal alpha
## (découpe des feuillages). Plus haut = découpe plus franche, moins de halo.
@export var foliage_alpha_scissor: float = 0.5
## Restitue la couche detail des NIF multitexture (slot 2 de NiTexturingProperty) :
## le grain d.ecorce des troncs d.arbres et la pierre des rochers, que la texture
## de base ne porte pas. OFF = rendu identique a avant P1-21T.
@export var prop_detail_layer_enabled: bool = true
## Le client d.origine module la couche detail en "2x" (base * detail * 2), ce que
## Godot ne sait pas faire : il ne propose que base * detail. Ce gain compense, sur
## les seules surfaces qui portent une couche detail. 1.0 = aucune compensation.
@export_range(1.0, 3.0, 0.05) var prop_detail_gain: float = 2.0

@export_group("Modèles et props placés")
## Place les vrais modèles des fixtures de la zone. OFF = terrain nu, utile pour
## isoler un problème de relief.
@export var place_real_models: bool = true
## Lit les modèles directement en .nif (pipeline natif, sans glTF). OFF = ancien
## chargeur .glb, transitionnel. Voir `src/nif/` et NOTE_TERRAIN §11.
@export var use_nif_reader: bool = true
## Choisit la branche NiLODNode la plus dense pour les props NIF. Experimental :
## plus de triangles, aucune distance LOD decodee. OFF = premier enfant historique.
## Recharge la zone apres changement. Les variantes de donjon gardent leur chemin.
@export var prop_dense_lod_enabled: bool = false
## Arbres cuits dans le Lab. OFF conserve les NIF d'origine.
@export var speedtree_enabled: bool = false
## Conversion de dimensions SPT : valeur provisoire a valider visuellement.
@export_range(0.1, 100.0, 0.1) var speedtree_units_to_daoc: float = 12.0
@export_range(1000.0, 100000.0, 1000.0) var speedtree_visible_distance_raw: float = 30000.0
## Sens de rotation appliqué au heading DAoC. Le passage monde DAoC → Godot
## (Y DAoC → Z Godot, sans négation) inverse la chiralité, d'où -1.0 par défaut.
## Passer à 1.0 si les bâtiments regardent systématiquement à l'envers.
@export var heading_sign: float = -1.0
## Décalage constant ajouté au heading, en degrés. À n'utiliser que si TOUS les
## modèles sont tournés du même angle.
@export var heading_offset_deg: float = 0.0
## Fixtures Ground=1 : cale le sommet le plus bas du modèle sur le terrain plutôt
## que son origine, pour que les modèles au pivot décalé ne flottent ni ne
## s'enfoncent.
@export var anchor_to_base: bool = true
## Décalage vertical, en unités DAoC brutes, réservé au plancher des maisons-ponts
## (`brghouse` / `bridgehouse`). Aucun autre modèle n'est concerné.
@export var brghouse_floor_anchor_offset_raw: float = -128.0

@export_subgroup("Modèles manquants")
## Pose un repère visible là où un modèle est absent ou en erreur, pour que les
## trous se voient au lieu de passer inaperçus.
@export var mark_missing: bool = true
## Liste dans la console les modèles introuvables.
@export var log_missing_models: bool = true
## Écrit aussi le diagnostic dans un CSV, plus facile à collecter qu'un log console.
@export var export_missing_models_csv: bool = true
## Chemin du CSV des modèles manquants.
@export var missing_models_csv_path: String = "res://reports/missing_models_last.csv"

@export_group("Référence visuelle Outward")
@export_subgroup("Profil global")
## Active le lot esthétique complet. Décochez pour conserver uniquement les
## réglages détaillés ci-dessous. Aucun profil ne modifie la géométrie autoritaire.
@export var visual_roadmap_enabled: bool = true
@export_enum("Faible:0", "Élevé:1", "Capture:2") var visual_roadmap_quality: int = 1
@export_subgroup("1. Lumière et atmosphère")
## Coche livrée : contraste lisible, météo claire et profondeur sans voile gris.
## Décochez-la pour reprendre la main sur les curseurs détaillés plus bas.
@export var outward_environment_default: bool = true
@export_subgroup("2. Végétation")
## Coche livrée : herbe plus courte, moins compacte et laissant lire le terrain.
@export var outward_vegetation_default: bool = true
@export_subgroup("4. Contact au sol")
## Coche livrée : occlusion de proximité calibrée pour les pieds et fondations.
@export var outward_grounding_default: bool = true

@export_group("Qualité graphique")
@export_subgroup("Terrain")
## Filtrage anisotrope des textures de sol (shader `terrain_splat`). Sans lui,
## le sol devient flou à seulement 3-4 mètres du joueur dès qu'il est vu en
## angle rasant : le GPU choisit son mip level sur le pire des deux axes du
## gradient d'écran, et l'axe "vers l'horizon" d'un sol quasi plat est énorme.
## C'est le MÊME défaut que le client DAoC d'origine (2001), qui ne forçait pas
## non plus l'anisotropie partout. Décoché, le rendu retombe sur ce filtrage
## bilinéaire+mipmap classique : plus fidèle au flou d'origine, moins coûteux
## sur un GPU modeste. Premier d'une série de réglages appelés à devenir des
## options de qualité graphique pour les configurations faibles.
## Lu une seule fois à la préparation du shader de terrain (premier chargement
## de zone) : changer la valeur en cours de partie ne retouche pas un terrain
## déjà construit, il faut recharger la zone.
@export var terrain_anisotropic_filtering: bool = true
## Sol PBR : le shader de terrain lit, en plus de l'albédo, les cartes de
## normale, de rugosité et d'occlusion générées à côté de chaque texture de
## `zones/TerrainTex` (`<nom>_normal.png`, `_roughness.png`, `_ao.png`). Le
## relief des sentiers, des rochers et des sillons de sable réagit alors à la
## lumière ; décoché, le fragment est octet pour octet celui d'avant l'option.
## Coût : trois `Texture2DArray` de plus par zone résidente (≈ 8 Mio par couche
## à 1024 px), donc à couper sur un GPU modeste. Réglable en cours de partie :
## les matériaux de sol déjà bâtis sont mis à jour sans reconstruire la zone.
@export var terrain_pbr_enabled: bool = false
## Taille de chaque tranche des tableaux PBR du sol. 1024 est le point
## d'équilibre VRAM ; 2048 double le coût pour un gain surtout visible au ras du
## sol. Lu à la préparation des cartes d'une zone : changer la valeur ne
## retouche pas une zone déjà résidente.
@export_enum("512 px:512", "1024 px:1024", "2048 px:2048") var terrain_pbr_map_size: int = 1024
## Profondeur de la carte de normale du sol. 1.0 = telle que générée ; au-delà,
## le relief est exagéré.
@export_range(0.0, 4.0, 0.05) var terrain_pbr_normal_strength: float = 1.0
## Part de l'occlusion ambiante du sol. 0 l'éteint sans décocher le PBR.
@export_range(0.0, 1.0, 0.05) var terrain_pbr_ao_amount: float = 1.0
@export_subgroup("Variation esthétique — sans relief")
## Casse les grandes plages uniformes par un bruit procedural de couleur et de
## rugosite. Aucun sommet, heightmap, masque DAoC ou corps de collision ne change.
@export var terrain_macro_variation_enabled: bool = false
## Taille mondiale des taches. Plus grand = variations plus larges et plus lentes.
@export_range(4.0, 512.0, 1.0) var terrain_macro_variation_scale: float = 96.0
## Ecart clair/sombre maximal. 0 conserve exactement la couleur des textures.
@export_range(0.0, 0.35, 0.01) var terrain_macro_color_strength: float = 0.08
## Variation de rugosite ; fonctionne aussi quand le PBR du sol est coupe.
@export_range(0.0, 0.5, 0.01) var terrain_macro_roughness_strength: float = 0.12
## Change le motif sans modifier sa densite ni aucune donnee de zone.
@export_range(0.0, 4096.0, 1.0) var terrain_macro_seed: float = 173.0
@export_subgroup("Expérimental — relief sans autorité")
## Illusion de petits creux et bosses. Ne déplace aucun sommet et se compare à chaud.
@export var terrain_virtual_relief_enabled: bool = false
@export_range(0.0, 0.08, 0.001) var terrain_virtual_relief_depth: float = 0.018
@export_range(2, 12, 1) var terrain_virtual_relief_steps: int = 6
## Densifie uniquement le maillage affiché avec le sampler bilinéaire autoritaire.
## Les collisions restent construites par le maillage historique.
@export_enum("Historique:1", "Bilinéaire ×2:2", "Bilinéaire ×4:4", "Bilinéaire ×8:8") var terrain_visual_bilinear_subdivision: int = 1

@export_subgroup("Ciel et atmosphère")
## Effets atmosphériques, chacun coupable séparément : selon la configuration du
## joueur le client doit pouvoir rester léger et rapide. Ils sont TOUS transmis à
## `DaocSky3DAdapter`, jamais posés en dur sur l'`Environment` : le backend reste
## remplaçable et `DaocEnvironmentController` garde l'autorité sur l'heure et la
## météo. Le coût croît vers le bas de ce sous-groupe.
##
## Le halo lumineux (glow). Le shader Sky3D rend son disque solaire à
## `sun_disk_intensity = 30.0`, donc franchement en HDR, mais Godot n'active PAS
## le glow par défaut : cette valeur était écrasée par le tonemap ACES et le
## soleil sortait en disque blanc plat. Coût écran quasi nul, plus gros écart
## visuel du sous-groupe. Décoché = rendu d'avant le 2026-09-07.
@export var sky_glow_enabled: bool = true
## Force du halo. Au-delà de 1 le ciel clair commence à laver les contrastes.
@export_range(0.0, 2.0, 0.05) var sky_glow_intensity: float = 0.55
## Luminance à partir de laquelle un pixel se met à rayonner. Plus bas = plus de
## surfaces brillent, pas seulement le soleil et les bords de nuages.
@export_range(0.0, 4.0, 0.05) var sky_glow_hdr_threshold: float = 1.0
## L'ambiance du sol est calculée À PARTIR DU CIEL RENDU au lieu de la couleur
## `[sky]` du SECTOR.DAT : le monde entier change de couleur quand le soleil
## descend. C'est ce qui manquait pour que la lumière « vienne du ciel ».
## Décoché (défaut), le comportement validé en P1-20K est conservé au bit près.
## ATTENTION : les PNG nuageux d'origine sont denses ; la couverture nuageuse
## est donc déduite une seule fois — voir `sky_ambient_sky_contribution`.
@export var sky_ambient_from_sky_enabled: bool = false
## Part de l'ambiance prise sur le ciel rendu, le reste venant de la couleur
## `[sky]` de la zone. À 1, la météo n'est PLUS appliquée une seconde fois par
## le multiplicateur d'ambiance : le panorama la porte déjà. À 0 le réglage
## ci-dessus n'a aucun effet. Sans effet si la case ci-dessus est décochée.
@export_range(0.0, 1.0, 0.05) var sky_ambient_sky_contribution: float = 0.85
## Recalcule la carte de radiance du ciel à CHAQUE image. Sans elle, l'ambiance
## et les réflexions se figent sur un ciel périmé et le coucher de soleil ne
## teinte plus rien. Godot plafonne alors la radiance à 256 px — c'est fait ici.
## C'est le seul réglage du sous-groupe qui coûte par image plutôt que par pixel :
## à décocher en premier sur une configuration faible.
@export var sky_realtime_radiance_enabled: bool = true
## Perspective aérienne : le brouillard de zone est appliqué DANS la profondeur,
## pas seulement à l'horizon, ce qui rend les reliefs lointains lisibles comme
## distance et non comme voile plat. Isolé du fog volumétrique ci-dessous, donc
## sans rapport avec la régression Godot 4.6. Coût négligeable.
@export var sky_aerial_perspective_enabled: bool = true
## Dosage de la perspective aérienne. Trop haut, les zones voisines P1-20J
## disparaissent dans le blanc.
@export_range(0.0, 1.0, 0.05) var sky_aerial_perspective_amount: float = 0.35
## Brouillard VOLUMÉTRIQUE, seul moyen d'obtenir de vrais rayons de soleil dans
## Godot. C'est le réglage LE PLUS COÛTEUX du client : il se paie au pixel sur
## tout l'écran, et c'est celui qu'on regrettera sur un siège de fort.
## DÉCOCHÉ PAR DÉFAUT, et pas seulement pour le coût : c'est ce backend qui porte
## la régression Sky3D/Godot 4.6 constatée en P1-20K. Le fog écran de Sky3D reste
## coupé dans tous les cas ; ici seul le volumétrique natif Godot est rallumé.
## Le monde DAoC étant à l'échelle brute, la grille volumétrique est très étirée :
## attendre un rendu grossier avant de conclure à un bug.
@export var sky_volumetric_fog_enabled: bool = false
## Densité du brouillard volumétrique. L'échelle Godot est extrêmement sensible
## dans ce monde exprimé en unités DAoC : 0,00012 (75 % de la plage) vise des
## rais lisibles façon Outward sans transformer le premier plan en laitance.
@export_range(0.0, 0.00016, 0.000005) var sky_volumetric_fog_density: float = 0.00012
## Portée du brouillard volumétrique devant la caméra, en unités DAoC brutes
## (converties par `world_scale`). La grille de calcul est de taille fixe :
## l'allonger dilue le détail au lieu d'en ajouter.
@export_range(500.0, 20000.0, 250.0) var sky_volumetric_fog_length_raw: float = 6000.0
## Quantité de lumière que la directionnelle DAoC injecte dans ce brouillard —
## c'est LITTÉRALEMENT le curseur des rayons crépusculaires. À 0, le volumétrique
## reste un voile gris sans traînées. Sans effet si la case ci-dessus est décochée.
## 1,5 correspond à 75 % de la plage et forme le preset visuel de référence.
@export_range(0.0, 2.0, 0.05) var sky_sun_rays_energy: float = 1.5
## OMBRES. Inclinaison supplémentaire de l'arc solaire, en degrés, ajoutée à
## l'`ecliptic_angle` du `sky_*.dat` de la zone (15 pour Albion). Sans elle le
## soleil passe au zénith à midi et toute façade lit plat. 20 le fait culminer
## vers 55 degrés. 0 rend l'arc du seul DAT.
@export_range(-40.0, 60.0, 1.0) var sky_sun_arc_extra_tilt_degrees: float = 20.0
## Diamètre angulaire du soleil : > 0 arme les ombres douces (PCSS). LAISSER À 0 :
## mesuré le 2026-09-18, dès 0,5° les ombres DISPARAISSENT complètement quand la
## scène est à plus de ~10 000 unités de l'origine — c'est le cas de toute zone
## DAoC. Ce curseur ne sert qu'à le re-vérifier après une mise à jour de Godot.
@export_range(0.0, 3.0, 0.05) var sky_shadow_softness_degrees: float = 0.0
## Portée des ombres du soleil, en unités DAoC brutes (converties par `world_scale`).
## Godot livre 100 : avec un personnage de ~80 unités, les ombres s'arrêtaient à
## un pas de la caméra. C'est cela qui rendait le monde plat, pas la lumière.
@export_range(500.0, 20000.0, 250.0) var sky_shadow_max_distance_raw: float = 5000.0
## Multiplie le soleil (1,15 × météo) sans toucher l'ambiance : creuse l'écart
## entre face éclairée et ombre.
@export_range(0.5, 2.5, 0.05) var sky_sun_energy_scale: float = 1.0
## Teinte seulement la lumiere directe : chaud au soleil bas, ivoire a midi.
## Aucun effet sur l'heure, la meteo, les ombres ou les donnees serveur.
@export var sky_sun_warm_palette_enabled: bool = false
@export_color_no_alpha var sky_sun_day_color: Color = Color(1.0, 0.965, 0.90)
@export_color_no_alpha var sky_sun_low_color: Color = Color(1.0, 0.68, 0.42)
@export_range(0.0, 1.0, 0.05) var sky_sun_warmth_strength: float = 0.65
## COULEURS. Coché : tonemapper AgX au lieu de l'ACES de Sky3D, qui grisait les
## teintes moyennes. Décoché : ACES / blanc 6 tel que livré par le greffon.
@export var sky_tonemap_agx_enabled: bool = true
## Exposition avant tonemapping.
@export_range(0.5, 2.0, 0.05) var sky_tonemap_exposure: float = 1.0
## Saturation et contraste finaux (`Environment.adjustment_*`). 1 et 1 coupent
## l'étage d'ajustement.
@export_range(0.0, 2.0, 0.02) var sky_color_saturation: float = 1.18
@export_range(0.5, 2.0, 0.02) var sky_color_contrast: float = 1.06
## NUAGES. Ombrage des bords et des bases des nuages (0 : voile plat d'avant P1-90).
@export_range(0.0, 1.0, 0.05) var sky_cloud_shading: float = 0.7
## Lumière du soleil filtrant par les bords fins des nuages, face au soleil.
@export_range(0.0, 2.0, 0.05) var sky_cloud_silver_lining: float = 0.6
## Dérive lente de la hauteur, de la compacité des couches et de la direction
## du vent : le ciel n'est jamais deux fois le même. Sans effet sur la météo DAoC.
@export var sky_cloud_drift_enabled: bool = true

@export_subgroup("Contact avec le sol")
## Ajoute des ombres de proximité aux pieds, sous les touffes et contre les murs.

@export_subgroup("Decors Outward")
## Petits rochers decoratifs dans les zones herbeuses, sans collision ajoutee.
@export var outward_rocks_enabled: bool = false:
	set(value):
		outward_rocks_enabled = value
		call_deferred("_apply_outward_decor_options")

@export_subgroup("Contact au sol")
@export var ground_contact_ssao_enabled: bool = true
@export_range(0.1, 4.0, 0.05) var ground_contact_ssao_radius: float = 1.60
@export_range(0.0, 4.0, 0.05) var ground_contact_ssao_intensity: float = 2.00
@export_range(0.1, 4.0, 0.05) var ground_contact_ssao_power: float = 1.35

@export_group("Collisions")
@export_subgroup("Terrain")
## Génère la collision du terrain à partir des mêmes maillages que le terrain
## visible : ce qu'on voit et ce sur quoi on marche ne peuvent pas diverger.
@export var build_terrain_collision: bool = true
## Calque de collision Godot porté par le terrain.
@export var terrain_collision_layer: int = 1
## Masque du terrain : ce que son corps détecte. 0 = il ne teste rien, il est
## seulement heurté par les autres.
@export var terrain_collision_mask: int = 0

@export_subgroup("Limites de zone (bound.csv)")
## Construit des murs invisibles depuis le `bound.csv` du client, aux limites
## praticables de la zone.
@export var build_bound_collision: bool = true
## Les murs de limite arrêtent réellement la capsule joueur. OFF = présents mais
## traversables.
@export var bound_collision_blocks_player: bool = true
## Calque de collision Godot porté par les murs de limite.
@export var bound_collision_layer: int = 1
## Masque des murs de limite. 0 = ils ne testent rien, ils sont seulement heurtés.
@export var bound_collision_mask: int = 0
## Épaisseur des murs de limite, en unités DAoC brutes. Trop fin, un joueur rapide
## peut traverser entre deux pas de physique.
@export var bound_collision_thickness_raw: float = 90.0
## Profondeur des murs sous le terrain, en unités DAoC brutes (valeur négative).
@export var bound_collision_bottom_offset_raw: float = -1000.0
## Hauteur des murs au-dessus du terrain, en unités DAoC brutes.
@export var bound_collision_top_offset_raw: float = 3000.0
## Rend les murs de limite visibles pour les inspecter.
@export var bound_collision_debug_visible: bool = false

@export_subgroup("Props solides")
## Première passe de collision des props, basée sur l'AABB du modèle placé.
## `fixtures.csv` fait autorité : seule une fixture avec Collide/collide != 0
## devient candidate. Les familles végétales restent exclues tant qu'une politique
## arbres/plantes n'est pas décidée.
@export var generate_prop_collisions: bool = true
## Bitmask séparé du terrain et des limites, pour que les requêtes de forme du
## joueur ne touchent que les props solides.
@export var prop_collision_layer: int = 4
## Masque des props. 0 = ils ne testent rien, ils sont seulement heurtés.
@export var prop_collision_mask: int = 0
## Les props solides arrêtent réellement la capsule joueur.
@export var prop_collision_blocks_player: bool = true
## Plafond de résultats pour une requête de forme sur les props. Réglage hérité :
## aucun consommateur runtime ne le lit actuellement.
@export var prop_collision_query_max_hits: int = 8
## Rend les corps de collision des props visibles pour les inspecter.
@export var prop_collision_debug_visible: bool = false
## Hotfix V5C2 : si le cache de placement JSON ne porte pas le flag Collide,
## relire `fixtures.csv` si possible ; sinon générer une collision pour tout prop
## non végétal. Volontairement large, mais ça évite le « 0 corps donc tout
## traversable » des anciens caches.
@export var prop_collision_fallback_when_flag_missing: bool = true
## Trace dans la console la décision prise pour chaque prop (collision ou non).
@export var prop_collision_log_decisions: bool = true
## Fragments de noms qui excluent un prop de la collision, par sous-chaîne. Couvre
## les familles végétales : arbres, buissons, feuillages.
@export var prop_collision_excluded_name_tokens: PackedStringArray = PackedStringArray([
	"tree", "speedtree", "grass", "bush", "shrub", "plant", "flower",
	"fern", "weed", "leaf", "leaves", "foliage", "ivy", "moss",
	"oak", "pine", "birch", "elm", "beech", "chestnut", "maple",
	"grove", "sapling", "branch", "pintre", "pinetree", "birchtree",
	"oaktree", "deadtree", "vrgrn", "whitepine", "reed", "rush"
])
## Noms de modèles exclus au nom exact, en complément des fragments ci-dessus.
@export var prop_collision_excluded_exact_names: PackedStringArray = PackedStringArray([
	"b_htoak1", "b_htoakb", "bmtntre1", "beech", "bpinea", "bpinetree",
	"bpintre1", "chestnut", "elm1", "elm2", "hbareskny", "hbirchsingle",
	"hbirchtree", "hdeadtree", "helm", "helm1grey", "helm2", "helm2tan",
	"holdgrove", "hoaktree", "maple", "mightyoak", "mightyoak-small",
	"nbirchtree", "npinea", "npinea-s", "npinedk", "npinetree",
	"npinetree-s", "npintre-s", "npintre1", "nvrgrn1-s", "pintre1",
	"tall_whitepine", "tall_whitepine2", "tall_whitepine2_snow",
	"tall_whitepine3", "vrgrn1",
	# P1-76 — passages du fort tutoriel (région 27) : arche de porte et donjon
	# creux, qu'une boîte englobante fermerait. Même liste que DaocGameWorld.
	"tutorial_2gate_alb", "tutorial_2gate_hib", "tutorial_2gate_mid",
	"tutorial_keep_alb", "tutorial_keep_hib", "tutorial_keep_mid"
])
## Rétrécit horizontalement l'AABB de collision, pour ne pas bloquer plus large
## que le modèle visible.
@export_range(0.10, 1.00, 0.01) var prop_collision_size_scale_xz: float = 0.72
## Rétrécit verticalement l'AABB de collision.
@export_range(0.10, 1.00, 0.01) var prop_collision_size_scale_y: float = 0.90
## Trace la construction des collisions dans la console.
@export var log_collision: bool = true

@export_group("Transitions de zone (zonejumps)")
## Construit les volumes de transition lus dans `zonejump.csv`, avec leur
## visualisation de debug.
@export var build_zonejump_debug: bool = true
## Rend les volumes de transition visibles.
@export var zonejump_debug_visible: bool = false
## Les volumes sont de vraies Area3D capables de déclencher une transition.
## OFF = simple décor de debug.
@export var zonejump_area_enabled: bool = true
## Fusionne les paires réciproques redondantes de `zonejump.csv`. Optionnel et OFF
## par défaut : à n'activer que pour comparer avec un index dédoublonné.
@export var zonejump_optional_dedupe_pairs: bool = false
## Épaisseur des volumes de transition, en unités DAoC brutes.
@export var zonejump_thickness_raw: float = 60.0
## Déclenche la transition dès l'entrée dans le volume, sans commande. OFF par
## défaut (P1-N6G) : le franchissement reste explicite.
@export var zonejump_auto_transition_enabled: bool = false
## Avec la transition automatique, effectue le saut directement au lieu de
## simplement signaler le franchissement.
@export var zonejump_direct_transition_enabled: bool = true
## Charge la zone cible si elle n'est pas déjà en mémoire au moment du saut.
@export var zonejump_load_missing_target_zone: bool = true
## Distance en avant du point d'arrivée où réapparaît le joueur, en unités DAoC
## brutes, pour ne pas retomber immédiatement dans le volume de départ.
@export var zonejump_spawn_offset_raw: float = 900.0
## Décalage vertical à l'arrivée, en unités DAoC brutes.
@export var zonejump_spawn_z_offset_raw: float = 3.0
## Rayon de recherche du zonejump le plus proche pour les commandes de saut, en
## unités DAoC brutes.
@export var zonejump_nearest_go_radius_raw: float = 2400.0
## Nombre d'évènements de zonejump conservés dans le journal.
@export var zonejump_event_log_limit: int = 24
## Nombre de transitions conservées dans le journal.
@export var zonejump_transition_log_limit: int = 16
## Trace la construction et les transitions de zonejump dans la console.
@export var log_zonejump: bool = true

@export_group("Eau")
@export_subgroup("Surface et rendu")
## Construit les plans d'eau depuis SECTOR.DAT : bandes `leftXX/rightXX`, hauteur,
## type, courant et tessellation d'origine. Les requêtes d'eau du gameplay restent
## la propriété de DaocWaterRuntime.
@export var build_water: bool = true
## Opacité de la surface d'eau.
@export var water_alpha: float = 0.62
## Décalage vertical de la surface au-dessus de la hauteur déclarée, en unités
## DAoC brutes. Évite le z-fighting avec une berge au même niveau.
@export var water_vertical_offset: float = 8.0
## Plafond de subdivision du maillage d'eau. SECTOR.DAT demande parfois 64 ou 100 :
## ce plafond évite d'en payer le coût au runtime.
@export_range(1, 24, 1) var water_tessellation_cap: int = 12
## Échelle des UV de l'eau rapportée au monde : plus petit = motif plus étiré.
@export_range(0.00001, 0.01, 0.00001) var water_uv_world_scale: float = 0.00055
## Revient à la couleur d'eau historique du viewer au lieu du rendu moderne
## P1-20L piloté par SECTOR.DAT et `watery.png`.
@export var use_legacy_water_color: bool = false
## Texture de vagues moderne du projet ; decoche pour relire watery.png depuis
## le client DAoC. N'agit que sur le rendu du materiau.
@export var water_modern_texture_enabled: bool = true
## Berges : écume de plage sur l'océan, mousse et fondu dans le sol pour lac,
## rivière et marais. Cache la ligne brisée où la surface coupe le relief.
@export var water_shore_enabled: bool = true
## Intensité des berges (écume et mousse), 0 = surface d'avant.
@export_range(0.0, 1.0, 0.01) var water_shore_strength: float = 0.85
## Trace la construction de l'eau dans la console.
@export var log_water: bool = true

@export_subgroup("Immersion, caustiques et sillage")
## Active le retour visuel autour de l'eau (P1-20L2). Ne modifie ni `is_in_water`,
## ni la profondeur, ni la vitesse, ni les collisions.
@export var water_fx_enabled: bool = true
## Filtre sous-marin et caustiques quand la caméra passe sous la surface.
@export var water_underwater_enabled: bool = true
## Anneaux de sillage laissés à la surface quand le joueur se déplace dans l'eau.
@export var water_player_wake_enabled: bool = true
## Vitesse de défilement des 64 images de caustiques du client, en images/seconde.
@export_range(1.0, 30.0, 1.0) var water_caustic_fps: float = 12.0
## Taille d'un anneau de sillage, en unités DAoC brutes.
@export_range(32.0, 800.0, 1.0) var water_player_wake_size_raw: float = 230.0
## Vitesse minimale du joueur, en unités DAoC brutes, en dessous de laquelle aucun
## anneau n'est émis.
@export_range(0.0, 500.0, 5.0) var water_player_wake_speed_threshold_raw: float = 30.0

@export_group("Végétation")
## Construit l'herbe de la zone. OFF = sol nu, utile pour mesurer un coût de rendu.
@export var build_vegetation: bool = true
## Affiche ou masque la végétation déjà construite, sans la reconstruire.
@export var vegetation_visible: bool = true
## Grass Vanilla conserve exactement le rendu historique. Grass Remaster utilise
## les masques de splat DAoC et TerrainTex, des MultiMesh locaux au joueur, un
## fondu progressif et un vent GPU.
@export_enum("Grass Vanilla", "Grass Remaster") var vegetation_render_mode: int = 0

## R10-HF2 — le vent dans les feuilles des arbres.
##
## Le Grass Remaster anime l'herbe depuis P1-20M ; les arbres restaient figés, ce
## qui se lit comme deux mondes superposés. Le vent est LE MÊME — direction,
## vitesse et rafales partagées avec l'herbe — mais le mouvement diffère : une
## lame plie depuis sa racine, une feuille est portée par une branche qui oscille
## et frissonne par-dessus.
##
## Trois familles de surfaces, mesurées : les cartes de feuilles SpeedTree et les
## frondes reçoivent le vent, l'écorce reste rigide. Un tronc qui ondulerait
## serait pire qu'un arbre immobile.
##
## AUCUNE DES TROIS AMPLITUDES N'EST CALIBRÉE — plausibles, pas mesurées, au même
## titre que `speedtree_units_to_daoc`. Décoché rend exactement comme avant.
@export var foliage_wind_enabled: bool = true
@export_range(0.0, 200.0, 1.0) var foliage_canopy_strength_raw: float = 40.0
@export_range(0.0, 100.0, 1.0) var foliage_leaf_flutter_strength_raw: float = 16.0
@export_range(100.0, 6000.0, 50.0) var foliage_wind_height_reference_raw: float = 1200.0
## Trace la construction de la végétation dans la console.
@export var log_vegetation: bool = true

@export_subgroup("Grass Vanilla")
## Multiplicateur global du score de pousse. Le score final vaut
## présence_herbe × poids_densité × cette valeur, et donne le nombre de touffes.
@export_range(0.0, 8.0, 0.05) var vegetation_density: float = 0.85
## Un pixel de grassmap sur N est échantillonné. Plus grand = moins d'herbe et
## moins de calcul.
@export_range(1, 16, 1) var vegetation_sample_step: int = 2
## Plafond dur d'instances d'herbe par secteur, quels que soient les autres
## réglages.
@export var vegetation_max_instances_per_sector: int = 2400
## Score de pousse minimal pour qu'un échantillon donne au moins une touffe.
## 0 = aucun filtrage.
@export var vegetation_density_threshold: float = 0.0
## Plancher de présence appliqué à la grassmap : même un pixel très faible compte
## au moins pour cette valeur.
@export_range(0.0, 1.0, 0.01) var vegetation_grass_presence_floor: float = 0.32
## Plancher du poids tiré de la densemap : à 1.0 la densemap n'a plus d'effet, à
## 0.0 elle peut annuler complètement la pousse.
@export_range(0.0, 1.0, 0.01) var vegetation_dense_floor: float = 0.40
## Nombre maximal de touffes générées pour un même échantillon.
@export_range(1, 4, 1) var vegetation_max_cards_per_sample: int = 2
## Largeur d'une carte d'herbe de repli, en unités DAoC brutes (P1-20G-H2 : ×0,1).
@export var vegetation_card_width: float = 8.2
## Hauteur d'une carte d'herbe de repli, en unités DAoC brutes (P1-20G-H2 : ×0,1).
@export var vegetation_card_height: float = 21.0
## Remonte les touffes au-dessus du terrain, en unités DAoC brutes, pour que leur
## pied ne disparaisse pas dans le sol.
@export var vegetation_vertical_offset: float = 6.0
## Oriente chaque touffe au hasard, pour casser l'alignement en grille.
@export var vegetation_random_yaw: bool = true
## Interdit l'herbe sur les plans d'eau lus dans SECTOR.DAT.
@export var vegetation_exclude_water: bool = true
## Marge d'exclusion autour de l'eau, en unités DAoC brutes.
@export var vegetation_water_margin: float = 260.0
## Teinte appliquée aux cartes d'herbe de repli. Sans effet quand une recette CSV
## DAoC fournit son propre atlas.
@export var vegetation_color: Color = Color(0.26, 0.42, 0.20, 0.86)
## Rend l'herbe sans éclairage : plus rapide et plus proche du client d'origine,
## mais insensible au cycle jour/nuit.
@export var vegetation_use_unshaded_material: bool = true
## Utilise les recettes d'herbe DAoC de `zones/textures` quand elles existent.
## L'atlas est de préférence le PNG exporté à côté du DDS d'origine.
@export var vegetation_use_daoc_grass_csv: bool = true
## Recette d'herbe utilisée, par nom de fichier CSV du client.
@export var vegetation_grass_csv_name: String = "grass_alb.csv"
## Atlas associé. Vide, il est déduit du nom du CSV : grass_alb.csv → grass_alb.png,
## puis repli .dds.
@export var vegetation_grass_atlas_name: String = ""
## Les valeurs de grassmap sont codées par dizaines (10, 20, 30… ; 0 = pas d'herbe)
## alors que les groupes du CSV DAoC commencent à zéro : -1 fait donc 10 → groupe 0.
@export var vegetation_grass_group_offset: int = -1
## Facteur appliqué aux tailles de touffe lues dans le CSV (P1-20G-H2 : ×0,1).
@export var vegetation_csv_size_scale: float = 0.8
## Seuil d'alpha-scissor des cartes d'herbe : plus haut = bords plus nets, moins
## de halo gris.
@export_range(0.0, 1.0, 0.01) var vegetation_alpha_scissor_threshold: float = 0.32

@export_subgroup("Grass Remaster")
## Une carte alternative placée dans `datXXX` devient l'autorité STRICTE du mode
## Remaster. Le mode Vanilla continue toujours de lire `grassmap.pcx`.
@export var grass_remaster_prefer_alternative_map: bool = true
## Nom de la carte alternative cherchée dans le dossier `datXXX` de la zone.
@export var grass_remaster_alternative_map_name: String = "grassmapALT.pcx"
## Le rôle natif exact de `densemap.pcx` n'est pas assez établi : en zone 51,
## 52 172 de ses pixels positifs tombent hors du masque grassmap. Disponible pour
## comparaison, mais elle ne module pas le Remaster par défaut.
@export var grass_remaster_use_densemap: bool = false
## Côté d'un chunk d'herbe, en unités DAoC brutes. Le rendu suit le joueur et ne
## recalcule qu'au passage d'un chunk.
@export_range(1024.0, 8192.0, 256.0) var grass_remaster_chunk_size_raw: float = 4096.0
## Écart de base entre deux touffes, en unités DAoC brutes. La grille LOD
## 60/81/120 en dérive selon la distance.
@export_range(45.0, 500.0, 5.0) var grass_remaster_spacing_raw: float = 60.0
## Distance, en unités DAoC brutes, où l'herbe commence à disparaître en trame
## progressive.
@export_range(1000.0, 20000.0, 250.0) var grass_remaster_fade_start_raw: float = 8500.0
## Distance, en unités DAoC brutes, où l'herbe a totalement disparu.
@export_range(2000.0, 30000.0, 250.0) var grass_remaster_fade_end_raw: float = 12000.0
## Multiplicateur de densité du Remaster.
@export_range(0.0, 2.0, 0.05) var grass_remaster_density: float = 1.40
## Couverture minimale du masque, en dessous de laquelle aucune touffe n'est posée.
## Les retouches éclaircies de grassmapALT imposent une couverture pleine.
@export_range(0.0, 1.0, 0.01) var grass_remaster_coverage_threshold: float = 0.10
## Plafond dur d'instances par chunk.
@export_range(64, 6000, 16) var grass_remaster_max_instances_per_chunk: int = 5000
## Largeur d'un brin Remaster, en unités DAoC brutes.
@export_range(8.0, 160.0, 1.0) var grass_remaster_card_width_raw: float = 64.0
## Hauteur d'un brin Remaster, en unités DAoC brutes.
@export_range(8.0, 200.0, 1.0) var grass_remaster_card_height_raw: float = 70.0
## Amplitude maximale du vent, en unités DAoC brutes (un brin Remaster fait 70
## unités). Convertie par `world_scale` : l'ancienne valeur 0,58 était invisible.
@export_range(0.0, 60.0, 1.0) var grass_remaster_wind_strength: float = 30.0
## Vitesse d'oscillation du vent. Le pied reste fixe, seule la pointe bouge.
@export_range(0.0, 4.0, 0.05) var grass_remaster_wind_speed: float = 1.35
## Part de rafale ajoutée à l'oscillation régulière, en seconde fréquence.
@export_range(0.0, 1.0, 0.05) var grass_remaster_wind_gust_strength: float = 0.72
## Densifie les anciennes grassmaps autour des arbres et plantes poses par le
## client. Une grassmapALT reste automatiquement prioritaire et desactive ce mode.
@export var grass_remaster_native_seed_enabled: bool = true
## Les bouquets de feuilles orange restent disponibles pour les zones d'automne,
## mais sont trop grands et trop dominants pour la prairie de référence.
@export var grass_remaster_autumn_groundcover_enabled: bool = true
## Rayon d'influence des arbres natifs, en unites DAoC brutes.
@export_range(0.0, 4000.0, 50.0) var grass_remaster_native_tree_radius_raw: float = 1450.0
## Rayon d'influence des petites plantes natives, en unites DAoC brutes.
@export_range(0.0, 2500.0, 50.0) var grass_remaster_native_plant_radius_raw: float = 900.0

@export_group("Ciel, jour-nuit et météo")
## `DaocEnvironmentController` devient l'autorité unique sur l'heure, le profil de
## zone et le front météo. Sky3D n'est qu'un backend graphique vendorisé et
## remplaçable ; les précipitations sont des GPUParticles3D.
@export var daoc_environment_enabled: bool = true
## Heure de départ hors ligne, en heures décimales. Ignorée quand la zone déclare
## un `override_time` dans zones.dat.
@export_range(0.0, 23.999, 0.25) var environment_offline_time_hours: float = 12.0
## Fait défiler le temps hors ligne. OFF = heure figée sur la valeur ci-dessus.
@export var environment_offline_cycle_enabled: bool = false
## Durée réelle d'une journée complète quand le cycle hors ligne tourne, en minutes.
@export_range(0.1, 1440.0, 0.1) var environment_offline_minutes_per_day: float = 12.0
## Météo simulée hors ligne, en l'absence d'un `SendWeather` serveur.
@export_enum("CLEAR", "RAIN", "SNOW") var environment_offline_weather: String = "CLEAR"
## Force du front météo hors ligne, de 0 (rien) à 1 (maximum).
@export_range(0.0, 1.0, 0.05) var environment_offline_weather_intensity: float = 0.0
## Champ `fogdiffusion` du front météo, conservé dans son échelle DAoC brute 0-255.
@export_range(0.0, 255.0, 1.0) var environment_offline_fog_diffusion: float = 80.0
## Durée du fondu entre deux états météo, en secondes.
@export_range(0.0, 60.0, 0.5) var environment_weather_transition_seconds: float = 8.0
## Trace l'heure, le profil de zone et l'état météo dans la console.
@export var environment_log_state: bool = true

@export_group("Horizon et zones lointaines")
## Remplit l'horizon avec le relief GROSSIER des autres zones de la région. Sans
## lui, le monde s'arrête net au bord de la zone chargée, et ce vide se lit comme
## un mur clair — ce n'est pas du LOD, c'est la fin des données.
@export var distant_terrain_enabled: bool = true
## R4, dernière pièce : l'horizon appartient au `DaocZoneStreamer` et SUIT les
## zones réellement résidentes, au lieu d'être bâti une fois sur la liste
## `zones` de l'inspecteur. Décoché, il redevient une branche du viewer bâtie au
## démarrage — l'ancien comportement exact, mais alors franchir une frontière
## dessinerait la voisine deux fois, en vrai et en relief lointain.
@export var horizon_follows_streamer: bool = true
## Un point sur N de la carte de hauteurs. 4 donne un relief franc pour environ
## 30 000 sommets par région ; 8 ou 16 allègent encore.
@export_range(1, 32, 1) var distant_terrain_step: int = 4
## Nombre maximal de zones voisines dessinées à l'horizon.
@export_range(1, 64, 1) var distant_terrain_max_zones: int = 24
## Les 64 PNG `lodXX-YY` natifs de chaque zone sont réduits dans un atlas runtime.
## 512 px garde couleurs et côtes lisibles pour environ 1,33 Mio avec mipmaps.
@export_enum("256 px:256", "512 px:512", "1024 px:1024") var distant_lod_colour_atlas_size: int = 512
## P1-33 — palier PROCHE : le rendu des zones lointaines qui partagent une vraie
## frontière avec une zone résidente et dont on s'approche. Décoché, toutes les
## zones lointaines gardent l'atlas ci-dessus et le pas ci-dessus — le rendu
## exact d'avant P1-33.
@export var distant_near_border_lod_enabled: bool = true
## Taille de l'atlas au palier proche. Les 64 tuiles `lodXX-YY.png` du client font
## 256 px chacune, donc 2048 px n'est PAS une montée en résolution : c'est le 1
## pour 1 avec la source, 32 unités DAoC par texel au lieu de 128. Compter ~22
## Mio par zone servie à ce palier.
@export_enum("512 px:512", "1024 px:1024", "2048 px natif:2048") var distant_near_lod_atlas_size: int = 2048
## Un point sur N de la carte de hauteurs dans la bande proche de la frontière
## partagée. 1 = tout ce que le `.r16` porte, soit un point tous les 256 unités.
@export_range(1, 8, 1) var distant_near_lod_step: int = 1
## Largeur de cette bande fine, en unités DAoC brutes.
@export_range(1024.0, 32768.0, 512.0) var distant_near_lod_band_raw: float = 8192.0
## Marge fixe du rayon qui décide du palier proche, en unités DAoC brutes.
@export_range(0.0, 65536.0, 512.0) var distant_near_lod_base_raw: float = 12000.0
## Secondes d'anticipation du palier proche. Même principe que le préchargement :
## plus on va vite, plus tôt la voisine passe en rendu fin.
@export_range(0.0, 20.0, 0.5) var distant_near_lod_seconds: float = 6.0
## Nombre maximal de zones servies au palier proche en même temps.
@export_range(0, 4, 1) var distant_near_lod_max_zones: int = 2
## Période minimale entre deux replanifications, en secondes. Le plan est
## recalculé à cette cadence ; l'horizon n'est REBÂTI que si la sélection change
## réellement.
@export_range(0.05, 5.0, 0.05) var zone_lod_plan_interval_seconds: float = 0.35
## Habille les tranches terrestres exposées avec `oceanuscliff.png` du client, au
## lieu de laisser une découpe verticale nue. Sans collision ni ombre.
@export var distant_cliffs_enabled: bool = true
## ATTENTION — réglage expérimental développé en observant Isle of Glass et Avalon
## Isle. Cette nappe peut masquer un relief légitime dans d'autres zones : la
## revalider visuellement par région et par royaume. Elle est interdite sur tout
## segment dont au moins une extrémité touche la mer.
@export var distant_non_maritime_border_fog_enabled: bool = true
## Relief de fond permanent au-delà de l'emprise connue de la région, pour briser
## l'horizon vide en conservant 32 trouées maritimes.
@export var distant_horizon_backdrop_enabled: bool = true
## Nombre de segments par côté du relief de fond. Plus haut = silhouette plus fine
## et plus coûteuse.
@export_range(8, 64, 1) var distant_horizon_segments_per_side: int = 28
## Distance du relief de fond, en unités DAoC brutes.
@export_range(8192.0, 131072.0, 1024.0) var distant_horizon_backdrop_distance_raw: float = 47186.0
## Densité de brouillard ajoutée en permanence pour noyer le relief de fond. Le
## front météo DAoC s'ajoute par-dessus.
@export_range(0.0, 0.00001, 0.0000001) var distant_horizon_fog_density_addition: float = 0.0000042

@export_group("Éclairage legacy")
## Lit `lights.csv` et crée des OmniLight3D approximatives sous LightingRoot.
## Ambiance et debug DAoC : ce n'est pas l'éclairage final.
@export var build_legacy_lights: bool = true
## Affiche ou masque les lumières déjà construites, sans les reconstruire.
@export var legacy_lights_visible: bool = true
## Énergie de chaque lumière legacy.
@export var legacy_light_energy: float = 3.0
## Portée de chaque lumière legacy, en unités DAoC brutes.
@export var legacy_light_range: float = 4200.0
## Atténuation de chaque lumière legacy. Plus haut = chute plus brutale.
@export var legacy_light_attenuation: float = 0.18
## Remonte les lumières au-dessus de leur position source, en unités DAoC brutes.
@export var legacy_light_vertical_offset: float = 24.0
## Colore chaque lumière selon son type DAoC plutôt qu'en blanc uniforme.
@export var use_legacy_light_type_colors: bool = true
## Les lumières legacy projettent des ombres — sous BUDGET depuis P1-91 : seules
## les N lampes les plus proches de la caméra projettent, l ombre fond avec la
## distance. Décoché : aucune ombre de lampe, comme avant.
@export var legacy_lights_cast_shadows: bool = false
## Lampes qui projettent en même temps (six faces de cubemap chacune, par image).
@export_range(0, 12, 1) var legacy_light_shadow_budget: int = 4
## Flou des bords de l ombre (1 = dur, Godot). Feux et lanternes : large.
@export_range(0.0, 6.0, 0.1) var legacy_light_shadow_blur: float = 2.6
## Opacité de l ombre (1 = noir). Une lampe n éteint pas la nuit autour d elle.
@export_range(0.0, 1.0, 0.05) var legacy_light_shadow_opacity: float = 0.82
## Les types de feu vacillent (énergie et ombre) ; les lueurs magiques non.
@export var legacy_lights_flicker: bool = true
@export_range(0.0, 0.5, 0.01) var legacy_light_flicker_amount: float = 0.12
## Pose un petit repère visible à l'emplacement de chaque lumière.
@export var legacy_lights_show_markers: bool = true
## Rayon des repères de lumière, en unités DAoC brutes.
@export var legacy_light_marker_radius: float = 95.0

@export_subgroup("Aperçu nuit")
## Force une scène sombre pour juger les lumières legacy seules, en remplaçant le
## soleil et l'ambiance par les deux valeurs ci-dessous.
@export var legacy_lights_preview_dark_scene: bool = false
## Énergie du soleil pendant l'aperçu nuit.
@export var legacy_preview_sun_energy: float = 0.0
## Énergie de la lumière ambiante pendant l'aperçu nuit.
@export var legacy_preview_ambient_energy: float = 0.015
## Trace la construction des lumières legacy dans la console.
@export var log_legacy_lights: bool = true

@export_group("Peuplement du monde")
@export_subgroup("Gothwaite - Isle of Glass (F5)")
## Place les entités réellement capturées autour de Heyveno depuis des scènes
## préconverties. Aucune conversion NIF ni accès réseau au runtime.
@export var gothwaite_population_enabled: bool = true
## Fixture canonique des 311 entités proches, issue de la capture de 831 paquets.
@export_file("*.json") var gothwaite_population_fixture_path: String = "res://reports/p1_20e_nearby_world_offline/p1_20e_entity_registry.json"
## Manifeste `model_id → scène` des entités vivantes, exporté par le Character Lab.
@export_file("*.json") var gothwaite_population_manifest_path: String = "res://assets/daoc/npc_showcase/manifest.json"
## Manifeste des props statiques, résolus via `objects.csv → items.csv`.
@export_file("*.json") var gothwaite_population_prop_manifest_path: String = "res://assets/daoc/gothwaite_props/manifest.json"
## Zone client où le peuplement est posé.
@export var gothwaite_population_zone: int = 51
## Région serveur correspondante.
@export var gothwaite_population_region: int = 51
## Origine monde X de la zone, pour convertir les coordonnées serveur de la capture
## en coordonnées de zone.
@export var gothwaite_population_world_origin_x: float = 491520.0
## Origine monde Y de la zone.
@export var gothwaite_population_world_origin_y: float = 491520.0
## Unités DAoC par mètre dans les scènes sources.
@export var gothwaite_population_source_units_per_meter: float = 100.0
## Distance de culling des entités autour du joueur, en mètres.
@export var gothwaite_population_culling_distance_m: float = 80.0
## Affiche une étiquette sur chaque entité correctement résolue.
@export var gothwaite_population_ready_labels_visible: bool = false
## Affiche une étiquette sur les entités sans scène, restées à l'état de balise.
## Ne jamais leur inventer un remplacement visuel.
@export var gothwaite_population_fallback_labels_visible: bool = true
## Les Z des paquets D9/DA sont des coordonnées serveur, pas un contrat de contact
## au sol uniforme. Reprojeter les bases visuelles évite les PNJ et objets
## suspendus ; une passe physique conserve les vrais pontons et planchers.
@export var gothwaite_population_grounding_enabled: bool = true

@export_subgroup("Boucle vivante (R2)")
## R2 — peuple le monde AU FIL DES PAQUETS au lieu de le poser d'un bloc. Le
## monde commence vide, les 310 entités apparaissent dans l'ordre de la capture
## (paquets 14 à 806), puis 24 paquets de déplacement bougent 8 d'entre elles.
##
## L'état final est le même qu'en bloc, à une exception PLUS JUSTE : les entités
## qui se sont déplacées finissent à leur position de déplacement, alors que le
## peuplement en bloc ignorait purement et simplement les paquets `0xA1`.
##
## Décoché, le monde est bâti d'un bloc comme avant.
@export var use_living_entity_stream: bool = false
## Événements appliqués par trame. `0` applique tout immédiatement — l'écran ne
## montre alors aucune différence avec le bloc. Une valeur positive étale le
## remplissage : c'est ce qu'il faut cocher pour VOIR le monde se peupler.
##
## Chaque apparition instancie une scène DAoC complète : au-delà de quelques
## dizaines, la trame se fige et le flux redevient indistinguable d'un bloc.
@export_range(0, 200, 1) var living_stream_events_per_frame: int = 0
## Calques interrogés par la passe physique d'ancrage (terrain et props solides).
@export_flags_3d_physics var gothwaite_population_grounding_collision_mask: int = 5
## Départ du rayon d'ancrage au-dessus de la position source, en unités DAoC brutes.
@export var gothwaite_population_grounding_probe_above_raw: float = 128.0
## Portée du rayon d'ancrage sous la position source, en unités DAoC brutes.
@export var gothwaite_population_grounding_probe_below_raw: float = 4096.0
## Écart toléré au Z source avant de considérer l'entité comme volante ou posée sur
## un support, en unités DAoC brutes.
@export var gothwaite_population_grounding_source_tolerance_raw: float = 256.0

@export_subgroup("Parade de modèles (TestBG)")
## Oracle de non-régression du registre exporté : instancie une fois chaque
## `model_id` disposant réellement d'une scène. Séparé de Gothwaite, et à ne pas
## remplacer par lui.
@export var npc_showcase_enabled: bool = true
## Registre `model_id → scène` consommé par la parade.
@export_file("*.json") var npc_showcase_manifest_path: String = "res://assets/daoc/npc_showcase/manifest.json"
## Zone d'accueil de la parade : une grande parcelle parfaitement plate.
@export var npc_showcase_zone: int = 242
## Coordonnée X du centre de la grille, en unités DAoC brutes.
@export var npc_showcase_origin_x: float = 32768.0
## Coordonnée Y du centre de la grille, en unités DAoC brutes.
@export var npc_showcase_origin_y: float = 32768.0
## Écart entre deux modèles voisins, en unités DAoC brutes (200 = 2 mètres).
@export var npc_showcase_spacing_raw: float = 200.0
## Nombre de colonnes de la grille.
@export_range(1, 20, 1) var npc_showcase_columns: int = 10
## Unités DAoC par mètre dans les scènes sources.
@export var npc_showcase_source_units_per_meter: float = 100.0
## Affiche le `model_id` au-dessus de chaque modèle de la parade.
@export var npc_showcase_labels_visible: bool = true

@export_group("Combat - serveur local (P1-21A)")
## Serveur local : l'autorite de combat qui tient la place du vrai serveur.
## Il detient les points de vie, decide si un coup touche et declare la mort.
## Aucun reseau n'est ouvert. Le jour ou un vrai OpenDAoC est joignable, ce
## module se debranche sans toucher au reste du client.
@export var local_server_enabled: bool = true
## Niveau du joueur. La capture CharacterOverview ne le porte PAS — la fixture
## annonce 0 pour Heyveno — donc il vient d'ici, et le rapport le declare.
@export_range(1, 50, 1) var local_server_player_level: int = 5
## Portee de melee, en unites DAoC brutes. Environ 200 en jeu.
@export_range(50.0, 1000.0, 10.0) var local_server_melee_range_raw: float = 200.0
## Les PNJ frappes ripostent, sur place. Aggro a distance et approche restent
## le chantier suivant : ici, un PNJ ne se deplace jamais.
@export var local_server_retaliation_enabled: bool = true
## Graine des tirages de combat. A graine egale, une session rejouee donne
## exactement les memes coups — un bug de combat reste donc reproductible.
@export var local_server_seed_base: int = 20260902
## Recopie chaque evenement de combat dans la console.
@export var local_server_log_events: bool = false

@export_subgroup("Interface de combat")
## HUD provisoire : vie du joueur, vie de la cible, journal. Les vraies fenetres
## du client (`ui/isles/*.xml`) sont un jalon a part.
@export var combat_hud_enabled: bool = true
## Rayon de recherche de la cible la plus proche, en unites DAoC brutes.
@export_range(200.0, 10000.0, 100.0) var combat_target_radius_raw: float = 2400.0
## Touche qui cible le vivant attaquable le plus proche.
@export var combat_target_key: Key = KEY_TAB
## Touche qui engage ou rompt le combat sur la cible courante.
@export var combat_attack_key: Key = KEY_1

@export_subgroup("Interface DAoC d'origine")
## Monte les VRAIES fenetres du client, baties depuis leur XML. Active depuis
## P1-21F : sans elle le F5 n'affiche aucune interface d'origine.
## Le HUD provisoire de P1-21A reste affiche en parallele - il porte le journal
## de combat, qu'aucune fenetre XML ne couvre encore.
@export var daoc_ui_enabled: bool = true
## Skin lu dans `ui/`. `atlantis` est le seul COHERENT : `isles` cite six
## textures qu'il ne declare pas dans son propre `assets.xml`.
@export var daoc_ui_skin: String = "atlantis"
## Echelle de la couche entiere. La contrainte 1:1 appartenait a l'ancien
## moteur ; les tailles natives des fenetres ne changent pas.
@export_range(0.5, 4.0, 0.05) var daoc_ui_scale: float = 1.0
## Fenetres DISPONIBLES, par `Name` ou `WindowId`. Elles sont toutes baties,
## mais seules `stats_index` et `summary` sont ouvertes a la premiere session -
## le joueur ouvre le reste depuis les six ronds du menu. Ensuite c'est son
## fichier `user://daoc_ui_layout.ini` qui decide, plus cette liste.
##
## Leur POSITION par defaut est notre choix, pas une donnee du client : le XML
## n'en porte aucune.
@export var daoc_ui_windows: PackedStringArray = PackedStringArray([
	"stats_index", "summary",
	"stats_attributes", "stats_spec_abil", "stats_combat",
	"stats_spells", "stats_group",
	"float_target", "minigroup", "miniinfo", "clock",
])

@export_group("Joueur - apparition et contrôles")
@export_subgroup("Apparition")
## Crée la capsule joueur locale, en unités DAoC brutes. Prototype client : elle ne
## remplace pas le futur déplacement autoritatif serveur.
@export var spawn_player_capsule: bool = true
## Zone où le joueur apparaît.
@export var player_zone: int = 0
## Utilise le `[start]` de SECTOR.DAT. DANGEREUX tant que la collision bound.csv est
## active : certains départs historiques tombent sur de la géométrie de transition.
@export var player_use_sector_start: bool = false
## Écarte le point de départ des murs de limite avant de poser le joueur.
@export var player_start_avoid_bound_collision: bool = true
## Dégagement minimal exigé autour du départ, en unités DAoC brutes.
@export var player_start_bound_clearance_raw: float = 600.0
## Position de départ X, en unités DAoC brutes. Négatif = centre neutre de la zone.
@export var player_start_x: float = -1.0
## Position de départ Y, en unités DAoC brutes. Négatif = centre neutre de la zone.
@export var player_start_y: float = -1.0
## Position de départ Z, en unités DAoC brutes. Négatif = posé sur le terrain.
@export var player_start_z: float = -1.0
## Orientation de départ, en degrés.
@export var player_start_heading_deg: float = 0.0
## Trace l'apparition du joueur dans la console.
@export var log_player_spawn: bool = true

@export_subgroup("Déplacement")
## Vitesse de course, en unités DAoC brutes par seconde.
@export var player_run_speed_raw: float = 1500.0
## Vitesse de rotation au clavier, en degrés par seconde.
@export var player_turn_rate_deg_per_sec: float = 180.0

@export_subgroup("Caméra")
## Rend la caméra joueur active au lancement.
@export var player_camera_current: bool = true
## Conserve la caméra libre à côté de la caméra joueur, pour inspecter la scène.
@export var keep_fly_camera: bool = true
## Lit les réglages de caméra dans le `default.ini` du client plutôt que des valeurs
## internes.
@export var player_use_client_camera_ini: bool = true
## Chemin du .ini de caméra utilisé.
@export var player_camera_ini_path: String = "res://data/default.ini"
## Ramène la caméra derrière le joueur après une rotation libre, comme le client.
@export var player_camera_snapback_enabled: bool = true
## Vitesse de ce recentrage, en unités par seconde.
@export var player_camera_snapback_speed_units_per_sec: float = 2048.0
## Trace les entrées de caméra dans la console.
@export var player_camera_debug_input: bool = false
## Deux profils demandés : les cases sont exclusives et restent accessibles à
## chaud. « Moderne » est le profil visuel livré ; « Défaut DAoC » restitue le
## cadrage historique sans toucher au moteur de déplacement.
@export var player_camera_default: bool = false
@export var player_camera_modern: bool = true
@export_range(25.0, 700.0, 5.0) var player_camera_distance_raw: float = 125.0
@export_range(-50.0, 25.0, 1.0) var player_camera_height_raw: float = 14.0
@export_range(100.0, 1700.0, 1.0) var player_camera_tilt_raw: float = 205.0
@export_range(35.0, 100.0, 1.0) var player_camera_fov_degrees: float = 60.0

@export_subgroup("Clavier et souris")
## Lit les affectations du `keyboard.dat` du client au lieu des touches par défaut.
@export var player_use_keyboard_dat_bindings: bool = true
## Jeu de touches du client à charger.
@export var player_keyboard_preset: String = "rpgdefault"
## Respecte le bit Shift brut des affectations du client.
@export var player_respect_keyboard_shift_raw: bool = false
## Le clic droit fait tourner le personnage au lieu de la seule caméra.
@export var player_right_mouse_turns_player: bool = false
## Le clic droit maintenu fait avancer (comportement souris hérité).
@export var player_mouse_right_moves_forward: bool = false
## Le clic gauche maintenu fait reculer (comportement souris hérité).
@export var player_mouse_left_moves_backward: bool = false
## Les deux boutons maintenus font avancer (course souris du client).
@export var player_mouse_both_buttons_move_forward: bool = false
## Coupe d'un bloc tous les déplacements souris hérités ci-dessus, quelles que
## soient leurs cases.
@export var player_force_disable_legacy_mouse_movement: bool = true
## Imprime les affectations clavier résolues au démarrage.
@export var player_debug_print_keyboard_bindings: bool = false

@export_group("Joueur - apparence et ancrage")
@export_subgroup("Modèle affiché")
## Affiche le visuel de joueur configuré au lieu de la capsule nue.
@export var player_visual_meshy_enabled: bool = true
## Applique ce visuel dès le lancement, sans commande.
@export var player_visual_meshy_apply_on_ready: bool = true
## OFF : `config/player_visual_meshy.json` est l'unique source de vérité.
## ON : les quatre valeurs ci-dessous remplacent explicitement ce fichier.
@export var player_visual_meshy_inspector_overrides_enabled: bool = false
## Échelle du modèle affiché. N'a d'effet qu'avec les surcharges activées.
@export_range(0.0001, 300.0, 0.0001, "or_greater") var player_visual_meshy_scale: float = 2.4119
## Rotation du modèle autour de la verticale, en degrés.
@export_range(-360.0, 360.0, 1.0) var player_visual_meshy_yaw_degrees: float = 90.0
## Décalage vertical du modèle par rapport à la capsule, en unités DAoC brutes.
@export_range(-128.0, 128.0, 0.01, "or_greater", "or_less") var player_visual_meshy_ground_offset: float = 0.0
## Animation : auto = pilotée par la vitesse du joueur ; walk/run = prévisualisation
## forcée ; idle = pose statique.
@export_enum("auto", "idle", "walk", "run") var player_visual_meshy_animation_state: String = "auto"
## Comportement à l'arrêt quand le modèle n'a pas de vrai idle : `walk_loop` permet
## de voir une animation même immobile.
@export_enum("freeze", "walk_loop") var player_visual_meshy_idle_mode: String = "walk_loop"
## Imprime l'état du visuel joueur au démarrage.
@export var player_visual_meshy_print_status_on_ready: bool = true

@export_subgroup("Ancrage au sol")
## Recale l'acteur sur le sol au lieu de le laisser à son Z source.
@export var player_grounding_enabled: bool = true
## Applique l'ancrage dès le lancement.
@export var player_grounding_apply_on_ready: bool = true
## Interroge les corps de collision (props, planchers, pontons).
@export var player_grounding_use_collision: bool = true
## Interroge la hauteur du terrain.
@export var player_grounding_use_terrain: bool = true
## Départ du rayon au-dessus de la position, en unités DAoC brutes.
@export var player_grounding_probe_height: float = 2048.0
## Portée du rayon sous la position, en unités DAoC brutes.
@export var player_grounding_probe_depth: float = 4096.0
## Décalage vertical final appliqué à l'acteur ancré, en unités DAoC brutes.
@export var player_grounding_actor_ground_offset: float = 0.0
## Correction maximale acceptée en une fois, en unités DAoC brutes. Au-delà,
## l'ancrage est refusé plutôt que de téléporter l'acteur.
@export var player_grounding_max_snap_delta: float = 512.0
## Force de la correction, de 0 (aucune) à 1 (immédiate).
@export var player_grounding_snap_strength: float = 1.0
## Pente maximale considérée comme praticable, en degrés.
@export var player_grounding_max_walkable_slope_degrees: float = 50.0
## Ignore la végétation comme support : on ne se pose pas sur une touffe d'herbe.
@export var player_grounding_ignore_vegetation: bool = true
## Dessine les rayons d'ancrage.
@export var player_grounding_debug_draw: bool = false
## Imprime l'état de l'ancrage au démarrage.
@export var player_grounding_print_status_on_ready: bool = true
## Dossier des rapports d'ancrage.
@export var player_grounding_report_dir: String = "res://reports/p1_18p_actor_grounding"

@export_subgroup("Alignement des pieds")
## Recale les orteils du modèle sur le support, après l'ancrage de la capsule.
@export var player_visual_auto_feet_align: bool = true
## Effectue cet alignement dès le lancement.
@export var player_visual_feet_align_on_ready: bool = true
## Décalage manuel ajouté à l'alignement, en unités DAoC brutes.
@export var player_visual_feet_offset: float = 0.0
## Poursuit l'alignement pendant le jeu, et pas seulement au lancement.
@export var player_visual_feet_align_runtime: bool = true
## Correction maximale par image, en unités DAoC brutes, pour éviter un saut visible.
@export var player_visual_feet_align_max_step: float = 128.0
## Trace l'alignement des pieds dans la console.
@export var player_visual_feet_debug: bool = false

@export_group("Réseau DOL et OpenDAoC")
@export_subgroup("Modules construits")
## Squelette client DOL local et testable : login → charlist → entrée en jeu, plus
## position, heading et changement de région en simulation.
@export var build_dol_client: bool = true
## Couche de transport TCP isolée. Présente, mais désactivée par défaut.
@export var build_dol_transport: bool = true
## Couche de découpage et d'assemblage des paquets.
@export var build_dol_packet_layer: bool = true
## Encodage fil de la version client 1.127.
@export var build_dol_wire_1127: bool = true
## Enchaînement de login 1.127.
@export var build_dol_login_flow_1127: bool = true
## Fixtures serveur 1.127 rejouées hors ligne.
@export var build_dol_server_fixtures_1127: bool = true
## Amorçage du personnage 1.127.
@export var build_dol_character_bootstrap_1127: bool = true
## HUD de sélection de personnage 1.127.
@export var build_dol_character_select_hud_1127: bool = true
## Résolveur d'assets des écrans de chargement d'avant-jeu.
@export var build_daoc_pregame_loading_asset_resolver: bool = true
## Affiche le parcours d'avant-jeu au lancement, au lieu d'entrer directement dans
## la zone.
@export var p1_20ui_show_pregame_flow_on_ready: bool = false

@export_subgroup("Transport local")
## Fait tourner le client DOL en simulation, sans aucune socket.
@export var dol_simulation_enabled: bool = true
## INTERDIT SANS AUTORISATION EXPLICITE : ouvre un vrai transport TCP. Ce projet
## sait atteindre l'état Playing sur un serveur réel ; une connexion lancée par
## inadvertance touche un service en production.
@export var dol_transport_enabled: bool = false
## Hôte par défaut du transport. Laisser vide.
@export var dol_default_host: String = ""
## Port par défaut du transport. Laisser à 0.
@export var dol_default_port: int = 0
## Délai d'attente du transport, en millisecondes.
@export var dol_transport_timeout_msec: int = 2500
## Compte utilisé par la simulation locale.
@export var dol_default_account: String = "debug"
## Trace les échanges réseau dans la console.
@export var dol_debug_network: bool = false

@export_subgroup("Sonde de login OpenDAoC (P1-20A)")
## INTERDIT SANS AUTORISATION EXPLICITE : la sonde parle à un vrai serveur
## OpenDAoC. Les captures existantes permettent de tout rejouer hors ligne.
@export var p1_20a_opendaoc_probe_enabled: bool = false
## Lance la sonde dès le démarrage. À laisser OFF.
@export var p1_20a_opendaoc_probe_run_on_ready: bool = false
## Rapport à blanc au démarrage : une sonde désactivée doit rester silencieuse
## pendant un lancement normal du viewer.
@export var p1_20a_opendaoc_dry_run_report_on_ready: bool = false
## Autorise le déclenchement manuel de la sonde par Ctrl+R.
@export var p1_20a_opendaoc_ctrl_r_enabled: bool = true
## Hôte visé par la sonde.
@export var p1_20a_opendaoc_host: String = ""
## Port de login visé.
@export var p1_20a_opendaoc_login_port: int = 10300
## Identifiant de compte utilisé par la sonde.
@export var p1_20a_opendaoc_username: String = ""
## Mot de passe utilisé par la sonde. Garder `p1_20a_opendaoc_redact_credentials`
## activé pour qu'il n'atterrisse pas dans un rapport.
@export var p1_20a_opendaoc_password: String = ""
## Version de client annoncée au serveur.
@export var p1_20a_opendaoc_client_version: String = ""
## Autorise l'envoi réel de paquets. Sans cela, la sonde n'observe que.
@export var p1_20a_opendaoc_send_packets: bool = false
## Garde-fou : autorise explicitement un hôte de production. À laisser OFF.
@export var p1_20a_opendaoc_allow_production_host: bool = false
## Arrête la sonde dès le CharacterOverview reçu, au lieu d'aller plus loin.
@export var p1_20a_opendaoc_stop_after_character_overview: bool = true
## Écrit un dump hexadécimal des paquets échangés.
@export var p1_20a_opendaoc_write_hex_dump: bool = true
## Délai d'attente de la sonde, en secondes.
@export var p1_20a_opendaoc_timeout_seconds: float = 8.0
## Dossier des rapports de la sonde.
@export var p1_20a_opendaoc_report_dir: String = "res://reports/p1_20a_opendaoc_tcp_login_probe/"
## Masque identifiants et mots de passe dans les rapports écrits.
@export var p1_20a_opendaoc_redact_credentials: bool = true

@export_group("Interface, HUD et ciblage")

@export_subgroup("Fenêtre et résolution")
## Résolution appliquée au démarrage. La liste reprend celle du client d'origine,
## qui livre un `defaultXXXX.ini` par largeur : 800, 1024, 1152, 1280, 1600, 1920
## et 2560. `Projet` laisse la valeur de `project.godot` (1600 x 900) et ne touche
## à rien ; `Personnalisée` utilise les deux champs ci-dessous.
@export_enum("Projet", "800 x 600", "1024 x 768", "1152 x 864", "1280 x 1024",
	"1600 x 900", "1920 x 1080", "2560 x 1440", "Personnalisée")
var window_resolution: int = 0
## Largeur en pixels quand `window_resolution` vaut `Personnalisée`.
@export_range(640, 7680, 1) var window_custom_width: int = 1600
## Hauteur en pixels quand `window_resolution` vaut `Personnalisée`.
@export_range(480, 4320, 1) var window_custom_height: int = 900
## Mode d'affichage. `Projet` ne touche à rien. « Plein écran » est le mode
## sans bordure de Godot, qui garde le bureau derrière ; « exclusif » prend le
## contrôle de l'écran et bascule plus lentement, mais évite une composition.
@export_enum("Projet", "Fenêtré", "Plein écran (sans bordure)", "Plein écran exclusif")
var window_display_mode: int = 0
## Recentre la fenêtre après changement de taille. Sans cela, une grande
## résolution appliquée à une fenêtre déjà placée en haut à gauche déborde de
## l'écran et sa barre de titre devient inatteignable.
@export var window_center_after_resize: bool = true
## Construit le HUD de logs à l'écran. Il reste disponible pour `/hud on` même
## masqué.
@export var build_dev_hud: bool = true
## Affiche le HUD de logs au démarrage. OFF depuis P1-20G-H : il masquait la vue.
@export var dev_hud_visible: bool = false
## Active le ciblage local, sans autorité serveur.
@export var build_local_targeting: bool = true
## Rayon de recherche de la cible la plus proche, en unités DAoC brutes.
@export var local_targeting_nearest_radius_raw: float = 2400.0
## P1-21H — sélection de la cible à la souris. Un clic gauche hors interface lance
## un rayon depuis la caméra active et cible l'entité sous le pointeur (PNJ, mob).
## Réutilise exactement le chemin de TAB : anneau, HUD et fenêtres d'origine
## suivent de la même façon. Sans autorité serveur combat, ce clic ne fait rien.
@export var mouse_targeting_enabled: bool = true
## Tolérance de visée, en pixels : élargit l'emprise de chaque entité à sa
## profondeur pour rattraper une cible fine quand le rayon passe juste à côté.
## 0 = pixel exact.
@export_range(0.0, 32.0, 1.0) var mouse_targeting_pixel_tolerance: float = 8.0
## Distance maximale de sélection à la souris, en unités DAoC brutes, mesurée au
## sol comme le HUD. 0 = aucune limite, le clic étant intentionnel.
@export var mouse_targeting_max_distance_raw: float = 0.0

@export_group("Diagnostics et audits")
@export_subgroup("Batterie de tests F12")
## Autorise la batterie de tests du monde lancée par F12 (terrain, eau, collision,
## props, zonejumps), qui écrit `daoc_f12_test_report.txt/.json`.
@export var f12_debug_test_enabled: bool = true
## Imprime les chemins des rapports produits.
@export var f12_debug_test_print_paths: bool = true
## Profil de la batterie F12 : `quick` par défaut.
@export var f12_debug_test_profile: String = "quick"
## Inclut les exports de scène lourds. Long : à réserver à une passe complète.
@export var f12_debug_test_run_heavy_scene_exports: bool = false

@export_subgroup("Audit matériaux et textures")
## Autorise l'audit de fidélité matériaux/textures zone et props.
@export var asset_material_audit_enabled: bool = true
## Auditer la scène runtime complète est une action de diagnostic, pas une étape de
## lancement : à laisser OFF.
@export var asset_material_audit_run_on_ready: bool = false
## Zone auditée.
@export_range(0, 999, 1) var asset_material_audit_zone: int = 0
## Inspecte aussi les fichiers de texture, et pas seulement les matériaux.
@export var asset_material_audit_scan_textures: bool = true
## Inspecte les matériaux réellement présents dans la scène vivante.
@export var asset_material_audit_inspect_runtime_materials: bool = true
## Plafond d'échantillons de texture examinés.
@export_range(16, 2000, 1) var asset_material_audit_max_texture_samples: int = 500
## Plafond de nœuds de la scène vivante examinés.
@export_range(32, 3000, 1) var asset_material_audit_max_runtime_material_nodes: int = 900
## Dossier des rapports d'audit.
@export var asset_material_audit_report_dir: String = "res://reports/p1_18n_asset_material_audit"
## Imprime l'état de l'audit au démarrage.
@export var asset_material_audit_print_status_on_ready: bool = true

@export_subgroup("Sonde d'import NIF")
## Autorise la sonde de conversion/import NIF.
@export var nif_import_probe_enabled: bool = true
## Lance la sonde au démarrage. À laisser OFF : c'est un diagnostic.
@export var nif_import_probe_run_on_ready: bool = false
## Zone sondée.
@export_range(0, 999, 1) var nif_import_probe_zone: int = 0
## Concentre la sonde sur le cas bridgehouse, historiquement problématique.
@export var nif_import_probe_focus_bridgehouse: bool = true
## Écrit le résultat en CSV.
@export var nif_import_probe_write_csv: bool = true
## Écrit le résultat en JSON.
@export var nif_import_probe_write_json: bool = true
## Plafond de fixtures sondées. 0 = aucune limite.
@export_range(0, 50000, 1) var nif_import_probe_max_fixtures: int = 0
## Ajoute un repère visuel dans la scène autour de la fixture ciblée.
@export var nif_import_probe_visual_debug_enabled: bool = false
## Identifiant de la fixture mise en évidence.
@export var nif_import_probe_visual_debug_target_fixture_id: int = 556
## Dessine l'AABB de la fixture ciblée.
@export var nif_import_probe_visual_debug_draw_aabb: bool = true
## Met la fixture ciblée en surbrillance.
@export var nif_import_probe_visual_debug_highlight: bool = true
## Ajoute une étiquette sur la fixture ciblée.
@export var nif_import_probe_visual_debug_label: bool = true

@export_subgroup("Parité des scènes générées")
## Compare une scène exportée hors ligne avec ce que le viewer construit au runtime.
@export var p1_19a_parity_enabled: bool = true
## Lance la comparaison au démarrage. À laisser OFF.
@export var p1_19a_parity_run_on_ready: bool = false
## Scène générée à comparer.
@export var p1_19a_generated_scene_path: String = ""
## Zone de cette scène générée.
@export var p1_19a_generated_scene_zone_id: int = 0
## Compare avec le viewer runtime plutôt qu'avec un rapport figé.
@export var p1_19a_compare_runtime_viewer: bool = true
## Compare aussi les matériaux.
@export var p1_19a_compare_materials: bool = true
## Compare aussi les collisions.
@export var p1_19a_compare_collisions: bool = true
## Restreint la comparaison aux fixtures critiques connues.
@export var p1_19a_focus_critical_fixtures: bool = true
## Plafond de fixtures comparées. 0 = aucune limite.
@export var p1_19a_max_fixture_compare: int = 0
## Dossier des rapports de parité.
@export var p1_19a_report_dir: String = "res://reports/p1_19a_generated_scene_parity"

@export_subgroup("Démarrage sur scène générée")
## Démarre directement sur la scène générée au lieu de construire la zone au
## runtime.
@export var p1_19a_generated_boot_enabled: bool = false
## Crée aussi le joueur dans ce mode.
@export var p1_19a_generated_boot_spawn_player: bool = true
## Attache aussi le visuel de joueur.
@export var p1_19a_generated_boot_attach_meshy: bool = true
## Applique aussi l'ancrage au sol.
@export var p1_19a_generated_boot_use_grounding: bool = true
## Trace ce démarrage dans la console.
@export var p1_19a_generated_boot_debug: bool = false

@export_group("Donjons générés et ZoneCreator")
## Raccourcis manuels temporaires des commandes ZoneCreator (P1-16A7D / P1-17C2-HF1
## / P1-17C3) : Ctrl+F1 affiche l'aperçu hors ligne, Ctrl+F2 le masque ;
## Ctrl+F3 sortie donjon isolée, Ctrl+F4 entrée donjon isolée + spawn ;
## Ctrl+F5 rapport donjon généré, Ctrl+F6 dry-run donjons, Ctrl+F7 export donjons,
## Ctrl+F8 manifeste ; Ctrl+F9 dry-run terrain, Ctrl+F10 export terrain,
## Ctrl+F11 attache les scènes terrain générées.
@export var zonecreator_manual_hotkeys_enabled: bool = true
## Zones de donjon visées par ces raccourcis.
@export var zonecreator_manual_dungeon_zones: PackedInt32Array = PackedInt32Array([19, 21])
## Donjon chargé par défaut par l'entrée runtime.
@export var generated_dungeon_runtime_default_zone: int = 19
## Décalage vertical du point d'apparition dans le donjon, en unités DAoC brutes.
@export var generated_dungeon_runtime_spawn_z_offset_raw: float = 8.0
## Masque l'extérieur pendant qu'on est dans le donjon.
@export var generated_dungeon_runtime_isolate_exterior: bool = true
## Compensation d'échelle des scènes de donjon générées (P1-17D HF2 : environ 10).
@export var generated_dungeon_runtime_scale_compensation: float = 10.0
## Exporte automatiquement un donjon manquant au lieu d'échouer. Long : OFF par
## défaut.
@export var generated_dungeon_runtime_auto_export_missing: bool = false
## Mémorise la position extérieure du joueur pour l'y ramener à la sortie.
@export var generated_dungeon_runtime_remember_exterior_player_state: bool = true
## Backend de destination utilisé à l'entrée : `auto`, `dol`, `opendaoc` ou
## `fallback`.
@export var generated_dungeon_runtime_destination_backend_preference: String = "auto"
@export_group("")

var _asset_index_registry_obj: RefCounted = null # P1-15D owns model/texture/path/json/csv/image indexes and caches

var _placement: Dictionary = {}   # zone -> world_origin [x,y]
var _zone_roots: Dictionary = {}    # zone -> DaocZoneRoot
var _base := Vector2.ZERO
var _hud_zones: String = ""
var _viewer_sun: DirectionalLight3D = null
var _viewer_environment: Environment = null
var _state_15e: DaocZoneViewerStateRegistry = DaocZoneViewerStateRegistryScript.new() # P1-15E owns grouped residual runtime/build/debug state
var _command_debug_surface_15f: RefCounted = null # P1-15F owns zonejump command/debug and guarded transition surface
var _local_viewer_bootstrap_15g: RefCounted = null # P1-15G owns local shell/bootstrap glue
var _npc_showcase: RefCounted = null
var _npc_showcase_report: Dictionary = {}
# ---------------------------------------------------------------------------
# R0 - socle de session
#
# Les sept membres ci-dessous ne sont plus STOCKES ici : ils vivent dans le
# noeud `DaocGameSession`, qui survit a une reconstruction de zone. Les ~120
# usages repartis dans ce fichier sont inchanges - ils traversent un accesseur
# au lieu de lire un champ. C'est tout l'interet : R0 deplace le proprietaire
# sans toucher a une seule ligne de logique, donc sa suite se verifie par
# simple parite avec l'existant.
#
# `use_game_session` decoche restaure exactement l'ancien stockage local, via
# les champs `_legacy_*`. Le drapeau est un choix de DEMARRAGE : le basculer en
# cours de partie changerait de stockage et perdrait les references.

var _session_node: DaocGameSession = null

var _legacy_gothwaite_population: RefCounted = null
var _legacy_local_server: DaocLocalServer = null
var _legacy_environment_controller: Node = null
var _legacy_water_fx: Node = null
var _legacy_player: Node3D = null
var _legacy_player_camera: Node = null
var _legacy_input_router: Node = null
var _legacy_zone_streamer: DaocZoneStreamer = null

## R4 - les services exposes aux etapes de zone, construits une seule fois.
var _zone_build_services: DaocZoneBuildServices = null
## Avertissements d'identifiants deja emis, pour ne les dire qu'une fois par champ.
var _p1_20a_credential_warned: Dictionary = {}


## Cree l'objet session sans l'attacher : un accesseur peut se declencher avant
## que le viewer soit dans l'arbre. Le rattachement se fait dans `_ready`.
func _ensure_game_session() -> DaocGameSession:
	if not use_game_session:
		return null
	if _session_node == null:
		_session_node = DaocGameSession.new()
		_session_node.name = "GameSession"
	return _session_node


## Résolutions proposées, dans l'ordre de `window_resolution`. L'entrée 0
## (`Projet`) n'a pas de taille : elle signifie « ne touche à rien ».
const WINDOW_RESOLUTION_PRESETS := [
	Vector2i.ZERO,
	Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1152, 864),
	Vector2i(1280, 1024), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


## La taille demandée par l'inspecteur, sans toucher à l'affichage.
##
## Séparée de `_apply_window_resolution` pour être VÉRIFIABLE hors ligne : elle
## ne lit aucun `DisplayServer` et ne dépend d'aucune fenêtre, donc une suite
## headless peut la contrôler. `Vector2i.ZERO` signifie « ne rien changer ».
func resolved_window_size() -> Vector2i:
	if window_resolution == WINDOW_RESOLUTION_PRESETS.size():
		return Vector2i(maxi(window_custom_width, 0), maxi(window_custom_height, 0))
	if window_resolution > 0 and window_resolution < WINDOW_RESOLUTION_PRESETS.size():
		return WINDOW_RESOLUTION_PRESETS[window_resolution]
	return Vector2i.ZERO


## Applique la résolution et le mode d'affichage choisis dans l'inspecteur.
##
## Appelée en TÊTE de `_ready()`, avant toute construction : l'interface DAoC
## lit la taille du viewport pour disposer ses fenêtres, donc redimensionner
## après coup les laisserait placées pour l'ancien écran.
##
## `Projet` sur les deux réglages ne touche à RIEN — la fenêtre reste celle de
## `project.godot`. C'est le défaut, pour qu'un lancement inchangé le reste.
func _apply_window_resolution() -> void:
	var window := get_window()
	if window == null:
		return

	if window_display_mode > 0:
		match window_display_mode:
			1: window.mode = Window.MODE_WINDOWED
			2: window.mode = Window.MODE_FULLSCREEN
			3: window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN

	var size := resolved_window_size()
	if size.x <= 0 or size.y <= 0:
		return

	# LE POINT QUI COMPTE, et qui manquait. `project.godot` déclare
	# `stretch/mode = canvas_items` avec un `content_scale_size` de 1600 x 900 :
	# Godot dessine dans ce cadre puis l'agrandit jusqu'à la fenêtre. Régler la
	# seule taille de fenêtre donne donc une image PLUS GRANDE, pas plus définie
	# — mesuré : fenêtre 2560 x 1440, viewport toujours 1600 x 900.
	# C'est `content_scale_size` qui porte la vraie résolution de rendu.
	window.content_scale_size = size

	# En plein écran la taille de la FENÊTRE appartient à l'écran ; seule la
	# résolution de rendu, réglée juste au-dessus, reste la nôtre. C'est d'ailleurs
	# le réglage utile là-bas : rendre en 1600 x 900 sur un écran 2560 x 1440
	# coûte deux fois moins cher.
	if window.mode != Window.MODE_WINDOWED:
		return

	# Une résolution plus grande que l'écran rendrait la barre de titre
	# inatteignable : on la borne à l'écran utilisable plutôt que de la refuser.
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x > 0 and usable.size.y > 0:
		size.x = mini(size.x, usable.size.x)
		size.y = mini(size.y, usable.size.y)

	window.size = size
	if window_center_after_resize:
		window.position = usable.position + (usable.size - size) / 2


## Attache la session sous le viewer. Appele en tete de `_ready`, avant toute
## construction, pour que les systemes se rangent directement au bon endroit.
func _mount_game_session_r0() -> void:
	var session: DaocGameSession = _ensure_game_session()
	if session != null and session.get_parent() == null:
		add_child(session)


## Etat R0 lisible par machine, pour la suite dediee et le rapport.
func game_session_report_r0() -> Dictionary:
	var session: DaocGameSession = _ensure_game_session()
	if session == null:
		return {"ok": true, "enabled": false, "owner": "ZoneViewer"}
	var report: Dictionary = session.describe()
	report["enabled"] = true
	report["owner"] = "DaocGameSession"
	report["mounted"] = session.get_parent() == self
	return report


# ---------------------------------------------------------------------------
# R1 - streamer de zones
#
# Le streamer est PERSISTANT : ce sont les zones qu'il tient qui meurent. Il est
# donc rattache a la session quand elle existe, exactement comme l'arbre cible
# du plan de reconstruction le decrit. Sans session, il retombe sous le viewer.
#
# `Node3D` a l'identite sous un parent a l'identite : les transformations
# globales des branches de zone sont inchangees. La suite R1 le verifie au lieu
# de le supposer.

func _ensure_zone_streamer() -> DaocZoneStreamer:
	if not use_zone_streamer:
		return null
	var session: DaocGameSession = _ensure_game_session()
	if session != null and session.zone_streamer != null:
		return session.zone_streamer

	var streamer := DaocZoneStreamer.new()
	streamer.name = "ZoneStreamer"
	# R4, derniere piece : l'horizon suit les zones residentes. Le branchement se
	# fait ICI, a la creation, et non a la construction de l'horizon - sinon un
	# chargement survenu AVANT le premier horizon passerait inapercu.
	streamer.resident_zones_changed.connect(_on_streamer_resident_zones_changed)
	if session != null:
		session.zone_streamer = streamer
		session.add_child(streamer)
	else:
		if _legacy_zone_streamer != null:
			return _legacy_zone_streamer
		_legacy_zone_streamer = streamer
		add_child(streamer)
	return streamer


## Detruit la branche d'une zone sans toucher a la session. Renvoie vrai si
## quelque chose a ete decharge.
func unload_zone_r1(znum: int) -> bool:
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return false
	return streamer.unload(znum)


## Le geste que R1 rend possible : la zone meurt et renait, la session ne bouge
## pas. Le remplissage reste `DaocZoneSceneAssembler`, inchange.
func reload_zone_r1(znum: int) -> Dictionary:
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return {"ok": false, "reason": "streamer desactive"}
	var unloaded: bool = streamer.unload(znum)
	_build_zone(znum)
	return {
		"ok": true,
		"zone": znum,
		"unloaded": unloaded,
		"streamer": streamer.describe(),
	}


## R5 — les emprises de zones, lues une fois.
##
## Même fichier que `_load_placement` et que l'horizon P1-20J : `zones_placement.json`.
## Une seule vérité sur l'endroit où vit chaque zone, sinon un passage de
## frontière déplacerait le joueur d'un décalage que personne ne verrait.
func _ensure_zone_transition_r5() -> DaocZoneTransition:
	if _zone_transition == null:
		_zone_transition = DaocZoneTransition.from_placement_file(
			_asset_data_15d("zones_placement.json"))
	return _zone_transition


## LE geste de R5 : le joueur sort de sa zone, on lui rend une voisine habitable.
##
## Appelé par `DaocPlayerMotor` à la place du rabotage, et par la suite qui joue
## le passage sans motor. Rend `{ok:false}` quand rien ne peut être fait — le
## rabotage reprend alors la main, et c'est le comportement voulu au bord de
## l'archipel.
##
## VERROUILLÉ, et c'est LE piège du jalon : le passage n'a lieu que si la voisine
## est REELLEMENT bâtie. `daoc_to_godot` lit l'origine de la zone dans
## `zone_runtime` ; une zone absente y répond `Vector3.ZERO`, donc franchir vers
## une zone non bâtie ne ferait pas entrer le joueur dans la voisine — il le
## téléporterait à l'origine de la session, très loin, sous un sol inexistant.
func cross_zone_border_r5(from_zone: int, daoc_x: float, daoc_y: float) -> Dictionary:
	if not zone_transition_enabled:
		return {"ok": false, "reason": "transitions de zone decochees"}
	var transition := _ensure_zone_transition_r5()
	var crossing: Dictionary = transition.resolve_border_crossing(from_zone, daoc_x, daoc_y)
	if not bool(crossing.get("ok", false)):
		return crossing

	var target := int(crossing["zone"])
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return {"ok": false, "reason": "streamer desactive, aucune voisine ne peut naitre"}

	var loaded_before: bool = streamer.has_zone(target)
	if not loaded_before:
		_build_zone(target)
	# Le contrôle qui protège du pire : bâtie ou non, la zone doit avoir une
	# origine, sinon on refuse de bouger le joueur.
	if not _state_15e.zone_runtime.has(target):
		return {"ok": false, "reason": "zone %d sans repere, passage refuse" % target,
			"zone": target}

	transition.note_entered(from_zone)
	transition.note_entered(target)
	player_zone = target

	var evicted: Array = []
	for zone_id in transition.plan_eviction(streamer.loaded_zones(), max_resident_zones, target):
		if streamer.unload(int(zone_id)):
			evicted.append(int(zone_id))
			_forget_zone_state_r5(int(zone_id))

	# P1-33 — le plan est PÉRIMÉ dès que la zone active change : la zone qu'on
	# vient de quitter devient lointaine, et c'est précisément celle qu'on
	# regarde en se retournant. La replanifier avant de rebâtir l'horizon évite
	# de le construire deux fois de suite.
	if zone_prefetch_enabled or distant_near_border_lod_enabled:
		var crossed_plan := plan_zone_lod_p1_33(target,
			float(crossing.get("x", 0.0)), float(crossing.get("y", 0.0)),
			0.0, streamer.loaded_zones())
		if bool(crossed_plan.get("ok", false)):
			_zone_lod_plan = crossed_plan
			_horizon_dirty = true

	# L'horizon suit : la voisine cesse d'y être dessinée, la zone quittée y
	# reprend sa place. Différé par le streamer, forcé ici pour que le rapport
	# rendu au motor décrive un monde déjà cohérent.
	refresh_distant_terrain_if_stale_r4()

	var report := crossing.duplicate(true)
	report["built"] = not loaded_before
	report["evicted"] = evicted
	report["resident"] = streamer.loaded_zones()
	_last_zone_transition_r5 = report
	return report


## Une zone déchargée ne doit plus répondre à personne.
##
## Les étapes R4 vident bien les index — mais seulement quand la zone est
## REBÂTIE. R1 pouvait s'en contenter : son seul geste était `unload` + rebuild.
## R5 décharge sans retour, d'où `DaocZoneUnload`.
func _forget_zone_state_r5(znum: int) -> Dictionary:
	return DaocZoneUnload.forget_zone(_state_15e, znum)


func zone_transition_report_r5() -> Dictionary:
	var transition := _ensure_zone_transition_r5()
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	var report: Dictionary = transition.describe(player_zone)
	report["enabled"] = zone_transition_enabled
	report["max_resident_zones"] = max_resident_zones
	report["resident"] = streamer.loaded_zones() if streamer != null else []
	report["last"] = _last_zone_transition_r5.duplicate(true)
	return report


func zone_streamer_report_r1() -> Dictionary:
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return {"ok": true, "enabled": false, "owner": "ZoneViewer"}
	var report: Dictionary = streamer.describe()
	report["enabled"] = true
	report["owner"] = "DaocZoneStreamer"
	report["under_session"] = streamer.get_parent() is DaocGameSession
	return report


var _gothwaite_population: RefCounted:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.entity_population if session != null else _legacy_gothwaite_population
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.entity_population = value
		else:
			_legacy_gothwaite_population = value

var _gothwaite_population_report: Dictionary = {}

var _local_server: DaocLocalServer:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.server_link if session != null else _legacy_local_server
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.server_link = value
		else:
			_legacy_local_server = value
var _combat_hud: DaocCombatHud = null
var _combat_client: DaocCombatClient = null
var _daoc_ui_manager: DaocUiWindowManager = null
var _daoc_ui_bus: DaocUiAdapterBus = null
var _daoc_ui_bridge: DaocUiServerBridge = null
var _daoc_ui_report: Dictionary = {}
var _local_server_report: Dictionary = {}
var _distant_terrain_report: Dictionary = {}
## Les zones residentes que l'horizon actuellement bati decrit, et le drapeau qui
## dit qu'elles ne sont plus les bonnes. Deux champs et non un : sans la liste, un
## rechargement de la MEME zone declencherait une reconstruction inutile de six
## reliefs voisins.
var _horizon_resident_zones: Array = []
var _horizon_dirty: bool = false
## P1-33 — la sélection de palier proche AVEC laquelle l'horizon a été bâti.
## Sans elle, un plan qui ne change que `near_zones` (la liste des résidentes
## restant la même, cas de TOUT ce qui précède le premier franchissement) était
## jugé « pas périmé » et la voisine restait floue jusqu'à la première traversée.
var _horizon_lod_selection: Dictionary = {}
## P1-33 — le dernier plan rendu par `DaocZoneLodPlanner`, et l'horloge qui
## borne sa fréquence. Le plan est CONSERVÉ parce que l'horizon ne doit être
## rebâti que sur un vrai changement de sélection, pas à chaque image.
var _zone_lod_plan: Dictionary = {}
var _zone_lod_plan_clock: float = 0.0
var _zone_prefetch_log: Array = []
## R5 — les emprises de zones et le dernier passage de frontiere.
var _zone_transition: DaocZoneTransition = null
var _last_zone_transition_r5: Dictionary = {}
var _environment_controller: Node:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.world_clock if session != null else _legacy_environment_controller
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.world_clock = value
		else:
			_legacy_environment_controller = value

var _sky3d_adapter: Node = null
var _weather_fx: Node3D = null

var _water_fx: Node:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.water_fx if session != null else _legacy_water_fx
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.water_fx = value
		else:
			_legacy_water_fx = value
var _environment_report: Dictionary = {}
var _zone_scene_assembler_obj: RefCounted = null # P1-15B orchestrates per-zone assembly order
var _legacy_visuals_obj: RefCounted = null # P1-15C-A owns old visual lights/cards implementation
var _player: Node3D:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.player if session != null else _legacy_player
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.player = value
		else:
			_legacy_player = value

var _player_camera: Node:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.player_camera if session != null else _legacy_player_camera
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.player_camera = value
		else:
			_legacy_player_camera = value

var _input_router: Node:
	get:
		var session: DaocGameSession = _ensure_game_session()
		return session.input_router if session != null else _legacy_input_router
	set(value):
		var session: DaocGameSession = _ensure_game_session()
		if session != null:
			session.input_router = value
		else:
			_legacy_input_router = value
var _command_router: Node = null
var _dol_client: Node = null
var _dol_transport: Node = null
var _dol_packet_layer: Node = null
var _dol_wire_1127: Node = null
var _dol_login_flow_1127: Node = null
var _dol_server_fixtures_1127: Node = null
var _dol_character_bootstrap_1127: Node = null
var _dol_character_select_hud_1127: Node = null
var _p1_20ui_pregame_layer: CanvasLayer = null
var _daoc_pregame_loading_asset_resolver: RefCounted = null
var _local_targeting: Node = null
var _dev_hud: CanvasLayer = null
var _fly_camera: Camera3D = null
var _debug_test_runner: RefCounted = null
var _generated_dungeon_runtime_bridge_17d: RefCounted = null


func _get(property: StringName) -> Variant:
	if _state_15e != null and _state_15e.has_method("has_compat_name") and bool(_state_15e.call("has_compat_name", str(property))):
		return _state_15e.call("compatibility_get", str(property))
	return null


func _set(property: StringName, value: Variant) -> bool:
	if _state_15e != null and _state_15e.has_method("compatibility_set"):
		return bool(_state_15e.call("compatibility_set", str(property), value))
	return false


func get_zoneviewer_state_15e_debug_snapshot() -> Dictionary:
	var state_snap: Dictionary = {}
	if _state_15e != null and _state_15e.has_method("debug_snapshot"):
		state_snap = _state_15e.call("debug_snapshot") as Dictionary
	var audit := get_zoneviewer_p1_15a_audit_snapshot() if has_method("get_zoneviewer_p1_15a_audit_snapshot") else {}
	var domains: Dictionary = audit.get("domains", {}) if audit is Dictionary else {}
	return {
		"scope": "P1-15E ZoneViewer state grouping / residual state reduction",
		"checkpoint": "C_STATE_GROUPING",
		"state_registry_present": _state_15e != null,
		"state_registry": state_snap,
		"audit": audit,
		"line_count": int(audit.get("line_count", 0)) if audit is Dictionary else 0,
		"function_count": int(audit.get("function_count", 0)) if audit is Dictionary else 0,
		"export_count": int(audit.get("export_count", 0)) if audit is Dictionary else 0,
		"var_count": int(audit.get("var_count", 0)) if audit is Dictionary else 0,
		"asset_index_residue": int(domains.get("asset_model_texture_index", 999)),
		"vegetation_legacy_residue": int(domains.get("vegetation_legacy", 999)),
		"legacy_lights_residue": int(domains.get("legacy_lights", 999)),
		"zonejump_residue": int(domains.get("zonejump_runtime_debug", 0)),
		"c_done": _state_15e != null,
		"compat_zone_runtime_size": _state_15e.zone_runtime.size(),
		"compat_prop_collision_size": _state_15e.prop_collision_runtime.size(),
		"recommended_next_step": "P1-15F ZoneViewer command/debug surface extraction",
	}


func _ensure_asset_index_registry_15d() -> RefCounted:
	if _asset_index_registry_obj == null:
		_asset_index_registry_obj = DaocAssetIndexRegistryScript.new()
	_asset_index_registry_obj.call("configure", {
		"daoc_client_root": daoc_client_root,
		"external_data_dir": external_data_dir,
		"models_dir": models_dir,
		"extra_models_dirs": extra_models_dirs,
		"use_nif_reader": use_nif_reader,
		"texture_dirs": texture_dirs,
		"extra_texture_dirs": extra_texture_dirs,
		"scan_full_texture_client_root": scan_full_texture_client_root,
		"link_textures": link_textures,
		"foliage_alpha_scissor": foliage_alpha_scissor,
		"prop_detail_layer_enabled": prop_detail_layer_enabled,
		"prop_dense_lod_enabled": prop_dense_lod_enabled,
		"prop_detail_gain": prop_detail_gain,
		"log_missing_models": log_missing_models,
		"export_missing_models_csv": export_missing_models_csv,
		"missing_models_csv_path": missing_models_csv_path,
		"world_scale": world_scale,
		# R10-HF2 — le vent dans les feuilles des props NIF.
		"foliage_wind_enabled": foliage_wind_enabled,
		"foliage_canopy_strength_raw": foliage_canopy_strength_raw,
		"foliage_leaf_flutter_strength_raw": foliage_leaf_flutter_strength_raw,
		"foliage_wind_height_reference_raw": foliage_wind_height_reference_raw,
	})
	return _asset_index_registry_obj


func get_asset_index_registry_15d() -> RefCounted:
	return _ensure_asset_index_registry_15d()


func get_asset_index_registry_15d_debug_snapshot() -> Dictionary:
	var reg := _ensure_asset_index_registry_15d()
	if reg == null:
		return {"scope": "P1-15D AssetIndexRegistry foundation", "present": false}
	var snap: Dictionary = reg.call("status_snapshot") as Dictionary
	snap["present"] = true
	return snap


func _asset_data_15d(file_name: String) -> String:
	return str(_ensure_asset_index_registry_15d().call("data_path", file_name))


func _asset_zone_file_15d(znum: int, file_name: String) -> String:
	return str(_ensure_asset_index_registry_15d().call("find_zone_dat_asset", znum, file_name))


func _asset_read_15d(asset_file: String) -> Variant:
	return _ensure_asset_index_registry_15d().call("load_json_file", asset_file)


func _asset_tex_15d(asset_file: String) -> Texture2D:
	return _ensure_asset_index_registry_15d().call("load_texture_file", asset_file) as Texture2D


## R10-HF1 — repare la lettre de lecteur du client, comme la scene de jeu.
##
## Le projet est ouvert depuis plusieurs machines et le disque n'y porte pas la
## meme lettre. Un chemin CONFIGURE QUI EXISTE n'est jamais touche : corriger a
## la main reste prioritaire. Voir `DaocClientRoot` pour l'ordre des candidats.
func resolve_client_root_r10() -> Dictionary:
	var resolution: Dictionary = DaocClientRootScript.resolve(daoc_client_root)
	if bool(resolution.get("ok", false)):
		daoc_client_root = str(resolution["root"])
		if bool(resolution.get("healed", false)):
			print("DAOC_CLIENT_ROOT repare : %s (source=%s)" % [
				daoc_client_root, str(resolution.get("source", "?"))])
	else:
		push_warning("DAOC_CLIENT_ROOT introuvable, essais : %s"
			% str(resolution.get("tried", [])))
	return resolution


func _ready() -> void:
	_apply_outward_reference_presets()
	_apply_visual_roadmap_profile()
	# R10-HF1 : la lettre de lecteur AVANT tout le reste. Un client introuvable
	# ne leve pas d'erreur, il rend des listes vides et des zones sans texture.
	resolve_client_root_r10()
	# La resolution s'applique EN PREMIER, avant toute construction. L'interface
	# DAoC lit la taille du viewport pour placer ses fenetres : la redimensionner
	# apres coup les laisserait disposees pour l'ancien ecran - c'est le defaut
	# deja paye en P1-21E, ou une capture montrait 1280x720 pour une disposition
	# calculee sur 1600x900.
	_apply_window_resolution()
	# R0 : la session existe AVANT toute construction, pour que les systemes
	# persistants s'y rangent directement au lieu d'y etre deplaces apres coup.
	_mount_game_session_r0()
	set_process_input(true)
	if p1_20a_opendaoc_dry_run_report_on_ready:
		_write_opendaoc_tcp_login_probe_dry_run_early_p1_20a()
	_ensure_local_viewer_bootstrap_15g().call("build_ready_sequence", self)
	_build_daoc_water_fx()
	if npc_showcase_enabled:
		_build_npc_showcase()
	if gothwaite_population_enabled:
		_build_gothwaite_population()
		if local_server_enabled:
			_build_local_server_combat_p1_21a()
	if distant_terrain_enabled:
		_build_distant_terrain()
	if player_visual_meshy_apply_on_ready:
		call_deferred("_apply_player_visual_meshy_from_inspector_p1_18m")
	if asset_material_audit_run_on_ready:
		call_deferred("_run_asset_material_audit_from_inspector_p1_18n")
	if nif_import_probe_run_on_ready:
		call_deferred("_run_nif_import_probe_from_inspector_p1_18n_hf6")
	if nif_import_probe_visual_debug_enabled:
		call_deferred("_apply_nif_import_probe_visual_debug_p1_18n_hf6")
	if p1_19a_parity_run_on_ready:
		call_deferred("_run_generated_scene_parity_from_inspector_p1_19a")
	if p1_20a_opendaoc_probe_run_on_ready:
		call_deferred("_run_opendaoc_tcp_login_probe_from_inspector_p1_20a")
	if p1_20ui_show_pregame_flow_on_ready:
		call_deferred("show_pregame_selection_ui_p1_20ui", true)


func _apply_visual_roadmap_profile() -> Dictionary:
	if not visual_roadmap_enabled:
		return {"enabled": false, "applied": {}}
	var applied: Dictionary = DaocVisualRoadmapProfileScript.apply_to(self, visual_roadmap_quality)
	return {"enabled": true, "quality": visual_roadmap_quality, "applied": applied}


func _build_npc_showcase() -> void:
	_npc_showcase = DaocNpcShowcaseScript.new()
	_npc_showcase_report = _npc_showcase.call("build", self, npc_showcase_manifest_path, {
		"zone": npc_showcase_zone,
		"origin_x": npc_showcase_origin_x,
		"origin_y": npc_showcase_origin_y,
		"spacing_raw": npc_showcase_spacing_raw,
		"columns": npc_showcase_columns,
		"source_units_per_meter": npc_showcase_source_units_per_meter,
		"labels_visible": npc_showcase_labels_visible,
	}) as Dictionary


## P1-20K — environment authority and replaceable rendering backend.
## Called by DaocLocalViewerBootstrap in place of its former static sun/sky.
func _build_daoc_environment() -> void:
	if _environment_controller != null:
		return
	var environment_zone := player_zone
	if environment_zone < 0 and not zones.is_empty():
		environment_zone = int(zones[0])
	var profile: RefCounted = DaocZoneEnvironmentProfileScript.new().load_from_client(environment_zone, daoc_client_root)

	_sky3d_adapter = DaocSky3DAdapterScript.new()
	_sky3d_adapter.name = "DaocSky3DAdapter"
	add_child(_sky3d_adapter)
	_sky3d_adapter.call("setup")
	_sky3d_adapter.call("set_horizon_fog_density_addition", distant_horizon_fog_density_addition)
	_sky3d_adapter.call("set_quality_options", daoc_sky_quality_options())

	_weather_fx = DaocWeatherFxScript.new()
	_weather_fx.name = "DaocWeatherFX"
	add_child(_weather_fx)
	_weather_fx.call("setup", null)

	_environment_controller = DaocEnvironmentControllerScript.new()
	_environment_controller.name = "DaocEnvironmentController"
	_environment_controller.connect("environment_state_changed", Callable(self, "_on_daoc_environment_state_changed"))
	add_child(_environment_controller)
	_environment_controller.call("configure", profile, {
		"server_time_seconds": roundi(environment_offline_time_hours * 3600.0),
		"offline_test_mode": true,
		"offline_cycle_enabled": environment_offline_cycle_enabled,
		"offline_minutes_per_day": environment_offline_minutes_per_day,
		"transition_seconds": environment_weather_transition_seconds,
	})
	_environment_controller.call("set_local_weather_sample_x", gothwaite_population_world_origin_x + player_start_x)
	match environment_offline_weather.to_upper():
		"RAIN":
			_environment_controller.call("set_offline_weather", DaocWeatherFrontStateScript.PrecipitationHint.RAIN, environment_offline_weather_intensity, environment_offline_fog_diffusion)
		"SNOW":
			_environment_controller.call("set_offline_weather", DaocWeatherFrontStateScript.PrecipitationHint.SNOW, environment_offline_weather_intensity, environment_offline_fog_diffusion)
		_:
			_environment_controller.call("set_weather_front_raw", {
				"x": 0.0, "width": 0.0, "speed": 0.0,
				"fogdiffusion": 0.0, "intensity": 0.0,
			}, DaocWeatherFrontStateScript.PrecipitationHint.UNKNOWN)
	_on_daoc_environment_state_changed(_environment_controller.call("emit_current_state", true) as Dictionary)
	_viewer_sun = _sky3d_adapter.call("sun_light") as DirectionalLight3D
	_viewer_environment = _sky3d_adapter.call("environment_resource") as Environment
	if environment_log_state:
		print("DAOC_ENVIRONMENT=%s" % JSON.stringify(get_daoc_environment_debug_snapshot()))


## Les cases du sous-groupe « Qualité graphique / Ciel et atmosphère », rendues en
## données. C'est le SEUL endroit qui traduit les exports en options de rendu :
## l'adapter décide comment il les applique, et rien ici ne touche l'`Environment`.
## Une future fenêtre d'options du client lira ce même dictionnaire.
func daoc_sky_quality_options() -> Dictionary:
	return {
		"glow_enabled": sky_glow_enabled,
		"glow_intensity": sky_glow_intensity,
		"glow_hdr_threshold": sky_glow_hdr_threshold,
		"ambient_from_sky_enabled": sky_ambient_from_sky_enabled,
		"ambient_sky_contribution": sky_ambient_sky_contribution,
		"realtime_radiance_enabled": sky_realtime_radiance_enabled,
		"aerial_perspective_enabled": sky_aerial_perspective_enabled,
		"aerial_perspective_amount": sky_aerial_perspective_amount,
		"volumetric_fog_enabled": sky_volumetric_fog_enabled,
		"volumetric_fog_density": sky_volumetric_fog_density,
		# Seul réglage du groupe exprimé en unités DAoC brutes, d'où la conversion.
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
		"ssao_enabled": ground_contact_ssao_enabled,
		"ssao_radius": ground_contact_ssao_radius,
		"ssao_intensity": ground_contact_ssao_intensity,
		"ssao_power": ground_contact_ssao_power,
	}


## Applique les valeurs retenues par le banc de comparaison. Les cases ne
## cachent aucun réglage : elles ne font que poser une base cohérente, puis tous
## les curseurs détaillés restent disponibles dans l'inspecteur.
func _apply_outward_reference_presets() -> void:
	if outward_environment_default:
		sky_glow_enabled = true
		sky_glow_intensity = 0.50
		sky_glow_hdr_threshold = 1.65
		sky_ambient_from_sky_enabled = true
		sky_ambient_sky_contribution = 0.62
		sky_aerial_perspective_enabled = true
		sky_aerial_perspective_amount = 0.30
		sky_volumetric_fog_enabled = false
		sky_volumetric_fog_density = 0.000035
		sky_volumetric_fog_length_raw = 7000.0
		sky_sun_rays_energy = 0.85
		environment_offline_weather = "CLEAR"
		environment_offline_weather_intensity = 0.0
	if outward_vegetation_default:
		vegetation_render_mode = 1
		grass_remaster_spacing_raw = 85.0
		grass_remaster_density = 0.90
		grass_remaster_coverage_threshold = 0.18
		grass_remaster_card_width_raw = 52.0
		grass_remaster_card_height_raw = 48.0
		grass_remaster_native_tree_radius_raw = 900.0
		grass_remaster_native_plant_radius_raw = 550.0
		grass_remaster_autumn_groundcover_enabled = false
	if outward_grounding_default:
		ground_contact_ssao_enabled = true
		ground_contact_ssao_radius = 1.60
		ground_contact_ssao_intensity = 2.00
		ground_contact_ssao_power = 1.35
	_apply_selected_camera_profile()


func _apply_selected_camera_profile() -> void:
	if player_camera_default:
		player_camera_modern = false
		player_use_client_camera_ini = true
		player_camera_distance_raw = 240.0
		player_camera_height_raw = 10.0
		player_camera_tilt_raw = 174.0
		player_camera_fov_degrees = 75.0
	elif player_camera_modern:
		player_camera_default = false
		player_use_client_camera_ini = false
		player_camera_distance_raw = 125.0
		player_camera_height_raw = 14.0
		player_camera_tilt_raw = 205.0
		player_camera_fov_degrees = 60.0
	var rig := _player_camera as Node
	if rig != null:
		rig.set("use_client_camera_ini", player_use_client_camera_ini)
		rig.set("distance_raw", player_camera_distance_raw)
		rig.set("height_raw", player_camera_height_raw)
		rig.set("tilt_raw", player_camera_tilt_raw)
		rig.set("camera_fov_degrees", player_camera_fov_degrees)
		var camera := rig.call("get_camera3d") as Camera3D
		if camera != null:
			camera.fov = player_camera_fov_degrees


## Rejoue les options graphiques du ciel sur l'adapter vivant. Contrairement au
## filtrage anisotrope du terrain, ces effets ne sont pas cuits dans un maillage :
## ils se rebasculent en pleine partie, ce qui est exactement ce qu'attend un menu
## d'options. Sans effet tant que l'environnement DAoC n'est pas construit.
func apply_sky_quality_options() -> void:
	if _sky3d_adapter == null:
		return
	_sky3d_adapter.call("set_quality_options", daoc_sky_quality_options())


func _on_daoc_environment_state_changed(state: Dictionary) -> void:
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


## Future DOL packet handlers call these two methods; they never address Sky3D.
func set_daoc_server_time_seconds(seconds: int) -> void:
	if _environment_controller != null:
		_environment_controller.call("set_server_time_seconds", seconds)


func set_daoc_weather_front(raw: Dictionary, precipitation_hint: int = 0) -> void:
	if _environment_controller != null:
		_environment_controller.call("set_weather_front_raw", raw, precipitation_hint)


func get_daoc_environment_debug_snapshot() -> Dictionary:
	var snapshot := _environment_report.duplicate(true)
	if _environment_controller != null:
		snapshot["state"] = _environment_controller.call("current_state")
	if _sky3d_adapter != null:
		snapshot["sky_backend"] = _sky3d_adapter.call("debug_snapshot")
	if _weather_fx != null:
		snapshot["weather_fx"] = _weather_fx.call("debug_snapshot")
	return snapshot


func _build_daoc_water_fx() -> void:
	if not water_fx_enabled or _water_fx != null or _player == null or _player_camera == null:
		return
	var camera := _player_camera.call("get_camera3d") as Camera3D
	if camera == null:
		return
	_water_fx = DaocWaterFxScript.new()
	_water_fx.name = "DaocWaterFX"
	add_child(_water_fx)
	_water_fx.call("setup", self, _player, camera, daoc_client_root, {
		"enabled": water_fx_enabled,
		"underwater_enabled": water_underwater_enabled,
		"wake_enabled": water_player_wake_enabled,
		"caustic_fps": water_caustic_fps,
		"water_vertical_offset_raw": water_vertical_offset,
		"wake_size_raw": water_player_wake_size_raw,
		"wake_speed_threshold_raw": water_player_wake_speed_threshold_raw,
	})


func get_daoc_water_fx_debug_snapshot() -> Dictionary:
	return _water_fx.call("debug_snapshot") as Dictionary if _water_fx != null else {"enabled": false, "present": false}


func get_npc_showcase_debug_snapshot() -> Dictionary:
	return _npc_showcase_report.duplicate(true)


## Horizon : le relief grossier des zones voisines de la region courante.
## Se construit apres les zones actives, dont il emprunte le repere.
##
## R4, derniere piece : les zones actives ne sont plus la liste `zones` de
## l'inspecteur mais celles que le `DaocZoneStreamer` tient REELLEMENT, et la
## branche produite lui appartient. Les deux vont ensemble - un horizon accroche
## au viewer survivrait au dechargement des zones qu'il complete.
func _build_distant_terrain() -> void:
	var streamer: DaocZoneStreamer = _distant_terrain_streamer()
	var active: Array = []
	if streamer != null:
		active = streamer.loaded_zones()
	# Repli : avant la premiere zone batie, le streamer ne tient rien. La liste
	# de l'inspecteur reste alors la seule source, exactement comme avant R4.
	if active.is_empty():
		for zone_number in zones:
			active.append(int(zone_number))
	if active.is_empty():
		return
	_horizon_dirty = false
	_horizon_resident_zones = active.duplicate()
	_horizon_lod_selection = {
		"near_zones": (_zone_lod_plan.get("near_zones", []) as Array).duplicate(),
		"near_edges": (_zone_lod_plan.get("near_edges", {}) as Dictionary).duplicate(true),
	} if distant_near_border_lod_enabled else {}
	var environment_state := _environment_report.get("state", {}) as Dictionary
	var environment_profile := environment_state.get("zone_profile", {}) as Dictionary
	var border_fog_color := Color.from_string(
		str(environment_profile.get("fog_color", "558ca6")), Color8(85, 140, 166))
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
		"parent": streamer.horizon_branch() if streamer != null else self,
		# P1-33 — le palier proche. Sans plan courant, les listes sont vides et
		# l'horizon est exactement celui d'avant le jalon.
		"near_zones": (_zone_lod_plan.get("near_zones", []) as Array) if distant_near_border_lod_enabled else [],
		"near_edges": (_zone_lod_plan.get("near_edges", {}) as Dictionary) if distant_near_border_lod_enabled else {},
		"near_lod_atlas_size": distant_near_lod_atlas_size,
		"near_step": distant_near_lod_step,
		"near_band_raw": distant_near_lod_band_raw,
	})
	_distant_terrain_report["owner"] = "DaocZoneStreamer" if streamer != null else "ZoneViewer"
	_distant_terrain_report["resident_zones"] = active.duplicate()
	print("DISTANT_TERRAIN={\"ok\":%s,\"region\":%d,\"zones\":%d,\"vertices\":%d,\"lod_atlases\":%d,\"lod_kib\":%d,\"cliffs\":%d,\"border_fog\":%d,\"horizon\":%d}" % [
		str(bool(_distant_terrain_report.get("ok", false))).to_lower(),
		int(_distant_terrain_report.get("region", -1)),
		(_distant_terrain_report.get("built_zones", []) as Array).size(),
		int(_distant_terrain_report.get("vertex_count", 0)),
		int(_distant_terrain_report.get("lod_atlas_zones", 0)),
		int(_distant_terrain_report.get("lod_atlas_estimated_bytes", 0)) / 1024,
		int(_distant_terrain_report.get("cliff_segments", 0)),
		int(_distant_terrain_report.get("border_fog_segments", 0)),
		int(_distant_terrain_report.get("horizon_segments", 0)),
	])


## P1-33 — replanifie le préchargement et le palier de LOD, à cadence bornée.
##
## Appelé à chaque image, il ne TRAVAILLE qu'à `zone_lod_plan_interval_seconds`.
## Et même alors, il ne rebâtit l'horizon que si la sélection a réellement changé
## : reconstruire le relief lointain parce que la vitesse a bougé de trois unités
## coûterait bien plus cher que la couture qu'on veut corriger.
func _tick_zone_lod_plan_p1_33(delta: float) -> void:
	if not zone_transition_enabled or not distant_terrain_enabled:
		return
	_zone_lod_plan_clock += maxf(delta, 0.0)
	if _zone_lod_plan_clock < zone_lod_plan_interval_seconds:
		return
	_zone_lod_plan_clock = 0.0
	refresh_zone_lod_plan_p1_33()


## Le plan courant, recalculé. Séparé du tic pour qu'une suite puisse le jouer
## sans horloge — et pour que le passage de frontière puisse le forcer.
func refresh_zone_lod_plan_p1_33() -> Dictionary:
	var motor := _player as DaocPlayerMotor
	if motor == null:
		return _zone_lod_plan
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return _zone_lod_plan
	var plan := plan_zone_lod_p1_33(motor.daoc_zone, motor.daoc_x, motor.daoc_y,
		motor.last_speed_raw, streamer.loaded_zones())
	if not bool(plan.get("ok", false)):
		return _zone_lod_plan

	# 1. le préchargement. Il passe par le MÊME `_build_zone` que R5 : le seul
	#    changement est le MOMENT, jamais le chemin de construction.
	if zone_prefetch_enabled:
		for value in (plan.get("prefetch", []) as Array):
			var zone_id := int(value)
			if streamer.has_zone(zone_id):
				continue
			# Le budget de résidence reste maître. Précharger au-delà ferait
			# évincer une zone dans la foulée : on aurait payé la construction
			# pour rien, et deux fois.
			if streamer.loaded_zones().size() >= maxi(1, max_resident_zones):
				break
			var started := Time.get_ticks_msec()
			_build_zone(zone_id)
			var elapsed := Time.get_ticks_msec() - started
			_zone_prefetch_log.append({
				"zone": zone_id,
				"milliseconds": elapsed,
				"speed_raw": float(plan.get("speed_raw", 0.0)),
				"radius_raw": float(plan.get("prefetch_radius_raw", 0.0)),
			})
			print("ZONE_PREFETCH={\"zone\":%d,\"ms\":%d,\"speed_raw\":%.1f,\"radius_raw\":%.1f}" % [
				zone_id, elapsed, float(plan.get("speed_raw", 0.0)),
				float(plan.get("prefetch_radius_raw", 0.0))])

	# 2. le palier de LOD. Rien à faire tant que la sélection est la même.
	if not DaocZoneLodPlanner.same_lod_selection(_zone_lod_plan, plan):
		_zone_lod_plan = plan
		_horizon_dirty = true
		refresh_distant_terrain_if_stale_r4()
	else:
		_zone_lod_plan = plan
	return _zone_lod_plan


## Le plan, sans rien construire ni dessiner. C'est ce que la suite headless
## interroge : la décision est séparée de son exécution, comme partout ailleurs
## dans ce projet.
func plan_zone_lod_p1_33(active: int, daoc_x: float, daoc_y: float,
		speed_raw: float, resident: Array) -> Dictionary:
	var transition := _ensure_zone_transition_r5()
	return DaocZoneLodPlanner.plan(transition, active, daoc_x, daoc_y, speed_raw,
		resident, {
			"prefetch_base_raw": zone_prefetch_base_raw,
			"prefetch_seconds": zone_prefetch_seconds,
			"max_prefetch_zones": zone_prefetch_max_zones if zone_prefetch_enabled else 0,
			"near_lod_base_raw": distant_near_lod_base_raw,
			"near_lod_seconds": distant_near_lod_seconds,
			"max_near_zones": distant_near_lod_max_zones if distant_near_border_lod_enabled else 0,
		})


func zone_lod_plan_report_p1_33() -> Dictionary:
	var report := _zone_lod_plan.duplicate(true)
	report["prefetch_enabled"] = zone_prefetch_enabled
	report["near_border_lod_enabled"] = distant_near_border_lod_enabled
	report["near_lod_atlas_size"] = distant_near_lod_atlas_size
	report["near_lod_step"] = distant_near_lod_step
	report["plan_interval_seconds"] = zone_lod_plan_interval_seconds
	report["prefetch_log"] = _zone_prefetch_log.duplicate(true)
	return report


## Le streamer, quand l'horizon doit le suivre. `null` rend l'ancien chemin :
## une branche d'horizon accrochee au viewer, batie une fois.
func _distant_terrain_streamer() -> DaocZoneStreamer:
	if not horizon_follows_streamer:
		return null
	return _ensure_zone_streamer()


## Le jeu des zones residentes a change : l'horizon est PERIME.
##
## On ne rebatit pas ici. Une construction de zone acquiert sa branche au milieu
## de l'assemblage, donc reconstruire sur-le-champ relirait les cartes de
## hauteurs des six voisines a chaque etape. Le drapeau est leve, la
## reconstruction est differee a la fin de la trame - une seule, quel que soit le
## nombre de zones qui ont bouge.
func _on_streamer_resident_zones_changed(_resident: Array) -> void:
	if not distant_terrain_enabled or not horizon_follows_streamer:
		return
	if _horizon_dirty:
		return
	_horizon_dirty = true
	call_deferred("refresh_distant_terrain_if_stale_r4")


## Rebatit l'horizon si, et seulement si, les zones residentes ne sont plus
## celles qu'il decrit. Idempotent : appele deux fois de suite, il ne travaille
## qu'une fois.
func refresh_distant_terrain_if_stale_r4() -> bool:
	if not _horizon_dirty:
		return false
	_horizon_dirty = false
	if not distant_terrain_enabled or not horizon_follows_streamer:
		return false
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer == null:
		return false
	var resident: Array = streamer.loaded_zones()
	if resident.is_empty():
		return false
	if not DaocZoneLodPlanner.horizon_is_stale(resident, _horizon_resident_zones,
			_zone_lod_plan, _horizon_lod_selection, distant_near_border_lod_enabled):
		return false
	_build_distant_terrain()
	return true


func get_distant_terrain_debug_snapshot() -> Dictionary:
	return _distant_terrain_report.duplicate(true)


## R2 — bâtit le monde AU FIL DES PAQUETS. Le peuplement s'ouvre vide, puis
## `DaocEntityStreamRuntime` lui envoie les apparitions et les déplacements dans
## l'ordre de la capture.
##
## La porte est la même qu'en bloc : `spawn_one`, dont `build` n'est que la
## boucle. Les deux chemins ne peuvent donc pas diverger sur le choix de scène,
## l'échelle, l'orientation ou l'ancrage.
func build_living_stream_r2(events_per_frame: int = -1) -> Dictionary:
	var stream: Dictionary = DaocWorldEntityStream.from_capture()
	if not bool(stream.get("ok", false)):
		return {"ok": false, "error": str(stream.get("error", "flux illisible"))}

	_gothwaite_population = DaocGothwaitePopulationScript.new()
	var opened: Dictionary = _gothwaite_population.call("begin_stream", self,
		gothwaite_population_manifest_path, _gothwaite_population_overrides()) as Dictionary
	if not bool(opened.get("ok", false)):
		return {"ok": false, "error": str(opened.get("error", "ouverture du flux refusee"))}

	var session: DaocGameSession = _ensure_game_session()
	var runtime := DaocEntityStreamRuntime.new()
	runtime.name = "EntityStream"
	if session != null:
		if session.entity_stream != null and is_instance_valid(session.entity_stream):
			session.entity_stream.queue_free()
		session.entity_stream = runtime
		session.add_child(runtime)
	else:
		add_child(runtime)

	runtime.setup(self, _gothwaite_population, stream.get("events", []) as Array)
	runtime.events_per_frame = living_stream_events_per_frame if events_per_frame < 0 else events_per_frame
	if runtime.events_per_frame <= 0:
		runtime.apply_all()
	elif gothwaite_population_grounding_enabled:
		# Avec un débit étalé, le monde n'est pas complet à la trame suivante :
		# une passe d'ancrage lancée en `call_deferred` travaillerait sur un
		# monde à moitié peuplé et laisserait le reste sans reprise. Elle attend
		# donc la fin du flux.
		runtime.stream_finished.connect(
			func(_report: Dictionary) -> void: _refine_gothwaite_population_grounding(),
			CONNECT_ONE_SHOT)

	# Le rapport de peuplement reste celui de l'ouverture : en flux, les compteurs
	# vivants sont ceux du runtime, pas ceux d'une passe en bloc qui n'a pas eu lieu.
	_gothwaite_population_report = opened
	return {
		"ok": true,
		"mode": "STREAM",
		"event_count": int(stream.get("event_count", 0)),
		"spawn_count": int(stream.get("spawn_count", 0)),
		"move_count": int(stream.get("move_count", 0)),
		"despawn_count": int(stream.get("despawn_count", 0)),
		"despawn_supported_by_capture": bool(stream.get("despawn_supported_by_capture", false)),
		"events_per_frame": runtime.events_per_frame,
		"runtime": runtime.report(),
	}


## Les réglages du peuplement, partagés par le chemin en bloc et par le flux :
## une entité doit être placée pareil quelle que soit la porte d'entrée.
func _gothwaite_population_overrides() -> Dictionary:
	return {
		"zone": gothwaite_population_zone,
		"region": gothwaite_population_region,
		"world_origin_x": gothwaite_population_world_origin_x,
		"world_origin_y": gothwaite_population_world_origin_y,
		"source_units_per_meter": gothwaite_population_source_units_per_meter,
		"culling_distance_m": gothwaite_population_culling_distance_m,
		"show_ready_labels": gothwaite_population_ready_labels_visible,
		"show_fallback_labels": gothwaite_population_fallback_labels_visible,
		"prop_manifest_path": gothwaite_population_prop_manifest_path,
		"grounding_enabled": gothwaite_population_grounding_enabled,
	}


func _build_gothwaite_population() -> void:
	if use_living_entity_stream:
		var streamed: Dictionary = build_living_stream_r2()
		# Débit nul : le monde est complet immédiatement, l'ancrage peut suivre
		# comme dans le chemin en bloc. Débit étalé : `build_living_stream_r2` a
		# branché l'ancrage sur la fin du flux, ne pas le lancer deux fois.
		if gothwaite_population_grounding_enabled and int(streamed.get("events_per_frame", 0)) <= 0:
			call_deferred("_refine_gothwaite_population_grounding")
		return
	_gothwaite_population = DaocGothwaitePopulationScript.new()
	_gothwaite_population_report = _gothwaite_population.call("build", self, gothwaite_population_fixture_path, gothwaite_population_manifest_path, {
		"zone": gothwaite_population_zone,
		"region": gothwaite_population_region,
		"world_origin_x": gothwaite_population_world_origin_x,
		"world_origin_y": gothwaite_population_world_origin_y,
		"source_units_per_meter": gothwaite_population_source_units_per_meter,
		"culling_distance_m": gothwaite_population_culling_distance_m,
		"show_ready_labels": gothwaite_population_ready_labels_visible,
		"show_fallback_labels": gothwaite_population_fallback_labels_visible,
		"prop_manifest_path": gothwaite_population_prop_manifest_path,
		"grounding_enabled": gothwaite_population_grounding_enabled,
	}) as Dictionary
	if gothwaite_population_grounding_enabled:
		call_deferred("_refine_gothwaite_population_grounding")


func _refine_gothwaite_population_grounding() -> void:
	# Les corps du terrain et des fixtures viennent d'etre ajoutes dans _ready().
	# Attendre une frame physique rend leur espace de collision interrogeable.
	await get_tree().physics_frame
	if _gothwaite_population == null or not _gothwaite_population.has_method("refine_living_supports"):
		return
	_gothwaite_population_report = _gothwaite_population.call("refine_living_supports", self, {
		"collision_mask": gothwaite_population_grounding_collision_mask,
		"probe_above_raw": gothwaite_population_grounding_probe_above_raw,
		"probe_below_raw": gothwaite_population_grounding_probe_below_raw,
		"source_tolerance_raw": gothwaite_population_grounding_source_tolerance_raw,
	}) as Dictionary
	print("GOTHWAITE_GROUNDING=%s" % JSON.stringify({
		"methods": _gothwaite_population_report.get("grounding_stats", {}),
		"collision_support_refined": int(_gothwaite_population_report.get("collision_support_refined", 0)),
	}))


func get_gothwaite_population_debug_snapshot() -> Dictionary:
	return _gothwaite_population_report.duplicate(true)


## P1-21A — monte l'autorite de combat locale au-dessus du peuplement.
##
## L'ordre compte : le serveur derive son etat de la MEME liste d'entites que
## `DaocGothwaitePopulation`, donc il doit venir apres elle. Il ne lit ni le
## reseau, ni un NIF, ni le disque au-dela de la fixture deja chargee.
func _build_local_server_combat_p1_21a() -> void:
	var source: Dictionary = DaocNearbyWorldEntitySourceScript.from_fixture(gothwaite_population_fixture_path)
	if not bool(source.get("ok", false)):
		_local_server_report = {"ok": false, "error": "fixture_unreadable", "detail": str(source.get("error", ""))}
		push_warning("P1-21A serveur local : fixture illisible (%s)" % str(source.get("error", "")))
		return

	_local_server = DaocLocalServerScript.new()
	_local_server.name = "DaocLocalServer"
	_local_server.log_events = local_server_log_events
	add_child(_local_server)

	var source_entities: Array = source.get("entities", []) as Array
	var boot_entities: Array = source_entities
	var game_session: DaocGameSession = _ensure_game_session()
	var living_runtime: DaocEntityStreamRuntime = (
		game_session.entity_stream if use_living_entity_stream and game_session != null else null)
	if living_runtime != null:
		# R3 : le flux R2 ne contient pas Heyveno — le registre la seme avant le
		# premier paquet. Elle est donc la seule presence initiale de l'arbitre ;
		# les PNJ entreront ensuite par leurs vrais evenements d'apparition.
		boot_entities = []
		for entity_value in source_entities:
			if entity_value is Dictionary and str((entity_value as Dictionary).get("entity_type", "")) == "player":
				boot_entities.append((entity_value as Dictionary).duplicate(true))
				break

	_local_server_report = _local_server.boot(boot_entities, {
		"player_level": local_server_player_level,
		"melee_range_raw": local_server_melee_range_raw,
		"retaliation_enabled": local_server_retaliation_enabled,
		"seed_base": local_server_seed_base,
	})
	if _gothwaite_population != null:
		var population_root: Node = _gothwaite_population.get("root") as Node
		_local_server_report["nodes_attached"] = _local_server.attach_nodes(population_root)
	if living_runtime != null:
		_bind_living_combat_r3(living_runtime)
		_local_server_report = _local_server.report()

	if combat_hud_enabled:
		_combat_hud = DaocCombatHudScript.new()
		_combat_hud.name = "DaocCombatHud"
		add_child(_combat_hud)

	_combat_client = DaocCombatClientScript.new()
	_combat_client.name = "DaocCombatClient"
	add_child(_combat_client)
	_combat_client.setup(self, _player, _local_server, _combat_hud, {
		"world_origin": Vector2(gothwaite_population_world_origin_x, gothwaite_population_world_origin_y),
		"target_radius_raw": combat_target_radius_raw,
		"target_key": int(combat_target_key),
		"attack_key": int(combat_attack_key),
		"zone_id": gothwaite_population_zone,
		"log_to_console": local_server_log_events,
	})

	_wire_mouse_targeting_p1_21h()

	if daoc_ui_enabled:
		_setup_daoc_ui()

	print("P1_21A_LOCAL_SERVER=%s" % JSON.stringify({
		"ok": bool(_local_server_report.get("ok", false)),
		"entity_states": int(_local_server_report.get("entity_states", 0)),
		"attackable": int(_local_server_report.get("attackable", 0)),
		"nodes_attached": int(_local_server_report.get("nodes_attached", 0)),
		"player_object_id": int(_local_server_report.get("player_object_id", -1)),
		"network_access_performed": false,
	}))


## R3 — branche l'arbitre sur l'unique sortie du flux R2, APRES application au
## monde. Si le flux a deja ete applique d'un coup (suites ou montage instantane),
## son prefixe est rejoue vers l'arbitre ; sinon les prochains evenements seront
## recus au fil des trames. Dans les deux cas l'autorite ne voit jamais la photo
## finale avant le monde.
func _bind_living_combat_r3(runtime: DaocEntityStreamRuntime) -> void:
	if runtime == null or _local_server == null:
		return
	var receiver := Callable(self, "_on_living_entity_event_r3")
	if not runtime.entity_event_applied.is_connected(receiver):
		runtime.entity_event_applied.connect(receiver)
	var authority_id := _local_server.get_instance_id()
	if int(runtime.get_meta("r3_replayed_authority_id", 0)) == authority_id:
		return
	var applied_count := mini(runtime.cursor, runtime.events.size())
	for index in range(applied_count):
		_on_living_entity_event_r3(runtime.events[index] as Dictionary, {"replayed": true})
	runtime.set_meta("r3_replayed_authority_id", authority_id)


## Traduit uniquement le REFERENTIEL des deplacements. Aucune regle de combat
## ni aucun decodage de paquet ne vit ici.
func _on_living_entity_event_r3(event: Dictionary, _outcome: Dictionary = {}) -> void:
	if _local_server == null:
		return
	var object_id := int(event.get("object_id", -1))
	match str(event.get("kind", "")):
		DaocWorldEntityStream.KIND_SPAWN:
			var entity_value: Variant = event.get("entity", {})
			if not entity_value is Dictionary:
				return
			var entity_node: Node3D = null
			if _gothwaite_population != null and _gothwaite_population.has_method("wrapper_of"):
				entity_node = _gothwaite_population.call("wrapper_of", object_id) as Node3D
			_local_server.spawn_stream_entity(entity_value as Dictionary, entity_node)
		DaocWorldEntityStream.KIND_MOVE:
			_local_server.move_stream_entity(object_id, Vector3(
				gothwaite_population_world_origin_x + float(event.get("zone_x", 0.0)),
				gothwaite_population_world_origin_y + float(event.get("zone_y", 0.0)),
				float(event.get("zone_z", 0.0))))
		DaocWorldEntityStream.KIND_DESPAWN:
			_local_server.despawn_stream_entity(object_id, "R2_entity_stream")


## P1-21E - monte les fenetres du client et les relie a l'autorite de combat.
## Le HUD provisoire n'est pas touche : les deux peuvent coexister le temps du
## verdict visuel.
func _setup_daoc_ui() -> void:
	var ui_root: String = daoc_client_root.replace("\\", "/").path_join("ui")
	if not DirAccess.dir_exists_absolute(ui_root):
		_daoc_ui_report = {"ok": false, "reason": "dossier ui/ introuvable : %s" % ui_root}
		push_warning("P1-21E: %s" % _daoc_ui_report["reason"])
		return

	_daoc_ui_bus = DaocUiAdapterBusScript.new()
	_daoc_ui_manager = DaocUiWindowManagerScript.new()
	_daoc_ui_manager.name = "DaocUiWindowManager"
	add_child(_daoc_ui_manager)
	_daoc_ui_report = _daoc_ui_manager.setup(
		ui_root, daoc_ui_skin, _daoc_ui_bus, daoc_ui_windows, daoc_ui_scale)

	if _local_server != null:
		_daoc_ui_bridge = DaocUiServerBridgeScript.new()
		_daoc_ui_report["bridge"] = _daoc_ui_bridge.setup(
			_local_server, _daoc_ui_bus,
			int(_local_server_report.get("player_object_id", -1)))

		# Sans cette liaison, `set_target()` n'etait jamais appele : cibler un
		# rat ne remplissait pas la fenetre de resume.
		if _combat_client != null:
			_combat_client.target_changed.connect(_daoc_ui_bridge.set_target)
			_daoc_ui_bridge.set_target(_combat_client.current_target_id)
			_daoc_ui_report["target_wired"] = true

	print("P1_21E_DAOC_UI=%s" % JSON.stringify(_daoc_ui_report))


## P1-21H — relie le clic monde du routeur d'entrees au picker du client de
## combat. Le routeur ignore tout du gameplay ; c'est ici, ou vivent les deux
## noeuds, que la couture se fait. Le peuplement et le routeur existent deja :
## `build_ready_sequence` monte le routeur avant l'appel a cette fonction.
func _wire_mouse_targeting_p1_21h() -> void:
	if not mouse_targeting_enabled or _combat_client == null or _input_router == null:
		return
	if not _input_router.has_signal("world_click"):
		return
	if not _input_router.world_click.is_connected(_on_world_click_target_p1_21h):
		_input_router.world_click.connect(_on_world_click_target_p1_21h)


## Un clic gauche hors interface cible l'entite sous le pointeur. Le picker
## renvoie l'instantane de la cible ; on ne fait rien de plus ici, l'anneau et le
## HUD suivent le changement de cible tout seuls.
func _on_world_click_target_p1_21h(screen_position: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT or _combat_client == null:
		return
	_combat_client.pick_target_at_screen(
		screen_position, mouse_targeting_pixel_tolerance, mouse_targeting_max_distance_raw)


func get_daoc_ui_debug_snapshot() -> Dictionary:
	if _daoc_ui_manager == null:
		return {"enabled": false}
	var snapshot: Dictionary = _daoc_ui_manager.get_debug_snapshot()
	snapshot["enabled"] = true
	if _daoc_ui_bridge != null:
		snapshot["bridge"] = _daoc_ui_bridge.get_debug_snapshot()
	return snapshot


func get_local_server_debug_snapshot() -> Dictionary:
	var out: Dictionary = _local_server_report.duplicate(true)
	if _local_server != null:
		out["runtime"] = _local_server.report()
	if _combat_client != null:
		out["client"] = _combat_client.get_debug_snapshot()
	if _combat_hud != null:
		out["hud"] = _combat_hud.get_debug_snapshot()
	return out


func show_pregame_selection_ui_p1_20ui(enabled: bool = true) -> Node:
	if not enabled:
		if _p1_20ui_pregame_layer != null:
			_p1_20ui_pregame_layer.queue_free()
			_p1_20ui_pregame_layer = null
		return null
	if _p1_20ui_pregame_layer == null:
		_p1_20ui_pregame_layer = CanvasLayer.new()
		_p1_20ui_pregame_layer.name = "P1_20UI_PregameLayer"
		_p1_20ui_pregame_layer.layer = 100
		add_child(_p1_20ui_pregame_layer)
		var flow := DaocPregameFlowScene.instantiate()
		flow.name = "DaocPregameFlow"
		_p1_20ui_pregame_layer.add_child(flow)
	return _p1_20ui_pregame_layer.get_node_or_null("DaocPregameFlow")


func _apply_player_visual_meshy_from_inspector_p1_18m() -> void:
	# P1-18M Inspector bridge: garde CharacterBody3D + CollisionShape3D, ne change que le visuel.
	if not spawn_player_capsule:
		return
	if not player_visual_meshy_enabled:
		_execute_local_debug_command_a7d("/playervisual off")
		return
	# Le fichier JSON porte le contrat d'échelle DAoC. Les anciens réglages Meshy de
	# l'inspecteur (notamment scale=60) ne doivent plus l'écraser silencieusement.
	if player_visual_meshy_inspector_overrides_enabled:
		_execute_local_debug_command_a7d("/playervisual scale %.4f" % player_visual_meshy_scale)
		_execute_local_debug_command_a7d("/playervisual yoffset %.3f" % player_visual_meshy_ground_offset)
		_execute_local_debug_command_a7d("/playervisual yaw %.3f" % player_visual_meshy_yaw_degrees)
	_execute_local_debug_command_a7d("/playervisual meshy")
	# Runtime-only options must be applied after the visual root exists.
	if player_visual_meshy_inspector_overrides_enabled:
		_execute_local_debug_command_a7d("/playervisual idlemode %s" % player_visual_meshy_idle_mode)
	_configure_runtime_feet_alignment_p1_18p()
	if player_grounding_apply_on_ready or player_visual_feet_align_on_ready:
		call_deferred("apply_player_grounding_and_feet_alignment_p1_18p")
	var anim_state := player_visual_meshy_animation_state.strip_edges().to_lower()
	if anim_state == "idle" or anim_state == "walk" or anim_state == "run":
		_execute_local_debug_command_a7d("/playervisual %s" % anim_state)
	else:
		_execute_local_debug_command_a7d("/playervisual auto")
	if player_visual_meshy_print_status_on_ready:
		_execute_local_debug_command_a7d("/playervisual status")


func build_player_grounding_options_p1_18p(extra: Dictionary = {}) -> Dictionary:
	var options := {
		"grounding_enabled": player_grounding_enabled,
		"grounding_snap_enabled": player_grounding_enabled,
		"grounding_use_collision": player_grounding_use_collision,
		"grounding_use_terrain": player_grounding_use_terrain,
		"grounding_probe_height": player_grounding_probe_height,
		"grounding_probe_depth": player_grounding_probe_depth,
		"grounding_actor_ground_offset": player_grounding_actor_ground_offset,
		"grounding_max_snap_delta": player_grounding_max_snap_delta,
		"grounding_snap_strength": player_grounding_snap_strength,
		"grounding_max_walkable_slope_degrees": player_grounding_max_walkable_slope_degrees,
		"grounding_ignore_vegetation": player_grounding_ignore_vegetation,
		"grounding_debug_draw": player_grounding_debug_draw,
		"player_visual_feet_offset": player_visual_feet_offset,
		"player_visual_feet_align_runtime": player_visual_feet_align_runtime,
		"player_visual_feet_align_max_step": player_visual_feet_align_max_step,
		"report_dir": player_grounding_report_dir,
		"write_report": true,
	}
	for key in extra.keys():
		options[key] = extra[key]
	return options


func apply_player_grounding_and_feet_alignment_p1_18p(extra: Dictionary = {}) -> Dictionary:
	var service: RefCounted = DaocGroundingServiceScript.new()
	if service == null:
		return {"ok": false, "reason": "grounding_service_missing"}
	var options := build_player_grounding_options_p1_18p(extra)
	var report := {"ok": true, "grounding": {}, "feet": {}, "checkpoint": "P1_18P_ACTOR_GROUNDING_VISUAL_FEET_ALIGNMENT"}
	if _player != null and player_grounding_enabled:
		var player_body := _player as CharacterBody3D
		if player_body != null:
			report["grounding"] = service.call("apply_grounding", player_body, self, options)
	if _player != null and player_visual_auto_feet_align and bool(options.get("apply_visual_feet_alignment", player_visual_feet_align_on_ready)):
		var visual_root := _player.get_node_or_null("DaocPlayerVisualRoot") as Node3D
		if visual_root != null:
			report["feet"] = service.call("apply_visual_feet_alignment", visual_root, options)
	if player_grounding_print_status_on_ready or player_visual_feet_debug:
		print("P1-18P grounding=%s feet=%s" % [str(report.get("grounding", {})), str(report.get("feet", {}))])
	return report


func _configure_runtime_feet_alignment_p1_18p() -> void:
	if _player == null:
		return
	var visual_root := _player.get_node_or_null("DaocPlayerVisualRoot")
	if visual_root != null and visual_root.has_method("configure"):
		visual_root.call("configure", {
			"feet_alignment_enabled": player_visual_auto_feet_align and player_visual_feet_align_runtime,
			"feet_alignment_offset": player_visual_feet_offset,
			"feet_alignment_max_step": player_visual_feet_align_max_step,
		})



func _run_asset_material_audit_from_inspector_p1_18n() -> void:
	# P1-18N-HF1 Inspector bridge: génère les rapports sans passer par la console debug.
	if not asset_material_audit_enabled:
		if asset_material_audit_print_status_on_ready:
			print("P1-18N asset/material audit disabled in inspector")
		return
	var audit: RefCounted = DaocAssetMaterialFidelityAuditScript.new()
	if audit == null:
		push_warning("P1-18N asset/material audit service unavailable")
		return
	var znum: int = int(asset_material_audit_zone)
	var options: Dictionary = {
		"write_reports": true,
		"scan_model_index": true,
		"scan_texture_index": asset_material_audit_scan_textures,
		"inspect_runtime_materials": asset_material_audit_inspect_runtime_materials,
		"max_texture_samples": int(asset_material_audit_max_texture_samples),
		"max_runtime_material_nodes": int(asset_material_audit_max_runtime_material_nodes),
		"report_dir": asset_material_audit_report_dir,
	}
	var report: Dictionary = audit.call("run_zone_audit", self, znum, options) as Dictionary
	if asset_material_audit_print_status_on_ready:
		print(audit.call("summarize_for_console", report))
		var written: Dictionary = report.get("written_files", {}) as Dictionary
		print("P1-18N reports: txt=%s json=%s dir=%s" % [str(written.get("txt", "")), str(written.get("json", "")), asset_material_audit_report_dir])


func _run_nif_import_probe_from_inspector_p1_18n_hf6() -> void:
	if not nif_import_probe_enabled:
		print("P1-18N-HF6 NIF import probe disabled in inspector")
		return
	var probe: RefCounted = DaocNifImportConversionProbeScript.new()
	if probe == null:
		push_warning("P1-18N-HF6 NIF import probe service unavailable")
		return
	var report: Dictionary = probe.call("run_zone_probe", self, int(nif_import_probe_zone), {
		"write_csv": nif_import_probe_write_csv,
		"write_json": nif_import_probe_write_json,
		"write_txt": true,
		"max_fixtures": int(nif_import_probe_max_fixtures),
		"focus_bridgehouse": nif_import_probe_focus_bridgehouse,
	}) as Dictionary
	print(probe.call("summarize_for_console", report))


func build_generated_scene_parity_options_p1_19a(extra: Dictionary = {}) -> Dictionary:
	var options := {
		"zone_id": p1_19a_generated_scene_zone_id,
		"manifest_path": "res://reports/generated/zones/manifest.json",
		"generated_scene_path": p1_19a_generated_scene_path,
		"compare_runtime_viewer": p1_19a_compare_runtime_viewer,
		"compare_materials": p1_19a_compare_materials,
		"compare_collisions": p1_19a_compare_collisions,
		"focus_critical_fixtures": p1_19a_focus_critical_fixtures,
		"max_fixture_compare": p1_19a_max_fixture_compare,
		"boot_enabled": p1_19a_generated_boot_enabled,
		"boot_spawn_player": p1_19a_generated_boot_spawn_player,
		"boot_attach_meshy": p1_19a_generated_boot_attach_meshy,
		"boot_use_grounding": p1_19a_generated_boot_use_grounding,
		"boot_debug": p1_19a_generated_boot_debug,
		"report_dir": p1_19a_report_dir,
		"write_reports": true,
	}
	for key in extra.keys():
		options[key] = extra[key]
	return options


func _run_generated_scene_parity_from_inspector_p1_19a() -> Dictionary:
	if not p1_19a_parity_enabled:
		return {"ok": false, "reason": "p1_19a_parity_disabled"}
	var audit: RefCounted = DaocGeneratedSceneParityAuditScript.new()
	if audit == null:
		return {"ok": false, "reason": "parity_audit_missing"}
	var report: Dictionary = audit.call("run_parity_audit", self, build_generated_scene_parity_options_p1_19a()) as Dictionary
	if bool(p1_19a_generated_boot_debug) or bool(report.get("overall_verdict", "") != "PASS"):
		print("P1-19A generated parity verdict=%s scene=%s reports=%s" % [
			str(report.get("overall_verdict", "")),
			str((report.get("generated_scene", {}) as Dictionary).get("scene_path", "")),
			str(report.get("written_files", {})),
		])
	return report


func build_opendaoc_tcp_login_probe_options_p1_20a(extra: Dictionary = {}) -> Dictionary:
	var options := {
		"probe_enabled": p1_20a_opendaoc_probe_enabled,
		"run_on_ready": p1_20a_opendaoc_probe_run_on_ready,
		"dry_run_report_on_ready": p1_20a_opendaoc_dry_run_report_on_ready,
		"host": p1_20a_opendaoc_host,
		"login_port": p1_20a_opendaoc_login_port,
		"username": _p1_20a_credential("p1_20a_opendaoc_username", "OPENDAOC_TEST_USERNAME"),
		"password": _p1_20a_credential("p1_20a_opendaoc_password", "OPENDAOC_TEST_PASSWORD"),
		"client_version": p1_20a_opendaoc_client_version,
		"send_packets": p1_20a_opendaoc_send_packets,
		"allow_production_host": p1_20a_opendaoc_allow_production_host,
		"stop_after_character_overview": p1_20a_opendaoc_stop_after_character_overview,
		"write_hex_dump": p1_20a_opendaoc_write_hex_dump,
		"timeout_seconds": p1_20a_opendaoc_timeout_seconds,
		"report_dir": p1_20a_opendaoc_report_dir,
		"redact_credentials": p1_20a_opendaoc_redact_credentials,
	}
	for key in extra.keys():
		options[key] = extra[key]
	return options


## Un identifiant de sonde : le champ de l'inspecteur d'abord, la variable
## d'environnement ensuite.
##
## POURQUOI CE REPLI EXISTE : ce qu'on tape dans l'inspecteur est ÉCRIT DANS
## `ZoneViewer.tscn` à la sauvegarde, et cette scène est SUIVIE PAR GIT. Un mot
## de passe saisi ici part donc dans le prochain commit sans que rien ne le
## signale — le dépôt ne doit jamais être publié, mais ce n'est pas une raison
## pour y déposer un secret. Laisser le champ VIDE et renseigner
## `OPENDAOC_TEST_PASSWORD` garde le secret hors du dépôt.
##
## Le champ reste disponible : sur un serveur local avec un compte jetable, le
## confort peut valoir plus que la précaution. Mais l'avertissement est émis une
## fois, pour que le choix soit conscient et non subi.
func _p1_20a_credential(export_name: String, env_name: String) -> String:
	var from_export := str(get(export_name)).strip_edges()
	if from_export != "":
		if not _p1_20a_credential_warned.has(export_name):
			_p1_20a_credential_warned[export_name] = true
			push_warning(
				"P1-20A : `%s` est renseigné dans l'inspecteur. Sauvegarder la scène l'écrira dans ZoneViewer.tscn, qui est suivi par git. Vider le champ et définir %s garde la valeur hors du dépôt."
					% [export_name, env_name])
		return from_export
	return OS.get_environment(env_name).strip_edges()


func _write_opendaoc_tcp_login_probe_dry_run_early_p1_20a() -> Dictionary:
	return _run_opendaoc_tcp_login_probe_from_inspector_p1_20a({
		"probe_enabled": false,
		"send_packets": false,
		"trigger": "early_ready_dry_run",
	})


func _run_opendaoc_tcp_login_probe_ctrl_r_p1_20a() -> Dictionary:
	return _run_opendaoc_tcp_login_probe_from_inspector_p1_20a({
		"probe_enabled": false,
		"send_packets": false,
		"trigger": "ctrl_r_dry_run",
	})


func _run_opendaoc_tcp_login_probe_from_inspector_p1_20a(extra: Dictionary = {}) -> Dictionary:
	var probe: Node = DaocOpenDaocTcpLoginProbeScript.new()
	if probe == null:
		return {"ok": false, "reason": "opendaoc_tcp_login_probe_missing"}
	var report: Dictionary = probe.call("run_probe", build_opendaoc_tcp_login_probe_options_p1_20a(extra)) as Dictionary
	probe.free()
	print("P1-20A OpenDAoC TCP probe verdict=%s state=%s reports=%s" % [
		str(report.get("verdict", "")),
		str(report.get("last_state", "")),
		str(report.get("written_files", {})),
	])
	return report


func _apply_nif_import_probe_visual_debug_p1_18n_hf6() -> void:
	if not nif_import_probe_visual_debug_enabled:
		return
	var probe: RefCounted = DaocNifImportConversionProbeScript.new()
	if probe == null:
		return
	var report: Dictionary = probe.call("apply_visual_debug", self, int(nif_import_probe_zone), int(nif_import_probe_visual_debug_target_fixture_id), nif_import_probe_visual_debug_draw_aabb, nif_import_probe_visual_debug_highlight, nif_import_probe_visual_debug_label) as Dictionary
	print("P1-18N-HF6 visual debug: %s" % str(report))

func _exit_tree() -> void:
	if _asset_index_registry_obj != null and _asset_index_registry_obj.has_method("clear_runtime_caches"):
		_asset_index_registry_obj.call("clear_runtime_caches")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if p1_20a_opendaoc_ctrl_r_enabled and event.ctrl_pressed and event.keycode == KEY_R:
			_run_opendaoc_tcp_login_probe_ctrl_r_p1_20a()
			get_viewport().set_input_as_handled()
			return
		if zonecreator_manual_hotkeys_enabled and event.keycode == KEY_F1 and not event.ctrl_pressed:
			_execute_local_debug_command_a7d("/offlinepreview show")
			get_viewport().set_input_as_handled()
			return
		if zonecreator_manual_hotkeys_enabled and event.ctrl_pressed:
			if event.keycode == KEY_F1:
				_execute_local_debug_command_a7d("/offlinepreview show")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F2:
				_execute_local_debug_command_a7d("/offlinepreview hide")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F3:
				_execute_local_debug_command_a7d("/generateddungeon detachall")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F4:
				_execute_local_debug_command_a7d(_generated_dungeon_attachspawn_command_17d())
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F5:
				_execute_local_debug_command_a7d(_zonecreator_dungeon_report_command_c3())
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F6:
				_execute_local_debug_command_a7d(_zonecreator_dungeon_command_c2_hf1(true))
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F7:
				_execute_local_debug_command_a7d(_zonecreator_dungeon_command_c2_hf1(false))
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F8:
				_execute_local_debug_command_a7d("/zonecreator manifest")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F9:
				_execute_local_debug_command_a7d("/zonecreator dryrun 0 1")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F10:
				_execute_local_debug_command_a7d("/zonecreator export 0 1")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F11:
				_execute_local_debug_command_a7d("/generated attachall")
				get_viewport().set_input_as_handled()
				return
		if f12_debug_test_enabled and event.keycode == KEY_F12:
			_run_f12_debug_tests()
			get_viewport().set_input_as_handled()


func _zonecreator_dungeon_command_c2_hf1(dry_run: bool) -> String:
	var zones_text: String = ""
	for znum in zonecreator_manual_dungeon_zones:
		if zones_text != "":
			zones_text += " "
		zones_text += str(int(znum))
	if zones_text == "":
		zones_text = "19 21"
	return "/zonecreator %s %s" % ["dungeondryrun" if dry_run else "dungeon", zones_text]


func _zonecreator_dungeon_report_command_c3() -> String:
	var zones_text: String = ""
	for znum in zonecreator_manual_dungeon_zones:
		if zones_text != "":
			zones_text += " "
		zones_text += str(int(znum))
	if zones_text == "":
		zones_text = "19 21"
	return "/zonecreator dungeonreport %s" % zones_text


func _generated_dungeon_attachspawn_command_17d() -> String:
	var znum: int = generated_dungeon_runtime_default_zone
	if znum <= 0 and zonecreator_manual_dungeon_zones.size() > 0:
		znum = int(zonecreator_manual_dungeon_zones[0])
	if znum <= 0:
		znum = 19
	return "/generateddungeon attachspawn %d" % znum


func _ensure_generated_dungeon_runtime_bridge_17d() -> RefCounted:
	if _generated_dungeon_runtime_bridge_17d == null:
		_generated_dungeon_runtime_bridge_17d = DaocGeneratedDungeonRuntimeBridgeScript.new()
		if _generated_dungeon_runtime_bridge_17d != null and _generated_dungeon_runtime_bridge_17d.has_method("configure"):
			_generated_dungeon_runtime_bridge_17d.call("configure", self)
	return _generated_dungeon_runtime_bridge_17d


func ensure_generated_dungeon_runtime_bridge_17d() -> RefCounted:
	return _ensure_generated_dungeon_runtime_bridge_17d()


func has_generated_dungeon_runtime_zone_17d(znum: int) -> bool:
	var bridge: RefCounted = _ensure_generated_dungeon_runtime_bridge_17d()
	return bridge != null and bridge.has_method("has_attached_zone") and bool(bridge.call("has_attached_zone", znum))


func get_generated_dungeon_runtime_17d_debug_snapshot() -> Dictionary:
	var bridge: RefCounted = _ensure_generated_dungeon_runtime_bridge_17d()
	if bridge != null and bridge.has_method("debug_snapshot"):
		return bridge.call("debug_snapshot") as Dictionary
	return {"scope": "P1-17E1 GeneratedDungeon runtime via neutral WorldDestination", "present": false}


func _execute_local_debug_command_a7d(command_text: String) -> bool:
	var command: Object = get("_command_router") as Object
	if command == null or not command.has_method("execute_command"):
		print("DAoC A7D manual command failed: command router missing")
		return false
	print("DAoC A7D manual command: %s" % command_text)
	var ok: bool = bool(command.call("execute_command", command_text))
	print("DAoC A7D manual command handled=%s" % str(ok))
	return ok


func _run_f12_debug_tests() -> void:
	if _debug_test_runner == null:
		_debug_test_runner = DaocDebugTestRunnerScript.new()
	var result: Dictionary = _debug_test_runner.call("run", self) as Dictionary
	if f12_debug_test_print_paths:
		print("DAoC F12 tests: pass=%s warn=%s fail=%s" % [str(result.get("pass", 0)), str(result.get("warn", 0)), str(result.get("fail", 0))])
		print("DAoC F12 report: %s" % str(result.get("report_path", "")))
		print("DAoC F12 debug export: %s" % str(result.get("debug_export_path", "")))
		print("DAoC F12 json report: %s" % str(result.get("json_report_path", "")))


func _process(delta: float) -> void:
	# Allows live tweaking from the Remote inspector while the scene is running.
	# Cheap enough for the current 38 DAoC legacy lights and vegetation roots.
	_apply_visual_stage_lamps_15c()
	_apply_visual_stage_cards_15c()
	_tick_zone_lod_plan_p1_33(delta)
	_tick_terrain_pbr_options()


func _load_placement() -> void:
	var f := FileAccess.open(_asset_data_15d("zones_placement.json"), FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		for z in d.get("zones", []):
			_placement[int(z["zone"])] = Vector2(float(z["world_origin"][0]), float(z["world_origin"][1]))


func _origin(znum: int) -> Vector2:
	return _placement.get(znum, Vector2.ZERO)


func _compute_base() -> void:
	var first := true
	for z in zones:
		var o := _origin(z)
		if first:
			_base = o
			first = false
		else:
			_base.x = min(_base.x, o.x)
			_base.y = min(_base.y, o.y)



func _get_zone_root(znum: int) -> Node3D:
	if not use_structured_zone_root:
		return self
	# R1 : le streamer possede les branches de zone et sait aussi les DETRUIRE,
	# ce que ce dictionnaire local n'a jamais su faire.
	var streamer: DaocZoneStreamer = _ensure_zone_streamer()
	if streamer != null:
		return streamer.acquire(znum)
	if _zone_roots.has(znum):
		return _zone_roots[znum] as Node3D
	var zr: Node3D = DaocZoneRootScript.new()
	zr.setup(znum)
	add_child(zr)
	_zone_roots[znum] = zr
	return zr


func _zone_branch(znum: int, branch_name: String) -> Node3D:
	var zr := _get_zone_root(znum)
	if not use_structured_zone_root:
		return zr
	if zr.has_method("get_branch"):
		return zr.call("get_branch", branch_name) as Node3D
	return zr


func _build_zone(znum: int) -> void:
	_ensure_zone_scene_assembler_15b()
	if _zone_scene_assembler_obj == null:
		push_warning("P1-15B ZoneSceneAssembler unavailable")
		return
	var result: Dictionary = _zone_scene_assembler_obj.call("build_zone", self, znum) as Dictionary
	_state_15e.zone_scene_assembler_results[znum] = result
	if not bool(result.get("ok", false)):
		push_warning("P1-15B zone assembler failed for zone%03d: %s" % [znum, str(result.get("error", "unknown"))])


func _ensure_zone_scene_assembler_15b() -> void:
	if _zone_scene_assembler_obj == null:
		_zone_scene_assembler_obj = DaocZoneSceneAssemblerScript.new()


func get_zone_scene_15b_debug_snapshot() -> Dictionary:
	_ensure_zone_scene_assembler_15b()
	var status: Dictionary = {}
	if _zone_scene_assembler_obj != null and _zone_scene_assembler_obj.has_method("status"):
		status = _zone_scene_assembler_obj.call("status") as Dictionary
	var zone0_result: Dictionary = _state_15e.zone_scene_assembler_results.get(0, {}) as Dictionary
	return {
		"scope": "P1-15B ZoneSceneAssembler foundation",
		"assembler_present": _zone_scene_assembler_obj != null,
		"result_count": _state_15e.zone_scene_assembler_results.size(),
		"zones": _state_15e.zone_scene_assembler_results.keys(),
		"zone0_result": zone0_result,
		"zone0_ok": bool(zone0_result.get("ok", false)),
		"build_order": status.get("build_order", []),
		"status": status,
		"zone_runtime_size": _state_15e.zone_runtime.size(),
		"builder_results": {
			"terrain": _state_15e.terrain_build_results.size(),
			"collision": _state_15e.boundary_build_results.size(),
			"zonejump": _state_15e.zonejump_build_results.size(),
			"water": _state_15e.water_build_results.size(),
			"props": _state_15e.prop_build_results.size(),
		},
		"recommended_next_step": "P1-15C ZoneViewer mass reduction A legacy visuals",
	}


func _setup_terrain_builder_for_zone(znum: int, meta: Dictionary, hb: PackedByteArray, res: int, origin3: Vector3, meta_path: String) -> void:
	# R4 tranche 3 : le nouveau chemin. Même constructeur 14E, même index, même
	# runtime ; seul le propriétaire de la plomberie a changé.
	if use_zone_build_steps:
		DaocZoneTerrainStep.build(zone_build_services_r4(), znum, meta, hb, res,
			origin3, meta_path, zone_step_settings_r4("terrain"),
			zone_step_logging_r4("terrain"))
		return
	var splat_manifest: Dictionary = {}
	var splat_manifest_path := _asset_data_15d("zone%03d_splat/manifest.json" % znum)
	if FileAccess.file_exists(splat_manifest_path):
		var loaded: Variant = _asset_read_15d(splat_manifest_path)
		if typeof(loaded) == TYPE_DICTIONARY:
			splat_manifest = loaded as Dictionary
			_prepare_terrain_splat_resources_14e(znum, splat_manifest)

	var ground_texture: Texture2D = null
	var ground_path := _asset_data_15d("zone%03d_ground.png" % znum)
	if FileAccess.file_exists(ground_path) or (ground_path.begins_with("res://") and ResourceLoader.exists(ground_path)):
		ground_texture = _asset_tex_15d(ground_path)

	var result: RefCounted = DaocTerrainBuilderScript.build(znum, meta, hb, origin3, {
		"source_path": meta_path,
		"world_scale": world_scale,
		"height_exaggeration": height_exaggeration,
		"build_terrain_collision": build_terrain_collision,
		"terrain_collision_layer": terrain_collision_layer,
		"terrain_collision_mask": terrain_collision_mask,
		"splat_manifest": splat_manifest,
		"splat_shader": _state_15e.splat_shader,
		"splat_details": _state_15e.splat_details,
		"splat_masks": _state_15e.splat_masks,
		"ground_texture": ground_texture,
		"tile_scale": 1.0,
		"terrain_pbr": terrain_pbr_quality_options(),
		"terrain_visual_bilinear_subdivision": terrain_visual_bilinear_subdivision,
	})
	_register_terrain_build_result_14e(znum, result)
	if result != null:
		var metrics: Dictionary = result.get("metrics") as Dictionary
		print("zone%03d terrain: %d sector(s), %d mesh(es), %d collision body/bodies [14E builder sig=%s]" % [
			znum,
			int(metrics.get("sectors", 0)),
			int(metrics.get("terrain_meshes", 0)),
			int(metrics.get("collision_bodies", 0)),
			str(result.get("index_signature")),
		])


func _terrain_14e_zone_uses_splat(znum: int) -> bool:
	var result: RefCounted = _state_15e.terrain_build_results.get(znum, null) as RefCounted
	if result == null:
		return false
	var metrics: Dictionary = result.get("metrics") as Dictionary
	return int(metrics.get("sectors", 0)) > 1


func _register_terrain_build_result_14e(znum: int, result: RefCounted) -> void:
	if result == null:
		_state_15e.terrain_build_results.erase(znum)
		_state_15e.terrain_meshes_by_zone[znum] = []
		_state_15e.terrain_collision_bodies_by_zone[znum] = []
		_replace_terrain_static_index_for_zone(znum, [])
		_ensure_terrain_runtime_14e()
		return
	_state_15e.terrain_build_results[znum] = result
	var result_root: Node3D = result.get("root") as Node3D
	if result_root != null:
		_zone_branch(znum, "TerrainRoot").add_child(result_root)
	var collision_root: Node3D = result.get("collision_root") as Node3D
	if collision_root != null and collision_root.get_child_count() > 0:
		_collision_root(znum).add_child(collision_root)
	_state_15e.terrain_meshes_by_zone[znum] = result.get("terrain_meshes") as Array
	_state_15e.terrain_collision_bodies_by_zone[znum] = result.get("collision_bodies") as Array
	_state_15e.terrain_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_terrain_static_index_for_zone(znum, result.get("static_index") as Array)
	_ensure_terrain_runtime_14e()


func _ensure_terrain_runtime_14e() -> void:
	if _state_15e.terrain_runtime_obj == null:
		_state_15e.terrain_runtime_obj = DaocTerrainRuntimeScript.new()
	_state_15e.terrain_runtime_obj.call("bind", _state_15e.terrain_static_index, _state_15e.zone_runtime)


func _replace_terrain_static_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.terrain_static_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.terrain_static_index = kept


func _setup_prop_builder_for_zone(meta: Dictionary, base: Vector3, hb: PackedByteArray, res: int) -> void:
	# R4 tranche 6 : le nouveau chemin. Mêmes constructeurs 14D et 14C, mêmes
	# deux index de session, mêmes deux accrochages ; seul le propriétaire de la
	# plomberie a changé. Les deux gardes `place_real_models` et
	# `generate_prop_collisions` descendent DANS l'étape, car décochés ils ne
	# s'abstiennent pas : le premier bascule sur les marqueurs, le second laisse
	# le placement visuel intact.
	if use_zone_build_steps:
		DaocZonePropsStep.build(zone_build_services_r4(), meta, base, hb, res,
			zone_step_settings_r4("props"), zone_step_logging_r4("props"))
		return
	var znum := int(meta.get("zone", -1))
	var pj_path := _asset_data_15d("zone%03d_placement.json" % znum)
	# No placement file or disabled -> keep the lightweight box markers, now via PropBuilder too.
	if not place_real_models or not FileAccess.file_exists(pj_path):
		_setup_prop_box_builder_for_zone(meta, base, hb, res)
		return

	var pf := FileAccess.open(pj_path, FileAccess.READ)
	var pj: Variant = JSON.parse_string(pf.get_as_text())
	pf.close()
	if typeof(pj) != TYPE_DICTIONARY:
		push_warning("placement: bad json %s" % pj_path)
		_setup_prop_box_builder_for_zone(meta, base, hb, res)
		return

	_ensure_asset_index_registry_15d().call("ensure_model_index")
	var models: Dictionary = pj.get("models", {})       # "nif" -> filename
	var fixtures: Array = pj.get("fixtures", [])
	var prepared_entries: Array = []
	var prop_collision_count := 0
	var prop_collision_missing_flag_fallback := 0
	var prop_collision_skipped_no_flag := 0
	var prop_collision_skipped_excluded := 0
	var prop_collision_skipped_flag_zero := 0

	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		var nif_id := int(fx.get("nif", -1))
		var fn: String = str(models.get(str(nif_id), ""))
		var tmpl := _ensure_asset_index_registry_15d().call("get_model", fn) as Node3D
		var s: float = float(fx.get("scale", 1.0)) * world_scale
		var wx: float = float(fx.get("x", 0.0))
		var wy: float = float(fx.get("y", 0.0))
		var h_units: float = float(fx.get("z", 0.0))
		var force_floor_anchor := _prop_should_floor_anchor_model(fn)
		var grounded := int(fx.get("ground", 0)) == 1 or h_units == 0.0 or force_floor_anchor
		if grounded:
			h_units = sample_daoc_floor_z(znum, wx, wy, 0.0)
			if force_floor_anchor:
				h_units += _prop_floor_anchor_offset_raw(fn)
		var pos := base + Vector3(wx * world_scale,
			h_units * world_scale * height_exaggeration,
			wy * world_scale)
		# Ground=1 means "rest ON the ground". Only LOWER models that float above
		# their origin (min_y > 0); never raise a model whose geometry already
		# reaches at/below its origin (that would make real 3D trees levitate).
		if grounded and anchor_to_base:
			pos.y -= _prop_ground_anchor_min_y(fn, float(_ensure_asset_index_registry_15d().call("model_min_y", fn))) * s
		var ang := deg_to_rad(heading_sign * float(fx.get("a", 0.0)) + heading_offset_deg)
		var basis := Basis(Vector3.UP, ang).scaled(Vector3.ONE * s)
		var xform := Transform3D(basis, pos)
		var fixture_id := int(fx.get("id", 0))
		var entry := {
			"fixture_id": fixture_id,
			"nif_id": nif_id,
			"file": fn,
			"template": tmpl,
			"transform": xform,
			"marker_transform": Transform3D(Basis().scaled(Vector3.ONE * s), pos),
			"position": pos,
			"x": wx,
			"y": wy,
			"z": h_units,
			"a": float(fx.get("a", 0.0)),
			"scale": float(fx.get("scale", 1.0)),
			"ground": int(fx.get("ground", 0)),
			"node_name": "f%d_%s" % [fixture_id, fn.get_basename()],
			"source": pj_path,
			"missing": tmpl == null,
		}
		prepared_entries.append(entry)

		if tmpl == null:
			_ensure_asset_index_registry_15d().call("record_missing_model", znum, fx, fn)
			continue
		if generate_prop_collisions:
			var prop_decision: Dictionary = _collision_prop_decision_14c(znum, fx, fn)
			var prop_reason: String = str(prop_decision.get("reason", ""))
			if bool(prop_decision.get("wants", false)):
				if prop_reason == "missing_flag_fallback":
					prop_collision_missing_flag_fallback += 1
				if _setup_prop_collision_builder_body(znum, fx, fn, tmpl, pos, ang, s):
					prop_collision_count += 1
			elif prop_reason == "excluded_by_name":
				prop_collision_skipped_excluded += 1
			elif prop_reason == "flag_zero":
				prop_collision_skipped_flag_zero += 1
			elif prop_reason == "missing_flag_no_fallback":
				prop_collision_skipped_no_flag += 1

	if generate_prop_collisions and log_collision:
		print("zone%03d prop collision: %d AABB body/bodies" % [znum, prop_collision_count])
		if prop_collision_log_decisions:
			print("zone%03d prop collision details: fallback_missing_flag=%d skipped_flag_zero=%d skipped_no_flag=%d skipped_excluded=%d" % [
				znum,
				prop_collision_missing_flag_fallback,
				prop_collision_skipped_flag_zero,
				prop_collision_skipped_no_flag,
				prop_collision_skipped_excluded,
			])

	var result: RefCounted = DaocPropBuilderScript.build(znum, prepared_entries, {
		"placement_path": pj_path,
		"mark_missing": mark_missing,
		"world_scale": world_scale,
		"daoc_client_root": _ensure_asset_index_registry_15d().effective_daoc_root(),
		"speedtree_enabled": speedtree_enabled,
		"speedtree_units_to_daoc": speedtree_units_to_daoc,
		"speedtree_visible_distance_raw": speedtree_visible_distance_raw,
	})
	_register_prop_build_result_14d(znum, result)
	var metrics: Dictionary = result.get("metrics") as Dictionary
	print("zone%03d placement: %d placed, %d missing model, %d fixtures [14D builder nodes=%d sig=%s]" % [
		znum,
		int(metrics.get("placed", 0)),
		int(metrics.get("missing", 0)),
		int(metrics.get("fixtures", fixtures.size())),
		int(metrics.get("nodes", 0)),
		str(result.get("index_signature")),
	])
	if export_missing_models_csv and int(metrics.get("missing", 0)) > 0:
		_ensure_asset_index_registry_15d().call("write_missing_models_csv")
	_hud_zones += "  [%d/%d props]" % [int(metrics.get("placed", 0)), int(metrics.get("fixtures", fixtures.size()))]


func _prop_ground_anchor_min_y(filename: String, min_y: float) -> float:
	var stem := filename.get_basename().to_lower()
	if stem == "brghouse" or stem == "bridgehouse":
		return min_y
	return maxf(0.0, min_y)


func _prop_should_floor_anchor_model(filename: String) -> bool:
	var stem := filename.get_basename().to_lower()
	return stem == "brghouse" or stem == "bridgehouse"


func _prop_floor_anchor_offset_raw(filename: String) -> float:
	var stem := filename.get_basename().to_lower()
	if stem == "brghouse" or stem == "bridgehouse":
		return brghouse_floor_anchor_offset_raw
	return 0.0


func _setup_prop_box_builder_for_zone(meta: Dictionary, base: Vector3, hb: PackedByteArray, res: int) -> void:
	var znum := int(meta.get("zone", -1))
	var fixtures: Array = meta.get("fixtures", [])
	if fixtures.is_empty():
		_register_prop_build_result_14d(znum, DaocPropBuilderScript.build(znum, [], {"mark_missing": false}))
		return
	var entries: Array = []
	for fx_raw in fixtures:
		var fx: Dictionary = fx_raw as Dictionary
		var wx: float = float(fx.get("x", 0.0))
		var wy: float = float(fx.get("y", 0.0))
		var h_units: float = float(fx.get("z", 0.0))
		if int(fx.get("ground", 0)) == 1 or h_units == 0.0:
			h_units = sample_daoc_floor_z(znum, wx, wy, 0.0)
		var p := base + Vector3(wx * world_scale,
			h_units * world_scale * height_exaggeration,
			wy * world_scale)
		var box := Node3D.new()
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 140.0 * world_scale
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.45, 0.15)
		mi.material_override = mat
		box.add_child(mi)
		var fixture_id := int(fx.get("id", 0))
		entries.append({
			"fixture_id": fixture_id,
			"nif_id": int(fx.get("nif", -1)),
			"file": "fixture_box",
			"template": box,
			"transform": Transform3D(Basis(), p),
			"marker_transform": Transform3D(Basis(), p),
			"position": p,
			"x": wx,
			"y": wy,
			"z": h_units,
			"a": float(fx.get("a", 0.0)),
			"scale": float(fx.get("scale", 1.0)),
			"ground": int(fx.get("ground", 0)),
			"node_name": "fixture_box_%d" % fixture_id,
			"source": "fallback_meta",
			"missing": false,
		})
	var result: RefCounted = DaocPropBuilderScript.build(znum, entries, {"mark_missing": false, "world_scale": world_scale})
	_register_prop_build_result_14d(znum, result)


func _register_prop_build_result_14d(znum: int, result: RefCounted) -> void:
	if result == null:
		_state_15e.prop_build_results.erase(znum)
		_state_15e.prop_nodes_by_zone[znum] = []
		_replace_prop_static_index_for_zone(znum, [])
		_ensure_prop_runtime_14d()
		return
	_state_15e.prop_build_results[znum] = result
	var result_root: Node3D = result.get("root") as Node3D
	if result_root != null:
		_zone_branch(znum, "StaticPropsRoot").add_child(result_root)
	_state_15e.prop_nodes_by_zone[znum] = result.get("prop_nodes") as Array
	_state_15e.prop_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_prop_static_index_for_zone(znum, result.get("static_index") as Array)
	_ensure_prop_runtime_14d()


func _ensure_prop_runtime_14d() -> void:
	if _state_15e.prop_runtime_obj == null:
		_state_15e.prop_runtime_obj = DaocPropRuntimeScript.new()
	_state_15e.prop_runtime_obj.call("bind", _state_15e.prop_static_index)


func _replace_prop_static_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.prop_static_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.prop_static_index = kept


func _missing_marker_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 200.0 * world_scale
	return box


# --- texture linking ---------------------------------------------------------
# The .glb carries each shape's source texture filename as the material name
# (set by the converter). We resolve that name to an actual image under
# texture_dirs (matched by stem, any of .dds/.tga/.png/.bmp), load it at runtime,
# and rebuild a StandardMaterial3D. Textures with an alpha channel -> alpha
# scissor + double-sided, which is what foliage cards need.

func _collision_root(znum: int) -> Node3D:
	return _zone_branch(znum, "CollisionRoot")


func _props_collision_root(znum: int) -> Node3D:
	var root := _collision_root(znum)
	var existing := root.get_node_or_null("PropsCollisionRoot")
	if existing != null and existing is Node3D:
		return existing as Node3D
	var n := Node3D.new()
	n.name = "PropsCollisionRoot"
	root.add_child(n)
	return n


func _ensure_collision_runtime_14c() -> void:
	if _state_15e.collision_runtime_obj == null:
		_state_15e.collision_runtime_obj = DaocCollisionRuntimeScript.new()
	_state_15e.collision_runtime_obj.call("bind_boundary", _state_15e.collision_static_boundary_index)
	_state_15e.collision_runtime_obj.call("bind_props", _state_15e.collision_static_prop_index)


func _setup_collision_boundary_builder_for_zone(znum: int, origin3: Vector3) -> void:
	# R4 tranche 4 : le nouveau chemin. Même constructeur 14C, même index de
	# frontières, même runtime ; seul le propriétaire de la plomberie a changé.
	if use_zone_build_steps:
		DaocZoneCollisionStep.build(zone_build_services_r4(), znum, origin3,
			zone_step_settings_r4("collisions"), zone_step_logging_r4("collisions"))
		return
	var path := _asset_zone_file_15d(znum, "bound.csv")
	if path == "":
		_state_15e.boundary_runtime[znum] = []
		_replace_collision_boundary_index_for_zone(znum, [])
		_ensure_collision_runtime_14c()
		if log_collision and (build_bound_collision or bound_collision_blocks_player):
			print("zone%03d bound: no bound.csv found" % znum)
		return
	var segments: Array = DaocCollisionBuilderScript.parse_bound_csv(path)
	var rt: Dictionary = _state_15e.zone_runtime.get(znum, {}) as Dictionary
	var settings := {
		"source_path": path,
		"build_bound_collision": build_bound_collision,
		"world_scale": world_scale,
		"height_exaggeration": height_exaggeration,
		"bound_collision_layer": bound_collision_layer,
		"bound_collision_mask": bound_collision_mask,
		"bound_collision_thickness_raw": bound_collision_thickness_raw,
		"bound_collision_bottom_offset_raw": bound_collision_bottom_offset_raw,
		"bound_collision_top_offset_raw": bound_collision_top_offset_raw,
		"bound_collision_debug_visible": bound_collision_debug_visible,
		"hb": rt.get("hb", PackedByteArray()),
		"res": int(rt.get("res", 0)),
	}
	var res: RefCounted = DaocCollisionBuilderScript.build_boundary(znum, segments, origin3, settings)
	if res == null:
		_state_15e.boundary_runtime[znum] = []
		_replace_collision_boundary_index_for_zone(znum, [])
		_ensure_collision_runtime_14c()
		return
	var root: Node3D = res.get("root") as Node3D
	if root != null and build_bound_collision:
		_collision_root(znum).add_child(root)
	_state_15e.boundary_build_results[znum] = res
	var static_index: Array = res.get("boundary_segments") as Array
	_state_15e.boundary_runtime[znum] = static_index.duplicate(true)
	_state_15e.collision_boundary_signature_by_zone[znum] = str(res.get("boundary_index_signature"))
	_replace_collision_boundary_index_for_zone(znum, static_index)
	_ensure_collision_runtime_14c()
	if log_collision:
		if build_bound_collision:
			print("zone%03d bound: %d collision segment(s) from %s [14C builder sig=%s]" % [znum, static_index.size(), path, str(res.get("boundary_index_signature"))])
		else:
			print("zone%03d bound: %d segment(s) registered for player solver only from %s [14C builder sig=%s]" % [znum, static_index.size(), path, str(res.get("boundary_index_signature"))])


func _replace_collision_boundary_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.collision_static_boundary_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.collision_static_boundary_index = kept


func _replace_collision_prop_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.collision_static_prop_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.collision_static_prop_index = kept


func _collision_prop_decision_14c(znum: int, fx: Dictionary, filename: String) -> Dictionary:
	var settings := _collision_prop_settings_14c()
	var table: Dictionary = _load_fixture_collide_table_14c(znum)
	return DaocCollisionBuilderScript.prop_collision_decision(fx, filename, table, settings)


func _collision_prop_settings_14c() -> Dictionary:
	return {
		"prop_collision_layer": prop_collision_layer,
		"prop_collision_mask": prop_collision_mask,
		"prop_collision_debug_visible": prop_collision_debug_visible,
		"prop_collision_size_scale_xz": prop_collision_size_scale_xz,
		"prop_collision_size_scale_y": prop_collision_size_scale_y,
		"prop_collision_excluded_name_tokens": prop_collision_excluded_name_tokens,
		"prop_collision_excluded_exact_names": prop_collision_excluded_exact_names,
		"prop_collision_fallback_when_flag_missing": prop_collision_fallback_when_flag_missing,
		"world_scale": world_scale,
		"height_exaggeration": height_exaggeration,
	}


func _load_fixture_collide_table_14c(znum: int) -> Dictionary:
	if _state_15e.fixture_collide_table_cache.has(znum):
		return _state_15e.fixture_collide_table_cache[znum] as Dictionary
	var out: Dictionary = {}
	var path := _asset_zone_file_15d(znum, "fixtures.csv")
	if path != "":
		out = DaocCollisionBuilderScript.parse_fixture_collide_table(path)
	_state_15e.fixture_collide_table_cache[znum] = out
	if log_collision and prop_collision_log_decisions and path != "":
		print("zone%03d fixtures.csv collide table: %d row(s) from %s" % [znum, out.size(), path])
	return out


func _setup_prop_collision_builder_body(znum: int, fx: Dictionary, filename: String, template_root: Node, pos: Vector3, yaw_rad: float, placed_scale: float) -> bool:
	var rt: Dictionary = _state_15e.zone_runtime.get(znum, {}) as Dictionary
	var origin3: Vector3 = rt.get("origin3", Vector3.ZERO) as Vector3
	var built: Dictionary = DaocCollisionBuilderScript.build_prop_aabb(znum, fx, filename, template_root, pos, yaw_rad, placed_scale, origin3, _collision_prop_settings_14c()) as Dictionary
	if not bool(built.get("ok", false)):
		return false
	var body: StaticBody3D = built.get("body", null) as StaticBody3D
	var runtime_item: Dictionary = built.get("runtime_item", {}) as Dictionary
	if body == null or runtime_item.is_empty():
		return false
	_props_collision_root(znum).add_child(body)
	if not _state_15e.prop_collision_runtime.has(znum):
		_state_15e.prop_collision_runtime[znum] = []
	(_state_15e.prop_collision_runtime[znum] as Array).append(runtime_item)
	_replace_collision_prop_index_for_zone(znum, _state_15e.prop_collision_runtime[znum] as Array)
	_state_15e.collision_prop_signature_by_zone[znum] = DaocCollisionBuilderScript.compute_prop_signature(_state_15e.prop_collision_runtime[znum] as Array)
	_ensure_collision_runtime_14c()
	return true


func solve_daoc_boundary_collision(znum: int, old_x: float, old_y: float,
		new_x: float, new_y: float, radius_raw: float = 40.0) -> Vector2:
	var newp := Vector2(new_x, new_y)
	if not bound_collision_blocks_player:
		return newp
	if _state_15e.collision_runtime_obj == null or not _state_15e.collision_runtime_obj.has_method("solve_boundary_collision"):
		return newp
	return _state_15e.collision_runtime_obj.call("solve_boundary_collision", znum, old_x, old_y, new_x, new_y, radius_raw) as Vector2


func solve_daoc_prop_collision(znum: int, old_x: float, old_y: float,
		new_x: float, new_y: float, daoc_z: float,
		radius_raw: float = 40.0, height_raw: float = 136.0) -> Vector2:
	var newp := Vector2(new_x, new_y)
	if not prop_collision_blocks_player or not generate_prop_collisions:
		return newp
	if _state_15e.collision_runtime_obj == null or not _state_15e.collision_runtime_obj.has_method("solve_prop_collision"):
		return newp
	return _state_15e.collision_runtime_obj.call("solve_prop_collision", znum, old_x, old_y, new_x, new_y, daoc_z, radius_raw, height_raw) as Vector2


func _collision_14c_is_prop_position_blocked(znum: int, p: Vector2, daoc_z: float, radius_raw: float, height_raw: float) -> bool:
	if _state_15e.collision_runtime_obj == null or not _state_15e.collision_runtime_obj.has_method("is_prop_position_blocked"):
		return false
	return bool(_state_15e.collision_runtime_obj.call("is_prop_position_blocked", znum, p, daoc_z, radius_raw, height_raw))

# --- DAoC zonejump.csv debug / non destructive -------------------------------

func _setup_zonejump_builder_for_zone(znum: int, origin3: Vector3) -> void:
	# R4 tranche 5 : le nouveau chemin. Même constructeur 14A, même index, même
	# runtime câblé ; seul le propriétaire de la plomberie a changé. Le garde
	# `build_zonejump_debug` descend DANS l'étape, car décoché il vide l'index.
	if use_zone_build_steps:
		DaocZoneJumpStep.build(zone_build_services_r4(), znum, origin3,
			zone_step_settings_r4("zonejumps"), zone_step_logging_r4("zonejumps"))
		return
	if not build_zonejump_debug:
		_state_15e.zonejump_entries_by_zone[znum] = []
		_replace_zonejump_static_index_for_zone(znum, [])
		_ensure_zonejump_runtime()
		_state_15e.zonejump_runtime.call("bind", _state_15e.zonejump_static_index)
		return
	var path := _asset_zone_file_15d(znum, "zonejump.csv")
	if path == "":
		_state_15e.zonejump_entries_by_zone[znum] = []
		_replace_zonejump_static_index_for_zone(znum, [])
		_ensure_zonejump_runtime()
		_state_15e.zonejump_runtime.call("bind", _state_15e.zonejump_static_index)
		if log_zonejump:
			print("zone%03d zonejump: no zonejump.csv found" % znum)
		return
	var entries: Array = _ensure_asset_index_registry_15d().call("parse_zonejump_csv", path) as Array
	if zonejump_optional_dedupe_pairs:
		entries = DaocZoneJumpBuilderScript.dedupe_reverse_pairs(entries)
	_state_15e.zonejump_entries_by_zone[znum] = entries

	var xform := DaocZoneJumpTransformContextScript.new()
	xform.call("setup", znum, origin3, world_scale, height_exaggeration, zonejump_thickness_raw, zonejump_debug_visible, zonejump_area_enabled)
	var result: RefCounted = DaocZoneJumpBuilderScript.build(znum, entries, xform)
	_state_15e.zonejump_build_results[znum] = result
	_state_15e.zonejump_areas_by_zone[znum] = result.get("areas")
	_state_15e.zonejump_index_signature_by_zone[znum] = str(result.get("index_signature"))
	_replace_zonejump_static_index_for_zone(znum, result.get("static_index") as Array)

	var root := _zone_branch(znum, "MechanicsDebugRoot")
	var result_root: Node3D = result.get("root") as Node3D
	if result_root != null:
		root.add_child(result_root)

	_ensure_zonejump_runtime()
	_state_15e.zonejump_runtime.call("bind", _state_15e.zonejump_static_index)
	var result_areas: Array = result.get("areas") as Array
	_state_15e.zonejump_runtime.call("wire", result_areas)
	if log_zonejump:
		var metrics: Dictionary = result.get("metrics") as Dictionary
		print("zone%03d zonejump: %d entry/entries (%d target(s)) from %s [14A builder areas=%d sig=%s]" % [
			znum,
			int(metrics.get("entries", entries.size())),
			int(metrics.get("targets", 0)),
			path,
			int(metrics.get("areas", 0)),
			str(result.get("index_signature")),
		])


func _ensure_zonejump_runtime() -> void:
	if _state_15e.zonejump_runtime != null:
		return
	_state_15e.zonejump_runtime = DaocZoneJumpRuntimeScript.new()
	var command_debug := _ensure_command_debug_surface_15f()
	_state_15e.zonejump_runtime.connect("zonejump_body_entered", Callable(command_debug, "on_zonejump_runtime_body_entered"))
	_state_15e.zonejump_runtime.connect("zonejump_body_exited", Callable(command_debug, "on_zonejump_runtime_body_exited"))


func _replace_zonejump_static_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.zonejump_static_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.zonejump_static_index = kept


func _ensure_command_debug_surface_15f() -> RefCounted:
	if _command_debug_surface_15f == null:
		_command_debug_surface_15f = DaocZoneViewerCommandDebugSurfaceScript.new()
	_command_debug_surface_15f.call("configure", self, _state_15e)
	return _command_debug_surface_15f


func get_zoneviewer_command_debug_15f_snapshot() -> Dictionary:
	var surface := _ensure_command_debug_surface_15f()
	if surface == null or not surface.has_method("debug_snapshot"):
		return {"scope": "P1-15F ZoneViewer command/debug surface extraction", "command_debug_surface_present": false}
	return surface.call("debug_snapshot") as Dictionary


func _ensure_local_viewer_bootstrap_15g() -> RefCounted:
	if _local_viewer_bootstrap_15g == null:
		_local_viewer_bootstrap_15g = DaocLocalViewerBootstrapScript.new()
	return _local_viewer_bootstrap_15g


func get_zoneviewer_bootstrap_15g_snapshot() -> Dictionary:
	var boot: RefCounted = _ensure_local_viewer_bootstrap_15g()
	var boot_snap: Dictionary = {}
	if boot != null and boot.has_method("status_snapshot"):
		boot_snap = boot.call("status_snapshot", self) as Dictionary
	var audit := get_zoneviewer_p1_15a_audit_snapshot() if has_method("get_zoneviewer_p1_15a_audit_snapshot") else {}
	var domains: Dictionary = audit.get("domains", {}) if audit is Dictionary else {}
	return {
		"scope": "P1-15G Viewer shell final / bootstrap cleanup",
		"checkpoint": "E_VIEWER_SHELL_BOOTSTRAP",
		"bootstrap_present": _local_viewer_bootstrap_15g != null,
		"bootstrap": boot_snap,
		"audit": audit,
		"line_count": int(audit.get("line_count", 0)) if audit is Dictionary else 0,
		"function_count": int(audit.get("function_count", 0)) if audit is Dictionary else 0,
		"export_count": int(audit.get("export_count", 0)) if audit is Dictionary else 0,
		"var_count": int(audit.get("var_count", 0)) if audit is Dictionary else 0,
		"preload_count": int(audit.get("preload_count", 0)) if audit is Dictionary else 0,
		"zonejump_runtime_debug_residue": int(domains.get("zonejump_runtime_debug", 999)),
		"asset_index_residue": int(domains.get("asset_model_texture_index", 999)),
		"vegetation_legacy_residue": int(domains.get("vegetation_legacy", 999)),
		"legacy_lights_residue": int(domains.get("legacy_lights", 999)),
		"recommended_next_step": "P1-15H ZoneViewer freeze audit / stop refactor",
	}


func get_zoneviewer_freeze_15h_snapshot() -> Dictionary:
	return DaocZoneViewerFreezeAuditScript.build_snapshot(self)


func set_zonejump_auto_transition_enabled(enabled: bool) -> Dictionary:
	return _ensure_command_debug_surface_15f().call("set_zonejump_auto_transition_enabled", enabled) as Dictionary


func execute_zonejump_nearest_transition(radius_raw: float = -1.0, reason: String = "command_nearest") -> Dictionary:
	return _ensure_command_debug_surface_15f().call("execute_zonejump_nearest_transition", radius_raw, reason) as Dictionary


func execute_zonejump_transition_by_id(jump_id: int, source_zone: int = -1, reason: String = "command_id") -> Dictionary:
	return _ensure_command_debug_surface_15f().call("execute_zonejump_transition_by_id", jump_id, source_zone, reason) as Dictionary


func execute_zonejump_transition_to_target(target: int, source_event: Dictionary, reason: String = "manual") -> Dictionary:
	return _ensure_command_debug_surface_15f().call("execute_zonejump_transition_to_target", target, source_event, reason) as Dictionary


func get_zonejump_transition_debug_snapshot() -> Dictionary:
	return _ensure_command_debug_surface_15f().call("get_zonejump_transition_debug_snapshot") as Dictionary


func get_zonejump_transition_lines(max_events: int = 4) -> PackedStringArray:
	return _ensure_command_debug_surface_15f().call("get_zonejump_transition_lines", max_events) as PackedStringArray


func get_zonejump_interaction_debug_snapshot() -> Dictionary:
	return _ensure_command_debug_surface_15f().call("get_zonejump_interaction_debug_snapshot") as Dictionary


func get_zonejump_status_lines(max_events: int = 4) -> PackedStringArray:
	return _ensure_command_debug_surface_15f().call("get_zonejump_status_lines", max_events) as PackedStringArray


func get_zonejump_last_event_lines() -> PackedStringArray:
	return _ensure_command_debug_surface_15f().call("get_zonejump_last_event_lines") as PackedStringArray


func get_zonejump_nearest_debug_snapshot(radius_raw: float = 1600.0) -> Dictionary:
	return _ensure_command_debug_surface_15f().call("get_zonejump_nearest_debug_snapshot", radius_raw) as Dictionary


## R4 — les services que le ZoneViewer expose aux étapes de zone.
##
## Fournis UNE FOIS, au lieu d'être rappelés à chaque étape. C'est la couture
## qui remplace les `host.callv` de `DaocZoneSceneAssembler`.
## R4 — la ligne d'état du HUD, alimentée par une étape au lieu d'un champ.
##
## `_hud_zones` reste un détail du banc : la vraie scène R6 n'aura pas le même
## affichage de diagnostic, mais elle fournira ce même service.
func hud_append_zone_fragment_r4(fragment: String) -> void:
	_hud_zones += fragment


func zone_build_services_r4() -> DaocZoneBuildServices:
	if _zone_build_services == null:
		_zone_build_services = DaocZoneBuildServices.create(self, _state_15e)
	return _zone_build_services


## Les réglages d'une étape de zone, rassemblés en DONNÉES.
##
## L'étape ne lit aucun `@export` : elle refuse d'inventer une valeur par défaut
## qui divergerait de celle du viewer, donc c'est le viewer qui les déclare.
## Une étape inconnue rend un dictionnaire vide plutôt qu'une erreur — les
## tranches R4 suivantes s'ajoutent ici, une à une.
func zone_step_settings_r4(step_name: String) -> Dictionary:
	match step_name:
		"water":
			return {
				"client_root": daoc_client_root,
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"water_alpha": water_alpha,
				"water_vertical_offset": water_vertical_offset,
				"water_tessellation_cap": water_tessellation_cap,
				"water_uv_world_scale": water_uv_world_scale,
				"use_legacy_water_color": use_legacy_water_color,
				"water_modern_texture_enabled": water_modern_texture_enabled,
				"water_shore_enabled": water_shore_enabled,
				"water_shore_strength": water_shore_strength,
			}
		# Lumières et végétation : les réglages sont déclarés ici pour être
		# LISIBLES par l'étape, mais `DaocLegacyVisuals` va encore les chercher
		# lui-même dans le viewer via `configure_from_host`. Tant que ce fil
		# n'est pas coupé, ces valeurs sont informatives et NE PILOTENT RIEN —
		# les dupliquer en pensant qu'elles agissent serait le piège.
		"lights":
			return {
				"visible": legacy_lights_visible,
				"cast_shadows": legacy_lights_cast_shadows,
				"show_markers": legacy_lights_show_markers,
				"preview_dark_scene": legacy_lights_preview_dark_scene,
				"authority": "DaocLegacyVisuals.configure_from_host",
			}
		"vegetation":
			return {
				"build_vegetation": build_vegetation,
				"render_mode": vegetation_render_mode,
				"authority": "DaocLegacyVisuals.configure_from_host",
			}
		# Terrain : contrairement aux lumières et à la végétation, ces réglages
		# PILOTENT réellement — l'étape les transmet au constructeur 14E, qui
		# n'a pas d'autre source. Les trois ressources « splat » n'y figurent
		# pas : elles vivent dans l'état de session, préparées par l'étape.
		"terrain":
			return {
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"build_terrain_collision": build_terrain_collision,
				"terrain_collision_layer": terrain_collision_layer,
				"terrain_collision_mask": terrain_collision_mask,
				"tile_scale": 1.0,
				"terrain_pbr": terrain_pbr_quality_options(),
				"terrain_visual_bilinear_subdivision": terrain_visual_bilinear_subdivision,
			}
		# Collisions : ces réglages pilotent aussi réellement. `hb` et `res` n'y
		# figurent pas — ce sont des données de zone, lues dans `zone_runtime`.
		"collisions":
			return {
				"build_bound_collision": build_bound_collision,
				"bound_collision_blocks_player": bound_collision_blocks_player,
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"bound_collision_layer": bound_collision_layer,
				"bound_collision_mask": bound_collision_mask,
				"bound_collision_thickness_raw": bound_collision_thickness_raw,
				"bound_collision_bottom_offset_raw": bound_collision_bottom_offset_raw,
				"bound_collision_top_offset_raw": bound_collision_top_offset_raw,
				"bound_collision_debug_visible": bound_collision_debug_visible,
			}
		# Zonejumps : `build_zonejump_debug` est un vrai garde, et il descend
		# DANS l'étape — décoché, il vide l'index au lieu de ne rien faire.
		"zonejumps":
			return {
				"build_zonejump_debug": build_zonejump_debug,
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"zonejump_thickness_raw": zonejump_thickness_raw,
				"zonejump_debug_visible": zonejump_debug_visible,
				"zonejump_area_enabled": zonejump_area_enabled,
				"zonejump_optional_dedupe_pairs": zonejump_optional_dedupe_pairs,
			}
		# Props : deux gardes vivent DANS l'étape, comme celui des zonejumps.
		# `place_real_models` décoché bascule sur les marqueurs au lieu de ne
		# rien faire, et `generate_prop_collisions` décoché place quand même les
		# props. Les remonter en garde d'entrée viderait la zone.
		"props":
			return {
				"place_real_models": place_real_models,
				"mark_missing": mark_missing,
				"world_scale": world_scale,
				"height_exaggeration": height_exaggeration,
				"anchor_to_base": anchor_to_base,
				"heading_sign": heading_sign,
				"heading_offset_deg": heading_offset_deg,
				"generate_prop_collisions": generate_prop_collisions,
				"prop_collision_log_decisions": prop_collision_log_decisions,
				"export_missing_models_csv": export_missing_models_csv,
				"brghouse_floor_anchor_offset_raw": brghouse_floor_anchor_offset_raw,
				# R10-HF2 — le vent atteint les arbres SpeedTree par ce chemin :
				# DaocPropBuilder transmet les reglages de props aux batches.
				"foliage_wind_enabled": foliage_wind_enabled,
				"foliage_canopy_strength_raw": foliage_canopy_strength_raw,
				"foliage_leaf_flutter_strength_raw": foliage_leaf_flutter_strength_raw,
				"foliage_wind_height_reference_raw": foliage_wind_height_reference_raw,
				"speedtree_enabled": speedtree_enabled,
				"speedtree_units_to_daoc": speedtree_units_to_daoc,
				"speedtree_visible_distance_raw": speedtree_visible_distance_raw,
			}
		_:
			return {}


## Une étape décochée dans l'inspecteur ne doit pas être lancée du tout.
func zone_step_enabled_r4(step_name: String) -> bool:
	match step_name:
		"water":
			return build_water
		_:
			return true


func zone_step_logging_r4(step_name: String) -> bool:
	match step_name:
		"water":
			return log_water
		"vegetation":
			return log_vegetation
		# Le relais d'origine tracait SANS condition : il n'existe pas de
		# `log_terrain`. En inventer un ici couperait une trace que quelqu'un
		# lit peut-etre — ce serait changer le comportement, pas le deplacer.
		"terrain":
			return true
		"collisions":
			return log_collision
		"zonejumps":
			return log_zonejump
		# Props : ce drapeau ne concerne QUE les lignes de collision de props.
		# La trace de placement est inconditionnelle depuis 14D, elle le reste.
		"props":
			return log_collision
		_:
			return false


## Vraie quand une étape a déjà basculé côté objet et que le drapeau est levé :
## l'assembleur peut alors la piloter sans rappeler le viewer.
func zone_step_migrated_r4(step_name: String) -> bool:
	return use_zone_build_steps and step_name in MIGRATED_ZONE_STEPS_R4


func _setup_water_builder_for_zone(znum: int, origin3: Vector3) -> void:
	if not build_water:
		return
	# R4 : le nouveau chemin. Même builder 14B, même résultat ; seul le
	# propriétaire de la plomberie a changé.
	if use_zone_build_steps:
		DaocZoneWaterStep.build(zone_build_services_r4(), znum, origin3,
			zone_step_settings_r4("water"), log_water)
		return
	var sector_path := _find_sector_dat(znum)
	if sector_path == "":
		if log_water:
			print("zone%03d water: no SECTOR.DAT found; expected zone%03d_sector.dat or raw dat%03d/SECTOR.DAT" % [znum, znum, znum])
		return
	var sector := _parse_sector_dat(sector_path)
	if sector.is_empty() or not sector.has("waterdefs"):
		return

	var settings := {
		"client_root": daoc_client_root,
		"world_scale": world_scale,
		"height_exaggeration": height_exaggeration,
		"water_alpha": water_alpha,
		"water_vertical_offset": water_vertical_offset,
		"water_tessellation_cap": water_tessellation_cap,
		"water_uv_world_scale": water_uv_world_scale,
		"use_legacy_water_color": use_legacy_water_color,
		"water_modern_texture_enabled": water_modern_texture_enabled,
		"water_shore_enabled": water_shore_enabled,
		"water_shore_strength": water_shore_strength,
		"sector_path": sector_path,
	}
	var res: RefCounted = DaocWaterBuilderScript.build(znum, sector, origin3, settings)
	if res == null:
		return
	var root: Node3D = res.get("root") as Node3D
	if root != null:
		_zone_branch(znum, "WaterRoot").add_child(root)

	_state_15e.water_build_results[znum] = res
	_state_15e.water_meshes_by_zone[znum] = res.get("meshes") as Array
	_state_15e.water_index_signature_by_zone[znum] = str(res.get("index_signature"))
	_replace_water_static_index_for_zone(znum, res.get("static_index") as Array)
	_state_15e.water_runtime[znum] = (res.get("static_index") as Array).duplicate(true)
	if _state_15e.water_runtime_obj == null:
		_state_15e.water_runtime_obj = DaocWaterRuntimeScript.new()
	_state_15e.water_runtime_obj.call("bind", _state_15e.water_static_index)

	if log_water:
		var metrics: Dictionary = res.get("metrics") as Dictionary
		print("zone%03d water: %d/%d body/bodies from %s [14B builder meshes=%d sig=%s]" % [
			znum,
			int(metrics.get("bodies", 0)),
			int(metrics.get("waterdefs", 0)),
			sector_path,
			int(metrics.get("meshes", 0)),
			str(res.get("index_signature")),
		])


func _replace_water_static_index_for_zone(znum: int, zone_index: Array) -> void:
	var kept: Array = []
	for item in _state_15e.water_static_index:
		var d: Dictionary = item as Dictionary
		if int(d.get("source_zone", d.get("zone", -1))) != znum:
			kept.append(d)
	for item in zone_index:
		kept.append(item)
	_state_15e.water_static_index = kept


## R6 — le corps de ces deux lectures vit maintenant dans `DaocSectorDat`, pour
## que la scène de jeu les partage au lieu d'en écrire une seconde version. Le
## banc garde les points d'entrée : `DaocZoneBuildServices` les adresse par nom.
func _find_sector_dat(znum: int) -> String:
	return DaocSectorDat.find_path(
		str(_ensure_asset_index_registry_15d().call("effective_data_dir")),
		str(_ensure_asset_index_registry_15d().call("effective_daoc_root")), znum)


func _parse_sector_dat(path: String) -> Dictionary:
	return DaocSectorDat.parse(path)





# --- DAoC zone vegetation ----------------------------------------------------
# Visual-only first pass. grassmap.pcx est une carte indexee/paletee et densemap
# n'est pas une autorite de vegetation fiable; Remaster peut preferer grassmapALT.
# This deliberately does not create gameplay nodes or per-grass objects.

# --- P1-15C-A legacy visuals wrapper ----------------------------------------
# Heavy legacy lights + vegetation implementation lives in DaocLegacyVisuals.
# ZoneViewer keeps only compatibility entry points for ZoneSceneAssembler.

func _ensure_visual_module_15c() -> RefCounted:
	if _legacy_visuals_obj == null:
		_legacy_visuals_obj = DaocLegacyVisualsScript.new()
	if _legacy_visuals_obj != null and _legacy_visuals_obj.has_method("configure_from_host"):
		_legacy_visuals_obj.call("configure_from_host", self)
	return _legacy_visuals_obj


func _setup_visual_stage_lamps_15c(znum: int, origin3: Vector3) -> void:
	if use_zone_build_steps:
		DaocZoneLightsStep.build(zone_build_services_r4(), znum, origin3,
			zone_step_settings_r4("lights"), zone_step_logging_r4("lights"))
		return
	var visuals := _ensure_visual_module_15c()
	if visuals != null and visuals.has_method("build_zone_lights"):
		visuals.call("build_zone_lights", znum, origin3)


func _setup_visual_stage_cards_15c(znum: int, origin3: Vector3, hb: PackedByteArray, res: int) -> void:
	if use_zone_build_steps:
		DaocZoneVegetationStep.build(zone_build_services_r4(), znum, origin3, hb, res,
			zone_step_settings_r4("vegetation"), zone_step_logging_r4("vegetation"))
		return
	var visuals := _ensure_visual_module_15c()
	if visuals != null and visuals.has_method("build_zone_vegetation"):
		visuals.call("build_zone_vegetation", znum, origin3, hb, res)


func _apply_visual_stage_lamps_15c() -> void:
	var visuals := _ensure_visual_module_15c()
	if visuals != null and visuals.has_method("apply_legacy_light_runtime_settings"):
		visuals.call("apply_legacy_light_runtime_settings")


func _apply_visual_stage_cards_15c() -> void:
	var visuals := _ensure_visual_module_15c()
	if visuals != null and visuals.has_method("apply_vegetation_runtime_settings"):
		visuals.call("apply_vegetation_runtime_settings")


func get_zoneviewer_mass_reduction_15c_snapshot() -> Dictionary:
	var audit := get_zoneviewer_p1_15a_audit_snapshot() if has_method("get_zoneviewer_p1_15a_audit_snapshot") else {}
	var domains: Dictionary = audit.get("domains", {}) if audit is Dictionary else {}
	return {
		"scope": "P1-15C ZoneViewer mass reduction A legacy visuals",
		"checkpoint": "A_LEGACY_VISUALS_PLUS_B_ASSET_INDEX",
		"legacy_visuals_present": _legacy_visuals_obj != null,
		"audit": audit,
		"line_count": int(audit.get("line_count", 0)),
		"function_count": int(audit.get("function_count", 0)),
		"export_count": int(audit.get("export_count", 0)),
		"var_count": int(audit.get("var_count", 0)),
		"preload_count": int(audit.get("preload_count", 0)),
		"vegetation_legacy_residue": int(domains.get("vegetation_legacy", 0)),
		"legacy_lights_residue": int(domains.get("legacy_lights", 0)),
		"asset_index_residue": int(domains.get("asset_model_texture_index", 0)),
		"zonejump_runtime_debug_residue": int(domains.get("zonejump_runtime_debug", 0)),
		"zonejump_runtime_debug_verdict": "CONFORME: surface de commandes/debug dans ZoneViewer, runtime vivant délégué à DaocZoneJumpRuntime",
		"visual_groups": {
			"lights": get_tree().get_nodes_in_group("daoc_legacy_light").size() if get_tree() != null else 0,
			"vegetation_roots": get_tree().get_nodes_in_group("daoc_vegetation_root").size() if get_tree() != null else 0,
			"vegetation_batches": get_tree().get_nodes_in_group("daoc_vegetation").size() if get_tree() != null else 0,
		},
		"before_reference": {
			"lines": 3901,
			"functions": 167,
			"exports": 152,
			"var_count": 710,
			"preload_count": 30,
			"asset_model_texture_index": 29,
			"vegetation_legacy": 18,
			"legacy_lights": 8,
			"zonejump_runtime_debug": 34,
		},
		"b_done": true,
		"c_done": false,
		"asset_registry": get_asset_index_registry_15d_debug_snapshot(),
		"recommended_next_step": "P1-15E State grouping / residual state reduction",
	}


func get_zoneviewer_mass_reduction_15d_snapshot() -> Dictionary:
	var audit := get_zoneviewer_p1_15a_audit_snapshot() if has_method("get_zoneviewer_p1_15a_audit_snapshot") else {}
	var domains: Dictionary = audit.get("domains", {}) if audit is Dictionary else {}
	var reg := get_asset_index_registry_15d_debug_snapshot()
	return {
		"scope": "P1-15D AssetIndexRegistry foundation",
		"checkpoint": "B_ASSET_INDEX_REGISTRY",
		"asset_registry_present": _asset_index_registry_obj != null,
		"asset_registry": reg,
		"audit": audit,
		"line_count": int(audit.get("line_count", 0)),
		"function_count": int(audit.get("function_count", 0)),
		"export_count": int(audit.get("export_count", 0)),
		"var_count": int(audit.get("var_count", 0)),
		"preload_count": int(audit.get("preload_count", 0)),
		"asset_index_residue": int(domains.get("asset_model_texture_index", 0)),
		"vegetation_legacy_residue": int(domains.get("vegetation_legacy", 0)),
		"legacy_lights_residue": int(domains.get("legacy_lights", 0)),
		"zonejump_runtime_debug_residue": int(domains.get("zonejump_runtime_debug", 0)),
		"before_reference": {
			"lines": 3901,
			"functions": 167,
			"exports": 152,
			"var_count": 710,
			"preload_count": 30,
			"asset_model_texture_index": 29,
			"vegetation_legacy": 18,
			"legacy_lights": 8,
			"zonejump_runtime_debug": 34,
		},
		"after_15c_reference": {
			"lines": 3166,
			"functions": 144,
			"exports": 152,
			"var_count": 506,
			"preload_count": 31,
			"asset_model_texture_index": 29,
			"vegetation_legacy": 0,
			"legacy_lights": 0,
			"zonejump_runtime_debug": 34,
		},
		"b_done": true,
		"c_done": false,
		"recommended_next_step": "P1-15E State grouping / residual state reduction",
	}


# Original lightweight markers, kept as a fallback when no placement file exists.

func _resolve_player_start(znum: int) -> Dictionary:
	var sx := player_start_x
	var sy := player_start_y
	var sz := player_start_z
	var heading := player_start_heading_deg
	var source := "manual"

	# Important pour le viewer : par défaut, ne pas utiliser automatiquement
	# SECTOR.DAT [start]. Ces points sont utiles pour le client 1:1, mais certains
	# tombent sur des volumes de transition/limite. Avec bound.csv bloquant, ça
	# peut coincer la capsule dès la première frame.
	if player_use_sector_start:
		var sector_path := _find_sector_dat(znum)
		if sector_path != "":
			var sector := _parse_sector_dat(sector_path)
			if sector.has("start"):
				var st: Dictionary = sector["start"] as Dictionary
				if sx < 0.0 and st.has("x"):
					sx = float(str(st.get("x", "32768")))
					source = "sector"
				if sy < 0.0 and st.has("y"):
					sy = float(str(st.get("y", "32768")))
					source = "sector"
				if sz < 0.0 and st.has("z"):
					sz = float(str(st.get("z", "0")))
				if heading == 0.0:
					if st.has("a"):
						heading = float(str(st.get("a", "0")))
					elif st.has("angle"):
						heading = float(str(st.get("angle", "0")))

	if sx < 0.0:
		sx = 32768.0
		source = "center"
	if sy < 0.0:
		sy = 32768.0
		source = "center"

	var p := Vector2(clampf(sx, 0.0, 65536.0), clampf(sy, 0.0, 65536.0))
	if player_start_avoid_bound_collision:
		p = _find_safe_player_start_2d(znum, p, maxf(player_start_bound_clearance_raw, 1.0))
		sx = p.x
		sy = p.y

	# Si le start secteur a donné un Z explicite mais que le point XY a été déplacé
	# pour éviter bound.csv, on recolle au terrain.
	if sz < 0.0 or source == "center":
		sz = sample_daoc_floor_z(znum, sx, sy, 0.0)
	elif player_start_avoid_bound_collision:
		sz = sample_daoc_floor_z(znum, sx, sy, 0.0)

	return {"pos": Vector3(sx, sy, sz), "heading": heading, "source": source}


func _find_safe_player_start_2d(znum: int, requested: Vector2, clearance_raw: float) -> Vector2:
	if not bound_collision_blocks_player:
		return requested
	var segments: Array = _state_15e.boundary_runtime.get(znum, [])
	if segments.is_empty():
		return requested
	if not _point_near_boundary_2d(znum, requested, clearance_raw):
		return requested

	# Priorité volontaire : centre de zone pour le viewer. Si lui-même tombe trop
	# près d'un segment, on cherche autour sur une grille grossière.
	var candidates: Array[Vector2] = [Vector2(32768.0, 32768.0)]
	var steps := [4096.0, 8192.0, 12288.0, 16384.0, 20480.0, 24576.0]
	for r in steps:
		for dx in [-r, 0.0, r]:
			for dy in [-r, 0.0, r]:
				if dx == 0.0 and dy == 0.0:
					continue
				candidates.append(Vector2(32768.0 + dx, 32768.0 + dy))

	var best := requested
	var best_score := INF
	for c in candidates:
		if c.x < 256.0 or c.y < 256.0 or c.x > 65280.0 or c.y > 65280.0:
			continue
		if _point_near_boundary_2d(znum, c, clearance_raw):
			continue
		var score := c.distance_squared_to(Vector2(32768.0, 32768.0))
		if score < best_score:
			best_score = score
			best = c

	return best


func _point_near_boundary_2d(znum: int, p: Vector2, clearance_raw: float) -> bool:
	if _state_15e.collision_runtime_obj != null and _state_15e.collision_runtime_obj.has_method("point_near_boundary_2d"):
		return bool(_state_15e.collision_runtime_obj.call("point_near_boundary_2d", znum, p, clearance_raw))
	var segments: Array = _state_15e.boundary_runtime.get(znum, [])
	for seg_var in segments:
		var seg: Dictionary = seg_var as Dictionary
		var a: Vector2 = seg.get("a", Vector2.ZERO) as Vector2
		var b: Vector2 = seg.get("b", Vector2.ZERO) as Vector2
		if _distance_to_segment_2d(p, a, b) < clearance_raw:
			return true
	return false

func get_zonejump_14a_debug_snapshot() -> Dictionary:
	var runtime_status: Dictionary = {}
	if _state_15e.zonejump_runtime != null and _state_15e.zonejump_runtime.has_method("status"):
		runtime_status = _state_15e.zonejump_runtime.call("status") as Dictionary
	var packed_ok := false
	var zone0_metrics: Dictionary = {}
	var zone0_signature := ""
	var zone0_index: Array = []
	var zone0_result: RefCounted = _state_15e.zonejump_build_results.get(0, null) as RefCounted
	if zone0_result != null:
		zone0_metrics = zone0_result.get("metrics") as Dictionary
		zone0_signature = str(zone0_result.get("index_signature"))
		zone0_index = zone0_result.get("static_index") as Array
		packed_ok = bool(zone0_metrics.get("packable_ok", false))
	return {
		"scope": "P1-14A ZoneJumpBuilder foundation",
		"builder_present": DaocZoneJumpBuilderScript != null,
		"runtime_present": _state_15e.zonejump_runtime != null,
		"build_result_present": zone0_result != null,
		"zone0_metrics": zone0_metrics,
		"zone0_index_signature": zone0_signature,
		"zone0_index_size": zone0_index.size(),
		"packed_scene_ok": packed_ok,
		"static_index_total": _state_15e.zonejump_static_index.size(),
		"entries_by_zone": _state_15e.zonejump_entries_by_zone.keys(),
		"areas_by_zone": _state_15e.zonejump_areas_by_zone.keys(),
		"runtime_status": runtime_status,
	}


func zonejump_14a_simulate_first_body_entered() -> Dictionary:
	if _state_15e.zonejump_runtime == null:
		return {"ok": false, "reason": "runtime missing"}
	var area: Area3D = null
	var zone_keys: Array = _state_15e.zonejump_areas_by_zone.keys()
	zone_keys.sort()
	for z in zone_keys:
		var arr: Array = _state_15e.zonejump_areas_by_zone.get(z, []) as Array
		if arr.size() > 0:
			area = arr[0] as Area3D
			break
	if area == null:
		return {"ok": false, "reason": "no zonejump area"}
	var fake_body := Node3D.new()
	area.emit_signal("body_entered", fake_body)
	fake_body.free()
	var last: Dictionary = _state_15e.zonejump_runtime.call("get_last_triggered") as Dictionary
	return {
		"ok": bool(last.get("ok", false)),
		"area_id": str(last.get("area_id", "")),
		"id": int(last.get("id", -1)),
		"zone": int(last.get("source_zone", last.get("zone", -1))),
		"target": int(last.get("target_zone", last.get("target", -1))),
		"last": last,
	}


func get_zonejump_debug_snapshot() -> Dictionary:
	var total := 0
	var targets := 0
	for z in _state_15e.zonejump_entries_by_zone.keys():
		var entries: Array = _state_15e.zonejump_entries_by_zone.get(z, []) as Array
		total += entries.size()
		for e in entries:
			var d: Dictionary = e as Dictionary
			if int(d.get("target", -1)) >= 0:
				targets += 1
	return {
		"enabled": build_zonejump_debug,
		"area_enabled": zonejump_area_enabled,
		"zones": _state_15e.zonejump_entries_by_zone.keys(),
		"entries_total": total,
		"targets_total": targets,
		"last": _state_15e.last_zonejump_debug,
		"event_log_size": _state_15e.zonejump_event_log.size(),
		"event_log_tail": _state_15e.zonejump_event_log.slice(maxi(0, _state_15e.zonejump_event_log.size() - 6), _state_15e.zonejump_event_log.size()),
		"p1_n6f": get_zonejump_interaction_debug_snapshot(),
		"p1_n6g": get_zonejump_transition_debug_snapshot(),
		"p1_14a": get_zonejump_14a_debug_snapshot(),
	}



func get_terrain_14e_debug_snapshot() -> Dictionary:
	var runtime_status: Dictionary = {}
	if _state_15e.terrain_runtime_obj != null and _state_15e.terrain_runtime_obj.has_method("status"):
		runtime_status = _state_15e.terrain_runtime_obj.call("status") as Dictionary
	var zone0_result: RefCounted = _state_15e.terrain_build_results.get(0, null) as RefCounted
	var metrics: Dictionary = {}
	var signature := ""
	var packed_ok := false
	var index_size := 0
	var mesh_count := 0
	var collision_count := 0
	if zone0_result != null:
		metrics = zone0_result.get("metrics") as Dictionary
		signature = str(zone0_result.get("index_signature"))
		index_size = (zone0_result.get("static_index") as Array).size()
		mesh_count = (zone0_result.get("terrain_meshes") as Array).size()
		collision_count = (zone0_result.get("collision_bodies") as Array).size()
		packed_ok = bool(metrics.get("packable_ok", false))
	return {
		"scope": "P1-14E TerrainBuilder foundation",
		"builder_present": DaocTerrainBuilderScript != null,
		"runtime_present": _state_15e.terrain_runtime_obj != null,
		"build_result_present": zone0_result != null,
		"zone0_metrics": metrics,
		"zone0_index_signature": signature,
		"zone0_index_size": index_size,
		"zone0_meshes": mesh_count,
		"zone0_collision_bodies": collision_count,
		"packed_scene_ok": packed_ok,
		"static_index_total": _state_15e.terrain_static_index.size(),
		"entries_by_zone": _state_15e.terrain_build_results.keys(),
		"meshes_by_zone": _state_15e.terrain_meshes_by_zone.keys(),
		"collision_bodies_by_zone": _state_15e.terrain_collision_bodies_by_zone.keys(),
		"runtime_status": runtime_status,
	}


func get_prop_14d_debug_snapshot() -> Dictionary:
	var zone0_result: RefCounted = _state_15e.prop_build_results.get(0, null) as RefCounted
	var metrics: Dictionary = {}
	var signature := ""
	var packed_ok := false
	var index_size := 0
	var nodes_size := 0
	if zone0_result != null:
		metrics = zone0_result.get("metrics") as Dictionary
		signature = str(zone0_result.get("index_signature"))
		index_size = (zone0_result.get("static_index") as Array).size()
		nodes_size = (zone0_result.get("prop_nodes") as Array).size()
		packed_ok = bool(metrics.get("packable_ok", false))
	return {
		"scope": "P1-14D PropBuilder foundation",
		"builder_present": DaocPropBuilderScript != null,
		"runtime_present": _state_15e.prop_runtime_obj != null,
		"build_result_present": zone0_result != null,
		"zone0_metrics": metrics,
		"zone0_index_signature": signature,
		"zone0_index_size": index_size,
		"zone0_nodes": nodes_size,
		"packed_scene_ok": packed_ok,
		"static_index_total": _state_15e.prop_static_index.size(),
		"entries_by_zone": _state_15e.prop_build_results.keys(),
		"nodes_by_zone": _state_15e.prop_nodes_by_zone.keys(),
		"runtime_status": _state_15e.prop_runtime_obj.call("status") if _state_15e.prop_runtime_obj != null and _state_15e.prop_runtime_obj.has_method("status") else {},
	}

func get_collision_debug_snapshot() -> Dictionary:
	var boundary_total := 0
	for z in _state_15e.boundary_runtime.keys():
		boundary_total += (_state_15e.boundary_runtime.get(z, []) as Array).size()
	var prop_total := 0
	for z in _state_15e.prop_collision_runtime.keys():
		prop_total += (_state_15e.prop_collision_runtime.get(z, []) as Array).size()
	return {
		"terrain_collision": build_terrain_collision,
		"bound_collision": build_bound_collision,
		"bound_blocks_player": bound_collision_blocks_player,
		"boundary_segments_total": boundary_total,
		"prop_collision": generate_prop_collisions,
		"prop_blocks_player": prop_collision_blocks_player,
		"prop_bodies_total": prop_total,
		"prop_excluded_tokens": prop_collision_excluded_name_tokens.size(),
		"prop_excluded_exact": prop_collision_excluded_exact_names.size(),
	}


func get_collision_14c_debug_snapshot() -> Dictionary:
	var runtime_status: Dictionary = {}
	if _state_15e.collision_runtime_obj != null and _state_15e.collision_runtime_obj.has_method("status"):
		runtime_status = _state_15e.collision_runtime_obj.call("status") as Dictionary
	var packed_ok := false
	var zone0_metrics: Dictionary = {}
	var zone0_boundary_sig := ""
	var zone0_prop_sig := ""
	var zone0_boundary_count := 0
	var zone0_prop_count := 0
	if _state_15e.boundary_build_results.has(0):
		var res: RefCounted = _state_15e.boundary_build_results.get(0, null) as RefCounted
		if res != null:
			zone0_metrics = res.get("metrics") as Dictionary
			zone0_boundary_sig = str(res.get("boundary_index_signature"))
			zone0_boundary_count = (res.get("boundary_segments") as Array).size()
			var root: Node3D = res.get("root") as Node3D
			if root != null:
				var pack_probe := PackedScene.new()
				packed_ok = pack_probe.pack(root) == OK
	zone0_prop_count = (_state_15e.prop_collision_runtime.get(0, []) as Array).size()
	zone0_prop_sig = str(_state_15e.collision_prop_signature_by_zone.get(0, ""))
	return {
		"scope": "P1-14C CollisionBuilder foundation",
		"builder_present": DaocCollisionBuilderScript != null,
		"runtime_present": _state_15e.collision_runtime_obj != null,
		"build_result_present": _state_15e.boundary_build_results.has(0),
		"zone0_metrics": zone0_metrics,
		"zone0_boundary_signature": zone0_boundary_sig,
		"zone0_prop_signature": zone0_prop_sig,
		"zone0_boundary_count": zone0_boundary_count,
		"zone0_prop_count": zone0_prop_count,
		"packed_scene_ok": packed_ok,
		"static_boundary_index_total": _state_15e.collision_static_boundary_index.size(),
		"static_prop_index_total": _state_15e.collision_static_prop_index.size(),
		"boundary_zones": _state_15e.boundary_runtime.keys(),
		"prop_zones": _state_15e.prop_collision_runtime.keys(),
		"runtime_status": runtime_status,
	}


func get_water_debug_snapshot() -> Dictionary:
	var total := 0
	for z in _state_15e.water_runtime.keys():
		total += (_state_15e.water_runtime.get(z, []) as Array).size()
	var player_info := {}
	if _player != null:
		player_info = sample_daoc_water_info(int(_player.get("daoc_zone")), float(_player.get("daoc_x")), float(_player.get("daoc_y")), float(_player.get("daoc_z")))
	var runtime_status: Dictionary = {}
	if _state_15e.water_runtime_obj != null and _state_15e.water_runtime_obj.has_method("status"):
		runtime_status = _state_15e.water_runtime_obj.call("status") as Dictionary
	return {
		"build_water": build_water,
		"water_bodies_total": total,
		"zones": _state_15e.water_runtime.keys(),
		"player_water_info": player_info,
		"water_fx": get_daoc_water_fx_debug_snapshot(),
		"p1_14b": get_water_14b_debug_snapshot(),
		"runtime_status": runtime_status,
	}


func get_water_14b_debug_snapshot() -> Dictionary:
	var runtime_status: Dictionary = {}
	if _state_15e.water_runtime_obj != null and _state_15e.water_runtime_obj.has_method("status"):
		runtime_status = _state_15e.water_runtime_obj.call("status") as Dictionary
	var packed_ok := false
	var zone0_metrics: Dictionary = {}
	var zone0_signature := ""
	var zone0_index_size := 0
	var zone0_meshes := 0
	if _state_15e.water_build_results.has(0):
		var res: RefCounted = _state_15e.water_build_results.get(0, null) as RefCounted
		if res != null:
			zone0_metrics = res.get("metrics") as Dictionary
			zone0_signature = str(res.get("index_signature"))
			zone0_index_size = (res.get("static_index") as Array).size()
			zone0_meshes = (res.get("meshes") as Array).size()
			var root: Node3D = res.get("root") as Node3D
			if root != null:
				var pack_probe := PackedScene.new()
				packed_ok = pack_probe.pack(root) == OK
	return {
		"scope": "P1-14B WaterBuilder foundation",
		"builder_present": DaocWaterBuilderScript != null,
		"runtime_present": _state_15e.water_runtime_obj != null,
		"build_result_present": _state_15e.water_build_results.has(0),
		"zone0_metrics": zone0_metrics,
		"zone0_index_signature": zone0_signature,
		"zone0_index_size": zone0_index_size,
		"zone0_meshes": zone0_meshes,
		"packed_scene_ok": packed_ok,
		"static_index_total": _state_15e.water_static_index.size(),
		"entries_by_zone": _state_15e.water_runtime.keys(),
		"meshes_by_zone": _state_15e.water_meshes_by_zone.keys(),
		"runtime_status": runtime_status,
	}


func get_zoneviewer_p1_15a_audit_snapshot() -> Dictionary:
	return DaocZoneViewerPostBuildersAuditScript.build_snapshot(self)



func get_opendaoc_db_core_candidate_paths() -> Array:
	var out: Array = []
	_opendaoc_db_append_unique_path(out, str(opendaoc_db_core_dir).strip_edges())
	_opendaoc_db_append_unique_path(out, str(opendaoc_db_core_project_fallback_dir).strip_edges())
	_opendaoc_db_append_unique_path(out, "res://data/server_dumps/opendaoc/opendaoc-db-core")
	_opendaoc_db_append_unique_path(out, "res://data/server_instruction_db/opendaoc-db-core")
	_opendaoc_db_append_unique_path(out, "res://opendaoc-db-core")
	return out


func get_opendaoc_db_core_debug_snapshot() -> Dictionary:
	var candidates: Array = get_opendaoc_db_core_candidate_paths()
	return {
		"scope": "P1-17E2G viewer persistent OpenDAoC DB path",
		"checkpoint": "P1_17E2G_VIEWER_OPENDAOC_DB_PATH",
		"abstract_only": true,
		"runtime_enabled": false,
		"coordinate_frame_confirmed": false,
		"configured_path": str(opendaoc_db_core_dir).strip_edges(),
		"project_fallback_path": str(opendaoc_db_core_project_fallback_dir).strip_edges(),
		"candidate_paths": candidates,
		"candidate_count": candidates.size(),
		"has_manual_path": str(opendaoc_db_core_dir).strip_edges() != "",
	}


func _opendaoc_db_append_unique_path(out: Array, value: String) -> void:
	var path: String = value.strip_edges()
	if path == "":
		return
	if not out.has(path):
		out.append(path)

func get_local_client_debug_snapshot() -> Dictionary:
	return {
		"opendaoc_db_core": get_opendaoc_db_core_debug_snapshot(),
		"zonejump": get_zonejump_debug_snapshot(),
		"terrain_14e": get_terrain_14e_debug_snapshot(),
		"collision": get_collision_debug_snapshot(),
		"collision_14c": get_collision_14c_debug_snapshot(),
		"prop_14d": get_prop_14d_debug_snapshot(),
		"water": get_water_debug_snapshot(),
		"water_14b": get_water_14b_debug_snapshot(),
		"mass_reduction_15c": get_zoneviewer_mass_reduction_15c_snapshot(),
		"bootstrap_15g": get_zoneviewer_bootstrap_15g_snapshot(),
		"dol": get_dol_debug_snapshot(),
		"dol_transport": get_dol_transport_debug_snapshot(),
		"dol_packet_layer": get_dol_packet_layer_debug_snapshot(),
		"dol_wire_1127": get_dol_wire_1127_debug_snapshot(),
		"dol_login_flow_1127": get_dol_login_flow_1127_debug_snapshot(),
		"dol_server_fixtures_1127": get_dol_server_fixtures_1127_debug_snapshot(),
		"dol_character_bootstrap_1127": get_dol_character_bootstrap_1127_debug_snapshot(),
		"dol_character_select_hud_1127": get_dol_character_select_hud_1127_debug_snapshot(),
		"pregame_loading_asset_resolver": get_pregame_loading_asset_resolver_debug_snapshot(),
		"has_dev_hud": _dev_hud != null,
		"has_local_targeting": _local_targeting != null,
		"has_dol_client": _dol_client != null,
		"has_dol_transport": _dol_transport != null,
		"has_dol_packet_layer": _dol_packet_layer != null,
		"has_dol_wire_1127": _dol_wire_1127 != null,
		"has_dol_login_flow_1127": _dol_login_flow_1127 != null,
		"has_dol_server_fixtures_1127": _dol_server_fixtures_1127 != null,
		"has_dol_character_bootstrap_1127": _dol_character_bootstrap_1127 != null,
		"has_dol_character_select_hud_1127": _dol_character_select_hud_1127 != null,
		"has_pregame_loading_asset_resolver": _daoc_pregame_loading_asset_resolver != null,
	}



func get_dol_login_flow_1127_debug_snapshot() -> Dictionary:
	if _dol_login_flow_1127 != null and _dol_login_flow_1127.has_method("status_snapshot"):
		return _dol_login_flow_1127.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N5B DOL login flow 1127 offline", "status_name": "MISSING"}


func get_dol_server_fixtures_1127_debug_snapshot() -> Dictionary:
	if _dol_server_fixtures_1127 != null and _dol_server_fixtures_1127.has_method("status_snapshot"):
		return _dol_server_fixtures_1127.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N5D DOL server response fixtures offline", "status_name": "MISSING"}


func get_dol_character_bootstrap_1127_debug_snapshot() -> Dictionary:
	if _dol_character_bootstrap_1127 != null and _dol_character_bootstrap_1127.has_method("status_snapshot"):
		return _dol_character_bootstrap_1127.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N5E/F/G character overview/select/bootstrap offline", "status_name": "MISSING"}


func get_dol_character_select_hud_1127_debug_snapshot() -> Dictionary:
	if _dol_character_select_hud_1127 != null and _dol_character_select_hud_1127.has_method("status_snapshot"):
		return _dol_character_select_hud_1127.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N5H character select text HUD offline", "status_name": "MISSING"}


func get_pregame_loading_asset_resolver_debug_snapshot() -> Dictionary:
	if _daoc_pregame_loading_asset_resolver != null and _daoc_pregame_loading_asset_resolver.has_method("status_snapshot"):
		return _daoc_pregame_loading_asset_resolver.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N6D pregame/loading asset resolver offline", "status_name": "MISSING"}

func get_dol_debug_snapshot() -> Dictionary:
	if _dol_client != null and _dol_client.has_method("get_network_debug_snapshot"):
		return _dol_client.call("get_network_debug_snapshot") as Dictionary
	return {"enabled": false, "state_name": "MISSING"}


func get_dol_transport_debug_snapshot() -> Dictionary:
	if _dol_transport != null and _dol_transport.has_method("get_transport_debug_snapshot"):
		return _dol_transport.call("get_transport_debug_snapshot") as Dictionary
	return {"enabled": false, "status_name": "MISSING"}


func get_dol_packet_layer_debug_snapshot() -> Dictionary:
	if _dol_packet_layer != null and _dol_packet_layer.has_method("status_snapshot"):
		return _dol_packet_layer.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N4 packet/framing preparatoire", "status_name": "MISSING"}

func get_dol_wire_1127_debug_snapshot() -> Dictionary:
	if _dol_wire_1127 != null and _dol_wire_1127.has_method("status_snapshot"):
		return _dol_wire_1127.call("status_snapshot") as Dictionary
	return {"enabled": false, "scope": "P1-N5A DOL wire 1127 offline", "status_name": "MISSING"}


func daoc_to_godot(znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Vector3:
	if has_generated_dungeon_runtime_zone_17d(znum):
		var bridge: RefCounted = _ensure_generated_dungeon_runtime_bridge_17d()
		if bridge != null and bridge.has_method("daoc_to_godot"):
			return bridge.call("daoc_to_godot", znum, daoc_x, daoc_y, daoc_z) as Vector3
	var rt: Dictionary = _state_15e.zone_runtime.get(znum, {}) as Dictionary
	var origin3: Vector3 = rt.get("origin3", Vector3.ZERO) as Vector3
	return origin3 + Vector3(
		daoc_x * world_scale,
		daoc_z * world_scale * height_exaggeration,
		daoc_y * world_scale
	)


func sample_daoc_floor_z(znum: int, daoc_x: float, daoc_y: float, daoc_z: float = 0.0) -> float:
	if has_generated_dungeon_runtime_zone_17d(znum):
		var bridge: RefCounted = _ensure_generated_dungeon_runtime_bridge_17d()
		if bridge != null and bridge.has_method("sample_floor_daoc"):
			return float(bridge.call("sample_floor_daoc", znum, daoc_x, daoc_y, daoc_z))
	if _state_15e.terrain_runtime_obj != null and _state_15e.terrain_runtime_obj.has_method("sample_floor"):
		return float(_state_15e.terrain_runtime_obj.call("sample_floor", znum, daoc_x, daoc_y, daoc_z))
	var rt: Dictionary = _state_15e.zone_runtime.get(znum, {}) as Dictionary
	if rt.is_empty():
		return 0.0
	return DaocTerrainRuntimeScript._sample_height(rt["hb"], int(rt["res"]), daoc_x, daoc_y)


func sample_daoc_water_info(znum: int, daoc_x: float, daoc_y: float, daoc_z: float) -> Dictionary:
	if has_generated_dungeon_runtime_zone_17d(znum):
		return {}
	if _state_15e.water_runtime_obj == null or not _state_15e.water_runtime_obj.has_method("sample_daoc"):
		return {}
	var floor_z := sample_daoc_floor_z(znum, daoc_x, daoc_y, daoc_z)
	return _state_15e.water_runtime_obj.call("sample_daoc", znum, daoc_x, daoc_y, daoc_z, floor_z) as Dictionary


func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ============================================================================
# Step 2 — per-pixel terrain splatting (shader). No baking: the shader samples
# the original ter masks + Terrain Tex details live, at the real tiling rate.
# One mesh + ShaderMaterial per 8x8 patch (sector); two shared Texture2DArrays.
# ============================================================================



func _prepare_terrain_splat_resources_14e(znum: int, manifest: Dictionary) -> void:
	if _state_15e.splat_shader == null:
		var base_shader := load("res://terrain_splat.gdshader") as Shader
		if terrain_anisotropic_filtering:
			_state_15e.splat_shader = base_shader
		else:
			# Repli qualite/perf : retire l'anisotropie du sampler `details` sans
			# toucher au .gdshader source (partage par tous les niveaux de qualite).
			var low_quality_shader := Shader.new()
			low_quality_shader.code = base_shader.code.replace(
				"filter_linear_mipmap_anisotropic", "filter_linear_mipmap")
			_state_15e.splat_shader = low_quality_shader
	var base := _asset_data_15d("zone%03d_splat" % znum)
	var dsize := int(manifest.get("detail_size", 1024))
	var dcount := int((manifest.get("details", []) as Array).size())
	var mcount := int(manifest.get("mask_count", 0))
	_state_15e.splat_details = _ensure_asset_index_registry_15d().call("load_image_array", base + "/details", dcount, 2, dsize, true) as Texture2DArray
	_state_15e.splat_masks = _ensure_asset_index_registry_15d().call("load_image_array", base + "/masks", mcount, 3, 128, false) as Texture2DArray
	_prepare_terrain_pbr_maps(znum, manifest)


## Sol PBR — les cartes d'une zone, empilées dans l'ordre de `details`. Ne fait
## rien si l'option est décochée ou si la zone les a déjà : le coût est payé une
## fois par zone résidente, et `apply_terrain_pbr_options` rejoue le reste.
func _prepare_terrain_pbr_maps(znum: int, manifest: Dictionary) -> void:
	if not terrain_pbr_enabled:
		return
	if _state_15e.splat_pbr_by_zone.has(znum):
		return
	var names: Array = manifest.get("details", []) as Array
	var report: Dictionary = DaocTerrainPbrUpgrade.load_zone_maps(daoc_client_root, names, terrain_pbr_map_size)
	_state_15e.splat_pbr_by_zone[znum] = report
	print("TERRAIN_PBR={\"zone\":%d,\"ok\":%s,\"couches\":%d,\"avec_cartes\":%d,\"sans_cartes\":%s,\"taille\":%d}" % [
		znum, str(bool(report.get("ok", false))).to_lower(),
		int(report.get("couches_attendues", 0)), int(report.get("couches_avec_cartes", 0)),
		JSON.stringify(report.get("couches_sans_cartes", [])), terrain_pbr_map_size])


## Les cases « Qualité graphique / Terrain » du sol PBR, rendues en données.
## Même rôle que `daoc_sky_quality_options` : le SEUL traducteur export → rendu,
## qu'une future fenêtre d'options du client lira tel quel.
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
	}


## Rejoue le sol PBR sur les zones DÉJÀ bâties, sans reconstruire un maillage.
## Une zone cochée après coup charge ses cartes ici, depuis son manifeste splat.
func apply_terrain_pbr_options() -> Dictionary:
	var options := terrain_pbr_quality_options()
	var report := {"checkpoint": DaocTerrainPbrUpgrade.CHECKPOINT, "zones": {}, "enabled": terrain_pbr_enabled}
	for key in _state_15e.terrain_meshes_by_zone.keys():
		var znum := int(key)
		var meshes: Array = _state_15e.terrain_meshes_by_zone[key] as Array
		var zone_options := options.duplicate()
		if terrain_pbr_enabled and not _state_15e.splat_pbr_by_zone.has(znum):
			var manifest_path := _asset_data_15d("zone%03d_splat/manifest.json" % znum)
			if FileAccess.file_exists(manifest_path):
				var loaded: Variant = _asset_read_15d(manifest_path)
				if typeof(loaded) == TYPE_DICTIONARY:
					_prepare_terrain_pbr_maps(znum, loaded as Dictionary)
		var maps: Dictionary = _state_15e.splat_pbr_by_zone.get(znum, {}) as Dictionary
		if bool(maps.get("ok", false)):
			zone_options["normals"] = maps.get("normals")
			zone_options["roughness"] = maps.get("roughness")
			zone_options["ao"] = maps.get("ao")
		var zone_report: Dictionary = DaocTerrainPbrUpgrade.apply(meshes, zone_options)
		zone_report["cartes"] = bool(maps.get("ok", false))
		zone_report["couches_sans_cartes"] = maps.get("couches_sans_cartes", [])
		(report["zones"] as Dictionary)[znum] = zone_report
	_terrain_pbr_applied_signature = _terrain_pbr_signature()
	return report


var _terrain_pbr_applied_signature: String = ""
func _terrain_pbr_signature() -> String:
	return "%s|%.3f|%.3f|%s|%.3f|%.3f|%.3f|%.1f|%s|%.4f|%d" % [str(terrain_pbr_enabled), terrain_pbr_normal_strength,
		terrain_pbr_ao_amount, str(terrain_macro_variation_enabled), terrain_macro_variation_scale,
		terrain_macro_color_strength, terrain_macro_roughness_strength, terrain_macro_seed,
		str(terrain_virtual_relief_enabled), terrain_virtual_relief_depth,
		terrain_virtual_relief_steps]


## Réglage à chaud depuis l'inspecteur distant : n'agit que si une case a bougé.
func _tick_terrain_pbr_options() -> void:
	if _terrain_pbr_applied_signature.is_empty():
		_terrain_pbr_applied_signature = _terrain_pbr_signature()
		return
	if _terrain_pbr_signature() != _terrain_pbr_applied_signature:
		apply_terrain_pbr_options()


func _apply_outward_decor_options() -> void:
	if not is_inside_tree():
		return
	for runtime in get_tree().get_nodes_in_group("daoc_grass_runtime"):
		if is_ancestor_of(runtime):
			runtime.call("set_outward_rocks_enabled", outward_rocks_enabled)
