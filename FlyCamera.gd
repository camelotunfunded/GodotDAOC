extends Camera3D
## Free-fly camera (AZERTY). Left-click to capture mouse / look around, Échap to release.
## ZQSD move, A/E down/up, hold Shift to go faster.

@export var speed: float = 9000.0
@export var boost: float = 5.0
@export var sensitivity: float = 0.003

var _looking: bool = false


func _ready() -> void:
	far = 600000.0
	near = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_looking = event.pressed
		Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED if _looking
			else Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _looking:
		rotate_y(-event.relative.x * sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * sensitivity)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_Z): dir -= transform.basis.z   # avancer
	if Input.is_key_pressed(KEY_S): dir += transform.basis.z   # reculer
	if Input.is_key_pressed(KEY_Q): dir -= transform.basis.x   # gauche
	if Input.is_key_pressed(KEY_D): dir += transform.basis.x   # droite
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP          # monter
	if Input.is_key_pressed(KEY_A): dir -= Vector3.UP          # descendre
	if dir != Vector3.ZERO:
		var s := speed * (boost if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		position += dir.normalized() * s * delta
