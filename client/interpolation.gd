class_name Interpolation
extends RefCounted
## Muestras de una entidad remota, reproducidas con retraso para verla suave.

const DELAY := 0.1
const MAX_CLOCK_DRIFT := 0.25
const CLOCK_CORRECTION := 0.1

var _samples: Array[Dictionary] = []


## Acerca el reloj local al del servidor sin saltos, salvo que esté muy lejos.
static func sync_clock(clock: float, server_time: float) -> float:
	var drift := server_time - clock
	return server_time if absf(drift) > MAX_CLOCK_DRIFT else clock + drift * CLOCK_CORRECTION


func push(time: float, position: Vector3, yaw: float) -> void:
	_samples.append({"time": time, "position": position, "yaw": yaw})


## Devuelve {position, yaw}, o un diccionario vacío si aún no hay muestras.
## Fuera del rango conocido se queda en el extremo: no extrapola.
func sample(time: float) -> Dictionary:
	if _samples.is_empty():
		return {}
	while _samples.size() >= 2 and _samples[1].time <= time:
		_samples.pop_front()
	var from: Dictionary = _samples[0]
	if _samples.size() == 1 or time <= from.time:
		return from
	var to: Dictionary = _samples[1]
	var weight: float = (time - from.time) / (to.time - from.time)
	return {
		"position": from.position.lerp(to.position, weight),
		"yaw": lerp_angle(from.yaw, to.yaw, weight),
	}
