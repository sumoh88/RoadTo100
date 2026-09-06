extends Node

# Debug test: force a Giro Sicuro scenario and observe what happens when it ends.
# We'll set up a specific game state where Giro Sicuro is active and then manually
# advance through turns to see if P2 plays after Giro Sicuro ends.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== SR End Debug Test ===")

	var main = load("res://Main.tscn").instance()
	add_child(main)
	yield(get_tree(), "idle_frame")

	var gc = null
	var mg = null
	for c in main.get_children():
		if c.name == "GameController":
			gc = c
		elif c.name == "ManualGame":
			mg = c

	assert_true(gc != null, "GameController found")
	assert_true(mg != null, "ManualGame found")

	var snapshot_before = null

	# Hook into action_completed to track state changes
	gc.connect("action_applied", func(result):
		var snap = result.get("snapshot", null)
		if snap == null:
			return
		var events = result.get("events", [])
		var sr_active = snap.get("special_round_active", false)
		var cur_idx = int(snap.get("current_player_index", -1))
		var players = snap.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))
		print("[ACTION] after action: player=" + cur_pid + " sr_active=" + str(sr_active))
		for e in events:
			if e.get("type") == "advantage_ended":
				print("[ACTION] advantage_ended detected!")
		snapshot_before = snap
	), [])

	# Start the game
	mg.start_game()

	# Watch for several turns
	var step_count = 0
	while step_count < 20:
		yield(get_tree().create_timer(0.3), "timeout")
		var state = gc.get_state()
		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			step_count += 1
			continue

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[DONE] Game over, winner=" + str(winner))
			break

		var sr_active = snapshot.get("special_round_active", false)
		var sr_type = str(snapshot.get("special_round_type", ""))
		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		print("[STEP " + str(step_count) + "] player=" + cur_pid + " state=" + str(state) + " sr=" + str(sr_active) + "/" + sr_type)

		# Check for stuck condition (same player multiple times)
		if snapshot_before != null:
			var prev_idx = int(snapshot_before.get("current_player_index", -1))
			if prev_idx == cur_idx and step_count > 0:
				print("[WARN] Same player repeated - possible stuck!")

		snapshot_before = snapshot
		step_count += 1

		# Manual tick
		mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

	print("\n--- Summary ---")
	print("  Steps: " + str(step_count))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
