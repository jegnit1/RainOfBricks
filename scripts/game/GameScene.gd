# GameScene.gd
extends Node2D

@onready var map: Node2D = $Map

var shake_intensity: float = 0.0
var shake_active: bool = false
var original_position: Vector2

var crack_polygons: Array = []

func _ready():
	original_position = position
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)
	GameManager.game_over_started.connect(_on_game_over_started)

func _process(delta: float):
	_handle_shake()

func _handle_shake():
	if not shake_active:
		return
	position = original_position + Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)

func _stop_shake():
	shake_active = false
	shake_intensity = 0.0
	position = original_position

func _on_weight_stage_changed(stage: String):
	match stage:
		"normal":
			_stop_shake()
			_clear_cracks()
		"warning":
			shake_intensity = 1.0   # 약하게
			shake_active = true
		"danger":
			shake_intensity = 2.5   # 중간
			shake_active = true
			_add_cracks()

func _on_game_over_started():
	_stop_shake()
	_clear_cracks()
	_play_floor_collapse()

func _play_floor_collapse():
	# 바닥 노드만 가져옴
	var floor_node = $Map/Floor

	var tween = create_tween()

	# 1단계: 바닥만 강하게 진동 (0.4초)
	tween.tween_method(
		func(t: float):
			floor_node.position += Vector2(
				randf_range(-8.0, 8.0),
				randf_range(-4.0, 4.0)
			),
		0.0, 1.0, 0.4
	)

	# 2단계: 바닥이 화면 아래로 떨어짐 (0.5초)
	tween.tween_property(
		floor_node, "position",
		floor_node.position + Vector2(0, 300),
		0.5
	).set_ease(Tween.EASE_IN)

	# 3단계: 연출 완료 → 게임오버 패널
	tween.tween_callback(func():
		GameManager.finish_game_over()
	)

func _add_cracks():
	_clear_cracks()
	for i in range(5):
		var crack = Polygon2D.new()
		var x = randf_range(100, 1180)
		var y = randf_range(580, 670)
		crack.polygon = PackedVector2Array([
			Vector2(x,      y),
			Vector2(x + 3,  y + randf_range(20, 50)),
			Vector2(x + 6,  y + randf_range(10, 30)),
			Vector2(x + 10, y + randf_range(30, 70)),
			Vector2(x + 7,  y + randf_range(30, 70)),
			Vector2(x + 3,  y + randf_range(10, 30)),
			Vector2(x - 1,  y + randf_range(20, 50)),
		])
		crack.color = Color(0.1, 0.1, 0.1, 0.8)
		crack.z_index = 10
		add_child(crack)
		crack_polygons.append(crack)

func _clear_cracks():
	for crack in crack_polygons:
		crack.queue_free()
	crack_polygons.clear()
