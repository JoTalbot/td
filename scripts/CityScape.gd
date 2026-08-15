extends Node3D
## Киберпанк-мегаполис вокруг поля: небоскрёбы с горящими окнами,
## голографические вывески, неоновый дождь и летающий транспорт.

const WINDOW_SHADER := preload("res://shaders/building_windows.gdshader")
const HOLO_SHADER := preload("res://shaders/holo.gdshader")

const NEON_PALETTE: Array[Color] = [
	Color(1.0, 0.12, 0.75),  # магента
	Color(0.15, 0.95, 1.0),  # циан
	Color(0.65, 0.3, 1.0),   # фиолет
	Color(1.0, 0.55, 0.1),   # оранж
	Color(0.2, 1.0, 0.55),   # кислотно-зелёный
]

var _cars: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xC7B3
	_build_skyline()
	_build_holo_signs()
	_build_rain()
	_build_traffic()


func _build_skyline() -> void:
	# Два кольца зданий вокруг поля (поле ~ 18x24, портрет).
	var rings := [
		{"radius": 16.0, "count": 14, "h_min": 6.0, "h_max": 16.0},
		{"radius": 24.0, "count": 18, "h_min": 14.0, "h_max": 34.0},
	]
	for ring in rings:
		for i in ring["count"]:
			var angle := TAU * float(i) / float(ring["count"]) + _rng.randf_range(-0.12, 0.12)
			var radius: float = ring["radius"] + _rng.randf_range(-2.0, 2.5)
			var h: float = _rng.randf_range(ring["h_min"], ring["h_max"])
			var w := _rng.randf_range(2.2, 4.5)
			var d := _rng.randf_range(2.2, 4.5)

			var b := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(w, h, d)
			b.mesh = mesh
			b.position = Vector3(cos(angle) * radius, h * 0.5 - 0.5, sin(angle) * radius)
			b.rotation.y = _rng.randf_range(0.0, TAU)

			var mat := ShaderMaterial.new()
			mat.shader = WINDOW_SHADER
			mat.set_shader_parameter("window_color", NEON_PALETTE[_rng.randi() % NEON_PALETTE.size()])
			mat.set_shader_parameter("win_density", Vector2(_rng.randf_range(5.0, 9.0), h * _rng.randf_range(0.9, 1.4)))
			mat.set_shader_parameter("lit_ratio", _rng.randf_range(0.25, 0.5))
			mat.set_shader_parameter("seed", _rng.randf() * 100.0)
			b.material_override = mat
			add_child(b)

			# Неоновая кромка крыши у части зданий
			if _rng.randf() < 0.6:
				var edge := MeshInstance3D.new()
				var edge_mesh := BoxMesh.new()
				edge_mesh.size = Vector3(w + 0.15, 0.15, d + 0.15)
				edge.mesh = edge_mesh
				edge.position = Vector3(0, h * 0.5, 0)
				var em := StandardMaterial3D.new()
				var c: Color = NEON_PALETTE[_rng.randi() % NEON_PALETTE.size()]
				em.albedo_color = c * 0.3
				em.emission_enabled = true
				em.emission = c
				em.emission_energy_multiplier = 3.0
				edge.material_override = em
				b.add_child(edge)

			# Красный маячок на самых высоких
			if h > 24.0:
				var beacon := OmniLight3D.new()
				beacon.light_color = Color(1.0, 0.15, 0.2)
				beacon.light_energy = 1.5
				beacon.omni_range = 5.0
				beacon.position = Vector3(0, h * 0.5 + 0.4, 0)
				b.add_child(beacon)


func _build_holo_signs() -> void:
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.3
		var sign_mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(_rng.randf_range(3.0, 6.0), _rng.randf_range(2.0, 4.0))
		sign_mesh.mesh = quad
		var r := _rng.randf_range(15.0, 21.0)
		sign_mesh.position = Vector3(cos(angle) * r, _rng.randf_range(6.0, 18.0), sin(angle) * r)
		# Повёрнуты к центру поля
		sign_mesh.look_at_from_position(sign_mesh.position, Vector3(0, sign_mesh.position.y, 0), Vector3.UP)
		var mat := ShaderMaterial.new()
		mat.shader = HOLO_SHADER
		mat.set_shader_parameter("color", NEON_PALETTE[_rng.randi() % NEON_PALETTE.size()])
		mat.set_shader_parameter("speed", _rng.randf_range(0.6, 1.6))
		sign_mesh.material_override = mat
		add_child(sign_mesh)


func _build_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.amount = 900
	rain.lifetime = 1.1
	rain.preprocess = 1.2
	rain.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 40, 60))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(26.0, 0.5, 30.0)
	mat.direction = Vector3(0.12, -1.0, 0.05)
	mat.spread = 0.0
	mat.initial_velocity_min = 26.0
	mat.initial_velocity_max = 34.0
	mat.gravity = Vector3.ZERO
	rain.process_material = mat
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.5, 0.015)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.55, 0.75, 1.0, 0.28)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.vertex_color_use_as_albedo = false
	drop.material = dm
	rain.draw_pass_1 = drop
	rain.position.y = 26.0
	add_child(rain)


func _build_traffic() -> void:
	# Летающие машины: светящиеся полосы, курсируют по кругу на разных высотах.
	for i in 7:
		var car := MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.12
		body.height = 0.9
		car.mesh = body
		car.rotation.z = PI / 2.0
		var c: Color = [Color(1.0, 0.2, 0.25), Color(0.95, 0.85, 0.4), Color(0.3, 0.8, 1.0)][_rng.randi() % 3]
		var m := StandardMaterial3D.new()
		m.albedo_color = c * 0.3
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		car.material_override = m
		var pivot := Node3D.new()
		pivot.rotation.y = _rng.randf_range(0.0, TAU)
		pivot.add_child(car)
		car.position = Vector3(_rng.randf_range(17.0, 26.0), _rng.randf_range(8.0, 22.0), 0)
		add_child(pivot)
		_cars.append({"pivot": pivot, "speed": _rng.randf_range(0.15, 0.45) * (1.0 if _rng.randf() < 0.5 else -1.0)})


func _process(delta: float) -> void:
	for entry in _cars:
		entry["pivot"].rotation.y += entry["speed"] * delta
