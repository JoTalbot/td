extends SceneTree
## Регрессия связной сети дорог: бонус ограничен и зависит только от контроля.

const NetworkRewards := preload("res://scripts/NetworkRewards.gd")

func _initialize() -> void:
	var routes: Array = [
		["citadel", "gasgrad"],
		["gasgrad", "bartertown"],
		["bartertown", "bulletfarm"],
		["rusthaven", "salttown"],
	]
	var control := {
		"citadel|gasgrad": "citadel",
		"bartertown|gasgrad": "citadel",
		"bartertown|bulletfarm": "citadel",
		"rusthaven|salttown": "rusthaven",
	}
	var failures: Array[String] = []
	var single_control := {"citadel|gasgrad": "citadel"}
	_check(failures, "single controlled route has no bonus", is_equal_approx(NetworkRewards.multiplier(single_control, routes, "citadel", "gasgrad"), 1.0))
	_check(failures, "connected network grows bonus", is_equal_approx(NetworkRewards.multiplier(control, routes, "gasgrad", "bartertown"), 1.04))
	var expanded_routes: Array = routes + [
		["bulletfarm", "salttown"],
		["salttown", "copperpit"],
		["copperpit", "crowsnest"],
		["crowsnest", "gasgrad"],
	]
	var expanded_control := control.duplicate()
	for route in expanded_routes.slice(routes.size()):
		expanded_control[NetworkRewards._route_key(String(route[0]), String(route[1]))] = "citadel"
	_check(failures, "bonus is capped", is_equal_approx(NetworkRewards.multiplier(expanded_control, expanded_routes, "citadel", "gasgrad"), 1.10))
	_check(failures, "other faction does not leak bonus", is_equal_approx(NetworkRewards.multiplier(control, routes, "rusthaven", "salttown"), 1.0))
	if failures.is_empty():
		print("NETWORK REGRESSION: PASS")
		quit(0)
		return
	print("NETWORK REGRESSION: FAIL")
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
	return

func _check(failures: Array[String], name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)

func is_equal_approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
