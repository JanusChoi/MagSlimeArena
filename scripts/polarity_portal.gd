extends Area2D
## 极性反转传送门陷阱：穿过即 N↔S 翻转。

@export var lifetime: float = 10.0
@export var radius: float = 36.0
@export var player_cooldown: float = 0.8

var _time_left: float = 10.0
var _player_cd: Dictionary = {}
var _spin: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_time_left = lifetime
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	_spin += delta * 3.0
	queue_redraw()
	for key in _player_cd.keys():
		_player_cd[key] = maxf(float(_player_cd[key]) - delta, 0.0)
	if _time_left <= 0.0:
		queue_free()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.55, 0.2, 0.95, 0.35), 6.0, true)
	draw_arc(Vector2.ZERO, radius * 0.65, _spin, _spin + TAU * 0.6, 28, Color(0.85, 0.45, 1.0, 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 1.0, 0.85))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	var pid: int = body.get("player_id") if body.get("player_id") != null else 0
	if _player_cd.get(pid, 0.0) > 0.0:
		return
	_player_cd[pid] = player_cooldown
	if body.has_method("flip_polarity"):
		body.flip_polarity()
