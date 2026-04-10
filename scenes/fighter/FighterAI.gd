## FighterAI — simple AI opponent. Overrides Fighter._get_ai_input().
## Behaviour: close distance → attack when in range → occasionally parry.
## Extend or replace this with a proper behaviour tree later.
class_name FighterAI
extends Fighter

const ATTACK_RANGE: float = 1.4
const CHASE_STOP_RANGE: float = 1.2
const PARRY_CHANCE_PER_FRAME: float = 0.012  # ~0.72% per frame → roughly once every 140 frames

var _target: Fighter = null  # set by Arena after spawning


func _ready() -> void:
	is_player = false
	super._ready()


func set_target(target: Fighter) -> void:
	_target = target


func _get_ai_input() -> Dictionary:
	var input := {
		"move_direction": Vector2.ZERO,
		"camera_look": Vector2.ZERO,
		"attack_pressed": false,
		"parry_held": false,
		"dodge_pressed": false,
		"absorb_held": false,
		"move_direction_3d": Vector3.ZERO,
	}

	if _target == null or _target.stats._is_dead:
		return input

	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	# Face the target
	if dist > 0.1:
		input["move_direction_3d"] = to_target.normalized()

	# Chase if too far
	if dist > CHASE_STOP_RANGE:
		var local_dir := to_target.normalized()
		input["move_direction"] = Vector2(local_dir.x, local_dir.z)

	# Attack when in range and able
	if dist <= ATTACK_RANGE:
		var can_attack: bool = state_machine.current_state in [
			FighterStateMachine.CombatState.IDLE,
			FighterStateMachine.CombatState.WALK,
		]
		if can_attack:
			input["attack_pressed"] = true

	# Random parry attempt
	if randf() < PARRY_CHANCE_PER_FRAME:
		input["parry_held"] = true

	return input
