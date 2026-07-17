extends Node

# Tests for Passaggio C — GameStateProvider + LocalGameEngine.
# Covers: start_game, snapshot, actions, events, event order for all card types.
# Run: ./Godot3 --path /path/to/project tests/provider_test.tscn --no-window

var _LocalGameEngine
var _CardData
var _CardDatabase

var passed = 0
var failed = 0
var failure_msgs = []

func _ready():
	_LocalGameEngine = load("res://engine/LocalGameEngine.gd")
	_CardData = load("res://engine/CardData.gd")
	_CardDatabase = load("res://engine/CardDatabase.gd")
	randomize()
	var out = _run_all()
	print(out)
	get_tree().quit(0)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		failure_msgs.append(msg)
	return cond


# ===========================================================================
# Helpers
# ===========================================================================

func _new_engine():
	return _LocalGameEngine.new()

func _card(card_id, name, value, color, metadata):
	return _CardData.new(card_id, name, value, color, metadata)

func _has_no_references(data):
	if data == null: return true
	var t = typeof(data)
	if t == TYPE_DICTIONARY:
		for k in data.keys():
			if typeof(k) != TYPE_STRING: return false
			if !_has_no_references(data[k]): return false
		return true
	elif t == TYPE_ARRAY:
		for v in data:
			if !_has_no_references(v): return false
		return true
	elif t in [TYPE_STRING, TYPE_INT, TYPE_REAL, TYPE_BOOL, TYPE_NIL]:
		return true
	return false


# Signal captures
var _last_snapshot = null
var _last_action_result = null
var _last_rejected = null

func _capture_snapshot(snapshot):
	_last_snapshot = snapshot

func _capture_result(result):
	_last_action_result = result

func _capture_rejected(msg):
	_last_rejected = msg

func _start_and_connect(engine):
	engine.connect("game_started", self, "_capture_snapshot")
	engine.connect("action_completed", self, "_capture_result")
	engine.connect("action_rejected", self, "_capture_rejected")
	engine.start_game(2)

func _playable_card_id(snapshot):
	for a in snapshot["available_actions"]:
		if a["action_type"] == "play_card" and a.has("card_id"):
			return a["card_id"]
	return null


# ===========================================================================
# Runner
# ===========================================================================

func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Provider Port Diagnostic\n"
	out += "========================================\n"

	# --- Existing tests (10) ---
	out += _test_start_game_2p()
	out += _test_start_game_3p()
	out += _test_start_game_4p()
	out += _test_snapshot_format()
	out += _test_snapshot_no_references()
	out += _test_available_actions_in_snapshot()
	out += _test_card_id_resolution()
	out += _test_invalid_action_rejected()
	out += _test_action_completed_format()
	out += _test_play_card_events_basic()
	out += _test_change_card_events()

	# --- New event order tests (5) ---
	out += _test_plus11_in_gdv_order()
	out += _test_89_triggers_advantage_order()
	out += _test_gold_reveal_order()
	out += _test_reset_hand_order()
	out += _test_gdv_ends_order()

	# --- Plateau visual stack tests (4) ---
	out += _test_visual_stack_seq_A()
	out += _test_visual_stack_seq_B()
	out += _test_visual_stack_seq_C()
	out += _test_visual_stack_seq_D()

	out += "\n--- Summary ---\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFailures:\n"
		for m in failure_msgs:
			out += "  - " + m + "\n"
	out += "\n========================================\n"
	return out


# ===========================================================================
# 1. start_game — 2, 3, 4 players
# ===========================================================================

func _test_start_game_2p():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(2)
	var s = _last_snapshot
	var ok1 = _assert(s["players"][0]["hand"].size() == 3, "2p hand")
	var ok2 = _assert(s["deck_count"] == 54, "2p deck " + str(s["deck_count"]))
	var ok3 = _assert(s["piatto"] == 0, "2p piatto")
	return "  Start game 2p:         " + ("[PASS]\n" if (ok1 and ok2 and ok3) else "[FAIL]\n")

func _test_start_game_3p():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(3)
	var s = _last_snapshot
	var ok1 = _assert(s["players"][0]["hand"].size() == 3, "3p hand")
	var ok2 = _assert(s["deck_count"] == 51, "3p deck " + str(s["deck_count"]))
	return "  Start game 3p:         " + ("[PASS]\n" if (ok1 and ok2) else "[FAIL]\n")

func _test_start_game_4p():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(4)
	var s = _last_snapshot
	var ok1 = _assert(s["players"][0]["hand"].size() == 3, "4p hand")
	var ok2 = _assert(s["deck_count"] == 48, "4p deck " + str(s["deck_count"]))
	return "  Start game 4p:         " + ("[PASS]\n" if (ok1 and ok2) else "[FAIL]\n")


# ===========================================================================
# 2. Snapshot format
# ===========================================================================

func _test_snapshot_format():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(2)
	var s = _last_snapshot
	var keys = ["players","current_player_index","piatto","deck_count","discard_top",
		"plateau_cards","plateau_visual_stack","advantage_turn","advantage_player_id",
		"winner","turn_number","available_actions","phase","local_player_id"]
	var all_ok = true
	for k in keys:
		if !s.has(k):
			_assert(false, "missing key: " + k)
			all_ok = false
	if all_ok: _assert(true, "all keys present")
	var p2 = _assert(s["phase"] == "playing", "phase " + str(s["phase"]))
	var t2 = _assert(s["turn_number"] == 0, "turn " + str(s["turn_number"]))
	var w2 = _assert(s["winner"] == null, "winner " + str(s["winner"]))
	# Verify plateau_visual_stack format
	var vs = s["plateau_visual_stack"]
	var vs_ok = _assert(typeof(vs) == TYPE_ARRAY, "visual_stack array")
	if vs.size() > 0:
		var first = vs[0]
		_assert(typeof(first) == TYPE_DICTIONARY, "visual_stack item dict")
		_assert(first.has("type"), "visual_stack item has type")
		if first.get("type") == "plate":
			_assert(first.has("value"), "plate item has value")
	return "  Snapshot format:       " + ("[PASS]\n" if (all_ok and p2 and t2 and w2 and vs_ok) else "[FAIL]\n")


# ===========================================================================
# 3. No Reference objects
# ===========================================================================

func _test_snapshot_no_references():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(2)
	var ok = _assert(_has_no_references(_last_snapshot), "snapshot has refs")
	return "  Snapshot no refs:      " + ("[PASS]\n" if ok else "[FAIL]\n")


# ===========================================================================
# 4. Available actions format
# ===========================================================================

func _test_available_actions_in_snapshot():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(2)
	var acts = _last_snapshot["available_actions"]
	var c_ok = _assert(acts.size() > 0, "action count " + str(acts.size()))
	var f_ok = true
	for a in acts:
		if !a.has("action_type"): f_ok = false; break
		if a["action_type"] != "reset_hand" and !a.has("card_id") and !a.has("choices"):
			f_ok = false; break
		if a.has("choices"):
			for ch in a["choices"]:
				if !ch.has("label") or !ch.has("parameters"):
					f_ok = false; break
	if f_ok: _assert(true, "action format ok")
	return "  Available actions:     " + ("[PASS]\n" if (c_ok and f_ok) else "[FAIL]\n")


# ===========================================================================
# 5. card_id resolution
# ===========================================================================

func _test_card_id_resolution():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(2)
	var cid = _last_snapshot["players"][0]["hand"][0]["card_id"]
	var r1 = e._resolve_card(cid)
	var ok1 = _assert(r1 != null, "resolve " + cid)
	var ok2 = _assert(r1.card_id == cid, "id match")
	var r2 = e._resolve_card("nonexistent")
	var ok3 = _assert(r2 == null, "nonexistent null")
	return "  Card ID resolution:    " + ("[PASS]\n" if (ok1 and ok2 and ok3) else "[FAIL]\n")


# ===========================================================================
# 6. Invalid action rejection
# ===========================================================================

func _test_invalid_action_rejected():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_rejected", self, "_capture_rejected")
	e.start_game(2)
	_last_rejected = null
	e.send_action({"action_type": "play_card", "card_id": "xx"})
	var r1 = _assert(_last_rejected != null, "bad card rejected")
	var ps = e._build_snapshot()
	var r2 = _assert(ps["piatto"] == 0, "piatto unchanged")
	_last_rejected = null
	e.send_action({})
	var r3 = _assert(_last_rejected != null, "empty rejected")
	return "  Invalid action reject: " + ("[PASS]\n" if (r1 and r2 and r3) else "[FAIL]\n")


# ===========================================================================
# 7. action_completed format
# ===========================================================================

func _test_action_completed_format():
	var e = _new_engine()
	_start_and_connect(e)
	var cid = _playable_card_id(_last_snapshot)
	if cid == null: return "  Action completed fmt:  [SKIP]\n"

	# Verify card resolves before sending
	var resolved = e._resolve_card(cid)
	if resolved == null: return "  Action completed fmt:  [FAIL - card " + cid + " not found]\n"

	_last_action_result = null
	_last_rejected = null
	e.send_action({"action_type": "play_card", "card_id": cid})
	if _last_action_result == null:
		if _last_rejected != null:
			return "  Action completed fmt:  [FAIL - rejected: " + str(_last_rejected) + "]\n"
		return "  Action completed fmt:  [FAIL - no result, no rejection]\n"
	var r = _last_action_result
	var o1 = _assert(r.has("snapshot"), "has snapshot")
	var o2 = _assert(r.has("events"), "has events")
	var o3 = _assert(typeof(r["events"]) == TYPE_ARRAY, "events array")
	var o4 = _assert(r["events"].size() >= 3, "events >= 3")
	var o5 = _assert(r["events"][0].get("type","") == "card_played", "first card_played")

	# Reset globals for next test
	_last_action_result = null
	_last_rejected = null
	return "  Action completed fmt:  " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5) else "[FAIL]\n")


# ===========================================================================
# 8. Basic play card events (normal increment)
# ===========================================================================

func _test_play_card_events_basic():
	var e = _new_engine()
	_start_and_connect(e)
	var cid = _playable_card_id(_last_snapshot)
	if cid == null: return "  Play card basic:       [SKIP]\n"
	e.send_action({"action_type": "play_card", "card_id": cid})
	if _last_action_result == null: return "  Play card basic:       [FAIL]\n"

	var ev = _last_action_result["events"]
	var snap = _last_action_result["snapshot"]
	var types = []; for x in ev: types.append(x["type"])

	var o1 = _assert(types[0] == "card_played", "first " + types[0])
	var o2 = _assert("card_drawn" in types, "has card_drawn")
	var o3 = _assert("turn_changed" in types, "has turn_changed")

	# Order: card_played < card_drawn < turn_changed
	var ip = types.find("card_played")
	var idr = types.find("card_drawn")
	var it = types.find("turn_changed")
	var o4 = _assert(ip < idr, "played before drawn")
	var o5 = _assert(idr < it, "drawn before turn")

	# Coherence
	var coh = true
	for x in ev:
		if x["type"] == "piatto_changed":
			coh = coh and _assert(x["new_value"] == snap["piatto"], "piatto coher")
		if x["type"] == "turn_changed":
			coh = coh and _assert(x["turn_number"] == snap["turn_number"], "turn coher")
	return "  Play card basic:       " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and coh) else "[FAIL]\n")


# ===========================================================================
# 9. Change card events
# ===========================================================================

func _test_change_card_events():
	var e = _new_engine()
	_start_and_connect(e)
	var s = _last_snapshot
	var cid = null
	for a in s["available_actions"]:
		if a["action_type"] == "change_card" and a.has("card_id"):
			cid = a["card_id"]; break
	if cid == null: return "  Change card:           [SKIP]\n"
	e.send_action({"action_type": "change_card", "card_id": cid})
	if _last_action_result == null: return "  Change card:           [FAIL]\n"
	var types = []; for x in _last_action_result["events"]: types.append(x["type"])
	var o1 = _assert(types[0] == "card_changed", "first " + types[0])
	var o2 = _assert("card_drawn" in types, "has card_drawn")
	return "  Change card:           " + ("[PASS]\n" if (o1 and o2) else "[FAIL]\n")


# ===========================================================================
# 10. +11 in GdV: card_played → game_won → piatto_changed → card_drawn → turn_changed
# ===========================================================================

func _test_plus11_in_gdv_order():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_completed", self, "_capture_result")
	e.start_game(1)  # single player
	var gs = e.game_state
	var cp = gs.current_player()

	# Give player a +11 card (clear hand first)
	cp.clear_hand()
	var p11 = _card("plus11_test", "+11", 11, "rosso",
		{"card_type": "special", "category": "speciale", "destination": "scarti"})
	cp.receive_card(p11)

	# Set GdV state
	gs.metadata["advantage_turn"] = true
	gs.metadata["advantage_player_id"] = "player_1"
	gs.metadata["turn_phase"] = "start"
	gs.metadata["piatto"] = 50

	# Also give a deck card so draw works
	var inc = _card("inc_test", "+1", 1, "arancione",
		{"card_type": "increment", "category": "normale", "destination": "scarti"})
	gs.deck.add_card(inc)

	_last_action_result = null
	e.send_action({"action_type": "play_card", "card_id": "plus11_test"})
	if _last_action_result == null: return "  +11 GdV order:         [FAIL - no result]\n"

	var types = []; for x in _last_action_result["events"]: types.append(x["type"])
	var expected = ["card_played", "game_won", "piatto_changed", "card_drawn", "turn_changed"]
	var all_ok = true

	# Check each type appears and in the right relative order
	var ip = types.find("card_played")
	var iw = types.find("game_won")
	var ipc = types.find("piatto_changed")
	var id = types.find("card_drawn")
	var it = types.find("turn_changed")

	var o1 = _assert(ip >= 0, "+11 has card_played")
	var o2 = _assert(iw >= 0, "+11 has game_won")
	var o3 = _assert(ipc >= 0, "+11 has piatto_changed")
	var o4 = _assert(id >= 0, "+11 has card_drawn")
	var o5 = _assert(it >= 0, "+11 has turn_changed")

	# game_won BEFORE piatto_changed
	var o6 = _assert(iw < ipc, "game_won before piatto: idx " + str(iw) + " < " + str(ipc))
	# card_played first, turn_changed last
	var o7 = _assert(ip == 0, "card_played first: idx " + str(ip))
	var o8 = _assert(it > id, "turn_changed after drawn: idx " + str(it) + " > " + str(id))

	return "  +11 GdV order:         " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6 and o7 and o8) else "[FAIL] order: " + str(types) + "\n")


# ===========================================================================
# 11. 89 triggers GdV: card_played → advantage_started → piatto_changed → card_drawn → turn_changed
# ===========================================================================

func _test_89_triggers_advantage_order():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_completed", self, "_capture_result")
	e.start_game(1)
	var gs = e.game_state
	var cp = gs.current_player()

	cp.clear_hand()
	var c89 = _card("card89_test", "89", 89, "viola",
		{"card_type": "special", "category": "speciale", "destination": "piatto"})
	cp.receive_card(c89)
	gs.metadata["piatto"] = 50
	gs.metadata["turn_phase"] = "start"
	gs.deck.add_card(_card("deck1", "+1", 1, "arancione", {"card_type": "increment"}))

	_last_action_result = null
	e.send_action({"action_type": "play_card", "card_id": "card89_test"})
	if _last_action_result == null: return "  89 order:              [FAIL - no result]\n"

	var types = []; for x in _last_action_result["events"]: types.append(x["type"])
	var ip = types.find("card_played")
	var ia = types.find("advantage_started")
	var ipc = types.find("piatto_changed")
	var id = types.find("card_drawn")

	var o1 = _assert(ip >= 0, "89 has card_played")
	var o2 = _assert(ia >= 0, "89 has advantage_started")
	var o3 = _assert(ipc >= 0, "89 has piatto_changed")
	var o4 = _assert(id >= 0, "89 has card_drawn")
	var o5 = _assert(id > ipc, "drawn after piatto: " + str(id) + " > " + str(ipc))

	# advantage_started before piatto_changed (89 sets advantage during increment calc)
	var o6 = _assert(ia < ipc, "advantage before piatto: " + str(ia) + " < " + str(ipc))

	return "  89 order:              " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6) else "[FAIL] order: " + str(types) + "\n")


# ===========================================================================
# 12. Gold reveal: gold_revealed → card_drawn → turn_changed
# ===========================================================================

func _test_gold_reveal_order():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_completed", self, "_capture_result")
	e.start_game(1)
	var gs = e.game_state
	var cp = gs.current_player()

	# Give a gold card matching piatto value
	cp.clear_hand()
	var gold = _card("gold_test_12", "12", 12, "dorato",
		{"card_type": "gold", "category": "gold", "destination": "piatto"})
	cp.receive_card(gold)
	gs.metadata["piatto"] = 12
	gs.metadata["turn_phase"] = "start"
	gs.deck.add_card(_card("deck1", "+1", 1, "arancione", {"card_type": "increment"}))

	_last_action_result = null
	e.send_action({"action_type": "reveal_gold", "card_id": "gold_test_12"})
	if _last_action_result == null: return "  Gold reveal order:     [FAIL - no result]\n"

	var types = []; for x in _last_action_result["events"]: types.append(x["type"])
	var o1 = _assert(types[0] == "gold_revealed", "first gold_revealed: " + types[0])
	var o2 = _assert("card_drawn" in types, "has card_drawn")
	var o3 = _assert("turn_changed" in types, "has turn_changed")
	var id = types.find("card_drawn")
	var it = types.find("turn_changed")
	var o4 = _assert(id < it, "drawn before turn: " + str(id) + " < " + str(it))

	return "  Gold reveal order:     " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL] order: " + str(types) + "\n")


# ===========================================================================
# 13. Reset hand: hand_reset → card_drawn ×3 → turn_changed
# ===========================================================================

func _test_reset_hand_order():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_completed", self, "_capture_result")
	e.start_game(1)
	var gs = e.game_state
	var cp = gs.current_player()

	# Give a non-orange card (gold) so player has no playable orange during GdV
	cp.clear_hand()
	var gold = _card("gold_test_23", "23", 23, "dorato",
		{"card_type": "gold", "category": "gold", "destination": "piatto"})
	cp.receive_card(gold)

	# Set GdV active for another player so RESET_HAND is the only option
	gs.metadata["advantage_turn"] = true
	gs.metadata["advantage_player_id"] = "some_other_player"
	gs.metadata["turn_phase"] = "start"
	gs.metadata["piatto"] = 30

	# Give 3 deck cards for the reset draw
	for i in range(3):
		gs.deck.add_card(_card("deck" + str(i), "+1", 1, "arancione", {"card_type": "increment"}))

	_last_action_result = null
	e.send_action({"action_type": "reset_hand"})
	if _last_action_result == null: return "  Reset hand order:      [FAIL - no result]\n"

	var types = []; for x in _last_action_result["events"]: types.append(x["type"])
	var o1 = _assert(types[0] == "hand_reset", "first hand_reset: " + types[0])

	# Count card_drawn events
	var drawn_count = 0
	for t in types:
		if t == "card_drawn": drawn_count += 1
	var o2 = _assert(drawn_count == 3, "3 card_drawn, got " + str(drawn_count))
	var o3 = _assert("turn_changed" in types, "has turn_changed")

	# All card_drawn before turn_changed
	var first_drawn = types.find("card_drawn")
	var last_drawn = types.find_last("card_drawn")
	var turn_idx = types.find("turn_changed")
	var o4 = _assert(last_drawn < turn_idx, "drawn before turn: " + str(last_drawn) + " < " + str(turn_idx))

	return "  Reset hand order:      " + ("[PASS]\n" if (o1 and o2 and o3 and o4) else "[FAIL] order: " + str(types) + "\n")


# ===========================================================================
# 14. GdV ends: turn_changed with advantage_ended after the advantage
#     player's NEXT turn completes
# ===========================================================================

func _test_gdv_ends_order():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.connect("action_completed", self, "_capture_result")
	e.start_game(2)
	var gs = e.game_state

	# Set up: GdV active for player_1, it's P1's NEXT turn so _advantage_turn_done
	# should be true. When advance_turn runs, GdV will end.
	var p1 = gs.players[0]
	var p2 = gs.players[1]

	# Give both players a simple card
	p1.clear_hand()
	p2.clear_hand()
	var inc1 = _card("p1card", "+1", 1, "arancione", {"card_type": "increment"})
	var inc2 = _card("p2card", "+1", 1, "arancione", {"card_type": "increment"})
	p1.receive_card(inc1)
	p2.receive_card(inc2)

	# Ensure enough deck
	for i in range(5):
		gs.deck.add_card(_card("d" + str(i), "+1", 1, "arancione", {"card_type": "increment"}))

	# Set GdV: active, P1 is advantage player, it's P1's turn, _advantage_turn_done = true
	gs.current_player_index = 0
	gs.set_current_player(p1)
	gs.metadata["advantage_turn"] = true
	gs.metadata["advantage_player_id"] = "player_1"
	gs.metadata["_advantage_turn_done"] = true
	gs.metadata["turn_phase"] = "start"
	gs.metadata["piatto"] = 50
	gs.turn_number = 5

	_last_action_result = null
	# P1 plays a card → advance_turn sees _advantage_turn_done = true → GdV ends
	e.send_action({"action_type": "play_card", "card_id": "p1card"})
	if _last_action_result == null: return "  GdV ends order:        [FAIL - no result]\n"

	var types = []; for x in _last_action_result["events"]: types.append(x["type"])

	var o1 = _assert("advantage_ended" in types, "has advantage_ended")
	var o2 = _assert("turn_changed" in types, "has turn_changed")

	# advantage_ended after turn_changed (or at least in the events)
	var ia = types.find("advantage_ended")
	var it = types.find("turn_changed")
	var o3 = _assert(it < ia, "turn_changed before advantage_ended: " + str(it) + " < " + str(ia))

	# GdV must be false in snapshot
	var snap = _last_action_result["snapshot"]
	var o4 = _assert(snap["advantage_turn"] == false, "advantage_turn false in snapshot")
	var o5 = _assert(snap["advantage_player_id"] == null, "advantage_player_id null")

	return "  GdV ends order:        " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5) else "[FAIL] order: " + str(types) + "\n")


# ===========================================================================
# 15. Plateau visual stack — Sequence A: non-Gold, Gold
#     Expected: [plate(0), card(gold)]  (Gold at top, no redundant plate)
# ===========================================================================

func _test_visual_stack_seq_A():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(1)
	var gs = e.game_state

	var inc = _card("inc_5", "+5", 5, "arancione", {"card_type": "increment"})
	var gold = _card("g_23", "23", 23, "dorato", {"card_type": "gold"})

	gs.metadata["plateau_cards"] = [inc, gold]
	gs.metadata["piatto"] = 23

	var snap = e._build_snapshot()
	var vs = snap.get("plateau_visual_stack", [])

	var o1 = _assert(vs.size() == 2, "A: size 2, got " + str(vs.size()))
	var o2 = _assert(vs[0]["type"] == "plate", "A: [0] type plate")
	var o3 = _assert(vs[0]["value"] == 0, "A: [0] value 0, got " + str(vs[0]["value"]))
	var o4 = _assert(vs[1]["type"] == "card", "A: [1] type card")
	var o5 = _assert(vs[1]["card"]["card_id"] == "g_23", "A: [1] card_id g_23")

	# Gold must be the last element (no plate on top)
	var o6 = _assert(vs[vs.size()-1]["type"] == "card", "A: last is card (gold at top)")

	return "  VS seq A:              " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6) else "[FAIL]\n")


# ===========================================================================
# 16. Plateau visual stack — Sequence B: non-Gold, Gold, non-Gold
#     Expected: [plate(0), card(gold), plate(new_value)]
#     Non-gold original card NOT in stack (only in discard).
# ===========================================================================

func _test_visual_stack_seq_B():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(1)
	var gs = e.game_state

	var inc_a = _card("inc_5", "+5", 5, "arancione", {"card_type": "increment"})
	var gold = _card("g_23", "23", 23, "dorato", {"card_type": "gold"})
	var inc_b = _card("inc_3", "+3", 3, "arancione", {"card_type": "increment"})

	gs.metadata["plateau_cards"] = [inc_a, gold, inc_b]
	gs.metadata["piatto"] = 26  # 23 + 3

	var snap = e._build_snapshot()
	var vs = snap.get("plateau_visual_stack", [])

	var o1 = _assert(vs.size() == 3, "B: size 3, got " + str(vs.size()))
	var o2 = _assert(vs[0]["type"] == "plate", "B: [0] type plate")
	var o3 = _assert(vs[0]["value"] == 0, "B: [0] value 0")
	var o4 = _assert(vs[1]["type"] == "card", "B: [1] type card")
	var o5 = _assert(vs[1]["card"]["card_id"] == "g_23", "B: [1] card_id g_23")
	var o6 = _assert(vs[2]["type"] == "plate", "B: [2] type plate")
	var o7 = _assert(vs[2]["value"] == 26, "B: [2] value 26, got " + str(vs[2]["value"]))

	# Last is plate (new value on top)
	var o8 = _assert(vs[vs.size()-1]["type"] == "plate", "B: last is plate")

	# Non-Gold original cards NOT in stack
	var non_gold_in_stack = false
	for item in vs:
		if item["type"] == "card":
			var cid = item["card"]["card_id"]
			if cid == "inc_5" or cid == "inc_3":
				non_gold_in_stack = true
				break
	var o9 = _assert(!non_gold_in_stack, "B: no non-gold card in stack")

	return "  VS seq B:              " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6 and o7 and o8 and o9) else "[FAIL]\n")


# ===========================================================================
# 17. Plateau visual stack — Sequence C: non-Gold, Gold, non-Gold, Gold
#     Expected: [plate(0), card(gold1), plate(val), card(gold2)]
#     Second Gold must be the last element (top of stack).
# ===========================================================================

func _test_visual_stack_seq_C():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(1)
	var gs = e.game_state

	var inc_a = _card("inc_5", "+5", 5, "arancione", {"card_type": "increment"})
	var gold_a = _card("g_23", "23", 23, "dorato", {"card_type": "gold"})
	var inc_b = _card("inc_3", "+3", 3, "arancione", {"card_type": "increment"})
	var gold_b = _card("g_34", "34", 34, "dorato", {"card_type": "gold"})

	gs.metadata["plateau_cards"] = [inc_a, gold_a, inc_b, gold_b]
	gs.metadata["piatto"] = 34

	var snap = e._build_snapshot()
	var vs = snap.get("plateau_visual_stack", [])

	var o1 = _assert(vs.size() == 4, "C: size 4, got " + str(vs.size()))
	var o2 = _assert(vs[0]["type"] == "plate", "C: [0] type plate")
	var o3 = _assert(vs[1]["type"] == "card", "C: [1] type card")
	var o4 = _assert(vs[1]["card"]["card_id"] == "g_23", "C: [1] card g_23")
	var o5 = _assert(vs[2]["type"] == "plate", "C: [2] type plate")
	var o6 = _assert(vs[2]["value"] == 26, "C: [2] value 26, got " + str(vs[2]["value"]))
	var o7 = _assert(vs[3]["type"] == "card", "C: [3] type card")
	var o8 = _assert(vs[3]["card"]["card_id"] == "g_34", "C: [3] card g_34")

	# Second Gold at top
	var o9 = _assert(vs[vs.size()-1]["type"] == "card", "C: last is card (gold at top)")
	var o10 = _assert(vs[vs.size()-1]["card"]["card_id"] == "g_34", "C: last card is g_34")

	return "  VS seq C:              " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6 and o7 and o8 and o9 and o10) else "[FAIL]\n")


# ===========================================================================
# 18. Plateau visual stack — Sequence D: non-Gold, Gold, non-Gold, Gold, non-Gold
#     Expected: [plate(0), card(gold1), plate(val1), card(gold2), plate(val2)]
#     Last plate must be at top with the correct final value.
# ===========================================================================

func _test_visual_stack_seq_D():
	var e = _new_engine()
	e.connect("game_started", self, "_capture_snapshot")
	e.start_game(1)
	var gs = e.game_state

	var inc_a = _card("inc_5", "+5", 5, "arancione", {"card_type": "increment"})
	var gold_a = _card("g_23", "23", 23, "dorato", {"card_type": "gold"})
	var inc_b = _card("inc_3", "+3", 3, "arancione", {"card_type": "increment"})
	var gold_b = _card("g_34", "34", 34, "dorato", {"card_type": "gold"})
	var inc_c = _card("inc_2", "+2", 2, "arancione", {"card_type": "increment"})

	gs.metadata["plateau_cards"] = [inc_a, gold_a, inc_b, gold_b, inc_c]
	gs.metadata["piatto"] = 36  # 34 + 2

	var snap = e._build_snapshot()
	var vs = snap.get("plateau_visual_stack", [])

	var o1 = _assert(vs.size() == 5, "D: size 5, got " + str(vs.size()))
	var o2 = _assert(vs[0]["type"] == "plate", "D: [0] type plate")
	var o3 = _assert(vs[0]["value"] == 0, "D: [0] value 0")
	var o4 = _assert(vs[1]["type"] == "card", "D: [1] type card")
	var o5 = _assert(vs[1]["card"]["card_id"] == "g_23", "D: [1] g_23")
	var o6 = _assert(vs[2]["type"] == "plate", "D: [2] type plate")
	var o7 = _assert(vs[2]["value"] == 26, "D: [2] value 26, got " + str(vs[2]["value"]))
	var o8 = _assert(vs[3]["type"] == "card", "D: [3] type card")
	var o9 = _assert(vs[3]["card"]["card_id"] == "g_34", "D: [3] g_34")
	var o10 = _assert(vs[4]["type"] == "plate", "D: [4] type plate")
	var o11 = _assert(vs[4]["value"] == 36, "D: [4] value 36, got " + str(vs[4]["value"]))

	# Last is plate with correct final value
	var o12 = _assert(vs[vs.size()-1]["type"] == "plate", "D: last is plate")
	var o13 = _assert(vs[vs.size()-1]["value"] == 36, "D: last value 36, got " + str(vs[vs.size()-1]["value"]))

	# Non-Gold original cards NOT in stack
	var non_gold_in_stack = false
	for item in vs:
		if item["type"] == "card":
			var cid = item["card"]["card_id"]
			if cid.begins_with("inc_"):
				non_gold_in_stack = true
				break
	var o14 = _assert(!non_gold_in_stack, "D: no non-gold card in stack")

	return "  VS seq D:              " + ("[PASS]\n" if (o1 and o2 and o3 and o4 and o5 and o6 and o7 and o8 and o9 and o10 and o11 and o12 and o13 and o14) else "[FAIL]\n")
