## HitStop — brief Engine.time_scale freeze on hit for impact weight.
## Call HitStop.trigger() from HitDetection when a hit lands.
## This is a standalone autoload-safe static utility.
extends Node

const LIGHT_HIT_DURATION: float = 0.04   # ~2–3 frames at 60fps
const HEAVY_HIT_DURATION: float = 0.08   # ~5 frames
const SCALE_DURING_STOP: float = 0.05    # almost frozen

var _tween: Tween = null


## Freeze time for `duration` real seconds based on hit weight.
func trigger(damage: int) -> void:
	var dur := HEAVY_HIT_DURATION if damage >= 20 else LIGHT_HIT_DURATION
	if _tween:
		_tween.kill()
	Engine.time_scale = SCALE_DURING_STOP
	_tween = get_tree().create_tween().set_ignore_time_scale(true)
	_tween.tween_callback(func(): Engine.time_scale = 1.0).set_delay(dur)


## Shake the camera by briefly offsetting the SpringArm target.
## Call with the player's SpringArm3D node.
static func screen_shake(spring_arm: SpringArm3D, intensity: float = 0.15) -> void:
	if spring_arm == null:
		return
	var tween := spring_arm.create_tween().set_ignore_time_scale(true)
	for i in 4:
		var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0)
		tween.tween_property(spring_arm, "position", offset, 0.02)
	tween.tween_property(spring_arm, "position", Vector3.ZERO, 0.03)
