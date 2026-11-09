class_name CombatRules
extends RefCounted
## Reglas puras de combate. La geometría es plana: solo cuentan X y Z.

const BODY_RADIUS := 0.5


static func mitigate(damage: float, resistance: float) -> float:
	return damage * 100.0 / (100.0 + maxf(resistance, 0.0))


static func respawn_time(level: int) -> float:
	return 5.0 + 2.0 * level


static func flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Dirección plana hacia `aim`, o `fallback` si `aim` está encima de `origin`.
static func direction(origin: Vector3, aim: Vector3, fallback: Vector3) -> Vector3:
	var offset := flat(aim) - flat(origin)
	if offset.length() < 0.01:
		return fallback
	var unit := offset.normalized()
	return Vector3(unit.x, 0.0, unit.y)


## Recorta `aim` al alcance, a la altura de `origin`.
static func clamp_aim(origin: Vector3, aim: Vector3, reach: float) -> Vector3:
	var offset := (flat(aim) - flat(origin)).limit_length(reach)
	return origin + Vector3(offset.x, 0.0, offset.y)


static func in_radius(center: Vector3, point: Vector3, radius: float) -> bool:
	return flat(center).distance_to(flat(point)) <= radius + BODY_RADIUS


## `angle` es la apertura total en grados y `forward` debe ser unitario.
static func in_cone(origin: Vector3, forward: Vector3, point: Vector3, reach: float, angle: float) -> bool:
	if not in_radius(origin, point, reach):
		return false
	var offset := flat(point) - flat(origin)
	if offset.length() <= BODY_RADIUS:
		return true
	return absf(flat(forward).angle_to(offset)) <= deg_to_rad(angle) / 2.0


static func hits_segment(from: Vector3, to: Vector3, point: Vector3, radius: float) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(flat(point), flat(from), flat(to))
	return closest.distance_to(flat(point)) <= radius + BODY_RADIUS
