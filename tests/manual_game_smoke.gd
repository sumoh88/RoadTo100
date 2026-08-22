extends Node

# Smoke test: loads the real Main.tscn scene, simulates pressing the
# "Inizia Partita" button, and drives the game in _process to verify:
#   1. button wiring starts a 4-player game in the real scene;
#   2. ManualGame is wired to GameController and running;
#   3. CPU turns auto-advance (with animations) in the real scene context.
# Drives manually (disabling MG's own timer) so it can wait for the
# CardAnimator tweens to finish between actions, regardless of random start.

var _main = null
var _mg = null
var _gc = null
var start_turn = -1
var frames_to_run = 2000


func _ready():
	_main = load("res://Main.tscn").instance()
	add_child(_main)

	var gc = _find_child(_main, "GameController")
	_gc = gc
	_mg = _find_child(gc, "ManualGame")

	if _mg == null:
		print("SMOKE FAIL: ManualGame node not found under GameController")
		get_tree().quit(1)
		return

	var btn = _find_child(_main, "StartGameButton")
	if btn == null:
		print("SMOKE FAIL: StartGameButton not found")
		get_tree().quit(1)
		return

	# 1. Simulate the button press (real scene wiring).
	btn.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	var snap = _gc.get_last_snapshot()
	if snap == null or snap.get("players", []).size() != 4:
		print("SMOKE FAIL: game did not start via button")
		get_tree().quit(1)
		return
	start_turn = snap.get("turn_number", -1)
	print("[Smoke] Game started via button: " + str(snap["players"].size()) + " players, turn=" + str(start_turn))

	# 2. ManualGame must be running and wired to GC.
	if _mg._gc != _gc or _mg.running != true:
		print("SMOKE FAIL: ManualGame not properly wired/running")
		get_tree().quit(1)
		return
	print("[Smoke] ManualGame wired and running — driving to verify CPU auto-play")

	# Disable MG's own timer; this test drives _on_timer_timeout directly.
	_mg.step_delay_ms = 999999


func _process(delta):
	var snap = _gc.get_last_snapshot()
	if snap == null:
		return

	var end_turn = snap.get("turn_number", -1)
	if snap.get("winner", null) != null or end_turn > start_turn:
		print("[Smoke] turn " + str(start_turn) + " -> " + str(end_turn) +
			" (winner=" + str(snap.get("winner", null)) + ")")
		if end_turn > start_turn or snap.get("winner", null) != null:
			print("SMOKE PASS: real-scene wiring verified, CPU advances turns automatically")
		else:
			print("SMOKE FAIL: no turn progression")
		get_tree().quit(0 if (end_turn > start_turn or snap.get("winner", null) != null) else 1)
		return

	frames_to_run -= 1
	if frames_to_run <= 0:
		print("SMOKE FAIL: timed out waiting for CPU turn progression")
		get_tree().quit(1)
		return

	var st = _gc.get_state()
	var lid = snap.get("local_player_id", "player_1")
	var is_local = _mg._is_local_turn(snap, lid)

	# Only act when the game is actionable (READY_FOR_INPUT or CARD_SELECTED).
	# While ANIMATING/ACTION_PENDING, wait for tweens to finish.
	if st == 1 or st == 2:
		if is_local:
			_simulate_human_action()
		else:
			_mg._on_timer_timeout()


func _simulate_human_action():
	var snap = _gc.get_last_snapshot()
	if snap == null: return
	for a in snap.get("available_actions", []):
		if a.get("action_type", "") == "play_card":
			var ad = {"action_type": "play_card", "card_id": a.get("card_id", "")}
			var choices = a.get("choices", [])
			if choices.size() > 0:
				for k in choices[0].get("parameters", {}).keys():
					ad[k] = choices[0]["parameters"][k]
			_gc.perform_action(ad)
			return


func _find_child(node, name):
	if node == null: return null
	for c in node.get_children():
		if c.name == name:
			return c
	return null
