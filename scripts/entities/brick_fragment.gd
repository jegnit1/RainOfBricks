# BrickFragment.gd
# 벽돌 파괴 시 흩뿌려지는 파편 이펙트.
# 별도 에셋 없이 원본 brick 텍스처를 격자로 분할해 각 조각에 맵핑.
extends Node2D

const GRAVITY: float = 580.0

var _velocity:  Vector2  = Vector2.ZERO
var _rot_speed: float    = 0.0
var _lifetime:  float    = 0.65
var _elapsed:   float    = 0.0
var _poly:      Polygon2D = null

# ── 초기화 ────────────────────────────────────────────────
# pos          : 스폰 월드 좌표 (이 조각의 중심)
# vel          : 초기 속도 벡터
# display_poly : 조각 형태 정점 배열 (로컬 좌표, 중심 기준)
# uv_coords    : 텍스처 UV 좌표 (display_poly 정점에 1:1 대응)
# tex          : 원본 brick 텍스처
# rot_spd      : 초기 회전 속도 (rad/s)
# life         : 수명(s)
func setup(pos: Vector2, vel: Vector2,
		   display_poly: PackedVector2Array, uv_coords: PackedVector2Array,
		   tex: Texture2D, rot_spd: float, life: float = 0.65) -> void:
	global_position = pos
	_velocity       = vel
	_rot_speed      = rot_spd
	_lifetime       = life

	_poly                = Polygon2D.new()
	_poly.texture        = tex
	_poly.polygon        = display_poly
	_poly.uv             = uv_coords
	_poly.z_index        = 8
	_poly.z_as_relative  = false
	add_child(_poly)

	# 검정 테두리 (Line2D, 폴리곤 윤곽을 따라 닫힌 선)
	var outline := Line2D.new()
	# 정점 배열에 첫 번째를 끝에 추가해 닫힌 선처럼 보이게
	var pts := PackedVector2Array(display_poly)
	pts.append(display_poly[0])
	outline.points          = pts
	outline.width           = 1.2
	outline.default_color   = Color(0.0, 0.0, 0.0, 0.85)
	outline.z_index         = 9
	outline.z_as_relative   = false
	add_child(outline)

func _process(delta: float) -> void:
	_elapsed += delta
	var ratio: float = _elapsed / _lifetime
	if ratio >= 1.0:
		queue_free()
		return

	_velocity.y     += GRAVITY * delta
	global_position += _velocity * delta
	rotation        += _rot_speed * delta

	# 후반 40% 에서 페이드아웃
	if ratio > 0.6:
		modulate.a = 1.0 - (ratio - 0.6) / 0.4
