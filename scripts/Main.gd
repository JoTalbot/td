extends Node3D
## Корневой узел игры: собирает окружение, доску, камеру, менеджеров и HUD.

const Board := preload("res://scripts/Board.gd")
const CameraRig := preload("res://scripts/CameraRig.gd")
const GameState := preload("res://scripts/GameState.gd")
const WaveManager := preload("res://scripts/WaveManager.gd")
const HUD := preload("res://scripts/HUD.gd")
const TowerScript := preload("res://scripts/Tower.gd")
const TowerData := preload("res://scripts/TowerData.gd")

var board: Board
var camera_rig: CameraRig
var state: GameState
var waves: WaveManager
var hud: HUD

var selected_tower_type: String = ""
var selected_tower: Node3D = null


func _ready() -> void:
	_setup_environment()
	_setup_lights()

	state = GameState.new()
	state.name = "GameState"
	add_child(state)

	board = Board.new()
	board.name = "Board"
	add_child(board)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.focus_on(board.center_position())

	waves = WaveManager.new()
	waves.name = "WaveManager"
	waves.board = board
	waves.state = state
	add_child(waves)

	hud = HUD.new()
	hud.name = "HUD"
	hud.state = state
	hud.waves = waves
	add_child(hud)

	hud.tower_selected.connect(_on_tower_type_selected)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.restart_pressed.connect(_on_restart_pressed)
	state.game_over.connect(func(): hud.show_game_over(waves.wave_index))

	waves.start()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.5)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.1, 0.25)
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.15

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color(0.7, 0.8, 1.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30.0, 140.0, 0.0)
	rim.light_color = Color(1.0, 0.3, 0.7)
	rim.light_energy = 0.35
	add_child(rim)


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
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return
	var t := -from.y / dir.y
	if t <= 0.0:
		return
	var hit := from + dir * t
	var cell := board.world_to_cell(hit)
	if not board.is_inside(cell):
		_deselect_tower()
		return

	var existing := board.tower_at(cell)
	if existing != null:
		_select_tower(existing)
		return

	if selected_tower_type != "" and board.is_buildable(cell):
		_try_build(cell)
	else:
		_deselect_tower()


func _try_build(cell: Vector2i) -> void:
	var cost: int = TowerData.DEFS[selected_tower_type]["cost"]
	if not state.spend(cost):
		hud.flash_message("Недостаточно кредитов!")
		return
	var tower: Node3D = TowerScript.new()
	tower.setup(selected_tower_type, board, state)
	board.place_tower(cell, tower)
	hud.flash_message("%s построена" % TowerData.DEFS[selected_tower_type]["name"])


func _select_tower(tower: Node3D) -> void:
	_deselect_tower()
	selected_tower = tower
	tower.set_selected(true)
	hud.show_tower_panel(tower)


func _deselect_tower() -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = null
	hud.hide_tower_panel()


func _on_tower_type_selected(type_id: String) -> void:
	selected_tower_type = type_id
	_deselect_tower()


func _on_upgrade_pressed() -> void:
	if not is_instance_valid(selected_tower):
		return
	var cost: int = selected_tower.upgrade_cost()
	if cost < 0:
		hud.flash_message("Максимальный уровень!")
		return
	if state.spend(cost):
		selected_tower.upgrade()
		hud.show_tower_panel(selected_tower)
		hud.flash_message("Улучшено до ур. %d" % (selected_tower.level + 1))
	else:
		hud.flash_message("Недостаточно кредитов!")


func _on_sell_pressed() -> void:
	if not is_instance_valid(selected_tower):
		return
	var refund: int = selected_tower.sell_value()
	board.remove_tower(selected_tower.cell)
	state.earn(refund)
	hud.flash_message("+%d кредитов за продажу" % refund)
	_deselect_tower()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
