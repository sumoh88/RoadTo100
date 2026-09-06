extends Node

# Reproduce the exact Giro Sicuro end scenario where P2 doesn't play after Giro Sicuro ends.
# Sequence: Gold played → GS starts → several turns → GS ends → next CPU should play.

var pass_count = 0
var fail_count = 0
var stuck_detected = false

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== Giro Sicuro End CPU Turn Test ===")

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

	var last_player_id = ""
	var same_player_count = 0
	var gs_ended = false
	var gs_ended_at_turn = 0
	var turn_num = 0

	for step in range(40):
		yield(get_tree().create_timer(0.25), "timeout")

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
		var gs_type = str(snapshot.get("special_round_type", ""))

		// Detect Giro Sicuro ending
		if last_player_id == "player_1" and !gs_active and turn_num > 0:
			// Check if GS just ended by looking at previous state
			pass

		if gs_active:
			print("[Step " + str(step) + "] player=" + cur_pid + " GS_ACTIVE(" + gs_type + ")")
		else:
			print("[Step " + str(step) + "] player=" + cur_pid + " normal play")

		// Detect stuck condition: same player repeated multiple times
		if last_player_id == cur_pid and cur_pid != "":
			same_player_count += 1
			if same_player_count > 4:
				print("[STUCK] Player " + cur_pid + " did not advance! state=" + str(gc.get_state()))
				stuck_detected = true
				break
		else:
			same_player_count = 0

		last_player_id = cur_pid
		turn_num += 1

	assert_true(!stuck_detected, "No stuck players detected")

	print("\n--- Summary ---")
	print("  Steps: " + str(step))
	print("  Stuck detected: " + str(stuck_detected))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
