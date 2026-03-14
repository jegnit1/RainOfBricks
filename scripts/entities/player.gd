# Player.gd
extends CharacterBody2D

const MOVE_SPEED: float = 200.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

# 무기 스탯 (무기 아이템 장착 시 교체 예정)
@export var weapon_reach: float = 48.0
@export var weapon_width: float = 32.0
@export var weapon_damage: int = 10
@export var weapon_attack_speed: float = 3.0  # 초당 공격 횟수

# 내부 변수
var attack_timer: float = 0.0
var effect_timer: float = 0.0
const EFFECT_DURATION: float = 0.1

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_effect: Polygon2D = $AttackHitbox/AttackEffect

func _ready():
	_setup_weapon(weapon_reach, weapon_width)

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

func _physics_process(delta: float):
	if GameManager.is_game_over:
		return

	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_update_aim()
	_handle_attack(delta)
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
		velocity.x = -MOVE_SPEED
	elif Input.is_action_pressed("move_right"):
		velocity.x = MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

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
