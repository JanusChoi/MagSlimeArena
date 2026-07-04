extends Node2D
## 墙锚攀岩点：左 S / 右 N，异极可抓握。

@export var is_north_pole: bool = true
@export var wall_side: int = -1  ## -1=左墙, 1=右墙, 0=自由放置

@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $PolarityLabel

var _latched_by: Node2D = null

const _WALL_INNER_X := {
	-1: 120.0,
	1: 960.0,
}


func _ready() -> void:
	add_to_group("magnetic_entities")
	add_to_group("magnetic_anchors")
	_update_visual()
	_snap_to_wall()


func get_magnetic_polarity() -> int:
	return 1 if is_north_pole else -1


func set_latched(active: bool, player: Node2D = null) -> void:
	_latched_by = player if active else null
	_update_visual()


func _snap_to_wall() -> void:
	if wall_side == 0:
		return
	var inner_x: float = _WALL_INNER_X.get(wall_side, _WALL_INNER_X[-1])
	var radius := 28.0
	if wall_side < 0:
		position.x = inner_x + radius
	else:
		position.x = inner_x - radius


func _update_visual() -> void:
	var base := Color(0.25, 0.55, 1.0, 0.85) if is_north_pole else Color(1.0, 0.35, 0.35, 0.85)
	if _visual:
		if _latched_by != null:
			_visual.color = base.lightened(0.35)
			_visual.scale = Vector2(1.18, 1.18)
		else:
			_visual.color = base
			_visual.scale = Vector2.ONE
		_visual.position.x = 0.0 if wall_side == 0 else (-10.0 if wall_side < 0 else 10.0)
	if _label:
		_label.text = "N" if is_north_pole else "S"
