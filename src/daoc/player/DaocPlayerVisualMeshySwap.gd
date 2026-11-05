extends RefCounted
class_name DaocPlayerVisualMeshySwap

const DaocPlayerVisualRuntimeScript = preload("res://src/daoc/player/DaocPlayerVisualRuntime.gd")
const DaocPlayerVisualProfileRegistryScript = preload("res://src/daoc/player/DaocPlayerVisualProfileRegistry.gd")
const DaocPbrMaterialUpgradeScript = preload("res://src/daoc/player/DaocPbrMaterialUpgrade.gd")
const DaocHairMotionScript = preload("res://src/daoc/player/DaocHairMotion.gd")

const CHECKPOINT: String = "P1_18M_PLAYER_VISUAL_MESHY_SWAP"
const VISUAL_ROOT_NAME: String = "DaocPlayerVisualRoot"
const WALK_SCENE_PATH: String = "res://assets/daoc/player/meshy/Meshy_AI_T_Pose_Character_Mode_biped_Animation_Walking_withSkin.glb"
const RUN_SCENE_PATH: String = "res://assets/daoc/player/meshy/Meshy_AI_T_Pose_Character_Mode_biped_Animation_Running_withSkin.glb"
const DEFAULT_CONFIG_PATH: String = "res://config/player_visual_meshy.json"


func default_config() -> Dictionary:
	return {
		"enabled": true,
		"walk_scene_path": WALK_SCENE_PATH,
		"run_scene_path": RUN_SCENE_PATH,
		"visual_scale": 60.0,
		"ground_offset": 0.0,
		"yaw_degrees": 90.0,
		"walk_threshold": 0.05,
		"run_threshold": 4.0,
		"force_state": "auto",
		"idle_mode": "freeze",
		"idle_animation_name": "",
		"walk_animation_name": "",
		"run_animation_name": "",
		"feet_alignment_enabled": true,
		"feet_alignment_mode": "auto",
		"feet_alignment_offset": 0.0,
		"feet_alignment_max_step": 128.0,
		"textures_enabled": false,
		"surface_textures": {},
		# Bascule Vanilla <-> PBR. Decochee, rien n'est charge et rien n'est
		# modifie : le rendu est exactement celui d'avant le jalon.
		"pbr_enabled": false,
		"pbr_client_root": "",
		"pbr_manifest_path": "",
		"pbr_normal_strength": 1.0,
		"pbr_roughness_amount": 1.0,
		"pbr_ao_amount": 0.35,
		"hair_motion_enabled": true,
	}


func load_config(path: String = DEFAULT_CONFIG_PATH) -> Dictionary:
	var config := default_config()
	if not FileAccess.file_exists(path):
		return config
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in (parsed as Dictionary).keys():
			config[str(key)] = (parsed as Dictionary)[key]
	return config


func build_status_report(player: Node = null, options: Dictionary = {}) -> Dictionary:
	var config := load_config(str(options.get("config_path", DEFAULT_CONFIG_PATH)))
	for key in options.keys():
		config[str(key)] = options[key]
	var visual_root := _find_visual_root(player)
	var runtime: Node = visual_root
	var runtime_status: Dictionary = {}
	if runtime != null and runtime.has_method("build_status_report"):
		runtime_status = runtime.call("build_status_report") as Dictionary
	return {
		"checkpoint": CHECKPOINT,
		"ok": FileAccess.file_exists(str(config.get("walk_scene_path", WALK_SCENE_PATH))) and FileAccess.file_exists(str(config.get("run_scene_path", RUN_SCENE_PATH))),
		"player_valid": player != null,
		"visual_root_name": VISUAL_ROOT_NAME,
		"visual_root_attached": visual_root != null,
		"runtime_script_attached": runtime != null and runtime.has_method("install_visuals"),
		"walk_scene_path": str(config.get("walk_scene_path", WALK_SCENE_PATH)),
		"run_scene_path": str(config.get("run_scene_path", RUN_SCENE_PATH)),
		"walk_glb_exists": FileAccess.file_exists(str(config.get("walk_scene_path", WALK_SCENE_PATH))),
		"run_glb_exists": FileAccess.file_exists(str(config.get("run_scene_path", RUN_SCENE_PATH))),
		"collision_shape_count": _count_nodes_of_type(player, "CollisionShape3D"),
		"capsule_collision_preserved": player == null or _count_nodes_of_type(player, "CollisionShape3D") > 0,
		"collision_replaced": false,
		"character_body_replaced": false,
		"root_motion_enabled": false,
		"server_authority_unchanged": true,
		"network_authority_changed": false,
		"runtime_status": runtime_status,
		"walk_animation_player_found": bool(runtime_status.get("walk_animation_player_found", false)),
		"run_animation_player_found": bool(runtime_status.get("run_animation_player_found", false)),
		"idle_animation_name": str(runtime_status.get("idle_animation_name", "")),
		"walk_animation_name": str(runtime_status.get("walk_animation_name", "")),
		"run_animation_name": str(runtime_status.get("run_animation_name", "")),
		"current_state": str(runtime_status.get("current_state", "")),
		"force_state": str(runtime_status.get("force_state", "auto")),
		"idle_mode": str(runtime_status.get("idle_mode", config.get("idle_mode", "walk_loop"))),
		"visual_scale": float(runtime_status.get("visual_scale", config.get("visual_scale", 60.0))),
		"ground_offset": float(runtime_status.get("ground_offset", config.get("ground_offset", 0.0))),
		"yaw_degrees": float(runtime_status.get("yaw_degrees", config.get("yaw_degrees", 90.0))),
		"textures_enabled": bool(runtime_status.get("textures_enabled", config.get("textures_enabled", false))),
		"texture_status": runtime_status.get("texture_status", {}),
	}


func attach_to_player(player: Node, options: Dictionary = {}) -> Dictionary:
	if player == null:
		var missing := build_status_report(null, options)
		missing["ok"] = false
		missing["error"] = "missing_player"
		return missing
	var config := load_config(str(options.get("config_path", DEFAULT_CONFIG_PATH)))
	for key in options.keys():
		config[str(key)] = options[key]
	var root := _find_visual_root(player)
	if root == null:
		root = Node3D.new()
		root.name = VISUAL_ROOT_NAME
		player.add_child(root)
	root.set_script(DaocPlayerVisualRuntimeScript)
	if root is Node3D:
		(root as Node3D).visible = true
	root.call("configure", config.merged({"player_body": player}, true))
	var install_report: Dictionary = root.call("install_visuals") as Dictionary
	var hidden_meshes := _hide_local_capsule_meshes(player, root)
	var status := build_status_report(player, config)
	status["ok"] = bool(install_report.get("ok", false))
	status["attach_report"] = install_report
	status["hidden_capsule_meshes"] = hidden_meshes
	status["visual_runtime_enabled"] = true
	status["pbr_report"] = apply_pbr_mode(root, config)
	return status


## Applique — ou retire — les cartes PBR sur une racine visuelle deja montee.
##
## Appelable seule, sans reattacher : c'est ce qui permet a la bascule de
## l'inspecteur de faire son aller-retour sans recharger la scene.
func apply_pbr_mode(visual_root: Node, config: Dictionary) -> Dictionary:
	if visual_root == null:
		return {"ok": false, "mode": "none", "erreur": "visual_root_absent"}
	if not bool(config.get("pbr_enabled", false)):
		return DaocPbrMaterialUpgradeScript.restore(visual_root)
	var manifest_path := str(config.get("pbr_manifest_path", ""))
	if manifest_path.strip_edges() == "":
		manifest_path = manifest_path_for_scene(str(config.get("walk_scene_path", "")))
	var report: Dictionary = DaocPbrMaterialUpgradeScript.apply(
		visual_root,
		manifest_path,
		str(config.get("pbr_client_root", "")),
		{
			"normal_strength": float(config.get("pbr_normal_strength", 1.0)),
			"roughness_amount": float(config.get("pbr_roughness_amount", 1.0)),
			"ao_amount": float(config.get("pbr_ao_amount", 0.35)),
		}
	)
	if bool(config.get("hair_motion_enabled", true)) and bool(report.get("ok", false)):
		report["hair_motion"] = DaocHairMotionScript.apply(visual_root)
	return report


## Convention posee par le Lab a l'export : le manifeste porte le nom de la
## scene. `briton_female_armsman_epic.tscn` -> `.manifest.json`.
static func manifest_path_for_scene(scene_path: String) -> String:
	if scene_path.strip_edges() == "":
		return ""
	return "%s.manifest.json" % scene_path.get_basename()


## Point de jonction CharacterOverview -> scène Character Lab déjà convertie.
## La sélection de profil reste purement locale et ne modifie aucune autorité réseau.
func attach_character_to_player(player: Node, character: Dictionary, options: Dictionary = {}) -> Dictionary:
	var registry: RefCounted = DaocPlayerVisualProfileRegistryScript.new()
	var resolved: Dictionary = registry.call("resolve_character", character, str(options.get("registry_path", DaocPlayerVisualProfileRegistryScript.DEFAULT_REGISTRY_PATH))) as Dictionary
	if not bool(resolved.get("ok", false)):
		return {
			"checkpoint": CHECKPOINT,
			"ok": false,
			"error": str(resolved.get("error", "visual_profile_not_resolved")),
			"profile_resolution": resolved,
			"server_authority_unchanged": true,
		}
	var runtime_options := (resolved.get("runtime_options", {}) as Dictionary).duplicate(true)
	for key in options.keys():
		if str(key) != "registry_path":
			runtime_options[str(key)] = options[key]
	var status := attach_to_player(player, runtime_options)
	status["profile_id"] = str(resolved.get("profile_id", ""))
	status["profile_resolution"] = str(resolved.get("resolution", ""))
	status["profile_manifest_path"] = str(resolved.get("manifest_path", ""))
	status["character_identity"] = resolved.get("identity", {})
	status["size_choice"] = str(resolved.get("size_choice", "average"))
	status["size_model_bits"] = int(resolved.get("size_model_bits", 0x1000))
	status["size_visual_factor"] = float(resolved.get("size_visual_factor", 1.0))
	return status


func resolve_profile_for_character(character: Dictionary, registry_path: String = DaocPlayerVisualProfileRegistryScript.DEFAULT_REGISTRY_PATH) -> Dictionary:
	var registry: RefCounted = DaocPlayerVisualProfileRegistryScript.new()
	return registry.call("resolve_character", character, registry_path) as Dictionary


func attach_overview_to_player(player: Node, overview: Dictionary, character_name: String = "", options: Dictionary = {}) -> Dictionary:
	var registry: RefCounted = DaocPlayerVisualProfileRegistryScript.new()
	var resolved: Dictionary = registry.call("resolve_overview", overview, character_name, str(options.get("registry_path", DaocPlayerVisualProfileRegistryScript.DEFAULT_REGISTRY_PATH))) as Dictionary
	if not bool(resolved.get("ok", false)):
		return {
			"checkpoint": CHECKPOINT,
			"ok": false,
			"error": str(resolved.get("error", "overview_visual_profile_not_resolved")),
			"profile_resolution": resolved,
			"server_authority_unchanged": true,
		}
	var character := resolved.get("selected_character", {}) as Dictionary
	return attach_character_to_player(player, character, options)


func detach_from_player(player: Node, remove_node: bool = false) -> Dictionary:
	if player == null:
		return {"checkpoint": CHECKPOINT, "ok": false, "error": "missing_player"}
	var root := _find_visual_root(player)
	if root == null:
		return {"checkpoint": CHECKPOINT, "ok": true, "status": "already_detached", "visual_runtime_enabled": false}
	if remove_node:
		player.remove_child(root)
		root.queue_free()
	else:
		if root is Node3D:
			(root as Node3D).visible = false
	_restore_local_capsule_meshes(player)
	return {
		"checkpoint": CHECKPOINT,
		"ok": true,
		"status": "detached" if remove_node else "hidden",
		"visual_runtime_enabled": false,
		"collision_replaced": false,
		"character_body_replaced": false,
	}


func force_state(player: Node, state: String) -> Dictionary:
	var root := _find_visual_root(player)
	if root == null or not root.has_method("configure"):
		return {"checkpoint": CHECKPOINT, "ok": false, "error": "visual_root_missing"}
	root.call("configure", {"force_state": state})
	if root.has_method("_set_state"):
		var normalized := state.strip_edges().to_lower()
		if normalized == "auto":
			normalized = "idle"
		if normalized == "idle" or normalized == "walk" or normalized == "run":
			root.call("_set_state", normalized, true)
	return build_status_report(player)


func configure_runtime(player: Node, options: Dictionary = {}) -> Dictionary:
	var root := _find_visual_root(player)
	if root == null or not root.has_method("configure"):
		return {"checkpoint": CHECKPOINT, "ok": false, "error": "visual_root_missing"}
	root.call("configure", options)
	return build_status_report(player)


func _find_visual_root(player: Node) -> Node:
	if player == null:
		return null
	return player.get_node_or_null(VISUAL_ROOT_NAME)


func _count_nodes_of_type(root: Node, type_name: String) -> int:
	if root == null:
		return 0
	var count := 0
	if root.is_class(type_name):
		count += 1
	for child in root.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _hide_local_capsule_meshes(player: Node, visual_root: Node) -> Array:
	var hidden: Array = []
	if player == null:
		return hidden
	for child in player.get_children():
		if child == visual_root:
			continue
		if child is MeshInstance3D:
			var lower := str(child.name).to_lower()
			if lower.contains("capsule") or lower.contains("player_mesh") or lower.contains("debug_player"):
				(child as MeshInstance3D).visible = false
				child.set_meta("p1_18m_hidden_by_meshy_swap", true)
				hidden.append(str(child.get_path()))
	return hidden


func _restore_local_capsule_meshes(player: Node) -> void:
	if player == null:
		return
	for child in player.get_children():
		if child is MeshInstance3D and child.has_meta("p1_18m_hidden_by_meshy_swap"):
			(child as MeshInstance3D).visible = true
			child.remove_meta("p1_18m_hidden_by_meshy_swap")
