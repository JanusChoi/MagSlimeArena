extends Node
## 屏幕固定岩浆：顶边为液面；进入预警带会「发烫」，深没即淘汰。

signal player_eliminated(fallen_player_id: int, winner_id: int)

@export var player_radius: float = 36.0
@export var warning_margin: float = 110.0
@export var burn_seconds: float = 0.28
## 脚深入液面超过此值立即淘汰（防止钩出 lava）
@export var instant_kill_depth: float = 52.0

var _camera: Camera2D
var _player1: Node2D
var _player2: Node2D
var _round_over: bool = false
var _p1_burn: float = 0.0
var _p2_burn: float = 0.0


func setup(camera: Camera2D, player1: Node2D, player2: Node2D) -> void:
	_camera = camera
	_player1 = player1
	_player2 = player2


func reset_for_round() -> void:
	_round_over = false
	_p1_burn = 0.0
	_p2_burn = 0.0
	_apply_heat(_player1, 0.0)
	_apply_heat(_player2, 0.0)


func _physics_process(delta: float) -> void:
	if _round_over or _camera == null or GameSession.input_locked:
		return

	if _camera.has_method("is_scrolling") and not _camera.is_scrolling():
		_decay_all_heat(delta)
		return

	var surface_y: float = _camera.get_lava_surface_world_y()
	_process_player(_player1, 1, surface_y, delta)
	_process_player(_player2, 2, surface_y, delta)


func _process_player(player: Node2D, player_id: int, surface_y: float, delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_eliminated") and player.is_eliminated():
		return

	var feet_y := player.global_position.y + player_radius
	var depth := feet_y - surface_y
	var heat_ref := _burn_ref(player_id)

	if depth >= instant_kill_depth:
		_set_burn(player_id, 1.0)
		_apply_heat(player, 1.0)
		_eliminate(player)
		return

	if depth >= 0.0:
		heat_ref = minf(heat_ref + delta / maxf(burn_seconds, 0.05), 1.0)
		_set_burn(player_id, heat_ref)
		_apply_heat(player, heat_ref)
		if player.has_method("apply_lava_sink"):
			player.apply_lava_sink(heat_ref, depth, delta)
		if heat_ref >= 1.0:
			_eliminate(player)
		return

	if depth >= -warning_margin:
		var warn := clampf((depth + warning_margin) / warning_margin, 0.0, 1.0)
		heat_ref = lerpf(heat_ref, warn * 0.65, delta * 6.0)
	else:
		heat_ref = maxf(heat_ref - delta * 3.0, 0.0)

	_set_burn(player_id, heat_ref)
	_apply_heat(player, heat_ref)


func _decay_all_heat(delta: float) -> void:
	for pair in [[_player1, 1], [_player2, 2]]:
		var player: Node2D = pair[0]
		var id: int = pair[1]
		var heat := maxf(_burn_ref(id) - delta * 4.0, 0.0)
		_set_burn(id, heat)
		_apply_heat(player, heat)


func _burn_ref(player_id: int) -> float:
	return _p1_burn if player_id == 1 else _p2_burn


func _set_burn(player_id: int, value: float) -> void:
	if player_id == 1:
		_p1_burn = value
	else:
		_p2_burn = value


func _apply_heat(player: Node2D, heat: float) -> void:
	if player != null and player.has_method("set_lava_heat"):
		player.set_lava_heat(heat)


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
