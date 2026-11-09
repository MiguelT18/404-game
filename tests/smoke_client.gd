extends Node
## Cliente automático de la prueba de red; lo lanza tests/net_smoke.sh.
## Argumentos: --port N --expect accept|reject [--version X] [--hero id] [--cast slot] [--jump]
## Con --cast, en vez de moverse lanza esa habilidad al muñeco más cercano.
## Con --jump, además de moverse salta sin parar.

const TIMEOUT := 6.0
const MIN_TRAVEL := 3.0
const MIN_JUMP := 0.8
const MAX_JUMP := 1.5

var _client: MatchClient
var _expect := "accept"
var _cast_slot := -1
var _casted := false
var _target_id := 0
var _jumping := false
var _peak := 0.0
var _max_others := 0
var _elapsed := 0.0
var _left_reason := ""
var _start := Vector3.INF


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var port := int(args[args.find("--port") + 1])
	_expect = args[args.find("--expect") + 1]
	var version_index := args.find("--version")
	if version_index != -1:
		ProjectSettings.set_setting("application/config/version", args[version_index + 1])
	var hero_index := args.find("--hero")
	var hero_id: String = args[hero_index + 1] if hero_index != -1 else "guardian"
	var cast_index := args.find("--cast")
	if cast_index != -1:
		_cast_slot = int(args[cast_index + 1])
	_client = MatchClient.new()
	add_child(_client)
	_client.left.connect(func(reason: String) -> void: _left_reason = reason)
	_client.join("127.0.0.1", port, hero_id)
	if _cast_slot == -1:
		Input.action_press("move_forward")
	_jumping = "--jump" in args
	if _jumping:
		Input.action_press("jump")


func _process(delta: float) -> void:
	_elapsed += delta
	if _start == Vector3.INF:
		_start = _client.confirmed_position
	elif _client.confirmed_position != Vector3.INF:
		_peak = maxf(_peak, _client.confirmed_position.y)
	# El otro cliente puede terminar antes: cuenta si se vieron, no si sigue ahí.
	_max_others = maxi(_max_others, _client.avatars.size() - 1)
	if _cast_slot != -1 and not _casted and _start != Vector3.INF:
		_cast_at_nearest_dummy()
	if _expect == "reject" and _left_reason != "":
		_finish(_left_reason != "Conexión perdida", "rechazado: %s" % _left_reason)
	elif _expect == "accept" and _left_reason != "":
		_finish(false, "expulsado: %s" % _left_reason)
	elif _casted and _dummy_was_hit():
		_finish(true, "habilidad %d dañó a un muñeco" % _cast_slot)
	elif _elapsed >= TIMEOUT:
		_finish_timeout()


func _cast_at_nearest_dummy() -> void:
	var nearest := Vector3.INF
	for entity: Array in _client.entities:
		if entity[1] == Net.Entity.DUMMY and _start.distance_to(entity[2]) < _start.distance_to(nearest):
			nearest = entity[2]
			_target_id = entity[0]
	if nearest != Vector3.INF:
		_casted = true
		Net.cast_ability.rpc_id(1, _cast_slot, nearest)


# Solo cuenta su muñeco: los otros clientes comparten mapa.
func _dummy_was_hit() -> bool:
	for entity: Array in _client.entities:
		if entity[0] == _target_id and entity[3] < entity[4]:
			return true
	return false


func _finish_timeout() -> void:
	if _expect == "reject" or _start == Vector3.INF or _cast_slot != -1:
		_finish(false, "sin resultado esperado")
		return
	var travel := _start.distance_to(_client.confirmed_position)
	var detail := "recorrió %.1f m, vio a %d más, corrección máxima %.3f m" % [travel, _max_others, _client.max_correction]
	var passed := travel >= MIN_TRAVEL and _max_others == 1
	if _jumping:
		detail += ", saltó %.2f m" % _peak
		passed = passed and _peak >= MIN_JUMP and _peak <= MAX_JUMP
	_finish(passed, detail)


func _finish(passed: bool, detail: String) -> void:
	print("%s %s" % ["PASA" if passed else "FALLA", detail])
	get_tree().quit(0 if passed else 1)
