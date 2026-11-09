class_name Hud
extends CanvasLayer
## Interfaz de partida: retrato, barras, poderes y minimapa.

const SLOT_SCENE := preload("res://client/ability_slot.tscn")
const HERO_VISUAL_PATH := "res://client/heroes/%s.tscn"
const SLOT_KEYS: Array[String] = ["Clic", "1", "2", "3", "4"]
const PORTRAIT_SIZE := Vector2i(256, 256)
const PORTRAIT_EYE := Vector3(0.0, 1.8, -2.4)
const PORTRAIT_TARGET := Vector3(0.0, 1.72, 0.0)
const PORTRAIT_FOV := 26.0

var _hero: HeroData
var _slots: Array[AbilitySlot] = []

@onready var _portrait: TextureRect = $TopLeft/Portrait/Image
@onready var _ring: Panel = $TopLeft/Portrait/Ring
@onready var _respawn: Label = $TopLeft/Portrait/Respawn
@onready var _health: ProgressBar = $TopLeft/Bars/HealthBox/Health
@onready var _shield: ProgressBar = $TopLeft/Bars/HealthBox/Shield
@onready var _health_text: Label = $TopLeft/Bars/HealthBox/Text
@onready var _mana: ProgressBar = $TopLeft/Bars/ManaBox/Mana
@onready var _mana_text: Label = $TopLeft/Bars/ManaBox/Text
@onready var _slot_row: HBoxContainer = $Slots
@onready var _minimap: Minimap = $Minimap


func setup(hero: HeroData) -> void:
	_hero = hero
	_health.max_value = hero.max_health
	_shield.max_value = hero.max_health
	_mana.max_value = hero.max_mana
	_build_portrait(hero)
	var ring: StyleBoxFlat = _ring.get_theme_stylebox("panel").duplicate()
	ring.border_color = CombatVisuals.damage_color(hero.damage_type)
	_ring.add_theme_stylebox_override("panel", ring)
	for slot in SLOT_KEYS.size():
		var ability_slot: AbilitySlot = SLOT_SCENE.instantiate()
		_slot_row.add_child(ability_slot)
		ability_slot.setup(hero.ability(slot), SLOT_KEYS[slot])
		_slots.append(ability_slot)


func setup_minimap(map: Node3D) -> void:
	_minimap.setup(map)


func show_units(own_position: Vector3, own_yaw: float, enemies: Array[Vector3]) -> void:
	_minimap.show_units(own_position, own_yaw, enemies)


func show_state(health: float, mana: float, shield: float, cooldowns: PackedFloat32Array, alive: bool, respawn_left: float) -> void:
	_health.value = health
	_shield.value = minf(health + shield, _hero.max_health)
	_mana.value = mana
	_health_text.text = "%d / %d" % [ceili(health), _hero.max_health]
	if shield > 0.0:
		_health_text.text += "  +%d" % ceili(shield)
	_mana_text.text = "%d / %d" % [floori(mana), _hero.max_mana]
	_portrait.material.set_shader_parameter("dead", not alive)
	_respawn.visible = not alive
	_respawn.text = "%d" % ceili(respawn_left)
	for slot in _slots.size():
		_slots[slot].show_state(cooldowns[slot], mana)


## Renderiza el modelo una sola vez, así el retrato siempre coincide con él.
func _build_portrait(hero: HeroData) -> void:
	var viewport := SubViewport.new()
	viewport.size = PORTRAIT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(viewport)
	viewport.add_child(load(HERO_VISUAL_PATH % hero.id).instantiate())
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var camera := Camera3D.new()
	camera.fov = PORTRAIT_FOV
	camera.environment = environment
	viewport.add_child(camera)
	camera.look_at_from_position(PORTRAIT_EYE, PORTRAIT_TARGET)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.look_at_from_position(Vector3(1.5, 3.0, -3.0), PORTRAIT_TARGET)
	_portrait.texture = viewport.get_texture()
