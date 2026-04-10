extends Node

signal round_started()
signal round_ended(winner_name: String)
signal match_ended(winner_name: String)

enum MatchState { MENU, DECK_BUILD, COUNTDOWN, FIGHTING, ROUND_END, MATCH_END }

const ROUNDS_TO_WIN: int = 2

var match_state: MatchState = MatchState.FIGHTING
var p1_rounds_won: int = 0
var p2_rounds_won: int = 0
var round_number: int = 1

# References set by Arena when fighters are spawned
var player_fighter: CharacterBody3D = null
var opponent_fighter: CharacterBody3D = null


func start_round() -> void:
	match_state = MatchState.FIGHTING
	round_started.emit()


func report_fighter_death(dead_fighter: CharacterBody3D) -> void:
	if match_state != MatchState.FIGHTING:
		return
	match_state = MatchState.ROUND_END

	var winner_name := ""
	if dead_fighter == player_fighter:
		p2_rounds_won += 1
		winner_name = "Opponent"
	else:
		p1_rounds_won += 1
		winner_name = "Player"

	round_ended.emit(winner_name)

	if p1_rounds_won >= ROUNDS_TO_WIN:
		match_state = MatchState.MATCH_END
		match_ended.emit("Player")
	elif p2_rounds_won >= ROUNDS_TO_WIN:
		match_state = MatchState.MATCH_END
		match_ended.emit("Opponent")


func reset_match() -> void:
	p1_rounds_won = 0
	p2_rounds_won = 0
	round_number = 1
	match_state = MatchState.FIGHTING
