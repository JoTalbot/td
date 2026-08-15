extends Node3D
## Рейдер пустоши: догоняет грузовик, пристраивается и таранит/обстреливает.
## Типы: badger (багги), biker (мотоцикл), ram (тяжёлый таран), boss (военный тягач).

signal died(reward: int)
## Босс кричит о смене фазы (текст для HUD).
signal phase_announced(text: String)
## Босс в отчаянии зовёт байкеров на подмогу.
signal spawn_minions(count: int)

const Junk := preload("res://scripts/Junk.gd")

var enemy_type := "buggy"
var max_hp := 50
var hp := 50
var chase_speed := 8.0
var reward := 10
var attack_damage := 4
var attack_interval := 1.6
var is_boss := false
var is_dying := false

## Фаза босса: 1 — обычный, 2 — ярость, 3 — отчаяние (разгонные тараны).
var phase := 1
var _charge_timer := 0.0
var _charge_mult := 1.0
var _charging := false
var _rage_light: OmniLight3D = null

var truck: Node3D = null
var state: Node = null

## Позиция "пристройки" рядом с грузовиком (смещение от его центра).
var attack_offset := Vector3(4.0, 0, -2.0)

var _attack_timer := 0.0
var _bob := 0.0
var _wheels: Array = []
var _body: Node3D
var _hp_bar: MeshInstance3D
var _hp_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _reached := false


func _ready() -> void:
	add_to_group("enemies")
	_rng.seed = randi()
	hp = max_hp
	_bob = randf() * TAU
	_body = Node3D.new()
	add_child(_body)
	match enemy_type:
		"biker": _build_biker()
		"ram": _build_ram()
		"boss": _build_boss()
		_: _build_buggy()
	_build_hp_bar()
	Junk.dust_trail(self, Vector3(0, 0.1, -1.5), 30, 0.7)


func _build_buggy() -> void:
	Junk.box(_body, Vector3(1.3, 0.45, 2.2), Vector3(0, 0.55, 0), Junk.rust(_rng))
	Junk.box(_body, Vector3(1.1, 0.4, 0.9), Vector3(0, 0.95, -0.3), Junk.rust(_rng))
	# Каркас безопасности
	Junk.cyl(_body, 0.05, 1.0, Vector3(-0.5, 1.0, 0.3), Junk.metal(Color(0.2, 0.2, 0.2), 0.7, 0.6), Vector3(0, 0, 20))
	Junk.cyl(_body, 0.05, 1.0, Vector3(0.5, 1.0, 0.3), Junk.metal(Color(0.2, 0.2, 0.2), 0.7, 0.6), Vector3(0, 0, -20))
	for side in [-1.0, 1.0]:
		_wheels.append(Junk.wheel(_body, 0.4, 0.3, Vector3(side * 0.75, 0.4, 0.7)))
		_wheels.append(Junk.wheel(_body, 0.4, 0.3, Vector3(side * 0.75, 0.4, -0.7)))
	# Водитель-рейдер
	Junk.box(_body, Vector3(0.3, 0.4, 0.25), Vector3(0, 1.3, -0.3), Junk.metal(Color(0.7, 0.6, 0.5), 0.9, 0.0))


func _build_biker() -> void:
	Junk.box(_body, Vector3(0.35, 0.4, 1.8), Vector3(0, 0.6, 0), Junk.rust(_rng))
	_wheels.append(Junk.wheel(_body, 0.38, 0.18, Vector3(0, 0.38, 0.8)))
	_wheels.append(Junk.wheel(_body, 0.38, 0.18, Vector3(0, 0.38, -0.8)))
	Junk.cyl(_body, 0.04, 0.7, Vector3(0, 0.95, 0.65), Junk.metal(Color(0.25, 0.22, 0.2), 0.7, 0.5), Vector3(0, 0, 90))
	# Наездник
	Junk.box(_body, Vector3(0.3, 0.5, 0.3), Vector3(0, 1.1, -0.2), Junk.metal(Color(0.55, 0.45, 0.35), 0.95, 0.0))
	Junk.spike(_body, 0.05, 0.3, Vector3(0, 1.5, -0.2))


func _build_ram() -> void:
	Junk.box(_body, Vector3(1.8, 0.7, 2.8), Vector3(0, 0.7, 0), Junk.rust(_rng))
	Junk.box(_body, Vector3(1.5, 0.6, 1.2), Vector3(0, 1.3, -0.6), Junk.rust(_rng))
	# Клин-таран спереди
	var wedge := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.9, 1.0, 1.0)
	wedge.mesh = pm
	wedge.position = Vector3(0, 0.7, 1.8)
	wedge.rotation_degrees = Vector3(90, 0, 0)
	wedge.material_override = Junk.metal(Color(0.45, 0.4, 0.35), 0.6, 0.8)
	_body.add_child(wedge)
	for i in 4:
		Junk.spike(_body, 0.08, 0.45, Vector3(-0.6 + i * 0.4, 0.7, 2.35), Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		_wheels.append(Junk.wheel(_body, 0.5, 0.4, Vector3(side * 1.0, 0.5, 1.0)))
		_wheels.append(Junk.wheel(_body, 0.5, 0.4, Vector3(side * 1.0, 0.5, -1.0)))


func _build_boss() -> void:
	Junk.box(_body, Vector3(2.2, 1.0, 4.5), Vector3(0, 0.95, 0), Junk.rust(_rng))
	Junk.box(_body, Vector3(2.0, 1.1, 1.5), Vector3(0, 1.9, 1.2), Junk.rust(_rng))
	# Череп-украшение на капоте (стилизованный)
	Junk.box(_body, Vector3(0.5, 0.5, 0.3), Vector3(0, 2.2, 2.2), Junk.metal(Color(0.85, 0.8, 0.7), 0.9, 0.0))
	Junk.spike(_body, 0.1, 0.5, Vector3(-0.35, 2.5, 2.2))
	Junk.spike(_body, 0.1, 0.5, Vector3(0.35, 2.5, 2.2))
	# Таранный отвал
	var blade := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.6, 1.4, 1.2)
	blade.mesh = pm
	blade.position = Vector3(0, 0.9, 2.8)
	blade.rotation_degrees = Vector3(90, 0, 0)
	blade.material_override = Junk.metal(Color(0.4, 0.35, 0.3), 0.7, 0.75)
	_body.add_child(blade)
	for i in 6:
		Junk.spike(_body, 0.1, 0.6, Vector3(-1.0 + i * 0.4, 0.9, 3.4), Vector3(90, 0, 0))
	# Выхлопы
	for side in [-1.0, 1.0]:
		Junk.cyl(_body, 0.1, 1.6, Vector3(side * 0.9, 2.2, 0.4), Junk.metal(Color(0.15, 0.15, 0.15), 0.6, 0.8))
	for side in [-1.0, 1.0]:
		for zi in 3:
			_wheels.append(Junk.wheel(_body, 0.6, 0.45, Vector3(side * 1.25, 0.6, -1.4 + zi * 1.4)))


func _build_hp_bar() -> void:
	_hp_bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 0.14)
	_hp_bar.mesh = quad
	_hp_mat = StandardMaterial3D.new()
	_hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_mat.albedo_color = Color(0.3, 0.9, 0.3)
	_hp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.material_override = _hp_mat
	_hp_bar.position.y = 2.6 if is_boss else 1.9
	add_child(_hp_bar)


func take_damage(amount: int, p_state: Node) -> void:
	if is_dying:
		return
	hp -= amount
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.scale.x = maxf(ratio, 0.01)
	_hp_mat.albedo_color = Color(1.0 - ratio * 0.7, ratio * 0.9, 0.15)
	if hp <= 0:
		_die(p_state)
	elif is_boss:
		_update_boss_phase(ratio)


## Смена фаз по порогам HP: 70% — ярость, 40% — отчаяние.
func _update_boss_phase(ratio: float) -> void:
	if phase == 1 and ratio <= 0.7:
		_set_phase(2)
	elif phase == 2 and ratio <= 0.4:
		_set_phase(3)


func _set_phase(p: int) -> void:
	phase = p
	# Машина дёргается — видно, что босс «переключился»
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3.ONE * 1.15, 0.1)
	tw.tween_property(_body, "scale", Vector3.ONE, 0.3)
	if p == 2:
		# Ярость: быстрее едет и чаще бьёт, зловещий отсвет перегретого мотора
		chase_speed *= 1.45
		attack_interval = maxf(attack_interval * 0.7, 1.0)
		_rage_light = OmniLight3D.new()
		_rage_light.light_color = Color(1.0, 0.3, 0.1)
		_rage_light.light_energy = 1.4
		_rage_light.omni_range = 4.5
		_rage_light.position = Vector3(0, 2.2, 1.5)
		_body.add_child(_rage_light)
		phase_announced.emit("😡 Босс в ЯРОСТИ: быстрее и злее!")
	elif p == 3:
		# Отчаяние: зовёт байкеров и идёт на разгонные тараны
		spawn_minions.emit(2)
		_charge_timer = 4.0
		phase_announced.emit("💀 Босс обезумел: берегись разгона!")


var _slow_mult := 1.0
var _slow_timer := 0.0

func apply_slow(factor: float, duration: float) -> void:
	_slow_mult = minf(_slow_mult, factor)
	_slow_timer = maxf(_slow_timer, duration)


func _die(p_state: Node) -> void:
	is_dying = true
	if p_state != null:
		p_state.earn(reward)
	died.emit(reward)
	Junk.explosion(get_tree().current_scene, global_position + Vector3.UP * 0.8, 1.4 if is_boss else 1.0)
	# Машину заносит, она кувыркается и отстаёт
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:z", position.z - 26.0, 1.1).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:x", position.x + signf(position.x) * 6.0, 1.1)
	tw.tween_property(_body, "rotation:z", signf(_rng.randf() - 0.5) * TAU, 1.0)
	tw.tween_property(_body, "rotation:x", -PI * 0.5, 1.0)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if is_dying or truck == null:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0
	for w in _wheels:
		(w as MeshInstance3D).rotate_object_local(Vector3.UP, delta * 12.0)
	_bob += delta * 11.0
	_body.position.y = sin(_bob) * 0.04

	var target_pos: Vector3 = truck.global_position + attack_offset
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length() > 0.4:
		var dir := to_target.normalized()
		global_position += dir * chase_speed * _slow_mult * delta
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z) * 0.25, delta * 4.0)
		_reached = false
	else:
		_reached = true
		_body.rotation.y = lerp_angle(_body.rotation.y, 0.0, delta * 5.0)
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack()
			_attack_timer = attack_interval
		# Фаза 3: периодически откатывается и идёт на разгонный таран
		if is_boss and phase == 3:
			_charge_timer -= delta
			if _charge_timer <= 0.0 and not _charging:
				_start_charge()


## Разгонный таран: босс откатывается назад, потом врубается с утроенной силой.
func _start_charge() -> void:
	_charging = true
	attack_offset.z -= 9.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if is_dying or not _charging:
			return
		_charging = false
		attack_offset.z += 9.0
		_charge_mult = 2.2
		_attack_timer = 0.0   # удар сразу по прибытию
		_charge_timer = 5.5
	)


func _attack() -> void:
	if state == null or truck == null:
		return
	# Рывок-таран в сторону грузовика
	var dir := signf(global_position.x - truck.global_position.x)
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x - dir * 1.1, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:x", position.x, 0.3).set_ease(Tween.EASE_OUT)
	var dmg := int(round(attack_damage * _charge_mult * truck.ram_damage_multiplier()))
	_charge_mult = 1.0
	state.damage_truck(maxi(dmg, 1))
	# Шипы ранят атакующего
	if truck.upgrade_levels["spikes"] > 0:
		take_damage(3 * truck.upgrade_levels["spikes"], state)
