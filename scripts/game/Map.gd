# Map.gd
extends Node2D

@export var map_width: float = 1280.0
@export var map_height: float = 720.0

const WALL_THICKNESS: float = 40.0

var floor_y: float
var wall_left_x: float
var wall_right_x: float
var ceiling_y: float = 0.0

@onready var floor_body: StaticBody2D = $Floor
@onready var wall_left: StaticBody2D = $WallLeft
@onready var wall_right: StaticBody2D = $WallRight

func _ready():
	_build_map()

func _build_map():
	floor_y = map_height - WALL_THICKNESS
	wall_left_x = WALL_THICKNESS
	wall_right_x = map_width - WALL_THICKNESS
	ceiling_y = 0.0

	_setup_floor()
	_setup_wall_left()
	_setup_wall_right()

func _setup_floor():
	floor_body.position = Vector2(map_width / 2.0, map_height - WALL_THICKNESS / 2.0)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(map_width, WALL_THICKNESS)
	$Floor/CollisionShape2D.shape = shape

	var rect = $Floor/ColorRect
	rect.size = Vector2(map_width, WALL_THICKNESS)
	rect.position = Vector2(-map_width / 2.0, -WALL_THICKNESS / 2.0)

func _setup_wall_left():
	wall_left.position = Vector2(WALL_THICKNESS / 2.0, map_height / 2.0)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(WALL_THICKNESS, map_height)
	$WallLeft/CollisionShape2D.shape = shape

	var rect = $WallLeft/ColorRect
	rect.size = Vector2(WALL_THICKNESS, map_height)
	rect.position = Vector2(-WALL_THICKNESS / 2.0, -map_height / 2.0)

func _setup_wall_right():
	wall_right.position = Vector2(map_width - WALL_THICKNESS / 2.0, map_height / 2.0)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(WALL_THICKNESS, map_height)
	$WallRight/CollisionShape2D.shape = shape

	var rect = $WallRight/ColorRect
	rect.size = Vector2(WALL_THICKNESS, map_height)
	rect.position = Vector2(-WALL_THICKNESS / 2.0, -map_height / 2.0)

func get_spawn_area() -> Dictionary:
	return {
		"left": wall_left_x,
		"right": wall_right_x,
		"top": ceiling_y,
		"bottom": floor_y
	}
