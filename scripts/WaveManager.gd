extends Node
## Волны рейдеров: подъезжают сзади и с боков, боссы каждые 5 волн.

signal wave_started(index: int)
signal wave_cleared(index: int)
## Сообщения от боссов (смена фаз, появление босса) — для HUD.
signal boss_event(text: String)
## Рейс пройден: доехали до города (волны маршрута кончились).
signal run_completed
## Любой враг убит — для контрактов-баунти и лута.
signal enemy_killed(type: String)

const EnemyScript := preload("res://scripts/Enemy.gd")
const CopterScript := preload("res://scripts/RaiderCopter.gd")

var truck: Node3D
var state: Node

var wave_index := 0
var enemies_alive := 0
var bosses_down := 0
## false, пока идёт экран карты; рейс запускается start().
var active := false
## Сколько волн до города; -1 — бесконечная классика.
var run_length := -1
## Множитель опасности маршрута (цифра дороги с карты).
var danger := 1.0
## Множитель награды за волну (теха «Конвойные схемы», дневной «Караван»).
var bonus_mult := 1.0
## Добавочные враги на волну (дневной мод «Караван»).
var extra_count := 0
## Союзный фургон эскорта: часть рейдеров целится в него. null — эскорта нет.
var ally: Node3D = null
## Сезон «Ночь Ведьм»: автожиры каждые N волн. 0 — отключено.
var ambush_every := 0
var spawning := false
var between_waves := true
var countdown := 5.0

var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _side_toggle := 1.0
var _train_cars: Array = []   # живые единицы военного поезда (для «фазы отцепки»)

const TYPES := {
	"buggy": {"hp": 40, "speed": 9.0, "reward": 9, "dmg": 4, "interval": 1.6},
	"biker": {"hp": 24, "speed": 13.0, "reward": 11, "dmg": 3, "interval": 1.1},
	"ram":   {"hp": 120, "speed": 7.0, "reward": 18, "dmg": 9, "interval": 2.2},
	# Военный поезд (каждая 15-я волна): локомотив толкает сцеп вагонов в хвост фуры
	"trainloko": {"hp": 230, "speed": 8.5, "reward": 60, "dmg": 10, "interval": 2.1},
	"traincar":  {"hp": 110, "speed": 8.5, "reward": 26, "dmg": 5,  "interval": 2.0},
}


func start() -> void:
	active = true
	between_waves = true
	countdown = 5.0


func _process(delta: float) -> void:
	if not active or state.is_game_over:
		return
	if between_waves:
		countdown -= delta
		if countdown <= 0.0:
			_launch_wave()
		return
	if spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
			_spawn(_spawn_queue.pop_front())
			_spawn_timer = maxf(1.3 - wave_index * 0.05, 0.6)
		if _spawn_queue.is_empty():
			spawning = false
	elif enemies_alive <= 0:
		wave_cleared.emit(wave_index)
		var bonus := int((25 + wave_index * 6) * danger * bonus_mult)
		if truck.upgrade_levels["engine"] > 0:
			bonus = int(bonus * (1.0 + 0.25 * truck.upgrade_levels["engine"]))
		state.earn(bonus)
		# Конец маршрута — город у горизонта
		if run_length > 0 and wave_index >= run_length:
			active = false
			run_completed.emit()
			return
		between_waves = true
		countdown = 8.0


func _launch_wave() -> void:
	wave_index += 1
	between_waves = false
	spawning = true
	_spawn_timer = 0.5
	_spawn_queue.clear()

	var count := 4 + wave_index + int((danger - 1.0) * 3.0) + extra_count
	var hp_scale := (1.0 + (wave_index - 1) * 0.2) * danger
	for i in count:
		var t := "buggy"
		if wave_index >= 2 and i % 3 == 1:
			t = "biker"
		if wave_index >= 4 and i % 4 == 2:
			t = "ram"
		_spawn_queue.append({"type": t, "hp_scale": hp_scale})
	if wave_index % 5 == 0:
		if wave_index % 15 == 0:
			# Каждая пятнадцатая — Военный Поезд: локомотив + сцеп вагонов
			_train_cars.clear()
			var cars := 2 + int(wave_index / 30)
			_spawn_queue.append({"type": "trainloko", "hp_scale": hp_scale})
			for i in cars:
				_spawn_queue.append({"type": "traincar", "hp_scale": hp_scale})
			boss_event.emit("🚂 ВОЕННЫЙ ПОЕЗД! Разбейте каждый вагон!")
		elif wave_index % 10 == 0:
			# Каждая десятая волна — воздушный босс вместо тягача
			_spawn_queue.append({"type": "ace", "hp_scale": hp_scale})
			boss_event.emit("🚁 КОРСАР в небе! Берегите платформу!")
		else:
			_spawn_queue.append({"type": "boss", "hp_scale": hp_scale})
			boss_event.emit("☠ БОСС-ТЯГАЧ на горизонте!")
	# «Ночь Ведьм»: стая автожиров каждые N волн (волну не блокируют)
	if ambush_every > 0 and wave_index % ambush_every == 2:
		_on_ace_escort(2)
		boss_event.emit("🎃 Стая автожиров в ночном небе!")
	wave_started.emit(wave_index)


func _spawn(data: Dictionary) -> void:
	var t: String = data["type"]
	if t == "ace":
		_spawn_ace(data)
		return
	var enemy: Node3D = EnemyScript.new()
	if t == "boss":
		enemy.enemy_type = "boss"
		enemy.is_boss = true
		enemy.max_hp = int(350 * data["hp_scale"])
		enemy.chase_speed = 6.5
		enemy.reward = 70
		enemy.attack_damage = 14
		enemy.attack_interval = 2.5
		enemy.attack_offset = Vector3(0, 0, -11.0)
		enemy.phase_announced.connect(func(text: String): boss_event.emit(text))
		enemy.spawn_minions.connect(_on_boss_spawn_minions)
		enemy.died.connect(func(_r): bosses_down += 1)
	else:
		var tpl: Dictionary = TYPES[t]
		enemy.enemy_type = t
		enemy.max_hp = int(tpl["hp"] * data["hp_scale"])
		enemy.chase_speed = tpl["speed"]
		enemy.reward = tpl["reward"]
		enemy.attack_damage = tpl["dmg"]
		enemy.attack_interval = tpl["interval"]
		_side_toggle *= -1.0
		var lane := 3.6 + randf() * 1.6
		var depth := randf_range(-3.5, 3.0)
		enemy.attack_offset = Vector3(_side_toggle * lane, 0, depth)
		# Эскорт: треть рейдеров валом валит на клиентский фургон
		if ally != null and is_instance_valid(ally) and not ally.is_dead and randf() < 0.35:
			enemy.ally = ally
			enemy.attack_offset = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		# Военный поезд: сцеп выстраивается в хвост фуры, вагоны связаны отцепкой
		if t == "trainloko" or t == "traincar":
			enemy.attack_offset = Vector3(_side_toggle * randf_range(0.6, 1.6), 0, -4.5 - _train_cars.size() * 3.4)
			_train_cars.append(enemy)
			enemy.died.connect(func(_r): _on_train_car_died(enemy))

	enemy.truck = truck
	enemy.state = state
	enemies_alive += 1
	enemy.died.connect(func(_r):
		enemies_alive -= 1
		enemy_killed.emit(enemy.enemy_type))
	get_tree().current_scene.add_child(enemy)
	# Появляются сзади в клубах пыли, чуть сбоку
	enemy.global_position = truck.global_position + Vector3(enemy.attack_offset.x * 1.5, 0, -38.0)


## Корсар: воздушный босс. Часть волны — считается в enemies_alive.
func _spawn_ace(data: Dictionary) -> void:
	var ace: Node3D = CopterScript.new()
	ace.is_ace = true
	ace.max_hp = int(300 * data["hp_scale"])
	ace.reward = 110
	ace.bomb_damage = 10
	ace.crash_damage = 24
	ace.bombs_total = 5
	ace.truck = truck
	ace.state = state
	enemies_alive += 1
	ace.died.connect(func(_r):
		enemies_alive -= 1
		bosses_down += 1
		enemy_killed.emit("ace"))
	ace.phase_announced.connect(func(text: String): boss_event.emit(text))
	ace.spawn_minions.connect(_on_ace_escort)
	get_tree().current_scene.add_child(ace)
	ace.scale = Vector3.ONE * 1.5
	ace.global_position = truck.global_position + Vector3(0, 15.0, -28.0)


## Корсар зовёт два обычных автожира эскортом (волну не блокируют).
func _on_ace_escort(count: int) -> void:
	for i in count:
		var c: Node3D = CopterScript.new()
		c.truck = truck
		c.state = state
		# Эскорт не блокирует волну, но сбитый автожир — добыча
		c.died.connect(func(_r): enemy_killed.emit("copter"))
		get_tree().current_scene.add_child(c)
		c.global_position = truck.global_position + Vector3(-4.0 + i * 8.0, 14.0, -24.0)


## Вагон поезда отцеплён: остаток сцепа наддаёт ходу (+22% скорости).
func _on_train_car_died(car: Node3D) -> void:
	_train_cars.erase(car)
	var alive_train := false
	for c in _train_cars:
		if is_instance_valid(c) and not c.is_dying:
			alive_train = true
			c.chase_speed *= 1.22
	if alive_train:
		boss_event.emit("🚂 Вагон отцеплён — поезд наддал ходу!")


## Босс в отчаянии зовёт байкеров на подмогу.
func _on_boss_spawn_minions(count: int) -> void:
	var hp_scale := (1.0 + (wave_index - 1) * 0.2) * danger
	for i in count:
		_spawn({"type": "biker", "hp_scale": hp_scale})


func time_to_next_wave() -> float:
	return maxf(countdown, 0.0) if between_waves else -1.0
