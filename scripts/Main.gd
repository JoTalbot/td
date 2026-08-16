extends Node3D
## Корень игры "Дорога ярости": пустыня, грузовик, волны рейдеров, HUD.

const Wasteland := preload("res://scripts/Wasteland.gd")
const Truck := preload("res://scripts/Truck.gd")
const CameraRig := preload("res://scripts/CameraRig.gd")
const GameState := preload("res://scripts/GameState.gd")
const WaveManager := preload("res://scripts/WaveManager.gd")
const HUD := preload("res://scripts/HUD.gd")
const WeaponScript := preload("res://scripts/Weapon.gd")
const WeaponData := preload("res://scripts/WeaponData.gd")
const TruckData := preload("res://scripts/TruckData.gd")
const Abilities := preload("res://scripts/Abilities.gd")
const SoundFX := preload("res://scripts/SoundFX.gd")
const AllyVan := preload("res://scripts/AllyVan.gd")
const RoadEvents := preload("res://scripts/RoadEvents.gd")
const MetaProgress := preload("res://scripts/MetaProgress.gd")
const Campaign := preload("res://scripts/Campaign.gd")
const CampaignData := preload("res://scripts/CampaignData.gd")
const MapScreen := preload("res://scripts/MapScreen.gd")
const Tutorial := preload("res://scripts/Tutorial.gd")
const UserSettings := preload("res://scripts/UserSettings.gd")
const Junk := preload("res://scripts/Junk.gd")

var truck: Truck
var wasteland: Wasteland
var camera_rig: CameraRig
var state: GameState
var waves: WaveManager
var hud: HUD
var abilities: Abilities
var events: RoadEvents
var sfx: SoundFX
var tutorial: Node
var meta: MetaProgress
var campaign: Campaign
var map_screen: MapScreen
var user_settings: UserSettings
var world_env: Environment
var _earned_blueprints := 0
## Рейс идёт (тапы по сцене работают только в бою)
var battle_active := false
## Город назначения текущего рейса
var _destination := ""
var _route_meta: Dictionary = {}
## Лут, набранный в рейсе (в трюм попадёт по прибытии)
var _run_loot: Dictionary = {}
var _run_trophies: Dictionary = {}
## Абордаж: шанс удачного броска крюка (вынесен в var — смок-тесты ставят 0/1).
var board_chance := 0.65
## Тачки, угнанные в этом рейсе по типам — чтоб случайный захват не сработал дважды.
var _boarded_pending: Dictionary = {}
var _boarding_hint_shown := false
## Ремкомплект из крафта: раз за рейс автопочинка при HP < 25%
var _repair_kit_ready := false
var _ally: Node3D = null          # действующий эскорт-фургон (null — не нанимали)
var _ally_warned := false
var _loot_chance := 0.25          # сезон «День Основания» поднимает до 0.5

var selected_weapon_type: String = ""
var selected_weapon: Node3D = null


func _ready() -> void:
	user_settings = UserSettings.new()
	user_settings.name = "UserSettings"
	add_child(user_settings)
	_apply_user_settings()
	user_settings.changed.connect(_on_user_setting_changed)

	_setup_environment()
	_setup_lights()

	state = GameState.new()
	state.name = "GameState"
	add_child(state)

	# Процедурные звуки и тряска камеры
	sfx = SoundFX.new()
	sfx.name = "SoundFX"
	sfx.master_volume = user_settings.sound_gain()
	add_child(sfx)
	state.sfx = sfx
	state.damaged.connect(_on_truck_damaged)

	# Мета-прогрессия: загружаем чертежи и применяем постоянные бонусы
	meta = MetaProgress.new()
	meta.name = "MetaProgress"
	add_child(meta)
	state.reward_mult = meta.reward_mult()
	state.max_hp += meta.bonus_start_hp()
	state.hp = state.max_hp
	state.scrap += meta.bonus_start_scrap()

	wasteland = Wasteland.new()
	wasteland.name = "Wasteland"
	add_child(wasteland)

	truck = Truck.new()
	truck.name = "Truck"
	add_child(truck)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.trauma_scale = user_settings.shake_gain()
	add_child(camera_rig)
	camera_rig.focus_on(Vector3(0, 1.0, 0))

	waves = WaveManager.new()
	waves.name = "WaveManager"
	waves.truck = truck
	waves.state = state
	add_child(waves)

	abilities = Abilities.new()
	abilities.name = "Abilities"
	abilities.setup(state, truck, wasteland)
	abilities.cooldown_mult = meta.cooldown_mult()
	add_child(abilities)

	events = RoadEvents.new()
	events.name = "RoadEvents"
	events.setup(state, truck, wasteland, world_env)
	add_child(events)

	# Обучение новичка: одноразовые контекстные подсказки (флаги в мета-сейве)
	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)

	hud = HUD.new()
	hud.name = "HUD"
	hud.state = state
	hud.waves = waves
	hud.truck = truck
	hud.abilities = abilities
	hud.meta = meta
	hud.settings = user_settings
	add_child(hud)

	hud.weapon_selected.connect(_on_weapon_type_selected)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.truck_upgrade_pressed.connect(_on_truck_upgrade)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.quit_to_map_pressed.connect(_on_quit_to_map)
	hud.ability_pressed.connect(func(a):
		if abilities.try_activate(a):
			sfx.play("ability", 0.8)
			user_settings.vibrate(30, 0.4)
			if tutorial != null:
				tutorial.notify("ability"))
	abilities.feedback.connect(hud.flash_message)
	# Кампания: карта пустоши, экономика, контракты
	campaign = Campaign.new()
	campaign.name = "Campaign"
	campaign.meta = meta
	add_child(campaign)
	campaign.achievement_unlocked.connect(func(_id, data):
		hud.show_achievement(data)
		sfx.play("earn", 1.0, 1.15))
	campaign.route_mastered.connect(func(data):
		hud.show_achievement(data)
		sfx.play("earn", 1.0, 0.9))

	map_screen = MapScreen.new()
	map_screen.name = "MapScreen"
	map_screen.campaign = campaign
	map_screen.settings = user_settings
	add_child(map_screen)
	hud.campaign = campaign
	map_screen.travel_requested.connect(_on_travel)

	waves.boss_event.connect(hud.flash_message)
	events.announced.connect(hud.flash_message)
	events.encounter.connect(hud.show_encounter)
	hud.meta_upgrade_pressed.connect(_on_meta_upgrade)
	state.game_over.connect(_on_game_over)
	waves.run_completed.connect(_on_run_completed)
	waves.enemy_killed.connect(_on_enemy_killed)
	state.weapon_jam_requested.connect(_on_weapon_jam_requested)
	# Звуковая полировка: горн волны, рык босса
	waves.wave_started.connect(func(_i): sfx.play("horn", 0.7))
	waves.boss_event.connect(func(_t): sfx.play("boss", 0.85); camera_rig.add_trauma(0.3))
	hud.sfx = sfx
	map_screen.sfx = sfx
	tutorial.setup(self, hud, state, waves, truck, meta)
	# Crossout-прогрессия: собираем платформу из выбранного в шоуруме корпуса.
	_apply_hull()
	map_screen.hull_changed.connect(_apply_hull)
	_sync_legendary_abilities()

	# Старт — на карте; бой начинается с выбора маршрута
	hud.visible = false
	events.waves = waves


## Игрок выбрал маршрут на карте — запускаем рейс.
func _on_travel(city_id: String) -> void:
	var route: Array = CampaignData.route_between(campaign.location, city_id)
	if route.is_empty():
		return
	_destination = city_id
	_route_meta = CampaignData.route_meta(campaign.location, city_id)
	waves.run_length = 4 + int(route[0]) * 2
	waves.danger = float(route[1]) * campaign.route_mastery_danger_mult(campaign.location, city_id)
	waves.bonus_mult *= campaign.route_mastery_reward_mult(campaign.location, city_id)
	var route_controller: String = campaign.route_controller(campaign.location, city_id)
	waves.commander_type = campaign.route_commander(campaign.location, city_id)
	var friendly_control := campaign.rep_level(route_controller) >= 2
	if friendly_control:
		waves.danger *= 0.95
		waves.bonus_mult *= 1.08
	else:
		waves.danger *= 1.05
	# Первые выезды на голой багги — учебный профиль: короче и мягче
	var noob := campaign.runs_finished < 2 and campaign.hull_current == "buggy"
	if noob:
		waves.run_length = mini(waves.run_length, 3)
		waves.danger = minf(waves.danger, 0.7)
	var scout_contract: Dictionary = campaign.active_scout_for(city_id)
	waves.scout_boss = not scout_contract.is_empty()
	if not scout_contract.is_empty():
		waves.run_length += 1
		waves.danger += float(scout_contract.get("danger_bonus", 0.2))
	_run_loot.clear()
	_run_trophies.clear()
	_boarded_pending.clear()
	_boarding_hint_shown = false
	events._encounters_done = 0   # встречи на трассе — заново каждый рейс
	map_screen.hide_screen()
	hud.visible = true
	battle_active = true
	hud.flash_message("🚚 Рейс: %s → %s" % [
		CampaignData.CITIES[campaign.location]["name"],
		CampaignData.CITIES[city_id]["name"]])
	# Метки трассы: караванный тракт и смертельные дороги
	events.set_caravan_run(CampaignData.route_is_caravan(campaign.location, city_id))
	var tags := ""
	if events.caravan_run:
		tags += " 🐫 караванный тракт — конвой сбросит припасы!"
	if float(route[1]) >= 1.4:
		tags += " ☠ Смертельная трасса: награды щедрее, рейдеры злее!"
	if not _route_meta.is_empty():
		hud.flash_message("ТРАССА: %s — %s" % [_route_meta["name"], _route_meta["desc"]])
	elif tags != "":
		hud.flash_message(tags.strip_edges())
	_apply_campaign_effects()
	if not friendly_control:
		waves.extra_count += 1
		hud.flash_message("ГРАНИЦА ФРАКЦИИ: контроль «%s» — рейдеров больше!" % CampaignData.CITIES[route_controller]["faction"])
	if not scout_contract.is_empty():
		waves.extra_count += 3
		hud.flash_message("РАЗВЕДКОНТРАКТ: +1 волна, усиленные рейдеры, повышенная награда!")
	elif waves.commander_type != "":
		var commander: Dictionary = CampaignData.FACTION_COMMANDERS.get(route_controller, {})
		hud.flash_message("РАЗВЕДКА: дорогу защищает командир «%s»!" % commander.get("name", "неизвестный"))
	_spawn_escort_if_needed(city_id)
	_sync_legendary_abilities()
	# Голой платформе в пустоши не место: штатный пулемёт с базы (продажа за 0)
	if truck.weapons.is_empty():
		var pw: Node3D = WeaponScript.new()
		pw.setup("mgun", state)
		pw.slot_index = 0
		truck.mount_weapon(0, pw)
		pw.set_meta("free_start", true)
		if noob:
			# «Бабушкин пулемёт»: механик базы подтянул ствол до 2-го уровня
			pw.upgrade()
			hud.flash_message("🔧 Штатный пулемёт, подтянутый механиком базы — держись за него!")
		else:
			hud.flash_message("🔧 Штатный пулемёт с базы на борту — больше стволов пока нет!")
	tutorial.notify("travel")
	waves.start()
	var route_event := String(_route_meta.get("event", ""))
	if route_event != "":
		var event_timer := create_tween()
		event_timer.tween_interval(3.0)
		event_timer.tween_callback(func():
			if battle_active and not state.is_game_over:
				events.trigger(route_event))


## Эскорт: если едем в город активного эскорт-контракта — цепляем фургон.
func _spawn_escort_if_needed(city_id: String) -> void:
	waves.ally = null
	_ally = null
	if campaign.active_escort_for(city_id).is_empty():
		return
	_ally = AllyVan.new()
	_ally.truck = truck
	add_child(_ally)
	_ally.global_position = truck.global_position + Vector3(-6.5, 0, -5.0)
	waves.ally = _ally
	_ally_warned = false
	_ally.damaged.connect(func(_hp, _mhp):
		if not _ally_warned and float(_hp) < float(_mhp) * 0.5:
			_ally_warned = true
			hud.flash_message("🛡 Клиентский фургон наполовину бит!"))
	_ally.destroyed.connect(func():
		hud.flash_message("💥 Броневик клиента уничтожен!")
		sfx.play("big_boom", 0.8)
		camera_rig.add_trauma(0.45)
		waves.ally = null)
	hud.flash_message("🛡 Эскорт: доведите броневик живым!")
	sfx.play("horn", 0.8, 1.2)


## Постоянные техи и staged-модули применяются один раз на старте рейса.
func _apply_campaign_effects() -> void:
	truck.apply_route_cosmetics(campaign.mastered_routes.size(), campaign.route_cosmetics)
	if "plating" in campaign.research_done:
		state.add_max_hp(40)
	if "copper_heads" in campaign.research_done:
		state.damage_mult = 1.12
	if "convoy" in campaign.research_done:
		waves.bonus_mult *= 1.15
	if "alliance_plating" in campaign.research_done:
		state.add_max_hp(int(state.max_hp * 0.1))
	if "mercenary_routes" in campaign.research_done:
		waves.bonus_mult *= 1.1
	if "traitor_ammo" in campaign.research_done:
		state.damage_mult *= 1.12
	# Мета-мастерская: стартовые орудия оружейной кладовой (продаются за 0)
	for wtype in MetaProgress.START_WEAPONS.get(meta.level_of("arsenal"), []):
		var slot := -1
		for i in truck.slot_nodes.size():
			if not truck.weapons.has(i):
				slot = i
				break
		if slot >= 0:
			var fw: Node3D = WeaponScript.new()
			fw.setup(wtype, state)
			fw.slot_index = slot
			fw.set_meta("free_start", true)
			truck.mount_weapon(slot, fw)
			hud.flash_message("🗃 Кладовая: %s на борту" % WeaponData.DEFS[wtype]["name"])
	# Сброс на рейс (для повторных тестовых применений)
	_loot_chance = 0.25
	waves.ambush_every = 0
	state.loot_magnet = 0.0     # легендарные способности не переезжают между рейсами
	state.fire_rate_mult = 1.0
	# Сезонные события календаря
	match campaign.season():
		"witch_night":
			waves.bonus_mult *= 1.25
			waves.ambush_every = 3
		"founding":
			_loot_chance = 0.5
	# Дневные модификаторы пустоши
	for m in campaign.daily_mods():
		match m:
			"heat":
				state.damage_kind_mult["flame"] = 1.3
			"horde":
				waves.extra_count = 2
				waves.bonus_mult *= 1.1
			"tailwind":
				wasteland.speed_scale *= 1.15
				abilities.cooldown_mult *= 0.8
	# Именованная трасса меняет правила конкретного рейса.
	match String(_route_meta.get("modifier", "")):
		"reward": waves.bonus_mult *= float(_route_meta.get("value", 1.0))
		"armor": state.add_max_hp(int(state.max_hp * float(_route_meta.get("value", 0.0))))
		"loot": _loot_chance += float(_route_meta.get("value", 0.0))
		"range": state.weapon_range_mult *= float(_route_meta.get("value", 1.0))
		"horde": waves.extra_count += int(_route_meta.get("value", 0))
	# Услуги городов расходуются при старте следующего рейса.
	for buff in campaign.pop_service_buffs():
		var buff_id := String(buff.get("id", "")) if buff is Dictionary else String(buff)
		var strength := float(buff.get("strength", 0.0)) if buff is Dictionary else 0.0
		match buff_id:
			"bone_plating": state.add_max_hp(int(state.max_hp * (strength if strength > 0.0 else 0.15)))
			"copper_sights": state.damage_mult *= 1.0 + (strength if strength > 0.0 else 0.12)
	for item in campaign.pop_pending():
		# Легендарки из кузни трофеев: орудие заданного уровня, продаётся за 0
		if item.begins_with("leg_"):
			_mount_legendary(item)
			continue
		match item:
			"repair_kit":
				_repair_kit_ready = true
			"plate_kit":
				state.add_max_hp(int(state.max_hp * 0.3))
			"nitro_mix":
				abilities.cooldown_mult *= 0.5
			"weapon_kit":
				var slot := truck.weapons.size()  # первый свободный — поиск ниже
				for i in truck.slot_nodes.size():
					if not truck.weapons.has(i):
						slot = i
						break
				if slot < truck.slot_nodes.size() and not truck.weapons.has(slot):
					var w: Node3D = WeaponScript.new()
					w.setup("mgun", state)
					w.slot_index = slot
					truck.mount_weapon(slot, w)
				hud.flash_message("🗜 Комплект орудия смонтирован!")


## Смонтировать выкованную легендарку в первый свободный слот.
func _mount_legendary(item: String) -> void:
	var ld: Dictionary = CampaignData.LEGENDARY_RECIPES.get(item, {})
	if ld.is_empty():
		return
	var slot := -1
	for i in truck.slot_nodes.size():
		if not truck.weapons.has(i):
			slot = i
			break
	if slot < 0:
		hud.flash_message("❌ Фура набита — %s ушло обратно в ангар!" % ld["name"])
		return
	var w: Node3D = WeaponScript.new()
	w.setup(String(ld["weapon"]), state)
	w.slot_index = slot
	truck.mount_weapon(slot, w)
	for i in int(ld["level"]):
		w.upgrade()
	w.set_meta("free_start", true)
	hud.flash_message("%s %s на борту, гроза выжженых земель!" % [ld["icon"], ld["name"]])
	sfx.play("ability", 0.9, 0.75)


## Доехали: сворачиваем лом и лут в кампанию, показываем сводку.
func _on_run_completed() -> void:
	battle_active = false
	tutorial.notify("arrival")
	# Эскорт решается ДО arrive: фургон жив — фракция платит щедро
	var escort_pay := 0
	if not campaign.active_escort_for(_destination).is_empty():
		var survived: bool = _ally != null and is_instance_valid(_ally) and not _ally.is_dead
		escort_pay = campaign.resolve_escort(_destination, survived)
		if escort_pay > 0:
			sfx.play("earn", 1.0)
		else:
			sfx.play("boss", 0.7)
	# Мастерство трассы растёт только за живое успешное прибытие.
	campaign.note_route(campaign.location, _destination)
	var summary: Dictionary = campaign.arrive(_destination, state.scrap, _run_loot, _run_trophies)
	summary["escort"] = escort_pay
	waves.ally = null
	# Живой финиш тоже приносит чертежи и идёт в рекорды
	summary["blueprints"] = meta.finish_run(waves.wave_index, waves.bosses_down)
	summary["record"] = meta.last_run_was_record
	summary["best_wave"] = meta.best_wave
	hud.show_arrival(CampaignData.CITIES[_destination]["name"], summary)


## Убийство рейдера: баунти-контракты + шанс лута в трюм + захват обломка.
func _on_enemy_killed(type: String) -> void:
	var done: Array = campaign.note_kill()
	for c in done:
		hud.flash_message("✅ Контракт выполнен! +⚙%d" % c["reward"])
	# Звук взрыва и тряска: боссы гремят сильнее
	if type in ["boss", "ace", "scoutboss", "bonepriest", "copperdrill"]:
		sfx.play("big_boom", 0.9)
		camera_rig.add_trauma(0.5)
	else:
		sfx.play("explosion", 0.45, randf_range(0.9, 1.15))
	# Угон: целая тачка выхвачена из-под обломков — в ангар по прибытии.
	# Абордаж уже зачёл свой трофей принудительно — не крутим шанс дважды.
	var tpl: Dictionary = CampaignData.TROPHIES.get(type, {})
	if int(_boarded_pending.get(type, 0)) > 0:
		_boarded_pending[type] = int(_boarded_pending[type]) - 1
	elif not tpl.is_empty() and randf() < float(tpl["chance"]):
		_run_trophies[type] = int(_run_trophies.get(type, 0)) + 1
		hud.flash_message("🛻 Захвачен трофей: %s %s!" % [tpl["icon"], tpl["name"]])
		sfx.play("earn", 0.8)
	# Лут с убитого (металл чаще всего); «День Основания» удваивает шанс
	if randf() < _loot_chance:
		var roll := randf()
		var res := "metal"
		if roll > 0.92:
			res = "parts"   # редкое золото гаражей
		elif roll > 0.84:
			res = "chips"
		elif roll > 0.72:
			res = "fuel"
		elif roll > 0.62:
			res = "ammo"
		elif roll > 0.52:
			res = "food"
		elif roll > 0.45:
			res = "water"
		_run_loot[res] = int(_run_loot.get(res, 0)) + 1


## Пересборка боевой платформы под корпус кампании: слоты и запас HP.
## Вызывать на свежей сцене (до монтировки орудий) или из шоурума на карте.
func _apply_hull() -> void:
	truck.set_hull(campaign.hull_current)
	truck.apply_route_cosmetics(campaign.mastered_routes.size(), campaign.route_cosmetics)
	var base := state.START_HP + meta.bonus_start_hp()
	var hull_mult := float(CampaignData.HULLS.get(campaign.hull_current, {}).get("hp_mult", 1.0))
	state.max_hp = int(round(float(base) * hull_mult))
	state.hp = state.max_hp


## Раздать выкованные легендарные способности: Abilities (гейтинг) + HUD (кнопки).
func _sync_legendary_abilities() -> void:
	abilities.unlocked_legendary = campaign.leg_abilities.duplicate()
	hud.leg_abilities = campaign.leg_abilities.duplicate()
	hud.rebuild_ability_bar()


## Диверсант добрался до фуры: случайное орудие заклинивает на 3.5 сек.
func _on_weapon_jam_requested() -> void:
	if truck.weapons.is_empty():
		return
	var slots: Array = truck.weapons.keys()
	var w: Node = truck.weapons[slots[randi() % slots.size()]]
	w.jam(3.5)
	hud.flash_message("🔧 Диверсия! «%s» заклинило на несколько секунд!" % w.weapon_name())
	sfx.play("jam", 0.8)


## Конец рейса смертью фуры: чертежи капают, груз в трюме пополам.
func _on_game_over() -> void:
	battle_active = false
	tutorial.notify("gameover")
	sfx.play("big_boom", 1.0)
	camera_rig.add_trauma(1.0)
	campaign.fail_run()
	_earned_blueprints = meta.finish_run(waves.wave_index, waves.bosses_down)
	hud.show_game_over(waves.wave_index, _earned_blueprints)


func _on_meta_upgrade(id: String) -> void:
	if meta.buy(id):
		hud.flash_message("%s улучшено до ур. %d!" % [MetaProgress.DEFS[id]["name"], meta.level_of(id)])
	else:
		hud.flash_message("Мало чертежей!")
	hud.refresh_meta_panel()


func _setup_environment() -> void:
	var env := Environment.new()
	# Раскалённое пустынное небо, выгоревшее у горизонта.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.72, 0.85)
	sky_mat.sky_horizon_color = Color(0.95, 0.82, 0.6)
	sky_mat.ground_bottom_color = Color(0.55, 0.42, 0.28)
	sky_mat.ground_horizon_color = Color(0.9, 0.75, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# Пыльная дымка вдали
	env.fog_enabled = true
	env.fog_light_color = Color(0.87, 0.72, 0.5)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12

	var world_env_node := WorldEnvironment.new()
	world_env_node.environment = env
	add_child(world_env_node)
	world_env = env


func _setup_lights() -> void:
	# Жестокое пустынное солнце
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	# Тёплый отражённый от песка свет
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(35.0, 130.0, 0.0)
	bounce.light_color = Color(0.9, 0.7, 0.45)
	bounce.light_energy = 0.35
	add_child(bounce)


func _unhandled_input(event: InputEvent) -> void:
	if state.is_game_over or not battle_active:
		return
	var tap_position := Vector2.ZERO
	var tapped := false
	if event is InputEventScreenTouch and event.pressed and not camera_rig.is_gesturing():
		tap_position = event.position
		tapped = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap_position = event.position
		tapped = true
	if tapped:
		_handle_tap(tap_position)


func _handle_tap(screen_pos: Vector2) -> void:
	# Проецируем тап на горизонтальную плоскость на высоте платформы грузовика.
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var plane_y := 1.15
	if absf(dir.y) < 0.0001:
		return
	var t := (plane_y - from.y) / dir.y
	if t <= 0.0:
		return
	var hit := from + dir * t

	# Сначала — попадание в существующее орудие
	var wslot := truck.nearest_weapon_slot(hit)
	if wslot >= 0:
		_select_weapon(truck.weapons[wslot])
		return

	# Затем — установка нового
	if selected_weapon_type != "":
		var slot := truck.nearest_free_slot(hit)
		if slot >= 0:
			_try_mount(slot)
			return
	elif truck.nearest_free_slot(hit) >= 0 and not meta.tutorial_seen("build_first"):
		# Новичок тапает слот, не выбрав орудие — подсказываем порядок действий
		hud.flash_message("⬇ Сначала выберите орудие на панели снизу!")
		return
	# Абордаж: тап по обочине рядом с добитой тачкой — бросок крюка
	if _try_board_at(screen_pos):
		return
	_deselect_weapon()


## Тап по дороге (не по слотам фуры): находим ближайшую годную к угону тачку.
func _try_board_at(screen_pos: Vector2) -> bool:
	if state.is_game_over or not waves.active:
		return false
	var cam := camera_rig.camera
	var best: Node3D = null
	var best_d := 110.0   # px — щедрая мишень под палец
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not ("boardable" in e) or not e.boardable():
			continue
		if cam.is_position_behind(e.global_position):
			continue
		var sp: Vector2 = cam.unproject_position(e.global_position + Vector3(0, 1.2, 0))
		var d: float = sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	_attempt_board(best)
	return true


## Бросок крюка: успех — тачка целиком в ангар, провал — рейдер озверевает.
func _attempt_board(e: Node3D) -> void:
	e.hook_attempted = true
	e.apply_hook()
	var tpl: Dictionary = CampaignData.TROPHIES.get(e.enemy_type, {})
	if randf() < board_chance:
		_run_trophies[e.enemy_type] = int(_run_trophies.get(e.enemy_type, 0)) + 1
		_boarded_pending[e.enemy_type] = int(_boarded_pending.get(e.enemy_type, 0)) + 1
		hud.flash_message("⚓ УГНАЛИ: %s %s — целёхонькая, в ангар!" % [tpl.get("icon", "🛻"), tpl.get("name", e.enemy_type)])
		sfx.play("earn", 0.8)
		e.capture()
	else:
		e.enrage()
		hud.flash_message("⚓ Крюк сорвался! %s озверела!" % tpl.get("name", "Тачка"))
		sfx.play("jam", 0.6)


func _try_mount(slot: int) -> void:
	var cost: int = WeaponData.DEFS[selected_weapon_type]["cost"]
	if not state.spend(cost):
		hud.flash_message("Мало металлолома!")
		return
	var weapon: Node3D = WeaponScript.new()
	weapon.setup(selected_weapon_type, state)
	weapon.slot_index = slot
	truck.mount_weapon(slot, weapon)
	hud.flash_message("%s установлен" % WeaponData.DEFS[selected_weapon_type]["name"])
	truck.set_slots_highlight(selected_weapon_type != "")
	tutorial.notify("mounted")


func _select_weapon(weapon: Node3D) -> void:
	_deselect_weapon()
	selected_weapon = weapon
	weapon.set_selected(true)
	hud.show_weapon_panel(weapon)


func _deselect_weapon() -> void:
	if is_instance_valid(selected_weapon):
		selected_weapon.set_selected(false)
	selected_weapon = null
	hud.hide_weapon_panel()


func _on_weapon_type_selected(type_id: String) -> void:
	selected_weapon_type = type_id
	truck.set_slots_highlight(true)
	_deselect_weapon()


func _on_upgrade_pressed() -> void:
	if not is_instance_valid(selected_weapon):
		return
	var cost: int = selected_weapon.upgrade_cost()
	if cost < 0:
		hud.flash_message("Максимальный уровень!")
		return
	if state.spend(cost):
		selected_weapon.upgrade()
		hud.show_weapon_panel(selected_weapon)
		hud.flash_message("Прокачано до ур. %d" % (selected_weapon.level + 1))
	else:
		hud.flash_message("Мало металлолома!")


func _on_sell_pressed() -> void:
	if not is_instance_valid(selected_weapon):
		return
	# Бесплатные орудия кладовой не продаются — только разборка за 0
	var refund: int = selected_weapon.sell_value() if not selected_weapon.has_meta("free_start") else 0
	truck.unmount_weapon(selected_weapon.slot_index)
	if refund > 0:
		state.earn(refund)
		hud.flash_message("+%d лома за демонтаж" % refund)
	else:
		hud.flash_message("Разобрано на болты (подарок кладовой)")
	selected_weapon = null
	hud.hide_weapon_panel()


func _on_truck_upgrade(id: String) -> void:
	var lvl: int = truck.upgrade_levels[id]
	var costs: Array = TruckData.DEFS[id]["costs"]
	if lvl >= costs.size():
		hud.flash_message("Максимальный уровень!")
		return
	if not state.spend(costs[lvl]):
		hud.flash_message("Мало металлолома!")
		return
	truck.apply_upgrade(id)
	match id:
		"armor":
			state.add_max_hp(60)
		"engine":
			wasteland.speed_scale = 1.0 + 0.15 * truck.upgrade_levels["engine"]
	hud.flash_message("%s: ур. %d" % [TruckData.DEFS[id]["name"], truck.upgrade_levels[id]])
	hud.refresh_truck_panel()


func _process(delta: float) -> void:
	if truck.repair_rate() > 0.0 and not state.is_game_over:
		state.heal(truck.repair_rate() * delta)
	# Ремкомплект: экстренная починка один раз за рейс
	if _repair_kit_ready and battle_active and state.hp < state.max_hp * 0.25 and not state.is_game_over:
		_repair_kit_ready = false
		state.heal(float(state.max_hp) * 0.35)
		hud.flash_message("🧰 Ремкомплект! +35% HP")
		sfx.play("repair", 0.9)
	# Бортмеханик (мета): штопает броню, пока пыль не поднялась снова
	if battle_active and waves.between_waves and not state.is_game_over:
		var mech_rate := meta.mechanic_rate()
		if mech_rate > 0.0:
			state.heal(mech_rate * delta)
	# Первый угонимый раз в жизни: подсказываем про абордаж один раз на игрока
	if battle_active and not _boarding_hint_shown and not meta.tutorial_seen("boarding"):
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if "boardable" in e and e.boardable():
				_boarding_hint_shown = true
				meta.mark_tutorial("boarding")
				hud.flash_message("⚓ Тачка при смерти — ЖМИ на неё и УГОНЯЙ в ангар!")
				break


## Применить настройки сразу и ко всем новым процедурным эффектам.
func _apply_user_settings() -> void:
	Junk.particle_scale = user_settings.particle_gain()
	Junk.perf_explosion_lights = String(user_settings.get_value("effects")) == "full"
	if sfx != null:
		sfx.master_volume = user_settings.sound_gain()
	if camera_rig != null:
		camera_rig.trauma_scale = user_settings.shake_gain()


func _on_user_setting_changed(_key: String) -> void:
	_apply_user_settings()


## Урон по фуре: тряска и вибрация пропорциональны влетевшему урону.
func _on_truck_damaged(amount: int) -> void:
	camera_rig.add_trauma(clampf(float(amount) * 0.035, 0.15, 0.6))
	user_settings.vibrate(clampi(25 + amount, 30, 90), clampf(float(amount) / 30.0, 0.3, 0.8))


func _on_restart_pressed() -> void:
	# Релоад сцены = свежая фура, снова на карте
	campaign.save_campaign()
	get_tree().reload_current_scene()


func _on_quit_to_map() -> void:
	# Добровольный выход считается провалом рейса: груз режется честно,
	# но игрок гарантированно возвращается на стоянку без зависшей паузы.
	battle_active = false
	campaign.fail_run()
	campaign.save_campaign()
	get_tree().reload_current_scene()
