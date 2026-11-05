extends RefCounted
class_name DaocZoneViewerFreezeAudit


## P1-15H — audit final de gel ZoneViewer.
## Ne déplace aucune logique runtime. Décide explicitement que le refactor structurel
## P1-15 est terminé et que la prochaine étape doit redevenir fonctionnelle.

const ZONEJUMP_SIG: String = "27a4632b710a6cdb202c18e182793954"
const WATER_SIG: String = "9fb7474a4dab25cb828a4973b2c12e15"
const BOUNDARY_SIG: String = "1154ee2f495873b7f8461dd88536908e"
const PROP_SIG: String = "46d670df525a69230158d643f5a70468"
const TERRAIN_SIG: String = "7601093f060a7b75f2c3e6824c40f05f"


static func build_snapshot(zone_viewer: Node) -> Dictionary:
	var audit := _call_dict(zone_viewer, "get_zoneviewer_p1_15a_audit_snapshot")
	var domains: Dictionary = audit.get("domains", {}) if audit is Dictionary else {}
	var asset := _call_dict(zone_viewer, "get_zoneviewer_mass_reduction_15d_snapshot")
	var state := _call_dict(zone_viewer, "get_zoneviewer_state_15e_debug_snapshot")
	var command_debug := _call_dict(zone_viewer, "get_zoneviewer_command_debug_15f_snapshot")
	var bootstrap := _call_dict(zone_viewer, "get_zoneviewer_bootstrap_15g_snapshot")
	var signatures := _signature_snapshot(zone_viewer)
	var module_presence := _module_presence(zone_viewer, asset, state, command_debug, bootstrap)

	var line_count := int(audit.get("line_count", 0))
	var function_count := int(audit.get("function_count", 0))
	var var_count := int(audit.get("var_count", 0))
	var preload_count := int(audit.get("preload_count", 0))
	var asset_residue := int(domains.get("asset_model_texture_index", 999))
	var vegetation_residue := int(domains.get("vegetation_legacy", 999))
	var legacy_lights_residue := int(domains.get("legacy_lights", 999))
	var zonejump_residue := int(domains.get("zonejump_runtime_debug", 999))
	var misc_residue := int(domains.get("misc_shared_helpers", 999))

	var hard_stop_reasons := [
		"ZoneViewer sous 2000 lignes et en rôle shell local",
		"builders statiques 14A→14E sortis et signatures inchangées",
		"legacy visuals, asset/index, state, command/debug et bootstrap extraits",
		"résidus lourds à zéro; zonejump restant limité aux wrappers publics",
		"continuer à extraire maintenant apporterait peu et augmenterait le risque",
	]

	return {
		"scope": "P1-15H ZoneViewer freeze audit / stop refactor",
		"checkpoint": "F_FREEZE_AUDIT_STOP_REFACTOR",
		"refactor_closed": true,
		"zoneviewer_role_now": "local viewer shell / compatibility facade",
		"final_decision": "P1-15 refactor ZoneViewer terminé",
		"recommended_next_step": "P1-16 reprise fonctionnelle hors refactor ZoneViewer",
		"do_not_continue_zoneviewer_refactor_now": true,
		"no_more_p1_15x_refactor_by_default": true,
		"audit": audit,
		"line_count": line_count,
		"function_count": function_count,
		"export_count": int(audit.get("export_count", 0)),
		"var_count": var_count,
		"preload_count": preload_count,
		"asset_index_residue": asset_residue,
		"vegetation_legacy_residue": vegetation_residue,
		"legacy_lights_residue": legacy_lights_residue,
		"zonejump_runtime_debug_residue": zonejump_residue,
		"misc_shared_helpers_residue": misc_residue,
		"module_presence": module_presence,
		"signatures": signatures,
		"hard_stop_reasons": hard_stop_reasons,
		"allowed_future_refactor_only_if": [
			"un bug concret exige une extraction ciblée",
			"un nouveau système fonctionnel impose une frontière claire",
			"un module dépasse à nouveau un seuil F12 explicite",
		],
		"next_functional_options": [
			"ZoneCreator / génération .tscn propre",
			"sélection personnage + écran chargement",
			"pipeline personnage modèle/animation",
			"préparation DOL réel gardée derrière garde-fous",
		],
	}


static func _call_dict(node: Node, method_name: String) -> Dictionary:
	if node == null or not node.has_method(method_name):
		return {}
	var value: Variant = node.call(method_name)
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


static func _module_presence(zone_viewer: Node, asset: Dictionary, state: Dictionary, command_debug: Dictionary, bootstrap: Dictionary) -> Dictionary:
	var boot: Dictionary = bootstrap.get("bootstrap", {}) if bootstrap is Dictionary else {}
	return {
		"asset_registry_present": bool(asset.get("asset_registry_present", false)),
		"state_registry_present": bool(state.get("state_registry_present", false)),
		"command_debug_surface_present": bool(command_debug.get("command_debug_surface_present", false)),
		"bootstrap_present": bool(bootstrap.get("bootstrap_present", false)),
		"player_present": bool(boot.get("player_present", false)),
		"player_camera_present": bool(boot.get("player_camera_present", false)),
		"input_router_present": bool(boot.get("input_router_present", false)),
		"command_router_present": bool(boot.get("command_router_present", false)),
		"dev_hud_present": bool(boot.get("dev_hud_present", false)),
		"local_targeting_present": bool(boot.get("local_targeting_present", false)),
		"dol_client_present": bool(boot.get("dol_client_present", false)),
		"zone_viewer_node_present": zone_viewer != null,
	}


static func _signature_snapshot(zone_viewer: Node) -> Dictionary:
	var zonejump := _call_dict(zone_viewer, "get_zonejump_14a_debug_snapshot")
	var water := _call_dict(zone_viewer, "get_water_14b_debug_snapshot")
	var collision := _call_dict(zone_viewer, "get_collision_14c_debug_snapshot")
	var prop := _call_dict(zone_viewer, "get_prop_14d_debug_snapshot")
	var terrain := _call_dict(zone_viewer, "get_terrain_14e_debug_snapshot")
	return {
		"zonejump": str(zonejump.get("zone0_index_signature", "")),
		"water": str(water.get("zone0_index_signature", "")),
		"boundary": str(collision.get("zone0_boundary_signature", "")),
		"prop": str(prop.get("zone0_index_signature", "")),
		"terrain": str(terrain.get("zone0_index_signature", "")),
		"zonejump_ok": str(zonejump.get("zone0_index_signature", "")) == ZONEJUMP_SIG,
		"water_ok": str(water.get("zone0_index_signature", "")) == WATER_SIG,
		"boundary_ok": str(collision.get("zone0_boundary_signature", "")) == BOUNDARY_SIG,
		"prop_ok": str(prop.get("zone0_index_signature", "")) == PROP_SIG,
		"terrain_ok": str(terrain.get("zone0_index_signature", "")) == TERRAIN_SIG,
	}
