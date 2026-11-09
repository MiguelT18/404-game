class_name HeroRig
extends AnimationTree
## Animaciones de un modelo con esqueleto: reposo, andar, correr y saltar según cómo se
## mueve su avatar, y un clip por habilidad con el mismo id que ella. Es solo
## presentación: deduce el movimiento de la posición, así que sirve igual para el
## jugador local y para los remotos.
##
## El `.glb` debe traer los clips `idle`, `walk`, `run`, `run_back`, `jump` y `land`.

const LOOPS: Array[StringName] = [&"idle", &"walk", &"run", &"run_back"]
const MOVES: Array[StringName] = [&"idle", &"walk", &"run", &"run_back", &"jump", &"land"]
## Huesos que no siguen a los hechizos cuando el héroe se mueve: así lanza corriendo.
const LOWER_BODY: Array[StringName] = [&"Hips", &"LeftUpLeg", &"LeftLeg", &"LeftFoot", &"LeftToeBase",
	&"RightUpLeg", &"RightLeg", &"RightFoot", &"RightToeBase"]
## Dirección en la que avanza cada clip de carrera, en el espacio del modelo (frente -Z).
const RUN_DIRECTION := {&"run": Vector3.FORWARD, &"run_back": Vector3(-1, 0, 1)}
const MOVING_SPEED := 0.4
const WALK_SPEED := 3.0
## Velocidades con las que los clips de andar y correr no patinan.
const WALK_CLIP_SPEED := 1.6
const RUN_CLIP_SPEED := 4.5
const AIR_HEIGHT := 0.05
const TURN_RATE := 12.0
const MAX_CAST := 1.0
const MIN_CAST := 0.35
## Parte del cooldown que puede ocupar el gesto de un hechizo.
const CAST_SHARE := 0.7
const CHARGE_TAIL := 0.3

var _avatar: Node3D
var _armature: Node3D
var _player: AnimationPlayer
var _cast_clip: AnimationNodeAnimation
var _cast_shot: AnimationNodeOneShot
var _state := &"idle"
var _last_position := Vector3.INF
var _velocity := Vector3.ZERO
var _airtime := 0.7
var _landing := 0.0


## Prepara el árbol si `model` trae un `AnimationPlayer` con los clips de movimiento.
static func attach(model: Node3D) -> HeroRig:
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player == null:
		return null
	for clip in MOVES:
		if not player.has_animation(clip):
			return null
	var rig := HeroRig.new()
	rig.name = "Rig"
	rig._player = player
	# Se llama desde un `_ready`, cuando el modelo aún está montando sus hijos.
	model.add_child.call_deferred(rig)
	return rig


func has_clip(clip: StringName) -> bool:
	return _player.has_animation(clip)


## Lanza el gesto de `ability`. Si el héroe se mueve, solo anima de cintura para arriba.
func cast(ability: AbilityData) -> void:
	if not is_node_ready():
		return
	var length := _player.get_animation(ability.id).length
	var target := clampf(minf(length, ability.cooldown * CAST_SHARE), MIN_CAST, MAX_CAST)
	if ability.cast_delay > 0.0:
		target = ability.cast_delay + CHARGE_TAIL
	_cast_clip.animation = ability.id
	_cast_shot.filter_enabled = _state != &"idle"
	set("parameters/cast_speed/scale", length / target)
	set("parameters/cast/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _ready() -> void:
	var model := get_parent() as Node3D
	_avatar = model.get_parent() as Node3D
	_armature = _player.get_parent().get_node_or_null("Armature")
	if _armature != null:
		# Gira cada fotograma hacia donde corre; no hace falta interpolarlo entre ticks.
		_armature.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var avatar := _avatar as Avatar
	if avatar != null and avatar.hero != null:
		_airtime = 2.0 * avatar.hero.jump_speed / MoveRules.GRAVITY
	for clip in LOOPS:
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	root_node = get_path_to(_player.get_parent())
	anim_player = get_path_to(_player)
	tree_root = _build_tree()
	active = true


func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var move := AnimationNodeTransition.new()
	move.xfade_time = 0.15
	for clip in MOVES:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		tree.add_node(clip, node)
		move.add_input(clip)
	tree.add_node(&"move", move)
	for i in MOVES.size():
		tree.connect_node(&"move", i, MOVES[i])
	tree.add_node(&"move_speed", AnimationNodeTimeScale.new())
	tree.connect_node(&"move_speed", 0, &"move")

	_cast_clip = AnimationNodeAnimation.new()
	_cast_clip.animation = &"idle"
	tree.add_node(&"cast_clip", _cast_clip)
	tree.add_node(&"cast_speed", AnimationNodeTimeScale.new())
	tree.connect_node(&"cast_speed", 0, &"cast_clip")
	_cast_shot = AnimationNodeOneShot.new()
	_cast_shot.fadein_time = 0.08
	_cast_shot.fadeout_time = 0.2
	var skeleton: Skeleton3D = _player.get_parent().find_child("Skeleton3D", true, false)
	var skeleton_path := _player.get_parent().get_path_to(skeleton)
	for bone in skeleton.get_bone_count():
		var bone_name := StringName(skeleton.get_bone_name(bone))
		if bone_name not in LOWER_BODY:
			_cast_shot.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone_name]), true)
	tree.add_node(&"cast", _cast_shot)
	tree.connect_node(&"cast", 0, &"move_speed")
	tree.connect_node(&"cast", 1, &"cast_speed")
	tree.connect_node(&"output", 0, &"cast")
	return tree


func _process(delta: float) -> void:
	if _avatar == null or delta <= 0.0:
		return
	# Con interpolación de física, la posición cruda solo cambia en los ticks.
	var position := _avatar.get_global_transform_interpolated().origin \
		if _avatar.is_physics_interpolated_and_enabled() else _avatar.global_position
	if _last_position != Vector3.INF:
		var raw := (position - _last_position) / delta
		_velocity = _velocity.lerp(Vector3(raw.x, 0.0, raw.z), 1.0 - exp(-12.0 * delta))
	_last_position = position
	var local := _avatar.global_basis.inverse() * _velocity
	var speed := local.length()
	var airborne := position.y > Avatar.GROUND_HEIGHT + AIR_HEIGHT

	var state := &"idle"
	var turn := 0.0
	var scale := 1.0
	if airborne:
		state = &"jump"
		scale = _player.get_animation(&"jump").length / _airtime
	elif _state == &"jump" and speed < MOVING_SPEED:
		state = &"land"
		_landing = _player.get_animation(&"land").length
	elif _state == &"land" and _landing > 0.0 and speed < MOVING_SPEED:
		state = &"land"
		_landing -= delta
	elif speed >= MOVING_SPEED:
		var pick := _pick_run(local)
		state = pick[0]
		turn = pick[1]
		if state == &"run" and speed < WALK_SPEED:
			state = &"walk"
		scale = speed / (WALK_CLIP_SPEED if state == &"walk" else RUN_CLIP_SPEED)
	if state != _state:
		set("parameters/move/transition_request", String(state))
		_state = state
	set("parameters/move_speed/scale", clampf(scale, 0.5, 2.0))
	if _armature != null:
		# Mientras lanza mira hacia donde apunta; si no, hacia donde corre.
		if get("parameters/cast/active"):
			turn = 0.0
		_armature.rotation.y = lerp_angle(_armature.rotation.y, turn, 1.0 - exp(-TURN_RATE * delta))


## Clip de carrera que menos hay que girar para avanzar en `direction`, y ese giro.
func _pick_run(direction: Vector3) -> Array:
	var best := &"run"
	var best_turn := INF
	for clip: StringName in RUN_DIRECTION:
		var turn := (RUN_DIRECTION[clip] as Vector3).normalized().signed_angle_to(direction.normalized(), Vector3.UP)
		if absf(turn) < absf(best_turn):
			best = clip
			best_turn = turn
	return [best, best_turn]
