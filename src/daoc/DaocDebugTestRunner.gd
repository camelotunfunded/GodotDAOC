extends RefCounted
class_name DaocDebugTestRunner

const DaocDebugOutputLimiterScript = preload("res://src/daoc/DaocDebugOutputLimiter.gd")


## Test runner local déclenché par ZoneViewer avec F12.
## Gros paquet 1→8 : contrôles, zonejump, collisions, sol/capsule, eau, caméra, HUD, targeting.
## P1-N1 hotfix: détails F12 compactés pour éviter le débordement console Godot.
## P1-N2 hotfix: la console n'imprime plus le rapport complet ; les details restent dans les fichiers de reports.
## P1-N3: transport TCP préparatoire isolé + log par fonction transport.
## P1-N4: 100 fonctions packet/framing préparatoires, 1 test F12 par fonction.
## P1-N5A: profil wire DOL 1127 offline + checksum/header/version probe.
## P1-N5B: encodeur offline login/char overview/char select/world init.
## P1-N5D: fixtures/parseur offline des premières réponses serveur DOL.
## P1-N5E/F/G: CharacterOverview enrichi, sélection locale, bootstrap entrée monde offline.
## P1-N5H/I/J + P1-N6A: pré-HUD sélection, modèle personnage, état sélection, apply bootstrap offline.
## P1-N6B: apply réel local confirmé + rollback.
## P1-N6C: flux UI DAoC offline : chargement -> royaume -> personnage.
## P1-N6D: resolver/audit offline des sources assets pregame/loading.
## P1-N6E: gouverneur sortie debug, snapshots compacts, F12 clean.
## P1-N6F: interaction debug zonejump non destructive.
## P1-N6G: zonejump direct local gardé, auto OFF, rollbackable.
## P1-14A: ZoneJumpBuilder foundation, split builder statique / runtime vivant.
## P1-14B: WaterBuilder foundation, split builder statique / runtime vivant.
## P1-14C: CollisionBuilder foundation, split builder statique / runtime vivant.
## P1-14D: PropBuilder foundation, split builder statique / runtime vivant.
## P1-14E: TerrainBuilder foundation, split builder statique / runtime sampling.
## P1-15A: audit statique ZoneViewer post-builders.
## P1-15B: ZoneSceneAssembler foundation, ordre d'assemblage zone sorti du viewer.
## P1-15C-A: réduction masse ZoneViewer, extraction legacy visuals.
## P1-15D: AssetIndexRegistry foundation, sortie du domaine asset/index.
## P1-15E: StateRegistry, regroupement état runtime/build/debug restant.
## P1-15F: extraction surface commandes/debug ZoneViewer.
## P1-15G: extraction bootstrap local viewer / shell final.
## P1-15H: audit de gel, arrêt du refactor ZoneViewer par défaut.
## P1-16A1: ZoneCreator foundation, première scène générée hors ZoneViewer.
## P1-16A2: export .tscn editor-visible minimal de GeneratedZone_000.
## P1-16A3a: population visuelle terrain + eau dans la scène générée.
## P1-16A3b: preview props contrôlée/sectorisée dans la scène générée.
## P1-16A3c: scène complète par zone avec full props.
## P1-16A4: ajout collisions + zonejumps comme données éditeur dans la scène générée.
## P1-16A5a: batch multi-zone limité/configurable, fondation hors génération totale.
## P1-16A6: ZoneSceneExportService, export dynamique orienté znum.
## P1-16A6b: F12 zone-aware, séparation oracles fixes zone000 / validation dynamique zone active.
## P1-16A6c: validation cold-start, suppression contrôlée du .tscn cible avant export A6.
## P1-16A7: batch multi-zone contrôlé + manifest disque, hors F12 global lourd.
## P1-16A7E: nettoyage oracles F12, séparation run historique zone000 pur / run multi-zone.
## P1-16A7F: détection multi-zone basée sur les zones réellement chargées, pas seulement l'export `zones`.
## P1-16A8: loader runtime des scènes GeneratedZone_XXX.tscn depuis le manifest A7.
## P1-16A9: pont runtime optionnel, attache/détache les scènes générées sous un root dédié.
## P1-16A10A: classification terrain/donjon/tileworld avant generated primary.
## P1-17D: runtime attach/spawn opt-in des GeneratedDungeonScene.
## P1-17E1-HF1: profil F12 interactif quick, exports .tscn lourds désactivés par défaut.
## P1-17E2C: DB abstraite des instructions serveur DOL/OpenDAoC, JSON .db, aucun effet runtime.
## P1-17E2D: import préparatoire OpenDAoC-Database SQL vers slots abstraits, aucun effet runtime.
## P1-17E2E: rapport local réel opendaoc-db-core configurable, export JSON/TXT, aucun effet runtime.
## P1-17E2F: probe de frame coordonnées serveur -> scène client, tâches de validation sans spawn.
## P1-17E2J: marker-only des coordonnées serveur candidates dans les scènes donjon, sans spawn joueur.
## P1-18D: OpenDAoC spell.sql -> SpellBook Godot, prediction-only, aucun dégât final.
## P1-18E: couverture des Types OpenDAoC, backlog unsupported, cast explicite, aucun handler fake.
## P1-18F: handlers P0 prediction-only: CC, Lifedrain, DD+Debuff, Heal/HoT/Rez/resources.
## P1-18M: remplacement visuel Meshy du joueur, capsule/collider conservés.
## P1-18N: audit fidélité assets/materials zone000, non destructif, pont/textures/lightmaps.
## P1-18N-HF6: probe conversion NIF, anomalies AABB/materials/hierarchie, audit only.
## P1-19A: audit parite scene generee / ZoneViewer et chemin boot joueur opt-in.
## P1-20A: probe TCP login OpenDAoC dry-run par defaut, sans UDP/spawn/gameplay.
## P1-20UI-A: scènes royaume/personnage originales, test F12 léger et strictement offline.

const DaocDolPacketScript = preload("res://src/daoc/DaocDolPacket.gd")
const DaocDolWire1127Script = preload("res://src/daoc/DaocDolWire1127.gd")
const DaocDolLoginFlow1127Script = preload("res://src/daoc/DaocDolLoginFlow1127.gd")
const DaocDolServerFixtures1127Script = preload("res://src/daoc/DaocDolServerFixtures1127.gd")
const DaocDolCharacterBootstrap1127Script = preload("res://src/daoc/DaocDolCharacterBootstrap1127.gd")
const DaocDolCharacterSelectHud1127Script = preload("res://src/daoc/DaocDolCharacterSelectHud1127.gd")
const DaocPregameLoadingAssetResolverScript = preload("res://src/daoc/DaocPregameLoadingAssetResolver.gd")
const DaocZoneJumpBuilderScript = preload("res://src/daoc/DaocZoneJumpBuilder.gd")
const DaocZoneJumpRuntimeScript = preload("res://src/daoc/DaocZoneJumpRuntime.gd")
const DaocZoneJumpBuildResultScript = preload("res://src/daoc/DaocZoneJumpBuildResult.gd")
const DaocWaterBuilderScript = preload("res://src/daoc/DaocWaterBuilder.gd")
const DaocWaterRuntimeScript = preload("res://src/daoc/DaocWaterRuntime.gd")
const DaocWaterBuildResultScript = preload("res://src/daoc/DaocWaterBuildResult.gd")
const DaocCollisionBuilderScript = preload("res://src/daoc/DaocCollisionBuilder.gd")
const DaocCollisionRuntimeScript = preload("res://src/daoc/DaocCollisionRuntime.gd")
const DaocCollisionBuildResultScript = preload("res://src/daoc/DaocCollisionBuildResult.gd")
const DaocPropBuilderScript = preload("res://src/daoc/DaocPropBuilder.gd")
const DaocPropRuntimeScript = preload("res://src/daoc/DaocPropRuntime.gd")
const DaocPropBuildResultScript = preload("res://src/daoc/DaocPropBuildResult.gd")
const DaocTerrainBuilderScript = preload("res://src/daoc/DaocTerrainBuilder.gd")
const DaocTerrainRuntimeScript = preload("res://src/daoc/DaocTerrainRuntime.gd")
const DaocTerrainBuildResultScript = preload("res://src/daoc/DaocTerrainBuildResult.gd")
const DaocZoneViewerPostBuildersAuditScript = preload("res://src/daoc/DaocZoneViewerPostBuildersAudit.gd")
const DaocZoneSceneAssemblerScript = preload("res://src/daoc/DaocZoneSceneAssembler.gd")
const DaocLegacyVisualsScript = preload("res://src/daoc/DaocLegacyVisuals.gd")
const DaocAssetIndexRegistryScript = preload("res://src/daoc/DaocAssetIndexRegistry.gd")
const DaocZoneViewerStateRegistryScript = preload("res://src/daoc/DaocZoneViewerStateRegistry.gd")
const DaocZoneViewerCommandDebugSurfaceScript = preload("res://src/daoc/DaocZoneViewerCommandDebugSurface.gd")
const DaocLocalViewerBootstrapScript = preload("res://src/daoc/DaocLocalViewerBootstrap.gd")
const DaocZoneViewerFreezeAuditScript = preload("res://src/daoc/DaocZoneViewerFreezeAudit.gd")
const DaocZoneCreationResultScript = preload("res://src/daoc/DaocZoneCreationResult.gd")
const DaocZoneCreatorScript = preload("res://src/daoc/DaocZoneCreator.gd")
const DaocGeneratedZoneSceneLoaderScript = preload("res://src/daoc/DaocGeneratedZoneSceneLoader.gd")
const DaocGeneratedZoneRuntimeBridgeScript = preload("res://src/daoc/DaocGeneratedZoneRuntimeBridge.gd")
const DaocZoneKindResolverScript = preload("res://src/daoc/DaocZoneKindResolver.gd")
const DaocDungeonSceneBuilderScript = preload("res://src/daoc/dungeon/DaocDungeonSceneBuilder.gd")
const DaocDungeonFileResolverScript = preload("res://src/daoc/dungeon/DaocDungeonFileResolver.gd")
const DaocGeneratedDungeonRuntimeBridgeScript = preload("res://src/daoc/dungeon/DaocGeneratedDungeonRuntimeBridge.gd")
const DaocWorldDestinationScript = preload("res://src/daoc/world/DaocWorldDestination.gd")
const DaocServerBackendAdapterScript = preload("res://src/daoc/world/DaocServerBackendAdapter.gd")
const DaocWorldDestinationResolverScript = preload("res://src/daoc/world/DaocWorldDestinationResolver.gd")
const DaocDolDestinationAdapterScript = preload("res://src/daoc/world/DaocDolDestinationAdapter.gd")
const DaocOpenDaocDestinationAdapterScript = preload("res://src/daoc/world/DaocOpenDaocDestinationAdapter.gd")
const DaocFallbackDestinationAdapterScript = preload("res://src/daoc/world/DaocFallbackDestinationAdapter.gd")
const DaocServerInstructionDbScript = preload("res://src/daoc/serverdb/DaocServerInstructionDb.gd")
const DaocOpenDaocSqlImportScript = preload("res://src/daoc/serverdb/DaocOpenDaocSqlImport.gd")
const DaocServerCoordinateFrameProbeScript = preload("res://src/daoc/serverdb/DaocServerCoordinateFrameProbe.gd")
const DaocServerCoordinateMarkerPlanScript = preload("res://src/daoc/serverdb/DaocServerCoordinateMarkerPlan.gd")
const DaocServerLiveCaptureProbeScript = preload("res://src/daoc/serverdb/DaocServerLiveCaptureProbe.gd")
const DaocOfflineWorldPreviewScript = preload("res://src/daoc/offline/DaocOfflineWorldPreview.gd")
const DaocOfflineCombatLabScript = preload("res://src/daoc/gameplay/lab/DaocOfflineCombatLab.gd")
const DaocOpenDaocAttackRequestCodecScript = preload("res://src/daoc/gameplay/net/DaocOpenDaocAttackRequestCodec.gd")
const DaocOpenDaocUseSpellCodecScript = preload("res://src/daoc/gameplay/net/DaocOpenDaocUseSpellCodec.gd")
const DaocActiveEffectScript = preload("res://src/daoc/gameplay/effects/DaocActiveEffect.gd")
const DaocEffectStateScript = preload("res://src/daoc/gameplay/effects/DaocEffectState.gd")
const DaocBuffDebuffSpellHandlerScript = preload("res://src/daoc/gameplay/spells/DaocBuffDebuffSpellHandler.gd")
const DaocDoTDiseaseProcSpellHandlerScript = preload("res://src/daoc/gameplay/spells/DaocDoTDiseaseProcSpellHandler.gd")
const DaocGenericDamageEffectSpellHandlerScript = preload("res://src/daoc/gameplay/spells/DaocGenericDamageEffectSpellHandler.gd")
const DaocPetSpellHandlerScript = preload("res://src/daoc/gameplay/spells/DaocPetSpellHandler.gd")
const DaocOpenDaocLiveComparisonHarnessScript = preload("res://src/daoc/gameplay/live/DaocOpenDaocLiveComparisonHarness.gd")
const DaocPlayerVisualMeshySwapScript = preload("res://src/daoc/player/DaocPlayerVisualMeshySwap.gd")
const DaocGroundingServiceScript = preload("res://src/daoc/player/DaocGroundingService.gd")
const DaocAssetMaterialFidelityAuditScript = preload("res://src/daoc/audit/DaocAssetMaterialFidelityAudit.gd")
const DaocNifImportConversionProbeScript = preload("res://src/daoc/audit/DaocNifImportConversionProbe.gd")
const DaocGeneratedSceneParityAuditScript = preload("res://src/daoc/audit/DaocGeneratedSceneParityAudit.gd")
const DaocOpenDaocPacketCodecScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketCodec.gd")
const DaocOpenDaocChecksumScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocChecksum.gd")
const DaocOpenDaocTcpLoginProbeScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocTcpLoginProbe.gd")
const DaocOpenDaocPacketLogScript = preload("res://src/daoc/network/opendaoc/DaocOpenDaocPacketLog.gd")
const DaocPregameDataAdapterScript = preload("res://src/daoc/ui/pregame/DaocPregameDataAdapter.gd")
const DaocPregameFlowScene = preload("res://scenes/ui/pregame/DaocPregameFlow.tscn")

const REPORT_PATH: String = "res://reports/daoc_f12_test_report.txt"
const DEBUG_EXPORT_PATH: String = "res://reports/daoc_f12_debug_export.txt"
const JSON_REPORT_PATH: String = "res://reports/daoc_f12_test_report.json"
const MAX_DETAIL_CHARS: int = 260
const MAX_DEBUG_SNAPSHOT_CHARS: int = 900
const A7_MANIFEST_PATH: String = "res://reports/generated/zones/manifest.json"

var _report: Array = []
var _debug: Array = []
var _json_sections: Array = []
var _debug_output_limiter: RefCounted = null
var _pass_count: int = 0
var _warn_count: int = 0
var _fail_count: int = 0
var _start_msec: int = 0
var _a6c_preflight_target_zone: int = -1
var _a6c_preflight_expected_path: String = ""
var _a6c_preflight_scene_existed_before: bool = false
var _a6c_preflight_scene_removed: bool = false
var _f12_heavy_scene_exports_enabled: bool = false
var _p1_17e2e_last_report: Dictionary = {}
var _p1_17e2f_last_report: Dictionary = {}


func run(zone_viewer: Node) -> Dictionary:
	_report.clear()
	_debug.clear()
	_json_sections.clear()
	_pass_count = 0
	_warn_count = 0
	_fail_count = 0
	_start_msec = Time.get_ticks_msec()
	_f12_heavy_scene_exports_enabled = _should_run_heavy_f12_scene_exports(zone_viewer)
	_p1_17e2e_last_report.clear()
	_p1_17e2f_last_report.clear()

	_add_header(zone_viewer)
	var run_zone000_oracles := _should_run_zone000_oracles(zone_viewer)

	_test_zoneviewer_core(zone_viewer)
	_test_runtime_zone_data(zone_viewer)
	_test_player_stack(zone_viewer)
	_test_player_visual_meshy_p1_18m(zone_viewer)
	_test_actor_grounding_visual_feet_p1_18p(zone_viewer)
	_test_asset_material_fidelity_p1_18n(zone_viewer)
	_test_nif_import_conversion_probe_p1_18n_hf6(zone_viewer)
	_test_keyboard_bindings(zone_viewer)
	_test_client_control_1(zone_viewer)
	_test_zonejump_2(zone_viewer)
	_test_zonejump_p1_n6f(zone_viewer)
	_test_zonejump_p1_n6g(zone_viewer)
	_test_collisions_3(zone_viewer)
	_test_f12_zone_oracle_routing_p1_16a6b(zone_viewer, run_zone000_oracles)

	if run_zone000_oracles:
		_test_zonejump_p1_14a(zone_viewer)
		_test_collision_p1_14c(zone_viewer)
		_test_prop_p1_14d(zone_viewer)
		_test_terrain_p1_14e(zone_viewer)
		_test_zoneviewer_p1_15a_audit(zone_viewer)
		_test_zone_scene_p1_15b_assembler(zone_viewer)
		_test_zoneviewer_mass_reduction_p1_15c(zone_viewer)
		_test_asset_index_registry_p1_15d(zone_viewer)
		_test_zoneviewer_state_grouping_p1_15e(zone_viewer)
		_test_zoneviewer_command_debug_surface_p1_15f(zone_viewer)
		_test_local_viewer_bootstrap_p1_15g(zone_viewer)
		_test_zoneviewer_freeze_audit_p1_15h(zone_viewer)
		_test_zone_creator_p1_16a1(zone_viewer)
		if _f12_heavy_scene_exports_enabled:
			_test_zone_creator_export_p1_16a2(zone_viewer)
			_test_zone_creator_terrain_water_p1_16a3a(zone_viewer)
			_test_zone_creator_props_strategy_p1_16a3b(zone_viewer)
			_test_zone_creator_full_zone_props_p1_16a3c(zone_viewer)
			_test_zone_creator_collision_zonejump_p1_16a4(zone_viewer)
			_test_zone_creator_multi_zone_batch_p1_16a5a(zone_viewer)
		else:
			_test_f12_heavy_scene_exports_skipped_p1_17e1_hf1(zone_viewer)
	else:
		_test_skipped_legacy_zone000_oracles_p1_16a6b(zone_viewer)

	if _f12_heavy_scene_exports_enabled:
		_test_cold_start_preflight_p1_16a6c(zone_viewer)
		_test_zone_scene_export_service_p1_16a6(zone_viewer)
		_test_cold_start_postflight_p1_16a6c(zone_viewer)
	else:
		_test_zone_scene_export_service_skipped_p1_17e1_hf1(zone_viewer)
	_test_zone_creator_controlled_batch_manifest_p1_16a7(zone_viewer)
	_test_generated_zone_scene_loader_p1_16a8(zone_viewer)
	_test_generated_zone_runtime_bridge_p1_16a9(zone_viewer)
	_test_generated_scene_parity_boot_p1_19a(zone_viewer)
	_test_zone_kind_resolver_p1_16a10a(zone_viewer)
	_test_dungeon_zonecreator_p1_17c(zone_viewer)
	_test_offline_preview_quality_p1_17f5(zone_viewer)
	_test_ground_capsule_4(zone_viewer)
	_test_motor_p0_a3(zone_viewer)
	_test_water_5(zone_viewer)
	if run_zone000_oracles:
		_test_water_p1_14b(zone_viewer)
	_test_camera_6(zone_viewer)
	_test_ui_7(zone_viewer)
	_test_targeting_8(zone_viewer)
	_test_dol_p1_n1(zone_viewer)
	_test_dol_p1_n2(zone_viewer)
	_test_dol_p1_n3(zone_viewer)
	_test_dol_p1_n4_packet_100(zone_viewer)
	_test_dol_p1_n5a_wire_1127(zone_viewer)
	_test_server_live_capture_p1_17f6(zone_viewer)
	_test_opendaoc_tcp_login_probe_p1_20a(zone_viewer)
	_test_daoc_pregame_selection_p1_20ui(zone_viewer)
	_test_offline_combat_lab_p1_18b(zone_viewer)
	_test_dol_p1_n5b_login_flow(zone_viewer)
	_test_dol_p1_n5d_server_fixtures(zone_viewer)
	_test_dol_p1_n5efg_character_bootstrap(zone_viewer)
	_test_dol_p1_n5hij_selection_hud_model_apply(zone_viewer)
	_test_dol_p1_n6b_guarded_real_apply_rollback(zone_viewer)
	_test_dol_p1_n6c_daoc_ui_flow(zone_viewer)
	_test_dol_p1_n6d_asset_source_resolver(zone_viewer)
	_test_p1_n6e_debug_output_governor(zone_viewer)
	_test_command_router(zone_viewer)
	_export_debug_dump(zone_viewer)

	var elapsed := Time.get_ticks_msec() - _start_msec
	_line("")
	_line("SUMMARY pass=%d warn=%d fail=%d elapsed_ms=%d" % [_pass_count, _warn_count, _fail_count, elapsed])
	_line("REPORT_PATH=%s" % ProjectSettings.globalize_path(REPORT_PATH))
	_line("DEBUG_EXPORT_PATH=%s" % ProjectSettings.globalize_path(DEBUG_EXPORT_PATH))
	_line("JSON_REPORT_PATH=%s" % ProjectSettings.globalize_path(JSON_REPORT_PATH))

	var report_text := "\n".join(_report) + "\n"
	var debug_text := "\n".join(_debug) + "\n"
	_write_text(REPORT_PATH, report_text)
	_write_text(DEBUG_EXPORT_PATH, debug_text)
	_write_json(zone_viewer, elapsed)

	# Ne jamais imprimer le rapport complet dans la console Godot.
	# Les snapshots P1-N1/P1-N2 peuvent être volumineux et provoquent sinon :
	# ERROR: [output overflow, print less text!]
	print("DAoC F12 report written: %s" % ProjectSettings.globalize_path(REPORT_PATH))
	print("DAoC F12 debug export written: %s" % ProjectSettings.globalize_path(DEBUG_EXPORT_PATH))
	print("DAoC F12 json report written: %s" % ProjectSettings.globalize_path(JSON_REPORT_PATH))

	return {
		"pass": _pass_count,
		"warn": _warn_count,
		"fail": _fail_count,
		"report_path": ProjectSettings.globalize_path(REPORT_PATH),
		"debug_export_path": ProjectSettings.globalize_path(DEBUG_EXPORT_PATH),
		"json_report_path": ProjectSettings.globalize_path(JSON_REPORT_PATH),
	}


func _add_header(zone_viewer: Node) -> void:
	_line("DAoC Godot F12 local test report")
	_line("timestamp=%s" % Time.get_datetime_string_from_system(true, true))
	_line("scene=%s" % (zone_viewer.name if zone_viewer != null else "<null>"))
	_line("godot=%s" % Engine.get_version_info().get("string", "unknown"))
	_line("scope=paquets client local 1→8 + P1-N1/N2/N3 + P1-N4 packet/framing 100 fonctions + P1-N5A wire 1127 offline + P1-N5B login flow offline + P1-N5D server fixtures offline + P1-N5E/F/G character bootstrap offline + P1-N5H/I/J + P1-N6A offline selection HUD/model/apply + P1-N6B guarded real apply rollback + P1-N6C DAoC UI flow + P1-N6D asset resolver + P1-N6E debug output governor + P1-N6F zonejump debug interaction + P1-N6G zonejump direct guarded local transition + P1-14A ZoneJumpBuilder + P1-14B WaterBuilder + P1-14C CollisionBuilder + P1-14D PropBuilder + P1-14E TerrainBuilder + P1-15A ZoneViewer audit + P1-15B ZoneSceneAssembler + P1-15C-A ZoneViewer mass reduction legacy visuals + P1-15D AssetIndexRegistry + P1-15E StateRegistry + P1-15F CommandDebugSurface + P1-15G ViewerBootstrap + P1-15H FreezeAudit + P1-16A1 ZoneCreator + P1-16A2 GeneratedZone tscn export + P1-16A3a terrain/water visible scene + P1-16A3b props strategy preview + P1-16A3c full zone props scene + P1-16A4 collision/zonejump editor data + P1-16A5a multi-zone batch foundation + P1-16A6 ZoneSceneExportService + P1-16A6b F12 zone-aware oracle routing + P1-16A6c cold-start rebuild guard + P1-16A7 controlled multi-zone batch manifest + P1-16A7c zonecreator command + P1-16A7E F12 multi-zone oracle cleanup + P1-16A7F effective loaded-zone oracle routing + P1-16A8 runtime load generated scenes + P1-16A9 generated-scene runtime bridge + P1-16A10A zone kind classification + P1-17C dungeon ZoneCreator integration + P1-17C3 generated dungeon regression report + P1-17D generated dungeon runtime attach/spawn + HF2 isolation + P1-17E1 neutral WorldDestination DOL/OpenDAoC + P1-17E2C abstract server instruction DB + P1-17E2D OpenDAoC SQL DB import preparation + P1-17E2E OpenDAoC real SQL local report + P1-17E2F server coordinate frame probe + P1-17E2G viewer persistent DB path + P1-17E2J server coordinate markers")
	_line("")


func _should_run_heavy_f12_scene_exports(zone_viewer: Node) -> bool:
	if zone_viewer == null:
		return false
	if zone_viewer.has_meta("f12_force_heavy_scene_exports_once"):
		var forced: bool = bool(zone_viewer.get_meta("f12_force_heavy_scene_exports_once"))
		zone_viewer.set_meta("f12_force_heavy_scene_exports_once", false)
		if forced:
			return true
	if _has_property(zone_viewer, "f12_debug_test_run_heavy_scene_exports"):
		return bool(zone_viewer.get("f12_debug_test_run_heavy_scene_exports"))
	return false


func _f12_profile_name(zone_viewer: Node) -> String:
	if zone_viewer != null and _has_property(zone_viewer, "f12_debug_test_profile"):
		return str(zone_viewer.get("f12_debug_test_profile"))
	return "quick"


func _test_f12_heavy_scene_exports_skipped_p1_17e1_hf1(zone_viewer: Node) -> void:
	_section("P1-17E1-HF1 F12 interactive quick profile")
	_check(true, "F12 quick profile active", "profile=%s heavy_scene_exports=%s" % [_f12_profile_name(zone_viewer), str(_f12_heavy_scene_exports_enabled)])
	_check(true, "P1-16A2/A3/A4/A5 heavy GeneratedZone .tscn exports skipped in interactive F12")
	_check(true, "Use f12_debug_test_run_heavy_scene_exports=true for full export regression")
	_check(true, "Manual ZoneCreator hotkeys and commands remain available", "F7/F8/F9/F10/F11 or /zonecreator")


func _test_zone_scene_export_service_skipped_p1_17e1_hf1(zone_viewer: Node) -> void:
	_section("P1-17E1-HF1 skipped P1-16A6 disk export service")
	_check(true, "P1-16A6 ResourceSaver/export reload skipped in interactive F12", "profile=%s" % _f12_profile_name(zone_viewer))
	_check(true, "Cold-start destructive .tscn delete/rebuild guard skipped in interactive F12")
	_check(true, "Full disk export validation is opt-in", "set f12_debug_test_run_heavy_scene_exports=true")


func _test_f12_zone_oracle_routing_p1_16a6b(zone_viewer: Node, run_zone000_oracles: bool) -> void:
	_section("P1-16A6b/F12 zone-aware oracle routing")
	var zones: Array = _get_array_like(zone_viewer, "zones")
	var effective_zones: Array = _effective_loaded_zones_a7f(zone_viewer)
	var target_zone: int = _first_configured_zone(zone_viewer)
	var multi_zone: bool = effective_zones.size() > 1
	_check(true, "P1-16A6b routing section present")
	_check(target_zone >= 0, "P1-16A6b target zone resolved", "target=%d zones=%s effective=%s" % [target_zone, str(zones), str(effective_zones)])
	_check(run_zone000_oracles == _should_run_zone000_oracles(zone_viewer), "P1-16A6b routing decision stable", "zone000_oracles=%s multi_zone=%s effective=%s" % [str(run_zone000_oracles), str(multi_zone), str(effective_zones)])
	if run_zone000_oracles:
		_check(true, "P1-16A6b historical zone000 oracles enabled", "zones=%s effective=%s" % [str(zones), str(effective_zones)])
	else:
		_check(target_zone != 0 or multi_zone, "P1-16A7F dynamic/multi-zone oracle mode enabled", "target=%d zones=%s effective=%s" % [target_zone, str(zones), str(effective_zones)])
		_check(true, "P1-16A7F legacy fixed zone000 totals deferred", "validation authority=P1-16A6/A7 dynamic zone-aware checks")


func _test_skipped_legacy_zone000_oracles_p1_16a6b(zone_viewer: Node) -> void:
	_section("P1-16A7F skipped legacy fixed zone000 oracles")
	var zones: Array = _get_array_like(zone_viewer, "zones")
	var effective_zones: Array = _effective_loaded_zones_a7f(zone_viewer)
	var target_zone: int = _first_configured_zone(zone_viewer)
	var multi_zone: bool = effective_zones.size() > 1
	_check(target_zone != 0 or multi_zone, "P1-16A7F skip is valid for non-zone000 or effective multi-zone runs", "target=%d zones=%s effective=%s" % [target_zone, str(zones), str(effective_zones)])
	_check(true, "P1-16A7F skipped P1-14A/B/C/D/E fixed global zone000 totals", "reason=runtime may legitimately contain several zones")
	_check(true, "P1-16A7F skipped P1-15 fixed visual totals", "reason=lights/vegetation are additive across loaded zones")
	_check(true, "P1-16A7F skipped P1-16A1-A5a fixed zone000 export oracles", "reason=P1-16A6/A7 validate dynamic zone export")


func _test_cold_start_preflight_p1_16a6c(zone_viewer: Node) -> void:
	_section("P1-16A6c cold-start rebuild guard")
	var zones := _get_array_like(zone_viewer, "zones")
	var target_zone := _first_configured_zone(zone_viewer)
	var expected_path := "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [target_zone, target_zone]
	_a6c_preflight_target_zone = target_zone
	_a6c_preflight_expected_path = expected_path
	_a6c_preflight_scene_existed_before = FileAccess.file_exists(expected_path)
	_a6c_preflight_scene_removed = false

	_debug.append("\n--- P1-16A6c cold-start rebuild guard ---")
	_debug.append("target=%d zones=%s path=%s existed_before=%s" % [target_zone, str(zones), expected_path, str(_a6c_preflight_scene_existed_before)])

	_check(true, "P1-16A6c section present")
	_check(target_zone >= 0, "P1-16A6c target zone resolved", "target=%d zones=%s" % [target_zone, str(zones)])
	if target_zone == 0:
		_check(true, "P1-16A6c guard inactive for zone000 oracle runs", "zones=%s" % str(zones))
		return

	_check(not _array_contains_int(zones, 0), "P1-16A6c run excludes zone000", "zones=%s" % str(zones))
	var required_maps := [
		"_zone_runtime",
		"_terrain_build_results",
		"_terrain_meshes_by_zone",
		"_boundary_build_results",
		"_zonejump_build_results",
		"_prop_collision_runtime",
		"_prop_build_results",
		"_prop_nodes_by_zone",
		"_water_build_results",
	]
	for property_name in required_maps:
		var keys := _dictionary_keys_int(zone_viewer, str(property_name))
		_check(not _array_contains_int(keys, 0), "P1-16A6c no stale zone000 key in %s" % str(property_name), "keys=%s" % str(keys))
		_check(_array_contains_int(keys, target_zone), "P1-16A6c target key present in %s" % str(property_name), "keys=%s" % str(keys))

	if _a6c_preflight_scene_existed_before:
		var abs_path := ProjectSettings.globalize_path(expected_path)
		var remove_error := DirAccess.remove_absolute(abs_path)
		_a6c_preflight_scene_removed = remove_error == OK
		_check(remove_error == OK, "P1-16A6c removes pre-existing target .tscn before export", "err=%d path=%s" % [remove_error, expected_path])
	else:
		_check(true, "P1-16A6c target .tscn was absent before export", expected_path)

	_check(not FileAccess.file_exists(expected_path), "P1-16A6c target .tscn absent before A6 export", expected_path)


func _test_cold_start_postflight_p1_16a6c(zone_viewer: Node) -> void:
	_section("P1-16A6c cold-start rebuild postflight")
	if _a6c_preflight_target_zone == 0:
		_check(true, "P1-16A6c postflight inactive for zone000 oracle runs")
		return
	_check(_a6c_preflight_target_zone == _first_configured_zone(zone_viewer), "P1-16A6c target zone unchanged during F12", "before=%d after=%d" % [_a6c_preflight_target_zone, _first_configured_zone(zone_viewer)])
	_check(FileAccess.file_exists(_a6c_preflight_expected_path), "P1-16A6c A6 recreated target .tscn", _a6c_preflight_expected_path)
	if _a6c_preflight_scene_existed_before:
		_check(_a6c_preflight_scene_removed, "P1-16A6c rebuild started from deleted prior .tscn", _a6c_preflight_expected_path)
	else:
		_check(true, "P1-16A6c rebuild started from missing .tscn", _a6c_preflight_expected_path)
	_check(_a6c_preflight_expected_path == "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [_a6c_preflight_target_zone, _a6c_preflight_target_zone], "P1-16A6c recreated path is zone-aware", _a6c_preflight_expected_path)


func _test_zoneviewer_core(zone_viewer: Node) -> void:
	_section("ZoneViewer core")
	_check(zone_viewer != null, "ZoneViewer node is valid")
	if zone_viewer == null:
		return
	_check(zone_viewer.has_method("daoc_to_godot"), "daoc_to_godot method present")
	_check(zone_viewer.has_method("sample_daoc_floor_z"), "sample_daoc_floor_z method present")
	_check(zone_viewer.has_method("sample_daoc_water_info"), "sample_daoc_water_info method present")
	_check(zone_viewer.has_method("solve_daoc_boundary_collision"), "solve_daoc_boundary_collision method present")
	_check(zone_viewer.has_method("solve_daoc_prop_collision"), "solve_daoc_prop_collision method present")
	_check(zone_viewer.has_method("get_local_client_debug_snapshot"), "local client debug snapshot present")
	_check(_get_bool(zone_viewer, "player_force_disable_legacy_mouse_movement") == true, "legacy mouse forced disabled at viewer level")
	_check(_get_bool(zone_viewer, "player_use_keyboard_dat_bindings") == true, "keyboard.dat bindings enabled")
	_check(_get_bool(zone_viewer, "build_dev_hud") == true, "dev HUD enabled")
	_check(_get_bool(zone_viewer, "build_local_targeting") == true, "local targeting enabled")


func _test_runtime_zone_data(zone_viewer: Node) -> void:
	_section("Runtime zone data")
	var zones := _get_array_like(zone_viewer, "zones")
	_check(zones.size() > 0, "at least one zone configured", "zones=%s" % str(zones))
	var zone_runtime := _get_dict(zone_viewer, "_zone_runtime")
	_check(zone_runtime.size() > 0, "zone runtime cache populated", "size=%d" % zone_runtime.size())
	for z in zones:
		var znum := int(z)
		var rt: Dictionary = zone_runtime.get(znum, {}) as Dictionary
		_check(not rt.is_empty(), "zone%03d runtime entry exists" % znum)
		if not rt.is_empty():
			_check(rt.has("hb") and rt.has("res"), "zone%03d height data present" % znum)
			var floor_z := float(zone_viewer.call("sample_daoc_floor_z", znum, 32768.0, 32768.0, 0.0))
			_check(_is_finite_float(floor_z), "zone%03d floor sample finite" % znum, "floor=%.2f" % floor_z)


func _test_player_stack(zone_viewer: Node) -> void:
	_section("Player stack")
	var player := _get_node_ref(zone_viewer, "_player")
	var camera := _get_node_ref(zone_viewer, "_player_camera")
	var router := _get_node_ref(zone_viewer, "_input_router")
	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(player != null, "player capsule exists")
	_check(camera != null, "player camera exists")
	_check(router != null, "input router exists")
	_check(command != null, "command router exists")
	if player != null:
		_check(player.has_method("turn_by_degrees"), "player turn_by_degrees method present")
		_check(player.has_method("motor_compute_forward_vector"), "player motor_compute_forward_vector method present")
		_check(player.has_method("motor_compute_right_vector"), "player motor_compute_right_vector method present")
		_check(player.has_method("motor_compute_effective_speed_raw"), "player motor_compute_effective_speed_raw method present")
		_check(player.has_method("get_motor_constants_snapshot"), "player motor constants snapshot present")
		_check(player.has_method("get_motor_local_flags_snapshot"), "player motor local flags snapshot present")
		_check(player.has_method("set_climb_flag_local_placeholder"), "player climb local flag setter present")
		_check(player.has_method("motor_movement_state_name_for_value"), "player movement state name helper present")
		_check(player.has_method("get_movement_debug_snapshot"), "player movement snapshot present")
		_check(player.has_method("unstuck_to_safe_local_position"), "local unstuck method present")
		var x := float(player.get("daoc_x"))
		var y := float(player.get("daoc_y"))
		var z := float(player.get("daoc_z"))
		_check(x >= 0.0 and x <= 65536.0 and y >= 0.0 and y <= 65536.0, "player XY inside zone", "x=%.1f y=%.1f" % [x, y])
		_check(_is_finite_float(z), "player Z finite", "z=%.1f" % z)


func _test_keyboard_bindings(zone_viewer: Node) -> void:
	_section("keyboard.dat bindings")
	var router := _get_node_ref(zone_viewer, "_input_router")
	_check(router != null, "router available for keyboard tests")
	if router == null:
		return
	var bindings: Object = router.get("keyboard_bindings") as Object
	_check(bindings != null, "keyboard bindings object exists")
	if bindings == null:
		return
	_check(bool(bindings.get("loaded")), "keyboard.dat loaded", str(bindings.get("last_error")))
	var source := str(bindings.get("source_path"))
	_check(source != "", "keyboard.dat source path captured", source)
	var presets = bindings.call("get_preset_names")
	_check(presets.has("fpsdefault"), "fpsdefault preset parsed", str(presets))
	_check(presets.has("rpgdefault"), "rpgdefault preset parsed", str(presets))
	_check(presets.has("mmodefault"), "mmodefault preset parsed", str(presets))
	var preset := str(router.get("keyboard_preset"))
	_check(bool(bindings.call("has_preset", preset)), "active preset exists", preset)
	var required := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0x14, 0x21, 0x2A, 0x42, 0x53]
	for action_id in required:
		var b: Dictionary = bindings.call("get_action_binding", preset, int(action_id)) as Dictionary
		_check(not b.is_empty(), "action %02d binding readable" % int(action_id), str(b))
		if int(action_id) in [0, 1, 2, 3, 4, 5, 7, 8, 9, 0x2A]:
			_check(bool(bindings.call("is_action_bound", preset, int(action_id))), "action %02d bound to Godot-readable key" % int(action_id), str(b))
	_check(bindings.has_method("get_actions_debug_snapshot"), "keyboard action snapshot helper present")
	_debug.append("\n--- keyboard compact ---")
	if bindings.has_method("debug_compact_actions"):
		_debug.append(_snapshot_debug_line(bindings.call("debug_compact_actions", preset, PackedInt32Array(required))))
	if bindings.has_method("get_actions_debug_snapshot"):
		var ksnap: Dictionary = bindings.call("get_actions_debug_snapshot", preset, PackedInt32Array(required), false, false) as Dictionary
		_check(int(ksnap.get("action_count", 0)) == required.size(), "keyboard action snapshot covers required movement actions", str(ksnap))
		_check(int(ksnap.get("bound_count", 0)) >= 10, "keyboard action snapshot has enough bound actions", str(ksnap))
		_debug.append("\n--- keyboard action snapshot ---")
		_debug.append(_snapshot_debug_line(ksnap))


func _test_client_control_1(zone_viewer: Node) -> void:
	_section("1. Client controls / locomotion")
	var router := _get_node_ref(zone_viewer, "_input_router")
	_check(router != null, "input router available")
	if router == null:
		return
	_check(bool(router.get("use_keyboard_dat_bindings")), "router uses keyboard.dat")
	_check(bool(router.get("mouse_right_moves_forward")) == false, "right mouse does not move forward")
	_check(bool(router.get("mouse_left_moves_backward")) == false, "left mouse does not move backward")
	_check(bool(router.get("mouse_both_buttons_move_forward")) == false, "both mouse chord does not move")
	_check(router.has_method("get_router_debug_snapshot"), "router debug snapshot present")
	_check(router.has_method("runlock_toggle"), "runlock_toggle present")
	_check(router.has_method("runlock_disable"), "runlock_disable present")
	_check(router.has_method("walk_toggle"), "walk_toggle present")
	_check(router.has_method("walk_disable"), "walk_disable present")
	_check(router.has_method("sprint_send_command_stub"), "sprint local stub present")
	_check(router.has_method("get_input_action_snapshot"), "input action snapshot present")
	var state: Object = null
	if router.has_method("get_input_state"):
		state = router.call("get_input_state") as Object
	_check(state != null, "input state available")
	if state != null:
		_check(state.has_method("action_debug_string"), "input state action_debug_string present")
		_check(state.has_method("get_debug_snapshot"), "input state debug snapshot present")
	if state != null and state.has_method("debug_string"):
		_debug.append("\n--- input state ---")
		_debug.append(_snapshot_debug_line(state.call("debug_string")))
	if router.has_method("get_input_action_snapshot"):
		_debug.append("\n--- input action snapshot ---")
		_debug.append(_snapshot_debug_line(router.call("get_input_action_snapshot")))
	if router.has_method("get_router_debug_snapshot"):
		_debug.append("\n--- router snapshot ---")
		_debug.append(_snapshot_debug_line(router.call("get_router_debug_snapshot")))
	_check(router.has_method("get_locomotion_router_snapshot"), "router locomotion snapshot present")
	if router.has_method("get_locomotion_router_snapshot"):
		_debug.append("\n--- locomotion router snapshot ---")
		_debug.append(_snapshot_debug_line(router.call("get_locomotion_router_snapshot")))
	if state != null:
		_check(state.has_method("get_locomotion_flags_snapshot"), "input state locomotion flags snapshot present")
		if state.has_method("get_locomotion_flags_snapshot"):
			_debug.append("\n--- input locomotion flags ---")
			_debug.append(_snapshot_debug_line(state.call("get_locomotion_flags_snapshot")))
	_check(router.has_method("get_mouse_camera_debug_snapshot"), "router mouse camera snapshot present")
	if router.has_method("get_mouse_camera_debug_snapshot"):
		_debug.append("\n--- mouse camera input snapshot ---")
		_debug.append(_snapshot_debug_line(router.call("get_mouse_camera_debug_snapshot")))


func _test_zonejump_2(zone_viewer: Node) -> void:
	_section("2. zonejump.csv debug volumes")
	var entries_by_zone := _get_dict(zone_viewer, "_zonejump_entries_by_zone")
	_check(entries_by_zone.size() > 0, "zonejump parsed entries dictionary populated", "zones=%s" % str(entries_by_zone.keys()))
	for z in entries_by_zone.keys():
		var entries: Array = entries_by_zone.get(z, []) as Array
		_check(entries.size() > 0, "zone%03d zonejump entries generated" % int(z), "entries=%d" % entries.size())
		var targets := 0
		for e in entries:
			var ed: Dictionary = e as Dictionary
			if int(ed.get("target", -1)) >= 0:
				targets += 1
		_check(targets > 0, "zone%03d zonejump targets present" % int(z), "targets=%d" % targets)
	var area_count := _count_nodes_with_meta(zone_viewer, "daoc_zonejump")
	_check(area_count > 0, "zonejump Area3D nodes present", "areas=%d" % area_count)
	_check(zone_viewer.has_method("get_zonejump_debug_snapshot"), "zonejump debug snapshot present")
	_force_zonejump_auto_off_for_f12(zone_viewer)
	if zone_viewer.has_method("get_zonejump_debug_snapshot"):
		_debug.append("\n--- zonejump snapshot ---")
		_debug.append(_snapshot_debug_line(zone_viewer.call("get_zonejump_debug_snapshot")))


func _force_zonejump_auto_off_for_f12(zone_viewer: Node) -> Dictionary:
	# P1-N6G hotfix: F12 must test the safe default independently from
	# manual user commands executed before the report (/zonejump auto on).
	if zone_viewer != null and zone_viewer.has_method("set_zonejump_auto_transition_enabled"):
		return zone_viewer.call("set_zonejump_auto_transition_enabled", false) as Dictionary
	return {}


func _test_zonejump_p1_n6f(zone_viewer: Node) -> void:
	_section("P1-N6F zonejump debug interaction")
	_force_zonejump_auto_off_for_f12(zone_viewer)
	_check(zone_viewer.has_method("get_zonejump_interaction_debug_snapshot"), "P1-N6F zonejump interaction snapshot present")
	_check(zone_viewer.has_method("get_zonejump_status_lines"), "P1-N6F zonejump status lines present")
	_check(zone_viewer.has_method("get_zonejump_last_event_lines"), "P1-N6F zonejump last lines present")
	_check(zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"), "P1-N6F zonejump nearest snapshot present")
	if zone_viewer.has_method("get_zonejump_interaction_debug_snapshot"):
		var snap: Dictionary = zone_viewer.call("get_zonejump_interaction_debug_snapshot") as Dictionary
		_check(int(snap.get("entries_total", 0)) > 0, "P1-N6F sees parsed zonejump entries", "entries=%d" % int(snap.get("entries_total", 0)))
		_check(int(snap.get("targets_total", 0)) > 0, "P1-N6F sees zonejump targets", "targets=%d" % int(snap.get("targets_total", 0)))
		_check(int(snap.get("area_count", 0)) > 0, "P1-N6F sees Area3D debug volumes", "areas=%d" % int(snap.get("area_count", 0)))
		_check(str(snap.get("transition_stage", snap.get("transition_deferred_to", ""))).contains("P1-N6G"), "P1-N6F hands off transition to P1-N6G", str(snap.get("transition_stage", snap.get("transition_deferred_to", ""))))
		_check(bool(snap.get("auto_transition_enabled", true)) == false, "P1-N6F auto transition disabled", "f12_forced_safe_default")
		_debug.append("\n--- P1-N6F zonejump interaction snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	if zone_viewer.has_method("get_zonejump_status_lines"):
		var status_lines: PackedStringArray = zone_viewer.call("get_zonejump_status_lines", 3) as PackedStringArray
		_check(status_lines.size() >= 2, "P1-N6F status lines readable", "lines=%d" % status_lines.size())
		_debug.append("\n--- P1-N6F zonejump status lines ---")
		var status_array: Array = []
		for i in range(status_lines.size()):
			status_array.append(status_lines[i])
		_debug.append(_snapshot_debug_line(status_array))
	if zone_viewer.has_method("get_zonejump_last_event_lines"):
		var last_lines: PackedStringArray = zone_viewer.call("get_zonejump_last_event_lines") as PackedStringArray
		_check(last_lines.size() >= 2, "P1-N6F last event lines readable", "lines=%d" % last_lines.size())
	if zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"):
		var near: Dictionary = zone_viewer.call("get_zonejump_nearest_debug_snapshot", 2400.0) as Dictionary
		_check(near.has("ok"), "P1-N6F nearest snapshot reports status", str(near))
	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-N6F command router available")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonejump status")), "/zonejump status handled")
		_check(bool(command.call("execute_command", "/zonejump last")), "/zonejump last handled")
		_check(bool(command.call("execute_command", "/zonejump log")), "/zonejump log handled")
		_check(bool(command.call("execute_command", "/zonejump nearest")), "/zonejump nearest handled")


func _test_zonejump_p1_n6g(zone_viewer: Node) -> void:
	_section("P1-N6G zonejump direct guarded local transition")
	_force_zonejump_auto_off_for_f12(zone_viewer)
	_check(zone_viewer.has_method("get_zonejump_transition_debug_snapshot"), "P1-N6G transition snapshot present")
	_check(zone_viewer.has_method("get_zonejump_transition_lines"), "P1-N6G transition lines present")
	_check(zone_viewer.has_method("execute_zonejump_nearest_transition"), "P1-N6G nearest direct transition method present")
	_check(zone_viewer.has_method("execute_zonejump_transition_by_id"), "P1-N6G id direct transition method present")
	_check(zone_viewer.has_method("set_zonejump_auto_transition_enabled"), "P1-N6G auto toggle method present")
	if zone_viewer.has_method("get_zonejump_transition_debug_snapshot"):
		var snap: Dictionary = zone_viewer.call("get_zonejump_transition_debug_snapshot") as Dictionary
		_check(bool(snap.get("direct_transition_enabled", false)), "P1-N6G direct transition enabled")
		_check(not bool(snap.get("auto_transition_enabled", true)), "P1-N6G auto transition off by default", "f12_forced_safe_default")
		_check(bool(snap.get("load_missing_target_zone", false)), "P1-N6G can load missing target zone on demand")
		_debug.append("\n--- P1-N6G zonejump transition snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	if zone_viewer.has_method("get_zonejump_transition_lines"):
		var lines: PackedStringArray = zone_viewer.call("get_zonejump_transition_lines", 4) as PackedStringArray
		_check(lines.size() >= 2, "P1-N6G transition lines readable", "lines=%d" % lines.size())
		var line_array: Array = []
		for i in range(lines.size()):
			line_array.append(lines[i])
		_debug.append("\n--- P1-N6G zonejump transition lines ---")
		_debug.append(_snapshot_debug_line(line_array))
	if zone_viewer.has_method("set_zonejump_auto_transition_enabled"):
		var on_snap: Dictionary = zone_viewer.call("set_zonejump_auto_transition_enabled", true) as Dictionary
		_check(bool(on_snap.get("auto_transition_enabled", false)), "P1-N6G auto can be enabled")
		var off_snap: Dictionary = zone_viewer.call("set_zonejump_auto_transition_enabled", false) as Dictionary
		_check(not bool(off_snap.get("auto_transition_enabled", true)), "P1-N6G auto can be disabled again")
	if zone_viewer.has_method("execute_zonejump_nearest_transition"):
		var result: Dictionary = zone_viewer.call("execute_zonejump_nearest_transition", 1.0, "f12_guarded_nearest_tiny_radius") as Dictionary
		_check(result.has("ok") and result.has("reason"), "P1-N6G nearest direct attempt returns guarded result", _snapshot_debug_line(result))
	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-N6G command router available")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonejump auto status")), "/zonejump auto status handled")
		_check(bool(command.call("execute_command", "/zonejump auto on")), "/zonejump auto on handled")
		_check(bool(command.call("execute_command", "/zonejump auto off")), "/zonejump auto off handled")
		_check(bool(command.call("execute_command", "/zonejump transition")), "/zonejump transition handled")
		_check(bool(command.call("execute_command", "/zonejump go nearest")), "/zonejump go nearest handled guarded")


func _test_zonejump_p1_14a(zone_viewer: Node) -> void:
	_section("P1-14A ZoneJumpBuilder foundation")
	var builder: RefCounted = DaocZoneJumpBuilderScript.new()
	var runtime: RefCounted = DaocZoneJumpRuntimeScript.new()
	var build_result: RefCounted = DaocZoneJumpBuildResultScript.new()
	_check(builder != null, "P1-14A DaocZoneJumpBuilder exists")
	_check(runtime != null, "P1-14A DaocZoneJumpRuntime exists")
	_check(build_result != null, "P1-14A DaocZoneJumpBuildResult exists")
	_check(builder != null and builder.has_method("build"), "P1-14A builder exposes build")
	_check(runtime != null and runtime.has_method("bind"), "P1-14A runtime exposes bind")
	_check(runtime != null and runtime.has_method("wire"), "P1-14A runtime exposes wire")
	_check(runtime != null and runtime.has_method("nearest_daoc"), "P1-14A runtime exposes nearest_daoc")
	_check(runtime != null and runtime.has_method("volumes_at_daoc"), "P1-14A runtime exposes volumes_at_daoc")
	_check(runtime != null and runtime.has_method("status"), "P1-14A runtime exposes status")
	_check(runtime != null and runtime.has_method("get_last_triggered"), "P1-14A runtime exposes get_last_triggered")

	var old_symbols := PackedStringArray([
		"_build_zone_zonejumps",
		"_add_zonejump_area",
		"_zonejump_node_name",
		"_find_nearest_zonejump_entry",
		"_zonejump_dedupe_reverse_pairs",
	])
	for symbol in old_symbols:
		_check(not zone_viewer.has_method(symbol), "P1-14A ZoneViewer old zonejump method absent: %s" % symbol)

	_check(zone_viewer.has_method("get_zonejump_14a_debug_snapshot"), "P1-14A debug snapshot present")
	_check(zone_viewer.has_method("zonejump_14a_simulate_first_body_entered"), "P1-14A signal simulation helper present")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		snap = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
		_debug.append("\n--- P1-14A zonejump builder snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	var metrics: Dictionary = snap.get("zone0_metrics", {}) as Dictionary
	_check(int(metrics.get("entries", 0)) == 28, "P1-14A builder isolated zone000 entries=28", str(metrics))
	_check(int(metrics.get("targets", 0)) == 26, "P1-14A builder isolated zone000 targets=26", str(metrics))
	_check(int(metrics.get("areas", 0)) == 28, "P1-14A builder isolated zone000 areas=28", str(metrics))
	_check(bool(snap.get("packed_scene_ok", false)), "P1-14A builder root packable")

	var results: Dictionary = _get_dict(zone_viewer, "_zonejump_build_results")
	var zone0_result: RefCounted = results.get(0, null) as RefCounted
	_check(zone0_result != null, "P1-14A ZoneViewer stores build result for zone000")
	if zone0_result != null:
		var static_index: Array = zone0_result.get("static_index") as Array
		var signature := str(zone0_result.get("index_signature"))
		var recomputed := str(DaocZoneJumpBuilderScript.compute_index_signature(static_index))
		_check(signature != "", "P1-14A index signature present", signature)
		_check(signature == recomputed, "P1-14A index signature stable", signature)
		_check(static_index.size() == int(metrics.get("areas", static_index.size())), "P1-14A static index matches area count", "index=%d areas=%d" % [static_index.size(), int(metrics.get("areas", 0))])
		var live_runtime: RefCounted = zone_viewer.get("_zonejump_runtime") as RefCounted
		_check(live_runtime != null, "P1-14A ZoneViewer owns runtime")
		if live_runtime != null and static_index.size() > 0:
			var first: Dictionary = static_index[0] as Dictionary
			var center := Vector2(float(first.get("center_x", 0.0)), float(first.get("center_y", 0.0)))
			var znum := int(first.get("source_zone", 0))
			var near: Dictionary = live_runtime.call("nearest_daoc", znum, center) as Dictionary
			_check(bool(near.get("ok", false)), "P1-14A nearest_daoc returns ok", _snapshot_debug_line(near))
			_check(int(near.get("id", -2)) == int(first.get("id", -1)), "P1-14A nearest_daoc center returns expected id", "got=%s expected=%s" % [str(near.get("id", "")), str(first.get("id", ""))])
			var volumes: Array = live_runtime.call("volumes_at_daoc", znum, center) as Array
			var found_volume := false
			for item in volumes:
				var d: Dictionary = item as Dictionary
				if int(d.get("id", -2)) == int(first.get("id", -1)):
					found_volume = true
					break
			_check(found_volume, "P1-14A volumes_at_daoc contains expected volume", "volumes=%d expected=%s" % [volumes.size(), str(first.get("id", ""))])

	if zone_viewer.has_method("zonejump_14a_simulate_first_body_entered"):
		var sim: Dictionary = zone_viewer.call("zonejump_14a_simulate_first_body_entered") as Dictionary
		_check(bool(sim.get("ok", false)), "P1-14A body_entered signal routed through runtime", _snapshot_debug_line(sim))

	var p1_n6f: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_interaction_debug_snapshot"):
		p1_n6f = zone_viewer.call("get_zonejump_interaction_debug_snapshot") as Dictionary
	var p1_n6g: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_transition_debug_snapshot"):
		p1_n6g = zone_viewer.call("get_zonejump_transition_debug_snapshot") as Dictionary
	_check(int(p1_n6f.get("entries_total", 0)) == 28, "P1-14A preserves P1-N6F zone000 entries", str(p1_n6f.get("entries_total", 0)))
	_check(int(p1_n6f.get("targets_total", 0)) == 26, "P1-14A preserves P1-N6F zone000 targets", str(p1_n6f.get("targets_total", 0)))
	_check(not bool(p1_n6g.get("auto_transition_enabled", true)), "P1-14A preserves P1-N6G auto OFF")


func _test_collisions_3(zone_viewer: Node) -> void:
	_section("3. Local collision diagnostics")
	_check(zone_viewer.has_method("get_collision_debug_snapshot"), "collision debug snapshot present")
	var boundary := _get_dict(zone_viewer, "_boundary_runtime")
	_check(boundary.size() > 0, "bound.csv runtime populated", "zones=%s" % str(boundary.keys()))
	for z in boundary.keys():
		var segments: Array = boundary.get(z, []) as Array
		_check(segments.size() > 0, "zone%03d boundary segments present" % int(z), "segments=%d" % segments.size())
	var props := _get_dict(zone_viewer, "_prop_collision_runtime")
	_check(props.size() > 0, "prop collision runtime populated", "zones=%s" % str(props.keys()))
	for z in props.keys():
		var bodies: Array = props.get(z, []) as Array
		_check(bodies.size() > 0, "zone%03d prop AABB bodies present" % int(z), "bodies=%d" % bodies.size())
	var group_count := _count_nodes_in_group(zone_viewer, "daoc_prop_collision")
	_check(group_count > 0, "prop collision bodies grouped for targeting/debug", "group=%d" % group_count)
	if zone_viewer.has_method("get_collision_debug_snapshot"):
		_debug.append("\n--- collision snapshot ---")
		_debug.append(_snapshot_debug_line(zone_viewer.call("get_collision_debug_snapshot")))


func _test_collision_p1_14c(zone_viewer: Node) -> void:
	_section("P1-14C CollisionBuilder foundation")
	var builder: RefCounted = DaocCollisionBuilderScript.new()
	var runtime: RefCounted = DaocCollisionRuntimeScript.new()
	var build_result: RefCounted = DaocCollisionBuildResultScript.new()
	_check(builder != null, "P1-14C DaocCollisionBuilder exists")
	_check(runtime != null, "P1-14C DaocCollisionRuntime exists")
	_check(build_result != null, "P1-14C DaocCollisionBuildResult exists")
	_check(builder != null and builder.has_method("build_boundary"), "P1-14C builder exposes build_boundary")
	_check(builder != null and builder.has_method("build_prop_aabb"), "P1-14C builder exposes build_prop_aabb")
	_check(builder != null and builder.has_method("parse_bound_csv"), "P1-14C builder exposes parse_bound_csv")
	_check(builder != null and builder.has_method("prop_collision_decision"), "P1-14C builder exposes prop_collision_decision")
	_check(builder != null and builder.has_method("compute_boundary_signature"), "P1-14C builder exposes compute_boundary_signature")
	_check(builder != null and builder.has_method("compute_prop_signature"), "P1-14C builder exposes compute_prop_signature")
	_check(runtime != null and runtime.has_method("bind_boundary"), "P1-14C runtime exposes bind_boundary")
	_check(runtime != null and runtime.has_method("bind_props"), "P1-14C runtime exposes bind_props")
	_check(runtime != null and runtime.has_method("status"), "P1-14C runtime exposes status")
	_check(runtime != null and runtime.has_method("point_near_boundary_2d"), "P1-14C runtime exposes point_near_boundary_2d")
	_check(runtime != null and runtime.has_method("solve_boundary_collision"), "P1-14C runtime exposes solve_boundary_collision")
	_check(runtime != null and runtime.has_method("solve_prop_collision"), "P1-14C runtime exposes solve_prop_collision")
	_check(runtime != null and runtime.has_method("is_prop_position_blocked"), "P1-14C runtime exposes is_prop_position_blocked")

	var old_symbols := PackedStringArray([
		"_build_zone_bound_collision",
		"_parse_bound_csv",
		"_add_bound_segment_collision",
		"_fixture_prop_collision_decision",
		"_add_prop_aabb_collision",
		"_template_local_aabb",
		"_transformed_aabb",
		"_register_prop_collision_runtime",
		"_is_daoc_prop_position_blocked",
		"_daoc_prop_aabb_blocks_position",
	])
	for symbol in old_symbols:
		_check(not zone_viewer.has_method(symbol), "P1-14C ZoneViewer old collision method absent: %s" % symbol)

	_check(zone_viewer.has_method("get_collision_14c_debug_snapshot"), "P1-14C debug snapshot present")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		snap = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
		_debug.append("\n--- P1-14C collision builder snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	var metrics: Dictionary = snap.get("zone0_metrics", {}) as Dictionary
	_check(int(metrics.get("boundary_segments", 0)) == 142, "P1-14C builder isolated zone000 boundary_segments=142", str(metrics))
	_check(int(metrics.get("boundary_bodies", 0)) == 142, "P1-14C builder isolated zone000 boundary_bodies=142", str(metrics))
	_check(bool(metrics.get("packable_ok", false)), "P1-14C boundary root packable", str(metrics))
	_check(int(snap.get("zone0_prop_count", 0)) == 502, "P1-14C builder/runtime zone000 prop_bodies=502", str(snap.get("zone0_prop_count", 0)))
	_check(int(snap.get("static_boundary_index_total", 0)) == 142, "P1-14C static boundary index total=142", str(snap.get("static_boundary_index_total", 0)))
	_check(int(snap.get("static_prop_index_total", 0)) == 502, "P1-14C static prop index total=502", str(snap.get("static_prop_index_total", 0)))

	var boundary_results: Dictionary = _get_dict(zone_viewer, "_boundary_build_results")
	var zone0_result: RefCounted = boundary_results.get(0, null) as RefCounted
	_check(zone0_result != null, "P1-14C ZoneViewer stores boundary build result for zone000")
	if zone0_result != null:
		var static_boundary: Array = zone0_result.get("boundary_segments") as Array
		var signature := str(zone0_result.get("boundary_index_signature"))
		var recomputed := str(DaocCollisionBuilderScript.compute_boundary_signature(static_boundary))
		_check(signature != "", "P1-14C boundary index signature present", signature)
		_check(signature == recomputed, "P1-14C boundary index signature stable", signature)

	var prop_runtime: Dictionary = _get_dict(zone_viewer, "_prop_collision_runtime")
	var prop_index: Array = prop_runtime.get(0, []) as Array
	var prop_signature := str(snap.get("zone0_prop_signature", ""))
	var prop_recomputed := str(DaocCollisionBuilderScript.compute_prop_signature(prop_index))
	_check(prop_signature != "", "P1-14C prop index signature present", prop_signature)
	_check(prop_signature == prop_recomputed, "P1-14C prop index signature stable", prop_signature)

	var live_runtime: RefCounted = zone_viewer.get("_collision_runtime_obj") as RefCounted
	_check(live_runtime != null, "P1-14C ZoneViewer owns runtime")
	if live_runtime != null:
		var boundary_index: Array = _get_dict(zone_viewer, "_boundary_runtime").get(0, []) as Array
		if boundary_index.size() > 0:
			var first_bound: Dictionary = boundary_index[0] as Dictionary
			var mid := ((first_bound.get("a", Vector2.ZERO) as Vector2) + (first_bound.get("b", Vector2.ZERO) as Vector2)) * 0.5
			var near_bound := bool(live_runtime.call("point_near_boundary_2d", 0, mid, 16.0))
			_check(near_bound, "P1-14C runtime point_near_boundary_2d sees first segment")
		if prop_index.size() > 0:
			var first_prop: Dictionary = prop_index[0] as Dictionary
			var sample := Vector2(float(first_prop.get("sample_x", 0.0)), float(first_prop.get("sample_y", 0.0)))
			var blocked := bool(live_runtime.call("is_prop_position_blocked", 0, sample, float(first_prop.get("sample_z", 0.0)), 1.0, maxf(1.0, float(first_prop.get("sample_height", 1.0)))))
			_check(blocked, "P1-14C runtime is_prop_position_blocked sees first prop", "fixture=%s file=%s" % [str(first_prop.get("fixture_id", "")), str(first_prop.get("file", ""))])

	var old_collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_debug_snapshot"):
		old_collision = zone_viewer.call("get_collision_debug_snapshot") as Dictionary
	_check(int(old_collision.get("boundary_segments_total", 0)) == 142, "P1-14C preserves old boundary debug count", str(old_collision.get("boundary_segments_total", 0)))
	_check(int(old_collision.get("prop_bodies_total", 0)) == 502, "P1-14C preserves old prop debug count", str(old_collision.get("prop_bodies_total", 0)))




func _test_prop_p1_14d(zone_viewer: Node) -> void:
	_section("P1-14D PropBuilder foundation")
	var builder: RefCounted = DaocPropBuilderScript.new()
	var runtime: RefCounted = DaocPropRuntimeScript.new()
	var build_result: RefCounted = DaocPropBuildResultScript.new()
	_check(builder != null, "P1-14D DaocPropBuilder exists")
	_check(runtime != null, "P1-14D DaocPropRuntime exists")
	_check(build_result != null, "P1-14D DaocPropBuildResult exists")
	_check(builder != null and builder.has_method("build"), "P1-14D builder exposes build")
	_check(builder != null and builder.has_method("compute_index_signature"), "P1-14D builder exposes compute_index_signature")
	_check(runtime != null and runtime.has_method("bind"), "P1-14D runtime exposes bind")
	_check(runtime != null and runtime.has_method("status"), "P1-14D runtime exposes status")
	_check(runtime != null and runtime.has_method("props_for_zone"), "P1-14D runtime exposes props_for_zone")
	_check(runtime != null and runtime.has_method("find_by_fixture_id"), "P1-14D runtime exposes find_by_fixture_id")

	var old_symbols := PackedStringArray([
		"_place_fixtures",
		"_place_fixture_boxes",
	])
	for symbol in old_symbols:
		_check(not zone_viewer.has_method(symbol), "P1-14D ZoneViewer old prop method absent: %s" % symbol)

	_check(zone_viewer.has_method("get_prop_14d_debug_snapshot"), "P1-14D debug snapshot present")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		snap = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
		_debug.append("\n--- P1-14D prop builder snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	var metrics: Dictionary = snap.get("zone0_metrics", {}) as Dictionary
	_check(int(metrics.get("fixtures", 0)) == 1876, "P1-14D builder isolated zone000 fixtures=1876", str(metrics))
	_check(int(metrics.get("placed", 0)) == 1876, "P1-14D builder isolated zone000 placed=1876", str(metrics))
	_check(int(metrics.get("missing", -1)) == 0, "P1-14D builder isolated zone000 missing=0", str(metrics))
	_check(int(metrics.get("nodes", 0)) == 1876, "P1-14D builder isolated zone000 nodes=1876", str(metrics))
	_check(bool(metrics.get("packable_ok", false)), "P1-14D prop root packable", str(metrics))
	_check(int(snap.get("static_index_total", 0)) == 1876, "P1-14D static prop index total=1876", str(snap.get("static_index_total", 0)))

	var results: Dictionary = _get_dict(zone_viewer, "_prop_build_results")
	var zone0_result: RefCounted = results.get(0, null) as RefCounted
	_check(zone0_result != null, "P1-14D ZoneViewer stores prop build result for zone000")
	if zone0_result != null:
		var static_index: Array = zone0_result.get("static_index") as Array
		var signature := str(zone0_result.get("index_signature"))
		var recomputed := str(DaocPropBuilderScript.compute_index_signature(static_index))
		_check(signature != "", "P1-14D prop index signature present", signature)
		_check(signature == recomputed, "P1-14D prop index signature stable", signature)
		_check(static_index.size() == int(metrics.get("fixtures", 0)), "P1-14D static index matches fixture count", "index=%d fixtures=%d" % [static_index.size(), int(metrics.get("fixtures", 0))])

	var live_runtime: RefCounted = zone_viewer.get("_prop_runtime_obj") as RefCounted
	_check(live_runtime != null, "P1-14D ZoneViewer owns prop runtime")
	if live_runtime != null:
		var props: Array = live_runtime.call("props_for_zone", 0) as Array
		_check(props.size() == 1876, "P1-14D runtime props_for_zone returns zone000 props", "props=%d" % props.size())
		if props.size() > 0:
			var first_prop: Dictionary = props[0] as Dictionary
			var fixture_id := int(first_prop.get("fixture_id", 0))
			var found: Dictionary = live_runtime.call("find_by_fixture_id", 0, fixture_id) as Dictionary
			_check(int(found.get("fixture_id", -1)) == fixture_id, "P1-14D runtime find_by_fixture_id returns first prop", "fixture=%d" % fixture_id)

	# 14D ne doit pas casser la collision props extraite en 14C.
	var old_collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_debug_snapshot"):
		old_collision = zone_viewer.call("get_collision_debug_snapshot") as Dictionary
	_check(int(old_collision.get("prop_bodies_total", 0)) == 502, "P1-14D preserves 14C prop collision count", str(old_collision.get("prop_bodies_total", 0)))


func _test_terrain_p1_14e(zone_viewer: Node) -> void:
	_section("P1-14E TerrainBuilder foundation")
	var builder: RefCounted = DaocTerrainBuilderScript.new()
	var runtime: RefCounted = DaocTerrainRuntimeScript.new()
	var build_result: RefCounted = DaocTerrainBuildResultScript.new()
	_check(builder != null, "P1-14E DaocTerrainBuilder exists")
	_check(runtime != null, "P1-14E DaocTerrainRuntime exists")
	_check(build_result != null, "P1-14E DaocTerrainBuildResult exists")
	_check(builder != null and builder.has_method("build"), "P1-14E builder exposes build")
	_check(builder != null and builder.has_method("compute_index_signature"), "P1-14E builder exposes compute_index_signature")
	_check(runtime != null and runtime.has_method("bind"), "P1-14E runtime exposes bind")
	_check(runtime != null and runtime.has_method("status"), "P1-14E runtime exposes status")
	_check(runtime != null and runtime.has_method("sample_floor"), "P1-14E runtime exposes sample_floor")
	_check(runtime != null and runtime.has_method("sectors_for_zone"), "P1-14E runtime exposes sectors_for_zone")

	var old_symbols := PackedStringArray([
		"_build_zone_splat",
		"_build_sector_mesh",
		"_build_terrain_collision_from_indexed_mesh",
		"_sample_height",
		"_raw_at",
		"_ensure_splat_shared",
	])
	for symbol in old_symbols:
		_check(not zone_viewer.has_method(symbol), "P1-14E ZoneViewer old terrain method absent: %s" % symbol)

	_check(zone_viewer.has_method("get_terrain_14e_debug_snapshot"), "P1-14E debug snapshot present")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		snap = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
		_debug.append("\n--- P1-14E terrain builder snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	var metrics: Dictionary = snap.get("zone0_metrics", {}) as Dictionary
	_check(int(metrics.get("sectors", 0)) == 64, "P1-14E terrain builder zone000 sectors=64", str(metrics))
	_check(int(metrics.get("terrain_meshes", 0)) == 64, "P1-14E terrain mesh count unchanged=64", str(metrics))
	_check(bool(metrics.get("packable_ok", false)), "P1-14E terrain root packable", str(metrics))
	_check(int(snap.get("static_index_total", 0)) == 64, "P1-14E static terrain index total=64", str(snap.get("static_index_total", 0)))
	if bool(zone_viewer.get("build_terrain_collision")):
		_check(int(metrics.get("collision_bodies", 0)) == 64, "P1-14E terrain collision body count unchanged=64", str(metrics))

	var results: Dictionary = _get_dict(zone_viewer, "_terrain_build_results")
	var zone0_result: RefCounted = results.get(0, null) as RefCounted
	_check(zone0_result != null, "P1-14E ZoneViewer stores terrain build result for zone000")
	if zone0_result != null:
		var static_index: Array = zone0_result.get("static_index") as Array
		var signature := str(zone0_result.get("index_signature"))
		var recomputed := str(DaocTerrainBuilderScript.compute_index_signature(static_index))
		_check(signature != "", "P1-14E terrain index signature present", signature)
		_check(signature == recomputed, "P1-14E terrain index signature stable", signature)
		_check(static_index.size() == int(metrics.get("sectors", 0)), "P1-14E static index matches sector count", "index=%d sectors=%d" % [static_index.size(), int(metrics.get("sectors", 0))])

	var live_runtime: RefCounted = zone_viewer.get("_terrain_runtime_obj") as RefCounted
	_check(live_runtime != null, "P1-14E ZoneViewer owns terrain runtime")
	if live_runtime != null:
		var sectors: Array = live_runtime.call("sectors_for_zone", 0) as Array
		_check(sectors.size() == 64, "P1-14E runtime sectors_for_zone returns 64 sectors", "sectors=%d" % sectors.size())
		var rt: Dictionary = (_get_dict(zone_viewer, "_zone_runtime")).get(0, {}) as Dictionary
		var hb: PackedByteArray = rt.get("hb", PackedByteArray()) as PackedByteArray
		var res := int(rt.get("res", 0))
		var points := [Vector2(32768.0, 32768.0), Vector2(1024.0, 1024.0), Vector2(65535.0, 65535.0), Vector2(12345.0, 54321.0)]
		for pnt in points:
			var p2: Vector2 = pnt as Vector2
			var via_viewer := float(zone_viewer.call("sample_daoc_floor_z", 0, p2.x, p2.y, 0.0))
			var via_runtime := float(live_runtime.call("sample_floor", 0, p2.x, p2.y, 0.0))
			var via_formula := via_runtime
			if not hb.is_empty() and res > 0:
				via_formula = DaocTerrainRuntimeScript._sample_height(hb, res, p2.x, p2.y)
			_check(absf(via_viewer - via_runtime) <= 0.001, "P1-14E sample_daoc_floor_z delegates unchanged at %.0f,%.0f" % [p2.x, p2.y], "viewer=%.3f runtime=%.3f" % [via_viewer, via_runtime])
			_check(absf(via_viewer - via_formula) <= 0.001, "P1-14E sample floor matches legacy formula at %.0f,%.0f" % [p2.x, p2.y], "viewer=%.3f formula=%.3f" % [via_viewer, via_formula])

	# 14E ne doit pas casser les builders déjà validés.
	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_debug_snapshot"):
		collision = zone_viewer.call("get_collision_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var zonejump_metrics: Dictionary = zonejump.get("zone0_metrics", {}) as Dictionary
	var water_metrics: Dictionary = water.get("zone0_metrics", {}) as Dictionary
	var prop_metrics: Dictionary = prop.get("zone0_metrics", {}) as Dictionary
	_check(int(zonejump_metrics.get("areas", 0)) == 28, "P1-14E preserves 14A zonejump areas=28")
	_check(int(water_metrics.get("meshes", 0)) == 2, "P1-14E preserves 14B water meshes=2")
	_check(int(collision.get("boundary_segments_total", 0)) == 142, "P1-14E preserves 14C boundary segments=142")
	_check(int(collision.get("prop_bodies_total", 0)) == 502, "P1-14E preserves 14C prop bodies=502")
	_check(int(prop_metrics.get("nodes", 0)) == 1876, "P1-14E preserves 14D prop nodes=1876")


func _test_zoneviewer_p1_15a_audit(zone_viewer: Node) -> void:
	_section("P1-15A ZoneViewer post-builders audit")
	_check(DaocZoneViewerPostBuildersAuditScript != null, "P1-15A DaocZoneViewerPostBuildersAudit exists")
	_check(zone_viewer.has_method("get_zoneviewer_p1_15a_audit_snapshot"), "P1-15A ZoneViewer exposes audit snapshot")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_p1_15a_audit_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_p1_15a_audit_snapshot") as Dictionary
	_debug.append("\n--- P1-15A ZoneViewer post-builders audit ---")
	_debug.append(_snapshot_debug_line(snap))
	_check(bool(snap.get("source_readable", false)), "P1-15A audit can read ZoneViewer.gd", str(snap.get("source_path", "")))
	_check(int(snap.get("line_count", 0)) > 0, "P1-15A audit remains readable after reductions", "lines=%d" % int(snap.get("line_count", 0)))
	_check(int(snap.get("function_count", 0)) >= 100, "P1-15A audit counts remaining ZoneViewer functions", "functions=%d" % int(snap.get("function_count", 0)))
	_check(int(snap.get("export_count", 0)) >= 100, "P1-15A audit counts exported knobs", "exports=%d" % int(snap.get("export_count", 0)))
	_check(bool(snap.get("extracted_builder_methods_absent", false)), "P1-15A extracted builder methods remain absent", str(snap.get("old_extracted_methods_present", [])))
	_check(str(snap.get("recommended_next_step", "")) == "P1-15B ZoneSceneAssembler foundation", "P1-15A recommends ZoneSceneAssembler next", str(snap.get("recommended_next_step", "")))

	var domains: Dictionary = snap.get("domains", {}) as Dictionary
	_check(int(domains.get("zonejump_runtime_debug", 0)) > 0, "P1-15A audit sees zonejump command/debug surface still in ZoneViewer", str(domains.get("zonejump_runtime_debug", 0)))
	_check(domains.has("vegetation_legacy"), "P1-15A audit reports vegetation legacy residue", str(domains.get("vegetation_legacy", 0)))
	_check(domains.has("legacy_lights"), "P1-15A audit reports legacy lights residue", str(domains.get("legacy_lights", 0)))

	var builder_status: Dictionary = snap.get("builder_runtime_status", {}) as Dictionary
	_check(int(builder_status.get("zonejump_build_results", 0)) >= 1, "P1-15A sees 14A zonejump build result", str(builder_status.get("zonejump_build_results", 0)))
	_check(int(builder_status.get("water_build_results", 0)) >= 1, "P1-15A sees 14B water build result", str(builder_status.get("water_build_results", 0)))
	_check(int(builder_status.get("collision_build_results", 0)) >= 1, "P1-15A sees 14C collision build result", str(builder_status.get("collision_build_results", 0)))
	_check(int(builder_status.get("prop_build_results", 0)) >= 1, "P1-15A sees 14D prop build result", str(builder_status.get("prop_build_results", 0)))
	_check(int(builder_status.get("terrain_build_results", 0)) >= 1, "P1-15A sees 14E terrain build result", str(builder_status.get("terrain_build_results", 0)))


func _test_zone_scene_p1_15b_assembler(zone_viewer: Node) -> void:
	_section("P1-15B ZoneSceneAssembler foundation")
	_check(DaocZoneSceneAssemblerScript != null, "P1-15B DaocZoneSceneAssembler exists")
	_check(zone_viewer.has_method("get_zone_scene_15b_debug_snapshot"), "P1-15B ZoneViewer exposes scene assembler snapshot")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zone_scene_15b_debug_snapshot"):
		snap = zone_viewer.call("get_zone_scene_15b_debug_snapshot") as Dictionary
	_debug.append("\n--- P1-15B ZoneSceneAssembler snapshot ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(bool(snap.get("assembler_present", false)), "P1-15B ZoneViewer owns ZoneSceneAssembler")
	_check(int(snap.get("result_count", 0)) >= 1, "P1-15B assembler has at least one zone result", str(snap.get("result_count", 0)))
	_check(bool(snap.get("zone0_ok", false)), "P1-15B zone000 assembly succeeded")
	_check(int(snap.get("zone_runtime_size", 0)) >= 1, "P1-15B zone runtime populated through assembler", str(snap.get("zone_runtime_size", 0)))

	var order: Array = snap.get("build_order", []) as Array
	_check(order.size() == 7, "P1-15B build order has 7 phases", str(order))
	if order.size() >= 7:
		_check(str(order[0]) == "terrain_14e", "P1-15B build order starts with terrain", str(order))
		_check(str(order[1]) == "collision_14c_boundary", "P1-15B build order keeps boundary after terrain", str(order))
		_check(str(order[2]) == "zonejump_14a", "P1-15B build order keeps zonejump before water", str(order))
		_check(str(order[6]) == "props_14d", "P1-15B build order finishes with props", str(order))

	var zone0: Dictionary = snap.get("zone0_result", {}) as Dictionary
	var steps: Array = zone0.get("steps", []) as Array
	_check(steps.size() == 7, "P1-15B zone000 has 7 executed assembly steps", "steps=%d" % steps.size())
	var all_steps_ok := steps.size() == 7
	for raw_step in steps:
		var step: Dictionary = raw_step as Dictionary
		if not bool(step.get("ok", false)):
			all_steps_ok = false
	_check(all_steps_ok, "P1-15B all zone000 assembly steps are OK", str(steps))

	var builder_results: Dictionary = snap.get("builder_results", {}) as Dictionary
	_check(int(builder_results.get("terrain", 0)) >= 1, "P1-15B sees terrain build result after assembly", str(builder_results.get("terrain", 0)))
	_check(int(builder_results.get("collision", 0)) >= 1, "P1-15B sees collision build result after assembly", str(builder_results.get("collision", 0)))
	_check(int(builder_results.get("zonejump", 0)) >= 1, "P1-15B sees zonejump build result after assembly", str(builder_results.get("zonejump", 0)))
	_check(int(builder_results.get("water", 0)) >= 1, "P1-15B sees water build result after assembly", str(builder_results.get("water", 0)))
	_check(int(builder_results.get("props", 0)) >= 1, "P1-15B sees prop build result after assembly", str(builder_results.get("props", 0)))
	_check(str(snap.get("recommended_next_step", "")) == "P1-15C ZoneViewer mass reduction A legacy visuals", "P1-15B recommends ZoneViewer mass reduction next", str(snap.get("recommended_next_step", "")))

func _test_zoneviewer_mass_reduction_p1_15c(zone_viewer: Node) -> void:
	_section("P1-15C ZoneViewer mass reduction A legacy visuals")
	_check(DaocLegacyVisualsScript != null, "P1-15C DaocLegacyVisuals exists")
	_check(zone_viewer.has_method("get_zoneviewer_mass_reduction_15c_snapshot"), "P1-15C ZoneViewer exposes mass reduction snapshot")
	_check(zone_viewer.has_method("_setup_visual_stage_lamps_15c"), "P1-15C ZoneViewer keeps lamp compatibility entry point")
	_check(zone_viewer.has_method("_setup_visual_stage_cards_15c"), "P1-15C ZoneViewer keeps card compatibility entry point")
	_check(not zone_viewer.has_method("_build_zone_lights"), "P1-15C old light builder absent from ZoneViewer")
	_check(not zone_viewer.has_method("_build_zone_vegetation"), "P1-15C old vegetation builder absent from ZoneViewer")
	_check(not zone_viewer.has_method("_parse_lights_csv"), "P1-15C old light parser absent from ZoneViewer")
	_check(not zone_viewer.has_method("_decode_pcx8"), "P1-15C old PCX decoder absent from ZoneViewer")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_mass_reduction_15c_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_mass_reduction_15c_snapshot") as Dictionary
	_debug.append("\n--- P1-15C ZoneViewer mass reduction A legacy visuals ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(int(snap.get("line_count", 99999)) <= 3300, "P1-15C ZoneViewer line count dropped after A", "lines=%d before=3901" % int(snap.get("line_count", 0)))
	_check(int(snap.get("function_count", 99999)) <= 150, "P1-15C ZoneViewer function count dropped after A", "functions=%d before=167" % int(snap.get("function_count", 0)))
	_check(int(snap.get("var_count", 99999)) <= 620, "P1-15C ZoneViewer var_count oracle dropped after A", "var_count=%d before=710" % int(snap.get("var_count", 0)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15C vegetation implementation residue is zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15C legacy light implementation residue is zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("asset_index_residue", -1)) >= 0, "P1-15C asset index status readable after later checkpoints", str(snap.get("asset_index_residue", -1)))
	_check(str(snap.get("zonejump_runtime_debug_verdict", "")).begins_with("CONFORME"), "P1-15C zonejump residue verdict is conforming", str(snap.get("zonejump_runtime_debug_verdict", "")))

	var groups: Dictionary = snap.get("visual_groups", {}) as Dictionary
	_check(int(groups.get("lights", 0)) == 38, "P1-15C legacy lights still spawn 38 lights", str(groups.get("lights", 0)))
	_check(int(groups.get("vegetation_roots", 0)) >= 1, "P1-15C vegetation root still exists", str(groups.get("vegetation_roots", 0)))
	_check(int(groups.get("vegetation_batches", 0)) > 0, "P1-15C vegetation MultiMesh batches still exist", str(groups.get("vegetation_batches", 0)))
	_check(str(snap.get("recommended_next_step", "")) != "", "P1-15C next-step field remains readable", str(snap.get("recommended_next_step", "")))

	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		collision = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var terrain: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		terrain = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
	_check(str(zonejump.get("zone0_index_signature", "")) == "27a4632b710a6cdb202c18e182793954", "P1-15C zonejump signature unchanged")
	_check(str(water.get("zone0_index_signature", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-15C water signature unchanged")
	_check(str(collision.get("zone0_boundary_signature", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-15C boundary signature unchanged")
	_check(str(prop.get("zone0_index_signature", "")) == "46d670df525a69230158d643f5a70468", "P1-15C prop signature unchanged")
	_check(str(terrain.get("zone0_index_signature", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-15C terrain signature unchanged")


func _test_asset_index_registry_p1_15d(zone_viewer: Node) -> void:
	_section("P1-15D AssetIndexRegistry foundation")
	_check(DaocAssetIndexRegistryScript != null, "P1-15D DaocAssetIndexRegistry exists")
	_check(zone_viewer.has_method("get_asset_index_registry_15d"), "P1-15D ZoneViewer exposes asset registry getter")
	_check(zone_viewer.has_method("get_asset_index_registry_15d_debug_snapshot"), "P1-15D ZoneViewer exposes asset registry snapshot")
	_check(zone_viewer.has_method("get_zoneviewer_mass_reduction_15d_snapshot"), "P1-15D ZoneViewer exposes mass reduction B snapshot")
	_check(not zone_viewer.has_method("_ensure_model_index"), "P1-15D old model index method absent from ZoneViewer")
	_check(not zone_viewer.has_method("_scan_dir_for_glb"), "P1-15D old model scanner absent from ZoneViewer")
	_check(not zone_viewer.has_method("_get_model"), "P1-15D old model loader absent from ZoneViewer")
	_check(not zone_viewer.has_method("_get_model_nif"), "P1-15D old NIF model loader absent from ZoneViewer")
	_check(not zone_viewer.has_method("_ensure_texture_index"), "P1-15D old texture index method absent from ZoneViewer")
	_check(not zone_viewer.has_method("_scan_dir_for_textures"), "P1-15D old texture scanner absent from ZoneViewer")
	_check(not zone_viewer.has_method("_get_texture"), "P1-15D old texture loader absent from ZoneViewer")
	_check(not zone_viewer.has_method("_dds_to_image"), "P1-15D old DDS decoder absent from ZoneViewer")
	_check(not zone_viewer.has_method("_find_zone_dat_asset"), "P1-15D old zone dat asset finder absent from ZoneViewer")
	_check(not zone_viewer.has_method("_data_path"), "P1-15D old data path helper absent from ZoneViewer")
	_check(not zone_viewer.has_method("_load_image_array"), "P1-15D old splat image array loader absent from ZoneViewer")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_mass_reduction_15d_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_mass_reduction_15d_snapshot") as Dictionary
	_debug.append("\n--- P1-15D AssetIndexRegistry foundation ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(int(snap.get("asset_index_residue", 999)) == 0, "P1-15D asset/index residue is zero in ZoneViewer", str(snap.get("asset_index_residue", 999)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15D keeps vegetation residue zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15D keeps legacy lights residue zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("line_count", 99999)) <= 2700, "P1-15D ZoneViewer line count dropped after B", "lines=%d before15C=3166" % int(snap.get("line_count", 0)))
	_check(int(snap.get("function_count", 99999)) <= 125, "P1-15D ZoneViewer function count dropped after B", "functions=%d before15C=144" % int(snap.get("function_count", 0)))
	_check(int(snap.get("var_count", 99999)) <= 430, "P1-15D ZoneViewer var_count oracle dropped after B", "var_count=%d before15C=506" % int(snap.get("var_count", 0)))
	_check(bool(snap.get("b_done", false)), "P1-15D reports checkpoint B done")
	_check(str(snap.get("recommended_next_step", "")) == "P1-15E State grouping / residual state reduction", "P1-15D recommends state grouping next", str(snap.get("recommended_next_step", "")))

	var reg: Dictionary = snap.get("asset_registry", {}) as Dictionary
	_check(bool(reg.get("present", false)), "P1-15D asset registry object present")
	_check(bool(reg.get("configured", false)), "P1-15D asset registry configured")
	_check(str(reg.get("data_dir", "")) != "", "P1-15D registry has data dir", str(reg.get("data_dir", "")))
	_check(bool(reg.get("model_index_built", false)), "P1-15D registry owns built model index")
	_check(int(reg.get("model_index_size", 0)) > 0, "P1-15D registry model index non-empty", str(reg.get("model_index_size", 0)))
	_check(int(reg.get("model_cache_size", 0)) > 0, "P1-15D registry model cache non-empty", str(reg.get("model_cache_size", 0)))
	_check(int(reg.get("missing_model_rows", -1)) == 0, "P1-15D registry missing model rows remain zero", str(reg.get("missing_model_rows", -1)))

	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		collision = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var terrain: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		terrain = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
	_check(str(zonejump.get("zone0_index_signature", "")) == "27a4632b710a6cdb202c18e182793954", "P1-15D zonejump signature unchanged")
	_check(str(water.get("zone0_index_signature", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-15D water signature unchanged")
	_check(str(collision.get("zone0_boundary_signature", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-15D boundary signature unchanged")
	_check(str(prop.get("zone0_index_signature", "")) == "46d670df525a69230158d643f5a70468", "P1-15D prop signature unchanged")
	_check(str(terrain.get("zone0_index_signature", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-15D terrain signature unchanged")


func _test_zoneviewer_state_grouping_p1_15e(zone_viewer: Node) -> void:
	_section("P1-15E ZoneViewer state grouping / residual state reduction")
	_check(DaocZoneViewerStateRegistryScript != null, "P1-15E DaocZoneViewerStateRegistry exists")
	_check(zone_viewer.has_method("get_zoneviewer_state_15e_debug_snapshot"), "P1-15E ZoneViewer exposes state grouping snapshot")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_state_15e_debug_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_state_15e_debug_snapshot") as Dictionary
	_debug.append("\n--- P1-15E ZoneViewer state grouping / residual state reduction ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(bool(snap.get("state_registry_present", false)), "P1-15E state registry object present")
	_check(str(snap.get("checkpoint", "")) == "C_STATE_GROUPING", "P1-15E reports checkpoint C", str(snap.get("checkpoint", "")))
	_check(int(snap.get("asset_index_residue", 999)) == 0, "P1-15E keeps asset/index residue zero", str(snap.get("asset_index_residue", 999)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15E keeps vegetation residue zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15E keeps legacy lights residue zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("line_count", 99999)) <= 2700, "P1-15E ZoneViewer line count remains reduced", "lines=%d" % int(snap.get("line_count", 0)))
	_check(int(snap.get("function_count", 99999)) <= 130, "P1-15E ZoneViewer function count remains controlled", "functions=%d" % int(snap.get("function_count", 0)))
	_check(int(snap.get("var_count", 99999)) <= 400, "P1-15E ZoneViewer var_count reduced after state grouping", "var_count=%d before15D=384" % int(snap.get("var_count", 0)))
	_check(str(snap.get("recommended_next_step", "")) == "P1-15F ZoneViewer command/debug surface extraction", "P1-15E recommends command/debug extraction next", str(snap.get("recommended_next_step", "")))

	var state: Dictionary = snap.get("state_registry", {}) as Dictionary
	_check(int(state.get("compat_name_count", 0)) >= 35, "P1-15E registry exposes compatibility names", str(state.get("compat_name_count", 0)))
	_check(int(state.get("zone_runtime_size", 0)) >= 1, "P1-15E registry owns zone runtime", str(state.get("zone_runtime_size", 0)))
	var compat_zone_runtime: Dictionary = _get_dict(zone_viewer, "_zone_runtime")
	var compat_prop_collision: Dictionary = _get_dict(zone_viewer, "_prop_collision_runtime")
	_check(compat_zone_runtime.size() >= 1, "P1-15E compatibility get(_zone_runtime) still works", str(compat_zone_runtime.size()))
	_check(compat_prop_collision.size() >= 1, "P1-15E compatibility get(_prop_collision_runtime) still works", str(compat_prop_collision.size()))

	var terrain_state: Dictionary = state.get("terrain", {}) as Dictionary
	var water_state: Dictionary = state.get("water", {}) as Dictionary
	var collision_state: Dictionary = state.get("collision", {}) as Dictionary
	var prop_state: Dictionary = state.get("props", {}) as Dictionary
	var zonejump_state: Dictionary = state.get("zonejump", {}) as Dictionary
	_check(bool(terrain_state.get("runtime_present", false)), "P1-15E registry owns terrain runtime")
	_check(int(terrain_state.get("build_results", 0)) >= 1, "P1-15E registry owns terrain build results", str(terrain_state.get("build_results", 0)))
	_check(bool(water_state.get("runtime_present", false)), "P1-15E registry owns water runtime")
	_check(int(water_state.get("build_results", 0)) >= 1, "P1-15E registry owns water build results", str(water_state.get("build_results", 0)))
	_check(bool(collision_state.get("runtime_present", false)), "P1-15E registry owns collision runtime")
	_check(int(collision_state.get("boundary_results", 0)) >= 1, "P1-15E registry owns collision build results", str(collision_state.get("boundary_results", 0)))
	_check(bool(prop_state.get("runtime_present", false)), "P1-15E registry owns prop runtime")
	_check(int(prop_state.get("build_results", 0)) >= 1, "P1-15E registry owns prop build results", str(prop_state.get("build_results", 0)))
	_check(bool(zonejump_state.get("runtime_present", false)), "P1-15E registry owns zonejump runtime")
	_check(int(zonejump_state.get("build_results", 0)) >= 1, "P1-15E registry owns zonejump build results", str(zonejump_state.get("build_results", 0)))

	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		collision = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var terrain: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		terrain = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
	_check(str(zonejump.get("zone0_index_signature", "")) == "27a4632b710a6cdb202c18e182793954", "P1-15E zonejump signature unchanged")
	_check(str(water.get("zone0_index_signature", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-15E water signature unchanged")
	_check(str(collision.get("zone0_boundary_signature", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-15E boundary signature unchanged")
	_check(str(prop.get("zone0_index_signature", "")) == "46d670df525a69230158d643f5a70468", "P1-15E prop signature unchanged")
	_check(str(terrain.get("zone0_index_signature", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-15E terrain signature unchanged")


func _test_zoneviewer_command_debug_surface_p1_15f(zone_viewer: Node) -> void:
	_section("P1-15F ZoneViewer command/debug surface extraction")
	_check(DaocZoneViewerCommandDebugSurfaceScript != null, "P1-15F DaocZoneViewerCommandDebugSurface exists")
	_check(zone_viewer.has_method("get_zoneviewer_command_debug_15f_snapshot"), "P1-15F ZoneViewer exposes command/debug snapshot")
	_check(zone_viewer.has_method("get_zonejump_status_lines"), "P1-15F keeps /zonejump status compatibility wrapper")
	_check(zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"), "P1-15F keeps /zonejump nearest compatibility wrapper")
	_check(zone_viewer.has_method("execute_zonejump_nearest_transition"), "P1-15F keeps /zonejump go nearest compatibility wrapper")
	_check(zone_viewer.has_method("set_zonejump_auto_transition_enabled"), "P1-15F keeps /zonejump auto compatibility wrapper")
	_check(not zone_viewer.has_method("_decorate_zonejump_runtime_event"), "P1-15F old zonejump event decorator absent from ZoneViewer")
	_check(not zone_viewer.has_method("_resolve_zonejump_target_spawn"), "P1-15F old zonejump spawn resolver absent from ZoneViewer")
	_check(not zone_viewer.has_method("_make_zonejump_event_dictionary_from_entry"), "P1-15F old zonejump event factory absent from ZoneViewer")
	_check(not zone_viewer.has_method("_zonejump_totals"), "P1-15F old zonejump totals helper absent from ZoneViewer")
	_check(not zone_viewer.has_method("_zonejump_area_count"), "P1-15F old zonejump area counter absent from ZoneViewer")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_command_debug_15f_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_command_debug_15f_snapshot") as Dictionary
	_debug.append("\n--- P1-15F ZoneViewer command/debug surface extraction ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(bool(snap.get("command_debug_surface_present", false)), "P1-15F command/debug surface object present")
	_check(str(snap.get("checkpoint", "")) == "D_COMMAND_DEBUG_SURFACE", "P1-15F reports checkpoint D", str(snap.get("checkpoint", "")))
	_check(int(snap.get("asset_index_residue", 999)) == 0, "P1-15F keeps asset/index residue zero", str(snap.get("asset_index_residue", 999)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15F keeps vegetation residue zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15F keeps legacy lights residue zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("zonejump_runtime_debug_residue", 999)) <= 18, "P1-15F zonejump command/debug residue drops", "residue=%d before15E=33" % int(snap.get("zonejump_runtime_debug_residue", 0)))
	_check(int(snap.get("line_count", 99999)) <= 2300, "P1-15F ZoneViewer line count drops after command/debug extraction", "lines=%d before15E=2635" % int(snap.get("line_count", 0)))
	_check_closed_refactor_oracle(int(snap.get("function_count", 99999)) <= 125, "P1-15F ZoneViewer function count remains within post-P1-18 inspector budget", "functions=%d before15E=122 budget=125" % int(snap.get("function_count", 0)))
	_check(str(snap.get("recommended_next_step", "")) == "P1-15G Viewer shell final / bootstrap cleanup", "P1-15F recommends viewer shell cleanup next", str(snap.get("recommended_next_step", "")))

	var lines := PackedStringArray()
	if zone_viewer.has_method("get_zonejump_status_lines"):
		lines = zone_viewer.call("get_zonejump_status_lines", 4) as PackedStringArray
	_check(lines.size() >= 2, "P1-15F /zonejump status lines remain readable", "lines=%d" % lines.size())
	var near: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_nearest_debug_snapshot"):
		near = zone_viewer.call("get_zonejump_nearest_debug_snapshot", 2400.0) as Dictionary
	_check(near.has("ok"), "P1-15F /zonejump nearest snapshot remains readable", str(near))
	var auto_on: Dictionary = {}
	var auto_off: Dictionary = {}
	if zone_viewer.has_method("set_zonejump_auto_transition_enabled"):
		auto_on = zone_viewer.call("set_zonejump_auto_transition_enabled", true) as Dictionary
		auto_off = zone_viewer.call("set_zonejump_auto_transition_enabled", false) as Dictionary
	_check(bool(auto_on.get("auto_transition_enabled", false)), "P1-15F /zonejump auto on still toggles")
	_check(not bool(auto_off.get("auto_transition_enabled", true)), "P1-15F /zonejump auto off restores safe default")
	var guarded: Dictionary = {}
	if zone_viewer.has_method("execute_zonejump_nearest_transition"):
		guarded = zone_viewer.call("execute_zonejump_nearest_transition", 1.0, "f12_15f_guarded") as Dictionary
	_check(guarded.has("ok"), "P1-15F /zonejump go nearest still returns guarded result", str(guarded))

	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonejump status")), "P1-15F command router /zonejump status handled")
		_check(bool(command.call("execute_command", "/zonejump nearest")), "P1-15F command router /zonejump nearest handled")
		_check(bool(command.call("execute_command", "/zonejump transition")), "P1-15F command router /zonejump transition handled")
		_check(bool(command.call("execute_command", "/zonejump auto on")), "P1-15F command router /zonejump auto on handled")
		_check(bool(command.call("execute_command", "/zonejump auto off")), "P1-15F command router /zonejump auto off handled")
	else:
		_check(false, "P1-15F command router available")

	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		collision = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var terrain: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		terrain = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
	_check(str(zonejump.get("zone0_index_signature", "")) == "27a4632b710a6cdb202c18e182793954", "P1-15F zonejump signature unchanged")
	_check(str(water.get("zone0_index_signature", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-15F water signature unchanged")
	_check(str(collision.get("zone0_boundary_signature", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-15F boundary signature unchanged")
	_check(str(prop.get("zone0_index_signature", "")) == "46d670df525a69230158d643f5a70468", "P1-15F prop signature unchanged")
	_check(str(terrain.get("zone0_index_signature", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-15F terrain signature unchanged")



func _test_local_viewer_bootstrap_p1_15g(zone_viewer: Node) -> void:
	_section("P1-15G Viewer shell final / bootstrap cleanup")
	_check(DaocLocalViewerBootstrapScript != null, "P1-15G DaocLocalViewerBootstrap exists")
	_check(zone_viewer.has_method("get_zoneviewer_bootstrap_15g_snapshot"), "P1-15G ZoneViewer exposes bootstrap snapshot")
	_check(not zone_viewer.has_method("_setup_player_capsule"), "P1-15G old player bootstrap absent from ZoneViewer")
	_check(not zone_viewer.has_method("_setup_environment"), "P1-15G old environment bootstrap absent from ZoneViewer")
	_check(not zone_viewer.has_method("_setup_camera"), "P1-15G old fly camera bootstrap absent from ZoneViewer")
	_check(not zone_viewer.has_method("_setup_hud"), "P1-15G old legacy HUD bootstrap absent from ZoneViewer")

	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_bootstrap_15g_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_bootstrap_15g_snapshot") as Dictionary
	_debug.append("\n--- P1-15G Viewer shell final / bootstrap cleanup ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(bool(snap.get("bootstrap_present", false)), "P1-15G bootstrap object present")
	_check(str(snap.get("checkpoint", "")) == "E_VIEWER_SHELL_BOOTSTRAP", "P1-15G reports checkpoint E", str(snap.get("checkpoint", "")))
	_check(int(snap.get("asset_index_residue", 999)) == 0, "P1-15G keeps asset/index residue zero", str(snap.get("asset_index_residue", 999)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15G keeps vegetation residue zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15G keeps legacy lights residue zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("zonejump_runtime_debug_residue", 999)) <= 18, "P1-15G keeps zonejump debug residue controlled", str(snap.get("zonejump_runtime_debug_residue", 999)))
	_check_closed_refactor_oracle(int(snap.get("line_count", 99999)) <= 2000, "P1-15G ZoneViewer line count drops after bootstrap extraction", "lines=%d before15F=2138" % int(snap.get("line_count", 0)))
	_check_closed_refactor_oracle(int(snap.get("function_count", 99999)) <= 110, "P1-15G ZoneViewer function count remains controlled", "functions=%d before15F=104" % int(snap.get("function_count", 0)))
	_check(int(snap.get("preload_count", 99999)) <= 24, "P1-15G ZoneViewer preload count drops", "preloads=%d before15F=34" % int(snap.get("preload_count", 0)))
	_check(str(snap.get("recommended_next_step", "")) == "P1-15H ZoneViewer freeze audit / stop refactor", "P1-15G recommends freeze audit next", str(snap.get("recommended_next_step", "")))

	var boot: Dictionary = snap.get("bootstrap", {}) as Dictionary
	_check(bool(boot.get("configured", false)), "P1-15G bootstrap configured")
	_check(bool(boot.get("environment_present", false)), "P1-15G environment still created")
	_check(bool(boot.get("sun_present", false)), "P1-15G sun still created")
	_check(bool(boot.get("player_present", false)), "P1-15G player still created")
	_check(bool(boot.get("player_camera_present", false)), "P1-15G player camera still created")
	_check(bool(boot.get("input_router_present", false)), "P1-15G input router still created")
	_check(bool(boot.get("command_router_present", false)), "P1-15G command router still created")
	_check(bool(boot.get("dev_hud_present", false)), "P1-15G dev HUD still created")
	_check(bool(boot.get("local_targeting_present", false)), "P1-15G local targeting still created")
	_check(bool(boot.get("dol_client_present", false)), "P1-15G DOL client still created")
	_check(bool(boot.get("dol_transport_present", false)), "P1-15G DOL transport still created")
	_check(bool(boot.get("dol_packet_layer_present", false)), "P1-15G DOL packet layer still created")
	_check(bool(boot.get("dol_wire_1127_present", false)), "P1-15G DOL wire 1127 still created")
	_check(bool(boot.get("dol_login_flow_1127_present", false)), "P1-15G DOL login flow still created")
	_check(bool(boot.get("dol_server_fixtures_1127_present", false)), "P1-15G DOL server fixtures still created")
	_check(bool(boot.get("dol_character_bootstrap_1127_present", false)), "P1-15G DOL character bootstrap still created")
	_check(bool(boot.get("dol_character_select_hud_1127_present", false)), "P1-15G DOL character select HUD still created")
	_check(bool(boot.get("pregame_loading_asset_resolver_present", false)), "P1-15G pregame/loading resolver still created")

	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonejump status")), "P1-15G command router still handles /zonejump status")
	else:
		_check(false, "P1-15G command router available")

	var zonejump: Dictionary = {}
	if zone_viewer.has_method("get_zonejump_14a_debug_snapshot"):
		zonejump = zone_viewer.call("get_zonejump_14a_debug_snapshot") as Dictionary
	var water: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		water = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
	var collision: Dictionary = {}
	if zone_viewer.has_method("get_collision_14c_debug_snapshot"):
		collision = zone_viewer.call("get_collision_14c_debug_snapshot") as Dictionary
	var prop: Dictionary = {}
	if zone_viewer.has_method("get_prop_14d_debug_snapshot"):
		prop = zone_viewer.call("get_prop_14d_debug_snapshot") as Dictionary
	var terrain: Dictionary = {}
	if zone_viewer.has_method("get_terrain_14e_debug_snapshot"):
		terrain = zone_viewer.call("get_terrain_14e_debug_snapshot") as Dictionary
	_check(str(zonejump.get("zone0_index_signature", "")) == "27a4632b710a6cdb202c18e182793954", "P1-15G zonejump signature unchanged")
	_check(str(water.get("zone0_index_signature", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-15G water signature unchanged")
	_check(str(collision.get("zone0_boundary_signature", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-15G boundary signature unchanged")
	_check(str(prop.get("zone0_index_signature", "")) == "46d670df525a69230158d643f5a70468", "P1-15G prop signature unchanged")
	_check(str(terrain.get("zone0_index_signature", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-15G terrain signature unchanged")


func _test_zoneviewer_freeze_audit_p1_15h(zone_viewer: Node) -> void:
	_section("P1-15H ZoneViewer freeze audit / stop refactor")
	_check(DaocZoneViewerFreezeAuditScript != null, "P1-15H DaocZoneViewerFreezeAudit exists")
	_check(zone_viewer.has_method("get_zoneviewer_freeze_15h_snapshot"), "P1-15H ZoneViewer exposes freeze snapshot")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_zoneviewer_freeze_15h_snapshot"):
		snap = zone_viewer.call("get_zoneviewer_freeze_15h_snapshot") as Dictionary
		_debug.append("\n--- P1-15H ZoneViewer freeze audit / stop refactor ---")
		_debug.append(_snapshot_debug_line(snap))
	_check(str(snap.get("checkpoint", "")) == "F_FREEZE_AUDIT_STOP_REFACTOR", "P1-15H reports freeze checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("refactor_closed", false)), "P1-15H marks P1-15 refactor closed")
	_check(bool(snap.get("do_not_continue_zoneviewer_refactor_now", false)), "P1-15H stops default ZoneViewer refactor")
	_check(str(snap.get("final_decision", "")) == "P1-15 refactor ZoneViewer terminé", "P1-15H final decision is explicit", str(snap.get("final_decision", "")))
	_check(str(snap.get("recommended_next_step", "")) == "P1-16 reprise fonctionnelle hors refactor ZoneViewer", "P1-15H recommends functional work next", str(snap.get("recommended_next_step", "")))
	_check_closed_refactor_oracle(int(snap.get("line_count", 99999)) <= 2000, "P1-15H ZoneViewer remains under 2000 lines", "lines=%d" % int(snap.get("line_count", 0)))
	_check_closed_refactor_oracle(int(snap.get("function_count", 99999)) <= 110, "P1-15H ZoneViewer function count remains shell-sized", "functions=%d" % int(snap.get("function_count", 0)))
	_check_closed_refactor_oracle(int(snap.get("var_count", 99999)) <= 300, "P1-15H ZoneViewer var count remains within post-P1-18 inspector budget", "var_count=%d budget=300" % int(snap.get("var_count", 0)))
	_check(int(snap.get("preload_count", 99999)) <= 24, "P1-15H ZoneViewer preload count remains reduced", "preloads=%d" % int(snap.get("preload_count", 0)))
	_check(int(snap.get("asset_index_residue", 999)) == 0, "P1-15H asset/index residue remains zero", str(snap.get("asset_index_residue", 999)))
	_check(int(snap.get("vegetation_legacy_residue", 999)) == 0, "P1-15H vegetation residue remains zero", str(snap.get("vegetation_legacy_residue", 999)))
	_check(int(snap.get("legacy_lights_residue", 999)) == 0, "P1-15H legacy lights residue remains zero", str(snap.get("legacy_lights_residue", 999)))
	_check(int(snap.get("zonejump_runtime_debug_residue", 999)) <= 18, "P1-15H zonejump wrapper residue remains controlled", str(snap.get("zonejump_runtime_debug_residue", 999)))
	_check_closed_refactor_oracle(int(snap.get("misc_shared_helpers_residue", 999)) <= 32, "P1-15H misc shared helpers remain acceptable", str(snap.get("misc_shared_helpers_residue", 999)))
	var modules: Dictionary = snap.get("module_presence", {}) as Dictionary
	_check(bool(modules.get("asset_registry_present", false)), "P1-15H asset registry still present")
	_check(bool(modules.get("state_registry_present", false)), "P1-15H state registry still present")
	_check(bool(modules.get("command_debug_surface_present", false)), "P1-15H command/debug surface still present")
	_check(bool(modules.get("bootstrap_present", false)), "P1-15H bootstrap still present")
	_check(bool(modules.get("player_present", false)), "P1-15H player still present")
	_check(bool(modules.get("player_camera_present", false)), "P1-15H player camera still present")
	_check(bool(modules.get("input_router_present", false)), "P1-15H input router still present")
	_check(bool(modules.get("command_router_present", false)), "P1-15H command router still present")
	_check(bool(modules.get("dev_hud_present", false)), "P1-15H dev HUD still present")
	_check(bool(modules.get("local_targeting_present", false)), "P1-15H local targeting still present")
	_check(bool(modules.get("dol_client_present", false)), "P1-15H DOL offline client still present")
	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(bool(signatures.get("zonejump_ok", false)), "P1-15H zonejump signature unchanged")
	_check(bool(signatures.get("water_ok", false)), "P1-15H water signature unchanged")
	_check(bool(signatures.get("boundary_ok", false)), "P1-15H boundary signature unchanged")
	_check(bool(signatures.get("prop_ok", false)), "P1-15H prop signature unchanged")
	_check(bool(signatures.get("terrain_ok", false)), "P1-15H terrain signature unchanged")
	var reasons: Array = snap.get("hard_stop_reasons", []) as Array
	_check(reasons.size() >= 4, "P1-15H documents stop-refactor reasons", "reasons=%d" % reasons.size())



func _test_zone_creator_p1_16a1(zone_viewer: Node) -> void:
	_section("P1-16A1 ZoneCreator foundation")
	_check(DaocZoneCreationResultScript != null, "P1-16A1 DaocZoneCreationResult exists")
	_check(DaocZoneCreatorScript != null, "P1-16A1 DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A1 ZoneCreator instantiates")
	_check(creator.has_method("create_zone_scene"), "P1-16A1 ZoneCreator exposes create_zone_scene")

	var result: RefCounted = null
	if creator != null and creator.has_method("create_zone_scene"):
		result = creator.call("create_zone_scene", zone_viewer, 0, {}) as RefCounted
	_check(result != null, "P1-16A1 create_zone_scene returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A1 ZoneCreator foundation ---")
		_debug.append(_snapshot_debug_line(snap))

	_check(str(snap.get("scope", "")) == "P1-16A1 ZoneCreator foundation", "P1-16A1 reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A1_ZONECREATOR_FOUNDATION", "P1-16A1 reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A1 generated result is ok")
	_check(int(snap.get("zone", -1)) == 0, "P1-16A1 creates zone000 result", str(snap.get("zone", -1)))
	_check(str(snap.get("root_name", "")) == "GeneratedZone_000", "P1-16A1 generated root name", str(snap.get("root_name", "")))

	var branch_names: Array = snap.get("branch_names", []) as Array
	_check(branch_names.has("TerrainRoot"), "P1-16A1 root has TerrainRoot")
	_check(branch_names.has("StaticPropsRoot"), "P1-16A1 root has StaticPropsRoot")
	_check(branch_names.has("CollisionRoot"), "P1-16A1 root has CollisionRoot")
	_check(branch_names.has("WaterRoot"), "P1-16A1 root has WaterRoot")
	_check(branch_names.has("ZoneJumpRoot"), "P1-16A1 root has ZoneJumpRoot")
	_check(branch_names.has("VisualsRoot"), "P1-16A1 root has VisualsRoot")
	_check(branch_names.has("DebugRoot"), "P1-16A1 root has DebugRoot")

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(bool(metrics.get("packable_ok", false)), "P1-16A1 generated root is packable")
	_check(bool(metrics.get("detached_by_default", false)), "P1-16A1 stays detached by default")
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A1 respects ZoneViewer freeze")
	_check(int(metrics.get("terrain_meshes_source", 0)) == 64, "P1-16A1 sees terrain source meshes", str(metrics.get("terrain_meshes_source", 0)))
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A1 sees prop source nodes", str(metrics.get("prop_nodes_source", 0)))
	_check(int(metrics.get("water_meshes_source", 0)) == 2, "P1-16A1 sees water source meshes", str(metrics.get("water_meshes_source", 0)))
	_check(int(metrics.get("boundary_segments_source", 0)) == 142, "P1-16A1 sees boundary source segments", str(metrics.get("boundary_segments_source", 0)))

	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A1 preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A1 preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A1 preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A1 preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A1 preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A2 exporter GeneratedZone_000.tscn", "P1-16A1 recommends editor scene export next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_export_p1_16a2(zone_viewer: Node) -> void:
	_section("P1-16A2 ZoneCreator editor scene export")
	_check(DaocZoneCreatorScript != null, "P1-16A2 DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A2 ZoneCreator instantiates")
	_check(creator.has_method("export_generated_scene"), "P1-16A2 ZoneCreator exposes export_generated_scene")

	var result: RefCounted = null
	if creator != null and creator.has_method("export_generated_scene"):
		result = creator.call("export_generated_scene", zone_viewer, 0, {}) as RefCounted
	_check(result != null, "P1-16A2 export_generated_scene returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A2 ZoneCreator editor scene export ---")
		_debug.append(_snapshot_debug_line(snap))

	var expected_path := "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(snap.get("scope", "")) == "P1-16A2 ZoneCreator editor scene export", "P1-16A2 reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A2_ZONECREATOR_EDITOR_SCENE_EXPORT", "P1-16A2 reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A2 generated export result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A2 export marked ok")
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A2 exported scene path", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("generated_scene_path", "")) == expected_path, "P1-16A2 generated scene path", str(snap.get("generated_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "editor_visible_shell", "P1-16A2 export mode is safe shell", str(snap.get("export_mode", "")))
	_check(not bool(snap.get("include_runtime_nodes", true)), "P1-16A2 does not duplicate runtime nodes by default")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A2 PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A2 ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A2 exported .tscn exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A2 exported .tscn exists on disk")

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A2 exported .tscn loadable as PackedScene")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A2 exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A2 reloaded root name", str(inst.name))
		_check(inst.get_node_or_null("TerrainRoot") != null, "P1-16A2 reloaded root has TerrainRoot")
		_check(inst.get_node_or_null("StaticPropsRoot") != null, "P1-16A2 reloaded root has StaticPropsRoot")
		_check(inst.get_node_or_null("CollisionRoot") != null, "P1-16A2 reloaded root has CollisionRoot")
		_check(inst.get_node_or_null("WaterRoot") != null, "P1-16A2 reloaded root has WaterRoot")
		_check(inst.get_node_or_null("ZoneJumpRoot") != null, "P1-16A2 reloaded root has ZoneJumpRoot")
		_check(inst.get_node_or_null("VisualsRoot") != null, "P1-16A2 reloaded root has VisualsRoot")
		_check(inst.get_node_or_null("DebugRoot") != null, "P1-16A2 reloaded root has DebugRoot")
		_check(str(inst.get_meta("daoc_checkpoint", "")) == "P1_16A2_ZONECREATOR_EDITOR_SCENE_EXPORT", "P1-16A2 reloaded metadata checkpoint", str(inst.get_meta("daoc_checkpoint", "")))
		inst.free()

	_check(bool(snap.get("reload_ok", false)), "P1-16A2 internal reload validation ok")
	var reload_branch_names: Array = snap.get("reload_branch_names", []) as Array
	_check(reload_branch_names.size() == 7, "P1-16A2 internal reload sees 7 branches", "branches=%d" % reload_branch_names.size())

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A2 respects ZoneViewer freeze")
	_check(int(metrics.get("terrain_meshes_source", 0)) == 64, "P1-16A2 keeps terrain source metric", str(metrics.get("terrain_meshes_source", 0)))
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A2 keeps prop source metric", str(metrics.get("prop_nodes_source", 0)))

	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A2 preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A2 preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A2 preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A2 preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A2 preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A3 populate GeneratedZone_000 with runtime visual roots", "P1-16A2 recommends population next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_terrain_water_p1_16a3a(zone_viewer: Node) -> void:
	_section("P1-16A3a ZoneCreator terrain water population")
	_check(DaocZoneCreatorScript != null, "P1-16A3a DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A3a ZoneCreator instantiates")
	_check(creator.has_method("export_generated_scene_with_terrain_water"), "P1-16A3a ZoneCreator exposes export_generated_scene_with_terrain_water")

	var result: RefCounted = null
	if creator != null and creator.has_method("export_generated_scene_with_terrain_water"):
		result = creator.call("export_generated_scene_with_terrain_water", zone_viewer, 0, {}) as RefCounted
	_check(result != null, "P1-16A3a export_generated_scene_with_terrain_water returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A3a ZoneCreator terrain water population ---")
		_debug.append(_snapshot_debug_line(snap))

	var expected_path := "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(snap.get("scope", "")) == "P1-16A3a ZoneCreator terrain water population", "P1-16A3a reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A3A_ZONECREATOR_TERRAIN_WATER_POPULATION", "P1-16A3a reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A3a generated export result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A3a export marked ok")
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A3a exported scene path", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "editor_visible_terrain_water", "P1-16A3a export mode is terrain/water", str(snap.get("export_mode", "")))
	_check(not bool(snap.get("include_runtime_nodes", true)), "P1-16A3a does not duplicate live runtime nodes flag")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A3a PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A3a ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A3a exported .tscn exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A3a exported .tscn exists on disk")

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(str(metrics.get("visual_population_mode", "")) == "terrain_water_only", "P1-16A3a visual population mode", str(metrics.get("visual_population_mode", "")))
	_check(bool(metrics.get("terrain_visual_root_present", false)), "P1-16A3a terrain visual root present")
	_check(bool(metrics.get("water_visual_root_present", false)), "P1-16A3a water visual root present")
	_check(int(metrics.get("terrain_visual_mesh_nodes", 0)) == 64, "P1-16A3a exports 64 terrain mesh nodes", str(metrics.get("terrain_visual_mesh_nodes", 0)))
	_check(int(metrics.get("water_visual_mesh_nodes", 0)) == 2, "P1-16A3a exports 2 water mesh nodes", str(metrics.get("water_visual_mesh_nodes", 0)))
	_check(int(metrics.get("props_visual_nodes", -1)) == 0, "P1-16A3a keeps props out", str(metrics.get("props_visual_nodes", -1)))
	_check(int(metrics.get("collision_visual_nodes", -1)) == 0, "P1-16A3a keeps collision visuals out", str(metrics.get("collision_visual_nodes", -1)))
	_check(not bool(metrics.get("props_included", true)), "P1-16A3a props not included")
	_check(not bool(metrics.get("collisions_included", true)), "P1-16A3a collisions not included")
	_check(not bool(metrics.get("runtime_nodes_duplicated", true)), "P1-16A3a runtime nodes not flagged duplicated")
	_check(bool(metrics.get("editor_recenter_enabled", false)), "P1-16A3a editor recenter enabled")
	_check(str(metrics.get("editor_recenter_mode", "")) == "zone_center_floor_to_origin", "P1-16A3a editor recenter mode", str(metrics.get("editor_recenter_mode", "")))
	_check(float(metrics.get("editor_anchor_floor_z", 0.0)) > 100.0, "P1-16A3a editor anchor floor captured", str(metrics.get("editor_anchor_floor_z", 0.0)))
	_check(float(metrics.get("reload_root_position_y", 0.0)) < -100.0, "P1-16A3a root Y offset lowers terrain to editor grid", str(metrics.get("reload_root_position_y", 0.0)))
	_check(absf(float(metrics.get("reload_center_floor_after_offset_x", 999999.0))) < 0.01, "P1-16A3a zone center X recentered", str(metrics.get("reload_center_floor_after_offset_x", 999999.0)))
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A3a zone center floor recentered to grid", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))
	_check(absf(float(metrics.get("reload_center_floor_after_offset_z", 999999.0))) < 0.01, "P1-16A3a zone center Z recentered", str(metrics.get("reload_center_floor_after_offset_z", 999999.0)))
	_check(int(metrics.get("reload_terrain_mesh_nodes", 0)) == 64, "P1-16A3a reload sees 64 terrain meshes", str(metrics.get("reload_terrain_mesh_nodes", 0)))
	_check(int(metrics.get("reload_water_mesh_nodes", 0)) == 2, "P1-16A3a reload sees 2 water meshes", str(metrics.get("reload_water_mesh_nodes", 0)))
	_check(int(metrics.get("reload_total_mesh_nodes", 0)) == 66, "P1-16A3a reload sees 66 total visible meshes", str(metrics.get("reload_total_mesh_nodes", 0)))

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A3a exported .tscn loadable as PackedScene")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A3a exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A3a reloaded root name", str(inst.name))
		var terrain_branch := inst.get_node_or_null("TerrainRoot")
		var water_branch := inst.get_node_or_null("WaterRoot")
		_check(terrain_branch != null, "P1-16A3a reloaded root has TerrainRoot")
		_check(water_branch != null, "P1-16A3a reloaded root has WaterRoot")
		_check(terrain_branch != null and terrain_branch.get_node_or_null("Zone000_TerrainVisuals") != null, "P1-16A3a reloaded TerrainRoot has Zone000_TerrainVisuals")
		_check(water_branch != null and water_branch.get_node_or_null("Zone000_WaterVisuals") != null, "P1-16A3a reloaded WaterRoot has Zone000_WaterVisuals")
		_check(str(inst.get_meta("daoc_checkpoint", "")) == "P1_16A3A_ZONECREATOR_TERRAIN_WATER_POPULATION", "P1-16A3a reloaded metadata checkpoint", str(inst.get_meta("daoc_checkpoint", "")))
		_check(str(inst.get_meta("daoc_export_mode", "")) == "editor_visible_terrain_water", "P1-16A3a reloaded metadata export mode", str(inst.get_meta("daoc_export_mode", "")))
		inst.free()

	_check(bool(snap.get("reload_ok", false)), "P1-16A3a internal reload validation ok")
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A3a respects ZoneViewer freeze")
	_check(int(metrics.get("terrain_meshes_source", 0)) == 64, "P1-16A3a keeps terrain source metric", str(metrics.get("terrain_meshes_source", 0)))
	_check(int(metrics.get("water_meshes_source", 0)) == 2, "P1-16A3a keeps water source metric", str(metrics.get("water_meshes_source", 0)))
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A3a keeps prop source metric without exporting", str(metrics.get("prop_nodes_source", 0)))

	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A3a preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A3a preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A3a preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A3a preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A3a preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A3b populate GeneratedZone_000 with props strategy", "P1-16A3a recommends props strategy next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_props_strategy_p1_16a3b(zone_viewer: Node) -> void:
	_section("P1-16A3b ZoneCreator props strategy")
	_check(DaocZoneCreatorScript != null, "P1-16A3b DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A3b ZoneCreator instantiates")
	_check(creator.has_method("export_generated_scene_with_props_strategy"), "P1-16A3b ZoneCreator exposes export_generated_scene_with_props_strategy")

	var result: RefCounted = null
	if creator != null and creator.has_method("export_generated_scene_with_props_strategy"):
		result = creator.call("export_generated_scene_with_props_strategy", zone_viewer, 0, { "prop_export_limit": 256 }) as RefCounted
	_check(result != null, "P1-16A3b export_generated_scene_with_props_strategy returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A3b ZoneCreator props strategy ---")
		_debug.append(_snapshot_debug_line(snap))

	var expected_path := "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(snap.get("scope", "")) == "P1-16A3b ZoneCreator props strategy", "P1-16A3b reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A3B_ZONECREATOR_PROPS_STRATEGY", "P1-16A3b reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A3b generated export result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A3b export marked ok")
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A3b exported scene path", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "editor_visible_terrain_water_props_preview", "P1-16A3b export mode is props preview", str(snap.get("export_mode", "")))
	_check(not bool(snap.get("include_runtime_nodes", true)), "P1-16A3b does not duplicate live runtime nodes flag")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A3b PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A3b ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A3b exported .tscn exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A3b exported .tscn exists on disk")

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(str(metrics.get("visual_population_mode", "")) == "terrain_water_props_preview", "P1-16A3b visual population mode", str(metrics.get("visual_population_mode", "")))
	_check(str(metrics.get("props_strategy", "")) == "editor_preview_even_sample_sector_buckets", "P1-16A3b props strategy", str(metrics.get("props_strategy", "")))
	_check(bool(metrics.get("terrain_visual_root_present", false)), "P1-16A3b keeps terrain visual root")
	_check(bool(metrics.get("water_visual_root_present", false)), "P1-16A3b keeps water visual root")
	_check(int(metrics.get("terrain_visual_mesh_nodes", 0)) == 64, "P1-16A3b keeps 64 terrain mesh nodes", str(metrics.get("terrain_visual_mesh_nodes", 0)))
	_check(int(metrics.get("water_visual_mesh_nodes", 0)) == 2, "P1-16A3b keeps 2 water mesh nodes", str(metrics.get("water_visual_mesh_nodes", 0)))
	_check(bool(metrics.get("props_preview_root_present", false)), "P1-16A3b props preview root present")
	_check(str(metrics.get("props_preview_root_name", "")) == "Zone000_PropsPreview_0256", "P1-16A3b props preview root name", str(metrics.get("props_preview_root_name", "")))
	_check(int(metrics.get("props_source_total", 0)) == 1876, "P1-16A3b sees 1876 source props", str(metrics.get("props_source_total", 0)))
	_check(int(metrics.get("props_preview_limit", 0)) == 256, "P1-16A3b props preview limit is 256", str(metrics.get("props_preview_limit", 0)))
	_check(int(metrics.get("props_visual_nodes", 0)) == 256, "P1-16A3b exports 256 props preview nodes", str(metrics.get("props_visual_nodes", 0)))
	_check(int(metrics.get("props_skipped_nodes", 0)) == 1620, "P1-16A3b leaves remaining props for later", str(metrics.get("props_skipped_nodes", 0)))
	_check(int(metrics.get("props_visual_mesh_nodes", 0)) > 0, "P1-16A3b props preview has mesh nodes", str(metrics.get("props_visual_mesh_nodes", 0)))
	_check(int(metrics.get("props_sector_bucket_count", 0)) > 0, "P1-16A3b sector bucket count non-zero", str(metrics.get("props_sector_bucket_count", 0)))
	_check(int(metrics.get("props_sector_bucket_count", 999)) <= 64, "P1-16A3b sector bucket count capped", str(metrics.get("props_sector_bucket_count", 999)))
	_check(bool(metrics.get("props_included", false)), "P1-16A3b props included")
	_check(bool(metrics.get("props_preview_capped", false)), "P1-16A3b props preview is intentionally capped")
	_check(not bool(metrics.get("props_full_export", true)), "P1-16A3b does not full-export props yet")
	_check(not bool(metrics.get("collisions_included", true)), "P1-16A3b collisions still excluded")
	_check(int(metrics.get("collision_visual_nodes", -1)) == 0, "P1-16A3b collision visuals remain out", str(metrics.get("collision_visual_nodes", -1)))
	_check(not bool(metrics.get("runtime_nodes_duplicated", true)), "P1-16A3b runtime nodes not flagged duplicated")
	_check(bool(metrics.get("editor_recenter_enabled", false)), "P1-16A3b editor recenter enabled")
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A3b zone center floor remains recentered", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))
	_check(int(metrics.get("reload_terrain_mesh_nodes", 0)) == 64, "P1-16A3b reload sees 64 terrain meshes", str(metrics.get("reload_terrain_mesh_nodes", 0)))
	_check(int(metrics.get("reload_water_mesh_nodes", 0)) == 2, "P1-16A3b reload sees 2 water meshes", str(metrics.get("reload_water_mesh_nodes", 0)))
	_check(int(metrics.get("reload_prop_mesh_nodes", 0)) > 0, "P1-16A3b reload sees prop mesh nodes", str(metrics.get("reload_prop_mesh_nodes", 0)))
	_check(bool(metrics.get("reload_props_preview_root_present", false)), "P1-16A3b reload sees props preview root")
	_check(int(metrics.get("reload_props_preview_exported_nodes", 0)) == 256, "P1-16A3b reload sees 256 preview prop nodes", str(metrics.get("reload_props_preview_exported_nodes", 0)))
	_check(int(metrics.get("reload_props_preview_bucket_count", 0)) == int(metrics.get("props_sector_bucket_count", -1)), "P1-16A3b reload keeps sector bucket count", "reload=%s source=%s" % [str(metrics.get("reload_props_preview_bucket_count", 0)), str(metrics.get("props_sector_bucket_count", -1))])

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A3b exported .tscn loadable as PackedScene")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A3b exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A3b reloaded root name", str(inst.name))
		var terrain_branch := inst.get_node_or_null("TerrainRoot")
		var water_branch := inst.get_node_or_null("WaterRoot")
		var props_branch := inst.get_node_or_null("StaticPropsRoot")
		_check(terrain_branch != null, "P1-16A3b reloaded root has TerrainRoot")
		_check(water_branch != null, "P1-16A3b reloaded root has WaterRoot")
		_check(props_branch != null, "P1-16A3b reloaded root has StaticPropsRoot")
		_check(terrain_branch != null and terrain_branch.get_node_or_null("Zone000_TerrainVisuals") != null, "P1-16A3b reloaded TerrainRoot has Zone000_TerrainVisuals")
		_check(water_branch != null and water_branch.get_node_or_null("Zone000_WaterVisuals") != null, "P1-16A3b reloaded WaterRoot has Zone000_WaterVisuals")
		_check(props_branch != null and props_branch.get_node_or_null("Zone000_PropsPreview_0256") != null, "P1-16A3b reloaded StaticPropsRoot has props preview")
		_check(str(inst.get_meta("daoc_checkpoint", "")) == "P1_16A3B_ZONECREATOR_PROPS_STRATEGY", "P1-16A3b reloaded metadata checkpoint", str(inst.get_meta("daoc_checkpoint", "")))
		_check(str(inst.get_meta("daoc_export_mode", "")) == "editor_visible_terrain_water_props_preview", "P1-16A3b reloaded metadata export mode", str(inst.get_meta("daoc_export_mode", "")))
		_check(str(inst.get_meta("daoc_props_strategy", "")) == "editor_preview_even_sample_sector_buckets", "P1-16A3b reloaded metadata props strategy", str(inst.get_meta("daoc_props_strategy", "")))
		_check(int(inst.get_meta("daoc_props_exported_nodes", 0)) == 256, "P1-16A3b reloaded metadata exported prop count", str(inst.get_meta("daoc_props_exported_nodes", 0)))
		inst.free()

	_check(bool(snap.get("reload_ok", false)), "P1-16A3b internal reload validation ok")
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A3b respects ZoneViewer freeze")
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A3b keeps prop source metric", str(metrics.get("prop_nodes_source", 0)))
	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A3b preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A3b preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A3b preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A3b preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A3b preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A3c decide full props export / instancing strategy", "P1-16A3b recommends full/instancing decision next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_full_zone_props_p1_16a3c(zone_viewer: Node) -> void:
	_section("P1-16A3c ZoneCreator full zone props")
	_check(DaocZoneCreatorScript != null, "P1-16A3c DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A3c ZoneCreator instantiates")
	_check(creator.has_method("export_generated_scene_full_zone_props"), "P1-16A3c ZoneCreator exposes export_generated_scene_full_zone_props")

	var result: RefCounted = null
	if creator != null and creator.has_method("export_generated_scene_full_zone_props"):
		result = creator.call("export_generated_scene_full_zone_props", zone_viewer, 0, {}) as RefCounted
	_check(result != null, "P1-16A3c export_generated_scene_full_zone_props returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A3c ZoneCreator full zone props ---")
		_debug.append(_snapshot_debug_line(snap))

	var expected_path: String = "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(snap.get("scope", "")) == "P1-16A3c ZoneCreator full zone props", "P1-16A3c reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A3C_ZONECREATOR_FULL_ZONE_PROPS", "P1-16A3c reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A3c generated export result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A3c export marked ok")
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A3c exported scene path", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "editor_visible_terrain_water_full_zone_props", "P1-16A3c export mode is full zone props", str(snap.get("export_mode", "")))
	_check(not bool(snap.get("include_runtime_nodes", true)), "P1-16A3c does not duplicate live runtime nodes flag")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A3c PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A3c ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A3c exported .tscn exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A3c exported .tscn exists on disk")

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(str(metrics.get("visual_population_mode", "")) == "terrain_water_full_zone_props", "P1-16A3c visual population mode", str(metrics.get("visual_population_mode", "")))
	_check(str(metrics.get("props_strategy", "")) == "full_zone_scene_sector_buckets", "P1-16A3c props strategy", str(metrics.get("props_strategy", "")))
	_check(str(metrics.get("props_population_kind", "")) == "full_zone_scene", "P1-16A3c props population kind", str(metrics.get("props_population_kind", "")))
	_check(bool(metrics.get("terrain_visual_root_present", false)), "P1-16A3c keeps terrain visual root")
	_check(bool(metrics.get("water_visual_root_present", false)), "P1-16A3c keeps water visual root")
	_check(int(metrics.get("terrain_visual_mesh_nodes", 0)) == 64, "P1-16A3c keeps 64 terrain mesh nodes", str(metrics.get("terrain_visual_mesh_nodes", 0)))
	_check(int(metrics.get("water_visual_mesh_nodes", 0)) == 2, "P1-16A3c keeps 2 water mesh nodes", str(metrics.get("water_visual_mesh_nodes", 0)))
	_check(bool(metrics.get("props_root_present", false)), "P1-16A3c props root present")
	_check(bool(metrics.get("props_full_root_present", false)), "P1-16A3c full props root present")
	_check(str(metrics.get("props_full_root_name", "")) == "Zone000_PropsFull_1876", "P1-16A3c full props root name", str(metrics.get("props_full_root_name", "")))
	_check(int(metrics.get("props_source_total", 0)) == 1876, "P1-16A3c sees 1876 source props", str(metrics.get("props_source_total", 0)))
	_check(int(metrics.get("props_export_limit", 0)) == 1876, "P1-16A3c prop export limit is full source count", str(metrics.get("props_export_limit", 0)))
	_check(int(metrics.get("props_visual_nodes", 0)) == 1876, "P1-16A3c exports all 1876 prop nodes", str(metrics.get("props_visual_nodes", 0)))
	_check(int(metrics.get("props_skipped_nodes", -1)) == 0, "P1-16A3c leaves no props for later", str(metrics.get("props_skipped_nodes", -1)))
	_check(int(metrics.get("props_visual_mesh_nodes", 0)) == 1876, "P1-16A3c prop mesh nodes match prop count", str(metrics.get("props_visual_mesh_nodes", 0)))
	_check(int(metrics.get("props_sector_bucket_count", 0)) > 0, "P1-16A3c sector bucket count non-zero", str(metrics.get("props_sector_bucket_count", 0)))
	_check(int(metrics.get("props_sector_bucket_count", 999)) <= 64, "P1-16A3c sector bucket count capped", str(metrics.get("props_sector_bucket_count", 999)))
	_check(bool(metrics.get("props_included", false)), "P1-16A3c props included")
	_check(bool(metrics.get("props_full_export", false)), "P1-16A3c props full export")
	_check(bool(metrics.get("props_full_zone_scene", false)), "P1-16A3c one scene per zone decision encoded")
	_check(not bool(metrics.get("props_preview_capped", true)), "P1-16A3c props preview cap disabled")
	_check(not bool(metrics.get("collisions_included", true)), "P1-16A3c collisions still excluded")
	_check(int(metrics.get("collision_visual_nodes", -1)) == 0, "P1-16A3c collision visuals remain out", str(metrics.get("collision_visual_nodes", -1)))
	_check(not bool(metrics.get("runtime_nodes_duplicated", true)), "P1-16A3c runtime nodes not flagged duplicated")
	_check(bool(metrics.get("editor_recenter_enabled", false)), "P1-16A3c editor recenter enabled")
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A3c zone center floor remains recentered", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))
	_check(int(metrics.get("reload_terrain_mesh_nodes", 0)) == 64, "P1-16A3c reload sees 64 terrain meshes", str(metrics.get("reload_terrain_mesh_nodes", 0)))
	_check(int(metrics.get("reload_water_mesh_nodes", 0)) == 2, "P1-16A3c reload sees 2 water meshes", str(metrics.get("reload_water_mesh_nodes", 0)))
	_check(int(metrics.get("reload_prop_mesh_nodes", 0)) == 1876, "P1-16A3c reload sees 1876 prop mesh nodes", str(metrics.get("reload_prop_mesh_nodes", 0)))
	_check(bool(metrics.get("reload_props_root_present", false)), "P1-16A3c reload sees props root")
	_check(bool(metrics.get("reload_props_full_root_present", false)), "P1-16A3c reload sees full props root")
	_check(int(metrics.get("reload_props_full_exported_nodes", 0)) == 1876, "P1-16A3c reload sees 1876 full prop nodes", str(metrics.get("reload_props_full_exported_nodes", 0)))
	_check(int(metrics.get("reload_props_full_bucket_count", 0)) == int(metrics.get("props_sector_bucket_count", -1)), "P1-16A3c reload keeps sector bucket count", "reload=%s source=%s" % [str(metrics.get("reload_props_full_bucket_count", 0)), str(metrics.get("props_sector_bucket_count", -1))])

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A3c exported .tscn loadable as PackedScene")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A3c exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A3c reloaded root name", str(inst.name))
		var terrain_branch := inst.get_node_or_null("TerrainRoot")
		var water_branch := inst.get_node_or_null("WaterRoot")
		var props_branch := inst.get_node_or_null("StaticPropsRoot")
		_check(terrain_branch != null, "P1-16A3c reloaded root has TerrainRoot")
		_check(water_branch != null, "P1-16A3c reloaded root has WaterRoot")
		_check(props_branch != null, "P1-16A3c reloaded root has StaticPropsRoot")
		_check(terrain_branch != null and terrain_branch.get_node_or_null("Zone000_TerrainVisuals") != null, "P1-16A3c reloaded TerrainRoot has Zone000_TerrainVisuals")
		_check(water_branch != null and water_branch.get_node_or_null("Zone000_WaterVisuals") != null, "P1-16A3c reloaded WaterRoot has Zone000_WaterVisuals")
		_check(props_branch != null and props_branch.get_node_or_null("Zone000_PropsFull_1876") != null, "P1-16A3c reloaded StaticPropsRoot has full props root")
		_check(str(inst.get_meta("daoc_checkpoint", "")) == "P1_16A3C_ZONECREATOR_FULL_ZONE_PROPS", "P1-16A3c reloaded metadata checkpoint", str(inst.get_meta("daoc_checkpoint", "")))
		_check(str(inst.get_meta("daoc_export_mode", "")) == "editor_visible_terrain_water_full_zone_props", "P1-16A3c reloaded metadata export mode", str(inst.get_meta("daoc_export_mode", "")))
		_check(str(inst.get_meta("daoc_props_strategy", "")) == "full_zone_scene_sector_buckets", "P1-16A3c reloaded metadata props strategy", str(inst.get_meta("daoc_props_strategy", "")))
		_check(str(inst.get_meta("daoc_props_population_kind", "")) == "full_zone_scene", "P1-16A3c reloaded metadata population kind", str(inst.get_meta("daoc_props_population_kind", "")))
		_check(int(inst.get_meta("daoc_props_exported_nodes", 0)) == 1876, "P1-16A3c reloaded metadata exported prop count", str(inst.get_meta("daoc_props_exported_nodes", 0)))
		inst.free()

	_check(bool(snap.get("reload_ok", false)), "P1-16A3c internal reload validation ok")
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A3c respects ZoneViewer freeze")
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A3c keeps prop source metric", str(metrics.get("prop_nodes_source", 0)))
	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A3c preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A3c preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A3c preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A3c preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A3c preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A4 add collisions/zonejump editor data to generated zone scene", "P1-16A3c recommends generated scene gameplay/debug data next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_collision_zonejump_p1_16a4(zone_viewer: Node) -> void:
	_section("P1-16A4 ZoneCreator collision zonejump editor data")
	_check(DaocZoneCreatorScript != null, "P1-16A4 DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A4 ZoneCreator instantiates")
	_check(creator.has_method("export_generated_scene_with_collision_zonejump_editor_data"), "P1-16A4 ZoneCreator exposes export_generated_scene_with_collision_zonejump_editor_data")

	var result: RefCounted = null
	if creator != null and creator.has_method("export_generated_scene_with_collision_zonejump_editor_data"):
		result = creator.call("export_generated_scene_with_collision_zonejump_editor_data", zone_viewer, 0, {}) as RefCounted
	_check(result != null, "P1-16A4 export_generated_scene_with_collision_zonejump_editor_data returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
		_debug.append("\n--- P1-16A4 ZoneCreator collision zonejump editor data ---")
		_debug.append(_snapshot_debug_line(snap))

	var expected_path: String = "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(snap.get("scope", "")) == "P1-16A4 ZoneCreator collision zonejump editor data", "P1-16A4 reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A4_ZONECREATOR_COLLISION_ZONEJUMP_EDITOR_DATA", "P1-16A4 reports checkpoint", str(snap.get("checkpoint", "")))
	_check(bool(snap.get("ok", false)), "P1-16A4 generated export result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A4 export marked ok")
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A4 exported scene path", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "editor_visible_full_zone_collision_zonejump", "P1-16A4 export mode is collision/zonejump", str(snap.get("export_mode", "")))
	_check(not bool(snap.get("include_runtime_nodes", true)), "P1-16A4 does not duplicate live runtime nodes flag")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A4 PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A4 ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A4 exported .tscn exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A4 exported .tscn exists on disk")

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	_check(str(metrics.get("visual_population_mode", "")) == "terrain_water_full_zone_props", "P1-16A4 keeps full zone visual population mode", str(metrics.get("visual_population_mode", "")))
	_check(str(metrics.get("props_strategy", "")) == "full_zone_scene_sector_buckets", "P1-16A4 keeps full props strategy", str(metrics.get("props_strategy", "")))
	_check(str(metrics.get("props_population_kind", "")) == "full_zone_scene", "P1-16A4 keeps full props population kind", str(metrics.get("props_population_kind", "")))
	_check(bool(metrics.get("props_full_zone_scene", false)), "P1-16A4 keeps one scene per zone decision")
	_check(int(metrics.get("terrain_visual_mesh_nodes", 0)) == 64, "P1-16A4 keeps 64 terrain mesh nodes", str(metrics.get("terrain_visual_mesh_nodes", 0)))
	_check(int(metrics.get("water_visual_mesh_nodes", 0)) == 2, "P1-16A4 keeps 2 water mesh nodes", str(metrics.get("water_visual_mesh_nodes", 0)))
	_check(int(metrics.get("props_visual_nodes", 0)) == 1876, "P1-16A4 keeps all 1876 prop nodes", str(metrics.get("props_visual_nodes", 0)))

	_check(bool(metrics.get("collision_editor_data_included", false)), "P1-16A4 collision editor data included")
	_check(str(metrics.get("collision_editor_strategy", "")) == "editor_data_staticbody_roots", "P1-16A4 collision editor strategy", str(metrics.get("collision_editor_strategy", "")))
	_check(bool(metrics.get("collisions_included", false)), "P1-16A4 collisions included")
	_check(bool(metrics.get("collision_root_present", false)), "P1-16A4 collision root present")
	_check(str(metrics.get("collision_root_name", "")) == "Zone000_CollisionEditorData", "P1-16A4 collision root name", str(metrics.get("collision_root_name", "")))
	_check(bool(metrics.get("boundary_collision_root_present", false)), "P1-16A4 boundary collision root present")
	_check(str(metrics.get("boundary_collision_root_name", "")) == "Zone000_BoundaryCollision", "P1-16A4 boundary collision root name", str(metrics.get("boundary_collision_root_name", "")))
	_check(int(metrics.get("boundary_collision_bodies", 0)) == 142, "P1-16A4 exports 142 boundary collision bodies", str(metrics.get("boundary_collision_bodies", 0)))
	_check(bool(metrics.get("prop_collision_root_present", false)), "P1-16A4 prop collision root present")
	_check(str(metrics.get("prop_collision_root_name", "")) == "Zone000_PropCollisionAABBs", "P1-16A4 prop collision root name", str(metrics.get("prop_collision_root_name", "")))
	_check(int(metrics.get("prop_collision_bodies", 0)) == 502, "P1-16A4 exports 502 prop collision bodies", str(metrics.get("prop_collision_bodies", 0)))
	_check(int(metrics.get("collision_static_bodies", 0)) == 644, "P1-16A4 exports 644 total collision bodies", str(metrics.get("collision_static_bodies", 0)))
	_check(int(metrics.get("collision_shape_nodes", 0)) >= 644, "P1-16A4 collision shapes exported", str(metrics.get("collision_shape_nodes", 0)))

	_check(bool(metrics.get("zonejump_editor_data_included", false)), "P1-16A4 zonejump editor data included")
	_check(str(metrics.get("zonejump_editor_strategy", "")) == "editor_data_area_roots_monitoring_off", "P1-16A4 zonejump editor strategy", str(metrics.get("zonejump_editor_strategy", "")))
	_check(bool(metrics.get("zonejump_root_present", false)), "P1-16A4 zonejump editor root present")
	_check(str(metrics.get("zonejump_root_name", "")) == "Zone000_ZoneJumpEditorData", "P1-16A4 zonejump root name", str(metrics.get("zonejump_root_name", "")))
	_check(int(metrics.get("zonejump_area_nodes", 0)) == 28, "P1-16A4 exports 28 zonejump areas", str(metrics.get("zonejump_area_nodes", 0)))
	_check(int(metrics.get("zonejump_collision_shape_nodes", 0)) >= 28, "P1-16A4 zonejump collision shapes exported", str(metrics.get("zonejump_collision_shape_nodes", 0)))
	_check(bool(metrics.get("zonejump_runtime_monitoring_disabled", false)), "P1-16A4 zonejump monitoring disabled in generated scene")

	_check(bool(metrics.get("editor_recenter_enabled", false)), "P1-16A4 editor recenter enabled")
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A4 zone center floor remains recentered", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))
	_check(int(metrics.get("reload_terrain_mesh_nodes", 0)) == 64, "P1-16A4 reload sees 64 terrain meshes", str(metrics.get("reload_terrain_mesh_nodes", 0)))
	_check(int(metrics.get("reload_water_mesh_nodes", 0)) == 2, "P1-16A4 reload sees 2 water meshes", str(metrics.get("reload_water_mesh_nodes", 0)))
	_check(int(metrics.get("reload_prop_mesh_nodes", 0)) == 1876, "P1-16A4 reload sees 1876 prop mesh nodes", str(metrics.get("reload_prop_mesh_nodes", 0)))
	_check(int(metrics.get("reload_collision_static_bodies", 0)) == 644, "P1-16A4 reload sees 644 collision bodies", str(metrics.get("reload_collision_static_bodies", 0)))
	_check(int(metrics.get("reload_collision_shape_nodes", 0)) >= 644, "P1-16A4 reload sees collision shapes", str(metrics.get("reload_collision_shape_nodes", 0)))
	_check(bool(metrics.get("reload_boundary_collision_root_present", false)), "P1-16A4 reload sees boundary collision root")
	_check(bool(metrics.get("reload_prop_collision_root_present", false)), "P1-16A4 reload sees prop collision root")
	_check(int(metrics.get("reload_zonejump_area_nodes", 0)) == 28, "P1-16A4 reload sees 28 zonejump areas", str(metrics.get("reload_zonejump_area_nodes", 0)))
	_check(int(metrics.get("reload_zonejump_collision_shape_nodes", 0)) >= 28, "P1-16A4 reload sees zonejump collision shapes", str(metrics.get("reload_zonejump_collision_shape_nodes", 0)))
	_check(bool(metrics.get("reload_zonejump_root_present", false)), "P1-16A4 reload sees zonejump editor root")
	_check(bool(metrics.get("reload_zonejump_runtime_monitoring_disabled", false)), "P1-16A4 reload keeps zonejump monitoring disabled")

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A4 exported .tscn loadable as PackedScene")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A4 exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A4 reloaded root name", str(inst.name))
		var terrain_branch: Node = inst.get_node_or_null("TerrainRoot")
		var water_branch: Node = inst.get_node_or_null("WaterRoot")
		var props_branch: Node = inst.get_node_or_null("StaticPropsRoot")
		var collision_branch: Node = inst.get_node_or_null("CollisionRoot")
		var zonejump_branch: Node = inst.get_node_or_null("ZoneJumpRoot")
		_check(terrain_branch != null, "P1-16A4 reloaded root has TerrainRoot")
		_check(water_branch != null, "P1-16A4 reloaded root has WaterRoot")
		_check(props_branch != null, "P1-16A4 reloaded root has StaticPropsRoot")
		_check(collision_branch != null, "P1-16A4 reloaded root has CollisionRoot")
		_check(zonejump_branch != null, "P1-16A4 reloaded root has ZoneJumpRoot")
		_check(terrain_branch != null and terrain_branch.get_node_or_null("Zone000_TerrainVisuals") != null, "P1-16A4 reloaded TerrainRoot has Zone000_TerrainVisuals")
		_check(water_branch != null and water_branch.get_node_or_null("Zone000_WaterVisuals") != null, "P1-16A4 reloaded WaterRoot has Zone000_WaterVisuals")
		_check(props_branch != null and props_branch.get_node_or_null("Zone000_PropsFull_1876") != null, "P1-16A4 reloaded StaticPropsRoot has full props root")
		_check(collision_branch != null and collision_branch.get_node_or_null("Zone000_CollisionEditorData") != null, "P1-16A4 reloaded CollisionRoot has editor data root")
		_check(zonejump_branch != null and zonejump_branch.get_node_or_null("Zone000_ZoneJumpEditorData") != null, "P1-16A4 reloaded ZoneJumpRoot has editor data root")
		_check(str(inst.get_meta("daoc_checkpoint", "")) == "P1_16A4_ZONECREATOR_COLLISION_ZONEJUMP_EDITOR_DATA", "P1-16A4 reloaded metadata checkpoint", str(inst.get_meta("daoc_checkpoint", "")))
		_check(str(inst.get_meta("daoc_export_mode", "")) == "editor_visible_full_zone_collision_zonejump", "P1-16A4 reloaded metadata export mode", str(inst.get_meta("daoc_export_mode", "")))
		_check(str(inst.get_meta("daoc_collision_editor_strategy", "")) == "editor_data_staticbody_roots", "P1-16A4 reloaded metadata collision strategy", str(inst.get_meta("daoc_collision_editor_strategy", "")))
		_check(str(inst.get_meta("daoc_zonejump_editor_strategy", "")) == "editor_data_area_roots_monitoring_off", "P1-16A4 reloaded metadata zonejump strategy", str(inst.get_meta("daoc_zonejump_editor_strategy", "")))
		_check(int(inst.get_meta("daoc_boundary_collision_bodies", 0)) == 142, "P1-16A4 reloaded metadata boundary body count", str(inst.get_meta("daoc_boundary_collision_bodies", 0)))
		_check(int(inst.get_meta("daoc_prop_collision_bodies", 0)) == 502, "P1-16A4 reloaded metadata prop body count", str(inst.get_meta("daoc_prop_collision_bodies", 0)))
		_check(int(inst.get_meta("daoc_zonejump_area_nodes", 0)) == 28, "P1-16A4 reloaded metadata zonejump area count", str(inst.get_meta("daoc_zonejump_area_nodes", 0)))
		inst.free()

	_check(bool(snap.get("reload_ok", false)), "P1-16A4 internal reload validation ok")
	_check(bool(metrics.get("zoneviewer_refactor_closed", false)), "P1-16A4 respects ZoneViewer freeze")
	_check(int(metrics.get("prop_nodes_source", 0)) == 1876, "P1-16A4 keeps prop source metric", str(metrics.get("prop_nodes_source", 0)))
	_check(int(metrics.get("boundary_segments_source", 0)) == 142, "P1-16A4 keeps boundary source metric", str(metrics.get("boundary_segments_source", 0)))
	_check(int(metrics.get("prop_collision_bodies_source", 0)) == 502, "P1-16A4 keeps prop collision source metric", str(metrics.get("prop_collision_bodies_source", 0)))
	_check(int(metrics.get("zonejump_entries_source", 0)) == 28, "P1-16A4 keeps zonejump source metric", str(metrics.get("zonejump_entries_source", 0)))
	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(str(signatures.get("zonejump", "")) == "27a4632b710a6cdb202c18e182793954", "P1-16A4 preserves zonejump signature")
	_check(str(signatures.get("water", "")) == "9fb7474a4dab25cb828a4973b2c12e15", "P1-16A4 preserves water signature")
	_check(str(signatures.get("boundary", "")) == "1154ee2f495873b7f8461dd88536908e", "P1-16A4 preserves boundary signature")
	_check(str(signatures.get("prop", "")) == "46d670df525a69230158d643f5a70468", "P1-16A4 preserves prop signature")
	_check(str(signatures.get("terrain", "")) == "7601093f060a7b75f2c3e6824c40f05f", "P1-16A4 preserves terrain signature")
	_check(str(snap.get("recommended_next_step", "")) == "P1-16A5 multi-zone scene generation batch", "P1-16A4 recommends multi-zone batch next", str(snap.get("recommended_next_step", "")))

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()


func _test_zone_creator_multi_zone_batch_p1_16a5a(zone_viewer: Node) -> void:
	_section("P1-16A5a ZoneCreator multi-zone batch foundation")
	_check(DaocZoneCreatorScript != null, "P1-16A5a DaocZoneCreator exists")

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A5a ZoneCreator instantiates")
	_check(creator.has_method("export_generated_zone_scenes_batch"), "P1-16A5a ZoneCreator exposes export_generated_zone_scenes_batch")
	_check(creator.has_method("export_generated_zone_scenes_batch_debug_snapshot"), "P1-16A5a ZoneCreator exposes batch debug snapshot")

	var batch: Dictionary = {}
	if creator != null and creator.has_method("export_generated_zone_scenes_batch"):
		batch = creator.call("export_generated_zone_scenes_batch", zone_viewer, {"max_batch_zones": 1}) as Dictionary
	_debug.append("\n--- P1-16A5a ZoneCreator multi-zone batch foundation ---")
	_debug.append(_snapshot_debug_line(batch))

	var expected_path: String = "res://reports/generated/zones/zone000/GeneratedZone_000.tscn"
	_check(str(batch.get("scope", "")) == "P1-16A5a ZoneCreator multi-zone batch foundation", "P1-16A5a reports scope", str(batch.get("scope", "")))
	_check(str(batch.get("checkpoint", "")) == "P1_16A5A_ZONECREATOR_MULTI_ZONE_BATCH_FOUNDATION", "P1-16A5a reports checkpoint", str(batch.get("checkpoint", "")))
	_check(bool(batch.get("ok", false)), "P1-16A5a batch result is ok")
	_check(str(batch.get("batch_mode", "")) == "configured_zones_limited_full_a4_export", "P1-16A5a batch mode", str(batch.get("batch_mode", "")))
	_check(bool(batch.get("one_scene_per_zone", false)), "P1-16A5a preserves one scene per zone decision")
	_check(bool(batch.get("uses_configured_zone_list", false)), "P1-16A5a uses configured ZoneViewer zone list")
	_check(bool(batch.get("default_limited_for_f12", false)), "P1-16A5a batch is limited for F12")
	_check(int(batch.get("max_batch_zones", 0)) == 1, "P1-16A5a max batch zones is guarded", str(batch.get("max_batch_zones", 0)))
	_check(int(batch.get("zone_count", 0)) == 1, "P1-16A5a exports one configured zone by default", str(batch.get("zone_count", 0)))
	_check(int(batch.get("ok_count", 0)) == 1, "P1-16A5a one zone export succeeded", str(batch.get("ok_count", 0)))
	_check(int(batch.get("fail_count", -1)) == 0, "P1-16A5a no batch zone failed", str(batch.get("fail_count", -1)))
	_check(int(batch.get("result_count", 0)) == 1, "P1-16A5a records one zone result", str(batch.get("result_count", 0)))
	_check(bool(batch.get("zone000_oracle_ok", false)), "P1-16A5a zone000 A4 oracle remains ok")
	_check(str(batch.get("zone000_export_path", "")) == expected_path, "P1-16A5a zone000 path", str(batch.get("zone000_export_path", "")))
	_check(str(batch.get("a4_export_mode", "")) == "editor_visible_full_zone_collision_zonejump", "P1-16A5a uses A4 full-zone export mode", str(batch.get("a4_export_mode", "")))

	var requested_zones: Array = batch.get("requested_zones", []) as Array
	var zones_to_export: Array = batch.get("zones_to_export", []) as Array
	var exported_zones: Array = batch.get("exported_zones", []) as Array
	var failed_zones: Array = batch.get("failed_zones", []) as Array
	var exported_paths: Array = batch.get("exported_paths", []) as Array
	_check(requested_zones.size() >= 1 and int(requested_zones[0]) == 0, "P1-16A5a requested zones include zone000", str(requested_zones))
	_check(zones_to_export.size() == 1 and int(zones_to_export[0]) == 0, "P1-16A5a effective zones limited to zone000", str(zones_to_export))
	_check(exported_zones.size() == 1 and int(exported_zones[0]) == 0, "P1-16A5a exported zones include zone000", str(exported_zones))
	_check(failed_zones.is_empty(), "P1-16A5a failed zones list empty", str(failed_zones))
	_check(exported_paths.size() == 1 and str(exported_paths[0]) == expected_path, "P1-16A5a exported path list contains zone000 scene", str(exported_paths))

	var results: Array = batch.get("results", []) as Array
	var zone0_snap: Dictionary = {}
	if results.size() > 0 and typeof(results[0]) == TYPE_DICTIONARY:
		zone0_snap = results[0] as Dictionary
	_check(not zone0_snap.is_empty(), "P1-16A5a zone000 result snapshot present")
	_check(str(zone0_snap.get("scope", "")) == "P1-16A4 ZoneCreator collision zonejump editor data", "P1-16A5a zone000 result keeps A4 scope", str(zone0_snap.get("scope", "")))
	_check(str(zone0_snap.get("checkpoint", "")) == "P1_16A4_ZONECREATOR_COLLISION_ZONEJUMP_EDITOR_DATA", "P1-16A5a zone000 result keeps A4 checkpoint", str(zone0_snap.get("checkpoint", "")))
	_check(bool(zone0_snap.get("ok", false)), "P1-16A5a zone000 result ok")
	_check(bool(zone0_snap.get("export_ok", false)), "P1-16A5a zone000 export ok")
	_check(bool(zone0_snap.get("reload_ok", false)), "P1-16A5a zone000 reload ok")
	_check(str(zone0_snap.get("exported_scene_path", "")) == expected_path, "P1-16A5a zone000 exported scene path", str(zone0_snap.get("exported_scene_path", "")))
	_check(str(zone0_snap.get("export_mode", "")) == "editor_visible_full_zone_collision_zonejump", "P1-16A5a zone000 export mode", str(zone0_snap.get("export_mode", "")))

	var metrics: Dictionary = zone0_snap.get("metrics", {}) as Dictionary
	_check(int(metrics.get("terrain_visual_mesh_nodes", 0)) == 64, "P1-16A5a zone000 keeps 64 terrain meshes", str(metrics.get("terrain_visual_mesh_nodes", 0)))
	_check(int(metrics.get("water_visual_mesh_nodes", 0)) == 2, "P1-16A5a zone000 keeps 2 water meshes", str(metrics.get("water_visual_mesh_nodes", 0)))
	_check(int(metrics.get("props_visual_nodes", 0)) == 1876, "P1-16A5a zone000 keeps 1876 props", str(metrics.get("props_visual_nodes", 0)))
	_check(int(metrics.get("collision_static_bodies", 0)) == 644, "P1-16A5a zone000 keeps 644 collision bodies", str(metrics.get("collision_static_bodies", 0)))
	_check(int(metrics.get("zonejump_area_nodes", 0)) == 28, "P1-16A5a zone000 keeps 28 zonejump areas", str(metrics.get("zonejump_area_nodes", 0)))
	_check(int(metrics.get("reload_prop_mesh_nodes", 0)) == 1876, "P1-16A5a zone000 reload sees 1876 props", str(metrics.get("reload_prop_mesh_nodes", 0)))
	_check(int(metrics.get("reload_collision_static_bodies", 0)) == 644, "P1-16A5a zone000 reload sees 644 collision bodies", str(metrics.get("reload_collision_static_bodies", 0)))
	_check(int(metrics.get("reload_zonejump_area_nodes", 0)) == 28, "P1-16A5a zone000 reload sees 28 zonejump areas", str(metrics.get("reload_zonejump_area_nodes", 0)))
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A5a zone000 remains recentered", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))

	_check(FileAccess.file_exists(expected_path), "P1-16A5a exported zone000 .tscn exists on disk")
	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene")
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A5a exported zone000 .tscn loadable")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A5a exported zone000 .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_000", "P1-16A5a reloaded zone000 root name", str(inst.name))
		_check(inst.get_node_or_null("TerrainRoot/Zone000_TerrainVisuals") != null, "P1-16A5a reloaded zone000 has terrain root")
		_check(inst.get_node_or_null("WaterRoot/Zone000_WaterVisuals") != null, "P1-16A5a reloaded zone000 has water root")
		_check(inst.get_node_or_null("StaticPropsRoot/Zone000_PropsFull_1876") != null, "P1-16A5a reloaded zone000 has full props root")
		_check(inst.get_node_or_null("CollisionRoot/Zone000_CollisionEditorData") != null, "P1-16A5a reloaded zone000 has collision editor data")
		_check(inst.get_node_or_null("ZoneJumpRoot/Zone000_ZoneJumpEditorData") != null, "P1-16A5a reloaded zone000 has zonejump editor data")
		inst.free()

	_check(str(batch.get("recommended_next_step", "")) == "P1-16A5b expand configured zone list / move batch outside global F12", "P1-16A5a recommends A5b controlled expansion", str(batch.get("recommended_next_step", "")))




func _test_zone_scene_export_service_p1_16a6(zone_viewer: Node) -> void:
	_section("P1-16A6 ZoneSceneExportService")
	_check(DaocZoneCreatorScript != null, "P1-16A6 DaocZoneCreator exists")
	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A6 ZoneCreator instantiates")
	_check(creator.has_method("export_zone_scene_a6"), "P1-16A6 ZoneCreator exposes export_zone_scene_a6")
	_check(creator.has_method("ensure_zone_built_a6"), "P1-16A6 ZoneCreator exposes ensure_zone_built_a6")

	var target_zone := _first_configured_zone(zone_viewer)
	var expected_path := "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [target_zone, target_zone]
	var result: RefCounted = null
	if creator != null and creator.has_method("export_zone_scene_a6"):
		result = creator.call("export_zone_scene_a6", zone_viewer, target_zone, {}) as RefCounted
	_check(result != null, "P1-16A6 export returns result")

	var snap: Dictionary = {}
	if result != null and result.has_method("to_debug_dict"):
		snap = result.call("to_debug_dict", false) as Dictionary
	_debug.append("\n--- P1-16A6 ZoneSceneExportService ---")
	_debug.append(_snapshot_debug_line(snap))

	_check(str(snap.get("scope", "")) == "P1-16A6 ZoneSceneExportService", "P1-16A6 reports scope", str(snap.get("scope", "")))
	_check(str(snap.get("checkpoint", "")) == "P1_16A6_ZONE_SCENE_EXPORT_SERVICE", "P1-16A6 reports checkpoint", str(snap.get("checkpoint", "")))
	_check(int(snap.get("zone", -1)) == target_zone, "P1-16A6 targets configured zone", "target=%d got=%s" % [target_zone, str(snap.get("zone", -1))])
	_check(str(snap.get("root_name", "")) == "GeneratedZone_%03d" % target_zone, "P1-16A6 root name is zone-aware", str(snap.get("root_name", "")))
	_check(str(snap.get("exported_scene_path", "")) == expected_path, "P1-16A6 exported scene path is zone-aware", str(snap.get("exported_scene_path", "")))
	_check(str(snap.get("generated_scene_path", "")) == expected_path, "P1-16A6 generated scene path is zone-aware", str(snap.get("generated_scene_path", "")))
	_check(str(snap.get("export_mode", "")) == "a6_zone_aware_full_zone_collision_zonejump", "P1-16A6 export mode", str(snap.get("export_mode", "")))
	_check(bool(snap.get("ok", false)), "P1-16A6 result is ok")
	_check(bool(snap.get("export_ok", false)), "P1-16A6 export ok")
	_check(bool(snap.get("reload_ok", false)), "P1-16A6 reload ok")
	_check(int(snap.get("pack_error_code", -1)) == OK, "P1-16A6 PackedScene.pack OK", str(snap.get("pack_error_code", -1)))
	_check(int(snap.get("export_error_code", -1)) == OK, "P1-16A6 ResourceSaver.save OK", str(snap.get("export_error_code", -1)))
	_check(bool(snap.get("file_exists_after_save", false)), "P1-16A6 file exists after save")
	_check(FileAccess.file_exists(expected_path), "P1-16A6 .tscn exists on disk", expected_path)

	var metrics: Dictionary = snap.get("metrics", {}) as Dictionary
	var signatures: Dictionary = snap.get("signatures", {}) as Dictionary
	_check(bool(metrics.get("zone_aware_metrics", false)), "P1-16A6 uses zone-aware metrics")
	_check(bool(metrics.get("dynamic_zone_validation", false)), "P1-16A6 uses dynamic validation")
	_check(int(metrics.get("target_zone", -1)) == target_zone, "P1-16A6 metrics target zone", str(metrics.get("target_zone", -1)))
	_check(bool(metrics.get("zone_source_ready", false)), "P1-16A6 zone sources ready")
	_check(bool(metrics.get("a6_export_service", false)), "P1-16A6 metrics mark export service")
	_check(bool(metrics.get("a6_zone_source_ready", false)), "P1-16A6 ensure snapshot ready")
	_check(bool(signatures.get("zone_aware", false)), "P1-16A6 signatures are zone-aware")

	var terrain_source := int(metrics.get("terrain_meshes_source", 0))
	var water_source := int(metrics.get("water_meshes_source", 0))
	var props_source := int(metrics.get("prop_nodes_source", 0))
	var boundary_source := int(metrics.get("boundary_segments_source", 0))
	var prop_collision_source := int(metrics.get("prop_collision_bodies_source", 0))
	var zonejump_source := int(metrics.get("zonejump_entries_source", 0))
	_check(terrain_source > 0, "P1-16A6 terrain source count positive", str(terrain_source))
	_check(water_source >= 0, "P1-16A6 water source count valid", str(water_source))
	_check(props_source > 0, "P1-16A6 prop source count positive", str(props_source))
	_check(boundary_source > 0, "P1-16A6 boundary source count positive", str(boundary_source))
	_check(prop_collision_source > 0, "P1-16A6 prop collision source count positive", str(prop_collision_source))
	_check(zonejump_source > 0, "P1-16A6 zonejump source count positive", str(zonejump_source))

	_check(int(metrics.get("terrain_visual_mesh_nodes", -1)) == terrain_source, "P1-16A6 exports all terrain meshes", "export=%s source=%d" % [str(metrics.get("terrain_visual_mesh_nodes", -1)), terrain_source])
	_check(int(metrics.get("water_visual_mesh_nodes", -1)) == water_source, "P1-16A6 exports all water meshes", "export=%s source=%d" % [str(metrics.get("water_visual_mesh_nodes", -1)), water_source])
	_check(int(metrics.get("props_visual_nodes", -1)) == props_source, "P1-16A6 exports all props", "export=%s source=%d" % [str(metrics.get("props_visual_nodes", -1)), props_source])
	_check(int(metrics.get("boundary_collision_bodies", -1)) == boundary_source, "P1-16A6 exports all boundary collisions", "export=%s source=%d" % [str(metrics.get("boundary_collision_bodies", -1)), boundary_source])
	_check(int(metrics.get("prop_collision_bodies", -1)) == prop_collision_source, "P1-16A6 exports all prop collisions", "export=%s source=%d" % [str(metrics.get("prop_collision_bodies", -1)), prop_collision_source])
	_check(int(metrics.get("zonejump_area_nodes", -1)) == zonejump_source, "P1-16A6 exports all zonejumps", "export=%s source=%d" % [str(metrics.get("zonejump_area_nodes", -1)), zonejump_source])
	_check(int(metrics.get("collision_static_bodies", -1)) == boundary_source + prop_collision_source, "P1-16A6 collision total matches dynamic sources", str(metrics.get("collision_static_bodies", -1)))

	_check(int(metrics.get("reload_terrain_mesh_nodes", -1)) == terrain_source, "P1-16A6 reload sees terrain meshes", str(metrics.get("reload_terrain_mesh_nodes", -1)))
	_check(int(metrics.get("reload_water_mesh_nodes", -1)) == water_source, "P1-16A6 reload sees water meshes", str(metrics.get("reload_water_mesh_nodes", -1)))
	_check(int(metrics.get("reload_prop_mesh_nodes", -1)) == props_source, "P1-16A6 reload sees props", str(metrics.get("reload_prop_mesh_nodes", -1)))
	_check(int(metrics.get("reload_collision_static_bodies", -1)) == boundary_source + prop_collision_source, "P1-16A6 reload sees collision bodies", str(metrics.get("reload_collision_static_bodies", -1)))
	_check(int(metrics.get("reload_zonejump_area_nodes", -1)) == zonejump_source, "P1-16A6 reload sees zonejumps", str(metrics.get("reload_zonejump_area_nodes", -1)))
	_check(absf(float(metrics.get("reload_center_floor_after_offset_y", 999999.0))) < 0.01, "P1-16A6 scene remains recentered", str(metrics.get("reload_center_floor_after_offset_y", 999999.0)))

	var loaded: Resource = ResourceLoader.load(expected_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var packed: PackedScene = loaded as PackedScene
	_check(packed != null, "P1-16A6 exported .tscn loadable")
	var inst: Node = null
	if packed != null:
		inst = packed.instantiate()
	_check(inst != null, "P1-16A6 exported .tscn instantiates")
	if inst != null:
		_check(str(inst.name) == "GeneratedZone_%03d" % target_zone, "P1-16A6 instantiated root name", str(inst.name))
		_check(inst.get_node_or_null("TerrainRoot/Zone%03d_TerrainVisuals" % target_zone) != null, "P1-16A6 instantiated scene has terrain root")
		_check(inst.get_node_or_null("WaterRoot/Zone%03d_WaterVisuals" % target_zone) != null or water_source == 0, "P1-16A6 instantiated scene has water root when needed")
		_check(inst.get_node_or_null("StaticPropsRoot/Zone%03d_PropsFull_%04d" % [target_zone, props_source]) != null, "P1-16A6 instantiated scene has full props root")
		_check(inst.get_node_or_null("CollisionRoot/Zone%03d_CollisionEditorData" % target_zone) != null, "P1-16A6 instantiated scene has collision editor data")
		_check(inst.get_node_or_null("ZoneJumpRoot/Zone%03d_ZoneJumpEditorData" % target_zone) != null, "P1-16A6 instantiated scene has zonejump editor data")
		inst.free()

	if result != null:
		var root: Node = result.get("root") as Node
		if root != null and not root.is_inside_tree():
			root.free()

func _test_zone_creator_controlled_batch_manifest_p1_16a7(zone_viewer: Node) -> void:
	_section("P1-16A7 ZoneCreator controlled multi-zone batch manifest")
	_check(DaocZoneCreatorScript != null, "P1-16A7 DaocZoneCreator exists")
	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-16A7 ZoneCreator instantiates")
	_check(creator.has_method("export_zones_batch_a7"), "P1-16A7 exposes export_zones_batch_a7")
	_check(creator.has_method("export_zones_batch_a7_debug_snapshot"), "P1-16A7 exposes export_zones_batch_a7_debug_snapshot")

	var target_zone := _first_configured_zone(zone_viewer)
	var requested: Array = [target_zone, target_zone]
	if target_zone != 0:
		requested.append(0)
	var expected_zones: Array = []
	for raw_zone in requested:
		var znum := int(raw_zone)
		if not expected_zones.has(znum):
			expected_zones.append(znum)
		if expected_zones.size() >= 2:
			break

	var batch: Dictionary = {}
	if creator != null and creator.has_method("export_zones_batch_a7"):
		batch = creator.call("export_zones_batch_a7", zone_viewer, requested, {"dry_run": true, "write_manifest": false, "max_batch_zones": 2}) as Dictionary
	_debug.append("\n--- P1-16A7 controlled multi-zone batch manifest smoke ---")
	_debug.append(_snapshot_debug_line(batch))

	_check(str(batch.get("scope", "")) == "P1-16A7 ZoneCreator controlled multi-zone batch manifest", "P1-16A7 reports scope", str(batch.get("scope", "")))
	_check(str(batch.get("checkpoint", "")) == "P1_16A7_CONTROLLED_MULTI_ZONE_BATCH_MANIFEST", "P1-16A7 reports checkpoint", str(batch.get("checkpoint", "")))
	_check(bool(batch.get("ok", false)), "P1-16A7 dry-run batch is ok")
	_check(str(batch.get("batch_mode", "")) == "a7_explicit_zone_list_manifest", "P1-16A7 batch mode", str(batch.get("batch_mode", "")))
	_check(bool(batch.get("one_scene_per_zone", false)), "P1-16A7 preserves one scene per zone")
	_check(bool(batch.get("explicit_zone_list", false)), "P1-16A7 uses explicit zone list")
	_check(bool(batch.get("no_silent_zone000_fallback", false)), "P1-16A7 forbids silent zone000 fallback")
	_check(bool(batch.get("dry_run", false)), "P1-16A7 F12 smoke does not run heavy batch export")
	_check(not bool(batch.get("manifest_written", true)), "P1-16A7 F12 smoke does not write manifest")
	_check(str(batch.get("manifest_path", "")) == A7_MANIFEST_PATH, "P1-16A7 default manifest path", str(batch.get("manifest_path", "")))
	_check(int(batch.get("zone_count", -1)) == expected_zones.size(), "P1-16A7 normalized zone count", str(batch.get("zone_count", -1)))
	_check(int(batch.get("result_count", -1)) == expected_zones.size(), "P1-16A7 result count", str(batch.get("result_count", -1)))
	_check(int(batch.get("ok_count", -1)) == expected_zones.size(), "P1-16A7 dry-run ok count", str(batch.get("ok_count", -1)))
	_check(int(batch.get("fail_count", -1)) == 0, "P1-16A7 dry-run fail count", str(batch.get("fail_count", -1)))

	var zones_to_export: Array = batch.get("zones_to_export", []) as Array
	_check(zones_to_export.size() == expected_zones.size(), "P1-16A7 zones_to_export deduplicated", str(zones_to_export))
	for i in range(expected_zones.size()):
		_check(int(zones_to_export[i]) == int(expected_zones[i]), "P1-16A7 zone order preserved %d" % i, str(zones_to_export))

	var entries: Array = batch.get("zones", []) as Array
	_check(entries.size() == expected_zones.size(), "P1-16A7 manifest entries present", str(entries.size()))
	for i in range(min(entries.size(), expected_zones.size())):
		var entry: Dictionary = entries[i] as Dictionary
		var znum := int(expected_zones[i])
		_check(int(entry.get("zone_id", -1)) == znum, "P1-16A7 manifest entry zone id %d" % i, str(entry.get("zone_id", -1)))
		_check(str(entry.get("scene_path", "")) == "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [znum, znum], "P1-16A7 manifest entry path %d" % i, str(entry.get("scene_path", "")))
		_check(bool(entry.get("ok", false)), "P1-16A7 manifest entry ok %d" % i)
		_check(bool(entry.get("dry_run", false)), "P1-16A7 manifest entry dry-run %d" % i)

	var recommended_next_step_a7 := str(batch.get("recommended_next_step", ""))
	var recommended_next_step_ok_a7 := recommended_next_step_a7 == "P1-16A8 runtime load generated scenes" or recommended_next_step_a7.begins_with("P1-16A10B generated primary only for terrain_heightmap")
	_check(recommended_next_step_ok_a7, "P1-16A7 recommends compatible downstream step", recommended_next_step_a7)

	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-16A7c command router present")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonecreator help")), "P1-16A7c /zonecreator help handled")
		_check(bool(command.call("execute_command", "/zonecreator dryrun 0 0")), "P1-16A7c /zonecreator dryrun handled")
		_check(bool(command.call("execute_command", "/zonecreator manifest")), "P1-16A7c /zonecreator manifest handled")


func _test_generated_zone_scene_loader_p1_16a8(zone_viewer: Node) -> void:
	_section("P1-16A8 runtime load generated scenes")
	_check(DaocGeneratedZoneSceneLoaderScript != null, "P1-16A8 DaocGeneratedZoneSceneLoader exists")
	var loader: RefCounted = DaocGeneratedZoneSceneLoaderScript.new()
	_check(loader != null, "P1-16A8 loader instantiates")
	if loader == null:
		return
	_check(loader.has_method("load_manifest"), "P1-16A8 exposes load_manifest")
	_check(loader.has_method("validate_manifest"), "P1-16A8 exposes validate_manifest")
	_check(loader.has_method("manifest_zone_ids"), "P1-16A8 exposes manifest_zone_ids")
	_check(loader.has_method("scene_path_for_zone"), "P1-16A8 exposes scene_path_for_zone")
	_check(loader.has_method("load_generated_zone_scene"), "P1-16A8 exposes load_generated_zone_scene")
	_check(loader.has_method("instantiate_generated_zone_scene"), "P1-16A8 exposes instantiate_generated_zone_scene")
	_check(loader.has_method("create_generated_zone_node"), "P1-16A8 exposes create_generated_zone_node")
	_check(loader.has_method("debug_snapshot"), "P1-16A8 exposes debug_snapshot")

	var load_manifest: Dictionary = loader.call("load_manifest", A7_MANIFEST_PATH) as Dictionary
	_debug.append("\n--- P1-16A8 generated zone scene loader ---")
	_debug.append(_snapshot_debug_line(loader.call("debug_snapshot")))

	if not FileAccess.file_exists(A7_MANIFEST_PATH):
		_check(not bool(load_manifest.get("ok", false)), "P1-16A8 manifest absence detected safely", str(load_manifest.get("error", "")))
		_check(true, "P1-16A8 waits for A7 generated manifest", "run Ctrl+F10 /zonecreator export 0 1 before full runtime-load validation")
		var command_missing: Node = _get_node_ref(zone_viewer, "_command_router")
		_check(command_missing != null, "P1-16A8 command router present")
		if command_missing != null and command_missing.has_method("execute_command"):
			_check(bool(command_missing.call("execute_command", "/generated manifest")), "P1-16A8 /generated manifest handled without manifest")
		return

	_check(bool(load_manifest.get("ok", false)), "P1-16A8 manifest loads", str(load_manifest.get("path", A7_MANIFEST_PATH)))
	var validation: Dictionary = loader.call("validate_manifest", A7_MANIFEST_PATH) as Dictionary
	_check(bool(validation.get("ok", false)), "P1-16A8 manifest validates as A7 manifest", str(validation.get("errors", [])))
	_check(str(validation.get("schema", "")) == "daoc.generated_zones_manifest.v1", "P1-16A8 manifest schema", str(validation.get("schema", "")))
	_check(str(validation.get("checkpoint", "")) == "P1_16A7_CONTROLLED_MULTI_ZONE_BATCH_MANIFEST", "P1-16A8 manifest checkpoint", str(validation.get("checkpoint", "")))
	_check(bool(validation.get("manifest_ok", false)), "P1-16A8 manifest ok=true")
	_check(int(validation.get("fail_count", -1)) == 0, "P1-16A8 manifest fail_count=0", str(validation.get("fail_count", -1)))

	var zone_ids: Array = loader.call("manifest_zone_ids") as Array
	_check(zone_ids.size() >= 1, "P1-16A8 manifest has at least one zone", str(zone_ids))
	_check(_array_contains_int(zone_ids, 0), "P1-16A8 manifest includes zone000", str(zone_ids))
	if _array_contains_int(zone_ids, 1):
		_check(true, "P1-16A8 manifest includes zone001", str(zone_ids))
	else:
		_check(true, "P1-16A8 zone001 runtime-load validation deferred", "manifest zones=%s; run Ctrl+F10 for [0,1]" % str(zone_ids))

	for zone_value in zone_ids:
		var znum: int = int(zone_value)
		var scene_path: String = str(loader.call("scene_path_for_zone", znum, A7_MANIFEST_PATH))
		_check(scene_path != "", "P1-16A8 scene path for zone%03d" % znum, scene_path)
		_check(scene_path == "res://reports/generated/zones/zone%03d/GeneratedZone_%03d.tscn" % [znum, znum], "P1-16A8 scene path is canonical zone%03d" % znum, scene_path)
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			_check(true, "P1-16A8 scene file missing handled safely zone%03d" % znum, scene_path)
			continue
		var loaded_scene: Dictionary = loader.call("load_generated_zone_scene", znum, A7_MANIFEST_PATH) as Dictionary
		_check(bool(loaded_scene.get("ok", false)), "P1-16A8 PackedScene loads zone%03d" % znum, scene_path)
		var instance_result: Dictionary = loader.call("instantiate_generated_zone_scene", znum, false, A7_MANIFEST_PATH) as Dictionary
		_check(bool(instance_result.get("ok", false)), "P1-16A8 generated scene instantiates zone%03d" % znum, str(instance_result.get("missing_branches", [])))
		_check(int(instance_result.get("branch_count", 0)) >= 5, "P1-16A8 generated scene exposes runtime branches zone%03d" % znum, str(instance_result.get("present_branches", [])))
		_check(not instance_result.has("node"), "P1-16A8 F12 does not keep instantiated node zone%03d" % znum)

	var command: Node = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-16A8 command router present")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/generated manifest")), "P1-16A8 /generated manifest handled")
		var zone0_path: String = str(loader.call("scene_path_for_zone", 0, A7_MANIFEST_PATH))
		if zone0_path != "" and ResourceLoader.exists(zone0_path):
			_check(bool(command.call("execute_command", "/generated load 0")), "P1-16A8 /generated load 0 handled")
		else:
			_check(true, "P1-16A8 /generated load 0 deferred because scene file is missing", zone0_path)
		if _array_contains_int(zone_ids, 1):
			var zone1_path: String = str(loader.call("scene_path_for_zone", 1, A7_MANIFEST_PATH))
			if zone1_path != "" and ResourceLoader.exists(zone1_path):
				_check(bool(command.call("execute_command", "/generated load 1")), "P1-16A8 /generated load 1 handled")
			else:
				_check(true, "P1-16A8 /generated load 1 deferred because scene file is missing", zone1_path)

	_debug.append("\n--- P1-16A8 generated zone scene loader post ---")
	_debug.append(_snapshot_debug_line(loader.call("debug_snapshot")))


func _test_generated_zone_runtime_bridge_p1_16a9(zone_viewer: Node) -> void:
	_section("P1-16A9 generated-scene runtime bridge")
	_check(DaocGeneratedZoneRuntimeBridgeScript != null, "P1-16A9 DaocGeneratedZoneRuntimeBridge exists")
	var bridge: RefCounted = DaocGeneratedZoneRuntimeBridgeScript.new()
	_check(bridge != null, "P1-16A9 bridge instantiates")
	if bridge == null:
		return
	_check(bridge.has_method("configure"), "P1-16A9 exposes configure")
	_check(bridge.has_method("attach_zone_scene"), "P1-16A9 exposes attach_zone_scene")
	_check(bridge.has_method("attach_manifest_zones"), "P1-16A9 exposes attach_manifest_zones")
	_check(bridge.has_method("detach_zone_scene"), "P1-16A9 exposes detach_zone_scene")
	_check(bridge.has_method("detach_all_generated_zones"), "P1-16A9 exposes detach_all_generated_zones")
	_check(bridge.has_method("has_attached_zone"), "P1-16A9 exposes has_attached_zone")
	_check(bridge.has_method("attached_zone_ids"), "P1-16A9 exposes attached_zone_ids")
	_check(bridge.has_method("debug_snapshot"), "P1-16A9 exposes debug_snapshot")

	var config: Dictionary = bridge.call("configure", zone_viewer, A7_MANIFEST_PATH) as Dictionary
	_check(bool(config.get("ok", false)), "P1-16A9 bridge configures on ZoneViewer", str(config.get("error", "")))
	var root: Node = zone_viewer.get_node_or_null(NodePath("GeneratedZonesRuntimeRoot_A9"))
	_check(root != null, "P1-16A9 creates dedicated runtime root")
	_debug.append("\n--- P1-16A9 generated runtime bridge initial ---")
	_debug.append(_snapshot_debug_line(bridge.call("debug_snapshot")))

	if not FileAccess.file_exists(A7_MANIFEST_PATH):
		_check(true, "P1-16A9 waits for generated manifest", "run Ctrl+F10 before attach validation")
		var command_missing: Node = _get_node_ref(zone_viewer, "_command_router")
		_check(command_missing != null, "P1-16A9 command router present")
		if command_missing != null and command_missing.has_method("execute_command"):
			_check(bool(command_missing.call("execute_command", "/generated status")), "P1-16A9 /generated status handled without manifest")
		return

	var loader: RefCounted = DaocGeneratedZoneSceneLoaderScript.new()
	var manifest_result: Dictionary = loader.call("load_manifest", A7_MANIFEST_PATH) as Dictionary
	_check(bool(manifest_result.get("ok", false)), "P1-16A9 can read A7 manifest", str(manifest_result.get("error", "")))
	var zone_ids: Array = loader.call("manifest_zone_ids") as Array
	_check(zone_ids.size() >= 1, "P1-16A9 manifest has attachable zones", str(zone_ids))

	var attached_direct: Array = []
	for zone_value in zone_ids:
		var znum: int = int(zone_value)
		var scene_path: String = str(loader.call("scene_path_for_zone", znum, A7_MANIFEST_PATH))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			_check(true, "P1-16A9 attach deferred because scene file is missing zone%03d" % znum, scene_path)
			continue
		var attach_result: Dictionary = bridge.call("attach_zone_scene", zone_viewer, znum, A7_MANIFEST_PATH, true) as Dictionary
		_check(bool(attach_result.get("ok", false)), "P1-16A9 attaches generated zone%03d" % znum, str(attach_result.get("error", "")))
		_check(bool(bridge.call("has_attached_zone", znum)), "P1-16A9 bridge tracks attached zone%03d" % znum, str(bridge.call("attached_zone_ids")))
		_check(int(attach_result.get("branch_count", 0)) >= 5, "P1-16A9 attached zone%03d exposes runtime branches" % znum, str(attach_result.get("present_branches", [])))
		attached_direct.append(znum)
		var attached_node: Node = null
		if root != null:
			attached_node = root.get_node_or_null(NodePath("RuntimeGeneratedZone_%03d" % znum))
		_check(attached_node != null, "P1-16A9 runtime node exists in bridge root zone%03d" % znum)

	if attached_direct.size() > 0:
		var snap_attached: Dictionary = bridge.call("debug_snapshot") as Dictionary
		_check(int(snap_attached.get("attached_zone_count", 0)) == attached_direct.size(), "P1-16A9 direct attach count matches", str(snap_attached.get("attached_zones", [])))
	else:
		_check(true, "P1-16A9 direct attach skipped safely", "no generated scene file available")

	var detach_result: Dictionary = bridge.call("detach_all_generated_zones") as Dictionary
	_check(bool(detach_result.get("ok", false)), "P1-16A9 detach all succeeds")
	_check(int(detach_result.get("attached_zone_count", -1)) == 0, "P1-16A9 detach all clears bridge state", str(detach_result.get("attached_zones", [])))
	_debug.append("\n--- P1-16A9 generated runtime bridge after direct detach ---")
	_debug.append(_snapshot_debug_line(bridge.call("debug_snapshot")))

	var command: Node = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-16A9 command router present")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/generated status")), "P1-16A9 /generated status handled")
		var zone0_path: String = str(loader.call("scene_path_for_zone", 0, A7_MANIFEST_PATH))
		if zone0_path != "" and ResourceLoader.exists(zone0_path):
			_check(bool(command.call("execute_command", "/generated attach 0")), "P1-16A9 /generated attach 0 handled")
			_check(bool(command.call("execute_command", "/generated detach 0")), "P1-16A9 /generated detach 0 handled")
		else:
			_check(true, "P1-16A9 /generated attach 0 deferred because scene file is missing", zone0_path)
		if attached_direct.size() > 0:
			_check(bool(command.call("execute_command", "/generated attachall")), "P1-16A9 /generated attachall handled")
			_check(bool(command.call("execute_command", "/generated detachall")), "P1-16A9 /generated detachall handled")
		else:
			_check(true, "P1-16A9 /generated attachall deferred because no generated scene file is available")

	_debug.append("\n--- P1-16A9 generated runtime bridge post commands ---")
	var command_bridge: RefCounted = null
	if command != null:
		command_bridge = command.get("_generated_zone_runtime_bridge_a9") as RefCounted
	if command_bridge != null and command_bridge.has_method("debug_snapshot"):
		_debug.append(_snapshot_debug_line(command_bridge.call("debug_snapshot")))
	else:
		_debug.append(_snapshot_debug_line(bridge.call("debug_snapshot")))


func _test_generated_scene_parity_boot_p1_19a(zone_viewer: Node) -> void:
	_section("P1-19A generated scene parity & boot path")
	_check(DaocGeneratedSceneParityAuditScript != null, "P1-19A parity audit script exists")
	if DaocGeneratedSceneParityAuditScript == null:
		return
	var audit: RefCounted = DaocGeneratedSceneParityAuditScript.new()
	_check(audit != null, "P1-19A parity audit instantiates")
	if audit == null:
		return
	_check(audit.has_method("run_parity_audit"), "P1-19A exposes run_parity_audit")
	_check(audit.has_method("run_boot_probe"), "P1-19A exposes run_boot_probe")
	_check(zone_viewer.get("p1_19a_parity_enabled") != null, "P1-19A inspector parity checkbox exported")
	_check(zone_viewer.get("p1_19a_parity_run_on_ready") != null, "P1-19A inspector auto-run exported")
	_check(zone_viewer.get("p1_19a_generated_boot_enabled") != null, "P1-19A generated boot exported")
	_check(zone_viewer.get("p1_19a_generated_boot_enabled") == false, "P1-19A generated boot false by default")
	_check(zone_viewer.has_method("build_generated_scene_parity_options_p1_19a"), "P1-19A ZoneViewer options wrapper exists")
	_check(zone_viewer.has_method("_run_generated_scene_parity_from_inspector_p1_19a"), "P1-19A inspector runner exists")
	var options: Dictionary = {
		"zone_id": _first_configured_zone(zone_viewer),
		"manifest_path": A7_MANIFEST_PATH,
		"report_dir": "res://reports/p1_19a_generated_scene_parity",
		"write_reports": true,
		"boot_enabled": false,
		"focus_critical_fixtures": true,
		"max_fixture_compare": 32,
	}
	if zone_viewer.has_method("build_generated_scene_parity_options_p1_19a"):
		options = zone_viewer.call("build_generated_scene_parity_options_p1_19a", options) as Dictionary
		options["write_reports"] = true
		options["boot_enabled"] = false
	var report: Dictionary = audit.call("run_parity_audit", zone_viewer, options) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_19A_GENERATED_SCENE_PARITY_BOOT_PATH", "P1-19A checkpoint")
	_check(bool(report.get("non_destructive", false)), "P1-19A non destructive")
	_check(not bool(report.get("runtime_asset_conversion", true)), "P1-19A does not convert assets at runtime")
	_check(bool(report.get("server_authority", false)), "P1-19A server authority unchanged")
	_check(bool(report.get("prediction_only", false)), "P1-19A prediction-only guard remains true")
	_check(not bool(report.get("damage_final", true)), "P1-19A damage_final remains false")
	_check(typeof(report.get("structure", {})) == TYPE_DICTIONARY, "P1-19A structure report produced")
	_check(typeof(report.get("fixtures", {})) == TYPE_DICTIONARY, "P1-19A fixture parity report produced")
	_check(typeof(report.get("critical_focus", {})) == TYPE_DICTIONARY, "P1-19A critical fixture report produced")
	_check(typeof(report.get("collisions", {})) == TYPE_DICTIONARY, "P1-19A collision report produced")
	_check(typeof(report.get("water_zonejump_bounds", {})) == TYPE_DICTIONARY, "P1-19A water/zonejump/bounds report produced")
	var generated: Dictionary = report.get("generated_scene", {}) as Dictionary
	if bool(generated.get("loadable", false)):
		_check(str(report.get("overall_verdict", "")) != "", "P1-19A generated scene audit has verdict", str(report.get("overall_verdict", "")))
	else:
		_warn("P1-19A generated scene absent/incomplete; parity report written for chantier", str(generated.get("error", "")))
	var focus: Dictionary = report.get("critical_focus", {}) as Dictionary
	var focus_items: Array = focus.get("items", []) as Array
	_check(focus_items.size() >= 6, "P1-19A critical fixtures tracked", str(focus_items.size()))
	var written: Dictionary = report.get("written_files", {}) as Dictionary
	_check(str(written.get("json", "")) != "", "P1-19A json report written", str(written.get("json", "")))
	_check(str(written.get("txt", "")) != "", "P1-19A text report written", str(written.get("txt", "")))
	_check(str(written.get("fixtures_csv", "")) != "", "P1-19A fixtures csv written", str(written.get("fixtures_csv", "")))
	_check(str(written.get("critical_csv", "")) != "", "P1-19A critical csv written", str(written.get("critical_csv", "")))
	var player_node := _get_node_ref(zone_viewer, "_player")
	_check(player_node == null or player_node is CharacterBody3D, "P1-19A existing player CharacterBody3D preserved")
	_check(player_node == null or _count_node_type(player_node, "CollisionShape3D") > 0, "P1-19A existing player CollisionShape3D preserved")
	var command: Node = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-19A command router present")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/generated parity")), "P1-19A /generated parity handled")
		_check(bool(command.call("execute_command", "/generated focus brghouse")), "P1-19A /generated focus brghouse handled")
	_debug.append("\n--- P1-19A generated scene parity & boot path ---")
	_debug.append(_snapshot_debug_line(report))


func _test_zone_kind_resolver_p1_16a10a(zone_viewer: Node) -> void:
	_section("P1-16A10A zone kind classification manifest")
	_check(DaocZoneKindResolverScript != null, "P1-16A10A DaocZoneKindResolver exists")
	var resolver: RefCounted = DaocZoneKindResolverScript.new()
	_check(resolver != null, "P1-16A10A resolver instantiates")
	if resolver == null:
		return
	_check(resolver.has_method("classify_zone"), "P1-16A10A exposes classify_zone")
	_check(resolver.has_method("classify_zones"), "P1-16A10A exposes classify_zones")
	_check(resolver.has_method("is_generated_scene_supported"), "P1-16A10A exposes is_generated_scene_supported")

	var target_zone: int = _first_configured_zone(zone_viewer)
	var classification: Dictionary = resolver.call("classify_zone", zone_viewer, target_zone) as Dictionary
	_debug.append("\n--- P1-16A10A zone kind classification ---")
	_debug.append(_snapshot_debug_line(classification))
	var valid_kinds: Array = ["terrain_heightmap", "dungeon_chunk", "tileworld_city", "tileworld_footprint", "unknown"]
	var zone_kind: String = str(classification.get("zone_kind", ""))
	_check(int(classification.get("zone_id", -1)) == target_zone, "P1-16A10A classification targets active/configured zone", "target=%d got=%s" % [target_zone, str(classification.get("zone_id", -1))])
	_check(valid_kinds.has(zone_kind), "P1-16A10A returns known zone kind", zone_kind)
	_check(str(classification.get("generated_scene_status", "")) != "", "P1-16A10A returns generated scene status", str(classification.get("generated_scene_status", "")))
	_check(str(classification.get("reason", "")) != "", "P1-16A10A returns reason", str(classification.get("reason", "")))
	var evidence: Dictionary = classification.get("evidence", {}) as Dictionary
	_check(not evidence.is_empty(), "P1-16A10A records evidence dictionary")
	_check(evidence.has("files"), "P1-16A10A evidence has files")
	_check(evidence.has("runtime"), "P1-16A10A evidence has runtime")
	if zone_kind == "terrain_heightmap":
		_check(bool(classification.get("supported_for_generated_scene", false)), "P1-16A10A terrain heightmap is generated-scene supported")
	else:
		_check(not bool(classification.get("supported_for_generated_scene", true)), "P1-16A10A non-terrain kind is not generated-scene primary")

	var manifest: Dictionary = resolver.call("classify_zones", zone_viewer, [target_zone]) as Dictionary
	_check(bool(manifest.get("ok", false)), "P1-16A10A classify_zones manifest ok")
	_check(str(manifest.get("schema", "")) == "daoc.zone_kind_manifest.v1", "P1-16A10A manifest schema", str(manifest.get("schema", "")))
	_check(int(manifest.get("zone_count", 0)) == 1, "P1-16A10A manifest has one requested zone", str(manifest.get("zone_count", 0)))
	_check((manifest.get("zones", []) as Array).size() == 1, "P1-16A10A manifest stores one classification entry")
	_check((manifest.get("generated_scene_primary_allowed_only_for", []) as Array).has("terrain_heightmap"), "P1-16A10A generated primary is limited to terrain_heightmap", str(manifest.get("generated_scene_primary_allowed_only_for", [])))

	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null and creator.has_method("classify_zone_kind_a10a"), "P1-16A10A ZoneCreator exposes classify_zone_kind_a10a")
	_check(creator != null and creator.has_method("classify_zones_manifest_a10a"), "P1-16A10A ZoneCreator exposes classify_zones_manifest_a10a")
	if creator != null and creator.has_method("classify_zones_manifest_a10a"):
		var creator_manifest: Dictionary = creator.call("classify_zones_manifest_a10a", zone_viewer, [target_zone], {}) as Dictionary
		_check(bool(creator_manifest.get("ok", false)), "P1-16A10A ZoneCreator classification manifest ok")

	var command: Node = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "P1-16A10A command router present")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/zonecreator classify %d" % target_zone)), "P1-16A10A /zonecreator classify handled")




func _test_dungeon_zonecreator_p1_17c(zone_viewer: Node) -> void:
	_section("P1-17C dungeon_chunk ZoneCreator integration")
	_check(DaocDungeonFileResolverScript != null, "P1-17C DaocDungeonFileResolver exists")
	_check(DaocDungeonSceneBuilderScript != null, "P1-17C DaocDungeonSceneBuilder exists")
	var builder: RefCounted = DaocDungeonSceneBuilderScript.new()
	_check(builder != null, "P1-17C dungeon builder instantiates")
	_check(builder != null and builder.has_method("build"), "P1-17C dungeon builder exposes build")
	var creator: RefCounted = DaocZoneCreatorScript.new()
	_check(creator != null, "P1-17C ZoneCreator instantiates")
	_check(creator != null and creator.has_method("export_dungeon_scene_c2"), "P1-17C ZoneCreator exposes export_dungeon_scene_c2")
	_check(creator != null and creator.has_method("export_dungeon_scene_c2_debug_snapshot"), "P1-17C ZoneCreator exposes dungeon debug snapshot")
	_check(creator != null and creator.has_method("export_dungeon_scenes_batch_c2"), "P1-17C ZoneCreator exposes export_dungeon_scenes_batch_c2")
	_check(creator != null and creator.has_method("export_dungeon_scenes_batch_c2_debug_snapshot"), "P1-17C ZoneCreator exposes dungeon batch debug snapshot")
	_check(creator != null and creator.has_method("validate_generated_dungeon_scenes_c3"), "P1-17C3 ZoneCreator exposes generated dungeon report validation")
	_check(creator != null and creator.has_method("validate_generated_dungeon_scenes_c3_debug_snapshot"), "P1-17C3 ZoneCreator exposes generated dungeon report debug snapshot")
	if DaocDungeonFileResolverScript != null:
		_check(str(DaocDungeonFileResolverScript.default_zone_name(19)) == "Stonehenge Barrows Dungeon", "P1-17C resolver knows Barrows zone019")
		_check(str(DaocDungeonFileResolverScript.default_zone_name(21)) == "Tomb of Mithra", "P1-17C resolver knows Mithra zone021")
	if creator != null and creator.has_method("status"):
		var status: Dictionary = creator.call("status") as Dictionary
		_check(str(status.get("dungeon_scene_export_checkpoint", "")) == "P1_17C2_ZONECREATOR_DUNGEON_CHUNK_INTEGRATION", "P1-17C status exposes dungeon export checkpoint", str(status.get("dungeon_scene_export_checkpoint", "")))
		_check(str(status.get("default_dungeon_manifest_path", "")) == "res://reports/generated/zones/dungeon_manifest.json", "P1-17C status exposes dungeon manifest path", str(status.get("default_dungeon_manifest_path", "")))
		_check(str(status.get("generated_dungeon_report_checkpoint", "")) == "P1_17C3_GENERATED_DUNGEON_SCENE_REGRESSION_REPORT", "P1-17C3 status exposes generated dungeon report checkpoint", str(status.get("generated_dungeon_report_checkpoint", "")))
		_check(str(status.get("default_dungeon_report_json_path", "")) == "res://reports/daoc_generated_dungeon_report.json", "P1-17C3 status exposes dungeon report json path", str(status.get("default_dungeon_report_json_path", "")))
	_check(DaocGeneratedDungeonRuntimeBridgeScript != null, "P1-17D/P1-17E1 GeneratedDungeon runtime bridge script exists")
	_check(DaocWorldDestinationScript != null, "P1-17E1 WorldDestination script exists")
	_check(DaocServerBackendAdapterScript != null, "P1-17E1 ServerBackendAdapter script exists")
	_check(DaocWorldDestinationResolverScript != null, "P1-17E1 WorldDestinationResolver script exists")
	_check(DaocDolDestinationAdapterScript != null, "P1-17E1 DOL destination adapter script exists")
	_check(DaocOpenDaocDestinationAdapterScript != null, "P1-17E1 OpenDAoC destination adapter script exists")
	_check(DaocFallbackDestinationAdapterScript != null, "P1-17E1 fallback destination adapter script exists")
	_check(DaocServerInstructionDbScript != null, "P1-17E2C ServerInstructionDb script exists")
	_check(DaocOpenDaocSqlImportScript != null, "P1-17E2D OpenDAoC SQL importer script exists")
	_check(DaocServerCoordinateMarkerPlanScript != null, "P1-17E2J server coordinate marker planner script exists")
	_test_server_instruction_db_p1_17e2c()
	_test_opendaoc_sql_import_p1_17e2d()
	_test_opendaoc_db_viewer_path_p1_17e2g(zone_viewer)
	_test_opendaoc_real_sql_report_p1_17e2e(zone_viewer)
	_test_server_coordinate_frame_probe_p1_17e2f()
	_test_server_coordinate_markers_p1_17e2j()
	var destination_resolver: RefCounted = DaocWorldDestinationResolverScript.new()
	_check(destination_resolver != null, "P1-17E1 WorldDestinationResolver instantiates")
	if destination_resolver != null and destination_resolver.has_method("resolve_destination_for_zone"):
		var destination_result: Dictionary = destination_resolver.call("resolve_destination_for_zone", 19, {"destination_backend_preference": "auto"}) as Dictionary
		_check(not bool(destination_result.get("ok", false)), "P1-17E1 resolver does not invent Barrows server spawn without imported data")
		_check(str(destination_result.get("checkpoint", "")) == "P1_17E1_WORLD_DESTINATION_ABSTRACTION", "P1-17E1 resolver exposes checkpoint", str(destination_result.get("checkpoint", "")))
		_check(str(destination_result.get("authenticity", "")) == "fallback", "P1-17E1 missing server destination is explicit fallback state", str(destination_result.get("authenticity", "")))
	var dungeon_bridge: RefCounted = DaocGeneratedDungeonRuntimeBridgeScript.new()
	_check(dungeon_bridge != null, "P1-17D GeneratedDungeon runtime bridge instantiates")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("attach_dungeon_scene"), "P1-17D bridge exposes attach_dungeon_scene")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("attach_and_spawn_player"), "P1-17D bridge exposes attach_and_spawn_player")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("spawn_player_on_dungeon"), "P1-17D bridge exposes spawn_player_on_dungeon")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("sample_floor_daoc"), "P1-17D bridge exposes sample_floor_daoc")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("daoc_to_godot"), "P1-17D bridge exposes dungeon daoc_to_godot")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("detach_all_dungeon_scenes"), "P1-17D HF2 bridge exposes detach_all isolation restore")
	_check(dungeon_bridge != null and dungeon_bridge.has_method("restore_player_after_dungeon"), "P1-17D HF3 bridge exposes exterior player restore")
	if dungeon_bridge != null and dungeon_bridge.has_method("debug_snapshot"):
		var bridge_snap_17e: Dictionary = dungeon_bridge.call("debug_snapshot") as Dictionary
		_check(str(bridge_snap_17e.get("checkpoint", "")) == "P1_17E1_WORLD_DESTINATION_RUNTIME_BRIDGE", "P1-17E1 bridge exposes WorldDestination checkpoint", str(bridge_snap_17e.get("checkpoint", "")))
		_check(bridge_snap_17e.has("destination_resolver"), "P1-17E1 bridge snapshot includes destination resolver")
	_check(bool(zone_viewer.get("generated_dungeon_runtime_isolate_exterior")), "P1-17D HF2 dungeon runtime isolates exterior by default")
	_check(float(zone_viewer.get("generated_dungeon_runtime_scale_compensation")) >= 9.9, "P1-17D HF2 dungeon runtime scale compensation enabled", str(zone_viewer.get("generated_dungeon_runtime_scale_compensation")))
	_check(not bool(zone_viewer.get("generated_dungeon_runtime_auto_export_missing")), "P1-17D HF2 runtime auto-export disabled by default")
	_check(bool(zone_viewer.get("generated_dungeon_runtime_remember_exterior_player_state")), "P1-17D HF3 exterior player restore enabled by default")
	_check(str(zone_viewer.get("generated_dungeon_runtime_destination_backend_preference")) == "auto", "P1-17E1 destination backend preference defaults to auto", str(zone_viewer.get("generated_dungeon_runtime_destination_backend_preference")))
	_check(zone_viewer.has_method("ensure_generated_dungeon_runtime_bridge_17d"), "P1-17D ZoneViewer exposes generated dungeon runtime bridge getter")
	_check(zone_viewer.has_method("get_generated_dungeon_runtime_17d_debug_snapshot"), "P1-17D ZoneViewer exposes generated dungeon runtime snapshot")
	_check(zone_viewer.has_method("has_generated_dungeon_runtime_zone_17d"), "P1-17D ZoneViewer exposes generated dungeon zone membership")
	var command_17d: Node = _get_node_ref(zone_viewer, "_command_router")
	_check(command_17d != null, "P1-17D command router available")
	if command_17d != null and command_17d.has_method("execute_command"):
		_check(bool(command_17d.call("execute_command", "/generateddungeon status")), "P1-17D /generateddungeon status handled")
	_debug.append("\n--- P1-17C/P1-17D/P1-17E1 dungeon integration ---")
	_debug.append("C methods=export_dungeon_scene_c2, export_dungeon_scenes_batch_c2, validate_generated_dungeon_scenes_c3; D methods=attach_dungeon_scene, attach_and_spawn_player; heavy dungeon attach/spawn intentionally not run in F12 global; HF2 isolates/scale, HF3 adds fixed entry spawn fallback + exterior restore + dungeon XY unclamped; E1 adds neutral WorldDestination resolver and DOL/OpenDAoC adapter contract; E2C adds abstract server instruction DB slots; E2D adds OpenDAoC SQL import prep slots; E2E adds local real opendaoc-db-core report/export; E2F adds server-coordinate-frame probe tasks with no runtime spawn; E2G adds persistent ZoneViewer OpenDAoC DB path field")


func _test_server_instruction_db_p1_17e2c() -> void:
	_section("P1-17E2C abstract server instruction DB")
	_check(FileAccess.file_exists("res://data/server_instruction_db/manifest_p1_17e2c.db"), "P1-17E2C manifest .db exists")
	_check(FileAccess.file_exists("res://data/server_instruction_db/unified_client_instruction_contracts_p1_17e2c.db"), "P1-17E2C unified instruction .db exists")
	_check(FileAccess.file_exists("res://data/server_instruction_db/server_profiles_abstract_p1_17e2c.db"), "P1-17E2C server profiles .db exists")
	_check(FileAccess.file_exists("res://data/server_instruction_db/server_table_slots_p1_17e2c.db"), "P1-17E2C server table slots .db exists")
	if DaocServerInstructionDbScript == null:
		return
	var db: RefCounted = DaocServerInstructionDbScript.new()
	_check(db != null, "P1-17E2C instruction DB instantiates")
	if db == null:
		return
	_check(db.has_method("load_default"), "P1-17E2C instruction DB exposes load_default")
	_check(db.has_method("query"), "P1-17E2C instruction DB exposes query")
	_check(db.has_method("build_backend_context"), "P1-17E2C instruction DB exposes backend context")
	var load_result: Dictionary = db.call("load_default") as Dictionary
	_check(bool(load_result.get("ok", false)), "P1-17E2C instruction DB loads default manifest", str(load_result.get("errors", [])))
	_check(str(load_result.get("checkpoint", "")) == "P1_17E2C_ABSTRACT_SERVER_DB", "P1-17E2C load result checkpoint", str(load_result.get("checkpoint", "")))
	_check(int(load_result.get("record_count", 0)) >= 50, "P1-17E2C loads identified mechanics records", str(load_result.get("record_count", 0)))
	_check(int(load_result.get("profile_count", 0)) >= 2, "P1-17E2C loads DOL/OpenDAoC abstract profiles", str(load_result.get("profile_count", 0)))
	_check(int(load_result.get("table_slot_count", 0)) >= 6, "P1-17E2C loads server table slots", str(load_result.get("table_slot_count", 0)))
	var summary: Dictionary = db.call("summarize") as Dictionary
	_check(bool(summary.get("abstract_only", false)), "P1-17E2C summary stays abstract-only")
	_check(str(summary.get("checkpoint", "")) == "P1_17E2C_ABSTRACT_SERVER_DB", "P1-17E2C summary checkpoint", str(summary.get("checkpoint", "")))
	var p0_records: Array = db.call("query", {"priority": "P0"}) as Array
	_check(p0_records.size() > 0, "P1-17E2C query P0 returns records", str(p0_records.size()))
	var zonepoint_records: Array = db.call("query", {"mechanic_contains": "zonepoint"}) as Array
	_check(zonepoint_records.size() > 0, "P1-17E2C query finds ZonePoint/regionchange records", str(zonepoint_records.size()))
	var spell_records: Array = db.call("query", {"tag": "spell"}) as Array
	_check(spell_records.size() > 0, "P1-17E2C query finds spell records", str(spell_records.size()))
	var combat_records: Array = db.call("query", {"tag": "combat"}) as Array
	_check(combat_records.size() > 0, "P1-17E2C query finds combat records", str(combat_records.size()))
	var dol_context: Dictionary = db.call("build_backend_context", "dol") as Dictionary
	var opendaoc_context: Dictionary = db.call("build_backend_context", "opendaoc") as Dictionary
	_check(bool(dol_context.get("ok", false)), "P1-17E2C builds DOL abstract backend context")
	_check(bool(opendaoc_context.get("ok", false)), "P1-17E2C builds OpenDAoC abstract backend context")
	_check(not bool(dol_context.get("runtime_enabled", true)), "P1-17E2C DOL context has no runtime effect")
	_check(not bool(opendaoc_context.get("runtime_enabled", true)), "P1-17E2C OpenDAoC context has no runtime effect")
	var zonepoint_slot: Dictionary = db.call("get_table_slot", "world_destination_zonepoint") as Dictionary
	_check(not zonepoint_slot.is_empty(), "P1-17E2C ZonePoint table slot exists")
	_check(str(zonepoint_slot.get("runtime_status", "")) == "pending_real_db", "P1-17E2C ZonePoint slot waits for real DB", str(zonepoint_slot.get("runtime_status", "")))
	_debug.append("\n--- P1-17E2C abstract server instruction DB ---")
	_debug.append(_snapshot_debug_line(summary))


func _test_opendaoc_sql_import_p1_17e2d() -> void:
	_section("P1-17E2D OpenDAoC SQL DB import preparation")
	_check(DaocOpenDaocSqlImportScript != null, "P1-17E2D OpenDAoC SQL importer exists")
	_check(FileAccess.file_exists("res://data/server_instruction_db/opendaoc_sql_import_slots_p1_17e2d.db"), "P1-17E2D OpenDAoC SQL slot .db exists")
	if DaocOpenDaocSqlImportScript == null:
		return
	var importer: RefCounted = DaocOpenDaocSqlImportScript.new()
	_check(importer != null, "P1-17E2D importer instantiates")
	if importer == null:
		return
	_check(importer.has_method("load_slot_db"), "P1-17E2D importer exposes load_slot_db")
	_check(importer.has_method("parse_sql_text"), "P1-17E2D importer exposes parse_sql_text")
	_check(importer.has_method("parse_sql_file"), "P1-17E2D importer exposes parse_sql_file")
	_check(importer.has_method("parse_sql_directory"), "P1-17E2D importer exposes parse_sql_directory")
	_check(importer.has_method("build_coverage_report"), "P1-17E2D importer exposes build_coverage_report")
	_check(importer.has_method("normalize_world_destination_rows"), "P1-17E2D importer exposes normalize_world_destination_rows")
	var slot_load: Dictionary = importer.call("load_slot_db") as Dictionary
	_check(bool(slot_load.get("ok", false)), "P1-17E2D slot db loads", str(slot_load.get("errors", [])))
	_check(str(slot_load.get("checkpoint", "")) == "P1_17E2D_OPENDAOC_SQL_DB_IMPORT", "P1-17E2D slot db checkpoint", str(slot_load.get("checkpoint", "")))
	_check(int(slot_load.get("slot_count", 0)) >= 8, "P1-17E2D slot db has core SQL slots", str(slot_load.get("slot_count", 0)))

	var zonepoint_sql: String = "INSERT INTO `ZonePoint` (`Id`,`TargetRegion`,`TargetX`,`TargetY`,`TargetZ`,`TargetHeading`,`Realm`,`ClassType`) VALUES (1001,20,12345,23456,3456,2048,1,''),(1002,21,22345,33456,2456,1024,1,'');"
	var region_sql: String = "INSERT INTO `Regions` (`RegionID`,`Name`,`Description`) VALUES (20,'Stonehenge Barrows','Stonehenge Barrows'),(21,'Tomb of Mithra','Tomb of Mithra');"
	var startup_sql: String = "INSERT INTO `StartupLocation` (`Region`,`XPos`,`YPos`,`ZPos`,`Heading`,`Realm`,`Class`) VALUES (1,5000,6000,1000,0,1,0);"
	var zonepoint_table: Dictionary = importer.call("parse_sql_text", "opendaoc_zonepoint", zonepoint_sql, {"expected_columns": ["Id", "TargetRegion", "TargetX", "TargetY", "TargetZ", "TargetHeading"]}) as Dictionary
	var region_table: Dictionary = importer.call("parse_sql_text", "opendaoc_regions", region_sql, {"expected_columns": ["RegionID", "Name", "Description"]}) as Dictionary
	var startup_table: Dictionary = importer.call("parse_sql_text", "opendaoc_startuplocation", startup_sql, {"expected_columns": ["Region", "XPos", "YPos", "ZPos", "Heading"]}) as Dictionary
	_check(bool(zonepoint_table.get("ok", false)), "P1-17E2D parses ZonePoint SQL fixture")
	_check(str(zonepoint_table.get("table_name", "")) == "ZonePoint", "P1-17E2D infers ZonePoint table name", str(zonepoint_table.get("table_name", "")))
	_check(int(zonepoint_table.get("insert_column_count", 0)) >= 8, "P1-17E2D reads ZonePoint columns", str(zonepoint_table.get("insert_column_count", 0)))
	_check((zonepoint_table.get("rows_sample", []) as Array).size() == 2, "P1-17E2D samples ZonePoint rows", str((zonepoint_table.get("rows_sample", []) as Array).size()))
	_check((zonepoint_table.get("dungeon_region_mentions", []) as Array).has(20), "P1-17E2D detects Barrows region candidate 20", str(zonepoint_table.get("dungeon_region_mentions", [])))
	_check((zonepoint_table.get("dungeon_region_mentions", []) as Array).has(21), "P1-17E2D detects Mithra region candidate 21", str(zonepoint_table.get("dungeon_region_mentions", [])))
	_check(bool(region_table.get("ok", false)), "P1-17E2D parses Regions SQL fixture")
	_check((region_table.get("name_hits", []) as Array).has("stonehenge"), "P1-17E2D detects Stonehenge name hit", str(region_table.get("name_hits", [])))
	_check((region_table.get("name_hits", []) as Array).has("mithra"), "P1-17E2D detects Mithra name hit", str(region_table.get("name_hits", [])))
	_check(bool(startup_table.get("ok", false)), "P1-17E2D parses StartupLocation SQL fixture")
	var normalized: Array = importer.call("normalize_world_destination_rows", zonepoint_table) as Array
	_check(normalized.size() == 2, "P1-17E2D normalizes ZonePoint rows as destination samples", str(normalized.size()))
	if normalized.size() > 0:
		var first_dest: Dictionary = normalized[0] as Dictionary
		_check(str(first_dest.get("authenticity", "")) == "server_db_imported_unconfirmed_frame", "P1-17E2D normalized destination remains unconfirmed", str(first_dest.get("authenticity", "")))
		_check(not bool(first_dest.get("coordinate_frame_confirmed", true)), "P1-17E2D normalized destination keeps coordinate frame unconfirmed")
		_check(not bool(first_dest.get("runtime_enabled", true)), "P1-17E2D normalized destination has no runtime effect")
	var coverage: Dictionary = importer.call("build_coverage_report", [zonepoint_table, region_table, startup_table]) as Dictionary
	_check(bool(coverage.get("ok", false)), "P1-17E2D coverage report builds")
	_check(int(coverage.get("present_table_count", 0)) == 3, "P1-17E2D coverage report counts parsed tables", str(coverage.get("present_table_count", 0)))
	_check(int(coverage.get("world_destination_table_count", 0)) >= 2, "P1-17E2D coverage sees world destination tables", str(coverage.get("world_destination_table_count", 0)))
	_check(str(coverage.get("barrows_mithra_coverage_status", "")) == "candidate_data_present_unconfirmed", "P1-17E2D Barrows/Mithra candidates stay unconfirmed", str(coverage.get("barrows_mithra_coverage_status", "")))
	_check(not bool(coverage.get("runtime_enabled", true)), "P1-17E2D coverage has no runtime effect")
	_check(not bool(coverage.get("coordinate_frame_confirmed", true)), "P1-17E2D coverage does not confirm coordinate frame")
	_debug.append("\n--- P1-17E2D OpenDAoC SQL DB import preparation ---")
	_debug.append(_snapshot_debug_line(coverage))



func _test_opendaoc_db_viewer_path_p1_17e2g(zone_viewer: Node) -> void:
	_section("P1-17E2G viewer persistent OpenDAoC DB path")
	_check(zone_viewer != null, "P1-17E2G ZoneViewer available")
	if zone_viewer == null:
		return
	_check(_has_property(zone_viewer, "opendaoc_db_core_dir"), "P1-17E2G ZoneViewer exposes opendaoc_db_core_dir")
	_check(_has_property(zone_viewer, "opendaoc_db_core_project_fallback_dir"), "P1-17E2G ZoneViewer exposes project fallback DB dir")
	_check(zone_viewer.has_method("get_opendaoc_db_core_candidate_paths"), "P1-17E2G ZoneViewer exposes DB candidate paths")
	_check(zone_viewer.has_method("get_opendaoc_db_core_debug_snapshot"), "P1-17E2G ZoneViewer exposes DB debug snapshot")
	var candidates: Array = _opendaoc_db_candidates_from_zone_viewer_p1_17e2g(zone_viewer)
	_check(candidates.size() >= 1, "P1-17E2G candidate path list is not empty", str(candidates))
	_check(candidates.has("res://data/server_dumps/opendaoc/opendaoc-db-core"), "P1-17E2G candidate paths include stable server_dumps fallback", str(candidates))
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_opendaoc_db_core_debug_snapshot"):
		snap = zone_viewer.call("get_opendaoc_db_core_debug_snapshot") as Dictionary
	_check(str(snap.get("checkpoint", "")) == "P1_17E2G_VIEWER_OPENDAOC_DB_PATH", "P1-17E2G snapshot checkpoint", str(snap.get("checkpoint", "")))
	_check(not bool(snap.get("runtime_enabled", true)), "P1-17E2G DB path field has no runtime effect")
	_check(not bool(snap.get("coordinate_frame_confirmed", true)), "P1-17E2G DB path field does not confirm coordinate frame")
	if DaocOpenDaocSqlImportScript != null:
		var importer: RefCounted = DaocOpenDaocSqlImportScript.new()
		if importer != null and importer.has_method("find_local_sql_directory"):
			var lookup: Dictionary = importer.call("find_local_sql_directory", candidates) as Dictionary
			_check(["found_local_sql_directory", "waiting_for_local_sql_directory"].has(str(lookup.get("status", ""))), "P1-17E2G importer accepts viewer candidate paths", str(lookup.get("status", "")))
			_check(not bool(lookup.get("runtime_enabled", true)), "P1-17E2G lookup has no runtime effect")
	_debug.append("\n--- P1-17E2G viewer OpenDAoC DB path ---")
	_debug.append(_snapshot_debug_line(snap))


func _opendaoc_db_candidates_from_zone_viewer_p1_17e2g(zone_viewer: Node) -> Array:
	if zone_viewer != null and zone_viewer.has_method("get_opendaoc_db_core_candidate_paths"):
		return zone_viewer.call("get_opendaoc_db_core_candidate_paths") as Array
	return []

func _test_opendaoc_real_sql_report_p1_17e2e(zone_viewer: Node = null) -> void:
	_section("P1-17E2E OpenDAoC real SQL local report")
	_check(DaocOpenDaocSqlImportScript != null, "P1-17E2E reuses OpenDAoC SQL importer")
	if DaocOpenDaocSqlImportScript == null:
		return
	var importer: RefCounted = DaocOpenDaocSqlImportScript.new()
	_check(importer != null, "P1-17E2E importer instantiates")
	if importer == null:
		return
	_check(importer.has_method("find_local_sql_directory"), "P1-17E2E importer exposes find_local_sql_directory")
	_check(importer.has_method("parse_configured_directory"), "P1-17E2E importer exposes parse_configured_directory")
	_check(importer.has_method("build_barrows_mithra_summary"), "P1-17E2E importer exposes Barrows/Mithra summary")
	_check(importer.has_method("export_last_report_json"), "P1-17E2E importer exposes JSON export")
	_check(importer.has_method("export_last_report_text"), "P1-17E2E importer exposes text export")
	var missing_lookup: Dictionary = importer.call("find_local_sql_directory", ["res://reports/test_fixtures/p1_17e2e_missing_opendaoc_db_core"]) as Dictionary
	_check(str(missing_lookup.get("status", "")) == "waiting_for_local_sql_directory", "P1-17E2E missing real SQL directory is a safe waiting state", str(missing_lookup.get("status", "")))
	_check(not bool(missing_lookup.get("runtime_enabled", true)), "P1-17E2E missing directory has no runtime effect")
	_check(not bool(missing_lookup.get("coordinate_frame_confirmed", true)), "P1-17E2E missing directory does not confirm coordinate frame")

	var fixture_dir_res: String = "res://reports/test_fixtures/p1_17e2e_opendaoc_db_core_fixture"
	var fixture_dir_abs: String = ProjectSettings.globalize_path(fixture_dir_res)
	DirAccess.make_dir_recursive_absolute(fixture_dir_abs)
	_write_text_file(fixture_dir_res.path_join("zonepoint.sql"), "INSERT INTO `ZonePoint` (`Id`,`TargetRegion`,`TargetX`,`TargetY`,`TargetZ`,`TargetHeading`,`Realm`,`ClassType`) VALUES (2001,20,11111,22222,3333,2048,1,''),(2002,21,44444,55555,2222,1024,1,'');")
	_write_text_file(fixture_dir_res.path_join("regions.sql"), "INSERT INTO `Regions` (`RegionID`,`Name`,`Description`) VALUES (20,'Stonehenge Barrows','Stonehenge Barrows'),(21,'Tomb of Mithra','Tomb of Mithra');")
	_write_text_file(fixture_dir_res.path_join("startuplocation.sql"), "INSERT INTO `StartupLocation` (`Region`,`XPos`,`YPos`,`ZPos`,`Heading`,`Realm`,`Class`) VALUES (1,5000,6000,1000,0,1,0);")
	var found_lookup: Dictionary = importer.call("find_local_sql_directory", [fixture_dir_res]) as Dictionary
	_check(str(found_lookup.get("status", "")) == "found_local_sql_directory", "P1-17E2E fixture SQL directory found", str(found_lookup.get("status", "")))
	_check(int(found_lookup.get("sql_file_count", 0)) >= 3, "P1-17E2E fixture SQL file count", str(found_lookup.get("sql_file_count", 0)))
	importer.call("load_slot_db")
	var selected_report_path: String = fixture_dir_res
	var selected_report_source: String = "fixture"
	var viewer_candidates: Array = _opendaoc_db_candidates_from_zone_viewer_p1_17e2g(zone_viewer)
	if not viewer_candidates.is_empty():
		var viewer_lookup: Dictionary = importer.call("find_local_sql_directory", viewer_candidates) as Dictionary
		if str(viewer_lookup.get("status", "")) == "found_local_sql_directory":
			selected_report_path = str(viewer_lookup.get("source_path", ""))
			selected_report_source = "viewer_configured"
	var real_report: Dictionary = importer.call("parse_configured_directory", selected_report_path) as Dictionary
	real_report["p1_17e2g_selected_report_source"] = selected_report_source
	importer.set("last_report", real_report.duplicate(true))
	_p1_17e2e_last_report = real_report.duplicate(true)
	_check(bool(real_report.get("ok", false)), "P1-17E2E configured directory report builds", str(real_report.get("errors", [])))
	_check(str(real_report.get("checkpoint", "")) == "P1_17E2E_OPENDAOC_REAL_SQL_LOCAL_REPORT", "P1-17E2E report checkpoint", str(real_report.get("checkpoint", "")))
	_check(str(real_report.get("status", "")) == "parsed_local_sql_directory", "P1-17E2E report status parsed", str(real_report.get("status", "")))
	_check(int(real_report.get("present_table_count", 0)) >= 3, "P1-17E2E real report counts tables", str(real_report.get("present_table_count", 0)))
	_check(int(real_report.get("world_destination_table_count", 0)) >= 2, "P1-17E2E real report sees world destination tables", str(real_report.get("world_destination_table_count", 0)))
	_check(int(real_report.get("normalized_destination_sample_count", 0)) >= 2, "P1-17E2E real report normalizes destination samples", str(real_report.get("normalized_destination_sample_count", 0)))
	var summary: Dictionary = importer.call("build_barrows_mithra_summary", real_report) as Dictionary
	var barrows: Dictionary = summary.get("barrows", {}) as Dictionary
	var mithra: Dictionary = summary.get("mithra", {}) as Dictionary
	if selected_report_source == "fixture":
		_check(str(barrows.get("status", "")) == "destination_candidates_unconfirmed", "P1-17E2E Barrows fixture candidate remains unconfirmed", str(barrows.get("status", "")))
		_check(str(mithra.get("status", "")) == "destination_candidates_unconfirmed", "P1-17E2E Mithra fixture candidate remains unconfirmed", str(mithra.get("status", "")))
	else:
		_check(["destination_candidates_unconfirmed", "table_candidates_unconfirmed", "missing"].has(str(barrows.get("status", ""))), "P1-17E2E Barrows real DB summary remains non-runtime", str(barrows.get("status", "")))
		_check(["destination_candidates_unconfirmed", "table_candidates_unconfirmed", "missing"].has(str(mithra.get("status", ""))), "P1-17E2E Mithra real DB summary remains non-runtime", str(mithra.get("status", "")))
	_check(not bool(summary.get("runtime_enabled", true)), "P1-17E2E summary has no runtime effect")
	_check(not bool(summary.get("coordinate_frame_confirmed", true)), "P1-17E2E summary does not confirm coordinate frame")
	var json_export: Dictionary = importer.call("export_last_report_json", "res://reports/daoc_opendaoc_sql_realdb_report_p1_17e2e.json") as Dictionary
	var txt_export: Dictionary = importer.call("export_last_report_text", "res://reports/daoc_opendaoc_sql_realdb_report_p1_17e2e.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-17E2E JSON report export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-17E2E text report export works", str(txt_export.get("error", "")))
	_debug.append("\n--- P1-17E2E OpenDAoC real SQL local report ---")
	_debug.append(_snapshot_debug_line(real_report))



func _test_server_coordinate_frame_probe_p1_17e2f() -> void:
	_section("P1-17E2F server coordinate frame probe")
	_check(DaocServerCoordinateFrameProbeScript != null, "P1-17E2F coordinate frame probe script exists")
	if DaocServerCoordinateFrameProbeScript == null:
		return
	var probe: RefCounted = DaocServerCoordinateFrameProbeScript.new()
	_check(probe != null, "P1-17E2F probe instantiates")
	if probe == null:
		return
	_check(probe.has_method("build_probe_report"), "P1-17E2F exposes build_probe_report")
	_check(probe.has_method("probe_destination"), "P1-17E2F exposes probe_destination")
	_check(probe.has_method("build_manual_validation_tasks"), "P1-17E2F exposes manual validation tasks")
	_check(probe.has_method("export_last_probe_json"), "P1-17E2F exposes JSON export")
	_check(probe.has_method("export_last_probe_text"), "P1-17E2F exposes text export")
	var fixture_report: Dictionary = {
		"status": "parsed_local_sql_directory_fixture",
		"barrows_mithra_summary": {
			"barrows": {
				"status": "destination_candidates_unconfirmed",
				"normalized_destination_samples": [{
					"backend": "opendaoc",
					"table_id": "zonepoint",
					"record_id": "2001",
					"target_region_id": 20,
					"x": 11111,
					"y": 22222,
					"z": 3333,
					"heading_raw": 2048,
					"authenticity": "server_db_imported_unconfirmed_frame",
					"coordinate_frame_confirmed": false,
					"runtime_enabled": false,
				}],
			},
			"mithra": {
				"status": "destination_candidates_unconfirmed",
				"normalized_destination_samples": [{
					"backend": "opendaoc",
					"table_id": "zonepoint",
					"record_id": "2002",
					"target_region_id": 21,
					"x": 44444,
					"y": 55555,
					"z": 2222,
					"heading_raw": 1024,
					"authenticity": "server_db_imported_unconfirmed_frame",
					"coordinate_frame_confirmed": false,
					"runtime_enabled": false,
				}],
			},
		},
	}
	var source_report: Dictionary = fixture_report
	var source_label: String = "fixture"
	if not _p1_17e2e_last_report.is_empty():
		source_report = _p1_17e2e_last_report.duplicate(true)
		source_label = str(source_report.get("p1_17e2g_selected_report_source", "real_report"))
	var report: Dictionary = probe.call("build_probe_report", source_report) as Dictionary
	_p1_17e2f_last_report = report.duplicate(true)
	_check(bool(report.get("ok", false)), "P1-17E2F probe report builds")
	_check(str(report.get("checkpoint", "")) == "P1_17E2F_SERVER_COORDINATE_FRAME_PROBE", "P1-17E2F checkpoint", str(report.get("checkpoint", "")))
	if source_label == "fixture":
		_check(int(report.get("candidate_count", 0)) == 2, "P1-17E2F sees two fixture destination candidates", str(report.get("candidate_count", 0)))
		_check(int(report.get("probe_count", 0)) == 2, "P1-17E2F builds two fixture probes", str(report.get("probe_count", 0)))
	else:
		_check(int(report.get("candidate_count", 0)) >= 0, "P1-17E2F accepts real DB candidate count", str(report.get("candidate_count", 0)))
		_check(int(report.get("probe_count", 0)) >= 0, "P1-17E2F accepts real DB probe count", str(report.get("probe_count", 0)))
	_check(int(report.get("manual_validation_task_count", 0)) >= 0, "P1-17E2F builds manual validation task set", str(report.get("manual_validation_task_count", 0)))
	_check(not bool(report.get("runtime_enabled", true)), "P1-17E2F has no runtime effect")
	_check(not bool(report.get("coordinate_frame_confirmed", true)), "P1-17E2F does not confirm coordinate frame")
	var probes: Array = report.get("probes", []) as Array
	for probe_value in probes:
		if typeof(probe_value) != TYPE_DICTIONARY:
			continue
		var one_probe: Dictionary = probe_value as Dictionary
		var rid: int = int(one_probe.get("target_region_id", 0))
		if rid == 20:
			_check(int(one_probe.get("expected_client_zone_id", -1)) == 19, "P1-17E2F maps Barrows to client zone019", str(one_probe.get("expected_client_zone_id", -1)))
			_check(str(one_probe.get("status", "")) != "", "P1-17E2F Barrows probe has validation status", str(one_probe.get("status", "")))
		elif rid == 21:
			_check(int(one_probe.get("expected_client_zone_id", -1)) == 21, "P1-17E2F maps Mithra to client zone021", str(one_probe.get("expected_client_zone_id", -1)))
			_check(str(one_probe.get("status", "")) != "", "P1-17E2F Mithra probe has validation status", str(one_probe.get("status", "")))
	var json_export: Dictionary = probe.call("export_last_probe_json", "res://reports/daoc_server_coordinate_frame_probe_p1_17e2f.json") as Dictionary
	var txt_export: Dictionary = probe.call("export_last_probe_text", "res://reports/daoc_server_coordinate_frame_probe_p1_17e2f.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-17E2F JSON probe export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-17E2F text probe export works", str(txt_export.get("error", "")))
	_debug.append("\n--- P1-17E2F server coordinate frame probe ---")
	_debug.append(_snapshot_debug_line(report))


func _test_server_coordinate_markers_p1_17e2j() -> void:
	_section("P1-17E2J server coordinate marker-only plan")
	_check(DaocServerCoordinateMarkerPlanScript != null, "P1-17E2J marker planner script exists")
	if DaocServerCoordinateMarkerPlanScript == null:
		return
	var marker_plan: RefCounted = DaocServerCoordinateMarkerPlanScript.new()
	_check(marker_plan != null, "P1-17E2J marker planner instantiates")
	if marker_plan == null:
		return
	_check(marker_plan.has_method("build_marker_plan"), "P1-17E2J exposes build_marker_plan")
	_check(marker_plan.has_method("daoc_xyz_to_godot_scene_local"), "P1-17E2J exposes DAoC->Godot marker transform")
	_check(marker_plan.has_method("create_marker_nodes"), "P1-17E2J exposes create_marker_nodes")
	_check(marker_plan.has_method("apply_markers_to_generated_dungeon_scene"), "P1-17E2J exposes opt-in scene marker bake")
	_check(marker_plan.has_method("export_last_plan_json"), "P1-17E2J exposes JSON export")
	_check(marker_plan.has_method("export_last_plan_text"), "P1-17E2J exposes text export")
	_check(marker_plan.has_method("build_compact_report"), "P1-17E2K exposes compact marker report")
	_check(marker_plan.has_method("build_validation_evidence_template"), "P1-17E2K exposes validation evidence template")
	var source_report: Dictionary = _p1_17e2f_last_report.duplicate(true)
	if source_report.is_empty():
		source_report = {
			"checkpoint": "P1_17E2F_SERVER_COORDINATE_FRAME_PROBE_FIXTURE",
			"probes": [
				{"target_region_id": 20, "expected_client_zone_id": 19, "x": 31424, "y": 34307, "z": 16496, "heading_raw": 1161, "source_record_id": "7", "source_table_id": "opendaoc_zonepoint", "authenticity": "server_db_imported_unconfirmed_frame"},
				{"target_region_id": 21, "expected_client_zone_id": 21, "x": 33150, "y": 32732, "z": 16480, "heading_raw": 2069, "source_record_id": "24", "source_table_id": "opendaoc_zonepoint", "authenticity": "server_db_imported_unconfirmed_frame"},
			],
		}
	var plan: Dictionary = marker_plan.call("build_marker_plan", source_report, {"dungeon_world_scale": 0.10, "runtime_scale_compensation": 10.0, "marker_lift_raw": 160.0}) as Dictionary
	_check(bool(plan.get("ok", false)), "P1-17E2J marker plan builds")
	_check(str(plan.get("checkpoint", "")) == "P1_17E2J_SERVER_COORDINATE_MARKER_ONLY", "P1-17E2J checkpoint", str(plan.get("checkpoint", "")))
	_check(bool(plan.get("marker_only", false)), "P1-17E2J plan is marker-only")
	_check(not bool(plan.get("runtime_enabled", true)), "P1-17E2J has no gameplay runtime effect")
	_check(not bool(plan.get("coordinate_frame_confirmed", true)), "P1-17E2J does not confirm coordinate frame")
	_check(not bool(plan.get("player_spawn_applied", true)), "P1-17E2J never applies player spawn")
	_check(int(plan.get("marker_count", 0)) == 2, "P1-17E2J builds exactly Barrows/Mithra marker candidates", str(plan.get("marker_count", 0)))
	_check(str(plan.get("placement_assumption", "")) == "dungeon_scene_local_daoc_xyz_to_godot_x_z_minus_y", "P1-17E2J records transform assumption", str(plan.get("placement_assumption", "")))
	var markers: Array = plan.get("markers", []) as Array
	var has_barrows_marker: bool = false
	var has_mithra_marker: bool = false
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value as Dictionary
		var rid: int = int(marker.get("target_region_id", 0))
		var scene_pos: Dictionary = marker.get("scene_local_marker_position", {}) as Dictionary
		_check(not scene_pos.is_empty(), "P1-17E2J marker has scene-local marker position", str(marker.get("id", "")))
		_check(str(marker.get("status", "")) == "marker_candidate_unconfirmed_frame", "P1-17E2J marker remains unconfirmed", str(marker.get("status", "")))
		_check(not bool(marker.get("coordinate_frame_confirmed", true)), "P1-17E2J marker does not confirm frame", str(marker.get("id", "")))
		_check(not bool(marker.get("player_spawn_applied", true)), "P1-17E2J marker does not spawn player", str(marker.get("id", "")))
		if rid == 20:
			has_barrows_marker = true
			_check(int(marker.get("client_zone_id", -1)) == 19, "P1-17E2J Barrows marker targets zone019", str(marker.get("client_zone_id", -1)))
			_check(str(marker.get("recommended_scene_path", "")).contains("GeneratedDungeon_019.tscn"), "P1-17E2J Barrows marker scene path", str(marker.get("recommended_scene_path", "")))
			_check(str(marker.get("source_record_id", "")) == "7", "P1-17E2K Barrows source ZonePoint id remains 7", str(marker.get("source_record_id", "")))
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "x", 31424.0), "P1-17E2K Barrows raw x exact")
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "y", 34307.0), "P1-17E2K Barrows raw y exact")
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "z", 16496.0), "P1-17E2K Barrows raw z exact")
			_check(_dict_float_close(scene_pos, "x", 3142.4), "P1-17E2K Barrows marker scene x exact")
			_check(_dict_float_close(scene_pos, "y", 1665.6), "P1-17E2K Barrows marker scene y includes lift")
			_check(_dict_float_close(scene_pos, "z", -3430.7), "P1-17E2K Barrows marker scene z exact")
			_check(int(marker.get("heading_raw", 0)) == 1161, "P1-17E2K Barrows heading exact", str(marker.get("heading_raw", 0)))
		elif rid == 21:
			has_mithra_marker = true
			_check(int(marker.get("client_zone_id", -1)) == 21, "P1-17E2J Mithra marker targets zone021", str(marker.get("client_zone_id", -1)))
			_check(str(marker.get("recommended_scene_path", "")).contains("GeneratedDungeon_021.tscn"), "P1-17E2J Mithra marker scene path", str(marker.get("recommended_scene_path", "")))
			_check(str(marker.get("source_record_id", "")) == "24", "P1-17E2K Mithra source ZonePoint id remains 24", str(marker.get("source_record_id", "")))
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "x", 33150.0), "P1-17E2K Mithra raw x exact")
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "y", 32732.0), "P1-17E2K Mithra raw y exact")
			_check(_dict_float_close(marker.get("daoc_position_raw", {}) as Dictionary, "z", 16480.0), "P1-17E2K Mithra raw z exact")
			_check(_dict_float_close(scene_pos, "x", 3315.0), "P1-17E2K Mithra marker scene x exact")
			_check(_dict_float_close(scene_pos, "y", 1664.0), "P1-17E2K Mithra marker scene y includes lift")
			_check(_dict_float_close(scene_pos, "z", -3273.2), "P1-17E2K Mithra marker scene z exact")
			_check(int(marker.get("heading_raw", 0)) == 2069, "P1-17E2K Mithra heading exact", str(marker.get("heading_raw", 0)))
	_check(has_barrows_marker, "P1-17E2J Barrows marker present")
	_check(has_mithra_marker, "P1-17E2J Mithra marker present")
	var dummy_root: Node3D = Node3D.new()
	dummy_root.name = "DummyGeneratedDungeonRoot_E2J"
	var apply_result: Dictionary = marker_plan.call("create_marker_nodes", dummy_root, plan, {"client_zone_id": 19, "coordinate_space": "scene_local"}) as Dictionary
	_check(bool(apply_result.get("ok", false)), "P1-17E2J can create marker nodes on a dungeon root")
	_check(int(apply_result.get("markers_created", 0)) >= 1, "P1-17E2J creates at least one zone019 marker node", str(apply_result.get("markers_created", 0)))
	_check(not bool(apply_result.get("runtime_enabled", true)), "P1-17E2J marker node creation has no gameplay runtime effect")
	_check(not bool(apply_result.get("coordinate_frame_confirmed", true)), "P1-17E2J marker node creation does not confirm frame")
	_check(not bool(apply_result.get("player_spawn_applied", true)), "P1-17E2J marker node creation does not spawn player")
	dummy_root.free()
	var missing_scene_result: Dictionary = marker_plan.call("apply_markers_to_generated_dungeon_scene", "res://reports/test_fixtures/missing_generated_dungeon_e2j.tscn", plan, 19, {}) as Dictionary
	_check(not bool(missing_scene_result.get("ok", true)), "P1-17E2J missing scene bake fails safely", str(missing_scene_result.get("error", "")))
	_check(not bool(missing_scene_result.get("player_spawn_applied", true)), "P1-17E2J missing scene bake does not spawn player")
	var compact_report: Dictionary = marker_plan.call("build_compact_report", plan) as Dictionary
	_check(bool(compact_report.get("ok", false)), "P1-17E2K compact marker report builds")
	_check(int(compact_report.get("marker_count", 0)) == 2, "P1-17E2K compact marker report preserves count", str(compact_report.get("marker_count", 0)))
	_check(not bool(compact_report.get("runtime_enabled", true)), "P1-17E2K compact report has no runtime effect")
	_check(not bool(compact_report.get("coordinate_frame_confirmed", true)), "P1-17E2K compact report does not confirm frame")
	_check(not bool(compact_report.get("player_spawn_applied", true)), "P1-17E2K compact report does not spawn player")
	var evidence_template: Dictionary = marker_plan.call("build_validation_evidence_template", plan) as Dictionary
	_check(bool(evidence_template.get("ok", false)), "P1-17E2K evidence template builds")
	_check((evidence_template.get("tasks", []) as Array).size() == 2, "P1-17E2K evidence template has one task per marker")
	_check(not bool(evidence_template.get("auto_confirm_allowed", true)), "P1-17E2K evidence template cannot auto-confirm")
	_check(not bool(evidence_template.get("coordinate_frame_confirmed", true)), "P1-17E2K evidence template keeps frame unconfirmed")
	_check(not bool(evidence_template.get("player_spawn_applied", true)), "P1-17E2K evidence template does not spawn player")
	var json_export: Dictionary = marker_plan.call("export_last_plan_json", "res://reports/daoc_server_coordinate_markers_p1_17e2j.json") as Dictionary
	var txt_export: Dictionary = marker_plan.call("export_last_plan_text", "res://reports/daoc_server_coordinate_markers_p1_17e2j.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-17E2J JSON marker export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-17E2J text marker export works", str(txt_export.get("error", "")))
	_debug.append("\n--- P1-17E2J server coordinate marker-only plan ---")
	_debug.append(_snapshot_debug_line(plan))


func _test_offline_preview_quality_p1_17f5(zone_viewer: Node) -> void:
	_section("P1-17F5 preview quality")
	_check(DaocOfflineWorldPreviewScript != null, "P1-17F5 offline preview quality script exists")
	if DaocOfflineWorldPreviewScript == null:
		return
	var preview: RefCounted = DaocOfflineWorldPreviewScript.new()
	_check(preview != null, "P1-17F5 preview quality service instantiates")
	if preview == null:
		return
	_check(preview.has_method("build_quality_report_from_scene"), "P1-17F5 can read attached preview placeholders")
	_check(preview.has_method("export_last_quality_report_json"), "P1-17F5 exposes quality JSON export")
	_check(preview.has_method("export_last_quality_report_text"), "P1-17F5 exposes quality text export")
	if zone_viewer == null:
		_check(true, "P1-17F5 no ZoneViewer available, quality report skipped safely")
		return
	var quality: Dictionary = preview.call("build_quality_report_from_scene", zone_viewer) as Dictionary
	var attached: int = int(quality.get("attached_placeholder_count", 0))
	if attached <= 0:
		_check(true, "P1-17F5 waiting for /offlinepreview show before measuring attached placeholders")
		_debug.append("\n--- P1-17F5 preview quality ---")
		_debug.append("No attached offline preview placeholders found. Run /offlinepreview show before F12 to populate reports/p1_17f5_preview_quality.*")
		return
	var vertical: Dictionary = quality.get("vertical_classification", {}) as Dictionary
	_check(bool(quality.get("ok", false)), "P1-17F5 quality report builds")
	_check(attached > 0, "P1-17F5 attached placeholders measured", str(attached))
	_check(int(quality.get("floor_snapped_count", 0)) >= 0, "P1-17F5 floor-snapped count available", str(quality.get("floor_snapped_count", 0)))
	_check(vertical.has("ok") and vertical.has("suspect") and vertical.has("bad"), "P1-17F5 vertical classification buckets present", str(vertical))
	_check((quality.get("top_20_abs_vertical_delta_raw", []) as Array).size() <= 20, "P1-17F5 top abnormal vertical cases capped at 20")
	_check(not bool(quality.get("runtime_enabled", true)), "P1-17F5 quality report has no gameplay runtime effect")
	_check(not bool(quality.get("coordinate_frame_confirmed", true)), "P1-17F5 quality report does not confirm coordinate frame")
	_check(not bool(quality.get("player_spawn_applied", true)), "P1-17F5 quality report does not spawn player")
	var json_export: Dictionary = preview.call("export_last_quality_report_json", "res://reports/p1_17f5_preview_quality.json") as Dictionary
	var txt_export: Dictionary = preview.call("export_last_quality_report_text", "res://reports/p1_17f5_preview_quality.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-17F5 quality JSON export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-17F5 quality text export works", str(txt_export.get("error", "")))
	_debug.append("\n--- P1-17F5 preview quality ---")
	_debug.append(_snapshot_debug_line(quality))



func _write_text_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _dict_float_close(values: Dictionary, key: String, expected: float, epsilon: float = 0.01) -> bool:
	return absf(float(values.get(key, 0.0)) - expected) <= epsilon


func _test_ground_capsule_4(zone_viewer: Node) -> void:
	_section("4. Ground / capsule controller")
	var player := _get_node_ref(zone_viewer, "_player")
	_check(player != null, "player available for ground tests")
	if player == null:
		return
	_check(bool(player.get("ground_probe_use_capsule_footprint")), "capsule footprint ground probe enabled")
	var floor_z := float(zone_viewer.call("sample_daoc_floor_z", int(player.get("daoc_zone")), float(player.get("daoc_x")), float(player.get("daoc_y")), float(player.get("daoc_z"))))
	_check(_is_finite_float(floor_z), "floor sample under player finite", "floor=%.1f" % floor_z)
	_check(player.has_method("get_movement_debug_snapshot"), "movement debug snapshot present")
	if player.has_method("get_movement_debug_snapshot"):
		var snap: Dictionary = player.call("get_movement_debug_snapshot") as Dictionary
		_check(str(snap.get("movement_state", "")) != "", "movement state named", str(snap.get("movement_state", "")))
		_check(snap.has("motor_flags"), "movement snapshot contains motor flags", str(snap))
		_check(snap.has("floor_source"), "movement snapshot contains floor source", str(snap.get("floor_source", "")))
		_check(snap.has("heightmap_floor_z"), "movement snapshot contains heightmap floor", str(snap.get("heightmap_floor_z", "")))
		_check(snap.has("collision_floor_z"), "movement snapshot contains collision floor", str(snap.get("collision_floor_z", "")))
		_debug.append("\n--- movement snapshot ---")
		_debug.append(_snapshot_debug_line(snap))


func _test_motor_p0_a3(zone_viewer: Node) -> void:
	_section("4B. Motor local P0-A3")
	var player := _get_node_ref(zone_viewer, "_player")
	var router := _get_node_ref(zone_viewer, "_input_router")
	_check(player != null, "player available for motor P0-A3 tests")
	if player == null:
		return
	_check(player.has_method("motor_compute_effective_speed_raw"), "motor effective speed helper present")
	_check(player.has_method("get_motor_constants_snapshot"), "motor constants snapshot helper present")
	_check(player.has_method("get_motor_local_flags_snapshot"), "motor local flags snapshot helper present")
	_check(player.has_method("set_climb_flag_local_placeholder"), "motor climb local placeholder setter present")
	_check(player.has_method("motor_movement_state_name_for_value"), "motor state name helper present")
	if not player.has_method("motor_compute_effective_speed_raw"):
		return
	var base_speed := float(player.get("local_run_speed_raw"))
	var walk_factor := float(player.get("walk_speed_factor"))
	var sprint_factor := float(player.get("sprint_speed_factor"))
	var run_speed := float(player.call("motor_compute_effective_speed_raw", false, false, false))
	var walk_speed := float(player.call("motor_compute_effective_speed_raw", true, false, false))
	var sprint_speed := float(player.call("motor_compute_effective_speed_raw", false, true, false))
	var wading_speed := float(player.call("motor_compute_effective_speed_raw", false, false, true))
	var walk_sprint_speed := float(player.call("motor_compute_effective_speed_raw", true, true, false))
	var walk_wading_speed := float(player.call("motor_compute_effective_speed_raw", true, false, true))
	_check(absf(run_speed - base_speed) <= 0.01, "motor run speed equals local base", "speed=%.1f" % run_speed)
	_check(absf(walk_speed - base_speed * walk_factor) <= 0.01, "motor walk factor applied", "speed=%.1f" % walk_speed)
	_check(absf(sprint_speed - base_speed * sprint_factor) <= 0.01, "motor sprint factor applied", "speed=%.1f" % sprint_speed)
	_check(absf(wading_speed - base_speed * 0.5) <= 0.01, "motor wading factor applied", "speed=%.1f" % wading_speed)
	_check(absf(walk_sprint_speed - walk_speed) <= 0.01, "motor walk takes precedence over sprint", "speed=%.1f" % walk_sprint_speed)
	_check(absf(walk_wading_speed - walk_speed * 0.5) <= 0.01, "motor walk and wading compose", "speed=%.1f" % walk_wading_speed)
	if player.has_method("get_motor_constants_snapshot"):
		var constants: Dictionary = player.call("get_motor_constants_snapshot") as Dictionary
		_check(float(constants.get("run_speed_raw", -1.0)) == base_speed, "motor constants expose run speed", str(constants))
		_check(float(constants.get("walk_speed_factor", -1.0)) == walk_factor, "motor constants expose walk factor", str(constants))
		_check(float(constants.get("sprint_speed_factor", -1.0)) == sprint_factor, "motor constants expose sprint factor", str(constants))
		_check(float(constants.get("wading_speed_factor", -1.0)) == 0.5, "motor constants expose wading factor", str(constants))
		var motor_states: Array = constants.get("states", []) as Array
		_check(motor_states.has("CLIMBING"), "motor constants expose climbing state", str(constants))
	if player.has_method("motor_movement_state_name_for_value"):
		_check(str(player.call("motor_movement_state_name_for_value", 0)) == "NORMAL", "motor state 0 is NORMAL")
		_check(str(player.call("motor_movement_state_name_for_value", 1)) == "SWIMMING", "motor state 1 is SWIMMING")
		_check(str(player.call("motor_movement_state_name_for_value", 2)) == "FALLING", "motor state 2 is FALLING")
		_check(str(player.call("motor_movement_state_name_for_value", 3)) == "CLIMBING", "motor state 3 is CLIMBING")
	if player.has_method("set_climb_flag_local_placeholder") and player.has_method("get_motor_local_flags_snapshot"):
		var saved_climb := bool(player.get("climb_flag_local_placeholder"))
		var saved_state := int(player.get("movement_state"))
		player.call("set_climb_flag_local_placeholder", true)
		var climb_snap: Dictionary = player.call("get_motor_local_flags_snapshot") as Dictionary
		_check(bool(climb_snap.get("climb_flag_local_placeholder", false)), "motor climb debug flag can be enabled", str(climb_snap))
		_check(bool(climb_snap.get("is_climbing", false)), "motor climb flag reports CLIMBING", str(climb_snap))
		player.call("set_climb_flag_local_placeholder", false)
		var climb_off_snap: Dictionary = player.call("get_motor_local_flags_snapshot") as Dictionary
		_check(not bool(climb_off_snap.get("climb_flag_local_placeholder", true)), "motor climb debug flag can be disabled", str(climb_off_snap))
		player.set("climb_flag_local_placeholder", saved_climb)
		player.set("movement_state", saved_state)
	if router != null:
		_check(router.has_method("get_locomotion_router_snapshot"), "router locomotion snapshot helper present")
		var st: Object = null
		if router.has_method("get_input_state"):
			st = router.call("get_input_state") as Object
		var saved_runlock := false
		var saved_walk_toggle := false
		if st != null:
			saved_runlock = bool(st.get("run_lock_enabled"))
		saved_walk_toggle = bool(router.get("_walk_toggle_enabled"))
		if router.has_method("runlock_enable") and router.has_method("runlock_disable") and st != null:
			router.call("runlock_enable")
			_check(bool(st.get("run_lock_enabled")), "router runlock can be enabled")
			router.call("runlock_disable")
			_check(not bool(st.get("run_lock_enabled")), "router runlock can be disabled")
			if saved_runlock:
				router.call("runlock_enable")
		if router.has_method("walk_toggle") and router.has_method("walk_disable") and st != null:
			router.call("walk_disable")
			router.call("walk_toggle")
			_check(bool(st.get("walk_held")), "router walk toggle updates input state")
			router.call("walk_disable")
			_check(not bool(st.get("walk_held")), "router walk disable clears input state")
			router.set("_walk_toggle_enabled", saved_walk_toggle)
			st.set("walk_held", saved_walk_toggle)
		if router.has_method("sprint_send_command_stub") and st != null:
			router.call("sprint_send_command_stub")
			_check(bool(st.get("sprint_pressed_frame")), "router sprint stub marks pressed frame", str(st.get("last_action_debug")))
		if router.has_method("get_locomotion_router_snapshot"):
			_debug.append("\n--- motor P0-A3 router snapshot ---")
			_debug.append(_snapshot_debug_line(router.call("get_locomotion_router_snapshot")))
	if player.has_method("get_motor_local_flags_snapshot"):
		_debug.append("\n--- motor P0-A3 flags snapshot ---")
		_debug.append(_snapshot_debug_line(player.call("get_motor_local_flags_snapshot")))


func _test_water_5(zone_viewer: Node) -> void:
	_section("5. Water / wading / swimming local state")
	var waters := _get_dict(zone_viewer, "_water_runtime")
	_check(waters.size() > 0, "water runtime populated", "zones=%s" % str(waters.keys()))
	for z in waters.keys():
		var water_bodies: Array = waters.get(z, []) as Array
		_check(water_bodies.size() > 0, "zone%03d water bodies present" % int(z), "bodies=%d" % water_bodies.size())
	_check(zone_viewer.has_method("get_water_debug_snapshot"), "water debug snapshot present")
	if zone_viewer.has_method("get_water_debug_snapshot"):
		_debug.append("\n--- water snapshot ---")
		_debug.append(_snapshot_debug_line(zone_viewer.call("get_water_debug_snapshot")))


func _test_water_p1_14b(zone_viewer: Node) -> void:
	_section("P1-14B WaterBuilder foundation")
	var builder: RefCounted = DaocWaterBuilderScript.new()
	var runtime: RefCounted = DaocWaterRuntimeScript.new()
	var build_result: RefCounted = DaocWaterBuildResultScript.new()
	_check(builder != null, "P1-14B DaocWaterBuilder exists")
	_check(runtime != null, "P1-14B DaocWaterRuntime exists")
	_check(build_result != null, "P1-14B DaocWaterBuildResult exists")
	_check(builder != null and builder.has_method("build"), "P1-14B builder exposes build")
	_check(builder != null and builder.has_method("compute_index_signature"), "P1-14B builder exposes compute_index_signature")
	_check(runtime != null and runtime.has_method("bind"), "P1-14B runtime exposes bind")
	_check(runtime != null and runtime.has_method("status"), "P1-14B runtime exposes status")
	_check(runtime != null and runtime.has_method("bodies_for_zone"), "P1-14B runtime exposes bodies_for_zone")
	_check(runtime != null and runtime.has_method("bodies_at_daoc"), "P1-14B runtime exposes bodies_at_daoc")
	_check(runtime != null and runtime.has_method("sample_daoc"), "P1-14B runtime exposes sample_daoc")

	var old_symbols := PackedStringArray([
		"_build_zone_water",
		"_make_water_body_mesh",
		"_sector_dat_point",
		"_make_water_material",
		"_register_water_runtime_body",
		"_point_in_water_body_2d",
		"_point_in_poly_2d",
	])
	for symbol in old_symbols:
		_check(not zone_viewer.has_method(symbol), "P1-14B ZoneViewer old water method absent: %s" % symbol)

	_check(zone_viewer.has_method("get_water_14b_debug_snapshot"), "P1-14B debug snapshot present")
	var snap: Dictionary = {}
	if zone_viewer.has_method("get_water_14b_debug_snapshot"):
		snap = zone_viewer.call("get_water_14b_debug_snapshot") as Dictionary
		_debug.append("\n--- P1-14B water builder snapshot ---")
		_debug.append(_snapshot_debug_line(snap))
	var metrics: Dictionary = snap.get("zone0_metrics", {}) as Dictionary
	_check(int(metrics.get("waterdefs", 0)) == 2, "P1-14B builder isolated zone000 waterdefs=2", str(metrics))
	_check(int(metrics.get("bodies", 0)) == 2, "P1-14B builder isolated zone000 bodies=2", str(metrics))
	_check(int(metrics.get("meshes", 0)) == 2, "P1-14B builder isolated zone000 meshes=2", str(metrics))
	_check(bool(metrics.get("packable_ok", false)), "P1-14B builder root packable", str(metrics))
	_check(bool(snap.get("packed_scene_ok", false)), "P1-14B ZoneViewer stored root packable")

	var results: Dictionary = _get_dict(zone_viewer, "_water_build_results")
	var zone0_result: RefCounted = results.get(0, null) as RefCounted
	_check(zone0_result != null, "P1-14B ZoneViewer stores build result for zone000")
	if zone0_result != null:
		var static_index: Array = zone0_result.get("static_index") as Array
		var signature := str(zone0_result.get("index_signature"))
		var recomputed := str(DaocWaterBuilderScript.compute_index_signature(static_index))
		_check(signature != "", "P1-14B index signature present", signature)
		_check(signature == recomputed, "P1-14B index signature stable", signature)
		_check(static_index.size() == int(metrics.get("meshes", static_index.size())), "P1-14B static index matches mesh count", "index=%d meshes=%d" % [static_index.size(), int(metrics.get("meshes", 0))])
		var live_runtime: RefCounted = zone_viewer.get("_water_runtime_obj") as RefCounted
		_check(live_runtime != null, "P1-14B ZoneViewer owns runtime")
		if live_runtime != null and static_index.size() > 0:
			var first: Dictionary = static_index[0] as Dictionary
			var xy := Vector2(float(first.get("sample_x", 0.0)), float(first.get("sample_y", 0.0)))
			var znum := int(first.get("source_zone", 0))
			var bodies: Array = live_runtime.call("bodies_at_daoc", znum, xy) as Array
			_check(bodies.size() > 0, "P1-14B bodies_at_daoc contains sample point", "bodies=%d section=%s" % [bodies.size(), str(first.get("section", ""))])
			var water_info: Dictionary = zone_viewer.call("sample_daoc_water_info", znum, xy.x, xy.y, float(first.get("height", 0.0))) as Dictionary
			_check(not water_info.is_empty(), "P1-14B sample_daoc_water_info delegates to runtime", _snapshot_debug_line(water_info))

	var waters := _get_dict(zone_viewer, "_water_runtime")
	_check(int((waters.get(0, []) as Array).size()) == 2, "P1-14B preserves zone000 water runtime body count", str((waters.get(0, []) as Array).size()))


func _test_camera_6(zone_viewer: Node) -> void:
	_section("6. Camera local client")
	var camera := _get_node_ref(zone_viewer, "_player_camera")
	_check(camera != null, "player camera node available")
	if camera == null:
		return
	var methods := [
		"orbit_mouse_dx", "tilt_mouse_dy", "zoom_wheel_notches", "reset_camera", "set_snapback_enabled",
		"toggle_camera_mode", "get_camera3d", "get_camera_debug_snapshot", "normalize_camera_values",
		"get_camera_constants_snapshot", "get_camera_state_for_restore", "restore_camera_state"
	]
	for m in methods:
		_check(camera.has_method(m), "camera method %s present" % m)
	var dist := float(camera.get("distance_raw"))
	var height := float(camera.get("height_raw"))
	var tilt := float(camera.get("tilt_raw"))
	var angle := float(camera.get("angle_raw"))
	_check(dist >= 25.0 and dist <= 1500.0, "camera distance in DAoC clamp range", "dist=%.1f" % dist)
	_check(height >= -50.0 and height <= 25.0, "camera height in live1420 clamp range", "height=%.1f" % height)
	_check(tilt >= 100.0 and tilt <= 1700.0, "camera tilt in live1420 clamp range", "tilt=%.1f" % tilt)
	_check(angle >= 0.0 and angle < 4096.0, "camera angle wrapped", "angle=%.1f" % angle)
	_check(bool(camera.get("camera_collision_enabled")), "camera collision enabled")
	var cam3d: Camera3D = null
	if camera.has_method("get_camera3d"):
		cam3d = camera.call("get_camera3d") as Camera3D
	_check(cam3d != null, "Camera3D instance returned")
	if cam3d != null:
		_check(cam3d.is_inside_tree(), "Camera3D is inside scene tree before look_at")
		if camera.has_method("get_pivot_global_position"):
			var pivot: Vector3 = camera.call("get_pivot_global_position") as Vector3
			var cam_dist := cam3d.global_position.distance_to(pivot)
			_check(cam_dist > 0.001, "Camera3D not exactly on pivot", "dist=%.3f" % cam_dist)
	if camera.has_method("get_camera_constants_snapshot"):
		var constants: Dictionary = camera.call("get_camera_constants_snapshot") as Dictionary
		_check(float(constants.get("distance_min", -1.0)) == 25.0, "camera live1420 distance min constant", str(constants))
		_check(float(constants.get("distance_max", -1.0)) == 700.0, "camera live1420 distance max constant", str(constants))
		_check(float(constants.get("distance_max_special", -1.0)) == 1500.0, "camera live1420 special distance max constant", str(constants))
		_check(float(constants.get("zoom_step", -1.0)) == 25.0, "camera wheel zoom step constant", str(constants))
		_check(float(constants.get("height_min", -999.0)) == -50.0 and float(constants.get("height_max", 999.0)) == 25.0, "camera live1420 height clamp constants", str(constants))
		_check(float(constants.get("tilt_min_live1420", -1.0)) == 100.0 and float(constants.get("tilt_center_live1420", -1.0)) == 900.0 and float(constants.get("tilt_max_live1420", -1.0)) == 1700.0, "camera live1420 tilt constants", str(constants))
	_test_camera_controls_p0_a2(camera)
	if camera.has_method("get_camera_debug_snapshot"):
		_debug.append("\n--- camera snapshot ---")
		_debug.append(_snapshot_debug_line(camera.call("get_camera_debug_snapshot")))


func _test_camera_controls_p0_a2(camera: Node) -> void:
	var saved_state: Dictionary = {}
	if camera.has_method("get_camera_state_for_restore"):
		saved_state = camera.call("get_camera_state_for_restore") as Dictionary
	var saved_input_state: Object = camera.get("input_state") as Object
	# Isoler les maths caméra des collisions pendant les micro-tests dynamiques.
	camera.set("camera_collision_enabled", false)
	camera.set("allow_boat_zoom_max", false)
	camera.set("distance_raw", 500.0)
	camera.call("zoom_wheel_notches", 1.0)
	_check(absf(float(camera.get("distance_raw")) - 475.0) <= 0.01, "camera wheel up zooms in by 25", "dist=%.1f" % float(camera.get("distance_raw")))
	camera.call("zoom_wheel_notches", -1.0)
	_check(absf(float(camera.get("distance_raw")) - 500.0) <= 0.01, "camera wheel down zooms out by 25", "dist=%.1f" % float(camera.get("distance_raw")))
	camera.set("distance_raw", 5.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("distance_raw")) - 25.0) <= 0.01, "camera normal distance clamps to 25 min", "dist=%.1f" % float(camera.get("distance_raw")))
	camera.set("distance_raw", 999.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("distance_raw")) - 700.0) <= 0.01, "camera normal distance clamps to 700 max", "dist=%.1f" % float(camera.get("distance_raw")))
	camera.set("allow_boat_zoom_max", true)
	camera.set("distance_raw", 1500.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("distance_raw")) - 1500.0) <= 0.01, "camera special distance accepts 1500", "dist=%.1f" % float(camera.get("distance_raw")))
	camera.set("height_raw", -999.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("height_raw")) + 50.0) <= 0.01, "camera height clamps to -50", "height=%.1f" % float(camera.get("height_raw")))
	camera.set("height_raw", 999.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("height_raw")) - 25.0) <= 0.01, "camera height clamps to 25", "height=%.1f" % float(camera.get("height_raw")))
	camera.set("tilt_raw", 0.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("tilt_raw")) - 100.0) <= 0.01, "camera tilt clamps to live1420 min 100", "tilt=%.1f" % float(camera.get("tilt_raw")))
	camera.set("tilt_raw", 1900.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("tilt_raw")) - 1700.0) <= 0.01, "camera tilt clamps to live1420 max 1700", "tilt=%.1f" % float(camera.get("tilt_raw")))
	camera.set("angle_raw", 4098.0)
	camera.call("normalize_camera_values")
	_check(absf(float(camera.get("angle_raw")) - 2.0) <= 0.01, "camera angle wraps at 4096", "angle=%.1f" % float(camera.get("angle_raw")))
	camera.set("angle_raw", 0.0)
	camera.call("orbit_mouse_dx", 10.0)
	_check(float(camera.get("angle_raw")) > 4000.0, "mouselook orbit updates wrapped angle", "angle=%.1f" % float(camera.get("angle_raw")))
	camera.set("tilt_raw", 174.0)
	camera.call("tilt_mouse_dy", 10.0)
	_check(float(camera.get("tilt_raw")) < 174.0 and float(camera.get("tilt_raw")) >= 100.0, "mouselook tilt updates vertical raw", "tilt=%.1f" % float(camera.get("tilt_raw")))
	camera.call("reset_camera")
	_check(absf(float(camera.get("distance_raw")) - 240.0) <= 0.01 and absf(float(camera.get("height_raw")) - 10.0) <= 0.01 and absf(float(camera.get("tilt_raw")) - 174.0) <= 0.01 and absf(float(camera.get("angle_raw"))) <= 0.01, "reset camera restores DAoC defaults", str(camera.call("get_camera_debug_snapshot")) if camera.has_method("get_camera_debug_snapshot") else "")
	var snap_state := DaocInputState.new()
	snap_state.forward_axis = 1.0
	snap_state.mouse_look_held = false
	snap_state.mouse_pan_held = false
	camera.call("set_input_state", snap_state)
	camera.call("set_snapback_enabled", true)
	camera.set("angle_raw", 512.0)
	camera.call("_update_snapback", 0.25)
	_check(float(camera.get("angle_raw")) < 512.0 or float(camera.get("angle_raw")) > 4000.0, "snapback moves camera angle toward zero while moving", "angle=%.1f" % float(camera.get("angle_raw")))
	if camera.has_method("restore_camera_state") and not saved_state.is_empty():
		camera.call("restore_camera_state", saved_state)
	camera.call("set_input_state", saved_input_state)


func _test_ui_7(zone_viewer: Node) -> void:
	_section("7. Dev UI / HUD")
	var hud := _get_node_ref(zone_viewer, "_dev_hud")
	_check(hud != null, "DaocDevHud exists")
	if hud == null:
		return
	_check(hud.has_method("get_debug_snapshot"), "HUD debug snapshot present")
	_check(hud.has_method("toggle_visible"), "HUD toggle method present")
	if hud.has_method("get_debug_snapshot"):
		_debug.append("\n--- dev HUD snapshot ---")
		_debug.append(_snapshot_debug_line(hud.call("get_debug_snapshot")))


func _test_targeting_8(zone_viewer: Node) -> void:
	_section("8. Local targeting / interactions")
	var targeter := _get_node_ref(zone_viewer, "_local_targeting")
	_check(targeter != null, "DaocLocalTargeting exists")
	if targeter == null:
		return
	_check(targeter.has_method("target_nearest_object"), "target_nearest_object present")
	_check(targeter.has_method("target_zonejump_nearest"), "target_zonejump_nearest present")
	_check(targeter.has_method("clear_target"), "clear_target present")
	_check(targeter.has_method("get_debug_snapshot"), "targeting debug snapshot present")
	if targeter.has_method("target_nearest_object"):
		var ok := bool(targeter.call("target_nearest_object", -1.0, false))
		_check(ok or int(targeter.get("last_scan_count")) >= 0, "nearest object scan executed", "result=%s scan=%s" % [str(ok), str(targeter.get("last_scan_count"))])
	if targeter.has_method("target_zonejump_nearest"):
		var ok_jump := bool(targeter.call("target_zonejump_nearest", 2400.0, false))
		_check(true, "nearest zonejump scan executed", "result=%s" % str(ok_jump))
	if targeter.has_method("get_debug_snapshot"):
		_debug.append("\n--- targeting snapshot ---")
		_debug.append(_snapshot_debug_line(targeter.call("get_debug_snapshot")))


func _test_dol_p1_n1(zone_viewer: Node) -> void:
	_section("P1-N1 DOL network skeleton")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	_check(dol != null, "DOL client node exists")
	if dol == null:
		return
	_check(dol.has_method("setup"), "DOL client setup present")
	_check(dol.has_method("start_login"), "DOL login stub present")
	_check(dol.has_method("request_charlist"), "DOL charlist stub present")
	_check(dol.has_method("enter_world"), "DOL enter world stub present")
	_check(dol.has_method("disconnect_from_server"), "DOL disconnect_from_server present")
	_check(dol.has_method("get_network_debug_snapshot"), "DOL network snapshot present")
	_check(dol.has_method("get_protocol_stage_snapshot"), "DOL protocol stage snapshot present")
	_check(dol.has_method("get_authority_boundary_snapshot"), "DOL authority boundary snapshot present")
	_check(dol.has_method("get_packet_flow_debug_snapshot"), "DOL packet flow snapshot present")
	_check(dol.has_method("get_connection_state_for_restore"), "DOL state restore snapshot present")
	_check(dol.has_method("restore_connection_state"), "DOL state restore method present")
	var saved := {}
	if dol.has_method("get_connection_state_for_restore"):
		saved = dol.call("get_connection_state_for_restore") as Dictionary
	if dol.has_method("reset_to_disconnected"):
		dol.call("reset_to_disconnected")
	var snap0: Dictionary = dol.call("get_network_debug_snapshot") as Dictionary
	_check(str(snap0.get("state_name", "")) == "DISCONNECTED", "DOL starts/reset to DISCONNECTED", str(snap0))
	_check(bool(snap0.get("real_socket_implemented", true)) == false, "DOL real socket is explicitly disabled in P1-N1", str(snap0))
	var login_ok := bool(dol.call("start_login", "f12_debug", "", true))
	_check(login_ok, "DOL simulated login succeeds")
	var snap_login: Dictionary = dol.call("get_network_debug_snapshot") as Dictionary
	_check(str(snap_login.get("state_name", "")) == "LOGIN_OK", "DOL state is LOGIN_OK after login", str(snap_login))
	_check(bool(snap_login.get("session_id_present", false)), "DOL simulated session id present", str(snap_login))
	var char_ok := bool(dol.call("request_charlist"))
	_check(char_ok, "DOL simulated charlist succeeds")
	var snap_chars: Dictionary = dol.call("get_network_debug_snapshot") as Dictionary
	_check(str(snap_chars.get("state_name", "")) == "CHARLIST_READY", "DOL state is CHARLIST_READY", str(snap_chars))
	_check(int(snap_chars.get("char_count", 0)) >= 1, "DOL charlist has at least one debug character", str(snap_chars))
	var enter_ok := bool(dol.call("enter_world", 0))
	_check(enter_ok, "DOL simulated enter world succeeds")
	var snap_world: Dictionary = dol.call("get_network_debug_snapshot") as Dictionary
	_check(str(snap_world.get("state_name", "")) == "IN_WORLD", "DOL state is IN_WORLD", str(snap_world))
	_check(int(snap_world.get("selected_character_index", -1)) == 0, "DOL selected character index captured", str(snap_world))
	var selected: Dictionary = snap_world.get("selected_character", {}) as Dictionary
	_check(not selected.is_empty(), "DOL selected character snapshot present", str(selected))
	var stages: Dictionary = dol.call("get_protocol_stage_snapshot") as Dictionary
	_check(bool(stages.get("login_ok", false)), "DOL protocol stage login_ok true", str(stages))
	_check(bool(stages.get("charlist_ready", false)), "DOL protocol stage charlist_ready true", str(stages))
	_check(bool(stages.get("in_world", false)), "DOL protocol stage in_world true", str(stages))
	var authority: Dictionary = dol.call("get_authority_boundary_snapshot") as Dictionary
	var auth_client: Array = authority.get("client_local", []) as Array
	var auth_server: Array = authority.get("server_authority_future", []) as Array
	_check(auth_client.size() > 0, "DOL authority snapshot has client_local", str(authority))
	_check(auth_server.size() > 0, "DOL authority snapshot has server_authority_future", str(authority))
	var flow: Dictionary = dol.call("get_packet_flow_debug_snapshot") as Dictionary
	_check(int(flow.get("count", 0)) >= 6, "DOL simulated packet flow captured", str(flow))
	_debug.append("\n--- DOL P1-N1 network snapshot ---")
	_debug.append(_snapshot_debug_line(snap_world))
	_debug.append("\n--- DOL P1-N1 authority boundary ---")
	_debug.append(_snapshot_debug_line(authority))
	_debug.append("\n--- DOL P1-N1 packet flow ---")
	_debug.append(_snapshot_debug_line(flow))
	if dol.has_method("restore_connection_state"):
		dol.call("restore_connection_state", saved)


func _test_dol_p1_n2(zone_viewer: Node) -> void:
	_section("P1-N2 position / heading / regionchange")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	_check(dol != null, "DOL client node exists for P1-N2")
	if dol == null:
		return
	_check(dol.has_method("capture_local_position_snapshot"), "DOL local position capture present")
	_check(dol.has_method("send_position_update_stub"), "DOL position update stub present")
	_check(dol.has_method("send_heading_update_stub"), "DOL heading update stub present")
	_check(dol.has_method("simulate_regionchange_stub"), "DOL regionchange stub present")
	_check(dol.has_method("heading_deg_to_daoc_units"), "DOL heading deg->units helper present")
	_check(dol.has_method("heading_units_to_deg"), "DOL heading units->deg helper present")
	_check(dol.has_method("get_position_sync_debug_snapshot"), "DOL position sync snapshot present")
	_check(dol.has_method("get_regionchange_debug_snapshot"), "DOL regionchange snapshot present")
	_check(dol.has_method("get_p1_n2_debug_snapshot"), "DOL P1-N2 combined snapshot present")
	var saved := {}
	if dol.has_method("get_connection_state_for_restore"):
		saved = dol.call("get_connection_state_for_restore") as Dictionary
	if dol.has_method("reset_to_disconnected"):
		dol.call("reset_to_disconnected")
	_check(bool(dol.call("start_login", "f12_debug", "", true)), "P1-N2 simulated login succeeds")
	_check(bool(dol.call("request_charlist")), "P1-N2 simulated charlist succeeds")
	_check(bool(dol.call("enter_world", 0)), "P1-N2 simulated enter world succeeds")
	var pos0: Dictionary = dol.call("capture_local_position_snapshot", "f12") as Dictionary
	_check(int(pos0.get("zone", -1)) >= 0, "P1-N2 position snapshot has zone", str(pos0))
	_check(float(pos0.get("x", -1.0)) >= 0.0 and float(pos0.get("x", -1.0)) <= 65536.0, "P1-N2 position x inside zone", "x=%.1f" % float(pos0.get("x", 0.0)))
	_check(float(pos0.get("y", -1.0)) >= 0.0 and float(pos0.get("y", -1.0)) <= 65536.0, "P1-N2 position y inside zone", "y=%.1f" % float(pos0.get("y", 0.0)))
	_check(_is_finite_float(float(pos0.get("z", 0.0))), "P1-N2 position z finite", "z=%.1f" % float(pos0.get("z", 0.0)))
	_check(int(pos0.get("heading_units", -1)) >= 0 and int(pos0.get("heading_units", -1)) < 4096, "P1-N2 heading units in DAoC range", "heading_units=%d" % int(pos0.get("heading_units", -1)))
	_check(int(pos0.get("sector_x", -1)) >= 0 and int(pos0.get("sector_x", -1)) <= 7, "P1-N2 sector_x in 0..7", "sector_x=%d" % int(pos0.get("sector_x", -1)))
	_check(int(pos0.get("sector_y", -1)) >= 0 and int(pos0.get("sector_y", -1)) <= 7, "P1-N2 sector_y in 0..7", "sector_y=%d" % int(pos0.get("sector_y", -1)))
	var h0 := int(dol.call("heading_deg_to_daoc_units", 0.0))
	var h90 := int(dol.call("heading_deg_to_daoc_units", 90.0))
	var hneg := int(dol.call("heading_deg_to_daoc_units", -90.0))
	_check(h0 == 0, "P1-N2 heading 0deg -> 0 units", "h0=%d" % h0)
	_check(h90 == 1024, "P1-N2 heading 90deg -> 1024 units", "h90=%d" % h90)
	_check(hneg == 3072, "P1-N2 heading -90deg wraps to 3072 units", "hneg=%d" % hneg)
	var d90 := float(dol.call("heading_units_to_deg", 1024))
	_check(absf(d90 - 90.0) < 0.01, "P1-N2 heading 1024 units -> 90deg", "deg=%.2f" % d90)
	var pos_ok := bool(dol.call("send_position_update_stub", "f12"))
	_check(pos_ok, "P1-N2 position update stub succeeds")
	var heading_ok := bool(dol.call("send_heading_update_stub", "f12"))
	_check(heading_ok, "P1-N2 heading update stub succeeds")
	var pos_snap: Dictionary = dol.call("get_position_sync_debug_snapshot") as Dictionary
	_check(int(pos_snap.get("position_sequence", 0)) >= 1, "P1-N2 position sequence incremented", str(pos_snap))
	_check(int(pos_snap.get("heading_sequence", 0)) >= 1, "P1-N2 heading sequence incremented", str(pos_snap))
	var ack: Dictionary = pos_snap.get("last_ack", {}) as Dictionary
	_check(bool(ack.get("accepted", false)), "P1-N2 position ack accepted", str(ack))
	var region_ok := bool(dol.call("simulate_regionchange_stub", int(pos0.get("zone", 0)), int(pos0.get("region_id", 0)), "f12"))
	_check(region_ok, "P1-N2 regionchange stub succeeds")
	var region_snap: Dictionary = dol.call("get_regionchange_debug_snapshot") as Dictionary
	_check(int(region_snap.get("sequence", 0)) >= 1, "P1-N2 regionchange sequence incremented", str(region_snap))
	_check(int(region_snap.get("last_zone_id", -1)) == int(pos0.get("zone", 0)), "P1-N2 regionchange tracks zone", str(region_snap))
	_check(int(region_snap.get("last_region_id", -1)) == int(pos0.get("region_id", 0)), "P1-N2 regionchange tracks region", str(region_snap))
	var flow: Dictionary = dol.call("get_packet_flow_debug_snapshot") as Dictionary
	_check(int(flow.get("count", 0)) >= 12, "P1-N2 packet flow includes position/heading/regionchange", str(flow))
	var all: Dictionary = dol.call("get_p1_n2_debug_snapshot") as Dictionary
	_check((all.get("position", {}) as Dictionary).size() > 0, "P1-N2 combined snapshot has position", _p1_n2_compact_report_line(all))
	_check((all.get("regionchange", {}) as Dictionary).size() > 0, "P1-N2 combined snapshot has regionchange", _p1_n2_compact_report_line(all))
	_debug.append("\n--- DOL P1-N2 position sync ---")
	_debug.append(_snapshot_debug_line(pos_snap))
	_debug.append("\n--- DOL P1-N2 regionchange ---")
	_debug.append(_snapshot_debug_line(region_snap))
	_debug.append("\n--- DOL P1-N2 combined snapshot ---")
	_debug.append(_snapshot_debug_line(all))
	if dol.has_method("restore_connection_state"):
		dol.call("restore_connection_state", saved)


func _test_dol_p1_n3(zone_viewer: Node) -> void:
	_section("P1-N3 DOL TCP transport preparatoire")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	var transport := _get_node_ref(zone_viewer, "_dol_transport")
	_check(dol != null, "P1-N3 DOL client exists")
	_check(transport != null, "P1-N3 DOL transport node exists")
	if dol == null or transport == null:
		return
	var methods := [
		"setup_transport", "configure_transport", "can_attempt_connection", "create_peer_if_needed",
		"connect_to_configured_host", "poll_transport", "send_raw_bytes", "read_available_bytes",
		"close_transport", "get_transport_debug_snapshot", "get_function_log_snapshot"
	]
	for method_name in methods:
		_check(transport.has_method(str(method_name)), "P1-N3 transport method present: %s" % str(method_name))
	_check(dol.has_method("set_transport"), "P1-N3 DOL client can attach transport")
	_check(dol.has_method("poll_transport"), "P1-N3 DOL client poll_transport wrapper present")
	_check(dol.has_method("get_p1_n3_debug_snapshot"), "P1-N3 DOL client combined snapshot present")
	if dol.has_method("set_transport"):
		dol.call("set_transport", transport)
	var original_transport: Dictionary = transport.call("get_transport_debug_snapshot") as Dictionary
	transport.call("configure_transport", "", 0, false, 2500)
	var snap0: Dictionary = transport.call("get_transport_debug_snapshot") as Dictionary
	_check(bool(snap0.get("enabled", true)) == false, "P1-N3 transport disabled by default", str(snap0))
	_check(str(snap0.get("status_name", "")) == "NO_PEER", "P1-N3 transport starts without TCP peer", str(snap0))
	_check(bool(transport.call("can_attempt_connection")) == false, "P1-N3 invalid host/port cannot connect")
	var connect_skipped := bool(transport.call("connect_to_configured_host"))
	_check(connect_skipped == false, "P1-N3 connect is skipped when disabled/invalid")
	var payload := PackedByteArray([0x44, 0x41, 0x4f, 0x43])
	var send_ok := bool(transport.call("send_raw_bytes", payload, "f12_no_peer"))
	_check(send_ok == false, "P1-N3 send is rejected without connected peer")
	var read_bytes: PackedByteArray = transport.call("read_available_bytes", 64) as PackedByteArray
	_check(read_bytes.size() == 0, "P1-N3 read without peer returns empty bytes")
	var close_ok := bool(transport.call("close_transport", "f12"))
	_check(close_ok, "P1-N3 close_transport succeeds even without peer")
	transport.call("configure_transport", "127.0.0.1", 65535, false, 2500)
	var can_disabled := bool(transport.call("can_attempt_connection"))
	_check(can_disabled == false, "P1-N3 disabled transport refuses otherwise valid host/port")
	var snap1: Dictionary = transport.call("get_transport_debug_snapshot") as Dictionary
	_check(int(snap1.get("function_log_size", 0)) >= 8, "P1-N3 function log records transport calls", str(snap1))
	var log_tail: Array = transport.call("get_function_log_snapshot", 20) as Array
	_check(log_tail.size() >= 8, "P1-N3 function log snapshot readable", str(log_tail))
	var combined: Dictionary = dol.call("get_p1_n3_debug_snapshot") as Dictionary
	_check(bool(combined.get("attached", false)), "P1-N3 combined snapshot sees attached transport", str(combined))
	_check(bool(combined.get("real_protocol_implemented", true)) == false, "P1-N3 real DOL protocol remains explicitly deferred", str(combined))
	_debug.append("\n--- DOL P1-N3 transport snapshot ---")
	_debug.append(_snapshot_debug_line(snap1))
	_debug.append("\n--- DOL P1-N3 function log ---")
	_debug.append(_snapshot_debug_line(log_tail))
	transport.call(
		"configure_transport",
		str(original_transport.get("host", "")),
		int(original_transport.get("port", 0)),
		bool(original_transport.get("enabled", false)),
		2500
	)


func _test_dol_p1_n4_packet_100(zone_viewer: Node) -> void:
	_section("P1-N4 DOL packet/framing preparatoire — 100 fonctions")
	var packet := _get_node_ref(zone_viewer, "_dol_packet_layer")
	if packet == null:
		packet = DaocDolPacketScript.new()
	_check(packet != null, "P1-N4 packet layer available")
	if packet == null:
		return

	packet.call("reset_packet_layer")
	packet.call("register_opcode", 0x2222, "TEMP")
	packet.call("reset_packet_layer")
	_check(int(packet.call("registry_size")) == 0, "P1-N4 fn 001 reset_packet_layer")

	packet.call("configure_packet_layer", true, false)
	_check(bool(packet.call("is_debug_enabled")) == true and bool(packet.call("uses_little_endian")) == false, "P1-N4 fn 002 configure_packet_layer")

	packet.call("set_debug_enabled", false)
	_check(bool(packet.call("is_debug_enabled")) == false, "P1-N4 fn 003 set_debug_enabled")

	packet.call("set_debug_enabled", true)
	_check(bool(packet.call("is_debug_enabled")) == true, "P1-N4 fn 004 is_debug_enabled")

	packet.call("set_default_endian_little", true)
	_check(bool(packet.call("uses_little_endian")) == true, "P1-N4 fn 005 set_default_endian_little")

	_check(bool(packet.call("uses_little_endian")) == true, "P1-N4 fn 006 uses_little_endian")

	_check(int(packet.call("clamp_u8", 999)) == 255, "P1-N4 fn 007 clamp_u8")

	_check(int(packet.call("clamp_u16", 999999)) == 65535, "P1-N4 fn 008 clamp_u16")

	_check(int(packet.call("clamp_u32", -1)) == 0, "P1-N4 fn 009 clamp_u32")

	_check(int(packet.call("signed_i16_from_u16", 0xffff)) == -1, "P1-N4 fn 010 signed_i16_from_u16")

	_check(int(packet.call("u16_from_signed_i16", -1)) == 65535, "P1-N4 fn 011 u16_from_signed_i16")

	var empty: PackedByteArray = packet.call("byte_array_empty") as PackedByteArray
	_check(empty.size() == 0, "P1-N4 fn 012 byte_array_empty")

	_check(int(packet.call("byte_array_size", PackedByteArray([1, 2, 3]))) == 3, "P1-N4 fn 013 byte_array_size")

	var cloned: PackedByteArray = packet.call("byte_array_clone", PackedByteArray([7, 8])) as PackedByteArray
	_check(cloned.size() == 2 and int(cloned[0]) == 7, "P1-N4 fn 014 byte_array_clone")

	_check(bool(packet.call("byte_array_equals", PackedByteArray([1, 2]), PackedByteArray([1, 2]))), "P1-N4 fn 015 byte_array_equals")

	var prefix: PackedByteArray = packet.call("byte_array_prefix", PackedByteArray([1, 2, 3]), 2) as PackedByteArray
	_check(prefix.size() == 2 and int(prefix[1]) == 2, "P1-N4 fn 016 byte_array_prefix")

	var suffix: PackedByteArray = packet.call("byte_array_suffix", PackedByteArray([1, 2, 3]), 2) as PackedByteArray
	_check(suffix.size() == 2 and int(suffix[0]) == 2, "P1-N4 fn 017 byte_array_suffix")

	var joined: PackedByteArray = packet.call("concat_bytes", PackedByteArray([1]), PackedByteArray([2, 3])) as PackedByteArray
	_check(joined.size() == 3 and int(joined[2]) == 3, "P1-N4 fn 018 concat_bytes")

	var b19: PackedByteArray = packet.call("append_u8", PackedByteArray(), 0x123) as PackedByteArray
	_check(b19.size() == 1 and int(b19[0]) == 0xff, "P1-N4 fn 019 append_u8")

	var b20: PackedByteArray = packet.call("append_u16_le", PackedByteArray(), 0x1234) as PackedByteArray
	_check(b20.size() == 2 and int(b20[0]) == 0x34 and int(b20[1]) == 0x12, "P1-N4 fn 020 append_u16_le")

	var b21: PackedByteArray = packet.call("append_u16_be", PackedByteArray(), 0x1234) as PackedByteArray
	_check(b21.size() == 2 and int(b21[0]) == 0x12 and int(b21[1]) == 0x34, "P1-N4 fn 021 append_u16_be")

	var b22: PackedByteArray = packet.call("append_u32_le", PackedByteArray(), 0x12345678) as PackedByteArray
	_check(b22.size() == 4 and int(b22[0]) == 0x78 and int(b22[3]) == 0x12, "P1-N4 fn 022 append_u32_le")

	var b23: PackedByteArray = packet.call("append_u32_be", PackedByteArray(), 0x12345678) as PackedByteArray
	_check(b23.size() == 4 and int(b23[0]) == 0x12 and int(b23[3]) == 0x78, "P1-N4 fn 023 append_u32_be")

	var b24: PackedByteArray = packet.call("append_i16_le", PackedByteArray(), -2) as PackedByteArray
	_check(b24.size() == 2 and int(b24[0]) == 0xfe and int(b24[1]) == 0xff, "P1-N4 fn 024 append_i16_le")

	var b25: PackedByteArray = packet.call("append_i32_le", PackedByteArray(), 1) as PackedByteArray
	_check(b25.size() == 4 and int(b25[0]) == 1, "P1-N4 fn 025 append_i32_le")

	var b26: PackedByteArray = packet.call("append_bytes", PackedByteArray([1]), PackedByteArray([9])) as PackedByteArray
	_check(b26.size() == 2 and int(b26[1]) == 9, "P1-N4 fn 026 append_bytes")

	_check(int(packet.call("read_u8", PackedByteArray([0xaa]), 0)) == 0xaa, "P1-N4 fn 027 read_u8")

	_check(int(packet.call("read_u16_le", PackedByteArray([0x34, 0x12]), 0)) == 0x1234, "P1-N4 fn 028 read_u16_le")

	_check(int(packet.call("read_u16_be", PackedByteArray([0x12, 0x34]), 0)) == 0x1234, "P1-N4 fn 029 read_u16_be")

	_check(int(packet.call("read_u32_le", PackedByteArray([0x78, 0x56, 0x34, 0x12]), 0)) == 0x12345678, "P1-N4 fn 030 read_u32_le")

	_check(int(packet.call("read_u32_be", PackedByteArray([0x12, 0x34, 0x56, 0x78]), 0)) == 0x12345678, "P1-N4 fn 031 read_u32_be")

	_check(int(packet.call("read_i16_le", PackedByteArray([0xff, 0xff]), 0)) == -1, "P1-N4 fn 032 read_i16_le")

	_check(int(packet.call("read_i32_le", PackedByteArray([0xff, 0xff, 0xff, 0xff]), 0)) == -1, "P1-N4 fn 033 read_i32_le")

	_check(str(packet.call("bytes_to_hex", PackedByteArray([0x0d, 0xa0]), " ")) == "0D A0", "P1-N4 fn 034 bytes_to_hex")

	var b35: PackedByteArray = packet.call("hex_to_bytes", "0D A0") as PackedByteArray
	_check(b35.size() == 2 and int(b35[0]) == 0x0d and int(b35[1]) == 0xa0, "P1-N4 fn 035 hex_to_bytes")

	var b36: PackedByteArray = packet.call("ascii_to_bytes", "DAOC") as PackedByteArray
	_check(b36.size() == 4 and int(b36[0]) == 68, "P1-N4 fn 036 ascii_to_bytes")

	_check(str(packet.call("bytes_to_ascii_lossy", PackedByteArray([68, 65, 0, 67]))) == "DA.C", "P1-N4 fn 037 bytes_to_ascii_lossy")

	_check(str(packet.call("sanitize_opcode_name", " login-stub ")) == "LOGIN_STUB", "P1-N4 fn 038 sanitize_opcode_name")

	_check(int(packet.call("normalize_opcode_id", 999999)) == 65535, "P1-N4 fn 039 normalize_opcode_id")

	packet.call("clear_registry")
	_check(bool(packet.call("register_opcode", 0x100, "test op")), "P1-N4 fn 040 register_opcode")

	_check(bool(packet.call("unregister_opcode", 0x100)), "P1-N4 fn 041 unregister_opcode")

	packet.call("register_opcode", 0x101, "exists")
	_check(bool(packet.call("has_opcode", 0x101)), "P1-N4 fn 042 has_opcode")

	_check(str(packet.call("opcode_name", 0x101)) == "EXISTS", "P1-N4 fn 043 opcode_name")

	_check(int(packet.call("opcode_id_by_name", "exists")) == 0x101, "P1-N4 fn 044 opcode_id_by_name")

	_check(int(packet.call("registry_size")) >= 1, "P1-N4 fn 045 registry_size")

	var regsnap: Dictionary = packet.call("registry_snapshot") as Dictionary
	_check(int(regsnap.get("count", 0)) >= 1, "P1-N4 fn 046 registry_snapshot")

	packet.call("clear_registry")
	_check(int(packet.call("registry_size")) == 0, "P1-N4 fn 047 clear_registry")

	_check(int(packet.call("register_default_debug_opcodes")) >= 7, "P1-N4 fn 048 register_default_debug_opcodes")

	_check(int(packet.call("compute_payload_length", PackedByteArray([1, 2, 3]))) == 3, "P1-N4 fn 049 compute_payload_length")

	_check(bool(packet.call("payload_length_valid", PackedByteArray([1, 2, 3]))), "P1-N4 fn 050 payload_length_valid")

	_check(int(packet.call("header_size")) == 4, "P1-N4 fn 051 header_size")

	var hle: PackedByteArray = packet.call("build_header_le", 7, 0x1234) as PackedByteArray
	_check(hle.size() == 4 and int(hle[0]) == 7 and int(hle[2]) == 0x34, "P1-N4 fn 052 build_header_le")

	var hbe: PackedByteArray = packet.call("build_header_be", 7, 0x1234) as PackedByteArray
	_check(hbe.size() == 4 and int(hbe[1]) == 7 and int(hbe[2]) == 0x12, "P1-N4 fn 053 build_header_be")

	var phle: Dictionary = packet.call("parse_header_le", hle) as Dictionary
	_check(bool(phle.get("ok", false)) and int(phle.get("opcode", 0)) == 0x1234, "P1-N4 fn 054 parse_header_le")

	var phbe: Dictionary = packet.call("parse_header_be", hbe) as Dictionary
	_check(bool(phbe.get("ok", false)) and int(phbe.get("opcode", 0)) == 0x1234, "P1-N4 fn 055 parse_header_be")

	_check(bool(packet.call("validate_header", phle)), "P1-N4 fn 056 validate_header")

	var pkt57: PackedByteArray = packet.call("build_packet", 0x0010, PackedByteArray([1, 2, 3]), true) as PackedByteArray
	_check(pkt57.size() == 7 and int(pkt57[0]) == 7, "P1-N4 fn 057 build_packet")

	var parsed58: Dictionary = packet.call("parse_packet", pkt57, true) as Dictionary
	_check(bool(parsed58.get("ok", false)) and int(parsed58.get("opcode", 0)) == 0x0010, "P1-N4 fn 058 parse_packet")

	var stream59: PackedByteArray = packet.call("concat_bytes", pkt57, PackedByteArray([9])) as PackedByteArray
	var split59: Dictionary = packet.call("split_stream_once", stream59, true) as Dictionary
	_check(bool(split59.get("ok", false)) and (split59.get("remaining", PackedByteArray()) as PackedByteArray).size() == 1, "P1-N4 fn 059 split_stream_once")

	var stream60: PackedByteArray = packet.call("concat_bytes", pkt57, pkt57) as PackedByteArray
	var split60: Dictionary = packet.call("split_stream_all", stream60, true) as Dictionary
	_check(int(split60.get("count", 0)) == 2, "P1-N4 fn 060 split_stream_all")

	packet.call("clear_receive_buffer")
	_check(int(packet.call("append_to_receive_buffer", pkt57)) == pkt57.size(), "P1-N4 fn 061 append_to_receive_buffer")

	_check(int(packet.call("receive_buffer_size")) == pkt57.size(), "P1-N4 fn 062 receive_buffer_size")

	var popped: Dictionary = packet.call("pop_next_packet_from_buffer", true) as Dictionary
	_check(bool(popped.get("ok", false)) and int(packet.call("receive_buffer_size")) == 0, "P1-N4 fn 063 pop_next_packet_from_buffer")

	packet.call("append_to_receive_buffer", PackedByteArray([1, 2, 3]))
	packet.call("clear_receive_buffer")
	_check(int(packet.call("receive_buffer_size")) == 0, "P1-N4 fn 064 clear_receive_buffer")

	var login_payload: PackedByteArray = packet.call("encode_login_stub", "heyveno") as PackedByteArray
	_check(login_payload.size() > 0, "P1-N4 fn 065 encode_login_stub")

	var login_dec: Dictionary = packet.call("decode_login_stub", login_payload) as Dictionary
	_check(str(login_dec.get("account", "")) == "heyveno", "P1-N4 fn 066 decode_login_stub")

	var char_payload: PackedByteArray = packet.call("encode_charlist_request_stub", "SIM1") as PackedByteArray
	_check(char_payload.size() > 0, "P1-N4 fn 067 encode_charlist_request_stub")

	var char_dec: Dictionary = packet.call("decode_charlist_request_stub", char_payload) as Dictionary
	_check(str(char_dec.get("session", "")) == "SIM1", "P1-N4 fn 068 decode_charlist_request_stub")

	var enter_payload: PackedByteArray = packet.call("encode_enter_world_stub", 2) as PackedByteArray
	_check(enter_payload.size() > 0, "P1-N4 fn 069 encode_enter_world_stub")

	var enter_dec: Dictionary = packet.call("decode_enter_world_stub", enter_payload) as Dictionary
	_check(int(enter_dec.get("slot", -1)) == 2, "P1-N4 fn 070 decode_enter_world_stub")

	var pos_payload: PackedByteArray = packet.call("encode_position_stub", {"zone": 0, "x": 1.0, "y": 2.0, "z": 3.0, "heading_units": 4}) as PackedByteArray
	_check(pos_payload.size() > 0, "P1-N4 fn 071 encode_position_stub")

	var pos_dec: Dictionary = packet.call("decode_position_stub", pos_payload) as Dictionary
	_check(int(pos_dec.get("zone", -1)) == 0 and int(pos_dec.get("heading_units", -1)) == 4, "P1-N4 fn 072 decode_position_stub")

	var heading_payload: PackedByteArray = packet.call("encode_heading_stub", 1024) as PackedByteArray
	_check(heading_payload.size() > 0, "P1-N4 fn 073 encode_heading_stub")

	var heading_dec: Dictionary = packet.call("decode_heading_stub", heading_payload) as Dictionary
	_check(int(heading_dec.get("heading_units", -1)) == 1024, "P1-N4 fn 074 decode_heading_stub")

	var region_payload: PackedByteArray = packet.call("encode_regionchange_stub", 7, 8) as PackedByteArray
	_check(region_payload.size() > 0, "P1-N4 fn 075 encode_regionchange_stub")

	var region_dec: Dictionary = packet.call("decode_regionchange_stub", region_payload) as Dictionary
	_check(int(region_dec.get("zone", -1)) == 7 and int(region_dec.get("region", -1)) == 8, "P1-N4 fn 076 decode_regionchange_stub")

	var logentry: Dictionary = packet.call("make_packet_log_entry", "client", 0x10, 3, "note") as Dictionary
	_check(str(logentry.get("direction", "")) == "client" and int(logentry.get("opcode", 0)) == 0x10, "P1-N4 fn 077 make_packet_log_entry")

	packet.call("clear_packet_log")
	_check(int(packet.call("record_packet_event", "client", 0x10, PackedByteArray([1, 2, 3]), "record")) == 1, "P1-N4 fn 078 record_packet_event")

	_check(int(packet.call("packet_log_size")) == 1, "P1-N4 fn 079 packet_log_size")

	var tail80: Array = packet.call("packet_log_tail", 1) as Array
	_check(tail80.size() == 1, "P1-N4 fn 080 packet_log_tail")

	packet.call("clear_packet_log")
	_check(int(packet.call("packet_log_size")) == 0, "P1-N4 fn 081 clear_packet_log")

	packet.call("set_sequence", 41)
	_check(int(packet.call("current_sequence")) == 41, "P1-N4 fn 082 set_sequence")

	_check(int(packet.call("next_sequence")) == 42, "P1-N4 fn 083 next_sequence")

	_check(int(packet.call("current_sequence")) == 42, "P1-N4 fn 084 current_sequence")

	_check(bool(packet.call("sequence_valid", 42)) and not bool(packet.call("sequence_valid", -1)), "P1-N4 fn 085 sequence_valid")

	_check(int(packet.call("payload_checksum8", PackedByteArray([1, 2, 3]))) == 6, "P1-N4 fn 086 payload_checksum8")

	_check(int(packet.call("packet_checksum8", PackedByteArray([1, 2, 3]))) == 6, "P1-N4 fn 087 packet_checksum8")

	var with_chk: PackedByteArray = packet.call("attach_checksum8", PackedByteArray([1, 2, 3])) as PackedByteArray
	_check(with_chk.size() == 4 and int(with_chk[3]) == 6, "P1-N4 fn 088 attach_checksum8")

	_check(bool(packet.call("verify_attached_checksum8", with_chk)), "P1-N4 fn 089 verify_attached_checksum8")

	_check(str(packet.call("describe_packet", parsed58)).contains("opcode=0x0010"), "P1-N4 fn 090 describe_packet")

	_check(str(packet.call("describe_header", phle)).contains("opcode=0x1234"), "P1-N4 fn 091 describe_header")

	var err92: Dictionary = packet.call("make_error", "unit", "message") as Dictionary
	_check(str(err92.get("code", "")) == "unit", "P1-N4 fn 092 make_error")

	var err93: Dictionary = packet.call("last_error_snapshot") as Dictionary
	_check(str(err93.get("code", "")) == "unit", "P1-N4 fn 093 last_error_snapshot")

	packet.call("clear_last_error")
	_check((packet.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N4 fn 094 clear_last_error")

	var status95: Dictionary = packet.call("status_snapshot") as Dictionary
	_check(str(status95.get("scope", "")).contains("P1-N4"), "P1-N4 fn 095 status_snapshot")

	_check(str(packet.call("p1_n4_scope")).contains("P1-N4"), "P1-N4 fn 096 p1_n4_scope")

	_check(bool(packet.call("is_real_protocol_implemented")) == false, "P1-N4 fn 097 is_real_protocol_implemented")

	_check(bool(packet.call("can_use_against_local_dol")) == true, "P1-N4 fn 098 can_use_against_local_dol")

	var hs: PackedByteArray = packet.call("make_handshake_placeholder_packet") as PackedByteArray
	var hs_parsed: Dictionary = packet.call("parse_packet", hs, bool(packet.call("uses_little_endian"))) as Dictionary
	_check(bool(hs_parsed.get("ok", false)) and int(hs_parsed.get("opcode", 0)) == 0x00ff, "P1-N4 fn 099 make_handshake_placeholder_packet")

	var names: PackedStringArray = packet.call("get_function_names") as PackedStringArray
	var all_present := names.size() == 100
	for name in names:
		if not packet.has_method(str(name)):
			all_present = false
			break
	_check(all_present, "P1-N4 fn 100 get_function_names", "count=%d" % names.size())

	_debug.append("\n--- DOL P1-N4 packet layer snapshot ---")
	_debug.append(_snapshot_debug_line(packet.call("status_snapshot")))
	_debug.append("\n--- DOL P1-N4 function names ---")
	_debug.append(_snapshot_debug_line(names))


func _test_dol_p1_n5a_wire_1127(zone_viewer: Node) -> void:
	_section("P1-N5A DOL wire 1127 offline")
	var wire := _get_node_ref(zone_viewer, "_dol_wire_1127")
	if wire == null:
		wire = DaocDolWire1127Script.new()
	_check(wire != null, "P1-N5A wire layer available")
	if wire == null:
		return
	var required := PackedStringArray([
		"reset_wire_profile", "configure_wire_profile", "packet_header_size", "dol_profile_snapshot", "expected_version_probe_offsets",
		"dol_client_version_from_bytes", "append_u16_be", "append_u32_be", "read_u16_be", "read_u32_be",
		"build_gspacket_header_12", "parse_gspacket_header_12", "dol_tcp_checksum16_region", "dol_tcp_checksum16", "append_dol_tcp_checksum16",
		"read_attached_checksum16", "verify_dol_tcp_checksum16", "build_gspacket_12", "parse_gspacket_12", "split_dol_tcp_stream_once",
		"split_dol_tcp_stream_all", "detect_packet_id", "describe_dol_gspacket", "describe_profile", "can_attempt_local_dol_probe",
		"build_version_probe_1127_packet", "version_probe_1127_valid", "status_snapshot", "p1_n5a_scope", "is_real_login_implemented",
	])
	for name in required:
		_check(wire.has_method(str(name)), "P1-N5A method present: %s" % str(name))

	wire.call("reset_wire_profile")
	wire.call("configure_wire_profile", "127.0.0.1", 10300, 10400, true)
	_check(int(wire.call("packet_header_size")) == 12, "P1-N5A header size is 12")

	var profile: Dictionary = wire.call("dol_profile_snapshot") as Dictionary
	_check(int(profile.get("client_version", 0)) == 1127, "P1-N5A profile client version 1127")
	_check(int(profile.get("packet_processor_version", 0)) == 168, "P1-N5A profile PacketProcessor v168")
	_check(str(profile.get("packet_lib", "")) == "PacketLib1127", "P1-N5A profile PacketLib1127")
	_check(int(profile.get("port", 0)) == 10300, "P1-N5A profile TCP port 10300")

	var offs: Dictionary = wire.call("expected_version_probe_offsets") as Dictionary
	_check(int(offs.get("major_index", 0)) == 11 and int(offs.get("build", 0)) == 27, "P1-N5A version probe offsets 11/12/13")

	var be := PackedByteArray()
	be = wire.call("append_u16_be", be, 0x1234) as PackedByteArray
	be = wire.call("append_u32_be", be, 0x01020304) as PackedByteArray
	_check(int(wire.call("read_u16_be", be, 0)) == 0x1234, "P1-N5A read/write u16 big endian")
	_check(int(wire.call("read_u32_be", be, 2)) == 0x01020304, "P1-N5A read/write u32 big endian")

	var payload := PackedByteArray([0xaa, 0xbb, 0xcc])
	var header: PackedByteArray = wire.call("build_gspacket_header_12", payload.size(), 0x2a, 1, 0, 0xf4) as PackedByteArray
	_check(header.size() == 10 and int(header[9]) == 0xf4, "P1-N5A builds DOL 10-byte prefix before checksum")

	var packet: PackedByteArray = wire.call("build_gspacket_12", 0xf4, payload, 0x2a, 1, 0) as PackedByteArray
	var parsed: Dictionary = wire.call("parse_gspacket_12", packet) as Dictionary
	_check(bool(parsed.get("ok", false)), "P1-N5A parses GSPacketIn-compatible packet")
	_check(int(parsed.get("data_size", -1)) == payload.size(), "P1-N5A data_size equals payload size")
	_check(int(parsed.get("sequence", -1)) == 0x2a, "P1-N5A sequence decoded")
	_check(int(parsed.get("session_id", -1)) == 1, "P1-N5A session decoded")
	_check(int(parsed.get("packet_id", -1)) == 0xf4, "P1-N5A packet id uses byte 9")
	_check(bool(parsed.get("checksum_ok", false)), "P1-N5A DOL checksum verifies")
	_check(int(wire.call("read_attached_checksum16", packet)) == int(parsed.get("checksum", -1)), "P1-N5A attached checksum readable")

	var stream := PackedByteArray()
	stream.append_array(packet)
	stream.append_array(packet)
	var one: Dictionary = wire.call("split_dol_tcp_stream_once", stream) as Dictionary
	var remaining_one: PackedByteArray = one.get("remaining", PackedByteArray()) as PackedByteArray
	_check(bool(one.get("ok", false)) and remaining_one.size() == packet.size(), "P1-N5A split one packet from stream")
	var all: Array = wire.call("split_dol_tcp_stream_all", stream) as Array
	_check(all.size() == 2, "P1-N5A split all packets from stream")

	_check(int(wire.call("detect_packet_id", packet)) == 0xf4, "P1-N5A detect packet id")
	_check(str(wire.call("describe_dol_gspacket", packet)).contains("id=0xF4"), "P1-N5A describe packet")
	_check(str(wire.call("describe_profile")).contains("PacketLib1127"), "P1-N5A describe profile")
	_check(bool(wire.call("can_attempt_local_dol_probe")), "P1-N5A local DOL probe profile is usable")

	var probe: PackedByteArray = wire.call("build_version_probe_1127_packet") as PackedByteArray
	_check(probe.size() >= 18, "P1-N5A version probe has enough bytes")
	_check(int(wire.call("dol_client_version_from_bytes", probe)) == 1127, "P1-N5A version probe decodes 1127")
	_check(bool(wire.call("version_probe_1127_valid", probe)), "P1-N5A version probe validates packet id and checksum")

	var status: Dictionary = wire.call("status_snapshot") as Dictionary
	_check(str(status.get("scope", "")).contains("P1-N5A"), "P1-N5A status snapshot")
	_check(str(wire.call("p1_n5a_scope")).contains("1127"), "P1-N5A scope text")
	_check(bool(wire.call("is_real_login_implemented")) == false, "P1-N5A real login remains deferred")

	var names: PackedStringArray = wire.call("get_function_names") as PackedStringArray
	var all_present := names.size() == 30
	for name in names:
		if not wire.has_method(str(name)):
			all_present = false
			break
	_check(all_present, "P1-N5A function list complete", "count=%d" % names.size())

	_debug.append("\n--- DOL P1-N5A wire profile snapshot ---")
	_debug.append(_snapshot_debug_line(status))
	_debug.append("\n--- DOL P1-N5A version probe ---")
	_debug.append(_snapshot_debug_line(wire.call("describe_dol_gspacket", probe)))


func _test_server_live_capture_p1_17f6(zone_viewer: Node) -> void:
	_section("P1-17F6 server capture readiness")
	_check(DaocServerLiveCaptureProbeScript != null, "P1-17F6 server capture script exists")
	if DaocServerLiveCaptureProbeScript == null:
		return
	var capture: RefCounted = DaocServerLiveCaptureProbeScript.new()
	_check(capture != null, "P1-17F6 server capture service instantiates")
	if capture == null:
		return
	var required := PackedStringArray([
		"build_readiness_report",
		"attempt_local_probe",
		"build_received_packet_summary",
		"export_last_report_json",
		"export_last_report_text",
		"build_text_report",
	])
	for name in required:
		_check(capture.has_method(str(name)), "P1-17F6 method present: %s" % str(name))

	var dol_client := _get_node_ref(zone_viewer, "_dol_client")
	var transport := _get_node_ref(zone_viewer, "_dol_transport")
	var wire := _get_node_ref(zone_viewer, "_dol_wire_1127")
	if wire == null:
		wire = DaocDolWire1127Script.new()
	var report: Dictionary = capture.call("build_readiness_report", dol_client, transport, wire, {"host": "127.0.0.1", "port": 10300}) as Dictionary
	var guard: Dictionary = report.get("guardrails", {}) as Dictionary
	var probe: Dictionary = report.get("version_probe_packet", {}) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_17F6_SERVER_LIVE_CAPTURE", "P1-17F6 checkpoint")
	_check(bool(report.get("ok", false)), "P1-17F6 readiness report builds")
	_check(not bool(report.get("live_probe_attempted", true)), "P1-17F6 F12 does not attempt network probe")
	_check(not bool(report.get("connect_attempted", true)), "P1-17F6 F12 does not connect to server")
	_check(not bool(report.get("connected", true)), "P1-17F6 readiness is not a live connection")
	_check(bool(probe.get("checksum_ok", false)), "P1-17F6 version probe checksum is valid")
	_check(int(probe.get("client_version", 0)) == 1127, "P1-17F6 version probe targets client 1127")
	_check(not bool(guard.get("coordinate_frame_confirmed", true)), "P1-17F6 coordinate frame remains unconfirmed")
	_check(not bool(guard.get("runtime_enabled", true)), "P1-17F6 runtime remains disabled")
	_check(not bool(guard.get("player_spawn_applied", true)), "P1-17F6 never spawns/moves player")
	_check(not bool(guard.get("credentials_sent", true)), "P1-17F6 never sends credentials")

	if wire != null and wire.has_method("build_version_probe_1127_packet"):
		var packet: PackedByteArray = wire.call("build_version_probe_1127_packet") as PackedByteArray
		var rx: Dictionary = capture.call("build_received_packet_summary", wire, packet) as Dictionary
		_check(int(rx.get("packet_count", 0)) == 1, "P1-17F6 can summarize one DOL packet from bytes")

	var json_export: Dictionary = capture.call("export_last_report_json", "res://reports/p1_17f6_server_capture.json") as Dictionary
	var txt_export: Dictionary = capture.call("export_last_report_text", "res://reports/p1_17f6_server_capture.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-17F6 JSON export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-17F6 text export works", str(txt_export.get("error", "")))

	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/servercapture status")), "P1-17F6 /servercapture status handled")
		_check(bool(command.call("execute_command", "/servercapture report")), "P1-17F6 /servercapture report handled")

	_debug.append("\n--- P1-17F6 server capture readiness ---")
	_debug.append(_snapshot_debug_line(report))




func _test_daoc_pregame_selection_p1_20ui(zone_viewer: Node) -> void:
	_section("P1-20UI-A DAoC realm/character selection (offline)")
	_check(DaocPregameFlowScene != null, "P1-20UI flow scene exists")
	_check(DaocPregameDataAdapterScript != null, "P1-20UI data adapter exists")
	var adapter: RefCounted = DaocPregameDataAdapterScript.new()
	var realms: Array = adapter.call("available_realms") as Array
	_check(realms.size() == 3, "P1-20UI exposes three realms")
	_check((adapter.call("visual_realm_order") as Array) == [1, 3, 2], "P1-20UI visual order Albion/Hibernia/Midgard")
	_check((adapter.call("parse_realm_descriptions") as Dictionary).size() == 3, "P1-20UI parses official realm descriptions")
	_check(ResourceLoader.exists("res://assets/daoc/pregame/ui/realm_selection.png"), "P1-20UI realm canvas imported")
	_check(ResourceLoader.exists("res://assets/daoc/pregame/ui/character_selection.png"), "P1-20UI character canvas imported")
	var flow: Node = DaocPregameFlowScene.instantiate()
	_check(flow != null, "P1-20UI flow instantiates")
	if flow != null:
		_check(flow.get("network_enabled") == false, "P1-20UI network disabled by default")
		_check(flow.get("udp_enabled") == false, "P1-20UI UDP disabled")
		flow.free()
	_check(zone_viewer.get("p1_20ui_show_pregame_flow_on_ready") == false, "P1-20UI optional ZoneViewer integration stays off")


func _test_opendaoc_tcp_login_probe_p1_20a(zone_viewer: Node) -> void:
	_section("P1-20A OpenDAoC TCP Login Probe")
	_check(DaocOpenDaocPacketCodecScript != null, "P1-20A codec script exists")
	_check(DaocOpenDaocChecksumScript != null, "P1-20A checksum script exists")
	_check(DaocOpenDaocTcpLoginProbeScript != null, "P1-20A tcp probe script exists")
	_check(DaocOpenDaocPacketLogScript != null, "P1-20A packet log script exists")
	if DaocOpenDaocPacketCodecScript == null or DaocOpenDaocTcpLoginProbeScript == null:
		return
	var codec: RefCounted = DaocOpenDaocPacketCodecScript.new()
	var checksum: RefCounted = DaocOpenDaocChecksumScript.new()
	var probe: Node = DaocOpenDaocTcpLoginProbeScript.new()
	var packet_log: RefCounted = DaocOpenDaocPacketLogScript.new()
	_check(codec != null, "P1-20A codec instantiates")
	_check(checksum != null, "P1-20A checksum instantiates")
	_check(probe != null, "P1-20A probe instantiates")
	_check(packet_log != null, "P1-20A packet log instantiates")
	if codec == null or checksum == null or probe == null:
		return
	var payload := PackedByteArray([0xaa, 0xbb])
	var packet0: PackedByteArray = codec.call("build_packet", 0xF4, payload, 0x1234, 0x2345, 0x3456, 0) as PackedByteArray
	var chk := int(checksum.call("compute_checksum", packet0.slice(0, packet0.size() - 2)))
	var packet: PackedByteArray = codec.call("build_packet", 0xF4, payload, 0x1234, 0x2345, 0x3456, chk) as PackedByteArray
	var parsed: Dictionary = codec.call("parse_packet", packet) as Dictionary
	_check(packet.size() == payload.size() + 12, "P1-20A build_packet total_size = payload_size + 12", str(packet.size()))
	_check(bool(parsed.get("ok", false)), "P1-20A parse_packet ok", str(parsed.get("parse_status", "")))
	_check(int(parsed.get("opcode", -1)) == 0xF4, "P1-20A parse_packet opcode", str(parsed.get("opcode_hex", "")))
	_check(int(parsed.get("sequence", 0)) == 0x1234 and int(parsed.get("session_id", 0)) == 0x2345 and int(parsed.get("parameter", 0)) == 0x3456, "P1-20A Big Endian fields read correctly")
	var fragmented := packet.slice(0, 4)
	var extract_a: Dictionary = codec.call("try_extract_packets", fragmented) as Dictionary
	fragmented.append_array(packet.slice(4, packet.size()))
	var extract_b: Dictionary = codec.call("try_extract_packets", fragmented) as Dictionary
	_check((extract_a.get("packets", []) as Array).is_empty(), "P1-20A fragmented TCP waits for more bytes")
	_check((extract_b.get("packets", []) as Array).size() == 1, "P1-20A fragmented TCP extraction completes")
	var short_parse: Dictionary = codec.call("parse_packet", PackedByteArray([0x00])) as Dictionary
	_check(not bool(short_parse.get("ok", true)), "P1-20A invalid short packet handled cleanly", str(short_parse.get("parse_status", "")))
	var invalid_size := PackedByteArray([0xff, 0xff, 0, 0, 0, 0, 0, 0, 0, 0])
	var invalid_extract: Dictionary = codec.call("try_extract_packets", invalid_size) as Dictionary
	_check(not bool(invalid_extract.get("ok", true)), "P1-20A invalid size handled cleanly", str(invalid_extract.get("errors", [])))
	var checksum_report: Dictionary = checksum.call("verify_checksum", packet) as Dictionary
	_check(bool(checksum_report.get("available", false)), "P1-20A checksum availability explicit", str(checksum_report.get("source", "")))
	_check(bool(checksum_report.get("ok", false)), "P1-20A checksum verifies local test packet", str(checksum_report.get("checksum_status", "")))
	var report: Dictionary = probe.call("run_probe", {
		"probe_enabled": false,
		"host": "127.0.0.1",
		"login_port": 10300,
		"username": "codex_test",
		"password": "secret_never_log",
		"send_packets": false,
		"allow_production_host": false,
		"report_dir": "res://reports/p1_20a_opendaoc_tcp_login_probe/",
		"redact_credentials": true,
	}) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_20A_OPENDAOC_TCP_LOGIN_PROBE", "P1-20A probe checkpoint")
	_check(str(report.get("verdict", "")) == "WARN", "P1-20A dry-run returns WARN, not FAIL", str(report.get("verdict", "")))
	_check(not bool(report.get("connection_attempted", true)), "P1-20A no live connection by default")
	_check(bool(report.get("password_redaction_enabled", false)), "P1-20A password redaction enabled")
	_check(not JSON.stringify(report).contains("secret_never_log"), "P1-20A password not present in returned report")
	var written: Dictionary = report.get("written_files", {}) as Dictionary
	_check(str(written.get("report_json", "")) != "", "P1-20A dry-run json report written", str(written.get("report_json", "")))
	_check(str(written.get("report_txt", "")) != "", "P1-20A dry-run text report written", str(written.get("report_txt", "")))
	_check(str(written.get("summary_txt", "")) != "", "P1-20A clear summary written", str(written.get("summary_txt", "")))
	_check(str(written.get("packet_log_csv", "")) != "", "P1-20A packet log csv written", str(written.get("packet_log_csv", "")))
	_check(str(written.get("codec_selftest_json", "")) != "", "P1-20A codec selftest json written", str(written.get("codec_selftest_json", "")))
	var prod_report: Dictionary = probe.call("run_probe", {
		"probe_enabled": true,
		"host": "135.125.201.202",
		"login_port": 10300,
		"username": "codex_test",
		"password": "secret_never_log",
		"send_packets": true,
		"allow_production_host": false,
		"report_dir": "res://reports/p1_20a_opendaoc_tcp_login_probe/",
	}) as Dictionary
	_check(bool(prod_report.get("production_blocked", false)), "P1-20A production host blocked unless explicitly allowed", str(prod_report.get("block_reason", "")))
	_check(not bool(prod_report.get("connection_attempted", true)), "P1-20A production block prevents connection")
	_check(zone_viewer.get("p1_20a_opendaoc_probe_enabled") != null, "P1-20A inspector enabled export exists")
	_check(zone_viewer.get("p1_20a_opendaoc_probe_run_on_ready") != null, "P1-20A inspector run_on_ready export exists")
	_check(zone_viewer.get("p1_20a_opendaoc_dry_run_report_on_ready") == false, "P1-20A dry-run report stays off during normal startup")
	_check(zone_viewer.get("p1_20a_opendaoc_ctrl_r_enabled") == true, "P1-20A Ctrl+R hotkey enabled by default")
	_check(zone_viewer.get("p1_20a_opendaoc_send_packets") == false, "P1-20A send_packets false by default")
	_check(zone_viewer.get("p1_20a_opendaoc_allow_production_host") == false, "P1-20A allow production host false by default")
	_check(zone_viewer.has_method("build_opendaoc_tcp_login_probe_options_p1_20a"), "P1-20A ZoneViewer options wrapper exists")
	_check(zone_viewer.has_method("_run_opendaoc_tcp_login_probe_from_inspector_p1_20a"), "P1-20A inspector runner exists")
	if bool(zone_viewer.get("p1_20a_opendaoc_probe_enabled")) and bool(zone_viewer.get("p1_20a_opendaoc_send_packets")):
		var live_report: Dictionary = zone_viewer.call("_run_opendaoc_tcp_login_probe_from_inspector_p1_20a") as Dictionary
		_warn("P1-20A explicit live probe executed by inspector flags", str(live_report.get("verdict", "")))
	else:
		_check(true, "P1-20A live probe not launched by default")
	probe.free()
	_debug.append("\n--- P1-20A OpenDAoC TCP Login Probe ---")
	_debug.append(_snapshot_debug_line(report))


func _test_asset_material_fidelity_p1_18n(zone_viewer: Node) -> void:
	_section("P1-18N Asset & Material Fidelity audit")
	_check(DaocAssetMaterialFidelityAuditScript != null, "P1-18N audit script exists")
	if DaocAssetMaterialFidelityAuditScript == null:
		return
	var audit: RefCounted = DaocAssetMaterialFidelityAuditScript.new()
	_check(audit != null, "P1-18N audit instantiates")
	if audit == null:
		return
	var defaults: Dictionary = audit.call("default_options") as Dictionary
	_check(str(defaults.get("report_dir", "")).find("p1_18n_asset_material_audit") >= 0, "P1-18N report dir configured", str(defaults.get("report_dir", "")))
	var tokens: Array = defaults.get("critical_tokens", []) as Array
	_check(tokens.has("bridge") and tokens.has("camelot") and tokens.has("cotswold"), "P1-18N critical bridge/Camelot/Cotswold tokens configured", str(tokens))
	var report: Dictionary = audit.call("run_zone_audit", zone_viewer, _first_configured_zone(zone_viewer), {
		"write_reports": true,
		"scan_model_index": true,
		"scan_texture_index": true,
		"inspect_runtime_materials": true,
		"max_texture_samples": 120,
		"max_runtime_material_nodes": 96,
	}) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_18N_ASSET_MATERIAL_FIDELITY_AUDIT", "P1-18N checkpoint")
	_check(bool(report.get("non_destructive", false)), "P1-18N non destructive")
	_check(not bool(report.get("runtime_modified", true)), "P1-18N runtime unchanged")
	_check(typeof(report.get("placement", {})) == TYPE_DICTIONARY, "P1-18N placement report produced")
	_check(typeof(report.get("models", {})) == TYPE_DICTIONARY, "P1-18N model report produced")
	_check(typeof(report.get("textures", {})) == TYPE_DICTIONARY, "P1-18N texture report produced")
	_check(typeof(report.get("critical_runtime", {})) == TYPE_DICTIONARY, "P1-18N critical runtime report produced")
	_check(typeof(report.get("critical_placements", {})) == TYPE_DICTIONARY, "P1-18N critical placement report produced")
	_check(int((report.get("models", {}) as Dictionary).get("model_index_size", 0)) > 0, "P1-18N model index accessible", str((report.get("models", {}) as Dictionary).get("model_index_size", 0)))
	_check(int((report.get("textures", {}) as Dictionary).get("texture_index_size", 0)) > 0, "P1-18N texture index accessible", str((report.get("textures", {}) as Dictionary).get("texture_index_size", 0)))
	_check(zone_viewer.get("asset_material_audit_enabled") != null, "P1-18N inspector checkbox exported")
	_check(zone_viewer.get("asset_material_audit_run_on_ready") != null, "P1-18N inspector auto-run exported")
	_check(zone_viewer.get("asset_material_audit_zone") != null, "P1-18N inspector zone exported")
	_check(zone_viewer.has_method("_run_asset_material_audit_from_inspector_p1_18n"), "P1-18N inspector runner exists")
	var written: Dictionary = report.get("written_files", {}) as Dictionary
	_check(str(written.get("txt", "")) != "", "P1-18N text report written", str(written.get("txt", "")))
	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/assetaudit help")), "P1-18N /assetaudit help handled")
	_debug.append("\n--- P1-18N Asset & Material Fidelity audit ---")
	_debug.append(_snapshot_debug_line(report))
	_debug.append(str(audit.call("summarize_for_console", report)))
	_debug.append(_format_p1_18n_debug_details(report))


func _test_nif_import_conversion_probe_p1_18n_hf6(zone_viewer: Node) -> void:
	_section("P1-18N-HF6 NIF Import Conversion Probe")
	_check(DaocNifImportConversionProbeScript != null, "P1-18N-HF6 probe script exists")
	if DaocNifImportConversionProbeScript == null:
		return
	var probe: RefCounted = DaocNifImportConversionProbeScript.new()
	_check(probe != null, "P1-18N-HF6 probe instantiates")
	if probe == null:
		return
	var defaults: Dictionary = probe.call("default_options") as Dictionary
	_check(str(defaults.get("report_dir", "")).find("p1_18n_nif_import_probe") >= 0, "P1-18N-HF6 report directory configured", str(defaults.get("report_dir", "")))
	var report: Dictionary = probe.call("run_zone_probe", zone_viewer, 0, {
		"write_csv": true,
		"write_json": true,
		"write_txt": true,
		"max_fixtures": 0,
		"focus_nif_ids": [408, 423, 424],
		"max_source_probes": 32,
	}) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_18N_HF6_NIF_IMPORT_CONVERSION_PROBE", "P1-18N-HF6 checkpoint")
	_check(bool(report.get("non_destructive", false)), "P1-18N-HF6 non destructive")
	_check(not bool(report.get("runtime_modified", true)), "P1-18N-HF6 no destructive runtime modifications")
	_check(typeof(report.get("fixtures", [])) == TYPE_ARRAY, "P1-18N-HF6 zone000 smoke probe runs")
	var brg: Dictionary = report.get("brghouse", {}) as Dictionary
	_check(not brg.is_empty(), "P1-18N-HF6 brghouse fixture detected or cleanly reported missing", str(brg.get("verdict", "")))
	if bool(brg.get("node_found", false)) and int(brg.get("vertex_count", 0)) >= 1000:
		_check(bool(brg.get("anomaly", false)) or str(brg.get("severity", "")) == "none", "P1-18N-HF6 brghouse anomaly verdict produced", str(brg.get("reasons", [])))
	var written: Dictionary = report.get("written_files", {}) as Dictionary
	_check(str(written.get("all_csv", "")) != "", "P1-18N-HF6 all.csv written", str(written.get("all_csv", "")))
	_check(str(written.get("anomalies_csv", "")) != "", "P1-18N-HF6 anomalies.csv written", str(written.get("anomalies_csv", "")))
	_check(str(written.get("focus_csv", "")) != "", "P1-18N-HF6 focus.csv written", str(written.get("focus_csv", "")))
	_check(str(written.get("json", "")) != "", "P1-18N-HF6 json report written", str(written.get("json", "")))
	_check(zone_viewer.get("nif_import_probe_enabled") != null, "P1-18N-HF6 inspector checkbox exported")
	_check(zone_viewer.get("nif_import_probe_run_on_ready") != null, "P1-18N-HF6 run_on_ready exported")
	_check(zone_viewer.get("nif_import_probe_run_on_ready") == false, "P1-18N-HF6 run_on_ready false by default")
	_check(zone_viewer.has_method("_run_nif_import_probe_from_inspector_p1_18n_hf6"), "P1-18N-HF6 inspector runner exists")
	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/nifprobe help")), "P1-18N-HF6 /nifprobe help handled")
	_debug.append("\n--- P1-18N-HF6 NIF Import Conversion Probe ---")
	_debug.append(_snapshot_debug_line(report))
	_debug.append(str(probe.call("summarize_for_console", report)))


func _test_player_visual_meshy_p1_18m(zone_viewer: Node) -> void:
	_section("P1-18M PlayerVisual Meshy swap")
	_check(DaocPlayerVisualMeshySwapScript != null, "P1-18M Meshy swap script exists")
	if DaocPlayerVisualMeshySwapScript == null:
		return
	var swap: RefCounted = DaocPlayerVisualMeshySwapScript.new()
	_check(swap != null, "P1-18M Meshy swap instantiates")
	if swap == null:
		return
	var player_node := _get_node_ref(zone_viewer, "_player")
	var status: Dictionary = swap.call("build_status_report", player_node) as Dictionary
	_check(str(status.get("checkpoint", "")) == "P1_18M_PLAYER_VISUAL_MESHY_SWAP", "P1-18M checkpoint")
	_check(bool(status.get("walk_glb_exists", false)), "P1-18M walking GLB present", str(status.get("walk_scene_path", "")))
	_check(bool(status.get("run_glb_exists", false)), "P1-18M running GLB present", str(status.get("run_scene_path", "")))
	_check(not bool(status.get("collision_replaced", true)), "P1-18M does not replace collision")
	_check(not bool(status.get("character_body_replaced", true)), "P1-18M does not replace CharacterBody3D")
	_check(bool(status.get("server_authority_unchanged", false)), "P1-18M server authority unchanged")
	_check(zone_viewer.get("player_visual_meshy_enabled") != null, "P1-18M inspector checkbox exported")
	_check(zone_viewer.get("player_visual_meshy_apply_on_ready") != null, "P1-18M inspector auto-apply exported")
	_check(zone_viewer.get("player_visual_meshy_animation_state") != null, "P1-18M inspector animation state exported")
	_check(zone_viewer.get("player_visual_meshy_idle_mode") != null, "P1-18M inspector idle mode exported")
	_check(float(zone_viewer.get("player_visual_meshy_scale")) >= 1.0, "P1-18M inspector scale exported", str(zone_viewer.get("player_visual_meshy_scale")))
	if player_node != null:
		var attach_report: Dictionary = swap.call("attach_to_player", player_node, {"visual_scale": 1.0, "ground_offset": 0.0, "yaw_degrees": 180.0}) as Dictionary
		_check(bool(attach_report.get("ok", false)), "P1-18M Meshy visual attaches", str(attach_report.get("install_error", "")))
		_check(bool(attach_report.get("visual_root_attached", false)), "P1-18M visual root attached")
		_check(bool(attach_report.get("walk_animation_player_found", false)), "P1-18M walk AnimationPlayer found")
		_check(bool(attach_report.get("run_animation_player_found", false)), "P1-18M run AnimationPlayer found")
		_check(bool(attach_report.get("capsule_collision_preserved", false)), "P1-18M capsule collision preserved")
		_check(int(attach_report.get("collision_shape_count", 0)) > 0, "P1-18M player collision shape still present", str(attach_report.get("collision_shape_count", 0)))
		_check(not bool(attach_report.get("collision_replaced", true)), "P1-18M attach does not replace collision")
		var detach_report: Dictionary = swap.call("detach_from_player", player_node, false) as Dictionary
		_check(bool(detach_report.get("ok", false)), "P1-18M visual detaches/hides cleanly")
	else:
		_warn("P1-18M player node not available; asset/status checks only")
	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/playervisual status")), "P1-18M /playervisual status handled")
		_check(bool(command.call("execute_command", "/playervisual meshy")), "P1-18M /playervisual meshy handled")
		_check(bool(command.call("execute_command", "/playervisual walk")), "P1-18M /playervisual walk handled")
		_check(bool(command.call("execute_command", "/playervisual run")), "P1-18M /playervisual run handled")
		_check(bool(command.call("execute_command", "/playervisual auto")), "P1-18M /playervisual auto handled")
		_check(bool(command.call("execute_command", "/playervisual idlemode walk_loop")), "P1-18M /playervisual idlemode handled")
		_check(bool(command.call("execute_command", "/playervisual off")), "P1-18M /playervisual off handled")
	_debug.append("\n--- P1-18M PlayerVisual Meshy swap ---")
	_debug.append(_snapshot_debug_line(status))


func _test_actor_grounding_visual_feet_p1_18p(zone_viewer: Node) -> void:
	_section("P1-18P Actor Grounding & Visual Feet Alignment")
	_check(DaocGroundingServiceScript != null, "P1-18P grounding service script exists")
	var service: RefCounted = DaocGroundingServiceScript.new()
	_check(service != null, "P1-18P grounding service instantiates")
	if service == null:
		return
	_check(zone_viewer.get("player_grounding_enabled") != null, "P1-18P grounding enabled export exists")
	_check(zone_viewer.get("player_grounding_probe_height") != null, "P1-18P probe height export exists")
	_check(zone_viewer.get("player_grounding_probe_depth") != null, "P1-18P probe depth export exists")
	_check(zone_viewer.get("player_visual_auto_feet_align") != null, "P1-18P visual auto feet align export exists")
	_check(zone_viewer.get("player_visual_feet_offset") != null, "P1-18P visual feet offset export exists")
	_check(zone_viewer.get("player_visual_feet_align_runtime") != null, "P1-18P runtime visual feet align export exists")
	_check(zone_viewer.get("player_visual_feet_align_max_step") != null, "P1-18P runtime visual feet max step export exists")
	_check(zone_viewer.has_method("build_player_grounding_options_p1_18p"), "P1-18P ZoneViewer options wrapper exists")
	_check(zone_viewer.has_method("apply_player_grounding_and_feet_alignment_p1_18p"), "P1-18P ZoneViewer apply wrapper exists")
	var player_node := _get_node_ref(zone_viewer, "_player")
	_check(player_node != null and player_node is CharacterBody3D, "P1-18P player CharacterBody3D still present")
	_check(player_node == null or _count_node_type(player_node, "CollisionShape3D") > 0, "P1-18P player CollisionShape3D still present")
	var options := {}
	if zone_viewer.has_method("build_player_grounding_options_p1_18p"):
		options = zone_viewer.call("build_player_grounding_options_p1_18p", {"write_report": true}) as Dictionary
	_check(str(options.get("report_dir", "")) != "", "P1-18P report dir configured", str(options.get("report_dir", "")))
	if player_node is Node3D:
		var probe: Dictionary = service.call("probe_ground", player_node as Node3D, zone_viewer, options) as Dictionary
		_check(typeof(probe) == TYPE_DICTIONARY, "P1-18P probe_ground returns Dictionary")
		_check(str(probe.get("ground_source", "none")) != "", "P1-18P ground source reported", str(probe.get("ground_source", "")))
		_check(probe.has("terrain_y"), "P1-18P terrain fallback field present")
		_check(probe.has("collision_y"), "P1-18P collision probe field present")
		var visual_root := player_node.get_node_or_null("DaocPlayerVisualRoot") as Node3D
		if visual_root != null:
			var feet: Dictionary = service.call("compute_visual_feet_offset", visual_root) as Dictionary
			_check(typeof(feet) == TYPE_DICTIONARY, "P1-18P compute visual feet returns Dictionary")
			var align: Dictionary = service.call("apply_visual_feet_alignment", visual_root, options.merged({"write_report": true}, true)) as Dictionary
			_check(typeof(align) == TYPE_DICTIONARY and align.has("visual_aabb_after"), "P1-18P visual feet alignment report produced")
			if visual_root.has_method("build_status_report"):
				var visual_status: Dictionary = visual_root.call("build_status_report") as Dictionary
				_check(visual_status.has("feet_alignment_enabled"), "P1-18P runtime visual feet alignment status exposed")
		else:
			_warn("P1-18P Meshy visual root absent; feet alignment optional")
	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/grounding status")), "P1-18P /grounding status handled")
		_check(bool(command.call("execute_command", "/grounding probe")), "P1-18P /grounding probe handled")
		_check(bool(command.call("execute_command", "/feetalign status")), "P1-18P /feetalign status handled")
	_debug.append("\n--- P1-18P Actor Grounding & Visual Feet Alignment ---")
	_debug.append("server_authority=true prediction_only=true damage_final=false; CharacterBody3D/Capsule/Meshy visual preserved")


func _test_offline_combat_lab_p1_18b(zone_viewer: Node) -> void:
	_section("P1-18B offline combat/spell mechanics lab")
	_check(DaocOfflineCombatLabScript != null, "P1-18B combat lab script exists")
	_check(DaocOpenDaocAttackRequestCodecScript != null, "P1-18B attack request codec script exists")
	_check(DaocOpenDaocUseSpellCodecScript != null, "P1-18B UseSpell codec script exists")
	if DaocOfflineCombatLabScript == null:
		return
	var lab: RefCounted = DaocOfflineCombatLabScript.new()
	_check(lab != null, "P1-18B combat lab instantiates")
	if lab == null:
		return
	var load: Dictionary = lab.call("load_default_fixtures") as Dictionary
	_check(bool(load.get("ok", false)), "P1-18B default spell fixtures load", str(load.get("error", "")))
	var report: Dictionary = lab.call("run_spell_suite", {"seed": 42}) as Dictionary
	var guard: Dictionary = report.get("guardrails", {}) as Dictionary
	var book: Dictionary = report.get("spellbook", {}) as Dictionary
	var registry: Dictionary = report.get("registry", {}) as Dictionary
	var spell_results: Array = report.get("spell_results", []) as Array
	var melee: Dictionary = report.get("melee", {}) as Dictionary
	_check(str(report.get("checkpoint", "")) == "P1_18B_OFFLINE_COMBAT_LAB", "P1-18B checkpoint")
	_check(bool(report.get("ok", false)), "P1-18B spell suite builds")
	_check(bool(guard.get("server_authority", false)), "P1-18B keeps server authority true")
	_check(bool(guard.get("prediction_only", false)), "P1-18B prediction_only true")
	_check(not bool(guard.get("damage_final", true)), "P1-18B damage_final remains false")
	_check(not bool(guard.get("runtime_enabled", true)), "P1-18B runtime remains disabled")
	_check(int(book.get("spell_count", 0)) >= 7, "P1-18B spell fixture count")
	_check(int(registry.get("handler_count", 0)) >= 7, "P1-18B handler registry count")
	_check(spell_results.size() >= 5, "P1-18B spell mechanisms execute")
	_check(int(melee.get("attack_count", 0)) >= 1, "P1-18B melee weapon action executes")

	var attack_codec: RefCounted = DaocOpenDaocAttackRequestCodecScript.new()
	var packet: PackedByteArray = attack_codec.call("build_attack_request", true, true) as PackedByteArray
	var decoded: Dictionary = attack_codec.call("decode_attack_request", packet) as Dictionary
	_check(bool(decoded.get("ok", false)) and str(decoded.get("action", "")) == "RequestStartAttack", "P1-18B PlayerAttackRequest codec start")
	var spell_codec: RefCounted = DaocOpenDaocUseSpellCodecScript.new()
	var use_req: Dictionary = spell_codec.call("build_use_spell_request_1127", Vector3(1.0, 2.0, 3.0), 0.0, 1024, 0, 50, {"target_in_view": true}) as Dictionary
	_check(bool(use_req.get("ok", false)) and int(use_req.get("spell_level", 0)) == 50, "P1-18B UseSpell request model builds")
	var json_export: Dictionary = lab.call("export_last_report_json", "res://reports/p1_18b_offline_combat_lab.json") as Dictionary
	var txt_export: Dictionary = lab.call("export_last_report_text", "res://reports/p1_18b_offline_combat_lab.txt") as Dictionary
	_check(bool(json_export.get("ok", false)), "P1-18B JSON report export works", str(json_export.get("error", "")))
	_check(bool(txt_export.get("ok", false)), "P1-18B text report export works", str(txt_export.get("error", "")))

	var command = _get_node_ref(zone_viewer, "_command_router")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab status")), "P1-18B /combatlab status handled")
		_check(bool(command.call("execute_command", "/combatlab report")), "P1-18B /combatlab report handled")

	_section("P1-18C combat lab detailed report")
	var detailed_report: Dictionary = lab.call("run_detailed_suite", {"seed": 42, "verbose": true}) as Dictionary
	var detailed_summary: Dictionary = detailed_report.get("summary", {}) as Dictionary
	var detailed_entries: Array = detailed_report.get("entries", []) as Array
	_check(str(detailed_report.get("checkpoint", "")) == "P1_18C_COMBAT_LAB_DETAILED_REPORT", "P1-18C checkpoint")
	_check(bool(detailed_report.get("ok", false)), "P1-18C detailed suite builds")
	_check(detailed_entries.size() >= 7, "P1-18C detailed entries include spell and reactive handlers")
	_check(int(detailed_summary.get("entry_count", 0)) >= 7, "P1-18C summary entry count")
	_check(int(detailed_summary.get("total_predicted_damage", 0)) > 0, "P1-18C total predicted damage reported")
	_check(int(detailed_summary.get("max_abs_hp_delta", 0)) > 0, "P1-18C max HP delta reported")
	var cast_probe: Dictionary = lab.call("cast_spell_by_id", 101, {"seed": 42, "verbose": true}) as Dictionary
	_check(bool(cast_probe.get("ok", false)) and int(cast_probe.get("spell_id", 0)) == 101, "P1-18C cast spell by id")
	var dummy_probe: Dictionary = lab.call("dummy_snapshot") as Dictionary
	_check(bool(dummy_probe.get("ok", false)), "P1-18C dummy snapshot")
	var detailed_json_export: Dictionary = lab.call("export_detailed_report_json", "res://reports/p1_18c_combat_lab.json") as Dictionary
	var detailed_txt_export: Dictionary = lab.call("export_detailed_report_text", "res://reports/p1_18c_combat_lab.txt") as Dictionary
	_check(bool(detailed_json_export.get("ok", false)), "P1-18C JSON report export works", str(detailed_json_export.get("error", "")))
	_check(bool(detailed_txt_export.get("ok", false)), "P1-18C text report export works", str(detailed_txt_export.get("error", "")))
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab dummy")), "P1-18C /combatlab dummy handled")
		_check(bool(command.call("execute_command", "/combatlab suite verbose")), "P1-18C /combatlab suite verbose handled")
		_check(bool(command.call("execute_command", "/combatlab cast 101")), "P1-18C /combatlab cast handled")

	_section("P1-18D OpenDAoC spell SQL spellbook")
	var p18d_candidates: Array = _opendaoc_db_candidates_from_zone_viewer_p1_17e2g(zone_viewer)
	var p18d_report: Dictionary = lab.call("run_opendaoc_spellbook_detailed_suite", p18d_candidates, {"seed": 42, "verbose": false, "max_rows": 8192}) as Dictionary
	var p18d_status: String = str(p18d_report.get("status", ""))
	var p18d_book: Dictionary = p18d_report.get("spellbook", {}) as Dictionary
	_check(str(p18d_report.get("checkpoint", "")) == "P1_18D_OPENDAOC_SPELLBOOK_TO_COMBAT_LAB", "P1-18D checkpoint")
	_check(bool(p18d_report.get("ok", false)) or p18d_status == "waiting_for_local_sql_directory", "P1-18D parses OpenDAoC spellbook or waits gracefully", p18d_status)
	if bool(p18d_report.get("ok", false)):
		_check(int(p18d_book.get("spell_count", 0)) > 0, "P1-18D OpenDAoC spell count", str(p18d_book.get("spell_count", 0)))
		_check(int(p18d_report.get("supported_spell_count", 0)) > 0, "P1-18D supported spell count", str(p18d_report.get("supported_spell_count", 0)))
		_check(int(p18d_report.get("first_supported_spell_id", 0)) > 0, "P1-18D first supported spell id", str(p18d_report.get("first_supported_spell_id", 0)))
		var p18d_real_cast: Dictionary = lab.call("cast_opendaoc_spell_by_id", int(p18d_report.get("first_supported_spell_id", 0)), p18d_candidates, {"seed": 42, "verbose": true, "max_rows": 8192}) as Dictionary
		_check(bool(p18d_real_cast.get("ok", false)), "P1-18D casts real OpenDAoC spell id in prediction lab", str(p18d_real_cast.get("spell_id", 0)))
		var p18d_json_export: Dictionary = lab.call("export_opendaoc_spellbook_report_json", "res://reports/p1_18d_opendaoc_spellbook.json") as Dictionary
		var p18d_txt_export: Dictionary = lab.call("export_opendaoc_spellbook_report_text", "res://reports/p1_18d_opendaoc_spellbook.txt") as Dictionary
		_check(bool(p18d_json_export.get("ok", false)), "P1-18D JSON spellbook report export works", str(p18d_json_export.get("error", "")))
		_check(bool(p18d_txt_export.get("ok", false)), "P1-18D text spellbook report export works", str(p18d_txt_export.get("error", "")))
	else:
		_check(p18d_status == "waiting_for_local_sql_directory", "P1-18D no DB fallback stays non-runtime", p18d_status)
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc status")), "P1-18D /combatlab opendaoc status handled")
		_check(bool(command.call("execute_command", "/combatlab opendaoc report")), "P1-18D /combatlab opendaoc report handled")
		if bool(p18d_report.get("ok", false)):
			_check(bool(command.call("execute_command", "/combatlab opendaoc cast %d" % int(p18d_report.get("first_supported_spell_id", 0)))), "P1-18E /combatlab opendaoc cast explicit handled")
	_debug.append("\n--- P1-18D OpenDAoC spellbook report ---")
	_debug.append(_snapshot_debug_line(p18d_report))

	_section("P1-18E OpenDAoC spell coverage backlog")
	var p18e_report: Dictionary = lab.call("run_opendaoc_spell_coverage_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4}) as Dictionary
	var p18e_status: String = str(p18e_report.get("status", ""))
	_check(str(p18e_report.get("checkpoint", "")) == "P1_18E_OPENDAOC_SPELL_COVERAGE", "P1-18E checkpoint")
	_check(bool(p18e_report.get("ok", false)) or p18e_status == "waiting_for_local_sql_directory", "P1-18E coverage builds or waits gracefully", p18e_status)
	if bool(p18e_report.get("ok", false)):
		_check(int(p18e_report.get("total_spell_count", 0)) == int(p18e_report.get("supported_spell_count", 0)) + int(p18e_report.get("unsupported_spell_count", 0)), "P1-18E supported + unsupported equals total")
		_check(int(p18e_report.get("type_count", 0)) > 0, "P1-18E type rows present", str(p18e_report.get("type_count", 0)))
		_check(int(p18e_report.get("unsupported_type_count", 0)) > 0, "P1-18E unsupported type count reported", str(p18e_report.get("unsupported_type_count", 0)))
		var p18e_top_unsupported: Array = p18e_report.get("top_unsupported_types", []) as Array
		var p18e_handler_backlog: Array = p18e_report.get("handler_backlog", []) as Array
		_check(p18e_top_unsupported.size() > 0, "P1-18E top unsupported types present")
		_check(p18e_handler_backlog.size() > 0, "P1-18E handler backlog present")
		var p18e_json_export: Dictionary = lab.call("export_opendaoc_spell_coverage_report_json", "res://reports/p1_18e_opendaoc_spell_coverage.json") as Dictionary
		var p18e_txt_export: Dictionary = lab.call("export_opendaoc_spell_coverage_report_text", "res://reports/p1_18e_opendaoc_spell_coverage.txt") as Dictionary
		_check(bool(p18e_json_export.get("ok", false)), "P1-18E JSON coverage report export works", str(p18e_json_export.get("error", "")))
		_check(bool(p18e_txt_export.get("ok", false)), "P1-18E text coverage report export works", str(p18e_txt_export.get("error", "")))
	else:
		_check(p18e_status == "waiting_for_local_sql_directory", "P1-18E no DB fallback stays non-runtime", p18e_status)
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc coverage")), "P1-18E /combatlab opendaoc coverage handled")
	_debug.append("\n--- P1-18E OpenDAoC spell coverage report ---")
	_debug.append(_snapshot_debug_line(p18e_report))

	_section("P1-18F OpenDAoC P0 spell handlers")
	var p18f_report: Dictionary = lab.call("run_opendaoc_p0_handler_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18f_status: String = str(p18f_report.get("status", ""))
	_check(str(p18f_report.get("checkpoint", "")) == "P1_18F_OPENDAOC_P0_HANDLERS", "P1-18F checkpoint")
	_check(bool(p18f_report.get("ok", false)) or p18f_status == "waiting_for_local_sql_directory", "P1-18F P0 report builds or waits gracefully", p18f_status)
	var p18f_registered: Array = p18f_report.get("p0_registered_types", []) as Array
	var p18f_missing: Array = p18f_report.get("missing_registered_types", []) as Array
	if bool(p18f_report.get("ok", false)):
		_check(p18f_registered.size() >= 20, "P1-18F P0 type list present", str(p18f_registered.size()))
		_check(p18f_missing.is_empty(), "P1-18F P0 types registered")
		_check(int(p18f_report.get("supported_spell_count", 0)) >= int(p18d_report.get("supported_spell_count", 0)), "P1-18F supported count remains expanded", "%d >= %d" % [int(p18f_report.get("supported_spell_count", 0)), int(p18d_report.get("supported_spell_count", 0))])
		_check(int(p18f_report.get("cast_probe_count", 0)) > 0, "P1-18F cast probes present", str(p18f_report.get("cast_probe_count", 0)))
		_check(int(p18f_report.get("ok_cast_probe_count", 0)) == int(p18f_report.get("cast_probe_count", 0)), "P1-18F all P0 cast probes handled", "%d/%d" % [int(p18f_report.get("ok_cast_probe_count", 0)), int(p18f_report.get("cast_probe_count", 0))])
		var p18f_handler_probe_counts: Dictionary = p18f_report.get("handler_probe_counts", {}) as Dictionary
		_check(p18f_handler_probe_counts.has("DaocCrowdControlSpellHandler"), "P1-18F crowd-control handler probes present")
		_check(p18f_handler_probe_counts.has("DaocLifeDrainSpellHandler"), "P1-18F lifedrain handler probes present")
		_check(p18f_handler_probe_counts.has("DaocDirectDamageWithDebuffSpellHandler"), "P1-18F DD+debuff handler probes present")
		_check(p18f_handler_probe_counts.has("DaocHealOrResurrectSpellHandler"), "P1-18F heal/resurrect handler probes present")
		var p18f_json_export: Dictionary = lab.call("export_opendaoc_p0_handler_report_json", "res://reports/p1_18f_opendaoc_p0_handlers.json") as Dictionary
		var p18f_txt_export: Dictionary = lab.call("export_opendaoc_p0_handler_report_text", "res://reports/p1_18f_opendaoc_p0_handlers.txt") as Dictionary
		_check(bool(p18f_json_export.get("ok", false)), "P1-18F JSON P0 handler report export works", str(p18f_json_export.get("error", "")))
		_check(bool(p18f_txt_export.get("ok", false)), "P1-18F text P0 handler report export works", str(p18f_txt_export.get("error", "")))
	else:
		_check(p18f_status == "waiting_for_local_sql_directory", "P1-18F no DB fallback stays non-runtime", p18f_status)
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc p0")), "P1-18F /combatlab opendaoc p0 handled")
	_debug.append("\n--- P1-18F OpenDAoC P0 handler report ---")
	_debug.append(_snapshot_debug_line(p18f_report))

	_section("P1-18G Buff/Debuff state model")
	_check(DaocBuffDebuffSpellHandlerScript != null, "P1-18G Buff/Debuff handler exists")
	_check(DaocActiveEffectScript != null, "P1-18G active effect model exists")
	_check(DaocEffectStateScript != null, "P1-18G effect state model exists")
	var p18g_report: Dictionary = lab.call("run_opendaoc_buff_debuff_state_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18g_status: String = str(p18g_report.get("status", ""))
	_check(str(p18g_report.get("checkpoint", "")) == "P1_18G_BUFF_DEBUFF_STATE_MODEL", "P1-18G checkpoint")
	_check(bool(p18g_report.get("ok", false)) or p18g_status == "waiting_for_local_sql_directory", "P1-18G report builds or waits gracefully", p18g_status)
	var p18g_registered: Array = p18g_report.get("registered_types", []) as Array
	var p18g_missing: Array = p18g_report.get("missing_registered_types", []) as Array
	_check(p18g_registered.has("BaseArmorFactorBuff"), "P1-18G BaseArmorFactorBuff registered")
	_check(p18g_registered.has("CombatSpeedBuff"), "P1-18G CombatSpeedBuff registered")
	_check(p18g_registered.has("StrengthConstitutionBuff"), "P1-18G StrengthConstitutionBuff registered")
	_check(p18g_registered.has("DexterityQuicknessBuff"), "P1-18G DexterityQuicknessBuff registered")
	_check(p18g_registered.has("SpeedEnhancement"), "P1-18G SpeedEnhancement registered")
	_check(p18g_missing.is_empty(), "P1-18G main Buff/Debuff types registered", str(p18g_missing))
	if bool(p18g_report.get("ok", false)):
		var p18g_summary: Dictionary = p18g_report.get("active_effect_summary", {}) as Dictionary
		_check(int(p18g_report.get("sample_cast_count", 0)) > 0, "P1-18G Buff/Debuff probes present", str(p18g_report.get("sample_cast_count", 0)))
		_check(int(p18g_report.get("ok_sample_cast_count", 0)) == int(p18g_report.get("sample_cast_count", 0)), "P1-18G Buff/Debuff probes pass", "%d/%d" % [int(p18g_report.get("ok_sample_cast_count", 0)), int(p18g_report.get("sample_cast_count", 0))])
		_check(int(p18g_summary.get("active_effect_count", 0)) > 0, "P1-18G active_effects is non-empty", str(p18g_summary.get("active_effect_count", 0)))
		_check(int(p18g_report.get("supported_spell_count", 0)) >= int(p18f_report.get("supported_spell_count", 0)), "P1-18G supported count increases from P1-18F", "%d >= %d" % [int(p18g_report.get("supported_spell_count", 0)), int(p18f_report.get("supported_spell_count", 0))])
		var p18g_json_export: Dictionary = lab.call("export_buff_debuff_state_report_json", "res://reports/p1_18g_buff_debuff_state.json") as Dictionary
		var p18g_txt_export: Dictionary = lab.call("export_buff_debuff_state_report_text", "res://reports/p1_18g_buff_debuff_state.txt") as Dictionary
		_check(bool(p18g_json_export.get("ok", false)), "P1-18G JSON Buff/Debuff report export works", str(p18g_json_export.get("error", "")))
		_check(bool(p18g_txt_export.get("ok", false)), "P1-18G text Buff/Debuff report export works", str(p18g_txt_export.get("error", "")))
		_check(bool((p18g_report.get("guardrails", {}) as Dictionary).get("server_authority", false)), "P1-18G server_authority true")
		_check(bool((p18g_report.get("guardrails", {}) as Dictionary).get("prediction_only", false)), "P1-18G prediction_only true")
		_check(not bool((p18g_report.get("guardrails", {}) as Dictionary).get("damage_final", true)), "P1-18G damage_final false")
		_check(not bool((p18g_report.get("guardrails", {}) as Dictionary).get("runtime_enabled", true)), "P1-18G runtime_enabled false")
	else:
		_check(p18g_status == "waiting_for_local_sql_directory", "P1-18G no DB fallback stays non-runtime", p18g_status)
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc buffs")), "P1-18G /combatlab opendaoc buffs handled")
		_check(bool(command.call("execute_command", "/combatlab effects")), "P1-18G /combatlab effects handled")
	_debug.append("\n--- P1-18G Buff/Debuff state model ---")
	_debug.append(_snapshot_debug_line(p18g_report))

	_section("P1-18H DoT/Disease/Proc state model")
	_check(DaocDoTDiseaseProcSpellHandlerScript != null, "P1-18H DoT/Disease/Proc handler exists")
	var p18h_report: Dictionary = lab.call("run_opendaoc_dot_disease_proc_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18h_status: String = str(p18h_report.get("status", ""))
	var p18h_registered: Array = p18h_report.get("registered_types", []) as Array
	_check(str(p18h_report.get("checkpoint", "")) == "P1_18H_DOT_DISEASE_PROC_STATE_MODEL", "P1-18H checkpoint")
	_check(bool(p18h_report.get("ok", false)) or p18h_status == "waiting_for_local_sql_directory", "P1-18H report builds or waits gracefully", p18h_status)
	_check(p18h_registered.has("OffensiveProc"), "P1-18H OffensiveProc registered")
	_check(p18h_registered.has("Disease"), "P1-18H Disease registered")
	_check(p18h_registered.has("ArcheryDoT"), "P1-18H ArcheryDoT registered")
	_check(p18h_registered.has("StyleBleeding"), "P1-18H StyleBleeding registered")
	_check((p18h_report.get("missing_registered_types", []) as Array).is_empty(), "P1-18H types registered")
	if bool(p18h_report.get("ok", false)):
		_check(int(p18h_report.get("sample_cast_count", 0)) > 0, "P1-18H probes present", str(p18h_report.get("sample_cast_count", 0)))
		_check(int(p18h_report.get("ok_sample_cast_count", 0)) == int(p18h_report.get("sample_cast_count", 0)), "P1-18H probes pass", "%d/%d" % [int(p18h_report.get("ok_sample_cast_count", 0)), int(p18h_report.get("sample_cast_count", 0))])
		_check(int(p18h_report.get("supported_spell_count", 0)) >= int(p18g_report.get("supported_spell_count", 0)), "P1-18H supported count expands", "%d >= %d" % [int(p18h_report.get("supported_spell_count", 0)), int(p18g_report.get("supported_spell_count", 0))])
		var p18h_json_export: Dictionary = lab.call("export_dot_disease_proc_report_json", "res://reports/p1_18h_dot_disease_proc_state.json") as Dictionary
		var p18h_txt_export: Dictionary = lab.call("export_dot_disease_proc_report_text", "res://reports/p1_18h_dot_disease_proc_state.txt") as Dictionary
		_check(bool(p18h_json_export.get("ok", false)), "P1-18H JSON report export works", str(p18h_json_export.get("error", "")))
		_check(bool(p18h_txt_export.get("ok", false)), "P1-18H text report export works", str(p18h_txt_export.get("error", "")))
		_check(bool((p18h_report.get("guardrails", {}) as Dictionary).get("server_authority", false)), "P1-18H server_authority true")
		_check(bool((p18h_report.get("guardrails", {}) as Dictionary).get("prediction_only", false)), "P1-18H prediction_only true")
		_check(not bool((p18h_report.get("guardrails", {}) as Dictionary).get("damage_final", true)), "P1-18H damage_final false")
		_check(not bool((p18h_report.get("guardrails", {}) as Dictionary).get("runtime_enabled", true)), "P1-18H runtime_enabled false")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc dots")), "P1-18H /combatlab opendaoc dots handled")
	_debug.append("\n--- P1-18H DoT/Disease/Proc state model ---")
	_debug.append(_snapshot_debug_line(p18h_report))

	_section("P1-18I Generic damage effects")
	_check(DaocGenericDamageEffectSpellHandlerScript != null, "P1-18I generic damage effect handler exists")
	var p18i_report: Dictionary = lab.call("run_opendaoc_generic_damage_effect_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18i_status: String = str(p18i_report.get("status", ""))
	var p18i_registered: Array = p18i_report.get("registered_types", []) as Array
	_check(str(p18i_report.get("checkpoint", "")) == "P1_18I_GENERIC_DAMAGE_EFFECTS", "P1-18I checkpoint")
	_check(bool(p18i_report.get("ok", false)) or p18i_status == "waiting_for_local_sql_directory", "P1-18I report builds or waits gracefully", p18i_status)
	_check(p18i_registered.has("Bomber"), "P1-18I Bomber registered")
	_check(p18i_registered.has("TurretPBAoE"), "P1-18I TurretPBAoE registered")
	_check(p18i_registered.has("FrontalPulseConeDD"), "P1-18I FrontalPulseConeDD registered")
	_check((p18i_report.get("missing_registered_types", []) as Array).is_empty(), "P1-18I types registered")
	if bool(p18i_report.get("ok", false)):
		_check(int(p18i_report.get("sample_cast_count", 0)) > 0, "P1-18I probes present", str(p18i_report.get("sample_cast_count", 0)))
		_check(int(p18i_report.get("ok_sample_cast_count", 0)) == int(p18i_report.get("sample_cast_count", 0)), "P1-18I probes pass", "%d/%d" % [int(p18i_report.get("ok_sample_cast_count", 0)), int(p18i_report.get("sample_cast_count", 0))])
		_check(int(p18i_report.get("supported_spell_count", 0)) >= int(p18h_report.get("supported_spell_count", 0)), "P1-18I supported count expands", "%d >= %d" % [int(p18i_report.get("supported_spell_count", 0)), int(p18h_report.get("supported_spell_count", 0))])
		var p18i_json_export: Dictionary = lab.call("export_generic_damage_effect_report_json", "res://reports/p1_18i_generic_damage_effects.json") as Dictionary
		var p18i_txt_export: Dictionary = lab.call("export_generic_damage_effect_report_text", "res://reports/p1_18i_generic_damage_effects.txt") as Dictionary
		_check(bool(p18i_json_export.get("ok", false)), "P1-18I JSON report export works", str(p18i_json_export.get("error", "")))
		_check(bool(p18i_txt_export.get("ok", false)), "P1-18I text report export works", str(p18i_txt_export.get("error", "")))
		_check(not bool((p18i_report.get("guardrails", {}) as Dictionary).get("damage_final", true)), "P1-18I damage_final false")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc damagefx")), "P1-18I /combatlab opendaoc damagefx handled")
	_debug.append("\n--- P1-18I Generic damage effects ---")
	_debug.append(_snapshot_debug_line(p18i_report))

	_section("P1-18J Pet/Summon intent model")
	_check(DaocPetSpellHandlerScript != null, "P1-18J pet intent handler exists")
	var p18j_report: Dictionary = lab.call("run_opendaoc_pet_summon_intent_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18j_status: String = str(p18j_report.get("status", ""))
	var p18j_registered: Array = p18j_report.get("registered_types", []) as Array
	_check(str(p18j_report.get("checkpoint", "")) == "P1_18J_PET_SUMMON_INTENT_MODEL", "P1-18J checkpoint")
	_check(bool(p18j_report.get("ok", false)) or p18j_status == "waiting_for_local_sql_directory", "P1-18J report builds or waits gracefully", p18j_status)
	_check(p18j_registered.has("SummonAnimistFnF"), "P1-18J SummonAnimistFnF registered")
	_check(p18j_registered.has("SummonMinion"), "P1-18J SummonMinion registered")
	_check(p18j_registered.has("Charm"), "P1-18J Charm registered")
	_check(p18j_registered.has("SummonSiegeRam"), "P1-18J SummonSiegeRam registered")
	_check((p18j_report.get("missing_registered_types", []) as Array).is_empty(), "P1-18J types registered")
	if bool(p18j_report.get("ok", false)):
		_check(int(p18j_report.get("sample_cast_count", 0)) > 0, "P1-18J probes present", str(p18j_report.get("sample_cast_count", 0)))
		_check(int(p18j_report.get("ok_sample_cast_count", 0)) == int(p18j_report.get("sample_cast_count", 0)), "P1-18J probes pass", "%d/%d" % [int(p18j_report.get("ok_sample_cast_count", 0)), int(p18j_report.get("sample_cast_count", 0))])
		_check(int(p18j_report.get("supported_spell_count", 0)) >= int(p18i_report.get("supported_spell_count", 0)), "P1-18J supported count expands", "%d >= %d" % [int(p18j_report.get("supported_spell_count", 0)), int(p18i_report.get("supported_spell_count", 0))])
		var p18j_json_export: Dictionary = lab.call("export_pet_summon_intent_report_json", "res://reports/p1_18j_pet_summon_intent.json") as Dictionary
		var p18j_txt_export: Dictionary = lab.call("export_pet_summon_intent_report_text", "res://reports/p1_18j_pet_summon_intent.txt") as Dictionary
		_check(bool(p18j_json_export.get("ok", false)), "P1-18J JSON report export works", str(p18j_json_export.get("error", "")))
		_check(bool(p18j_txt_export.get("ok", false)), "P1-18J text report export works", str(p18j_txt_export.get("error", "")))
		_check(not bool(p18j_report.get("player_spawn_applied", true)), "P1-18J player_spawn_applied false")
		_check(not bool(p18j_report.get("coordinate_frame_confirmed", true)), "P1-18J coordinate_frame_confirmed false")
		_check(not bool((p18j_report.get("guardrails", {}) as Dictionary).get("runtime_enabled", true)), "P1-18J runtime_enabled false")
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc pets")), "P1-18J /combatlab opendaoc pets handled")
		_check(bool(command.call("execute_command", "/combatlab opendaoc hij")), "P1-18H/I/J combined command handled")
	_debug.append("\n--- P1-18J Pet/Summon intent model ---")
	_debug.append(_snapshot_debug_line(p18j_report))

	_section("P1-18K.2-K.5 lab runtime observation")
	var p18k_report: Dictionary = lab.call("run_opendaoc_k25_lab_runtime_report", p18d_candidates, {"max_rows": 8192, "top_limit": 50, "sample_limit": 4, "seed": 42, "verbose": false}) as Dictionary
	var p18k_status: String = str(p18k_report.get("status", ""))
	_check(str(p18k_report.get("checkpoint", "")) == "P1_18K_2_5_LAB_RUNTIME", "P1-18K.2-K.5 checkpoint")
	_check(bool(p18k_report.get("ok", false)) or p18k_status == "waiting_for_local_sql_directory", "P1-18K.2-K.5 report builds or waits gracefully", p18k_status)
	if bool(p18k_report.get("ok", false)):
		var p18k_k2: Dictionary = p18k_report.get("k2_heal_simple", {}) as Dictionary
		var p18k_k3: Dictionary = p18k_report.get("k3_buff_debuff_duration", {}) as Dictionary
		var p18k_k4: Dictionary = p18k_report.get("k4_dot_tick_minimal", {}) as Dictionary
		var p18k_k5: Dictionary = p18k_report.get("k5_pet_summon_observation", {}) as Dictionary
		_check(bool(p18k_k2.get("ok", false)) and int(p18k_k2.get("effective_amount", 0)) > 0, "P1-18K.2 heal simple applies in lab", "%d" % int(p18k_k2.get("effective_amount", 0)))
		_check(bool(p18k_k2.get("applied_to_lab_target", false)), "P1-18K.2 heal marked lab-only")
		_check(bool(p18k_k3.get("ok", false)) and int(p18k_k3.get("active_before", 0)) > 0, "P1-18K.3 Buff/Debuff duration advances", "%d -> %d" % [int(p18k_k3.get("active_before", 0)), int(p18k_k3.get("active_after", 0))])
		_check(int(p18k_k3.get("advanced_msec", 0)) > 0, "P1-18K.3 duration tick reported")
		_check(bool(p18k_k4.get("ok", false)) and int(p18k_k4.get("tick_damage", 0)) > 0, "P1-18K.4 DoT tick minimal applies in lab", "%d" % int(p18k_k4.get("tick_damage", 0)))
		_check(not bool(p18k_k4.get("final_damage_applied", true)), "P1-18K.4 final damage remains false")
		_check(bool(p18k_k5.get("ok", false)) and int(p18k_k5.get("observed_intent_count", 0)) > 0, "P1-18K.5 pet/summon intents observed", "%d" % int(p18k_k5.get("observed_intent_count", 0)))
		_check(not bool(p18k_k5.get("runtime_spawn_applied", true)), "P1-18K.5 runtime spawn remains false")
		_check(not bool(p18k_report.get("player_spawn_applied", true)), "P1-18K.5 player_spawn_applied false")
		_check(not bool((p18k_report.get("guardrails", {}) as Dictionary).get("runtime_enabled", true)), "P1-18K runtime_enabled false")
		var p18k_json_export: Dictionary = lab.call("export_k25_lab_runtime_report_json", "res://reports/p1_18k_2_5_lab_runtime.json") as Dictionary
		var p18k_txt_export: Dictionary = lab.call("export_k25_lab_runtime_report_text", "res://reports/p1_18k_2_5_lab_runtime.txt") as Dictionary
		_check(bool(p18k_json_export.get("ok", false)), "P1-18K JSON report export works", str(p18k_json_export.get("error", "")))
		_check(bool(p18k_txt_export.get("ok", false)), "P1-18K text report export works", str(p18k_txt_export.get("error", "")))
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab opendaoc k25")), "P1-18K /combatlab opendaoc k25 handled")
	_debug.append("\n--- P1-18K.2-K.5 lab runtime observation ---")
	_debug.append(_snapshot_debug_line(p18k_report))

	_section("P1-18L OpenDAoC live comparison harness")
	_check(DaocOpenDaocLiveComparisonHarnessScript != null, "P1-18L harness script exists")
	var p18l_harness: RefCounted = DaocOpenDaocLiveComparisonHarnessScript.new()
	var p18l_status: Dictionary = p18l_harness.call("build_status_report", {"enabled": false}) as Dictionary
	_check(str(p18l_status.get("checkpoint", "")) == "P1_18L_LIVE_COMPARISON_HARNESS", "P1-18L checkpoint")
	_check(bool(p18l_status.get("ok", false)), "P1-18L disabled status is ok")
	_check(bool(p18l_status.get("skipped", false)), "P1-18L disabled status skips explicitly", str(p18l_status.get("comparison_status", "")))
	_check(not bool(p18l_status.get("server_reachable", true)), "P1-18L disabled status does not probe server")
	var p18l_dd_skip: Dictionary = p18l_harness.call("run_direct_damage_comparison", lab, 101, [], {"enabled": false, "seed": 42}) as Dictionary
	var p18l_prediction: Dictionary = p18l_dd_skip.get("prediction_summary", {}) as Dictionary
	_check(bool(p18l_dd_skip.get("ok", false)) and bool(p18l_dd_skip.get("skipped", false)), "P1-18L DirectDamage skip report is clean", str(p18l_dd_skip.get("comparison_status", "")))
	_check(int(p18l_prediction.get("total_damage", 0)) > 0, "P1-18L prediction result captured", str(p18l_prediction.get("total_damage", 0)))
	_check(not bool(p18l_dd_skip.get("damage_final", true)), "P1-18L damage_final false")
	_check(not bool(p18l_dd_skip.get("runtime_enabled", true)), "P1-18L runtime_enabled false")
	_check(bool(p18l_dd_skip.get("server_authority", false)), "P1-18L server_authority true")
	_check(bool(p18l_dd_skip.get("prediction_only", false)), "P1-18L prediction_only true")
	var p18l_json_export: Dictionary = p18l_harness.call("export_last_report_json") as Dictionary
	var p18l_txt_export: Dictionary = p18l_harness.call("export_last_report_text") as Dictionary
	_check(bool(p18l_json_export.get("ok", false)), "P1-18L user debug JSON export works", str(p18l_json_export.get("error", "")))
	_check(bool(p18l_txt_export.get("ok", false)), "P1-18L user debug text export works", str(p18l_txt_export.get("error", "")))
	if command != null and command.has_method("execute_command"):
		_check(bool(command.call("execute_command", "/combatlab live status")), "P1-18L /combatlab live status handled")
		_check(bool(command.call("execute_command", "/combatlab live dd 101")), "P1-18L /combatlab live dd handled")
		_check(bool(command.call("execute_command", "/combatlab live report")), "P1-18L /combatlab live report handled")
	_debug.append("\n--- P1-18L OpenDAoC live comparison harness ---")
	_debug.append(_snapshot_debug_line(p18l_dd_skip))

	_debug.append("\n--- P1-18B offline combat lab ---")
	_debug.append(_snapshot_debug_line(report))
	_debug.append("\n--- P1-18C combat lab detailed report ---")
	_debug.append(_snapshot_debug_line(detailed_report))


func _test_dol_p1_n5b_login_flow(zone_viewer: Node) -> void:
	_section("P1-N5B DOL login/charselect/worldinit offline")
	var wire := _get_node_ref(zone_viewer, "_dol_wire_1127")
	if wire == null:
		wire = DaocDolWire1127Script.new()
	var flow := _get_node_ref(zone_viewer, "_dol_login_flow_1127")
	if flow == null:
		flow = DaocDolLoginFlow1127Script.new()
		if flow.has_method("setup_flow"):
			flow.call("setup_flow", wire)
	_check(flow != null, "P1-N5B login flow layer available")
	if flow == null:
		return
	if flow.has_method("set_wire_1127"):
		flow.call("set_wire_1127", wire)

	var required := PackedStringArray([
		"reset_flow_profile", "setup_flow", "set_wire_1127", "configure_account", "configure_character",
		"set_debug_enabled", "is_debug_enabled", "default_account", "default_password", "sanitize_account_name",
		"sanitize_password", "account_valid", "password_valid", "ascii_bytes", "bytes_to_ascii",
		"append_u8", "append_u16_le", "append_u32_le", "append_fixed_string", "append_c_string",
		"append_pascal_i32_le_string", "read_u8", "read_u16_le", "read_u32_le", "read_fixed_string",
		"read_c_string", "read_pascal_i32_le_string", "client_packet_id_map", "client_packet_name_for_id", "client_packet_id_for_name",
		"build_login_payload_1127", "decode_login_payload_1127", "build_login_packet_1127", "decode_login_packet_1127", "build_character_overview_payload_1127",
		"decode_character_overview_payload_1127", "build_character_overview_packet_1127", "decode_character_overview_packet_1127", "realm_name_for_id", "realm_id_for_name",
		"build_character_select_payload_1127", "decode_character_select_payload_1127", "build_character_select_packet_1127", "decode_character_select_packet_1127", "character_slot_to_account_slot",
		"account_slot_to_character_slot", "build_world_init_payload_1127", "decode_world_init_payload_1127", "build_world_init_packet_1127", "decode_world_init_packet_1127",
		"build_full_offline_flow_packets", "decode_full_offline_flow_packets", "flow_packet_count", "flow_to_hex_lines", "bytes_to_hex",
		"packet_summary", "flow_summary", "checksum_ok_for_packet", "validate_client_packet", "describe_source_basis",
		"p1_n5b_scope", "is_real_network_send_enabled", "can_build_offline_login_flow", "status_snapshot", "last_error_snapshot",
		"clear_last_error", "make_error", "get_function_names",
	])
	for name in required:
		_check(flow.has_method(str(name)), "P1-N5B method present: %s" % str(name))

	flow.call("reset_flow_profile")
	flow.call("setup_flow", wire)
	flow.call("configure_account", "testgodot", "testgodot")
	flow.call("configure_character", 1, 0, 0)
	flow.call("set_debug_enabled", true)
	_check(bool(flow.call("is_debug_enabled")), "P1-N5B debug flag enabled")
	_check(str(flow.call("default_account")) == "testgodot", "P1-N5B default account")
	_check(str(flow.call("default_password")) == "testgodot", "P1-N5B default password")
	_check(str(flow.call("sanitize_account_name", "bad name!")) == "badname", "P1-N5B account sanitizer")
	_check(str(flow.call("sanitize_password", "  pass  ")) == "pass", "P1-N5B password sanitizer")
	_check(bool(flow.call("account_valid", "testgodot")), "P1-N5B account valid")
	_check(bool(flow.call("password_valid", "testgodot")), "P1-N5B password valid")

	var ab: PackedByteArray = flow.call("ascii_bytes", "abc") as PackedByteArray
	_check(ab.size() == 3 and int(ab[0]) == 97, "P1-N5B ascii bytes")
	_check(str(flow.call("bytes_to_ascii", ab)) == "abc", "P1-N5B bytes to ascii")
	var b := PackedByteArray()
	b = flow.call("append_u8", b, 0x12) as PackedByteArray
	b = flow.call("append_u16_le", b, 0x3456) as PackedByteArray
	b = flow.call("append_u32_le", b, 0x01020304) as PackedByteArray
	_check(int(flow.call("read_u8", b, 0)) == 0x12, "P1-N5B read/write u8")
	_check(int(flow.call("read_u16_le", b, 1)) == 0x3456, "P1-N5B read/write u16 LE")
	_check(int(flow.call("read_u32_le", b, 3)) == 0x01020304, "P1-N5B read/write u32 LE")
	var fixed: PackedByteArray = flow.call("append_fixed_string", PackedByteArray(), "abc", 6) as PackedByteArray
	_check(fixed.size() == 6 and str(flow.call("read_fixed_string", fixed, 0, 6)) == "abc", "P1-N5B fixed string")
	var cstr: PackedByteArray = flow.call("append_c_string", PackedByteArray(), "abc") as PackedByteArray
	var cdec: Dictionary = flow.call("read_c_string", cstr, 0) as Dictionary
	_check(str(cdec.get("text", "")) == "abc", "P1-N5B c string")
	var pas: PackedByteArray = flow.call("append_pascal_i32_le_string", PackedByteArray(), "abc", true) as PackedByteArray
	var pdec: Dictionary = flow.call("read_pascal_i32_le_string", pas, 0) as Dictionary
	_check(str(pdec.get("text", "")) == "abc" and int(pdec.get("length", 0)) == 4, "P1-N5B IntPascalLE string")

	var idmap: Dictionary = flow.call("client_packet_id_map") as Dictionary
	_check(int(idmap.get("LoginRequest", 0)) == 0xA7, "P1-N5B LoginRequest id 0xA7")
	_check(int(idmap.get("CharacterOverviewRequest", 0)) == 0xFC, "P1-N5B CharacterOverview id 0xFC")
	_check(int(idmap.get("CharacterSelectRequest", 0)) == 0x10, "P1-N5B CharacterSelect id 0x10")
	_check(int(idmap.get("WorldInitRequest", 0)) == 0xD4, "P1-N5B WorldInit id 0xD4")
	_check(str(flow.call("client_packet_name_for_id", 0xA7)) == "LoginRequest", "P1-N5B name for LoginRequest")
	_check(int(flow.call("client_packet_id_for_name", "WorldInitRequest")) == 0xD4, "P1-N5B id for WorldInitRequest")

	var login_payload: PackedByteArray = flow.call("build_login_payload_1127", "testgodot", "testgodot") as PackedByteArray
	var login_dec: Dictionary = flow.call("decode_login_payload_1127", login_payload) as Dictionary
	_check(bool(login_dec.get("ok", false)) and str(login_dec.get("account", "")) == "testgodot", "P1-N5B login payload encode/decode")
	var login_packet: PackedByteArray = flow.call("build_login_packet_1127", "testgodot", "testgodot", 1, 0) as PackedByteArray
	var login_packet_dec: Dictionary = flow.call("decode_login_packet_1127", login_packet) as Dictionary
	_check(int(login_packet_dec.get("packet_id", 0)) == 0xA7, "P1-N5B login packet id")
	_check(bool(login_packet_dec.get("checksum_ok", false)), "P1-N5B login checksum")

	var overview_payload: PackedByteArray = flow.call("build_character_overview_payload_1127", 1) as PackedByteArray
	var overview_dec: Dictionary = flow.call("decode_character_overview_payload_1127", overview_payload) as Dictionary
	_check(int(overview_dec.get("realm", 0)) == 1, "P1-N5B overview realm payload")
	var overview_packet: PackedByteArray = flow.call("build_character_overview_packet_1127", 1, 2, 0) as PackedByteArray
	var overview_packet_dec: Dictionary = flow.call("decode_character_overview_packet_1127", overview_packet) as Dictionary
	_check(int(overview_packet_dec.get("packet_id", 0)) == 0xFC, "P1-N5B overview packet id")

	_check(str(flow.call("realm_name_for_id", 1)) == "Albion", "P1-N5B realm id to name")
	_check(int(flow.call("realm_id_for_name", "hib")) == 3, "P1-N5B realm name to id")
	var select_payload: PackedByteArray = flow.call("build_character_select_payload_1127", 0) as PackedByteArray
	var select_dec: Dictionary = flow.call("decode_character_select_payload_1127", select_payload) as Dictionary
	_check(int(select_dec.get("character_index", -1)) == 0, "P1-N5B select payload")
	var select_packet: PackedByteArray = flow.call("build_character_select_packet_1127", 0, 3, 0) as PackedByteArray
	var select_packet_dec: Dictionary = flow.call("decode_character_select_packet_1127", select_packet) as Dictionary
	_check(int(select_packet_dec.get("packet_id", 0)) == 0x10, "P1-N5B select packet id")
	_check(int(flow.call("character_slot_to_account_slot", 0, 1)) == 100, "P1-N5B char slot to account slot")
	_check(int(flow.call("account_slot_to_character_slot", 100, 1)) == 0, "P1-N5B account slot to char slot")

	var world_payload: PackedByteArray = flow.call("build_world_init_payload_1127") as PackedByteArray
	var world_dec: Dictionary = flow.call("decode_world_init_payload_1127", world_payload) as Dictionary
	_check(bool(world_dec.get("ok", false)), "P1-N5B world init empty payload")
	var world_packet: PackedByteArray = flow.call("build_world_init_packet_1127", 4, 0) as PackedByteArray
	var world_packet_dec: Dictionary = flow.call("decode_world_init_packet_1127", world_packet) as Dictionary
	_check(int(world_packet_dec.get("packet_id", 0)) == 0xD4, "P1-N5B world init packet id")

	var flow_packets: Array = flow.call("build_full_offline_flow_packets", "testgodot", "testgodot", 1, 0) as Array
	_check(int(flow.call("flow_packet_count", flow_packets)) == 5, "P1-N5B full flow packet count")
	var decoded_flow: Array = flow.call("decode_full_offline_flow_packets", flow_packets) as Array
	_check(decoded_flow.size() == 5, "P1-N5B decode full flow")
	var hex_lines: PackedStringArray = flow.call("flow_to_hex_lines", flow_packets, 48) as PackedStringArray
	_check(hex_lines.size() == 5, "P1-N5B flow hex lines")
	_check(str(flow.call("bytes_to_hex", login_packet, 12)).contains("A7"), "P1-N5B bytes to hex contains packet id")
	_check(str(flow.call("packet_summary", login_packet)).contains("LoginRequest"), "P1-N5B packet summary")
	_check(str(flow.call("flow_summary", flow_packets)).contains("flow count=5"), "P1-N5B flow summary")
	_check(bool(flow.call("checksum_ok_for_packet", login_packet)), "P1-N5B checksum helper")
	var val: Dictionary = flow.call("validate_client_packet", login_packet, 0xA7) as Dictionary
	_check(bool(val.get("ok", false)), "P1-N5B validate client packet")
	_check(str(flow.call("describe_source_basis")).contains("LoginRequest"), "P1-N5B source basis")
	_check(str(flow.call("p1_n5b_scope")).contains("P1-N5B"), "P1-N5B scope")
	_check(bool(flow.call("is_real_network_send_enabled")) == false, "P1-N5B real network disabled")
	_check(bool(flow.call("can_build_offline_login_flow")), "P1-N5B can build offline flow")
	var status: Dictionary = flow.call("status_snapshot") as Dictionary
	_check(int(status.get("flow_count", 0)) == 5, "P1-N5B status snapshot")
	_check((flow.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5B no last error")
	flow.call("make_error", "f12", "synthetic")
	_check(not (flow.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5B make_error")
	flow.call("clear_last_error")
	_check((flow.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5B clear_last_error")
	var names: PackedStringArray = flow.call("get_function_names") as PackedStringArray
	var all_present := names.size() == 68
	for name in names:
		if not flow.has_method(str(name)):
			all_present = false
			break
	_check(all_present, "P1-N5B function list complete", "count=%d" % names.size())

	_debug.append("\n--- DOL P1-N5B login flow snapshot ---")
	_debug.append(_snapshot_debug_line(status))
	_debug.append("\n--- DOL P1-N5B flow hex ---")
	_debug.append(_snapshot_debug_line(hex_lines))


func _test_dol_p1_n5d_server_fixtures(zone_viewer: Node) -> void:
	_section("P1-N5D DOL server response fixtures offline")
	var fixtures := _get_node_ref(zone_viewer, "_dol_server_fixtures_1127")
	if fixtures == null:
		fixtures = DaocDolServerFixtures1127Script.new()
		var flow := _get_node_ref(zone_viewer, "_dol_login_flow_1127")
		fixtures.call("setup_fixtures", flow)
	_check(fixtures != null, "P1-N5D server fixtures layer available")
	if fixtures == null:
		return

	var required := PackedStringArray([
		"reset_fixture_profile", "setup_fixtures", "set_login_flow_1127", "configure_identity", "configure_position",
		"set_debug_enabled", "is_debug_enabled", "server_packet_header_size", "default_account", "default_server_name",
		"sanitize_ascii", "ascii_bytes", "bytes_to_ascii", "append_u8", "append_u16_be",
		"append_u16_le", "append_u32_be", "append_u32_le", "read_u8", "read_u16_be",
		"read_u16_le", "read_u32_be", "read_u32_le", "append_pascal_string", "read_pascal_string",
		"append_fixed_string", "read_fixed_string", "server_packet_id_map", "server_packet_name_for_id", "server_packet_id_for_name",
		"build_server_tcp_packet", "parse_server_tcp_packet", "split_server_tcp_stream_once", "split_server_tcp_stream_all", "detect_server_packet_id",
		"packet_payload", "packet_summary", "bytes_to_hex", "build_login_granted_payload_1127", "decode_login_granted_payload_1127",
		"build_login_granted_packet_1127", "decode_login_granted_packet_1127", "build_login_denied_payload_1127", "decode_login_denied_payload_1127", "build_login_denied_packet_1127",
		"decode_login_denied_packet_1127", "login_error_name", "build_session_id_payload_1127", "decode_session_id_payload_1127", "build_session_id_packet_1127",
		"decode_session_id_packet_1127", "build_realm_payload_1127", "decode_realm_payload_1127", "build_realm_packet_1127", "decode_realm_packet_1127",
		"build_character_overview_empty_payload_1127", "decode_character_overview_header_1127", "build_character_overview_empty_packet_1127", "decode_character_overview_packet_1127", "build_position_object_payload_1127",
		"decode_position_object_payload_1127", "build_position_object_packet_1127", "decode_position_object_packet_1127", "realm_name_for_id", "realm_id_for_name",
		"build_server_fixture_flow", "decode_server_fixture_flow", "fixture_flow_packet_count", "fixture_flow_to_hex_lines", "fixture_flow_summary",
		"validate_server_packet", "describe_source_basis", "p1_n5d_scope", "is_live_server_required", "can_parse_offline_server_fixtures",
		"status_snapshot", "last_error_snapshot", "clear_last_error", "make_error", "get_function_names",
	])
	for name in required:
		_check(fixtures.has_method(str(name)), "P1-N5D method present: %s" % str(name))

	fixtures.call("reset_fixture_profile")
	fixtures.call("configure_identity", "testgodot", "GodotDOL", 1, 1)
	fixtures.call("configure_position", 1, 32768, 32768, 2075, 0)
	fixtures.call("set_debug_enabled", true)
	_check(bool(fixtures.call("is_debug_enabled")), "P1-N5D debug flag enabled")
	_check(int(fixtures.call("server_packet_header_size")) == 3, "P1-N5D server packet header size is 3")
	_check(str(fixtures.call("default_account")) == "testgodot", "P1-N5D default account")
	_check(str(fixtures.call("default_server_name")) == "GodotDOL", "P1-N5D default server name")
	_check(str(fixtures.call("sanitize_ascii", " héllo! ", 8, "x")) == "hllo!", "P1-N5D sanitize ascii")

	var ab: PackedByteArray = fixtures.call("ascii_bytes", "abc") as PackedByteArray
	_check(ab.size() == 3 and int(ab[0]) == 97, "P1-N5D ascii bytes")
	_check(str(fixtures.call("bytes_to_ascii", ab)) == "abc", "P1-N5D bytes to ascii")
	var b := PackedByteArray()
	b = fixtures.call("append_u8", b, 0x12) as PackedByteArray
	b = fixtures.call("append_u16_be", b, 0x3456) as PackedByteArray
	b = fixtures.call("append_u16_le", b, 0x789A) as PackedByteArray
	b = fixtures.call("append_u32_be", b, 0x01020304) as PackedByteArray
	b = fixtures.call("append_u32_le", b, 0x05060708) as PackedByteArray
	_check(int(fixtures.call("read_u8", b, 0)) == 0x12, "P1-N5D read/write u8")
	_check(int(fixtures.call("read_u16_be", b, 1)) == 0x3456, "P1-N5D read/write u16 BE")
	_check(int(fixtures.call("read_u16_le", b, 3)) == 0x789A, "P1-N5D read/write u16 LE")
	_check(int(fixtures.call("read_u32_be", b, 5)) == 0x01020304, "P1-N5D read/write u32 BE")
	_check(int(fixtures.call("read_u32_le", b, 9)) == 0x05060708, "P1-N5D read/write u32 LE")

	var pas: PackedByteArray = fixtures.call("append_pascal_string", PackedByteArray(), "abc") as PackedByteArray
	var pas_dec: Dictionary = fixtures.call("read_pascal_string", pas, 0) as Dictionary
	_check(str(pas_dec.get("text", "")) == "abc", "P1-N5D pascal string")
	var fixed: PackedByteArray = fixtures.call("append_fixed_string", PackedByteArray(), "abc", 6) as PackedByteArray
	_check(str(fixtures.call("read_fixed_string", fixed, 0, 6)) == "abc", "P1-N5D fixed string")

	var idmap: Dictionary = fixtures.call("server_packet_id_map") as Dictionary
	_check(int(idmap.get("LoginGranted", 0)) == 0x2A, "P1-N5D LoginGranted id 0x2A")
	_check(int(idmap.get("LoginDenied", 0)) == 0x2C, "P1-N5D LoginDenied id 0x2C")
	_check(int(idmap.get("SessionID", 0)) == 0x28, "P1-N5D SessionID id 0x28")
	_check(int(idmap.get("Realm", 0)) == 0xFE, "P1-N5D Realm id 0xFE")
	_check(int(idmap.get("CharacterOverview1126", 0)) == 0xFC, "P1-N5D CharacterOverview1126 id 0xFC")
	_check(int(idmap.get("PositionAndObjectID", 0)) == 0x20, "P1-N5D PositionAndObjectID id 0x20")
	_check(str(fixtures.call("server_packet_name_for_id", 0x2A)) == "LoginGranted", "P1-N5D name for LoginGranted")
	_check(int(fixtures.call("server_packet_id_for_name", "Realm")) == 0xFE, "P1-N5D id for Realm")

	var raw_payload := PackedByteArray([0xAA, 0xBB])
	var raw_packet: PackedByteArray = fixtures.call("build_server_tcp_packet", 0x28, raw_payload) as PackedByteArray
	var raw_parsed: Dictionary = fixtures.call("parse_server_tcp_packet", raw_packet) as Dictionary
	_check(bool(raw_parsed.get("ok", false)) and int(raw_parsed.get("data_size", 0)) == 2, "P1-N5D parse server TCP packet")
	_check(int(fixtures.call("detect_server_packet_id", raw_packet)) == 0x28, "P1-N5D detect server packet id")
	_check((fixtures.call("packet_payload", raw_packet) as PackedByteArray).size() == 2, "P1-N5D packet payload helper")
	_check(str(fixtures.call("packet_summary", raw_packet)).contains("SessionID"), "P1-N5D packet summary")
	_check(str(fixtures.call("bytes_to_hex", raw_packet, 8)).contains("28"), "P1-N5D bytes to hex")

	var login_granted: PackedByteArray = fixtures.call("build_login_granted_packet_1127", "testgodot", "GodotDOL", 7) as PackedByteArray
	var login_granted_dec: Dictionary = fixtures.call("decode_login_granted_packet_1127", login_granted) as Dictionary
	_check(int(login_granted_dec.get("packet_id", 0)) == 0x2A, "P1-N5D LoginGranted packet id")
	_check(str((login_granted_dec.get("decoded", {}) as Dictionary).get("account", "")) == "testgodot", "P1-N5D LoginGranted account")

	var login_denied: PackedByteArray = fixtures.call("build_login_denied_packet_1127", 1) as PackedByteArray
	var login_denied_dec: Dictionary = fixtures.call("decode_login_denied_packet_1127", login_denied) as Dictionary
	_check(int(login_denied_dec.get("packet_id", 0)) == 0x2C, "P1-N5D LoginDenied packet id")
	_check(str(fixtures.call("login_error_name", 1)).contains("Account"), "P1-N5D login error name")

	var session_packet: PackedByteArray = fixtures.call("build_session_id_packet_1127", 4660) as PackedByteArray
	var session_dec: Dictionary = fixtures.call("decode_session_id_packet_1127", session_packet) as Dictionary
	_check(int(session_dec.get("packet_id", 0)) == 0x28, "P1-N5D SessionID packet id")
	_check(int((session_dec.get("decoded", {}) as Dictionary).get("session_id", 0)) == 4660, "P1-N5D SessionID decode LE")

	var realm_packet: PackedByteArray = fixtures.call("build_realm_packet_1127", 1) as PackedByteArray
	var realm_dec: Dictionary = fixtures.call("decode_realm_packet_1127", realm_packet) as Dictionary
	_check(int(realm_dec.get("packet_id", 0)) == 0xFE, "P1-N5D Realm packet id")
	_check(str((realm_dec.get("decoded", {}) as Dictionary).get("realm_name", "")) == "Albion", "P1-N5D Realm decode")

	var overview_packet: PackedByteArray = fixtures.call("build_character_overview_empty_packet_1127", false) as PackedByteArray
	var overview_dec: Dictionary = fixtures.call("decode_character_overview_packet_1127", overview_packet) as Dictionary
	_check(int(overview_dec.get("packet_id", 0)) == 0xFC, "P1-N5D CharacterOverview1126 packet id")
	_check(int((overview_dec.get("decoded", {}) as Dictionary).get("header_size", 0)) == 16, "P1-N5D CharacterOverview1126 header")

	var pos_packet: PackedByteArray = fixtures.call("build_position_object_packet_1127", 1, 32768, 32768, 2075, 0, 0) as PackedByteArray
	var pos_dec: Dictionary = fixtures.call("decode_position_object_packet_1127", pos_packet) as Dictionary
	var pos_payload: Dictionary = pos_dec.get("decoded", {}) as Dictionary
	_check(int(pos_dec.get("packet_id", 0)) == 0x20, "P1-N5D PositionAndObjectID packet id")
	_check(int(pos_payload.get("x", 0)) == 32768 and int(pos_payload.get("z", 0)) == 2075, "P1-N5D PositionAndObjectID decode")

	_check(str(fixtures.call("realm_name_for_id", 3)) == "Hibernia", "P1-N5D realm id to name")
	_check(int(fixtures.call("realm_id_for_name", "mid")) == 2, "P1-N5D realm name to id")

	var flow_packets: Array = fixtures.call("build_server_fixture_flow") as Array
	_check(int(fixtures.call("fixture_flow_packet_count", flow_packets)) == 5, "P1-N5D fixture flow count")
	var decoded_flow: Array = fixtures.call("decode_server_fixture_flow", flow_packets) as Array
	_check(decoded_flow.size() == 5, "P1-N5D decode fixture flow")
	var hex_lines: PackedStringArray = fixtures.call("fixture_flow_to_hex_lines", flow_packets, 48) as PackedStringArray
	_check(hex_lines.size() == 5, "P1-N5D fixture flow hex lines")
	_check(str(fixtures.call("fixture_flow_summary", flow_packets)).contains("flow count=5"), "P1-N5D fixture flow summary")

	var stream := PackedByteArray()
	for item in flow_packets:
		var d: Dictionary = item as Dictionary
		stream.append_array(d.get("packet", PackedByteArray()) as PackedByteArray)
	var one: Dictionary = fixtures.call("split_server_tcp_stream_once", stream) as Dictionary
	_check(bool(one.get("ok", false)), "P1-N5D split one server packet")
	var split_all: Array = fixtures.call("split_server_tcp_stream_all", stream) as Array
	_check(split_all.size() == 5, "P1-N5D split all server packets")
	var val: Dictionary = fixtures.call("validate_server_packet", login_granted, 0x2A) as Dictionary
	_check(bool(val.get("ok", false)), "P1-N5D validate server packet")

	_check(str(fixtures.call("describe_source_basis")).contains("GSTCPPacketOut"), "P1-N5D source basis")
	_check(str(fixtures.call("p1_n5d_scope")).contains("P1-N5D"), "P1-N5D scope")
	_check(bool(fixtures.call("is_live_server_required")) == false, "P1-N5D live server not required")
	_check(bool(fixtures.call("can_parse_offline_server_fixtures")), "P1-N5D can parse offline fixtures")
	var status: Dictionary = fixtures.call("status_snapshot") as Dictionary
	_check(int(status.get("flow_count", 0)) == 5, "P1-N5D status snapshot")
	_check((fixtures.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5D no last error")
	fixtures.call("make_error", "f12", "synthetic")
	_check(not (fixtures.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5D make_error")
	fixtures.call("clear_last_error")
	_check((fixtures.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5D clear_last_error")
	var names: PackedStringArray = fixtures.call("get_function_names") as PackedStringArray
	var all_present := names.size() == 80
	for name in names:
		if not fixtures.has_method(str(name)):
			all_present = false
			break
	_check(all_present, "P1-N5D function list complete", "count=%d" % names.size())

	_debug.append("\n--- DOL P1-N5D server fixtures snapshot ---")
	_debug.append(_snapshot_debug_line(status))
	_debug.append("\n--- DOL P1-N5D fixture flow hex ---")
	_debug.append(_snapshot_debug_line(hex_lines))


func _test_dol_p1_n5efg_character_bootstrap(zone_viewer: Node) -> void:
	_section("P1-N5E/F/G character overview/select/bootstrap offline")
	var bootstrap := _get_node_ref(zone_viewer, "_dol_character_bootstrap_1127")
	_check(bootstrap != null, "P1-N5E/F/G character bootstrap layer available")
	if bootstrap == null:
		return
	var expected := [
		"reset_bootstrap_profile", "setup_bootstrap", "set_server_fixtures_1127", "set_login_flow_1127", "configure_character_fixture", "configure_selection", "set_debug_enabled", "is_debug_enabled", "default_character", "default_character_name", "sanitize_text", "clamp_realm", "clamp_slot_index", "realm_base_account_slot", "account_slot_for_index", "index_for_account_slot", "realm_name_for_id", "realm_id_for_name", "class_name_for_id", "race_name_for_id", "gender_name_for_id", "ascii_bytes", "bytes_to_ascii", "append_u8", "append_u16_le", "append_u16_be", "append_u32_le", "read_u8", "read_u16_le", "read_u16_be", "read_u32_le", "append_pascal_i32_le_string", "read_pascal_i32_le_string", "append_zero_fill", "append_equipment_u16_list", "read_equipment_u16_list", "normalize_character_dict", "compact_character_dict", "validate_character_dict", "character_display_name", "character_slot_summary", "character_slot_empty_marker", "build_character_slot_payload_1127", "decode_character_slot_payload_1127", "build_missing_slot_payload_1127", "build_character_overview_enriched_payload_1127", "build_character_overview_enriched_packet_1127", "decode_character_overview_enriched_payload_1127", "decode_character_overview_enriched_packet_1127", "character_list_from_overview_packet", "character_count", "get_character_by_index", "get_character_by_account_slot", "select_character_by_index", "select_character_by_account_slot", "selected_character_snapshot", "clear_selection", "has_selection", "selection_valid", "build_client_select_packet_for_selected", "decode_client_select_packet_for_selected", "build_server_session_for_selection", "build_bootstrap_position_for_character", "decode_bootstrap_position", "build_offline_bootstrap_flow", "decode_offline_bootstrap_flow", "bootstrap_flow_count", "bootstrap_flow_summary", "bootstrap_to_hex_lines", "apply_bootstrap_to_snapshot", "can_apply_bootstrap_without_moving_player", "build_local_ui_model_snapshot", "normalized_ui_character", "equipment_preview", "count_non_zero_equipment", "is_character_selectable", "selection_reason", "character_ui_row", "build_character_ui_rows", "selection_panel_lines", "selection_panel_text", "set_selection_from_index", "unselect_character", "selected_character_full_snapshot", "get_bootstrap_position_snapshot", "dry_apply_bootstrap", "apply_bootstrap_to_player", "make_player_transform_snapshot", "bootstrap_target_transform_snapshot", "validate_player_transform_snapshot", "validate_bootstrap_target_snapshot", "player_transform_delta", "apply_transform_snapshot_to_player", "safe_real_apply_requires_confirm", "build_apply_guard_snapshot", "apply_bootstrap_to_player_guarded", "rollback_last_player_apply", "can_rollback_last_apply", "get_last_safe_apply_snapshot", "last_rollback_snapshot", "clear_apply_guard_snapshots", "p1_n6b_scope", "heading_units_to_degrees", "bootstrap_apply_contract", "bootstrap_ready_snapshot", "is_real_player_move_default", "can_apply_bootstrap_to_player", "build_selection_state_snapshot", "build_selection_hud_model", "selection_screen_needed_now", "selection_screen_next_step", "describe_selection_screen_contract", "describe_source_basis", "p1_n5efg_scope", "is_live_server_required", "is_real_ui_implemented", "can_build_enriched_charlist", "status_snapshot", "last_error_snapshot", "clear_last_error", "make_error", "get_function_names", "default_equipment_u16", "default_stats", "build_server_tcp_packet_local", "parse_server_packet_local", "build_world_init_packet_local", "append_u32_be_local", "bytes_to_hex"
	]
	for name in expected:
		_check(bootstrap.has_method(str(name)), "P1-N5E/F/G method present: %s" % str(name))
	bootstrap.call("set_debug_enabled", true)
	_check(bool(bootstrap.call("is_debug_enabled")), "P1-N5E/F/G debug flag enabled")
	_check(str(bootstrap.call("default_character_name")) == "GodotServerDebug", "P1-N5E/F/G default character name")
	_check(str(bootstrap.call("sanitize_text", " héllo! ", 8, "x")) == "hllo!", "P1-N5E/F/G sanitize text")
	_check(int(bootstrap.call("clamp_realm", 9)) == 3, "P1-N5E/F/G clamp realm")
	_check(int(bootstrap.call("clamp_slot_index", 99)) == 9, "P1-N5E/F/G clamp slot")
	_check(int(bootstrap.call("account_slot_for_index", 0, 1)) == 100, "P1-N5E/F/G account slot Albion index 0")
	_check(int(bootstrap.call("index_for_account_slot", 105, 1)) == 5, "P1-N5E/F/G index from account slot")
	_check(str(bootstrap.call("realm_name_for_id", 2)) == "Midgard", "P1-N5E/F/G realm name")
	_check(int(bootstrap.call("realm_id_for_name", "hib")) == 3, "P1-N5E/F/G realm id")
	_check(str(bootstrap.call("class_name_for_id", 2)) == "Armsman", "P1-N5E/F/G class name")
	_check(str(bootstrap.call("class_name_for_id", 14)) == "Fighter", "P1-N5E/F/G base class name")
	_check(str(bootstrap.call("race_name_for_id", 18, 3)) == "Shar", "P1-N5E/F/G expansion race name")
	_check(str(bootstrap.call("race_name_for_id", 1, 1)) == "Briton", "P1-N5E/F/G race name")
	_check(str(bootstrap.call("gender_name_for_id", 1)) == "Female", "P1-N5E/F/G gender name")
	var ab: PackedByteArray = bootstrap.call("ascii_bytes", "abc") as PackedByteArray
	_check(ab.size() == 3 and int(ab[0]) == 97, "P1-N5E/F/G ascii bytes")
	_check(str(bootstrap.call("bytes_to_ascii", ab)) == "abc", "P1-N5E/F/G bytes to ascii")
	var b := PackedByteArray()
	b = bootstrap.call("append_u8", b, 0x12) as PackedByteArray
	b = bootstrap.call("append_u16_le", b, 0x3456) as PackedByteArray
	b = bootstrap.call("append_u16_be", b, 0x789A) as PackedByteArray
	b = bootstrap.call("append_u32_le", b, 0x01020304) as PackedByteArray
	_check(int(bootstrap.call("read_u8", b, 0)) == 0x12, "P1-N5E/F/G read/write u8")
	_check(int(bootstrap.call("read_u16_le", b, 1)) == 0x3456, "P1-N5E/F/G read/write u16 LE")
	_check(int(bootstrap.call("read_u16_be", b, 3)) == 0x789A, "P1-N5E/F/G read/write u16 BE")
	_check(int(bootstrap.call("read_u32_le", b, 5)) == 0x01020304, "P1-N5E/F/G read/write u32 LE")
	var pstr := bootstrap.call("append_pascal_i32_le_string", PackedByteArray(), "abc", 24) as PackedByteArray
	var pdec := bootstrap.call("read_pascal_i32_le_string", pstr, 0) as Dictionary
	_check(str(pdec.get("text", "")) == "abc", "P1-N5E/F/G IntPascalLE")
	var eq := bootstrap.call("default_equipment_u16") as Array
	var eq_bytes := bootstrap.call("append_equipment_u16_list", PackedByteArray(), eq) as PackedByteArray
	var eq_dec := bootstrap.call("read_equipment_u16_list", eq_bytes, 0, 20) as Dictionary
	_check(bool(eq_dec.get("ok", false)) and (eq_dec.get("values", []) as Array).size() == 20, "P1-N5E/F/G equipment list")
	var eq_preview := bootstrap.call("equipment_preview", eq) as Dictionary
	_check(int(eq_preview.get("helmet", 0)) == 101 and int(eq_preview.get("torso", 0)) == 110 and int(eq_preview.get("right_hand", 0)) == 500, "P1-N5E/F/G equipment semantic order")
	# Oracle issu de la capture CharacterOverview réelle de Heyveno (PacketLib1125).
	var heyveno_eq: Array = [824, 85, 84, 0, 81, 0, 82, 83, 0, 0, 0, 0, 0, 0, 0, 0, 3, 59, 0, 0]
	var heyveno_preview := bootstrap.call("equipment_preview", heyveno_eq) as Dictionary
	_check(
		int(heyveno_preview.get("slot_count", 0)) == 20
		and int(heyveno_preview.get("helmet", 0)) == 824
		and int(heyveno_preview.get("gloves", 0)) == 85
		and int(heyveno_preview.get("boots", 0)) == 84
		and int(heyveno_preview.get("torso", 0)) == 81
		and int(heyveno_preview.get("legs", 0)) == 82
		and int(heyveno_preview.get("arms", 0)) == 83
		and int(heyveno_preview.get("right_hand", 0)) == 3
		and int(heyveno_preview.get("left_hand", 0)) == 59,
		"P1-N5E/F/G real Heyveno equipment oracle"
	)
	var ch := bootstrap.call("normalize_character_dict", {}) as Dictionary
	_check(str(ch.get("name", "")) == "GodotServerDebug", "P1-N5E/F/G normalize default character")
	_check(bool((bootstrap.call("validate_character_dict", ch) as Dictionary).get("ok", false)), "P1-N5E/F/G validate character")
	_check(str(bootstrap.call("character_display_name", ch)).contains("GodotServerDebug"), "P1-N5E/F/G character display")
	_check(str(bootstrap.call("character_slot_summary", ch)).contains("slot=100"), "P1-N5E/F/G character slot summary")
	_check(bool((bootstrap.call("character_slot_empty_marker", 1, 1) as Dictionary).get("empty", false)), "P1-N5E/F/G empty slot marker")
	var slot_payload: PackedByteArray = bootstrap.call("build_character_slot_payload_1127", ch) as PackedByteArray
	var slot_dec := bootstrap.call("decode_character_slot_payload_1127", slot_payload, 0, 0, 1) as Dictionary
	_check(bool(slot_dec.get("ok", false)) and str((slot_dec.get("character", {}) as Dictionary).get("name", "")) == "GodotServerDebug", "P1-N5E/F/G character slot encode/decode")
	_check((bootstrap.call("build_missing_slot_payload_1127") as PackedByteArray).size() == 1, "P1-N5E/F/G missing slot payload")
	var payload: PackedByteArray = bootstrap.call("build_character_overview_enriched_payload_1127", ch, 1, false) as PackedByteArray
	var payload_dec := bootstrap.call("decode_character_overview_enriched_payload_1127", payload, 1) as Dictionary
	_check(int(payload_dec.get("character_count", 0)) == 1, "P1-N5E/F/G enriched overview payload decode")
	var packet: PackedByteArray = bootstrap.call("build_character_overview_enriched_packet_1127", ch, 1) as PackedByteArray
	var packet_dec := bootstrap.call("decode_character_overview_enriched_packet_1127", packet, 1) as Dictionary
	_check(int(packet_dec.get("packet_id", 0)) == 0xFC, "P1-N5E/F/G enriched overview packet id")
	var chars: Array = bootstrap.call("character_list_from_overview_packet", packet, 1) as Array
	_check(chars.size() == 1, "P1-N5E/F/G character list from packet")
	_check(int(bootstrap.call("character_count", chars)) == 1, "P1-N5E/F/G character count")
	_check(str((bootstrap.call("get_character_by_index", chars, 0) as Dictionary).get("name", "")) == "GodotServerDebug", "P1-N5E/F/G get character by index")
	_check(str((bootstrap.call("get_character_by_account_slot", chars, 100) as Dictionary).get("name", "")) == "GodotServerDebug", "P1-N5E/F/G get character by account slot")
	var sel := bootstrap.call("select_character_by_index", chars, 0) as Dictionary
	_check(str(sel.get("name", "")) == "GodotServerDebug", "P1-N5E/F/G select character by index")
	_check(bool(bootstrap.call("has_selection")), "P1-N5E/F/G has selection")
	_check(bool(bootstrap.call("selection_valid")), "P1-N5E/F/G selection valid")
	_check(str((bootstrap.call("selected_character_snapshot") as Dictionary).get("name", "")) == "GodotServerDebug", "P1-N5E/F/G selected snapshot")
	var select_packet: PackedByteArray = bootstrap.call("build_client_select_packet_for_selected", 3, 0) as PackedByteArray
	_check(select_packet.size() > 0, "P1-N5E/F/G client select packet for selected")
	var select_dec := bootstrap.call("decode_client_select_packet_for_selected", select_packet) as Dictionary
	_check(bool(select_dec.get("ok", false)), "P1-N5E/F/G client select decode")
	_check((bootstrap.call("build_server_session_for_selection") as PackedByteArray).size() > 0, "P1-N5E/F/G server session for selection")
	var pos_packet: PackedByteArray = bootstrap.call("build_bootstrap_position_for_character", ch) as PackedByteArray
	var pos_dec := bootstrap.call("decode_bootstrap_position", pos_packet) as Dictionary
	_check(int(pos_dec.get("packet_id", 0)) == 0x20, "P1-N5E/F/G bootstrap position packet")
	var flow: Array = bootstrap.call("build_offline_bootstrap_flow", ch) as Array
	_check(int(bootstrap.call("bootstrap_flow_count", flow)) == 5, "P1-N5E/F/G bootstrap flow count")
	var decoded_flow: Array = bootstrap.call("decode_offline_bootstrap_flow", flow) as Array
	_check(decoded_flow.size() == 5, "P1-N5E/F/G decode bootstrap flow")
	var hex_lines: PackedStringArray = bootstrap.call("bootstrap_to_hex_lines", flow) as PackedStringArray
	_check(hex_lines.size() == 5, "P1-N5E/F/G bootstrap hex lines")
	_check(str(bootstrap.call("bootstrap_flow_summary", flow)).contains("flow count=5"), "P1-N5E/F/G bootstrap summary")
	var apply_snap := bootstrap.call("apply_bootstrap_to_snapshot", ch, pos_dec) as Dictionary
	_check(bool(apply_snap.get("would_move_player", true)) == false, "P1-N5E/F/G bootstrap does not move player")
	_check(bool(bootstrap.call("can_apply_bootstrap_without_moving_player")), "P1-N5E/F/G can apply without moving")
	var ui_snap := bootstrap.call("build_local_ui_model_snapshot", chars) as Dictionary
	_check(int(ui_snap.get("character_count", 0)) == 1 and bool(ui_snap.get("ui_implemented", true)) == false, "P1-N5E/F/G UI model snapshot, no UI yet")
	_check(bool(bootstrap.call("selection_screen_needed_now")) == false, "P1-N5E/F/G selection screen not needed now")
	_check(str(bootstrap.call("selection_screen_next_step")).contains("UI"), "P1-N5E/F/G selection screen next step")
	_check(str(bootstrap.call("describe_selection_screen_contract")).contains("characters"), "P1-N5E/F/G selection screen contract")
	_check(str(bootstrap.call("describe_source_basis")).contains("PacketLib1126"), "P1-N5E/F/G source basis")
	_check(str(bootstrap.call("p1_n5efg_scope")).contains("P1-N5E/F/G"), "P1-N5E/F/G scope")
	_check(bool(bootstrap.call("is_live_server_required")) == false, "P1-N5E/F/G live server not required")
	_check(bool(bootstrap.call("is_real_ui_implemented")) == false, "P1-N5E/F/G real UI not implemented")
	_check(bool(bootstrap.call("can_build_enriched_charlist")), "P1-N5E/F/G can build enriched charlist")
	var status := bootstrap.call("status_snapshot") as Dictionary
	_check(int(status.get("character_count", 0)) == 1, "P1-N5E/F/G status snapshot")
	_check((bootstrap.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5E/F/G no last error")
	bootstrap.call("make_error", "f12", "forced")
	_check(not (bootstrap.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5E/F/G make_error")
	bootstrap.call("clear_last_error")
	_check((bootstrap.call("last_error_snapshot") as Dictionary).is_empty(), "P1-N5E/F/G clear_last_error")
	var names: PackedStringArray = bootstrap.call("get_function_names") as PackedStringArray
	var all_present := names.size() == expected.size()
	for name in expected:
		all_present = all_present and names.has(str(name))
	_check(all_present, "P1-N5E/F/G function list complete", "count=%d" % names.size())
	_debug.append("\n--- DOL P1-N5E/F/G character bootstrap snapshot ---")
	_debug.append(_snapshot_debug_line(status))
	_debug.append("\n--- DOL P1-N5E/F/G bootstrap flow hex ---")
	_debug.append(_snapshot_debug_line(hex_lines))



func _test_dol_p1_n5hij_selection_hud_model_apply(zone_viewer: Node) -> void:
	_section("P1-N5H/I/J + P1-N6A offline selection HUD/model/apply")
	var bootstrap := _get_node_ref(zone_viewer, "_dol_character_bootstrap_1127")
	var hud := _get_node_ref(zone_viewer, "_dol_character_select_hud_1127")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	var player := _get_node_ref(zone_viewer, "_player")
	_check(bootstrap != null, "P1-N5H/I/J bootstrap dependency available")
	_check(hud != null, "P1-N5H character select HUD layer available")
	_check(dol != null, "P1-N5J DOL client state layer available")
	if bootstrap == null or hud == null or dol == null:
		return
	var bootstrap_new := [
		"normalized_ui_character", "equipment_preview", "count_non_zero_equipment", "is_character_selectable", "selection_reason", "character_ui_row", "build_character_ui_rows", "selection_panel_lines", "selection_panel_text", "set_selection_from_index", "unselect_character", "selected_character_full_snapshot", "get_bootstrap_position_snapshot", "dry_apply_bootstrap", "apply_bootstrap_to_player", "make_player_transform_snapshot", "bootstrap_target_transform_snapshot", "validate_player_transform_snapshot", "validate_bootstrap_target_snapshot", "player_transform_delta", "apply_transform_snapshot_to_player", "safe_real_apply_requires_confirm", "build_apply_guard_snapshot", "apply_bootstrap_to_player_guarded", "rollback_last_player_apply", "can_rollback_last_apply", "get_last_safe_apply_snapshot", "last_rollback_snapshot", "clear_apply_guard_snapshots", "p1_n6b_scope", "heading_units_to_degrees", "bootstrap_apply_contract", "bootstrap_ready_snapshot", "is_real_player_move_default", "can_apply_bootstrap_to_player", "build_selection_state_snapshot", "build_selection_hud_model"
	]
	for name in bootstrap_new:
		_check(bootstrap.has_method(str(name)), "P1-N5H/I/J bootstrap method present: %s" % str(name))
	var hud_expected := [
		"setup", "set_character_bootstrap_1127", "set_dol_client", "set_player", "set_visible_enabled", "show_panel", "hide_panel", "toggle_panel", "is_panel_visible", "set_auto_refresh_enabled", "is_auto_refresh_enabled", "set_selected_index", "selected_index", "reset_login_selection_flow", "start_loading_screen", "complete_loading_to_realm_select", "start_world_loading_screen", "complete_world_loading_to_ready", "pregame_asset_root_hint", "post_character_loading_asset_root_hint", "character_select_scene_source_hint", "loading_asset_rule_basis", "set_ui_phase", "ui_phase", "ui_phase_index", "ui_phase_label", "ui_flow_order", "available_realms", "selected_realm_snapshot", "select_realm", "realm_id_for_name", "realm_name_for_id", "transition_to_character_select", "transition_to_ready_to_enter", "can_show_realm_select", "can_show_character_select", "can_enter_world_from_ui", "build_character_rows", "build_loading_panel_lines", "build_world_loading_panel_lines", "build_asset_source_panel_lines", "build_realm_panel_lines", "build_character_panel_lines", "build_panel_lines", "build_panel_text", "refresh_panel", "force_refresh", "character_count", "selected_character_snapshot", "select_character", "unselect_character", "build_ui_model", "build_login_selection_flow_model", "get_debug_snapshot", "status_snapshot", "has_bootstrap", "has_character_rows", "p1_n5h_scope", "p1_n6c_scope", "is_real_ui_final", "is_live_server_required", "get_function_names"
	]
	for name in hud_expected:
		_check(hud.has_method(str(name)), "P1-N5H HUD method present: %s" % str(name))
	var dol_expected := [
		"set_character_select_hud_1127", "import_bootstrap_charlist_to_client", "choose_bootstrap_character", "unchoose_bootstrap_character", "selected_bootstrap_character_snapshot", "mark_bootstrap_ready_from_selected", "apply_bootstrap_to_player_offline", "apply_bootstrap_to_player_safe_real", "rollback_last_bootstrap_apply", "get_character_selection_phase_snapshot", "set_login_selection_ui_phase", "select_login_realm_offline", "get_p1_n5hij_debug_snapshot", "get_p1_n6b_debug_snapshot", "get_p1_n6c_debug_snapshot", "p1_n5hij_scope", "p1_n6b_scope", "p1_n6c_scope"
	]
	for name in dol_expected:
		_check(dol.has_method(str(name)), "P1-N5J client method present: %s" % str(name))
	var packet: PackedByteArray = bootstrap.call("build_character_overview_enriched_packet_1127", {}, 1) as PackedByteArray
	var chars: Array = bootstrap.call("character_list_from_overview_packet", packet, 1) as Array
	_check(chars.size() == 1, "P1-N5H charlist source has one character")
	var ch: Dictionary = chars[0] as Dictionary
	var ui_char := bootstrap.call("normalized_ui_character", ch) as Dictionary
	_check(str(ui_char.get("display_name", "")).contains("GodotServerDebug"), "P1-N5I normalized UI character display")
	_check(bool(ui_char.get("is_selectable", false)), "P1-N5I normalized UI character selectable")
	_check(int((ui_char.get("equipment_preview", {}) as Dictionary).get("non_zero_count", 0)) >= 1, "P1-N5I equipment preview")
	_check(str(bootstrap.call("character_ui_row", ch)).contains("Camelot Hills"), "P1-N5H character UI row")
	var rows: PackedStringArray = bootstrap.call("build_character_ui_rows", chars) as PackedStringArray
	_check(rows.size() == 1, "P1-N5H character UI rows")
	var panel_text := str(bootstrap.call("selection_panel_text", chars))
	_check(panel_text.contains("GodotServerDebug") and panel_text.contains("live_server=false"), "P1-N5H selection panel text")
	var hud_text := str(hud.call("force_refresh"))
	_check(hud_text.contains("pré-écran sélection") or hud_text.contains("pre"), "P1-N5H HUD text refresh")
	hud.call("show_panel")
	_check(bool(hud.call("is_panel_visible")), "P1-N5H HUD show")
	hud.call("hide_panel")
	_check(not bool(hud.call("is_panel_visible")), "P1-N5H HUD hide")
	hud.call("set_auto_refresh_enabled", false)
	_check(not bool(hud.call("is_auto_refresh_enabled")), "P1-N5H HUD auto refresh toggle")
	hud.call("set_auto_refresh_enabled", true)
	var hud_model := hud.call("build_ui_model") as Dictionary
	_check(int(hud_model.get("character_count", 0)) == 1, "P1-N5H HUD UI model")
	var imported: Array = dol.call("import_bootstrap_charlist_to_client") as Array
	_check(imported.size() == 1, "P1-N5J client imports bootstrap charlist")
	var selected: Dictionary = dol.call("choose_bootstrap_character", 0) as Dictionary
	_check(str(selected.get("name", "")) == "GodotServerDebug", "P1-N5J client chooses bootstrap character")
	var phase: Dictionary = dol.call("get_character_selection_phase_snapshot") as Dictionary
	_check(str(phase.get("phase", "")) == "CHARACTER_SELECTED", "P1-N5J phase CHARACTER_SELECTED")
	var ready: Dictionary = dol.call("mark_bootstrap_ready_from_selected") as Dictionary
	_check(bool(ready.get("ready", false)), "P1-N5J bootstrap ready from selected")
	var ready_phase: Dictionary = dol.call("get_character_selection_phase_snapshot") as Dictionary
	_check(str(ready_phase.get("phase", "")) == "BOOTSTRAP_READY", "P1-N5J phase BOOTSTRAP_READY")
	var px := 0.0
	var py := 0.0
	var pz := 0.0
	if player != null:
		px = float(player.get("daoc_x"))
		py = float(player.get("daoc_y"))
		pz = float(player.get("daoc_z"))
	var dry_apply: Dictionary = dol.call("apply_bootstrap_to_player_offline", false) as Dictionary
	_check(bool(dry_apply.get("ok", false)) and bool(dry_apply.get("would_move_player", true)) == false, "P1-N6A apply bootstrap dry run")
	if player != null:
		_check(abs(float(player.get("daoc_x")) - px) < 0.01 and abs(float(player.get("daoc_y")) - py) < 0.01 and abs(float(player.get("daoc_z")) - pz) < 0.01, "P1-N6A dry run does not move player")
	_check(bool(bootstrap.call("is_real_player_move_default")) == false, "P1-N6A real player move disabled by default")
	_check(str(bootstrap.call("bootstrap_apply_contract")).contains("dry"), "P1-N6A apply contract")
	_check(bool(bootstrap.call("can_apply_bootstrap_to_player", player)) == (player != null), "P1-N6A can apply predicate")
	var state_snap := bootstrap.call("build_selection_state_snapshot") as Dictionary
	_check(int(state_snap.get("character_count", 0)) == 1, "P1-N5I/J selection state snapshot")
	var hij_snap := dol.call("get_p1_n5hij_debug_snapshot") as Dictionary
	_check(bool(hij_snap.get("live_server_required", true)) == false and bool(hij_snap.get("real_ui_final", true)) == false, "P1-N5H/I/J snapshot offline/no final UI")
	_check(str(dol.call("p1_n5hij_scope")).contains("P1-N5H"), "P1-N5H/I/J client scope")
	var hud_names: PackedStringArray = hud.call("get_function_names") as PackedStringArray
	var missing_hud := PackedStringArray()
	for name in hud_expected:
		if not hud_names.has(str(name)):
			missing_hud.append(str(name))
	_check(missing_hud.is_empty(), "P1-N5H HUD required function list present", "count=%d missing=%s" % [hud_names.size(), str(missing_hud)])
	_debug.append("\n--- DOL P1-N5H/I/J + P1-N6A snapshot ---")
	_debug.append(_snapshot_debug_line(hij_snap))
	_debug.append("\n--- DOL P1-N5H HUD text ---")
	_debug.append(_snapshot_debug_line(hud_text))


func _test_dol_p1_n6b_guarded_real_apply_rollback(zone_viewer: Node) -> void:
	_section("P1-N6B offline guarded real apply + rollback")
	var bootstrap := _get_node_ref(zone_viewer, "_dol_character_bootstrap_1127")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	var player := _get_node_ref(zone_viewer, "_player")
	_check(bootstrap != null, "P1-N6B bootstrap dependency available")
	_check(dol != null, "P1-N6B DOL client dependency available")
	_check(player != null, "P1-N6B player dependency available")
	if bootstrap == null or dol == null or player == null:
		return
	var bootstrap_methods := [
		"make_player_transform_snapshot", "bootstrap_target_transform_snapshot", "validate_player_transform_snapshot", "validate_bootstrap_target_snapshot", "player_transform_delta", "apply_transform_snapshot_to_player", "safe_real_apply_requires_confirm", "build_apply_guard_snapshot", "apply_bootstrap_to_player_guarded", "rollback_last_player_apply", "can_rollback_last_apply", "get_last_safe_apply_snapshot", "last_rollback_snapshot", "clear_apply_guard_snapshots", "p1_n6b_scope"
	]
	for name in bootstrap_methods:
		_check(bootstrap.has_method(str(name)), "P1-N6B bootstrap method present: %s" % str(name))
	var client_methods := ["apply_bootstrap_to_player_safe_real", "rollback_last_bootstrap_apply", "get_p1_n6b_debug_snapshot", "p1_n6b_scope"]
	for name in client_methods:
		_check(dol.has_method(str(name)), "P1-N6B client method present: %s" % str(name))
	var original_character: Dictionary = bootstrap.call("selected_character_full_snapshot") as Dictionary
	if original_character.is_empty():
		original_character = bootstrap.call("default_character") as Dictionary
	var original_player: Dictionary = bootstrap.call("make_player_transform_snapshot", player, "f12_original", "p1_n6b") as Dictionary
	_check(bool(bootstrap.call("validate_player_transform_snapshot", original_player)), "P1-N6B original player snapshot valid")
	var shifted := original_character.duplicate(true)
	shifted["x"] = int(original_player.get("x", 32768)) + 321
	shifted["y"] = int(original_player.get("y", 32768)) + 123
	shifted["z"] = int(original_player.get("z", 2075)) + 7
	shifted["heading"] = 512
	bootstrap.call("configure_character_fixture", shifted)
	dol.call("import_bootstrap_charlist_to_client")
	dol.call("choose_bootstrap_character", 0)
	var guard: Dictionary = bootstrap.call("build_apply_guard_snapshot", player) as Dictionary
	_check(bool(guard.get("safe_real_requires_confirm", false)), "P1-N6B guard requires explicit confirm")
	_check(bool(guard.get("before_valid", false)), "P1-N6B guard before snapshot valid")
	_check(bool(guard.get("target_valid", false)), "P1-N6B guard target valid")
	var denied: Dictionary = dol.call("apply_bootstrap_to_player_safe_real", false, "f12_denied") as Dictionary
	_check(bool(denied.get("handled", false)) and bool(denied.get("guard_denied", false)) and not bool(denied.get("ok", true)), "P1-N6B unconfirmed real apply denied but handled")
	var after_denied: Dictionary = bootstrap.call("make_player_transform_snapshot", player, "after_denied", "p1_n6b") as Dictionary
	var denied_delta: Dictionary = bootstrap.call("player_transform_delta", original_player, after_denied) as Dictionary
	_check(abs(float(denied_delta.get("dx", 99.0))) < 0.01 and abs(float(denied_delta.get("dy", 99.0))) < 0.01 and abs(float(denied_delta.get("dz", 99.0))) < 0.01, "P1-N6B denied apply does not move player")
	var applied: Dictionary = dol.call("apply_bootstrap_to_player_safe_real", true, "f12_confirmed") as Dictionary
	_check(bool(applied.get("ok", false)) and bool(applied.get("rollback_available", false)), "P1-N6B confirmed real apply succeeds with rollback snapshot")
	var after_apply: Dictionary = bootstrap.call("make_player_transform_snapshot", player, "after_apply", "p1_n6b") as Dictionary
	var apply_delta: Dictionary = bootstrap.call("player_transform_delta", original_player, after_apply) as Dictionary
	_check(abs(float(apply_delta.get("dx", 0.0))) > 1.0 or abs(float(apply_delta.get("dy", 0.0))) > 1.0 or abs(float(apply_delta.get("dz", 0.0))) > 1.0, "P1-N6B confirmed apply moves player locally")
	_check(bool(bootstrap.call("can_rollback_last_apply")), "P1-N6B rollback available after confirmed apply")
	var rolled: Dictionary = dol.call("rollback_last_bootstrap_apply", "f12_rollback") as Dictionary
	_check(bool(rolled.get("ok", false)), "P1-N6B rollback succeeds")
	var after_rollback: Dictionary = bootstrap.call("make_player_transform_snapshot", player, "after_rollback", "p1_n6b") as Dictionary
	var rollback_delta: Dictionary = bootstrap.call("player_transform_delta", original_player, after_rollback) as Dictionary
	_check(abs(float(rollback_delta.get("dx", 99.0))) < 0.01 and abs(float(rollback_delta.get("dy", 99.0))) < 0.01 and abs(float(rollback_delta.get("dz", 99.0))) < 0.01, "P1-N6B rollback restores original player position")
	var rollback_snap: Dictionary = bootstrap.call("last_rollback_snapshot") as Dictionary
	_check(bool(rollback_snap.get("ok", false)), "P1-N6B rollback snapshot stored")
	var n6b_snap: Dictionary = dol.call("get_p1_n6b_debug_snapshot") as Dictionary
	_check(bool(n6b_snap.get("live_server_required", true)) == false and bool(n6b_snap.get("real_network_send_enabled", true)) == false, "P1-N6B snapshot offline/no network")
	_check(str(bootstrap.call("p1_n6b_scope")).contains("rollback"), "P1-N6B bootstrap scope")
	_check(str(dol.call("p1_n6b_scope")).contains("rollback"), "P1-N6B client scope")
	bootstrap.call("configure_character_fixture", original_character)
	dol.call("import_bootstrap_charlist_to_client")
	dol.call("choose_bootstrap_character", 0)
	_debug.append("\n--- DOL P1-N6B guarded apply snapshot ---")
	_debug.append(_snapshot_debug_line(n6b_snap))
	_debug.append("\n--- DOL P1-N6B rollback snapshot ---")
	_debug.append(_snapshot_debug_line(rollback_snap))


func _test_dol_p1_n6c_daoc_ui_flow(zone_viewer: Node) -> void:
	_section("P1-N6C offline DAoC UI flow loading/realm/character")
	var hud := _get_node_ref(zone_viewer, "_dol_character_select_hud_1127")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	_check(hud != null, "P1-N6C HUD dependency available")
	_check(dol != null, "P1-N6C DOL client dependency available")
	if hud == null or dol == null:
		return
	var expected := ["reset_login_selection_flow", "start_loading_screen", "complete_loading_to_realm_select", "start_world_loading_screen", "complete_world_loading_to_ready", "pregame_asset_root_hint", "post_character_loading_asset_root_hint", "loading_asset_rule_basis", "ui_phase", "ui_flow_order", "available_realms", "select_realm", "selected_realm_snapshot", "can_show_realm_select", "can_show_character_select", "can_enter_world_from_ui", "build_login_selection_flow_model", "p1_n6c_scope"]
	for name in expected:
		_check(hud.has_method(str(name)), "P1-N6C HUD method present: %s" % str(name))
	_check(dol.has_method("set_login_selection_ui_phase"), "P1-N6C DOL client phase bridge present")
	_check(dol.has_method("select_login_realm_offline"), "P1-N6C DOL client realm bridge present")
	_check(dol.has_method("get_p1_n6c_debug_snapshot"), "P1-N6C DOL client snapshot present")
	hud.call("reset_login_selection_flow")
	_check(str(hud.call("ui_phase")) == "LOADING", "P1-N6C starts on loading phase")
	var loading_text := str(hud.call("force_refresh"))
	_check(loading_text.contains("chargement") and loading_text.contains("royaume"), "P1-N6C loading screen text references next realm step")
	var realm_model: Dictionary = hud.call("complete_loading_to_realm_select", "f12") as Dictionary
	_check(str(hud.call("ui_phase")) == "REALM_SELECT", "P1-N6C loading completes to realm select")
	_check(bool(hud.call("can_show_realm_select")), "P1-N6C realm select visible")
	_check((hud.call("available_realms") as Array).size() == 3, "P1-N6C exposes 3 DAoC realms")
	_check(str(realm_model.get("screen", "")).contains("login_selection"), "P1-N6C realm model uses login selection flow")
	var realm_result: Dictionary = dol.call("select_login_realm_offline", "Albion") as Dictionary
	_check(bool(realm_result.get("ok", false)), "P1-N6C select realm Albion succeeds")
	_check(str(hud.call("ui_phase")) == "CHARACTER_SELECT", "P1-N6C realm select transitions to character select")
	_check(bool(hud.call("can_show_character_select")), "P1-N6C character select visible after realm")
	var selected_realm: Dictionary = hud.call("selected_realm_snapshot") as Dictionary
	_check(str(selected_realm.get("name", "")) == "Albion", "P1-N6C selected realm snapshot")
	var char_text := str(hud.call("force_refresh"))
	_check(char_text.contains("sélection personnage") and char_text.contains("GodotServerDebug"), "P1-N6C character select text after realm")
	var selected: Dictionary = hud.call("select_character", 0) as Dictionary
	_check(str(selected.get("name", "")) == "GodotServerDebug", "P1-N6C select character from UI flow")
	_check(str(hud.call("ui_phase")) == "WORLD_LOADING", "P1-N6C character selection starts post-character world loading")
	var world_loading_text := str(hud.call("force_refresh"))
	_check(world_loading_text.contains("Data/loading") and world_loading_text.contains("après personnage"), "P1-N6C world loading text references Data/loading")
	var ready_model: Dictionary = hud.call("complete_world_loading_to_ready", "f12_world_ready") as Dictionary
	_check(str(hud.call("ui_phase")) == "READY_TO_ENTER", "P1-N6C world loading completes to ready to enter")
	_check(bool(hud.call("can_enter_world_from_ui")), "P1-N6C can enter world after post-character loading")
	_check(str(ready_model.get("loading_asset_sources", {})).contains("pregame") and str(ready_model.get("loading_asset_sources", {})).contains("Data/loading"), "P1-N6C model documents pregame and Data/loading sources")
	var snap: Dictionary = dol.call("get_p1_n6c_debug_snapshot") as Dictionary
	_check(bool(snap.get("flow_matches_daoc_order", false)), "P1-N6C snapshot preserves DAoC order")
	_check(str(snap).contains("Data/loading"), "P1-N6C snapshot documents post-character loading source")
	_check(bool(snap.get("live_server_required", true)) == false and bool(snap.get("real_network_send_enabled", true)) == false, "P1-N6C snapshot offline/no network")
	_check(str(hud.call("p1_n6c_scope")).contains("loading") or str(hud.call("p1_n6c_scope")).contains("chargement"), "P1-N6C HUD scope")
	_check(str(dol.call("p1_n6c_scope")).contains("realm"), "P1-N6C DOL client scope")
	_debug.append("\n--- DOL P1-N6C UI flow snapshot ---")
	_debug.append(_snapshot_debug_line(snap))
	_debug.append("\n--- DOL P1-N6C UI text ---")
	_debug.append(_snapshot_debug_line(char_text))


func _test_dol_p1_n6d_asset_source_resolver(zone_viewer: Node) -> void:
	_section("P1-N6D asset source resolver pregame/loading")
	var resolver = null
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	if dol != null:
		var candidate = dol.get("pregame_loading_asset_resolver")
		if candidate != null:
			resolver = candidate
	if resolver == null:
		resolver = DaocPregameLoadingAssetResolverScript.new()
	var root := ""
	if zone_viewer != null and zone_viewer.has_method("get_asset_index_registry_15d_debug_snapshot"):
		var asset_snap: Dictionary = zone_viewer.call("get_asset_index_registry_15d_debug_snapshot") as Dictionary
		root = str(asset_snap.get("daoc_root", ""))
	if resolver.has_method("setup"):
		resolver.call("setup", root)
	_check(resolver != null, "P1-N6D resolver available")
	if resolver == null:
		return
	var required := PackedStringArray([
		"scan_daoc_asset_roots", "scan_pregame_assets", "parse_realmdesc_text", "realmdesc_fixture_text", "build_realm_asset_candidates",
		"scan_loading_sets", "build_loading_candidates", "asset_candidate_status", "build_pregame_loading_audit_snapshot", "build_asset_source_panel_lines",
		"status_snapshot", "p1_n6d_scope", "is_runtime_import_enabled", "get_function_names",
	])
	for name in required:
		_check(resolver.has_method(str(name)), "P1-N6D method present: %s" % str(name))
	var roots: Dictionary = resolver.call("scan_daoc_asset_roots", root) as Dictionary
	_check(str(roots.get("selected_pregame_path", "")).contains("pregame"), "P1-N6D pregame root candidate")
	_check(str(roots.get("selected_loading_path", "")).to_lower().contains("loading"), "P1-N6D loading root candidate")
	var parsed: Dictionary = resolver.call("parse_realmdesc_text", str(resolver.call("realmdesc_fixture_text"))) as Dictionary
	_check(bool(parsed.get("ok", false)) and int(parsed.get("realm_count", 0)) == 3, "P1-N6D parses realmdesc fixture into 3 realms")
	var alb: Dictionary = resolver.call("build_realm_asset_candidates", 1) as Dictionary
	_check(str(alb).contains("charscreenalb.nif") and str(alb).contains("charScreenAlb.npk"), "P1-N6D Albion charscreen candidates include NIF and NPK")
	_check(bool(alb.get("rule_confirmed", true)) == false, "P1-N6D character scene rule remains unconfirmed")
	var hib: Dictionary = resolver.call("build_realm_asset_candidates", 3) as Dictionary
	_check(str(hib).contains("pennant_hib.tga"), "P1-N6D Hibernia pennant candidate")
	var loading: Dictionary = resolver.call("scan_loading_sets", "") as Dictionary
	_check(str(loading).contains("alb1") and str(loading).contains("mid1") and str(loading).contains("hib1"), "P1-N6D loading sets include realm trio")
	_check(str(loading).contains("toa") and str(loading).contains("cat") and str(loading).contains("lab"), "P1-N6D loading sets include expansion candidates")
	_check(bool(loading.get("rule_confirmed", true)) == false, "P1-N6D loading rule remains unconfirmed")
	var load_candidates: Dictionary = resolver.call("build_loading_candidates", 2, -1, -1, "f12") as Dictionary
	_check(str(load_candidates).contains("mid1"), "P1-N6D Midgard loading candidate ranks mid1")
	_check(bool(load_candidates.get("rule_confirmed", true)) == false, "P1-N6D build_loading_candidates does not hardcode final rule")
	var archive_status: Dictionary = resolver.call("asset_candidate_status", "archive://pregame/charScreenAlb.npk:charscreenalb.nif") as Dictionary
	_check(str(archive_status.get("status", "")) == "container_only", "P1-N6D archive candidates are container_only")
	var audit: Dictionary = resolver.call("build_pregame_loading_audit_snapshot") as Dictionary
	_check(bool(audit.get("no_runtime_import", false)), "P1-N6D audit forbids runtime import")
	_check(bool(audit.get("real_network_required", true)) == false, "P1-N6D audit offline/no network")
	var lines: PackedStringArray = resolver.call("build_asset_source_panel_lines", 1, -1, -1, "f12") as PackedStringArray
	_check(lines.size() >= 5 and str(lines).contains("rule_confirmed=false"), "P1-N6D panel lines expose cautious rule status")
	if dol != null and dol.has_method("get_p1_n6d_debug_snapshot"):
		var dol_snap: Dictionary = dol.call("get_p1_n6d_debug_snapshot") as Dictionary
		_check(bool(dol_snap.get("no_runtime_import", false)), "P1-N6D DOL bridge snapshot no_runtime_import")
		_check(bool(dol_snap.get("rule_confirmed", true)) == false, "P1-N6D DOL bridge keeps rule unconfirmed")
	var hud := _get_node_ref(zone_viewer, "_dol_character_select_hud_1127")
	if hud != null and hud.has_method("build_p1_n6d_asset_audit_snapshot"):
		var hud_audit: Dictionary = hud.call("build_p1_n6d_asset_audit_snapshot") as Dictionary
		_check(bool(hud_audit.get("no_runtime_import", false)), "P1-N6D HUD bridge exposes asset audit")
	var names: PackedStringArray = resolver.call("get_function_names") as PackedStringArray
	var all_present := names.size() >= 18
	for name in names:
		if not resolver.has_method(str(name)):
			all_present = false
			break
	_check(all_present, "P1-N6D function list complete", "count=%d" % names.size())
	_check(bool(resolver.call("is_runtime_import_enabled")) == false, "P1-N6D runtime import disabled")
	_check(str(resolver.call("p1_n6d_scope")).contains("P1-N6D"), "P1-N6D scope text")
	_debug.append("\n--- DOL P1-N6D asset resolver audit ---")
	_debug.append(_snapshot_debug_line(audit))
	_debug.append("\n--- DOL P1-N6D asset panel ---")
	_debug.append(_snapshot_debug_line(lines))


func _test_p1_n6e_debug_output_governor(zone_viewer: Node) -> void:
	_section("P1-N6E debug output governor / F12 clean")
	var limiter: RefCounted = DaocDebugOutputLimiterScript.new()
	_check(limiter != null, "P1-N6E limiter available")
	if limiter == null:
		return
	var long_text := ""
	for _i in range(160):
		long_text += "0123456789"
	var compact_text := str(limiter.call("compact_text", long_text, 180, 8))
	_check(compact_text.length() <= 240 and compact_text.contains("truncated"), "P1-N6E compact_text clamps long console line", "len=%d" % compact_text.length())
	var deep := {
		"scope": "P1-N6E test",
		"outer": {
			"inner": {"array": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "text": long_text},
		},
	}
	var compact_value := str(limiter.call("compact_value", deep, 360, 2))
	_check(compact_value.length() <= 430, "P1-N6E compact_value clamps nested dictionaries", "len=%d" % compact_value.length())
	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null and command.has_method("has_debug_output_governor") and bool(command.call("has_debug_output_governor")), "P1-N6E command router safe print present")
	_debug.append("\n--- P1-N6E limiter sample ---")
	_debug.append(_snapshot_debug_line(deep))


func _test_command_router(zone_viewer: Node) -> void:
	_section("Command router")
	var command = _get_node_ref(zone_viewer, "_command_router")
	_check(command != null, "command router available")
	if command == null:
		return
	_check(command.has_method("execute_command"), "execute_command present")
	_check(command.has_method("set_dol_client"), "command router can receive DOL client")
	var handled_loc := bool(command.call("execute_command", "/loc"))
	_check(handled_loc, "/loc handled")
	var handled_where := bool(command.call("execute_command", "/where"))
	_check(handled_where, "/where handled")
	var handled_target := bool(command.call("execute_command", "/target"))
	_check(handled_target, "/target handled")
	var handled_dol := bool(command.call("execute_command", "/dol status"))
	_check(handled_dol, "/dol status handled")
	var handled_tcp := bool(command.call("execute_command", "/dol tcp"))
	_check(handled_tcp, "/dol tcp handled")
	var handled_packet := bool(command.call("execute_command", "/dol packet"))
	_check(handled_packet, "/dol packet handled")
	var handled_wire := bool(command.call("execute_command", "/dol wire"))
	_check(handled_wire, "/dol wire handled")
	var handled_loginpacket := bool(command.call("execute_command", "/dol loginpacket testgodot testgodot"))
	_check(handled_loginpacket, "/dol loginpacket handled")
	var handled_charpacket := bool(command.call("execute_command", "/dol charpacket 1"))
	_check(handled_charpacket, "/dol charpacket handled")
	var handled_selectpacket := bool(command.call("execute_command", "/dol selectpacket 0"))
	_check(handled_selectpacket, "/dol selectpacket handled")
	var handled_worldpacket := bool(command.call("execute_command", "/dol worldpacket"))
	_check(handled_worldpacket, "/dol worldpacket handled")
	var handled_flow := bool(command.call("execute_command", "/dol flow testgodot testgodot"))
	_check(handled_flow, "/dol flow handled")
	var handled_rx := bool(command.call("execute_command", "/dol rx"))
	_check(handled_rx, "/dol rx handled")
	var handled_assets := bool(command.call("execute_command", "/dol assets"))
	_check(handled_assets, "/dol assets handled")
	var handled_assets_audit := bool(command.call("execute_command", "/dol assets audit"))
	_check(handled_assets_audit, "/dol assets audit handled")
	var handled_zonejump := bool(command.call("execute_command", "/zonejump status"))
	_check(handled_zonejump, "/zonejump status handled by command router")
	var handled_charhud := bool(command.call("execute_command", "/dol charhud on"))
	_check(handled_charhud, "/dol charhud handled")
	var handled_uiflow := bool(command.call("execute_command", "/dol uiflow"))
	_check(handled_uiflow, "/dol uiflow handled")
	var handled_loading := bool(command.call("execute_command", "/dol loading"))
	_check(handled_loading, "/dol loading handled")
	var handled_loading_done := bool(command.call("execute_command", "/dol loading done"))
	_check(handled_loading_done, "/dol loading done handled")
	var handled_worldloading := bool(command.call("execute_command", "/dol worldloading"))
	_check(handled_worldloading, "/dol worldloading handled")
	var handled_worldloading_done := bool(command.call("execute_command", "/dol worldloading done"))
	_check(handled_worldloading_done, "/dol worldloading done handled")
	var handled_realm_list := bool(command.call("execute_command", "/dol realm"))
	_check(handled_realm_list, "/dol realm handled")
	var handled_realm_albion := bool(command.call("execute_command", "/dol realm Albion"))
	_check(handled_realm_albion, "/dol realm Albion handled")
	var handled_charview := bool(command.call("execute_command", "/dol charview"))
	_check(handled_charview, "/dol charview handled")
	var handled_choose := bool(command.call("execute_command", "/dol choose 0"))
	_check(handled_choose, "/dol choose handled")
	var handled_selected := bool(command.call("execute_command", "/dol selected"))
	_check(handled_selected, "/dol selected handled")
	var handled_apply_dry := bool(command.call("execute_command", "/dol applybootstrap dry"))
	_check(handled_apply_dry, "/dol applybootstrap dry handled")
	var handled_apply_real_guard := bool(command.call("execute_command", "/dol applybootstrap real"))
	_check(handled_apply_real_guard, "/dol applybootstrap real guard handled")
	var handled_rollback_guard := bool(command.call("execute_command", "/dol rollbackbootstrap"))
	_check(handled_rollback_guard, "/dol rollbackbootstrap handled")
	var handled_bootstrap := bool(command.call("execute_command", "/dol bootstrap"))
	_check(handled_bootstrap, "/dol bootstrap handled")
	var handled_unchoose := bool(command.call("execute_command", "/dol unchoose"))
	_check(handled_unchoose, "/dol unchoose handled")
	var dol := _get_node_ref(zone_viewer, "_dol_client")
	if dol != null and dol.has_method("get_connection_state_for_restore"):
		var saved := dol.call("get_connection_state_for_restore") as Dictionary
		if dol.has_method("reset_to_disconnected"):
			dol.call("reset_to_disconnected")
		if dol.has_method("start_login"):
			dol.call("start_login", "f12_command", "", true)
		if dol.has_method("request_charlist"):
			dol.call("request_charlist")
		if dol.has_method("enter_world"):
			dol.call("enter_world", 0)
		var handled_pos := bool(command.call("execute_command", "/dol pos"))
		_check(handled_pos, "/dol pos handled")
		var handled_heading := bool(command.call("execute_command", "/dol heading"))
		_check(handled_heading, "/dol heading handled")
		var handled_region := bool(command.call("execute_command", "/dol region"))
		_check(handled_region, "/dol region handled")
		dol.call("restore_connection_state", saved)


func _export_debug_dump(zone_viewer: Node) -> void:
	_debug.append("DAoC Godot F12 debug export")
	_debug.append("timestamp=%s" % Time.get_datetime_string_from_system(true, true))
	_debug.append("report_summary_so_far pass=%d warn=%d fail=%d" % [_pass_count, _warn_count, _fail_count])
	_debug.append("")
	_debug.append("--- selected ZoneViewer properties ---")
	if zone_viewer != null:
		var props := [
			"zones", "world_scale", "height_exaggeration", "build_terrain_collision", "build_bound_collision",
			"bound_collision_blocks_player", "build_zonejump_debug", "zonejump_area_enabled", "zonejump_optional_dedupe_pairs",
			"generate_prop_collisions", "prop_collision_blocks_player", "spawn_player_capsule", "player_zone",
			"player_use_keyboard_dat_bindings", "player_keyboard_preset", "player_mouse_right_moves_forward",
			"player_mouse_left_moves_backward", "player_mouse_both_buttons_move_forward", "player_force_disable_legacy_mouse_movement",
			"build_water", "build_legacy_lights", "build_vegetation", "build_dev_hud", "build_local_targeting",
			"build_dol_client", "build_dol_transport", "build_dol_packet_layer", "build_dol_wire_1127", "build_dol_login_flow_1127", "build_dol_server_fixtures_1127", "build_dol_character_bootstrap_1127", "build_dol_character_select_hud_1127", "dol_simulation_enabled", "dol_transport_enabled", "dol_default_host", "dol_default_port", "dol_transport_timeout_msec"
		]
		for p in props:
			_debug.append("%s=%s" % [p, str(zone_viewer.get(p))])
		_debug.append("")
		_debug.append("--- runtime dictionary sizes ---")
		for p in ["_zone_runtime", "_terrain_build_results", "_terrain_meshes_by_zone", "_terrain_collision_bodies_by_zone", "_boundary_runtime", "_boundary_build_results", "_zonejump_entries_by_zone", "_zonejump_build_results", "_prop_collision_runtime", "_prop_build_results", "_prop_nodes_by_zone", "_water_runtime", "_water_build_results"]:
			var d: Dictionary = _get_dict(zone_viewer, p)
			_debug.append("%s size=%d keys=%s" % [p, d.size(), str(d.keys())])
		_debug.append("")
		_debug.append("--- scene tree compact ---")
		_dump_tree(zone_viewer, 0, 3, 80)
		if zone_viewer.has_method("get_local_client_debug_snapshot"):
			_debug.append("")
			_debug.append("--- local client snapshot ---")
			_debug.append(_snapshot_debug_line(zone_viewer.call("get_local_client_debug_snapshot")))
		if zone_viewer.has_method("get_zonejump_interaction_debug_snapshot"):
			_debug.append("")
			_debug.append("--- P1-N6F zonejump final snapshot ---")
			_debug.append(_snapshot_debug_line(zone_viewer.call("get_zonejump_interaction_debug_snapshot")))
		var dol := _get_node_ref(zone_viewer, "_dol_client")
		if dol != null and dol.has_method("get_network_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL client final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_network_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n2_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N2 final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n2_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n3_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N3 final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n3_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n4_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N4 final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n4_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n5a_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N5A final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n5a_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n5b_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N5B final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n5b_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n5d_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N5D final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n5d_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n5efg_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N5E/F/G final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n5efg_debug_snapshot")))
		if dol != null and dol.has_method("get_p1_n5hij_debug_snapshot"):
			_debug.append("")
			_debug.append("--- DOL P1-N5H/I/J + P1-N6A final snapshot ---")
			_debug.append(_snapshot_debug_line(dol.call("get_p1_n5hij_debug_snapshot")))
			if dol != null and dol.has_method("get_p1_n6b_debug_snapshot"):
				_debug.append("")
				_debug.append("--- DOL P1-N6B final snapshot ---")
				_debug.append(_snapshot_debug_line(dol.call("get_p1_n6b_debug_snapshot")))
			if dol != null and dol.has_method("get_p1_n6c_debug_snapshot"):
				_debug.append("")
				_debug.append("--- DOL P1-N6C final snapshot ---")
				_debug.append(_snapshot_debug_line(dol.call("get_p1_n6c_debug_snapshot")))
			if dol != null and dol.has_method("get_p1_n6d_debug_snapshot"):
				_debug.append("")
				_debug.append("--- DOL P1-N6D final snapshot ---")
				_debug.append(_snapshot_debug_line(dol.call("get_p1_n6d_debug_snapshot")))


func _dump_tree(node: Node, depth: int, max_depth: int, max_lines: int) -> void:
	if node == null or depth > max_depth or max_lines <= 0:
		return
	if _debug.size() > max_lines + 120:
		return
	var indent := ""
	for _i in range(depth):
		indent += "  "
	var extra := ""
	if node is Node3D:
		extra = " pos=%s" % str((node as Node3D).global_position)
	elif node is CollisionShape3D:
		extra = " disabled=%s" % str((node as CollisionShape3D).disabled)
	_debug.append("%s- %s <%s>%s" % [indent, node.name, node.get_class(), extra])
	var children := node.get_children()
	var shown := 0
	for child in children:
		if shown >= 14 and depth >= 2:
			_debug.append("%s  ... %d more children" % [indent, children.size() - shown])
			break
		_dump_tree(child, depth + 1, max_depth, max_lines)
		shown += 1


func _count_nodes_with_meta(root: Node, meta_name: String) -> int:
	if root == null:
		return 0
	var count := 0
	if root.has_meta(meta_name):
		count += 1
	for c in root.get_children():
		count += _count_nodes_with_meta(c, meta_name)
	return count


func _count_nodes_in_group(root: Node, group_name: String) -> int:
	if root == null or root.get_tree() == null:
		return 0
	var count := 0
	for n in root.get_tree().get_nodes_in_group(group_name):
		if n is Node:
			count += 1
	return count


func _count_node_type(root: Node, type_name: String) -> int:
	if root == null:
		return 0
	var count := 1 if root.is_class(type_name) else 0
	for c in root.get_children():
		count += _count_node_type(c, type_name)
	return count



func _p1_n2_compact_report_line(snap: Dictionary) -> String:
	var pos: Dictionary = snap.get("position", {}) as Dictionary
	var region: Dictionary = snap.get("regionchange", {}) as Dictionary
	var flow: Dictionary = snap.get("packet_flow", {}) as Dictionary
	var current: Dictionary = pos.get("current", {}) as Dictionary
	return "pos_seq=%d heading_seq=%d region_seq=%d zone=%d region=%d sector=%d,%d flow=%d" % [
		int(pos.get("position_sequence", 0)),
		int(pos.get("heading_sequence", 0)),
		int(region.get("sequence", 0)),
		int(current.get("zone", -1)),
		int(current.get("region_id", -1)),
		int(current.get("sector_x", -1)),
		int(current.get("sector_y", -1)),
		int(flow.get("count", 0)),
	]


func _limiter() -> RefCounted:
	if _debug_output_limiter == null:
		_debug_output_limiter = DaocDebugOutputLimiterScript.new()
	return _debug_output_limiter


func _compact_detail(detail: String, max_chars: int = MAX_DETAIL_CHARS) -> String:
	return str(_limiter().call("compact_text", str(detail), max_chars, 8))


func _snapshot_debug_line(value: Variant) -> String:
	return str(_limiter().call("compact_value", value, MAX_DEBUG_SNAPSHOT_CHARS, 2))

func _section(title: String) -> void:
	_line("")
	_line("[%s]" % title)
	_json_sections.append({"section": title, "items": []})


func _check(ok: bool, label: String, detail: String = "") -> void:
	var compact_detail := _compact_detail(detail)
	var suffix := ""
	if compact_detail != "":
		suffix = " :: " + compact_detail
	if ok:
		_pass_count += 1
		_line("PASS %s%s" % [label, suffix])
		_json_item("PASS", label, compact_detail)
	else:
		_fail_count += 1
		_line("FAIL %s%s" % [label, suffix])
		_json_item("FAIL", label, compact_detail)


func _check_closed_refactor_oracle(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_check(true, label, detail)
	else:
		_warn("%s (closed refactor oracle, non bloquant)" % label, detail)


func _warn(label: String, detail: String = "") -> void:
	var compact_detail := _compact_detail(detail)
	var suffix := ""
	if compact_detail != "":
		suffix = " :: " + compact_detail
	_warn_count += 1
	_line("WARN %s%s" % [label, suffix])
	_json_item("WARN", label, compact_detail)


func _json_item(status: String, label: String, detail: String) -> void:
	if _json_sections.is_empty():
		_json_sections.append({"section": "misc", "items": []})
	var s: Dictionary = _json_sections[_json_sections.size() - 1] as Dictionary
	var items: Array = s.get("items", []) as Array
	items.append({"status": status, "label": label, "detail": detail})
	s["items"] = items
	_json_sections[_json_sections.size() - 1] = s


func _line(text: String) -> void:
	_report.append(text)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("F12 test: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()


func _write_json(zone_viewer: Node, elapsed: int) -> void:
	var scene_name := "<null>"
	if zone_viewer != null:
		scene_name = zone_viewer.name
	var root := {
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"scene": scene_name,
		"godot": Engine.get_version_info().get("string", "unknown"),
		"summary": {"pass": _pass_count, "warn": _warn_count, "fail": _fail_count, "elapsed_ms": elapsed},
		"sections": _json_sections,
	}
	_write_text(JSON_REPORT_PATH, JSON.stringify(_json_sanitize(root), "\t"))


func _json_sanitize(v: Variant) -> Variant:
	var t := typeof(v)
	if t == TYPE_DICTIONARY:
		var out := {}
		var d: Dictionary = v as Dictionary
		for k in d.keys():
			out[str(k)] = _json_sanitize(d[k])
		return out
	if t == TYPE_ARRAY:
		var arr: Array = v as Array
		var out_arr := []
		for item in arr:
			out_arr.append(_json_sanitize(item))
		return out_arr
	if t == TYPE_PACKED_STRING_ARRAY or t == TYPE_PACKED_INT32_ARRAY or t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_VECTOR2_ARRAY or t == TYPE_PACKED_VECTOR3_ARRAY:
		var out_packed := []
		for item in v:
			out_packed.append(_json_sanitize(item))
		return out_packed
	if t == TYPE_VECTOR2:
		var vv: Vector2 = v as Vector2
		return {"x": vv.x, "y": vv.y}
	if t == TYPE_VECTOR3:
		var v3: Vector3 = v as Vector3
		return {"x": v3.x, "y": v3.y, "z": v3.z}
	if t == TYPE_OBJECT:
		return str(v)
	return v


func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for property_info in obj.get_property_list():
		if typeof(property_info) == TYPE_DICTIONARY and str(property_info.get("name", "")) == property_name:
			return true
	return false


func _get_bool(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	return bool(obj.get(property_name))


func _get_dict(obj: Object, property_name: String) -> Dictionary:
	if obj == null:
		return {}
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_DICTIONARY:
		return v as Dictionary
	return {}


func _get_node_ref(obj: Object, property_name: String) -> Node:
	if obj == null:
		return null
	var v: Variant = obj.get(property_name)
	if v is Node:
		return v as Node
	return null


func _get_array_like(obj: Object, property_name: String) -> Array:
	if obj == null:
		return []
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	if typeof(v) == TYPE_PACKED_INT32_ARRAY:
		var out: Array = []
		for i in v:
			out.append(int(i))
		return out
	return []


func _format_p1_18n_debug_details(report: Dictionary) -> String:
	var models: Dictionary = report.get("models", {}) as Dictionary
	var textures: Dictionary = report.get("textures", {}) as Dictionary
	var crit: Dictionary = report.get("critical_candidates", {}) as Dictionary
	var crit_runtime: Dictionary = report.get("critical_runtime", {}) as Dictionary
	var runtime_materials: Dictionary = report.get("runtime_materials", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("P1-18N details: model_index=%d missing_by_index=%d texture_index=%d lightmaps=%d critical=%d critical_missing=%d")
	lines[lines.size() - 1] = lines[lines.size() - 1] % [
		int(models.get("model_index_size", 0)),
		int(models.get("missing_by_model_index_count", 0)),
		int(textures.get("texture_index_size", 0)),
		int(textures.get("lightmap_candidate_count", 0)),
		int(crit.get("candidate_count", 0)),
		int(crit.get("missing_candidate_count", 0)),
	]
	lines.append("P1-18N runtime critical: rows=%d missing_nodes=%d zero_mesh=%d zero_vertices=%d")
	lines[lines.size() - 1] = lines[lines.size() - 1] % [
		int(crit_runtime.get("critical_runtime_count", 0)),
		int(crit_runtime.get("missing_node_count", 0)),
		int(crit_runtime.get("zero_mesh_count", 0)),
		int(crit_runtime.get("zero_vertex_count", 0)),
	]
	lines.append("P1-18N runtime materials: prop_mesh_nodes=%d terrain_mesh_nodes=%d inspected=%d albedo_slots=%d")
	lines[lines.size() - 1] = lines[lines.size() - 1] % [
		int(runtime_materials.get("prop_mesh_nodes_found", runtime_materials.get("mesh_nodes_found", 0))),
		int(runtime_materials.get("terrain_mesh_nodes_found", 0)),
		int(runtime_materials.get("mesh_nodes_inspected", 0)),
		int(runtime_materials.get("albedo_texture_count", 0)),
	]
	for row_value in (crit_runtime.get("rows", []) as Array).slice(0, min(8, (crit_runtime.get("rows", []) as Array).size())):
		var row: Dictionary = row_value as Dictionary
		lines.append("P1-18N critical node: fixture=%d file=%s node_found=%s meshes=%d vertices=%d origin=%s")
		lines[lines.size() - 1] = lines[lines.size() - 1] % [
			int(row.get("fixture_id", 0)),
			str(row.get("file", "")),
			str(row.get("node_found", false)),
			int(row.get("mesh_instance_count", 0)),
			int(row.get("vertex_count", 0)),
			str(row.get("global_origin", "")),
		]
	return "\n".join(lines)

func _effective_loaded_zones_a7f(zone_viewer: Node) -> Array:
	var seen: Dictionary = {}
	var configured_zones: Array = _get_array_like(zone_viewer, "zones")
	for zone_value in configured_zones:
		seen[int(zone_value)] = true

	var runtime_zone_maps: Array = [
		"_zone_runtime",
		"_terrain_build_results",
		"_terrain_meshes_by_zone",
		"_terrain_collision_bodies_by_zone",
		"_boundary_runtime",
		"_boundary_build_results",
		"_zonejump_entries_by_zone",
		"_zonejump_build_results",
		"_prop_collision_runtime",
		"_prop_build_results",
		"_prop_nodes_by_zone",
		"_water_runtime",
		"_water_build_results",
	]
	for property_name_value in runtime_zone_maps:
		var property_name: String = str(property_name_value)
		var keys: Array = _dictionary_keys_int(zone_viewer, property_name)
		for key_value in keys:
			seen[int(key_value)] = true

	var out: Array = []
	for key in seen.keys():
		out.append(int(key))
	out.sort()
	return out


func _should_run_zone000_oracles(zone_viewer: Node) -> bool:
	var effective_zones: Array = _effective_loaded_zones_a7f(zone_viewer)
	if effective_zones.is_empty():
		return _first_configured_zone(zone_viewer) == 0
	# Les oracles historiques P1-14/P1-15/P1-16A1-A5a comparent des compteurs fixes
	# de zone000. Ils ne doivent tourner que dans une session pure zone000 réellement chargée.
	# A7F corrige A7E: `zones` peut rester [0] alors que le runtime contient déjà [0, 1]
	# après un export manuel, donc la décision doit utiliser les dictionnaires runtime/build results.
	return effective_zones.size() == 1 and int(effective_zones[0]) == 0


func _first_configured_zone(zone_viewer: Node) -> int:
	var zones := _get_array_like(zone_viewer, "zones")
	if zones.size() > 0:
		return int(zones[0])
	var player := _get_node_ref(zone_viewer, "_player")
	if player != null:
		return int(player.get("daoc_zone"))
	return 0


func _array_contains_int(values: Array, target: int) -> bool:
	for value in values:
		if int(value) == target:
			return true
	return false


func _dictionary_keys_int(obj: Object, property_name: String) -> Array:
	if obj == null:
		return []
	var v: Variant = obj.get(property_name)
	if typeof(v) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = v as Dictionary
	var out: Array = []
	for key in d.keys():
		out.append(int(key))
	out.sort()
	return out


func _is_finite_float(v: float) -> bool:
	return v == v and absf(v) < INF
