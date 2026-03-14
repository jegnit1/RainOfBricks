# GameManager.gd
extends Node

signal game_over          # 패널 표시용
signal game_over_started  # 연출 시작용

signal weight_changed(current: float, max_weight: float)
signal currency_changed(amount: int)
signal weight_stage_changed(stage: String)  # "normal" / "warning" / "danger"

var MAX_WEIGHT: float = 100.0  # const → var 로 변경 (스테이지별 가변)

var current_weight: float = 0.0
var is_game_over: bool = false
var currency: int = 0
var current_weight_stage: String = "normal"

func _ready():
	print("GameManager 초기화 완료")

# 스테이지별 최대 무게 변경
func set_max_weight(value: float):
	MAX_WEIGHT = value
	weight_changed.emit(current_weight, MAX_WEIGHT)

func add_weight(amount: float):
	if is_game_over:
		return
	current_weight += amount
	weight_changed.emit(current_weight, MAX_WEIGHT)
	_check_weight_stage()
	if current_weight >= MAX_WEIGHT:
		trigger_game_over()

func remove_weight(amount: float):
	current_weight = max(0.0, current_weight - amount)
	weight_changed.emit(current_weight, MAX_WEIGHT)
	_check_weight_stage()

func _check_weight_stage():
	var ratio = current_weight / MAX_WEIGHT
	var new_stage: String

	if ratio >= 0.9:
		new_stage = "danger"
	elif ratio >= 0.8:
		new_stage = "warning"
	else:
		new_stage = "normal"

	if new_stage != current_weight_stage:
		current_weight_stage = new_stage
		weight_stage_changed.emit(current_weight_stage)

func add_currency(amount: int):
	currency += amount
	currency_changed.emit(currency)

func trigger_game_over():
	if is_game_over:
		return
	is_game_over = true
	# 시그널은 즉시 발신하지 않음
	# GameScene에서 연출 후 finish_game_over() 호출
	game_over_started.emit()  # 연출 시작 신호
	
func finish_game_over():
	game_over.emit()  # 패널 표시 신호

func reset():
	current_weight = 0.0
	is_game_over = false
	currency = 0
	current_weight_stage = "normal"
	weight_changed.emit(current_weight, MAX_WEIGHT)
	currency_changed.emit(currency)
	weight_stage_changed.emit(current_weight_stage)
