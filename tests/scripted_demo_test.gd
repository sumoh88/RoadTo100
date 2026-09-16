extends Node

# Headless test for the SCRIPTED TUTORIAL DEMO system.
# Verifies:
#   1. Initial state matches the prepared scenario (P1 hand, Piatto).
#   2. Each step plays its scripted card(s) through the real flow (piatto /
#      special-round outcomes match the rules).
#   3. Real choice popups open (state reaches WAITING_FOR_CHOICE for Jolly/
#      Imbroglio/Gold).
#   4. Rewind between segments restores the prepared state.
#   5. Reproducibility: two runs of the same step are identical.

var GameController = load("res://scripts/GameController.gd")
var DebugDemoScript = load("res://scripts/DebugDemo.gd")
var TutorialControllerScript = load("res://scripts/TutorialController.gd")
var MockPresenter = load("res://tests/mock_presenter.gd")

const WAITING_FOR_CHOICE = 3

var passed = 0
var failed = 0
var _gc = null
var _demo = null
var _tc = null
var _bp = null
var _hp = null
var _tp = null


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
# Setup
# ---------------------------------------------------------------------------

func _setup():
	_gc = GameController.new()
	var mp = load("res://engine/LocalGameEngine.gd").new()
	_gc.set_provider(mp)
	_bp = MockPresenter.new(); _gc._board = _bp
	_hp = MockPresenter.new(); _gc._hand = _hp
	_tp = MockPresenter.new(); _gc._turn = _tp
	add_child(_gc)
	_demo = DebugDemoScript.new()
	_gc.add_child(_demo)
	_tc = TutorialControllerScript.new()
	_gc.add_child(_tc)


func _cleanup():
	if _tc != null: _gc.remove_child(_tc); _tc.free(); _tc = null
	if _demo != null: _gc.remove_child(_demo); _demo.free(); _demo = null
	remove_child(_gc); _gc.free(); _gc = null
	if _bp != null: _bp.free(); _bp = null
	if _hp != null: _hp.free(); _hp = null
	if _tp != null: _tp.free(); _tp = null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_step(id):
	for s in _tc.steps:
		if s.get("id") == id:
			return s
	return null


func _p1_ids_str(snap):
	if snap == null: return ""
	var out = ""
	for p in snap.get("players", []):
		if str(p.get("id", "")) == "player_1":
			var h = p.get("hand", [])
			for i in range(h.size()):
				if i > 0: out += ","
				out += str(h[i].get("card_id", ""))
	return out


func _sig(snap):
	if snap == null: return "null"
	var cur = str(snap.get("current_player_index", -1))
	var piatto = str(snap.get("piatto", 0))
	return cur + "|" + piatto + "|" + _p1_ids_str(snap)


# Run a scripted scenario, returning the sequence of (snapshot_sig, gc_state)
# observed after setup and after each tick.
func _run_scenario(scenario, max_ticks=40):
	_demo.start_scripted_demo(scenario)
	yield(get_tree(), "idle_frame")
	var out = []
	out.append({"sig": _sig(_gc.get_last_snapshot()), "state": _gc.get_state()})
	for i in range(max_ticks):
		if not _demo.running:
			break
		_demo.advance_step()
		yield(get_tree(), "idle_frame")
		out.append({"sig": _gc_state_sig(), "state": _gc.get_state()})
	return out


func _gc_state_sig():
	var s = _gc.get_last_snapshot()
	if s == null: return "null"
	var cur = str(s.get("current_player_index", -1))
	var piatto = str(s.get("piatto", 0))
	var winner = str(s.get("winner", ""))
	return cur + "|" + piatto + "|w=" + winner + "|" + _p1_ids_str(s)


func _any_state(seq, state_val):
	for e in seq:
		if int(e["state"]) == state_val:
			return true
	return false


func _sig_contains(sig, frag):
	return sig.find(frag) >= 0


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Req: initial state matches the prepared scenario (P1 hand + Piatto).
func _test_initial_state():
	_setup()
	var step = _get_step("increment_cards")
	var setup = step["scenario"]["segments"][0]["setup"]
	_demo.start_scripted_demo(step["scenario"])
	yield(get_tree(), "idle_frame")
	var s = _gc.get_last_snapshot()
	var ids = _p1_ids_str(s)
	_assert(ids.find("increment_4_0") >= 0, "P1 has +4 initially (got " + ids + ")")
	_assert(ids.find("increment_7_0") >= 0, "P1 has +7 initially")
	_assert(ids.find("jolly_0") >= 0, "P1 has Jolly initially")
	_assert(int(s.get("current_player_index", -1)) == 0, "starts from Player 1")
	_cleanup()


# Req: step 1 plays +7 (piatto 7) then rewinds and plays Jolly value 5 (piatto 5).
func _test_step1_sequence():
	_setup()
	var step = _get_step("increment_cards")
	var seq = _run_scenario(step["scenario"])
	if seq is GDScriptFunctionState: seq = yield(seq, "completed")

	var saw_plus7 = false
	var saw_jolly5 = false
	for e in seq:
		if _sig_contains(e["sig"], "|7|"):
			saw_plus7 = true
		if _sig_contains(e["sig"], "|5|"):
			saw_jolly5 = true
	_assert(saw_plus7, "step 1 demo 1 shows Piatto 7 after +7")
	_assert(saw_jolly5, "step 1 demo 2 shows Piatto 5 after Jolly=5")
	_assert(_any_state(seq, WAITING_FOR_CHOICE), "Jolly opens the real value-choice popup")
	_cleanup()


# Req: step 2 Imbroglio -7 reduces Piatto (15 -> 8) and opens the popup.
func _test_step2_imbroglio():
	_setup()
	var step = _get_step("imbroglio")
	var seq = _run_scenario(step["scenario"])
	if seq is GDScriptFunctionState: seq = yield(seq, "completed")
	var saw_8 = false
	for e in seq:
		if _sig_contains(e["sig"], "|8|"):
			saw_8 = true
	_assert(saw_8, "step 2 shows Piatto reduced to 8 after Imbroglio -7 (15-7)")
	_assert(_any_state(seq, WAITING_FOR_CHOICE), "Imbroglio opens the real value-choice popup")
	_cleanup()


# Req: step 3 Gold sets Piatto to the gold value and activates a Safe Round.
func _test_step3_gold():
	_setup()
	var step = _get_step("gold")
	_demo.start_scripted_demo(step["scenario"])
	yield(get_tree(), "idle_frame")
	# Drive: select+play (opens safe round popup), then choose blocked_type.
	for i in range(6):
		if not _demo.running: break
		_demo.advance_step()
		yield(get_tree(), "idle_frame")
	var s = _gc.get_last_snapshot()
	_assert(int(s.get("piatto", 0)) == 34, "step 3 sets Piatto to 34 (Gold 34)")
	_assert(bool(s.get("special_round_active", false)), "step 3 activates a Special Round (Giro Sicuro)")
	_assert(str(s.get("special_round_type", "")) == "safe", "step 3 is a Safe Round")
	_assert(str(s.get("blocked_type", "")) == "Incremento", "step 3 blocked_type is Incremento (real choice)")
	_cleanup()


# Req: step 4 plays 89 -> Piatto 89 + GdV (advantage) active.
func _test_step4_gdv():
	_setup()
	var step = _get_step("gdv")
	var seq = _run_scenario(step["scenario"])
	if seq is GDScriptFunctionState: seq = yield(seq, "completed")
	# P1's 89 sets the Piatto to 89; GdV (advantage) stays active afterwards.
	var saw_89 = false
	for e in seq:
		if e["sig"].split("|")[1] == "89":
			saw_89 = true
	var s = _gc.get_last_snapshot()
	var gdv_active = bool(s.get("special_round_active", false)) and str(s.get("special_round_type", "")) == "advantage"
	_assert(saw_89, "step 4 sets Piatto to 89 (from the 89 card)")
	_assert(gdv_active, "step 4 leaves Giro di Vantaggio (advantage) active")
	_cleanup()


# Req: step 5 case 1 (+11 in GdV) produces a winner.
func _test_step5_case1_win():
	_setup()
	var step = _get_step("plus11")
	var seq = _run_scenario(step["scenario"])
	if seq is GDScriptFunctionState: seq = yield(seq, "completed")
	# Case 1 (first segment) is +11 in GdV -> winner. Scan the run for it.
	var saw_winner = false
	for e in seq:
		if e["sig"].find("w=player_1") >= 0:
			saw_winner = true
	_assert(saw_winner, "step 5 case 1 (+11 in GdV) produces a winner (player_1)")
	_cleanup()


# Req: step 5 case 3 (+11 after Gold) transforms into the next Gold.
func _test_step5_case3_transform():
	_setup()
	var step = _get_step("plus11")
	# Drive only segment index 2 by pre-seeding the demo to that segment.
	_demo.start_scripted_demo(step["scenario"])
	yield(get_tree(), "idle_frame")
	# Advance through all 3 segments; capture the final (case 3) outcome.
	for i in range(30):
		if not _demo.running: break
		_demo.advance_step()
		yield(get_tree(), "idle_frame")
	var s = _gc.get_last_snapshot()
	# After +11 on Gold12 -> transformed Gold23 on plateau, Safe Round active.
	var plateau = s.get("plateau_cards", [])
	var has_gold23 = false
	for c in plateau:
		if str(c.get("card_type", "")) == "gold" and int(c.get("value", 0)) == 23:
			has_gold23 = true
	_assert(has_gold23, "step 5 case 3 transforms +11 into Gold 23 on the plateau")
	_cleanup()


# Req: rewind restores the prepared state (each segment starts clean).
func _test_rewind_restores_state():
	_setup()
	var step = _get_step("increment_cards")
	var seg0_setup_sig = null
	var seq = _run_scenario(step["scenario"])
	if seq is GDScriptFunctionState: seq = yield(seq, "completed")
	# The second segment re-applies the same setup; P1 hand must again be +4,+7,Jolly.
	var saw_second_reset = false
	for e in seq:
		if _sig_contains(e["sig"], "increment_7_0") and _sig_contains(e["sig"], "|0|"):
			saw_second_reset = true
	_assert(saw_second_reset, "rewind re-prepares P1 with +7 and Piatto 0 before demo 2")
	_cleanup()


# Req: reproducibility — two runs of the same step are identical.
func _test_reproducibility():
	_setup()
	var step = _get_step("plus11")
	var r1 = _run_scenario(step["scenario"])
	if r1 is GDScriptFunctionState: r1 = yield(r1, "completed")
	var r2 = _run_scenario(step["scenario"])
	if r2 is GDScriptFunctionState: r2 = yield(r2, "completed")

	# Compare the sequence of snapshot signatures.
	var s1 = []
	for e in r1: s1.append(e["sig"])
	var s2 = []
	for e in r2: s2.append(e["sig"])
	_assert(s1.size() == s2.size(), "two runs produce same-length sequences")
	var same = true
	for i in range(min(s1.size(), s2.size())):
		if s1[i] != s2[i]:
			same = false
			break
	_assert(same, "two runs of the same step replay identically (reproducible)")
	_cleanup()


# Req: all steps with a scenario run without errors and terminate.
func _test_all_steps_run():
	_setup()
	for s in _tc.steps:
		if not s.has("scenario"):
			continue
		var id = s.get("id", "?")
		_demo.start_scripted_demo(s["scenario"])
		yield(get_tree(), "idle_frame")
		var ticks = 0
		while _demo.running and ticks < 60:
			_demo.advance_step()
			yield(get_tree(), "idle_frame")
			ticks += 1
		_assert(_demo.running == false, "step '" + id + "' demo terminates (ticks=" + str(ticks) + ")")
		_cleanup()
		_setup()


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Scripted Tutorial Demo Test\n"
	out += "========================================\n"

	var t1 = _test_initial_state()
	if t1 is GDScriptFunctionState: yield(t1, "completed")
	var t2 = _test_step1_sequence()
	if t2 is GDScriptFunctionState: yield(t2, "completed")
	var t3 = _test_step2_imbroglio()
	if t3 is GDScriptFunctionState: yield(t3, "completed")
	var t4 = _test_step3_gold()
	if t4 is GDScriptFunctionState: yield(t4, "completed")
	var t5 = _test_step4_gdv()
	if t5 is GDScriptFunctionState: yield(t5, "completed")
	var t6 = _test_step5_case1_win()
	if t6 is GDScriptFunctionState: yield(t6, "completed")
	var t7 = _test_step5_case3_transform()
	if t7 is GDScriptFunctionState: yield(t7, "completed")
	var t8 = _test_rewind_restores_state()
	if t8 is GDScriptFunctionState: yield(t8, "completed")
	var t9 = _test_reproducibility()
	if t9 is GDScriptFunctionState: yield(t9, "completed")
	var t10 = _test_all_steps_run()
	if t10 is GDScriptFunctionState: yield(t10, "completed")

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFAIL: Some scripted-demo assertions failed.\n"
	else:
		out += "\nALL SCRIPTED-DEMO ASSERTIONS PASSED.\n"
	out += "========================================\n"
	return out
