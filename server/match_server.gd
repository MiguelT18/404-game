class_name MatchServer
extends Node
## Simula la partida y es la única verdad.

# Plazas extra para poder explicar el rechazo en vez de ignorar la conexión.
const REJECT_SLOTS := 4
const KICK_DELAY := 1.0
const AVATAR_SCENE := preload("res://shared/avatar.tscn")

var _mode: MatchModeData
var _map: Node3D
var _players: Dictionary[int, Player] = {}
var _next_spawn := 0
var _tick := 0


class Player:
	var avatar: Avatar
	var inputs := InputQueue.new()
	var acked_seq := 0


func start(port: int, mode: MatchModeData) -> Error:
	_mode = mode
	_map = mode.map.instantiate()
	add_child(_map)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, _capacity() + REJECT_SLOTS)
	if error != OK:
		return error
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Net.hello_received.connect(_on_hello)
	Net.input_received.connect(_on_input)
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
	var player := Player.new()
	player.avatar = AVATAR_SCENE.instantiate()
	_map.add_child(player.avatar)
	var spawns := _map.get_node("SpawnPoints").get_children()
	player.avatar.global_position = spawns[_next_spawn % spawns.size()].global_position
	_next_spawn += 1
	_players[peer_id] = player
	Net.welcome.rpc_id(peer_id, String(_mode.id), peer_id)
	print("Jugador %d conectado" % peer_id)


func _kick(peer_id: int, reason: String) -> void:
	print("Rechazado %d: %s" % [peer_id, reason])
	Net.reject.rpc_id(peer_id, reason)
	# Desconectar en el acto descartaría el mensaje de rechazo que aún no salió.
	await get_tree().create_timer(KICK_DELAY).timeout
	if peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_input(peer_id: int, seq: int, move: Vector2, yaw: float) -> void:
	if _players.has(peer_id):
		_players[peer_id].inputs.push(seq, move, yaw)


func _on_peer_disconnected(peer_id: int) -> void:
	if _players.has(peer_id):
		_players[peer_id].avatar.queue_free()
		_players.erase(peer_id)
		print("Jugador %d desconectado" % peer_id)


func _physics_process(_delta: float) -> void:
	_tick += 1
	for player: Player in _players.values():
		var input := player.inputs.pop()
		if not input.is_empty():
			player.avatar.apply_input(input.move, input.yaw)
			player.acked_seq = input.seq
	# 20 Hz con 30 ticks: se envía en 2 de cada 3.
	if _tick % 3 != 0:
		_send_snapshot()


func _send_snapshot() -> void:
	var states: Array = []
	for peer_id: int in _players:
		var player := _players[peer_id]
		states.append([peer_id, player.avatar.global_position, player.avatar.rotation.y, player.acked_seq])
	for peer_id: int in _players:
		Net.snapshot.rpc_id(peer_id, _tick, states)
