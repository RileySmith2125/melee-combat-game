class_name ComboDeck
extends Resource

const MAX_DECK_SIZE: int = 12
const MIN_DECK_SIZE: int = 4

@export var deck_name: String = "My Deck"
@export var moves: Array[MoveCard] = []


func is_valid() -> bool:
	return moves.size() >= MIN_DECK_SIZE


## Returns a list of warning strings for unreachable stance transitions.
## An empty array means the deck flows cleanly.
func validate_flow() -> Array[String]:
	var warnings: Array[String] = []
	for i in moves.size():
		var card: MoveCard = moves[i]
		if card.required_stance == null:
			continue
		var prev: MoveCard = moves[(i - 1) % moves.size()]
		if prev.exit_stance == null:
			continue
		if prev.exit_stance.stance_id != card.required_stance.stance_id:
			warnings.append(
				"Card %d (%s) requires stance '%s' but card %d (%s) exits to '%s'" % [
					i, card.move_name, card.required_stance.stance_name,
					(i - 1) % moves.size(), prev.move_name, prev.exit_stance.stance_name
				]
			)
	return warnings


func get_move_at(index: int) -> MoveCard:
	if moves.is_empty():
		return null
	return moves[index % moves.size()]
