extends Node
## 无尽模式道具刷新。

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

@export var spawn_every_chunks: int = 2
@export var max_active_pickups: int = 3

var _arena: MainArena
var _pickups_root: Node2D
var _chunks_since_spawn: int = 0


func setup(arena: MainArena, pickups_root: Node2D) -> void:
	_arena = arena
	_pickups_root = pickups_root


func on_chunk_spawned(result: Dictionary) -> void:
	if _arena == null or _pickups_root == null:
		return
	_chunks_since_spawn += 1
	if _chunks_since_spawn < spawn_every_chunks:
		return
	if _pickups_root.get_child_count() >= max_active_pickups:
		return
	_chunks_since_spawn = 0
	var positions: Array = result.get("scatter_positions", [])
	if positions.is_empty():
		return
	var pos: Vector2 = positions[randi() % positions.size()]
	_spawn_random_pickup(pos + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)))


func _spawn_random_pickup(pos: Vector2) -> void:
	var pickup: ArenaPickup = PICKUP_SCENE.instantiate()
	pickup.pickup_type = randi() % 3
	pickup.position = Vector2(
		clampf(pos.x, 200.0, 880.0),
		pos.y,
	)
	_pickups_root.add_child(pickup)


func clear_all() -> void:
	if _pickups_root == null:
		return
	for child in _pickups_root.get_children():
		child.queue_free()
	_chunks_since_spawn = 0
