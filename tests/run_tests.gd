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
	_test_mitigation()
	_test_geometry()
	_test_combat_state()
	_test_effects()
	_test_data()
	_test_minimap()
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
	_check(MoveRules.vertical_speed(0.0, true, true, 7.0, 0.1) == 7.0, "se salta desde el suelo")
	_check(MoveRules.vertical_speed(0.0, true, false, 7.0, 0.1) == 0.0, "sin saltar sigue en el suelo")
	_check(is_equal_approx(MoveRules.vertical_speed(5.0, false, true, 7.0, 0.1), 3.0), "en el aire no se vuelve a saltar y cae")


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


func _test_mitigation() -> void:
	_check(is_equal_approx(CombatRules.mitigate(100.0, 0.0), 100.0), "sin resistencia no se mitiga")
	_check(is_equal_approx(CombatRules.mitigate(100.0, 100.0), 50.0), "100 de resistencia es la mitad")
	_check(is_equal_approx(CombatRules.mitigate(100.0, -50.0), 100.0), "resistencia negativa no aumenta el daño")
	_check(is_equal_approx(CombatRules.respawn_time(1), 7.0), "reaparición en nivel 1")


func _test_geometry() -> void:
	var forward := Vector3(0, 0, -1)
	_check(CombatRules.in_cone(Vector3.ZERO, forward, Vector3(0, 0, -2), 3.0, 90.0), "cono alcanza de frente")
	_check(not CombatRules.in_cone(Vector3.ZERO, forward, Vector3(0, 0, 2), 3.0, 90.0), "cono no alcanza atrás")
	_check(not CombatRules.in_cone(Vector3.ZERO, forward, Vector3(0, 0, -9), 3.0, 90.0), "cono no pasa su alcance")
	_check(CombatRules.in_radius(Vector3.ZERO, Vector3(3.4, 5, 0), 3.0), "el radio suma el cuerpo e ignora la altura")
	_check(not CombatRules.in_radius(Vector3.ZERO, Vector3(3.6, 0, 0), 3.0), "fuera del radio")
	_check(CombatRules.hits_segment(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 0.5), 0.2), "el segmento toca al objetivo")
	_check(not CombatRules.hits_segment(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 2), 0.2), "el segmento pasa lejos")
	_check(_near(CombatRules.clamp_aim(Vector3.ZERO, Vector3(10, 3, 0), 4.0), Vector3(4, 0, 0)), "el alcance recorta la mira")
	_check(_near(CombatRules.clamp_aim(Vector3.ZERO, Vector3(1, 0, 0), 4.0), Vector3(1, 0, 0)), "dentro del alcance no cambia")
	_check(_near(CombatRules.direction(Vector3.ZERO, Vector3.ZERO, forward), forward), "sin dirección usa la de reserva")


func _hero() -> HeroData:
	var hero := HeroData.new()
	hero.max_health = 100.0
	hero.max_mana = 50.0
	hero.mana_regen = 10.0
	hero.armor = 100.0
	return hero


func _test_combat_state() -> void:
	var ability := AbilityData.new()
	ability.mana_cost = 40.0
	ability.cooldown = 2.0
	var state := CombatState.for_hero(_hero())
	_check(state.can_cast(1, ability), "se puede lanzar con maná y sin cooldown")
	state.spend(1, ability)
	_check(is_equal_approx(state.mana, 10.0), "lanzar gasta maná")
	_check(not state.can_cast(1, ability), "no se lanza en cooldown")
	state.tick(2.1)
	_check(state.cooldowns[1] == 0.0, "el cooldown termina")
	_check(is_equal_approx(state.mana, 31.0), "el maná se regenera")
	_check(not state.can_cast(1, ability), "no se lanza sin maná")
	state.tick(100.0)
	_check(is_equal_approx(state.mana, 50.0), "el maná no pasa del máximo")
	_check(is_equal_approx(state.take_damage(100.0, AbilityData.DamageType.PHYSICAL), 50.0), "la armadura reduce el físico")
	_check(is_equal_approx(state.health, 50.0), "el daño baja la vida")
	state.take_damage(30.0, AbilityData.DamageType.MAGIC)
	_check(is_equal_approx(state.health, 20.0), "la armadura no reduce el mágico")
	state.take_damage(999.0, AbilityData.DamageType.MAGIC)
	_check(not state.is_alive() and state.health == 0.0, "la vida llega a 0 y muere")
	_check(not state.can_cast(1, ability), "los muertos no lanzan")
	_check(state.move_factor() == 0.0, "los muertos no se mueven")
	state.reset()
	_check(state.is_alive() and state.health == 100.0 and state.mana == 50.0, "reaparecer restaura todo")


func _test_effects() -> void:
	var ability := AbilityData.new()
	var state := CombatState.for_hero(_hero())
	state.add_shield(30.0, 1.0)
	state.take_damage(20.0, AbilityData.DamageType.MAGIC)
	_check(is_equal_approx(state.shield, 10.0) and state.health == 100.0, "el escudo absorbe primero")
	state.take_damage(30.0, AbilityData.DamageType.MAGIC)
	_check(state.shield == 0.0 and is_equal_approx(state.health, 80.0), "lo que sobra pasa a la vida")
	state.add_shield(30.0, 1.0)
	state.tick(1.1)
	_check(state.shield == 0.0, "el escudo caduca")
	state.apply_slow(0.4, 1.0)
	_check(is_equal_approx(state.move_factor(), 0.6), "la ralentización reduce la velocidad")
	state.tick(1.1)
	_check(state.move_factor() == 1.0, "la ralentización termina")
	state.apply_stun(1.0)
	_check(state.move_factor() == 0.0 and not state.can_cast(1, ability), "aturdido no se mueve ni lanza")
	state.tick(1.1)
	_check(state.can_cast(1, ability), "el aturdimiento termina")


func _test_minimap() -> void:
	var square := Rect2(-16, -16, 32, 32)
	var size := Vector2(200, 200)
	_check(Minimap.to_minimap(Vector2.ZERO, square, size).is_equal_approx(Vector2(100, 100)), "el centro del mapa va al centro")
	_check(Minimap.to_minimap(Vector2(-16, -16), square, size).is_equal_approx(Vector2.ZERO), "el noroeste va arriba a la izquierda")
	_check(Minimap.to_minimap(Vector2(16, 16), square, size).is_equal_approx(size), "el sureste va abajo a la derecha")
	var wide := Rect2(-20, -10, 40, 20)
	_check(Minimap.to_minimap(Vector2(0, -10), wide, size).is_equal_approx(Vector2(100, 50)), "un mapa alargado mantiene la proporción")


func _test_data() -> void:
	for id in ["guardian", "arcanist"]:
		var hero: HeroData = load("res://data/heroes/%s.tres" % id)
		_check(hero.abilities.size() == 4, "%s tiene 4 poderes" % id)
		for slot in HeroData.SLOT_COUNT:
			_check(hero.ability(slot) != null, "%s tiene el slot %d" % [id, slot])
		_check(hero.ability(HeroData.SLOT_COUNT) == null and hero.ability(-1) == null, "slot inválido devuelve null")
		_check(hero.max_health > 0.0 and hero.max_mana > 0.0, "%s tiene vida y maná" % id)
		for slot in HeroData.SLOT_COUNT:
			var ability := hero.ability(slot)
			_check(ResourceLoader.exists("res://client/icons/%s.svg" % ability.id), "%s tiene icono" % ability.id)
	var guardian: HeroData = load("res://data/heroes/guardian.tres")
	var arcanist: HeroData = load("res://data/heroes/arcanist.tres")
	_check(guardian.attack_type == HeroData.AttackType.MELEE, "Guardián es cuerpo a cuerpo")
	_check(guardian.damage_type == AbilityData.DamageType.PHYSICAL, "Guardián hace daño físico")
	_check(arcanist.attack_type == HeroData.AttackType.RANGED, "Arcanista es a distancia")
	_check(arcanist.damage_type == AbilityData.DamageType.MAGIC, "Arcanista hace daño mágico")
	var mode: MatchModeData = load("res://data/modes/hero_test.tres")
	_check(mode.heroes.size() == 2, "el modo de pruebas ofrece los dos héroes")
	for mode_id in ["hero_test", "line_1v1"]:
		var heroes: Array[HeroData] = load("res://data/modes/%s.tres" % mode_id).heroes
		for hero in heroes:
			_check(ResourceLoader.exists("res://client/heroes/%s.tscn" % hero.id), "%s tiene modelo" % hero.id)
	var map: Node = mode.map.instantiate()
	_check(map.get_node("Dummies").get_child_count() == 4, "el mapa tiene 4 muñecos")
	_check(map.get_node("SpawnPoints").get_child_count() == 4, "el mapa tiene 4 apariciones")
	map.free()
