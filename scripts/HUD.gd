extends CanvasLayer
## HUD пустоши: лом, HP грузовика, волны, арсенал, гараж (апгрейды Crossout).

signal weapon_selected(type_id: String)
signal upgrade_pressed
signal sell_pressed
signal truck_upgrade_pressed(id: String)
signal restart_pressed
signal ability_pressed(id: String)
signal meta_upgrade_pressed(id: String)

const WeaponData := preload("res://scripts/WeaponData.gd")
const TruckData := preload("res://scripts/TruckData.gd")
const AbilityData := preload("res://scripts/AbilityData.gd")
const MetaProgress := preload("res://scripts/MetaProgress.gd")
const CampaignData := preload("res://scripts/CampaignData.gd")

var state: Node
var waves: Node
var truck: Node3D
var abilities: Node = null
var meta: Node = null

var _scrap_label: Label
var _hp_label: Label
var _hp_fill: ColorRect
var _wave_label: Label
var _message_label: Label
var _weapon_panel: PanelContainer
var _weapon_info: Label
var _upgrade_btn: Button
var _build_buttons: Dictionary = {}
var _garage_panel: PanelContainer
var _garage_buttons: Dictionary = {}
var _garage_toggle: Button
var _game_over_panel: CenterContainer
var _ability_buttons: Dictionary = {}
var _blueprints_label: Label
var _earned_label: Label
var _meta_buttons: Dictionary = {}

const PANEL_BG := Color(0.12, 0.09, 0.06, 0.92)
const BORDER := Color(0.55, 0.4, 0.2)
const ACCENT := Color(0.95, 0.75, 0.35)
const TEXT_DIM := Color(0.85, 0.78, 0.65)


func _ready() -> void:
	_build_top_bar()
	_build_bottom_bar()
	_build_weapon_panel()
	_build_garage()
	_build_message()
	_build_game_over()
	_build_ability_bar()

	state.scrap_changed.connect(func(v): _scrap_label.text = "⚙ %d" % v)
	state.hp_changed.connect(_on_hp_changed)
	waves.wave_started.connect(func(i):
		if waves.run_length > 0:
			_wave_label.text = "Волна %d/%d" % [i, waves.run_length]
		else:
			_wave_label.text = "Волна %d" % i)
	waves.wave_cleared.connect(func(i): flash_message("Волна %d отбита!" % i))

	_scrap_label.text = "⚙ %d" % state.scrap
	_on_hp_changed(state.hp, state.max_hp)
	_wave_label.text = "Держись..."


func _process(_delta: float) -> void:
	var t: float = waves.time_to_next_wave()
	if t >= 0.0:
		if waves.wave_index == 0:
			_wave_label.text = "Рейдеры через %.0f" % ceilf(t)
		else:
			_wave_label.text = "Волна %d через %.0f" % [waves.wave_index + 1, ceilf(t)]
	for id in _build_buttons:
		(_build_buttons[id] as Button).disabled = state.scrap < WeaponData.DEFS[id]["cost"]
	if abilities != null:
		for id in _ability_buttons:
			var btn: Button = _ability_buttons[id]
			var def: Dictionary = AbilityData.DEFS[id]
			var left: float = abilities.cooldown_left(id)
			if state.is_game_over or left > 0.0:
				btn.disabled = true
				btn.text = "%s %.0f с" % [def["icon"], left] if not state.is_game_over else "%s %s" % [def["icon"], def["name"]]
			else:
				btn.disabled = false
				btn.text = "%s %s" % [def["icon"], def["name"]]


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_label.text = "%d/%d" % [hp, max_hp]
	var ratio := float(hp) / float(max_hp)
	_hp_fill.custom_minimum_size.x = 120.0 * ratio
	_hp_fill.color = Color(1.0 - ratio * 0.7, ratio * 0.75, 0.1)


func _styled_panel(border := BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	return sb


func _rusty_button(text: String, accent := ACCENT) -> Button:
	var btn := Button.new()
	btn.text = text
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.08, 0.95)
	sb.border_color = accent * 0.8
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.3, 0.2, 0.1, 0.95)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	var sb_d := sb.duplicate() as StyleBoxFlat
	sb_d.bg_color = Color(0.1, 0.08, 0.06, 0.9)
	sb_d.border_color = Color(0.3, 0.25, 0.2)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.38))
	return btn


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -215
	panel.offset_right = 215
	panel.offset_top = 8
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	_scrap_label = Label.new()
	_scrap_label.add_theme_color_override("font_color", ACCENT)
	_scrap_label.add_theme_font_size_override("font_size", 21)
	row.add_child(_scrap_label)

	# HP-бар грузовика
	var hp_box := HBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 6)
	row.add_child(hp_box)
	var hp_icon := Label.new()
	hp_icon.text = "🛠"
	hp_icon.add_theme_font_size_override("font_size", 19)
	hp_box.add_child(hp_icon)
	var bar_bg := PanelContainer.new()
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.05, 0.04, 0.03)
	bg_sb.border_color = BORDER
	bg_sb.set_border_width_all(1)
	bg_sb.set_content_margin_all(2)
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	hp_box.add_child(bar_bg)
	var fill_wrap := Control.new()
	fill_wrap.custom_minimum_size = Vector2(120, 16)
	bar_bg.add_child(fill_wrap)
	_hp_fill = ColorRect.new()
	_hp_fill.custom_minimum_size = Vector2(120, 16)
	_hp_fill.color = Color(0.3, 0.75, 0.1)
	fill_wrap.add_child(_hp_fill)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 15)
	_hp_label.add_theme_color_override("font_color", TEXT_DIM)
	hp_box.add_child(_hp_label)

	_wave_label = Label.new()
	_wave_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.3))
	_wave_label.add_theme_font_size_override("font_size", 19)
	row.add_child(_wave_label)


func _build_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -356
	panel.offset_right = 356
	panel.offset_top = -102
	panel.offset_bottom = -12
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	for id in WeaponData.DEFS:
		var def: Dictionary = WeaponData.DEFS[id]
		var btn := _rusty_button("%s\n⚙ %d" % [def["name"], def["cost"]], def["color"])
		btn.custom_minimum_size = Vector2(88, 68)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func(): weapon_selected.emit(id))
		row.add_child(btn)
		_build_buttons[id] = btn

	# Кнопка гаража
	_garage_toggle = _rusty_button("ГАРАЖ", Color(0.7, 0.85, 0.5))
	_garage_toggle.custom_minimum_size = Vector2(88, 68)
	_garage_toggle.add_theme_font_size_override("font_size", 15)
	_garage_toggle.pressed.connect(_toggle_garage)
	row.add_child(_garage_toggle)


## Вертикальная колонка способностей экипажа слева по центру экрана.
func _build_ability_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 10
	panel.offset_right = 148
	panel.offset_top = -126
	panel.offset_bottom = 126
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Label.new()
	title.text = "ЭКИПАЖ"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	for id in AbilityData.DEFS:
		var def: Dictionary = AbilityData.DEFS[id]
		var btn := _rusty_button("%s %s" % [def["icon"], def["name"]], def["color"])
		btn.custom_minimum_size = Vector2(112, 56)
		btn.add_theme_font_size_override("font_size", 16)
		btn.tooltip_text = def["desc"]
		btn.pressed.connect(func(): ability_pressed.emit(id))
		col.add_child(btn)
		_ability_buttons[id] = btn


func _build_garage() -> void:
	_garage_panel = PanelContainer.new()
	_garage_panel.add_theme_stylebox_override("panel", _styled_panel(Color(0.6, 0.7, 0.4)))
	_garage_panel.anchor_left = 0.5
	_garage_panel.anchor_right = 0.5
	_garage_panel.anchor_top = 1.0
	_garage_panel.anchor_bottom = 1.0
	_garage_panel.offset_left = -290
	_garage_panel.offset_right = 290
	_garage_panel.offset_top = -368
	_garage_panel.offset_bottom = -112
	_garage_panel.visible = false
	add_child(_garage_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_garage_panel.add_child(col)

	var title := Label.new()
	title.text = "🔧 ГАРАЖ — прокачка фуры"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	for id in TruckData.DEFS:
		var def: Dictionary = TruckData.DEFS[id]
		var btn := _rusty_button("", ACCENT)
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func(): truck_upgrade_pressed.emit(id))
		col.add_child(btn)
		_garage_buttons[id] = btn
	refresh_truck_panel()


func refresh_truck_panel() -> void:
	for id in _garage_buttons:
		var def: Dictionary = TruckData.DEFS[id]
		var lvl: int = truck.upgrade_levels[id]
		var costs: Array = def["costs"]
		var btn: Button = _garage_buttons[id]
		if lvl >= costs.size():
			btn.text = "%s [МАКС] — %s" % [def["name"], def["desc"]]
			btn.disabled = true
		else:
			btn.text = "%s [ур.%d→%d] ⚙ %d — %s" % [def["name"], lvl, lvl + 1, costs[lvl], def["desc"]]
			btn.disabled = false


func _toggle_garage() -> void:
	_garage_panel.visible = not _garage_panel.visible
	if _garage_panel.visible:
		refresh_truck_panel()


func _build_weapon_panel() -> void:
	_weapon_panel = PanelContainer.new()
	_weapon_panel.add_theme_stylebox_override("panel", _styled_panel())
	_weapon_panel.anchor_left = 1.0
	_weapon_panel.anchor_right = 1.0
	_weapon_panel.anchor_top = 0.5
	_weapon_panel.anchor_bottom = 0.5
	_weapon_panel.offset_left = -225
	_weapon_panel.offset_right = -10
	_weapon_panel.offset_top = -115
	_weapon_panel.offset_bottom = 115
	_weapon_panel.visible = false
	add_child(_weapon_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_weapon_panel.add_child(col)

	_weapon_info = Label.new()
	_weapon_info.add_theme_font_size_override("font_size", 16)
	_weapon_info.add_theme_color_override("font_color", TEXT_DIM)
	col.add_child(_weapon_info)

	_upgrade_btn = _rusty_button("")
	_upgrade_btn.custom_minimum_size = Vector2(0, 46)
	_upgrade_btn.pressed.connect(func(): upgrade_pressed.emit())
	col.add_child(_upgrade_btn)

	var sell_btn := _rusty_button("Демонтаж", Color(0.9, 0.5, 0.3))
	sell_btn.custom_minimum_size = Vector2(0, 46)
	sell_btn.pressed.connect(func(): sell_pressed.emit())
	col.add_child(sell_btn)


func show_weapon_panel(weapon: Node3D) -> void:
	var def: Dictionary = WeaponData.DEFS[weapon.type_id]
	var st: Dictionary = weapon.stats()
	_weapon_info.text = "%s — ур. %d\nУрон: %d\nДальность: %.0f\nТемп: %.1f/с" % [
		def["name"], weapon.level + 1, st["damage"], st["range"], st["fire_rate"]
	]
	var up: int = weapon.upgrade_cost()
	_upgrade_btn.text = "Прокачать ⚙ %d" % up if up >= 0 else "МАКС. УРОВЕНЬ"
	_upgrade_btn.disabled = up < 0
	_weapon_panel.visible = true


func hide_weapon_panel() -> void:
	_weapon_panel.visible = false


func _build_message() -> void:
	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.16
	_message_label.anchor_bottom = 0.16
	_message_label.offset_left = -300
	_message_label.offset_right = 300
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_message_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	_message_label.add_theme_constant_override("outline_size", 6)
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
	var sb := _styled_panel(Color(0.9, 0.4, 0.2))
	sb.bg_color = Color(0.1, 0.05, 0.02, 0.96)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	_game_over_panel.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	var title := Label.new()
	title.text = "ФУРА УНИЧТОЖЕНА"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	_earned_label = Label.new()
	_earned_label.add_theme_font_size_override("font_size", 20)
	_earned_label.add_theme_color_override("font_color", ACCENT)
	_earned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_earned_label)

	# Мастерская: тратим чертежи на постоянные улучшения
	var shop_title := Label.new()
	shop_title.text = "🔧 МАСТЕРСКАЯ — постоянные улучшения"
	shop_title.add_theme_font_size_override("font_size", 18)
	shop_title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.6))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(shop_title)

	_blueprints_label = Label.new()
	_blueprints_label.add_theme_font_size_override("font_size", 17)
	_blueprints_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_blueprints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_blueprints_label)

	for id in MetaProgress.DEFS:
		var def: Dictionary = MetaProgress.DEFS[id]
		var mbtn := _rusty_button("", Color(0.7, 0.85, 0.5))
		mbtn.custom_minimum_size = Vector2(420, 46)
		mbtn.add_theme_font_size_override("font_size", 15)
		mbtn.pressed.connect(func(): meta_upgrade_pressed.emit(id))
		col.add_child(mbtn)
		_meta_buttons[id] = mbtn

	var btn := _rusty_button("На карту пустоши")
	btn.custom_minimum_size = Vector2(240, 54)
	btn.add_theme_font_size_override("font_size", 19)
	btn.pressed.connect(func(): restart_pressed.emit())
	col.add_child(btn)


## Панель прибытия: город, лом рейса, лут в трюм, закрытые контракты.
func build_arrival_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ArrivalPanel"
	panel.add_theme_stylebox_override("panel", _styled_panel(Color(0.7, 0.85, 0.5)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.visible = false
	add_child(panel)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	return panel


func show_arrival(city_name: String, summary: Dictionary) -> void:
	var panel := find_child("ArrivalPanel", false, false) as PanelContainer
	if panel == null:
		panel = build_arrival_panel()
	var col := panel.get_node("Col")
	for ch in col.get_children():
		ch.queue_free()
	var title := Label.new()
	title.text = "🏁 ПРИБЫТИЕ: %s" % city_name
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var scrap_l := Label.new()
	scrap_l.text = "⚙ Лом рейса: +%d" % int(summary.get("scrap", 0))
	scrap_l.add_theme_font_size_override("font_size", 18)
	scrap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(scrap_l)
	var loot: Dictionary = summary.get("loot", {})
	if not loot.is_empty():
		var ll := Label.new()
		var parts: Array = []
		for res in loot:
			var d: Dictionary = CampaignData.RESOURCES[res]
			parts.append("%s×%d" % [d["icon"], int(loot[res])])
		ll.text = "📦 В трюм: " + ", ".join(parts)
		ll.add_theme_font_size_override("font_size", 16)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ll)
	if int(summary.get("sold", 0)) > 0:
		var sl := Label.new()
		sl.text = "💰 Не влезло, продано кустарям: +⚙%d" % int(summary["sold"])
		sl.add_theme_font_size_override("font_size", 15)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sl)
	for c in summary.get("done", []):
		var cl := Label.new()
		cl.text = "✅ Контракт закрыт: +⚙%d" % int(c["reward"])
		cl.add_theme_font_size_override("font_size", 16)
		cl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.6))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cl)
	var btn := _rusty_button("К стоянке (карта)", Color(0.7, 0.85, 0.5))
	btn.custom_minimum_size = Vector2(0, 54)
	btn.add_theme_font_size_override("font_size", 19)
	btn.pressed.connect(func(): restart_pressed.emit())
	col.add_child(btn)
	panel.visible = true


func show_game_over(wave: int, earned: int = 0) -> void:
	var subtitle := _game_over_panel.find_child("Subtitle", true, false) as Label
	subtitle.text = "Вы отбились от %d волн рейдеров" % wave
	_earned_label.text = "+ 📐 %d чертежей добыто из руин" % earned
	refresh_meta_panel()
	_game_over_panel.visible = true


## Обновляет кнопки мастерской: уровни, цены, доступность.
func refresh_meta_panel() -> void:
	if meta == null:
		return
	_blueprints_label.text = "📐 Чертежей в наличии: %d" % meta.blueprints
	for id in _meta_buttons:
		var def: Dictionary = MetaProgress.DEFS[id]
		var lvl: int = meta.level_of(id)
		var cost: int = meta.cost_of(id)
		var btn: Button = _meta_buttons[id]
		if cost < 0:
			btn.text = "%s %s [МАКС] — %s" % [def["icon"], def["name"], def["desc"]]
			btn.disabled = true
		else:
			btn.text = "%s %s [ур.%d→%d, 📐%d] — %s" % [def["icon"], def["name"], lvl, lvl + 1, cost, def["desc"]]
			btn.disabled = meta.blueprints < cost
