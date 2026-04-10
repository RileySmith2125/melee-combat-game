## Arena — spawns and wires up the two fighters, connects HUD, manages round flow.
extends Node3D

const FIGHTER_SCENE := preload("res://scenes/fighter/Fighter.tscn")
const AI_SCENE := preload("res://scenes/fighter/FighterAI.tscn")
const DEFAULT_DECK := preload("res://resources/decks/deck_default.tres")

@onready var _p1_spawn: Marker3D = $P1Spawn
@onready var _p2_spawn: Marker3D = $P2Spawn
@onready var _hud: Control = $HUD/HUDControl

var _player: Fighter = null
var _opponent: FighterAI = null


func _ready() -> void:
	_spawn_fighters()
	_connect_hud()
	_connect_game_manager()
	GameManager.start_round()


func _spawn_fighters() -> void:
	# Player
	_player = FIGHTER_SCENE.instantiate() as Fighter
	_player.is_player = true
	_player.start_deck = DEFAULT_DECK.duplicate(true)
	_player.global_position = _p1_spawn.global_position
	add_child(_player)
	GameManager.player_fighter = _player

	# AI opponent
	_opponent = AI_SCENE.instantiate() as FighterAI
	_opponent.is_player = false
	_opponent.start_deck = DEFAULT_DECK.duplicate(true)
	_opponent.global_position = _p2_spawn.global_position
	add_child(_opponent)
	_opponent.set_target(_player)
	GameManager.opponent_fighter = _opponent


func _connect_hud() -> void:
	if _hud == null:
		return
	_player.stats.health_changed.connect(
		func(hp, max_hp): _hud.set_p1_health(hp, max_hp)
	)
	_player.stats.absorb_resource_changed.connect(
		func(val, max_val): _hud.set_absorb(val, max_val)
	)
	_opponent.stats.health_changed.connect(
		func(hp, max_hp): _hud.set_p2_health(hp, max_hp)
	)

	# Emit initial values to seed HUD
	_player.stats.health_changed.emit(_player.stats.health, _player.stats.max_health)
	_player.stats.absorb_resource_changed.emit(_player.stats.absorb_resource, _player.stats.max_absorb_resource)
	_opponent.stats.health_changed.emit(_opponent.stats.health, _opponent.stats.max_health)

	# Debug labels for deck/stance
	if _hud.has_method("set_debug_visible"):
		_hud.set_debug_visible(true)
	_player.state_machine.state_changed.connect(
		func(_s): _hud.update_debug(_player)
	)


func _connect_game_manager() -> void:
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)


func _on_round_ended(winner_name: String) -> void:
	if _hud:
		_hud.show_message("%s wins the round!" % winner_name, 2.5)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()


func _on_match_ended(winner_name: String) -> void:
	if _hud:
		_hud.show_message("%s WINS THE MATCH!" % winner_name, 0.0)
