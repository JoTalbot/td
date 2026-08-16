extends CanvasLayer
## Карта пустоши: города, дороги, выбор рейса, рынок и контракты в городе.
## Всё рисуется кодом — процедурный UI в духе проекта.

signal travel_requested(city_id: String)
## Игрок сменил корпус в шоуруме — Main пересобирает платформу.
signal hull_changed

const CampaignData := preload("res://scripts/CampaignData.gd")
const RustButton := preload("res://scripts/RustButton.gd")
const RustHeader := preload("res://scripts/RustHeader.gd")
const CityMarker := preload("res://scripts/CityMarker.gd")
const SafeArea := preload("res://scripts/SafeArea.gd")

var campaign: Node = null
var settings: Node = null
var sfx: Node = null          # Main ставит синтезатор звука

const PANEL_BG := Color(0.12, 0.09, 0.06, 0.96)
const BORDER := Color(0.55, 0.4, 0.2)
const ACCENT := Color(0.95, 0.75, 0.35)
const TEXT_DIM := Color(0.85, 0.78, 0.65)

var _loc_label: Label
var _wallet_label: Label
var _cargo_label: Label
var _day_label: Label
var _map_viewport: Control
var _map_stage: Control
var _map_area: Control
var _city_buttons: Dictionary = {}
var _map_zoom := 1.0
var _map_pan := Vector2.ZERO
var _map_touches: Dictionary = {}
var _map_pinch_distance := 0.0
var _map_mouse_dragging := false
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_body: VBoxContainer
var _nav_buttons: Dictionary = {}
var _safe_insets := Vector4.ZERO
var _selected := ""
var _view := "info"   # info | market | contracts | hangar | base | lab | showroom
var _intel_message := ""


func _ready() -> void:
	layer = 20
	_safe_insets = SafeArea.insets(get_viewport().get_visible_rect().size)
	_build_chrome()
	_build_map()
	_select(campaign.location)


func show_screen() -> void:
	visible = true
	_refresh_top()
	_redraw_map()
	_select(_selected)


func hide_screen() -> void:
	visible = false


func _styled_panel(border := BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 5
	sb.border_width_bottom = 5
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0.02, 0.01, 0.005, 0.8)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	return sb


func _font(base: int) -> int:
	return settings.font_size(base) if settings != null else base


func _rusty_button(text: String, accent := ACCENT) -> Button:
	var btn := RustButton.new()
	btn.setup(text, accent)
	btn.add_theme_font_size_override("font_size", _font(20))
	btn.pressed.connect(func(): if sfx != null: sfx.play("click", 0.35))
	return btn


func _build_chrome() -> void:
	# Фон — выжженный пергамент
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Верхняя панель: положение, кошелёк, трюм, день
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _styled_panel())
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = 8 + _safe_insets.x
	top.offset_right = -8 - _safe_insets.z
	top.offset_top = 8 + _safe_insets.y
	top.offset_bottom = 160 + _safe_insets.y
	add_child(top)
	# Две строки не дают крупным статусам слипаться на узком портретном экране.
	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 5)
	top.add_child(top_col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_col.add_child(row)
	_loc_label = _mk_label(row, 24, ACCENT)
	_status_icon(row, "scrap", 30)
	_wallet_label = _mk_label(row, 24, Color(0.95, 0.75, 0.35))
	_status_icon(row, "cargo", 30)
	_cargo_label = _mk_label(row, 24, Color(0.8, 0.85, 0.6))
	var settings_btn := _rusty_button("⚙", Color(0.55, 0.72, 0.82))
	settings_btn.custom_minimum_size = Vector2(62, 58)
	settings_btn.tooltip_text = "Настройки"
	settings_btn.pressed.connect(func(): _open_view("settings"))
	row.add_child(settings_btn)
	var day_row := HBoxContainer.new()
	day_row.alignment = BoxContainer.ALIGNMENT_CENTER
	day_row.add_theme_constant_override("separation", 8)
	top_col.add_child(day_row)
	_status_icon(day_row, "record", 28)
	_day_label = _mk_label(day_row, 22, TEXT_DIM)
	_day_label.custom_minimum_size = Vector2(520, 0)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _mk_label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", _font(size))
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Маленькая нарисованная иконка в начало строки списка.
## Возвращает true, если ассет нашёлся (тогда эмодзи в тексте можно опустить).
func _status_icon(parent: Control, id: String, px: int = 30) -> TextureRect:
	var tr := TextureRect.new()
	var path := "res://assets/ui/st_%s.svg" % id
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


func _add_row_icon(row: HBoxContainer, path: String, px: int = 30) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tr)
	row.move_child(tr, 0)
	return true


func _refresh_top() -> void:
	var c: Dictionary = CampaignData.CITIES[campaign.location]
	_loc_label.text = String(c["name"])
	_wallet_label.text = "ЛОМ %d" % campaign.wallet
	_cargo_label.text = "ТРЮМ %d/%d" % [campaign.cargo_used(), campaign.cargo_cap()]
	var mods_txt := ""
	for m in campaign.daily_mods():
		var d: Dictionary = CampaignData.DAILY_MODS[m]
		mods_txt += "  %s%s" % [d["icon"], d["name"]]
	var season_id: String = campaign.season()
	var season_tip := ""
	if season_id != "":
		var sd: Dictionary = CampaignData.SEASONS[season_id]
		mods_txt += "  %s %s" % [sd["icon"], sd["name"]]
		season_tip = "%s %s: %s\n" % [sd["icon"], sd["name"], sd["desc"]]
	var best: int = campaign.meta.best_wave if campaign.meta != null else 0
	_day_label.text = "ДЕНЬ %d%s    РЕКОРД %d" % [campaign.day, mods_txt, best]
	_day_label.tooltip_text = season_tip
	for m in campaign.daily_mods():
		_day_label.tooltip_text += "%s: %s\n" % [CampaignData.DAILY_MODS[m]["name"], CampaignData.DAILY_MODS[m]["desc"]]


func _build_map() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var area_size := Vector2(
		viewport_size.x - 16.0 - _safe_insets.x - _safe_insets.z,
		maxf(370.0, 506.0 - _safe_insets.y - _safe_insets.w))
	var area_pos := Vector2(8 + _safe_insets.x, 170 + _safe_insets.y)
	# Окно обрезает увеличенную карту, а stage двигает фон, дороги и города вместе.
	_map_viewport = Control.new()
	_map_viewport.position = area_pos
	_map_viewport.size = area_size
	_map_viewport.clip_contents = true
	_map_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_viewport.gui_input.connect(_on_map_gui_input)
	add_child(_map_viewport)
	_map_stage = Control.new()
	_map_stage.size = area_size
	_map_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_viewport.add_child(_map_stage)
	# Рисованный фон пустоши под дорогами и кнопками городов
	var bg_path := "res://assets/ui/map_bg.jpg"
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = area_size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_stage.add_child(bg)
	_map_area = MapCanvas.new()
	_map_area.size = area_size
	_map_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_stage.add_child(_map_area)
	for id in CampaignData.CITIES:
		var c: Dictionary = CampaignData.CITIES[id]
		var marker := CityMarker.new()
		var cicon: String = "res://assets/ui/c_%s.png" % id
		var city_texture: Texture2D = load(cicon) if ResourceLoader.exists(cicon) else null
		marker.setup(String(c["name"]), city_texture, _font(18))
		var city_size := marker.custom_minimum_size
		var city_pos: Vector2 = c["pos"] * area_size - city_size * 0.5
		city_pos.x = clampf(city_pos.x, 0.0, area_size.x - city_size.x)
		city_pos.y = clampf(city_pos.y, 0.0, area_size.y - city_size.y)
		marker.pressed.connect(func(): _select(id))
		_map_area.add_child(marker)
		# После входа в дерево принудительно ужимаем длинные названия до маркера.
		marker.size = city_size
		marker.position = city_pos
		marker.mouse_filter = Control.MOUSE_FILTER_PASS
		_city_buttons[id] = marker
	var reset_zoom := _rusty_button("1:1", Color(0.55, 0.72, 0.82))
	reset_zoom.custom_minimum_size = Vector2(72, 58)
	reset_zoom.position = Vector2(area_size.x - 80, 8)
	reset_zoom.tooltip_text = "Сбросить масштаб карты"
	reset_zoom.pressed.connect(_reset_map_transform)
	_map_viewport.add_child(reset_zoom)
	_restore_map_transform()

	# Нижний лист: инфо / рынок / контракты
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", _styled_panel())
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 8 + _safe_insets.x
	_sheet.offset_right = -8 - _safe_insets.z
	_sheet.offset_top = -594 - _safe_insets.w
	_sheet.offset_bottom = -10 - _safe_insets.w
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_sheet.add_child(col)
	_sheet_title = RustHeader.new()
	(_sheet_title as RustHeader).setup("КАРТА ПУСТОШИ", _font(25), ACCENT)
	col.add_child(_sheet_title)
	# Закреплённые вкладки остаются на месте, пока длинное содержимое крутится.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(nav)
	for tab in [
		["info", "← ГОРОД", Color(0.75, 0.7, 0.5)],
		["market", "РЫНОК", Color(0.72, 0.84, 0.48)],
		["contracts", "КОНТРАКТЫ", Color(0.82, 0.66, 0.34)],
		["hangar", "АНГАР", Color(0.78, 0.58, 0.35)],
	]:
		var tab_id: String = tab[0]
		var tab_btn := _rusty_button(tab[1], tab[2])
		tab_btn.custom_minimum_size = Vector2(156, 58)
		tab_btn.add_theme_font_size_override("font_size", _font(18))
		tab_btn.toggle_mode = true
		tab_btn.pressed.connect(func(): _open_view(tab_id))
		nav.add_child(tab_btn)
		_nav_buttons[tab_id] = tab_btn
	# Лист может быть длинным (ангар, лаборатория) — крутим вертикально
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_sheet_body = VBoxContainer.new()
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_sheet_body)


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_map_touches[event.index] = event.position
		else:
			_map_touches.erase(event.index)
			if _map_touches.is_empty():
				_save_map_transform()
		if _map_touches.size() == 2:
			var touch_points := _map_touches.values()
			_map_pinch_distance = (touch_points[0] as Vector2).distance_to(touch_points[1] as Vector2)
		else:
			_map_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		_map_touches[event.index] = event.position
		if _map_touches.size() >= 2:
			var points := _map_touches.values()
			var p0 := points[0] as Vector2
			var p1 := points[1] as Vector2
			var distance := p0.distance_to(p1)
			if _map_pinch_distance > 0.0:
				_set_map_zoom(_map_zoom * distance / _map_pinch_distance, (p0 + p1) * 0.5)
			_map_pinch_distance = distance
		else:
			_map_pan += event.relative
			_apply_map_transform()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_map_mouse_dragging = event.pressed
			if not event.pressed:
				_save_map_transform()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_map_zoom(_map_zoom * 1.15, event.position)
			_save_map_transform()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_map_zoom(_map_zoom / 1.15, event.position)
			_save_map_transform()
	elif event is InputEventMouseMotion and _map_mouse_dragging:
		_map_pan += event.relative
		_apply_map_transform()


func _set_map_zoom(value: float, focus: Vector2) -> void:
	var old_zoom := _map_zoom
	_map_zoom = clampf(value, 1.0, 2.4)
	if is_equal_approx(old_zoom, _map_zoom):
		return
	var world_point := (focus - _map_pan) / old_zoom
	_map_pan = focus - world_point * _map_zoom
	_apply_map_transform()


func _apply_map_transform() -> void:
	if _map_stage == null or _map_viewport == null:
		return
	var scaled := _map_stage.size * _map_zoom
	_map_pan.x = clampf(_map_pan.x, minf(0.0, _map_viewport.size.x - scaled.x), 0.0)
	_map_pan.y = clampf(_map_pan.y, minf(0.0, _map_viewport.size.y - scaled.y), 0.0)
	_map_stage.scale = Vector2.ONE * _map_zoom
	_map_stage.position = _map_pan


func _restore_map_transform() -> void:
	if settings == null:
		return
	var saved: Dictionary = settings.map_view()
	_map_zoom = clampf(float(saved.get("zoom", 1.0)), 1.0, 2.4)
	_map_pan = saved.get("pan", Vector2.ZERO)
	_apply_map_transform()


func _save_map_transform() -> void:
	if settings != null:
		settings.save_map_view(_map_zoom, _map_pan)


func _reset_map_transform() -> void:
	_map_zoom = 1.0
	_map_pan = Vector2.ZERO
	_apply_map_transform()
	_save_map_transform()


func _redraw_map() -> void:
	for id in _city_buttons:
		var marker: CityMarker = _city_buttons[id]
		marker.visible = campaign.is_city_discovered(id)
		if marker.visible:
			marker.set_marks(id == campaign.location, not campaign.poi_at(id).is_empty())
			marker.set_story_ending(campaign.story_ending(id))
	(_map_area as MapCanvas).set_discovered(campaign.discovered_cities)
	(_map_area as MapCanvas).set_mastery(campaign.route_mastery)
	(_map_area as MapCanvas).set_route_control(campaign.route_control)
	var selected_to := ""
	if _selected != campaign.location and not CampaignData.route_between(campaign.location, _selected).is_empty():
		selected_to = _selected
	(_map_area as MapCanvas).select_route(campaign.location, selected_to)
	_map_area.queue_redraw()


func _select(id: String) -> void:
	_selected = id
	_open_view("info")


func _open_view(view_id: String) -> void:
	_view = view_id
	_render_sheet()


func _clear_body() -> void:
	for ch in _sheet_body.get_children():
		ch.queue_free()


func _render_sheet() -> void:
	_clear_body()
	var c: Dictionary = CampaignData.CITIES[_selected]
	var is_here: bool = _selected == campaign.location
	var route: Array = CampaignData.route_between(campaign.location, _selected)
	_refresh_top()
	_redraw_map()
	for tab_id in _nav_buttons:
		var tab_btn: Button = _nav_buttons[tab_id]
		tab_btn.set_pressed_no_signal(tab_id == _view)
	# Вложенные экраны базы возвращаются закреплённой вкладкой «ГОРОД».
	if not _nav_buttons.has(_view):
		(_nav_buttons["info"] as Button).set_pressed_no_signal(false)

	if _view == "market":
		_sheet_title.text = "РЫНОК — %s" % c["name"]
		_render_market(is_here)
	elif _view == "contracts":
		_sheet_title.text = "КОНТРАКТЫ — %s" % c["name"]
		_render_contracts(is_here)
	elif _view == "base":
		_sheet_title.text = "БАЗА"
		_render_base(is_here)
	elif _view == "lab":
		_sheet_title.text = "ЛАБОРАТОРИЯ"
		_render_lab(is_here)
	elif _view == "hangar":
		_sheet_title.text = "АНГАР"
		_render_hangar(is_here)
	elif _view == "showroom":
		_sheet_title.text = "КОРПУСА"
		_render_showroom(is_here)
	elif _view == "settings":
		_sheet_title.text = "НАСТРОЙКИ"
		_render_settings()
	elif _view == "achievements":
		_sheet_title.text = "ДОСТИЖЕНИЯ"
		_render_achievements()
	elif _view == "warlog":
		_sheet_title.text = "ЖУРНАЛ ВОЙНЫ"
		_render_war_log()
	else:
		_sheet_title.text = String(c["name"])
		_render_info(c, is_here, route)
	_sheet_body.modulate.a = 0.35
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_sheet_body, "modulate:a", 1.0, 0.16)


func _render_info(c: Dictionary, is_here: bool, route: Array) -> void:
	var desc := _mk_label(_sheet_body, 20, TEXT_DIM)
	desc.text = c["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spec := _mk_label(_sheet_body, 19, Color(0.8, 0.85, 0.6))
	var cheap: Array = []
	for r in c["mods"]:
		if float(c["mods"][r]) < 0.85:
			cheap.append("%s %s" % [CampaignData.RESOURCES[r]["icon"], CampaignData.RESOURCES[r]["name"]])
	spec.text = "Дёшево тут: %s" % (", ".join(cheap) if not cheap.is_empty() else "ничего особенного")
	spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Фракция и наше положение в ней
	var rep_lvl: int = campaign.rep_level(_selected)
	var rep_row := HBoxContainer.new()
	rep_row.add_theme_constant_override("separation", 8)
	_sheet_body.add_child(rep_row)
	_status_icon(rep_row, "rep", 34)
	var frac := _mk_label(rep_row, 19, Color(0.7, 0.85, 0.9).lerp(Color(0.95, 0.8, 0.4), rep_lvl / 4.0))
	frac.text = "%s • %s • %d/100  |  скидка %d%% • скупка +%d%%" % [
		c.get("faction", "Фракция"), campaign.rep_title(_selected), campaign.rep_of(_selected),
		rep_lvl * 4, rep_lvl * 3]
	frac.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_here and not route.is_empty():
		var route_row := HBoxContainer.new()
		route_row.alignment = BoxContainer.ALIGNMENT_CENTER
		route_row.add_theme_constant_override("separation", 10)
		_sheet_body.add_child(route_row)
		_status_icon(route_row, "warning" if float(route[1]) >= 1.4 else "route", 38)
		var route_info := _mk_label(route_row, 20,
			Color(1.0, 0.48, 0.25) if float(route[1]) >= 1.4 else Color(0.95, 0.78, 0.42))
		var route_tags := ""
		if CampaignData.route_is_caravan(campaign.location, _selected):
			route_tags = " • КАРАВАН"
		var route_meta: Dictionary = CampaignData.route_meta(campaign.location, _selected)
		var route_name := String(route_meta.get("name", "Безымянный тракт"))
		var controller: String = campaign.route_controller(campaign.location, _selected)
		var controller_name := String(CampaignData.CITIES.get(controller, {}).get("faction", "Ничейная земля"))
		var mastery_level: int = campaign.route_mastery_level(campaign.location, _selected)
		var effective_danger: float = float(route[1]) * campaign.route_mastery_danger_mult(campaign.location, _selected)
		route_info.text = "%s • МАСТЕРСТВО %d/3 • %d ВОЛН • ОПАСНОСТЬ %.2f%s\nКОНТРОЛЬ: %s" % [
			route_name.to_upper(), mastery_level, 4 + int(route[0]) * 2, effective_danger, route_tags, controller_name]
		route_info.tooltip_text = String(route_meta.get("desc", "Подсвеченная дорога ведёт в выбранный город"))
		var preview: Dictionary = CampaignData.route_preview(campaign.location, _selected)
		var preview_row := HBoxContainer.new()
		preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_row.add_theme_constant_override("separation", 8)
		_sheet_body.add_child(preview_row)
		_status_icon(preview_row, "scrap", 34)
		var forecast := _mk_label(preview_row, 19, Color(0.78, 0.9, 0.62))
		var mastery_scrap := int(int(preview.get("scrap", 0)) * campaign.route_mastery_reward_mult(campaign.location, _selected))
		var mastery_count: int = campaign.route_mastery_count(campaign.location, _selected)
		forecast.text = "ПРОГНОЗ • ЛОМ ~%d • ЛУТ ~%d • РЕПУТАЦИЯ +%d  |  ПРОЕЗДОВ %d" % [
			mastery_scrap, int(preview.get("loot", 0)), int(preview.get("rep", 1)), mastery_count]
	# Рандомная находка дня рядом с городом — одна попытка в сутки
	if is_here:
		var poi: Dictionary = campaign.poi_at(_selected)
		if not poi.is_empty():
			var prow := HBoxContainer.new()
			prow.add_theme_constant_override("separation", 8)
			_sheet_body.add_child(prow)
			var plab := _mk_label(prow, 19, Color(0.85, 0.75, 0.4))
			plab.text = "%s %s — %s" % [poi["icon"], poi["name"], poi["desc"]]
			plab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			plab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pbtn := _rusty_button("ОСМОТРЕТЬ", Color(0.85, 0.75, 0.4))
			pbtn.custom_minimum_size = Vector2(150, 58)
			pbtn.pressed.connect(func(): _resolve_poi_at(_selected))
			prow.add_child(pbtn)
	if is_here:
		_render_war_campaign(_selected)
		_render_city_specials(_selected)
	var achievements_btn := _rusty_button("ДОСТИЖЕНИЯ • %d/%d" % [
		campaign.achievements.size(), CampaignData.ACHIEVEMENTS.size()], Color(0.82, 0.64, 0.3))
	achievements_btn.custom_minimum_size = Vector2(300, 58)
	achievements_btn.pressed.connect(func(): _open_view("achievements"))
	_sheet_body.add_child(achievements_btn)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	_sheet_body.add_child(btns)
	if is_here:
		var mk := _rusty_button("РЫНОК")
		mk.custom_minimum_size = Vector2(160, 58)
		mk.pressed.connect(func(): _open_view("market"))
		btns.add_child(mk)
		var ct := _rusty_button("КОНТРАКТЫ")
		ct.custom_minimum_size = Vector2(170, 58)
		ct.pressed.connect(func(): _open_view("contracts"))
		btns.add_child(ct)
		var tn := 0
		for t in campaign.trophies:
			tn += int(campaign.trophies[t])
		var hg := _rusty_button("АНГАР  %d" % tn, Color(0.75, 0.7, 0.55))
		hg.custom_minimum_size = Vector2(160, 58)
		hg.pressed.connect(func(): _open_view("hangar"))
		btns.add_child(hg)
		if bool(c.get("home", false)):
			var btns2 := HBoxContainer.new()
			btns2.add_theme_constant_override("separation", 8)
			_sheet_body.add_child(btns2)
			var bb := _rusty_button("БАЗА", Color(0.85, 0.7, 0.3))
			bb.custom_minimum_size = Vector2(150, 58)
			bb.pressed.connect(func(): _open_view("base"))
			btns2.add_child(bb)
			var lb := _rusty_button("ЛАБОРАТОРИЯ" if campaign.bld_level("lab") > 0 else "ЛАБОРАТОРИЯ — ЗАКРЫТА", Color(0.7, 0.8, 0.5))
			lb.custom_minimum_size = Vector2(210, 58)
			lb.disabled = campaign.bld_level("lab") == 0
			lb.pressed.connect(func(): _open_view("lab"))
			btns2.add_child(lb)
			var sr := _rusty_button("КОРПУСА", Color(0.95, 0.7, 0.35))
			sr.custom_minimum_size = Vector2(170, 58)
			var hicon: String = "res://assets/ui/h_%s.png" % campaign.hull_current
			if ResourceLoader.exists(hicon):
				sr.icon = load(hicon)
				sr.add_theme_constant_override("icon_max_width", 34)
			sr.pressed.connect(func(): _open_view("showroom"))
			btns2.add_child(sr)
	elif not route.is_empty():
		var waves_count := 4 + int(route[0]) * 2
		var tags := ""
		if float(route[1]) >= 1.4:
			tags += " • ОПАСНО"
		if CampaignData.route_is_caravan(campaign.location, _selected):
			tags += " • КАРАВАН"
		var go := _rusty_button("В РЕЙС • %d ВОЛН • %.1f%s" % [waves_count, float(route[1]), tags], Color(0.9, 0.5, 0.25))
		go.custom_minimum_size = Vector2(360, 58)
		go.add_theme_font_size_override("font_size", _font(22))
		go.pressed.connect(func(): travel_requested.emit(_selected))
		btns.add_child(go)
	else:
		var nope := _mk_label(btns, 20, Color(0.6, 0.5, 0.4))
		nope.text = "Прямой дороги нет — езжай через соседей."


func _render_war_campaign(city: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_sheet_body.add_child(row)
	_status_icon(row, "warning", 42)
	var label := _mk_label(row, 19, Color(0.9, 0.62, 0.35))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if campaign.war_side == "":
		label.text = "НЕДЕЛЯ ВОЙНЫ • выберите фракцию поддержки"
		var support := _rusty_button("ПОДДЕРЖАТЬ", Color(0.88, 0.52, 0.25))
		support.custom_minimum_size = Vector2(190, 60)
		support.pressed.connect(func():
			if campaign.choose_war_side(city):
				_render_sheet())
		row.add_child(support)
	else:
		label.text = "НЕДЕЛЯ ВОЙНЫ • %s\nОЧКИ %d/15 • ЦЕЛИ 4 / 8 / 15" % [campaign.war_faction_name(), campaign.war_points]
	var journal := _rusty_button("ЖУРНАЛ ЗАХВАТОВ", Color(0.68, 0.52, 0.32))
	journal.custom_minimum_size = Vector2(260, 58)
	journal.pressed.connect(func(): _open_view("warlog"))
	_sheet_body.add_child(journal)


func _render_war_log() -> void:
	if campaign.war_log.is_empty():
		var empty := _mk_label(_sheet_body, 20, TEXT_DIM)
		empty.text = "Пока ни одна фракция не изменила контроль дорог."
		return
	for entry in campaign.war_log:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_sheet_body.add_child(row)
		_status_icon(row, "warning", 40)
		var owner := String(entry.get("owner", ""))
		var faction := String(CampaignData.CITIES.get(owner, {}).get("faction", owner))
		var text := _mk_label(row, 19, TEXT_DIM)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = "ДЕНЬ %d • %s\nКОНТРОЛЬ: %s" % [int(entry.get("day", 0)), entry.get("name", "Дорога"), faction]


func _render_city_specials(city: String) -> void:
	var service: Dictionary = CampaignData.CITY_SERVICES.get(city, {})
	if not service.is_empty():
		var service_row := HBoxContainer.new()
		service_row.add_theme_constant_override("separation", 10)
		_sheet_body.add_child(service_row)
		var service_text := _mk_label(service_row, 19, Color(0.82, 0.88, 0.58))
		service_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		service_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var service_strength := int(round(campaign.city_service_strength(city) * 100.0))
		service_text.text = "УСЛУГА • %s • РАНГ %d\nЭФФЕКТ +%d%% • НУЖНО: %s" % [
			service["name"], campaign.rep_level(city) + 1, service_strength, _cost_text(service["needs"])]
		var buy_service := _rusty_button("ЗАКАЗАТЬ • %d ЛОМА" % campaign.city_service_price(city), Color(0.72, 0.82, 0.48))
		buy_service.custom_minimum_size = Vector2(230, 64)
		buy_service.disabled = not campaign.can_buy_city_service(city)
		buy_service.pressed.connect(func():
			if campaign.buy_city_service(city):
				_play_earn()
				_render_sheet())
		service_row.add_child(buy_service)
	if CampaignData.CITY_STORIES.has(city):
		var stage: Dictionary = campaign.story_current(city)
		var story_label := _mk_label(_sheet_body, 20, Color(0.9, 0.66, 0.35))
		if stage.is_empty():
			var endings := {"allied": "СОЮЗ", "mercenary": "ДЕЛОВОЕ ПАРТНЁРСТВО", "betrayed": "ПРЕДАТЕЛЬСТВО"}
			story_label.text = "ИСТОРИЯ ЗАВЕРШЕНА • %s" % endings.get(campaign.story_ending(city), "ФИНАЛ")
			return
		var art_prefix := "bone" if city == "bonewall" else "copper"
		var art_path := "res://assets/ui/art_%s_%d.jpg" % [art_prefix, campaign.story_stage(city) + 1]
		if ResourceLoader.exists(art_path):
			var art := TextureRect.new()
			art.texture = load(art_path)
			art.custom_minimum_size = Vector2(640, 190)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sheet_body.add_child(art)
			_sheet_body.move_child(art, story_label.get_index())
		story_label.text = "ИСТОРИЯ • %s\n%s\nНУЖНО: %s\nНАГРАДА: %s" % [
			stage["title"], stage["text"], _cost_text(stage["needs"]), _reward_text(stage["reward"])]
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 8)
		_sheet_body.add_child(choices)
		_add_story_choice(choices, city, "ПОМОЧЬ ФРАКЦИИ", "loyal", Color(0.65, 0.82, 0.48))
		_add_story_choice(choices, city, "ВЗЯТЬ ПЛАТУ", "profit", Color(0.88, 0.65, 0.3))
		if campaign.story_stage(city) == (CampaignData.CITY_STORIES[city] as Array).size() - 1:
			_add_story_choice(choices, city, "ПРЕДАТЬ", "betray", Color(0.9, 0.3, 0.2))


func _add_story_choice(parent: HBoxContainer, city: String, label: String, choice: String, color: Color) -> void:
	var button := _rusty_button(label, color)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", _font(18))
	button.disabled = not campaign.can_advance_story(city)
	button.pressed.connect(func():
		if campaign.advance_story(city, choice):
			_play_earn()
			_render_sheet())
	parent.add_child(button)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost:
		var name := String(key)
		if name.begins_with("trophy:"):
			var trophy_id := name.trim_prefix("trophy:")
			name = String(CampaignData.TROPHIES.get(trophy_id, {}).get("name", trophy_id))
		else:
			name = String(CampaignData.RESOURCES.get(name, {}).get("name", name))
		parts.append("%s ×%d" % [name, int(cost[key])])
	return ", ".join(parts)


func _reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for key in reward:
		var names := {"rep": "репутация", "scrap": "лом", "bp": "чертежи"}
		var name := String(names.get(key, CampaignData.RESOURCES.get(key, {}).get("name", key)))
		parts.append("%s +%d" % [name, int(reward[key])])
	return ", ".join(parts)


## Осмотр находки дня: разрешаем и показываем итог поверх листа города.
func _resolve_poi_at(city: String) -> void:
	var res: Dictionary = campaign.resolve_poi(city)
	_render_sheet()
	if res.is_empty():
		return
	var box := _mk_label(_sheet_body, 20, Color(0.95, 0.85, 0.5))
	box.text = "%s: %s" % [res.get("title", "Находка"), res.get("text", "")]
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_body.move_child(box, 0)


## Звон лома для сделок рынка (защита от null в smoke-тестах).
func _play_earn() -> void:
	if sfx != null:
		sfx.play("earn", 0.7)


func _buy_intel() -> void:
	var city: String = campaign.buy_intel()
	if city != "":
		_intel_message = "ОТКРЫТО: %s" % CampaignData.CITIES[city]["name"]
		_play_earn()
		_redraw_map()
	_render_sheet()


func _render_market(is_here: bool) -> void:
	if not is_here:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Торговать можно только в городе, где стоит фура."
		return
	var intel_row := HBoxContainer.new()
	intel_row.add_theme_constant_override("separation", 10)
	_sheet_body.add_child(intel_row)
	_status_icon(intel_row, "route", 42)
	var intel_text := _mk_label(intel_row, 19, Color(0.72, 0.86, 0.9))
	intel_text.custom_minimum_size = Vector2(300, 58)
	intel_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel_text.text = _intel_message if _intel_message != "" else "РАЗВЕДДАННЫЕ • открыть неизвестный город"
	var intel_btn := _rusty_button("КУПИТЬ • %d ЛОМА" % campaign.intel_price(), Color(0.55, 0.72, 0.82))
	intel_btn.custom_minimum_size = Vector2(190, 60)
	intel_btn.disabled = campaign.intel_candidates().is_empty() or campaign.wallet < campaign.intel_price()
	if campaign.intel_candidates().is_empty():
		intel_btn.text = "КАРТА ОТКРЫТА"
	intel_btn.pressed.connect(_buy_intel)
	intel_row.add_child(intel_btn)
	for res in CampaignData.RESOURCES:
		var d: Dictionary = CampaignData.RESOURCES[res]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		# Нарисованная иконка ресурса (png с движка или svg-заглушка)
		var res_icon: String = "res://assets/ui/res_%s.png" % res
		if not ResourceLoader.exists(res_icon):
			res_icon = "res://assets/ui/res_%s.svg" % res
		if ResourceLoader.exists(res_icon):
			var tr := TextureRect.new()
			tr.texture = load(res_icon)
			tr.custom_minimum_size = Vector2(30, 30)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tr)
		var name_l := _mk_label(row, 20, TEXT_DIM)
		name_l.custom_minimum_size = Vector2(300, 0)
		var bp: int = campaign.buy_price(res, campaign.location)
		var sp: int = int(campaign.price_of(res, campaign.location) * campaign.sell_rate(campaign.location))
		name_l.text = "%s • %d/%d • В ТРЮМЕ %d" % [d["name"], bp, sp, campaign.cargo_qty(res)]
		name_l.tooltip_text = "Цена покупки / продажи"
		var buy_b := _rusty_button("Купить", Color(0.7, 0.85, 0.5))
		buy_b.custom_minimum_size = Vector2(120, 58)
		buy_b.disabled = campaign.wallet < bp or campaign.cargo_space() < 1
		var r: String = res
		buy_b.pressed.connect(func(): if campaign.buy(r, 1): _play_earn(); _render_sheet())
		row.add_child(buy_b)
		var sell_b := _rusty_button("Продать", Color(0.9, 0.6, 0.3))
		sell_b.custom_minimum_size = Vector2(120, 58)
		sell_b.disabled = campaign.cargo_qty(res) < 1
		sell_b.pressed.connect(func(): if campaign.sell(r, 1): _play_earn(); _render_sheet())
		row.add_child(sell_b)


## Ангар: захваченные в рейсах тачки — пилить на ресурсы или продавать.
func _render_hangar(is_here: bool) -> void:
	var total := 0
	for t in campaign.trophies:
		total += int(campaign.trophies[t])
	if total == 0:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Пусто. Тачки добываются в рейсах: бей рейдеров — целые обломки отбуксируем сюда."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if not is_here:
		var nl := _mk_label(_sheet_body, 19, Color(0.7, 0.55, 0.4))
		nl.text = "Ангар при фуре — работать можно в городе, где стоим."
		return
	for t in CampaignData.TROPHIES:
		var have: int = int(campaign.trophies.get(t, 0))
		if have <= 0:
			continue
		var d: Dictionary = CampaignData.TROPHIES[t]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var parts: Array = []
		for res in d["salvage"]:
			parts.append("%s×%d" % [CampaignData.RESOURCES[res]["icon"], int(d["salvage"][res])])
		var has_icon: bool = _add_row_icon(row, "res://assets/ui/t_%s.png" % t)
		var lab := _mk_label(row, 19, TEXT_DIM)
		lab.custom_minimum_size = Vector2(280, 0)
		var prefix: String = "" if has_icon else "%s " % d["icon"]
		lab.text = "%s%s ×%d — распил: %s" % [prefix, d["name"], have, " ".join(parts)]
		var tid: String = t
		var scr := _rusty_button("Разобрать", Color(0.75, 0.7, 0.55))
		scr.custom_minimum_size = Vector2(140, 58)
		scr.pressed.connect(func(): campaign.scrap_trophy(tid); _render_sheet())
		row.add_child(scr)
		var sel := _rusty_button("⚙%d" % int(d["scrap_price"]), Color(0.9, 0.6, 0.3))
		sel.custom_minimum_size = Vector2(100, 58)
		sel.pressed.connect(func(): campaign.sell_trophy(tid); _render_sheet())
		row.add_child(sel)
	# Кузня легендарок: трофеи плавим в орудия на следующий рейс
	var fhead := _mk_label(_sheet_body, 21, Color(1.0, 0.8, 0.4))
	fhead.text = "КУЗНЯ ТРОФЕЕВ"
	_sheet_body.add_child(fhead)
	for fid in CampaignData.LEGENDARY_RECIPES:
		var ld: Dictionary = CampaignData.LEGENDARY_RECIPES[fid]
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(frow)
		var needs: Array = []
		for t in ld["needs"]:
			var td2: Dictionary = CampaignData.TROPHIES[t]
			needs.append("%s %d/%d" % [td2["icon"], int(campaign.trophies.get(t, 0)), int(ld["needs"][t])])
		var flab := _mk_label(frow, 19, TEXT_DIM)
		flab.custom_minimum_size = Vector2(440, 0)
		flab.text = "%s %s — %s  [нужно: %s]" % [ld["icon"], ld["name"], ld["desc"], " ".join(needs)]
		var fb := _rusty_button("Сковать", Color(1.0, 0.8, 0.4))
		fb.custom_minimum_size = Vector2(130, 58)
		fb.disabled = not campaign.can_forge(fid)
		var ffid: String = fid
		fb.pressed.connect(func():
			campaign.forge(ffid)
			_play_earn()
			_render_sheet())
		frow.add_child(fb)
	# Кузня легендарных способностей: дороже, зато навсегда
	var ahead := _mk_label(_sheet_body, 21, Color(0.55, 0.75, 1.0))
	ahead.text = "КУЗНЯ СПОСОБНОСТЕЙ • НАВСЕГДА"
	_sheet_body.add_child(ahead)
	for aid in CampaignData.LEGENDARY_ABILITY_RECIPES:
		var ad: Dictionary = CampaignData.LEGENDARY_ABILITY_RECIPES[aid]
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(arow)
		var aneeds: Array = []
		for t in ad["needs"]:
			var td3: Dictionary = CampaignData.TROPHIES[t]
			aneeds.append("%s %d/%d" % [td3["icon"], int(campaign.trophies.get(t, 0)), int(ad["needs"][t])])
		var alab := _mk_label(arow, 19, TEXT_DIM)
		alab.custom_minimum_size = Vector2(440, 0)
		alab.text = "%s %s — %s  [нужно: %s]" % [ad["icon"], ad["name"], ad["desc"], " ".join(aneeds)]
		var ab := _rusty_button("Сковать", Color(0.55, 0.75, 1.0))
		ab.custom_minimum_size = Vector2(130, 58)
		var already: bool = campaign.leg_abilities.has(String(ad["ability"]))
		ab.disabled = already or not campaign.can_forge_ability(aid)
		if already:
			ab.text = "В арсенале ✓"
		var aaid: String = aid
		ab.pressed.connect(func():
			campaign.forge_ability(aaid)
			_play_earn()
			_render_sheet())
		arow.add_child(ab)


## Шоурум: лесенка корпусов. Собираем из запчастей (только дома), выбираем рабочую.
func _render_showroom(is_here: bool) -> void:
	if not is_here:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Шоурум при базе — загляни домой."
		return
	var head := _mk_label(_sheet_body, 20, Color(0.85, 0.78, 0.6))
	head.text = "ЗАПЧАСТИ %d  •  ЛОМ %d  •  МАСТЕРСКАЯ %d" % [
		campaign.cargo_qty("parts"), campaign.wallet, campaign.bld_level("workshop")]
	for id in CampaignData.HULL_ORDER:
		var d: Dictionary = CampaignData.HULLS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_sheet_body.add_child(row)
		var has_icon: bool = _add_row_icon(row, "res://assets/ui/h_%s.png" % id, 48)
		var prefix: String = "" if has_icon else "%s " % d["icon"]
		var txt := _mk_label(row, 20, TEXT_DIM)
		txt.custom_minimum_size = Vector2(330, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var n: int = int(d["slots"])
		var slots_w := "слот" if n == 1 else ("слота" if n < 5 else "слотов")
		txt.text = "%s%s — %d %s • HP ×%.2f\n%s" % [prefix, d["name"], n, slots_w, float(d["hp_mult"]), d["desc"]]
		var btn := _rusty_button("", Color(0.95, 0.7, 0.35))
		btn.custom_minimum_size = Vector2(230, 58)
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var hid: String = id
		if id == campaign.hull_current:
			btn.text = "✓ В строю"
			btn.disabled = true
		elif id in campaign.hulls_owned:
			btn.text = "Выбрать"
			btn.pressed.connect(func():
				if campaign.select_hull(hid):
					hull_changed.emit()
					_render_sheet())
		else:
			btn.text = "СОБРАТЬ  🔧%d  ⚙%d  •%d" % [int(d["parts"]), int(d["scrap"]), int(d["workshop"])]
			btn.tooltip_text = "Нужна мастерская ур.%d" % int(d["workshop"])
			btn.disabled = not campaign.can_build_hull(id)
			btn.pressed.connect(func():
				if campaign.build_hull(hid):
					_play_earn()
					hull_changed.emit()
					_render_sheet())
		row.add_child(btn)


func _render_contracts(is_here: bool) -> void:
	var active_t := _mk_label(_sheet_body, 21, ACCENT)
	active_t.text = "— Активные (%d/3) —" % campaign.contracts.size()
	if campaign.contracts.is_empty():
		var l := _mk_label(_sheet_body, 19, TEXT_DIM)
		l.text = "Пусто. Возьми контракт с доски."
	for c in campaign.contracts:
		var l2 := _mk_label(_sheet_body, 19, TEXT_DIM)
		l2.text = campaign.contract_text(c)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var off_t := _mk_label(_sheet_body, 21, ACCENT)
	off_t.text = "— На доске —"
	if not is_here:
		var l3 := _mk_label(_sheet_body, 19, Color(0.7, 0.55, 0.4))
		l3.text = "Доска доступна, только когда фура в городе."
		return
	for c in campaign.offer_list(campaign.location):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var txt := _mk_label(row, 20, TEXT_DIM)
		txt.custom_minimum_size = Vector2(500, 0)
		txt.text = campaign.contract_text(c)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var take := _rusty_button("Взять", Color(0.7, 0.85, 0.5))
		take.custom_minimum_size = Vector2(90, 58)
		take.disabled = campaign.contracts.size() >= 3
		var uid := str(c["uid"])
		take.pressed.connect(func():
			campaign.accept_contract(campaign.location, uid)
			_render_sheet())
		row.add_child(take)


## Вид базы: постройки, их уровни и цены.
func _render_base(is_here: bool) -> void:
	if not is_here:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Строить можно только дома."
		return
	for id in CampaignData.BUILDINGS:
		var d: Dictionary = CampaignData.BUILDINGS[id]
		var lvl: int = campaign.bld_level(id)
		var cost: Dictionary = campaign.bld_cost(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var has_icon: bool = _add_row_icon(row, "res://assets/ui/b_%s.png" % id)
		var prefix: String = "" if has_icon else "%s " % d["icon"]
		var txt := _mk_label(row, 20, TEXT_DIM)
		txt.custom_minimum_size = Vector2(440, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cost.is_empty():
			txt.text = "%s%s [МАКС ур.%d] — %s" % [prefix, d["name"], lvl, d["desc"]]
		else:
			var parts: Array = []
			for k in cost:
				if k == "scrap":
					parts.append("⚙%d" % int(cost[k]))
				else:
					parts.append("%s×%d" % [CampaignData.RESOURCES[k]["icon"], int(cost[k])])
			txt.text = "%s%s [ур.%d→%d] — %s  |  цена: %s" % [prefix, d["name"], lvl, lvl + 1, d["desc"], " ".join(parts)]
		row.add_child(txt)
		var b := _rusty_button("Строить", Color(0.85, 0.7, 0.3))
		b.custom_minimum_size = Vector2(130, 58)
		b.disabled = cost.is_empty() or not campaign.can_build(id)
		var bid: String = id
		b.pressed.connect(func(): campaign.build(bid); _render_sheet())
		row.add_child(b)


## Вид лаборатории: исследования, крафт, инвентарь модулей.
func _render_lab(is_here: bool) -> void:
	if not is_here:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Лаборанты работают только дома."
		return

	# Активное исследование
	if campaign.research_active != "":
		var d: Dictionary = CampaignData.RESEARCH[campaign.research_active]
		var cur := _mk_label(_sheet_body, 20, Color(0.8, 0.85, 0.6))
		cur.text = "⚗️ Идёт: %s %s — осталось рейсов: %d" % [d["icon"], d["name"], campaign.research_left]

	# Список техов
	for id in CampaignData.RESEARCH:
		var d: Dictionary = CampaignData.RESEARCH[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var ricon: bool = _add_row_icon(row, "res://assets/ui/r_%s.png" % id)
		var rprefix: String = "" if ricon else "%s " % d["icon"]
		var txt := _mk_label(row, 20, TEXT_DIM)
		txt.custom_minimum_size = Vector2(410, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _rusty_button("", Color(0.7, 0.8, 0.5))
		b.custom_minimum_size = Vector2(120, 58)
		if id in campaign.research_done:
			txt.text = "%s%s ✅ — %s" % [rprefix, d["name"], d["desc"]]
			b.visible = false
		elif id == campaign.research_active:
			txt.text = "%s%s ⏳ — %s" % [rprefix, d["name"], d["desc"]]
			b.visible = false
		else:
			var parts: Array = []
			for k in d["cost"]:
				if k == "scrap":
					parts.append("⚙%d" % int(d["cost"][k]))
				else:
					parts.append("%s×%d" % [CampaignData.RESOURCES[k]["icon"], int(d["cost"][k])])
			parts.append("📐%d" % int(d["bp"]))
			parts.append("🔬%dр" % int(d["runs"]))
			var lab_ok: bool = campaign.research_level_req_met(id)
			txt.text = "%s%s [лаб.%d] — %s  |  %s" % [rprefix, d["name"], d["lab"], d["desc"], " ".join(parts)]
			var ending_req := String(d.get("ending", ""))
			if ending_req != "" and not campaign.research_ending_req_met(id):
				var ending_names := {"allied": "СОЮЗ", "mercenary": "ПАРТНЁРСТВО", "betrayed": "ПРЕДАТЕЛЬСТВО"}
				txt.text += "  [НУЖЕН ФИНАЛ: %s]" % ending_names.get(ending_req, ending_req)
			txt.modulate = Color(1, 1, 1) if lab_ok else Color(1, 1, 1, 0.45)
			b.text = "Начать"
			b.disabled = not campaign.can_research(id)
			var rid: String = id
			b.pressed.connect(func(): campaign.start_research(rid); _render_sheet())
		row.add_child(txt)
		row.add_child(b)

	# Крафт-модули
	var ct := _mk_label(_sheet_body, 21, ACCENT)
	ct.text = "КРАФТ • НА ОДИН РЕЙС"
	for id in CampaignData.RECIPES:
		var d: Dictionary = CampaignData.RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var cicon: bool = _add_row_icon(row, "res://assets/ui/cr_%s.svg" % id)
		var cprefix: String = "" if cicon else "%s " % d["icon"]
		var txt := _mk_label(row, 20, TEXT_DIM)
		txt.custom_minimum_size = Vector2(410, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _rusty_button("", Color(0.85, 0.7, 0.4))
		b.custom_minimum_size = Vector2(120, 58)
		txt.text = "%s%s ×%d — %s" % [cprefix, d["name"], int(campaign.inventory.get(id, 0)), d["desc"]]
		var req: String = d.get("research", "")
		if req != "" and req not in campaign.research_done:
			b.text = "ЗАКРЫТО"
			b.disabled = true
			txt.text += " [нужна теха «%s»]" % CampaignData.RESEARCH[req]["name"]
			txt.modulate = Color(1, 1, 1, 0.45)
		else:
			var parts: Array = []
			for k in d["needs"]:
				if k == "scrap":
					parts.append("⚙%d" % campaign.craft_scrap_cost(id))
				else:
					parts.append("%s×%d" % [CampaignData.RESOURCES[k]["icon"], int(d["needs"][k])])
			b.text = "Скрафтить"
			b.disabled = not campaign.can_craft(id)
			txt.text += "  |  " + " ".join(parts)
			var cid: String = id
			b.pressed.connect(func(): campaign.craft(cid); _render_sheet())
		row.add_child(txt)
		row.add_child(b)
		# Модуль в следующий рейс
		if int(campaign.inventory.get(id, 0)) > 0:
			var taken: bool = campaign.pending.has(id)
			var st := _rusty_button("В рейс" if not taken else "ВЗЯТ", Color(0.9, 0.55, 0.25))
			st.custom_minimum_size = Vector2(100, 58)
			st.disabled = taken
			var sid: String = id
			st.pressed.connect(func(): campaign.stage_item(sid); _render_sheet())
			row.add_child(st)


func _render_achievements() -> void:
	campaign.check_achievements()
	for id in CampaignData.ACHIEVEMENTS:
		var data: Dictionary = CampaignData.ACHIEVEMENTS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_sheet_body.add_child(row)
		_status_icon(row, "record", 46)
		var unlocked: bool = id in campaign.achievements
		var label := _mk_label(row, 20, Color(1.0, 0.78, 0.35) if unlocked else TEXT_DIM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s • %s\n%s\nНАГРАДА: %s" % [
			"ВЫПОЛНЕНО" if unlocked else "В ПРОЦЕССЕ", data["name"], data["desc"], _reward_text(data["reward"])]


## Настройки доступны со стоянки и сохраняются отдельно от кампании.
func _render_settings() -> void:
	if settings == null:
		var unavailable := _mk_label(_sheet_body, 20, TEXT_DIM)
		unavailable.text = "Настройки пока недоступны."
		return
	var intro := _mk_label(_sheet_body, 19, TEXT_DIM)
	intro.text = "Все параметры сохраняются сразу. Размер текста применится после быстрого обновления сцены."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var size_row := _settings_row("РАЗМЕР НАДПИСЕЙ")
	var large := _rusty_button("КРУПНЫЙ", Color(0.65, 0.76, 0.5))
	var huge := _rusty_button("ОЧЕНЬ КРУПНЫЙ", Color(0.9, 0.65, 0.3))
	for b in [large, huge]:
		b.custom_minimum_size = Vector2(180, 58)
		b.toggle_mode = true
		size_row.add_child(b)
	large.set_pressed_no_signal(String(settings.get_value("ui_size")) == "large")
	huge.set_pressed_no_signal(String(settings.get_value("ui_size")) == "huge")
	large.pressed.connect(func(): _set_setting("ui_size", "large", true))
	huge.pressed.connect(func(): _set_setting("ui_size", "huge", true))

	var sound_row := _settings_row("ГРОМКОСТЬ")
	var quieter := _rusty_button("−", Color(0.65, 0.72, 0.5))
	quieter.custom_minimum_size = Vector2(82, 58)
	var sound_value := _mk_label(sound_row, 22, ACCENT)
	sound_value.custom_minimum_size = Vector2(140, 58)
	sound_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sound_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sound_value.text = "%d%%" % int(settings.get_value("sound"))
	var louder := _rusty_button("+", Color(0.75, 0.82, 0.5))
	louder.custom_minimum_size = Vector2(82, 58)
	sound_row.add_child(quieter)
	sound_row.move_child(quieter, sound_value.get_index())
	sound_row.add_child(louder)
	quieter.pressed.connect(func(): _set_setting("sound", maxi(0, int(settings.get_value("sound")) - 10)))
	louder.pressed.connect(func(): _set_setting("sound", mini(100, int(settings.get_value("sound")) + 10)))

	var vibration_row := _settings_row("ВИБРАЦИЯ УДАРОВ")
	var vibration := _rusty_button("ВКЛЮЧЕНА" if bool(settings.get_value("vibration")) else "ВЫКЛЮЧЕНА",
		Color(0.65, 0.82, 0.5) if bool(settings.get_value("vibration")) else Color(0.65, 0.45, 0.35))
	vibration.custom_minimum_size = Vector2(220, 58)
	vibration.pressed.connect(func(): _set_setting("vibration", not bool(settings.get_value("vibration"))))
	vibration_row.add_child(vibration)

	var shake_row := _settings_row("ТРЯСКА КАМЕРЫ")
	var shake_names := {0: "ВЫКЛ.", 50: "СРЕДНЯЯ", 100: "ПОЛНАЯ"}
	var shake_value_int := int(settings.get_value("shake"))
	var shake := _rusty_button(shake_names.get(shake_value_int, "ПОЛНАЯ"), Color(0.82, 0.6, 0.35))
	shake.custom_minimum_size = Vector2(220, 58)
	shake.pressed.connect(func():
		var current := int(settings.get_value("shake"))
		_set_setting("shake", 50 if current == 0 else (100 if current == 50 else 0)))
	shake_row.add_child(shake)

	var effects_row := _settings_row("ЧАСТИЦЫ И ВСПЫШКИ")
	var economy := String(settings.get_value("effects")) == "economy"
	var effects := _rusty_button("ЭКОНОМНЫЕ" if economy else "ПОЛНЫЕ",
		Color(0.6, 0.75, 0.5) if economy else Color(0.9, 0.58, 0.28))
	effects.custom_minimum_size = Vector2(220, 58)
	effects.tooltip_text = "Экономный режим уменьшает пыль, искры и отключает свет взрывов"
	effects.pressed.connect(func(): _set_setting("effects", "full" if economy else "economy"))
	effects_row.add_child(effects)

	var reset := _rusty_button("СБРОСИТЬ ОБУЧЕНИЕ", Color(0.75, 0.48, 0.3))
	reset.custom_minimum_size = Vector2(320, 58)
	reset.pressed.connect(_reset_tutorial)
	_sheet_body.add_child(reset)


func _settings_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_sheet_body.add_child(row)
	var label := _mk_label(row, 20, TEXT_DIM)
	label.text = title
	label.custom_minimum_size = Vector2(260, 58)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


func _set_setting(key: String, value, reload_ui: bool = false) -> void:
	settings.set_value(key, value)
	settings.vibrate(22, 0.3)
	if reload_ui:
		get_tree().call_deferred("reload_current_scene")
	else:
		_render_sheet()


func _reset_tutorial() -> void:
	if campaign.meta != null:
		campaign.meta.tutorial_flags.clear()
		campaign.meta.save_meta()
	if settings != null:
		settings.vibrate(45, 0.45)
	var done := _mk_label(_sheet_body, 20, Color(0.75, 0.95, 0.55))
	done.text = "✓ Подсказки обучения снова включены."
	_sheet_body.move_child(done, 0)


## Холст карты: рисует дороги между городами.
class MapCanvas:
	extends Control
	const CDATA := preload("res://scripts/CampaignData.gd")
	var selected_a := ""
	var selected_b := ""
	var discovered: Array = []
	var mastery: Dictionary = {}
	var control: Dictionary = {}

	func set_route_control(values: Dictionary) -> void:
		control = values.duplicate(true)
		queue_redraw()

	func set_mastery(values: Dictionary) -> void:
		mastery = values.duplicate(true)
		queue_redraw()

	func set_discovered(cities: Array) -> void:
		discovered = cities.duplicate()
		queue_redraw()

	func select_route(a: String, b: String) -> void:
		selected_a = a
		selected_b = b
		queue_redraw()

	func _draw() -> void:
		# Полупрозрачные зоны влияния фракций лежат под дорогами и эмблемами.
		for city in discovered:
			if not CDATA.CITIES.has(city):
				continue
			var city_data: Dictionary = CDATA.CITIES[city]
			var hue := fposmod(float(abs(String(city_data.get("faction", city)).hash()) % 360) / 360.0, 1.0)
			var territory := Color.from_hsv(hue, 0.55, 0.8, 0.14)
			draw_circle((city_data["pos"] as Vector2) * size, 68.0, territory)
		for r: Array in CDATA.ROUTES:
			if String(r[0]) not in discovered or String(r[1]) not in discovered:
				continue
			var a: Vector2 = (CDATA.CITIES[r[0]]["pos"] as Vector2) * size
			var b: Vector2 = (CDATA.CITIES[r[1]]["pos"] as Vector2) * size
			var is_selected: bool = selected_b != "" and (
				(String(r[0]) == selected_a and String(r[1]) == selected_b) or
				(String(r[1]) == selected_a and String(r[0]) == selected_b))
			var col := Color(0.45, 0.35, 0.2, 0.9)
			if float(r[3]) >= 1.4:
				col = Color(0.8, 0.18, 0.1, 0.95)   # смертельная трасса
			elif float(r[3]) >= 1.2:
				col = Color(0.6, 0.3, 0.15, 0.9)
			if is_selected:
				draw_line(a, b, Color(0.12, 0.045, 0.015, 0.9), 13.0, true)
				draw_line(a, b, Color(1.0, 0.48, 0.12, 1.0), 7.0, true)
				draw_circle((a + b) * 0.5, 7.0, Color(1.0, 0.78, 0.25, 1.0))
			else:
				draw_line(a, b, col, 4.0, true)
			var route_key := CDATA.route_key(String(r[0]), String(r[1]))
			if control.has(route_key):
				var owner := String(control[route_key])
				var faction := String(CDATA.CITIES.get(owner, {}).get("faction", owner))
				var control_hue := fposmod(float(abs(faction.hash()) % 360) / 360.0, 1.0)
				draw_line(a, b, Color.from_hsv(control_hue, 0.72, 0.95, 0.8), 2.0, true)
			draw_circle(a, 5.0, Color(1.0, 0.48, 0.12) if is_selected else col)
			var mastery_count := int(mastery.get(CDATA.route_key(String(r[0]), String(r[1])), 0))
			var mastery_level := mini(int(mastery_count / 2), 3)
			var mastery_mid := (a + b) * 0.5
			for i in mastery_level:
				draw_circle(mastery_mid + Vector2((i - (mastery_level - 1) * 0.5) * 12.0, 12), 4.0, Color(1.0, 0.78, 0.25, 0.95))
			# Метки трасс в середине линии
			var marks := ""
			if float(r[3]) >= 1.4:
				marks += "☠"
			if r.size() > 4 and String(r[4]) == "caravan":
				marks += "🐫"
			if marks != "":
				var mid := (a + b) * 0.5 + Vector2(-12, -12)
				draw_string(ThemeDB.fallback_font, mid, marks,
					HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1.0, 0.9, 0.7, 0.95))
		# Рамка пустоши
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.12, 0.5), false, 3.0)
