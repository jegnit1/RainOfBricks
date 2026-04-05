# Kiosk.gd
extends Area2D

var player_inside: bool = false

func _ready():
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true)
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false)
	_setup_visuals()

func _process(_delta):
	if player_inside and Input.is_action_just_pressed("action"):
		_open_shop()

func _setup_visuals():
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-20, -30), Vector2(20, -30),
		Vector2(20,  30),  Vector2(-20, 30)
	])
	poly.color = Color(0.1, 0.7, 0.7)
	poly.z_index = 5
	add_child(poly)

	# 라벨
	var label = Label.new()
	label.text = "SHOP"
	label.position = Vector2(-16, -50)
	label.z_index = 6
	add_child(label)

func _open_shop():
	var shop = get_node_or_null("/root/GameScene/ShopPanel")
	if shop == null:
		return
	shop.open_shop()
