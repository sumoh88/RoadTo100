extends Reference
class_name Hand

# Mirrors simulator/domain/hand.py
# Manages cards currently held by a player.

var cards = []  # Array of CardData

func _init(p_cards = []):
	cards = p_cards.duplicate()

func size():
	return cards.size()

func is_empty():
	return cards.empty()

func add_card(card):
	cards.append(card)

func add_cards(new_cards):
	for c in new_cards:
		cards.append(c)

# Remove a specific card from the hand by reference.
# Mirrors Python: if card in self.cards: self.cards.remove(card); return card; return None
func remove_card(card):
	var idx = cards.find(card)
	if idx >= 0:
		return cards.pop_at(idx)
	return null

func contains(card):
	return cards.find(card) >= 0

func clear():
	cards.clear()
