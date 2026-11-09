class_name Avatar
extends CharacterBody3D
## Cuerpo de un personaje. Sin nodos visuales: también corre en el servidor.

const GROUND_HEIGHT := 0.0

var hero: HeroData
var move_factor := 1.0
var vertical_speed := 0.0


## Avanza un tick. Debe llamarse en `_physics_process`, porque `move_and_slide()`
## usa el delta del proceso activo.
func apply_input(move: Vector2, yaw: float, jump := false) -> void:
	var grounded := global_position.y <= GROUND_HEIGHT
	var can_jump := jump and move_factor > 0.0
	var delta := get_physics_process_delta_time()
	vertical_speed = MoveRules.vertical_speed(vertical_speed, grounded, can_jump, hero.jump_speed, delta)
	velocity = MoveRules.velocity(move, yaw, hero.move_speed * move_factor)
	rotation.y = yaw
	move_and_slide()
	# Va aparte: al deslizar por un muro, `move_and_slide()` convertiría la velocidad
	# horizontal en subida. El suelo no tiene colisión, así que se aterriza a mano.
	global_position.y += vertical_speed * delta
	if global_position.y < GROUND_HEIGHT:
		global_position.y = GROUND_HEIGHT
		vertical_speed = 0.0
