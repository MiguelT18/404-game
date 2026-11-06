class_name InputQueue
extends RefCounted
## Entradas validadas de un jugador. El servidor consume una por tick, así que
## enviar más entradas no da más velocidad.

const MAX_SIZE := 6

var last_seq := 0
var _items: Array[Dictionary] = []


func push(seq: int, move: Vector2, yaw: float) -> bool:
	if not MoveRules.is_valid_input(seq, last_seq, move, yaw):
		return false
	last_seq = seq
	_items.append({"seq": seq, "move": move, "yaw": yaw})
	if _items.size() > MAX_SIZE:
		_items.pop_front()
	return true


## Devuelve un diccionario vacío si no hay entradas.
func pop() -> Dictionary:
	return {} if _items.is_empty() else _items.pop_front()
