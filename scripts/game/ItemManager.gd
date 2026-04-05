# ItemManager.gd  — Autoload 싱글톤
# 아이템 DB 로드 / 보유 목록 / 드롭 판정 / 효과 적용 통합 관리
extends Node

# ── 시그널 ────────────────────────────────────────
signal item_added(item_data: Dictionary)

# ── 내부 데이터 ───────────────────────────────────
var _item_db:    Array      = []   # 전체 아이템 배열 (items.json)
var owned_items: Array      = []   # 이번 런에서 획득한 아이템 목록

# ── 등급 드롭 가중치 기본값 ───────────────────────
const GRADE_BASE_WEIGHT: Dictionary = {
	"D": 60, "C": 25, "B": 10, "A": 4, "S": 1
}

# ── 초기화 ───────────────────────────────────────
func _ready() -> void:
	_load_item_db()

func _load_item_db() -> void:
	var file = FileAccess.open("res://items.json", FileAccess.READ)
	if not file:
		push_warning("ItemManager: items.json 로드 실패")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_item_db = parsed
		print("ItemManager: 아이템 로드 완료 - ", _item_db.size(), "개")
	else:
		print("ItemManager: 파싱 실패 - ", typeof(parsed))

# ── DB 조회 ──────────────────────────────────────
func get_item_by_id(id: String) -> Dictionary:
	for item in _item_db:
		if item.get("id", "") == id:
			return item
	return {}

## 특정 소스(KIOSK / TREASURE / ROBOT_DROP)에 해당하는 아이템을 무작위로 n개 반환
func get_shop_items(n: int) -> Array:
	return _filter_and_pick("KIOSK", n)

func _filter_and_pick(source: String, n: int) -> Array:
	var pool: Array = _item_db.filter(
		func(i): return source in i.get("sources", [])
	)
	print("ItemManager: ", source, " 풀 크기 = ", pool.size(), " / 전체 DB = ", _item_db.size())
	if pool.is_empty():
		return []
	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))

# ── 드롭 판정 ─────────────────────────────────────
## source: "TREASURE" | "ROBOT_DROP"
## luck  : player.luck 값 (0~)
## 반환  : 드롭된 아이템 Dictionary, 없으면 {}
func roll_drop(source: String, luck: int) -> Dictionary:
	# 드롭 확률: 기본 30% + luck 5%p (최대 90%)
	var chance: float = min(0.30 + luck * 0.05, 0.90)
	if randf() > chance:
		return {}

	var pool: Array = _item_db.filter(
		func(i): return source in i.get("sources", [])
	)
	if pool.is_empty():
		return {}

	return _weighted_pick(pool, luck)

## luck이 높을수록 고등급 가중치 증가
func _weighted_pick(pool: Array, luck: int) -> Dictionary:
	# 등급 가중치 테이블 (luck 보정)
	var weights: Dictionary = {}
	for grade in GRADE_BASE_WEIGHT:
		var base = GRADE_BASE_WEIGHT[grade]
		# 고등급일수록 luck 보정 가중
		match grade:
			"S": weights[grade] = base + luck * 3
			"A": weights[grade] = base + luck * 2
			"B": weights[grade] = base + luck * 1
			_:   weights[grade] = max(1, base - luck)

	# 각 아이템에 등급 가중치 부여 후 랜덤 선택
	var total: float = 0.0
	var weighted_pool: Array = []
	for item in pool:
		var grade = item.get("grade", "D")
		var w = float(weights.get(grade, 1))
		total += w
		weighted_pool.append({ "item": item, "weight": w })

	if total <= 0.0:
		return pool[randi() % pool.size()]

	var r = randf() * total
	var cumulative: float = 0.0
	for entry in weighted_pool:
		cumulative += entry["weight"]
		if r <= cumulative:
			return entry["item"]

	return pool[pool.size() - 1]

# ── 아이템 획득 + 효과 적용 ───────────────────────
func add_item(item_data: Dictionary) -> void:
	if item_data.is_empty():
		return
	owned_items.append(item_data)
	_apply_to_player(item_data)
	item_added.emit(item_data)

func _apply_to_player(item_data: Dictionary) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	for eff in item_data.get("effects", []):
		_apply_effect(player, eff)

func _apply_effect(player: Node, eff: Dictionary) -> void:
	var key:  String = eff.get("stat_key", "")
	var val:  float  = float(eff.get("value", 0.0))
	var mode: String = eff.get("mode", "add")

	match key:
		# ── 체력 ─────────────────────────────────
		"max_hp":
			player.max_hp     += val
			player.current_hp  = min(player.current_hp + val, player.max_hp)
			_refresh_hp_hud(player)

		# ── 이동 / 점프 ───────────────────────────
		"move_speed":
			player.move_speed += val
		"jump_force":
			# jump_force +N → jump_velocity 더 음수 (높이 증가)
			player.jump_velocity -= val

		# ── 전투 ─────────────────────────────────
		"attack_speed":
			player.weapon_attack_speed += val
			player.equip_weapon(player.weapon_reach, player.weapon_width,
				player.weapon_damage, player.weapon_attack_speed)
		"attack_power_flat":
			player.weapon_damage += int(val)
			player.equip_weapon(player.weapon_reach, player.weapon_width,
				player.weapon_damage, player.weapon_attack_speed)

		# ── 체력 회복 ─────────────────────────────
		"hp_regen":
			player.hp_regen += val

		# ── 재화 관련 ─────────────────────────────
		"interest_bonus":
			# 2.0 → +0.02 (2%)
			player.interest_rate += val / 100.0
		"gold_gain_mult":
			player.gold_gain_mult += val
		"robot_gold_mult":
			player.robot_gold_mult += val
		"mine_gold_mult":
			player.mine_gold_mult += val
		"kiosk_price_mult":
			player.kiosk_price_mult += val
		"fall_dmg_reduction":
			player.fall_dmg_reduction += val

		# ── 산소 / 무게 ───────────────────────────
		"oxygen_drain_rate":
			# multiply 모드: -0.1 → 소모 10% 감소 → dig_speed 근사 보정
			if mode == "multiply":
				player.dig_speed = max(0.1, player.dig_speed - val)
		"weight_limit_mult":
			# 무게 한계 배율 조정 (GameManager.MAX_WEIGHT에 반영)
			var new_max = GameManager.MAX_WEIGHT * (1.0 + val)
			GameManager.set_max_weight(new_max)

		# ── 낙사 피해 감소 (미구현, 변수 누적만) ───
		"fall_dmg_reduction":
			player.fall_dmg_reduction += val

func _refresh_hp_hud(player: Node) -> void:
	var hud = get_tree().get_nodes_in_group("hud")
	# HUD가 그룹에 없을 경우 경로로 직접 접근
	var hud_node = hud[0] if not hud.is_empty() else \
		player.get_node_or_null("/root/GameScene/HUD")
	if hud_node and hud_node.has_method("update_hp"):
		hud_node.update_hp(player.current_hp, player.max_hp)

# ── 누적 스탯 조회 (ShopPanel 가격 보정 등 외부 참조용) ──
func get_player_stat(stat_key: String, default_val: float = 0.0) -> float:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return default_val
	var player = players[0]
	if stat_key in player:
		return float(player.get(stat_key))
	return default_val

# ── 리셋 (게임오버 / 재시작 시) ──────────────────
func reset() -> void:
	owned_items.clear()
