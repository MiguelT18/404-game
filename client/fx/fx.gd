class_name Fx
extends RefCounted
## Piezas de efectos hechas en código, sin texturas ni escenas: partículas, luces,
## marcas en el suelo y fundidos. Cada llamada crea sus propios materiales, así un
## efecto puede desvanecerse sin tocar a los demás.

const GROUND_SHADER := preload("res://client/fx/ground.gdshader")
const SLASH_SHADER := preload("res://client/fx/slash.gdshader")
const SHIELD_SHADER := preload("res://client/fx/shield.gdshader")
const DUST_COLOR := Color(0.55, 0.5, 0.42, 0.45)
const ROCK_COLOR := Color(0.42, 0.38, 0.33)
# Separa las marcas del suelo para que no parpadeen al superponerse.
const GROUND_LIFT := 0.03

static var _soft_dot: GradientTexture2D


## Punto redondo y difuso para las partículas.
static func soft_dot() -> Texture2D:
	if _soft_dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = gradient
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(1.0, 0.5)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot


## Por encima de 1, el resplandor del entorno lo hace brillar.
static func hdr(color: Color, energy: float) -> Color:
	return Color(color.r * energy, color.g * energy, color.b * energy, color.a)


## Material sin sombreado. `additive` suma luz a lo de detrás; si no, lo tapa.
static func glow(color: Color, energy := 2.0, additive := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = hdr(color, energy)
	return material


static func sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh_node(mesh, material)


static func cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _mesh_node(mesh, material)


## Partículas difusas en coordenadas del mundo, que se apagan y encogen al morir.
## Emiten sin parar hasta pasarlas a `burst` o a `fade_out`.
static func particles(color: Color, amount: int, lifetime: float, size: float, additive := true, energy := 1.1) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	var material := glow(Color.WHITE, energy if additive else 1.0, additive)
	material.albedo_texture = soft_dot()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var node := _particles_node(mesh, color, amount, lifetime)
	node.gravity = Vector3.ZERO
	return node


## Chispas alargadas que siguen su dirección y caen.
static func sparks(color: Color, amount: int, speed: float, lifetime := 0.4) -> CPUParticles3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.22, 0.03)
	var material := glow(Color.WHITE, 2.0)
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var node := _particles_node(mesh, color.lerp(Color.WHITE, 0.35), amount, lifetime)
	node.particle_flag_align_y = true
	node.direction = Vector3.UP
	node.spread = 75.0
	node.initial_velocity_min = speed * 0.5
	node.initial_velocity_max = speed
	node.gravity = Vector3(0, -14, 0)
	return node


## Trozos de roca con luz y sombra que saltan y caen.
static func debris(amount: int, speed: float) -> CPUParticles3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = ROCK_COLOR
	material.roughness = 1.0
	mesh.material = material
	var node := _particles_node(mesh, Color.WHITE, amount, 1.1)
	node.color_ramp = null
	node.direction = Vector3.UP
	node.spread = 50.0
	node.initial_velocity_min = speed * 0.5
	node.initial_velocity_max = speed
	node.gravity = Vector3(0, -22, 0)
	node.particle_flag_rotate_y = true
	node.angular_velocity_min = -400.0
	node.angular_velocity_max = 400.0
	node.scale_amount_min = 0.4
	node.scale_amount_max = 1.3
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 0.8
	return node


## Las partículas salen en horizontal hacia fuera, como una nube que se abre.
static func spread_flat(node: CPUParticles3D, speed: float, start_radius: float) -> CPUParticles3D:
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	node.emission_ring_axis = Vector3.UP
	node.emission_ring_radius = start_radius
	node.emission_ring_inner_radius = start_radius * 0.5
	node.emission_ring_height = 0.1
	node.direction = Vector3.RIGHT
	node.spread = 180.0
	node.flatness = 1.0
	node.initial_velocity_min = speed * 0.6
	node.initial_velocity_max = speed
	node.damping_min = speed * 1.2
	node.damping_max = speed * 1.6
	return node


## Partículas que nacen en una esfera y caen hacia su centro.
static func gather(node: CPUParticles3D, radius: float, pull: float) -> CPUParticles3D:
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	node.emission_sphere_radius = radius
	node.radial_accel_min = -pull
	node.radial_accel_max = -pull * 0.8
	return node


## Una sola ráfaga en `at`, que se borra al terminar.
static func burst(parent: Node, at: Vector3, node: CPUParticles3D, explosiveness := 1.0) -> CPUParticles3D:
	node.one_shot = true
	node.explosiveness = explosiveness
	parent.add_child(node)
	node.global_position = at
	node.restart()
	node.finished.connect(node.queue_free)
	return node


## Luz breve que se apaga sola.
static func flash(parent: Node, at: Vector3, color: Color, energy: float, light_range: float, time: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(light.queue_free)


## Marca de `radius` metros en el suelo. Con `ring_width` es un anillo.
static func ground(radius: float, color: Color, ring_width := 0.0, energy := 1.0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("alpha", 1.0)
	material.set_shader_parameter("ring_radius", 1.0 if ring_width == 0.0 else 0.95)
	material.set_shader_parameter("ring_width", ring_width)
	return _mesh_node(mesh, material)


## Anillo que se abre desde el centro hasta `radius` y se desvanece.
static func shockwave(parent: Node, at: Vector3, radius: float, color: Color, time: float, ring_width := 0.12) -> void:
	var ring := ground(radius, color, ring_width, 1.4)
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * GROUND_LIFT * 2.0
	var material: ShaderMaterial = ring.material_override
	material.set_shader_parameter("ring_radius", 0.1)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(material, "shader_parameter/ring_radius", 0.95, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "shader_parameter/alpha", 0.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(ring.queue_free)


## Cinta curva de `angle` radianes a `radius` del centro, hacia -Z, para el shader
## de tajo. Baja `drop` metros de derecha a izquierda, como un golpe en diagonal.
## UV.x recorre el arco de derecha a izquierda y UV.y va de abajo arriba.
static func swing_mesh(angle: float, radius: float, thickness: float, drop := 0.0) -> ArrayMesh:
	const STEPS := 24
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STEPS + 1:
		var t := float(i) / STEPS
		var theta := angle * (0.5 - t)
		var direction := Vector3(sin(theta), 0.0, -cos(theta))
		var center := direction * radius + Vector3.UP * drop * (0.5 - t)
		tool.set_uv(Vector2(t, 0.0))
		tool.add_vertex(center + Vector3.DOWN * thickness * 0.5)
		# El filo se abre un poco hacia fuera.
		tool.set_uv(Vector2(t, 1.0))
		tool.add_vertex(center + Vector3.UP * thickness * 0.5 + direction * thickness * 0.3)
	for i in STEPS:
		var base := i * 2
		for index: int in [base, base + 1, base + 2, base + 1, base + 3, base + 2]:
			tool.add_index(index)
	return tool.commit()


static func slash_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SLASH_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("energy", 1.4)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("tail", 0.55)
	return material


static func shield_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHIELD_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("alpha", 1.0)
	return material


## Cristal translúcido con luz propia, para el hielo.
static func ice_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.lightened(0.5), 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	material.metallic = 0.2
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6
	return material


## Mallas del modelo, sin contar los efectos que lleva encima.
static func model_meshes(model: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in _descendants(model):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.material_override == null:
			meshes.append(mesh)
	return meshes


## Destello blanco sobre un modelo al recibir un golpe.
static func hit_flash(model: Node3D, time: float) -> void:
	var material := glow(Color(1, 1, 1, 0.8), 1.0)
	var meshes := model_meshes(model)
	for mesh in meshes:
		mesh.material_overlay = material
	var tween := model.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_callback(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.material_overlay == material:
				mesh.material_overlay = null)


## Copia translúcida de un modelo en `at`, que se desvanece.
static func ghost(parent: Node, model: Node3D, at: Vector3, color: Color, time: float) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_transform = Transform3D(model.global_basis, at)
	var material := glow(Color(color, 0.4), 1.0, false)
	for mesh in model_meshes(model):
		var copy := _mesh_node(mesh.mesh, material)
		root.add_child(copy)
		copy.transform = model.global_transform.affine_inverse() * mesh.global_transform
	var tween := root.create_tween().set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_property(root, "scale", Vector3(1.15, 1.05, 1.15), time)
	tween.chain().tween_callback(root.queue_free)


## Apaga un efecto que dura y lo borra cuando ya no queda nada visible.
static func fade_out(node: Node3D, time: float) -> void:
	var tween := node.create_tween().set_parallel()
	var wait := time
	for child in _descendants(node):
		if child is CPUParticles3D:
			var particles := child as CPUParticles3D
			particles.emitting = false
			wait = maxf(wait, particles.lifetime)
		elif child is OmniLight3D:
			tween.tween_property(child, "light_energy", 0.0, time)
		elif child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override
			if material is ShaderMaterial and material.shader != SLASH_SHADER:
				tween.tween_property(material, "shader_parameter/alpha", 0.0, time)
			elif material is StandardMaterial3D:
				tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_interval(wait)
	tween.chain().tween_callback(node.queue_free)


static func _particles_node(mesh: Mesh, color: Color, amount: int, lifetime: float) -> CPUParticles3D:
	var node := CPUParticles3D.new()
	node.mesh = mesh
	node.amount = amount
	node.lifetime = lifetime
	node.local_coords = false
	node.randomness = 0.3
	node.lifetime_randomness = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	node.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))
	node.scale_amount_curve = shrink
	return node


static func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _descendants(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child in node.get_children():
		nodes.append_array(_descendants(child))
	return nodes
