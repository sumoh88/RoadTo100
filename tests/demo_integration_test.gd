extends Node

# Headless integration test: runs 3+ complete games through GameController
# with real LocalGameEngine and auto-action selection (DebugDemo-like).
# Validates that game over is reached without errors.

var GameController = load("res://scripts/GameController.gd")
var MockPresenter = load("res://tests/mock_presenter.gd")

var passed = 0
var failed = 0
var games_completed = 0
var target_games = 5
var max_turns_per_game = 200

# F7: +11 Gold chain (mirrors RoadTo100Rules.GOLD_CHAIN) — decides whether a
# +11 play activates a Safe Round (23-78) vs the Advantage Round (89).
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}
const SAFE_ROUND_CHOICES = ["Incremento", "Gold", "Imbroglio"]

var _gc = null
var _mp = null
var _bp = null
var _hp = null
var _tp = null


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
		print("  FAIL: " + str(msg))
	return cond


func _setup_game():
	_gc = GameController.new()
	# Real provider
	_mp = load("res://engine/LocalGameEngine.gd").new()
	_gc.set_provider(_mp)

	# Mock presenters (null-safe — GC checks has_method before calling)
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

	_gc.connect("action_applied", self, "_on_action_applied")
	add_child(_gc)


func _cleanup():
	if _gc != null:
		remove_child(_gc)
		_gc.free()
		_gc = null
	if _bp != null: _bp.free(); _bp = null
	if _hp != null: _hp.free(); _hp = null
	if _tp != null: _tp.free(); _tp = null
	_mp = null


func _on_action_applied(result):
	pass  # just for signal relay


func _run_single_game(game_num):
	_setup_game()
	var snap = null

	# Start game
	_gc.start_game(4)

	# Wait for game_started signal to process
	yield(get_tree(), "idle_frame")

	snap = _gc.get_last_snapshot()
	if snap == null:
		_assert(false, "Game " + str(game_num) + ": snapshot null after start")
		_cleanup()
		return

	var turn = 0
	var winner = null

	while turn < max_turns_per_game:
		# Process pending events
		yield(get_tree(), "idle_frame")

		snap = _gc.get_last_snapshot()
		if snap == null:
			break

		winner = snap.get("winner", null)
		if winner != null:
			break

		var state = _gc.get_state()
		# Avoid acting during WAITING_FOR_CHOICE or ANIMATING states
		if state == 3 or state == 5 or state == 4:
			if state == 3:
				# GC auto-opened a blocking popup — answer it directly.
				for a in snap.get("available_actions", []):
					if a.get("action_type", "") == "reset_hand":
						_gc.perform_action({"action_type": "reset_hand"})
						break
			yield(get_tree(), "idle_frame")
			continue

		if state != 1 and state != 2:  # READY_FOR_INPUT or CARD_SELECTED
			yield(get_tree(), "idle_frame")
			continue

		# Get available actions from snapshot
		var acts = snap.get("available_actions", [])
		if acts.empty():
			yield(get_tree(), "idle_frame")
			continue

		# Pick an action: prefer play_card, then change_card, then reset_hand
		var chosen = null
		for pref in ["play_card", "change_card", "reset_hand"]:
			var cs = []
			for a in acts:
				if a.get("action_type", "") == pref:
					cs.append(a)
			if not cs.empty():
				chosen = cs[randi() % cs.size()]
				break

		if chosen == null:
			chosen = acts[0]

		var at = chosen.get("action_type", "")
		var cid = chosen.get("card_id", "")

		if at == "reset_hand":
			_gc.perform_action({"action_type": "reset_hand"})
		elif at == "play_card" or at == "change_card":
			var action_dict = {"action_type": at, "card_id": cid}
			var choices = chosen.get("choices", [])
			if choices.size() > 0:
				var params = choices[0].get("parameters", {})
				for k in params.keys():
					action_dict[k] = params[k]
			# F7: a play_card that activates a Safe Round carries its blocked_type
			# on the same single action.
			if at == "play_card" and _play_activates_safe_round(snap, cid):
				action_dict["blocked_type"] = SAFE_ROUND_CHOICES[randi() % SAFE_ROUND_CHOICES.size()]
			_gc.perform_action(action_dict)

		turn += 1

		# Let the synchronous action cycle complete
		yield(get_tree(), "idle_frame")

	# Check result
	if winner != null:
		games_completed += 1
		_assert(true, "Game " + str(game_num) + ": COMPLETE — " + str(winner) + " wins in " + str(turn) + " turns")
	else:
		_assert(false, "Game " + str(game_num) + ": NO WINNER after " + str(turn) + " turns")

	_cleanup()


func _play_activates_safe_round(snapshot, card_id):
	"""F7: true when playing this card activates a Safe Round — a normal Gold,
	or a +11 played immediately after a normal Gold whose next chain value is
	23-78 (a chain to 89 activates the Advantage Round instead)."""
	var card = null
	for p in snapshot.get("players", []):
		for c in p.get("hand", []):
			if c.get("card_id", "") == card_id:
				card = c
				break
		if card != null:
			break
	if card == null:
		return false
	var ct = str(card.get("card_type", ""))
	if ct == "gold":
		return true
	if ct == "special" and str(card.get("name", "")) == "+11":
		var plateau_cards = snapshot.get("plateau_cards", [])
		if plateau_cards.size() > 0:
			var last = plateau_cards[plateau_cards.size() - 1]
			if str(last.get("card_type", "")) == "gold":
				var chain_val = GOLD_CHAIN.get(int(last.get("value", 0)), null)
				return chain_val != null and chain_val != 89
	return false


func _run_all():
	var out = ""
	out += "========================================\n"
	out += " RoadTo100 — Demo Integration Test\n"
	out += "   (GameController + LocalGameEngine)\n"
	out += "========================================\n"
	out += " Running " + str(target_games) + " headless games...\n\n"

	for i in range(target_games):
		var g = _run_single_game(i + 1)
		if g is GDScriptFunctionState:
			yield(g, "completed")

	out += "\n--- Summary ---\n"
	out += "  Games completed: " + str(games_completed) + " / " + str(target_games) + "\n"
	out += "  Assertions passed: " + str(passed) + "\n"
	out += "  Assertions failed: " + str(failed) + "\n"
	if failed > 0:
		out += "\nFAIL: Some games did not reach game over!\n"
	else:
		out += "\nALL GAMES COMPLETE — Integration verified.\n"
	out += "========================================\n"
	return out
