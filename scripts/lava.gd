extends Node
## Screen-fixed lava hazard: eliminates players below the lava surface while scrolling.

signal player_eliminated(fallen_player_id: int, winner_id: int)

@export var player_radius: float = 36.0

var _camera: Camera2D
var _player1: Node2D
var _player2: Node2D
var _round_over: bool = false


func setup(camera: Camera2D, player1: Node2D, player2: Node2D) -> void:
	_camera = camera
	_player1 = player1
	_player2 = player2


func reset_for_round() -> void:
	_round_over = false


func _physics_process(_delta: float) -> void:
	if _round_over or _camera == null or GameSession.input_locked:
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
	if _round_over:
		return
	_round_over = true

	var fallen_id: int = player.get("player_id") if player.get("player_id") != null else 0
	var winner_id := 2 if fallen_id == 1 else 1
	_disable_player(player)
	player_eliminated.emit(fallen_id, winner_id)


func _disable_player(body: Node2D) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
		rb.freeze = true
	if body.has_method("set_eliminated"):
		body.set_eliminated()
