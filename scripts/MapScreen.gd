extends CanvasLayer
## Карта пустоши: города, дороги, выбор рейса, рынок и контракты в городе.
## Всё рисуется кодом — процедурный UI в духе проекта.

signal travel_requested(city_id: String)

const CampaignData := preload("res://scripts/CampaignData.gd")

var campaign: Node = null
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
var _selected := ""
var _view := "info"   # info | market | contracts


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
	top.offset_bottom = 58
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row)
	_loc_label = _mk_label(row, 19, ACCENT)
	_wallet_label = _mk_label(row, 19, Color(0.95, 0.75, 0.35))
	_cargo_label = _mk_label(row, 19, Color(0.8, 0.85, 0.6))
	_day_label = _mk_label(row, 17, TEXT_DIM)


func _mk_label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


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
	var area_size := Vector2(704, 600)
	_map_area = MapCanvas.new()
	_map_area.position = Vector2(8, 70)
	_map_area.size = area_size
	add_child(_map_area)
	for id in CampaignData.CITIES:
		var c: Dictionary = CampaignData.CITIES[id]
		var btn := _rusty_button("%s\n%s" % [c["icon"], c["name"]], ACCENT)
		btn.custom_minimum_size = Vector2(150, 62)
		btn.add_theme_font_size_override("font_size", 15)
		btn.position = c["pos"] * area_size - Vector2(75, 31)
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
	_sheet_title = _mk_label(col, 20, ACCENT)
	_sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_body = VBoxContainer.new()
	_sheet_body.add_theme_constant_override("separation", 6)
	col.add_child(_sheet_body)


func _redraw_map() -> void:
	for id in _city_buttons:
		var btn: Button = _city_buttons[id]
		var c: Dictionary = CampaignData.CITIES[id]
		var mark := ""
		if id == campaign.location:
			mark = " 📍"
		if not campaign.poi_at(id).is_empty():
			mark += " ❓"
		btn.text = "%s\n%s%s" % [c["icon"], c["name"], mark]
	_map_area.queue_redraw()


func _select(id: String) -> void:
	_selected = id
	_view = "info"
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
	else:
		_sheet_title.text = "%s %s" % [c["icon"], c["name"]]
		_render_info(c, is_here, route)


func _render_info(c: Dictionary, is_here: bool, route: Array) -> void:
	var desc := _mk_label(_sheet_body, 15, TEXT_DIM)
	desc.text = c["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spec := _mk_label(_sheet_body, 14, Color(0.8, 0.85, 0.6))
	var cheap: Array = []
	for r in c["mods"]:
		if float(c["mods"][r]) < 0.85:
			cheap.append("%s %s" % [CampaignData.RESOURCES[r]["icon"], CampaignData.RESOURCES[r]["name"]])
	spec.text = "Дёшево тут: %s" % (", ".join(cheap) if not cheap.is_empty() else "ничего особенного")
	spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Фракция и наше положение в ней
	var rep_lvl: int = campaign.rep_level(_selected)
	var frac := _mk_label(_sheet_body, 14, Color(0.7, 0.85, 0.9).lerp(Color(0.95, 0.8, 0.4), rep_lvl / 4.0))
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
			var plab := _mk_label(prow, 14, Color(0.85, 0.75, 0.4))
			plab.text = "%s %s — %s" % [poi["icon"], poi["name"], poi["desc"]]
			plab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			plab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pbtn := _rusty_button("🔎 Осмотреть", Color(0.85, 0.75, 0.4))
			pbtn.custom_minimum_size = Vector2(150, 46)
			pbtn.pressed.connect(func(): _resolve_poi_at(_selected))
			prow.add_child(pbtn)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	_sheet_body.add_child(btns)
	if is_here:
		var mk := _rusty_button("⛺ Рынок")
		mk.custom_minimum_size = Vector2(160, 52)
		mk.pressed.connect(func(): _view = "market"; _render_sheet())
		btns.add_child(mk)
		var ct := _rusty_button("📋 Контракты")
		ct.custom_minimum_size = Vector2(170, 52)
		ct.pressed.connect(func(): _view = "contracts"; _render_sheet())
		btns.add_child(ct)
		var tn := 0
		for t in campaign.trophies:
			tn += int(campaign.trophies[t])
		var hg := _rusty_button("🛻 Ангар (%d)" % tn, Color(0.75, 0.7, 0.55))
		hg.custom_minimum_size = Vector2(160, 52)
		hg.pressed.connect(func(): _view = "hangar"; _render_sheet())
		btns.add_child(hg)
		if bool(c.get("home", false)):
			var btns2 := HBoxContainer.new()
			btns2.add_theme_constant_override("separation", 8)
			_sheet_body.add_child(btns2)
			var bb := _rusty_button("🏠 База", Color(0.85, 0.7, 0.3))
			bb.custom_minimum_size = Vector2(150, 52)
			bb.pressed.connect(func(): _view = "base"; _render_sheet())
			btns2.add_child(bb)
			var lb := _rusty_button("⚗️ Лаборатория" if campaign.bld_level("lab") > 0 else "⚗️ Лаборатория (нет)", Color(0.7, 0.8, 0.5))
			lb.custom_minimum_size = Vector2(210, 52)
			lb.disabled = campaign.bld_level("lab") == 0
			lb.pressed.connect(func(): _view = "lab"; _render_sheet())
			btns2.add_child(lb)
	elif not route.is_empty():
		var waves_count := 4 + int(route[0]) * 2
		var go := _rusty_button("🚚 В РЕЙС: %d волн, опасность ★%.0f" % [waves_count, float(route[1])], Color(0.9, 0.5, 0.25))
		go.custom_minimum_size = Vector2(360, 56)
		go.add_theme_font_size_override("font_size", 17)
		go.pressed.connect(func(): travel_requested.emit(_selected))
		btns.add_child(go)
	else:
		var nope := _mk_label(btns, 15, Color(0.6, 0.5, 0.4))
		nope.text = "Прямой дороги нет — езжай через соседей."


## Осмотр находки дня: разрешаем и показываем итог поверх листа города.
func _resolve_poi_at(city: String) -> void:
	var res: Dictionary = campaign.resolve_poi(city)
	_render_sheet()
	if res.is_empty():
		return
	var box := _mk_label(_sheet_body, 15, Color(0.95, 0.85, 0.5))
	box.text = "%s: %s" % [res.get("title", "Находка"), res.get("text", "")]
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_body.move_child(box, 0)


## Звон лома для сделок рынка (защита от null в smoke-тестах).
func _play_earn() -> void:
	if sfx != null:
		sfx.play("earn", 0.7)


func _render_market(is_here: bool) -> void:
	var back := _rusty_button("← К описанию")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func(): _view = "info"; _render_sheet())
	_sheet_body.add_child(back)
	if not is_here:
		var l := _mk_label(_sheet_body, 15, Color(0.7, 0.55, 0.4))
		l.text = "Торговать можно только в городе, где стоит фура."
		return
	for res in CampaignData.RESOURCES:
		var d: Dictionary = CampaignData.RESOURCES[res]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var name_l := _mk_label(row, 15, TEXT_DIM)
		name_l.custom_minimum_size = Vector2(240, 0)
		var bp: int = campaign.buy_price(res, campaign.location)
		var sp: int = int(campaign.price_of(res, campaign.location) * campaign.sell_rate(campaign.location))
		name_l.text = "%s %s ⚙%d/⚙%d  (трюм: %d)" % [d["icon"], d["name"], bp, sp, campaign.cargo_qty(res)]
		var buy_b := _rusty_button("Купить", Color(0.7, 0.85, 0.5))
		buy_b.custom_minimum_size = Vector2(110, 40)
		buy_b.disabled = campaign.wallet < bp or campaign.cargo_space() < 1
		var r: String = res
		buy_b.pressed.connect(func(): if campaign.buy(r, 1): _play_earn(); _render_sheet())
		row.add_child(buy_b)
		var sell_b := _rusty_button("Продать", Color(0.9, 0.6, 0.3))
		sell_b.custom_minimum_size = Vector2(110, 40)
		sell_b.disabled = campaign.cargo_qty(res) < 1
		sell_b.pressed.connect(func(): if campaign.sell(r, 1): _play_earn(); _render_sheet())
		row.add_child(sell_b)


## Ангар: захваченные в рейсах тачки — пилить на ресурсы или продавать.
func _render_hangar(is_here: bool) -> void:
	var back := _rusty_button("← К описанию")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func(): _view = "info"; _render_sheet())
	_sheet_body.add_child(back)
	var total := 0
	for t in campaign.trophies:
		total += int(campaign.trophies[t])
	if total == 0:
		var l := _mk_label(_sheet_body, 15, Color(0.7, 0.55, 0.4))
		l.text = "Пусто. Тачки добываются в рейсах: бей рейдеров — целые обломки отбуксируем сюда."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if not is_here:
		var nl := _mk_label(_sheet_body, 14, Color(0.7, 0.55, 0.4))
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
		var lab := _mk_label(row, 14, TEXT_DIM)
		lab.custom_minimum_size = Vector2(280, 0)
		lab.text = "%s %s ×%d — распил: %s" % [d["icon"], d["name"], have, " ".join(parts)]
		var tid: String = t
		var scr := _rusty_button("Разобрать", Color(0.75, 0.7, 0.55))
		scr.custom_minimum_size = Vector2(130, 40)
		scr.pressed.connect(func(): campaign.scrap_trophy(tid); _render_sheet())
		row.add_child(scr)
		var sel := _rusty_button("⚙%d" % int(d["scrap_price"]), Color(0.9, 0.6, 0.3))
		sel.custom_minimum_size = Vector2(90, 40)
		sel.pressed.connect(func(): campaign.sell_trophy(tid); _render_sheet())
		row.add_child(sel)
	# Кузня легендарок: трофеи плавим в орудия на следующий рейс
	var fhead := _mk_label(_sheet_body, 16, Color(1.0, 0.8, 0.4))
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
		var flab := _mk_label(frow, 14, TEXT_DIM)
		flab.custom_minimum_size = Vector2(440, 0)
		flab.text = "%s %s — %s  [нужно: %s]" % [ld["icon"], ld["name"], ld["desc"], " ".join(needs)]
		var fb := _rusty_button("Сковать", Color(1.0, 0.8, 0.4))
		fb.custom_minimum_size = Vector2(120, 40)
		fb.disabled = not campaign.can_forge(fid)
		var ffid: String = fid
		fb.pressed.connect(func():
			campaign.forge(ffid)
			_play_earn()
			_render_sheet())
		frow.add_child(fb)


func _render_contracts(is_here: bool) -> void:
	var back := _rusty_button("← К описанию")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func(): _view = "info"; _render_sheet())
	_sheet_body.add_child(back)
	var active_t := _mk_label(_sheet_body, 16, ACCENT)
	active_t.text = "— Активные (%d/3) —" % campaign.contracts.size()
	if campaign.contracts.is_empty():
		var l := _mk_label(_sheet_body, 14, TEXT_DIM)
		l.text = "Пусто. Возьми контракт с доски."
	for c in campaign.contracts:
		var l2 := _mk_label(_sheet_body, 14, TEXT_DIM)
		l2.text = campaign.contract_text(c)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var off_t := _mk_label(_sheet_body, 16, ACCENT)
	off_t.text = "— На доске —"
	if not is_here:
		var l3 := _mk_label(_sheet_body, 14, Color(0.7, 0.55, 0.4))
		l3.text = "Доска доступна, только когда фура в городе."
		return
	for c in campaign.offer_list(campaign.location):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var txt := _mk_label(row, 14, TEXT_DIM)
		txt.custom_minimum_size = Vector2(500, 0)
		txt.text = campaign.contract_text(c)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var take := _rusty_button("Взять", Color(0.7, 0.85, 0.5))
		take.custom_minimum_size = Vector2(90, 40)
		take.disabled = campaign.contracts.size() >= 3
		var uid := str(c["uid"])
		take.pressed.connect(func():
			campaign.accept_contract(campaign.location, uid)
			_render_sheet())
		row.add_child(take)


## Вид базы: постройки, их уровни и цены.
func _render_base(is_here: bool) -> void:
	var back := _rusty_button("← К описанию")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func(): _view = "info"; _render_sheet())
	_sheet_body.add_child(back)
	if not is_here:
		var l := _mk_label(_sheet_body, 15, Color(0.7, 0.55, 0.4))
		l.text = "Строить можно только дома."
		return
	for id in CampaignData.BUILDINGS:
		var d: Dictionary = CampaignData.BUILDINGS[id]
		var lvl: int = campaign.bld_level(id)
		var cost: Dictionary = campaign.bld_cost(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var txt := _mk_label(row, 14, TEXT_DIM)
		txt.custom_minimum_size = Vector2(470, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cost.is_empty():
			txt.text = "%s %s [МАКС ур.%d] — %s" % [d["icon"], d["name"], lvl, d["desc"]]
		else:
			var parts: Array = []
			for k in cost:
				if k == "scrap":
					parts.append("⚙%d" % int(cost[k]))
				else:
					parts.append("%s×%d" % [CampaignData.RESOURCES[k]["icon"], int(cost[k])])
			txt.text = "%s %s [ур.%d→%d] — %s  |  цена: %s" % [d["icon"], d["name"], lvl, lvl + 1, d["desc"], " ".join(parts)]
		row.add_child(txt)
		var b := _rusty_button("Строить", Color(0.85, 0.7, 0.3))
		b.custom_minimum_size = Vector2(120, 40)
		b.disabled = cost.is_empty() or not campaign.can_build(id)
		var bid: String = id
		b.pressed.connect(func(): campaign.build(bid); _render_sheet())
		row.add_child(b)


## Вид лаборатории: исследования, крафт, инвентарь модулей.
func _render_lab(is_here: bool) -> void:
	var back := _rusty_button("← К описанию")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func(): _view = "info"; _render_sheet())
	_sheet_body.add_child(back)
	if not is_here:
		var l := _mk_label(_sheet_body, 15, Color(0.7, 0.55, 0.4))
		l.text = "Лаборанты работают только дома."
		return

	# Активное исследование
	if campaign.research_active != "":
		var d: Dictionary = CampaignData.RESEARCH[campaign.research_active]
		var cur := _mk_label(_sheet_body, 15, Color(0.8, 0.85, 0.6))
		cur.text = "⚗️ Идёт: %s %s — осталось рейсов: %d" % [d["icon"], d["name"], campaign.research_left]

	# Список техов
	for id in CampaignData.RESEARCH:
		var d: Dictionary = CampaignData.RESEARCH[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var txt := _mk_label(row, 13, TEXT_DIM)
		txt.custom_minimum_size = Vector2(440, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _rusty_button("", Color(0.7, 0.8, 0.5))
		b.custom_minimum_size = Vector2(110, 38)
		if id in campaign.research_done:
			txt.text = "%s %s ✅ — %s" % [d["icon"], d["name"], d["desc"]]
			b.visible = false
		elif id == campaign.research_active:
			txt.text = "%s %s ⏳ — %s" % [d["icon"], d["name"], d["desc"]]
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
			txt.text = "%s %s [лаб.%d] — %s  |  %s" % [d["icon"], d["name"], d["lab"], d["desc"], " ".join(parts)]
			txt.modulate = Color(1, 1, 1) if lab_ok else Color(1, 1, 1, 0.45)
			b.text = "Начать"
			b.disabled = not campaign.can_research(id)
			var rid: String = id
			b.pressed.connect(func(): campaign.start_research(rid); _render_sheet())
		row.add_child(txt)
		row.add_child(b)

	# Крафт-модули
	var ct := _mk_label(_sheet_body, 16, ACCENT)
	ct.text = "— Крафт-модули (на 1 рейс) —"
	for id in CampaignData.RECIPES:
		var d: Dictionary = CampaignData.RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		var txt := _mk_label(row, 13, TEXT_DIM)
		txt.custom_minimum_size = Vector2(440, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _rusty_button("", Color(0.85, 0.7, 0.4))
		b.custom_minimum_size = Vector2(110, 38)
		txt.text = "%s %s ×%d — %s" % [d["icon"], d["name"], int(campaign.inventory.get(id, 0)), d["desc"]]
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
			st.custom_minimum_size = Vector2(90, 38)
			st.disabled = taken
			var sid: String = id
			st.pressed.connect(func(): campaign.stage_item(sid); _render_sheet())
			row.add_child(st)


## Холст карты: рисует дороги между городами.
class MapCanvas:
	extends Control
	const CDATA := preload("res://scripts/CampaignData.gd")

	func _draw() -> void:
		for r: Array in CDATA.ROUTES:
			var a: Vector2 = (CDATA.CITIES[r[0]]["pos"] as Vector2) * size
			var b: Vector2 = (CDATA.CITIES[r[1]]["pos"] as Vector2) * size
			var col := Color(0.45, 0.35, 0.2, 0.9) if float(r[3]) < 1.2 else Color(0.6, 0.3, 0.15, 0.9)
			draw_line(a, b, col, 4.0, true)
			draw_circle(a, 5.0, col)
		# Рамка пустоши
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.12, 0.5), false, 3.0)
