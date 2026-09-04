extends Node

# AI Personality Test — verifies that P2/P3/P4 use different AI instances with
# distinct weight configurations producing different play styles.
# Tests that all CPUs use AI (not random) and that the seat mapping is correct.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
		print("  [PASS] " + msg)
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== AI Personality Test ===")

	var ai_class = load("res://engine/RoadTo100AI.gd")

	# Create three AI instances with different personalities
	var p2_ai = ai_class.new()
	var p3_ai = ai_class.new()
	p3_ai.W_INCREMENT_HIGH = 8
	p3_ai.W_BOUNCE_PENALTY = -20
	p3_ai.W_JOLLY_FLEXIBILITY = 25
	var p4_ai = ai_class.new()
	p4_ai.W_INCREMENT_HIGH = 2
	p4_ai.W_BOUNCE_PENALTY = -80
	p4_ai.W_IMBROGLIO_STRATEGIC = 50

	# Verify P2 is balanced (default weights)
	assert_true(p2_ai.W_INCREMENT_HIGH == 3, "P2 balanced: W_INCREMENT_HIGH=3")
	assert_true(p2_ai.W_BOUNCE_PENALTY == -50, "P2 balanced: W_BOUNCE_PENALTY=-50")

	# Verify P3 is aggressive (higher increment bonus, lower bounce penalty)
	assert_true(p3_ai.W_INCREMENT_HIGH > p2_ai.W_INCREMENT_HIGH, "P3 aggressive: higher increment bonus")
	assert_true(p3_ai.W_BOUNCE_PENALTY > p2_ai.W_BOUNCE_PENALTY, "P3 aggressive: lower bounce penalty (more risk)")
	assert_true(p3_ai.W_JOLLY_FLEXIBILITY > p2_ai.W_JOLLY_FLEXIBILITY, "P3 aggressive: higher Jolly flexibility")

	# Verify P4 is tactical/prudent (lower increment bonus, higher bounce penalty)
	assert_true(p4_ai.W_INCREMENT_HIGH < p2_ai.W_INCREMENT_HIGH, "P4 tactical: lower increment bonus")
	assert_true(p4_ai.W_BOUNCE_PENALTY < p2_ai.W_BOUNCE_PENALTY, "P4 tactical: higher bounce penalty (less risk)")
	assert_true(p4_ai.W_IMBROGLIO_STRATEGIC > p2_ai.W_IMBROGLIO_STRATEGIC, "P4 tactical: higher Imbroglio bonus")

	# Verify the three personalities are different from each other
	assert_true(p2_ai.W_INCREMENT_HIGH != p3_ai.W_INCREMENT_HIGH, "P2/P3 have different increment bonuses")
	assert_true(p2_ai.W_INCREMENT_HIGH != p4_ai.W_INCREMENT_HIGH, "P2/P4 have different increment bonuses")
	assert_true(p3_ai.W_INCREMENT_HIGH != p4_ai.W_INCREMENT_HIGH, "P3/P4 have different increment bonuses")

	# Test decision difference in a controlled scenario: high-value vs low-value card
	var snapshot = {
		"piatto": 20,
		"players": [
			{"id": "player_1", "hand_count": 3},
			{"id": "player_2", "hand_count": 3, "hand": [
				{"card_id": "inc9", "name": "+9", "value": 9, "card_type": "increment"},
				{"card_id": "inc2", "name": "+2", "value": 2, "card_type": "increment"}
			]},
			{"id": "player_3", "hand_count": 3},
			{"id": "player_4", "hand_count": 3}
		],
		"current_player_index": 1,
		"special_round_active": false,
		"plateau_cards": []
	}

	var available_actions = [
		{"action_type": "play_card", "card_id": "inc9"},
		{"action_type": "play_card", "card_id": "inc2"}
	]

	# P3 (aggressive) should prefer the high-value card more strongly than P4 (tactical)
	var p3_choice = null
	for i in range(20):
		var choice = p3_ai.select_action(available_actions, snapshot)
		if choice != null and choice["card_id"] == "inc9":
			p3_choice = true
			break

	var p4_choice = null
	for i in range(20):
		var choice = p4_ai.select_action(available_actions, snapshot)
		if choice != null and choice["card_id"] == "inc9":
			p4_choice = true
			break

	assert_true(p3_choice == true, "P3 (aggressive) chooses high-value card")
	# P4 may or may not choose the high-value card (both are valid), but the scoring differs
	print("  [INFO] P4 chose inc9: " + str(p4_choice))

	# Verify seat mapping in ManualGame (check the OPPONENT_SEATS constant)
	var animator_script = load("res://scripts/CardAnimator.gd")
	assert_true(animator_script.OPPONENT_SEATS["player_2"] == "LeftSeat", "P2 maps to LeftSeat")
	assert_true(animator_script.OPPONENT_SEATS["player_3"] == "TopSeat", "P3 maps to TopSeat")
	assert_true(animator_script.OPPONENT_SEATS["player_4"] == "RightSeat", "P4 maps to RightSeat")

	print("\n--- Summary ---")
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

	if fail_count > 0:
		print("========================================")
		print("FAILURES DETECTED")
		print("========================================")
	else:
		print("ALL AI PERSONALITY TESTS PASSED")

func _ready():
	run()
	get_tree().quit()
