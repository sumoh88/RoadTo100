extends Node

# Tests for reset_hand rule: only allowed during GdV, not GS.

var _CardData
var _RoadTo100Rules
var _LocalGameEngine

var game_ready = false
var test_engine = null


func _ready():
	_CardData = load("res://engine/CardData.gd")
	_RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")
	_LocalGameEngine = load("res://engine/LocalGameEngine.gd")

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
	var rules = e.rules

	# Clear all hands and deck
	for p in players:
		p.clear_hand()
	gs.deck.cards.clear()

	print("=== Test 1: GS → reset_hand vietato ===\n")

	# Setup: Player 2 has only blocked cards during GS
	var gold_card = _CardData.new("gold_45_test", "45", 45, "Gold", {"card_type": "gold"})
	var inc_card = _CardData.new("+5_test", "+5", 5, "Orange", {"card_type": "increment"})

	# Player 1 plays Gold to activate GS
	players[0].receive_card(gold_card)
	gs.current_player_index = 0
	gs.set_current_player(players[0])
	e.send_action({"action_type": "play_card", "card_id": "gold_45_test", "blocked_type": "Gold"})

	# Now Player 2 has only non-playable cards (Gold is blocked)
	var only_blocked_gold = _CardData.new("gold_78_p2", "78", 78, "Gold", {"card_type": "gold"})
	players[1].receive_card(only_blocked_gold)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var available_actions_gs = rules.get_available_actions(gs)
	var reset_hand_allowed_gs = false
	for a in available_actions_gs:
		if a["action_type"] == "reset_hand":
			reset_hand_allowed_gs = true
			break

	if !reset_hand_allowed_gs:
		print("  ✓ PASS: reset_hand not allowed during GS")
		passed += 1
	else:
		print("  ✗ FAIL: reset_hand incorrectly allowed during GS")
		failures.append("Test 1: reset_hand should not be allowed during GS")

	print("\n=== Test 2: GdV → consentito una volta, poi vietato ===\n")

	# Clear and setup new scenario for GdV
	for p in players:
		p.clear_hand()
	gs.deck.cards.clear()

	var card89 = _CardData.new("card89_test", "89", 89, "Purple", {"card_type": "special"})

	# Player 1 plays 89 to activate GdV
	players[0].receive_card(card89)
	gs.current_player_index = 0
	gs.set_current_player(players[0])
	e.send_action({"action_type": "play_card", "card_id": "card89_test"})

	# Add some cards to deck for drawing
	var filler1 = _CardData.new("+1_filler1", "+1", 1, "Orange", {"card_type": "increment"})
	var filler2 = _CardData.new("+1_filler2", "+1", 1, "Orange", {"card_type": "increment"})
	gs.deck.add_card(filler1)
	gs.deck.add_card(filler2)

	# Player 2 has only non-Orange cards (blocked during GdV)
	var gold_78_p2 = _CardData.new("gold_78_p2", "78", 78, "Gold", {"card_type": "gold"})
	players[1].receive_card(gold_78_p2)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	# First attempt: reset_hand should be allowed
	var available_actions_first = rules.get_available_actions(gs)
	var reset_hand_allowed_first = false
	for a in available_actions_first:
		if a["action_type"] == "reset_hand":
			reset_hand_allowed_first = true
			break

	if reset_hand_allowed_first:
		print("  ✓ PASS: reset_hand allowed first time during GdV")
		passed += 1

		# Use reset_hand
		e.send_action({"action_type": "reset_hand"})

		# Second attempt: reset_hand should NOT be allowed again
		var available_actions_second = rules.get_available_actions(gs)
		var reset_hand_allowed_second = false
		for a in available_actions_second:
			if a["action_type"] == "reset_hand":
				reset_hand_allowed_second = true
				break

		if !reset_hand_allowed_second:
			print("  ✓ PASS: reset_hand not allowed second time (same turn)")
			passed += 1
		else:
			print("  ✗ FAIL: reset_hand incorrectly allowed second time")
			failures.append("Test 2: reset_hand should only be allowed once per turn")
	else:
		print("  ✗ FAIL: reset_hand not allowed first time during GdV")
		failures.append("Test 2: reset_hand should be allowed first time during GdV")

	# Cleanup
	e.queue_free()

	# Summary
	var out = "========================================\n"
	out += " Reset Hand Rule Test\n"
	out += "========================================\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failures.size()) + "\n"
	if failures.size() > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + str(f) + "\n"
	out += "\n"
	return out
