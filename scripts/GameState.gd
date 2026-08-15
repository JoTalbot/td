extends Node
## Экономика и жизни базы.

signal money_changed(value: int)
signal lives_changed(value: int)
signal game_over

const START_MONEY := 220
const START_LIVES := 20

var money: int = START_MONEY
var lives: int = START_LIVES
var is_game_over: bool = false


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func earn(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func lose_life(amount: int = 1) -> void:
	if is_game_over:
		return
	lives = maxi(lives - amount, 0)
	lives_changed.emit(lives)
	if lives <= 0:
		is_game_over = true
		game_over.emit()
