extends Node

# Diagnostic script for Passaggio A — Domain port.
# Verifies that the GDScript domain classes match the Python reference.
#
# Run from Godot 3.4.4:
#   ./Godot3 --path /path/to/project tests/domain_test.tscn --no-window
#
# NOTE: Load scripts explicitly to avoid class_name resolution issues in CLI mode.

var _GameConstants
var _CardData
var _Deck
var _Hand
var _PlayerData
var _GameState
var _CardDatabase

var GameConstants  # assigned in _ready()
var CardData
var Deck
var Hand
var PlayerData
var GameState
var CardDatabase


func _ready():
	# Load all engine scripts explicitly (class_name not reliable in CLI mode)
	_GameConstants = load("res://engine/GameConstants.gd")
	_CardData = load("res://engine/CardData.gd")
	_Deck = load("res://engine/Deck.gd")
	_Hand = load("res://engine/Hand.gd")
	_PlayerData = load("res://engine/PlayerData.gd")
	_GameState = load("res://engine/GameState.gd")
	_CardDatabase = load("res://engine/CardDatabase.gd")

	GameConstants = _GameConstants
	CardData = _CardData
	Deck = _Deck
	Hand = _Hand
	PlayerData = _PlayerData
	GameState = _GameState
	CardDatabase = _CardDatabase

	randomize()
	var report = _run_all_checks()
	print(report)
	get_tree().quit(0)


# Helper: create CardData via loaded script
func _deck():
	return CardDatabase.new().build_deck()


# ---------------------------------------------------------------------------
# 1. build_deck() — total count
# ---------------------------------------------------------------------------
func _check_build_deck():
	var out = ""
	out += "\n1. build_deck() — 60 cards\n"

	var deck = _deck()
	var count = deck.size()
	out += "   Total cards: " + str(count)

	if count == 60:
		out += "  [PASS]\n"
	else:
		out += "  [FAIL — expected 60]\n"

	out += "   First card:  " + deck[0].card_id + "\n"
	out += "   Last card:   " + deck[deck.size() - 1].card_id + "\n"
	return out


# ---------------------------------------------------------------------------
# 2. Uniqueness of all card_ids
# ---------------------------------------------------------------------------
func _check_card_id_uniqueness():
	var out = ""
	out += "\n2. card_id uniqueness\n"

	var deck = _deck()
	var ids = {}
	var duplicates = []
	for c in deck:
		var cid = c.card_id
		if ids.has(cid):
			duplicates.append(cid)
		else:
			ids[cid] = true

	if duplicates.empty():
		out += "   All " + str(deck.size()) + " card_ids are unique.  [PASS]\n"
	else:
		out += "   Duplicates found: " + str(duplicates) + "  [FAIL]\n"
	return out


# ---------------------------------------------------------------------------
# 3. Count by card type
# ---------------------------------------------------------------------------
func _check_card_counts_by_type():
	var out = ""
	out += "\n3. Card counts by type\n"

	var deck = _deck()
	var counts = {}
	for c in deck:
		var ct = c.metadata.get("card_type", "unknown")
		counts[ct] = counts.get(ct, 0) + 1

	var expected_type_counts = {
		"increment": 30,
		"jolly": 10,
		"gold": 7,
		"special": 8,   # 3 x card89 + 5 x +11
		"imbroglio": 5,
	}

	var all_ok = true
	for t in expected_type_counts.keys():
		var got = counts.get(t, 0)
		var exp_count = expected_type_counts[t]
		if got == exp_count:
			out += "   " + t + ": " + str(got) + " [PASS]\n"
		else:
			out += "   " + t + ": " + str(got) + " [FAIL - expected " + str(exp_count) + "]\n"
			all_ok = false

	if all_ok:
		out += "   All type counts match Python.  [PASS]\n"
	else:
		out += "   Type count mismatch!  [FAIL]\n"

	return out


# ---------------------------------------------------------------------------
# 4. Count by value
# ---------------------------------------------------------------------------
func _check_card_counts_by_value():
	var out = ""
	out += "\n4. Card counts by value\n"

	var deck = _deck()
	var by_type_value = {}

	for c in deck:
		var ct = c.metadata.get("card_type", "unknown")
		var val = c.value
		var key = str(ct) + ":" + str(val)
		by_type_value[key] = by_type_value.get(key, 0) + 1

	# Increment: each value 1..10 should have exactly 3 copies
	out += "   Increment cards per value:\n"
	for v in GameConstants.INCREMENT_VALUES:
		var key = "increment:" + str(v)
		var got = by_type_value.get(key, 0)
		var status = "[PASS]" if got == 3 else "[FAIL - expected 3]"
		out += "     +" + str(v) + ": " + str(got) + " " + status + "\n"

	# Gold: each value should have exactly 1 copy
	out += "   Gold cards per value:\n"
	for v in GameConstants.GOLD_VALUES:
		var key = "gold:" + str(v)
		var got = by_type_value.get(key, 0)
		var status = "[PASS]" if got == 1 else "[FAIL - expected 1]"
		out += "     " + str(v) + ": " + str(got) + " " + status + "\n"

	# 89 cards
	var c89_count = by_type_value.get("special:89", 0)
	out += "   89 cards: "
	if c89_count == 3:
		out += str(c89_count) + " [PASS]\n"
	else:
		out += str(c89_count) + " [FAIL - expected 3]\n"

	# +11 cards
	var p11_count = by_type_value.get("special:11", 0)
	out += "   +11 cards: "
	if p11_count == 5:
		out += str(p11_count) + " [PASS]\n"
	else:
		out += str(p11_count) + " [FAIL - expected 5]\n"

	return out


# ---------------------------------------------------------------------------
# 5. Deck operations
# ---------------------------------------------------------------------------
func _check_deck_operations():
	var out = ""
	out += "\n5. Deck operations\n"

	var deck_src = _deck()
	var d = Deck.new(deck_src.duplicate())

	if d.size() == 60:
		out += "   Initial size:    60 [PASS]\n"
	else:
		out += "   Initial size:    " + str(d.size()) + " [FAIL]\n"

	var drawn = d.draw()
	out += "   Draw one:        " + drawn.card_id + "\n"

	if d.size() == 59:
		out += "   Size after draw: 59 [PASS]\n"
	else:
		out += "   Size after draw: " + str(d.size()) + " [FAIL]\n"

	if !d.is_empty():
		out += "   is_empty:        false [PASS]\n"
	else:
		out += "   is_empty:        true [FAIL]\n"

	# Shuffle: verify no cards lost, no cards duplicated
	var before_ids = []
	for c in d.cards:
		before_ids.append(c.card_id)

	d.shuffle()

	var after_ids = []
	for c in d.cards:
		after_ids.append(c.card_id)

	var shuffle_pass = true
	if d.size() != 59:
		out += "   Shuffle — size unchanged: " + str(d.size()) + " [FAIL - expected 59]\n"
		shuffle_pass = false
	else:
		out += "   Shuffle — size unchanged: 59 [PASS]\n"

	# Check same cards present
	var before_dict = {}
	for cid in before_ids:
		before_dict[cid] = before_dict.get(cid, 0) + 1
	var after_dict = {}
	for cid in after_ids:
		after_dict[cid] = after_dict.get(cid, 0) + 1

	var cards_match = true
	for cid in before_dict.keys():
		if before_dict[cid] != after_dict.get(cid, 0):
			cards_match = false
			break
	for cid in after_dict.keys():
		if after_dict[cid] != before_dict.get(cid, 0):
			cards_match = false
			break

	if shuffle_pass and cards_match:
		out += "   Shuffle — no cards lost/duplicated: [PASS]\n"
	else:
		out += "   Shuffle — no cards lost/duplicated: [FAIL]\n"

	d.clear()
	if d.is_empty():
		out += "   Clear — is_empty: true [PASS]\n"
	else:
		out += "   Clear — is_empty: false [FAIL]\n"

	return out


# ---------------------------------------------------------------------------
# 6. Hand operations
# ---------------------------------------------------------------------------
func _check_hand_operations():
	var out = ""
	out += "\n6. Hand operations\n"

	var deck = _deck()
	var c1 = deck[0]
	var c2 = deck[1]
	var c3 = deck[2]

	var h = Hand.new()

	if h.is_empty():
		out += "   Empty hand is_empty: true [PASS]\n"
	else:
		out += "   Empty hand is_empty: false [FAIL]\n"

	h.add_card(c1)
	h.add_card(c2)
	h.add_card(c3)

	if h.size() == 3:
		out += "   Size after add 3: 3 [PASS]\n"
	else:
		out += "   Size after add 3: " + str(h.size()) + " [FAIL]\n"

	if h.contains(c1):
		out += "   Contains c1: true [PASS]\n"
	else:
		out += "   Contains c1: false [FAIL]\n"

	var removed = h.remove_card(c2)
	if removed != null and removed.card_id == c2.card_id:
		out += "   Remove c2 — returned: " + removed.card_id + " [PASS]\n"
	else:
		out += "   Remove c2 — returned: null [FAIL]\n"

	if h.size() == 2:
		out += "   Size after remove: 2 [PASS]\n"
	else:
		out += "   Size after remove: " + str(h.size()) + " [FAIL]\n"

	if !h.contains(c2):
		out += "   Contains c2 after remove: false [PASS]\n"
	else:
		out += "   Contains c2 after remove: true [FAIL]\n"

	# Remove non-existent card -> null
	var fake = CardData.new("fake_0", "Fake", null, "none", {})
	var removed_null = h.remove_card(fake)
	if removed_null == null:
		out += "   Remove fake -> null: [PASS]\n"
	else:
		out += "   Remove fake -> not null: [FAIL]\n"

	h.clear()
	if h.is_empty():
		out += "   Clear — is_empty: true [PASS]\n"
	else:
		out += "   Clear — is_empty: false [FAIL]\n"

	return out


# ---------------------------------------------------------------------------
# 7. PlayerData operations
# ---------------------------------------------------------------------------
func _check_player_operations():
	var out = ""
	out += "\n7. PlayerData operations\n"

	var deck = _deck()

	var p = PlayerData.new("player_1", "Player 1")

	if p.player_id == "player_1":
		out += "   player_id: player_1 [PASS]\n"
	else:
		out += "   player_id: " + p.player_id + " [FAIL]\n"

	if p.hand.size() == 0:
		out += "   Empty hand size: 0 [PASS]\n"
	else:
		out += "   Empty hand size: " + str(p.hand.size()) + " [FAIL]\n"

	p.receive_card(deck[0])
	p.receive_card(deck[1])
	p.receive_card(deck[2])

	if p.hand.size() == 3:
		out += "   After receive 3: 3 [PASS]\n"
	else:
		out += "   After receive 3: " + str(p.hand.size()) + " [FAIL]\n"

	if p.has_card(deck[0]):
		out += "   has_card(deck[0]): true [PASS]\n"
	else:
		out += "   has_card(deck[0]): false [FAIL]\n"

	var played = p.play_card(deck[0])
	if played != null and played.card_id == deck[0].card_id:
		out += "   play_card — returned: " + played.card_id + " [PASS]\n"
	else:
		out += "   play_card — returned: null [FAIL]\n"

	if p.hand.size() == 2:
		out += "   Hand size after play: 2 [PASS]\n"
	else:
		out += "   Hand size after play: " + str(p.hand.size()) + " [FAIL]\n"

	p.clear_hand()
	if p.hand.size() == 0:
		out += "   After clear_hand: 0 [PASS]\n"
	else:
		out += "   After clear_hand: " + str(p.hand.size()) + " [FAIL]\n"

	return out


# ---------------------------------------------------------------------------
# 8. GameState operations
# ---------------------------------------------------------------------------
func _check_gamestate_operations():
	var out = ""
	out += "\n8. GameState operations\n"

	var gs = GameState.new()

	if gs.phase == GameConstants.GamePhase.SETUP:
		out += "   Default phase: " + str(gs.phase) + " [PASS]\n"
	else:
		out += "   Default phase: " + str(gs.phase) + " [FAIL]\n"

	if gs.deck != null and gs.deck.size() == 0:
		out += "   Default deck size: 0 [PASS]\n"
	else:
		out += "   Default deck: not empty [FAIL]\n"

	var p1 = PlayerData.new("p1", "Player 1")
	var p2 = PlayerData.new("p2", "Player 2")
	var p3 = PlayerData.new("p3", "Player 3")
	gs.add_player(p1)
	gs.add_player(p2)
	gs.add_player(p3)

	gs.set_current_player(p2)
	var cp = gs.current_player()
	if cp != null and cp.player_id == "p2":
		out += "   current_player after set(p2): p2 [PASS]\n"
	else:
		out += "   current_player: null [FAIL]\n"

	if gs.current_player_index == 1:
		out += "   current_player_index: 1 [PASS]\n"
	else:
		out += "   current_player_index: " + str(gs.current_player_index) + " [FAIL]\n"

	gs.set_current_player(null)
	if gs.current_player() == null:
		out += "   set_current_player(null): null [PASS]\n"
	else:
		out += "   set_current_player(null): not null [FAIL]\n"

	gs.set_winner(p1)
	if gs.winner != null and gs.winner.player_id == "p1":
		out += "   Winner: p1 [PASS]\n"
	else:
		out += "   Winner: null [FAIL]\n"

	gs.set_phase(GameConstants.GamePhase.PLAYING)
	if gs.phase == GameConstants.GamePhase.PLAYING:
		out += "   Phase after set: " + str(gs.phase) + " [PASS]\n"
	else:
		out += "   Phase after set: " + str(gs.phase) + " [FAIL]\n"

	return out


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
func _run_all_checks():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Domain Port Diagnostic\n"
	out += "========================================\n"

	out += _check_build_deck()
	out += _check_card_id_uniqueness()
	out += _check_card_counts_by_type()
	out += _check_card_counts_by_value()
	out += _check_deck_operations()
	out += _check_hand_operations()
	out += _check_player_operations()
	out += _check_gamestate_operations()

	out += "\n========================================\n"
	out += " All domain checks completed.\n"
	out += "========================================\n"
	return out
