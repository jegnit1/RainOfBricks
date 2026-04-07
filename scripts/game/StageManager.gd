# StageManager.gd
extends Node

signal stage_cleared
signal stage_started(stage_num: int)

var stage_data: Array = []
var current_stage: int = 1
var current_stage_data: Dictionary = {}

var total_bricks: int = 0
var spawned_bricks: int = 0
var destroyed_bricks: int = 0

func _ready():
	_load_stage_data()

func _load_stage_data():
	var file = FileAccess.open("res://data/stages.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Array:
			stage_data = data
		elif data is Dictionary:
			stage_data = data.get("stages", [])

func get_stage_data(stage_num: int) -> Dictionary:
	for s in stage_data:
		if s["stage"] == stage_num:
			return s
	# 마지막 스테이지 데이터 반복 사용
	return stage_data[stage_data.size() - 1]

func start_stage(stage_num: int):
	current_stage = stage_num
	current_stage_data = get_stage_data(stage_num)
	total_bricks = current_stage_data.get("brick_count", 20)
	spawned_bricks = 0
	destroyed_bricks = 0
	GameManager.set_max_weight(current_stage_data.get("max_weight", 100))
	stage_started.emit(stage_num)

func on_brick_spawned():
	spawned_bricks += 1
	if spawned_bricks >= total_bricks:
		stage_cleared.emit()

func is_spawn_complete() -> bool:
	return spawned_bricks >= total_bricks
