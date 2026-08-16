extends CanvasLayer
## Карта пустоши: города, дороги, выбор рейса, рынок и контракты в городе.
## Всё рисуется кодом — процедурный UI в духе проекта.

signal travel_requested(city_id: String)
## Игрок сменил корпус в шоуруме — Main пересобирает платформу.
signal hull_changed

const CampaignData := preload("res://scripts/CampaignData.gd")
const RustButton := preload("res://scripts/RustButton.gd")
const RustHeader := preload("res://scripts/RustHeader.gd")

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
var _map_area: Control
var _city_buttons: Dictionary = {}
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_body: VBoxContainer
var _nav_buttons: Dictionary = {}
var _selected := ""
var _view := "info"   # info | market | contracts | hangar | base | lab | showroom


func _ready() -> void:
	layer = 20
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
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.offset_bottom = 130
	add_child(top)
	# Две строки не дают крупным статусам слипаться на узком портретном экране.
	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 5)
	top.add_child(top_col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_col.add_child(row)
	_loc_label = _mk_label(row, 24, ACCENT)
	_wallet_label = _mk_label(row, 24, Color(0.95, 0.75, 0.35))
	_cargo_label = _mk_label(row, 24, Color(0.8, 0.85, 0.6))
	var settings_btn := _rusty_button("⚙", Color(0.55, 0.72, 0.82))
	settings_btn.custom_minimum_size = Vector2(62, 58)
	settings_btn.tooltip_text = "Настройки"
	settings_btn.pressed.connect(func(): _open_view("settings"))
	row.add_child(settings_btn)
	_day_label = _mk_label(top_col, 22, TEXT_DIM)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _mk_label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", _font(size))
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Маленькая нарисованная иконка в начало строки списка.
## Возвращает true, если ассет нашёлся (тогда эмодзи в тексте можно опустить).
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
	_loc_label.text = "%s %s" % [c["icon"], c["name"]]
	_wallet_label.text = "⚙ %d" % campaign.wallet
	_cargo_label.text = "📦 %d/%d" % [campaign.cargo_used(), campaign.cargo_cap()]
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
	_day_label.text = "☀ День %d%s    🏆 %d" % [campaign.day, mods_txt, best]
	_day_label.tooltip_text = season_tip
	for m in campaign.daily_mods():
		_day_label.tooltip_text += "%s: %s\n" % [CampaignData.DAILY_MODS[m]["name"], CampaignData.DAILY_MODS[m]["desc"]]


func _build_map() -> void:
	var area_size := Vector2(704, 536)
	# Рисованный фон пустоши под дорогами и кнопками городов
	var bg_path := "res://assets/ui/map_bg.jpg"
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		# Сначала разрешаем ужать текстуру: иначе её нативные 1408×768
		# раздвигают весь портретный интерфейс за правый край.
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.position = Vector2(8, 140)
		bg.size = area_size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	_map_area = MapCanvas.new()
	_map_area.position = Vector2(8, 140)
	_map_area.size = area_size
	add_child(_map_area)
	for id in CampaignData.CITIES:
		var c: Dictionary = CampaignData.CITIES[id]
		var btn := _rusty_button("%s\n%s" % [c["icon"], c["name"]], ACCENT)
		var city_size := Vector2(170, 108)
		btn.custom_minimum_size = city_size
		btn.size = city_size
		btn.add_theme_font_size_override("font_size", _font(18))
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Нарисованная эмблема города над именем
		var cicon: String = "res://assets/ui/c_%s.png" % id
		if ResourceLoader.exists(cicon):
			btn.icon = load(cicon)
			btn.add_theme_constant_override("icon_max_width", 38)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.text = String(c["name"])
		var city_pos: Vector2 = c["pos"] * area_size - city_size * 0.5
		city_pos.x = clampf(city_pos.x, 0.0, area_size.x - city_size.x)
		city_pos.y = clampf(city_pos.y, 0.0, area_size.y - city_size.y)
		btn.position = city_pos
		btn.pressed.connect(func(): _select(id))
		_map_area.add_child(btn)
		_city_buttons[id] = btn

	# Нижний лист: инфо / рынок / контракты
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", _styled_panel())
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 8
	_sheet.offset_right = -8
	_sheet.offset_top = -594
	_sheet.offset_bottom = -10
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


func _redraw_map() -> void:
	for id in _city_buttons:
		var btn: Button = _city_buttons[id]
		var c: Dictionary = CampaignData.CITIES[id]
		var mark := ""
		if id == campaign.location:
			mark = " 📍"
		if not campaign.poi_at(id).is_empty():
			mark += " ❓"
		# С нарисованной эмблемой эмодзи города не нужен
		if btn.icon != null:
			btn.text = "%s%s" % [c["name"], mark]
		else:
			btn.text = "%s\n%s%s" % [c["icon"], c["name"], mark]
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
		_sheet_title.text = "%s %s — рынок" % [c["icon"], c["name"]]
		_render_market(is_here)
	elif _view == "contracts":
		_sheet_title.text = "%s %s — доска контрактов" % [c["icon"], c["name"]]
		_render_contracts(is_here)
	elif _view == "base":
		_sheet_title.text = "%s %s — БАЗА" % [c["icon"], c["name"]]
		_render_base(is_here)
	elif _view == "lab":
		_sheet_title.text = "%s %s — ЛАБОРАТОРИЯ" % [c["icon"], c["name"]]
		_render_lab(is_here)
	elif _view == "hangar":
		_sheet_title.text = "%s %s — АНГАР ТРОФЕЕВ" % [c["icon"], c["name"]]
		_render_hangar(is_here)
	elif _view == "showroom":
		_sheet_title.text = "%s %s — ШОУРУМ ПЛАТФОРМ" % [c["icon"], c["name"]]
		_render_showroom(is_here)
	elif _view == "settings":
		_sheet_title.text = "⚙ НАСТРОЙКИ ФУРЫ"
		_render_settings()
	else:
		_sheet_title.text = "%s %s" % [c["icon"], c["name"]]
		_render_info(c, is_here, route)


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
	var frac := _mk_label(_sheet_body, 19, Color(0.7, 0.85, 0.9).lerp(Color(0.95, 0.8, 0.4), rep_lvl / 4.0))
	frac.text = "🎪 %s — отношение: %s (%d/100). Скидка -%d%%, скупка +%d%%, контракты +%d%%" % [
		c.get("faction", "фракция"), campaign.rep_title(_selected), campaign.rep_of(_selected),
		rep_lvl * 4, rep_lvl * 3, rep_lvl * 5]
	frac.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			var pbtn := _rusty_button("🔎 Осмотреть", Color(0.85, 0.75, 0.4))
			pbtn.custom_minimum_size = Vector2(150, 58)
			pbtn.pressed.connect(func(): _resolve_poi_at(_selected))
			prow.add_child(pbtn)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	_sheet_body.add_child(btns)
	if is_here:
		var mk := _rusty_button("⛺ Рынок")
		mk.custom_minimum_size = Vector2(160, 58)
		mk.pressed.connect(func(): _open_view("market"))
		btns.add_child(mk)
		var ct := _rusty_button("📋 Контракты")
		ct.custom_minimum_size = Vector2(170, 58)
		ct.pressed.connect(func(): _open_view("contracts"))
		btns.add_child(ct)
		var tn := 0
		for t in campaign.trophies:
			tn += int(campaign.trophies[t])
		var hg := _rusty_button("🛻 Ангар (%d)" % tn, Color(0.75, 0.7, 0.55))
		hg.custom_minimum_size = Vector2(160, 58)
		hg.pressed.connect(func(): _open_view("hangar"))
		btns.add_child(hg)
		if bool(c.get("home", false)):
			var btns2 := HBoxContainer.new()
			btns2.add_theme_constant_override("separation", 8)
			_sheet_body.add_child(btns2)
			var bb := _rusty_button("🏠 База", Color(0.85, 0.7, 0.3))
			bb.custom_minimum_size = Vector2(150, 58)
			bb.pressed.connect(func(): _open_view("base"))
			btns2.add_child(bb)
			var lb := _rusty_button("⚗️ Лаборатория" if campaign.bld_level("lab") > 0 else "⚗️ Лаборатория (нет)", Color(0.7, 0.8, 0.5))
			lb.custom_minimum_size = Vector2(210, 58)
			lb.disabled = campaign.bld_level("lab") == 0
			lb.pressed.connect(func(): _open_view("lab"))
			btns2.add_child(lb)
			var sr := _rusty_button("🛠 Шоурум", Color(0.95, 0.7, 0.35))
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
			tags += " ☠ СМЕРТЕЛЬНАЯ ТРАССА"
		if CampaignData.route_is_caravan(campaign.location, _selected):
			tags += " 🐫 караванный тракт"
		var go := _rusty_button("🚚 В РЕЙС: %d волн, ★%.1f%s" % [waves_count, float(route[1]), tags], Color(0.9, 0.5, 0.25))
		go.custom_minimum_size = Vector2(360, 58)
		go.add_theme_font_size_override("font_size", _font(22))
		go.pressed.connect(func(): travel_requested.emit(_selected))
		btns.add_child(go)
	else:
		var nope := _mk_label(btns, 20, Color(0.6, 0.5, 0.4))
		nope.text = "Прямой дороги нет — езжай через соседей."


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


func _render_market(is_here: bool) -> void:
	if not is_here:
		var l := _mk_label(_sheet_body, 20, Color(0.7, 0.55, 0.4))
		l.text = "Торговать можно только в городе, где стоит фура."
		return
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
		name_l.text = "%s ⚙%d/⚙%d  (трюм: %d)" % [d["name"], bp, sp, campaign.cargo_qty(res)]
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
	fhead.text = "⚒ КУЗНЯ ТРОФЕЕВ"
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
	ahead.text = "⚒ КУЗНЯ СПОСОБНОСТЕЙ (навсегда)"
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
	head.text = "🔧 Запчасти: %d   ⚙ Лом: %d   🛠 Мастерская ур.%d" % [
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
			txt.modulate = Color(1, 1, 1) if lab_ok else Color(1, 1, 1, 0.45)
			b.text = "Начать"
			b.disabled = not campaign.can_research(id)
			var rid: String = id
			b.pressed.connect(func(): campaign.start_research(rid); _render_sheet())
		row.add_child(txt)
		row.add_child(b)

	# Крафт-модули
	var ct := _mk_label(_sheet_body, 21, ACCENT)
	ct.text = "— Крафт-модули (на 1 рейс) —"
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
			b.text = "🔒"
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
			var st := _rusty_button("В рейс" if not taken else "✅ взят", Color(0.9, 0.55, 0.25))
			st.custom_minimum_size = Vector2(100, 58)
			st.disabled = taken
			var sid: String = id
			st.pressed.connect(func(): campaign.stage_item(sid); _render_sheet())
			row.add_child(st)


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

	func _draw() -> void:
		for r: Array in CDATA.ROUTES:
			var a: Vector2 = (CDATA.CITIES[r[0]]["pos"] as Vector2) * size
			var b: Vector2 = (CDATA.CITIES[r[1]]["pos"] as Vector2) * size
			var col := Color(0.45, 0.35, 0.2, 0.9)
			if float(r[3]) >= 1.4:
				col = Color(0.8, 0.18, 0.1, 0.95)   # смертельная трасса
			elif float(r[3]) >= 1.2:
				col = Color(0.6, 0.3, 0.15, 0.9)
			draw_line(a, b, col, 4.0, true)
			draw_circle(a, 5.0, col)
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
