extends Reference

# Porting of games/roadto100/rules.py — RoadTo100RuleSet
# Every method, helper, constant, and logic sequence mirrors the Python
# reference implementation exactly.

const PLAY_CARD_ACTION = "play_card"
const CHANGE_CARD_ACTION = "change_card"
const REVEAL_GOLD_ACTION = "reveal_gold"
const RESET_HAND_ACTION = "reset_hand"

const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}

# ---------------------------------------------------------------------------
# Card type helpers (mirror Python staticmethods)
# ---------------------------------------------------------------------------

func _is_increment_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	return ct == "increment"

func _is_jolly_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	return ct == "jolly" or card.name.to_lower() == "jolly"

func _is_gold_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	if ct == "gold":
		return true
	var n = card.name.to_lower()
	return n in ["12", "23", "34", "45", "56", "67", "78"]

func _is_imbroglio_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	return ct == "imbroglio" or card.name.to_lower() == "imbroglio"

func _is_special_89_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	return ct == "special" and card.name == "89"

func _is_plus11_card(card):
	var ct = str(card.metadata.get("card_type", "")).to_lower()
	return ct == "special" and card.name == "+11"

# ---------------------------------------------------------------------------
# Deck helpers (mirror Python staticmethods)
# ---------------------------------------------------------------------------

func _reshuffle_discard_into_deck(game):
	"""Move discard cards (except the last) back to deck, then shuffle.

	If only one card remains in the discard, it is moved to deck too
	so the game does not stall.
	"""
	if game.discard_pile.empty():
		return
	if game.discard_pile.size() == 1:
		var cards = game.discard_pile.duplicate()
		game.discard_pile.clear()
		game.deck.add_cards(cards)
	else:
		var last_card = game.discard_pile.pop_back()
		var cards = game.discard_pile.duplicate()
		game.discard_pile.clear()
		game.discard_pile.append(last_card)
		game.deck.add_cards(cards)
	game.deck.shuffle()

func _draw_cards(game, count):
	"""Draw up to count cards, reconstituting deck from discard if needed."""
	var drawn = []
	while not game.deck.is_empty() and drawn.size() < count:
		var card = game.deck.draw()
		if card != null:
			drawn.append(card)
	if drawn.size() < count:
		_reshuffle_discard_into_deck(game)
		while not game.deck.is_empty() and drawn.size() < count:
			var card = game.deck.draw()
			if card != null:
				drawn.append(card)
	return drawn

func _draw_or_reshuffle(game):
	"""Draw a card, reshuffling discard into deck if the deck is empty."""
	var drawn = _draw_cards(game, 1)
	if drawn.empty():
		return null
	return drawn[0]

func _matching_gold_card(player, plateau_value):
	"""Return a matching Gold card from the player's hand, if present."""
	for card in player.hand.cards:
		if _is_gold_card(card) and card.value == plateau_value:
			return card
	return null

# ---------------------------------------------------------------------------
# RuleSet interface
# ---------------------------------------------------------------------------

func initialize_game(game):
	"""Initialize the game state for a new match. (mirrors initialize_game)"""
	game.phase = 1  # GameConstants.GamePhase.PLAYING
	game.winner = null
	game.turn_number = 0
	game.discard_pile.clear()
	game.metadata["piatto"] = 0
	game.metadata["plateau_cards"] = []
	game.metadata["advantage_turn"] = false
	game.metadata["advantage_player_id"] = null
	game.metadata["target_score"] = 100  # TARGET_SCORE
	game.metadata["turn_phase"] = "start"

	for player in game.players:
		player.clear_hand()
		player.metadata["score"] = 0

	if game.players.size() > 0:
		game.deck.shuffle()
		game.current_player_index = randi() % game.players.size()
		game.set_current_player(game.players[game.current_player_index])
		for i in range(3):  # INITIAL_HAND_SIZE
			for player in game.players:
				var card = game.deck.draw()
				if card != null:
					player.receive_card(card)
	else:
		game.set_current_player(null)

func get_available_actions(game):
	"""Return available actions for the current player.
	Each action is a Dictionary: {"action_type": str, "card": CardData, ...}
	"""
	var current_player = game.current_player()
	if current_player == null:
		return []

	var actions = []

	var advantage_turn = bool(game.metadata.get("advantage_turn", false))
	var advantage_player_id = game.metadata.get("advantage_player_id", null)
	var is_advantage_player = false
	if advantage_turn and advantage_player_id != null and current_player.player_id == advantage_player_id:
		is_advantage_player = true

	# Gold reveal at start of turn
	if game.metadata.get("turn_phase") == "start":
		var plateau_value = int(game.metadata.get("piatto", 0))
		var matching_gold = _matching_gold_card(current_player, plateau_value)
		if matching_gold != null:
			actions.append({"action_type": REVEAL_GOLD_ACTION, "card": matching_gold})

	# During GdV: non-advantage players with no playable cards get RESET_HAND
	if advantage_turn and not is_advantage_player:
		var has_playable = false
		for c in current_player.hand.cards:
			if _is_increment_card(c) or _is_jolly_card(c) or _is_plus11_card(c):
				has_playable = true
				break
		if not has_playable and not current_player.hand.cards.empty():
			actions.append({"action_type": RESET_HAND_ACTION})
			return actions
		if current_player.hand.cards.empty():
			actions.append({"action_type": RESET_HAND_ACTION})
			return actions

	# Safety net: if the player has no cards at all, offer RESET_HAND
	if current_player.hand.cards.empty():
		actions.append({"action_type": RESET_HAND_ACTION})
		return actions

	# Card play actions
	for card in current_player.hand.cards:
		# During GdV: only Orange cards and +11 can be played
		if advantage_turn:
			if not (_is_increment_card(card) or _is_jolly_card(card) or _is_plus11_card(card)):
				continue

		if _is_jolly_card(card):
			for chosen_value in range(1, 11):
				actions.append({
					"action_type": PLAY_CARD_ACTION,
					"card": card,
					"selected_value": chosen_value
				})
		elif _is_imbroglio_card(card):
			var plateau_value = int(game.metadata.get("piatto", 0))
			for chosen_value in range(-15, 16):
				if chosen_value == 0:
					continue
				var candidate = plateau_value + chosen_value
				if 0 <= candidate and candidate <= 99:  # TARGET_SCORE - 1
					actions.append({
						"action_type": PLAY_CARD_ACTION,
						"card": card,
						"selected_value": chosen_value
					})
		elif _is_special_89_card(card):
			actions.append({"action_type": PLAY_CARD_ACTION, "card": card})
		elif _is_plus11_card(card):
			actions.append({"action_type": PLAY_CARD_ACTION, "card": card})
		elif _is_gold_card(card):
			actions.append({"action_type": PLAY_CARD_ACTION, "card": card})
		elif card.value != null:
			actions.append({"action_type": PLAY_CARD_ACTION, "card": card})

	# CHANGE_CARD is always available for every card in hand
	for card in current_player.hand.cards:
		actions.append({"action_type": CHANGE_CARD_ACTION, "card": card})

	return actions

func validate_action(game, action_dict):
	"""Return whether the provided action is valid. (mirrors validate_action)"""
	if action_dict == null or typeof(action_dict) != TYPE_DICTIONARY:
		return false

	var current_player = game.current_player()
	if current_player == null:
		return false

	var card = action_dict.get("card", null)
	if action_dict["action_type"] != RESET_HAND_ACTION:
		if card == null or typeof(card) != TYPE_OBJECT or not current_player.has_card(card):
			return false

	var advantage_turn = bool(game.metadata.get("advantage_turn", false))
	var advantage_player_id = game.metadata.get("advantage_player_id", null)
	var is_advantage_player = false
	if advantage_turn and advantage_player_id != null and current_player.player_id == advantage_player_id:
		is_advantage_player = true

	if action_dict["action_type"] == RESET_HAND_ACTION:
		if current_player.hand.cards.empty():
			return true
		return advantage_turn and not is_advantage_player

	if action_dict["action_type"] == REVEAL_GOLD_ACTION:
		var plateau_value = int(game.metadata.get("piatto", 0))
		return (card != null and typeof(card) == TYPE_OBJECT
				and current_player.has_card(card)
				and _is_gold_card(card)
				and card.value == plateau_value)

	if action_dict["action_type"] == CHANGE_CARD_ACTION:
		return card != null and typeof(card) == TYPE_OBJECT and current_player.has_card(card)

	# Card play actions during GdV: only Orange and +11 allowed
	if advantage_turn:
		if not (_is_increment_card(card) or _is_jolly_card(card) or _is_plus11_card(card)):
			return false

	if _is_jolly_card(card):
		var selected_value = action_dict.get("selected_value", null)
		return typeof(selected_value) == TYPE_INT and 1 <= selected_value and selected_value <= 10

	if _is_imbroglio_card(card):
		var selected_value = action_dict.get("selected_value", null)
		if typeof(selected_value) != TYPE_INT or selected_value == 0:
			return false
		var plateau_value = int(game.metadata.get("piatto", 0))
		var candidate = plateau_value + selected_value
		return 0 <= candidate and candidate <= 99

	if _is_special_89_card(card):
		return card.value != null

	if _is_plus11_card(card):
		return card.value != null

	if _is_gold_card(card):
		return card.value != null

	return card.value != null

func apply_action(game, action_dict):
	"""Apply a validated action to the game state. (mirrors apply_action)"""
	var current_player = game.current_player()
	if current_player == null:
		return

	var card = action_dict.get("card", null)
	if action_dict["action_type"] != RESET_HAND_ACTION:
		if card == null:
			return

	if action_dict["action_type"] == RESET_HAND_ACTION:
		var cards_to_reset = current_player.hand.cards.duplicate()
		current_player.clear_hand()
		for c in cards_to_reset:
			game.deck.add_card(c)
		game.deck.shuffle()
		for c in _draw_cards(game, 3):
			current_player.receive_card(c)
		game.metadata["turn_phase"] = "action"
		return

	if action_dict["action_type"] == REVEAL_GOLD_ACTION:
		current_player.play_card(card)
		game.deck.add_card(card)
		game.deck.shuffle()
		var drawn_card = _draw_or_reshuffle(game)
		if drawn_card != null:
			current_player.receive_card(drawn_card)
		game.metadata["turn_phase"] = "action"
		return

	if action_dict["action_type"] == CHANGE_CARD_ACTION:
		current_player.play_card(card)
		game.deck.add_card(card)
		game.deck.shuffle()
		var drawn_card = _draw_or_reshuffle(game)
		if drawn_card != null:
			current_player.receive_card(drawn_card)
		game.metadata["turn_phase"] = "action"
		return

	# --- PLAY_CARD_ACTION ---
	current_player.play_card(card)

	if not _is_gold_card(card) and not _is_special_89_card(card):
		game.discard_pile.append(card)

	var increment = 0
	if _is_jolly_card(card):
		var chosen_value = int(action_dict.get("selected_value", 1))
		increment = chosen_value
	elif _is_imbroglio_card(card):
		increment = int(action_dict.get("selected_value", 0))
	elif _is_special_89_card(card):
		increment = 89
		game.metadata["advantage_turn"] = true
		game.metadata["advantage_player_id"] = current_player.player_id
	elif _is_plus11_card(card):
		var at = bool(game.metadata.get("advantage_turn", false))
		if at:
			increment = 11
			game.winner = current_player
		else:
			var plateau_cards = game.metadata.get("plateau_cards", [])
			var gold_chain_value = null
			if !plateau_cards.empty():
				var last_card = plateau_cards[plateau_cards.size() - 1]
				if _is_gold_card(last_card):
					gold_chain_value = GOLD_CHAIN.get(int(last_card.value), null)
			if gold_chain_value != null:
				increment = gold_chain_value
				if increment == 89:
					game.metadata["advantage_turn"] = true
					game.metadata["advantage_player_id"] = current_player.player_id
				game.metadata["_plus11_gold_chain"] = true
			else:
				increment = 11
	elif _is_gold_card(card):
		increment = int(card.value)
		game.metadata["plateau_value"] = increment
		var gold_cards = game.metadata.get("gold_cards", [])
		gold_cards.append(card)
		game.metadata["gold_cards"] = gold_cards
	else:
		increment = int(card.value)

	var plateau = int(game.metadata.get("piatto", 0))
	if _is_gold_card(card) or game.metadata.has("_plus11_gold_chain"):
		if game.metadata.has("_plus11_gold_chain"):
			game.metadata.erase("_plus11_gold_chain")
		plateau = increment
	else:
		plateau += increment
	game.metadata["piatto"] = min(plateau, 100)  # TARGET_SCORE

	if not game.metadata.has("plateau_cards"):
		game.metadata["plateau_cards"] = []
	game.metadata["plateau_cards"].append(card)

	current_player.metadata["score"] = int(current_player.metadata.get("score", 0)) + increment
	if int(game.metadata.get("piatto", 0)) >= 100:  # TARGET_SCORE
		var at = bool(game.metadata.get("advantage_turn", false))
		var adv_pid = game.metadata.get("advantage_player_id", null)
		if not at or (adv_pid != null and current_player.player_id == adv_pid):
			game.winner = current_player

	game.metadata["turn_phase"] = "action"
	var drawn_card = _draw_or_reshuffle(game)
	if drawn_card != null:
		current_player.receive_card(drawn_card)

func advance_turn(game):
	"""Advance the game flow after an action has been processed.
	(mirrors advance_turn)"""
	if game.players.empty():
		return

	var previous_player_index = game.current_player_index

	if game.current_player_index == null:
		game.current_player_index = 0
	else:
		game.current_player_index = (game.current_player_index + 1) % game.players.size()

	game.set_current_player(game.players[game.current_player_index])
	game.metadata["turn_phase"] = "start"
	game.turn_number += 1

	# GdV ends when the advantage player completes their NEXT turn
	var advantage_turn = bool(game.metadata.get("advantage_turn", false))
	var advantage_player_id = game.metadata.get("advantage_player_id", null)
	if advantage_turn and advantage_player_id != null:
		var prev_player = game.players[previous_player_index]
		if prev_player.player_id == advantage_player_id:
			if game.metadata.get("_advantage_turn_done", false):
				game.metadata["advantage_turn"] = false
				game.metadata["advantage_player_id"] = null
				game.metadata["_advantage_turn_done"] = false
			else:
				game.metadata["_advantage_turn_done"] = true

func is_game_over(game):
	"""Return whether the game has reached a terminal state."""
	return game.winner != null

func get_winner(game):
	"""Return the winning player, if any."""
	return game.winner
