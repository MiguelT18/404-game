extends Control
## Decide si este proceso es servidor o cliente.

const DEFAULT_PORT := 7777
const HEROES_PATH := "res://data/heroes/"
const LOCAL_HOST := "127.0.0.1"
const PRACTICE_MODE := "hero_test"

@onready var _menu: Control = $Menu
@onready var _connect: Button = $Menu/Connect
@onready var _practice: Button = $Menu/Practice
@onready var _host: LineEdit = $Menu/Host
@onready var _port: LineEdit = $Menu/Port
@onready var _hero: OptionButton = $Menu/Hero
@onready var _status: Label = $Menu/Status


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_menu.hide()
		_start_server(args)
	else:
		_fill_heroes()
		_connect.pressed.connect(_on_connect_pressed)
		_practice.pressed.connect(_on_practice_pressed)


func _fill_heroes() -> void:
	for file in ResourceLoader.list_directory(HEROES_PATH):
		var hero: HeroData = load(HEROES_PATH + file)
		_hero.add_item(hero.display_name)
		_hero.set_item_metadata(_hero.item_count - 1, String(hero.id))


func _start_server(args: PackedStringArray) -> void:
	var port := _arg(args, "--port", str(DEFAULT_PORT)).to_int()
	var mode_path := "res://data/modes/%s.tres" % _arg(args, "--mode", "line_1v1")
	if port < 1 or port > 65535 or not ResourceLoader.exists(mode_path):
		printerr("Argumentos inválidos: puerto %d, modo %s" % [port, mode_path])
		get_tree().quit(1)
		return
	var server := MatchServer.new()
	server.quit_when_empty = "--quit-when-empty" in args
	add_child(server)
	var error := server.start(port, load(mode_path))
	if error != OK:
		printerr("No se pudo abrir el puerto %d: %s" % [port, error_string(error)])
		get_tree().quit(1)


func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var index := args.find(flag)
	return args[index + 1] if index != -1 and index + 1 < args.size() else fallback


func _on_connect_pressed() -> void:
	_join(_host.text.strip_edges(), _port.text.to_int())


## Si ya hay un servidor local, el nuevo no puede abrir el puerto y se cierra solo,
## así que un segundo jugador entra a la misma partida.
func _on_practice_pressed() -> void:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--headless", "--", "--server", "--port", str(DEFAULT_PORT)])
	args.append_array(["--mode", PRACTICE_MODE, "--quit-when-empty"])
	if OS.create_process(OS.get_executable_path(), args) == -1:
		_status.text = "No se pudo arrancar el servidor local"
		return
	_join(LOCAL_HOST, DEFAULT_PORT)


func _join(host: String, port: int) -> void:
	if port < 1 or port > 65535:
		_status.text = "Puerto inválido"
		return
	var client := MatchClient.new()
	add_child(client)
	var error := client.join(host, port, _hero.get_selected_metadata())
	if error != OK:
		client.queue_free()
		_status.text = "No se pudo conectar: %s" % error_string(error)
		return
	client.entered.connect(_menu.hide)
	client.left.connect(_on_left)
	_status.text = "Conectando…"
	_set_buttons_enabled(false)


func _on_left(reason: String) -> void:
	_status.text = reason
	_set_buttons_enabled(true)
	_menu.show()


func _set_buttons_enabled(enabled: bool) -> void:
	_connect.disabled = not enabled
	_practice.disabled = not enabled
