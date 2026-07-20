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
		"advantage_turn": false,
		"advantage_player_id": null,
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


# 4.5 Gold Reveal available -> WAITING_FOR_CHOICE
func _test_gold_reveal_opens_popup():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g23"},
		{"action_type": "play_card", "card_id": "g23"},
	]
	mp.emit_signal("game_started", snap)

	# GC should detect reveal_gold and go to WAITING_FOR_CHOICE
	var o1 = _assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE (3) due to gold reveal")
	_cleanup(d)
	return "  Gold reveal opens popup:   " + ("[PASS]\n" if o1 else "[FAIL]\n")


# 4.6 Gold Reveal Yes -> sends action, no selection needed
func _test_gold_reveal_yes():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g23"},
		{"action_type": "play_card", "card_id": "g23"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	mp.auto_emit_action_completed = false
	gc._on_gold_reveal_yes()

	var o1 = _assert_eq(gc.get_state(), 4, "ACTION_PENDING (4)")
	var o2 = _assert(mp.send_action_called, "send_action called")
	var o3 = _assert_eq(mp.last_send_action_dict.get("action_type"), "reveal_gold", "action_type reveal_gold")
	var o4 = _assert_eq(mp.last_send_action_dict.get("card_id"), "g23", "card_id g23")
	_cleanup(d)
	return "  Gold reveal Yes sends:     " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL]\n")


# 4.7 Gold Reveal No -> back to READY_FOR_INPUT
func _test_gold_reveal_no():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g23"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	gc._on_gold_reveal_no()

	var o1 = _assert_eq(gc.get_state(), 1, "READY_FOR_INPUT (1) after No")
	var o2 = _assert(!mp.send_action_called, "action NOT sent after No")
	_cleanup(d)
	return "  Gold reveal No dismiss:    " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


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


# 4.13 Gold reveal not reopened if already in WAITING_FOR_CHOICE
func _test_gold_reveal_not_reopen():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g23"},
		{"action_type": "play_card", "card_id": "g23"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	# Second game_started with same snapshot — should NOT reopen or change pending
	mp.snapshot_to_emit = snap
	mp.emit_signal("game_started", snap)

	var o1 = _assert_eq(gc.get_state(), 3, "still WAITING_FOR_CHOICE")
	_cleanup(d)
	return "  Gold no reopen:            " + ("[PASS]\n" if o1 else "[FAIL]\n")


# 4.14 Gold reveal not opened in GAME_OVER
func _test_gold_reveal_not_in_gameover():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g23"},
	]
	snap["winner"] = "player_1"
	snap["phase"] = "game_over"
	mp.emit_signal("game_started", snap)

	var o1 = _assert_eq(gc.get_state(), 7, "GAME_OVER (7) — gold reveal blocked")
	_cleanup(d)
	return "  Gold not in gameover:      " + ("[PASS]\n" if o1 else "[FAIL]\n")


# 4.15 Gold reveal uses real card_id from available_actions
func _test_gold_reveal_real_card_id():
	var d = _setup_gc_with_hand()
	var gc = d["gc"]; var mp = d["mp"]; var hp = d["hp"]; var tp = d["tp"]

	var snap = _make_hand_snapshot([
		{"card_id":"g78","name":"78","value":78,"color":"dorato","card_type":"gold"},
	])
	snap["available_actions"] = [
		{"action_type": "reveal_gold", "card_id": "g78"},
	]
	mp.emit_signal("game_started", snap)
	_assert_eq(gc.get_state(), 3, "WAITING_FOR_CHOICE")

	mp.auto_emit_action_completed = false
	gc._on_gold_reveal_yes()
	var o1 = _assert_eq(mp.last_send_action_dict.get("card_id"), "g78", "card_id from available_actions")
	_cleanup(d)
	return "  Gold uses real card_id:    " + ("[PASS]\n" if o1 else "[FAIL]\n")


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
	out += _test_gold_reveal_opens_popup()
	out += _test_gold_reveal_yes()
	out += _test_gold_reveal_no()
	out += _test_jolly_value_zero_invalid()
	out += _test_jolly_value_eleven_invalid()
	out += _test_imbroglio_value_zero_invalid()
	out += _test_imbroglio_value_minus16_invalid()
	out += _test_imbroglio_value_16_invalid()
	out += _test_gold_reveal_not_reopen()
	out += _test_gold_reveal_not_in_gameover()
	out += _test_gold_reveal_real_card_id()
	out += "--- Step 5: card animator ---\n"
	out += _test_animating_state()
	out += _test_anim_finishes_ready()
	out += _test_input_ignored_during_anim()

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFailures:\n"
		for m in failure_msgs:
			out += "  - " + str(m) + "\n"
	out += "\n========================================\n"
	return out
