extends Node

# Debug/Development tool — Automatic 4-player demo.
# Connects to real presenters in Main.tscn and verifies visual updates.

signal game_started(snapshot)
signal action_completed(result)

var _LocalGameEngine = load("res://engine/LocalGameEngine.gd")

var engine = null
var timer = null
var running = false
var turn_count = 0
var max_demo_turns = 1000
var step_delay_ms = 1000

# Explicit presenter references (set from _ready via explicit paths)
var _board = null
var _hand = null
var _turn = null

# Stats
var stats = {"play_card":0,"change_card":0,"reveal_gold":0,"reset_hand":0,"advantage_turns":0}


func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = step_delay_ms / 1000.0
	timer.connect("timeout", self, "_on_timer_timeout")
	add_child(timer)

	# Find presenters via their sibling relationship to Main
	# DebugDemo is at: Main/GameController/DebugDemo
	# Presenters are at: Main/BoardPresenter, Main/HandPresenter, Main/TurnPresenter
	var main_node = get_node("../../")  # Main
	if main_node == null:
		print("[Demo] CRITICAL: Cannot find Main node!")
		return

	for c in main_node.get_children():
		var name = c.name
		if name == "BoardPresenter":
			_board = c
		elif name == "HandPresenter":
			_hand = c
		elif name == "TurnPresenter":
			_turn = c

	# Diagnostic: report what was found
	print("\n===== DEMO DIAGNOSTIC =====")
	print("Main node: " + str(main_node) + " (children: " + str(main_node.get_child_count()) + ")")
	for c in main_node.get_children():
		var script = c.get_script()
		var has_script = script != null
		var has_update = false
		if has_script:
			has_update = c.has_method("apply_snapshot")
		var sc_name = ""
		if has_script:
			sc_name = script.resource_path
		print("  child: " + c.name + " script=" + str(has_script) + " has_update=" + str(has_update) + " path=" + sc_name)

	if _board != null:
		print("[Demo] BoardPresenter found: " + str(_board))
		var bp_path = _board.get_path()
		print("[Demo]   path: " + str(bp_path))
		# Call a diagnostic method to check internal refs
		if _board.has_method("diagnose"):
			_board.diagnose()
		else:
			print("[Demo]   WARNING: BoardPresenter has no diagnose() method")
	else:
		print("[Demo] CRITICAL: BoardPresenter not found!")

	if _hand != null:
		print("[Demo] HandPresenter found: " + str(_hand))
		var hp_path = _hand.get_path()
		print("[Demo]   path: " + str(hp_path))
		if _hand.has_method("diagnose"):
			_hand.diagnose()
		else:
			print("[Demo]   WARNING: HandPresenter has no diagnose() method")
	else:
		print("[Demo] CRITICAL: HandPresenter not found!")

	if _turn != null:
		print("[Demo] TurnPresenter found: " + str(_turn))
		var tp_path = _turn.get_path()
		print("[Demo]   path: " + str(tp_path))
		if _turn.has_method("diagnose"):
			_turn.diagnose()
		else:
			print("[Demo]   WARNING: TurnPresenter has no diagnose() method")
	else:
		print("[Demo] CRITICAL: TurnPresenter not found!")

	print("===========================\n")

	# Demo starts only via button press (DemoButton) or F10 key — no auto-start.


func _schedule_next_step():
	var jitter = randi() % 201 - 100
	var delay = max(0.05, (step_delay_ms + jitter) / 1000.0)
	timer.wait_time = delay
	timer.start()


func _update_presenters(snapshot, label):
	"""Update all presenters and print diagnostic of real node state."""
	if _board != null and _board.has_method("apply_snapshot"):
		_board.apply_snapshot(snapshot)
	if _hand != null and _hand.has_method("apply_snapshot"):
		_hand.apply_snapshot(snapshot)
	if _turn != null and _turn.has_method("apply_snapshot"):
		_turn.apply_snapshot(snapshot)

	# Real node state check (only for first update and periodically)
	if randi() % 10 == 0 or label == "first":
		_diagnose_real_state(snapshot, label)


func _diagnose_real_state(snapshot, label):
	"""Print the actual state of UI nodes after an update."""
	var out = "[Demo] UI state [" + label + "]:"
	if _board != null and _board.has_method("_diagnose_nodes"):
		out += _board._diagnose_nodes()
	if _hand != null and _hand.has_method("_diagnose_nodes"):
		out += _hand._diagnose_nodes()
	if _turn != null and _turn.has_method("_diagnose_nodes"):
		out += _turn._diagnose_nodes()
	print(out)


# ----- Engine signal handlers -----

func _on_engine_game_started(snapshot):
	print("\n[Demo] Game started — 4 players")
	_update_presenters(snapshot, "first")
	_schedule_next_step()


func _on_engine_action_completed(result):
	var snapshot = result["snapshot"]
	var events = result["events"]
	turn_count += 1

	_update_presenters(snapshot, "turn" + str(turn_count))

	var event_summary = []
	for e in events:
		var es = e["type"]
		if e.has("player_id"): es += "(" + str(e["player_id"]) + ")"
		if e.has("card_id"): es += "[" + str(e["card_id"]) + "]"
		event_summary.append(es)
	print("[Demo] Turn " + str(snapshot["turn_number"]) + " — " + PoolStringArray(event_summary).join(", "))

	for e in events:
		var t = e["type"]
		if t == "card_played": stats["play_card"] += 1
		elif t == "card_changed": stats["change_card"] += 1
		elif t == "gold_revealed": stats["reveal_gold"] += 1
		elif t == "hand_reset": stats["reset_hand"] += 1
		elif t == "advantage_started": stats["advantage_turns"] += 1

	if snapshot["winner"] != null:
		_on_game_won(snapshot)
		return
	if turn_count >= max_demo_turns:
		stop_demo()
		return
	_schedule_next_step()


func _on_engine_action_rejected(msg):
	print("[Demo] Action rejected: " + str(msg))
	_schedule_next_step()


func _on_timer_timeout():
	if not running or engine == null:
		return
	var snapshot = engine._build_snapshot()
	var action = _choose_action(snapshot)
	if action == null:
		stop_demo()
		return
	engine.send_action(_build_engine_action(action))


func _choose_action(snapshot):
	var acts = snapshot["available_actions"]
	if acts.empty(): return null
	for p in ["reveal_gold","play_card","change_card","reset_hand"]:
		var cs = []
		for a in acts:
			if a["action_type"] == p: cs.append(a)
		if !cs.empty(): return cs[randi() % cs.size()]
	return acts[0]


func _build_engine_action(pa):
	var a = {"action_type": pa["action_type"]}
	if pa.has("card_id"): a["card_id"] = pa["card_id"]
	if pa.has("choices") and !pa["choices"].empty():
		var ch = pa["choices"][0]
		for k in ch["parameters"].keys(): a[k] = ch["parameters"][k]
	return a


func _on_game_won(snapshot):
	print("\n========================================")
	print("[Demo] GAME OVER — " + str(snapshot["winner"]) + " wins!")
	print("       Turns: " + str(snapshot["turn_number"]))
	print("       Final piatto: " + str(snapshot["piatto"]))
	print("       Stats: play=" + str(stats["play_card"]) + " change=" + str(stats["change_card"]) +
		" gold=" + str(stats["reveal_gold"]) + " reset=" + str(stats["reset_hand"]) +
		" adv=" + str(stats["advantage_turns"]))
	print("========================================\n")

	_update_presenters(snapshot, "gameover")
	running = false


func start_demo():
	if running:
		print("[Demo] Already running.")
		return
	print("\n========== DEMO AUTOMATICA ==========")
	running = true
	turn_count = 0
	stats = {"play_card":0,"change_card":0,"reveal_gold":0,"reset_hand":0,"advantage_turns":0}

	engine = _LocalGameEngine.new()
	engine.connect("game_started", self, "_on_engine_game_started")
	engine.connect("action_completed", self, "_on_engine_action_completed")
	engine.connect("action_rejected", self, "_on_engine_action_rejected")
	engine.start_game(4)


func stop_demo():
	if not running: return
	running = false
	timer.stop()
	print("[Demo] Stopped.")
	if engine != null:
		engine.disconnect("game_started", self, "_on_engine_game_started")
		engine.disconnect("action_completed", self, "_on_engine_action_completed")
		engine.disconnect("action_rejected", self, "_on_engine_action_rejected")
		engine = null


func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F10:
		if running: stop_demo()
		else: start_demo()
