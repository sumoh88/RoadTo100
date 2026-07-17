extends Reference
class_name CardDatabase

# Mirrors games/roadto100/card_database.py factory functions + cards.py build_deck()
# Every factory method reproduces the exact card_id, name, value, color, and
# metadata produced by the Python reference implementation.
#
# NOTE: uses load() and literal strings to avoid class_name cross-references
# at parse time in Godot 3 CLI mode.

var _CardData = null  # cached by _get_carddata_class()
var _CardDataLoaded = false

func _get_carddata_class():
	if !_CardDataLoaded:
		_CardData = load("res://engine/CardData.gd")
		_CardDataLoaded = true
	return _CardData

func build_deck():
	var cards = []
	# 30 increment cards (3 copies per value 1..10)
	for v in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		for c in range(3):
			cards.append(self.make_increment_card(v, c))
	# 10 Jolly
	for c in range(10):
		cards.append(self.make_jolly_card(c))
	# 7 Gold
	for v in [12, 23, 34, 45, 56, 67, 78]:
		cards.append(self.make_gold_card(v))
	# 3 x 89
	for c in range(3):
		cards.append(self.make_89_card(c))
	# 5 x +11
	for c in range(5):
		cards.append(self.make_plus11_card(c))
	# 5 x Imbroglio
	for c in range(5):
		cards.append(self.make_imbroglio_card(c))
	return cards

func make_increment_card(value, copy_index = 0):
	var CD = _get_carddata_class()
	return CD.new(
		"increment_" + str(value) + "_" + str(copy_index),
		"+" + str(value),
		value,
		"arancione",
		{"card_type": "increment", "category": "normale", "destination": "scarti"}
	)

func make_jolly_card(copy_index = 0):
	var CD = _get_carddata_class()
	return CD.new(
		"jolly_" + str(copy_index),
		"Jolly",
		null,
		"arancione",
		{"card_type": "jolly", "category": "normale", "destination": "scarti"}
	)

func make_gold_card(value):
	var CD = _get_carddata_class()
	return CD.new(
		"gold_" + str(value),
		str(value),
		value,
		"dorato",
		{"card_type": "gold", "category": "gold", "destination": "piatto"}
	)

func make_89_card(copy_index = 0):
	var CD = _get_carddata_class()
	return CD.new(
		"card89_" + str(copy_index),
		"89",
		89,
		"viola",
		{"card_type": "special", "category": "speciale", "destination": "piatto"}
	)

func make_plus11_card(copy_index = 0):
	var CD = _get_carddata_class()
	return CD.new(
		"plus11_" + str(copy_index),
		"+11",
		11,
		"rosso",
		{"card_type": "special", "category": "speciale", "destination": "scarti"}
	)

func make_imbroglio_card(copy_index = 0):
	var CD = _get_carddata_class()
	return CD.new(
		"imbroglio_" + str(copy_index),
		"Imbroglio",
		null,
		"verde",
		{"card_type": "imbroglio", "category": "speciale", "destination": "scarti"}
	)
