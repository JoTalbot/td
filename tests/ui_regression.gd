extends SceneTree
## Лёгкая headless-проверка UI и критических ресурсов.
## Пиксели не сравниваем: проверяем ресурсы и синтаксис ключевых скриптов.

const REQUIRED_FILES := [
	"res://scripts/Main.gd",
	"res://scripts/Campaign.gd",
	"res://scripts/CampaignData.gd",
	"res://scripts/MapScreen.gd",
	"res://scripts/HUD.gd",
	"res://scripts/Truck.gd",
	"res://assets/ui/map_bg.jpg",
]

const PARSE_SCRIPTS := [
	"res://scripts/Main.gd",
	"res://scripts/Campaign.gd",
	"res://scripts/CampaignData.gd",
	"res://scripts/MapScreen.gd",
	"res://scripts/HUD.gd",
	"res://scripts/Truck.gd",
	"res://scripts/WaveManager.gd",
	"res://scripts/NetworkRewards.gd",
	"res://scripts/RoadEvents.gd",
	"res://scripts/WeatherFX.gd",
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_FILES:
		if not ResourceLoader.exists(path):
			failures.append("missing: %s" % path)
	for path in PARSE_SCRIPTS:
		if not ResourceLoader.exists(path):
			failures.append("missing script: %s" % path)
			continue
		var script = load(path)
		if script == null:
			failures.append("parse/load failed: %s" % path)
	if not failures.is_empty():
		print("UI RESOURCE REGRESSION: FAIL")
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
		return
	print("UI RESOURCE REGRESSION: PASS (%d resources, %d scripts parsed)" % [REQUIRED_FILES.size(), PARSE_SCRIPTS.size()])
	quit(0)
