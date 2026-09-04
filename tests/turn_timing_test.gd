extends Node

# Test turn timing: verify that CPUs play automatically after each action
# and that the game progresses through P1→P2→P3→P4 correctly.

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
	print("\n=== Turn Timing Test ===")

	# Load the Main scene
	var main = load("res://Main.tscn").instance()
	add_child(main)

	# Wait for the scene to initialize
	yield(get_tree(), "idle_frame")

	# Find the GameController and ManualGame nodes
	var gc = null
	var mg = null
	for c in main.get_children():
		if c.name == "GameController":
			gc = c
		elif c.name == "ManualGame":
			mg = c

	assert_true(gc != null, "GameController found")
	assert_true(mg != null, "ManualGame found")

	# Run 10 timer ticks to trigger several turns
	for i in range(10):
		mg._on_timer_timeout()
		
		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			break

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[Turn " + str(i) + "] Game over! Winner: " + str(winner))
			break

		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		print("[Turn " + str(i) + "] Player: " + cur_pid)
		turns_seen.append(cur_pid)

	# Verify that all 4 players had at least one turn
	var players_acted = {}
	for p in turns_seen:
		players_acted[p] = true

	assert_true(players_acted.has("player_1"), "P1 acted")
	assert_true(players_acted.has("player_2"), "P2 acted")
	assert_true(players_acted.has("player_3"), "P3 acted")
	assert_true(players_acted.has("player_4"), "P4 acted")

	print("\nTurns seen: " + str(turns_seen))
	print("\n--- Summary ---")
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
