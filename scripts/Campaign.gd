extends Node
## Состояние кампании: кошелёк (лом), грузовой трюм, контракты,
## текущий город, день. Сейв в user://campaign.save (JSON).

signal achievement_unlocked(id: String, data: Dictionary)
signal route_mastered(data: Dictionary)

const CampaignData := preload("res://scripts/CampaignData.gd")

const SAVE_PATH := "user://campaign.save"
const START_WALLET := 100
const BASE_CARGO_CAP := 15

var wallet := START_WALLET
var cargo: Dictionary = {}        # res_id -> qty
var location := "citadel"
var day := 0                       # игровые сутки, тикают по рейсам
var day_seed := 0                  # настоящая дата — дневной джиттер цен
var contracts: Array = []          # активные контракты
var offers: Dictionary = {}        # city -> контракты на доске
var kills_total := 0
var runs_finished := 0            # завершённые рейсы (для облегчения первых выездов)
var buildings: Dictionary = {}     # bld_id -> level
var research_done: Array = []      # завершённые техи
var research_active := ""          # текущее исследование (id), "" — свободно
var research_left := 0             # сколько рейсов до завершения
var inventory: Dictionary = {}     # item_id -> qty (скрафченные модули)
var pending: Array = []            # модули, выданные в следующий рейс
var poi_used: Array = []           # осмотренные находки: ключи "day_seed:city"
var reputation: Dictionary = {}    # city -> очки репутации (0..100) у фракции
var trophies: Dictionary = {}      # тип трофея -> кол-во (ездит с фурой)
var leg_abilities: Array = []      # легендарные способности, выкованные навсегда (id из AbilityData)
var service_buffs: Array = []      # городские услуги на следующий рейс
var discovered_cities: Array = ["citadel"]
var story_progress: Dictionary = {} # city -> следующий этап сюжетной цепочки
var story_choices: Dictionary = {}  # city -> выбранные решения по этапам
var visited_routes: Array = []       # ключи именованных трасс
var route_mastery: Dictionary = {}  # route_key -> число успешных прохождений
var mastered_routes: Array = []     # награда за уровень 3 уже выдана
var route_control: Dictionary = {}  # route_key -> город-фракция, контролирующая дорогу
var war_log: Array = []              # последние захваты дорог
var achievements: Array = []         # автоматически выданные достижения
var achievement_stats: Dictionary = {"trade": 0, "trophies": 0}
var war_week := -1
var war_side := ""               # город выбранной фракции на текущую неделю
var war_points := 0
var war_claimed: Array = []        # пороги 5/12/25
## Корпуса (Crossout-прогрессия): собранные платформы и текущая рабочая.
var hulls_owned: Array = ["buggy"]
var hull_current := "buggy"
## Ссылка на мета-прогресс (чертежи). Ставится из Main.
var meta: Node = null


func _ready() -> void:
	day_seed = int(Time.get_unix_time_from_system() / 86400.0)
	var had_save := FileAccess.file_exists(SAVE_PATH)
	load_campaign()
	_sync_war_week()
	if not had_save:
		discover_around(location)
		save_campaign()


func load_campaign() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	wallet = int(data.get("wallet", START_WALLET))
	cargo = data.get("cargo", {})
	location = data.get("location", "citadel")
	day = int(data.get("day", 0))
	contracts = data.get("contracts", [])
	offers = data.get("offers", {})
	kills_total = int(data.get("kills_total", 0))
	runs_finished = int(data.get("runs_finished", 0))
	buildings = data.get("buildings", {})
	research_done = data.get("research_done", [])
	research_active = data.get("research_active", "")
	research_left = int(data.get("research_left", 0))
	inventory = data.get("inventory", {})
	pending = data.get("pending", [])
	poi_used = data.get("poi_used", [])
	reputation = data.get("reputation", {})
	trophies = data.get("trophies", {})
	leg_abilities = data.get("leg_abilities", [])
	service_buffs = data.get("service_buffs", [])
	story_progress = data.get("story_progress", {})
	story_choices = data.get("story_choices", {})
	visited_routes = data.get("visited_routes", [])
	route_mastery = data.get("route_mastery", {})
	mastered_routes = data.get("mastered_routes", [])
	route_control = data.get("route_control", {})
	war_log = data.get("war_log", [])
	achievements = data.get("achievements", [])
	achievement_stats = data.get("achievement_stats", {"trade": 0, "trophies": 0})
	war_week = int(data.get("war_week", -1))
	war_side = String(data.get("war_side", ""))
	war_points = int(data.get("war_points", 0))
	war_claimed = data.get("war_claimed", [])
	_sync_war_week()
	if data.has("discovered_cities"):
		discovered_cities = data.get("discovered_cities", [location])
	else:
		# Ветеранские сейвы не закрываем туманом задним числом.
		discovered_cities = CampaignData.CITIES.keys()
	hulls_owned = data.get("hulls_owned", [])
	hull_current = str(data.get("hull_current", ""))
	if hulls_owned.is_empty():
		# Миграция ветеранов: сейв без корпусов — дарим «Мамонта», не ломаем сборки
		hulls_owned = ["buggy", "truck"]
		hull_current = "truck"
	if hull_current == "" or hull_current not in hulls_owned:
		hull_current = hulls_owned[0]
	# Находки живут одни сутки: чистим метки прошлых дней
	var today_prefix := "%d:" % day_seed
	poi_used = poi_used.filter(func(k: Variant) -> bool: return str(k).begins_with(today_prefix))


func save_campaign() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"wallet": wallet,
		"cargo": cargo,
		"location": location,
		"day": day,
		"contracts": contracts,
		"offers": offers,
		"kills_total": kills_total,
		"runs_finished": runs_finished,
		"buildings": buildings,
		"research_done": research_done,
		"research_active": research_active,
		"research_left": research_left,
		"inventory": inventory,
		"pending": pending,
		"poi_used": poi_used,
		"reputation": reputation,
		"trophies": trophies,
		"leg_abilities": leg_abilities,
		"service_buffs": service_buffs,
		"discovered_cities": discovered_cities,
		"story_progress": story_progress,
		"story_choices": story_choices,
		"visited_routes": visited_routes,
		"route_mastery": route_mastery,
		"mastered_routes": mastered_routes,
		"route_control": route_control,
		"war_log": war_log,
		"achievements": achievements,
		"achievement_stats": achievement_stats,
		"war_week": war_week,
		"war_side": war_side,
		"war_points": war_points,
		"war_claimed": war_claimed,
		"hulls_owned": hulls_owned,
		"hull_current": hull_current,
	}))

## --- Разведка, городские услуги и сюжет фракций ---
func is_city_discovered(city: String) -> bool:
	return city in discovered_cities


func discover_around(city: String) -> void:
	if city not in discovered_cities:
		discovered_cities.append(city)
	for neighbor in CampaignData.neighbors(city):
		if neighbor not in discovered_cities:
			discovered_cities.append(neighbor)


func note_route(a: String, b: String) -> void:
	var key := CampaignData.route_key(a, b)
	if not CampaignData.route_meta(a, b).is_empty():
		if key not in visited_routes:
			visited_routes.append(key)
		route_mastery[key] = int(route_mastery.get(key, 0)) + 1
		if route_mastery_level(a, b) >= 3 and key not in mastered_routes:
			mastered_routes.append(key)
			wallet += 150
			add_cargo("parts", 2)
			if meta != null:
				meta.blueprints += 1
				meta.save_meta()
			var route_name := String(CampaignData.route_meta(a, b).get("name", "Трасса"))
			route_mastered.emit({"name": "МАСТЕР: %s" % route_name, "desc": "Трасса освоена. Торговая скидка растёт на 3%.", "reward": {"scrap": 150, "bp": 1}})
	_add_war_points(a, b)
	check_achievements()
	save_campaign()


func route_mastery_count(a: String, b: String) -> int:
	return int(route_mastery.get(CampaignData.route_key(a, b), 0))


func route_mastery_level(a: String, b: String) -> int:
	return mini(int(route_mastery_count(a, b) / 2), 3)


func route_mastery_reward_mult(a: String, b: String) -> float:
	return 1.0 + route_mastery_level(a, b) * 0.05


func route_mastery_danger_mult(a: String, b: String) -> float:
	return 1.0 - route_mastery_level(a, b) * 0.05


func route_controller(a: String, b: String) -> String:
	var key := CampaignData.route_key(a, b)
	if route_control.has(key):
		return String(route_control[key])
	return a if a < b else b


func advance_faction_war() -> void:
	if CampaignData.ROUTES.is_empty():
		return
	var route: Array = CampaignData.ROUTES[(day * 7 + runs_finished * 3) % CampaignData.ROUTES.size()]
	var key := CampaignData.route_key(String(route[0]), String(route[1]))
	var owner := String(route[0]) if (day + runs_finished) % 2 == 0 else String(route[1])
	var previous := String(route_control.get(key, ""))
	route_control[key] = owner
	if previous != owner:
		var route_name := String(CampaignData.route_meta(String(route[0]), String(route[1])).get("name", "Безымянная дорога"))
		war_log.push_front({"day": day, "route": key, "name": route_name, "owner": owner, "previous": previous})
		if war_log.size() > 20:
			war_log.resize(20)


func _current_war_week() -> int:
	return int(Time.get_unix_time_from_system() / 604800.0)


func _sync_war_week() -> void:
	var current := _current_war_week()
	if war_week != current:
		war_week = current
		war_side = ""
		war_points = 0
		war_claimed.clear()


func choose_war_side(city: String) -> bool:
	_sync_war_week()
	if war_side != "" or not CampaignData.CITIES.has(city):
		return false
	war_side = city
	save_campaign()
	return true


func war_faction_name() -> String:
	return String(CampaignData.CITIES.get(war_side, {}).get("faction", "Фракция не выбрана"))


func _add_war_points(a: String, b: String) -> void:
	_sync_war_week()
	if war_side == "":
		return
	war_points += 2 if route_controller(a, b) == war_side else 1
	for threshold in [5, 12, 25]:
		if war_points >= threshold and threshold not in war_claimed:
			war_claimed.append(threshold)
			var reward := {"scrap": 100 if threshold == 5 else (200 if threshold == 12 else 350)}
			if threshold >= 12:
				reward["bp"] = 1 if threshold == 12 else 2
			_grant_achievement_reward(reward)
			achievement_unlocked.emit("war_%d" % threshold, {
				"name": "НЕДЕЛЯ ВОЙНЫ • %d" % threshold,
				"desc": "Цель поддержки фракции выполнена.", "reward": reward})


func check_achievements() -> Array[String]:
	var unlocked: Array[String] = []
	var route_runs := 0
	for count in route_mastery.values():
		route_runs += int(count)
	for id in CampaignData.ACHIEVEMENTS:
		if id in achievements:
			continue
		var complete := false
		match String(id):
			"explorer": complete = discovered_cities.size() >= CampaignData.CITIES.size()
			"bone_saga": complete = story_stage("bonewall") >= CampaignData.CITY_STORIES["bonewall"].size()
			"copper_saga": complete = story_stage("copperpit") >= CampaignData.CITY_STORIES["copperpit"].size()
			"roadmaster": complete = visited_routes.size() >= CampaignData.ROUTE_META.size()
			"veteran": complete = runs_finished >= 10
			"war_rig": complete = "war_rig" in hulls_owned
			"roads_bronze": complete = route_runs >= 4
			"roads_silver": complete = route_runs >= 12
			"roads_gold": complete = route_runs >= 24
			"trade_bronze": complete = int(achievement_stats.get("trade", 0)) >= 10
			"trade_silver": complete = int(achievement_stats.get("trade", 0)) >= 30
			"trade_gold": complete = int(achievement_stats.get("trade", 0)) >= 75
			"trophy_bronze": complete = int(achievement_stats.get("trophies", 0)) >= 3
			"trophy_silver": complete = int(achievement_stats.get("trophies", 0)) >= 10
			"trophy_gold": complete = int(achievement_stats.get("trophies", 0)) >= 25
		if complete:
			achievements.append(id)
			unlocked.append(id)
			_grant_achievement_reward(CampaignData.ACHIEVEMENTS[id]["reward"])
			achievement_unlocked.emit(id, CampaignData.ACHIEVEMENTS[id])
	if not unlocked.is_empty():
		save_campaign()
	return unlocked


func _grant_achievement_reward(reward: Dictionary) -> void:
	if reward.has("scrap"):
		wallet += int(reward["scrap"])
	if reward.has("bp") and meta != null:
		meta.blueprints += int(reward["bp"])
		meta.save_meta()


func intel_candidates() -> Array[String]:
	var out: Array[String] = []
	for city in CampaignData.CITIES:
		if city in discovered_cities:
			continue
		for neighbor in CampaignData.neighbors(city):
			if neighbor in discovered_cities:
				out.append(city)
				break
	return out


func intel_price() -> int:
	return maxi(30, 80 - rep_level(location) * 10)


func buy_intel() -> String:
	var candidates := intel_candidates()
	if candidates.is_empty() or wallet < intel_price():
		return ""
	wallet -= intel_price()
	candidates.sort()
	var city: String = candidates[(day_seed + day) % candidates.size()]
	discovered_cities.append(city)
	check_achievements()
	save_campaign()
	return city


func story_ending(city: String) -> String:
	var chain: Array = CampaignData.CITY_STORIES.get(city, [])
	if chain.is_empty() or story_stage(city) < chain.size():
		return "ongoing"
	var choices: Array = story_choices.get(city, [])
	if "betray" in choices:
		return "betrayed"
	var profit_count := choices.count("profit")
	return "mercenary" if profit_count >= 2 else "allied"


func city_service_price(city: String) -> int:
	var service: Dictionary = CampaignData.CITY_SERVICES.get(city, {})
	var price := int(round(int(service.get("scrap", 0)) * (1.0 - rep_level(city) * 0.05)))
	if story_ending(city) == "allied":
		price = int(round(price * 0.85))
	return maxi(1, price)


func city_service_strength(city: String) -> float:
	var strength := 0.15 + rep_level(city) * 0.03 if city == "bonewall" else 0.12 + rep_level(city) * 0.02
	if story_ending(city) == "allied":
		strength += 0.05
	elif story_ending(city) == "mercenary":
		strength += 0.03
	return strength


func _has_service_buff(buff_id: String) -> bool:
	for queued in service_buffs:
		if queued is Dictionary:
			if String(queued.get("id", "")) == buff_id:
				return true
		elif String(queued) == buff_id:
			return true
	return false


func can_buy_city_service(city: String) -> bool:
	var service: Dictionary = CampaignData.CITY_SERVICES.get(city, {})
	if service.is_empty() or location != city or story_ending(city) == "betrayed" or _has_service_buff(String(service["buff"])):
		return false
	if wallet < city_service_price(city):
		return false
	for res in service["needs"]:
		if cargo_qty(res) < int(service["needs"][res]):
			return false
	return true


func buy_city_service(city: String) -> bool:
	if not can_buy_city_service(city):
		return false
	var service: Dictionary = CampaignData.CITY_SERVICES[city]
	wallet -= city_service_price(city)
	for res in service["needs"]:
		take_cargo(res, int(service["needs"][res]))
	service_buffs.append({"id": String(service["buff"]), "strength": city_service_strength(city)})
	save_campaign()
	return true


func pop_service_buffs() -> Array:
	var out := service_buffs.duplicate()
	service_buffs.clear()
	save_campaign()
	return out


func story_stage(city: String) -> int:
	return int(story_progress.get(city, 0))


func story_current(city: String) -> Dictionary:
	var chain: Array = CampaignData.CITY_STORIES.get(city, [])
	var stage := story_stage(city)
	return chain[stage] if stage < chain.size() else {}


func can_advance_story(city: String) -> bool:
	if location != city:
		return false
	var stage := story_current(city)
	if stage.is_empty():
		return false
	for key in stage["needs"]:
		var amount := int(stage["needs"][key])
		if String(key).begins_with("trophy:"):
			if int(trophies.get(String(key).trim_prefix("trophy:"), 0)) < amount:
				return false
		elif cargo_qty(key) < amount:
			return false
	return true


func advance_story(city: String, choice: String = "loyal") -> bool:
	if not can_advance_story(city):
		return false
	var stage := story_current(city)
	for key in stage["needs"]:
		var amount := int(stage["needs"][key])
		if String(key).begins_with("trophy:"):
			var trophy_id := String(key).trim_prefix("trophy:")
			trophies[trophy_id] = int(trophies.get(trophy_id, 0)) - amount
		else:
			take_cargo(key, amount)
	var reward: Dictionary = stage["reward"].duplicate(true)
	match choice:
		"profit":
			reward["rep"] = int(int(reward.get("rep", 0)) / 2)
			reward["scrap"] = int(reward.get("scrap", 0)) + 100
		"betray":
			reward["rep"] = -15
			reward["scrap"] = int(reward.get("scrap", 0)) + 250
	for key in reward:
		var amount := int(reward[key])
		match String(key):
			"rep": gain_rep(city, amount)
			"scrap": wallet += amount
			"bp":
				if meta != null:
					meta.blueprints += amount
					meta.save_meta()
			_: add_cargo(key, amount)
	if not story_choices.has(city):
		story_choices[city] = []
	(story_choices[city] as Array).append(choice)
	story_progress[city] = story_stage(city) + 1
	check_achievements()
	save_campaign()
	return true


## --- База (только в родном городе) ---
func bld_level(id: String) -> int:
	return int(buildings.get(id, 0))


func bld_cost(id: String) -> Dictionary:
	## Цена следующего уровня; пусто — если максимум.
	var lvl: int = bld_level(id)
	var costs: Array = CampaignData.BUILDINGS[id]["costs"]
	return costs[lvl] if lvl < costs.size() else {}


func can_build(id: String) -> bool:
	var cost := bld_cost(id)
	if cost.is_empty():
		return false
	for k in cost:
		if k == "scrap":
			if wallet < int(cost[k]):
				return false
		elif cargo_qty(k) < int(cost[k]):
			return false
	return true


func build(id: String) -> bool:
	if not can_build(id):
		return false
	var cost := bld_cost(id)
	for k in cost:
		if k == "scrap":
			wallet -= int(cost[k])
		else:
			take_cargo(k, int(cost[k]))
	buildings[id] = bld_level(id) + 1
	save_campaign()
	return true


## --- Шоурум корпусов (собираются дома из запчастей) ---
func can_build_hull(id: String) -> bool:
	var d: Dictionary = CampaignData.HULLS.get(id, {})
	if d.is_empty() or id in hulls_owned:
		return false
	if bld_level("workshop") < int(d["workshop"]):
		return false
	if wallet < int(d["scrap"]):
		return false
	return cargo_qty("parts") >= int(d["parts"])


func build_hull(id: String) -> bool:
	if not can_build_hull(id):
		return false
	var d: Dictionary = CampaignData.HULLS[id]
	wallet -= int(d["scrap"])
	take_cargo("parts", int(d["parts"]))
	hulls_owned.append(id)
	hull_current = id          # свежесобранное — сразу в строй
	check_achievements()
	save_campaign()
	return true


func select_hull(id: String) -> bool:
	if id not in hulls_owned or id == hull_current:
		return false
	hull_current = id
	save_campaign()
	return true


## --- Трюм ---
func cargo_used() -> int:
	var n := 0
	for k in cargo:
		n += int(cargo[k])
	return n


func cargo_cap() -> int:
	# +места от склада на базе
	return BASE_CARGO_CAP + bld_level("storage") * 6


func cargo_space() -> int:
	return cargo_cap() - cargo_used()


func add_cargo(res: String, qty: int) -> int:
	## Кладёт сколько влезло, возвращает сколько РЕАЛЬНО влезло.
	var fit := mini(qty, cargo_space())
	if fit > 0:
		cargo[res] = int(cargo.get(res, 0)) + fit
	return fit


func take_cargo(res: String, qty: int) -> bool:
	if int(cargo.get(res, 0)) < qty:
		return false
	cargo[res] = int(cargo[res]) - qty
	if cargo[res] <= 0:
		cargo.erase(res)
	return true


func cargo_qty(res: String) -> int:
	return int(cargo.get(res, 0))


## --- Цены (с дневным джиттером) ---
## Активные дневные модификаторы (1-2, детерминированно от даты).
func daily_mods() -> Array:
	var ids: Array = CampaignData.DAILY_MODS.keys()
	var h1 := fposmod(sin(float(day_seed) * 57.31) * 43758.5453, 1.0)
	var out: Array = [ids[int(h1 * ids.size()) % ids.size()]]
	var h2 := fposmod(sin(float(day_seed) * 91.7) * 24634.6345, 1.0)
	if h2 < 0.35:
		var second: String = ids[(ids.find(out[0]) + 2) % ids.size()]
		if not out.has(second):
			out.append(second)
	return out


## Активный сезон по реальному календарю ("" — обычный день пустоши).
var _season_override := ""   # для смок-тестов


func season() -> String:
	if _season_override != "":
		return _season_override
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return CampaignData.season_for(int(d["month"]), int(d["day"]))


func price_of(res: String, city: String) -> int:
	var base: float = CampaignData.RESOURCES[res]["price"]
	var mod: float = CampaignData.CITIES[city]["mods"].get(res, 1.0)
	if "fair" in daily_mods():
		mod *= 0.8   # ярмарочный день — всё дешевле
	if season() == "barter_fair":
		mod *= 0.7   # Великая Ярмарка — распродажа века
	var h := sin(float(day_seed) * 127.1 + float(res.hash() % 997) * 311.7 + float(city.hash() % 991) * 74.7) * 43758.5453
	var jitter := 0.9 + 0.2 * (h - floorf(h))
	return maxi(int(round(base * mod * jitter)), 1)


## --- Репутация у фракций городов ---
func rep_of(city: String) -> int:
	return int(reputation.get(city, 0))


func rep_level(city: String) -> int:
	return CampaignData.rep_level_of(rep_of(city))


func rep_title(city: String) -> String:
	return CampaignData.REP_LEVELS[rep_level(city)]["title"]


## Очки репутации с потолком 100. Без сейва — разом сохранит вызывающий.
func gain_rep(city: String, n: int) -> void:
	reputation[city] = clampi(rep_of(city) + n, 0, 100)


## Цена покупки для НАШЕЙ фуры: свои дают скидку (-4% за уровень).
## Округляем вниз — скидка должна чувствоваться даже на дешёвом товаре.
func buy_price(res: String, city: String) -> int:
	var disc := 1.0 - 0.04 * float(rep_level(city))
	# Каждая полностью освоенная именованная трасса даёт постоянные −3% (до −18%).
	disc -= minf(mastered_routes.size() * 0.03, 0.18)
	return maxi(int(floor(price_of(res, city) * disc)), 1)


## Доля цены при продаже: +3% за уровень репутации (потолок 95%).
func sell_rate(city: String) -> float:
	var rate := 0.85 if "tradecraft" in research_done else 0.75
	if season() == "barter_fair":
		rate += 0.10   # на ярмарке скупают не глядя
	return minf(rate + 0.03 * float(rep_level(city)), 0.95)


func buy(res: String, qty: int) -> bool:
	var cost := buy_price(res, location) * qty
	if cost > wallet or qty > cargo_space():
		return false
	wallet -= cost
	add_cargo(res, qty)
	gain_rep(location, 1)  # деньги сливаются — тебя запоминают
	achievement_stats["trade"] = int(achievement_stats.get("trade", 0)) + 1
	check_achievements()
	save_campaign()
	return true


func sell(res: String, qty: int) -> bool:
	if int(cargo.get(res, 0)) < qty:
		return false
	take_cargo(res, qty)
	wallet += int(price_of(res, location) * qty * sell_rate(location))
	gain_rep(location, 1)
	achievement_stats["trade"] = int(achievement_stats.get("trade", 0)) + 1
	check_achievements()
	save_campaign()
	return true


## --- Трофейные тачки (ангар) ---
func add_trophies(d: Dictionary) -> void:
	for t in d:
		if CampaignData.TROPHIES.has(t):
			trophies[t] = int(trophies.get(t, 0)) + int(d[t])
	save_campaign()


## Разобрать трофей: распил на ресурсы, что не влезло — скупщику за полцены.
## Возвращает текст итога для UI.
func scrap_trophy(t: String) -> String:
	if int(trophies.get(t, 0)) <= 0:
		return ""
	trophies[t] = int(trophies[t]) - 1
	var d: Dictionary = CampaignData.TROPHIES[t]
	var parts: Array[String] = []
	var fallback := 0
	for res in d["salvage"]:
		var want: int = d["salvage"][res]
		var fit := add_cargo(res, want)
		if fit > 0:
			parts.append("+%d %s" % [fit, CampaignData.RESOURCES[res]["name"]])
		if want > fit:
			fallback += int(CampaignData.RESOURCES[res]["price"] * 0.5) * (want - fit)
	if fallback > 0:
		wallet += fallback
		parts.append("остаток скупщику: ⚙+%d" % fallback)
	achievement_stats["trophies"] = int(achievement_stats.get("trophies", 0)) + 1
	check_achievements()
	save_campaign()
	return "; ".join(parts) if not parts.is_empty() else "Груда ржавчины."


## Продать трофей целиком за лом. Возвращает выручку.
func sell_trophy(t: String) -> int:
	if int(trophies.get(t, 0)) <= 0:
		return 0
	trophies[t] = int(trophies[t]) - 1
	var price: int = CampaignData.TROPHIES[t]["scrap_price"]
	wallet += price
	achievement_stats["trophies"] = int(achievement_stats.get("trophies", 0)) + 1
	check_achievements()
	save_campaign()
	return price


## --- Исследования (лаборатория, тикают рейсами как в EVE) ---
func has_story_ending(ending: String) -> bool:
	for city in CampaignData.CITY_STORIES:
		if story_ending(city) == ending:
			return true
	return false


func research_ending_req_met(id: String) -> bool:
	var ending := String(CampaignData.RESEARCH[id].get("ending", ""))
	return ending == "" or has_story_ending(ending)


func research_level_req_met(id: String) -> bool:
	return bld_level("lab") >= int(CampaignData.RESEARCH[id]["lab"]) and research_ending_req_met(id)


func can_research(id: String) -> bool:
	if research_active != "" or id in research_done or not research_level_req_met(id):
		return false
	var d: Dictionary = CampaignData.RESEARCH[id]
	if meta != null and meta.blueprints < int(d["bp"]):
		return false
	for k in d["cost"]:
		if k == "scrap":
			if wallet < int(d["cost"][k]):
				return false
		elif cargo_qty(k) < int(d["cost"][k]):
			return false
	return true


func start_research(id: String) -> bool:
	if not can_research(id):
		return false
	var d: Dictionary = CampaignData.RESEARCH[id]
	for k in d["cost"]:
		if k == "scrap":
			wallet -= int(d["cost"][k])
		else:
			take_cargo(k, int(d["cost"][k]))
	if meta != null:
		meta.blueprints -= int(d["bp"])
		meta.save_meta()
	research_active = id
	research_left = int(d["runs"])
	save_campaign()
	return true


## --- Крафт (рецепты-модули на один рейс) ---
func can_craft(id: String) -> bool:
	var d: Dictionary = CampaignData.RECIPES[id]
	var req: String = d.get("research", "")
	if req != "" and req not in research_done:
		return false
	var scrap_part := craft_scrap_cost(id)
	if wallet < scrap_part:
		return false
	for k in d["needs"]:
		if k == "scrap":
			continue
		if cargo_qty(k) < int(d["needs"][k]):
			return false
	return true


## Ломовая часть крафта, режется Мастерской (-8%/ур.)
func craft_scrap_cost(id: String) -> int:
	var d: Dictionary = CampaignData.RECIPES[id]
	var base := int(d["needs"].get("scrap", 0))
	return int(base * (1.0 - 0.08 * bld_level("workshop")))


func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var d: Dictionary = CampaignData.RECIPES[id]
	for k in d["needs"]:
		if k == "scrap":
			wallet -= craft_scrap_cost(id)
		else:
			take_cargo(k, int(d["needs"][k]))
	inventory[id] = int(inventory.get(id, 0)) + 1
	save_campaign()
	return true


## Отложить модуль в следующий рейс (по одному каждого вида).
func stage_item(id: String) -> bool:
	if int(inventory.get(id, 0)) < 1 or id in pending:
		return false
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	pending.append(id)
	save_campaign()
	return true


## Забирает staged-модули (вызывает Main при старте рейса).
func pop_pending() -> Array:
	var out := pending.duplicate()
	pending.clear()
	save_campaign()
	return out


## --- Контракты ---
func offer_list(city: String) -> Array:
	if not offers.has(city) or (offers[city] as Array).is_empty():
		offers[city] = _generate_offers(city)
		save_campaign()
	return offers[city]


func _generate_offers(city: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city) + day_seed * 977 + int(city.hash() % 131)
	var out: Array = []
	var tpls: Array = CampaignData.CONTRACT_POOL.duplicate()
	tpls.shuffle()
	var res_keys: Array = CampaignData.RESOURCES.keys()
	var offer_count := 3 if story_ending(city) == "allied" else (1 if story_ending(city) == "betrayed" else 2)
	for i in offer_count:
		var tpl: Dictionary = tpls[i % tpls.size()]
		var c := {"type": tpl["type"], "uid": "%s_%d_%d" % [city, day_seed, i], "origin": city}
		match tpl["type"]:
			"deliver":
				c["res"] = res_keys[rng.randi() % res_keys.size()]
				c["qty"] = rng.randi_range(int(tpl["qty_min"]), int(tpl["qty_max"]))
				var dests := CampaignData.neighbors(city)
				c["dest"] = dests[rng.randi() % dests.size()]
				c["progress"] = 0
				c["reward"] = int(price_of(c["res"], c["dest"]) * int(c["qty"]) * float(tpl["pay_mult"]))
			"bounty":
				c["qty"] = rng.randi_range(int(tpl["qty_min"]), int(tpl["qty_max"]))
				c["start_kills"] = kills_total
				c["reward"] = rng.randi_range(int(tpl["pay_min"]), int(tpl["pay_max"]))
			"reach":
				var dests2 := CampaignData.neighbors(city)
				c["dest"] = dests2[rng.randi() % dests2.size()]
				c["reward"] = rng.randi_range(int(tpl["pay_min"]), int(tpl["pay_max"]))
			"escort":
				var dests3 := CampaignData.neighbors(city)
				c["dest"] = dests3[rng.randi() % dests3.size()]
				c["reward"] = rng.randi_range(int(tpl["pay_min"]), int(tpl["pay_max"]))
			"scout":
				var unknown := intel_candidates()
				if unknown.is_empty():
					c["type"] = "reach"
					var fallback := CampaignData.neighbors(city)
					c["dest"] = fallback[rng.randi() % fallback.size()]
				else:
					c["dest"] = unknown[rng.randi() % unknown.size()]
					c["danger_bonus"] = 0.2
				c["reward"] = rng.randi_range(int(tpl["pay_min"]), int(tpl["pay_max"]))
		out.append(c)
	return out


func accept_contract(city: String, uid: String) -> bool:
	if contracts.size() >= 3:
		return false
	var list: Array = offers.get(city, [])
	for i in list.size():
		if str(list[i].get("uid", "")) == uid:
			var c: Dictionary = list[i]
			if c["type"] == "bounty":
				c["start_kills"] = kills_total
			elif c["type"] == "scout":
				var target := String(c.get("dest", ""))
				if target != "" and target not in discovered_cities:
					discovered_cities.append(target)
					check_achievements()
			contracts.append(c)
			list.remove_at(i)
			save_campaign()
			return true
	return false


func note_kill() -> Array:
	## Возвращает выполненные bounty-контракты.
	kills_total += 1
	var done: Array = []
	for i in range(contracts.size() - 1, -1, -1):
		var c: Dictionary = contracts[i]
		if c["type"] == "bounty" and kills_total - int(c["start_kills"]) >= int(c["qty"]):
			var origin: String = c.get("origin", "")
			c["reward"] = int(int(c["reward"]) * (1.0 + 0.05 * float(rep_level(origin))))
			wallet += int(c["reward"])
			if origin != "":
				gain_rep(origin, 3)
				save_campaign()
			done.append(c)
			contracts.remove_at(i)
	return done


func contract_text(c: Dictionary) -> String:
	match c.get("type"):
		"deliver":
			var rn: String = CampaignData.RESOURCES.get(c["res"], {}).get("name", "?")
			var dn: String = CampaignData.CITIES.get(c["dest"], {}).get("name", "?")
			return "🚚 %d×%s → %s (награда ⚙%d)" % [c["qty"], rn, dn, c["reward"]]
		"bounty":
			return "🎯 Рейдеры: %d/%d убито (награда ⚙%d)" % [kills_total - int(c["start_kills"]), c["qty"], c["reward"]]
		"reach":
			var dn2: String = CampaignData.CITIES.get(c["dest"], {}).get("name", "?")
			return "🏁 Доехать до %s живым (награда ⚙%d)" % [dn2, c["reward"]]
		"escort":
			var dn3: String = CampaignData.CITIES.get(c["dest"], {}).get("name", "?")
			return "🛡 Сопроводить броневик до %s (награда ⚙%d)" % [dn3, c["reward"]]
		"scout":
			var dn4: String = CampaignData.CITIES.get(c["dest"], {}).get("name", "?")
			return "🔭 Разведать %s: усиленный рейс (награда ⚙%d)" % [dn4, c["reward"]]
	return "?"


## Есть ли активный эскорт-контракт на этот город.
func active_escort_for(city: String) -> Dictionary:
	for c in contracts:
		if c["type"] == "escort" and c["dest"] == city:
			return c
	return {}


func active_scout_for(city: String) -> Dictionary:
	for c in contracts:
		if c["type"] == "scout" and c["dest"] == city:
			return c
	return {}


## Исход эскорта по прибытии: survived — довезли живым.
## Возвращает награду (>0), 0 — контракта нет, -1 — фургон погиб.
func resolve_escort(city: String, survived: bool) -> int:
	for i in range(contracts.size() - 1, -1, -1):
		var c: Dictionary = contracts[i]
		if c["type"] == "escort" and c["dest"] == city:
			contracts.remove_at(i)
			if not survived:
				save_campaign()
				return -1
			var origin: String = c.get("origin", "")
			var pay: int = int(int(c["reward"]) * (1.0 + 0.05 * float(rep_level(origin))))
			wallet += pay
			if origin != "":
				gain_rep(origin, 4)
			save_campaign()
			return pay
	return 0


## --- Легендарная ковка (трофеи → орудие на рейс) ---
func can_forge(id: String) -> bool:
	if not CampaignData.LEGENDARY_RECIPES.has(id):
		return false
	var needs: Dictionary = CampaignData.LEGENDARY_RECIPES[id]["needs"]
	for t in needs:
		if int(trophies.get(t, 0)) < int(needs[t]):
			return false
	return true


## Сковать: трофеи в печь, орудие в staged-модули следующего рейса.
func forge(id: String) -> bool:
	if not can_forge(id):
		return false
	var needs: Dictionary = CampaignData.LEGENDARY_RECIPES[id]["needs"]
	for t in needs:
		trophies[t] = int(trophies[t]) - int(needs[t])
	pending.append(id)
	save_campaign()
	return true


## --- Легендарная ковка способностей (трофеи → навсегда) ---
func can_forge_ability(id: String) -> bool:
	if not CampaignData.LEGENDARY_ABILITY_RECIPES.has(id):
		return false
	if leg_abilities.has(String(CampaignData.LEGENDARY_ABILITY_RECIPES[id]["ability"])):
		return false   # уже выкована навсегда
	var needs: Dictionary = CampaignData.LEGENDARY_ABILITY_RECIPES[id]["needs"]
	for t in needs:
		if int(trophies.get(t, 0)) < int(needs[t]):
			return false
	return true


## Сковать способность: трофеи в печь, id способности — в постоянный арсенал.
func forge_ability(id: String) -> bool:
	if not can_forge_ability(id):
		return false
	var needs: Dictionary = CampaignData.LEGENDARY_ABILITY_RECIPES[id]["needs"]
	for t in needs:
		trophies[t] = int(trophies[t]) - int(needs[t])
	leg_abilities.append(String(CampaignData.LEGENDARY_ABILITY_RECIPES[id]["ability"]))
	save_campaign()
	return true


## --- Рандомные локации (POI) ---
## Находка у города сегодня, если её ещё не осматривали.
func poi_at(city: String) -> Dictionary:
	if poi_used.has("%d:%s" % [day_seed, city]):
		return {}
	return CampaignData.poi_for(city, day_seed)


## Осмотреть находку. Бросок детерминирован (день + город) — перезаход не поможет.
## Возвращает {"title", "text"} для панели или {} если осматривать нечего.
func resolve_poi(city: String) -> Dictionary:
	var poi: Dictionary = poi_at(city)
	if poi.is_empty():
		return {}
	poi_used.append("%d:%s" % [day_seed, city])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash("%d:%s:roll" % [day_seed, city])))
	var parts: Array[String] = []
	match String(poi.get("id", "")):
		"spring":
			var res := "fuel" if rng.randf() < 0.5 else "water"
			var n := add_cargo(res, rng.randi_range(1, 2))
			if n > 0:
				parts.append("+%d %s" % [n, CampaignData.RESOURCES[res]["name"]])
			else:
				# Трюм полон — прямо в баки и котлы фуры
				var sc := 8 * rng.randi_range(1, 2)
				wallet += sc
				parts.append("трюм полон, слили в котлы (⚙+%d)" % sc)
		"convoy_wreck":
			var pool: Array = ["metal", "food", "ammo", "water"]
			for _i in rng.randi_range(2, 3):
				var r2: String = pool[rng.randi() % pool.size()]
				if add_cargo(r2, 1) > 0:
					parts.append("+1 %s" % CampaignData.RESOURCES[r2]["name"])
			if rng.randf() < 0.3 and add_cargo("chips", 1) > 0:
				parts.append("+1 Электроника!")
		"raider_cache":
			if rng.randf() < 0.25:
				var toll: int = mini(wallet, rng.randi_range(15, 35))
				wallet -= toll
				parts.append("ЛОВУШКА! Мина рванула — ремонт ⚙-%d" % toll)
			else:
				var pool2: Array = ["metal", "ammo", "chips"]
				for _i in rng.randi_range(3, 4):
					var r3: String = pool2[rng.randi() % pool2.size()]
					if add_cargo(r3, 1) > 0:
						parts.append("+1 %s" % CampaignData.RESOURCES[r3]["name"])
				# Иногда в заначке чертёж — уходит в мета-мастерскую
				if rng.randf() < 0.5 and meta != null:
					meta.blueprints += 1
					meta.save_meta()
					parts.append("+1 чертёж 📐")
		"merchant":
			var keys: Array = CampaignData.RESOURCES.keys()
			var res2: String = keys[rng.randi() % keys.size()]
			var unit := maxi(1, int(price_of(res2, city) * 0.5))
			var qty: int = mini(3, mini(cargo_space(), wallet / unit))
			if qty > 0:
				wallet -= unit * qty
				add_cargo(res2, qty)
				parts.append("+%d %s за ⚙%d (по ⚙%d)" % [qty, CampaignData.RESOURCES[res2]["name"], unit * qty, unit])
			else:
				parts.append("торговец развёл руками: кошелёк или трюм пуст")
	save_campaign()
	var title_txt: String = "%s %s" % [poi.get("icon", "❓"), poi.get("name", "Находка")]
	var body: String = "; ".join(parts) if not parts.is_empty() else "Пусто. Пепел и ржавчина."
	return {"title": title_txt, "text": body}


## --- Итоги рейса ---
## Прибыл в город: лом рейса в кошелёк, лут в трюм, контракты проверены,
## трофеи в ангар. Возвращает сводку для панели прибытия.
func arrive(city: String, run_scrap: int, loot: Dictionary, captured: Dictionary = {}) -> Dictionary:
	location = city
	discover_around(city)
	day += 1
	runs_finished += 1
	advance_faction_war()
	wallet += run_scrap
	var loot_in := {}
	var scrap_fallback := 0
	for res in loot:
		var fit := add_cargo(res, int(loot[res]))
		if fit > 0:
			loot_in[res] = fit
		var rest := int(loot[res]) - fit
		if rest > 0:
			# Не влезло — сдали попутному скупщику за полцены
			scrap_fallback += int(CampaignData.RESOURCES[res]["price"] * 0.5) * rest
	wallet += scrap_fallback
	# Трофейные обломки едут с нами
	for t in captured:
		if CampaignData.TROPHIES.has(t):
			trophies[t] = int(trophies.get(t, 0)) + int(captured[t])
	var rep_gains := {"dest": 0, "contracts": {}}
	gain_rep(city, 1)  # доехал живым — к тебе присматриваются
	rep_gains["dest"] = 1
	var done: Array = []
	for i in range(contracts.size() - 1, -1, -1):
		var c: Dictionary = contracts[i]
		if c["type"] in ["reach", "scout"] and c["dest"] == city:
			var origin: String = c.get("origin", "")
			c["reward"] = int(int(c["reward"]) * (1.0 + 0.05 * float(rep_level(origin))))
			wallet += int(c["reward"])
			if origin != "":
				gain_rep(origin, 3)
				rep_gains["contracts"][origin] = int(rep_gains["contracts"].get(origin, 0)) + 3
			done.append(c)
			contracts.remove_at(i)
		elif c["type"] == "deliver" and c["dest"] == city and cargo_qty(c["res"]) >= int(c["qty"]):
			take_cargo(c["res"], int(c["qty"]))
			var origin2: String = c.get("origin", "")
			c["reward"] = int(int(c["reward"]) * (1.0 + 0.05 * float(rep_level(origin2))))
			wallet += int(c["reward"])
			if origin2 != "":
				gain_rep(origin2, 4)
				rep_gains["contracts"][origin2] = int(rep_gains["contracts"].get(origin2, 0)) + 4
			done.append(c)
			contracts.remove_at(i)
	# Производство базы, если приехали домой
	var produced := {}
	if city == "citadel":
		if bld_level("refinery") > 0:
			var n := add_cargo("fuel", bld_level("refinery") * 2)
			if n > 0:
				produced["fuel"] = n
		if bld_level("greenshed") > 0:
			var n2 := add_cargo("food", bld_level("greenshed") * 2)
			if n2 > 0:
				produced["food"] = n2
	# Исследование тикает рейсом (как время скилла в EVE)
	var research_finished := ""
	if research_active != "":
		research_left -= 1
		if research_left <= 0:
			research_done.append(research_active)
			research_finished = research_active
			research_active = ""
	# Доска контрактов в новом городе обновляется
	offers.erase(city)
	check_achievements()
	save_campaign()
	return {"scrap": run_scrap, "loot": loot_in, "sold": scrap_fallback, "done": done, "produced": produced, "research": research_finished, "trophies": captured, "rep": rep_gains}


## Рейс провален: груз пополам, лом рейса сгорел.
func fail_run() -> void:
	runs_finished += 1
	day += 1
	advance_faction_war()
	for res in cargo.keys():
		var loss := int(ceil(int(cargo[res]) * 0.5))
		cargo[res] = int(cargo[res]) - loss
		if int(cargo[res]) <= 0:
			cargo.erase(res)
	# Исследование тикает и в провале — лаборанты не виноваты
	if research_active != "":
		research_left -= 1
		if research_left <= 0:
				research_done.append(research_active)
				research_active = ""
	check_achievements()
	save_campaign()
