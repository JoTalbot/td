extends RefCounted
## Фабрика "ржавого железа": материалы и мелкие детали в стиле Безумного Макса.

## Глобальный выключатель света вспышек взрывов (бюджет слабых устройств).
static var perf_explosion_lights := true

const RUST_TONES: Array[Color] = [
	Color(0.42, 0.22, 0.1),   # ржавчина
	Color(0.35, 0.3, 0.26),   # грязный металл
	Color(0.5, 0.35, 0.15),   # выгоревшая охра
	Color(0.28, 0.26, 0.24),  # копоть
	Color(0.45, 0.4, 0.3),    # пыльная сталь
]


static func metal(color: Color, rough := 0.85, met := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = met
	return m


static func rust(rng: RandomNumberGenerator) -> StandardMaterial3D:
	var c: Color = RUST_TONES[rng.randi() % RUST_TONES.size()]
	c = c.lightened(rng.randf_range(-0.06, 0.06))
	return metal(c, rng.randf_range(0.75, 0.95), rng.randf_range(0.4, 0.7))


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func spike(parent: Node3D, radius: float, height: float, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = metal(Color(0.55, 0.5, 0.45), 0.5, 0.8)
	parent.add_child(mi)
	return mi


## Колесо с "протектором" из накладок.
static func wheel(parent: Node3D, radius: float, width: float, pos: Vector3) -> MeshInstance3D:
	var w := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	w.mesh = mesh
	w.rotation_degrees = Vector3(0, 0, 90)
	w.position = pos
	w.material_override = metal(Color(0.08, 0.08, 0.08), 0.95, 0.1)
	parent.add_child(w)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.45
	hub_mesh.bottom_radius = radius * 0.45
	hub_mesh.height = width + 0.04
	hub.mesh = hub_mesh
	hub.material_override = metal(Color(0.4, 0.35, 0.28), 0.6, 0.7)
	w.add_child(hub)
	return w


## Пыльный шлейф из-под колёс.
static func dust_trail(parent: Node3D, pos: Vector3, amount := 60, scale := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.preprocess = 0.8
	p.visibility_aabb = AABB(Vector3(-8, -1, -20) * scale, Vector3(16, 8, 30) * scale)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.35, -1)
	mat.spread = 22.0
	mat.initial_velocity_min = 4.0 * scale
	mat.initial_velocity_max = 8.0 * scale
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.5 * scale
	mat.scale_max = 1.6 * scale
	mat.color = Color(0.62, 0.5, 0.34, 0.35)
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.62, 0.5, 0.34, 0.3)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = dm
	p.draw_pass_1 = mesh
	p.position = pos
	parent.add_child(p)
	return p


## Взрыв: огонь + дым. Бюджет эффектов: на жирных волнах вспышки экономим.
static func explosion(scene: Node, pos: Vector3, scale := 1.0) -> void:
	var live: int = scene.get_tree().get_nodes_in_group("fx_explosion").size()
	if live >= 8:
		return   # волна и так в огне — лишний взрыв не строим вовсе
	var p := GPUParticles3D.new()
	p.add_to_group("fx_explosion")
	p.amount = 26
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 4.0 * scale
	mat.initial_velocity_max = 9.0 * scale
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.15 * scale
	mat.scale_max = 0.5 * scale
	mat.color = Color(1.0, 0.55, 0.12)
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1.0, 0.5, 0.1)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.45, 0.05)
	dm.emission_energy_multiplier = 2.5
	mesh.material = dm
	p.draw_pass_1 = mesh
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	if live >= 4 or not perf_explosion_lights:
		# Свет — самое дорогое на мобильном рендерере: дальше 4 вспышек только искры
		var tw0 := p.create_tween()
		tw0.tween_interval(0.9)
		tw0.tween_callback(p.queue_free)
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 3.0 * scale
	light.omni_range = 6.0 * scale
	p.add_child(light)
	var tw := p.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	tw.tween_interval(0.4)
	tw.tween_callback(p.queue_free)
