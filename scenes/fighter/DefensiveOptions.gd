## DefensiveOptions — frame-window parry, absorb resource system, and dodge i-frames.
## Called by FighterStateMachine during parry/absorb/dodge states.
class_name DefensiveOptions
extends RefCounted

# Parry timings (frames at 60 fps)
const PARRY_STARTUP_FRAMES: int = 3
const PARRY_ACTIVE_FRAMES: int = 6   # tight window for perfect parry
const PARRY_RECOVERY_FRAMES: int = 28 # punishable on whiff

# Dodge timings
const DODGE_TOTAL_FRAMES: int = 22
const DODGE_SPEED: float = 7.0
const DODGE_IFRAMES_START: int = 3
const DODGE_IFRAMES_END: int = 13

# Hitstop on parry success (frames to freeze via Engine.time_scale)
const PARRY_HITSTOP_FRAMES: int = 5

var _fsm: RefCounted  # FighterStateMachine — typed as RefCounted to avoid circular dep
var _fighter: Node

var _dodge_velocity: Vector3 = Vector3.ZERO

signal parry_success(attacker: Node)


func _init(fsm: RefCounted, fighter: Node) -> void:
	_fsm = fsm
	_fighter = fighter


# ── Parry ────────────────────────────────────────────────────────────────────

func begin_parry() -> void:
	_fsm.transition_to(_fsm.CombatState.PARRY_STARTUP)


func tick_parry(frame: int, input: Dictionary) -> void:
	match _fsm.current_state:
		_fsm.CombatState.PARRY_STARTUP:
			if frame >= PARRY_STARTUP_FRAMES:
				_fsm.transition_to(_fsm.CombatState.PARRY_ACTIVE)
		_fsm.CombatState.PARRY_ACTIVE:
			# Release or window expired → punishable recovery
			if frame >= PARRY_ACTIVE_FRAMES or not input.get("parry_held", false):
				_fsm.transition_to(_fsm.CombatState.PARRY_RECOVERY)
		_fsm.CombatState.PARRY_RECOVERY:
			if frame >= PARRY_RECOVERY_FRAMES:
				_fsm.transition_to(_fsm.CombatState.IDLE)


## Called by FighterStateMachine.receive_hit() when a hit lands during PARRY_ACTIVE.
func resolve_parry_success(attacker_move: MoveCard, attacker: Node) -> void:
	# Grant i-frames briefly (no hurtbox) and return to IDLE
	_fighter.hit_detection.set_hurtbox_enabled(false)
	_fsm.transition_to(_fsm.CombatState.IDLE)
	get_tree_via_fighter().create_timer(0.1).timeout.connect(
		func(): _fighter.hit_detection.set_hurtbox_enabled(true)
	)
	# Tell attacker to enter PARRIED stun
	if attacker and attacker.has_method("enter_parried_stun"):
		attacker.enter_parried_stun()
	parry_success.emit(attacker)


# ── Absorb ───────────────────────────────────────────────────────────────────

func begin_absorb() -> void:
	_fsm.transition_to(_fsm.CombatState.ABSORBING)


func tick_absorb(_frame: int, input: Dictionary) -> void:
	if not input.get("absorb_held", false):
		_fsm.transition_to(_fsm.CombatState.IDLE)


## Called when a hit arrives during ABSORBING. Returns true if absorbed.
func resolve_absorb(attacker_move: MoveCard) -> bool:
	if attacker_move.is_unabsorbable:
		return false
	var cost := float(attacker_move.damage)
	var absorbed: bool = _fighter.stats.spend_absorb_resource(cost)
	if absorbed:
		# Take full damage but skip hitstun — fighter stays active
		_fighter.stats.take_damage(attacker_move.damage)
		_fsm.transition_to(_fsm.CombatState.IDLE)
	return absorbed


# ── Dodge ────────────────────────────────────────────────────────────────────

func begin_dodge(world_direction: Vector3) -> void:
	_dodge_velocity = world_direction.normalized() * DODGE_SPEED
	if _dodge_velocity.length_squared() < 0.01:
		# Default: back-dodge along fighter's facing
		_dodge_velocity = -_fighter.global_transform.basis.z * DODGE_SPEED
	_fsm.transition_to(_fsm.CombatState.DODGE)


func tick_dodge(frame: int, _input: Dictionary) -> void:
	# Velocity burst that decays to zero over the dodge duration
	var progress := float(frame) / float(DODGE_TOTAL_FRAMES)
	_fighter.velocity.x = _dodge_velocity.x * (1.0 - progress)
	_fighter.velocity.z = _dodge_velocity.z * (1.0 - progress)

	# Toggle hurtbox for i-frames
	var invincible: bool = frame >= DODGE_IFRAMES_START and frame <= DODGE_IFRAMES_END
	_fighter.hit_detection.set_hurtbox_enabled(not invincible)

	if frame >= DODGE_TOTAL_FRAMES:
		_fighter.hit_detection.set_hurtbox_enabled(true)
		_fsm.transition_to(_fsm.CombatState.IDLE)


func is_invincible() -> bool:
	var f: int = _fsm.frame_counter
	return (
		_fsm.current_state == _fsm.CombatState.DODGE
		and f >= DODGE_IFRAMES_START
		and f <= DODGE_IFRAMES_END
	)


# ── Helpers ──────────────────────────────────────────────────────────────────

func get_tree_via_fighter() -> SceneTree:
	return _fighter.get_tree()
