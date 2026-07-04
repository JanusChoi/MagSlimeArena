extends StaticBody2D
## 随机宽度平台：在 _ready 中随机缩放 X 轴，碰撞与视觉同步。

@export var min_scale_x: float = 1.35
@export var max_scale_x: float = 2.85


func _ready() -> void:
	scale.x = randf_range(min_scale_x, max_scale_x)
