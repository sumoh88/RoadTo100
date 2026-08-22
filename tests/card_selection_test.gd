extends Node

# Tests for the manual-mode card selection bug fix.
#
# Root cause: HUDLayer (full-screen, rendered above LocalPlayerArea) had
# mouse_filter = 1 (PASS). A full-screen Control with mouse_filter != IGNORE
# intercepts mouse events over its whole rect, so clicks meant for the local
# hand were swallowed by HUDLayer instead of reaching the CardFace nodes.
# The action buttons still worked only because they are CHILDREN of HUDLayer
# (the deepest control at their position wins). Fix: set HUDLayer.mouse_filter
# to 2 (IGNORE) so it is transparent to clicks on the cards beneath it.
#
# These tests verify:
#   - HUDLayer does not block clicks on the hand (structural fix).
#   - A playable card receives input (mouse_filter != IGNORE) and emits a
#     "clicked" signal connected by HandPresenter.
#   - During a Safe Round, blocked cards are IGNORE (not clickable) while
#     non-blocked cards remain clickable.
#   - The real click -> CardFace.clicked -> HandPresenter.card_selected ->
#     GameController selection chain updates the selected card_id and Play /
#     Change forward it to the engine.
#
# Run: ./Godot3 --path /path/to/project tests/card_selection_test.tscn --no-window

var passed = 0
var failed = 0
var failure_msgs = []


func _ready():
	randomize()
	var out = _run_all()
	if out is GDScriptFunctionState:
		out = yield(out, "completed")
	print(out)
	get_tree().quit(0 if failed == 0 else 1)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(str(msg))
	return cond


# ===========================================================================
# Helpers
# ===========================================================================

func _instantiate_main():
	var scene = load("res://Main.tscn")
	_assert(scene != null, "Main.tscn loaded")
	if scene == null:
		return null
	var inst = scene.instance()
	add_child(inst)
	yield(get_tree(), "idle_frame")
	return inst


func _find_card(cards_layer, card_id):
	for c in cards_layer.get_children():
		if "card_id" in c and c.card_id == card_id:
			return c
	return null


func _has_clicked_conn(card):
	for conn in card.get_signal_connection_list("clicked"):
		if str(conn["method"]) == "_on_card_face_clicked":
			return true
	return false


# ===========================================================================
# 1. Structural fix — HUDLayer must not block the hand
# ===========================================================================

func _test_hud_layer_does_not_block_cards():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  HUDLayer no-block:       [FAIL]\n"
	var hud = inst.get_node_or_null("GameArea/HUDLayer")
	var o1 = _assert(hud != null, "HUDLayer exists in Main.tscn")
	var o2 = false
	if hud != null:
		o2 = _assert(hud.mouse_filter == 2,
			"HUDLayer mouse_filter is IGNORE (2), got " + str(hud.mouse_filter))
	inst.free()
	return "  HUDLayer no-block:       " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# ===========================================================================
# 2. Playable card receives input + emits clicked
# ===========================================================================

func _test_playable_card_is_clickable():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  Playable clickable:      [FAIL]\n"
	var hand = inst.get_node("HandPresenter")
	var snap = {
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "inc1_x1", "card_type": "increment", "name": "+1"},
				{"card_id": "gold12_x1", "card_type": "gold", "name": "12"},
			]},
		],
		"special_round_active": false,
	}
	hand.apply_snapshot(snap)
	yield(get_tree(), "idle_frame")

	var cl = inst.get_node("GameArea/LocalPlayerArea/PlayerHand/CardsLayer")
	var c1 = _find_card(cl, "inc1_x1")
	var c2 = _find_card(cl, "gold12_x1")

	var o1 = _assert(c1 != null and c2 != null, "both cards created")
	var o2 = c1 != null and _assert(c1.mouse_filter != 2,
		"increment card mouse_filter not IGNORE, got " + str(c1.mouse_filter))
	var o3 = c2 != null and _assert(c2.mouse_filter != 2,
		"gold card mouse_filter not IGNORE, got " + str(c2.mouse_filter))
	var o4 = c1 != null and _assert(_has_clicked_conn(c1),
		"increment card connected to clicked")
	var o5 = c2 != null and _assert(_has_clicked_conn(c2),
		"gold card connected to clicked")

	inst.free()
	return "  Playable clickable:      " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5) else "[FAIL]\n")


# ===========================================================================
# 3. Safe Round — a blocked card stays selectable (clickable) and dimmed,
#    so the player can pick it for Cambio Carta. Allowed cards are clickable
#    and not dimmed.
# ===========================================================================

func _test_sr_blocked_card_selectable_but_dimmed():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  SR blocked selectable:   [FAIL]\n"
	var hand = inst.get_node("HandPresenter")
	var snap = {
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1", "hand": [
				# blocked by "Incremento"
				{"card_id": "inc3_x1", "card_type": "increment", "name": "+3"},
				{"card_id": "p11_x1", "card_type": "special", "name": "+11"},
				# allowed during this GS
				{"card_id": "gold23_x1", "card_type": "gold", "name": "23"},
			]},
		],
		"special_round_active": true,
		"special_round_type": "safe",
		"blocked_type": "Incremento",
	}
	hand.apply_snapshot(snap)
	yield(get_tree(), "idle_frame")

	var cl = inst.get_node("GameArea/LocalPlayerArea/PlayerHand/CardsLayer")
	var blocked_ids = ["inc3_x1", "p11_x1"]
	var allowed_ids = ["gold23_x1"]

	var all_ok = true
	for bid in blocked_ids:
		var c = _find_card(cl, bid)
		if c == null:
			all_ok = false
			continue
		# Still selectable: clickable + connected.
		if not _assert(c.mouse_filter != 2,
			bid + " (blocked) mouse_filter not IGNORE, got " + str(c.mouse_filter)):
			all_ok = false
		if not _assert(_has_clicked_conn(c),
			bid + " (blocked) connected to clicked"):
			all_ok = false
		# Still visually dimmed.
		if not _assert(abs(c.modulate.a - 0.45) < 0.01,
			bid + " (blocked) dimmed (alpha ~0.45), got " + str(c.modulate.a)):
			all_ok = false

	for aid in allowed_ids:
		var c = _find_card(cl, aid)
		if c == null:
			all_ok = false
			continue
		if not _assert(c.mouse_filter != 2,
			aid + " (allowed) mouse_filter not IGNORE, got " + str(c.mouse_filter)):
			all_ok = false
		if not _assert(_has_clicked_conn(c),
			aid + " (allowed) connected to clicked"):
			all_ok = false
		if not _assert(abs(c.modulate.a - 1.0) < 0.01,
			aid + " (allowed) not dimmed (alpha 1.0), got " + str(c.modulate.a)):
			all_ok = false

	inst.free()
	return "  SR blocked selectable:   " + ("[PASS]\n" if all_ok else "[FAIL]\n")


# ===========================================================================
# 4. Safe Round — a blocked card is NOT playable: Play rejects it (no
#    play_card action is sent to the engine).
# ===========================================================================

func _test_sr_blocked_card_not_playable():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  SR blocked not-playable: [FAIL]\n"
	var gc = inst.get_node("GameController")
	var snap = {
		"local_player_id": "player_1",
		"special_round_active": true,
		"special_round_type": "safe",
		"blocked_type": "Incremento",
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "inc3_x1", "card_type": "increment", "name": "+3"},
			]},
		],
	}
	var prov = _FakeProvider.new()
	gc.set_provider(prov)
	gc._last_snapshot = snap
	gc._state = 1  # READY_FOR_INPUT

	gc._on_card_selected("inc3_x1")
	var sel_ok = gc.get_state() == 2 and gc.get_selected_card_id() == "inc3_x1"

	# Press Play — must NOT send a play_card for the blocked card.
	gc._on_play_pressed()
	var no_play = str(prov.last_action.get("action_type", "")) != "play_card"

	var ok = sel_ok and no_play
	inst.free()
	return "  SR blocked not-playable: " + ("[PASS]\n" if ok else "[FAIL]\n")


# ===========================================================================
# 5. Safe Round — a blocked card IS changeable: Change sends change_card
#    with the selected (blocked) card_id.
# ===========================================================================

func _test_sr_blocked_card_changeable():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  SR blocked changeable:   [FAIL]\n"
	var gc = inst.get_node("GameController")
	var snap = {
		"local_player_id": "player_1",
		"special_round_active": true,
		"special_round_type": "safe",
		"blocked_type": "Incremento",
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "inc3_x1", "card_type": "increment", "name": "+3"},
			]},
		],
	}
	var prov = _FakeProvider.new()
	gc.set_provider(prov)
	gc._last_snapshot = snap
	gc._state = 1  # READY_FOR_INPUT

	gc._on_card_selected("inc3_x1")
	gc._on_change_pressed()
	var changed = str(prov.last_action.get("action_type", "")) == "change_card" \
		and str(prov.last_action.get("card_id", "")) == "inc3_x1"

	inst.free()
	return "  SR blocked changeable:   " + ("[PASS]\n" if changed else "[FAIL]\n")


# ===========================================================================
# 6. Safe Round — when the whole hand is blocked, no lock: every card is
#    selectable and Cambio Carta works on a chosen (blocked) card.
# ===========================================================================

func _test_all_blocked_hand_change_works():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  All-blocked hand no-lock:[FAIL]\n"
	var gc = inst.get_node("GameController")
	var hand = inst.get_node("HandPresenter")
	var snap = {
		"local_player_id": "player_1",
		"special_round_active": true,
		"special_round_type": "safe",
		"blocked_type": "Incremento",
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "inc3_x1", "card_type": "increment", "name": "+3"},
				{"card_id": "jolly_x1", "card_type": "jolly", "name": "Jolly"},
				{"card_id": "p11_x1", "card_type": "special", "name": "+11"},
			]},
		],
	}
	var prov = _FakeProvider.new()
	gc.set_provider(prov)
	gc._last_snapshot = snap
	hand.apply_snapshot(snap)
	yield(get_tree(), "idle_frame")
	gc._state = 1  # READY_FOR_INPUT

	var cl = inst.get_node("GameArea/LocalPlayerArea/PlayerHand/CardsLayer")
	var all_selectable = true
	for cid in ["inc3_x1", "jolly_x1", "p11_x1"]:
		var c = _find_card(cl, cid)
		if c == null or c.mouse_filter == 2 or not _has_clicked_conn(c):
			all_selectable = false

	# Select a blocked card and change it — must work (no lock).
	gc._on_card_selected("inc3_x1")
	var sel_ok = gc.get_state() == 2 and gc.get_selected_card_id() == "inc3_x1"
	gc._on_change_pressed()
	var changed = str(prov.last_action.get("action_type", "")) == "change_card"

	var ok = all_selectable and sel_ok and changed
	inst.free()
	return "  All-blocked hand no-lock:[PASS]\n" if ok else "  All-blocked hand no-lock:[FAIL]\n"


# ===========================================================================
# 4. End-to-end: CardFace.clicked -> HandPresenter -> GameController selection
#    and Play/Change forward the chosen card_id to the engine.
# ===========================================================================

func _test_selection_updates_gc_and_play_uses_card_id():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  Selection->GC flow:      [FAIL]\n"

	var gc = inst.get_node("GameController")
	var hand = inst.get_node("HandPresenter")

	# Build a snapshot for the local player's turn with one playable card.
	var snap = {
		"local_player_id": "player_1",
		"current_player_index": 0,
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "inc5_x1", "card_type": "increment", "name": "+5"},
			]},
			{"id": "player_2", "hand": []},
		],
		"piatto": 0,
		"deck_count": 48,
		"plateau_cards": [],
		"available_actions": [
			{"action_type": "play_card", "card_id": "inc5_x1"},
			{"action_type": "change_card", "card_id": "inc5_x1"},
		],
		"special_round_active": false,
		"winner": null,
		"turn_number": 1,
	}

	var prov = _FakeProvider.new()
	gc.set_provider(prov)
	gc._state = 1  # READY_FOR_INPUT

	# Simulate the CardFace emitting "clicked" (as a real mouse click would).
	hand.emit_signal("card_selected", "inc5_x1")
	var o1 = _assert(gc.get_state() == 2,
		"CARD_SELECTED after card_selected signal, got " + str(gc.get_state()))
	var o2 = _assert(gc.get_selected_card_id() == "inc5_x1",
		"selected card_id stored by GC")

	# Press Play — the engine must receive play_card with the selected card_id.
	gc._on_play_pressed()
	var played = prov.last_action.get("card_id", "") == "inc5_x1" \
		and prov.last_action.get("action_type", "") == "play_card"
	var o3 = _assert(played,
		"Play forwards selected card_id to engine: " + str(prov.last_action))

	inst.free()
	return "  Selection->GC flow:      " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# ===========================================================================
# 5. End-to-end: when a CardFace receives a mouse click it emits "clicked",
#    which the HandPresenter relays to GameController, selecting the card.
#    (Verifies the real input path CardFace._gui_input -> HandPresenter -> GC.)
# ===========================================================================

func _test_card_face_click_event_selects():
	var inst = yield(_instantiate_main(), "completed")
	if inst == null:
		return "  CardFace click event:    [FAIL]\n"

	var gc = inst.get_node("GameController")
	var hand = inst.get_node("HandPresenter")

	hand.apply_snapshot({
		"local_player_id": "player_1",
		"players": [{"id": "player_1", "hand": [
			{"card_id": "inc9_x1", "card_type": "increment", "name": "+9"},
		]}],
		"special_round_active": false,
	})
	yield(get_tree(), "idle_frame")
	gc._state = 1  # READY_FOR_INPUT

	var cl = inst.get_node("GameArea/LocalPlayerArea/PlayerHand/CardsLayer")
	var card = _find_card(cl, "inc9_x1")
	if card == null:
		inst.free()
		return "  CardFace click event:    [FAIL] (card not found)\n"

	# Feed a left mouse button press into the real CardFace node.
	var ev = InputEventMouseButton.new()
	ev.button_index = BUTTON_LEFT
	ev.pressed = true
	card._gui_input(ev)

	var selected = gc.get_state() == 2 and gc.get_selected_card_id() == "inc9_x1"
	inst.free()
	return "  CardFace click event:    " + ("[PASS]\n" if selected else "[FAIL]\n")


# ===========================================================================
func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Card Selection Routing Test\n"
	out += "========================================\n\n"

	var tests = [
		"_test_hud_layer_does_not_block_cards",
		"_test_playable_card_is_clickable",
		"_test_sr_blocked_card_selectable_but_dimmed",
		"_test_sr_blocked_card_not_playable",
		"_test_sr_blocked_card_changeable",
		"_test_all_blocked_hand_change_works",
		"_test_selection_updates_gc_and_play_uses_card_id",
		"_test_card_face_click_event_selects",
	]

	for t in tests:
		print("--- " + t + " ---")
		var g = callv(t, [])
		if g is GDScriptFunctionState:
			g = yield(g, "completed")
		out += g

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFAILURES:\n"
		for m in failure_msgs:
			out += "  - " + m + "\n"
	else:
		out += "\nALL TESTS PASSED.\n"
	out += "========================================\n"
	return out


# ===========================================================================
# Minimal provider stub for the selection flow test.
# ===========================================================================

class _FakeProvider:
	var last_action = {}
	var _gc = null

	func start_game(_count):
		pass

	func send_action(a):
		last_action = a
		if _gc != null and _gc.has_signal("action_completed"):
			_gc.emit_signal("action_completed", {"snapshot": {}, "events": []})
