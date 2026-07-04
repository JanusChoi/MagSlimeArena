extends Node2D
## 磁力波浪连线：在玩家本地坐标绘制，z_index 保证显示在史莱姆上方。

@export var line_width: float = 5.0

var _local_points: PackedVector2Array = PackedVector2Array()
var _line_color: Color = Color(0.55, 0.82, 1.0, 0.95)
var _active: bool = false


func _ready() -> void:
	z_index = 10


func set_wavy_line(local_points: PackedVector2Array, color: Color, active: bool) -> void:
	_active = active
	_line_color = color
	_local_points = local_points
	visible = active
	queue_redraw()


func _draw() -> void:
	if not _active or _local_points.size() < 2:
		return

	draw_polyline(_local_points, _line_color, line_width, true)
	draw_circle(_local_points[0], line_width * 0.55, _line_color)
	draw_circle(_local_points[_local_points.size() - 1], line_width * 0.55, _line_color)
