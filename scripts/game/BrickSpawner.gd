# BrickSpawner.gd
extends Node2D

@export var spawn_interval: float = 2.0
@export var brick_scene: PackedScene

var spawn_timer: float = 0.0
var map: Node2D

func _ready():
	map = get_parent().get_node("Map")

func _process(delta: float):
	if GameManager.is_game_over:
		return
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_brick()

func _spawn_brick():
	if brick_scene == null:
		return
	
	var spawn_area = map.get_spawn_area()
	var brick = brick_scene.instantiate()
	
	# 랜덤 X 좌표 (벽 안쪽에서만)
	var rand_x = randf_range(spawn_area["left"] + 30, spawn_area["right"] - 30)
	brick.position = Vector2(rand_x, -30)
	
	get_parent().add_child(brick)
