## HUD — runtime health bars, absorb resource bar, stance/deck debug labels,
## and the round-end message overlay.
extends Control

@onready var _p1_bar: ProgressBar = $TopBar/P1HealthBar
@onready var _p2_bar: ProgressBar = $TopBar/P2HealthBar
@onready var _absorb_bar: ProgressBar = $AbsorbBar
@onready var _message_label: Label = $MessageLabel
@onready var _debug_label: Label = $DebugLabel

var _message_timer: SceneTreeTimer = null


func _ready() -> void:
	_message_label.visible = false
	_debug_label.visible = false


# ── Health / resource ─────────────────────────────────────────────────────────

func set_p1_health(hp: int, max_hp: int) -> void:
	_p1_bar.max_value = max_hp
	_p1_bar.value = hp


func set_p2_health(hp: int, max_hp: int) -> void:
	_p2_bar.max_value = max_hp
	_p2_bar.value = hp


func set_absorb(val: float, max_val: float) -> void:
	_absorb_bar.max_value = max_val
	_absorb_bar.value = val


# ── Messages ──────────────────────────────────────────────────────────────────

## Show a message for `duration` seconds (0 = permanent).
func show_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_label.visible = true
	if _message_timer != null:
		# Can't cancel SceneTreeTimer, just let it expire harmlessly
		_message_timer = null
	if duration > 0.0:
		_message_timer = get_tree().create_timer(duration)
		_message_timer.timeout.connect(func(): _message_label.visible = false)


# ── Debug ─────────────────────────────────────────────────────────────────────

func set_debug_visible(visible_: bool) -> void:
	_debug_label.visible = visible_


func update_debug(fighter: Fighter) -> void:
	if not _debug_label.visible:
		return
	var stance_name := "none"
	if fighter.current_stance != null:
		stance_name = fighter.current_stance.stance_name
	var state_name: String = FighterStateMachine.CombatState.keys()[fighter.state_machine.current_state]
	var deck_pos: int = fighter.deck_runner.position
	_debug_label.text = "State: %s\nStance: %s\nDeck[%d]" % [state_name, stance_name, deck_pos]
