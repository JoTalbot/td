extends Node
## Генерация волн: масштабирование сложности, типы врагов, боссы каждые 5 волн.

signal wave_started(index: int)
signal wave_cleared(index: int)

const EnemyScript := preload("res://scripts/Enemy.gd")

var board: Node3D
var state: Node

var wave_index := 0
var enemies_alive := 0
var spawning := false
var between_waves := true
var countdown := 4.0

var _spawn_queue: Array = []
var _spawn_timer := 0.0

const ENEMY_TYPES := [
	{"hp": 45, "speed": 3.0, "reward": 8, "color": Color(1.0, 0.35, 0.3), "dmg": 1},
	{"hp": 30, "speed": 4.6, "reward": 10, "color": Color(0.3, 1.0, 0.5), "dmg": 1},
	{"hp": 110, "speed": 2.1, "reward": 16, "color": Color(0.9, 0.5, 1.0), "dmg": 2},
]


func start() -> void:
	between_waves = true
	countdown = 4.0


func _process(delta: float) -> void:
	if state.is_game_over:
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
			_spawn_timer = 0.7 if wave_index < 8 else 0.5
		if _spawn_queue.is_empty():
			spawning = false
	elif enemies_alive <= 0:
		wave_cleared.emit(wave_index)
		state.earn(30 + wave_index * 5)
		between_waves = true
		countdown = 6.0


func _launch_wave() -> void:
	wave_index += 1
	between_waves = false
	spawning = true
	_spawn_timer = 0.0
	_spawn_queue.clear()

	var count := 6 + wave_index * 2
	var hp_scale := 1.0 + (wave_index - 1) * 0.22
	for i in count:
		var tpl: Dictionary = ENEMY_TYPES[0]
		if wave_index >= 3 and i % 3 == 1:
			tpl = ENEMY_TYPES[1]
		if wave_index >= 5 and i % 4 == 2:
			tpl = ENEMY_TYPES[2]
		_spawn_queue.append({
			"hp": int(tpl["hp"] * hp_scale),
			"speed": tpl["speed"],
			"reward": tpl["reward"],
			"color": tpl["color"],
			"dmg": tpl["dmg"],
			"boss": false,
		})

	if wave_index % 5 == 0:
		_spawn_queue.append({
			"hp": int(400 * hp_scale),
			"speed": 1.6,
			"reward": 80,
			"color": Color(1.0, 0.8, 0.1),
			"dmg": 5,
			"boss": true,
		})

	wave_started.emit(wave_index)


func _spawn(data: Dictionary) -> void:
	var enemy: Node3D = EnemyScript.new()
	enemy.max_hp = data["hp"]
	enemy.base_speed = data["speed"]
	enemy.reward = data["reward"]
	enemy.enemy_color = data["color"]
	enemy.damage_to_base = data["dmg"]
	enemy.is_boss = data["boss"]
	enemy.path = board.path_points
	enemies_alive += 1
	enemy.died.connect(func(_r): enemies_alive -= 1)
	enemy.reached_base.connect(func():
		enemies_alive -= 1
		state.lose_life(data["dmg"])
	)
	get_tree().current_scene.add_child(enemy)


func time_to_next_wave() -> float:
	return maxf(countdown, 0.0) if between_waves else -1.0
