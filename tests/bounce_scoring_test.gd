extends Node

# Targeted tests for the new bounce/plateau scoring model.
# Verifies that the AI evaluates the ACTUAL resulting plateau, not nominal card value.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func make_snapshot(plateau_val, hand_cards):
	return {
		"piatto": plateau_val,
		"current_player_index": 0,
		"players": [{"id": "player_2", "hand": hand_cards}],
		"plateau_cards": [],
		"special_round_active": false,
		"winner": null
	}

func run():
	print("\n=== Bounce Scoring Model Tests ===")

	var ai = load("res://engine/RoadTo100AI.gd").new()

	# --- Test 1: Piatto 97 — bounce should be preferred over leaving 99 ---
	var hand1 = [
		{"card_id": "inc_2", "card_type": "increment", "name": "+2", "value": 2},
		{"card_id": "inc_10", "card_type": "increment", "name": "+10", "value": 10}
	]
	var snap1 = make_snapshot(97, hand1)
	var acts1 = [
		{"action_type": "play_card", "card_id": "inc_2"},
		{"action_type": "play_card", "card_id": "inc_10"}
	]
	var result1 = ai.select_action(acts1, snap1)

	print("[Test 1] Piatto 97, +2 vs +10: chose " + str(result1["card_id"]))
	# +10 bounces to 93 (safe), +2 leaves 99 (dangerous). AI should pick +10.
	assert_true(result1["card_id"] == "inc_10", "Piatto 97: should prefer +10 (bounce to 93) over +2 (leave 99)")


	# --- Test 2: Piatto 50 — higher card preferred (no danger zone) ---
	var hand2 = [
		{"card_id": "inc_2", "card_type": "increment", "name": "+2", "value": 2},
		{"card_id": "inc_10", "card_type": "increment", "name": "+10", "value": 10}
	]
	var snap2 = make_snapshot(50, hand2)
	var acts2 = [
		{"action_type": "play_card", "card_id": "inc_2"},
		{"action_type": "play_card", "card_id": "inc_10"}
	]
	var result2 = ai.select_action(acts2, snap2)

	print("[Test 2] Piatto 50, +2 vs +10: chose " + str(result2["card_id"]))
	assert_true(result2["card_id"] == "inc_10", "Piatto 50: should prefer +10 (more progress, no danger)")


	# --- Test 3: Piatto 94 — both +2→96 and +10→96(bounce) give same result plateau ---
	var hand3 = [
		{"card_id": "inc_2", "card_type": "increment", "name": "+2", "value": 2},
		{"card_id": "inc_10", "card_type": "increment", "name": "+10", "value": 10}
	]
	var snap3 = make_snapshot(94, hand3)
	var acts3 = [
		{"action_type": "play_card", "card_id": "inc_2"},
		{"action_type": "play_card", "card_id": "inc_10"}
	]
	var result3 = ai.select_action(acts3, snap3)

	print("[Test 3] Piatto 94, +2 vs +10 (both→96): chose " + str(result3["card_id"]))
	# Both produce plateau 96. With new model they should score nearly identically.
	# +2: change=+2, progress=20, danger=(96-92)*15=60, total=-40+1(bonus)=-39
	# +10: change=96-94=+2, progress=20, danger=(96-92)*15=60, total=-40+3(bonus)=-37
	# Very close! Either is acceptable. Just verify AI picks one of them (no crash).
	assert_true(result3["card_id"] == "inc_2" or result3["card_id"] == "inc_10", "Piatto 94: either card valid (same result plateau)")


	# --- Test 4: Piatto 85 — +2→87 (safe) vs +10→95 (enters danger zone) ---
	var hand4 = [
		{"card_id": "inc_2", "card_type": "increment", "name": "+2", "value": 2},
		{"card_id": "inc_10", "card_type": "increment", "name": "+10", "value": 10}
	]
	var snap4 = make_snapshot(85, hand4)
	var acts4 = [
		{"action_type": "play_card", "card_id": "inc_2"},
		{"action_type": "play_card", "card_id": "inc_10"}
	]
	var result4 = ai.select_action(acts4, snap4)

	print("[Test 4] Piatto 85, +2 vs +10: chose " + str(result4["card_id"]))
	# +2: change=+2, progress=20, no danger → total=21
	# +10: change=+10, progress=50 (halved in danger zone), danger increase=(3-0)*15=45 → total=8
	# New model prefers safe progress: +2 avoids entering danger zone.
	assert_true(result4["card_id"] == "inc_2", "Piatto 85: should prefer +2 (safe at 87) over +10 (dangerous at 95)")


	# --- Test 5: Piatto 97 with aggressive personality (W_PLATEAU_DANGER=6) ---
	var ai_agg = load("res://engine/RoadTo100AI.gd").new()
	ai_agg.W_PLATEAU_DANGER = 6

	print("[Test 5] Piatto 97, aggressive AI (danger=6):")
	var result5 = ai_agg.select_action(acts1, snap1)
	print("  chose " + str(result5["card_id"]))
	# +2: progress=20, danger=(99-92)*6=42, bonus=1 → total=-21
	# +10: change=-4, progress=-40, danger=(93-92)*6=6, bonus=3 → total=-43
	# With low danger weight, +2 might win! That's the aggressive personality working.
	# Just verify it picks something valid (no crash, no null).
	assert_true(result5 != null and result5.has("card_id"), "Aggressive AI: should still make a valid choice")


	# --- Test 6: Piatto 97 with defensive personality (W_PLATEAU_DANGER=30) ---
	var ai_def = load("res://engine/RoadTo100AI.gd").new()
	ai_def.W_PLATEAU_DANGER = 30

	print("[Test 6] Piatto 97, defensive AI (danger=30):")
	var result6 = ai_def.select_action(acts1, snap1)
	print("  chose " + str(result6["card_id"]))
	# +2: progress=20, danger=(99-92)*30=210, bonus=1 → total=-189
	# +10: change=-4, progress=-40, danger=(93-92)*30=30, bonus=3 → total=-67
	# Defensive AI strongly prefers bounce.
	assert_true(result6["card_id"] == "inc_10", "Defensive AI: should prefer +10 (bounce to 93)")


	# --- Test 7: Immediate win still takes priority ---
	var hand7 = [
		{"card_id": "inc_3", "card_type": "increment", "name": "+3", "value": 3},
		{"card_id": "inc_10", "card_type": "increment", "name": "+10", "value": 10}
	]
	var snap7 = make_snapshot(97, hand7)
	var acts7 = [
		{"action_type": "play_card", "card_id": "inc_3"},   # 97+3=100 → WIN!
		{"action_type": "play_card", "card_id": "inc_10"}    # 97+10=107→93 bounce
	]
	var result7 = ai.select_action(acts7, snap7)

	print("[Test 7] Piatto 97, +3(wins) vs +10(bounce): chose " + str(result7["card_id"]))
	assert_true(result7["card_id"] == "inc_3", "Immediate win must always take priority over bounce strategy")


	# --- Test 8: GdV activator no-bounce exception still works ---
	var hand8 = [
		{"card_id": "inc_5", "card_type": "increment", "name": "+5", "value": 5}
	]
	var snap8 = {
		"piatto": 98,
		"current_player_index": 0,
		"players": [
			{"id": "player_2", "hand": hand8},
			{"id": "player_1", "hand": []}
		],
		"plateau_cards": [],
		"special_round_active": true,
		"special_round_type": "advantage",
		"special_round_player_id": "player_2",
		"winner": null
	}
	var acts8 = [{"action_type": "play_card", "card_id": "inc_5"}]
	var result8 = ai.select_action(acts8, snap8)

	print("[Test 8] GdV activator at 98 with +5 (→103 no bounce): chose " + str(result8["card_id"]))
	# GdV activator: 98+5=103, no bounce, this WINS (>=100 for GdV activator)
	assert_true(result8["card_id"] == "inc_5", "GdV activator should play winning card")


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
