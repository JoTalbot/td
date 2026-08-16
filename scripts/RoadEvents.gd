extends Node
## Случайные дорожные события: песчаная буря, мины за борт, сброс припасов.
## Срабатывают по таймеру, пока идёт игра; анонсы улетают в HUD.

signal announced(text: String)
## Встреча на трассе в перерыве между волнами: HUD рисует модалку с вариантами.
## options: [{label: String, cb: Callable}]
signal encounter(title: String, desc: String, options: Array)

const Junk := preload("res://scripts/Junk.gd")
const Copter := preload("res://scripts/RaiderCopter.gd")

var state: Node
var truck: Node3D
var wasteland: Node
var env: Environment = null
## Ссылка на менеджер волн: события живут только в рейсе.
var waves: Node = null

## Паузы между событиями (сек)
const FIRST_EVENT_MIN := 18.0
const FIRST_EVENT_MAX := 30.0
const EVENT_GAP_MIN := 28.0
const EVENT_GAP_MAX := 46.0
const STORM_DURATION := 9.0
const STORM_RANGE_MULT := 0.55     # дальность орудий в бурю
const STORM_FOG := 0.03            # плотность тумана в бурю
const MINE_DAMAGE := 55
const MINE_COUNT := 3
const SUPPLY_HEAL := 12.0

var _timer := 0.0
var _storm_timer := 0.0
var _storm_dust: GPUParticles3D = null
var _base_fog_density := 0.008
var _base_fog_color := Color(0.87, 0.72, 0.5)
var _rng := RandomNumberGenerator.new()

## Встречи на трассе: шанс в каждом перерыве между волнами, не чаще 3 за рейс.
const ENCOUNTER_CHANCE := 0.45
const ENCOUNTER_MAX_PER_RUN := 3
var _was_between := false
var _encounters_done := 0

## Караванный тракт: первое событие рейса гарантированно — сброс припасов.
var caravan_run := false
var _caravan_supply_pending := false


## Main вызывает при старте рейса по караванному тракту.
func set_caravan_run(on: bool) -> void:
	caravan_run = on
	_caravan_supply_pending = on


func setup(p_state: Node, p_truck: Node3D, p_wasteland: Node, p_env: Environment) -> void:
	state = p_state
	truck = p_truck
	wasteland = p_wasteland
	env = p_env
	_rng.seed = randi()
	if env != null:
		_base_fog_density = env.fog_density
		_base_fog_color = env.fog_light_color
	_timer = _rng.randf_range(FIRST_EVENT_MIN, FIRST_EVENT_MAX)


func _process(delta: float) -> void:
	if state == null or truck == null or state.is_game_over:
		return
	if waves != null and not waves.active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(EVENT_GAP_MIN, EVENT_GAP_MAX)
		if _caravan_supply_pending:
			# Караванный тракт: конвой сбрасывает ящики гарантированно и первым
			_caravan_supply_pending = false
			trigger("supply")
		else:
			trigger(_pick_event())
	if _storm_timer > 0.0:
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_end_storm()
	# Встречи на трассе — на фронте «волна закончилась»
	var between: bool = waves != null and waves.active and waves.between_waves and not state.is_game_over
	if between and not _was_between:
		_maybe_encounter()
	_was_between = between


func _pick_event() -> String:
	var ids := ["storm", "mines", "supply", "ambush"]
	return ids[_rng.randi() % ids.size()]


## --- Встречи на трассе (перерывы между волнами) ---

## Дёргается на фронте «волна кончилась»; дальше — шанс и лимит на рейс.
func _maybe_encounter() -> void:
	if _encounters_done >= ENCOUNTER_MAX_PER_RUN:
		return
	if waves != null and waves.wave_index < 2:
		return
	if _rng.randf() > ENCOUNTER_CHANCE:
		return
	_encounters_done += 1
	match _rng.randi_range(0, 2):
		0:
			_encounter_trader()
		1:
			_encounter_blockade()
		_:
			_encounter_pilgrim()


## Кочующий торговец: ремонт или боевую смесь за лом.
func _encounter_trader() -> void:
	var opts: Array = [
		{"label": "Починка +30% HP — ⚙35", "cb": func() -> void:
			if state.spend(35):
				state.heal(float(state.max_hp) * 0.3)
				announced.emit("🛠 Торговец латанул броню!")},
		{"label": "Топсмесь +10% урона — ⚙45", "cb": func() -> void:
			if state.spend(45):
				state.damage_mult *= 1.1
				announced.emit("🔥 Топливо с душой: +10% урона до города!")},
		{"label": "Уйти", "cb": func() -> void: pass},
	]
	encounter.emit("🚐 Кочующий торговец",
		"Дымящийся фургон притормозил рядом. Хозяин стучит по борту: «Железо, микстуры — всё за лом, только быстро!»",
		opts)


## Блокпост в колее: принять жирную волну или объехать стороной.
func _encounter_blockade() -> void:
	var opts: Array = [
		{"label": "На таран! (+4 рейдера, награда ×1.35)", "cb": func() -> void:
			if waves != null:
				waves.extra_count += 4
				waves.bonus_mult *= 1.35
			announced.emit("⚔ Засада принята: следующая волна жирнее!")},
		{"label": "Объехать стороной", "cb": func() -> void: pass},
	]
	encounter.emit("🚧 Блокпост в колее",
		"Впереди свежий блокпост рейдеров: спицы, бочки, чужие флаги. Можно взять их на таран — или свернуть в пыль.",
		opts)


## Паломник пустоши: бескорыстный дар воды и лома.
func _encounter_pilgrim() -> void:
	state.heal(float(state.max_hp) * 0.15)
	var gift := _rng.randi_range(15, 30)
	state.earn(gift)
	announced.emit("🙏 Паломник поделился водой: +15% HP и ⚙%d" % gift)


func trigger(id: String) -> void:
	match id:
		"storm":
			_do_storm()
		"mines":
			_do_mines()
		"supply":
			_do_supply()
		"ambush":
			_do_ambush()
		"bonefall":
			state.damage_truck(12)
			announced.emit("КОСТЯНАЯ ГРЯДА: обвал рёбер! Броня принимает 12 урона.")
		"cavein":
			_do_mines()
			announced.emit("МЕДНЫЙ РАЗЛОМ: шахтный взрыв выбросил мины на дорогу!")
		"ore_cache":
			state.earn(90)
			state.heal(8.0)
			announced.emit("ШАХТЁРСКИЙ КАРАВАН: найден ящик руды — +90 лома, +8 HP!")
		"salt_fog":
			_do_storm()
			announced.emit("БЕРЕГ МЁРТВЫХ СУДОВ: соляная мгла глушит прицелы!")
		"smoke_ambush":
			_do_ambush()
			announced.emit("ЧЁРНЫЙ ДЫМ: автожиры вышли из копоти!")
		"caravan_toll":
			if state.spend(20):
				if waves != null:
					waves.bonus_mult *= 1.1
				announced.emit("СТАРЫЙ ТРАКТ: пошлина уплачена — награда за охрану выше!")
			else:
				if waves != null:
					waves.extra_count += 2
				announced.emit("СТАРЫЙ ТРАКТ: нечем платить — охрана идёт в бой!")


## Воздушная засада: автожиры рейдеров пикут с неба.
func _do_ambush() -> void:
	var count := 2 if _rng.randf() < 0.7 else 3
	for i in count:
		var copter: Node3D = Copter.new()
		copter.truck = truck
		copter.state = state
		if waves != null:
			# Сбитый автожир засады — добыча для ангара трофеев
			copter.died.connect(func(_r): waves.enemy_killed.emit("copter"))
		get_tree().current_scene.add_child(copter)
		# Впархивают сверху-сзади, немного вразброд
		copter.global_position = truck.global_position + Vector3(
			_rng.randf_range(-10.0, 10.0), 16.0 + _rng.randf_range(0, 3.0), -26.0 - i * 5.0)
	announced.emit("🚁 Воздушная засада: %d автожиров!" % count)


func _do_storm() -> void:
	# Песчаная буря: густая охристая дымка, орудиям режется дальность.
	state.weapon_range_mult = STORM_RANGE_MULT
	_storm_timer = STORM_DURATION
	if env != null:
		env.fog_density = STORM_FOG
		env.fog_light_color = Color(0.75, 0.55, 0.32)
	if _storm_dust != null:
		_storm_dust.queue_free()
	# Пыль валом из-под колёс на время бури
	_storm_dust = Junk.dust_trail(truck, Vector3(0, 0.4, -2.0), 90, 2.2)
	announced.emit("🌪 Песчаная буря! Дальность орудий -45%!")


func _end_storm() -> void:
	state.weapon_range_mult = 1.0
	if env != null:
		env.fog_density = _base_fog_density
		env.fog_light_color = _base_fog_color
	if _storm_dust != null:
		_storm_dust.queue_free()
		_storm_dust = null
	announced.emit("🌪 Буря стихла")


func _do_mines() -> void:
	# С платформы сбрасывают самодельные мины — катятся назад по колее.
	for i in MINE_COUNT:
		var mine := Mine.new()
		mine.damage = MINE_DAMAGE
		mine.setup(state, truck, wasteland)
		get_tree().current_scene.add_child(mine)
		mine.global_position = truck.global_position + Vector3(
			_rng.randf_range(-2.4, 2.4), 0.0, -7.0 - i * 4.0 - _rng.randf_range(0.0, 2.0))
	announced.emit("💣 Мины за борт: %d шт. по колее!" % MINE_COUNT)


func _do_supply() -> void:
	# Дружественный конвой кидает ящик припасов прямо на платформу.
	var scrap_gain := _rng.randi_range(45, 85)
	state.earn(scrap_gain)
	state.heal(SUPPLY_HEAL)
	announced.emit("📦 Сброс припасов: +%d лома, +%d HP!" % [scrap_gain, int(SUPPLY_HEAL)])
	# Ящик падает на платформу сверху, трясётся и растворяется
	var crate := Junk.box(truck, Vector3(0.7, 0.7, 0.7), Vector3(0.8, 16.0, -1.8), Junk.rust(_rng))
	Junk.box(crate, Vector3(0.76, 0.12, 0.76), Vector3.ZERO, Junk.metal(Color(0.35, 0.28, 0.2), 0.7, 0.6))
	var tw := crate.create_tween()
	tw.tween_property(crate, "position:y", 1.5, 1.0).set_ease(Tween.EASE_IN)
	tw.tween_property(crate, "position:y", 1.35, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(crate, "scale", Vector3.ZERO, 0.35)
	tw.tween_callback(crate.queue_free)


## Самодельная мина: лежит на дороге, катится назад со скоростью мира,
## взрывается, когда догоняющий рейдер на неё наезжает.
class Mine:
	extends Node3D

	const JunkF := preload("res://scripts/Junk.gd")
	const SCROLL_BASE := 22.0   # зеркалит Wasteland.SCROLL_SPEED

	var state: Node
	var truck: Node3D
	var wasteland: Node
	var damage := 55
	var _armed := false


	func setup(p_state: Node, p_truck: Node3D, p_wasteland: Node) -> void:
		state = p_state
		truck = p_truck
		wasteland = p_wasteland


	func _ready() -> void:
		# Диск с шипами и мигающей лампочкой-взводом
		JunkF.cyl(self, 0.34, 0.12, Vector3(0, 0.06, 0), JunkF.metal(Color(0.3, 0.25, 0.2), 0.7, 0.7))
		for i in 5:
			var a := TAU * i / 5.0
			JunkF.spike(self, 0.05, 0.2, Vector3(cos(a) * 0.22, 0.14, sin(a) * 0.22))
		var lamp := JunkF.box(self, Vector3(0.08, 0.06, 0.08), Vector3(0, 0.16, 0),
			JunkF.metal(Color(1.0, 0.6, 0.2), 0.4, 0.3))
		var lm := lamp.material_override as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.55, 0.15)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(lm, "emission_energy_multiplier", 0.3, 0.4)
		tw.tween_property(lm, "emission_energy_multiplier", 2.0, 0.4)
		# Взводится с задержкой — чтобы не грохнуть под самой фурой
		var arm := create_tween()
		arm.tween_interval(0.6)
		arm.tween_callback(func(): _armed = true)


	func _process(delta: float) -> void:
		if truck == null:
			queue_free()
			return
		# Мина «остаётся на месте»: относительно фуры катится назад
		var scale: float = wasteland.speed_scale if wasteland != null else 1.0
		position.z -= SCROLL_BASE * scale * delta
		if position.z < truck.global_position.z - 80.0:
			queue_free()
			return
		if not _armed:
			return
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_dying:
				continue
			var d: Vector3 = enemy.global_position - global_position
			d.y = 0.0
			if d.length() < 1.3:
				_detonate()
				return


	func _detonate() -> void:
		JunkF.explosion(get_tree().current_scene, global_position + Vector3.UP * 0.4, 1.3)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_dying:
				continue
			var d: Vector3 = enemy.global_position - global_position
			d.y = 0.0
			if d.length() < 2.4:
				enemy.take_damage(damage, state)
		queue_free()
