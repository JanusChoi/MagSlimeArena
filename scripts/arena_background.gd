extends Node2D
## 筒仓背景：从开局岩浆线向上平铺，接缝不在初始视野内。

@export var arena_width: float = 1080.0
@export var texture: Texture2D
@export var align_bottom_to_spawn_lava: bool = true
@export var spawn_leader_y: float = 2432.0
@export var lava_screen_fraction: float = 0.25
@export var safe_margin_above_lava: float = 120.0
## align_bottom_to_spawn_lava=false 时用手动底边
@export var anchor_bottom_y: float = 3100.0

const _Z_INDEX_BACKGROUND := -10


func _ready() -> void:
	z_index = _Z_INDEX_BACKGROUND
	if texture == null:
		push_warning("ArenaBackground: 未指定 texture")
		return

	var bottom_y := anchor_bottom_y
	if align_bottom_to_spawn_lava:
		bottom_y = _spawn_lava_surface_y()

	_build_tiles(bottom_y)


func _spawn_lava_surface_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	var half_viewport := viewport_height * 0.5
	var lava_height := viewport_height * lava_screen_fraction
	var cam_y := spawn_leader_y - (half_viewport - lava_height - safe_margin_above_lava)
	return cam_y + half_viewport - lava_height


func _build_tiles(bottom_y: float) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var scale_factor := arena_width / tex_size.x
	var scaled_height := tex_size.y * scale_factor
	var y_bottom := bottom_y

	while y_bottom > -scaled_height:
		var y_top := y_bottom - scaled_height
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(0.0, y_top)
		sprite.scale = Vector2(scale_factor, scale_factor)
		add_child(sprite)
		y_bottom = y_top
