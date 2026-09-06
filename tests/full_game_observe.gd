extends Node

# Play a full 4-player game and observe all turns, focusing on Giro Sicuro transitions.

var pass_count = 0
var fail_count = 0

func assert_true(condition, msg):
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		print("  [FAIL] " + msg)

func run():
	print("\n=== Full Game Observation Test ===")

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

	var last_gs_active = false
	var stuck_count = 0
	var last_player = ""

	for step in range(100):
		yield(get_tree().create_timer(0.2), "timeout")

		mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

		var snapshot = gc.get_last_snapshot()
		if snapshot == null:
			continue

		var winner = snapshot.get("winner", null)
		if winner != null:
			print("[Step " + str(step) + "] GAME OVER! Winner: " + str(winner))
			break

		var cur_idx = int(snapshot.get("current_player_index", -1))
		var players = snapshot.get("players", [])
		var cur_pid = ""
		if cur_idx >= 0 and cur_idx < players.size():
			cur_pid = str(players[cur_idx].get("id", ""))

		var gs_active = snapshot.get("special_round_active", false)
		var gs_type = str(snapshot.get("special_round_type", ""))
		var state = gc.get_state()

		// Detect Giro Sicuro transitions
		if last_gs_active and !gs_active:
			print("[Step " + str(step) + "] *** GIRO SICURO ENDED! Next player: " + cur_pid + " ***")
		if gs_active and !last_gs_active:
			print("[Step " + str(step) + "] *** GIRO SICURO STARTED (" + gs_type + ")! Player: " + cur_pid + " ***")

		// Track stuck condition
		if last_player == cur_pid and cur_pid != "":
			stuck_count += 1
			if stuck_count > 5:
				print("[Step " + str(step) + "] STUCK! Same player " + cur_pid + " repeated, state=" + str(state))
				break
		else:
			stuck_count = 0

		last_player = cur_pid
		last_gs_active = gs_active
		print("[Step " + str(step) + "] P=" + cur_pid + " S=" + str(state) + (gs_active ? " GS("+gs_type+")" : ""))

	print("\n--- Summary ---")
	print("  Steps: " + str(step))
	print("  Assertions passed: " + str(pass_count))
	print("  Assertions failed: " + str(fail_count))

func _ready():
	run()
	get_tree().quit()
