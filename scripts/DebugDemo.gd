extends Node

# Debug/Development tool — Automatic 4-player demo.
# Routes all game logic through GameController (parent node).
# Demo only: chooses actions from available_actions, calls
# GameController.perform_action() to execute them.

var _gc = null
var timer = null
var running = false
var turn_count = 0
var max_demo_turns = 1000
var step_delay_ms = 1000

# Stats
var stats = {"play_card":0,"change_card":0,"reveal_gold":0,"reset_hand":0,"advantage_turns":0}


func _ready():
	_gc = get_parent()
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = step_delay_ms / 1000.0
	timer.connect("timeout", self, "_on_timer_timeout")
	add_child(timer)

	if _gc != null and _gc.has_signal("action_applied"):
		_gc.connect("action_applied", self, "_on_gc_action_applied")

	print("\n===== DEMO DIAGNOSTIC =====")
	if _gc != null:
		print("[Demo] GameController: " + str(_gc) + " path=" + str(_gc.get_path()))
	else:
		print("[Demo] CRITICAL: GameController not found!")
	print("===========================\n")


func _schedule_next_step():
	var jitter = randi() % 201 - 100
	var delay = max(0.05, (step_delay_ms + jitter) / 1000.0)
	timer.wait_time = delay
	timer.start()


func start_demo():
	if running:
		print("[Demo] Already running.")
		return
	if _gc == null:
		print("[Demo] CRITICAL: No GameController reference.")
		return

	print("\n========== DEMO AUTOMATICA ==========")
	running = true
	turn_count = 0
	stats = {"play_card":0,"change_card":0,"reveal_gold":0,"reset_hand":0,"advantage_turns":0}

	_gc.start_game(4)
	_schedule_next_step()


func stop_demo():
	if not running: return
	running = false
	timer.stop()
	print("[Demo] Stopped.")


func _on_timer_timeout():
	if not running or _gc == null:
		return

	var state = _gc.get_state()

	# Handle WAITING_FOR_CHOICE — gold reveal popup or value choice
	if state == 3:
		var snap = _gc.get_last_snapshot()
		if snap != null:
			for a in snap.get("available_actions", []):
				if a.get("action_type", "") == "reveal_gold":
					# Answer Yes to gold reveal
					_gc.perform_action({"action_type": "reveal_gold", "card_id": a.get("card_id", "")})
					_schedule_next_step()
					return
		# Value choice (Jolly/Imbroglio) or unknown — retry later
		_schedule_next_step()
		return

	# Only act when ready for input
	if state != 1 and state != 2:
		if state == 7:  # GAME_OVER — done
			return
		_schedule_next_step()  # Retry later
		return

	var snapshot = _gc.get_last_snapshot()
	if snapshot == null:
		_schedule_next_step()
		return

	var acts = snapshot.get("available_actions", [])
	if acts.empty():
		_schedule_next_step()
		return

	# Detect gold reveal in available_actions before GC opens popup
	for a in acts:
		if a.get("action_type", "") == "reveal_gold":
			_gc.perform_action({"action_type": "reveal_gold", "card_id": a.get("card_id", "")})
			_schedule_next_step()
			return

	var action = _choose_action(acts)
	if action == null:
		_schedule_next_step()
		return

	var at = action.get("action_type", "")
	var cid = action.get("card_id", "")

	if at == "play_card" or at == "change_card":
		var action_dict = {"action_type": at, "card_id": cid}

		# Handle Jolly/Imbroglio: pick first available value from choices
		var choices = action.get("choices", [])
		if choices.size() > 0:
			var params = choices[0].get("parameters", {})
			for k in params.keys():
				action_dict[k] = params[k]

		_gc.perform_action(action_dict)

	elif at == "reset_hand":
		_gc.perform_action({"action_type": "reset_hand"})

	_schedule_next_step()


func _choose_action(acts):
	if acts.empty():
		return null
	# Prefer play_card, then change_card, then reset_hand
	for p in ["play_card", "change_card", "reset_hand"]:
		var cs = []
		for a in acts:
			if a["action_type"] == p:
				cs.append(a)
		if not cs.empty():
			return cs[randi() % cs.size()]
	return acts[0]


func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F10:
		if running: stop_demo()
		else: start_demo()


# ---------------------------------------------------------------------------
# GC signal relay — track events for per-turn stats
# ---------------------------------------------------------------------------

func _on_gc_action_applied(result):
	var snapshot = result["snapshot"]
	var events = result.get("events", [])
	turn_count += 1

	# Print turn summary
	var event_summary = []
	for e in events:
		var es = e["type"]
		if e.has("player_id"): es += "(" + str(e["player_id"]) + ")"
		if e.has("card_id"): es += "[" + str(e["card_id"]) + "]"
		event_summary.append(es)
	print("[Demo] Turn " + str(snapshot["turn_number"]) + " — " + PoolStringArray(event_summary).join(", "))

	# Track stats
	for e in events:
		var t = e["type"]
		if t == "card_played": stats["play_card"] += 1
		elif t == "card_changed": stats["change_card"] += 1
		elif t == "gold_revealed": stats["reveal_gold"] += 1
		elif t == "hand_reset": stats["reset_hand"] += 1
		elif t == "advantage_started": stats["advantage_turns"] += 1

	# Handle game over
	if snapshot.get("winner", null) != null:
		_on_game_won(snapshot)
		return
	if turn_count >= max_demo_turns:
		stop_demo()


func _on_game_won(snapshot):
	print("\n========================================")
	print("[Demo] GAME OVER — " + str(snapshot["winner"]) + " wins!")
	print("       Turns: " + str(snapshot["turn_number"]))
	print("       Final piatto: " + str(snapshot["piatto"]))
	print("       Stats: play=" + str(stats["play_card"]) + " change=" + str(stats["change_card"]) +
		" gold=" + str(stats["reveal_gold"]) + " reset=" + str(stats["reset_hand"]) +
		" adv=" + str(stats["advantage_turns"]))
	print("========================================\n")

	running = false
