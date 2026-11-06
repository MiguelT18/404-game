class_name MatchServer
extends Node
## Simula la partida y es la única verdad.

# Plazas extra para poder explicar el rechazo en vez de ignorar la conexión.
const REJECT_SLOTS := 4
const KICK_DELAY := 1.0

var _mode: MatchModeData
var _players: Dictionary[int, InputQueue] = {}


func start(port: int, mode: MatchModeData) -> Error:
	_mode = mode
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, _capacity() + REJECT_SLOTS)
	if error != OK:
		return error
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Net.hello_received.connect(_on_hello)
	print("Servidor en el puerto %d, modo %s" % [port, mode.id])
	return OK


func _capacity() -> int:
	return _mode.players_per_team * 2


func _on_hello(peer_id: int, version: String) -> void:
	if _players.has(peer_id):
		return
	if version != Net.game_version():
		_kick(peer_id, "Versión distinta: el servidor usa %s" % Net.game_version())
	elif _players.size() >= _capacity():
		_kick(peer_id, "La partida está llena")
	else:
		_add_player(peer_id)


func _add_player(peer_id: int) -> void:
	# shortcut: cada jugador aparece al conectarse, la espera a que estén todos llega en M3.
	_players[peer_id] = InputQueue.new()
	Net.welcome.rpc_id(peer_id, String(_mode.id), peer_id)
	print("Jugador %d conectado" % peer_id)


func _kick(peer_id: int, reason: String) -> void:
	print("Rechazado %d: %s" % [peer_id, reason])
	Net.reject.rpc_id(peer_id, reason)
	# Desconectar en el acto descartaría el mensaje de rechazo que aún no salió.
	await get_tree().create_timer(KICK_DELAY).timeout
	if peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _players.erase(peer_id):
		print("Jugador %d desconectado" % peer_id)
