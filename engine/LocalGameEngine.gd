extends "res://engine/GameStateProvider.gd"
class_name LocalGameEngine

# Concrete GameStateProvider that runs the game engine locally.
# Manages a GameState + RoadTo100Rules, exposes serializable snapshots
# and events (no Reference objects in public data).
#
# Signals (inherited from GameStateProvider):
#   game_started(snapshot)
#   action_completed(result)
#   action_rejected(error_message)

const PLAY_CARD_ACTION = "play_card"
const CHANGE_CARD_ACTION = "change_card"
const REVEAL_GOLD_ACTION = "reveal_gold"
const RESET_HAND_ACTION = "reset_hand"

var _GameState = load("res://engine/GameState.gd")
var _PlayerData = load("res://engine/PlayerData.gd")
var _Deck = load("res://engine/Deck.gd")
var _CardDatabase = load("res://engine/CardDatabase.gd")
var _RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")

var game_state = null
var rules = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_game(player_count):
	"""Initialize a new game with the given number of players."""
	var CardDatabase = _CardDatabase.new()

	# Create players
	var players = []
	for i in range(player_count):
		var p = _PlayerData.new("player_" + str(i + 1), "Player " + str(i + 1))
		players.append(p)

	# Build game state
	game_state = _GameState.new()
	game_state.add_players(players)
	var deck_cards = CardDatabase.build_deck()
	for c in deck_cards:
		game_state.deck.add_card(c)

	# Initialize rules
	rules = _RoadTo100Rules.new()
	rules.initialize_game(game_state)

	emit_signal("game_started", _build_snapshot())


func send_action(action_dict):
	"""Process a player action. action_dict uses card_id strings (not CardData)."""
	if game_state == null or rules == null:
		emit_signal("action_rejected", "Game not started")
		return

	var at = action_dict.get("action_type", "")
	if at == "":
		emit_signal("action_rejected", "Missing action_type")
		return

	# Resolve card_id to CardData (if present)
	var card_id = action_dict.get("card_id", "")
	var card = null
	if card_id != "":
		card = _resolve_card(card_id)
		if card == null:
			emit_signal("action_rejected", "Card not found: " + str(card_id))
			return

	# Build rules-compatible action dict (with CardData object)
	var rules_action = {"action_type": at}
	if card != null:
		rules_action["card"] = card
	if action_dict.has("selected_value"):
		rules_action["selected_value"] = action_dict["selected_value"]

	# Capture before-state for event generation
	var before = _capture_before_state()

	# Validate
	if not rules.validate_action(game_state, rules_action):
		emit_signal("action_rejected", "Invalid action")
		return

	# Apply action
	rules.apply_action(game_state, rules_action)

	# Generate action-phase events
	var events = _generate_events(before, rules_action, card)

	# Advance turn
	rules.advance_turn(game_state)

	# Generate turn-phase events (turn_changed, advantage_ended)
	var turn_events = _generate_turn_events(before, rules_action, card)
	for e in turn_events:
		events.append(e)

	# Build final snapshot
	var snapshot = _build_snapshot()

	emit_signal("action_completed", {
		"snapshot": snapshot,
		"events": events
	})


# ---------------------------------------------------------------------------
# Card / state helpers
# ---------------------------------------------------------------------------

func _card_to_dict(card):
	"""Convert a CardData to a plain serializable Dictionary."""
	if card == null:
		return null
	return {
		"card_id": card.card_id,
		"name": card.name,
		"value": card.value,
		"color": card.color,
		"card_type": card.metadata.get("card_type", ""),
	}


func _resolve_card(card_id):
	"""Find a CardData by card_id in the current game state."""
	# Search current player's hand first (most common)
	var cp = game_state.current_player()
	if cp != null:
		for c in cp.hand.cards:
			if c.card_id == card_id:
				return c

	# Search discard pile
	for c in game_state.discard_pile:
		if c.card_id == card_id:
			return c

	# Search deck
	for c in game_state.deck.cards:
		if c.card_id == card_id:
			return c

	# Search all players' hands
	for p in game_state.players:
		for c in p.hand.cards:
			if c.card_id == card_id:
				return c

	return null


func _get_hand_card_ids(player):
	"""Return an array of card_id strings for a player's hand."""
	var ids = []
	if player == null:
		return ids
	for c in player.hand.cards:
		ids.append(c.card_id)
	return ids


# ---------------------------------------------------------------------------
# Snapshot building
# ---------------------------------------------------------------------------

func _build_snapshot():
	"""Build the current authoritative game state as a plain Dictionary."""
	var players_data = []
	for p in game_state.players:
		var hand_data = []
		for c in p.hand.cards:
			hand_data.append(_card_to_dict(c))
		players_data.append({
			"id": p.player_id,
			"name": p.name,
			"hand_count": p.hand.size(),
			"hand": hand_data,
		})

	# Discard top card
	var discard_top = null
	if !game_state.discard_pile.empty():
		discard_top = _card_to_dict(game_state.discard_pile[game_state.discard_pile.size() - 1])

	# Plateau cards (all played cards, in chronological order)
	var plateau = []
	var plateau_cards = game_state.metadata.get("plateau_cards", [])
	for c in plateau_cards:
		plateau.append(_card_to_dict(c))

	# Plateau visual stack — chronological visual representation
	# Alternates between {"type":"plate","value":N} and {"type":"card","card":{...}}
	var plateau_visual_stack = _build_plateau_visual_stack(game_state)

	var snapshot = {
		"players": players_data,
		"current_player_index": game_state.current_player_index,
		"piatto": game_state.metadata.get("piatto", 0),
		"deck_count": game_state.deck.size(),
		"discard_top": discard_top,
		"plateau_cards": plateau,
		"plateau_visual_stack": plateau_visual_stack,
		"advantage_turn": game_state.metadata.get("advantage_turn", false),
		"advantage_player_id": game_state.metadata.get("advantage_player_id", null),
		"winner": game_state.winner.player_id if game_state.winner != null else null,
		"turn_number": game_state.turn_number,
		"available_actions": _build_available_actions(),
		"phase": _get_phase_string(),
		"local_player_id": "player_1",
	}
	return snapshot


func _build_plateau_visual_stack(game_state):
	"""Build the visual plateau stack from the chronological card history.

	Returns an array of items alternating between:
	  {"type": "plate", "value": N}  — carta Piatto showing the piatto value
	  {"type": "card", "card": {...}} — Gold/89 card face

	The visual stack always starts with a carta Piatto (initial value 0).
	Gold/89 cards are shown as card faces. Non-Gold cards played after a Gold
	update the top carta Piatto's value.
	"""
	var raw_cards = game_state.metadata.get("plateau_cards", [])
	var current_piatto = game_state.metadata.get("piatto", 0)

	# Step 1: Classify each card and compute running piatto
	var segments = []  # [{card, piatto_after, is_gold}]
	var running = 0
	var last_is_gold = false

	for c in raw_cards:
		var ct = str(c.metadata.get("card_type", "")).to_lower()
		var is_gold = ct == "gold"
		var is_89 = ct == "special" and c.name == "89"
		var is_gold_or_89 = is_gold or is_89

		if is_gold_or_89:
			running = c.value if c.value != null else 0
		elif ct == "increment":
			running += c.value if c.value != null else 0
		elif ct == "jolly":
			running += 5
		elif ct == "imbroglio":
			pass
		elif ct == "special" and c.name == "+11":
			running += 11
		else:
			running += c.value if c.value != null else 0

		segments.append({
			"card": _card_to_dict(c),
			"piatto_after": running,
			"is_gold_or_89": is_gold_or_89,
		})
		last_is_gold = is_gold_or_89

	# Step 2: Build visual stack from segments
	var visual = [{"type": "plate", "value": 0}]
	var gold_count = 0

	for seg in segments:
		if seg["is_gold_or_89"]:
			# Gold/89 card: add card face on top
			visual.append({"type": "card", "card": seg["card"]})
			gold_count += 1
		else:
			# Non-Gold after at least one Gold: update or add carta Piatto
			if gold_count > 0:
				if visual.size() > 1 and visual[visual.size() - 1]["type"] == "plate":
					# Update existing top plate with current running value
					visual[visual.size() - 1]["value"] = seg["piatto_after"]
				else:
					# Add new carta Piatto above the last Gold
					visual.append({"type": "plate", "value": seg["piatto_after"]})

	# Step 3: Finalize top of the stack based on the LAST CARD PLAYED.
	# If the last card was a Gold/89, the card face IS the top — no trailing plate.
	# If the last card was non-Gold, ensure a final plate with the current value.
	if visual.size() > 0:
		if last_is_gold:
			# Last card was Gold/89: card face is the top visual element.
			# If there's a trailing plate (from a previous non-gold update),
			# remove it so the Gold is truly on top.
			if visual[visual.size() - 1]["type"] == "plate":
				visual.pop_back()
		else:
			# Last card was non-Gold: ensure a final plate.
			if visual[visual.size() - 1]["type"] == "card":
				visual.append({"type": "plate", "value": current_piatto})
			elif visual[visual.size() - 1]["type"] == "plate":
				visual[visual.size() - 1]["value"] = current_piatto

	return visual


func _build_available_actions():
	"""Convert raw rules actions to public format with card_id strings and choices."""
	var raw_actions = rules.get_available_actions(game_state)
	var grouped = {}  # key: "card_id\taction_type"

	for a in raw_actions:
		var at = a["action_type"]

		# RESET_HAND has no card — emit as-is once
		if at == RESET_HAND_ACTION:
			if not grouped.has("__reset_hand__"):
				grouped["__reset_hand__"] = {"action_type": at}
			continue

		var card = a.get("card", null)
		if card == null:
			continue

		var cid = card.card_id
		var key = cid + "\t" + at

		if not grouped.has(key):
			grouped[key] = {
				"action_type": at,
				"card_id": cid,
				"choices": [],
			}

		if a.has("selected_value"):
			var sv = a["selected_value"]
			grouped[key]["choices"].append({
				"label": str(sv),
				"parameters": {"selected_value": sv},
			})

	var result = []
	for key in grouped.keys():
		var entry = grouped[key]
		if key == "__reset_hand__":
			result.append({"action_type": RESET_HAND_ACTION})
		elif entry["choices"].empty():
			result.append({
				"action_type": entry["action_type"],
				"card_id": entry["card_id"],
			})
		else:
			result.append({
				"action_type": entry["action_type"],
				"card_id": entry["card_id"],
				"choices": entry["choices"],
			})

	return result


func _get_phase_string():
	if game_state.winner != null:
		return "game_over"
	if game_state.metadata.get("advantage_turn", false):
		return "advantage"
	return "playing"


# ---------------------------------------------------------------------------
# Before-state capture
# ---------------------------------------------------------------------------

func _capture_before_state():
	"""Capture relevant state before applying an action."""
	var cp = game_state.current_player()
	return {
		"piatto": game_state.metadata.get("piatto", 0),
		"advantage_turn": game_state.metadata.get("advantage_turn", false),
		"advantage_player_id": game_state.metadata.get("advantage_player_id", null),
		"winner": game_state.winner,
		"current_player_index": game_state.current_player_index,
		"current_player_id": cp.player_id if cp != null else null,
		"current_hand_ids": _get_hand_card_ids(cp),
		"current_hand_metadata": {},  # card_id: metadata snapshot for identity tracking
	}


# ---------------------------------------------------------------------------
# Event generation
# ---------------------------------------------------------------------------

func _generate_events(before, rules_action, card):
	"""Generate events following the exact operation order of Python's
	apply_action() for each action/card type."""
	var events = []
	var cp = game_state.current_player()
	var cp_id = cp.player_id if cp != null else before.get("current_player_id", "")
	var at = rules_action["action_type"]
	var card_id = card.card_id if card != null else ""

	# -----------------------------------------------------------------------
	# RESET_HAND: hand_reset, then card_drawn (×3)
	# -----------------------------------------------------------------------
	if at == RESET_HAND_ACTION:
		events.append({"type": "hand_reset", "player_id": cp_id})
		var after_ids = _get_hand_card_ids(cp)
		for cid in after_ids:
			if not cid in before.get("current_hand_ids", []):
				events.append({"type": "card_drawn", "player_id": cp_id, "card_id": cid})
		return events

	# -----------------------------------------------------------------------
	# REVEAL_GOLD: gold_revealed, then card_drawn
	# -----------------------------------------------------------------------
	if at == REVEAL_GOLD_ACTION:
		events.append({"type": "gold_revealed", "player_id": cp_id, "card_id": card_id})
		var after_ids = _get_hand_card_ids(cp)
		for cid in after_ids:
			if not cid in before.get("current_hand_ids", []):
				events.append({"type": "card_drawn", "player_id": cp_id, "card_id": cid})
		return events

	# -----------------------------------------------------------------------
	# CHANGE_CARD: card_changed, then card_drawn
	# -----------------------------------------------------------------------
	if at == CHANGE_CARD_ACTION:
		events.append({"type": "card_changed", "player_id": cp_id, "card_id": card_id})
		var after_ids = _get_hand_card_ids(cp)
		for cid in after_ids:
			if not cid in before.get("current_hand_ids", []):
				events.append({"type": "card_drawn", "player_id": cp_id, "card_id": cid})
		return events

	# -----------------------------------------------------------------------
	# PLAY_CARD — order mirrors Python apply_action() execution:
	#   1. card_played
	#   2. game_won  (only for +11 in GdV — winner set at increment calc time,
	#                 BEFORE piatto update in Python)
	#   3. advantage_started  (89 / gold chain — set during increment calc)
	#   4. piatto_changed
	#   5. game_won  (for all other wins — Python checks AFTER piatto update,
	#                 BEFORE draw)
	#   6. card_drawn
	# -----------------------------------------------------------------------
	var dest = "discard"
	if rules._is_gold_card(card) or rules._is_special_89_card(card):
		dest = "plateau"

	events.append({"type": "card_played", "player_id": cp_id, "card_id": card_id, "destination": dest})

	var is_plus11 = rules._is_plus11_card(card)
	var was_advantage = before.get("advantage_turn", false)
	var winner_emitted = false

	# Step 2: +11 in GdV — winner set BEFORE piatto in Python (+11 handler)
	if is_plus11 and was_advantage and game_state.winner != null:
		events.append({"type": "game_won", "player_id": game_state.winner.player_id})
		winner_emitted = true

	# Step 3: advantage_started (89 / gold chain) — set during increment calc
	if not before.get("advantage_turn", false) and game_state.metadata.get("advantage_turn", false):
		events.append({
			"type": "advantage_started",
			"player_id": game_state.metadata.get("advantage_player_id", cp_id),
		})

	# Step 4: piatto_changed (after all effects)
	var old_piatto = before.get("piatto", 0)
	var new_piatto = game_state.metadata.get("piatto", 0)
	if old_piatto != new_piatto:
		events.append({"type": "piatto_changed", "old_value": old_piatto, "new_value": new_piatto})

	# Step 5: game_won for non-plus11-GdV wins (Python checks AFTER piatto, BEFORE draw)
	if game_state.winner != null and not winner_emitted:
		events.append({"type": "game_won", "player_id": game_state.winner.player_id})
		winner_emitted = true

	# Step 6: card_drawn (Python draws after all effects, before advance_turn)
	var after_ids = _get_hand_card_ids(cp)
	for cid in after_ids:
		if not cid in before.get("current_hand_ids", []):
			events.append({"type": "card_drawn", "player_id": cp_id, "card_id": cid})

	return events


func _generate_turn_events(before, rules_action, card):
	"""Generate turn-phase events by comparing before/after advance_turn."""
	var events = []

	var old_index = before.get("current_player_index", 0)
	var old_pid = before.get("current_player_id", "")
	var new_cp = game_state.current_player()
	var new_pid = new_cp.player_id if new_cp != null else ""
	var new_index = game_state.current_player_index

	# Turn changed
	if new_pid != old_pid or game_state.turn_number > 0:
		events.append({
			"type": "turn_changed",
			"player_id": new_pid,
			"turn_number": game_state.turn_number,
		})

	# Advantage ended
	if before.get("advantage_turn", false) and not game_state.metadata.get("advantage_turn", false):
		events.append({"type": "advantage_ended"})

	return events
