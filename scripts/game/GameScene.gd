# GameScene.gd
extends Node2D

@onready var map: Node2D = $Map
@onready var camera: Camera2D = $Player/Camera2D

var shake_intensity: float = 0.0
var shake_active: bool = false
var original_position: Vector2

var crack_polygons: Array = []

func _ready():
	original_position = position
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)
	GameManager.game_over_started.connect(_on_game_over_started)
	_play_intro_zoom()

func _process(delta: float):
	_handle_shake()
	
func _play_intro_zoom():
	get_tree().paused = true

	var map_width = 1880.0
	var screen_width = 1280.0
	var fit_zoom = screen_width / map_width

	camera.zoom = Vector2(fit_zoom, fit_zoom)
	camera.position_smoothing_enabled = false

	# 줌아웃 시 카메라를 맵 중앙으로 강제 이동
	# Camera2D는 플레이어 자식이므로 offset으로 보정
	var map_center_x = map_width / 2.0   # 940
	var player_x = 940.0
	camera.offset = Vector2(map_center_x - player_x, 0)  # 0 (이미 중앙)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.5)
	tween.tween_property(camera, "zoom",
		Vector2(1.0, 1.0), 1.2
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# 줌인 완료 후 offset 원복
	tween.parallel().tween_property(camera, "offset",
		Vector2.ZERO, 1.2
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		camera.position_smoothing_enabled = true
		get_tree().paused = false
	)

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
	_release_all_bodies()
	_play_floor_collapse()
	
func _release_all_bodies():
	# 플레이어 자유낙하
	var player = get_node_or_null("Player")
	if player:
		player.set_physics_process(false)
		# 자체 tween으로 낙하
		var tween = create_tween()
		tween.tween_property(player, "position",
			player.position + Vector2(0, 800), 1.2
		).set_ease(Tween.EASE_IN)

	# 활성 로봇 자유낙하
	for node in get_children():
		if node is CharacterBody2D and node.name != "Player":
			node.set_physics_process(false)
			var tween = create_tween()
			tween.tween_property(node, "position",
				node.position + Vector2(0, 800), 1.0
			).set_ease(Tween.EASE_IN)

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
