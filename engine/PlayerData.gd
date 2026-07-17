extends Reference
class_name PlayerData

# Mirrors simulator/domain/player.py
# Represents a player with identity and hand.

var player_id = ""
var name = ""
var hand = null
var metadata = {}

func _init(p_player_id = "", p_name = "", p_hand = null, p_metadata = {}):
	player_id = p_player_id
	name = p_name
	# Avoid class_name reference at parse time — use load() for fallback
	if p_hand != null:
		hand = p_hand
	else:
		hand = (load("res://engine/Hand.gd") as Script).new()
	metadata = p_metadata.duplicate()

func receive_card(card):
	hand.add_card(card)

func receive_cards(new_cards):
	hand.add_cards(new_cards)

func play_card(card):
	return hand.remove_card(card)

func has_card(card):
	return hand.contains(card)

func clear_hand():
	hand.clear()
