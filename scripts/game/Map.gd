# Map.gd
extends Node2D

@export var map_width: float = 1880.0   # 전체 맵 너비 확장
@export var map_height: float = 720.0
@export var wall_thickness: float = 300.0  # 벽 두께 대폭 확장
@export var wall_block_scene: PackedScene
@export var treasure_scene: PackedScene
@export var max_treasures_per_side: int = 6  # 한쪽 벽 최대 보물상자 수

const BLOCK_SIZE: float = 32.0

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
	shape.size = Vector2(map_width, 1000.0)
	$Floor/CollisionShape2D.shape = shape
	$Floor/CollisionShape2D.position = Vector2(0, 480) # 중심점 보정

	var poly = $Floor/Polygon2D
	poly.polygon = _make_rect_polygon(map_width, 1000.0)
	poly.position = Vector2(0, 480)
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
		# sqlite_utils export: flat array / 기존 수기 형식: {"blocks": [...]}
		if data is Array:
			wall_block_data = data
		elif data is Dictionary:
			wall_block_data = data.get("blocks", [])

func _generate_wall_blocks():
	var rows = ceili(floor_y / BLOCK_SIZE)
	var left_cols = int(wall_thickness / BLOCK_SIZE)
	var right_start_col = int(wall_right_x / BLOCK_SIZE)
	var right_end_col = int(map_width / BLOCK_SIZE)

	# 왼쪽 벽 보물상자 위치 미리 결정
	var left_treasure_positions = _pick_treasure_positions(
		0, left_cols, 0, rows
	)
	# 오른쪽 벽 보물상자 위치 미리 결정
	var right_treasure_positions = _pick_treasure_positions(
		right_start_col, right_end_col, 0, rows
	)

	for col in range(left_cols):
		for row in range(rows):
			var block_bottom = (row + 1) * BLOCK_SIZE
			if block_bottom > floor_y:
				continue
			var key = Vector2i(col, row)
			var has_treasure = left_treasure_positions.has(key)
			var grade = left_treasure_positions.get(key, "")
			_place_block(col, row, has_treasure, grade)

	for col in range(right_start_col, right_end_col):
		for row in range(rows):
			var block_bottom = (row + 1) * BLOCK_SIZE
			if block_bottom > floor_y:
				continue
			var key = Vector2i(col, row)
			var has_treasure = right_treasure_positions.has(key)
			var grade = right_treasure_positions.get(key, "")
			_place_block(col, row, has_treasure, grade)

func _place_block(col: int, row: int, has_treasure: bool = false, treasure_grade: String = ""):
	var block = wall_block_scene.instantiate()
	add_child(block)

	var data = wall_block_data[0].duplicate()
	# 스테이지 볼록 HP 배율 적용
	var hp_mult: float = StageManager.current_stage_data.get("brick_hp_mult", 1.0)
	data["hp"] = int(data.get("hp", 120) * hp_mult)
	
	var pos = Vector2(
		col * BLOCK_SIZE + BLOCK_SIZE / 2.0,
		row * BLOCK_SIZE + BLOCK_SIZE / 2.0
	)

	var treasure_data = {}
	if has_treasure:
		treasure_data = { "grade": treasure_grade }

	block.setup(data, pos, treasure_data)

	var key = Vector2i(col, row)
	wall_blocks[key] = block

	var captured_key = key
	var captured_grade = treasure_grade
	var captured_has_treasure = has_treasure
	var captured_pos = pos

	block.block_destroyed.connect(func(b):
		wall_blocks.erase(captured_key)
		# 보물상자 드랍
		if captured_has_treasure and treasure_scene != null:
			var chest = treasure_scene.instantiate()
			get_parent().add_child(chest)
			chest.setup(captured_grade, captured_pos)
	)
	
func regenerate_walls():
	# 기존 블록 전부 제거
	for block in wall_blocks.values():
		if is_instance_valid(block):
			block.queue_free()
	wall_blocks.clear()
	
	# 블록 재생성
	_generate_wall_blocks()

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
	var block_size = 32.0
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
		
func dig_blocks_in_radius(world_pos: Vector2, radius: float, dig_power: int):
	var min_col = int((world_pos.x - radius) / BLOCK_SIZE)
	var max_col = int((world_pos.x + radius) / BLOCK_SIZE)
	var min_row = int((world_pos.y - radius) / BLOCK_SIZE)
	var max_row = int((world_pos.y + radius) / BLOCK_SIZE)
	
	var to_damage = []
	for col in range(min_col, max_col + 1):
		for row in range(min_row, max_row + 1):
			var key = Vector2i(col, row)
			if not wall_blocks.has(key):
				continue
				
			# 원형 범위 내에 있는지 중심 좌표로 확인
			var block_pos = Vector2(col * BLOCK_SIZE + BLOCK_SIZE / 2.0, row * BLOCK_SIZE + BLOCK_SIZE / 2.0)
			if block_pos.distance_to(world_pos) <= radius:
				if is_exposed(col, row):
					to_damage.append(wall_blocks[key])
					
	for block in to_damage:
		if is_instance_valid(block):
			block.take_dig(dig_power)

func is_exposed(col: int, row: int) -> bool:
	if not wall_blocks.has(Vector2i(col, row - 1)): return true
	if not wall_blocks.has(Vector2i(col - 1, row)): return true
	if not wall_blocks.has(Vector2i(col + 1, row)): return true
	
	var bottom_y = (row + 1) * BLOCK_SIZE
	if bottom_y < floor_y and not wall_blocks.has(Vector2i(col, row + 1)):
		return true
		
	return false
		
func _pick_treasure_positions(col_start: int, col_end: int, row_start: int, row_end: int) -> Dictionary:
	var result = Dictionary()
	var total_rows = row_end - row_start
	var total_cols = col_end - col_start

	# 전체 후보 위치 생성
	var candidates = []
	for col in range(col_start, col_end):
		for row in range(row_start, row_end):
			var block_bottom = (row + 1) * BLOCK_SIZE
			if block_bottom <= floor_y:
				candidates.append(Vector2i(col, row))

	# 랜덤 셔플 후 max_treasures_per_side개 선택
	candidates.shuffle()
	var count = min(max_treasures_per_side, candidates.size())

	for i in range(count):
		var pos = candidates[i]
		# 높이 비율로 등급 결정
		var height_ratio = 1.0 - (float(pos.y) / float(total_rows))
		result[pos] = _determine_grade(height_ratio)

	return result
	
func _determine_grade(height_ratio: float) -> String:
	if height_ratio > 0.8:
		return "diamond"
	elif height_ratio > 0.6:
		return "gold"
	elif height_ratio > 0.3:
		return "silver"
	else:
		return "bronze"
