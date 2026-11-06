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

var _map: Node3D
var _camera: ThirdPersonCamera
var _seq := 0
var _latest_states: Array = []


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


func _on_snapshot(_tick: int, states: Array) -> void:
	_latest_states = states


func _physics_process(_delta: float) -> void:
	if _map == null:
		return
	_seq += 1
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	Net.submit_input.rpc_id(1, _seq, move, _camera.yaw)
	_apply_states()


func _apply_states() -> void:
	var seen: Dictionary[int, bool] = {}
	for state: Array in _latest_states:
		var id: int = state[0]
		seen[id] = true
		if not avatars.has(id):
			avatars[id] = _spawn_avatar()
			if id == peer_id:
				_camera.target = avatars[id]
		avatars[id].global_position = state[1]
		avatars[id].rotation.y = state[2]
	for id: int in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)


func _spawn_avatar() -> Avatar:
	var avatar: Avatar = AVATAR_SCENE.instantiate()
	avatar.add_child(VISUAL_SCENE.instantiate())
	_map.add_child(avatar)
	return avatar


func _leave(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	left.emit(reason)
	queue_free()
