extends Node
## Autoload: match scoring, input lock, best-of-7 (first to 4).

const WINS_TO_MATCH := 4
const MAX_ROUNDS := 7

var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 1
var input_locked: bool = false


func start_new_match() -> void:
	p1_wins = 0
	p2_wins = 0
	current_round = 1
	input_locked = false


func record_round_win(winner_id: int) -> bool:
	if winner_id == 1:
		p1_wins += 1
	elif winner_id == 2:
		p2_wins += 1
	current_round += 1
	return p1_wins >= WINS_TO_MATCH or p2_wins >= WINS_TO_MATCH


func get_wins(player_id: int) -> int:
	return p1_wins if player_id == 1 else p2_wins


func get_match_winner_id() -> int:
	if p1_wins >= WINS_TO_MATCH:
		return 1
	if p2_wins >= WINS_TO_MATCH:
		return 2
	return 0


func get_score_label() -> String:
	return "%d - %d" % [p1_wins, p2_wins]


func get_round_label() -> String:
	return "R%d" % mini(current_round, MAX_ROUNDS)


func set_input_locked(locked: bool) -> void:
	input_locked = locked


func player_tag(player_id: int) -> String:
	return "P1" if player_id == 1 else "P2"
