# HUD.gd
extends CanvasLayer

@onready var weight_bar: ProgressBar = $UIRoot/WeightBar
@onready var weight_label: Label = $UIRoot/WeightLabel
@onready var currency_label: Label = $UIRoot/CurrencyLabel
@onready var game_over_panel: Panel = $UIRoot/GameOverPanel
@onready var warning_label: Label = $UIRoot/WarningLabel

func _ready():
	GameManager.weight_changed.connect(_on_weight_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.weight_stage_changed.connect(_on_weight_stage_changed)

	game_over_panel.visible = false
	warning_label.visible = false
	_update_weight(0.0, GameManager.MAX_WEIGHT)
	_on_currency_changed(0)

func _on_weight_changed(current: float, max_weight: float):
	_update_weight(current, max_weight)

func _update_weight(current: float, max_weight: float):
	weight_bar.max_value = max_weight
	weight_bar.value = current
	weight_label.text = "%d / %d" % [current, max_weight]

	var ratio = current / max_weight
	if ratio >= 0.9:
		weight_bar.modulate = Color(1, 0, 0)
	elif ratio >= 0.8:
		weight_bar.modulate = Color(1, 0.6, 0)
	else:
		weight_bar.modulate = Color(0, 0.8, 0)

func _on_weight_stage_changed(stage: String):
	match stage:
		"normal":
			warning_label.visible = false
		"warning":
			warning_label.text = "⚠ WARNING"
			warning_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
			warning_label.visible = true
		"danger":
			warning_label.text = "⚠ DANGER"
			warning_label.add_theme_color_override("font_color", Color(1, 0, 0))
			warning_label.visible = true

func _on_game_over():
	game_over_panel.visible = true

func _on_currency_changed(amount: int):
	currency_label.text = "💰 %d" % amount


func _on_restart_button_pressed() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()
