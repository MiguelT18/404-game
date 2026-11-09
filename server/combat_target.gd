class_name CombatTarget
extends RefCounted
## Algo que puede recibir daño: un jugador (id positivo) o un muñeco (id negativo).

var id: int
var body: Node3D
var state: CombatState
var respawn_delay: float
var spawn_position: Vector3
var respawn_left := 0.0


func _init(target_id: int, target_body: Node3D, target_state: CombatState, delay: float) -> void:
	id = target_id
	body = target_body
	state = target_state
	respawn_delay = delay
	spawn_position = target_body.global_position


func position() -> Vector3:
	return body.global_position


func forward() -> Vector3:
	return -body.global_basis.z
