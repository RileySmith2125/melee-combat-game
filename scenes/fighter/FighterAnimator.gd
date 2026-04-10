## FighterAnimator — thin wrapper around AnimationTree / AnimationStateMachine.
## Combat logic never touches AnimationTree directly; it calls methods here.
## During the prototype phase (no rigged character), this is a no-op stub so that
## the rest of the system can be built and tested without animations.
class_name FighterAnimator
extends Node

@onready var _anim_player: AnimationPlayer = get_parent().get_node_or_null("AnimationPlayer")
@onready var _anim_tree: AnimationTree = get_parent().get_node_or_null("AnimationTree")

var _playback: AnimationNodeStateMachinePlayback = null
var _stub_mode: bool = true  # switched off once a real AnimationTree is wired up


func _ready() -> void:
	if _anim_tree != null:
		_playback = _anim_tree.get("parameters/playback")
		_stub_mode = _playback == null
	if _stub_mode:
		print("[FighterAnimator] Running in stub mode — no AnimationTree found.")


func play_move(move: MoveCard) -> void:
	if _stub_mode or move.animation_name.is_empty():
		return
	_playback.travel(move.animation_name)


func play_idle(stance: Stance) -> void:
	if _stub_mode or stance == null or stance.idle_animation.is_empty():
		return
	_playback.travel(stance.idle_animation)


func play_walk(stance: Stance) -> void:
	if _stub_mode or stance == null or stance.walk_animation.is_empty():
		return
	_playback.travel(stance.walk_animation)


func force_idle() -> void:
	if _stub_mode:
		return
	_playback.travel("idle_neutral")
