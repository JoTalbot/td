extends Node3D
## Боевая платформа игрока: шесть корпусов от багги (1 слот) до военного
## тягача (10 слотов). Crossout-лесенка: корпус пересобирает всю геометрию
## и слоты; апгрейды навешивают видимые детали (привязаны к габаритам корпуса).

const Junk := preload("res://scripts/Junk.gd")

## Текущий корпус (id из CampaignData.HULLS).
var hull_id := "truck"
var slot_nodes: Array = []      # Node3D маркеров слотов
var weapons: Dictionary = {}    # slot_index -> Weapon
var upgrade_levels := {"armor": 0, "spikes": 0, "engine": 0, "drone": 0}

## Габариты активной платформы — обвесы гаража строятся от них.
var _bed_len := 8.6
var _bed_w := 2.9
var _cab_z := 5.6

var _wheels: Array = []
var _rng := RandomNumberGenerator.new()
var _armor_parts: Array = []
var _spike_parts: Array = []
var _engine_parts: Array = []
var _drone: Node3D = null
var _drone_phase := 0.0
var _shake_phase := 0.0


func _ready() -> void:
	_rng.seed = 0xBADF00D
	set_hull(hull_id)


## Полная пересборка под корпус. Контракт: вызывается ДО монтировки орудий
## (Main применяет hull кампании при старте сцены) или после scene-reload.
func set_hull(id: String) -> void:
	hull_id = id if id != "" else "truck"
	if not weapons.is_empty():
		push_warning("Truck.set_hull: орудия уже смонтированы — сбрасываем вместе с корпусом")
	weapons.clear()
	slot_nodes.clear()
	_wheels.clear()
	_armor_parts.clear()
	_spike_parts.clear()
	_engine_parts.clear()
	_drone = null
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	match hull_id:
		"buggy": _build_buggy()
		"pickup": _build_pickup()
		"flatbed": _build_flatbed()
		"halftrack": _build_halftrack()
		"war_rig": _build_war_rig()
		_: _build_truck()


## Маленький выхлоп для компактных корпусов (скромные частицы).
func _mini_exhaust(parent: Node3D, pos: Vector3) -> void:
	var stack := Node3D.new()
	stack.position = pos
	parent.add_child(stack)
	Junk.cyl(stack, 0.09, 1.4, Vector3.ZERO, Junk.metal(Color(0.2, 0.2, 0.2), 0.7, 0.75))
	Junk.cyl(stack, 0.12, 0.2, Vector3(0, 0.75, 0), Junk.metal(Color(0.1, 0.1, 0.1), 0.9, 0.4))
	var smoke := GPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 0.8
	smoke.preprocess = 0.5
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, -0.5)
	pm.spread = 14.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, 0.6, -1.2)
	pm.scale_min = 0.12
	pm.scale_max = 0.35
	pm.color = Color(0.15, 0.14, 0.13, 0.45)
	smoke.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.3
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.18, 0.17, 0.16, 0.4)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smm
	smoke.draw_pass_1 = sm
	smoke.position = Vector3(0, 1.0, 0)
	stack.add_child(smoke)


## --- Корпус 1: Багги-пустынник (1 слот на крыше) ---
func _build_buggy() -> void:
	_bed_len = 3.0
	_bed_w = 1.9
	_cab_z = 1.4
	var body := Node3D.new()
	body.name = "Cab"
	body.position = Vector3(0, 0, 1.4)
	add_child(body)
	# Рама и днище
	Junk.box(body, Vector3(1.7, 0.3, 3.6), Vector3(0, 0.55, 0), Junk.rust(_rng))
	# Ковш сиденья
	Junk.box(body, Vector3(1.0, 0.35, 1.0), Vector3(0, 0.9, -0.3), Junk.metal(Color(0.3, 0.25, 0.2), 0.85, 0.5))
	Junk.box(body, Vector3(1.0, 0.7, 0.15), Vector3(0, 1.3, -0.8), Junk.rust(_rng))
	# Дуга безопасности над кабиной — на ней же турель-слот
	for side in [-1.0, 1.0]:
		Junk.box(body, Vector3(0.1, 1.0, 0.1), Vector3(side * 0.7, 1.35, -0.7), Junk.rust(_rng))
		Junk.box(body, Vector3(0.1, 0.8, 0.1), Vector3(side * 0.7, 1.25, 0.6), Junk.rust(_rng))
	Junk.box(body, Vector3(1.5, 0.1, 1.4), Vector3(0, 1.85, -0.05), Junk.rust(_rng))
	# Мотор сзади
	Junk.box(body, Vector3(1.0, 0.65, 0.8), Vector3(0, 0.85, -1.5), Junk.metal(Color(0.22, 0.2, 0.18), 0.6, 0.8))
	_mini_exhaust(body, Vector3(-0.55, 0.8, -1.5))
	# Морда: мелкий бампер и фара
	Junk.box(body, Vector3(1.5, 0.25, 0.15), Vector3(0, 0.5, 1.75), Junk.metal(Color(0.35, 0.32, 0.3), 0.7, 0.7))
	Junk.cyl(body, 0.16, 0.12, Vector3(0, 0.75, 1.72), Junk.metal(Color(0.95, 0.85, 0.4), 0.5, 0.9), Vector3(90, 0, 0))
	# Большие задние колёса, маленькие передние — классика багги
	for side in [-1.0, 1.0]:
		_wheels.append(Junk.wheel(body, 0.65, 0.45, Vector3(side * 1.0, 0.65, -1.2)))
		_wheels.append(Junk.wheel(body, 0.5, 0.35, Vector3(side * 0.95, 0.5, 1.25)))
	_build_slots([Vector3(0, 1.95, 1.35)])
	Junk.dust_trail(self, Vector3(-0.7, 0.15, -2.2))
	Junk.dust_trail(self, Vector3(0.7, 0.15, -2.2))


## --- Корпус 2: Пикап «Гиена» (2 слота в борту + 1 на крыше) ---
func _build_pickup() -> void:
	_bed_len = 4.2
	_bed_w = 2.4
	_cab_z = 4.4
	_build_pup_cab(0.82, 4.4)
	# Борт пикапа
	var bed := Node3D.new()
	bed.name = "Trailer"
	add_child(bed)
	Junk.box(bed, Vector3(2.2, 0.3, 4.0), Vector3(0, 0.8, -0.4), Junk.metal(Color(0.24, 0.21, 0.18), 0.85, 0.55))
	Junk.box(bed, Vector3(2.4, 0.15, 4.2), Vector3(0, 0.98, -0.4), Junk.metal(Color(0.33, 0.28, 0.22), 0.8, 0.5))
	for side in [-1.0, 1.0]:
		Junk.box(bed, Vector3(0.1, 0.45, 4.2), Vector3(side * 1.15, 1.25, -0.4), Junk.rust(_rng))
	Junk.box(bed, Vector3(2.4, 0.45, 0.12), Vector3(0, 1.25, -2.5), Junk.rust(_rng))
	for side in [-1.0, 1.0]:
		_wheels.append(Junk.wheel(bed, 0.55, 0.4, Vector3(side * 1.1, 0.55, -1.6)))
	# Канистра в борту
	Junk.box(bed, Vector3(0.35, 0.5, 0.25), Vector3(1.0, 1.25, 0.9), Junk.metal(Color(0.5, 0.15, 0.1), 0.8, 0.4))
	_build_slots([
		Vector3(-0.66, 1.15, -1.0), Vector3(0.66, 1.15, -1.0),
		Vector3(0, 2.35, 3.9),
	])
	Junk.dust_trail(self, Vector3(-0.9, 0.15, -2.8))
	Junk.dust_trail(self, Vector3(0.9, 0.15, -2.8))


## --- Корпус 3: Бортовая «Кляча» (4 слота в борту + 1 на крыше) ---
func _build_flatbed() -> void:
	_bed_len = 6.2
	_bed_w = 2.6
	_cab_z = 5.0
	_build_pup_cab(0.92, 5.0)
	var bed := Node3D.new()
	bed.name = "Trailer"
	add_child(bed)
	Junk.box(bed, Vector3(2.4, 0.35, 6.0), Vector3(0, 0.75, -0.9), Junk.metal(Color(0.24, 0.21, 0.18), 0.85, 0.55))
	Junk.box(bed, Vector3(2.6, 0.18, 6.2), Vector3(0, 1.0, -0.9), Junk.metal(Color(0.33, 0.28, 0.22), 0.8, 0.5))
	for side in [-1.0, 1.0]:
		var wall := Junk.box(bed, Vector3(0.12, 0.5, 6.2), Vector3(side * 1.3, 1.3, -0.9), Junk.rust(_rng))
		for i in 5:
			Junk.box(wall, Vector3(0.16, 0.12, 0.12), Vector3(0, 0.1, -2.5 + i * 1.2), Junk.metal(Color(0.5, 0.45, 0.4), 0.6, 0.8))
	Junk.box(bed, Vector3(2.6, 0.55, 0.14), Vector3(0, 1.3, -4.0), Junk.rust(_rng))
	for side in [-1.0, 1.0]:
		for zi in 2:
			_wheels.append(Junk.wheel(bed, 0.55, 0.4, Vector3(side * 1.15, 0.55, -2.6 + zi * 1.6)))
	_build_slots([
		Vector3(-0.72, 1.15, -2.6), Vector3(0.72, 1.15, -2.6),
		Vector3(-0.72, 1.15, -0.4), Vector3(0.72, 1.15, -0.4),
		Vector3(0, 2.4, 4.5),
	])
	Junk.dust_trail(self, Vector3(-1.0, 0.2, -4.2))
	Junk.dust_trail(self, Vector3(1.0, 0.2, -4.2))
	Junk.dust_trail(self, Vector3(0, 0.1, -4.6), 30, 1.2)


## --- Корпус 4: Полугусеничный «Кабан» (4 в борту + 2 на крыше) ---
func _build_halftrack() -> void:
	_bed_len = 6.2
	_bed_w = 2.7
	_cab_z = 5.0
	_build_pup_cab(0.92, 5.0)
	var bed := Node3D.new()
	bed.name = "Trailer"
	add_child(bed)
	Junk.box(bed, Vector3(2.5, 0.35, 6.0), Vector3(0, 0.8, -0.9), Junk.metal(Color(0.2, 0.19, 0.17), 0.85, 0.6))
	Junk.box(bed, Vector3(2.7, 0.18, 6.2), Vector3(0, 1.02, -0.9), Junk.metal(Color(0.3, 0.26, 0.2), 0.8, 0.55))
	# Гусеничные ленты вместо задних колёс: блоки+катки
	for side in [-1.0, 1.0]:
		Junk.box(bed, Vector3(0.5, 0.85, 3.4), Vector3(side * 1.1, 0.55, -2.2), Junk.metal(Color(0.12, 0.11, 0.1), 0.9, 0.35))
		for i in 5:
			var roller := Junk.wheel(bed, 0.28, 0.52, Vector3(side * 1.12, 0.35, -3.4 + i * 0.7))
			_wheels.append(roller)
	# Бронескирты
	for side in [-1.0, 1.0]:
		Junk.box(bed, Vector3(0.1, 0.7, 6.2), Vector3(side * 1.38, 1.35, -0.9), Junk.rust(_rng), Vector3(0, 0, side * -4))
	Junk.box(bed, Vector3(2.7, 0.55, 0.14), Vector3(0, 1.3, -4.0), Junk.rust(_rng))
	_build_slots([
		Vector3(-0.72, 1.15, -2.6), Vector3(0.72, 1.15, -2.6),
		Vector3(-0.72, 1.15, -0.4), Vector3(0.72, 1.15, -0.4),
		Vector3(-0.72, 2.4, 4.6), Vector3(0.72, 2.4, 4.6),
	])
	Junk.dust_trail(self, Vector3(-1.1, 0.2, -4.2))
	Junk.dust_trail(self, Vector3(1.1, 0.2, -4.2))
	Junk.dust_trail(self, Vector3(0, 0.1, -4.6), 34, 1.3)


## --- Корпус 5: Фура «Мамонт» (легендарная 8-слотовая компоновка) ---
func _build_truck() -> void:
	_bed_len = 8.6
	_bed_w = 2.9
	_cab_z = 5.6
	_build_cab()
	_build_trailer()
	_build_slots([
		Vector3(-0.72, 1.15, -3.2), Vector3(0.72, 1.15, -3.2),
		Vector3(-0.72, 1.15, -0.8), Vector3(0.72, 1.15, -0.8),
		Vector3(-0.72, 1.15, 1.6), Vector3(0.72, 1.15, 1.6),
		Vector3(-0.72, 2.4, 5.0), Vector3(0.72, 2.4, 5.0),
	])


## --- Корпус 6: Тягач «Одержимый» (10 слотов, удлинённая платформа) ---
func _build_war_rig() -> void:
	_bed_len = 10.6
	_bed_w = 3.1
	_cab_z = 5.6
	_build_cab()
	_build_rig_trailer()
	_build_slots([
		Vector3(-0.78, 1.15, -4.6), Vector3(0.78, 1.15, -4.6),
		Vector3(-0.78, 1.15, -2.2), Vector3(0.78, 1.15, -2.2),
		Vector3(-0.78, 1.15, 0.2), Vector3(0.78, 1.15, 0.2),
		Vector3(-0.78, 1.15, 2.6), Vector3(0.78, 1.15, 2.6),
		Vector3(-0.78, 2.4, 5.0), Vector3(0.78, 2.4, 5.0),
	])


## Уменьшенная кабина для лёгких корпусов (пикап/бортовой/полугусеничный).
func _build_pup_cab(scale_k: float, z_pos: float) -> void:
	_build_cab()
	var cab := get_node("Cab") as Node3D
	cab.position.z = z_pos
	cab.scale = Vector3.ONE * scale_k


func _build_cab() -> void:
	var cab := Node3D.new()
	cab.name = "Cab"
	cab.position = Vector3(0, 0, 5.6)
	add_child(cab)

	# Капот и кабина
	Junk.box(cab, Vector3(2.4, 1.0, 2.2), Vector3(0, 0.9, 1.2), Junk.metal(Color(0.3, 0.25, 0.2), 0.8, 0.6))
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
		Junk.cyl(pipe, 0.15, 0.25, Vector3(0, 1.3, 0), Junk.metal(Color(0.1, 0.1, 0.1), 0.9, 0.4))
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


## Длинный трейлер «Одержимого»: больше рама, больше зла.
func _build_rig_trailer() -> void:
	_build_trailer()
	var trailer := get_node("Trailer") as Node3D
	# Наращиваем раму в хвост
	Junk.box(trailer, Vector3(2.8, 0.4, 2.4), Vector3(0, 0.78, -5.2), Junk.metal(Color(0.24, 0.21, 0.18), 0.85, 0.55))
	Junk.box(trailer, Vector3(3.1, 0.2, 2.6), Vector3(0, 1.02, -5.2), Junk.metal(Color(0.33, 0.28, 0.22), 0.8, 0.5))
	for side in [-1.0, 1.0]:
		Junk.box(trailer, Vector3(0.12, 0.55, 2.6), Vector3(side * 1.55, 1.3, -5.2), Junk.rust(_rng))
		for i in 2:
			_wheels.append(Junk.wheel(trailer, 0.55, 0.4, Vector3(side * 1.4, 0.55, -5.9 + i * 1.3)))
	# Шипастый гребень по заднему борту
	for i in 5:
		Junk.spike(trailer, 0.12, 0.6, Vector3(-1.2 + i * 0.6, 1.6, -6.4), Vector3(0, 0, 0))
	Junk.box(trailer, Vector3(3.1, 0.6, 0.14), Vector3(0, 1.35, -6.5), Junk.rust(_rng))
	Junk.dust_trail(self, Vector3(0, 0.1, -7.0), 46, 1.6)


func _build_slots(positions: Array) -> void:
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


## Апгрейды фуры переживают смену корпуса только через пересборку сцены:
## при set_hull вызываем заново для актуального корпуса.
func reapply_upgrades() -> void:
	var saved: Dictionary = upgrade_levels.duplicate()
	upgrade_levels = {"armor": 0, "spikes": 0, "engine": 0, "drone": 0}
	for id in saved:
		for i in int(saved[id]):
			apply_upgrade(id)


## Косметика мастерства трасс: видимые знаки, костяные трофеи и медная мачта.
func apply_route_cosmetics(mastered_count: int) -> void:
	var old := get_node_or_null("RouteCosmetics")
	if old != null:
		old.queue_free()
	if mastered_count <= 0:
		return
	var root := Node3D.new()
	root.name = "RouteCosmetics"
	add_child(root)
	var colors := [Color(0.72, 0.34, 0.14), Color(0.78, 0.62, 0.24), Color(0.36, 0.48, 0.42)]
	# По одной клёпаной дорожной табличке за каждую освоенную трассу.
	for i in mini(mastered_count, 6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := -_bed_len * 0.36 + int(i / 2) * 1.25
		var plate := Junk.box(root, Vector3(0.09, 0.42, 0.72), Vector3(side * (_bed_w * 0.54), 1.65, z), Junk.metal(colors[i % colors.size()], 0.75, 0.65))
		plate.rotation_degrees.z = side * 5.0
		for rivet_y in [-0.14, 0.14]:
			Junk.cyl(plate, 0.025, 0.1, Vector3(side * 0.05, rivet_y, 0), Junk.metal(Color(0.18, 0.15, 0.12), 0.6, 0.8), Vector3(0, 0, 90))
	if mastered_count >= 2:
		# Костяные рога на крыше — награда южных трактов.
		Junk.spike(root, 0.12, 0.75, Vector3(-0.65, 2.9, _cab_z), Vector3(0, 0, -22))
		Junk.spike(root, 0.12, 0.75, Vector3(0.65, 2.9, _cab_z), Vector3(0, 0, 22))
	if mastered_count >= 4:
		# Медная маршрутная мачта.
		var copper := Junk.metal(Color(0.62, 0.3, 0.12), 0.58, 0.8)
		Junk.cyl(root, 0.06, 1.8, Vector3(0, 3.2, _cab_z - 0.4), copper)
		Junk.cyl(root, 0.035, 0.9, Vector3(0, 4.0, _cab_z - 0.4), copper, Vector3(0, 0, 90))
	if mastered_count >= 6:
		# Золотой знак полного знания пустоши.
		Junk.cyl(root, 0.3, 0.1, Vector3(0, 2.75, _cab_z + 0.75), Junk.metal(Color(0.95, 0.7, 0.2), 0.35, 0.85), Vector3(90, 0, 0))


func _add_armor_visual(lvl: int) -> void:
	# Ржавые бронелисты на бортах, с каждым уровнем — больше и выше.
	for side in [-1.0, 1.0]:
		for i in 2:
			var plate := Junk.box(self,
				Vector3(0.1, 0.55 + lvl * 0.1, 1.6),
				Vector3(side * (_bed_w * 0.52 + lvl * 0.04), 1.35 + lvl * 0.12, -_bed_len * 0.35 + i * _bed_len * 0.38 + lvl * 0.5),
				Junk.rust(_rng),
				Vector3(0, 0, side * _rng.randf_range(2.0, 6.0)))
			_armor_parts.append(plate)
	if lvl >= 2:
		# Бронещит на кабину
		var shield := Junk.box(self, Vector3(2.5, 0.7, 0.12), Vector3(0, 2.3, _cab_z + 0.8), Junk.rust(_rng), Vector3(-20, 0, 0))
		_armor_parts.append(shield)


func _add_spikes_visual(lvl: int) -> void:
	# Шипы по бортам и на колёсах.
	for side in [-1.0, 1.0]:
		for i in 3 + lvl:
			var sp := Junk.spike(self, 0.12, 0.55 + lvl * 0.1,
				Vector3(side * (_bed_w * 0.56), 1.15, -_bed_len * 0.44 + i * (_bed_len * 0.9 / (2 + lvl))),
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
