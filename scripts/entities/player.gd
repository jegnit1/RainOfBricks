# Player.gd
extends CharacterBody2D

const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

var dig_timer: float = 0.0
var is_digging: bool = false

var dig_hitbox: Area2D = null
var dig_shape: RectangleShape2D = null
var dig_effect_poly: Polygon2D = null
var dig_effect_timer: float = 0.0
const DIG_EFFECT_DURATION: float = 0.15

# 무기 스탯 (무기 아이템 장착 시 교체 예정)
@export var weapon_reach: float = 48.0
@export var weapon_width: float = 32.0
@export var weapon_damage: int = 10
@export var weapon_attack_speed: float = 1.5  # 초당 공격 횟수
@export var move_speed: float = 200.0    # MOVE_SPEED를 변수로 전환
@export var jump_velocity: float = -400.0
@export var dig_speed: float = 1.0
@export var luck: int = 0
@export var interest_rate: float = 0.0
@export var dig_power: int = 20       # 채굴력 (삽 장비로 증가 예정)
@export var dig_cooldown: float = 0.4 # 채굴 쿨타임 (채굴속도 스탯으로 감소)
@export var dig_reach: float = 32.0   # 채굴 사거리 (기본 1블록)
@export var dig_width: float = 24.0   # 채굴 폭


@onready var level_up_panel = get_node("/root/GameScene/LevelUpPanel")

# 내부 변수
var attack_timer: float = 0.0
var effect_timer: float = 0.0
const EFFECT_DURATION: float = 0.1

var max_hp: float = 100.0
var current_hp: float = 100.0
var hp_regen: float = 0.0          # 초당 체력 회복량 (아이템으로 증가)
var invincible_timer: float = 0.0  # 무적 시간 (피해 중복 방지)
const INVINCIBLE_DURATION: float = 0.3

var push_hold_timer: float = 0.0
const PUSH_HOLD_THRESHOLD: float = 0.6  # 0.6초 누른 후부터 밀림
const PUSH_FORCE: float = 30.0          # 기존보다 훨씬 약하게

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
	GameManager.trigger_game_over()

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_effect: Polygon2D = $AttackHitbox/AttackEffect

func _ready():
	_setup_dig_hitbox()
	_setup_weapon(weapon_reach, weapon_width)
	level_up_panel.stat_selected.connect(_on_stat_selected)
	
	StageManager.stage_started.connect(_on_stage_started)

func _on_stage_started(stage_num: int):
	current_oxygen = MAX_OXYGEN
	
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
	
func _on_stat_selected(stat: Dictionary):
	match stat["type"]:
		"weapon_damage":
			weapon_damage += int(stat["value"])
			equip_weapon(weapon_reach, weapon_width, weapon_damage, weapon_attack_speed)
		"weapon_attack_speed":
			weapon_attack_speed += stat["value"]
			equip_weapon(weapon_reach, weapon_width, weapon_damage, weapon_attack_speed)
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

	velocity.y = min(velocity.y, 800.0)

	# move_and_slide 전 Y 위치 기록
	var pre_y = global_position.y

	move_and_slide()
	_push_bricks()

	# 낙하 벽돌이 플레이어를 아래로 밀었는지 확인
	_correct_brick_pushdown(pre_y)

	if is_on_floor():
		velocity.y = min(velocity.y, 0.0)

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
	if Input.is_action_pressed("move_left"):
		velocity.x = -move_speed
	elif Input.is_action_pressed("move_right"):
		velocity.x = move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func _handle_attack(delta: float):
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
	for body in hit_bodies:
		if body.has_method("take_damage"):
			body.take_damage(weapon_damage)

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

	if Input.is_action_pressed("dig") and dig_timer <= 0:
		dig_timer = dig_cooldown / dig_speed
		dig_effect_timer = DIG_EFFECT_DURATION  # 채굴 시 이펙트 시작
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
