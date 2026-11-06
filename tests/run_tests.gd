extends SceneTree
## Pruebas headless de reglas: godot --headless --path . --script res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_input_validation()
	_test_velocity()
	_test_input_queue()
	_test_prediction()
	_test_interpolation()
	_test_clock()
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


func _test_prediction() -> void:
	var prediction := Prediction.new()
	for seq in range(1, 6):
		prediction.record(seq, Vector2.UP, 0.0)
	prediction.acknowledge(3)
	_check(prediction.pending.size() == 2, "confirmar quita lo procesado")
	_check(prediction.pending[0].seq == 4, "quedan las entradas sin confirmar, en orden")
	prediction.acknowledge(1)
	_check(prediction.pending.size() == 2, "una confirmación antigua no cambia nada")
	for seq in range(6, 6 + Prediction.MAX_PENDING + 5):
		prediction.record(seq, Vector2.UP, 0.0)
	_check(prediction.pending.size() == Prediction.MAX_PENDING, "las pendientes están acotadas")


func _test_interpolation() -> void:
	var buffer := Interpolation.new()
	_check(buffer.sample(1.0).is_empty(), "sin muestras no hay resultado")
	buffer.push(1.0, Vector3.ZERO, 0.0)
	_check(_near(buffer.sample(5.0).position, Vector3.ZERO), "una sola muestra se mantiene")
	buffer.push(2.0, Vector3(10, 0, 0), 0.0)
	_check(_near(buffer.sample(0.5).position, Vector3.ZERO), "antes del rango usa la primera")
	_check(_near(buffer.sample(1.5).position, Vector3(5, 0, 0)), "interpola entre dos muestras")
	_check(_near(buffer.sample(9.0).position, Vector3(10, 0, 0)), "no extrapola tras la última")
	var angles := Interpolation.new()
	angles.push(0.0, Vector3.ZERO, PI - 0.1)
	angles.push(1.0, Vector3.ZERO, -PI + 0.1)
	_check(absf(absf(angles.sample(0.5).yaw) - PI) < 0.001, "yaw gira por el camino corto")


func _test_clock() -> void:
	_check(is_equal_approx(Interpolation.sync_clock(0.0, 10.0), 10.0), "reloj muy lejos salta")
	var nudged := Interpolation.sync_clock(10.0, 10.1)
	_check(nudged > 10.0 and nudged < 10.1, "reloj cercano se acerca poco a poco")
