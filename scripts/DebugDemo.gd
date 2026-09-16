extends Node

# Debug/Development tool — Automatic 4-player demo.
# Routes all game logic through GameController (parent node).
# Demo only: chooses actions from available_actions, calls
# GameController.perform_action() to execute them.

var _gc = null
var timer = null
var running = false
var turn_count = 0
var max_demo_turns = 1000
var step_delay_ms = 1000
var _game_gen = -1  # Generation ID at game start — invalidates stale timers

# Short (limited) demo mode — used by the tutorial. When short_demo_turns > 0,
# the demo stops after that many turns and emits short_demo_completed.
var short_demo_turns = -1
# Optional card_type focus for a short demo (tutorial). When non-empty, the
# demo prefers play_card actions whose card_type is in this list (falls back to
# any action if none match). Empty = normal random behaviour.
var short_demo_focus_types = []

# Fixed seed used EXCLUSIVELY by tutorial short demos. Every time "Mostra" is
# pressed the RNG is re-seeded with this value so the same step always replays
# the exact same cards/turns/sequence, fully isolated from normal games (which
# keep using the global randi()).
const TUTORIAL_DEMO_SEED = 987654321
var _tutorial_rng = null

# Scripted tutorial demo mode (steps with a predefined scenario). Each step's
# "scenario" is a list of segments; each segment has a fixed setup + a scripted
# action list. Between segments the state is re-prepared (REWIND) so every
# repeat shows the identical, prepared lesson.
var scripted_mode = false
var _segments = []        # [{setup: {...}, script: [ {action...}, ... ]}]
var _seg_index = 0
var _script_index = 0
var _scripted_ticks = 0   # safety counter against a stalled script

# Hard cap on scripted ticks so a misconfigured scenario can never hang the demo.
const MAX_SCRIPTED_TICKS = 200

signal short_demo_completed

# F7: +11 Gold chain (mirrors RoadTo100Rules.GOLD_CHAIN) — decides whether a
# +11 play activates a Safe Round (23-78) vs the Advantage Round (89).
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}
const SAFE_ROUND_CHOICES = ["Incremento", "Imbroglio", "Gold"]

# Stats
var stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}


func _ready():
	_gc = get_parent()
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = step_delay_ms / 1000.0
	timer.connect("timeout", self, "_on_timer_timeout")
	add_child(timer)

	if _gc != null and _gc.has_signal("action_applied"):
		_gc.connect("action_applied", self, "_on_gc_action_applied")

	print("\n===== DEMO DIAGNOSTIC =====")
	if _gc != null:
		print("[Demo] GameController: " + str(_gc) + " path=" + str(_gc.get_path()))
	else:
		print("[Demo] CRITICAL: GameController not found!")
	print("===========================\n")


func _schedule_next_step():
	var jitter = randi() % 201 - 100
	var delay = max(0.05, (step_delay_ms + jitter) / 1000.0)
	timer.wait_time = delay
	timer.start()


func start_demo():
	if running:
		print("[Demo] Already running.")
		return
	if _gc == null:
		print("[Demo] CRITICAL: No GameController reference.")
		return

	short_demo_turns = -1  # Normal demo: no short limit.

	# Stop any sibling automation (e.g. ManualGame) so only one drives the game.
	_stop_sibling_automation()

	print("\n========== DEMO AUTOMATICA ==========")
	running = true
	turn_count = 0
	stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}

	_gc.start_game(4)
	# Capture the generation AFTER start_game increments it.
	_game_gen = _gc.get_game_generation()
	_schedule_next_step()


# Start an auto demo limited to n turns (tutorial "Mostra"). Reuses the same
# machinery as start_demo(); emits short_demo_completed when the limit is hit.
func start_short_demo(n, focus_types=null):
	if _gc == null:
		print("[Demo] CRITICAL: No GameController reference.")
		return
	short_demo_turns = n
	short_demo_focus_types = focus_types if focus_types != null else []

	# Restart cleanly even if a previous demo is running.
	stop_demo()
	_stop_sibling_automation()

	# Deterministic tutorial RNG: re-seed with the fixed value every time so the
	# same step always replays identically. Shared with the engine (shuffle +
	# starting player) and with _choose_action below — one single stream.
	if _tutorial_rng == null:
		_tutorial_rng = RandomNumberGenerator.new()
	_tutorial_rng.seed = TUTORIAL_DEMO_SEED

	print("[Demo] Short demo — max turns: " + str(n))
	running = true
	turn_count = 0
	stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}

	_gc.start_game(4, _tutorial_rng)
	_game_gen = _gc.get_game_generation()
	_schedule_next_step()


# Start a scripted tutorial demo (prepared scenario). Each segment is prepared
# (start_scenario) then its scripted actions are driven through the real UI
# flow so actual choice popups open. Between segments the state is re-prepared
# (rewind). Emits short_demo_completed when all segments finish.
func start_scripted_demo(scenario):
	if _gc == null:
		print("[Demo] CRITICAL: No GameController reference.")
		return
	scripted_mode = true
	short_demo_turns = -1

	stop_demo()
	_stop_sibling_automation()

	_segments = scenario.get("segments", [])
	_seg_index = 0
	_script_index = 0
	_scripted_ticks = 0

	print("[Demo] Scripted demo — segments: " + str(_segments.size()))
	running = true
	turn_count = 0
	stats = {"play_card":0,"change_card":0,"reset_hand":0,"advantage_turns":0}

	if _segments.size() > 0:
		_gc.start_scenario(_segments[0].get("setup", {}))
		_game_gen = _gc.get_game_generation()

	_schedule_next_step()


# Public wrapper around the per-tick demo loop so tests can drive it without
# relying on the Timer firing.
func advance_step():
	_on_timer_timeout()


func _stop_sibling_automation():
	var p = get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c == self:
			continue
		if c.has_method("stop"):
			c.stop()


func stop_demo():
	if not running: return
	running = false
	timer.stop()
	print("[Demo] Stopped.")


func _on_timer_timeout():
	if not running or _gc == null:
		return

	# Generation check — if the game was restarted, this timer callback
	# belongs to the old game and must NOT act on the new game's state.
	if _game_gen != -1 and _gc.get_game_generation() != _game_gen:
		return

	# Scripted tutorial demo drives its own prepared sequence.
	if scripted_mode:
		_on_scripted_tick()
		return

	var state = _gc.get_state()

	# Handle WAITING_FOR_CHOICE — value choice (Jolly/Imbroglio/Safe Round)
	if state == 3:
		_schedule_next_step()
		return

	# Only act when ready for input
	if state != 1 and state != 2:
		if state == 7:  # GAME_OVER — done
			return
		_schedule_next_step()  # Retry later
		return

	var snapshot = _gc.get_last_snapshot()
	if snapshot == null:
		_schedule_next_step()
		return

	var acts = snapshot.get("available_actions", [])
	if acts.empty():
		_schedule_next_step()
		return

	# Short-demo focus (tutorial): prefer cards of the requested card_types.
	var effective_acts = acts
	if short_demo_turns > 0 and short_demo_focus_types.size() > 0:
		var filtered = _filter_actions_by_focus(acts, snapshot)
		if filtered.size() > 0:
			effective_acts = filtered

	var action = _choose_action(effective_acts)
	if action == null:
		_schedule_next_step()
		return

	var at = action.get("action_type", "")
	var cid = action.get("card_id", "")

	if at == "play_card" or at == "change_card":
		var action_dict = {"action_type": at, "card_id": cid}

		# Handle Jolly/Imbroglio: pick first available value from choices
		var choices = action.get("choices", [])
		if choices.size() > 0:
			var params = choices[0].get("parameters", {})
			for k in params.keys():
				action_dict[k] = params[k]

		# F7: a play_card that activates a Safe Round carries its blocked_type
		# on the same single action.
		if at == "play_card" and _play_activates_safe_round(snapshot, cid):
			action_dict["blocked_type"] = SAFE_ROUND_CHOICES[_demo_rand() % SAFE_ROUND_CHOICES.size()]

		_gc.perform_action(action_dict)

	elif at == "reset_hand":
		_gc.perform_action({"action_type": "reset_hand"})

	_schedule_next_step()


# ---------------------------------------------------------------------------
# Scripted tutorial demo — drives prepared scenarios through the real UI flow.
# ---------------------------------------------------------------------------


func _on_scripted_tick():
	# Safety: never run forever on a misconfigured/stalled script.
	if _scripted_ticks > MAX_SCRIPTED_TICKS:
		print("[Demo] WARN: scripted tick cap reached, finishing.")
		_finish_scripted()
		return
	_scripted_ticks += 1

	if _seg_index >= _segments.size():
		_finish_scripted()
		return

	var seg = _segments[_seg_index]
	var script = seg.get("script", [])

	# Current segment's script finished -> move to the next one (REWIND).
	if _script_index >= script.size():
		_next_segment()
		return

	var step = script[_script_index]

	# Tutorial-only command: terminate the active Special Round immediately.
	# This does NOT modify the real game rules; it only allows a scripted
	# tutorial scenario to end a Special Round earlier for demonstration.
	if str(step.get("action", "")) == "end_special_round":
		var game = _gc.get_game_state() if _gc.has_method("get_game_state") else null

		if game != null:
			game.metadata["special_round_active"] = false
			game.metadata["special_round_player_id"] = null
			game.metadata["special_round_type"] = "advantage"
			game.metadata["blocked_type"] = ""
			game.metadata["_activator_has_played_next"] = false

		_script_index += 1
		_schedule_next_step()
		return

	var state = _gc.get_state()
	var cur_pid = _current_player_id()
	var is_local = (cur_pid == "player_1")
	var cid = _resolve_hand_card_id(str(step.get("card", "")))

	if cid == "":
		# Cannot resolve the scripted card — skip to avoid an infinite loop.
		print("[Demo] WARN: could not resolve scripted card '" + str(step.get("card", "")) + "'")
		_script_index += 1
		_schedule_next_step()
		return

	if state == _gc.State.WAITING_FOR_CHOICE:
		# A real choice popup is open for this play; pick the scripted value.
		if is_local:
			var bt = step.get("blocked_type", null)
			if _gc._pending_blocked_type:
				_gc._on_safe_round_choice_chosen(bt if bt != null else SAFE_ROUND_CHOICES[0])
			else:
				var sv = step.get("value", null)
				if sv == null:
					sv = 1
				_gc._on_value_chosen(sv)
		else:
			# CPU player: apply the choice directly (no UI popup).
			_perform_cpu_action(step, cid)
		_schedule_next_step()
		return

	if state == _gc.State.READY_FOR_INPUT or state == _gc.State.CARD_SELECTED:
		if is_local:
			# Local (P1): select then play. For choice cards this opens the real
			# popup (resolved on the next tick); for a plain card it completes now.
			_gc._on_card_selected(cid)
			_gc._on_play_pressed()
		else:
			# CPU player: perform the scripted action directly.
			_perform_cpu_action(step, cid)
		_schedule_next_step()
		return

	# ANIMATING / ACTION_PENDING / others: wait for the state to settle.
	_schedule_next_step()



func _current_player_id():
	var snap = _gc.get_last_snapshot()
	if snap == null:
		return ""
	var cpi = int(snap.get("current_player_index", -1))
	var players = snap.get("players", [])
	if cpi < 0 or cpi >= players.size():
		return ""
	return str(players[cpi].get("id", ""))


func _perform_cpu_action(step, cid):
	var act = {"action_type": "play_card", "card_id": cid}
	if step.has("value"):
		act["selected_value"] = step["value"]
	if step.has("blocked_type"):
		act["blocked_type"] = step["blocked_type"]
	_gc.perform_action(act)


func _next_segment():
	_seg_index += 1
	_script_index = 0
	if _seg_index < _segments.size():
		# REWIND: re-prepare the (possibly different) starting state.
		_gc.start_scenario(_segments[_seg_index].get("setup", {}))
		_game_gen = _gc.get_game_generation()
	_schedule_next_step()


func _finish_scripted():
	if running:
		running = false
		emit_signal("short_demo_completed")


# Find the card_id in the CURRENT player's hand matching a descriptor.
func _resolve_hand_card_id(desc):
	var snap = _gc.get_last_snapshot()
	if snap == null or desc == "":
		return ""
	var cpi = int(snap.get("current_player_index", -1))
	var players = snap.get("players", [])
	if cpi < 0 or cpi >= players.size():
		return ""
	for c in players[cpi].get("hand", []):
		if _card_matches_desc(c, desc):
			return str(c.get("card_id", ""))
	return ""


func _card_matches_desc(c, desc):
	var ct = str(c.get("card_type", ""))
	var name = str(c.get("name", ""))
	var v = c.get("value", null)
	if desc == "Jolly":
		return ct == "jolly" or name == "Jolly"
	elif desc == "Imbroglio":
		return ct == "imbroglio"
	elif desc == "89":
		return name == "89"
	elif desc == "+11":
		return name == "+11"
	elif str(desc).begins_with("Gold"):
		return ct == "gold" and int(str(v)) == int(str(desc).substr(4))
	elif str(desc).begins_with("+"):
		return ct == "increment" and int(str(v)) == int(str(desc).substr(1))
	return false


# RNG for demo decisions. During a tutorial short demo this draws from the
# deterministic _tutorial_rng; otherwise it falls back to the global randi()
# (normal behaviour preserved).
func _demo_rand():
	if short_demo_turns > 0 and _tutorial_rng != null:
		return _tutorial_rng.randi()
	return randi()


func _choose_action(acts):
	if acts.empty():
		return null
	# Prefer play_card, then change_card, then reset_hand
	for p in ["play_card", "change_card", "reset_hand"]:
		var cs = []
		for a in acts:
			if a["action_type"] == p:
				cs.append(a)
		if not cs.empty():
			return cs[_demo_rand() % cs.size()]
	return acts[0]


# Returns the subset of play_card actions whose card has one of the requested
# card_types (from short_demo_focus_types). Returns all `acts` unchanged when
# no focus is set. Used only to steer the tutorial short demo.
func _filter_actions_by_focus(acts, snapshot):
	if short_demo_focus_types == null or short_demo_focus_types.size() == 0:
		return acts
	var id_to_type = {}
	for p in snapshot.get("players", []):
		for c in p.get("hand", []):
			id_to_type[str(c.get("card_id", ""))] = str(c.get("card_type", ""))
	var out = []
	for a in acts:
		if str(a.get("action_type", "")) != "play_card":
			continue
		var ct = id_to_type.get(str(a.get("card_id", "")), "")
		if short_demo_focus_types.has(ct):
			out.append(a)
	return out


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


func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F10:
		if running: stop_demo()
		else: start_demo()


# ---------------------------------------------------------------------------
# GC signal relay — track events for per-turn stats
# ---------------------------------------------------------------------------

func _on_gc_action_applied(result):
	if scripted_mode:
		_handle_scripted_action_applied(result)
		return

	var snapshot = result["snapshot"]
	var events = result.get("events", [])
	turn_count += 1

	# Print turn summary
	var event_summary = []
	for e in events:
		var es = e["type"]
		if e.has("player_id"):
			es += "(" + str(e["player_id"]) + ")"
		if e.has("card_id"):
			es += "[" + str(e["card_id"]) + "]"
		event_summary.append(es)

	print("[Demo] Turn " + str(snapshot["turn_number"]) + " — " + PoolStringArray(event_summary).join(", "))

	# Print CPU hands for debugging
	print("[Demo] CPU hands:")
	for p in snapshot["players"]:
		if p["id"] == "player_1":
			continue  # Skip human player

		var card_ids = []
		for c in p["hand"]:
			card_ids.append(str(c["card_id"]))

		print("  " + str(p["id"]) + ": [" + PoolStringArray(card_ids).join(", ") + "]")

	# Track stats
	for e in events:
		var t = e["type"]
		if t == "card_played":
			stats["play_card"] += 1
		elif t == "card_changed":
			stats["change_card"] += 1
		elif t == "hand_reset":
			stats["reset_hand"] += 1
		elif t == "advantage_started":
			stats["advantage_turns"] += 1

	# Handle game over
	if snapshot.get("winner", null) != null:
		_on_game_won(snapshot)
		return

	# Short demo limit (tutorial) — stop and notify.
	if short_demo_turns > 0 and turn_count >= short_demo_turns:
		running = false
		emit_signal("short_demo_completed")
		return

	if turn_count >= max_demo_turns:
		stop_demo()


# Scripted-mode action handler: advance the script pointer and track stats.
# Deliberately does NOT stop on a winner — the segment/rewind logic controls
# flow (e.g. step 5 wins then rewinds to the next case).
func _handle_scripted_action_applied(result):
	var snapshot = result["snapshot"]
	var events = result.get("events", [])
	turn_count += 1

	if _seg_index < _segments.size() and _script_index < _segments[_seg_index].get("script", []).size():
		_script_index += 1

	for e in events:
		var t = e["type"]
		if t == "card_played":
			stats["play_card"] += 1
		elif t == "card_changed":
			stats["change_card"] += 1
		elif t == "hand_reset":
			stats["reset_hand"] += 1
		elif t == "advantage_started":
			stats["advantage_turns"] += 1

	print("[Demo] scripted turn=" + str(snapshot.get("turn_number", "?")) +
		" piatto=" + str(snapshot.get("piatto", 0)) +
		" winner=" + str(snapshot.get("winner", null)))


func _on_game_won(snapshot):
	print("\n========================================")
	print("[Demo] GAME OVER — " + str(snapshot["winner"]) + " wins!")
	print("       Turns: " + str(snapshot["turn_number"]))
	print("       Final piatto: " + str(snapshot["piatto"]))
	print("       Stats: play=" + str(stats["play_card"]) + " change=" + str(stats["change_card"]) +
		" reset=" + str(stats["reset_hand"]) +
		" adv=" + str(stats["advantage_turns"]))
	print("========================================\n")

	running = false
