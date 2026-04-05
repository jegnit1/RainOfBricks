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
	var player = get_node_or_null("/root/GameScene/Player")
	var init_max_hp = player.max_hp if player else 100.0
	hp_bar.max_value = init_max_hp
	hp_bar.value = init_max_hp
	hp_bar.modulate = Color(0, 0.8, 0)
	oxygen_bar.max_value = 100
	oxygen_bar.value = 100

	ItemManager.item_added.connect(_on_item_added)
	
func update_hp(current: float, max_hp: float):
	hp_bar.max_value = max_hp
	hp_bar.value = current
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


func _on_item_added(item_data: Dictionary) -> void:
	if item_slots_row.get_child_count() >= MAX_ITEM_SLOTS:
		return
	var slot = _create_item_slot(item_data)
	item_slots_row.add_child(slot)

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
		if mode == "multiply":
			parts.append("%s %+d%%" % [lbl, int(val * 100)])
		else:
			parts.append("%s %+.1f" % [lbl, val])
	return "\n".join(parts) if not parts.is_empty() else "효과 없음"

func _on_restart_button_pressed() -> void:
	# 아이템 슬롯 초기화
	for child in item_slots_row.get_children():
		child.queue_free()
	GameManager.reset()
	get_tree().reload_current_scene()
