extends Control

@onready var _level_btn: Button = $Layer/Root/LevelModeButton
@onready var _endless_btn: Button = $Layer/Root/EndlessModeButton


func _ready() -> void:
	_level_btn.pressed.connect(_on_level_pressed)
	_endless_btn.pressed.connect(_on_endless_pressed)
	_level_btn.mouse_entered.connect(_on_btn_hover.bind(_level_btn, true))
	_level_btn.mouse_exited.connect(_on_btn_hover.bind(_level_btn, false))
	_endless_btn.mouse_entered.connect(_on_btn_hover.bind(_endless_btn, true))
	_endless_btn.mouse_exited.connect(_on_btn_hover.bind(_endless_btn, false))
	call_deferred("_ensure_bgm")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_ensure_bgm()
	elif event is InputEventKey and event.pressed and not event.echo:
		_ensure_bgm()


func _ensure_bgm() -> void:
	GameAudio.ensure_bgm_playing()


func _on_level_pressed() -> void:
	_ensure_bgm()
	GameSession.start_level_match()
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")


func _on_endless_pressed() -> void:
	_ensure_bgm()
	GameSession.start_endless_match()
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")


func _on_btn_hover(btn: Button, entered: bool) -> void:
	btn.scale = Vector2(1.06, 1.06) if entered else Vector2.ONE
