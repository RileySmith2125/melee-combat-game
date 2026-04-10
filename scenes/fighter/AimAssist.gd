## AimAssist — soft angular pull toward the nearest enemy within a forward cone.
## This replaces hard lock-on: the fighter gently steers toward a valid target
## but never snaps position or forces camera alignment.
class_name AimAssist
extends Node

const ASSIST_CONE_HALF_ANGLE_DEG: float = 50.0
const ASSIST_RANGE: float = 5.0
## Maximum rotation correction applied per physics frame (degrees)
const MAX_CORRECTION_DEG_PER_FRAME: float = 12.0

@onready var _fighter: CharacterBody3D = get_parent()


## Given the fighter's current forward vector, returns a corrected forward vector
## that nudges toward the nearest valid target. If no target is found, returns
## current_facing unchanged.
func get_assisted_facing(current_facing: Vector3) -> Vector3:
	var target := _find_best_target(current_facing)
	if target == null:
		return current_facing

	var to_target := target.global_position - _fighter.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.001:
		return current_facing
	to_target = to_target.normalized()

	var angle := current_facing.angle_to(to_target)
	if angle < 0.001:
		return to_target

	var max_angle := deg_to_rad(MAX_CORRECTION_DEG_PER_FRAME)
	var t := minf(max_angle / angle, 1.0)
	return current_facing.slerp(to_target, t).normalized()


func _find_best_target(facing: Vector3) -> Node3D:
	var cone_cos := cos(deg_to_rad(ASSIST_CONE_HALF_ANGLE_DEG))
	var best: Node3D = null
	var best_dot := -1.0

	for node in get_tree().get_nodes_in_group("fighter"):
		if node == _fighter:
			continue
		var to_node: Vector3 = node.global_position - _fighter.global_position
		if to_node.length() > ASSIST_RANGE:
			continue
		var dir := to_node.normalized()
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			continue
		var dot := facing.dot(dir)
		if dot < cone_cos:
			continue
		if dot > best_dot:
			best_dot = dot
			best = node

	return best
