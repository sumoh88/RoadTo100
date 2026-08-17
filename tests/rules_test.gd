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

	# --- F7: Safe Round end-to-end (blocked_type persistence, +11 chain,
	#     replacement lifecycle, GS/GdV bounce & victory, playability) ---
	out += _test_f7_gold_persists_blocked_type()
	tests_run += 1
	out += _test_f7_plus11_chain_persists_blocked_type()
	tests_run += 1
	out += _test_f7_89_replaces_gs_clears_blocked()
	tests_run += 1
	out += _test_f7_gs_end_clears_blocked()
	tests_run += 1
	out += _test_f7_new_gs_replacement_updates_blocked()
	tests_run += 1
	out += _test_f7_plus11_no_preceding_gold_keeps_gs()
	tests_run += 1
	out += _test_f7_plus11_after_gold_replaces_gs()
	tests_run += 1
	out += _test_f7_replacement_survives_advance()
	tests_run += 1
	out += _test_f7_gdv_after_gs_no_stale_block()
	tests_run += 1
	out += _test_f7_activator_over_100_bounces()
	tests_run += 1
	out += _test_f7_activator_exact_100_wins()
	tests_run += 1
	out += _test_f7_change_when_no_playable_in_gs()
	tests_run += 1
	out += _test_f7_imbroglio_playable_in_gs_when_not_blocked()
	tests_run += 1
	out += _test_f7_gdv_still_excludes_imbroglio()
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
# +11 during GdV — playable, ignores bounce and advantage restriction
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
			"piatto": 89,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p2",
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

	# Apply — Piatto 89+11=100, +11 ignores bounce and GdV restriction → wins
	var action = plus11_play[0]
	rules.apply_action(game, action)
	var win_ok = _assert_true(game.winner == p,
		"+11 reach 100", "+11 reaching 100 must win even as non-advantage player")

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


# ===========================================================================
# F7 — Safe Round end-to-end (blocked_type persistence, +11 chain during GS,
#      replacement lifecycle, GS/GdV bounce & victory, playability)
# ===========================================================================

func _f7_play_cids(actions):
	var cids = []
	for a in actions:
		if a["action_type"] == "play_card":
			cids.append(a.get("card", null))
	return cids


func _f7_change_cids(actions):
	var cids = []
	for a in actions:
		if a["action_type"] == "change_card":
			cids.append(a.get("card", null))
	return cids


func _test_f7_gold_persists_blocked_type():
	"""Gold played with blocked_type persists it; next turn's actions are filtered."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(gold_card(12))
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(increment_card(3, 0))
	p2.receive_card(imbroglio_card(0))
	var game = make_game(
		[p1, p2],
		[],
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
	var action = {"action_type": "play_card", "card": p1.hand.cards[0], "blocked_type": "Incremento"}
	rules.apply_action(game, action)
	var o1 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Incremento",
		"f7 persist blocked", "blocked_type must be persisted from the play_card action")
	var o2 = _assert_eq(str(game.metadata.get("special_round_type", "")), "safe",
		"f7 persist type", "type safe after gold")
	rules.advance_turn(game)
	var actions = rules.get_available_actions(game)
	var play_cids = _f7_play_cids(actions)
	var change_cids = _f7_change_cids(actions)
	var inc = increment_card(3, 0)
	var imb = imbroglio_card(0)
	# find the actual cards in p2 hand by card_id (factory instances differ)
	var played_inc = false
	var played_imb = false
	for c in play_cids:
		if c != null and c.card_id == inc.card_id:
			played_inc = true
		if c != null and c.card_id == imb.card_id:
			played_imb = true
	var o3 = _assert_true(!played_inc, "f7 persist filter inc", "blocked Incremento must be filtered")
	var o4 = _assert_true(played_imb, "f7 persist filter imb", "Imbroglio is playable during GS when not blocked")
	var o5 = _assert_eq(change_cids.size(), 2, "f7 persist cambio", "Cambio available for both cards")
	if o1 and o2 and o3 and o4 and o5:
		_test("f7 gold persists blocked_type")
		return "  F7 persist blocked_type: [PASS]\n"
	return "  F7 persist blocked_type: [FAIL]\n"


func _test_f7_plus11_chain_persists_blocked_type():
	"""+11 chained after Gold 67 resolves as 78 and persists the chosen blocked_type."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(plus11_card(0))
	var game = make_game(
		[p1, p2],
		[],
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
	game.current_player_index = 1
	game.set_current_player(p2)
	var action = {"action_type": "play_card", "card": p2.hand.cards[0], "blocked_type": "Gold"}
	rules.apply_action(game, action)
	var o1 = _assert_eq(game.metadata["piatto"], 78, "f7 chain 78", "+11 from 67 resolves as 78")
	var o2 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p2",
		"f7 chain activator", "P2 becomes the GS activator")
	var o3 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Gold",
		"f7 chain blocked", "chain-activated GS must persist the chosen blocked_type")
	if o1 and o2 and o3:
		_test("f7 +11 chain persists blocked_type")
		return "  F7 chain persists bt:   [PASS]\n"
	return "  F7 chain persists bt:   [FAIL]\n"


func _test_f7_89_replaces_gs_clears_blocked():
	"""Playing 89 during a GS replaces it with GdV and clears the stale blocked_type."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(card89(0))
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 12,
			"plateau_cards": [gold_card(12)],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": "Incremento",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.current_player_index = 1
	game.set_current_player(p2)
	var action = {"action_type": "play_card", "card": p2.hand.cards[0]}
	rules.apply_action(game, action)
	var o1 = _assert_eq(str(game.metadata.get("special_round_type", "")), "advantage",
		"f7 89 type", "89 activates GdV")
	var o2 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p2",
		"f7 89 activator", "P2 becomes the GdV player")
	var o3 = _assert_eq(str(game.metadata.get("blocked_type", "")), "",
		"f7 89 blocked clear", "stale blocked_type must not leak into the GdV")
	if o1 and o2 and o3:
		_test("f7 89 replaces gs clears blocked")
		return "  F7 89 clears blocked:   [PASS]\n"
	return "  F7 89 clears blocked:   [FAIL]\n"


func _test_f7_gs_end_clears_blocked():
	"""When the GS ends (activator's next turn completes), blocked_type is cleared."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 12,
			"plateau_cards": [gold_card(12)],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": "Gold",
			"_activator_has_played_next": true,
			"turn_phase": "action",
			"target_score": 100,
		}
	)
	rules.advance_turn(game)
	var o1 = _assert_true(!game.metadata.get("special_round_active", false),
		"f7 gs end", "GS must end after the activator's next turn")
	var o2 = _assert_eq(str(game.metadata.get("blocked_type", "")), "",
		"f7 gs end blocked clear", "blocked_type must be cleared when the GS ends")
	if o1 and o2:
		_test("f7 gs end clears blocked")
		return "  F7 GS end clears bt:    [PASS]\n"
	return "  F7 GS end clears bt:    [FAIL]\n"


func _test_f7_new_gs_replacement_updates_blocked():
	"""A new GS replaces the previous one, including its blocked_type."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(gold_card(12))
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(gold_card(34))
	var game = make_game(
		[p1, p2],
		[],
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
	rules.apply_action(game, {"action_type": "play_card", "card": p1.hand.cards[0], "blocked_type": "Imbroglio"})
	var o1 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Imbroglio",
		"f7 repl first", "first GS blocked_type")
	game.current_player_index = 1
	game.set_current_player(p2)
	game.metadata["turn_phase"] = "start"
	rules.apply_action(game, {"action_type": "play_card", "card": p2.hand.cards[0], "blocked_type": "Gold"})
	var o2 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p2",
		"f7 repl activator", "P2 becomes the new GS activator")
	var o3 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Gold",
		"f7 repl blocked", "the replacement GS must carry its own blocked_type")
	if o1 and o2 and o3:
		_test("f7 gs replacement updates blocked")
		return "  F7 GS replacement bt:   [PASS]\n"
	return "  F7 GS replacement bt:   [FAIL]\n"


# --- F7 helper: Safe Round context (GS active for p1) with p2 to act ---
func _f7_gs_context(p2_cards, plateau_cards, piatto, blocked_type):
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	for c in p2_cards:
		p2.receive_card(c)
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": piatto,
			"plateau_cards": plateau_cards,
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": blocked_type,
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.current_player_index = 1
	game.set_current_player(p2)
	return {"p1": p1, "p2": p2, "game": game}


func _test_f7_plus11_no_preceding_gold_keeps_gs():
	"""+11 with a non-Gold previous card just adds 11; the GS is unchanged."""
	var rules = Rules.new()
	var ctx = _f7_gs_context([plus11_card(0)], [increment_card(2, 0)], 50, "Imbroglio")
	var p2 = ctx["p2"]; var game = ctx["game"]
	rules.apply_action(game, {"action_type": "play_card", "card": p2.hand.cards[0]})
	var o1 = _assert_eq(game.metadata["piatto"], 61, "f7 plus11 nochain", "+11 adds 11 without a Gold chain")
	var o2 = _assert_true(bool(game.metadata.get("special_round_active", false)),
		"f7 plus11 nochain gs", "GS must stay active")
	var o3 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p1",
		"f7 plus11 nochain pid", "GS activator must be unchanged")
	var o4 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Imbroglio",
		"f7 plus11 nochain bt", "GS blocked_type must be unchanged")
	var o5 = _assert_true(game.winner == null, "f7 plus11 nochain winner", "no winner at 61")
	if o1 and o2 and o3 and o4 and o5:
		_test("f7 +11 without preceding gold keeps GS")
		return "  F7 +11 keeps GS:        [PASS]\n"
	return "  F7 +11 keeps GS:        [FAIL]\n"


func _test_f7_plus11_after_gold_replaces_gs():
	"""+11 immediately after a Gold chains (67→78) and replaces the GS for P2."""
	var rules = Rules.new()
	var ctx = _f7_gs_context([plus11_card(0)], [gold_card(67)], 67, "Imbroglio")
	var p2 = ctx["p2"]; var game = ctx["game"]
	rules.apply_action(game, {"action_type": "play_card", "card": p2.hand.cards[0], "blocked_type": "Incremento"})
	var o1 = _assert_eq(game.metadata["piatto"], 78, "f7 plus11 chain", "+11 from 67 resolves as 78")
	var o2 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p2",
		"f7 plus11 chain pid", "the +11 player becomes the new GS activator")
	var o3 = _assert_eq(str(game.metadata.get("special_round_type", "")), "safe",
		"f7 plus11 chain type", "chain to 78 activates a Safe Round")
	var o4 = _assert_eq(str(game.metadata.get("blocked_type", "")), "Incremento",
		"f7 plus11 chain bt", "replaced GS must carry the new blocked_type")
	if o1 and o2 and o3 and o4:
		_test("f7 +11 after gold replaces GS")
		return "  F7 +11 replaces GS:     [PASS]\n"
	return "  F7 +11 replaces GS:     [FAIL]\n"


func _test_f7_replacement_survives_advance():
	"""A GS replacing another GS stays active through the replacement's turns."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(gold_card(12))
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(gold_card(34))
	var game = make_game(
		[p1, p2],
		[],
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
	rules.apply_action(game, {"action_type": "play_card", "card": p1.hand.cards[0], "blocked_type": "Imbroglio"})
	rules.advance_turn(game)  # flag F→T after P1's activation turn
	var o1 = _assert_true(bool(game.metadata.get("special_round_active", false)),
		"f7 repl advance 1", "GS active after activation turn")

	game.current_player_index = 1
	game.set_current_player(p2)
	rules.apply_action(game, {"action_type": "play_card", "card": p2.hand.cards[0], "blocked_type": "Gold"})
	rules.advance_turn(game)  # must NOT end here (flag was reset on replacement)
	var o2 = _assert_true(bool(game.metadata.get("special_round_active", false)),
		"f7 repl advance 2", "replaced GS must survive the first advance after replacement")
	var o3 = _assert_eq(str(game.metadata.get("special_round_player_id", "")), "p2",
		"f7 repl advance 3", "P2 is the GS activator")

	rules.advance_turn(game)  # P1's restricted turn ends
	var o4 = _assert_true(bool(game.metadata.get("special_round_active", false)),
		"f7 repl advance 4", "GS still active during P1's turn")
	rules.advance_turn(game)  # P2's NEXT turn completes → GS ends
	var o5 = _assert_true(!game.metadata.get("special_round_active", false),
		"f7 repl advance 5", "GS must end after the activator's next turn")
	if o1 and o2 and o3 and o4 and o5:
		_test("f7 replacement survives advance")
		return "  F7 replacement lifecycle: [PASS]\n"
	return "  F7 replacement lifecycle: [FAIL]\n"


func _test_f7_gdv_after_gs_no_stale_block():
	"""After 89 replaces a GS, GdV playability is not affected by the stale block."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(3, 0))
	p1.receive_card(gold_card(23))
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(card89(0))
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 12,
			"plateau_cards": [gold_card(12)],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": "Incremento",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.current_player_index = 1
	game.set_current_player(p2)
	rules.apply_action(game, {"action_type": "play_card", "card": p2.hand.cards[0]})
	rules.advance_turn(game)  # now P1's turn during GdV

	var actions = rules.get_available_actions(game)
	var play_cids = _f7_play_cids(actions)
	var has_inc = false
	var has_gold = false
	for c in play_cids:
		if c != null and c.card_id == "+3_0":
			has_inc = true
		if c != null and c.card_id == "gold_23":
			has_gold = true
	var o1 = _assert_true(has_inc, "f7 gdv stale block", "increments must be playable in GdV despite stale GS block")
	var o2 = _assert_true(!has_gold, "f7 gdv stale gold", "GdV allows only Orange cards and +11")
	if o1 and o2:
		_test("f7 gdv after gs no stale block")
		return "  F7 GdV no stale block:  [PASS]\n"
	return "  F7 GdV no stale block:  [FAIL]\n"


func _test_f7_activator_over_100_bounces():
	"""GS activator: 96+5=101 → bounce to 99, no victory."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(5, 0))
	var game = make_game(
		[p1],
		[],
		null,
		{
			"piatto": 96,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": "Imbroglio",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	rules.apply_action(game, {"action_type": "play_card", "card": p1.hand.cards[0]})
	var o1 = _assert_eq(game.metadata["piatto"], 99, "f7 activator bounce", "101 must bounce to 99")
	var o2 = _assert_true(game.winner == null, "f7 activator bounce winner", "GS activator must bounce like everyone else")
	if o1 and o2:
		_test("f7 gs activator over 100 bounces")
		return "  F7 GS activator bounces: [PASS]\n"
	return "  F7 GS activator bounces: [FAIL]\n"


func _test_f7_activator_exact_100_wins():
	"""GS activator: 97+3=100 → normal victory."""
	var rules = Rules.new()
	var p1 = PlayerData.new("p1", "P1")
	p1.receive_card(increment_card(3, 0))
	var game = make_game(
		[p1],
		[],
		null,
		{
			"piatto": 97,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "safe",
			"blocked_type": "Imbroglio",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	rules.apply_action(game, {"action_type": "play_card", "card": p1.hand.cards[0]})
	var o1 = _assert_eq(game.metadata["piatto"], 100, "f7 activator win", "100 must be kept")
	var o2 = _assert_true(game.winner != null and game.winner.player_id == "p1",
		"f7 activator win winner", "GS activator wins at exactly 100")
	if o1 and o2:
		_test("f7 gs activator exact 100 wins")
		return "  F7 GS activator 100 win: [PASS]\n"
	return "  F7 GS activator 100 win: [FAIL]\n"


func _test_f7_change_when_no_playable_in_gs():
	"""GS with blocked type == the player's only card type: RESET_HAND + Cambio."""
	var rules = Rules.new()
	var ctx = _f7_gs_context([imbroglio_card(0)], [gold_card(12)], 50, "Imbroglio")
	var game = ctx["game"]
	var actions = rules.get_available_actions(game)
	var has_reset = false
	var has_play = false
	var change_count = 0
	for a in actions:
		if a["action_type"] == "reset_hand":
			has_reset = true
		elif a["action_type"] == "play_card":
			has_play = true
		elif a["action_type"] == "change_card":
			change_count += 1
	var o1 = _assert_true(has_reset, "f7 no playable reset", "RESET_HAND must be offered")
	var o2 = _assert_true(!has_play, "f7 no playable play", "no PLAY_CARD when every card is blocked")
	var o3 = _assert_eq(change_count, 1, "f7 no playable cambio", "Cambio Carta must stay available")
	if o1 and o2 and o3:
		_test("f7 cambio when no playable in GS")
		return "  F7 Cambio in GS:        [PASS]\n"
	return "  F7 Cambio in GS:        [FAIL]\n"


func _test_f7_imbroglio_playable_in_gs_when_not_blocked():
	"""GS blocking Gold: Imbroglio is still playable (Orange filter is GdV-only)."""
	var rules = Rules.new()
	var ctx = _f7_gs_context([imbroglio_card(0), gold_card(34)], [gold_card(12)], 50, "Gold")
	var game = ctx["game"]
	var actions = rules.get_available_actions(game)
	var play_cids = _f7_play_cids(actions)
	var has_imb = false
	var has_gold = false
	for c in play_cids:
		if c != null and c.card_id == "imbroglio_0":
			has_imb = true
		if c != null and c.card_id == "gold_34":
			has_gold = true
	var o1 = _assert_true(has_imb, "f7 gs imbroglio", "Imbroglio must be playable when not blocked")
	var o2 = _assert_true(!has_gold, "f7 gs gold blocked", "blocked Gold must be filtered")
	if o1 and o2:
		_test("f7 imbroglio playable in GS when not blocked")
		return "  F7 GS Imbroglio play:   [PASS]\n"
	return "  F7 GS Imbroglio play:   [FAIL]\n"


func _test_f7_gdv_still_excludes_imbroglio():
	"""GdV: only Orange cards and +11, Imbroglio excluded as before."""
	var p1 = PlayerData.new("p1", "P1")
	var p2 = PlayerData.new("p2", "P2")
	p2.receive_card(imbroglio_card(0))
	p2.receive_card(increment_card(3, 0))
	var game = make_game(
		[p1, p2],
		[],
		null,
		{
			"piatto": 89,
			"plateau_cards": [],
			"special_round_active": true,
			"special_round_player_id": "p1",
			"special_round_type": "advantage",
			"turn_phase": "start",
			"target_score": 100,
		}
	)
	game.current_player_index = 1
	game.set_current_player(p2)
	var rules = Rules.new()
	var actions = rules.get_available_actions(game)
	var play_cids = _f7_play_cids(actions)
	var has_inc = false
	var has_imb = false
	for c in play_cids:
		if c != null and c.card_id == "+3_0":
			has_inc = true
		if c != null and c.card_id == "imbroglio_0":
			has_imb = true
	var o1 = _assert_true(has_inc, "f7 gdv inc", "increments must be playable in GdV")
	var o2 = _assert_true(!has_imb, "f7 gdv imb", "Imbroglio must stay excluded in GdV")
	if o1 and o2:
		_test("f7 gdv still excludes imbroglio")
		return "  F7 GdV excludes Imbr.:  [PASS]\n"
	return "  F7 GdV excludes Imbr.:  [FAIL]\n"
