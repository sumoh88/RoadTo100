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
	var meta_copy = metadata.duplicate(true) if metadata != null else {}
	var g = GameState.new(
		players,
		Deck.new(deck_cards.duplicate()),
		discard.duplicate() if discard != null else [],
		0,  # current_player_index
		0,  # turn_number
		1,  # phase = PLAYING
		null,  # winner
		meta_copy
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

	# --- TestGdvBounce (7 tests) ---
	out += _test_bounce_99_plus_1()
	tests_run += 1
	out += _test_bounce_99_plus_5()
	tests_run += 1
	out += _test_bounce_90_plus_10()
	tests_run += 1
	out += _test_bounce_97_plus_8()
	tests_run += 1
	out += _test_bounce_70_plus_10_no_bounce()
	tests_run += 1
	out += _test_no_bounce_advantage_player()
	tests_run += 1
	out += _test_no_bounce_plus11_non_advantage()
	tests_run += 1

	# --- F5: Bounce formula and bifurcation ---
	out += _test_normal_bounce_99_plus_1()
	tests_run += 1
	out += _test_normal_bounce_99_plus_2()
	tests_run += 1
	out += _test_normal_bounce_97_plus_8()
	tests_run += 1
	out += _test_normal_bounce_95_plus_8()
	tests_run += 1
	out += _test_gdv_non_adv_exact_100()
	tests_run += 1
	out += _test_gdv_advantage_97_plus_8()
	tests_run += 1
	out += _test_safe_round_victory()
	tests_run += 1

	# --- F2: Safe Round activation ---
	out += _test_gold_12_activates_safe_round()
	tests_run += 1
	out += _test_gold_78_activates_safe_round()
	tests_run += 1
	out += _test_plus11_from_67_chain_activates_safe_round()
	tests_run += 1
	out += _test_plus11_from_78_chain_activates_advantage()
	tests_run += 1
	out += _test_new_safe_round_overwrites()
	tests_run += 1

	# --- F4: Safe Round blocked type ---
	out += _test_blocked_incremento_blocks_normal()
	tests_run += 1
	out += _test_blocked_incremento_blocks_plus11()
	tests_run += 1
	out += _test_blocked_gold_blocks_normal()
	tests_run += 1
	out += _test_blocked_gold_blocks_89()
	out += _test_blocked_gold_allows_plus11()
	tests_run += 1
	out += _test_blocked_imbroglio_blocks_imbroglio()
	tests_run += 1
	out += _test_change_card_available_during_safe_round()
	tests_run += 1
	out += _test_validate_action_blocks_incremento()
	tests_run += 1
	out += _test_validate_allows_plus11_gold_blocked()
	tests_run += 1
	out += _test_validate_blocks_89_gold_blocked()
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
			"special_round_active": false,
			"special_round_player_id": null,
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
			"special_round_active": false,
			"special_round_player_id": null,
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
	var gdv_ok = _assert_true(game.metadata.get("special_round_active", false),
		"78+11 GdV", "advantage_turn should be true")
	var adv_ok = _assert_eq(game.metadata.get("special_round_player_id", null), "p1",
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
			"special_round_active": true,
			"special_round_player_id": "p1",
			"turn_phase": "action",
			"target_score": 100,
		}
	)

	# Step 1: advance_turn from P1 (after 89) → P2
	rules.advance_turn(game)
	var step1_gdv = _assert_true(game.metadata.get("special_round_active", false),
		"GdV lifecycle step1", "GdV should stay active after P1's turn ends")
	var step1_player = _assert_eq(game.current_player().player_id, "p2",
		"GdV lifecycle step1 player", "expected p2")

	# Step 2: P2's turn ends → back to P1 (NEXT turn for P1)
	rules.advance_turn(game)
	var step2_gdv = _assert_true(game.metadata.get("special_round_active", false),
		"GdV lifecycle step2", "GdV should be active during P1's NEXT turn")
	var step2_player = _assert_eq(game.current_player().player_id, "p1",
		"GdV lifecycle step2 player", "expected p1")

	# Step 3: P1's NEXT turn ends → GdV must end
	rules.advance_turn(game)
	var step3_gdv_end = _assert_true(!bool(game.metadata.get("special_round_active", false)),
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
			"special_round_active": true,
			"special_round_player_id": "p2",
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
			"special_round_active": true,
			"special_round_player_id": "p1",
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
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	p.receive_card(c89)

	var action = {"action_type": "play_card", "card": c89}
	rules.apply_action(game, action)

	var piatto_ok = _assert_eq(game.metadata["piatto"], 89,
		"89 piatto " + str(piatto_before), "expected piatto=89")
	var gdv_ok = _assert_true(game.metadata.get("special_round_active", false),
		"89 GdV " + str(piatto_before), "advantage_turn should be true")
	var adv_ok = _assert_eq(game.metadata.get("special_round_player_id", null), "p1",
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
			"special_round_active": false,
			"special_round_player_id": null,
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
			"special_round_active": true,
			"special_round_player_id": "p2",
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


# ---------------------------------------------------------------------------
# Helper: create a 2-player GdV game with P2 as current player (non-advantage
# by default) and P1 as advantage player.
# ---------------------------------------------------------------------------

func _make_gdv_game(piatto, card, advantage_player = "p1", current_player = "p2"):
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new(current_player, "P" + current_player.right(1))
	p2.receive_card(card)
	var game = make_game(
		[p1, p2],
		[increment_card(3, 0)],
		null,
		{
			"piatto": piatto,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": advantage_player,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p2)
	return [rules, p2, game]


# ---------------------------------------------------------------------------
# GdV Bounce tests (mirror TestGdvBounce in test_roadto100_rules.py)
# ---------------------------------------------------------------------------

func _test_bounce_99_plus_1():
	var r = _make_gdv_game(99, increment_card(1, 0))
	var rules = r[0]; var player = r[1]; var game = r[2]
	var action = {"action_type": "play_card", "card": player.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 99, "bounce 99+1", "expected 99")
	var o2 = _assert_true(game.winner == null, "bounce 99+1 no win", "no winner")
	if o1 and o2:
		_test("bounce 99+1")
		return "  Bounce 99+1:          [PASS]\n"
	return "  Bounce 99+1:          [FAIL]\n"

func _test_bounce_99_plus_5():
	"""Non-advantage GdV: 99+5=104 → bounce (200-104=96)."""
	var r = _make_gdv_game(99, increment_card(5, 0))
	var rules = r[0]; var player = r[1]; var game = r[2]
	var action = {"action_type": "play_card", "card": player.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 96, "bounce 99+5", "expected 96")
	var o2 = _assert_true(game.winner == null, "bounce 99+5 no win", "no winner")
	if o1 and o2:
		_test("bounce 99+5")
		return "  Bounce 99+5:          [PASS]\n"
	return "  Bounce 99+5:          [FAIL]\n"

func _test_bounce_90_plus_10():
	var r = _make_gdv_game(90, increment_card(10, 0))
	var rules = r[0]; var player = r[1]; var game = r[2]
	var action = {"action_type": "play_card", "card": player.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 99, "bounce 90+10", "expected 99")
	var o2 = _assert_true(game.winner == null, "bounce 90+10 no win", "no winner")
	if o1 and o2:
		_test("bounce 90+10")
		return "  Bounce 90+10:         [PASS]\n"
	return "  Bounce 90+10:         [FAIL]\n"

func _test_bounce_97_plus_8():
	"""Non-advantage GdV: 97+8=105 → bounce (200-105=95)."""
	var r = _make_gdv_game(97, increment_card(8, 0))
	var rules = r[0]; var player = r[1]; var game = r[2]
	var action = {"action_type": "play_card", "card": player.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 95, "bounce 97+8", "expected 95")
	var o2 = _assert_true(game.winner == null, "bounce 97+8 no win", "no winner")
	if o1 and o2:
		_test("bounce 97+8")
		return "  Bounce 97+8:          [PASS]\n"
	return "  Bounce 97+8:          [FAIL]\n"

func _test_bounce_70_plus_10_no_bounce():
	var r = _make_gdv_game(70, increment_card(10, 0))
	var rules = r[0]; var player = r[1]; var game = r[2]
	var action = {"action_type": "play_card", "card": player.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 80, "bounce 70+10", "expected 80 (no bounce)")
	var o2 = _assert_true(game.winner == null, "bounce 70+10 no win", "no winner")
	if o1 and o2:
		_test("bounce 70+10 no bounce")
		return "  Bounce 70+10:         [PASS]\n"
	return "  Bounce 70+10:         [FAIL]\n"

func _test_no_bounce_advantage_player():
	"""Advantage player: piatto 95 +10 → 105, wins (no bounce)."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(10, 0))
	var p2 = PlayerData.new("p2", "P2")
	var game = make_game(
		[p1, p2],
		[increment_card(3, 0)],
		null,
		{
			"piatto": 95,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p1)
	var action = {"action_type": "play_card", "card": p1.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 105, "adv player 95+10", "expected 105")
	var o2 = _assert_true(game.winner == p1, "adv player wins", "expected p1 winner")
	if o1 and o2:
		_test("no bounce advantage")
		return "  Bounce adv player:    [PASS]\n"
	return "  Bounce adv player:    [FAIL]\n"

func _test_no_bounce_plus11_non_advantage():
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var c11 = plus11_card(0)
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(c11)
	var game = make_game(
		[p1, p2],
		[increment_card(3, 0)],
		null,
		{
			"piatto": 99,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p2)
	var action = {"action_type": "play_card", "card": c11}
	rules.apply_action(game, action)
	var o1 = _assert_true(game.winner == p2, "+11 non-adv wins", "+11 must win for non-advantage")
	if o1:
		_test("+11 non-advantage")
		return "  +11 non-adv GdV:      [PASS]\n"
	return "  +11 non-adv GdV:      [FAIL]\n"


# ===========================================================================
# F5 — Bounce formula (200 - raw_total) and bifurcation logic
# ===========================================================================

func _test_normal_bounce_99_plus_1():
	"""Normal play: 99+1=100 → victory."""
	var rules = Rules.new()
	var p = PlayerData.new("p1", "P1")
	p.receive_card(increment_card(1, 0))
	var game = make_game(
		[p],
		[],
		null,
		{
			"piatto": 99,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 100, "normal 99+1", "expected 100")
	var o2 = _assert_true(game.winner == p, "normal 99+1 win", "p1 wins")
	if o1 and o2:
		_test("normal bounce 99+1")
		return "  Normal 99+1:          [PASS]\n"
	return "  Normal 99+1:          [FAIL]\n"

func _test_normal_bounce_99_plus_2():
	"""Normal play: 99+2=101 → bounce (200-101=99)."""
	var rules = Rules.new()
	var p = PlayerData.new("p1", "P1")
	p.receive_card(increment_card(2, 0))
	var game = make_game(
		[p],
		[],
		null,
		{
			"piatto": 99,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 99, "normal 99+2", "expected 99")
	var o2 = _assert_true(game.winner == null, "normal 99+2 no win", "no winner")
	if o1 and o2:
		_test("normal bounce 99+2")
		return "  Normal 99+2:          [PASS]\n"
	return "  Normal 99+2:          [FAIL]\n"

func _test_normal_bounce_97_plus_8():
	"""Normal play: 97+8=105 → bounce (200-105=95)."""
	var rules = Rules.new()
	var p = PlayerData.new("p1", "P1")
	p.receive_card(increment_card(8, 0))
	var game = make_game(
		[p],
		[],
		null,
		{
			"piatto": 97,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 95, "normal 97+8", "expected 95")
	var o2 = _assert_true(game.winner == null, "normal 97+8 no win", "no winner")
	if o1 and o2:
		_test("normal bounce 97+8")
		return "  Normal 97+8:          [PASS]\n"
	return "  Normal 97+8:          [FAIL]\n"

func _test_normal_bounce_95_plus_8():
	"""Normal play: 95+8=103 → bounce (200-103=97)."""
	var rules = Rules.new()
	var p = PlayerData.new("p1", "P1")
	p.receive_card(increment_card(8, 0))
	var game = make_game(
		[p],
		[],
		null,
		{
			"piatto": 95,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 97, "normal 95+8", "expected 97")
	var o2 = _assert_true(game.winner == null, "normal 95+8 no win", "no winner")
	if o1 and o2:
		_test("normal bounce 95+8")
		return "  Normal 95+8:          [PASS]\n"
	return "  Normal 95+8:          [FAIL]\n"

func _test_gdv_non_adv_exact_100():
	"""GdV non-advantage: plateau exactly 100 → Piatto=99, no win."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(increment_card(1, 0))
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 99,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p2)
	var action = {"action_type": "play_card", "card": p2.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 99, "gdv non-adv 99+1", "expected 99")
	var o2 = _assert_true(game.winner == null, "gdv non-adv 99+1 no win", "no winner")
	if o1 and o2:
		_test("gdv non-adv exact 100")
		return "  GdV non-adv 99+1:     [PASS]\n"
	return "  GdV non-adv 99+1:     [FAIL]\n"

func _test_gdv_advantage_97_plus_8():
	"""GdV advantage: 97+8=105 → 105, immediate win (no bounce)."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(8, 0))
	var p2 = PlayerData.new("p2", "P2")
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 97,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p1)
	var action = {"action_type": "play_card", "card": p1.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 105, "gdv adv 97+8", "expected 105")
	var o2 = _assert_true(game.winner == p1, "gdv adv 97+8 win", "p1 wins")
	if o1 and o2:
		_test("gdv advantage no bounce")
		return "  GdV advantage 97+8:   [PASS]\n"
	return "  GdV advantage 97+8:   [FAIL]\n"

func _test_safe_round_victory():
	"""Safe Round: activator player wins at 100."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(1, 0))
	var game = make_game(
		[p1],
		[],
		null,
		{
			"piatto": 99,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	var action = {"action_type": "play_card", "card": p1.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 100, "safe round 99+1", "expected 100")
	var o2 = _assert_true(game.winner == p1, "safe round 99+1 win", "p1 wins")
	if o1 and o2:
		_test("safe round victory")
		return "  Safe Round victory:   [PASS]\n"
	return "  Safe Round victory:   [FAIL]\n"


# ===========================================================================
# F2 — Safe Round activation from Gold cards and +11 chain
# ===========================================================================

func _test_gold_12_activates_safe_round():
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	p.receive_card(gold_card(12))
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 0,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_true(game.metadata["piatto"] == 12, "gold_12 piatto", "plateau should be 12")
	var o2 = _assert_true(game.metadata.get("special_round_active", false), "gold_12 sr active", "Safe Round activates")
	var o3 = _assert_true(game.metadata.get("special_round_player_id", "") == "p1", "gold_12 activator", "P1 is activator")
	var o4 = _assert_true(str(game.metadata.get("special_round_type", "")) == "safe", "gold_12 type safe", "Type is safe")
	if o1 and o2 and o3 and o4:
		_test("Gold 12 Safe Round")
		return "  Gold 12 Safe Round:    [PASS]\n"
	return "  Gold 12 Safe Round:    [FAIL]\n"


func _test_gold_78_activates_safe_round():
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	p.receive_card(gold_card(78))
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 0,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_true(game.metadata["piatto"] == 78, "gold_78 piatto", "plateau should be 78")
	var o2 = _assert_true(game.metadata.get("special_round_active", false), "gold_78 sr active", "Safe Round activates")
	var o3 = _assert_true(str(game.metadata.get("special_round_type", "")) == "safe", "gold_78 type safe", "Type is safe")
	if o1 and o2 and o3:
		_test("Gold 78 Safe Round")
		return "  Gold 78 Safe Round:    [PASS]\n"
	return "  Gold 78 Safe Round:    [FAIL]\n"


func _test_plus11_from_67_chain_activates_safe_round():
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	p.receive_card(plus11_card(0))
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 67,
			"plateau_cards": [gold_card(67)],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_true(game.metadata["piatto"] == 78, "+11_67 plateau", "plateau should be 78")
	var o2 = _assert_true(game.metadata.get("special_round_active", false), "+11_67 sr active", "Safe Round activates")
	var o3 = _assert_true(str(game.metadata.get("special_round_type", "")) == "safe", "+11_67 type safe", "Type is safe")
	if o1 and o2 and o3:
		_test("+11 from 67 chain Safe Round")
		return "  +11 from 67 Safe Round:[PASS]\n"
	return "  +11 from 67 Safe Round:[FAIL]\n"


func _test_plus11_from_78_chain_activates_advantage():
	var rules = Rules.new()
	var p = PlayerData.new("p1", "Player 1")
	p.receive_card(plus11_card(0))
	var game = make_game(
		[p],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 78,
			"plateau_cards": [gold_card(78)],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(p)
	var action = {"action_type": "play_card", "card": p.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_true(game.metadata["piatto"] == 89, "+11_78 plateau", "plateau should be 89")
	var o2 = _assert_true(game.metadata.get("special_round_active", false), "+11_78 sr active", "Special Round activates")
	var o3 = _assert_true(str(game.metadata.get("special_round_type", "")) == "advantage", "+11_78 type adv", "Type is advantage")
	if o1 and o2 and o3:
		_test("+11 from 78 chain Advantage Round")
		return "  +11 from 78 Adv Round: [PASS]\n"
	return "  +11 from 78 Adv Round: [FAIL]\n"


func _test_new_safe_round_overwrites():
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "Player 1")
	p1.receive_card(gold_card(12))
	var p2 = PlayerData.new("p2", "Player 2")
	p2.receive_card(gold_card(34))
	var game = make_game(
		[p1, p2],
		[increment_card(1, 0)],
		null,
		{
			"piatto": 0,
			"plateau_cards": [],
			"special_round_active": false,
			"special_round_player_id": null,
			"turn_phase": "start",
			"target_score": 100,
		}
	)

	# P1 plays Gold 12 → Safe Round for P1
	game.set_current_player(p1)
	var action1 = {"action_type": "play_card", "card": p1.hand.cards[0]}
	rules.apply_action(game, action1)
	var o1 = _assert_true(game.metadata.get("special_round_player_id", "") == "p1", "sr p1", "P1 activator after Gold 12")
	var o2 = _assert_true(game.metadata["piatto"] == 12, "sr piatto 12", "plateau is 12")

	# Advance turn to P2, P2 plays Gold 34 → replaces for P2
	game.current_player_index = 1
	game.set_current_player(p2)
	game.metadata["turn_phase"] = "start"
	game.turn_number += 1
	var action2 = {"action_type": "play_card", "card": p2.hand.cards[0]}
	rules.apply_action(game, action2)
	var o3 = _assert_true(game.metadata.get("special_round_player_id", "") == "p2", "sr p2", "P2 becomes new activator")
	var o4 = _assert_true(game.metadata["piatto"] == 34, "sr piatto 34", "plateau set to 34 by Gold 34")

	if o1 and o2 and o3 and o4:
		_test("Safe Round replace")
		return "  New Safe replaces old: [PASS]\n"
	return "  New Safe replaces old: [FAIL]\n"


# ===========================================================================
# F4 — Safe Round blocked type (card type blocking for non-activators)
# ===========================================================================

func _make_safe_round_game(players, blocked_type, current_player_idx):
	"""Create a 2-player game with Safe Round active for p1 and blocked_type set."""
	var p1 = PlayerData.new("p1", "P1")
	var p2id = "p2"
	if current_player_idx == 0:
		p2id = "p1"
	var p2 = PlayerData.new(p2id, "P" + str(current_player_idx + 1))
	var game = make_game(
		players,
		[increment_card(1, 0)],
		null,
		{
			"piatto": 50,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": blocked_type,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.set_current_player(players[current_player_idx])
	return [game, p1, p2]


func _test_blocked_incremento_blocks_normal():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Incremento", 1)
	var game = r[0]
	var p2 = game.current_player()
	p2.receive_card(increment_card(5, 0))
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	# Verify increment card NOT in play actions
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == p2.hand.cards[0]:
			found_play = true
			break
	var ok = _assert_true(!found_play, "blocked_inc play", "Increment card not playable when Incremento blocked")
	if ok:
		_test("blocked incremento normal")
		return "  Blocked Incremento normal:[PASS]\n"
	return "  Blocked Incremento normal:[FAIL]\n"


func _test_blocked_incremento_blocks_plus11():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Incremento", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c11 = plus11_card(0)
	p2.receive_card(c11)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == c11:
			found_play = true
			break
	var ok = _assert_true(!found_play, "blocked_inc_plus11", "+11 not playable when Incremento blocked")
	if ok:
		_test("blocked incremento +11")
		return "  Blocked Incremento +11:   [PASS]\n"
	return "  Blocked Incremento +11:   [FAIL]\n"


func _test_blocked_gold_blocks_normal():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Gold", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c_gold = gold_card(23)
	p2.receive_card(c_gold)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == c_gold:
			found_play = true
			break
	var ok = _assert_true(!found_play, "blocked_gold", "Gold card not playable when Gold blocked")
	if ok:
		_test("blocked gold normal")
		return "  Blocked Gold normal:     [PASS]\n"
	return "  Blocked Gold normal:     [FAIL]\n"


func _test_blocked_gold_blocks_89():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Gold", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c89 = card89(0)
	p2.receive_card(c89)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == c89:
			found_play = true
			break
	var ok = _assert_true(!found_play, "blocked_gold_89", "89 not playable when Gold blocked")
	if ok:
		_test("blocked gold 89")
		return "  Blocked Gold 89:         [PASS]\n"
	return "  Blocked Gold 89:         [FAIL]\n"


func _test_blocked_gold_allows_plus11():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Gold", 1)
	var game = r[0]
	# Use game's player objects (the ones stored in the game, not local vars)
	var p2 = game.current_player()
	var c11 = plus11_card(0)
	p2.receive_card(c11)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == c11:
			found_play = true
			break
	var ok = _assert_true(found_play, "gold_allows_plus11", "+11 playable when Gold blocked")
	if ok:
		_test("blocked gold allows +11")
		return "  Blocked Gold allows +11: [PASS]\n"
	return "  Blocked Gold allows +11: [FAIL]\n"


func _test_blocked_imbroglio_blocks_imbroglio():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Imbroglio", 1)
	var game = r[0]
	var p2 = game.current_player()
	var imb = imbroglio_card(0)
	p2.receive_card(imb)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_play = false
	for a in actions:
		if a["action_type"] == "play_card" and a.get("card", null) == imb:
			found_play = true
			break
	var ok = _assert_true(!found_play, "blocked_imbroglio", "Imbroglio card not playable when Imbroglio blocked")
	if ok:
		_test("blocked imbroglio")
		return "  Blocked Imbroglio:       [PASS]\n"
	return "  Blocked Imbroglio:       [FAIL]\n"


func _test_change_card_available_during_safe_round():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Incremento", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c = increment_card(5, 0)
	p2.receive_card(c)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var found_change = false
	for a in actions:
		if a["action_type"] == "change_card" and a.get("card", null) == c:
			found_change = true
			break
	var ok = _assert_true(found_change, "change_available", "Change card available during Safe Round")
	if ok:
		_test("change card during safe round")
		return "  Change Card available:     [PASS]\n"
	return "  Change Card available:     [FAIL]\n"


func _test_validate_action_blocks_incremento():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Incremento", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c = increment_card(5, 0)
	p2.receive_card(c)
	var rules = Rules.new()
	var action = {"action_type": "play_card", "card": c}
	var ok = _assert_true(!rules.validate_action(game, action), "validate_blocks_inc",
		"validate_action rejects blocked Incremento card")
	if ok:
		_test("validate blocks incremento")
		return "  Validate blocks inc:       [PASS]\n"
	return "  Validate blocks inc:       [FAIL]\n"


func _test_validate_allows_plus11_gold_blocked():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Gold", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c11 = plus11_card(0)
	p2.receive_card(c11)
	var rules = Rules.new()
	var action = {"action_type": "play_card", "card": c11}
	var ok = _assert_true(rules.validate_action(game, action), "validate_plus11_gold_ok",
		"validate_action accepts +11 when Gold blocked")
	if ok:
		_test("validate allows +11 gold blocked")
		return "  Validate allows +11:       [PASS]\n"
	return "  Validate allows +11:       [FAIL]\n"


func _test_validate_blocks_89_gold_blocked():
	var r = _make_safe_round_game([PlayerData.new("p1"), PlayerData.new("p2")], "Gold", 1)
	var game = r[0]
	var p2 = game.current_player()
	var c89 = card89(0)
	p2.receive_card(c89)
	var rules = Rules.new()
	var action = {"action_type": "play_card", "card": c89}
	var ok = _assert_true(!rules.validate_action(game, action), "validate_89_blocked",
		"validate_action rejects 89 when Gold blocked")
	if ok:
		_test("validate blocks 89 gold")
		return "  Validate blocks 89:        [PASS]\n"
	return "  Validate blocks 89:        [FAIL]\n"
