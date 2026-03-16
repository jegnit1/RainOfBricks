# Map.gd
extends Node2D

@export var map_width: float = 1880.0   # 전체 맵 너비 확장
@export var map_height: float = 720.0
@export var wall_thickness: float = 300.0  # 벽 두께 대폭 확장
@export var wall_block_scene: PackedScene

const BLOCK_SIZE: float = 30.0

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
	# floor_y를 BLOCK_SIZE 배수로 정렬
	var raw_floor_y = map_height - 40.0
	floor_y = int(raw_floor_y / BLOCK_SIZE) * BLOCK_SIZE  # 660.0
	
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
	floor_body.position = Vector2(map_width / 2.0, floor_y + 20.0)

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
	# 바닥 위까지만 블록 생성
	var rows = ceili(floor_y / BLOCK_SIZE)  # map_height 대신 floor_y 사용
	print("floor_y:", floor_y, " rows:", rows)
	print("wall_left_x:", wall_left_x, " wall_right_x:", wall_right_x)
	print("left_cols:", int(wall_thickness / BLOCK_SIZE))
	print("right_start_col:", int(wall_right_x / BLOCK_SIZE), " right_end_col:", int(map_width / BLOCK_SIZE))
	var left_cols = int(wall_thickness / BLOCK_SIZE)
	var right_start_col = int(wall_right_x / BLOCK_SIZE)
	var right_end_col = int(map_width / BLOCK_SIZE)

	for col in range(left_cols):
		for row in range(rows):
			_place_block(col, row)

	for col in range(right_start_col, right_end_col):
		for row in range(rows):
			_place_block(col, row)

func _place_block(col: int, row: int):
	var block_bottom = (row + 1) * BLOCK_SIZE
	if block_bottom > floor_y:
		return

	var block = wall_block_scene.instantiate()
	add_child(block)

	var height_ratio = 1.0 - (float(row) / (map_height / BLOCK_SIZE))
	var treasure_data = _roll_treasure(height_ratio)
	var data = wall_block_data[0]

	# 블록 위치: col/row × BLOCK_SIZE
	var pos = Vector2(
		col * BLOCK_SIZE + BLOCK_SIZE / 2.0,
		row * BLOCK_SIZE + BLOCK_SIZE / 2.0
	)
	block.setup(data, pos, treasure_data)

	var key = Vector2i(col, row)
	wall_blocks[key] = block

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
	var block_size = 30.0
	var col = int(world_pos.x / block_size)
	var row = int(world_pos.y / block_size)
	var key = Vector2i(col, row)
	if wall_blocks.has(key):
		wall_blocks[key].take_dig(999)  # 즉시 파괴 (Player가 dig_power 전달)
		wall_blocks.erase(key)

func dig_block_at(world_pos: Vector2, dig_power: int):
	var col = int(world_pos.x / BLOCK_SIZE)
	var row = int(world_pos.y / BLOCK_SIZE)
	var key = Vector2i(col, row)

	if not wall_blocks.has(key):
		return
	var block = wall_blocks[key]
	if not is_instance_valid(block):
		wall_blocks.erase(key)
		return
	block.take_dig(dig_power)
	if not is_instance_valid(block):
		wall_blocks.erase(key)
