extends Node
## Autoload singleton (Project Settings -> GameSession).
## Do not add class_name here; it conflicts with the autoload name.

enum GameMode { LEVEL, ENDLESS }

const WINS_TO_MATCH := 4
const MAX_ROUNDS := 7
const ENDLESS_START_HP := 5

var mode: GameMode = GameMode.LEVEL
var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 1
var p1_hp: int = ENDLESS_START_HP
var p2_hp: int = ENDLESS_START_HP
var input_locked: bool = false


func start_new_match() -> void:
	start_level_match()


func start_level_match() -> void:
	mode = GameMode.LEVEL
	p1_wins = 0
	p2_wins = 0
	current_round = 1
	input_locked = false


func start_endless_match() -> void:
	mode = GameMode.ENDLESS
	p1_hp = ENDLESS_START_HP
	p2_hp = ENDLESS_START_HP
	input_locked = false


func is_endless() -> bool:
	return mode == GameMode.ENDLESS


func is_level() -> bool:
	return mode == GameMode.LEVEL


func record_round_win(winner_id: int) -> bool:
	if winner_id == 1:
		p1_wins += 1
	elif winner_id == 2:
		p2_wins += 1
	current_round += 1
	return p1_wins >= WINS_TO_MATCH or p2_wins >= WINS_TO_MATCH


func get_wins(player_id: int) -> int:
	return p1_wins if player_id == 1 else p2_wins


func get_hp(player_id: int) -> int:
	return p1_hp if player_id == 1 else p2_hp


func take_lava_damage(player_id: int) -> bool:
	if player_id == 1:
		p1_hp = maxi(p1_hp - 1, 0)
		return p1_hp > 0
	if player_id == 2:
		p2_hp = maxi(p2_hp - 1, 0)
		return p2_hp > 0
	return false


func get_match_winner_id() -> int:
	if is_endless():
		if p1_hp <= 0 and p2_hp > 0:
			return 2
		if p2_hp <= 0 and p1_hp > 0:
			return 1
		return 0
	if p1_wins >= WINS_TO_MATCH:
		return 1
	if p2_wins >= WINS_TO_MATCH:
		return 2
	return 0


func is_game_over() -> bool:
	if is_endless():
		return p1_hp <= 0 or p2_hp <= 0
	return get_match_winner_id() != 0


func get_score_label() -> String:
	if is_endless():
		return "ENDLESS | P1 %s | P2 %s" % [hp_hearts(1), hp_hearts(2)]
	return "%d - %d" % [p1_wins, p2_wins]


func hp_hearts(player_id: int) -> String:
	# ASCII-only: Godot Web default font lacks ♥/♡ glyphs (shows tofu boxes).
	var hp := get_hp(player_id)
	return "HP %d/%d" % [hp, ENDLESS_START_HP]


func get_round_label() -> String:
	return "R%d" % mini(current_round, MAX_ROUNDS)


func set_input_locked(locked: bool) -> void:
	input_locked = locked


func player_tag(player_id: int) -> String:
	return "P1" if player_id == 1 else "P2"
