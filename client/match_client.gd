class_name MatchClient
extends Node
## Envía intenciones y muestra el estado que llega del servidor.

signal entered
signal left(reason: String)

const AVATAR_SCENE := preload("res://shared/avatar.tscn")
const HERO_VISUAL_PATH := "res://client/heroes/%s.tscn"
const CROSSHAIR_SCENE := preload("res://client/crosshair.tscn")
const HUD_SCENE := preload("res://client/hud.tscn")
const SLOT_ACTIONS: Array[StringName] = [&"basic_attack", &"ability_1", &"ability_2", &"ability_3", &"ability_4"]
# Evita repetir un lanzamiento hasta que el servidor confirme el cooldown.
const CAST_RETRY := 0.25
# Una corrección mayor es un salto real, como Parpadeo: no se suaviza.
const TELEPORT_DISTANCE := 2.0
const HEALTH_LABEL_HEIGHT := 2.5
# ENet tarda más de 30 s en rendirse si nadie responde.
const CONNECT_TIMEOUT := 8.0

var peer_id := 0
var mode: MatchModeData
var avatars: Dictionary[int, Avatar] = {}
var entities: Array = []
var confirmed_position := Vector3.INF
var max_correction := 0.0

var _hero_id := ""
var _map: Node3D
var _camera: ThirdPersonCamera
var _hud: Hud
var _visuals: CombatVisuals
var _seq := 0
var _clock := 0.0
var _own_state: Array = []
var _own_cooldowns := PackedFloat32Array()
var _cast_waits := PackedFloat32Array()
var _tapped: Array[bool] = []
var _jump_tapped := false
var _alive := true
var _prediction := Prediction.new()
var _remote_buffers: Dictionary[int, Interpolation] = {}
var _health_labels: Dictionary[int, Label3D] = {}


func join(host: String, port: int, hero_id: String) -> Error:
	_hero_id = hero_id
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
	Net.combat_event_received.connect(_on_combat_event)
	get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(_on_connect_timeout)
	return OK


func _on_connect_timeout() -> void:
	if _map == null:
		_leave("No hay servidor en esa IP y puerto. ¿Está arrancado?")


func _on_connected() -> void:
	Net.hello.rpc_id(1, Net.game_version(), _hero_id)


func _on_welcomed(mode_id: String, my_peer_id: int) -> void:
	peer_id = my_peer_id
	mode = load("res://data/modes/%s.tres" % mode_id)
	_map = mode.map.instantiate()
	add_child(_map)
	_camera = ThirdPersonCamera.new()
	add_child(_camera)
	_visuals = CombatVisuals.new(_map, mode)
	_visuals.avatars = avatars
	_visuals.own_id = peer_id
	_visuals.shaken.connect(_camera.shake)
	_map.add_child(_visuals)
	add_child(CROSSHAIR_SCENE.instantiate())
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.setup_minimap(_map)
	_cast_waits.resize(HeroData.SLOT_COUNT)
	_tapped.resize(HeroData.SLOT_COUNT)
	_tapped.fill(false)
	entered.emit()


func _on_snapshot(tick: int, states: Array, new_entities: Array) -> void:
	# La bienvenida es fiable y la instantánea no: puede llegar antes.
	if _map == null:
		return
	var time := float(tick) / Engine.physics_ticks_per_second
	_clock = Interpolation.sync_clock(_clock, time)
	entities = new_entities
	_visuals.update_entities(time, new_entities)
	var seen: Dictionary[int, bool] = {}
	for state: Array in states:
		var id: int = state[Net.State.PEER]
		seen[id] = true
		if not avatars.has(id):
			_add_avatar(id, state[Net.State.POSITION], mode.heroes[state[Net.State.HERO]])
		avatars[id].visible = state[Net.State.ALIVE]
		_visuals.show_shield(id, state[Net.State.SHIELD] > 0.0)
		if id == peer_id:
			_own_state = state
			_show_own_state(state)
		else:
			_remote_buffers[id].push(time, state[Net.State.POSITION], state[Net.State.YAW])
			_health_labels[id].text = "%d" % state[Net.State.HEALTH]
	for id: int in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
			_remote_buffers.erase(id)
			_health_labels.erase(id)


func _show_own_state(state: Array) -> void:
	_own_cooldowns = state[Net.State.COOLDOWNS]
	_alive = state[Net.State.ALIVE]
	_hud.show_state(
		state[Net.State.HEALTH], state[Net.State.MANA], state[Net.State.SHIELD],
		_own_cooldowns, _alive, state[Net.State.RESPAWN_LEFT]
	)


func _on_combat_event(event: Array) -> void:
	if _visuals != null:
		_visuals.show_event(event)


func _add_avatar(id: int, position: Vector3, hero: HeroData) -> void:
	var avatar := _spawn_avatar(hero)
	avatar.global_position = position
	avatar.reset_physics_interpolation()
	avatars[id] = avatar
	if id == peer_id:
		_camera.target = avatar
		_hud.setup(hero)
	else:
		# Se interpola a mano en `_process`.
		avatar.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_remote_buffers[id] = Interpolation.new()
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = HEALTH_LABEL_HEIGHT
		avatar.add_child(label)
		_health_labels[id] = label


func _process(delta: float) -> void:
	_clock += delta
	for id: int in _remote_buffers:
		var sampled := _remote_buffers[id].sample(_clock - Interpolation.DELAY)
		if not sampled.is_empty():
			avatars[id].global_position = sampled.position
			avatars[id].rotation.y = sampled.yaw
	if _visuals != null:
		_visuals.sample(_clock - Interpolation.DELAY)
	if avatars.has(peer_id):
		_update_minimap()


func _update_minimap() -> void:
	var enemies: Array[Vector3] = []
	for id: int in avatars:
		if id != peer_id and avatars[id].visible:
			enemies.append(avatars[id].global_position)
	_hud.show_units(avatars[peer_id].global_position, _camera.yaw, enemies)


func _physics_process(delta: float) -> void:
	if not avatars.has(peer_id):
		return
	var avatar := avatars[peer_id]
	# Se reconcilia aquí y no en el RPC: `move_and_slide()` necesita el tick de física.
	if not _own_state.is_empty():
		_reconcile(avatar)
	_seq += 1
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := _jump_tapped or Input.is_action_pressed("jump")
	_jump_tapped = false
	avatar.apply_input(move, _camera.yaw, jump)
	_prediction.record(_seq, move, _camera.yaw, jump)
	Net.submit_input.rpc_id(1, _seq, move, _camera.yaw, jump)
	_send_casts(avatar, delta)


# Un toque rápido puede empezar y acabar entre dos ticks de física.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_tapped = true
	if _tapped.is_empty() or not _camera.can_aim():
		return
	for slot in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[slot]):
			_tapped[slot] = true


func _send_casts(avatar: Avatar, delta: float) -> void:
	for slot in SLOT_ACTIONS.size():
		_cast_waits[slot] = maxf(_cast_waits[slot] - delta, 0.0)
	if _alive and _camera.can_aim() and not _own_cooldowns.is_empty():
		for slot in SLOT_ACTIONS.size():
			var wanted := _tapped[slot] or Input.is_action_pressed(SLOT_ACTIONS[slot])
			if wanted and _cast_waits[slot] == 0.0 and _own_cooldowns[slot] <= 0.0:
				_cast_waits[slot] = CAST_RETRY
				Net.cast_ability.rpc_id(1, slot, _camera.aim_point([avatar.get_rid()]))
	_tapped.fill(false)


func _reconcile(avatar: Avatar) -> void:
	var predicted := avatar.global_position
	confirmed_position = _own_state[Net.State.POSITION]
	_prediction.acknowledge(_own_state[Net.State.SEQ])
	avatar.move_factor = _own_state[Net.State.MOVE_FACTOR]
	avatar.global_position = confirmed_position
	avatar.vertical_speed = _own_state[Net.State.VERTICAL_SPEED]
	for input: Dictionary in _prediction.pending:
		avatar.apply_input(input.move, input.yaw, input.jump)
	var correction := predicted.distance_to(avatar.global_position)
	max_correction = maxf(max_correction, correction)
	if correction > TELEPORT_DISTANCE:
		avatar.reset_physics_interpolation()
	_own_state = []


func _spawn_avatar(hero: HeroData) -> Avatar:
	var avatar: Avatar = AVATAR_SCENE.instantiate()
	avatar.hero = hero
	var visual: Node3D = load(HERO_VISUAL_PATH % hero.id).instantiate()
	visual.name = "Visual"
	var animator := HeroAnimator.new()
	animator.name = "Animator"
	visual.add_child(animator)
	avatar.add_child(visual)
	_map.add_child(avatar)
	return avatar


func _leave(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	left.emit(reason)
	queue_free()
