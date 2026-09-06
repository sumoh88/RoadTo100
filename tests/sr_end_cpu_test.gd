extends Node

# Test: Giro Sicuro ends, verify CPU can play on the next turn.
# This isolates the specific scenario where the game gets stuck after SR ends.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

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

	var sr_ended_seen = false
	var cpu_played_after_sr = false
	var stuck_count = 0
	var last_player = ""
	var last_snapshot = null

	for step in range(25):
		yield(get_tree().create_timer(0.4), "timeout")

		mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			print("[Step " + str(step) + "] No snapshot yet")
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

		var sr_active = snapshot.get("special_round_active", false)
		var sr_type = str(snapshot.get("special_round_type", ""))
		var state = gc.get_state()

		print("[Step " + str(step) + "] player=" + cur_pid + " state=" + str(state) + " sr_active=" + str(sr_active))

		if last_snapshot != null:
			var prev_sr_active = last_snapshot.get("special_round_active", false)
			var prev_sr_type = str(last_snapshot.get("special_round_type", ""))
			if prev_sr_active and prev_sr_type == "safe" and !sr_active:
				sr_ended_seen = true
				print("[Step " + str(step) + "] SR ENDED! Next player should be " + cur_pid)

		if sr_ended_seen and !cpu_played_after_sr and cur_pid != "player_1":
			cpu_played_after_sr = true
			print("[Step " + str(step) + "] CPU PLAYED after SR: " + cur_pid)

		if last_player == cur_pid and cur_pid != "":
			stuck_count += 1
			if stuck_count > 3:
				print("[Step " + str(step) + "] STUCK! Same player " + cur_pid + " repeated")
				var acts = snapshot.get("available_actions", [])
				print("  Available actions count: " + str(acts.size()))
				for a in acts:
					print("    - " + str(a))
				break
		else:
			stuck_count = 0

		last_player = cur_pid
		last_snapshot = snapshot

	assert_true(sr_ended_seen, "Giro Sicuro activated and ended")
	assert_true(cpu_played_after_sr, "CPU played after SR ended")

	print("\n--- Summary ---")
	print("  SR ended seen: " + str(sr_ended_seen))
	print("  CPU played after SR: " + str(cpu_played_after_sr))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
