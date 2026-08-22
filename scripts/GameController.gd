extends Node

# GameController — central orchestrator for the game UI.
# Manages interface states, coordinates presenters, and drives
# the GameStateProvider.
#
# Signals:
#   action_applied(result) — fired after each completed action (for debug/demo)

signal action_applied(result)
#
# States (in order of progression):
#   WAITING_FOR_STATE  — initial, no game loaded
#   READY_FOR_INPUT    — waiting for player action
#   CARD_SELECTED      — a card is selected, awaiting action type
#   WAITING_FOR_CHOICE — popup open (Jolly/Imbroglio/Gold Reveal)
#   ACTION_PENDING     — action sent to provider, awaiting result
#   ANIMATING          — animations in progress
#   INPUT_LOCKED       — explicit input block
#   GAME_OVER          — game has a winner
enum State {
	WAITING_FOR_STATE,
	READY_FOR_INPUT,
	CARD_SELECTED,
	WAITING_FOR_CHOICE,
	ACTION_PENDING,
	ANIMATING,
	INPUT_LOCKED,
	GAME_OVER,
}

# Provider
var _provider = null
var _LocalGameEngine = load("res://engine/LocalGameEngine.gd")

# Presenter references
var _board = null
var _hand = null
var _turn = null
var _card_animator = null

# Popup references
var _value_choice_popup = null
var _value_choice_label = null
var _value_btn_grid = null
var _value_cancel_btn = null
var _hand_reset_popup = null
var _hand_reset_yes_btn = null
var _hand_reset_no_btn = null

# Full-screen blocker shown while a choice popup is open so that clicking
# outside the popup neither closes it nor reaches the underlying UI.
var _choice_input_blocker = null

# Internal state
var _state = State.WAITING_FOR_STATE
var _last_snapshot = null
var _last_events = []
var _last_error = ""

# Card selection
var _selected_card_id = ""

# Pending action (for popup-driven actions)
var _pending_action_type = ""
var _pending_card_id = ""
var _pending_valid_values = []
var _pending_blocked_type = false  # F3: true when waiting for Safe Round blocked_type choice

# F3: Safe Round card type choices
const SAFE_ROUND_CHOICES = ["Incremento", "Gold", "Imbroglio"]

# F7: +11 Gold chain (mirrors RoadTo100Rules.GOLD_CHAIN) — used only to
# decide whether a +11 play will activate a Safe Round (23-78) vs the
# Advantage Round (89). Game rules stay in the provider.
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_provider(p):
	_provider = p


func start_game(player_count):
	if _provider == null:
		print("[GC] ERROR: No provider set")
		return
	_state = State.WAITING_FOR_STATE
	_last_snapshot = null
	_last_events = []
	_last_error = ""
	_selected_card_id = ""
	_provider.start_game(player_count)


func get_state():
	return _state


func get_last_snapshot():
	return _last_snapshot


func get_selected_card_id():
	return _selected_card_id


func get_last_events():
	return _last_events


func perform_action(action_dict):
	"""Send an action directly through the provider (for debug/auto-demo use).
	Bypasses user input flow. Returns after the synchronous action cycle."""
	if _provider == null:
		print("[GC] ERROR: No provider set")
		return
	# Close the specific popup if this direct call resolves it (demo/CPU path)
	var at = action_dict.get("action_type", "")
	if at == "play_card" and _value_choice_popup != null and _value_choice_popup.visible:
		_value_choice_popup.hide()
	if at == "reset_hand" and _hand_reset_popup != null and _hand_reset_popup.visible:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	_state = State.ACTION_PENDING
	_provider.send_action(action_dict)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready():
	_find_presenters()
	_find_popups()
	if _provider == null:
		_provider = _LocalGameEngine.new()
	_provider.connect("game_started", self, "_on_game_started")
	_provider.connect("action_completed", self, "_on_action_completed")
	_provider.connect("action_rejected", self, "_on_action_rejected")


func _find_presenters():
	var main = _node_up("Main")
	if main == null:
		return
	for c in main.get_children():
		var name = c.name
		if name == "BoardPresenter":
			_board = c
		elif name == "HandPresenter":
			_hand = c
			if _hand != null and _hand.has_signal("card_selected"):
				_hand.connect("card_selected", self, "_on_card_selected")
		elif name == "TurnPresenter":
			_turn = c
			if _turn != null:
				if _turn.has_signal("play_pressed"):
					_turn.connect("play_pressed", self, "_on_play_pressed")
				if _turn.has_signal("change_pressed"):
					_turn.connect("change_pressed", self, "_on_change_pressed")
				if _turn.has_signal("cancel_pressed"):
					_turn.connect("cancel_pressed", self, "_on_cancel_pressed")
		elif name == "CardAnimator":
			_card_animator = c
			if _card_animator != null and _card_animator.has_signal("animation_finished"):
				_card_animator.connect("animation_finished", self, "_on_animation_finished")


func _find_popups():
	var main = _node_up("Main")
	if main == null:
		return
	var ol = _child(main, "OverlayLayer")
	if ol == null:
		return

	_choice_input_blocker = _child(ol, "InputBlocker")

	_value_choice_popup = _child(ol, "ValueChoicePopup")
	if _value_choice_popup != null:
		var vb = _child(_value_choice_popup, "VBox")
		if vb != null:
			_value_choice_label = _child(vb, "MsgLabel")
			_value_btn_grid = _child(vb, "BtnGrid")
			_value_cancel_btn = _child(vb, "CancelBtn")
			if _value_cancel_btn != null:
				_value_cancel_btn.connect("pressed", self, "_on_value_cancel")

	_hand_reset_popup = _child(ol, "HandResetPopup")
	if _hand_reset_popup != null:
		var vb = _child(_hand_reset_popup, "VBox")
		if vb != null:
			var br = _child(vb, "BtnRow")
			if br != null:
				_hand_reset_yes_btn = _child(br, "YesBtn")
				_hand_reset_no_btn = _child(br, "NoBtn")
				if _hand_reset_yes_btn != null:
					_hand_reset_yes_btn.connect("pressed", self, "_on_hand_reset_yes")
				if _hand_reset_no_btn != null:
					_hand_reset_no_btn.connect("pressed", self, "_on_hand_reset_no")


func _child(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null


func _node_up(name):
	var p = get_parent()
	while p != null and p.name != name:
		p = p.get_parent()
	return p


func _update_choice_blocker():
	"""Show the full-screen InputBlocker while any choice popup is open, so
	clicks outside a popup are absorbed instead of closing it or reaching the
	game UI underneath."""
	if _choice_input_blocker == null:
		return
	var any_visible = false
	for p in [_value_choice_popup, _hand_reset_popup]:
		if p != null and p.visible:
			any_visible = true
			break
	_choice_input_blocker.visible = any_visible


# ---------------------------------------------------------------------------
# Card selection handler
# ---------------------------------------------------------------------------

func _on_card_selected(card_id):
	if _state == State.READY_FOR_INPUT:
		_selected_card_id = card_id
		if _hand != null and _hand.has_method("set_selected"):
			_hand.set_selected(card_id)
		_state = State.CARD_SELECTED

	elif _state == State.CARD_SELECTED:
		if card_id == _selected_card_id:
			_clear_selection()
			_state = State.READY_FOR_INPUT
		else:
			if _hand != null and _hand.has_method("clear_selection"):
				_hand.clear_selection()
			_selected_card_id = card_id
			if _hand != null and _hand.has_method("set_selected"):
				_hand.set_selected(card_id)

	# All other states: ignore click


func _clear_selection():
	_selected_card_id = ""
	if _hand != null and _hand.has_method("clear_selection"):
		_hand.clear_selection()


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_play_pressed():
	if _state == State.CARD_SELECTED and _selected_card_id != "":
		# Safe Round: a blocked card is selectable (for Cambio Carta) but not playable.
		if _is_selected_card_blocked_by_sr():
			if _turn != null and _turn.has_method("show_tip"):
				_turn.show_tip("Carta bloccata da Giro Sicuro: non giocabile")
			return
		var ct = _get_selected_card_type()
		if ct == "jolly" or ct == "imbroglio":
			# Show all theoretical values in the popup; only engine-validated
			# choices are enabled. The full range is always displayed so the
			# player can see which values are currently legal.
			var valid_vals = _play_values_for_selected_card()
			var all_vals = _full_value_range(ct)
			_open_value_choice(ct, all_vals, valid_vals)
			return
		elif _play_activates_safe_round():
			# F7: the Safe Round blocked_type is chosen BEFORE the activating
			# play_card is sent; the choice rides on the same single action.
			_open_safe_round_choice()
		else:
			perform_action({"action_type": "play_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_change_pressed():
	if _state == State.CARD_SELECTED and _selected_card_id != "":
		perform_action({"action_type": "change_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_cancel_pressed():
	if _state == State.CARD_SELECTED:
		_clear_selection()
		_state = State.READY_FOR_INPUT


# ---------------------------------------------------------------------------
# Value choice popup (Jolly / Imbroglio)
# ---------------------------------------------------------------------------

func _full_value_range(card_type):
	"""Return all theoretical selectable values for a card type."""
	var vals = []
	if card_type == "jolly":
		for v in range(1, 11): vals.append(v)
	elif card_type == "imbroglio":
		for v in range(-15, 0): vals.append(v)
		for v in range(1, 16): vals.append(v)
	return vals


func _play_values_for_selected_card():
	"""Collect the allowed selected_value choices for the selected card
	from the snapshot's available_actions (provider/rule-filtered)."""
	var vals = []
	if _selected_card_id == "" or _last_snapshot == null:
		return vals
	for a in _last_snapshot.get("available_actions", []):
		if str(a.get("action_type", "")) != "play_card":
			continue
		if str(a.get("card_id", "")) != _selected_card_id:
			continue
		for ch in a.get("choices", []):
			var params = ch.get("parameters", {})
			if params.has("selected_value"):
				vals.append(params["selected_value"])
	return vals


func _open_value_choice(card_name, all_values, valid_values):
	"""Open the value choice popup showing all theoretical values.
	Only values in valid_values (from engine) are enabled.
	If valid_values is empty, all buttons are disabled and a warning is logged."""
	_state = State.WAITING_FOR_CHOICE
	_pending_action_type = "play_card"
	_pending_card_id = _selected_card_id
	_pending_valid_values = valid_values
	_pending_blocked_type = false

	if valid_values.size() == 0:
		print("[GC] WARNING: No choices provided by engine for " + card_name + " — all options disabled")

	if _value_choice_label != null:
		_value_choice_label.text = "Scegli il valore per " + card_name

	# Clear old buttons from grid
	if _value_btn_grid != null:
		for c in _value_btn_grid.get_children():
			_value_btn_grid.remove_child(c)
			c.queue_free()

		# Add value buttons — enabled only if present in valid_values
		for v in all_values:
			var btn = Button.new()
			btn.text = str(v)
			btn.rect_min_size = Vector2(60, 40)
			if not v in valid_values:
				btn.disabled = true
				btn.modulate = Color(1, 1, 1, 0.35)
			else:
				btn.connect("pressed", self, "_on_value_chosen", [v])
			_value_btn_grid.add_child(btn)

	if _value_choice_popup != null:
		_value_choice_popup.popup()
	_update_choice_blocker()


func _on_value_chosen(value):
	if _state != State.WAITING_FOR_CHOICE:
		return
	if _pending_valid_values.size() > 0 and not value in _pending_valid_values:
		return  # Invalid value — stay in WAITING_FOR_CHOICE, popup stays open
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()
	var action = {"action_type": _pending_action_type, "card_id": _pending_card_id}
	action["selected_value"] = value
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	perform_action(action)


func _on_value_cancel():
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_pending_blocked_type = false
	_state = State.CARD_SELECTED


# ---------------------------------------------------------------------------
# Hand Reset popup (GdV: non-advantage player has no playable Orange cards)
# ---------------------------------------------------------------------------

func _check_reset_hand(snapshot):
	"""Open HandResetPopup ONLY during GdV for the local non-advantage player
	who has no playable Incremento cards."""
	if snapshot == null:
		return
	if _state == State.WAITING_FOR_CHOICE or _state == State.ACTION_PENDING or _state == State.GAME_OVER:
		return
	# Only during Giro di Vantaggio (never during Safe Round)
	var sr_type = str(snapshot.get("special_round_type", ""))
	if sr_type != "advantage":
		return
	# Only if it's the local player's turn
	var cur_idx = snapshot.get("current_player_index", -1)
	var players = snapshot.get("players", [])
	if cur_idx < 0 or cur_idx >= players.size():
		return
	var cur_pid = players[cur_idx].get("id", "")
	if cur_pid != snapshot.get("local_player_id", "player_1"):
		return
	# Only for non-advantage player
	var adv_pid = snapshot.get("special_round_player_id", null)
	if cur_pid == adv_pid:
		return
	# Check available_actions: reset_hand present, no play_card
	var acts = snapshot.get("available_actions", [])
	var has_reset = false
	var has_play = false
	for a in acts:
		var at = str(a.get("action_type", ""))
		if at == "reset_hand":
			has_reset = true
		elif at == "play_card":
			has_play = true
	if has_reset and not has_play:
		_state = State.WAITING_FOR_CHOICE
		if _hand_reset_popup != null:
			_hand_reset_popup.popup()
	_update_choice_blocker()


func _on_hand_reset_yes():
	if _hand_reset_popup != null:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return
	perform_action({"action_type": "reset_hand"})


func _on_hand_reset_no():
	if _hand_reset_popup != null:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return
	_state = State.READY_FOR_INPUT


# ---------------------------------------------------------------------------
# Provider signal handlers
# ---------------------------------------------------------------------------

func _on_game_started(snapshot):
	_last_snapshot = snapshot
	_clear_selection()
	_apply_snapshot(snapshot)
	if snapshot.get("winner", null) != null:
		_state = State.GAME_OVER
	else:
		_state = State.READY_FOR_INPUT
	_check_reset_hand(snapshot)
	_update_choice_blocker()


func _on_action_completed(result):
	_last_snapshot = result.get("snapshot", null)
	_last_events = result.get("events", [])
	emit_signal("action_applied", result)

	# Start animation BEFORE applying snapshot so CardAnimator can clone
	# the card texture from the pre-action hand state (before the card is removed).
	var should_animate = _card_animator != null and _card_animator.has_method("play_events") and _last_events.size() > 0
	if should_animate:
		_state = State.ANIMATING
		_card_animator.play_events(_last_events, _last_snapshot)

	_apply_snapshot(_last_snapshot)

	# Pre-hide any cards that will be drawn, so they don't flicker into
	# existence before the draw animation reveals them.
	if should_animate and _card_animator != null and _card_animator.has_method("hide_drawn_cards"):
		_card_animator.hide_drawn_cards(_last_events)

	if not should_animate:
		_finish_post_action()


# ---------------------------------------------------------------------------
# F7: Safe Round choice popup — opened BEFORE the activating play_card is
# sent, so the blocked_type rides on the same single play_card action.
# ---------------------------------------------------------------------------

func _selected_card_dict():
	if _selected_card_id == "" or _last_snapshot == null:
		return null
	var lid = _last_snapshot.get("local_player_id", "player_1")
	for p in _last_snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					return c
	return null


func _play_activates_safe_round():
	"""F7: true when the selected card will activate a Safe Round — a normal
	Gold, or a +11 played immediately after a normal Gold whose next chain
	value is 23-78 (a chain to 89 activates the Advantage Round instead)."""
	var c = _selected_card_dict()
	if c == null:
		return false
	var ct = str(c.get("card_type", ""))
	if ct == "gold":
		return true
	if ct == "special" and str(c.get("name", "")) == "+11":
		var plateau_cards = _last_snapshot.get("plateau_cards", [])
		if plateau_cards.size() > 0:
			var last = plateau_cards[plateau_cards.size() - 1]
			if str(last.get("card_type", "")) == "gold":
				var chain_val = GOLD_CHAIN.get(int(last.get("value", 0)), null)
				return chain_val != null and chain_val != 89
	return false


func _is_selected_card_blocked_by_sr():
	"""True when the selected card is of the type currently blocked by an
	active Safe Round (Giro Sicuro). Such cards are selectable (for Cambio
	Carta) but must be rejected by Play. Mirrors the SR blocking rules."""
	if _selected_card_id == "" or _last_snapshot == null:
		return false
	if not _last_snapshot.get("special_round_active", false):
		return false
	var sr_type = str(_last_snapshot.get("special_round_type", ""))
	if sr_type != "safe":
		return false
	var blocked_type = str(_last_snapshot.get("blocked_type", "")).to_lower()
	if blocked_type == "":
		return false
	var card = _selected_card_dict()
	if card == null:
		return false
	var ct = str(card.get("card_type", "")).to_lower()
	var name = str(card.get("name", ""))
	if blocked_type == "incremento":
		return ct == "increment" or ct == "jolly" or name == "+11"
	elif blocked_type == "gold":
		return ct == "gold" or name == "89"
	elif blocked_type == "imbroglio":
		return ct == "imbroglio"
	return false


func _open_safe_round_choice():
	"""Open ValueChoicePopup for Safe Round blocked_type selection."""
	_state = State.WAITING_FOR_CHOICE
	_pending_action_type = "play_card"
	_pending_card_id = _selected_card_id
	_pending_valid_values = SAFE_ROUND_CHOICES.duplicate()
	_pending_blocked_type = true

	if _value_choice_label != null:
		_value_choice_label.text = "Scegli la tipologia da bloccare"

	# Clear old buttons and create Safe Round type buttons
	if _value_btn_grid != null:
		for c in _value_btn_grid.get_children():
			_value_btn_grid.remove_child(c)
			c.queue_free()

		for choice in SAFE_ROUND_CHOICES:
			var btn = Button.new()
			btn.text = choice
			btn.rect_min_size = Vector2(80, 40)
			btn.connect("pressed", self, "_on_safe_round_choice_chosen", [choice])
			_value_btn_grid.add_child(btn)

	if _value_choice_popup != null:
		_value_choice_popup.popup()
	_update_choice_blocker()


func _on_safe_round_choice_chosen(choice):
	"""Handle Safe Round blocked_type choice: send the single activating
	play_card with the chosen blocked_type."""
	if _state != State.WAITING_FOR_CHOICE:
		return
	if _pending_blocked_type != true:
		return

	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()

	var action = {"action_type": "play_card", "card_id": _pending_card_id}
	action["blocked_type"] = choice

	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_pending_blocked_type = false

	perform_action(action)


func _on_animation_finished():
	_finish_post_action()


func _finish_post_action():
	# GAME_OVER is set here, after the winning card animation has completed.
	if _last_snapshot != null and _last_snapshot.get("winner", null) != null:
		_clear_selection()
		_state = State.GAME_OVER
		return

	_validate_selection(_last_snapshot)
	if _selected_card_id == "":
		_state = State.READY_FOR_INPUT
	else:
		_state = State.CARD_SELECTED
	_check_reset_hand(_last_snapshot)
	_update_choice_blocker()


func _on_action_rejected(error_message):
	_last_error = error_message
	_clear_selection()
	_state = State.READY_FOR_INPUT


# ---------------------------------------------------------------------------
# Selection validation
# ---------------------------------------------------------------------------

func _validate_selection(snapshot):
	if _selected_card_id == "" or snapshot == null:
		return
	var lid = snapshot.get("local_player_id", "player_1")
	var found = false
	for p in snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					found = true
					break
			break
	if found:
		if _hand != null and _hand.has_method("set_selected"):
			_hand.set_selected(_selected_card_id)
	else:
		_clear_selection()


# ---------------------------------------------------------------------------
# Card type lookup
# ---------------------------------------------------------------------------

func _get_selected_card_type():
	if _selected_card_id == "" or _last_snapshot == null:
		return ""
	var lid = _last_snapshot.get("local_player_id", "player_1")
	for p in _last_snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					return c.get("card_type", "")
	return ""


# ---------------------------------------------------------------------------
# Presenter update
# ---------------------------------------------------------------------------

func _apply_snapshot(snapshot):
	if snapshot == null:
		return
	if _board != null and _board.has_method("apply_snapshot"):
		_board.apply_snapshot(snapshot)
	if _hand != null and _hand.has_method("apply_snapshot"):
		_hand.apply_snapshot(snapshot)
	if _turn != null and _turn.has_method("apply_snapshot"):
		_turn.apply_snapshot(snapshot)
