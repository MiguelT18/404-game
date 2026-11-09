class_name HeroAnimator
extends Node
## Gestos del modelo al lanzar habilidades. Mueve el modelo y su arma, nunca el
## cuerpo, así que es solo presentación. Va como hijo del modelo y busca en él
## `Weapon`, `Weapon/Tip` y, si lo tiene, `Shield`.

## Altura del salto de Impacto. El servidor lo mueve en el plano; el arco es visual.
const LEAP_HEIGHT := 2.2
# Cuánto se adelanta el escudo al cubrirse, desde su pose de reposo.
const SHIELD_FRONT := Vector3(0.42, 0.1, -0.47)
const SHIELD_TURN := 1.35
## Lo que tarda en tomar impulso antes de un golpe.
const WIND_UP := 0.07

var _model: Node3D
var _weapon: Node3D
var _shield: Node3D
var _rest: Dictionary[Node3D, Transform3D] = {}
var _tween: Tween


func _ready() -> void:
	_model = get_parent()
	_weapon = _model.get_node_or_null("Weapon")
	_shield = _model.get_node_or_null("Shield")
	for part: Node3D in [_model, _weapon, _shield]:
		if part != null:
			_rest[part] = part.transform


## Punto del que salen los disparos y las cargas.
func tip() -> Node3D:
	var node := _model.get_node_or_null("Weapon/Tip")
	return node if node != null else _model


func play(ability: AbilityData) -> void:
	if _tween != null:
		_tween.kill()
	_restore()
	_tween = create_tween()
	# Con interpolación de física, moverlo fuera del tick se vería a saltos.
	if _model.is_physics_interpolated_and_enabled():
		_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	match ability.kind:
		AbilityData.Kind.CONE:
			_swing()
		AbilityData.Kind.PROJECTILE:
			_thrust()
		AbilityData.Kind.AREA:
			_spin()
		AbilityData.Kind.DASH:
			_lean(ability.reach / ability.speed)
		AbilityData.Kind.SHIELD:
			_brace()
		AbilityData.Kind.ZONE:
			_slam()
		AbilityData.Kind.BLINK:
			_vanish()
		AbilityData.Kind.LEAP:
			_leap(ability.duration)
		AbilityData.Kind.BEAM:
			_channel(ability.cast_delay)
	_tween.tween_callback(_restore)


# Toma impulso hacia la derecha y descarga el golpe en diagonal.
func _swing() -> void:
	_turn(_weapon, Vector3(1.2, 0, -0.3), WIND_UP)
	_turn(_model, Vector3(0, -0.35, 0), WIND_UP, true)
	_turn(_weapon, Vector3(-1.9, 0, 0.4), 0.09, false, Tween.EASE_IN)
	_turn(_model, Vector3(0.08, 0.3, 0), 0.09, true, Tween.EASE_IN)
	_tween.tween_interval(0.06)
	_back(0.22)


# Empuja el arma hacia delante, como si lanzara el proyectil con ella.
func _thrust() -> void:
	_turn(_weapon, Vector3(-1.0, 0, 0), 0.07)
	_shift(_weapon, Vector3(0, 0.05, -0.3), 0.07, true)
	_turn(_model, Vector3(-0.08, 0, 0), 0.07, true)
	_tween.tween_interval(0.05)
	_back(0.25)


# Gira sobre sí mismo con el arma extendida.
func _spin() -> void:
	_turn(_weapon, Vector3(0, 0, -1.4), 0.08)
	_squash(Vector3(1.05, 0.92, 1.05), 0.08, true)
	_tween.tween_property(_model, "rotation:y", _rest[_model].basis.get_euler().y + TAU, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_back(0.2)


# Se inclina hacia delante durante la carrera, con el escudo por delante.
func _lean(duration: float) -> void:
	_turn(_model, Vector3(-0.35, 0, 0), 0.08)
	_turn(_weapon, Vector3(-0.8, 0, 0), 0.08, true)
	_cover(0.08)
	_tween.tween_interval(maxf(duration - 0.08, 0.0))
	_back(0.2)


# Se cubre y se agacha un poco para aguantar.
func _brace() -> void:
	_squash(Vector3(1.06, 0.9, 1.06), 0.12)
	_cover(0.12)
	_turn(_weapon, Vector3(0.6, 0, 0), 0.12, true)
	_tween.tween_interval(0.5)
	_back(0.3)


# Levanta el arma y la clava en el suelo.
func _slam() -> void:
	_turn(_weapon, Vector3(0.5, 0, 0), 0.14)
	_squash(Vector3(0.97, 1.05, 0.97), 0.14, true)
	_turn(_weapon, Vector3(-0.9, 0, 0), 0.08, false, Tween.EASE_IN)
	_squash(Vector3(1.05, 0.92, 1.05), 0.08, true)
	_tween.tween_interval(0.08)
	_back(0.3)


# Se estrecha hasta casi desaparecer y reaparece de golpe.
func _vanish() -> void:
	_squash(Vector3(0.15, 1.4, 0.15), 0.07, false, Tween.EASE_IN)
	_tween.tween_property(_model, "transform", _rest[_model], 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Se agacha, salta en arco con el arma en alto y la descarga al caer.
func _leap(duration: float) -> void:
	const CROUCH := 0.07
	const SLAM := 0.1
	var air := maxf(duration - CROUCH, SLAM)
	_squash(Vector3(1.12, 0.82, 1.12), CROUCH)
	_turn(_weapon, Vector3(1.5, 0, 0), CROUCH, true)
	_tween.tween_method(_lift, 0.0, 1.0, air)
	_tween.parallel().tween_property(_model, "scale", _scaled(Vector3(0.95, 1.1, 0.95)), 0.15)
	var slam := _turn(_weapon, Vector3(-1.8, 0, 0), SLAM, true, Tween.EASE_IN)
	if slam != null:
		slam.set_delay(air - SLAM)
	_squash(Vector3(1.15, 0.8, 1.15), 0.05)
	_back(0.25)


# Apunta con el arma mientras carga, temblando cada vez más, y retrocede al disparar.
func _channel(charge: float) -> void:
	const AIM := 0.15
	_turn(_weapon, Vector3(-1.3, 0, 0), AIM)
	_shift(_weapon, Vector3(0, 0.15, -0.2), AIM, true)
	_turn(_model, Vector3(0.08, 0, 0), AIM, true)
	_tween.tween_method(_tremble, 0.0, 1.0, maxf(charge - AIM, 0.0))
	_turn(_model, Vector3(0.25, 0, 0), 0.05)
	_tween.tween_interval(0.1)
	_back(0.35)


func _lift(t: float) -> void:
	_model.position.y = _rest[_model].origin.y + LEAP_HEIGHT * 4.0 * t * (1.0 - t)


func _tremble(t: float) -> void:
	_model.rotation.z = _rest[_model].basis.get_euler().z + sin(t * 90.0) * 0.03 * t


func _cover(time: float) -> void:
	if _shield == null:
		return
	_shift(_shield, SHIELD_FRONT, time, true)
	_turn(_shield, Vector3(0, SHIELD_TURN, 0), time, true)


## Gira `part` respecto a su reposo. Sin `part`, solo espera para no descuadrar el ritmo.
func _turn(part: Node3D, offset: Vector3, time: float, with_previous := false, ease := Tween.EASE_OUT) -> PropertyTweener:
	if part == null:
		if not with_previous:
			_tween.tween_interval(time)
		return null
	if with_previous:
		_tween.parallel()
	return _tween.tween_property(part, "rotation", _rest[part].basis.get_euler() + offset, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(ease)


func _shift(part: Node3D, offset: Vector3, time: float, with_previous := false) -> void:
	if part == null:
		return
	if with_previous:
		_tween.parallel()
	_tween.tween_property(part, "position", _rest[part].origin + offset, time).set_trans(Tween.TRANS_SINE)


func _squash(factor: Vector3, time: float, with_previous := false, ease := Tween.EASE_OUT) -> void:
	if with_previous:
		_tween.parallel()
	_tween.tween_property(_model, "scale", _scaled(factor), time).set_trans(Tween.TRANS_SINE).set_ease(ease)


func _scaled(factor: Vector3) -> Vector3:
	return _rest[_model].basis.get_scale() * factor


# Vuelve todo a su reposo a la vez.
func _back(time: float) -> void:
	var first := true
	for part: Node3D in _rest:
		if not first:
			_tween.parallel()
		_tween.tween_property(part, "transform", _rest[part], time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		first = false


func _restore() -> void:
	for part: Node3D in _rest:
		part.transform = _rest[part]
