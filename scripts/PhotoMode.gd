extends CanvasLayer
## Фоторежим: скрывает игровой HUD, ставит бой на паузу и сохраняет PNG в user://.

const RustButton := preload("res://scripts/RustButton.gd")
const RustHeader := preload("res://scripts/RustHeader.gd")

var camera_rig: Node
var weather: Node
var hud: CanvasLayer
var map_screen: CanvasLayer
var active := false
var _root: Control
var _toolbar: PanelContainer
var _status: Label
var _hud_was_visible := false
var _map_was_visible := false


func setup(p_camera: Node, p_weather: Node, p_hud: CanvasLayer, p_map: CanvasLayer) -> void:
	camera_rig = p_camera
	weather = p_weather
	hud = p_hud
	map_screen = p_map


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func enter() -> void:
	if active:
		return
	active = true
	_hud_was_visible = hud != null and hud.visible
	_map_was_visible = map_screen != null and map_screen.visible
	if hud != null:
		hud.visible = false
	if map_screen != null:
		map_screen.visible = false
	_root.visible = true
	get_tree().paused = true
	_status.text = "DRAG — ПОВОРОТ • PINCH — ЗУМ"


func exit() -> void:
	if not active:
		return
	active = false
	_root.visible = false
	if hud != null:
		hud.visible = _hud_was_visible
	if map_screen != null:
		map_screen.visible = _map_was_visible
	get_tree().paused = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_toolbar = PanelContainer.new()
	_toolbar.anchor_left = 0.5
	_toolbar.anchor_right = 0.5
	_toolbar.offset_left = -330
	_toolbar.offset_right = 330
	_toolbar.offset_top = 24
	_toolbar.offset_bottom = 122
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.05, 0.03, 0.9)
	panel.border_color = Color(0.72, 0.42, 0.18)
	panel.set_border_width_all(3)
	panel.set_content_margin_all(10)
	_toolbar.add_theme_stylebox_override("panel", panel)
	_root.add_child(_toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_toolbar.add_child(row)
	var close := _button("ВЫХОД")
	close.pressed.connect(exit)
	row.add_child(close)
	var shot := _button("СНИМОК")
	shot.pressed.connect(_save_screenshot)
	row.add_child(shot)
	var cycle := _button("ПОГОДА")
	cycle.pressed.connect(_cycle_weather)
	row.add_child(cycle)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.95, 0.82, 0.62))
	row.add_child(_status)


func _button(text: String) -> Button:
	var button := RustButton.new()
	button.setup(text, Color(0.72, 0.42, 0.18))
	button.custom_minimum_size = Vector2(130, 58)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _cycle_weather() -> void:
	if weather == null:
		return
	var order := ["clear", "dust", "ash"]
	var index: int = order.find(String(weather.current))
	weather._apply(order[(index + 1) % order.size()])
	_status.text = "ПОГОДА: %s" % String(weather.current).to_upper()


func _save_screenshot() -> void:
	_toolbar.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://rustroad_%s.png" % stamp
	var error := image.save_png(path)
	_toolbar.visible = true
	_status.text = "СОХРАНЕНО: %s" % path if error == OK else "ОШИБКА СОХРАНЕНИЯ"


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_cancel"):
		exit()
		get_viewport().set_input_as_handled()
