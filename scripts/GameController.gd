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
var _gold_reveal_popup = null
var _gold_card_label = null
var _gold_yes_btn = null
var _gold_no_btn = null

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

	_value_choice_popup = _child(ol, "ValueChoicePopup")
	if _value_choice_popup != null:
		var vb = _child(_value_choice_popup, "VBox")
		if vb != null:
			_value_choice_label = _child(vb, "MsgLabel")
			_value_btn_grid = _child(vb, "BtnGrid")
			_value_cancel_btn = _child(vb, "CancelBtn")
			if _value_cancel_btn != null:
				_value_cancel_btn.connect("pressed", self, "_on_value_cancel")

	_gold_reveal_popup = _child(ol, "GoldRevealPopup")
	if _gold_reveal_popup != null:
		var vb = _child(_gold_reveal_popup, "VBox")
		if vb != null:
			_gold_card_label = _child(vb, "CardLabel")
			var br = _child(vb, "BtnRow")
			if br != null:
				_gold_yes_btn = _child(br, "YesBtn")
				_gold_no_btn = _child(br, "NoBtn")
				if _gold_yes_btn != null:
					_gold_yes_btn.connect("pressed", self, "_on_gold_reveal_yes")
				if _gold_no_btn != null:
					_gold_no_btn.connect("pressed", self, "_on_gold_reveal_no")


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
		var ct = _get_selected_card_type()
		if ct == "jolly":
			_open_value_choice("Jolly", range(1, 11))
		elif ct == "imbroglio":
			var vals = []
			for v in range(-15, 16):
				if v != 0:
					vals.append(v)
			_open_value_choice("Imbroglio", vals)
		else:
			_send_action({"action_type": "play_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_change_pressed():
	if _state == State.CARD_SELECTED and _selected_card_id != "":
		_send_action({"action_type": "change_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_cancel_pressed():
	if _state == State.CARD_SELECTED:
		_clear_selection()
		_state = State.READY_FOR_INPUT


func _send_action(action):
	_state = State.ACTION_PENDING
	_provider.send_action(action)


# ---------------------------------------------------------------------------
# Value choice popup (Jolly / Imbroglio)
# ---------------------------------------------------------------------------

func _open_value_choice(card_name, values):
	_state = State.WAITING_FOR_CHOICE
	_pending_action_type = "play_card"
	_pending_card_id = _selected_card_id
	_pending_valid_values = values

	if _value_choice_label != null:
		_value_choice_label.text = "Scegli il valore per " + card_name

	# Clear old buttons from grid
	if _value_btn_grid != null:
		for c in _value_btn_grid.get_children():
			_value_btn_grid.remove_child(c)
			c.queue_free()

		# Add value buttons
		for v in values:
			var btn = Button.new()
			btn.text = str(v)
			btn.rect_min_size = Vector2(60, 40)
			btn.connect("pressed", self, "_on_value_chosen", [v])
			_value_btn_grid.add_child(btn)

	if _value_choice_popup != null:
		_value_choice_popup.popup()


func _on_value_chosen(value):
	if _state != State.WAITING_FOR_CHOICE:
		return
	if _pending_valid_values.size() > 0 and not value in _pending_valid_values:
		return  # Invalid value — stay in WAITING_FOR_CHOICE, popup stays open
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	var action = {"action_type": _pending_action_type, "card_id": _pending_card_id}
	action["selected_value"] = value
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_state = State.ACTION_PENDING
	_provider.send_action(action)


func _on_value_cancel():
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	if _state != State.WAITING_FOR_CHOICE:
		return
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_state = State.CARD_SELECTED


# ---------------------------------------------------------------------------
# Gold Reveal popup
# ---------------------------------------------------------------------------

func _check_gold_reveal(snapshot):
	if snapshot == null:
		return
	# Don't reopen if already in a choice or in a blocked state
	if _state == State.WAITING_FOR_CHOICE or _state == State.ACTION_PENDING or _state == State.GAME_OVER:
		return
	var acts = snapshot.get("available_actions", [])
	var gold_cid = ""
	var gold_name = ""
	for a in acts:
		if a.get("action_type", "") == "reveal_gold":
			gold_cid = a.get("card_id", "")
			break
	if gold_cid == "":
		return

	# Find the gold card name in the hand
	for p in snapshot.get("players", []):
		if p.get("id", "") == snapshot.get("local_player_id", "player_1"):
			for c in p.get("hand", []):
				if c.get("card_id", "") == gold_cid:
					gold_name = c.get("name", "Gold")
					break
			break

	_pending_action_type = "reveal_gold"
	_pending_card_id = gold_cid
	_state = State.WAITING_FOR_CHOICE

	if _gold_card_label != null:
		_gold_card_label.text = gold_name
	if _gold_reveal_popup != null:
		_gold_reveal_popup.popup()


func _on_gold_reveal_yes():
	if _gold_reveal_popup != null:
		_gold_reveal_popup.hide()
	if _state != State.WAITING_FOR_CHOICE:
		return
	var action = {"action_type": _pending_action_type, "card_id": _pending_card_id}
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_state = State.ACTION_PENDING
	_provider.send_action(action)


func _on_gold_reveal_no():
	if _gold_reveal_popup != null:
		_gold_reveal_popup.hide()
	if _state != State.WAITING_FOR_CHOICE:
		return
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
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
	_check_gold_reveal(snapshot)


func _on_action_completed(result):
	_last_snapshot = result.get("snapshot", null)
	_last_events = result.get("events", [])
	emit_signal("action_applied", result)
	_apply_snapshot(_last_snapshot)
	if _last_snapshot != null and _last_snapshot.get("winner", null) != null:
		_clear_selection()
		_state = State.GAME_OVER
		return
	# Start animation queue if animator is available and events exist
	if _card_animator != null and _card_animator.has_method("play_events") and _last_events.size() > 0:
		_state = State.ANIMATING
		_card_animator.play_events(_last_events, _last_snapshot)
	else:
		_finish_post_action()


func _on_animation_finished():
	_finish_post_action()


func _finish_post_action():
	_validate_selection(_last_snapshot)
	if _selected_card_id == "":
		_state = State.READY_FOR_INPUT
	else:
		_state = State.CARD_SELECTED
	_check_gold_reveal(_last_snapshot)


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
