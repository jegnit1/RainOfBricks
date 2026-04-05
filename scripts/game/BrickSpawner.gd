# BrickSpawner.gd
extends Node2D

@export var brick_scene: PackedScene

var spawn_timer: float = 0.0
var map: Node2D

func _ready():
	map = get_parent().get_node("Map")
	StageManager.stage_started.connect(_on_stage_started)

func _on_stage_started(stage_num: int):
	spawn_timer = 0.0

func _process(delta: float):
	if GameManager.is_game_over:
		return
	if get_tree().paused:
		return
	if StageManager.is_spawn_complete():
		return

	spawn_timer += delta
	var interval = StageManager.current_stage_data.get("brick_spawn_interval", 2.0)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_brick()

func _spawn_brick():
	if brick_scene == null:
		return

	var spawn_area = map.get_spawn_area()
	var brick = brick_scene.instantiate()
	var rand_x = randf_range(spawn_area["left"] + 30, spawn_area["right"] - 30)
	brick.position = Vector2(rand_x, -30)

	var brick_hp = StageManager.current_stage_data.get("brick_hp", 30)
	brick.hp = brick_hp

	get_parent().add_child(brick)
	StageManager.on_brick_spawned()  # 마지막 벽돌이면 내부에서 stage_cleared 발신
