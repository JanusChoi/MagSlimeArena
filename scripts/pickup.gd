extends Area2D
class_name ArenaPickup
## 无尽模式道具拾取物。

enum PickupType { MASS_AMPLIFIER, POLARITY_OVERDRIVE, PORTAL_TRAP }

@export var pickup_type: PickupType = PickupType.MASS_AMPLIFIER

var _bob_phase: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_bob_phase = randf() * TAU
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_bob_phase += delta * 4.0
	queue_redraw()


func _draw() -> void:
	var bob := sin(_bob_phase) * 4.0
	match pickup_type:
		PickupType.MASS_AMPLIFIER:
			_draw_mass_icon(bob)
		PickupType.POLARITY_OVERDRIVE:
			_draw_battery_icon(bob)
		PickupType.PORTAL_TRAP:
			_draw_portal_icon(bob)
		_:
			pass


func _draw_mass_icon(bob: float) -> void:
	var c := Vector2(0.0, bob)
	draw_circle(c, 22.0, Color(0.35, 0.35, 0.42, 0.35))
	draw_rect(Rect2(c + Vector2(-14.0, -6.0 + bob * 0.2), Vector2(28.0, 16.0)), Color(0.75, 0.78, 0.85, 1.0))
	draw_rect(Rect2(c + Vector2(-10.0, -14.0 + bob * 0.2), Vector2(20.0, 8.0)), Color(0.55, 0.58, 0.68, 1.0))
	draw_string(
		ThemeDB.fallback_font,
		c + Vector2(-5.0, 5.0),
		"M",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14,
		Color(1.0, 0.85, 0.35, 1.0),
	)


func _draw_battery_icon(bob: float) -> void:
	var c := Vector2(0.0, bob)
	draw_rect(Rect2(c + Vector2(-12.0, -16.0), Vector2(24.0, 32.0)), Color(0.2, 0.85, 1.0, 0.95))
	draw_rect(Rect2(c + Vector2(-4.0, -20.0), Vector2(8.0, 4.0)), Color(0.85, 0.95, 1.0, 1.0))
	for i in 3:
		var spark := c + Vector2(cos(_bob_phase + i * 2.1) * 18.0, sin(_bob_phase * 1.3 + i) * 10.0 - 4.0)
		draw_line(c, spark, Color(0.55, 0.95, 1.0, 0.85), 2.0, true)


func _draw_portal_icon(bob: float) -> void:
	var c := Vector2(0.0, bob)
	draw_arc(c, 20.0, 0.0, TAU, 32, Color(0.75, 0.35, 1.0, 0.95), 3.0, true)
	draw_arc(c, 12.0, _bob_phase, _bob_phase + TAU * 0.75, 24, Color(0.95, 0.55, 1.0, 0.8), 2.0, true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	if not body.has_method("apply_pickup"):
		return
	body.apply_pickup(pickup_type, global_position)
	queue_free()
