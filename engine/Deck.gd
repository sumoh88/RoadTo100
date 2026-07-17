extends Reference
class_name Deck

# Mirrors simulator/domain/deck.py
# Cards are stored as an Array of CardData.
# The "top" of the deck for drawing is the last element (pop_back).

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

# Draw the top card (last element, matching Python list.pop())
func draw():
	if is_empty():
		return null
	return cards.pop_back()

# Draw multiple cards
func draw_many(count):
	var drawn = []
	for i in range(min(count, cards.size())):
		drawn.append(draw())
	return drawn

# Fisher-Yates shuffle (matching Python random.shuffle semantics)
func shuffle():
	for i in range(cards.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

func clear():
	cards.clear()
