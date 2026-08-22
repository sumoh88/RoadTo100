extends Node

# Headless tests for the 1 Human + 3 CPU manual game mode (ManualGame.gd).
#
# Covers:
#   - avvio 1 human + 3 CPU
#   - CPU avanzano automaticamente
#   - automazione si ferma al turno umano (no action on human turn)
#   - UI/azioni umane funzionano (via signal flow + popup handlers)
#   - dopo il turno umano le CPU ripartono
#   - popup umani non vengono aperti nei turni CPU (CPU resolves own popups)
#   - game over interrompe tutto correttamente
#
# Run: ./Godot3 --path /path/to/project tests/manual_game_test.tscn --no-window

var GameController = load("res://scripts/GameController.gd")
var ManualGame = load("res://scripts/ManualGame.gd")
var LocalGameEngine = load("res://engine/LocalGameEngine.gd")
var MockProvider = load("res://tests/mock_provider.gd")
var MockPresenter = load("res://tests/mock_presenter.gd")

const GC_WAITING_FOR_STATE = 0
const GC_READY_FOR_INPUT = 1
const GC_CARD_SELECTED = 2
const GC_WAITING_FOR_CHOICE = 3
const GC_GAME_OVER = 7

var passed = 0
var failed = 0
var failure_msgs = []

var _gc = null
var _mp = null
var _bp = null
var _hp = null
var _tp = null
var _mg = null


func _ready():
	randomize()
	var out = _run_all()
	if out is GDScriptFunctionState:
		out = yield(out, "completed")
	print(out)
	get_tree().quit(0)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(str(msg))
		print("  FAIL: " + str(msg))
	return cond


# ===========================================================================
# Setup / teardown
# ===========================================================================

# GC + provider + mock presenters + ManualGame (as child of GC, like Main.tscn).
# provider_class selectable: real LocalGameEngine or MockProvider.
func _setup(use_mock_provider):
	_gc = GameController.new()
	if use_mock_provider:
		_mp = MockProvider.new()
		_mp.auto_emit_action_completed = false  # record-only for unit tests
	else:
		_mp = LocalGameEngine.new()
	_gc.set_provider(_mp)

	_bp = MockPresenter.new()
	_hp = MockPresenter.new()
	_tp = MockPresenter.new()
	_gc._board = _bp
	_gc._hand = _hp
	_gc._turn = _tp
	_hp.connect("card_selected", _gc, "_on_card_selected")
	_tp.connect("play_pressed", _gc, "_on_play_pressed")
	_tp.connect("change_pressed", _gc, "_on_change_pressed")
	_tp.connect("cancel_pressed", _gc, "_on_cancel_pressed")

	add_child(_gc)

	# ManualGame as child of GameController (matches Main.tscn wiring).
	_mg = ManualGame.new()
	_gc.add_child(_mg)
	# Defensive wiring (robust against _ready timing):
	if _mg._gc != _gc:
		_mg._gc = _gc
	if _mg.timer == null:
		var t = Timer.new()
		t.one_shot = true
		_mg.timer = t
		_mg.add_child(t)
	# Huge delay so any accidental schedule never fires during the test; we drive manually.
	_mg.step_delay_ms = 999999


func _cleanup():
	if _mg != null:
		_mg.stop()
		_mg.free()
		_mg = null
	if _gc != null:
		remove_child(_gc)
		_gc.free()
		_gc = null
	if _bp != null: _bp.free(); _bp = null
	if _hp != null: _hp.free(); _hp = null
	if _tp != null: _tp.free(); _tp = null
	_mp = null


# ===========================================================================
# Unit tests (MockProvider / crafted snapshots)
# ===========================================================================

func _test_is_local_turn_detection():
	# Standalone ManualGame — pure logic.
	var mg = ManualGame.new()
	var human_snap = {
		"current_player_index": 0,
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
	}
	var cpu_snap = {
		"current_player_index": 1,
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
	}
	_assert(mg._is_local_turn(human_snap, "player_1") == true, "detects human turn (index 0)")
	_assert(mg._is_local_turn(cpu_snap, "player_1") == false, "does not detect CPU turn (index 1)")
	mg.free()


func _test_no_action_on_human_turn():
	_setup(true)
	var mp = _mp
	mp.auto_emit_game_started = true
	mp.snapshot_to_emit = {
		"current_player_index": 0,  # player_1 = human goes first
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
		"available_actions": [
			{"action_type": "play_card", "card_id": "inc1_x1"},
		],
		"winner": null,
		"turn_number": 1,
	}
	_gc.start_game(4)
	yield(get_tree(), "idle_frame")

	mp.reset()
	_mg.running = true
	# Timer fires while it is the HUMAN's turn: must NOT perform an action.
	_mg._on_timer_timeout()
	yield(get_tree(), "idle_frame")

	_assert(mp.send_action_called == false, "no CPU action on human turn")
	_cleanup()


func _test_action_on_cpu_turn():
	_setup(true)
	var mp = _mp
	mp.snapshot_to_emit = {
		"current_player_index": 1,  # player_2 = CPU
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
		"available_actions": [
			{"action_type": "play_card", "card_id": "inc1_x1"},
		],
		"winner": null,
		"turn_number": 2,
	}
	_gc.start_game(4)
	yield(get_tree(), "idle_frame")

	mp.reset()
	_mg.running = true
	_mg._on_timer_timeout()
	yield(get_tree(), "idle_frame")

	_assert(mp.send_action_called == true, "CPU performs action on its turn")
	var d = mp.last_send_action_dict
	if d != null:
		_assert(d.get("action_type", "") == "play_card", "CPU action is play_card")
	_cleanup()


func _test_cpu_resolves_own_popup():
	# During a CPU turn the GC may auto-open a value-choice popup (WAITING_FOR_CHOICE,
	# e.g. Jolly). ManualGame must resolve it itself (not leave it for the human).
	_setup(true)
	var mp = _mp
	mp.snapshot_to_emit = {
		"current_player_index": 2,  # player_3 = CPU
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
		"available_actions": [
			{
				"action_type": "play_card",
				"card_id": "jolly_x1",
				"choices": [{"label": "5", "parameters": {"selected_value": 5}}],
			},
		],
		"winner": null,
		"turn_number": 3,
	}
	_gc.start_game(4)
	yield(get_tree(), "idle_frame")

	# Force the WAITING_FOR_CHOICE state as if a value-choice popup were open.
	_gc._state = GC_WAITING_FOR_CHOICE
	mp.reset()
	_mg.running = true
	_mg._on_timer_timeout()
	yield(get_tree(), "idle_frame")

	_assert(mp.send_action_called == true, "CPU resolves its own value-choice popup")
	var d = mp.last_send_action_dict
	if d != null:
		_assert(d.get("action_type", "") == "play_card", "CPU popup resolved via play_card")
		_assert(d.get("selected_value", 0) == 5, "CPU chose the offered value")
	_cleanup()


# ===========================================================================
# Human UI helpers (drive the real GameController signal flow)
# ===========================================================================

func _pick_human_action(acts):
	for a in acts:
		if a.get("action_type", "") == "play_card" and not a.has("choices"):
			return a
	for a in acts:
		if a.get("action_type", "") == "play_card":
			return a
	for a in acts:
		if a.get("action_type", "") == "change_card":
			return a
	for a in acts:
		if a.get("action_type", "") == "reset_hand":
			return a
	return acts[0] if not acts.empty() else null


func _human_resolve_popup():
	if _gc.get_state() != GC_WAITING_FOR_CHOICE:
		return
	if _gc._pending_blocked_type:
		_gc._on_safe_round_choice_chosen("Incremento")
	else:
		var vals = _gc._pending_valid_values
		if not vals.empty():
			_gc._on_value_chosen(vals[0])
		else:
			# HandResetPopup — answer Yes.
			_gc._on_hand_reset_yes()


# Human takes one turn through the UI signal flow (returns true if it acted).
# Note: signal handlers run synchronously in Godot 3 (no card animator in tests),
# so this is a plain function — no yields.
func _human_take_turn():
	var snap = _gc.get_last_snapshot()
	if snap == null:
		return false
	var acts = snap.get("available_actions", [])

	# If a blocking popup is already open on this human turn, resolve it.
	if _gc.get_state() == GC_WAITING_FOR_CHOICE:
		_human_resolve_popup()
		return true

	var target = _pick_human_action(acts)
	if target == null:
		return false

	var at = target.get("action_type", "")
	if at == "play_card" or at == "change_card":
		var cid = target.get("card_id", "")
		_hp.emit_signal("card_selected", cid)   # UI: select card
		if at == "play_card":
			_tp.emit_signal("play_pressed")     # UI: press Gioca
		else:
			_tp.emit_signal("change_pressed")   # UI: press Cambia
		_human_resolve_popup()                    # value / safe-round popup
		return true
	elif at == "reset_hand":
		if _gc.get_state() == GC_WAITING_FOR_CHOICE:
			_gc._on_hand_reset_yes()
		else:
			_gc.perform_action({"action_type": "reset_hand"})
		return true

	return false


# ===========================================================================
# Integration tests (real LocalGameEngine)
# ===========================================================================

func _test_start_1h3c():
	_setup(false)
	_mg.start_game()
	yield(get_tree(), "idle_frame")
	var snap = _gc.get_last_snapshot()
	_assert(snap != null, "snapshot present after start")
	if snap != null:
		_assert(snap.get("players", []).size() == 4, "game has 4 players")
		_assert(snap.get("local_player_id", "") == "player_1", "local player is player_1")
		var ci = snap.get("current_player_index", -1)
		# Starting player is random; just verify it is a valid index.
		_assert(ci >= 0 and ci < 4, "valid starting player index: " + str(ci))
	_cleanup()


func _test_cpu_advances_after_human_turn():
	_setup(false)
	_mg.start_game()
	yield(get_tree(), "idle_frame")

	# Drive CPU turns (automated) until it becomes the human's turn.
	var max_iter = 120
	var iter = 0
	var reached_human = false
	while iter < max_iter:
		iter += 1
		var snap = _gc.get_last_snapshot()
		if snap == null or snap.get("winner", null) != null:
			break
		if _mg._is_local_turn(snap, snap.get("local_player_id", "player_1")):
			reached_human = true
			break
		_mg.running = true
		_mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

	_assert(reached_human == true, "reached a human turn")
	if not reached_human:
		_cleanup()
		return

	# Human's turn — act through the UI flow.
	var snap = _gc.get_last_snapshot()
	var idx_before = snap.get("current_player_index", -1)
	var human_acted = _human_take_turn()
	yield(get_tree(), "idle_frame")
	_assert(human_acted == true, "human completed their turn via UI")

	# After the human acts, it should be a CPU's turn now.
	var snap2 = _gc.get_last_snapshot()
	if snap2 != null and snap2.get("winner", null) == null:
		var lid = snap2.get("local_player_id", "player_1")
		_assert(_mg._is_local_turn(snap2, lid) == false, "turn passed to a CPU after human")

		# CPU should now advance automatically.
		var turn_before = snap2.get("turn_number", 0)
		_mg.running = true
		_mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

		var snap3 = _gc.get_last_snapshot()
		var advanced = false
		if snap3 != null:
			advanced = (snap3.get("turn_number", 0) > turn_before) or \
				snap3.get("current_player_index", -1) != idx_before or \
				snap3.get("winner", null) != null
		_assert(advanced == true, "CPU advanced its turn automatically")
	_cleanup()


func _test_full_game_1h3c():
	_setup(false)
	_mg.start_game()
	yield(get_tree(), "idle_frame")

	# A 4-player game with reshuffles can take many actions to reach 100;
	# allow a generous budget so the test isn't flaky on slow boards.
	var max_iter = 400
	var iter = 0
	var winner = null
	var cpu_moves = 0
	var human_moves = 0

	while iter < max_iter:
		iter += 1
		var snap = _gc.get_last_snapshot()
		if snap == null:
			yield(get_tree(), "idle_frame")
			continue
		winner = snap.get("winner", null)
		if winner != null:
			break

		var lid = snap.get("local_player_id", "player_1")
		if _mg._is_local_turn(snap, lid):
			# Human turn — act through the UI flow.
			if _human_take_turn():
				human_moves += 1
			yield(get_tree(), "idle_frame")
		else:
			# CPU turn — automate via ManualGame.
			_mg.running = true
			_mg._on_timer_timeout()
			cpu_moves += 1
			yield(get_tree(), "idle_frame")

	_assert(winner != null, "full game reached a winner (turns=" + str(iter) + ")")
	_assert(cpu_moves > 0, "CPU made moves: " + str(cpu_moves))
	_assert(human_moves > 0, "human made moves via UI: " + str(human_moves))
	_assert(_mg.running == false, "ManualGame stopped on game over")
	_cleanup()


# ===========================================================================
# Regression tests for the two visual-test bugs
# ===========================================================================

# Bug 1: starting ManualGame must stop any sibling automation (e.g. DebugDemo)
# so it never plays the human's turn while a manual game is running.
func _test_manual_game_stops_sibling_automation():
	var DebugDemo = load("res://scripts/DebugDemo.gd")
	_setup(true)
	var mp = _mp
	mp.auto_emit_game_started = true
	mp.snapshot_to_emit = {
		"current_player_index": 0,
		"local_player_id": "player_1",
		"players": [
			{"id": "player_1"}, {"id": "player_2"},
			{"id": "player_3"}, {"id": "player_4"},
		],
		"available_actions": [],
		"winner": null,
		"turn_number": 0,
	}

	var dd = DebugDemo.new()
	_gc.add_child(dd)
	yield(get_tree(), "idle_frame")
	if dd._gc != _gc:
		dd._gc = _gc

	# Simulate a demo that was already running when the user starts a manual game.
	dd.running = true
	_mg.start_game()
	yield(get_tree(), "idle_frame")

	_assert(_mg.running == true, "ManualGame is running after start")
	_assert(dd.running == false, "sibling DebugDemo was stopped (bug 1 fix), got: " + str(dd.running))

	dd.free()
	_cleanup()


# Bug 2: the OverlayLayer must not intercept game-area clicks — its mouse_filter
# must be IGNORE so that on a human turn the card buttons remain clickable.
func _test_overlay_does_not_block_input():
	var scene = load("res://Main.tscn")
	if scene == null:
		_assert(false, "Main.tscn loaded")
		return
	var inst = scene.instance()
	var overlay = inst.get_node_or_null("OverlayLayer")
	_assert(overlay != null, "OverlayLayer node exists in Main.tscn")
	if overlay != null:
		# MOUSE_FILTER_IGNORE == 2 (1 = PASS would steal clicks from the game UI).
		_assert(overlay.mouse_filter == 2,
			"OverlayLayer mouse_filter is IGNORE (bug 2 fix), got: " + str(overlay.mouse_filter))
	inst.free()


# Requested: on a human turn the GC must be interactive, and selecting a card +
# pressing Gioca/Cambia must actually send an action to the engine.
func _test_human_play_action_reaches_engine():
	_setup(false)
	_mg.start_game()
	yield(get_tree(), "idle_frame")

	# Drive CPU turns until it is the human's turn.
	var max_iter = 120
	var iter = 0
	while iter < max_iter:
		iter += 1
		var snap = _gc.get_last_snapshot()
		if snap == null or snap.get("winner", null) != null:
			break
		if _mg._is_local_turn(snap, snap.get("local_player_id", "player_1")):
			break
		_mg.running = true
		_mg._on_timer_timeout()
		yield(get_tree(), "idle_frame")

	var snap = _gc.get_last_snapshot()
	if snap == null or snap.get("winner", null) != null:
		_cleanup()
		return
	if not _mg._is_local_turn(snap, snap.get("local_player_id", "player_1")):
		_assert(false, "could not reach a human turn")
		_cleanup()
		return

	# (a) GC is in an interactive state on the human's turn.
	var st = _gc.get_state()
	_assert(st == GC_READY_FOR_INPUT or st == GC_CARD_SELECTED,
		"GC is interactive on human turn (state=" + str(st) + ")")

	# (b) Select a card and press Play/Change — the engine state must advance.
	var acts = snap.get("available_actions", [])
	var target = _pick_human_action(acts)
	if target == null:
		_cleanup()
		return
	var at = target.get("action_type", "")
	var cid = target.get("card_id", "")
	var turn_before = snap.get("turn_number", 0)

	if at == "play_card" or at == "change_card":
		_hp.emit_signal("card_selected", cid)
		if at == "play_card":
			_tp.emit_signal("play_pressed")
		else:
			_tp.emit_signal("change_pressed")
		_human_resolve_popup()

	yield(get_tree(), "idle_frame")

	var snap2 = _gc.get_last_snapshot()
	var acted = false
	if snap2 != null:
		acted = (snap2.get("turn_number", 0) > turn_before) or \
			snap2.get("winner", null) != null
	_assert(acted, "human selection + Play/Change was applied to the engine (turn advanced)")
	_cleanup()


# ===========================================================================
func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Manual Game Test (1H + 3C)\n"
	out += "========================================\n\n"

	var tests = [
		"_test_is_local_turn_detection",
		"_test_no_action_on_human_turn",
		"_test_action_on_cpu_turn",
		"_test_cpu_resolves_own_popup",
		"_test_start_1h3c",
		"_test_cpu_advances_after_human_turn",
		"_test_full_game_1h3c",
		"_test_manual_game_stops_sibling_automation",
		"_test_overlay_does_not_block_input",
		"_test_human_play_action_reaches_engine",
	]

	for t in tests:
		print("--- " + t + " ---")
		var g = callv(t, [])
		if g is GDScriptFunctionState:
			yield(g, "completed")

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
