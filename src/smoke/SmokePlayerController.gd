extends CharacterBody3D
class_name SmokePlayerController

@export var walk_speed: float = 1.7
@export var run_speed: float = 4.8
@export var gravity: float = 9.8
@export var turn_to_move: bool = true

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	if turn_to_move and input_dir.length() > 0.01:
		look_at(global_position + Vector3(input_dir.x, 0.0, input_dir.z), Vector3.UP)
