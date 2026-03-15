# LevelUpPanel.gd
extends CanvasLayer

signal stat_selected(stat: Dictionary)

@onready var title_label: Label = $UIRoot/TitleLabel
@onready var options_container: HBoxContainer = $UIRoot/OptionsContainer

var stat_pool: Array = []
var current_options: Array = []

func _ready():
	_load_stat_pool()
	visible = false
	GameManager.level_up.connect(_on_level_up)

func _load_stat_pool():
	var file = FileAccess.open("res://data/stat_options.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		stat_pool = data["stats"]

func _on_level_up(new_level: int):
	title_label.text = "LEVEL %d !" % new_level
	_show_options()

func _show_options():
	get_tree().paused = true
	visible = true

	var shuffled = stat_pool.duplicate()
	shuffled.shuffle()
	current_options = shuffled.slice(0, 3)

	var buttons = options_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i]
		var stat = current_options[i]
		btn.text = "%s\n\n%s" % [stat["name"], stat["description"]]

		# 기존 연결 전부 끊기
		for connection in btn.pressed.get_connections():
			btn.pressed.disconnect(connection["callable"])

		# 새로 연결 (캡처 변수로 index 고정)
		var index = i
		btn.pressed.connect(func(): _on_option_selected(index))

func _on_option_selected(index: int):
	var selected = current_options[index]
	stat_selected.emit(selected)
	visible = false
	get_tree().paused = false
