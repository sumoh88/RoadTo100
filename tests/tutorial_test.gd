extends Node

# Headless test for the TUTORIAL MODE (Phase 1A).
# Covers:
#   1. "Come si gioca" enters tutorial mode (routing via Main.tscn)
#   2. Gameplay/input blocked in mode
#   3. "Nuova partita" not accessible
#   4. "Mostra" starts the demo and blocks interaction
#   5. End of "Mostra" always returns to the same popup/step
#   6. "Prosegui" advances to next step
#   7. "Prosegui"/"Fine" on last step ends tutorial (tutorial_finished)
#   8. States restored when exiting
#   9. Popup has a left image and uses the choice_value style

var GameController = load("res://scripts/GameController.gd")
var DebugDemoScript = load("res://scripts/DebugDemo.gd")
var TutorialControllerScript = load("res://scripts/TutorialController.gd")
var MockPresenter = load("res://tests/mock_presenter.gd")

var passed = 0
var failed = 0

var _gc = null
var _demo = null
var _tc = null
var _bp = null
var _hp = null
var _tp = null
var _finished_emitted = false


func _ready():
	randomize()
	var out = _run_all()
	if out is GDScriptFunctionState:
		out = yield(out, "completed")
	print(out)
	get_tree().quit(0 if (failed == 0 and passed > 0) else 1)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: " + str(msg))
	return cond


# ---------------------------------------------------------------------------
# Setup / teardown (unit: GC + provider + real DebugDemo + TutorialController)
# ---------------------------------------------------------------------------

func _on_tutorial_finished_signal():
	_finished_emitted = true


# The UI (overlay, panel, image, labels, buttons) now lives in the .tscn, so
# instantiate the controller from its scene to keep those nodes present.
func _create_tc():
	var packed = load("res://scripts/TutorialController.tscn") as PackedScene
	if packed != null:
		return packed.instance()
	return TutorialControllerScript.new()


func _setup():
	_gc = GameController.new()
	var mp = load("res://engine/LocalGameEngine.gd").new()
	_gc.set_provider(mp)

	_bp = MockPresenter.new(); _gc._board = _bp
	_hp = MockPresenter.new(); _gc._hand = _hp
	_tp = MockPresenter.new(); _gc._turn = _tp
	_hp.connect("card_selected", _gc, "_on_card_selected")
	_tp.connect("play_pressed", _gc, "_on_play_pressed")
	_tp.connect("change_pressed", _gc, "_on_change_pressed")
	_tp.connect("cancel_pressed", _gc, "_on_cancel_pressed")
	add_child(_gc)

	_demo = DebugDemoScript.new()
	_gc.add_child(_demo)

	_tc = _create_tc()
	_gc.add_child(_tc)
	_finished_emitted = false
	if _tc.has_signal("tutorial_finished"):
		_tc.connect("tutorial_finished", self, "_on_tutorial_finished_signal")


func _cleanup():
	if _tc != null:
		_gc.remove_child(_tc); _tc.free(); _tc = null
	if _demo != null:
		_gc.remove_child(_demo); _demo.free(); _demo = null
	remove_child(_gc); _gc.free(); _gc = null
	if _bp != null: _bp.free(); _bp = null
	if _hp != null: _hp.free(); _hp = null
	if _tp != null: _tp.free(); _tp = null


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

# Req 1 + 3: routing from the menu enters tutorial mode; "Nuova partita" off.
func _test_menu_routing():
	GlobalsUtilities.tutorialStarted = true
	var packed = load("res://Main.tscn") as PackedScene
	if packed == null:
		_assert(false, "Main.tscn not found")
		return
	var main = packed.instance()
	add_child(main)  # triggers _ready -> tutorial routing
	yield(get_tree(), "idle_frame")

	var tc = main.get_node_or_null("GameController/TutorialController")
	_assert(tc != null, "TutorialController present in Main scene")
	if tc != null:
		_assert(tc.active == true, "tutorial mode active after 'Come si gioca' routing")
		assert_overlay_blocks(tc)
	var sgb = main.get_node_or_null("StartGameButton")
	if sgb != null:
		_assert(sgb.disabled == true, "'Nuova partita' disabled in tutorial mode")
	_assert(GlobalsUtilities.tutorialStarted == false, "tutorialStarted flag cleared after entering")

	main.queue_free()
	yield(get_tree(), "idle_frame")
	GlobalsUtilities.tutorialStarted = false


func assert_overlay_blocks(tc):
	if tc != null and tc._overlay_root != null:
		_assert(tc._overlay_root.visible == true, "input blocker active (gameplay blocked)")


# Req 2: mode active + input blocked.
func _test_mode_blocks_input():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	_assert(_tc.active == true, "mode active after start")
	assert_overlay_blocks(_tc)
	_cleanup()


# Req 4: "Mostra" starts the demo and keeps interaction blocked.
func _test_mostra_starts_demo_and_blocks():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	_tc.on_show_pressed()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	_assert(_demo.running == true or _gc.get_last_snapshot() != null, "Mostra started the demo")
	_assert(_gc.get_last_snapshot() != null, "game snapshot present (board set up)")
	assert_overlay_blocks(_tc)
	_assert(_tc._panel == null or _tc._panel.visible == false, "popup hidden during demo (table visible)")
	_cleanup()


# Req 5: end of "Mostra" always returns to the same popup/step.
func _test_demo_end_returns_to_same_popup():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	var step_before = _tc.current_step_index
	_tc.on_show_pressed()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	for i in range(40):
		yield(get_tree(), "idle_frame")
		if not _demo.running:
			break
		_demo.advance_step()
	yield(get_tree(), "idle_frame")
	_assert(_tc.active == true, "still in tutorial after demo ends")
	_assert(_tc.current_step_index == step_before, "returned to the SAME step")
	_assert(_tc._panel != null and _tc._panel.visible == true, "popup re-shown after demo")
	_cleanup()


# Req 6: "Prosegui" advances to the next step.
func _test_proceed_advances():
	_setup()
	_assert(_tc.steps.size() >= 2, "tutorial has at least 2 steps (1A and 1B)")
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	_assert(_tc.current_step_index == 0, "started on step 0")
	var expected_title = _tc.steps[1]["title"]
	_tc.on_proceed_pressed()
	yield(get_tree(), "idle_frame")
	_assert(_tc.current_step_index == 1, "advanced to step 1 after Prosegui")
	_assert(_tc._title_label.text == expected_title, "step 1 content shown")
	_cleanup()


# Req 7: "Prosegui"/"Fine" on the last step ends the tutorial.
func _test_last_step_fine():
	_setup()
	_finished_emitted = false
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	# Navigate to the last step (works regardless of step count).
	while _tc.current_step_index < _tc.steps.size() - 1:
		_tc.on_proceed_pressed()
		yield(get_tree(), "idle_frame")
	_assert(_tc.current_step_index == _tc.steps.size() - 1, "reached the last step")
	_assert(_tc._proceed_btn.text == "Fine", "last step shows 'Fine'")
	_tc.on_proceed_pressed()
	yield(get_tree(), "idle_frame")
	_assert(_tc.active == false, "tutorial inactive after Fine")
	_assert(_finished_emitted == true, "tutorial_finished emitted (scene navigates to menu)")
	_cleanup()


# Req 8: states restored when exiting.
func _test_states_restored():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	_tc.finish_tutorial()
	yield(get_tree(), "idle_frame")
	_assert(_tc.active == false, "mode inactive after finish")
	_assert(_tc._overlay_root != null and _tc._overlay_root.visible == false, "input blocker removed")
	_assert(GlobalsUtilities.tutorialStarted == false, "no lingering tutorial flags")
	_cleanup()


# Req 9: popup has a left image and uses the choice_value style.
func _test_popup_layout_style():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	var step = _tc.steps[0]
	_assert(_tc._image_rect != null, "left image node present")
	_assert(_tc._image_rect.texture != null, "left image texture loaded from step content")
	if _tc._panel != null:
		var sbt = _tc._panel.get_stylebox("panel")
		_assert(sbt != null and (sbt is StyleBoxTexture), "panel uses a StyleBoxTexture background (choice_value style)")
	_assert(_tc._title_label != null and _tc._title_label.text == step["title"], "title set")
	_assert(_tc._text_label != null, "body text node present")
	_assert(_tc._show_btn != null and _tc._show_btn.text == "Mostra", "'Mostra' button present")
	_assert(_tc._proceed_btn != null, "'Prosegui'/'Fine' button present")
	_cleanup()


# Step 1B: the increment step exists with the right content and image.
func _test_step1b_content():
	_setup()
	var found = null
	for s in _tc.steps:
		if s.get("id") == "increment_cards":
			found = s
			break
	_assert(found != null, "step 1B (increment_cards) exists")
	if found != null:
		_assert(found["image"] == "res://imgs/inc7.png", "step 1B uses an increment +7 card image")
		var txt = str(found["text"]).to_lower()
		_assert(txt.find("jolly") >= 0, "step 1B explains the Jolly")
		_assert((txt.find("+1") >= 0) and (txt.find("+10") >= 0), "step 1B mentions the increment range (+1..+10)")
		_assert(found.has("scenario"), "step 1B has a scripted scenario demo")
		var segs = found["scenario"].get("segments", [])
		_assert(segs.size() >= 2, "step 1B has at least 2 segments (two demos with rewind)")
		if segs.size() > 0:
			var p1 = str(segs[0]["setup"]["hands"]["player_1"])
			_assert((p1.find("+4") >= 0) and (p1.find("+7") >= 0) and (p1.find("Jolly") >= 0), "step 1B P1 starts with +4, +7, Jolly")
	_cleanup()


# Step 1B: the short-demo card-type focus filter keeps only matching cards.
func _test_demo_focus_filtering():
	_setup()
	var snapshot = {
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "c1", "card_type": "increment", "value": 7},
				{"card_id": "c2", "card_type": "gold", "value": 23},
				{"card_id": "c3", "card_type": "jolly"},
			]},
		],
	}
	var acts = [
		{"action_type": "play_card", "card_id": "c1"},
		{"action_type": "play_card", "card_id": "c2"},
		{"action_type": "play_card", "card_id": "c3"},
	]
	_demo.short_demo_focus_types = ["increment", "jolly"]
	var filtered = _demo._filter_actions_by_focus(acts, snapshot)
	_assert(filtered.size() == 2, "focus filter keeps only increment + jolly plays")
	var kept = []
	for a in filtered:
		kept.append(a["card_id"])
	_assert(kept.has("c1") and kept.has("c3"), "increment (c1) and jolly (c3) kept, gold (c2) dropped")

	# No focus -> returns all acts unchanged.
	_demo.short_demo_focus_types = []
	var unfiltered = _demo._filter_actions_by_focus(acts, snapshot)
	_assert(unfiltered.size() == acts.size(), "no focus returns all actions unchanged")
	_cleanup()


# Step 1: "Mostra" on the increment step starts the scripted prepared demo.
func _test_step1b_mostra_focus():
	_setup()
	_tc.start_tutorial()
	yield(get_tree(), "idle_frame")
	# Advance to step 1B (index 1).
	while _tc.current_step_index < 1:
		_tc.on_proceed_pressed()
		yield(get_tree(), "idle_frame")
	_assert(_tc.steps[_tc.current_step_index].get("id") == "increment_cards", "on the increment step")
	_demo.scripted_mode = false
	_tc.on_show_pressed()
	yield(get_tree(), "idle_frame")
	_assert(_demo.scripted_mode == true, "Mostra on the increment step starts the scripted demo")
	_cleanup()


# Step 1B: the focused short demo only selects increment/jolly plays when they
# are available. We simulate one decision tick of _on_timer_timeout's selection
# path by feeding it a snapshot + actions and confirming the filtered set (which
# _choose_action then draws from) contains no non-focused cards.
func _test_step1b_demo_selects_increment():
	_setup()
	var snapshot = {
		"players": [
			{"id": "player_1", "hand": [
				{"card_id": "c1", "card_type": "increment", "value": 7},
				{"card_id": "c2", "card_type": "increment", "value": 3},
				{"card_id": "c3", "card_type": "gold", "value": 23},
			]},
		],
	}
	var acts = [
		{"action_type": "play_card", "card_id": "c1"},
		{"action_type": "play_card", "card_id": "c2"},
		{"action_type": "play_card", "card_id": "c3"},
	]
	_demo.short_demo_turns = 3
	_demo.short_demo_focus_types = ["increment", "jolly"]
	# Replicate the selection logic from _on_timer_timeout.
	var effective_acts = acts
	if _demo.short_demo_turns > 0 and _demo.short_demo_focus_types.size() > 0:
		var filtered = _demo._filter_actions_by_focus(acts, snapshot)
		if filtered.size() > 0:
			effective_acts = filtered
	_assert(effective_acts.size() == 2, "short demo with focus only sees increment plays")
	for a in effective_acts:
		var ct = ""
		for p in snapshot["players"]:
			for c in p["hand"]:
				if str(c.get("card_id", "")) == str(a.get("card_id", "")):
					ct = str(c.get("card_type", ""))
		_assert(ct == "increment" or ct == "jolly", "no non-focused card selected for the step 1B demo")
	_cleanup()


# Determinism helpers ------------------------------------------------------------

func _snap_sig(s):
	"""Stable signature of a snapshot: starting/current player, Piatto, and every
	hand's ordered card_ids. Two runs producing identical signatures per step are
	playing the exact same game."""
	if s == null:
		return "null"
	var cur = str(s.get("current_player_index", -1))
	var piatto = str(s.get("piatto", 0))
	var hands = ""
	for p in s.get("players", []):
		var ids_str = ""
		var h = p.get("hand", [])
		for idx2 in range(h.size()):
			if idx2 > 0:
				ids_str += ","
			ids_str += str(h[idx2].get("card_id", ""))
		hands += str(p.get("id", "")) + ":" + ids_str + ";"
	return cur + "|" + piatto + "|" + hands


# Req 2: the tutorial demo always starts from Player 1.
func _test_demo_starts_player1():
	_setup()
	_demo.start_short_demo(3, [])
	yield(get_tree(), "idle_frame")
	var s = _gc.get_last_snapshot()
	_assert(s != null, "snapshot present after tutorial demo start")
	if s != null:
		_assert(int(s.get("current_player_index", -1)) == 0, "demo starts from player index 0")
		var players = s.get("players", [])
		_assert(players.size() > 0 and str(players[0].get("id", "")) == "player_1", "demo starts from Player 1")
	_cleanup()


# Req 1: two runs of the same "Mostra" replay the exact same initial state and
# turn sequence (fixed tutorial seed).
func _test_mostra_is_deterministic():
	_setup()

	# --- Run 1 ---
	_demo.start_short_demo(3, [])
	yield(get_tree(), "idle_frame")
	var seq1 = []
	seq1.append(_snap_sig(_gc.get_last_snapshot()))
	for i in range(10):
		if not _demo.running:
			break
		_demo.advance_step()
		yield(get_tree(), "idle_frame")
		seq1.append(_snap_sig(_gc.get_last_snapshot()))

	# --- Run 2 (start_short_demo re-seeds the tutorial RNG) ---
	_demo.start_short_demo(3, [])
	yield(get_tree(), "idle_frame")
	var seq2 = []
	seq2.append(_snap_sig(_gc.get_last_snapshot()))
	for i in range(10):
		if not _demo.running:
			break
		_demo.advance_step()
		yield(get_tree(), "idle_frame")
		seq2.append(_snap_sig(_gc.get_last_snapshot()))

	_assert(seq1.size() > 1, "demo produced a multi-step sequence (got " + str(seq1.size()) + ")")
	_assert(seq1.size() == seq2.size(), "two Mostra runs produce same-length sequences")
	var same_initial = (seq1.size() > 0 and seq2.size() > 0 and seq1[0] == seq2[0])
	_assert(same_initial, "same initial state on both Mostra runs")
	var seq_ok = true
	for i in range(min(seq1.size(), seq2.size())):
		if seq1[i] != seq2[i]:
			seq_ok = false
			break
	_assert(seq_ok, "identical turn sequence across two Mostra runs (deterministic seed)")
	_cleanup()


# Req 3: normal games are unaffected — no tutorial RNG attached and the starting
# player is still chosen randomly (not forced to Player 1).
func _test_normal_game_unaffected():
	var Engine = load("res://engine/LocalGameEngine.gd")
	var seen = {}
	for i in range(16):
		var e = Engine.new()
		e.start_game(4)  # no rng -> normal behaviour (global randi, random start)
		var idx = int(e.game_state.current_player_index)
		seen[idx] = true
		_assert(e.game_state.deck.rng == null, "normal game deck has no tutorial rng attached")
		e.free()
	_assert(seen.size() > 1, "normal start_game(4) uses a random starting player (not forced to Player 1)")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Tutorial Mode Test (1A + 1B)\n"
	out += "========================================\n"

	var t1 = _test_menu_routing()
	if t1 is GDScriptFunctionState: yield(t1, "completed")
	var t2 = _test_mode_blocks_input()
	if t2 is GDScriptFunctionState: yield(t2, "completed")
	var t3 = _test_mostra_starts_demo_and_blocks()
	if t3 is GDScriptFunctionState: yield(t3, "completed")
	var t4 = _test_demo_end_returns_to_same_popup()
	if t4 is GDScriptFunctionState: yield(t4, "completed")
	var t5 = _test_proceed_advances()
	if t5 is GDScriptFunctionState: yield(t5, "completed")
	var t6 = _test_last_step_fine()
	if t6 is GDScriptFunctionState: yield(t6, "completed")
	var t7 = _test_states_restored()
	if t7 is GDScriptFunctionState: yield(t7, "completed")
	var t8 = _test_popup_layout_style()
	if t8 is GDScriptFunctionState: yield(t8, "completed")
	var t9 = _test_step1b_content()
	if t9 is GDScriptFunctionState: yield(t9, "completed")
	var t10 = _test_demo_focus_filtering()
	if t10 is GDScriptFunctionState: yield(t10, "completed")
	var t11 = _test_step1b_mostra_focus()
	if t11 is GDScriptFunctionState: yield(t11, "completed")
	var t12 = _test_step1b_demo_selects_increment()
	if t12 is GDScriptFunctionState: yield(t12, "completed")
	var t13 = _test_demo_starts_player1()
	if t13 is GDScriptFunctionState: yield(t13, "completed")
	var t14 = _test_mostra_is_deterministic()
	if t14 is GDScriptFunctionState: yield(t14, "completed")
	var t15 = _test_normal_game_unaffected()
	if t15 is GDScriptFunctionState: yield(t15, "completed")

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if passed + failed == 0:
		out += "\nFAIL: NO assertions executed — likely a script/runtime error.\n"
	elif failed > 0:
		out += "\nFAIL: Some tutorial assertions failed.\n"
	else:
		out += "\nALL TUTORIAL ASSERTIONS PASSED.\n"
	out += "========================================\n"
	return out
