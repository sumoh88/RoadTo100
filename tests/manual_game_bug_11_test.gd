extends Node

# Test to reproduce +11/GS bug in ManualGame
# Scenario: Gold 45 (block Gold) → +5 → +11 CPU
# Expected: GS remains unchanged (P2, blocked_type="Gold")

var _CardData
var _Deck
var _Hand
var _PlayerData
var _GameState
var _RoadTo100Rules
var _LocalGameEngine
var _CardDatabase
var _GameController

var CardData
var Deck
var Hand
var PlayerData
var GameState
var Rules
var Engine
var CardDB
var GC

var game_ready = false
var game_started_snap = null
var test_engine = null

func _ready():
	_CardData = load("res://engine/CardData.gd")
	_Deck = load("res://engine/Deck.gd")
	_Hand = load("res://engine/Hand.gd")
	_PlayerData = load("res://engine/PlayerData.gd")
	_GameState = load("res://engine/GameState.gd")
	_RoadTo100Rules = load("res://engine/RoadTo100Rules.gd")
	_LocalGameEngine = load("res://engine/LocalGameEngine.gd")
	_CardDatabase = load("res://engine/CardDatabase.gd")
	_GameController = load("res://scripts/GameController.gd")
	
	CardData = _CardData
	Deck = _Deck
	Hand = _Hand
	PlayerData = _PlayerData
	GameState = _GameState
	Rules = _RoadTo100Rules
	Engine = _LocalGameEngine
	CardDB = _CardDatabase
	GC = _GameController
	
	var e = Engine.new()
	var gc = GC.new()
	add_child(e)
	add_child(gc)
	gc.set_provider(e)
	
	test_engine = e
	e.connect("game_started", self, "_on_game_started")
	
	# Start game with 4 players
	e.start_game(4)

func _on_game_started(snap):
	game_ready = true
	game_started_snap = snap
	var out = _run_test()
	print(out)
	get_tree().quit(0)

func _run_test():
	var passed = 0
	var failed = 0
	var failures = []
	
	var e = test_engine
	var gs = e.game_state
	var snap = game_started_snap
	if snap == null:
		return "FAIL: No snapshot received\n"

	print("Initial state:")
	print("  Players: ", snap["players"].size())
	print("  Plateau: ", snap["piatto"])
	
	# We need to set up the scenario manually
	var players = gs.players
	
	# Clear all hands
	for p in players:
		p.clear_hand()
	
	# Set up specific cards for each player
	var gold45 = CardData.new("gold_45", "45", 45, "Gold", {"card_type": "gold"})
	var plus5 = CardData.new("+5_test", "+5", 5, "Orange", {"card_type": "increment"})
	var plus11 = CardData.new("+11_test", "+11", 11, "Red", {"card_type": "special"})
	
	# P2 gets Gold 45
	players[1].receive_card(gold45)
	
	# P3 gets +5
	players[2].receive_card(plus5)
	
	# P4 gets +11 (CPU player)
	players[3].receive_card(plus11)
	
	# Add extra cards to deck for drawing
	var inc1 = CardData.new("+1", "+1", 1, "Orange", {"card_type": "increment"})
	gs.deck.add_card(inc1)
	
	# Set P2 as current player and play Gold 45
	gs.current_player_index = 1
	gs.set_current_player(players[1])

	print("\nStep 1: P2 plays Gold 45")
	e.send_action({"action_type": "play_card", "card_id": "gold_45", "blocked_type": "Gold"})

	var sr_active = gs.metadata.get("special_round_active", false)
	var sr_player = gs.metadata.get("special_round_player_id", "")
	var blocked_type = gs.metadata.get("blocked_type", "")
	print("  SR active: ", sr_active)
	print("  SR player: ", sr_player)
	print("  Blocked type: ", blocked_type)

	if not sr_active:
		failures.append("Gold 45 should activate SR")
	else:
		passed += 1

	# Step 2: P3 plays +5
	print("\nStep 2: P3 plays +5")
	gs.current_player_index = 2
	gs.set_current_player(players[2])

	e.send_action({"action_type": "play_card", "card_id": "+5_test"})

	var piatto_after_plus5 = gs.metadata.get("piatto", 0)
	print("  Plateau: ", piatto_after_plus5)
	print("  SR still active: ", gs.metadata.get("special_round_active", false))

	# Check plateau_cards before +11
	var pc = gs.metadata.get("plateau_cards", [])
	print("  Plateau cards count: ", pc.size())
	if pc.size() > 0:
		var last_pc = pc[pc.size() - 1]
		print("  Last plateau card: ", last_pc.name, " (type=", last_pc.metadata.get("card_type", "?"), ")")

	# Step 3: P4 (CPU) plays +11 - this is where the bug should manifest
	print("\nStep 3: P4 CPU plays +11")
	gs.current_player_index = 3
	gs.set_current_player(players[3])

	# Capture SR state before +11
	var sr_player_before = gs.metadata.get("special_round_player_id", "")
	var sr_blocked_before = gs.metadata.get("blocked_type", "")
	var sr_active_before = gs.metadata.get("special_round_active", false)

	e.send_action({"action_type": "play_card", "card_id": "+11_test"})

	var piatto_after_plus11 = gs.metadata.get("piatto", 0)
	print("  Plateau: ", piatto_after_plus11)
	print("  SR active: ", gs.metadata.get("special_round_active", false))
	print("  SR player: ", gs.metadata.get("special_round_player_id", ""))
	print("  Blocked type: ", gs.metadata.get("blocked_type", ""))

	# Verify GS was NOT changed by +11
	var o1 = _assert_eq(gs.metadata.get("special_round_player_id", ""), sr_player_before,
		"SR player unchanged", "Player ID should remain the same")
	var o2 = _assert_eq(gs.metadata.get("blocked_type", ""), sr_blocked_before,
		"SR blocked_type unchanged", "Blocked type should remain the same")
	var o3 = _assert_true(gs.metadata.get("special_round_active", false) == sr_active_before,
		"SR still active")

	if o1: passed += 1
	else: failures.append("SR player changed incorrectly")
	if o2: passed += 1
	else: failures.append("SR blocked_type changed incorrectly")
	if o3: passed += 1
	else: failures.append("SR activation state changed")

	# Cleanup
	e.queue_free()

	# Summary
	var out = "========================================\n"
	out += " +11/GS Bug Test\n"
	out += "========================================\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failures.size()) + "\n"
	if failures.size() > 0:
		out += "\nFailures:\n"
		for f in failures:
			out += "  - " + str(f) + "\n"
	out += "\n"
	return out

func _assert_eq(a, b, test_name, msg):
	var ok = (str(a) == str(b))
	if ok:
		print("  ✓ " + test_name)
	else:
		print("  ✗ " + test_name + ": expected '" + str(b) + "', got '" + str(a) + "'")
	return ok

func _assert_true(condition, test_name):
	var ok = bool(condition)
	if ok:
		print("  ✓ " + test_name)
	else:
		print("  ✗ " + test_name)
	return ok
