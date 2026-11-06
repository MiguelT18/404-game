extends Control
## Decide si este proceso es servidor o cliente.

const DEFAULT_PORT := 7777

@onready var _menu: Control = $Menu
@onready var _host: LineEdit = $Menu/Host
@onready var _port: LineEdit = $Menu/Port
@onready var _status: Label = $Menu/Status


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_menu.hide()
		_start_server(args)
	else:
		$Menu/Connect.pressed.connect(_on_connect_pressed)


func _start_server(args: PackedStringArray) -> void:
	var port := _arg(args, "--port", str(DEFAULT_PORT)).to_int()
	var mode_path := "res://data/modes/%s.tres" % _arg(args, "--mode", "line_1v1")
	if port < 1 or port > 65535 or not ResourceLoader.exists(mode_path):
		printerr("Argumentos inválidos: puerto %d, modo %s" % [port, mode_path])
		get_tree().quit(1)
		return
	var server := MatchServer.new()
	add_child(server)
	var error := server.start(port, load(mode_path))
	if error != OK:
		printerr("No se pudo abrir el puerto %d: %s" % [port, error_string(error)])
		get_tree().quit(1)


func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var index := args.find(flag)
	return args[index + 1] if index != -1 and index + 1 < args.size() else fallback


func _on_connect_pressed() -> void:
	var port := _port.text.to_int()
	if port < 1 or port > 65535:
		_status.text = "Puerto inválido"
		return
	var client := MatchClient.new()
	add_child(client)
	var error := client.join(_host.text.strip_edges(), port)
	if error != OK:
		client.queue_free()
		_status.text = "No se pudo conectar: %s" % error_string(error)
		return
	client.left.connect(_on_left)
	_status.text = ""
	_menu.hide()


func _on_left(reason: String) -> void:
	_status.text = reason
	_menu.show()
