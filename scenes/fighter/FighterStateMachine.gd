## FighterStateMachine — the central combat logic hub.
## Runs as a plain RefCounted (not a Node) so it has no scene overhead.
## Called every physics frame from Fighter._physics_process().
##
## Key invariant: frame_counter increments ONCE per physics tick and resets to 0
## on every state transition. At 60 fps, 1 frame = 1/60 s.
class_name FighterStateMachine
extends RefCounted

enum CombatState {
	IDLE,
	WALK,
	STARTUP,      # attack wind-up — no hitbox yet
	ACTIVE,       # hitbox live
	RECOVERY,     # attack wind-down
	HITSTUN,      # took a hit
	PARRY_STARTUP,
	PARRY_ACTIVE,
	PARRY_RECOVERY,
	ABSORBING,
	DODGE,
	PARRIED,      # stunned after own attack was parried
	DEAD,
}

signal state_changed(new_state: CombatState)

var current_state: CombatState = CombatState.IDLE
var current_move: MoveCard = null
var frame_counter: int = 0
var active_hitstun_frames: int = 0  # set by receive_hit()

# Injected by Fighter._ready()
var fighter: Node          # CharacterBody3D (avoids circular class_name dep)
var deck_runner: DeckRunner
var defensive: DefensiveOptions
var animator: FighterAnimator


# ── Public API ───────────────────────────────────────────────────────────────

func tick(_delta: float, input: Dictionary) -> void:
	frame_counter += 1
	_process_state(input)


func transition_to(new_state: CombatState, move: MoveCard = null) -> void:
	current_state = new_state
	current_move = move
	frame_counter = 0
	state_changed.emit(new_state)


## Called by HitDetection when this fighter's hurtbox is struck.
func receive_hit(attacker_move: MoveCard, attacker: Node = null) -> void:
	match current_state:
		CombatState.PARRY_ACTIVE:
			defensive.resolve_parry_success(attacker_move, attacker)
		CombatState.ABSORBING:
			if not defensive.resolve_absorb(attacker_move):
				_apply_hit(attacker_move)
		CombatState.DODGE:
			if defensive.is_invincible():
				pass  # i-frames — ignore
			else:
				_apply_hit(attacker_move)
		CombatState.DEAD:
			pass
		_:
			_apply_hit(attacker_move)


## Called by DefensiveOptions when a parry lands on this fighter's attack.
func enter_parried_stun() -> void:
	transition_to(CombatState.PARRIED)
	active_hitstun_frames = 30  # long stun — free counter window for opponent


# ── State processors ─────────────────────────────────────────────────────────

func _process_state(input: Dictionary) -> void:
	match current_state:
		CombatState.IDLE, CombatState.WALK:
			_state_idle(input)
		CombatState.STARTUP:
			_state_startup(input)
		CombatState.ACTIVE:
			_state_active(input)
		CombatState.RECOVERY:
			_state_recovery(input)
		CombatState.HITSTUN:
			_state_hitstun(input)
		CombatState.PARRIED:
			_state_hitstun(input)  # same logic, just longer duration
		CombatState.PARRY_STARTUP, CombatState.PARRY_ACTIVE, CombatState.PARRY_RECOVERY:
			defensive.tick_parry(frame_counter, input)
		CombatState.DODGE:
			defensive.tick_dodge(frame_counter, input)
		CombatState.ABSORBING:
			defensive.tick_absorb(frame_counter, input)
		CombatState.DEAD:
			pass


func _state_idle(input: Dictionary) -> void:
	# Priority: attack > parry > absorb > dodge > move
	if input.get("attack_pressed", false):
		var move := deck_runner.get_current_move()
		if move != null:
			transition_to(CombatState.STARTUP, move)
			animator.play_move(move)
			return

	if input.get("parry_held", false):
		defensive.begin_parry()
		return

	if input.get("absorb_held", false):
		defensive.begin_absorb()
		return

	if input.get("dodge_pressed", false):
		var dir_3d: Vector3 = input.get("move_direction_3d", Vector3.ZERO)
		defensive.begin_dodge(dir_3d)
		return

	var is_moving: bool = input.get("move_direction", Vector2.ZERO).length() > 0.1
	var new_state: CombatState = CombatState.WALK if is_moving else CombatState.IDLE
	if new_state != current_state:
		current_state = new_state
		# Animator walk/idle blend updated by Fighter._update_facing()


func _state_startup(input: Dictionary) -> void:
	if frame_counter >= current_move.startup_frames:
		transition_to(CombatState.ACTIVE, current_move)
		fighter.hit_detection.activate_hitbox(current_move)


func _state_active(input: Dictionary) -> void:
	if frame_counter >= current_move.active_frames:
		fighter.hit_detection.deactivate_hitbox()
		transition_to(CombatState.RECOVERY, current_move)


func _state_recovery(input: Dictionary) -> void:
	# Accept chained attack input within chain window
	if frame_counter >= current_move.chain_window_frame and input.get("attack_pressed", false):
		deck_runner.advance()
		var next_move := deck_runner.get_current_move()
		if next_move != null:
			transition_to(CombatState.STARTUP, next_move)
			animator.play_move(next_move)
			return

	if frame_counter >= current_move.recovery_frames:
		deck_runner.advance()
		if current_move.exit_stance != null:
			fighter.set("current_stance", current_move.exit_stance)
			animator.play_idle(current_move.exit_stance)
		transition_to(CombatState.IDLE)


func _state_hitstun(_input: Dictionary) -> void:
	if frame_counter >= active_hitstun_frames:
		transition_to(CombatState.IDLE)


# ── Hit application ───────────────────────────────────────────────────────────

func _apply_hit(move: MoveCard) -> void:
	fighter.stats.take_damage(move.damage)
	active_hitstun_frames = move.hitstun_frames
	# Knockback is applied in fighter's local forward direction of attacker — simplified:
	# we just use the move's knockback_vector as a world impulse for now
	fighter.velocity += move.knockback_vector
	transition_to(CombatState.HITSTUN)
