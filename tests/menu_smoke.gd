extends Node
## Pulsa los botones del menú real; lo lanza tests/net_smoke.sh.
## Argumentos: --expect enter|fail [--port N] [--practice] [--players N]
## Con --practice usa "Practicar en local" en vez de "Conectar".
## Con --players espera a ver a N personajes en la partida.

const TIMEOUT := 12.0

var _main: Control
var _expect := "enter"
var _players := 1
var _elapsed := 0.0
var _hid_too_soon := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_expect = args[args.find("--expect") + 1]
	if "--players" in args:
		_players = int(args[args.find("--players") + 1])
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	if "--practice" in args:
		_main.get_node("Menu/Practice").pressed.emit()
	else:
		_main.get_node("Menu/Port").text = args[args.find("--port") + 1]
		_main.get_node("Menu/Connect").pressed.emit()
	_hid_too_soon = not _main.get_node("Menu").visible


func _process(delta: float) -> void:
	_elapsed += delta
	var status: String = _main.get_node("Menu/Status").text
	var menu_visible: bool = _main.get_node("Menu").visible
	if _hid_too_soon:
		_finish(false, "el menú se ocultó antes de entrar")
	elif _expect == "enter" and not menu_visible and _avatar_count() >= _players:
		_finish(true, "el menú entró a la partida, ve %d personajes" % _avatar_count())
	elif _expect == "fail" and not _main.get_node("Menu/Connect").disabled:
		_finish(status != "Conectando…" and status != "", "sin servidor avisa en %.0f s: %s" % [_elapsed, status])
	elif _elapsed >= TIMEOUT:
		_finish(false, "sin resultado; estado: %s" % status)


func _avatar_count() -> int:
	for child in _main.get_children():
		if child is MatchClient:
			return child.avatars.size()
	return 0


func _finish(passed: bool, detail: String) -> void:
	print("%s %s" % ["PASA" if passed else "FALLA", detail])
	get_tree().quit(0 if passed else 1)
