extends Node
## Ресурсы (металлолом) и прочность грузовика.

signal scrap_changed(value: int)
signal hp_changed(hp: int, max_hp: int)
signal game_over

const START_SCRAP := 150
const START_HP := 100

var scrap: int = START_SCRAP
var hp: int = START_HP
var max_hp: int = START_HP
var is_game_over: bool = false

## Множитель дальности орудий (песчаная буря и т.п.). Крутится дорожными событиями.
var weapon_range_mult := 1.0

## Множитель наград ломом (мета-улучшение «Скупщик хлама»).
var reward_mult := 1.0

var _heal_accum := 0.0
var _invulnerable := 0.0


func _process(delta: float) -> void:
	if _invulnerable > 0.0:
		_invulnerable = maxf(_invulnerable - delta, 0.0)


## Временная неуязвимость фуры (способность «Щит»).
func grant_invulnerability(seconds: float) -> void:
	_invulnerable = maxf(_invulnerable, seconds)


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func spend(amount: int) -> bool:
	if amount > scrap:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true


func earn(amount: int) -> void:
	scrap += int(round(amount * reward_mult))
	scrap_changed.emit(scrap)


func damage_truck(amount: int) -> void:
	if is_game_over or is_invulnerable():
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		is_game_over = true
		game_over.emit()


func heal(amount: float) -> void:
	if is_game_over:
		return
	_heal_accum += amount
	if _heal_accum >= 1.0:
		var whole := int(_heal_accum)
		_heal_accum -= whole
		hp = mini(hp + whole, max_hp)
		hp_changed.emit(hp, max_hp)


func add_max_hp(amount: int) -> void:
	max_hp += amount
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
