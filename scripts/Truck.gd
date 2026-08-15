extends Node3D
## Боевой грузовик ("Военная фура"): кабина, цистерна, платформа 2x4 слотов
## под орудия. Апгрейды Crossout-стиля навешивают видимые детали.

const Junk := preload("res://scripts/Junk.gd")

## Слоты под орудия: 2 колонны x 4 ряда на крыше трейлера/кабины.
const SLOT_COLS := 2
const SLOT_ROWS := 4

var slot_nodes: Array = []      # Node3D маркеров слотов
var weapons: Dictionary = {}    # slot_index -> Weapon
var upgrade_levels := {"armor": 0, "spikes": 0, "engine": 0, "drone": 0}

var _wheels: Array = []
var _rng := RandomNumberGenerator.new()
var _armor_parts: Array = []
var _spike_parts: Array = []
var _engine_parts: Array = []
var _drone: Node3D = null
var _drone_phase := 0.0
var _shake_phase := 0.0
var _exhaust_stacks: Array = []


func _ready() -> void:
	_rng.seed = 0xBADF00D
	_build_cab()
	_build_trailer()
	_build_slots()


func _build_cab() -> void:
	var cab := Node3D.new()
	cab.name = "Cab"
	cab.position = Vector3(0, 0, 5.6)
	add_child(cab)

	var body_mat := Junk.metal(Color(0.3, 0.25, 0.2), 0.8, 0.6)
	# Капот и кабина
	Junk.box(cab, Vector3(2.4, 1.0, 2.2), Vector3(0, 0.9, 1.2), body_mat)
	Junk.box(cab, Vector3(2.4, 1.9, 1.6), Vector3(0, 1.35, -0.6), Junk.metal(Color(0.26, 0.22, 0.18), 0.85, 0.5))
	# Лобовая решётка-гриль с зубьями
	Junk.box(cab, Vector3(2.2, 0.9, 0.15), Vector3(0, 0.85, 2.32), Junk.metal(Color(0.5, 0.45, 0.4), 0.5, 0.85))
	for i in 6:
		Junk.spike(cab, 0.09, 0.4, Vector3(-1.0 + i * 0.4, 0.85, 2.5), Vector3(90, 0, 0))
	# Отбойник-таран
	Junk.box(cab, Vector3(2.8, 0.5, 0.3), Vector3(0, 0.4, 2.45), Junk.metal(Color(0.35, 0.32, 0.3), 0.7, 0.7))
	# Лобовое стекло с решёткой
	var glass := Junk.box(cab, Vector3(2.0, 0.8, 0.1), Vector3(0, 1.7, 0.25), Junk.metal(Color(0.1, 0.12, 0.12), 0.3, 0.9), Vector3(-15, 0, 0))
	for i in 4:
		Junk.box(glass, Vector3(0.06, 0.8, 0.12), Vector3(-0.75 + i * 0.5, 0, 0.01), Junk.metal(Color(0.3, 0.28, 0.25), 0.8, 0.6))
	# Выхлопные трубы по бокам кабины
	for side in [-1.0, 1.0]:
		var pipe := Junk.cyl(cab, 0.12, 2.4, Vector3(side * 1.3, 1.9, -1.2), Junk.metal(Color(0.2, 0.2, 0.2), 0.6, 0.8))
		var tip := Junk.cyl(pipe, 0.15, 0.25, Vector3(0, 1.3, 0), Junk.metal(Color(0.1, 0.1, 0.1), 0.9, 0.4))
		_exhaust_stacks.append(tip)
		var smoke := GPUParticles3D.new()
		smoke.amount = 22
		smoke.lifetime = 1.0
		smoke.preprocess = 0.5
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, -0.6)
		pm.spread = 12.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 3.5
		pm.gravity = Vector3(0, 0.8, -2.0)
		pm.scale_min = 0.15
		pm.scale_max = 0.5
		pm.color = Color(0.15, 0.14, 0.13, 0.5)
		smoke.process_material = pm
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		var smm := StandardMaterial3D.new()
		smm.albedo_color = Color(0.18, 0.17, 0.16, 0.45)
		smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = smm
		smoke.draw_pass_1 = sm
		smoke.position = Vector3(0, 1.45, 0)
		pipe.add_child(smoke)
	# Фары
	for side in [-1.0, 1.0]:
		var lamp := Junk.box(cab, Vector3(0.3, 0.2, 0.1), Vector3(side * 0.85, 1.1, 2.33), Junk.metal(Color(1.0, 0.95, 0.7), 0.2, 0.1))
		var lm := lamp.material_override as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.9, 0.6)
		lm.emission_energy_multiplier = 1.6
	# Колёса кабины
	for side in [-1.0, 1.0]:
		_wheels.append(Junk.wheel(cab, 0.55, 0.4, Vector3(side * 1.25, 0.55, 1.5)))
		_wheels.append(Junk.wheel(cab, 0.55, 0.4, Vector3(side * 1.25, 0.55, -0.7)))


func _build_trailer() -> void:
	var trailer := Node3D.new()
	trailer.name = "Trailer"
	add_child(trailer)

	# Рама и платформа
	Junk.box(trailer, Vector3(2.6, 0.35, 8.4), Vector3(0, 0.75, 0), Junk.metal(Color(0.24, 0.21, 0.18), 0.85, 0.55))
	Junk.box(trailer, Vector3(2.9, 0.18, 8.6), Vector3(0, 1.0, 0), Junk.metal(Color(0.33, 0.28, 0.22), 0.8, 0.5))
	# Цистерна под платформой (как War Rig)
	Junk.cyl(trailer, 0.8, 7.6, Vector3(0, 0.45, 0), Junk.metal(Color(0.38, 0.3, 0.2), 0.75, 0.65), Vector3(90, 0, 0))
	# Борта с заклёпками
	for side in [-1.0, 1.0]:
		var wall := Junk.box(trailer, Vector3(0.12, 0.5, 8.6), Vector3(side * 1.45, 1.3, 0), Junk.rust(_rng))
		for i in 7:
			Junk.box(wall, Vector3(0.16, 0.12, 0.12), Vector3(0, 0.1, -3.6 + i * 1.2), Junk.metal(Color(0.5, 0.45, 0.4), 0.6, 0.8))
	# Задний борт
	Junk.box(trailer, Vector3(2.9, 0.55, 0.14), Vector3(0, 1.3, -4.3), Junk.rust(_rng))
	# Колёса трейлера
	for side in [-1.0, 1.0]:
		for zi in 3:
			_wheels.append(Junk.wheel(trailer, 0.55, 0.4, Vector3(side * 1.3, 0.55, -3.4 + zi * 1.3)))
	# Канистры и хлам на бортах
	for i in 4:
		var can := Junk.box(trailer, Vector3(0.35, 0.5, 0.25),
			Vector3(1.62 * (1 if i % 2 == 0 else -1), 1.15, -2.8 + i * 1.7),
			Junk.metal(Color(0.5, 0.15, 0.1) if i % 2 == 0 else Color(0.4, 0.38, 0.15), 0.8, 0.4))
		can.rotation_degrees.z = _rng.randf_range(-6, 6)
	# Пыль из-под колёс
	Junk.dust_trail(self, Vector3(-1.2, 0.2, -4.5))
	Junk.dust_trail(self, Vector3(1.2, 0.2, -4.5))
	Junk.dust_trail(self, Vector3(0, 0.1, -5.0), 40, 1.4)


func _build_slots() -> void:
	# 8 слотов: 6 на трейлере + 2 над кабиной.
	var positions: Array[Vector3] = []
	for row in 3:
		for col in SLOT_COLS:
			positions.append(Vector3(-0.72 + col * 1.44, 1.15, -3.2 + row * 2.4))
	positions.append(Vector3(-0.72, 2.4, 5.0))
	positions.append(Vector3(0.72, 2.4, 5.0))

	for pos in positions:
		var slot := Node3D.new()
		slot.position = pos
		add_child(slot)
		# Маркер-площадка
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = 0.5
		pad_mesh.bottom_radius = 0.5
		pad_mesh.height = 0.06
		pad.mesh = pad_mesh
		pad.name = "Pad"
		var pm := Junk.metal(Color(0.2, 0.18, 0.15), 0.9, 0.4)
		pad.material_override = pm
		slot.add_child(pad)
		slot_nodes.append(slot)


func slot_world_position(idx: int) -> Vector3:
	return (slot_nodes[idx] as Node3D).global_position


func nearest_free_slot(world_pos: Vector3, max_dist := 1.2) -> int:
	var best := -1
	var best_d := max_dist
	for i in slot_nodes.size():
		if weapons.has(i):
			continue
		var d: float = slot_world_position(i).distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func nearest_weapon_slot(world_pos: Vector3, max_dist := 1.4) -> int:
	var best := -1
	var best_d := max_dist
	for i in weapons:
		var d: float = slot_world_position(i).distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func set_slots_highlight(on: bool) -> void:
	for i in slot_nodes.size():
		var pad := (slot_nodes[i] as Node3D).get_node("Pad") as MeshInstance3D
		var m := pad.material_override as StandardMaterial3D
		if on and not weapons.has(i):
			m.emission_enabled = true
			m.emission = Color(1.0, 0.75, 0.25)
			m.emission_energy_multiplier = 0.9
		else:
			m.emission_enabled = false


func mount_weapon(idx: int, weapon: Node3D) -> void:
	weapons[idx] = weapon
	(slot_nodes[idx] as Node3D).add_child(weapon)


func unmount_weapon(idx: int) -> void:
	if weapons.has(idx):
		weapons[idx].queue_free()
		weapons.erase(idx)


## --- Апгрейды Crossout: каждая покупка добавляет видимый обвес ---

func apply_upgrade(id: String) -> void:
	upgrade_levels[id] += 1
	var lvl: int = upgrade_levels[id]
	match id:
		"armor":
			_add_armor_visual(lvl)
		"spikes":
			_add_spikes_visual(lvl)
		"engine":
			_add_engine_visual(lvl)
		"drone":
			_add_drone_visual(lvl)


func _add_armor_visual(lvl: int) -> void:
	# Ржавые бронелисты на бортах, с каждым уровнем — больше и выше.
	for side in [-1.0, 1.0]:
		for i in 2:
			var plate := Junk.box(self,
				Vector3(0.1, 0.55 + lvl * 0.1, 1.6),
				Vector3(side * (1.52 + lvl * 0.04), 1.35 + lvl * 0.12, -3.0 + i * 3.2 + lvl * 0.5),
				Junk.rust(_rng),
				Vector3(0, 0, side * _rng.randf_range(2.0, 6.0)))
			_armor_parts.append(plate)
	if lvl >= 2:
		# Бронещит на кабину
		var shield := Junk.box(self, Vector3(2.5, 0.7, 0.12), Vector3(0, 2.3, 6.4), Junk.rust(_rng), Vector3(-20, 0, 0))
		_armor_parts.append(shield)


func _add_spikes_visual(lvl: int) -> void:
	# Шипы по бортам и на колёсах.
	for side in [-1.0, 1.0]:
		for i in 3 + lvl:
			var sp := Junk.spike(self, 0.12, 0.55 + lvl * 0.1,
				Vector3(side * 1.62, 1.15, -3.8 + i * (7.0 / (2 + lvl))),
				Vector3(0, 0, side * -90.0))
			_spike_parts.append(sp)
	if lvl >= 2:
		for w in _wheels:
			if _rng.randf() < 0.5:
				continue
			var sp := Junk.spike(w, 0.1, 0.5, Vector3(0, 0.3, 0), Vector3.ZERO)
			_spike_parts.append(sp)


func _add_engine_visual(lvl: int) -> void:
	# Наддув на капоте: блок цилиндров + воздухозаборник, растёт с уровнем.
	var cab := get_node("Cab") as Node3D
	var blower := Junk.box(cab, Vector3(0.6 + lvl * 0.12, 0.3 + lvl * 0.08, 0.8),
		Vector3(0, 1.55 + lvl * 0.1, 1.3), Junk.metal(Color(0.55, 0.5, 0.45), 0.4, 0.9))
	_engine_parts.append(blower)
	var intake := Junk.cyl(blower, 0.16 + lvl * 0.03, 0.35, Vector3(0, 0.3, 0), Junk.metal(Color(0.2, 0.2, 0.22), 0.5, 0.85))
	_engine_parts.append(intake)


func _add_drone_visual(lvl: int) -> void:
	if _drone == null:
		_drone = Node3D.new()
		add_child(_drone)
		var body := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.3
		mesh.height = 0.6
		body.mesh = mesh
		body.material_override = Junk.metal(Color(0.5, 0.42, 0.3), 0.6, 0.75)
		_drone.add_child(body)
		var rotor := Junk.cyl(_drone, 0.45, 0.04, Vector3(0, 0.35, 0), Junk.metal(Color(0.25, 0.24, 0.22), 0.7, 0.6))
		rotor.name = "Rotor"
		var lamp := Junk.box(_drone, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.1, 0.28), Junk.metal(Color(0.2, 1.0, 0.4), 0.3, 0.2))
		var lm := lamp.material_override as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission = Color(0.2, 1.0, 0.4)
		lm.emission_energy_multiplier = 2.0
	else:
		_drone.scale = Vector3.ONE * (1.0 + lvl * 0.15)


func ram_damage_multiplier() -> float:
	return maxf(1.0 - 0.3 * upgrade_levels["spikes"], 0.1)


func repair_rate() -> float:
	return 1.5 * upgrade_levels["drone"]


func _process(delta: float) -> void:
	# Колёса крутятся, корпус слегка трясётся, дрон облетает грузовик.
	for w in _wheels:
		(w as MeshInstance3D).rotate_object_local(Vector3.UP, delta * 9.0)
	_shake_phase += delta * 13.0
	position.y = sin(_shake_phase) * 0.035
	rotation.z = sin(_shake_phase * 0.7) * 0.006
	if _drone != null:
		_drone_phase += delta * 1.2
		_drone.position = Vector3(sin(_drone_phase) * 2.2, 3.4 + sin(_drone_phase * 2.3) * 0.3, cos(_drone_phase) * 4.0)
		var rotor := _drone.get_node_or_null("Rotor")
		if rotor:
			(rotor as Node3D).rotate_y(delta * 25.0)
