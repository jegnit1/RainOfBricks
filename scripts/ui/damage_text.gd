# DamageText.gd
extends Node2D

var amount: int = 0
var is_critical: bool = false

func _ready():
	# z_index를 높여서 다른 요소들 위에 보이도록 설정
	z_index = 100
	
	var label = Label.new()
	label.text = str(amount)
	
	# 기본: 하얀 글자에 검은 테두리. 크리티컬일 경우 다른 느낌을 주도록 준비
	if is_critical:
		label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # 빨간색
		label.add_theme_font_size_override("font_size", 24)
	else:
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		label.add_theme_font_size_override("font_size", 18)
		
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	
	# 중앙 정렬
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# 마우스 중심 등 살짝 어긋난 좌표 보정용 (원한다면)
	label.position = Vector2(-20, -10)
	
	add_child(label)
	
	# 애니메이션: 떠오르면서 사라짐
	var tween = create_tween()
	# 위치 이동: 위로 50픽셀 떠오름, 0.6초간
	var target_pos = position + Vector2(randf_range(-15, 15), -50)
	tween.tween_property(self, "position", target_pos, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 페이드 아웃: modulate 투명도를 병렬로 조절
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.8).set_ease(Tween.EASE_IN).set_delay(0.2)
	
	tween.tween_callback(queue_free)
