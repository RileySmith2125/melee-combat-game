## DeckRunner — runtime cursor over a ComboDeck.
## Advances through the deck as the fighter executes moves, gating each card
## against the fighter's current stance so only valid moves are returned.
class_name DeckRunner
extends RefCounted

var deck: ComboDeck = null
var position: int = 0

# Reference to the Fighter node (not a type hint to avoid circular dependency)
var fighter: Node = null


## Returns the first MoveCard at or after the current cursor position whose
## required_stance matches fighter.current_stance. Returns null if the deck is
## empty or no valid card exists (misconfigured deck).
func get_current_move() -> MoveCard:
	if deck == null or deck.moves.is_empty():
		return null
	var checked := 0
	var idx := position
	while checked < deck.moves.size():
		var card: MoveCard = deck.moves[idx % deck.moves.size()]
		if _stance_matches(card):
			return card
		idx += 1
		checked += 1
	return null


func advance() -> void:
	if deck == null or deck.moves.is_empty():
		return
	position = (position + 1) % deck.moves.size()


func reset() -> void:
	position = 0


func _stance_matches(card: MoveCard) -> bool:
	if card.required_stance == null:
		return true
	if fighter == null:
		return true
	var current: Stance = fighter.get("current_stance")
	if current == null:
		return true
	return current.stance_id == card.required_stance.stance_id
