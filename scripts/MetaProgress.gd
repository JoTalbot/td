extends Node
## Мета-прогрессия между рейсами: чертежи (мета-валюта) и постоянные
## улучшения мастерской. Хранится в user://meta_progress.save (JSON).
## Бонусы применяются один раз при старте рейса из Main.

const SAVE_PATH := "user://meta_progress.save"

## Постоянные улучшения мастерской × 3 уровня.
const DEFS := {
	"frame": {
		"name": "Усиленная рама",
		"icon": "🔩",
		"desc": "+30 HP фуры с самого старта",
		"costs": [3, 6, 10],
	},
	"stash": {
		"name": "Тайник с ломом",
		"icon": "⚙",
		"desc": "+60 лома с самого старта",
		"costs": [3, 6, 10],
	},
	"dealer": {
		"name": "Скупщик хлама",
		"icon": "💰",
		"desc": "+8% лома за убийства и волны",
		"costs": [4, 7, 12],
	},
	"crew": {
		"name": "Ветераны экипажа",
		"icon": "🎖",
		"desc": "-7% к кулдаунам способностей",
		"costs": [4, 7, 12],
	},
	"arsenal": {
		"name": "Оружейная кладовая",
		"icon": "🗃",
		"desc": "Рейс начинается с бесплатным орудием (ур. = больше железа)",
		"costs": [4, 8, 13],
	},
	"mechanic": {
		"name": "Бортмеханик",
		"icon": "🔧",
		"desc": "Чинит 2 HP/сек в перерыве между волнами (за уровень)",
		"costs": [5, 9, 14],
	},
}

## Какие орудия бесплатно стоят на фуре в начале рейса — по уровню кладовой.
## Бесплатные орудия продаются за 0 лома (см. Main._on_sell_pressed).
const START_WEAPONS := {
	1: ["mgun"],
	2: ["mgun", "flamer"],
	3: ["mgun", "flamer", "cannon"],
}

var blueprints := 0
var levels := {"frame": 0, "stash": 0, "dealer": 0, "crew": 0, "arsenal": 0, "mechanic": 0}
var best_wave := 0              # рекорд волн за рейс (между сессиями)
var last_run_was_record := false
var tutorial_flags: Dictionary = {}   # обучение новичка: id подсказки -> показана


func _ready() -> void:
	load_meta()


func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	blueprints = int(data.get("blueprints", 0))
	best_wave = int(data.get("best_wave", 0))
	tutorial_flags = data.get("tutorial_flags", {})
	var lvls: Dictionary = data.get("levels", {})
	for id in levels:
		levels[id] = int(lvls.get(id, 0))


func save_meta() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"blueprints": blueprints, "levels": levels, "best_wave": best_wave, "tutorial_flags": tutorial_flags}))


## Итоги рейса: чертёж за каждую достигнутую волну + по два за убитого босса.
func finish_run(wave_index: int, bosses_down: int) -> int:
	var earned := maxi(wave_index + bosses_down * 2, 1)
	blueprints += earned
	last_run_was_record = wave_index > best_wave
	best_wave = maxi(best_wave, wave_index)
	save_meta()
	return earned


func level_of(id: String) -> int:
	return int(levels.get(id, 0))


## --- Обучение новичка: каждая подсказка показывается один раз и навсегда ---
func tutorial_seen(id: String) -> bool:
	return bool(tutorial_flags.get(id, false))


func mark_tutorial(id: String) -> void:
	if tutorial_seen(id):
		return
	tutorial_flags[id] = true
	save_meta()


## Цена следующего уровня; -1 — если уже максимум.
func cost_of(id: String) -> int:
	var lvl: int = level_of(id)
	var costs: Array = DEFS[id]["costs"]
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy(id: String) -> bool:
	var cost := cost_of(id)
	if cost < 0 or cost > blueprints:
		return false
	blueprints -= cost
	levels[id] = level_of(id) + 1
	save_meta()
	return true


## --- Постоянные бонусы, применяемые при старте рейса ---
func bonus_start_hp() -> int:
	return 30 * level_of("frame")


func bonus_start_scrap() -> int:
	return 60 * level_of("stash")


func reward_mult() -> float:
	return 1.0 + 0.08 * level_of("dealer")


func cooldown_mult() -> float:
	return 1.0 - 0.07 * level_of("crew")


## Скорость починки бортмеханика: HP/сек, только в перерыве между волнами.
func mechanic_rate() -> float:
	return 2.0 * level_of("mechanic")
