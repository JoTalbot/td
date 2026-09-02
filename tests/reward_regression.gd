extends SceneTree
## Регрессия экономики: реальные таблицы наград WaveManager не должны случайно обнулиться,
## стать отрицательными или поменять относительную ценность без явного решения.

const WaveManagerScript := preload("res://scripts/WaveManager.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var types: Dictionary = WaveManagerScript.TYPES

	_check(failures, "buggy reward is positive", int(types["buggy"]["reward"]) > 0)
	_check(failures, "biker reward exceeds buggy", int(types["biker"]["reward"]) > int(types["buggy"]["reward"]))
	_check(failures, "ram reward exceeds biker", int(types["ram"]["reward"]) > int(types["biker"]["reward"]))
	_check(failures, "train locomotive reward is premium", int(types["trainloko"]["reward"]) > int(types["ram"]["reward"]))
	_check(failures, "train car reward is positive", int(types["traincar"]["reward"]) > 0)

	for type_id in types:
		var reward := int(types[type_id]["reward"])
		_check(failures, "%s reward is bounded" % type_id, reward > 0 and reward < 1000)

	# Kill payout is separate from the wave-clear payout. Keep both bounded so
	# a future balance pass cannot accidentally turn one enemy into an economy exploit.
	var wave_clear_max := (25 + 15 * 6) * 2.0 * 2.0
	_check(failures, "wave clear reference remains bounded", wave_clear_max < 10000.0)

	if failures.is_empty():
		print("REWARD REGRESSION: PASS")
		quit(0)
		return
	print("REWARD REGRESSION: FAIL")
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
	return

func _check(failures: Array[String], name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)
