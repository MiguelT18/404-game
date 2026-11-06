class_name MatchClient
extends Node
## Envía intenciones y muestra el estado que llega del servidor.

signal left(reason: String)

var peer_id := 0
var mode: MatchModeData


func join(host: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_leave.bind("No se pudo conectar"))
	multiplayer.server_disconnected.connect(_leave.bind("Conexión perdida"))
	Net.welcomed.connect(_on_welcomed)
	Net.rejected.connect(_leave)
	return OK


func _on_connected() -> void:
	Net.hello.rpc_id(1, Net.game_version())


func _on_welcomed(mode_id: String, my_peer_id: int) -> void:
	peer_id = my_peer_id
	mode = load("res://data/modes/%s.tres" % mode_id)


func _leave(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	left.emit(reason)
	queue_free()
