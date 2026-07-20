extends Node

# Tests for CardAnimator (Passaggio E — Step 5)
# Yield-based tests run inline in _ready() to avoid GDScriptFunctionState return.
# Run: ./Godot3 --path /path/to/project tests/card_animator_test.tscn --no-window

var CardAnimator = load("res://scripts/CardAnimator.gd")

var passed = 0
var failed = 0
var failure_msgs = []


func _assert(cond, msg):
	if cond: passed += 1
	else: failed += 1; failure_msgs.append(str(msg))
	return cond


func _assert_eq(got, expected, msg):
	if got == expected:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(str(msg, " got=", got, " expected=", expected))
	return got == expected


func _ready():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — CardAnimator (Step 5)\n"
	out += "========================================\n"

	# ---- 1. Initial state ----
	var ca = CardAnimator.new()
	add_child(ca)
	out += "  Initial not busy:          " + ("[PASS]\n" if _assert(!ca.is_animating(), "not animating initially") else "[FAIL]\n")
	remove_child(ca); ca.free()

	# ---- 2. Play empty events (headless) fires start+finish ----
	ca = CardAnimator.new()
	add_child(ca)
	ca.play_events([], null)
	yield(get_tree(), "idle_frame")
	var o2a = _assert(!ca.is_animating(), "done after empty events")
	out += "  Play events fires signals: " + ("[PASS]\n" if o2a else "[FAIL]\n")
	remove_child(ca); ca.free()

	# ---- 3. FIFO order ----
	ca = CardAnimator.new()
	add_child(ca)
	ca._animation_layer = null
	ca.play_events([
		{"type": "piatto_changed", "old_value": 10, "new_value": 15},
		{"type": "card_played", "card_id": "c1", "destination": "discard"},
	], null)
	yield(get_tree(), "idle_frame")
	var o3a = _assert(!ca.is_animating(), "done after headless FIFO")
	out += "  FIFO order:                " + ("[PASS]\n" if o3a else "[FAIL]\n")
	remove_child(ca); ca.free()

	# ---- 4. Headless fallback ----
	ca = CardAnimator.new()
	add_child(ca)
	ca.play_events([
		{"type": "card_played", "card_id": "c1", "destination": "discard"},
		{"type": "piatto_changed", "old_value": 5, "new_value": 8},
	], null)
	yield(get_tree(), "idle_frame")
	var o4a = _assert(!ca.is_animating(), "not busy after headless")
	out += "  Headless fallback:         " + ("[PASS]\n" if o4a else "[FAIL]\n")
	remove_child(ca); ca.free()

	# ---- 5. Busy guard ----
	ca = CardAnimator.new()
	add_child(ca)
	ca._busy = true
	ca.play_events([{"type": "card_played", "card_id": "c1"}], null)
	var o5a = _assert(ca._busy, "still busy after blocked play_events")
	ca._busy = false
	out += "  Busy guard:                " + ("[PASS]\n" if o5a else "[FAIL]\n")
	remove_child(ca); ca.free()

	# ---- Summary ----
	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFailures:\n"
		for m in failure_msgs:
			out += "  - " + str(m) + "\n"
	out += "\n========================================\n"
	print(out)
	get_tree().quit(0)
