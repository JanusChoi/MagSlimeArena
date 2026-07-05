extends Node2D
## 墙锚攀岩点：N / S 极精灵，异极可抓握。

@export var is_north_pole: bool = true
@export var wall_side: int = -1  ## -1=左墙, 1=右墙, 0=自由放置
@export var display_scale: float = 1.0

const _TEX_N := preload("res://assets/anchors/anchor_n_pole.png")
const _TEX_S := preload("res://assets/anchors/anchor_s_pole.png")

@onready var _visual: Sprite2D = $Visual
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
	var radius := _anchor_radius()
	if wall_side < 0:
		position.x = inner_x + radius
	else:
		position.x = inner_x - radius


func _anchor_radius() -> float:
	if _visual != null and _visual.texture != null:
		return _visual.texture.get_height() * 0.5 * display_scale
	return 25.0


func _update_visual() -> void:
	if _visual:
		_visual.texture = _TEX_N if is_north_pole else _TEX_S
		_visual.centered = true
		var base_scale := display_scale
		if _latched_by != null:
			_visual.modulate = Color(1.35, 1.35, 1.35, 1.0)
			_visual.scale = Vector2.ONE * base_scale * 1.18
		else:
			_visual.modulate = Color.WHITE
			_visual.scale = Vector2.ONE * base_scale
		_visual.position.x = 0.0 if wall_side == 0 else (-10.0 if wall_side < 0 else 10.0)
	if _label:
		_label.visible = false
