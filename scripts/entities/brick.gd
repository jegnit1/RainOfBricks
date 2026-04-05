# Brick.gd
extends RigidBody2D

@export var hp: int = 30
@export var weight: float = 5.0
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
	
	# 데미지 텍스트 생성
	var dmg_script = preload("res://scripts/ui/damage_text.gd")
	var dmg_node = Node2D.new()
	dmg_node.set_script(dmg_script)
	dmg_node.amount = amount
	dmg_node.is_critical = false
	dmg_node.global_position = global_position
	var scene = get_tree().current_scene
	if scene: scene.add_child(dmg_node)
	
	if hp <= 0:
		_destroy()

func _destroy():
	# 주변 벽돌 sleeping 해제
	var bodies = get_colliding_bodies()
	for body in bodies:
		if body is RigidBody2D:
			body.sleeping = false
			
	# 재화 지급 (공중이면 2배)
	var reward = currency_value * 2 if not is_grounded else currency_value
	GameManager.add_currency(reward)
	GameManager.add_exp(exp_value)
	
	# 착지한 벽돌이 파괴되면 무게 제거
	if is_grounded:
		GameManager.remove_weight(weight)
	
	queue_free()
