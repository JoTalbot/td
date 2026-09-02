extends SceneTree
## Регрессия баланса 2.5: детерминированные формулы не должны ломать темп прогрессии.
## Это не заменяет 20 реальных рейсов из docs/BALANCE_2.5.md.

const WaveManagerScript := preload("res://scripts/WaveManager.gd")
const MAX_NETWORK_BONUS := 1.10

class StubTruck extends Node3D:
	var upgrade_levels: Dictionary = {"engine": 0}

class StubState extends Node:
	var is_game_over := false
	var earned := 0

	func earn(value: int) -> void:
		earned = value

func _initialize() -> void:
	var failures: Array[String] = []
	var previous_reward := 0
	for wave in range(1, 16):
		var reward := _wave_reward(wave, 1.0, 1.0, 1.0)
		_check(failures, "wave %d reward grows" % wave, reward > previous_reward)
		_check(failures, "wave %d reward is finite" % wave, reward > 0 and reward < 10000)
		previous_reward = reward

	_check(failures, "danger increases reward", _wave_reward(10, 1.5, 1.0, 1.0) > _wave_reward(10, 1.0, 1.0, 1.0))
	_check(failures, "network cap is bounded", MAX_NETWORK_BONUS <= 1.10)
	_check(failures, "engine bonus is monotonic", _wave_reward(10, 1.0, 1.50, 1.0) > _wave_reward(10, 1.0, 1.25, 1.0))
	_check(failures, "engine bonus remains bounded", _wave_reward(15, 1.0, 2.0, 1.0) < 10000)

	var boss_hp_5 := _boss_hp(5, 1.0, 1.0)
	var boss_hp_10 := _boss_hp(10, 1.0, 1.0)
	var boss_hp_15 := _boss_hp(15, 1.0, 1.0)
	_check(failures, "boss HP grows with wave", boss_hp_5 < boss_hp_10 and boss_hp_10 < boss_hp_15)
	_check(failures, "boss HP remains playable", boss_hp_15 < 10000)

	# Exercise the real WaveManager reward path instead of only checking a copy
	# of the formula. This catches future drift in _process().
	var live_waves: Node = WaveManagerScript.new()
	var live_truck := StubTruck.new()
	var live_state := StubState.new()
	live_waves.truck = live_truck
	live_waves.state = live_state
	live_waves.wave_index = 10
	live_waves.danger = 1.25
	live_waves.bonus_mult = 1.08
	live_waves.between_waves = false
	live_waves.spawning = false
	live_waves.enemies_alive = 0
	live_waves._process(0.0)
	var expected_live_reward := _wave_reward(10, 1.25, 1.0, 1.08)
	_check(failures, "live WaveManager reward matches formula", live_state.earned == expected_live_reward)
	live_waves.free()
	live_truck.free()
	live_state.free()

	# start() is called again for every campaign route. Verify that no per-run
	# wave state leaks into the next route.
	var waves: Node = WaveManagerScript.new()
	waves.wave_index = 12
	waves.enemies_alive = 4
	waves.bosses_down = 3
	waves.spawning = true
	waves.countdown = 0.0
	waves._spawn_timer = 2.0
	waves._side_toggle = -1.0
	waves._spawned_count = 7
	waves._hp_scale = 3.4
	waves._treasurer_spawned = true
	waves.start()
	_check(failures, "new run resets wave index", waves.wave_index == 0)
	_check(failures, "new run resets live enemy count", waves.enemies_alive == 0)
	_check(failures, "new run resets boss counter", waves.bosses_down == 0)
	_check(failures, "new run resets spawning state", not waves.spawning)
	_check(failures, "new run resets countdown", is_equal_approx(waves.countdown, 5.0))
	_check(failures, "new run resets treasurer state", not waves._treasurer_spawned)
	_check(failures, "new run resets flank counter", waves._spawned_count == 0)
	_check(failures, "new run resets HP scale", is_equal_approx(waves._hp_scale, 1.0))
	waves.free()

	if failures.is_empty():
		print("BALANCE REGRESSION: PASS")
		quit(0)
		return
	print("BALANCE REGRESSION: FAIL")
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
	return

func _wave_reward(wave: int, danger: float, engine_mult: float, bonus_mult: float) -> int:
	var bonus := int((25 + wave * 6) * danger * bonus_mult)
	if engine_mult > 1.0:
		bonus = int(bonus * engine_mult)
	return bonus

func _boss_hp(wave: int, danger: float, boss_mult: float) -> int:
	return int(300.0 * (1.0 + (wave - 1) * 0.15) * danger * boss_mult)

func _check(failures: Array[String], name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)
