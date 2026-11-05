extends RefCounted
class_name DaocZoneCreationResult

## P1-16A1/A2/A3a/A3b/A3c/A4/A5a — résultat de création/export de scène de zone hors ZoneViewer.
## Le résultat décrit une scène générée propre, ses branches, les signatures
## héritées des builders 14A→14E, le statut export/reload, puis les métriques
## de population visuelle terrain/eau, preview props contrôlée, full props par zone,
## puis données éditeur collision/zonejump, batch multi-zone contrôlé et classification P1-16A10A.

var scope: String = "P1-16A1 ZoneCreator foundation"
var checkpoint: String = "P1_16A1_ZONECREATOR_FOUNDATION"
var ok: bool = false
var zone: int = -1
var root: Node3D = null
var branches: Dictionary = {}
var branch_names: Array = []
var source_snapshots: Dictionary = {}
var signatures: Dictionary = {}
var metrics: Dictionary = {}
var errors: Array = []
var warnings: Array = []
var creation_mode: String = "detached_editor_ready_shell"
var attached_to_host: bool = false
var generated_scene_path: String = ""
var exported_scene_path: String = ""
var export_ok: bool = false
var export_error_code: int = -1
var pack_error_code: int = -1
var file_exists_after_save: bool = false
var reload_ok: bool = false
var reload_root_name: String = ""
var reload_branch_names: Array = []
var export_mode: String = "none"
var include_runtime_nodes: bool = false
var recommended_next_step: String = "P1-16A2 exporter GeneratedZone_000.tscn"
var zone_kind: String = "unknown"
var generated_scene_status: String = "unknown_unclassified"
var supported_for_generated_scene: bool = false
var zone_kind_reason: String = ""
var zone_kind_evidence: Dictionary = {}


func add_error(message: String) -> void:
	if message == "":
		return
	errors.append(message)
	ok = false


func add_warning(message: String) -> void:
	if message == "":
		return
	warnings.append(message)


func set_branch(branch_name: String, branch: Node3D) -> void:
	if branch_name == "":
		return
	branches[branch_name] = branch
	if not branch_names.has(branch_name):
		branch_names.append(branch_name)


func has_branch(branch_name: String) -> bool:
	return branches.has(branch_name) and branches.get(branch_name) is Node3D


func branch_count() -> int:
	return branch_names.size()


func to_debug_dict(include_node_paths: bool = true) -> Dictionary:
	var branch_paths := {}
	if include_node_paths:
		for raw_name in branch_names:
			var branch_name := str(raw_name)
			var branch: Node = branches.get(branch_name, null) as Node
			branch_paths[branch_name] = branch.get_path() if branch != null and branch.is_inside_tree() else branch_name
	return {
		"scope": scope,
		"checkpoint": checkpoint,
		"ok": ok,
		"zone": zone,
		"root_name": root.name if root != null else "",
		"root_present": root != null,
		"branch_names": branch_names.duplicate(),
		"branch_count": branch_count(),
		"branch_paths": branch_paths,
		"source_snapshots": source_snapshots,
		"signatures": signatures,
		"metrics": metrics,
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"creation_mode": creation_mode,
		"attached_to_host": attached_to_host,
		"generated_scene_path": generated_scene_path,
		"exported_scene_path": exported_scene_path,
		"export_ok": export_ok,
		"export_error_code": export_error_code,
		"pack_error_code": pack_error_code,
		"file_exists_after_save": file_exists_after_save,
		"reload_ok": reload_ok,
		"reload_root_name": reload_root_name,
		"reload_branch_names": reload_branch_names.duplicate(),
		"export_mode": export_mode,
		"include_runtime_nodes": include_runtime_nodes,
		"recommended_next_step": recommended_next_step,
		"zone_kind": zone_kind,
		"generated_scene_status": generated_scene_status,
		"supported_for_generated_scene": supported_for_generated_scene,
		"zone_kind_reason": zone_kind_reason,
		"zone_kind_evidence": zone_kind_evidence,
	}
