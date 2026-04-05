# StatusPanel.gd
extends CanvasLayer

var is_open: bool = false
var panel: PanelContainer = null
var vbox: VBoxContainer = null
var item_grid: HFlowContainer = null

func _ready():
	process_mode = PROCESS_MODE_ALWAYS # 일시정지 중에도 확인가능, 본인도 입력받기 위함
	layer = 100 # 상단 표시
	
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.1)

	panel = PanelContainer.new()
	# 우측 1/4 폭 앵커 방식 유지
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.anchor_left = 0.75
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.95)
	style.border_width_left = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.2)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_right", 15)
	panel.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(root_vbox)

	# [상단] 스탯 텍스트 (스크롤 없음)
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	# 상단을 덜 차지하고 아이템에 공간을 할애하기위해
	root_vbox.add_child(vbox)
	
	var sep = HSeparator.new()
	root_vbox.add_child(sep)
	
	var item_title = Label.new()
	item_title.text = "보유 아이템"
	item_title.add_theme_font_size_override("font_size", 16)
	item_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(item_title)
	
	# [하단] 아이템 아이콘 그리드
	var item_scroll = ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(item_scroll)
	
	item_grid = HFlowContainer.new()
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 6)
	item_grid.add_theme_constant_override("v_separation", 6)
	item_scroll.add_child(item_grid)

	add_child(panel)
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var shop = null
		if get_tree().current_scene:
			shop = get_tree().current_scene.get_node_or_null("ShopPanel")
		
		# 상점이 열려 있으면 상점이 입력을 가로채므로 일단 리턴 (shop_panel.gd에서 닫기 처리됨)
		if shop and shop.visible:
			return

		if is_open:
			set_open(false)
			get_tree().paused = false
		else:
			set_open(true)
			get_tree().paused = true

func set_open(show: bool):
	is_open = show
	visible = show
	if show:
		_refresh_stats()

func _refresh_stats():
	# 기존 자식 초기화
	for child in vbox.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "Player Stats"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(stats_grid)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p = players[0]
	
	_add_stat(stats_grid, "HP", "%d/%d" % [int(p.current_hp), int(p.max_hp)])
	_add_stat(stats_grid, "회복/초", p.hp_regen)
	_add_stat(stats_grid, "공격력", p.weapon_damage)
	_add_stat(stats_grid, "공속(초)", p.weapon_attack_speed)
	_add_stat(stats_grid, "이동속도", p.move_speed)
	_add_stat(stats_grid, "점프력", abs(int(p.jump_velocity)))
	_add_stat(stats_grid, "채굴력", p.dig_power)
	_add_stat(stats_grid, "채굴속도", p.dig_speed)
	_add_stat(stats_grid, "드롭운", p.luck)
	_add_stat(stats_grid, "낙하피해감소", p.fall_dmg_reduction)
	_add_stat(stats_grid, "기본재화배율", "x%.2f" % ItemManager.get_player_stat("gold_gain_mult", 1.0))
	_add_stat(stats_grid, "로봇처치배율", "x%.2f" % ItemManager.get_player_stat("robot_gold_mult", 1.0))
	_add_stat(stats_grid, "채굴재화배율", "x%.2f" % ItemManager.get_player_stat("mine_gold_mult", 1.0))
	_add_stat(stats_grid, "상점가격배율", "x%.2f" % ItemManager.get_player_stat("kiosk_price_mult", 1.0))
	_add_stat(stats_grid, "스테이지이자", "+%.1f%%" % (p.interest_rate * 100))
	
	_refresh_items()

func _add_stat(parent: Control, stat_name: String, value):
	var hbox = HBoxContainer.new()
	var lbl_name = Label.new()
	lbl_name.text = stat_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 12)
	
	var lbl_val = Label.new()
	if value is float:
		lbl_val.text = "%.1f" % value
	else:
		lbl_val.text = str(value)
	lbl_val.add_theme_font_size_override("font_size", 12)
	lbl_val.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	
	hbox.add_child(lbl_name)
	hbox.add_child(lbl_val)
	parent.add_child(hbox)

func _refresh_items():
	for child in item_grid.get_children():
		child.queue_free()
		
	for item in ItemManager.owned_items:
		var grade = item.get("grade", "D")
		var name_kr = item.get("name_kr", "?")
		
		# 아이콘 대용 프로토타입 박스
		var box = PanelContainer.new()
		box.custom_minimum_size = Vector2(36, 36)
		box.tooltip_text = _build_tooltip(item)
		
		var style = StyleBoxFlat.new()
		style.bg_color = _get_grade_color(grade)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(1,1,1,0.3)
		box.add_theme_stylebox_override("panel", style)
		
		var lbl = Label.new()
		lbl.text = name_kr.substr(0, 1) # 첫글자
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.add_theme_font_size_override("font_size", 13)
		box.add_child(lbl)
		
		item_grid.add_child(box)

func _get_grade_color(grade: String) -> Color:
	var colors = {
		"D": Color(0.45, 0.45, 0.45),
		"C": Color(0.1,  0.55, 0.1 ),
		"B": Color(0.1,  0.3,  0.8 ),
		"A": Color(0.5,  0.1,  0.8 ),
		"S": Color(0.85, 0.6,  0.0 )
	}
	return colors.get(grade, Color(0.4, 0.4, 0.4))

func _build_tooltip(item: Dictionary) -> String:
	var lines: Array = ["[%s] %s" % [item.get("grade", "D"), item.get("name_kr", "?")], ""]
	for eff in item.get("effects", []):
		var lbl  = eff.get("label_kr", eff.get("stat_key", ""))
		var val  = eff.get("value", 0.0)
		var mode = eff.get("mode", "add")
		if mode == "multiply":
			var pct = int(val * 100)
			var sign_str = "+" if pct >= 0 else ""
			lines.append("%s %s%d%%" % [lbl, sign_str, pct])
		else:
			var sign_str = "+" if val >= 0 else ""
			if val == int(val):
				lines.append("%s %s%d" % [lbl, sign_str, int(val)])
			else:
				lines.append("%s %s%.1f" % [lbl, sign_str, val])
	return "\n".join(lines)
