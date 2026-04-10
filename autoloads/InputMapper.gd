## InputMapper — autoload that collects and buffers player input each physics frame.
## All combat logic should read from get_input() rather than polling Input directly,
## so that short presses during busy states are not silently dropped.
extends Node

const BUFFER_FRAMES: int = 6

var _attack_buffer: int = 0
var _dodge_buffer: int = 0

# Raw mouse delta accumulated since last physics tick (set in _input, consumed in get_input)
var _mouse_delta: Vector2 = Vector2.ZERO
var mouse_sensitivity: float = 0.002


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative


func _physics_process(_delta: float) -> void:
	# Decay buffers
	_attack_buffer = maxi(_attack_buffer - 1, 0)
	_dodge_buffer = maxi(_dodge_buffer - 1, 0)

	# Latch fresh presses into buffer
	if Input.is_action_just_pressed("attack"):
		_attack_buffer = BUFFER_FRAMES
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer = BUFFER_FRAMES


## Returns a snapshot of the current input state. Consuming buffered presses
## (attack, dodge) clears their buffer so the same press isn't used twice.
func get_input() -> Dictionary:
	var move_input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)

	var attack_pressed := _attack_buffer > 0
	var dodge_pressed := _dodge_buffer > 0

	if attack_pressed:
		_attack_buffer = 0
	if dodge_pressed:
		_dodge_buffer = 0

	var look := _mouse_delta * mouse_sensitivity
	_mouse_delta = Vector2.ZERO  # consume

	return {
		"move_direction": move_input,
		"camera_look": look,
		"attack_pressed": attack_pressed,
		"parry_held": Input.is_action_pressed("parry"),
		"dodge_pressed": dodge_pressed,
		"absorb_held": Input.is_action_pressed("absorb"),
	}
