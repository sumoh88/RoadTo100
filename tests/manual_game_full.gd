extends Node

# Full manual game test — loads Main.tscn and runs the game.
# Logs each turn to verify P1→P2→P3→P4 progression.

var pass_count = 0
var fail_count = 0
var turns_seen = []
var step_count = 0
var main_scene = null

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== Full Manual Game Test (real scene) ===")

	# Load the Main scene
	main_scene = load("res://Main.tscn").instance()
	add_child(main_scene)

	# Wait for the scene to initialize
	yield(get_tree(), "idle_frame")

	# Find the GameController in the loaded scene
	var gc = null
	for c in main_scene.get_children():
		if c.name == "GameController":
			gc = c
			break

	if gc == null:
		print("  [FAIL] GameController not found!")
		return

	# Find ManualGame
	var mg = null
	for c in main_scene.get_children():
		if c.name == "ManualGame":
			mg = c
			break

	if mg == null:
		print("  [FAIL] ManualGame not found!")
		return

	# Track the previous player to detect hangs
	var prev_player = ""

	# Run 15 timer ticks (should cover multiple turns)
	for i in range(15):
		mg._on_timer_timeout()
		step_count += 1

		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			break

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[Step " + str(i) + "] Game over! Winner: " + str(winner))
			break

		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		var state = gc.get_state()
		print("[Step " + str(i) + "] Player: " + cur_pid + ", State: " + str(state) + ", Piatto: " + str(snapshot.get("piatto", 0)))

		if prev_player != "" and prev_player == cur_pid and i > 0:
			print("  [WARN] Same player twice in a row - possible hang!")

		turns_seen.append(cur_pid)
		prev_player = cur_pid

	print("\nTurns seen: " + str(turns_seen))

	# Verify that all 4 players had at least one turn
	var players_acted = {}
	for p in turns_seen:
		players_acted[p] = true

	assert_true(players_acted.has("player_1"), "P1 should have acted")
	assert_true(players_acted.has("player_2"), "P2 should have acted")
	assert_true(players_acted.has("player_3"), "P3 should have acted")
	assert_true(players_acted.has("player_4"), "P4 should have acted")

	print("\n--- Summary ---")
	print("  Steps executed: " + str(step_count))
	print("  Turns seen: " + str(turns_seen.size()))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
