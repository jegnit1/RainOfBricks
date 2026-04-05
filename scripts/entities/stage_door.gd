# StageDoor.gd
extends Area2D

signal door_entered

var player_inside: bool = false

func _ready():
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true)
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false)
	_setup_visuals()

func _process(_delta):
	if player_inside and Input.is_action_just_pressed("action"):
		door_entered.emit()

func _setup_visuals():
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-20, -40), Vector2(20, -40),
		Vector2(20,  40),  Vector2(-20, 40)
	])
	poly.color = Color(0.1, 0.8, 0.2)
	poly.z_index = 5
	add_child(poly)

	var label = Label.new()
	label.text = "NEXT"
	label.position = Vector2(-16, -60)
	label.z_index = 6
	add_child(label)
