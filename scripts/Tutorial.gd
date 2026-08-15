extends Node
## Обучение новичка: одноразовые контекстные подсказки поверх игры.
## Каждая показывается ровно один раз (флаги в мета-сейве MetaProgress).
## Тап по баннеру — «понял»: закрыть и больше не показывать.

var main: Node
var hud: Node
var state: Node
var waves: Node
var truck: Node3D
var meta: Node

## События от Main: travel / mounted / ability / arrival / gameover.
var _events: Dictionary = {}
var _showing := ""
var _show_until := 0.0
var _tick := 0.0


func setup(p_main: Node, p_hud: Node, p_state: Node, p_waves: Node, p_truck: Node3D, p_meta: Node) -> void:
	main = p_main
	hud = p_hud
	state = p_state
	waves = p_waves
	truck = p_truck
	meta = p_meta
	hud.hint_dismissed.connect(_on_hint_dismissed)


func _on_hint_dismissed() -> void:
	if _showing != "":
		meta.mark_tutorial(_showing)
		_showing = ""


## Main сообщает контекст: рейс начался, орудие куплено, способность жмакнута...
func notify(what: String) -> void:
	_events[what] = true
	# Контексты перезатирают друг друга: «следующий выезд» — только после прибытия
	if what == "travel":
		_events.erase("arrival")
		_events.erase("gameover")
	elif what == "arrival" or what == "gameover":
		_events.erase("travel")


## Всё обучение пройдено — для тестов и диагностики.
func all_done() -> bool:
	for s in _steps():
		if not meta.tutorial_seen(String(s["id"])):
			return false
	return true


func _process(delta: float) -> void:
	if meta == null or state == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_step()


func _step() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Текущая подсказка: сама решилась (игрок разобрался) или таймаут
	if _showing != "":
		if _done_condition(_showing) or now > _show_until:
			hud.hide_hint()
			meta.mark_tutorial(_showing)
			_showing = ""
		return
	for s in _steps():
		if meta.tutorial_seen(String(s["id"])):
			continue
		if not bool((s["when"] as Callable).call()):
			continue
		_showing = String(s["id"])
		_show_until = now + float(s.get("timeout", 8.0))
		hud.show_hint(String(s["text"]))
		return


## Подсказка закрывается раньше таймаута, если игрок сам всё сделал.
func _done_condition(id: String) -> bool:
	match id:
		"map_intro":
			return _events.has("travel")
		"build_first":
			return truck.weapons.size() > 0
		"upgrade_hint":
			return hud._weapon_panel.visible   # сам тапнул орудие — разобрался
		"abilities_hint":
			return _events.has("ability")
		"arrival_intro":
			return _events.has("travel")   # уехал дальше — точно разобрался
		"gameover_intro":
			return _events.has("travel")
	return false


## Сценарий: when — когда показывать, timeout — потолок показа (сек).
func _steps() -> Array:
	return [
		{"id": "map_intro", "timeout": 40.0,
			"text": "🗺 Карта пустоши. Жмите город на дороге — и «В путь!» Рейс — это несколько волн рейдеров.",
			"when": func() -> bool: return not main.battle_active},
		{"id": "build_first", "timeout": 30.0,
			"text": "🔨 Слоты фуры пусты! Тапните по пустому слоту на платформе и купите орудие за лом.",
			"when": func() -> bool: return main.battle_active and truck.weapons.is_empty()},
		{"id": "upgrade_hint", "timeout": 12.0,
			"text": "⚙ Орудие на борту! Тап по орудию — прокачка до 3-го уровня или демонтаж.",
			"when": func() -> bool: return main.battle_active and truck.weapons.size() > 0},
		{"id": "abilities_hint", "timeout": 16.0,
			"text": "⚡ Слева — способности экипажа. «Залп» бьёт по всем врагам разом: спасает, когда жарко!",
			"when": func() -> bool: return main.battle_active and waves.wave_index >= 1},
		{"id": "arrival_intro", "timeout": 10.0,
			"text": "🏙 Город! Кнопки листа города — рынок, контракты, ангар с кузней. Чертежи тратьте в Мастерской.",
			"when": func() -> bool: return _events.has("arrival") and not main.battle_active},
		{"id": "gameover_intro", "timeout": 10.0,
			"text": "💀 Фура пала, но чертежи при вас. Мастерская на карте усиливает навсегда — и снова в рейс!",
			"when": func() -> bool: return _events.has("gameover") and not main.battle_active},
	]
