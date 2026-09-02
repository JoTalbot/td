extends SceneTree
## Регрессионные проверки кампании: детерминированные правила войны и экономики.

const Campaign := preload("res://scripts/Campaign.gd")
const CampaignData := preload("res://scripts/CampaignData.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var c := Campaign.new()
	c.day_seed = 20400

	_check(c, failures, "route key is canonical", CampaignData.route_key("citadel", "gasgrad") == CampaignData.route_key("gasgrad", "citadel"))
	_check(c, failures, "mastery reward level 0", is_equal_approx(c.route_mastery_reward_mult("citadel", "gasgrad"), 1.0))
	c.route_mastery[CampaignData.route_key("citadel", "gasgrad")] = 6
	_check(c, failures, "mastery caps at level 3", c.route_mastery_level("citadel", "gasgrad") == 3)
	_check(c, failures, "mastery danger reduction", is_equal_approx(c.route_mastery_danger_mult("citadel", "gasgrad"), 0.85))

	c.route_control["citadel|gasgrad"] = "bonewall"
	c.route_control_age["citadel|gasgrad"] = 2
	_check(c, failures, "commander appears after hold days", c.route_commander("citadel", "gasgrad") == "bonepriest")
	c.route_control_age["citadel|gasgrad"] = 1
	_check(c, failures, "commander gated before hold days", c.route_commander("citadel", "gasgrad") == "")

	_check(c, failures, "deadly route threshold", CampaignData.route_is_deadly("citadel", "salttown"))
	_check(c, failures, "caravan route flag", CampaignData.route_is_caravan("citadel", "bartertown"))
	_check(c, failures, "season founding", CampaignData.season_for(8, 16) == "founding")
	_check(c, failures, "season witch night wrap", CampaignData.season_for(10, 31) == "witch_night")

	if failures.is_empty():
		print("CAMPAIGN REGRESSION: PASS")
		quit(0)
		return
	print("CAMPAIGN REGRESSION: FAIL")
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
	return

func _check(_campaign: Node, failures: Array[String], name: String, condition: bool) -> void:
	if not condition:
		failures.append(name)

func is_equal_approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
