extends RefCounted
## Данные активных способностей экипажа: кулдауны, тексты, цвета.
## Новая способность: запись в DEFS + ветка в Abilities.try_activate().

const BARRAGE_DAMAGE := 60        # урон каждому врагу от «Залпа»
const SHIELD_DURATION := 5.0      # секунд неуязвимости от «Щита»
const NITRO_DURATION := 3.0       # секунд форсажа «Нитро»
const NITRO_SLOW := 0.25          # множитель скорости врагов под «Нитро»
const NITRO_SLOW_TIME := 3.5      # длительность замедления врагов
const NITRO_WORLD_BOOST := 1.7    # ускорение скролла мира под «Нитро»
const MAGNET_DURATION := 10.0     # секунд работы «Хламного магнита»
const MAGNET_BONUS := 1.5         # множитель лома под «Магнитом»
const LAST_STAND_DURATION := 6.0  # секунд «Последнего рубежа»
const LAST_STAND_MULT := 2.0      # множитель темпа орудий

const DEFS := {
	"barrage": {
		"name": "Залп",
		"icon": "🚀",
		"desc": "Ракеты по всем врагам",
		"cooldown": 25.0,
		"color": Color(1.0, 0.6, 0.25),
	},
	"shield": {
		"name": "Щит",
		"icon": "🛡",
		"desc": "Арматурная клетка: фура неуязвима",
		"cooldown": 35.0,
		"color": Color(0.9, 0.75, 0.4),
	},
	"nitro": {
		"name": "Нитро",
		"icon": "🔥",
		"desc": "Форсаж: рейдеры резко отстают",
		"cooldown": 30.0,
		"color": Color(1.0, 0.5, 0.2),
	},
	# Легендарные: открываются навсегда ковкой трофеев (кузня в ангаре)
	"magnet": {
		"name": "Магнит",
		"icon": "🧲",
		"desc": "Хламный магнит: +50% лома за всё 10 сек (легендарная)",
		"cooldown": 40.0,
		"color": Color(0.55, 0.75, 1.0),
		"legendary": true,
	},
	"last_stand": {
		"name": "Последний рубеж",
		"icon": "🪓",
		"desc": "Темп всех орудий ×2 на 6 сек (легендарная)",
		"cooldown": 60.0,
		"color": Color(1.0, 0.35, 0.3),
		"legendary": true,
	},
}
