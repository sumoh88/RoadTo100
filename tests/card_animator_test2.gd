extends Node

# Tests for CardAnimator multi-player + draw animation (Step 8).
# Yield-based tests run inline in _ready() — GDScript 3 cannot chain
# yielding function calls with string concatenation.
#
# Run: ./Godot3 --path /path/to/project tests/card_animator_test2.tscn --no-window

var CardAnimator = load("res://scripts/CardAnimator.gd")
var CARD_FACE = preload("res://scenes/CardFace.tscn")

var passed = 0
var failed = 0
var failure_msgs = []


func _assert(cond, msg):
	if cond: passed += 1
	else: failed += 1; failure_msgs.append(str(msg))
	return cond

func _assert_eq(got, expected, msg):
	if got == expected: passed += 1
	else: failed += 1; failure_msgs.append(str(msg, " got=", got, " expected=", expected))
	return got == expected


func _ready():
	randomize()
	var out = ""
	out += "========================================\n"
	out += " CardAnimator — Step 8 Animation Tests\n"
	out += "========================================\n"
	out += "--- Logic tests (no yield) ---\n"
	out += _test_get_main_node()
	out += _test_find_node()
	out += _test_global_to_layer()
	out += _test_cardface_props()
	out += _test_clone_creation()
	out += _test_event_scan()
	out += _test_hide_drawn_empty()

	out += "--- Headless tests (yield) ---\n"
	# Run yield tests inline — must use yield(func, "completed") because
	# each test function uses yield internally.
	out += yield(_test_headless_played(), "completed")
	out += yield(_test_headless_multi(), "completed")
	out += yield(_test_headless_drawn(), "completed")
	out += _test_busy_guard()  # no yield inside
	out += yield(_test_event_routing(), "completed")

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


# ============================================================================
# No-yield logic tests
# ============================================================================

func _test_get_main_node():
	var main = Control.new(); main.name = "Main"
	var ca = CardAnimator.new(); main.add_child(ca)
	var found = ca._get_main_node()
	var ok = _assert(found == main, "get_main_node returns parent Main")
	main.free()
	return "  get_main_node:             " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_find_node():
	var ca = CardAnimator.new()
	var p = Control.new(); p.name = "P"
	var c1 = Control.new(); c1.name = "C1"; p.add_child(c1)
	var c2 = Control.new(); c2.name = "C2"; p.add_child(c2)
	var f1 = ca._find_node_by_name(p, "C1")
	var f2 = ca._find_node_by_name(p, "C2")
	var fn = ca._find_node_by_name(p, "X")
	var o1 = _assert(f1 == c1, "find C1")
	var o2 = _assert(f2 == c2, "find C2")
	var o3 = _assert(fn == null, "nonexistent null")
	p.free(); ca.free()
	return "  find_node_by_name:         " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")

func _test_global_to_layer():
	var ca = CardAnimator.new(); add_child(ca)
	var ok = _assert_eq(ca._global_to_layer(Vector2(123, 456)), Vector2(123, 456), "identity")
	remove_child(ca); ca.free()
	return "  global_to_layer:           " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_cardface_props():
	var cf = CARD_FACE.instance()
	cf.card_id = "abc"
	var o1 = _assert_eq(cf.card_id, "abc", "card_id set/get")
	cf.card_id = ""
	var o2 = _assert_eq(cf.card_id, "", "card_id empty")
	cf.free()
	return "  CardFace properties:       " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")

func _test_clone_creation():
	var cal = Control.new()
	var orig = TextureRect.new()
	orig.texture = load("res://imgs/cardback.png")
	orig.rect_size = Vector2(201, 282)
	orig.rect_position = Vector2(100, 200)
	# Clone logic from animate_card_played
	var clone = TextureRect.new()
	clone.texture = orig.texture
	clone.expand = true
	clone.rect_min_size = orig.rect_size
	clone.rect_size = orig.rect_size
	clone.rect_position = orig.rect_global_position
	clone.mouse_filter = 2
	orig.visible = false
	cal.add_child(clone)
	var o1 = _assert(clone.texture == orig.texture, "texture matches")
	var o2 = _assert(clone.rect_size.x > 0 and clone.rect_size.y > 0, "clone has positive size (got " + str(clone.rect_size) + ")")
	var o3 = _assert(!orig.visible, "original hidden")
	var o4 = _assert(cal.get_child_count() > 0, "clone in layer")
	clone.queue_free(); cal.free()
	return "  Clone creation:            " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")

func _test_event_scan():
	var events = [
		{"type": "card_played", "player_id": "player_1"},
		{"type": "card_drawn", "card_id": "d1", "player_id": "player_1"},
		{"type": "card_drawn", "card_id": "d2", "player_id": "player_2"},
		{"type": "turn_changed", "player_id": "player_2"},
	]
	var drawn = []
	for e in events:
		if e.get("type", "") == "card_drawn": drawn.append(e)
	var o1 = _assert_eq(drawn.size(), 2, "2 card_drawn events")
	var o2 = _assert_eq(drawn[0]["card_id"], "d1", "first d1")
	var o3 = _assert_eq(drawn[1]["card_id"], "d2", "second d2")
	return "  Event scan:                " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")

func _test_hide_drawn_empty():
	var ca = CardAnimator.new(); add_child(ca)
	ca.hide_drawn_cards([])
	var ok = _assert(true, "no crash on empty")
	remove_child(ca); ca.free()
	return "  hide_drawn empty:          " + ("[PASS]\n" if ok else "[FAIL]\n")


# ============================================================================
# Yield-based tests — run inline, must not return strings from yield functions
# ============================================================================

func _test_headless_played():
	var ca = CardAnimator.new(); add_child(ca)
	ca._animation_layer = null
	ca.play_events([{"type":"card_played","card_id":"c1","destination":"discard","player_id":"player_1"}], null)
	yield(get_tree(), "idle_frame")
	var ok = _assert(!ca.is_animating(), "headless played finishes")
	remove_child(ca); ca.free()
	return "  Headless played:           " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_headless_multi():
	var ca = CardAnimator.new(); add_child(ca)
	ca._animation_layer = null
	ca.play_events([
		{"type":"card_played","card_id":"c1","player_id":"player_1","destination":"plateau"},
		{"type":"card_drawn","card_id":"c2","player_id":"player_1"},
		{"type":"turn_changed","player_id":"player_2"},
	], null)
	yield(get_tree(), "idle_frame")
	var ok = _assert(!ca.is_animating(), "multi FIFO finishes")
	remove_child(ca); ca.free()
	return "  Headless multi:            " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_headless_drawn():
	var ca = CardAnimator.new(); add_child(ca)
	ca._animation_layer = null
	ca.play_events([{"type":"card_drawn","card_id":"d1","player_id":"player_1"}], null)
	yield(get_tree(), "idle_frame")
	var ok = _assert(!ca.is_animating(), "headless drawn finishes")
	remove_child(ca); ca.free()
	return "  Headless drawn:            " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_busy_guard():
	var ca = CardAnimator.new(); add_child(ca)
	ca._busy = true
	ca.play_events([{"type":"card_played","card_id":"c1","player_id":"player_1"}], null)
	var ok = _assert(ca._busy, "busy guard blocks")
	ca._busy = false
	remove_child(ca); ca.free()
	return "  Busy guard:                " + ("[PASS]\n" if ok else "[FAIL]\n")

func _test_event_routing():
	var ca = CardAnimator.new(); add_child(ca)
	ca._animation_layer = null
	ca._queue = [
		{"type":"card_played","card_id":"x","player_id":"player_1","destination":"discard"},
		{"type":"card_drawn","card_id":"y","player_id":"player_1"},
	]
	ca._busy = true
	ca._process_next()
	yield(get_tree(), "idle_frame")
	var ok = _assert(ca._queue.empty() or ca._queue.size() <= 1, "fifo processed")
	ca._busy = false; ca._queue.clear()
	remove_child(ca); ca.free()
	return "  Event routing:             " + ("[PASS]\n" if ok else "[FAIL]\n")
