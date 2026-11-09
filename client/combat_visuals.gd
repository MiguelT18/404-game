class_name CombatVisuals
extends Node3D
## Dibuja entidades y efectos de combate. Solo presentación.
## Cada pieza de habilidad (`AbilityData.Kind`) tiene su efecto, así que una
## habilidad nueva se ve bien sin código propio.

## Fuerza de 0 a 1 para que la cámara tiemble.
signal shaken(strength: float)

const PHYSICAL_COLOR := Color(1.0, 0.6, 0.2)
const MAGIC_COLOR := Color(0.6, 0.5, 1.0)
const SHIELD_COLOR := Color(1.0, 0.85, 0.45)
const LABEL_HEIGHT := 2.6
const NUMBER_TIME := 0.8
const SHOT_HEIGHT := 1.0
const SLASH_HEIGHT := 1.2
const FADE_TIME := 0.4
# Los demás se ven con retraso; sus efectos esperan lo mismo para coincidir.
const REMOTE_DELAY := Interpolation.DELAY

## El mismo diccionario que `MatchClient.avatars`.
var avatars: Dictionary[int, Avatar] = {}
var own_id := 0

var _map: Node3D
var _abilities: Dictionary[StringName, AbilityData] = {}
var _nodes: Dictionary[int, Node3D] = {}
var _buffers: Dictionary[int, Interpolation] = {}
var _ending: Dictionary[int, bool] = {}
var _shields: Dictionary[int, Node3D] = {}


func _init(map: Node3D, mode: MatchModeData) -> void:
	_map = map
	# Todo se mueve a mano en `_process`.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for hero in mode.heroes:
		for slot in HeroData.SLOT_COUNT:
			var ability := hero.ability(slot)
			if ability != null:
				_abilities[ability.id] = ability


static func damage_color(type: AbilityData.DamageType) -> Color:
	return PHYSICAL_COLOR if type == AbilityData.DamageType.PHYSICAL else MAGIC_COLOR


static func ability_color(ability: AbilityData) -> Color:
	return ability.fx_color if ability.fx_color.a > 0.0 else damage_color(ability.damage_type)


func update_entities(time: float, entities: Array) -> void:
	var seen: Dictionary[int, bool] = {}
	for entity: Array in entities:
		var id: int = entity[0]
		seen[id] = true
		match entity[1]:
			Net.Entity.DUMMY:
				_update_dummy(id, entity)
			Net.Entity.PROJECTILE:
				_update_projectile(id, time, entity)
			Net.Entity.ZONE:
				_update_zone(id, entity)
	for id: int in _nodes.keys():
		if not seen.has(id) and not _ending.has(id):
			_end_entity(id)


func sample(time: float) -> void:
	for id: int in _buffers:
		var sampled := _buffers[id].sample(time)
		if sampled.is_empty():
			continue
		var node := _nodes[id]
		var next: Vector3 = sampled.position + Vector3.UP * SHOT_HEIGHT
		var step := next - node.global_position
		node.global_position = next
		if step.length_squared() > 0.0001 and absf(step.normalized().y) < 0.99:
			node.look_at(next + step)


func show_event(event: Array) -> void:
	match event[0]:
		Net.Event.DAMAGE:
			_after(_delay(event[1]), _show_hit.bind(event[1], event[2], event[3], event[4]))
		Net.Event.CAST:
			if _abilities.has(event[2]):
				_after(_delay(event[1]), _show_cast.bind(event[1], _abilities[event[2]]))
		Net.Event.EFFECT:
			if _abilities.has(event[5]):
				_after(_delay(event[4]), _show_effect.bind(event[1], event[2], event[3], event[4], _abilities[event[5]]))


## Muestra u oculta la burbuja de escudo de un jugador según su estado.
func show_shield(id: int, active: bool) -> void:
	var model := _model(id)
	if active and not _shields.has(id) and model != null:
		var bubble := Fx.sphere(1.0, Fx.shield_material(SHIELD_COLOR))
		bubble.scale = Vector3(1.1, 1.3, 1.1) * 0.3
		model.add_child(bubble)
		bubble.position.y = 1.15
		bubble.create_tween().tween_property(bubble, "scale", Vector3(1.1, 1.3, 1.1), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shields[id] = bubble
	elif not active and _shields.has(id):
		var bubble := _shields[id]
		_shields.erase(id)
		if is_instance_valid(bubble):
			Fx.burst(self, bubble.global_position, _motes(SHIELD_COLOR, 24, 3.5, 0.4))
			bubble.create_tween().tween_property(bubble, "scale", bubble.scale * 1.25, 0.15)
			Fx.fade_out(bubble, 0.15)


func _delay(source_id: int) -> float:
	return 0.0 if source_id == own_id else REMOTE_DELAY


func _after(seconds: float, callback: Callable) -> void:
	if seconds <= 0.0:
		callback.call()
	else:
		get_tree().create_timer(seconds).timeout.connect(callback)


func _model(id: int) -> Node3D:
	return avatars[id].get_node_or_null("Visual") if avatars.has(id) else null


func _dummy(id: int) -> Node3D:
	return _map.get_node("Dummies").get_child(-id - 1) as Node3D


func _update_dummy(id: int, entity: Array) -> void:
	if not _nodes.has(id):
		var label := _new_label()
		add_child(label)
		label.global_position = entity[2] + Vector3.UP * LABEL_HEIGHT
		_nodes[id] = label
	var dummy: TrainingDummy = _dummy(id)
	_nodes[id].text = "%s\n%d / %d" % [dummy.data.display_name, entity[3], entity[4]]


func _update_projectile(id: int, time: float, entity: Array) -> void:
	if not _nodes.has(id):
		if not _abilities.has(entity[3]):
			return
		var node := _new_projectile(_abilities[entity[3]])
		add_child(node)
		node.global_position = entity[2] + Vector3.UP * SHOT_HEIGHT
		_nodes[id] = node
		_buffers[id] = Interpolation.new()
	_buffers[id].push(time, entity[2], 0.0)


func _update_zone(id: int, entity: Array) -> void:
	if _nodes.has(id) or not _abilities.has(entity[3]):
		return
	var node := _new_zone(_abilities[entity[3]])
	add_child(node)
	node.global_position = entity[2]
	_nodes[id] = node


# Espera el retraso de interpolación, para que el proyectil llegue a donde acabó.
func _end_entity(id: int) -> void:
	_ending[id] = true
	_after(REMOTE_DELAY, func() -> void:
		var node := _nodes[id]
		_nodes.erase(id)
		_buffers.erase(id)
		_ending.erase(id)
		if node.has_meta("projectile"):
			_impact(node.global_position, node.get_meta("projectile"), false)
			Fx.fade_out(node, 0.05)
		else:
			Fx.fade_out(node, FADE_TIME))


func _show_cast(caster_id: int, ability: AbilityData) -> void:
	var model := _model(caster_id)
	if model == null:
		return
	var animator: HeroAnimator = model.get_node_or_null("Animator")
	if animator != null:
		animator.play(ability)
	var tip := animator.tip() if animator != null else model
	var color := ability_color(ability)
	match ability.kind:
		AbilityData.Kind.PROJECTILE:
			Fx.flash(self, tip.global_position, color, 3.0, 3.0, 0.15)
			Fx.burst(self, tip.global_position, _motes(color, 10, 2.5, 0.2))
		AbilityData.Kind.BEAM:
			_charge(tip, ability)
		AbilityData.Kind.DASH:
			_dash_trail(model, ability)
		AbilityData.Kind.LEAP:
			_dust(model.global_position, 1.2, 12)


func _show_effect(from: Vector3, to: Vector3, radius: float, caster_id: int, ability: AbilityData) -> void:
	match ability.kind:
		AbilityData.Kind.CONE:
			_slash(from, to, ability)
		AbilityData.Kind.SHIELD:
			_shield_burst(from, ability)
		AbilityData.Kind.BLINK:
			_blink(from, to, caster_id, ability)
		AbilityData.Kind.LEAP:
			_landing(from, radius, ability)
		AbilityData.Kind.BEAM:
			_beam(from, to, caster_id, ability)
		_:
			if radius > 0.0:
				_sweep(from, radius, caster_id, ability)
			else:
				_beam(from, to, caster_id, ability)


func _show_hit(id: int, amount: float, type: AbilityData.DamageType, at: Vector3) -> void:
	_show_number(amount, type, at)
	var color := damage_color(type)
	var point := at + Vector3.UP * SHOT_HEIGHT
	if type == AbilityData.DamageType.PHYSICAL:
		Fx.burst(self, point, Fx.sparks(color, 14, 6.0))
	else:
		Fx.burst(self, point, _motes(color, 16, 3.0, 0.35))
	Fx.flash(self, point, color, 1.5, 2.5, 0.12)
	var model := _model(id) if id > 0 else _dummy(id)
	if model != null:
		Fx.hit_flash(model, 0.15)
	if id < 0:
		_wobble(_dummy(id).get_node("Mesh"))
	if id == own_id:
		shaken.emit(0.25 + minf(amount / 300.0, 0.3))


func _show_number(amount: float, type: AbilityData.DamageType, at: Vector3) -> void:
	var label := _new_label()
	label.text = "%d" % roundi(amount)
	label.modulate = damage_color(type)
	add_child(label)
	label.global_position = at + Vector3.UP * (LABEL_HEIGHT + 0.9) + Vector3(randf_range(-0.4, 0.4), 0, 0)
	label.scale = Vector3.ONE * 1.6
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y + 1.0, NUMBER_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME * 0.5).set_delay(NUMBER_TIME * 0.5)
	tween.chain().tween_callback(label.queue_free)


func _new_projectile(ability: AbilityData) -> Node3D:
	var color := ability_color(ability)
	# Los más rápidos se ven más alargados, como un dardo.
	var stretch := 1.0 + maxf(ability.speed - 15.0, 0.0) / 5.0
	var root := Node3D.new()
	root.set_meta("projectile", ability)
	var core := Fx.sphere(ability.radius * 0.5, Fx.glow(color.lerp(Color.WHITE, 0.3), 1.4))
	core.scale.z = stretch
	root.add_child(core)
	var halo := Fx.sphere(ability.radius, Fx.glow(Color(color, 0.6), 1.0))
	halo.scale.z = stretch * 0.8
	root.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.5
	root.add_child(light)
	root.add_child(Fx.particles(color, 40, 0.3, ability.radius * 1.6))
	var wisps := Fx.particles(color.lerp(Color.WHITE, 0.5), 16, 0.45, 0.08, true, 1.5)
	wisps.spread = 180.0
	wisps.initial_velocity_max = 0.8
	root.add_child(wisps)
	return root


func _new_zone(ability: AbilityData) -> Node3D:
	var color := ability_color(ability)
	var radius := ability.radius
	var root := Node3D.new()
	var floor_mark := Fx.ground(radius, Color(color, 0.8))
	(floor_mark.material_override as ShaderMaterial).set_shader_parameter("swirl", 2.0)
	floor_mark.position.y = Fx.GROUND_LIFT
	root.add_child(floor_mark)
	var rim := Fx.ground(radius, color.lightened(0.5), 0.04, 1.3)
	rim.position.y = Fx.GROUND_LIFT * 2.0
	root.add_child(rim)
	for i in 9:
		root.add_child(_ice_shard(color, radius, TAU * i / 9.0, i))
	var snow := Fx.particles(Color(1, 1, 1, 0.9), 40, 1.6, 0.12, true, 2.0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	snow.emission_ring_axis = Vector3.UP
	snow.emission_ring_radius = radius * 0.95
	snow.emission_ring_inner_radius = 0.0
	snow.emission_ring_height = 0.1
	snow.gravity = Vector3(0, -1.2, 0)
	snow.position.y = 2.4
	root.add_child(snow)
	var mist := Fx.particles(Color(color.lightened(0.6), 0.3), 14, 2.0, 1.6, false)
	Fx.spread_flat(mist, 0.4, radius * 0.8)
	mist.position.y = 0.3
	root.add_child(mist)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = radius * 1.6
	light.position.y = 1.0
	root.add_child(light)
	root.scale = Vector3(0.2, 1, 0.2)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return root


# Cristal que brota del suelo cerca del borde, inclinado hacia fuera.
func _ice_shard(color: Color, radius: float, angle: float, index: int) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	var height := randf_range(0.5, 1.1)
	mesh.size = Vector3(0.3, height, 0.3)
	var shard := MeshInstance3D.new()
	shard.mesh = mesh
	shard.material_override = Fx.ice_material(color)
	var outward := Vector3(cos(angle), 0, sin(angle))
	shard.position = outward * radius * randf_range(0.75, 0.92)
	shard.basis = Basis(outward.cross(Vector3.UP).normalized(), -randf_range(0.2, 0.5)) * Basis(Vector3.UP, randf() * TAU)
	var rest_y := height * 0.35
	shard.position.y = -height
	var tween := shard.create_tween()
	tween.tween_interval(index * 0.025)
	tween.tween_property(shard, "position:y", rest_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return shard


# Arco de luz que sigue el recorrido del arma.
func _slash(from: Vector3, to: Vector3, ability: AbilityData) -> void:
	var reach := from.distance_to(to)
	var material := Fx.slash_material(ability_color(ability))
	material.set_shader_parameter("tail", 0.7)
	var node := MeshInstance3D.new()
	node.mesh = Fx.swing_mesh(deg_to_rad(ability.angle) * 1.2, reach * 0.95, 1.0, 1.4)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = from + Vector3.UP * SLASH_HEIGHT
	if not is_zero_approx(Vector2(to.x - from.x, to.z - from.z).length()):
		node.look_at(Vector3(to.x, node.global_position.y, to.z))
	var tween := node.create_tween()
	# Empieza cuando la maza baja, tras tomar impulso.
	tween.tween_interval(HeroAnimator.WIND_UP)
	tween.tween_property(material, "shader_parameter/progress", 1.7, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(node.queue_free)


# Golpe en área alrededor de un punto: tajo circular, onda y polvo.
func _sweep(center: Vector3, radius: float, caster_id: int, ability: AbilityData) -> void:
	var color := ability_color(ability)
	var material := Fx.slash_material(color)
	material.set_shader_parameter("tail", 0.8)
	var ring := MeshInstance3D.new()
	ring.mesh = Fx.swing_mesh(TAU, radius * 0.8, 0.7)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = center + Vector3.UP * 0.6
	var model := _model(caster_id)
	if model != null:
		ring.global_basis = Basis(Vector3.UP, model.global_rotation.y + PI)
	var tween := ring.create_tween()
	tween.tween_property(material, "shader_parameter/progress", 1.8, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)
	Fx.shockwave(self, center, radius, color.lightened(0.3), 0.35)
	_dust(center, radius * 0.3, 26, radius * 2.0)
	if ability.damage_type == AbilityData.DamageType.PHYSICAL:
		Fx.burst(self, center + Vector3.UP * 0.3, Fx.spread_flat(Fx.sparks(color, 16, radius * 2.5), radius * 2.5, 0.8))
	if caster_id == own_id:
		shaken.emit(0.3)


func _shield_burst(center: Vector3, ability: AbilityData) -> void:
	var color := ability_color(ability)
	var motes := _motes(color, 28, 0.0, 0.7)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 0.9
	motes.emission_ring_inner_radius = 0.7
	motes.emission_ring_height = 0.2
	motes.gravity = Vector3(0, 4, 0)
	Fx.burst(self, center + Vector3.UP * 0.2, motes, 0.6)
	Fx.shockwave(self, center, 1.8, color, 0.3, 0.2)
	Fx.flash(self, center + Vector3.UP, color, 3.0, 4.0, 0.3)


func _blink(from: Vector3, to: Vector3, caster_id: int, ability: AbilityData) -> void:
	var color := ability_color(ability)
	var model := _model(caster_id)
	if model != null:
		Fx.ghost(self, model, from, color, 0.35)
	var body := Vector3.UP * SHOT_HEIGHT
	Fx.burst(self, from + body, Fx.gather(_motes(color, 24, 0.0, 0.25), 1.0, 18.0))
	Fx.flash(self, from + body, color, 3.0, 4.0, 0.2)
	var length := from.distance_to(to)
	if length > 0.1:
		var streak := Fx.cylinder(0.05, length, Fx.glow(color, 3.0))
		add_child(streak)
		_point_along(streak, from + body, to + body)
		streak.create_tween().tween_property(streak, "scale", Vector3(0, 1, 0), 0.25)
		Fx.fade_out(streak, 0.25)
	Fx.burst(self, to + body, _motes(color, 24, 3.5, 0.35))
	Fx.flash(self, to + body, color, 3.0, 4.0, 0.3)
	Fx.shockwave(self, to, 1.5, color, 0.3, 0.2)


# Caída de Impacto: ondas, cráter, rocas, polvo y temblor.
func _landing(center: Vector3, radius: float, ability: AbilityData) -> void:
	var color := ability_color(ability)
	Fx.shockwave(self, center, radius * 1.1, color.lightened(0.3), 0.3, 0.15)
	_after(0.08, Fx.shockwave.bind(self, center, radius * 1.5, Fx.DUST_COLOR, 0.6, 0.25))
	var crater := Fx.ground(radius * 0.6, Color(0.1, 0.08, 0.06, 0.75))
	add_child(crater)
	crater.global_position = center + Vector3.UP * Fx.GROUND_LIFT
	crater.scale = Vector3.ONE * 0.5
	var tween := crater.create_tween()
	tween.tween_property(crater, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.5)
	tween.tween_callback(Fx.fade_out.bind(crater, 1.0))
	Fx.burst(self, center + Vector3.UP * 0.2, Fx.debris(18, 7.0))
	Fx.burst(self, center + Vector3.UP * 0.2, Fx.sparks(color, 18, 8.0, 0.5))
	_dust(center, radius * 0.3, 32, radius * 2.0, 1.8)
	Fx.flash(self, center + Vector3.UP, color, 6.0, radius * 2.5, 0.35)
	if avatars.has(own_id):
		var distance := avatars[own_id].global_position.distance_to(center)
		var strength := clampf(1.0 - distance / (radius * 3.0), 0.0, 1.0)
		if strength > 0.0:
			shaken.emit(0.3 + 0.5 * strength)


# Rayo de Descarga: núcleo brillante, halo que tiembla, luz e impacto al final.
func _beam(from: Vector3, to: Vector3, caster_id: int, ability: AbilityData) -> void:
	var color := ability_color(ability)
	var start := from + Vector3.UP * SHOT_HEIGHT
	var model := _model(caster_id)
	var animator: HeroAnimator = model.get_node_or_null("Animator") if model != null else null
	if animator != null:
		start = animator.tip().global_position
	var end := to + Vector3.UP * SHOT_HEIGHT
	var length := start.distance_to(end)
	if length < 0.1:
		return
	var width := maxf(ability.radius, 0.3)
	var root := Node3D.new()
	add_child(root)
	_point_along(root, start, end)
	var core := Fx.cylinder(width * 0.12, length, Fx.glow(color.lerp(Color.WHITE, 0.6), 3.0))
	root.add_child(core)
	var halo := Fx.cylinder(width * 0.45, length, Fx.glow(Color(color, 0.45), 1.1))
	root.add_child(halo)
	var crackle := _motes(color.lerp(Color.WHITE, 0.4), 50, 1.5, 0.4)
	crackle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	crackle.emission_box_extents = Vector3(width * 0.3, length * 0.5, width * 0.3)
	crackle.spread = 180.0
	Fx.burst(root, root.global_position, crackle, 0.8)
	Fx.flash(self, start, color, 5.0, 5.0, 0.4)
	_impact(end, ability, true)
	var tween := root.create_tween()
	tween.tween_method(func(t: float) -> void:
		var thickness := (1.0 - t) * randf_range(0.75, 1.25)
		core.scale = Vector3(thickness, 1, thickness)
		halo.scale = Vector3(thickness, 1, thickness), 0.0, 1.0, 0.45)
	tween.tween_callback(root.queue_free)
	if caster_id == own_id:
		shaken.emit(0.35)


# Carga de Descarga: chispas que se juntan en la punta y una esfera que crece.
func _charge(tip: Node3D, ability: AbilityData) -> void:
	var color := ability_color(ability)
	var time := maxf(ability.cast_delay, 0.1)
	var root := Node3D.new()
	tip.add_child(root)
	var orb := Fx.sphere(0.25, Fx.glow(color.lerp(Color.WHITE, 0.4), 1.6))
	orb.scale = Vector3.ONE * 0.05
	root.add_child(orb)
	var pull := Fx.gather(_motes(color, 32, 0.0, 0.35), 0.9, 15.0)
	pull.local_coords = true
	root.add_child(pull)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 4.0
	root.add_child(light)
	var tween := root.create_tween().set_parallel()
	tween.tween_property(orb, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 4.0, time)
	tween.chain().tween_callback(Fx.fade_out.bind(root, 0.1))


# Polvo bajo los pies y una estela del color de la habilidad durante la carrera.
func _dash_trail(model: Node3D, ability: AbilityData) -> void:
	var root := Node3D.new()
	model.add_child(root)
	var dust := Fx.particles(Fx.DUST_COLOR, 30, 0.6, 0.9, false)
	dust.direction = Vector3.UP
	dust.initial_velocity_max = 1.0
	dust.position.y = 0.2
	root.add_child(dust)
	var glow := Fx.particles(Color(ability_color(ability), 0.35), 24, 0.3, 0.5, false)
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	glow.emission_box_extents = Vector3(0.3, 0.6, 0.2)
	glow.position.y = 1.0
	root.add_child(glow)
	_after(ability.reach / ability.speed, Fx.fade_out.bind(root, 0.1))


func _impact(at: Vector3, ability: AbilityData, strong: bool) -> void:
	var color := ability_color(ability)
	var amount := 30 if strong else 14
	Fx.burst(self, at, _motes(color, amount, 4.0 if strong else 2.5, 0.35))
	if strong or ability.damage_type == AbilityData.DamageType.PHYSICAL:
		Fx.burst(self, at, Fx.sparks(color, amount / 2, 6.0))
	Fx.flash(self, at, color, 4.0 if strong else 2.5, 4.0, 0.2)


func _dust(at: Vector3, start_radius: float, amount: int, speed := 2.5, size := 1.2) -> void:
	var dust := Fx.spread_flat(Fx.particles(Fx.DUST_COLOR, amount, 0.9, size, false), speed, start_radius)
	dust.gravity = Vector3(0, 0.6, 0)
	Fx.burst(self, at + Vector3.UP * 0.2, dust)


func _motes(color: Color, amount: int, speed: float, lifetime: float) -> CPUParticles3D:
	var motes := Fx.particles(color, amount, lifetime, 0.18, true, 1.3)
	motes.spread = 180.0
	motes.initial_velocity_min = speed * 0.4
	motes.initial_velocity_max = speed
	return motes


# Tambaleo del muñeco al recibir un golpe.
func _wobble(mesh: Node3D) -> void:
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "rotation:x", 0.18, 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# Orienta un nodo con su eje Y de `from` a `to`, centrado entre ambos.
func _point_along(node: Node3D, from: Vector3, to: Vector3) -> void:
	node.global_position = from.lerp(to, 0.5)
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	node.global_basis = Basis(side, axis, side.cross(axis))


func _new_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 32
	label.outline_size = 8
	return label
