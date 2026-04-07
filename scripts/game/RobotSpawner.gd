# RobotSpawner.gd
extends Node2D

@export var robot_scene: PackedScene

var spawn_timer: float = 0.0
var map: Node2D
var robot_pool: Array = []

func _ready():
	map = get_parent().get_node("Map")
	_load_robot_data()

func _load_robot_data():
	var file = FileAccess.open("res://data/robots.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Array:
			robot_pool = data
		elif data is Dictionary:
			robot_pool = data.get("robots", [])

func _process(delta: float):
	if GameManager.is_game_over:
		return
	if get_tree().paused:
		return
	if StageManager.is_spawn_complete():
		return

	# 로봇 비활성화 스테이지
	var robot_enabled = StageManager.current_stage_data.get("robot_enabled", false)
	if not robot_enabled:
		return

	spawn_timer += delta
	var interval = StageManager.current_stage_data.get("robot_spawn_interval", 999.0)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_robot()

func _spawn_robot():
	if robot_scene == null or robot_pool.is_empty():
		return
	var spawn_area = map.get_spawn_area()
	var robot = robot_scene.instantiate()
	var rand_x = randf_range(spawn_area["left"] + 30, spawn_area["right"] - 30)
	robot.position = Vector2(rand_x, -40)
	var data = robot_pool[randi() % robot_pool.size()].duplicate()
	# 스테이지 HP 배율 적용
	var hp_mult: float = StageManager.current_stage_data.get("robot_hp_mult", 1.0)
	data["hp"] = int(data.get("hp", 50) * hp_mult)
	get_parent().add_child(robot)
	robot.setup(data)
