# GameScene.gd
extends Node2D

@onready var map: Node2D = $Map

# 진동 관련
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var original_position: Vector2

# 균열 이펙트 (Polygon2D로 표현)
var crack_polygons: Array = []

func _ready():
	original_position = position
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)
	GameManager.game_over_started.connect(_on_game_over_started)  # 변경
	
func _on_game_over_started():
	shake_intensity = 0.0
	position = original_position
	_play_floor_collapse()

func _process(delta: float):
	_handle_shake(delta)

func _handle_shake(delta: float):
	if shake_intensity <= 0:
		return

	shake_timer -= delta

	# 랜덤 방향으로 진동
	var offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	position = original_position + offset

	if shake_timer <= 0:
		shake_timer = 0.05  # 진동 갱신 주기
	
func _on_weight_stage_changed(stage: String):
	match stage:
		"normal":
			shake_intensity = 0.0
			position = original_position
			_clear_cracks()
		"warning":
			shake_intensity = 2.0   # 약한 진동
			shake_timer = 0.05
		"danger":
			shake_intensity = 5.0   # 강한 진동
			shake_timer = 0.05
			_add_cracks()

func _on_game_over():
	shake_intensity = 0.0
	position = original_position
	_play_floor_collapse()

# 균열 이펙트 생성
func _add_cracks():
	_clear_cracks()
	for i in range(5):  # 균열 5개 랜덤 생성
		var crack = Polygon2D.new()
		var x = randf_range(100, 1180)
		var y = randf_range(500, 680)
		crack.polygon = PackedVector2Array([
			Vector2(x,      y),
			Vector2(x + 3,  y + randf_range(20, 60)),
			Vector2(x + 6,  y + randf_range(10, 30)),
			Vector2(x + 10, y + randf_range(30, 80)),
			Vector2(x + 7,  y + randf_range(30, 80)),
			Vector2(x + 3,  y + randf_range(10, 30)),
			Vector2(x - 1,  y + randf_range(20, 60)),
		])
		crack.color = Color(0.1, 0.1, 0.1, 0.8)
		crack.z_index = 10
		add_child(crack)
		crack_polygons.append(crack)

func _clear_cracks():
	for crack in crack_polygons:
		crack.queue_free()
	crack_polygons.clear()

# 바닥 붕괴 연출
func _play_floor_collapse():
	_clear_cracks()
	var tween = create_tween()
	# 강한 진동 0.3초
	tween.tween_method(_shake_strong, 0.0, 1.0, 0.3)
	# 화면 아래로 꺼짐 0.5초
	tween.tween_property(self, "position", original_position + Vector2(0, 400), 0.5)\
		.set_ease(Tween.EASE_IN)
	# 연출 완료 후 게임오버 패널 표시
	tween.tween_callback(func():
		position = original_position
		GameManager.finish_game_over()
	)

func _shake_strong(t: float):
	var intensity = 12.0
	position = original_position + Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
