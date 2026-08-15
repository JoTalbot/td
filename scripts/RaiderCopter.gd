extends Node3D
## Рейдер-автожир из воздушной засады: впархивает сверху, висит над фурой,
## сбрасывает самодельные бомбы, а потом идёт на таран-камикадзе.
## Орудия могут сбить его: сидит в группе "enemies".
## НЕ считается в WaveManager.enemies_alive — событийный бонус-враг.

signal died(reward: int)

const Junk := preload("res://scripts/Junk.gd")

var max_hp := 45
var hp := 45
var reward := 22
var bomb_damage := 6
var crash_damage := 15
var bombs_total := 3
var is_dying := false

var truck: Node3D = null
var state: Node = null

enum FlyPhase {APPROACH, HOVER, KAMIKAZE}
var _phase: int = FlyPhase.APPROACH

var _rng := RandomNumberGenerator.new()
var _body: Node3D
var _rotor: Node3D
var _bob := 0.0
var _hover_offset := Vector3.ZERO
var _bomb_timer := 0.0
var _bombs_left := 0
var _wobble := 0.0

const HOVER_ALT := 6.5     # высота висения над фурой
const FLY_SPEED := 9.0     # скорость подлёта
const CRASH_SPEED := 22.0  # скорость пике


func _ready() -> void:
	add_to_group("enemies")
	_rng.seed = randi()
	hp = max_hp
	_bombs_left = bombs_total
	_bob = randf() * TAU
	_build_visual()
	# Кружево висения: случайная точка сбоку-сзади от фуры
	_hover_offset = Vector3(_rng.randf_range(-4.5, 4.5), HOVER_ALT, _rng.randf_range(-4.0, 2.0))


func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	# Рама-сиденье из труб
	Junk.box(_body, Vector3(0.8, 0.35, 1.1), Vector3(0, 0, 0), Junk.rust(_rng))
	Junk.cyl(_body, 0.09, 1.5, Vector3(0, 0.6, 0), Junk.metal(Color(0.3, 0.28, 0.25), 0.7, 0.6))
	# Пилот-рейдер
	Junk.box(_body, Vector3(0.35, 0.45, 0.3), Vector3(0, 0.45, -0.15), Junk.metal(Color(0.6, 0.5, 0.4), 0.9, 0.0))
	# Лопасти — крутятся
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.4, 0)
	_body.add_child(_rotor)
	Junk.box(_rotor, Vector3(4.2, 0.05, 0.22), Vector3.ZERO, Junk.metal(Color(0.25, 0.22, 0.2), 0.6, 0.5))
	Junk.box(_rotor, Vector3(0.22, 0.05, 4.2), Vector3.ZERO, Junk.metal(Color(0.25, 0.22, 0.2), 0.6, 0.5))
	# Хвостовая балка + хвостовой винт
	Junk.cyl(_body, 0.07, 2.2, Vector3(0, 0.25, -1.6), Junk.metal(Color(0.32, 0.3, 0.26), 0.7, 0.6), Vector3(90, 0, 0))
	var tail := Junk.box(_body, Vector3(0.05, 0.7, 0.9), Vector3(0.1, 0.35, -2.7), Junk.metal(Color(0.4, 0.35, 0.3), 0.7, 0.5))
	tail.name = "TailRotor"
	# Подвес с бомбами — ржавые болванки по бокам
	Junk.cyl(_body, 0.14, 0.5, Vector3(0.45, -0.25, 0.2), Junk.metal(Color(0.5, 0.3, 0.12), 0.8, 0.5))
	Junk.cyl(_body, 0.14, 0.5, Vector3(-0.45, -0.25, 0.2), Junk.metal(Color(0.5, 0.3, 0.12), 0.8, 0.5))


func take_damage(amount: int, p_state: Node) -> void:
	if is_dying:
		return
	hp -= amount
	_wobble += 0.8   # трясёт от попаданий
	if hp <= 0:
		_shot_down(p_state)


func _shot_down(p_state: Node) -> void:
	is_dying = true
	if p_state != null:
		p_state.earn(reward)
	died.emit(reward)
	# Кувырок вниз с взрывом при приземлении
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", 0.5, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(_body, "rotation:z", _rng.randf_range(3.0, 6.0), 1.0)
	tw.tween_property(_body, "rotation:x", _rng.randf_range(-4.0, -2.0), 1.0)
	tw.chain().tween_callback(func() -> void:
		Junk.explosion(get_tree().current_scene, global_position, 1.3)
		queue_free()
	)


func _process(delta: float) -> void:
	if is_dying or truck == null:
		return
	_bob += delta * 9.0
	_wobble = maxf(_wobble - delta * 2.5, 0.0)
	# Лопасти всегда крутятся, корпус чуть покачивает
	_rotor.rotate_y(delta * 28.0)
	var tail := _body.get_node_or_null("TailRotor") as Node3D
	if tail:
		tail.rotate_x(delta * 20.0)
	_body.position.y = sin(_bob) * 0.15
	_body.rotation.z = sin(_bob * 0.63) * 0.06 + _wobble * sin(_bob * 7.0) * 0.12

	match _phase:
		FlyPhase.APPROACH:
			_fly_toward(truck.global_position + _hover_offset, FLY_SPEED, delta)
			if global_position.distance_to(truck.global_position + _hover_offset) < 1.0:
				_phase = FlyPhase.HOVER
				_bomb_timer = 1.2   # первая бомба почти сразу — игрок видит, чем это грозит
		FlyPhase.HOVER:
			# Висим в точке, лёгкий дрейф за фурой по ветру
			var target_pos: Vector3 = truck.global_position + _hover_offset + Vector3(sin(_bob * 0.4) * 0.8, 0, cos(_bob * 0.31) * 0.8)
			global_position = global_position.lerp(target_pos, delta * 2.0)
			_bomb_timer -= delta
			if _bomb_timer <= 0.0:
				if _bombs_left > 0:
					_drop_bomb()
					_bombs_left -= 1
					_bomb_timer = 3.5
				else:
					_phase = FlyPhase.KAMIKAZE
		FlyPhase.KAMIKAZE:
			# Визг мотора и пике прямо в платформу
			var aim: Vector3 = truck.global_position + Vector3(0, 1.6, 0)
			_fly_toward(aim, CRASH_SPEED, delta)
			if global_position.distance_to(aim) < 1.4:
				Junk.explosion(get_tree().current_scene, global_position, 1.6)
				if state != null and not state.is_invulnerable():
					state.damage_truck(crash_damage)
				died.emit(0)
				queue_free()


func _fly_toward(point: Vector3, speed: float, delta: float) -> void:
	var to := point - global_position
	if to.length() < 0.05:
		return
	global_position += to.normalized() * speed * delta
	# Нос по направлению полёта
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), delta * 3.0)


func _drop_bomb() -> void:
	var bomb := Bomb.new()
	bomb.state = state
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = global_position + Vector3(0, -0.4, 0)
	# Лёгкий кабанчик при сбросе
	_wobble += 0.4


## Самодельная авиабомба: падает по вертикали и рвётся о палубу.
class Bomb:
	extends Node3D

	const JunkF := preload("res://scripts/Junk.gd")

	var state: Node

	func _ready() -> void:
		var body := JunkF.cyl(self, 0.16, 0.5, Vector3.ZERO, JunkF.metal(Color(0.45, 0.28, 0.12), 0.75, 0.55))
		body.rotation_degrees = Vector3.ZERO
		# Оперение-крестовина
		JunkF.box(self, Vector3(0.34, 0.2, 0.03), Vector3(0, 0.32, 0), JunkF.metal(Color(0.3, 0.27, 0.24), 0.7, 0.6))
		JunkF.box(self, Vector3(0.03, 0.2, 0.34), Vector3(0, 0.32, 0), JunkF.metal(Color(0.3, 0.27, 0.24), 0.7, 0.6))

	func _process(delta: float) -> void:
		position.y -= 11.0 * delta
		rotation.y += delta * 2.0
		if position.y <= 1.1:
			JunkF.explosion(get_tree().current_scene, global_position, 0.9)
			if state != null and not state.is_invulnerable():
				state.damage_truck(6)
			queue_free()
