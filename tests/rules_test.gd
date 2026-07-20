extends Node

# Porting of test_roadto100_rules.py — 13 tests for RoadTo100 rules.
# Run: ./Godot3 --path /path/to/project tests/rules_test.tscn --no-window

var _CardData
var _Deck
var _Hand
var _PlayerData
var _GameState
var _RoadTo100Rules

var CardData
var Deck
var Hand
var PlayerData
var GameState
var Rules

# Counters
var passed = 0
var failed = 0
var failures = []

func _ready():
	_CardData = load("res://engine/CardData.gd")
	_Deck = load("res://engine/Deck.gd")
	_Hand = load("res://engine/Hand.gd")
	_PlayerData = load("res://engine/PlayerData.gd")
	_GameState = load("res://engine/GameState.gd")
	_RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")

	CardData = _CardData
	Deck = _Deck
	Hand = _Hand
	PlayerData = _PlayerData
	GameState = _GameState
	Rules = _RoadTo100Rules

	randomize()
	var out = _run_all()
	print(out)
	get_tree().quit(0)

# ---------------------------------------------------------------------------
# Card factory helpers (mirror Python test helpers)
# ---------------------------------------------------------------------------

func gold_card(value):
	return CardData.new("gold_" + str(value), str(value), value, "Gold",
		{"card_type": "gold", "category": "gold", "destination": "plate"})

func plus11_card(copy):
	return CardData.new("+11_" + str(copy), "+11", 11, "Red",
		{"card_type": "special", "category": "normal", "destination": "discard"})

func card89(copy):
	return CardData.new("89_" + str(copy), "89", 89, "Purple",
		{"card_type": "special", "category": "normal", "destination": "plate"})

func increment_card(value, copy):
	return CardData.new("+" + str(value) + "_" + str(copy), "+" + str(value), value, "Orange",
		{"card_type": "increment", "category": "normal", "destination": "discard"})

func jolly_card(copy):
	return CardData.new("jolly_" + str(copy), "Jolly", null, "Orange",
		{"card_type": "jolly", "category": "normal", "destination": "discard"})

func imbroglio_card(copy):
	return CardData.new("imbroglio_" + str(copy), "Imbroglio", 0, "Green",
		{"card_type": "imbroglio", "category": "normal", "destination": "discard"})

# ---------------------------------------------------------------------------
# Game factory helper (mirrors Python make_game)
# ---------------------------------------------------------------------------

func make_game(players, deck_cards, discard = null, metadata = null):
	var g = GameState.new(
		players,
		Deck.new(deck_cards.duplicate()),
		discard.duplicate() if discard != null else [],
		0,  # current_player_index
		0,  # turn_number
		1,  # phase = PLAYING
		null,  # winner
		metadata.duplicate(true) if metadata != null else {}
	)
	g.set_current_player(players[0])
	return g

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

func _assert_eq(got, expected, test_name, context):
	if got == expected:
		passed += 1
		return true
	else:
		failed += 1
		failures.append(test_name + ": expected " + str(expected) + ", got " + str(got) + " (" + context + ")")
		return false

func _assert_true(cond, test_name, msg):
	if cond:
		passed += 1
		return true
	else:
		failed += 1
		failures.append(test_name + ": " + msg)
		return false

func _test(name):
	passed += 1

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Rules Port Diagnostic\n"
	out += "========================================\n"

	# Track test count (13 Python tests)
	var total_tests = 13
	var tests_run = 0

	# --- TestGoldChain (7 chain tests + 1 GdV trigger) ---
	out += _test_gold_chain_12()
	tests_run += 1
	out += _test_gold_chain_23()
	tests_run += 1
	out += _test_gold_chain_34()
	tests_run += 1
	out += _test_gold_chain_45()
	tests_run += 1
	out += _test_gold_chain_56()
	tests_run += 1
	out += _test_gold_chain_67()
	tests_run += 1
	out += _test_gold_chain_78()
	tests_run += 1
	out += _test_gold_chain_78_triggers_gdv()
	tests_run += 1

	# --- TestGdvLifecycle ---
	out += _test_gdv_lifecycle()
	tests_run += 1

	# --- TestCard89NotPlayableDuringGdv ---
	out += _test_89_not_playable_during_gdv()
	tests_run += 1

	# --- TestPlus11DuringGdv ---
	out += _test_plus11_during_gdv()
	tests_run += 1

	# --- TestCard89SetsPiatto ---
	out += _test_89_sets_piatto_from_0()
	tests_run += 1
	out += _test_89_sets_piatto_from_11()
	tests_run += 1
	out += _test_89_sets_piatto_from_50()
	tests_run += 1

	# --- TestDeckReconstitution ---
	out += _test_draw_cards_reconstitutes()
	tests_run += 1
	out += _test_change_card_insufficient_deck()
	tests_run += 1
	out += _test_reset_hand_reconstitutes()
	tests_run += 1

	out += "\n--- Summary ---\n"
	out += "  Tests executed: " + str(tests_run) + "\n"
	out += "  Passed: " + str(passed) + "\n"
	out += "  Failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + f + "\n"
	out += "\n========================================\n"
	return out


# ---------------------------------------------------------------------------
# Gold chain test (single value)
# ---------------------------------------------------------------------------
func _run_gold_chain(gold_value, expected):
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": gold_value,
			"plateau_cards": [gold_card(gold_value)],
			"advantage_turn": false,
			"advantage_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var card = plus11_card(0)
	p.receive_card(card)

	var action = {"action_type": "play_card", "card": card}
	rules.apply_action(game, action)
	return _assert_eq(game.metadata["piatto"], expected,
		"Gold chain " + str(gold_value), "expected " + str(expected))

func _test_gold_chain_12():
	var ok = _run_gold_chain(12, 23)
	return "  Gold chain 12->23:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_23():
	var ok = _run_gold_chain(23, 34)
	return "  Gold chain 23->34:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_34():
	var ok = _run_gold_chain(34, 45)
	return "  Gold chain 34->45:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_45():
	var ok = _run_gold_chain(45, 56)
	return "  Gold chain 45->56:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_56():
	var ok = _run_gold_chain(56, 67)
	return "  Gold chain 56->67:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_67():
	var ok = _run_gold_chain(67, 78)
	return "  Gold chain 67->78:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_78():
	var ok = _run_gold_chain(78, 89)
	return "  Gold chain 78->89:   " + ("[PASS]" if ok else "[FAIL]") + "\n"

func _test_gold_chain_78_triggers_gdv():
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 78,
			"plateau_cards": [gold_card(78)],
			"advantage_turn": false,
			"advantage_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var card = plus11_card(0)
	p.receive_card(card)

	var action = {"action_type": "play_card", "card": card}
	rules.apply_action(game, action)

	var piatto_ok = _assert_eq(game.metadata["piatto"], 89,
		"78+11 piatto", "expected 89")
	var gdv_ok = _assert_true(game.metadata.get("advantage_turn", false),
		"78+11 GdV", "advantage_turn should be true")
	var adv_ok = _assert_eq(game.metadata.get("advantage_player_id", null), "p1",
		"78+11 adv player", "expected p1")

	if piatto_ok and gdv_ok and adv_ok:
		_test("78->89 triggers GdV")
		return "  78->89 triggers GdV: [PASS]\n"
	else:
		return "  78->89 triggers GdV: [FAIL]\n"


# ---------------------------------------------------------------------------
# GdV lifecycle test
# ---------------------------------------------------------------------------
func _test_gdv_lifecycle():
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1", Hand.new([increment_card(1, 0)]))
	var p2 = PlayerData.new("p2", "P2", Hand.new([increment_card(2, 0)]))

	var game = make_game(
		[p1, p2],
		[increment_card(3, 0)],
		null,
		{
			"piatto": 89,
			"plateau_cards": [card89(0)],
			"advantage_turn": true,
			"advantage_player_id": "p1",
			"turn_phase": "action",
			"target_score": 100,
		}
	)

	# Step 1: advance_turn from P1 (after 89) → P2
	rules.advance_turn(game)
	var step1_gdv = _assert_true(game.metadata.get("advantage_turn", false),
		"GdV lifecycle step1", "GdV should stay active after P1's turn ends")
	var step1_player = _assert_eq(game.current_player().player_id, "p2",
		"GdV lifecycle step1 player", "expected p2")

	# Step 2: P2's turn ends → back to P1 (NEXT turn for P1)
	rules.advance_turn(game)
	var step2_gdv = _assert_true(game.metadata.get("advantage_turn", false),
		"GdV lifecycle step2", "GdV should be active during P1's NEXT turn")
	var step2_player = _assert_eq(game.current_player().player_id, "p1",
		"GdV lifecycle step2 player", "expected p1")

	# Step 3: P1's NEXT turn ends → GdV must end
	rules.advance_turn(game)
	var step3_gdv_end = _assert_true(!bool(game.metadata.get("advantage_turn", false)),
		"GdV lifecycle step3", "GdV should end after P1's NEXT turn completes")
	var step3_player = _assert_eq(game.current_player().player_id, "p2",
		"GdV lifecycle step3 player", "expected p2")

	if step1_gdv and step1_player and step2_gdv and step2_player and step3_gdv_end and step3_player:
		_test("GdV lifecycle")
		return "  GdV lifecycle:       [PASS]\n"
	else:
		return "  GdV lifecycle:       [FAIL]\n"


# ---------------------------------------------------------------------------
# 89 not playable during GdV
# ---------------------------------------------------------------------------
func _test_89_not_playable_during_gdv():
	var rules = Rules.new()
	var c89 = card89(0)
	var p = PlayerData.new("p1", "P1", Hand.new([c89, increment_card(1, 0)]))

	var game = make_game(
		[p],
		[increment_card(2, 0)],
		null,
		{
			"piatto": 50,
			"plateau_cards": [],
			"advantage_turn": true,
			"advantage_player_id": "p2",
			"turn_phase": "start",
			"target_score": 100,
		}
	)

	var actions = rules.get_available_actions(game)

	# Verify 89 is NOT in play_card actions
	var c89_found_as_play = false
	var c89_found_as_change = false
	for a in actions:
		if a["action_type"] == "play_card":
			var played = a.get("card", null)
			if played == c89:
				c89_found_as_play = true
				break
		elif a["action_type"] == "change_card":
			var played = a.get("card", null)
			if played == c89:
				c89_found_as_change = true

	var play_ok = _assert_true(!c89_found_as_play,
		"89 not playable", "89 card should NOT be playable during GdV")
	var change_ok = _assert_true(c89_found_as_change,
		"89 changeable", "89 card should be changeable during GdV")

	if play_ok and change_ok:
		_test("89 not playable during GdV")
		return "  89 not playable GdV: [PASS]\n"
	else:
		return "  89 not playable GdV: [FAIL]\n"


# ---------------------------------------------------------------------------
# +11 during GdV — playable and wins instantly
# ---------------------------------------------------------------------------
func _test_plus11_during_gdv():
	var rules = Rules.new()
	var c11 = plus11_card(0)
	var p = PlayerData.new("p1", "P1", Hand.new([c11]))

	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 50,
			"plateau_cards": [],
			"advantage_turn": true,
			"advantage_player_id": "p1",
			"turn_phase": "start",
			"target_score": 100,
		}
	)

	# Verify +11 appears in available actions
	var actions = rules.get_available_actions(game)
	var plus11_play = []
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == c11:
			plus11_play.append(a)

	var avail_ok = _assert_true(!plus11_play.empty(),
		"+11 playable", "+11 must be playable during GdV")

	# Apply — should win immediately
	var action = plus11_play[0]
	rules.apply_action(game, action)
	var win_ok = _assert_true(game.winner == p,
		"+11 instant win", "+11 must grant immediate victory during GdV")

	if avail_ok and win_ok:
		_test("+11 during GdV wins")
		return "  +11 during GdV win:  [PASS]\n"
	else:
		return "  +11 during GdV win:  [FAIL]\n"


# ---------------------------------------------------------------------------
# 89 card must SET the piatto to 89 (not add 89)
# ---------------------------------------------------------------------------
func _run_89_asserts(piatto_before):
	var rules = Rules.new()
	var c89 = card89(0)
	var p = PlayerData.new("p1", "P1")
	
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": piatto_before,
			"plateau_cards": [],
			"advantage_turn": false,
			"advantage_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	p.receive_card(c89)

	var action = {"action_type": "play_card", "card": c89}
	rules.apply_action(game, action)

	var piatto_ok = _assert_eq(game.metadata["piatto"], 89,
		"89 piatto " + str(piatto_before), "expected piatto=89")
	var gdv_ok = _assert_true(game.metadata.get("advantage_turn", false),
		"89 GdV " + str(piatto_before), "advantage_turn should be true")
	var adv_ok = _assert_eq(game.metadata.get("advantage_player_id", null), "p1",
		"89 adv player " + str(piatto_before), "expected p1")
	var winner_ok = _assert_true(game.winner == null,
		"89 no win " + str(piatto_before), "winner should be null")

	return piatto_ok and gdv_ok and adv_ok and winner_ok

func _test_89_sets_piatto_from_0():
	if _run_89_asserts(0):
		_test("89 piatto from 0")
		return "  89 piatto 0 -> 89:    [PASS]\n"
	else:
		return "  89 piatto 0 -> 89:    [FAIL]\n"

func _test_89_sets_piatto_from_11():
	if _run_89_asserts(11):
		_test("89 piatto from 11")
		return "  89 piatto 11 -> 89:   [PASS]\n"
	else:
		return "  89 piatto 11 -> 89:   [FAIL]\n"

func _test_89_sets_piatto_from_50():
	if _run_89_asserts(50):
		_test("89 piatto from 50")
		return "  89 piatto 50 -> 89:   [PASS]\n"
	else:
		return "  89 piatto 50 -> 89:   [FAIL]\n"


# ---------------------------------------------------------------------------
# _draw_cards reconstitutes from discard
# ---------------------------------------------------------------------------
func _test_draw_cards_reconstitutes():
	var rules = Rules.new()
	var d1 = increment_card(1, 0)
	var p = PlayerData.new("p1", "P1")

	var game = make_game(
		[p],
		[d1],
		[increment_card(3, 0), increment_card(4, 0), increment_card(5, 0)],
		{"target_score": 100}
	)

	var drawn = rules._draw_cards(game, 3)

	var len_ok = _assert_eq(drawn.size(), 3, "draw_cards count", "expected 3 drawn")
	var first_ok = _assert_eq(drawn[0], d1, "draw_cards first", "first must be from deck")
	var discard_ok = _assert_eq(game.discard_pile.size(), 1,
		"draw_cards discard after", "discard must have 1 card after reconstitution")
	var deck_ok = _assert_eq(game.deck.cards.size(), 0,
		"draw_cards deck empty", "deck must be empty")

	if len_ok and first_ok and discard_ok and deck_ok:
		_test("draw_cards reconstitutes")
		return "  Draw cards reconstit: [PASS]\n"
	else:
		return "  Draw cards reconstit: [FAIL]\n"


# ---------------------------------------------------------------------------
# CHANGE_CARD with insufficient deck
# ---------------------------------------------------------------------------
func _test_change_card_insufficient_deck():
	var rules = Rules.new()

	var h1 = increment_card(1, 0)
	var h2 = increment_card(2, 0)
	var h3 = increment_card(3, 0)
	var p = PlayerData.new("p1", "P1", Hand.new([h1, h2, h3]))

	var s1 = increment_card(4, 0)
	var s2 = increment_card(5, 0)

	var game = make_game(
		[p],
		[],  # empty deck
		[s1, s2],
		{
			"piatto": 10,
			"plateau_cards": [],
			"advantage_turn": false,
			"advantage_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)

	var initial_count = p.hand.size()

	var action = {"action_type": "change_card", "card": h1}
	rules.apply_action(game, action)

	var hand_ok = _assert_eq(p.hand.size(), initial_count,
		"change_card insufficient deck", "hand must have same size after CHANGE_CARD")

	if hand_ok:
		_test("change_card insufficient deck")
		return "  Change card insuff:   [PASS]\n"
	else:
		return "  Change card insuff:   [FAIL]\n"


# ---------------------------------------------------------------------------
# RESET_HAND reconstitutes deck
# ---------------------------------------------------------------------------
func _test_reset_hand_reconstitutes():
	var rules = Rules.new()

	var h1 = increment_card(1, 0)
	var p = PlayerData.new("p1", "P1", Hand.new([h1]))

	var s1 = increment_card(4, 0)
	var s2 = increment_card(5, 0)
	var s3 = increment_card(6, 0)
	var s4 = increment_card(7, 0)

	var p2 = PlayerData.new("p2", "P2")
	var game = make_game(
		[p, p2],
		[],  # empty deck
		[s1, s2, s3, s4],
		{
			"piatto": 50,
			"plateau_cards": [],
			"advantage_turn": true,
			"advantage_player_id": "p2",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	# Ensure p1 is current player for RESET_HAND
	game.set_current_player(p)

	var action = {"action_type": "reset_hand"}
	rules.apply_action(game, action)

	var hand_ok = _assert_eq(p.hand.size(), 3,
		"reset_hand count", "hand must have 3 cards after RESET_HAND")

	if hand_ok:
		_test("reset_hand reconstitutes")
		return "  Reset hand reconstit: [PASS]\n"
	else:
		return "  Reset hand reconstit: [FAIL]\n"
