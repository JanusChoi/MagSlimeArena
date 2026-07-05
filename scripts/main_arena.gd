extends Node2D
class_name MainArena
## 主竞技场：左右交替平台、终点线、屏幕固定岩浆 + 世界上滚。

enum MagnetGameplay {
	CLASSIC_HOLD,
	ANCHOR_IMPULSE_ONE_SHOT,
}

const ARENA_WIDTH := 1080.0
const LEVEL_COUNT := 11
const PLAYER_STAND_OFFSET := 48.0
const PLATFORM_BASE_HALF_WIDTH := 100.0
const FINISH_LINE_ABOVE_TOP := 100.0

@export_group("Arena Layout")
@export var arena_height: float = 4000.0
@export var start_platform_y: float = 3000.0

## 极端测试：仅出生台 + 垂直锚点链（Inspector 可关）
@export var anchor_only_climb_test: bool = true

@export_group("Magnet Gameplay")
@export var magnet_gameplay: MagnetGameplay = MagnetGameplay.ANCHOR_IMPULSE_ONE_SHOT
@export var magnet_affects_players: bool = false
## 模型2：F/Shift 只打锚点，G/Option 专打对手（与 magnet_affects_players 互斥）
@export var pvp_dual_key_impulse: bool = true

@export_group("Anchor Impulse (one-shot F/Shift)")
@export var impulse_max_range: float = 520.0
@export var impulse_attract_speed: float = 1960.0
@export var impulse_repel_speed: float = 840.0
@export var impulse_up_bias: float = 0.48
@export var impulse_distance_bonus: float = 0.35

@export_group("Player Impulse (dual-key G / Option · sabotage hook)")
@export var player_impulse_max_range: float = 1024.0
@export var player_impulse_attract_speed: float = 980.0
@export var player_impulse_up_bias: float = 0.22
@export var player_impulse_distance_bonus: float = 0.5
@export var player_impulse_cooldown: float = 0.5
## 对手被拽向钩人者的速度倍率（主效果）
@export var player_hook_target_speed_scale: float = 1.0
## 钩人者自身被吸向对手的速度倍率（副效果，宜明显弱于 target）
@export var player_hook_self_speed_scale: float = 0.22
## 对手在上方时，额外加强向下拽的分量（领先者被拉回危险区）
@export var player_hook_target_down_bias: float = 0.35

@export_group("Guaranteed Routes")
@export var route_vert_step: float = 360.0
@export var route_horiz_zigzag: float = 110.0
@export var route_top_y: float = 480.0
## 主路线旁零星异色锚：数量 ≤ 该侧主锚 × 此比例（0.5 = 一半）
@export var scatter_opposite_ratio: float = 0.5
@export var scatter_min_separation: float = 72.0

const ROUTE_REACH_SAFETY := 0.86
const P1_ROUTE_LANE_X := LEFT_LANE_X
const P2_ROUTE_LANE_X := RIGHT_LANE_X

const PLATFORM_SCENE := preload("res://scenes/platform.tscn")
const ANCHOR_SCENE := preload("res://scenes/magnetic_anchor.tscn")

const MIN_VERT_STEP := 168.0
const MAX_VERT_STEP := 188.0
const ANCHOR_COUNT_MIN := 5
const ANCHOR_COUNT_MAX := 8
const SPAWN_PLATFORM_SCALE_MIN := 3.1
const SPAWN_PLATFORM_SCALE_MAX := 3.9
const MIN_PLATFORM_SCALE := 1.35
const MAX_PLATFORM_SCALE := 2.85
const LEFT_LANE_X := 330.0
const RIGHT_LANE_X := 750.0
const CENTER_LANE_X := 540.0
const LANE_JITTER := 35.0
const P1_SPAWN_X := 420.0
const P2_SPAWN_X := 660.0
const SPAWN_HEAD_CLEARANCE := 55.0
const SPAWN_PROTECTED_LEVELS := 2
const WALL_INNER_LEFT := 120.0
const WALL_INNER_RIGHT := 960.0
const WALL_TUCK_MARGIN := 20.0

enum ArenaSide { LEFT = -1, CENTER = 0, RIGHT = 1 }

@onready var _platforms: Node2D = $Platforms
@onready var _anchors: Node2D = $Anchors
@onready var _hazard: Node = $ScrollHazard
@onready var _finish_line: Node2D = $FinishLine
@onready var _score_p1: Label = $HUD/ScoreP1
@onready var _score_p2: Label = $HUD/ScoreP2
@onready var _round_label: Label = $HUD/RoundLabel
@onready var _countdown_label: Label = $HUD/CountdownLabel
@onready var _endless_countdown_label: Label = $HUD/EndlessCountdownLabel
@onready var _controls_hint_p1: Label = $HUD/ControlsHintP1
@onready var _controls_hint_p2: Label = $HUD/ControlsHintP2
@onready var _round_banner: Label = $HUD/RoundBanner
@onready var _lava_visual: Control = $HUD/LavaOverlay
@onready var _match_result: CanvasLayer = $MatchResult
@onready var _match_winner: Label = $MatchResult/Panel/MatchWinner
@onready var _match_score: Label = $MatchResult/Panel/MatchScore
@onready var _play_again_btn: Button = $MatchResult/Panel/PlayAgainButton
@onready var _menu_btn: Button = $MatchResult/Panel/MenuButton
@onready var _arena_camera: Camera2D = $ArenaCamera
@onready var _player1: SlimePlayer = $Player1
@onready var _player2: SlimePlayer = $Player2
@onready var _background: Node2D = $Background
@onready var _left_wall: StaticBody2D = $LeftWall
@onready var _right_wall: StaticBody2D = $RightWall
@onready var _hook_fx: Node = $HookImpactFx
@onready var _hp_p1: Label = $HUD/HPP1
@onready var _hp_p2: Label = $HUD/HPP2
@onready var _endless_chunks: Node = $EndlessChunks
@onready var _pickup_spawner: Node = $PickupSpawner
@onready var _pickups: Node2D = $Pickups
@onready var _portals: Node2D = $Portals

var _spawn_player_y: float = 2952.0
var _platform_centers: Array[Vector2] = []
var _platform_scales: Array[float] = []
var _placed_anchor_positions: Array[Vector2] = []
var _round_over: bool = false
var _endless_respawn_busy: bool = false


func _ready() -> void:
	_match_result.visible = false
	_round_banner.visible = false
	_play_again_btn.pressed.connect(_on_play_again)
	_menu_btn.pressed.connect(_on_menu)
	_arena_camera.scroll_started.connect(_on_scroll_started)
	_bootstrap_arena()


func _process(_delta: float) -> void:
	if _round_over or GameSession.input_locked:
		return
	if GameSession.is_level():
		_finish_line.check_players(_player1, _player2)
	_update_countdown_hud()


func _is_endless() -> bool:
	return GameSession.is_endless()


func _bootstrap_arena() -> void:
	_round_over = false
	_endless_respawn_busy = false
	GameSession.set_input_locked(false)
	_sync_arena_geometry()
	_build_staircase()
	if _is_endless():
		_clear_anchors()
		_placed_anchor_positions.clear()
	else:
		_build_scattered_anchors()
	if _is_endless():
		_finish_line.visible = false
		if _endless_chunks.has_method("reset_for_match"):
			_endless_chunks.reset_for_match(self, _arena_camera, start_platform_y - PLAYER_STAND_OFFSET)
		if _pickup_spawner.has_method("clear_all"):
			_pickup_spawner.clear_all()
		for child in _portals.get_children():
			child.queue_free()
	else:
		_finish_line.visible = true
		_setup_finish_line()
		_finish_line.reset()
	_spawn_player_y = start_platform_y - PLAYER_STAND_OFFSET
	var finish_y: float = _finish_line.finish_y if GameSession.is_level() else -1.0e9
	_arena_camera.reset_for_round(_player1, _player2, _spawn_player_y, finish_y, _is_endless())
	_place_players()
	if _hazard.has_method("reset_for_round"):
		_hazard.reset_for_round()
	_hazard.setup(_arena_camera, _player1, _player2)
	_connect_hazard_signals()
	if _lava_visual and _lava_visual.has_method("set_scroll_active"):
		_lava_visual.set_scroll_active(false)
	if GameSession.is_level():
		_connect_finish_signal(true)
	else:
		_connect_finish_signal(false)
	if _hook_fx and _hook_fx.has_method("setup"):
		_hook_fx.setup(_arena_camera)
	if _hook_fx and _hook_fx.has_method("reset_for_round"):
		_hook_fx.reset_for_round()
	if _pickup_spawner.has_method("setup"):
		_pickup_spawner.setup(self, _pickups)
	_apply_mode_hud()


func _clear_anchors() -> void:
	for child in _anchors.get_children():
		child.queue_free()


func _connect_hazard_signals() -> void:
	if _hazard.player_eliminated.is_connected(_on_round_lost_by_lava):
		_hazard.player_eliminated.disconnect(_on_round_lost_by_lava)
	if _hazard.player_lava_damaged.is_connected(_on_endless_lava_hit):
		_hazard.player_lava_damaged.disconnect(_on_endless_lava_hit)
	if GameSession.is_level():
		_hazard.player_eliminated.connect(_on_round_lost_by_lava)
	else:
		_hazard.player_lava_damaged.connect(_on_endless_lava_hit)


func _connect_finish_signal(enabled: bool) -> void:
	if _finish_line.player_crossed.is_connected(_on_round_won_by_finish):
		_finish_line.player_crossed.disconnect(_on_round_won_by_finish)
	if enabled:
		_finish_line.player_crossed.connect(_on_round_won_by_finish)


func _apply_mode_hud() -> void:
	var endless := _is_endless()
	if _score_p1:
		_score_p1.visible = not endless
	if _score_p2:
		_score_p2.visible = not endless
	if _round_label:
		_round_label.visible = not endless
	if _hp_p1:
		_hp_p1.visible = endless
	if _hp_p2:
		_hp_p2.visible = endless
	if endless:
		_refresh_hp_hud()
	else:
		_refresh_score_hud()


func trigger_hook_impact(pull_direction: Vector2) -> void:
	if _hook_fx and _hook_fx.has_method("trigger"):
		_hook_fx.trigger(pull_direction)


func _sync_arena_geometry() -> void:
	var wall_center_y := arena_height * 0.5
	for wall in [_left_wall, _right_wall]:
		if wall == null:
			continue
		wall.position.y = wall_center_y
		var shape_node := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			(shape_node.shape as RectangleShape2D).size.y = arena_height

	if _background != null and _background.has_method("configure_spawn"):
		_background.configure_spawn(start_platform_y - PLAYER_STAND_OFFSET)


func _build_staircase() -> void:
	for child in _platforms.get_children():
		child.queue_free()

	_platform_centers.clear()
	_platform_scales.clear()

	if anchor_only_climb_test:
		_build_spawn_platform_only()
		return

	var prev_x := 540.0
	var prev_y := start_platform_y
	var prev_scale := randf_range(SPAWN_PLATFORM_SCALE_MIN, SPAWN_PLATFORM_SCALE_MAX)
	var prev_side := ArenaSide.CENTER
	var next_side := ArenaSide.RIGHT if randf() > 0.5 else ArenaSide.LEFT

	for i in LEVEL_COUNT:
		var platform: StaticBody2D = PLATFORM_SCENE.instantiate()
		var y: float
		var x: float
		var scale_x: float
		var side: ArenaSide = ArenaSide.CENTER

		if i == 0:
			x = CENTER_LANE_X
			y = start_platform_y
			scale_x = prev_scale
			side = ArenaSide.CENTER
		else:
			if i == 1:
				var placement := _spawn_safe_jump_platform(prev_x, prev_y, prev_scale, ArenaSide.CENTER)
				x = placement.x
				y = placement.y
				scale_x = placement.scale
				side = placement.side
			else:
				side = next_side
				if i % 6 == 3:
					side = ArenaSide.CENTER
				else:
					next_side = ArenaSide.RIGHT if next_side == ArenaSide.LEFT else ArenaSide.LEFT

				var placement := _pick_platform_placement(prev_x, prev_y, prev_scale, prev_side, side, i)
				x = placement.x
				y = placement.y
				scale_x = placement.scale
				side = placement.side

				if i <= SPAWN_PROTECTED_LEVELS and _overlaps_spawn_headroom(x, scale_x):
					var safe := _spawn_safe_jump_platform(prev_x, prev_y, prev_scale, prev_side)
					x = safe.x
					y = safe.y
					scale_x = safe.scale
					side = safe.side

		platform.position = Vector2(x, y)
		platform.min_scale_x = scale_x
		platform.max_scale_x = scale_x
		_platforms.add_child(platform)
		_platform_centers.append(Vector2(x, y))
		_platform_scales.append(scale_x)

		prev_x = x
		prev_y = y
		prev_scale = scale_x
		prev_side = side


func _build_spawn_platform_only() -> void:
	var scale_x := randf_range(SPAWN_PLATFORM_SCALE_MIN, SPAWN_PLATFORM_SCALE_MAX)
	var platform: StaticBody2D = PLATFORM_SCENE.instantiate()
	platform.position = Vector2(CENTER_LANE_X, start_platform_y)
	platform.min_scale_x = scale_x
	platform.max_scale_x = scale_x
	_platforms.add_child(platform)
	_platform_centers.append(Vector2(CENTER_LANE_X, start_platform_y))
	_platform_scales.append(scale_x)


func _setup_finish_line() -> void:
	var top_y: float
	if anchor_only_climb_test:
		if _anchors.get_child_count() == 0:
			return
		top_y = INF
		for child in _anchors.get_children():
			top_y = minf(top_y, child.position.y)
	else:
		if _platform_centers.is_empty():
			return
		top_y = _platform_centers[_platform_centers.size() - 1].y
	var finish_y := top_y - FINISH_LINE_ABOVE_TOP
	_finish_line.setup(finish_y)


func _spawn_safe_jump_platform(
	prev_x: float, prev_y: float, prev_scale: float, avoid_side: int
) -> Dictionary:
	var side := ArenaSide.LEFT if randf() > 0.5 else ArenaSide.RIGHT
	if avoid_side == ArenaSide.LEFT:
		side = ArenaSide.RIGHT
	elif avoid_side == ArenaSide.RIGHT:
		side = ArenaSide.LEFT

	var scale_x := _max_wall_scale_for_spawn_clearance()
	var x := _wall_tuck_x(side, scale_x)
	var y := prev_y - randf_range(MIN_VERT_STEP, MAX_VERT_STEP)
	if not _is_placement_valid(prev_x, prev_y, prev_scale, x, y, scale_x, 1):
		y = prev_y - MAX_VERT_STEP
	return {"x": x, "y": y, "scale": scale_x, "side": side, "score": 100.0}


func _max_wall_scale_for_spawn_clearance() -> float:
	var p1_limit := P1_SPAWN_X - SPAWN_HEAD_CLEARANCE - WALL_INNER_LEFT - WALL_TUCK_MARGIN
	var p2_limit := WALL_INNER_RIGHT - WALL_TUCK_MARGIN - (P2_SPAWN_X + SPAWN_HEAD_CLEARANCE)
	var max_half := minf(p1_limit, p2_limit) * 0.5
	return clampf(max_half / PLATFORM_BASE_HALF_WIDTH, 0.85, MIN_PLATFORM_SCALE)


func _wall_tuck_x(side: int, scale_x: float) -> float:
	var half := _half_width(scale_x)
	if side == ArenaSide.LEFT:
		return WALL_INNER_LEFT + half + WALL_TUCK_MARGIN
	return WALL_INNER_RIGHT - half - WALL_TUCK_MARGIN


func _pick_platform_placement(
	prev_x: float, prev_y: float, prev_scale: float, prev_side: int, preferred_side: int, level_index: int
) -> Dictionary:
	var sides_to_try: Array[int] = [preferred_side]
	if preferred_side != ArenaSide.LEFT:
		sides_to_try.append(ArenaSide.LEFT)
	if preferred_side != ArenaSide.RIGHT:
		sides_to_try.append(ArenaSide.RIGHT)
	if preferred_side != ArenaSide.CENTER:
		sides_to_try.append(ArenaSide.CENTER)

	var best := _forced_lane_placement(prev_x, prev_y, prev_scale, preferred_side, level_index)

	for side in sides_to_try:
		for _attempt in 10:
			var vert_step := randf_range(MIN_VERT_STEP, MAX_VERT_STEP)
			var y := prev_y - vert_step
			var scale_x := randf_range(MIN_PLATFORM_SCALE, MAX_PLATFORM_SCALE)
			var x := _lane_x_for_side(side, scale_x, level_index)

			if side != ArenaSide.CENTER and prev_side != ArenaSide.CENTER and side == prev_side:
				continue

			if not _is_placement_valid(prev_x, prev_y, prev_scale, x, y, scale_x, level_index):
				continue

			var score := _score_placement(prev_x, x, vert_step, scale_x, side)
			if score > best.score:
				best = {"x": x, "y": y, "scale": scale_x, "side": side, "score": score}

	return best


func _forced_lane_placement(prev_x: float, prev_y: float, prev_scale: float, side: int, level_index: int) -> Dictionary:
	var opposite := ArenaSide.RIGHT if side == ArenaSide.LEFT else ArenaSide.LEFT
	var use_side := opposite if side == ArenaSide.CENTER else side
	var scale_x := randf_range(MIN_PLATFORM_SCALE, MAX_PLATFORM_SCALE)
	var x := _lane_x_for_side(use_side, scale_x, level_index)
	var y := prev_y - MIN_VERT_STEP
	if not _is_placement_valid(prev_x, prev_y, prev_scale, x, y, scale_x, level_index):
		y = prev_y - MAX_VERT_STEP
	return {"x": x, "y": y, "scale": scale_x, "side": use_side, "score": -INF}


func _lane_x_for_side(side: int, scale_x: float, _level_index: int = -1) -> float:
	var half := _half_width(scale_x)
	var jitter := randf_range(-LANE_JITTER, LANE_JITTER)

	match side:
		ArenaSide.LEFT:
			return clampf(LEFT_LANE_X + jitter, 120.0 + half, CENTER_LANE_X - half * 0.35)
		ArenaSide.RIGHT:
			return clampf(RIGHT_LANE_X + jitter, CENTER_LANE_X + half * 0.35, 960.0 - half)
		_:
			return clampf(CENTER_LANE_X + jitter * 0.5, 120.0 + half, 960.0 - half)


func _half_width(scale_x: float) -> float:
	return PLATFORM_BASE_HALF_WIDTH * scale_x


func _is_placement_valid(
	prev_x: float, prev_y: float, prev_scale: float,
	x: float, y: float, scale_x: float, level_index: int = -1
) -> bool:
	var vert_step := prev_y - y
	if vert_step < MIN_VERT_STEP - 2.0:
		return false

	if level_index >= 1 and level_index <= SPAWN_PROTECTED_LEVELS:
		if _overlaps_spawn_headroom(x, scale_x):
			return false

	var prev_half := _half_width(prev_scale)
	var half := _half_width(scale_x)
	var overlap := _overlap_amount(prev_x, prev_half, x, half)

	if overlap > 60.0 and vert_step < 125.0:
		return false
	if overlap > 120.0 and vert_step < 138.0:
		return false

	if absf(x - prev_x) < 160.0 and overlap > 20.0:
		return false

	return true


func _overlaps_spawn_headroom(x: float, scale_x: float) -> bool:
	var half := _half_width(scale_x)
	var p1_overlap := _overlap_amount(P1_SPAWN_X, SPAWN_HEAD_CLEARANCE, x, half)
	var p2_overlap := _overlap_amount(P2_SPAWN_X, SPAWN_HEAD_CLEARANCE, x, half)
	return p1_overlap > 0.0 or p2_overlap > 0.0


func _overlap_amount(ax: float, a_half: float, bx: float, b_half: float) -> float:
	var left := maxf(ax - a_half, bx - b_half)
	var right := minf(ax + a_half, bx + b_half)
	return maxf(right - left, 0.0)


func _score_placement(prev_x: float, x: float, vert_step: float, _scale_x: float, side: int) -> float:
	var horiz := absf(x - prev_x)
	var score := horiz * 0.6
	score += clampf(vert_step, MIN_VERT_STEP, MAX_VERT_STEP) * 0.25
	if side != ArenaSide.CENTER:
		score += 40.0
	if horiz >= 280.0:
		score += 50.0
	return score


func append_route_chunk(row_count: int, prev_p1: Vector2, prev_p2: Vector2, chunk_index: int) -> Dictionary:
	var vert_step := _effective_route_vert_step()
	var max_reach := impulse_max_range * ROUTE_REACH_SAFETY
	var highest_y := prev_p1.y
	var scatter_positions: Array[Vector2] = []
	var route_ys: Array[float] = []

	for i in row_count:
		var row := chunk_index * row_count + i
		var y := prev_p1.y - vert_step
		route_ys.append(y)
		var p1_x := P1_ROUTE_LANE_X + (route_horiz_zigzag if row % 2 == 0 else -route_horiz_zigzag * 0.45)
		var p2_x := P2_ROUTE_LANE_X + (route_horiz_zigzag if row % 2 == 1 else -route_horiz_zigzag * 0.45)
		var pos_p1 := Vector2(clampf(p1_x, 240.0, 470.0), y)
		var pos_p2 := Vector2(clampf(p2_x, 610.0, 840.0), y - vert_step * 0.22)
		pos_p1 = _clamp_anchor_to_reach(prev_p1, pos_p1, max_reach)
		pos_p2 = _clamp_anchor_to_reach(prev_p2, pos_p2, max_reach)
		_place_route_anchor(pos_p1, false)
		_place_route_anchor(pos_p2, true)
		scatter_positions.append(pos_p1)
		scatter_positions.append(pos_p2)
		prev_p1 = pos_p1
		prev_p2 = pos_p2
		highest_y = minf(highest_y, y)

	_scatter_opposite_lane_anchors(route_ys, row_count, vert_step)
	for pos in _placed_anchor_positions:
		if pos.y <= highest_y + vert_step:
			scatter_positions.append(pos)

	return {
		"prev_p1": prev_p1,
		"prev_p2": prev_p2,
		"highest_y": highest_y,
		"scatter_positions": scatter_positions,
	}


func on_endless_chunk_spawned(result: Dictionary) -> void:
	if _pickup_spawner.has_method("on_chunk_spawned"):
		_pickup_spawner.on_chunk_spawned(result)


func _on_endless_lava_hit(player_id: int) -> void:
	if _round_over or _endless_respawn_busy:
		return
	_begin_endless_respawn_sequence(player_id)


func _begin_endless_respawn_sequence(player_id: int) -> void:
	_endless_respawn_busy = true
	var player := _player1 if player_id == 1 else _player2
	if player == null:
		_endless_respawn_busy = false
		return

	GameSession.set_input_locked(true)
	_set_players_frozen(true)
	if _arena_camera.has_method("pause_scroll"):
		_arena_camera.pause_scroll(true)

	if player is RigidBody2D:
		var body := player as RigidBody2D
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0

	var still_alive := GameSession.take_lava_damage(player_id)
	_refresh_hp_hud()

	await _show_endless_fall_banner(player_id, still_alive)

	if _round_over:
		return

	if not still_alive:
		_endless_respawn_busy = false
		if _arena_camera.has_method("pause_scroll"):
			_arena_camera.pause_scroll(false)
		_set_players_frozen(false)
		_end_endless_game(2 if player_id == 1 else 1)
		return

	_respawn_player_above_lava(player_id, false)
	_set_players_frozen(true)
	await _run_endless_resume_countdown()

	if _round_over:
		return

	_cleanup_endless_respawn_freeze()
	_begin_respawn_protection(player_id)
	_launch_respawned_player(player_id)
	_endless_respawn_busy = false


func _set_players_frozen(frozen: bool) -> void:
	for player in [_player1, _player2]:
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("is_eliminated") and player.is_eliminated():
			continue
		if player is RigidBody2D:
			var body := player as RigidBody2D
			body.freeze = frozen
			if frozen:
				body.linear_velocity = Vector2.ZERO
				body.angular_velocity = 0.0


func _show_endless_fall_banner(player_id: int, still_alive: bool) -> void:
	if _countdown_label:
		_countdown_label.visible = false
	if _endless_countdown_label:
		_endless_countdown_label.visible = false
	if _round_banner:
		if still_alive:
			_round_banner.text = "%s FELL!  %s" % [
				GameSession.player_tag(player_id),
				GameSession.hp_hearts(player_id),
			]
		else:
			_round_banner.text = "%s OUT!" % GameSession.player_tag(player_id)
		_round_banner.visible = true
	await get_tree().create_timer(1.2).timeout
	if _round_banner:
		_round_banner.visible = false


func _run_endless_resume_countdown() -> void:
	var label := _endless_countdown_label if _endless_countdown_label else _countdown_label
	if label == null:
		await get_tree().create_timer(3.0).timeout
		return
	if _countdown_label and label != _countdown_label:
		_countdown_label.visible = false
	for i in [3, 2, 1]:
		if _round_over:
			return
		label.text = str(i)
		label.visible = true
		await get_tree().create_timer(1.0).timeout
	label.visible = false


func _hide_endless_countdown() -> void:
	if _endless_countdown_label:
		_endless_countdown_label.visible = false
	if _countdown_label:
		_countdown_label.visible = false


func _launch_respawned_player(player_id: int) -> void:
	var player := _player1 if player_id == 1 else _player2
	if player is RigidBody2D:
		var body := player as RigidBody2D
		body.sleeping = false
		body.linear_velocity = Vector2(0.0, -720.0)


func _begin_respawn_protection(player_id: int) -> void:
	var player := _player1 if player_id == 1 else _player2
	if player == null:
		return
	var invuln := 2.0
	var grace := 2.5
	if _hazard != null:
		invuln = _hazard.endless_respawn_invuln
		grace = maxf(invuln + 0.5, _hazard.endless_hit_cooldown)
	if player.has_method("start_respawn_invuln"):
		player.start_respawn_invuln(invuln, true)
	if _hazard.has_method("reset_player_after_respawn"):
		_hazard.reset_player_after_respawn(player_id, grace)


func _cleanup_endless_respawn_freeze() -> void:
	_set_players_frozen(false)
	if _arena_camera.has_method("pause_scroll"):
		_arena_camera.pause_scroll(false)
	GameSession.set_input_locked(false)
	_hide_endless_countdown()


func _respawn_player_above_lava(player_id: int, apply_launch_velocity: bool = true) -> void:
	var player := _player1 if player_id == 1 else _player2
	if player == null:
		return
	var surface_y: float = _arena_camera.get_lava_surface_world_y()
	var view_h := get_viewport_rect().size.y
	var respawn_y := surface_y - view_h * 0.35
	var spawn_x := P1_SPAWN_X if player_id == 1 else P2_SPAWN_X
	player.global_position = Vector2(spawn_x, respawn_y)
	var hold_frozen := not apply_launch_velocity
	if player.has_method("reset_for_respawn"):
		player.reset_for_respawn(hold_frozen)
	if player is RigidBody2D:
		var body := player as RigidBody2D
		body.sleeping = false
		if apply_launch_velocity:
			body.freeze = false
			body.linear_velocity = Vector2(0.0, -720.0)
		else:
			body.linear_velocity = Vector2.ZERO
			body.freeze = true
	if apply_launch_velocity:
		var invuln := 2.0
		var grace := 2.5
		if _hazard != null:
			invuln = _hazard.endless_respawn_invuln
			grace = maxf(invuln + 0.5, _hazard.endless_hit_cooldown)
		if player.has_method("start_respawn_invuln"):
			player.start_respawn_invuln(invuln)
		if _hazard.has_method("reset_player_after_respawn"):
			_hazard.reset_player_after_respawn(player_id, grace)


func _end_endless_game(winner_id: int) -> void:
	if _round_over:
		return
	_round_over = true
	_endless_respawn_busy = false
	if _arena_camera.has_method("pause_scroll"):
		_arena_camera.pause_scroll(false)
	GameSession.set_input_locked(true)
	if _hazard.has_method("set_round_over"):
		_hazard.set_round_over(true)
	var loser_id := 2 if winner_id == 1 else 1
	var loser := _player1 if loser_id == 1 else _player2
	if loser != null and loser.has_method("set_eliminated"):
		loser.set_eliminated()
	for player in [_player1, _player2]:
		if player is RigidBody2D:
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0
	_show_endless_result(winner_id)


func _show_endless_result(winner_id: int) -> void:
	if _match_winner:
		_match_winner.text = "%s WINS" % GameSession.player_tag(winner_id)
	if _match_score:
		_match_score.text = GameSession.get_score_label()
	_match_result.visible = true


func _refresh_hp_hud() -> void:
	if _hp_p1:
		_hp_p1.text = GameSession.hp_hearts(1)
	if _hp_p2:
		_hp_p2.text = GameSession.hp_hearts(2)


func _build_scattered_anchors() -> void:
	for child in _anchors.get_children():
		child.queue_free()

	if anchor_only_climb_test:
		_build_guaranteed_player_routes()
		return

	if _platform_centers.size() < 4:
		return

	var candidates: Array[Vector2] = []
	for i in range(1, _platform_centers.size() - 1):
		var lower := _platform_centers[i]
		var upper := _platform_centers[i + 1]
		var mid := (lower + upper) * 0.5
		if randf() < 0.55:
			mid.x = randf_range(420.0, 660.0)
		else:
			mid.x = LEFT_LANE_X if randf() > 0.5 else RIGHT_LANE_X
			mid.x += randf_range(-80.0, 80.0)
		mid.y -= randf_range(10.0, 45.0)
		mid.x = clampf(mid.x, 200.0, 880.0)
		candidates.append(mid)

	candidates.shuffle()
	var count := mini(randi_range(ANCHOR_COUNT_MIN, ANCHOR_COUNT_MAX), candidates.size())
	var polarities := _balanced_polarities(count)

	for j in count:
		var pos: Vector2 = candidates[j]
		var anchor: Node2D = ANCHOR_SCENE.instantiate()
		anchor.position = pos
		anchor.set("wall_side", 0)
		anchor.set("is_north_pole", polarities[j])
		_anchors.add_child(anchor)


func _balanced_polarities(count: int) -> Array[bool]:
	var half := count >> 1
	var flags: Array[bool] = []
	for i in count:
		flags.append(i < half)
	flags.shuffle()
	return flags


func _build_guaranteed_player_routes() -> void:
	if _platform_centers.is_empty():
		return

	_placed_anchor_positions.clear()
	var base_y := _platform_centers[0].y
	var vert_step := _effective_route_vert_step()
	var anchor_count := _route_anchor_count(base_y, vert_step)
	var max_reach := impulse_max_range * ROUTE_REACH_SAFETY
	var prev_p1 := Vector2(P1_SPAWN_X, _spawn_player_y)
	var prev_p2 := Vector2(P2_SPAWN_X, _spawn_player_y)
	var route_ys: Array[float] = []

	for i in anchor_count:
		var y := base_y - float(i + 1) * vert_step
		route_ys.append(y)
		var p1_x := P1_ROUTE_LANE_X + (route_horiz_zigzag if i % 2 == 0 else -route_horiz_zigzag * 0.45)
		var p2_x := P2_ROUTE_LANE_X + (route_horiz_zigzag if i % 2 == 1 else -route_horiz_zigzag * 0.45)
		var pos_p1 := Vector2(clampf(p1_x, 240.0, 470.0), y)
		var pos_p2 := Vector2(clampf(p2_x, 610.0, 840.0), y - vert_step * 0.22)

		pos_p1 = _clamp_anchor_to_reach(prev_p1, pos_p1, max_reach)
		pos_p2 = _clamp_anchor_to_reach(prev_p2, pos_p2, max_reach)

		# 左线主链 S 极（红）；右线主链 N 极（蓝）
		_place_route_anchor(pos_p1, false)
		_place_route_anchor(pos_p2, true)

		prev_p1 = pos_p1
		prev_p2 = pos_p2

	_scatter_opposite_lane_anchors(route_ys, anchor_count, vert_step)


func _effective_route_vert_step() -> float:
	var horiz := route_horiz_zigzag
	var max_vert := sqrt(maxf(impulse_max_range * ROUTE_REACH_SAFETY, 1.0) ** 2 - horiz * horiz)
	return clampf(route_vert_step, 220.0, max_vert * 0.92)


func _route_anchor_count(base_y: float, vert_step: float) -> int:
	var climb := base_y - route_top_y
	return maxi(4, int(ceil(climb / maxf(vert_step, 1.0))))


func _clamp_anchor_to_reach(from: Vector2, target: Vector2, max_reach: float) -> Vector2:
	var offset := target - from
	var dist := offset.length()
	if dist <= max_reach or dist < 0.001:
		return target
	return from + offset * (max_reach * 0.95 / dist)


func _place_route_anchor(pos: Vector2, is_north: bool) -> void:
	var anchor: Node2D = ANCHOR_SCENE.instantiate()
	anchor.position = pos
	anchor.set("wall_side", 0)
	anchor.set("is_north_pole", is_north)
	_anchors.add_child(anchor)
	_placed_anchor_positions.append(pos)


func _scatter_opposite_lane_anchors(route_ys: Array[float], primary_count: int, vert_step: float) -> void:
	if primary_count <= 0 or route_ys.is_empty():
		return

	var max_extra := maxi(1, int(floor(float(primary_count) * scatter_opposite_ratio)))
	var left_n_extra := randi_range(1, max_extra)
	var right_s_extra := randi_range(1, max_extra)

	var left_indices := _shuffled_route_indices(primary_count)
	var right_indices := _shuffled_route_indices(primary_count)

	# 左线主链 S（红）→ 零星 N（蓝）
	for j in left_n_extra:
		if j >= left_indices.size():
			break
		var idx: int = left_indices[j]
		var y := route_ys[idx] - vert_step * (0.12 if idx % 2 == 0 else 0.28)
		var x := _scatter_lane_x(ArenaSide.LEFT, idx, true)
		_try_place_scatter_anchor(Vector2(x, y), true)

	# 右线主链 N（蓝）→ 零星 S（红），层位与左线错开
	for j in right_s_extra:
		if j >= right_indices.size():
			break
		var idx: int = right_indices[(j + (primary_count >> 1)) % right_indices.size()]
		var y := route_ys[idx] - vert_step * (0.2 if idx % 2 == 1 else 0.34)
		var x := _scatter_lane_x(ArenaSide.RIGHT, idx, true)
		_try_place_scatter_anchor(Vector2(x, y), false)


func _shuffled_route_indices(count: int) -> Array[int]:
	var indices: Array[int] = []
	for i in count:
		indices.append(i)
	indices.shuffle()
	return indices


func _scatter_lane_x(side: int, row_index: int, opposite_zigzag: bool) -> float:
	var base_x := LEFT_LANE_X if side == ArenaSide.LEFT else RIGHT_LANE_X
	var zig := route_horiz_zigzag * (0.55 if opposite_zigzag else 1.0)
	if row_index % 2 == 0:
		base_x += zig
	else:
		base_x -= zig * 0.5
	base_x += randf_range(-LANE_JITTER, LANE_JITTER)
	if side == ArenaSide.LEFT:
		return clampf(base_x, 240.0, 470.0)
	return clampf(base_x, 610.0, 840.0)


func _try_place_scatter_anchor(pos: Vector2, is_north: bool) -> bool:
	if not _is_anchor_spot_free(pos):
		return false
	_place_route_anchor(pos, is_north)
	return true


func _is_anchor_spot_free(pos: Vector2) -> bool:
	for existing in _placed_anchor_positions:
		if existing.distance_to(pos) < scatter_min_separation:
			return false
	return true


func _place_players() -> void:
	_revive_player_at_spawn(_player1, P1_SPAWN_X)
	_revive_player_at_spawn(_player2, P2_SPAWN_X)


func _revive_player_at_spawn(player: SlimePlayer, spawn_x: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.visible = true
	player.global_position = Vector2(spawn_x, _spawn_player_y)
	player.reset_for_round()


func _reset_arena_for_next_round() -> void:
	_bootstrap_arena()
	if GameSession.is_endless():
		_refresh_hp_hud()
	else:
		_refresh_score_hud()


func _refresh_score_hud() -> void:
	if _score_p1:
		_score_p1.text = str(GameSession.get_wins(1))
	if _score_p2:
		_score_p2.text = str(GameSession.get_wins(2))
	if _round_label:
		_round_label.text = GameSession.get_round_label()


func _update_countdown_hud() -> void:
	if _countdown_label == null or _arena_camera == null:
		return
	var remaining: int = _arena_camera.get_countdown_display()
	var show_hints: bool = remaining > 0 and not _arena_camera.is_scrolling()
	if show_hints:
		_countdown_label.text = str(remaining)
		_countdown_label.visible = true
	else:
		_countdown_label.visible = false
	if _controls_hint_p1:
		_controls_hint_p1.visible = show_hints
	if _controls_hint_p2:
		_controls_hint_p2.visible = show_hints


func _on_scroll_started() -> void:
	if _controls_hint_p1:
		_controls_hint_p1.visible = false
	if _controls_hint_p2:
		_controls_hint_p2.visible = false
	if _lava_visual and _lava_visual.has_method("set_scroll_active"):
		_lava_visual.set_scroll_active(true)


func _on_round_lost_by_lava(_fallen_id: int, winner_id: int) -> void:
	_end_round(winner_id)


func _on_round_won_by_finish(winner_id: int, _winner_name: String) -> void:
	_end_round(winner_id)


func _end_round(winner_id: int) -> void:
	if _round_over:
		return
	_round_over = true
	GameSession.set_input_locked(true)

	if winner_id != 1 and _player1.has_method("set_eliminated"):
		_player1.set_eliminated()
	if winner_id != 2 and _player2.has_method("set_eliminated"):
		_player2.set_eliminated()

	for player in [_player1, _player2]:
		if player is RigidBody2D:
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0

	var match_over: bool = GameSession.record_round_win(winner_id)
	_refresh_score_hud()
	await _show_round_banner(winner_id)

	if match_over:
		_show_match_result()
	else:
		_reset_arena_for_next_round()


func _show_round_banner(winner_id: int) -> void:
	if _round_banner == null:
		await get_tree().create_timer(1.2).timeout
		return
	_round_banner.text = "%s WINS" % GameSession.player_tag(winner_id)
	_round_banner.visible = true
	await get_tree().create_timer(1.2).timeout
	_round_banner.visible = false


func _show_match_result() -> void:
	var winner_id: int = GameSession.get_match_winner_id()
	if _match_winner:
		_match_winner.text = "%s WINS" % GameSession.player_tag(winner_id)
	if _match_score:
		_match_score.text = GameSession.get_score_label()
	_match_result.visible = true


func _on_play_again() -> void:
	_match_result.visible = false
	if GameSession.is_endless():
		GameSession.start_endless_match()
	else:
		GameSession.start_new_match()
	_reset_arena_for_next_round()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func get_spawn_player_y() -> float:
	return _spawn_player_y
