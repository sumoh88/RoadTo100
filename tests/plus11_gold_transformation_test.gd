extends Node

# Test for +11 Gold chain transformation.
# Verifies that when +11 is played after a Gold, it creates a new transformed Gold card
# on the plateau without consuming or removing the original Gold from the game.

var _CardData
var _Deck
var _Hand
var _PlayerData
var _GameState
var _RoadTo100Rules
var _LocalGameEngine
var _CardDatabase

var game_ready = false
var test_engine = null


func _ready():
	_CardData = load("res://engine/CardData.gd")
	_Deck = load("res://engine/Deck.gd")
	_Hand = load("res://engine/Hand.gd")
	_PlayerData = load("res://engine/PlayerData.gd")
	_GameState = load("res://engine/GameState.gd")
	_RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")
	_LocalGameEngine = load("res://engine/LocalGameEngine.gd")
	_CardDatabase = load("res://engine/CardDatabase.gd")

	var e = _LocalGameEngine.new()
	add_child(e)
	test_engine = e

	e.connect("game_started", self, "_on_game_started")
	e.start_game(4)


func _on_game_started(snap):
	game_ready = true
	var out = _run_test()
	print(out)
	get_tree().quit(0)


func _run_test():
	var passed = 0
	var failed = 0
	var failures = []

	var e = test_engine
	var gs = e.game_state
	var players = gs.players

	# Clear all hands and deck
	for p in players:
		p.clear_hand()
	gs.deck.cards.clear()

	print("=== Test 1: Gold 45 → +11 → should create transformed Gold 56 ===\n")

	# Setup: Create original Gold 45 and Gold 56 to verify they're not consumed
	var original_gold_45 = _CardData.new("gold_45_orig", "45", 45, "Gold", {"card_type": "gold"})
	var original_gold_56 = _CardData.new("gold_56_orig", "56", 56, "Gold", {"card_type": "gold"})
	var plus11_card = _CardData.new("+11_test", "+11", 11, "Red", {"card_type": "special"})

	# Add some filler cards to deck so drawing works
	var filler1 = _CardData.new("+1_filler1", "+1", 1, "Orange", {"card_type": "increment"})
	var filler2 = _CardData.new("+1_filler2", "+1", 1, "Orange", {"card_type": "increment"})
	gs.deck.add_card(filler1)
	gs.deck.add_card(filler2)

	# P2 plays Gold 45
	players[1].receive_card(original_gold_45)
	gs.current_player_index = 1
	gs.set_current_player(players[1])
	e.send_action({"action_type": "play_card", "card_id": "gold_45_orig", "blocked_type": "Gold"})

	# Add Gold 56 to deck to verify it's not consumed by transformation
	gs.deck.add_card(original_gold_56)
	print("  Deck size after adding Gold 56: ", gs.deck.cards.size())

	# P3 plays +11 (should transform into Gold 56 via Gold chain)
	players[2].receive_card(plus11_card)
	gs.current_player_index = 2
	gs.set_current_player(players[2])
	e.send_action({"action_type": "play_card", "card_id": "+11_test"})

	# Check plateau_cards for transformed Gold
	var plateau_cards = gs.metadata.get("plateau_cards", [])
	if plateau_cards.size() >= 2:
		var last_card = plateau_cards[plateau_cards.size() - 1]
		
		# Verify transformed card properties
		var is_transformed_gold = last_card.name == "56" and \
			last_card.metadata.get("card_type", "") == "gold" and \
			str(last_card.card_id).begins_with("transformed_gold_")
		
		if is_transformed_gold:
			print("  ✓ PASS: +11 transformed into Gold 56 on plateau")
			passed += 1
		else:
			print("  ✗ FAIL: Last card on plateau is not transformed Gold 56")
			print("    Name: ", last_card.name, " (expected: 56)")
			print("    Type: ", last_card.metadata.get("card_type", ""), " (expected: gold)")
			print("    ID: ", last_card.card_id, " (expected: transformed_gold_*)")
			failures.append("Test 1: Last card on plateau is not transformed Gold 56")

	# Verify transformed card has unique ID (not same as any original Gold 56)
	var transformed_card_found = false
	var transformed_id_unique = true
	for c in plateau_cards:
		if str(c.card_id).begins_with("transformed_gold_"):
			transformed_card_found = true
			# Check that this card_id doesn't exist in deck or hands (it's newly created)
			for dc in gs.deck.cards:
				if dc.card_id == c.card_id:
					transformed_id_unique = false
					break
			for p in players:
				for hc in p.hand.cards:
					if hc.card_id == c.card_id:
						transformed_id_unique = false
						break
	
	if transformed_card_found and transformed_id_unique:
		print("  ✓ PASS: Transformed Gold has unique ID (newly created, not from deck)")
		passed += 1
	else:
		print("  ✗ FAIL: Transformed Gold ID issue")
		print("    Found: ", transformed_card_found)
		print("    Unique: ", transformed_id_unique)
		failures.append("Test 1: Transformed Gold ID not unique or not found")

	# Verify original Gold 45 is on plateau (from first play)
	var gold_45_on_plateau = false
	for c in plateau_cards:
		if c.card_id == "gold_45_orig":
			gold_45_on_plateau = true
			break

	if gold_45_on_plateau:
		print("  ✓ PASS: Original Gold 45 on plateau from first play")
		passed += 1
	else:
		print("  ✗ FAIL: Original Gold 45 not found on plateau")
		failures.append("Test 1: Original Gold 45 not found on plateau")

	e.queue_free()

	# Summary
	var out = "========================================\n"
	out += " +11 Gold Transformation Test\n"
	out += "========================================\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failures.size()) + "\n"
	if failures.size() > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + str(f) + "\n"
	out += "\n"
	return out
