class_name AbilityRunner
extends RefCounted
## Ejecuta las piezas de habilidad. Debe avanzar dentro del tick de física,
## porque comprueba los muros con rayos.

signal event_emitted(event: Array)

const WALL_MASK := 1
const HIT_HEIGHT := 1.0
const WALL_MARGIN := 0.6
const ZONE_PULSE := 0.5

var targets: Array[CombatTarget] = []

var _world: Node3D
var _next_id := 0
var _charges: Array = []
var _moves: Array = []
var _projectiles: Array = []
var _zones: Array = []


class Charge:
	var caster: CombatTarget
	var ability: AbilityData
	var aim: Vector3
	var left: float


class Move:
	var caster: CombatTarget
	var ability: AbilityData
	var from: Vector3
	var to: Vector3
	var elapsed := 0.0
	var duration: float
	var hit: Array[CombatTarget] = []


class Projectile:
	var id: int
	var caster: CombatTarget
	var ability: AbilityData
	var position: Vector3
	var direction: Vector3
	var traveled := 0.0


class Zone:
	var id: int
	var caster: CombatTarget
	var ability: AbilityData
	var position: Vector3
	var left: float
	var pulse_left := 0.0


func _init(world: Node3D) -> void:
	_world = world


func cast(caster: CombatTarget, ability: AbilityData, aim: Vector3) -> void:
	event_emitted.emit([Net.Event.CAST, caster.id, ability.id])
	if ability.cast_delay <= 0.0:
		_execute(caster, ability, aim)
		return
	caster.state.apply_stun(ability.cast_delay)
	var charge := Charge.new()
	charge.caster = caster
	charge.ability = ability
	charge.aim = aim
	charge.left = ability.cast_delay
	_charges.append(charge)


func tick(delta: float) -> void:
	_charges = _charges.filter(_advance_charge.bind(delta))
	_moves = _moves.filter(_advance_move.bind(delta))
	_projectiles = _projectiles.filter(_advance_projectile.bind(delta))
	_zones = _zones.filter(_advance_zone.bind(delta))


## Olvida lo que dependa del cuerpo de un jugador que se fue.
func remove(target: CombatTarget) -> void:
	targets.erase(target)
	_charges = _charges.filter(func(charge: Charge) -> bool: return charge.caster != target)
	_moves = _moves.filter(func(move: Move) -> bool: return move.caster != target)


func entities() -> Array:
	var list: Array = []
	for projectile: Projectile in _projectiles:
		list.append([projectile.id, Net.Entity.PROJECTILE, projectile.position, projectile.ability.id])
	for zone: Zone in _zones:
		list.append([zone.id, Net.Entity.ZONE, zone.position, zone.ability.id])
	return list


func _execute(caster: CombatTarget, ability: AbilityData, aim: Vector3) -> void:
	var origin := caster.position()
	var direction := CombatRules.direction(origin, aim, caster.forward())
	match ability.kind:
		AbilityData.Kind.CONE:
			_cast_cone(caster, ability, direction)
		AbilityData.Kind.PROJECTILE:
			_cast_projectile(caster, ability, direction)
		AbilityData.Kind.AREA:
			var center := origin if ability.reach == 0.0 else CombatRules.clamp_aim(origin, aim, ability.reach)
			_hit_area(caster, ability, center)
		AbilityData.Kind.DASH:
			_start_move(caster, ability, origin + direction * ability.reach, ability.reach / ability.speed)
		AbilityData.Kind.SHIELD:
			caster.state.add_shield(ability.shield, ability.duration)
			_effect(caster, origin, origin, CombatRules.BODY_RADIUS * 2.0, ability)
		AbilityData.Kind.ZONE:
			_cast_zone(caster, ability, CombatRules.clamp_aim(origin, aim, ability.reach))
		AbilityData.Kind.BLINK:
			var destination := _free_point(origin, CombatRules.clamp_aim(origin, aim, ability.reach))
			caster.body.global_position = destination
			_effect(caster, origin, destination, 0.0, ability)
		AbilityData.Kind.LEAP:
			_start_move(caster, ability, CombatRules.clamp_aim(origin, aim, ability.reach), ability.duration)
		AbilityData.Kind.BEAM:
			_cast_beam(caster, ability, direction)


func _cast_cone(caster: CombatTarget, ability: AbilityData, direction: Vector3) -> void:
	var origin := caster.position()
	for target in _enemies(caster):
		if CombatRules.in_cone(origin, direction, target.position(), ability.reach, ability.angle):
			_hit(target, ability)
	_effect(caster, origin, origin + direction * ability.reach, 0.0, ability)


func _cast_projectile(caster: CombatTarget, ability: AbilityData, direction: Vector3) -> void:
	var projectile := Projectile.new()
	projectile.id = _new_id()
	projectile.caster = caster
	projectile.ability = ability
	projectile.position = caster.position()
	projectile.direction = direction
	_projectiles.append(projectile)


func _cast_zone(caster: CombatTarget, ability: AbilityData, center: Vector3) -> void:
	var zone := Zone.new()
	zone.id = _new_id()
	zone.caster = caster
	zone.ability = ability
	zone.position = center
	zone.left = ability.duration
	_zones.append(zone)


func _cast_beam(caster: CombatTarget, ability: AbilityData, direction: Vector3) -> void:
	var origin := caster.position()
	var end := _wall_point(origin, origin + direction * ability.reach)
	for target in _enemies(caster):
		if CombatRules.hits_segment(origin, end, target.position(), ability.radius):
			_hit(target, ability)
	_effect(caster, origin, end, 0.0, ability)


func _start_move(caster: CombatTarget, ability: AbilityData, to: Vector3, duration: float) -> void:
	var move := Move.new()
	move.caster = caster
	move.ability = ability
	move.from = caster.position()
	move.to = _free_point(move.from, to)
	# Lanzado en el aire, termina en el suelo.
	move.to.y = caster.spawn_position.y
	move.duration = duration
	caster.state.apply_stun(duration)
	_moves.append(move)


func _advance_charge(charge: Charge, delta: float) -> bool:
	charge.left -= delta
	if charge.left > 0.0:
		return charge.caster.state.is_alive()
	if charge.caster.state.is_alive():
		_execute(charge.caster, charge.ability, charge.aim)
	return false


func _advance_move(move: Move, delta: float) -> bool:
	if not move.caster.state.is_alive():
		return false
	move.elapsed += delta
	var weight := minf(move.elapsed / move.duration, 1.0)
	move.caster.body.global_position = move.from.lerp(move.to, weight)
	if move.ability.kind == AbilityData.Kind.DASH:
		for target in _enemies(move.caster):
			if target not in move.hit and CombatRules.in_radius(move.caster.position(), target.position(), move.ability.radius):
				move.hit.append(target)
				_hit(target, move.ability)
	if weight < 1.0:
		return true
	if move.ability.kind == AbilityData.Kind.LEAP:
		_hit_area(move.caster, move.ability, move.to)
	return false


func _advance_projectile(projectile: Projectile, delta: float) -> bool:
	var ability := projectile.ability
	var step := minf(ability.speed * delta, ability.reach - projectile.traveled)
	var next := projectile.position + projectile.direction * step
	var stop := _wall_point(projectile.position, next)
	for target in _enemies(projectile.caster):
		if CombatRules.hits_segment(projectile.position, stop, target.position(), ability.radius):
			_hit(target, ability)
			return false
	projectile.position = stop
	projectile.traveled += step
	return stop == next and projectile.traveled < ability.reach


func _advance_zone(zone: Zone, delta: float) -> bool:
	zone.left -= delta
	zone.pulse_left -= delta
	if zone.pulse_left <= 0.0:
		zone.pulse_left = ZONE_PULSE
		for target in _enemies(zone.caster):
			if CombatRules.in_radius(zone.position, target.position(), zone.ability.radius):
				_hit(target, zone.ability)
	return zone.left > 0.0


func _hit_area(caster: CombatTarget, ability: AbilityData, center: Vector3) -> void:
	for target in _enemies(caster):
		if CombatRules.in_radius(center, target.position(), ability.radius):
			_hit(target, ability)
	_effect(caster, center, center, ability.radius, ability)


func _hit(target: CombatTarget, ability: AbilityData) -> void:
	var dealt := target.state.take_damage(ability.damage, ability.damage_type)
	event_emitted.emit([Net.Event.DAMAGE, target.id, dealt, ability.damage_type, target.position()])
	if not target.state.is_alive():
		target.respawn_left = target.respawn_delay
		event_emitted.emit([Net.Event.DEATH, target.id])
		return
	if ability.slow > 0.0:
		target.state.apply_slow(ability.slow, ability.slow_duration)
	if ability.stun > 0.0:
		target.state.apply_stun(ability.stun)


func _effect(caster: CombatTarget, from: Vector3, to: Vector3, radius: float, ability: AbilityData) -> void:
	event_emitted.emit([Net.Event.EFFECT, from, to, radius, caster.id, ability.id])


# shortcut: todos son enemigos entre sí, los equipos llegan en M3.
func _enemies(caster: CombatTarget) -> Array[CombatTarget]:
	return targets.filter(func(target: CombatTarget) -> bool:
		return target != caster and target.state.is_alive())


## Punto más lejano hacia `to` sin quedar dentro de un muro.
func _free_point(from: Vector3, to: Vector3) -> Vector3:
	var stop := _wall_point(from, to)
	if stop == to:
		return to
	return from.move_toward(stop, maxf(from.distance_to(stop) - WALL_MARGIN, 0.0))


func _wall_point(from: Vector3, to: Vector3) -> Vector3:
	var height := Vector3.UP * HIT_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from + height, to + height, WALL_MASK)
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	return to if hit.is_empty() else hit.position - height


func _new_id() -> int:
	_next_id += 1
	return _next_id
