# Player.gd
extends CharacterBody2D

# 이동 관련 상수
const MOVE_SPEED: float = 200.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

# 공격 관련
const ATTACK_COOLDOWN: float = 0.3

# 내부 변수
var attack_timer: float = 0.0
var is_facing_right: bool = true

@onready var attack_hitbox: Area2D = $AttackHitbox

func _ready():
	pass

func _physics_process(delta: float):
	if GameManager.is_game_over:
		return

	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_handle_attack(delta)
	move_and_slide()

# 중력 적용
func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

# 좌우 이동
func _handle_movement():
	if Input.is_action_pressed("move_left"):
		velocity.x = -MOVE_SPEED
		is_facing_right = false
		_flip_hitbox()
	elif Input.is_action_pressed("move_right"):
		velocity.x = MOVE_SPEED
		is_facing_right = true
		_flip_hitbox()
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)

# 점프
func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

# 공격
func _handle_attack(delta: float):
	attack_timer -= delta
	if Input.is_action_just_pressed("attack") and attack_timer <= 0:
		attack_timer = ATTACK_COOLDOWN
		_do_attack()

func _do_attack():
	var hit_bodies = attack_hitbox.get_overlapping_bodies()
	for body in hit_bodies:
		if body.has_method("take_damage"):
			body.take_damage(10)

# 바라보는 방향에 따라 히트박스 위치 반전
func _flip_hitbox():
	if is_facing_right:
		attack_hitbox.position.x = abs(attack_hitbox.position.x)
	else:
		attack_hitbox.position.x = -abs(attack_hitbox.position.x)
