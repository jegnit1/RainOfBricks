# ShopPanel.gd
extends CanvasLayer

# ── 등급별 기본 가격 ──────────────────────────────
const GRADE_BASE_PRICE: Dictionary = {
	"D": 50, "C": 120, "B": 280, "A": 500, "S": 1000
}

# 등급별 색상 (배경 카드)
const GRADE_COLOR: Dictionary = {
	"D": Color(0.45, 0.45, 0.45),
	"C": Color(0.1,  0.55, 0.1 ),
	"B": Color(0.1,  0.3,  0.8 ),
	"A": Color(0.5,  0.1,  0.8 ),
	"S": Color(0.85, 0.6,  0.0 ),
}

# ── 노드 참조 ────────────────────────────────────
@onready var item_list:       HBoxContainer = $UIRoot/PanelContainer/VBox/Scroll/ItemList
@onready var currency_label:  Label         = $UIRoot/PanelContainer/VBox/TopBar/CurrencyLabel
@onready var close_button:    Button        = $UIRoot/PanelContainer/VBox/CloseButton

# ── 내부 상태 ────────────────────────────────────
var _shop_items: Array = []       # 현재 진열 아이템
var _reroll_count: int = 0
var reroll_button: Button = null

var status_panel_instance: Node = null
@onready var root_panel: PanelContainer = $UIRoot/PanelContainer
@onready var top_bar: HBoxContainer = $UIRoot/PanelContainer/VBox/TopBar

# ── 초기화 ───────────────────────────────────────
func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	GameManager.currency_changed.connect(_refresh_currency_label)
	
	# 상점 UI를 중앙에서 화면 좌측으로 살짝 이동시키며 width를 920 픽셀로 구성하여 겹침 방지 (해상도 1280 기준 우측 320px 공간 확보)
	root_panel.offset_left = -600
	root_panel.offset_right = 320
	
	reroll_button = Button.new()
	reroll_button.text = "새로고침 (💰 10)"
	reroll_button.pressed.connect(_on_reroll_pressed)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.35, 0.6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	reroll_button.add_theme_stylebox_override("normal", sb)
	top_bar.add_child(reroll_button)
	top_bar.move_child(reroll_button, 1)
	
	var sp_script = preload("res://scripts/ui/status_panel.gd")
	status_panel_instance = CanvasLayer.new()
	status_panel_instance.set_script(sp_script)
	add_child(status_panel_instance)

# ── 외부 호출: 상점 열기 ─────────────────────────
func open_shop() -> void:
	if _shop_items.is_empty():
		_shop_items = _pick_shop_items(4)
	_build_item_cards()
	_refresh_currency_label(GameManager.currency)
	status_panel_instance.set_open(true)
	visible = true
	get_tree().paused = true

func reset_shop() -> void:
	_shop_items.clear()
	_reroll_count = 0

func get_reroll_cost() -> int:
	return int(10 * pow(2, _reroll_count))

func _on_reroll_pressed() -> void:
	var cost = get_reroll_cost()
	if GameManager.currency >= cost:
		GameManager.currency -= cost
		GameManager.currency_changed.emit(GameManager.currency)
		_reroll_count += 1
		_shop_items = _pick_shop_items(4)
		_build_item_cards()
		_refresh_currency_label(GameManager.currency)

# ── 상점 닫기 ────────────────────────────────────
func _on_close_pressed() -> void:
	status_panel_instance.set_open(false)
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("action") and not event.is_echo():
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ── 아이템 선택 — ItemManager DB 위임 ──────────────
func _pick_shop_items(n: int) -> Array:
	return ItemManager.get_shop_items(n)

# ── 카드 UI 동적 생성 ─────────────────────────────
func _build_item_cards() -> void:
	# 기존 카드 제거
	for child in item_list.get_children():
		child.queue_free()

	for item in _shop_items:
		var card = _create_card(item)
		item_list.add_child(card)

func _create_card(item: Dictionary) -> Control:
	var grade  = item.get("grade", "D")
	var price  = _calc_price(item)

	# 카드 컨테이너
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 280)

	# 배경 색
	var style = StyleBoxFlat.new()
	style.bg_color      = GRADE_COLOR.get(grade, Color(0.4, 0.4, 0.4))
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# 등급 배지
	var grade_lbl = Label.new()
	grade_lbl.text                 = "[ %s ]" % grade
	grade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_lbl.add_theme_font_size_override("font_size", 14)
	grade_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	vbox.add_child(grade_lbl)

	# 아이템 이름
	var name_lbl = Label.new()
	name_lbl.text                 = item.get("name_kr", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	# 효과 텍스트
	var effect_text = _build_effect_text(item)
	var eff_lbl = Label.new()
	eff_lbl.text                 = effect_text
	eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eff_lbl.add_theme_font_size_override("font_size", 13)
	eff_lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.85))
	eff_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(eff_lbl)

	# 간격 채우기
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 가격 표시
	var price_lbl = Label.new()
	price_lbl.text                 = "💰 %d" % price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	vbox.add_child(price_lbl)

	# 구매 버튼
	var btn = Button.new()
	btn.text = "구매"
	btn.add_theme_font_size_override("font_size", 15)
	var can_buy = GameManager.currency >= price
	btn.disabled = not can_buy
	vbox.add_child(btn)

	# 캡처 변수 (클로저 바인딩)
	var captured_item  = item
	var captured_card  = card
	var captured_price = price
	btn.pressed.connect(func():
		_on_buy_pressed(captured_item, captured_price, captured_card)
	)

	return card

# ── 효과 텍스트 생성 ──────────────────────────────
func _build_effect_text(item: Dictionary) -> String:
	var lines: Array = []
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

# ── 가격 계산 (kiosk_price_mult 반영) ────────────
func _calc_price(item: Dictionary) -> int:
	var base = GRADE_BASE_PRICE.get(item.get("grade", "D"), 50)
	var mult = ItemManager.get_player_stat("kiosk_price_mult", 1.0)
	return max(1, int(base * mult))

# ── 구매 처리 ─────────────────────────────────────
func _on_buy_pressed(item: Dictionary, price: int, card: Control) -> void:
	if GameManager.currency < price:
		return
	GameManager.currency -= price
	GameManager.currency_changed.emit(GameManager.currency)

	# ItemManager가 효과 적용 + owned_items 추가 + item_added 시그널 발신
	ItemManager.add_item(item)

	# 카드 제거 및 목록 갱신
	_shop_items.erase(item)
	card.queue_free()
	_refresh_currency_label(GameManager.currency)
	_refresh_buy_buttons()
	
	# 즉시 스탯창을 갱신 (상시 반영)
	if status_panel_instance and status_panel_instance.is_open:
		status_panel_instance._refresh_stats()

# ── UI 갱신 헬퍼 ──────────────────────────────────
func _refresh_currency_label(_amount: int = -1) -> void:
	currency_label.text = "💰 %d" % GameManager.currency
	if reroll_button:
		var cost = get_reroll_cost()
		reroll_button.text = "새로고침 (💰 %d)" % cost
		reroll_button.disabled = (GameManager.currency < cost)

func _refresh_buy_buttons() -> void:
	for card in item_list.get_children():
		# 카드 VBox > ... > Button (마지막 자식)
		var vbox = card.get_child(0) if card.get_child_count() > 0 else null
		if vbox == null:
			continue
		var btn = vbox.get_child(vbox.get_child_count() - 1)
		if btn is Button:
			var price_lbl = vbox.get_child(vbox.get_child_count() - 2)
			if price_lbl is Label:
				var price_text = price_lbl.text.replace("💰 ", "")
				var price = int(price_text)
				btn.disabled = GameManager.currency < price
