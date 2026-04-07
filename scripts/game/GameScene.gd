# GameScene.gd
extends Node2D

@onready var map: Node2D = $Map
@onready var camera: Camera2D = $Player/Camera2D
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

@export var kiosk_scene: PackedScene
@export var door_scene: PackedScene

var shake_intensity: float = 0.0
var shake_active: bool = false
var original_position: Vector2

var hit_shake_timer: float = 0.0
var hit_shake_intensity: float = 0.0

var crack_polygons: Array = []

var kiosk_instance: Node = null
var door_instance: Node = null

var status_panel_instance: Node = null

func _ready():
	original_position = position
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)
	GameManager.game_over_started.connect(_on_game_over_started)
	StageManager.stage_cleared.connect(_on_stage_cleared)
	StageManager.start_stage(1)
	
	var sp_script = preload("res://scripts/ui/status_panel.gd")
	status_panel_instance = CanvasLayer.new()
	status_panel_instance.set_script(sp_script)
	status_panel_instance.name = "StatusPanel"
	add_child(status_panel_instance)
	
	_play_intro_zoom()

func _process(delta: float):
	_handle_shake()
	_handle_hit_shake(delta)
	
func _unhandled_input(event: InputEvent) -> void:
	# 디버그용 치트
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			GameManager.currency += 1000
			GameManager.currency_changed.emit(GameManager.currency)
			print("[CHEAT] Gold +1000")
		elif event.keycode == KEY_F2:
			print("[CHEAT] Trigger Stage Cleared (Spawn Complete)")
			StageManager.spawned_bricks = StageManager.total_bricks
			StageManager.stage_cleared.emit()

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

# 임시적으로 진동을 제거함
func trigger_hit_shake(intensity: float = 0.0, duration: float = 0.08):
	hit_shake_intensity = intensity
	hit_shake_timer = duration

func _handle_hit_shake(delta: float):
	if hit_shake_timer <= 0.0:
		return
	hit_shake_timer -= delta
	camera.offset = Vector2(
		randf_range(-hit_shake_intensity, hit_shake_intensity),
		randf_range(-hit_shake_intensity, hit_shake_intensity)
	)
	if hit_shake_timer <= 0.0:
		camera.offset = Vector2.ZERO

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
	
func _on_stage_cleared():
	_spawn_stage_objects()
	
func _spawn_stage_objects():
	var map = $Map
	var center_x = (map.wall_left_x + map.wall_right_x) / 2.0
	var floor_y = map.floor_y

	# 키오스크 (중앙 왼쪽)
	if kiosk_scene:
		kiosk_instance = kiosk_scene.instantiate()
		kiosk_instance.position = Vector2(center_x - 100, floor_y - 40)
		add_child(kiosk_instance)

	# 문 (중앙 오른쪽)
	if door_scene:
		door_instance = door_scene.instantiate()
		door_instance.position = Vector2(center_x + 100, floor_y - 50)
		door_instance.door_entered.connect(_on_door_entered)
		add_child(door_instance)

func _on_door_entered():
	_transition_to_next_stage()

func _show_shop():
	var shop = get_node_or_null("ShopPanel")
	if shop:
		shop.open_shop()
	else:
		_transition_to_next_stage()

func _transition_to_next_stage():
	get_tree().paused = true

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _setup_next_stage())
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): get_tree().paused = false)

func _setup_next_stage():
	# 이자 지급 (다음 스테이지 시작 직전)
	_apply_interest()
	
	var shop = get_node_or_null("ShopPanel")
	if shop and shop.has_method("reset_shop"):
		shop.reset_shop()

	# 키오스크, 문 제거
	if kiosk_instance and is_instance_valid(kiosk_instance):
		kiosk_instance.queue_free()
	if door_instance and is_instance_valid(door_instance):
		door_instance.queue_free()

	# 기존 벽돌 · 로봇 제거
	for node in get_children():
		if node.is_in_group("brick") or node.is_in_group("robot"):
			node.queue_free()
			
	$Map.regenerate_walls()

	# 무게 초기화
	GameManager.current_weight = 0.0
	GameManager.weight_changed.emit(0.0, GameManager.MAX_WEIGHT)
	GameManager.current_weight_stage = "normal"
	GameManager.weight_stage_changed.emit("normal")

	# 플레이어 위치 초기화
	var player = get_node_or_null("Player")
	if player:
		player.global_position = Vector2(940, 620)
		player.velocity = Vector2.ZERO

	StageManager.start_stage(StageManager.current_stage + 1)

# 스테이지 클리어 시 보유 재화에 이자 적용
func _apply_interest() -> void:
	var player = get_node_or_null("Player")
	if player == null:
		return
	# player.interest_rate에 레벨업 + ItemManager의 interest_bonus가 이미 누적됨
	var rate: float = player.interest_rate
	if rate <= 0.0:
		return
	var bonus = int(GameManager.currency * rate)
	if bonus > 0:
		GameManager.add_currency(bonus)
