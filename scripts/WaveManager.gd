extends Node
## Волны рейдеров: подъезжают сзади и с боков, боссы каждые 5 волн.

signal wave_started(index: int)
signal wave_cleared(index: int)

const EnemyScript := preload("res://scripts/Enemy.gd")

var truck: Node3D
var state: Node

var wave_index := 0
var enemies_alive := 0
var spawning := false
var between_waves := true
var countdown := 5.0

var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _side_toggle := 1.0

const TYPES := {
	"buggy": {"hp": 40, "speed": 9.0, "reward": 9, "dmg": 4, "interval": 1.6},
	"biker": {"hp": 24, "speed": 13.0, "reward": 11, "dmg": 3, "interval": 1.1},
	"ram":   {"hp": 120, "speed": 7.0, "reward": 18, "dmg": 9, "interval": 2.2},
}


func start() -> void:
	between_waves = true
	countdown = 5.0


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
			_spawn_timer = maxf(1.3 - wave_index * 0.05, 0.6)
		if _spawn_queue.is_empty():
			spawning = false
	elif enemies_alive <= 0:
		wave_cleared.emit(wave_index)
		var bonus := 25 + wave_index * 6
		if truck.upgrade_levels["engine"] > 0:
			bonus = int(bonus * (1.0 + 0.25 * truck.upgrade_levels["engine"]))
		state.earn(bonus)
		between_waves = true
		countdown = 8.0


func _launch_wave() -> void:
	wave_index += 1
	between_waves = false
	spawning = true
	_spawn_timer = 0.5
	_spawn_queue.clear()

	var count := 4 + wave_index
	var hp_scale := 1.0 + (wave_index - 1) * 0.2
	for i in count:
		var t := "buggy"
		if wave_index >= 2 and i % 3 == 1:
			t = "biker"
		if wave_index >= 4 and i % 4 == 2:
			t = "ram"
		_spawn_queue.append({"type": t, "hp_scale": hp_scale})
	if wave_index % 5 == 0:
		_spawn_queue.append({"type": "boss", "hp_scale": hp_scale})
	wave_started.emit(wave_index)


func _spawn(data: Dictionary) -> void:
	var enemy: Node3D = EnemyScript.new()
	var t: String = data["type"]
	if t == "boss":
		enemy.enemy_type = "boss"
		enemy.is_boss = true
		enemy.max_hp = int(350 * data["hp_scale"])
		enemy.chase_speed = 6.5
		enemy.reward = 70
		enemy.attack_damage = 14
		enemy.attack_interval = 2.5
		enemy.attack_offset = Vector3(0, 0, -11.0)
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

	enemy.truck = truck
	enemy.state = state
	enemies_alive += 1
	enemy.died.connect(func(_r): enemies_alive -= 1)
	get_tree().current_scene.add_child(enemy)
	# Появляются сзади в клубах пыли, чуть сбоку
	enemy.global_position = truck.global_position + Vector3(enemy.attack_offset.x * 1.5, 0, -38.0)


func time_to_next_wave() -> float:
	return maxf(countdown, 0.0) if between_waves else -1.0
