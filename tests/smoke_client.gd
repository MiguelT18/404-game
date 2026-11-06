extends Node
## Cliente automático de la prueba de red; lo lanza tests/net_smoke.sh.
## Argumentos: --port N --expect accept|reject [--version X]

const TIMEOUT := 6.0
const MIN_TRAVEL := 3.0

var _client: MatchClient
var _expect := "accept"
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
	_client = MatchClient.new()
	add_child(_client)
	_client.left.connect(func(reason: String) -> void: _left_reason = reason)
	_client.join("127.0.0.1", port)
	Input.action_press("move_forward")


func _process(delta: float) -> void:
	_elapsed += delta
	if _start == Vector3.INF and _client.avatars.has(_client.peer_id):
		_start = _client.avatars[_client.peer_id].global_position
	if _expect == "reject" and _left_reason != "":
		_finish(_left_reason != "Conexión perdida", "rechazado: %s" % _left_reason)
	elif _expect == "accept" and _left_reason != "":
		_finish(false, "expulsado: %s" % _left_reason)
	elif _elapsed >= TIMEOUT:
		_finish_timeout()


func _finish_timeout() -> void:
	if _expect == "reject" or not _client.avatars.has(_client.peer_id):
		_finish(false, "sin resultado esperado")
		return
	var travel := _start.distance_to(_client.avatars[_client.peer_id].global_position)
	var others := _client.avatars.size() - 1
	_finish(travel >= MIN_TRAVEL and others == 1, "recorrió %.1f m, ve a %d más" % [travel, others])


func _finish(passed: bool, detail: String) -> void:
	print("%s %s" % ["PASA" if passed else "FALLA", detail])
	get_tree().quit(0 if passed else 1)
