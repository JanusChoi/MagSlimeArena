extends Node2D
## 终点线：虚线横条，玩家中心越过即获胜。

signal player_crossed(winner_id: int, winner_name: String)

@export var arena_width: float = 1080.0
@export var line_width: float = 5.0
@export var dash_length: float = 28.0
@export var gap_length: float = 18.0
@export var line_color: Color = Color(1.0, 0.92, 0.35, 0.95)

var finish_y: float = 0.0
var _triggered: bool = false


func setup(y: float) -> void:
	finish_y = y
	position = Vector2(arena_width * 0.5, y)
	queue_redraw()


func reset() -> void:
	_triggered = false


func check_players(player1: Node2D, player2: Node2D) -> void:
	if _triggered:
		return

	for player in [player1, player2]:
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("is_eliminated") and player.is_eliminated():
			continue
		if player.global_position.y <= finish_y:
			_triggered = true
			var winner_id: int = player.get("player_id") if player.get("player_id") != null else 0
			player_crossed.emit(winner_id, _winner_name(winner_id))
			return


func _draw() -> void:
	var left := -arena_width * 0.5 + 24.0
	var right := arena_width * 0.5 - 24.0
	var x := left
	while x < right:
		var x_end := minf(x + dash_length, right)
		draw_line(Vector2(x, 0.0), Vector2(x_end, 0.0), line_color, line_width, true)
		x += dash_length + gap_length

	# 顶部小三角标记
	var tri := PackedVector2Array([
		Vector2(-14.0, -18.0),
		Vector2(14.0, -18.0),
		Vector2(0.0, -34.0),
	])
	draw_colored_polygon(tri, line_color)


func _winner_name(player_id: int) -> String:
	match player_id:
		1:
			return "N-Pole (Player 1)"
		2:
			return "S-Pole (Player 2)"
		_:
			return "Player"
