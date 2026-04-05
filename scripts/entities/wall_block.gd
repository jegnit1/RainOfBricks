# WallBlock.gd
extends StaticBody2D

signal block_destroyed(block: Node)

const BLOCK_SIZE: float = 32.0

var max_hp: int = 120
var current_hp: int = 120
var block_color: Color = Color(0.4, 0.4, 0.4)
var block_id: String = "wall_basic"
var treasure_chance: float = 0.1

# 보물상자 관련
var has_treasure: bool = false
var treasure_grade: String = "bronze"  # bronze / silver / gold / diamond

@onready var block_visual: Polygon2D = $BlockVisual
@onready var crack_visual: Polygon2D = $CrackVisual
@onready var crack_lines: Node2D = $CrackLines

func _ready():
	_setup_visuals()

func setup(data: Dictionary, pos: Vector2, treasure_data: Dictionary = {}):
	block_id = data.get("id", "wall_basic")
	max_hp = data.get("hp", 120)
	current_hp = max_hp
	var c = data.get("color", [0.4, 0.4, 0.4])
	block_color = Color(c[0], c[1], c[2])
	treasure_chance = data.get("treasure_chance", 0.1)
	position = pos

	# 보물상자 여부 결정
	if not treasure_data.is_empty():
		has_treasure = true
		treasure_grade = treasure_data.get("grade", "bronze")

	_setup_visuals()
	_update_crack()

func _setup_visuals():
	var half = BLOCK_SIZE / 2.0
	var poly = PackedVector2Array([
		Vector2(-half, -half),
		Vector2( half, -half),
		Vector2( half,  half),
		Vector2(-half,  half)
	])

	block_visual.polygon = poly
	block_visual.color = block_color

	# 균열 비주얼 초기화
	crack_visual.polygon = poly
	crack_visual.color = Color(0, 0, 0, 0)  # 투명
	crack_visual.z_index = 1

	# 보물상자 실루엣 표시
	if has_treasure:
		_show_treasure_silhouette()

func take_dig(dig_power: int):
	current_hp -= dig_power
	print("블록 피격 - hp:", current_hp, "/", max_hp)
	_update_crack()
	if current_hp <= 0:
		_destroy()

func _update_crack():
	var ratio = float(current_hp) / float(max_hp)

	if ratio > 0.8:
		# 균열 없음
		crack_visual.color = Color(0, 0, 0, 0)
	elif ratio > 0.6:
		# 1단계 균열
		_draw_cracks(1, 0.25)
	elif ratio > 0.4:
		# 2단계 균열
		_draw_cracks(2, 0.5)
	elif ratio > 0.2:
		# 3단계 균열
		_draw_cracks(3, 0.75)
	else:
		# 4단계 균열
		_draw_cracks(4, 0.9)

func _draw_cracks(stage: int, alpha: float):
	block_visual.color = Color(
		block_color.r * (1.0 - alpha * 0.25),
		block_color.g * (1.0 - alpha * 0.25),
		block_color.b * (1.0 - alpha * 0.25)
	)
	crack_visual.color = Color(0, 0, 0, alpha * 0.3)

	# 기존 균열선 제거
	for child in crack_lines.get_children():
		child.queue_free()

	var half = BLOCK_SIZE / 2.0

	if stage >= 1:
		# 1단계: 균열선 2개
		_add_crack_line([Vector2(-half + 4, -half + 2), Vector2(2, 4), Vector2(-2, half - 3)], alpha)
		_add_crack_line([Vector2(half - 6, -half + 5), Vector2(-3, 2), Vector2(1, half - 4)], alpha)

	if stage >= 2:
		# 2단계: 추가 균열선 2개
		_add_crack_line([Vector2(-half + 2, 2), Vector2(half - 4, -3)], alpha)
		_add_crack_line([Vector2(-3, -half + 4), Vector2(2, half - 2)], alpha)
		
	if stage >= 3:
		# 3단계: 갈라짐 강조 2개
		_add_crack_line([Vector2(2, 4), Vector2(half - 2, half - 2)], alpha)
		_add_crack_line([Vector2(-3, 2), Vector2(-half + 2, half - 5)], alpha)
		
	if stage >= 4:
		# 4단계: 파괴 직전 균열
		_add_crack_line([Vector2(0, -half + 2), Vector2(0, half - 2)], alpha)
		_add_crack_line([Vector2(-half + 2, 0), Vector2(half - 2, 0)], alpha)
	
func _add_crack_line(points: Array, alpha: float):
	var line = Line2D.new()
	line.points = PackedVector2Array(points)
	line.width = 1.5
	line.default_color = Color(0.05, 0.02, 0.0, alpha)
	line.z_index = 3
	crack_lines.add_child(line)

func _show_treasure_silhouette():
	# 보물상자 등급별 실루엣 색상
	var silhouette_color: Color
	match treasure_grade:
		"bronze":   silhouette_color = Color(0.6, 0.3, 0.1, 0.4)
		"silver":   silhouette_color = Color(0.7, 0.7, 0.7, 0.4)
		"gold":     silhouette_color = Color(0.8, 0.7, 0.0, 0.4)
		"diamond":  silhouette_color = Color(0.3, 0.8, 0.9, 0.4)

	# 보물상자 실루엣 (작은 사각형)
	var sil = Polygon2D.new()
	sil.polygon = PackedVector2Array([
		Vector2(-15, -15),
		Vector2( 15, -15),
		Vector2( 15,  15),
		Vector2(-15,  15)
	])
	sil.color = silhouette_color
	sil.z_index = 2
	add_child(sil)

func _destroy():
	if has_treasure:
		_spawn_treasure()
	block_destroyed.emit(self)
	queue_free()

func _spawn_treasure():
	# 보물상자 드롭 (추후 TreasureChest 씬으로 교체 예정)
	print("보물상자 획득! 등급: ", treasure_grade)
	# TODO: 실제 보물상자 아이템 지급
