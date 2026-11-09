extends Node
## Prueba cada pieza de habilidad con física real, sin red:
## godot --headless --path . res://tests/ability_test.tscn

const MAP_SCENE := preload("res://maps/hero_test_map.tscn")
const AVATAR_SCENE := preload("res://shared/avatar.tscn")
const GUARDIAN := preload("res://data/heroes/guardian.tres")
const ARCANIST := preload("res://data/heroes/arcanist.tres")
const TICK := 1.0 / 30.0

var _failures := 0
var _map: Node3D
var _runner: AbilityRunner
var _avatar: Avatar
var _caster: CombatTarget
var _dummies: Dictionary[String, CombatTarget] = {}
var _events: Array[Array] = []


func _ready() -> void:
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	await _run(TICK * 2.0)
	await _test_cone()
	await _test_projectile()
	await _test_wall_blocks_projectile()
	await _test_dash()
	_test_area()
	_test_shield()
	await _test_zone()
	await _test_blink()
	await _test_leap()
	await _test_beam()
	_test_death()
	await _test_jump()
	await _test_dash_from_air()
	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FALLA: ", label)


## Empieza una escena limpia con el héroe en `at`.
func _setup(hero: HeroData, at: Vector3) -> void:
	if _avatar != null:
		_avatar.free()
	_avatar = AVATAR_SCENE.instantiate()
	_avatar.hero = hero
	_map.add_child(_avatar)
	_avatar.global_position = at
	_caster = CombatTarget.new(1, _avatar, CombatState.for_hero(hero), 7.0)
	_runner = AbilityRunner.new(_map)
	_runner.targets.append(_caster)
	_runner.event_emitted.connect(func(event: Array) -> void: _events.append(event))
	_events.clear()
	for dummy: TrainingDummy in _map.get_node("Dummies").get_children():
		var unit := CombatTarget.new(-(dummy.get_index() + 1), dummy, CombatState.for_dummy(dummy.data), 3.0)
		_dummies[dummy.name] = unit
		_runner.targets.append(unit)


func _run(seconds: float) -> void:
	for tick in ceili(seconds / TICK):
		await get_tree().physics_frame
		if _runner != null:
			for target in _runner.targets:
				target.state.tick(TICK)
			_runner.tick(TICK)


func _lost(dummy: String) -> float:
	var state := _dummies[dummy].state
	return state.max_health - state.health


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


## Aplica entradas como el servidor y devuelve la altura máxima alcanzada.
func _simulate_jump(ticks: int, jump: bool) -> float:
	var peak := 0.0
	for tick in ticks:
		await get_tree().physics_frame
		_avatar.apply_input(Vector2.ZERO, 0.0, jump)
		peak = maxf(peak, _avatar.global_position.y)
	return peak


func _test_jump() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 12))
	var peak: float = await _simulate_jump(1, true)
	peak = maxf(peak, await _simulate_jump(30, false))
	_check(peak > 1.0 and peak < 1.5, "el salto alcanza la altura esperada: %.2f" % peak)
	_check(_avatar.global_position.y == 0.0 and _avatar.vertical_speed == 0.0, "aterriza en el suelo")
	await _simulate_jump(1, true)
	await _simulate_jump(3, false)
	var rising := _avatar.vertical_speed
	await _simulate_jump(1, true)
	_check(_avatar.vertical_speed < rising, "no se salta otra vez en el aire")
	await _simulate_jump(30, false)
	_avatar.move_factor = 0.0
	_check(await _simulate_jump(3, true) == 0.0, "aturdido no salta")
	_avatar.move_factor = 1.0
	_setup(GUARDIAN, Vector3(0, 0, -14))
	var wall_peak := 0.0
	for tick in 30:
		await get_tree().physics_frame
		_avatar.apply_input(Vector2(0, -1), 0.0, tick == 3)
		wall_peak = maxf(wall_peak, _avatar.global_position.y)
	_check(_avatar.global_position.z > -14.6, "el muro detiene al personaje")
	_check(wall_peak < 1.5, "saltar contra un muro no da más altura: %.2f" % wall_peak)


func _test_dash_from_air() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 12))
	_avatar.global_position.y = 1.0
	_runner.cast(_caster, GUARDIAN.ability(1), Vector3(0, 0, 6))
	await _run(0.5)
	_check(_avatar.global_position.y == 0.0, "la embestida en el aire termina en el suelo")
	_check(_near(_lost("Normal"), 70.0), "saltar no impide golpear")


func _test_cone() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 8))
	_runner.cast(_caster, GUARDIAN.basic_attack, Vector3(0, 0, 6))
	_check(_near(_lost("Normal"), 40.0), "el golpe daña al muñeco de enfrente")
	_check(_events[0] == [Net.Event.CAST, 1, GUARDIAN.basic_attack.id], "se avisa del lanzamiento y de su habilidad")
	var effects := _events.filter(func(event: Array) -> bool: return event[0] == Net.Event.EFFECT)
	_check(effects.size() == 1 and effects[0][4] == 1 and effects[0][5] == GUARDIAN.basic_attack.id, "el efecto dice quién lo lanzó y con qué")
	_check(_lost("Far") == 0.0, "el golpe no alcanza lejos")
	_setup(GUARDIAN, Vector3(0, 0, 8))
	_runner.cast(_caster, GUARDIAN.basic_attack, Vector3(0, 0, 20))
	_check(_lost("Normal") == 0.0, "el golpe no alcanza por la espalda")
	_setup(GUARDIAN, Vector3(-5, 0, 8))
	_runner.cast(_caster, GUARDIAN.basic_attack, Vector3(-5, 0, 6))
	_check(_near(_lost("Armored"), 40.0 / 3.0), "la armadura mitiga el daño físico")
	await _run(TICK)


func _test_projectile() -> void:
	_setup(ARCANIST, Vector3(0, 0, 12))
	_runner.cast(_caster, ARCANIST.ability(1), Vector3(0, 0, 6))
	_check(_runner.entities().size() == 1, "el dardo aparece como entidad")
	_check(_runner.entities()[0][3] == ARCANIST.ability(1).id, "la entidad dice qué habilidad es, para dibujarla")
	await _run(0.5)
	_check(_near(_lost("Normal"), 90.0), "el dardo daña")
	_check(_runner.entities().is_empty(), "el dardo desaparece al impactar")
	_setup(ARCANIST, Vector3(5, 0, 12))
	_runner.cast(_caster, ARCANIST.ability(1), Vector3(5, 0, 6))
	await _run(0.5)
	_check(_near(_lost("Antimagic"), 30.0), "la resistencia mitiga el daño mágico")
	_check(_lost("Armored") == 0.0, "el dardo solo daña a quien toca")
	_setup(ARCANIST, Vector3(12, 0, 6))
	_runner.cast(_caster, ARCANIST.basic_attack, Vector3(-30, 0, 6))
	await _run(1.0)
	_check(_near(_lost("Antimagic"), 35.0 / 3.0) and _lost("Normal") == 0.0, "el proyectil se detiene en el primer objetivo")


func _test_wall_blocks_projectile() -> void:
	_setup(ARCANIST, Vector3(-7, 0, 6))
	var far := _dummies["Far"]
	var original := far.position()
	far.body.global_position = Vector3(-7, 0, -4)
	_runner.cast(_caster, ARCANIST.ability(1), Vector3(-7, 0, -4))
	await _run(0.8)
	_check(_lost("Far") == 0.0, "el pilar bloquea el proyectil")
	_check(_runner.entities().is_empty(), "el proyectil desaparece en el muro")
	far.body.global_position = original


func _test_dash() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 12))
	_runner.cast(_caster, GUARDIAN.ability(1), Vector3(0, 0, 6))
	_check(_caster.state.is_stunned(), "no se controla durante la embestida")
	await _run(0.5)
	_check(_near(_caster.position().z, 5.0), "la embestida recorre todo su alcance")
	_check(_near(_lost("Normal"), 70.0), "la embestida daña una sola vez")
	_setup(GUARDIAN, Vector3(-7, 0, 5))
	_runner.cast(_caster, GUARDIAN.ability(1), Vector3(-7, 0, -5))
	await _run(0.5)
	_check(_caster.position().z > 1.5, "la embestida no atraviesa el pilar")


func _test_area() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 8))
	_runner.cast(_caster, GUARDIAN.ability(2), Vector3(0, 0, 6))
	_check(_near(_lost("Normal"), 60.0), "el golpe circular daña cerca")
	_check(_near(_dummies["Normal"].state.move_factor(), 0.6), "el golpe circular ralentiza")
	_check(_lost("Armored") == 0.0, "el golpe circular no alcanza lejos")


func _test_shield() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 12))
	_runner.cast(_caster, GUARDIAN.ability(3), Vector3.ZERO)
	_check(_caster.state.shield == 150.0, "Baluarte da escudo")


func _test_zone() -> void:
	_setup(ARCANIST, Vector3(0, 0, 12))
	_runner.cast(_caster, ARCANIST.ability(2), Vector3(0, 0, 6))
	await _run(1.1)
	_check(_near(_lost("Normal"), 60.0), "el campo daña en cada pulso")
	_check(_dummies["Normal"].state.move_factor() < 1.0, "el campo ralentiza")
	_check(_runner.entities().size() == 1, "el campo sigue activo")
	await _run(3.2)
	_check(_runner.entities().is_empty(), "el campo termina")


func _test_blink() -> void:
	_setup(ARCANIST, Vector3(0, 0, 12))
	_runner.cast(_caster, ARCANIST.ability(3), Vector3(0, 0, -20))
	_check(_near(_caster.position().z, 5.0), "Parpadeo se recorta a su alcance")
	await _run(TICK)
	_setup(ARCANIST, Vector3(-7, 0, 5))
	_runner.cast(_caster, ARCANIST.ability(3), Vector3(-7, 0, -5))
	_check(_caster.position().z > 1.5, "Parpadeo no atraviesa el pilar")


func _test_leap() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 12))
	_runner.cast(_caster, GUARDIAN.ability(4), Vector3(0, 0, 7))
	await _run(0.2)
	_check(_lost("Normal") == 0.0, "Impacto daña al caer, no al saltar")
	await _run(0.4)
	_check(_near(_caster.position().z, 7.0), "Impacto llega al punto elegido")
	_check(_near(_lost("Normal"), 120.0), "Impacto daña en área")
	_check(_dummies["Normal"].state.is_stunned(), "Impacto aturde")


func _test_beam() -> void:
	_setup(ARCANIST, Vector3(-10, 0, 6))
	_runner.cast(_caster, ARCANIST.ability(4), Vector3(10, 0, 6))
	_check(_caster.state.is_stunned(), "no se mueve mientras carga")
	await _run(0.5)
	_check(_lost("Normal") == 0.0, "Descarga espera a terminar la carga")
	await _run(0.4)
	_check(_near(_lost("Armored"), 200.0) and _near(_lost("Normal"), 200.0), "Descarga atraviesa enemigos")
	_check(_near(_lost("Antimagic"), 200.0 / 3.0), "Descarga aplica la resistencia mágica")


func _test_death() -> void:
	_setup(GUARDIAN, Vector3(0, 0, 8))
	var dummy := _dummies["Normal"]
	dummy.state.health = 10.0
	_runner.cast(_caster, GUARDIAN.basic_attack, Vector3(0, 0, 6))
	_check(not dummy.state.is_alive(), "el muñeco muere a 0 de vida")
	_check(dummy.respawn_left == 3.0, "morir inicia la cuenta de reaparición")
	_check(_events.any(func(event: Array) -> bool: return event[0] == Net.Event.DEATH), "se avisa de la muerte")
	_events.clear()
	_runner.cast(_caster, GUARDIAN.basic_attack, Vector3(0, 0, 6))
	_check(not _events.any(func(event: Array) -> bool: return event[0] == Net.Event.DAMAGE), "los muertos no reciben daño")
	_test_respawn()


func _test_respawn() -> void:
	var server := MatchServer.new()
	_caster.state.take_damage(9999.0, AbilityData.DamageType.MAGIC)
	_caster.respawn_left = 7.0
	_avatar.global_position = Vector3(3, 0, 3)
	server._update_unit(_caster, 6.0)
	_check(not _caster.state.is_alive(), "no reaparece antes de tiempo")
	server._update_unit(_caster, 1.1)
	_check(_caster.state.is_alive(), "reaparece al terminar la cuenta")
	_check(_near(_caster.position().z, 8.0), "reaparece en su base")
	_check(_caster.state.health == _caster.state.max_health, "reaparece con toda la vida")
	server.free()
