extends Camera2D
## 分档上滚：默认固定视角；无尽模式解除终点线下限。

signal scroll_started

@export var follow_smoothing: float = 4.0
@export var lava_screen_fraction: float = 0.25
@export var start_delay: float = 12.0
@export var safe_margin_above_lava: float = 120.0
@export var step_scroll_amount: float = 380.0
@export var leader_top_margin: float = 80.0
@export var leader_reset_margin: float = 180.0
@export var leader_offscreen_chase: float = 40.0
@export var scroll_speed: float = 20.0

var _player1: Node2D
var _player2: Node2D
var _finish_y: float = 0.0
var _unbounded_climb: bool = false
var _scroll_active: bool = false
var _elapsed: float = 0.0
var _scroll_anchor_y: float = 0.0
var _base_cam_y: float = 2100.0
var _min_cam_y: float = 960.0
var _max_cam_y: float = 2100.0
var _can_trigger_next_step: bool = true
var _scroll_paused: bool = false


func pause_scroll(paused: bool) -> void:
	_scroll_paused = paused


func _ready() -> void:
	make_current()
	position.x = 540.0


func setup(player1: Node2D, player2: Node2D, spawn_leader_y: float, finish_y: float, unbounded: bool = false) -> void:
	_player1 = player1
	_player2 = player2
	_finish_y = finish_y
	_unbounded_climb = unbounded
	var half_viewport := get_viewport_rect().size.y * 0.5
	_max_cam_y = _spawn_camera_y(spawn_leader_y)
	_min_cam_y = half_viewport if unbounded else maxf(half_viewport, _spawn_camera_y(finish_y))
	_base_cam_y = _max_cam_y
	position.y = _base_cam_y


func is_scrolling() -> bool:
	return _scroll_active


func get_time_until_scroll() -> float:
	if _scroll_active:
		return 0.0
	return maxf(start_delay - _elapsed, 0.0)


func get_lava_surface_world_y() -> float:
	var half_viewport := get_viewport_rect().size.y * 0.5
	var lava_height := get_viewport_rect().size.y * lava_screen_fraction
	return global_position.y + half_viewport - lava_height


func get_lava_screen_fraction() -> float:
	return lava_screen_fraction


func get_leader_y() -> float:
	if _player1 == null or _player2 == null:
		return 0.0
	return minf(_player1.global_position.y, _player2.global_position.y)


func reset_for_round(player1: Node2D, player2: Node2D, spawn_leader_y: float, finish_y: float, unbounded: bool = false) -> void:
	_player1 = player1
	_player2 = player2
	_finish_y = finish_y
	_unbounded_climb = unbounded
	_scroll_active = false
	_elapsed = 0.0
	_can_trigger_next_step = true
	_scroll_paused = false
	var half_viewport := get_viewport_rect().size.y * 0.5
	_max_cam_y = _spawn_camera_y(spawn_leader_y)
	_min_cam_y = half_viewport if unbounded else maxf(half_viewport, _spawn_camera_y(finish_y))
	_base_cam_y = _max_cam_y
	_scroll_anchor_y = _base_cam_y
	position.y = _base_cam_y


func get_countdown_display() -> int:
	return int(ceil(get_time_until_scroll()))


func _process(delta: float) -> void:
	if _player1 == null or _player2 == null:
		return

	if _scroll_paused:
		return

	if not _scroll_active:
		_elapsed += delta
		if _elapsed >= start_delay:
			_scroll_active = true
			_scroll_anchor_y = position.y
			scroll_started.emit()

	var leader_y := minf(_player1.global_position.y, _player2.global_position.y)
	_update_leader_step(leader_y)

	var target_y := _base_cam_y
	if _scroll_active:
		_scroll_anchor_y -= scroll_speed * delta
		target_y = minf(_base_cam_y, _scroll_anchor_y)

	if _unbounded_climb:
		target_y = minf(target_y, _base_cam_y)
	else:
		target_y = clampf(target_y, _min_cam_y, _max_cam_y)
	position.y = lerpf(position.y, target_y, delta * follow_smoothing)


func _update_leader_step(leader_y: float) -> void:
	var half_viewport := get_viewport_rect().size.y * 0.5
	var top_world_y := position.y - half_viewport
	var trigger_y := top_world_y + leader_top_margin
	var reset_y := top_world_y + leader_reset_margin

	if leader_y > reset_y:
		_can_trigger_next_step = true

	if leader_y <= top_world_y - leader_offscreen_chase:
		var chase_y := _spawn_camera_y(leader_y)
		_base_cam_y = minf(_base_cam_y, chase_y)
		if not _unbounded_climb:
			_base_cam_y = maxf(_base_cam_y, _min_cam_y)
		return

	if not _can_trigger_next_step:
		return

	if leader_y <= trigger_y:
		_can_trigger_next_step = false
		_base_cam_y -= step_scroll_amount
		if not _unbounded_climb:
			_base_cam_y = maxf(_base_cam_y, _min_cam_y)


func _spawn_camera_y(leader_y: float) -> float:
	var half_viewport := get_viewport_rect().size.y * 0.5
	var lava_height := get_viewport_rect().size.y * lava_screen_fraction
	var player_below_center := half_viewport - lava_height - safe_margin_above_lava
	return leader_y - player_below_center
