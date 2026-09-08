extends Reference
class_name RoadTo100AI

# RoadTo100 AI Bot Implementation.
# A heuristic-based bot that makes strategic decisions using visible information only.
# Design: score each available action, pick the highest with small random tie-breaking.
#
# Personality profiles are configured via constructor parameters that override
# the default weights. Different weight configurations produce different play
# styles while reusing the same core scoring logic.

# --- Default balanced weights (can be overridden per personality) ---
var W_IMMEDIATE_WIN = 10000       # Score for winning immediately
var W_ADVANCE = 100               # Base score per point of progress toward 100
var W_PLATEAU_DANGER = 25         # Penalty per point above 92 left to next player (danger zone)
var W_INCREMENT_HIGH = 3          # Bonus for high-value increment cards (8-10)
var W_INCREMENT_MED = 2           # Bonus for medium increment (5-7)
var W_INCREMENT_LOW = 1           # Base score for low increment (1-4)
var W_JOLLY_FLEXIBILITY = 15      # Jolly is flexible, add bonus
var W_GOLD_ACTIVATE_SR = 60       # Gold activates Safe Round - strategic value
var W_PLUS11_GOLD_CHAIN = 70      # +11 after Gold creates transformed Gold
var W_PLUS11_NORMAL = 40          # +11 just adds 11 points
var W_PLUS11_HOLD_BACK = -75      # Penalty for using +11 when not strategic (must exceed max advancement 110)
var W_IMBROGLIO_STRATEGIC = 25    # Imbroglio can be used strategically
var W_GDV_BONUS = 30              # Bonus during GdV for +11 or high increments
var W_CHANGE_CARD = -10           # Cambio Carta is last resort (negative score)
const TIE_BREAKER_JITTER = 5      # Max random jitter for tie-breaking

const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}


func select_action(available_actions, snapshot):
	if available_actions == null or available_actions.size() == 0:
		return {"action_type": "reset_hand"}

	var best_score = -1000000.0
	var best_action = null

	for i in range(available_actions.size()):
		var action = available_actions[i]
		var score = _score_action(snapshot, action)

		# For Jolly/Imbroglio with choices, find the best value
		var chosen_value = -999999
		if action.get("choices", []).size() > 0:
			chosen_value = _select_best_choice(snapshot, action)

		# Add small random jitter to avoid predictable patterns
		var jitter = randi() % (2 * TIE_BREAKER_JITTER + 1) - TIE_BREAKER_JITTER
		var final_score = score + jitter

		if final_score > best_score:
			best_score = final_score
			# Build the result action with selected_value if applicable
			if chosen_value != -999999:
				best_action = {"action_type": action["action_type"], "card_id": action["card_id"], "selected_value": chosen_value}
			else:
				best_action = {"action_type": action["action_type"], "card_id": str(action.get("card_id", ""))}

	if best_action == null:
		return {"action_type": "reset_hand"}

	return best_action


func _score_action(snapshot, action):
	var action_type = str(action.get("action_type", ""))
	var card_id = str(action.get("card_id", ""))
	var choices = action.get("choices", [])

	# Get game state info from snapshot
	var plateau = int(snapshot.get("piatto", 0))
	var plateau_cards = snapshot.get("plateau_cards", [])
	var special_round_active = bool(snapshot.get("special_round_active", false))
	var special_round_player_id = str(snapshot.get("special_round_player_id", ""))
	var special_round_type = str(snapshot.get("special_round_type", "advantage"))
	var current_player_index = int(snapshot.get("current_player_index", -1))

	# Determine if this player is the activator of an active Special Round
	var players = snapshot.get("players", [])
	var is_activator = false
	if special_round_active and special_round_player_id != "" and current_player_index >= 0:
		var current_pid = str(players[current_player_index].get("id", "")) if current_player_index < players.size() else ""
		is_activator = (current_pid == special_round_player_id)

	# Get last card on plateau for Gold chain logic
	var last_plateau_card = null
	if plateau_cards.size() > 0:
		last_plateau_card = plateau_cards[plateau_cards.size() - 1]

	# --- RESET_HAND scoring ---
	if action_type == "reset_hand":
		return 0.0

	# --- CHANGE_CARD scoring (last resort) ---
	if action_type == "change_card":
		return float(W_CHANGE_CARD)

	# --- PLAY_CARD scoring ---
	if action_type != "play_card" or card_id == "":
		return 0.0

	# Find the card to determine its type and value
	var card = _find_card_by_id(snapshot, card_id)
	if card == null:
		return 0.0

	var card_type = str(card.get("card_type", "")).to_lower()
	var card_name = str(card.get("name", ""))

	# --- Immediate win detection ---
	var effective_value = _get_effective_value(card, last_plateau_card, choices)
	if _would_win(plateau, card, effective_value, last_plateau_card, special_round_active, special_round_type, is_activator):
		return float(W_IMMEDIATE_WIN)

	# Score based on card type and situation
	var score = 0.0

	# Calculate bounce potential and advancement toward 100
	var card_type_check = str(card.get("card_type", "")).to_lower()
	var card_name_check = str(card.get("name", ""))
	var is_gold_check = _is_gold_card(card)
	var is_89_check = (card_type_check == "special" and card_name_check == "89")
	var is_plus11_check = (card_type_check == "special" and card_name_check == "+11")
	var is_gold_chain = is_plus11_check and last_plateau_card != null and _is_gold_card(last_plateau_card)

	if is_gold_check or is_89_check or is_gold_chain:
		# Gold/89/Gold-chain set plateau directly, no bounce possible
		score += (effective_value * W_ADVANCE) / 10.0
	else:
		var raw_new_plateau = plateau + effective_value
		var no_bounce = is_plus11_check or (special_round_active and special_round_type == "advantage" and is_activator)

		# Compute actual resulting plateau using engine formula
		var result_plateau
		if raw_new_plateau > 100 and not no_bounce:
			result_plateau = 200 - raw_new_plateau
		else:
			result_plateau = raw_new_plateau

		# Progress: reward movement toward 100 (only positive changes)
		var actual_change = result_plateau - plateau
		if actual_change > 0:
			if result_plateau < 93:
				score += (actual_change * W_ADVANCE) / 10.0
			else:
				score += (actual_change * W_ADVANCE) / 20.0

		# Strategic safety: net danger change vs starting position
		var start_danger = max(0, plateau - 92)
		var end_danger = max(0, result_plateau - 92)
		if end_danger < start_danger:
			score += (start_danger - end_danger) * W_PLATEAU_DANGER
		elif end_danger > start_danger:
			score -= (end_danger - start_danger) * W_PLATEAU_DANGER

	# Card-specific scoring
	if card_type == "increment":
		var value = int(card.get("value", 0))
		if value >= 8:
			score += float(W_INCREMENT_HIGH)
		elif value >= 5:
			score += float(W_INCREMENT_MED)
		else:
			score += float(W_INCREMENT_LOW)

	elif card_type == "jolly":
		score += float(W_JOLLY_FLEXIBILITY)

	elif card_type == "gold":
		score += float(W_GOLD_ACTIVATE_SR)

	elif card_type == "imbroglio":
		score += float(W_IMBROGLIO_STRATEGIC)

	elif card_type == "special":
		if card_name == "+11":
			# Check if this +11 would trigger Gold chain (strategic use)
			if last_plateau_card != null and _is_gold_card(last_plateau_card):
				score += float(W_PLUS11_GOLD_CHAIN)
			elif special_round_active and special_round_type == "advantage" and is_activator:
				# +11 during GdV as activator is strategic
				score += float(W_PLUS11_NORMAL + W_GDV_BONUS)
			else:
				# Normal +11 use - apply hold-back penalty unless near win
				if !_would_win(plateau, card, effective_value, last_plateau_card, special_round_active, special_round_type, is_activator):
					score += float(W_PLUS11_HOLD_BACK)
				else:
					score += float(W_PLUS11_NORMAL)

		elif card_name == "89":
			# 89 is high value but risky (starts GdV)
			score += 50.0  # Strategic value of starting GdV

	# Special Round bonuses
	if special_round_active and special_round_type == "advantage" and is_activator:
		if card_type == "special" and card_name == "+11":
			score += float(W_GDV_BONUS)
		elif card_type == "increment" and int(card.get("value", 0)) >= 8:
			score += W_GDV_BONUS / 2.0

	return score


func _select_best_choice(snapshot, action):
	"""Select the best value for Jolly/Imbroglio from available choices."""
	var choices = action.get("choices", [])
	if choices.size() == 0:
		return -999999

	var plateau = int(snapshot.get("piatto", 0))
	var card_id = str(action.get("card_id", ""))
	var card = _find_card_by_id(snapshot, card_id)
	if card == null:
		return -999999

	var card_type = str(card.get("card_type", "")).to_lower()
	var best_value = int(choices[0].get("parameters", {}).get("selected_value", 5))
	var best_score = -1000000.0

	for i in range(choices.size()):
		var val = int(choices[i].get("parameters", {}).get("selected_value", 0))
		var score = _score_choice(plateau, card_type, val)
		if score > best_score:
			best_score = score
			best_value = val

	return best_value


func _score_choice(plateau, card_type, value):
	"""Score a specific Jolly/Imbroglio value choice."""
	var target = 100

	if card_type == "jolly":
		# Jolly: choose value that gets closest to 100 without bouncing
		var new_plateau = plateau + value
		if new_plateau == target:
			return W_IMMEDIATE_WIN  # Immediate win!
		elif new_plateau > target:
			# Would bounce — evaluate actual resulting plateau
			var result_plateau = 2 * target - new_plateau
			var s = 0.0
			var actual_change = result_plateau - plateau
			if actual_change > 0:
				if result_plateau < 93:
					s += (actual_change * W_ADVANCE) / 10.0
				else:
					s += (actual_change * W_ADVANCE) / 20.0
			var start_danger = max(0, plateau - 92)
			var end_danger = max(0, result_plateau - 92)
			if end_danger < start_danger:
				s += (start_danger - end_danger) * W_PLATEAU_DANGER
			elif end_danger > start_danger:
				s -= (end_danger - start_danger) * W_PLATEAU_DANGER
			return s
		else:
			# Good advancement, higher is better
			return value * W_ADVANCE / 10.0

	elif card_type == "imbroglio":
		# Imbroglio: choose value that maximizes progress without exceeding 99
		var new_plateau = plateau + value
		if new_plateau < 0 or new_plateau > target - 1:
			return -1000.0  # Invalid choice (shouldn't happen with valid choices)
		# Imbroglio can never win directly (capped at 99), so maximize progress
		return new_plateau * W_ADVANCE / 10.0

	return 0.0


func _would_win(plateau, card, effective_value, last_plateau_card, sr_active, sr_type, is_activator):
	"""Check if playing this card would win immediately."""
	var target = 100
	var card_type = str(card.get("card_type", "")).to_lower()
	var card_name = str(card.get("name", ""))

	var is_gold = _is_gold_card(card)
	var is_89 = (card_type == "special" and card_name == "89")
	var is_plus11 = (card_type == "special" and card_name == "+11")

	# Gold, 89, and +11 with Gold chain never win directly
	if is_gold or is_89:
		return false

	if is_plus11 and last_plateau_card != null and _is_gold_card(last_plateau_card):
		# Gold chain sets plateau to transformed value (23-89), never wins
		return false

	# Normal cards: compute new plateau
	var new_plateau = plateau + effective_value

	if is_plus11:
		# +11 wins at >= 100 regardless of bounce/GdV
		return new_plateau >= target

	# Check SR state for normal cards
	if sr_active and sr_type == "advantage":
		if is_activator:
			# GdV activator: no bounce, wins at >= 100
			return new_plateau >= target
		else:
			# GdV non-activator: capped to 99, never wins
			return false

	# Safe Round or no SR: win at exactly 100 (bounce prevents >100 from winning)
	if sr_active and sr_type == "safe":
		return new_plateau == target

	# No SR: win at exactly 100 (bounce for >100)
	return new_plateau == target


func _calculate_new_plateau(plateau, card, effective_value, last_plateau_card, sr_active, sr_type, is_activator):
	"""Calculate the resulting plateau value after playing this card."""
	var target = 100
	var card_type = str(card.get("card_type", "")).to_lower()
	var card_name = str(card.get("name", ""))

	var is_gold = _is_gold_card(card)
	var is_89 = (card_type == "special" and card_name == "89")
	var is_plus11 = (card_type == "special" and card_name == "+11")

	# Gold/89 set plateau directly
	if is_gold or is_89:
		return int(card.get("value", 0))

	# +11 with Gold chain sets plateau to transformed value
	if is_plus11 and last_plateau_card != null and _is_gold_card(last_plateau_card):
		var gold_value = int(last_plateau_card.get("value", 0))
		return int(GOLD_CHAIN.get(gold_value, 11))

	# Normal: add to plateau
	var new_plateau = plateau + effective_value

	# Apply bounce logic
	if is_plus11 or (sr_active and sr_type == "advantage" and is_activator):
		return new_plateau  # No bounce for +11 or GdV activator

	if sr_active and sr_type == "advantage":
		# GdV non-activator: cap to 99, bounce for >100
		if new_plateau == target:
			return target - 1
		elif new_plateau > target:
			return (2 * target) - new_plateau

	# GS or no SR: normal bounce
	if new_plateau > target:
		return (2 * target) - new_plateau

	return new_plateau


func _get_effective_value(card, last_plateau_card, choices):
	var card_type = str(card.get("card_type", "")).to_lower()

	# For Jolly with choices, use the best choice value for scoring
	if card_type == "jolly" and choices.size() > 0:
		return _select_best_choice_from_array(choices)

	# For Imbroglio with choices, use the best choice value
	if card_type == "imbroglio" and choices.size() > 0:
		return _select_best_imbroglio_value(choices)

	# For +11 with Gold chain, calculate transformed value
	if card_type == "special" and str(card.get("name", "")) == "+11":
		if last_plateau_card != null and _is_gold_card(last_plateau_card):
			var gold_value = int(last_plateau_card.get("value", 0))
			return int(GOLD_CHAIN.get(gold_value, 11))

	# Default: use card's value
	var val = card.get("value", 0)
	return int(val) if val != null else 0


func _select_best_choice_from_array(choices):
	"""Select best Jolly value from choices array (for scoring)."""
	if choices.size() == 0:
		return 5
	# Use the highest value that doesn't cause bounce - but for scoring we estimate
	# The actual selection is done in _select_best_choice
	var max_val = 1
	for i in range(choices.size()):
		var v = int(choices[i].get("parameters", {}).get("selected_value", 0))
		if v > max_val:
			max_val = v
	return max_val


func _select_best_imbroglio_value(choices):
	"""Select best Imbroglio value from choices array (for scoring)."""
	if choices.size() == 0:
		return 0
	# For Imbroglio, prefer positive values for progress
	var best = 0
	for i in range(choices.size()):
		var v = int(choices[i].get("parameters", {}).get("selected_value", 0))
		if v > best:
			best = v
	return best


func _is_gold_card(card):
	if card == null:
		return false
	var ct = str(card.get("card_type", "")).to_lower()
	var card_name = str(card.get("name", ""))
	return ct == "gold" or card_name in ["12", "23", "34", "45", "56", "67", "78"]


func _find_card_by_id(snapshot, card_id):
	var players = snapshot.get("players", [])
	var current_player_index = int(snapshot.get("current_player_index", -1))

	if current_player_index < 0 or current_player_index >= players.size():
		return null

	var hand = players[current_player_index].get("hand", [])
	for i in range(hand.size()):
		if str(hand[i].get("card_id", "")) == card_id:
			return hand[i]
	return null
