extends Node3D
## Союзный броневик эскорт-контракта: тащится на левом фланге фуры.
## Часть рейдеров целится в него — задача эскорта: довести живым.

const Junk := preload("res://scripts/Junk.gd")

signal destroyed
signal damaged(hp: int, max_hp: int)

var max_hp := 160
var hp := 160
var is_dead := false
var truck: Node3D = null

var _wheels: Array = []
var _hp_bar: MeshInstance3D
var _hp_mat: StandardMaterial3D
var _bob := 0.0
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_build()
	_build_hp_bar()


func _build() -> void:
	# Бронированный фургон: будка, кабина, листы брони по бортам, турель
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Рама и будка
	Junk.box(_body, Vector3(1.7, 0.3, 4.2), Vector3(0, 0.4, 0), Junk.metal(Color(0.2, 0.18, 0.15)))
	Junk.box(_body, Vector3(1.5, 1.05, 2.6), Vector3(0, 1.05, -0.5), Junk.rust(rng))
	# Кабина с пулемётным гнездом
	Junk.box(_body, Vector3(1.5, 0.75, 1.0), Vector3(0, 0.85, 1.45), Junk.metal(Color(0.35, 0.32, 0.25)))
	Junk.box(_body, Vector3(1.2, 0.25, 0.08), Vector3(0, 1.15, 1.9), Junk.metal(Color(0.1, 0.12, 0.14)))
	# Листы брони по бортам — чужие щиты, наши теперь
	Junk.box(_body, Vector3(0.08, 0.7, 2.4), Vector3(-0.8, 1.1, -0.5), Junk.rust(rng), Vector3(0, 0, -6))
	Junk.box(_body, Vector3(0.08, 0.7, 2.4), Vector3(0.8, 1.1, -0.5), Junk.rust(rng), Vector3(0, 0, 6))
	# Турель на крыше будки
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.65, -0.5)
	_body.add_child(tur)
	Junk.cyl(tur, 0.22, 0.22, Vector3.ZERO, Junk.metal(Color(0.28, 0.26, 0.22)))
	Junk.cyl(tur, 0.045, 0.7, Vector3(0, 0.12, 0.4), Junk.metal(Color(0.15, 0.15, 0.15), 0.5, 0.85), Vector3(90, 0, 0))
	# Колёса
	for i in 4:
		var side := -0.8 if i % 2 == 0 else 0.8
		_wheels.append(Junk.wheel(_body, 0.42, 0.3, Vector3(side, 0.42, -1.35 + (i / 2) * 2.7)))
	# Выхлопная труба
	Junk.cyl(_body, 0.06, 0.8, Vector3(-0.7, 1.5, -1.6), Junk.metal(Color(0.12, 0.12, 0.12)))


func _build_hp_bar() -> void:
	_hp_bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 0.14)
	_hp_bar.mesh = quad
	_hp_mat = StandardMaterial3D.new()
	_hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_mat.albedo_color = Color(0.3, 0.7, 0.95)
	_hp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.material_override = _hp_mat
	_hp_bar.position.y = 2.3
	add_child(_hp_bar)


func _process(delta: float) -> void:
	if truck == null or is_dead:
		return
	# Держимся левым флангом чуть позади фуры
	var want: Vector3 = truck.global_position + Vector3(-6.5, 0, -5.0)
	want.y = 0.0
	global_position = global_position.lerp(want, minf(delta * 2.4, 1.0))
	_bob += delta * 9.0
	_body.position.y = sin(_bob) * 0.05
	for w in _wheels:
		(w as MeshInstance3D).rotate_object_local(Vector3.UP, delta * 10.0)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.scale.x = maxf(ratio, 0.01)
	_hp_mat.albedo_color = Color(0.95 - ratio * 0.55, 0.3 + ratio * 0.4, 0.2)
	damaged.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	Junk.explosion(get_tree().current_scene, global_position, 1.4)
	visible = false
	set_process(false)
	destroyed.emit()
