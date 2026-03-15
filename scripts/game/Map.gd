# Map.gd
extends Node2D

@export var map_width: float = 1880.0   # 전체 맵 너비 확장
@export var map_height: float = 720.0
@export var wall_thickness: float = 300.0  # 벽 두께 대폭 확장
@export var wall_block_scene: PackedScene

# 기존 WALL_THICKNESS 상수 제거 → @export로 변경
# 나머지 코드는 wall_thickness 변수로 교체

var floor_y: float
var wall_left_x: float
var wall_right_x: float
var ceiling_y: float = 0.0

var wall_block_data: Array = []
var wall_blocks: Dictionary = {}

@onready var floor_body: StaticBody2D = $Floor
@onready var wall_left: StaticBody2D = $WallLeft
@onready var wall_right: StaticBody2D = $WallRight

func _ready():
	_build_map()
	_load_wall_data()
	_generate_wall_blocks()

func _build_map():
	floor_y = map_height - wall_thickness / 7.5  # 바닥 두께는 40 유지
	wall_left_x = wall_thickness
	wall_right_x = map_width - wall_thickness
	ceiling_y = 0.0

	_setup_floor()
	_setup_wall_left()
	_setup_wall_right()

func _make_rect_polygon(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-width / 2.0, -height / 2.0),
		Vector2( width / 2.0, -height / 2.0),
		Vector2( width / 2.0,  height / 2.0),
		Vector2(-width / 2.0,  height / 2.0)
	])

func _setup_floor():
	floor_body.position = Vector2(map_width / 2.0, map_height - 20.0)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(map_width, 40.0)
	$Floor/CollisionShape2D.shape = shape

	var poly = $Floor/Polygon2D
	poly.polygon = _make_rect_polygon(map_width, 40.0)
	poly.color = Color(0.4, 0.4, 0.4)

func _setup_wall_left():
	wall_left.position = Vector2(wall_thickness / 2.0, map_height / 2.0)

	# CollisionShape 비활성화 → 격자 블록이 충돌 담당
	$WallLeft/CollisionShape2D.disabled = true

	var poly = $WallLeft/Polygon2D
	poly.polygon = _make_rect_polygon(wall_thickness, map_height)
	poly.color = Color(0, 0, 0, 0)  # 투명


func _setup_wall_right():
	wall_right.position = Vector2(map_width - wall_thickness / 2.0, map_height / 2.0)

	# CollisionShape 비활성화 → 격자 블록이 충돌 담당
	$WallRight/CollisionShape2D.disabled = true

	var poly = $WallRight/Polygon2D
	poly.polygon = _make_rect_polygon(wall_thickness, map_height)
	poly.color = Color(0, 0, 0, 0)

func get_spawn_area() -> Dictionary:
	return {
		"left": wall_left_x,
		"right": wall_right_x,
		"top": ceiling_y,
		"bottom": floor_y
	}
	
func _load_wall_data():
	var file = FileAccess.open("res://data/wall_blocks.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		wall_block_data = data["blocks"]

func _generate_wall_blocks():
	if wall_block_scene == null:
		return

	var block_size = 60.0
	var rows = int(map_height / block_size)

	# 왼쪽 벽 생성
	var left_cols = int(wall_thickness / block_size)
	print("왼쪽 벽 col 범위: 0 ~", left_cols - 1)
	for col in range(left_cols):
		for row in range(rows):
			_place_block(col, row, block_size, true)

	# 오른쪽 벽 생성
	var right_start_col = int(wall_right_x / block_size)
	var right_end_col = int(map_width / block_size)
	print("오른쪽 벽 col 범위:", right_start_col, "~", right_end_col - 1)
	print("rows:", rows)
	for col in range(right_start_col, right_end_col):
		for row in range(rows):
			_place_block(col, row, block_size, false)

func _place_block(col: int, row: int, block_size: float, is_left: bool):
	var block = wall_block_scene.instantiate()
	add_child(block)

	var height_ratio = 1.0 - (float(row) / (map_height / block_size))
	var treasure_data = _roll_treasure(height_ratio)
	var data = wall_block_data[0]
	var pos = Vector2(col * block_size + block_size / 2.0,
					  row * block_size + block_size / 2.0)
	block.setup(data, pos, treasure_data)

	# key를 로컬 변수로 고정
	var key = Vector2i(col, row)
	wall_blocks[key] = block

	# 고정된 key 캡처
	var captured_key = key
	block.block_destroyed.connect(func(b):
		wall_blocks.erase(captured_key)
	)

func _roll_treasure(height_ratio: float) -> Dictionary:
	# 높이가 높을수록 고등급 보물상자 확률 증가
	var rand = randf()
	var threshold = 0.08 + height_ratio * 0.15  # 최대 23%

	if rand > threshold:
		return {}  # 보물상자 없음

	# 등급 결정 (높이 비율 기반)
	if height_ratio > 0.8 and randf() < 0.3:
		return { "grade": "diamond" }
	elif height_ratio > 0.6 and randf() < 0.4:
		return { "grade": "gold" }
	elif height_ratio > 0.3 and randf() < 0.5:
		return { "grade": "silver" }
	else:
		return { "grade": "bronze" }

# 외부에서 특정 위치 블록 제거 (Player에서 호출)
func remove_block_at(world_pos: Vector2):
	var block_size = 60.0
	var col = int(world_pos.x / block_size)
	var row = int(world_pos.y / block_size)
	var key = Vector2i(col, row)
	if wall_blocks.has(key):
		wall_blocks[key].take_dig(999)  # 즉시 파괴 (Player가 dig_power 전달)
		wall_blocks.erase(key)

func dig_block_at(world_pos: Vector2, dig_power: int):
	var block_size = 60.0
	var col = int(world_pos.x / block_size)
	var row = int(world_pos.y / block_size)
	var key = Vector2i(col, row)
	
	print("dig - col:", col, " row:", row, " 존재:", wall_blocks.has(key), " 전체 키 수:", wall_blocks.size())
	
	if not wall_blocks.has(key):
		return
	
	var block = wall_blocks[key]
	print("블록 유효:", is_instance_valid(block))  # 추가
	
	if not is_instance_valid(block):
		wall_blocks.erase(key)
		return
	
	block.take_dig(dig_power)
	if not is_instance_valid(block):
		wall_blocks.erase(key)
