extends Node
## Protocolo de red. Los RPC viven aquí porque Godot exige la misma ruta de nodo
## en ambos lados; servidor y cliente solo escuchan estas señales.

signal hello_received(peer_id: int, version: String, hero_id: String)
signal input_received(peer_id: int, seq: int, move: Vector2, yaw: float, jump: bool)
signal cast_received(peer_id: int, slot: int, aim: Vector3)
signal welcomed(mode_id: String, peer_id: int)
signal rejected(reason: String)
signal snapshot_received(tick: int, states: Array, entities: Array)
signal combat_event_received(event: Array)

## Posición de cada campo en el estado de un jugador.
enum State { PEER, POSITION, YAW, SEQ, HERO, HEALTH, MANA, SHIELD, MOVE_FACTOR, COOLDOWNS, ALIVE, RESPAWN_LEFT, VERTICAL_SPEED }
## Entidades de la instantánea:
## DUMMY [id, tipo, posición, vida, vida máxima]
## PROJECTILE [id, tipo, posición, id de la habilidad]
## ZONE [id, tipo, posición, id de la habilidad]
enum Entity { DUMMY, PROJECTILE, ZONE }
## Eventos de combate:
## DAMAGE [tipo, id, daño, tipo de daño, posición]
## DEATH [tipo, id]
## EFFECT [tipo, desde, hasta, radio, id del lanzador, id de la habilidad]
## CAST [tipo, id del lanzador, id de la habilidad]: empieza un lanzamiento o su carga.
enum Event { DAMAGE, DEATH, EFFECT, CAST }

const INPUT_CHANNEL := 1
const SNAPSHOT_CHANNEL := 2


func game_version() -> String:
	return ProjectSettings.get_setting("application/config/version")


@rpc("any_peer", "call_remote", "reliable")
func hello(version: String, hero_id: String) -> void:
	if multiplayer.is_server():
		hello_received.emit(multiplayer.get_remote_sender_id(), version, hero_id)


@rpc("any_peer", "call_remote", "unreliable_ordered", INPUT_CHANNEL)
func submit_input(seq: int, move: Vector2, yaw: float, jump: bool) -> void:
	if multiplayer.is_server():
		input_received.emit(multiplayer.get_remote_sender_id(), seq, move, yaw, jump)


@rpc("any_peer", "call_remote", "reliable")
func cast_ability(slot: int, aim: Vector3) -> void:
	if multiplayer.is_server():
		cast_received.emit(multiplayer.get_remote_sender_id(), slot, aim)


@rpc("authority", "call_remote", "reliable")
func welcome(mode_id: String, peer_id: int) -> void:
	welcomed.emit(mode_id, peer_id)


@rpc("authority", "call_remote", "reliable")
func reject(reason: String) -> void:
	rejected.emit(reason)


## `states` es una lista de estados de jugador, ordenados según `State`.
@rpc("authority", "call_remote", "unreliable_ordered", SNAPSHOT_CHANNEL)
func snapshot(tick: int, states: Array, entities: Array) -> void:
	snapshot_received.emit(tick, states, entities)


@rpc("authority", "call_remote", "reliable")
func combat_event(event: Array) -> void:
	combat_event_received.emit(event)
