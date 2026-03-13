# HUD.gd
extends CanvasLayer

@onready var weight_bar: ProgressBar = $WeightBar
@onready var weight_label: Label = $WeightLabel
@onready var game_over_panel: Panel = $GameOverPanel

func _ready():
	# GameManager 시그널 연결
	GameManager.weight_changed.connect(_on_weight_changed)
	GameManager.game_over.connect(_on_game_over)
	
	# 초기 상태
	game_over_panel.visible = false
	_update_weight(0.0, GameManager.MAX_WEIGHT)

func _on_weight_changed(current: float, max_weight: float):
	_update_weight(current, max_weight)

func _update_weight(current: float, max_weight: float):
	weight_bar.max_value = max_weight
	weight_bar.value = current
	weight_label.text = "%d / %d" % [current, max_weight]
	
	# 무게에 따라 게이지 색 변경
	if current / max_weight >= 0.8:
		weight_bar.modulate = Color(1, 0, 0)      # 빨간색 (위험)
	elif current / max_weight >= 0.5:
		weight_bar.modulate = Color(1, 0.6, 0)    # 주황색 (경고)
	else:
		weight_bar.modulate = Color(0, 0.8, 0)    # 초록색 (안전)

func _on_game_over():
	game_over_panel.visible = true
