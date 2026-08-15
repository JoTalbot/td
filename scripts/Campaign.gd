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
func price_of(res: String, city: String) -> int:
	var base: float = CampaignData.RESOURCES[res]["price"]
	var mod: float = CampaignData.CITIES[city]["mods"].get(res, 1.0)
	var h := sin(float(day_seed) * 127.1 + float(res.hash() % 997) * 311.7 + float(city.hash() % 991) * 74.7) * 43758.5453
	var jitter := 0.9 + 0.2 * (h - floorf(h))
	return maxi(int(round(base * mod * jitter)), 1)


func buy(res: String, qty: int) -> bool:
	var cost := price_of(res, location) * qty
	if cost > wallet or qty > cargo_space():
		return false
	wallet -= cost
	add_cargo(res, qty)
	save_campaign()
	return true


func sell(res: String, qty: int) -> bool:
	if int(cargo.get(res, 0)) < qty:
		return false
	take_cargo(res, qty)
	# Скупают за 75% цены
	wallet += int(price_of(res, location) * qty * 0.75)
	save_campaign()
	return true


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
		var c := {"type": tpl["type"], "uid": "%s_%d_%d" % [city, day_seed, i]}
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
			wallet += int(c["reward"])
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
	return "?"


## --- Итоги рейса ---
## Прибыл в город: лом рейса в кошелёк, лут в трюм, контракты проверены.
## Возвращает сводку для панели прибытия.
func arrive(city: String, run_scrap: int, loot: Dictionary) -> Dictionary:
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
	var done: Array = []
	for i in range(contracts.size() - 1, -1, -1):
		var c: Dictionary = contracts[i]
		if c["type"] == "reach" and c["dest"] == city:
			wallet += int(c["reward"])
			done.append(c)
			contracts.remove_at(i)
		elif c["type"] == "deliver" and c["dest"] == city and cargo_qty(c["res"]) >= int(c["qty"]):
			take_cargo(c["res"], int(c["qty"]))
			wallet += int(c["reward"])
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
	# Доска контрактов в новом городе обновляется
	offers.erase(city)
	save_campaign()
	return {"scrap": run_scrap, "loot": loot_in, "sold": scrap_fallback, "done": done, "produced": produced}


## Рейс провален: груз пополам, лом рейса сгорел.
func fail_run() -> void:
	day += 1
	for res in cargo.keys():
		var loss := int(ceil(int(cargo[res]) * 0.5))
		cargo[res] = int(cargo[res]) - loss
		if int(cargo[res]) <= 0:
			cargo.erase(res)
	save_campaign()
