# Key.gd
extends Area2D

signal key_collected

func _ready():
	body_entered.connect(_on_body_entered)
	_setup_visuals()
	# 위아래 둥둥 뜨는 애니메이션
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position",
		position + Vector2(0, -10), 0.6
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position",
		position + Vector2(0, 10), 0.6
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _setup_visuals():
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-10, -10),
		Vector2( 10, -10),
		Vector2( 10,  10),
		Vector2(-10,  10)
	])
	poly.color = Color(1.0, 0.9, 0.0, 1.0)  # 노란색
	poly.z_index = 10
	add_child(poly)

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		key_collected.emit()
		queue_free()
