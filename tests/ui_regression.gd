extends SceneTree
## Lightweight headless UI/resource regression checks.
## Не рендерит пиксели: проверяет, что критические сцены и ассеты не исчезли из сборки.

const REQUIRED_FILES := [
	"res://project.godot",
	"res://scripts/Main.gd",
	"res://scripts/Campaign.gd",
	"res://scripts/CampaignData.gd",
	"res://scripts/MapScreen.gd",
	"res://scripts/HUD.gd",
	"res://scripts/Truck.gd",
	"res://assets/ui/map_bg.jpg",
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_FILES:
		if not ResourceLoader.exists(path):
			failures.append(path)
	if not failures.is_empty():
		print("UI RESOURCE REGRESSION: FAIL")
		for path in failures:
			print(" - missing: %s" % path)
		quit(1)
		return
	print("UI RESOURCE REGRESSION: PASS (%d critical resources)" % REQUIRED_FILES.size())
	quit(0)
