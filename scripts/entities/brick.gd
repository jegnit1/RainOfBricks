# Brick.gd
extends RigidBody2D

@export var hp: int = 30
@export var weight: float = 10.0
@export var currency_value: int = 5
@export var exp_value: int = 10  # 벽돌 파괴 시 경험치

var is_grounded: bool = false
var was_hit_in_air: bool = false

func _ready():
	# 바닥 착지 감지
	body_entered.connect(_on_body_entered)
	 # Polygon2D 자동 생성
	var poly = $Polygon2D
	poly.polygon = PackedVector2Array([
		Vector2(-30, -30),
		Vector2( 30, -30),
		Vector2( 30,  30),
		Vector2(-30,  30)
	])
	poly.color = Color(0.9, 0.5, 0.1)  # 주황색

func _on_body_entered(body: Node):
	if is_grounded:
		return
	# 바닥이나 다른 벽돌 위에 착지한 경우
	if body.is_in_group("ground") or body.is_in_group("brick"):
		is_grounded = true
		GameManager.add_weight(weight)

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		_destroy()

func _destroy():
	# 재화 지급 (공중이면 2배)
	var reward = currency_value * 2 if not is_grounded else currency_value
	GameManager.add_currency(reward)
	GameManager.add_exp(exp_value)
	
	# 착지한 벽돌이 파괴되면 무게 제거
	if is_grounded:
		GameManager.remove_weight(weight)
	
	queue_free()
