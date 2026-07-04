class_name SlimePlayer
extends RigidBody2D
## 史莱姆玩家：平台跳跃 + 锚点交互 + 磁力（持续 / 单次冲量两种模式）。

@export var player_id: int = 1
@export var move_force: float = 1200.0
@export var max_horizontal_speed: float = 525.0
@export var jump_strength: float = 830.0
@export var max_jumps: int = 2
@export var magnet_strength: float = 600000.0
@export var magnet_min_distance: float = 50.0
@export var prefer_player_targets: bool = true
@export var debug_jump: bool = false

@export_group("Anchor Jump (classic mode)")
@export var anchor_entry_radius: float = 58.0
@export var anchor_highlight_sec: float = 0.35

@export_group("Squash & Stretch")
@export var stretch_amount: float = 0.35
@export var squash_amount: float = 0.25
@export var vertical_ref_speed: float = 400.0
@export var horizontal_ref_speed: float = 350.0
@export var recovery_speed: float = 12.0

@export_group("Magnet Link")
@export var magnet_link_width: float = 3.0
@export var magnet_link_amplitude: float = 14.0
@export var magnet_link_segments: int = 16
@export var magnet_link_wave_speed: float = 8.0
@export var magnet_link_wave_cycles: float = 3.0

const _GROUND_PROBE_EXTRA := 10.0
const _MagneticUtilsScript := preload("res://scripts/magnetic_utils.gd")

@onready var _ground_ray: RayCast2D = $GroundRay
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual_root: Node2D = $VisualRoot
@onready var _polarity_label: Label = $VisualRoot/PolarityLabel
@onready var _visual: Polygon2D = $VisualRoot/Visual
@onready var _magnet_ring: Polygon2D = $VisualRoot/MagnetRing
@onready var _magnet_link: Node2D = $MagnetLinkDraw

var polarity: int = 1
var _magnet_active: bool = false
var _magnet_was_pressed: bool = false
var _magnet_just_pressed: bool = false
var _grapple_active: bool = false
var _grapple_was_pressed: bool = false
var _grapple_just_pressed: bool = false
var _grapple_cooldown: float = 0.0
var _magnet_link_phase: float = 0.0
var _jumps_remaining: int = 0
var _jump_was_pressed: bool = false
var _pending_jump: bool = false
var _eliminated: bool = false
var _jump_granted_anchors: Dictionary = {}
var _highlight_anchor: Node2D = null
var _highlight_timer: float = 0.0
var _just_granted_anchor_jump: bool = false
var _impulse_link_target: Node2D = null
var _impulse_link_timer: float = 0.0
var _impulse_link_to_player: bool = false
var _magnet_flash_timer: float = 0.0

const _INPUT_KEYS := {
	1: {
		"left": KEY_A,
		"right": KEY_D,
		"jump": KEY_W,
		"magnet": KEY_F,
		"magnet_action": &"magnet_p1",
		"grapple": KEY_G,
		"grapple_action": &"grapple_p1",
	},
	2: {
		"left": KEY_LEFT,
		"right": KEY_RIGHT,
		"jump": KEY_UP,
		"magnet": KEY_SHIFT,
		"magnet_action": &"magnet_p2",
		"grapple": KEY_SLASH,
		"grapple_action": &"grapple_p2",
	},
}


func _ready() -> void:
	add_to_group("players")
	add_to_group("magnetic_entities")
	polarity = 1 if player_id == 1 else -1
	_jumps_remaining = max_jumps
	_update_polarity_label()
	_apply_player_color()
	_magnet_ring.visible = false
	if _magnet_link:
		_magnet_link.line_width = magnet_link_width
		_magnet_link.set_wavy_line(PackedVector2Array(), Color.WHITE, false)


func _process(delta: float) -> void:
	_update_squash_stretch(delta)
	_update_magnet_link(delta)
	_update_anchor_highlight(delta)
	if _impulse_link_timer > 0.0:
		_impulse_link_timer -= delta
	if _magnet_flash_timer > 0.0:
		_magnet_flash_timer -= delta
	if _grapple_cooldown > 0.0:
		_grapple_cooldown -= delta


func _physics_process(_delta: float) -> void:
	if _eliminated:
		return

	_ground_ray.force_raycast_update()
	_update_magnet_state()
	_update_grapple_state()

	var grounded := _is_grounded()

	if _uses_impulse_mode():
		if _magnet_just_pressed:
			_trigger_anchor_impulse()
		if _uses_dual_key_pvp() and _grapple_just_pressed:
			_trigger_player_impulse()
	else:
		if grounded:
			_jump_granted_anchors.clear()
		else:
			_check_anchor_jump_entry()
		if _magnet_active:
			_apply_magnetism()

	_handle_movement()
	_handle_jump(grounded)
	_clamp_horizontal_speed()
	_update_magnet_visual()
	_flush_pending_jump()


func _arena() -> MainArena:
	return get_parent() as MainArena


func _uses_impulse_mode() -> bool:
	var arena := _arena()
	return arena != null and arena.magnet_gameplay == MainArena.MagnetGameplay.ANCHOR_IMPULSE_ONE_SHOT


func _uses_dual_key_pvp() -> bool:
	var arena := _arena()
	return (
		arena != null
		and _uses_impulse_mode()
		and arena.pvp_dual_key_impulse
	)


func _magnet_targets_players() -> bool:
	var arena := _arena()
	if arena == null:
		return prefer_player_targets
	if _uses_dual_key_pvp():
		return false
	return arena.magnet_affects_players


func _trigger_anchor_impulse() -> void:
	var arena := _arena()
	if arena == null:
		return

	var anchor := _find_closest_anchor_in_range(arena.impulse_max_range)
	if anchor == null:
		return

	var to_anchor := anchor.global_position - global_position
	var dist := to_anchor.length()
	if dist < 0.001:
		return

	var dir := to_anchor / dist
	var interaction: int = polarity * _MagneticUtilsScript.get_polarity(anchor)
	sleeping = false

	if interaction < 0:
		var fly_dir := (dir + Vector2(0.0, -arena.impulse_up_bias)).normalized()
		var speed := arena.impulse_attract_speed + dist * arena.impulse_distance_bonus
		linear_velocity = fly_dir * speed
	else:
		var speed := arena.impulse_repel_speed + dist * arena.impulse_distance_bonus * 0.6
		linear_velocity = -dir * speed

	_flash_anchor(anchor)
	_impulse_link_target = anchor
	_impulse_link_to_player = false
	_impulse_link_timer = 0.45
	_magnet_flash_timer = 0.3
	_just_granted_anchor_jump = true


func _trigger_player_impulse() -> void:
	var arena := _arena()
	if arena == null or _grapple_cooldown > 0.0:
		return

	var opponent := _find_opponent_in_range(arena.player_impulse_max_range)
	if opponent == null:
		return

	var to_target := opponent.global_position - global_position
	var dist := to_target.length()
	if dist < 0.001:
		return

	var dir := to_target / dist
	sleeping = false
	var fly_dir := (dir + Vector2(0.0, -arena.player_impulse_up_bias)).normalized()
	var speed := arena.player_impulse_attract_speed + dist * arena.player_impulse_distance_bonus
	linear_velocity = fly_dir * speed

	_impulse_link_target = opponent
	_impulse_link_to_player = true
	_impulse_link_timer = 0.35
	_magnet_flash_timer = 0.25
	_grapple_cooldown = arena.player_impulse_cooldown


func _find_opponent_in_range(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not node is Node2D:
			continue
		if node.has_method("is_eliminated") and node.is_eliminated():
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist <= max_range and dist < best_dist:
			best_dist = dist
			best = node
	return best


func _find_closest_anchor_in_range(max_range: float) -> Node2D:
	var best_opposite: Node2D = null
	var best_opposite_dist := INF
	var best_same: Node2D = null
	var best_same_dist := INF

	for node in get_tree().get_nodes_in_group("magnetic_anchors"):
		if not node is Node2D:
			continue
		var anchor := node as Node2D
		var dist := global_position.distance_to(anchor.global_position)
		if dist > max_range:
			continue
		var interaction: int = polarity * _MagneticUtilsScript.get_polarity(anchor)
		if interaction < 0:
			if dist < best_opposite_dist:
				best_opposite_dist = dist
				best_opposite = anchor
		elif dist < best_same_dist:
			best_same_dist = dist
			best_same = anchor

	# 优先异极（可飞过）；范围内只有同极时才斥开
	if best_opposite != null:
		return best_opposite
	return best_same


func set_eliminated() -> void:
	_clear_anchor_highlight()
	_eliminated = true
	if _visual:
		_visual.modulate = Color(0.45, 0.45, 0.45, 0.7)
	if _magnet_ring:
		_magnet_ring.visible = false
	if _magnet_link:
		_magnet_link.set_wavy_line(PackedVector2Array(), Color.WHITE, false)


func is_eliminated() -> bool:
	return _eliminated


func get_magnetic_polarity() -> int:
	return polarity


func _check_anchor_jump_entry() -> void:
	for node in get_tree().get_nodes_in_group("magnetic_anchors"):
		if not node is Node2D:
			continue
		var anchor := node as Node2D
		var anchor_id: int = anchor.get_instance_id()
		if _jump_granted_anchors.get(anchor_id, false):
			continue
		if global_position.distance_to(anchor.global_position) > anchor_entry_radius:
			continue
		var interaction: int = polarity * _MagneticUtilsScript.get_polarity(anchor)
		if interaction >= 0:
			continue
		_jump_granted_anchors[anchor_id] = true
		_jumps_remaining = maxi(_jumps_remaining, 1)
		_just_granted_anchor_jump = true
		_flash_anchor(anchor)


func _flash_anchor(anchor: Node2D) -> void:
	_clear_anchor_highlight()
	_highlight_anchor = anchor
	_highlight_timer = anchor_highlight_sec
	if anchor.has_method("set_latched"):
		anchor.set_latched(true, self)


func _clear_anchor_highlight() -> void:
	if _highlight_anchor != null and is_instance_valid(_highlight_anchor):
		if _highlight_anchor.has_method("set_latched"):
			_highlight_anchor.set_latched(false, self)
	_highlight_anchor = null
	_highlight_timer = 0.0


func _update_anchor_highlight(delta: float) -> void:
	if _highlight_timer <= 0.0:
		return
	_highlight_timer -= delta
	if _highlight_timer <= 0.0:
		_clear_anchor_highlight()
		_just_granted_anchor_jump = false


func _update_squash_stretch(delta: float) -> void:
	if _visual_root == null:
		return

	var vx := linear_velocity.x / horizontal_ref_speed
	var vy := linear_velocity.y / vertical_ref_speed
	var target := Vector2(
		1.0 + absf(vx) * stretch_amount - absf(vy) * squash_amount,
		1.0 + absf(vy) * stretch_amount - absf(vx) * squash_amount,
	)
	target = target.clamp(Vector2(0.7, 0.7), Vector2(1.4, 1.4))
	_visual_root.scale = _visual_root.scale.lerp(target, delta * recovery_speed)


func _flush_pending_jump() -> void:
	if not _pending_jump:
		return
	linear_velocity = Vector2(linear_velocity.x, -jump_strength)
	_pending_jump = false


func _get_keys() -> Dictionary:
	return _INPUT_KEYS.get(player_id, _INPUT_KEYS[1])


func _update_magnet_state() -> void:
	var keys := _get_keys()
	var action: StringName = keys["magnet_action"]
	var pressed := (
		Input.is_action_pressed(action)
		or Input.is_physical_key_pressed(keys["magnet"])
	)
	_magnet_just_pressed = pressed and not _magnet_was_pressed
	_magnet_active = pressed
	_magnet_was_pressed = pressed


func _update_grapple_state() -> void:
	if not _uses_dual_key_pvp():
		_grapple_active = false
		_grapple_just_pressed = false
		_grapple_was_pressed = false
		return

	var keys := _get_keys()
	var action: StringName = keys["grapple_action"]
	var pressed := (
		Input.is_action_pressed(action)
		or Input.is_physical_key_pressed(keys["grapple"])
	)
	_grapple_just_pressed = pressed and not _grapple_was_pressed
	_grapple_active = pressed
	_grapple_was_pressed = pressed


func _handle_movement() -> void:
	var keys := _get_keys()
	var direction := 0.0

	if Input.is_physical_key_pressed(keys["left"]):
		direction -= 1.0
	if Input.is_physical_key_pressed(keys["right"]):
		direction += 1.0

	if direction != 0.0:
		apply_central_force(Vector2(direction * move_force, 0.0))


func _handle_jump(grounded: bool) -> void:
	if grounded:
		_jumps_remaining = max_jumps

	var jump_key: Key = _get_keys()["jump"]
	var jump_pressed := Input.is_physical_key_pressed(jump_key)

	if jump_pressed and not _jump_was_pressed:
		if _jumps_remaining > 0:
			_request_jump()

	_jump_was_pressed = jump_pressed


func _request_jump() -> void:
	sleeping = false
	_pending_jump = true
	_jumps_remaining -= 1


func _is_grounded() -> bool:
	if _ground_ray.is_colliding():
		return true

	var radius := _get_body_radius()
	var from := global_position
	var to := global_position + Vector2(0.0, radius + _GROUND_PROBE_EXTRA)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _get_body_radius() -> float:
	var shape := _collision_shape.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	return 36.0


func _find_closest_magnetic_target() -> Node2D:
	if _uses_impulse_mode():
		if _impulse_link_target != null and is_instance_valid(_impulse_link_target) and _impulse_link_timer > 0.0:
			return _impulse_link_target
		return _find_closest_anchor_in_range(_arena().impulse_max_range if _arena() else 520.0)

	var closest: Node2D = null
	var closest_dist_sq := INF
	var closest_player: Node2D = null
	var closest_player_dist_sq := INF
	var allow_players := _magnet_targets_players()

	for node in get_tree().get_nodes_in_group("magnetic_entities"):
		if node == self or not node is Node2D:
			continue
		if node.is_in_group("magnetic_anchors"):
			pass
		elif node.is_in_group("players") and not allow_players:
			continue
		var dist_sq := global_position.distance_squared_to(node.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = node
		if allow_players and prefer_player_targets and node.is_in_group("players"):
			if dist_sq < closest_player_dist_sq:
				closest_player_dist_sq = dist_sq
				closest_player = node

	if allow_players and prefer_player_targets and closest_player != null:
		if closest == null or closest_player_dist_sq <= closest_dist_sq * 1.35:
			return closest_player

	return closest


func _apply_magnetism() -> void:
	var target := _find_closest_magnetic_target()
	if target == null:
		return
	_apply_magnetism_to_target(target)


func _apply_magnetism_to_target(target: Node2D) -> void:
	var delta_pos := target.global_position - global_position
	var distance := delta_pos.length()
	if distance <= 0.001:
		return

	var force_mag := magnet_strength / maxf(distance, magnet_min_distance)
	var dir := delta_pos / distance
	var interaction_sign: int = polarity * _MagneticUtilsScript.get_polarity(target)
	apply_central_force(-dir * force_mag * interaction_sign)


func _update_magnet_link(delta: float) -> void:
	if _magnet_link == null or _eliminated:
		return

	if not _magnet_link.has_method("set_wavy_line"):
		return

	var show_link := false
	if _uses_impulse_mode():
		show_link = _impulse_link_timer > 0.0 and _impulse_link_target != null
	else:
		show_link = _is_magnet_pressed()

	if not show_link:
		_magnet_link.set_wavy_line(PackedVector2Array(), Color.WHITE, false)
		return

	var target := _find_closest_magnetic_target()
	if target == null:
		_magnet_link.set_wavy_line(PackedVector2Array(), Color.WHITE, false)
		return

	_magnet_link_phase += delta * magnet_link_wave_speed
	var local_points := _build_wavy_line(
		Vector2.ZERO,
		to_local(target.global_position),
		magnet_link_segments,
		magnet_link_amplitude,
		_magnet_link_phase,
	)
	var link_color := _get_magnet_link_color_for_target(target)
	if _impulse_link_to_player:
		link_color = Color(1.0, 0.72, 0.28, 0.95)
	_magnet_link.line_width = magnet_link_width + (2.0 if _uses_impulse_mode() else 0.0)
	_magnet_link.set_wavy_line(local_points, link_color, true)


func _is_magnet_pressed() -> bool:
	return _magnet_active


func _build_wavy_line(
	from: Vector2,
	to: Vector2,
	segments: int,
	amplitude: float,
	phase: float,
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		points.append(from)
		points.append(to)
		return points

	var tangent := delta / length
	var normal := tangent.orthogonal()
	var seg_count := maxi(segments, 2)

	for i in seg_count + 1:
		var t := float(i) / float(seg_count)
		var along := from.lerp(to, t)
		var wave := sin(t * magnet_link_wave_cycles * TAU + phase) * amplitude
		points.append(along + normal * wave)

	return points


func _get_magnet_link_color_for_target(target: Node2D) -> Color:
	var interaction: int = polarity * _MagneticUtilsScript.get_polarity(target)
	if interaction < 0:
		return Color(0.38, 0.95, 0.48, 0.92)
	return Color(1.0, 0.4, 0.36, 0.92)


func _clamp_horizontal_speed() -> void:
	var cap := max_horizontal_speed
	if _uses_impulse_mode():
		cap = maxf(max_horizontal_speed, 920.0)
	var velocity := linear_velocity
	velocity.x = clampf(velocity.x, -cap, cap)
	linear_velocity = velocity


func _update_polarity_label() -> void:
	if _polarity_label:
		_polarity_label.text = "N" if polarity > 0 else "S"


func _apply_player_color() -> void:
	if _visual:
		_visual.color = Color(0.25, 0.55, 1.0) if player_id == 1 else Color(1.0, 0.35, 0.35)
	if _magnet_ring:
		_magnet_ring.color = Color(0.5, 0.85, 1.0, 0.45) if player_id == 1 else Color(1.0, 0.55, 0.55, 0.45)


func _update_magnet_visual() -> void:
	if _magnet_ring:
		if _uses_impulse_mode():
			_magnet_ring.visible = _magnet_flash_timer > 0.0
			if _impulse_link_to_player and _magnet_flash_timer > 0.0:
				_magnet_ring.color = Color(1.0, 0.75, 0.35, 0.55) if player_id == 1 else Color(1.0, 0.65, 0.4, 0.55)
			else:
				_apply_player_color()
		else:
			_magnet_ring.visible = _magnet_active

	if _visual and not _eliminated:
		if _just_granted_anchor_jump or _magnet_flash_timer > 0.0:
			if _impulse_link_to_player and _magnet_flash_timer > 0.0:
				_visual.modulate = Color(1.35, 1.15, 0.85)
			else:
				_visual.modulate = Color(1.15, 1.45, 1.2)
		elif _grapple_active and _uses_dual_key_pvp():
			_visual.modulate = Color(1.25, 1.2, 1.0)
		elif _magnet_active and not _uses_impulse_mode():
			_visual.modulate = Color(1.35, 1.35, 1.5)
		else:
			_visual.modulate = Color.WHITE
