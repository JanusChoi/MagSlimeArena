extends Node2D
class_name MainArena
## 主竞技场：左右交替平台、终点线、屏幕固定岩浆 + 世界上滚。

enum MagnetGameplay {
	CLASSIC_HOLD,
	ANCHOR_IMPULSE_ONE_SHOT,
}

const ARENA_HEIGHT := 3100.0
const ARENA_WIDTH := 1080.0
const LEVEL_COUNT := 11
const START_PLATFORM_Y := 2480.0
const PLAYER_STAND_OFFSET := 48.0
const PLATFORM_BASE_HALF_WIDTH := 100.0
const FINISH_LINE_ABOVE_TOP := 100.0

## 极端测试：仅出生台 + 垂直锚点链（Inspector 可关）
@export var anchor_only_climb_test: bool = true

@export_group("Magnet Gameplay")
@export var magnet_gameplay: MagnetGameplay = MagnetGameplay.ANCHOR_IMPULSE_ONE_SHOT
@export var magnet_affects_players: bool = false
## 模型2：F/Shift 只打锚点，G/? 专打对手（与 magnet_affects_players 互斥）
@export var pvp_dual_key_impulse: bool = true

@export_group("Anchor Impulse (one-shot F/Shift)")
@export var impulse_max_range: float = 520.0
@export var impulse_attract_speed: float = 1960.0
@export var impulse_repel_speed: float = 840.0
@export var impulse_up_bias: float = 0.48
@export var impulse_distance_bonus: float = 0.35

@export_group("Player Impulse (dual-key G / ? · weak hook)")
@export var player_impulse_max_range: float = 280.0
@export var player_impulse_attract_speed: float = 520.0
@export var player_impulse_up_bias: float = 0.22
@export var player_impulse_distance_bonus: float = 0.15
@export var player_impulse_cooldown: float = 0.45

@export_group("Guaranteed Routes")
@export var route_vert_step: float = 360.0
@export var route_horiz_zigzag: float = 110.0
@export var route_top_y: float = 720.0

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

enum Side { LEFT = -1, CENTER = 0, RIGHT = 1 }

@onready var _platforms: Node2D = $Platforms
@onready var _anchors: Node2D = $Anchors
@onready var _hazard: Node = $ScrollHazard
@onready var _finish_line: Node2D = $FinishLine
@onready var _lava_status: Label = $HUD/LavaStatus
@onready var _controls_hint: Label = $HUD/ControlsHint
@onready var _arena_camera: Camera2D = $ArenaCamera
@onready var _player1: SlimePlayer = $Player1
@onready var _player2: SlimePlayer = $Player2

var _spawn_player_y: float = START_PLATFORM_Y - PLAYER_STAND_OFFSET
var _platform_centers: Array[Vector2] = []
var _platform_scales: Array[float] = []
var _game_over: bool = false


func _ready() -> void:
	_build_staircase()
	_build_scattered_anchors()
	_setup_finish_line()
	_place_players()
	_arena_camera.setup(_player1, _player2, _spawn_player_y, _finish_line.finish_y)
	_hazard.setup(_arena_camera, _player1, _player2)
	_hazard.player_eliminated.connect(_on_player_eliminated)
	_finish_line.player_crossed.connect(_on_player_won)
	_update_hud()
	_update_controls_hint()


func _process(_delta: float) -> void:
	if _game_over:
		return
	_finish_line.check_players(_player1, _player2)
	_update_hud()


func _build_staircase() -> void:
	for child in _platforms.get_children():
		child.queue_free()

	_platform_centers.clear()
	_platform_scales.clear()

	if anchor_only_climb_test:
		_build_spawn_platform_only()
		return

	var prev_x := 540.0
	var prev_y := START_PLATFORM_Y
	var prev_scale := randf_range(SPAWN_PLATFORM_SCALE_MIN, SPAWN_PLATFORM_SCALE_MAX)
	var prev_side := Side.CENTER
	var next_side := Side.RIGHT if randf() > 0.5 else Side.LEFT

	for i in LEVEL_COUNT:
		var platform: StaticBody2D = PLATFORM_SCENE.instantiate()
		var y: float
		var x: float
		var scale_x: float
		var side: int = Side.CENTER

		if i == 0:
			x = CENTER_LANE_X
			y = START_PLATFORM_Y
			scale_x = prev_scale
			side = Side.CENTER
		else:
			if i == 1:
				var placement := _spawn_safe_jump_platform(prev_x, prev_y, prev_scale, Side.CENTER)
				x = placement.x
				y = placement.y
				scale_x = placement.scale
				side = placement.side
			else:
				side = next_side
				if i % 6 == 3:
					side = Side.CENTER
				else:
					next_side = Side.RIGHT if next_side == Side.LEFT else Side.LEFT

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
	platform.position = Vector2(CENTER_LANE_X, START_PLATFORM_Y)
	platform.min_scale_x = scale_x
	platform.max_scale_x = scale_x
	_platforms.add_child(platform)
	_platform_centers.append(Vector2(CENTER_LANE_X, START_PLATFORM_Y))
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
	var side := Side.LEFT if randf() > 0.5 else Side.RIGHT
	if avoid_side == Side.LEFT:
		side = Side.RIGHT
	elif avoid_side == Side.RIGHT:
		side = Side.LEFT

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
	if side == Side.LEFT:
		return WALL_INNER_LEFT + half + WALL_TUCK_MARGIN
	return WALL_INNER_RIGHT - half - WALL_TUCK_MARGIN


func _pick_platform_placement(
	prev_x: float, prev_y: float, prev_scale: float, prev_side: int, preferred_side: int, level_index: int
) -> Dictionary:
	var sides_to_try: Array[int] = [preferred_side]
	if preferred_side != Side.LEFT:
		sides_to_try.append(Side.LEFT)
	if preferred_side != Side.RIGHT:
		sides_to_try.append(Side.RIGHT)
	if preferred_side != Side.CENTER:
		sides_to_try.append(Side.CENTER)

	var best := _forced_lane_placement(prev_x, prev_y, prev_scale, preferred_side, level_index)

	for side in sides_to_try:
		for _attempt in 10:
			var vert_step := randf_range(MIN_VERT_STEP, MAX_VERT_STEP)
			var y := prev_y - vert_step
			var scale_x := randf_range(MIN_PLATFORM_SCALE, MAX_PLATFORM_SCALE)
			var x := _lane_x_for_side(side, scale_x, level_index)

			if side != Side.CENTER and prev_side != Side.CENTER and side == prev_side:
				continue

			if not _is_placement_valid(prev_x, prev_y, prev_scale, x, y, scale_x, level_index):
				continue

			var score := _score_placement(prev_x, x, vert_step, scale_x, side)
			if score > best.score:
				best = {"x": x, "y": y, "scale": scale_x, "side": side, "score": score}

	return best


func _forced_lane_placement(prev_x: float, prev_y: float, prev_scale: float, side: int, level_index: int) -> Dictionary:
	var opposite := Side.RIGHT if side == Side.LEFT else Side.LEFT
	var use_side := opposite if side == Side.CENTER else side
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
		Side.LEFT:
			return clampf(LEFT_LANE_X + jitter, 120.0 + half, CENTER_LANE_X - half * 0.35)
		Side.RIGHT:
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


func _score_placement(prev_x: float, x: float, vert_step: float, scale_x: float, side: int) -> float:
	var horiz := absf(x - prev_x)
	var score := horiz * 0.6
	score += clampf(vert_step, MIN_VERT_STEP, MAX_VERT_STEP) * 0.25
	if side != Side.CENTER:
		score += 40.0
	if horiz >= 280.0:
		score += 50.0
	return score


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
	var half := count / 2
	var flags: Array[bool] = []
	for i in count:
		flags.append(i < half)
	flags.shuffle()
	return flags


func _build_guaranteed_player_routes() -> void:
	if _platform_centers.is_empty():
		return

	var base_y := _platform_centers[0].y
	var vert_step := _effective_route_vert_step()
	var anchor_count := _route_anchor_count(base_y, vert_step)
	var max_reach := impulse_max_range * ROUTE_REACH_SAFETY
	var prev_p1 := Vector2(P1_SPAWN_X, _spawn_player_y)
	var prev_p2 := Vector2(P2_SPAWN_X, _spawn_player_y)

	for i in anchor_count:
		var y := base_y - float(i + 1) * vert_step
		var p1_x := P1_ROUTE_LANE_X + (route_horiz_zigzag if i % 2 == 0 else -route_horiz_zigzag * 0.45)
		var p2_x := P2_ROUTE_LANE_X + (route_horiz_zigzag if i % 2 == 1 else -route_horiz_zigzag * 0.45)
		var pos_p1 := Vector2(clampf(p1_x, 240.0, 470.0), y)
		var pos_p2 := Vector2(clampf(p2_x, 610.0, 840.0), y - vert_step * 0.22)

		pos_p1 = _clamp_anchor_to_reach(prev_p1, pos_p1, max_reach)
		pos_p2 = _clamp_anchor_to_reach(prev_p2, pos_p2, max_reach)

		_place_route_anchor(pos_p1, false)
		_place_route_anchor(pos_p2, true)

		prev_p1 = pos_p1
		prev_p2 = pos_p2


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


func _place_players() -> void:
	_spawn_player_y = START_PLATFORM_Y - PLAYER_STAND_OFFSET
	_player1.global_position = Vector2(420.0, _spawn_player_y)
	_player2.global_position = Vector2(660.0, _spawn_player_y)


func _update_hud() -> void:
	if _arena_camera == null or _lava_status == null:
		return

	var countdown: float = _arena_camera.get_time_until_scroll()
	if countdown > 0.0:
		_lava_status.text = "岩浆将在 %.0f 秒后上涌！快往上逃！" % ceil(countdown)
		_lava_status.modulate = Color(1.0, 0.85, 0.4)
	elif _arena_camera.is_scrolling():
		var surface_y: float = _arena_camera.get_lava_surface_world_y()
		var leader_y := minf(_player1.global_position.y, _player2.global_position.y)
		var gap := surface_y - leader_y
		_lava_status.text = "往上逃！领先者距岩浆 %.0f px · 冲过顶部虚线获胜" % maxf(gap, 0.0)
		_lava_status.modulate = Color(1.0, 0.45, 0.35)
	else:
		_lava_status.text = ""


func _update_controls_hint() -> void:
	if _controls_hint == null:
		return
	var lines: PackedStringArray = []
	if anchor_only_climb_test:
		lines.append("【测试：仅出生台 + 双路保底锚点链】")
	if magnet_gameplay == MagnetGameplay.ANCHOR_IMPULSE_ONE_SHOT:
		lines.append("【冲量】F/Shift → 锚点（强）· 异极飞过 / 同极弹开")
		if pvp_dual_key_impulse:
			lines.append("【对抗】G / ? → 吸向对手（弱钩，有冷却）")
		elif magnet_affects_players:
			lines.append("F/Shift 对玩家与锚点均生效")
		else:
			lines.append("玩家之间无磁力，仍有碰撞")
	else:
		lines.append("按住 F/Shift 持续磁力")
	lines.append("P1 (蓝 N): A/D | W 跳 | F 锚 | G 钩人")
	lines.append("P2 (红 S): ←/→ | ↑ 跳 | Shift 锚 | ? 钩人")
	lines.append("5 秒后场景上滚 · 冲过顶部虚线获胜")
	_controls_hint.text = "\n".join(lines)


func _on_player_eliminated(_fallen_id: int, _winner_name: String) -> void:
	_game_over = true


func _on_player_won(winner_id: int, winner_name: String) -> void:
	if _game_over:
		return
	_game_over = true
	print("%s 冲过终点线！" % winner_name)
	_lava_status.text = "%s 获胜！" % winner_name
	_lava_status.modulate = Color(0.5, 1.0, 0.55)
	if _player1.has_method("set_eliminated") and winner_id != 1:
		_player1.set_eliminated()
	if _player2.has_method("set_eliminated") and winner_id != 2:
		_player2.set_eliminated()
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


func get_spawn_player_y() -> float:
	return _spawn_player_y
