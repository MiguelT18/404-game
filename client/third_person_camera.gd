class_name ThirdPersonCamera
extends Node3D
## Cámara sobre el hombro. Su `yaw` es la dirección que se envía al servidor.

const SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.7
const HEAD_HEIGHT := 1.7
const SHOULDER_OFFSET := 0.8
const DISTANCE := 4.0

var target: Node3D
var yaw := 0.0

var _pitch := -0.2


func _ready() -> void:
	top_level = true
	# Sigue el transform ya interpolado del objetivo en cada fotograma.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var arm := SpringArm3D.new()
	arm.position.x = SHOULDER_OFFSET
	arm.spring_length = DISTANCE
	arm.collision_mask = 1
	arm.margin = 0.2
	add_child(arm)
	var camera := Camera3D.new()
	arm.add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)


func _process(_delta: float) -> void:
	rotation = Vector3(_pitch, yaw, 0.0)
	if target != null:
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * HEAD_HEIGHT
