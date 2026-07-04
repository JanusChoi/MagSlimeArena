extends Control

@onready var _start_button: Button = $Layer/Root/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.mouse_entered.connect(_on_start_hover.bind(true))
	_start_button.mouse_exited.connect(_on_start_hover.bind(false))


func _on_start_pressed() -> void:
	GameSession.start_new_match()
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")


func _on_start_hover(entered: bool) -> void:
	_start_button.scale = Vector2(1.06, 1.06) if entered else Vector2.ONE
