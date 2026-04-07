# Player.gd
extends CharacterBody2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

var dig_timer: float = 0.0
var is_digging: bool = false

var dig_hitbox: Area2D = null
var dig_shape: RectangleShape2D = null
var dig_effect_poly: Polygon2D = null
var dig_effect_timer: float = 0.0
const DIG_EFFECT_DURATION: float = 0.15

# 플레이어 스탯 — data/player_base.json 에서 로드 (DB → export_all.bat → JSON)
var weapon_reach: float         = 48.0
var weapon_width: float         = 32.0
var weapon_damage: int          = 10
var weapon_attack_speed: float  = 1.5
var move_speed: float           = 200.0
var jump_velocity: float        = -400.0
var dig_speed: float            = 1.0
var weapon_knockback: float     = 150.0
var luck: int                   = 0

# ── 무기 베이스 스탯 (장비에서 덮어씀, 초기값 = player_base.json) ──
var weapon_base_damage: int          = 10
var weapon_base_attack_speed: float  = 1.5
var weapon_base_knockback: float     = 150.0

# ── 무기 보너스 스탯 (레벨업·유물 아이템으로 누적) ──────────────
var weapon_bonus_damage: int         = 0
var weapon_bonus_attack_speed: float = 0.0
var weapon_bonus_knockback: float    = 0.0
var interest_rate: float        = 0.0
var dig_power: int              = 20
var dig_cooldown: float         = 0.4
var dig_reach: float            = 32.0
var dig_width: float            = 24.0


@onready var level_up_panel = get_node("/root/GameScene/LevelUpPanel")

# 내부 변수
var attack_timer: float = 0.0
var effect_timer: float = 0.0
const EFFECT_DURATION: float = 0.1

var hitstop_end_msec: int = 0

var max_hp: float = 100.0
var current_hp: float = 100.0
var hp_regen: float = 0.0          # 초당 체력 회복량 (아이템으로 증가)
var invincible_timer: float = 0.0  # 무적 시간 (피해 중복 방지)
const INVINCIBLE_DURATION: float = 0.3

var push_hold_timer: float = 0.0
const PUSH_HOLD_THRESHOLD: float = 0.6  # 0.6초 누른 후부터 밀림
const PUSH_FORCE: float = 30.0          # 기존보다 훨씬 약하게

# ── 벽돌 들기 시스템 ────────────────────────────────
var held_brick: RigidBody2D = null
var _held_visual: Node2D = null
var _held_brick_layer: int = 0   # 픽업 전 collision_layer 저장
var _held_brick_mask: int  = 0   # 픽업 전 collision_mask 저장
var facing_dir: int = 1
const PICKUP_RANGE: float  = 58.0   # 줍기 감지 반경
const HOLD_SPEED_MULT: float = 0.35  # 들고 있을 때 이동속도 배율

# ── ItemManager 연동 스탯 변수 ──────────────────────
var gold_gain_mult: float = 1.0      # 전체 재화 획득 배율
var robot_gold_mult: float = 1.0     # 로봇 처치 재화 배율
var mine_gold_mult: float = 1.0      # 채굴 재화 배율
var kiosk_price_mult: float = 1.0    # 상점 가격 배율 (1.0 = 기본, <1.0 = 할인)
var fall_dmg_reduction: float = 0.0  # 낙하 피해 감소량

@onready var _hud = get_node_or_null("/root/GameScene/HUD")

func take_damage(amount: int):
	if invincible_timer > 0:
		return
	current_hp -= amount
	invincible_timer = INVINCIBLE_DURATION

	# 데미지 텍스트 생성
	var dmg_script = preload("res://scripts/ui/damage_text.gd")
	var dmg_node = Node2D.new()
	dmg_node.set_script(dmg_script)
	dmg_node.amount = amount
	dmg_node.is_critical = false
	# 플레이어 머리 위쪽에서 시작
	dmg_node.global_position = global_position + Vector2(0, -30)
	var scene = get_tree().current_scene
	if scene: scene.add_child(dmg_node)

	# HUD 갱신
	if _hud:
		_hud.update_hp(current_hp, max_hp)

	if current_hp <= 0:
		_on_player_dead()

func _on_player_dead():
	if held_brick != null:
		_clear_held_brick()
	GameManager.trigger_game_over()

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_effect: Polygon2D = $AttackHitbox/AttackEffect

func _ready():
	_load_base_stats()
	_setup_dig_hitbox()
	_setup_weapon(weapon_reach, weapon_width)
	_setup_overhead_bars()
	level_up_panel.stat_selected.connect(_on_stat_selected)
	StageManager.stage_started.connect(_on_stage_started)

func _load_base_stats() -> void:
	var file = FileAccess.open("res://data/player_base.json", FileAccess.READ)
	if not file:
		push_warning("Player: data/player_base.json 로드 실패 — 기본값 사용")
		return
	var rows = JSON.parse_string(file.get_as_text())
	if not rows is Array:
		push_warning("Player: player_base.json 파싱 실패")
		return
	for row in rows:
		var k: String = row.get("key", "")
		var v = row.get("value", null)
		if v == null or k == "":
			continue
		match k:
			"max_hp":              max_hp              = float(v); current_hp = float(v)
			"hp_regen":            hp_regen            = float(v)
			"move_speed":          move_speed          = float(v)
			"jump_velocity":       jump_velocity       = float(v)
			"weapon_reach":        weapon_reach        = float(v)
			"weapon_width":        weapon_width        = float(v)
			"weapon_damage":       weapon_damage = int(v);        weapon_base_damage = int(v)
			"weapon_attack_speed": weapon_attack_speed = float(v); weapon_base_attack_speed = float(v)
			"dig_power":           dig_power           = int(v)
			"dig_speed":           dig_speed           = float(v)
			"dig_cooldown":        dig_cooldown        = float(v)
			"dig_reach":           dig_reach           = float(v)
			"dig_width":           dig_width           = float(v)
			"luck":                luck                = int(v)
			"interest_rate":       interest_rate       = float(v)
			"fall_dmg_reduction":  fall_dmg_reduction  = float(v)
			"gold_gain_mult":      gold_gain_mult      = float(v)
			"robot_gold_mult":     robot_gold_mult     = float(v)
			"mine_gold_mult":      mine_gold_mult      = float(v)
			"kiosk_price_mult":    kiosk_price_mult    = float(v)

func _on_stage_started(stage_num: int):
	current_oxygen = MAX_OXYGEN
	if held_brick != null:
		_clear_held_brick()
	
func _setup_dig_hitbox():
	dig_hitbox = Area2D.new()
	dig_hitbox.collision_layer = 0
	dig_hitbox.collision_mask = 16 # WallBlock (layer 5)
	add_child(dig_hitbox)
	
	var cs = CollisionShape2D.new()
	dig_shape = RectangleShape2D.new()
	cs.shape = dig_shape
	dig_shape.size = Vector2(dig_reach, dig_width)
	dig_hitbox.add_child(cs)
	dig_hitbox.get_child(0).position = Vector2(16 + dig_reach / 2.0, 0)
	
	dig_effect_poly = Polygon2D.new()
	dig_effect_poly.color = Color(0.3, 0.9, 1.0, 0.0)
	dig_effect_poly.z_index = 50
	dig_effect_poly.z_as_relative = false
	dig_effect_poly.polygon = PackedVector2Array([
		Vector2(16,              -dig_width / 2.0),
		Vector2(16 + dig_reach,  -dig_width / 4.0),
		Vector2(16 + dig_reach + 8, 0),
		Vector2(16 + dig_reach,   dig_width / 4.0),
		Vector2(16,               dig_width / 2.0),
	])
	dig_effect_poly.position = Vector2.ZERO
	dig_hitbox.add_child(dig_effect_poly)


func _setup_weapon(reach: float, width: float):
	var shape = RectangleShape2D.new()
	shape.size = Vector2(reach, width)
	attack_hitbox_shape.shape = shape
	attack_hitbox_shape.position = Vector2(16 + reach / 2.0, 0)

	attack_effect.polygon = PackedVector2Array([
		Vector2(16,              -width / 2.0),
		Vector2(16 + reach,      -width / 4.0),
		Vector2(16 + reach + 8,   0),
		Vector2(16 + reach,       width / 4.0),
		Vector2(16,               width / 2.0),
	])
	attack_effect.color = Color(1, 1, 0.3, 0.85)
	attack_effect.visible = false
	attack_effect.z_index = 100
	attack_effect.z_as_relative = false
	
# 무기 최종 스탯 재계산 (base + bonus) 후 히트박스 갱신
func _refresh_weapon_stats() -> void:
	weapon_damage       = weapon_base_damage       + weapon_bonus_damage
	weapon_attack_speed = weapon_base_attack_speed + weapon_bonus_attack_speed
	weapon_knockback    = weapon_base_knockback    + weapon_bonus_knockback
	equip_weapon(weapon_reach, weapon_width, weapon_damage, weapon_attack_speed)

func _on_stat_selected(stat: Dictionary):
	match stat["type"]:
		"weapon_damage":
			weapon_bonus_damage += int(stat["value"])
			_refresh_weapon_stats()
		"weapon_attack_speed":
			weapon_bonus_attack_speed += stat["value"]
			_refresh_weapon_stats()
		"move_speed":
			move_speed += stat["value"]
		"jump_velocity":
			jump_velocity -= stat["value"]  # 음수이므로 빼기
		"dig_speed":
			dig_speed += stat["value"]
		"luck":
			luck += int(stat["value"])
		"interest_rate":
			interest_rate += stat["value"]

func _physics_process(delta: float):
	if GameManager.is_game_over:
		return

	# 히트스톱 복원 (실시간 기준)
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= hitstop_end_msec:
		Engine.time_scale = 1.0

	if invincible_timer > 0:
		invincible_timer -= delta
	if dig_timer > 0:
		dig_timer -= delta

	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_update_aim()
	_handle_attack(delta)
	_handle_dig(delta)
	_handle_oxygen(delta)
	_handle_hp_regen(delta)
	_handle_effect(delta)

	_update_animation()
	_update_overhead_bars()

	velocity.y = min(velocity.y, 800.0)

	# move_and_slide 전 Y 위치·속도 기록
	var pre_y = global_position.y
	var pre_vy = velocity.y
	var was_airborne = not is_on_floor()

	move_and_slide()
	_push_bricks()

	# 낙하 벽돌이 플레이어를 아래로 밀었는지 확인
	_correct_brick_pushdown(pre_y)

	if is_on_floor():
		velocity.y = min(velocity.y, 0.0)
		# 강한 낙하 착지 시 카메라 진동 (내려찍기)
		if was_airborne and pre_vy > 350.0:
			var gs = get_node_or_null("/root/GameScene")
			if gs and gs.has_method("trigger_hit_shake"):
				gs.trigger_hit_shake()

func _correct_brick_pushdown(pre_y: float):
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if not (collider is RigidBody2D and collider.is_in_group("brick")):
			continue

		var normal = col.get_normal()
		# normal.y < -0.5 → 벽돌이 위에서 플레이어를 아래로 누르는 상황
		if normal.y < -0.5:
			# Y 위치를 move_and_slide 이전으로 복원
			global_position.y = pre_y
			velocity.y = 0.0
			return
			
func _update_animation():
	if not is_on_floor():
		anim_sprite.play("jump")
		anim_sprite.speed_scale = 1.0
	elif velocity.x != 0:
		anim_sprite.play("run")
		# 이동속도 비율에 따라 fps 조절
		var speed_ratio = abs(velocity.x) / move_speed
		anim_sprite.speed_scale = speed_ratio
	else:
		anim_sprite.play("idle")
		anim_sprite.speed_scale = 1.0

# 머리 위 벽돌 충돌 시 아래 방향 velocity 차단
func _handle_brick_overhead():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody2D and collider.is_in_group("brick"):
			var normal = collision.get_normal()
			# 충돌 normal이 위쪽(y < -0.5)이면 머리 위에서 눌리는 상황
			# velocity.y가 양수(아래 방향)로 커지는 것 차단
			if normal.y < -0.5 and velocity.y > 0:
				velocity.y = 0.0
	
func _push_bricks():
	var pressing = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	var touching_brick = false

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody2D and collider.is_in_group("brick"):
			touching_brick = true
			if push_hold_timer >= PUSH_HOLD_THRESHOLD:
				var push_dir = -collision.get_normal()
				# Y 방향 힘 제거 → 수평 밀기만
				push_dir.y = 0
				collider.apply_central_impulse(push_dir * PUSH_FORCE)

	# 벽돌에 닿아 있고 방향키 누르는 중일 때만 타이머 증가
	if touching_brick and pressing:
		push_hold_timer += get_physics_process_delta_time()
	else:
		push_hold_timer = 0.0

func _update_aim():
	var mouse_pos = get_global_mouse_position()
	var aimed_rot = (mouse_pos - global_position).angle()
	attack_hitbox.rotation = aimed_rot

	# 마우스 방향으로 캐릭터 반전 (이동 방향 무관하게 항상 조준 방향을 바라봄)
	if mouse_pos.x >= global_position.x:
		anim_sprite.flip_h = false
		facing_dir = 1
	else:
		anim_sprite.flip_h = true
		facing_dir = -1

	# 채굴 상단 방지 로직 (마우스가 위에 있으면 좌/우 수평으로 강제 고정)
	var dig_rot = aimed_rot
	if dig_rot < 0:
		if dig_rot < -PI/2.0:
			dig_rot = PI
		else:
			dig_rot = 0

	dig_hitbox.rotation = dig_rot

func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# 바닥에 있을 때 아래 방향 속도 누적 방지
		velocity.y = 0.0

func _handle_movement():
	var speed = move_speed * (HOLD_SPEED_MULT if held_brick != null else 1.0)
	if Input.is_action_pressed("move_left"):
		velocity.x = -speed
	elif Input.is_action_pressed("move_right"):
		velocity.x = speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func _handle_attack(delta: float):
	if held_brick != null:
		return  # 벽돌 들고 있으면 공격 불가
	# 쿨타임 감소
	if attack_timer > 0:
		attack_timer -= delta

	# 클릭 또는 홀드 모두 공속 한계 내에서 공격
	if Input.is_action_pressed("attack") and attack_timer <= 0:
		attack_timer = 1.0 / weapon_attack_speed  # 공속 기반 쿨타임
		_do_attack()

func _do_attack():
	attack_effect.visible = true
	effect_timer = EFFECT_DURATION

	var hit_bodies = attack_hitbox.get_overlapping_bodies()
	var hit_count = 0
	for body in hit_bodies:
		if not body.has_method("take_damage"):
			continue
		if body.is_in_group("robot"):
			var knockback_dir = (body.global_position - global_position).normalized()
			body.take_damage(weapon_damage, knockback_dir, weapon_knockback)
		else:
			body.take_damage(weapon_damage)
		hit_count += 1

	if hit_count > 0:
		# 히트스톱
		Engine.time_scale = 0.05
		hitstop_end_msec = Time.get_ticks_msec() + 50
		# 카메라 진동 (일반 공격 기본값)
		var gs = get_node_or_null("/root/GameScene")
		if gs and gs.has_method("trigger_hit_shake"):
			gs.trigger_hit_shake()

func _handle_effect(delta: float):
	if effect_timer > 0:
		effect_timer -= delta
		attack_effect.color = Color(1, 1, 0.3, effect_timer / EFFECT_DURATION)
		if effect_timer <= 0:
			attack_effect.visible = false

# 무기 장착 시 외부에서 호출
func equip_weapon(reach: float, width: float, damage: int, attack_speed: float):
	weapon_reach = reach
	weapon_width = width
	weapon_damage = damage
	weapon_attack_speed = attack_speed
	_setup_weapon(reach, width)
	
func _handle_dig(delta: float):
	# 이펙트 타이머 감소
	if dig_effect_timer > 0:
		dig_effect_timer -= delta
		dig_effect_poly.color = Color(0.3, 0.9, 1.0, (dig_effect_timer / DIG_EFFECT_DURATION) * 0.8)
	else:
		dig_effect_poly.color = Color(0.3, 0.9, 1.0, 0.0)

	# ── 들고 있는 상태 ──────────────────────────────
	if held_brick != null:
		if not is_instance_valid(held_brick):
			# 들고 있던 벽돌이 외부 원인으로 사라진 경우 정리
			_clear_held_brick()
			return
		_update_held_visual_pos()
		if Input.is_action_just_pressed("dig"):
			_place_brick()
		return

	# ── 우클릭 첫 입력: 근처 벽돌이면 줍기, 아니면 채굴 ─
	if Input.is_action_just_pressed("dig"):
		var nearby = _get_nearest_brick_in_range()
		if nearby != null:
			_pickup_brick(nearby)
			return

	# ── 기존 채굴 (홀드) ────────────────────────────
	if Input.is_action_pressed("dig") and dig_timer <= 0:
		dig_timer = dig_cooldown / dig_speed
		dig_effect_timer = DIG_EFFECT_DURATION
		_do_dig()

func _do_dig():
	var map = get_node_or_null("/root/GameScene/Map")
	var hit_bodies = dig_hitbox.get_overlapping_bodies()
	
	for body in hit_bodies:
		if body.has_method("take_dig"):
			# 벽돌의 노출 여부 검사 (Adjacency check)
			if map and map.has_method("is_exposed"):
				var block_size = 32.0
				var col = int(body.global_position.x / block_size)
				var row = int(body.global_position.y / block_size)
				if not map.is_exposed(col, row):
					continue # 겹겹이 쌓인 안쪽 블록이면 스킵
			body.take_dig(dig_power)
		
# 체력 회복
func _handle_hp_regen(delta: float):
	if hp_regen <= 0.0 or current_hp <= 0.0:
		return
	current_hp = min(max_hp, current_hp + hp_regen * delta)
	if _hud:
		_hud.update_hp(current_hp, max_hp)

# 산소 시스템
const MAX_OXYGEN: float = 100.0
var current_oxygen: float = 100.0
const OXYGEN_DRAIN: float = 15.0
const OXYGEN_REGEN: float = 10.0
const OXYGEN_DAMAGE: float = 5.0

var oxygen_damage_accumulator: float = 0.0
var toxic_gas_timer: float = 0.0
var toxic_gas_level: int = 0

func _handle_oxygen(delta: float):
	var drain = OXYGEN_DRAIN
	var dmg_rate = OXYGEN_DAMAGE
	
	if StageManager.is_spawn_complete():
		toxic_gas_timer += delta
		if toxic_gas_timer >= 10.0:
			toxic_gas_timer -= 10.0
			toxic_gas_level += 1
			_show_toxic_warning()
	else:
		toxic_gas_level = 0
		toxic_gas_timer = 0.0

	var inside_wall = _is_inside_wall()
	# 독가스 레벨 1이상이면 질식 데미지가 매 레벨 2배씩 증가
	if toxic_gas_level >= 1:
		dmg_rate = OXYGEN_DAMAGE * pow(2, toxic_gas_level)

	# 독가스 레벨 2이상이면 밖(안전지대)에 있어도 무작위 산소 감소
	var force_drain = (toxic_gas_level >= 2)
	
	if inside_wall or force_drain:
		current_oxygen -= drain * delta / dig_speed
		current_oxygen = max(0.0, current_oxygen)
		if current_oxygen <= 0:
			oxygen_damage_accumulator += dmg_rate * delta
			if oxygen_damage_accumulator >= 1.0:
				var dmg = int(oxygen_damage_accumulator)
				take_damage(dmg)
				oxygen_damage_accumulator -= dmg
	else:
		current_oxygen = min(MAX_OXYGEN, current_oxygen + OXYGEN_REGEN * delta)
		oxygen_damage_accumulator = 0.0

	if _hud:
		_hud.update_oxygen(current_oxygen, MAX_OXYGEN)

func _is_inside_wall() -> bool:
	var map = get_node("/root/GameScene/Map")
	if map == null:
		return false
	# 몸이 스치는 것을 방지: 캐릭터 중심점이 명확히 벽 내부 좌표로 넘어갔을 때만 True
	return global_position.x < map.wall_left_x or \
		   global_position.x > map.wall_right_x

func _show_toxic_warning():
	var lbl = Label.new()
	lbl.text = "⚠️ 유해가스 농도 증가! (Lv.%d)" % toxic_gas_level
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0, 0, 0.8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 4
	style.border_color = Color(1, 0.2, 0.2)
	lbl.add_theme_stylebox_override("normal", style)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var start_pos = Vector2(viewport_size.x - 300, viewport_size.y - 100)
	lbl.global_position = start_pos
	
	var canvas = get_node_or_null("/root/GameScene/HUD")
	if canvas:
		canvas.add_child(lbl)
	else:
		get_parent().add_child(lbl)
		
	var tween = create_tween()
	tween.tween_property(lbl, "global_position:y", viewport_size.y - 180, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)


# Removed _update_dig_indicator

# ══ 벽돌 들기 시스템 ═══════════════════════════════════

func _get_nearest_brick_in_range() -> RigidBody2D:
	var space = get_world_2d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = PICKUP_RANGE
	shape_query.shape = circle
	shape_query.transform = Transform2D(0, global_position)
	shape_query.collision_mask = 4  # brick layer (layer 3)
	var results = space.intersect_shape(shape_query)
	var nearest: RigidBody2D = null
	var nearest_dist: float = INF
	for r in results:
		var col = r.get("collider")
		if not (col is RigidBody2D):
			continue
		var dx = abs(col.global_position.x - global_position.x)
		var dy = col.global_position.y - global_position.y  # 양수 = 아래

		# 발 아래 벽돌 제외: Y가 아래이고 수평 거리가 발 너비 이내
		if dy > 10.0 and dx < 35.0:
			continue

		# 바라보는 방향에 있는 벽돌만 허용
		# (facing_dir 방향 반대쪽 10px 초과는 제외)
		var rel_x = col.global_position.x - global_position.x
		if rel_x * facing_dir < -10.0:
			continue

		var dist = col.global_position.distance_to(global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = col
	return nearest

func _pickup_brick(brick: RigidBody2D) -> void:
	held_brick = brick
	# 충돌 레이어 저장 후 완전 제거
	_held_brick_layer = held_brick.collision_layer
	_held_brick_mask  = held_brick.collision_mask
	held_brick.collision_layer = 0
	held_brick.collision_mask  = 0
	# 물리 정지
	held_brick.freeze = true
	# 착지 무게 제거
	if held_brick.is_grounded:
		GameManager.remove_weight(held_brick.weight)
		held_brick.is_grounded = false
	# 플레이어 스프라이트에 들기 색조
	anim_sprite.modulate = Color(1.0, 0.85, 0.65)
	# 원본 벽돌 자체를 플레이어 자식으로 reparent → 실제 에셋 이미지 그대로 표시
	held_brick.reparent(self, false)
	held_brick.visible      = true
	held_brick.modulate     = Color(1.0, 1.0, 1.0, 0.88)
	held_brick.z_index      = 100
	held_brick.z_as_relative = false
	_update_held_visual_pos()


func _update_held_visual_pos() -> void:
	if held_brick and is_instance_valid(held_brick) and held_brick.get_parent() == self:
		# 플레이어 앞 40px, 허리~머리 높이(-42)
		held_brick.position = Vector2(facing_dir * 40, -49)

func _place_brick() -> void:
	if held_brick == null:
		return
	# 씬 루트로 reparent 복원 후 글로벌 좌표 설정
	var scene = get_tree().current_scene
	var target_global = global_position + Vector2(facing_dir * 60.0, 0)
	const SNAP: float = 60.0
	target_global = Vector2(
		floor(target_global.x / SNAP) * SNAP + SNAP * 0.5,
		floor(target_global.y / SNAP) * SNAP + SNAP * 0.5
	)
	held_brick.reparent(scene, false)
	held_brick.global_position  = target_global
	held_brick.linear_velocity  = Vector2.ZERO
	held_brick.angular_velocity = 0.0
	held_brick.modulate         = Color(1, 1, 1, 1)
	held_brick.z_index          = 0
	held_brick.z_as_relative    = true
	held_brick.collision_layer  = _held_brick_layer
	held_brick.collision_mask   = _held_brick_mask
	held_brick.freeze           = false
	_clear_held_brick()

func _clear_held_brick() -> void:
	# reparent된 경우 held_brick은 이미 씬 루트로 돌아감
	held_brick = null
	# 구버전 _held_visual 잔재 정리 (혹시 남아있을 경우)
	if _held_visual:
		_held_visual.queue_free()
		_held_visual = null
	anim_sprite.modulate = Color(1, 1, 1)

# ══ 머리 위 체력/산소 바 ═════════════════════════════════

const BAR_WIDTH: float  = 40.0
const BAR_Y_HP: float   = -38.0   # 체력 바 Y 오프셋
const BAR_Y_OXY: float  = -34.0   # 산소 바 Y 오프셋 (HP 아래 2px 여백)
const HP_BAR_H: float   = 3.0     # 체력 바 두께
const OXY_BAR_H: float  = 2.0     # 산소 바 두께

var _bar_root: Node2D = null
var _hp_bg: Polygon2D = null
var _hp_fill: Polygon2D = null
var _oxy_bg: Polygon2D = null
var _oxy_fill: Polygon2D = null

func _setup_overhead_bars() -> void:
	_bar_root = Node2D.new()
	_bar_root.z_index = 200
	_bar_root.z_as_relative = false
	add_child(_bar_root)

	# ── 체력 배경 (어두운 그라디언트) ──────────────────
	_hp_bg = Polygon2D.new()
	_hp_bg.polygon = _bar_rect(BAR_WIDTH, HP_BAR_H)
	_hp_bg.vertex_colors = _grad_colors(
		Color(0.18, 0.18, 0.18, 0.75), Color(0.06, 0.06, 0.06, 0.75))
	_hp_bg.position = Vector2(-BAR_WIDTH * 0.5, BAR_Y_HP)
	_bar_root.add_child(_hp_bg)

	# ── 체력 채움 ──────────────────────────────────────
	_hp_fill = Polygon2D.new()
	_hp_fill.polygon = _bar_rect(BAR_WIDTH, HP_BAR_H)
	_hp_fill.vertex_colors = _hp_grad_colors(1.0)
	_hp_fill.position = Vector2(-BAR_WIDTH * 0.5, BAR_Y_HP)
	_bar_root.add_child(_hp_fill)

	# ── 산소 배경 (어두운 그라디언트) ──────────────────
	_oxy_bg = Polygon2D.new()
	_oxy_bg.polygon = _bar_rect(BAR_WIDTH, OXY_BAR_H)
	_oxy_bg.vertex_colors = _grad_colors(
		Color(0.08, 0.1, 0.25, 0.75), Color(0.03, 0.04, 0.12, 0.75))
	_oxy_bg.position = Vector2(-BAR_WIDTH * 0.5, BAR_Y_OXY)
	_bar_root.add_child(_oxy_bg)

	# ── 산소 채움 ──────────────────────────────────────
	_oxy_fill = Polygon2D.new()
	_oxy_fill.polygon = _bar_rect(BAR_WIDTH, OXY_BAR_H)
	_oxy_fill.vertex_colors = _grad_colors(
		Color(0.5, 0.85, 1.0, 0.95), Color(0.15, 0.45, 0.8, 0.95))
	_oxy_fill.position = Vector2(-BAR_WIDTH * 0.5, BAR_Y_OXY)
	_bar_root.add_child(_oxy_fill)

# 사각형 폴리곤 정점 순서: [TL, TR, BR, BL]
func _bar_rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0),
		Vector2(w, h), Vector2(0, h)
	])

# 위(top)→아래(bottom) 수직 그라디언트용 vertex_colors
func _grad_colors(top: Color, bottom: Color) -> PackedColorArray:
	return PackedColorArray([top, top, bottom, bottom])

# HP 비율에 따라 색상 세트 반환 (위=밝음, 아래=어두움)
func _hp_grad_colors(ratio: float) -> PackedColorArray:
	var top: Color
	var bot: Color
	if ratio > 0.5:
		top = Color(0.35, 1.0, 0.45, 0.95)
		bot = Color(0.08, 0.55, 0.15, 0.95)
	elif ratio > 0.25:
		top = Color(1.0,  0.92, 0.25, 0.95)
		bot = Color(0.65, 0.42, 0.05, 0.95)
	else:
		top = Color(1.0,  0.28, 0.18, 0.95)
		bot = Color(0.55, 0.06, 0.06, 0.95)
	return _grad_colors(top, bot)

func _update_overhead_bars() -> void:
	if _hp_fill == null:
		return

	# ── 체력 바 ──────────────────────────────────────
	var hp_ratio = clampf(current_hp / max_hp, 0.0, 1.0)
	var hp_w = BAR_WIDTH * hp_ratio
	if hp_w > 0.0:
		_hp_fill.polygon      = _bar_rect(hp_w, HP_BAR_H)
		_hp_fill.vertex_colors = _hp_grad_colors(hp_ratio)
		_hp_fill.visible = true
	else:
		_hp_fill.visible = false

	# ── 산소 바 ──────────────────────────────────────
	var oxy_ratio = clampf(current_oxygen / MAX_OXYGEN, 0.0, 1.0)
	var oxy_w = BAR_WIDTH * oxy_ratio
	if oxy_w > 0.0:
		_oxy_fill.polygon      = _bar_rect(oxy_w, OXY_BAR_H)
		_oxy_fill.vertex_colors = _grad_colors(
			Color(0.5, 0.85, 1.0, 0.95), Color(0.15, 0.45, 0.8, 0.95))
		_oxy_fill.visible = true
	else:
		_oxy_fill.visible = false
