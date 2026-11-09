class_name AbilitySlot
extends Control
## Casilla de un poder: icono, tecla y cooldown en forma de reloj.

const ICON_PATH := "res://client/icons/%s.svg"
const NO_MANA_TINT := Color(0.35, 0.45, 1.0)
const READY_FLASH_TIME := 0.3

var _ability: AbilityData
var _left := 0.0

@onready var _icon: TextureRect = $Icon
@onready var _clock: TextureProgressBar = $Clock
@onready var _time: Label = $Time
@onready var _key: Label = $Key
@onready var _flash: ColorRect = $Flash


func setup(ability: AbilityData, key: String) -> void:
	_ability = ability
	_icon.texture = load(ICON_PATH % ability.id)
	_key.text = key


## Corrige el reloj con el valor del servidor.
func show_state(cooldown_left: float, mana: float) -> void:
	_set_left(cooldown_left)
	_icon.modulate = Color.WHITE if mana >= _ability.mana_cost else NO_MANA_TINT


# Entre instantáneas baja solo, para que el reloj no avance a saltos.
func _process(delta: float) -> void:
	if _ability != null and _left > 0.0:
		_set_left(maxf(_left - delta, 0.0))


func _set_left(left: float) -> void:
	if _left > 0.0 and left == 0.0:
		_flash_ready()
	_left = left
	_clock.value = _left / _ability.cooldown
	_time.visible = _left > 0.0
	# Se redondea hacia arriba para no mostrar 0.0 con tiempo restante.
	_time.text = "%.1f" % (ceilf(_left * 10.0) / 10.0) if _left < 1.0 else "%d" % ceili(_left)


func _flash_ready() -> void:
	_flash.modulate.a = 0.8
	create_tween().tween_property(_flash, "modulate:a", 0.0, READY_FLASH_TIME)
