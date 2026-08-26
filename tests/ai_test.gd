extends Node

# Tests for RoadTo100AI implementation.
# Verifies that the AI makes correct decisions based on heuristics.

var _CardData
var _RoadTo100Rules
var _LocalGameEngine
var _RoadTo100AI

var game_ready = false
var test_engine = null


func _ready():
	_CardData = load("res://engine/CardData.gd")
	_RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")
	_LocalGameEngine = load("res://engine/LocalGameEngine.gd")
	_RoadTo100AI = load("res://engine/RoadTo100AI.gd")

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

	print("=== Test 1: AI prefers high-value increment over low-value ===\n")

	# Setup: Player 2 has +9 and +1, should prefer +9
	var plus9 = _CardData.new("+9_test", "+9", 9, "Orange", {"card_type": "increment"})
	var plus1 = _CardData.new("+1_test", "+1", 1, "Orange", {"card_type": "increment"})

	players[1].receive_card(plus9)
	players[1].receive_card(plus1)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var ai = _RoadTo100AI.new()

	# Get available actions (simplified mock)
	var available_actions = [
		{"action_type": "play_card", "card_id": "+9_test"},
		{"action_type": "play_card", "card_id": "+1_test"}
	]

	var snapshot = {
		"players": [
			{"id": "player_1", "hand": []},
			{"id": "player_2", "hand": [
				{"card_id": "+9_test", "name": "+9", "value": 9, "color": "Orange", "card_type": "increment"},
				{"card_id": "+1_test", "name": "+1", "value": 1, "color": "Orange", "card_type": "increment"}
			]},
			{"id": "player_3", "hand": []},
			{"id": "player_4", "hand": []}
		],
		"current_player_index": 1,
		"plateau_cards": [],
		"special_round_active": false
	}

	var selected = ai.select_action(available_actions, snapshot)

	if str(selected.get("card_id", "")) == "+9_test":
		print("  ✓ PASS: AI selected +9 over +1")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", selected.get("card_id", "?"), " instead of +9")
		failures.append("Test 1: AI should prefer +9 over +1")

	print("\n=== Test 2: AI prefers Gold (activates Safe Round) ===\n")

	var gold45 = _CardData.new("gold_45_test", "45", 45, "Gold", {"card_type": "gold"})
	players[1].receive_card(gold45)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var available_actions2 = [
		{"action_type": "play_card", "card_id": "+9_test"},
		{"action_type": "play_card", "card_id": "gold_45_test"}
	]

	var snapshot2 = {
		"players": [
			{"id": "player_1", "hand": []},
			{"id": "player_2", "hand": [
				{"card_id": "+9_test", "name": "+9", "value": 9, "color": "Orange", "card_type": "increment"},
				{"card_id": "gold_45_test", "name": "45", "value": 45, "color": "Gold", "card_type": "gold"}
			]},
			{"id": "player_3", "hand": []},
			{"id": "player_4", "hand": []}
		],
		"current_player_index": 1,
		"plateau_cards": [],
		"special_round_active": false
	}

	var selected2 = ai.select_action(available_actions2, snapshot2)

	if str(selected2.get("card_id", "")) == "gold_45_test":
		print("  ✓ PASS: AI selected Gold (Safe Round activation)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", selected2.get("card_id", "?"), " instead of Gold")
		failures.append("Test 2: AI should prefer Gold for Safe Round activation")

	print("\n=== Test 3: AI prefers +11 after Gold (Gold chain) ===\n")

	var plus11 = _CardData.new("+11_test", "+11", 11, "Red", {"card_type": "special"})
	players[1].receive_card(plus11)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var available_actions3 = [
		{"action_type": "play_card", "card_id": "+9_test"},
		{"action_type": "play_card", "card_id": "+11_test"}
	]

	var snapshot3 = {
		"players": [
			{"id": "player_1", "hand": []},
			{"id": "player_2", "hand": [
				{"card_id": "+9_test", "name": "+9", "value": 9, "color": "Orange", "card_type": "increment"},
				{"card_id": "+11_test", "name": "+11", "value": 11, "color": "Red", "card_type": "special"}
			]},
			{"id": "player_3", "hand": []},
			{"id": "player_4", "hand": []}
		],
		"current_player_index": 1,
		"plateau_cards": [
			{"card_id": "gold_45_test", "name": "45", "value": 45, "color": "Gold", "card_type": "gold"}
		],
		"special_round_active": true,
		"special_round_player_id": "player_2",
		"special_round_type": "safe"
	}

	var selected3 = ai.select_action(available_actions3, snapshot3)

	if str(selected3.get("card_id", "")) == "+11_test":
		print("  ✓ PASS: AI selected +11 for Gold chain")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", selected3.get("card_id", "?"), " instead of +11")
		failures.append("Test 3: AI should prefer +11 after Gold (Gold chain)")

	# Cleanup
	e.queue_free()

	# Summary
	var out = "========================================\n"
	out += " RoadTo100AI Test\n"
	out += "========================================\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failures.size()) + "\n"
	if failures.size() > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + str(f) + "\n"
	out += "\n"
	return out
