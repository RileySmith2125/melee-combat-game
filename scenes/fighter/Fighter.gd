## Fighter — the top-level CharacterBody3D that owns and coordinates all combat sub-systems.
## Set is_player = false on the second fighter; it will receive AI input instead.
class_name Fighter
extends CharacterBody3D

const MOVE_SPEED: float = 4.0
const GRAVITY: float = -20.0
const TURN_SPEED: float = 8.0  # lerp factor for smooth yaw rotation

@export var is_player: bool = true
@export var start_deck: ComboDeck = null

# Current stance — read by DeckRunner to gate available moves
var current_stance: Stance = null

# Set by FighterStateMachine when a hit lands
var active_hitstun_frames: int = 0

# Sub-systems (Node children wired in _ready)
var state_machine: FighterStateMachine
var stats: FighterStats
var hit_detection: HitDetection
var defensive: DefensiveOptions
var deck_runner: DeckRunner
var animator: FighterAnimator
var aim_assist: AimAssist

# Camera (player only)
@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var _camera_yaw: float = 0.0   # accumulated horizontal rotation (radians)
var _camera_pitch: float = -0.3 # initial downward tilt


func _ready() -> void:
	add_to_group("fighter")

	# Wire node sub-systems
	stats = $FighterStats
	hit_detection = $HitDetection
	aim_assist = $AimAssist
	animator = $FighterAnimator

	# Build RefCounted sub-systems and inject dependencies
	state_machine = FighterStateMachine.new()
	deck_runner = DeckRunner.new()
	defensive = DefensiveOptions.new(state_machine, self)

	state_machine.fighter = self
	state_machine.deck_runner = deck_runner
	state_machine.defensive = defensive
	state_machine.animator = animator

	deck_runner.fighter = self
	if start_deck != null:
		deck_runner.deck = start_deck

	# Connect fighter death
	stats.fighter_died.connect(_on_fighter_died)

	# Disable camera for non-player fighter
	if not is_player and _spring_arm != null:
		_spring_arm.queue_free()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_player else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var input: Dictionary = InputMapper.get_input() if is_player else _get_ai_input()

	# ── Camera update (player only) ──
	if is_player:
		_camera_yaw -= input["camera_look"].x
		_camera_pitch = clampf(
			_camera_pitch - input["camera_look"].y,
			deg_to_rad(-55.0), deg_to_rad(15.0)
		)
		_spring_arm.global_position = global_position + Vector3(0.0, 1.5, 0.0)
		_spring_arm.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

	# ── Build camera-relative move direction ──
	var move_2d: Vector2 = input["move_direction"]
	var move_dir := Vector3.ZERO
	if move_2d.length() > 0.1:
		var yaw := _camera_yaw if is_player else rotation.y
		var cam_basis := Basis(Vector3.UP, yaw)
		move_dir = (cam_basis * Vector3(move_2d.x, 0.0, move_2d.y)).normalized()

	# Inject 3D direction into input dict for FSM/defensive use
	input["move_direction_3d"] = move_dir

	# ── Tick state machine ──
	state_machine.tick(delta, input)

	# ── Movement (only when not in a locked state) ──
	var locked := state_machine.current_state in [
		FighterStateMachine.CombatState.STARTUP,
		FighterStateMachine.CombatState.ACTIVE,
		FighterStateMachine.CombatState.HITSTUN,
		FighterStateMachine.CombatState.PARRIED,
	]
	if not locked:
		velocity.x = move_dir.x * MOVE_SPEED
		velocity.z = move_dir.z * MOVE_SPEED

	# ── Gravity ──
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	move_and_slide()

	# ── Smooth facing ──
	_update_facing(move_dir, delta)


## Smooth yaw rotation toward move_dir, with aim-assist override during attacks.
func _update_facing(move_dir: Vector3, delta: float) -> void:
	var target_facing := move_dir

	# During attack phases, steer toward the nearest enemy
	if state_machine.current_state in [
		FighterStateMachine.CombatState.STARTUP,
		FighterStateMachine.CombatState.ACTIVE,
	]:
		var current_fwd := -global_transform.basis.z
		target_facing = aim_assist.get_assisted_facing(current_fwd)

	if target_facing.length() < 0.1:
		return

	var target_yaw := atan2(target_facing.x, target_facing.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)


## Called by HitDetection to route an incoming hit through the state machine.
func receive_hit(move: MoveCard, attacker: Node = null) -> void:
	state_machine.receive_hit(move, attacker)


## Called when a parry stuns this fighter.
func enter_parried_stun() -> void:
	state_machine.enter_parried_stun()


func set_deck(deck: ComboDeck) -> void:
	deck_runner.deck = deck
	deck_runner.reset()


func _on_fighter_died() -> void:
	state_machine.transition_to(FighterStateMachine.CombatState.DEAD)
	GameManager.report_fighter_death(self)


## Override in FighterAI subclass. Returns same shape as InputMapper.get_input().
func _get_ai_input() -> Dictionary:
	return {
		"move_direction": Vector2.ZERO,
		"camera_look": Vector2.ZERO,
		"attack_pressed": false,
		"parry_held": false,
		"dodge_pressed": false,
		"absorb_held": false,
		"move_direction_3d": Vector3.ZERO,
	}
