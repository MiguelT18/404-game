class_name Prediction
extends RefCounted
## Entradas ya aplicadas en el cliente que el servidor aún no confirmó.

# Tres segundos de ticks: evita crecer sin límite si el servidor deja de responder.
const MAX_PENDING := 90

var pending: Array[Dictionary] = []


func record(seq: int, move: Vector2, yaw: float) -> void:
	pending.append({"seq": seq, "move": move, "yaw": yaw})
	if pending.size() > MAX_PENDING:
		pending.pop_front()


func acknowledge(seq: int) -> void:
	while not pending.is_empty() and pending[0].seq <= seq:
		pending.pop_front()
