extends SubViewportContainer
class_name DaocCharacterPreview

signal model_ready(model: Node3D)

const DaocPlayerVisualRuntimeScript = preload("res://src/daoc/player/DaocPlayerVisualRuntime.gd")
const AnimationPresentation = preload("res://src/daoc/player/DaocAnimationPresentation.gd")

## L'apercu 3D de l'ecran de selection.
##
## Jusqu'au 2026-09-15 il montrait un seul GLB Meshy generique, quel que soit
## le personnage clique. Il instancie desormais la scene que
## `DaocPlayableRoster.preview_scene_for` designe : la meme que celle que le
## jeu montera. Les scenes exportees du Lab sont en unites NIF (~70 de haut) ;
## elles sont ramenees a `TARGET_HEIGHT` metres pour la camera de la vue.
##
## Le viewport a son PROPRE monde (`own_world_3d`) : sans cela son
## WorldEnvironment et sa lumiere entrent dans le monde du jeu et le ciel
## devient gris — c'est arrive le 2026-09-14.

const RosterScript = preload("res://src/daoc/ui/pregame/DaocPlayableRoster.gd")
const DEFAULT_MODEL := "res://assets/daoc/player/meshy/Meshy_AI_T_Pose_Character_Mode_biped_Animation_Walking_withSkin.glb"
const TARGET_HEIGHT := 2.2
const FLOOR_Y := -0.28

var _character: Dictionary = {}
var _model: Node3D = null
var _model_scene_path := ""
var _yaw := 0.0
var _last_report: Dictionary = {}
var animation_polish_enabled := true
## P1-129 : de face, sans balancement. Selection : le clip « idle » JOUE en
## boucle ; inventaire (`set_static_pose(true)`) : fige dans la pose neutre.
var static_pose := false
## Instant du clip « idle » ou les bras tombent le long du corps (0..1).
var neutral_fraction := 0.22
## P1-129 — l apercu de SELECTION s habille avec l equipement de l overview
## (0xFD : 20 modeles, meme code qu en jeu) : tenue nue de la race, armure,
## armes du jeu actif. L inventaire le coupe : il habille avec le 0x02.
var dress_from_overview := true
## Index du tableau `equipment` de l overview -> eInventorySlot (mesure sur Vcx :
## 62 casque, 34 gants, 133 bottes, 31 torse, 32 jambes, 33 bras, 13/59/19 armes).
const OVERVIEW_EQUIPMENT_SLOTS := {0: 21, 1: 22, 2: 23, 4: 25, 5: 26, 6: 27, 7: 28, 16: 10, 17: 11, 18: 12, 19: 13}
static var _dressers: Dictionary = {}

@onready var character_root: Node3D = $Viewport/CharacterRoot


func _ready() -> void:
	animation_polish_enabled = AnimationPresentation.load_enabled(true)
	visible = false
	set_process(true)


func show_character(data: Dictionary) -> void:
	_character = data.duplicate(true)
	var valid := bool(data.get("valid", false)) and str(data.get("name", "")) != ""
	visible = valid
	if not valid:
		return
	var scene_path := RosterScript.preview_scene_for(_character)
	if scene_path == "":
		scene_path = DEFAULT_MODEL
	_ensure_model(scene_path)
	if _model != null:
		_model.visible = true
		_dress_from_overview()


func clear_character() -> void:
	_character = {}
	visible = false
	if _model != null:
		_model.visible = false


func set_presentation_yaw(degrees: float) -> void:
	_yaw = deg_to_rad(degrees)
	if character_root != null:
		character_root.rotation.y = _yaw


func status_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"character_valid": not _character.is_empty() and bool(_character.get("valid", false)),
		"scene_path": _model_scene_path,
		"scene_exists": _model_scene_path != "" and ResourceLoader.exists(_model_scene_path),
		"instantiated": _model != null,
		"meshy_path": DEFAULT_MODEL,
		"meshy_exists": ResourceLoader.exists(DEFAULT_MODEL),
		"meshy_instantiated": _model != null and _model_scene_path == DEFAULT_MODEL,
		"transparent_viewport": bool($Viewport.transparent_bg),
		"own_world": bool($Viewport.own_world_3d),
		"report": _last_report.duplicate(true),
	}


func _process(_delta: float) -> void:
	pass  # P1-129 : plus de balancement ; l idle anime la selection.


func _ensure_model(scene_path: String) -> void:
	if _model != null and _model_scene_path == scene_path:
		return
	if _model != null:
		_model.queue_free()
		_model = null
		_model_scene_path = ""
	if not ResourceLoader.exists(scene_path):
		_last_report = {"ok": false, "reason": "scene absente", "scene": scene_path}
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_last_report = {"ok": false, "reason": "scene illisible", "scene": scene_path}
		return
	_model = packed.instantiate() as Node3D
	preload("res://src/daoc/assets/DaocMeshWindingFix.gd").apply(_model)
	if _model == null:
		_last_report = {"ok": false, "reason": "racine non 3D", "scene": scene_path}
		return
	# L'apercu doit passer par la meme correction de skin que le personnage en
	# jeu. Elle parcourt recursivement le corps et chaque item skinné, quelle que
	# soit la race ou la combinaison d'equipement exportee par le Lab.
	var skin_runtime := DaocPlayerVisualRuntimeScript.new()
	skin_runtime.call("_remap_left_forearm_skins", _model)
	skin_runtime.free()
	_model_scene_path = scene_path
	character_root.add_child(_model)
	if scene_path == DEFAULT_MODEL:
		_model.position = Vector3(0.0, -1.15, 0.0)
		_model.scale = Vector3.ONE * 1.25
	else:
		_fit_daoc_scene()
	_pose_first_animation()
	_last_report = {"ok": true, "scene": scene_path, "scale": _model.scale.x, "height": _measured_height()}
	# P1-128 : une scene pre-cuite porte toutes les armes ; seul le jeu actif
	# de l overview reste visible (avant model_ready : l inventaire rhabille ensuite).
	_last_report["weapons"] = DaocPlayerEquipmentVisuals.filter_baked_weapons(_model,
		DaocPlayerEquipmentVisuals.active_weapon_slots_from_overview(_character))
	model_ready.emit(_model)


func set_animation_polish_enabled(enabled: bool) -> void:
	animation_polish_enabled = enabled
	if _model != null:
		AnimationPresentation.apply_to_tree(_model, enabled)
		_pose_first_animation()


## Ramene une scene en unites NIF a une hauteur de vue. La hauteur est MESUREE
## sur les maillages plutot que lue dans le manifeste : une scene sans
## manifeste reste affichable.
func _fit_daoc_scene() -> void:
	# Le manifeste du Lab porte la hauteur native (~70) et les scenes ont leurs
	# pieds a l'origine. L'AABB des maillages skinnes est trop large (le Troll
	# mesure 124 en bind pose) : il ne sert que de repli sans manifeste.
	var height := _manifest_native_height(_model_scene_path)
	var feet_at_origin := height > 0.0
	if height <= 0.0:
		height = _measured_height()
	if height <= 0.0:
		height = 70.0
	var factor := TARGET_HEIGHT / height
	_model.scale = Vector3.ONE * factor
	var min_y := 0.0
	if not feet_at_origin:
		var bounds := _model_bounds()
		min_y = bounds.position.y if bounds.size != Vector3.ZERO else 0.0
	_model.position = Vector3(0.0, FLOOR_Y - min_y * factor, 0.0)


static func _manifest_native_height(scene_path: String) -> float:
	var manifest_path := scene_path.get_basename() + ".manifest.json"
	if not FileAccess.file_exists(manifest_path):
		return 0.0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return 0.0
	var contract: Variant = (parsed as Dictionary).get("scale_contract", {})
	if not contract is Dictionary:
		return 0.0
	return float((contract as Dictionary).get("native_height", 0.0))


func _measured_height() -> float:
	var bounds := _model_bounds()
	return bounds.size.y if bounds.size != Vector3.ZERO else 0.0


func _model_bounds() -> AABB:
	var result := AABB()
	var first := true
	for child in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		var relative: Transform3D = _model.global_transform.affine_inverse() * mi.global_transform if _model.is_inside_tree() else mi.transform
		var box := relative * local
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _pose_first_animation() -> void:
	for child in _model.find_children("*", "AnimationPlayer", true, false):
		var player := child as AnimationPlayer
		AnimationPresentation.apply_to_player(player, animation_polish_enabled)
		var preferred := neutral_animation_name(player.get_animation_list())
		if preferred == "":
			continue
		var animation := player.get_animation(preferred)
		player.play(preferred, AnimationPresentation.blend_seconds(animation_polish_enabled))
		# Le début du clip idle de plusieurs exports correspond à la garde de
		# combat. Un peu plus loin, les bras sont revenus dans l'attente neutre.
		var is_locomotion := preferred.to_lower().contains("walk") or preferred.to_lower().contains("run")
		var neutral_time := 0.0 if is_locomotion else minf(animation.length * neutral_fraction, 0.42)
		player.seek(neutral_time, true)
		if static_pose:
			player.pause()
		else:
			animation.loop_mode = Animation.LOOP_LINEAR
		break


func set_static_pose(value: bool) -> void:
	static_pose = value
	set_process(not static_pose)
	if _model != null:
		_pose_first_animation()
	if character_root != null:
		character_root.rotation.y = _yaw


func model_root() -> Node3D:
	return _model


func _dress_from_overview() -> void:
	if not dress_from_overview or _model == null:
		return
	var raw: Dictionary = _character.get("raw", {}) as Dictionary
	var equipment: Array = _character.get("equipment", raw.get("equipment", [])) as Array
	var active := DaocPlayerEquipmentVisuals.active_weapon_slots_from_overview(_character)
	var appearance_id := DaocPlayerCatalogAppearance.appearance_for_character(_character)
	var client_root := DaocClientRoot.resolve_path(OS.get_environment("DAOC_CLIENT_ROOT"))
	if appearance_id <= 0 or client_root == "":
		_last_report["weapons"] = DaocPlayerEquipmentVisuals.filter_baked_weapons(_model, active)
		return
	if not _dressers.has(appearance_id):
		var dresser := DaocPlayerEquipmentVisuals.new()
		dresser.configure(client_root, appearance_id, "male" if appearance_id % 2 == 1 else "female")
		_dressers[appearance_id] = dresser
	var equipped: Dictionary = {}
	for index_value in OVERVIEW_EQUIPMENT_SLOTS.keys():
		var index := int(index_value)
		if index < equipment.size() and int(equipment[index]) > 0:
			equipped[int(OVERVIEW_EQUIPMENT_SLOTS[index])] = {"model": int(equipment[index])}
	_last_report["dressed"] = (_dressers[appearance_id] as DaocPlayerEquipmentVisuals).apply([_model], equipped, active)


## P1-129 — le clip de la pose neutre : « idle » exact d abord, jamais la garde
## de combat (`combat_idle`) ni l assise (`sit_idle`) qui pouvaient passer
## avant lui selon l ordre de la bibliotheque.
static func neutral_animation_name(names: PackedStringArray) -> String:
	var fallback := ""
	for value in names:
		var lower := str(value).to_lower()
		if lower == "idle" or lower.ends_with("/idle"):
			return str(value)
		if fallback == "" and lower.contains("idle") and not lower.contains("combat") and not lower.contains("sit"):
			fallback = str(value)
	if fallback == "":
		for value in names:
			var lower := str(value).to_lower()
			if lower != "reset" and not lower.contains("combat") and not lower.contains("sit") and not lower.contains("stand_up"):
				return str(value)
	return fallback
