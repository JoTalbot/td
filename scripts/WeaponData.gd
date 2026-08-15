extends RefCounted
## Характеристики орудий, устанавливаемых на грузовик, и их уровней.

const DEFS := {
	"mgun": {
		"name": "Пулемёт",
		"cost": 50,
		"color": Color(1.0, 0.85, 0.45),
		"kind": "bullet",
		"levels": [
			{"damage": 6, "range": 14.0, "fire_rate": 3.2, "upgrade": 45},
			{"damage": 10, "range": 15.0, "fire_rate": 4.0, "upgrade": 80},
			{"damage": 16, "range": 16.0, "fire_rate": 5.0, "upgrade": -1},
		],
	},
	"flamer": {
		"name": "Огнемёт",
		"cost": 80,
		"color": Color(1.0, 0.45, 0.1),
		"kind": "flame",
		"levels": [
			{"damage": 4, "range": 8.0, "fire_rate": 7.0, "upgrade": 60},
			{"damage": 6, "range": 9.0, "fire_rate": 8.0, "upgrade": 110},
			{"damage": 9, "range": 10.0, "fire_rate": 9.0, "upgrade": -1},
		],
	},
	"harpoon": {
		"name": "Гарпун",
		"cost": 90,
		"color": Color(0.75, 0.8, 0.85),
		"kind": "harpoon",
		"levels": [
			{"damage": 12, "range": 17.0, "fire_rate": 0.8, "slow": 0.45, "upgrade": 70},
			{"damage": 20, "range": 18.0, "fire_rate": 0.95, "slow": 0.35, "upgrade": 130},
			{"damage": 32, "range": 19.0, "fire_rate": 1.1, "slow": 0.25, "upgrade": -1},
		],
	},
	"cannon": {
		"name": "Пушка",
		"cost": 130,
		"color": Color(0.95, 0.6, 0.3),
		"kind": "shell",
		"levels": [
			{"damage": 40, "range": 20.0, "fire_rate": 0.5, "splash": 3.0, "upgrade": 100},
			{"damage": 70, "range": 21.0, "fire_rate": 0.6, "splash": 3.5, "upgrade": 180},
			{"damage": 115, "range": 22.0, "fire_rate": 0.7, "splash": 4.0, "upgrade": -1},
		],
	},
	"tesla": {
		"name": "Тесла",
		"cost": 110,
		"color": Color(1.0, 0.88, 0.45),
		"kind": "zap",
		"levels": [
			{"damage": 9, "range": 12.0, "fire_rate": 1.1, "chain": 2, "upgrade": 100},
			{"damage": 15, "range": 13.0, "fire_rate": 1.3, "chain": 3, "upgrade": 190},
			{"damage": 24, "range": 14.0, "fire_rate": 1.5, "chain": 4, "upgrade": -1},
		],
	},
	"mortar": {
		"name": "Мортира",
		"cost": 160,
		"color": Color(0.9, 0.65, 0.3),
		"kind": "mortar",
		"levels": [
			{"damage": 48, "range": 19.0, "fire_rate": 0.4, "splash": 4.5, "upgrade": 130},
			{"damage": 80, "range": 20.0, "fire_rate": 0.48, "splash": 5.0, "upgrade": 240},
			{"damage": 130, "range": 21.0, "fire_rate": 0.55, "splash": 5.5, "upgrade": -1},
		],
	},
}
