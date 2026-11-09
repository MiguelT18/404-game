extends Node3D
## Hace flotar y girar una pieza del modelo, como el orbe del bastón del Arcanista.
## Es solo presentación: oscila alrededor de su reposo y no mueve `Weapon/Tip`.

@export var spin_speed := 1.6
@export var bob_height := 0.03
@export var bob_speed := 2.2

var _rest: Vector3
var _time := 0.0


func _ready() -> void:
	_rest = position
	# Se mueve cada fotograma, así que no necesita interpolar entre ticks de física.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_time += delta
	rotate_y(spin_speed * delta)
	position = _rest + Vector3.UP * sin(_time * bob_speed) * bob_height
