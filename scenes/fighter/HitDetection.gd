## HitDetection — manages the fighter's Hitbox and Hurtbox Areas.
## Activated/deactivated by FighterStateMachine during STARTUP→ACTIVE→RECOVERY.
## Resolves hits by routing to the target fighter's state machine.
class_name HitDetection
extends Node

signal hit_landed(target: Node, move: MoveCard)

@onready var hitbox: Area3D = $Hitbox
@onready var hurtbox: Area3D = $Hurtbox

var active_move: MoveCard = null
var _fighter: Node  # set in _ready, avoids circular class_name dependency


func _ready() -> void:
	_fighter = get_parent()
	hurtbox.add_to_group("hurtbox")

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.monitoring = false
	hitbox.get_node("CollisionShape3D").disabled = true


## Positions the hitbox in world-space relative to the fighter's facing direction
## and activates it. Called at the start of the ACTIVE phase.
func activate_hitbox(move: MoveCard) -> void:
	active_move = move
	# Place hitbox at move's local offset rotated by fighter facing
	var world_offset: Vector3 = _fighter.global_transform.basis * move.hitbox_offset
	hitbox.global_position = _fighter.global_position + world_offset
	# Resize sphere to match move data
	var shape := hitbox.get_node("CollisionShape3D").shape as SphereShape3D
	if shape:
		shape.radius = move.hitbox_radius
	hitbox.get_node("CollisionShape3D").disabled = false
	hitbox.monitoring = true


func deactivate_hitbox() -> void:
	hitbox.monitoring = false
	hitbox.get_node("CollisionShape3D").disabled = true
	active_move = null


## Enable/disable the hurtbox (used by dodge i-frames and parry success window).
func set_hurtbox_enabled(enabled: bool) -> void:
	hurtbox.monitorable = enabled


func _on_hitbox_area_entered(area: Area3D) -> void:
	if active_move == null:
		return
	if not area.is_in_group("hurtbox"):
		return
	# Walk up: Hurtbox → HitDetection → Fighter
	var target: Node = area.get_parent().get_parent()
	if target == _fighter:
		return
	if target.has_method("receive_hit"):
		target.receive_hit(active_move)
	hit_landed.emit(target, active_move)
	HitStop.trigger(active_move.damage)
	deactivate_hitbox()  # one hit per swing; multi-hit moves re-activate separately
