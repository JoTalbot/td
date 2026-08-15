extends RefCounted
class_name NeonTowerData
## Характеристики башен и уровней прокачки.

const DEFS := {
	"pulse": {
		"name": "Импульс",
		"cost": 60,
		"color": Color(0.2, 0.85, 1.0),
		"levels": [
			{"damage": 12, "range": 5.0, "fire_rate": 1.6, "upgrade": 45},
			{"damage": 20, "range": 5.6, "fire_rate": 1.9, "upgrade": 80},
			{"damage": 34, "range": 6.2, "fire_rate": 2.3, "upgrade": -1},
		],
	},
	"rail": {
		"name": "Рельсотрон",
		"cost": 110,
		"color": Color(1.0, 0.35, 0.75),
		"levels": [
			{"damage": 45, "range": 8.0, "fire_rate": 0.55, "upgrade": 90},
			{"damage": 80, "range": 8.8, "fire_rate": 0.65, "upgrade": 150},
			{"damage": 140, "range": 9.6, "fire_rate": 0.8, "upgrade": -1},
		],
	},
	"cryo": {
		"name": "Крио",
		"cost": 85,
		"color": Color(0.5, 0.6, 1.0),
		"levels": [
			{"damage": 6, "range": 4.5, "fire_rate": 1.2, "slow": 0.5, "upgrade": 70},
			{"damage": 10, "range": 5.0, "fire_rate": 1.4, "slow": 0.4, "upgrade": 120},
			{"damage": 16, "range": 5.5, "fire_rate": 1.6, "slow": 0.3, "upgrade": -1},
		],
	},
	"tesla": {
		"name": "Тесла",
		"cost": 140,
		"color": Color(1.0, 0.9, 0.2),
		"levels": [
			{"damage": 18, "range": 4.8, "fire_rate": 1.0, "chain": 3, "upgrade": 110},
			{"damage": 28, "range": 5.4, "fire_rate": 1.2, "chain": 4, "upgrade": 190},
			{"damage": 44, "range": 6.0, "fire_rate": 1.4, "chain": 5, "upgrade": -1},
		],
	},
}
