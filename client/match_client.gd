class_name MatchClient
extends Node
## Envía intenciones y muestra el estado que llega del servidor.

signal left(reason: String)

const AVATAR_SCENE := preload("res://shared/avatar.tscn")
const VISUAL_SCENE := preload("res://client/avatar_visual.tscn")
const CROSSHAIR_SCENE := preload("res://client/crosshair.tscn")

var peer_id := 0
var mode: MatchModeData
var avatars: Dictionary[int, Avatar] = {}
var confirmed_position := Vector3.INF
var max_correction := 0.0

var _map: Node3D
var _camera: ThirdPersonCamera
var _seq := 0
var _clock := 0.0
var _own_state: Array = []
var _prediction := Prediction.new()
var _remote_buffers: Dictionary[int, Interpolation] = {}


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
	Net.snapshot_received.connect(_on_snapshot)
	return OK


func _on_connected() -> void:
	Net.hello.rpc_id(1, Net.game_version())


func _on_welcomed(mode_id: String, my_peer_id: int) -> void:
	peer_id = my_peer_id
	mode = load("res://data/modes/%s.tres" % mode_id)
	_map = mode.map.instantiate()
	add_child(_map)
	_camera = ThirdPersonCamera.new()
	add_child(_camera)
	add_child(CROSSHAIR_SCENE.instantiate())


func _on_snapshot(tick: int, states: Array) -> void:
	_clock = Interpolation.sync_clock(_clock, float(tick) / Engine.physics_ticks_per_second)
	var seen: Dictionary[int, bool] = {}
	for state: Array in states:
		var id: int = state[0]
		seen[id] = true
		if not avatars.has(id):
			_add_avatar(id, state[1])
		if id == peer_id:
			_own_state = state
		else:
			_remote_buffers[id].push(float(tick) / Engine.physics_ticks_per_second, state[1], state[2])
	for id: int in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
			_remote_buffers.erase(id)


func _add_avatar(id: int, position: Vector3) -> void:
	var avatar := _spawn_avatar()
	avatar.global_position = position
	avatar.reset_physics_interpolation()
	avatars[id] = avatar
	if id == peer_id:
		_camera.target = avatar
	else:
		# Se interpola a mano en `_process`.
		avatar.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_remote_buffers[id] = Interpolation.new()


func _process(delta: float) -> void:
	_clock += delta
	for id: int in _remote_buffers:
		var sampled := _remote_buffers[id].sample(_clock - Interpolation.DELAY)
		if not sampled.is_empty():
			avatars[id].global_position = sampled.position
			avatars[id].rotation.y = sampled.yaw


func _physics_process(_delta: float) -> void:
	if not avatars.has(peer_id):
		return
	var avatar := avatars[peer_id]
	# Se reconcilia aquí y no en el RPC: `move_and_slide()` necesita el tick de física.
	if not _own_state.is_empty():
		_reconcile(avatar)
	_seq += 1
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	avatar.apply_input(move, _camera.yaw)
	_prediction.record(_seq, move, _camera.yaw)
	Net.submit_input.rpc_id(1, _seq, move, _camera.yaw)


func _reconcile(avatar: Avatar) -> void:
	var predicted := avatar.global_position
	confirmed_position = _own_state[1]
	_prediction.acknowledge(_own_state[3])
	avatar.global_position = confirmed_position
	for input: Dictionary in _prediction.pending:
		avatar.apply_input(input.move, input.yaw)
	max_correction = maxf(max_correction, predicted.distance_to(avatar.global_position))
	_own_state = []


func _spawn_avatar() -> Avatar:
	var avatar: Avatar = AVATAR_SCENE.instantiate()
	avatar.add_child(VISUAL_SCENE.instantiate())
	_map.add_child(avatar)
	return avatar


func _leave(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	left.emit(reason)
	queue_free()
