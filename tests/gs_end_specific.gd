extends Node

# Specifically test: Giro Sicuro ends, does next CPU play automatically?
# Drive turns manually through ManualGame to observe exact behavior.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func get_player_id(snapshot, idx):
	var players = snapshot.get("players", [])
	if idx >= 0 and idx < players.size():
		return str(players[idx].get("id", ""))
	return ""

func run():
	print("\n=== Giro Sicuro End - CPU Continuation Test ===")

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

	var gs_ended_turn = 0
	var gs_ended_next_player = ""
	var cpu_played_after_gs = false
	var stuck_count = 0
	var last_player = ""

	for step in range(50):
		yield(get_tree().create_timer(0.15), "timeout")

		var state_before = gc.get_state()
		var snap_before = gc.get_last_snapshot()

		mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			continue

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[Step " + str(step) + "] Game over! Winner: " + str(winner))
			break

		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		var gs_active = snapshot.get("special_round_active", false)

		// Detect Giro Sicuro ending
		if snap_before != null and snap_before.get("special_round_active", false) and !gs_active:
			gs_ended_turn = step
			gs_ended_next_player = cur_pid
			print("[Step " + str(step) + "] *** GIRO SICURO ENDED! Next player should be: " + cur_pid + " ***")

		if gs_active:
			print("[Step " + str(step) + "] GS active, player=" + cur_pid + " state=" + str(gc.get_state()))
		elif gs_ended_turn > 0 and step == gs_ended_turn + 1:
			print("[Step " + str(step) + "] After GS ended, player=" + cur_pid + " state=" + str(gc.get_state()) + " - checking if CPU played...")
			if cur_pid != gs_ended_next_player:
				cpu_played_after_gs = true
				print("  -> CPU DID play! Turn advanced to " + cur_pid)
			else:
				print("  -> SAME player still! Possible stuck.")

		// Detect stuck condition (same player repeated many times)
		if last_player == cur_pid and cur_pid != "":
			stuck_count += 1
			if stuck_count > 5:
				print("[Step " + str(step) + "] STUCK! Same player " + cur_pid + " for " + str(stuck_count) + " steps")
				print("  State: " + str(gc.get_state()))
				break
		else:
			stuck_count = 0

		last_player = cur_pid

	assert_true(cpu_played_after_gs or gs_ended_turn == 0, "CPU played after Giro Sicuro ended")

	print("\n--- Summary ---")
	print("  Giro Sicuro ended at step: " + str(gs_ended_turn))
	print("  CPU played after GS: " + str(cpu_played_after_gs))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
