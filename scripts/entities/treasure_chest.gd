# TreasureChest.gd
extends Area2D

var grade: String = "bronze"
var poly: Polygon2D

func _ready():
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func setup(chest_grade: String, pos: Vector2):
	grade = chest_grade
	position = pos

func _setup_visuals():
	poly = Polygon2D.new()
	var half = 12.0
	poly.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2( half, -half),
		Vector2( half,  half),
		Vector2(-half,  half)
	])
	poly.color = _get_grade_color()
	poly.z_index = 5
	add_child(poly)

	# 반짝이는 테두리 효과
	var border = Line2D.new()
	var half_b = 12.0
	border.points = PackedVector2Array([
		Vector2(-half_b, -half_b),
		Vector2( half_b, -half_b),
		Vector2( half_b,  half_b),
		Vector2(-half_b,  half_b),
		Vector2(-half_b, -half_b),
	])
	border.width = 2.0
	border.default_color = Color(1, 1, 1, 0.8)
	border.z_index = 6
	add_child(border)

func _get_grade_color() -> Color:
	match grade:
		"bronze":  return Color(0.7, 0.4, 0.1, 1.0)
		"silver":  return Color(0.75, 0.75, 0.75, 1.0)
		"gold":    return Color(0.9, 0.8, 0.0, 1.0)
		"diamond": return Color(0.4, 0.9, 1.0, 1.0)
	return Color(0.7, 0.4, 0.1, 1.0)

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		_grant_reward()
		queue_free()

func _grant_reward():
	# 등급별 재화 보상
	var rewards = {
		"bronze":  20,
		"silver":  50,
		"gold":    120,
		"diamond": 300
	}
	var amount = rewards.get(grade, 20)
	GameManager.add_currency(amount)

	# 아이템 드롭 판정
	var players = get_tree().get_nodes_in_group("player")
	var luck = players[0].luck if not players.is_empty() else 0
	var drop = ItemManager.roll_drop("TREASURE", luck)
	if not drop.is_empty():
		ItemManager.add_item(drop)
