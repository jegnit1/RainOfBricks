# HUD.gd
extends CanvasLayer

@onready var weight_bar:     ProgressBar  = $UIRoot/WeightBar
@onready var weight_label:   Label        = $UIRoot/WeightLabel
@onready var currency_label: Label        = $UIRoot/CurrencyLabel
@onready var game_over_panel: Panel       = $UIRoot/GameOverPanel
@onready var warning_label:  Label        = $UIRoot/WarningLabel
@onready var exp_bar:        ProgressBar  = $UIRoot/ExpBar
@onready var exp_label:      Label        = $UIRoot/ExpLabel
@onready var hp_bar:         ProgressBar  = $UIRoot/HPBar
@onready var oxygen_bar:     ProgressBar  = $UIRoot/OxygenBar
@onready var item_slots_row: HBoxContainer = $UIRoot/ItemSlotsRow

# 등급별 슬롯 색상
const SLOT_GRADE_COLOR: Dictionary = {
	"D": Color(0.45, 0.45, 0.45),
	"C": Color(0.1,  0.55, 0.1 ),
	"B": Color(0.1,  0.3,  0.8 ),
	"A": Color(0.5,  0.1,  0.8 ),
	"S": Color(0.85, 0.6,  0.0 ),
}
const MAX_ITEM_SLOTS: int = 8

var _weapon_slot_panel: PanelContainer = null

func _ready():
	GameManager.weight_changed.connect(_on_weight_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)

	game_over_panel.visible = false
	warning_label.visible = false
	_update_weight(0.0, GameManager.MAX_WEIGHT)
	_on_currency_changed(0)

	GameManager.exp_changed.connect(_on_exp_changed)
	exp_bar.value = 0
	# 경험치 바를 하단 얇은 게이지로 변신
	exp_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	exp_bar.custom_minimum_size.y = 6
	exp_bar.offset_top = -6
	exp_bar.offset_bottom = 0
	exp_bar.show_percentage = false
	var exp_sb = StyleBoxFlat.new()
	exp_sb.bg_color = Color(0.4, 0.8, 1.0) # Light blue
	exp_bar.add_theme_stylebox_override("fill", exp_sb)
	exp_label.visible = false # 기존 숫자 텍스트 숨김
	
	var player = get_node_or_null("/root/GameScene/Player")
	var init_max_hp = player.max_hp if player else 100.0
	hp_bar.max_value = init_max_hp
	hp_bar.value = init_max_hp
	hp_bar.modulate = Color(0, 0.8, 0)
	hp_bar.show_percentage = false
	
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	hp_label.text = "%d / %d" % [init_max_hp, init_max_hp]
	hp_bar.add_child(hp_label)
	
	oxygen_bar.max_value = 100
	oxygen_bar.value = 100

	ItemManager.item_added.connect(_on_item_added)
	_setup_weapon_slot()
	
func update_hp(current: float, max_hp: float):
	hp_bar.max_value = max_hp
	hp_bar.value = current
	
	var hp_label = hp_bar.get_node_or_null("HPLabel")
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(max_hp)]
		
	var ratio = current / max_hp
	if ratio <= 0.3:
		hp_bar.modulate = Color(1, 0, 0)
	elif ratio <= 0.6:
		hp_bar.modulate = Color(1, 0.6, 0)
	else:
		hp_bar.modulate = Color(0, 0.8, 0)
	
func _on_exp_changed(current: int, required: int, level: int):
	exp_bar.max_value = required if required != -1 else exp_bar.max_value
	exp_bar.value = current
	exp_label.text = "Lv.%d  %d / %d" % [level, current, required]

func _on_weight_changed(current: float, max_weight: float):
	_update_weight(current, max_weight)

func _update_weight(current: float, max_weight: float):
	weight_bar.max_value = max_weight
	weight_bar.value = current
	weight_label.text = "%d / %d" % [current, max_weight]

	var ratio = current / max_weight
	if ratio >= 0.9:
		weight_bar.modulate = Color(1, 0, 0)
	elif ratio >= 0.8:
		weight_bar.modulate = Color(1, 0.6, 0)
	else:
		weight_bar.modulate = Color(0, 0.8, 0)

func _on_weight_stage_changed(stage: String):
	match stage:
		"normal":
			warning_label.visible = false
		"warning":
			warning_label.text = "⚠ WARNING"
			warning_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
			warning_label.visible = true
		"danger":
			warning_label.text = "⚠ DANGER"
			warning_label.add_theme_color_override("font_color", Color(1, 0, 0))
			warning_label.visible = true
			
func update_oxygen(current: float, max_oxygen: float):
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = current
	var ratio = current / max_oxygen
	if ratio <= 0.3:
		oxygen_bar.modulate = Color(1, 0, 0)
	else:
		oxygen_bar.modulate = Color(0.3, 0.8, 1.0)

func _on_game_over():
	game_over_panel.visible = true

func _on_currency_changed(amount: int):
	currency_label.text = "💰 %d" % amount


func _setup_weapon_slot() -> void:
	var row = HBoxContainer.new()
	row.name = "WeaponSlotRow"

	var icon_lbl = Label.new()
	icon_lbl.text = "⚔ "
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)

	_weapon_slot_panel = PanelContainer.new()
	_weapon_slot_panel.custom_minimum_size = Vector2(36, 36)
	_weapon_slot_panel.tooltip_text = "장착된 무기 없음"
	_apply_weapon_slot_style(Color(0.2, 0.2, 0.2), Color(0.5, 0.5, 0.5, 0.6))
	row.add_child(_weapon_slot_panel)

	var slot_lbl = Label.new()
	slot_lbl.name = "WeaponSlotLabel"
	slot_lbl.text = "-"
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size", 14)
	slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	slot_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_slot_panel.add_child(slot_lbl)

	# ItemSlotsRow 앞에 삽입
	var parent = item_slots_row.get_parent()
	parent.add_child(row)
	parent.move_child(row, item_slots_row.get_index())

func _apply_weapon_slot_style(bg: Color, border: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color     = bg
	style.border_color = border
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	_weapon_slot_panel.add_theme_stylebox_override("panel", style)

func _on_item_added(item_data: Dictionary) -> void:
	_show_item_toast(item_data)
	if item_data.get("item_type", "relic") == "equipment":
		_update_weapon_slot(item_data)
		return
	if item_slots_row.get_child_count() >= MAX_ITEM_SLOTS:
		return
	var slot = _create_item_slot(item_data)
	item_slots_row.add_child(slot)

func _update_weapon_slot(item_data: Dictionary) -> void:
	if _weapon_slot_panel == null:
		return
	var grade   = item_data.get("grade", "D")
	var name_kr = item_data.get("name_kr", "?")
	_apply_weapon_slot_style(
		SLOT_GRADE_COLOR.get(grade, Color(0.4, 0.4, 0.4)),
		Color(1, 1, 1, 0.5)
	)
	var lbl = _weapon_slot_panel.get_node_or_null("WeaponSlotLabel")
	if lbl:
		lbl.text = name_kr.substr(0, 1)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_weapon_slot_panel.tooltip_text = "%s [%s]\n%s" % [
		name_kr, grade, _slot_effect_summary(item_data)
	]
	
func _show_item_toast(item_data: Dictionary) -> void:
	var name_kr = item_data.get("name_kr", "?")
	var grade = item_data.get("grade", "D")
	
	var toast = Label.new()
	toast.text = "[ %s ]을(를) 획득했습니다." % name_kr
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(1, 1, 1))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	# 등급 색상 경계선 추가
	style.border_width_left = 3
	style.border_color = SLOT_GRADE_COLOR.get(grade, Color(0.4, 0.4, 0.4))
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	toast.add_theme_stylebox_override("normal", style)
	
	add_child(toast)
	
	# 대략적인 가운데 아래, 혹은 우측 하단에서 나타남
	var viewport_size = get_viewport().get_visible_rect().size
	# 우측 하단 시작
	var start_pos = Vector2(viewport_size.x - 300, viewport_size.y)
	var end_pos = Vector2(viewport_size.x - 300, viewport_size.y - 120)
	
	toast.global_position = start_pos
	
	var tween = create_tween()
	tween.tween_property(toast, "global_position:y", end_pos.y, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)

func _create_item_slot(item_data: Dictionary) -> Control:
	var grade = item_data.get("grade", "D")
	var name_kr = item_data.get("name_kr", "?")

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(36, 36)
	panel.tooltip_text = "%s [%s]\n%s" % [
		name_kr, grade,
		_slot_effect_summary(item_data)
	]

	var style = StyleBoxFlat.new()
	style.bg_color = SLOT_GRADE_COLOR.get(grade, Color(0.4, 0.4, 0.4))
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.4)
	panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	# 이름 첫 글자(한글 포함)를 슬롯 아이콘 대용으로 표시
	lbl.text = name_kr.substr(0, 1) if name_kr.length() > 0 else "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)

	return panel

func _slot_effect_summary(item_data: Dictionary) -> String:
	var parts: Array = []
	for eff in item_data.get("effects", []):
		var lbl  = eff.get("label_kr", eff.get("stat_key", ""))
		var val  = eff.get("value", 0.0)
		var mode = eff.get("mode", "add")
		match mode:
			"set":
				parts.append("%s: %.0f" % [lbl, val])
			"multiply":
				parts.append("%s %+d%%" % [lbl, int(val * 100)])
			_:
				parts.append("%s %+.1f" % [lbl, val])
	return "\n".join(parts) if not parts.is_empty() else "효과 없음"

func _on_restart_button_pressed() -> void:
	# 아이템 슬롯 초기화
	for child in item_slots_row.get_children():
		child.queue_free()
	GameManager.reset()
	get_tree().reload_current_scene()
