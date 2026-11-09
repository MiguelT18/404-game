class_name ThirdPersonCamera
extends Node3D
## Cámara sobre el hombro. Su `yaw` es la dirección que se envía al servidor.

const SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.7
const HEAD_HEIGHT := 1.7
const SHOULDER_OFFSET := 0.8
const DISTANCE := 4.0
const AIM_DISTANCE := 60.0
# Muros, personajes y muñecos.
const AIM_MASK := 0b111
# El temblor se mide de 0 a 1 y se apaga solo; mueve la imagen, no la mira.
const SHAKE_DECAY := 2.5
const SHAKE_OFFSET := 0.3

var target: Node3D
var yaw := 0.0

var _pitch := -0.2
var _camera: Camera3D
var _recapturing := false
var _trauma := 0.0


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
	_camera = Camera3D.new()
	arm.add_child(_camera)
	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		if not event.pressed:
			_recapturing = false
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_recapturing = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	rotation = Vector3(_pitch, yaw, 0.0)
	_trauma = maxf(_trauma - delta * SHAKE_DECAY, 0.0)
	var offset := _trauma * _trauma * SHAKE_OFFSET
	_camera.h_offset = randf_range(-offset, offset)
	_camera.v_offset = randf_range(-offset, offset)
	if target != null:
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * HEAD_HEIGHT


## Falso con el ratón libre o mientras dura el clic que lo recapturó.
func can_aim() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _recapturing


## Punto bajo la mira. Debe llamarse en el tick de física.
func aim_point(exclude: Array[RID]) -> Vector3:
	var from := _camera.global_position
	var forward := -_camera.global_basis.z
	var point := from + forward * AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, point, AIM_MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point = hit.position
	# El suelo no tiene colisión, así que se corta el rayo con el plano Y = 0.
	if forward.y < 0.0:
		var ground := from + forward * (-from.y / forward.y)
		if from.distance_to(ground) < from.distance_to(point):
			point = ground
	return point


func shake(strength: float) -> void:
	_trauma = clampf(maxf(_trauma, strength), 0.0, 1.0)
