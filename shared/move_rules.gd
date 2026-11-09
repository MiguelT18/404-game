class_name MoveRules
extends RefCounted
## Reglas puras de movimiento, iguales en servidor y predicción.

const GRAVITY := 20.0


static func is_valid_input(seq: int, last_seq: int, move: Vector2, yaw: float) -> bool:
	return seq > last_seq and move.is_finite() and is_finite(yaw)


## `move.y` negativo es hacia delante, como devuelve `Input.get_vector()`.
static func velocity(move: Vector2, yaw: float, speed: float) -> Vector3:
	var clamped := move.limit_length(1.0)
	return Vector3(clamped.x, 0.0, clamped.y).rotated(Vector3.UP, yaw) * speed


## Solo se salta desde el suelo: pedirlo en el aire no cambia nada.
static func vertical_speed(current: float, grounded: bool, jump: bool, jump_speed: float, delta: float) -> float:
	if grounded:
		return jump_speed if jump else 0.0
	return current - GRAVITY * delta
