extends Node
## 屏幕固定岩浆：相机上滚时检测玩家是否落入屏幕下方岩浆区。

signal player_eliminated(fallen_player_id: int, winner_name: String)

@export var player_radius: float = 36.0

var _camera: Camera2D
var _player1: Node2D
var _player2: Node2D
var _game_over: bool = false


func setup(camera: Camera2D, player1: Node2D, player2: Node2D) -> void:
	_camera = camera
	_player1 = player1
	_player2 = player2


func _physics_process(_delta: float) -> void:
	if _game_over or _camera == null:
		return

	if _camera.has_method("is_scrolling") and not _camera.is_scrolling():
		return

	var surface_y: float = _camera.get_lava_surface_world_y()
	for player in [_player1, _player2]:
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("is_eliminated") and player.is_eliminated():
			continue
		if player.global_position.y + player_radius >= surface_y:
			_eliminate(player)


func _eliminate(player: Node2D) -> void:
	if _game_over:
		return
	_game_over = true

	var fallen_id: int = player.get("player_id") if player.get("player_id") != null else 0
	var winner_name := _get_winner_name(fallen_id)
	print("%s 被岩浆吞噬！" % _get_player_name(fallen_id))
	player_eliminated.emit(fallen_id, winner_name)
	_disable_player(player)
	print("%s 获胜！" % winner_name)

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()


func _disable_player(body: Node2D) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
		rb.freeze = true
		rb.collision_layer = 0
		rb.collision_mask = 0

	if body.has_method("set_eliminated"):
		body.set_eliminated()


func _get_player_name(player_id: int) -> String:
	match player_id:
		1:
			return "N-Pole (Player 1)"
		2:
			return "S-Pole (Player 2)"
		_:
			return "Player"


func _get_winner_name(fallen_player_id: int) -> String:
	match fallen_player_id:
		1:
			return "S-Pole (Player 2)"
		2:
			return "N-Pole (Player 1)"
		_:
			return "对手"
