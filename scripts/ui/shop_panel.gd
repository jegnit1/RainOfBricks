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

# ── 초기화 ───────────────────────────────────────
func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	GameManager.currency_changed.connect(_refresh_currency_label)

# ── 외부 호출: 상점 열기 ─────────────────────────
func open_shop() -> void:
	_shop_items = _pick_shop_items(4)
	_build_item_cards()
	_refresh_currency_label(GameManager.currency)
	visible = true
	get_tree().paused = true

# ── 상점 닫기 ────────────────────────────────────
func _on_close_pressed() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if visible and event.is_action_just_pressed("action"):
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

# ── UI 갱신 헬퍼 ──────────────────────────────────
func _refresh_currency_label(_amount: int = -1) -> void:
	currency_label.text = "💰 %d" % GameManager.currency

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
