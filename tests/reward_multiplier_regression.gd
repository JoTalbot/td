extends SceneTree
## Регрессия множителей награды: GameState должен применять мета-бонус и магнит
## ровно один раз к любому фактическому earn().

const GameStateScript := preload("res://scripts/GameState.gd")

func _initialize() -> void:
	var failures: Array[String] = []

	var base: Node = GameStateScript.new()
	base.earn(100)
	_check(failures, "base earn is exact", base.scrap == 250)
	base.free()

	var meta: Node = GameStateScript.new()
	meta.reward_mult = 1.25
	meta.earn(100)
	_check(failures, "meta reward multiplier applies once", meta.scrap == 275)
	meta.free()

	var magnet: Node = GameStateScript.new()
	magnet.reward_mult = 1.25
	magnet.loot_magnet = 10.0
	magnet.earn(100)
	_check(failures, "magnet and meta multipliers compose once", magnet.scrap == 338)
	magnet.free()

	if failures.is_empty():
		print("REWARD MULTIPLIER REGRESSION: PASS")
		quit(0)
		return
	print("REWARD MULTIPLIER REGRESSION: FAIL")
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
	return

func _check(failures: Array[String], name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)
