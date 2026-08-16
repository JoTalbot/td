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
var ally: Node3D = null      # эскорт-фургон: если задан и жив — бьём его, а не фуру
## Диверсант: первый удар по фуре заклинивает случайное оружие на несколько секунд.
var sab := false
var _sab_done := false

## Абордаж: добитую (HP < 30%) лёгкую тачку игрок может угнать тапом — целиком в ангар.
const BOARDABLE := ["buggy", "biker", "ram", "traincar"]
var hook_attempted := false        # один бросок крюка на тачку
var _hook_mark: MeshInstance3D = null

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
		"scoutboss": _build_scoutboss()
		"bonepriest": _build_bonepriest()
		"trainloko": _build_trainloko()
		"traincar": _build_traincar()
		_: _build_buggy()
	_build_hp_bar()
	Junk.dust_trail(self, Vector3(0, 0.1, -1.5), 30, 0.7)
	if sab:
		_add_sab_hood()


## Чёрный балахон диверсанта: заметен издалека — приоритетная цель.
func _add_sab_hood() -> void:
	Junk.box(_body, Vector3(0.42, 0.5, 0.42), Vector3(0, 1.35, -0.2),
		Junk.metal(Color(0.08, 0.07, 0.09), 0.95, 0.0))
	scale = Vector3.ONE * 1.05


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


## Локомотив военного поезда: длинный котёл, дымовая труба, таранный плуг.
func _build_trainloko() -> void:
	# Длинная рама на больших колёсах
	Junk.box(_body, Vector3(1.8, 0.35, 5.4), Vector3(0, 0.5, 0), Junk.metal(Color(0.18, 0.17, 0.15)))
	for i in 6:
		var side := -0.85 if i % 2 == 0 else 0.85
		_wheels.append(Junk.wheel(_body, 0.5, 0.34, Vector3(side, 0.5, -1.9 + (i / 2) * 1.9)))
	# Котёл
	Junk.cyl(_body, 0.7, 3.4, Vector3(0, 1.25, 0.4), Junk.rust(_rng), Vector3(90, 0, 0))
	# Будка машиниста
	Junk.box(_body, Vector3(1.7, 1.1, 1.2), Vector3(0, 1.45, -1.9), Junk.rust(_rng))
	Junk.box(_body, Vector3(1.5, 0.3, 0.1), Vector3(0, 1.9, -1.35), Junk.metal(Color(0.1, 0.12, 0.14)))
	# Дымовая труба и фара
	Junk.cyl(_body, 0.14, 0.9, Vector3(0, 2.15, 1.7), Junk.metal(Color(0.1, 0.1, 0.1), 0.6, 0.8))
	Junk.cyl(_body, 0.18, 0.15, Vector3(0, 1.25, 2.15), Junk.metal(Color(0.95, 0.85, 0.4), 0.5, 0.9), Vector3(90, 0, 0))
	# Таранный плуг спереди
	var plow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.9, 0.8, 1.0)
	plow.mesh = pm
	plow.position = Vector3(0, 0.6, 2.6)
	plow.rotation_degrees = Vector3(0, 180, 0)
	plow.material_override = Junk.rust(_rng)
	_body.add_child(plow)
	Junk.spike(_body, 0.1, 0.5, Vector3(-0.6, 1.0, 2.7), Vector3(90, 0, 0))
	Junk.spike(_body, 0.1, 0.5, Vector3(0.6, 1.0, 2.7), Vector3(90, 0, 0))


## Вагон военного поезда: бронекороб с турелью на крыше.
func _build_traincar() -> void:
	Junk.box(_body, Vector3(1.8, 0.35, 4.2), Vector3(0, 0.5, 0), Junk.metal(Color(0.18, 0.17, 0.15)))
	for i in 4:
		var side := -0.85 if i % 2 == 0 else 0.85
		_wheels.append(Junk.wheel(_body, 0.5, 0.34, Vector3(side, 0.5, -1.5 + (i / 2) * 2.6)))
	Junk.box(_body, Vector3(1.6, 0.95, 3.6), Vector3(0, 1.15, 0), Junk.rust(_rng))
	# Бронелисты по бортам
	Junk.box(_body, Vector3(0.08, 0.75, 3.2), Vector3(-0.84, 1.2, 0), Junk.rust(_rng), Vector3(0, 0, -5))
	Junk.box(_body, Vector3(0.08, 0.75, 3.2), Vector3(0.84, 1.2, 0), Junk.rust(_rng), Vector3(0, 0, 5))
	# Турель
	Junk.cyl(_body, 0.3, 0.22, Vector3(0, 1.75, 0.9), Junk.metal(Color(0.28, 0.26, 0.22)))
	Junk.cyl(_body, 0.05, 0.7, Vector3(0, 1.8, 1.35), Junk.metal(Color(0.15, 0.15, 0.15), 0.5, 0.85), Vector3(90, 0, 0))


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


## Дозорный-картограф: босс-тягач с антеннами, прожектором и картами на броне.
func _build_scoutboss() -> void:
	_build_boss()
	var copper := Junk.metal(Color(0.58, 0.28, 0.12), 0.65, 0.75)
	# Высокая мачта и перекрёстные антенны.
	Junk.cyl(_body, 0.07, 2.4, Vector3(0, 3.0, -0.4), copper)
	Junk.cyl(_body, 0.04, 1.4, Vector3(0, 4.05, -0.4), copper, Vector3(0, 0, 90))
	for x in [-0.65, 0.65]:
		Junk.spike(_body, 0.05, 0.55, Vector3(x, 4.05, -0.4), Vector3(0, 0, 90 if x > 0 else -90))
	# Прожектор разведки.
	var lamp := Junk.cyl(_body, 0.28, 0.22, Vector3(0, 2.65, 2.15), Junk.metal(Color(0.9, 0.72, 0.28), 0.35, 0.8), Vector3(90, 0, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.28)
	light.light_energy = 2.0
	light.omni_range = 7.0
	lamp.add_child(light)
	# Карты и маршрутные листы, приклёпанные к бортам.
	for side in [-1.0, 1.0]:
		var plate := Junk.box(_body, Vector3(0.08, 0.8, 1.25), Vector3(side * 1.16, 1.55, 0.45), Junk.metal(Color(0.62, 0.48, 0.28), 0.95, 0.05))
		plate.rotation_degrees.z = side * 4.0
		for z in [-0.35, 0.0, 0.35]:
			Junk.cyl(plate, 0.025, 0.09, Vector3(side * 0.05, 0.0, z), copper, Vector3(0, 0, 90))
	# Флаги-разведчики на мачте.
	Junk.box(_body, Vector3(0.75, 0.42, 0.05), Vector3(0.42, 3.65, -0.4), Junk.metal(Color(0.3, 0.12, 0.08), 0.95, 0.0), Vector3(0, 0, -8))


## Костяной Жрец: командир Сборщиков с клеткой из рёбер и тотемом.
func _build_bonepriest() -> void:
	_build_boss()
	var bone := Junk.metal(Color(0.78, 0.68, 0.48), 0.92, 0.08)
	var dark := Junk.metal(Color(0.22, 0.1, 0.06), 0.9, 0.25)
	# Рёберная клетка над кабиной.
	for side in [-1.0, 1.0]:
		for i in 3:
			Junk.cyl(_body, 0.075, 1.7, Vector3(side * (0.65 + i * 0.16), 2.9, 0.4 - i * 0.35), bone, Vector3(0, 0, side * 24))
	# Высокий тотем из позвонков.
	Junk.cyl(_body, 0.12, 2.0, Vector3(0, 3.2, -0.7), dark)
	for y in [2.55, 2.9, 3.25, 3.6, 3.95]:
		Junk.cyl(_body, 0.18, 0.16, Vector3(0, y, -0.7), bone)
	Junk.box(_body, Vector3(0.48, 0.55, 0.28), Vector3(0, 4.25, -0.7), bone)
	Junk.spike(_body, 0.09, 0.55, Vector3(-0.28, 4.5, -0.7), Vector3(0, 0, -24))
	Junk.spike(_body, 0.09, 0.55, Vector3(0.28, 4.5, -0.7), Vector3(0, 0, 24))
	# Курильницы с красным светом по бортам.
	for side in [-1.0, 1.0]:
		var brazier := Junk.cyl(_body, 0.2, 0.22, Vector3(side * 1.15, 2.2, -0.8), dark)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.22, 0.08)
		glow.light_energy = 1.1
		glow.omni_range = 3.0
		brazier.add_child(glow)


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
	else:
		_check_hook_mark()


## --- Абордаж ---

## Тачку можно угнать: тип лёгкий, живая, жестоко бита, крюк ещё не бросали.
func boardable() -> bool:
	return (not is_dying) and (not hook_attempted) and enemy_type in BOARDABLE \
		and hp > 0 and float(hp) / float(max_hp) < 0.3


## Мигающий янтарный ромбик над добитой тачкой: «жми — угоняй!»
func _check_hook_mark() -> void:
	if boardable() and _hook_mark == null:
		_hook_mark = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		_hook_mark.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.62, 0.15)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_hook_mark.material_override = m
		_hook_mark.position.y = 2.9 if is_boss else 2.2
		add_child(_hook_mark)


func _drop_hook_mark() -> void:
	if _hook_mark != null:
		_hook_mark.queue_free()
		_hook_mark = null


## Крюк впился: тачку тянет назад по тросу (те же тормоза, что у гарпуна).
func apply_hook() -> void:
	_slow_mult = 0.35
	_slow_timer = 2.5


## Крюк сорвался: рейдер озверел — бьёт больнее и чаще.
func enrage() -> void:
	attack_damage = int(ceil(attack_damage * 1.4))
	attack_interval = maxf(attack_interval * 0.8, 0.6)
	chase_speed *= 1.15
	_drop_hook_mark()


## Удачный угон: трос поддёрнул тачку и унёс с трассы — без взрыва и без лома,
## награда — целый трофей в ангаре. Смерть учитываем (волна/контракты).
func capture() -> void:
	if is_dying:
		return
	is_dying = true
	_drop_hook_mark()
	died.emit(0)
	var dir := signf(global_position.x)
	if dir == 0.0:
		dir = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:z", position.z - 24.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 3.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", position.x + dir * 4.0, 0.9)
	tw.tween_property(_body, "rotation:y", dir * 0.9, 0.9)
	tw.chain().tween_callback(queue_free)


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
		if enemy_type == "bonepriest":
			spawn_minions.emit(2)
			phase_announced.emit("КОСТЯНОЙ ЖРЕЦ поднял первую свиту!")
		else:
			phase_announced.emit("😡 Босс в ЯРОСТИ: быстрее и злее!")
	elif p == 3:
		# Отчаяние: зовёт байкеров и идёт на разгонные тараны
		spawn_minions.emit(4 if enemy_type == "bonepriest" else 2)
		_charge_timer = 4.0
		phase_announced.emit("ЖРЕЦ созвал костяную орду!" if enemy_type == "bonepriest" else "💀 Босс обезумел: берегись разгона!")


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
	# Маркер угона пульсирует, чтобы его заметили в гуще боя
	if _hook_mark != null:
		var s := 1.0 + 0.25 * sin(_bob * 0.9)
		_hook_mark.scale = Vector3(s, s, s)

	# Цель: союзный фургон, если метим в него, иначе фура
	var anchor: Node3D = truck
	if ally != null and is_instance_valid(ally) and not ally.is_dead:
		anchor = ally
	var target_pos: Vector3 = anchor.global_position + attack_offset
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


## Разгонный таран: босс откатывается назад, потом врубается с силой ×2.2.
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
		_charge_mult = 2.0
		_attack_timer = 0.0   # удар сразу по прибытию
		_charge_timer = 5.5
	)


func _attack() -> void:
	if state == null or truck == null:
		return
	# Эскорт: эта пташка бьёт клиентский фургон
	if ally != null and is_instance_valid(ally) and not ally.is_dead:
		var dir2 := signf(global_position.x - ally.global_position.x)
		if dir2 == 0.0:
			dir2 = 1.0
		var tw2 := create_tween()
		tw2.tween_property(self, "position:x", position.x - dir2 * 1.1, 0.12).set_ease(Tween.EASE_IN)
		tw2.tween_property(self, "position:x", position.x, 0.3).set_ease(Tween.EASE_OUT)
		ally.take_damage(maxi(int(round(attack_damage * _charge_mult)), 1))
		_charge_mult = 1.0
		return
	# Рывок-таран в сторону грузовика
	var dir := signf(global_position.x - truck.global_position.x)
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x - dir * 1.1, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:x", position.x, 0.3).set_ease(Tween.EASE_OUT)
	var dmg := int(round(attack_damage * _charge_mult * truck.ram_damage_multiplier()))
	_charge_mult = 1.0
	state.damage_truck(maxi(dmg, 1))
	# Диверсия: первый пробивший удар глушит орудия
	if sab and not _sab_done:
		_sab_done = true
		state.weapon_jam_requested.emit()
	# Шипы ранят атакующего
	if truck.upgrade_levels["spikes"] > 0:
		take_damage(3 * truck.upgrade_levels["spikes"], state)
