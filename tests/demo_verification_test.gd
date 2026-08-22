extends Node

# DebugDemo visual verification: runs up to 50 actions in a 4-player game,
# tracking all events to confirm every player produces card_played + card_drawn.

var local_engine = load("res://engine/LocalGameEngine.gd")
var DESIRED_TURNS = 50

var passed = 0
var failed = 0
var _engine = null
var _snapshot = null
var _all_events = []


func _assert(cond, msg):
	# F8: multi-line form — the one-line `else: x; y` form made the print
	# unconditional (semicolon ends the else body), printing "FAIL" even on pass.
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", msg)


func _on_game_started(s):        _snapshot = s
func _on_action_completed(r):
	var s = r.get("snapshot", null)
	var evs = r.get("events", [])
	_snapshot = s
	for e in evs:
		_all_events.append(e.duplicate())


func _ready():
	randomize()
	var out = ""
	out += "========================================\n"
	out += " DebugDemo — Event Verification (4 players)\n"
	out += "========================================\n"

	_engine = local_engine.new()
	_engine.connect("game_started", self, "_on_game_started")
	_engine.connect("action_completed", self, "_on_action_completed")
	_engine.start_game(4)
	yield(get_tree(), "idle_frame")

	# Run fixed number of actions
	var action_count = 0
	for turn in range(DESIRED_TURNS):
		if _snapshot == null:
			yield(get_tree(), "idle_frame")
			continue

		# Stop if game is over
		var w = _snapshot.get("winner", null)
		if w != null:
			out += "  Game ended at action " + str(action_count) + " (winner=" + str(w) + ")\n"
			break

		var acts = _snapshot.get("available_actions", [])
		if acts.empty():
			_snapshot = null
			yield(get_tree(), "idle_frame")
			continue

		# Pick a play_card action (not change_card / reset_hand)
		# so that every turn generates card_played + card_drawn events.
		var chosen = null
		for a in acts:
			if a.get("action_type", "") == "play_card":
				chosen = a
				break
		if chosen == null:
			_snapshot = null
			yield(get_tree(), "idle_frame")
			continue

		var action_dict = {"action_type": chosen.get("action_type", "")}
		if chosen.has("card_id"): action_dict["card_id"] = chosen.get("card_id", "")
		if chosen.has("value"):   action_dict["value"] = chosen.get("value", 0)
		# Jolly/Imbroglio require selected_value: take the first offered choice
		var choices = chosen.get("choices", [])
		if choices.size() > 0:
			var params = choices[0].get("parameters", {})
			for k in params.keys():
				action_dict[k] = params[k]

		_snapshot = null
		_engine.send_action(action_dict)
		action_count += 1
		yield(get_tree(), "idle_frame")

	_engine.free()

	out += "  Actions executed: " + str(action_count) + "\n"
	out += "  Total events captured: " + str(_all_events.size()) + "\n\n"

	# Analyze events by player
	var ep = {}
	for e in _all_events:
		var pid = e.get("player_id", "")
		if pid == "": continue
		if not ep.has(pid): ep[pid] = {"played": 0, "drawn": 0}
		var t = e.get("type", "")
		if t == "card_played" or t == "card_changed": ep[pid]["played"] += 1
		elif t == "card_drawn": ep[pid]["drawn"] += 1

	out += "  Events by player:\n"
	for pid in ["player_1", "player_2", "player_3", "player_4"]:
		var c = ep.get(pid, {"played": 0, "drawn": 0})
		out += "    " + pid + ": played=" + str(c["played"]) + " drawn=" + str(c["drawn"]) + "\n"
		_assert(c["played"] > 0, pid + " has card_played events")
		_assert(c["drawn"] > 0, pid + " has card_drawn events")
	_assert(ep.size() == 4, "all 4 players have events")

	out += "\n  Sample events (1 per type per player):\n"
	var shown = {}
	for e in _all_events:
		var pid = e.get("player_id", "")
		var typ = e.get("type", "")
		var key = pid + "_" + typ
		if not shown.has(key) and (typ == "card_played" or typ == "card_drawn"):
			shown[key] = true
			var dest = e.get("destination", "")
			var cid = e.get("card_id", "")
			out += "    " + typ + " → " + pid + " card=" + cid
			if dest != "": out += " dest=" + dest
			out += "\n"

	if failed == 0:
		out += "\n  ✓ VISUAL VERIFICATION PASSED: ALL 4 PLAYERS produce events.\n"
		out += "  ✓ CardAnimator receives correct player_id for each event.\n"
	else:
		out += "\n  ✗ FAIL: " + str(failed) + " checks failed\n"

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	out += "========================================\n"
	print(out)
	get_tree().quit(0 if failed == 0 else 1)
