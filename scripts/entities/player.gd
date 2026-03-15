# Player.gd
extends CharacterBody2D

const MOVE_SPEED: float = 200.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

var dig_timer: float = 0.0
var is_digging: bool = false

# 무기 스탯 (무기 아이템 장착 시 교체 예정)
@export var weapon_reach: float = 48.0
@export var weapon_width: float = 32.0
@export var weapon_damage: int = 10
@export var weapon_attack_speed: float = 3.0  # 초당 공격 횟수
@export var move_speed: float = 200.0    # MOVE_SPEED를 변수로 전환
@export var jump_velocity: float = -400.0
@export var dig_speed: float = 1.0
@export var luck: int = 0
@export var interest_rate: float = 0.0
@export var dig_power: int = 20       # 채굴력 (삽 장비로 증가 예정)
@export var dig_cooldown: float = 0.4 # 채굴 쿨타임 (채굴속도 스탯으로 감소)


@onready var level_up_panel = get_node("/root/GameScene/LevelUpPanel")

# 내부 변수
var attack_timer: float = 0.0
var effect_timer: float = 0.0
const EFFECT_DURATION: float = 0.1

const MAX_HP: float = 100.0
var current_hp: float = 100.0
var invincible_timer: float = 0.0  # 무적 시간 (피해 중복 방지)
const INVINCIBLE_DURATION: float = 0.3

func take_damage(amount: int):
	if invincible_timer > 0:
		return
	current_hp -= amount
	invincible_timer = INVINCIBLE_DURATION

	# HUD 갱신
	var hud = get_node("/root/GameScene/HUD")
	if hud:
		hud.update_hp(current_hp, MAX_HP)

	if current_hp <= 0:
		_on_player_dead()

func _on_player_dead():
	GameManager.trigger_game_over()

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_effect: Polygon2D = $AttackHitbox/AttackEffect

func _ready():
	_setup_weapon(weapon_reach, weapon_width)
	level_up_panel.stat_selected.connect(_on_stat_selected)


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
	_handle_dig(delta)      # 추가
	_handle_oxygen(delta)   # 추가
	_handle_effect(delta)
	move_and_slide()

func _update_aim():
	var mouse_pos = get_global_mouse_position()
	attack_hitbox.rotation = (mouse_pos - global_position).angle()

func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

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
	if Input.is_action_pressed("dig") and dig_timer <= 0:
		dig_timer = dig_cooldown / dig_speed  # dig_speed 스탯 반영
		_do_dig()

func _do_dig():
	var mouse_pos = get_global_mouse_position()
	var dir = sign(mouse_pos.x - global_position.x)

	# 마우스 위치를 그대로 dig 위치로 사용
	# 단, X축은 플레이어 기준 방향으로 제한
	var dig_pos = Vector2(
		mouse_pos.x,   # 마우스 X 위치 그대로
		mouse_pos.y    # 마우스 Y 위치 그대로
	)

	var map = get_node("/root/GameScene/Map")
	if map:
		map.dig_block_at(dig_pos, dig_power)
		
# 산소 시스템
const MAX_OXYGEN: float = 100.0
var current_oxygen: float = 100.0
const OXYGEN_DRAIN: float = 15.0
const OXYGEN_REGEN: float = 30.0
const OXYGEN_DAMAGE: float = 5.0

func _handle_oxygen(delta: float):
	if _is_inside_wall():
		current_oxygen -= OXYGEN_DRAIN * delta / dig_speed
		current_oxygen = max(0.0, current_oxygen)
		if current_oxygen <= 0:
			take_damage(int(OXYGEN_DAMAGE * delta))
	else:
		current_oxygen = min(MAX_OXYGEN, current_oxygen + OXYGEN_REGEN * delta)

	var hud = get_node("/root/GameScene/HUD")
	if hud:
		hud.update_oxygen(current_oxygen, MAX_OXYGEN)

func _is_inside_wall() -> bool:
	var map = get_node("/root/GameScene/Map")
	if map == null:
		return false
	# 플레이어 X 좌표가 벽 영역 안인지 체크
	return global_position.x < map.wall_left_x or \
		   global_position.x > map.wall_right_x
