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

var truck: Truck
var wasteland: Wasteland
var camera_rig: CameraRig
var state: GameState
var waves: WaveManager
var hud: HUD
var abilities: Abilities
var events: RoadEvents
var world_env: Environment

var selected_weapon_type: String = ""
var selected_weapon: Node3D = null


func _ready() -> void:
	_setup_environment()
	_setup_lights()

	state = GameState.new()
	state.name = "GameState"
	add_child(state)

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
	add_child(hud)

	hud.weapon_selected.connect(_on_weapon_type_selected)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.truck_upgrade_pressed.connect(_on_truck_upgrade)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.ability_pressed.connect(abilities.try_activate)
	abilities.feedback.connect(hud.flash_message)
	waves.boss_event.connect(hud.flash_message)
	events.announced.connect(hud.flash_message)
	state.game_over.connect(func(): hud.show_game_over(waves.wave_index))

	waves.start()


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
	if state.is_game_over:
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


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
