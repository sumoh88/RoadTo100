extends Node

# Debug test to trace the full ManualGame flow with turn-by-turn logging.
# This will help identify where the game gets stuck after P3 plays.

var pass_count = 0
var fail_count = 0
var turns_seen = []

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== Manual Game Debug Test ===")
	print("Running a full game and logging each turn transition...")

	# Create game objects manually (no scene needed)
	var gc = load("res://scripts/GameController.gd").new()
	var mg = load("res://scripts/ManualGame.gd").new()

	# Connect ManualGame to GC
	mg._gc = gc

	# Start the game
	gc.start_game(4)

	# Simulate several CPU turns by manually triggering perform_action
	# with safe, legal actions (change_card is always available)
	var turn_count = 0
	var max_turns = 12  # 3 full rounds of 4 players

	while turn_count < max_turns:
		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			break

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[Turn " + str(turn_count) + "] Game over! Winner: " + str(winner))
			break

		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		print("[Turn " + str(turn_count) + "] Player: " + cur_pid + ", Piatto: " + str(snapshot.get("piatto", 0)))
		turns_seen.append(cur_pid)

		# Get available actions
		var acts = snapshot.get("available_actions", [])
		if acts.empty():
			print("  No actions available - game stuck?")
			break

		# Pick first play_card action (or fallback to change_card)
		var action = null
		for a in acts:
			if str(a.get("action_type", "")) == "play_card":
				action = {"action_type": "play_card", "card_id": a.get("card_id", "")}
				break
		if action == null:
			action = {"action_type": "change_card", "card_id": acts[0].get("card_id", "")}

		# Perform the action (this will trigger animation and state changes)
		gc.perform_action(action)
		turn_count += 1

	print("\nTurns seen: " + str(turns_seen))
	assert_true(turns_seen.size() >= 4, "Should see at least 4 turns (one per player)")

	# Verify turn order is correct
	var expected_order = ["player_1", "player_2", "player_3", "player_4"]
	for i in range(min(4, turns_seen.size())):
		assert_true(turns_seen[i] == expected_order[i], "Turn " + str(i) + " should be " + expected_order[i])

	print("\n--- Summary ---")
	print("  Turns played: " + str(turns_seen.size()))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
