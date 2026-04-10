class_name Stance
extends Resource

## Unique identifier used for fast equality checks
@export var stance_id: StringName = &"neutral"
@export var stance_name: String = "Neutral"

# Animation state names in the AnimationTree StateMachine
@export var idle_animation: String = "idle_neutral"
@export var walk_animation: String = "walk_neutral"

@export var icon: Texture2D = null
