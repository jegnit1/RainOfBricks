# Robot.gd
extends CharacterBody2D

# 로봇 스탯 (robots.json에서 로드)
var robot_id: String = "robot_basic"
var hp: int = 50
var weight: float = 15.0
var move_speed: float = 80.0
var jump_velocity: float = -300.0
var power_duration: float = 5.0
var damage: int = 10
var damage_interval: float = 0.5
var currency_value: int = 15
var exp_value: int = 20

# 상태
var is_powered: bool = true
var is_grounded: bool = false
var is_patrolling: bool = false
var patrol_direction: int = 1
var patrol_timer: float = 0.0
const PATROL_CHANGE_TIME: float = 2.0

const GRAVITY: float = 980.0

@onready var power_timer: Timer = $PowerTimer
@onready var damage_timer: Timer = $DamageTimer
@onready var player_detector: Area2D = $PlayerDetector
@onready var poly: Polygon2D = $Polygon2D

func _ready():
	_setup_visuals()
	_start_power()
	power_timer.timeout.connect(_on_power_timeout)
	damage_timer.timeout.connect(_on_damage_tick)
	player_detector.body_entered.connect(_on_player_entered)
	player_detector.body_exited.connect(_on_player_exited)

func setup(data: Dictionary):
	robot_id = data.get("id", "robot_basic")
	hp = data.get("hp", 50)
	weight = data.get("weight", 15.0)
	move_speed = data.get("move_speed", 80.0)
	jump_velocity = data.get("jump_velocity", -300.0)
	power_duration = data.get("power_duration", 5.0)
	damage = data.get("damage", 10)
	damage_interval = data.get("damage_interval", 0.5)
	currency_value = data.get("currency_value", 15)
	exp_value = data.get("exp_value", 20)
	damage_timer.wait_time = damage_interval

func _setup_visuals():
	poly.polygon = PackedVector2Array([
		Vector2(-20, -30),
		Vector2( 20, -30),
		Vector2( 20,  30),
		Vector2(-20,  30)
	])
	poly.color = Color(0.8, 0.2, 0.2)  # 빨간색 (전원 ON)

func _start_power():
	is_powered = true
	poly.color = Color(0.8, 0.2, 0.2)
	if power_duration > 0:
		power_timer.wait_time = power_duration
		power_timer.start()

func _on_power_timeout():
	_power_off()

func _power_off():
	is_powered = false
	is_patrolling = false
	velocity = Vector2.ZERO
	poly.color = Color(0.4, 0.4, 0.4)
	damage_timer.stop()
	
	collision_layer = 4        # brick 레이어 (무게 누적용)
	collision_mask = 1 | 16   # world + wall만 (brick 제외)
	
	if is_grounded:
		GameManager.add_weight(weight)

func _physics_process(delta: float):
	if not is_powered:
		# 전원 OFF → 중력만 적용
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		# 전원 OFF 상태로 낙하 중 처음 착지한 경우 무게 추가
		if not is_grounded and is_on_floor():
			is_grounded = true
			GameManager.add_weight(weight)
		return

	if GameManager.is_game_over:
		return

	_apply_gravity(delta)
	_handle_ai(delta)
	move_and_slide()
	_check_grounded()

func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_ai(delta: float):
	var player = _get_player()
	if player == null:
		return

	if is_patrolling:
		_handle_patrol(delta)
		# 배회 중에도 주기적으로 추적 재시도
		patrol_timer -= delta
		if patrol_timer <= 0:
			is_patrolling = false
		return

	# 플레이어 방향으로 이동
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * move_speed

	# 장애물 감지 → 점프 or 배회 전환
	if is_on_floor() and _is_blocked(dir):
		var obstacle_height = _get_obstacle_height(dir)
		if obstacle_height != 0 and abs(jump_velocity) >= obstacle_height:
			# 점프로 넘어감
			velocity.y = jump_velocity
		else:
			# 배회로 전환
			is_patrolling = true
			patrol_direction = -dir
			patrol_timer = PATROL_CHANGE_TIME

func _handle_patrol(delta: float):
	velocity.x = patrol_direction * move_speed
	# 벽에 막히면 방향 전환
	if is_on_wall():
		patrol_direction *= -1

func _is_blocked(direction: int) -> bool:
	# 이동 방향으로 벽이나 벽돌에 막혔는지 체크
	return is_on_wall()

func _get_obstacle_height(direction: int) -> float:
	# RayCast로 장애물 높이 측정
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(direction * 50, 0),
		0b01101  # world + brick + wall
	)
	var result = space.intersect_ray(query)
	if result.is_empty():
		return 0.0

	# 장애물 위쪽으로 Ray를 쏴서 높이 측정
	var top_query = PhysicsRayQueryParameters2D.create(
		result["position"] + Vector2(direction * 5, -200),
		result["position"] + Vector2(direction * 5, 0),
		0b01101
	)
	var top_result = space.intersect_ray(top_query)
	if top_result.is_empty():
		return 0.0

	return global_position.y - top_result["position"].y

func _check_grounded():
	if not is_grounded and is_on_floor():
		is_grounded = true

func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _on_player_entered(body: Node):
	if not is_powered:
		return
	damage_timer.start()
	# 즉시 첫 피해
	_on_damage_tick()

func _on_player_exited(body: Node):
	damage_timer.stop()

func _on_damage_tick():
	if not is_powered:
		damage_timer.stop()
		return
	var players = player_detector.get_overlapping_bodies()
	for p in players:
		if p.has_method("take_damage"):
			p.take_damage(damage)

func take_damage(amount: int):
	hp -= amount
	
	# 데미지 텍스트 생성
	var dmg_script = preload("res://scripts/ui/damage_text.gd")
	var dmg_node = Node2D.new()
	dmg_node.set_script(dmg_script)
	dmg_node.amount = amount
	dmg_node.is_critical = false
	dmg_node.global_position = global_position + Vector2(0, -30)
	var scene = get_tree().current_scene
	if scene: scene.add_child(dmg_node)
	
	if hp <= 0:
		_destroy()

func _destroy():
	# 전원 ON 처치 시 2배 재화
	var reward = currency_value * 2 if is_powered else currency_value
	GameManager.add_currency(reward)
	GameManager.add_exp(exp_value)

	# 착지 상태에서 파괴 시 무게 제거
	if is_grounded and not is_powered:
		GameManager.remove_weight(weight)

	# 아이템 드롭 판정
	var players = get_tree().get_nodes_in_group("player")
	var luck = players[0].luck if not players.is_empty() else 0
	var drop = ItemManager.roll_drop("ROBOT_DROP", luck)
	if not drop.is_empty():
		ItemManager.add_item(drop)

	queue_free()
