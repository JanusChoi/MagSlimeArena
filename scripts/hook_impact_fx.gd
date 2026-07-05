extends Node
## G/Option 钩人命中：极短 hit-stop + 方向性震屏（不受 time_scale 影响）。

@export var hitstop_scale: float = 0.05
@export var hitstop_real_duration: float = 0.1
@export var shake_strength: float = 16.0
@export var shake_real_duration: float = 0.12

var _camera: Camera2D
var _hitstop_until_usec: int = 0
var _saved_time_scale: float = 1.0
var _shake_dir: Vector2 = Vector2.DOWN
var _shake_remaining_real: float = 0.0
var _shake_phase: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(camera: Camera2D) -> void:
	_camera = camera


func trigger(pull_direction: Vector2) -> void:
	var now := Time.get_ticks_usec()
	var duration_usec := int(hitstop_real_duration * 1_000_000.0)
	_hitstop_until_usec = maxi(_hitstop_until_usec, now + duration_usec)
	if Engine.time_scale > hitstop_scale + 0.001:
		_saved_time_scale = Engine.time_scale
	Engine.time_scale = hitstop_scale

	if pull_direction.length_squared() > 0.0001:
		_shake_dir = pull_direction.normalized()
	else:
		_shake_dir = Vector2.DOWN
	_shake_remaining_real = shake_real_duration
	_shake_phase = randf() * TAU


func reset_for_round() -> void:
	_hitstop_until_usec = 0
	_shake_remaining_real = 0.0
	Engine.time_scale = 1.0
	_saved_time_scale = 1.0
	if _camera:
		_camera.offset = Vector2.ZERO


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _hitstop_until_usec > 0 and now >= _hitstop_until_usec:
		_hitstop_until_usec = 0
		Engine.time_scale = _saved_time_scale

	if _camera == null:
		return

	if _shake_remaining_real > 0.0:
		_shake_remaining_real = maxf(_shake_remaining_real - delta, 0.0)
		var t := _shake_remaining_real / maxf(shake_real_duration, 0.001)
		var amp := shake_strength * t * t
		var wobble := sin(_shake_phase + (shake_real_duration - _shake_remaining_real) * 50.0)
		_camera.offset = _shake_dir * amp * wobble
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO
