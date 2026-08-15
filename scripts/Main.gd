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
const RoadEvents := preload("res://scripts/RoadEvents.gd")
const MetaProgress := preload("res://scripts/MetaProgress.gd")
const Campaign := preload("res://scripts/Campaign.gd")
const CampaignData := preload("res://scripts/CampaignData.gd")
const MapScreen := preload("res://scripts/MapScreen.gd")

var truck: Truck
var wasteland: Wasteland
var camera_rig: CameraRig
var state: GameState
var waves: WaveManager
var hud: HUD
var abilities: Abilities
var events: RoadEvents
var meta: MetaProgress
var campaign: Campaign
var map_screen: MapScreen
var world_env: Environment
var _earned_blueprints := 0
## Рейс идёт (тапы по сцене работают только в бою)
var battle_active := false
## Город назначения текущего рейса
var _destination := ""
## Лут, набранный в рейсе (в трюм попадёт по прибытии)
var _run_loot: Dictionary = {}
## Ремкомплект из крафта: раз за рейс автопочинка при HP < 25%
var _repair_kit_ready := false

var selected_weapon_type: String = ""
var selected_weapon: Node3D = null


func _ready() -> void:
	_setup_environment()
	_setup_lights()

	state = GameState.new()
	state.name = "GameState"
	add_child(state)

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

	hud = HUD.new()
	hud.name = "HUD"
	hud.state = state
	hud.waves = waves
	hud.truck = truck
	hud.abilities = abilities
	hud.meta = meta
	add_child(hud)

	hud.weapon_selected.connect(_on_weapon_type_selected)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.truck_upgrade_pressed.connect(_on_truck_upgrade)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.ability_pressed.connect(abilities.try_activate)
	abilities.feedback.connect(hud.flash_message)
	# Кампания: карта пустоши, экономика, контракты
	campaign = Campaign.new()
	campaign.name = "Campaign"
	campaign.meta = meta
	add_child(campaign)

	map_screen = MapScreen.new()
	map_screen.name = "MapScreen"
	map_screen.campaign = campaign
	add_child(map_screen)
	map_screen.travel_requested.connect(_on_travel)

	waves.boss_event.connect(hud.flash_message)
	events.announced.connect(hud.flash_message)
	hud.meta_upgrade_pressed.connect(_on_meta_upgrade)
	state.game_over.connect(_on_game_over)
	waves.run_completed.connect(_on_run_completed)
	waves.enemy_killed.connect(_on_enemy_killed)

	# Старт — на карте; бой начинается с выбора маршрута
	hud.visible = false
	events.waves = waves


## Игрок выбрал маршрут на карте — запускаем рейс.
func _on_travel(city_id: String) -> void:
	var route: Array = CampaignData.route_between(campaign.location, city_id)
	if route.is_empty():
		return
	_destination = city_id
	waves.run_length = 4 + int(route[0]) * 2
	waves.danger = float(route[1])
	_run_loot.clear()
	map_screen.hide_screen()
	hud.visible = true
	battle_active = true
	hud.flash_message("🚚 Рейс: %s → %s" % [
		CampaignData.CITIES[campaign.location]["name"],
		CampaignData.CITIES[city_id]["name"]])
	_apply_campaign_effects()
	waves.start()


## Постоянные техи и staged-модули применяются один раз на старте рейса.
func _apply_campaign_effects() -> void:
	if "plating" in campaign.research_done:
		state.add_max_hp(40)
	if "copper_heads" in campaign.research_done:
		state.damage_mult = 1.12
	if "convoy" in campaign.research_done:
		waves.bonus_mult = 1.15
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
	for item in campaign.pop_pending():
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


## Доехали: сворачиваем лом и лут в кампанию, показываем сводку.
func _on_run_completed() -> void:
	battle_active = false
	var summary: Dictionary = campaign.arrive(_destination, state.scrap, _run_loot)
	hud.show_arrival(CampaignData.CITIES[_destination]["name"], summary)


## Убийство рейдера: баунти-контракты + шанс лута в трюм.
func _on_enemy_killed() -> void:
	var done: Array = campaign.note_kill()
	for c in done:
		hud.flash_message("✅ Контракт выполнен! +⚙%d" % c["reward"])
	# Лут: 25% шанс на ресурс с убитого (металл чаще всего)
	if randf() < 0.25:
		var roll := randf()
		var res := "metal"
		if roll > 0.93:
			res = "chips"
		elif roll > 0.80:
			res = "fuel"
		elif roll > 0.68:
			res = "ammo"
		elif roll > 0.55:
			res = "food"
		elif roll > 0.45:
			res = "water"
		_run_loot[res] = int(_run_loot.get(res, 0)) + 1


## Конец рейса смертью фуры: чертежи капают, груз в трюме пополам.
func _on_game_over() -> void:
	battle_active = false
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
	_deselect_weapon()


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
	var refund: int = selected_weapon.sell_value()
	truck.unmount_weapon(selected_weapon.slot_index)
	state.earn(refund)
	hud.flash_message("+%d лома за демонтаж" % refund)
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


func _on_restart_pressed() -> void:
	# Релоад сцены = свежая фура, снова на карте
	campaign.save_campaign()
	get_tree().reload_current_scene()
