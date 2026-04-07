# Brick.gd
extends RigidBody2D

@export var hp: int = 30
@export var weight: float = 5.0
@export var currency_value: int = 5
@export var exp_value: int = 10  # 벽돌 파괴 시 경험치

# HP 절반 이상이면 brick_2(온전한 모습), 미만이면 brick_1(손상된 모습)
const HP_HIGH_TEXTURE = preload("res://assets/sprites/brick_2.png")
const HP_LOW_TEXTURE  = preload("res://assets/sprites/brick_1.png")

@onready var _sprite: Sprite2D = $Sprite2D

var max_hp: int = 30
var is_grounded: bool = false
var was_hit_in_air: bool = false

func _ready():
	max_hp = hp
	_update_texture()
	# 바닥 착지 감지
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if is_grounded:
		return
	# 바닥이나 다른 벽돌 위에 착지한 경우
	if body.is_in_group("ground") or body.is_in_group("brick"):
		is_grounded = true
		GameManager.add_weight(weight)

func _update_texture() -> void:
	if _sprite == null:
		return
	# 초기 최대 체력이 80 이상인 벽돌만 brick_2(온전한 모습) 사용
	_sprite.texture = HP_HIGH_TEXTURE if max_hp >= 80 else HP_LOW_TEXTURE

func take_damage(amount: int):
	hp -= amount

	# 데미지 텍스트 생성
	var dmg_script = preload("res://scripts/ui/damage_text.gd")
	var dmg_node = Node2D.new()
	dmg_node.set_script(dmg_script)
	dmg_node.amount = amount
	dmg_node.is_critical = false
	dmg_node.global_position = global_position
	var scene = get_tree().current_scene
	if scene: scene.add_child(dmg_node)

	if hp <= 0:
		_destroy()

const _FRAG_SCRIPT = preload("res://scripts/entities/brick_fragment.gd")

func _destroy():
	# 주변 벽돌 sleeping 해제
	var bodies = get_colliding_bodies()
	for body in bodies:
		if body is RigidBody2D:
			body.sleeping = false

	# 파편 이펙트
	_spawn_fragments()

	# 재화 지급 (공중이면 2배)
	var reward = currency_value * 2 if not is_grounded else currency_value
	GameManager.add_currency(reward)
	GameManager.add_exp(exp_value)

	# 착지한 벽돌이 파괴되면 무게 제거
	if is_grounded:
		GameManager.remove_weight(weight)

	queue_free()

func _spawn_fragments() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return

	# HP 상태에 따라 실제 벽돌 텍스처 선택
	var tex: Texture2D = HP_HIGH_TEXTURE if max_hp >= 80 else HP_LOW_TEXTURE
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())

	# ── 큰 파편: 텍스처를 COLS×ROWS 격자로 분할 ───────────────
	const COLS: int = 3
	const ROWS: int = 3
	var cell_w: float = tex_w / COLS
	var cell_h: float = tex_h / ROWS

	# 스프라이트 로컬 좌표 -> 월드 좌표 오프셋 계산
	# Sprite2D는 기본적으로 텍스처 중심이 (0,0)이므로 좌상단은 (-tex_w/2, -tex_h/2)
	var sprite_origin: Vector2 = Vector2(-tex_w * 0.5, -tex_h * 0.5)

	var chunk_count: int = randi_range(6, 8)
	var used_cells: Array = []
	for i in chunk_count:
		# 격자 셀을 랜덤하게 (중복 허용)
		var col: int = randi() % COLS
		var row: int = randi() % ROWS

		# 셀의 픽셀 범위 (텍스처 좌표)
		var u0: float = col * cell_w
		var v0: float = row * cell_h
		var u1: float = u0 + cell_w
		var v1: float = v0 + cell_h

		# 약간 무작위 변형으로 딱딱한 격자 느낌 완화
		var jitter: float = min(cell_w, cell_h) * 0.15
		var pu0: float = u0 + randf_range(0.0, jitter)
		var pv0: float = v0 + randf_range(0.0, jitter)
		var pu1: float = u1 - randf_range(0.0, jitter)
		var pv1: float = v1 - randf_range(0.0, jitter)

		# UV 좌표 (텍스처 픽셀 단위)
		var uv: PackedVector2Array = PackedVector2Array([
			Vector2(pu0, pv0),
			Vector2(pu1, pv0),
			Vector2(pu1, pv1),
			Vector2(pu0, pv1),
		])

		# 로컬 정점 (조각 중심 기준) — 스프라이트 좌표에서 셀 중심을 빼서 중심 정렬
		var cx: float = (pu0 + pu1) * 0.5
		var cy: float = (pv0 + pv1) * 0.5
		var display_poly: PackedVector2Array = PackedVector2Array([
			Vector2(pu0 - cx, pv0 - cy),
			Vector2(pu1 - cx, pv0 - cy),
			Vector2(pu1 - cx, pv1 - cy),
			Vector2(pu0 - cx, pv1 - cy),
		])

		# 스폰 위치: 셀 중심의 월드 좌표 + 랜덤 오프셋
		var cell_world_offset: Vector2 = sprite_origin + Vector2(cx, cy)
		var spawn_pos: Vector2 = global_position + cell_world_offset + Vector2(
			randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

		var angle: float   = randf_range(0.0, TAU)
		var speed: float   = randf_range(120.0, 350.0)
		var vel: Vector2   = Vector2(cos(angle), sin(angle)) * speed
		vel.y             -= randf_range(80.0, 200.0)

		var rot_spd: float = randf_range(-10.0, 10.0)
		var life: float    = randf_range(0.50, 0.72)

		var frag = Node2D.new()
		frag.set_script(_FRAG_SCRIPT)
		scene.add_child(frag)
		frag.setup(spawn_pos, vel, display_poly, uv, tex, rot_spd, life)

	# ── 작은 먼지 파편: 텍스처 임의 서브영역 ─────────────────
	var dust_count: int = randi_range(3, 4)
	for i in dust_count:
		# 작은 랜덤 영역 (셀의 절반 크기)
		var sw: float  = randf_range(cell_w * 0.3, cell_w * 0.55)
		var sh: float  = randf_range(cell_h * 0.3, cell_h * 0.55)
		var u0: float  = randf_range(0.0, tex_w - sw)
		var v0: float  = randf_range(0.0, tex_h - sh)
		var u1: float  = u0 + sw
		var v1: float  = v0 + sh

		var uv: PackedVector2Array = PackedVector2Array([
			Vector2(u0, v0), Vector2(u1, v0),
			Vector2(u1, v1), Vector2(u0, v1),
		])
		var cx: float = (u0 + u1) * 0.5
		var cy: float = (v0 + v1) * 0.5
		var display_poly: PackedVector2Array = PackedVector2Array([
			Vector2(u0 - cx, v0 - cy), Vector2(u1 - cx, v0 - cy),
			Vector2(u1 - cx, v1 - cy), Vector2(u0 - cx, v1 - cy),
		])

		var cell_world_offset: Vector2 = sprite_origin + Vector2(cx, cy)
		var spawn_pos: Vector2 = global_position + cell_world_offset + Vector2(
			randf_range(-35.0, 35.0), randf_range(-35.0, 35.0))

		var angle: float   = randf_range(0.0, TAU)
		var speed: float   = randf_range(200.0, 480.0)
		var vel: Vector2   = Vector2(cos(angle), sin(angle)) * speed
		vel.y             -= randf_range(60.0, 160.0)

		var rot_spd: float = randf_range(-15.0, 15.0)
		var life: float    = randf_range(0.30, 0.50)

		var frag = Node2D.new()
		frag.set_script(_FRAG_SCRIPT)
		scene.add_child(frag)
		frag.setup(spawn_pos, vel, display_poly, uv, tex, rot_spd, life)
