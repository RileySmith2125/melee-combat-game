class_name MoveCard
extends Resource

@export var move_name: String = "Unnamed Move"

# Stance gating — null means any stance is valid
@export var required_stance: Stance = null
@export var exit_stance: Stance = null

# Frame data at 60 fps
@export var startup_frames: int = 8
@export var active_frames: int = 4
@export var recovery_frames: int = 16
## Frame within recovery where the next attack input is accepted for chaining
@export var chain_window_frame: int = 20

# Combat values
@export var damage: int = 15
@export var hitstun_frames: int = 14
@export var knockback_vector: Vector3 = Vector3(0.0, 0.2, -1.5)

# Animation — must match the AnimationStateMachine node name in AnimationTree
@export var animation_name: String = ""

# Hitbox world-space offset from fighter origin (used until skeleton is rigged)
@export var hitbox_offset: Vector3 = Vector3(0.0, 1.0, -0.6)
@export var hitbox_radius: float = 0.3

# Defensive interaction overrides
@export var is_unabsorbable: bool = false
@export var is_unparriable: bool = false
