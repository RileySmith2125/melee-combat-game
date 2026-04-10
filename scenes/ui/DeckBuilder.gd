## DeckBuilder — between-fight UI for arranging MoveCards into the player's deck.
## Drag a card from the catalog panel on the right into a slot on the left.
## Warnings about unreachable stance transitions are shown inline.
extends Control

const MOVES_CATALOG := preload("res://resources/moves/moves_catalog.tres")

@onready var _slots_container: VBoxContainer = $HSplit/DeckPanel/SlotsContainer
@onready var _catalog_container: VBoxContainer = $HSplit/CatalogPanel/CatalogContainer
@onready var _warning_label: Label = $WarningLabel
@onready var _save_button: Button = $SaveButton

var _deck: ComboDeck = null
var _slot_buttons: Array[Button] = []

signal deck_saved(deck: ComboDeck)


func _ready() -> void:
	_save_button.pressed.connect(_on_save_pressed)


## Open the builder for editing `deck`.
func open(deck: ComboDeck) -> void:
	_deck = deck
	_rebuild_slots()
	_rebuild_catalog()
	_refresh_warnings()
	show()


func _rebuild_slots() -> void:
	for child in _slots_container.get_children():
		child.queue_free()
	_slot_buttons.clear()

	for i in ComboDeck.MAX_DECK_SIZE:
		var btn := Button.new()
		var card: MoveCard = _deck.get_move_at(i) if i < _deck.moves.size() else null
		btn.text = card.move_name if card else "[ empty ]"
		btn.custom_minimum_size = Vector2(200, 36)
		btn.set_meta("slot_index", i)
		_slots_container.add_child(btn)
		_slot_buttons.append(btn)


func _rebuild_catalog() -> void:
	for child in _catalog_container.get_children():
		child.queue_free()
	if MOVES_CATALOG == null:
		return
	for move in MOVES_CATALOG.moves:
		var btn := Button.new()
		btn.text = "%s  [%s→%s]" % [
			move.move_name,
			move.required_stance.stance_name if move.required_stance else "any",
			move.exit_stance.stance_name if move.exit_stance else "?"
		]
		btn.custom_minimum_size = Vector2(220, 36)
		btn.pressed.connect(_on_catalog_card_pressed.bind(move))
		_catalog_container.add_child(btn)


var _selected_catalog_move: MoveCard = null


func _on_catalog_card_pressed(move: MoveCard) -> void:
	_selected_catalog_move = move
	# Highlight selected — simplified: just remember it
	_warning_label.text = "Selected: %s — click a slot to place it." % move.move_name


func _on_slot_pressed(slot_index: int) -> void:
	if _selected_catalog_move == null:
		return
	if slot_index < _deck.moves.size():
		_deck.moves[slot_index] = _selected_catalog_move
	else:
		_deck.moves.append(_selected_catalog_move)
	_selected_catalog_move = null
	_rebuild_slots()
	_refresh_warnings()


func _refresh_warnings() -> void:
	var warnings := _deck.validate_flow()
	if warnings.is_empty():
		_warning_label.text = "Deck OK"
		_warning_label.modulate = Color.GREEN
	else:
		_warning_label.text = "\n".join(warnings)
		_warning_label.modulate = Color.YELLOW


func _on_save_pressed() -> void:
	ResourceSaver.save(_deck, _deck.resource_path if not _deck.resource_path.is_empty() \
		else "user://deck_saved.tres")
	deck_saved.emit(_deck)
	hide()
