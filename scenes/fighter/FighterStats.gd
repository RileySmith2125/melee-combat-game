class_name FighterStats
extends Node

signal health_changed(new_hp: int, max_hp: int)
signal absorb_resource_changed(new_val: float, max_val: float)
signal fighter_died()

@export var max_health: int = 100
@export var max_absorb_resource: float = 100.0
@export var absorb_regen_per_second: float = 15.0

var health: int
var absorb_resource: float
var _is_dead: bool = false


func _ready() -> void:
	health = max_health
	absorb_resource = max_absorb_resource


func _process(delta: float) -> void:
	if _is_dead:
		return
	absorb_resource = minf(absorb_resource + absorb_regen_per_second * delta, max_absorb_resource)
	absorb_resource_changed.emit(absorb_resource, max_absorb_resource)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_is_dead = true
		fighter_died.emit()


## Returns true if the absorb succeeded, false if resource was insufficient.
func spend_absorb_resource(cost: float) -> bool:
	if absorb_resource < cost:
		return false
	absorb_resource -= cost
	absorb_resource_changed.emit(absorb_resource, max_absorb_resource)
	return true


func reset() -> void:
	_is_dead = false
	health = max_health
	absorb_resource = max_absorb_resource
	health_changed.emit(health, max_health)
	absorb_resource_changed.emit(absorb_resource, max_absorb_resource)
