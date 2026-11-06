extends Node
## Protocolo de red. Los RPC viven aquí porque Godot exige la misma ruta de nodo
## en ambos lados; servidor y cliente solo escuchan estas señales.

signal hello_received(peer_id: int, version: String)
signal input_received(peer_id: int, seq: int, move: Vector2, yaw: float)
signal welcomed(mode_id: String, peer_id: int)
signal rejected(reason: String)
signal snapshot_received(tick: int, states: Array)

const INPUT_CHANNEL := 1
const SNAPSHOT_CHANNEL := 2


static func game_version() -> String:
	return ProjectSettings.get_setting("application/config/version")


@rpc("any_peer", "call_remote", "reliable")
func hello(version: String) -> void:
	if multiplayer.is_server():
		hello_received.emit(multiplayer.get_remote_sender_id(), version)


@rpc("any_peer", "call_remote", "unreliable_ordered", INPUT_CHANNEL)
func submit_input(seq: int, move: Vector2, yaw: float) -> void:
	if multiplayer.is_server():
		input_received.emit(multiplayer.get_remote_sender_id(), seq, move, yaw)


@rpc("authority", "call_remote", "reliable")
func welcome(mode_id: String, peer_id: int) -> void:
	welcomed.emit(mode_id, peer_id)


@rpc("authority", "call_remote", "reliable")
func reject(reason: String) -> void:
	rejected.emit(reason)


## `states` es una lista de [peer_id, posición, yaw, último seq procesado].
@rpc("authority", "call_remote", "unreliable_ordered", SNAPSHOT_CHANNEL)
func snapshot(tick: int, states: Array) -> void:
	snapshot_received.emit(tick, states)
