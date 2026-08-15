extends CanvasLayer
## HUD: ресурсы, волны, панель строительства, панель башни, game over.

signal tower_selected(type_id: String)
signal upgrade_pressed
signal sell_pressed
signal restart_pressed

const TowerData := preload("res://scripts/TowerData.gd")

var state: Node
var waves: Node

var _money_label: Label
var _lives_label: Label
var _wave_label: Label
var _message_label: Label
var _tower_panel: PanelContainer
var _tower_info: Label
var _upgrade_btn: Button
var _build_buttons: Dictionary = {}
var _game_over_panel: CenterContainer

const PANEL_BG := Color(0.05, 0.07, 0.16, 0.85)
const ACCENT := Color(0.35, 0.8, 1.0)


func _ready() -> void:
	_build_top_bar()
	_build_bottom_bar()
	_build_tower_panel()
	_build_message()
	_build_game_over()

	state.money_changed.connect(func(v): _money_label.text = "⬡ %d" % v)
	state.lives_changed.connect(func(v): _lives_label.text = "♥ %d" % v)
	waves.wave_started.connect(func(i): _wave_label.text = "Волна %d" % i)
	waves.wave_cleared.connect(func(i): flash_message("Волна %d зачищена! +%d" % [i, 30 + i * 5]))

	_money_label.text = "⬡ %d" % state.money
	_lives_label.text = "♥ %d" % state.lives
	_wave_label.text = "Приготовьтесь..."


func _process(_delta: float) -> void:
	var t: float = waves.time_to_next_wave()
	if t >= 0.0 and waves.wave_index >= 0:
		if waves.wave_index == 0:
			_wave_label.text = "Старт через %.0f" % ceilf(t)
		else:
			_wave_label.text = "Волна %d через %.0f" % [waves.wave_index + 1, ceilf(t)]
	# Доступность кнопок по деньгам
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]
		btn.disabled = state.money < TowerData.DEFS[id]["cost"]


func _styled_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = ACCENT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = 8
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	_money_label = Label.new()
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_money_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_money_label)

	_lives_label = Label.new()
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5))
	_lives_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_lives_label)

	_wave_label = Label.new()
	_wave_label.add_theme_color_override("font_color", ACCENT)
	_wave_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_wave_label)


func _build_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -100
	panel.offset_bottom = -12
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	for id in TowerData.DEFS:
		var def: Dictionary = TowerData.DEFS[id]
		var btn := Button.new()
		btn.text = "%s\n⬡ %d" % [def["name"], def["cost"]]
		btn.custom_minimum_size = Vector2(130, 70)
		btn.add_theme_font_size_override("font_size", 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(def["color"].r * 0.2, def["color"].g * 0.2, def["color"].b * 0.2, 0.9)
		sb.border_color = def["color"]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(def["color"].r * 0.35, def["color"].g * 0.35, def["color"].b * 0.35, 0.95)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_h)
		btn.pressed.connect(func(): tower_selected.emit(id))
		row.add_child(btn)
		_build_buttons[id] = btn


func _build_tower_panel() -> void:
	_tower_panel = PanelContainer.new()
	_tower_panel.add_theme_stylebox_override("panel", _styled_panel())
	_tower_panel.anchor_left = 1.0
	_tower_panel.anchor_right = 1.0
	_tower_panel.anchor_top = 0.5
	_tower_panel.anchor_bottom = 0.5
	_tower_panel.offset_left = -230
	_tower_panel.offset_right = -10
	_tower_panel.offset_top = -110
	_tower_panel.offset_bottom = 110
	_tower_panel.visible = false
	add_child(_tower_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_tower_panel.add_child(col)

	_tower_info = Label.new()
	_tower_info.add_theme_font_size_override("font_size", 17)
	col.add_child(_tower_info)

	_upgrade_btn = Button.new()
	_upgrade_btn.custom_minimum_size = Vector2(0, 48)
	_upgrade_btn.pressed.connect(func(): upgrade_pressed.emit())
	col.add_child(_upgrade_btn)

	var sell_btn := Button.new()
	sell_btn.text = "Продать"
	sell_btn.custom_minimum_size = Vector2(0, 48)
	sell_btn.pressed.connect(func(): sell_pressed.emit())
	col.add_child(sell_btn)


func show_tower_panel(tower: Node3D) -> void:
	var def: Dictionary = TowerData.DEFS[tower.type_id]
	var st: Dictionary = tower.stats()
	_tower_info.text = "%s — ур. %d\nУрон: %d\nДальность: %.1f\nСкорострельность: %.1f/с" % [
		def["name"], tower.level + 1, st["damage"], st["range"], st["fire_rate"]
	]
	var up: int = tower.upgrade_cost()
	_upgrade_btn.text = "Улучшить ⬡ %d" % up if up >= 0 else "МАКС. УРОВЕНЬ"
	_upgrade_btn.disabled = up < 0
	_tower_panel.visible = true


func hide_tower_panel() -> void:
	_tower_panel.visible = false


func _build_message() -> void:
	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.18
	_message_label.anchor_bottom = 0.18
	_message_label.offset_left = -300
	_message_label.offset_right = 300
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 26)
	_message_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_message_label.modulate.a = 0.0
	add_child(_message_label)


func flash_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_message_label, "modulate:a", 0.0, 0.6)


func _build_game_over() -> void:
	_game_over_panel = CenterContainer.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.visible = false
	add_child(_game_over_panel)

	var panel := PanelContainer.new()
	var sb := _styled_panel()
	sb.bg_color = Color(0.03, 0.02, 0.08, 0.95)
	sb.border_color = Color(1.0, 0.3, 0.5)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	_game_over_panel.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	var title := Label.new()
	title.name = "Title"
	title.text = "БАЗА УНИЧТОЖЕНА"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	var btn := Button.new()
	btn.text = "Играть снова"
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): restart_pressed.emit())
	col.add_child(btn)


func show_game_over(wave: int) -> void:
	var subtitle := _game_over_panel.find_child("Subtitle", true, false) as Label
	subtitle.text = "Вы продержались %d волн" % wave
	_game_over_panel.visible = true
