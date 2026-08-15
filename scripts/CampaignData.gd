extends RefCounted
## Данные кампании: города пустоши, ресурсы, дороги.
## Кампания: карта → рейс (N волн по маршруту) → прибытие в город.

## Ресурсы: базовая цена в ломе.
const RESOURCES := {
	"metal": {"name": "Металл", "icon": "🔩", "price": 5},
	"fuel":  {"name": "Топливо", "icon": "🛢", "price": 12},
	"water": {"name": "Вода", "icon": "💧", "price": 8},
	"ammo":  {"name": "Свинец", "icon": "🔸", "price": 10},
	"food":  {"name": "Еда", "icon": "🥫", "price": 7},
	"chips": {"name": "Электроника", "icon": "📟", "price": 18},
}

## Города: позиция на карте (0..1), иконка, описание, ценовые модификаторы
## (<1 — тут дешевле, >1 — дороже) и флаг родной базы.
const CITIES := {
	"citadel": {
		"name": "Цитадель",
		"icon": "🏰",
		"pos": Vector2(0.50, 0.84),
		"desc": "Скала с водяным насосом. Наш дом и наша база.",
		"faction": "Дети Воды",
		"mods": {"water": 0.6, "food": 0.9},
		"home": true,
	},
	"gasgrad": {
		"name": "Бензинград",
		"icon": "🛢",
		"pos": Vector2(0.16, 0.56),
		"desc": "Нефтяные вышки и вечный чад. Топливо льётся рекой.",
		"faction": "Нефтяные Бароны",
		"mods": {"fuel": 0.5, "water": 1.4},
	},
	"bulletfarm": {
		"name": "Свинцовая Ферма",
		"icon": "🔸",
		"pos": Vector2(0.83, 0.48),
		"desc": "Шахты и литейни. Свинец и порох — местный хлеб.",
		"faction": "Литейный Синдикат",
		"mods": {"ammo": 0.5, "metal": 0.8, "food": 1.3},
	},
	"bartertown": {
		"name": "Бартертаун",
		"icon": "⚖️",
		"pos": Vector2(0.50, 0.30),
		"desc": "Вольный торговый город. Всё есть, всё дорого.",
		"faction": "Вольные Торговцы",
		"mods": {"metal": 0.9, "fuel": 0.9, "water": 0.9, "ammo": 0.9, "food": 0.9, "chips": 0.8},
	},
	"crowsnest": {
		"name": "Гнездо Крука",
		"icon": "📡",
		"pos": Vector2(0.20, 0.10),
		"desc": "Свалка довоенной техники. Кликуши торгуют электроникой.",
		"faction": "Кликуши",
		"mods": {"chips": 0.5, "metal": 1.2, "fuel": 1.2},
	},
}

## Дороги: [город A, город B, расстояние (рейс = 4 + dist*2 волн), опасность].
const ROUTES := [
	["citadel", "gasgrad", 1, 1.0],
	["citadel", "bulletfarm", 1, 1.1],
	["citadel", "bartertown", 2, 1.2],
	["gasgrad", "bartertown", 1, 1.1],
	["bulletfarm", "bartertown", 1, 1.0],
	["bartertown", "crowsnest", 2, 1.35],
	["gasgrad", "crowsnest", 2, 1.3],
]

## Здания базы (в Цитадели): цена — лом + ресурсы из трюма.
const BUILDINGS := {
	"storage": {
		"name": "Склад",
		"icon": "📦",
		"desc": "+6 мест в трюме за уровень",
		"costs": [
			{"scrap": 60, "metal": 4},
			{"scrap": 120, "metal": 8},
			{"scrap": 220, "metal": 14},
		],
	},
	"lab": {
		"name": "Лаборатория",
		"icon": "⚗️",
		"desc": "Открывает исследования (ур. = доступ к техам)",
		"costs": [
			{"scrap": 100, "metal": 5, "chips": 2},
			{"scrap": 200, "metal": 10, "chips": 5},
			{"scrap": 350, "metal": 16, "chips": 9},
		],
	},
	"refinery": {
		"name": "Перегонный куб",
		"icon": "🛢",
		"desc": "+2 топлива при возвращении домой (за ур.)",
		"costs": [
			{"scrap": 80, "metal": 6},
			{"scrap": 150, "metal": 12},
			{"scrap": 260, "metal": 20},
		],
	},
	"greenshed": {
		"name": "Теплица",
		"icon": "🌿",
		"desc": "+2 еды при возвращении домой (за ур.)",
		"costs": [
			{"scrap": 70, "metal": 3, "water": 2},
			{"scrap": 130, "metal": 6, "water": 4},
			{"scrap": 220, "metal": 10, "water": 7},
		],
	},
	"workshop": {
		"name": "Мастерская",
		"icon": "🔧",
		"desc": "-8% к цене крафта за уровень",
		"costs": [
			{"scrap": 90, "metal": 7},
			{"scrap": 170, "metal": 12},
			{"scrap": 280, "metal": 18},
		],
	},
}

## Исследования: нужна Лаборатория нужного уровня, тикают по рейсам.
## bp — цена в чертежах (мета-валюта из MetaProgress).
const RESEARCH := {
	"plating": {
		"name": "Композитная броня", "icon": "🛡",
		"desc": "+40 HP фуры с старта каждого рейса",
		"lab": 1, "runs": 1, "bp": 1,
		"cost": {"scrap": 80, "metal": 6},
	},
	"copper_heads": {
		"name": "Бронебойные", "icon": "🔸",
		"desc": "+12% урона орудий",
		"lab": 1, "runs": 1, "bp": 2,
		"cost": {"scrap": 90, "metal": 4, "ammo": 3},
	},
	"chemfuel": {
		"name": "Химия топлива", "icon": "⚗️",
		"desc": "Открывает крафт «Нитро-микс»",
		"lab": 1, "runs": 1, "bp": 1,
		"cost": {"scrap": 70, "fuel": 3},
	},
	"tradecraft": {
		"name": "Торговые связи", "icon": "⚖️",
		"desc": "Продажа ресурсов за 85% вместо 75%",
		"lab": 2, "runs": 2, "bp": 2,
		"cost": {"scrap": 120, "food": 3, "water": 3},
	},
	"convoy": {
		"name": "Конвойные схемы", "icon": "🗺",
		"desc": "+15% к награде за волну",
		"lab": 2, "runs": 2, "bp": 3,
		"cost": {"scrap": 140, "chips": 4},
	},
	"armory": {
		"name": "Оружейные чертежи", "icon": "🗜",
		"desc": "Открывает крафт «Комплект орудия»",
		"lab": 3, "runs": 2, "bp": 4,
		"cost": {"scrap": 200, "metal": 10, "chips": 5},
	},
}

## Крафт-модули на рейс (расходники). research — какая теха открывает рецепт.
const RECIPES := {
	"repair_kit": {
		"name": "Ремкомплект", "icon": "🧰",
		"desc": "Раз за рейс: при HP < 25% автопочинка +35% HP",
		"needs": {"metal": 4, "chips": 2},
		"research": "",
	},
	"plate_kit": {
		"name": "Набор брони", "icon": "🛡",
		"desc": "На рейс: +30% к максимуму HP",
		"needs": {"metal": 5},
		"research": "",
	},
	"nitro_mix": {
		"name": "Нитро-микс", "icon": "🔥",
		"desc": "На рейс: кулдаун «Нитро» вдвое короче",
		"needs": {"fuel": 3},
		"research": "chemfuel",
	},
	"weapon_kit": {
		"name": "Комплект орудия", "icon": "🗜",
		"desc": "Рейс начинается с готовым Пулемётом ур.1",
		"needs": {"metal": 6, "ammo": 4, "scrap": 40},
		"research": "armory",
	},
}

## Дневные модификаторы пустоши: 1-2 активных каждый день (сид — дата).
const DAILY_MODS := {
	"heat":     {"name": "Жара", "icon": "🌡", "desc": "огнемёты +30% урона"},
	"fair":     {"name": "Ярмарка", "icon": "🎪", "desc": "цены на рынках -20%"},
	"horde":    {"name": "Караван", "icon": "🏍", "desc": "+2 рейдера на волну, +10% наград"},
	"tailwind": {"name": "Попутный ветер", "icon": "🍃", "desc": "мир летит +15%, КД Нитро -20%"},
}

## Репутация у фракций: очки 0..100, уровень по порогам.
## Бонусы уровня: -4% к цене покупки, +3% к доле продажи, +5% к награде контракта.
const REP_LEVELS := [
	{"min": 0, "title": "Чужак"},
	{"min": 5, "title": "Знакомый"},
	{"min": 15, "title": "Свой"},
	{"min": 30, "title": "Уважаемый"},
	{"min": 50, "title": "Легенда"},
]

## Трофейные тачки: шанс захвата обломка, распил на ресурсы и цена продажи.
const TROPHIES := {
	"buggy":  {"name": "Багги", "icon": "🛞", "chance": 0.12, "scrap_price": 25, "salvage": {"metal": 2, "ammo": 1}},
	"biker":  {"name": "Мотоцикл", "icon": "🏍", "chance": 0.12, "scrap_price": 20, "salvage": {"metal": 1, "fuel": 1}},
	"ram":    {"name": "Таран", "icon": "🛡", "chance": 0.18, "scrap_price": 45, "salvage": {"metal": 4, "chips": 1}},
	"copter": {"name": "Автожир", "icon": "🚁", "chance": 0.10, "scrap_price": 35, "salvage": {"metal": 2, "chips": 1}},
	"boss":   {"name": "Босс-тягач", "icon": "☠️", "chance": 1.0, "scrap_price": 120, "salvage": {"metal": 8, "chips": 2}},
	"ace":    {"name": "Корсар", "icon": "🛩", "chance": 1.0, "scrap_price": 150, "salvage": {"metal": 6, "chips": 3}},
	"trainloko": {"name": "Локомотив", "icon": "🚂", "chance": 1.0, "scrap_price": 200, "salvage": {"metal": 10, "chips": 3}},
	"traincar":  {"name": "Вагон поезда", "icon": "🚃", "chance": 0.5, "scrap_price": 80, "salvage": {"metal": 5, "chips": 2}},
}

## Уровень репутации по очкам.
static func rep_level_of(points: int) -> int:
	var lvl := 0
	for i in REP_LEVELS.size():
		if points >= int(REP_LEVELS[i]["min"]):
			lvl = i
	return lvl


## Рандомные локации пустоши (POI): каждый день по сиду даты часть городов
## получает находку поблизости. Осматривается один раз в день.
const POI_TYPES := {
	"convoy_wreck": {"name": "Остов конвоя", "icon": "🚛",
		"desc": "Разбитый караван у обочины. Можно порыться в обломках."},
	"raider_cache": {"name": "Схрон рейдеров", "icon": "🏴",
		"desc": "Заначка банды в скалах. Богато, но бывают мины."},
	"merchant": {"name": "Странствующий торговец", "icon": "🐪",
		"desc": "Кочевник с товаром за полцены от местного рынка."},
	"spring": {"name": "Просачивающаяся скважина", "icon": "⛲",
		"desc": "Из-под земли бьёт струйка. Бесплатно — бери."},
}

## Шаблоны контрактов, которые раздают города.
const CONTRACT_POOL := [
	{"type": "deliver", "label": "Отвезти %d «%s» в %s", "qty_min": 2, "qty_max": 5, "pay_mult": 3.0},
	{"type": "bounty", "label": "Перебить %d рейдеров в рейсах", "qty_min": 10, "qty_max": 20, "pay_min": 60, "pay_max": 120},
	{"type": "reach", "label": "Доехать до %s живым", "pay_min": 50, "pay_max": 90},
	{"type": "escort", "label": "Сопроводить броневик до %s", "pay_min": 120, "pay_max": 200},
]

## Сезонные даты пустоши (реальный календарь): особые правила на пару дней.
const SEASONS := {
	"witch_night": {"name": "Ночь Ведьм", "icon": "🎃", "desc": "автожиры каждые 3 волны, награды +25%", "from": Vector2i(10, 30), "to": Vector2i(11, 1)},
	"founding": {"name": "День Основания", "icon": "🏁", "desc": "лут с рейдеров вдвое щедрее", "from": Vector2i(8, 15), "to": Vector2i(8, 17)},
	"barter_fair": {"name": "Великая Ярмарка", "icon": "🎪", "desc": "цены −30%, скупка +10% к доле", "from": Vector2i(5, 1), "to": Vector2i(5, 3)},
}

## Легендарная ковка из трофеев: орудие заданного уровня в следующий рейс.
## level — индекс уровня (0-based): 1 = ур.2, 2 = ур.3.
const LEGENDARY_RECIPES := {
	"leg_shkval": {"name": "«Шквал»", "icon": "🌪", "weapon": "mgun", "level": 1, "needs": {"biker": 2, "buggy": 1}, "desc": "Пулемёт ур.2 в следующий рейс"},
	"leg_rychag": {"name": "«Рычаг»", "icon": "🪝", "weapon": "harpoon", "level": 2, "needs": {"ram": 2}, "desc": "Гарпун ур.3 в следующий рейс"},
	"leg_groza": {"name": "«Гроза»", "icon": "⛈", "weapon": "tesla", "level": 1, "needs": {"ace": 1, "copter": 2}, "desc": "Тесла ур.2 в следующий рейс"},
	"leg_stena": {"name": "«Стена»", "icon": "🧱", "weapon": "cannon", "level": 2, "needs": {"boss": 1, "ram": 1}, "desc": "Пушка ур.3 в следующий рейс"},
}

## Легендарная ковка способностей: сгорают трофеи — способность открыта НАВСЕГДА.
const LEGENDARY_ABILITY_RECIPES := {
	"ab_magnet": {"name": "«Магнит»", "icon": "🧲", "ability": "magnet", "needs": {"buggy": 3, "biker": 2}, "desc": "Навсегда: «Хламный магнит» — +50% лома 10 сек"},
	"ab_last_stand": {"name": "«Рубеж»", "icon": "🪓", "ability": "last_stand", "needs": {"trainloko": 1}, "desc": "Навсегда: «Последний рубеж» — темп орудий ×2 на 6 сек"},
}

## Сезон по реальной дате (месяц, день); "" если обычный день.
static func season_for(month: int, day: int) -> String:
	var md := month * 100 + day
	for id in SEASONS:
		var f: Vector2i = SEASONS[id]["from"]
		var t: Vector2i = SEASONS[id]["to"]
		var fmd: int = f.x * 100 + f.y
		var tmd: int = t.x * 100 + t.y
		var inside: bool = (md >= fmd and md <= tmd) if fmd <= tmd else (md >= fmd or md <= tmd)
		if inside:
			return id
	return ""


## Какая находка ждёт у города сегодня: {} если пусто.
## Детерминированно от реальной даты и города — на всей пустоши одинаково.
static func poi_for(city: String, day_seed: int) -> Dictionary:
	var h := fposmod(sin(float(day_seed) * 37.77 + float(city.hash() % 997) * 17.13) * 24634.6345, 1.0)
	if h > 0.5:
		return {}
	var keys := POI_TYPES.keys()
	var h2 := fposmod(sin(float(day_seed) * 91.31 + float(city.hash() % 991) * 57.71) * 43758.5453, 1.0)
	var id: String = keys[int(h2 * float(keys.size())) % keys.size()]
	var d: Dictionary = POI_TYPES[id].duplicate()
	d["id"] = id
	return d


static func route_between(a: String, b: String) -> Array:
	## Возвращает [dist, danger] или [] если дороги нет.
	for r in ROUTES:
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			return [int(r[2]), float(r[3])]
	return []


static func neighbors(city: String) -> Array[String]:
	var out: Array[String] = []
	for r in ROUTES:
		if r[0] == city:
			out.append(r[1])
		elif r[1] == city:
			out.append(r[0])
	return out
