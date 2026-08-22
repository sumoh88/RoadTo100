extends Node

# Tests for Passaggio E — GameController (Steps 1 + 2)
# Step 1: state machine, provider connection, presenter updates.
# Step 2: card selection, HandPresenter signal wiring.
#
# Run: ./Godot3 --path /path/to/project tests/game_controller_test.tscn --no-window

var GameController = load("res://scripts/GameController.gd")
var MockProvider = load("res://tests/mock_provider.gd")
var MockPresenter = load("res://tests/mock_presenter.gd")

var passed = 0
var failed = 0
var failure_msgs = []


func _ready():
	randomize()
	var out = _run_all()
	print(out)
	get_tree().quit(0)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(str(msg))
	return cond


func _assert_eq(got, expected, msg):
	if got == expected:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(str(msg, "  got=", got, " expected=", expected))
	return got == expected


# ===========================================================================
# Helpers
# ===========================================================================

# Create GC + mock provider + mock hand, reach READY_FOR_INPUT.
# Returns {gc, mp, bp, hp, tp} — caller must free all via _cleanup().
func _setup_gc_with_hand():
	var gc = GameController.new()
	var mp = MockProvider.new()
	mp.auto_emit_game_started = false
	gc.set_provider(mp)
	add_child(gc)

	var bp = MockPresenter.new()
	var hp = MockPresenter.new()
	var tp = MockPresenter.new()
	gc._board = bp
	gc._hand = hp
	gc._turn = tp
	hp.connect("card_selected", gc, "_on_card_selected")
	tp.connect("play_pressed", gc, "_on_play_pressed")
	tp.connect("change_pressed", gc, "_on_change_pressed")
	tp.connect("cancel_pressed", gc, "_on_cancel_pressed")

	return {"gc": gc, "mp": mp, "bp": bp, "hp": hp, "tp": tp}


func _cleanup(data):
	var gc = data["gc"]
	var mp = data["mp"]
	var bp = data["bp"]
	var hp = data["hp"]
	var tp = data["tp"]
	remove_child(gc)
	gc.free()
	mp.free()
	bp.free()
	hp.free()
	tp.free()


func _make_snapshot(player_count, winner):
	var players = []
	for i in range(player_count):
		players.append({
			"id": "player_" + str(i + 1),
			"name": "Player " + str(i + 1),
			"hand_count": 3,
			"hand": [],
		})
	return {
		"players": players,
		"current_player_index": 0,
		"piatto": 0,
		"deck_count": 60 - player_count * 3,
		"discard_top": null,
		"plateau_cards": [],
		"plateau_visual_stack": [{"type": "plate", "value": 0}],
		"special_round_active": false,
		"special_round_player_id": null,
		"winner": winner,
		"turn_number": 0,
		"available_actions": [],
		"phase": "game_over" if winner != null else "playing",
		"local_player_id": "player_1",
	}


# ===========================================================================
# Step 1 tests (7)
# ===========================================================================

func _test_initial_state():
	var gc = GameController.new()
	var ok = _assert_eq(gc.get_state(), 0, "initial state WAITING_FOR_STATE (0)")
	gc.free()
	return "  Initial WAITING_FOR_STATE:  " + ("[PASS]\n" if ok else "[FAIL]\n")


func _test_start_game_forwards():
	var gc = GameController.new()
	var mp = MockProvider.new()
	mp.auto_emit_game_started = false
	gc.set_provider(mp)
	gc.start_game(3)
	var o1 = _assert(mp.start_game_called, "provider.start_game() called")
	var o2 = _assert_eq(mp.last_start_game_count, 3, "player count forwarded")
	var o3 = _assert_eq(gc.get_state(), 0, "still WAITING_FOR_STATE (0)")
	mp.free(); gc.free()
	return "  start_game forwards:       " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


func _test_game_started_updates_presenters():
	var d = _setup_gc_with_hand()
	var mp = d["mp"]
	var snap = _make_snapshot(2, null)
	mp.emit_signal("game_started", snap)
	var o1 = _assert(d["bp"].last_snapshot != null, "Board received snapshot")
	var o2 = _assert(d["hp"].last_snapshot != null, "Hand received snapshot")
	var o3 = _assert(d["tp"].last_snapshot != null, "Turn received snapshot")
	var o4 = _assert(d["gc"].get_last_snapshot() != null, "GC stored snapshot")
	_cleanup(d)
	return "  game_started updates:      " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


func _test_game_started_transition_ready():
	var d = _setup_gc_with_hand()
	d["mp"].emit_signal("game_started", _make_snapshot(2, null))
	var ok = _assert_eq(d["gc"].get_state(), 1, "READY_FOR_INPUT (1)")
	_cleanup(d)
	return "  Transition to READY_INPUT: " + ("[PASS]\n" if ok else "[FAIL]\n")


func _test_winner_transition_game_over():
	var d = _setup_gc_with_hand()
	d["mp"].emit_signal("game_started", _make_snapshot(2, "player_1"))
	var o1 = _assert_eq(d["gc"].get_state(), 7, "GAME_OVER (7)")
	var o2 = _assert(d["gc"].get_last_snapshot() != null, "snapshot stored")
	var win = d["gc"].get_last_snapshot().get("winner", null)
	var o3 = _assert_eq(win, "player_1", "winner stored")
	_cleanup(d)
	return "  Winner -> GAME_OVER:        " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


func _test_action_rejected_resets():
	var d = _setup_gc_with_hand()
	d["mp"].emit_signal("game_started", _make_snapshot(2, null))
	var was_ready = _assert_eq(d["gc"].get_state(), 1, "was READY before rejection")
	d["mp"].auto_emit_action_rejected = true
	d["mp"].rejection_message = "Invalid action"
	d["mp"].send_action({"action_type": "bad"})
	var o2 = _assert_eq(d["gc"].get_state(), 1, "returns to READY after rejection")
	_cleanup(d)
	return "  Rejection resets:          " + ("[PASS]\n" if (was_ready and o2) else "[FAIL]\n")


func _test_null_snapshot_safe():
	var gc = GameController.new()
	var mp = MockProvider.new()
	mp.auto_emit_game_started = false
	gc.set_provider(mp)
	add_child(gc)
	var bp = MockPresenter.new(); var hp = MockPresenter.new(); var tp = MockPresenter.new()
	gc._board = bp; gc._hand = hp; gc._turn = tp
	gc._apply_snapshot(null)
	var o1 = _assert(bp.last_snapshot == null, "Board not updated with null")
	var o2 = _assert(hp.last_snapshot == null, "Hand not updated with null")
	var o3 = _assert(tp.last_snapshot == null, "Turn not updated with null")
	gc._apply_snapshot({})
	var o4 = _assert(bp.last_snapshot != null, "Board updated with empty dict")
	remove_child(gc); gc.free(); mp.free(); bp.free(); hp.free(); tp.free()
	return "  Null/empty snapshot safe:  " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# ===========================================================================
# Step 2 tests — Card selection
# ===========================================================================

# 2.1 READY_FOR_INPUT + click -> CARD_SELECTED
func _test_click_ready_selects():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	var ready = _assert_eq(gc.get_state(), 1, "starts READY")

	hp.emit_signal("card_selected", "card_abc")
	var o1 = _assert_eq(gc.get_state(), 2, "CARD_SELECTED (2)")
	var o2 = _assert_eq(gc.get_selected_card_id(), "card_abc", "selected card stored")
	var o3 = _assert_eq(hp.last_selected, "card_abc", "HP.set_selected called")
	_cleanup(d)
	return "  Click selects:              " + ("[PASS]\n" if (ready and o1 and o2 and o3) else "[FAIL]\n")


# 2.2 Click same card twice deselects
func _test_click_same_card_deselects():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_state(), 2, "was CARD_SELECTED")

	hp.emit_signal("card_selected", "card_abc")
	var o1 = _assert_eq(gc.get_state(), 1, "back to READY_FOR_INPUT")
	var o2 = _assert_eq(gc.get_selected_card_id(), "", "deselected")
	_cleanup(d)
	return "  Same card deselects:       " + ("[PASS]\n" if (was_selected and o1 and o2) else "[FAIL]\n")


# 2.3 Click different card changes selection
func _test_click_different_card_changes():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	_assert_eq(gc.get_state(), 2, "was CARD_SELECTED")

	hp.emit_signal("card_selected", "card_xyz")
	var o1 = _assert_eq(gc.get_state(), 2, "still CARD_SELECTED")
	var o2 = _assert_eq(gc.get_selected_card_id(), "card_xyz", "changed to xyz")
	_cleanup(d)
	return "  Different card changes:    " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 2.4 Blocked states ignore click
func _test_blocked_states_ignore():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	# Test each blocked state
	var blocked = [0, 3, 4, 5, 6, 7]  # WAITING, WAITING_CHOICE, ACTION_PENDING, ANIMATING, INPUT_LOCKED, GAME_OVER
	for st in blocked:
		gc._state = st
		gc._selected_card_id = "existing_card"
		hp.emit_signal("card_selected", "new_card")
		var s_ok = _assert_eq(gc.get_state(), st, "state " + str(st) + " unchanged")
		var c_ok = _assert_eq(gc.get_selected_card_id(), "existing_card", "card_id untouched in state " + str(st))
		if not s_ok or not c_ok:
			_cleanup(d)
			return "  Blocked states ignore:     [FAIL]\n"
	_cleanup(d)
	return "  Blocked states ignore:     [PASS]\n"


# 2.5 action_rejected clears selection
func _test_rejection_clears_selection():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_selected_card_id(), "card_abc", "selected before reject")

	mp.auto_emit_action_rejected = true
	mp.rejection_message = "not allowed"
	mp.send_action({"action_type": "bad"})

	var o1 = _assert_eq(gc.get_selected_card_id(), "", "cleared after rejection")
	var o2 = _assert_eq(gc.get_state(), 1, "back to READY")
	_cleanup(d)
	return "  Rejection clears select:   " + ("[PASS]\n" if (was_selected and o1 and o2) else "[FAIL]\n")


# 2.6 New game clears selection
func _test_new_game_clears_selection():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_selected_card_id(), "card_abc", "selected before new game")

	mp.emit_signal("game_started", _make_snapshot(2, null))
	var o1 = _assert_eq(gc.get_selected_card_id(), "", "cleared on new game")
	_cleanup(d)
	return "  New game clears select:    " + ("[PASS]\n" if (was_selected and o1) else "[FAIL]\n")


# 2.7 Snapshot without selected card clears selection (from action_completed)
func _test_snapshot_without_card_clears():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	# Game starts with hand that CONTAINS card_abc
	var snap_with = _make_snapshot(2, null)
	snap_with["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap_with["players"][0]["hand_count"] = 1
	mp.snapshot_to_emit = snap_with
	mp.emit_signal("game_started", snap_with)
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_selected_card_id(), "card_abc", "selected card in hand")

	# action_completed with snapshot that LACKS the card
	var snap_without = _make_snapshot(2, null)
	snap_without["players"][0]["hand"] = [{"card_id":"card_xyz","name":"+3","value":3,"color":"arancione","card_type":"increment"}]
	snap_without["players"][0]["hand_count"] = 1
	mp.result_to_emit = {"snapshot": snap_without, "events": []}
	mp.auto_emit_action_completed = true
	mp.auto_emit_action_rejected = false
	mp.send_action({"action_type": "play_card"})

	var o1 = _assert_eq(gc.get_selected_card_id(), "", "cleared when card not in hand")
	var o2 = _assert_eq(gc.get_state(), 1, "back to READY")
	_cleanup(d)
	return "  Snapshot no card clears:   " + ("[PASS]\n" if (was_selected and o1 and o2) else "[FAIL]\n")


# 2.8 Snapshot WITH selected card preserves selection (from action_completed)
func _test_snapshot_with_card_preserves():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	# Game starts with card_abc in hand, select it
	var snap1 = _make_snapshot(2, null)
	snap1["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap1["players"][0]["hand_count"] = 1
	mp.snapshot_to_emit = snap1
	mp.emit_signal("game_started", snap1)
	hp.emit_signal("card_selected", "card_abc")
	_assert_eq(gc.get_selected_card_id(), "card_abc", "selected")

	# action_completed with same card still in hand
	var snap2 = _make_snapshot(2, null)
	snap2["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap2["players"][0]["hand_count"] = 1
	mp.result_to_emit = {"snapshot": snap2, "events": []}
	mp.auto_emit_action_completed = true
	mp.auto_emit_action_rejected = false
	mp.send_action({"action_type": "play_card"})

	var o1 = _assert_eq(gc.get_selected_card_id(), "card_abc", "selection preserved")
	var o2 = _assert_eq(gc.get_state(), 2, "still CARD_SELECTED")
	_cleanup(d)
	return "  Snapshot has card presrv:  " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 2.9 GAME_OVER clears selection
func _test_game_over_clears_selection():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]

	mp.snapshot_to_emit = _make_snapshot(2, null)
	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_selected_card_id(), "card_abc", "selected before game over")

	# game_started with winner
	mp.snapshot_to_emit = _make_snapshot(2, "player_1")
	mp.emit_signal("game_started", _make_snapshot(2, "player_1"))

	var o1 = _assert_eq(gc.get_selected_card_id(), "", "cleared on GAME_OVER")
	var o2 = _assert_eq(gc.get_state(), 7, "GAME_OVER (7)")
	_cleanup(d)
	return "  GameOver clears select:    " + ("[PASS]\n" if (was_selected and o1 and o2) else "[FAIL]\n")


# ===========================================================================
# Step 3 tests — Button actions
# ===========================================================================

# 3.1 Cancel in CARD_SELECTED deselects
func _test_cancel_deselects():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	hp.emit_signal("card_selected", "card_abc")
	var was_selected = _assert_eq(gc.get_state(), 2, "CARD_SELECTED before cancel")

	tp.emit_signal("cancel_pressed")
	var o1 = _assert_eq(gc.get_state(), 1, "back to READY after cancel")
	var o2 = _assert_eq(gc.get_selected_card_id(), "", "selection cleared after cancel")
	_cleanup(d)
	return "  Cancel deselects:          " + ("[PASS]\n" if (was_selected and o1 and o2) else "[FAIL]\n")


# 3.2 Play with selection sends correct action
func _test_play_sends_action():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap["players"][0]["hand_count"] = 1
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "card_abc")

	tp.emit_signal("play_pressed")

	var o1 = _assert(mp.send_action_called, "send_action called")
	var o2 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "action_type play_card")
	var o3 = _assert_eq(mp.last_send_action_dict.get("card_id"), "card_abc", "card_id forwarded")
	_cleanup(d)
	return "  Play sends action:         " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# 3.3 Change with selection sends correct action
func _test_change_sends_action():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap["players"][0]["hand_count"] = 1
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "card_abc")

	tp.emit_signal("change_pressed")

	var o1 = _assert(mp.send_action_called, "send_action called")
	var o2 = _assert_eq(mp.last_send_action_dict.get("action_type"), "change_card", "action_type change_card")
	var o3 = _assert_eq(mp.last_send_action_dict.get("card_id"), "card_abc", "card_id forwarded")
	_cleanup(d)
	return "  Change sends action:       " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# 3.4 Play without selection shows tip, no action
func _test_play_no_selection_shows_tip():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	var was_ready = _assert_eq(gc.get_state(), 1, "READY before play")

	tp.emit_signal("play_pressed")

	var o1 = _assert(!mp.send_action_called, "send_action NOT called")
	var o2 = _assert(tp.last_tip != "", "show_tip was called: '" + tp.last_tip + "'")
	var o3 = _assert_eq(gc.get_state(), 1, "still READY")
	_cleanup(d)
	return "  Play no select shows tip:  " + ("[PASS]\n" if (was_ready and o1 and o2 and o3) else "[FAIL]\n")


# 3.5 Change without selection shows tip, no action
func _test_change_no_selection_shows_tip():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	_assert_eq(gc.get_state(), 1, "READY before change")

	tp.emit_signal("change_pressed")

	var o1 = _assert(!mp.send_action_called, "send_action NOT called")
	var o2 = _assert(tp.last_tip != "", "show_tip was called: '" + tp.last_tip + "'")
	var o3 = _assert_eq(gc.get_state(), 1, "still READY")
	_cleanup(d)
	return "  Change no select shows tip:" + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# 3.6 Buttons ignored in non-READY/non-CARD_SELECTED states
func _test_buttons_ignored_in_wrong_state():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	mp.emit_signal("game_started", _make_snapshot(2, null))
	_assert_eq(gc.get_state(), 1, "READY")

	# Put GC in GAME_OVER — all buttons should be ignored
	gc._state = 7  # GAME_OVER
	gc._selected_card_id = "card_abc"

	tp.emit_signal("play_pressed")
	var o1 = _assert(!mp.send_action_called, "play ignored in GAME_OVER")
	var o2 = _assert_eq(gc.get_state(), 7, "state still GAME_OVER")

	tp.emit_signal("change_pressed")
	var o3 = _assert(!mp.send_action_called, "change ignored in GAME_OVER")
	var o4 = _assert_eq(gc.get_selected_card_id(), "card_abc", "selection untouched in GAME_OVER")

	tp.emit_signal("cancel_pressed")
	var o5 = _assert_eq(gc.get_selected_card_id(), "card_abc", "cancel ignored in GAME_OVER")
	var o6 = _assert_eq(gc.get_state(), 7, "state still GAME_OVER after cancel")

	_cleanup(d)
	return "  Buttons ignored wrong st:  " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6) else "[FAIL]\n")


# 3.7 ACTION_PENDING transition when auto-emit is off
func _test_action_pending_transition():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["players"][0]["hand"] = [{"card_id":"card_abc","name":"+5","value":5,"color":"arancione","card_type":"increment"}]
	snap["players"][0]["hand_count"] = 1
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "card_abc")
	_assert_eq(gc.get_state(), 2, "CARD_SELECTED")

	# Disable auto-emit so we can observe ACTION_PENDING
	mp.auto_emit_action_completed = false
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4)")
	var o2 = _assert(mp.send_action_called, "send_action called")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "action correct")

	# Now complete the action
	mp.auto_emit_action_completed = true
	mp.result_to_emit = {"snapshot": snap, "events": []}
	mp.send_action({"action_type": "play_card", "card_id": "card_abc"})

	var o4 = _assert(!gc.get_state() == 4, "no longer ACTION_PENDING after completion")
	_cleanup(d)
	return "  ACTION_PENDING transition: " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# ===========================================================================
# Step 4 tests — Popups and special choices
# ===========================================================================

# Helper: snapshot with a specific hand
func _make_hand_snapshot(hand_cards):
	var snap = _make_snapshot(2, null)
	snap["players"][0]["hand"] = hand_cards
	snap["players"][0]["hand_count"] = hand_cards.size()
	# F8: mirror the provider — available_actions reflects what the rules
	# layer would offer for this hand (Jolly/Imbroglio with filtered choices).
	var acts = []
	var pv = int(snap.get("piatto", 0))
	for c in hand_cards:
		var ct = str(c.get("card_type", ""))
		if ct == "jolly":
			var act = {"action_type": "play_card", "card_id": c["card_id"], "choices": []}
			for v in range(1, 11):
				act["choices"].append({"label": str(v), "parameters": {"selected_value": v}})
			acts.append(act)
		elif ct == "imbroglio":
			var act = {"action_type": "play_card", "card_id": c["card_id"], "choices": []}
			for v in range(-15, 16):
				if v == 0:
					continue
				if 0 <= pv + v and pv + v <= 99:
					act["choices"].append({"label": str(v), "parameters": {"selected_value": v}})
			acts.append(act)
		else:
			acts.append({"action_type": "play_card", "card_id": c["card_id"]})
		acts.append({"action_type": "change_card", "card_id": c["card_id"]})
	snap["available_actions"] = acts
	return snap

# 4.1 Jolly card + play_pressed -> WAITING_FOR_CHOICE
func _test_jolly_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
		{"card_id":"inc1","name":"+1","value":1,"color":"arancione","card_type":"increment"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	_assert_eq(gc.get_state(), 2, "CARD_SELECTED")

	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var o2 = _assert(!mp.send_action_called, "action NOT sent yet")
	_cleanup(d)
	return "  Jolly opens popup:         " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.2 Imbroglio card + play_pressed -> WAITING_FOR_CHOICE
func _test_imbroglio_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	_assert_eq(gc.get_state(), 2, "CARD_SELECTED")

	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var o2 = _assert(!mp.send_action_called, "action NOT sent yet")
	_cleanup(d)
	return "  Imbroglio opens popup:     " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.3 Value choice sends action with selected_value
func _test_value_choice_sends_action():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	# Simulate value chosen, disable auto-emit so we can check the pending state
	mp.auto_emit_action_completed = false
	gc._on_value_chosen(7)

	var o1 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4)")
	var o2 = _assert(mp.send_action_called, "send_action called")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "action_type play_card")
	var o4 = _assert_eq(mp.last_send_action_dict.get("card_id"), "jolly_0", "card_id forwarded")
	var o5 = _assert_eq(mp.last_send_action_dict.get("selected_value"), 7, "selected_value=7")
	_cleanup(d)
	return "  Value choice sends action: " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5) else "[FAIL]\n")


# 4.4 Value choice cancel returns to CARD_SELECTED
func _test_value_choice_cancel():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE before cancel")

	mp.auto_emit_action_completed = false
	gc._on_value_cancel()

	var o1 = _assert_eq(gc.get_state(), 2, "CARD_SELECTED (2) after cancel")
	var o2 = _assert(!mp.send_action_called, "action NOT sent after cancel")
	_cleanup(d)
	return "  Value choice cancel:       " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.8 Invalid Jolly value 0 — stays WAITING_FOR_CHOICE
func _test_jolly_value_zero_invalid():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	mp.auto_emit_action_completed = false
	gc._on_value_chosen(0)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	var o2 = _assert(!mp.send_action_called, "action NOT sent")
	_cleanup(d)
	return "  Inv Jolly value 0:         " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.9 Invalid Jolly value 11 — stays WAITING_FOR_CHOICE
func _test_jolly_value_eleven_invalid():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_value_chosen(11)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	var o2 = _assert(!mp.send_action_called, "action NOT sent")
	_cleanup(d)
	return "  Inv Jolly value 11:        " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.10 Invalid Imbroglio value 0 — stays WAITING_FOR_CHOICE
func _test_imbroglio_value_zero_invalid():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_value_chosen(0)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	var o2 = _assert(!mp.send_action_called, "action NOT sent")
	_cleanup(d)
	return "  Inv Imbroglio value 0:     " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.11 Invalid Imbroglio value -16 — stays WAITING_FOR_CHOICE
func _test_imbroglio_value_minus16_invalid():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_value_chosen(-16)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	var o2 = _assert(!mp.send_action_called, "action NOT sent")
	_cleanup(d)
	return "  Inv Imbroglio value -16:   " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 4.12 Invalid Imbroglio value 16 — stays WAITING_FOR_CHOICE
func _test_imbroglio_value_16_invalid():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_value_chosen(16)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	var o2 = _assert(!mp.send_action_called, "action NOT sent")
	_cleanup(d)
	return "  Inv Imbroglio value 16:    " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


func _test_f7_gold_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "g12")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var o2 = _assert(!mp.send_action_called, "action NOT sent before blocked_type choice")
	_cleanup(d)
	return "  F7 gold opens popup:     " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# F7.2 Choosing blocked_type sends ONE play_card with card_id + blocked_type
func _test_f7_choice_sends_single_action():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "g12")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	mp.auto_emit_action_completed = false
	gc._on_safe_round_choice_chosen("Gold")

	var o1 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4)")
	var o2 = _assert(mp.send_action_called, "send_action called once")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "single play_card action")
	var o4 = _assert_eq(mp.last_send_action_dict.get("card_id"), "g12", "activating card_id forwarded")
	var o5 = _assert_eq(str(mp.last_send_action_dict.get("blocked_type", "")), "Gold", "blocked_type on the same action")
	_cleanup(d)
	return "  F7 single play_card:     " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5) else "[FAIL]\n")


# F7.3 +11 immediately after a Gold (chain to 78) opens the popup
func _test_f7_plus11_after_gold_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"p11","name":"+11","value":11,"color":"rosso","card_type":"special"},
	])
	snap["plateau_cards"] = [
		{"card_id":"g67","name":"67","value":67,"color":"dorato","card_type":"gold"},
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "p11")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var o2 = _assert(!mp.send_action_called, "chain to 78 activates GS: choice required first")
	_cleanup(d)
	return "  F7 +11 chain opens popup:" + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# F7.4 +11 without a preceding Gold plays directly (no popup, no blocked_type)
func _test_f7_plus11_no_gold_plays_directly():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"p11","name":"+11","value":11,"color":"rosso","card_type":"special"},
	])
	snap["plateau_cards"] = [
		{"card_id":"inc3","name":"+3","value":3,"color":"arancione","card_type":"increment"},
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "p11")
	tp.emit_signal("play_pressed")

	var o1 = _assert(mp.send_action_called, "no popup: action sent directly")
	var o2 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "play_card action")
	var o3 = _assert_eq(mp.last_send_action_dict.get("card_id"), "p11", "card_id forwarded")
	var o4 = _assert(!mp.last_send_action_dict.has("blocked_type"), "no blocked_type without GS activation")
	_cleanup(d)
	return "  F7 +11 no chain direct:  " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# F7.5 +11 chaining to 89 activates the Advantage Round — no GS popup
func _test_f7_plus11_chain_89_no_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"p11","name":"+11","value":11,"color":"rosso","card_type":"special"},
	])
	snap["plateau_cards"] = [
		{"card_id":"g78","name":"78","value":78,"color":"dorato","card_type":"gold"},
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "p11")
	tp.emit_signal("play_pressed")

	var o1 = _assert(mp.send_action_called, "chain to 89 is GdV: no GS popup, direct play")
	var o2 = _assert_eq(mp.last_send_action_dict.get("card_id"), "p11", "card_id forwarded")
	_cleanup(d)
	return "  F7 +11 chain 89 no pop:  " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# F7.6 Cancel in the Safe Round popup returns to CARD_SELECTED, no action sent
func _test_f7_choice_cancel():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "g12")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE before cancel")

	mp.auto_emit_action_completed = false
	gc._on_value_cancel()

	var o1 = _assert_eq(gc.get_state(), 2, "CARD_SELECTED (2) after cancel")
	var o2 = _assert(!mp.send_action_called, "action NOT sent after cancel")
	var o3 = _assert_eq(gc.get_selected_card_id(), "g12", "selection preserved after cancel")
	_cleanup(d)
	return "  F7 GS choice cancel:     " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# ===========================================================================
# Step F8 tests — final regression (Special Round closeout)
# ===========================================================================

# F8.1 Imbroglio popup offers only the rule-filtered values from the snapshot
func _test_f8_imbroglio_filtered_choices():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["piatto"] = 95
	snap["players"][0]["hand"] = [
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	]
	snap["players"][0]["hand_count"] = 1
	var choices = []
	for v in range(-15, 16):
		if v == 0: continue
		if 0 <= 95 + v and 95 + v <= 99:
			choices.append({"label": str(v), "parameters": {"selected_value": v}})
	snap["available_actions"] = [
		{"action_type":"play_card","card_id":"imb0","choices":choices},
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var pending = gc._pending_valid_values
	var o2 = _assert_eq(pending.size(), 19, "19 filtered values at Piatto 95")
	var o3 = _assert(not (15 in pending), "+15 not offered at Piatto 95 (95+15>99)")
	var o4 = _assert(-15 in pending and 4 in pending and 1 in pending, "negatives + 1..4 offered")
	_cleanup(d)
	return "  F8 imbroglio filtered:   " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# F8.2 A value not in the offered choices cannot be sent — stays WAITING_FOR_CHOICE
func _test_f8_imbroglio_disallowed_value_blocked():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["piatto"] = 95
	snap["players"][0]["hand"] = [
		{"card_id":"imb0","name":"Imbroglio","value":null,"color":"verde","card_type":"imbroglio"},
	]
	snap["players"][0]["hand_count"] = 1
	var choices = []
	for v in range(-15, 16):
		if v == 0: continue
		if 0 <= 95 + v and 95 + v <= 99:
			choices.append({"label": str(v), "parameters": {"selected_value": v}})
	snap["available_actions"] = [
		{"action_type":"play_card","card_id":"imb0","choices":choices},
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "imb0")
	tp.emit_signal("play_pressed")
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE before")

	mp.auto_emit_action_completed = false
	gc._on_value_chosen(15)  # not offered: 95+15 > 99 — must be blocked

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE (3)")
	var o2 = _assert(!mp.send_action_called, "no action sent for disallowed value")
	_cleanup(d)
	return "  F8 disallowed blocked:   " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# F8.3 Jolly popup uses the snapshot's choices (1..10 from the rules layer)
func _test_f8_jolly_choices_from_snapshot():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3)")
	var pending = gc._pending_valid_values
	var o2 = _assert_eq(pending.size(), 10, "10 jolly values from snapshot")
	var o3 = _assert(1 in pending and 10 in pending, "range 1..10 present")
	_cleanup(d)
	return "  F8 jolly from snapshot:  " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# ===========================================================================
# Step 5 tests — CardAnimator integration
# ===========================================================================

# Helper: add mock animator to setup
func _setup_gc_with_anim():
	var d = _setup_gc_with_hand()
	var ma = load("res://tests/mock_animator.gd").new()
	d["gc"].add_child(ma)
	d["gc"]._card_animator = ma
	ma.connect("animation_finished", d["gc"], "_on_animation_finished")
	d["ma"] = ma
	return d


func _cleanup_anim(d):
	_cleanup(d)  # gc.free() frees all children including mock animator


# 5.1 action_completed with events -> ANIMATING
func _test_animating_state():
	var d = _setup_gc_with_anim()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var ma = d["ma"]

	var snap = _make_hand_snapshot([{"card_id":"c1","name":"+5","value":5,"color":"arancione","card_type":"increment"}])
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 1, "READY")

	# Send action with auto-emit ON — chain stops at mock (no auto-finish)
	mp.auto_emit_action_completed = true
	mp.auto_emit_game_started = false
	mp.result_to_emit = {"snapshot": snap, "events": [
		{"type": "card_played", "card_id": "c1", "destination": "discard"},
	]}
	mp.send_action({"action_type": "play_card", "card_id": "c1"})

	var o1 = _assert_eq(gc.get_state(), 5, "ANIMATING (5) while events play")
	var o2 = _assert(ma.animating, "mock animator is busy")
	_cleanup_anim(d)
	return "  action_completed -> ANIM:  " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 5.2 After finish_animation -> READY_FOR_INPUT (no yield)
func _test_anim_finishes_ready():
	var d = _setup_gc_with_anim()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var ma = d["ma"]

	var snap = _make_hand_snapshot([{"card_id":"c1","name":"+5","value":5,"color":"arancione","card_type":"increment"}])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "c1")

	mp.auto_emit_action_completed = true
	mp.auto_emit_game_started = false
	mp.result_to_emit = {"snapshot": snap, "events": [{"type": "card_played", "card_id": "c1"}]}
	mp.send_action({"action_type": "play_card", "card_id": "c1"})
	_assert_eq(gc.get_state(), 5, "ANIMATING before finish")

	# Manually trigger animation finished
	ma.finish_animation()

	var o1 = _assert_eq(gc.get_state(), 2, "CARD_SELECTED after anim (card still in snap)")
	var o2 = _assert(!ma.animating, "mock animator done")
	_cleanup_anim(d)
	return "  anim_finished -> READY:    " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# 5.3 Input ignored during ANIMATING
func _test_input_ignored_during_anim():
	var d = _setup_gc_with_anim()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]; var ma = d["ma"]

	var snap = _make_hand_snapshot([{"card_id":"c1","name":"+5","value":5,"color":"arancione","card_type":"increment"}])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "c1")
	_assert_eq(gc.get_state(), 2, "CARD_SELECTED")

	# Force ANIMATING
	gc._state = 5
	gc._selected_card_id = "c1"

	# Try card click, play, change, cancel — all should be ignored
	hp.emit_signal("card_selected", "c2")
	var o1 = _assert_eq(gc.get_selected_card_id(), "c1", "card_selected ignored during ANIMATING")

	tp.emit_signal("play_pressed")
	var o2 = _assert(gc.get_state() == 5, "play_pressed ignored")

	tp.emit_signal("cancel_pressed")
	var o3 = _assert_eq(gc.get_selected_card_id(), "c1", "cancel ignored during ANIMATING")

	tp.emit_signal("change_pressed")
	var o4 = _assert(!mp.send_action_called, "change ignored during ANIMATING")

	_cleanup_anim(d)
	return "  Input ignored ANIMATING:   " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# ===========================================================================
# Step 7 — End-to-end GUI input flow (real HandPresenter + CardFace)
# ===========================================================================

func _test_real_click_to_action():
	# Setup: GC + mock provider + mock turn/board + REAL HandPresenter
	var gc = GameController.new()
	var mp = MockProvider.new()
	mp.auto_emit_game_started = false
	gc.set_provider(mp)
	add_child(gc)

	# Real HandPresenter with a synthetic cards layer
	var HandPresenter = load("res://scripts/HandPresenter.gd")
	var hp = HandPresenter.new()
	var layer = Control.new()
	layer.rect_size = Vector2(800, 300)
	hp._cards_layer = layer
	gc._hand = hp
	hp.connect("card_selected", gc, "_on_card_selected")

	# Mock TurnPresenter for button signals
	var tp = MockPresenter.new()
	gc._turn = tp
	tp.connect("play_pressed", gc, "_on_play_pressed")

	# Minimal snapshot with one card in hand
	var snap = _make_hand_snapshot([
		{"card_id":"c1","name":"+5","value":5,"color":"arancione","card_type":"increment"},
	])
	mp.emit_signal("game_started", snap)
	var was_ready = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT after start")

	# Step 1: Simulate CardFace click via _gui_input
	var cf = null
	var card_faces = hp._card_faces
	if card_faces.size() > 0:
		cf = card_faces[0]
		var event = InputEventMouseButton.new()
		event.button_index = 1
		event.pressed = true
		cf._gui_input(event)

	var o1 = _assert(cf != null, "CardFace created in hand")
	var o2 = _assert_eq(gc.get_state(), 2, "CARD_SELECTED after CardFace click")
	var o3 = _assert_eq(gc.get_selected_card_id(), "c1", "selected card_id = c1")

	# Step 2: Simulate PlayButton press
	tp.emit_signal("play_pressed")

	var o4 = _assert(mp.send_action_called, "send_action called via perform_action")
	var o5 = _assert_eq(mp.last_send_action_dict.get("action_type"), "play_card", "action_type = play_card")
	var o6 = _assert_eq(mp.last_send_action_dict.get("card_id"), "c1", "card_id = c1")

	# Cleanup
	remove_child(gc)
	gc.free()
	mp.free()
	hp.free()
	tp.free()
	layer.free()  # frees CardFace children too

	return "  Real click-to-action:      " + ("[PASS]\n" if (was_ready and o1 and o2 and o3 and o4 and o5 and o6) else "[FAIL]\n")


# ===========================================================================
# Step 9 — Fix verification tests
# ===========================================================================

# Fix 1: Jolly with no choices in snapshot still opens popup (fallback)
func _test_fix1_jolly_fallback_when_no_choices():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	# Jolly card in hand, but NO choices in available_actions (edge case)
	var snap = _make_snapshot(2, null)
	snap["players"][0]["hand"] = [
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	]
	snap["players"][0]["hand_count"] = 1
	# No choices provided — should trigger fallback
	snap["available_actions"] = [
		{"action_type": "play_card", "card_id": "jolly_0"},  # no "choices" key
	]
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3) — fallback popup opened")
	var o2 = _assert(!mp.send_action_called, "action NOT sent yet")
	_cleanup(d)
	return "  Fix1 jolly fallback:     " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


func _test_fix4_reset_hand_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	# GdV scenario: non-advantage player has no playable Orange cards
	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_2"
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3) — reset hand popup opened")
	_cleanup(d)
	return "  Fix4 reset popup open:   " + ("[PASS]\n" if o1 else "[FAIL]\n")


# Fix 4b: Reset hand Yes sends reset_hand action
func _test_fix4_reset_hand_yes_sends_action():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_2"
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	mp.auto_emit_action_completed = false
	gc._on_hand_reset_yes()

	var o1 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4)")
	var o2 = _assert(mp.send_action_called, "send_action called")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "reset_hand", "action_type = reset_hand")
	_cleanup(d)
	return "  Fix4 reset Yes sends:    " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# Fix 4c: Reset hand No returns to READY_FOR_INPUT, change_card still available
func _test_fix4_reset_hand_no_returns_ready():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_2"
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_hand_reset_no()

	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1) after No")
	var o2 = _assert(!mp.send_action_called, "action NOT sent after No")
	_cleanup(d)
	return "  Fix4 reset No dismiss:   " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# Fix 6: Victory animation is not skipped — GAME_OVER set after animation
func _test_fix6_victory_animation_not_skipped():
	var d = _setup_gc_with_anim()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var ma = d["ma"]

	mp.emit_signal("game_started", _make_snapshot(2, null))

	# Simulate action_completed with winner and events (should animate)
	var snap_with_winner = _make_snapshot(2, "player_1")
	snap_with_winner["players"][0]["hand"] = [
		{"card_id":"p11","name":"+11","value":11,"color":"rosso","card_type":"special"},
	]
	var events = [
		{"type": "card_played", "player_id": "player_1", "card_id": "p11", "destination": "scarti"},
		{"type": "game_won", "player_id": "player_1"},
	]
	mp.result_to_emit = {"snapshot": snap_with_winner, "events": events}
	mp.auto_emit_action_completed = true
	mp.send_action({"action_type": "play_card", "card_id": "p11"})

	# Should be ANIMATING, not immediately GAME_OVER
	var o1 = _assert_eq(gc.get_state(), 5, "ANIMATING (5) — victory card animates")

	# Simulate animation finished → should become GAME_OVER
	ma.finish_animation()
	var o2 = _assert_eq(gc.get_state(), 7, "GAME_OVER (7) after animation")
	_cleanup_anim(d)
	return "  Fix6 victory anim:       " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# --- HandResetPopup scope tests ---

# No HandResetPopup during Safe Round (GS), even without playable cards
func _test_handr_reset_no_popup_during_gs():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "safe"  # Safe Round, not GdV
	snap["special_round_player_id"] = "player_2"
	snap["blocked_type"] = "Incremento"
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)

	# Should NOT be WAITING_FOR_CHOICE (3), should be READY_FOR_INPUT (1)
	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1) — no popup during GS")
	_cleanup(d)
	return "  HR no popup in GS:       " + ("[PASS]\n" if o1 else "[FAIL]\n")


# During GS without playable cards, Cambio Carta remains available (no popup blocks it)
func _test_handr_reset_gs_change_card_available():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "safe"
	snap["special_round_player_id"] = "player_2"
	snap["blocked_type"] = "Incremento"
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)

	# State should be READY_FOR_INPUT — player can freely use Cambio Carta
	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1)")
	# Select a card and press change — should work without popup interference
	hp.emit_signal("card_selected", "g12")
	tp.emit_signal("change_pressed")
	var o2 = _assert(mp.send_action_called, "change_card sent without popup interference")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "change_card", "action_type = change_card")
	_cleanup(d)
	return "  HR GS change available:  " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


# No HandResetPopup when it's not the local player's turn
func _test_handr_reset_no_popup_not_local_turn():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_1"
	snap["current_player_index"] = 1  # player_2's turn, not local (player_1)
	snap["players"][1]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][1]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)

	# Should NOT open popup since it's not the local player's turn
	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1) — no popup on other's turn")
	_cleanup(d)
	return "  HR no popup non-local:   " + ("[PASS]\n" if o1 else "[FAIL]\n")


# No HandResetPopup for the advantage player themselves
func _test_handr_reset_no_popup_for_advantage_player():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]

	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_1"  # local player IS advantage player
	snap["current_player_index"] = 0  # player_1's turn
	snap["players"][0]["hand"] = [
		{"card_id":"g12","name":"12","value":12,"color":"dorato","card_type":"gold"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "reset_hand"},
		{"action_type": "change_card", "card_id": "g12"},
	]
	mp.emit_signal("game_started", snap)

	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1) — no popup for advantage player")
	_cleanup(d)
	return "  HR no popup adv player:  " + ("[PASS]\n" if o1 else "[FAIL]\n")


# Jolly/Imbroglio popup works correctly even when HandReset conditions are present
func _test_handr_reset_no_interference_jolly():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	# GdV active but player has a Jolly (playable) — no reset scenario
	var snap = _make_snapshot(2, null)
	snap["special_round_active"] = true
	snap["special_round_type"] = "advantage"
	snap["special_round_player_id"] = "player_2"
	snap["players"][0]["hand"] = [
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	]
	snap["players"][0]["hand_count"] = 1
	snap["available_actions"] = [
		{"action_type": "play_card", "card_id": "jolly_0", "choices": [{"parameters": {"selected_value": 5}}]},
		{"action_type": "change_card", "card_id": "jolly_0"},
	]
	mp.emit_signal("game_started", snap)

	# Select Jolly and press play — should open value popup, not HandResetPopup
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3) — Jolly popup opened")
	# Verify it's the value choice popup (has valid values set)
	var o2 = _assert(gc._pending_valid_values.size() > 0, "valid values populated for Jolly")
	_cleanup(d)
	return "  HR no jolly interferenc: " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# ===========================================================================
# Popup modality tests — the InputBlocker overlay must keep any choice popup
# in front, absorb outside clicks, and only close on a valid choice.
# ===========================================================================

# Build real popup/blocker nodes wired onto a GC so the visual modality logic
# (not just the state machine) is exercised.
func _setup_gc_with_popup_nodes():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]

	var vp = PopupPanel.new(); vp.name = "VPC"; add_child(vp)
	var hr = PopupPanel.new(); hr.name = "HRC"; add_child(hr)
	var ib = ColorRect.new(); ib.name = "IBC"
	ib.anchor_right = 1.0; ib.anchor_bottom = 1.0
	ib.mouse_filter = 0; ib.visible = false; add_child(ib)

	gc._value_choice_popup = vp
	gc._hand_reset_popup = hr
	gc._choice_input_blocker = ib

	d["vp"] = vp; d["hr"] = hr; d["ib"] = ib
	return d


func _test_popup_blocker_reflects_open_state():
	var d = _setup_gc_with_popup_nodes()
	var gc = d["gc"]; var vp = d["vp"]; var hr = d["hr"]; var ib = d["ib"]

	vp.visible = false; hr.visible = false
	gc._update_choice_blocker()
	var o1 = _assert(ib.visible == false, "blocker hidden when no popup open")

	vp.visible = true
	gc._update_choice_blocker()
	var o2 = _assert(ib.visible == true, "blocker shown while value popup open")

	vp.visible = false; hr.visible = true
	gc._update_choice_blocker()
	var o3 = _assert(ib.visible == true, "blocker shown while hand-reset popup open")

	hr.visible = false
	gc._update_choice_blocker()
	var o4 = _assert(ib.visible == false, "blocker hidden when all popups closed")

	ib.queue_free(); vp.queue_free(); hr.queue_free()
	_cleanup(d)
	return "  Popup blocker open state: " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# A valid choice must hide the popup, hide the blocker, and complete the action.
func _test_popup_valid_choice_closes_and_completes():
	var d = _setup_gc_with_popup_nodes()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]
	var vp = d["vp"]; var ib = d["ib"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")  # opens the value-choice popup

	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE before choice")
	var o2 = _assert(vp.visible == true, "value popup is visible when open")
	var o3 = _assert(ib.visible == true, "input blocker up while popup open")

	mp.auto_emit_action_completed = false
	gc._on_value_chosen(7)  # valid choice

	var o4 = _assert(vp.visible == false, "valid choice hides the popup")
	var o5 = _assert(ib.visible == false, "valid choice removes the input blocker")
	var o6 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4) after valid choice")
	var o7 = _assert(mp.send_action_called, "send_action called on valid choice")
	var o8 = _assert_eq(mp.last_send_action_dict.get("selected_value"), 7, "selected_value=7 forwarded")

	ib.queue_free(); vp.queue_free()
	if d.has("hr"): d["hr"].queue_free()
	_cleanup(d)
	return "  Popup valid choice closes: " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6 and o7 and o8) else "[FAIL]\n")


# Clicking OUTSIDE an open popup must not close it, advance the game, or drop
# the GC out of WAITING_FOR_CHOICE (the blocker absorbs the click).
func _test_popup_outside_click_does_not_close():
	var d = _setup_gc_with_popup_nodes()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]
	var vp = d["vp"]; var ib = d["ib"]

	var snap = _make_hand_snapshot([
		{"card_id":"jolly_0","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"},
	])
	mp.emit_signal("game_started", snap)
	hp.emit_signal("card_selected", "jolly_0")
	tp.emit_signal("play_pressed")  # opens the value-choice popup
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE before outside click")

	# Simulate a mouse click far outside the popup (top-left corner) by
	# injecting raw input events. The visible InputBlocker (mouse_filter=STOP)
	# must absorb it — nothing may close the popup or advance the game.
	var down = InputEventMouseButton.new()
	down.button_index = BUTTON_LEFT
	down.position = Vector2(5, 5)
	down.pressed = true
	Input.parse_input_event(down)
	var up = InputEventMouseButton.new()
	up.button_index = BUTTON_LEFT
	up.position = Vector2(5, 5)
	up.pressed = false
	Input.parse_input_event(up)

	var o1 = _assert(vp.visible == true, "popup still open after outside click")
	var o2 = _assert(ib.visible == true, "blocker still up after outside click")
	var o3 = _assert_eq(gc.get_state(), 3, "state unchanged (3) after outside click")
	var o4 = _assert(!mp.send_action_called, "no action sent from an outside click")

	ib.queue_free(); vp.queue_free()
	if d.has("hr"): d["hr"].queue_free()
	_cleanup(d)
	return "  Popup outside click inert: " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# Structural check on Main.tscn: the InputBlocker must cover the full screen
# with mouse_filter=STOP so it physically blocks clicks behind an open popup.
func _test_scene_input_blocker_config():
	var scene = load("res://Main.tscn")
	if scene == null:
		return "  Scene input blocker:      [FAIL]\n"
	var inst = scene.instance()
	var ol = inst.get_node_or_null("OverlayLayer")
	var ib = ol.get_node_or_null("InputBlocker") if ol != null else null

	var o1 = _assert(ib != null, "InputBlocker node exists in Main.tscn")
	var o2 = false
	var o3 = false
	if ib != null:
		# MOUSE_FILTER_STOP == 0
		o2 = _assert(ib.mouse_filter == 0, "InputBlocker mouse_filter is STOP (0)")
		o3 = _assert(
			abs(ib.anchor_right - 1.0) < 0.001 and abs(ib.anchor_bottom - 1.0) < 0.001,
			"InputBlocker spans the full overlay")
	inst.free()
	return "  Scene input blocker:      " + ("[PASS]\n" if (o1 and o2 and o3) else "[FAIL]\n")


func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — GameController (Steps 1+2)\n"
	out += "========================================\n"
	out += "--- Step 1: base state machine ---\n"
	out += _test_initial_state()
	out += _test_start_game_forwards()
	out += _test_game_started_updates_presenters()
	out += _test_game_started_transition_ready()
	out += _test_winner_transition_game_over()
	out += _test_action_rejected_resets()
	out += _test_null_snapshot_safe()
	out += "--- Step 2: card selection ---\n"
	out += _test_click_ready_selects()
	out += _test_click_same_card_deselects()
	out += _test_click_different_card_changes()
	out += _test_blocked_states_ignore()
	out += _test_rejection_clears_selection()
	out += _test_new_game_clears_selection()
	out += _test_snapshot_without_card_clears()
	out += _test_snapshot_with_card_preserves()
	out += _test_game_over_clears_selection()
	out += "--- Step 3: button actions ---\n"
	out += _test_cancel_deselects()
	out += _test_play_sends_action()
	out += _test_change_sends_action()
	out += _test_play_no_selection_shows_tip()
	out += _test_change_no_selection_shows_tip()
	out += _test_buttons_ignored_in_wrong_state()
	out += _test_action_pending_transition()
	out += "--- Step 4: popup choices ---\n"
	out += _test_jolly_opens_popup()
	out += _test_imbroglio_opens_popup()
	out += _test_value_choice_sends_action()
	out += _test_value_choice_cancel()
	out += _test_jolly_value_zero_invalid()
	out += _test_jolly_value_eleven_invalid()
	out += _test_imbroglio_value_zero_invalid()
	out += _test_imbroglio_value_minus16_invalid()
	out += _test_imbroglio_value_16_invalid()
	out += "--- Step F7: Safe Round pre-action choice ---\n"
	out += _test_f7_gold_opens_popup()
	out += _test_f7_choice_sends_single_action()
	out += _test_f7_plus11_after_gold_opens_popup()
	out += _test_f7_plus11_no_gold_plays_directly()
	out += _test_f7_plus11_chain_89_no_popup()
	out += _test_f7_choice_cancel()
	out += "--- Step F8: final regression (Special Round closeout) ---\n"
	out += _test_f8_imbroglio_filtered_choices()
	out += _test_f8_imbroglio_disallowed_value_blocked()
	out += _test_f8_jolly_choices_from_snapshot()
	out += "--- Step 9: Fix verification tests ---\n"
	out += _test_fix1_jolly_fallback_when_no_choices()
	out += _test_fix4_reset_hand_opens_popup()
	out += _test_fix4_reset_hand_yes_sends_action()
	out += _test_fix4_reset_hand_no_returns_ready()
	out += _test_fix6_victory_animation_not_skipped()
	out += "--- HandResetPopup scope tests ---\n"
	out += _test_handr_reset_no_popup_during_gs()
	out += _test_handr_reset_gs_change_card_available()
	out += _test_handr_reset_no_popup_not_local_turn()
	out += _test_handr_reset_no_popup_for_advantage_player()
	out += _test_handr_reset_no_interference_jolly()
	out += "--- Step 5: card animator ---\n"
	out += _test_animating_state()
	out += _test_anim_finishes_ready()
	out += _test_input_ignored_during_anim()
	out += "--- Step 7: GUI input flow ---\n"
	out += _test_real_click_to_action()
	out += "--- Popup modality (InputBlocker) ---\n"
	out += _test_popup_blocker_reflects_open_state()
	out += _test_popup_valid_choice_closes_and_completes()
	out += _test_popup_outside_click_does_not_close()
	out += _test_scene_input_blocker_config()

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFailures:\n"
		for m in failure_msgs:
			out += "  - " + str(m) + "\n"
	out += "\n========================================\n"
	return out
