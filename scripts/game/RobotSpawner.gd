# RobotSpawner.gd
extends Node2D

@export var spawn_interval: float = 8.0
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
		robot_pool = data["robots"]

func _process(delta: float):
	if GameManager.is_game_over:
		return
	if get_tree().paused:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_robot()

func _spawn_robot():
	if robot_scene == null or robot_pool.is_empty():
		return

	var spawn_area = map.get_spawn_area()
	var robot = robot_scene.instantiate()
	var rand_x = randf_range(spawn_area["left"] + 30, spawn_area["right"] - 30)
	robot.position = Vector2(rand_x, -40)

	# 랜덤 로봇 타입 선택
	var data = robot_pool[randi() % robot_pool.size()]
	get_parent().add_child(robot)
	robot.setup(data)
