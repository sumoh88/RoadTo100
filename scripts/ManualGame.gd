extends Node

# ManualGame — 1 Human + 3 CPU playable mode.
# Routes all game logic through GameController (parent node).
# CPU players: chosen automatically from available_actions (same as DebugDemo).
# player_2 uses the new RoadTo100AI; other CPUs use random selection.
# Human player (local_player_id): automation pauses, UI input handles the turn.
# After the human completes their action, CPU resumes automatically.

var _gc = null
var timer = null
var running = false
var max_turns = 1000
var step_delay_ms = 600

var BGsQnty = 4

# F7: +11 Gold chain (mirrors RoadTo100Rules.GOLD_CHAIN) — decides whether a
# +11 play activates a Safe Round (23-78) vs the Advantage Round (89).
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}
const SAFE_ROUND_CHOICES = ["Incremento", "Gold", "Imbroglio"]

var stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}

# AI instances for each CPU player with different personalities
var _ai_player2 = null  # Balanced (default)
var _ai_player3 = null  # Aggressive
var _ai_player4 = null  # Tactical/Prudent


func _ready():
	_gc = get_parent()
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = step_delay_ms / 1000.0
	timer.connect("timeout", self, "_on_timer_timeout")
	add_child(timer)

	# Initialize AI for player_2 (balanced — default weights)
	var ai_class = load("res://engine/RoadTo100AI.gd")
	_ai_player2 = ai_class.new()

	# Initialize AI for player_3 (aggressive)
	_ai_player3 = ai_class.new()
	_ai_player3.W_INCREMENT_HIGH = 8          # Strong preference for big jumps
	_ai_player3.W_INCREMENT_MED = 4
	_ai_player3.W_PLATEAU_DANGER = 6          # Accepts higher plateau risk for progress
	_ai_player3.W_JOLLY_FLEXIBILITY = 25      # Aggressive Jolly use
	_ai_player3.W_GOLD_ACTIVATE_SR = 80       # Willing to start SR
	_ai_player3.W_PLUS11_NORMAL = 60          # More willing to use +11
	_ai_player3.W_PLUS11_HOLD_BACK = -50      # Less conservative about +11

	# Initialize AI for player_4 (tactical/prudent)
	_ai_player4 = ai_class.new()
	_ai_player4.W_INCREMENT_HIGH = 2          # Prefer smaller, safer increments
	_ai_player4.W_PLATEAU_DANGER = 30         # Very danger-averse, uses bounce defensively
	_ai_player4.W_JOLLY_FLEXIBILITY = 8       # Conservative Jolly use
	_ai_player4.W_GOLD_ACTIVATE_SR = -40       # Less willing to start SR
	_ai_player4.W_PLUS11_HOLD_BACK = -200     # Very conservative about +11
	_ai_player4.W_IMBROGLIO_STRATEGIC = 50    # Prefer Imbroglio for control

	if _gc != null and _gc.has_signal("action_applied"):
		_gc.connect("action_applied", self, "_on_gc_action_applied")

func start_game():
#	if running:
#		return
	var bgImage = "res://imgs/tableBG"+str((randi() % BGsQnty) + 1)+".png"
	var main = get_tree().get_root().find_node("Main",true, false)
	var bgImagePath = main.get_node("Background/BackgroundImage")
	bgImagePath.texture = load(bgImage)
	randomize()
	if _gc == null:
		print("[ManualGame] ERROR: No GameController reference.")
		return

	# Stop any sibling automation (e.g. DebugDemo) so it never plays the
	# human's turn while a manual game is running.
	_stop_sibling_automation()

	print("\n========== PARTITA 1 UMANO + 3 CPU ==========")
	running = true
	stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}

	_gc.start_game(4)
	_schedule_next_step()


func _stop_sibling_automation():
	var p = get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c == self:
			continue
		if c.has_method("stop_demo"):
			c.stop_demo()
		elif c.has_method("stop"):
			c.stop()


func stop():
	if not running:
		return
	running = false
	timer.stop()
	print("[ManualGame] Stopped.")


func _schedule_next_step():
	var jitter = randi() % 201 - 100
	var delay = max(0.05, (step_delay_ms + jitter) / 1000.0)
	timer.wait_time = delay
	timer.start()


func _on_timer_timeout():
	if not running or _gc == null:
		return

	var state = _gc.get_state()
	var snapshot = _gc.get_last_snapshot()

	# Game over — stop everything
	if state == 7 or (snapshot != null and snapshot.get("winner", null) != null):
		stop()
		return

	# No snapshot yet or in a transient state that will resolve on its own
	if snapshot == null:
		_schedule_next_step()
		return

	var lid = snapshot.get("local_player_id", "player_1")

	# If it's the HUMAN's turn, don't act — let UI handle it.
	if _is_local_turn(snapshot, lid):
		_schedule_next_step()
		return

	# CPU turn — debug current state
	var cur_player_idx = int(snapshot.get("current_player_index", -1))
	var players = snapshot.get("players", [])
	var cur_player_id = ""
	var cur_hand = []

	if cur_player_idx >= 0 and cur_player_idx < players.size():
		cur_player_id = str(players[cur_player_idx].get("id", ""))

		for c in players[cur_player_idx].get("hand", []):
			cur_hand.append(str(c.get("card_id", "")))

	print("[CPU DEBUG] player=" + cur_player_id)
	print("[CPU DEBUG] state=" + str(state))
	print("[CPU DEBUG] hand=[" + PoolStringArray(cur_hand).join(", ") + "]")

	# CPU turn — check if we can act
	# Only act when READY_FOR_INPUT(1) or CARD_SELECTED(2) — same as DebugDemo
	if state != 1 and state != 2:
		print("[CPU DEBUG] not ready for input, state=" + str(state))

		# WAITING_FOR_CHOICE (3): a popup is open; the GC opens it, and for CPU
		# we resolve it via _handle_cpu_choice (value choices / reset hand).
		if state == 3:
			print("[CPU DEBUG] WAITING_FOR_CHOICE -> _handle_cpu_choice")
			_handle_cpu_choice(snapshot, lid)
			return

		_schedule_next_step()
		return

	# CPU performs action — all CPU players use AI (no random behavior)
	var acts = snapshot.get("available_actions", [])

	print("[CPU DEBUG] available_actions=" + str(acts))

	if acts.empty():
		print("[CPU DEBUG] STUCK CANDIDATE: available_actions is EMPTY")
		_schedule_next_step()
		return

	var action
	if cur_player_id == "player_2" and _ai_player2 != null:
		# Use the new strategic AI for player_2
		action = _ai_player2.select_action(acts, snapshot)
	elif cur_player_id == "player_3" and _ai_player3 != null:
		# Use aggressive AI for player_3
		action = _ai_player3.select_action(acts, snapshot)
	elif cur_player_id == "player_4" and _ai_player4 != null:
		# Use tactical/prudent AI for player_4
		action = _ai_player4.select_action(acts, snapshot)
	else:
		# Fallback: random selection (should never happen in normal play)
		action = _choose_action(acts)

	print("[CPU DEBUG] chosen_action=" + str(action))

	if action == null:
		print("[CPU DEBUG] STUCK CANDIDATE: AI returned NULL")
		_schedule_next_step()
		return

	var at = action.get("action_type", "")
	var cid = action.get("card_id", "")

	if at == "play_card" or at == "change_card":
		var action_dict = {"action_type": at, "card_id": cid}

		# If AI explicitly chose a value (Jolly/Imbroglio), use it
		if action.has("selected_value"):
			action_dict["selected_value"] = action["selected_value"]
		else:
			# Fallback: pick first available value from choices
			var choices = action.get("choices", [])
			if choices.size() > 0:
				var params = choices[0].get("parameters", {})
				for k in params.keys():
					action_dict[k] = params[k]

		# F7: a play_card that activates a Safe Round carries its blocked_type
		# on the same single action.
		if at == "play_card":
			if _play_activates_safe_round(snapshot, cid):
				action_dict["blocked_type"] = SAFE_ROUND_CHOICES[randi() % SAFE_ROUND_CHOICES.size()]

		print("[CPU DEBUG] perform_action=" + str(action_dict))
		_gc.perform_action(action_dict)

	elif at == "reset_hand":
		print("[CPU DEBUG] perform_action=reset_hand")
		_gc.perform_action({"action_type": "reset_hand"})

	_schedule_next_step()


func _is_local_turn(snapshot, local_id):
	var ci = snapshot.get("current_player_index", -1)
	var players = snapshot.get("players", [])
	if ci < 0 or ci >= players.size():
		return false
	return players[ci].get("id", "") == local_id


func _handle_cpu_choice(snapshot, lid):
	"""Handle CPU resolution of WAITING_FOR_CHOICE (value choice / reset hand).
	The GC opens these popups for both CPU and human turns. For CPU, we need
	to resolve them automatically via perform_action."""
	var acts = snapshot.get("available_actions", [])

	# Safe Round blocked_type popup — a CPU Gold/+11 play left the GC waiting
	# on this choice; resolve it so the turn never stalls in WAITING_FOR_CHOICE.
	if _gc._pending_blocked_type == true:
		_gc._on_safe_round_choice_chosen(
			SAFE_ROUND_CHOICES[randi() % SAFE_ROUND_CHOICES.size()])
		_schedule_next_step()
		return

	# Value-choice popup (Jolly/Imbroglio) — resolve from the GC's actual
	# pending values. This is robust even when the snapshot offers no choices
	# (e.g. a Jolly with an empty choices list would otherwise stall).
	if _gc._pending_valid_values.size() > 0:
		_gc._on_value_chosen(_gc._pending_valid_values[0])
		_schedule_next_step()
		return

	# Hand reset during GdV — only for non-advantage CPU players
	var cur_idx = snapshot.get("current_player_index", -1)
	var players = snapshot.get("players", [])
	if cur_idx >= 0 and cur_idx < players.size():
		var cur_pid = players[cur_idx].get("id", "")
		if cur_pid != lid:  # not local, so CPU can reset
			var has_reset = false
			var has_play = false
			for a in acts:
				var at = str(a.get("action_type", ""))
				if at == "reset_hand": has_reset = true
				elif at == "play_card": has_play = true
			if has_reset and not has_play:
				_gc.perform_action({"action_type": "reset_hand"})
				_schedule_next_step()
				return

	# Value choice (Jolly/Imbroglio) — CPU picks first valid value
	for a in acts:
		if str(a.get("action_type", "")) != "play_card":
			continue
		var choices = a.get("choices", [])
		if choices.size() > 0:
			var params = choices[0].get("parameters", {})
			var action_dict = {"action_type": "play_card", "card_id": a.get("card_id", "")}
			for k in params.keys():
				action_dict[k] = params[k]
			_gc.perform_action(action_dict)
			_schedule_next_step()
			return

	# Can't resolve — schedule retry
	_schedule_next_step()


func _choose_action(acts):
	if acts.empty():
		return null
	for p in ["play_card", "change_card", "reset_hand"]:
		var cs = []
		for a in acts:
			if a["action_type"] == p:
				cs.append(a)
		if not cs.empty():
			return cs[randi() % cs.size()]
	return acts[0]


func _play_activates_safe_round(snapshot, card_id):
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


func _on_gc_action_applied(result):
	var snapshot = result["snapshot"]
	var events = result.get("events", [])

	# Track stats
	for e in events:
		var t = e["type"]
		if t == "card_played": stats["play_card"] += 1
		elif t == "card_changed": stats["change_card"] += 1
		elif t == "hand_reset": stats["reset_hand"] += 1
		elif t == "advantage_started": stats["advantage_turns"] += 1

	# Handle game over
	if snapshot.get("winner", null) != null:
		stop()
