extends Node
## 无尽模式：按领先者高度动态追加锚点区块。

@export var chunk_height: float = 960.0
@export var anchors_per_chunk: int = 3
@export var lookahead_chunks: int = 2
@export var initial_chunks: int = 4

var _arena: MainArena
var _camera: Camera2D
var _highest_generated_y: float = 0.0
var _route_prev_p1: Vector2
var _route_prev_p2: Vector2
var _chunk_index: int = 0
var _active: bool = false


func setup(arena: MainArena, camera: Camera2D, spawn_y: float) -> void:
	_arena = arena
	_camera = camera
	_active = true
	_chunk_index = 0
	_highest_generated_y = arena.start_platform_y
	_route_prev_p1 = Vector2(420.0, spawn_y)
	_route_prev_p2 = Vector2(660.0, spawn_y)
	for i in initial_chunks:
		_spawn_next_chunk()


func reset_for_match(arena: MainArena, camera: Camera2D, spawn_y: float) -> void:
	setup(arena, camera, spawn_y)


func get_highest_generated_y() -> float:
	return _highest_generated_y


func _process(_delta: float) -> void:
	if not _active or _arena == null or _camera == null:
		return
	var leader_y: float = _camera.get_leader_y() if _camera.has_method("get_leader_y") else INF
	var threshold := _highest_generated_y - lookahead_chunks * chunk_height
	while leader_y < threshold:
		_spawn_next_chunk()
		threshold = _highest_generated_y - lookahead_chunks * chunk_height


func _spawn_next_chunk() -> void:
	if _arena == null:
		return
	var result := _arena.append_route_chunk(anchors_per_chunk, _route_prev_p1, _route_prev_p2, _chunk_index)
	_route_prev_p1 = result.prev_p1
	_route_prev_p2 = result.prev_p2
	_highest_generated_y = result.highest_y
	_chunk_index += 1
	if _arena.has_method("on_endless_chunk_spawned"):
		_arena.on_endless_chunk_spawned(result)
