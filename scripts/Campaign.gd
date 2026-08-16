extends Node
## Состояние кампании: кошелёк (лом), грузовой трюм, контракты,
## текущий город, день. Сейв в user://campaign.save (JSON).

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
## Корпуса (Crossout-прогрессия): собранные платформы и текущая рабочая.
var hulls_owned: Array = ["buggy"]
var hull_current := "buggy"
## Ссылка на мета-прогресс (чертежи). Ставится из Main.
var meta: Node = null


func _ready() -> void:
	day_seed = int(Time.get_unix_time_from_system() / 86400.0)
	load_campaign()


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
		"hulls_owned": hulls_owned,
		"hull_current": hull_current,
	}))

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
	save_campaign()
	return true


func sell(res: String, qty: int) -> bool:
	if int(cargo.get(res, 0)) < qty:
		return false
	take_cargo(res, qty)
	wallet += int(price_of(res, location) * qty * sell_rate(location))
	gain_rep(location, 1)
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
	save_campaign()
	return "; ".join(parts) if not parts.is_empty() else "Груда ржавчины."


## Продать трофей целиком за лом. Возвращает выручку.
func sell_trophy(t: String) -> int:
	if int(trophies.get(t, 0)) <= 0:
		return 0
	trophies[t] = int(trophies[t]) - 1
	var price: int = CampaignData.TROPHIES[t]["scrap_price"]
	wallet += price
	save_campaign()
	return price


## --- Исследования (лаборатория, тикают рейсами как в EVE) ---
func research_level_req_met(id: String) -> bool:
	return bld_level("lab") >= int(CampaignData.RESEARCH[id]["lab"])


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
	for i in 2:
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
	return "?"


## Есть ли активный эскорт-контракт на этот город.
func active_escort_for(city: String) -> Dictionary:
	for c in contracts:
		if c["type"] == "escort" and c["dest"] == city:
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
	day += 1
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
		if c["type"] == "reach" and c["dest"] == city:
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
	save_campaign()
	return {"scrap": run_scrap, "loot": loot_in, "sold": scrap_fallback, "done": done, "produced": produced, "research": research_finished, "trophies": captured, "rep": rep_gains}


## Рейс провален: груз пополам, лом рейса сгорел.
func fail_run() -> void:
	day += 1
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
	save_campaign()
