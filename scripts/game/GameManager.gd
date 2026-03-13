# GameManager.gd
extends Node

signal game_over
signal weight_changed(current: float, max: float)

const MAX_WEIGHT: float = 100.0

var current_weight: float = 0.0
var is_game_over: bool = false

func _ready():
	print("GameManager 초기화 완료")

func add_weight(amount: float):
	if is_game_over:
		return
	current_weight += amount
	weight_changed.emit(current_weight, MAX_WEIGHT)
	if current_weight >= MAX_WEIGHT:
		trigger_game_over()

func remove_weight(amount: float):
	current_weight = max(0.0, current_weight - amount)
	weight_changed.emit(current_weight, MAX_WEIGHT)

func trigger_game_over():
	if is_game_over:
		return
	is_game_over = true
	print("게임오버!")
	game_over.emit()

func reset():
	current_weight = 0.0
	is_game_over = false
	weight_changed.emit(current_weight, MAX_WEIGHT)
