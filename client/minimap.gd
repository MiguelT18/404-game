class_name Minimap
extends Control
## Mapa de la esquina. Se genera del mapa de la partida, con el norte (-Z) arriba.

const MARGIN := 1.0
const BACKGROUND := Color(0.08, 0.1, 0.13, 0.85)
const FLOOR_COLOR := Color(0.32, 0.36, 0.4)
const BLOCK_COLOR := Color(0.72, 0.74, 0.78)
const BORDER_COLOR := Color(0.85, 0.88, 0.92)
const DUMMY_COLOR := Color(0.75, 0.75, 0.75)
const ENEMY_COLOR := Color(0.95, 0.25, 0.25)
const OWN_COLOR := Color(0.35, 1.0, 0.5)
const DOT_RADIUS := 5.0
const ARROW_SIZE := 11.0

var _floor := Rect2()
var _bounds := Rect2(0, 0, 1, 1)
var _blocks: Array[Rect2] = []
var _dummies: Array[Vector3] = []
var _own_position := Vector3.INF
var _own_yaw := 0.0
var _enemies: Array[Vector3] = []


## Convierte un punto del mundo (X, Z) a píxeles, centrando el mapa en `size`.
static func to_minimap(world: Vector2, bounds: Rect2, size: Vector2) -> Vector2:
	var scale := minf(size.x / bounds.size.x, size.y / bounds.size.y)
	return (world - bounds.get_center()) * scale + size / 2.0


func setup(map: Node3D) -> void:
	var aabb: AABB = map.get_node("Floor").get_aabb()
	_floor = Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
	_bounds = _floor.grow(MARGIN)
	for child in map.get_children():
		if child is StaticBody3D and child.has_node("Shape"):
			var shape: Shape3D = child.get_node("Shape").shape
			if shape is BoxShape3D:
				var extent := Vector2(shape.size.x, shape.size.z)
				_blocks.append(Rect2(CombatRules.flat(child.position) - extent / 2.0, extent))
	if map.has_node("Dummies"):
		for dummy: Node3D in map.get_node("Dummies").get_children():
			_dummies.append(dummy.position)
	queue_redraw()


func show_units(own_position: Vector3, own_yaw: float, enemies: Array[Vector3]) -> void:
	_own_position = own_position
	_own_yaw = own_yaw
	_enemies = enemies
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(_to_rect(_floor), FLOOR_COLOR)
	for block in _blocks:
		draw_rect(_to_rect(block), BLOCK_COLOR)
	for dummy in _dummies:
		draw_circle(_to_pixels(dummy), DOT_RADIUS - 1.0, DUMMY_COLOR)
	for enemy in _enemies:
		draw_circle(_to_pixels(enemy), DOT_RADIUS, ENEMY_COLOR)
	if _own_position != Vector3.INF:
		_draw_own_arrow()
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)


func _draw_own_arrow() -> void:
	var center := _to_pixels(_own_position)
	var forward := Vector2(-sin(_own_yaw), -cos(_own_yaw))
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		center + forward * ARROW_SIZE,
		center - forward * ARROW_SIZE * 0.6 + side * ARROW_SIZE * 0.7,
		center - forward * ARROW_SIZE * 0.6 - side * ARROW_SIZE * 0.7,
	]), OWN_COLOR)


func _to_pixels(world: Vector3) -> Vector2:
	return to_minimap(CombatRules.flat(world), _bounds, size)


func _to_rect(rect: Rect2) -> Rect2:
	var from := to_minimap(rect.position, _bounds, size)
	return Rect2(from, to_minimap(rect.end, _bounds, size) - from)
