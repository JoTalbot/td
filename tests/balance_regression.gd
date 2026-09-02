extends SceneTree
## Регрессия баланса 2.5: детерминированные формулы не должны ломать темп прогрессии.
## Это не заменяет 20 реальных рейсов из docs/BALANCE_2.5.md.

const MAX_NETWORK_BONUS := 1.10

func _initialize() -> void:
	var failures: Array[String] = []
	var previous_reward := 0
	for wave in range(1, 16):
		var reward := _wave_reward(wave, 1.0, 1.0, 0)
		_check(failures, "wave %d reward grows" % wave, reward > previous_reward)
		_check(failures, "wave %d reward is finite" % wave, reward > 0 and reward < 10000)
		previous_reward = reward

	_check(failures, "danger increases reward", _wave_reward(10, 1.5, 1.0, 0) > _wave_reward(10, 1.0, 1.0, 0))
	_check(failures, "network cap is bounded", MAX_NETWORK_BONUS <= 1.10)
	_check(failures, "engine bonus is monotonic", _wave_reward(10, 1.0, 1.50, 0) > _wave_reward(10, 1.0, 1.25, 0))
	_check(failures, "engine bonus remains bounded", _wave_reward(15, 1.0, 2.0, 0) < 10000)

	var boss_hp_5 := _boss_hp(5, 1.0, 1.0)
	var boss_hp_10 := _boss_hp(10, 1.0, 1.0)
	var boss_hp_15 := _boss_hp(15, 1.0, 1.0)
	_check(failures, "boss HP grows with wave", boss_hp_5 < boss_hp_10 and boss_hp_10 < boss_hp_15)
	_check(failures, "boss HP remains playable", boss_hp_15 < 10000)

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
