class_name MatchServer
extends Node
## Simula la partida y es la única verdad.

# Plazas extra para poder explicar el rechazo en vez de ignorar la conexión.
const REJECT_SLOTS := 4
const KICK_DELAY := 1.0
const MAX_PENDING_CASTS := HeroData.SLOT_COUNT
const EMPTY_QUIT_DELAY := 10.0
# shortcut: nivel fijo, la experiencia llega en M3.
const LEVEL := 1
const AVATAR_SCENE := preload("res://shared/avatar.tscn")

## Cierra el proceso tras un rato sin jugadores, tanto si se fueron como si nunca
## llegaron. Lo usa la práctica local.
var quit_when_empty := false

var _mode: MatchModeData
var _map: Node3D
var _runner: AbilityRunner
var _players: Dictionary[int, Player] = {}
var _dummies: Array[CombatTarget] = []
var _next_spawn := 0
var _tick := 0
var _empty_time := 0.0


class Player:
	var avatar: Avatar
	var unit: CombatTarget
	var hero_index := 0
	var inputs := InputQueue.new()
	var casts: Array[Array] = []
	var acked_seq := 0


func start(port: int, mode: MatchModeData) -> Error:
	_mode = mode
	_map = mode.map.instantiate()
	add_child(_map)
	_runner = AbilityRunner.new(_map)
	_runner.event_emitted.connect(_send_event)
	_add_dummies()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, _capacity() + REJECT_SLOTS)
	if error != OK:
		return error
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Net.hello_received.connect(_on_hello)
	Net.input_received.connect(_on_input)
	Net.cast_received.connect(_on_cast)
	print("Servidor en el puerto %d, modo %s" % [port, mode.id])
	return OK


func _capacity() -> int:
	return _mode.players_per_team * 2


func _add_dummies() -> void:
	if not _map.has_node("Dummies"):
		return
	for dummy: TrainingDummy in _map.get_node("Dummies").get_children():
		var id := -(dummy.get_index() + 1)
		var unit := CombatTarget.new(id, dummy, CombatState.for_dummy(dummy.data), dummy.data.reset_delay)
		_dummies.append(unit)
		_runner.targets.append(unit)


func _on_hello(peer_id: int, version: String, hero_id: String) -> void:
	if _players.has(peer_id):
		return
	var hero_index := _hero_index(hero_id)
	if version != Net.game_version():
		_kick(peer_id, "Versión distinta: el servidor usa %s" % Net.game_version())
	elif hero_index == -1:
		_kick(peer_id, "Héroe no disponible en este modo")
	elif _players.size() >= _capacity():
		_kick(peer_id, "La partida está llena")
	else:
		_add_player(peer_id, hero_index)


func _hero_index(hero_id: String) -> int:
	for index in _mode.heroes.size():
		if String(_mode.heroes[index].id) == hero_id:
			return index
	return -1


func _add_player(peer_id: int, hero_index: int) -> void:
	# shortcut: cada jugador aparece al conectarse, la espera a que estén todos llega en M3.
	var hero := _mode.heroes[hero_index]
	var player := Player.new()
	player.hero_index = hero_index
	player.avatar = AVATAR_SCENE.instantiate()
	player.avatar.hero = hero
	_map.add_child(player.avatar)
	var spawns := _map.get_node("SpawnPoints").get_children()
	player.avatar.global_position = spawns[_next_spawn % spawns.size()].global_position
	_next_spawn += 1
	var delay := CombatRules.respawn_time(LEVEL)
	player.unit = CombatTarget.new(peer_id, player.avatar, CombatState.for_hero(hero), delay)
	_runner.targets.append(player.unit)
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


func _on_input(peer_id: int, seq: int, move: Vector2, yaw: float, jump: bool) -> void:
	if _players.has(peer_id):
		_players[peer_id].inputs.push(seq, move, yaw, jump)


func _on_cast(peer_id: int, slot: int, aim: Vector3) -> void:
	if _players.has(peer_id) and _players[peer_id].casts.size() < MAX_PENDING_CASTS:
		_players[peer_id].casts.append([slot, aim])


func _on_peer_disconnected(peer_id: int) -> void:
	if _players.has(peer_id):
		_runner.remove(_players[peer_id].unit)
		_players[peer_id].avatar.queue_free()
		_players.erase(peer_id)
		print("Jugador %d desconectado" % peer_id)


func _physics_process(delta: float) -> void:
	_tick += 1
	_empty_time = _empty_time + delta if _players.is_empty() else 0.0
	if quit_when_empty and _empty_time >= EMPTY_QUIT_DELAY:
		get_tree().quit()
	for unit in _runner.targets:
		_update_unit(unit, delta)
	for player: Player in _players.values():
		_run_casts(player)
		player.avatar.move_factor = player.unit.state.move_factor()
		var input := player.inputs.pop()
		if not input.is_empty():
			player.avatar.apply_input(input.move, input.yaw, input.jump)
			player.acked_seq = input.seq
	_runner.tick(delta)
	# 20 Hz con 30 ticks: se envía en 2 de cada 3.
	if _tick % 3 != 0:
		_send_snapshot()


func _update_unit(unit: CombatTarget, delta: float) -> void:
	unit.state.tick(delta)
	if unit.state.is_alive():
		return
	unit.respawn_left -= delta
	if unit.respawn_left <= 0.0:
		unit.state.reset()
		unit.body.global_position = unit.spawn_position


func _run_casts(player: Player) -> void:
	for cast: Array in player.casts:
		var slot: int = cast[0]
		var aim: Vector3 = cast[1]
		var ability := player.avatar.hero.ability(slot)
		if ability != null and aim.is_finite() and player.unit.state.can_cast(slot, ability):
			player.unit.state.spend(slot, ability)
			_runner.cast(player.unit, ability, aim)
	player.casts.clear()


func _send_snapshot() -> void:
	var states: Array = []
	for peer_id: int in _players:
		var player := _players[peer_id]
		var state := player.unit.state
		states.append([
			peer_id, player.avatar.global_position, player.avatar.rotation.y, player.acked_seq,
			player.hero_index, state.health, state.mana, state.shield, state.move_factor(),
			state.cooldowns, state.is_alive(), player.unit.respawn_left, player.avatar.vertical_speed,
		])
	var entities := _runner.entities()
	for dummy in _dummies:
		entities.append([dummy.id, Net.Entity.DUMMY, dummy.position(), dummy.state.health, dummy.state.max_health])
	for peer_id: int in _players:
		Net.snapshot.rpc_id(peer_id, _tick, states, entities)


func _send_event(event: Array) -> void:
	for peer_id: int in _players:
		Net.combat_event.rpc_id(peer_id, event)
