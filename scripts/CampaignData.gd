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
		"mods": {"water": 0.6, "food": 0.9},
		"home": true,
	},
	"gasgrad": {
		"name": "Бензинград",
		"icon": "🛢",
		"pos": Vector2(0.16, 0.56),
		"desc": "Нефтяные вышки и вечный чад. Топливо льётся рекой.",
		"mods": {"fuel": 0.5, "water": 1.4},
	},
	"bulletfarm": {
		"name": "Свинцовая Ферма",
		"icon": "🔸",
		"pos": Vector2(0.83, 0.48),
		"desc": "Шахты и литейни. Свинец и порох — местный хлеб.",
		"mods": {"ammo": 0.5, "metal": 0.8, "food": 1.3},
	},
	"bartertown": {
		"name": "Бартертаун",
		"icon": "⚖️",
		"pos": Vector2(0.50, 0.30),
		"desc": "Вольный торговый город. Всё есть, всё дорого.",
		"mods": {"metal": 0.9, "fuel": 0.9, "water": 0.9, "ammo": 0.9, "food": 0.9, "chips": 0.8},
	},
	"crowsnest": {
		"name": "Гнездо Крука",
		"icon": "📡",
		"pos": Vector2(0.20, 0.10),
		"desc": "Свалка довоенной техники. Кликуши торгуют электроникой.",
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

## Шаблоны контрактов, которые раздают города.
const CONTRACT_POOL := [
	{"type": "deliver", "label": "Отвезти %d «%s» в %s", "qty_min": 2, "qty_max": 5, "pay_mult": 3.0},
	{"type": "bounty", "label": "Перебить %d рейдеров в рейсах", "qty_min": 10, "qty_max": 20, "pay_min": 60, "pay_max": 120},
	{"type": "reach", "label": "Доехать до %s живым", "pay_min": 50, "pay_max": 90},
]


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
