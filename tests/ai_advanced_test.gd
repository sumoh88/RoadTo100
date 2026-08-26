extends Node

# Tests for advanced RoadTo100AI capabilities:
# - Immediate win detection
# - Strategic Jolly value selection
# - Bounce avoidance
# - Imbroglio strategy

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


func _make_snapshot(piatto, hand_cards, plateau_cards_arr, sr_active, sr_player_id, sr_type):
	return {
		"players": [
			{"id": "player_1", "hand": []},
			{"id": "player_2", "hand": hand_cards},
			{"id": "player_3", "hand": []},
			{"id": "player_4", "hand": []}
		],
		"current_player_index": 1,
		"piatto": piatto,
		"plateau_cards": plateau_cards_arr,
		"special_round_active": sr_active,
		"special_round_player_id": sr_player_id if sr_player_id != "" else null,
		"special_round_type": sr_type,
	}


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

	var ai = _RoadTo100AI.new()

	# =========================================================================
	print("=== Test 1: AI detects immediate win (plateau 95, +5 wins at 100) ===\n")

	var plus5 = _CardData.new("+5_win", "+5", 5, "Orange", {"card_type": "increment"})
	var plus3 = _CardData.new("+3_safe", "+3", 3, "Orange", {"card_type": "increment"})
	players[1].receive_card(plus5)
	players[1].receive_card(plus3)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t1 = [
		{"action_type": "play_card", "card_id": "+5_win"},
		{"action_type": "play_card", "card_id": "+3_safe"}
	]

	var snap_t1 = _make_snapshot(95, [
		{"card_id": "+5_win", "name": "+5", "value": 5, "color": "Orange", "card_type": "increment"},
		{"card_id": "+3_safe", "name": "+3", "value": 3, "color": "Orange", "card_type": "increment"}
	], [], false, "", "")

	var sel_t1 = ai.select_action(actions_t1, snap_t1)

	if str(sel_t1.get("card_id", "")) == "+5_win":
		print("  ✓ PASS: AI selected +5 (immediate win at 100)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", sel_t1.get("card_id", "?"), " instead of winning +5")
		failures.append("Test 1: AI should detect immediate win with +5 at plateau 95")

	# =========================================================================
	print("\n=== Test 2: AI picks winning Jolly value (plateau 90, Jolly→+10 wins) ===\n")

	var jolly_card = _CardData.new("jolly_test", "Jolly", 0, "Orange", {"card_type": "jolly"})
	players[1].receive_card(jolly_card)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t2 = [
		{"action_type": "play_card", "card_id": "jolly_test", "choices": [
			{"label": "1", "parameters": {"selected_value": 1}},
			{"label": "5", "parameters": {"selected_value": 5}},
			{"label": "10", "parameters": {"selected_value": 10}},
		]}
	]

	var snap_t2 = _make_snapshot(90, [
		{"card_id": "jolly_test", "name": "Jolly", "value": 0, "color": "Orange", "card_type": "jolly"}
	], [], false, "", "")

	var sel_t2 = ai.select_action(actions_t2, snap_t2)

	if str(sel_t2.get("card_id", "")) == "jolly_test" and int(sel_t2.get("selected_value", 0)) == 10:
		print("  ✓ PASS: AI selected Jolly with value 10 (wins at 100)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", sel_t2.get("card_id", "?"), " value=", sel_t2.get("selected_value", "?"), " instead of Jolly 10")
		failures.append("Test 2: AI should pick Jolly value 10 at plateau 90 for immediate win")

	# =========================================================================
	print("\n=== Test 3: AI avoids bounce (plateau 95, +6 bounces vs +3 safe) ===\n")

	var plus6 = _CardData.new("+6_bounce", "+6", 6, "Orange", {"card_type": "increment"})
	var plus3b = _CardData.new("+3_nobounce", "+3", 3, "Orange", {"card_type": "increment"})
	players[1].receive_card(plus6)
	players[1].receive_card(plus3b)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t3 = [
		{"action_type": "play_card", "card_id": "+6_bounce"},
		{"action_type": "play_card", "card_id": "+3_nobounce"}
	]

	var snap_t3 = _make_snapshot(95, [
		{"card_id": "+6_bounce", "name": "+6", "value": 6, "color": "Orange", "card_type": "increment"},
		{"card_id": "+3_nobounce", "name": "+3", "value": 3, "color": "Orange", "card_type": "increment"}
	], [], false, "", "")

	var sel_t3 = ai.select_action(actions_t3, snap_t3)

	if str(sel_t3.get("card_id", "")) == "+3_nobounce":
		print("  ✓ PASS: AI selected +3 (avoids bounce from +6)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", sel_t3.get("card_id", "?"), " - should avoid bouncing +6")
		failures.append("Test 3: AI should prefer +3 over bouncing +6 at plateau 95")

	# =========================================================================
	print("\n=== Test 4: AI picks strategic Imbroglio value (plateau 85, maximize progress) ===\n")

	var imb_card = _CardData.new("imb_test", "Imbroglio", 0, "Green", {"card_type": "imbroglio"})
	players[1].receive_card(imb_card)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	# Imbroglio at plateau 85: max valid is +14 (reaches 99)
	var imb_choices = []
	for v in range(-15, 16):
		if v != 0 and 85 + v >= 0 and 85 + v <= 99:
			imb_choices.append({"label": str(v), "parameters": {"selected_value": v}})

	var actions_t4 = [
		{"action_type": "play_card", "card_id": "imb_test", "choices": imb_choices}
	]

	var snap_t4 = _make_snapshot(85, [
		{"card_id": "imb_test", "name": "Imbroglio", "value": 0, "color": "Green", "card_type": "imbroglio"}
	], [], false, "", "")

	var sel_t4 = ai.select_action(actions_t4, snap_t4)

	var imb_val = int(sel_t4.get("selected_value", 0))
	if str(sel_t4.get("card_id", "")) == "imb_test" and imb_val >= 10:
		print("  ✓ PASS: AI selected Imbroglio with value ", imb_val, " (maximizes progress)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected Imbroglio value=", imb_val, " - should pick high positive value")
		failures.append("Test 4: AI should pick high positive Imbroglio value at plateau 85")

	# =========================================================================
	print("\n=== Test 5: AI holds back +11 when not strategic (plateau 50) ===\n")

	var plus11_hold = _CardData.new("+11_hold", "+11", 11, "Red", {"card_type": "special"})
	var plus7 = _CardData.new("+7_play", "+7", 7, "Orange", {"card_type": "increment"})
	players[1].receive_card(plus11_hold)
	players[1].receive_card(plus7)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t5 = [
		{"action_type": "play_card", "card_id": "+11_hold"},
		{"action_type": "play_card", "card_id": "+7_play"}
	]

	var snap_t5 = _make_snapshot(50, [
		{"card_id": "+11_hold", "name": "+11", "value": 11, "color": "Red", "card_type": "special"},
		{"card_id": "+7_play", "name": "+7", "value": 7, "color": "Orange", "card_type": "increment"}
	], [], false, "", "")

	var sel_t5 = ai.select_action(actions_t5, snap_t5)

	if str(sel_t5.get("card_id", "")) == "+7_play":
		print("  ✓ PASS: AI held back +11, played +7 instead")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", sel_t5.get("card_id", "?"), " - should hold back +11 at plateau 50")
		failures.append("Test 5: AI should hold back +11 when not strategic (plateau 50)")

	# =========================================================================
	print("\n=== Test 6: AI plays +11 to win (plateau 90, +11 wins at 101) ===\n")

	var plus11_win = _CardData.new("+11_win", "+11", 11, "Red", {"card_type": "special"})
	var plus2 = _CardData.new("+2_low", "+2", 2, "Orange", {"card_type": "increment"})
	players[1].receive_card(plus11_win)
	players[1].receive_card(plus2)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t6 = [
		{"action_type": "play_card", "card_id": "+11_win"},
		{"action_type": "play_card", "card_id": "+2_low"}
	]

	var snap_t6 = _make_snapshot(90, [
		{"card_id": "+11_win", "name": "+11", "value": 11, "color": "Red", "card_type": "special"},
		{"card_id": "+2_low", "name": "+2", "value": 2, "color": "Orange", "card_type": "increment"}
	], [], false, "", "")

	var sel_t6 = ai.select_action(actions_t6, snap_t6)

	if str(sel_t6.get("card_id", "")) == "+11_win":
		print("  ✓ PASS: AI played +11 for immediate win at plateau 90")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected ", sel_t6.get("card_id", "?"), " - should play +11 to win")
		failures.append("Test 6: AI should play +11 when it wins (plateau 90, 90+11=101>=100)")

	# =========================================================================
	print("\n=== Test 7: Jolly avoids bounce (plateau 95, pick 4 not 10) ===\n")

	var jolly2 = _CardData.new("jolly_b", "Jolly", 0, "Orange", {"card_type": "jolly"})
	players[1].receive_card(jolly2)

	gs.current_player_index = 1
	gs.set_current_player(players[1])

	var actions_t7 = [
		{"action_type": "play_card", "card_id": "jolly_b", "choices": [
			{"label": "4", "parameters": {"selected_value": 4}},
			{"label": "5", "parameters": {"selected_value": 5}},
			{"label": "10", "parameters": {"selected_value": 10}},
		]}
	]

	var snap_t7 = _make_snapshot(95, [
		{"card_id": "jolly_b", "name": "Jolly", "value": 0, "color": "Orange", "card_type": "jolly"}
	], [], false, "", "")

	var sel_t7 = ai.select_action(actions_t7, snap_t7)

	var jval_t7 = int(sel_t7.get("selected_value", 0))
	if str(sel_t7.get("card_id", "")) == "jolly_b" and jval_t7 <= 5:
		print("  ✓ PASS: AI selected Jolly value ", jval_t7, " (avoids bounce at plateau 95)")
		passed += 1
	else:
		print("  ✗ FAIL: AI selected Jolly value=", jval_t7, " - should avoid bouncing values")
		failures.append("Test 7: AI should pick Jolly value <=5 at plateau 95 to avoid bounce")

	# Cleanup
	e.queue_free()

	# Summary
	var out = "========================================\n"
	out += " RoadTo100AI Advanced Test\n"
	out += "========================================\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failures.size()) + "\n"
	if failures.size() > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + str(f) + "\n"
	out += "\n"
	return out
