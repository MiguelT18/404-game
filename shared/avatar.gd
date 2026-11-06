class_name Avatar
extends CharacterBody3D
## Cuerpo de un personaje. Sin nodos visuales: también corre en el servidor.

# shortcut: todos usan el héroe de la escena, cambia a un dato por jugador en M4.
@export var hero: HeroData


## Avanza un tick. Debe llamarse en `_physics_process`, porque `move_and_slide()`
## usa el delta del proceso activo.
func apply_input(move: Vector2, yaw: float) -> void:
	velocity = MoveRules.velocity(move, yaw, hero.move_speed)
	rotation.y = yaw
	move_and_slide()
