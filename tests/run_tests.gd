extends SceneTree
## Pruebas headless de reglas: godot --headless --path . --script res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_input_validation()
	_test_velocity()
	_test_input_queue()
	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FALLA: ", label)


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


func _test_input_validation() -> void:
	_check(MoveRules.is_valid_input(2, 1, Vector2.UP, 0.0), "entrada nueva es válida")
	_check(not MoveRules.is_valid_input(1, 1, Vector2.UP, 0.0), "seq repetido se descarta")
	_check(not MoveRules.is_valid_input(1, 2, Vector2.UP, 0.0), "seq antiguo se descarta")
	_check(not MoveRules.is_valid_input(2, 1, Vector2(NAN, 0.0), 0.0), "move NaN se descarta")
	_check(not MoveRules.is_valid_input(2, 1, Vector2(INF, 0.0), 0.0), "move infinito se descarta")
	_check(not MoveRules.is_valid_input(2, 1, Vector2.UP, NAN), "yaw NaN se descarta")


func _test_velocity() -> void:
	_check(_near(MoveRules.velocity(Vector2(0, -1), 0.0, 6.0), Vector3(0, 0, -6)), "adelante es -Z")
	_check(_near(MoveRules.velocity(Vector2(0, -1), PI / 2.0, 6.0), Vector3(-6, 0, 0)), "yaw gira la dirección")
	_check(is_equal_approx(MoveRules.velocity(Vector2(100, 100), 1.0, 6.0).length(), 6.0), "move largo no da más velocidad")
	_check(_near(MoveRules.velocity(Vector2.ZERO, 1.0, 6.0), Vector3.ZERO), "sin entrada no hay movimiento")


func _test_input_queue() -> void:
	var queue := InputQueue.new()
	_check(queue.pop().is_empty(), "cola vacía devuelve vacío")
	_check(queue.push(1, Vector2.UP, 0.0), "acepta entrada válida")
	_check(not queue.push(1, Vector2.UP, 0.0), "rechaza seq repetido")
	_check(queue.pop().seq == 1, "consume en orden")
	for seq in range(2, 2 + InputQueue.MAX_SIZE + 3):
		queue.push(seq, Vector2.UP, 0.0)
	var count := 0
	while not queue.pop().is_empty():
		count += 1
	_check(count == InputQueue.MAX_SIZE, "la cola está acotada")
