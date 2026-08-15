extends RefCounted
## Данные активных способностей экипажа: кулдауны, тексты, цвета.
## Новая способность: запись в DEFS + ветка в Abilities.try_activate().

const BARRAGE_DAMAGE := 60        # урон каждому врагу от «Залпа»
const SHIELD_DURATION := 5.0      # секунд неуязвимости от «Щита»
const NITRO_DURATION := 3.0       # секунд форсажа «Нитро»
const NITRO_SLOW := 0.25          # множитель скорости врагов под «Нитро»
const NITRO_SLOW_TIME := 3.5      # длительность замедления врагов
const NITRO_WORLD_BOOST := 1.7    # ускорение скролла мира под «Нитро»

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
}
