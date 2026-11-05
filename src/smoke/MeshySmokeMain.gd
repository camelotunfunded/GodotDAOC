extends Node3D

const MeshySwapScript = preload("res://src/daoc/player/DaocPlayerVisualMeshySwap.gd")
const SmokePlayerControllerScript = preload("res://src/smoke/SmokePlayerController.gd")

var player: CharacterBody3D = null
var swap: RefCounted = null
var label: Label = null
var visual_enabled: bool = true

func _ready() -> void:
	_build_world()
	swap = MeshySwapScript.new()
	_attach_meshy()
	print("P1-18M smoke project ready. WASD move, Shift run, F1 toggle visual, F2 idle, F3 walk, F4 run.")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("visual_toggle"):
		if visual_enabled:
			_detach_meshy()
		else:
			_attach_meshy()
	if Input.is_action_just_pressed("visual_idle"):
		_force_state("idle")
	if Input.is_action_just_pressed("visual_walk"):
		_force_state("walk")
	if Input.is_action_just_pressed("visual_run"):
		_force_state("run")
	_update_label()


func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.55)
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	sun.light_energy = 2.0
	add_child(sun)

	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	ground_mesh.mesh = plane
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 0.1, 12.0)
	ground_shape.shape = box
	ground_shape.position = Vector3(0.0, -0.05, 0.0)
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(SmokePlayerControllerScript)
	player.position = Vector3(0.0, 0.95, 0.0)
	add_child(player)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	player.add_child(collision)

	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "DebugPlayerCapsuleMesh"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.8
	debug_mesh.mesh = capsule_mesh
	player.add_child(debug_mesh)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 2.3, 5.0)
	camera.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	camera.current = true
	player.add_child(camera)

	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	label = Label.new()
	label.name = "Info"
	label.position = Vector2(12.0, 12.0)
	label.text = "P1-18M Meshy Smoke"
	canvas.add_child(label)
	add_child(canvas)


func _attach_meshy() -> void:
	if swap == null:
		swap = MeshySwapScript.new()
	var report: Dictionary = swap.call("attach_to_player", player, {
		"visual_scale": 100.0,
		"ground_offset": 0.0,
		"yaw_degrees": 180.0,
		"walk_threshold": 0.05,
		"run_threshold": 4.0,
	}) as Dictionary
	visual_enabled = bool(report.get("ok", false))
	print("Meshy attach report: ", JSON.stringify(report))


func _detach_meshy() -> void:
	if swap == null:
		return
	var report: Dictionary = swap.call("detach_from_player", player, false) as Dictionary
	visual_enabled = false
	print("Meshy detach report: ", JSON.stringify(report))


func _force_state(state: String) -> void:
	if swap == null:
		return
	var report: Dictionary = swap.call("force_state", player, state) as Dictionary
	print("Meshy force %s: %s" % [state, JSON.stringify(report)])


func _update_label() -> void:
	if label == null or player == null:
		return
	var speed := 0.0
	var velocity_value: Variant = player.get("velocity")
	if typeof(velocity_value) == TYPE_VECTOR3:
		var velocity_vec: Vector3 = velocity_value
		speed = velocity_vec.length()
	var state := "unknown"
	var root := player.get_node_or_null("DaocPlayerVisualRoot")
	if root != null and root.has_method("build_status_report"):
		var status: Dictionary = root.call("build_status_report") as Dictionary
		state = str(status.get("current_state", "unknown"))
	label.text = "P1-18M Meshy Smoke\nWASD move | Shift run | F1 toggle | F2 idle | F3 walk | F4 run\nvisual=%s state=%s speed=%.2f scale=100" % [str(visual_enabled), state, speed]
