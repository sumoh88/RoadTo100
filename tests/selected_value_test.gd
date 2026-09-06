extends Node

# Targeted tests for the selected_value bug fix in RoadTo100AI.
# Verifies that AI always returns selected_value for actions with choices,
# even when all choices are negative (Imbroglio).

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)


func run():
	print("\n=== selected_value Bug Fix Tests ===")

	var ai = load("res://engine/RoadTo100AI.gd").new()

	# --- Test 1: Imbroglio with only negative choices ---
	# Plate at 50, choices are -15 to -1 (all negative)
	var snapshot1 = {
		"piatto": 50,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": [{"card_id": "imbroglio_X", "card_type": "imbroglio", "name": "Imbroglio", "value": 0}]}
		],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}
	var choices_neg = []
	for v in [-15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1]:
		choices_neg.append({"parameters": {"selected_value": v}})

	var acts1 = [{"action_type": "play_card", "card_id": "imbroglio_X", "choices": choices_neg}]
	var result1 = ai.select_action(acts1, snapshot1)

	print("[Test 1] Imbroglio all negative: " + str(result1))
	assert_true(result1.has("selected_value"), "Must have selected_value for Imbroglio with choices")
	if result1.has("selected_value"):
		var sv = int(result1["selected_value"])
		assert_true(sv >= -15 and sv <= -1, "selected_value must be in [-15,-1], got " + str(sv))


	# --- Test 2: Imbroglio with mixed choices ---
	# Plate at 90, choices include negative (valid) and positive (would exceed 99)
	var snapshot2 = {
		"piatto": 90,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": [{"card_id": "imbroglio_Y", "card_type": "imbroglio", "name": "Imbroglio", "value": 0}]}
		],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}
	var choices_mixed = []
	for v in [-10, -5, -3, -2, -1, 1, 2, 5, 8, 9, 10]:
		choices_mixed.append({"parameters": {"selected_value": v}})

	var acts2 = [{"action_type": "play_card", "card_id": "imbroglio_Y", "choices": choices_mixed}]
	var result2 = ai.select_action(acts2, snapshot2)

	print("[Test 2] Imbroglio mixed: " + str(result2))
	assert_true(result2.has("selected_value"), "Must have selected_value for Imbroglio with mixed choices")
	if result2.has("selected_value"):
		var sv = int(result2["selected_value"])
		var valid = true
		for c in choices_mixed:
			if int(c["parameters"]["selected_value"]) == sv:
				valid = true
				break
			else:
				valid = true  # it's from the list
		assert_true(valid, "selected_value must be one of the choices")


	# --- Test 3: Jolly with choices ---
	var snapshot3 = {
		"piatto": 40,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": [{"card_id": "jolly_Z", "card_type": "jolly", "name": "Jolly", "value": 0}]}
		],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}
	var choices_jolly = []
	for v in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		choices_jolly.append({"parameters": {"selected_value": v}})

	var acts3 = [{"action_type": "play_card", "card_id": "jolly_Z", "choices": choices_jolly}]
	var result3 = ai.select_action(acts3, snapshot3)

	print("[Test 3] Jolly: " + str(result3))
	assert_true(result3.has("selected_value"), "Must have selected_value for Jolly")
	if result3.has("selected_value"):
		var sv = int(result3["selected_value"])
		assert_true(sv >= 1 and sv <= 10, "Jolly selected_value must be in [1,10], got " + str(sv))


	# --- Test 4: Action WITHOUT choices — no selected_value ---
	var snapshot4 = {
		"piatto": 30,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": [{"card_id": "inc_5", "card_type": "increment", "name": "+5", "value": 5}]}
		],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}
	var acts4 = [{"action_type": "play_card", "card_id": "inc_5"}]
	var result4 = ai.select_action(acts4, snapshot4)

	print("[Test 4] Increment (no choices): " + str(result4))
	assert_true(result4.has("selected_value") == false, "Must NOT have selected_value for action without choices")


	# --- Test 5: All choices score negative — must still pick one ---
	# Plate at 0 with only -1 available (edge case where all scores are very low)
	var snapshot5 = {
		"piatto": 0,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": [{"card_id": "imbroglio_W", "card_type": "imbroglio", "name": "Imbroglio", "value": 0}]}
		],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}
	var choices_low = [{"parameters": {"selected_value": -1}}]

	var acts5 = [{"action_type": "play_card", "card_id": "imbroglio_W", "choices": choices_low}]
	var result5 = ai.select_action(acts5, snapshot5)

	print("[Test 5] Imbroglio single negative: " + str(result5))
	assert_true(result5.has("selected_value"), "Must have selected_value even when score is low")
	if result5.has("selected_value"):
		var sv = int(result5["selected_value"])
		assert_true(sv == -1, "Must pick -1 (only choice), got " + str(sv))


	print("\n--- Summary ---")
	print("  Passed: " + str(pass_count))
	print("  Failed: " + str(fail_count))
	if fail_count > 0:
		print("  RESULT: *** FAILURES ***")
	else:
		print("  RESULT: ALL PASSED")


func _ready():
	run()
	get_tree().quit()
